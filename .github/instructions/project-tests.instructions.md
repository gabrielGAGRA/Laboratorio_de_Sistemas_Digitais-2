---
description: Use when writing or editing tests - test commands, TDD self checking, and how to run.
applyTo: Laboratórios/**/tb_*.v,Laboratórios/**/*_tb.v
---

# Testbenches & Simulation

- **Testbench Scope:** Every non-trivial module should have an accompanying self-checking testbench (`tb_<module>.v` or `<module>_tb.v`).
- **Execution Workflow (Icarus Verilog):**
  ```bash
  iverilog -o sim.vvp <module>.v tb_<module>.v
  vvp sim.vvp
  ```
- **Self-Checking Standard:** Testbenches must tally an `errors` integer and explicitly output `SUCCESS: ALL TESTBENCH CHECKS PASSED!` or `FAILURE: <N> error(s)` followed by `$finish`.
- **Fast Simulation:** Override physical timing parameters (e.g., set debouncer or baud rate dividers to small numbers of cycles) to ensure simulations finish in milliseconds.
- **User Assistance Role:** The user assists by providing expected test vectors from the lab guide (roteiro), inspecting waveforms (`.vcd` in GTKWave) when debugging subtle timing bugs, and running the synthesized bitstream on the physical DE0-CV FPGA board.

Simulation harnesses, template, and waveform dumping: `docs/llm/testbench-guide.md`.
Synthesis and RTL coding rules: `docs/llm/software-engineering-rules-verilog.md`.