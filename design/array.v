
`timescale 1ns / 1ps

//=====================================================================
// 4x4 WEIGHT-STATIONARY SYSTOLIC ARRAY
//
// Architecture:
//
//              COLUMN 0        COLUMN 1        COLUMN 2        COLUMN 3
//
// ROW 0       PE[0][0] ----> PE[0][1] ----> PE[0][2] ----> PE[0][3]
//                |               |               |               |
//                v               v               v               v
// ROW 1       PE[1][0] ----> PE[1][1] ----> PE[1][2] ----> PE[1][3]
//                |               |               |               |
//                v               v               v               v
// ROW 2       PE[2][0] ----> PE[2][1] ----> PE[2][2] ----> PE[2][3]
//                |               |               |               |
//                v               v               v               v
// ROW 3       PE[3][0] ----> PE[3][1] ----> PE[3][2] ----> PE[3][3]
//                |               |               |               |
//                v               v               v               v
//             ACC[0]          ACC[1]          ACC[2]          ACC[3]
//
// Activation : LEFT  -> RIGHT
// Partial Sum: TOP   -> BOTTOM
// Weight     : LOCAL / STATIONARY
//
// Total PEs = 4 x 4 = 16
//=====================================================================

module systolic_array_4x4 #(
    parameter NUM_ROWS   = 4,
    parameter NUM_COLS   = 4,
    parameter DATA_WIDTH = 8
)(
    input  wire clk,
    input  wire rst,

    //=============================================================
    // WEIGHT LOAD CONTROL
    //=============================================================

    input  wire load_weight,

    //=============================================================
    // WEIGHT MATRIX
    //
    // Packing:
    //
    // weight_in[  7:  0] = W[0][0]
    // weight_in[ 15:  8] = W[0][1]
    // weight_in[ 23: 16] = W[0][2]
    // weight_in[ 31: 24] = W[0][3]
    //
    // weight_in[ 39: 32] = W[1][0]
    // ...
    //
    // weight_in[127:120] = W[3][3]
    //=============================================================

    input wire signed
    [NUM_ROWS*NUM_COLS*DATA_WIDTH-1:0] weight_in,

    //=============================================================
    // ACTIVATION INPUT
    //
    // One activation enters each row at column 0.
    //
    // a_in[ 7: 0] = Row 0
    // a_in[15: 8] = Row 1
    // a_in[23:16] = Row 2
    // a_in[31:24] = Row 3
    //=============================================================

    input wire signed
    [NUM_ROWS*DATA_WIDTH-1:0] a_in,

    //=============================================================
    // ACCUMULATED OUTPUT
    //
    // One partial-sum result exits from the bottom of each column.
    //
    // ACC_WIDTH = 2*DATA_WIDTH + 1
    //
    // acc_out[  8:  0] = Column 0 result
    // acc_out[ 17:  9] = Column 1 result
    // acc_out[ 26: 18] = Column 2 result
    // acc_out[ 35: 27] = Column 3 result
    //=============================================================

    output wire signed
    [NUM_COLS*(2*DATA_WIDTH+1)-1:0] acc_out,

    //=============================================================
    // RIGHT EDGE ACTIVATION OUTPUT
    //
    // Allows another systolic array to be chained later.
    //=============================================================

    output wire signed
    [NUM_ROWS*DATA_WIDTH-1:0] a_out
);

    //=================================================================
    // LOCAL PARAMETERS
    //=================================================================

    localparam ACC_WIDTH = (2*DATA_WIDTH) + 1;

    //=================================================================
    // HORIZONTAL ACTIVATION WIRES
    //
    // a_grid[r][0]
    //      = external activation entering row r
    //
    // a_grid[r][1]
    //      = PE[r][0].a_out
    //
    // a_grid[r][2]
    //      = PE[r][1].a_out
    //
    // a_grid[r][3]
    //      = PE[r][2].a_out
    //
    // a_grid[r][4]
    //      = PE[r][3].a_out
    //
    // Therefore each row needs NUM_COLS + 1 nodes.
    //=================================================================

    wire signed [DATA_WIDTH-1:0]
        a_grid [0:NUM_ROWS-1][0:NUM_COLS];

    //=================================================================
    // VERTICAL PARTIAL-SUM WIRES
    //
    // psum_grid[0][c]
    //      = top boundary, initialized to zero
    //
    // psum_grid[1][c]
    //      = PE[0][c].psum_out
    //
    // psum_grid[2][c]
    //      = PE[1][c].psum_out
    //
    // psum_grid[3][c]
    //      = PE[2][c].psum_out
    //
    // psum_grid[4][c]
    //      = PE[3][c].psum_out
    //
    // Therefore each column needs NUM_ROWS + 1 nodes.
    //=================================================================

    wire signed [ACC_WIDTH-1:0]
        psum_grid [0:NUM_ROWS][0:NUM_COLS-1];

    //=================================================================
    // WEIGHT WIRES
    //
    // One weight wire for every PE.
    //=================================================================

    wire signed [DATA_WIDTH-1:0]
        weight_grid [0:NUM_ROWS-1][0:NUM_COLS-1];

    //=================================================================
    // BOUNDARY CONNECTIONS
    //=================================================================

    genvar r;
    genvar c;

    generate

        //=============================================================
        // ACTIVATION INPUTS
        //=============================================================

        for (r = 0; r < NUM_ROWS; r = r + 1) begin : ROW_INPUT_CONNECTIONS

            assign a_grid[r][0] =
                a_in[
                    r*DATA_WIDTH +: DATA_WIDTH
                ];

            //=========================================================
            // RIGHT EDGE OUTPUT
            //=========================================================

            assign a_out[
                r*DATA_WIDTH +: DATA_WIDTH
            ] = a_grid[r][NUM_COLS];

        end

        //=============================================================
        // TOP PARTIAL-SUM BOUNDARY
        //
        // Every column starts with zero partial sum.
        //=============================================================

        for (c = 0; c < NUM_COLS; c = c + 1) begin : COLUMN_INPUT_CONNECTIONS

            assign psum_grid[0][c] = {ACC_WIDTH{1'b0}};

            //=========================================================
            // BOTTOM ACCUMULATOR OUTPUT
            //=========================================================

            assign acc_out[
                c*ACC_WIDTH +: ACC_WIDTH
            ] = psum_grid[NUM_ROWS][c];

        end

        //=============================================================
        // WEIGHT MATRIX CONNECTIONS
        //=============================================================

        for (r = 0; r < NUM_ROWS; r = r + 1) begin : WEIGHT_ROW_CONNECTIONS

            for (c = 0; c < NUM_COLS; c = c + 1) begin : WEIGHT_COLUMN_CONNECTIONS

                assign weight_grid[r][c] =
                    weight_in[
                        (r*NUM_COLS + c)*DATA_WIDTH
                        +: DATA_WIDTH
                    ];

            end

        end

    endgenerate

    //=================================================================
    // 16 PROCESSING ELEMENTS
    //
    // ROW 0:
    //
    // PE[0][0] PE[0][1] PE[0][2] PE[0][3]
    //
    // ROW 1:
    //
    // PE[1][0] PE[1][1] PE[1][2] PE[1][3]
    //
    // ROW 2:
    //
    // PE[2][0] PE[2][1] PE[2][2] PE[2][3]
    //
    // ROW 3:
    //
    // PE[3][0] PE[3][1] PE[3][2] PE[3][3]
    //
    //=================================================================

    generate

        for (r = 0; r < NUM_ROWS; r = r + 1) begin : pe_row

            for (c = 0; c < NUM_COLS; c = c + 1) begin : pe_col

                processing_element_2d #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) pe_inst (
                    //=================================================
                    // CLOCK / RESET
                    //=================================================

                    .clk(clk),
                    .rst(rst),

                    //=================================================
                    // WEIGHT
                    //=================================================

                    .load_weight(load_weight),
                    .weight_in(weight_grid[r][c]),

                    //=================================================
                    // ACTIVATION
                    //
                    // Comes from left.
                    // Goes to right.
                    //=================================================

                    .a_in(a_grid[r][c]),
                    .a_out(a_grid[r][c+1]),

                    //=================================================
                    // PARTIAL SUM
                    //
                    // Comes from above.
                    // Goes downward.
                    //=================================================

                    .psum_in(psum_grid[r][c]),
                    .psum_out(psum_grid[r+1][c])
                );

            end

        end

    endgenerate

endmodule

