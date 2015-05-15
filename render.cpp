#include <stdint.h>
#include <math.h>
#include <stdio.h>

#include "render.h"

// These structures should live somewhere else
extern AudioFormat audioFormat;
extern BufferConfig bufferConfig;

// 0 = success
char setAudioFormatAndBufferConfig(WaveFormat format,
				   uint32_t samplesPerSecond,
				   uint8_t channelSampleBitLength,
				   uint8_t channelCount,
				   uint32_t bufferSampleCount)
{
  audioFormat.format                 = format;
  audioFormat.samplesPerSecond       = samplesPerSecond;
  audioFormat.channelSampleBitLength = channelSampleBitLength;
  audioFormat.channelCount           = channelCount;
  audioFormat.sampleByteLength       = channelSampleBitLength / 8 * channelCount;

  bufferConfig.sampleCount = bufferSampleCount;
  bufferConfig.byteLength  = bufferSampleCount * audioFormat.sampleByteLength;
  bufferConfig.render = (char*)malloc(bufferConfig.byteLength);
  bufferConfig.active = (char*)malloc(bufferConfig.byteLength);
  return bufferConfig.render != NULL && bufferConfig.active != NULL;
}
void setBufferConfig(uint32_t bufferSampleCount);

void SinOscillator_renderBlockPcm16(AudioRenderer* ptr, char* block)
{
  SinOscillator* o = (SinOscillator*)ptr;

  float currentPhase = o->currentPhase;

  char* blockLimit = block + bufferConfig.byteLength;
  
  if(ptr->state == RENDER_STATE_RELEASE) {
    while(block < blockLimit) {
      ptr->volume -= .0001;
      if(ptr->volume < 0) {
	ptr->state = RENDER_STATE_DONE;
	return;
      }
      
      // ASSUMING 16 bits per sample and 2 channels
      uint16_t note = (uint16_t)*((uint32_t*)block);
      note += (uint16_t)(ptr->volume * sin(currentPhase) * 0x7FFF);

      *((uint32_t*)block) = note << 16 | note;

      currentPhase += o->increment;
      if(currentPhase > TWO_PI) {
	currentPhase -= TWO_PI;
      }

      block += audioFormat.sampleByteLength;
    }
  } else {
    while(block < blockLimit) {

      // ASSUMING 16 bits per sample and 2 channels
      uint16_t note = (uint16_t)*((uint32_t*)block);
      note += (uint16_t)(ptr->volume * sin(currentPhase) * 0x7FFF);

      *((uint32_t*)block) = note << 16 | note;

      currentPhase += o->increment;
      if(currentPhase > TWO_PI) {
	currentPhase -= TWO_PI;
      }

      block += audioFormat.sampleByteLength;
    }
  }

  o->currentPhase = currentPhase;
}
void SinOscillator_initPcm16(SinOscillator* o, float frequency, float volume)
{
  o->renderer.object.destructor = 0;
  o->renderer.renderBlock = &SinOscillator_renderBlockPcm16;
  o->renderer.volume = volume;
  o->increment = TWO_PI * frequency / audioFormat.samplesPerSecond;
  o->currentPhase = 0;
  o->releasing = 0;
}

void SinOscillator_renderBlockFloat(AudioRenderer* ptr, char* block)
{
  SinOscillator* o = (SinOscillator*)ptr;

  float currentPhase = o->currentPhase;

  char* blockLimit = block + bufferConfig.byteLength;
  
  if(ptr->state == RENDER_STATE_RELEASE) {
    while(block < blockLimit) {
      ptr->volume -= .0001;
      if(ptr->volume < 0) {
	ptr->state = RENDER_STATE_DONE;
	return;
      }
      
      float note = ((float*)block)[0];
      note += ptr->volume * sin(currentPhase);

      for(uint8_t i = 0; i < audioFormat.channelCount; i++) {
	((float*)block)[i] = note;
      }

      currentPhase += o->increment;
      if(currentPhase > TWO_PI) {
	currentPhase -= TWO_PI;
      }

      block += audioFormat.sampleByteLength;
    }
  } else {
    while(block < blockLimit) {

      float note = ((float*)block)[0];
      note += ptr->volume * sin(currentPhase);

      for(uint8_t i = 0; i < audioFormat.channelCount; i++) {
	((float*)block)[i] = note;
      }

      currentPhase += o->increment;
      if(currentPhase > TWO_PI) {
	currentPhase -= TWO_PI;
      }

      block += audioFormat.sampleByteLength;
    }
  }

  o->currentPhase = currentPhase;
}
void SinOscillator_initFloat(SinOscillator* o, float frequency, float volume)
{
  o->renderer.object.destructor = 0;
  o->renderer.renderBlock = &SinOscillator_renderBlockFloat;
  o->renderer.volume = volume;
  o->increment = TWO_PI * frequency / audioFormat.samplesPerSecond;
  o->currentPhase = 0;
  o->releasing = 0;
}
