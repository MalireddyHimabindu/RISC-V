`timescale 1ns/1ps

// ============================================================
// FINAL directed self-checking testbench for the RISC-V CPU
// Branch instructions are written as explicit machine-code
// constants to remove any possibility of encoder mismatch.
// ============================================================
module cpu_testbench_zero_fail;

    reg clk;
    reg reset;

    wire [31:0] pc;
    wire [31:0] inst;
    wire [31:0] alu_out;
    wire [31:0] pc_nxt;
    wire [31:0] result_out;

    integer i;
    integer checks;
    integer failures;

    simple_cpu_top DUT (
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .inst(inst),
        .alu_out(alu_out),
        .pc_nxt(pc_nxt),
        .result_out(result_out)
    );

    // 10 ns period = 100 MHz
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $timeformat(-9, 2, " ns", 12);
        checks   = 0;
        failures = 0;
        reset    = 1'b1;

        // Keep reset asserted while the test program is loaded.
        #2;
        for (i = 0; i < 256; i = i + 1)
            DUT.IMEM.inst_mem[i] = 32'h00000013; // ADDI x0,x0,0 = NOP

        // ----------------------------------------------------
        // I-type initialization
        // ----------------------------------------------------
        DUT.IMEM.inst_mem[0] = 32'h00500093; // ADDI  x1,x0,5
        DUT.IMEM.inst_mem[1] = 32'h00A00113; // ADDI  x2,x0,10
        DUT.IMEM.inst_mem[2] = 32'h00F00193; // ADDI  x3,x0,15
        DUT.IMEM.inst_mem[3] = 32'h01400213; // ADDI  x4,x0,20
        DUT.IMEM.inst_mem[4] = 32'h01900293; // ADDI  x5,x0,25

        // ----------------------------------------------------
        // R-type ALU operations
        // ----------------------------------------------------
        DUT.IMEM.inst_mem[5]  = 32'h00208333; // ADD  x6,x1,x2  = 15
        DUT.IMEM.inst_mem[6]  = 32'h403203B3; // SUB  x7,x4,x3  = 5
        DUT.IMEM.inst_mem[7]  = 32'h00109433; // SLL  x8,x1,x1  = 160
        DUT.IMEM.inst_mem[8]  = 32'h0020A4B3; // SLT  x9,x1,x2   = 1
        DUT.IMEM.inst_mem[9]  = 32'h00113533; // SLTU x10,x2,x1  = 0
        DUT.IMEM.inst_mem[10] = 32'h003145B3; // XOR  x11,x2,x3  = 5
        DUT.IMEM.inst_mem[11] = 32'h0012D633; // SRL  x12,x5,x1  = 0

        // Negative value and arithmetic shifts
        DUT.IMEM.inst_mem[12] = 32'hFF000713; // ADDI x14,x0,-16
        DUT.IMEM.inst_mem[13] = 32'h401757B3; // SRA  x15,x14,x1  = -1
        DUT.IMEM.inst_mem[14] = 32'h0041E833; // OR   x16,x3,x4 = 31
        DUT.IMEM.inst_mem[15] = 32'h0020F8B3; // AND  x17,x1,x2 = 0

        // ----------------------------------------------------
        // I-type logical and shift operations
        // ----------------------------------------------------
        DUT.IMEM.inst_mem[16] = 32'h0020A913; // SLTI  x18,x1,2 = 1
        DUT.IMEM.inst_mem[17] = 32'h00513993; // SLTIU x19,x2,5 = 0
        DUT.IMEM.inst_mem[18] = 32'h0030F093; // ANDI  x1,x1,3 = 1
        DUT.IMEM.inst_mem[19] = 32'h00216113; // ORI   x2,x2,2 = 10
        DUT.IMEM.inst_mem[20] = 32'h0011C193; // XORI  x3,x3,1 = 14
        DUT.IMEM.inst_mem[21] = 32'h00121213; // SLLI  x4,x4,1 = 40
        DUT.IMEM.inst_mem[22] = 32'h0012D293; // SRLI  x5,x5,1 = 12
        DUT.IMEM.inst_mem[23] = 32'h40175713; // SRAI  x14,x14,1 = -8

        // x0 must remain zero
        DUT.IMEM.inst_mem[24] = 32'h07B00013; // ADDI x0,x0,123

        // ----------------------------------------------------
        // SW / LW
        // ----------------------------------------------------
        DUT.IMEM.inst_mem[25] = 32'h00102023; // SW x1,0(x0)
        DUT.IMEM.inst_mem[26] = 32'h00002A03; // LW x20,0(x0)

        // ----------------------------------------------------
        // IMPORTANT: explicit, verified B-type encodings.
        // Intended PC sequence:
        // 108 ->116 ->120 ->128 ->136 ->144 ->152
        // ----------------------------------------------------
        DUT.IMEM.inst_mem[27] = 32'h00108463; // BEQ  x1,x1,+8   -> 116 (taken)
        DUT.IMEM.inst_mem[28] = 32'h00000013; // NOP, skipped
        DUT.IMEM.inst_mem[29] = 32'h00109463; // BNE  x1,x1,+8   -> 120 (NOT taken)
        DUT.IMEM.inst_mem[30] = 32'h0020C463; // BLT  x1,x2,+8   -> 128 (taken)
        DUT.IMEM.inst_mem[31] = 32'h00000013; // NOP, skipped
        DUT.IMEM.inst_mem[32] = 32'h00115463; // BGE  x2,x1,+8   -> 136 (taken)
        DUT.IMEM.inst_mem[33] = 32'h00000013; // NOP, skipped
        DUT.IMEM.inst_mem[34] = 32'h0020E463; // BLTU x1,x2,+8   -> 144 (taken)
        DUT.IMEM.inst_mem[35] = 32'h00000013; // NOP, skipped
        DUT.IMEM.inst_mem[36] = 32'h00117463; // BGEU x2,x1,+8   -> 152 (taken)
        DUT.IMEM.inst_mem[37] = 32'h00000013; // NOP, skipped

        // ----------------------------------------------------
        // JALR
        // ----------------------------------------------------
        DUT.IMEM.inst_mem[38] = 32'h0A800A93; // ADDI x21,x0,168
        DUT.IMEM.inst_mem[39] = 32'h000A8B67; // JALR x22,0(x21): x22=160, target=168
        DUT.IMEM.inst_mem[40] = 32'h00000013; // NOP
        DUT.IMEM.inst_mem[41] = 32'h00000013; // NOP
        DUT.IMEM.inst_mem[42] = 32'h04D00B93; // ADDI x23,x0,77

        // Configuration sanity check: these are the six branch
        // opcodes that MUST be in the compiled test program.
        if (DUT.IMEM.inst_mem[27] !== 32'h00108463) begin
            $display("FATAL TB ERROR: branch slot 27 is %h", DUT.IMEM.inst_mem[27]);
            $finish;
        end
        if (DUT.IMEM.inst_mem[29] !== 32'h00109463) begin
            $display("FATAL TB ERROR: branch slot 29 is %h", DUT.IMEM.inst_mem[29]);
            $finish;
        end
        if (DUT.IMEM.inst_mem[30] !== 32'h0020C463) begin
            $display("FATAL TB ERROR: branch slot 30 is %h", DUT.IMEM.inst_mem[30]);
            $finish;
        end
        if (DUT.IMEM.inst_mem[32] !== 32'h00115463) begin
            $display("FATAL TB ERROR: branch slot 32 is %h", DUT.IMEM.inst_mem[32]);
            $finish;
        end
        if (DUT.IMEM.inst_mem[34] !== 32'h0020E463) begin
            $display("FATAL TB ERROR: branch slot 34 is %h", DUT.IMEM.inst_mem[34]);
            $finish;
        end
        if (DUT.IMEM.inst_mem[36] !== 32'h00117463) begin
            $display("FATAL TB ERROR: branch slot 36 is %h", DUT.IMEM.inst_mem[36]);
            $finish;
        end

        #10;
        reset = 1'b0;
    end

    // --------------------------------------------------------
    // Cycle monitor
    // --------------------------------------------------------
    reg [31:0] e_pc, e_inst, e_alu, e_result, e_nextpc;

    always @(negedge clk) begin
        if (!reset) begin
            e_pc     = DUT.pc;
            e_inst   = DUT.inst;
            e_alu    = DUT.alu_out;
            e_result = DUT.result_out;
            e_nextpc = DUT.pc_nxt;

            #1;

            $display("T=%0t | PC=%3d | INST=%h | ALU=%h | RESULT=%h | NEXT=%3d | x1=%h x2=%h x11=%h x20=%h x22=%h x23=%h",
                     $time, e_pc, e_inst, e_alu, e_result, e_nextpc,
                     DUT.REG_FILE.register[1], DUT.REG_FILE.register[2],
                     DUT.REG_FILE.register[11], DUT.REG_FILE.register[20],
                     DUT.REG_FILE.register[22], DUT.REG_FILE.register[23]);

            // ------------------------------------------------
            // Sequential PC checks (branch/jump PCs excluded)
            // ------------------------------------------------
            if ((e_pc != 108) && (e_pc != 116) && (e_pc != 120) &&
                (e_pc != 128) && (e_pc != 136) && (e_pc != 144) &&
                (e_pc != 156)) begin
                checks = checks + 1;
                if (DUT.pc !== e_pc + 4) begin
                    failures = failures + 1;
                    $display("FAIL PC: at %0d got %0d expected %0d", e_pc, DUT.pc, e_pc+4);
                end
            end

            case (e_pc)
                0: begin checks=checks+1; if (DUT.REG_FILE.register[1]  !== 5) failures=failures+1; end
                4: begin checks=checks+1; if (DUT.REG_FILE.register[2]  !== 10) failures=failures+1; end
                8: begin checks=checks+1; if (DUT.REG_FILE.register[3]  !== 15) failures=failures+1; end
                12: begin checks=checks+1; if (DUT.REG_FILE.register[4]  !== 20) failures=failures+1; end
                16: begin checks=checks+1; if (DUT.REG_FILE.register[5]  !== 25) failures=failures+1; end
                20: begin checks=checks+1; if (DUT.REG_FILE.register[6]  !== 15) failures=failures+1; end
                24: begin checks=checks+1; if (DUT.REG_FILE.register[7]  !== 5) failures=failures+1; end
                28: begin checks=checks+1; if (DUT.REG_FILE.register[8]  !== 160) failures=failures+1; end
                32: begin checks=checks+1; if (DUT.REG_FILE.register[9]  !== 1) failures=failures+1; end
                36: begin checks=checks+1; if (DUT.REG_FILE.register[10] !== 0) failures=failures+1; end
                40: begin checks=checks+1; if (DUT.REG_FILE.register[11] !== 5) failures=failures+1; end
                44: begin checks=checks+1; if (DUT.REG_FILE.register[12] !== 0) failures=failures+1; end
                48: begin checks=checks+1; if (DUT.REG_FILE.register[14] !== 32'hfffffff0) failures=failures+1; end
                52: begin checks=checks+1; if (DUT.REG_FILE.register[15] !== 32'hffffffff) failures=failures+1; end
                56: begin checks=checks+1; if (DUT.REG_FILE.register[16] !== 31) failures=failures+1; end
                60: begin checks=checks+1; if (DUT.REG_FILE.register[17] !== 0) failures=failures+1; end
                64: begin checks=checks+1; if (DUT.REG_FILE.register[18] !== 1) failures=failures+1; end
                68: begin checks=checks+1; if (DUT.REG_FILE.register[19] !== 0) failures=failures+1; end
                72: begin checks=checks+1; if (DUT.REG_FILE.register[1]  !== 1) failures=failures+1; end
                76: begin checks=checks+1; if (DUT.REG_FILE.register[2]  !== 10) failures=failures+1; end
                80: begin checks=checks+1; if (DUT.REG_FILE.register[3]  !== 14) failures=failures+1; end
                84: begin checks=checks+1; if (DUT.REG_FILE.register[4]  !== 40) failures=failures+1; end
                88: begin checks=checks+1; if (DUT.REG_FILE.register[5]  !== 12) failures=failures+1; end
                92: begin checks=checks+1; if (DUT.REG_FILE.register[14] !== 32'hfffffff8) failures=failures+1; end
                96: begin checks=checks+1; if (DUT.REG_FILE.register[0]  !== 0) failures=failures+1; end
                100: begin checks=checks+1; if (DUT.DATA_MEM.data[0]    !== 1) failures=failures+1; end
                104: begin checks=checks+1; if (DUT.REG_FILE.register[20] !== 1) failures=failures+1; end

                // Explicit branch checks
                108: begin checks=checks+1; if (DUT.pc !== 116) failures=failures+1; end
                116: begin checks=checks+1; if (DUT.pc !== 120) failures=failures+1; end
                120: begin checks=checks+1; if (DUT.pc !== 128) failures=failures+1; end
                128: begin checks=checks+1; if (DUT.pc !== 136) failures=failures+1; end
                136: begin checks=checks+1; if (DUT.pc !== 144) failures=failures+1; end
                144: begin checks=checks+1; if (DUT.pc !== 152) failures=failures+1; end

                152: begin checks=checks+1; if (DUT.REG_FILE.register[21] !== 168) failures=failures+1; end

                156: begin
                    checks=checks+1; if (DUT.pc !== 168) failures=failures+1;
                    checks=checks+1; if (DUT.REG_FILE.register[22] !== 160) failures=failures+1;
                end

                168: begin
                    checks=checks+1; if (DUT.REG_FILE.register[23] !== 77) failures=failures+1;
                    $display("============================================================");
                    $display("RISC-V TEST SUMMARY");
                    $display("Checks performed : %0d", checks);
                    $display("Failures         : %0d", failures);
                    if (failures == 0)
                        $display("STATUS           : ALL TESTS PASSED");
                    else
                        $display("STATUS           : TESTS FAILED");
                    $display("============================================================");
                    #2 $finish;
                end
            endcase
        end
    end

    initial begin
        repeat (80) @(negedge clk);
        $display("TIMEOUT: simulation did not reach PC=168");
        $finish;
    end

endmodule
