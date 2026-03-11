module debouncer #(
    parameter NUM_BUTTONS    = 9,
    parameter TICK_HZ        = 1000,
    parameter SAMPLE_RATE_MS = 5,     // Sample every 5ms
    parameter HISTORY_SIZE   = 4
) (
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   tick_en,
    input  wire [NUM_BUTTONS-1:0] btn_in,   // The raw, bouncy inputs
    output reg  [NUM_BUTTONS-1:0] btn_out   // The clean outputs
);

  localparam TICK_TICKS = (SAMPLE_RATE_MS * TICK_HZ) / 1000;
  localparam BITS = $clog2(TICK_TICKS);

  reg [BITS-1:0] tick_counter;
  // An array of shift registers to hold button history
  reg [HISTORY_SIZE-1:0] history[0:NUM_BUTTONS-1];

  integer i;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      tick_counter <= 0;
      btn_out <= 0;
      for (i = 0; i < NUM_BUTTONS; i = i + 1) begin
        history[i] <= 'b0;
      end
    end else if (tick_en) begin
      if (tick_counter >= BITS'(TICK_TICKS - 1)) begin
        tick_counter <= 0;

        for (i = 0; i < NUM_BUTTONS; i = i + 1) begin
          // Shift the old history left, and bring in the new raw button state
          logic [HISTORY_SIZE-1:0] next_history;
          next_history = {history[i][HISTORY_SIZE-2:0], btn_in[i]};
          history[i] <= next_history;

          // If the button has been HIGH for entire history
          if (next_history == {(HISTORY_SIZE) {1'b1}}) btn_out[i] <= 1'b1;  // Definitely Pressed
          // If the button has been LOW for entire history
          else if (next_history == '0) btn_out[i] <= 1'b0;  // Definitely Released
        end
      end else begin
        tick_counter <= tick_counter + 1;
      end
    end
  end

endmodule
