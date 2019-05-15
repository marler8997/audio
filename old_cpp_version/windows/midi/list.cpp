#include <stdio.h>

#include "platform.h"
void usage()
{
  printf("list [i|input|o|output]\n");
}
int main(int argc, char* argv[])
{
  MMRESULT result;

  byte listInputs, listOutputs;
  if(argc == 1) {
    listInputs = 1;
    listOutputs = 1;
  } else if(argc == 2) {
    char* type = argv[1];
    if(strcmp(type, "i") == 0 || strcmp(type, "input") == 0) {
      listInputs = 1;
    } else if(strcmp(type, "o") == 0 || strcmp(type, "ouptut") == 0) {
      listOutputs = 1;
    } else {
      printf("Error: unknown type '%s'\n", type);
      usage();
      return 1;
    }
  } else {
    printf("Error: too many command line args\n");
    usage();
    return 1;
  }

  if(listInputs)
  {
    UINT midiInDeviceCount = midiInGetNumDevs();
    printf("%d Midi IN devices\n", midiInDeviceCount);
    MIDIINCAPS info;
    for(UINT i = 0; i < midiInDeviceCount; i++) {
      result = midiInGetDevCaps(i, &info, sizeof(info));
      if(result != MMSYSERR_NOERROR) {
	printf("  Device %d: midiInGetDevCaps failed\n", i);
      } else {
	printf("  Input Device %d\n", i);
	printf("    Mid           : %d\n", info.wMid);
	printf("    Pid           : %d\n", info.wPid);
	printf("    DriverVersion : %d.%d\n", info.vDriverVersion >> 8,
	       (byte)info.vDriverVersion);
	printf("    ProductName   : '%s'\n", info.szPname);
      }
    }
  }

  if(listOutputs)
  {
    UINT midiOutDeviceCount = midiOutGetNumDevs();
    printf("%d Midi OUT devices\n", midiOutDeviceCount);
    MIDIOUTCAPS info;
    for(UINT i = 0; i < midiOutDeviceCount; i++) {
      result = midiOutGetDevCaps(i, &info, sizeof(info));
      if(result != MMSYSERR_NOERROR) {
	printf("  Device %d: midiOutGetDevCaps failed\n", i);
      } else {
	printf("  Output Device %d\n", i);
	printf("    Mid           : %d\n", info.wMid);
	printf("    Pid           : %d\n", info.wPid);
	printf("    DriverVersion : %d.%d\n", info.vDriverVersion >> 8,
	       (byte)info.vDriverVersion);
	printf("    ProductName   : '%s'\n", info.szPname);
	printf("    Technology    : %d\n", info.wTechnology);
	printf("    Voices        : %d\n", info.wVoices);
	printf("    Notes         : %d\n", info.wNotes);
	printf("    ChannelMask   : 0x%x\n", info.wChannelMask);
	printf("    Support       : %d\n", info.dwSupport);
      }
    }
  }
  
  return 0;
}
