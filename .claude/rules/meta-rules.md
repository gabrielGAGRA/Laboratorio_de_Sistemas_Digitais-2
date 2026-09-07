---
---

# Meta rules

## Priority (highest -> lowest)
1. `AGENTS.md` - persona, behavioral constraints, laboratory structure and user assistance role
2. `project-rules` - hardware repo scope, FPGA tech stack, lab layout
3. `agents-feature-checklist` - change order (before, during, and after implementation)
4. `project-tests` - testbench layout and simulation pointers
5. `docs/llm/software-engineering-rules-verilog.md` - synthesizable RTL standards (passive; read when implementing)

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
| Persona, hardware constraints, user role | `AGENTS.md` |
| Tech stack, FPGA target platform, lab layout | `project-rules` + `docs/llm/laboratorios-guide.md` |
| Before an ambiguous or relevant change | `@interview-plan` + `agents-feature-checklist` |
| After an RTL change (latch check, simulation, checklist) | `agents-feature-checklist` |
| Validating any diff before delivery | `@adversarial-review` |
| Laboratory workflow (Planejamento vs Relatório) | `docs/llm/laboratorios-guide.md` |
| Verilog synthesis rules, latches, operators | `docs/llm/software-engineering-rules-verilog.md` |
| Testbenches & simulation commands | `project-tests` + `docs/llm/testbench-guide.md` |
| Rule create / update / self-healing | `@project-rules-writing` skill |