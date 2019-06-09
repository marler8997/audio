module audio.errors;

private __gshared bool inUnrecoverableState = false;

// A placeholder function to flag that we have entered an unrecoverable state
void setUnrecoverable(string msg, string file = __FILE__, uint line = __LINE__)
{
    import audio.log;

    if (!inUnrecoverableState)
    {
        inUnrecoverableState = true;
        logError(file, "(", line, ") the 'unrecoverable' flag has been NEWLY set with: ", msg);
    }
    else
    {
        logError(file, "(", line, ") the 'unrecoverable' flag has been set AGAIN, this time with: ", msg);
    }
    // gather logs?
    // analyze what could have happened?
    // assert?
}
