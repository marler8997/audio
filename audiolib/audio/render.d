module audio.render;

import mar.math : sin;

import audio.log;
import backend = audio.backend;

enum TWO_PI = 3.14159265358979 * 2;

enum RenderState
{
    attack,
    sustain,
    delay,
    release,
    done,
}

// NOTE: This Audio Renderer Uses a renderBlock function
// pointer and a RenderState.  There may be some
// renderers that don't need a render state but instead just
// change the renderBlock pointer.
struct AudioRenderer(T)
{
    void function(T* obj, void* block) renderBlock;
    float volume; // 0.0 to 1.0
    RenderState state;
}

struct SinOscillator
{
    AudioRenderer!SinOscillator base;
    float increment; // READONLY
    float currentPhase;
    char releasing;
    void initPcm16(float frequency, float volume)
    {
        this.base.renderBlock = &renderBlockPcm16;
        this.base.volume = volume;
        this.increment = TWO_PI * frequency / backend.samplesPerSecond;
        this.currentPhase = 0;
        this.releasing = 0;
    }
    void initFloat(float frequency, float volume)
    {
        this.base.renderBlock = &renderBlockFloat;
        this.base.volume = volume;
        this.increment = TWO_PI * frequency / backend.samplesPerSecond;
        this.currentPhase = 0;
        this.releasing = 0;
    }
}

/*
struct Pcm16
{
    static ushort getSample(
}

void renderSin(T)(SinOscillator* o, ubyte* block)
{
    auto currentPhase = o.currentPhase;
    auto blockLimit = block + backend.bufferByteLength;

    if(o.base.state == RenderState.release)
    {
        while(block < blockLimit)
        {
            o.base.volume -= .0001;
            if(o.base.volume < 0)
            {
                o.base.state = RenderState.done;
                return;
            }


            auto note = T.getSample(block);

            // ASSUMING 16 bits per sample and 2 channels
            ushort note = cast(ushort)*(cast(uint*)block);
            note += cast(ushort)(o.base.volume * sin(currentPhase) * 0x7FFF);

            *(cast(uint*)block) = note << 16 | note;

            currentPhase += o.increment;
            if(currentPhase > TWO_PI)
                currentPhase -= TWO_PI;

            block += backend.sampleByteLength;
        }
    }
    else
    {
        while(block < blockLimit)
        {
            // ASSUMING 16 bits per sample and 2 channels
            ushort note = cast(ushort)*(cast(uint*)block);
            note += cast(ushort)(o.base.volume * sin(currentPhase) * 0x7FFF);

            *(cast(uint*)block) = note << 16 | note;

            currentPhase += o.increment;
            if(currentPhase > TWO_PI)
                currentPhase -= TWO_PI;

            block += backend.sampleByteLength;
        }
    }

    o.currentPhase = currentPhase;
}
*/


void renderBlockPcm16(SinOscillator* o, void* block)
{
    auto currentPhase = o.currentPhase;
    auto blockLimit = block + backend.bufferByteLength;

    if(o.base.state == RenderState.release)
    {
        while(block < blockLimit)
        {
            o.base.volume -= .0001;
            if(o.base.volume < 0)
            {
                o.base.state = RenderState.done;
                return;
            }

            // ASSUMING 16 bits per sample and 2 channels
            ushort note = cast(ushort)*(cast(uint*)block);
            note += cast(ushort)(o.base.volume * sin(currentPhase) * 0x7FFF);

            *(cast(uint*)block) = note << 16 | note;

            currentPhase += o.increment;
            if(currentPhase > TWO_PI)
                currentPhase -= TWO_PI;

            block += backend.sampleByteLength;
        }
    }
    else
    {
        while(block < blockLimit)
        {
            // ASSUMING 16 bits per sample and 2 channels
            ushort note = cast(ushort)*(cast(uint*)block);
            note += cast(ushort)(o.base.volume * sin(currentPhase) * 0x7FFF);

            *(cast(uint*)block) = note << 16 | note;

            currentPhase += o.increment;
            if(currentPhase > TWO_PI)
                currentPhase -= TWO_PI;

            block += backend.sampleByteLength;
        }
    }

    o.currentPhase = currentPhase;
}

