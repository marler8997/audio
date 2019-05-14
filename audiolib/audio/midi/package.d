module audio.midi;

enum MidiNote : ubyte
{
    none = 0,

    anegative1 = 9,
    asharpnegative1 = 10,
    bnegative1 = 11,
    c0      =  12,
    csharp0 =  13,
    d0      =  14,
    dsharp0 =  15,
    e0      =  16,
    f0      =  17,
    fsharp0 =  18,
    g0      =  19,
    gsharp0 =  20,
    a0      =  21,
    asharp0 =  22,
    b0      =  23,
    c1      =  24,
    csharp1 =  25,
    d1      =  26,
    dsharp1 =  27,
    e1      =  28,
    f1      =  29,
    fsharp1 =  30,
    g1      =  31,
    gsharp1 =  32,
    a1      =  33,
    asharp1 =  34,
    b1      =  35,
    c2      =  36,
    csharp2 =  37,
    d2      =  38,
    dsharp2 =  39,
    e2      =  40,
    f2      =  41,
    fsharp2 =  42,
    g2      =  43,
    gsharp2 =  44,
    a2      =  45,
    asharp2 =  46,
    b2      =  47,
    c3      =  48,
    csharp3 =  49,
    d3      =  50,
    dsharp3 =  51,
    e3      =  52,
    f3      =  53,
    fsharp3 =  54,
    g3      =  55,
    gsharp3 =  56,
    a3      =  57,
    asharp3 =  58,
    b3      =  59,
    c4      =  60,
    csharp4 =  61,
    d4      =  62,
    dsharp4 =  63,
    e4      =  64,
    f4      =  65,
    fsharp4 =  66,
    g4      =  67,
    gsharp4 =  68,
    a4      =  69,
    asharp4 =  70,
    b4      =  71,
    c5      =  72,
    csharp5 =  73,
    d5      =  74,
    dsharp5 =  75,
    e5      =  76,
    f5      =  77,
    fsharp5 =  78,
    g5      =  79,
    gsharp5 =  80,
    a5      =  81,
    asharp5 =  82,
    b5      =  83,
    c6      =  84,
    csharp6 =  85,
    d6      =  86,
    dsharp6 =  87,
    e6      =  88,
    f6      =  89,
    fsharp6 =  90,
    g6      =  91,
    gsharp6 =  92,
    a6      =  93,
    asharp6 =  94,
    b6      =  95,
    c7      =  96,
    csharp7 =  97,
    d7      =  98,
    dsharp7 =  99,
    e7      = 100,
    f7      = 101,
    fsharp7 = 102,
    g7      = 103,
    gsharp7 = 104,
    a7      = 105,
    asharp7 = 106,
    b7      = 107,
    c8      = 108,
    csharp8 = 109,
    d8      = 110,
    dsharp8 = 111,
    e8      = 112,
    f8      = 113,
    fsharp8 = 114,
    g8      = 115,
    gsharp8 = 116,
    a8      = 117,
    asharp8 = 118,
    b8      = 119,
    c9      = 120,
    csharp9 = 121,
    d9      = 122,
    dsharp9 = 123,
    e9      = 124,
    f9      = 125,
    fsharp9 = 126,
    g9      = 127,
    //gsharp9 = 127,
}

