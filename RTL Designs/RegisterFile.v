module RegisterFile(
    input clk, we,
    input [4:0] ra1, ra2, wa,
    input [31:0] wd,
    output [31:0] rd1, rd2
);
    reg [31:0] regs [0:31];
    integer i;

    initial begin
        for (i=0; i<32; i=i+1)
            regs[i] = 0;
    end

    assign rd1 = (ra1 == 0) ? 0 : regs[ra1];
    assign rd2 = (ra2 == 0) ? 0 : regs[ra2];

    always @(posedge clk) begin
        if (we && wa != 0)
            regs[wa] <= wd;
    end
endmodule