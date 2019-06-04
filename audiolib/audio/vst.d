module audio.vst;

// http://teragonaudio.com/article/How-to-make-your-own-VST-host.html

// ============================================================================
// affect.h
// ============================================================================

/*    to create an Audio Effect for power pc's, create a
    code resource
    file type: 'aPcs'
    resource type: 'aEff'
    ppc header: none (raw pef)

    for windows, it's a .dll

    the only symbol searched for is:
    AEffect *main(float (*audioMaster)(AEffect *effect, uint opcode, uint index,
        uint value, void *ptr, float opt));
*/

/*
#if CARBON
#if PRAGMA_STRUCT_ALIGN || __MWERKS__
    #pragma options align=mac68k
#endif
#else
#if PRAGMA_ALIGN_SUPPORTED || __MWERKS__
    #pragma options align=mac68k
#endif
#endif
#if defined __BORLANDC__
    #pragma -a8
#elif defined(WIN32) || defined(__FLAT__) || defined CBUILDER
    #pragma pack(push)
    #pragma pack(8)
    #define VSTCALLBACK __cdecl
#else
    #define VSTCALLBACK
#endif
*/


//-------------------------------------------------
// Misc. Definition
//-------------------------------------------------

alias audioMasterCallback = extern (C) uint function(
    AEffect *effect,
    AudioOpcode opcode,
    uint index,
    uint value,
    void *ptr,
    float opt
);

// prototype for plug-in main
// AEffect *main(audioMasterCallback audioMaster);

// Four Character Constant
uint CCONST(char a, char b, char c, char d)
{
    return ((cast(uint)a) << 24)
         | ((cast(uint)b) << 16)
         | ((cast(uint)c) <<  8)
         | ((cast(uint)d) <<  0);
}

// Magic Number
enum kEffectMagic = CCONST('V', 's', 't', 'P');

//-------------------------------------------------
// AEffect Structure
//-------------------------------------------------
struct AEffect
{
    uint magic;            // must be kEffectMagic ('VstP')

    extern (C) uint function(AEffect *effect, uint opCode, uint index, int value,
        void *ptr, float opt) dispatcher;

    extern (C) void function(AEffect *effect, float **inputs, float **outputs, uint sampleframes) process;

    extern (C) void function(AEffect *effect, uint index, float parameter) setParameter;
    extern (C) float function(AEffect *effect, uint index) getParameter;

    uint numPrograms;   // number of Programs
    uint numParams;        // all programs are assumed to have numParams parameters
    uint numInputs;        // number of Audio Inputs
    uint numOutputs;    // number of Audio Outputs

    uint flags;            // see constants (Flags Bits)

    uint resvd1;        // reserved for Host, must be 0 (Dont use it)
    uint resvd2;        // reserved for Host, must be 0 (Dont use it)

    uint initialDelay;    // for algorithms which need input in the first place

    uint realQualities;    // number of realtime qualities (0: realtime)
    uint offQualities;    // number of offline qualities (0: realtime only)
    float ioRatio;        // input samplerate to output samplerate ratio, not used yet

    void *object;        // for class access (see AudioEffect.hpp), MUST be 0 else!
    void *user;            // user access

    uint uniqueID;        // pls choose 4 character as unique as possible. (register it at Steinberg Web)
                        // this is used to identify an effect for save+load
    uint version_;        // (example 1100 for version 1.1.0.0)

    extern (C) void function(AEffect *effect, float **inputs, float **outputs, uint sampleframes) processReplacing;

    ubyte[60] future;    // pls zero
};

//-------------------------------------------------
// Flags Bits
//-------------------------------------------------

enum effFlags
{
    HasEditor     =  1, // if set, is expected to react to editor messages
    HasClip       =  2, // return > 1. in getVu() if clipped
    HasVu         =  4, // return vu value in getVu(); > 1. means clipped
    CanMono       =  8, // if numInputs == 2, makes sense to be used for mono in
    CanReplacing  = 16, // supports in place output (processReplacing() exsists)
    ProgramChunks = 32, // program data are handled in formatless chunks
}

//-------------------------------------------------
// Dispatcher OpCodes
//-------------------------------------------------

enum eff
{
    Open = 0,        // initialise
    Close,            // exit, release all memory and other resources!

    SetProgram,        // program no in <value>
    GetProgram,        // return current program no.
    SetProgramName,    // user changed program name (max 24 char + 0) to as passed in string
    GetProgramName,    // stuff program name (max 24 char + 0) into string

    GetParamLabel,    // stuff parameter <index> label (max 8 char + 0) into string
                        // (examples: sec, dB, type)
    GetParamDisplay,    // stuff parameter <index> textual representation into string
                        // (examples: 0.5, -3, PLATE)
    GetParamName,    // stuff parameter <index> label (max 8 char + 0) into string
                        // (examples: Time, Gain, RoomType)
    GetVu,            // called if (flags & (effFlagsHasClip | effFlagsHasVu))

    // system
    setSampleRate,    // in opt (float value in Hz; for example 44100.0Hz)
    setBlockSize,    // in value (this is the maximun size of an audio block,
                        // pls check sampleframes in process call)
    mainsChanged,    // the user has switched the 'power on' button to
                        // value (0 off, else on). This only switches audio
                        // processing; you should flush delay buffers etc.

    // editor
    EditGetRect,        // stuff rect (top, left, bottom, right) into ptr
    EditOpen,        // system dependant Window pointer in ptr
    EditClose,        // no arguments
    EditDraw,        // draw method, ptr points to rect (MAC Only)
    EditMouse,        // index: x, value: y (MAC Only)
    EditKey,            // system keycode in value
    EditIdle,        // no arguments. Be gentle!
    EditTop,            // window has topped, no arguments
    EditSleep,        // window goes to background

