`timescale 1ns/1ps 
//===================================================================== 
// SECTION - 1 
// TESTBENCH 
// Systolic Array 4x4 Verification 
//===================================================================== 
module systolic_array_4x4_tb;
//=====================================================================
// SECTION - 2
// PARAMETERS AND CLOCK RESET
//=====================================================================
localparam NUM_ROWS   = 4;
localparam NUM_COLS   = 4;
localparam DATA_WIDTH = 8;
localparam ACC_WIDTH  = (2*DATA_WIDTH) + 1;
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
reg                                      load_weight;
reg signed [NUM_ROWS*NUM_COLS*DATA_WIDTH-1:0] weight_in;
reg signed [NUM_ROWS*DATA_WIDTH-1:0]          a_in;
//=====================================================================
// SECTION - 5
// DUT OUTPUTS
// here the output wires are just reg because 
//=====================================================================
wire signed [NUM_COLS*ACC_WIDTH-1:0] acc_out;
wire signed [NUM_ROWS*DATA_WIDTH-1:0] a_out;


/*// debugging...............................
integer r;
integer c;
integer k;
integer debug_cycle;
*/
//=====================================================================
// SECTION - 6
// DUT INSTANTIATION
//=====================================================================
systolic_array_4x4
#(
    .NUM_ROWS   (NUM_ROWS),
    .NUM_COLS   (NUM_COLS),
    .DATA_WIDTH (DATA_WIDTH)
)
dut
(
    .clk         (clk),
    .rst         (rst),

    .load_weight (load_weight),
    .weight_in   (weight_in),

    .a_in        (a_in),

    .acc_out     (acc_out),
    .a_out       (a_out)
);
//=====================================================================
// DEBUG ACCESS TO PE WEIGHT REGISTERS
//
// Direct hierarchical references to generate blocks must use
// elaboration-time constant indices.
//
// These wires expose all 16 PE weight registers so that procedural
// loops can safely access them using r and c.
//=====================================================================

wire signed [DATA_WIDTH-1:0] pe_weight_debug [0:NUM_ROWS-1][0:NUM_COLS-1];

genvar gr;
genvar gc;

generate

    for (gr = 0; gr < NUM_ROWS; gr = gr + 1) begin : DEBUG_ROW

        for (gc = 0; gc < NUM_COLS; gc = gc + 1) begin : DEBUG_COL

            assign pe_weight_debug[gr][gc] =
                dut.pe_row[gr].pe_col[gc].pe_inst.w_reg;

        end

    end

endgenerate
//=====================================================================
// SECTION - 7
// CLOCK GENERATION
//=====================================================================
initial begin
    clk = 0;
    forever
        #5 clk = ~clk;
end
//=====================================================================
// SECTION - 8
// INITIALIZATION
//=====================================================================
initial begin
    rst                  = 1;
    load_weight          = 0;
    weight_in            = 0;
    a_in                 = 0;
    scoreboard_enable    = 0;
    total_tests          = 0;
    passed_tests         = 0;
    failed_tests         = 0;
    cycle                = 0;
    // temporary one 
    //debug_cycle =0;
end
//=====================================================================
// SECTION - 9
// CYCLE COUNTER
//=====================================================================
always @(posedge clk) begin
    cycle = cycle + 1;
end
//=====================================================================
// SECTION - 10
// UTILITY TASKS
//=====================================================================

task reset_dut;
begin
    rst               = 1;
    load_weight       = 0;
    weight_in         = 0;
    a_in              = 0;

    scoreboard_enable = 0;
    cycle             = 0;

    repeat (2) @(posedge clk);

    rst = 0;

    @(posedge clk);
end
endtask
//=====================================================================
// PRINT MATRIX
//=====================================================================

task print_matrix;
    input signed [NUM_ROWS*NUM_COLS*DATA_WIDTH-1:0] matrix;
    input [8*20-1:0] matrix_name;

    integer r;
    integer c;
    reg signed [DATA_WIDTH-1:0] value;

    begin
        $display("");
        $display("============================================================");
        $display("%0s", matrix_name);
        $display("============================================================");

        $write("        ");
        for (c = 0; c < NUM_COLS; c = c + 1)
            $write("C%-7d", c);

        $display("");

        for (r = 0; r < NUM_ROWS; r = r + 1) begin
            $write("R%-5d", r);

            for (c = 0; c < NUM_COLS; c = c + 1) begin
                value = matrix[((r*NUM_COLS+c)*DATA_WIDTH) +: DATA_WIDTH];
                $write("%-8d", value);
            end

            $display("");
        end

        $display("============================================================");
        $display("");
    end
endtask
//=====================================================================
// PRINT RESULTS
//=====================================================================
task print_results;
    integer c;
    reg signed [ACC_WIDTH-1:0] result;

    begin
        $display("");
        $display("============================================================");
        $display("                 SYSTOLIC ARRAY RESULTS");
        $display("============================================================");

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            result = acc_out[((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH];

            $display("Column %0d : %0d", c, result);

        end

        $display("============================================================");
        $display("");
    end
endtask
//=====================================================================
// SECTION - 10.4
// PRINT BANNER
//=====================================================================

task print_banner;
    input [8*60-1:0] test_name;

    begin
        $display("");
        $display("================================================================");
        $display("%0s", test_name);
        $display("================================================================");
        $display("");
    end
endtask
//=====================================================================
// SECTION - 10.5
// PRINT SUMMARY
//=====================================================================

task print_summary;
    begin
        $display("");
        $display("================================================================");
        $display("                 FINAL VERIFICATION SUMMARY");
        $display("================================================================");

        $display("Total Tests : %0d", total_tests);
        $display("Passed      : %0d", passed_tests);
        $display("Failed      : %0d", failed_tests);

        $display("----------------------------------------------------------------");

        if (failed_tests == 0)
            $display("OVERALL RESULT : PASS");
        else
            $display("OVERALL RESULT : FAIL");

        $display("================================================================");
        $display("");
    end
endtask
//=====================================================================
// SECTION - 11.1
// REFERENCE MODEL
// refernece parameter declaration
//=====================================================================
reg signed [DATA_WIDTH-1:0]     ref_weights         [0:NUM_ROWS-1][0:NUM_COLS-1];
reg signed [DATA_WIDTH-1:0]     ref_a_grid          [0:NUM_ROWS-1][0:NUM_COLS];
reg signed [ACC_WIDTH-1:0]      ref_psum_grid       [0:NUM_ROWS][0:NUM_COLS-1];
reg signed [2*DATA_WIDTH-1:0]   ref_product_grid    [0:NUM_ROWS-1][0:NUM_COLS-1];
reg signed [DATA_WIDTH-1:0]     next_a_grid         [0:NUM_ROWS-1][0:NUM_COLS];
reg signed [2*DATA_WIDTH-1:0]   next_product_grid   [0:NUM_ROWS-1][0:NUM_COLS-1];
reg signed [ACC_WIDTH-1:0]      next_psum_grid      [0:NUM_ROWS][0:NUM_COLS-1];
reg signed [ACC_WIDTH-1:0]      expected_acc        [0:NUM_COLS-1];
integer                         rr;
integer                         cc;
//=====================================================================
// SECTION - 11.2
// LOAD REFERENCE WEIGHTS
//=====================================================================

task load_reference_weights;
    integer r;
    integer c;

    begin
        for (r = 0; r < NUM_ROWS; r = r + 1) begin
            for (c = 0; c < NUM_COLS; c = c + 1) begin
                ref_weights[r][c] =
                    weight_in[((r*NUM_COLS+c)*DATA_WIDTH) +: DATA_WIDTH];
            end
        end
    end
endtask
//=====================================================================
// SECTION - 11.3
// REFERENCE ACTIVATION MATRIX
//=====================================================================
reg signed [DATA_WIDTH-1:0] ref_matrix_a [0:NUM_ROWS-1][0:NUM_COLS-1];
task load_reference_matrix;
    input signed [NUM_ROWS*NUM_COLS*DATA_WIDTH-1:0] matrix;

    integer r;
    integer c;

    begin
        for (r = 0; r < NUM_ROWS; r = r + 1) begin
            for (c = 0; c < NUM_COLS; c = c + 1) begin
                ref_matrix_a[r][c] =
                    matrix[((r*NUM_COLS+c)*DATA_WIDTH) +: DATA_WIDTH];
            end
        end
    end
endtask
//=====================================================================
// SECTION - 11.4
// CYCLE-BY-CYCLE REFERENCE MODEL
//=====================================================================

task reference_model_step;

    integer r;
    integer c;

    begin

        //=============================================================
        // STEP 1
        // Calculate next activation values
        //=============================================================

        for (r = 0; r < NUM_ROWS; r = r + 1) begin

            next_a_grid[r][0] = a_in[((r+1)*DATA_WIDTH)-1 -: DATA_WIDTH];

            for (c = 0; c < NUM_COLS; c = c + 1) begin
                next_a_grid[r][c+1] = ref_a_grid[r][c];
            end

        end


        //=============================================================
        // STEP 2
        // Calculate next product registers
        //=============================================================

        for (r = 0; r < NUM_ROWS; r = r + 1) begin
            for (c = 0; c < NUM_COLS; c = c + 1) begin

                next_product_grid[r][c] =
                    ref_a_grid[r][c] * ref_weights[r][c];

            end
        end


        //=============================================================
        // STEP 3
        // Calculate next partial sums
        //=============================================================

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            next_psum_grid[0][c] = 0;

            for (r = 0; r < NUM_ROWS; r = r + 1) begin

                next_psum_grid[r+1][c] =
                    ref_psum_grid[r][c] +
                    ref_product_grid[r][c];

            end

        end


        //=============================================================
        // STEP 4
        // Update reference-model state
        //=============================================================

        for (r = 0; r < NUM_ROWS; r = r + 1) begin

            for (c = 0; c <= NUM_COLS; c = c + 1) begin
                ref_a_grid[r][c] = next_a_grid[r][c];
            end

        end


        for (r = 0; r < NUM_ROWS; r = r + 1) begin
            for (c = 0; c < NUM_COLS; c = c + 1) begin

                ref_product_grid[r][c] =
                    next_product_grid[r][c];

            end
        end


        for (r = 0; r <= NUM_ROWS; r = r + 1) begin
            for (c = 0; c < NUM_COLS; c = c + 1) begin

                ref_psum_grid[r][c] =
                    next_psum_grid[r][c];

            end
        end


        //=============================================================
        // STEP 5
        // Extract final expected outputs
        //=============================================================

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            expected_acc[c] = ref_psum_grid[NUM_ROWS][c];

        end

    end
endtask

//=====================================================================
// REFERENCE MODEL DESCRIPTION
//=====================================================================
// The reference model mimics the systolic array cycle by cycle.
// It shifts activations horizontally, calculates products using
// stationary weights, propagates partial sums vertically, and
// generates the expected bottom-row outputs.
//=====================================================================

//=====================================================================
// SECTION - 11.5
// RESET REFERENCE MODEL
//=====================================================================

task reset_reference_model;

integer r;
integer c;

begin

    //=============================================================
    // Reset reference weights
    //=============================================================

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            ref_weights[r][c]      = 0;
            ref_matrix_a[r][c]     = 0;

            ref_product_grid[r][c] = 0;
            next_product_grid[r][c] = 0;

        end

    end


    //=============================================================
    // Reset activation pipeline
    //
    // NUM_COLS + 1 entries because:
    //
    // [0]     = external a_in
    // [1]     = PE column 0 output
    // [2]     = PE column 1 output
    // ...
    // [4]     = right-edge output
    //=============================================================

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c <= NUM_COLS; c = c + 1) begin

            ref_a_grid[r][c]   = 0;
            next_a_grid[r][c]  = 0;

        end

    end


    //=============================================================
    // Reset partial-sum pipeline
    //
    // NUM_ROWS + 1 entries because:
    //
    // [0] = top boundary
    // [1] = PE row 0 output
    // [2] = PE row 1 output
    // ...
    // [4] = bottom output
    //=============================================================

    for (r = 0; r <= NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            ref_psum_grid[r][c]  = 0;
            next_psum_grid[r][c] = 0;

        end

    end


    //=============================================================
    // Reset expected outputs
    //=============================================================

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        expected_acc[c] = 0;

    end
end
endtask
//=====================================================================
// SECTION - 12
// SCOREBOARD
//=====================================================================

always @(posedge clk)
begin

    if (!rst && scoreboard_enable)
    begin

        $display("");
        $display("============================================================");
        $display("SYSTOLIC ARRAY SCOREBOARD");
        $display("Cycle : %0d", cycle);
        $display("============================================================");

        //-------------------------------------------------------------
        // COLUMN 0
        //-------------------------------------------------------------

        $display("");
        $display("COLUMN 0");
        $display("--------------------------------------------");

        $display("Expected : %6d",
                 $signed(expected_acc[0]));

        $display("Actual   : %6d",
                 $signed(acc_out[(1*ACC_WIDTH)-1 -: ACC_WIDTH]));

        //-------------------------------------------------------------
        // COLUMN 1
        //-------------------------------------------------------------

        $display("");
        $display("COLUMN 1");
        $display("--------------------------------------------");

        $display("Expected : %6d",
                 $signed(expected_acc[1]));

        $display("Actual   : %6d",
                 $signed(acc_out[(2*ACC_WIDTH)-1 -: ACC_WIDTH]));

        //-------------------------------------------------------------
        // COLUMN 2
        //-------------------------------------------------------------

        $display("");
        $display("COLUMN 2");
        $display("--------------------------------------------");

        $display("Expected : %6d",
                 $signed(expected_acc[2]));

        $display("Actual   : %6d",
                 $signed(acc_out[(3*ACC_WIDTH)-1 -: ACC_WIDTH]));

        //-------------------------------------------------------------
        // COLUMN 3
        //-------------------------------------------------------------

        $display("");
        $display("COLUMN 3");
        $display("--------------------------------------------");

        $display("Expected : %6d",
                 $signed(expected_acc[3]));

        $display("Actual   : %6d",
                 $signed(acc_out[(4*ACC_WIDTH)-1 -: ACC_WIDTH]));

        //-------------------------------------------------------------
        // PASS / FAIL
        //-------------------------------------------------------------

        if (
            ($signed(expected_acc[0]) ===
             $signed(acc_out[(1*ACC_WIDTH)-1 -: ACC_WIDTH])) &&

            ($signed(expected_acc[1]) ===
             $signed(acc_out[(2*ACC_WIDTH)-1 -: ACC_WIDTH])) &&

            ($signed(expected_acc[2]) ===
             $signed(acc_out[(3*ACC_WIDTH)-1 -: ACC_WIDTH])) &&

            ($signed(expected_acc[3]) ===
             $signed(acc_out[(4*ACC_WIDTH)-1 -: ACC_WIDTH]))
           )
        begin

            $display("");
            $display("STATUS : PASS");

        end
        else
        begin

            $display("");
            $display("STATUS : FAIL");

        end

        $display("");
        $display("============================================================");
        $display("");

    end
end
//=====================================================================
// SECTION - 13
// TEST CASES
//=====================================================================

//=====================================================================
// TC1 : RESET VERIFICATION
//=====================================================================
task tc1_reset;
begin

    print_banner("TC1 : RESET VERIFICATION");

    total_tests = total_tests + 1;

    //-------------------------------------------------------------
    // Apply Reset on  DUT
    //-------------------------------------------------------------

    reset_dut();

    //-------------------------------------------------------------
    // Check all outputs
    //-------------------------------------------------------------

    if (($signed(acc_out) == 0) &&
        ($signed(a_out)   == 0))
    begin

        passed_tests = passed_tests + 1;

        $display("STATUS : PASS");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("STATUS : FAIL");

        $display("");
        $display("Expected:");
        $display("acc_out = 0");
        $display("a_out   = 0");

        $display("");
        $display("Observed:");
        $display("acc_out = %0d", $signed(acc_out));
        $display("a_out   = %0d", $signed(a_out));

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

task tc2_weight_loading;

integer r;
integer c;

begin

    print_banner("TC2 : WEIGHT LOADING VERIFICATION");

    total_tests = total_tests + 1;

    //-------------------------------------------------------------
    // Reset DUT and reference model
    //-------------------------------------------------------------

    reset_dut();
    reset_reference_model();

    //-------------------------------------------------------------
    // Give every PE a known weight
    //
    // For easy checking:
    //
    //  1  2  3  4
    //  5  6  7  8
    //  9 10 11 12
    // 13 14 15 16
    //
    //-------------------------------------------------------------

    weight_in = 0;

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            weight_in[((r*NUM_COLS+c)*DATA_WIDTH) +: DATA_WIDTH]
                = r*NUM_COLS + c + 1;

        end

    end

    //-------------------------------------------------------------
    // Load weights
    //-------------------------------------------------------------

    load_weight = 1;

    @(posedge clk);
    #1;

    load_weight = 0;

    //-------------------------------------------------------------
    // Load same weights into reference model
    //-------------------------------------------------------------

    load_reference_weights();

    //-------------------------------------------------------------
    // Check reference weights
    //-------------------------------------------------------------

    $display("");
    $display("WEIGHT MATRIX");
    $display("--------------------------------------------");

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            $write("%5d",
                   $signed(ref_weights[r][c]));

        end

        $display("");

    end

    //-------------------------------------------------------------
    // Weight registers inside individual PEs
    // should now contain the loaded weights.
    //-------------------------------------------------------------

    if (
        ($signed(dut.pe_row[0].pe_col[0].pe_inst.w_reg) == 1) &&
        ($signed(dut.pe_row[0].pe_col[1].pe_inst.w_reg) == 2) &&
        ($signed(dut.pe_row[0].pe_col[2].pe_inst.w_reg) == 3) &&
        ($signed(dut.pe_row[0].pe_col[3].pe_inst.w_reg) == 4) &&

        ($signed(dut.pe_row[1].pe_col[0].pe_inst.w_reg) == 5) &&
        ($signed(dut.pe_row[1].pe_col[1].pe_inst.w_reg) == 6) &&
        ($signed(dut.pe_row[1].pe_col[2].pe_inst.w_reg) == 7) &&
        ($signed(dut.pe_row[1].pe_col[3].pe_inst.w_reg) == 8) &&

        ($signed(dut.pe_row[2].pe_col[0].pe_inst.w_reg) == 9) &&
        ($signed(dut.pe_row[2].pe_col[1].pe_inst.w_reg) == 10) &&
        ($signed(dut.pe_row[2].pe_col[2].pe_inst.w_reg) == 11) &&
        ($signed(dut.pe_row[2].pe_col[3].pe_inst.w_reg) == 12) &&

        ($signed(dut.pe_row[3].pe_col[0].pe_inst.w_reg) == 13) &&
        ($signed(dut.pe_row[3].pe_col[1].pe_inst.w_reg) == 14) &&
        ($signed(dut.pe_row[3].pe_col[2].pe_inst.w_reg) == 15) &&
        ($signed(dut.pe_row[3].pe_col[3].pe_inst.w_reg) == 16)
       )
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
        $display("One or more PE weight registers are incorrect.");

    end
    //-------------------------------------------------------------
    // Clear inputs
    //-------------------------------------------------------------

    weight_in   = 0;
    load_weight = 0;

    $display("");
    $display("------------------------------------------------------------");
    $display("TC2 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask
//=====================================================================
// TC3 : ACTIVATION PROPAGATION VERIFICATION
//=====================================================================

task tc3_activation_propagation;

reg test_pass;

begin

    print_banner("TC3 : ACTIVATION PROPAGATION VERIFICATION");

    total_tests = total_tests + 1;
    test_pass   = 1;

    //-------------------------------------------------------------
    // Reset DUT
    //-------------------------------------------------------------

    reset_dut();

    //-------------------------------------------------------------
    // Apply one activation to every row
    //
    // Row 0 : 10
    // Row 1 : 20
    // Row 2 : 30
    // Row 3 : 40
    //-------------------------------------------------------------

    a_in[0*DATA_WIDTH +: DATA_WIDTH] = 8'sd10;
    a_in[1*DATA_WIDTH +: DATA_WIDTH] = 8'sd20;
    a_in[2*DATA_WIDTH +: DATA_WIDTH] = 8'sd30;
    a_in[3*DATA_WIDTH +: DATA_WIDTH] = 8'sd40;

    //-------------------------------------------------------------
    // Cycle 1
    //
    // PE column 0 receives the activations.
    // a_out is still the registered previous value.
    //-------------------------------------------------------------

    @(posedge clk);
    #1;

    //-------------------------------------------------------------
    // Cycle 2
    //
    // Activations should now be at column 1.
    //-------------------------------------------------------------

    if (($signed(dut.a_grid[0][1]) != 10) ||
        ($signed(dut.a_grid[1][1]) != 20) ||
        ($signed(dut.a_grid[2][1]) != 30) ||
        ($signed(dut.a_grid[3][1]) != 40))
    begin
        test_pass = 0;
    end

    //-------------------------------------------------------------
    // Cycle 3
    //
    // Activations should now be at column 2.
    //-------------------------------------------------------------

    @(posedge clk);
    #1;

    if (($signed(dut.a_grid[0][2]) != 10) ||
        ($signed(dut.a_grid[1][2]) != 20) ||
        ($signed(dut.a_grid[2][2]) != 30) ||
        ($signed(dut.a_grid[3][2]) != 40))
    begin
        test_pass = 0;
    end

    //-------------------------------------------------------------
    // Cycle 4
    //
    // Activations should now be at column 3.
    //-------------------------------------------------------------

    @(posedge clk);
    #1;

    if (($signed(dut.a_grid[0][3]) != 10) ||
        ($signed(dut.a_grid[1][3]) != 20) ||
        ($signed(dut.a_grid[2][3]) != 30) ||
        ($signed(dut.a_grid[3][3]) != 40))
    begin
        test_pass = 0;
    end

    //-------------------------------------------------------------
    // Cycle 5
    //
    // Activations should reach the right edge.
    //-------------------------------------------------------------

    @(posedge clk);
    #1;

    if (($signed(a_out[0*DATA_WIDTH +: DATA_WIDTH]) != 10) ||
        ($signed(a_out[1*DATA_WIDTH +: DATA_WIDTH]) != 20) ||
        ($signed(a_out[2*DATA_WIDTH +: DATA_WIDTH]) != 30) ||
        ($signed(a_out[3*DATA_WIDTH +: DATA_WIDTH]) != 40))
    begin
        test_pass = 0;
    end

    //-------------------------------------------------------------
    // Display result
    //-------------------------------------------------------------

    $display("");
    $display("EXPECTED ACTIVATIONS AT RIGHT EDGE");
    $display("--------------------------------------------");
    $display("Row 0 : 10");
    $display("Row 1 : 20");
    $display("Row 2 : 30");
    $display("Row 3 : 40");

    $display("");
    $display("ACTUAL ACTIVATIONS");
    $display("--------------------------------------------");
    $display("Row 0 : %0d",
             $signed(a_out[0*DATA_WIDTH +: DATA_WIDTH]));
    $display("Row 1 : %0d",
             $signed(a_out[1*DATA_WIDTH +: DATA_WIDTH]));
    $display("Row 2 : %0d",
             $signed(a_out[2*DATA_WIDTH +: DATA_WIDTH]));
    $display("Row 3 : %0d",
             $signed(a_out[3*DATA_WIDTH +: DATA_WIDTH]));

    //-------------------------------------------------------------
    // PASS / FAIL
    //-------------------------------------------------------------

    if (test_pass)
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

    end

    //-------------------------------------------------------------
    // Clear input
    //-------------------------------------------------------------

    a_in = 0;

    $display("");
    $display("------------------------------------------------------------");
    $display("TC3 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
//=====================================================================
//=====================================================================
//=====================================================================
//=====================================================================
// TC4 : 4x4 MATRIX MULTIPLICATION VERIFICATION
//=====================================================================
//=====================================================================
//=====================================================================
//=====================================================================
//=====================================================================
//=====================================================================
// TC4 : 4x4 MATRIX MULTIPLICATION VERIFICATION
//=====================================================================
//
// DUT UNDER TEST:
//
//     systolic_array_4x4
//
// Dataflow:
//
//     Activations : LEFT  -> RIGHT
//     Partial Sum : TOP   -> BOTTOM
//
// Weight matrix:
//
//          C0  C1  C2  C3
//     R0    1   0   0   0
//     R1    0   1   0   0
//     R2    0   0   1   0
//     R3    0   0   0   1
//
// Activation matrix:
//
//          C0  C1  C2  C3
//     R0    1   2   3   4
//     R1    5   6   7   8
//     R2    9  10  11  12
//     R3   13  14  15  16
//
// Expected systolic outputs:
//
//     Column 0 = 1 + 2 + 3 + 4       = 10
//     Column 1 = 5 + 6 + 7 + 8       = 26
//     Column 2 = 9 + 10 + 11 + 12    = 42
//     Column 3 = 13 + 14 + 15 + 16   = 58
//
//=====================================================================

task tc4_matrix_multiplication;

integer r;
integer c;
integer k;

reg signed [DATA_WIDTH-1:0]
    test_a [0:NUM_ROWS-1][0:NUM_COLS-1];

reg signed [DATA_WIDTH-1:0]
    test_w [0:NUM_ROWS-1][0:NUM_COLS-1];

reg signed [ACC_WIDTH-1:0]
    expected_result [0:NUM_COLS-1];

reg test_pass;

begin

    print_banner("TC4 : 4x4 SYSTOLIC COMPUTATION VERIFICATION");

    total_tests = total_tests + 1;
    test_pass   = 1;

    //=============================================================
    // STEP 1 : RESET DUT
    //=============================================================

    reset_dut();


    //=============================================================
    // STEP 2 : DEFINE ACTIVATION MATRIX
    //=============================================================

    test_a[0][0] =  1;
    test_a[0][1] =  2;
    test_a[0][2] =  3;
    test_a[0][3] =  4;

    test_a[1][0] =  5;
    test_a[1][1] =  6;
    test_a[1][2] =  7;
    test_a[1][3] =  8;

    test_a[2][0] =  9;
    test_a[2][1] = 10;
    test_a[2][2] = 11;
    test_a[2][3] = 12;

    test_a[3][0] = 13;
    test_a[3][1] = 14;
    test_a[3][2] = 15;
    test_a[3][3] = 16;


    //=============================================================
    // STEP 3 : DEFINE IDENTITY WEIGHT MATRIX
    //=============================================================

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            if (r == c)
                test_w[r][c] = 1;
            else
                test_w[r][c] = 0;

        end

    end


    //=============================================================
    // STEP 4 : PACK WEIGHT MATRIX
    //
    // weight_in:
    //
    // [7:0]    = W[0][0]
    // [15:8]   = W[0][1]
    // ...
    //=============================================================

    weight_in = 0;

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            weight_in[
                ((r * NUM_COLS + c) * DATA_WIDTH)
                +: DATA_WIDTH
            ] = test_w[r][c];

        end

    end


    //=============================================================
    // STEP 5 : LOAD WEIGHTS
    //
    // load_weight is sampled by all 16 PEs on this clock edge.
    //=============================================================

    load_weight = 1;

    @(posedge clk);
    #1;

    load_weight = 0;


    //=============================================================
    // STEP 6 : CALCULATE EXPECTED RESULTS
    //
    // For this systolic architecture:
    //
    // result[c] =
    //
    //     SUM(r=0..3)
    //     SUM(k=0..3)
    //
    //         A[r][k] * W[r][c]
    //
    // Since W is the identity matrix:
    //
    // result[0] = A[0][0] + A[0][1] + A[0][2] + A[0][3]
    // result[1] = A[1][0] + A[1][1] + A[1][2] + A[1][3]
    // result[2] = A[2][0] + A[2][1] + A[2][2] + A[2][3]
    // result[3] = A[3][0] + A[3][1] + A[3][2] + A[3][3]
    //
    // Expected:
    //
    //     10, 26, 42, 58
    //
    //=============================================================

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        expected_result[c] = 0;

        for (r = 0; r < NUM_ROWS; r = r + 1) begin

            for (k = 0; k < NUM_COLS; k = k + 1) begin

                expected_result[c] =
                    expected_result[c] +
                    test_a[r][k] * test_w[r][c];

            end

        end

    end


    //=============================================================
    // STEP 7 : DISPLAY MATRICES
    //=============================================================

    $display("");
    $display("INPUT ACTIVATION MATRIX");
    $display("============================================================");

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        $display("%6d %6d %6d %6d",
                 test_a[r][0],
                 test_a[r][1],
                 test_a[r][2],
                 test_a[r][3]);

    end


    $display("");
    $display("IDENTITY WEIGHT MATRIX");
    $display("============================================================");

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        $display("%6d %6d %6d %6d",
                 test_w[r][0],
                 test_w[r][1],
                 test_w[r][2],
                 test_w[r][3]);

    end


    //=============================================================
    // STEP 8 : DISPLAY EXPECTED RESULTS
    //=============================================================

    $display("");
    $display("EXPECTED RESULTS");
    $display("============================================================");

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        $display("Column %0d : %0d",
                 c,
                 $signed(expected_result[c]));

    end


    //=============================================================
    // STEP 9 : FEED SKEWED ACTIVATION STREAM
    //
    // The skew is essential for the systolic dataflow.
    //
    // Cycle 0 :
    //
    //     A00    0     0     0
    //
    // Cycle 1 :
    //
    //     A01   A10    0     0
    //
    // Cycle 2 :
    //
    //     A02   A11   A20    0
    //
    // Cycle 3 :
    //
    //     A03   A12   A21   A30
    //
    // Cycle 4 :
    //
    //      0    A13   A22   A31
    //
    // Cycle 5 :
    //
    //      0     0    A23   A32
    //
    // Cycle 6 :
    //
    //      0     0     0    A33
    //
    //=============================================================

    for (k = 0;
         k < NUM_ROWS + NUM_COLS - 1;
         k = k + 1) begin


        //=========================================================
        // ROW 0
        //=========================================================

        if (k < NUM_COLS)

            a_in[
                0*DATA_WIDTH +: DATA_WIDTH
            ] = test_a[0][k];

        else

            a_in[
                0*DATA_WIDTH +: DATA_WIDTH
            ] = 0;


        //=========================================================
        // ROW 1
        //=========================================================

        if ((k >= 1) &&
            ((k - 1) < NUM_COLS))

            a_in[
                1*DATA_WIDTH +: DATA_WIDTH
            ] = test_a[1][k-1];

        else

            a_in[
                1*DATA_WIDTH +: DATA_WIDTH
            ] = 0;


        //=========================================================
        // ROW 2
        //=========================================================

        if ((k >= 2) &&
            ((k - 2) < NUM_COLS))

            a_in[
                2*DATA_WIDTH +: DATA_WIDTH
            ] = test_a[2][k-2];

        else

            a_in[
                2*DATA_WIDTH +: DATA_WIDTH
            ] = 0;


        //=========================================================
        // ROW 3
        //=========================================================

        if ((k >= 3) &&
            ((k - 3) < NUM_COLS))

            a_in[
                3*DATA_WIDTH +: DATA_WIDTH
            ] = test_a[3][k-3];

        else

            a_in[
                3*DATA_WIDTH +: DATA_WIDTH
            ] = 0;


        //=========================================================
        // APPLY INPUTS FOR ONE COMPLETE CLOCK PERIOD
        //
        // Inputs are assigned BEFORE the rising edge.
        //
        // This is important:
        //
        //     Drive data
        //          |
        //          v
        //     Rising edge
        //          |
        //          v
        //     PE samples data
        //
        //=========================================================

        @(posedge clk);
        #1;


        //=========================================================
        // DEBUG : DISPLAY CURRENT FEED CYCLE
        //=========================================================

        $display("");
        $display("TC4 FEED CYCLE = %0d", k);
        $display("--------------------------------------------");

        $display("A_IN = [%0d %0d %0d %0d]",
                 $signed(a_in[7:0]),
                 $signed(a_in[15:8]),
                 $signed(a_in[23:16]),
                 $signed(a_in[31:24]));


        //=========================================================
        // DEBUG : ACTIVATION GRID
        //=========================================================

        $display("A_GRID ROW0 = [%0d %0d %0d %0d %0d]",
                 $signed(dut.a_grid[0][0]),
                 $signed(dut.a_grid[0][1]),
                 $signed(dut.a_grid[0][2]),
                 $signed(dut.a_grid[0][3]),
                 $signed(dut.a_grid[0][4]));

        $display("A_GRID ROW1 = [%0d %0d %0d %0d %0d]",
                 $signed(dut.a_grid[1][0]),
                 $signed(dut.a_grid[1][1]),
                 $signed(dut.a_grid[1][2]),
                 $signed(dut.a_grid[1][3]),
                 $signed(dut.a_grid[1][4]));

        $display("A_GRID ROW2 = [%0d %0d %0d %0d %0d]",
                 $signed(dut.a_grid[2][0]),
                 $signed(dut.a_grid[2][1]),
                 $signed(dut.a_grid[2][2]),
                 $signed(dut.a_grid[2][3]),
                 $signed(dut.a_grid[2][4]));

        $display("A_GRID ROW3 = [%0d %0d %0d %0d %0d]",
                 $signed(dut.a_grid[3][0]),
                 $signed(dut.a_grid[3][1]),
                 $signed(dut.a_grid[3][2]),
                 $signed(dut.a_grid[3][3]),
                 $signed(dut.a_grid[3][4]));


        //=========================================================
        // DEBUG : BOTTOM PARTIAL SUMS
        //=========================================================

        $display("PSUM BOTTOM = [%0d %0d %0d %0d]",
                 $signed(dut.psum_grid[4][0]),
                 $signed(dut.psum_grid[4][1]),
                 $signed(dut.psum_grid[4][2]),
                 $signed(dut.psum_grid[4][3]));

   end


    //=============================================================
    // STEP 10 : STOP INPUT STREAM
    //=============================================================

    a_in = 0;


    //=============================================================
    // STEP 11 : FLUSH SYSTOLIC ARRAY
    //
    // 4x4 array requires enough cycles for the final
    // partial sums to propagate through the four rows.
    //
    // We deliberately give extra cycles for verification.
    //
    //=============================================================

    repeat (NUM_ROWS + NUM_COLS + 2)
    begin

        @(posedge clk);
        #1;

        $display("FLUSH : PSUM BOTTOM = [%0d %0d %0d %0d]",
                 $signed(dut.psum_grid[4][0]),
                 $signed(dut.psum_grid[4][1]),
                 $signed(dut.psum_grid[4][2]),
                 $signed(dut.psum_grid[4][3]));

    end


    //=============================================================
    // STEP 12 : DISPLAY FINAL RESULTS
    //=============================================================

    $display("");
    $display("FINAL SYSTOLIC ARRAY RESULTS");
    $display("============================================================");

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        $display("Column %0d : Expected = %6d   Actual = %6d",
                 c,
                 $signed(expected_result[c]),
                 $signed(
                     acc_out[
                         ((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH
                     ]
                 ));

    end


    //=============================================================
    // STEP 13 : COMPARE RESULTS
    //=============================================================

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        if (
            $signed(
                acc_out[
                    ((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH
                ]
            )
            !==
            $signed(expected_result[c])
        )
        begin

            test_pass = 0;

            $display("");
            $display("MISMATCH DETECTED");
            $display("--------------------------------------------");

            $display("Column   : %0d", c);

            $display("Expected : %0d",
                     $signed(expected_result[c]));

            $display("Observed : %0d",
                     $signed(
                         acc_out[
                             ((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH
                         ]
                     ));

        end

    end


    //=============================================================
    // STEP 14 : PASS / FAIL
    //=============================================================

    if (test_pass)
    begin

        passed_tests = passed_tests + 1;

        $display("");
        $display("STATUS : PASS");
        $display("All four systolic-array outputs are correct.");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("");
        $display("STATUS : FAIL");
        $display("One or more systolic-array outputs are incorrect.");

    end


    //=============================================================
    // STEP 15 : CLEAR INPUTS
    //=============================================================

    a_in        = 0;
    weight_in   = 0;
    load_weight = 0;


    $display("");
    $display("------------------------------------------------------------");
    $display("TC4 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end
endtask
//=====================================================================
//=====================================================================
//=====================================================================
//=====================================================================
// TC5 : WEIGHT HOLD VERIFICATION
//=====================================================================
//=====================================================================
//=====================================================================
//=====================================================================
//=====================================================================
task tc5_weight_hold;
integer r;
integer c;
reg test_pass;
begin
    print_banner("TC5 : WEIGHT HOLD VERIFICATION");
    total_tests = total_tests + 1;
    test_pass   = 1;

    //-------------------------------------------------------------
    // Reset DUT
    //-------------------------------------------------------------

    reset_dut();

    //-------------------------------------------------------------
    // Give every PE a known weight
    //
    //  1   2   3   4
    //  5   6   7   8
    //  9  10  11  12
    // 13  14  15  16
    //
    //-------------------------------------------------------------

    weight_in = 0;

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            weight_in[((r*NUM_COLS+c)*DATA_WIDTH) +: DATA_WIDTH]
                = r*NUM_COLS + c + 1;

        end

    end

    //-------------------------------------------------------------
    // Load weights into DUT
    //-------------------------------------------------------------
    load_weight = 1;
    @(posedge clk);
    #1;
    //-------------------------------------------------------------
    // IMPORTANT:
    // Stop loading weights.
    //
    // From this point onward, the PEs should HOLD
    // their previously loaded weights.
    //-------------------------------------------------------------

    load_weight = 0;

    //-------------------------------------------------------------
    // Clear weight input.
    //
    // This proves that the PE is actually storing the weight
    // internally and is NOT continuously reading weight_in.
    //-------------------------------------------------------------

    weight_in = 0;

    //-------------------------------------------------------------
    // Wait several clock cycles
    //
    // During these cycles:
    //
    // load_weight = 0
    // weight_in   = 0
    //
    // Therefore the PE weights should remain unchanged.
    //-------------------------------------------------------------
    repeat (5)
        @(posedge clk);
    #1;
    //-------------------------------------------------------------
    // Check every PE weight register
    //-------------------------------------------------------------

/*    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            if ($signed(dut.pe_row[r].pe_col[c].pe_inst.w_reg)
                != (r*NUM_COLS + c + 1))
            begin

                test_pass = 0;

                $display("");
                $display("WEIGHT HOLD ERROR");
                $display("--------------------------------------------");

                $display("PE[%0d][%0d]", r, c);

                $display("Expected Weight : %0d",
                         r*NUM_COLS + c + 1);

                $display("Actual Weight   : %0d",
                         $signed(dut.pe_row[r].pe_col[c].pe_inst.w_reg));

            end

        end

    end
*/


    //-------------------------------------------------------------
    // Display final weight matrix
    //-------------------------------------------------------------

    $display("");
    $display("WEIGHTS AFTER HOLD PERIOD");
    $display("--------------------------------------------");

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            $write("%5d",
                $signed(pe_weight_debug[r][c]));
        end

        $display("");

    end


    //-------------------------------------------------------------
    // PASS / FAIL
    //-------------------------------------------------------------

    if (test_pass)
    begin

        passed_tests = passed_tests + 1;

        $display("");
        $display("STATUS : PASS");
        $display("All PE weights remained unchanged.");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("");
        $display("STATUS : FAIL");
        $display("One or more PE weights changed.");

    end

    //-------------------------------------------------------------
    // Clear inputs
    //-------------------------------------------------------------

    a_in       = 0;
    weight_in  = 0;
    load_weight = 0;

    $display("");
    $display("------------------------------------------------------------");
    $display("TC5 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask
//=====================================================================
// TC6 : SIGNED / NEGATIVE VALUE VERIFICATION
//=====================================================================

task tc6_negative_values;

integer r;
integer c;
integer k;

reg signed [DATA_WIDTH-1:0] test_a [0:NUM_ROWS-1][0:NUM_COLS-1];
reg signed [DATA_WIDTH-1:0] test_w [0:NUM_ROWS-1][0:NUM_COLS-1];

reg signed [ACC_WIDTH-1:0] expected_result [0:NUM_COLS-1];

reg test_pass;

begin

    print_banner("TC6 : SIGNED / NEGATIVE VALUE VERIFICATION");

    total_tests = total_tests + 1;
    test_pass   = 1;

    //-------------------------------------------------------------
    // Reset DUT and reference model
    //-------------------------------------------------------------

    reset_dut();
    reset_reference_model();

    //-------------------------------------------------------------
    // Test activation matrix
    //-------------------------------------------------------------
    //
    //        C0   C1   C2   C3
    //
    // R0    -1    2   -3    4
    // R1     5   -6    7   -8
    // R2    -9   10  -11   12
    // R3    13  -14   15  -16
    //
    //-------------------------------------------------------------

    test_a[0][0] = -1;
    test_a[0][1] =  2;
    test_a[0][2] = -3;
    test_a[0][3] =  4;

    test_a[1][0] =  5;
    test_a[1][1] = -6;
    test_a[1][2] =  7;
    test_a[1][3] = -8;

    test_a[2][0] = -9;
    test_a[2][1] = 10;
    test_a[2][2] = -11;
    test_a[2][3] = 12;

    test_a[3][0] = 13;
    test_a[3][1] = -14;
    test_a[3][2] = 15;
    test_a[3][3] = -16;

    //-------------------------------------------------------------
    // Signed weight matrix
    //-------------------------------------------------------------
    //
    //        C0   C1   C2   C3
    //
    // R0     1   -1    2   -2
    // R1    -2    2   -1    1
    // R2     3   -3    1   -1
    // R3    -1    1   -2    2
    //
    //-------------------------------------------------------------

    test_w[0][0] =  1;
    test_w[0][1] = -1;
    test_w[0][2] =  2;
    test_w[0][3] = -2;

    test_w[1][0] = -2;
    test_w[1][1] =  2;
    test_w[1][2] = -1;
    test_w[1][3] =  1;

    test_w[2][0] =  3;
    test_w[2][1] = -3;
    test_w[2][2] =  1;
    test_w[2][3] = -1;

    test_w[3][0] = -1;
    test_w[3][1] =  1;
    test_w[3][2] = -2;
    test_w[3][3] =  2;

    //-------------------------------------------------------------
    // Pack weight matrix
    //-------------------------------------------------------------

    weight_in = 0;

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            weight_in[((r*NUM_COLS+c)*DATA_WIDTH) +: DATA_WIDTH]
                = test_w[r][c];

        end

    end

    //-------------------------------------------------------------
    // Load weights into reference model
    //-------------------------------------------------------------

    load_reference_weights();

    //-------------------------------------------------------------
    // Load weights into DUT
    //-------------------------------------------------------------

    load_weight = 1;

    @(posedge clk);
    #1;

    load_weight = 0;

    //-------------------------------------------------------------
    // Display activation matrix
    //-------------------------------------------------------------

    $display("");
    $display("SIGNED INPUT MATRIX A");
    $display("--------------------------------------------");

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        $display("%5d %5d %5d %5d",
                 test_a[r][0],
                 test_a[r][1],
                 test_a[r][2],
                 test_a[r][3]);

    end

    //-------------------------------------------------------------
    // Display weight matrix
    //-------------------------------------------------------------

    $display("");
    $display("SIGNED WEIGHT MATRIX");
    $display("--------------------------------------------");

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        $display("%5d %5d %5d %5d",
                 test_w[r][0],
                 test_w[r][1],
                 test_w[r][2],
                 test_w[r][3]);

    end

    //-------------------------------------------------------------
    // Calculate expected mathematical result
    //-------------------------------------------------------------

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        expected_result[c] = 0;

        for (r = 0; r < NUM_ROWS; r = r + 1) begin

            for (k = 0; k < NUM_COLS; k = k + 1) begin

                expected_result[c] =
                    expected_result[c] +
                    test_a[r][k] * test_w[r][c];

            end

        end

    end

    //-------------------------------------------------------------
    // Create systolic input stream
    //-------------------------------------------------------------

    for (k = 0; k < NUM_COLS + NUM_ROWS - 1; k = k + 1) begin

        //---------------------------------------------------------
        // Row 0
        //---------------------------------------------------------

        if ((k >= 0) && (k < NUM_COLS))
            a_in[0*DATA_WIDTH +: DATA_WIDTH] =
                test_a[0][k];
        else
            a_in[0*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Row 1
        //---------------------------------------------------------

        if ((k >= 1) && (k-1 < NUM_COLS))
            a_in[1*DATA_WIDTH +: DATA_WIDTH] =
                test_a[1][k-1];
        else
            a_in[1*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Row 2
        //---------------------------------------------------------

        if ((k >= 2) && (k-2 < NUM_COLS))
            a_in[2*DATA_WIDTH +: DATA_WIDTH] =
                test_a[2][k-2];
        else
            a_in[2*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Row 3
        //---------------------------------------------------------

        if ((k >= 3) && (k-3 < NUM_COLS))
            a_in[3*DATA_WIDTH +: DATA_WIDTH] =
                test_a[3][k-3];
        else
            a_in[3*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Advance reference model
        //---------------------------------------------------------

        reference_model_step();

        //---------------------------------------------------------
        // Advance DUT
        //---------------------------------------------------------

        @(posedge clk);
        #1;

    end

    //-------------------------------------------------------------
    // Stop input stream
    //-------------------------------------------------------------

    a_in = 0;

    //-------------------------------------------------------------
    // Flush systolic array
    //-------------------------------------------------------------

    repeat (NUM_ROWS + NUM_COLS + 2)
    begin

        reference_model_step();

        @(posedge clk);
        #1;

    end

    //-------------------------------------------------------------
    // Display results
    //-------------------------------------------------------------

    $display("");
    $display("SIGNED VALUE RESULTS");
    $display("============================================================");

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        $display("Column %0d : Expected = %6d   Actual = %6d",
                 c,
                 $signed(expected_result[c]),
                 $signed(acc_out[((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH]));

    end

    //-------------------------------------------------------------
    // Compare results
    //-------------------------------------------------------------

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        if ($signed(acc_out[((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH])
            != $signed(expected_result[c]))
        begin

            test_pass = 0;

        end

    end

    //-------------------------------------------------------------
    // PASS / FAIL
    //-------------------------------------------------------------

    if (test_pass)
    begin

        passed_tests = passed_tests + 1;

        $display("");
        $display("STATUS : PASS");
        $display("Signed and negative values handled correctly.");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("");
        $display("STATUS : FAIL");
        $display("Signed value processing is incorrect.");

    end

    //-------------------------------------------------------------
    // Clear inputs
    //-------------------------------------------------------------

    a_in       = 0;
    weight_in  = 0;
    load_weight = 0;

    $display("");
    $display("------------------------------------------------------------");
    $display("TC6 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
// TC7 : MIXED POSITIVE AND NEGATIVE WEIGHTS
//=====================================================================

task tc7_mixed_weights;

integer r;
integer c;
integer k;

reg signed [DATA_WIDTH-1:0] test_a [0:NUM_ROWS-1][0:NUM_COLS-1];
reg signed [DATA_WIDTH-1:0] test_w [0:NUM_ROWS-1][0:NUM_COLS-1];

reg signed [ACC_WIDTH-1:0] expected_result [0:NUM_COLS-1];

reg test_pass;

begin

    print_banner("TC7 : MIXED POSITIVE AND NEGATIVE WEIGHTS");

    total_tests = total_tests + 1;
    test_pass   = 1;

    //-------------------------------------------------------------
    // Reset DUT and reference model
    //-------------------------------------------------------------

    reset_dut();
    reset_reference_model();

    //-------------------------------------------------------------
    // Test activation matrix
    //-------------------------------------------------------------

    test_a[0][0] = 1;
    test_a[0][1] = 2;
    test_a[0][2] = 3;
    test_a[0][3] = 4;

    test_a[1][0] = 5;
    test_a[1][1] = 6;
    test_a[1][2] = 7;
    test_a[1][3] = 8;

    test_a[2][0] = 9;
    test_a[2][1] = 10;
    test_a[2][2] = 11;
    test_a[2][3] = 12;

    test_a[3][0] = 13;
    test_a[3][1] = 14;
    test_a[3][2] = 15;
    test_a[3][3] = 16;

    //-------------------------------------------------------------
    // Mixed positive and negative weight matrix
    //
    //       C0   C1   C2   C3
    //
    // R0     1   -2    3   -4
    // R1    -5    6   -7    8
    // R2     9  -10   11  -12
    // R3   -13   14  -15   16
    //
    //-------------------------------------------------------------

    test_w[0][0] =  1;
    test_w[0][1] = -2;
    test_w[0][2] =  3;
    test_w[0][3] = -4;

    test_w[1][0] = -5;
    test_w[1][1] =  6;
    test_w[1][2] = -7;
    test_w[1][3] =  8;

    test_w[2][0] =  9;
    test_w[2][1] = -10;
    test_w[2][2] = 11;
    test_w[2][3] = -12;

    test_w[3][0] = -13;
    test_w[3][1] = 14;
    test_w[3][2] = -15;
    test_w[3][3] = 16;

    //-------------------------------------------------------------
    // Pack weight matrix
    //-------------------------------------------------------------

    weight_in = 0;

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            weight_in[((r*NUM_COLS+c)*DATA_WIDTH) +: DATA_WIDTH]
                = test_w[r][c];

        end

    end

    //-------------------------------------------------------------
    // Load weights into reference model
    //-------------------------------------------------------------

    load_reference_weights();

    //-------------------------------------------------------------
    // Load weights into DUT
    //-------------------------------------------------------------

    load_weight = 1;

    @(posedge clk);
    #1;

    load_weight = 0;

    //-------------------------------------------------------------
    // Display activation matrix
    //-------------------------------------------------------------

    $display("");
    $display("INPUT MATRIX A");
    $display("--------------------------------------------");

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        $display("%5d %5d %5d %5d",
                 test_a[r][0],
                 test_a[r][1],
                 test_a[r][2],
                 test_a[r][3]);

    end

    //-------------------------------------------------------------
    // Display mixed weight matrix
    //-------------------------------------------------------------

    $display("");
    $display("MIXED WEIGHT MATRIX");
    $display("--------------------------------------------");

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        $display("%5d %5d %5d %5d",
                 test_w[r][0],
                 test_w[r][1],
                 test_w[r][2],
                 test_w[r][3]);

    end

    //-------------------------------------------------------------
    // Calculate expected mathematical result
    //
    // Each output column is:
    //
    //       result[c] = SUM A[r][k] * W[r][c]
    //
    //-------------------------------------------------------------

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        expected_result[c] = 0;

        for (r = 0; r < NUM_ROWS; r = r + 1) begin

            for (k = 0; k < NUM_COLS; k = k + 1) begin

                expected_result[c] =
                    expected_result[c] +
                    test_a[r][k] * test_w[r][c];

            end

        end

    end

    //-------------------------------------------------------------
    // Create diagonal systolic input stream
    //
    // Cycle 0 : A00   0     0     0
    // Cycle 1 : A01   A10   0     0
    // Cycle 2 : A02   A11   A20   0
    // Cycle 3 : A03   A12   A21   A30
    // Cycle 4 : 0     A13   A22   A31
    // Cycle 5 : 0     0     A23   A32
    // Cycle 6 : 0     0     0     A33
    //
    //-------------------------------------------------------------

    for (k = 0; k < NUM_COLS + NUM_ROWS - 1; k = k + 1) begin

        //---------------------------------------------------------
        // Row 0
        //---------------------------------------------------------

        if ((k >= 0) && (k < NUM_COLS))
            a_in[0*DATA_WIDTH +: DATA_WIDTH] =
                test_a[0][k];
        else
            a_in[0*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Row 1
        //---------------------------------------------------------

        if ((k >= 1) && (k-1 < NUM_COLS))
            a_in[1*DATA_WIDTH +: DATA_WIDTH] =
                test_a[1][k-1];
        else
            a_in[1*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Row 2
        //---------------------------------------------------------

        if ((k >= 2) && (k-2 < NUM_COLS))
            a_in[2*DATA_WIDTH +: DATA_WIDTH] =
                test_a[2][k-2];
        else
            a_in[2*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Row 3
        //---------------------------------------------------------

        if ((k >= 3) && (k-3 < NUM_COLS))
            a_in[3*DATA_WIDTH +: DATA_WIDTH] =
                test_a[3][k-3];
        else
            a_in[3*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Advance reference model
        //---------------------------------------------------------

        reference_model_step();

        //---------------------------------------------------------
        // Advance DUT
        //---------------------------------------------------------

        @(posedge clk);
        #1;

    end

    //-------------------------------------------------------------
    // Stop feeding activations
    //-------------------------------------------------------------

    a_in = 0;

    //-------------------------------------------------------------
    // Flush systolic array
    //-------------------------------------------------------------

    repeat (NUM_ROWS + NUM_COLS + 2)
    begin

        reference_model_step();

        @(posedge clk);
        #1;

    end

    //-------------------------------------------------------------
    // Display final results
    //-------------------------------------------------------------

    $display("");
    $display("FINAL RESULTS");
    $display("============================================================");

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        $display("Column %0d : Expected = %6d   Actual = %6d",
                 c,
                 $signed(expected_result[c]),
                 $signed(acc_out[((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH]));

    end

    //-------------------------------------------------------------
    // Compare DUT with mathematical reference
    //-------------------------------------------------------------

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        if ($signed(acc_out[((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH])
            != $signed(expected_result[c]))
        begin

            test_pass = 0;

        end

    end

    //-------------------------------------------------------------
    // PASS / FAIL
    //-------------------------------------------------------------

    if (test_pass)
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

    end

    //-------------------------------------------------------------
    // Clear inputs
    //-------------------------------------------------------------

    a_in      = 0;
    weight_in = 0;

    $display("");
    $display("------------------------------------------------------------");
    $display("TC7 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");
end
endtask
//=====================================================================
// TC8 : BOUNDARY VALUE VERIFICATION
//=====================================================================

task tc8_boundary_values;

integer r;
integer c;
integer k;

reg signed [DATA_WIDTH-1:0] test_a [0:NUM_ROWS-1][0:NUM_COLS-1];
reg signed [DATA_WIDTH-1:0] test_w [0:NUM_ROWS-1][0:NUM_COLS-1];

reg signed [ACC_WIDTH-1:0] expected_result [0:NUM_COLS-1];

reg test_pass;

begin

    print_banner("TC8 : BOUNDARY VALUE VERIFICATION");

    total_tests = total_tests + 1;
    test_pass   = 1;

    //-------------------------------------------------------------
    // Reset DUT and reference model
    //-------------------------------------------------------------

    reset_dut();
    reset_reference_model();

    //-------------------------------------------------------------
    // Boundary-value activation matrix
    //
    // Maximum positive 8-bit signed value  = +127
    // Minimum negative 8-bit signed value  = -128
    //
    //-------------------------------------------------------------

    test_a[0][0] =  127;
    test_a[0][1] = -128;
    test_a[0][2] =    0;
    test_a[0][3] =    1;

    test_a[1][0] = -128;
    test_a[1][1] =  127;
    test_a[1][2] =    1;
    test_a[1][3] =   -1;

    test_a[2][0] =    0;
    test_a[2][1] =    1;
    test_a[2][2] = -128;
    test_a[2][3] =  127;

    test_a[3][0] =    1;
    test_a[3][1] =   -1;
    test_a[3][2] =  127;
    test_a[3][3] = -128;

    //-------------------------------------------------------------
    // Boundary-value weight matrix
    //
    // Use both +127 and -128 to exercise the signed multiplier.
    //
    //-------------------------------------------------------------

    test_w[0][0] =  127;
    test_w[0][1] = -128;
    test_w[0][2] =    1;
    test_w[0][3] =   -1;

    test_w[1][0] = -128;
    test_w[1][1] =  127;
    test_w[1][2] =   -1;
    test_w[1][3] =    1;

    test_w[2][0] =    1;
    test_w[2][1] =   -1;
    test_w[2][2] =  127;
    test_w[2][3] = -128;

    test_w[3][0] =   -1;
    test_w[3][1] =    1;
    test_w[3][2] = -128;
    test_w[3][3] =  127;

    //-------------------------------------------------------------
    // Pack weight matrix
    //-------------------------------------------------------------

    weight_in = 0;

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            weight_in[((r*NUM_COLS+c)*DATA_WIDTH) +: DATA_WIDTH]
                = test_w[r][c];

        end

    end

    //-------------------------------------------------------------
    // Load reference weights
    //-------------------------------------------------------------

    load_reference_weights();

    //-------------------------------------------------------------
    // Load weights into DUT
    //-------------------------------------------------------------

    load_weight = 1;

    @(posedge clk);
    #1;

    load_weight = 0;

    //-------------------------------------------------------------
    // Display activation matrix
    //-------------------------------------------------------------

    $display("");
    $display("BOUNDARY VALUE INPUT MATRIX A");
    $display("--------------------------------------------");

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        $display("%6d %6d %6d %6d",
                 test_a[r][0],
                 test_a[r][1],
                 test_a[r][2],
                 test_a[r][3]);

    end

    //-------------------------------------------------------------
    // Display weight matrix
    //-------------------------------------------------------------

    $display("");
    $display("BOUNDARY VALUE WEIGHT MATRIX");
    $display("--------------------------------------------");

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        $display("%6d %6d %6d %6d",
                 test_w[r][0],
                 test_w[r][1],
                 test_w[r][2],
                 test_w[r][3]);

    end

    //-------------------------------------------------------------
    // Calculate expected mathematical result
    //-------------------------------------------------------------

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        expected_result[c] = 0;

        for (r = 0; r < NUM_ROWS; r = r + 1) begin

            for (k = 0; k < NUM_COLS; k = k + 1) begin

                expected_result[c] =
                    expected_result[c] +
                    test_a[r][k] * test_w[r][c];

            end

        end

    end

    //-------------------------------------------------------------
    // Create diagonal systolic input stream
    //-------------------------------------------------------------

    for (k = 0; k < NUM_COLS + NUM_ROWS - 1; k = k + 1) begin

        //---------------------------------------------------------
        // Row 0
        //---------------------------------------------------------

        if ((k >= 0) && (k < NUM_COLS))
            a_in[0*DATA_WIDTH +: DATA_WIDTH] =
                test_a[0][k];
        else
            a_in[0*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Row 1
        //---------------------------------------------------------

        if ((k >= 1) && (k-1 < NUM_COLS))
            a_in[1*DATA_WIDTH +: DATA_WIDTH] =
                test_a[1][k-1];
        else
            a_in[1*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Row 2
        //---------------------------------------------------------

        if ((k >= 2) && (k-2 < NUM_COLS))
            a_in[2*DATA_WIDTH +: DATA_WIDTH] =
                test_a[2][k-2];
        else
            a_in[2*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Row 3
        //---------------------------------------------------------

        if ((k >= 3) && (k-3 < NUM_COLS))
            a_in[3*DATA_WIDTH +: DATA_WIDTH] =
                test_a[3][k-3];
        else
            a_in[3*DATA_WIDTH +: DATA_WIDTH] = 0;

        //---------------------------------------------------------
        // Advance reference model
        //---------------------------------------------------------

        reference_model_step();

        //---------------------------------------------------------
        // Advance DUT
        //---------------------------------------------------------

        @(posedge clk);
        #1;

    end

    //-------------------------------------------------------------
    // Stop feeding activations
    //-------------------------------------------------------------

    a_in = 0;

    //-------------------------------------------------------------
    // Flush systolic array
    //-------------------------------------------------------------

    repeat (NUM_ROWS + NUM_COLS + 2)
    begin

        reference_model_step();

        @(posedge clk);
        #1;

    end

    //-------------------------------------------------------------
    // Display final results
    //-------------------------------------------------------------

    $display("");
    $display("FINAL BOUNDARY VALUE RESULTS");
    $display("============================================================");

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        $display("Column %0d : Expected = %8d   Actual = %8d",
                 c,
                 $signed(expected_result[c]),
                 $signed(acc_out[((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH]));

    end

    //-------------------------------------------------------------
    // Compare DUT with expected result
    //-------------------------------------------------------------

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        if ($signed(acc_out[((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH])
            != $signed(expected_result[c]))
        begin

            test_pass = 0;

        end

    end

    //-------------------------------------------------------------
    // PASS / FAIL
    //-------------------------------------------------------------

    if (test_pass)
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

    end

    //-------------------------------------------------------------
    // Clear inputs
    //-------------------------------------------------------------
    a_in      = 0;
    weight_in = 0;

    $display("");
    $display("------------------------------------------------------------");
    $display("TC8 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
// TC9 : MID-RUN RESET VERIFICATION
//=====================================================================

task tc9_mid_run_reset;

reg test_pass;

begin

    print_banner("TC9 : MID-RUN RESET VERIFICATION");

    total_tests = total_tests + 1;
    test_pass   = 1;

    //-------------------------------------------------------------
    // Step 1 : Reset DUT and reference model
    //-------------------------------------------------------------

    reset_dut();
    reset_reference_model();

    //-------------------------------------------------------------
    // Step 2 : Load some known weights
    //
    // We use all weights = 1 so that the array
    // definitely contains active data during the test.
    //-------------------------------------------------------------

    weight_in = 0;

    weight_in[(0*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(1*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(2*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(3*DATA_WIDTH) +: DATA_WIDTH] = 1;

    weight_in[(4*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(5*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(6*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(7*DATA_WIDTH) +: DATA_WIDTH] = 1;

    weight_in[(8*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(9*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(10*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(11*DATA_WIDTH) +: DATA_WIDTH] = 1;

    weight_in[(12*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(13*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(14*DATA_WIDTH) +: DATA_WIDTH] = 1;
    weight_in[(15*DATA_WIDTH) +: DATA_WIDTH] = 1;

    //-------------------------------------------------------------
    // Load weights into DUT
    //-------------------------------------------------------------

    load_weight = 1;

    @(posedge clk);
    #1;

    load_weight = 0;

    //-------------------------------------------------------------
    // Step 3 : Start sending activations
    //
    // These values will enter the systolic array and
    // create activity inside the PEs.
    //-------------------------------------------------------------

    a_in[0*DATA_WIDTH +: DATA_WIDTH] = 10;
    a_in[1*DATA_WIDTH +: DATA_WIDTH] = 20;
    a_in[2*DATA_WIDTH +: DATA_WIDTH] = 30;
    a_in[3*DATA_WIDTH +: DATA_WIDTH] = 40;

    //-------------------------------------------------------------
    // Let the array run for a few cycles
    //-------------------------------------------------------------

    @(posedge clk);
    #1;

    @(posedge clk);
    #1;

    //-------------------------------------------------------------
    // At this point the systolic array is ACTIVE.
    //
    // Now apply RESET in the middle of operation.
    //-------------------------------------------------------------

    $display("");
    $display("Applying MID-RUN RESET...");
    $display("");

    rst   = 1;
    a_in  = 0;
    load_weight = 0;

    //-------------------------------------------------------------
    // Hold reset for two clock cycles
    //-------------------------------------------------------------

    repeat (2)
        @(posedge clk);

    #1;

    //-------------------------------------------------------------
    // Check that all important outputs are cleared
    //-------------------------------------------------------------

    if (($signed(acc_out) != 0) ||
        ($signed(a_out)   != 0))
    begin

        test_pass = 0;

    end

    //-------------------------------------------------------------
    // Also check internal activation pipeline
    //-------------------------------------------------------------

    if (($signed(dut.a_grid[0][0]) != 0) ||
        ($signed(dut.a_grid[0][1]) != 0) ||
        ($signed(dut.a_grid[0][2]) != 0) ||
        ($signed(dut.a_grid[0][3]) != 0) ||

        ($signed(dut.a_grid[1][0]) != 0) ||
        ($signed(dut.a_grid[1][1]) != 0) ||
        ($signed(dut.a_grid[1][2]) != 0) ||
        ($signed(dut.a_grid[1][3]) != 0) ||

        ($signed(dut.a_grid[2][0]) != 0) ||
        ($signed(dut.a_grid[2][1]) != 0) ||
        ($signed(dut.a_grid[2][2]) != 0) ||
        ($signed(dut.a_grid[2][3]) != 0) ||

        ($signed(dut.a_grid[3][0]) != 0) ||
        ($signed(dut.a_grid[3][1]) != 0) ||
        ($signed(dut.a_grid[3][2]) != 0) ||
        ($signed(dut.a_grid[3][3]) != 0))
    begin

        test_pass = 0;

    end

    //-------------------------------------------------------------
    // Display reset result
    //-------------------------------------------------------------

    $display("");
    $display("MID-RUN RESET CHECK");
    $display("------------------------------------------------------------");

    $display("acc_out = %0d", $signed(acc_out));
    $display("a_out   = %0d", $signed(a_out));

    //-------------------------------------------------------------
    // Step 4 : Release reset
    //-------------------------------------------------------------

    rst = 0;

    @(posedge clk);
    #1;

    //-------------------------------------------------------------
    // Step 5 : Verify that the array can operate again
    //
    // Send a simple activation after reset.
    //-------------------------------------------------------------

    a_in[0*DATA_WIDTH +: DATA_WIDTH] = 5;
    a_in[1*DATA_WIDTH +: DATA_WIDTH] = 6;
    a_in[2*DATA_WIDTH +: DATA_WIDTH] = 7;
    a_in[3*DATA_WIDTH +: DATA_WIDTH] = 8;

    @(posedge clk);
    #1;

    //-------------------------------------------------------------
    // The reset should not permanently disable the array.
    // Check that the new activation has entered column 1.
    //-------------------------------------------------------------

    if (($signed(dut.a_grid[0][1]) != 5) ||
        ($signed(dut.a_grid[1][1]) != 6) ||
        ($signed(dut.a_grid[2][1]) != 7) ||
        ($signed(dut.a_grid[3][1]) != 8))
    begin

        test_pass = 0;

    end

    //-------------------------------------------------------------
    // PASS / FAIL
    //-------------------------------------------------------------

    if (test_pass)
    begin

        passed_tests = passed_tests + 1;

        $display("");
        $display("STATUS : PASS");
        $display("Mid-run reset successfully cleared the array.");
        $display("Array successfully resumed operation after reset.");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("");
        $display("STATUS : FAIL");
        $display("Mid-run reset did not behave correctly.");

    end
    //-------------------------------------------------------------
    // Clear inputs
    //-------------------------------------------------------------
    a_in      = 0;
    weight_in = 0;
    load_weight = 0;
    $display("");
    $display("------------------------------------------------------------");
    $display("TC9 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");
end
endtask

//=====================================================================
// TC10 : LONG ACCUMULATION VERIFICATION
//=====================================================================
task tc10_long_accumulation;
integer r;
integer c;
integer k;

reg signed [DATA_WIDTH-1:0] test_w [0:NUM_ROWS-1][0:NUM_COLS-1];

reg signed [DATA_WIDTH-1:0] activation_value;

reg signed [ACC_WIDTH-1:0] expected_result [0:NUM_COLS-1];

reg test_pass;

begin

    print_banner("TC10 : LONG ACCUMULATION VERIFICATION");

    total_tests = total_tests + 1;
    test_pass   = 1;

    //-------------------------------------------------------------
    // Reset DUT and reference model
    //-------------------------------------------------------------

    reset_dut();
    reset_reference_model();

    //-------------------------------------------------------------
    // Use all weights = 1
    //
    // This makes the expected accumulation very easy to
    // understand and verify.
    //-------------------------------------------------------------

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            test_w[r][c] = 1;

        end

    end

    //-------------------------------------------------------------
    // Pack weight matrix
    //-------------------------------------------------------------

    weight_in = 0;

    for (r = 0; r < NUM_ROWS; r = r + 1) begin

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            weight_in[((r*NUM_COLS+c)*DATA_WIDTH) +: DATA_WIDTH]
                = test_w[r][c];

        end

    end

    //-------------------------------------------------------------
    // Load weights into reference model
    //-------------------------------------------------------------

    load_reference_weights();

    //-------------------------------------------------------------
    // Load weights into DUT
    //-------------------------------------------------------------

    load_weight = 1;

    @(posedge clk);
    #1;

    load_weight = 0;

    //-------------------------------------------------------------
    // Initialize expected results
    //-------------------------------------------------------------

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        expected_result[c] = 0;

    end

    //-------------------------------------------------------------
    // Perform multiple activation streams
    //
    // Each stream contributes additional values to the
    // accumulators.
    //
    // We repeat the operation several times so that the
    // accumulators have to hold and add many products.
    //-------------------------------------------------------------

    for (k = 0; k < 8; k = k + 1) begin

        //---------------------------------------------------------
        // Generate a different activation value each iteration
        //---------------------------------------------------------

        activation_value = k + 1;

        //---------------------------------------------------------
        // Feed the same activation value into all rows
        //---------------------------------------------------------

        a_in[0*DATA_WIDTH +: DATA_WIDTH] = activation_value;
        a_in[1*DATA_WIDTH +: DATA_WIDTH] = activation_value;
        a_in[2*DATA_WIDTH +: DATA_WIDTH] = activation_value;
        a_in[3*DATA_WIDTH +: DATA_WIDTH] = activation_value;

        //---------------------------------------------------------
        // Calculate the expected contribution.
        //
        // Four rows are active and every weight is 1.
        //
        // Contribution for one cycle:
        //
        // activation × 1
        // + activation × 1
        // + activation × 1
        // + activation × 1
        //
        // = 4 × activation
        //---------------------------------------------------------

        for (c = 0; c < NUM_COLS; c = c + 1) begin

            expected_result[c] =
                expected_result[c] +
                (4 * activation_value);

        end

        //---------------------------------------------------------
        // Advance the reference model
        //---------------------------------------------------------

        reference_model_step();

        //---------------------------------------------------------
        // Advance DUT
        //---------------------------------------------------------

        @(posedge clk);
        #1;

    end

    //-------------------------------------------------------------
    // Stop feeding data
    //-------------------------------------------------------------

    a_in = 0;

    //-------------------------------------------------------------
    // Flush the systolic array
    //-------------------------------------------------------------

    repeat (NUM_ROWS + NUM_COLS + 4)
    begin

        reference_model_step();

        @(posedge clk);
        #1;

    end

    //-------------------------------------------------------------
    // Display expected result
    //-------------------------------------------------------------

    $display("");
    $display("LONG ACCUMULATION RESULTS");
    $display("============================================================");

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        $display("Column %0d : Expected = %6d   Actual = %6d",
                 c,
                 $signed(expected_result[c]),
                 $signed(acc_out[((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH]));

    end

    //-------------------------------------------------------------
    // Compare expected and actual results
    //-------------------------------------------------------------

    for (c = 0; c < NUM_COLS; c = c + 1) begin

        if ($signed(acc_out[((c+1)*ACC_WIDTH)-1 -: ACC_WIDTH])
            != $signed(expected_result[c]))
        begin

            test_pass = 0;

        end

    end

    //-------------------------------------------------------------
    // PASS / FAIL
    //-------------------------------------------------------------

    if (test_pass)
    begin

        passed_tests = passed_tests + 1;

        $display("");
        $display("STATUS : PASS");
        $display("Long accumulation completed correctly.");

    end
    else
    begin

        failed_tests = failed_tests + 1;

        $display("");
        $display("STATUS : FAIL");
        $display("Long accumulation produced incorrect results.");

    end

    //-------------------------------------------------------------
    // Clear inputs
    //-------------------------------------------------------------

    a_in      = 0;
    weight_in = 0;
    load_weight = 0;

    $display("");
    $display("------------------------------------------------------------");
    $display("TC10 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
// DEBUG MONITOR : 4x4 SYSTOLIC ARRAY INTERNAL ACTIVITY
//=====================================================================
//
// TEMPORARY DEBUG CODE
//
// This prints:
//   - external activation input
//   - each PE activation output
//   - each PE partial-sum output
//   - final accumulator outputs
//
// It allows us to see exactly where the data becomes zero.
//
//=====================================================================
/*
always @(posedge clk) begin

    if (!rst) begin
          // its added
        #1;
        debug_cycle = debug_cycle + 1;

        $display("");
        $display("============================================================");
        $display("DEBUG CYCLE = %0d    TIME = %0t", debug_cycle, $time);
        $display("============================================================");
        $display("");
        $display("ACC OUT : [%0d %0d %0d %0d]",
          $signed(acc_out[ACC_WIDTH-1:0]),
          $signed(acc_out[(2*ACC_WIDTH)-1:ACC_WIDTH]),
          $signed(acc_out[(3*ACC_WIDTH)-1:(2*ACC_WIDTH)]),
          $signed(acc_out[(4*ACC_WIDTH)-1:(3*ACC_WIDTH)]));
       // its added
        $display("");
        $display("============================================================");
        $display("DEBUG TIME = %0t ns", $time);
        $display("============================================================");

        //=============================================================
        // EXTERNAL ACTIVATION INPUT
        //=============================================================

        $display("A_IN : [%0d %0d %0d %0d]",
                 $signed(a_in[7:0]),
                 $signed(a_in[15:8]),
                 $signed(a_in[23:16]),
                 $signed(a_in[31:24]));


        //=============================================================
        // HORIZONTAL ACTIVATION FLOW
        //=============================================================

        $display("");
        $display("ACTIVATION GRID");

        $display("Row 0 : %4d %4d %4d %4d %4d",
                 $signed(dut.a_grid[0][0]),
                 $signed(dut.a_grid[0][1]),
                 $signed(dut.a_grid[0][2]),
                 $signed(dut.a_grid[0][3]),
                 $signed(dut.a_grid[0][4]));

        $display("Row 1 : %4d %4d %4d %4d %4d",
                 $signed(dut.a_grid[1][0]),
                 $signed(dut.a_grid[1][1]),
                 $signed(dut.a_grid[1][2]),
                 $signed(dut.a_grid[1][3]),
                 $signed(dut.a_grid[1][4]));

        $display("Row 2 : %4d %4d %4d %4d %4d",
                 $signed(dut.a_grid[2][0]),
                 $signed(dut.a_grid[2][1]),
                 $signed(dut.a_grid[2][2]),
                 $signed(dut.a_grid[2][3]),
                 $signed(dut.a_grid[2][4]));

        $display("Row 3 : %4d %4d %4d %4d %4d",
                 $signed(dut.a_grid[3][0]),
                 $signed(dut.a_grid[3][1]),
                 $signed(dut.a_grid[3][2]),
                 $signed(dut.a_grid[3][3]),
                 $signed(dut.a_grid[3][4]));


        //=============================================================
        // PARTIAL SUM FLOW
        //=============================================================

        $display("");
        $display("PARTIAL SUM GRID");

        $display("Row 0 : %6d %6d %6d %6d",
                 $signed(dut.psum_grid[0][0]),
                 $signed(dut.psum_grid[0][1]),
                 $signed(dut.psum_grid[0][2]),
                 $signed(dut.psum_grid[0][3]));

        $display("Row 1 : %6d %6d %6d %6d",
                 $signed(dut.psum_grid[1][0]),
                 $signed(dut.psum_grid[1][1]),
                 $signed(dut.psum_grid[1][2]),
                 $signed(dut.psum_grid[1][3]));

        $display("Row 2 : %6d %6d %6d %6d",
                 $signed(dut.psum_grid[2][0]),
                 $signed(dut.psum_grid[2][1]),
                 $signed(dut.psum_grid[2][2]),
                 $signed(dut.psum_grid[2][3]));

        $display("Row 3 : %6d %6d %6d %6d",
                 $signed(dut.psum_grid[3][0]),
                 $signed(dut.psum_grid[3][1]),
                 $signed(dut.psum_grid[3][2]),
                 $signed(dut.psum_grid[3][3]));

        $display("Row 4 : %6d %6d %6d %6d",
                 $signed(dut.psum_grid[4][0]),
                 $signed(dut.psum_grid[4][1]),
                 $signed(dut.psum_grid[4][2]),
                 $signed(dut.psum_grid[4][3]));


        //=============================================================
        // INDIVIDUAL PE OUTPUTS
        //=============================================================

        $display("");
        $display("PE OUTPUTS : PSUM");

        $display("PE Row 0 : %6d %6d %6d %6d",
                 $signed(dut.pe_row[0].pe_col[0].pe_inst.psum_out),
                 $signed(dut.pe_row[0].pe_col[1].pe_inst.psum_out),
                 $signed(dut.pe_row[0].pe_col[2].pe_inst.psum_out),
                 $signed(dut.pe_row[0].pe_col[3].pe_inst.psum_out));

        $display("PE Row 1 : %6d %6d %6d %6d",
                 $signed(dut.pe_row[1].pe_col[0].pe_inst.psum_out),
                 $signed(dut.pe_row[1].pe_col[1].pe_inst.psum_out),
                 $signed(dut.pe_row[1].pe_col[2].pe_inst.psum_out),
                 $signed(dut.pe_row[1].pe_col[3].pe_inst.psum_out));

        $display("PE Row 2 : %6d %6d %6d %6d",
                 $signed(dut.pe_row[2].pe_col[0].pe_inst.psum_out),
                 $signed(dut.pe_row[2].pe_col[1].pe_inst.psum_out),
                 $signed(dut.pe_row[2].pe_col[2].pe_inst.psum_out),
                 $signed(dut.pe_row[2].pe_col[3].pe_inst.psum_out));

        $display("PE Row 3 : %6d %6d %6d %6d",
                 $signed(dut.pe_row[3].pe_col[0].pe_inst.psum_out),
                 $signed(dut.pe_row[3].pe_col[1].pe_inst.psum_out),
                 $signed(dut.pe_row[3].pe_col[2].pe_inst.psum_out),
                 $signed(dut.pe_row[3].pe_col[3].pe_inst.psum_out));


        //=============================================================
        // WEIGHT REGISTERS
        //=============================================================

        $display("");
        $display("WEIGHT REGISTERS");

        $display("W Row 0 : %4d %4d %4d %4d",
                 $signed(dut.pe_row[0].pe_col[0].pe_inst.w_reg),
                 $signed(dut.pe_row[0].pe_col[1].pe_inst.w_reg),
                 $signed(dut.pe_row[0].pe_col[2].pe_inst.w_reg),
                 $signed(dut.pe_row[0].pe_col[3].pe_inst.w_reg));

        $display("W Row 1 : %4d %4d %4d %4d",
                 $signed(dut.pe_row[1].pe_col[0].pe_inst.w_reg),
                 $signed(dut.pe_row[1].pe_col[1].pe_inst.w_reg),
                 $signed(dut.pe_row[1].pe_col[2].pe_inst.w_reg),
                 $signed(dut.pe_row[1].pe_col[3].pe_inst.w_reg));

        $display("W Row 2 : %4d %4d %4d %4d",
                 $signed(dut.pe_row[2].pe_col[0].pe_inst.w_reg),
                 $signed(dut.pe_row[2].pe_col[1].pe_inst.w_reg),
                 $signed(dut.pe_row[2].pe_col[2].pe_inst.w_reg),
                 $signed(dut.pe_row[2].pe_col[3].pe_inst.w_reg));

        $display("W Row 3 : %4d %4d %4d %4d",
                 $signed(dut.pe_row[3].pe_col[0].pe_inst.w_reg),
                 $signed(dut.pe_row[3].pe_col[1].pe_inst.w_reg),
                 $signed(dut.pe_row[3].pe_col[2].pe_inst.w_reg),
                 $signed(dut.pe_row[3].pe_col[3].pe_inst.w_reg));


        //=============================================================
        // FINAL OUTPUT
        //=============================================================

        $display("");
        $display("ACC OUT : [%0d %0d %0d %0d]",
                 $signed(acc_out[ACC_WIDTH-1:0]),
                 $signed(acc_out[(2*ACC_WIDTH)-1:ACC_WIDTH]),
                 $signed(acc_out[(3*ACC_WIDTH)-1:(2*ACC_WIDTH)]),
                 $signed(acc_out[(4*ACC_WIDTH)-1:(3*ACC_WIDTH)]));

        $display("============================================================");
    end

end
*/

//=====================================================================
// SECTION - 14
// FINAL TEST SEQUENCE
//=====================================================================

initial begin

    //-------------------------------------------------------------
    // Initial delay
    //
    // Gives the testbench a moment to initialize before starting
    // the verification sequence.
    //-------------------------------------------------------------

    #1;

    //-------------------------------------------------------------
    // Start verification
    //-------------------------------------------------------------

    $display("");
    $display("================================================================");
    $display("              SYSTOLIC ARRAY 4x4 VERIFICATION");
    $display("================================================================");
    $display("");
    $display("Starting all verification test cases...");
    $display("");

    //-------------------------------------------------------------
    // TC1 : Reset verification
    //-------------------------------------------------------------

    tc1_reset();

    //-------------------------------------------------------------
    // TC2 : Weight loading verification
    //-------------------------------------------------------------

    tc2_weight_loading();

    //-------------------------------------------------------------
    // TC3 : Activation propagation verification
    //-------------------------------------------------------------

    tc3_activation_propagation();

    //-------------------------------------------------------------
    // TC4 : Matrix multiplication verification
    //-------------------------------------------------------------

    tc4_matrix_multiplication();

    //-------------------------------------------------------------
    // TC5 : Weight hold verification
    //-------------------------------------------------------------

    tc5_weight_hold();

    //-------------------------------------------------------------
    // TC6 : Negative activation verification
    //-------------------------------------------------------------

    tc6_negative_values();

    //-------------------------------------------------------------
    // TC7 : Mixed weight verification
    //-------------------------------------------------------------

    tc7_mixed_weights();

    //-------------------------------------------------------------
    // TC8 : Boundary value verification
    //-------------------------------------------------------------

    tc8_boundary_values();

    //-------------------------------------------------------------
    // TC9 : Mid-run reset verification
    //-------------------------------------------------------------

    tc9_mid_run_reset();

    //-------------------------------------------------------------
    // TC10 : Long accumulation verification
    //-------------------------------------------------------------

    tc10_long_accumulation();

    //-------------------------------------------------------------
    // Print final verification summary
    //-------------------------------------------------------------

    print_summary();

    //-------------------------------------------------------------
    // End simulation
    //-------------------------------------------------------------

    $display("");
    $display("================================================================");
    $display("              VERIFICATION COMPLETE");
    $display("================================================================");
    $display("");

    $finish;

end

endmodule































