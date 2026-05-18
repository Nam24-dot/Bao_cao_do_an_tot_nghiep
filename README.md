# RISC-V 5-state pipelined với mã hóa AES đã triển khai thành công trên FPGA

Repository này lưu trữ mã nguồn, testbench, script mô phỏng, cấu hình Quartus và trang báo cáo cho đề tài:

**Thiết kế bộ vi xử lý RISC-V 5-stage pipeline tích hợp bộ tăng tốc mã hóa AES tùy biến trên FPGA DE10 Standard.**

## Tóm tắt dự án

Dự án xây dựng một SoC nhỏ gồm CPU RISC-V RV32I subset, bộ nhớ lệnh, bộ nhớ dữ liệu, khối IO LED/SW và khối tăng tốc AES memory-mapped. CPU nạp key và data block 128-bit vào AES accelerator bằng các lệnh `sw`, kích hoạt qua thanh ghi điều khiển, chờ cờ `ready/valid`, đọc ciphertext 128-bit và đưa kết quả ra LED để quan sát trên FPGA.

Phiên bản hiện tại có các điểm chính:

- CPU đã được chuyển sang pipeline 5 tầng: IF, ID, EX, MEM, WB.
- Hỗ trợ forwarding, WB-to-ID bypass, load-use stall và flush cho branch/jump.
- AES accelerator có chế độ Custom AES khớp với phần mềm Python trong `Software/`.
- GUI Python cho phép nhập key và input block 128-bit, sau đó tự sinh file `risc_aes.hex` tương thích với CPU.
- Firmware AES ghi đủ 4 word kết quả `RESULT0..RESULT3` ra LED IO register.
- Trên DE10 Standard, `SW[9:8]` chọn word 32-bit và `SW[7:6]` chọn byte trong word đó để hiển thị trên `LEDR[7:0]`.

## Trạng thái tư liệu kết quả

Hai thư mục `Ket_qua_chay_tren_FPGA_DE10_Standard/` và `Ket_qua_va_Waveform/` hiện đang chứa ảnh/video/waveform từ bản cũ của đồ án. Các tư liệu này **chưa đại diện cho phiên bản hiện tại** sau khi CPU pipeline 5 tầng, AES được tùy biến theo phần mềm và LED IO được mở rộng để quan sát đủ 128 bit theo từng word/byte.

Khi chạy lại bản mới, cần cập nhật lại các ảnh/video/waveform trong hai thư mục này theo đúng firmware hiện tại. Kết quả mô phỏng hiện tại đã được xác nhận bằng QuestaSim với:

```text
TEST_PASS tb_cpu_isa
TEST_PASS tb_cpu_aes
result=0xf4199f768a3a321a15c74d182bf6d6b5
```

## Cấu trúc thư mục

### `RTL Designs/`

Chứa toàn bộ mã nguồn Verilog của SoC.

- `CPU.v`: CPU RISC-V pipeline 5 stage, điều khiển PC, hazard, forwarding, memory access, AES MMIO và IO LED.
- `ControlUnit.v`: giải mã opcode/funct của tập lệnh RV32I đang hỗ trợ.
- `ImmGen.v`: tạo immediate cho các định dạng I/S/B/U/J.
- `ALU.v`: khối tính toán số học/logic và so sánh.
- `RegisterFile.v`: 32 thanh ghi RISC-V.
- `InstructionMemory.v`: bộ nhớ lệnh đọc file hex.
- `DataMemory.v`: bộ nhớ dữ liệu, hỗ trợ load/store byte, halfword, word.
- `SimpleIO.v`: 4 thanh ghi LED 32-bit, cho phép chọn `RESULT0..RESULT3` bằng switch.
- `DE10_Top.v`: top-level cho FPGA DE10 Standard, chia clock, nối switch/key/LED với CPU.
- `aes.v`: wrapper memory-mapped cho AES accelerator.
- `aes_core.v`, `aes_core_alt.v`: lõi AES và chế độ custom.
- `aes_encipher_block.v`, `aes_decipher_block.v`: datapath mã hóa/giải mã AES.
- `aes_key_mem.v`: sinh round key AES.
- `aes_sbox.v`, `aes_inv_sbox.v`: S-box và inverse S-box.
- `PC.v`, `PerformanceCounter.v`: các module phụ trợ cho PC và bộ đếm hiệu năng.

### `Software/`

Chứa phần mềm Python dùng để tạo dữ liệu/firmware cho CPU.

- `Custom_AES_OneFile_GUI.py`: GUI nhập key và input block 128-bit, chạy Custom AES, hiển thị kết quả và tạo `risc_aes.hex` cho CPU.
- `Custom_AES_OneFile_GUI.spec`: file cấu hình PyInstaller nếu cần đóng gói thành `.exe`.

Custom AES trong phần mềm và RTL giữ cấu trúc AES chuẩn bên trong, nhưng thêm các bước tùy biến trước/sau AES:

- XOR input mask.
- Hoán vị byte input.
- XOR key mask.
- AES-128 ECB trên block đã biến đổi.
- XOR output mask.
- Hoán vị ngược và rotate byte đầu ra.

### `Testbench/`

Chứa file test và chương trình hex dùng cho mô phỏng.

