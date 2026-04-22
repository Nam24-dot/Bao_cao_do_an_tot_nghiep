# Kết quả chạy trên FPGA DE10 Standard

Thư mục này đang chứa ảnh/video từ bản kiểm tra cũ của đồ án.

Các tư liệu hiện có chưa đại diện cho phiên bản hiện tại sau các thay đổi sau:

- CPU pipeline 5 tầng.
- AES đã chạy ở chế độ Custom AES khớp với phần mềm Python.
- Firmware `risc_aes.hex` được tạo tự động từ key và input block.
- LED IO đã được mở rộng để lưu đủ `RESULT0..RESULT3` và quan sát đủ 128 bit theo từng word/byte.

Khi chạy lại trên FPGA, cần cập nhật lại ảnh/video trong thư mục này theo cách quan sát mới:

- `SW[9:8]` chọn `RESULT0..RESULT3`.
- `SW[7:6]` chọn byte trong word 32-bit đang chọn.
- `LEDR[7:0]` hiển thị byte dữ liệu.
- `LEDR[9:8]` hiển thị word kết quả đang chọn.