    Identify,        // returns 'NvEf'
    GetChunk,        // host requests pointer to chunk into (void**)ptr, byteSize returned
    SetChunk,        // plug-in receives saved chunk, byteSize passed

    NumOpcodes
};

//-------------------------------------------------
// AudioMaster OpCodes
//-------------------------------------------------

enum AudioOpcode : uint
{
    MasterAutomate = 0,        // index, value, returns 0
    MasterVersion,             // VST Version supported (for example 2200 for VST 2.2)
    MasterCurrentId,           // Returns the unique id of a plug that's currently
                                    // loading
    MasterIdle,                // Call application idle routine (this will
                                    // call eff.EditIdle for all open editors too)
    MasterPinConnected            // Inquire if an input or output is beeing connected;
                                    // index enumerates input or output counting from zero,
                                    // value is 0 for input and != 0 otherwise. note: the
                                    // return value is 0 for <true> such that older versions
                                    // will always return true.
};

// ============================================================================
// affectx.h
// ============================================================================

/*
#if PRAGMA_STRUCT_ALIGN || __MWERKS__
    #pragma options align=mac68k
#elif defined __BORLANDC__
    #pragma -a8
#elif defined(WIN32) || defined(__FLAT__)
    #pragma pack(push)
    #pragma pack(8)
#endif
*/

//-------------------------------------------------
// VstEvent
//-------------------------------------------------

struct VstEvent            // a generic timestamped event
{
    uint type;            // see enum below
    uint byteSize;        // of this event, excl. type and byteSize
    uint deltaFrames;    // sample frames related to the current block start sample position
    uint flags;            // generic flags, none defined yet (0)

    ubyte[16] data;        // size may vary but is usually 16
};

//----VstEvent Types-------------------------------
enum kVst
{
    MidiType = 1,    // midi event, can be cast as VstMidiEvent (see below)
    AudioType,        // audio
    VideoType,        // video
    ParameterType,    // parameter
    TriggerType,    // trigger
    SysExType        // midi system exclusive
    // ...etc
};

struct VstEvents            // a block of events for the current audio block
{
    uint numEvents;
    uint reserved;            // zero
    VstEvent*[2] events;    // variable
};

//---Defined Events--------------------------------
struct VstMidiEvent        // to be casted from a VstEvent
{
    uint type;            // kVst.MidiType
    uint byteSize;        // 24
    uint deltaFrames;    // sample frames related to the current block start sample position
    uint flags;            // none defined yet

    uint noteLength;    // (in sample frames) of entire note, if available, else 0
    uint noteOffset;    // offset into note from note start if available, else 0

    ubyte[4] midiData;    // 1 thru 3 midi bytes; midiData[3] is reserved (zero)
    ubyte detune;        // -64 to +63 cents; for scales other than 'well-tempered' ('microtuning')
    ubyte noteOffVelocity;
    ubyte reserved1;        // zero
    ubyte reserved2;        // zero
};


//-------------------------------------------------
// VstTimeInfo
//-------------------------------------------------


// VstTimeInfo as requested via audioMasterGetTime (getTimeInfo())
// refers to the current time slice. note the new slice is
// already started when processEvents() is called

struct VstTimeInfo
{
    double samplePos;            // current location
    double sampleRate;
    double nanoSeconds;            // system time
    double ppqPos;                // 1 ppq
    double tempo;                // in bpm
    double barStartPos;            // last bar start, in 1 ppq
    double cycleStartPos;        // 1 ppq
    double cycleEndPos;            // 1 ppq
    uint timeSigNumerator;        // time signature
    uint timeSigDenominator;
    uint smpteOffset;
    uint smpteFrameRate;        // 0:24, 1:25, 2:29.97, 3:30, 4:29.97 df, 5:30 df
    uint samplesToNextClock;    // midi clock resolution (24 ppq), can be negative
    uint flags;                    // see below
};

enum kVstFlag
{
    TransportChanged     = 1 << 0,        // Indicates that Playing, Cycle or Recording has changed
    TransportPlaying     = 1 << 1,
    TransportCycleActive = 1 << 2,
    TransportRecording   = 1 << 3,

    AutomationWriting    = 1 << 6,
    AutomationReading    = 1 << 7,

    // flags which indicate which of the fields in this VstTimeInfo
    //  are valid; samplePos and sampleRate are always valid
    NanosValid           = 1 << 8,
    PpqPosValid          = 1 << 9,
    TempoValid           = 1 << 10,
    BarsValid            = 1 << 11,
    CyclePosValid        = 1 << 12,    // start and end
    TimeSigValid         = 1 << 13,
    SmpteValid           = 1 << 14,
    ClockValid           = 1 << 15
};

//-------------------------------------------------
// Variable IO for Offline Processing
//-------------------------------------------------
struct VstVariableIo
{
    float** inputs;
    float** outputs;
    uint numSamplesInput;
    uint numSamplesOutput;
    uint* numSamplesInputProcessed;
    uint* numSamplesOutputProcessed;
};

