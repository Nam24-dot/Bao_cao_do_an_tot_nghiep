module ControlUnit(
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    input [11:0] imm12,
    output reg reg_write, mem_write, mem_read,
    output reg alu_src, mem_to_reg, branch, jump, jalr,
    output reg [1:0] branch_type, mem_size,
    output reg mem_sign_ext, auipc_sel, ecall, ebreak,
    output reg [3:0] alu_ctrl
);

    always @(*) begin
        // Defaults
        reg_write = 0; mem_write = 0; mem_read = 0;
        alu_src = 0; mem_to_reg = 0; branch = 0;
        jump = 0; jalr = 0;
        alu_ctrl = 4'b0000;
        branch_type = 2'b00; mem_size = 2'b10; mem_sign_ext = 1;
        auipc_sel = 0; ecall = 0; ebreak = 0;

        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1; alu_src = 0;
                case (funct3)
                    3'b000: alu_ctrl = (funct7[5]) ? 4'b0001 : 4'b0000; // SUB : ADD
                    3'b111: alu_ctrl = 4'b0010; // AND
                    3'b110: alu_ctrl = 4'b0011; // OR
                    3'b100: alu_ctrl = 4'b0100; // XOR
                    3'b010: alu_ctrl = 4'b1000; // SLT
                    3'b011: alu_ctrl = 4'b1001; // SLTU
                    3'b001: alu_ctrl = 4'b0101; // SLL
                    3'b101: alu_ctrl = (funct7[5]) ? 4'b0111 : 4'b0110; // SRA : SRL
                endcase
            end
            7'b0010011: begin // I-type ALU
                reg_write = 1; alu_src = 1;
                case (funct3)
                    3'b000: alu_ctrl = 4'b0000; // ADDI
                    3'b100: alu_ctrl = 4'b0100; // XORI
                    3'b110: alu_ctrl = 4'b0011; // ORI
                    3'b111: alu_ctrl = 4'b0010; // ANDI
                    3'b010: alu_ctrl = 4'b1000; // SLTI
                    3'b011: alu_ctrl = 4'b1001; // SLTIU
                    3'b001: alu_ctrl = 4'b0101; // SLLI
                    3'b101: alu_ctrl = (funct7[5]) ? 4'b0111 : 4'b0110; // SRAI : SRLI
                endcase
            end
            7'b0000011: begin // Load
                reg_write = 1; mem_read = 1; alu_src = 1; mem_to_reg = 1;
                alu_ctrl = 4'b0000;
                case(funct3)
                    3'b000: begin mem_size = 2'b00; mem_sign_ext = 1; end // LB
                    3'b001: begin mem_size = 2'b01; mem_sign_ext = 1; end // LH
                    3'b010: begin mem_size = 2'b10; mem_sign_ext = 1; end // LW
                    3'b100: begin mem_size = 2'b00; mem_sign_ext = 0; end // LBU
                    3'b101: begin mem_size = 2'b01; mem_sign_ext = 0; end // LHU
                endcase
            end
            7'b0100011: begin // Store
                mem_write = 1; alu_src = 1; alu_ctrl = 4'b0000;
                case (funct3)
                    3'b000: mem_size = 2'b00; // SB
                    3'b001: mem_size = 2'b01; // SH
                    3'b010: mem_size = 2'b10; // SW
                endcase
            end
            7'b1100011: begin // Branch
                branch = 1; alu_ctrl = 4'b0001; // SUB for compare
                case (funct3)
                    3'b000: branch_type = 2'b00; // BEQ
                    3'b001: branch_type = 2'b01; // BNE
                    3'b100: branch_type = 2'b10; // BLT
                    3'b101: branch_type = 2'b11; // BGE
                    3'b110: branch_type = 2'b10; // BLTU (reuse BLT logic)
                    3'b111: branch_type = 2'b11; // BGEU (reuse BGE logic)
                endcase
            end
            7'b1101111: begin // JAL
                reg_write = 1; jump = 1;
            end
            7'b1100111: begin // JALR
                reg_write = 1; jalr = 1; alu_src = 1; alu_ctrl = 4'b0000; // ADD
            end
            7'b0110111: begin // LUI
                reg_write = 1; alu_src = 1; alu_ctrl = 4'b1010; // PASS immediate
            end
            7'b0010111: begin // AUIPC
                reg_write = 1; alu_src = 1; auipc_sel = 1; alu_ctrl = 4'b0000; // ADD PC + imm
            end
            7'b1110011: begin // SYSTEM
                if (funct3 == 3'b000) begin
                    if (imm12 == 12'h000) ecall = 1;
                    else if (imm12 == 12'h001) ebreak = 1;
                end
            end
        endcase
    end
endmodule