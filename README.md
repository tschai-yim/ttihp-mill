![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tic-Tac-Toe ASIC (Tiny Tapeout)

This project is a hardware-accelerated, two-player Tic-Tac-Toe implementation. The design is optimized for high throughput and performance to meet the extreme demands of the legendary 3x3 board game (some might even say it's NP-complete). It includes parallel win detection, a debouncing system for mechanical buttons, and an LED controller for various visual states.

## Operation

The design uses a state machine to manage turns and board state. An LED controller uses pattern look-up tables (LUTs) to drive 9 LEDs with different effects based on the current game state.

### Visual States:
*   **IDLE:** A single LED sequence "rotates" around the 3x3 grid.
*   **Player 1:** Solid ON.
*   **Player 2:** Slow Pulsing (50% duty cycle).
*   **Win Condition:** The three LEDs forming the winning line flash at a higher frequency.
*   **Draw:** If the board is full with no winner, the Player 2 LEDs flash at a higher frequency.
*   **Error:** If an occupied cell is selected, that LED strobes for one second.

## Testing and Simulation

### Automated Tests
The test suite in `test.py` verifies game logic, win conditions, and LED blinking patterns by sampling simulation outputs.

```bash
cd test
make
```

### Interactive Simulation
The terminal-based simulation environment synchronizes with the system clock to allow for real-time interaction with the design.

```bash
cd test
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

## Technical Specifications
- **Architecture:** Synchronous digital design.
- **Input Debouncing:** 5ms sample rate with 8-cycle history.
- **Win Detection:** Parallel combinational logic checking all 8 win conditions.
- **Clock:** Target 50MHz (ASIC); 1000Hz used for simulation.

For pinout mapping and additional details, see [docs/info.md](docs/info.md).

---

## Tiny Tapeout
Tiny Tapeout is an educational project for manufacturing digital designs on a real chip. Visit https://tinytapeout.com for details.
