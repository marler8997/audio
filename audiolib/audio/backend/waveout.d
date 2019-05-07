module audio.backend.waveout;

import mar.passfail;
import mar.mem : zero;
import mar.c : cstring;

import mar.windows.types : Handle, SRWLock, INFINITE, InputRecord, ConsoleFlag;
import mar.windows.kernel32 :
    GetLastError, GetCurrentThreadId,
    InitializeSRWLock, AcquireSRWLockExclusive, ReleaseSRWLockExclusive,
    CreateEventA, SetEvent, ResetEvent,
    QueryPerformanceFrequency, QueryPerformanceCounter,
    WaitForSingleObject;
import mar.windows.winmm;
import mar.windows.waveout :
    WaveFormatTag, WaveoutHandle, WaveFormatEx, ChannelFlags, KSDataFormat,
    WaveFormatExtensible, WaveHeader, WaveOutputMessage;

import audio.log;
import audio.render : RenderState, SinOscillator, addRenderer, render;

//--------------------------------
// Public Data
struct GlobalData
{
    AudioFormat audioFormatID;
    WaveFormatExtensible waveFormat;
    SRWLock renderLock;
    uint bufferByteLength;
    uint bufferSampleCount;
    byte* activeBuffer;
    byte* renderBuffer;
}
private __gshared GlobalData global;
//--------------------------------

// ========================================================================================
// Backend API
alias AudioFormat = WaveFormatTag;
void doRenderLock()
{
    import mar.windows.kernel32 : AcquireSRWLockExclusive;
    pragma(inline, true);
    AcquireSRWLockExclusive(&global.renderLock);
}
void doRenderUnlock()
{
    import mar.windows.kernel32 : ReleaseSRWLockExclusive;
    pragma(inline, true);
    ReleaseSRWLockExclusive(&global.renderLock);
}
auto renderBuffer() { pragma(inline, true); return global.renderBuffer; }
auto channelCount() { pragma(inline, true); return global.waveFormat.format.channelCount; }
auto bufferSampleCount() { pragma(inline, true); return global.bufferSampleCount; }
auto samplesPerSecond() { pragma(inline, true); return global.waveFormat.format.samplesPerSec; }
auto bufferByteLength() { pragma(inline, true); return global.bufferByteLength; }
auto sampleByteLength() { pragma(inline, true); return global.waveFormat.format.blockAlign; }
// ========================================================================================


__gshared WaveoutHandle waveOut;
struct CustomWaveHeader
{
  WaveHeader hdr;
  Handle freeEvent;
  long writeTime;
  long setEventTime;
}
__gshared CustomWaveHeader[2] headers;

struct UniqueSinOscillator
{
    SinOscillator oscillator;
    float frequency;
}

__gshared long performanceFrequency;
__gshared float msPerTicks;

// Macros that need to be defined by the audio format
passfail platformInit()
{
    import mar.mem : zero;

    // Setup Headers
    for(int i = 0; i < 2; i++)
    {
        zero(&headers[i], headers[0].sizeof);
    }

    if(QueryPerformanceFrequency(&performanceFrequency).failed)
    {
        logError("QueryPerformanceFrequency failed");
        return passfail.fail;
    }
    //logDebug("performance frequency: ", performanceFrequency);
    msPerTicks = 1000.0 / cast(float)performanceFrequency;

    return passfail.pass;
}

// TODO: define a function to get the AudioFormat string (platform dependent?)

