module build;

import core.thread : Thread, dur;
import std.algorithm;
import std.array;
import std.exception;
import std.stdio;
import std.string;
import std.path;
import std.file;
import std.process;
import std.parallelism;

string RC_INCLUDE_1 = r"C:\Program Files\Microsoft SDKs\Windows\v7.1\Include";
string RC_INCLUDE_2 = r"C:\Program Files\Microsoft Visual Studio 10.0\VC\include";
string RC_INCLUDE_3 = r"C:\Program Files\Microsoft Visual Studio 10.0\VC\atlmfc\include";
    
extern(C) int kbhit();
extern(C) int getch();    
    
class ForcedExitException : Exception
{
    this()
    {
        super("");
    }    
}

class FailedBuildException : Exception
{
    string[] failedMods;
    this(string[] failedModules)
    {
        this.failedMods = failedModules;
        super("");
    }    
}
    
void checkTools()
{
    system("echo int x; > test.h");
    auto res = system("htod test.h");
    
    if (res == -1 || res == 1)
    {
        skipHeaderCompile = true;
        writeln(0, "Warning: The builder will use existing D header files and won't generate them dyanimcally. You need to download and install HTOD. Please see the Links section in the Readme file.");
    }
    
    try { std.file.remove("test.h"); } catch {};
    try { std.file.remove("test.d"); } catch {};    
    
    system("echo //void > test.rc");
    res = system("rc test.rc");    
    if (res == -1 || res == 1)
    {
        skipResCompile = true;
        writeln("Warning: RC Compiler not found. Builder will will use precompiled resources. See README for more details..\n");
        Thread.sleep(dur!("seconds")(3));
    }
    
    try { std.file.remove("test.rc");  } catch {};
    try { std.file.remove("test.res"); } catch {};
    
    if (!skipResCompile &&
        !(RC_INCLUDE_1.exists && 
          RC_INCLUDE_2.exists &&
          RC_INCLUDE_3.exists))
    {
        auto includes = getenv("RCINCLUDES").split(";");
        
        if (!includes.length)
        {
            skipResCompile = true;
            writeln("Warning: RC Compiler Include dirs not found. Builder will will use precompiled resources. See README for more details.");
            Thread.sleep(dur!("seconds")(3));
        }
    }        
    
}

string[] getFilesByExt(string dir, string ext, string ext2 = null)
{
    string[] result;
    foreach (string file; dirEntries(dir, SpanMode.shallow))
    {
        if (file.isfile && (file.getExt == ext || file.getExt == ext2))
            result ~= file;
    }
    return result;
}

__gshared bool forcedExit;
__gshared bool Debug;
__gshared bool cleanOnly;
__gshared bool skipHeaderCompile;
__gshared bool skipResCompile;
__gshared bool silent;
__gshared string soloProject;
__gshared alias reduce!("a ~ ' ' ~ b") flatten;
__gshared string[] failedBuilds;

bool buildProject(string dir)
{
    string appName = rel2abs(dir).basename;
    string exeName = rel2abs(dir) ~ r"\" ~ appName ~ ".exe";
    string LIBPATH = r".";
    string FLAGS = Debug ? 
                   "-I. -version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista -g" 
                 : "-I. -version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista -L-Subsystem:Windows";
    
    // there's only one resource and header file for each example
    string[] resources;
    string[] headers;
    
    if (!skipResCompile) 
        resources = dir.getFilesByExt("rc");  
    
    if (!skipHeaderCompile) 
        headers = dir.getFilesByExt("h");
    
    resources.length && system("rc /i" ~ `"` ~ RC_INCLUDE_1 ~ `"` ~ 
                                 " /i" ~ `"` ~ RC_INCLUDE_2 ~ `"` ~
                                 " /i" ~ `"` ~ RC_INCLUDE_3 ~ `"` ~ 
                                 " " ~ resources[0].getName ~ ".rc");

    headers.length && system("htod " ~ headers[0]);
    
    // get sources after any .h header files were converted to .d header files
    auto sources   = dir.getFilesByExt("d", "res");
    
    if (sources.length)
    {
        if (!silent) writeln("Building " ~ exeName);
        auto res = system(" dmd -of" ~ exeName ~
                          " -od" ~ rel2abs(dir) ~ r"\" ~ 
                          " -I" ~ LIBPATH ~ r"\" ~ 
                          " " ~ LIBPATH ~ r"\win32.lib" ~
                          " " ~ FLAGS ~ 
                          " " ~ sources.flatten);
        
        if (res == -1 || res == 1)
            return false;
        
        try { system("del " ~ appName ~ ".map"); } catch{};
    }
    
    return true;
}

