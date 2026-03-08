SystemVerilog Testbench for UART-Controlled Digital Clock

Overview

This repository contains a layered SystemVerilog testbench designed to verify a UART receiver module that is integrated with a FIFO buffer and a command decoder. It is an excellent framework for testing serial communication intended to control external logic—such as setting a digital clock or stopwatch—by validating both data integrity and accurate command decoding.

Testbench Architecture

The testbench follows a standard, object-oriented verification methodology using class-based components:
Interface (uart_interface): Bundles the system clock, reset, UART serial lines, FIFO control signals, and the decoded output signals for the clock operations.
Transaction: Defines the data object passed between the testbench components. It restricts the randomized uart_rx data to four specific ASCII commands: 'r' (run/stop), 'u' (hour up), 'l' (minute up), and 'd' (second up).

Generator: Creates randomized transaction objects containing the ASCII commands and passes them to the driver via a mailbox.

Driver: Takes the transaction data and drives it serially onto the uart_rx line. It faithfully simulates the UART physical protocol by sending a start bit, 8 data bits, and a stop bit, correctly synchronized to the baud rate tick (b_tick).
Monitor: Passively observes the interface to capture data. It records incoming data when the write enable (we) signal is high and reads output data when the FIFO pop (rx_fifo_pop) signal is asserted.

Scoreboard: Acts as the checker to validate DUT behavior. It pushes the incoming data into a queue, and upon a read operation, it pops the expected data to compare against the actual FIFO output (rx_fifo_out). Furthermore, it verifies that the ASCII command decoder correctly asserted the appropriate output signal (e.g., o_ascii_hour_up when 'u' is received).

Environment & Top Module (tb_uart_veri): The environment class instantiates and wires all the verification components together so they run concurrently. The top module binds the interface to the Device Under Test (DUT), initializes the environment, and provides the clock stimulus to drive the simulation.
