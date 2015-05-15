#include <stdio.h>
#include <windows.h>
#include <mmreg.h>
#include <math.h>

#include "render.h"

// Used by render.o object file
AudioFormat audioFormat;
BufferConfig bufferConfig;

// Audio Render Information
WAVEFORMATEXTENSIBLE waveFormat;
SRWLOCK renderDataLock;
HWAVEOUT waveOut;

typedef struct {
  SinOscillator oscillator;
  float frequency;
} UniqueSinOscillator;

#define AUDIO_BUFFER_COUNT 2

typedef struct {
  WAVEHDR hdr;
  HANDLE freeEvent;
  LARGE_INTEGER writeTime;
  LARGE_INTEGER setEventTime;
} CUSTOMWAVEHDR;
CUSTOMWAVEHDR headers[AUDIO_BUFFER_COUNT];

LARGE_INTEGER performanceFrequency;
float msPerTicks;

// 0 = success
// Note: must call before setting buffer length
char setupWindowsWaveFormat()
{
  waveFormat.Format.nSamplesPerSec  = audioFormat.samplesPerSecond;
  waveFormat.Format.wBitsPerSample  = audioFormat.channelSampleBitLength;
  waveFormat.Format.nChannels       = audioFormat.channelCount;

  if(audioFormat.format == WAVE_FORMAT_PCM) {
    waveFormat.Format.wFormatTag      = WAVE_FORMAT_PCM;
    waveFormat.Format.nBlockAlign     = audioFormat.sampleByteLength;
    waveFormat.Format.nAvgBytesPerSec = audioFormat.sampleByteLength * audioFormat.samplesPerSecond;
    waveFormat.Format.cbSize          = 0; // Size of extra info
  } else if(audioFormat.format == WAVE_FORMAT_FLOAT) {
    waveFormat.Format.wFormatTag      = WAVE_FORMAT_EXTENSIBLE;
    waveFormat.Format.nBlockAlign     = audioFormat.sampleByteLength;
    waveFormat.Format.nAvgBytesPerSec = audioFormat.sampleByteLength * audioFormat.samplesPerSecond;
    waveFormat.Format.cbSize          = 22; // Size of extra info
    waveFormat.Samples.wValidBitsPerSample = audioFormat.channelSampleBitLength;
    waveFormat.dwChannelMask          = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
    waveFormat.SubFormat              = KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;
  } else {
    printf("Unsupported format %d\n", audioFormat.format);
    return 1;
  }
  return 0;
}

void waitForKey(const char* msg)
{
  printf("Press enter to %s...", msg);
  fflush(stdout);
  getchar();
}

// Need a function to copy a wave window for a specified amount of time
// Note: maybe this can be hardware accelerated? DMA?
// Input: Pointer to sound buffer
//        Pointer to start offset (where to start copying the sound) (not necessary)
//        Pointer to sound buffer limit
//        Pointer to finish the copy
// Output: length

// Input: pointer to sound buffer
//        length of sound to copy
//        limit of copy
// Output: offset into sound that was copied to fill the last copy
size_t copySound(char* sound, size_t soundLength, char *destLimit)
{
  destLimit -= soundLength;

  char* dest = sound + soundLength;
  while(dest <= destLimit) {
    memcpy(dest, sound, soundLength);
    dest += soundLength;
  }
  
  size_t left = destLimit + soundLength - dest;
  memcpy(dest, sound, left);

  return left;
}

// 0 = success, 1 = out of memory, 2 = prepareHeader error
char initializeBuffers(HWAVEOUT waveOut)
{
  for(int i = 0; i < AUDIO_BUFFER_COUNT; i++) {
    ZeroMemory(&headers[i], sizeof(WAVEHDR));
    headers[i].hdr.dwBufferLength = bufferConfig.byteLength;
    headers[i].hdr.lpData = (LPSTR)malloc(bufferConfig.byteLength);
    if(headers[i].hdr.lpData == NULL)
      return 1;
    headers[i].freeEvent = CreateEvent(NULL, TRUE, TRUE, NULL);
    if(headers[i].freeEvent == NULL) {
      printf("CreateEvent failed\n");
      return 1;
    }
  }
  return 0;
}

