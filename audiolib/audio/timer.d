// probably move to mar?
module audio.timer;

struct Timer
{
    long startTime;
    void start()
    {
        QueryPerformanceCounter(&startTime);
    }
    auto getElapsedStop()
    {
        long now;
        QueryPerformanceCounter(&now);
        return now - startTime;
    }
    auto getElapsedRestart()
    {
        long now;
        QueryPerformanceCounter(&now);
        auto result = now - startTime;
        startTime = now;
        return result;
    }
}
