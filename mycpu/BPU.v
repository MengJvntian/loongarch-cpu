`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

`define BHT_IDX_W 8                    // 表索引位宽
`define BHT_ENTRY (1 << `BHT_IDX_W)     // 表项个数

module BPU (
    input  wire         cpu_clk    ,
    input  wire         cpu_rstn   ,
    input  wire [31:0]  if_pc      ,        // IF阶段PC
    input  wire         if_valid   ,        // IF阶段有效信号
    // predict branch direction and target
    output wire [31:0]  pred_target,        // 预测目标地址
    output wire         pred_error ,        // 是否预测错误
    output wire         pred_taken ,        // 预测是否跳转
    // signals to update BHT and BTB
    input  wire [31:0]  ex_pred_target,     // ex阶段预测地址
    input  wire         ex_pred_taken,      // ex阶段预测方向
    input  wire         ex_valid   ,        // EX阶段有效信号
    input  wire         ex_is_bj   ,        // EX阶段是否是分支跳转指令
    input  wire [31:0]  ex_pc      ,        // EX阶段PC
    input  wire         real_taken ,        // EX阶段得到的真实跳转方向
    input  wire [31:0]  real_target         // EX阶段得到的真实目标地址
);

// BHT and BTB
reg  [`BHT_ENTRY-1:0] valid;
reg  [           1:0] history [`BHT_ENTRY-1:0];
reg  [          31:0] target  [`BHT_ENTRY-1:0];

wire [          31:0] pc_hash =  {if_pc[21:18] ^ if_pc[17:14] ^ if_pc[13:10] ^ if_pc[9:6] , if_pc[5:2] , if_pc[1:0]};      // 地址折叠
wire [`BHT_IDX_W-1:0] index   = pc_hash[`BHT_IDX_W+1:2];    // 表索引

wire [          31:0] ex_pc_hash = {ex_pc [21:18] ^ ex_pc [17:14] ^ ex_pc [13:10] ^ ex_pc[9:6] , ex_pc[5:2] , ex_pc[1:0]};      // 地址折叠
wire [`BHT_IDX_W-1:0] ex_index   = ex_pc_hash[`BHT_IDX_W+1:2];    // 表索引

assign pred_taken  = valid [index] && history [index] [1] && if_valid;        // 生成预测跳转方向
assign pred_target = pred_taken ? target [index] : if_pc + 3'h4;                                // 生成预测跳转的目标地址

wire taken_error  = (ex_is_bj && ex_pred_taken != real_taken) |                                // 检测分支跳转方向是否预测错误
                    (!ex_is_bj && ex_pred_taken);
wire target_error = real_target != ex_pred_target & real_taken & ex_pred_taken;                // 检测目标地址是否预测错误
assign pred_error = ex_valid & (taken_error | target_error);

wire add_entry     = ex_valid & real_taken & !valid [ex_index];                                // 判断何种情形需要在BHT和BTB中新增表项
wire update_entry  = ex_valid & taken_error;                                                   // 判断何种情形需要更新BHT和BTB的现有表项
wire replace_entry = ex_valid & real_taken & target_error;        // 判断何种情形需要替换BHT和BTB的现有表项

// Update BHT and BTB
integer i;
always @(posedge cpu_clk or negedge cpu_rstn) begin
    if (!cpu_rstn) begin
        valid <= {`BHT_ENTRY{1'b0}};
        for (i = 0; i < `BHT_ENTRY; i = i + 1)
            history [i] <= 2'b10;
    end else begin
        if(add_entry || replace_entry)begin
            valid [ex_index]   <= 1'b1;
            history [ex_index] <= 2'b10;
            target [ex_index]  <= real_target;   
        end 
        else if(update_entry)begin
            if(!ex_is_bj || !real_taken)
            case(history [ex_index])
                2'b11 : history [ex_index] <= 2'b10;
                2'b10 , 2'b01 , 2'b00 : history [ex_index] <= 2'b00;
                default: history [ex_index] <= 2'b10;
            endcase    
            else
            case(history [ex_index])
                2'b00 : history [ex_index] <= 2'b01;
                2'b01 , 2'b10 , 2'b11 : history [ex_index] <= 2'b11;
                default: history [ex_index] <= 2'b10;
            endcase    
        end
    end
end

endmodule