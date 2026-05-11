`timescale 1ns / 1ps


module ascii_decoder(
    input clk,
    input reset,
    input [7:0] ascii_in,
    input rx_done,
    
    output reg [7:0] o_ascii_run_stop, 
    output reg [7:0] o_ascii_hour_up ,
    output reg [7:0] o_ascii_min_up ,
    output reg [7:0] o_ascii_sec_up,

    output reg [7:0]o_ascii_mode,
    output reg [7:0]o_ascii_stop_watch,
    output reg [7:0]o_ascii_time_switch
    );
     wire [7:0] w_rx_data;
     wire w_rx_done;

    wire w_ascii_run_stop = (w_rx_data == 8'h72) && w_rx_done;
    wire w_ascii_hour_up = (w_rx_data == 8'h75) && w_rx_done;
    wire w_ascii_min_up = (w_rx_data == 8'h6C) && w_rx_done;
    wire w_ascii_sec_up = (w_rx_data == 8'h64) && w_rx_done;


    always @(posedge clk, posedge reset) begin
        if (reset)begin
        o_ascii_run_stop <= 8'h30;
        o_ascii_hour_up <= 8'h30;
        o_ascii_min_up <= 8'h30;
        o_ascii_sec_up <= 8'h30;
        o_ascii_mode <= 8'h30;
        o_ascii_stop_watch <= 8'h30;
        o_ascii_time_switch <= 8'h30;
        end else begin
            o_ascii_run_stop <= 0;
            o_ascii_hour_up <= 0;
            o_ascii_min_up <= 0;
            o_ascii_sec_up <= 0;
        if(rx_done)begin
        case (ascii_in)
            8'h72:o_ascii_run_stop <= 8'h72;
            8'h75:o_ascii_hour_up <= 8'h75;
            8'h6C:o_ascii_min_up <= 8'h6C;
            8'h64:o_ascii_sec_up <= 8'h64;
            8'h30:o_ascii_mode <= ~o_ascii_mode;
            8'h31:o_ascii_stop_watch <= ~o_ascii_stop_watch;
            8'h32:o_ascii_time_switch <= ~o_ascii_time_switch;
            
        endcase
        end
    end
    end
endmodule
