#ifndef WAVE_H
#define WAVE_H

typedef struct {
  unsigned short format;
  unsigned short channels;
  unsigned int samplesPerSecond;
  unsigned int avgBytesPerSecond; //
  unsigned short blockAlign;          // = channels
  unsigned short bitsPerSample;
} WaveFormat;

void WaveFormatPrint(const WaveFormat *waveFormat);
char *TryReadWaveFile(const char *filename, WaveFormat* waveFormat,
		      char **outWaveData, unsigned int *outWaveDataLength);
char *TryWriteWaveFile(const char *filename, const WaveFormat* waveFormat,
		       const char *waveData, unsigned int waveDataLength);
#endif
