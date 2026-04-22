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
add wave -radix hex /tb_cpu_aes/switches
add wave -radix hex /tb_cpu_aes/leds
add wave -radix hex /tb_cpu_aes/led_data
add wave -radix hex /tb_cpu_aes/aes_result

add wave -divider "CPU Pipeline"
add wave -radix hex /tb_cpu_aes/dut/pc
add wave -radix hex /tb_cpu_aes/dut/if_instr
add wave -radix hex /tb_cpu_aes/dut/if_id_instr
add wave -radix hex /tb_cpu_aes/dut/id_ex_pc
add wave -radix hex /tb_cpu_aes/dut/ex_alu_result
add wave -radix hex /tb_cpu_aes/dut/ex_mem_alu_result
add wave -radix hex /tb_cpu_aes/dut/ex_mem_store_data
add wave -radix hex /tb_cpu_aes/dut/mem_wb_mem_data
add wave -radix hex /tb_cpu_aes/dut/wb_write_data
add wave -radix binary /tb_cpu_aes/dut/load_use_stall
add wave -radix binary /tb_cpu_aes/dut/ex_flush
add wave -radix binary /tb_cpu_aes/dut/halted

add wave -divider "Memory Mapped IO"
add wave -radix binary /tb_cpu_aes/dut/mem_aes_cs
add wave -radix binary /tb_cpu_aes/dut/mem_io_write
add wave -radix hex /tb_cpu_aes/dut/aes_read_data
add wave -radix hex /tb_cpu_aes/dut/io_module/led_regs

add wave -divider "AES Register Interface"
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/cs
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/we
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/address
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/write_data
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/read_data
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/ready_reg
add wave -radix binary /tb_cpu_aes/dut/aes_accelerator/valid_reg
add wave -radix hex /tb_cpu_aes/dut/aes_accelerator/result_reg

run 2500 ns
wave zoom full
