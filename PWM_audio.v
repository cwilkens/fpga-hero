`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:39:22 11/20/2011 
// Design Name: 
// Module Name:    PWM_audio 
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
module PWM_audio(clk_in, play, PWM_in, audio_out);

input play;
input clk_in;
input [15:0] PWM_in;
output reg audio_out;

// PWM module to take in PWM data and play it out on a one line speaker
// mainly taken from:
// http://www.fpga4fun.com/PWM_DAC.html

// sigma delta PWM
reg [16:0] PWM_accumulator;

always @(posedge clk_in) begin
	PWM_accumulator[16:0] = PWM_accumulator[15:0] + PWM_in; // plus sigma
	audio_out = PWM_accumulator[16] && play;
	PWM_accumulator[16] = 0;		// delta : subtract 256
end




endmodule



