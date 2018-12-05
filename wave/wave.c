#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include "BinaryConversion.macros.c"

#include "wave.h"


void WaveFormatPrint(const WaveFormat *waveFormat)
{
  printf("Format           : %u\n", waveFormat->format);
  printf("Channels         : %u\n", waveFormat->channels);
  printf("SamplesPerSecond : %u\n", waveFormat->samplesPerSecond);
  printf("AvgBytesPerSecond: %u\n", waveFormat->avgBytesPerSecond);
  printf("BlockAlign       : %u\n", waveFormat->blockAlign);
  printf("BitsPerSample    : %u\n", waveFormat->bitsPerSample);
}
void WaveFormatWrite(const WaveFormat *waveFormat, char *array)
{
  TwoByteValueToLittleEndian (array,  0, waveFormat->format);
  TwoByteValueToLittleEndian (array,  2, waveFormat->channels);
  FourByteValueToLittleEndian(array,  4, waveFormat->samplesPerSecond);
  FourByteValueToLittleEndian(array,  8, waveFormat->avgBytesPerSecond);
  TwoByteValueToLittleEndian (array, 12, waveFormat->blockAlign);
  TwoByteValueToLittleEndian (array, 14, waveFormat->bitsPerSample);
}

// returns error message and wavePcmData
char *TryReadWaveFile(const char *filename, WaveFormat* waveFormat, char **outWaveData, unsigned int *outWaveDataLength)
{
  const int fileDesc = open(filename, O_RDONLY);
  if(fileDesc < 0) return "failed to open file";

  char eightBytes[8];
  int bytesRead;


#define VerifyChunkID(chunkID, error)				\
  if(eightBytes[0] != chunkID[0] ||				\
     eightBytes[1] != chunkID[1] ||				\
     eightBytes[2] != chunkID[2] ||				\
     eightBytes[3] != chunkID[3]) {				\
    close(fileDesc);						\
    return error;						\
  }
#define ReadChunkIDOnly()				\
  bytesRead = read(fileDesc, eightBytes, 4);		\
  if(bytesRead <= 0) goto READ_ERROR
#define ReadChunkIDAndLength(assignLengthTo)		\
  bytesRead = read(fileDesc, eightBytes, 8);		\
  if(bytesRead <= 0) goto READ_ERROR;			\
  assignLengthTo = ToUInt32LittleEndian(eightBytes, 4)
#define ReadUShort(assignTo)				\
  bytesRead = read(fileDesc, eightBytes, 2);		\
  if(bytesRead <= 0) goto READ_ERROR;			\
  assignTo = ToUShortLittleEndian(eightBytes, 0)
#define ReadUInt32(assignTo)				\
  bytesRead = read(fileDesc, eightBytes, 4);		\
  if(bytesRead <= 0) goto READ_ERROR;			\
  assignTo = ToUInt32LittleEndian(eightBytes, 0)

  int riffChunkLength;
  ReadChunkIDAndLength(riffChunkLength);
  VerifyChunkID("RIFF", "invalid format, file did not begin with 'RIFF'");

  ReadChunkIDOnly();
  VerifyChunkID("WAVE", "invalid format, the 'WAVE' chunk id was not the first item inside the 'RIFF' chunk");

  int fmtLength;
  ReadChunkIDAndLength(fmtLength);
  VerifyChunkID("fmt ", "invalid format, the 'fmt ' chunk id was not the first item inside the 'WAVE' chunk");
  if(fmtLength < 16) {
    close(fileDesc);
    return "unexpected end of file";
  }

  ReadUShort(waveFormat->format);
  ReadUShort(waveFormat->channels);
  ReadUInt32(waveFormat->samplesPerSecond);
  ReadUInt32(waveFormat->avgBytesPerSecond);
  ReadUShort(waveFormat->blockAlign);
  ReadUShort(waveFormat->bitsPerSample);

  if(fmtLength > 16) {
    //printf("Debug: skipping %d bytes\n", fmtLength - 16);
    int returnValue = lseek(fileDesc, fmtLength - 16, SEEK_CUR);
    if(returnValue < 0) {
      close(fileDesc);
      return "lseek failed";
    }
  }

  int waveDataLength;
  ReadChunkIDAndLength(waveDataLength);
  VerifyChunkID("data", "invalid format, the 'data' chunk id did not follow the 'fmt ' chunk");
  
  if(waveDataLength < 0) return "negative data size";

  //printf("Debug: waveDataLength %d\n", waveDataLength);
  char *waveData = malloc(waveDataLength);
  int totalBytesRead = 0;
  do {
    bytesRead = read(fileDesc, waveData + totalBytesRead, waveDataLength - totalBytesRead);
    if(bytesRead <= 0) {
      free(waveData);
      goto READ_ERROR;
    }
    totalBytesRead += bytesRead;
    //printf("Debug: TotalBytesRead %d LastBytesRead %d\n", totalBytesRead, bytesRead);
  } while(totalBytesRead < waveDataLength);

  *outWaveData = waveData;
  *outWaveDataLength = waveDataLength;

  return NULL;

 READ_ERROR:
  close(fileDesc);
  return (bytesRead == 0) ? "unexpected end of file" : "read error";
}


#define WAVE_FILE_HEADER "RIFFSIZEWAVEfmt SIZE0123456789012345dataSIZE"
char *TryWriteWaveFile(const char *filename, const WaveFormat* waveFormat, const char *waveData, unsigned int waveDataLength)
{
  int fileDesc = creat(filename, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH);
  if(fileDesc < 0) return "failed to create file";


  char header[sizeof(WAVE_FILE_HEADER)];
  strcpy(header, WAVE_FILE_HEADER);
  FourByteValueToLittleEndian(header,  4, sizeof(header) - 1 + waveDataLength);
  FourByteValueToLittleEndian(header, 16, 16);
  WaveFormatWrite(waveFormat, header + 20);
  FourByteValueToLittleEndian(header, 40, waveDataLength)

  write(fileDesc, header, sizeof(header) - 1);

  write(fileDesc, waveData, waveDataLength);
  
  close(fileDesc);
}
