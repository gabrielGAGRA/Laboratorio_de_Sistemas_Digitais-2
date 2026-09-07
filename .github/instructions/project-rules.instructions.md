
# Project Core

## Repository & Tech Stack

- **HDL Standard:** Synthesizable Verilog-2001 (IEEE Std 1364-2001).
- **Target Hardware:** Intel / Altera Cyclone V FPGA (DE0-CV Development Kit, 50 MHz clock).
- **Synthesis Toolchain:** Quartus Prime (Intel FPGA Edition).
- **Simulation:** Icarus Verilog (`iverilog` / `vvp`) / ModelSim / QuestaSim.
- **Architecture:** Synchronous Digital Design (Top-Level $\to$ Control Unit FSM + Datapath $\to$ Submodules & M10K Memory).

## User Collaboration

- **Laboratory Hierarchy:** All experiment work strictly follows `Laboratórios/EXP<N>/Planejamento` (pre-lab design, preliminary FSM/datapath, initial testbenches) or `Laboratórios/EXP<N>/Relatório` (final verified RTL, complete testbenches, post-lab deliverables).
- **Active User Assistance:** The user actively assists the workflow. The user provides lab guidelines (roteiros), problem statements, timing diagrams, pin assignments, and performs physical validation on the DE0-CV board (switches, pushbuttons, LEDs, 7-segment displays). Consult the user for hardware-level feedback, physical board test observations, and ambiguous lab requirements.