`define ENABLE_ICACHE

`define CACHE_BLK_LEN  4
`define CACHE_BLK_SIZE (`CACHE_BLK_LEN*32)

// PC复位初始值
`define PC_INIT_VAL     32'h80000000

// NPC op
`define NPC_PC4  2'b00
`define NPC_PC18 2'b01
`define NPC_PC28 2'b10
`define NPC_PCRJ 2'b11

// 立即数扩展op
`define EXT_20   3'b110
`define EXT_12S  3'b111
`define EXT_12U  3'b100
`define EXT_5    3'b101
`define EXT_18   3'b001
`define EXT_28   3'b010
`define EXT_NONE 3'b000

// Load指令读数据后的扩展op
`define RAM_EXT_HS  3'b001
`define RAM_EXT_HU  3'b010
`define RAM_EXT_BS  3'b011
`define RAM_EXT_BU  3'b100
`define RAM_EXT_W   3'b101
`define RAM_EXT_N   3'b000

// Store指令写数据op
`define RAM_WE_N 4'b0000
`define RAM_WE_B 4'b0001
`define RAM_WE_H 4'b0010
`define RAM_WE_W 4'b0011

// ALU op
`define ALU_ADD    5'b00000
`define ALU_OR     5'b00001
`define ALU_SUB    5'b00010
`define ALU_AND    5'b00011
`define ALU_XOR    5'b00100
`define ALU_NOR    5'b00101
`define ALU_SLL    5'b00110
`define ALU_SRL    5'b00111
`define ALU_SRA    5'b01000
`define ALU_SLT    5'b01001
`define ALU_SLTU   5'b01010
`define ALU_MUL    5'b01011
`define ALU_MULH   5'b01100
`define ALU_MULHU  5'b01101
`define ALU_LU12I  5'b01110
`define ALU_MOD    5'b10000
`define ALU_DIV    5'b10001
`define ALU_MODU   5'b10010
`define ALU_DIVU   5'b10011
`define ALU_BEQ    5'b10100
`define ALU_BNE    5'b10101
`define ALU_BGE    5'b10110
`define ALU_BGEU   5'b10111
`define ALU_BLT    5'b11000
`define ALU_BLTU   5'b11001
`define ALU_JIRL   5'b11010
`define ALU_B_BL   5'b11011

// 指令译码相关
`define FR5_ADD   5'b00000
`define FR5_SUB   5'b00010
`define FR5_AND   5'b01001
`define FR5_OR    5'b01010
`define FR5_XOR   5'b01011
`define FR5_NOR   5'b01000
`define FR5_SLL   5'b01110
`define FR5_SRL   5'b01111
`define FR5_SRA   5'b10000
`define FR5_SLT   5'b00100
`define FR5_SLTU  5'b00101
`define FR5_MUL   5'b11000
`define FR5_MULH  5'b11001
`define FR5_MULHU 5'b11010
`define FR5_MOD   5'b00001
`define FR5_MODU  5'b00011
`define FR5_DIV   5'b00000
`define FR5_DIVU  5'b00010

`define FR5_SLLI  5'b00001
`define FR5_SRLI  5'b01001
`define FR5_SRAI  5'b10001

`define FR3_ORI    3'b110
`define FR3_ADDI   3'b010
`define FR3_ANDI   3'b101
`define FR3_XORI   3'b111
`define FR3_SLTI   3'b000
`define FR3_SLTUI  3'b001
`define FR3_LD_B   3'b000
`define FR3_LD_BU  3'b000
`define FR3_LD_H   3'b001
`define FR3_LD_HU  3'b001
`define FR3_LD_W   3'b010
`define FR3_ST_B   3'b100
`define FR3_ST_H   3'b101
`define FR3_ST_W   3'b110

// 源操作数2的选择：选择rk或rd
`define R2_RK  1'b1
`define R2_RD  1'b0

// 目的操作数的选择：选择rd或r1
`define WR_RD   1'b1
`define WR_Rr1  1'b0

// 写数据选择：选择将ALU数据或将读主存的数据或者将PC+4的地址写回寄存器堆
`define WD_ALU  2'b11
`define WD_RAM  2'b01
`define WD_PC4  2'b10

// ALU操作数A的选择：选择源寄存器1或PC值
`define ALUA_R1  1'b1
`define ALUA_PC  1'b0

// ALU操作数B的选择：选择源寄存器2或立即数
`define ALUB_R2  1'b1
`define ALUB_EXT 1'b0

// 串口寄存器
`define SerialState 32'hBFD003FC
`define SerialData  32'hBFD003F8

// Baseram与Extram的起始地址
`define BASE_START 32'h80000000
`define BASE_END   32'h803FFFFF
`define EXT_START  32'h80400000
`define EXT_END    32'h807FFFFF

// sram读写时钟延迟
`define SRAM_READ_DELAY_CYCLES  1  // 读操作延迟周期数 
`define SRAM_WRITE_DELAY_CYCLES 1  // 写操作延迟周期数

// 发送接收模块时钟频率
`define CPU_CLOCK 160000000
