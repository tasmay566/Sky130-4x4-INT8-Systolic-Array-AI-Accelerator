import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_8x8_systolic_array(dut):
    """Test 8x8 matrix multiplication on the systolic array"""
    
    # Hardware Parameters
    N = 8
    ACT_WIDTH = 8
    WGT_WIDTH = 8
    PSUM_WIDTH = 32

    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize inputs
    dut.reset.value = 1
    dut.load_weight.value = 0
    dut.psum_in_top.value = 0
    dut.weight_in_top.value = 0
    dut.act_in_flat.value = 0

    # Wait for a few clock cycles and release reset
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    dut._log.info("Hardware Reset Complete.")
    await RisingEdge(dut.clk)

    # ==========================================
    # MANUALLY DEFINED 8x8 MATRICES
    # Feel free to change these numbers to test specific edge cases!
    # ==========================================
    A = [
        [1, 2, 1, 3, 1, 2, 1, 1],
        [2, 1, 2, 1, 2, 1, 2, 2],
        [1, 1, 3, 1, 1, 2, 1, 3],
        [3, 2, 1, 2, 3, 1, 2, 1],
        [1, 2, 2, 1, 1, 3, 1, 2],
        [2, 1, 1, 2, 2, 1, 3, 1],
        [1, 3, 1, 1, 2, 2, 1, 2],
        [2, 2, 1, 3, 1, 1, 2, 1]
    ]

    B = [
        [2, 1, 1, 2, 1, 3, 1, 2],
        [1, 2, 3, 1, 2, 1, 1, 1],
        [1, 1, 2, 2, 1, 1, 2, 3],
        [3, 2, 1, 1, 2, 2, 1, 1],
        [1, 1, 2, 3, 1, 2, 1, 2],
        [2, 3, 1, 1, 2, 1, 2, 1],
        [1, 2, 1, 2, 1, 1, 3, 1],
        [2, 1, 2, 1, 3, 2, 1, 1]
    ]

    # Calculate Expected Golden Model using standard Python math
    C_expected = [[sum(a * b for a, b in zip(A_row, B_col)) for B_col in zip(*B)] for A_row in A]

    dut._log.info("--- MATRIX A ---")
    for row in A: dut._log.info(str(row))
    dut._log.info("--- MATRIX B (WEIGHTS) ---")
    for row in B: dut._log.info(str(row))
    dut._log.info("--- EXPECTED OUTPUT MATRIX C ---")
    for row in C_expected: dut._log.info(str(row))
    dut._log.info("--------------------------------")

    # ==========================================
    # Step 1: Load Weights (B matrix)
    # We push bottom row (N-1) first so it settles at the bottom of the array
    # ==========================================
    dut.load_weight.value = 1
    for row in reversed(range(N)):
        packed_weight = 0
        for col in range(N):
            # Shift each 8-bit weight into its proper column slot
            packed_weight |= (B[row][col] & 0xFF) << (col * WGT_WIDTH)
        
        dut.weight_in_top.value = packed_weight
        await RisingEdge(dut.clk)

    dut.load_weight.value = 0
    dut.weight_in_top.value = 0
    dut._log.info("8x8 Matrix B Locked into PEs.")

    # ==========================================
    # Step 2: Feed Activations (A matrix)
    # Stream in row by row into the flat wire
    # ==========================================
    for row in range(N):
        packed_act = 0
        for i in range(N):
            # Shift each 8-bit activation into its proper row slot
            packed_act |= (A[row][i] & 0xFF) << (i * ACT_WIDTH)
        
        dut.act_in_flat.value = packed_act
        await RisingEdge(dut.clk)

    # Feed zeros to flush out the pipeline
    dut.act_in_flat.value = 0
    
    # ==========================================
    # Step 3: Monitor the 256-bit wide output
    # ==========================================
    dut._log.info("Watching outputs propagate...")
    
    # An 8x8 array takes longer to flush. N cycles to load, N to compute, plus skew delay.
    # 25 cycles is plenty of time to catch all falling data.
    for cycle in range(25):
        await RisingEdge(dut.clk)
        
        try:
            # Read the massive 256-bit wire
            psum_out = int(dut.psum_out_bottom.value)
            
            # Unpack the 32-bit columns
            out_cols = []
            for col in range(N):
                out_cols.append((psum_out >> (col * PSUM_WIDTH)) & 0xFFFFFFFF)
            
            # Only print to terminal if actual math drops out (ignore rows of zeros)
            if sum(out_cols) > 0:
                dut._log.info(f"[Cycle {cycle}] psum_out_bottom = {out_cols}")
                
        except ValueError:
            # Safely ignore 'x' or 'z' uninitialized states at bootup
            pass
