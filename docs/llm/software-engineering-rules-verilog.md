# Verilog-2001 RTL Engineering Rules

Synthesizable Verilog-2001 (IEEE Std 1364-2001) standards for Intel Cyclone V FPGAs synthesized with Intel Quartus Prime Version 20.1.1 Lite Edition. Targets deterministic FPGA synthesis, M10K block memory inference, lint cleanliness, and timing closure.

---

## Editing this Doc

Objective syntax, naming patterns, compiler directives, and banned language constructs are automated by `scripts/lint_verilog.py`. Use this document for architectural and semantic decisions that a linter or compiler cannot enforce reliably. Automate what is objective; document what needs microarchitectural judgment, rationale, or an exception process.

### Modal verbs
- **NEVER / ALWAYS** — hard constraints; hardware malfunction, simulation-synthesis mismatch, or synthesis failure risk.
- **Prefer / Avoid** — default patterns when both work; follow unless timing closure, routing congestion, or FPGA resource limits demand otherwise.

*Why*: add a brief *Why* only when a rule deliberately counters a common online tutorial default or needs FPGA microarchitectural rationale.

---

## 1. Naming & File Conventions

- **Extensions & Ownership**: `.v` for synthesizable modules; `.vh` for header files. Exactly one module per file matching the file basename.
- **Module & instance names**: `snake_case` for modules; instances MUST prefix with `u_` (submodules) or `u_cell_` (primitives).
- **Clocks & resets**: `clock` or `clk`; internal module reset MUST be active-high `reset`. Board-level physical active-low pushbuttons/signals MUST end in `_n` (e.g., `reset_n`, `key_n`) and MUST be inverted at the top-level chip wrapper (`wire reset = ~reset_n;`).
  - *Why:* Internal active-high resets map directly to Cyclone V ALM clear registers (`aclr`/`sclr`) and keep submodules reusable and bug-free without inconsistent polarities.
- **Register separation**: Flop output MUST use `_q` or `_reg`; combinational next-state lookahead MUST use `_d` or `_next`.
- **Constants & Encodings**: `SCREAMING_SNAKE_CASE` for `parameter` and `localparam`. State encodings use `localparam [WIDTH-1:0] STATE_NAME = ...;`. NEVER use `parameter` for FSM states.

---

## 2. Module Boundaries & Formatting

- **Compiler directive**: ALWAYS declare `` `default_nettype none `` at the top of every file. Restore with `` `default_nettype wire `` at the bottom if toolchain requires.
  - *Why:* Prevents silent 1-bit wire inference when signal names are misspelled, catching typos during compilation instead of during board debugging.
- **Ports**: ANSI C-style port declarations ONLY. One port per line, aligned: direction (`input`/`output`/`inout`), net/variable type (`wire`/`reg`), signedness, width `[MSB:0]`, name. Group: Clocks/Resets, Control/Flow, Data Path, Status. NEVER use legacy Verilog-1995 split declarations.
  *Example:*
  ```verilog
  module contador_m #(
      parameter DATA_WIDTH = 8
  )(
      input  wire                  clock,
      input  wire                  reset,
      input  wire                  enable,
      output reg  [DATA_WIDTH-1:0] q,
      output wire                  done
  );
  ```
- **Instantiations**: Named port binding ONLY (`.clock(clock), .reset(reset)`). NEVER use positional instantiation. SystemVerilog wildcard `.*` is unsupported.
- **Unconnected ports**: Explicitly mark unused outputs with empty binding `.unused_port()`. NEVER leave input ports floating—tie off explicitly to sized literals (`1'b0` or `1'b1`).
- **Indentation**: 2 or 4 spaces consistently; NO tabs; 100-column soft limit (120 hard).
- **Dedicated processes**: Combinational logic MUST use `always @*` (or `always @(*)`). NEVER use manual sensitivity lists like `always @(a or b)` in synthesizable RTL. Sequential logic MUST use edge-triggered `always @(posedge clock or posedge reset)` or synchronous `always @(posedge clock)`.

---

## 3. Procedural Assignments & Latch Prevention

- **Sequential (`always @(posedge ...)` )**: Use non-blocking (`<=`) assignments ONLY. NEVER use blocking (`=`) in sequential blocks.
- **Combinational (`always @*`)**: Use blocking (`=`) assignments ONLY. NEVER use non-blocking (`<=`) in combinational blocks.
- **NEVER mix** `=` and `<=` within the same procedural block.
- **Single driver rule**: NEVER drive a signal from multiple `always` blocks or mix continuous `assign` with procedural assignments on the same signal.
- **Latch prevention (Default Assignment Idiom)**: In `always @*`, ALWAYS assign default values to all outputs at the very top of the block before any conditional branches, OR guarantee explicit assignment in every branch of `if`/`else` and `case`.
- **Exhaustive case**: ALWAYS provide a `default:` branch in `case` statements, even when states seem completely enumerated.
- **Synthesis pragmas**: NEVER use `// synopsys full_case parallel_case`.

---

## 4. Types, Widths, & Arithmetic

- **Data types**: Use `wire` for nets, continuous assignments, and submodule interconnects. Use `reg` strictly for procedural targets in `always` blocks. NEVER use SystemVerilog `logic`.
- **Explicit sizing**: NEVER use unsized literals (e.g., `42`, `0`). Always size: `8'd42`, `1'b0`, `16'hFFFF`.
  - SystemVerilog `'0` and `'1` do not exist. For bus clearing or filling, use `{WIDTH{1'b0}}` or `[WIDTH-1:0]'d0`.
