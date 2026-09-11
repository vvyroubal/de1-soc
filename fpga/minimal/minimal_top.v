// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
// Minimal top-level module - smallest possible real logic (single register).
// Purpose: smallest possible bitstream to minimize Active-Serial
// configuration time from flash, to test whether Boot ROM's FPGA-config
// timing race is sensitive to bitstream size/complexity.
module minimal_top(input clk, output reg q);
    always @(posedge clk)
        q <= ~q;
endmodule
