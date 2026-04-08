module DE10_Top(
    input  CLOCK_50,   // Thạch anh 50MHz trên board
    input  [3:0] KEY,  // Các nút bấm (KEY[0] làm nút Reset)
    input  [9:0] SW,   // Các nút gạt
    output [9:0] LEDR  // Dải 10 đèn LED màu đỏ
);

    wire cpu_rst;
    wire [7:0] leds_out;
    
    // Nút nhấn trên FPGA thường tích cực mức thấp (bấm vào là 0)
    // CPU trong thiết kế cần Reset tích cực mức cao (bấm vào là 1)
    assign cpu_rst = ~KEY[0]; 

    // Gán 8 LED đầu tiên cho CPU, 2 LED cuối tắt
    assign LEDR[7:0] = leds_out;
    assign LEDR[9:8] = 2'b00;

    // Khởi tạo Hệ thống SoC (CPU + AES)
    CPU my_soc (
        .clk(CLOCK_50),
        .rst(cpu_rst),
        .switches(SW[7:0]),
        .step_mode(1'b0),     // Chạy chế độ tự động liên tục (không dùng step)
        .step_trigger(1'b0),
        .leds(leds_out),
        .cycle_count(),       // Bỏ qua không cắm dây
        .instr_count(),
        .current_pc(),
        .halt_flag()
    );

endmodule