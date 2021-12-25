import std.conv:to;
import std.array;
import std.path;
import std.file;
import std.process;
import std.stdio;

import buildapi;

struct DependencyInfo
{
    string name;
    string path;
}

alias DependencySet = bool[DependencyInfo];


struct DependencyNode
{
    DependencyInfo info;
    DependenciesPack pack;

    DependencyNode[] children;

    public void addChild(DependencyNode node){children~= node;}


    alias info this;
}

private __gshared DependencySet[DependencyInfo] handledDependencies;
private __gshared DependencyNode root;

version(Windows)
    enum outputExt = ".exe";
else
    enum outputExt = "";


bool handleDependency(DependencyInfo parent, DependencyInfo child, out string err)
{
    if(!(parent in handledDependencies))
        handledDependencies[parent] = DependencySet.init;
    if(child in handledDependencies && parent in handledDependencies[child])
    {
        err = "Diamond dependency problem ( infinite loop found ). \n" ~
        "Child project '"~child.name~"'("~child.path~"') already depends on '"~parent.name~"'("~parent.path~")";
        return false;
    }
    if(child in handledDependencies[parent])
    {
        err = "Dependency called '"~child.name~"' at path '"~child.path~
        "' is already included on project '"~parent.name~"'("~parent.path~")";
        return false;
    }

    handledDependencies[parent][child] = true;
    return true;
}

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

string replaceAll(string str, string replaceWhat, string replaceWith)
{
    int checking = 0;
    string ret = "";
    for(int i = 0; i < str.length; i++)
    {
        while(i+checking < str.length && str[i + checking] == replaceWhat[checking])
        {
            checking++;
            if(checking == replaceWhat.length)
            {
                ret~= replaceWith;
                i+= replaceWhat.length;
                break;
            }
        }
        ret~= str[i];
        checking = 0;
    }
    return ret;
}

int execBuild(string workingDir, string projectName, DependencyNode parentNode)
{
    string file = buildPath(workingDir, ".hipmake", "build"~outputExt);
    string cmd = file;
    //This must be later after resolves the dependencies
    if(willGetCommand)
        cmd~= " getCommand";

    auto ret = std.process.executeShell(cmd);
    writeln(cmd);

    if(ret.status == ExitCodes.commands)
    {
        std.file.write(buildPath(workingDir, ".hipmake", "command.txt"), ret.output);
        return 0;
    }
    else if(ret.status == ExitCodes.dependencies)
    {
        DependenciesPack pack = packDependencies(ret.output.replaceAll("\r", ""));
        if(parentNode == DependencyNode.init)
            root = parentNode = DependencyNode(DependencyInfo("Root", workingDir), pack, []);


        foreach(string dependencyProjectName, dependencyProjectPath; pack.projects) //Build the command generator for them
        {
            string path = dependencyProjectPath;
            DependencyNode dep = DependencyNode(DependencyInfo(dependencyProjectName, dependencyProjectPath),
            pack, []);
            parentNode.addChild(dep);

            if(!isAbsolute(path))
                path = buildNormalizedPath(workingDir, path);

            if(int status = buildCommandGenerator(hipMakePath, path))
            {
                writeln("Building generator failed at directory '"~path~"'");
                return 1;
            }
            if(int status = execBuild(path, dependencyProjectName, dep))
            {
                writeln("Dependency build failed at project '"~dependencyProjectName~"'("~path~")");
                return 1;
            }
        }
        writeln(pack);
    }
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

int checkEnvironment(ref string hipMakePath)
{
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
    hipMakePath = environment[environmentVariable];
    return 0;
}

int checkProject(string workingDir)
{
    if(!std.file.exists(buildPath(workingDir, projectFileName).asAbsolutePath))
    {
        writeln("'project.d' file not found in the current directory ( "~workingDir~ " )");
        return 1;
    }
    return 0;
}

void createHipmakeFolder(string workingDir)
{
    std.file.mkdirRecurse(buildPath(workingDir, ".hipmake"));
}

bool willGetCommand = false;
string hipMakePath;

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
        writeln("Building "~workingDir);
        int status = execBuild(workingDir, "Root", root);
        if(status)
            writeln("HipMake failed!");
        return status;
    }

    if(checkEnvironment(hipMakePath))
        return 1;
    if(checkProject(workingDir))
        return 1;
    createHipmakeFolder(workingDir);
    
    if(int cmdGen = buildCommandGenerator(hipMakePath, workingDir))
    {
        writeln("HipMake failed at building command generator for the directory: '"~workingDir~"'");
        return cmdGen;
    }

    writeln("Building "~workingDir);
    if(int status = execBuild(workingDir, "Root", root))
    {
        writeln("HipMake failed!");
        return status;
    }
    chdir(workingDir);

    if(!createTimestampCache(workingDir))
        writeln("Could not create a timestamp cache");

    return 0;
}