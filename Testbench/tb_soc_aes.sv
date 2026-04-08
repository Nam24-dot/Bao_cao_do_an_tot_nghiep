`timescale 1ns/1ps

module tb_soc_aes;
    // Khai báo tín hiệu
    logic        clk;
    logic        rst;
    logic [7:0]  switches;
    logic [7:0]  leds;
    logic        halt_flag;

    // Khởi tạo DUT
    CPU dut (
        .clk(clk),
        .rst(rst),
        .switches(switches),
        .step_mode(1'b0),
        .step_trigger(1'b0),
        .leds(leds),
        .cycle_count(),
        .instr_count(),
        .current_pc(),
        .halt_flag(halt_flag)
    );

    // Tạo Clock
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // =========================================================
    // TASK: THEO DÕI GIAO DỊCH TRÊN BUS MMIO (BUS MONITOR)
    // =========================================================
    task automatic monitor_aes_bus();
        forever begin
            @(posedge clk);
            if (dut.aes_cs && dut.mem_write) begin
                $display("[%0t] [BUS MONITOR] CPU Ghi vao AES -> Dia chi: 0x%0h | Du lieu: 0x%0h", 
                         $time, dut.alu_result, dut.rd2);
            end
        end
    endtask

    // Kịch bản Kiểm thử chính
    initial begin
        $dumpfile("soc_aes.vcd");
        $dumpvars(0, tb_soc_aes);

        $display("==================================================");
        $display("[SOC TEST] KIEM THU TICH HOP CPU VÀ AES ACCELERATOR");
        $display("==================================================");

        // Khởi động Bus Monitor
        fork
            monitor_aes_bus();
        join_none

        // Khởi tạo
        rst = 1'b1;
        switches = 8'h00;
        #55; 
        rst = 1'b0;

        // 1. Chỉ cần CHỜ 1 LẦN DUY NHẤT cho đến khi CPU chạy xong
        wait(halt_flag == 1'b1);
        
        $display("==================================================");
        $display("[%0t] CPU DA HOAN THANH MA HOA AES", $time);
        
        // 2. IN KẾT QUẢ ĐÈN LED (8-BIT)
        $display("-> Gia tri Ban ma xuat ra LED (8-bit): 0x%0h", leds);
        if (leds !== 8'h00 && leds !== 8'hxx) begin
            $display("-> [PASS] He thong da ra ban ma hop le tren LED.");
        end else begin
            $display("-> [FAIL] Loi! Ban ma khong xuat hien hoac toan 0 tren LED.");
        end
        
        // 3. IN KẾT QUẢ FULL 128-BIT TỪ THANH GHI
        $display("\n--- KET QUA MA HOA 128-BIT (FULL CIPHERTEXT) ---");
        $display("CIPHERTEXT = %08x%08x%08x%08x", 
                 dut.regfile.regs[8],   // Word 0
                 dut.regfile.regs[9],   // Word 1
                 dut.regfile.regs[20],  // Word 2
                 dut.regfile.regs[21]); // Word 3
        
        $display("==================================================");
        
        // 4. LỆNH FINISH DUY NHẤT ĐẶT Ở CUỐI CÙNG
        $finish;
    end

    // =========================================================
    // ASSERTION: KIỂM TRA LUẬT PHẦN CỨNG
    // =========================================================
    property aes_ready_known;
        @(posedge clk) disable iff (rst)
        !$isunknown(dut.aes_accelerator.ready_reg);
    endproperty
    assert property(aes_ready_known) 
        else $error("Loi: Tin hieu Ready cua AES bi roi vao trang thai X!");

endmodule