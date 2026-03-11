# Tic-Tac-Toe Verification Suite

This directory contains the verification environment for the Tic-Tac-Toe ASIC. It uses [cocotb](https://docs.cocotb.org/en/stable/) to drive the design and verify the outputs.

## Automated Verification
The test suite in `test.py` performs sampling of the LED outputs to verify blinking patterns and game logic across multiple scenarios (Win, Draw, Reset, Illegal Moves).

### How to run the automated tests:
```bash
make
```

## Interactive Simulation
`interactive_sim.py` provides a real-time terminal-based view of the board. It synchronizes the simulation clock with the system clock to allow for real-time interaction with the design.

### How to run the interactive simulation:
```bash
make interactive
```

Output:
```
   TIC-TAC-TOE LIVE SIM         KEY MAPPING
==========================     =============
         █ | · | ·               1 | 2 | 3
        ---+---+---             ---+---+---
         · | · | █               4 | 5 | 6
        ---+---+---             ---+---+---
         · | · | █               7 | 8 | 9
==========================     =============
 Status: Game Running                  
 Controls: [1-9] Move, [R] Reset, [Q] or Ctrl+C to Quit
```

## Waveforms
The simulation generates a waveform file (`tb.fst`).

### View with GTKWave:
```bash
gtkwave tb.fst tb.gtkw
```

### View with Surfer:
```bash
surfer tb.fst
```

## Configuration
- **CLK_FREQ:** In simulation, the frequency is set to **1000Hz** via the `SIM` macro in `project.v`. This frequency is used for both automated and interactive simulation.
- **I/O Mapping:** The testbench mirrors the ASIC pinout:
  - `ui_in[7:0]` and `uio_in[0]` for buttons.
  - `uo_out[7:0]` and `uio_out[7]` for LEDs.
