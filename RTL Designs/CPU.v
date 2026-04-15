module CPU(
    input clk, rst,
    input [7:0] switches,
    input step_mode, step_trigger,
    output [7:0] leds,
    output [31:0] led_data,
    output [31:0] cycle_count, instr_count, current_pc,
    output halt_flag
);

    // Các tín hiệu nội bộ tiêu chuẩn của CPU RISC-V
    wire [31:0] pc, pc_next, pc_plus4, pc_branch, pc_jump;
    wire [31:0] instr;
    wire [31:0] rd1, rd2, imm, alu_a, alu_b, alu_result, mem_data, write_data;
    wire [3:0] alu_ctrl;
    wire [1:0] branch_type, mem_size;
    wire reg_write, mem_write, mem_read, alu_src, mem_to_reg;
    wire branch, jump, jalr, mem_sign_ext, auipc_sel;
    wire ecall, ebreak, halt;
    wire zero, less_than, less_than_u, branch_taken;

    // --- TÍN HIỆU ĐẶC BIỆT CHO LÕI AES ---
    wire aes_region, aes_cs, io_write, dmem_read, dmem_write;
    wire [31:0] aes_read_data;
    wire [31:0] final_mem_data;

    // Halt logic
    assign halt = ecall | ebreak;
    assign halt_flag = halt;

    // Branch logic
    reg branch_condition;
    always @(*) begin
        case(instr[14:12])
            3'b000: branch_condition = zero;          // BEQ
            3'b001: branch_condition = ~zero;         // BNE
            3'b100: branch_condition = less_than;     // BLT
            3'b101: branch_condition = ~less_than;    // BGE
            3'b110: branch_condition = less_than_u;   // BLTU
            3'b111: branch_condition = ~less_than_u;  // BGEU
            default: branch_condition = 1'b0;
        endcase
    end
    assign branch_taken = branch & branch_condition;

    // PC logic
    assign pc_plus4 = pc + 4;
    assign pc_branch = pc + imm;
    assign pc_jump = jalr ? (alu_result & 32'hFFFFFFFE) : (pc + imm);
    assign pc_next = (jump || jalr) ? pc_jump : (branch_taken ? pc_branch : pc_plus4);
    assign current_pc = pc;

    // --- KHỞI TẠO CÁC KHỐI CHỨC NĂNG ---
    PC pc_reg(
        .clk(clk), .rst(rst),
        .step_mode(step_mode), .step_trigger(step_trigger), .halt(halt),
        .pc_next(pc_next), .pc(pc)
    );

    InstructionMemory imem(.addr(pc), .instruction(instr));

    ControlUnit ctrl(
        .opcode(instr[6:0]), .funct3(instr[14:12]), .funct7(instr[31:25]), .imm12(instr[31:20]),
        .reg_write(reg_write), .mem_write(mem_write), .mem_read(mem_read),
        .alu_src(alu_src), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump), .jalr(jalr),
        .branch_type(branch_type), .mem_size(mem_size),
        .mem_sign_ext(mem_sign_ext), .auipc_sel(auipc_sel),
        .ecall(ecall), .ebreak(ebreak),
        .alu_ctrl(alu_ctrl)
    );

    RegisterFile regfile(
        .clk(clk), .we(reg_write),
        .ra1(instr[19:15]), .ra2(instr[24:20]), .wa(instr[11:7]),
        .wd(write_data), .rd1(rd1), .rd2(rd2)
    );

    ImmGen immgen(.instr(instr), .imm(imm));

    assign alu_a = auipc_sel ? pc : rd1;
    assign alu_b = alu_src ? imm : rd2;

    ALU alu(
        .a(alu_a), .b(alu_b), .alu_ctrl(alu_ctrl),
        .result(alu_result), .zero(zero),
        .less_than(less_than), .less_than_u(less_than_u)
    );

    assign aes_region = (alu_result[31:8] == 24'h800000);
    assign aes_cs     = (mem_read || mem_write) && aes_region;
    assign io_write   = mem_write && (alu_result == 32'hFFFF0000);
    assign dmem_read  = mem_read && !aes_cs;
    assign dmem_write = mem_write && !aes_cs && !io_write;

    DataMemory dmem(
        .clk(clk), .we(dmem_write), .re(dmem_read),
        .size(mem_size), .sign_ext(mem_sign_ext),
        .addr(alu_result), .wd(rd2), .rd(mem_data)
    );

    // =========================================================================
    // KHỐI TĂNG TỐC MÃ HÓA AES (HARDWARE ACCELERATOR)
    // =========================================================================
    // Giải mã địa chỉ: Chọn AES khi CPU truy cập dải 0x800000xx
    aes aes_accelerator (
        .clk(clk),
        .reset_n(~rst),            // rst của CPU tích cực cao, AES tích cực thấp
        .cs(aes_cs),
        .we(mem_write && aes_cs),
        .address(alu_result[9:2]), // Trích xuất địa chỉ thanh ghi (Word-aligned)
        .write_data(rd2),
        .read_data(aes_read_data)
    );

    // =========================================================================
    // WRITEBACK LOGIC (ĐÃ CHỈNH SỬA)
    // =========================================================================
    // Phân luồng dữ liệu đọc: Lấy từ AES hoặc RAM
    assign final_mem_data = aes_cs ? aes_read_data : mem_data;
    
    // Nạp dữ liệu về thanh ghi
    assign write_data = (jump || jalr) ? pc_plus4 : (mem_to_reg ? final_mem_data : alu_result);
    assign leds = led_data[7:0];

    // Tính năng phụ: Đếm chu kỳ và Xuất LED cơ bản (từ tài liệu gốc)
    PerformanceCounter perf_counter(
        .clk(clk), .rst(rst),
        .enable(!halt && (!step_mode || step_trigger)),
        .cycle_count(cycle_count),
        .instr_count(instr_count)
    );

    SimpleIO io_module(
        .clk(clk), .rst(rst),
        .switches(switches),
        .cpu_data(rd2),   
        .write_enable(io_write),
        .led_data(led_data)
    );
endmodule
