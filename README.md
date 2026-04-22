# Bao cao do an tot nghiep

Repository nay luu tru ma nguon, testbench, script mo phong, cau hinh Quartus va trang bao cao cho de tai:

**Thiet ke bo vi xu ly RISC-V 5-stage pipeline tich hop bo tang toc ma hoa AES tuy bien tren FPGA DE10 Standard.**

## Tom tat du an

Du an xay dung mot SoC nho gom CPU RISC-V RV32I subset, bo nho lenh, bo nho du lieu, khoi IO LED/SW va khoi tang toc AES memory-mapped. CPU nap key va data block 128-bit vao AES accelerator bang cac lenh `sw`, kich hoat qua thanh ghi dieu khien, cho co `ready/valid`, doc ciphertext 128-bit va dua ket qua ra LED de quan sat tren FPGA.

Phien ban hien tai co cac diem chinh:

- CPU da duoc chuyen sang pipeline 5 tang: IF, ID, EX, MEM, WB.
- Ho tro forwarding, WB-to-ID bypass, load-use stall va flush cho branch/jump.
- AES accelerator co che do custom AES khop voi phan mem Python trong `Software/`.
- GUI Python cho phep nhap key va input block 128-bit, sau do tu sinh file `risc_aes.hex` tuong thich voi CPU.
- Firmware AES ghi du 4 word ket qua `RESULT0..RESULT3` ra LED IO register.
- Tren DE10 Standard, `SW[9:8]` chon word 32-bit va `SW[7:6]` chon byte trong word do de hien thi tren `LEDR[7:0]`.

## Cau truc thu muc

### `RTL Designs/`

Chua toan bo ma nguon Verilog cua SoC.

- `CPU.v`: CPU RISC-V pipeline 5 stage, dieu khien PC, hazard, forwarding, memory access, AES MMIO va IO LED.
- `ControlUnit.v`: giai ma opcode/funct cua tap lenh RV32I dang ho tro.
- `ImmGen.v`: tao immediate cho cac dinh dang I/S/B/U/J.
- `ALU.v`: khoi tinh toan so hoc/logic va so sanh.
- `RegisterFile.v`: 32 thanh ghi RISC-V.
- `InstructionMemory.v`: bo nho lenh doc file hex.
- `DataMemory.v`: bo nho du lieu, ho tro load/store byte, halfword, word.
- `SimpleIO.v`: 4 thanh ghi LED 32-bit, cho phep chon `RESULT0..RESULT3` bang switch.
- `DE10_Top.v`: top-level cho FPGA DE10 Standard, chia clock, noi switch/key/LED voi CPU.
- `aes.v`: wrapper memory-mapped cho AES accelerator.
- `aes_core.v`, `aes_core_alt.v`: loi AES va che do custom.
- `aes_encipher_block.v`, `aes_decipher_block.v`: datapath ma hoa/giai ma AES.
- `aes_key_mem.v`: sinh round key AES.
- `aes_sbox.v`, `aes_inv_sbox.v`: S-box va inverse S-box.
- `PC.v`, `PerformanceCounter.v`: cac module phu tro cho PC va dem hieu nang.

### `Software/`

Chua phan mem Python dung de tao du lieu/firmware cho CPU.

- `Custom_AES_OneFile_GUI.py`: GUI nhap key va input block 128-bit, chay custom AES, hien thi ket qua va tao `risc_aes.hex` cho CPU.
- `Custom_AES_OneFile_GUI.spec`: file cau hinh PyInstaller neu can dong goi thanh `.exe`.

Custom AES trong phan mem va RTL giu cau truc AES chuan ben trong, nhung them cac buoc tuy bien truoc/sau AES:

- XOR input mask.
- Hoan vi byte input.
- XOR key mask.
- AES-128 ECB tren block da bien doi.
- XOR output mask.
- Hoan vi nguoc va rotate byte dau ra.

### `Testbench/`

Chua file test va chuong trinh hex dung cho mo phong.

- `tb_cpu_isa.sv`: test tap lenh CPU, kiem tra ALU, immediate, load/store, branch/jump va system instruction.
- `tb_cpu_aes.sv`: test CPU giao tiep AES, ghi key/block, chay AES, doc result va kiem tra LED IO.
- `tb_soc_aes.sv`: test SoC/AES bo sung neu can dung rieng.
- `isa_full.hex`: chuong trinh test ISA.
- `isa_test_39.hex`: chuong trinh test 39 lenh CPU.
- `risc_aes.hex`: firmware AES duoc GUI tao ra, CPU nap file nay de chay ma hoa.

