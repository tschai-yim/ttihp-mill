import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles
import sys
import select
import termios
import tty
import logging
import time
import os
import signal

# Suppress noisy cocotb logs
logging.getLogger("cocotb").setLevel(logging.ERROR)

def get_board_leds(dut):
    val = dut.uo_out.value.to_unsigned()
    led8 = (dut.uio_out.value.to_unsigned() >> 7) & 1
    return (val & 0xFF) | (led8 << 8)

def render_board(leds, info_msg=""):
    chars = ["█" if (leds >> i) & 1 else "·" for i in range(9)]
    
    out = []
    out.append("\033[H") # Home cursor
    out.append("   TIC-TAC-TOE LIVE SIM         KEY MAPPING")
    out.append("==========================     =============")
    out.append(f"         {chars[0]} | {chars[1]} | {chars[2]}               1 | 2 | 3")
    out.append("        ---+---+---             ---+---+---")
    out.append(f"         {chars[3]} | {chars[4]} | {chars[5]}               4 | 5 | 6")
    out.append("        ---+---+---             ---+---+---")
    out.append(f"         {chars[6]} | {chars[7]} | {chars[8]}               7 | 8 | 9")
    out.append("==========================     =============")
    out.append(f" Status: {info_msg:<30}")
    out.append(" Controls: [1-9] Move, [R] Reset, [Q] or Ctrl+C to Quit")
    out.append("\033[J") # Clear to end
    return "\n".join(out)

def is_data():
    return select.select([sys.stdin], [], [], 0) == ([sys.stdin], [], [])

async def press_button(dut, index):
    # CLK_FREQ=1000, so 60 cycles is 60ms - enough for debouncer
    if index < 8:
        current_val = dut.ui_in.value.to_unsigned()
        dut.ui_in.value = current_val | (1 << index)
    else:
        dut.uio_in.value = 1
    await ClockCycles(dut.clk, 60)
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 60)

@cocotb.test()
async def interactive_test(dut):
    # 1ms period = 1000Hz. Matches CLK_FREQ=1000 in Verilog for simulation.
    clock = Clock(dut.clk, 1, unit="ms")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    old_settings = termios.tcgetattr(sys.stdin)
    info_msg = "Ready"
    
    # Clear screen and hide cursor
    sys.stdout.write("\033[2J\033[?25l")
    sys.stdout.flush()

    def cleanup():
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
        sys.stdout.write("\033[?25h\nSimulation exited.\n") # Show cursor
        sys.stdout.flush()
        os._exit(0)

    # Handle Ctrl+C properly
    def signal_handler(sig, frame):
        cleanup()
    signal.signal(signal.SIGINT, signal_handler)

    try:
        tty.setcbreak(sys.stdin.fileno())
        
        while True:
            frame_start_wall = time.perf_counter()
            
            # 1. Input handling
            if is_data():
                c = sys.stdin.read(1).lower()
                if c == 'q':
                    break
                elif c == 'r':
                    info_msg = "Resetting..."
                    dut.rst_n.value = 0
                    await ClockCycles(dut.clk, 10)
                    dut.rst_n.value = 1
                elif c in "123456789":
                    idx = int(c) - 1
                    info_msg = f"Button {c} pressed"
                    cocotb.start_soon(press_button(dut, idx))

            # 2. Advance Simulation by 20ms of Logic Time
            # At 1000Hz, this is exactly 20 cycles.
            await ClockCycles(dut.clk, 20)

            # 3. Update Display
            leds = get_board_leds(dut)
            sys.stdout.write(render_board(leds, info_msg))
            sys.stdout.flush()

            # 4. Sync with Wall Clock
            elapsed_wall = time.perf_counter() - frame_start_wall
            sleep_time = 0.020 - elapsed_wall
            if sleep_time > 0:
                time.sleep(sleep_time)
            
            if "pressed" in info_msg or "Resetting" in info_msg:
                info_msg = "Game Running"

    finally:
        cleanup()
