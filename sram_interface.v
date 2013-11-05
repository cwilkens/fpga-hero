`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
/*
    Copyright 2010, 2011 David Fritz, Brian Gordon, Wira Mulia

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

 */


/* 
David Fritz

SRAM interface

31.12.2010
*/
// 
// Taken from PLP verilog source.
//////////////////////////////////////////////////////////////////////////////////
module sram_interface(rst, clk, addr, dout, rdy, sram_clk, sram_adv, sram_cre, sram_ce, sram_oe, sram_we, sram_lb, sram_ub, sram_data, sram_addr);

input clk, rst;
input [23:0] addr;
//input drw;
//input [31:0] din;
output reg [15:0] dout;
output rdy;
output sram_clk, sram_adv, sram_cre, sram_ce, sram_oe, sram_lb, sram_ub;
output [23:1] sram_addr;
output sram_we;
inout [15:0] sram_data;

/* some sram signals are static */
assign sram_clk = 0;
assign sram_adv = 0;
assign sram_cre = 0;
assign sram_ce  = 0;
assign sram_oe  = 0; /* sram_we overrides this signal */
assign sram_ub  = 0;
assign sram_lb  = 0;

reg [2:0] state = 3'b000;

assign sram_data = 16'hzzzz;
assign sram_addr = {addr[23:1],1'b0};
assign sram_we   = 1; // never write
assign rdy = (state == 3'b000);

always @(posedge clk) begin
	if (!rst) begin
		if (state == 3'b010) dout <= sram_data;
		//if (state == 3'b100) dout[15:0]  <= sram_data;
		if (state == 3'b010)
			state <= 3'b000;
		else
			state <= state + 1;
	end else begin
		state <= 3'b000;
	end
end

endmodule

