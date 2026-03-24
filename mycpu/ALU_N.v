`timescale 1ns / 1ps

`include "defines.vh"

module ALU_N (
    input  wire [31:0]  A,
    input  wire [31:0]  B,
    input  wire [ 4:0]  alu_op,
    output reg  [31:0]  C
);

    reg  [63:0]  TR; // Temporary Register

// 根据alu_op完成不同的运算操作
always @(*) begin
    case (alu_op)
        `ALU_ADD  : C = A + B;
        `ALU_OR   : C = A | B;
        `ALU_SUB  : C = A - B;
        `ALU_AND  : C = A & B;
        `ALU_XOR  : C = A ^ B;
        `ALU_NOR  : C = ~ ( A | B );
        `ALU_SLL  : C = A << B[4:0];
        `ALU_SRL  : C = A >> B[4:0];
        `ALU_SRA  : C = ( A >> B[4:0] ) | ({ 32 { A[31] }} << ( 6'd32 - { 1'b0 , B[4:0] }));
        `ALU_SLT  : C = $signed(A) < $signed(B);
        `ALU_SLTU : C = A < B;
        `ALU_MUL  : begin
                        TR = $signed(A) * $signed(B);
                        C = TR[31:0];
                    end
        `ALU_MULH : begin
                        TR = $signed(A) * $signed(B);
                        C = TR[63:32];
                    end
        `ALU_MULHU: begin
                        TR = A * B;
                        C = TR[63:32];
                    end
        `ALU_LU12I: C = B;
        default   : C = 32'h0;
    endcase
end

endmodule
