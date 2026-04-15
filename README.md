# Bao cao do an tot nghiep

Repository nay luu tru source RTL, testbench mo phong va trang bao cao GitHub Pages cho de tai:

**Thiet ke bo vi xu ly RISC-V tich hop bo tang toc ma hoa AES tren FPGA DE10 Standard.**

## Noi dung chinh

- `RTL Designs/`: ma nguon Verilog cua CPU, AES accelerator va top-level DE10.
- `Testbench/`: testbench SystemVerilog, file hex chuong trinh test ISA va AES.
- `Simulation Scripts/`: script QuestaSim de chay regression va mo waveform.
- `Quartus Project/`: file cau hinh Quartus.
- `index.html`: trang blog/bao cao tinh cho GitHub Pages.

## Chay mo phong

Tu thu muc project goc:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\run_questa_all.ps1"
```

Ket qua mong doi:

```text
TEST_PASS tb_cpu_isa
TEST_PASS tb_cpu_aes
```

## Xem waveform

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\open_aes_wave.ps1"
```

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\open_isa_wave.ps1"
```