- `tb_cpu_isa.sv`: test tập lệnh CPU, kiểm tra ALU, immediate, load/store, branch/jump và system instruction.
- `tb_cpu_aes.sv`: test CPU giao tiếp AES, ghi key/block, chạy AES, đọc result và kiểm tra LED IO.
- `tb_soc_aes.sv`: test SoC/AES bổ sung nếu cần dùng riêng.
- `isa_full.hex`: chương trình test ISA.
- `isa_test_39.hex`: chương trình test 39 lệnh CPU.
- `risc_aes.hex`: firmware AES được GUI tạo ra, CPU nạp file này để chạy mã hóa.

### `Simulation Scripts/`

Chứa script chạy QuestaSim 10.2c.

- `run_questa_all.ps1`: chạy toàn bộ regression ISA và AES.
- `run_isa.do`: compile và run test ISA.
- `run_aes.do`: compile và run test CPU-AES.
- `wave_cpu_isa.do`: cấu hình waveform cho test ISA.
- `wave_cpu_aes.do`: cấu hình waveform cho test AES.
- `open_isa_wave.ps1`, `open_aes_wave.ps1`: mở waveform `.wlf` sau khi đã chạy mô phỏng.

### `Quartus Project/`

Chứa file cấu hình Quartus cho DE10 Standard.

- `RISC_V_Microprocessor.qpf`: Quartus project file.
- `RISC_V_Microprocessor.qsf`: gán file source, pin assignment và cấu hình FPGA.
- `RISC_V_Microprocessor.sdc`: ràng buộc timing/clock.

### `Ket_qua_chay_tren_FPGA_DE10_Standard/`

Chứa ảnh/video chạy trên board FPGA DE10 Standard. Lưu ý: nội dung hiện tại là tư liệu cũ, chưa đúng với phiên bản pipeline + Custom AES + hiển thị đủ 128 bit hiện tại. Cần cập nhật lại sau khi compile/nạp FPGA bản mới.

### `Ket_qua_va_Waveform/`

Chứa ảnh kết quả mô phỏng và waveform. Lưu ý: nội dung hiện tại là tư liệu cũ, chưa đúng với kết quả mô phỏng hiện tại. Cần xuất lại waveform từ `Simulation Scripts/open_aes_wave.ps1` và `Simulation Scripts/open_isa_wave.ps1`.

### `assets/`

Chứa CSS và tài nguyên cho trang GitHub Pages.

### File gốc repository

- `index.html`: trang blog/báo cáo tĩnh trên GitHub Pages.
- `README.md`: file mô tả dự án này.
- `risc_aes.hex`, `isa_test_39.hex`: bản sao nhanh ở thư mục gốc để tiện chạy tool/script cũ.

## Cách tạo firmware AES mới

1. Chạy GUI Python:

```powershell
python .\Software\Custom_AES_OneFile_GUI.py
```

2. Nhập `Key (128-bit hex)` và `Input block (128-bit hex)`.
3. Bấm `Tạo risc_aes.hex cho CPU` trong GUI.
4. Lấy file `risc_aes.hex` mới sinh ra để nạp cho CPU/InstructionMemory.
5. GUI đồng thời cập nhật expected result trong `tb_cpu_aes.sv` khi chạy ở đúng thư mục project.

## Cách chạy mô phỏng QuestaSim

Từ thư mục gốc repository:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\run_questa_all.ps1"
```

Kết quả mong đợi:

```text
TEST_PASS tb_cpu_isa
TEST_PASS tb_cpu_aes
```

Mở waveform AES:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\open_aes_wave.ps1"
```

Mở waveform ISA:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\open_isa_wave.ps1"
```

## Cách quan sát kết quả trên FPGA

Ciphertext AES có 128 bit, trong khi DE10 Standard chỉ có 10 LED đỏ. Vì vậy dự án hiển thị theo từng byte:

- `SW[9:8] = 00`: chọn `RESULT0`, tức 32 bit cao nhất của ciphertext.
- `SW[9:8] = 01`: chọn `RESULT1`.
- `SW[9:8] = 10`: chọn `RESULT2`.
- `SW[9:8] = 11`: chọn `RESULT3`, tức 32 bit thấp nhất của ciphertext.
- `SW[7:6] = 00`: hiển thị byte `[7:0]` của word đang chọn.
- `SW[7:6] = 01`: hiển thị byte `[15:8]`.
- `SW[7:6] = 10`: hiển thị byte `[23:16]`.
- `SW[7:6] = 11`: hiển thị byte `[31:24]`.

`LEDR[7:0]` hiển thị byte dữ liệu, `LEDR[9:8]` hiển thị word đang chọn.

## Địa chỉ memory-mapped AES và IO

- AES base: `0x80000000`.
- AES control: `0x80000020`.
- AES status: `0x80000024`.
- AES config: `0x80000028`.
- AES key words: `0x80000040` đến `0x8000004C`.
- AES block words: `0x80000080` đến `0x8000008C`.
- AES result words: `0x800000C0` đến `0x800000CC`.
- LED IO base: `0xFFFF0000`.
- LED result registers: `0xFFFF0000`, `0xFFFF0004`, `0xFFFF0008`, `0xFFFF000C`.

## Yêu cầu công cụ

- QuestaSim 10.2c để mô phỏng.
- Quartus Prime Lite phù hợp với DE10 Standard/Cyclone V để compile FPGA.
- Python 3 và `pycryptodome` nếu dùng GUI Custom AES:

```powershell
python -m pip install pycryptodome
```
