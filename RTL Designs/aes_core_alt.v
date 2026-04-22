module aes_core_alt #(
                    parameter CUSTOM_MODE = 1'b0,
                    parameter [127 : 0] CUSTOM_IN_MASK  = 128'h13579BDF2468ACE013579BDF2468ACE0,
                    parameter [127 : 0] CUSTOM_OUT_MASK = 128'h0F1E2D3C4B5A69788796A5B4C3D2E1F0,
                    parameter [255 : 0] CUSTOM_KEY_MASK = 256'hA55AA55A3CC33CC35AA55AA53CC33CC300000000000000000000000000000000,
                    parameter [3 : 0]   CUSTOM_ROT_BYTES = 4'd3
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
  // Custom mode keeps the standard iterative AES core intact and adds
  // a private reversible transform around it:
  //   - input whitening mask
  //   - secret byte permutation
  //   - key whitening mask
  //   - output whitening + byte rotation
  //
  // This makes external ciphertext differ from standard AES while
  // keeping the hardware integration stable.
  //----------------------------------------------------------------
  localparam CMD_IDLE    = 2'h0;
  localparam CMD_INIT    = 2'h1;
  localparam CMD_NEXT    = 2'h2;

  localparam STATE_IDLE  = 2'h0;
  localparam STATE_PULSE = 2'h1;
  localparam STATE_BUSY  = 2'h2;

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

  wire [255:0] custom_key_bus;
  wire [127:0] custom_input_block;
  wire [127:0] custom_output_block;

  //----------------------------------------------------------------
  // Helper functions.
  //----------------------------------------------------------------
  function [127:0] perm_fwd;
    input [127:0] x;
    begin
      perm_fwd = {
                  x[71  :64 ],  // b7
                  x[111 :104],  // b2
                  x[23  :16 ],  // b13
                  x[95  :88 ],  // b4
                  x[39  :32 ],  // b11
                  x[127 :120],  // b0
                  x[7   :0  ],  // b15
                  x[55  :48 ],  // b9
                  x[119 :112],  // b1
                  x[15  :8  ],  // b14
                  x[79  :72 ],  // b6
                  x[47  :40 ],  // b10
                  x[103 :96 ],  // b3
                  x[31  :24 ],  // b12
                  x[87  :80 ],  // b5
                  x[63  :56 ]   // b8
                 };
    end
  endfunction

  function [127:0] perm_inv;
    input [127:0] x;
    begin
      perm_inv = {
                  x[87  :80 ],  // original b0  = y5
                  x[63  :56 ],  // original b1  = y8
                  x[119 :112],  // original b2  = y1
                  x[31  :24 ],  // original b3  = y12
                  x[103 :96 ],  // original b4  = y3
                  x[15  :8  ],  // original b5  = y14
                  x[47  :40 ],  // original b6  = y10
                  x[127 :120],  // original b7  = y0
                  x[7   :0  ],  // original b8  = y15
                  x[71  :64 ],  // original b9  = y7
                  x[39  :32 ],  // original b10 = y11
                  x[95  :88 ],  // original b11 = y4
                  x[23  :16 ],  // original b12 = y13
                  x[111 :104],  // original b13 = y2
                  x[55  :48 ],  // original b14 = y9
                  x[79  :72 ]   // original b15 = y6
                 };
    end
  endfunction

  function [127:0] rotl_bytes;
    input [127:0] x;
    input [3:0] sh;
    begin
      case (sh)
        4'd0  : rotl_bytes = x;
        4'd1  : rotl_bytes = {x[119:0],  x[127:120]};
        4'd2  : rotl_bytes = {x[111:0],  x[127:112]};
        4'd3  : rotl_bytes = {x[103:0],  x[127:104]};
        4'd4  : rotl_bytes = {x[95:0],   x[127:96]};
        4'd5  : rotl_bytes = {x[87:0],   x[127:88]};
        4'd6  : rotl_bytes = {x[79:0],   x[127:80]};
        4'd7  : rotl_bytes = {x[71:0],   x[127:72]};
        4'd8  : rotl_bytes = {x[63:0],   x[127:64]};
        4'd9  : rotl_bytes = {x[55:0],   x[127:56]};
        4'd10 : rotl_bytes = {x[47:0],   x[127:48]};
        4'd11 : rotl_bytes = {x[39:0],   x[127:40]};
        4'd12 : rotl_bytes = {x[31:0],   x[127:32]};
        4'd13 : rotl_bytes = {x[23:0],   x[127:24]};
        4'd14 : rotl_bytes = {x[15:0],   x[127:16]};
        default: rotl_bytes = {x[7:0],   x[127:8]};
      endcase
    end
  endfunction

  function [127:0] rotr_bytes;
    input [127:0] x;
    input [3:0] sh;
    begin
      case (sh)
        4'd0  : rotr_bytes = x;
        4'd1  : rotr_bytes = {x[7:0],    x[127:8]};
        4'd2  : rotr_bytes = {x[15:0],   x[127:16]};
        4'd3  : rotr_bytes = {x[23:0],   x[127:24]};
        4'd4  : rotr_bytes = {x[31:0],   x[127:32]};
        4'd5  : rotr_bytes = {x[39:0],   x[127:40]};
        4'd6  : rotr_bytes = {x[47:0],   x[127:48]};
        4'd7  : rotr_bytes = {x[55:0],   x[127:56]};
        4'd8  : rotr_bytes = {x[63:0],   x[127:64]};
        4'd9  : rotr_bytes = {x[71:0],   x[127:72]};
        4'd10 : rotr_bytes = {x[79:0],   x[127:80]};
        4'd11 : rotr_bytes = {x[87:0],   x[127:88]};
        4'd12 : rotr_bytes = {x[95:0],   x[127:96]};
        4'd13 : rotr_bytes = {x[103:0],  x[127:104]};
        4'd14 : rotr_bytes = {x[111:0],  x[127:112]};
        default: rotr_bytes = {x[119:0], x[127:120]};
      endcase
    end
  endfunction

  //----------------------------------------------------------------
  // Custom transform mapping.
  // Encryption path:
  //   custom_in  = perm_fwd(block ^ IN_MASK)
  //   core_key   = key ^ KEY_MASK
  //   custom_out = rotl_bytes(perm_inv(AES_out ^ OUT_MASK), ROT)
  //
  // Decryption path performs the exact inverse sequence.
  //----------------------------------------------------------------
  assign custom_key_bus = CUSTOM_MODE ? (key ^ CUSTOM_KEY_MASK) : key;

  assign custom_input_block =
    (!CUSTOM_MODE) ? block :
    (encdec ? perm_fwd(block ^ CUSTOM_IN_MASK) :
              (perm_fwd(rotr_bytes(block, CUSTOM_ROT_BYTES)) ^ CUSTOM_OUT_MASK));

  assign custom_output_block =
    (!CUSTOM_MODE) ? legacy_result :
    (encdec_reg ? rotl_bytes(perm_inv(legacy_result ^ CUSTOM_OUT_MASK), CUSTOM_ROT_BYTES) :
                  (perm_inv(legacy_result) ^ CUSTOM_IN_MASK));

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
            key_reg    <= custom_key_bus;
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
