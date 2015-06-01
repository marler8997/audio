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

void fillSinWave(LPSTR block, float frequency)
{
  float currentPhase = 0;
  float phaseIncrement = TWO_PI / waveFormat.nSamplesPerSec * frequency;

  //printf("phaseIncrement = %f\n", phaseIncrement);
  
  for(DWORD i = 0; i < bufferSampleCount; i++) {

    *((DWORD*)block) = (DWORD)(10000.0 * sin(currentPhase));
    *((DWORD*)block) |= *((DWORD*)block) << waveFormat.wBitsPerSample;

    currentPhase += phaseIncrement;
    if(currentPhase > TWO_PI) {
      currentPhase -= TWO_PI;
    }

    block += waveFormat.nBlockAlign;
  }
}
void addSinWave(LPSTR block, float frequency)
{
  float currentPhase = 0;
  float phaseIncrement = TWO_PI / waveFormat.nSamplesPerSec * frequency;

  //printf("phaseIncrement = %f\n", phaseIncrement);
  
  for(DWORD i = 0; i < bufferSampleCount; i++) {

    *((DWORD*)block) += (DWORD)(10000.0 * sin(currentPhase));
    *((DWORD*)block) |= *((DWORD*)block) << waveFormat.wBitsPerSample;

    currentPhase += phaseIncrement;
    if(currentPhase > TWO_PI) {
      currentPhase -= TWO_PI;
    }

    block += waveFormat.nBlockAlign;
  }
}



void writeAudioBlock(HWAVEOUT waveOut, LPSTR block, DWORD byteSize)
{
  WAVEHDR header;

  ZeroMemory(&header, sizeof(WAVEHDR));
  header.dwBufferLength = byteSize;
  header.lpData = block;

  waveOutPrepareHeader(waveOut, &header, sizeof(WAVEHDR));
  waveOutWrite(waveOut, &header, sizeof(WAVEHDR));

  printf("[DEBUG] header = 0x%p\n", header);
  // Wait for the block to play then unprepare header
  Sleep(500);
  while(waveOutUnprepareHeader(waveOut, &header, sizeof(WAVEHDR)) == WAVERR_STILLPLAYING) {
    Sleep(100);
  }
}
char testNoCallback(float seconds, float frequency)
{
  MMRESULT result;

  HWAVEOUT waveOut;
  result = waveOutOpen(&waveOut,
		       WAVE_MAPPER,
		       &waveFormat,
		       0,
		       0,
		       CALLBACK_NULL);
  if(result != MMSYSERR_NOERROR) {
    printf("waveOutOpen failed (result=%d)\n", result);
    return 1;
  }

  printf("Opened Wave Mapper!\n");
  fflush(stdout);
  
  DWORD sampleCount = seconds * waveFormat.nSamplesPerSec;
  LPSTR block = allocateBlock(sampleCount);
  fillSinWave(block, frequency, sampleCount);
  
  printf("Writing block...\n");
  fflush(stdout);
  writeAudioBlock(waveOut, block, sampleCount * waveFormat.nBlockAlign);

  waveOutClose(waveOut);

  return 0;
}



//
// The Callback Function Method
//
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
    printf("[DEBUG] [tid=%d] waveOutCallback (msg=%d WOM_DONE)\n", GetCurrentThreadId(), msg);
    //printf("[DEBUG] header (dwBufferLength=%d,lpData=0x%p)\n",
    //header->dwBufferLength, header->lpData);
    waveOutUnprepareHeader(waveOut, header, sizeof(WAVEHDR));
    break;
  }
  default:
    printf("[DEBUG] [tid=%d] waveOutCallback (msg=%d)\n", GetCurrentThreadId(), msg);
    break;
  }
  fflush(stdout);
}
void writeBlock(HWAVEOUT waveOut, LPWAVEHDR header)
{
  waveOutPrepareHeader(waveOut, header, sizeof(WAVEHDR));
  waveOutWrite(waveOut, header, sizeof(WAVEHDR));
}
char testFunctionCallback(float seconds, float frequency)
{
  MMRESULT result;

  HWAVEOUT waveOut;
  result = waveOutOpen(&waveOut,
		       WAVE_MAPPER,
		       &waveFormat,
		       (DWORD_PTR)&waveOutCallback,
		       0,
		       CALLBACK_FUNCTION);
  if(result != MMSYSERR_NOERROR) {
    printf("waveOutOpen failed (result=%d)\n", result);
    return 1;
  }

  printf("[tid=%d] Opened Wave Mapper!\n", GetCurrentThreadId());
  fflush(stdout);
  
  waitForKey("to start rendering sound");

  DWORD sampleCount = seconds * waveFormat.nSamplesPerSec;
  LPSTR block1 = allocateBlock(sampleCount);
  LPSTR block2 = allocateBlock(sampleCount);
  fillSinWave(block1, frequency, sampleCount);
  fillSinWave(block2, frequency * 1.5, sampleCount);
  
  printf("Writing block (0x%p)...\n", block1);
  fflush(stdout);

  {
    WAVEHDR header1;
    WAVEHDR header2;
    
    ZeroMemory(&header1, sizeof(WAVEHDR));
    header1.dwBufferLength = sampleCount * waveFormat.nBlockAlign;
    header1.lpData = block1;
    
    writeBlock(waveOut, &header1);

    ZeroMemory(&header2, sizeof(WAVEHDR));
    header2.dwBufferLength = sampleCount * waveFormat.nBlockAlign;
    header2.lpData = block2;
    
    writeBlock(waveOut, &header2);
  }
  waitForKey("to close");

  waveOutClose(waveOut);

  return 0;
}

