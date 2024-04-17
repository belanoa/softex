// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import sfm_pkg::*;
import fpnew_pkg::*;

module expu_top #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = FPFORMAT_IN                   ,
    parameter sfm_pkg::regs_config_t    REG_POS                 = sfm_pkg::BEFORE               ,
    parameter int unsigned              NUM_REGS                = 0                             ,
    parameter int unsigned              N_ROWS                  = 1                             ,
    parameter int unsigned              A_FRACTION              = EXPU_A_FRACTION               ,
    parameter logic                     ENABLE_ROUNDING         = EXPU_ENABLE_ROUNDING          ,
    parameter logic                     ENABLE_MANT_CORRECTION  = EXPU_ENABLE_MANT_CORRECTION   ,
    parameter int unsigned              COEFFICIENT_FRACTION    = EXPU_COEFFICIENT_FRACTION     ,
    parameter int unsigned              CONSTANT_FRACTION       = EXPU_CONSTANT_FRACTION        ,
    parameter int unsigned              MUL_SURPLUS_BITS        = EXPU_MUL_SURPLUS_BITS         ,
    parameter int unsigned              NOT_SURPLUS_BITS        = EXPU_NOT_SURPLUS_BITS         ,
    parameter real                      ALPHA_REAL              = EXPU_ALPHA_REAL               ,
    parameter real                      BETA_REAL               = EXPU_BETA_REAL                ,
    parameter real                      GAMMA_1_REAL            = EXPU_GAMMA_1_REAL             ,
    parameter real                      GAMMA_2_REAL            = EXPU_GAMMA_2_REAL             ,
    parameter type                      TAG_TYPE                = logic                         ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT)
) (
    input   logic                                   clk_i       ,
    input   logic                                   rst_ni      ,
    input   logic                                   clear_i     ,
    input   logic                                   enable_i    ,
    input   logic                                   valid_i     ,
    input   logic                                   ready_i     ,
    input   logic [N_ROWS - 1 : 0]                  strb_i      ,
    input   logic [N_ROWS - 1 : 0] [WIDTH - 1 : 0]  op_i        ,
    input   TAG_TYPE                                tag_i       ,
    output  logic [N_ROWS - 1 : 0] [WIDTH - 1 : 0]  res_o       ,
    output  logic                                   valid_o     ,
    output  logic                                   ready_o     ,
    output  logic [N_ROWS - 1 : 0]                  strb_o      ,
    output  TAG_TYPE                                tag_o       ,
    output  logic                                   busy_o      
);

    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT);
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT);

    logic [NUM_REGS : 0]    valid_reg;
    logic [NUM_REGS : 0]    reg_en_n;

    TAG_TYPE [NUM_REGS : 0] tag_reg;

    logic [NUM_REGS : 0] [N_ROWS - 1 : 0] strb_reg;

    logic [N_ROWS - 1 : 0] [NUM_REGS - 1 : 0]   row_enable;

    always_comb begin
        for (int i = 0; i < N_ROWS; i++) begin
            for (int j = 0; j < NUM_REGS; j++) begin
                row_enable [i][j]   = enable_i & ~reg_en_n [j] & strb_reg [j][i] & valid_reg [j];
            end
        end
    end

    generate
        for (genvar i = 0; i < N_ROWS; i++) begin : expu_row
            expu_row #(
                .FPFORMAT               (   FPFORMAT                ),
                .REG_POS                (   REG_POS                 ),
                .NUM_REGS               (   NUM_REGS                ),
                .A_FRACTION             (   A_FRACTION              ),
                .ENABLE_ROUNDING        (   ENABLE_ROUNDING         ),
                .ENABLE_MANT_CORRECTION (   ENABLE_MANT_CORRECTION  ),
                .COEFFICIENT_FRACTION   (   COEFFICIENT_FRACTION    ),
                .CONSTANT_FRACTION      (   CONSTANT_FRACTION       ),
                .MUL_SURPLUS_BITS       (   MUL_SURPLUS_BITS        ),
                .NOT_SURPLUS_BITS       (   NOT_SURPLUS_BITS        ),
                .ALPHA_REAL             (   ALPHA_REAL              ),
                .BETA_REAL              (   BETA_REAL               ),
                .GAMMA_1_REAL           (   GAMMA_1_REAL            ),
                .GAMMA_2_REAL           (   GAMMA_2_REAL            )
            ) i_expu_row (
                .clk_i      (   clk_i           ),
                .rst_ni     (   rst_ni          ),
                .clear_i    (   clear_i         ),
                .enable_i   (   row_enable  [i] ),
                .op_i       (   op_i        [i] ),
                .res_o      (   res_o       [i] )
            );
        end
    endgenerate

    assign reg_en_n [NUM_REGS] = ~ready_i;

    generate
        for (genvar i = 0; i < NUM_REGS; i++) begin : reg_enable_assignment
            assign reg_en_n [i] = reg_en_n [i + 1] & valid_reg [i + 1];
        end
    endgenerate

    generate
        for (genvar i = 0; i < NUM_REGS; i++) begin : valid_registers
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (~rst_ni) begin
                    valid_reg [i + 1] <= '0;
                end else begin
                    if (clear_i) begin
                        valid_reg [i + 1] <= '0;
                    end else if (enable_i & ~reg_en_n [i]) begin
                        valid_reg [i + 1] <= valid_reg [i];
                    end else begin
                        valid_reg [i + 1] <= valid_reg [i + 1];
                    end
                end
            end
        end
    endgenerate

    generate
        for (genvar i = 0; i < NUM_REGS; i++) begin : strobe_registers
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (~rst_ni) begin
                    strb_reg [i + 1] <= '0;
                end else begin
                    if (clear_i) begin
                        strb_reg [i + 1] <= '0;
                    end else if (enable_i & ~reg_en_n [i]) begin
                        strb_reg [i + 1] <= strb_reg [i];
                    end else begin
                        strb_reg [i + 1] <= strb_reg [i + 1];
                    end
                end
            end
        end
    endgenerate

    generate
        for (genvar i = 0; i < NUM_REGS; i++) begin : tag_registers
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (~rst_ni) begin
                    tag_reg [i + 1] <= '0;
                end else begin
                    if (clear_i) begin
                        tag_reg [i + 1] <= '0;
                    end else if (enable_i & ~reg_en_n [i]) begin
                        tag_reg [i + 1] <= tag_reg [i];
                    end else begin
                        tag_reg [i + 1] <= tag_reg [i + 1];
                    end
                end
            end
        end
    endgenerate


    assign valid_reg [0]    = valid_i;
    assign valid_o          = valid_reg [NUM_REGS];
    assign strb_reg [0]     = strb_i;
    assign strb_o           = strb_reg  [NUM_REGS];
    assign tag_reg [0]      = tag_i;
    assign tag_o            = tag_reg   [NUM_REGS];

    assign ready_o = ~reg_en_n [0] & enable_i;

    assign busy_o  = |valid_reg [NUM_REGS : 1];

endmodule