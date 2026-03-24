`timescale 1ns / 1ps

`include "defines.vh"

module CU (
    input  wire [16:0]  din,            // 指令码的高17位
    input  wire         jump_taken,     // 跳转发生清零上一条指令的判断
    output reg  [ 2:0]  ext_op,         // 控制立即数扩展方式
    output reg  [ 2:0]  ram_ext_op,     // 控制读主存数据的扩展方式（针对load指令）
    output reg  [ 4:0]  alu_op,         // 控制运算类型
    output reg          rf_we,          // 控制是否写回寄存器堆
    output reg  [ 3:0]  ram_we,         // 写主存的写使能信号（针对store指令）
    output wire         r2_sel,         // 控制源寄存器2的选择
    output wire         wr_sel,         // 控制目的寄存器的选择
    output reg  [ 1:0]  wd_sel,         // 控制写回数据源
    output reg          rR1_re,         // 指令是否读取rR1，用于检测数据冒险
    output reg          rR2_re,         // 指令是否读取rR2，用于检测数据冒险
    output wire         alua_sel,       // 选择ALU操作数A的来源
    output reg          alub_sel,       // 选择ALU操作数B的来源
    output reg          is_br_jmp,      // 判断是否为分支跳转指令

    output reg          is_branch,      // 判断是否为分支指令
    output reg          is_jump         // 判断是否为跳转指令
);

reg   alu_r2;                            // 表明源寄存器2的选择
wire  alu_wr = din[15:11] == 5'b10101;   // 表明指令为bl即分支并跳转指令,选择r1为目的寄存器

always @(*) begin
    case (din[15:13])
        3'b110 : alu_r2 = `R2_RD;
        3'b010 : if(din[9]) alu_r2 = `R2_RD;
                 else alu_r2 = `R2_RK;
        3'b100 : alu_r2 = `R2_RK;
        3'b101 : if(din[12]) alu_r2 = `R2_RD;
                 else alu_r2 = `R2_RK;
        default: alu_r2 = `R2_RK;
    endcase
end

always @(*) begin
    case (din[15:13])
        3'b000 : if (din[10]) begin 
                        if(din[9])  ext_op = `EXT_12U;
                        else ext_op = `EXT_12S;
                        end
                 else begin
                        if(din[7])  ext_op = `EXT_5;
                        else ext_op = `EXT_NONE;
                 end
        3'b001 : ext_op = `EXT_20;
        3'b010 : ext_op = `EXT_12S;
        3'b100 , 3'b110 : ext_op = `EXT_18;
        3'b101 : if(din[12]) ext_op = `EXT_18;
                 else ext_op = `EXT_28;
        default: ext_op = `EXT_NONE;
    endcase
end

always @(*) begin
    case (din[15:13])
        3'b010: begin
            case (din[10:7])
                4'b0001: ram_ext_op = `RAM_EXT_HS;
                4'b1001: ram_ext_op = `RAM_EXT_HU;
                4'b0000: ram_ext_op = `RAM_EXT_BS;
                4'b1000: ram_ext_op = `RAM_EXT_BU;
                4'b0010: ram_ext_op = `RAM_EXT_W;
                default: ram_ext_op = `RAM_EXT_N;
            endcase
        end
        default: ram_ext_op = `RAM_EXT_N;
    endcase
end

always @(*) begin
    case (din[15:13]) 
        3'b000 , 3'b001 , 3'b010 : is_br_jmp = 1'b0;
        3'b101 , 3'b110 , 3'b100 : is_br_jmp = 1'b1;
        default : is_br_jmp = 1'b0;
    endcase
end

always @(*) begin
    if(jump_taken) begin
        is_branch = 1'b0;
        is_jump = 1'b0;
    end
    else begin
        case (din[15:13]) 
            3'b000 , 3'b001 , 3'b010 : begin
                is_branch = 1'b0;
                is_jump = 1'b0;
            end
            3'b100 : begin
                is_branch = 1'b0;
                is_jump = 1'b1;
            end
            3'b101 : begin
                if(din[12]) begin
                    is_branch = 1'b1;
                    is_jump = 1'b0;
                end
                else begin
                    is_branch = 1'b0;
                    is_jump = 1'b1;
                end
            end 
            3'b110 : begin
                is_branch = 1'b1;
                is_jump = 1'b0;
            end
            default : begin
                is_branch = 1'b0;
                is_jump = 1'b0;
            end
        endcase
    end
end