__gshared immutable float[256] stdFreq = [
     0               :    8.18,
     1               :    8.66,
     2               :    9.18,
     3               :    9.72,
     4               :   10.30,
     5               :   10.91,
     6               :   11.56,
     7               :   12.25,
     8               :   12.98,
     9               :   13.75,
    10               :   14.57,
    11               :   15.43,
    MidiNote.c0      :   16.35,
    MidiNote.csharp0 :   17.32,
    MidiNote.d0      :   18.35,
    MidiNote.dsharp0 :   19.45,
    MidiNote.e0      :   20.60,
    MidiNote.f0      :   21.83,
    MidiNote.fsharp0 :   23.12,
    MidiNote.g0      :   24.50,
    MidiNote.gsharp0 :   25.96,
    MidiNote.a0      :   27.50,
    MidiNote.asharp0 :   29.14,
    MidiNote.b0      :   30.87,
    MidiNote.c1      :   32.70,
    MidiNote.csharp1 :   34.65,
    MidiNote.d1      :   36.71,
    MidiNote.dsharp1 :   38.89,
    MidiNote.e1      :   41.20,
    MidiNote.f1      :   43.65,
    MidiNote.fsharp1 :   46.25,
    MidiNote.g1      :   49.00,
    MidiNote.gsharp1 :   51.91,
    MidiNote.a1      :   55.00,
    MidiNote.asharp1 :   58.27,
    MidiNote.b1      :   61.74,
    MidiNote.c2      :   65.41,
    MidiNote.csharp2 :   69.30,
    MidiNote.d2      :   73.42,
    MidiNote.dsharp2 :   77.78,
    MidiNote.e2      :   82.41,
    MidiNote.f2      :   87.31,
    MidiNote.fsharp2 :   92.50,
    MidiNote.g2      :   98.00,
    MidiNote.gsharp2 :  103.83,
    MidiNote.a2      :  110.00,
    MidiNote.asharp2 :  116.54,
    MidiNote.b2      :  123.47,
    MidiNote.c3      :  130.81,
    MidiNote.csharp3 :  138.59,
    MidiNote.d3      :  146.83,
    MidiNote.dsharp3 :  155.56,
    MidiNote.e3      :  164.81,
    MidiNote.f3      :  174.61,
    MidiNote.fsharp3 :  185.00,
    MidiNote.g3      :  196.00,
    MidiNote.gsharp3 :  207.65,
    MidiNote.a3      :  220.00,
    MidiNote.asharp3 :  233.08,
    MidiNote.b3      :  246.94,
    MidiNote.c4      :  261.63,
    MidiNote.csharp4 :  277.18,
    MidiNote.d4      :  293.66,
    MidiNote.dsharp4 :  311.13,
    MidiNote.e4      :  329.63,
    MidiNote.f4      :  349.23,
    MidiNote.fsharp4 :  369.99,
    MidiNote.g4      :  392.00,
    MidiNote.gsharp4 :  415.30,
    MidiNote.a4      :  440.00,
    MidiNote.asharp4 :  466.16,
    MidiNote.b4      :  493.88,
    MidiNote.c5      :  523.25,
    MidiNote.csharp5 :  554.37,
    MidiNote.d5      :  587.33,
    MidiNote.dsharp5 :  622.25,
    MidiNote.e5      :  659.25,
    MidiNote.f5      :  698.46,
    MidiNote.fsharp5 :  739.99,
    MidiNote.g5      :  783.99,
    MidiNote.gsharp5 :  830.61,
    MidiNote.a5      :  880.00,
    MidiNote.asharp5 :  932.33,
    MidiNote.b5      :  987.77,
    MidiNote.c6      : 1046.50,
    MidiNote.csharp6 : 1108.73,
    MidiNote.d6      : 1174.66,
    MidiNote.dsharp6 : 1244.51,
    MidiNote.e6      : 1318.51,
    MidiNote.f6      : 1396.91,
    MidiNote.fsharp6 : 1479.98,
    MidiNote.g6      : 1567.98,
    MidiNote.gsharp6 : 1661.22,
    MidiNote.a6      : 1760.00,
    MidiNote.asharp6 : 1864.66,
    MidiNote.b6      : 1975.53,
    MidiNote.c7      : 2093.00,
    MidiNote.csharp7 : 2217.46,
    MidiNote.d7      : 2349.32,
    MidiNote.dsharp7 : 2489.02,
    MidiNote.e7      : 2637.02,
    MidiNote.f7      : 2793.83,
    MidiNote.fsharp7 : 2959.96,
    MidiNote.g7      : 3135.96,
    MidiNote.gsharp7 : 3322.44,
    MidiNote.a7      : 3520.00,
    MidiNote.asharp7 : 3729.31,
    MidiNote.b7      : 3951.07,
    MidiNote.c8      : 4186.01,
    MidiNote.csharp8 : 4434.92,
    MidiNote.d8      : 4698.63,
    MidiNote.dsharp8 : 4978.03,
    MidiNote.e8      : 5274.04,
    MidiNote.f8      : 5587.65,
    MidiNote.fsharp8 : 5919.91,
    MidiNote.g8      : 6271.93,
    MidiNote.gsharp8 : 6644.88,
    MidiNote.a8      : 7040.00,
    MidiNote.asharp8 : 7458.62,
    MidiNote.b8      : 7902.13,
    MidiNote.c9      : 8372.02,
    MidiNote.csharp9 : 8869.84,
    MidiNote.d9      : 9397.27,
    MidiNote.dsharp9 : 9956.06,
    MidiNote.e9      : 10548.08,
    MidiNote.f9      : 11175.30,
    MidiNote.fsharp9 : 11839.82,
    MidiNote.g9      : 12543.85,
    //MidiNote.gsharp9 : 13289.75,
];

