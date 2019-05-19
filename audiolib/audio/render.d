module audio.render;

import mar.from;
import mar.passfail;
import mar.math : sin;

import audio.log;
static import audio.global;
static import audio.backend;
import audio.renderformat;
import audio.dag : AudioGenerator;

struct Global
{
    import mar.arraybuilder : ArrayBuilder;
    version (Windows)
    {
        import mar.windows : SRWLock;
        SRWLock lock;
    }
    //
    // The generators connected directly to the audio backend
    //
    ArrayBuilder!(AudioGenerator!void*) rootAudioGenerators;
    void* backendOutputNode; // just leave as null for now
}
__gshared Global global;

passfail renderPlatformInit()
{
    version (Windows)
    {
        import mar.windows.kernel32 : InitializeSRWLock;
        InitializeSRWLock(&global.lock);
    }
    return passfail.pass;
}

final void enterRenderCriticalSection()
{
    pragma(inline, true);

    version (Windows)
    {
        import mar.windows.kernel32 : AcquireSRWLockExclusive;
        AcquireSRWLockExclusive(&global.lock);
    }
}
final void exitRenderCriticalSection()
{
    pragma(inline, true);

    version (Windows)
    {
        import mar.windows.kernel32 : ReleaseSRWLockExclusive;
        ReleaseSRWLockExclusive(&global.lock);
    }
}

auto addRootAudioGenerator(T)(AudioGenerator!T* generator)
{
    auto result = addRootAudioGenerator(cast(AudioGenerator!void*)generator);
    return result;
}
passfail addRootAudioGenerator(AudioGenerator!void* generator)
{
    import audio.errors;

    if (generator.connectOutputNode(generator, global.backendOutputNode).failed)
    {
        // error already logged
        return passfail.fail;
    }
    enterRenderCriticalSection();
    scope (exit) exitRenderCriticalSection();
    auto result = global.rootAudioGenerators.tryPut(generator);
    if (result.failed)
    {
        logError("failed to add audio generator: ", result);
        if (generator.disconnectOutputNode(generator, global.backendOutputNode).failed)
            setUnrecoverable("failed to disconnect main output node from an audio generator");

        return passfail.fail;
    }
    return passfail.pass;
}

mixin from!"mar.thread".threadEntryMixin!("renderThread", q{
    import mar.mem : malloc, free;
    import mar.thread : ThreadEntryResult;

    /*
    // Set priority
    if(!SetPriorityClass(GetCurrentProcess(), REALTIME_PRIORITY_CLASS)) {
    printf("SetPriorityClass failed\n");
    return 1;
    }
    */
    /*
    {
        import mar.windows : ThreadPriority;
        import mar.windows.kernel32 : GetCurrentThread, GetThreadPriority, SetThreadPriority;
        const thread = GetCurrentThread();
        const priority = GetThreadPriority(thread);
        logDebug("ThreadPriority=", priority);
        if (priority < ThreadPriority.timeCritical)
        {
            logDebug("Setting thread priority to ", ThreadPriority.timeCritical);
            if (SetThreadPriority(thread, ThreadPriority.timeCritical).failed)
            {
                logError("Failed to set thread priority, e=", GetLastError());
                return 1; // fail
            }
        }
    }
    */

    const renderBufferSize = audio.global.bufferSampleFrameCount *
        audio.global.channelCount * RenderFormat.SamplePoint.sizeof;
    //logDebug("renderBufferSize ", renderBufferSize);
    auto renderBuffer = malloc(renderBufferSize);
    if(renderBuffer == null)
    {
        logError("malloc failed");
        return ThreadEntryResult.fail;
    }
    ubyte* channels = cast(ubyte*)malloc(ubyte.sizeof * audio.global.channelCount);
    if(channels == null)
    {
        logError("malloc failed");
        return ThreadEntryResult.fail;
    }
    foreach (ubyte i; 0 .. audio.global.channelCount)
    {
        channels[i] = i;
    }
    audio.backend.startingRenderLoop().enforce();
    const result = renderLoop(channels[0 .. audio.global.channelCount],
        cast(RenderFormat.SamplePoint*)renderBuffer,
        cast(RenderFormat.SamplePoint*)(renderBuffer + renderBufferSize));
    audio.backend.stoppingRenderLoop();
    free(renderBuffer);
    return result.failed ? ThreadEntryResult.fail : ThreadEntryResult.pass;
});


//version = DebugDumpRender;
passfail renderLoop(ubyte[] channels, RenderFormat.SamplePoint* renderBuffer, const RenderFormat.SamplePoint* renderLimit)
{
    render(channels, renderBuffer, renderLimit);
    version (DebugDumpRender)
    {
        for (auto p = renderBuffer; p < renderLimit; p += audio.global.channelCount)
        {
            // only log one channel right now
            if (audio.global.channelCount == 1)
                logDebug(p[0]);
            if (audio.global.channelCount == 2)
                logDebug(p[0], "    ", p[1]);
        }
        import mar.process : exit;
        exit(1);
    }
    audio.backend.writeFirstBuffer(renderBuffer);

    while(true)
    {
        //logDebug("Rendering buffer ", bufferIndex);
        //renderStartTick.update();
        render(channels, renderBuffer, renderLimit);
        if (audio.backend.writeBuffer(renderBuffer).failed)
        {
            // error already logged
            return passfail.fail;
        }
    }
}

void render(ubyte[] channels, RenderFormat.SamplePoint* buffer, const RenderFormat.SamplePoint* limit)
{
    import mar.mem : zero;
    //
    // TODO: if there are any generators that have a "set" function, then I
    //       could use that first and skip zeroing memory
    //
    zero(buffer, (limit - buffer) * buffer[0].sizeof);

    enterRenderCriticalSection();
    scope (exit) exitRenderCriticalSection();

    //logDebug("render");
    for (size_t i = 0; i < global.rootAudioGenerators.length; i++)
    {
        auto generator = global.rootAudioGenerators[i];
        generator.mix(generator, channels, buffer, limit);
    }
    // Notify each node that the render is finished
    for (size_t i = 0; i < global.rootAudioGenerators.length; i++)
    {
        auto generator = global.rootAudioGenerators[i];
        generator.renderFinished(generator, global.backendOutputNode);
    }
}