// 0 = success
byte setAudioFormatAndBufferConfig(AudioFormat formatID,
				   uint samplesPerSecond,
				   byte channelSampleBitLength,
				   byte channelCount,
				   uint bufferSampleCount_)
{
    import mar.mem;

    //
    // Setup audio format
    //
    global.audioFormatID = formatID;

    global.waveFormat.format.samplesPerSec  = samplesPerSecond;

    global.waveFormat.format.bitsPerSample  = channelSampleBitLength;
    global.waveFormat.format.blockAlign     = cast(ushort)((channelSampleBitLength / 8) * channelCount);

    global.waveFormat.format.channelCount   = channelCount;

    global.waveFormat.format.avgBytesPerSec = sampleByteLength * samplesPerSecond;

    if(formatID == WaveFormatTag.pcm)
    {
        global.waveFormat.format.tag        = WaveFormatTag.pcm;
        global.waveFormat.format.extraSize  = 0; // Size of extra info
    }
    else if(formatID == WaveFormatTag.float_)
    {
        global.waveFormat.format.tag         = WaveFormatTag.extensible;
        global.waveFormat.format.extraSize   = 22; // Size of extra info
        global.waveFormat.validBitsPerSample = channelSampleBitLength;
        global.waveFormat.channelMask        = ChannelFlags.frontLeft | ChannelFlags.frontRight;
        global.waveFormat.subFormat          = KSDataFormat.ieeeFloat;
    }
    else
    {
        logError("Unsupported format", formatID);
        return 1;
    }

    // Setup Buffers
    global.bufferSampleCount = bufferSampleCount_;
    global.bufferByteLength = bufferSampleCount_ * sampleByteLength;

    foreach (i; 0 .. 2)
    {
        if(headers[i].hdr.data)
            free(headers[i].hdr.data);

        headers[i].hdr.bufferLength = bufferByteLength;
        headers[i].hdr.data = malloc(bufferByteLength);
        if(headers[i].hdr.data == null)
        {
            logError("malloc failed");
            return 1;
        }
        headers[i].freeEvent = CreateEventA(null, 1, 1, null);
        if(headers[i].freeEvent.isNull)
        {
            logError("CreateEvent failed");
            return 1;
        }
    }

    return 0;
}

void waitForKey(cstring msg)
{
    import core.stdc.stdio : getchar;
    logError("Press enter to ", msg);
    flushErrors();
    getchar();
}

extern (Windows) void waveOutCallback(WaveoutHandle waveOut, uint msg, uint* instance,
    uint* param1, uint* param2)
{
    //logDebug("waveOutCallback (instance=0x%p,param1=0x%p,param2=0x%p)\n",
    //instance, param1, param2);
    switch(msg)
    {
    case WaveOutputMessage.open:
        logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, " WOM_OPEN)");
        break;
    case WaveOutputMessage.close:
        logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, " WOM_CLOSE)");
        break;
    case WaveOutputMessage.done:
        //logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, " WOM_DONE)");
        {
            auto header = cast(WaveHeader*)param1;
            //printf("[DEBUG] header (dwBufferLength=%d,data=0x%p)\n",
            //header->dwBufferLength, header->data);
            QueryPerformanceCounter(&((cast(CustomWaveHeader*)header).setEventTime));
            SetEvent((cast(CustomWaveHeader*)header).freeEvent);
        }
        break;
    default:
        logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, ")");
        break;
    }
    flushDebug();
}

