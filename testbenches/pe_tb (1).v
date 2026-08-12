`timescale 1ns/1ps

//=====================================================================
// SECTION - 1
// TESTBENCH
// Processing Element Verification
//=====================================================================

module tb_processing_element;

//=====================================================================
// SECTION - 2
// PARAMETERS AND CLOCK RESET
//=====================================================================

localparam NUM_ROWS   = 4;
localparam NUM_COLS   = 4;
localparam DATA_WIDTH = 8;
localparam ACC_WIDTH = (2*DATA_WIDTH)+1;
//=====================================================================
// CLOCK / RESET
//=====================================================================

reg clk;
reg rst;

//=====================================================================
// SECTION - 3
// TESTBENCH VARIABLES
//=====================================================================

reg scoreboard_enable;
integer total_tests;
integer passed_tests;
integer failed_tests;
integer cycle;

//=====================================================================
// SECTION - 4
// DUT INPUTS
//=====================================================================
reg                               load_weight;
reg signed [DATA_WIDTH-1:0]       weight_in;
reg signed [DATA_WIDTH-1:0]       a_in;
reg signed [(2*DATA_WIDTH):0]     psum_in;
//=====================================================================
// SECTION - 5
// DUT OUTPUTS
//=====================================================================
wire signed [DATA_WIDTH-1:0]        a_out;
wire signed [(2*DATA_WIDTH):0]      psum_out;

//=====================================================================
// SECTION - 6
// DUT INSTANTIATION
//=====================================================================

processing_element_2d
#(
    .DATA_WIDTH(DATA_WIDTH)
)
dut
(
    .clk         (clk),
    .rst         (rst),

    .load_weight (load_weight),
    .weight_in   (weight_in),

    .a_in        (a_in),
    .a_out       (a_out),

    .psum_in     (psum_in),
    .psum_out    (psum_out)
); 

//=====================================================================
// SECTION - 7
// CLOCK GENERATION
//=====================================================================

initial
begin
    clk = 0;

    forever
        #5 clk = ~clk;
end
//=====================================================================

//=====================================================================
// SECTION - 8
// INITIALIZATION
//=====================================================================

initial
begin

    //----------------------------------------------------------
    // Clock / Reset
    //----------------------------------------------------------

    rst = 1;

    //----------------------------------------------------------
    // DUT Inputs
    //----------------------------------------------------------

    load_weight = 0;
    weight_in   = 0;

    a_in        = 0;
    psum_in     = 0;

    //----------------------------------------------------------
    // Generic Variables
    //----------------------------------------------------------

    scoreboard_enable = 0;

    total_tests  = 0;
    passed_tests = 0;
    failed_tests = 0;

    cycle = 0;

end
//=====================================================================
// SECTION - 9
// CYCLE COUNTER (Exact copy from matrix feeder)
//=====================================================================

always @(posedge clk)
begin

    if (rst)
        cycle <= 0;
    else
        cycle <= cycle + 1;

end

//=====================================================================
// SECTION - 10
// UTILITY TASKS
//=====================================================================
//=====================================================================
// RESET DUT (same from feeder)
//=====================================================================

task automatic reset_dut;

begin

    $display("");
    $display("============================================================");
    $display("Applying Reset...");
    $display("============================================================");

    rst = 1;

    load_weight = 0;
    weight_in   = 0;
    a_in        = 0;
    psum_in     = 0;

    repeat(5) @(posedge clk);

    rst = 0;

    @(posedge clk);

end

endtask
//=====================================================================
// PRINT BANNER (same from feeder)
//=====================================================================

task automatic print_banner;

input [256*8:1] title;

begin

    $display("");
    $display("============================================================");
    $display("%0s", title);
    $display("============================================================");

end

endtask
//=====================================================================
// PRINT STATUS
//=====================================================================

task automatic print_status;

begin

    $display("------------------------------------------------------------");
    $display("Time         : %t", $time);
    $display("Cycle        : %0d", cycle);
    $display("");

    $display("load_weight  : %0b", load_weight);

    $display("weight_in    : %0d", $signed(weight_in));

    $display("a_in         : %0d", $signed(a_in));
    $display("a_out        : %0d", $signed(a_out));

    $display("psum_in      : %0d", $signed(psum_in));
    $display("psum_out     : %0d", $signed(psum_out));

    $display("------------------------------------------------------------");

end

endtask
//=====================================================================
// PRINT SUMMARY (same from feeder)
//=====================================================================

task automatic print_summary;

begin

    $display("");
    $display("============================================================");
    $display("FINAL VERIFICATION SUMMARY");
    $display("============================================================");

    $display("Total Tests : %0d", total_tests);
    $display("Passed      : %0d", passed_tests);
    $display("Failed      : %0d", failed_tests);

    if(failed_tests == 0)
        $display("OVERALL RESULT : PASS");
    else
        $display("OVERALL RESULT : FAIL");

    $display("============================================================");

end

endtask
//=====================================================================
// SECTION - 11
// REFERENCE MODEL
//=====================================================================

//----------------------------------------------------------
// Reference Variables
//----------------------------------------------------------
reg signed [DATA_WIDTH-1:0]   expected_weight;
reg signed [DATA_WIDTH-1:0]   expected_a_out;
reg signed [ACC_WIDTH-1:0]    expected_psum_out;

// Internal reference pipeline registers

reg signed [DATA_WIDTH-1:0]   ref_weight;
reg signed [(2*DATA_WIDTH)-1:0] ref_product;
//----------------------------------------------------------
// Processing Element Reference Model
//----------------------------------------------------------

always @(posedge clk)
begin

    if(rst)
    begin

        ref_weight        <= 0;
        ref_product       <= 0;

        expected_weight   <= 0;
        expected_a_out    <= 0;
        expected_psum_out <= 0;

    end
    else
    begin

        //--------------------------------------------------
        // Weight Register
        //--------------------------------------------------

        if(load_weight)
            ref_weight <= weight_in;

        expected_weight <= load_weight ? weight_in : ref_weight;

        //--------------------------------------------------
        // Activation Forwarding
        //--------------------------------------------------

        expected_a_out <= a_in;

        //--------------------------------------------------
        // Multiply Stage
        //--------------------------------------------------

        ref_product <= a_in * ref_weight;

        //--------------------------------------------------
        // Accumulate Stage
        //--------------------------------------------------

        expected_psum_out <= psum_in + ref_product;

    end

end
//=====================================================================
// SECTION - 12
// SCOREBOARD
//=====================================================================

always @(posedge clk)
begin

    if(!rst && scoreboard_enable)
    begin

        $display("");
        $display("============================================================");
        $display("Cycle : %0d", cycle);
        $display("============================================================");

        //----------------------------------------------------------
        // Weight Register
        //----------------------------------------------------------

        $display("");
        $display("WEIGHT REGISTER");
        $display("--------------------------------------------");

        $display("Expected Weight : %4d",
                 $signed(expected_weight));

        $display("Actual Weight   : %4d",
                 $signed(dut.w_reg));

        //----------------------------------------------------------
        // Activation Forwarding
        //----------------------------------------------------------

        $display("");
        $display("ACTIVATION FORWARDING");
        $display("--------------------------------------------");

        $display("Expected a_out : %4d",
                 $signed(expected_a_out));

        $display("Actual a_out   : %4d",
                 $signed(a_out));

        //----------------------------------------------------------
        // Partial Sum
        //----------------------------------------------------------

        $display("");
        $display("PARTIAL SUM");
        $display("--------------------------------------------");

        $display("Expected psum_out : %6d",
                 $signed(expected_psum_out));

        $display("Actual psum_out   : %6d",
                 $signed(psum_out));

        //----------------------------------------------------------
        // PASS / FAIL
        //----------------------------------------------------------

        if((expected_weight   === dut.w_reg) &&
           (expected_a_out    === a_out) &&
           (expected_psum_out === psum_out))
        begin

            $display("");
            $display("STATUS : PASS");

        end
        else
        begin

            $display("");
            $display("STATUS : FAIL");

        end

    end

end

//=====================================================================
// SECTION - 13
// TEST CASES
//=====================================================================
//=====================================================================
// TC1 : RESET VERIFICATION
//=====================================================================

task automatic tc1_reset;

begin

    print_banner("TC1 : RESET VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Apply Reset
    //----------------------------------------------------------

    reset_dut();

    //----------------------------------------------------------
    // Display DUT Status
    //----------------------------------------------------------

    print_status();

    //----------------------------------------------------------
    // Check Outputs
    //----------------------------------------------------------

    if ((dut.w_reg   == 0) &&
        (a_out       == 0) &&
        (psum_out    == 0))
    begin

        passed_tests = passed_tests + 1;

        $display("");
        $display("STATUS : PASS");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("");
        $display("STATUS : FAIL");

        $display("");
        $display("Expected");
        $display("----------------------------------------");
        $display("Weight Register = 0");
        $display("a_out           = 0");
        $display("psum_out        = 0");

        $display("");
        $display("Observed");
        $display("----------------------------------------");
        $display("Weight Register = %0d", $signed(dut.w_reg));
        $display("a_out           = %0d", $signed(a_out));
        $display("psum_out        = %0d", $signed(psum_out));

    end

    $display("");
    $display("------------------------------------------------------------");
    $display("TC1 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end
endtask

//=====================================================================
// TC2 : WEIGHT LOADING VERIFICATION
//=====================================================================

task automatic tc2_weight_loading;

begin

    print_banner("TC2 : WEIGHT LOADING VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Make sure DUT starts from reset state
    //----------------------------------------------------------

    reset_dut();

    //----------------------------------------------------------
    // Apply weight
    //----------------------------------------------------------

    weight_in   = 8'sd5;
    load_weight = 1;

    //----------------------------------------------------------
    // Load weight
    //----------------------------------------------------------

    @(posedge clk);

    //----------------------------------------------------------
    // Remove load signal
    //----------------------------------------------------------

    load_weight = 0;

    //----------------------------------------------------------
    // Allow registered weight to update
    //----------------------------------------------------------

    @(posedge clk);

    //----------------------------------------------------------
    // Display DUT Status
    //----------------------------------------------------------

    print_status();

    //----------------------------------------------------------
    // Check Weight Register
    //----------------------------------------------------------

    if ($signed(dut.w_reg) == 5)
    begin

        passed_tests = passed_tests + 1;

        $display("");
        $display("STATUS : PASS");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("");
        $display("STATUS : FAIL");

        $display("");
        $display("Expected");
        $display("----------------------------------------");
        $display("Weight Register = 5");

        $display("");
        $display("Observed");
        $display("----------------------------------------");
        $display("Weight Register = %0d",
                 $signed(dut.w_reg));

    end

    $display("");
    $display("------------------------------------------------------------");
    $display("TC2 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
// TC3 : ACTIVATION FORWARDING VERIFICATION
//=====================================================================

task automatic tc3_activation_forwarding;

reg test_pass;

begin

    print_banner("TC3 : ACTIVATION FORWARDING VERIFICATION");

    total_tests = total_tests + 1;
    test_pass   = 1;

    //----------------------------------------------------------
    // Reset DUT
    //----------------------------------------------------------

    reset_dut();

    //----------------------------------------------------------
    // Apply activation
    //----------------------------------------------------------

    a_in = 8'sd10;

    @(posedge clk);
    #1;

    //----------------------------------------------------------
    // Check activation forwarding
    //----------------------------------------------------------

    if ($signed(a_out) != 10)
        test_pass = 0;

    //----------------------------------------------------------
    // Remove input
    //----------------------------------------------------------

    a_in = 0;

    @(posedge clk);
    #1;

    //----------------------------------------------------------
    // Check zero forwarding
    //----------------------------------------------------------

    if ($signed(a_out) != 0)
        test_pass = 0;

    //----------------------------------------------------------
    // Final result
    //----------------------------------------------------------

    if (test_pass)
    begin
        passed_tests = passed_tests + 1;
        $display("STATUS : PASS");
    end
    else
    begin
        failed_tests = failed_tests + 1;
        $display("STATUS : FAIL");
    end

    $display("");
    $display("------------------------------------------------------------");
    $display("TC3 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
// TC4 : MULTIPLICATION VERIFICATION
//=====================================================================

task automatic tc4_multiplication;

begin

    print_banner("TC4 : MULTIPLICATION VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Reset DUT
    //----------------------------------------------------------

    reset_dut();

    //----------------------------------------------------------
    // Load Weight
    //----------------------------------------------------------

    weight_in   = 8'sd3;
    load_weight = 1;

    @(posedge clk);
    #1;

    load_weight = 0;

    //----------------------------------------------------------
    // Apply activation
    //----------------------------------------------------------

    a_in   = 8'sd4;
    psum_in = 0;

    //----------------------------------------------------------
    // Product is registered first
    //----------------------------------------------------------

    @(posedge clk);
    #1;

    //----------------------------------------------------------
    // Product is now available to accumulation stage
    //----------------------------------------------------------

    @(posedge clk);
    #1;

    //----------------------------------------------------------
    // Check result
    //----------------------------------------------------------

    print_status();

    if ($signed(psum_out) == 12)
    begin

        passed_tests = passed_tests + 1;

        $display("");
        $display("Expected : 3 x 4 = 12");
        $display("Observed : %0d", $signed(psum_out));
        $display("");
        $display("STATUS : PASS");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("");
        $display("STATUS : FAIL");

        $display("");
        $display("Expected");
        $display("----------------------------------------");
        $display("psum_out = 12");

        $display("");
        $display("Observed");
        $display("----------------------------------------");
        $display("psum_out = %0d", $signed(psum_out));

    end

    //----------------------------------------------------------
    // Clear inputs
    //----------------------------------------------------------

    a_in    = 0;
    psum_in = 0;

    $display("");
    $display("------------------------------------------------------------");
    $display("TC4 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask
//=====================================================================
// TC5 : ACCUMULATION VERIFICATION
//=====================================================================

task automatic tc5_accumulation;

begin

    print_banner("TC5 : ACCUMULATION VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Reset DUT
    //----------------------------------------------------------

    reset_dut();

    //----------------------------------------------------------
    // Load Weight
    //----------------------------------------------------------

    weight_in   = 8'sd3;
    load_weight = 1;

    @(posedge clk);
    #1;

    load_weight = 0;

    //----------------------------------------------------------
    // Apply activation and partial sum
    //----------------------------------------------------------

    a_in    = 8'sd4;
    psum_in = 10;

    //----------------------------------------------------------
    // Wait for multiplication stage
    //----------------------------------------------------------

    @(posedge clk);
    #1;

    //----------------------------------------------------------
    // Wait for accumulation stage
    //----------------------------------------------------------

    @(posedge clk);
    #1;

    //----------------------------------------------------------
    // Display DUT Status
    //----------------------------------------------------------

    print_status();

    //----------------------------------------------------------
    // Check accumulated result
    //----------------------------------------------------------

    if ($signed(psum_out) == 22)
    begin

        passed_tests = passed_tests + 1;

        $display("");
        $display("Expected : 10 + (4 x 3) = 22");
        $display("Observed : %0d", $signed(psum_out));
        $display("");
        $display("STATUS : PASS");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("");
        $display("STATUS : FAIL");

        $display("");
        $display("Expected");
        $display("----------------------------------------");
        $display("psum_out = 22");

        $display("");
        $display("Observed");
        $display("----------------------------------------");
        $display("psum_out = %0d", $signed(psum_out));

    end

    //----------------------------------------------------------
    // Clear inputs
    //----------------------------------------------------------

    a_in    = 0;
    psum_in = 0;

    $display("");
    $display("------------------------------------------------------------");
    $display("TC5 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
// TC6 : SIGNED / NEGATIVE NUMBER VERIFICATION
//=====================================================================

task automatic tc6_signed_arithmetic;

reg test_pass;

begin

    print_banner("TC6 : SIGNED / NEGATIVE NUMBER VERIFICATION");

    total_tests = total_tests + 1;
    test_pass   = 1;

    //----------------------------------------------------------
    // Reset DUT
    //----------------------------------------------------------

    reset_dut();

    //==========================================================
    // SUB-TEST 1 : Negative Weight
    //==========================================================

    weight_in   = -8'sd3;
    load_weight = 1;

    @(posedge clk);
    #1;

    load_weight = 0;

    a_in    = 8'sd4;
    psum_in = 0;

    @(posedge clk);
    #1;

    @(posedge clk);
    #1;

    if ($signed(psum_out) != -12)
        test_pass = 0;

    //----------------------------------------------------------
    // SUB-TEST 2 : Negative x Negative
    //----------------------------------------------------------

    a_in    = -8'sd4;
    psum_in = 0;

    @(posedge clk);
    #1;

    @(posedge clk);
    #1;

    if ($signed(psum_out) != 12)
        test_pass = 0;

    //----------------------------------------------------------
    // Final TC6 Result
    //----------------------------------------------------------

    if (test_pass)
    begin

        passed_tests = passed_tests + 1;

        $display("");
        $display("Expected:");
        $display("(-3) x 4  = -12");
        $display("(-3) x (-4) = 12");

        $display("");
        $display("STATUS : PASS");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("");
        $display("STATUS : FAIL");

    end

    //----------------------------------------------------------
    // Clear inputs
    //----------------------------------------------------------

    a_in    = 0;
    psum_in = 0;

    $display("");
    $display("------------------------------------------------------------");
    $display("TC6 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//----------------------------------------------------------
// section 13 complete
//----------------------------------------------------------
//=====================================================================
// SECTION - 14
// TIME FORMAT
//=====================================================================

initial
begin

    $timeformat(-9, 0, " ns", 10);

end
//=====================================================================
// SECTION - 15
// WAVEFORM DUMP
//=====================================================================

initial
begin

    $dumpfile("tb_processing_element.vcd");
    $dumpvars(0, tb_processing_element);

end
 //=====================================================================
// SECTION - 16
// SIMULATION TIMEOUT
//=====================================================================

initial
begin

    #5000;

    $display("");
    $display("========================================");
    $display("SIMULATION TIMEOUT");
    $display("========================================");

    $finish;

end
//=====================================================================
// SECTION - 17
// MAIN TEST SEQUENCE
//=====================================================================

initial
begin

    //----------------------------------------------------------
    // Run Test Cases
    //----------------------------------------------------------

    tc1_reset();

    tc2_weight_loading();

    tc3_activation_forwarding();

    tc4_multiplication();

    tc5_accumulation();

    tc6_signed_arithmetic();

    //----------------------------------------------------------
    // Final Verification Summary
    //----------------------------------------------------------

    print_summary();

    //----------------------------------------------------------
    // End Simulation
    //----------------------------------------------------------

    $finish;

end

endmodule











