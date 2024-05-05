// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import sfm_pkg::*;
import hwpe_stream_package::*;

module sfm_cast_in #(
    parameter int unsigned                      DATA_WIDTH  = DATA_W        ,
    parameter int unsigned                      FPFORMAT    = FPFORMAT_IN   ,
    parameter int unsigned                      INT_WIDTH   = INT_W          
) (
    input cast_ctrl_t               ctrl_i      ,

    hwpe_stream_intf_stream.sink    stream_i    ,
    hwpe_stream_intf_stream.source  stream_o 
);

    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT);
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT);
    localparam int unsigned BIAS            = fpnew_pkg::bias(FPFORMAT); 
    localparam int unsigned FP_WIDTH        = fpnew_pkg::fp_width(FPFORMAT);

    localparam int unsigned TREE_DEPTH      = $clog2(INT_WIDTH / 2); 

    localparam int unsigned NUM_ROWS        = INT_WIDTH > FP_WIDTH ? DATA_WIDTH / INT_WIDTH : DATA_WIDTH / FP_WIDTH;

    logic [NUM_ROWS - 1 : 0] [INT_WIDTH - 1 : 0]    signed_data,
                                                    unsigned_data;

    logic [NUM_ROWS * INT_WIDTH - 1 : 0]    cnt_data;

    logic [NUM_ROWS - 1 : 0]    sign_mask;

    logic [TREE_DEPTH : 0] [NUM_ROWS * INT_WIDTH / 2 - 1 : 0] [$clog2(INT_WIDTH) : 0]   leading_zeros;

    logic [NUM_ROWS - 1 : 0] [MANTISSA_BITS - 1 : 0] mantissae;
    logic [NUM_ROWS - 1 : 0] [EXPONENT_BITS - 1 : 0] exponents;

    logic [NUM_ROWS - 1 : 0] [FP_WIDTH - 1 : 0] results;

    logic [NUM_ROWS - 1 : 0] [FP_WIDTH/8 - 1 : 0] strbs;

    assign signed_data = stream_i.data [NUM_ROWS * INT_WIDTH - 1 : 0];

    for (genvar i = 0; i < NUM_ROWS; i++) begin : compute_2s_complement
        assign unsigned_data [i]    = ctrl_i.is_signed & signed_data [i] [INT_WIDTH - 1] ? ~(signed_data [i]) + 1 : signed_data [i];
        assign sign_mask [i]        = ctrl_i.is_signed & signed_data [i] [INT_WIDTH - 1];
    end

    assign cnt_data = unsigned_data;

    // We start counting the number of leading zeros by considering 2 bit integers
    always_comb begin : initial_encoding
        for (int i = 0; i < NUM_ROWS * INT_WIDTH / 2; i++) begin 
            casex (cnt_data [2 * i +: 2])
                2'b1?:  leading_zeros [0] [i] = 0;
                2'b01:  leading_zeros [0] [i] = 1;
                2'b00:  leading_zeros [0] [i] = 2;
            endcase
        end
    end

    // We continue counting the number of leading zeros of 2**n bit integers by joining adjacent leading zero counts
    for (genvar ii = 0; ii < TREE_DEPTH; ii++) begin : generate_leading_zero_tree
        always_comb begin
            leading_zeros [ii + 1] = '0;

            for (int i = 0; i < (NUM_ROWS * INT_WIDTH / 2) >> (ii + 1); i++) begin

                // We only need to check if only zeros have been found up to this point
                casex ({leading_zeros [ii] [2 * i + 1] [ii + 1], leading_zeros [ii] [2 * i] [ii + 1]})
                    2'b11:  leading_zeros [ii + 1] [i] = 2 * (ii + 2);
                    2'b10:  leading_zeros [ii + 1] [i] = {leading_zeros [ii] [2 * i + 1] [$clog2(INT_WIDTH) -: TREE_DEPTH - ii + 1], leading_zeros [ii] [2 * i] [ii : 0]};
                    2'b0?:  leading_zeros [ii + 1] [i] = leading_zeros [ii] [2 * i + 1];
                endcase
            end
        end
    end

    for (genvar i = 0; i < NUM_ROWS; i++) begin : assign_mantissae
        if (INT_WIDTH >= MANTISSA_BITS) begin
            assign mantissae [i] = {(unsigned_data [i] << (leading_zeros [TREE_DEPTH] [i] + 1))} [INT_WIDTH - 1 -: MANTISSA_BITS];
        end else begin
            assign mantissae [i] = {{(unsigned_data [i] << (leading_zeros [TREE_DEPTH] [i] + 1))}, {(MANTISSA_BITS - INT_WIDTH){1'b0}}};
        end
    end
    
    for (genvar i = 0; i < NUM_ROWS; i++) begin : assign_exponents
        assign exponents [i] = leading_zeros [TREE_DEPTH] [i] [$clog2(INT_WIDTH)] ? '0 : signed'(BIAS - 1 - leading_zeros [TREE_DEPTH] [i] + ctrl_i.is_signed) + ctrl_i.int_bits;
    end

    for (genvar i = 0; i < NUM_ROWS; i++) begin : assign_results
        assign results [i] = {sign_mask [i], exponents [i], mantissae [i]};
    end

    for (genvar i = 0; i < NUM_ROWS; i++) begin : assign_strbs
        assign strbs [i] = {(FP_WIDTH/8){stream_i.strb [(INT_WIDTH/8) * i +: (INT_WIDTH/8)]}};
    end

    assign stream_i.ready   = stream_o.ready;

    assign stream_o.valid   = stream_i.valid;
    assign stream_o.data    = ctrl_i.enable ? {{((DATA_WIDTH / FP_WIDTH - NUM_ROWS) * FP_WIDTH){1'b0}}, results} : stream_i.data;
    assign stream_o.strb    = ctrl_i.enable ? {{((DATA_WIDTH / FP_WIDTH - NUM_ROWS) * FP_WIDTH/8){1'b0}}, strbs} : stream_i.strb;

endmodule