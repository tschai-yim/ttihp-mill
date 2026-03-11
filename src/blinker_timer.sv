module blinker_timer #(
    parameter TICK_HZ = 1000,
    parameter STEP_MS = 50
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_en, // From shared prescaler
    output wire [3:0] step     // The current step in the sequence (0-15)
);

  localparam STEP_TICKS = (STEP_MS * TICK_HZ) / 1000;
  localparam BITS = $clog2(STEP_TICKS);

  reg [BITS-1:0] tick_counter_q;
  reg [3:0]      step_q;

  assign step = step_q;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      tick_counter_q <= '0;
      step_q <= '0;
    end else if (tick_en) begin
      if (tick_counter_q >= BITS'(STEP_TICKS - 1)) begin
        tick_counter_q <= '0;
        step_q <= step_q + 1'b1;
      end else begin
        tick_counter_q <= tick_counter_q + 1'b1;
      end
    end
  end
endmodule
