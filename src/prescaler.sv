module prescaler #(
    parameter CLK_FREQ = 10_000_000,
    parameter TICK_HZ  = 1000
) (
    input  wire clk,
    input  wire rst_n,
    output wire tick_en
);

  localparam TICK_LIMIT = CLK_FREQ / TICK_HZ;
  // Ensure WIDTH is at least 1 to avoid Icarus Verilog errors when TICK_LIMIT is 1
  localparam WIDTH = ($clog2(TICK_LIMIT) > 0) ? $clog2(TICK_LIMIT) : 1;

  reg [WIDTH-1:0] counter_q;

  assign tick_en = (TICK_LIMIT <= 1) ? 1'b1 : (counter_q == WIDTH'(TICK_LIMIT - 1));

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      counter_q <= '0;
    end else begin
      if (tick_en) begin
        counter_q <= '0;
      end else begin
        counter_q <= counter_q + 1'b1;
      end
    end
  end

endmodule
