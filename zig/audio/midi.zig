const std = @import("std");
const testing = std.testing;

const midilog = std.log.scoped(.midi);

pub const ReaderCallback = fn(timestamp: usize, msg: MidiMsg) void;

pub const MidiReader =
    if (std.builtin.os.tag == .windows) @import("windows/MidiReader.zig")
    else @compileError("Unuspported OS");

pub const MidiNote = enum(u7) {
    cneg1      =  0,
    csharpneg1 =  1,
    dneg1      =  2,
    dsharpneg1 =  3,
    eneg1      =  4,
    fneg1      =  5,
    fsharpneg1 =  6,
    gneg1      =  7,
    gsharpneg1 =  8,
    aneg1      =  9,
    asharpneg1 = 10,
    bneg1      = 11,
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
};

pub const defaultFreq = stdFreq;
//pub const defaultFreq = justC4Freq;
//pub const defaultFreq = justFreqTable(MidiNote.b3);
pub const justC4Freq = justFreqTable(MidiNote.c4);
pub const justC0Freq = justFreqTable(MidiNote.c0);

pub fn getStdFreq(note : MidiNote) f32 {
    return stdFreq[@enumToInt(note)];
}
pub const stdFreq = [_]f32 {
        8.18, //   0
        8.66, //   1
        9.18, //   2
        9.72, //   3
       10.30, //   4
       10.91, //   5
       11.56, //   6
       12.25, //   7
       12.98, //   8
       13.75, //   9
       14.57, //  10
       15.43, //  11
       16.35, //  12 - c0
       17.32, //  13 - csharp0
       18.35, //  14 - d0
       19.45, //  15 - dsharp0
       20.60, //  16 - e0
       21.83, //  17 - f0
       23.12, //  18 - fsharp0
       24.50, //  19 - g0
       25.96, //  20 - gsharp0
       27.50, //  21 - a0
       29.14, //  22 - asharp0
       30.87, //  23 - b0
       32.70, //  24 - c1
       34.65, //  25 - csharp1
       36.71, //  26 - d1
       38.89, //  27 - dsharp1
       41.20, //  28 - e1
       43.65, //  29 - f1
       46.25, //  30 - fsharp1
       49.00, //  31 - g1
       51.91, //  32 - gsharp1
       55.00, //  33 - a1
       58.27, //  34 - asharp1
       61.74, //  35 - b1
       65.41, //  36 - c2
       69.30, //  37 - csharp2
       73.42, //  38 - d2
       77.78, //  39 - dsharp2
       82.41, //  40 - e2
       87.31, //  41 - f2
       92.50, //  42 - fsharp2
       98.00, //  43 - g2
      103.83, //  44 - gsharp2
      110.00, //  45 - a2
      116.54, //  46 - asharp2
      123.47, //  47 - b2
      130.81, //  48 - c3
      138.59, //  49 - csharp3
      146.83, //  50 - d3
      155.56, //  51 - dsharp3
      164.81, //  52 - e3
      174.61, //  53 - f3
      185.00, //  54 - fsharp3
      196.00, //  55 - g3
      207.65, //  56 - gsharp3
      220.00, //  57 - a3
      233.08, //  58 - asharp3
      246.94, //  59 - b3
      261.63, //  60 - c4
      277.18, //  61 - csharp4
      293.66, //  62 - d4
      311.13, //  63 - dsharp4
      329.63, //  64 - e4
      349.23, //  65 - f4
      369.99, //  66 - fsharp4
      392.00, //  67 - g4
      415.30, //  68 - gsharp4
      440.00, //  69 - a4
      466.16, //  70 - asharp4
      493.88, //  71 - b4
      523.25, //  72 - c5
      554.37, //  73 - csharp5
      587.33, //  74 - d5
      622.25, //  75 - dsharp5
      659.25, //  76 - e5
      698.46, //  77 - f5
      739.99, //  78 - fsharp5
      783.99, //  79 - g5
      830.61, //  80 - gsharp5
      880.00, //  81 - a5
      932.33, //  82 - asharp5
      987.77, //  83 - b5
     1046.50, //  84 - c6
     1108.73, //  85 - csharp6
     1174.66, //  86 - d6
     1244.51, //  87 - dsharp6
     1318.51, //  88 - e6
     1396.91, //  89 - f6
     1479.98, //  90 - fsharp6
     1567.98, //  91 - g6
     1661.22, //  92 - gsharp6
     1760.00, //  93 - a6
     1864.66, //  94 - asharp6
     1975.53, //  95 - b6
     2093.00, //  96 - c7
     2217.46, //  97 - csharp7
     2349.32, //  98 - d7
     2489.02, //  99 - dsharp7
     2637.02, // 100 - e7
     2793.83, // 101 - f7
     2959.96, // 102 - fsharp7
     3135.96, // 103 - g7
     3322.44, // 104 - gsharp7
     3520.00, // 105 - a7
     3729.31, // 106 - asharp7
     3951.07, // 107 - b7
     4186.01, // 108 - c8
     4434.92, // 109 - csharp8
     4698.63, // 110 - d8
     4978.03, // 111 - dsharp8
     5274.04, // 112 - e8
     5587.65, // 113 - f8
     5919.91, // 114 - fsharp8
     6271.93, // 115 - g8
     6644.88, // 116 - gsharp8
     7040.00, // 117 - a8
     7458.62, // 118 - asharp8
     7902.13, // 119 - b8
     8372.02, // 120 - c9
     8869.84, // 121 - csharp9
     9397.27, // 122 - d9
     9956.06, // 123 - dsharp9
    10548.08, // 124 - e9
    11175.30, // 125 - f9
    11839.82, // 126 - fsharp9
    12543.85, // 127 - g9
};

