const std = @import("std");

const stdext = @import("../stdext.zig");
usingnamespace stdext.limitarray;

const audio = @import("../audio.zig");
usingnamespace audio.log;
usingnamespace audio.renderformat;
const OutputNode = audio.dag.OutputNode;
const AudioGenerator = audio.dag.AudioGenerator;


pub const global = struct {
    // Meant to lock access to the render node graph to keep nodes
    // or data inside it from being modified during a render.
    pub var renderLock = std.StaticallyInitializedMutex.init();

    // The generators connected directly to the audio backend
    var rootAudioGenerators: std.ArrayList(*AudioGenerator) = undefined;

    var mainOutputNode = OutputNode {};
};

pub fn init() anyerror!void {

    global.rootAudioGenerators = std.ArrayList(*AudioGenerator).init(audio.global.allocator);
}
pub fn addRootAudioGenerator(generator: *AudioGenerator) !void {
    try generator.connectOutputNode(generator, &global.mainOutputNode);

    const locked = global.renderLock.acquire();
    defer locked.release();

    try global.rootAudioGenerators.append(generator);
}

pub fn renderThreadEntry(context: void) void {
    logDebug("renderThread started!");
    const result = renderThread2();
    if (result) {
        log("renderThread is exiting with no error");
    } else |err| {
        logError("render thread failed with {}", err);
    }
}

fn renderThread2() !void {
    //// Set priority
    //if(!SetPriorityClass(GetCurrentProcess(), REALTIME_PRIORITY_CLASS)) {
    //    printf("SetPriorityClass failed\n");
    //    return 1;
    //}

    //{
    //    const thread = GetCurrentThread();
    //    const priority = GetThreadPriority(thread);
    //    logDebug("ThreadPriority={}", priority);
    //    if (priority < ThreadPriority.timeCritical)
    //    {
    //        logDebug("Setting thread priority to ", ThreadPriority.timeCritical);
    //        if (SetThreadPriority(thread, ThreadPriority.timeCritical).failed)
    //        {
    //            logError("Failed to set thread priority, e={}", GetLastError());
    //            return 1; // fail
    //        }
    //    }
    //}

    const renderBufferSampleCount = audio.global.bufferSampleFrameCount * audio.global.channelCount;
    logDebug("renderBufferSampleCount {}", renderBufferSampleCount);
    var renderBuffer = try audio.global.allocator.alloc(SamplePoint, renderBufferSampleCount);
    defer audio.global.allocator.free(renderBuffer);

    var channels = try audio.global.allocator.alloc(u8, audio.global.channelCount);
    defer audio.global.allocator.free(channels);
    {
        var i : u8 = 0;
        while (i < audio.global.channelCount)
        {
            channels[i] = i;
            i += 1;
        }
    }
    try audio.global.backendFuncs.startingRenderLoop();
    const renderLoopResult = renderLoop(channels, renderBuffer.ptr, renderBuffer.ptr + renderBuffer.len);
    try audio.global.backendFuncs.stoppingRenderLoop();
    return renderLoopResult;
}

//version = DebugDumpRender;
fn renderLoop(channels: []u8, bufferStart: [*]SamplePoint, bufferLimit: [*]SamplePoint) anyerror!void {

    try render(channels, bufferStart, bufferLimit);
    //version (DebugDumpRender)
    //{
    //    for (auto p = renderBuffer; p < renderLimit; p += audio.global.channelCount)
    //    {
    //        // only log one channel right now
    //        if (audio.global.channelCount == 1)
    //            logDebug(p[0]);
    //        if (audio.global.channelCount == 2)
    //            logDebug(p[0], "    ", p[1]);
    //    }
    //    import mar.process : exit;
    //    exit(1);
    //}
    try audio.global.backendFuncs.writeFirstBuffer(bufferStart);

    while(true)
    {
        //logDebug("Rendering buffer ", bufferIndex);
        //renderStartTick.update();
        try render(channels, bufferStart, bufferLimit);
        try audio.global.backendFuncs.writeBuffer(bufferStart);
    }
}

fn render(channels: []u8, bufferStart: [*]SamplePoint, bufferLimit: [*]SamplePoint) !void {

    // TODO: if there are any generators that have a "set" function, then I
    //       could use that first and skip zeroing memory
    //

    // TODO: which one is faster????
    //stdext.mem.set(renderBuffer.toArray(), 0);
    stdext.mem.secureZero(limitPointersToSlice(bufferStart, bufferLimit));

    const locked = global.renderLock.acquire();
    defer locked.release();
    //logDebug("render");
    for (global.rootAudioGenerators.toSlice()) |generator| {
        try generator.mix(generator, channels, bufferStart, bufferLimit);
    }
    for (global.rootAudioGenerators.toSlice()) |generator| {
        try generator.renderFinished(generator, &global.mainOutputNode);
    }
}

pub fn addToEachChannel(channels: []u8, buffer: [*]SamplePoint, value: SamplePoint) void {
    for (channels) |channel| {
        buffer[channel] += value;
    }
}

//pub fn popFrant(