void checkWinLib()
{
    enforce("win32.lib".exists, "You have to compile the WindowsAPI bindings first. Use the build_unicode.bat script in the win32 folder");
}

string[] getProjectDirs(string root)
{
    string[] result;
    
    // direntries is not a range in 2.053
    foreach (string dir; dirEntries(root, SpanMode.shallow))
    {
        if (dir.isdir)
        {
            foreach (string subdir; dirEntries(dir, SpanMode.shallow))
            {
                if (subdir.isdir && subdir.basename != "todo")
                    result ~= subdir;
            }
        }
    }    
    return result;
}

void buildProjectDirs(string[] dirs, bool cleanOnly = false)
{
    __gshared string[] failedBuilds;
    
    foreach (dir; parallel(dirs, 1))
    {
        if (!cleanOnly && kbhit())
        {
            auto key = cast(dchar)getch();
            stdin.flush();
            enforce(key != 'q', new ForcedExitException);
        }
        
        // DLL Examples require special commands, using batch file workarounds for now.
        if (dir.basename == "EdrTest" ||
            dir.basename == "ShowBit" ||
            dir.basename == "StrProg")
        {
            if (cleanOnly)
            {
                try { system("del " ~ dir ~ r"\" ~ "*.obj"); } catch{};
                try { system("del " ~ dir ~ r"\" ~ "*.map"); } catch{};  
                try { system("del " ~ dir ~ r"\" ~ "*.exe"); } catch{};
            }
            else
            {
                auto res = system(dir ~ r"\" ~ "build.bat");
                if (res == 1 || res == -1)
                    failedBuilds ~= rel2abs(dir) ~ r"\" ~ dir.basename ~ ".exe";
            }
        }
        else
        {
            if (cleanOnly)
            {
                try { system("del " ~ dir ~ r"\" ~ "*.obj"); } catch{};
                
                    // @BUG@ DMD 2.053 still outputs map files in the CWD instead of project folder,
                // update this when 2.054 comes out.                        
                //~ try { system("del " ~ dir ~ r"\" ~ "*.map"); } catch{};
                    
                try { system("del " ~ dir ~ r"\" ~ "*.exe"); } catch{};
            }
            else
            {
                if (!buildProject(dir))
                    failedBuilds ~= rel2abs(dir) ~ r"\" ~ dir.basename ~ ".exe";
            }
        }
    }
    
    enforce(!failedBuilds.length, new FailedBuildException(failedBuilds));
}

int main(string[] args)
{
    args.popFront;
    
    foreach (arg; args)
    {
        if (arg == "clean") cleanOnly = true;
        else if (arg == "debug") Debug = true;
        else
        {
            if (getDrive(arg))
            {
                if (exists(arg) && isdir(arg))
                {
                    soloProject = arg;
                }
                else
                    enforce(0, "Cannot build project in path: \"" ~ arg ~ 
                              "\". Try wrapping %CD% with quotes when calling build: \"%CD%\"");
            }               
        }
    }
    
    string[] dirs;
    if (soloProject.length)
    {
        silent = true;
        chdir(r"..\..\..\");
        dirs = [soloProject];
    }
    else
    {
        dirs = getProjectDirs(rel2abs(curdir ~ r"\Samples"));  
    }
    
    if (!cleanOnly)
    {
        checkTools();
        checkWinLib();
        
        if (!silent)
        {
            writeln("About to build.");
            
            // @BUG@ The RDMD bundled with DMD 2.053 has input handling bugs,
            // wait for 2.054 to print this out. If you have RDMD from github,
            // you can press 'q' during the build process to force exit.
            
            //~ writeln("About to build. Press 'q' to stop the build process.");
            Thread.sleep(dur!("seconds")(2));
        }
    }    
    
    try
    {
        buildProjectDirs(dirs, cleanOnly);
    }
    catch (ForcedExitException)
    {
        writeln("\nBuild process halted, about to clean..\n");
        Thread.sleep(dur!("seconds")(3));
        cleanOnly = true;
        buildProjectDirs(dirs, cleanOnly);
    }
    catch (FailedBuildException exc)
    {
        if (!silent)
        {
            writefln("\n%s projects failed to build:", exc.failedMods.length);
            foreach (mod; exc.failedMods)
            {
                writeln(mod);
            }
        }
        
        return 1;
    }
    
    if (!cleanOnly && !silent)
    {
        writeln("\nAll examples succesfully built.");
    }
    
    return 0;
}
