module DataMemory(
    input clk, we, re,
    input [1:0] size,
    input sign_ext,
    input [31:0] addr, wd,
    output reg [31:0] rd
);
    reg [7:0] mem [0:1023]; // Tăng RAM lên 1KB để thoải mái chạy
    wire [1:0] byte_offset;
    wire [31:0] aligned_addr;

    assign byte_offset = addr[1:0];
    assign aligned_addr = {addr[31:2], 2'b00};

    // Read logic
    always @(*) begin
        case (size)
            2'b00: begin // Byte
                if (sign_ext) rd = {{24{mem[addr][7]}}, mem[addr]};
                else          rd = {24'b0, mem[addr]};
            end
            2'b01: begin // Halfword
                if (sign_ext) rd = {{16{mem[addr+1][7]}}, mem[addr+1], mem[addr]};
                else          rd = {16'b0, mem[addr+1], mem[addr]};
            end
            2'b10: begin // Word
                rd = {mem[aligned_addr+3], mem[aligned_addr+2], mem[aligned_addr+1], mem[aligned_addr]};
            end
            default: rd = 0;
        endcase
    end

    // Write logic
    always @(posedge clk) begin
        if (we) begin
            case (size)
                2'b00: mem[addr] <= wd[7:0]; // Byte
                2'b01: begin // Halfword
                    mem[addr]   <= wd[7:0];
                    mem[addr+1] <= wd[15:8];
                end
                2'b10: begin // Word
                    mem[aligned_addr]   <= wd[7:0];
                    mem[aligned_addr+1] <= wd[15:8];
                    mem[aligned_addr+2] <= wd[23:16];
                    mem[aligned_addr+3] <= wd[31:24];
                end
            endcase
        end
    end
endmodule