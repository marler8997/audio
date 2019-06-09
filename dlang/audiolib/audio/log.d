module audio.log;

void logDebug(T...)(T args)
{
    import mar.stdio : stdout;
    stdout.writeln("[DEBUG] ", args);
}
void flushDebug()
{
    import mar.stdio : stdout;
    stdout.tryFlush();
}

void logError(T...)(T args)
{
    import mar.stdio : stderr;
    stderr.writeln(args);
}

void flushErrors()
{
    import mar.stdio : stderr;
    stderr.tryFlush();
}


void log(T...)(T args)
{
    import mar.stdio : stdout;
    stdout.writeln(args);
}
void flushLog()
{
    import mar.stdio : stdout;
    stdout.tryFlush();
}