extern (Windows) uint audioWriteLoop(void* param)
{
    /*
    // Set priority
    if(!SetPriorityClass(GetCurrentProcess(), REALTIME_PRIORITY_CLASS)) {
    printf("SetPriorityClass failed\n");
    return 1;
    }
    */

    // TODO: don't cast to uint, mar not able to print floats yet
    log("Expected write time ", cast(uint)(cast(float)bufferSampleCount * 1000.0 / cast(float)samplesPerSecond));

    long start, finish;

    //headers[0].hdr.data = bufferConfig.render;
    //headers[1].hdr.data = bufferConfig.active;

    // Write the first buffer
    //logDebug("zeroing out memory for last buffer ", headers[1].hdr.data);
    zero(headers[1].hdr.data, bufferByteLength); // Zero out memory for last buffer
    global.activeBuffer = cast(byte*)headers[1].hdr.data;
    global.renderBuffer = cast(byte*)headers[0].hdr.data;
    render(); // renders to header[0] renderBuffer
    waveOutPrepareHeader(waveOut, &headers[0].hdr, headers[0].hdr.sizeof); // IS THIS CALL NECESSARY?
    if(ResetEvent(headers[0].freeEvent).failed)
    {
        logError("ResetEvent failed, e=", GetLastError());
        return 1;
    }
    QueryPerformanceCounter(&headers[0].writeTime);
    waveOutWrite(waveOut, &headers[0].hdr, WaveHeader.sizeof);

    ubyte lastBufferIndex = 0;
    ubyte bufferIndex     = 1;

    while(true)
    {
        //logDebug("Rendering buffer ", bufferIndex);

        global.activeBuffer = cast(byte*)headers[lastBufferIndex].hdr.data;
        global.renderBuffer = cast(byte*)headers[bufferIndex].hdr.data;
        QueryPerformanceCounter(&start);
        render();
        QueryPerformanceCounter(&finish);
        const renderTime = finish - start;

        QueryPerformanceCounter(&start);
        waveOutPrepareHeader(waveOut, &headers[bufferIndex].hdr, WaveHeader.sizeof);
        QueryPerformanceCounter(&finish);
        const prepareTime = finish - start;

        if(ResetEvent(headers[bufferIndex].freeEvent).failed)
        {
            logError("ResetEvent failed, e=", GetLastError());
            return 1;
        }

        QueryPerformanceCounter(&headers[bufferIndex].writeTime);
        waveOutWrite(waveOut, &headers[bufferIndex].hdr, WaveHeader.sizeof);

        {
            char temp = bufferIndex;
            bufferIndex = lastBufferIndex;
            lastBufferIndex = temp;
        }

        QueryPerformanceCounter(&start);
        WaitForSingleObject(headers[bufferIndex].freeEvent, INFINITE);
        QueryPerformanceCounter(&finish);
        long waitTime = finish - start;

        QueryPerformanceCounter(&start);
        waveOutUnprepareHeader(waveOut, &headers[bufferIndex].hdr, WaveHeader.sizeof);
        QueryPerformanceCounter(&finish);
        long unprepareTime = finish - start;

        /*
        printf("Buffer %d stats render=%.1f ms, perpare=%.1f ms, write=%.1f ms, setEvent=%.1f ms, unprepare=%.1f ms, waited=%.1f ms\n", bufferIndex,
        renderTime * msPerTicks,
        prepareTime * msPerTicks,
        (headers[bufferIndex].setEventTime - headers[bufferIndex].writeTime) * msPerTicks,
        (finish - headers[bufferIndex].setEventTime) * msPerTicks,
        unprepareTime * msPerTicks,
        waitTime    * msPerTicks);
        */
    }
}

