module SimpleIO(
    input clk, rst,
    input [7:0] switches,
    input [31:0] cpu_data,
    input write_enable,
    output reg [31:0] led_data
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            led_data <= 32'h0;
        else if (write_enable)
            led_data <= cpu_data;
    end
endmodule
