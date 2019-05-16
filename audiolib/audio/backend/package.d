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
    passfail open()
    {
        switch (audio.global.backend)
        {
            case AudioBackend.waveout: return audio.backend.waveout.open();
            case AudioBackend.wasapi: return audio.backend.wasapi.open();
            default: assert(0);
        }
    }
    passfail close()
    {
        switch (audio.global.backend)
        {
            case AudioBackend.waveout: return audio.backend.waveout.close();
            case AudioBackend.wasapi: return audio.backend.wasapi.close();
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
    passfail open()
    {
        switch (audio.global.backend)
        {
            case AudioBackend.placeholder: logError("no backend for non-windows implemented"); return passfail.fail;
            default: assert(0);
        }
    }
    passfail close()
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
