#include <math.h>
#include <stdio.h>

#include "platform.h"
#include "render.h"

PLATFORM_DEFINE_EXTERNS

// These structures should live somewhere else
extern AudioFormat audioFormat;
extern BufferConfig bufferConfig;

// 0 = success
char setAudioFormatAndBufferConfig(WaveFormat format,
				   uint32 samplesPerSecond,
				   byte channelSampleBitLength,
				   byte channelCount,
				   uint32 bufferSampleCount)
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
void setBufferConfig(uint32 bufferSampleCount);

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
      uint16 note = (uint16)*((uint32*)block);
      note += (uint16)(ptr->volume * sin(currentPhase) * 0x7FFF);

      *((uint32*)block) = note << 16 | note;

      currentPhase += o->increment;
      if(currentPhase > TWO_PI) {
	currentPhase -= TWO_PI;
      }

      block += audioFormat.sampleByteLength;
    }
  } else {
    while(block < blockLimit) {

      // ASSUMING 16 bits per sample and 2 channels
      uint16 note = (uint16)*((uint32*)block);
      note += (uint16)(ptr->volume * sin(currentPhase) * 0x7FFF);

      *((uint32*)block) = note << 16 | note;

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

      for(byte i = 0; i < audioFormat.channelCount; i++) {
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

      for(byte i = 0; i < audioFormat.channelCount; i++) {
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


//
// Render Logic
//
AudioRenderer **renderers;
uint32 currentRendererCapacity;
uint32 currentRendererCount;

void initializeRenderers(uint32 capacity)
{
  renderers = (AudioRenderer**)malloc(capacity * sizeof(AudioRenderer*));
  currentRendererCapacity = capacity;
  currentRendererCount = 0;
}
void addRenderer(AudioRenderer* renderer)
{
  if(currentRendererCount >= currentRendererCapacity) {
    realloc(renderers, currentRendererCapacity * 2);
  }
  renderers[currentRendererCount++] = renderer;
  //printf("Added a renderer (there are now %d renderers)\n", currentRendererCount);
}

/*
// Make sure the sound cuts off nicely
// Assume 16 bit sample 2-channel
void renderRelease(char* block, uint32 fullNote)
{
  int16 maxDiff = (int16)(audioFormat.samplesPerSecond / 100 * 2);

  int16 note = (int16)(fullNote & 0xFFFF);
  if(fullNote >> 16 == (uint16)note) {
    if(note > 0) {
      while(true) {
	note -= maxDiff;
	if(note < 0)
	  break;
	*((uint32*)block) = note << 16 | note;
	printf("[DEBUG] release %d\n", note);
	
	block += audioFormat.sampleByteLength;
      }	
    } else {
      while(true) {
	note += maxDiff;
	if(note > 0)
	  break;
	*((uint32*)block) = note << 16 | note;
	printf("[DEBUG] release %d\n", note);
	
	block += audioFormat.sampleByteLength;
      }	
    }
  } else {
    printf("[WARNING] releasing sound with different phases on left/right is not implemented\n");
  }
}
*/

void render()
{
  PLATFORM_ZERO_MEM(bufferConfig.render, bufferConfig.byteLength);
  PLATFORM_RENDER_LOCK();
  if(currentRendererCount == 0) {
    PLATFORM_RENDER_UNLOCK();

    //uint32 fullNote = (((uint32*)lastBlock)[bufferConfig.sampleCount-1]);
    //renderRelease(block, fullNote);

  } else {
    //printf("There are %d renderers\n", currentRendererCount);
    for(uint32 i = 0; i < currentRendererCount; i++) {
      AudioRenderer* renderer = renderers[i];
      
      if(renderer->state != RENDER_STATE_DONE)
	renderer->renderBlock(renderer, bufferConfig.render);

      if(renderer->state == RENDER_STATE_DONE) {
	// REMOVE the renderer
	for(uint32 j = i; j+1 < currentRendererCount; j++) {
	  renderers[j] = renderers[j+1];
	}
	currentRendererCount--;
	i--;
      }
    }
    PLATFORM_RENDER_UNLOCK();
  }
}

