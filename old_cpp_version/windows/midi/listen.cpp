#include <stdio.h>

#include "platform.h"

#define MIDI_STATUS(x) LOBYTE(x)
//#define MIDI_DATA(x) LOBYTE(HIWORD(x))

void CALLBACK listenCallback(HMIDIIN midiHandle, UINT msg, DWORD_PTR instance,
			     DWORD_PTR param1, DWORD_PTR param2)
{
  switch(msg) {
  case MIM_OPEN:
    printf("[callback] open\n");
    break;
  case MIM_CLOSE:
    printf("[callback] close\n");
    break;
  case MIM_DATA: {
    // param1 (low byte) = midi event
    // param2            = timestamp
    byte status = MIDI_STATUS(param1);
    byte statusCategory = status & 0xF0;
    if(statusCategory == 0x80) {
      byte note     = HIBYTE(LOWORD(param1));
      byte velocity = LOBYTE(HIWORD(param1));
      printf("[callback] note %d OFF (velocity=%d)\n", note, velocity);
    } else if(statusCategory == 0x90) {
      byte note     = HIBYTE(LOWORD(param1));
      byte velocity = LOBYTE(HIWORD(param1));
      printf("[callback] note %d ON (velocity=%d)\n", note, velocity);
    } else {
      printf("[callback] data (unkown-status)\n");
    }
    //printf("[callback] data (event=%d, timestampe=%d)\n",
    //(byte)param1, param2);
    break;
  } case MIM_LONGDATA:
    printf("[callback] longdata\n");
    break;
  case MIM_ERROR:
    printf("[callback] error\n");
    break;
  case MIM_LONGERROR:
    printf("[callback] longerror\n");
    break;
  case MIM_MOREDATA:
    printf("[callback] moredata\n");
    break;
  default:
    printf("[callback] msg=%d\n", msg);
    break;
  }
  fflush(stdout);
}

#define MIDI_BUFFER_LENGTH 512


MIDIHDR midiHeader;
int listen(UINT deviceID)
{
  int status = 0;
  MMRESULT result;
  HMIDIIN midiHandle;
  
  result = midiInOpen(&midiHandle, deviceID,
		      (DWORD_PTR)&listenCallback,
		      NULL, CALLBACK_FUNCTION);
  if(result != MMSYSERR_NOERROR) {
    printf("midiInOpen failed\n");
    status = 1;
    goto DONE;
  }

  midiHeader.lpData = (LPSTR)malloc(MIDI_BUFFER_LENGTH);
  midiHeader.dwBufferLength = MIDI_BUFFER_LENGTH;

  result = midiInPrepareHeader(midiHandle, &midiHeader, sizeof(midiHeader));
  if(result != MMSYSERR_NOERROR) {
    printf("midiInPrepareHeader failed\n");
    status = 1;
    goto DONE;
  }
  result = midiInAddBuffer(midiHandle, &midiHeader, sizeof(midiHeader));
  if(result != MMSYSERR_NOERROR) {
    printf("midiInAddBuffer failed\n");
    status = 1;
    goto DONE;
  }
  result = midiInStart(midiHandle);
  if(result != MMSYSERR_NOERROR) {
    printf("midiInStart failed\n");
    status = 1;
    goto DONE;
  }

  printf("Press enter to quit...");
  fflush(stdout);
  getchar();

 DONE:

  // TODO: finish cleanup


  midiInClose(midiHandle);

  return status;
}

void usage()
{
  printf("listen input-device-id");
}
int main(int argc, char* argv[])
{
  MMRESULT result;

  UINT deviceID;
  if(argc == 1) {
    usage();
    return 0;
  } else if(argc == 2) {
    char* deviceIDString = argv[1];
    deviceID = atoi(deviceIDString);
    if(deviceID == 0 && deviceIDString[0] != '0') {
      printf("Invalid device id '%s'\n", deviceIDString);
    }
  } else {
    printf("Error: too many command line arguments\n");
    usage();
    return 1;
  }

  //
  // Print the info (just because)
  //
  {
    MIDIINCAPS info;
    result = midiInGetDevCaps(deviceID, &info, sizeof(info));
    if(result != MMSYSERR_NOERROR) {
      printf("  Device %d: midiInGetDevCaps failed\n", deviceID);
      return 1;
    }

    printf("Mid           : %d\n", info.wMid);
    printf("Pid           : %d\n", info.wPid);
    printf("DriverVersion : %d.%d\n", info.vDriverVersion >> 8,
	   (byte)info.vDriverVersion);
    printf("ProductName   : '%s'\n", info.szPname);
  }

  return listen(deviceID);
}
