`timescale 1ns/1ps

module tb_cpu_aes;
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
  reg [127:0] aes_result;

  localparam [127:0] EXPECTED_AES = 128'hf4199f768a3a321a15c74d182bf6d6b5;

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

  task automatic check32(input [31:0] got, input [31:0] exp, input string name);
    begin
      if (got !== exp) begin
        $display("[FAIL] %s expected 0x%08h got 0x%08h", name, exp, got);
        errors = errors + 1;
      end else begin
        $display("[ OK ] %s = 0x%08h", name, exp);
      end
    end
  endtask

  initial begin
    errors = 0;
    cycles = 0;
    switches = 8'h00;

    $readmemh("Testbench/risc_aes.hex", dut.imem.mem);

    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;

    while (!halt_flag && cycles < 2000) begin
      @(posedge clk);
      cycles = cycles + 1;
    end

    if (!halt_flag) begin
      $display("[FAIL] CPU did not halt during AES program");
      errors = errors + 1;
    end

    aes_result = {
      dut.aes_accelerator.result_reg[127:96],
      dut.aes_accelerator.result_reg[95:64],
      dut.aes_accelerator.result_reg[63:32],
      dut.aes_accelerator.result_reg[31:0]
    };

    check32(dut.aes_accelerator.result_reg[127:96], EXPECTED_AES[127:96], "AES RESULT0");
    check32(dut.aes_accelerator.result_reg[95:64],  EXPECTED_AES[95:64],  "AES RESULT1");
    check32(dut.aes_accelerator.result_reg[63:32],  EXPECTED_AES[63:32],  "AES RESULT2");
    check32(dut.aes_accelerator.result_reg[31:0],   EXPECTED_AES[31:0],   "AES RESULT3");

    if (dut.aes_accelerator.valid_reg !== 1'b1) begin
      $display("[FAIL] AES valid_reg expected 1 got %b", dut.aes_accelerator.valid_reg);
      errors = errors + 1;
    end else begin
      $display("[ OK ] AES valid_reg = 1");
    end

    switches = 8'h00;
    #1;
    check32(led_data, EXPECTED_AES[127:96], "LED RESULT0 register");
    if (leds !== EXPECTED_AES[103:96]) begin
      $display("[FAIL] LED byte RESULT0 expected 0x%02h got 0x%02h", EXPECTED_AES[103:96], leds);
      errors = errors + 1;
    end else begin
      $display("[ OK ] LED byte RESULT0 = 0x%02h", leds);
    end

    switches = 8'h01;
    #1;
    check32(led_data, EXPECTED_AES[95:64], "LED RESULT1 register");

    switches = 8'h02;
    #1;
    check32(led_data, EXPECTED_AES[63:32], "LED RESULT2 register");

    switches = 8'h03;
    #1;
    check32(led_data, EXPECTED_AES[31:0], "LED RESULT3 register");

    if (errors == 0)
      $display("TEST_PASS tb_cpu_aes cycles=%0d instr_count=%0d result=0x%032h",
               cycles, instr_count, aes_result);
    else begin
      $display("TEST_FAIL tb_cpu_aes errors=%0d result=0x%032h", errors, aes_result);
      $fatal(1, "tb_cpu_aes failed");
    end

    $finish;
  end
endmodule
