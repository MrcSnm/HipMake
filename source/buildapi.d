import std.path;

enum CommandGeneratorControl : string
{
    getCommand = "getCommand",
    dependenciesRequired = "dependenciesRequired",
    dependenciesResolved = "dependenciesResolved"
}

enum ExitCodes
{
    success = 0,
    error = 1,
    commands = 2,
    dependencies = 3,
}

enum OutputType
{
    library = 0,
    sharedLibrary,
    executable
}

struct Project
{
    string name;
    string[] versions;
    string[] importDirectories;
    string[] libraryPaths;
    string[] libraries;

    string compiler         = "dmd";
    string sourceEntryPoint = "source/app.d";
    string outputDirectory  = "build";


    Dependency[string] dependencies;
    Configuration[string] configurations;
    OutputType outputType;
    bool isDebug;
    bool is64;
}


struct Configuration
{

}

struct Dependency
{
    string path;
}


struct DependenciesPack
{
    string[string] projects;
    string[] importPaths;
    string[] libPaths;
    string[] libs;
    string[] versions;
}

enum PackingOrder
{
    PROJECTS = 1,
    IMPORTS,
    LIBPATHS,
    LIBS,
    VERSIONS
}

private string[] split(string str, char c)
{
    string[] ret;

    string accumulator = "";
    for(uint i = 0; i < str.length; i++)
    {
        if(str[i] == c)
        {
            ret~= accumulator;
            accumulator = "";
            continue;
        }
        else
            accumulator~= str[i];
    }
    if(accumulator != "")
        ret~= accumulator;
    return ret;
}

struct ProjectPair
{
    string key;
    string value;
}

ProjectPair getProjectPair(string projInput)
{
    for(int i = 0; i < projInput.length; i++)
    {
        if(projInput[i] == ':')
        {
            return ProjectPair(projInput[0..i], projInput[i+3..$]);
        }
    }
    throw new Error("Could not find the expected input in "~projInput);
}

DependenciesPack packDependencies(string workingDir, string deps)
{
    DependenciesPack pack;
    string[] lines = deps.split('\n');
    int current = 0;
    import std.stdio;

    foreach(l; lines)
    {
        if(l == "PROJECTS:::" ||
        l == "IMPORTS:::" ||
        l == "LIBPATHS:::" ||
        l == "LIBS:::" ||
        l == "VERSIONS:::")
        {
            current++;
            continue;
        }

        
        if(l != "")
        {
            switch(current)
            {
                case PackingOrder.PROJECTS:
                    ProjectPair p = getProjectPair(l);
                    pack.projects[p.key] = isAbsolute(p.value) ?
                                        buildNormalizedPath(workingDir, p.value) :
                                        p.value;
                    break;
                case PackingOrder.IMPORTS:
                    pack.importPaths~= isAbsolute(l) ? buildNormalizedPath(workingDir, l) : l;
                    break;
                case PackingOrder.LIBPATHS:
                    pack.libPaths~= isAbsolute(l) ? buildNormalizedPath(workingDir, l) : l;
                    break;
                case PackingOrder.LIBS:
                    pack.libs~= l;
                    break;
                case PackingOrder.VERSIONS:
                    pack.versions~= l;
                    break;
                default:continue;
            }
        }
    }

    return pack;
}

string unpackDependencies(DependenciesPack pack)
{
    string unpacked = "PROJECTS:::\n";
    foreach(string k, string v; pack.projects)
        unpacked~= k~":::"~v~"\n";

    unpacked~= "\nIMPORTS:::\n";
    foreach(imports; pack.importPaths)
        unpacked~=imports~"\n";
    
    unpacked~="\nLIBPATHS:::\n";
    foreach(libpath;pack.libPaths)
        unpacked~=libpath~"\n";

    unpacked~="\nLIBS:::\n";
    foreach(lib;pack.libs)
        unpacked~=lib~"\n";

    unpacked~="\n";
    return unpacked;
}

string unpackDependencies(Project p)
{
    string[string] projs;
    foreach(k, v; p.dependencies)
        projs[k] = v.path;
    return unpackDependencies(DependenciesPack(projs, p.importDirectories, p.libraryPaths, p.libraries));
}