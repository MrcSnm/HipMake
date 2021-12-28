# HipMake
    Project made to use together with dub. It aims to bring a faster building system with a more understandable code.

## How it works
    The best way to make building it faster is by caching the compilation command and executing it plainly. This is exactly what this build system aims to do.

## How to use

    You need to configure an environment variable called HIPMAKE_SOURCE_PATH, this variable must contain a path of a clone of this repository.

    Create a project.d file in where your willing to call the build command, and call rdmd %HIPMAKE_SOURCE_PATH%/source/app.d.

    This project.d must contain a function `Project getProject()` which must be resolved on CTFE.

    This is the following example on how a sample project.d should be:

```d
module project;
import buildapi;

Project getProject()
{
    Project project = {
        name: "projectName",
        sourceEntryPoint: "source/app.d",
        dependencies : null,
        importDirectories : [
            "source"
        ],
        configurations : null, //Current unused
        isDebug: true,
        is64: true,
        outputType : OutputType.library,
        versions : 
        [
            "OurVersion"
        ]
    };

    return project;
}
```

    Pass `command` as an argument if you wish to output a commands.txt on your .hipmake folder with the command it is executing.

## Advantages over Dub

- Caches the command, starting the compilation a lot earlier
- The project configuration is made in D. That means you can use logical branches, use version statements for conditionals(currently only builtin) and you're using a programming language instead of a markup.

## Disadvantages over Dub

- Not a package manager
- It doesn't have the concept of caching per project
- It still does not caches the current build

### Q: Why another build system?
    Dub built a project in 1.2 second in a project that should be built in 0.2 seconds, with only one dependency. This iteration time is pretty important for when using D as a native scripting language, it does a lot of difference. 

### Q: Is that a package manager like dub?
    No, package management requires a lot of tooling, which is not intended on this fast project.

### Q: How can I help on this project?
    You can do it by issuing pull requests for the current missing features:

    - More compiler options
    - Optimal way to do anything on this project
    - Package Management (This could be a lot of effort, probably a dub integration would be better (then cache the new command))
    - Dub project generator

## Next Steps

- Dub project generator (As it can be fairly useful)