// 0 = success
char readNotes()
{
    import mar.print : formatHex;
    import mar.stdio : stdin;
    import mar.windows.types : EventType;
    import mar.windows.kernel32 :
        GetConsoleMode, SetConsoleMode, ReadConsoleInputA;

    // TODO: move these to mar
    enum VK_ESCAPE = 0x1b;
    enum VK_OEM_COMMA = 0xbc;
    enum VK_OEM_PERIOD = 0xbe;
    enum VK_OEM_1 = 0xba;
    enum VK_OEM_2 = 0xbf;
    enum LEFT_CTRL_PRESSED = 0x0008;
    enum RIGHT_CTRL_PRESSED = 0x0004;


    InputRecord[128] inputBuffer;

    if(!stdin.isValid)
    {
        logError("Error: failed to get stdin handle");
        return 1;
    }

    // Save old input mode
    uint oldMode;
    if(GetConsoleMode(stdin.asHandle, &oldMode).failed)
    {
        logError("Error: GetConsoleMode failed, e=", GetLastError());
        return 1;
    }
    auto newMode = oldMode;
    newMode &= ~(
          ConsoleFlag.enableEchoInput      // disable echo
        | ConsoleFlag.enableLineInput      // disable line input, we want characters immediately
        | ConsoleFlag.enableProcessedInput // we'll handle CTL-C so we can cleanup and reset the console mode
    );
    log("Current console mode 0x", oldMode.formatHex, ", setting so 0x", newMode.formatHex);

    if(SetConsoleMode(stdin.asHandle, newMode).failed)
    {
        logError("Error: SetConsoleMode failed, e=", GetLastError());
        return 1;
    }

    __gshared static UniqueSinOscillator[256] KeyOscillators;
    for(ushort i = 0; i < 256; i++)
    {
        KeyOscillators[i].frequency = 0;
        KeyOscillators[i].oscillator.base.state = RenderState.done; // keeps note from being started multiple times
    }
    KeyOscillators['Z'          ].frequency = 261.63; // C
    KeyOscillators['S'          ].frequency = 277.18; // C#
    KeyOscillators['X'          ].frequency = 293.66; // D
    KeyOscillators['D'          ].frequency = 311.13; // D#
    KeyOscillators['C'          ].frequency = 329.63; // E
    KeyOscillators['V'          ].frequency = 349.23; // F
    KeyOscillators['G'          ].frequency = 369.99; // F#
    KeyOscillators['B'          ].frequency = 392.00; // G
    KeyOscillators['H'          ].frequency = 415.30; // G#
    KeyOscillators['N'          ].frequency = 440.00; // A
    KeyOscillators['J'          ].frequency = 466.16; // A#
    KeyOscillators['M'          ].frequency = 493.88; // B
    KeyOscillators[VK_OEM_COMMA ].frequency = 523.25; // C
    KeyOscillators['L'          ].frequency = 554.37; // C#
    KeyOscillators[VK_OEM_PERIOD].frequency = 587.33; // D
    KeyOscillators[VK_OEM_1     ].frequency = 622.25; // D# ';'
    KeyOscillators[VK_OEM_2     ].frequency = 659.25; // E  '/'

    log("Use keyboard for sounds (ESC to exit)");
    flushLog();

LinputLoop:
    while(true)
    {
        uint inputCount;
        if(ReadConsoleInputA(stdin.asHandle, inputBuffer.ptr, inputBuffer.length, &inputCount).failed)
        {
            logError("Error: ReadConsoleInput failed, e=", GetLastError());
            SetConsoleMode(stdin.asHandle, oldMode);
            return 1;
        }

        //logDebug("Handling ", inputCount, " input events...");
        foreach(i; 0 .. inputCount)
        {
            switch(inputBuffer[i].type)
            {
            case EventType.key: {
                /*
                logDebug("KeyEvent code=", inputBuffer[i].key.keyCode
                    , " ", inputBuffer[i].key.down ? "down" : "up"
                );
                printf("KeyEvent code=%d 0x%x ascii=%c '%s' state=%d\n",
                inputBuffer[i].key.keyCode,
                inputBuffer[i].key.keyCode,
                inputBuffer[i].key.asciiChar,
                inputBuffer[i].key.down ? "down" : "up",
                inputBuffer[i].key.controlKeyState);
                */
                const code = inputBuffer[i].key.keyCode;

                // Quit from ESCAPE or CTL-C
                if((code == VK_ESCAPE) ||
                    (code == 'C' &&
                    (inputBuffer[i].key.controlKeyState & (LEFT_CTRL_PRESSED |
                    RIGHT_CTRL_PRESSED))))
                {
                    break LinputLoop;
                }

                if(inputBuffer[i].key.down)
                {
                    AcquireSRWLockExclusive(&global.renderLock);
                    scope (exit) ReleaseSRWLockExclusive(&global.renderLock);
                    if(KeyOscillators[code].oscillator.base.state >= RenderState.release)
                    {
                        char needToAdd = KeyOscillators[code].oscillator.base.state == RenderState.done;
                        KeyOscillators[code].oscillator.base.state = RenderState.sustain;

                        if(KeyOscillators[code].frequency == 0)
                        {
                            log("Key code ", code, " ", code.formatHex, " '", cast(char)code, "' has no frequency");
                        }
                        else
                        {
                            //printf("Key code %d 0x%x '%c' has frequency %f\n", code, code, (char)code,
                            //KeyOscillators[code].frequency);
                            if(global.audioFormatID == WaveFormatTag.pcm)
                            {
                                KeyOscillators[code].oscillator.initPcm16(KeyOscillators[code].frequency, .2);
                            }
                            else if(global.audioFormatID == WaveFormatTag.float_)
                            {
                                KeyOscillators[code].oscillator.initFloat(KeyOscillators[code].frequency, .2);
                            }
                            else
                            {
                                logError("unsupported audio format ", global.audioFormatID);
                                return 1;
                            }
                            if(needToAdd)
                                addRenderer(&(KeyOscillators[code].oscillator.base));
                        }
                    }
                }
                else
                {
                    AcquireSRWLockExclusive(&global.renderLock);
                    scope (exit) ReleaseSRWLockExclusive(&global.renderLock);
                    if(KeyOscillators[code].frequency == 0)
                        KeyOscillators[code].oscillator.base.state = RenderState.done;
                    else
                        KeyOscillators[code].oscillator.base.state = RenderState.release;
                }

            }
            break;
            case EventType.mouse:
                //printf("mouse event!\n");
                break;
            case EventType.focus:
                break;
            default:
                logDebug("unhandled event: ", inputBuffer[i].type);
                break;
            }
        }
    }

    return 0;
}

