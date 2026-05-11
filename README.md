# UART_Verification

# 🕒 UART-Controlled Digital Clock Verification

**A Layered SystemVerilog Testbench for Robust Serial Communication Verification**

## 📖 Overview

This repository features a professional, layered SystemVerilog testbench architecture. It is specifically designed to verify a **UART Receiver** integrated with a **FIFO buffer** and a **Command Decoder**.

The framework validates data integrity and the accuracy of command decoding for serial communication intended to control external logic, such as:

- **Digital Clock/Stopwatch Settings**
- **Sequential Command Decoding**
- **FIFO Buffer Management**

---

## 🏗️ Testbench Architecture

The testbench follows a modern, Object-Oriented (OO) verification methodology using class-based components for scalability and reuse.

### 🧬 Block Diagram Concept

### 🧩 Component Details

| Component | Description |
| --- | --- |
| **Interface (`uart_if`)** | Bundles clock, reset, UART serial lines, FIFO control, and decoded clock signals. |
| **Transaction** | Defines the data object. Randomized `uart_rx` data is restricted to four ASCII commands:
• `'r'`: Run/Stop
• `'u'`: Hour Up
• `'l'`: Minute Up
• `'d'`: Second Up |
| **Generator** | Creates randomized transaction objects and sends them to the Driver via a **Mailbox**. |
| **Driver** | Simulates the physical UART protocol (Start + 8-bit Data + Stop) synchronized to the `b_tick`. |
| **Monitor** | Passively captures data on `we` (write enable) and `rx_fifo_pop` (read) assertions. |
| **Scoreboard** | **The Checker:** Compares FIFO output against expected values and verifies the ASCII decoder's output signals (e.g., `o_ascii_hour_up`). |
| **Environment** | The container class that instantiates and connects all verification components. |

Sheets로 내보내기

---

## 🚀 Key Verification Features

- **Constrained Randomization:** Ensures only valid ASCII commands ('r', 'u', 'l', 'd') are generated for focused testing.
- **Protocol Accuracy:** Faithful simulation of bit-timing and UART framing.
- **Data Integrity:** Queue-based scoreboard ensures FIFO ordering and data consistency.
- **Command Decoding:** Dedicated checks for the transition from raw ASCII to functional control signals.

---

## 📂 Project Structure

Bash

`├── RTL/                  # Target Device Under Test (DUT)
├── TB/
│   ├── uart_interface.sv # Interface signals
│   ├── uart_trans.sv     # Transaction class with constraints
│   ├── uart_gen.sv       # Generator
│   ├── uart_drv.sv       # Driver (Serial driving logic)
│   ├── uart_mon.sv       # Monitor
│   ├── uart_scb.sv       # Scoreboard & Checker
│   ├── uart_env.sv       # Environment wrapper
│   └── tb_top.sv         # Top module & Test execution
└── README.md`

---

## 🛠️ How to Run

1. Clone the repository.
2. Compile using your preferred simulator (e.g., Questa, Vivado, or VCS).
3. Run `tb_top.sv` to initiate the layered simulation.

---

**Author:** [Your Name/GitHub Handle]

**Project Goal:** To demonstrate high-reliability verification of serial-to-parallel command decoding logic.
