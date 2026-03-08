`timescale 1ns / 1ps

module uart_sv (
    input        clk,
    input        reset,
    //input [3:0]  sw,
    //  input btn_d,
    input        uart_rx,
    output       uart_tx
);
    //   output [7:0] rx_data


    wire[7:0] send_tx_data;
    wire send_tx_start;
    wire tx_fifo_full,tx_fifo_empty;

    wire w_b_tick, w_rx_done;
    wire [7:0] w_rx_data;
    wire w_run_stop, w_clear, w_mode ;  
     wire btn_s = w_rx_done && (w_rx_data == 8'h73);  //s btn   
     wire tx_busy;
     wire tx_done;
     wire w_tx_pop_signal;
     wire tx_fifo_pop;
     wire rx_fifo_pop;
     wire rx_fifo_full,rx_fifo_empty;
     wire [7:0] rx_fifo_out;

     wire [7:0] w_tx_data_fifo;
     

     assign w_tx_pop_signal =  (UNT_UART_TX.c_state == 2'd0) && !tx_fifo_empty ;
     assign send_tx_start = (!tx_busy)&(!tx_fifo_empty);

     assign send_tx_data = w_tx_data_fifo;

     assign rx_fifo_pop = !rx_fifo_empty;//-->(check full)1'b0;


    wire [13:0] w_counter;

    wire o_btn_run_stop,o_btn_clear;
    wire [23:0] w_stopwatch_time;
    wire [23:0] w_watch_time;
    wire [23:0] w_mux_2x1_stop_watch;

    wire  [7:0] w_o_ascii_run_stop;
    wire  [7:0] w_o_ascii_hour_up;
    wire  [7:0] w_o_ascii_min_up;
    wire  [7:0] w_o_ascii_sec_up;
    
    
    

    


    wire w_ascii_mode, w_ascii_stop_watch, w_ascii_time_switch;

    


 


    ascii_decoder U_ASCII_DECODER(
    .clk(clk),
    .reset(reset),
    .rx_done(rx_fifo_pop),
    .ascii_in(rx_fifo_out),
    .o_ascii_run_stop(w_o_ascii_run_stop), 
    .o_ascii_hour_up(w_o_ascii_hour_up) ,
    .o_ascii_min_up(w_o_ascii_min_up) ,
    .o_ascii_sec_up(w_o_ascii_sec_up),
    .o_ascii_mode(w_ascii_mode),
    .o_ascii_stop_watch(w_ascii_stop_watch),
    .o_ascii_time_switch(w_ascii_time_switch)

    );


 fifo #(.DEPTH (8), .BIT_WIDTH (8) ) UNIT_RX_FIFO(
    .clk(clk), 
    .reset(reset),
    .we(w_rx_done && !rx_fifo_full),
    .re(rx_fifo_pop),
    .wdata(w_rx_data),
    .rdata(rx_fifo_out),
    .full(rx_fifo_full),
    .empty(rx_fifo_empty)

    ); 

    fifo #(.DEPTH (16), .BIT_WIDTH (8) ) UNIT_TX_FIFO (
    .clk(clk), 
    .reset(reset),
    .we(w_rx_done && !tx_fifo_full),
    .re(send_tx_start),
    .wdata(w_rx_data),
    .rdata(w_tx_data_fifo),
    .full(tx_fifo_full),
    .empty(tx_fifo_empty)


    ); 





    uart_rx UART_RX (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx),
        .b_tick(w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    uart_tx UNT_UART_TX (
        .clk(clk),
        .reset(reset),
        .tx_start(send_tx_start),
        .b_tick(w_b_tick),
        .tx_data(send_tx_data),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .uart_tx(uart_tx)
    );
    b_tick UNT_B_TICK (
        .clk(clk),
        .reset(reset),
        .b_tick(w_b_tick)
    );
endmodule


module uart_rx (
    input clk,
    input reset,
    input rx,
    input b_tick,
    output [7:0] rx_data,
    output rx_done
);
    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;

    reg [1:0] c_state, n_state;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    logic rx_sync_f, rx_sync_s;
    always_ff @( posedge clk ) begin
        rx_sync_f <= rx;
        rx_sync_s <= rx_sync_f;        
    end

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= 2'd0;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg <= 3'd0;
            done_reg <= 1'b0;
            buf_reg <= 8'd0;
        end else begin
            c_state <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
            done_reg <= done_next;
            buf_reg <= buf_next;
        end

    end

    always @(*) begin
        n_state = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        done_next = done_reg;
        buf_next = buf_reg;
        case (c_state)
            IDLE: begin
                b_tick_cnt_next = 5'd0;
                bit_cnt_next = 3'd0;
                done_next = 1'b0;
                if (b_tick & rx == 0) begin
                    buf_next = 8'd0;
                    n_state  = START;
                end
            end
            START: begin
                if (b_tick)
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 5'd0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end

            end
            STOP: begin
                if (b_tick)
                    if (b_tick_cnt_reg == 15) begin
                        n_state   = IDLE;
                        if(rx == 1'b1)begin
                        done_next = 1'b1;
                        end else begin 
                            done_next = 1'b0;   // checking for trash data 
                        end 
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end
        endcase
    end

endmodule

module uart_tx (
    input clk,
    input reset,
    input tx_start,
    input b_tick,
    input [7:0] tx_data,
    output tx_busy,
    output tx_done,
    output uart_tx
);
    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;




    reg [1:0] c_state, n_state;
    reg tx_reg, tx_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg busy_reg, busy_next;
    reg done_reg, done_next;
    reg [7:0] data_in_buf_reg, data_in_buf_next;
    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;




    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            tx_reg <= 1'b1;
            bit_cnt_reg <= 1'b0;
            b_tick_cnt_reg <= 4'h0;
            busy_reg <= 1'b0;
            done_reg <= 1'b0;
            data_in_buf_reg <= 8'h00;

        end else begin
            c_state <= n_state;
            tx_reg <= tx_next;
            bit_cnt_reg <= bit_cnt_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            busy_reg <= busy_next;
            done_reg <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        tx_next = tx_reg;
        bit_cnt_next = bit_cnt_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        busy_next = busy_reg;
        done_next = done_reg;
        data_in_buf_next = data_in_buf_reg;


        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                bit_cnt_next = 1'b0;
                b_tick_cnt_next = 4'h0;
                busy_next = 1'b0;
                done_next = 1'b0;
                if (tx_start) begin
                    n_state = START;
                    busy_next = 1'b1;
                    data_in_buf_next = tx_data;

                end
            end

            START: begin

                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 4'h0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 4'h0;
                            n_state = STOP;
                        end else begin
                            b_tick_cnt_next = 4'h0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                            n_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end

                end
            end


            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        done_next = 1'b1;
                        n_state   = IDLE;

                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule







module b_tick (
    input clk,
    input reset,
    output reg b_tick

);

    parameter TIMES = 9600 * 16;
    parameter COUNT = 100_000_000 / TIMES;

    reg [$clog2(COUNT)-1:0] counter_reg;


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 1'b0;
            b_tick <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (COUNT - 1)) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end



endmodule
`timescale 1ns / 1ps


