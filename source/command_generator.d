module command_generator;

import std.string:join;
import std.array:join;

//Import the commonly shared buildapi
import buildapi;
//Blindly import project, app.d will handle that
import project;

import std.process;
import std.stdio;
import std.datetime.stopwatch;

version(Windows) enum pathSep = '\\';
else enum pathSep = '/';

version(Windows) 
    enum executableExt = ".exe";
else version(Linux)
    enum executableExt = "";

version(Windows) 
    enum sharedLibExt = ".dll";
else version(Linux)
    enum sharedLibExt = ".so";
else 
    enum sharedLibExt = ".dynlib";


version(Windows)
    enum libExt = ".lib";
else 
    enum libExt = ".a";

string getCompiler(string compiler)
{
    switch(compiler)
    {
        case "dmd":  return "dmd";
        case "ldc":  return "ldc2";
        case "ldc2": return "ldc2";

        default: assert(false, "Inavlid compiler "~compiler);
    }
}


string getVersion(string v)
{
    switch(v)
    {
        case "dmd": return "-version=";
        case "ldc2": return"-d-version=";
        
        default: assert(false, "Invalid version "~v);
    }
}

string getExtension(OutputType t)
{
    final switch(t)
    {
        case OutputType.executable:
            return executableExt;
        case OutputType.library:
            return libExt;
        case OutputType.sharedLibrary:
            return sharedLibExt;
    }
}



enum p = getProject();

string sendProjectsDependencies(){return unpackDependencies(p);}


string[] buildCommand(string[] extraImports = [], string[] extraVersions = [],
string[] extraLibs = [], string[] extraLibPaths = [])
{
    enum compiler = p.compiler.getCompiler;

    string[] cmd = [compiler];

    if(p.isDebug)
        cmd~= "-g";
    if(p.is64)
        cmd~= "-m64";
    
    final switch(p.outputType)
    {
        case OutputType.executable:
            break;
        case OutputType.library: 
            cmd~= "-lib";
            break;
        case OutputType.sharedLibrary:
            cmd~= "-shared";
            break;
    }

    foreach(i; p.importDirectories ~ extraImports)
        cmd~= "-I"~i;

    foreach(v; p.versions ~ extraVersions)
        cmd~= compiler.getVersion~v;


    foreach(l; p.libraries ~ extraLibs)
        cmd~= "-l"~l~libExt;
    foreach(lp; p.libraryPaths~extraLibPaths)
        cmd~= "-L-L"~lp;

    cmd~= "-i";
    cmd~= p.sourceEntryPoint;

    if(p.outputDirectory)
        cmd~= "-od"~p.outputDirectory;


    cmd~= "-of"~p.outputDirectory~pathSep~p.name ~ p.outputType.getExtension;

    return cmd;
}


int returnCommandString(string[] extraImports, string[] extraVersions, string[] extraLibs, string[] extraLibPaths)
{
    string character;
    version(Windows)
        character = " ^\n";
    else
        character = " \\\n";

    writeln(buildCommand(extraImports, extraVersions, extraLibs, extraLibPaths).join(character));
    return ExitCodes.commands;
}




enum hasDependencies = p.dependencies !is null;

bool shouldReturnDependencies()
{
    if(dependenciesRequired)
        return true;
    else if(dependenciesResolved)
        return false;
    else
        return hasDependencies;
}



bool contains(T)(T[] arr, T what)
{
    foreach(a; arr)
        if(a == what)
            return true;
    return false;
}

import std.typecons:Tuple;

alias BoolArg = Tuple!(bool*, string);

void loadArgs(string[] str, Tuple!(bool*, string)[] args)
{
    foreach(a; args)
    {
        *a[0] = str.contains(a[1]);
    }
}

bool dependenciesResolved;
bool dependenciesRequired;
bool getCommand;

/**
*   The command generator is a program which may receive the following arguments:
*   - getCommand : Executed automatically when hipmake runs hipmake command
*   - dependenciesResolved : That means this program is receiving the correct arguments
*   taking into account the dependencies
*/
int main(string[] args)
{ 
    loadArgs(args, 
    [
    BoolArg(&dependenciesResolved, "dependenciesResolved"),
    BoolArg(&dependenciesRequired, "dependenciesRequired"),
    BoolArg(&getCommand, "getCommand")
    ]
    );

    if(shouldReturnDependencies())
    {
        writeln(sendProjectsDependencies);
        return ExitCodes.dependencies;
    }

    string[] extraImports  = [];
    string[] extraVersions = [];
    string[] extraLibs     = [];
    string[] extraLibPaths = [];
    if(dependenciesResolved)
    {
        DependenciesPack p = packDependencies("", args[2]);
        extraImports = p.importPaths;
        extraVersions = p.versions;
        extraLibs = p.libs;
        extraLibPaths = p.libPaths;
    }

    if(getCommand)
        return returnCommandString(extraImports, extraVersions, extraLibs, extraLibPaths);

    StopWatch st = StopWatch(AutoStart.yes);
    auto ex = execute(buildCommand(extraImports, extraVersions, extraLibs, extraLibPaths));
    st.stop();
    if(ex.status)
    {
        return ex.status;
    }
    bool quiet = (args.length > 1) && args[1] == "quiet";
    

    if(!quiet)
        writeln("Built project '"~p.name~"' in ", (st.peek.total!"msecs"), " ms.") ;
    return 0;
}