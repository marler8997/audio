# Terminology

#### SamplePoint

A single number value of a single sound wave.

#### SampleFrame

A sample frame is a set of consecutive sample points representing the value of multiple sound waves at the same point in time.

Sample frames are used in multi-channel audio where channels are interleaved within the same buffer rather than in their own separate buffers.

#### Sample

An array of sample points or samples frames that represent one or more sound waves.

# TODO

* finish render channel/mix system, allow short-circuiting
* allow audio generators to set or mix
* when a note sustained note is reattacked at a lower velocity, the sustained note is still there...I should test this behavior on a regular piano
* use something other than waveout for windows
* load instrument from json file
* make sure none of the samples start with a buffer of silence
  maybe the program should detect and warn/fix this?
* implement VST
