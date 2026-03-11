module button_handler #(
    parameter NUM_BUTTONS = 9,
    parameter CLK_FREQ = 10_000_000
) (
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [NUM_BUTTONS-1:0] buttons_raw,
    output wire                   move_valid,   // Single-cycle pulse when a button is pressed
    output wire [            3:0] move_idx      // Index of the highest-priority button pressed
);

  wire [NUM_BUTTONS-1:0] buttons_debounced;
  reg  [NUM_BUTTONS-1:0] buttons_debounced_d;
  wire [NUM_BUTTONS-1:0] buttons_pressed;

  debouncer #(
      .NUM_BUTTONS(NUM_BUTTONS),
      .CLK_FREQ(CLK_FREQ)
  ) btn_debouncer (
      .clk(clk),
      .rst_n(rst_n),
      .btn_in(buttons_raw),
      .btn_out(buttons_debounced)
  );

  // Edge detector to create a single-cycle pulse
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      buttons_debounced_d <= '0;
    end else begin
      buttons_debounced_d <= buttons_debounced;
    end
  end
  assign buttons_pressed = buttons_debounced & ~buttons_debounced_d;

  // Combinational logic for priority encoding
  assign move_valid = |(buttons_pressed);
  assign move_idx = buttons_pressed[8] ? 8 :
                    buttons_pressed[7] ? 7 :
                    buttons_pressed[6] ? 6 :
                    buttons_pressed[5] ? 5 :
                    buttons_pressed[4] ? 4 :
                    buttons_pressed[3] ? 3 :
                    buttons_pressed[2] ? 2 :
                    buttons_pressed[1] ? 1 :
                    buttons_pressed[0] ? 0 :
                    '0;
endmodule