/// The "OctaveRoot" is the same note as some "root note" but in a different
/// octave.
const OctaveRoot = struct { octave: i5, root: i8 };

fn getOctaveRoot(root: MidiNote, note: MidiNote) OctaveRoot {
    @setEvalBranchQuota(3000);

    if (@enumToInt(note) >= @enumToInt(root)) {
        var result = OctaveRoot { .octave = 0, .root = undefined };
        var next_root = @as(u8, @enumToInt(root)) + 12;
        while (next_root <= @enumToInt(note)) : (next_root += 12) {
            result.octave += 1;
        }
        result.root = @intCast(i8, next_root - 12);
        return result;
    }

    var result = OctaveRoot { .octave = -1, .root =  @as(i8, @enumToInt(root)) - 12 };
    while (result.root > @enumToInt(note)) : (result.root -= 12) {
        result.octave -= 1;
    }
    return result;
}
test "getOctaveRoot" {
    try testing.expectEqual(OctaveRoot { .octave =  0, .root = @enumToInt(MidiNote.c4)}, getOctaveRoot(MidiNote.c4, MidiNote.c4));
    try testing.expectEqual(OctaveRoot { .octave =  0, .root = @enumToInt(MidiNote.c4)}, getOctaveRoot(MidiNote.c4, MidiNote.csharp4));
    try testing.expectEqual(OctaveRoot { .octave =  0, .root = @enumToInt(MidiNote.c4)}, getOctaveRoot(MidiNote.c4, MidiNote.b4));
    try testing.expectEqual(OctaveRoot { .octave =  1, .root = @enumToInt(MidiNote.c5)}, getOctaveRoot(MidiNote.c4, MidiNote.c5));
    try testing.expectEqual(OctaveRoot { .octave =  1, .root = @enumToInt(MidiNote.c5)}, getOctaveRoot(MidiNote.c4, MidiNote.b5));
    try testing.expectEqual(OctaveRoot { .octave =  5, .root = @enumToInt(MidiNote.c9)}, getOctaveRoot(MidiNote.c4, MidiNote.g9));

    try testing.expectEqual(OctaveRoot { .octave = -1, .root = @enumToInt(MidiNote.c3)}, getOctaveRoot(MidiNote.c4, MidiNote.b3));
    try testing.expectEqual(OctaveRoot { .octave = -1, .root = @enumToInt(MidiNote.c3)}, getOctaveRoot(MidiNote.c4, MidiNote.c3));
    try testing.expectEqual(OctaveRoot { .octave = -2, .root = @enumToInt(MidiNote.c2)}, getOctaveRoot(MidiNote.c4, MidiNote.b2));
    try testing.expectEqual(OctaveRoot { .octave = -4, .root = @enumToInt(MidiNote.c0)}, getOctaveRoot(MidiNote.c4, MidiNote.c0));

    try testing.expectEqual(OctaveRoot { .octave = -1, .root = -11}, getOctaveRoot(MidiNote.csharpneg1, MidiNote.cneg1));
    try testing.expectEqual(OctaveRoot { .octave = -1, .root = @enumToInt(MidiNote.g8)}, getOctaveRoot(MidiNote.g9, MidiNote.f9));
}

