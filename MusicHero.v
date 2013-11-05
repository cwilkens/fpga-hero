`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:45:18 10/10/2011 
// Design Name: 
// Module Name:    Lab8
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

//MAKE SURE YOU ADD vga_controller_640_60.vhd to your design
//LIKE SERIOUSLY, YOU HAVE TO OR IT WON'T WORK
//MAKE SURE Lab8.v AND vga_controller_640_60.vhd ARE ON THE SAME FOLDER


module MusicHero(clk, hs, vs, rgb, LEDout, audio_output,
					  PSdata1, PSclk1, PScommand1, PSattention1, PSkeys1, 
					  PSdata2, PSclk2, PScommand2, PSattention2, PSkeys2, 
					  ram_address, ram_data, indata, memrdy, ram_clk, ram_adv, ram_cre, ram_ce, ram_oe, ram_we, ram_lb, ram_ub);

input clk;
output hs;  //don't use reg here because you are passing an output of a module
output vs;  //don't use reg here because you are passing an output of a module
output [7:0] rgb;
input PSdata1;
output PSclk1;
output PScommand1;
output PSattention1;
output [7:0] PSkeys1;
input PSdata2;
output PSclk2;
output PScommand2;
output PSattention2;
output [7:0] PSkeys2;
// PSkeys[7]	 green
// PSkeys[6]	 red
// PSkeys[5]	 yellow
// PSkeys[4]	 blue
// PSkeys[3]	 orange
// PSkeys[2]	 up or down (strum)
// PSkeys[1]	 start
//	PSkeys[0]	 select
output [7:0] LEDout;
output audio_output;

output [23:1] ram_address;
reg    [23:0] address;
inout  [15:0] ram_data;
output [15:0] indata;
output memrdy;
output ram_clk;
output ram_adv;
output ram_cre;
output ram_ce;
output ram_oe;
output ram_we;
output ram_lb;
output ram_ub;

reg [7:0] LEDout;
reg [7:0] rgb;

// music data
parameter bpm = 346; // 173*2 = 346
parameter vpb = 64; // pixels (vlines) per beat, ignoring angle of fretboard MUST BE POWER OF 2! (because I suck at designing algorithms without division)
parameter fretstart = 60;		// vertical count from top of screen of start of fretboard
parameter hitlength = 360; 	// length of fretboard in pixels to hitbar
parameter fretlength = 420;	// total length of fretboard in pixels
// note information
wire [9:0] notedata;	// used for drawing
reg [9:0] hitdata;	// used for checking controller
reg [12:0] targetnote; // current note pulling from bram

// module to hold note data
songdata bram(.clk(clk), .addr(targetnote), .data(notedata));

reg [1:0] hitnote1;	// temp value if note was hit, [0] is just hit, [1] is one beat in the past
reg [1:0] hitnote2;	// bass
reg [4:0] streak1;	// exactly what you think it is
reg [4:0] streak2;
reg [12:0] points1; // oh yeah!
reg [12:0] points2;
reg shownote1;      // used to calculate if we're showing the note based on hitnote
reg shownote2;

// values for calculating notes on vga
reg [31:0] count;     // 18 bits for counting cycles (max 250,000) (currently 32 cause might change)
reg [8:0] pixelcount; // 9 bits for vertical pixel number (0-439)
reg [15:0] beatcount; // current beat count in song

reg [3:0] ncount;  // note height
reg [8:0] ncounter; 
reg [7:0] fcount;  // fret offset
reg [8:0] fcounter;
reg [10:0] fline;  // vertical pixel value (vcount) of next fret line
reg [15:0] bcount;  // beat count for rendering to screen

// game stuff
reg [2:0] dselect;
reg [2:0] dstart;
reg [2:0] dstrum1;
reg [2:0] dstrum2;
wire select_press = (dselect[2:1] == 2'b01);
wire start_press	= (dstart[2:1] == 2'b01); // used for a "just pressed" value
wire strum1			= (dstrum1[2:1] == 2'b01);
wire strum2			= (dstrum2[2:1] == 2'b01);
reg started; // started music?

// vga module stuff, don't break
reg clk_half;
wire blank;
wire [10:0] hcount, vcount;

//We have to use vga_controller_640_60 as a our submodule
vga_controller_640_60 vga(.rst(1'b0), .pixel_clk(clk_half), .HS(hs), .VS(vs), .hcount(hcount), .vcount(vcount), .blank(blank));

reg [10:0] guitarcounter;
reg guitarclock;

// modules to communicate with both guitars
PS2control guitar1(.clk(guitarclock), .keys(PSkeys1), .outclk(PSclk1), .command(PScommand1), .attention(PSattention1), .data(PSdata1));
PS2control guitar2(.clk(guitarclock), .keys(PSkeys2), .outclk(PSclk2), .command(PScommand2), .attention(PSattention2), .data(PSdata2));


// sound stuff
// 50 Mhz clock / 16000 hz sound = 3125
// 50 MHz / 32   kHz sound = 1562.5
// 50 MHz / 44.1 kHz sound = 1133.786
parameter pwmfull = 1563;
reg [11:0] pwmcount;
reg [15:0] pwm_input;

// module that handles output of audio
PWM_audio PWM_audio_module(.clk_in(clk), .play(started), .PWM_in(pwm_input), .audio_out(audio_output));

// memory wizards
reg readmem;

// module that reads in ram
sram_interface RAM_module(.rst(1'b0), .clk(clk_half), .addr(address), .dout(indata), .rdy(memrdy), 
								  .sram_clk(ram_clk), .sram_adv(ram_adv), .sram_cre(ram_cre), .sram_ce(ram_ce), .sram_oe(ram_oe), .sram_we(ram_we), 
								  .sram_lb(ram_lb), .sram_ub(ram_ub), .sram_data(ram_data), .sram_addr(ram_address));


initial begin
	clk_half = 0;
	beatcount = 0; //
	pixelcount = vpb/2; // to adjust timing
	bcount = 0;
	count = 0;
	started = 0;
	
	address = 0;
	readmem = 0;
	
	// audio
	pwmcount = 0;
	pwm_input = 0;
	
	// game stuff
	hitnote1 = 0;
	hitnote2 = 0;
	streak1 = 5'b00000;
	streak2 = 5'b00000;
	points1 = 0;
	points2 = 0;
	
	// music data (from bram)
	targetnote = 0;
	hitdata = 0;

end

//YOUR MONITOR RUNS ON 25 MHz FREQUENCY

always @(posedge clk) begin
	clk_half = ~clk_half;
	// THIS IS 50 MHz
	
	// audio stuff
	if (pwmcount == 1 && started) begin
		readmem = 1;
		address = address + 1'b1; 
	end 
	// three cycles after telling mem_module to read (80 ns)
	if (pwmcount > 1 && pwmcount < 11 && memrdy && readmem) begin
		// read in
		readmem = 0;
		pwm_input[15:0] = indata[15:0];
		// convert to unsigned
		if (pwm_input[15]) begin
			pwm_input = ~pwm_input;
			pwm_input = pwm_input + 1'b1;
			pwm_input = 16'b1000000000000000 - pwm_input;
		end else begin
			pwm_input = pwm_input + 16'b1000000000000000;
		end
	end
	
	pwmcount = pwmcount + started;

	if (pwmcount > pwmfull)
		pwmcount = 0;
		
	// reset (for stuff in this always@ block)
	if (select_press) begin // reset song
		address = 0;
		readmem = 0;
		pwmcount = 0;
		pwm_input = 0;
	end
	
end


always @(posedge clk_half) begin
	// THIS IS 25 MHz
	
	// check for end of song
	if (beatcount == 1150) begin // couple measures after end
		started = 0;
	end
	
	// deal with timing for PS2 submodule. solid 500 kHz signal.
	guitarcounter = guitarcounter + 1;
	if (guitarcounter == 25) begin
		guitarcounter = 0;
		guitarclock = ~guitarclock;
	end
	
	// debug info
	LEDout[7:5] = beatcount[2:0];
	LEDout[4:0] = notedata[4:0];
	
	// check key stuff
	dstrum1[2:0] = {dstrum1[1:0], PSkeys1[2]};
	dstrum2[2:0] = {dstrum2[1:0], PSkeys2[2]};
	dstart[2:0] = {dstart[1:0], PSkeys1[1]};
	dselect[2:0] = {dselect[1:0], PSkeys1[0]};
	if (start_press && beatcount < 1136)			// if start button has been pressed (downstroke) and not end of song
		started = ~started;	// start song
	if (select_press) begin // reset song
		beatcount = 0;
		pixelcount = vpb/2;
		bcount = 0;
		count = 0;
		started = 0;
		hitnote1 = 0;
		hitnote2 = 0;
		streak1 = 5'b0000;
		streak2 = 5'b0000;
		points1 = 0;
		points2 = 0;
		targetnote = 0;
		hitdata = 0;
	end
	
	// update movement
	// count is current cycle to next vline
	count = count + started;
	if (count == 25000000*60/bpm/vpb) begin  // cycles per vline of movement
		// increment pixel count, check beat count
		count = 0;
		pixelcount = pixelcount + 1; // move stuff down
		//fdelta = fdelta + 1; // fret adjustment, see video counters below
		if (pixelcount == vpb) begin
			hitnote1[1] = hitnote1[0]; // move hit beats down (hiding notes that were hit)
			hitnote1[0] = 0; // next note, haven't hit it yet
			hitnote2[1] = hitnote2[0]; // bass
			hitnote2[0] = 0;
			pixelcount = 0;
			beatcount = beatcount + 1;
		end
	end
	
	// check for hitting a note
	// third note down on fretboard is 384 pixels. hitbar: 405 to 435
	// aiming for middle of note (pixelcount) to be in hitbar: 405 < 384 + x < 435
	if (started && hitdata[4:0] != 5'b00000) begin // if the song is playing
		if (pixelcount >= 8 && pixelcount <= 56 && !hitnote1[0]) begin // if we're in range and haven't hit it yet
			// on a beat
			if (PSkeys1[7:3] == hitdata[4:0] && strum1) begin // keys match, and we strum
				hitnote1[0] = 1; // hitnote is reset in pixelcount
				if (streak1 < 15)
					streak1 = streak1 + 1;
				// add point stuff here
				if (streak1 == 15)
					points1 = points1 + 4;
				else if (streak1 >= 10)
					points1 = points1 + 3;
				else if (streak1 >= 5)
					points1 = points1 + 2;
				else
					points1 = points1 + 1;
			end else	if (pixelcount == 56) begin
				// strummed on beat, but wrong note (or already hit)
				streak1 = 0;
			end
		end
	end else if (started) begin // on a blank note
		if (strum1)
			streak1 = 0;	// strummed, so missed
	end
	
	// bass
	if (started && hitdata[9:5] != 5'b00000) begin // if the song is playing
		if (pixelcount >= 8 && pixelcount <= 56 && !hitnote2[0]) begin // if we're in range and haven't hit it yet
			// on a beat
			if (PSkeys2[7:3] == hitdata[9:5] && strum2) begin // keys match, and we strum
				hitnote2[0] = 1; // hitnote is reset in pixelcount
				if (streak2 < 15)
					streak2 = streak2 + 1;
				// add point stuff here
				if (streak2 == 15)
					points2 = points2 + 4;
				else if (streak2 >= 10)
					points2 = points2 + 3;
				else if (streak2 >= 5)
					points2 = points2 + 2;
				else
					points2 = points2 + 1;
			end else	if (pixelcount == 56) begin
				// strummed on beat, but wrong note (or already hit)
				streak2 = 0;
			end
		end
	end else if (started) begin // on a blank note
		if (strum2)
			streak2 = 0;	// strummed, so missed
	end
	
	// ----- counters for video
	// ncount: halfheight of notes on fretboard
	// goes from 5 to 10, for a note size of 10 to 20 pixels.
	// increases down the screen.
	// fcount: distance between frets. moves from half vpb at top to full vpb at the bottom near the hitbar
	// used to properly draw perspective
	// fline: next fretline down the screen to draw
	if (hcount == 0 && vcount == 0) begin // reset counters
		ncounter = 0;
		ncount = 5;
		fcounter = 0;
		bcount = beatcount;
		targetnote = beatcount+7; // when set to = beatcount, first note is on 23
										// first note is 16 in bram, so +7;
		fcount = vpb/2;
		fline = fretstart+pixelcount/2;
	end
	if (hcount == 0 && vcount > fretstart) begin
		ncounter = ncounter + 1;
		if (ncounter == fretlength/5) begin
			ncounter = 0;
			ncount = ncount + 1;
		end
	end
	if (hcount == 0 && vcount > fretstart) begin
		fcounter = fcounter + 1;
		if (fcounter == hitlength/(vpb/2)) begin
			fcounter = 0;
			fcount = fcount + 1;
			if (vcount < fline) // adjust previous estimation
				fline = fline + 1;
		end
	end
	if (vcount > fline + (fcount)/2) begin// if the current vcount is > than half to the next fline, set next fline
		bcount = bcount + 1;
		targetnote = targetnote - 1;
		fline = fline + fcount;
	end
	
	// calculate note stuff
	// targetnote = (480-vcount+pixelcount)/vpb+beatcount; // old equation for constant velocity
	// now counts with vga. targetnote is reset in vga counters
	if (targetnote == beatcount && pixelcount < 7)
		hitdata[9:0] = notedata[9:0];
		
	if (targetnote == beatcount) begin
		shownote1 = ~hitnote1[0];
		shownote2 = ~hitnote2[0];
	end else if (targetnote == beatcount-1) begin
		shownote1 = ~hitnote1[1];
		shownote2 = ~hitnote2[1];
	end else begin
		shownote1 = 1'b1;
		shownote2 = 1'b1;
	end
		
	
	// VIDEO!!!!1!!!111!111one!!eleven!1!1
	case (blank)

		1: begin
			rgb = 0;
		end

		0: begin		
			// draw ALL THE THINGS
			
			// background color
			rgb = 8'b01001001; // gray
			
			// point bar for player 1
			if (-4*(vcount - 180) <= 15*(hcount - 56) && -4*(vcount - 180) > 15*(hcount - 76) && vcount >= 60 && vcount < 375) begin
				// black border
				rgb = 8'b00000000;
				if (-4*(vcount - 180) <= 15*(hcount - 57) && -4*(vcount - 180) > 15*(hcount - 75) && vcount > 60 && vcount < 374) begin
					if (vcount*10 > 3740-points1*2 || points1 > 1670)
						rgb = 8'b00010100; // green point bar
					else
						rgb = 8'b01001001; // grey background
				end
			end
			
			// inside fretboard 1 (to simplify things)
			if (-4*(vcount - 180) <= 15*(hcount - 80) && 4*(vcount - 180) > 15*(hcount - 241) && vcount >= 60) begin
				// fretboard background
				rgb = 8'b01100100; // reddish brown
				
				// fretlines
				if (vcount == fline && bcount[0] == 1)
					rgb = 8'b11011011; // white fretline
				if (vcount == fline && bcount[0] == 0)
					rgb = 8'b01101110; // grey fretline
				
				if (vcount > fline-ncount && vcount < fline+ncount && shownote1) begin // draw notes 
					// green notes column
					if (-4*(vcount - 180) <= 15*(hcount - 84) && -4*(vcount - 180) > 25*(hcount - 109) && notedata[4]) begin
						rgb = 8'b00011100;
					end
					// red notes column
					if (-4*(vcount - 180) <= 25*(hcount - 116) && -4*(vcount - 180) > 75*(hcount - 141) && notedata[3]) begin
						rgb = 8'b11100000;
					end
					// yellow notes column
					if (-4*(vcount - 180) <= 75*(hcount - 148) && 4*(vcount - 180) > 75*(hcount - 173) && notedata[2]) begin
						rgb = 8'b11111100;
					end
					// blue notes column
					if (4*(vcount - 180) <= 75*(hcount - 180) && 4*(vcount - 180) > 25*(hcount - 205) && notedata[1]) begin
						rgb = 8'b00000011;
					end
					// orange notes column
					if (4*(vcount - 180) <= 25*(hcount - 212) && 4*(vcount - 180) > 15*(hcount - 237) && notedata[0]) begin
						rgb = 8'b11101100;
					end
				end
				
				// hitbar lines
				if (vcount >= 435 && vcount <= 436)
					rgb = 8'b11111111; // bottom bar bottom line
				if (vcount >= 405 && vcount <= 406)
					rgb = 8'b11111111; // bottom bar top line
				
				// draw the pressed button things
				if (vcount > 409 && vcount < 432) begin
					// green
					if (-4*(vcount - 180) <= 15*(hcount - 84) && -4*(vcount - 180) > 25*(hcount - 109) && PSkeys1[7])
						rgb = 8'b00011100;
					// red
					if (-4*(vcount - 180) <= 25*(hcount - 116) && -4*(vcount - 180) > 75*(hcount - 141) && PSkeys1[6])
						rgb = 8'b11100000;
					// yellow
					if (-4*(vcount - 180) <= 75*(hcount - 148) && 4*(vcount - 180) > 75*(hcount - 173) && PSkeys1[5])
						rgb = 8'b11111100;
					// blue
					if (4*(vcount - 180) <= 75*(hcount - 180) && 4*(vcount - 180) > 25*(hcount - 205) && PSkeys1[4])
						rgb = 8'b00000011;
					// orange
					if (4*(vcount - 180) <= 25*(hcount - 212) && 4*(vcount - 180) > 15*(hcount - 237) && PSkeys1[3])
						rgb = 8'b11101100;
				end
				
				// draw the fretboard vertical lines
				if (-4*(vcount - 180) <= 15*(hcount - 80)  && -4*(vcount - 180) > 15*(hcount - 81))		rgb = 8'b11111111; //white
				if (-4*(vcount - 180) <= 25*(hcount - 112) && -4*(vcount - 180) > 25*(hcount - 113))	rgb = 8'b11111111;
				if (-4*(vcount - 180) <= 75*(hcount - 144) && -4*(vcount - 180) > 75*(hcount - 145))	rgb = 8'b11111111;
				if (4*(vcount - 180) <= 75*(hcount - 176)  && 4*(vcount - 180) > 75*(hcount - 177))		rgb = 8'b11111111;
				if (4*(vcount - 180) <= 25*(hcount - 208)  && 4*(vcount - 180) > 25*(hcount - 209))		rgb = 8'b11111111;
				if (4*(vcount - 180) <= 15*(hcount - 240)  && 4*(vcount - 180) > 15*(hcount - 241))		rgb = 8'b11111111;

			end // of fretboard 1
			
			// streak meter for fretboard 1
			if (4*(vcount - 180) <= 15*(hcount - 244) && 4*(vcount - 180) > 15*(hcount - 264) && vcount > 253 && vcount < 375) begin
				// stuff
				rgb = 8'b00000000;
				if (4*(vcount - 180) <= 15*(hcount - 245) && 4*(vcount - 180) > 15*(hcount - 263) && vcount > 254 && vcount < 374) begin
					if (streak1 == 15) begin
						rgb = 8'b01100011; // purple
					end else if (streak1 >= 10) begin
						rgb = 8'b01001111; // light blue
					end else if (streak1 >= 5) begin
						rgb = 8'b00111101; // light green
					end else
						rgb = 8'b11111101; // light yellow
					// draw the empty space on the streak
					if (vcount < 375-streak1*8) begin
						rgb = 8'b01001001;
					end
				end
			end
			
			// point bar for player 2			
			if (4*(vcount - 180) <= 15*(hcount - 564) && 4*(vcount - 180) > 15*(hcount - 584) && vcount >= 60 && vcount < 375) begin
				// black border
				rgb = 8'b00000000;
				if (4*(vcount - 180) <= 15*(hcount - 565) && 4*(vcount - 180) > 15*(hcount - 583) && vcount > 60 && vcount < 374) begin
					if (vcount*10 > 3740-points2*2 || points2 > 1670)
						rgb = 8'b00010100; // green point bar
					else
						rgb = 8'b01001001; // grey background
				end
			end
			
			// inside fretboard 2 (to simplify things)
			if (-4*(vcount - 180) <= 15*(hcount - 400) && 4*(vcount - 180) > 15*(hcount - 561) && vcount >= 60) begin
			
				// fretboard background
				rgb = 8'b01100100; // reddish brown
				
				// fretlines
				if (vcount == fline && bcount[0] == 1)
					rgb = 8'b11011011; // white fretline
				if (vcount == fline && bcount[0] == 0)
					rgb = 8'b01101110; // grey fretline
				
				if (vcount > fline-ncount && vcount < fline+ncount && shownote2) begin // draw notes 
					// green notes column
					if (-4*(vcount - 180) <= 15*(hcount - 404) && -4*(vcount - 180) > 25*(hcount - 429) && notedata[9]) begin
						rgb = 8'b00011100;
					end
					// red notes column
					if (-4*(vcount - 180) <= 25*(hcount - 436) && -4*(vcount - 180) > 75*(hcount - 461) && notedata[8]) begin
						rgb = 8'b11100000;
					end
					// yellow notes column
					if (-4*(vcount - 180) <= 75*(hcount - 468) && 4*(vcount - 180) > 75*(hcount - 493) && notedata[7]) begin
						rgb = 8'b11111100;
					end
					// blue notes column
					if (4*(vcount - 180) <= 75*(hcount - 500) && 4*(vcount - 180) > 25*(hcount - 525) && notedata[6]) begin
						rgb = 8'b00000011;
					end
					// orange notes column
					if (4*(vcount - 180) <= 25*(hcount - 532) && 4*(vcount - 180) > 15*(hcount - 557) && notedata[5]) begin
						rgb = 8'b11101100;
					end
				end
				
				// hitbar lines
				if (vcount >= 435 && vcount <= 436)
					rgb = 8'b11111111; // bottom bar bottom line
				if (vcount >= 405 && vcount <= 406)
					rgb = 8'b11111111; // bottom bar top line
				
				// draw the pressed button things
				if (vcount > 409 && vcount < 432) begin
					// green
					if (-4*(vcount - 180) <= 15*(hcount - 404) && -4*(vcount - 180) > 25*(hcount - 429) && PSkeys2[7])
						rgb = 8'b00011100;
					// red
					if (-4*(vcount - 180) <= 25*(hcount - 436) && -4*(vcount - 180) > 75*(hcount - 461) && PSkeys2[6])
						rgb = 8'b11100000;
					// yellow
					if (-4*(vcount - 180) <= 75*(hcount - 468) && 4*(vcount - 180) > 75*(hcount - 493) && PSkeys2[5])
						rgb = 8'b11111100;
					// blue
					if (4*(vcount - 180) <= 75*(hcount - 500) && 4*(vcount - 180) > 25*(hcount - 525) && PSkeys2[4])
						rgb = 8'b00000011;
					// orange
					if (4*(vcount - 180) <= 25*(hcount - 532) && 4*(vcount - 180) > 15*(hcount - 557) && PSkeys2[3])
						rgb = 8'b11101100;
				end
				
				// draw the fretboard vertical lines
				if (-4*(vcount - 180) <= 15*(hcount - 400) && -4*(vcount - 180) > 15*(hcount - 401))	rgb = 8'b11111111; //white
				if (-4*(vcount - 180) <= 25*(hcount - 432) && -4*(vcount - 180) > 25*(hcount - 433))	rgb = 8'b11111111;
				if (-4*(vcount - 180) <= 75*(hcount - 464) && -4*(vcount - 180) > 75*(hcount - 465))	rgb = 8'b11111111;
				if (4*(vcount - 180) <= 75*(hcount - 496) && 4*(vcount - 180) > 75*(hcount - 497))		rgb = 8'b11111111;
				if (4*(vcount - 180) <= 25*(hcount - 528) && 4*(vcount - 180) > 25*(hcount - 529))		rgb = 8'b11111111;
				if (4*(vcount - 180) <= 15*(hcount - 560) && 4*(vcount - 180) > 15*(hcount - 561))		rgb = 8'b11111111;
				
			end // of fretboard 2
			
			// streak meter for fretboard 2
			if (-4*(vcount - 180) <= 15*(hcount - 376) && -4*(vcount - 180) > 15*(hcount - 396) && vcount > 253 && vcount < 375) begin
				// border
				rgb = 8'b00000000;
				if (-4*(vcount - 180) <= 15*(hcount - 377) && -4*(vcount - 180) > 15*(hcount - 395) && vcount > 254 && vcount < 374) begin
					if (streak2 == 15) begin
						rgb = 8'b01100011; // purple
					end else if (streak2 >= 10) begin
						rgb = 8'b01001111; // light blue
					end else if (streak2 >= 5) begin
						rgb = 8'b00111101; // light green
					end else
						rgb = 8'b11111101; // light yellow
					// draw the empty space on the streak
					if (vcount < 375-streak2*8) begin
						rgb = 8'b01001001; // background
					end
				end
			end
			
			// more drawing can go here
			
		end// of draw

	endcase

end // always @


endmodule





