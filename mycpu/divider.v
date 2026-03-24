`timescale 1ns / 1ps

`include "defines.vh"

module divider (
    input wire clk,
    input wire rstn,
    input wire [ 4:0] alu_op,
    input wire start,
    input wire [31:0] dividend,
    input wire [31:0] divisor,
    output reg [31:0] quotient,
    output reg [31:0] remainder,
    output reg ready,
    output reg finish
);
    // 内部寄存器
    reg [31:0] dividend_abs, divisor_abs;
    reg [5:0] lzc_dividend, lzc_divisor;
    reg [63:0] dividend_norm, divisor_norm;
    reg sign_dividend, sign_divisor;
    reg sign_result;
    reg [2:0] state;
    wire sign;
    
    // 除法算法寄存器
    reg [5:0] count;
    reg [32:0] A, M;
    reg [31:0] Q;
    reg last_sign;
    reg [31:0] divisor_saved;
    reg [5:0] lzc_saved;

    assign sign = (alu_op[4:1] == 4'b1001) ? 1'b0 : 1'b1;

    // 前导0计算
    reg found;
    integer i;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            quotient <= 0;
            remainder <= 0;
            ready <= 1;
            state <= 0;
            finish <= 0;
            count <= 0;
            A <= 0;
            Q <= 0;
            M <= 0;
            last_sign <= 0;
        end else begin
            case (state)
                0: begin
                    ready <= 1;
                    finish <= 0;
                    if (start) begin
                        // 符号处理
                        sign_dividend <= sign ? dividend[31] : 1'b0;
                        sign_divisor <= sign ? divisor[31] : 1'b0;
                        
                        // 绝对值转换
                        if (sign) begin
                            dividend_abs <= dividend[31] ? -dividend : dividend;
                            divisor_abs  <= divisor[31]  ? -divisor : divisor;
                        end else begin
                            dividend_abs <= dividend;
                            divisor_abs  <= divisor;
                        end
                        
                        state <= 1;
                        ready <= 0;
                    end
                end
                
                1: begin
                    // 计算前导零
                    lzc_dividend = 32;      // 默认值（全0时返回32）
                    lzc_divisor = 32;
                    found = 0;     // 重置标志位
                    
                    // 从最高位(31)向最低位(0)扫描
                    for (i = 31; (i >= 0) && (!found); i = i - 1) begin
                        if (dividend_abs[i] && !found) begin  // 找到第一个1
                            lzc_dividend = 31 - i;          // 计算前导零数量
                            found = 1;             // 设置标志位停止后续检查
                        end
                    end

                    for (i = 31, found = 0; (i >= 0) && (!found); i = i - 1) begin
                        if (divisor_abs[i] && !found) begin  
                            lzc_divisor = 31 - i;         
                            found = 1;             
                        end
                    end
                    state <= 2;
                end
                
                2: begin
                    if (divisor_abs == 0) begin
                        // 除数为0处理
                        quotient <= 32'hFFFFFFFF;
                        remainder <= 0;
                        sign_result <= 1'b0;
                        finish <= 1'b1;
                        ready <= 1;
                        state <= 0;
                    end else begin
                        // 归一化对齐
                        dividend_norm = dividend_abs << lzc_divisor;
                        divisor_norm  = divisor_abs << lzc_divisor;
                        
                        // 保存归一化参数
                        divisor_saved <= divisor_norm[31:0];
                        lzc_saved <= lzc_divisor;
                        
                        // 初始化除法算法
                        A <= {1'b0, dividend_norm[63:32]}; // 高位部分
                        Q <= dividend_norm[31:0];          // 低位部分
                        M <= {1'b0, divisor_norm[31:0]};   // 除数
                        count <= 32 - lzc_divisor;         // 优化后的迭代次数
                        last_sign <= 0;
                        
                        state <= 3;
                    end
                end
                
                3: begin  // 不恢复余数除法迭代
                    // 左移A和Q
                    {A, Q} = {A, Q} << 1;
                    
                    // 根据上一次的符号位决定操作
                    if (last_sign == 0) begin
                        A = A - M;
                    end else begin
                        A = A + M;
                    end
                    
                    // 更新符号位并设置商位
                    last_sign = A[32];
                    Q[0] = (A[32] == 0) ? 1'b1 : 1'b0;
                    
                    count <= count - 1;
                    
                    if (count == 1) begin  // 最后一次迭代
                        state <= 4;
                    end
                end
                
                4: begin  // 最终处理
                    // 余数调整（如果需要）
                    if (A[32] == 1) begin
                        A = A + M;
                    end
                    
                    // 反归一化余数
                    remainder = A[31:0] >> lzc_saved;
                    
                    // 结果符号调整
                    if (sign) begin
                        quotient <= sign_dividend ^ sign_divisor ? -Q : Q;
                        remainder <= sign_dividend ? -remainder : remainder;
                    end else begin
                        quotient <= Q;
                        // remainder 已经处理
                    end
                    
                    finish <= 1'b1;
                    ready <= 1;
                    state <= 0;
                end
            endcase
        end
    end
endmodule
