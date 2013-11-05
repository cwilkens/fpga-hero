fpga-hero
=========

An FPGA implementation of the popular game Guitar Hero. Written in Verilog and developed on a Digilent Nexys 2. No CPU core and no software, everything is done in hardware.

I did this project in 2011 for a Digital Logic Design class. 

A video of the project in action can be seen here:
http://www.youtube.com/watch?v=2A2oCwJN4i8

Basic structure of the code:

PS2control.v - state machine to communicate with unmodified Playstation 2 guitar hero controllers.

PWM_audio.v - module to play the audio from sram.

sram_interface.v - SRAM interface borrowed from the PLP project.

songdata.v - initializes a block ram for the game notes that appear on the screen.

MusicHero.v - main file that ties it all together, and handles all of the drawing code.

The music itself is put into the board's SRAM as a file using Digilent Adept.

The block ram notes match a cut version of Paramore's "Misery Business": the exact format of which is a 16 bit, mono PCM file exported as raw data.