//-------------------------------------------------
// AudioMaster OpCodes
//-------------------------------------------------
enum audioMaster
{
    //---from here VST 2.0 extension opcodes------------------------------------------------------
    // VstEvents + VstTimeInfo
    WantMidi = AudioOpcode.MasterPinConnected + 2,    // <value> is a filter which is currently ignored
    GetTime,                // returns const VstTimeInfo* (or 0 if not supported)
                                    // <value> should contain a mask indicating which fields are required
                                    // (see valid masks above), as some items may require extensive
                                    // conversions
    ProcessEvents,        // VstEvents* in <ptr>
    SetTime,                // VstTimenfo* in <ptr>, filter in <value>, not supported
    TempoAt,                // returns tempo (in bpm * 10000) at sample frame location passed in <value>

    // parameters
    GetNumAutomatableParameters,
    GetParameterQuantization,    // returns the integer value for +1.0 representation,
                                            // or 1 if full single float precision is maintained
                                            // in automation. parameter index in <value> (-1: all, any)
    // connections, configuration
    IOChanged,                // numInputs and/or numOutputs has changed
    NeedIdle,                // plug needs idle calls (outside its editor window)
    SizeWindow,                // index: width, value: height
    GetSampleRate,
    GetBlockSize,
    GetInputLatency,
    GetOutputLatency,
    GetPreviousPlug,            // input pin in <value> (-1: first to come), returns cEffect*
    GetNextPlug,                // output pin in <value> (-1: first to come), returns cEffect*

    // realtime info
    WillReplaceOrAccumulate,    // returns: 0: not supported, 1: replace, 2: accumulate
    GetCurrentProcessLevel,    // returns: 0: not supported,
                                        // 1: currently in user thread (gui)
                                        // 2: currently in audio thread (where process is called)
                                        // 3: currently in 'sequencer' thread (midi, timer etc)
                                        // 4: currently offline processing and thus in user thread
                                        // other: not defined, but probably pre-empting user thread.
    GetAutomationState,        // returns 0: not supported, 1: off, 2:read, 3:write, 4:read/write

    // offline
    OfflineStart,
    OfflineRead,                // ptr points to offline structure, see below. return 0: error, 1 ok
    OfflineWrite,            // same as read
    OfflineGetCurrentPass,
    OfflineGetCurrentMetaPass,

    // other
    SetOutputSampleRate,        // for variable i/o, sample rate in <opt>
    GetSpeakerArrangement,    // result in ret
    GetOutputSpeakerArrangement = GetSpeakerArrangement,
    GetVendorString,            // fills <ptr> with a string identifying the vendor (max 64 char)
    GetProductString,        // fills <ptr> with a string with product name (max 64 char)
    GetVendorVersion,        // returns vendor-specific version
    VendorSpecific,            // no definition, vendor specific handling
    SetIcon,                    // void* in <ptr>, format not defined yet
    CanDo,                    // string in ptr, see below
    GetLanguage,                // see enum
    OpenWindow,                // returns platform specific ptr
    CloseWindow,                // close window, platform specific handle in <ptr>
    GetDirectory,            // get plug directory, FSSpec on MAC, else char*
    UpdateDisplay,            // something has changed, update 'multi-fx' display

    //---from here VST 2.1 extension opcodes------------------------------------------------------
    BeginEdit,               // begin of automation session (when mouse down), parameter index in <index>
    EndEdit,                 // end of automation session (when mouse up),     parameter index in <index>
    OpenFileSelector,        // open a fileselector window with VstFileSelect* in <ptr>

    //---from here VST 2.2 extension opcodes------------------------------------------------------
    CloseFileSelector,        // close a fileselector operation with VstFileSelect* in <ptr>: Must be always called after an open !
    EditFile,                // open an editor for audio (defined by XML text in ptr)
    GetChunkFile,            // get the native path of currently loading bank or project
                                        // (called from writeChunk) void* in <ptr> (char[2048], or sizeof(FSSpec))

    //---from here VST 2.3 extension opcodes------------------------------------------------------
    GetInputSpeakerArrangement    // result a VstSpeakerArrangement in ret
};

//-------------------------------------------------
// Language
//-------------------------------------------------

enum VstHostLanguage
{
    kVstLangEnglish = 1,
    kVstLangGerman,
    kVstLangFrench,
    kVstLangItalian,
    kVstLangSpanish,
    kVstLangJapanese
};

//-------------------------------------------------
// Dispatcher OpCodes
//-------------------------------------------------

enum
{
    //---from here VST 2.0 extension opcodes---------------------------------------------------------
    // VstEvents
    effProcessEvents = eff.SetChunk + 1,        // VstEvents* in <ptr>

    // parameters and programs
    effCanBeAutomated,                        // parameter index in <index>
    effString2Parameter,                    // parameter index in <index>, string in <ptr>
    effGetNumProgramCategories,                // no arguments. this is for dividing programs into groups (like GM)
    effGetProgramNameIndexed,                // get program name of category <value>, program <index> into <ptr>.
                                            // category (that is, <value>) may be -1, in which case program indices
                                            // are enumerated linearily (as usual); otherwise, each category starts
                                            // over with index 0.
    effCopyProgram,                            // copy current program to destination <index>
                                            // note: implies setParameter
    // connections, configuration
    effConnectInput,                        // input at <index> has been (dis-)connected;
                                            // <value> == 0: disconnected, else connected
    effConnectOutput,                        // same as input
    effGetInputProperties,                    // <index>, VstPinProperties* in ptr, return != 0 => true
    effGetOutputProperties,                    // dto
    effGetPlugCategory,                        // no parameter, return value is category

    // realtime
    effGetCurrentPosition,                    // for external dsp, see flag bits below
    effGetDestinationBuffer,                // for external dsp, see flag bits below. returns float*

