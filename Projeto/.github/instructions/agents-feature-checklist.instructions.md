---
description: Checklist and decision matrix before, during, and after implementing Verilog RTL changes.
applyTo: **/*.v,**/*.sv
---

# Feature Change Checklist

## Post-change Quality Gate
1. **Synthesizability & Latch Prevention Audit:**
   - Verify every combinational `always @(*)` assigns safe default values at the very top.
   - Verify every `case` statement has a `default:` branch.
   - Ensure strictly non-blocking (`<=`) in sequential blocks and blocking (`=`) in combinational blocks. Never mix them.
   - Ensure file starts with `` `default_nettype none `` and ends with `` `default_nettype wire ``.
   - Ensure named port bindings (`.port(sig)`) on all module instantiations.
2. **Simulation & Testbench:**
   - Run relevant module testbench (e.g. `iverilog -o sim.vvp <module>.v tb_<module>.v && vvp sim.vvp`).
   - Confirm output logs `SUCCESS: ALL TESTBENCH CHECKS PASSED!`.
3. **Docs Update:** Update `docs/llm/` guides as triggered by the decision matrix.
4. **Adversarial Review:** Invoke `@adversarial-review` on the diff before concluding.

## Decision Matrix
After finishing an RTL task, evaluate downstream updates. Open a file ONLY when a trigger matches:

| You Changed | Evaluate |
|---|---|
| Module hierarchy, top wrapper, or port list | `project-architecture.md` & `docs/llm/architecture-guide.md` |
| FSM states, transition logic, or command signals | `unidade_controle.v` testbench & `docs/llm/architecture-guide.md` |
| Pinout, button inversion, display decoding, or audio math | `project-hardware-domain.md` & `docs/llm/hardware-domain-guide.md` |
| Block ROM/RAM sizing or song asset formats (`.txt`) | `docs/llm/hardware-domain-guide.md` & memory testbenches |
| Testbench layout, simulation commands, or verification harness | `project-tests.md` & `docs/llm/testbench-guide.md` |