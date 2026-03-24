`timescale 1ns / 1ps

`include "defines.vh"

module inst_cache(
    input  wire         cpu_clk,
    input  wire         cpu_rstn,                // low active
    input  wire         pred_error, 
    // Interface to CPU
    input  wire         inst_rreq,               // 来自CPU的取指请�?
    input  wire [31:0]  inst_addr,               // 来自CPU的取指地�?
    output wire         inst_valid,              // 输出给CPU的指令有效信号（读指令命中）
    output reg  [31:0]  inst_out,                // 输出给CPU的指�?
    output wire         inst_busy,               // 输出给CPU的取指忙信号
    // Interface to Read Bus
    input  wire         dev_rrdy,                // 主存就绪信号（高电平表示主存可接收ICache的读请求�?
    output reg  [ 3:0]  cpu_ren,                 // 输出给主存的读使能信�?
    output reg  [31:0]  cpu_raddr,               // 输出给主存的读地�?
    input  wire         dev_rvalid,              // 来自主存的数据有效信�?
    input  wire [`CACHE_BLK_SIZE-1:0] dev_rdata  // 来自主存的读数据
);

`ifdef ENABLE_ICACHE    /******** 不要修改此行代码 ********/

    assign inst_busy = (current_state == REFILL);
    // 主存地址分解
    wire [11:0]  tag_from_cpu   = inst_addr[21:10];     // 主存地址的TAG
    wire [5:0]  cache_index    = inst_addr[9:4];      // 主存地址的Cache索引 / ICache存储体的地址
    wire [1:0]  offset         = inst_addr[3:2];       // 32位字偏移�?

    wire [127:0] cache_line_r0 = cache_mem0[cache_index];    // 0路数据                         
    wire [127:0] cache_line_r1 = cache_mem1[cache_index];    // 1路数据                         
    wire         valid_bit0    = valid0[cache_index];        // 0路有效位
    wire         valid_bit1    = valid1[cache_index];        // 1路有效位
    wire [11:0]  tag_from_set0 = tag0[cache_index];          // 0路标签
    wire [11:0]  tag_from_set1 = tag1[cache_index];          // 1路标签
    
    reg [63:0] valid0;            
    reg [11:0]   tag0 [0:63]; 
    reg [127:0] cache_mem0 [0:63];               
    reg [63:0] valid1;           
    reg [11:0]   tag1 [0:63];   
    reg [127:0] cache_mem1 [0:63];        

    // 定义ICache状�?�机的状态变�?
    localparam IDLE      = 1'b0;
    localparam REFILL    = 1'b1;

    reg current_state;   
    reg next_state;       

    // �?保证命中时，hit信号仅有�?1个时钟周�?
    wire hit0 = valid_bit0 && (tag_from_cpu == tag_from_set0);     // Cache组内�?0块的命中信号
    wire hit1 = valid_bit1 && (tag_from_cpu == tag_from_set1);     // Cache组内�?1块的命中信号
    wire hit  = (hit0 | hit1) & inst_rreq & (current_state == IDLE);

    wire [`CACHE_BLK_SIZE-1:0] hit_data_blk = {`CACHE_BLK_SIZE{hit0}} & cache_line_r0[`CACHE_BLK_SIZE-1:0] |
                                              {`CACHE_BLK_SIZE{hit1}} & cache_line_r1[`CACHE_BLK_SIZE-1:0];

    // 根据字偏移，选择组内命中的Cache行中的某�?32位字作为输出
    assign inst_valid = hit;
    always @(*)begin
        if(hit)begin
            case(offset)
            2'h0 : inst_out = hit_data_blk[31:0];
            2'h1 : inst_out = hit_data_blk[63:32];
            2'h2 : inst_out = hit_data_blk[95:64];
            2'h3 : inst_out = hit_data_blk[127:96];
            endcase
        end
        else inst_out = 32'h0;
    end
    
    // LSFR的实�?   
    reg        load;     
    reg  [2:0] seed;     
    reg  [2:0] rand_num; 
    
    always @(posedge cpu_clk)begin                                        
        if(inst_addr[2:0]) seed <= inst_addr[2:0];                             
    end                                          

    always @(posedge cpu_clk or negedge cpu_rstn)begin
        if(!cpu_rstn)begin
            rand_num <= 3'b1;
            load     <= 1'b1;
        end 
        else if(load && seed)begin	
            rand_num <= seed; 
            load     <= 1'b0;
        end    
        else begin
                rand_num[0] <= rand_num[2];
                rand_num[1] <= rand_num[0];
                rand_num[2] <= rand_num[1] ^ rand_num[2];
             end   
    end

    // 记录第i个Cache组内的Cache块的被访问情况（比如�?0被访问，则置use_bit[i]�?01，块1被访问则置use_bit[i]�?10），用于实现Cache块替换
    wire         cache_we0    = (!valid_bit0 | (valid_bit0 & valid_bit1 & !rand_num[0])) & dev_rvalid;                 // ICache存储�?0的写使能信号
    wire         cache_we1    = ((valid_bit0 & !valid_bit1) | (valid_bit0 & valid_bit1 & rand_num[0])) & dev_rvalid;   // ICache存储�?1的写使能信号
    wire [127:0] cache_line_w = dev_rdata;                                                    // 待写入ICache的Cache�?
    reg    [5:0] cache_index_r;

    always @(posedge cpu_clk or negedge cpu_rstn) begin
        if (!cpu_rstn) cache_index_r <= 6'h0;
        else if((next_state == REFILL) & (current_state == IDLE)) cache_index_r <= cache_index;
    end

    always @(posedge cpu_clk or negedge cpu_rstn) begin
        if (!cpu_rstn) begin
            valid0 <= 64'h0;
            valid1 <= 64'h0;
        end
        else begin
            if (cache_we0) begin
                cache_mem0[cache_index_r] <= cache_line_w;
                valid0[cache_index_r] <= 1'h1; 
                tag0[cache_index_r] <= tag_from_cpu;
            end
            else if (cache_we1) begin
                cache_mem1[cache_index_r] <= cache_line_w;
                valid1[cache_index_r] <= 1'h1;
                tag1[cache_index_r] <= tag_from_cpu;
            end
        end
    end

    // 状�?�机现�?�的更新逻辑
    always @(posedge cpu_clk or negedge cpu_rstn) begin
        if (!cpu_rstn) current_state <= IDLE;
        else           current_state <= next_state;
    end
    
    // 状�?�机的状态转移�?�辑
    always @(*) begin
        case (current_state)
            IDLE    :  if (~(hit0 | hit1) & inst_rreq & !pred_error) next_state = REFILL;
                       else            next_state = IDLE;
            REFILL   : if (dev_rvalid) next_state = IDLE;
                       else            next_state = REFILL;
            default  :                 next_state = IDLE;
        endcase
    end

    // 生成状�?�机的输出信号：访存请求（即cpu_raddr和cpu_ren）的生成
    always @(*) begin
        if (!cpu_rstn) begin
            cpu_ren    = 4'h0;
            cpu_raddr  = 32'h0;
        end
        else begin
            case (current_state)
                REFILL: begin
                            if(dev_rrdy & !dev_rvalid) begin
                                cpu_ren   = 4'hF;        
                                cpu_raddr = {inst_addr[31:4] , 4'h0};
                            end
                            else begin
                                cpu_ren   = 4'h0;        
                            end
                        end
                default:begin
                            cpu_ren = 4'h0;
                        end
            endcase
        end
    end

    /******** 不要修改以下代码 ********/
`else

    localparam IDLE  = 2'b00;
    localparam STAT0 = 2'b01;
    localparam STAT1 = 2'b11;
    reg [1:0] state, nstat;

    always @(posedge cpu_clk or negedge cpu_rstn) begin
        state <= !cpu_rstn ? IDLE : nstat;
    end

    always @(*) begin
        case (state)
            IDLE:    nstat = inst_rreq ? (dev_rrdy ? STAT1 : STAT0) : IDLE;
            STAT0:   nstat = dev_rrdy ? STAT1 : STAT0;
            STAT1:   nstat = dev_rvalid ? IDLE : STAT1;
            default: nstat = IDLE;
        endcase
    end

    always @(posedge cpu_clk or negedge cpu_rstn) begin
        if (!cpu_rstn) begin
            inst_valid <= 1'b0;
            cpu_ren    <= 4'h0;
        end else begin
            case (state)
                IDLE: begin
                    inst_valid <= 1'b0;
                    cpu_ren    <= (inst_rreq & dev_rrdy) ? 4'hF : 4'h0;
                    cpu_raddr  <= inst_rreq ? inst_addr : 32'h0;
                end
                STAT0: begin
                    cpu_ren    <= dev_rrdy ? 4'hF : 4'h0;
                end
                STAT1: begin
                    cpu_ren    <= 4'h0;
                    inst_valid <= dev_rvalid ? 1'b1 : 1'b0;
                    inst_out   <= dev_rvalid ? dev_rdata[31:0] : 32'h0;
                end
                default: begin
                    inst_valid <= 1'b0;
                    cpu_ren    <= 4'h0;
                end
            endcase
        end
    end

`endif

endmodule
