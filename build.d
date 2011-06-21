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

// Update these to reflect the state on your system, these are the default on XP32.
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

bool Debug;
bool skipHeaderCompile;
bool skipResCompile;
alias reduce!("a ~ ' ' ~ b") flatten;
string[] failedBuilds;

void build(string dir)
{
    string appName = rel2abs(dir).basename;
    string exeName = rel2abs(dir) ~ r"\" ~ appName ~ ".exe";
    string LIBPATH = r"..\..\..";
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
        writeln("Building " ~ exeName);
        auto res = system("dmd -of" ~ appName ~ ".exe" ~ 
                          " -I" ~ LIBPATH ~ r"\" ~ 
                          " " ~ LIBPATH ~ r"\win32.lib" ~
                          " " ~ FLAGS ~ 
                          " " ~ sources.flatten);
        
        if (res == -1 || res == 1)
            failedBuilds ~= exeName;
    }
}

void main(string[] args)
{
    args.popFront;
    bool clean   = (args.length && args[0] == "clean");
    Debug        = (args.length && args[0] == "debug");
    string projectPath;
    
    if (args.length && getDrive(args[0]))
    {
        if (exists(args[0]) && isdir(args[0]))
        {
            projectPath = args[0];
        }
        else
            assert(0, "Cannot build project in path: \"" ~ args[0] ~ 
                      "\". Try wrapping %CD% with quotes when calling build: \"%CD%\"");
    }
    
    if (!clean) checkDependencies();
    
    // build a single project only
    if (projectPath.length)
    {
        chdir(projectPath);
        build(curdir);
    }
    else
    {
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
        
        foreach (dir; dirs)
        {
            chdir(dir);

            // the DLL examples are special, for one thing the std.c.windows.windows
            // module clashes with the WindowsAPI bindings, and the 
            // DLLs require special DMD flags. Each dir has its own batch file.
            if (dir.basename == "EdrTest" ||
                dir.basename == "ShowBit" ||
                dir.basename == "StrProg")
            {
                if (clean)
                {
                    try { system("del *.obj"); } catch{};
                    try { system("del *.map"); } catch{};
                    try { system("del *.exe"); } catch{};
                }
                else
                {
                    auto res = system(r"build.bat");
                    if (res == 1 || res == -1)
                        failedBuilds ~= rel2abs(dir) ~ r"\" ~ dir.basename ~ ".exe";
                }
            }
            else
            {
                if (clean)
                {
                    try { system("del *.obj"); } catch{};
                    try { system("del *.map"); } catch{};
                    try { system("del *.exe"); } catch{};
                }
                else
                    build(curdir);
            }
        }
    }
    
    if (failedBuilds.length)
    {
        writeln("The following failed to build:");
        foreach (file; failedBuilds)
        {
            writeln(file);
        }
    }
    else if (!clean)
    {
        writeln("All examples succesfully built.");
    }
}
