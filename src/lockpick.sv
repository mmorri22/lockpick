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
  logic [127:0] key_a, key_b, result_msg;
  logic [127:0] challenge_hash;
  logic [1:0]   attempts;
  logic         hash_match;

  logic [7:0] sbox_table [0:127];

  // Challenge target (constant internal 256-bit value)
  logic [127:0] challenge_target;

  initial
    begin
      sbox_table[0] = 8'h63;
      sbox_table[1] = 8'h7c;
      sbox_table[2] = 8'h77;
      sbox_table[3]  = 8'h7b;
      sbox_table[4]  = 8'hf2;
      sbox_table[5]  = 8'h6b;
      sbox_table[6]  = 8'h6f;
      sbox_table[7]  = 8'hc5;
      sbox_table[8]  = 8'h30;
      sbox_table[9]  = 8'h01;
      sbox_table[10] = 8'h67;
      sbox_table[11] = 8'h2b;
      sbox_table[12] = 8'hfe;
      sbox_table[13] = 8'hd7;
      sbox_table[14] = 8'hab;
      sbox_table[15] = 8'h76;
      sbox_table[16] = 8'hca;
      sbox_table[17] = 8'h82;
      sbox_table[18] = 8'hc9;
      sbox_table[19] = 8'h7d;
      sbox_table[20] = 8'hfa;
      sbox_table[21] = 8'h59;
      sbox_table[22] = 8'h47;
      sbox_table[23] = 8'hf0;
      sbox_table[24] = 8'had;
      sbox_table[25] = 8'hd4;
      sbox_table[26] = 8'ha2;
      sbox_table[27] = 8'haf;
      sbox_table[28] = 8'h9c;
      sbox_table[29] = 8'ha4;
      sbox_table[30] = 8'h72;
      sbox_table[31] = 8'hc0;
      sbox_table[32] = 8'hb7;
      sbox_table[33] = 8'hfd;
      sbox_table[34] = 8'h93;
      sbox_table[35] = 8'h26;
      sbox_table[36] = 8'h36;
      sbox_table[37] = 8'h3f;
      sbox_table[38] = 8'hf7;
      sbox_table[39] = 8'hcc;
      sbox_table[40] = 8'h34;
      sbox_table[41] = 8'ha5;
      sbox_table[42] = 8'he5;
      sbox_table[43] = 8'hf1;
      sbox_table[44] = 8'h71;
      sbox_table[45] = 8'hd8;
      sbox_table[46] = 8'h31;
      sbox_table[47] = 8'h15;
      sbox_table[48] = 8'h04;
      sbox_table[49] = 8'hc7;
      sbox_table[50] = 8'h23;
      sbox_table[51] = 8'hc3;
      sbox_table[52] = 8'h18;
      sbox_table[53] = 8'h96;
      sbox_table[54] = 8'h05;
      sbox_table[55] = 8'h9a;
      sbox_table[56] = 8'h07;
      sbox_table[57] = 8'h12;
      sbox_table[58] = 8'h80;
      sbox_table[59] = 8'he2;
      sbox_table[60] = 8'heb;
      sbox_table[61] = 8'h27;
      sbox_table[62] = 8'hb2;
      sbox_table[63] = 8'h75;
      sbox_table[64] = 8'h09;
      sbox_table[65] = 8'h83;
      sbox_table[66] = 8'h2c;
      sbox_table[67] = 8'h1a;
      sbox_table[68] = 8'h1b;
      sbox_table[69] = 8'h6e;
      sbox_table[70] = 8'h5a;
      sbox_table[71] = 8'ha0;
      sbox_table[72] = 8'h52;
      sbox_table[73] = 8'h3b;
      sbox_table[74] = 8'hd6;
      sbox_table[75] = 8'hb3;
      sbox_table[76] = 8'h29;
      sbox_table[77] = 8'he3;
      sbox_table[78] = 8'h2f;
      sbox_table[79] = 8'h84;
      sbox_table[80] = 8'h53;
      sbox_table[81] = 8'hd1;
      sbox_table[82] = 8'h00;
      sbox_table[83] = 8'hed;
      sbox_table[84] = 8'h20;
      sbox_table[85] = 8'hfc;
      sbox_table[86] = 8'hb1;
      sbox_table[87] = 8'h5b;
      sbox_table[88] = 8'h6a;
      sbox_table[89] = 8'hcb;
      sbox_table[90] = 8'hbe;
      sbox_table[91] = 8'h39;
      sbox_table[92] = 8'h4a;
      sbox_table[93] = 8'h4c;
      sbox_table[94] = 8'h58;
      sbox_table[95] = 8'hcf;
      sbox_table[96] = 8'hd0;
      sbox_table[97] = 8'hef;
      sbox_table[98] = 8'haa;
      sbox_table[99] = 8'hfb;
      sbox_table[100] = 8'h43;
      sbox_table[101] = 8'h4d;
      sbox_table[102] = 8'h33;
      sbox_table[103] = 8'h85;
      sbox_table[104] = 8'h45;
      sbox_table[105] = 8'hf9;
      sbox_table[106] = 8'h02;
      sbox_table[107] = 8'h7f;
      sbox_table[108] = 8'h50;
      sbox_table[109] = 8'h3c;
      sbox_table[110] = 8'h9f;
      sbox_table[111] = 8'ha8;
      sbox_table[112] = 8'h51;
      sbox_table[113] = 8'ha3;
      sbox_table[114] = 8'h40;
      sbox_table[115] = 8'h8f;
      sbox_table[116] = 8'h92;
      sbox_table[117] = 8'h9d;
      sbox_table[118] = 8'h38;
      sbox_table[119] = 8'hf5;
      sbox_table[120] = 8'hbc;
      sbox_table[121] = 8'hb6;
      sbox_table[122] = 8'hda;
      sbox_table[123] = 8'h21;
      sbox_table[124] = 8'h10;
      sbox_table[125] = 8'hff;
      sbox_table[126] = 8'hf3;
      sbox_table[127] = 8'hd2;

      challenge_target = 128'hCAFEBABE_12345678_DEADBEEF_FEEDFACE;
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
        if (input_enable && byte_count == 5'd15) next_state = INPUT_B;

      INPUT_B:
        if (input_enable && byte_count == 5'd15) next_state = HASH;

      HASH:
        if (hash_done)
          next_state = COMPARE;
        else
          next_state = HASH;


      COMPARE:
        next_state = OUTPUT;

      OUTPUT:
        if (byte_count == 5'd15) begin
          if (hash_match || attempts == 2'd2)
            next_state = IDLE;
          else
            next_state = INPUT_A;
        end

      default next_state = IDLE;
      
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
  
  
  function automatic [31:0] permute(input [31:0] x);
    // Rotate each byte and then rotate whole word left by 13
    logic [7:0] b[0:7];
    for (int i = 0; i < 4; i++) begin
      b[i] = x[i*8 +: 8];
      b[i] = {b[i][6:0], b[i][7]};  // Rotate left 1
    end
    x = {b[3], b[2], b[1], b[0]};
    permute = {x[28:0], x[31:29]};  // Rotate 32-bit word left by 13
  endfunction

  function automatic [127:0] feistel_hash(input [127:0] in);
    logic [31:0] A, B, C, D;
    A = in[127:96];
    B = in[95:64];
    C = in[63:32];
    D = in[31:0];

    for (int round = 0; round < 3; round++) begin
      logic [31:0] F;
      F = ((B ^ D) + (A | C)) ^ {C[15:0], D[15:0]};
      F = permute(F);

      // Apply S-box to each byte of F
      for (int j = 0; j < 4; j++) begin
        F[j*8 +: 8] = sbox_table[F[j*8 +: 7]];
      end

      A ^= F;
      B = {B[14:0], B[31:15]};  // Left rotate 16
      C += A;
      D = ~D ^ B;
      A = {A[23:0], A[31:24]};  // Left rotate 8

     end

    feistel_hash = {A, B, C, D};
  endfunction
 
  // Hash and compare
  //---------------------------------------------------------
  // Multi-cycle HASH + COMPARE block (full replacement)
  //---------------------------------------------------------
  logic [31:0] A_reg, B_reg, C_reg, D_reg;
  logic [1:0]  round;
  logic        hash_busy, hash_done;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // HASH engine reset
      hash_busy <= 1'b0;
      hash_done <= 1'b0;
      round     <= 2'd0;
  
      // COMPARE reset
      hash_match <= 1'b0;
    end 
      
    else begin
      //-----------------------------------------------------
      // Kick off Feistel hash when entering HASH state
      //-----------------------------------------------------
      if (state == HASH && !hash_busy) begin
        {A_reg, B_reg, C_reg, D_reg} <= key_a ^ key_b;
        round     <= 2'd0;
        hash_busy <= 1'b1;
        hash_done <= 1'b0;
      end
  
      //-----------------------------------------------------
      // Perform ONE Feistel round per cycle
      //-----------------------------------------------------
      else if (state == HASH && hash_busy) begin
        logic [31:0] F;
  
        // Round function
        F = ((B_reg ^ D_reg) + (A_reg | C_reg)) ^ {C_reg[15:0], D_reg[15:0]};
        F = permute(F);
  
        // S-box substitution
        for (int j = 0; j < 4; j++)
          F[j*8 +: 8] = sbox_table[F[j*8 +: 7]];
  
        // Feistel mixing (note: A_reg updated twice — may split if needed)
        A_reg <= (A_reg ^ F);
        B_reg <= {B_reg[14:0], B_reg[31:15]};
        C_reg <= C_reg + A_reg;
        D_reg <= ~D_reg ^ B_reg;
        A_reg <= {A_reg[23:0], A_reg[31:24]};
  
        // End of final round?
        if (round == 2) begin
          challenge_hash <= {A_reg, B_reg, C_reg, D_reg};
          hash_busy <= 1'b0;
          hash_done <= 1'b1;
        end 
        else begin
          round <= round + 1;
        end
      end
  
      //-----------------------------------------------------
      // COMPARE state (unchanged from your original code)
      //-----------------------------------------------------
      if (state == COMPARE)
        hash_match <= (challenge_hash == challenge_target);
  
      //-----------------------------------------------------
      // Default cleanup: stop asserting hash_done
      //-----------------------------------------------------
      if (state != HASH)
        hash_done <= 1'b0;
    end
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
      ? {8{16'hFACE}}
                    : (attempts == 2'd2
                       ? {8{16'hDEAD}} // locked out
                       : {8{16'hBAD0}}); // error
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


  // avoid linter warning about unused pins:
  wire _unused_pins = ena;   
  
  // Assign enable paths 
  assign uio_oe[0] = 1'b0;
  assign uio_oe[1] = 1'b0;
  assign uio_oe[2] = 1'b1;
  assign uio_oe[3] = 1'b1;
  assign uio_oe[4] = 1'b1;
  assign uio_oe[5] = 1'b1;
  assign uio_oe[6] = _unused_pins;
  assign uio_oe[7] = _unused_pins;  

  // Set AND with the unused input signals
  // Reference - https://verilator.org/guide/latest/warnings.html#cmdoption-arg-UNUSEDSIGNAL
  wire _unused_ok_2 = 1'b0 & uio_in[2];
  wire _unused_ok_3 = 1'b0 & uio_in[3];
  wire _unused_ok_4 = 1'b0 & uio_in[4];
  wire _unused_ok_5 = 1'b0 & uio_in[5];
  wire _unused_ok_6 = 1'b0 & uio_in[6];
  wire _unused_ok_7 = 1'b0 & uio_in[7];
  
  // Assign usused pin to the unused uio_out  
  assign uio_out[0] = _unused_pins;
  assign uio_out[1] = _unused_pins;
  assign uio_out[5] = _unused_pins;
  assign uio_out[6] = _unused_pins;
  assign uio_out[7] = _unused_pins;  
  
endmodule
