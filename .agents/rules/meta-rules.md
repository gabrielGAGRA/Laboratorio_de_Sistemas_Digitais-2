---
trigger: always_on
description: >
---

# Meta rules

## Priority (highest -> lowest)
1. `AGENTS.md` - persona, workflow, behavioral constraints, laboratory structure and user assistance role
2. `project-rules` - hardware repo scope, FPGA tech stack, lab layout
3. `project-tests` - testbench layout and simulation pointers
4. `docs/llm/software-engineering-rules-verilog.md` - synthesizable RTL standards (passive; read before implementing)

## Skill Invocation (single registry)
| Trigger / Intent | Action |
|---|---|
| Ambiguous or non-trivial change, before drafting a plan | `@interview-plan` |
| Any diff before delivery. Only ran on a separate subagent orchestration. | `@adversarial-review` |
| If the user sends the variables and asks for the pin mappings. | `@pin-mapper` |