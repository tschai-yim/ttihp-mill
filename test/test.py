# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer

class TTTTester:
    def __init__(self, dut):
        self.dut = dut
        self.clk_freq = 1000 # As set in project.v for SIM
        self.step_cycles = 50 # 50ms at 1000Hz
        self.period_cycles = 16 * self.step_cycles # 800 cycles

    async def reset(self):
        self.dut.ena.value = 1
        self.dut.ui_in.value = 0
        self.dut.uio_in.value = 0
        self.dut.rst_n.value = 0
        await ClockCycles(self.dut.clk, 10)
        self.dut.rst_n.value = 1
        await ClockCycles(self.dut.clk, 10)

    async def press_button(self, index):
        """Presses a button and waits for it to be debounced."""
        debounce_cycles = 60 # Debouncer needs 40 cycles at 1000Hz

        if index < 8:
            current_ui = self.dut.ui_in.value.to_unsigned()
            self.dut.ui_in.value = current_ui | (1 << index)
        else:
            current_uio = self.dut.uio_in.value.to_unsigned()
            self.dut.uio_in.value = current_uio | 1  # uio_in[0] is button 8
        
        await ClockCycles(self.dut.clk, debounce_cycles)

        # Release button
        if index < 8:
            self.dut.ui_in.value = self.dut.ui_in.value.to_unsigned() & ~(1 << index)
        else:
            self.dut.uio_in.value = self.dut.uio_in.value.to_unsigned() & ~1
            
        await ClockCycles(self.dut.clk, debounce_cycles)

    def get_current_leds(self):
        val = self.dut.uo_out.value.to_unsigned()
        led8 = (self.dut.uio_out.value.to_unsigned() >> 7) & 1
        return (val & 0xFF) | (led8 << 8)

    async def sample_patterns(self):
        """Samples the LED outputs over a full animation period (16 steps)."""
        history = [[] for _ in range(9)]
        for _ in range(self.period_cycles):
            leds = self.get_current_leds()
            for i in range(9):
                history[i].append((leds >> i) & 1)
            await ClockCycles(self.dut.clk, 1)
        
        # Now compress history into 16 bits
        compact_patterns = []
        for i in range(9):
            pattern = 0
            for step in range(16):
                # Take majority vote in each 50-cycle window
                window = history[i][step*50 : (step+1)*50]
                if sum(window) > 25:
                    pattern |= (1 << (15 - step))
            compact_patterns.append(pattern)
        return compact_patterns

    def is_cyclic_match(self, observed, expected):
        if expected == 0: return observed == 0
        if expected == 0xFFFF: return observed == 0xFFFF
        
        # Check all 16 cyclic shifts
        for i in range(16):
            shifted = ((expected << i) | (expected >> (16 - i))) & 0xFFFF
            if observed == shifted:
                return True
        return False

    PATTERNS = {
        "OFF": 0x0000,
        "P1": 0xFFFF,
        "P2": 0xFF00,
        "WIN": 0xCCCC,
        "ERROR": 0xAAAA,
        "HIGHLIGHT": 0x8888,
        "DRAW": 0xDB7D 
    }

    async def assert_led_pattern(self, index, expected_name):
        patterns = await self.sample_patterns()
        observed = patterns[index]
        expected = self.PATTERNS[expected_name]
        assert self.is_cyclic_match(observed, expected), \
            f"LED {index} expected {expected_name} ({hex(expected)}), but got {hex(observed)}"

    async def assert_board_patterns(self, expected_names):
        """expected_names is a list of 9 pattern names."""
        patterns = await self.sample_patterns()
        for i in range(9):
            observed = patterns[i]
            expected = self.PATTERNS[expected_names[i]]
            assert self.is_cyclic_match(observed, expected), \
                f"LED {i} expected {expected_names[i]} ({hex(expected)}), but got {hex(observed)}"

