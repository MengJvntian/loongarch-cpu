`timescale 1ns / 1ps

`include "defines.vh"

module NPC (
    input  wire [31:0]  ex_pc,      // 执行阶段PC值
    input  wire [ 1:0]  npc_op,     // NPC操作控制信号，用于选择下一个PC的值
    input  wire [31:0]  jump_addr,  // 分支跳转指令的跳转地址

    output wire [31:0]  pc4,        // 当前 PC+4 的值（顺序执行的下一条指令地址）
    output reg  [31:0]  npc,        // 下一个PC的值
    
    output reg          jump_taken  // 跳转信号，表示是否发生了分支或跳转
);

assign pc4 = ex_pc + 32'h4;
always @(*) begin
    case (npc_op)
        `NPC_PC4:   // 如果npc_op为NPC_PC4，选择顺序执行的下一条指令地址
            npc = pc4;
        `NPC_PC18 , `NPC_PC28 , `NPC_PCRJ: npc = jump_addr;  // 其他情况下都发生跳转
        default :   // 默认情况下，也选择顺序执行的下一条指令地址
            npc = pc4;
    endcase
end

// when branch or jump, set jump_taken to 1
always @(*) begin
    case (npc_op)
        `NPC_PC18 , `NPC_PC28 , `NPC_PCRJ: jump_taken = 1'b1;
        default  : jump_taken = 1'b0;
    endcase
end

endmodule
