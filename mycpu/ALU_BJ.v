`timescale 1ns / 1ps

`include "defines.vh"

module ALU_BJ (
    input  wire [31:0]  A,
    input  wire [31:0]  B,
    input  wire [ 4:0]  alu_op,
    output reg  [31:0]  C
);

// 根据alu_op完成不同的运算操作
always @(*) begin
    case (alu_op)
        `ALU_BLT  : C = $signed(A) < $signed(B);
        `ALU_BLTU : C = A < B;
        `ALU_BEQ  : C = !(A ^ B);
        `ALU_BNE  : C = |(A ^ B);
        `ALU_BGE  : C = $signed(A) >= $signed(B);
        `ALU_BGEU : C = A >= B;
        default   : C = 32'h0;
    endcase
end

endmodule
