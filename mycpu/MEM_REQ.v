`timescale 1ns / 1ps

`include "defines.vh"

module MEM_REQ (
    input  wire         clk,
    input  wire         rstn,
    input  wire         ex_valid,
    input  wire [ 1:0]  mem_wd_sel,
    input  wire [31:0]  mem_ram_addr,

    input  wire [ 2:0]  mem_ram_ext_op,
    output reg  [ 3:0]  da_ren,
    output reg  [31:0]  da_addr,

    input  wire [ 3:0]  mem_ram_we,
    input  wire [31:0]  mem_ram_wdata,
    output reg  [ 3:0]  da_wen,
    output reg  [31:0]  da_wdata,

    input  wire         suspend
);

// send_ldst_req用于确保读写请求只有效一个clk
reg        send_ldst_req;       // only valid in the first clk of mem stage
wire [1:0] offset = mem_ram_addr[1:0];
reg        delay;

/*always @(posedge clk or negedge rstn) begin
    if (!rstn) delay <= 1'b1;
    else if (da_ren | da_wen) delay <= 1'b0;  
    else delay <= 1'b1; 
end

always @(posedge clk or negedge rstn) begin
    if (!rstn) send_ldst_req <= 1'b0;
    else send_ldst_req <= ex_valid & !suspend;
end

always @(*) begin
    if (!rstn) begin
        da_ren        = 4'h0;
        da_wen        = 4'h0;
        da_addr       = 32'h0;
    end else begin
        if ((da_wen != 4'h0 | da_ren != 4'h0) & !delay) begin
            da_wen = 4'h0;
            da_ren = 4'h0;
        end
        // 通过mem_wd_sel的值判断当前是否是访存指令
        else if (send_ldst_req & (mem_wd_sel == `WD_RAM)) begin
            
            da_addr = {mem_ram_addr[31:2], 2'h0};          // 访存地址按字对齐
            
            // 通过mem_ram_we判断指令是store还是load，如果是store，具体是哪一条store
            case (mem_ram_we)
                `RAM_WE_B:begin
                    da_ren = 4'h0;                                           // st.b
                    case(offset)
                        2'h0:begin
                            da_wen  = 4'h1;
                            da_wdata = mem_ram_wdata[7:0];
                        end 
                        2'h1:begin
                            da_wen  = 4'h2;
                            da_wdata[15:8] = mem_ram_wdata[7:0];
                        end 
                        2'h2:begin
                            da_wen  = 4'h4;
                            da_wdata[23:16] = mem_ram_wdata[7:0];
                        end 
                        2'h3:begin
                            da_wen  = 4'h8;
                            da_wdata[31:24] = mem_ram_wdata[7:0];
                        end 
                    endcase
                end
                `RAM_WE_H:begin 
                    da_ren = 4'h0;                                               // st.h
                    case(offset)
                        2'h0:begin
                            da_wen  = 4'h3;
                            da_wdata = mem_ram_wdata[15:0];
                        end 
                        2'h2:begin
                            da_wen  = 4'hC;
                            da_wdata[31:16] = mem_ram_wdata[15:0];
                        end 
                        2'h1 , 2'h3:begin
                            da_wen  = 4'h0;
                            da_wdata = 32'h0;
                        end 
                    endcase
                end
                `RAM_WE_W:begin 
                    da_ren = 4'h0;                                               // st.w
                    case(offset)
                        2'h0:begin
                            da_wen  = 4'hF;
                            da_wdata = mem_ram_wdata;
                        end 
                        2'h1 , 2'h2 , 2'h3:begin
                            da_wen  = 4'h0;
                            da_wdata = 32'h0;
                        end 
                    endcase
                end
                default: begin
                    da_wen = 4'h0;
                    // 通过mem_ram_ext_op判断load指令具体是哪一条load
                    case (mem_ram_ext_op)
                        `RAM_EXT_HS , `RAM_EXT_HU:                        // ld.h
                            if (offset == 2'h0 || offset == 2'h2)
                                da_ren = 4'hF;
                        `RAM_EXT_BS , `RAM_EXT_BU:                        // ld.b
                                da_ren = 4'hF;
                        `RAM_EXT_W:                                       // ld.w
                            if (offset == 2'h0)
                                da_ren = 4'hF;
                        default:                            
                                da_ren = 4'hF;
                    endcase
                end
            endcase
        end
        else if(mem_wd_sel != `WD_RAM) begin
            da_wen = 4'h0;
            da_ren = 4'h0;
        end
    end
end*/

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        send_ldst_req <= 1'b0;
        da_ren        <= 4'h0;
        da_wen        <= 4'h0;
        da_addr       <= 32'h0;
    end else begin
        send_ldst_req <= ex_valid & !suspend;
        if (da_ren != 4'h0) da_ren  <= 4'h0;
        if (da_wen != 4'h0) da_wen  <= 4'h0;

        // 通过mem_wd_sel的值判断当前是否是访存指令
        if (send_ldst_req & (mem_wd_sel == `WD_RAM)) begin
            
            da_addr <= {mem_ram_addr[31:2], 2'h0};          // 访存地址按字对齐
            
            // 通过mem_ram_we判断指令是store还是load，如果是store，具体是哪一条store
            case (mem_ram_we)
                `RAM_WE_B:begin                                           // st.b
                    case(offset)
                        2'h0:begin
                            da_wen  <= 4'h1;
                            da_wdata <= mem_ram_wdata[7:0];
                        end 
                        2'h1:begin
                            da_wen  <= 4'h2;
                            da_wdata[15:8] <= mem_ram_wdata[7:0];
                        end 
                        2'h2:begin
                            da_wen  <= 4'h4;
                            da_wdata[23:16] <= mem_ram_wdata[7:0];
                        end 
                        2'h3:begin
                            da_wen  <= 4'h8;
                            da_wdata[31:24] <= mem_ram_wdata[7:0];
                        end 
                    endcase
                end
                `RAM_WE_H:                                                // st.h
                    case(offset)
                        2'h0:begin
                            da_wen  <= 4'h3;
                            da_wdata <= mem_ram_wdata[15:0];
                        end 
                        2'h2:begin
                            da_wen  <= 4'hC;
                            da_wdata[31:16] <= mem_ram_wdata[15:0];
                        end 
                        2'h1 , 2'h3:begin
                            da_wen  <= 4'h0;
                            da_wdata <= 32'h0;
                        end 
                    endcase
                `RAM_WE_W:                                                // st.w
                    case(offset)
                        2'h0:begin
                            da_wen  <= 4'hF;
                            da_wdata <= mem_ram_wdata;
                        end 
                        2'h1 , 2'h2 , 2'h3:begin
                            da_wen  <= 4'h0;
                            da_wdata <= 32'h0;
                        end 
                    endcase
                default: begin
                    // 通过mem_ram_ext_op判断load指令具体是哪一条load
                    case (mem_ram_ext_op)
                        `RAM_EXT_HS , `RAM_EXT_HU:                        // ld.h
                            if (offset == 2'h0 || offset == 2'h2)
                                da_ren <= 4'hF;
                        `RAM_EXT_BS , `RAM_EXT_BU:                        // ld.b
                                da_ren <= 4'hF;
                        `RAM_EXT_W:                                       // ld.w
                            if (offset == 2'h0)
                                da_ren <= 4'hF;
                        default:                            
                                da_ren <= 4'hF;
                    endcase
                end
            endcase
        end
    end
end

endmodule
