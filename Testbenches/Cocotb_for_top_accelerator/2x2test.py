"""import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_systolic_array(dut):
    """Test 2x2 matrix multiplication on the systolic array"""
    
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, unit="step")
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
    await RisingEdge(dut.clk)

    # Matrices to multiply: C = A * B
    # A = [[11, 22],
    #      [33, 44]]
    # B = [[1, 0],
    #      [0, 1]]
    # Expected C = [[11, 22],
    #               [33, 44]]

    # Step 1: Load Weights (B matrix)
    # The comments say: "To load weights, we feed them into the top row, and they will shift down."
    # So we feed row 1 of B, then row 0 of B.
    # B row 1 = [7, 8]. weight_in_top[15:8] = 8 (col 1), weight_in_top[7:0] = 7 (col 0)
    
    dut.load_weight.value = 1
    dut.weight_in_top.value = (1 << 8) | 0
    await RisingEdge(dut.clk)

    # B row 0 = [5, 6]. weight_in_top[15:8] = 6 (col 1), weight_in_top[7:0] = 5 (col 0)
    dut.weight_in_top.value = (0 << 8) | 1
    await RisingEdge(dut.clk)

    dut.load_weight.value = 0
    dut.weight_in_top.value = 0

    # Step 2: Feed Activations (A matrix) row by row
    # A row 0 = [1, 2]. act_in_flat[15:8] = 2 (col 1 -> row 1 of array), act_in_flat[7:0] = 1 (col 0 -> row 0 of array)
    dut.act_in_flat.value = (22 << 8) | 11
    await RisingEdge(dut.clk)

    # A row 1 = [3, 4]. act_in_flat[15:8] = 4 (col 1 -> row 1 of array), act_in_flat[7:0] = 3 (col 0 -> row 0 of array)
    dut.act_in_flat.value = (44 << 8) | 33
    await RisingEdge(dut.clk)

    # Feed zeros to flush out the pipeline
    dut.act_in_flat.value = 0
    
    # Wait for the results to propagate
    # It takes several cycles for psum to reach the bottom
    for _ in range(10):
        await RisingEdge(dut.clk)
        
        # Read the bottom partial sums
        psum_out = int(dut.psum_out_bottom.value)
        psum_col0 = psum_out & 0xFFFFFFFF
        psum_col1 = (psum_out >> 32) & 0xFFFFFFFF
        
        dut._log.info(f"Time {cocotb.utils.get_sim_time('ns')}ns: psum_out_bottom = [col0: {psum_col0}, col1: {psum_col1}]")
        
        # Check against expected results C = [[19, 22], [43, 50]]
        # Output order should be (C00, C01) then (C10, C11)
        # Expected outputs at different times:
        if psum_col0 == 19:
            dut._log.info("Successfully matched C00 (19)")
        if psum_col1 == 22:
            dut._log.info("Successfully matched C01 (22)")
        if psum_col0 == 43:
            dut._log.info("Successfully matched C10 (43)")
        if psum_col1 == 50:
            dut._log.info("Successfully matched C11 (50)")
            
        """