    // offline
    effOfflineNotify,                        // ptr = VstAudioFile array, value = count, index = start flag
    effOfflinePrepare,                        // ptr = VstOfflineTask array, value = count
    effOfflineRun,                            // dto

    // other
    effProcessVarIo,                        // VstVariableIo* in <ptr>
    effSetSpeakerArrangement,                // VstSpeakerArrangement* pluginInput in <value>
                                            // VstSpeakerArrangement* pluginOutput in <ptr>
    effSetBlockSizeAndSampleRate,            // block size in <value>, sampleRate in <opt>
    effSetBypass,                            // onOff in <value> (0 = off)
    effGetEffectName,                        // char* name (max 32 bytes) in <ptr>
    effGetErrorText,                        // char* text (max 256 bytes) in <ptr>
    effGetVendorString,                        // fills <ptr> with a string identifying the vendor (max 64 char)
    effGetProductString,                    // fills <ptr> with a string with product name (max 64 char)
    effGetVendorVersion,                    // returns vendor-specific version
    effVendorSpecific,                        // no definition, vendor specific handling
    effCanDo,                                // <ptr>
    effGetTailSize,                            // returns tail size; 0 is default (return 1 for 'no tail')
    effIdle,                                // idle call in response to audioMasterneedIdle. must
                                            // return 1 to keep idle calls beeing issued

    // gui
    effGetIcon,                                // void* in <ptr>, not yet defined
    effSetViewPosition,                        // set view position (in window) to x <index> y <value>

    // and...
    effGetParameterProperties,                // of param <index>, VstParameterProperties* in <ptr>
    effKeysRequired,                        // returns 0: needs keys (default for 1.0 plugs), 1: don't need
    effGetVstVersion,                        // returns 2 for VST 2; older versions return 0; 2100 for VST 2.1

    effNumV2Opcodes,
    // note that effNumOpcodes doesn't apply anymore


    //---from here VST 2.1 extension opcodes---------------------------------------------------------
    effEditKeyDown = effNumV2Opcodes,       // Character in <index>, virtual in <value>, modifiers in <opt>,
                                            // return -1 if not used, return 1 if used
    effEditKeyUp,                           // Character in <index>, virtual in <value>, modifiers in <opt>
                                            // return -1 if not used, return 1 if used
    effSetEditKnobMode,                     // Mode in <value>: 0: circular, 1:circular relativ, 2:linear

    // midi plugins channeldependent programs
    effGetMidiProgramName,                    // Passed <ptr> points to MidiProgramName struct.
                                            // struct will be filled with information for 'thisProgramIndex'.
                                            // returns number of used programIndexes.
                                            // if 0 is returned, no MidiProgramNames supported.

    effGetCurrentMidiProgram,                // Returns the programIndex of the current program.
                                            // passed <ptr> points to MidiProgramName struct.
                                            // struct will be filled with information for the current program.

    effGetMidiProgramCategory,                // Passed <ptr> points to MidiProgramCategory struct.
                                            // struct will be filled with information for 'thisCategoryIndex'.
                                            // returns number of used categoryIndexes.
                                            // if 0 is returned, no MidiProgramCategories supported.

    effHasMidiProgramsChanged,                // Returns 1 if the MidiProgramNames or MidiKeyNames
                                            // had changed on this channel, 0 otherwise. <ptr> ignored.

    effGetMidiKeyName,                        // Passed <ptr> points to MidiKeyName struct.
                                            // struct will be filled with information for 'thisProgramIndex' and
                                            // 'thisKeyNumber'. If keyName is "" the standard name of the key
                                            // will be displayed. If 0 is returned, no MidiKeyNames are
                                            // defined for 'thisProgramIndex'.

    effBeginSetProgram,                        // Called before a new program is loaded
    effEndSetProgram,                        // Called when the program is loaded

    effNumV2_1Opcodes,

    //---from here VST 2.3 extension opcodes---------------------------------------------------------
    effGetSpeakerArrangement = effNumV2_1Opcodes, // VstSpeakerArrangement** pluginInput in <value>
                                                  // VstSpeakerArrangement** pluginOutput in <ptr>

    effShellGetNextPlugin,                    // This opcode is only called, if plugin is of type kPlugCategShell.
                                             // returns the next plugin's uniqueID.
                                             // <ptr> points to a char buffer of size 64, which is to be filled
                                             // with the name of the plugin including the terminating zero.

    effStartProcess,                        // Called before the start of process call
    effStopProcess,                            // Called after the stop of process call
    effSetTotalSampleToProcess,                // Called in offline (non RealTime) Process before process is called, indicates how many sample will be processed

    effSetPanLaw,                            // PanLaw : Type (Linear, Equal Power,.. see enum PanLaw Type) in <value>,
                                            // Gain in <opt>: for Linear : [1.0 => 0dB PanLaw], [~0.58 => -4.5dB], [0.5 => -6.02dB]
    effBeginLoadBank,                        // Called before a Bank is loaded, <ptr> points to VstPatchChunkInfo structure
                                            // return -1 if the Bank can not be loaded, return 1 if it can be loaded else 0 (for compatibility)
    effBeginLoadProgram,                    // Called before a Program is loaded, <ptr> points to VstPatchChunkInfo structure
                                            // return -1 if the Program can not be loaded, return 1 if it can be loaded else 0 (for compatibility)

    effNumV2_3Opcodes
};

//-------------------------------------------------
// Parameter Properties
//-------------------------------------------------

