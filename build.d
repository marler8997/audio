#!/usr/bin/env rund
import core.stdc.stdlib : exit;
import std.path : buildPath, dirName;
import std.file : exists;
import std.stdio;

void run(string[] args)
{
    import std.process;
    writefln("[RUN] %s", args);
    auto proc = spawnProcess(args);
    const result = wait(proc);
    if (result != 0)
    {
        writefln("Error: last command exited with code %s", result);
        exit(1);
    }
}
string findprog(string prog)
{
    import std.process;
    import std.string : lineSplitter, strip;
    version (Windows)
        const result = execute(["where", prog]);
    else
        const result = execute(["which", prog]);
    if (result.status != 0)
    {

        writefln("Failed to find program '%s'", prog);
        writeln(result.output);
        exit(1);
    }
    return result.output.lineSplitter.front.strip();
}

string relpath(T...)(T parts)
{
    return buildPath(dirName(__FILE_FULL_PATH__), parts);
}
string gitpath(T...)(T parts)
{
    import std.path : buildPath, dirName;
    return buildPath(dirName(dirName(__FILE_FULL_PATH__)), parts);
}

int main(string[] args)
{
    auto dc = findprog("dmd");
    
    const marRepo = gitpath("mar");
    if (!exists(marRepo))
    {
        writefln("Error: mar repository '%s' does not exist", marRepo);
        exit(1);
    }
    const marInclude = buildPath(marRepo, "src");

    run([dc
        , "-betterC"
        ,"-g", "-debug"
        // NOTE: using m32mscoff allows you to debug with visual studio
        //       however, it requires access to the MSVC linker
        //, "-m32mscoff"
        ,"-of=" ~ relpath("audio.exe")
        , "-I=" ~ marInclude
        , "-I=" ~ relpath("audiolib")
        , "-i", relpath("main.d")
    ]);
    return 0;
}