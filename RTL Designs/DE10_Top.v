module DE10_Top (
    input CLOCK_50,
    input [3:0] KEY,
    input [9:0] SW,
    output [9:0] LEDR
);

    wire cpu_rst;
    wire [7:0] leds_out;
    wire [31:0] led_data;
    reg [4:0] clk_div;
    wire soc_clk;

    assign cpu_rst = ~KEY[0];

    always @(posedge CLOCK_50 or posedge cpu_rst) begin
        if (cpu_rst)
            clk_div <= 5'd0;
        else
            clk_div <= clk_div + 5'd1;
    end

    assign soc_clk = clk_div[4]; // 50 MHz / 32 = 1.5625 MHz

    // SW[9:8] selects RESULT0..RESULT3, SW[7:6] selects byte inside that 32-bit word.
    assign LEDR[7:0] = (SW[7:6] == 2'b00) ? led_data[7:0]   :
                       (SW[7:6] == 2'b01) ? led_data[15:8]  :
                       (SW[7:6] == 2'b10) ? led_data[23:16] :
                                            led_data[31:24];
    assign LEDR[9:8] = SW[9:8];

    CPU my_soc (
        .clk(soc_clk),
        .rst(cpu_rst),
        .switches({6'b0, SW[9:8]}),
        .step_mode(1'b0),
        .step_trigger(1'b0),
        .leds(leds_out),
        .led_data(led_data),
        .cycle_count(),
        .instr_count(),
        .current_pc(),
        .halt_flag()
    );
endmodule