const NotePos = struct {
    octave: i5,
    interval: u4,
};
fn notePos(root: MidiNote, note: MidiNote) NotePos {
    const octave_root = getOctaveRoot(root, note);
    return .{ .octave = octave_root.octave, .interval = @intCast(u4, @enumToInt(note) - octave_root.root) };
}


const neg_scale_table = [_]f32 {
    0.0/1024.0, 0.0/512.0, 0.0/256.0, 0.0/128.0, 0.0/64.0, 0.0/32.0, 0.0/16.0, 0.0/8.0, 0.0/4.0, 0.0/2.0,
};
const pos_scale_table = [_]f32 {
    1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0,
};
fn getScale(octave: i5) f32 {
    if (octave >= 0) {
        return pos_scale_table[@intCast(usize, octave)];
    }
    return neg_scale_table[@intCast(usize, -octave)];
}

fn sortRatioTable(ratios: [11]f32) [12]f32 {
    for (ratios) |ratio| {
        std.debug.assert(ratio > 1.0);
        std.debug.assert(ratio < 2.0);
    }
    var table: [12]f32 = undefined;
    table[0] = 1.0;
    std.mem.copy(f32, table[1..], &ratios);
    std.sort.sort(f32, &table, {}, comptime std.sort.asc(f32));
    return table;
}

const just_ratios = sortRatioTable([_]f32 {
    // Ratios of 2
    3.0 / 2.0,   // 5      (G  in key of C)
    // Ratios of 3
    4.0 / 3.0,   // 4      (F  in key of C)
    5.0 / 3.0,   // 6      (A  in key of C)
    // Ratios of 4
    5.0 / 4.0,   // 3      (E  in key of C)
    // ----- 6/4 (same as 3/2)
    // ----- 7/4 (not used in 18th century european music?)
    // Ratios of 5
    6.0 / 5.0,   // Flat 3 (Eb in key of C)
    7.0 / 5.0,   // Flat 5 (Gb in key of C)
    8.0 / 5.0,   // Flat 6 (Ab in key of C)
    9.0 / 5.0,  // Flat 7 (Bb in key of C)
    // Ratios of 6?
    // -----  7/6 ?
    // -----  8/6 is 4/3
    // -----  9/6 is 3/2
    // ----- 10/6 is 5/3
    // ----- 11/6 ?
    // Ratios of 7?
    // -----  8/7?
    // -----  9/8?
    // ----- 10/7?
    // ----- 11/7?
    // ----- 12/7?
    // ----- 13/7?
    // Ratios of 8
    9.0 / 8.0, // 2      (D in key of C)
    // ----- 10/8 (same as 5/4)
    // ----- 11/8?
    // ----- 12/8 (same as 3/2)
    // ----- 13/8 ?
    // ----- 14/8 (same as 7/4)
    15.0 / 8.0, //7      (B in key of C)
    16.0 / 15.0,//Flat 2 (Db in key of C)
});

fn getJustRatio(interval: u4) f32 {
    if (interval > 11)
        unreachable;
    return just_ratios[interval];
}

fn justFreqTable(root_note: MidiNote) [127]f32 {
    var table: [127]f32 = undefined;
    const root_freq = stdFreq[@enumToInt(root_note)];
    {
        var i: u7 = 0;
        while (true) {
            const pos = notePos(root_note, @intToEnum(MidiNote, i));
            table[i] = root_freq * getScale(pos.octave) * getJustRatio(pos.interval);
            i += 1;
            if (i == table.len - 1)
                break;
        }
    }
    return table;
}