- **Arithmetic carry width**: When adding two $N$-bit signals, destination MUST be at least $N+1$ bits wide to avoid silent overflow.
- **Signedness**: Verilog-2001 supports `signed`. NEVER mix signed and unsigned operands in the same expression without explicit `$signed()` or manual sign-extension.
- **Cyclone V DSP blocks**: Multiplications (`*`) infer Variable Precision DSP Blocks in Cyclone V when operand widths justify hardware multipliers. Keep multiplier widths aligned to 9, 18, or 27 bits for optimal ALM-to-DSP resource utilization.

---

## 5. FPGA Architecture: Clocks, Resets, & Cyclone V Hardware Invariants

- **Dedicated Clock Networks (GCLK)**: NEVER generate gated or divided clocks using logic gates (`wire clk_gated = clk & en`). Gated clocks cause severe clock skew, routing delays, and hold violations across Cyclone V ALMs.
- **Clock enables**: ALWAYS implement clock gating using register clock enables:
  *Example:*
  ```verilog
  always @(posedge clock or posedge reset) begin
      if (reset) begin
          q <= {WIDTH{1'b0}};
      end else if (clock_enable) begin
          q <= d;
      end
  end
  ```
  Cyclone V ALM flip-flops contain dedicated hardware clock-enable (`ena`) inputs.
- **M10K Block Memory Inference**:
  - Cyclone V embeds dedicated M10K memory blocks (10,240 bits each).
  - Quartus Prime 20.1 infers M10K blocks ONLY when read operations are synchronous (`always @(posedge clock) data_out <= ram[addr];`).
  - Asynchronous memory reads (`assign data_out = ram[addr];`) CANNOT map to M10K blocks and will exhaust ALM LUTs. NEVER use asynchronous read for large memories or ROMs.
  - Memory initialization: ROMs and initial RAM contents MUST be loaded using `initial $readmemh("file.hex", ram);` or `$readmemb`. Quartus Prime synthesizes this directly into M10K configuration bits.
- **Reset methodology**:
  - Internal logic standardizes on active-high `reset`.
  - Top-level chip wrappers must invert active-low pushbuttons (`wire reset = ~reset_n;`).
  - When using external asynchronous reset (`always @(posedge clock or posedge reset)`), deassert synchronously using a 2-FF reset synchronizer at top-level to prevent reset recovery/removal timing violations.
- **Internal Tri-States**:
  - Cyclone V FPGA fabric has NO internal tri-state buses (`1'bz`). Core multiplexing MUST use logic multiplexers. Tri-states are permitted ONLY on top-level bidirectional physical I/O pins (`inout`).

---

## 6. Parameters, Headers, & FSM State Encodings

- **`parameter` vs `localparam`**:
  - `parameter`: Module interface knobs meant to be overridden by parent instantiations (e.g. `parameter DATA_WIDTH = 8`).
  - `localparam`: Derived constants, internal limits, and FSM state encodings. NEVER override `localparam` from outside the module.
- **FSM State Encodings**:
  - NEVER use `parameter` for FSM states (which pollutes module interface configuration).
  - Use `localparam [WIDTH-1:0]` with explicit binary or one-hot encodings:
  *Example:*
    ```verilog
    localparam [2:0] STATE_INICIAL = 3'd0,
                     STATE_ESPERA  = 3'd1,
                     STATE_COMPARA = 3'd2,
                     STATE_PROXIMO = 3'd3;
    ```
- **Header files (`.vh`)**: Shared constants, widths, and macro definitions across multiple modules MUST reside in header files included via `` `include "project_defs.vh" `` with standard include guards:
  *Example:*
  ```verilog
  `ifndef PROJECT_DEFS_VH
  `define PROJECT_DEFS_VH

  `define AUDIO_SAMPLE_RATE 50000000

  `endif // PROJECT_DEFS_VH
  ```

---

## 7. Anti-Patterns & Prohibited Constructs

- **Redundant clock checks**: NEVER write `else if (clock)` inside an edge-triggered `always @(posedge clock ...)` block (legacy anti-pattern observed in older code). Use `if (reset) ... else begin ... end`.
- **`#delay`**: NEVER use `#<delay>` in synthesizable RTL. Synthesis tools ignore delays, leading to complete simulation-synthesis mismatches.
- **Combinational loops**: NEVER write combinational feedback loops (`assign a = a ^ b`). Logic paths MUST be strictly acyclic.
- **Unsized vector resets**: NEVER use `Q <= 0;` on multi-bit vectors. Use explicit width replication `Q <= {N{1'b0}};` or sized constants `Q <= 8'd0;`.
- **Floating inputs**: Tie unused inputs explicitly to `1'b0` or `1'b1`. Unused outputs MUST be explicitly bound to empty `.port()`.
- **Bit-select out of bounds**: Ensure index expressions stay within `[MSB:0]` bounds to avoid indeterminate bits.

---

## 8. Quartus Prime 20.1 Synthesis & Timing Closure

- **Timing Constraints (`.sdc`)**: Every design targeting Cyclone V in Quartus Prime MUST have at least a clock constraint in its Synopsys Design Constraints file (`create_clock -name clock -period 20.000 [get_ports CLOCK_50]`).
- **Synthesis attributes**: Use standard Verilog-2001 attributes `(* ramstyle = "M10K" *)` or `(* keep *)` directly above declarations when synthesis control is required.
- **Warnings treated as synthesis errors**:
  - Inferred latches (`Warning: Inferring latch for "..."`).
  - Undriven pins or stuck at VCC/GND.
  - Width mismatches in port connections or continuous assignments.