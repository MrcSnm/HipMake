import std.conv:to;
import std.array;
import std.path;
import std.file;
import std.process;
import std.stdio;


version(Windows)
    enum outputExt = ".exe";
else
    enum outputExt = "";


enum environmentVariable = "HIPMAKE_SOURCE_PATH";
enum projectFileName     = "project.d";
enum tsCache             = ".timestamp_cache";


nothrow bool isUpToDate(string workspace)
{
    string cache = buildPath(workspace, ".hipmake", tsCache);
    string proj = buildPath(workspace, projectFileName);

    if(!std.file.exists(proj))
        return false;
    if(!std.file.exists(cache))
        return false;

    //Read the timestamp
    try
    {
        File f = File(cache);
        ubyte[] buff = new ubyte[cast(uint)(f.size)];
        f.rawRead(buff);
        f.close();
        long ts = to!long((cast(string)buff));
        long projMod = std.file.timeLastModified(proj).stdTime;
        return ts == projMod;    
    }
    catch(Exception e)
    {
        try{writeln(e.toString); return false;}
        catch(Exception e){return false;}
    }

    return false;
}

/**
*  Returns if operation was succesful
*/
nothrow bool createTimestampCache(string workspace)
{
    try
    {
        long t = std.file.timeLastModified(buildPath(workspace, projectFileName)).stdTime;
        string path = buildPath(workspace, ".hipmake", tsCache);
        File f = File(path, "w");
        f.write(t);
        f.close();
    }
    catch(Exception e)
    {
        try{writeln(e.toString); return false;}
        catch(Exception e){return false;}
    }
    return true;
}

int buildCommandGenerator(string hipMakePath, string workingDir)
{
    string outputPath = buildPath(workingDir, ".hipmake");
    string[] commands = 
    [
        "dmd",
        "-i", 
        "-I"~buildPath(hipMakePath, "source"),
        "-I"~workingDir,
        "-od="~outputPath,
        "-of="~buildPath(outputPath, "build"~outputExt),
        buildPath(hipMakePath, "source", "command_generator.d")
    ];

    //Build the command generator
    auto res = std.process.execute(commands);

    if(res.status)
    {
        writeln(res.output);
        return res.status;
    }

    return 0;
}

int execBuild(string workingDir)
{
    string file = buildPath(workingDir, ".hipmake", "build"~outputExt);

    string cmd = file;

    if(willGetCommand)
        cmd~= " getCommand";

    auto ret = std.process.executeShell(cmd);
    if(ret.status == "getCommand".length)
    {
        std.file.write(buildPath(workingDir, ".hipmake", "command.txt"), ret.output);
        return 0;
    }
    writeln(ret.output);
    return ret.status;
}

nothrow bool clean(string workingDir)
{
    try{rmdirRecurse(buildPath(workingDir, ".hipmake")); return true;}
    catch(Exception e)
    {
        try{writeln("Could not remove .hipmake: ", e.toString); return false;}
        catch(Exception e){return false;}
    }
    return false;
}

bool willGetCommand = false;

/**
*
*   All this file does is:
*   1. Search in the current directory for project.d
*   2. Use that directory as an import place for the project generator
*   3. Build the command generator together with the project.d (as it is being blindly imported )
*   4. Run the command generator using the project gotten from getProject function
*   5. Caches the command generated from the generator until project.d is modified.
*   6. If it is cached, it will only run the command
*/
int main(string[] args)
{
    string workingDir = getcwd();

    if(args.length > 1 && args[1] == "clean")
        return cast(int)clean(workingDir);
    else if(args.length > 1 && args[1] == "rebuild")
    {
        if(!clean(workingDir))
        {
            writeln("Error while trying to clean");
            return 1;
        }
    }
    else if(args.length > 1 && args[1] == "command")
        willGetCommand = true;

    if(isUpToDate(workingDir))
    {
        int status = execBuild(workingDir);
        if(status)
            writeln("HipMake failed!");
        return status;
    }

    if(environment.get(environmentVariable) is null)
    {
        writefln("%s environment variable not defined. This variable is necessary for
building the project.d file. For setting it under:
        Windows: set %s=\"path\\where\\hipmake\\is\"
        Linux  : export %s=\"path/where/hipmake/is\"

        Beware: If you set it under User Variables or System Variables on Windows, you may need
        to restart your PC.
        
", environmentVariable, environmentVariable, environmentVariable);
        return 1;
    }

    if(!std.file.exists(buildPath(workingDir, projectFileName).asAbsolutePath))
    {
        writeln("'project.d' file not found in the current directory ( "~workingDir~ " )");
        return 1;
    }

    string hipMakePath = environment[environmentVariable];

    std.file.mkdirRecurse(buildPath(workingDir, ".hipmake"));

    int cmdGen = buildCommandGenerator(hipMakePath, workingDir);
    if(cmdGen)
    {
        writeln("HipMake failed at building command generator");
        return cmdGen;
    }


    if(!createTimestampCache(workingDir))
        writeln("Could not create a timestamp cache");


    int status = execBuild(workingDir);
    if(status)
    {
        writeln("HipMake failed!");
        return status;
    }
    return 0;
}