__gshared immutable float[256] justC4Freq = [
     0               : 0,
     1               : 0,
     2               : 0,
     3               : 0,
     4               : 0,
     5               : 0,
     6               : 0,
     7               : 0,
     8               : 0,
     9               : 0,
    10               : 0,
    11               : 0,
    MidiNote.c0      : stdFreq[MidiNote.c4] * 0.0625,
    MidiNote.csharp0 : stdFreq[MidiNote.c4] * 0.0625 * 1.0417,
    MidiNote.d0      : stdFreq[MidiNote.c4] * 0.0625 * 1.1250,
    MidiNote.dsharp0 : stdFreq[MidiNote.c4] * 0.0625 * 1.2000,
    MidiNote.e0      : stdFreq[MidiNote.c4] * 0.0625 * 1.2500,
    MidiNote.f0      : stdFreq[MidiNote.c4] * 0.0625 * 1.3333,
    MidiNote.fsharp0 : stdFreq[MidiNote.c4] * 0.0625 * 1.4063,
    MidiNote.g0      : stdFreq[MidiNote.c4] * 0.0625 * 1.5000,
    MidiNote.gsharp0 : stdFreq[MidiNote.c4] * 0.0625 * 1.6000,
    MidiNote.a0      : stdFreq[MidiNote.c4] * 0.0625 * 1.6667,
    MidiNote.asharp0 : stdFreq[MidiNote.c4] * 0.0625 * 1.8000,
    MidiNote.b0      : stdFreq[MidiNote.c4] * 0.0625 * 1.8750,
    MidiNote.c1      : stdFreq[MidiNote.c4] * 0.125,
    MidiNote.csharp1 : stdFreq[MidiNote.c4] * 0.125 * 1.0417,
    MidiNote.d1      : stdFreq[MidiNote.c4] * 0.125 * 1.1250,
    MidiNote.dsharp1 : stdFreq[MidiNote.c4] * 0.125 * 1.2000,
    MidiNote.e1      : stdFreq[MidiNote.c4] * 0.125 * 1.2500,
    MidiNote.f1      : stdFreq[MidiNote.c4] * 0.125 * 1.3333,
    MidiNote.fsharp1 : stdFreq[MidiNote.c4] * 0.125 * 1.4063,
    MidiNote.g1      : stdFreq[MidiNote.c4] * 0.125 * 1.5000,
    MidiNote.gsharp1 : stdFreq[MidiNote.c4] * 0.125 * 1.6000,
    MidiNote.a1      : stdFreq[MidiNote.c4] * 0.125 * 1.6667,
    MidiNote.asharp1 : stdFreq[MidiNote.c4] * 0.125 * 1.8000,
    MidiNote.b1      : stdFreq[MidiNote.c4] * 0.125 * 1.8750,
    MidiNote.c2      : stdFreq[MidiNote.c4] * 0.25,
    MidiNote.csharp2 : stdFreq[MidiNote.c4] * 0.25 * 1.0417,
    MidiNote.d2      : stdFreq[MidiNote.c4] * 0.25 * 1.1250,
    MidiNote.dsharp2 : stdFreq[MidiNote.c4] * 0.25 * 1.2000,
    MidiNote.e2      : stdFreq[MidiNote.c4] * 0.25 * 1.2500,
    MidiNote.f2      : stdFreq[MidiNote.c4] * 0.25 * 1.3333,
    MidiNote.fsharp2 : stdFreq[MidiNote.c4] * 0.25 * 1.4063,
    MidiNote.g2      : stdFreq[MidiNote.c4] * 0.25 * 1.5000,
    MidiNote.gsharp2 : stdFreq[MidiNote.c4] * 0.25 * 1.6000,
    MidiNote.a2      : stdFreq[MidiNote.c4] * 0.25 * 1.6667,
    MidiNote.asharp2 : stdFreq[MidiNote.c4] * 0.25 * 1.8000,
    MidiNote.b2      : stdFreq[MidiNote.c4] * 0.25 * 1.8750,
    MidiNote.c3      : stdFreq[MidiNote.c4] * 0.5,
    MidiNote.csharp3 : stdFreq[MidiNote.c4] * 0.5 * 1.0417,
    MidiNote.d3      : stdFreq[MidiNote.c4] * 0.5 * 1.1250,
    MidiNote.dsharp3 : stdFreq[MidiNote.c4] * 0.5 * 1.2000,
    MidiNote.e3      : stdFreq[MidiNote.c4] * 0.5 * 1.2500,
    MidiNote.f3      : stdFreq[MidiNote.c4] * 0.5 * 1.3333,
    MidiNote.fsharp3 : stdFreq[MidiNote.c4] * 0.5 * 1.4063,
    MidiNote.g3      : stdFreq[MidiNote.c4] * 0.5 * 1.5000,
    MidiNote.gsharp3 : stdFreq[MidiNote.c4] * 0.5 * 1.6000,
    MidiNote.a3      : stdFreq[MidiNote.c4] * 0.5 * 1.6667,
    MidiNote.asharp3 : stdFreq[MidiNote.c4] * 0.5 * 1.8000,
    MidiNote.b3      : stdFreq[MidiNote.c4] * 0.5 * 1.8750,
    MidiNote.c4      : stdFreq[MidiNote.c4],
    MidiNote.csharp4 : stdFreq[MidiNote.c4] * 1.0417,
    MidiNote.d4      : stdFreq[MidiNote.c4] * 1.1250,
    MidiNote.dsharp4 : stdFreq[MidiNote.c4] * 1.2000,
    MidiNote.e4      : stdFreq[MidiNote.c4] * 1.2500,
    MidiNote.f4      : stdFreq[MidiNote.c4] * 1.3333,
    MidiNote.fsharp4 : stdFreq[MidiNote.c4] * 1.4063,
    MidiNote.g4      : stdFreq[MidiNote.c4] * 1.5000,
    MidiNote.gsharp4 : stdFreq[MidiNote.c4] * 1.6000,
    MidiNote.a4      : stdFreq[MidiNote.c4] * 1.6667,
    MidiNote.asharp4 : stdFreq[MidiNote.c4] * 1.8000,
    MidiNote.b4      : stdFreq[MidiNote.c4] * 1.8750,
    MidiNote.c5      : stdFreq[MidiNote.c4] * 2,
    MidiNote.csharp5 : stdFreq[MidiNote.c4] * 2 * 1.0417,
    MidiNote.d5      : stdFreq[MidiNote.c4] * 2 * 1.1250,
    MidiNote.dsharp5 : stdFreq[MidiNote.c4] * 2 * 1.2000,
    MidiNote.e5      : stdFreq[MidiNote.c4] * 2 * 1.2500,
    MidiNote.f5      : stdFreq[MidiNote.c4] * 2 * 1.3333,
    MidiNote.fsharp5 : stdFreq[MidiNote.c4] * 2 * 1.4063,
    MidiNote.g5      : stdFreq[MidiNote.c4] * 2 * 1.5000,
    MidiNote.gsharp5 : stdFreq[MidiNote.c4] * 2 * 1.6000,
    MidiNote.a5      : stdFreq[MidiNote.c4] * 2 * 1.6667,
    MidiNote.asharp5 : stdFreq[MidiNote.c4] * 2 * 1.8000,
    MidiNote.b5      : stdFreq[MidiNote.c4] * 2 * 1.8750,
    MidiNote.c6      : stdFreq[MidiNote.c4] * 4,
    MidiNote.csharp6 : stdFreq[MidiNote.c4] * 4 * 1.0417,
    MidiNote.d6      : stdFreq[MidiNote.c4] * 4 * 1.1250,
    MidiNote.dsharp6 : stdFreq[MidiNote.c4] * 4 * 1.2000,
    MidiNote.e6      : stdFreq[MidiNote.c4] * 4 * 1.2500,
    MidiNote.f6      : stdFreq[MidiNote.c4] * 4 * 1.3333,
    MidiNote.fsharp6 : stdFreq[MidiNote.c4] * 4 * 1.4063,
    MidiNote.g6      : stdFreq[MidiNote.c4] * 4 * 1.5000,
    MidiNote.gsharp6 : stdFreq[MidiNote.c4] * 4 * 1.6000,
    MidiNote.a6      : stdFreq[MidiNote.c4] * 4 * 1.6667,
    MidiNote.asharp6 : stdFreq[MidiNote.c4] * 4 * 1.8000,
    MidiNote.b6      : stdFreq[MidiNote.c4] * 4 * 1.8750,
    MidiNote.c7      : stdFreq[MidiNote.c4] * 8,
    MidiNote.csharp7 : stdFreq[MidiNote.c4] * 8 * 1.0417,
    MidiNote.d7      : stdFreq[MidiNote.c4] * 8 * 1.1250,
    MidiNote.dsharp7 : stdFreq[MidiNote.c4] * 8 * 1.2000,
    MidiNote.e7      : stdFreq[MidiNote.c4] * 8 * 1.2500,
    MidiNote.f7      : stdFreq[MidiNote.c4] * 8 * 1.3333,
    MidiNote.fsharp7 : stdFreq[MidiNote.c4] * 8 * 1.4063,
    MidiNote.g7      : stdFreq[MidiNote.c4] * 8 * 1.5000,
    MidiNote.gsharp7 : stdFreq[MidiNote.c4] * 8 * 1.6000,
    MidiNote.a7      : stdFreq[MidiNote.c4] * 8 * 1.6667,
    MidiNote.asharp7 : stdFreq[MidiNote.c4] * 8 * 1.8000,
    MidiNote.b7      : stdFreq[MidiNote.c4] * 8 * 1.8750,
    MidiNote.c8      : stdFreq[MidiNote.c4] * 16,
    MidiNote.csharp8 : stdFreq[MidiNote.c4] * 16 * 1.0417,
    MidiNote.d8      : stdFreq[MidiNote.c4] * 16 * 1.1250,
    MidiNote.dsharp8 : stdFreq[MidiNote.c4] * 16 * 1.2000,
    MidiNote.e8      : stdFreq[MidiNote.c4] * 16 * 1.2500,
    MidiNote.f8      : stdFreq[MidiNote.c4] * 16 * 1.3333,
    MidiNote.fsharp8 : stdFreq[MidiNote.c4] * 16 * 1.4063,
    MidiNote.g8      : stdFreq[MidiNote.c4] * 16 * 1.5000,
    MidiNote.gsharp8 : stdFreq[MidiNote.c4] * 16 * 1.6000,
    MidiNote.a8      : stdFreq[MidiNote.c4] * 16 * 1.6667,
    MidiNote.asharp8 : stdFreq[MidiNote.c4] * 16 * 1.8000,
    MidiNote.b8      : stdFreq[MidiNote.c4] * 16 * 1.8750,
    MidiNote.c9      : stdFreq[MidiNote.c4] * 32,
    MidiNote.csharp9 : stdFreq[MidiNote.c4] * 32 * 1.0417,
    MidiNote.d9      : stdFreq[MidiNote.c4] * 32 * 1.1250,
    MidiNote.dsharp9 : stdFreq[MidiNote.c4] * 32 * 1.2000,
    MidiNote.e9      : stdFreq[MidiNote.c4] * 32 * 1.2500,
    MidiNote.f9      : stdFreq[MidiNote.c4] * 32 * 1.3333,
    MidiNote.fsharp9 : stdFreq[MidiNote.c4] * 32 * 1.4063,
    MidiNote.g9      : stdFreq[MidiNote.c4] * 32 * 1.5000,
    //MidiNote.gsharp9 : stdFreq[MidiNote.c4] * 32 * 1.6000,
];