module fifo #(parameter DEPTH = 4, BIT_WIDTH =8 ) (
    input       clk, 
    input       reset,
    input       we,
    input       re,
    input [7:0] wdata,
    output [7:0] rdata,
    output      full,
    output      empty


    );      


    wire [$clog2(DEPTH)-1 :0] w_wptr, w_rptr; 



    register_file #(
        .DEPTH(DEPTH),
        .BIT_WIDTH(BIT_WIDTH)) U_REG_FILE(
        .clk(clk),
        .wdata(wdata),
        .w_addr(w_wptr),
        .r_addr(w_rptr),
        .we(we & (~full)),
        .rdata(rdata)
    );

    control_unit #(
        .DEPTH(DEPTH)) U_CNTL_UNIT(
        .clk(clk), 
        .reset(reset),
        .we(we),
        .re(re),
        .wptr(w_wptr),
        .rptr(w_rptr),
        .full(full),
        .empty(empty)
    );



endmodule

    //register_file 
    module register_file #(parameter DEPTH = 4, BIT_WIDTH = 8 ) 
     (
        input                      clk,
        input [BIT_WIDTH -1:0]     wdata,
        input [$clog2(DEPTH)-1:0]  w_addr,
        input [$clog2(DEPTH)-1:0]  r_addr,
        input                      we,
        output  [BIT_WIDTH-1:0] rdata
    );

    //ram 
    reg [BIT_WIDTH-1:0] register_file [0:DEPTH-1];


    //push, to register_file 
    always @(posedge clk) begin
        if (we) begin
            //push
            register_file[w_addr] <= wdata;

        end //else begin
            //pop_data <= register_file[r_addr];
        //end
    end 

    //pop
    assign rdata =  register_file[r_addr];


        
    endmodule
    // control_unit
    module control_unit  #(parameter DEPTH = 4) (
        input                      clk, 
        input                      reset,
        input                      we,
        input                      re,
        output [$clog2(DEPTH)-1:0] wptr,
        output [$clog2(DEPTH)-1:0] rptr,
        output                     full,
        output                     empty
    );

    reg [1:0] c_state, n_state;
    reg[$clog2(DEPTH)-1:0] wptr_reg,wptr_next, rptr_reg, rptr_next;
    reg full_reg, full_next, empty_reg, empty_next;
    assign wptr = wptr_reg;
    assign rptr = rptr_reg;
    assign full = full_reg;
    assign empty = empty_reg; 

    // SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= 2'b00;
            wptr_reg <= 0;
            rptr_reg <= 0;
            full_reg <= 0;
            empty_reg <= 1'b1;

        end else begin
            c_state <= n_state;
            wptr_reg <= wptr_next;
            rptr_reg <= rptr_next;
            full_reg <= full_next;
            empty_reg <= empty_next;

        end
    end
    // CL
    always @(*) begin
        n_state = c_state;
        wptr_next = wptr_reg;
        rptr_next = rptr_reg;
        full_next = full_reg;
        empty_next = empty_reg;
        case ({we,re})
            //push 
            2'b10:begin
                if(!full)begin
                wptr_next = wptr_reg +1;
                empty_next = 1'b0;
                if (wptr_next == rptr_reg) begin
                    full_next = 1'b1;
                end
                end                
            end
            //pop
            2'b01: begin
                if(!empty) begin
                rptr_next = rptr_reg+1;
                full_next = 1'b0;
                if (wptr_reg == rptr_next) begin
                    empty_next = 1'b1;

                end
            end
            end

            //push,pop
            2'b11: begin

                if (full_reg == 1'b1) begin
                    rptr_next = rptr_reg +1;
                    full_next = 1'b0;
                end else if (empty == 1'b1) begin
                    wptr_next = wptr_reg +1;
                    empty_next = 1'b0;
                end else begin
                    wptr_next = wptr_reg +1;
                    rptr_next = rptr_reg +1;
                end
            end

        endcase
    end

        
    endmodule


