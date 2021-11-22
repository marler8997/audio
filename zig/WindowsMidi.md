Here's some things I've learned about MIDI on Windows.

Windows exposes MIDI data through "input" and "output" devices.  It provides a way
to query the devices and open them.  Applications can read MIDI messages from "input" devices
and write MIDI messages to "output" devices.

Windows does not provide a way for userspace applications to create new MIDI devices, this requires
kernel driver suppport.  Tobias Erichsen has created a MIDI driver that allows userspace applications
to create new virtual MIDI devices.

http://www.tobias-erichsen.de/software/virtualMIDI.html

This being said, using a custom API to create a virtual MIDI device may be overkill if all you need
is a way to transfer MIDI data between applications.  For this, Tobias also created a program called
"loopMIDI" which leverages his virtualMIDI driver.

http://www.tobias-erichsen.de/software/loopmidi.html

loopMIDI creates a pair MIDI devices, one for input and one for output.  All MIDI messages sent to the
output device will be forwarded to the input device. Tobias mentions that there have been previous
implementations of this which he calls "loopback MIDI ports" but says that the number of ports was
statically determined at driver install time, whereas with his, new ports could be added without
re-installing the driver.

Tobias' virtualMIDI driver can be used for free, but he requires permission and possibly a commercial
license to distribute software that links to the virtualMIDI sdk.