@cocotb.test()
async def test_idle_animation(dut):
    """Verify the rotating dot animation in IDLE state."""
    tester = TTTTester(dut)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    await tester.reset()
    
    patterns = await tester.sample_patterns()
    for i in range(8):
        # bit i and i+8 should be set
        expected = (1 << (15 - i)) | (1 << (15 - (i + 8)))
        assert tester.is_cyclic_match(patterns[i], expected), f"LED {i} idle pattern mismatch"
    # LED 8 should blink with LED 0 (3'(8) == 0)
    assert tester.is_cyclic_match(patterns[8], (1 << 15) | (1 << 7))

@cocotb.test()
async def test_p1_win_row(dut):
    """Test a scenario where Player 1 wins with a row."""
    tester = TTTTester(dut)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    await tester.reset()

    # P1: 0, 1, 2
    # P2: 3, 4
    await tester.press_button(0) # P1
    await tester.press_button(3) # P2
    await tester.press_button(1) # P1
    await tester.press_button(4) # P2
    await tester.press_button(2) # P1 -> Win!

    # Wait for move feedback animation to finish
    await ClockCycles(dut.clk, 1000)

    expected = ["WIN", "WIN", "WIN", "P2", "P2", "OFF", "OFF", "OFF", "OFF"]
    await tester.assert_board_patterns(expected)

@cocotb.test()
async def test_p2_win_col(dut):
    """Test a scenario where Player 2 wins with a column."""
    tester = TTTTester(dut)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    await tester.reset()

    # P1: 0, 1, 3
    # P2: 2, 5, 8
    await tester.press_button(0) # P1
    await tester.press_button(2) # P2
    await tester.press_button(1) # P1
    await tester.press_button(5) # P2
    await tester.press_button(3) # P1
    await tester.press_button(8) # P2 -> Win! (2, 5, 8)

    await ClockCycles(dut.clk, 1000)

    expected = ["P1", "P1", "WIN", "P1", "OFF", "WIN", "OFF", "OFF", "WIN"]
    await tester.assert_board_patterns(expected)

@cocotb.test()
async def test_draw(dut):
    """Test a draw scenario where the board is full with no winner."""
    tester = TTTTester(dut)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    await tester.reset()

    # Moves:
    # P1: 0, 2, 3, 7, 8
    # P2: 1, 4, 5, 6
    moves = [0, 1, 2, 4, 3, 5, 7, 6, 8]
    for m in moves:
        await tester.press_button(m)

    await ClockCycles(dut.clk, 1000)

    # In a draw, P2 LEDs sparkle (DRAW pattern), P1 are solid
    expected = ["P1", "DRAW", "P1", "P1", "DRAW", "DRAW", "DRAW", "P1", "P1"]
    await tester.assert_board_patterns(expected)

@cocotb.test()
async def test_illegal_move(dut):
    """Verify that pressing an occupied cell triggers an error strobe."""
    tester = TTTTester(dut)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    await tester.reset()

    await tester.press_button(4) # P1 takes center
    await ClockCycles(dut.clk, 1000) # Wait for highlight to end
    
    # P2 tries to take center
    await tester.press_button(4) 
    
    # Should see ERROR pattern on LED 4 for 1 second
    await tester.assert_led_pattern(4, "ERROR")
    
    # After 1 second, should return to P1 (solid)
    await ClockCycles(dut.clk, 1000)
    await tester.assert_led_pattern(4, "P1")

@cocotb.test()
async def test_reset(dut):
    """Verify that the game can be reset after it's over."""
    tester = TTTTester(dut)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    await tester.reset()

    # Win the game
    await tester.press_button(0)
    await tester.press_button(3)
    await tester.press_button(1)
    await tester.press_button(4)
    await tester.press_button(2)
    await ClockCycles(dut.clk, 1000)
    
    # Game is over, winning line is WIN
    await tester.assert_led_pattern(0, "WIN")
    
    # Press any button to reset
    await tester.press_button(8)
    await ClockCycles(dut.clk, 100)
    
    # Should be back in IDLE
    patterns = await tester.sample_patterns()
    # P1 (index 0) should not be solid anymore
    assert not tester.is_cyclic_match(patterns[0], tester.PATTERNS["P1"])
    assert not tester.is_cyclic_match(patterns[0], tester.PATTERNS["WIN"])
