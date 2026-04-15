module aes_core_alt #(
                    parameter CUSTOM_MODE = 1'b0,
                    parameter [127 : 0] CUSTOM_IN_MASK  = 128'h4e414d5f435553544f4d5f4145535f31,
                    parameter [127 : 0] CUSTOM_OUT_MASK = 128'h444e544e5f52495343565f4145532121
                   )
                   (
                    input wire            clk,
                    input wire            reset_n,

                    input wire            encdec,
                    input wire            init,
                    input wire            next,
                    output wire           ready,

                    input wire [255 : 0]  key,
                    input wire            keylen,

                    input wire [127 : 0]  block,
                    output wire [127 : 0] result,
                    output wire           result_valid
                   );

  //----------------------------------------------------------------
  // Alternate AES core.
  //
  // The AES datapath is still the proven iterative core from the
  // original project. This wrapper adds registered command, key,
  // block and result signals so the memory-mapped CPU bus sees stable
  // AES status/data while keeping the old core available.
  //----------------------------------------------------------------
  localparam CMD_IDLE   = 2'h0;
  localparam CMD_INIT   = 2'h1;
  localparam CMD_NEXT   = 2'h2;

  localparam STATE_IDLE = 2'h0;
  localparam STATE_PULSE = 2'h1;
  localparam STATE_BUSY = 2'h2;

  reg [1 : 0]  cmd_reg;
  reg [1 : 0]  state_reg;
  reg          encdec_reg;
  reg          keylen_reg;
  reg [255:0]  key_reg;
  reg [127:0]  block_reg;
  reg [127:0]  result_reg;
  reg          valid_reg;

  wire         legacy_ready;
  wire [127:0] legacy_result;
  wire         legacy_valid;
  wire         legacy_init;
  wire         legacy_next;
  wire [127:0] custom_input_block;
  wire [127:0] custom_output_block;

  assign custom_input_block =
    CUSTOM_MODE ? (encdec ? (block ^ CUSTOM_IN_MASK) : (block ^ CUSTOM_OUT_MASK)) : block;

  assign custom_output_block =
    CUSTOM_MODE ? (encdec_reg ? (legacy_result ^ CUSTOM_OUT_MASK) : (legacy_result ^ CUSTOM_IN_MASK)) :
                  legacy_result;

  assign legacy_init = (cmd_reg == CMD_INIT);
  assign legacy_next = (cmd_reg == CMD_NEXT);

  assign ready = (state_reg == STATE_IDLE) && legacy_ready;
  assign result = result_reg;
  assign result_valid = valid_reg;

  aes_core legacy_core(
                       .clk(clk),
                       .reset_n(reset_n),

                       .encdec(encdec_reg),
                       .init(legacy_init),
                       .next(legacy_next),
                       .ready(legacy_ready),

                       .key(key_reg),
                       .keylen(keylen_reg),

                       .block(block_reg),
                       .result(legacy_result),
                       .result_valid(legacy_valid)
                      );

  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      cmd_reg    <= CMD_IDLE;
      encdec_reg <= 1'b0;
      keylen_reg <= 1'b0;
      key_reg    <= 256'h0;
      block_reg  <= 128'h0;
      result_reg <= 128'h0;
      valid_reg  <= 1'b0;
      state_reg  <= STATE_IDLE;
    end else begin
      cmd_reg <= CMD_IDLE;

      case (state_reg)
        STATE_IDLE: begin
          if (legacy_ready && init) begin
            cmd_reg    <= CMD_INIT;
            encdec_reg <= encdec;
            keylen_reg <= keylen;
            key_reg    <= key;
            valid_reg  <= 1'b0;
            state_reg  <= STATE_PULSE;
          end else if (legacy_ready && next) begin
            cmd_reg    <= CMD_NEXT;
            encdec_reg <= encdec;
            keylen_reg <= keylen;
          block_reg  <= custom_input_block;
            valid_reg  <= 1'b0;
            state_reg  <= STATE_PULSE;
          end
        end

        STATE_PULSE: begin
          state_reg <= STATE_BUSY;
        end

        STATE_BUSY: begin
          if (legacy_ready) begin
            state_reg <= STATE_IDLE;

            if (legacy_valid) begin
              result_reg <= custom_output_block;
              valid_reg  <= 1'b1;
            end
          end
        end

        default: begin
          state_reg <= STATE_IDLE;
        end
      endcase
    end
  end
endmodule
