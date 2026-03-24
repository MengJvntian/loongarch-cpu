`timescale 1ns / 1ps

`include "defines.vh"

module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,

    inout  wire [31:0] base_ram_data,
    output wire [19:0] base_ram_addr,
    output wire [ 3:0] base_ram_be_n,
    output wire        base_ram_ce_n,
    output wire        base_ram_oe_n,
    output wire        base_ram_we_n,

    inout  wire [31:0] ext_ram_data,
    output wire [19:0] ext_ram_addr,
    output wire [ 3:0] ext_ram_be_n,
    output wire        ext_ram_ce_n,
    output wire        ext_ram_oe_n,
    output wire        ext_ram_we_n,
     
    output wire        txd,
    input  wire        rxd
);
// ICache Interface
wire        cpu2ic_rreq  ;
wire [31:0] cpu2ic_addr  ;
wire        ic2cpu_valid ;
wire [31:0] ic2cpu_inst  ;
wire        ic2cpu_busy  ;

wire        dev2ic_rrdy  ;
wire [ 3:0] ic2dev_ren   ;
wire [31:0] ic2dev_raddr ;
wire        dev2ic_rvalid;
wire [`CACHE_BLK_SIZE-1:0] dev2ic_rdata;

wire        pred_error   ;

// Data Access Interface
wire [ 3:0] cpu2dc_ren   ;
wire [31:0] cpu2dc_addr  ;
wire        dc2cpu_valid ;
wire [31:0] dc2cpu_rdata ;
wire [ 3:0] cpu2dc_wen   ;
wire [31:0] cpu2dc_wdata ;
wire        dc2cpu_wresp ;

wire [31:0]  serial_t;
wire [31:0]  serial_addr;
wire [31:0]  serial_o;
wire         serial_f;
wire         serial_w;
wire [31:0]  dcr_data; // 读回给CPU的数据,从串口或从cache
wire [ 3:0]  dc_ren; // dcache真正读信号
wire [ 3:0]  dc_wen; // dcache真正写信号
wire         dc_addr_ser; // 地址为串口地址
wire [31:0]  base_ram_addr0;
wire [31:0]  ext_ram_addr0;

assign dc_addr_ser = !aresetn ? 1'h0 : (cpu2dc_addr == `SerialData) | (cpu2dc_addr == `SerialState);
assign serial_t = aresetn & (cpu2dc_addr == `SerialData) ? cpu2dc_wdata : 32'h0;
assign serial_addr = aresetn & dc_addr_ser & (cpu2dc_ren | cpu2dc_wen) ? cpu2dc_addr : 32'h0;
assign serial_w = !aresetn ? 1'h0 : cpu2dc_wen && dc_addr_ser;
assign dcr_data = !aresetn ? 32'h0 : dc_addr_ser ? serial_o : dc2cpu_rdata;
assign dc_ren = !aresetn ? 4'h0 : cpu2dc_ren & {4{!dc_addr_ser}};
assign dc_wen = !aresetn ? 4'h0 : cpu2dc_wen & {4{!dc_addr_ser}};
assign base_ram_addr = base_ram_addr0[21:2];
assign ext_ram_addr = ext_ram_addr0[21:2];                                      

myCPU u_mycpu (
    .cpu_rstn   (aresetn),
    .cpu_clk    (aclk),

    .serial_f       (serial_f),
    // Instruction Fetch Interface
    .ifetch_rreq    (cpu2ic_rreq ),
    .ifetch_addr    (cpu2ic_addr ),
    .ifetch_valid   (ic2cpu_valid),
    .ifetch_inst    (ic2cpu_inst ),
    .ifetch_busy    (ic2cpu_busy ),
    .pred_error     (pred_error  ),
    
    // Data Access Interface
    .daccess_ren    (cpu2dc_ren  ),
    .daccess_addr   (cpu2dc_addr ),
    .daccess_valid  (dc2cpu_valid),
    .daccess_rdata  (dcr_data),
    .daccess_wen    (cpu2dc_wen  ),
    .daccess_wdata  (cpu2dc_wdata),
    .daccess_wresp  (dc2cpu_wresp)

);

inst_cache U_icache (
    .cpu_clk        (aclk),
    .cpu_rstn       (aresetn),
    .pred_error     (pred_error),
    // Interface to CPU
    .inst_rreq      (cpu2ic_rreq),
    .inst_addr      (cpu2ic_addr),
    .inst_valid     (ic2cpu_valid),
    .inst_out       (ic2cpu_inst),
    .inst_busy      (ic2cpu_busy),
    // Interface to Bus
    .dev_rrdy       (dev2ic_rrdy),
    .cpu_ren        (ic2dev_ren),
    .cpu_raddr      (ic2dev_raddr),
    .dev_rvalid     (dev2ic_rvalid),
    .dev_rdata      (dev2ic_rdata)
);



sram_uart U_sramuart(
    .aclk               (aclk),  
    .aresetn            (aresetn),

    // 串口专用
    .serial_t           (serial_t[7:0]),
    .serial_addr        (serial_addr),
    .serial_o           (serial_o),
    .serial_f           (serial_f),
    .serial_w           (serial_w),
    
    // icache接口
    .ic_rrdy            (dev2ic_rrdy),
    .ic_ren             (ic2dev_ren),
    .ic_raddr           (ic2dev_raddr),
    .ic_rvalid          (dev2ic_rvalid),
    .ic_rdata           (dev2ic_rdata),

    // 数据读写
    .da_ren             (dc_ren      ),
    .da_addr            (cpu2dc_addr ),
    .da_rvalid          (dc2cpu_valid),
    .da_rdata           (dc2cpu_rdata),
    .da_wen             (dc_wen      ),
    .da_wdata           (cpu2dc_wdata),
    .da_wresp           (dc2cpu_wresp),
    
    .base_ram_data      (base_ram_data),
    .base_ram_addr      (base_ram_addr0),
    .base_ram_be_n      (base_ram_be_n),
    .base_ram_ce_n      (base_ram_ce_n),
    .base_ram_oe_n      (base_ram_oe_n),
    .base_ram_we_n      (base_ram_we_n),

    .ext_ram_data       (ext_ram_data),
    .ext_ram_addr       (ext_ram_addr0),
    .ext_ram_be_n       (ext_ram_be_n),
    .ext_ram_ce_n       (ext_ram_ce_n),
    .ext_ram_oe_n       (ext_ram_oe_n),
    .ext_ram_we_n       (ext_ram_we_n),
     
    .txd                (txd),
    .rxd                (rxd)
);

endmodule