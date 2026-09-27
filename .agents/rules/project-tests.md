---
trigger: model_decision
description: Use when writing or editing tests - test commands, TDD self checking, and how to run.
globs: Laboratórios/**/tb_*.v,Laboratórios/**/*_tb.v
---

# Testbenches & Simulation

- **Testbench Scope:** Every non-trivial module should have an accompanying self-checking testbench (`<module>_tb.v`).
- **Execution Workflow:**
  ```bash
  iverilog -o sim.vvp <module>.v tb_<module>.v
  vvp sim.vvp
  ```
- **Self-Checking Standard:** Testbenches must tally an `errors` integer and explicitly output sucess or failure.
- **Fast Simulation:** Override physical timing parameters to ensure simulations finish in milliseconds.

Simulation harnesses, template, and waveform dumping: `docs/llm/testbench-guide.md`.