# 32-bit RISC-V RV32I Single-Cycle Processor

## Overview

This project implements a **32-bit RISC-V processor based on the RV32I instruction-set architecture using Verilog HDL**.

The processor follows a **single-cycle datapath organization**, where instruction fetch, instruction decode, execution, memory access, and write-back are completed within one clock period.

The design was developed and verified using **Xilinx Vivado** and is targeted toward FPGA implementation.

---

## Features

* 32-bit RISC-V RV32I processor
* Single-cycle datapath architecture
* Verilog HDL RTL implementation
* 32 general-purpose registers
* Dedicated zero register (`x0`)
* Separate instruction and data memories
* 32-bit ALU
* Immediate generation and sign extension
* Branch and jump address generation
* Instruction decoding and control-signal generation
* Load and store operations
* Conditional branch operations
* JALR instruction support
* RTL simulation and waveform verification
* FPGA-oriented implementation using Xilinx Vivado

---

## Processor Architecture

The processor consists of the following major components:

```text
                    ┌──────────────────┐
                    │ Program Counter  │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ Instruction      │
                    │ Memory           │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ Instruction      │
                    │ Decode / Control │
                    └───────┬──────────┘
                            │
             ┌──────────────┴──────────────┐
             ▼                             ▼
     ┌────────────────┐          ┌─────────────────┐
     │ Register File  │          │ Immediate       │
     │ 32 × 32-bit    │          │ Extension Unit  │
     └───────┬────────┘          └────────┬────────┘
             │                            │
             └──────────────┬─────────────┘
                            ▼
                     ┌────────────┐
                     │    ALU     │
                     └─────┬──────┘
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
      ┌─────────────┐             ┌─────────────┐
      │ Data Memory │             │ Next-PC     │
      │ 256 × 32-bit│             │ Generation  │
      └──────┬──────┘             └──────┬──────┘
             │                           │
             └─────────────┬─────────────┘
                           ▼
                    ┌──────────────┐
                    │ Result MUX   │
                    └──────┬───────┘
                           │
                           ▼
                    Register Write
```

The processor uses the familiar:

```text
IF → ID → EX → MEM → WB
```

instruction flow. Since this is a single-cycle processor, these functions are completed as one instruction flow within a single clock period rather than being separate pipeline stages.

---

# Main Modules

## 1. Program Counter

The Program Counter (PC) stores the address of the current instruction.

For normal sequential execution, the PC advances by 4 bytes because the processor uses 32-bit instructions.

```text
PC_next = PC + 4
```

The design also supports branch and JALR target selection.

---

## 2. Instruction Memory

The instruction memory stores the processor instructions.

* 256 words
* 32 bits per word
* Word-aligned addressing
* Address bits `[9:2]` are used as the memory index

This provides:

```text
256 × 32-bit words
= 1024 bytes
= 1 KB
```

---

## 3. Register File

The register file contains:

```text
32 registers × 32 bits
```

It provides:

* Two source-register read ports
* One destination-register write port

The register `x0` is permanently maintained as zero.

Writes to register `x0` are suppressed.

---

## 4. Immediate Extension Unit

The immediate-extension unit extracts immediate values from different RISC-V instruction formats and sign-extends them to 32 bits.

The implementation supports:

* I-type immediate
* S-type immediate
* B-type immediate

---

## 5. Control Unit

The control unit decodes the instruction opcode and generates the control signals required by the datapath.

Important control signals include:

```text
PCSrc
ALUSrc
ResultSrc
ImmSrc
RegWr
MemWrite
MemRead
```

These signals determine:

* ALU operand selection
* Immediate format
* Register write operation
* Memory access
* Write-back source
* Next PC selection

---

## 6. ALU

The Arithmetic Logic Unit performs the arithmetic, logical, shift, and comparison operations.

Supported ALU operations include:

```text
ADD
SUB
SLL
SLT
SLTU
XOR
SRL
SRA
OR
AND
```

The ALU is also used to calculate effective addresses for load and store instructions.

---

## 7. Data Memory

The data memory contains:

```text
256 × 32-bit words
```

The processor supports:

* `LW` — Load Word
* `SW` — Store Word

The design uses synchronous memory writes and combinational memory reads.

---

## 8. Branch and Jump Logic

The processor contains dedicated logic for calculating branch and jump targets.

The PC multiplexer selects between:

```text
PC + 4
Branch Target
JALR Target
```

This allows the processor to execute sequential instructions as well as conditional branches and jumps.

---

# Supported Instructions

The documented processor supports the following instruction categories:

| Instruction Type | Supported Instructions                               |
| ---------------- | ---------------------------------------------------- |
| R-Type           | ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND     |
| I-Type ALU       | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI |
| Load             | LW                                                   |
| Store            | SW                                                   |
| Branch           | BEQ, BNE, BLT, BGE, BLTU, BGEU                       |
| Jump             | JALR                                                 |

---

# Instruction Execution

### R-Type Example

```text
ADD x3, x1, x2
```

The processor:

1. Fetches the instruction.
2. Decodes the instruction fields.
3. Reads `x1` and `x2`.
4. Selects the register operands.
5. Performs addition in the ALU.
6. Writes the result to `x3`.
7. Advances the PC to `PC + 4`.

---

### Load Example

```text
LW x11, 0(x0)
```

The processor:

```text
Register → ALU Address Calculation
              ↓
         Data Memory
              ↓
          Result MUX
              ↓
        Register File
```

The loaded data is written into `x11`.

---

### Store Example

```text
SW x1, 0(x0)
```

The ALU calculates the effective memory address and the value from `x1` is written into data memory.

---

### Branch Example

```text
BEQ x1, x1, +8
```

The processor compares the two source registers.

If the condition is true:

