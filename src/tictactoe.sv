module tictactoe #(
    parameter CLK_FREQ = 10_000_000
) (
    input  wire [8:0] buttons_raw,
    output wire [8:0] display,
    input  wire       clk,
    input  wire       rst_n
);

  // --- Constants and State Definitions ---
  localparam IDLE = 2'b00, P1_TURN = 2'b01, P2_TURN = 2'b10, GAME_OVER = 2'b11;
  reg [1:0] state_q;

  // --- Win Condition Masks (Hardcoded for 3x3) ---
  localparam [71:0] WIN_MASKS = {
      9'b001010100,  // Diag 2
      9'b100010001,  // Diag 1
      9'b100100100,  // Col 2
      9'b010010010,  // Col 1
      9'b001001001,  // Col 0
      9'b111000000,  // Row 2
      9'b000111000,  // Row 1
      9'b000000111   // Row 0
  };

  // --- Board and Game State Registers ---
  reg [8:0] board_p1_q, board_p2_q;
  reg  [8:0] win_mask_q;
  reg        is_draw_q;

  // --- Button Handling ---
  wire       move_valid;
  wire [3:0] move_idx;

  button_handler #(
      .NUM_BUTTONS(9),
      .CLK_FREQ(CLK_FREQ)
  ) btn_handler (
      .clk(clk),
      .rst_n(rst_n),
      .buttons_raw(buttons_raw),
      .move_valid(move_valid),
      .move_idx(move_idx)
  );

  // --- Animation and UI Timers ---
  localparam ONE_SECOND_CYCLES = CLK_FREQ;
  localparam ANIM_BITS = $clog2(ONE_SECOND_CYCLES);
  reg [ANIM_BITS-1:0] anim_timer_q;
  reg [          3:0] anim_target_idx_q;
  reg                 anim_is_error_q;

  // --- Next Board State Calculation Logic ---
  wire p1_wins, p2_wins, is_full;
  logic [8:0] p1_win_mask_w, p2_win_mask_w;
  logic [8:0] next_board_p1, next_board_p2;

  always_comb begin
    // Determine the next board states based on the current valid move 
    next_board_p1 = board_p1_q;
    next_board_p2 = board_p2_q;

    if (move_valid) begin
      if (state_q == IDLE) begin
        next_board_p1 = 9'b1 << move_idx;
      end else if (state_q == P1_TURN && ((board_p1_q[move_idx] | board_p2_q[move_idx]) == 1'b0)) begin
        next_board_p1 = board_p1_q | (9'b1 << move_idx);
      end else if (state_q == P2_TURN && ((board_p1_q[move_idx] | board_p2_q[move_idx]) == 1'b0)) begin
        next_board_p2 = board_p2_q | (9'b1 << move_idx);
      end
    end

    // Check all 8 win conditions for each player in parallel using lookahead state
    p1_win_mask_w = '0;
    p2_win_mask_w = '0;
    for (int i = 0; i < 8; i++) begin
      if ((next_board_p1 & WIN_MASKS[i*9 +: 9]) == WIN_MASKS[i*9 +: 9]) p1_win_mask_w = WIN_MASKS[i*9 +: 9];
      if ((next_board_p2 & WIN_MASKS[i*9 +: 9]) == WIN_MASKS[i*9 +: 9]) p2_win_mask_w = WIN_MASKS[i*9 +: 9];
    end
  end

  assign p1_wins = |(p1_win_mask_w);
  assign p2_wins = |(p2_win_mask_w);
  assign is_full = &(next_board_p1 | next_board_p2);  // AND-reduction: are all bits 1?

  // --- Main Game State Machine ---
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state_q <= IDLE;
      board_p1_q <= '0;
      board_p2_q <= '0;
      win_mask_q <= '0;
      is_draw_q <= 1'b0;
      anim_timer_q <= '0;
    end else begin
      // Decrement animation timer automatically
      if (anim_timer_q > 0) begin
        anim_timer_q <= anim_timer_q - 1;
      end

      case (state_q)
        IDLE: begin
          if (move_valid) begin
            board_p1_q <= next_board_p1;
            anim_timer_q <= CLK_FREQ;
            anim_target_idx_q <= move_idx;
            anim_is_error_q <= 1'b0;
            state_q <= P2_TURN;
          end
        end

        P1_TURN: begin
          if (move_valid) begin
            // Check if cell is empty
            if ((board_p1_q[move_idx] | board_p2_q[move_idx]) == 1'b0) begin
              board_p1_q <= next_board_p1;
              anim_timer_q <= ONE_SECOND_CYCLES;
              anim_target_idx_q <= move_idx;
              anim_is_error_q <= 1'b0;

              if (p1_wins) begin
                state_q <= GAME_OVER;
                win_mask_q <= p1_win_mask_w;
              end else if (is_full) begin
                state_q   <= GAME_OVER;
                is_draw_q <= 1'b1;
              end else begin
                state_q <= P2_TURN;
              end
            end else begin  // Cell occupied, trigger error
              anim_timer_q <= ONE_SECOND_CYCLES;
              anim_target_idx_q <= move_idx;
              anim_is_error_q <= 1'b1;
            end
          end
        end

        P2_TURN: begin
          if (move_valid) begin
            if ((board_p1_q[move_idx] | board_p2_q[move_idx]) == 1'b0) begin
              board_p2_q <= next_board_p2;
              anim_timer_q <= ONE_SECOND_CYCLES;
              anim_target_idx_q <= move_idx;
              anim_is_error_q <= 1'b0;

              if (p2_wins) begin
                state_q <= GAME_OVER;
                win_mask_q <= p2_win_mask_w;
              end else if (is_full) begin
                state_q   <= GAME_OVER;
                is_draw_q <= 1'b1;
              end else begin
                state_q <= P1_TURN;
              end
            end else begin
              anim_timer_q <= ONE_SECOND_CYCLES;
              anim_target_idx_q <= move_idx;
              anim_is_error_q <= 1'b1;
            end
          end
        end

        GAME_OVER: begin
          if (move_valid) begin
            // Any button press resets the game
            state_q <= IDLE;
            board_p1_q <= '0;
            board_p2_q <= '0;
            win_mask_q <= '0;
            is_draw_q <= 1'b0;
          end
        end
      endcase
    end
  end

  // --- Display Rendering Logic ---
  wire [3:0] master_step;
  reg  [2:0] preset_sel  [0:8];

  blinker_timer #(
      .CLK_FREQ(CLK_FREQ)
  ) shared_timer (
      .clk  (clk),
      .rst_n(rst_n),
      .step (master_step)
  );

  always_comb begin
    for (int i = 0; i < 9; i++) begin
      // Default to off
      preset_sel[i] = 3'd0;

      // Highest priority: Non-blocking animations
      if (anim_timer_q > 0 && 4'(i) == anim_target_idx_q) begin
        preset_sel[i] = anim_is_error_q ? 3'd4 : 3'd6;  // Strobe or Highlight
      end else begin
        // Second priority: Game state rendering
        case (state_q)
          IDLE: begin
            // Rotating "dot" animation
            if (3'(i) == master_step[2:0]) preset_sel[i] = 3'd1;
          end
          GAME_OVER: begin
            if (win_mask_q[i]) begin  // Winning line blinks fast
              preset_sel[i] = 3'd3;
            end else if (board_p1_q[i]) begin  // P1 pieces are solid
              preset_sel[i] = 3'd1;
            end else if (board_p2_q[i]) begin  // P2 pieces slow blink
              if (is_draw_q) preset_sel[i] = 3'd7;  // On a draw, P2 LEDs sparkle
              else preset_sel[i] = 3'd2;
            end
          end
          default: begin  // P1_TURN or P2_TURN
            if (board_p1_q[i]) preset_sel[i] = 3'd1;  // P1 is solid
            else if (board_p2_q[i]) preset_sel[i] = 3'd2;  // P2 slow blinks
          end
        endcase
      end
    end
  end

  // Generate 9 blinker LUTs and connect them to the display output
  genvar k;
  generate
    for (k = 0; k < 9; k = k + 1) begin : blinker_gen
      blinker_lut lut_inst (
          .step(master_step),
          .preset_sel(preset_sel[k]),
          .led_out(display[k])
      );
    end
  endgenerate

endmodule