//struct MidiNoteMapView(T)
//{
//    //private ubyte[MidiNote.max + 1] indexTable;
//    // The offsetof indexTable must match the offsetof indexTable in MidiNoteMap
//    //static assert(indexTable.offsetof == 0);
//    MidiNoteMap!(void, null)* noteMap;
//    size_t elementSize;
//}
//
//struct MidiNoteMap(T, string noteMember)
//{
//    import mar.array : StaticArray;
//
//    private ubyte[MidiNote.max + 1] indexTable;
//    // The offsetof indexTable must match the offsetof indexTable in GenericMidiNoteMap
//    //static assert(indexTable.offsetof == 0);
//
//    static if (!is(T == void))
//        private StaticArray!(T, MidiNote.max + 1) array;
//    else
//        private void[0] array;
//
//    auto getView(ViewType)() inout
//    {
//        return MidiNoteMapView!ViewType(cast(MidiNoteMap!(void, null)*)&this);
//    }
//
//
//    final void initialize()
//    {
//        import mar.mem : memset;
//        memset(indexTable.ptr, ubyte.max, indexTable.length);
//    }
//    final auto length() const { return array.length; }
//    final auto asArray() inout { return array.data; }
//    final auto tryGetRef(MidiNote note) inout
//    {
//        auto index = indexTable[note];
//        return (index == ubyte.max) ? null : &array[index];
//    }
//
//    static if (!is(T == void))
//    {
//        final auto get(MidiNote note, T default_) inout
//        {
//            auto index = indexTable[note];
//            return (index == ubyte.max) ? default_ : array[index];
//        }
//    }
//
//    static if (noteMember !is null)
//    {
//        final void set(T data)
//        {
//            auto index = indexTable[mixin("data" ~ noteMember)];
//            if (index != ubyte.max)
//            {
//                array[index] = data;
//            }
//            else
//            {
//                index = cast(byte)array.length;
//                indexTable[mixin("data" ~ noteMember)] = index;
//                array.tryPut(data).enforce();
//            }
//        }
//        // Returns: index the note was in, ubyte.max if it's not added
//        final ubyte remove(MidiNote note)
//        {
//            const index = indexTable[note];
//            if (index != ubyte.max)
//            {
//                indexTable[note] = ubyte.max;
//                array.removeAt(index);
//                foreach (i; index .. array.length)
//                {
//                    indexTable[mixin("array[i]" ~ noteMember)]--;
//                }
//            }
//            return index;
//        }
//        final ubyte removeAt(ubyte index)
//        in {
//            assert(index < array.length);
//            assert(indexTable[mixin("array[index]" ~ noteMember)] == index);
//        } do
//        {
//            indexTable[mixin("array[index]" ~ noteMember)] = ubyte.max;
//            array.removeAt(index);
//            foreach (i; index .. array.length)
//            {
//                indexTable[mixin("array[i]" ~ noteMember)]--;
//            }
//            return index;
//        }
//    }
//    else
//    {
//        static if (!is(T == void))
//        {
//            final void set(MidiNote note, T data)
//            {
//                auto index = indexTable[note];
//                if (index != ubyte.max)
//                {
//                    array[index] = data;
//                }
//                else
//                {
//                    index = cast(byte)array.length;
//                    indexTable[note] = index;
//                    array.tryPut(data).enforce();
//                }
//            }
//        }
//    }
//}
//
//unittest
////void unittest1()
//{
//    {
//        MidiNoteMap!(MidiNote, "") map;
//        map.initialize();
//        map.set(MidiNote.c4);
//        map.set(MidiNote.csharp4);
//        map.set(MidiNote.d4);
//
//        assert(MidiNote.c4 == map.get(MidiNote.c4, MidiNote.none));
//        assert(MidiNote.csharp4 == map.get(MidiNote.csharp4, MidiNote.none));
//        assert(MidiNote.d4 == map.get(MidiNote.d4, MidiNote.none));
//
//        assert(0 == map.remove(MidiNote.c4));
//        assert(MidiNote.csharp4 == map.get(MidiNote.csharp4, MidiNote.none));
//        assert(MidiNote.d4 == map.get(MidiNote.d4, MidiNote.none));
//
//        assert(0 == map.remove(MidiNote.csharp4));
//        assert(MidiNote.d4 == map.get(MidiNote.d4, MidiNote.none));
//
//        assert(0 == map.remove(MidiNote.d4));
//    }
//}

