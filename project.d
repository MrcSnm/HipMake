module project;
import buildapi;

Project getProject()
{
    Project project = {
        name: "hipmake",
        sourceEntryPoint: "source/app.d",
        dependencies : null,
        // [
            //"somedep" : Dependency("depPath")
        // ],
        configurations : null,
        // [
            // "Script" : Configuration()
        // ],
        isDebug: true,
        is64: true,
        outputType : OutputType.executable,
        versions : 
        [
            "HipMake",
            "BuildScript"
        ]
    };

    return project;
}