```text
PC = Branch Target
```

Otherwise:

```text
PC = PC + 4
```

---

# Memory Organization

Both instruction and data memories are implemented as:

```text
256 words × 32 bits
```

The memory index uses:

```text
Address[9:2]
```

Example:

```text
Address 0x000 → Memory[0]
Address 0x004 → Memory[1]
Address 0x008 → Memory[2]
Address 0x00C → Memory[3]
Address 0x010 → Memory[4]
```

The simplified memory model is word-oriented.

---

# Verification and Testbench

The processor was verified using a Verilog simulation testbench.

The testbench performs the following operations:

1. Generates a periodic clock.
2. Applies reset.
3. Preloads instruction memory.
4. Executes the programmed instruction sequence.
5. Monitors the processor signals.
6. Observes the PC, instruction, ALU output, register values, and memory activity.
7. Verifies arithmetic, logical, memory, branch, and control-flow operations.

The reference simulation uses a:

```text
Clock Period = 10 ns
Clock Frequency = 100 MHz
```

---

# Representative Test Cases

The verification includes representative instructions such as:

```text
SW x1, 0(x0)
LW x11, 0(x0)
BEQ x1, x1, +8
BNE x1, x2, +2
BLT x11, x2, +2
BGE x2, x1, +8
```

These tests verify:

* Effective-address generation
* Data-memory write
* Data-memory read
* Register write-back
* Conditional branches
* ALU comparison operations

---

# Simulation Results

The design was simulated using Vivado.

The simulation evidence includes:

* RTL schematic
* Simulation waveform
* Simulator console output

The waveform allows observation of:

```text
PC
Instruction
ALU Output
Next PC
Register Values
Write-back Result
Memory Activity
```

The simulation demonstrates sequential instruction execution, arithmetic and logical operations, memory operations, and control-flow behavior.

---

# FPGA Implementation

The project is targeted for FPGA implementation using:

```text
Tool   : Xilinx Vivado 2024.1
Device : xc7a100tcsg324-1
HDL    : Verilog
Architecture : 32-bit RISC-V Single-Cycle
```

The RTL-to-FPGA flow consists of:

```text
RTL Design
    ↓
Elaboration
    ↓
Synthesis
    ↓
Implementation
    ↓
Timing Analysis
    ↓
Bitstream Generation
    ↓
FPGA Programming
```

The supplied project documentation does not provide complete post-implementation timing and resource-utilization numbers, so those values should be obtained directly from the Vivado synthesis and implementation reports before being reported as measured results.

---

# Critical Path and Performance

Because the processor uses a single-cycle architecture, the clock period must be long enough for the slowest instruction.

The `LW` instruction represents an important critical-path case:

```text
PC
 ↓
Instruction Memory
 ↓
Instruction Decode
 ↓
Register Read
 ↓
Immediate Generation
 ↓
ALU
 ↓
Data Memory
 ↓
Result MUX
 ↓
Register Write
```

This long combinational path limits the maximum operating frequency.

---

# Design Limitations

The current implementation has several limitations:

* Single-cycle architecture limits clock frequency.
* Only a subset of the complete RV32I instruction set is implemented.
* Instruction and data memories are limited to 256 words each.
* The memory model is word-oriented.
* No pipeline registers are included.
* No forwarding unit is included.
* No hazard detection unit is included.
* No branch prediction is implemented.
* No cache hierarchy is included.
* Complete post-implementation timing and utilization results are not included in the supplied project metadata.

---

# Future Scope

The processor can be extended by:

1. Converting the single-cycle processor into a five-stage pipelined processor.
2. Adding IF/ID, ID/EX, EX/MEM, and MEM/WB pipeline registers.
3. Implementing data forwarding.
4. Adding hazard detection.
5. Adding branch hazard handling and prediction.
6. Expanding support toward the complete RV32I instruction set.
7. Increasing memory capacity.
8. Adding byte and halfword memory access.
9. Adding instruction and data caches.
10. Optimizing the critical path using FPGA timing reports.
11. Integrating the processor into a larger FPGA-based SoC.

---

# Tools Used

* **Verilog HDL**
* **Xilinx Vivado 2024.1**
* **RTL Simulation**
* **FPGA Implementation**
* **RISC-V RV32I Architecture**

---

# Project Structure

A suggested GitHub structure is:

```text
RISC-V-Processor/
│
├── README.md
│
├── RTL/
│   ├── ALU.v
│   ├── ins_fetch.v
│   ├── instruction_decode.v
│   ├── control_unit.v
│   ├── controller.v
│   ├── datapath.v
│   ├── instruction_memory.v
│   ├── data_memory.v
│   └── risc-v_top.v
│
├── Testbench/
│   └── cpu_testbench_zero_fail.v
│
├── Report/
│   └── riscv_report.pdf
│
└── Results/
    ├── RTL_schematic.png
    ├── simulation_waveform.png
    └── simulation_console.png
```

> **Note:** Use the actual filenames from your Verilog project when creating the folders. The report identifies modules such as `ALU.v`, `ins_fetch.v`, `instruction_decode.v`, `control_unit.v`, `controller.v`, `datapath.v`, `instruction memory.v`, `risc-v_top.v`, and `data memory.v`.

---

# Conclusion

This project demonstrates the RTL-level implementation of a **32-bit RISC-V RV32I single-cycle processor using Verilog HDL**.

The processor integrates instruction memory, register file, immediate generation, control logic, ALU, data memory, and next-PC logic into a complete datapath.

The project provides a foundation for understanding processor architecture, RTL design, instruction execution, control-signal generation, simulation, and FPGA implementation.

The next major improvement is pipelining, which can reduce the clock-period limitation of the current single-cycle architecture and enable higher-performance processor implementations.
