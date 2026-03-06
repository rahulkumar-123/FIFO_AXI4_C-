# AXI4-Stream Synchronous FIFO

A production-grade, highly parameterizable Synchronous FIFO written in Verilog, designed specifically for high-throughput FPGA and ASIC data pipelines. It natively supports the AMBA AXI4-Stream protocol and employs a cycle-accurate C++ Golden Model text-regression verification flow to mathematically guarantee zero data corruption.

I built this IP because I needed a rock-solid, drop-in replacement for vendor-locked FIFO generators (like Xilinx/Intel IP cores). The architecture focuses on minimal latency, combinatorial exactness for status flags, and rigorous verification.

## Core Features

- **AXI4-Stream Native:** Full handshake (`tvalid` / `tready`) compatibility built straight into the core logic, ensuring lossless byte streaming out of the box.
- **Sideband Tiers:** Properly handles End-of-Packet `tlast` boundaries as well as variable-width byte enables via `tkeep` on closing transactions.
- **Programmable Thresholds:** Look-ahead tracking combinatorial logic to assert `almost_full` and `almost_empty` limits, giving upstream MACs/pipelined modules time to react before backpressure forces a drop.
- **Strictly Synchronous:** Complies exactly with the AXI spec by enforcing active-low synchronous resets across the board. No sketchy asynchronous reset timing violations.
- **FWFT Behavior:** First-Word Fall-Through. Data is valid on the master output exactly when `tvalid` goes high, saving a continuous clock cycle of tracking overhead on the receiving end.

## The Architecture
The module relies on dual augmented pointers (`rd_ptr` and `wr_ptr`) utilizing the extra MSB hardware approach. This avoids costly internal division or modulo logic when tracking circular wraparounds in the RAM.

By instantiating a localized parameterizable LUTRAM (`mem`), data payload, `tkeep` bitmasks, and `tlast` markers are unified, written, and extracted synchronously on the rising clock edge perfectly coupled with the handshake conditionals.

## Verification & Golden Model

Testing generic FIFOs via eyeball-waveforms doesn't prove anything at scale. I wrote a deterministic, text-backed regression test suite instead.

### The C++ Reference Model (`model.cpp`)
The C++ program serves as the absolute "Golden State."
1. It generates hundreds of randomized AXI4-Stream payload bursts.
2. It randomizes the probability of `tlast` packet boundaries and dynamically calculates randomized valid byte masks for `tkeep` partial word transfers.
3. It pushes the data through an idealized C++ `std::queue`.
4. It dumps the stimuli to `input_vectors.txt` and the verified expected results to `expected_output.txt`.

### The Simulation Execution (`test_runner.py` & `tb_fifo.v`)
A Python orchestrator script runs the entire sequence automatically:
1. Compiles the C++ model and generates the vectors.
2. Spins up the **ModelSim** `vlog` and `vsim` engines.
3. Feeds the Verilog testbench the text-based stimuli. 
4. The Verilog testbench (`tb_fifo.v`) randomizes hardware-level delays on the `tvalid` and `tready` ports to mimic unpredictable bus arbitration stalls.
5. Captures the physical cycle-accurate hardware output to `actual_output.txt`.
6. Does a complete 1:1 cross-comparison string evaluation proving the hardware matches the ideal C++ queue perfectly.

## Quick Start

You will need `g++`, Python 3, and ModelSim (or any Verilog standard simulator via tweaking `test_runner.py`) installed.

Execute the whole test flow with one command:
```bash
python test_runner.py
```

If it prints `OK: all txns matched golden model`, the Verilog is mathematically sound and ready to be synthesized onto your target silicon.

---
*Built with care for robust hardware pipelines. Drop a star or reach out if this saves you time fighting with vendor IP!*
