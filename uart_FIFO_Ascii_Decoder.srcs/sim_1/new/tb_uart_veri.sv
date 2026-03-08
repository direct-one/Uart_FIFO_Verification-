`timescale 1ns / 1ps


interface uart_interface(input logic clk);
    logic reset;
    logic uart_rx;
    logic uart_tx;
    logic b_tick;

    // FIFO Signals
    logic rx_fifo_pop;
    logic [7:0] rx_fifo_out;
    logic rx_fifo_empty;
    logic rx_fifo_full;
    logic we;

    // Decoder Signals
    logic rx_done;
    logic [7:0] ascii_in;
    logic [7:0] o_ascii_run_stop;
    logic [7:0] o_ascii_hour_up;   
    logic [7:0] o_ascii_min_up;
    logic [7:0] o_ascii_sec_up;
endinterface


class transaction;
    rand bit [7:0] uart_rx;
    bit [7:0] rx_fifo_out;

    bit we, rx_fifo_pop, rx_fifo_full;
    bit [7:0] o_ascii_run_stop, o_ascii_hour_up, o_ascii_min_up, o_ascii_sec_up;
    bit stop_bit = 1'b1; // alwayas stop_bit ==1'b1

    constraint ascii_data {
        uart_rx dist {
            8'h72 := 20, // r
            8'h75 := 20, // u
            8'h6C := 20, // l
            8'h64 := 20  // d
        };
    }

    function void display(string name);
        $display("[%t] [%s] ASCII Data = 8'h%h ('%c')", $time, name, uart_rx, uart_rx);
    endfunction
endclass


class generator;
    transaction tr;
    mailbox#(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox,
                 event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int run_count);
        repeat(run_count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");
           @(gen_next_ev);
        end
    endtask
endclass


class driver;
    transaction tr;
    mailbox#(transaction) gen2drv_mbox;
    virtual uart_interface uart_if;

    function new(mailbox#(transaction) gen2drv_mbox, virtual uart_interface uart_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_if      = uart_if;
    endfunction

    // stop_bit
    task send_stop_bit();
        uart_if.uart_rx <= tr.stop_bit;
        repeat(16) @(posedge uart_if.b_tick);
        uart_if.uart_rx <= 1'b1; // IDLE
    endtask

    task data();
        // Start bit
        @(negedge uart_if.b_tick);  // expext race condition 
        uart_if.uart_rx <= 1'b0;
        repeat(16) @(posedge uart_if.b_tick);

        // Data bits 
        for (int i = 0; i < 8; i++) begin
            uart_if.uart_rx <= tr.uart_rx[i];
            repeat(16) @(posedge uart_if.b_tick);
        end

        send_stop_bit(); 
    endtask

    task run();
        uart_if.uart_rx <= 1'b1; // IDLE state
        forever begin
            gen2drv_mbox.get(tr);
            data();
        end
    endtask
endclass


class monitor;
    transaction tr;
    mailbox#(transaction) mon2scb_mbox;
    virtual uart_interface uart_if;

    function new(mailbox#(transaction) mon2scb_mbox, virtual uart_interface uart_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_if      = uart_if;
    endfunction

    task run();
        forever begin
            @(posedge uart_if.clk);

            // monitor write signal
            if (uart_if.we) begin
                tr = new();
                tr.we           = 1'b1;
                tr.uart_rx      = uart_if.ascii_in;
                tr.rx_fifo_full = uart_if.rx_fifo_full;
                mon2scb_mbox.put(tr);
            end

            // monitor read signal
            if (uart_if.rx_fifo_pop) begin
                fork
                    begin
                        automatic transaction local_tr;// local Handle 
                        automatic logic [7:0] fifo_out = uart_if.rx_fifo_out;
                        #1;
                        local_tr = new();
                        local_tr.rx_fifo_pop      = 1'b1;
                        local_tr.rx_fifo_out      = fifo_out;
                        local_tr.o_ascii_run_stop = uart_if.o_ascii_run_stop;
                        local_tr.o_ascii_hour_up  = uart_if.o_ascii_hour_up;  
                        local_tr.o_ascii_min_up   = uart_if.o_ascii_min_up;
                        local_tr.o_ascii_sec_up   = uart_if.o_ascii_sec_up;
                        mon2scb_mbox.put(local_tr);
                    end
                join_none
            end
        end
    endtask
endclass


class scoreboard;
    transaction tr;
    mailbox#(transaction) mon2scb_mbox;
    event gen_next_ev;
    int pass_cnt = 0, fail_cnt = 0, total_cnt = 0;

    logic [7:0] Queue[$:15]; 
    logic [7:0] exp_data;

    function new(mailbox#(transaction) mon2scb_mbox,
                 event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    function bit decoder();
        case (exp_data)
            8'h72: return (tr.o_ascii_run_stop == 8'h72);
            8'h75: return (tr.o_ascii_hour_up  == 8'h75);
            8'h6C: return (tr.o_ascii_min_up   == 8'h6C);
            8'h64: return (tr.o_ascii_sec_up   == 8'h64);
            default: return 1'b1;
        endcase
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(tr);

            // push
            if (tr.we && !tr.rx_fifo_full) begin
                Queue.push_front(tr.uart_rx);
                $display("Push Data: %h", tr.uart_rx);
            end

            // compare & pop
            if (tr.rx_fifo_pop) begin
                total_cnt++;

                if (Queue.size() == 16)
                    tr.rx_fifo_full = 1'b1;

                if (Queue.size() > 0) begin
                    exp_data = Queue.pop_back();
                    $display("\n[DATA COMPARE] exp: %h, rdata: %h", exp_data, tr.rx_fifo_out);

                    if ((exp_data === tr.rx_fifo_out) && decoder()) begin
                        pass_cnt++;
                        $display("[ PASS ]");
                    end else begin
                        fail_cnt++;
                        $display("[ FAIL ]");
                        if (exp_data !== tr.rx_fifo_out) $display("Data Mismatch");
                        if (!decoder())                  $display("ASCII Decoder Error");
                    end
                end
                -> gen_next_ev;
                $display("========================================");
            end
        end
    endtask
endclass


class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;

    mailbox#(transaction) gen2drv_mbox;
    mailbox#(transaction) mon2scb_mbox;
    event gen_next_ev;

    function new(virtual uart_interface uart_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();

        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, uart_if);
        mon = new(mon2scb_mbox, uart_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction

    task run();
        fork
            gen.run(100);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #1000;
        $display("\nPass: %0d, Fail: %0d", scb.pass_cnt, scb.fail_cnt);
        $stop;
    endtask
endclass


module tb_uart_veri();
    logic clk;

    uart_interface uart_if(clk);

    uart_sv dut(
        .clk    (uart_if.clk),
        .reset  (uart_if.reset),
        .uart_rx(uart_if.uart_rx),
        .uart_tx(uart_if.uart_tx)
    );

    assign uart_if.b_tick        = dut.w_b_tick;
    assign uart_if.we            = dut.w_rx_done;
    assign uart_if.ascii_in      = dut.w_rx_data;

    assign uart_if.rx_done       = dut.w_rx_done;
    assign uart_if.rx_fifo_pop   = dut.rx_fifo_pop;
    assign uart_if.rx_fifo_out   = dut.rx_fifo_out;
    assign uart_if.rx_fifo_empty = dut.rx_fifo_empty;
    assign uart_if.rx_fifo_full  = dut.rx_fifo_full;

    assign uart_if.o_ascii_run_stop = dut.w_o_ascii_run_stop;
    assign uart_if.o_ascii_hour_up  = dut.w_o_ascii_hour_up;  
    assign uart_if.o_ascii_min_up   = dut.w_o_ascii_min_up;
    assign uart_if.o_ascii_sec_up   = dut.w_o_ascii_sec_up;

    environment env;

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        uart_if.reset = 1'b1;
        #20 uart_if.reset = 1'b0;

        env = new(uart_if);
        env.run();
    end
endmodule