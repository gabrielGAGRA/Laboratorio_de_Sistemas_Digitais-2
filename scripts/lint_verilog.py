"""Strict Verilog-2001 & Intel Cyclone V RTL Linter.
  *. Tools:
     - Icarus Verilog (iverilog): Compiler elaboration pre-flight check
       (iverilog -Wall -g2001 -tnull -y <dir> -I <dir> <file>) to validate syntax,
       types, port connections, and undeclared signals.
     - Verilator: Static RTL analysis (verilator --lint-only -Wall +1364-2001ext+v)
       on synthesizable modules (skipped for testbench files).

  **. Linter Parameters:
     - Accepts files or directories (recursively scanning for .v and .vh).
     - --exclude: Substring or regex patterns to bypass legacy/unrelated dirs.
     - --no-iverilog: Disable Icarus Verilog compiler check.
     - --no-verilator: Disable Verilator static analysis check.
     - --strict: Return exit code 1 if any error violation occurs.

  1. Structural Rules (Verilog-2001):
     - FILE_EXT_SYSTEMVERILOG: Rejects SystemVerilog extensions (.sv); requires .v/.vh.
     - FILE_MODULE_NAME_MISMATCH: Module name must exactly match filename stem.
     - DIRECTIVE_DEFAULT_NETTYPE_NONE: Requires `default_nettype none at top and at end 
       of file to avoid implicit 1-bit wire inference on typos.
     - SV_KEYWORD_BANNED: Prohibits SystemVerilog keywords (logic, always_ff,
       always_comb, always_latch, typedef, enum, package, '0, '1).

  2. Synthesis Anti-Patterns:
     - FSM_PARAMETER_PROHIBITED: FSM states/modes must use 'localparam [W-1:0]',
       never 'parameter'.
     - DELAY_PROHIBITED: #delay statements are prohibited in synthesizable RTL
       (only available for testbench files *_tb.v / tb_*.v).
     - MANUAL_SENSITIVITY_LIST: Combinational always blocks must use 'always @*'
       or 'always @(*)'; manual sensitivity lists are prohibited in synthesizable RTL.
     - ANTI_PATTERN_REDUNDANT_CLOCK_CHECK: Flags redundant 'else if (clock)' checks
       inside edge-triggered always blocks.
     - SEQUENTIAL_BLOCKING_ASSIGNMENT: Sequential blocks must use non-blocking (<=)
       assignments; blocking (=) is prohibited.
     - COMBINATIONAL_NONBLOCKING_ASSIGNMENT: Combinational blocks must use blocking (=)
       assignments; non-blocking (<=) is prohibited.

  3. Submodule Instantiations:
     - INSTANCE_NAME_PREFIX: Submodule instances must be prefixed with 'u_' or
       primitive cells with 'u_cell_'.
     - POSITIONAL_INSTANTIATION: Positional port mapping is prohibited; explicit
       named port binding (.port(sig)) is strictly required.

  4. Intel Cyclone V Hardware Invariants:
     - M10K_ASYNC_READ_PROHIBITED: Asynchronous reads on memory arrays
       (assign data = mem[addr]) cannot map to Cyclone V M10K block RAM and exhaust
       LUTs. Enforces synchronous registered reads:
       always @(posedge clock) data <= mem[addr].
     - CLOCK_GATING_LOGIC_PROHIBITED: Logic-gated clocks (clk & en) violate dedicated
       Global Clock (GCLK) networks and induce skew; enforces register clock enables.
     - INTERNAL_TRISTATE_PROHIBITED: Internal tri-states (1'bz) cannot be synthesized
       inside Cyclone V FPGA logic fabric; multiplexers must be used instead.
       Allowed only in top-level chip wrappers.
"""

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import List, Optional, Pattern, Tuple



class Severity(Enum):
    ERROR = "ERROR"
    WARNING = "WARNING"
    INFO = "INFO"


