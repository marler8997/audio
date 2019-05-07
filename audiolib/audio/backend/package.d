module audio.backend;

version (Windows)
{
    public import audio.backend.waveout;
}