`timescale 1ns/1ps

module tb_cpu_isa;
  reg clk;
  reg rst;
  reg [7:0] switches;
  wire [7:0] leds;
  wire [31:0] led_data;
  wire [31:0] cycle_count;
  wire [31:0] instr_count;
  wire [31:0] current_pc;
  wire halt_flag;

  integer errors;
  integer cycles;

  CPU dut (
    .clk(clk),
    .rst(rst),
    .switches(switches),
    .step_mode(1'b0),
    .step_trigger(1'b0),
    .leds(leds),
    .led_data(led_data),
    .cycle_count(cycle_count),
    .instr_count(instr_count),
    .current_pc(current_pc),
    .halt_flag(halt_flag)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic check_reg(input integer idx, input [31:0] exp, input string name);
    begin
      if (dut.regfile.regs[idx] !== exp) begin
        $display("[FAIL] %s x%0d expected 0x%08h got 0x%08h",
                 name, idx, exp, dut.regfile.regs[idx]);
        errors = errors + 1;
      end else begin
        $display("[ OK ] %s x%0d = 0x%08h", name, idx, exp);
      end
    end
  endtask

  task automatic check_mem(input integer addr, input [7:0] exp, input string name);
    begin
      if (dut.dmem.mem[addr] !== exp) begin
        $display("[FAIL] %s mem[0x%0h] expected 0x%02h got 0x%02h",
                 name, addr, exp, dut.dmem.mem[addr]);
        errors = errors + 1;
      end else begin
        $display("[ OK ] %s mem[0x%0h] = 0x%02h", name, addr, exp);
      end
    end
  endtask

  initial begin
    errors = 0;
    cycles = 0;
    switches = 8'h00;

    $readmemh("Testbench/isa_full.hex", dut.imem.mem);

    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;

    while (!halt_flag && cycles < 300) begin
      @(posedge clk);
      cycles = cycles + 1;
    end

    if (!halt_flag) begin
      $display("[FAIL] CPU did not halt during ISA test");
      errors = errors + 1;
    end

    check_reg(1,  32'h12345000, "LUI");
    check_reg(2,  32'h12345004, "AUIPC");
    check_reg(3,  32'h12345678, "ADDI");
    check_reg(4,  32'h00000000, "SLTI");
    check_reg(5,  32'h00000000, "SLTIU");
    check_reg(6,  32'hedcbafff, "XORI");
    check_reg(7,  32'hffffffff, "ORI");
    check_reg(8,  32'h12345000, "ANDI");
    check_reg(9,  32'h23450000, "SLLI");
    check_reg(11, 32'h01234500, "SRAI");
    check_reg(12, 32'h2468a004, "ADD");
    check_reg(13, 32'hfffffffc, "SUB");
    check_reg(14, 32'h23450000, "SLL");
    check_reg(15, 32'h00000001, "SLT");
    check_reg(16, 32'h00000001, "SLTU");
    check_reg(17, 32'h00000004, "XOR");
    check_reg(18, 32'h01234500, "SRL");
    check_reg(19, 32'h01234500, "SRA");
    check_reg(20, 32'h12345004, "OR");
    check_reg(21, 32'h12345000, "AND");
    check_reg(22, 32'h12345000, "LW");
    check_reg(23, 32'h00005000, "LH");
    check_reg(24, 32'h00005000, "LHU");
    check_reg(25, 32'h00000000, "LB");
    check_reg(26, 32'h00000000, "LBU");
    check_reg(31, 32'h000000b0, "JAL link");
    check_reg(28, 32'h000000b4, "AUIPC before JALR");
    check_reg(29, 32'h000000bc, "JALR link");
    check_reg(10, 32'h00000001, "ECALL pass marker");
    check_reg(30, 32'h00000200, "RAM base");

    check_mem(32'h200, 8'h00, "SW byte0");
    check_mem(32'h201, 8'h50, "SW byte1");
    check_mem(32'h202, 8'h34, "SW byte2");
    check_mem(32'h203, 8'h12, "SW byte3");
    check_mem(32'h204, 8'h00, "SH byte0");
    check_mem(32'h205, 8'h50, "SH byte1");
    check_mem(32'h208, 8'h00, "SB byte0");

    if (errors == 0)
      $display("TEST_PASS tb_cpu_isa cycles=%0d instr_count=%0d", cycles, instr_count);
    else begin
      $display("TEST_FAIL tb_cpu_isa errors=%0d", errors);
      $fatal(1, "tb_cpu_isa failed");
    end

    $finish;
  end
endmodule
