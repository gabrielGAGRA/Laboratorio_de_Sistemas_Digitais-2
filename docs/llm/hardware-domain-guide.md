# Digital Hardware Domain & Board Invariants Guide

This guide defines physical constraints, DE0-CV FPGA board conventions, musical note frequencies, memory structures, and timing constants.

---

## 1. Board & Physical I/O Invariants (Cyclone V / DE0-CV)

- **Master Clock:** 50 MHz on pin `CLOCK_50` ($T = 20\,\text{ns}$). All synchronous logic runs in this domain.
- **Master Reset:** Physical pin `reset_n` is active-low (pressed = 0).
  - In `piano_top.v`, inverted immediately: `wire reset = ~reset_n;` (all internal RTL uses active-high synchronous/asynchronous `reset`).
- **Pushbuttons (Keys / Switches):**
  - Physical board buttons are active-low. Invert at the top boundary before debouncing: `btn_modo(~btn_modo)`.
- **7-Segment Displays (`hex0` - `hex5`):**
  - Active-low segments (0 = lit, 1 = off).
  - `7'b1111111` (or `7'h7F`) corresponds to blank (all segments off).
- **LEDs & Buzzer:**
  - Active-high: driving `1` lights the LED or drives positive buzzer potential.

---

## 2. Operating Modes & FSM States

The system implements 4 core operating modes encoded in `fsm_modo_ativo [1:0]`:

| Mode | Value `[1:0]` | Name | Behavior |
|---|---|---|---|
| **0** | `2'd0` | **Modo Livre (Free Play)** | Real-time keyboard play, octave control, free audio synthesis. Displays song as blank. |
| **1** | `2'd1` | **Modo Aprendizado (Learning)** | Step-by-step song playback: waits for the user to press the correct note before advancing score. |
| **2** | `2'd2` | **Modo Gravação / Reprodução** | Records played notes into `sync_ram` and replays them sequentially. |
| **3** | `2'd3` | **Modo Demonstração (Auto Play)** | Automatically plays stored song from `sync_rom` at the defined BPM tempo. |

---

## 3. Note Encoding & Audio Synthesis Formula

### Note Identification (`id_nota [2:0]`):
- `3'd0`: Silence / Rest (no note active)
- `3'd1`: Dó (C)
- `3'd2`: Ré (D)
- `3'd3`: Mi (E)
- `3'd4`: Fá (F)
- `3'd5`: Sol (G)
- `3'd6`: Lá (A)
- `3'd7`: Si (B)
- Suffix / Modifier: `sustenido` (1-bit flag: 1 = sharp, 0 = natural).

### Frequency Divider Formula:
For a square wave frequency $f_{\text{nota}}$ synthesized from $f_{\text{clk}} = 50\,\text{MHz}$:
$$\text{DIVISOR} = \frac{50\,000\,000}{2 \times f_{\text{nota}}}$$
The audio counter toggles the buzzer output when it reaches $\text{DIVISOR}$. These values are precomputed into `frequencia_lut.v`.

---

## 4. Debounce Timing Constants

Filter constants for `debounce.v` run on the 50 MHz clock:
- **Keys / Teclas:** `DEBOUNCE_TECLA = 100_000` cycles ($100\,000 \times 20\,\text{ns} = 2\,\text{ms}$).
- **Control Buttons:** `DEBOUNCE_CONTROLE = 200_000` cycles ($200\,000 \times 20\,\text{ns} = 4\,\text{ms}$).
- **Simulation override:** When writing testbenches, override these parameters to small values (e.g., `DEBOUNCE_TECLA = 5`) to prevent simulation stalls.

---

## 5. Memory Asset Formatting (`assets/*.txt` for `$readmemb`)

Song files read into `sync_rom` contain binary-formatted records, one note entry per line:
- **Bit [6:4]:** Note ID (0 to 7)
- **Bit [3]:** Sharp flag (1 = sharp, 0 = natural)
- **Bit [2:0]:** Octave (typically 3, 4, or 5)
- **End-of-song marker:** Encoded as special value `7'b0000000` (or `7'h00` / max address).
