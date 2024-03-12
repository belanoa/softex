`include "sfm_macros.svh"

import sfm_pkg::*;
import fpnew_pkg::*;

module sfm_fp_minmax_rec #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = fpnew_pkg::FP16ALT    ,
    parameter int unsigned              N_INP                   = 1                     ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT) ,
    localparam int unsigned A_WIDTH = (N_INP + 1) / 2               ,
    localparam int unsigned B_WIDTH = N_INP - A_WIDTH
) (
    input   logic [N_INP - 1 : 0] [WIDTH - 1 : 0]   op_i    ,
    input   logic [N_INP - 1 : 0]                   strb_i  ,
    input   sfm_pkg::min_max_mode_t                 mode_i  ,
    output  logic [WIDTH - 1 : 0]                   res_o   ,
    output  logic                                   strb_o
);
    logic [A_WIDTH - 1 : 0] [WIDTH - 1 : 0] a;
    logic [B_WIDTH - 1 : 0] [WIDTH - 1 : 0] b;

    logic [WIDTH - 1 : 0]   res_a,
                            res_b;

    logic   o_strb_a,
            o_strb_b;

    logic [A_WIDTH - 1 : 0] i_strb_a;
    logic [B_WIDTH - 1 : 0] i_strb_b;

    if (N_INP != 1) begin
        assign a = op_i [A_WIDTH - 1 : 0];
        assign b = op_i [N_INP - 1 -: B_WIDTH];

        assign i_strb_a = strb_i [A_WIDTH - 1 : 0];
        assign i_strb_b = strb_i [N_INP - 1 -: B_WIDTH];
    end

    if (N_INP == 1) begin
        assign res_o    = op_i;
        assign strb_o   = strb_i;
    end else if (N_INP == 2) begin
        assign res_o    = (&strb_i == 1) ? ((mode_i == sfm_pkg::MAX) ? (`FP_GT(a[0], b[0], FPFORMAT) ? a : b) : (`FP_LT(a[0], b[0], FPFORMAT) ? a : b)) : ((i_strb_a == 1) ? a : b);
        assign strb_o   = |strb_i;
    end else begin
         sfm_fp_minmax_rec #(
            .FPFORMAT   (   FPFORMAT    ),
            .N_INP      (   A_WIDTH     )
        ) a_minmax (
            .op_i   (   a           ),
            .strb_i (   i_strb_a    ),
            .mode_i (   mode_i      ),
            .res_o  (   res_a       ),
            .strb_o (   o_strb_a    )
        );

        sfm_fp_minmax_rec #(
            .FPFORMAT   (   FPFORMAT    ),
            .N_INP      (   B_WIDTH     )
        ) b_minmax (
            .op_i   (   b           ),
            .strb_i (   i_strb_b    ),
            .mode_i (   mode_i      ),
            .res_o  (   res_b       ),
            .strb_o (   o_strb_b    )
        );

        assign res_o    = (o_strb_a & o_strb_b) ? ((mode_i == sfm_pkg::MAX) ? (`FP_GT(res_a, res_b, FPFORMAT) ? res_a : res_b) : (`FP_LT(res_a, res_b, FPFORMAT) ? res_a : res_b)) : ((o_strb_a == 1) ? res_a : res_b);
        assign strb_o   = o_strb_a | o_strb_b;
    end

endmodule

module sfm_fp_red_minmax #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = fpnew_pkg::FP16ALT    ,
    parameter sfm_pkg::regs_config_t    REG_POS                 = sfm_pkg::BEFORE       ,
    parameter int unsigned              NUM_REGS                = 0                     ,
    parameter int unsigned              VECT_WIDTH              = 1                     ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT)              
) (
    input   logic                                                           clk_i       ,
    input   logic                                                           rst_ni      ,
    input   logic                                                           clear_i     ,
    input   logic                                                           enable_i    ,
    input   logic                                                           valid_i     ,
    input   logic                                                           ready_i     ,
    input   logic                   [VECT_WIDTH - 1 : 0]                    strb_i      ,
    input   logic                   [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]    vect_i      ,
    input   sfm_pkg::min_max_mode_t                                         mode_i      ,
    output  logic                   [WIDTH - 1 : 0]                         res_o       ,
    output  logic                                                           strb_o      ,
    output  logic                                                           valid_o     ,
    output  logic                                                           ready_o
);
    logic   minmax_strb;

    sfm_pkg::min_max_mode_t mode;

    logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  vect;

    logic [VECT_WIDTH - 1 : 0]  strb;

    logic [WIDTH - 1 : 0]   minmax_res,
                            res;

    sfm_pipeline #(
        .REG_POS    (   REG_POS     ),
        .NUM_REGS   (   NUM_REGS    ),
        .WIDTH_IN   (   WIDTH       ),
        .NUM_IN     (   VECT_WIDTH  ),
        .WIDTH_OUT  (   WIDTH       ),
        .NUM_OUT    (   1           )
    ) i_minmax_pipeline (
        .clk_i      (   clk_i       ),
        .rst_ni     (   rst_ni      ),
        .enable_i   (   enable_i    ),
        .clear_i    (   clear_i     ),
        .valid_i    (   valid_i     ),
        .ready_i    (   ready_i     ),
        .valid_o    (   valid_o     ),
        .ready_o    (   ready_o     ),
        .i_data_i   (   vect_i      ),
        .i_data_o   (   vect        ),
        .o_data_i   (   minmax_res  ),
        .o_data_o   (   res_o       ),
        .i_strb_i   (   strb_i      ),
        .i_strb_o   (   strb        ),
        .o_strb_i   (   minmax_strb ),
        .o_strb_o   (   strb_o      )
    );

    sfm_pipeline #(
        .REG_POS    (   REG_POS     ),
        .NUM_REGS   (   NUM_REGS    ),
        .WIDTH_IN   (   1           ),
        .NUM_IN     (   1           ),
        .WIDTH_OUT  (   0           ),
        .NUM_OUT    (   0           )
    ) i_mode_pipeline (
        .clk_i      (   clk_i       ),
        .rst_ni     (   rst_ni      ),
        .enable_i   (   enable_i    ),
        .clear_i    (   clear_i     ),
        .valid_i    (   valid_i     ),
        .ready_i    (   ready_i     ),
        .valid_o    (               ),
        .ready_o    (               ),
        .i_data_i   (   mode_i      ),
        .i_data_o   (   mode        ),
        .o_data_i   (               ),
        .o_data_o   (               ),
        .i_strb_i   (   '1          ),
        .i_strb_o   (               ),
        .o_strb_i   (               ),
        .o_strb_o   (               )
    );


    sfm_fp_minmax_rec #(
        .FPFORMAT   (   FPFORMAT    ),
        .N_INP      (   VECT_WIDTH  )
    ) minmax_tree (
        .op_i   (   vect        ),
        .strb_i (   strb        ),
        .mode_i (   mode        ),
        .res_o  (   minmax_res  ),
        .strb_o (   minmax_strb )
    );

endmodule