module SimpleIO(
    input clk, rst,
    input [7:0] switches,
    input [31:0] addr,
    input [31:0] cpu_data,
    input write_enable,
    output [31:0] led_data
);
    reg [31:0] led_regs [0:3];
    integer i;

    wire [1:0] write_index = addr[3:2];
    wire [1:0] read_index = switches[1:0];

    assign led_data = led_regs[read_index];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1)
                led_regs[i] <= 32'h0;
        end else if (write_enable) begin
            led_regs[write_index] <= cpu_data;
        end
    end
endmodule
