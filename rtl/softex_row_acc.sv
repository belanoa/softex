// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import softex_pkg::*;

module softex_row_acc #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT        = FPFORMAT_IN       ,
    parameter softex_pkg::regs_config_t REG_POS         = DEFAULT_REG_POS   ,
    parameter int unsigned              NUM_REGS        = NUM_REGS_ROW_ACC  ,
    parameter int unsigned              NUM_ROWS        = 1                 ,
    parameter int unsigned              NUM_FRAC_BITS   = ROW_ACC_WIDTH     ,
    parameter type                      TAG_TYPE        = logic             ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT)
) (
    input   logic                               clk_i           ,
    input   logic                               rst_ni          ,
    input   logic                               clear_i         ,
    input   fpnew_pkg::roundmode_e              round_mode_i    ,
    output  logic                               busy_o          ,

    input   logic [NUM_ROWS-1:0]                strb_i          ,
    output  logic                               valid_o         ,
    input   logic                               op_valid_i      ,
    output  logic                               op_ready_o      ,
    input   logic                               ready_i         ,
    input   logic [NUM_ROWS-1:0] [WIDTH-1:0]    op_i            ,
    input   logic [NUM_ROWS-1:0]                op_positive_i   ,    
    
    input   logic                               weight_valid_i  ,
    output  logic                               weight_ready_o  ,
    input   logic [WIDTH-1:0]                   weight_i        ,
    input   logic                               last_weight_i   ,

    output  logic [NUM_ROWS-1:0]                strb_o          ,
    output  logic [NUM_ROWS-1:0] [WIDTH-1:0]    res_o       
);

    localparam fpnew_pkg::pipe_config_t REG_POS_CVFPU   = softex_pkg::softex_to_cvfpu(REG_POS);

    localparam int unsigned LZ_WIDTH        = $clog2((NUM_FRAC_BITS)); 

    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT);
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT);
    localparam int unsigned BIAS            = fpnew_pkg::bias(FPFORMAT);

    logic [NUM_ROWS-1:0] [2:0] [WIDTH-1:0]      operands;

    logic [NUM_ROWS-1:0] [WIDTH-1:0]            mul_res;

    logic [NUM_ROWS-1:0] [MANTISSA_BITS:0]      mul_res_man;
    logic [NUM_ROWS-1:0] [EXPONENT_BITS-1:0]    mul_res_exp;

    logic [NUM_ROWS-1:0] [NUM_FRAC_BITS:0]    fix_pre_shift, fix_shift;

    logic [NUM_ROWS-1:0] [NUM_FRAC_BITS-1:0]    mul_res_fix;

    logic [NUM_ROWS-1:0] [NUM_FRAC_BITS-1:0]      acc_res_d, acc_res_q, int_res, shifted_res;

    logic [NUM_ROWS-1:0]                        last_op_d, op_positive_d, op_positive_q, mul_busy, mul_valids, mul_o_strb;
    logic                                       last_op_q;

    softex_glob_tag_t [NUM_ROWS-1:0]            glob_tags_d, glob_tags_q;

    logic [NUM_ROWS-1:0]                        pipe_strb_d, pipe_strb_q;

    logic [NUM_ROWS-1:0]                        mul_ready;

    logic                                       pipe_ready, pipe_valid;

    logic [NUM_ROWS-1:0] [LZ_WIDTH-1:0]         leading_zeros;

    logic [NUM_ROWS-1:0] [MANTISSA_BITS-1:0]    mantissae;
    logic [NUM_ROWS-1:0] [MANTISSA_BITS-1:0]    exponents;

    for (genvar i = 0; i < NUM_ROWS; i++) begin

        assign operands [i] [0] = weight_i;
        assign operands [i] [1] = op_i [i];
        assign operands [i] [2] = '0;

        fpnew_fma #(
                .FpFormat       (   FPFORMAT                ),
                .NumPipeRegs    (   0                       ),
                .PipeConfig     (   REG_POS_CVFPU           ),
                .TagType        (                           ),
                .AuxType        (   logic [1:0]             )
        ) i_in_mul (
            .clk_i              (   clk_i                               ),
            .rst_ni             (   rst_ni                              ),
            .operands_i         (   operands [i]                        ),
            .is_boxed_i         (   '1                                  ),
            .rnd_mode_i         (   round_mode_i                        ),
            .op_i               (   fpnew_pkg::MUL                      ),
            .op_mod_i           (   '0                                  ),
            .tag_i              (                                       ),
            .mask_i             (   strb_i [i]                          ),
            .aux_i              (   {last_weight_i, op_positive_i [i]}  ),
            .in_valid_i         (   weight_valid_i & op_valid_i         ),
            .in_ready_o         (   mul_ready [i]                       ),
            .flush_i            (   clear_i                             ),
            .result_o           (   mul_res [i]                         ),
            .status_o           (                                       ),
            .extension_bit_o    (                                       ),
            .tag_o              (                                       ),
            .mask_o             (   mul_o_strb [i]                      ),
            .aux_o              (   {last_op_d [i], op_positive_d [i]}  ),
            .out_valid_o        (   mul_valids [i]                      ),
            .out_ready_i        (   pipe_ready                          ),
            .busy_o             (   mul_busy [i]                        )
        );

        //BF TO FIX

        //Every addend is positive and < 1

        assign mul_res_exp [i]      = mul_res [i] [WIDTH-2:MANTISSA_BITS];        
        assign mul_res_man [i]      = {1'b1, mul_res [i] [MANTISSA_BITS-1:0]};

        assign fix_pre_shift [i]    = {mul_res_man [i], {(NUM_FRAC_BITS - MANTISSA_BITS){1'b0}}};
        assign fix_shift [i]        = fix_pre_shift [i] >> (BIAS - 1 - mul_res_exp [i]);

        assign mul_res_fix [i]      = (fix_shift [i] >> 1) + fix_shift [i] [0];

        assign acc_res_d [i]        = acc_res_q [i] + mul_res_fix [i];

    end

    softex_delay #(
        .NUM_REGS   (   NUM_REGS            ),
        .DATA_WIDTH (   NUM_FRAC_BITS       ),
        .NUM_ROWS   (   NUM_ROWS            )
    ) i_acc_pipe (
        .clk_i      (   clk_i                       ),
        .rst_ni     (   rst_ni                      ),
        .enable_i   (   '1                          ),
        .clear_i    (   clear_i                     ),
        .valid_i    (   mul_valids [0]              ),
        .ready_i    (   last_op_q ? ready_i : '1    ),
        .data_i     (   acc_res_d                   ),
        .strb_i     (   mul_o_strb                  ),
        .valid_o    (   pipe_valid                  ),
        .ready_o    (   pipe_ready                  ),
        .data_o     (   acc_res_q                   ),
        .strb_o     (   strb_o                      )    
    );

    softex_delay #(
        .NUM_REGS   (   NUM_REGS        ),
        .DATA_WIDTH (   NUM_ROWS + 1    ),
        .NUM_ROWS   (   1               )
    ) i_tag_pipe (
        .clk_i      (   clk_i                           ),
        .rst_ni     (   rst_ni                          ),
        .enable_i   (   '1                              ),
        .clear_i    (   clear_i                         ),
        .valid_i    (   mul_valids [0]                  ),
        .ready_i    (   last_op_q ? ready_i : '1        ),
        .data_i     (   {last_op_d [0], op_positive_d}  ),
        .strb_i     (   '1                              ),
        .valid_o    (                                   ),
        .ready_o    (                                   ),
        .data_o     (   {last_op_q, op_positive_q}      ),
        .strb_o     (                                   )    
    );

    always_comb begin
        for (int i = 0; i < NUM_ROWS; i++) begin
            int_res [i] = op_positive_q [i] ? ('b1 << (NUM_FRAC_BITS - 1)) - acc_res_q [i] : acc_res_q [i];
        end
    end

    for (genvar i = 0; i < NUM_ROWS; i++) begin
        lzc #(
            .WIDTH  (   NUM_FRAC_BITS       ),
            .MODE   (   1                   )
        ) i_lzc (
            .in_i    (   int_res [i]         ),
            .cnt_o   (   leading_zeros [i]   ),
            .empty_o (                       )
        );

        assign shifted_res [i]  = int_res [i] << (leading_zeros [i] + 1);

        assign mantissae [i]    = shifted_res [i] [(NUM_FRAC_BITS-1)-:MANTISSA_BITS] + shifted_res [i] [NUM_FRAC_BITS-1-MANTISSA_BITS];
        assign exponents [i]    = BIAS - leading_zeros [i] - 1;

        assign res_o [i]        = int_res [i] == '0 ? '0 : {1'b0, exponents [i], mantissae [i]};
    end
    
    assign valid_o          = last_op_q ? pipe_valid : '0;
    assign op_ready_o       = mul_ready [0] & weight_valid_i;
    assign weight_ready_o   = mul_ready [0] & op_valid_i;

endmodule