struct VstParameterProperties
{
    float stepFloat;
    float smallStepFloat;
    float largeStepFloat;
    char[64] label;
    uint flags;                // see below
    uint minInteger;
    uint maxInteger;
    uint stepInteger;
    uint largeStepInteger;
    char[8] shortLabel;        // recommended: 6 + delimiter

    // the following are for remote controller display purposes.
    // note that the kVstParameterSupportsDisplayIndex flag must be set.
    // host can scan all parameters, and find out in what order
    // to display them:

    short displayIndex;        // for remote controllers, the index where this parameter
                            // should be displayed (starting with 0)

    // host can also possibly display the parameter group (category), such as
    // ---------------------------
    // Osc 1
    // Wave  Detune  Octave  Mod
    // ---------------------------
    // if the plug supports it (flag kVstParameterSupportsDisplayCategory)
    short category;            // 0: no category, else group index + 1
    short numParametersInCategory;
    short reserved;
    char[24] categoryLabel;    // for instance, "Osc 1"

    char[18] future;
};

//---Parameter Properties Flags--------------------
enum kVstParameter
{
    IsSwitch                    = 1 << 0,
    UsesIntegerMinMax            = 1 << 1,
    UsesFloatStep                = 1 << 2,
    UsesIntStep                = 1 << 3,
    SupportsDisplayIndex         = 1 << 4,
    SupportsDisplayCategory    = 1 << 5,
    CanRamp                    = 1 << 6
};

//-------------------------------------------------
// Pin Properties
//-------------------------------------------------

struct VstPinProperties
{
    char[64] label;
    uint flags;         // see pin properties flags
    uint arrangementType;
    char[8] shortLabel;    // recommended: 6 + delimiter
    char[48] future;
};

//---Pin Properties Flags--------------------------
enum kVstPin
{
    IsActive   = 1 << 0,
    IsStereo   = 1 << 1,
    UseSpeaker = 1 << 2
};

//-------------------------------------------------
// Plugin Category
//-------------------------------------------------

enum VstPlugCategory
{
    kPlugCategUnknown = 0,
    kPlugCategEffect,
    kPlugCategSynth,
    kPlugCategAnalysis,
    kPlugCategMastering,
    kPlugCategSpacializer,    // 'panners'
    kPlugCategRoomFx,        // delays and reverbs
    kPlugSurroundFx,        // dedicated surround processor
    kPlugCategRestoration,
    kPlugCategOfflineProcess,
    kPlugCategShell,        // plugin which is only a container of plugins.
    kPlugCategGenerator
};

//-------------------------------------------------
// Midi Plugins Channel Dependent Programs
//-------------------------------------------------

struct MidiProgramName
{
    uint thisProgramIndex;        // >= 0. fill struct for this program index.
    char[64] name;
    char midiProgram;            // -1:off, 0-127
    char midiBankMsb;            // -1:off, 0-127
    char midiBankLsb;            // -1:off, 0-127
    char reserved;                // zero
    uint parentCategoryIndex;    // -1:no parent category
    uint flags;                    // omni etc, see below
};

//---MidiProgramName Flags-------------------------
enum kMidi
{
    IsOmni = 1                // default is multi. for omni mode, channel 0
                                // is used for inquiries and program changes
};

//---MidiProgramName-------------------------------
struct MidiProgramCategory
{
    uint thisCategoryIndex;        // >= 0. fill struct for this category index.
    char[64] name;
    uint parentCategoryIndex;    // -1:no parent category
    uint flags;                    // reserved, none defined yet, zero.
};

//---MidiKeyName-----------------------------------
struct MidiKeyName
{
    uint thisProgramIndex;        // >= 0. fill struct for this program index.
    uint thisKeyNumber;            // 0 - 127. fill struct for this key number.
    char[64] keyName;
    uint reserved;                // zero
    uint flags;                    // reserved, none defined yet, zero.
};

//-------------------------------------------------
// Flags Bits
//-------------------------------------------------

enum effFlag
{
    IsSynth       = 1 << 8,     // host may assign mixer channels for its outputs
    NoSoundInStop = 1 << 9,     // does not produce sound when input is all silence
    ExtIsAsync    = 1 << 10,    // for external dsp; plug returns immedeately from process()
                                // host polls plug position (current block) via effGetCurrentPosition
    ExtHasBuffer  = 1 << 11     // external dsp, may have their own output buffe (32 bit float)
                                // host then requests this via effGetDestinationBuffer
};

//-------------------------------------------------
// Surround Setup
//-------------------------------------------------

//---Speaker Properties----------------------------
struct VstSpeakerProperties
{                         // units:    range:            except:
    float azimuth;        // rad        -PI...PI        10.f for LFE channel
    float elevation;    // rad        -PI/2...PI/2    10.f for LFE channel
    float radius;        // meter                    0.f for LFE channel
    float reserved;        // 0.
    char[64] name;        // for new setups, new names should be given (L/R/C... won't do)
    uint  type;            // speaker type
    char[28]  future;
};

// note: the origin for azimuth is right (as by math conventions dealing with radians);
// the elevation origin is also right, visualizing a rotation of a circle across the
// -pi/pi axis of the horizontal circle. thus, an elevation of -pi/2 corresponds
// to bottom, and a speaker standing on the left, and 'beaming' upwards would have
// an azimuth of -pi, and an elevation of pi/2.
// for user interface representation, grads are more likely to be used, and the
// origins will obviously 'shift' accordingly.

//---Speaker Arrangement---------------------------
struct VstSpeakerArrangement
{
    uint type;                // (was float lfeGain; // LFE channel gain is adjusted [dB] higher than other channels)
    uint numChannels;        // number of channels in this speaker arrangement
    VstSpeakerProperties[8] speakers;    // variable
};

