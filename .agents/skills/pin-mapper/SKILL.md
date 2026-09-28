---
name: pin-mapper
description: >-
  Maps top-level Verilog ports or node names to physical FPGA pins on the DE0-CV.
---

# DE0-CV Pinout Mapper

---

## 1. Database Resource
A CSV file contains all physical pin definitions:
- [de0_cv_pins.csv](./resources/de0_cv_pins.csv) (`signal_resource,fpga_pin`)

---

## 2. Usage

### From a Top-Level Verilog File
Automatically parses ports, expands buses (`hex0[0..6]`, `ledr[0..9]`), sorts alphabetically, and prints only the `PIN_...` column:

```bash
python .agents/skills/pin-mapper/scripts/pin_mapper.py \
  --top path/to/top_module.v \
  --map "reset=SW0,clock=CLOCK_50,var1=GPIO_1_D1,var2=GPIO_1_D3"
```