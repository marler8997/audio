#include <stdio.h>
#include <Mmdeviceapi.h>
#include <Audioclient.h>

#include "platform.h"

#define REFTIMES_PER_MS 100000


// 0 = success
char testAudioDevice(IMMDevice* device)
{
  HRESULT hr;

  IAudioClient* client;
  hr = device->Activate(__uuidof(IAudioClient),
			CLSCTX_ALL,
			NULL,
			(void**)&client);
  if(hr) {printHResult("IMMDevice.Activate failed", hr);return 1;}

  WAVEFORMATEX* waveFormat;
  hr = client->GetMixFormat(&waveFormat);
  if(hr) {printHResult("IAudioClient.GetMixFormat failed", hr);return 1;}

  printWaveFormat(waveFormat);

  hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED,
			  0,
			  REFTIMES_PER_MS * 100,
			  0,
			  waveFormat,
			  NULL);
  if(hr) {printHResult("IAudioClient.Initialize failed", hr);return 1;}

  //
  // TODO: write code to render audio to the device
  //
  {
    //if(
  }

  return 0;
}

const char* debug_GetDeviceStateString(DWORD state)
{
  switch(state) {
  case DEVICE_STATE_ACTIVE    : return "ACTIVE";
  case DEVICE_STATE_DISABLED  : return "DISABLED";
  case DEVICE_STATE_NOTPRESENT: return "NOTPRESENT";
  case DEVICE_STATE_UNPLUGGED : return "UNPLUGGED";
  default: return "DEVICE_STATE_UNKNOWN";
  }
}
// returns 0 on success
char printMMDevice(IMMDevice* device)
{
  HRESULT hr;

  {
    LPWSTR id;
    hr = device->GetId(&id);
    if(hr) {printHResult("IMMDevice.GetId failed", hr);return 1;}
    wprintf(L"    device->GetID    = '%s'\n", id);
  }
  {  
    DWORD state;
    hr = device->GetState(&state);
    if(hr) {printHResult("IMMDevice.GetState failed", hr);return 1;}
    printf("    device->GetState = %s\n", debug_GetDeviceStateString(state));
  }
  return 0;
}

// return 0 on success
char tryGetDefaultAudioEndpoint(IMMDeviceEnumerator* enumerator, EDataFlow dataFlow, ERole role)
{
  HRESULT hr;

  IMMDevice* device;

  printf("tryGetDefaultAudioEndpoint(%d,%d)\n", dataFlow, role);

  hr = enumerator->GetDefaultAudioEndpoint(dataFlow,
					   role,
					   &device);
  if(hr) {printHResult("GetDefaultAudioEndpoint failed", hr);return 1;}

  printf("  DefaultDevice:\n");

  return printMMDevice(device);
}
// returns 0 on success
char tryEnumAudioEndpoints(IMMDeviceEnumerator* enumerator,
			   EDataFlow dataFlowFilter,
			   DWORD stateMaskFilter)
{
  HRESULT hr;

  IMMDeviceCollection* devices;

  hr = enumerator->EnumAudioEndpoints(dataFlowFilter, stateMaskFilter, &devices);
  if(hr) {printHResult("EnumAudioEndpoints failed", hr);return 1;}

  UINT deviceCount;
  hr = devices->GetCount(&deviceCount);
  if(hr) {printHResult("IMMDeviceCollection->GetCount failed", hr);return 1;}
  
  printf("Found %d devices\n", deviceCount);

  for(UINT i = 0; i < deviceCount; i++) {
    IMMDevice* device;
    hr = devices->Item(i, &device);
    if(hr) {printHResult("IMMDeviceCollection->Item failed", hr);return 1;}

    printf("  Device %d:\n", i);
    printMMDevice(device);

    testAudioDevice(device);
  }

  return 0;
}
int main(int args, char* argv[])
{
  HRESULT hr;
  const char* error;
  IMMDeviceEnumerator *enumerator;
  
  // Initializes the COM library.  Required before calling any Co methods.
  hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if(hr) {printHResult("CoInitializeEx failed", hr);return 1;}

  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator),
			NULL,
			CLSCTX_ALL,
			__uuidof(IMMDeviceEnumerator),
			(void**)&enumerator);
  if(hr) {printHResult("CoCreateInstance failed", hr);return 1;}

  // print common guids
  printf("KSDATAFORMAT_SUBTYPE_PCM        ");
  printGuid(KSDATAFORMAT_SUBTYPE_PCM);
  printf("\n");
  printf("KSDATAFORMAT_SUBTYPE_MPEG       ");
  printGuid(KSDATAFORMAT_SUBTYPE_MPEG);
  printf("\n");
  printf("KSDATAFORMAT_SUBTYPE_ADPCM      ");
  printGuid(KSDATAFORMAT_SUBTYPE_ADPCM);
  printf("\n");
  printf("KSDATAFORMAT_SUBTYPE_ALAW       ");
  printGuid(KSDATAFORMAT_SUBTYPE_ALAW);
  printf("\n");
  printf("KSDATAFORMAT_SUBTYPE_DRM        ");
  printGuid(KSDATAFORMAT_SUBTYPE_DRM);
  printf("\n");
  printf("KSDATAFORMAT_SUBTYPE_IEEE_FLOAT ");
  printGuid(KSDATAFORMAT_SUBTYPE_IEEE_FLOAT);
  printf("\n");
  printf("KSDATAFORMAT_SUBTYPE_MULAW      ");
  printGuid(KSDATAFORMAT_SUBTYPE_MULAW);
  printf("\n");
  printf("KSDATAFORMAT_SUBTYPE_IEC61937_DOLBY_DIGITAL      ");
  printGuid(KSDATAFORMAT_SUBTYPE_IEC61937_DOLBY_DIGITAL);
  printf("\n");
  printf("KSDATAFORMAT_SUBTYPE_IEC61937_DOLBY_DIGITAL_PLUS ");
  printGuid(KSDATAFORMAT_SUBTYPE_IEC61937_DOLBY_DIGITAL_PLUS);
  printf("\n");


  //printf("--------------------------------------\n");
  //printf("GetDefaultAudioEndpoint:\n");
  //printf("--------------------------------------\n");
  //tryGetDefaultAudioEndpoint(enumerator, eRender, eConsole);

  printf("--------------------------------------\n");
  printf("EnumAudioEndpoints:\n");
  printf("--------------------------------------\n");

  //tryEnumAudioEndpoints(enumerator, eAll, DEVICE_STATEMASK_ALL);
  tryEnumAudioEndpoints(enumerator, eRender, DEVICE_STATE_ACTIVE | DEVICE_STATE_UNPLUGGED);
  
  return 0;
}
