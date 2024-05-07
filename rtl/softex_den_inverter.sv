// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

`include "softex_macros.svh"

module softex_den_inverter #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT    = fpnew_pkg::FP32   ,
    parameter softex_pkg::regs_config_t    REG_POS     = softex_pkg::BEFORE   ,
    parameter int unsigned              NUM_REGS    = 2                 ,
    parameter int unsigned              N_MANT_BITS = 7                 ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT)
) (
    input   logic                   clk_i   ,
    input   logic                   rst_ni  ,
    input   logic                   clear_i ,
    input   logic                   valid_i ,
    input   logic                   ready_i ,
    input   logic [WIDTH - 1 : 0]   den_i   ,
    output  logic                   ready_o ,
    output  logic                   valid_o ,
    output  logic [WIDTH - 1 : 0]   inv_o
);

    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT);
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT);
    localparam int unsigned BIAS            = fpnew_pkg::bias(FPFORMAT);

    logic [WIDTH - 1 : 0]   den_del,
                            res;

    logic [EXPONENT_BITS - 1 : 0]   exponent,
                                    out_exponent;

    logic [MANTISSA_BITS - 1 : 0]   mantissa,
                                    out_mantissa;

    logic [N_MANT_BITS - 1 : 0] mantissa_sel,
                                mantissa_n;

    logic [2 * N_MANT_BITS - 2 : 0] mantissa_prod;

    logic sign;

    softex_pipeline #(
        .REG_POS    (   REG_POS     ),
        .NUM_REGS   (   NUM_REGS    ),
        .WIDTH_IN   (   WIDTH       ),
        .NUM_IN     (   1           ),
        .WIDTH_OUT  (   WIDTH       ),
        .NUM_OUT    (   1           )
    ) den_inverter_pipeline (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .enable_i   (   '1              ),
        .clear_i    (   clear_i         ),
        .valid_i    (   valid_i         ),
        .ready_i    (   ready_i         ),
        .valid_o    (   valid_o         ),
        .ready_o    (   ready_o         ),
        .i_data_i   (   den_i           ),
        .i_data_o   (   den_del         ),
        .o_data_i   (   res             ),
        .o_data_o   (   inv_o           ),
        .i_strb_i   (   '1              ),
        .i_strb_o   (                   ),
        .o_strb_i   (   '1              ),
        .o_strb_o   (                   )    
    );

    assign mantissa = den_del [MANTISSA_BITS - 1 : 0];
    assign exponent = den_del [`EXPONENT(FPFORMAT)];
    assign sign     = den_del [`SIGN(FPFORMAT)];

    assign mantissa_sel = mantissa[MANTISSA_BITS - 1 -: N_MANT_BITS]; 
    assign mantissa_n   = ~mantissa_sel;

    assign out_exponent = (mantissa_sel == '0) ? 2 * BIAS - exponent : 2 * BIAS - 1 - exponent;

    assign mantissa_prod    = (mantissa_n >> 1) * mantissa_n;
    assign out_mantissa     = (mantissa_sel == '0) ? '0 : {mantissa_prod [2 * N_MANT_BITS - 2 -: N_MANT_BITS], {(MANTISSA_BITS - N_MANT_BITS){1'b0}}};

    assign res = {sign, out_exponent, out_mantissa};

endmodule