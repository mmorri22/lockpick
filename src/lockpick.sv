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
      sbox_table[128] = 8'hcd;
      sbox_table[129] = 8'h0c;
      sbox_table[130] = 8'h13;
      sbox_table[131] = 8'hec;
      sbox_table[132] = 8'h5f;
      sbox_table[133] = 8'h97;
      sbox_table[134] = 8'h44;
      sbox_table[135] = 8'h17;
      sbox_table[136] = 8'hc4;
      sbox_table[137] = 8'ha7;
      sbox_table[138] = 8'h7e;
      sbox_table[139] = 8'h3d;
      sbox_table[140] = 8'h64;
      sbox_table[141] = 8'h5d;
      sbox_table[142] = 8'h19;
      sbox_table[143] = 8'h73;
      sbox_table[144] = 8'h60;
      sbox_table[145] = 8'h81;
      sbox_table[146] = 8'h4f;
      sbox_table[147] = 8'hdc;
      sbox_table[148] = 8'h22;
      sbox_table[149] = 8'h2a;
      sbox_table[150] = 8'h90;
      sbox_table[151] = 8'h88;
      sbox_table[152] = 8'h46;
      sbox_table[153] = 8'hee;
      sbox_table[154] = 8'hb8;
      sbox_table[155] = 8'h14;
      sbox_table[156] = 8'hde;
      sbox_table[157] = 8'h5e;
      sbox_table[158] = 8'h0b;
      sbox_table[159] = 8'hdb;
      sbox_table[160] = 8'he0;
      sbox_table[161] = 8'h32;
      sbox_table[162] = 8'h3a;
      sbox_table[163] = 8'h0a;
      sbox_table[164] = 8'h49;
      sbox_table[165] = 8'h06;
      sbox_table[166] = 8'h24;
      sbox_table[167] = 8'h5c;
      sbox_table[168] = 8'hc2;
      sbox_table[169] = 8'hd3;
      sbox_table[170] = 8'hac;
      sbox_table[171] = 8'h62;
      sbox_table[172] = 8'h91;
      sbox_table[173] = 8'h95;
      sbox_table[174] = 8'he4;
      sbox_table[175] = 8'h79;
      sbox_table[176] = 8'he7;
      sbox_table[177] = 8'hc8;
      sbox_table[178] = 8'h37;
      sbox_table[179] = 8'h6d;
      sbox_table[180] = 8'h8d;
      sbox_table[181] = 8'hd5;
      sbox_table[182] = 8'h4e;
      sbox_table[183] = 8'ha9;
      sbox_table[184] = 8'h6c;
      sbox_table[185] = 8'h56;
      sbox_table[186] = 8'hf4;
      sbox_table[187] = 8'hea;
      sbox_table[188] = 8'h65;
      sbox_table[189] = 8'h7a;
      sbox_table[190] = 8'hae;
      sbox_table[191] = 8'h08;
      sbox_table[192] = 8'hba;
      sbox_table[193] = 8'h78;
      sbox_table[194] = 8'h25;
      sbox_table[195] = 8'h2e;
      sbox_table[196] = 8'h1c;
      sbox_table[197] = 8'ha6;
      sbox_table[198] = 8'hb4;
      sbox_table[199] = 8'hc6;
      sbox_table[200] = 8'he8;
      sbox_table[201] = 8'hdd;
      sbox_table[202] = 8'h74;
      sbox_table[203] = 8'h1f;
      sbox_table[204] = 8'h4b;
      sbox_table[205] = 8'hbd;
      sbox_table[206] = 8'h8b;
      sbox_table[207] = 8'h8a;
      sbox_table[208] = 8'h70;
      sbox_table[209] = 8'h3e;
      sbox_table[210] = 8'hb5;
      sbox_table[211] = 8'h66;
      sbox_table[212] = 8'h48;
      sbox_table[213] = 8'h03;
      sbox_table[214] = 8'hf6;
      sbox_table[215] = 8'h0e;
      sbox_table[216] = 8'h61;
      sbox_table[217] = 8'h35;
      sbox_table[218] = 8'h57;
      sbox_table[219] = 8'hb9;
      sbox_table[220] = 8'h86;
      sbox_table[221] = 8'hc1;
      sbox_table[222] = 8'h1d;
      sbox_table[223] = 8'h9e;
      sbox_table[224] = 8'he1;
      sbox_table[225] = 8'hf8;
      sbox_table[226] = 8'h98;
      sbox_table[227] = 8'h11;
      sbox_table[228] = 8'h69;
      sbox_table[229] = 8'hd9;
      sbox_table[230] = 8'h8e;
      sbox_table[231] = 8'h94;
      sbox_table[232] = 8'h9b;
      sbox_table[233] = 8'h1e;
      sbox_table[234] = 8'h87;
      sbox_table[235] = 8'he9;
      sbox_table[236] = 8'hce;
      sbox_table[237] = 8'h55;
      sbox_table[238] = 8'h28;
      sbox_table[239] = 8'hdf;
      sbox_table[240] = 8'h8c;
      sbox_table[241] = 8'ha1;
      sbox_table[242] = 8'h89;
      sbox_table[243] = 8'h0d;
      sbox_table[244] = 8'hbf;
      sbox_table[245] = 8'he6;
      sbox_table[246] = 8'h42;
      sbox_table[247] = 8'h68;
      sbox_table[248] = 8'h41;
      sbox_table[249] = 8'h99;
      sbox_table[250] = 8'h2d;
      sbox_table[251] = 8'h0f;
      sbox_table[252] = 8'hb0;
      sbox_table[253] = 8'h54;
      sbox_table[254] = 8'hbb;
      sbox_table[255] = 8'h16;
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
