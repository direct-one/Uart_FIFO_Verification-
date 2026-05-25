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

## 🛠️ 컴포넌트 상세 설명 (Component Descriptions)

| 컴포넌트 (Component) | 파일 경로 (File Path) | 기능 및 역할 (Function) |
| :--- | :--- | :--- |
| **Interface** | `TB/uart_interface.sv` | 적절한 모드포트(Modport)를 사용하여 DUT(검증 대상 유닛)와 테스트벤치를 연결하는 물리적 신호들을 정의합니다. |
| **Transaction** | `TB/uart_trans.sv` | 패킷 데이터(데이터, 패리티, 정지 비트)를 무작위화(Randomization) 제약 조건과 함께 캡슐화(Encapsulate)합니다. |
| **Generator** | `TB/uart_gen.sv` | 무작위(Random) 또는 지시된(Directed) 트랜잭션 객체를 생성하고, 이를 메일박스(Mailbox)를 통해 전송합니다. |
| **Driver** | `TB/uart_drv.sv` | 트랜잭션 데이터를 풀어(Unpack) UART 프로토콜의 규칙과 타이밍에 맞게 직렬 하드웨어 핀(Pin)에 신호를 인가(Drive)합니다. |
| **Monitor** | `TB/uart_mon.sv` | 내부 및 외부의 물리적 신호를 관찰(Sample)하여 추상화된 트랜잭션 형태로 재구성한 뒤, 스코어보드로 전달합니다. |
| **Scoreboard** | `TB/uart_scb.sv` | 참조 모델(Reference Model)을 포함하여 예상되는 결과를 미리 예측하고, 실제 동작 결과와 비교하여 데이터 무결성을 검증(Check)합니다. |
| **Environment** | `TB/uart_env.sv` | 검증에 필요한 모든 객체 지향 하위 컴포넌트들을 인스턴스화(Instantiate)하고 하나의 구조(Topology)로 연결합니다. |
| **Top Module** | `TB/tb_top.sv` | 클럭(Clock)을 생성하고, DUT를 인스턴스화하며, 전체 테스트 시뮬레이션을 시작(Trigger)하는 정적 하드웨어(Static Hardware) 계층입니다. |

---

## 🛠️ How to Run

1. Clone the repository.
2. Compile using your preferred simulator (e.g., Questa, Vivado, or VCS).
3. Run `tb_top.sv` to initiate the layered simulation.

---

**Author:** [Your Name/GitHub Handle]

**Project Goal:** To demonstrate high-reliability verification of serial-to-parallel command decoding logic.