void dumpWaveFormat(WaveFormatExtensible* waveFormat)
{
    import mar.print : formatHex;
    logDebug("WaveFormat:");
    logDebug(" validBitsPerSample=", waveFormat.validBitsPerSample);
    logDebug(" channelMask=0x", waveFormat.channelMask.formatHex);
    logDebug(" subFormat=", waveFormat.subFormat.a.formatHex
        , "-", waveFormat.subFormat.b.formatHex
        , "-", waveFormat.subFormat.c.formatHex
        , "-", waveFormat.subFormat.d[0].formatHex
        , "-", waveFormat.subFormat.d[1].formatHex
        , "-", waveFormat.subFormat.d[2].formatHex
        , "-", waveFormat.subFormat.d[3].formatHex
        , "-", waveFormat.subFormat.d[4].formatHex
        , "-", waveFormat.subFormat.d[5].formatHex
        , "-", waveFormat.subFormat.d[6].formatHex
        , "-", waveFormat.subFormat.d[7].formatHex
    );
    logDebug(" format.tag=", waveFormat.format.tag);
    logDebug(" format.channels=", waveFormat.format.channelCount);
    logDebug(" format.samplesPerSec=", waveFormat.format.samplesPerSec);
    logDebug(" format.avgBytesPerSec=", waveFormat.format.avgBytesPerSec);
    logDebug(" format.blockAlign=", waveFormat.format.blockAlign);
    logDebug(" format.bitsPerSample=", waveFormat.format.bitsPerSample);
    logDebug(" format.extraSize=", waveFormat.format.extraSize);

    logDebug("sizeof WaveFormatEx=", waveFormat.format.sizeof);
    logDebug("offsetof channelMask=", waveFormat.channelMask.offsetof);
    logDebug("offsetof subFormat=", waveFormat.subFormat.offsetof);
}

// Temporary function to implement a computer music keyboard
byte shim()
{
    import mar.windows.kernel32 : CreateThread;
    import mar.windows.winmm : WaveoutOpenFlags, WAVE_MAPPER;

    InitializeSRWLock(&global.renderLock);

    /*
    dumpWaveFormat(&global.waveFormat);
    logDebug("WAVE_MAPPER=", WAVE_MAPPER);
    logDebug("WaveoutOpenFlags.callbackFunction=", WaveoutOpenFlags.callbackFunction);
    */
    const result = waveOutOpen(&waveOut,
        WAVE_MAPPER,
        &global.waveFormat.format,
        cast(void*)&waveOutCallback,
        null,
        WaveoutOpenFlags.callbackFunction);
    if(result.failed)
    {
        //printf("waveOutOpen failed (result=%d '%s')\n", result, getMMRESULTString(result));
        logError("waveOutOpen failed, result=", result);
        return 1;
    }

    auto audioWriteThread = CreateThread(null,
        0,
        &audioWriteLoop,
        null,
        0,
        null);

    readNotes();
    waveOutClose(waveOut);

    return 0;
}

