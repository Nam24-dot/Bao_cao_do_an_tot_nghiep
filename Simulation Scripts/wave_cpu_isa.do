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

add wave -divider "CPU Control"
add wave -radix hex /tb_cpu_isa/dut/pc
add wave -radix hex /tb_cpu_isa/dut/instr
add wave -radix binary /tb_cpu_isa/dut/reg_write
add wave -radix binary /tb_cpu_isa/dut/mem_read
add wave -radix binary /tb_cpu_isa/dut/mem_write
add wave -radix binary /tb_cpu_isa/dut/branch
add wave -radix binary /tb_cpu_isa/dut/branch_taken
add wave -radix binary /tb_cpu_isa/dut/jump
add wave -radix binary /tb_cpu_isa/dut/jalr
add wave -radix binary /tb_cpu_isa/dut/halt

add wave -divider "ALU And Memory"
add wave -radix hex /tb_cpu_isa/dut/rd1
add wave -radix hex /tb_cpu_isa/dut/rd2
add wave -radix hex /tb_cpu_isa/dut/imm
add wave -radix hex /tb_cpu_isa/dut/alu_result
add wave -radix hex /tb_cpu_isa/dut/write_data
add wave -radix hex /tb_cpu_isa/dut/mem_data
add wave -radix binary /tb_cpu_isa/dut/dmem_read
add wave -radix binary /tb_cpu_isa/dut/dmem_write

add wave -divider "Register File"
add wave -radix hex /tb_cpu_isa/dut/regfile/regs

run 1200 ns
wave zoom full
