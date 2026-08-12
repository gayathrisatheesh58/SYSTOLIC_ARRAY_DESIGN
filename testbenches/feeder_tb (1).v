`timescale 1ns / 1ps

//=====================================================================
// SECTION - 1
// Matrix Feeder Verification
//=====================================================================

module tb_matrix_feeder;

//=====================================================================
// SECTION -2 
// PARAMETERS AND CLOCK RESET
//=====================================================================

localparam NUM_ROWS   = 4;
localparam NUM_COLS   = 4;
localparam DATA_WIDTH = 8;

//=====================================================================
// CLOCK / RESET
//=====================================================================

reg clk;
reg rst;
reg start;

//=====================================================================
// SECTION - 4
// DUT INPUTS
//=====================================================================

reg signed [NUM_ROWS*NUM_COLS*DATA_WIDTH-1:0] matrix_a_flat;
reg signed [NUM_ROWS*NUM_COLS*DATA_WIDTH-1:0] weight_flat;

//=====================================================================
// SECTION - 5
// DUT OUTPUTS
//=====================================================================

wire signed [NUM_ROWS*DATA_WIDTH-1:0]          a_in;
wire                                           load_weight;
wire signed [NUM_ROWS*NUM_COLS*DATA_WIDTH-1:0] weight_in;

wire busy;
wire done;
wire out_valid;

//=====================================================================
// TEST MATRICES
//=====================================================================

reg signed [DATA_WIDTH-1:0] matrix_A [0:NUM_ROWS-1][0:NUM_COLS-1];
reg signed [DATA_WIDTH-1:0] matrix_W [0:NUM_ROWS-1][0:NUM_COLS-1];

//=====================================================================
// REFERENCE MODEL VARIABLES
//=====================================================================

reg signed [NUM_ROWS*DATA_WIDTH-1:0]          expected_a_in;
reg                                           expected_load_weight;
reg signed [NUM_ROWS*NUM_COLS*DATA_WIDTH-1:0] expected_weight_in;

reg expected_busy;
reg expected_done;
reg expected_out_valid;
reg scoreboard_enable;

//=====================================================================
// SECTION - 3
// TESTBENCH VARIABLES
//=====================================================================
integer total_tests;
integer passed_tests;
integer failed_tests;

integer cycle;

//=====================================================================
// SECTION - 6
// DUT INSTANTIATION
//=====================================================================

matrix_feeder
#(
    .NUM_ROWS(NUM_ROWS),
    .NUM_COLS(NUM_COLS),
    .DATA_WIDTH(DATA_WIDTH)
)
dut
(
    .clk(clk),
    .rst(rst),
    .start(start),

    .matrix_a_flat(matrix_a_flat),
    .weight_flat(weight_flat),

    .a_in(a_in),
    .load_weight(load_weight),
    .weight_in(weight_in),

    .busy(busy),
    .done(done),
    .out_valid(out_valid)
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
// SECTION - 8
// INITIALIZATION
//=====================================================================

initial
begin

    rst = 1;
    start = 0;

    matrix_a_flat = 0;
    weight_flat   = 0;

    total_tests  = 0;
    passed_tests = 0;
    failed_tests = 0;
    scoreboard_enable = 0; 
    cycle = 0;
    

end

//=====================================================================
// SECTION - 9
// CYCLE COUNTER
//=====================================================================

always @(posedge clk)
begin

    if(rst)
        cycle <= 0;
    else
        cycle <= cycle + 1;

end

//=====================================================================
// SECTION 10
// UTILITY TASKS
//=====================================================================

//=====================================================================
// RESET
//=====================================================================

task automatic reset_dut;

begin

    $display("");
    $display("============================================================");
    $display("Applying Reset...");
    $display("============================================================");

    rst = 1;
    start = 0;

    repeat(5) @(posedge clk);

    rst = 0;

    @(posedge clk);

end

endtask
//=====================================================================
// PRINT BANNER
//=====================================================================

task automatic print_banner;

input [256*8:1] title;

begin

    $display("");
    $display("============================================================");
    $display("%0s",title);
    $display("============================================================");

end

endtask
//=====================================================================
// PRINT MATRIX
//=====================================================================
task automatic print_matrix_A;

integer r, c;

begin

    $display("");

    for(r = 0; r < NUM_ROWS; r = r + 1)
    begin
        for(c = 0; c < NUM_COLS; c = c + 1)
            $write("%6d", matrix_A[r][c]);

        $display("");
    end

    $display("");

end

endtask
task automatic print_matrix_W;

integer r, c;

begin

    $display("");

    for(r = 0; r < NUM_ROWS; r = r + 1)
    begin
        for(c = 0; c < NUM_COLS; c = c + 1)
            $write("%6d", matrix_W[r][c]);

        $display("");
    end

    $display("");

end

endtask

//=====================================================================
// LOAD MATRICES
//=====================================================================

task automatic load_matrices;

integer r,c;

begin

    //----------------------------------------------------------
    // Pack Matrix A
    //----------------------------------------------------------

    matrix_a_flat = 0;

    for(r=0; r<NUM_ROWS; r=r+1)
    begin
        for(c=0; c<NUM_COLS; c=c+1)
        begin

            matrix_a_flat[((r*NUM_COLS+c+1)*DATA_WIDTH)-1 -: DATA_WIDTH]
                = matrix_A[r][c];

        end
    end

    //----------------------------------------------------------
    // Pack Weight Matrix
    //----------------------------------------------------------

    weight_flat = 0;

    for(r=0; r<NUM_ROWS; r=r+1)
    begin
        for(c=0; c<NUM_COLS; c=c+1)
        begin

            weight_flat[((r*NUM_COLS+c+1)*DATA_WIDTH)-1 -: DATA_WIDTH]
                = matrix_W[r][c];

        end
    end

    //----------------------------------------------------------
    // Display Matrices
    //----------------------------------------------------------

    $display("");
    $display("============================================================");
    $display("INPUT MATRIX A");
    $display("============================================================");

    print_matrix_A();

    $display("");

    $display("============================================================");
    $display("WEIGHT MATRIX");
    $display("============================================================");

    print_matrix_W();

end

endtask

//=====================================================================
// PRINT STATUS
//=====================================================================

task automatic print_status;

integer r;

begin

    $display("------------------------------------------------------------");
    $display("Time          : %t", $time);
    $display("Cycle         : %0d", cycle);
    $display("");

    $display("load_weight   : %0b", load_weight);
    $display("busy          : %0b", busy);
    $display("done          : %0b", done);
    $display("out_valid     : %0b", out_valid);

    $display("");

    $display("a_in Streams");

    for(r=0; r<NUM_ROWS; r=r+1)
    begin
        $display("Row %0d : %0d",
                 r,
                 $signed(a_in[((r+1)*DATA_WIDTH)-1 -: DATA_WIDTH]));
    end

    $display("");

    $display("Loaded Weight Matrix");

    for(r=0; r<NUM_ROWS; r=r+1)
    begin
        $display("Row %0d : %4d %4d %4d %4d",
            r,
            $signed(weight_in[((r*NUM_COLS+0+1)*DATA_WIDTH)-1 -: DATA_WIDTH]),
            $signed(weight_in[((r*NUM_COLS+1+1)*DATA_WIDTH)-1 -: DATA_WIDTH]),
            $signed(weight_in[((r*NUM_COLS+2+1)*DATA_WIDTH)-1 -: DATA_WIDTH]),
            $signed(weight_in[((r*NUM_COLS+3+1)*DATA_WIDTH)-1 -: DATA_WIDTH]));
    end

    $display("------------------------------------------------------------");

end

endtask


//=====================================================================
// PRINT SUMMARY 
//=====================================================================
task automatic print_summary;

begin

    $display("");
    $display("============================================================");
    $display("FINAL VERIFICATION SUMMARY");
    $display("============================================================");

    $display("Total Tests : %0d",total_tests);
    $display("Passed      : %0d",passed_tests);
    $display("Failed      : %0d",failed_tests);

    if(failed_tests==0)
        $display("OVERALL RESULT : PASS");
    else
        $display("OVERALL RESULT : FAIL");

    $display("============================================================");

end

endtask


//=====================================================================
// SECTION - 11
// MATRIX FEEDER REFERENCE MODEL
//=====================================================================

//=====================================================================
// REFERENCE MEMORIES
//=====================================================================

reg signed [DATA_WIDTH-1:0] ref_matrix [0:NUM_ROWS-1][0:NUM_COLS-1];
reg signed [DATA_WIDTH-1:0] ref_weight [0:NUM_ROWS-1][0:NUM_COLS-1];

//=====================================================================
// REFERENCE FSM
//=====================================================================

localparam REF_IDLE   = 3'd0;
localparam REF_LOAD   = 3'd1;
localparam REF_STREAM = 3'd2;
localparam REF_DRAIN  = 3'd3;
localparam REF_DONE   = 3'd4;

reg [2:0] ref_state;
integer ref_cnt;

integer r;
integer c;

//=====================================================================
// REFERENCE MODEL INITIALIZATION
//=====================================================================

initial
begin

    ref_state = REF_IDLE;
    ref_cnt   = 0;

    expected_a_in        = 0;
    expected_weight_in   = 0;

    expected_load_weight = 0;

    expected_busy        = 0;
    expected_done        = 0;
    expected_out_valid   = 0;

    //----------------------------------------------------------
    // Clear reference memories
    //----------------------------------------------------------

    for(r = 0; r < NUM_ROWS; r = r + 1)
    begin
        for(c = 0; c < NUM_COLS; c = c + 1)
        begin
            ref_matrix[r][c] = 0;
            ref_weight[r][c] = 0;
        end
    end

end


//=====================================================================
// REFERENCE STATE MACHINE
//=====================================================================

always @(posedge clk)
begin

    if(rst)
    begin

        //------------------------------------------------------
        // Reset reference model
        //------------------------------------------------------

        ref_state <= REF_IDLE;
        ref_cnt   <= 0;

        expected_a_in        <= 0;
        expected_weight_in   <= 0;

        expected_load_weight <= 0;

        expected_busy        <= 0;
        expected_done        <= 0;
        expected_out_valid   <= 0;

        //------------------------------------------------------
        // Clear reference memories
        //------------------------------------------------------

        for(r = 0; r < NUM_ROWS; r = r + 1)
        begin
            for(c = 0; c < NUM_COLS; c = c + 1)
            begin
                ref_matrix[r][c] <= 0;
                ref_weight[r][c] <= 0;
            end
        end

    end

    else
    begin

        //------------------------------------------------------
        // Default one-cycle control signals
        //------------------------------------------------------

        expected_load_weight <= 0;
        expected_out_valid   <= 0;

        case(ref_state)

        //======================================================
        // REF_IDLE
        //======================================================

        REF_IDLE:
        begin

            expected_busy <= 0;
            expected_done <= 0;
            expected_a_in <= 0;

            //--------------------------------------------------
            // Start new transaction
            //--------------------------------------------------

            if(start)
            begin

                //------------------------------------------------
                // Store input matrix in reference memory
                //------------------------------------------------

                for(r = 0; r < NUM_ROWS; r = r + 1)
                begin
                    for(c = 0; c < NUM_COLS; c = c + 1)
                    begin

                        ref_matrix[r][c]
                            <= matrix_a_flat[
                               ((r*NUM_COLS+c+1)*DATA_WIDTH)-1
                               -: DATA_WIDTH];

                        ref_weight[r][c]
                            <= weight_flat[
                               ((r*NUM_COLS+c+1)*DATA_WIDTH)-1
                               -: DATA_WIDTH];

                    end
                end

                //------------------------------------------------
                // Weight output is loaded immediately
                // when start is accepted.
                //------------------------------------------------

                expected_weight_in   <= weight_flat;
                expected_load_weight <= 1;

                //------------------------------------------------
                // Feeder becomes busy
                //------------------------------------------------

                expected_busy <= 1;

                //------------------------------------------------
                // Start counters
                //------------------------------------------------

                ref_cnt   <= 0;

                //------------------------------------------------
                // Next state is LOAD
                //------------------------------------------------

                ref_state <= REF_LOAD;

            end

        end


        //======================================================
        // REF_LOAD
        //======================================================

        REF_LOAD:
        begin

            //--------------------------------------------------
            // This cycle corresponds to DUT S_LOAD.
            //
            // The DUT drives a_in = 0 during this cycle.
            //--------------------------------------------------

            expected_a_in <= 0;

            expected_busy <= 1;
            expected_done <= 0;

            //--------------------------------------------------
            // Stream counter starts at zero.
            //--------------------------------------------------

            ref_cnt <= 0;

            //--------------------------------------------------
            // Next clock enters STREAM.
            //--------------------------------------------------

            ref_state <= REF_STREAM;

        end


        //======================================================
        // REF_STREAM
        //======================================================

        REF_STREAM:
        begin

            //--------------------------------------------------
            // Generate the same diagonal/systolic activation
            // pattern produced by the DUT.
            //--------------------------------------------------

            expected_a_in <= 0;

            for(r = 0; r < NUM_ROWS; r = r + 1)
            begin

                if((ref_cnt >= r) &&
                   ((ref_cnt - r) < NUM_COLS))
                begin

                    expected_a_in[
                        ((r+1)*DATA_WIDTH)-1 -: DATA_WIDTH
                    ]
                    <= ref_matrix[r][ref_cnt-r];

                end

                else
                begin

                    expected_a_in[
                        ((r+1)*DATA_WIDTH)-1 -: DATA_WIDTH
                    ]
                    <= 0;

                end

            end

            //--------------------------------------------------
            // Control signals during streaming
            //--------------------------------------------------

            expected_busy <= 1;
            expected_done <= 0;

            //--------------------------------------------------
            // There are:
            //
            // NUM_ROWS + NUM_COLS - 1
            //
            // stream cycles.
            //
            // For 4x4:
            // 7 stream cycles
            //
            //--------------------------------------------------

            if(ref_cnt == (NUM_ROWS + NUM_COLS - 2))
            begin

                //------------------------------------------------
                // Last stream cycle completed.
                //------------------------------------------------

                ref_cnt   <= 0;
                ref_state <= REF_DRAIN;

            end

            else
            begin

                ref_cnt <= ref_cnt + 1;

            end

        end


        //======================================================
        // REF_DRAIN
        //======================================================

        REF_DRAIN:
        begin

            //--------------------------------------------------
            // No more activation data is injected.
            //--------------------------------------------------

            expected_a_in <= 0;

            expected_busy <= 1;
            expected_done <= 0;

            //--------------------------------------------------
            // Wait for the feeder drain period.
            //
            // DUT:
            //
            // DRAIN_CYCLES = NUM_ROWS + NUM_COLS + 2
            //
            // For 4x4:
            // DRAIN_CYCLES = 10
            //
            //--------------------------------------------------

            if(ref_cnt == (NUM_ROWS + NUM_COLS + 2 - 1))
            begin

                //------------------------------------------------
                // Transaction completed.
                //------------------------------------------------

                expected_busy      <= 0;
                expected_done      <= 1;
                expected_out_valid <= 1;

                ref_cnt   <= 0;
                ref_state <= REF_DONE;

            end

            else
            begin

                ref_cnt <= ref_cnt + 1;

            end

        end


        //======================================================
        // REF_DONE
        //======================================================

        REF_DONE:
        begin

            //--------------------------------------------------
            // DUT holds done high in S_DONE.
            //--------------------------------------------------

            expected_a_in <= 0;

            expected_busy      <= 0;
            expected_done      <= 1;
            expected_out_valid <= 0;

            //--------------------------------------------------
            // Return to IDLE after start is released.
            //--------------------------------------------------

            if(!start)
            begin
                ref_state <= REF_IDLE;
            end

        end


        //======================================================
        // DEFAULT
        //======================================================

        default:
        begin

            ref_state <= REF_IDLE;
            ref_cnt   <= 0;

            expected_a_in        <= 0;
            expected_weight_in   <= 0;
            expected_load_weight <= 0;
            expected_busy        <= 0;
            expected_done        <= 0;
            expected_out_valid   <= 0;

        end

        endcase

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
        // Control Signals
        //----------------------------------------------------------

        $display("");
        $display("CONTROL SIGNALS");
        $display("--------------------------------------------");

        $display("load_weight : Expected = %0b  Actual = %0b",
                  expected_load_weight, load_weight);

        $display("busy        : Expected = %0b  Actual = %0b",
                  expected_busy, busy);

        $display("done        : Expected = %0b  Actual = %0b",
                  expected_done, done);

        $display("out_valid   : Expected = %0b  Actual = %0b",
                  expected_out_valid, out_valid);

        //----------------------------------------------------------
        // Activation Streams
        //----------------------------------------------------------

        $display("");
        $display("ACTIVATION STREAMS");
        $display("--------------------------------------------");

        for(r=0; r<NUM_ROWS; r=r+1)
        begin

            $display("Row %0d : Expected = %4d   Actual = %4d",
                r,
                $signed(expected_a_in[((r+1)*DATA_WIDTH)-1 -: DATA_WIDTH]),
                $signed(a_in[((r+1)*DATA_WIDTH)-1 -: DATA_WIDTH]));

        end

        //----------------------------------------------------------
        // Weight Matrix Check
        //----------------------------------------------------------

        if(load_weight)
        begin

            $display("");
            $display("Weight matrix loaded.");

        end

        //----------------------------------------------------------
        // PASS / FAIL
        //----------------------------------------------------------

        if((expected_a_in        === a_in) &&
           (expected_weight_in   === weight_in) &&
           (expected_load_weight === load_weight) &&
           (expected_busy        === busy) &&
           (expected_done        === done) &&
           (expected_out_valid   === out_valid))
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
// SECTION 13
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
    // Check Reset Outputs
    //----------------------------------------------------------

    if ((a_in        === 0) &&
        (load_weight === 0) &&
        (weight_in   === 0) &&
        (busy        === 0) &&
        (done        === 0) &&
        (out_valid   === 0))
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

        $display("a_in         = 0");
        $display("load_weight  = 0");
        $display("weight_in    = 0");
        $display("busy         = 0");
        $display("done         = 0");
        $display("out_valid    = 0");

        $display("");
        $display("Observed");
        $display("----------------------------------------");

        $display("a_in         = %h", a_in);
        $display("load_weight  = %b", load_weight);
        $display("weight_in    = %h", weight_in);
        $display("busy         = %b", busy);
        $display("done         = %b", done);
        $display("out_valid    = %b", out_valid);

    end

    $display("");
    $display("------------------------------------------------------------");
    $display("TC1 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
// TC2 : BASIC MATRIX FEEDING VERIFICATION
//=====================================================================

task automatic tc2_basic_matrix_feed;

integer r, c;

begin

    print_banner("TC2 : BASIC MATRIX FEEDING VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Enable cycle-by-cycle scoreboard
    //----------------------------------------------------------

    scoreboard_enable = 1;

    //----------------------------------------------------------
    // Create Input Matrix A
    //----------------------------------------------------------

    matrix_A[0][0] = 1;
    matrix_A[0][1] = 2;
    matrix_A[0][2] = 3;
    matrix_A[0][3] = 4;

    matrix_A[1][0] = 5;
    matrix_A[1][1] = 6;
    matrix_A[1][2] = 7;
    matrix_A[1][3] = 8;

    matrix_A[2][0] = 9;
    matrix_A[2][1] = 10;
    matrix_A[2][2] = 11;
    matrix_A[2][3] = 12;

    matrix_A[3][0] = 13;
    matrix_A[3][1] = 14;
    matrix_A[3][2] = 15;
    matrix_A[3][3] = 16;

    //----------------------------------------------------------
    // Identity Weight Matrix
    //----------------------------------------------------------

    for(r = 0; r < NUM_ROWS; r = r + 1)
    begin

        for(c = 0; c < NUM_COLS; c = c + 1)
        begin

            if(r == c)
                matrix_W[r][c] = 1;
            else
                matrix_W[r][c] = 0;

        end

    end

    //----------------------------------------------------------
    // Display and Pack Matrices
    //----------------------------------------------------------

    load_matrices();

    //----------------------------------------------------------
    // Start Matrix Feeder
    //----------------------------------------------------------

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //----------------------------------------------------------
    // Wait for feeder completion
    //
    // The current DUT requires:
    //
    // LOAD   = 1 cycle
    // STREAM = 7 cycles
    // DRAIN  = 10 cycles
    //
    // Total operation = 18 cycles after entering S_LOAD
    //----------------------------------------------------------

    wait(done == 1);

    //----------------------------------------------------------
    // Allow scoreboard to observe DONE/OUT_VALID
    //----------------------------------------------------------

    @(posedge clk);

    //----------------------------------------------------------
    // Disable scoreboard before final status check
    //----------------------------------------------------------

    scoreboard_enable = 0;

    //----------------------------------------------------------
    // Display final status
    //----------------------------------------------------------

    print_status();

    //----------------------------------------------------------
    // Final functional check
    //----------------------------------------------------------

    if((a_in        === 0) &&
       (load_weight === 0) &&
       (busy        === 0) &&
       (done         === 1) &&
       (out_valid    === 0))
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
        $display("Expected final state:");
        $display("----------------------------------------");
        $display("a_in         = 0");
        $display("load_weight  = 0");
        $display("busy         = 0");
        $display("done         = 1");
        $display("out_valid    = 0");

        $display("");
        $display("Observed:");
        $display("----------------------------------------");
        $display("a_in         = %h", a_in);
        $display("load_weight  = %b", load_weight);
        $display("busy         = %b", busy);
        $display("done         = %b", done);
        $display("out_valid    = %b", out_valid);

    end

    //----------------------------------------------------------
    // Test complete
    //----------------------------------------------------------

    $display("");
    $display("------------------------------------------------------------");
    $display("TC2 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask


//=====================================================================
// TC3 : SIGNED / NEGATIVE MATRIX FEED VERIFICATION
//=====================================================================

task automatic tc3_signed_matrix_feed;

integer r, c;

begin

    print_banner("TC3 : SIGNED / NEGATIVE MATRIX FEED VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Enable cycle-by-cycle scoreboard
    //----------------------------------------------------------

    scoreboard_enable = 1;

    //----------------------------------------------------------
    // Matrix A
    //----------------------------------------------------------
    // Use both positive and negative values to verify that
    // signed 8-bit packing/unpacking is correct.
    //----------------------------------------------------------

    matrix_A[0][0] = -1;
    matrix_A[0][1] =  2;
    matrix_A[0][2] = -3;
    matrix_A[0][3] =  4;

    matrix_A[1][0] = -5;
    matrix_A[1][1] =  6;
    matrix_A[1][2] = -7;
    matrix_A[1][3] =  8;

    matrix_A[2][0] = -9;
    matrix_A[2][1] = 10;
    matrix_A[2][2] = -11;
    matrix_A[2][3] = 12;

    matrix_A[3][0] = -13;
    matrix_A[3][1] = 14;
    matrix_A[3][2] = -15;
    matrix_A[3][3] = 16;

    //----------------------------------------------------------
    // Weight Matrix
    //----------------------------------------------------------
    // Use signed values as well. The feeder only transports
    // these values; it does not perform multiplication.
    //----------------------------------------------------------

    matrix_W[0][0] =  1;
    matrix_W[0][1] = -1;
    matrix_W[0][2] =  2;
    matrix_W[0][3] = -2;

    matrix_W[1][0] =  3;
    matrix_W[1][1] = -3;
    matrix_W[1][2] =  4;
    matrix_W[1][3] = -4;

    matrix_W[2][0] =  5;
    matrix_W[2][1] = -5;
    matrix_W[2][2] =  6;
    matrix_W[2][3] = -6;

    matrix_W[3][0] =  7;
    matrix_W[3][1] = -7;
    matrix_W[3][2] =  8;
    matrix_W[3][3] = -8;

    //----------------------------------------------------------
    // Display and pack matrices
    //----------------------------------------------------------

    load_matrices();

    //----------------------------------------------------------
    // Start feeder
    //----------------------------------------------------------

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //----------------------------------------------------------
    // Wait until feeder completes
    //----------------------------------------------------------

    wait(done == 1);

    //----------------------------------------------------------
    // Allow final scoreboard observation
    //----------------------------------------------------------

    @(posedge clk);

    //----------------------------------------------------------
    // Disable scoreboard
    //----------------------------------------------------------

    scoreboard_enable = 0;

    //----------------------------------------------------------
    // Final status
    //----------------------------------------------------------

    print_status();

    //----------------------------------------------------------
    // Verify final state
    //----------------------------------------------------------

    if((a_in        === 0) &&
       (load_weight === 0) &&
       (busy        === 0) &&
       (done         === 1) &&
       (out_valid    === 0))
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
        $display("Expected final state:");
        $display("----------------------------------------");

        $display("a_in         = 0");
        $display("load_weight  = 0");
        $display("busy         = 0");
        $display("done         = 1");
        $display("out_valid    = 0");

        $display("");
        $display("Observed:");
        $display("----------------------------------------");

        $display("a_in         = %h", a_in);
        $display("load_weight  = %b", load_weight);
        $display("busy         = %b", busy);
        $display("done         = %b", done);
        $display("out_valid    = %b", out_valid);

    end

    //----------------------------------------------------------
    // Test complete
    //----------------------------------------------------------

    $display("");
    $display("------------------------------------------------------------");
    $display("TC3 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
// TC4 : ROW / COLUMN ORDER VERIFICATION
//=====================================================================

task automatic tc4_row_column_order;

integer r, c;

begin

    print_banner("TC4 : ROW / COLUMN ORDER VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Enable scoreboard
    //----------------------------------------------------------

    scoreboard_enable = 1;

    //----------------------------------------------------------
    // Asymmetric Matrix A
    //----------------------------------------------------------
    // Deliberately different values in every position so that
    // row/column swaps are immediately visible.
    //----------------------------------------------------------

    matrix_A[0][0] = 11;
    matrix_A[0][1] = 22;
    matrix_A[0][2] = 33;
    matrix_A[0][3] = 44;

    matrix_A[1][0] = 55;
    matrix_A[1][1] = 66;
    matrix_A[1][2] = 77;
    matrix_A[1][3] = 88;

    matrix_A[2][0] = 12;
    matrix_A[2][1] = 23;
    matrix_A[2][2] = 34;
    matrix_A[2][3] = 45;

    matrix_A[3][0] = 56;
    matrix_A[3][1] = 67;
    matrix_A[3][2] = 78;
    matrix_A[3][3] = 89;

    //----------------------------------------------------------
    // Asymmetric Weight Matrix
    //----------------------------------------------------------

    matrix_W[0][0] =  1;
    matrix_W[0][1] =  2;
    matrix_W[0][2] =  3;
    matrix_W[0][3] =  4;

    matrix_W[1][0] =  5;
    matrix_W[1][1] =  6;
    matrix_W[1][2] =  7;
    matrix_W[1][3] =  8;

    matrix_W[2][0] =  9;
    matrix_W[2][1] = 10;
    matrix_W[2][2] = 11;
    matrix_W[2][3] = 12;

    matrix_W[3][0] = 13;
    matrix_W[3][1] = 14;
    matrix_W[3][2] = 15;
    matrix_W[3][3] = 16;

    //----------------------------------------------------------
    // Pack and display matrices
    //----------------------------------------------------------

    load_matrices();

    //----------------------------------------------------------
    // Start feeder
    //----------------------------------------------------------

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //----------------------------------------------------------
    // Wait for completion
    //----------------------------------------------------------

    wait(done == 1);

    //----------------------------------------------------------
    // Allow scoreboard to observe final cycle
    //----------------------------------------------------------

    @(posedge clk);

    //----------------------------------------------------------
    // Disable scoreboard
    //----------------------------------------------------------

    scoreboard_enable = 0;

    //----------------------------------------------------------
    // Final status check
    //----------------------------------------------------------

    print_status();

    if((a_in        === 0) &&
       (load_weight === 0) &&
       (busy        === 0) &&
       (done         === 1) &&
       (out_valid    === 0))
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
        $display("Expected final state:");
        $display("----------------------------------------");

        $display("a_in         = 0");
        $display("load_weight  = 0");
        $display("busy         = 0");
        $display("done         = 1");
        $display("out_valid    = 0");

        $display("");
        $display("Observed:");
        $display("----------------------------------------");

        $display("a_in         = %h", a_in);
        $display("load_weight  = %b", load_weight);
        $display("busy         = %b", busy);
        $display("done         = %b", done);
        $display("out_valid    = %b", out_valid);

    end

    //----------------------------------------------------------
    // Test complete
    //----------------------------------------------------------

    $display("");
    $display("------------------------------------------------------------");
    $display("TC4 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
// TC5 : START / BUSY TRANSACTION CONTROL VERIFICATION
//=====================================================================

task automatic tc5_start_busy_control;

integer r, c;

begin

    print_banner("TC5 : START / BUSY TRANSACTION CONTROL");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Enable scoreboard
    //----------------------------------------------------------

    scoreboard_enable = 1;

    //----------------------------------------------------------
    // Prepare Matrix A
    //----------------------------------------------------------

    matrix_A[0][0] = 1;
    matrix_A[0][1] = 2;
    matrix_A[0][2] = 3;
    matrix_A[0][3] = 4;

    matrix_A[1][0] = 5;
    matrix_A[1][1] = 6;
    matrix_A[1][2] = 7;
    matrix_A[1][3] = 8;

    matrix_A[2][0] = 9;
    matrix_A[2][1] = 10;
    matrix_A[2][2] = 11;
    matrix_A[2][3] = 12;

    matrix_A[3][0] = 13;
    matrix_A[3][1] = 14;
    matrix_A[3][2] = 15;
    matrix_A[3][3] = 16;

    //----------------------------------------------------------
    // Prepare Weight Matrix
    //----------------------------------------------------------

    for(r = 0; r < NUM_ROWS; r = r + 1)
    begin

        for(c = 0; c < NUM_COLS; c = c + 1)
        begin

            matrix_W[r][c] = 1;

        end

    end

    //----------------------------------------------------------
    // Pack matrices
    //----------------------------------------------------------

    load_matrices();

    //----------------------------------------------------------
    // Start first transaction
    //----------------------------------------------------------

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //----------------------------------------------------------
    // Verify feeder entered BUSY state
    //----------------------------------------------------------

    if(busy !== 1)
    begin

        $display("");
        $display("ERROR : Feeder did not enter BUSY state after START.");

    end

    //----------------------------------------------------------
    // Attempt to keep START asserted while BUSY
    //
    // The feeder should NOT restart the transaction.
    //----------------------------------------------------------

    start = 1;

    repeat(3)
    begin

        @(posedge clk);

        if(busy !== 1)
        begin

            $display("");
            $display("ERROR : BUSY dropped while transaction was active.");

        end

    end

    start = 0;

    //----------------------------------------------------------
    // Wait for completion
    //----------------------------------------------------------

    wait(done == 1);

    //----------------------------------------------------------
    // Allow final scoreboard observation
    //----------------------------------------------------------

    @(posedge clk);

    //----------------------------------------------------------
    // Disable scoreboard
    //----------------------------------------------------------

    scoreboard_enable = 0;

    //----------------------------------------------------------
    // Final state verification
    //----------------------------------------------------------

    print_status();

    if((busy      === 0) &&
       (done      === 1) &&
       (a_in      === 0) &&
       (load_weight === 0))
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
        $display("Expected:");
        $display("----------------------------------------");
        $display("busy         = 0");
        $display("done         = 1");
        $display("a_in         = 0");
        $display("load_weight  = 0");

        $display("");
        $display("Observed:");
        $display("----------------------------------------");
        $display("busy         = %b", busy);
        $display("done         = %b", done);
        $display("a_in         = %h", a_in);
        $display("load_weight  = %b", load_weight);

    end

    //----------------------------------------------------------
    // Test complete
    //----------------------------------------------------------

    $display("");
    $display("------------------------------------------------------------");
    $display("TC5 COMPLETE");
    $display("------------------------------------------------------------");
    $display("");

end

endtask

//=====================================================================
// TC6 : SIGNED / NEGATIVE ACTIVATION VERIFICATION
//=====================================================================

task automatic tc6_negative_values;

integer r, c;

begin

    scoreboard_enable = 1;

    print_banner("TC6 : SIGNED / NEGATIVE ACTIVATION VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Negative / Positive Input Matrix A
    //----------------------------------------------------------

    matrix_A[0][0] = -1;
    matrix_A[0][1] = -2;
    matrix_A[0][2] = -3;
    matrix_A[0][3] = -4;

    matrix_A[1][0] =  5;
    matrix_A[1][1] =  6;
    matrix_A[1][2] =  7;
    matrix_A[1][3] =  8;

    matrix_A[2][0] = -9;
    matrix_A[2][1] = -10;
    matrix_A[2][2] = -11;
    matrix_A[2][3] = -12;

    matrix_A[3][0] = 13;
    matrix_A[3][1] = 14;
    matrix_A[3][2] = 15;
    matrix_A[3][3] = 16;

    //----------------------------------------------------------
    // Identity Weight Matrix
    //----------------------------------------------------------

    for(r = 0; r < NUM_ROWS; r = r + 1)
    begin

        for(c = 0; c < NUM_COLS; c = c + 1)
        begin

            if(r == c)
                matrix_W[r][c] = 1;
            else
                matrix_W[r][c] = 0;

        end

    end

    //----------------------------------------------------------
    // Pack matrices into flat inputs
    //----------------------------------------------------------

    load_matrices();

    //----------------------------------------------------------
    // Start DUT
    //----------------------------------------------------------

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //----------------------------------------------------------
    // Allow complete activation streaming and drain
    //----------------------------------------------------------

    repeat(20)
        @(posedge clk);

    //----------------------------------------------------------
    // Final Status
    //----------------------------------------------------------

    print_status();

    $display("");
    $display("Checking signed activation handling...");

    if((expected_a_in        === a_in) &&
       (expected_weight_in   === weight_in) &&
       (expected_load_weight === load_weight) &&
       (expected_busy        === busy) &&
       (expected_done        === done) &&
       (expected_out_valid   === out_valid))
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

    //----------------------------------------------------------
    // Test Completion
    //----------------------------------------------------------

    $display("");
    $display("------------------------------------------------------------");
    $display("TC6 COMPLETE");
    $display("------------------------------------------------------------");

    scoreboard_enable = 0;

end

endtask

//=====================================================================
// TC7 : BOUNDARY VALUE VERIFICATION
//=====================================================================

task automatic tc7_boundary_values;

integer r, c;

begin

    scoreboard_enable = 1;

    print_banner("TC7 : BOUNDARY VALUE VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Boundary Values for 8-bit Signed Data
    // -128 to +127
    //----------------------------------------------------------

    matrix_A[0][0] = -128;
    matrix_A[0][1] = -127;
    matrix_A[0][2] =   0;
    matrix_A[0][3] = 127;

    matrix_A[1][0] = 127;
    matrix_A[1][1] =   0;
    matrix_A[1][2] = -128;
    matrix_A[1][3] = -1;

    matrix_A[2][0] = -1;
    matrix_A[2][1] = 127;
    matrix_A[2][2] = -128;
    matrix_A[2][3] = 0;

    matrix_A[3][0] = 0;
    matrix_A[3][1] = -128;
    matrix_A[3][2] = 127;
    matrix_A[3][3] = -127;

    //----------------------------------------------------------
    // Identity Weight Matrix
    //----------------------------------------------------------

    for(r = 0; r < NUM_ROWS; r = r + 1)
    begin

        for(c = 0; c < NUM_COLS; c = c + 1)
        begin

            if(r == c)
                matrix_W[r][c] = 1;
            else
                matrix_W[r][c] = 0;

        end

    end

    //----------------------------------------------------------
    // Pack matrices
    //----------------------------------------------------------

    load_matrices();

    //----------------------------------------------------------
    // Start DUT
    //----------------------------------------------------------

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //----------------------------------------------------------
    // Allow complete feeder operation
    //----------------------------------------------------------

    repeat(20)
        @(posedge clk);

    //----------------------------------------------------------
    // Final verification
    //----------------------------------------------------------

    print_status();

    $display("");
    $display("Checking 8-bit boundary value handling...");

    if((expected_a_in        === a_in) &&
       (expected_weight_in   === weight_in) &&
       (expected_load_weight === load_weight) &&
       (expected_busy        === busy) &&
       (expected_done        === done) &&
       (expected_out_valid   === out_valid))
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

    //----------------------------------------------------------
    // Test completion
    //----------------------------------------------------------

    $display("");
    $display("------------------------------------------------------------");
    $display("TC7 COMPLETE");
    $display("------------------------------------------------------------");

    scoreboard_enable = 0;

end

endtask
//=====================================================================
// TC8 : WEIGHT MATRIX LOAD VERIFICATION
//=====================================================================

task automatic tc8_weight_matrix_load;

integer r, c;

begin

    scoreboard_enable = 1;

    print_banner("TC8 : WEIGHT MATRIX LOAD VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Simple activation matrix
    //----------------------------------------------------------

    matrix_A[0][0] = 1;
    matrix_A[0][1] = 2;
    matrix_A[0][2] = 3;
    matrix_A[0][3] = 4;

    matrix_A[1][0] = 5;
    matrix_A[1][1] = 6;
    matrix_A[1][2] = 7;
    matrix_A[1][3] = 8;

    matrix_A[2][0] = 9;
    matrix_A[2][1] = 10;
    matrix_A[2][2] = 11;
    matrix_A[2][3] = 12;

    matrix_A[3][0] = 13;
    matrix_A[3][1] = 14;
    matrix_A[3][2] = 15;
    matrix_A[3][3] = 16;

    //----------------------------------------------------------
    // Unique Weight Matrix
    // Makes row/column packing errors easy to detect
    //----------------------------------------------------------

    matrix_W[0][0] = 1;
    matrix_W[0][1] = 2;
    matrix_W[0][2] = 3;
    matrix_W[0][3] = 4;

    matrix_W[1][0] = 5;
    matrix_W[1][1] = 6;
    matrix_W[1][2] = 7;
    matrix_W[1][3] = 8;

    matrix_W[2][0] = 9;
    matrix_W[2][1] = 10;
    matrix_W[2][2] = 11;
    matrix_W[2][3] = 12;

    matrix_W[3][0] = 13;
    matrix_W[3][1] = 14;
    matrix_W[3][2] = 15;
    matrix_W[3][3] = 16;

    //----------------------------------------------------------
    // Pack matrices
    //----------------------------------------------------------

    load_matrices();

    //----------------------------------------------------------
    // Start DUT
    //----------------------------------------------------------

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //----------------------------------------------------------
    // Allow complete feeder operation
    //----------------------------------------------------------

    repeat(20)
        @(posedge clk);

    //----------------------------------------------------------
    // Final verification
    //----------------------------------------------------------

    print_status();

    $display("");
    $display("Checking complete weight matrix transfer...");

    if((expected_a_in        === a_in) &&
       (expected_weight_in   === weight_in) &&
       (expected_load_weight === load_weight) &&
       (expected_busy        === busy) &&
       (expected_done        === done) &&
       (expected_out_valid   === out_valid))
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

    //----------------------------------------------------------
    // Test completion
    //----------------------------------------------------------

    $display("");
    $display("------------------------------------------------------------");
    $display("TC8 COMPLETE");
    $display("------------------------------------------------------------");

    scoreboard_enable = 0;

end
endtask
//=====================================================================
// TC9 : BACK-TO-BACK OPERATION VERIFICATION
//=====================================================================

task automatic tc9_back_to_back_operation;

integer r, c;

begin

    scoreboard_enable = 1;

    print_banner("TC9 : BACK-TO-BACK OPERATION VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Matrix A - Test 1
    //----------------------------------------------------------

    matrix_A[0][0] = 1;
    matrix_A[0][1] = 2;
    matrix_A[0][2] = 3;
    matrix_A[0][3] = 4;

    matrix_A[1][0] = 5;
    matrix_A[1][1] = 6;
    matrix_A[1][2] = 7;
    matrix_A[1][3] = 8;

    matrix_A[2][0] = 9;
    matrix_A[2][1] = 10;
    matrix_A[2][2] = 11;
    matrix_A[2][3] = 12;

    matrix_A[3][0] = 13;
    matrix_A[3][1] = 14;
    matrix_A[3][2] = 15;
    matrix_A[3][3] = 16;

    //----------------------------------------------------------
    // Weight Matrix - Test 1
    //----------------------------------------------------------

    for(r = 0; r < NUM_ROWS; r = r + 1)
    begin
        for(c = 0; c < NUM_COLS; c = c + 1)
        begin
            if(r == c)
                matrix_W[r][c] = 1;
            else
                matrix_W[r][c] = 0;
        end
    end

    //----------------------------------------------------------
    // Load Test 1
    //----------------------------------------------------------

    load_matrices();

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //----------------------------------------------------------
    // Wait for Test 1 to complete
    //----------------------------------------------------------

    wait(done == 1);

    @(posedge clk);

    //----------------------------------------------------------
    // Matrix A - Test 2
    //----------------------------------------------------------

    matrix_A[0][0] = 16;
    matrix_A[0][1] = 15;
    matrix_A[0][2] = 14;
    matrix_A[0][3] = 13;

    matrix_A[1][0] = 12;
    matrix_A[1][1] = 11;
    matrix_A[1][2] = 10;
    matrix_A[1][3] = 9;

    matrix_A[2][0] = 8;
    matrix_A[2][1] = 7;
    matrix_A[2][2] = 6;
    matrix_A[2][3] = 5;

    matrix_A[3][0] = 4;
    matrix_A[3][1] = 3;
    matrix_A[3][2] = 2;
    matrix_A[3][3] = 1;

    //----------------------------------------------------------
    // Weight Matrix - Test 2
    //----------------------------------------------------------

    matrix_W[0][0] = 2;
    matrix_W[0][1] = 0;
    matrix_W[0][2] = 0;
    matrix_W[0][3] = 0;

    matrix_W[1][0] = 0;
    matrix_W[1][1] = 2;
    matrix_W[1][2] = 0;
    matrix_W[1][3] = 0;

    matrix_W[2][0] = 0;
    matrix_W[2][1] = 0;
    matrix_W[2][2] = 2;
    matrix_W[2][3] = 0;

    matrix_W[3][0] = 0;
    matrix_W[3][1] = 0;
    matrix_W[3][2] = 0;
    matrix_W[3][3] = 2;

    //----------------------------------------------------------
    // Load Test 2
    //----------------------------------------------------------

    load_matrices();

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //----------------------------------------------------------
    // Wait for Test 2 to complete
    //----------------------------------------------------------

    wait(done == 1);

    //----------------------------------------------------------
    // Final status
    //----------------------------------------------------------

    print_status();

    $display("");
    $display("Checking back-to-back operation...");

    if((expected_a_in        === a_in) &&
       (expected_weight_in   === weight_in) &&
       (expected_load_weight === load_weight) &&
       (expected_busy        === busy) &&
       (expected_done        === done) &&
       (expected_out_valid   === out_valid))
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

    //----------------------------------------------------------
    // Test completion
    //----------------------------------------------------------

    $display("");
    $display("------------------------------------------------------------");
    $display("TC9 COMPLETE");
    $display("------------------------------------------------------------");

    scoreboard_enable = 0;

end

endtask
//=====================================================================
// TC10 : MID-RUN RESET VERIFICATION
//=====================================================================

task automatic tc10_mid_run_reset;

integer r, c;

begin

    scoreboard_enable = 1;

    print_banner("TC10 : MID-RUN RESET VERIFICATION");

    total_tests = total_tests + 1;

    //----------------------------------------------------------
    // Input Matrix A
    //----------------------------------------------------------

    matrix_A[0][0] = 1;
    matrix_A[0][1] = 2;
    matrix_A[0][2] = 3;
    matrix_A[0][3] = 4;

    matrix_A[1][0] = 5;
    matrix_A[1][1] = 6;
    matrix_A[1][2] = 7;
    matrix_A[1][3] = 8;

    matrix_A[2][0] = 9;
    matrix_A[2][1] = 10;
    matrix_A[2][2] = 11;
    matrix_A[2][3] = 12;

    matrix_A[3][0] = 13;
    matrix_A[3][1] = 14;
    matrix_A[3][2] = 15;
    matrix_A[3][3] = 16;

    //----------------------------------------------------------
    // Identity Weight Matrix
    //----------------------------------------------------------

    for(r = 0; r < NUM_ROWS; r = r + 1)
    begin
        for(c = 0; c < NUM_COLS; c = c + 1)
        begin
            if(r == c)
                matrix_W[r][c] = 1;
            else
                matrix_W[r][c] = 0;
        end
    end

    //----------------------------------------------------------
    // Pack matrices
    //----------------------------------------------------------

    load_matrices();

    //----------------------------------------------------------
    // Start DUT
    //----------------------------------------------------------

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //----------------------------------------------------------
    // Allow feeder to enter streaming operation
    //----------------------------------------------------------

    repeat(3)
        @(posedge clk);

    //----------------------------------------------------------
    // Apply RESET while DUT is busy
    //----------------------------------------------------------

    $display("");
    $display("Applying MID-RUN RESET...");

    rst = 1;

    repeat(2)
        @(posedge clk);

    //----------------------------------------------------------
    // Release reset
    //----------------------------------------------------------

    rst = 0;

    @(posedge clk);

    //----------------------------------------------------------
    // Check reset state
    //----------------------------------------------------------

    print_status();

    if((a_in      === 0) &&
       (load_weight === 0) &&
       (weight_in === 0) &&
       (busy      === 0) &&
       (done      === 0) &&
       (out_valid === 0))
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
        $display("Expected all outputs to be reset to zero.");

    end

    //----------------------------------------------------------
    // Test completion
    //----------------------------------------------------------

    $display("");
    $display("------------------------------------------------------------");
    $display("TC10 COMPLETE");
    $display("------------------------------------------------------------");

    scoreboard_enable = 0;

end

endtask

//=====================================================================
// SECTION - 14
// TIME FORMAT
//=====================================================================

initial
begin
    $timeformat(-9,0," ns",10);
end

//=====================================================================
// SECTION - 15
// WAVEFORM DUMP
//=====================================================================

initial
begin
    $dumpfile("tb_matrix_feeder.vcd");
    $dumpvars(0,tb_matrix_feeder);
end

//=====================================================================
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
    // Execute all Matrix Feeder test cases
    //----------------------------------------------------------

    tc1_reset();

    tc2_identity_matrix();

    tc3_random_matrix();

    tc4_busy_done_timing();

    tc5_weight_hold();

    tc6_negative_values();

    tc7_mixed_values();

    tc8_boundary_values();

    tc9_back_to_back_transactions();

    tc10_mid_run_reset();

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