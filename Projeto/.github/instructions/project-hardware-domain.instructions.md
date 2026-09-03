---
description: Use when modifying board I/O, clocking, reset polarity, physical buttons, FSM operating modes, note/octave encoding, or 7-segment display logic.
applyTo: **/*.v,**/*.sv
---

# Hardware Domain Map

- **Clocks & Resets:** Master clock is 50 MHz (`CLOCK_50`). Physical pin `reset_n` is active-low, inverted at top-level boundary: `wire reset = ~reset_n;`.
- **I/O Polarity:**
  - Mechanical pushbuttons: active-low on board -> invert at top boundary: `~btn`.
  - 7-Segment Displays (`hex0` - `hex5`): active-low (0 = segment lit, 1 = off, `7'h7F` = blank).
  - LEDs & Buzzer: active-high.
- **Operating Modes (`fsm_modo_ativo [1:0]`):**
  - `2'd0`: Modo Livre (Free play, score blanked).
  - `2'd1`: Modo Aprendizado (Interactive step-by-step note matching).
  - `2'd2`: Modo Gravação / Reprodução (Record into RAM & replay).
  - `2'd3`: Modo Demonstração (Automated playback from ROM at tempo tick).
- **Note Encoding:** 3-bit Note ID (1=Dó .. 7=Si, 0=Silêncio) + 1-bit `sustenido` (sharp) + Octaves 1-7.
- **Debouncing:** Keys = 2 ms (`100_000` cycles), Control buttons = 4 ms (`200_000` cycles).

Deep frequency tables, pinouts, and memory asset specs: `docs/llm/hardware-domain-guide.md`.
