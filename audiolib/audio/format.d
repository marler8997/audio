module audio.format;

//alias CurrentFormat = Pcm16Format;
alias CurrentFormat = FloatFormat;

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
}
