module SimpleIO(
    input clk, rst,
    input [7:0] switches,
    input [31:0] cpu_data,
    input write_enable,
    output reg [7:0] leds
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            leds <= 0;
        else if (write_enable)
            leds <= cpu_data[7:0];
    end
endmodule