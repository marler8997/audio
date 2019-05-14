module audio.render;

import mar.passfail;
import mar.math : sin;

import audio.log;
static import audio.global;
import audio.renderformat;
import audio.dag : RootRenderNode;
import backend = audio.backend;

enum TWO_PI = 3.14159265358979 * 2;

enum RenderState
{
    off,
    attack,
    sustain,
    delay,
    release,
}

// NOTE: This Audio Renderer Uses a renderBlock function
// pointer and a RenderState.  There may be some
// renderers that don't need a render state but instead just
// change the renderBlock pointer.
struct AudioRenderer(T)
{
    void function(T* obj, void* block, const void* limit) renderBlock;
    float volume; // 0.0 to 1.0
    RenderState state;
}

struct SinOscillator
{
    AudioRenderer!SinOscillator base;
    float increment; // READONLY
    float currentPhase;
    void initialize(Format)(uint samplesPerSecond, float frequency, float volume)
    {
        this.base.renderBlock = &renderSin!Format;
        this.base.volume = volume;
        this.base.state = RenderState.sustain;
        this.increment = TWO_PI * frequency / samplesPerSecond;
        this.currentPhase = 0;
    }
}
void renderSin(Format)(SinOscillator* o, void* block, const void* limit)
{
    auto currentPhase = o.currentPhase;
    scope (exit) o.currentPhase = currentPhase;

    while(block < limit)
    {
        if (o.base.state == RenderState.release)
        {
            o.base.volume -= .0001;
            if (o.base.volume <= 0)
            {
                o.base.state = RenderState.off;
                break;
            }
        }

        Format.getSampleRef(block) += cast(Format.SampleType)(o.base.volume * sin(currentPhase) * Format.MaxAmplitude);

        currentPhase += o.increment;
        if(currentPhase > TWO_PI)
            currentPhase -= TWO_PI;

        block += Format.SampleType.sizeof;
    }
}

struct Global
{
    import mar.arraybuilder : ArrayBuilder;
    version (Windows)
    {
        import mar.windows.types : SRWLock;
        SRWLock lock;
    }
    ArrayBuilder!(AudioRenderer!void*) renderers;
    ArrayBuilder!(RootRenderNode!void*) rootRenderNodes;
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

void addRenderer(T)(AudioRenderer!T* renderer)
{
    addRenderer(cast(AudioRenderer!void*)renderer);
}
void addRenderer(AudioRenderer!void* renderer)
{
    import mar.mem : realloc;
    enterRenderCriticalSection();
    scope (exit) exitRenderCriticalSection();
    auto result = global.renderers.tryPut(renderer);
    if (result.failed)
    {
        logError("failed to add renderer: ", result);
        assert(0);
    }
    //printf("Added a renderer (there are now %d renderers)\n", currentRendererCount);
}

void addRootRenderNode(T)(RootRenderNode!T* renderer)
{
    addRootRenderNode(cast(RootRenderNode!void*)renderer);
}
void addRootRenderNode(RootRenderNode!void* renderer)
{
    import mar.mem : realloc;
    enterRenderCriticalSection();
    scope (exit) exitRenderCriticalSection();
    auto result = global.rootRenderNodes.tryPut(renderer);
    if (result.failed)
    {
        logError("failed to add renderer: ", result);
        assert(0);
    }
    //printf("Added a renderer (there are now %d renderers)\n", currentRendererCount);
}

void render(ubyte[] channels, void* buffer, const void* limit)
{
    import mar.mem : zero;
    zero(buffer, limit - buffer);
    enterRenderCriticalSection();
    scope (exit) exitRenderCriticalSection();

    //logDebug("render");
    for (size_t i = 0; i < global.renderers.length; i++)
    {
        auto renderer = global.renderers[i];

        if(renderer.state != RenderState.off)
            renderer.renderBlock(renderer, buffer, limit);

        if(renderer.state == RenderState.off)
        {
            global.renderers.removeAt(i);
            i--; // rewind
        }
    }
    for (size_t i = 0; i < global.rootRenderNodes.length; i++)
    {
        auto node = global.rootRenderNodes[i];
        node.renderNextBuffer(node, channels, buffer, limit);
    }
}

extern (Windows) uint renderThread(void* param)
{
    /*
    // Set priority
    if(!SetPriorityClass(GetCurrentProcess(), REALTIME_PRIORITY_CLASS)) {
    printf("SetPriorityClass failed\n");
    return 1;
    }
    */
    renderLoop!RenderFormat(backend.bufferSampleCount);
    return 0;
}

passfail renderLoop(Format)(uint bufferSampleCount)
{
    import mar.mem : malloc, free;

    const renderBufferSize = bufferSampleCount * audio.global.channelCount * Format.SampleType.sizeof;
    //logDebug("renderBufferSize ", renderBufferSize);
    auto renderBuffer = malloc(renderBufferSize);
    if(renderBuffer == null)
    {
        logError("malloc failed");
        return passfail.fail;
    }
    ubyte* channels = cast(ubyte*)malloc(ubyte.sizeof * audio.global.channelCount);
    if(channels == null)
    {
        logError("malloc failed");
        return passfail.fail;
    }
    foreach (ubyte i; 0 .. audio.global.channelCount)
    {
        channels[i] = i;
    }
    const result = renderLoop!Format(channels[0 .. audio.global.channelCount],
        renderBuffer, renderBuffer + renderBufferSize);
    free(renderBuffer);
    return result;
}


//version = AddDefaultRenderer;
//version = DebugDumpRender;
passfail renderLoop(Format)(ubyte[] channels, void* renderBuffer, const void* renderLimit)
{
    while(true)
    {
        //logDebug("Rendering buffer ", bufferIndex);
        //renderStartTick.update();
        //version (DebugDumpRender)
        version (AddDefaultRenderer)
        {
            static bool added = false;
            static SinOscillator o;
            if (!added)
            {
                o.init!Format(backend.samplesPerSec, 261.63, .2);
                addRenderer(&o.base);
                added = true;
            }
        }

        render(channels, renderBuffer, renderLimit);

        version (DebugDumpRender)
        {
            for (auto p = cast(Format.SampleType*)renderBuffer; p < renderLimit; p++)
            {
                logDebug(p[0]);
            }
            import mar.process : exit;
            exit(1);
        }
        if (backend.writeBuffer!Format(renderBuffer).failed)
        {
            // error already logged
            return passfail.fail;
        }
    }
}
