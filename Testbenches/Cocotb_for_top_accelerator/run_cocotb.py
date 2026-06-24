import os
from pathlib import Path
from cocotb_tools.runner import get_runner

def test_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent

    verilog_sources = [
        proj_path / "data_skew_buffer.v",
        proj_path / "pe.v",
        proj_path / "systolic_array.v",
        proj_path / "top_accelerator.v",
        proj_path / "dump.v"
    ]

    runner = get_runner(sim)
    runner.build(
        verilog_sources=verilog_sources,
        hdl_toplevel="top_accelerator",
        always=True,
        timescale=("1ns", "1ps")
    )

    runner.test(
        hdl_toplevel="top_accelerator",
        test_module="8x8test",
        waves=True
    )

if __name__ == "__main__":
    test_runner()