@dataclass
class LintViolation:
    rule_id: str
    severity: Severity
    file_path: Path
    line_num: int
    col_num: int
    message: str
    snippet: str = ""

    def __str__(self) -> str:
        color_map = {
            Severity.ERROR: "\033[91m", # Red
            Severity.WARNING: "\033[93m", # Yellow
            Severity.INFO: "\033[94m", # Green
        }
        sev = f"{color_map.get(self.severity, '')}{self.severity.value}\033[0m"
        loc = f"{self.file_path}:{self.line_num}:{self.col_num}" if self.line_num > 0 else str(self.file_path)
        out = f"\033[1m{loc}:\033[0m [{sev}] \033[1m({self.rule_id})\033[0m: {self.message}"
        if self.snippet:
            out += f"\n    \033[90m{self.line_num} | \033[0m{self.snippet.strip()}"
        return out

# Função de ignorar comentários e strings
def mask_comments_and_strings(source: str) -> str:
    """Masks comments and strings with spaces, preserving line and column offsets."""
    def _repl(m):
        return re.sub(r"[^\r\n]", " ", m.group(0))

    return re.sub(r"//[^\r\n]*|/\*[\s\S]*?\*/|\"(?:\\.|[^\"\\\r\n])*\"", _repl, source)


# Variáveis de padrões pesquisados de violação
RE_MODULE = re.compile(r"\bmodule\s+([a-zA-Z_0-9]+)\b")
RE_FSM_PARAM = re.compile(
    r"^\s*parameter\s+(?:(?:\[[^\]]+\]|\w+)\s+)?([A-Z0-9_]*(?:IDLE|WAIT|STATE|ST_|MODO|ESPERA|PROX|INIC|FIM)[A-Z0-9_]*)\s*="
)
PARAM_EXCLUDE_SUFFIXES = (
    "_CYCLES", "_TICKS", "_TIMEOUT", "_WIDTH", "_MAX", "_MIN",
    "_DIV", "_MS", "_US", "_NS", "_HZ", "_CNT", "_COUNT", "_LIMIT", "_VAL"
)

RE_ALWAYS = re.compile(r"\balways\s*@\s*(\([^)]*\)|\*)")
RE_MEM_DECL = re.compile(r"\breg\s+(?:\[[^\]]+\]\s+)?([a-zA-Z_0-9]+)\s*\[[^\]]+\]\s*;")
RE_INST = re.compile(
    r"\b([a-zA-Z_0-9]+)\s*(?:#\s*\([^)]*\))?\s+([a-zA-Z_0-9]+)\s*\(([^;]*)\)\s*;",
    re.MULTILINE,
)
RE_GATED_CLK = re.compile(
    r"\b(?:assign\s+|wire\s+)[a-zA-Z_0-9]*clk[a-zA-Z_0-9]*\s*=\s*[^;]*(?:\b(?:clk|clock)\b\s*&|&\s*\b(?:clk|clock)\b)",
    re.IGNORECASE,
)
RE_ASSIGN = re.compile(r"^\s*assign\b")
RE_DELAY = re.compile(r"#[0-9]+")
RE_REDUNDANT_CLK = re.compile(r"\belse\s+if\s*\(\s*(?:clk|clock)\s*\)")
RE_BLOCKING = re.compile(r"(?<![=!<>])=(?![=])")
RE_NONBLOCKING = re.compile(r"<=")
RE_TRISTATE = re.compile(r"1'[bB][zZ]")

SV_KEYWORDS: Tuple[Tuple[str, Pattern], ...] = (
    ("logic", re.compile(r"\blogic\b")),
    ("always_ff", re.compile(r"\balways_ff\b")),
    ("always_comb", re.compile(r"\balways_comb\b")),
    ("always_latch", re.compile(r"\balways_latch\b")),
    ("typedef", re.compile(r"\btypedef\b")),
    ("enum", re.compile(r"\benum\b")),
    ("package", re.compile(r"\bpackage\b")),
    ("interface", re.compile(r"\binterface\b")),
    ("'0 or '1", re.compile(r"(?<!\d)'[01]\b")),
)

RESERVED_KEYWORDS = {
    "module", "always", "initial", "case", "casex", "casez",
    "if", "else", "assign", "begin", "end", "generate", "endgenerate",
    "function", "task",
}

