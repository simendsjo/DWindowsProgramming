module build;

import core.thread : Thread, dur;
import std.algorithm;
import std.array;
import std.stdio;
import std.string;
import std.path;
import std.file;
import std.process;
import std.parallelism;

string RC_INCLUDE_1 = r"C:\Program Files\Microsoft SDKs\Windows\v7.1\Include";
string RC_INCLUDE_2 = r"C:\Program Files\Microsoft Visual Studio 10.0\VC\include";
string RC_INCLUDE_3 = r"C:\Program Files\Microsoft Visual Studio 10.0\VC\atlmfc\include";
    
void checkDependencies()
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
        writeln("Warning: The builder will use precompiled .res resource files. But you need to download and install the Microsoft RC resource compiler if you want to edit and compile .rc resource files. Please see the Links section in the Readme file.\n");
        Thread.sleep(dur!("seconds")(5));
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
            assert(0, "Your need to download the Windows SDK and set up the RC Include directories. Please see the Building section in the Readme file.");
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

__gshared bool Debug;
__gshared bool clean;
__gshared bool skipHeaderCompile;
__gshared bool skipResCompile;
__gshared bool silent;
__gshared string projectPath;
__gshared alias reduce!("a ~ ' ' ~ b") flatten;
__gshared string[] failedBuilds;

void build(string dir)
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
            failedBuilds ~= exeName;
        
        try { system("del " ~ appName ~ ".map"); } catch{};
    }
}

void checkLibExists()
{
    if (!exists("win32.lib"))
    {
        assert(0, "You have to compile the WindowsAPI bindings first. Use the build_unicode.bat script in the win32 folder");
    }
}

int main(string[] args)
{
    args.popFront;
    
    foreach (arg; args)
    {
        if (arg == "clean") clean = true;
        else if (arg == "debug") Debug = true;
        else
        {
            if (getDrive(arg))
            {
                if (exists(arg) && isdir(arg))
                {
                    projectPath = arg;
                }
                else
                    assert(0, "Cannot build project in path: \"" ~ arg ~ 
                              "\". Try wrapping %CD% with quotes when calling build: \"%CD%\"");
            }               
        }
    }
    
    if (!clean) checkDependencies();
    
    // build a single project only
    if (projectPath.length)
    {
        silent = true;
        chdir(r"..\..\..\");
        checkLibExists();
        build(projectPath);
    }
    else
    {
        checkLibExists();
        // direntries is not a range in 2.053:
        string[] dirs;
        foreach (string dir; dirEntries(rel2abs(curdir ~ r"\Samples"), SpanMode.shallow))
        {
            if (dir.isdir)
            {
                foreach (string subdir; dirEntries(dir, SpanMode.shallow))
                {
                    if (subdir.isdir && subdir.basename != "todo")
                        dirs ~= subdir;
                }
            }
        }
        
        foreach (dir; parallel(dirs, 1))
        {
            // the DLL examples are special, for one thing the std.c.windows.windows
            // module clashes with the WindowsAPI bindings, and the 
            // DLLs require special DMD flags. Each dir has its own batch file.
            if (dir.basename == "EdrTest" ||
                dir.basename == "ShowBit" ||
                dir.basename == "StrProg")
            {
                if (clean)
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
                if (clean)
                {
                    try { system("del " ~ dir ~ r"\" ~ "*.obj"); } catch{};
                        
                    // @BUG@ DMD 2.053 still outputs map files in CWD instead of project folders,
                    // update this when 2.054 comes out.                        
                    //~ try { system("del " ~ dir ~ r"\" ~ "*.map"); } catch{};
                    try { system("del " ~ dir ~ r"\" ~ "*.exe"); } catch{};
                }
                else
                    build(dir);
            }
        }
    }
    
    if (failedBuilds.length)
    {
        if (!projectPath.length)
        {
            writeln("The following failed to build:");
            foreach (file; failedBuilds)
            {
                writeln(file);
            }
        }
        return 1;
    }
    else if (!clean && !projectPath.length)
    {
        writeln("All examples succesfully built.");
        return 0;
    }
    return 0;
}
