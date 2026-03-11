module blinker_timer #(
    parameter CLK_FREQ = 10_000_000,
    parameter STEP_MS  = 50
) (
    input  wire clk,
    input  wire rst_n,
    output wire [3:0] step // The current step in the sequence (0-15)
);

  localparam CYCLES_PER_STEP = (CLK_FREQ / 1000) * STEP_MS;
  localparam BITS = $clog2(CYCLES_PER_STEP);

  reg [BITS-1:0] tick_counter_q;
  reg [3:0]      step_q;

  assign step = step_q;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      tick_counter_q <= '0;
      step_q <= '0;
    end else begin
      if (tick_counter_q >= BITS'(CYCLES_PER_STEP - 1)) begin
        tick_counter_q <= '0;
        step_q <= step_q + 1;
      end else begin
        tick_counter_q <= tick_counter_q + 1;
      end
    end
  end
endmodule