always @(*) begin
    case (din[15:13])
        3'b000: begin
            if (!din[10]) begin
                if (!din[7]) begin
                    if(!din[6]) begin
                        case (din[4:0])
                            `FR5_ADD  : alu_op = `ALU_ADD;
                            `FR5_SUB  : alu_op = `ALU_SUB;
                            `FR5_AND  : alu_op = `ALU_AND;
                            `FR5_OR   : alu_op = `ALU_OR;
                            `FR5_XOR  : alu_op = `ALU_XOR;
                            `FR5_NOR  : alu_op = `ALU_NOR;
                            `FR5_SLL  : alu_op = `ALU_SLL;
                            `FR5_SRL  : alu_op = `ALU_SRL;
                            `FR5_SRA  : alu_op = `ALU_SRA;
                            `FR5_SLT  : alu_op = `ALU_SLT;
                            `FR5_SLTU : alu_op = `ALU_SLTU;
                            `FR5_MUL  : alu_op = `ALU_MUL;
                            `FR5_MULH : alu_op = `ALU_MULH;
                            `FR5_MULHU: alu_op = `ALU_MULHU;
                            default   : alu_op = `ALU_ADD;
                        endcase
                    end
                    else begin
                        case (din[4:0])
                            `FR5_MOD : alu_op = `ALU_MOD;
                            `FR5_MODU: alu_op = `ALU_MODU;
                            `FR5_DIV : alu_op = `ALU_DIV;
                            `FR5_DIVU: alu_op = `ALU_DIVU;
                            default  : alu_op = `ALU_ADD;
                        endcase;
                    end
                end 
                else begin
                    case (din[4:0])
                        `FR5_SLLI: alu_op = `ALU_SLL;
                        `FR5_SRLI: alu_op = `ALU_SRL;
                        `FR5_SRAI: alu_op = `ALU_SRA;
                        default  : alu_op = `ALU_ADD;
                    endcase
                end
            end  
            else begin
                case (din[9:7])
                    `FR3_ORI  : alu_op = `ALU_OR;
                    `FR3_ADDI : alu_op = `ALU_ADD;
                    `FR3_ANDI : alu_op = `ALU_AND;
                    `FR3_XORI : alu_op = `ALU_XOR;
                    `FR3_SLTI : alu_op = `ALU_SLT;
                    `FR3_SLTUI: alu_op = `ALU_SLTU;
                    default   : alu_op = `ALU_ADD;
                endcase
            end
        end
        3'b001:begin
            if(!din[12]) alu_op = `ALU_LU12I;
            else alu_op = `ALU_ADD;
        end
        3'b010:alu_op = `ALU_ADD;
        3'b101:begin
            case (din[12:11])
                2'b10  : alu_op = `ALU_BEQ;
                2'b11  : alu_op = `ALU_BNE;
                2'b00 , 2'b01 : alu_op = `ALU_B_BL;
                default: alu_op = `ALU_ADD;
            endcase
        end
        3'b110:begin
            case (din[12:11])
                2'b00  : alu_op = `ALU_BLT;
                2'b10  : alu_op = `ALU_BLTU;
                2'b01  : alu_op = `ALU_BGE;
                2'b11  : alu_op = `ALU_BGEU;
                default: alu_op = `ALU_ADD;
            endcase
        end
        3'b100:begin
            alu_op = `ALU_JIRL;
        end
        default: alu_op = `ALU_ADD;
    endcase
end

always @(*) begin
    case (din[15:13])
        3'b010 : begin
            if (!din[9]) rf_we = 1'b1;
            else         rf_we = 1'b0;
        end
        3'b101 : if (din[12:11] == 2'b01) rf_we = 1'b1;
                 else  rf_we = 1'b0;
        3'b110 : rf_we = 1'b0;
        3'b100 : rf_we = 1'b1;
        default: rf_we = 1'b1;
    endcase
end

always @(*) begin
    case (din[15:13])
        3'b010 : if(din[9])
                    case (din[8:7]) 
                    2'b00: ram_we = `RAM_WE_B;
                    2'b01: ram_we = `RAM_WE_H;
                    2'b10: ram_we = `RAM_WE_W;
                    default: ram_we = `RAM_WE_N;
                endcase    
                else ram_we = `RAM_WE_N;
        default: ram_we = `RAM_WE_N;
    endcase
end

assign r2_sel = alu_r2? `R2_RK  : `R2_RD;     // 分支，store类指令选rd为源寄存器2，其他的选择rk为源寄存器2
assign wr_sel = alu_wr? `WR_Rr1 : `WR_RD;     // bl指令选择r1为目的寄存器，其他的选择rd为目的寄存器

always @(*) begin
    case (din[15:13])
        3'b000 , 3'b001 , 3'b110 : wd_sel = `WD_ALU;
        3'b010 : wd_sel = `WD_RAM;
        3'b100 : wd_sel = `WD_PC4;
        3'b101 : if(din[12:11] == 2'b01) wd_sel = `WD_PC4;
                 else wd_sel = `WD_ALU;
        default: wd_sel = `WD_ALU;
    endcase
end

always @(*) begin
    if (din[15:13] == 3'b001)
        rR1_re = 1'b0;
    else
        rR1_re = 1'b1;
end

always @(*) begin
    case (din[15:12])
        4'b0000, 4'b1011, 4'b1100, 4'b1101: rR2_re = 1'b1;
        4'b0101: if(din[9]) rR2_re = 1'b1;
                 else rR2_re = 1'b0;
        default: rR2_re = 1'b0;
    endcase
end


assign alua_sel = (din[15:11] == 5'b00111) || (din[15:11] == 5'b10101) ? `ALUA_PC : `ALUA_R1;

always @(*) begin
    case (din[15:13])
        3'b000 : if((!din[10]) && (!din[7])) alub_sel = `ALUB_R2;
                 else alub_sel = `ALUB_EXT;
        3'b001 , 3'b010 , 3'b100 : alub_sel = `ALUB_EXT;
        default: alub_sel = `ALUB_R2;
    endcase
end

endmodule
