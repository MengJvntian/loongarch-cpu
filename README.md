# LoongArch 5-Stage Pipeline CPU

## 🚀 Overview
A 5-stage pipeline CPU designed based on LoongArch32 ISA, supporting basic instruction execution and hazard handling.

## 🧠 Architecture
- IF / ID / EX / MEM / WB pipeline
- Data forwarding
- Hazard detection (Load-Use stall)
- Branch prediction (BPU)
- 2-way set associative ICache

## ⚙️ Features
- Supports 46 instructions
- Frequency up to 155MHz
- Pipeline optimization with reduced stalls
- Modular ALU design

## 🔧 Tech Stack
- Verilog
- FPGA
