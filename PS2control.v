`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:27:31 11/27/2011 
// Design Name: 
// Module Name:    PS2control 
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
module PS2control(clk, data, outclk, command, attention, keys);

// this module needs a 500 kHz signal coming in on clk.
input clk;
input data;
output outclk;
output command;
output attention;
output [7:0] keys;
reg outclk;
reg command;
reg attention;
reg [7:0] keys;

reg [3:0] packetstate;
reg [3:0] gotostate;
reg [3:0] bytecounter;
reg [3:0] bitcounter;
reg [10:0] waitcounter;

// values for command shift register
reg [7:0] commandshift;

//output [7:0] datashift;
reg [7:0] datashift; // data shift register

initial begin
	packetstate = 4'b1111;
	gotostate   = 4'b0001;
	bytecounter = 5'b00000; // starts at 0, every packet state adds one first, so counting starts at 1.
	bitcounter =  4'b0000;
	waitcounter = 0;
end

always @ (posedge outclk) begin
	datashift = {data, datashift[7:1]};
end

always @ (posedge clk) begin
	// main state machine
	case (packetstate)
	
		4'b1111: begin // wait state between polling the controller 100 cycles or so, (50 cycles of 250kHz)
			//
			waitcounter = waitcounter + 1;
			if (waitcounter < 2000) begin
				attention = 1; // attention line is high, ain't doin' nothin.
				command = 1;  // cause we can.
				bitcounter = 0;
			end else begin
				waitcounter = 0;
				packetstate = gotostate;
				attention = 0;
			end
		end
		
		4'b1110: begin // pause for a couple cycles
			bitcounter = bitcounter + 1;
			if (bitcounter > 13) begin
				bitcounter = 0;
				packetstate = gotostate; // go to next byte in packet, or next packet
			end
		end
		
		4'b0000: begin // main state, driving lines to get data one byte at a time
			//
			outclk = ~outclk; // drive outclk at 250 kHz
			command = commandshift[bitcounter];
			bitcounter = bitcounter + outclk;
			if (bitcounter == 8) begin
				packetstate = 4'b1110; // go to pause between bytes
				bitcounter = 0;
			end
		end
		
		4'b0001: begin // this state is a whole packet. moves back and forth between main state and pause state to send bytes.
			bytecounter = bytecounter + 1; // first packet: set controller into config mode
			packetstate = 4'b0000; // send the byte, if not overridden
			case (bytecounter)
				5'b00001: commandshift = 8'h01; // before 1st byte
				5'b00010: commandshift = 8'h43; // 2
				5'b00011: commandshift = 8'h00; // 3
				5'b00100: commandshift = 8'h01; // 4
				5'b00101: commandshift = 8'h00; // 5
				5'b00110: begin
					packetstate = 4'b1111;
					gotostate   = 4'b0010; // go to next packet
					bytecounter = 5'b00000;
				end
			endcase
			//
		end
		
		4'b0010: begin
			bytecounter = bytecounter + 1; // second packet: set controller to analog mode (after entering config mode)
			gotostate = 4'b0010;
			packetstate = 4'b0000; // send the byte, if not overridden
			case (bytecounter)
				5'b00001: commandshift = 8'h01; // before 1st byte
				5'b00010: commandshift = 8'h44; // 2
				5'b00011: commandshift = 8'h00; // 3
				5'b00100: commandshift = 8'h01; // 4
				5'b00101: commandshift = 8'h03; // 5
				5'b00110: commandshift = 8'h00; // 6
				5'b00111: commandshift = 8'h00; // 7
				5'b01000: commandshift = 8'h00; // 8
				5'b01001: commandshift = 8'h00; // 9
				5'b01010: begin // done
					packetstate = 4'b1111;
					gotostate   = 4'b0011;
					bytecounter = 5'b00000;
				end
			endcase
			//
		end
		
		4'b0011: begin
			bytecounter = bytecounter + 1; // third packet: exit config mode
			gotostate = 4'b0011;
			packetstate = 4'b0000; // send the byte, if not overridden
			case (bytecounter)
				5'b00001: commandshift = 8'h01; // before 1st byte
				5'b00010: commandshift = 8'h43; // 2
				5'b00011: commandshift = 8'h00; // 3
				5'b00100: commandshift = 8'h00; // 4
				5'b00101: commandshift = 8'h5A; // 5
				5'b00110: commandshift = 8'h5A; // 6
				5'b00111: commandshift = 8'h5A; // 7
				5'b01000: commandshift = 8'h5A; // 8
				5'b01001: commandshift = 8'h5A; // 9
				5'b01010: begin // done
					packetstate = 4'b1111;
					gotostate   = 4'b0100;
					bytecounter = 5'b00000;
				end
			endcase
			//
		end
		
		4'b0100: begin
			bytecounter = bytecounter + 1; // fourth packet: standard poll for keys
			packetstate = 4'b0000; // send the byte, if not overridden
			gotostate = 4'b0100;
			case (bytecounter)
				5'b00001: commandshift = 8'h01; // before 1st byte
				5'b00010: commandshift = 8'h42; // 2
				5'b00011: commandshift = 8'h00; // 3
				5'b00100: commandshift = 8'h00; // 4
				5'b00101: begin
					commandshift = 8'h00; // 5
					// now handle data from 4th byte (digital buttons)
					keys[0] = ~datashift[0];						// select
					keys[1] = ~datashift[3];						// start
					keys[2] = ~datashift[4] | ~datashift[6];	// up or down
				end
				5'b00110: begin
					commandshift = 8'h00; // 6
					// data from 5th byte (digital buttons)
					keys[3] = ~datashift[7];						// orange
					keys[4] = ~datashift[6];						// blue
					keys[5] = ~datashift[4];						// yellow
					keys[6] = ~datashift[5];						// red
					keys[7] = ~datashift[1];						// green
				end
				5'b00111: begin
					commandshift = 8'h00; // 7
					// data from 6th byte (analog RX) centers to 0x7F
				end					
				5'b01000: begin
					commandshift = 8'h00; // 8
					// data from 7th byte (analog RY) centers to 0x7F
				end
				5'b01001: begin
					commandshift = 8'h00; // 9
					// data from 8th byte (analog LX) centers to 0x7F
				end
				5'b01010: begin // done
					// data from 9th byte (analog LY) centers to 0x7F
					packetstate = 4'b1111;
					gotostate   = 4'b0100;
					bytecounter = 5'b00000;
				end					
			endcase
			//
		end
		
		// more packetstates can go here
		
	endcase
	
end


endmodule