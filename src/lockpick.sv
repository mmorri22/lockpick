module lockpick_game (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic        input_enable,
  input  logic [7:0]  input_data,

  output logic        output_valid,
  output logic [7:0]  output_data,
  output logic [1:0]  status
);

  // FSM states
  typedef enum logic [2:0] {
    IDLE,
    INPUT_A,
    INPUT_B,
    HASH,
    COMPARE,
    OUTPUT
  } state_t;

  state_t state, next_state;

  logic [4:0] byte_count;
  logic [255:0] key_a, key_b, result_msg;
  logic [255:0] challenge_hash;
  logic [1:0]   attempts;
  logic         hash_match;

  logic [7:0] sbox_table [0:255];

  // Challenge target (constant internal 256-bit value)
  logic [255:0] challenge_target;
  assign challenge_target = 256'hCAFEBABE_12345678_DEADBEEF_FEEDFACE_C001D00D_BADC0DE5_BAADF00D_0BADBEEF;

  initial
    begin
      sbox_table = {
          8'h63, 8'h7c, 8'h77, 8'h7b, 8'hf2, 8'h6b, 8'h6f, 8'hc5,
          8'h30, 8'h01, 8'h67, 8'h2b, 8'hfe, 8'hd7, 8'hab, 8'h76,
          8'hca, 8'h82, 8'hc9, 8'h7d, 8'hfa, 8'h59, 8'h47, 8'hf0,
          8'had, 8'hd4, 8'ha2, 8'haf, 8'h9c, 8'ha4, 8'h72, 8'hc0,
          8'hb7, 8'hfd, 8'h93, 8'h26, 8'h36, 8'h3f, 8'hf7, 8'hcc,
          8'h34, 8'ha5, 8'he5, 8'hf1, 8'h71, 8'hd8, 8'h31, 8'h15,
          8'h04, 8'hc7, 8'h23, 8'hc3, 8'h18, 8'h96, 8'h05, 8'h9a,
          8'h07, 8'h12, 8'h80, 8'he2, 8'heb, 8'h27, 8'hb2, 8'h75,
          8'h09, 8'h83, 8'h2c, 8'h1a, 8'h1b, 8'h6e, 8'h5a, 8'ha0,
          8'h52, 8'h3b, 8'hd6, 8'hb3, 8'h29, 8'he3, 8'h2f, 8'h84,
          8'h53, 8'hd1, 8'h00, 8'hed, 8'h20, 8'hfc, 8'hb1, 8'h5b,
          8'h6a, 8'hcb, 8'hbe, 8'h39, 8'h4a, 8'h4c, 8'h58, 8'hcf,
          8'hd0, 8'hef, 8'haa, 8'hfb, 8'h43, 8'h4d, 8'h33, 8'h85,
          8'h45, 8'hf9, 8'h02, 8'h7f, 8'h50, 8'h3c, 8'h9f, 8'ha8,
          8'h51, 8'ha3, 8'h40, 8'h8f, 8'h92, 8'h9d, 8'h38, 8'hf5,
          8'hbc, 8'hb6, 8'hda, 8'h21, 8'h10, 8'hff, 8'hf3, 8'hd2,
          8'hcd, 8'h0c, 8'h13, 8'hec, 8'h5f, 8'h97, 8'h44, 8'h17,
          8'hc4, 8'ha7, 8'h7e, 8'h3d, 8'h64, 8'h5d, 8'h19, 8'h73,
          8'h60, 8'h81, 8'h4f, 8'hdc, 8'h22, 8'h2a, 8'h90, 8'h88,
          8'h46, 8'hee, 8'hb8, 8'h14, 8'hde, 8'h5e, 8'h0b, 8'hdb,
          8'he0, 8'h32, 8'h3a, 8'h0a, 8'h49, 8'h06, 8'h24, 8'h5c,
          8'hc2, 8'hd3, 8'hac, 8'h62, 8'h91, 8'h95, 8'he4, 8'h79,
          8'he7, 8'hc8, 8'h37, 8'h6d, 8'h8d, 8'hd5, 8'h4e, 8'ha9,
          8'h6c, 8'h56, 8'hf4, 8'hea, 8'h65, 8'h7a, 8'hae, 8'h08,
          8'hba, 8'h78, 8'h25, 8'h2e, 8'h1c, 8'ha6, 8'hb4, 8'hc6,
          8'he8, 8'hdd, 8'h74, 8'h1f, 8'h4b, 8'hbd, 8'h8b, 8'h8a,
          8'h70, 8'h3e, 8'hb5, 8'h66, 8'h48, 8'h03, 8'hf6, 8'h0e,
          8'h61, 8'h35, 8'h57, 8'hb9, 8'h86, 8'hc1, 8'h1d, 8'h9e,
          8'he1, 8'hf8, 8'h98, 8'h11, 8'h69, 8'hd9, 8'h8e, 8'h94,
          8'h9b, 8'h1e, 8'h87, 8'he9, 8'hce, 8'h55, 8'h28, 8'hdf,
          8'h8c, 8'ha1, 8'h89, 8'h0d, 8'hbf, 8'he6, 8'h42, 8'h68,
          8'h41, 8'h99, 8'h2d, 8'h0f, 8'hb0, 8'h54, 8'hbb, 8'h16
        };
     end
  

  // FSM transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // FSM next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:
        if (start) next_state = INPUT_A;

      INPUT_A:
        if (input_enable && byte_count == 5'd31) next_state = INPUT_B;

      INPUT_B:
        if (input_enable && byte_count == 5'd31) next_state = HASH;

      HASH:
        next_state = COMPARE;

      COMPARE:
        next_state = OUTPUT;

      OUTPUT:
        if (byte_count == 5'd31) begin
          if (hash_match || attempts == 2'd2)
            next_state = IDLE;
          else
            next_state = INPUT_A;
        end
    endcase
  end

  // Byte counter
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      byte_count <= 5'd0;
    else if ((state == INPUT_A || state == INPUT_B) && input_enable)
      byte_count <= byte_count + 1;
    else if (state == OUTPUT)
      byte_count <= byte_count + 1;
    else if (state == IDLE || state == HASH || state == COMPARE)
      byte_count <= 5'd0;
  end

  // Input loading
  always_ff @(posedge clk) begin
    if (state == INPUT_A && input_enable)
      key_a[byte_count*8 +: 8] <= input_data;
    if (state == INPUT_B && input_enable)
      key_b[byte_count*8 +: 8] <= input_data;
  end
  
  
  function automatic [63:0] permute(input [63:0] x);
    // Rotate each byte and then rotate whole word left by 13
    logic [7:0] b[0:7];
    for (int i = 0; i < 8; i++) begin
      b[i] = x[i*8 +: 8];
      b[i] = {b[i][6:0], b[i][7]};  // Rotate left 1
    end
    x = {b[7], b[6], b[5], b[4], b[3], b[2], b[1], b[0]};
    permute = {x[50:0], x[63:51]};  // Rotate 64-bit word left by 13
  endfunction

  function automatic [255:0] feistel_hash(input [255:0] in);
    logic [63:0] A, B, C, D;
    A = in[255:192];
    B = in[191:128];
    C = in[127:64];
    D = in[63:0];

    for (int round = 0; round < 3; round++) begin
      logic [63:0] F;
      F = ((B ^ D) + (A | C)) ^ {C[31:0], D[31:0]};
      F = permute(F);

      // Apply S-box to each byte of F
      for (int j = 0; j < 8; j++) begin
        F[j*8 +: 8] = sbox_table[F[j*8 +: 8]];
      end

      A ^= F;
      B = {B[30:0], B[63:31]};  // Left rotate 33
      C += A;
      D = ~D ^ B;
      A = {A[15:0], A[63:16]};  // Left rotate 16

     end

    feistel_hash = {A, B, C, D};
  endfunction
 
  // Hash and compare
  always_ff @(posedge clk) begin
    if (state == HASH)
      challenge_hash <= feistel_hash(key_a ^ key_b);
    if (state == COMPARE)
      hash_match <= (challenge_hash == challenge_target);
  end

  // Track attempts
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      attempts <= 2'd0;
    else if (state == COMPARE && !hash_match && attempts < 2)
      attempts <= attempts + 1;
    else if (state == IDLE)
      attempts <= 2'd0;
  end

  // Status output
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      status <= 2'b00;
    else if (state == COMPARE) begin
      if (hash_match)
        status <= 2'b10; // win
      else if (attempts == 2'd2)
        status <= 2'b11; // locked out
      else
        status <= 2'b01; // error
    end else if (state == IDLE) begin
      status <= 2'b00;
    end
  end

  // Result message
  always_ff @(posedge clk) begin
    if (state == COMPARE) begin
      result_msg <= hash_match
                    ? {8{32'hFACEFACE}}
                    : (attempts == 2'd2
                        ? {8{32'hDEADDEAD}} // locked out
                        : {8{32'hBAD0BAD0}}); // error
    end
  end

  // Output logic
  always_ff @(posedge clk) begin
    if (state == OUTPUT) begin
      output_data <= result_msg[byte_count*8 +: 8];
      output_valid <= 1;
    end else begin
      output_data <= 8'd0;
      output_valid <= 0;
    end
  end

endmodule


module tt_um_mmorri22_lockpick_game (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  lockpick_game design_example(
    .clk(clk),
    .rst_n(rst_n),
    .start(uio_in[0]),
    .input_enable(uio_in[1]),
    .input_data(ui_in),
    .output_valid(uio_out[2]),
    .output_data(uo_out),
    .status(uio_out[4:3])
  );

  // Assign enable paths 
  assign uio_oe[0] = 1'b0;
  assign uio_oe[1] = 1'b0;
  assign uio_oe[2] = 1'b1;
  assign uio_oe[3] = 1'b1;
  assign uio_oe[4] = 1'b1;
  assign uio_oe[5] = 1'b1;

 
  // avoid linter warning about unused pins:
  wire _unused_pins = ena;   
  assign uio_out[7] = _unused_pins;
  assign uio_out[6] = _unused_pins;
  assign uio_out[5] = _unused_pins;
  assign uio_out[1] = _unused_pins;
  assign uio_out[0] = _unused_pins;  
  
endmodule
