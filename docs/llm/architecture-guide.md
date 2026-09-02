# Digital Systems Microarchitecture & Interconnect Guide

This guide details the structural hierarchy, module roles, and signal contracts between the Control Unit, Datapath, Memory, and Peripherals.

---

## 1. Structural Hierarchy Overview

The digital design is partitioned into standard RTL layers:

```text
[Top-Level Wrapper: piano_top.v]
  ├── Reset Condition & Polarity: reset = ~reset_n
  ├── Debounce & Edge Detectors (Button conditioning)
  ├── [Control Unit (FSM): unidade_controle.v]
  │     └── FSM states, transition logic, command signal outputs
  ├── [Datapath: fluxo_dados.v]
  │     ├── Note Priority Encoder: logica_notas_prioridade.v
  │     ├── Octave Register & Limits: guarda_oitava.v
  │     ├── Song Sequencer & Counters: contador_m.v
  │     ├── Memory (ROM / RAM): sync_rom.v, sync_ram.v
  │     ├── Frequency Lookup Table: frequencia_lut.v
  │     ├── Audio & ADSR Synthesis: gerador_audio.v
  │     └── LED / Volume Modulation: gerador_pwm.v
  └── Display & Visual Decoding
        ├── 7-Segment Hex Decoders: hexa7seg.v
        ├── Musical Cipher Display: decodificador_cifra.v
        └── Sharp Indicator: display_sustenido.v
```

---

## 2. Control Unit (FSM) <-> Datapath Signal Contract

Communication between `unidade_controle` and `fluxo_dados` follows strict command/status handshakes:

### Commands (Driven by Control Unit -> Read by Datapath):
- `fsm_modo_ativo [1:0]`: Operating mode (0: Free Play, 1: Learning, 2: Record/Play, 3: Demonstration).
- `fsm_zera_end`: Synchronous reset of the song/RAM memory address counter.
- `fsm_conta_end`: Increment memory address pointer to next note in sequence.
- `fsm_escreve_ram`: Write-enable pulse to store note data into `sync_ram`.

### Status Flags (Driven by Datapath -> Read by Control Unit):
- `fd_mudou_modo`: Single-cycle pulse indicating mode button press.
- `fd_mudou_musica`: Single-cycle pulse indicating song select button press.
- `fd_tem_nota_ativa`: Asserted while any piano key is currently pressed.
- `fd_acerto_nota`: Asserted in Learning Mode when user plays the note currently requested by the score.
- `fd_fim_musica`: Asserted when memory pointer reaches the end-of-track marker.
- `fd_pulso_bpm`: Periodic tempo tick controlling score playback speed.

---

## 3. Submodule Catalog & Parameter Disciplines

| Module | Primary Parameters | Purpose |
|---|---|---|
| `piano_top.v` | `DEBOUNCE_TECLA`, `DEBOUNCE_CONTROLE` | Top-level pin routing, inversion wrappers, and display muxes |
| `unidade_controle.v` | N/A | Moore/Mealy state machine controlling operating modes and flow |
| `fluxo_dados.v` | `DEBOUNCE_TECLA`, `DEBOUNCE_CONTROLE` | Datapath pipeline and submodule integration |
| `contador_m.v` | `M` (modulus), `N` (counter bit-width) | Reusable parameterizable rollover counter |
| `debounce.v` | `LIMITE_CONTAGEM` | Stable debouncing filter for mechanical pushbuttons/switches |
| `edge_detector.v` | N/A | Single-cycle pulse generator on rising/falling transitions |
| `sync_rom.v` | `DATA_WIDTH`, `ADDR_WIDTH`, `INIT_FILE` | Synchronous ROM inferred into FPGA M10K block memory |
| `sync_ram.v` | `DATA_WIDTH`, `ADDR_WIDTH` | Synchronous Single-Port RAM for user-recorded melodies |
| `frequencia_lut.v` | N/A | Combinational LUT mapping note ID + octave to clock-divider count |
| `gerador_audio.v` | N/A | Audio wave frequency generation with dynamic envelope (ADSR) |
| `gerador_pwm.v` | `RESOLUTION_BITS` | High-frequency PWM modulator for volume/LED brightness |

---

## 4. Integration Guidelines

1. **Named Port Bindings:** Always connect submodules using `.port_name(signal_name)`.
2. **Explicit Clock & Reset:** Propagate the global `clock` (50 MHz) and `reset` directly; never derive sub-clocks combinational logic.
3. **Pipelining & Latency:** Note that synchronous memories (`sync_rom`, `sync_ram`) have a 1-cycle read latency; address changes at clock cycle $T$ output valid data at cycle $T+1$.
