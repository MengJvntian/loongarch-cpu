`timescale 1ns / 1ps

`include "defines.vh"

module PC (
    input  wire         cpu_rstn,
    input  wire         cpu_clk,
    input  wire         suspend,        // 流水线暂停信号

    input  wire [31:0]  din  ,          // 下一条指令地址
    output reg  [31:0]  pc   ,          // 当前程序计数器（PC）的值
    output wire         valid,          // IF阶段有效信号
    input  wire         ifetch_valid,  
    input  wire         pred_error
);

always @(posedge cpu_clk or negedge cpu_rstn) begin
    if (!cpu_rstn)
        pc <= `PC_INIT_VAL;
    else if(suspend)
        pc <= pc;
    else if(ifetch_valid | pred_error)
        pc <= din;
end

assign valid = !cpu_rstn ? 1'b0 : ifetch_valid;

endmodule