//---Speaker Types---------------------------------
enum kSpeaker
{
    Undefined = 0x7fffffff,    // Undefinded
    M = 0,                    // Mono (M)
    L,                        // Left (L)
    R,                        // Right (R)
    C,                        // Center (C)
    Lfe,                    // Subbass (Lfe)
    Ls,                        // Left Surround (Ls)
    Rs,                        // Right Surround (Rs)
    Lc,                        // Left of Center (Lc)
    Rc,                        // Right of Center (Rc)
    S,                        // Surround (S)
    Cs = kSpeaker.S,            // Center of Surround (Cs) = Surround (S)
    Sl,                        // Side Left (Sl)
    Sr,                        // Side Right (Sr)
    Tm,                        // Top Middle (Tm)
    Tfl,                    // Top Front Left (Tfl)
    Tfc,                    // Top Front Center (Tfc)
    Tfr,                    // Top Front Right (Tfr)
    Trl,                    // Top Rear Left (Trl)
    Trc,                    // Top Rear Center (Trc)
    Trr,                    // Top Rear Right (Trr)
    Lfe2                    // Subbass 2 (Lfe2)
};

// user-defined speaker types (to be extended in the negative range)
// (will be handled as their corresponding speaker types with abs values:
// e.g abs(kSpeakerU1) == kSpeakerL, abs(kSpeakerU2) == kSpeakerR)
enum kSpeakerU
{
    _32 = -32,
    _31,
    _30,
    _29,
    _28,
    _27,
    _26,
    _25,
    _24,
    _23,
    _22,
    _21,
    _20,            // == kSpeakerLfe2
    _19,            // == kSpeakerTrr
    _18,            // == kSpeakerTrc
    _17,            // == kSpeakerTrl
    _16,            // == kSpeakerTfr
    _15,            // == kSpeakerTfc
    _14,            // == kSpeakerTfl
    _13,            // == kSpeakerTm
    _12,            // == kSpeakerSr
    _11,            // == kSpeakerSl
    _10,            // == kSpeakerCs
    _9,                // == kSpeakerS
    _8,                // == kSpeakerRc
    _7,                // == kSpeakerLc
    _6,                // == kSpeakerRs
    _5,                // == kSpeakerLs
    _4,                // == kSpeakerLfe
    _3,                // == kSpeakerC
    _2,                // == kSpeakerR
    _1                // == kSpeakerL
};

//---Speaker Arrangement Types---------------------
enum kSpeakerArr
{
    UserDefined = -2,
    Empty = -1,

    Mono  =  0,    // M

    Stereo,            // L R
    StereoSurround,    // Ls Rs
    StereoCenter,    // Lc Rc
    StereoSide,        // Sl Sr
    StereoCLfe,        // C Lfe

    _30Cine,            // L R C
    _30Music,            // L R S
    _31Cine,            // L R C Lfe
    _31Music,            // L R Lfe S

    _40Cine,            // L R C   S (LCRS)
    _40Music,            // L R Ls  Rs (Quadro)
    _41Cine,            // L R C   Lfe S (LCRS+Lfe)
    _41Music,            // L R Lfe Ls Rs (Quadro+Lfe)

    _50,                // L R C Ls  Rs
    _51,                // L R C Lfe Ls Rs

    _60Cine,            // L R C   Ls  Rs Cs
    _60Music,            // L R Ls  Rs  Sl Sr
    _61Cine,            // L R C   Lfe Ls Rs Cs
    _61Music,            // L R Lfe Ls  Rs Sl Sr

    _70Cine,            // L R C Ls  Rs Lc Rc
    _70Music,            // L R C Ls  Rs Sl Sr
    _71Cine,            // L R C Lfe Ls Rs Lc Rc
    _71Music,            // L R C Lfe Ls Rs Sl Sr

    _80Cine,            // L R C Ls  Rs Lc Rc Cs
    _80Music,            // L R C Ls  Rs Cs Sl Sr
    _81Cine,            // L R C Lfe Ls Rs Lc Rc Cs
    _81Music,            // L R C Lfe Ls Rs Cs Sl Sr

    _102,                // L R C Lfe Ls Rs Tfl Tfc Tfr Trl Trr Lfe2

    NumSpeakerArr
};

//-------------------------------------------------
// Offline Processing
//-------------------------------------------------

struct VstOfflineTask
{
    char[96]    processName;    // set by plug

    // audio access
    double    readPosition;        // set by plug/host
    double    writePosition;        // set by plug/host
    uint    readCount;            // set by plug/host
    uint    writeCount;            // set by plug
    uint    sizeInputBuffer;    // set by host
    uint    sizeOutputBuffer;    // set by host
    void*    inputBuffer;        // set by host
    void*    outputBuffer;        // set by host
    double    positionToProcessFrom;    // set by host
    double    numFramesToProcess;    // set by host
    double    maxFramesToWrite;    // set by plug

    // other data access
    void*    extraBuffer;        // set by plug
    uint    value;                // set by host or plug
    uint    index;                // set by host or plug

    // file attributes
    double    numFramesInSourceFile;    // set by host
    double    sourceSampleRate;        // set by host or plug
    double    destinationSampleRate;    // set by host or plug
    uint    numSourceChannels;        // set by host or plug
    uint    numDestinationChannels;    // set by host or plug
    uint    sourceFormat;            // set by host
    uint    destinationFormat;        // set by plug
    char[512]    outputText;        // set by plug or host

