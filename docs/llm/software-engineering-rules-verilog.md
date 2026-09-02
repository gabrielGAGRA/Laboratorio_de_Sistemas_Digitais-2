# SystemVerilog RTL Engineering Rules

Repo-agnostic SystemVerilog (IEEE Std 1800-2017) synthesizable RTL standards. Targets ASIC/FPGA synthesis, lint, formal verification, and timing closure.

---

## Editing this Doc

Use this document for architectural and semantic decisions that a linter/formatter cannot enforce reliably. Automate what is objective; document what needs microarchitectural judgment, rationale, or an exception process.

### Modal verbs
- **NEVER / ALWAYS** — hard constraints; physical silicon or synthesis failure risk.
- **Prefer / Avoid** — default patterns when both work; follow unless timing closure or area constraints demand otherwise.

*Why*: add a brief *Why* only when a rule deliberately counters a common model/tutorial default or needs generalization.

---

## 1. Naming & File Conventions

- **Extensions**: `.sv` for synthesizable modules; `_pkg.sv` for packages; `.svh` for macro headers. NEVER use `.v` for new code.
- **File ownership**: Exactly one top-level module, interface, or package per file; filename MUST match the declared symbol (e.g., `fifo_sync.sv`).
- **Module & instance names**: `snake_case` for modules; instances prefix with `u_` (submodules) or `u_cell_` (primitives).
- **Clocks & resets**: `clk` or `clk_<domain>`; active-low resets MUST end in `_n` or `_rst_n` (e.g., `rst_n`, `axi_rst_n`).
  - *Why:* Active-low is the ASIC standard; standardizing suffixes avoids phase-inversion bugs during clock-tree and reset synthesis.
- **Register separation**: Flop output MUST use `_q` or `_reg`; combinational next-state lookahead MUST use `_d` or `_next`.
  - *Why:* Distinguishes registered boundaries from combinational paths at a glance during timing analysis.
- **Constants & Types**: `SCREAMING_SNAKE_CASE` for `parameter` and `localparam`. Types end in `_t` (`axi_addr_t`); enums end in `_e` (`fsm_state_e`) with enum members prefixed by the enum name (e.g., `FSM_IDLE`).

---

## 2. Module Boundaries & Formatting

- **Compiler directive**: ALWAYS declare `` `default_nettype none `` at the top of every file. Restore with `` `default_nettype wire `` at the bottom if toolchain requires.
  - *Why:* Prevents silent 1-bit wire inference when signal names are misspelled.
- **Ports**: ANSI-C style ONLY. One port per line, aligned: direction (`input`/`output`), type (`logic`), signedness, width `[MSB:0]`, name. NEVER use legacy 1995/2001 split declarations. Group: Clocks/Resets, Control/Flow, Data Path, Status.
- **Instantiations**: Named port binding ONLY (`.clk(clk), .rst_n(rst_n)`). NEVER use positional instantiation.
  - Wildcard `.*` is permitted ONLY in verified top-level chip wrappers with identical pin names.
- **Unconnected ports**: Explicitly mark unused outputs with `.unused_port()`. NEVER leave input ports floating—tie off to `'0` or `'1'`.
- **Indentation**: 2 spaces; NO tabs; 100-column soft limit (120 hard).
- **Dedicated processes**: ALWAYS use `always_ff`, `always_comb`, and `always_latch`. NEVER use bare `always @*` or `always @(a or b)` in synthesizable RTL.

---

## 3. Procedural Assignments & Latch Prevention

- **Sequential (`always_ff`)**: Use non-blocking (`<=`) assignments ONLY. NEVER use blocking (`=`) in sequential blocks.
- **Combinational (`always_comb`)**: Use blocking (`=`) assignments ONLY. NEVER use non-blocking (`<=`) in combinational blocks.
- **NEVER mix** `=` and `<=` within the same procedural block.
- **Single driver rule**: NEVER drive a variable from multiple `always_*` blocks or mix continuous `assign` with procedural assignments on the same signal.
- **Latch prevention (Default Assignment Idiom)**: In `always_comb`, ALWAYS assign default values to all outputs at the very top of the block before any conditional branches, OR guarantee explicit assignment in every branch of `if`/`else` and `case`.
- **Exhaustive case**: ALWAYS provide a `default:` branch in `case` statements unless the selector is provably full.
- **Synthesis pragmas**: NEVER use `// synopsys full_case parallel_case`.
  - *Why:* Causes severe simulation-synthesis mismatches by telling the synthesis tool to make assumptions the simulator does not.

---

## 4. Types, Widths, & Arithmetic

