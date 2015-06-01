#include <stdio.h>
//#include <Mmdeviceapi.h>
//#include <Audioclient.h>

#include "platform.h"
/*
void printHResult(const char* errorMessage, HRESULT hr)
{
  DWORD error = GetLastError();
  printf("%s (hresult %lu 0x%x lasterror %d 0x%x)\n", errorMessage, hr, hr, error, error);
}
void printGuid(GUID guid)
{
  // NOTE: This is endian-specific
  printf("%08X-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X",
	 guid.Data1, guid.Data2, guid.Data3,
	 guid.Data4[0], guid.Data4[1],
	 guid.Data4[2], guid.Data4[3],
	 guid.Data4[4], guid.Data4[5],
	 guid.Data4[6], guid.Data4[7]);
}
void printChannels(DWORD channelMask)
{
  char atFirst = 1;
  if(channelMask & SPEAKER_FRONT_LEFT) {
    if(atFirst) atFirst = 0; else printf(",");
    printf("FRONT_LEFT");
  }
  if(channelMask & SPEAKER_FRONT_RIGHT) {
    if(atFirst) atFirst = 0; else printf(",");
    printf("FRONT_RIGHT");
  }
  if(channelMask & SPEAKER_FRONT_CENTER) {
    if(atFirst) atFirst = 0; else printf(",");
    printf("FRONT_CENTER");
  }
  // TODO: add the rest
}
const char* getMMRESULTString(MMRESULT result)
{
  switch(result) {
  case MMSYSERR_ALLOCATED  : return "already allocated";
  case MMSYSERR_BADDEVICEID: return "bad device id";
  case MMSYSERR_NODRIVER   : return "no driver";
  case MMSYSERR_NOMEM      : return "unable to allocate or lock memory";
  case WAVERR_BADFORMAT    : return "bad wave audio format";
  case WAVERR_SYNC         : return "device is synchronous but missing WAVE_ALLOWSYNC flag";
    //case MMSYSERR_: return "";
  default                  : return "unknown";
  }
}

static const char* getWaveFormatString(WORD format)
{
  switch(format) {
  case WAVE_FORMAT_PCM: return "PCM";
  case WAVE_FORMAT_EXTENSIBLE : return "EXTENSIBLE";
  case WAVE_FORMAT_MPEG : return "MPEG";
  case WAVE_FORMAT_MPEGLAYER3 : return "MPEGLAYER3";
  default: return "?";
  }
}
void printWaveFormat(WAVEFORMATEX* waveFormat)
{
  printf("    WAVEFORMAT:\n");
  printf("      Format           %d '%s'\n", waveFormat->wFormatTag, getWaveFormatString(waveFormat->wFormatTag));
  printf("      SamplesPerSecond %d\n", waveFormat->nSamplesPerSec);
  printf("      BitsPerSample    %d\n", waveFormat->wBitsPerSample);
  printf("      SampleByteLength %d\n", waveFormat->nBlockAlign);
  printf("      Channels         %d\n", waveFormat->nChannels);
  printf("      ExtraSize        %d\n", waveFormat->cbSize);
  if(waveFormat->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
    printf("      EXTENSIBLE FIELDS:\n");
    printf("        Samples(union):\n");
    printf("          ValidBitsPerSample %d\n", ((WAVEFORMATEXTENSIBLE*)waveFormat)->Samples.wValidBitsPerSample);
    printf("          SamplesPerBlock    %d\n", ((WAVEFORMATEXTENSIBLE*)waveFormat)->Samples.wSamplesPerBlock);
    printf("        ChannelMask    0x%x '", ((WAVEFORMATEXTENSIBLE*)waveFormat)->dwChannelMask);
    printChannels(((WAVEFORMATEXTENSIBLE*)waveFormat)->dwChannelMask);
    printf("'\n");
    printf("        SubFormat      ");
    printGuid(((WAVEFORMATEXTENSIBLE*)waveFormat)->SubFormat);
    printf("\n");
  }
}
*/