    // progress notification
    double    progress;                // set by plug
    uint    progressMode;            // reserved for future
    char[100]    progressText;        // set by plug

    uint    flags;                    // set by host and plug; see VstOfflineTaskFlags
    uint    returnValue;            // reserved for future
    void*    hostOwned;                // set by host
    void*    plugOwned;                // set by plug

    char[1024]    future;
};

//---VstOfflineTask Flags--------------------------
enum VstOfflineTaskFlags
{
    // set by host
    kVstOfflineUnvalidParameter    = 1 << 0,
    kVstOfflineNewFile            = 1 << 1,

    // set by plug
    kVstOfflinePlugError        = 1 << 10,
    kVstOfflineInterleavedAudio    = 1 << 11,
    kVstOfflineTempOutputFile    = 1 << 12,
    kVstOfflineFloatOutputFile    = 1 << 13,
    kVstOfflineRandomWrite        = 1 << 14,
    kVstOfflineStretch            = 1 << 15,
    kVstOfflineNoThread            = 1 << 16
};

//---Option passed to offlineRead/offlineWrite-----
enum VstOfflineOption
{
   kVstOfflineAudio,        // reading/writing audio samples
   kVstOfflinePeaks,        // reading graphic representation
   kVstOfflineParameter,    // reading/writing parameters
   kVstOfflineMarker,        // reading/writing marker
   kVstOfflineCursor,        // reading/moving edit cursor
   kVstOfflineSelection,    // reading/changing selection
   kVstOfflineQueryFiles    // to request the host to call asynchronously offlineNotify
};

//---Structure passed to offlineNotify and offlineStart
struct VstAudioFile
{
    uint    flags;                // see enum VstAudioFileFlags
    void*    hostOwned;            // any data private to host
    void*    plugOwned;            // any data private to plugin
    char[100]    name;            // file title
    uint    uniqueId;            // uniquely identify a file during a session
    double    sampleRate;            // file sample rate
    uint    numChannels;        // number of channels (1 for mono, 2 for stereo...)
    double    numFrames;            // number of frames in the audio file
    uint    format;                // reserved for future
    double    editCursorPosition;    // -1 if no such cursor
    double    selectionStart;        // frame index of first selected frame, or -1
    double    selectionSize;        // number of frames in selection, or 0
    uint    selectedChannelsMask;    // 1 bit per channel
    uint    numMarkers;            // number of markers in the file
    uint    timeRulerUnit;        // see doc for possible values
    double    timeRulerOffset;    // offset in time ruler (positive or negative)
    double    tempo;                // as bpm
    uint    timeSigNumerator;    // time signature numerator
    uint    timeSigDenominator;    // time signature denominator
    uint    ticksPerBlackNote;    // resolution
    uint    smpteFrameRate;        // smpte rate (set as in VstTimeInfo)

    char[64]    future;
};

//---VstAudioFile Flags----------------------------
enum VstAudioFileFlags
{
    // set by host (in call offlineNotify)
    kVstOfflineReadOnly                = 1 << 0,
    kVstOfflineNoRateConversion        = 1 << 1,
    kVstOfflineNoChannelChange        = 1 << 2,

    // Set by plug (in function offlineStart)
    kVstOfflineCanProcessSelection    = 1 << 10,
    kVstOfflineNoCrossfade            = 1 << 11,
    kVstOfflineWantRead                = 1 << 12,
    kVstOfflineWantWrite            = 1 << 13,
    kVstOfflineWantWriteMarker        = 1 << 14,
    kVstOfflineWantMoveCursor        = 1 << 15,
    kVstOfflineWantSelect            = 1 << 16
};

//---VstAudioFileMarker----------------------------
struct VstAudioFileMarker
{
    double    position;
    char[32]    name;
    uint    type;
    uint    id;
    uint    reserved;
};

//-------------------------------------------------
// Others
//-------------------------------------------------

//---Structure used for openWindow and closeWindow
struct VstWindow
{
    char[128]  title;    // title
    short xPos;          // position and size
    short yPos;
    short width;
    short height;
    uint  style;         // 0: with title, 1: without title

    void *parent;        // parent of this window
    void *userHandle;    // reserved
    void *winHandle;     // reserved

    char[104] future;
};

//---Structure and enum used for keyUp/keyDown-----
struct VstKeyCode
{
    uint character;
    ubyte virt;     // see enum VstVirtualKey
    ubyte modifier; // see enum VstModifierKey
};

//---Used by member virt of VstKeyCode-------------
enum VstVirtualKey
{
    VKEY_BACK = 1,
    VKEY_TAB,
    VKEY_CLEAR,
    VKEY_RETURN,
    VKEY_PAUSE,
    VKEY_ESCAPE,
    VKEY_SPACE,
    VKEY_NEXT,
    VKEY_END,
    VKEY_HOME,

    VKEY_LEFT,
    VKEY_UP,
    VKEY_RIGHT,
    VKEY_DOWN,
    VKEY_PAGEUP,
    VKEY_PAGEDOWN,

