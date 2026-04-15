transcript file {Simulation Scripts/aes_wave_transcript.log}
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
  {Testbench/tb_cpu_aes.sv}

vsim -wlf {Simulation Scripts/cpu_aes.wlf} -voptargs=+acc work.tb_cpu_aes

add wave -divider "Testbench"
add wave -radix binary /tb_cpu_aes/clk
add wave -radix binary /tb_cpu_aes/rst
add wave -radix unsigned /tb_cpu_aes/cycles
add wave -radix unsigned /tb_cpu_aes/errors
add wave -radix hex /tb_cpu_aes/leds

add wave -divider "CPU Bus"
add wave -radix hex /tb_cpu_aes/dut/pc
add wave -radix hex /tb_cpu_aes/dut/instr
add wave -radix hex /tb_cpu_aes/dut/alu_result
add wave -radix hex /tb_cpu_aes/dut/rd2
add wave -radix hex /tb_cpu_aes/dut/write_data
add wave -radix binary /tb_cpu_aes/dut/mem_read
add wave -radix binary /tb_cpu_aes/dut/mem_write
add wave -radix binary /tb_cpu_aes/dut/aes_cs
add wave -radix binary /tb_cpu_aes/dut/io_write

add wave -divider "AES Register Interface"
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/cs
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/we
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/address
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/write_data
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/read_data
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/ready_reg
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/valid_reg
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/result_reg

add wave -divider "AES Core"
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/gen_alt_core/core/ready
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/gen_alt_core/core/result_valid
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/gen_alt_core/core/state_reg
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/gen_alt_core/core/cmd_reg
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/gen_alt_core/core/legacy_init
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/gen_alt_core/core/legacy_next
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/gen_alt_core/core/legacy_ready
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/gen_alt_core/core/legacy_valid
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/gen_alt_core/core/result_reg

run 2500 ns
wave zoom full
