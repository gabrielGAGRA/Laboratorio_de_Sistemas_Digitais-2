---
description: Use when editing Verilog - feature change checklist, post-change quality gate, and decision matrix.
applyTo: Laboratórios/**/*.v,Laboratórios/**/*.vh
---

# Feature Change Checklist

## Post-change
1. **Quality gate:** Run `python3 scripts/lint_verilog.py <files>`.
2. **Simulation gate:** Execute the self-checking testbench with `iverilog` until displays 0 errors.
3. **Rules / governance:** When necessary, read `@project-rules-writing`, only right before updating rules (invocation time).
4. **Git:** Only when requested by user; if so, read `@commit` only at invocation time.
5. **Adversarial review:** Use `@adversarial-review` on a subagent; resolve Required findings and re-run affected verification.

## Decision Matrix
After finishing a task, evaluate downstream updates. Open a file ONLY when a trigger below matches.
| You Changed | Evaluate |
| --- | --- |
| Submodule or Datapath (`*_fd.v` or primitive) | Check top-level instantiation connections and parent testbench |
| Control Unit FSM (`*_uc.v`) | Check state encoding constants, latch prevention defaults, and FSM testbench |
| Top-level module (`Laboratórios/EXPx/*/*.v`) | Verify pin mapping against DE0-CV pinouts, run full top-level testbench |
| Testbench (`tb_*.v` or `*_tb.v`) | Ensure self-checking logic, termination via `$finish`, and check waveform dump flags |
| Promoting from `Planejamento/` to `Relatório/` | Run full linter and regression test suite across all modules in the experiment |