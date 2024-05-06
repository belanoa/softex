// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import sfm_pkg::*;
import hwpe_stream_package::*;

module sfm_cast_out #(
    parameter int unsigned              DATA_WIDTH  = DATA_W        ,
    parameter fpnew_pkg::fp_format_e    FPFORMAT    = FPFORMAT_IN   ,
    parameter int unsigned              INT_WIDTH   = INT_W          
) (
    input cast_ctrl_t               ctrl_i      ,

    hwpe_stream_intf_stream.sink    stream_i    ,
    hwpe_stream_intf_stream.source  stream_o 
);

    localparam int unsigned ACTUAL_DW       =   DATA_WIDTH - 32;

    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT);
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT);
    localparam int unsigned BIAS            = fpnew_pkg::bias(FPFORMAT); 
    localparam int unsigned FP_WIDTH        = fpnew_pkg::fp_width(FPFORMAT);

    localparam int unsigned SHIFTED_LENGTH  = MANTISSA_BITS > INT_WIDTH ? MANTISSA_BITS + 1 : INT_WIDTH + 1;

    localparam int unsigned NUM_ROWS        = ACTUAL_DW / FP_WIDTH;

    logic [NUM_ROWS - 1 : 0] [FP_WIDTH - 1 : 0] i_data;

    logic [NUM_ROWS - 1 : 0] [EXPONENT_BITS - 1 : 0] exponents;
    logic [NUM_ROWS - 1 : 0] [MANTISSA_BITS - 1 : 0] mantissae;

    logic [NUM_ROWS - 1 : 0] ovrf;

    logic [NUM_ROWS - 1 : 0] [SHIFTED_LENGTH - 1 : 0] shifted_mantissae;
    
    logic [NUM_ROWS - 1 : 0] [INT_WIDTH - 1 : 0] results;

    logic [NUM_ROWS - 1 : 0] [INT_WIDTH/8 - 1 : 0] strbs;

    assign i_data = stream_i.data [ACTUAL_DW - 1 : 0];

    for (genvar i = 0; i < NUM_ROWS; i++) begin : exponents_assignment
        assign exponents [i] = i_data [i] [FP_WIDTH - 2 -: EXPONENT_BITS];
    end

    for (genvar i = 0; i < NUM_ROWS; i++) begin : mantissae_assignment
        assign mantissae [i] = i_data [i] [MANTISSA_BITS - 1 : 0];
    end

    // As the accelerator only outputs positive numbers in the range [0, 1] many cheks are skipped

    for (genvar i = 0; i < NUM_ROWS; i++) begin : overflow_assignment
        assign ovrf [i] = signed'(BIAS + ctrl_i.is_signed) + ctrl_i.int_bits < signed'(exponents [i] + 1);
    end

    for (genvar i = 0; i < NUM_ROWS; i++) begin : shifted_mantissae_assignment
        assign shifted_mantissae [i] = ovrf [i] ? '1 : ({1'b1, mantissae [i], {(SHIFTED_LENGTH - MANTISSA_BITS - 1){1'b0}}} >> (signed'(BIAS - exponents [i] - 1 + ctrl_i.is_signed) + ctrl_i.int_bits));
    end

    always_comb begin : results_assignment
        for (int i = 0; i < NUM_ROWS; i++) begin
            if (ctrl_i.is_signed & ovrf [i]) begin
                results [i] = {1'b0, shifted_mantissae [i] [SHIFTED_LENGTH - 2 : 1]} [SHIFTED_LENGTH - 1 -: INT_WIDTH];
            end else begin
                results [i] = shifted_mantissae [i] [SHIFTED_LENGTH - 1 -: INT_WIDTH] + shifted_mantissae [i] [SHIFTED_LENGTH - INT_WIDTH - 1];
            end
        end
    end

    for (genvar i = 0; i < NUM_ROWS; i++) begin
        assign strbs [i] = {(INT_WIDTH/8){&stream_i.strb [i * FP_WIDTH / 8 +: FP_WIDTH / 8]}};
    end

    assign stream_i.ready   = stream_o.ready;

    assign stream_o.valid   = stream_i.valid;
    assign stream_o.data    = ctrl_i.enable ? {32'b0, results} : stream_i.data;
    assign stream_o.strb    = ctrl_i.enable ? {4'b0, strbs} : stream_i.strb;

endmodule