---
description: >
  Use when reading or modifying Verilog RTL modules — structural hierarchy,
  top-level interconnects, Control Unit (FSM), Datapath, and memory submodules.
globs: **/*.v,**/*.sv
alwaysApply: false
---

# Microarchitecture Map

| Layer / Role | Primary Modules | Responsibility |
|---|---|---|
| **Top-Level Wrapper** | `piano_top.v` | DE0-CV pinouts, button inversions, display multiplexing, clock/reset wiring |
| **Control Unit (FSM)** | `unidade_controle.v` | Moore/Mealy FSM, state transitions, command signals (`escreve_ram`, `zera_end`, `conta_end`) |
| **Datapath (Fluxo de Dados)** | `fluxo_dados.v` | Note priority encoder, frequency LUT, audio synth, octave management, debouncers |
| **Audio & Volume** | `gerador_audio.v`, `gerador_pwm.v` | Note tone synthesis, ADSR envelope, PWM volume modulation |
| **Memory Subsystems** | `sync_rom.v`, `sync_ram.v` | Synchronous FPGA M10K block ROM (score storage) and RAM (recorded tracks) |
| **Peripherals & Displays** | `debounce.v`, `edge_detector.v`, `hexa7seg.v` | Input signal conditioning and 7-segment active-low decoding |

**Core Interconnect Invariant**: Control Unit (`unidade_controle`) issues control vectors and reads status flags from Datapath (`fluxo_dados`); Datapath houses all arithmetic, registers, and sub-blocks.

Deep signal contracts and submodule parameters: `docs/llm/architecture-guide.md`.