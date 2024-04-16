// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import sfm_pkg::*;
import fpnew_pkg::*;

module expu_correction #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = fpnew_pkg::FP16ALT        ,
    parameter int unsigned              COEFFICIENT_FRACTION    = EXPU_COEFFICIENT_FRACTION ,
    parameter int unsigned              CONSTANT_FRACTION       = EXPU_CONSTANT_FRACTION    ,
    parameter int unsigned              MUL_SURPLUS_BITS        = EXPU_MUL_SURPLUS_BITS     ,
    parameter int unsigned              NOT_SURPLUS_BITS        = EXPU_NOT_SURPLUS_BITS     ,
    parameter real                      ALPHA_REAL              = EXPU_ALPHA_REAL           ,
    parameter real                      BETA_REAL               = EXPU_BETA_REAL            ,
    parameter real                      GAMMA_1_REAL            = EXPU_GAMMA_1_REAL         ,
    parameter real                      GAMMA_2_REAL            = EXPU_GAMMA_2_REAL         ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT)
) (
    input   logic [WIDTH - 1 : 0]  op_i     ,
    output  logic [WIDTH - 1 : 0]  res_o    
);

    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT);
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT);
    localparam int unsigned SUM_FRACTION    = MANTISSA_BITS > CONSTANT_FRACTION ? MANTISSA_BITS : CONSTANT_FRACTION;

    logic [EXPONENT_BITS - 1 : 0]               exponent;
    //Q<1.MANTISSA_BITS>
    logic [MANTISSA_BITS : 0]                   mantissa;

    //Q<-1.CONSTANT_FRACTION>
    localparam int unsigned ALPHA   = int'(ALPHA_REAL * 2 ** COEFFICIENT_FRACTION);
    localparam int unsigned BETA    = int'(BETA_REAL * 2 ** COEFFICIENT_FRACTION);

    //Q<2.COEFFICIENT_FRACTION>
    localparam int unsigned GAMMA_1 = int'(GAMMA_1_REAL * 2 ** CONSTANT_FRACTION);
    localparam int unsigned GAMMA_2 = int'(GAMMA_2_REAL * 2 ** CONSTANT_FRACTION);

    //Q<-1.MANTISSA_BITS + MUL_SURPLUS_BITS>
    logic [MANTISSA_BITS - 2 + MUL_SURPLUS_BITS : 0]   mant_mul_1;

    //Q<-1.COEFFICIENT_FRACTION>
    logic [COEFFICIENT_FRACTION - 2 : 0]                alpha_beta_mul_1;

    //Q<0.SUM_FRACTION>
    logic [SUM_FRACTION - 1 : 0]                        mant_add_1;

    //Q<2.SUM_FRACTION>
    logic [SUM_FRACTION + 1 : 0]                        gamma_add_1;

    //Q<2.SUM_FRACTION>
    logic [SUM_FRACTION + 1 : 0]                        res_add_1;

    //Q<-2.COEF + INPUT + MUL_SURPLUS_BITS>
    logic [MANTISSA_BITS + COEFFICIENT_FRACTION + MUL_SURPLUS_BITS -3 : 0]                 res_mul_1;

    //Q<0.MANTISSA_BITS + SUM_FRACTION + COEFFICIENT_FRACTION + MUL_SURPLUS_BITS>
    logic [MANTISSA_BITS + SUM_FRACTION + COEFFICIENT_FRACTION + MUL_SURPLUS_BITS - 1: 0]  res_mul_2;

    //Q<0.MANTISSA_BITS + NOT_SURPLUS_BITS>
    logic [MANTISSA_BITS + NOT_SURPLUS_BITS - 1 : 0]                                       res_pre_inversion;

    logic [MANTISSA_BITS - 1 : 0]   corrected_mantissa;

    assign exponent =   op_i   [WIDTH - 2 -: EXPONENT_BITS];
    assign mantissa =   {1'b1, op_i [MANTISSA_BITS - 1 : 0]};

    assign mant_mul_1           = mantissa [MANTISSA_BITS - 1] == 1'b0 ? {mantissa [MANTISSA_BITS - 2 : 0], {MUL_SURPLUS_BITS{1'b0}}} : ~{mantissa [MANTISSA_BITS - 1 : 0], {MUL_SURPLUS_BITS{1'b0}}};
    assign alpha_beta_mul_1     = mantissa [MANTISSA_BITS - 1] == 1'b0 ? ALPHA : BETA;

    assign res_mul_1            = mant_mul_1 * alpha_beta_mul_1;

    assign mant_add_1           = {mantissa, {(SUM_FRACTION - MANTISSA_BITS){1'b0}}};
    assign gamma_add_1          = {mantissa [MANTISSA_BITS - 1] == 1'b0 ? GAMMA_1 : GAMMA_2, {(SUM_FRACTION - CONSTANT_FRACTION){1'b0}}};

    assign res_add_1            = mant_add_1 + gamma_add_1;

    assign res_mul_2            = res_mul_1 * res_add_1;
    
    assign res_pre_inversion    = res_mul_2 >> (SUM_FRACTION + COEFFICIENT_FRACTION + MUL_SURPLUS_BITS - NOT_SURPLUS_BITS);

    assign corrected_mantissa   = (mantissa [MANTISSA_BITS - 1] == 1'b0 ? res_pre_inversion : ~res_pre_inversion) >> NOT_SURPLUS_BITS;

    assign res_o                = {1'b0, exponent, corrected_mantissa};

endmodule