- **Data type**: Use `logic` for all single-driver signals. NEVER use legacy `reg`. Reserve `wire` solely for multi-driver or tri-state buses.
- **Explicit sizing**: NEVER use unsized literals (e.g., `42`, `'0` in arithmetic/slices). Use sized literals: `8'd42`, `1'b0`, `16'hFFFF`.
  - Simple fill `'0` and `'1` is allowed only in standalone scalar/bus assignments (`data_q <= '0;`).
- **Arithmetic carry width**: When adding two $N$-bit signals, destination MUST be at least $N+1$ bits wide.
- **Signedness coercion trap**: NEVER mix signed and unsigned operands in the same expression.
  - *Why:* SystemVerilog coerces the entire expression to unsigned if even a single operand is unsigned, silently invalidating signed math.
- **Sign-extension**: Use explicit `$signed()` casts or replicate sign bits `{ {PAD{sig[MSB]}}, sig }`. Avoid implicit sign-extension.

---

## 5. Resets, Clocks, & Timing

- **Reset methodology**: Prefer Asynchronous Assert, Synchronous Deassert (AASD). Reset polarity MUST be consistent per domain (default active-low).
- **Data path resets**: Reset control registers (FSMs, counters, valid/ready flags, pointers). AVOID resetting wide data-path registers (payloads, pipelines, memories) unless required for security or protocol reset values.
  - *Why:* Omitting resets on payload flops reduces routing congestion, gate count, and dynamic power.
- **Clock generation**: NEVER generate gated or divided clocks using combinational gates (`wire clk_gated = clk & en`). Use dedicated Integrated Clock Gating (ICG) primitives or flip-flop clock-enables.
- **Multi-clock domains**: NEVER place multiple clock edges in a single `always_ff` (`@(posedge clk1 or posedge clk2)`). Each flop belongs to exactly one clock domain.
- **Clock Domain Crossing (CDC)**: NEVER cross multi-bit signals between asynchronous clocks using simple 2-FF synchronizers. Use Gray-code pointers, handshakes, or asynchronous FIFOs.

---

## 6. Parameters, Packages, & Reusability

- **`parameter` vs `localparam`**:
  - `parameter`: Module interface knobs meant to be overridden by parent instantiations. ALWAYS provide explicit type and width (`parameter int unsigned DATA_WIDTH = 32`).
  - `localparam`: Derived constants, internal limits, and state encodings. NEVER override from outside the module.
- **Macros (`` `define ``)**: NEVER use `` `define `` for bus widths, address offsets, or design constants.
  - Reserve `` `define `` strictly for header include guards and global compile switches (`` `ifdef SYNTHESIS ``).
  - All `.svh` files MUST use include guards: `<PROJECT>_<PATH>_<FILE>_SVH_`.
- **Packages**: Encapsulate shared `typedef struct`, `typedef enum`, and global constants in `_pkg.sv`. Import symbols explicitly at module scope (`import my_pkg::cfg_t;`). AVOID wildcard imports (`import my_pkg::*;`) in the global `$unit` scope.

---

## 7. Anti-Patterns & Prohibited Constructs

- **`#delay`**: NEVER use `#<delay>` in synthesizable RTL. Synthesis tools ignore delays, causing complete simulation-synthesis mismatches.
- **Internal Tri-States**: NEVER use `1'bz` or tri-state buses inside the ASIC/FPGA logic core. Use multiplexers. Tri-states are permitted only at physical chip pads.
- **Combinational loops**: NEVER write combinational feedback loops (`assign a = a ^ b`). Logic paths MUST be strictly acyclic.
- **`initial` for state**: NEVER rely on `initial` blocks to initialize synthesizable ASIC flip-flops (ASIC flops power up to indeterminate X). Use hardware reset.
- **Floating pins**: NEVER leave inputs unconnected. Tie unused inputs to `'0` or `'1'`. Unused outputs MUST be explicitly marked `.port()`.
- **Bit-select out of bounds**: Check array and vector index boundaries. Linters flag variable bit-selects that exceed vector bounds.

---

## 8. Lint Waivers & Assertions

- **Waivers**: NEVER apply blanket or directory-wide lint waivers. Every inline waiver MUST state: tool name, rule ID, physical justification, and author/date.
- **SVA in RTL**: Embed concurrent assertions (`assert property`) to validate interface protocols and microarchitectural invariants. Guard testbench/simulation-only assertions with `` `ifndef SYNTHESIS ``.

---

## Parting Words

BE CONSISTENT.

Look at the surrounding RTL before adding code. Match port grouping conventions, naming suffixes (`_q`/`_d`, `_n`), and signal alignments. RTL is physical silicon: prioritize deterministic synthesis, timing closure, and lint cleanliness over clever shorthand.