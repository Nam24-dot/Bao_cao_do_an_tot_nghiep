transcript file {Simulation Scripts/isa_wave_transcript.log}
if {[file exists work]} {
  vdel -lib work -all
}
vlib work
vmap work work

vlog -sv +acc \
  {RTL Designs/aes_sbox.v} \
  {RTL Designs/aes_inv_sbox.v} \
  {RTL Designs/aes_key_mem.v} \
  {RTL Designs/aes_encipher_block.v} \
  {RTL Designs/aes_decipher_block.v} \
  {RTL Designs/aes_core.v} \
  {RTL Designs/aes_core_alt.v} \
  {RTL Designs/aes.v} \
  {RTL Designs/ALU.v} \
  {RTL Designs/ControlUnit.v} \
  {RTL Designs/DataMemory.v} \
  {RTL Designs/ImmGen.v} \
  {RTL Designs/PC.v} \
  {RTL Designs/PerformanceCounter.v} \
  {RTL Designs/RegisterFile.v} \
  {RTL Designs/SimpleIO.v} \
  {RTL Designs/InstructionMemory.v} \
  {RTL Designs/CPU.v} \
  {Testbench/tb_cpu_isa.sv}

vsim -wlf {Simulation Scripts/cpu_isa.wlf} -voptargs=+acc work.tb_cpu_isa

add wave -divider "Testbench"
add wave -radix binary /tb_cpu_isa/clk
add wave -radix binary /tb_cpu_isa/rst
add wave -radix unsigned /tb_cpu_isa/cycles
add wave -radix unsigned /tb_cpu_isa/errors
add wave -radix hex /tb_cpu_isa/led_data

add wave -divider "CPU Pipeline"
add wave -radix hex /tb_cpu_isa/dut/pc
add wave -radix hex /tb_cpu_isa/dut/if_instr
add wave -radix hex /tb_cpu_isa/dut/if_id_instr
add wave -radix hex /tb_cpu_isa/dut/id_opcode
add wave -radix hex /tb_cpu_isa/dut/id_rs1
add wave -radix hex /tb_cpu_isa/dut/id_rs2
add wave -radix hex /tb_cpu_isa/dut/id_rd
add wave -radix hex /tb_cpu_isa/dut/id_imm
add wave -radix hex /tb_cpu_isa/dut/ex_alu_result
add wave -radix hex /tb_cpu_isa/dut/ex_mem_alu_result
add wave -radix hex /tb_cpu_isa/dut/mem_final_data
add wave -radix hex /tb_cpu_isa/dut/wb_write_data
add wave -radix binary /tb_cpu_isa/dut/load_use_stall
add wave -radix binary /tb_cpu_isa/dut/ex_flush
add wave -radix binary /tb_cpu_isa/dut/halted

add wave -divider "Register File"
add wave -radix hex /tb_cpu_isa/dut/regfile/regs

run 1200 ns
wave zoom full