    VKEY_SELECT,
    VKEY_PRINT,
    VKEY_ENTER,
    VKEY_SNAPSHOT,
    VKEY_INSERT,
    VKEY_DELETE,
    VKEY_HELP,
    VKEY_NUMPAD0,
    VKEY_NUMPAD1,
    VKEY_NUMPAD2,
    VKEY_NUMPAD3,
    VKEY_NUMPAD4,
    VKEY_NUMPAD5,
    VKEY_NUMPAD6,
    VKEY_NUMPAD7,
    VKEY_NUMPAD8,
    VKEY_NUMPAD9,
    VKEY_MULTIPLY,
    VKEY_ADD,
    VKEY_SEPARATOR,
    VKEY_SUBTRACT,
    VKEY_DECIMAL,
    VKEY_DIVIDE,
    VKEY_F1,
    VKEY_F2,
    VKEY_F3,
    VKEY_F4,
    VKEY_F5,
    VKEY_F6,
    VKEY_F7,
    VKEY_F8,
    VKEY_F9,
    VKEY_F10,
    VKEY_F11,
    VKEY_F12,
    VKEY_NUMLOCK,
    VKEY_SCROLL,

    VKEY_SHIFT,
    VKEY_CONTROL,
    VKEY_ALT,

    VKEY_EQUALS
};

//---Used by member modifier of VstKeyCode---------
enum VstModifierKey
{
    MODIFIER_SHIFT     = 1<<0, // Shift
    MODIFIER_ALTERNATE = 1<<1, // Alt
    MODIFIER_COMMAND   = 1<<2, // Control on Mac
    MODIFIER_CONTROL   = 1<<3  // Ctrl on PC, Apple on Mac
};


//---Used by audioMasterOpenFileSelector-----------
struct VstFileType
{
    this(char* _name, char* _macType, char* _dosType, char* _unixType = null,
        char* _mimeType1 = null, char* _mimeType2 = null)
    {
        import core.stdc.string : strcpy;
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // TODO: use strncpy to avoid overflow
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        if (_name)
            strcpy(this.name.ptr, _name);
        if (_macType)
            strcpy(this.macType.ptr, _macType);
        if (_dosType)
            strcpy(this.dosType.ptr, _dosType);
        if (_unixType)
            strcpy(this.unixType.ptr, _unixType);
        if (_mimeType1)
            strcpy(this.mimeType1.ptr, _mimeType1);
        if (_mimeType2)
            strcpy(this.mimeType2.ptr, _mimeType2);
    }
    char[128] name;
    char[8] macType;
    char[8] dosType;
    char[8] unixType;
    char[128] mimeType1;
    char[128] mimeType2;
};

struct VstFileSelect
{
    uint command;           // see enum kVstFileLoad....
    uint type;              // see enum kVstFileType...

    uint macCreator;        // optional: 0 = no creator

    uint nbFileTypes;       // nb of fileTypes to used
    VstFileType *fileTypes; // list of fileTypes

    char[1024] title;       // text display in the file selector's title

    char *initialPath;      // initial path

    char *returnPath;       // use with kVstFileLoad and kVstDirectorySelect
                            // if null is passed, the host will allocated memory
                            // the plugin should then called closeOpenFileSelector for freeing memory
    uint sizeReturnPath;

    char **returnMultiplePaths; // use with kVstMultipleFilesLoad
                                // the host allocates this array. The plugin should then called closeOpenFileSelector for freeing memory
    uint nbReturnPath;            // number of selected paths

    uint reserved;                // reserved for host application
    char[116] future;            // future use
};

enum kVst2
{
    FileLoad = 0,
    FileSave,
    MultipleFilesLoad,
    DirectorySelect,

    FileType = 0
};

//---Structure used for effBeginLoadBank/effBeginLoadProgram--
struct VstPatchChunkInfo
{
    uint version_;        // Format Version (should be 1)
    uint pluginUniqueID;// UniqueID of the plugin
    uint pluginVersion; // Plugin Version
    uint numElements;    // Number of Programs (Bank) or Parameters (Program)
    char[48] future;
};


//---PanLaw Type-----------------------------------
enum k
{
    LinearPanLaw = 0,    // L = pan * M; R = (1 - pan) * M;
    EqualPowerPanLaw    // L = pow (pan, 0.5) * M; R = pow ((1 - pan), 0.5) * M;
};

// Plugin's entry point
alias VSTPluginMainFunc = extern (C) AEffect* function(audioMasterCallback host);
// Plugin's dispatcher function
alias DispatcherFunc = extern (C) void*/*VstIntPtr*/ function(AEffect *effect, int opCode,
  int index, int value, void *ptr, float opt);
// Plugin's getParameter() method
alias GetParameterFunc = extern (C) float function(AEffect *effect, int index);
// Plugin's setParameter() method
alias SetParameterFunc = extern (C) void function(AEffect *effect, int index, float value);
// Plugin's processEvents() method
alias ProcessEventsFunc = extern (C) int function(VstEvents *events);
// Plugin's process() method
alias ProcessFunc = extern (C) void function(AEffect *effect, float **inputs,
  float **outputs, int sampleFrames);



import mar.passfail;
import mar.c : cstring;
AEffect* loadPlugin(cstring path, audioMasterCallback hostCallback)
{
    import mar.sentinel : lit;
    version (Windows)
        import mar.windows.kernel32 : GetLastError, LoadLibraryA, GetProcAddress;
    import audio.log;
    logDebug("loadPlugin: ", path);

    version (Windows)
    {
        auto mod = LoadLibraryA(path);
        if (mod.isNull)
        {
            logError("LoadLibrary '", path, "' failed, e=", GetLastError());
            return null; // fail
        }
        auto vstPluginMain = cast(VSTPluginMainFunc)GetProcAddress(mod, lit!"VSTPluginMain".ptr);
        if (!vstPluginMain)
        {
            logError("GetProcAddress on '", path, "' for 'VSTPluginMain' failed, e=", GetLastError());
            return null; // fail
        }
        return vstPluginMain(hostCallback);
    }
    else
    {
        return null;
    }
}
