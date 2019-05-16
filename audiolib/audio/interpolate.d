
/**
Ultimate guide to sound interpolation, Olli Niemitalo's paper: http://yehar.com/blog/wp-content/uploads/2009/08/deip.pdf
Intepolation Methods: http://paulbourke.net/miscellaneous/interpolation/
Cubic Interpolation: https://www.paulinternet.nl/?page=bicubic
*/
module audio.interpolate;

import audio.renderformat;

struct DropSample
{
    static RenderFormat.SamplePoint interpolate(const(RenderFormat.SamplePoint)[] points, size_t pointsOffset)
    {
        return points[pointsOffset];
    }
}

struct Linear
{
    static RenderFormat.SamplePoint interpolate(const(RenderFormat.SamplePoint)[] points,
        size_t pointsOffset, float time, ubyte channelCount)
    {
        const p0 = points[pointsOffset + channelCount];
        const p1 = (pointsOffset + 2*channelCount < points.length) ?
            points[pointsOffset + 2*channelCount] : p0;
        return p0 + (p1 - p0) * time;
    }
}

struct Parabolic
{
    static RenderFormat.SamplePoint interpolate(const(RenderFormat.SamplePoint)[] points,
        size_t pointsOffset, float time, ubyte channelCount)
    {
        const p0 = points[pointsOffset];
        auto p1 = (pointsOffset + channelCount < points.length) ?
            points[pointsOffset + channelCount] : p0;
        auto p2 = (pointsOffset + 2*channelCount < points.length) ?
            points[pointsOffset + 2*channelCount] : p1;
        return p0 + time / 2.0 * (
            -3*p0 + 4*p1 - p2 + time * (
                p0 - 2 * p1 + p2
            )
        );
    }
}

struct OlliOptimal6po5o
{
    static RenderFormat.SamplePoint interpolate(const(RenderFormat.SamplePoint)[] points,
        size_t pointsOffset, float time, ubyte channelCount)
    {
        const p0 = points[pointsOffset];
        const p1 = (pointsOffset + channelCount < points.length) ?
            points[pointsOffset + channelCount] : p0;
        const p2 = (pointsOffset + 2*channelCount < points.length) ?
            points[pointsOffset + 2*channelCount] : p1;

        const pneg1 = (pointsOffset >= channelCount) ?
            points[pointsOffset - channelCount] : p0;
        const pneg2 = (pointsOffset >= 2*channelCount) ?
            points[pointsOffset - 2*channelCount] : pneg1;
        const pneg3 = (pointsOffset >= 3*channelCount) ?
            points[pointsOffset - 3*channelCount] : pneg2;

        const z = time - 1/2.0;
        const even1 = p0+pneg1, odd1 = p0-pneg1;
        const even2 = p1+pneg2, odd2 = p1-pneg2;
        const even3 = p2+pneg3, odd3 = p2-pneg3;
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
