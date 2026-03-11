module blinker_lut (
    input  wire [3:0] step,
    input  wire [2:0] preset_sel,
    output wire       led_out
);
  reg [15:0] current_pattern;

  always_comb begin
    case (preset_sel)
      //                      16-bit Pattern (read left to right over 800ms)
      3'd0: current_pattern = 16'b0000_0000_0000_0000;  // OFF
      3'd1: current_pattern = 16'b1111_1111_1111_1111;  // ON
      3'd2: current_pattern = 16'b1111_1111_0000_0000;  // SLOW BLINK
      3'd3: current_pattern = 16'b1100_1100_1100_1100;  // FAST BLINK
      3'd4: current_pattern = 16'b1010_1010_1010_1010;  // STROBE (Error)
      3'd5: current_pattern = 16'b1110_0000_1110_0000;  // HEARTBEAT
      3'd6: current_pattern = 16'b1000_1000_1000_1000;  // HIGHLIGHT
      3'd7: current_pattern = 16'b1101_1011_0111_1101;  // WINNER SPARKLE
      default: current_pattern = 16'h0000;
    endcase
  end

  assign led_out = current_pattern[15-step];
endmodule
