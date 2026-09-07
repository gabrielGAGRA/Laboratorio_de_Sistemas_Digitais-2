#!/usr/bin/env python3
"""Strict Verilog-2001 & Intel Cyclone V RTL Linter.

Enforces engineering standards documented in software-engineering-rules-verilog.md:
  - Verilog-2001 (IEEE Std 1364-2001) synthesizability
  - Cyclone V FPGA invariants (M10K block RAM inference, clock enables, GCLK)
  - Clean coding conventions, latch prevention, and legacy anti-pattern detection
  - Icarus Verilog (iverilog -Wall -g2001 -tnull) compiler elaboration
  - Optional Verilator (--lint-only -Wall) static analysis
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import List, Optional, Tuple


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
            Severity.ERROR: "\033[91m",   # Red
            Severity.WARNING: "\033[93m", # Yellow
            Severity.INFO: "\033[94m",    # Blue
        }
        reset = "\033[0m"
        bold = "\033[1m"
        sev_str = f"{color_map.get(self.severity, '')}{self.severity.value}{reset}"
        loc = f"{self.file_path}:{self.line_num}:{self.col_num}" if self.line_num > 0 else str(self.file_path)
        out = f"{bold}{loc}:{reset} [{sev_str}] {bold}({self.rule_id}){reset}: {self.message}"
        if self.snippet:
            out += f"\n    \033[90m{self.line_num} | \033[0m{self.snippet.strip()}"
        return out


def mask_comments_and_strings(source: str) -> str:
    """Masks comments and string literals with spaces, preserving line and column offsets."""
    chars = list(source)
    n = len(chars)
    i = 0

    while i < n:
        if i + 1 < n and chars[i] == "/" and chars[i + 1] == "/":
            chars[i] = " "
            chars[i + 1] = " "
            i += 2
            while i < n and chars[i] != "\n":
                chars[i] = " "
                i += 1
        elif i + 1 < n and chars[i] == "/" and chars[i + 1] == "*":
            chars[i] = " "
            chars[i + 1] = " "
            i += 2
            while i + 1 < n and not (chars[i] == "*" and chars[i + 1] == "/"):
                if chars[i] != "\n":
                    chars[i] = " "
                i += 1
            if i + 1 < n:
                chars[i] = " "
                chars[i + 1] = " "
                i += 2
        elif chars[i] == '"':
            chars[i] = " "
            i += 1
            while i < n and chars[i] != '"':
                if chars[i] == "\\":
                    chars[i] = " "
                    i += 1
                    if i < n and chars[i] != "\n":
                        chars[i] = " "
                elif chars[i] != "\n":
                    chars[i] = " "
                i += 1
            if i < n and chars[i] == '"':
                chars[i] = " "
                i += 1
        else:
            i += 1

    return "".join(chars)


class VerilogLinter:
    """Static and elaboration linter for Verilog-2001 and Cyclone V."""

    def __init__(self, run_iverilog: bool = True, run_verilator: bool = True):
        self.run_iverilog = run_iverilog and (shutil.which("iverilog") is not None)
        self.run_verilator = run_verilator and (shutil.which("verilator") is not None)

    def lint_file(self, file_path: Path) -> List[LintViolation]:
        violations: List[LintViolation] = []

        # 1. Extension check
        if file_path.suffix == ".sv":
            violations.append(
                LintViolation(
                    rule_id="FILE_EXT_SYSTEMVERILOG",
                    severity=Severity.ERROR,
                    file_path=file_path,
                    line_num=1,
                    col_num=1,
                    message="SystemVerilog extension (.sv) prohibited. Use .v for synthesizable Verilog-2001.",
                )
            )

        if file_path.suffix not in [".v", ".vh"]:
            return violations

        try:
            raw_source = file_path.read_text(encoding="utf-8", errors="replace")
        except Exception as e:
            violations.append(
                LintViolation(
                    rule_id="FILE_READ_ERROR",
                    severity=Severity.ERROR,
                    file_path=file_path,
                    line_num=0,
                    col_num=0,
                    message=f"Failed to read file: {e}",
                )
            )
            return violations

        lines = raw_source.splitlines()
        masked_source = mask_comments_and_strings(raw_source)
        masked_lines = masked_source.splitlines()

        # 2. File Ownership & Top/Bottom Directives
        self._check_file_structure(file_path, raw_source, masked_lines, lines, violations)

        # 3. SystemVerilog Prohibited Keywords
        self._check_sv_keywords(file_path, masked_lines, lines, violations)

        # 4. Procedural assignments & Anti-Patterns
        self._check_procedural_blocks(file_path, masked_lines, lines, violations)

        # 5. Instantiations & Ports
        self._check_instantiations_and_ports(file_path, masked_lines, lines, violations)

        # 6. Cyclone V Hardware Invariants (M10K RAM, Gated Clocks, Tri-states)
        self._check_cyclone_v_invariants(file_path, masked_lines, lines, violations)

        # 7. Icarus Verilog Elaboration Check
        if self.run_iverilog and file_path.suffix == ".v":
            self._run_iverilog_check(file_path, violations)

        # 8. Verilator Lint Check
        if self.run_verilator and file_path.suffix == ".v":
            self._run_verilator_check(file_path, violations)

        return violations

    def _check_file_structure(
        self,
        file_path: Path,
        raw_source: str,
        masked_lines: List[str],
        raw_lines: List[str],
        violations: List[LintViolation],
    ) -> None:
        """Verifies default_nettype directives and module naming match."""
        # Check `default_nettype none at top (before first module)
        has_default_nettype_none = False
        has_default_nettype_wire = False
        module_decl_line = None
        module_name = None

        mod_regex = re.compile(r"\bmodule\s+([a-zA-Z_0-9]+)\b")

        for idx, line in enumerate(masked_lines):
            line_num = idx + 1
            if "`default_nettype" in line:
                if "none" in line:
                    has_default_nettype_none = True
                elif "wire" in line:
                    has_default_nettype_wire = True

            match = mod_regex.search(line)
            if match and module_decl_line is None:
                module_decl_line = line_num
                module_name = match.group(1)

        # Directives check
        if not has_default_nettype_none:
            violations.append(
                LintViolation(
                    rule_id="DIRECTIVE_DEFAULT_NETTYPE_NONE",
                    severity=Severity.ERROR,
                    file_path=file_path,
                    line_num=1,
                    col_num=1,
                    message="Missing `default_nettype none at top of file. Required to prevent silent 1-bit wire inference.",
                )
            )

        if not has_default_nettype_wire:
            last_line = len(raw_lines) if raw_lines else 1
            violations.append(
                LintViolation(
                    rule_id="DIRECTIVE_DEFAULT_NETTYPE_WIRE",
                    severity=Severity.ERROR,
                    file_path=file_path,
                    line_num=last_line,
                    col_num=1,
                    message="Missing `default_nettype wire at end of file to restore default toolchain behavior.",
                )
            )

        # Module name matching filename (for .v synthesizable files)
        if file_path.suffix == ".v" and module_name is not None:
            expected_name = file_path.stem
            if module_name != expected_name:
                violations.append(
                    LintViolation(
                        rule_id="FILE_MODULE_NAME_MISMATCH",
                        severity=Severity.ERROR,
                        file_path=file_path,
                        line_num=module_decl_line or 1,
                        col_num=1,
                        message=f"Module name '{module_name}' does not match filename '{file_path.name}'.",
                        snippet=raw_lines[module_decl_line - 1] if module_decl_line else "",
                    )
                )

    def _check_sv_keywords(
        self,
        file_path: Path,
        masked_lines: List[str],
        raw_lines: List[str],
        violations: List[LintViolation],
    ) -> None:
        """Flags SystemVerilog keywords in Verilog-2001 RTL."""
        sv_keywords = [
            ("logic", r"\blogic\b"),
            ("always_ff", r"\balways_ff\b"),
            ("always_comb", r"\balways_comb\b"),
            ("always_latch", r"\balways_latch\b"),
            ("typedef", r"\btypedef\b"),
            ("enum", r"\benum\b"),
            ("package", r"\bpackage\b"),
            ("'0 or '1", r"(?<!\d)'[01]\b"),
        ]

        for idx, line in enumerate(masked_lines):
            line_num = idx + 1
            for name, pattern in sv_keywords:
                match = re.search(pattern, line)
                if match:
                    violations.append(
                        LintViolation(
                            rule_id="SV_KEYWORD_BANNED",
                            severity=Severity.ERROR,
                            file_path=file_path,
                            line_num=line_num,
                            col_num=match.start() + 1,
                            message=f"SystemVerilog construct '{name}' is not allowed in Verilog-2001 RTL.",
                            snippet=raw_lines[idx],
                        )
                    )

    def _check_procedural_blocks(
        self,
        file_path: Path,
        masked_lines: List[str],
        raw_lines: List[str],
        violations: List[LintViolation],
    ) -> None:
        """Inspects always blocks for procedural rules, anti-patterns, and latches."""
        current_block: Optional[str] = None  # 'sequential' | 'combinational'
        block_depth = 0
        in_always = False

        re_always = re.compile(r"\balways\s*@\s*(\([^)]*\)|\*)")
        re_fsm_param = re.compile(
            r"^\s*parameter\s+(?:(?:\[[^\]]+\]|\w+)\s+)?([A-Z0-9_]*(?:IDLE|WAIT|STATE|ST_|MODO|ESPERA|PROX|INIC|FIM)[A-Z0-9_]*)\s*="
        )

        for idx, line in enumerate(masked_lines):
            line_num = idx + 1

            # Ignore assign statements for procedural assignment checking
            is_assign = bool(re.search(r"^\s*assign\b", line))

            # Check FSM parameter vs localparam
            fsm_match = re_fsm_param.search(line)
            if fsm_match:
                violations.append(
                    LintViolation(
                        rule_id="FSM_PARAMETER_PROHIBITED",
                        severity=Severity.ERROR,
                        file_path=file_path,
                        line_num=line_num,
                        col_num=fsm_match.start() + 1,
                        message=f"FSM state/mode '{fsm_match.group(1)}' declared with 'parameter'. Use 'localparam [WIDTH-1:0]'.",
                        snippet=raw_lines[idx],
                    )
                )

            # Check delay #<delay>
            delay_match = re.search(r"#[0-9]+", line)
            if delay_match:
                violations.append(
                    LintViolation(
                        rule_id="DELAY_PROHIBITED",
                        severity=Severity.ERROR,
                        file_path=file_path,
                        line_num=line_num,
                        col_num=delay_match.start() + 1,
                        message="#delay statements are prohibited in synthesizable RTL.",
                        snippet=raw_lines[idx],
                    )
                )

            # Detect always header
            always_match = re_always.search(line)
            if always_match:
                sens = always_match.group(1).strip()
                in_always = True
                if "*" in sens:
                    current_block = "combinational"
                elif "posedge" in sens or "negedge" in sens:
                    current_block = "sequential"
                else:
                    current_block = "combinational"
                    violations.append(
                        LintViolation(
                            rule_id="MANUAL_SENSITIVITY_LIST",
                            severity=Severity.ERROR,
                            file_path=file_path,
                            line_num=line_num,
                            col_num=always_match.start() + 1,
                            message="Manual sensitivity list in combinational block. Use 'always @*' (or 'always @(*)').",
                            snippet=raw_lines[idx],
                        )
                    )

            # Track block depth if in an always block
            if in_always:
                begins = len(re.findall(r"\bbegin\b", line))
                ends = len(re.findall(r"\bend\b", line))
                block_depth += begins - ends
                if begins > 0 or block_depth > 0:
                    pass  # active block
                if block_depth <= 0 and (ends > 0 or ";" in line):
                    # Exited always block
                    in_always = False
                    current_block = None
                    block_depth = 0

            # Check redundant clock check anti-pattern: else if (clock)
            if current_block == "sequential" and not is_assign:
                red_clk = re.search(r"\belse\s+if\s*\(\s*(?:clk|clock)\s*\)", line)
                if red_clk:
                    violations.append(
                        LintViolation(
                            rule_id="ANTI_PATTERN_REDUNDANT_CLOCK_CHECK",
                            severity=Severity.ERROR,
                            file_path=file_path,
                            line_num=line_num,
                            col_num=red_clk.start() + 1,
                            message="Redundant 'else if (clock)' check inside edge-triggered always block.",
                            snippet=raw_lines[idx],
                        )
                    )

            # Check assignments inside blocks
            if current_block == "sequential" and not is_assign:
                if not re.search(r"\bfor\s*\(", line):
                    blk_match = re.search(r"(?<![=!<>])=(?![=])", line)
                    nonblk_match = re.search(r"<=", line)
                    if blk_match and not nonblk_match:
                        if re.search(r"\b\w+(?:\[[^\]]+\])?\s*=(?![=])", line):
                            violations.append(
                                LintViolation(
                                    rule_id="SEQUENTIAL_BLOCKING_ASSIGNMENT",
                                    severity=Severity.ERROR,
                                    file_path=file_path,
                                    line_num=line_num,
                                    col_num=blk_match.start() + 1,
                                    message="Blocking assignment (=) inside sequential always block. Use non-blocking (<=).",
                                    snippet=raw_lines[idx],
                                )
                            )

            elif current_block == "combinational" and not is_assign:
                nonblk_match = re.search(r"<=", line)
                if nonblk_match:
                    violations.append(
                        LintViolation(
                            rule_id="COMBINATIONAL_NONBLOCKING_ASSIGNMENT",
                            severity=Severity.ERROR,
                            file_path=file_path,
                            line_num=line_num,
                            col_num=nonblk_match.start() + 1,
                            message="Non-blocking assignment (<=) inside combinational always block. Use blocking (=).",
                            snippet=raw_lines[idx],
                        )
                    )

            if "endmodule" in line:
                current_block = None
                in_always = False
                block_depth = 0

    def _check_instantiations_and_ports(
        self,
        file_path: Path,
        masked_lines: List[str],
        raw_lines: List[str],
        violations: List[LintViolation],
    ) -> None:
        """Inspects submodule instantiations and port bindings."""
        # Regex to catch instantiation patterns:
        # module_name [#(..)] instance_name ( ... );
        source_text = "\n".join(masked_lines)

        # Match instantiations
        inst_pattern = re.compile(
            r"\b([a-zA-Z_0-9]+)\s*(?:#\s*\([^)]*\))?\s+([a-zA-Z_0-9]+)\s*\(([^;]*)\)\s*;",
            re.MULTILINE,
        )

        reserved_keywords = {
            "module", "always", "initial", "case", "casex", "casez",
            "if", "else", "assign", "begin", "end", "generate", "endgenerate",
            "function", "task"
        }

        for match in inst_pattern.finditer(source_text):
            mod_type = match.group(1)
            inst_name = match.group(2)
            port_list = match.group(3).strip()

            if mod_type in reserved_keywords or inst_name in reserved_keywords:
                continue

            # Calculate line number
            start_pos = match.start()
            line_num = source_text[:start_pos].count("\n") + 1

            # Check instance prefix u_ or u_cell_
            if not (inst_name.startswith("u_") or inst_name.startswith("u_cell_")):
                violations.append(
                    LintViolation(
                        rule_id="INSTANCE_NAME_PREFIX",
                        severity=Severity.ERROR,
                        file_path=file_path,
                        line_num=line_num,
                        col_num=1,
                        message=f"Submodule instance '{inst_name}' must be prefixed with 'u_' (e.g. 'u_{inst_name}').",
                        snippet=raw_lines[line_num - 1] if line_num <= len(raw_lines) else "",
                    )
                )

            # Check for positional instantiation
            # If ports are present, at least one .port(sig) must be used, and no unadorned signal names
            if port_list:
                has_named_ports = bool(re.search(r"\.\s*[a-zA-Z_0-9]+\s*\(", port_list))
                if not has_named_ports:
                    violations.append(
                        LintViolation(
                            rule_id="POSITIONAL_INSTANTIATION",
                            severity=Severity.ERROR,
                            file_path=file_path,
                            line_num=line_num,
                            col_num=1,
                            message=f"Positional port instantiation in '{inst_name}'. Named port binding (.port(sig)) is required.",
                            snippet=raw_lines[line_num - 1] if line_num <= len(raw_lines) else "",
                        )
                    )

    def _check_cyclone_v_invariants(
        self,
        file_path: Path,
        masked_lines: List[str],
        raw_lines: List[str],
        violations: List[LintViolation],
    ) -> None:
        """Inspects Cyclone V FPGA hardware rules (M10K RAM, Gated Clocks, Tri-states)."""
        # 1. Detect memory array declarations: reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
        mem_arrays = set()
        mem_decl_regex = re.compile(
            r"\breg\s+(?:\[[^\]]+\]\s+)?([a-zA-Z_0-9]+)\s*\[[^\]]+\]\s*;"
        )

        for line in masked_lines:
            match = mem_decl_regex.search(line)
            if match:
                mem_arrays.add(match.group(1))

        # Check for continuous assign or combinational read from memory array
        # e.g., assign q = mem[addr];
        for idx, line in enumerate(masked_lines):
            line_num = idx + 1
            for mem in mem_arrays:
                async_read_pattern = rf"\bassign\s+[^=]+=\s*{mem}\s*\["
                if re.search(async_read_pattern, line):
                    violations.append(
                        LintViolation(
                            rule_id="M10K_ASYNC_READ_PROHIBITED",
                            severity=Severity.ERROR,
                            file_path=file_path,
                            line_num=line_num,
                            col_num=1,
                            message=f"Asynchronous read on memory array '{mem}' (assign ... = {mem}[...]). "
                                    f"Cyclone V M10K blocks require synchronous read ('always @(posedge clock) q <= {mem}[addr]').",
                            snippet=raw_lines[idx],
                        )
                    )

            # Check gated clock: wire clk_gated = (clock|clk) & ...
            gated_clk_match = re.search(
                r"\b(?:assign\s+|wire\s+)[a-zA-Z_0-9]*clk[a-zA-Z_0-9]*\s*=\s*[^;]*\b(?:clk|clock)\s*&",
                line,
                re.IGNORECASE,
            )
            if gated_clk_match:
                violations.append(
                    LintViolation(
                        rule_id="CLOCK_GATING_LOGIC_PROHIBITED",
                        severity=Severity.ERROR,
                        file_path=file_path,
                        line_num=line_num,
                        col_num=gated_clk_match.start() + 1,
                        message="Logic-gated clock detected (clk & en). Use dedicated register clock enables (ena).",
                        snippet=raw_lines[idx],
                    )
                )

            # Check internal tri-states: 1'bz or 1'bZ
            tristate_match = re.search(r"1'[bB][zZ]", line)
            # Allow only if filename is top-level (contains 'top') or inout port
            if tristate_match and "top" not in file_path.stem.lower():
                violations.append(
                    LintViolation(
                        rule_id="INTERNAL_TRISTATE_PROHIBITED",
                        severity=Severity.ERROR,
                        file_path=file_path,
                        line_num=line_num,
                        col_num=tristate_match.start() + 1,
                        message="Internal tri-state (1'bz) prohibited in Cyclone V core logic. Use multiplexers.",
                        snippet=raw_lines[idx],
                    )
                )

    def _run_iverilog_check(self, file_path: Path, violations: List[LintViolation]) -> None:
        """Runs iverilog -Wall -g2001 -tnull as a compiler elaboration pre-flight check."""
        file_dir = str(file_path.parent)
        cmd = ["iverilog", "-Wall", "-g2001", "-tnull", "-y", file_dir, "-I", file_dir, str(file_path)]
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10)
            if res.returncode != 0 or res.stderr:
                # Parse iverilog errors and warnings: filename:line: message
                for err_line in res.stderr.splitlines():
                    err_line = err_line.strip()
                    if not err_line:
                        continue
                    # Match pattern: path/to/file.v:line: error/warning: message
                    match = re.match(r"^([^:]+):(\d+):\s*(error|warning)?\s*(.*)$", err_line, re.IGNORECASE)
                    if match:
                        _, line_str, err_type, msg = match.groups()
                        line_no = int(line_str)
                        is_warn = (err_type or "").lower() == "warning"
                        violations.append(
                            LintViolation(
                                rule_id="IVERILOG_COMPILER_WARNING" if is_warn else "IVERILOG_COMPILER_ERROR",
                                severity=Severity.WARNING if is_warn else Severity.ERROR,
                                file_path=file_path,
                                line_num=line_no,
                                col_num=1,
                                message=f"[iverilog] {msg or err_line}",
                            )
                        )
                    else:
                        violations.append(
                            LintViolation(
                                rule_id="IVERILOG_COMPILER_ERROR",
                                severity=Severity.ERROR,
                                file_path=file_path,
                                line_num=0,
                                col_num=0,
                                message=f"[iverilog] {err_line}",
                            )
                        )
        except Exception as e:
            violations.append(
                LintViolation(
                    rule_id="IVERILOG_EXEC_ERROR",
                    severity=Severity.WARNING,
                    file_path=file_path,
                    line_num=0,
                    col_num=0,
                    message=f"Could not execute iverilog: {e}",
                )
            )

    def _run_verilator_check(self, file_path: Path, violations: List[LintViolation]) -> None:
        """Runs verilator --lint-only -Wall when available."""
        cmd = ["verilator", "--lint-only", "-Wall", "+1364-2001ext+v", str(file_path)]
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10)
            if res.stderr:
                for line in res.stderr.splitlines():
                    line = line.strip()
                    if not line or line.startswith("%"):
                        # Extract %Error or %Warning
                        match = re.match(r"^%(Error|Warning)(?:-([A-Z0-9_]+))?:\s*([^:]+):(\d+):(?:\d+:)?\s*(.*)$", line)
                        if match:
                            sev, rule, _, line_no, msg = match.groups()
                            violations.append(
                                LintViolation(
                                    rule_id=f"VERILATOR_{rule or 'LINT'}",
                                    severity=Severity.ERROR if sev == "Error" else Severity.WARNING,
                                    file_path=file_path,
                                    line_num=int(line_no),
                                    col_num=1,
                                    message=f"[verilator] {msg}",
                                )
                            )
        except Exception:
            pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Strict Verilog-2001 & Cyclone V RTL Linter",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "targets",
        nargs="*",
        default=["."],
        help="Files or directories to lint",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Patterns or directory names to exclude (e.g. --exclude 'Lab 1 - Projeto Final')",
    )
    parser.add_argument(
        "--no-iverilog",
        action="store_true",
        help="Disable Icarus Verilog elaboration check",
    )
    parser.add_argument(
        "--no-verilator",
        action="store_true",
        help="Disable Verilator static analysis check",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        default=True,
        help="Fail (exit 1) on errors",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    linter = VerilogLinter(
        run_iverilog=not args.no_iverilog,
        run_verilator=not args.no_verilator,
    )

    # Collect files
    files_to_lint: List[Path] = []
    excludes = [re.compile(re.escape(exc)) for exc in args.exclude]

    for target in args.targets:
        t_path = Path(target).resolve()
        if t_path.is_file() and t_path.suffix in [".v", ".vh"]:
            files_to_lint.append(t_path)
        elif t_path.is_dir():
            for p in t_path.rglob("*.v"):
                files_to_lint.append(p)
            for p in t_path.rglob("*.vh"):
                files_to_lint.append(p)

    # Filter excludes
    filtered_files: List[Path] = []
    for f in files_to_lint:
        str_path = str(f)
        if any(exc.search(str_path) for exc in excludes):
            continue
        filtered_files.append(f)

    filtered_files = sorted(list(set(filtered_files)))

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

        if violations:
            for v in violations:
                print(v)
            print()

    # Summary
    print("-" * 60)
    status_color = "\033[92m" if total_errors == 0 else "\033[91m"
    status_text = "PASS" if total_errors == 0 else "FAIL"
    print(f"Result: {status_color}\033[1m{status_text}\033[0m ({total_errors} errors, {total_warnings} warnings)")

    if total_errors > 0 and args.strict:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
