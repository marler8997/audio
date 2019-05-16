module audio.global;

import mar.from;

import audio.backend : AudioBackend;

__gshared ubyte channelCount;
__gshared uint sampleFramesPerSec;
__gshared uint bufferSampleFrameCount;
__gshared AudioBackend backend;
