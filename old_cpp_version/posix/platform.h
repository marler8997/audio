#ifndef WINDOWS_PLATFORM_H

#include <stdint.h>
#include <stdlib.h>

// Define the standard types
typedef unsigned char byte;

typedef int16_t  int16;
typedef uint16_t uint16;

typedef int32_t  int32;
typedef uint32_t uint32;

//void printHResult(const char* errorMessage, HRESULT hr);
//void printGuid(GUID guid);
//const char* getMMRESULTString(MMRESULT result);
//void printWaveFormat(WAVEFORMATEX* waveFormat);

//typedef WORD WaveFormat;
// WAVE_FORMAT_PCM (already defined in windows.h)
//#define WAVE_FORMAT_FLOAT (WAVE_FORMAT_PCM+1)

//#define PLATFORM_ZERO_MEM(ptr,byteLength) memset(ptr, 0, byteLength)

//#define PLATFORM_RENDER_LOCK() 
//AcquireSRWLockExclusive(&renderLock)
//#define PLATFORM_RENDER_UNLOCK()
//ReleaseSRWLockExclusive(&renderLock)

//#define PLATFORM_DEFINE_EXTERNS
//extern SRWLOCK renderLock;

#endif
