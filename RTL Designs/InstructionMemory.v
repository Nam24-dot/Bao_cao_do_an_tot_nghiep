module InstructionMemory(
    input [31:0] addr,
    output [31:0] instruction
);
    reg [31:0] mem [0:63]; // RAM Lệnh 64 Word

    initial begin
        // Đọc toàn bộ file Hex vào RAM
        //$readmemh("risc_aes.hex", mem);
		  $readmemh("isa_test_39.hex", mem);
    end

    // Gửi lệnh ra cho CPU (chia 4 do RISC-V đánh địa chỉ theo Byte)
    assign instruction = mem[addr[31:2]]; 
endmodule