# Kết quả mô phỏng và waveform

Thư mục này đang chứa ảnh/waveform từ bản mô phỏng cũ của đồ án.

Các tư liệu hiện có chưa đại diện cho phiên bản hiện tại sau khi cập nhật CPU pipeline, Custom AES và LED IO 128-bit. Kết quả mô phỏng hiện tại cần được tạo lại bằng script trong thư mục `Simulation Scripts/`.

Lệnh chạy regression:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\run_questa_all.ps1"
```

Kết quả đúng hiện tại:

```text
TEST_PASS tb_cpu_isa
TEST_PASS tb_cpu_aes
result=0xf4199f768a3a321a15c74d182bf6d6b5
```

Lệnh mở waveform AES:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\open_aes_wave.ps1"
```

Lệnh mở waveform ISA:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Simulation Scripts\open_isa_wave.ps1"
```
