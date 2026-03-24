`timescale 1ns / 1ps

`include "defines.vh"

module sram_uart(
    input  wire        aclk,
    input  wire        aresetn,

    // 串口专用
    input  wire   [7:0] serial_t,          // 待发送的数据
    input  wire  [31:0] serial_addr,       // 串口寄存器访问地址
    output reg   [31:0] serial_o,          // 串口状态数据
    output reg          serial_f,          // 串口工作完成
    input  wire         serial_w,          // 写串口信号

    // icache接口
    output wire         ic_rrdy,          // 可读指令状态
    input  wire   [3:0] ic_ren,           // 指令读使能
    input  wire  [31:0] ic_raddr,         // 指令地址
    output reg          ic_rvalid,        // 指令输出有效
    output reg  [127:0] ic_rdata,         // 输出指令

    // 数据读写
    input  wire   [3:0] da_ren,           // 数据读使能
    input  wire  [31:0] da_addr,          // 数据读写地址
    output wire         da_rvalid,        // 数据读有效
    output wire  [31:0] da_rdata,         // 输出数据
    input  wire   [3:0] da_wen,           // 数据写使能
    input  wire  [31:0] da_wdata,         // 待写入数据
    output wire         da_wresp,         // 数据写完成
    
    // SRAM接口
    inout  wire [31:0] base_ram_data,     // BaseRAM数据
    output reg  [31:0] base_ram_addr,     // BaseRAM地址
    output reg  [3:0]  base_ram_be_n,     // BaseRAM字节使能
    output reg         base_ram_ce_n,     // BaseRAM片选
    output reg         base_ram_oe_n,     // BaseRAM读使能
    output reg         base_ram_we_n,     // BaseRAM写使能
    
    inout  wire [31:0] ext_ram_data,      // ExtRAM数据
    output reg  [31:0] ext_ram_addr,      // ExtRAM地址
    output reg  [3:0]  ext_ram_be_n,      // ExtRAM字节使能
    output reg         ext_ram_ce_n,      // ExtRAM片选
    output reg         ext_ram_oe_n,      // ExtRAM读使能
    output reg         ext_ram_we_n,      // ExtRAM写使能
    
    // 串口信号
    output wire        txd,               // 串口发送端
    input  wire        rxd                // 串口接收端
);
// ========== 地址解码和寄存器 ==========
wire is_SerialState; 
wire is_SerialData;
        
assign is_SerialState = (serial_addr == `SerialState); 
assign is_SerialData  = (serial_addr == `SerialData);

// ========== 串口控制器 ==========
wire [7:0] uart_rx;
reg  [7:0] uart_tx;
reg  [7:0] uart_buffer; // 缓存接收到的数据，确保在下一次接收结束前，仍可读取上一次接收数据
wire       uart_ready;
wire       uart_busy;
reg        uart_start;
reg        uart_clear;
wire       uart_wr; // 串口读写使能，低写高读

assign uart_wr = serial_w ? 1'b0 : 1'b1;

async_receiver #(.ClkFrequency(`CPU_CLOCK),.Baud(9600)) //接收模块，9600无检验位
    ext_uart_r(
        .clk(aclk),                     // 外部时钟信号
        .RxD(rxd),                      // 外部串行信号输入
        .RxD_data_ready(uart_ready),    // 数据接收完成标志
        .RxD_clear(uart_clear),         // 清除接收数据完成标志
        .RxD_data(uart_rx)              // 接收到的一字节数据
    );

/*rx_data u_rx_data(
    .aclk (aclk),
    .aresetn (aresetn),
    .ready  (uart_ready),
    .clear (uart_clear),
    .rx (uart_rx)
);*/

// 接收到缓冲区
always @(posedge aclk or negedge aresetn) begin 
    if(!aresetn) begin
        uart_buffer <= 8'b0;
    end 
    else if(uart_ready) begin
        uart_buffer <= uart_rx;
    end
end

async_transmitter #(.ClkFrequency(`CPU_CLOCK),.Baud(9600)) //发送模块，9600无检验位
    ext_uart_t(
        .clk(aclk),                     // 外部时钟信号
        .TxD(txd),                      // 串行信号输出
        .TxD_busy(uart_busy),           // 发送器忙状态指示
        .TxD_start(uart_start),         // 开始发送信号
        .TxD_data(uart_tx)              // 待发送的数据
    );

