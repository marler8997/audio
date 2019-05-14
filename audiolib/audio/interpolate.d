
/**
Ultimate guide to sound interpolation, Olli Niemitalo's paper: http://yehar.com/blog/wp-content/uploads/2009/08/deip.pdf
Intepolation Methods: http://paulbourke.net/miscellaneous/interpolation/
Cubic Interpolation: https://www.paulinternet.nl/?page=bicubic
*/
module audio.interpolate;

import audio.renderformat;

struct DropSample
{
    static RenderFormat.SampleType interpolate(const(RenderFormat.SampleType)[] samples, size_t s0Index)
    {
        return samples[s0Index];
    }
}

struct Linear
{
    static RenderFormat.SampleType interpolate(const(RenderFormat.SampleType)[] samples,
        size_t s0Index, float time, ubyte channelCount)
    {
        const s0 = samples[s0Index];
        const s1 = (s0Index + channelCount < samples.length) ?
            samples[s0Index + channelCount] : s0;
        return s0 + (s1 - s0) * time;
    }
}

struct Parabolic
{
    static RenderFormat.SampleType interpolate(const(RenderFormat.SampleType)[] samples,
        size_t s0Index, float time, ubyte channelCount)
    {
        const s0 = samples[s0Index];
        auto s1 = (s0Index + channelCount < samples.length) ?
            samples[s0Index + channelCount] : s0;
        auto s2 = (s0Index + 2*channelCount < samples.length) ?
            samples[s0Index + 2*channelCount] : s1;
        return s0 + time / 2.0 * (
            -3*s0 + 4*s1 - s2 + time * (
                s0 - 2 * s1 + s2
            )
        );
    }
}

struct OlliOptimal6po5o
{
    static RenderFormat.SampleType interpolate(const(RenderFormat.SampleType)[] samples,
        size_t s0Index, float time, ubyte channelCount)
    {
        const s0 = samples[s0Index];
        const s1 = (s0Index + channelCount < samples.length) ?
            samples[s0Index + channelCount] : s0;
        const s2 = (s0Index + 2*channelCount < samples.length) ?
            samples[s0Index + 2*channelCount] : s1;

        const sneg1 = (s0Index >= channelCount) ?
            samples[s0Index - channelCount] : s0;
        const sneg2 = (s0Index >= 2*channelCount) ?
            samples[s0Index - 2*channelCount] : sneg1;
        const sneg3 = (s0Index >= 3*channelCount) ?
            samples[s0Index - 3*channelCount] : sneg2;

        const z = time - 1/2.0;
        const even1 = s0+sneg1, odd1 = s0-sneg1;
        const even2 = s1+sneg2, odd2 = s1-sneg2;
        const even3 = s2+sneg3, odd3 = s2-sneg3;
        const c0 = even1*0.40513396007145713 + even2*0.09251794438424393
        + even3*0.00234806603570670;
        const c1 = odd1*0.28342806338906690 + odd2*0.21703277024054901
        + odd3*0.01309294748731515;
        const c2 = even1*-0.191337682540351941 + even2*0.16187844487943592
        + even3*0.02946017143111912;
        const c3 = odd1*-0.16471626190554542 + odd2*-0.00154547203542499
        + odd3*0.03399271444851909;
        const c4 = even1*0.03845798729588149 + even2*-0.05712936104242644
        + even3*0.01866750929921070;
        const c5 = odd1*0.04317950185225609 + odd2*-0.01802814255926417
        + odd3*0.00152170021558204;
        return ((((c5*z+c4)*z+c3)*z+c2)*z+c1)*z+c0;
    }
}
