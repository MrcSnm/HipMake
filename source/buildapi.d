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