// 处理收发
always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        uart_start <= 1'b0;
        uart_tx <= 8'b0;
        serial_o <= 32'h0;
        serial_f <= 1'h0;
    end
    else begin
        if(is_SerialState) begin   // 更新串口状态
            uart_start <= 1'b0;
            uart_tx <= 8'b0;
            serial_o <= {30'b0, {uart_ready, !uart_busy}};
            serial_f <= 1'h1;
        end
        else if(is_SerialData) begin                  
            if(uart_wr & uart_ready) begin  // 读串口
                uart_start <= 1'b0;
                uart_tx <= 8'b0;
                serial_o <= {24'h0, uart_buffer};
                serial_f <= 1'h1;
            end
            else if(!uart_wr & !uart_busy) begin  // 发数据
                uart_start <= 1'b1;
                uart_tx <= serial_t;
                serial_o <= 32'h0;
                serial_f <= 1'h1;
            end 
        end
        else if(serial_f)begin
            serial_f <= 1'h0;
        end
        else begin
            uart_start <= 1'b0;
            uart_tx <= 8'b0;
            serial_o <= 32'h0;
        end
    end
end

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) uart_clear <= 1'b1;
    else if(uart_ready && is_SerialData && uart_wr) uart_clear <= 1'b1;
    else uart_clear <= 1'b0;
end

// ========== SRAM数据总线控制 ==========
wire da_req = |da_wen || |da_ren; 
reg [31:0] base_da_out;
reg [31:0] ext_da_out;
assign ic_rrdy = !base_work;
assign da_wresp = ext_wresp || base_wresp;
assign da_rvalid = ext_rvalid || base_da_rvalid;
assign da_rdata = ext_da_out | base_da_out;
// ========== BASERAM读写信号控制 ==========
reg both_work;
reg [31:0] both_work_addr;
reg [31:0] ic_addr_save;
reg [31:0] da_addr_save;
reg [3:0] da_wstrb_save;
reg da_wr_save;
reg [31:0] da_save;
reg save_state;
reg rvalid;
reg base_ic_r_work;
reg base_da_r_work;
reg base_w_work;
reg base_da_rvalid;
reg base_wresp;
reg [31:0] base_wdata_save;
wire da_base = (da_addr >= `BASE_START) && (da_addr <= `BASE_END);
wire base_work = base_state != BASE_IDLE;
wire base_da_req = da_base && (|da_ren || |da_wen);
assign base_ram_data = base_w_work ? base_wdata_save : 32'hzzzzzzzz;
// ========== baseram状态机定义 ==========
localparam BASE_IDLE         = 3'b000;
localparam BASE_IC_READ_WAIT = 3'b001;
localparam BASE_IC_READ_DONE = 3'b010;
localparam BASE_DA_READ_WAIT = 3'b011;
localparam BASE_DA_READ_DONE = 3'b100;
localparam BASE_WRITE_WAIT   = 3'b101;
localparam BASE_WRITE_DONE   = 3'b110;

reg [2:0] base_state;
reg [2:0] base_delay; // 延迟计数器
reg [2:0] count; // 读四次数据计数

// ========== baseram状态机控制 ==========
always @(posedge aclk or negedge aresetn) begin
    if(!aresetn) begin 
        both_work <= 1'b0;
        both_work_addr <= 32'h0;
        ic_addr_save <= 32'h0;
        da_addr_save <= 32'h0; 
        da_wstrb_save <= 4'h0;
        da_wr_save <= 1'b0;
        da_save <= 32'b0;
        save_state <= 1'b0;
    end
    else begin
        if(|ic_ren && base_da_req) begin
            both_work_addr <= ic_raddr;
            both_work <= 1'b1;
            save_state <= 1'b1;
        end
        else if(base_work && base_da_req) begin
            da_addr_save <= da_addr;
            da_wstrb_save <= da_wen;
            da_wr_save <= |da_wen;
            da_save <= da_wdata;
            save_state <= 1'b1;
        end
        else begin
            if(save_state && base_state == BASE_IDLE) save_state <= 1'b0;
            if(both_work && base_state == BASE_IDLE) both_work <= 1'b0;
        end
    end
end 

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        base_state <= BASE_IDLE;
        base_delay <= 3'h0;
        count <= 3'h0;
        rvalid <= 1'b0;
        base_ic_r_work <= 1'b0;
        base_da_r_work <= 1'b0;
        base_w_work <= 1'b0;
        base_da_rvalid <= 1'b0;
        base_wresp <= 1'b0;
        ic_rvalid <= 1'b0;
        base_da_out <= 32'h0;
        ic_rdata <= 128'h0;
        
        // SRAM控制信号复位
        base_ram_ce_n <= 1'b1;
        base_ram_oe_n <= 1'b1;
        base_ram_we_n <= 1'b1;
    end 
    else begin
        if(|da_ren) base_da_out <= 32'h0;
        case(base_state)
            BASE_IDLE: begin
                ic_rvalid <= 1'b0;
                if(|ic_ren && base_da_req) begin
                    base_ram_ce_n <= 1'b0;
                    base_ram_addr <= da_addr;
                    if(|da_wen) begin
                        base_w_work <= 1'b1;
                        base_ram_oe_n <= 1'b1;
                        base_ram_be_n <= ~da_wen;
                        base_ram_we_n <= 1'b0;
                        base_wdata_save <= da_wdata;
                        base_delay <= `SRAM_WRITE_DELAY_CYCLES;
                        base_state <= BASE_WRITE_WAIT;
                    end
                    else begin
                        base_da_r_work <= 1'b1;
                        base_ram_oe_n <= 1'b0;
                        base_ram_be_n <= 4'h0;
                        base_ram_we_n <= 1'b1;
                        base_delay <= `SRAM_READ_DELAY_CYCLES;
                        base_state <= BASE_DA_READ_WAIT;
                    end
                end
                else if (save_state) begin
                    if(both_work) begin
                        count <= 3'd4;
                        base_ic_r_work <= 1'b1;
                        base_ram_ce_n <= 1'b0;
                        base_ram_oe_n <= 1'b0;
                        base_ram_be_n <= 4'h0;
                        base_ram_we_n <= 1'b1;
                        base_ram_addr <= both_work_addr;
                        base_delay <= `SRAM_READ_DELAY_CYCLES;
                        base_state <= BASE_IC_READ_WAIT;
                    end
                    else begin
                        base_da_r_work <= !da_wr_save;
                        base_w_work <= da_wr_save;
                        base_ram_ce_n <= 1'b0;
                        base_ram_oe_n <= da_wr_save;
                        base_ram_be_n <= da_wr_save ? ~da_wstrb_save : 4'h0;
                        base_ram_we_n <= !da_wr_save;
                        base_ram_addr <= da_addr_save;
                        base_wdata_save <= da_save;
                        base_delay <= da_wr_save ? `SRAM_WRITE_DELAY_CYCLES : `SRAM_READ_DELAY_CYCLES;
                        base_state <= da_wr_save ? BASE_WRITE_WAIT : BASE_DA_READ_WAIT;
                    end
                end
                else begin
                    if(|ic_ren)begin 
                        count <= 3'd4;
                        base_ic_r_work <= 1'b1;
                        base_ram_ce_n <= 1'b0;
                        base_ram_oe_n <= 1'b0;
                        base_ram_be_n <= 4'h0;
                        base_ram_we_n <= 1'b1;
                        base_ram_addr <= ic_raddr;
                        base_delay <= `SRAM_READ_DELAY_CYCLES;
                        base_state <= BASE_IC_READ_WAIT;
                    end
                    else if(|da_ren && da_base)begin  
                        base_da_r_work <= 1'b1;
                        base_ram_ce_n <= 1'b0;
                        base_ram_oe_n <= 1'b0;
                        base_ram_be_n <= 4'h0;
                        base_ram_we_n <= 1'b1;
                        base_ram_addr <= da_addr;
                        base_delay <= `SRAM_READ_DELAY_CYCLES;
                        base_state <= BASE_DA_READ_WAIT;
                    end 
                    else if(|da_wen && da_base)begin
                        base_w_work <= 1'b1;
                        base_ram_ce_n <= 1'b0;
                        base_ram_oe_n <= 1'b1;
                        base_ram_be_n <= ~da_wen;
                        base_ram_we_n <= 1'b0;
                        base_ram_addr <= da_addr;
                        base_wdata_save <= da_wdata;
                        base_delay <= `SRAM_WRITE_DELAY_CYCLES;
                        base_state <= BASE_WRITE_WAIT;
                    end
                end
            end
            
            BASE_IC_READ_WAIT: begin
                if (base_delay > 0) begin
                    base_delay <= base_delay - 1;
                end
                else begin
                    base_state <= BASE_IC_READ_DONE;
                    count <= count - 1;
                    rvalid <= 1'b1;
                end
            end
            
            BASE_IC_READ_DONE: begin
                case(count)
                    3'd0:ic_rdata[127:96] <= base_ram_data;
                    3'd1:ic_rdata[95:64]  <= base_ram_data;
                    3'd2:ic_rdata[63:32]  <= base_ram_data;
                    3'd3:ic_rdata[31:0]   <= base_ram_data;
                endcase
                rvalid <= 1'b0;
                if (!count) begin
                    ic_rvalid <= 1'b1;
                    base_state <= BASE_IDLE;
                    base_ic_r_work <= 1'b0;
                    // 关闭SRAM
                    base_ram_ce_n <= 1'b1;
                    base_ram_oe_n <= 1'b1;
                end
                else begin
                    base_delay <= `SRAM_READ_DELAY_CYCLES;
                    base_state <= BASE_IC_READ_WAIT;
                    base_ram_addr <= base_ram_addr + 32'h4;
                end
            end
            
            BASE_DA_READ_WAIT: begin
                if (base_delay > 0) begin
                    base_delay <= base_delay - 1;
                end 
                else begin
                    base_state <= BASE_DA_READ_DONE;
                    base_da_rvalid <= 1'b1;
                end
            end
            
            BASE_DA_READ_DONE: begin
                base_da_rvalid <= 1'b0;
                base_da_out <= base_ram_data;
                base_state <= BASE_IDLE;
                base_da_r_work <= 1'b0;
                // 关闭SRAM
                base_ram_ce_n <= 1'b1;
                base_ram_oe_n <= 1'b1;
            end

            
            BASE_WRITE_WAIT: begin
                if (base_delay > 0) begin
                    base_delay <= base_delay - 1;
                end 
                else begin
                    base_state <= BASE_WRITE_DONE;
                    base_wresp <= 1'b1;
                end
            end
            
            BASE_WRITE_DONE: begin
                base_wresp <= 1'b0;
                base_state <= BASE_IDLE;
                base_w_work <= 1'b0;
                // 关闭SRAM
                base_ram_ce_n <= 1'b1;
                base_ram_we_n <= 1'b1;
            end
            
            default: base_state <= BASE_IDLE;
        endcase
    end
end
// ========== EXTRAM读写信号控制 ==========
reg ext_r_work;
reg ext_w_work;
reg ext_rvalid;
reg ext_wresp;
reg [31:0] ext_wdata_save;
wire ext_work = ext_state != EXT_IDLE;
wire da_ext = (da_addr >= `EXT_START) && (da_addr <= `EXT_END);
assign ext_ram_data = ext_w_work ? ext_wdata_save : 32'hzzzzzzzz;
// ========== extram状态机定义 ==========
localparam EXT_IDLE         = 3'b000;
localparam EXT_READ_WAIT    = 3'b001;
localparam EXT_READ_DONE    = 3'b010;
localparam EXT_WRITE_WAIT   = 3'b011;
localparam EXT_WRITE_DONE   = 3'b100;

reg [2:0] ext_state;
reg [2:0] ext_delay; // 延迟计数器
// ========== extram状态机控制 ==========
always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        ext_state <= EXT_IDLE;
        ext_delay <= 3'h0;
        ext_r_work <= 1'b0;
        ext_w_work <= 1'b0;
        ext_rvalid <= 1'b0;
        ext_wresp <= 1'b0;
        ext_wdata_save <= 32'h0;
        ext_da_out <= 32'h0; 
        // SRAM控制信号复位
        ext_ram_ce_n <= 1'b1;
        ext_ram_oe_n <= 1'b1;
        ext_ram_we_n <= 1'b1;
    end 
    else begin
        if(|da_ren) ext_da_out <= 32'h0;
        case(ext_state)
            EXT_IDLE: begin
                if (|da_ren && da_ext) begin  
                    ext_ram_ce_n <= 1'b0;
                    ext_ram_oe_n <= 1'b0;
                    ext_ram_be_n <= 4'h0;
                    ext_ram_addr <= da_addr;
                    ext_r_work <= 1'b1;
                    ext_delay <= `SRAM_READ_DELAY_CYCLES;
                    ext_state <= EXT_READ_WAIT;
                end
                else if (|da_wen && da_ext) begin 
                    ext_ram_ce_n <= 1'b0;
                    ext_ram_we_n <= 1'b0;
                    ext_ram_be_n <= ~da_wen;
                    ext_ram_addr <= da_addr;
                    ext_w_work <= 1'b1;
                    ext_wdata_save <= da_wdata;
                    ext_delay <= `SRAM_WRITE_DELAY_CYCLES;
                    ext_state <= EXT_WRITE_WAIT;
                end 
            end
            
            EXT_READ_WAIT: begin
                if (ext_delay > 0) begin
                    ext_delay <= ext_delay - 1;
                end 
                else begin
                    ext_state <= EXT_READ_DONE;
                    ext_rvalid <= 1'b1;
                end
            end
            
            EXT_READ_DONE: begin
                ext_da_out <= ext_ram_data;
                ext_rvalid <= 1'b0;
                ext_state <= EXT_IDLE;
                ext_r_work <= 1'b0;
                // 关闭SRAM
                ext_ram_ce_n <= 1'b1;
                ext_ram_oe_n <= 1'b1;
            end
            
            EXT_WRITE_WAIT: begin
                if (ext_delay > 0) begin
                    ext_delay <= ext_delay - 1;
                end 
                else begin
                    ext_state <= EXT_WRITE_DONE;
                    ext_wresp <= 1'b1;
                end
            end
            
            EXT_WRITE_DONE: begin
                ext_wresp <= 1'b0;
                ext_state <= EXT_IDLE;
                ext_w_work <= 1'b0;
                // 关闭SRAM
                ext_ram_ce_n <= 1'b1;
                ext_ram_we_n <= 1'b1;
            end
            
            default: ext_state <= EXT_IDLE;
        endcase
    end
end

endmodule