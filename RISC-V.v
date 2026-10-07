`timescale 1ns/1ps

// ============================================================
// 32-bit RISC-V Single-Cycle Processor (RV32I subset)
// Corrected and cleaned RTL implementation
// ============================================================

// ------------------------------------------------------------
// PC Register
// ------------------------------------------------------------
module pcreg (
    input        clk,
    input        reset,
    input [31:0] pc_nxt,
    output reg [31:0] pc
);

    always @(negedge clk or posedge reset) begin
        if (reset)
            pc <= 32'd0;
        else
            pc <= pc_nxt;
    end

endmodule

// ------------------------------------------------------------
// PC + 4 Adder
// ------------------------------------------------------------
module pcadder (
    input  [31:0] pc,
    output [31:0] pcadd
);

    assign pcadd = pc + 32'd4;

endmodule

// ------------------------------------------------------------
// Branch Target Adder
// ------------------------------------------------------------
module pcbranchadder (
    input  [31:0] pc,
    input  [31:0] imm,
    output [31:0] pcnxt
);

    assign pcnxt = pc + imm;

endmodule

// ------------------------------------------------------------
// Next-PC MUX
// PCSrc:
// 00 -> PC + 4
// 01 -> Branch target
// 10 -> Jump/JALR target (ALU output)
// ------------------------------------------------------------
module pcmux (
    input  [31:0] pcadd,
    input  [31:0] pcbranch,
    input  [31:0] pcjump,
    input  [1:0]  PCSrc,
    output reg [31:0] pc_nxt
);

    always @(*) begin
        case (PCSrc)
            2'b00:   pc_nxt = pcadd;
            2'b01:   pc_nxt = pcbranch;
            2'b10:   pc_nxt = pcjump;
            default: pc_nxt = pcadd;
        endcase
    end

endmodule

// ------------------------------------------------------------
// Immediate Extension Unit
// ImmSrc:
// 00 -> I-type / Load
// 01 -> S-type / Store
// 10 -> B-type / Branch
// imm5 -> shift amount for SLLI/SRLI/SRAI
// ------------------------------------------------------------
module imm_extend (
    input  [1:0]  immSrc,
    input  [31:0] inst,
    output reg [31:0] imm,
    output reg [31:0] imm5
);

    always @(*) begin
        // Defaults prevent inferred latches.
        imm  = 32'd0;
        imm5 = 32'd0;

        case (immSrc)
            2'b00: begin
                // I-type / Load immediate: bits [31:20]
                imm  = {{20{inst[31]}}, inst[31:20]};
                imm5 = {{27{1'b0}}, inst[24:20]};
            end

            2'b01: begin
                // S-type immediate: imm[11:5] = inst[31:25]
                //                    imm[4:0] = inst[11:7]
                imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            end

            2'b10: begin
                // B-type immediate:
                // imm[12]   = inst[31]
                // imm[11]   = inst[7]
                // imm[10:5] = inst[30:25]
                // imm[4:1]  = inst[11:8]
                // imm[0]    = 0
                imm = {{19{inst[31]}}, inst[31], inst[7],
                       inst[30:25], inst[11:8], 1'b0};
            end

            default: begin
                imm  = 32'd0;
                imm5 = 32'd0;
            end
        endcase
    end

endmodule

// ------------------------------------------------------------
// Register File
// 32 x 32-bit registers
// Two asynchronous read ports and one synchronous write port.
// x0 is protected from writes and remains 0.
// ------------------------------------------------------------
module reg_file (
    input  [31:0] inst,
    input  [31:0] Wr_Data,
    input         wr_enable,
    input         clk,
    output [31:0] data_rs1,
    output [31:0] data_rs2
);

    reg [31:0] register [0:31];
    wire [4:0] rs1, rs2, rd;
    integer i;

    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign rd  = inst[11:7];

    assign data_rs1 = register[rs1];
    assign data_rs2 = register[rs2];

    // Register write occurs on the falling edge.
    // rd != 0 prevents modification of x0.
    always @(negedge clk) begin
        if (wr_enable && (rd != 5'd0))
            register[rd] <= Wr_Data;
    end

    // Initialization used for simulation/debugging.
    // register[0] starts at 0 and all remaining registers at their index.
    initial begin
        for (i = 0; i < 32; i = i + 1)
            register[i] = i;
    end

endmodule

// ------------------------------------------------------------
// ALU Source MUX
// aluSrc:
// 00 -> rs2
// 01 -> immediate
// 10 -> 5-bit shift amount
// ------------------------------------------------------------
module alu_mux (
    input  [31:0] data_rs2,
    input  [31:0] imm,
    input  [31:0] imm5,
    input  [1:0]  aluSrc,
    output reg [31:0] b
);

    always @(*) begin
        case (aluSrc)
            2'b00:   b = data_rs2;
            2'b01:   b = imm;
            2'b10:   b = imm5;
            default: b = data_rs2;
        endcase
    end

endmodule

// ------------------------------------------------------------
// ALU
// alu_ctrl mapping:
// 0 -> ADD
// 1 -> SUB
// 2 -> SLL
// 3 -> SLT
// 4 -> SLTU
// 5 -> XOR
// 6 -> SRL
// 7 -> SRA
// 8 -> OR
// 9 -> AND
// ------------------------------------------------------------
module ALU #(parameter N = 31) (
    input  [N:0] rs1,
    input  [N:0] rs2,
    input  [3:0] alu_ctrl,
    output reg [N:0] alu_out,
    output zero,
    output lessthan,
    output lessthanU
);

    assign zero      = (alu_out == 32'b0);
    assign lessthan  = ($signed(rs1) < $signed(rs2));
    assign lessthanU = (rs1 < rs2);

    always @(*) begin
        case (alu_ctrl)
            4'h0: alu_out = rs1 + rs2;                    // ADD
            4'h1: alu_out = rs1 - rs2;                    // SUB
            4'h2: alu_out = rs1 << rs2[4:0];             // SLL
            4'h3: alu_out = {31'b0, lessthan};            // SLT
            4'h4: alu_out = {31'b0, lessthanU};           // SLTU
            4'h5: alu_out = rs1 ^ rs2;                   // XOR
            4'h6: alu_out = rs1 >> rs2[4:0];              // SRL
            4'h7: alu_out = $signed(rs1) >>> rs2[4:0];   // SRA
            4'h8: alu_out = rs1 | rs2;                   // OR
            4'h9: alu_out = rs1 & rs2;                   // AND
            default: alu_out = 32'd0;
        endcase
    end

endmodule

// ------------------------------------------------------------
// Result / Write-Back MUX
// ResultSrc:
// 00 -> ALU result
// 01 -> Data memory result
// 10 -> PC + 4
// ------------------------------------------------------------
module result_mux (
    input  [31:0] alu_out,
    input  [31:0] store_data,
    input  [31:0] pc_nxt,
    input  [1:0]  ResultSrc,
    output reg [31:0] Result_out
);

    always @(*) begin
        case (ResultSrc)
            2'b00:   Result_out = alu_out;
            2'b01:   Result_out = store_data;
            2'b10:   Result_out = pc_nxt;
            default: Result_out = 32'd0;
        endcase
    end

endmodule

// ------------------------------------------------------------
// Main Controller
// ------------------------------------------------------------
module controller (
    input  [31:0] inst,
    input         zero,
    input         lessthan,
    input         lessthanU,
    output reg [1:0] immSrc,
    output reg [1:0] ResultSrc,
    output reg [1:0] PCSrc,
    output reg [1:0] aluop,
    output reg [1:0] aluSrc,
    output reg       Regwr,
    output reg       MemRead,
    output reg       MemWrite,
    output [2:0] func_3,
    output [6:0] func_7
);

    wire [6:0] opcode;

    assign func_3 = inst[14:12];
    assign func_7 = inst[31:25];
    assign opcode = inst[6:0];

    always @(*) begin
        // Safe defaults: sequential PC, no memory operation,
        // no register write, ALU result as default write-back.
        Regwr    = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        ResultSrc = 2'b00;
        immSrc    = 2'b00;
        aluSrc    = 2'b00;
        PCSrc     = 2'b00;
        aluop     = 2'b00;

        case (opcode)
            7'b0110011: begin // R-type
                Regwr     = 1'b1;
                aluSrc    = 2'b00;
                PCSrc     = 2'b00;
                ResultSrc = 2'b00;
                immSrc    = 2'b00;
                aluop     = 2'b10;
            end

            7'b0010011: begin // I-type ALU operations
                Regwr     = 1'b1;
                PCSrc     = 2'b00;
                ResultSrc = 2'b00;
                immSrc    = 2'b00;
                aluop     = 2'b11;

                // Shift instructions use imm5; other I-type
                // instructions use the sign-extended immediate.
                if ((func_3 == 3'b001) || (func_3 == 3'b101))
                    aluSrc = 2'b10;
                else
                    aluSrc = 2'b01;
            end

            7'b0100011: begin // SW
                MemWrite = 1'b1;
                aluSrc   = 2'b01;
                immSrc   = 2'b01;
                aluop    = 2'b00; // ADD for effective address
            end

            7'b0000011: begin // LW
                aluSrc    = 2'b01;
                Regwr     = 1'b1;
                MemRead   = 1'b1;
                ResultSrc = 2'b01;
                immSrc    = 2'b00;
                aluop     = 2'b00; // ADD for effective address
            end

            7'b1100011: begin // Branch instructions
                aluSrc = 2'b00;
                immSrc = 2'b10;
                aluop  = 2'b01; // SUB for branch comparison

                case (func_3)
                    3'b000: PCSrc = zero       ? 2'b01 : 2'b00; // BEQ
                    3'b001: PCSrc = !zero      ? 2'b01 : 2'b00; // BNE
                    3'b100: PCSrc = lessthan   ? 2'b01 : 2'b00; // BLT
                    3'b101: PCSrc = !lessthan  ? 2'b01 : 2'b00; // BGE
                    3'b110: PCSrc = lessthanU  ? 2'b01 : 2'b00; // BLTU
                    3'b111: PCSrc = !lessthanU ? 2'b01 : 2'b00; // BGEU
                    default: PCSrc = 2'b00;
                endcase
            end

            7'b1100111: begin // JALR
                immSrc    = 2'b00;
                PCSrc     = 2'b10; // ALU output
                ResultSrc = 2'b10; // PC + 4
                Regwr     = 1'b1;
                aluSrc    = 2'b01;
                aluop     = 2'b00; // ADD target address
            end

            default: begin
                // Keep safe defaults.
            end
        endcase
    end

endmodule

// ------------------------------------------------------------
// ALU Decoder
// aluop:
// 00 -> ADD (address calculation for LW/SW/JALR)
// 01 -> SUB (branch comparison)
// 10 -> R-type decode
// 11 -> I-type decode
// ------------------------------------------------------------
module alu_decoder (
    input  [2:0] func_3,
    input  [6:0] func_7,
    input  [1:0] aluop,
    output reg [3:0] alu_control
);

    always @(*) begin
        // Safe default = ADD
        alu_control = 4'h0;

        case (aluop)
            2'b00: begin
                alu_control = 4'h0; // ADD: LW/SW/JALR address
            end

            2'b01: begin
                alu_control = 4'h1; // SUB: branch comparison
            end

            2'b10: begin // R-type
                case (func_3)
                    3'b000: alu_control = (func_7 == 7'b0100000) ? 4'h1 : 4'h0; // SUB/ADD
                    3'b001: alu_control = 4'h2;                                 // SLL
                    3'b010: alu_control = 4'h3;                                 // SLT
                    3'b011: alu_control = 4'h4;                                 // SLTU
                    3'b100: alu_control = 4'h5;                                 // XOR
                    3'b101: alu_control = (func_7 == 7'b0100000) ? 4'h7 : 4'h6; // SRA/SRL
                    3'b110: alu_control = 4'h8;                                 // OR
                    3'b111: alu_control = 4'h9;                                 // AND
                    default: alu_control = 4'h0;
                endcase
            end

            2'b11: begin // I-type
                case (func_3)
                    3'b000: alu_control = 4'h0; // ADDI
                    3'b010: alu_control = 4'h3; // SLTI
                    3'b011: alu_control = 4'h4; // SLTIU
                    3'b100: alu_control = 4'h5; // XORI
                    3'b110: alu_control = 4'h8; // ORI
                    3'b111: alu_control = 4'h9; // ANDI
                    3'b001: alu_control = 4'h2; // SLLI
                    3'b101: alu_control = (func_7 == 7'b0100000) ? 4'h7 : 4'h6; // SRAI/SRLI
                    default: alu_control = 4'h0;
                endcase
            end

            default: alu_control = 4'h0;
        endcase
    end

endmodule

// ------------------------------------------------------------
// Data Memory
// 256 words x 32 bits = 1 KB
// Word-aligned indexing using address bits [9:2]
// Synchronous read/write behavior at posedge.
// ------------------------------------------------------------
module data_memory (
    input        clk,
    input [31:0] Mem_wrdata,
    input [31:0] Mem_wradd,
    input        Memread,
    input        MemWrite,
    output reg [31:0] ReadData
);

    reg [31:0] data [0:255];

    initial begin
        data[0] = 32'd5;
    end

    always @(posedge clk) begin
        if (MemWrite) begin
            data[Mem_wradd[9:2]] <= Mem_wrdata;
            ReadData <= 32'd0;
        end
        else if (Memread) begin
            ReadData <= data[Mem_wradd[9:2]];
        end
        else begin
            ReadData <= 32'd0;
        end
    end

endmodule

// ------------------------------------------------------------
// Instruction Memory
// 256 words x 32 bits = 1 KB
// Combinational read using PC bits [9:2]
// ------------------------------------------------------------
module inst_memory (
    input  [31:0] pc,
    output [31:0] inst
);

    reg [31:0] inst_mem [0:255];

    assign inst = inst_mem[pc[9:2]];

    initial begin
        inst_mem[0] = 32'h00000013; // ADDI x0,x0,0 (NOP)
    end

endmodule

// ------------------------------------------------------------
// Top-Level RISC-V Single-Cycle CPU
// ------------------------------------------------------------
module simple_cpu_top (
    input        clk,
    input        reset,
    output [31:0] pc,
    output [31:0] inst,
    output [31:0] alu_out,
    output [31:0] pc_nxt,
    output [31:0] result_out
);

    wire [31:0] pcadd;
    wire [31:0] pcbranch;
    wire [31:0] pcjump;
    wire [31:0] data_rs1;
    wire [31:0] data_rs2;
    wire [31:0] imm;
    wire [31:0] imm5;
    wire [31:0] alu_b;
    wire [31:0] mem_rd_data;

    wire [1:0] immSrc;
    wire [1:0] ResultSrc;
    wire [1:0] PCSrc;
    wire [1:0] aluop;
    wire [1:0] aluSrc;

    wire Regwr;
    wire MemRead;
    wire MemWrite;

    wire zero;
    wire lessthan;
    wire lessthanU;

    wire [2:0] func_3;
    wire [6:0] func_7;
    wire [3:0] alu_ctrl;

    // --------------------------------------------------------
    // Processor datapath
    // --------------------------------------------------------
    pcreg PC_REG (
        .clk(clk),
        .reset(reset),
        .pc_nxt(pc_nxt),
        .pc(pc)
    );

    inst_memory IMEM (
        .pc(pc),
        .inst(inst)
    );

    imm_extend IMM_EXTENDER (
        .immSrc(immSrc),
        .inst(inst),
        .imm(imm),
        .imm5(imm5)
    );

    reg_file REG_FILE (
        .inst(inst),
        .Wr_Data(result_out),
        .wr_enable(Regwr),
        .clk(clk),
        .data_rs1(data_rs1),
        .data_rs2(data_rs2)
    );

    alu_mux ALU_MUX (
        .data_rs2(data_rs2),
        .imm(imm),
        .imm5(imm5),
        .aluSrc(aluSrc),
        .b(alu_b)
    );

    ALU ALU1 (
        .rs1(data_rs1),
        .rs2(alu_b),
        .alu_ctrl(alu_ctrl),
        .alu_out(alu_out),
        .zero(zero),
        .lessthan(lessthan),
        .lessthanU(lessthanU)
    );

    pcadder PC_ADD (
        .pc(pc),
        .pcadd(pcadd)
    );

    pcbranchadder PC_BRANCH (
        .pc(pc),
        .imm(imm),
        .pcnxt(pcbranch)
    );

    // RV32I JALR target must have bit 0 cleared for alignment.
    wire [31:0] jalr_target;
    assign jalr_target = {alu_out[31:1], 1'b0};

    pcmux PC_MUX (
        .pcadd(pcadd),
        .pcbranch(pcbranch),
        .pcjump(jalr_target),
        .PCSrc(PCSrc),
        .pc_nxt(pc_nxt)
    );

    data_memory DATA_MEM (
        .clk(clk),
        .Mem_wrdata(data_rs2),
        .Mem_wradd(alu_out),
        .Memread(MemRead),
        .MemWrite(MemWrite),
        .ReadData(mem_rd_data)
    );

    result_mux RESULT_MUX (
        .alu_out(alu_out),
        .store_data(mem_rd_data),
        .pc_nxt(pcadd),
        .ResultSrc(ResultSrc),
        .Result_out(result_out)
    );

    controller CTRL_UNIT (
        .inst(inst),
        .zero(zero),
        .lessthan(lessthan),
        .lessthanU(lessthanU),
        .immSrc(immSrc),
        .ResultSrc(ResultSrc),
        .PCSrc(PCSrc),
        .aluop(aluop),
        .aluSrc(aluSrc),
        .Regwr(Regwr),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .func_3(func_3),
        .func_7(func_7)
    );

    alu_decoder ALU_DECODER (
        .func_3(func_3),
        .func_7(func_7),
        .aluop(aluop),
        .alu_control(alu_ctrl)
    );

endmodule
