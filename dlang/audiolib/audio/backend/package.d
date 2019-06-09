module audio.backend;

import mar.passfail;

static import audio.global;

version (Windows)
{
    enum AudioBackend
    {
        waveout,
        wasapi,
    }
    static import audio.backend.waveout;
    static import audio.backend.wasapi;
    //
    // Perform any setup that could change global parameters
    //
    passfail setup()
    {
        switch (audio.global.backend)
        {
            case AudioBackend.waveout: return audio.backend.waveout.setup();
            case AudioBackend.wasapi: return audio.backend.wasapi.setup();
            default: assert(0);
        }
    }
    //
    // About to render the first buffer
    //
    passfail startingRenderLoop()
    {
        switch (audio.global.backend)
        {
            case AudioBackend.waveout: return audio.backend.waveout.startingRenderLoop();
            case AudioBackend.wasapi: return audio.backend.wasapi.startingRenderLoop();
            default: assert(0);
        }
    }
    passfail stoppingRenderLoop()
    {
        switch (audio.global.backend)
        {
            case AudioBackend.waveout: return audio.backend.waveout.stoppingRenderLoop();
            case AudioBackend.wasapi: return audio.backend.wasapi.stoppingRenderLoop();
            default: assert(0);
        }
    }
    passfail writeFirstBuffer(void* renderBuffer)
    {
        switch (audio.global.backend)
        {
            case AudioBackend.waveout: return audio.backend.waveout.writeFirstBuffer(renderBuffer);
            case AudioBackend.wasapi: return audio.backend.wasapi.writeFirstBuffer(renderBuffer);
            default: assert(0);
        }
    }
    passfail writeBuffer(void* renderBuffer)
    {
        switch (audio.global.backend)
        {
            case AudioBackend.waveout: return audio.backend.waveout.writeBuffer(renderBuffer);
            case AudioBackend.wasapi: return audio.backend.wasapi.writeBuffer(renderBuffer);
            default: assert(0);
        }
    }
}
else
{
    enum AudioBackend
    {
        placeholder,
    }
    passfail setup()
    {
        switch (audio.global.backend)
        {
            case AudioBackend.placeholder: logError("no backend for non-windows implemented"); return passfail.fail;
            default: assert(0);
        }
    }
    passfail startingRenderLoop()
    {
        switch (audio.global.backend)
        {
            case AudioBackend.placeholder: logError("no backend for non-windows implemented"); return passfail.fail;
            default: assert(0);
        }
    }
    passfail stoppingRenderLoop()
    {
        switch (audio.global.backend)
        {
            case AudioBackend.placeholder: logError("no backend for non-windows implemented"); return passfail.fail;
            default: assert(0);
        }
    }
    passfail writeFirstBuffer(void* renderBuffer)
    {
        switch (audio.global.backend)
        {
            case AudioBackend.placeholder: logError("no backend for non-windows implemented"); return passfail.fail;
            default: assert(0);
        }
    }
    passfail writeBuffer(void* renderBuffer)
    {
        switch (audio.global.backend)
        {
            case AudioBackend.placeholder: logError("no backend for non-windows implemented"); return passfail.fail;
            default: assert(0);
        }
    }
}
