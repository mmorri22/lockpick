module tb_lockpick_game;

  // DUT Interface
  logic clk, rst;
  logic start;
  logic input_enable;
  logic [7:0] input_data;
  logic output_valid;
  logic [7:0] output_data;

  // Instantiate DUT
  tt_um_mmorri22_lockpick_game dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .input_enable(input_enable),
    .input_data(input_data),
    .output_valid(output_valid),
    .output_data(output_data)
  );

  // Clock generation (10 ns period)
  initial clk = 0;
  always #50 clk = ~clk;

  // Internal variables
  logic [255:0] key_a;
  logic [255:0] key_b;
  logic [255:0] xor_expected;
  logic [255:0] received_result;
  logic [255:0] secret_lock = 256'hCAFEBABE_12345678_DEADBEEF_FEEDFACE_C001D00D_BADC0DE5_BAADF00D_0BADBEEF;
  logic [255:0] match_pattern = {8{32'hFACEFACE}};
  logic [255:0] fail_pattern  = {8{32'hBAD0BAD0}};
  int output_byte_index;

  // Task: send 256-bit value over 32 input cycles
  task automatic send_256bit(input logic [255:0] value);
    for (int i = 0; i < 32; i++) begin
      logic [7:0] current_byte = value[i*8 +: 8];
      input_data <= current_byte;
      input_enable <= 1;
      @(posedge clk);
      $display("Sending byte %0d: 0x%02h, 0x%h, 0x%h", i, input_data, current_byte, value);
    end
    input_enable <= 0;	
    @(posedge clk);
  endtask

  // Capture 256-bit output over 32 cycles
  task automatic capture_256bit();
    received_result = 256'd0;
    output_byte_index = 0;

    wait (output_valid);
    repeat (32) begin
      @(posedge clk);
      if (output_valid) begin
        received_result[output_byte_index*8 +: 8] = output_data;
        $display("Received byte %0d: 0x%02h", output_byte_index, output_data);
        output_byte_index++;
      end
    end
  endtask

  // Check result
  task automatic check_result(input string test_name);
    logic [255:0] xor_expected;
    logic is_match;
    logic [255:0] expected_result;

    xor_expected = key_a ^ key_b;
    is_match = (xor_expected == secret_lock);
    expected_result = is_match ? match_pattern : fail_pattern;

    if (received_result !== expected_result) begin
      $display("%s FAILED", test_name);
      $display("Expected: %h", expected_result);
      $display("Received: %h", received_result);
    end else begin
      $display("%s PASSED", test_name);
    end
  endtask

  // Main stimulus
  initial begin
    $display("Starting 256-bit LOCKPICK testbench...");

    // ========= Test Case 1: Should Pass =========
    key_a = 256'hCAFEBABE_12345678_DEADBEEF_FEEDFACE_C001D00D_BADC0DE5_BAADF00D_0BADBEEF;
    key_b = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000; // XOR = secret_lock

    // Reset and start
    input_data = 8'd0;
    input_enable = 0;
    start = 0;
    rst = 0;
    @(posedge clk);
    rst = 1;
    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;

    send_256bit(key_a);
    send_256bit(key_b);
    capture_256bit();
    check_result("Test 1 (Match)");

    // ========= Test Case 2: Should Fail =========
    @(posedge clk);
    key_a = 256'hACEFABEB_FFFFFFFF_00000000_12345678_AAAAAAAA_BADC0DE5_0BADBEEF_11223344;
    key_b = 256'h11111111_22222222_33333333_44444444_55555555_66666666_77777777_88888888;

    rst = 0;
    @(posedge clk);
    rst = 1;
    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;

    send_256bit(key_a);
    send_256bit(key_b);
    capture_256bit();
    check_result("Test 2 (Mismatch)");

    $display("All tests completed.");
    $finish;
  end

endmodule
