module InstructionMemory(
    input clk,
    input [31:0] addr,
    output [31:0] instruction
);
    reg [31:0] mem [0:63];

    initial begin
        $readmemh("risc_aes.hex", mem);
        //$readmemh("isa_test_39.hex", mem);
    end

    assign instruction = mem[addr[31:2]];
endmodule