PRIMITIVE_GATES = {
    "and", "nand", "or", "nor", "xor", "xnor", "buf", "not",
    "bufif0", "bufif1", "notif0", "notif1",
}

FATAL_VERILATOR_RULES = {
    "LATCH",
    "WIDTH",
    "CASEINCOMPLETE",
    "COMBDLY",
    "UNDRIVEN",
    "MULTIDRIVEN",
    "ALWCOMBORDER",
}


class VerilogLinter:
    """Static and elaboration linter for Verilog-2001 and Cyclone V."""

    def __init__(self, run_iverilog: bool = True, run_verilator: bool = True):
        self.run_iverilog = run_iverilog and (shutil.which("iverilog") is not None)
        self.run_verilator = run_verilator and (shutil.which("verilator") is not None)

    def _add(
        self,
        violations: List[LintViolation],
        rule_id: str,
        path: Path,
        line: int,
        col: int,
        msg: str,
        snippet: str = "",
        severity: Severity = Severity.ERROR,
    ) -> None:
        violations.append(LintViolation(rule_id, severity, path, line, col, msg, snippet))

    def lint_file(self, file_path: Path) -> List[LintViolation]:
        violations: List[LintViolation] = []

        if file_path.suffix == ".sv":
            self._add(
                violations,
                "FILE_EXT_SYSTEMVERILOG",
                file_path,
                1,
                1,
                "SystemVerilog extension (.sv) prohibited. Use .v for synthesizable Verilog-2001.",
            )
            return violations

        if file_path.suffix not in [".v", ".vh"]:
            return violations

        try:
            raw_source = file_path.read_text(encoding="utf-8", errors="replace")
        except Exception as e:
            self._add(violations, "FILE_READ_ERROR", file_path, 0, 0, f"Failed to read file: {e}")
            return violations

        lines = raw_source.splitlines()
        masked_lines = mask_comments_and_strings(raw_source).splitlines()
        is_tb = file_path.stem.lower().startswith("tb_") or file_path.stem.lower().endswith("_tb")

        self._check_file_structure(file_path, masked_lines, lines, violations)
        self._check_sv_keywords(file_path, masked_lines, lines, violations)
        self._check_procedural_blocks(file_path, masked_lines, lines, violations, is_tb)
        self._check_instantiations_and_ports(file_path, masked_lines, lines, violations, is_tb)
        self._check_cyclone_v_invariants(file_path, masked_lines, lines, violations)

        if file_path.suffix == ".v":
            if self.run_iverilog:
                self._run_iverilog_check(file_path, violations)
            if self.run_verilator and not is_tb:
                self._run_verilator_check(file_path, violations)

        return violations

    def _check_file_structure(
        self,
        file_path: Path,
        masked_lines: List[str],
        raw_lines: List[str],
        violations: List[LintViolation],
    ) -> None:
        has_nettype_none = False
        nettype_none_line = None
        has_nettype_wire = False
        nettype_wire_line = None
        module_lines: List[Tuple[int, str]] = []
        last_endmodule_line = None

        for idx, line in enumerate(masked_lines):
            line_num = idx + 1
            if "`default_nettype" in line:
                if "none" in line:
                    has_nettype_none = True
                    if nettype_none_line is None:
                        nettype_none_line = line_num
                elif "wire" in line:
                    has_nettype_wire = True
                    nettype_wire_line = line_num

            match = RE_MODULE.search(line)
            if match:
                module_lines.append((line_num, match.group(1)))

            if "endmodule" in line:
                last_endmodule_line = line_num

        first_mod_line = module_lines[0][0] if module_lines else (len(raw_lines) + 1)

        if not has_nettype_none or (nettype_none_line and nettype_none_line > first_mod_line):
            self._add(
                violations,
                "DIRECTIVE_DEFAULT_NETTYPE_NONE",
                file_path,
                nettype_none_line or 1,
                1,
                "Missing `default_nettype none at top of file (must precede module declarations) to prevent silent 1-bit wire inference.",
            )

        if file_path.suffix == ".v":
            if not has_nettype_wire or (last_endmodule_line and nettype_wire_line and nettype_wire_line < last_endmodule_line):
                last_line = len(raw_lines) or 1
                self._add(
                    violations,
                    "DIRECTIVE_DEFAULT_NETTYPE_WIRE",
                    file_path,
                    nettype_wire_line or last_line,
                    1,
                    "Missing `default_nettype wire at end of file (must follow endmodule) to restore default toolchain behavior.",
                )

            if len(module_lines) > 1:
                mod_names = ", ".join(f"'{m[1]}'" for m in module_lines)
                self._add(
                    violations,
                    "FILE_MULTIPLE_MODULES",
                    file_path,
                    module_lines[1][0],
                    1,
                    f"File contains multiple modules ({mod_names}). Exactly one module per file matching filename stem is required.",
                    raw_lines[module_lines[1][0] - 1] if module_lines[1][0] <= len(raw_lines) else "",
                )
            elif len(module_lines) == 1:
                mod_line, mod_name = module_lines[0]
                if mod_name != file_path.stem:
                    self._add(
                        violations,
                        "FILE_MODULE_NAME_MISMATCH",
                        file_path,
                        mod_line,
                        1,
                        f"Module name '{mod_name}' does not match filename '{file_path.name}'.",
                        raw_lines[mod_line - 1] if mod_line <= len(raw_lines) else "",
                    )

    def _check_sv_keywords(
        self,
        file_path: Path,
        masked_lines: List[str],
        raw_lines: List[str],
        violations: List[LintViolation],
    ) -> None:
        for idx, line in enumerate(masked_lines):
            for name, pattern in SV_KEYWORDS:
                match = pattern.search(line)
                if match:
                    self._add(
                        violations,
                        "SV_KEYWORD_BANNED",
                        file_path,
                        idx + 1,
                        match.start() + 1,
                        f"SystemVerilog construct '{name}' is not allowed in Verilog-2001 RTL.",
                        raw_lines[idx],
                    )

    def _check_procedural_blocks(
        self,
        file_path: Path,
        masked_lines: List[str],
        raw_lines: List[str],
        violations: List[LintViolation],
        is_tb: bool = False,
    ) -> None:
        current_block: Optional[str] = None
        block_depth = 0
        in_always = False
        in_always_header = False
        always_header_buf = ""
        always_header_line = 1

        for idx, line in enumerate(masked_lines):
            line_num = idx + 1
            is_assign = bool(RE_ASSIGN.search(line))

            fsm_match = RE_FSM_PARAM.search(line)
            if fsm_match:
                param_name = fsm_match.group(1)
                if not any(param_name.endswith(suf) for suf in PARAM_EXCLUDE_SUFFIXES):
                    self._add(
                        violations,
                        "FSM_PARAMETER_PROHIBITED",
                        file_path,
                        line_num,
                        fsm_match.start() + 1,
                        f"FSM state/mode '{param_name}' declared with 'parameter'. Use 'localparam [WIDTH-1:0]'.",
                        raw_lines[idx],
                    )

            if not is_tb:
                delay_match = RE_DELAY.search(line)
                if delay_match:
                    self._add(
                        violations,
                        "DELAY_PROHIBITED",
                        file_path,
                        line_num,
                        delay_match.start() + 1,
                        "#delay statements are prohibited in synthesizable RTL.",
                        raw_lines[idx],
                    )

            if not in_always_header:
                always_match = RE_ALWAYS.search(line)
                if always_match:
                    sens = always_match.group(1).strip()
                    in_always = True
                    if "*" in sens:
                        current_block = "combinational"
                    elif "posedge" in sens or "negedge" in sens:
                        current_block = "sequential"
                    else:
                        current_block = "combinational"
                        self._add(
                            violations,
                            "MANUAL_SENSITIVITY_LIST",
                            file_path,
                            line_num,
                            always_match.start() + 1,
                            "Manual sensitivity list in combinational block. Use 'always @*' (or 'always @(*)').",
                            raw_lines[idx],
                        )
                elif re.search(r"\balways\s*@", line):
                    in_always_header = True
                    always_header_buf = line
                    always_header_line = line_num
            else:
                always_header_buf += " " + line
                if ")" in line:
                    in_always_header = False
                    in_always = True
                    m_sens = re.search(r"\balways\s*@\s*(\([^)]*\)|\*)", always_header_buf)
                    if m_sens:
                        sens = m_sens.group(1).strip()
                        if "*" in sens:
                            current_block = "combinational"
                        elif "posedge" in sens or "negedge" in sens:
                            current_block = "sequential"
                        else:
                            current_block = "combinational"
                            self._add(
                                violations,
                                "MANUAL_SENSITIVITY_LIST",
                                file_path,
                                always_header_line,
                                1,
                                "Manual sensitivity list in combinational block. Use 'always @*' (or 'always @(*)').",
                                raw_lines[always_header_line - 1],
                            )

            begins = len(re.findall(r"\bbegin\b", line))
            ends = len(re.findall(r"\bend\b", line))
            if in_always:
                block_depth += begins - ends

            if current_block == "sequential" and not is_assign:
                red_clk = RE_REDUNDANT_CLK.search(line)
                if red_clk:
                    self._add(
                        violations,
                        "ANTI_PATTERN_REDUNDANT_CLOCK_CHECK",
                        file_path,
                        line_num,
                        red_clk.start() + 1,
                        "Redundant 'else if (clock)' check inside edge-triggered always block.",
                        raw_lines[idx],
                    )

                if not re.search(r"\bfor\s*\(", line):
                    blk = RE_BLOCKING.search(line)
                    if blk and not re.search(r"\b(?:if|while)\s*\(.*=", line):
                        if re.search(r"(?:^\s*|\b(?:begin|else)\s+)(?:[a-zA-Z_0-9]+(?:\s*\[[^\]]+\])?|\{[^}]+\})\s*=(?![=])", line):
                            self._add(
                                violations,
                                "SEQUENTIAL_BLOCKING_ASSIGNMENT",
                                file_path,
                                line_num,
                                blk.start() + 1,
                                "Blocking assignment (=) inside sequential always block. Use non-blocking (<=).",
                                raw_lines[idx],
                            )

            elif current_block == "combinational" and not is_assign:
                if not re.search(r"\b(?:if|while)\s*\(.*<=", line):
                    nonblk = re.search(r"(?:^\s*|\b(?:begin|else)\s+)(?:[a-zA-Z_0-9]+(?:\s*\[[^\]]+\])?|\{[^}]+\})\s*<=(?![=])", line)
                    if nonblk:
                        self._add(
                            violations,
                            "COMBINATIONAL_NONBLOCKING_ASSIGNMENT",
                            file_path,
                            line_num,
                            nonblk.start() + 1,
                            "Non-blocking assignment (<=) inside combinational always block. Use blocking (=).",
                            raw_lines[idx],
                        )

            if in_always:
                if block_depth <= 0 and (ends > 0 or (block_depth == 0 and begins == 0 and ";" in line)):
                    in_always = False
                    current_block = None
                    block_depth = 0

            if "endmodule" in line:
                current_block = None
                in_always = False
                in_always_header = False
                block_depth = 0

    def _check_instantiations_and_ports(
        self,
        file_path: Path,
        masked_lines: List[str],
        raw_lines: List[str],
        violations: List[LintViolation],
        is_tb: bool = False,
    ) -> None:
        source_text = "\n".join(masked_lines)

        for match in RE_INST.finditer(source_text):
            mod_type, inst_name, port_list = match.group(1), match.group(2), match.group(3).strip()
            if mod_type in RESERVED_KEYWORDS or inst_name in RESERVED_KEYWORDS:
                continue

            line_num = source_text[: match.start()].count("\n") + 1
            snippet = raw_lines[line_num - 1] if line_num <= len(raw_lines) else ""

            is_valid_prefix = inst_name.startswith("u_") or inst_name.startswith("u_cell_")
            if is_tb:
                is_valid_prefix = is_valid_prefix or inst_name in ("uut", "dut", "u_uut", "u_dut")

            if not is_valid_prefix:
                self._add(
                    violations,
                    "INSTANCE_NAME_PREFIX",
                    file_path,
                    line_num,
                    1,
                    f"Submodule instance '{inst_name}' must be prefixed with 'u_' (e.g. 'u_{inst_name}').",
                    snippet,
                )

            if mod_type not in PRIMITIVE_GATES and port_list and not re.search(r"\.\s*[a-zA-Z_0-9]+\s*\(", port_list):
                self._add(
                    violations,
                    "POSITIONAL_INSTANTIATION",
                    file_path,
                    line_num,
                    1,
                    f"Positional port instantiation in '{inst_name}'. Named port binding (.port(sig)) is required.",
                    snippet,
                )

    def _check_cyclone_v_invariants(
        self,
        file_path: Path,
        masked_lines: List[str],
        raw_lines: List[str],
        violations: List[LintViolation],
    ) -> None:
        mem_arrays = {m.group(1) for line in masked_lines for m in [RE_MEM_DECL.search(line)] if m}
        stem_lower = file_path.stem.lower()
        is_top = (
            stem_lower == "top"
            or stem_lower.endswith("_top")
            or stem_lower.startswith("top_")
            or any(re.search(r"\binout\b", l) for l in masked_lines)
        )

        in_comb = False
        for idx, line in enumerate(masked_lines):
            line_num = idx + 1

            if re.search(r"\balways\s*@\s*(\*|\(\s*\*\s*\))", line):
                in_comb = True
            elif re.search(r"\balways\s*@\s*\(", line):
                in_comb = False
            if "endmodule" in line:
                in_comb = False

            for mem in mem_arrays:
                is_async_assign = bool(re.search(rf"\bassign\s+[^=]+=\s*{mem}\s*\[", line))
                is_async_comb = in_comb and bool(re.search(rf"\b\w+\s*=\s*{mem}\s*\[", line))
                if is_async_assign or is_async_comb:
                    self._add(
                        violations,
                        "M10K_ASYNC_READ_PROHIBITED",
                        file_path,
                        line_num,
                        1,
                        f"Asynchronous read on memory array '{mem}'. "
                        f"Cyclone V M10K blocks require synchronous read ('always @(posedge clock) q <= {mem}[addr]').",
                        raw_lines[idx],
                    )

            gated_clk = RE_GATED_CLK.search(line)
            if gated_clk:
                self._add(
                    violations,
                    "CLOCK_GATING_LOGIC_PROHIBITED",
                    file_path,
                    line_num,
                    gated_clk.start() + 1,
                    "Logic-gated clock detected (clk & en). Use dedicated register clock enables (ena).",
                    raw_lines[idx],
                )

            tristate = RE_TRISTATE.search(line)
            if tristate and not is_top:
                self._add(
                    violations,
                    "INTERNAL_TRISTATE_PROHIBITED",
                    file_path,
                    line_num,
                    tristate.start() + 1,
                    "Internal tri-state (1'bz) prohibited in Cyclone V core logic. Use multiplexers.",
                    raw_lines[idx],
                )

    def _run_iverilog_check(self, file_path: Path, violations: List[LintViolation]) -> None:
        file_dir = str(file_path.parent)
        cmd = ["iverilog", "-Wall", "-g2001", "-tnull", "-y", file_dir, "-I", file_dir, str(file_path)]
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10)
            if res.returncode != 0 or res.stderr:
                for err_line in res.stderr.splitlines():
                    err_line = err_line.strip()
                    if not err_line:
                        continue
                    m = re.match(r"^([^:]+):(\d+):\s*(error|warning)?\s*(.*)$", err_line, re.IGNORECASE)
                    if m:
                        _, line_str, err_type, msg = m.groups()
                        is_note = msg.startswith("...") or (err_type or "").startswith("...")
                        is_warn = (err_type or "").lower() == "warning" or is_note
                        self._add(
                            violations,
                            "IVERILOG_COMPILER_WARNING" if is_warn else "IVERILOG_COMPILER_ERROR",
                            file_path,
                            int(line_str),
                            1,
                            f"[iverilog] {msg or err_line}",
                            severity=Severity.WARNING if is_warn else Severity.ERROR,
                        )
                    else:
                        is_note = err_line.startswith("...") or "timescale" in err_line.lower()
                        self._add(
                            violations,
                            "IVERILOG_COMPILER_WARNING" if is_note else "IVERILOG_COMPILER_ERROR",
                            file_path,
                            0,
                            0,
                            f"[iverilog] {err_line}",
                            severity=Severity.WARNING if is_note else Severity.ERROR,
                        )
        except Exception as e:
            self._add(violations, "IVERILOG_EXEC_ERROR", file_path, 0, 0, f"Could not execute iverilog: {e}", severity=Severity.WARNING)

    def _run_verilator_check(self, file_path: Path, violations: List[LintViolation]) -> None:
        file_dir = str(file_path.parent)
        cmd = [
            "verilator",
            "--lint-only",
            "-Wall",
            "+1364-2001ext+v",
            "-I" + file_dir,
            "-y",
            file_dir,
            "-Wno-PINCONNECTEMPTY",
            "-Wno-UNUSEDSIGNAL",
            "-Wno-EOFNEWLINE",
            "-Werror-LATCH",
            "-Werror-CASEINCOMPLETE",
            "-Werror-COMBDLY",
            str(file_path),
        ]
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10)
            if res.stderr:
                for line in res.stderr.splitlines():
                    line = line.strip()
                    if not line or line.startswith("%"):
                        m = re.match(r"^%(Error|Warning)(?:-([A-Z0-9_]+))?:\s*([^:]+):(\d+):(?:\d+:)?\s*(.*)$", line)
                        if m:
                            sev, rule, _, line_no, msg = m.groups()
                            rule_name = rule or "LINT"
                            is_err = (sev == "Error") or (rule_name in FATAL_VERILATOR_RULES)
                            self._add(
                                violations,
                                f"VERILATOR_{rule_name}",
                                file_path,
                                int(line_no),
                                1,
                                f"[verilator] {msg}",
                                severity=Severity.ERROR if is_err else Severity.WARNING,
                            )
        except Exception:
            pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Strict Verilog-2001 & Cyclone V RTL Linter",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("targets", nargs="*", default=["."], help="Files or directories to lint")
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Patterns or directory names to exclude (e.g. --exclude 'Lab 1 - Projeto Final')",
    )
    parser.add_argument("--no-iverilog", action="store_true", help="Disable Icarus Verilog elaboration check")
    parser.add_argument("--no-verilator", action="store_true", help="Disable Verilator static analysis check")
    parser.add_argument("--strict", action="store_true", default=True, help="Fail (exit 1) on errors")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    linter = VerilogLinter(
        run_iverilog=not args.no_iverilog,
        run_verilator=not args.no_verilator,
    )

    targets: List[Path] = []
    excludes = [re.compile(re.escape(exc)) for exc in args.exclude]
    valid_extensions = {".v", ".vh", ".sv"}

    for target in args.targets:
        t_path = Path(target).resolve()
        if t_path.is_file() and t_path.suffix in valid_extensions:
            targets.append(t_path)
        elif t_path.is_dir():
            targets.extend(p for p in t_path.rglob("*") if p.suffix in valid_extensions)

    filtered_files = sorted({f for f in targets if not any(exc.search(str(f)) for exc in excludes)})

    if not filtered_files:
        print("No Verilog files found to lint.")
        return 0

    print(f"\033[1mScanning {len(filtered_files)} file(s) for Verilog-2001 & Cyclone V compliance...\033[0m\n")

    total_errors = 0
    total_warnings = 0

    for file_path in filtered_files:
        violations = linter.lint_file(file_path)
        errors = [v for v in violations if v.severity == Severity.ERROR]
        warnings = [v for v in violations if v.severity == Severity.WARNING]
        total_errors += len(errors)
        total_warnings += len(warnings)

        for v in violations:
            print(v)
        if violations:
            print()

    print("-" * 60)
    status_color = "\033[92m" if total_errors == 0 else "\033[91m"
    status_text = "PASS" if total_errors == 0 else "FAIL"
    print(f"Result: {status_color}\033[1m{status_text}\033[0m ({total_errors} errors, {total_warnings} warnings)")

    return 1 if total_errors > 0 and args.strict else 0


if __name__ == "__main__":
    sys.exit(main())
