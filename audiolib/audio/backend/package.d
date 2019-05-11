module audio.backend;

version (Windows)
{
    public import audio.backend.waveout;
}
else
{
    public import audio.backend.linux;
}