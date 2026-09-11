// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
module de1soc_top (
    input  wire        CLOCK_50,

    // Red LEDs
    output wire [9:0]  LEDR,

    // 7-segment displays (active-low)
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX4,
    output wire [6:0]  HEX5,

    // Push buttons (active-low)
    input  wire [3:0]  KEY,

    // Slide switches
    input  wire [9:0]  SW
);

// 25-bit counter for ~0.67 Hz blink on 50 MHz clock
reg [24:0] counter;
always @(posedge CLOCK_50)
    counter <= counter + 1'b1;

wire blink = counter[24];

// LEDs: blink upper half, show switch state on lower half
assign LEDR[9:5] = {5{blink}};
assign LEDR[4:0] = SW[4:0];

// 7-segment digit encoder (active-low segments)
function [6:0] seg7;
    input [3:0] d;
    case (d)
        4'h0: seg7 = 7'b1000000;
        4'h1: seg7 = 7'b1111001;
        4'h2: seg7 = 7'b0100100;
        4'h3: seg7 = 7'b0110000;
        4'h4: seg7 = 7'b0011001;
        4'h5: seg7 = 7'b0010010;
        4'h6: seg7 = 7'b0000010;
        4'h7: seg7 = 7'b1111000;
        4'h8: seg7 = 7'b0000000;
        4'h9: seg7 = 7'b0010000;
        4'ha: seg7 = 7'b0001000;
        4'hb: seg7 = 7'b0000011;
        4'hc: seg7 = 7'b1000110;
        4'hd: seg7 = 7'b0100001;
        4'he: seg7 = 7'b0000110;
        4'hf: seg7 = 7'b0001110;
    endcase
endfunction

// Show counter upper nibbles across the six displays
assign HEX0 = seg7(counter[24:21]);
assign HEX1 = seg7(counter[20:17]);
assign HEX2 = seg7(counter[16:13]);
assign HEX3 = seg7(counter[12:9]);
assign HEX4 = seg7(counter[8:5]);
assign HEX5 = seg7(counter[4:1]);

endmodule