enum MidiMsgCategory
{
    noteOff = 0x80,
    noteOn  = 0x90,
    localAftertouch = 0xa0,
    control = 0xb0,
    program = 0xc0,
    globalAftertouch = 0xd0,
    pitchBend = 0xe0,
}
enum MidiControlCode
{
    sustainPedal = 64,
}

struct MidiNoteMap(T, string noteMember)
{
    import mar.array : StaticArray;

    private StaticArray!(T, MidiNote.max + 1) array;
    private ubyte[MidiNote.max + 1] indexTable;

    void initialize()
    {
        import mar.mem : memset;
        memset(indexTable.ptr, ubyte.max, indexTable.length);
    }
    auto length() const { return array.length; }
    auto asArray() inout { return array.data; }
    auto tryGetRef(MidiNote note) inout
    {
        auto index = indexTable[note];
        return (index == ubyte.max) ? null : &array[index];
    }
    auto get(MidiNote note, T default_) inout
    {
        auto index = indexTable[note];
        return (index == ubyte.max) ? default_ : array[index];
    }

    static if (noteMember !is null)
    {
        void set(T data)
        {
            auto index = indexTable[mixin("data" ~ noteMember)];
            if (index != ubyte.max)
            {
                array[index] = data;
            }
            else
            {
                index = cast(byte)array.length;
                indexTable[mixin("data" ~ noteMember)] = index;
                array.tryPut(data).enforce();
            }
        }
        // Returns: index the note was in, ubyte.max if it's not added
        ubyte remove(MidiNote note)
        {
            const index = indexTable[note];
            if (index != ubyte.max)
            {
                indexTable[note] = ubyte.max;
                array.removeAt(index);
                foreach (i; index .. array.length)
                {
                    indexTable[mixin("array[i]" ~ noteMember)]--;
                }
            }
            return index;
        }
        ubyte removeAt(ubyte index)
        in {
            assert(index < array.length);
            assert(indexTable[mixin("array[index]" ~ noteMember)] == index);
        } do
        {
            indexTable[mixin("array[index]" ~ noteMember)] = ubyte.max;
            array.removeAt(index);
            foreach (i; index .. array.length)
            {
                indexTable[mixin("array[i]" ~ noteMember)]--;
            }
            return index;
        }
    }
    else
    {
        void set(MidiNote note, T data)
        {
            auto index = indexTable[note];
            if (index != ubyte.max)
            {
                array[index] = data;
            }
            else
            {
                index = cast(byte)array.length;
                indexTable[note] = index;
                array.tryPut(data).enforce();
            }
        }
    }
}

unittest
//void unittest1()
{
    {
        MidiNoteMap!(MidiNote, "") map;
        map.initialize();
        map.set(MidiNote.c4);
        map.set(MidiNote.csharp4);
        map.set(MidiNote.d4);

        assert(MidiNote.c4 == map.get(MidiNote.c4, MidiNote.none));
        assert(MidiNote.csharp4 == map.get(MidiNote.csharp4, MidiNote.none));
        assert(MidiNote.d4 == map.get(MidiNote.d4, MidiNote.none));

        assert(0 == map.remove(MidiNote.c4));
        assert(MidiNote.csharp4 == map.get(MidiNote.csharp4, MidiNote.none));
        assert(MidiNote.d4 == map.get(MidiNote.d4, MidiNote.none));

        assert(0 == map.remove(MidiNote.csharp4));
        assert(MidiNote.d4 == map.get(MidiNote.d4, MidiNote.none));

        assert(0 == map.remove(MidiNote.d4));
    }
}
