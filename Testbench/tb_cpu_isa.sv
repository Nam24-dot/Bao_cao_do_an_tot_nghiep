`timescale 1ns/1ps

module tb_cpu_isa;
    // Khai báo các tín hiệu giao tiếp với CPU
    logic        clk;
    logic        rst;
    logic [7:0]  switches;
    logic        step_mode;
    logic        step_trigger;
    
    // Các tín hiệu quan sát từ CPU
    logic [7:0]  leds;
    logic [31:0] cycle_count;
    logic [31:0] instr_count;
    logic [31:0] current_pc;
    logic        halt_flag;

    // Khởi tạo DUT (Device Under Test) - Khối CPU của bạn
    CPU dut (
        .clk(clk),
        .rst(rst),
        .switches(switches),
        .step_mode(step_mode),
        .step_trigger(step_trigger),
        .leds(leds),
        .cycle_count(cycle_count),
        .instr_count(instr_count),
        .current_pc(current_pc),
        .halt_flag(halt_flag)
    );

    // =========================================================
    // 1. TẠO XUNG CLOCK
    // =========================================================
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // =========================================================
    // 2. KHỐI TRACE MONITOR (GIÁM SÁT THỜI GIAN THỰC)
    // Đã được chuyển ra ngoài đứng độc lập
    // =========================================================
    logic [31:0] shadow_regs [0:31];
    integer i;

    initial begin
        for(i=0; i<32; i++) shadow_regs[i] = 32'h0;
    end

    // Kiểm tra sau mỗi sườn âm của Clock
    always @(negedge clk) begin
        if (!rst) begin
            // Theo dõi sự thay đổi trong Tập thanh ghi (Register File)
            for(i=1; i<32; i++) begin // Bỏ qua x0 vì luôn bằng 0
                if (dut.regfile.regs[i] !== shadow_regs[i]) begin
                    $display("[%0t] PC = 0x%0h | Lenh ghi vao x%0d -> Thuc te: 0x%0h", 
                             $time, current_pc, i, dut.regfile.regs[i]);
                    // Cập nhật lại bản sao
                    shadow_regs[i] = dut.regfile.regs[i];
                end
            end
            
            // Theo dõi CPU ghi xuống Bộ nhớ (RAM)
            if (dut.mem_write) begin
                $display("[%0t] PC = 0x%0h | Lenh ghi RAM   -> Dia chi: 0x%0h | Thuc te: 0x%0h", 
                         $time, current_pc, dut.alu_result, dut.rd2);
            end
        end
    end

    // =========================================================
    // 3. KỊCH BẢN KIỂM THỬ CHÍNH
    // =========================================================
    initial begin
        // Bật ghi sóng Waveform để debug nếu cần
        $dumpfile("cpu_isa_test.vcd");
        $dumpvars(0, tb_cpu_isa);

        $display("==================================================");
        $display("[ISA TEST] KHOI DONG KIEM THU 39 LENH RV32I");
        $display("==================================================");

        // Khởi tạo trạng thái ban đầu
        switches = 8'h00;
        step_mode = 1'b0;      // Chạy chế độ tự động (không step)
        step_trigger = 1'b0;
        rst = 1'b1;            // Nhấn giữ Reset

        // Giữ Reset trong 5 chu kỳ clock cho hệ thống ổn định
        repeat(5) @(posedge clk);
        rst = 1'b0;            // Thả Reset, CPU bắt đầu chạy
        $display("[%0t] Da tha Reset, CPU dang chay...\n", $time);

        // Chờ CPU thi hành xong (khi gặp lệnh EBREAK, halt_flag sẽ lên 1)
        fork
            wait(halt_flag == 1'b1);
            begin
                repeat(2000) @(posedge clk);
                $error("[%0t] TIMEOUT! CPU bi ket, khong the den duoc lenh EBREAK.", $time);
                $stop;
            end
        join_any
        disable fork; // Tắt luồng Timeout nếu CPU đã chạy xong bình thường

        $display("\n[%0t] CPU da dung lai tai PC = 0x%0h", $time, current_pc);

        // =========================================================
        // KIỂM TRA HỘP TRẮNG (WHITE-BOX CHECKING)
        // =========================================================
        $display("\n--- TONG KET KET QUA ---");
        
        // Theo thiết kế của file Hex, nếu sai nó ghi 0 vào x10, nếu đúng hết nó ghi 1 vào x10
        if (dut.regfile.regs[10] === 32'h00000001) begin
            $display("-> TRANG THAI: [ PASS ] - Tuyet voi! CPU cua ban da hoat dong chinh xac ca 39 lenh.");
        end else if (dut.regfile.regs[10] === 32'h00000000) begin
            $display("-> TRANG THAI: [ FAIL ] - Phat hien loi logic! CPU da tinh toan hoac re nhanh sai.");
        end else begin
            $display("-> TRANG THAI: [ LOI KHONG XAC DINH ] - Gia tri x10 = 0x%0h (Nghi ngo CPU khong ghi duoc vao Register File)", dut.regfile.regs[10]);
        end

        // In hiệu suất cơ bản
        $display("Tong so chu ky Clock: %0d", cycle_count);
        $display("Tong so lenh da chay : %0d", instr_count);
        $display("==================================================");
        $finish;
    end
endmodule
