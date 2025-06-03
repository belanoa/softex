// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//


module softex_acc_top import softex_pkg::*; #(
    parameter fpnew_pkg::fp_format_e    ACC_FPFORMAT        = FPFORMAT_ACC                      ,
    parameter fpnew_pkg::fp_format_e    ADD_FPFORMAT        = FPFORMAT_ACC                      ,
    parameter fpnew_pkg::fp_format_e    MUL_FPFORMAT        = FPFORMAT_IN                       ,
    parameter int unsigned              N_INV_ITERS         = N_NEWTON_ITERS                    ,
    parameter int unsigned              NUM_REGS_FMA        = NUM_REGS_FMA_ACC                  , 
    parameter int unsigned              FACTOR_FIFO_DEPTH   = ACC_FACT_FIFO_D                   ,
    parameter int unsigned              ADDEND_FIFO_DEPTH   = NUM_REGS_FMA * FACTOR_FIFO_DEPTH  ,  
    parameter fpnew_pkg::roundmode_e    ROUND_MODE          = fpnew_pkg::RNE                    ,

    localparam int unsigned ACC_WIDTH   = fpnew_pkg::fp_width(ACC_FPFORMAT),
    localparam int unsigned ADD_WIDTH   = fpnew_pkg::fp_width(ADD_FPFORMAT),
    localparam int unsigned MUL_WIDTH   = fpnew_pkg::fp_width(MUL_FPFORMAT)
) (
    input   logic                           clk_i       ,
    input   logic                           rst_ni      ,
    input   logic                           clear_i     ,
    input   softex_pkg::accumulator_ctrl_t  ctrl_i      ,
    input   logic                           add_valid_i ,
    input   logic [ADD_WIDTH - 1 : 0]       add_i       ,
    input   logic                           mul_valid_i ,
    input   logic [MUL_WIDTH - 1 : 0]       mul_i       ,
    output  logic                           ready_o     ,
    output  logic                           valid_o     ,
    output  softex_pkg::accumulator_flags_t flags_o     ,
    output  logic [ACC_WIDTH - 1 : 0]       acc_o
);

    softex_pkg::acc_datapath_ctrl_t    datapath_ctrl;
    softex_pkg::acc_datapath_flags_t   datapath_flags;

    softex_acc_ctrl #(
        .N_INV_ITERS    (   N_INV_ITERS )
    ) i_acc_ctrl (
        .clk_i              (   clk_i           ),
        .rst_ni             (   rst_ni          ),
        .clear_i            (   clear_i         ),
        .ctrl_i             (   ctrl_i          ),
        .flags_o            (   flags_o         ),
        .ctrl_datapath_o    (   datapath_ctrl   ),
        .flags_datapath_i   (   datapath_flags  )
    );

    softex_acc_datapath #(
        .ACC_FPFORMAT       (   ACC_FPFORMAT        ),
        .ADD_FPFORMAT       (   ADD_FPFORMAT        ),
        .MUL_FPFORMAT       (   MUL_FPFORMAT        ),
        .NUM_REGS_FMA       (   NUM_REGS_FMA        ),
        .FACTOR_FIFO_DEPTH  (   FACTOR_FIFO_DEPTH   ),
        .ADDEND_FIFO_DEPTH  (   ADDEND_FIFO_DEPTH   ),
        .ROUND_MODE         (   ROUND_MODE          )
    ) i_acc_datapath (
        .clk_i          (   clk_i           ),
        .rst_ni         (   rst_ni          ),
        .clear_i        (   clear_i         ),
        .ctrl_i         (   datapath_ctrl   ),
        .add_valid_i    (   add_valid_i     ),
        .add_i          (   add_i           ),
        .mul_valid_i    (   mul_valid_i     ),
        .mul_i          (   mul_i           ),
        .ready_o        (   ready_o         ),
        .valid_o        (   valid_o         ),
        .flags_o        (   datapath_flags  ),
        .acc_o          (   acc_o           )
    );

endmodule