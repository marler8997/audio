#include <stdio.h>
#include <windows.h>
#include <mmreg.h>
#include <math.h>

#include "render.h"

//--------------------------------
// Public Data
AudioFormat audioFormatID;
WAVEFORMATEXTENSIBLE waveFormat;
SRWLOCK renderLock;

uint32 bufferByteLength;
uint32 bufferSampleCount;
byte* activeBuffer;
byte* renderBuffer;
//--------------------------------


HWAVEOUT waveOut;
typedef struct {
  WAVEHDR hdr;
  HANDLE freeEvent;
  LARGE_INTEGER writeTime;
  LARGE_INTEGER setEventTime;
} CUSTOMWAVEHDR;
CUSTOMWAVEHDR headers[2];

typedef struct {
  SinOscillator oscillator;
  float frequency;
} UniqueSinOscillator;

LARGE_INTEGER performanceFrequency;
float msPerTicks;

// Macros that need to be defined by the audio format

byte platformInit()
{
  // Setup Headers
  for(int i = 0; i < 2; i++) {
    PLATFORM_ZERO_MEM(&headers[i], sizeof(WAVEHDR));
    headers[i].freeEvent = CreateEvent(NULL, TRUE, TRUE, NULL);
    if(headers[i].freeEvent == NULL) {
      printf("CreateEvent failed\n");
      return 1;
    }
  }

  if(QueryPerformanceFrequency(&performanceFrequency) == 0) {
    msPerTicks = 1000.0 / (float)performanceFrequency.QuadPart;
    printf("QueryPerformanceFrequency failed\n");
    return 1;
  }

  return 0;
}

// TODO: define a function to get the AudioFormat string (platform dependent?)

// 0 = success
byte setAudioFormatAndBufferConfig(AudioFormat format,
				   uint32 samplesPerSecond,
				   byte channelSampleBitLength,
				   byte channelCount,
				   uint32 bufferSampleCount_)
{
  //
  // Setup audio format
  //
  audioFormatID = format;

  waveFormat.Format.nSamplesPerSec  = samplesPerSecond;

  waveFormat.Format.wBitsPerSample  = channelSampleBitLength;
  waveFormat.Format.nBlockAlign     = channelSampleBitLength / 8 * channelCount;

  waveFormat.Format.nChannels       = channelCount;

  waveFormat.Format.nAvgBytesPerSec = SAMPLE_BYTE_LENGTH * samplesPerSecond;
  
  if(format == WAVE_FORMAT_PCM) {
    waveFormat.Format.wFormatTag      = WAVE_FORMAT_PCM;
    waveFormat.Format.cbSize          = 0; // Size of extra info
  } else if(format == WAVE_FORMAT_FLOAT) {
    waveFormat.Format.wFormatTag      = WAVE_FORMAT_EXTENSIBLE;
    waveFormat.Format.cbSize          = 22; // Size of extra info
    waveFormat.Samples.wValidBitsPerSample = channelSampleBitLength;
    waveFormat.dwChannelMask          = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
    waveFormat.SubFormat              = KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;
  } else {
    printf("Unsupported format %d\n", format);
    return 1;
  }
  
  // Setup Buffers
  bufferSampleCount = bufferSampleCount_;
  bufferByteLength = bufferSampleCount_ * SAMPLE_BYTE_LENGTH;
  
  for(int i = 0; i < 2; i++) {
    if(headers[i].hdr.lpData) {
      free(headers[i].hdr.lpData);
    }
    
    headers[i].hdr.dwBufferLength = bufferByteLength;
    headers[i].hdr.lpData = (LPSTR)malloc(bufferByteLength);
    if(headers[i].hdr.lpData == NULL) {
      printf("malloc failed\n");
      return 1;
    }
    headers[i].freeEvent = CreateEvent(NULL, TRUE, TRUE, NULL);
    if(headers[i].freeEvent == NULL) {
      printf("CreateEvent failed\n");
      return 1;
    }
  }

  return 0;
}

