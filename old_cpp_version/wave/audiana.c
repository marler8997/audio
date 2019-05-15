#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "BinaryConversion.macros.c"
#include "wave.h"






void PrintSamples(const char *waveData, int cols, int rows)
{
  int index = 0;
  for(int i = 0; i < cols; i++) {
    for(int j = 0; j < rows; j++) {
      if(j > 0) putchar(' ');

      short sample = ToShortLittleEndian(waveData, index);
      printf("%4d", sample);
      index += 2;
    }
    putchar('\n');
  }
}



int main(int argc, char *argv[])
{
  char *errorMessage;

  if(argc < 2) {
    printf("Missing wave file name\n");
    return 1;
  }

  char *waveFileName = argv[1];

  //
  // Read Wave File
  //
  WaveFormat waveFormat;
  char *waveData;
  int waveDataLength;
  errorMessage = TryReadWaveFile(waveFileName, &waveFormat, &waveData, &waveDataLength);
  if(errorMessage) {
    printf("Could not read wave file '%s': %s errno=%d\n", waveFileName, errorMessage, errno);
    return 1;
  }

  WaveFormatPrint(&waveFormat);

  int waveDataIndex = 0;
  while(1) {
    short sample = ToShortLittleEndian(waveData, waveDataIndex);
    if(sample > 10 || sample < -10) {
      printf("At Index %d (%4f\%)\n", waveDataIndex, (float)100* (float)(waveDataIndex) / (float)waveDataLength);
      PrintSamples(waveData + waveDataIndex, 30, 20);
      break;
    }
    waveDataIndex += 2;
  }


  //
  //
  // Transofrm Wave File to become diff
  //
  //
  printf("Transforming audio...\n");
  short lastSample = ToShortLittleEndian(waveData, 0);
  for(int i = 0; (i+3) < waveDataLength; i += 2) {
    short thisSample = ToShortLittleEndian(waveData, i + 2);

    int diff = (int)thisSample - (int)lastSample;
    TwoByteValueToLittleEndian(waveData, i, diff);

    lastSample = thisSample;
  }


  const char *postfix = ".transform.wav";
  char *outputWaveFileName = malloc(strlen(waveFileName) + strlen(postfix) + 1);
  strcpy(outputWaveFileName, waveFileName);
  strcat(outputWaveFileName, postfix);

  printf("Writing wave file '%s'\n", outputWaveFileName);
  errorMessage = TryWriteWaveFile(outputWaveFileName, &waveFormat, waveData, waveDataLength);
  if(errorMessage) {
    printf("Could not write wave file '%s': %s errno=%d\n", outputWaveFileName, errorMessage, errno);
    return 1;
  }
  


  return 0;
}