pub const MidiMsgKind = enum(u3) {
    note_off         = 0b000,
    note_on          = 0b001,
    poly_pressure    = 0b010,
    control_change   = 0b011,
    program_change   = 0b100,
    channel_pressure = 0b101,
    pitch_bend       = 0b110,
    system_msg       = 0b111,
};
const NoteAndVelocity = packed struct {
    msb_note: u1,
    note: u7,
    msb_velocity: u1,
    velocity: u7,
};
pub const MidiMsg = packed struct {
    status_arg: u4,
    kind: MidiMsgKind,
    msb_status: u1,
    data: packed union {
        bytes: [2]u8,
        note_off: Note,
        note_on: Note,
        poly_pressure: PressureNote,
        control_change: Control,
        program_change: packed struct {
            num: u7,
            msb_num: u1,
        },
        channel_pressure: packed struct {
            pressure: u7,
            msb_pressure: u1,
        },
        pitch_bend: packed struct {
            low_bits: u7,
            msb_low_bits: u1,
            high_bits: u7,
            msb_high_bits: u1,
            pub fn getValue(self: @This()) u14 {
                return (@intCast(u14, self.high_bits) << 7) | @intCast(u14, self.low_bits);
            }
        },

        pub const Note = packed struct {
            note: u7,
            msb_note: u1,
            velocity: u7,
            msb_velocity: u1,
        };
        pub const PressureNote = packed struct {
            note: u7,
            msb_note: u1,
            pressure: u7,
            msb_pressure: u1,
        };
        pub const Control = packed struct {
            num: u7,
            msb_num: u1,
            velocity: u7,
            msb_velocity: u1,
        };
    },
};

// TODO: remove this once I can use @bitCast instead
pub const MidiMsgUnion = packed union {
    bytes: [@sizeOf(MidiMsg)]u8,
    msg: MidiMsg,
};

pub fn checkMidiMsg(msg: MidiMsg) !void {
    if (msg.msb_status == 0) return error.MidiMsgStatusMsbIsZero;
    if (msg.data.bytes[0] == 1) return error.MidiMsgFirstDataByteMsbIsOne;
    if (msg.data.bytes[1] == 1) return error.MidiMsgSecondDataByteMsbIsOne;
}

pub fn logMidiMsg(msg: MidiMsg) void {
    switch (msg.kind) {
        .note_off, .note_on => {
            const kind: []const u8 = if (msg.kind == .note_off) "off" else "on";
            midilog.debug("note_{s} channel={} note={s}({}) velocity={}", .{
                kind, msg.status_arg,
                @tagName(@intToEnum(MidiNote, msg.data.note_off.note)),
                msg.data.note_off.note, msg.data.note_off.velocity});
        },
        .poly_pressure => {
            midilog.debug("poly_pressure channel={} {}", .{msg.status_arg, msg.data.poly_pressure});
        },
        .control_change => {
            midilog.debug("control_change channel={} {}", .{msg.status_arg, msg.data.control_change});
        },
        .program_change => {
            midilog.debug("program_change channel={} {}", .{msg.status_arg, msg.data.program_change});
        },
        .channel_pressure => {
            midilog.debug("channel_pressure channel={} {}", .{msg.status_arg, msg.data.channel_pressure});
        },
        .pitch_bend => {
            midilog.debug("pitch_bend channel={} {}", .{msg.status_arg, msg.data.pitch_bend.getValue()});
        },
        else => {
            midilog.debug("unknown msg {}", .{msg});
        },
    }
}
