---
description: > 
  Use for rule priority, where to find docs, and when to 
  invoke skills (planning, adversarial review, commit, and rule governance). 
alwaysApply: true
---

# Meta rules

## Priority (highest -> lowest)
1. `AGENTS.md` - persona and behavioral constraints
2. `project-rules` - hardware repo scope, FPGA tech stack
3. `agents-feature-checklist` - change order (before, during, and after implementation)
4. `project-architecture` / `project-hardware-domain` - hierarchy and board domain invariants
5. `project-tests` - testbench layout and simulation pointers
6. `docs/llm/software-engineering-rules-verilog.md` - synthesizable RTL standards (passive; read when implementing)

## Skill Invocation (single registry)
| Trigger / Intent | Action |
|---|---|
| Commit, branch, or any git write | `@commit` |
| Create, edit, or self-heal agent rules / conventions | `@project-rules-writing` |
| Ambiguous or non-trivial change, before drafting a plan | `@interview-plan` |
| Any diff before delivery or git write | `@adversarial-review` |

## Navigation - when to read what
| Question | Read |
|---|---|
| Persona, hardware constraints | `AGENTS.md` |
| Tech stack, FPGA target platform | `project-rules` |
| Before an ambiguous or relevant change | `@interview-plan` + `agents-feature-checklist` |
| After an RTL change (latch check, simulation, checklist) | `agents-feature-checklist` |
| Validating any diff before delivery | `@adversarial-review` |
| Module hierarchy & interconnects | `project-architecture` + `docs/llm/architecture-guide.md` |
| Hardware I/O, modes, note math, memory assets | `project-hardware-domain` + `docs/llm/hardware-domain-guide.md` |
| Verilog synthesis rules, latches, operators | `docs/llm/software-engineering-rules-verilog.md` |
| Testbenches & simulation commands | `project-tests` + `docs/llm/testbench-guide.md` |
| Rule create / update / self-healing | `@project-rules-writing` skill |