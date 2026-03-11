/*
 * Copyright (c) 2024 tschai-yim
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tschai_yim_mill (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
  // --- Pinout Mapping ---
  // Buttons:
  // Button 0-7 -> ui_in[7:0]
  // Button 8   -> uio_in[0]
  //
  // Display LEDs:
  // LED 0-7    -> uo_out[7:0]
  // LED 8      -> uio_out[7]

  wire [8:0] buttons_raw;
  wire [8:0] display_out;

  // --- I/O ---
  assign buttons_raw = {uio_in[0], ui_in[7:0]};
  assign uo_out[7:0] = display_out[7:0];
  // uio[0] is an input (button 8)
  // uio[7] is an output (LED 8)
  // All others are unused, so set to input to be safe.
  assign uio_oe = 8'b10000000;
  assign uio_out[7] = display_out[8];
  // Tie off unused mixed-use outputs to 0
  assign uio_out[6:0] = 7'b0;

  // --- Tic-Tac-Toe ---
  tictactoe #(
`ifdef SIM
      .CLK_FREQ(1000)
`else
      .CLK_FREQ(50_000_000)
`endif
  ) ttt_core (
      .buttons_raw(buttons_raw),
      .display(display_out),
      .clk(clk),
      .rst_n(rst_n)
  );
endmodule
