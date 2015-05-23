#ifndef WINDOWS_PLATFORM_H

#include <windows.h>

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

typedef WORD WaveFormat;
// WAVE_FORMAT_PCM (already defined in windows.h)
#define WAVE_FORMAT_FLOAT (WAVE_FORMAT_PCM+1)

#define PLATFORM_ZERO_MEM(ptr,byteLength)	\
  ZeroMemory(ptr, byteLength);

#define PLATFORM_RENDER_LOCK()    AcquireSRWLockExclusive(&renderLock)
#define PLATFORM_RENDER_UNLOCK()  ReleaseSRWLockExclusive(&renderLock)

#define PLATFORM_DEFINE_EXTERNS			\
  extern SRWLOCK renderLock;

#endif
