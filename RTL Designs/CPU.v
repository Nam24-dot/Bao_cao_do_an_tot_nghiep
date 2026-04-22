module CPU(
    input clk, rst,
    input [7:0] switches,
    input step_mode, step_trigger,
    output [7:0] leds,
    output [31:0] led_data,
    output reg [31:0] cycle_count,
    output reg [31:0] instr_count,
    output [31:0] current_pc,
    output halt_flag
);
    localparam NOP = 32'h00000013;

    reg [31:0] pc;
    reg halted;
    reg step_prev;
    wire step_pulse = step_trigger && !step_prev;
    wire run_en = !halted && (!step_mode || step_pulse);

    wire [31:0] if_instr;
    wire [31:0] pc_plus4 = pc + 32'd4;

    InstructionMemory imem(
        .clk(clk),
        .addr(pc),
        .instruction(if_instr)
    );

    // IF/ID pipeline register.
    reg        if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_pc4;
    reg [31:0] if_id_instr;

    wire [6:0] id_opcode = if_id_instr[6:0];
    wire [4:0] id_rs1 = if_id_instr[19:15];
    wire [4:0] id_rs2 = if_id_instr[24:20];
    wire [4:0] id_rd  = if_id_instr[11:7];
    wire [2:0] id_funct3 = if_id_instr[14:12];

    wire id_reg_write;
    wire id_mem_write;
    wire id_mem_read;
    wire id_alu_src;
    wire id_mem_to_reg;
    wire id_branch;
    wire id_jump;
    wire id_jalr;
    wire [1:0] id_branch_type;
    wire [1:0] id_mem_size;
    wire id_mem_sign_ext;
    wire id_auipc_sel;
    wire id_ecall;
    wire id_ebreak;
    wire [3:0] id_alu_ctrl;
    wire [31:0] id_imm;
    wire [31:0] id_rd1;
    wire [31:0] id_rd2;

    ControlUnit ctrl(
        .opcode(id_opcode),
        .funct3(id_funct3),
        .funct7(if_id_instr[31:25]),
        .imm12(if_id_instr[31:20]),
        .reg_write(id_reg_write),
        .mem_write(id_mem_write),
        .mem_read(id_mem_read),
        .alu_src(id_alu_src),
        .mem_to_reg(id_mem_to_reg),
        .branch(id_branch),
        .jump(id_jump),
        .jalr(id_jalr),
        .branch_type(id_branch_type),
        .mem_size(id_mem_size),
        .mem_sign_ext(id_mem_sign_ext),
        .auipc_sel(id_auipc_sel),
        .ecall(id_ecall),
        .ebreak(id_ebreak),
        .alu_ctrl(id_alu_ctrl)
    );

    ImmGen immgen(.instr(if_id_instr), .imm(id_imm));

    wire wb_reg_write;
    wire [4:0] wb_rd;
    wire [31:0] wb_write_data;

    RegisterFile regfile(
        .clk(clk),
        .we(wb_reg_write),
        .ra1(id_rs1),
        .ra2(id_rs2),
        .wa(wb_rd),
        .wd(wb_write_data),
        .rd1(id_rd1),
        .rd2(id_rd2)
    );

    // ID/EX pipeline register.
    reg        id_ex_valid;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_pc4;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg [2:0]  id_ex_funct3;
    reg [3:0]  id_ex_alu_ctrl;
    reg [1:0]  id_ex_mem_size;
    reg        id_ex_mem_sign_ext;
    reg        id_ex_reg_write;
    reg        id_ex_mem_write;
    reg        id_ex_mem_read;
    reg        id_ex_alu_src;
    reg        id_ex_mem_to_reg;
    reg        id_ex_branch;
    reg        id_ex_jump;
    reg        id_ex_jalr;
    reg        id_ex_auipc_sel;
    reg        id_ex_halt;

    wire id_uses_rs1 = (id_opcode == 7'b0110011) || (id_opcode == 7'b0010011) ||
                       (id_opcode == 7'b0000011) || (id_opcode == 7'b0100011) ||
                       (id_opcode == 7'b1100011) || (id_opcode == 7'b1100111);
    wire id_uses_rs2 = (id_opcode == 7'b0110011) || (id_opcode == 7'b0100011) ||
                       (id_opcode == 7'b1100011);

    wire load_use_stall = id_ex_valid && id_ex_mem_read && (id_ex_rd != 5'd0) &&
                          ((id_uses_rs1 && (id_ex_rd == id_rs1)) ||
                           (id_uses_rs2 && (id_ex_rd == id_rs2)));

    // EX/MEM pipeline register.
    reg        ex_mem_valid;
    reg [31:0] ex_mem_pc4;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_store_data;
    reg [4:0]  ex_mem_rd;
    reg [1:0]  ex_mem_mem_size;
    reg        ex_mem_mem_sign_ext;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_to_reg;
    reg        ex_mem_jump_link;
    reg        ex_mem_halt;

    // MEM/WB pipeline register.
    reg        mem_wb_valid;
    reg [31:0] mem_wb_pc4;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg        mem_wb_mem_to_reg;
    reg        mem_wb_jump_link;
    reg        mem_wb_halt;

    assign wb_reg_write = mem_wb_valid && mem_wb_reg_write && !halted;
    assign wb_rd = mem_wb_rd;
    assign wb_write_data = mem_wb_jump_link ? mem_wb_pc4 :
                           (mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_result);

    wire [31:0] ex_forward_from_mem = ex_mem_jump_link ? ex_mem_pc4 : ex_mem_alu_result;
    wire [31:0] id_rs1_data_byp =
        (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == id_rs1)) ? wb_write_data : id_rd1;
    wire [31:0] id_rs2_data_byp =
        (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == id_rs2)) ? wb_write_data : id_rd2;

    reg [31:0] ex_rs1_value;
    reg [31:0] ex_rs2_value;
    always @(*) begin
        ex_rs1_value = id_ex_rs1_data;
        ex_rs2_value = id_ex_rs2_data;

        if (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_to_reg &&
            (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            ex_rs1_value = ex_forward_from_mem;
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == id_ex_rs1))
            ex_rs1_value = wb_write_data;

        if (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_to_reg &&
            (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
            ex_rs2_value = ex_forward_from_mem;
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == id_ex_rs2))
            ex_rs2_value = wb_write_data;
    end

    wire [31:0] ex_alu_a = id_ex_auipc_sel ? id_ex_pc : ex_rs1_value;
    wire [31:0] ex_alu_b = id_ex_alu_src ? id_ex_imm : ex_rs2_value;
    wire [31:0] ex_alu_result;
    wire ex_zero;
    wire ex_less_than;
    wire ex_less_than_u;

    ALU alu(
        .a(ex_alu_a),
        .b(ex_alu_b),
        .alu_ctrl(id_ex_alu_ctrl),
        .result(ex_alu_result),
        .zero(ex_zero),
        .less_than(ex_less_than),
        .less_than_u(ex_less_than_u)
    );

    reg ex_branch_condition;
    always @(*) begin
        case (id_ex_funct3)
            3'b000: ex_branch_condition = ex_zero;
            3'b001: ex_branch_condition = ~ex_zero;
            3'b100: ex_branch_condition = ex_less_than;
            3'b101: ex_branch_condition = ~ex_less_than;
            3'b110: ex_branch_condition = ex_less_than_u;
            3'b111: ex_branch_condition = ~ex_less_than_u;
            default: ex_branch_condition = 1'b0;
        endcase
    end

    wire ex_branch_taken = id_ex_valid && id_ex_branch && ex_branch_condition;
    wire ex_jump_taken = id_ex_valid && (id_ex_jump || id_ex_jalr);
    wire ex_flush = ex_branch_taken || ex_jump_taken;
    wire [31:0] ex_branch_target = id_ex_pc + id_ex_imm;
    wire [31:0] ex_jalr_target = (ex_alu_result & 32'hffff_fffe);
    wire [31:0] ex_next_pc = id_ex_jalr ? ex_jalr_target : ex_branch_target;

    wire mem_aes_region = (ex_mem_alu_result[31:8] == 24'h800000);
    wire mem_aes_cs = ex_mem_valid && (ex_mem_mem_read || ex_mem_mem_write) && mem_aes_region;
    wire mem_io_region = (ex_mem_alu_result[31:4] == 28'hffff000);
    wire mem_io_write = ex_mem_valid && ex_mem_mem_write && mem_io_region;
    wire mem_dmem_read = ex_mem_valid && ex_mem_mem_read && !mem_aes_cs;
    wire mem_dmem_write = ex_mem_valid && ex_mem_mem_write && !mem_aes_cs && !mem_io_write;

    wire [31:0] mem_data;
    wire [31:0] aes_read_data;
    wire [31:0] mem_final_data = mem_aes_cs ? aes_read_data : mem_data;

    DataMemory dmem(
        .clk(clk),
        .we(mem_dmem_write),
        .re(mem_dmem_read),
        .size(ex_mem_mem_size),
        .sign_ext(ex_mem_mem_sign_ext),
        .addr(ex_mem_alu_result),
        .wd(ex_mem_store_data),
        .rd(mem_data)
    );

    aes #(
        .CUSTOM_MODE(1'b1)
    ) aes_accelerator (
        .clk(clk),
        .reset_n(~rst),
        .cs(mem_aes_cs),
        .we(ex_mem_mem_write && mem_aes_cs),
        .address(ex_mem_alu_result[9:2]),
        .write_data(ex_mem_store_data),
        .read_data(aes_read_data)
    );

    SimpleIO io_module(
        .clk(clk),
        .rst(rst),
        .switches(switches),
        .addr(ex_mem_alu_result),
        .cpu_data(ex_mem_store_data),
        .write_enable(mem_io_write),
        .led_data(led_data)
    );

    assign leds = led_data[7:0];
    assign current_pc = pc;
    assign halt_flag = halted;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 32'd0;
            halted <= 1'b0;
            step_prev <= 1'b0;
            cycle_count <= 32'd0;
            instr_count <= 32'd0;

            if_id_valid <= 1'b0;
            if_id_pc <= 32'd0;
            if_id_pc4 <= 32'd0;
            if_id_instr <= NOP;

            id_ex_valid <= 1'b0;
            id_ex_pc <= 32'd0;
            id_ex_pc4 <= 32'd0;
            id_ex_rs1_data <= 32'd0;
            id_ex_rs2_data <= 32'd0;
            id_ex_imm <= 32'd0;
            id_ex_rs1 <= 5'd0;
            id_ex_rs2 <= 5'd0;
            id_ex_rd <= 5'd0;
            id_ex_funct3 <= 3'd0;
            id_ex_alu_ctrl <= 4'd0;
            id_ex_mem_size <= 2'd0;
            id_ex_mem_sign_ext <= 1'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;
            id_ex_jalr <= 1'b0;
            id_ex_auipc_sel <= 1'b0;
            id_ex_halt <= 1'b0;

            ex_mem_valid <= 1'b0;
            ex_mem_pc4 <= 32'd0;
            ex_mem_alu_result <= 32'd0;
            ex_mem_store_data <= 32'd0;
            ex_mem_rd <= 5'd0;
            ex_mem_mem_size <= 2'd0;
            ex_mem_mem_sign_ext <= 1'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_to_reg <= 1'b0;
            ex_mem_jump_link <= 1'b0;
            ex_mem_halt <= 1'b0;

            mem_wb_valid <= 1'b0;
            mem_wb_pc4 <= 32'd0;
            mem_wb_alu_result <= 32'd0;
            mem_wb_mem_data <= 32'd0;
            mem_wb_rd <= 5'd0;
            mem_wb_reg_write <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;
            mem_wb_jump_link <= 1'b0;
            mem_wb_halt <= 1'b0;
        end else begin
            step_prev <= step_trigger;
            cycle_count <= cycle_count + 32'd1;

            if (run_en) begin
                if (mem_wb_valid)
                    instr_count <= instr_count + 32'd1;

                if (mem_wb_valid && mem_wb_halt)
                    halted <= 1'b1;

                mem_wb_valid <= ex_mem_valid;
                mem_wb_pc4 <= ex_mem_pc4;
                mem_wb_alu_result <= ex_mem_alu_result;
                mem_wb_mem_data <= mem_final_data;
                mem_wb_rd <= ex_mem_rd;
                mem_wb_reg_write <= ex_mem_reg_write;
                mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
                mem_wb_jump_link <= ex_mem_jump_link;
                mem_wb_halt <= ex_mem_halt;

                ex_mem_valid <= id_ex_valid;
                ex_mem_pc4 <= id_ex_pc4;
                ex_mem_alu_result <= ex_alu_result;
                ex_mem_store_data <= ex_rs2_value;
                ex_mem_rd <= id_ex_rd;
                ex_mem_mem_size <= id_ex_mem_size;
                ex_mem_mem_sign_ext <= id_ex_mem_sign_ext;
                ex_mem_reg_write <= id_ex_reg_write;
                ex_mem_mem_write <= id_ex_mem_write;
                ex_mem_mem_read <= id_ex_mem_read;
                ex_mem_mem_to_reg <= id_ex_mem_to_reg;
                ex_mem_jump_link <= id_ex_jump || id_ex_jalr;
                ex_mem_halt <= id_ex_halt;

                if (ex_flush) begin
                    pc <= ex_next_pc;
                    if_id_valid <= 1'b0;
                    if_id_pc <= 32'd0;
                    if_id_pc4 <= 32'd0;
                    if_id_instr <= NOP;

                    id_ex_valid <= 1'b0;
                    id_ex_reg_write <= 1'b0;
                    id_ex_mem_write <= 1'b0;
                    id_ex_mem_read <= 1'b0;
                    id_ex_branch <= 1'b0;
                    id_ex_jump <= 1'b0;
                    id_ex_jalr <= 1'b0;
                    id_ex_halt <= 1'b0;
                end else if (load_use_stall) begin
                    id_ex_valid <= 1'b0;
                    id_ex_reg_write <= 1'b0;
                    id_ex_mem_write <= 1'b0;
                    id_ex_mem_read <= 1'b0;
                    id_ex_branch <= 1'b0;
                    id_ex_jump <= 1'b0;
                    id_ex_jalr <= 1'b0;
                    id_ex_halt <= 1'b0;
                end else begin
                    pc <= pc_plus4;

                    if_id_valid <= 1'b1;
                    if_id_pc <= pc;
                    if_id_pc4 <= pc_plus4;
                    if_id_instr <= if_instr;

                    id_ex_valid <= if_id_valid;
                    id_ex_pc <= if_id_pc;
                    id_ex_pc4 <= if_id_pc4;
                    id_ex_rs1_data <= id_rs1_data_byp;
                    id_ex_rs2_data <= id_rs2_data_byp;
                    id_ex_imm <= id_imm;
                    id_ex_rs1 <= id_rs1;
                    id_ex_rs2 <= id_rs2;
                    id_ex_rd <= id_rd;
                    id_ex_funct3 <= id_funct3;
                    id_ex_alu_ctrl <= id_alu_ctrl;
                    id_ex_mem_size <= id_mem_size;
                    id_ex_mem_sign_ext <= id_mem_sign_ext;
                    id_ex_reg_write <= id_reg_write;
                    id_ex_mem_write <= id_mem_write;
                    id_ex_mem_read <= id_mem_read;
                    id_ex_alu_src <= id_alu_src;
                    id_ex_mem_to_reg <= id_mem_to_reg;
                    id_ex_branch <= id_branch;
                    id_ex_jump <= id_jump;
                    id_ex_jalr <= id_jalr;
                    id_ex_auipc_sel <= id_auipc_sel;
                    id_ex_halt <= id_ecall || id_ebreak;
                end
            end
        end
    end
endmodule