void waitForKey(const char* msg)
{
  printf("Press enter to %s...", msg);
  fflush(stdout);
  getchar();
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

DWORD CALLBACK audioWriteLoop(LPVOID param)
{
  /*
  // Set priority
  if(!SetPriorityClass(GetCurrentProcess(), REALTIME_PRIORITY_CLASS)) {
    printf("SetPriorityClass failed\n");
    return 1;
  }
  */

  printf("Expected write time %.1f ms\n", (float)BUFFER_SAMPLE_COUNT * 1000.0 / (float)SAMPLES_PER_SECOND);

  LARGE_INTEGER start, finish;

  //headers[0].hdr.lpData = bufferConfig.render;
  //headers[1].hdr.lpData = bufferConfig.active;
  
  // Write the first buffer
  PLATFORM_ZERO_MEM(headers[1].hdr.lpData, BUFFER_BYTE_LENGTH); // Zero out memory for last buffer
  activeBuffer = (byte*)headers[1].hdr.lpData;
  renderBuffer = (byte*)headers[0].hdr.lpData;
  render(); // renders to header[0] (bufferConfig.render)
  waveOutPrepareHeader(waveOut, &headers[0].hdr, sizeof(WAVEHDR)); // IS THIS CALL NECESSARY?
  if(!ResetEvent(headers[0].freeEvent)) {
    printf("ResetEvent failed (error=%d)\n", GetLastError());
    return 1;
  }
  QueryPerformanceCounter(&headers[0].writeTime);
  waveOutWrite(waveOut, &headers[0].hdr, sizeof(WAVEHDR));
  
  char lastBufferIndex = 0;
  char bufferIndex     = 1;
  
  while(true) {
    //printf("Rendering buffer %d\n", bufferIndex);

    activeBuffer = (byte*)headers[lastBufferIndex].hdr.lpData;
    renderBuffer = (byte*)headers[bufferIndex].hdr.lpData;
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
    waveOutWrite(waveOut, &headers[bufferIndex].hdr, sizeof(WAVEHDR));
    
    {
      char temp = bufferIndex;
      bufferIndex = lastBufferIndex;
      lastBufferIndex = temp;
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
	  AcquireSRWLockExclusive(&renderLock);
	  if(KeyOscillators[code].oscillator.renderer.state >= RENDER_STATE_RELEASE) {

	    char needToAdd = KeyOscillators[code].oscillator.renderer.state == RENDER_STATE_DONE;
	    KeyOscillators[code].oscillator.renderer.state = RENDER_STATE_SUSTAIN;

	    if(KeyOscillators[code].frequency == 0) {
	      printf("Key code %d 0x%x '%c' has no frequency\n", code, code, (char)code);
	    } else {
	      //printf("Key code %d 0x%x '%c' has frequency %f\n", code, code, (char)code,
	      //KeyOscillators[code].frequency);
	      if(AUDIO_FORMAT == WAVE_FORMAT_PCM) {
		SinOscillator_initPcm16(&KeyOscillators[code].oscillator, KeyOscillators[code].frequency, .2);
	      } else if(AUDIO_FORMAT == WAVE_FORMAT_FLOAT) {
		SinOscillator_initFloat(&KeyOscillators[code].oscillator, KeyOscillators[code].frequency, .2);
	      } else {
		printf("unsupported audio format %d\n", AUDIO_FORMAT);
		return 1;
	      }
	      if(needToAdd)
		addRenderer(&(KeyOscillators[code].oscillator.renderer));
	    }
	  }
	  ReleaseSRWLockExclusive(&renderLock);
	} else {
	  AcquireSRWLockExclusive(&renderLock);
	  if(KeyOscillators[code].frequency == 0) {
	    KeyOscillators[code].oscillator.renderer.state = RENDER_STATE_DONE;
	  } else {
	    KeyOscillators[code].oscillator.renderer.state = RENDER_STATE_RELEASE;
	  }
	  ReleaseSRWLockExclusive(&renderLock);
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

byte shim()
{
  MMRESULT result;
  
  InitializeSRWLock(&renderLock);
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

