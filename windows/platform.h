#ifndef WINDOWS_PLATFORM_H

#include <windows.h>
#include <mmreg.h>

//#include "waveout.h"

// Define the standard types
typedef unsigned char byte;

typedef INT16 int16;
typedef WORD uint16;

typedef INT int32;
typedef DWORD uint32;

void printHResult(const char* errorMessage, HRESULT hr);
void printGuid(GUID guid);
const char* getMMRESULTString(MMRESULT result);
void printWaveFormat(WAVEFORMATEX* waveFormat);

typedef WORD AudioFormat;
// WAVE_FORMAT_PCM (already defined in windows.h)
#define WAVE_FORMAT_FLOAT (WAVE_FORMAT_PCM+1)

#define PLATFORM_ZERO_MEM(ptr,byteLength)	\
  ZeroMemory(ptr, byteLength);

#define PLATFORM_RENDER_LOCK()    AcquireSRWLockExclusive(&renderLock)
#define PLATFORM_RENDER_UNLOCK()  ReleaseSRWLockExclusive(&renderLock)


#define PLATFORM_DEFINE_RENDER_EXTERNS					\
  extern SRWLOCK renderLock;						\
  extern AudioFormat audioFormatID;					\
  extern WAVEFORMATEXTENSIBLE waveFormat;				\
  extern uint32 bufferByteLength;					\
  extern uint32 bufferSampleCount;					\
  extern byte* activeBuffer;						\
  extern byte* renderBuffer;

// WAVEOUT DEFINES
#define AUDIO_FORMAT       (audioFormatID)
#define SAMPLES_PER_SECOND (waveFormat.Format.nSamplesPerSec)
#define SAMPLE_BIT_LENGTH  (waveFormat.Format.wBitsPerSample)
#define SAMPLE_BYTE_LENGTH (waveFormat.Format.nBlockAlign)
#define CHANNEL_COUNT      (waveFormat.Format.nChannels)

#define BUFFER_SAMPLE_COUNT bufferSampleCount
#define BUFFER_BYTE_LENGTH  bufferByteLength
#define BUFFER_ACTIVE       activeBuffer
#define BUFFER_RENDER       renderBuffer



#endif
