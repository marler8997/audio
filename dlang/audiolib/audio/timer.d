module audio.timer;

import mar.passfail;

import audio.log;

version (Windows)
{
    private __gshared long performanceFrequency;
}
passfail timerInit()
{
    version (Windows)
    {
        import mar.windows.kernel32 : QueryPerformanceFrequency;
        if(QueryPerformanceFrequency(&performanceFrequency).failed)
        {
            logError("QueryPerformanceFrequency failed");
            return passfail.fail;
        }
    }
    //logDebug("performance frequency: ", performanceFrequency);
    return passfail.pass;
}

struct Timer
{
    version (Windows)
    {
        import mar.windows.kernel32 : QueryPerformanceCounter;

        long startTime;
    }
    void start()
    {
        version (Windows)
        {
            QueryPerformanceCounter(&startTime);
        }
    }
    auto getElapsedStop()
    {
        version (Windows)
        {
            long now;
            QueryPerformanceCounter(&now);
            return now - startTime;
        }
    }
    auto getElapsedRestart()
    {
        version (Windows)
        {
            long now;
            QueryPerformanceCounter(&now);
            auto result = now - startTime;
            startTime = now;
        }
        return result;
    }
}
