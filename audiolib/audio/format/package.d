module audio.format;

import mar.passfail;

import audio.log;

enum SampleKind { int_, float_ }

struct Pcm16Format
{
    alias SampleType = short;
    enum MaxAmplitude = short.max;
    static ref short getSampleRef(void* block)
    {
        return (cast(short*)block)[0];
    }
    static void monoToStereo(void* dst, void* src, size_t sampleCount)
    {
        pragma(inline, true);
        monoToStereo(cast(uint*)dst, cast(ushort*)src, sampleCount);
    }
    static void monoToStereo(uint* dst, ushort* src, size_t sampleCount)
    {
        foreach (i; 0 .. sampleCount)
        {
            dst[i] = cast(uint)src[i] << 16 | src[i];
        }
    }
}
struct FloatFormat
{
    alias SampleType = float;
    enum MaxAmplitude = 1.0f;
    static ref float getSampleRef(void* block)
    {
        return (cast(float*)block)[0];
    }
    static void monoToStereo(void* dst, void* src, size_t sampleCount)
    {
        pragma(inline, true);
        monoToStereo(cast(float*)dst, cast(float*)src, sampleCount);
    }
    static void monoToStereo(float* dst, float* src, size_t sampleCount)
    {
        foreach (i; 0 .. sampleCount)
        {
            dst[2*i+0] = src[i];
            dst[2*i+1] = src[i];
        }
    }
    static passfail copyConvert(float* dst, void* src, SampleKind kind, uint samplesPerSec, size_t sampleCount, ubyte channelCount, ubyte sampleSize)
    {
        static import audio.global;
        if (samplesPerSec != audio.global.samplesPerSec)
        {
            logError("Converting between frequencies ", samplesPerSec, " to ",
                audio.global.samplesPerSec, " is not implemented");
            return passfail.fail;
        }
        foreach (i; 0 .. sampleCount)
        {
            foreach (channel; 0 .. channelCount)
            {
                switch(kind)
                {
                    case SampleKind.int_:
                        if (sampleSize == 2)
                        {
                            import mar.serialize : deserializeBE;
                            // TODO: we don't know if the sample is big endian yet
                            dst[0] = cast(float)deserializeBE!short(src) / 32768.0;
                            //if (channel == 0)
                            //    logDebug(*cast(short*)src, " > ", dst[0]);
                        }
                        else
                        {
                            logError("format not supported yet");
                            return passfail.fail;
                        }
                        break;
                    case SampleKind.float_:
                        logError("format not supported yet");
                        return passfail.fail;
                    default:
                        logError("codebug");
                        return passfail.fail;
                }
                src += sampleSize;
                dst++;
            }
        }
        return passfail.pass;
    }
}
