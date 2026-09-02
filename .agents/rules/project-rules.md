---
description: >
  Workspace facts. Use for hardware tech stack, FPGA target platform,
  synthesis toolchain, project structure, and deferred work (TODO.md).
alwaysApply: true
---

# Project Core

## Repository & Tech Stack

- **HDL Standard:** Synthesizable Verilog-2001 (IEEE Std 1364-2001).
- **Target Hardware:** Intel / Altera Cyclone V FPGA (DE0-CV Development Kit, 50 MHz clock).
- **Synthesis Toolchain:** Quartus Prime (Intel FPGA Edition).
- **Simulation:** Icarus Verilog (`iverilog` / `vvp`) / ModelSim / QuestaSim.
- **Architecture:** Synchronous Digital Design (Top-Level $\to$ Control Unit FSM + Datapath $\to$ Submodules & M10K Memory).

---

# Deferred work (TODO.md)

When you or the user defer something for later, record it in `TODO.md` at the repository root so the team can track it.

- Add a bullet with a short description and enough context to resume work (file, area, or reason deferred).
- Update `TODO.md` in the same turn you agree to defer.
- If `TODO.md` does not exist yet, create it with a short heading and the first item.