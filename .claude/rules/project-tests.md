---
description: Use when writing or editing tests - test commands, TDD self checking, and how to run.
paths:
  - "Laboratórios/**/tb_*.v"
  - "Laboratórios/**/*_tb.v"
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
- **Waveform Diagnostics:** When checks fail or timing diverges, dump VCD signals (`$dumpfile("sim.vcd"); $dumpvars(0, <tb>);`) and run `python3 scripts/vcd_trace.py sim.vcd --clock <clk> --signals <s1,s2>` to inspect cycle-accurate signal transitions before editing RTL.

Simulation harnesses, template, and waveform dumping: `docs/llm/testbench-guide.md`.