#ifndef WINDOWS_PLATFORM_H

#include <windows.h>

void printHResult(const char* errorMessage, HRESULT hr);
void printGuid(GUID guid);
const char* getMMRESULTString(MMRESULT result);
void printWaveFormat(WAVEFORMATEX* waveFormat);

typedef WORD WaveFormat;
// WAVE_FORMAT_PCM (already defined in windows.h)
#define WAVE_FORMAT_FLOAT (WAVE_FORMAT_PCM+1)





#endif
