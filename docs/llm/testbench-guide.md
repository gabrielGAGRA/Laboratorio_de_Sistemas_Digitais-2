# Testbench Verification & Simulation Guide

This guide establishes standards for writing deterministic, self-checking Verilog-2001 testbenches and executing simulations using Icarus Verilog or ModelSim.

---

## 1. Golden Rules of RTL Verification

1. **Self-Checking:** Testbenches MUST NOT require manual waveform inspection to determine success. Automated checks with conditional comparisons and an error counter MUST report `TEST PASSED` or `TEST FAILED`.
2. **Deterministic Termination:** Every testbench MUST end with `$finish`.
3. **Parameter Overrides for Speed:** In simulation, override physical timing delays (e.g., set `DEBOUNCE_TECLA = 5` instead of `100_000`) so tests finish in milliseconds rather than minutes.

---

## 2. Standard Testbench Template

```verilog
`timescale 1ns / 1ps

module tb_my_module;

    // 1. Clocks and Signals
    reg        clock;
    reg        reset;
    reg  [6:0] data_in;
    wire [6:0] data_out;
    integer    errors = 0;

    // 2. Clock Generation: 50 MHz (Period = 20ns -> Half-period = 10ns)
    always #10 clock = ~clock;

    // 3. Unit Under Test (UUT)
    my_module #(
        .PARAM_FAST_SIM (5)
    ) uut (
        .clock    (clock),
        .reset    (reset),
        .data_in  (data_in),
        .data_out (data_out)
    );

    // 4. Stimulus Sequence
    initial begin
        // Initialize inputs
        clock   = 1'b0;
        reset   = 1'b1;
        data_in = 7'd0;

        // Apply reset for 2 clock cycles
        #40;
        reset   = 1'b0;
        #20;

        // Test Scenario 1: Basic operation
        data_in = 7'd10;
        #20;
        if (data_out !== 7'd10) begin
            $display("[ERROR] %0t ns: data_out expected 10, got %d", $time, data_out);
            errors = errors + 1;
        end

        // Final Report
        #100;
        if (errors == 0) begin
            $display("========================================");
            $display("SUCCESS: ALL TESTBENCH CHECKS PASSED!");
            $display("========================================");
        end else begin
            $display("FAILURE: %0d error(s) detected!", errors);
        end
        $finish;
    end

endmodule
```

---

## 3. Simulation Toolchain & Commands

### A. Icarus Verilog (`iverilog` + `vvp`)
To compile and run from PowerShell or terminal:
```powershell
# Compile RTL + Testbench
iverilog -o sim.vvp my_module.v tb_my_module.v

# Execute simulation
vvp sim.vvp
```

### B. Waveform Dumping (for GTKWave or debugging)
To dump signals into a `.vcd` file when diagnosing a failing test:
```verilog
initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_my_module);
end
```
Then view with:
```bash
gtkwave waveform.vcd
```
