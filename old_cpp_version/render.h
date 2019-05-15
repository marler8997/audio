#ifndef RENDER_H
#define RENDER_H

#include "platform.h"

#define TWO_PI (3.14159265358979 * 2)
/*
typedef struct {
  AudioFormat format;
  uint32 samplesPerSecond;
  byte channelSampleBitLength;
  byte channelCount;
  byte sampleByteLength; // byte-aligned length of a full sample
} AudioFormat;
typedef struct {
  uint32 sampleCount;
  uint32 byteLength;
  char* render;
  char* active;
} BufferConfig;
*/
// 0 = success
/*
char setAudioFormatAndBufferConfig(WaveFormat format,
				   uint32 samplesPerSecond,
				   byte channelSampleBitLength,
				   byte channelCount,
				   uint32 bufferSampleCount);
*/
typedef struct ObjectStruct {
  void (*destructor)(ObjectStruct* o);
} Object;

typedef enum {
  RENDER_STATE_ATTACK  = 0,
  RENDER_STATE_SUSTAIN = 1,
  RENDER_STATE_DELAY   = 2,
  RENDER_STATE_RELEASE = 3,
  RENDER_STATE_DONE    = 4
} RenderState;


// NOTE: This Audio Renderer Uses a renderBlock function
// pointer and a RenderState.  There may be some
// renderers that don't need a render state but instead just
// change the renderBlock pointer.
typedef struct AudioRendererStruct {
  struct ObjectStruct object;
  void (*renderBlock)(AudioRendererStruct* o, byte* block);
  float volume; // 0.0 to 1.0
  RenderState state;
} AudioRenderer;

typedef struct {
  AudioRenderer renderer;
  float increment; // READONLY
  float currentPhase;
  char releasing;
} SinOscillator;
void SinOscillator_initPcm16(SinOscillator* o, float frequency, float volume);
void SinOscillator_initFloat(SinOscillator* o, float frequency, float volume);

byte initializeRenderers(uint32 capacity);
void addRenderer(AudioRenderer* renderer);
void render();

#endif