void renderBlockFloat(SinOscillator* o, void* block)
{
    auto currentPhase = o.currentPhase;
    auto blockLimit = block + backend.bufferByteLength;

    if(o.base.state == RenderState.release)
    {
        while(block < blockLimit)
        {
            o.base.volume -= .0001;
            if(o.base.volume < 0)
            {
                o.base.state = RenderState.done;
                return;
            }

            float note = (cast(float*)block)[0];
            note += o.base.volume * sin(currentPhase);

            for(ubyte i = 0; i < backend.channelCount; i++)
            {
                (cast(float*)block)[i] = note;
            }

            currentPhase += o.increment;
            if(currentPhase > TWO_PI)
            {
                currentPhase -= TWO_PI;
            }

            block += backend.sampleByteLength;
        }
    }
    else
    {
        while(block < blockLimit)
        {
            float note = (cast(float*)block)[0];
            note += o.base.volume * sin(currentPhase);

            for(ubyte i = 0; i < backend.channelCount; i++)
            {
                (cast(float*)block)[i] = note;
            }

            currentPhase += o.increment;
            if(currentPhase > TWO_PI)
            {
                currentPhase -= TWO_PI;
            }

            block += backend.sampleByteLength;
        }
    }

    o.currentPhase = currentPhase;
}


//
// Render Logic
//
__gshared AudioRenderer!void **renderers;
__gshared uint currentRendererCapacity;
__gshared uint currentRendererCount;


ubyte initializeRenderers(uint capacity)
{
    import mar.mem : malloc;
    renderers = cast(AudioRenderer!void**)malloc(capacity * (AudioRenderer!void*).sizeof);
    currentRendererCapacity = capacity;
    currentRendererCount = 0;
    return 0;
}

void addRenderer(T)(AudioRenderer!T* renderer)
{
    addRenderer(cast(AudioRenderer!void*)renderer);
}
void addRenderer(AudioRenderer!void* renderer)
{
    import mar.mem : realloc;
    if(currentRendererCount >= currentRendererCapacity)
    {
        realloc(renderers, currentRendererCapacity * 2);
    }
    renderers[currentRendererCount++] = renderer;
    //printf("Added a renderer (there are now %d renderers)\n", currentRendererCount);
}

/*
// Make sure the sound cuts off nicely
// Assume 16 bit sample 2-channel
void renderRelease(char* block, uint fullNote)
{
  int16 maxDiff = (int16)(audioFormat.samplesPerSecond / 100 * 2);

  int16 note = (int16)(fullNote & 0xFFFF);
  if(fullNote >> 16 == (ushort)note) {
    if(note > 0) {
      while(true) {
	note -= maxDiff;
	if(note < 0)
	  break;
	*((uint*)block) = note << 16 | note;
	printf("[DEBUG] release %d\n", note);
	
	block += audioFormat.sampleByteLength;
      }	
    } else {
      while(true) {
	note += maxDiff;
	if(note > 0)
	  break;
	*((uint*)block) = note << 16 | note;
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
    import mar.mem : zero;
    zero(backend.renderBuffer, backend.bufferByteLength);
    backend.doRenderLock();
    //logDebug("render (", currentRendererCount, " renderers)");
    if(currentRendererCount == 0)
    {
        backend.doRenderUnlock();
        //uint fullNote = (((uint*)lastBlock)[bufferConfig.sampleCount-1]);
        //renderRelease(block, fullNote);
    }
    else
    {
        for (uint rendererIndex = 0; rendererIndex < currentRendererCount; rendererIndex++)
        {
            auto renderer = renderers[rendererIndex];

            if(renderer.state != RenderState.done)
                renderer.renderBlock(renderer, backend.renderBuffer);

            if(renderer.state == RenderState.done)
            {
                // REMOVE the renderer
                //logDebug("renderer is done, removing");
                for(uint j = rendererIndex; j+1 < currentRendererCount; j++)
                {
                    renderers[j] = renderers[j+1];
                }
                currentRendererCount--;
                rendererIndex--;
            }
        }
        backend.doRenderUnlock();
    }
}

