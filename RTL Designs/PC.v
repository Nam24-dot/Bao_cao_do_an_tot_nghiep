module PC(
    input clk, rst, step_mode, step_trigger, halt,
    input [31:0] pc_next,
    output reg [31:0] pc
);
    reg step_prev;
    wire step_pulse;

    assign step_pulse = step_trigger && !step_prev;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            pc <= 0;
            step_prev <= 0;
        end else begin
            step_prev <= step_trigger;
            if(!halt && (!step_mode || step_pulse))
                pc <= pc_next;
        end
    end
endmodule