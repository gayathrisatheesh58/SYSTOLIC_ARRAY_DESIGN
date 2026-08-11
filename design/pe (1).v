
`timescale 1ns / 1ps

//=====================================================================
// PROCESSING ELEMENT - 2D SYSTOLIC ARRAY
//
// Architecture:
//   Weight Stationary
//   Activation  -> Right
//   Partial Sum -> Down
//
// Two-cycle MAC datapath:
//
//   STAGE 1:
//       product_reg = a_in * w_reg
//
//   STAGE 2:
//       accumulator = accumulator + product_reg
//
// The accumulator is persistent and therefore retains the running
// sum across multiple systolic data cycles.
//
// The accumulated result is forwarded downward through psum_out.
//=====================================================================

module processing_element_2d #(
    parameter DATA_WIDTH = 8
)(
    input  wire                         clk,
    input  wire                         rst,

    //=============================================================
    // WEIGHT INTERFACE
    //=============================================================

    input  wire                         load_weight,
    input  wire signed [DATA_WIDTH-1:0] weight_in,

    //=============================================================
    // ACTIVATION PATH
    //=============================================================

    input  wire signed [DATA_WIDTH-1:0] a_in,
    output reg  signed [DATA_WIDTH-1:0] a_out,

    //=============================================================
    // PARTIAL SUM PATH
    //
    // Width = 2*DATA_WIDTH + 1 bits
    //=============================================================

    input  wire signed [(2*DATA_WIDTH):0] psum_in,
    output reg  signed [(2*DATA_WIDTH):0] psum_out
);

    //=============================================================
    // LOCAL STATIONARY WEIGHT
    //=============================================================

    reg signed [DATA_WIDTH-1:0] w_reg;


    //=============================================================
    // PIPELINE STAGE 1
    //
    // Multiplication is performed here.
    //
    // product_reg = activation × stationary weight
    //=============================================================

    reg signed [(2*DATA_WIDTH)-1:0] product_reg;


    //=============================================================
    // PIPELINE STAGE 1 - PARTIAL SUM DELAY
    //
    // Incoming partial sum is delayed so that it remains aligned
    // with product_reg.
    //=============================================================

    reg signed [(2*DATA_WIDTH):0] psum_reg;


    //=============================================================
    // LOCAL ACCUMULATOR
    //
    // IMPORTANT:
    //
    // This register retains the accumulated value from one cycle
    // to the next.
    //
    // accumulator <= accumulator + product_reg
    //
    // This is what makes the PE a true MAC element.
    //=============================================================

    reg signed [(2*DATA_WIDTH):0] accumulator;


    //=============================================================
    // WEIGHT REGISTER
    //
    // Weight is loaded once and then remains stationary.
    //=============================================================

    always @(posedge clk) begin

        if (rst) begin

            w_reg <= 0;

        end

        else if (load_weight) begin

            w_reg <= weight_in;

        end

    end


    //=============================================================
    // TWO-CYCLE PIPELINED MAC
    //=============================================================

    always @(posedge clk) begin

        if (rst) begin

            a_out      <= 0;
            product_reg <= 0;
            psum_reg   <= 0;
            accumulator <= 0;
            psum_out   <= 0;

        end

        else begin

            //=====================================================
            // ACTIVATION FORWARDING
            //
            // Activation moves one PE to the right every cycle.
            //=====================================================

            a_out <= a_in;


            //=====================================================
            // STAGE 1 : MULTIPLICATION
            //=====================================================

            product_reg <= a_in * w_reg;


            //=====================================================
            // DELAY INCOMING PARTIAL SUM
            //=====================================================

            psum_reg <= psum_in;


            //=====================================================
            // STAGE 2 : ACCUMULATION
            //
            // The PE now keeps a running sum.
            //
            // accumulator[n+1] =
            //       accumulator[n] + product_reg[n]
            //=====================================================

            accumulator <= accumulator + product_reg;


            //=====================================================
            // PARTIAL SUM OUTPUT
            //
            // Forward the accumulated result downward.
            //
            // psum_reg is also included so an incoming partial sum
            // can participate in the computation.
            //=====================================================

            psum_out <= psum_reg + accumulator + product_reg;

        end

    end

endmodule
