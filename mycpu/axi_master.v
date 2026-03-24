`timescale 1ns / 1ps

`include "defines.vh"

module axi_master(
    input  wire         aclk,
    input  wire         aresetn,    // low active
    output wire         dc_work,
    output wire         ic_work,

    // ICache Interface
    output reg          ic_dev_rrdy  ,
    input  wire         ic_cpu_ren   ,
    input  wire [31:0]  ic_cpu_raddr ,
    output reg          ic_dev_rvalid,
    output reg  [`CACHE_BLK_SIZE-1:0] ic_dev_rdata,
    // DCache Write Data Interface
    output reg          dc_dev_wrdy  ,
    input  wire [ 3:0]  dc_cpu_wen   ,
    input  wire [31:0]  dc_cpu_waddr ,
    input  wire [31:0]  dc_cpu_wdata ,
    // DCache Read Data Interface
    output reg          dc_dev_rrdy  ,
    input  wire         dc_cpu_ren   ,
    input  wire [31:0]  dc_cpu_raddr ,
    output reg          dc_dev_rvalid,
    output reg  [`CACHE_BLK_SIZE-1:0] dc_dev_rdata,

    // AXI4 Master Interface
    // write address channel
    output wire [ 3:0]  m_axi_awid   , 
    output reg  [31:0]  m_axi_awaddr ,
    output reg  [ 7:0]  m_axi_awlen  ,
    output reg  [ 2:0]  m_axi_awsize ,
    output reg  [ 1:0]  m_axi_awburst,
    output wire [ 1:0]  m_axi_awlock ,
    output wire [ 3:0]  m_axi_awcache,
    output wire [ 2:0]  m_axi_awprot ,
    output reg          m_axi_awvalid,
    input  wire         m_axi_awready,
    // write data channel
    output wire [ 3:0]  m_axi_wid    , 
    output reg  [31:0]  m_axi_wdata  ,
    output reg  [ 3:0]  m_axi_wstrb  ,
    output wire         m_axi_wlast  ,
    output reg          m_axi_wvalid ,
    input  wire         m_axi_wready ,
    // write response channel
    input  wire [ 3:0]  m_axi_bid    , 
    output wire         m_axi_bready ,
    input  wire [ 1:0]  m_axi_bresp  ,
    input  wire         m_axi_bvalid ,
    // read address channel
    output wire [ 3:0]  m_axi_arid   , 
    output reg  [31:0]  m_axi_araddr ,
    output reg  [ 7:0]  m_axi_arlen  ,
    output reg  [ 2:0]  m_axi_arsize ,
    output reg  [ 1:0]  m_axi_arburst,
    output wire [ 1:0]  m_axi_arlock ,
    output wire [ 3:0]  m_axi_arcache,
    output wire [ 2:0]  m_axi_arprot ,
    output reg          m_axi_arvalid,
    input  wire         m_axi_arready,
    // read data channel
    input  wire [ 3:0]  m_axi_rid   ,  
    output wire         m_axi_rready,
    input  wire [31:0]  m_axi_rdata ,
    input  wire [ 1:0]  m_axi_rresp ,
    input  wire         m_axi_rlast ,
    input  wire         m_axi_rvalid
);

    assign m_axi_awid    = 4'h8;
    assign m_axi_awlock  = 2'h0;
    assign m_axi_awcache = 4'h2;
    assign m_axi_awprot  = 3'h0;
    assign m_axi_wid     = 4'h8;
    assign m_axi_arid    = 4'h8;
    assign m_axi_arlock  = 2'h0;
    assign m_axi_arcache = 4'h2;
    assign m_axi_arprot  = 3'h0;

    wire has_dc_wr_req = dc_dev_wrdy & (dc_cpu_wen != 4'h0);
    wire has_dc_rd_req = dc_cpu_ren;    // 是否有DCache读请求
    wire has_ic_rd_req = ic_cpu_ren;    // 是否有ICache读请求
    wire has_rd_req    = has_dc_rd_req | has_ic_rd_req;    // 是否有读请求

    reg  dc_do , ic_do;
    assign dc_work = dc_do;
    assign ic_work = ic_do;
    ///////////////////////////////////////////////////////////////////////////
    // read address channel
    // 给AR通道的输出信号赋值 
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_axi_araddr  <= 32'h0;
            m_axi_arvalid <= 1'b0;
            dc_do <= 1'b0;
            ic_do <= 1'b0;
        end 
        else begin
            if (m_axi_arvalid & m_axi_arready) begin
                m_axi_arvalid <= 1'b0;
                m_axi_arlen   <= 8'h0;
                m_axi_arsize  <= 3'h0;
                m_axi_arburst <= 2'h0;
                m_axi_araddr  <= 32'h0;
            end 
            else if(has_dc_rd_req) begin
                    m_axi_araddr  <= dc_cpu_raddr;
                    m_axi_arlen   <= 8'h1 - 1;      
                    m_axi_arsize  <= 3'h2;          
                    m_axi_arburst <= 2'h1;         
                    m_axi_arvalid <= 1'b1;
                    dc_do         <= 1'b1;
                end
            else if(has_ic_rd_req)begin
                    m_axi_araddr  <= ic_cpu_raddr;
                    m_axi_arlen   <= 8'h4 - 1;      
                    m_axi_arsize  <= 3'h2;          
                    m_axi_arburst <= 2'h1;          
                    m_axi_arvalid <= 1'b1;
                    ic_do         <= 1'b1;
                end
            if (ic_dev_rvalid | dc_dev_rvalid) begin
                dc_do <= 1'b0;
                ic_do <= 1'b0;
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // read data channel
    // 给ic_dev_rrdy、dc_dev_rrdy信号赋值（接收到读请求后ready置0，读请求处理完成后置1）
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ic_dev_rrdy <= 1'h1;
            dc_dev_rrdy <= 1'h1;
        end 
        else begin
            if (ic_cpu_ren | dc_cpu_ren) begin
                ic_dev_rrdy <= 1'h0;
                dc_dev_rrdy <= 1'h0;
            end 
            else if (ic_dev_rvalid | dc_dev_rvalid) begin
                ic_dev_rrdy <= 1'h1;
                dc_dev_rrdy <= 1'h1;
            end
        end
    end

    // 给ic_dev_rvalid、dc_dev_rvalid信号赋值（返回给Cache的数据块就绪后置1）
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ic_dev_rvalid <= 1'h0;
            dc_dev_rvalid <= 1'h0;
        end
        else if (dc_dev_rvalid | ic_dev_rvalid) begin
            ic_dev_rvalid <= 1'h0;
            dc_dev_rvalid <= 1'h0;
        end 
        else if (m_axi_rlast & dc_do & m_axi_rvalid) begin
                dc_dev_rvalid <= 1'h1;
            end 
        else if (m_axi_rlast & ic_do & m_axi_rvalid) begin
                ic_dev_rvalid <= 1'h1;
            end   
    end

    // 从总线上接收读数据，生成DCache重填所需的数据块dc_dev_rdata及ICache重填所需的数据块ic_dev_rdata 
    reg [1:0] count;
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            dc_dev_rdata <= 128'h0;
            ic_dev_rdata <= 128'h0;
            count <= 2'h0;
        end 
        else if (has_rd_req) begin
            count <= 2'h0;
        end
        else if (m_axi_rvalid & dc_do) begin
            dc_dev_rdata <= {96'h0, m_axi_rdata};
        end 
        else if (m_axi_rvalid & ic_do) begin
            case(count)
            2'h0 : begin
                ic_dev_rdata[31:0] <= m_axi_rdata;
                count     <= 2'h1;
            end
            2'h1 : begin
                ic_dev_rdata[63:32] <= m_axi_rdata;
                count     <= 2'h2;
            end
            2'h2 : begin
                ic_dev_rdata[95:64] <= m_axi_rdata;
                count     <= 2'h3;
            end
            2'h3 : begin
                ic_dev_rdata[127:96] <= m_axi_rdata;
                count     <= 2'h0;
            end
            endcase
        end 
    end

    assign m_axi_rready = !aresetn ? 1'b0 : 1'b1;

    /******** 不要修改以下代码 ********/
    ///////////////////////////////////////////////////////////////////////////
    // write address channel
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_axi_awaddr  <= 32'h0;
            m_axi_awvalid <= 1'b0;
        end else begin
            if (m_axi_awvalid & m_axi_awready) begin
                m_axi_awvalid <= 1'b0;
                m_axi_awlen   <= 8'h0;
                m_axi_awsize  <= 3'h0;
                m_axi_awburst <= 2'h0;
            end else if (has_dc_wr_req) begin
                m_axi_awaddr  <= dc_cpu_waddr;
                m_axi_awlen   <= 8'h1 - 1;      // 1 packages each transaction
                m_axi_awsize  <= 3'h2;          // 2^2 bytes per package
                m_axi_awburst <= 2'h1;          // INCR addressing mode
                m_axi_awvalid <= 1'b1;
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // write data channel
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_axi_wdata  <= 32'h0;
            m_axi_wstrb  <= 4'h0;
            m_axi_wvalid <= 1'b0;
        end else begin
            if (m_axi_wvalid & m_axi_wready) begin
                m_axi_wvalid <= 1'b0;
            end else if (has_dc_wr_req) begin
                m_axi_wdata  <= dc_cpu_wdata;
                m_axi_wstrb  <= dc_cpu_wen;
                m_axi_wvalid <= 1'b1;
            end
        end
    end

    assign m_axi_wlast = m_axi_wvalid;

    ///////////////////////////////////////////////////////////////////////////
    // write response channel
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            dc_dev_wrdy     <= 1'b1;
        end else begin
            if (m_axi_bvalid) begin
                dc_dev_wrdy <= 1'b1;
            end else if (has_dc_wr_req) begin
                dc_dev_wrdy <= 1'b0;
            end
        end
    end

    assign m_axi_bready = !aresetn ? 1'b0 : 1'b1;

endmodule