//
// Render Data
//
AudioRenderer **renderers;
DWORD currentRendererCapacity;
DWORD currentRendererCount;

void initializeRenderers(DWORD capacity)
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
void renderRelease(char* block, uint32_t fullNote)
{
  int16_t maxDiff = (int16_t)(audioFormat.samplesPerSecond / 100 * 2);

  int16_t note = (int16_t)(fullNote & 0xFFFF);
  if(fullNote >> 16 == (uint16_t)note) {
    if(note > 0) {
      while(true) {
	note -= maxDiff;
	if(note < 0)
	  break;
	*((uint32_t*)block) = note << 16 | note;
	printf("[DEBUG] release %d\n", note);
	
	block += audioFormat.sampleByteLength;
      }	
    } else {
      while(true) {
	note += maxDiff;
	if(note > 0)
	  break;
	*((uint32_t*)block) = note << 16 | note;
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
  ZeroMemory(bufferConfig.render, bufferConfig.byteLength);
  AcquireSRWLockExclusive(&renderDataLock);
  if(currentRendererCount == 0) {
    ReleaseSRWLockExclusive(&renderDataLock);

    //uint32_t fullNote = (((uint32_t*)lastBlock)[bufferConfig.sampleCount-1]);
    //renderRelease(block, fullNote);

  } else {
    //printf("There are %d renderers\n", currentRendererCount);
    for(uint32_t i = 0; i < currentRendererCount; i++) {
      AudioRenderer* renderer = renderers[i];
      
      if(renderer->state != RENDER_STATE_DONE)
	renderer->renderBlock(renderer, bufferConfig.render);

      if(renderer->state == RENDER_STATE_DONE) {
	// REMOVE the renderer
	for(uint32_t j = i; j+1 < currentRendererCount; j++) {
	  renderers[j] = renderers[j+1];
	}
	currentRendererCount--;
	i--;
      }
    }
    ReleaseSRWLockExclusive(&renderDataLock);
  }
}


void CALLBACK waveOutCallback(HWAVEOUT waveOut, UINT msg, DWORD_PTR instance,
		     DWORD_PTR param1, DWORD_PTR param2)
{
  //printf("[DEBUG] waveOutCallback (instance=0x%p,param1=0x%p,param2=0x%p)\n",
  //instance, param1, param2);
  switch(msg) {
  case WOM_OPEN:
    printf("[DEBUG] [tid=%d] waveOutCallback (msg=%d WOM_OPEN)\n", GetCurrentThreadId(), msg);
    break;
  case WOM_CLOSE:
    printf("[DEBUG] [tid=%d] waveOutCallback (msg=%d WOM_CLOSE)\n", GetCurrentThreadId(), msg);
    break;
  case WOM_DONE: {
    WAVEHDR* header = (WAVEHDR*) param1;
    //printf("[DEBUG] [tid=%d] waveOutCallback (msg=%d WOM_DONE)\n", GetCurrentThreadId(), msg);
    //printf("[DEBUG] header (dwBufferLength=%d,lpData=0x%p)\n",
    //header->dwBufferLength, header->lpData);
    QueryPerformanceCounter(&(((CUSTOMWAVEHDR*)header)->setEventTime));
    SetEvent(((CUSTOMWAVEHDR*)header)->freeEvent);
    break;
  }
  default:
    printf("[DEBUG] [tid=%d] waveOutCallback (msg=%d)\n", GetCurrentThreadId(), msg);
    break;
  }
  fflush(stdout);
}

void waveOutWriteShim(HWAVEOUT waveOut, WAVEHDR* header, DWORD size)
{
  /*
  char* block = header->lpData;
  for(uint32_t i = 0; i < bufferConfig.sampleCount; i++) {
    // ASSUMING 16 bits per sample and 2 channels
    int16_t note = (int16_t)*((uint32_t*)block);
    //printf("%h\n", note);
    printf("%d\n", note);
    block += audioFormat.sampleByteLength;
  }
  */
  waveOutWrite(waveOut, header, size);
}

DWORD CALLBACK audioWriteLoop(LPVOID param)
{
  /*
  // Set priority
  if(!SetPriorityClass(GetCurrentProcess(), REALTIME_PRIORITY_CLASS)) {
    printf("SetPriorityClass failed\n");
    return 1;
  }
  */

  printf("Expected write time %.1f ms\n", (float)bufferConfig.sampleCount * 1000.0 / (float)audioFormat.samplesPerSecond);

  LARGE_INTEGER start, finish;

  headers[0].hdr.lpData = bufferConfig.render;
  headers[1].hdr.lpData = bufferConfig.active;
  
  // Write the first buffer
  ZeroMemory(headers[1].hdr.lpData, bufferConfig.byteLength); // Zero out memory for last buffer
  render(); // renders to header[0] (bufferConfig.render)
  waveOutPrepareHeader(waveOut, &headers[0].hdr, sizeof(WAVEHDR)); // IS THIS CALL NECESSARY?
  if(!ResetEvent(headers[0].freeEvent)) {
    printf("ResetEvent failed (error=%d)\n", GetLastError());
    return 1;
  }
  QueryPerformanceCounter(&headers[0].writeTime);
  waveOutWriteShim(waveOut, &headers[0].hdr, sizeof(WAVEHDR));
  
  {
    char* temp = bufferConfig.render;
    bufferConfig.render = bufferConfig.active;
    bufferConfig.active = temp;
  }

  char lastBufferIndex = 0;
  char bufferIndex     = 1;
  
  while(true) {
    //printf("Rendering buffer %d\n", bufferIndex);

    QueryPerformanceCounter(&start);
    render();
    QueryPerformanceCounter(&finish);
    LONGLONG renderTime = finish.QuadPart - start.QuadPart;
    
    QueryPerformanceCounter(&start);
    waveOutPrepareHeader(waveOut, &headers[bufferIndex].hdr, sizeof(WAVEHDR));
    QueryPerformanceCounter(&finish);
    LONGLONG prepareTime = finish.QuadPart - start.QuadPart;
    
    if(!ResetEvent(headers[bufferIndex].freeEvent)) {
      printf("ResetEvent failed (error=%d)\n", GetLastError());
      return 1;
    }

    QueryPerformanceCounter(&headers[bufferIndex].writeTime);
    waveOutWriteShim(waveOut, &headers[bufferIndex].hdr, sizeof(WAVEHDR));
    
    {
      char temp = bufferIndex;
      bufferIndex = lastBufferIndex;
      lastBufferIndex = temp;
      char* tempBuffer = bufferConfig.render;
      bufferConfig.render = bufferConfig.active;
      bufferConfig.active = tempBuffer;
    }    

    QueryPerformanceCounter(&start);
    WaitForSingleObject(headers[bufferIndex].freeEvent, INFINITE);
    QueryPerformanceCounter(&finish);
    LONGLONG waitTime = finish.QuadPart - start.QuadPart;

    QueryPerformanceCounter(&start);
    waveOutUnprepareHeader(waveOut, &headers[bufferIndex].hdr, sizeof(WAVEHDR));
    QueryPerformanceCounter(&finish);
    LONGLONG unprepareTime = finish.QuadPart - start.QuadPart;

    /*
    printf("Buffer %d stats render=%.1f ms, perpare=%.1f ms, write=%.1f ms, setEvent=%.1f ms, unprepare=%.1f ms, waited=%.1f ms\n", bufferIndex,
	   renderTime * msPerTicks,
	   prepareTime * msPerTicks,
	   (headers[bufferIndex].setEventTime.QuadPart - headers[bufferIndex].writeTime.QuadPart) * msPerTicks,
	   (finish.QuadPart - headers[bufferIndex].setEventTime.QuadPart) * msPerTicks,
	   unprepareTime * msPerTicks,
	   waitTime    * msPerTicks);
    */
  }
}

// 0 = success
char readNotes()
{
  INPUT_RECORD inputBuffer[128];

  HANDLE stdinHandle = GetStdHandle(STD_INPUT_HANDLE);
  if(stdinHandle == INVALID_HANDLE_VALUE) {
    printf("Error: GetStdHandle failed\n");
    return 1;
  }
  
  // Save old input mode
  DWORD oldMode;
  if(!GetConsoleMode(stdinHandle, &oldMode)) {
    printf("Error: GetConsoleMode failed (error=%d)\n", GetLastError());
    return 1;
  }

  if(!SetConsoleMode(stdinHandle, ENABLE_WINDOW_INPUT | ENABLE_MOUSE_INPUT)) {
    printf("Error: SetConsoleMode failed (error=%d)\n", GetLastError());
    return 1;
  }

  static UniqueSinOscillator KeyOscillators[256];
  for(WORD i = 0; i < 256; i++) {
    KeyOscillators[i].frequency = 0;
    KeyOscillators[i].oscillator.renderer.state = RENDER_STATE_DONE; // keeps note from being started multiple times
  }
  KeyOscillators['Z'          ].frequency = 261.63; // C
  KeyOscillators['S'          ].frequency = 277.18; // C#
  KeyOscillators['X'          ].frequency = 293.66; // D
  KeyOscillators['D'          ].frequency = 311.13; // D#
  KeyOscillators['C'          ].frequency = 329.63; // E
  KeyOscillators['V'          ].frequency = 349.23; // F
  KeyOscillators['G'          ].frequency = 369.99; // F#
  KeyOscillators['B'          ].frequency = 392.00; // G
  KeyOscillators['H'          ].frequency = 415.30; // G#
  KeyOscillators['N'          ].frequency = 440.00; // A
  KeyOscillators['J'          ].frequency = 466.16; // A#
  KeyOscillators['M'          ].frequency = 493.88; // B
  KeyOscillators[VK_OEM_COMMA ].frequency = 523.25; // C
  KeyOscillators['L'          ].frequency = 554.37; // C#
  KeyOscillators[VK_OEM_PERIOD].frequency = 587.33; // D
  KeyOscillators[VK_OEM_1     ].frequency = 622.25; // D# ';'
  KeyOscillators[VK_OEM_2     ].frequency = 659.25; // E  '/'
  
  
  printf("Use keyboard for sounds (ESC to exit)\n");
  fflush(stdout);
  
  BOOL continueLoop = true;
  while(continueLoop) {
    DWORD inputCount;
    if(!ReadConsoleInput(stdinHandle, inputBuffer, 128, &inputCount)) {
      printf("Error: ReadConsoleInput failed (error=%d)\n", GetLastError());
      SetConsoleMode(stdinHandle, oldMode);
      return 1;
    }

    for(DWORD i = 0; i < inputCount; i++) {
      switch(inputBuffer[i].EventType) {
      case KEY_EVENT: {
	/*
	printf("KeyEvent code=%d 0x%x ascii=%c '%s' state=%d\n",
	       inputBuffer[i].Event.KeyEvent.wVirtualKeyCode,
	       inputBuffer[i].Event.KeyEvent.wVirtualKeyCode,
	       inputBuffer[i].Event.KeyEvent.uChar.AsciiChar,
	       inputBuffer[i].Event.KeyEvent.bKeyDown ? "down" : "up",
	       inputBuffer[i].Event.KeyEvent.dwControlKeyState);
	*/
	WORD code = inputBuffer[i].Event.KeyEvent.wVirtualKeyCode;

	// Quit from ESCAPE or CTL-C
	if((code == VK_ESCAPE) ||
	   (code == 'C' &&
	   (inputBuffer[i].Event.KeyEvent.dwControlKeyState & (LEFT_CTRL_PRESSED |
							       RIGHT_CTRL_PRESSED)))) {
	  continueLoop = false;
	  break;
	}

	if(inputBuffer[i].Event.KeyEvent.bKeyDown) {
	  AcquireSRWLockExclusive(&renderDataLock);
	  if(KeyOscillators[code].oscillator.renderer.state >= RENDER_STATE_RELEASE) {

	    char needToAdd = KeyOscillators[code].oscillator.renderer.state == RENDER_STATE_DONE;
	    KeyOscillators[code].oscillator.renderer.state = RENDER_STATE_SUSTAIN;

	    if(KeyOscillators[code].frequency == 0) {
	      printf("Key code %d 0x%x '%c' has no frequency\n", code, code, (char)code);
	    } else {
	      //printf("Key code %d 0x%x '%c' has frequency %f\n", code, code, (char)code,
	      //KeyOscillators[code].frequency);
	      if(audioFormat.format == WAVE_FORMAT_PCM) {
		SinOscillator_initPcm16(&KeyOscillators[code].oscillator, KeyOscillators[code].frequency, .2);
	      } else if(audioFormat.format == WAVE_FORMAT_FLOAT) {
		SinOscillator_initFloat(&KeyOscillators[code].oscillator, KeyOscillators[code].frequency, .2);
	      } else {
		printf("unsupported audio format %d\n", audioFormat.format);
		return 1;
	      }
	      if(needToAdd)
		addRenderer(&(KeyOscillators[code].oscillator.renderer));
	    }
	  }
	  ReleaseSRWLockExclusive(&renderDataLock);
	} else {
	  AcquireSRWLockExclusive(&renderDataLock);
	  if(KeyOscillators[code].frequency == 0) {
	    KeyOscillators[code].oscillator.renderer.state = RENDER_STATE_DONE;
	  } else {
	    KeyOscillators[code].oscillator.renderer.state = RENDER_STATE_RELEASE;
	  }
	  ReleaseSRWLockExclusive(&renderDataLock);
	}
	
      }
	break;
      case MOUSE_EVENT:
	//printf("mouse event!\n");
	break;
      case FOCUS_EVENT:
	break;
      default:
	printf("unhandled event %d\n", inputBuffer[i].EventType);
	break;
      }
    }
  }

  return 0;
}

int main(int argc, char* argv[])
{
  MMRESULT result;

  QueryPerformanceFrequency(&performanceFrequency);
  msPerTicks = 1000.0 / (float)performanceFrequency.QuadPart;

  
  //initializeRenderers(1); // Use 1 right now for testing
  initializeRenderers(16);

  //
  // Note: waveOut function will probably not be able to
  //       keep up with a buffer size less then 23 ms (around 1024 samples @ 44100HZ).
  //       This is a limitation on waveOut API (which is pretty high level).
  //       To get better latency, I'll need to use CoreAudio.
  //
  setAudioFormatAndBufferConfig(WAVE_FORMAT_PCM,
				44100, // samplesPerSecond
				16,    // channelSampleBitLength
				2,     // channelCount
				//4410); // bufferSampleCount (about 100 ms)
				2205); // bufferSampleCount (about 50 ms)
                                //1664); // bufferSampleCount (about 40 ms)
				//441); // bufferSampleCount (about 10 ms)
  /*
  setAudioFormatAndBufferConfig(WAVE_FORMAT_FLOAT,
				48000, // samplesPerSecond
				32,    // channelSampleBitLength
				2,     // channelCount
				//4410); // bufferSampleCount (about 100 ms)
				2205); // bufferSampleCount (about 50 ms)
                                //1664); // bufferSampleCount (about 40 ms)
				//441); // bufferSampleCount (about 10 ms)
				*/
  if(setupWindowsWaveFormat())
    return 1;

  InitializeSRWLock(&renderDataLock);
  result = waveOutOpen(&waveOut,
		       WAVE_MAPPER,
		       &waveFormat.Format,
		       (DWORD_PTR)&waveOutCallback,
		       0,
		       CALLBACK_FUNCTION);
  if(result != MMSYSERR_NOERROR) {
    printf("waveOutOpen failed (result=%d '%s')\n", result, getMMRESULTString(result));
    return 1;
  }

  char result2 = initializeBuffers(waveOut);
  if(result2)
    return result2;

  HANDLE audioWriteThread = CreateThread(NULL,
					 0,
					 &audioWriteLoop,
					 NULL,
					 0,
					 0);

  readNotes();
  
  waveOutClose(waveOut);
  
  return 0;
}
