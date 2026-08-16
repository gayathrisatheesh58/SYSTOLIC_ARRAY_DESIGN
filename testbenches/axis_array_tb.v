`timescale 1ns / 1ps
//=====================================================================
// TESTBENCH: axis_systolic_array (AXI4-Stream wrapper) — WRAPPER ONLY
//
// STRATEGY
// --------
// The wrapper's job is purely to serialize/deserialize AXI4-Stream
// words into/out of the systolic_array_4x4_top core and to run the
// RECEIVE -> START -> WAIT -> OUTPUT handshake correctly. The core
// itself (matrix_feeder / systolic_array_4x4 / processing_element_2d)
// is treated as an already-verified, trusted "golden" block.
//
// So instead of hand-deriving the pipelined/skewed MAC arithmetic,
// this TB instantiates a SECOND, independent copy of
// systolic_array_4x4_top ("REF") and drives it directly (no AXI).
// For every test the SAME W/A matrices are:
//   (a) sent to the DUT through the AXI4-Stream wrapper, and
//   (b) applied directly to REF's parallel matrix_a_flat/weight_flat
//       ports with a `start` pulse.
// REF's acc_out is the oracle; the DUT's unpacked AXIS output words
// must match it bit-for-bit. This validates exactly the wrapper
// logic (packing order, word count, TLAST placement, READY/VALID
// handshaking, state sequencing, reset behavior) with zero risk of
// a hand-derived "golden model" being wrong about the core's
// internal pipeline timing.
//
// NOTE ON DATA REPRESENTATION
// ----------------------------
// Matrices are carried as flat 128-bit vectors using exactly the
// same packing the wrapper itself uses:
//   flat[(row*32)+(col*8) +: 8]  = element[row][col]
// i.e. flat[row*32 +: 32] is precisely the 32-bit AXI word for that
// row. This keeps every task/function port a simple packed vector
// (portable across simulators, including Icarus, which does not
// support unpacked-array subroutine ports).
//
// Compile (Icarus, needs -g2012 for the SV constructs used here):
//   iverilog -g2012 -o sim.out \
//       axis_systolic_array.v systolic_array_4x4_top.v \
//       systolic_array_4x4.v processing_element_2d.v matrix_feeder.v \
//       tb_axis_systolic_array.sv
//   vvp sim.out
//=====================================================================

module tb_axis_systolic_array;

    //=================================================================
    // PARAMETERS
    //=================================================================

    localparam DATA_WIDTH = 8;
    localparam AXIS_WIDTH = 32;
    localparam NUM_ROWS   = 4;
    localparam NUM_COLS   = 4;
    localparam ACC_WIDTH  = (2*DATA_WIDTH) + 1;   // 17
    localparam MAT_WIDTH  = NUM_ROWS*NUM_COLS*DATA_WIDTH; // 128
    localparam ACCS_WIDTH = NUM_COLS*ACC_WIDTH;            // 68

    localparam CLK_PERIOD = 10;

    //=================================================================
    // CLOCK / RESET
    //=================================================================

    reg aclk;
    reg aresetn;

    initial aclk = 1'b0;
    always #(CLK_PERIOD/2) aclk = ~aclk;

    //=================================================================
    // DUT (UNIT UNDER TEST) — the AXIS wrapper
    //=================================================================

    reg  [AXIS_WIDTH-1:0] s_axis_tdata;
    reg                   s_axis_tvalid;
    wire                  s_axis_tready;
    reg                   s_axis_tlast;

    wire [AXIS_WIDTH-1:0] m_axis_tdata;
    wire                  m_axis_tvalid;
    reg                   m_axis_tready;
    wire                  m_axis_tlast;

    axis_systolic_array #(
        .DATA_WIDTH (DATA_WIDTH),
        .AXIS_WIDTH (AXIS_WIDTH)
    ) dut (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tlast  (s_axis_tlast),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tlast  (m_axis_tlast)
    );

    //=================================================================
    // REF (GOLDEN ORACLE) — direct copy of the trusted core, no AXIS
    //=================================================================

    reg                          start_ref;
    reg  signed [MAT_WIDTH-1:0]  matrix_a_flat_ref;
    reg  signed [MAT_WIDTH-1:0]  weight_flat_ref;

    wire signed [ACCS_WIDTH-1:0] acc_out_ref;
    wire                         out_valid_ref;
    wire                         busy_ref;
    wire                         done_ref;

    wire rst;
    assign rst = ~aresetn;

    systolic_array_4x4_top #(
        .NUM_ROWS   (NUM_ROWS),
        .NUM_COLS   (NUM_COLS),
        .DATA_WIDTH (DATA_WIDTH)
    ) ref_core (
        .clk           (aclk),
        .rst           (rst),
        .start         (start_ref),
        .matrix_a_flat (matrix_a_flat_ref),
        .weight_flat   (weight_flat_ref),
        .acc_out       (acc_out_ref),
        .out_valid     (out_valid_ref),
        .busy          (busy_ref),
        .done          (done_ref)
    );

    //=================================================================
    // SCOREBOARD COUNTERS
    //=================================================================

    integer pass_count;
    integer fail_count;
    integer check_count;

    //=================================================================
    // WATCHDOG
    //=================================================================

    initial begin
        #2000000;
        $display("\n*** TIMEOUT: testbench did not complete in time — likely a hang/deadlock in the wrapper protocol ***");
        $display("=== SUMMARY: %0d checks, %0d passed, %0d failed (INCOMPLETE) ===", check_count, pass_count, fail_count);
        $finish;
    end

    //=================================================================
    // MATRIX BUILD / ACCESS HELPERS  (all packed-vector based)
    //=================================================================

    task automatic build_const(output reg signed [MAT_WIDTH-1:0] flat, input reg signed [7:0] val);
        integer r, c;
        begin
            for (r = 0; r < NUM_ROWS; r = r + 1)
                for (c = 0; c < NUM_COLS; c = c + 1)
                    flat[(r*AXIS_WIDTH)+(c*DATA_WIDTH) +: DATA_WIDTH] = val;
        end
    endtask

    task automatic build_random(output reg signed [MAT_WIDTH-1:0] flat);
        integer r, c;
        begin
            for (r = 0; r < NUM_ROWS; r = r + 1)
                for (c = 0; c < NUM_COLS; c = c + 1)
                    flat[(r*AXIS_WIDTH)+(c*DATA_WIDTH) +: DATA_WIDTH] = $urandom_range(0, 255);
        end
    endtask

    task automatic build_identity_scaled(output reg signed [MAT_WIDTH-1:0] flat, input reg signed [7:0] diag_val);
        integer r, c;
        begin
            for (r = 0; r < NUM_ROWS; r = r + 1)
                for (c = 0; c < NUM_COLS; c = c + 1)
                    flat[(r*AXIS_WIDTH)+(c*DATA_WIDTH) +: DATA_WIDTH] = (r == c) ? diag_val : 8'sd0;
        end
    endtask

    task automatic build_ramp(output reg signed [MAT_WIDTH-1:0] flat, input integer offset);
        integer r, c;
        begin
            for (r = 0; r < NUM_ROWS; r = r + 1)
                for (c = 0; c < NUM_COLS; c = c + 1)
                    flat[(r*AXIS_WIDTH)+(c*DATA_WIDTH) +: DATA_WIDTH] = (r*NUM_COLS + c) - offset;
        end
    endtask

    task automatic build_checkerboard(output reg signed [MAT_WIDTH-1:0] flat, input bit invert);
        integer r, c;
        reg signed [7:0] hi, lo;
        begin
            hi = 8'sd127;
            lo = -8'sd128;
            for (r = 0; r < NUM_ROWS; r = r + 1)
                for (c = 0; c < NUM_COLS; c = c + 1) begin
                    if (((r+c) % 2 == 0) ^ invert)
                        flat[(r*AXIS_WIDTH)+(c*DATA_WIDTH) +: DATA_WIDTH] = hi;
                    else
                        flat[(r*AXIS_WIDTH)+(c*DATA_WIDTH) +: DATA_WIDTH] = lo;
                end
        end
    endtask

    //=================================================================
    // AXI4-STREAM MASTER (DRIVES DUT INPUT)
    //=================================================================

    // Sends one word. If stall_en, randomly deasserts TVALID for a
    // few cycles beforehand to exercise the "waiting for valid" path.
    task automatic axis_send_word(input [AXIS_WIDTH-1:0] data, input bit stall_en);
        integer gap;
        begin
            if (stall_en && $urandom_range(0,1)) begin
                s_axis_tvalid <= 1'b0;
                gap = $urandom_range(1,3);
                repeat (gap) @(posedge aclk);
            end

            s_axis_tdata <= data;
            s_axis_tlast <= 1'b0;   // tlast is unused by the DUT on input; keep low
            s_axis_tvalid <= 1'b1;

            @(posedge aclk);
            while (s_axis_tready !== 1'b1) begin
                @(posedge aclk);
            end
            // handshake occurred on the edge we just crossed
            s_axis_tvalid <= 1'b0;
        end
    endtask

    // Sends a full 8-word packet: 4 weight rows then 4 activation rows.
    task automatic send_packet(
        input reg signed [MAT_WIDTH-1:0] W_flat,
        input reg signed [MAT_WIDTH-1:0] A_flat,
        input bit stall_en
    );
        integer i;
        begin
            for (i = 0; i < 4; i = i + 1)
                axis_send_word(W_flat[i*AXIS_WIDTH +: AXIS_WIDTH], stall_en);
            for (i = 0; i < 4; i = i + 1)
                axis_send_word(A_flat[i*AXIS_WIDTH +: AXIS_WIDTH], stall_en);
        end
    endtask

    //=================================================================
    // AXI4-STREAM SLAVE (RECEIVES DUT OUTPUT)
    //=================================================================

    // Receives the 4-word output packet into a flat 128-bit vector
    // (word i in bits [i*32 +: 32]). Checks TLAST placement (only on
    // the 4th word) as a protocol assertion. If stall_en, randomly
    // deasserts TREADY between words to exercise backpressure.
    task automatic recv_packet(
        output reg [4*AXIS_WIDTH-1:0] words_flat,
        input bit stall_en
    );
        integer i;
        integer gap;
        begin
            for (i = 0; i < 4; i = i + 1) begin
                if (stall_en && $urandom_range(0,1)) begin
                    m_axis_tready <= 1'b0;
                    gap = $urandom_range(1,3);
                    repeat (gap) @(posedge aclk);
                end

                m_axis_tready <= 1'b1;
                @(posedge aclk);
                while (!(m_axis_tvalid && m_axis_tready)) begin
                    @(posedge aclk);
                end

                words_flat[i*AXIS_WIDTH +: AXIS_WIDTH] = m_axis_tdata;

                // --- protocol check: TLAST only on word index 3 ---
                check_count = check_count + 1;
                if (i == 3) begin
                    if (m_axis_tlast === 1'b1) begin
                        pass_count = pass_count + 1;
                    end else begin
                        fail_count = fail_count + 1;
                        $display("[%0t] FAIL: TLAST not asserted on final (4th) output word", $time);
                    end
                end else begin
                    if (m_axis_tlast === 1'b0) begin
                        pass_count = pass_count + 1;
                    end else begin
                        fail_count = fail_count + 1;
                        $display("[%0t] FAIL: TLAST asserted early on output word index %0d", $time, i);
                    end
                end
            end
            m_axis_tready <= 1'b0;
        end
    endtask

    //=================================================================
    // GOLDEN REFERENCE TASK — drives REF core directly, no AXIS
    //=================================================================

    task automatic compute_reference(
        input  reg signed [MAT_WIDTH-1:0] W_flat,
        input  reg signed [MAT_WIDTH-1:0] A_flat,
        output reg signed [ACCS_WIDTH-1:0] ref_acc_flat
    );
        begin
            weight_flat_ref <= W_flat;
            matrix_a_flat_ref <= A_flat;

            start_ref <= 1'b1;
            @(posedge aclk);
            start_ref <= 1'b0;

            while (!done_ref) @(posedge aclk);

            ref_acc_flat = acc_out_ref;

            // let feeder return S_DONE -> S_IDLE before reusing it
            @(posedge aclk);
        end
    endtask

    //=================================================================
    // TOP-LEVEL SCOREBOARD COMPARE FOR ONE PACKET
    //=================================================================

    task automatic check_result(
        input reg [4*AXIS_WIDTH-1:0]  words_flat,
        input reg signed [ACCS_WIDTH-1:0] ref_acc_flat,
        input string test_name
    );
        integer c;
        reg signed [ACC_WIDTH-1:0] got, exp;
        reg [AXIS_WIDTH-1:0] w;
        begin
            for (c = 0; c < 4; c = c + 1) begin
                w   = words_flat[c*AXIS_WIDTH +: AXIS_WIDTH];
                got = w[ACC_WIDTH-1:0];
                exp = ref_acc_flat[c*ACC_WIDTH +: ACC_WIDTH];
                check_count = check_count + 1;

                // upper bits of the AXI word must always be zero-padded
                if (w[AXIS_WIDTH-1:ACC_WIDTH] !== {(AXIS_WIDTH-ACC_WIDTH){1'b0}}) begin
                    fail_count = fail_count + 1;
                    $display("[%0t] FAIL (%s): column %0d output word has non-zero padding bits: %h",
                              $time, test_name, c, w);
                end else if (got === exp) begin
                    pass_count = pass_count + 1;
                end else begin
                    fail_count = fail_count + 1;
                    $display("[%0t] FAIL (%s): column %0d mismatch. DUT=%0d (0x%h)  REF=%0d (0x%h)",
                              $time, test_name, c, got, got, exp, exp);
                end
            end
        end
    endtask

    //=================================================================
    // ONE COMPLETE DIRECTED/RANDOM TEST: build matrices, run both
    // paths, compare.
    //=================================================================

    task automatic run_test(
        input reg signed [MAT_WIDTH-1:0] W_flat,
        input reg signed [MAT_WIDTH-1:0] A_flat,
        input bit stall_en,
        input string test_name
    );
        reg signed [ACCS_WIDTH-1:0] ref_acc_flat;
        reg [4*AXIS_WIDTH-1:0] words_flat;
        begin
            compute_reference(W_flat, A_flat, ref_acc_flat);
            send_packet(W_flat, A_flat, stall_en);
            recv_packet(words_flat, stall_en);
            check_result(words_flat, ref_acc_flat, test_name);
        end
    endtask

    //=================================================================
    // WHITEBOX PROTOCOL ASSERTION
    //
    // Hierarchical peek into the DUT's internal state register to
    // confirm TREADY is only ever asserted in S_RECEIVE. Runs
    // continuously in the background for the whole simulation.
    //=================================================================

    always @(posedge aclk) begin
        if (aresetn) begin
            check_count = check_count + 1;
            if (s_axis_tready === (dut.state == dut.S_RECEIVE)) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("[%0t] FAIL: s_axis_tready (%b) inconsistent with state==S_RECEIVE (state=%0d)",
                          $time, s_axis_tready, dut.state);
            end
        end
    end

    //=================================================================
    // MAIN TEST SEQUENCE
    //=================================================================

    reg signed [MAT_WIDTH-1:0] W_flat, A_flat, W2_flat, A2_flat;
    reg signed [ACCS_WIDTH-1:0] ref_acc_flat;
    reg [4*AXIS_WIDTH-1:0] words_flat;

    integer i;

    initial begin
        pass_count  = 0;
        fail_count  = 0;
        check_count = 0;

        s_axis_tdata <= 0;
        s_axis_tvalid <= 0;
        s_axis_tlast <= 0;
        m_axis_tready <= 0;
        start_ref <= 0;
        matrix_a_flat_ref <= 0;
        weight_flat_ref <= 0;

        aresetn <= 1'b0;
        repeat (5) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);

        $display("=====================================================");
        $display(" axis_systolic_array wrapper self-checking testbench ");
        $display("=====================================================");

        //-------------------------------------------------------------
        // DIRECTED TEST 1: all-zero matrices
        //-------------------------------------------------------------
        build_const(W_flat, 8'sd0);
        build_const(A_flat, 8'sd0);
        run_test(W_flat, A_flat, 1'b0, "zero_matrices_no_stall");

        //-------------------------------------------------------------
        // DIRECTED TEST 2: max positive (127) on both matrices
        //-------------------------------------------------------------
        build_const(W_flat, 8'sd127);
        build_const(A_flat, 8'sd127);
        run_test(W_flat, A_flat, 1'b0, "max_positive_no_stall");

        //-------------------------------------------------------------
        // DIRECTED TEST 3: max negative (-128) on both matrices
        //-------------------------------------------------------------
        build_const(W_flat, -8'sd128);
        build_const(A_flat, -8'sd128);
        run_test(W_flat, A_flat, 1'b0, "max_negative_no_stall");

        //-------------------------------------------------------------
        // DIRECTED TEST 4: identity weight, ramp activation,
        // driven WITH random input/output stalls
        //-------------------------------------------------------------
        build_identity_scaled(W_flat, 8'sd1);
        build_ramp(A_flat, 8);
        run_test(W_flat, A_flat, 1'b1, "identity_weight_with_stalls");

        //-------------------------------------------------------------
        // DIRECTED TEST 5: checkerboard signs, alternating extremes
        //-------------------------------------------------------------
        build_checkerboard(W_flat, 1'b0);
        build_checkerboard(A_flat, 1'b1);
        run_test(W_flat, A_flat, 1'b1, "checkerboard_extremes_with_stalls");

        //-------------------------------------------------------------
        // RANDOM REGRESSION: mix of stall/no-stall
        //-------------------------------------------------------------
        for (i = 0; i < 40; i = i + 1) begin
            build_random(W_flat);
            build_random(A_flat);
            run_test(W_flat, A_flat, $urandom_range(0,1), $sformatf("random_%0d", i));
        end

        //-------------------------------------------------------------
        // BACK-TO-BACK TEST: several packets sent with zero idle gap
        // between the last output word of packet N and the first
        // input word of packet N+1.
        //-------------------------------------------------------------
        for (i = 0; i < 5; i = i + 1) begin
            build_random(W_flat);
            build_random(A_flat);
            compute_reference(W_flat, A_flat, ref_acc_flat);
            send_packet(W_flat, A_flat, 1'b0);
            recv_packet(words_flat, 1'b0);
            check_result(words_flat, ref_acc_flat, $sformatf("back_to_back_%0d", i));
        end

        //-------------------------------------------------------------
        // RESET-MID-PACKET TEST:
        // Start sending a packet, assert reset partway through
        // (after 3 of 8 words), then confirm the wrapper discards the
        // partial packet and correctly accepts a brand new one
        // starting at word 0.
        //-------------------------------------------------------------
        build_random(W_flat);
        build_random(A_flat);
        axis_send_word(W_flat[0*AXIS_WIDTH +: AXIS_WIDTH], 1'b0);
        axis_send_word(W_flat[1*AXIS_WIDTH +: AXIS_WIDTH], 1'b0);
        axis_send_word(W_flat[2*AXIS_WIDTH +: AXIS_WIDTH], 1'b0);

        // assert reset mid-stream
        aresetn <= 1'b0;
        s_axis_tvalid <= 1'b0;
        repeat (3) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);

        check_count = check_count + 1;
        if (dut.state == dut.S_RECEIVE && dut.input_count == 4'd0) begin
            pass_count = pass_count + 1;
        end else begin
            fail_count = fail_count + 1;
            $display("[%0t] FAIL: wrapper did not return to a clean S_RECEIVE/input_count=0 after reset", $time);
        end

        // now send a full fresh packet and confirm it computes correctly,
        // proving the aborted partial packet did not leak into this one
        build_random(W2_flat);
        build_random(A2_flat);
        run_test(W2_flat, A2_flat, 1'b0, "post_reset_fresh_packet");

        //-------------------------------------------------------------
        // SUMMARY
        //-------------------------------------------------------------
        repeat (5) @(posedge aclk);

        $display("=====================================================");
        $display(" SUMMARY: %0d checks, %0d passed, %0d failed",
                  check_count, pass_count, fail_count);
        if (fail_count == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: %0d TEST(S) FAILED", fail_count);
        $display("=====================================================");

        $finish;
    end

endmodule