### `Simulation Scripts/`

Chua script chay QuestaSim 10.2c.

- `run_questa_all.ps1`: chay toan bo regression ISA va AES.
- `run_isa.do`: compile va run test ISA.
- `run_aes.do`: compile va run test CPU-AES.
- `wave_cpu_isa.do`: cau hinh waveform cho test ISA.
- `wave_cpu_aes.do`: cau hinh waveform cho test AES.
- `open_isa_wave.ps1`, `open_aes_wave.ps1`: mo waveform `.wlf` sau khi da chay mo phong.

### `Quartus Project/`

Chua file cau hinh Quartus cho DE10 Standard.

- `RISC_V_Microprocessor.qpf`: Quartus project file.
- `RISC_V_Microprocessor.qsf`: gan file source, pin assignment va cau hinh FPGA.
- `RISC_V_Microprocessor.sdc`: rang buoc timing/clock.

### `Ket_qua_chay_tren_FPGA_DE10_Standard/`

Chua anh/minh chung ket qua chay thuc te tren board FPGA DE10 Standard.

### `Ket_qua_va_Waveform/`

Chua anh ket qua mo phong, waveform CPU va AES.

### `assets/`

Chua CSS va tai nguyen cho trang GitHub Pages.

### File goc repository

- `index.html`: trang blog/bao cao tinh tren GitHub Pages.
- `README.md`: file mo ta du an nay.
- `risc_aes.hex`, `isa_test_39.hex`: ban sao nhanh o thu muc goc de tien chay tool/script cu.

## Cach tao firmware AES moi

1. Chay GUI Python:

```powershell
python .\Software\Custom_AES_OneFile_GUI.py
```

2. Nhap `Key (128-bit hex)` va `Input block (128-bit hex)`.
3. Bam `Tao risc_aes.hex cho CPU`.
4. Lay file `risc_aes.hex` moi sinh ra de nap cho CPU/InstructionMemory.
5. GUI dong thoi cap nhat expected result trong `tb_cpu_aes.sv` khi chay o dung thu muc project.

## Cach chay mo phong QuestaSim

Tu thu muc goc repository:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\run_questa_all.ps1"
```

Ket qua mong doi:

```text
TEST_PASS tb_cpu_isa
TEST_PASS tb_cpu_aes
```

Mo waveform AES:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\open_aes_wave.ps1"
```

Mo waveform ISA:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\open_isa_wave.ps1"
```

## Cach quan sat ket qua tren FPGA

Ciphertext AES co 128 bit, trong khi DE10 Standard chi co 10 LED do. Vi vay du an hien thi theo tung byte:

- `SW[9:8] = 00`: chon `RESULT0`, tuc 32 bit cao nhat cua ciphertext.
- `SW[9:8] = 01`: chon `RESULT1`.
- `SW[9:8] = 10`: chon `RESULT2`.
- `SW[9:8] = 11`: chon `RESULT3`, tuc 32 bit thap nhat cua ciphertext.
- `SW[7:6] = 00`: hien thi byte `[7:0]` cua word dang chon.
- `SW[7:6] = 01`: hien thi byte `[15:8]`.
- `SW[7:6] = 10`: hien thi byte `[23:16]`.
- `SW[7:6] = 11`: hien thi byte `[31:24]`.

`LEDR[7:0]` hien thi byte du lieu, `LEDR[9:8]` hien thi word dang chon.

## Dia chi memory-mapped AES va IO

- AES base: `0x80000000`.
- AES control: `0x80000020`.
- AES status: `0x80000024`.
- AES config: `0x80000028`.
- AES key words: `0x80000040` den `0x8000004C`.
- AES block words: `0x80000080` den `0x8000008C`.
- AES result words: `0x800000C0` den `0x800000CC`.
- LED IO base: `0xFFFF0000`.
- LED result registers: `0xFFFF0000`, `0xFFFF0004`, `0xFFFF0008`, `0xFFFF000C`.

## Yeu cau cong cu

- QuestaSim 10.2c de mo phong.
- Quartus Prime Lite phu hop voi DE10 Standard/Cyclone V de compile FPGA.
- Python 3 va `pycryptodome` neu dung GUI custom AES:

```powershell
python -m pip install pycryptodome
```
