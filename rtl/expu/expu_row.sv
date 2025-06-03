// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//


module expu_row
import softex_pkg::*;
import fpnew_pkg::*;
#(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = FPFORMAT_IN                   ,
    parameter softex_pkg::regs_config_t REG_POS                 = DEFAULT_REG_POS               ,
    parameter int unsigned              NUM_REGS                = 0                             ,
    parameter int unsigned              A_FRACTION              = EXPU_A_FRACTION               ,
    parameter int unsigned              ENABLE_ROUNDING         = EXPU_ENABLE_ROUNDING          ,
    parameter logic                     ENABLE_MANT_CORRECTION  = EXPU_ENABLE_MANT_CORRECTION   ,
    parameter int unsigned              COEFFICIENT_FRACTION    = EXPU_COEFFICIENT_FRACTION     ,
    parameter int unsigned              CONSTANT_FRACTION       = EXPU_CONSTANT_FRACTION        ,
    parameter int unsigned              MUL_SURPLUS_BITS        = EXPU_MUL_SURPLUS_BITS         ,
    parameter int unsigned              NOT_SURPLUS_BITS        = EXPU_NOT_SURPLUS_BITS         ,
    parameter int unsigned              ALPHA_FIXED             = EXPU_ALPHA_FIXED              ,
    parameter int unsigned              BETA_FIXED              = EXPU_BETA_FIXED               ,
    parameter int unsigned              GAMMA_1_FIXED           = EXPU_GAMMA_1_FIXED            ,
    parameter int unsigned              GAMMA_2_FIXED           = EXPU_GAMMA_2_FIXED            ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT)
) (
    input   logic                       clk_i       ,
    input   logic                       rst_ni      ,
    input   logic                       clear_i     ,
    input   logic [NUM_REGS - 1 : 0]    enable_i    ,
    input   logic [WIDTH - 1 : 0]       op_i        ,
    output  logic [WIDTH - 1 : 0]       res_o            
);

    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT);
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT);

    logic [WIDTH - 1 : 0]           res_sch,
                                    res_cor;

    logic [WIDTH - 1 : 0]           result;

    logic [NUM_REGS : 0] [WIDTH - 1 : 0] reg_data;

    logic [WIDTH - 1 : 0]   op_before;

    generate
        if (REG_POS == softex_pkg::BEFORE) begin
            assign reg_data [0] = op_i;
            assign op_before    = reg_data [NUM_REGS];
            assign res_o        = result;
        end else if (REG_POS == softex_pkg::AFTER) begin
            assign reg_data [0] = result;
            assign res_o        = reg_data [NUM_REGS];
            assign op_before    = op_i;
        end else if (REG_POS == softex_pkg::AROUND) begin
            assign reg_data [0] = op_i;
            assign op_before    = reg_data [NUM_REGS / 2];
            assign res_o        = reg_data [NUM_REGS];
        end
    endgenerate

    generate
        for (genvar i = 0; i < NUM_REGS; i ++) begin : gen_regs
            if (i != NUM_REGS / 2 || REG_POS != softex_pkg::AROUND) begin
                always_ff @(posedge clk_i or negedge rst_ni) begin
                    if (~rst_ni) begin
                        reg_data [i + 1] <= '0;
                    end else begin
                        if (clear_i) begin
                            reg_data [i + 1] <= '0;
                        end else if (enable_i [i]) begin
                            reg_data [i + 1] <= reg_data [i];
                        end
                    end
                end
            end else begin
                always_ff @(posedge clk_i or negedge rst_ni) begin
                    if (~rst_ni) begin
                        reg_data [i + 1] <= '0;
                    end else begin
                        if (clear_i) begin
                            reg_data [i + 1] <= '0;
                        end else if (enable_i [i]) begin
                            reg_data [i + 1] <= result;
                        end
                    end
                end
            end
        end
    endgenerate

    expu_schraudolph #(
        .FPFORMAT       (   FPFORMAT        ),
        .A_FRACTION     (   A_FRACTION      ),
        .ENABLE_ROUNDING(   ENABLE_ROUNDING )
    ) expu_schraudolph (
        .op_i   (   op_before   ),
        .res_o  (   res_sch     )  
    );

    generate
        if (ENABLE_MANT_CORRECTION) begin
            expu_correction #(
                .FPFORMAT               (   FPFORMAT                ),
                .COEFFICIENT_FRACTION   (   COEFFICIENT_FRACTION    ),
                .CONSTANT_FRACTION      (   CONSTANT_FRACTION       ),
                .MUL_SURPLUS_BITS       (   MUL_SURPLUS_BITS        ),
                .NOT_SURPLUS_BITS       (   NOT_SURPLUS_BITS        ),
                .ALPHA_FIXED            (   ALPHA_FIXED             ),
                .BETA_FIXED             (   BETA_FIXED              ),
                .GAMMA_1_FIXED          (   GAMMA_1_FIXED           ),
                .GAMMA_2_FIXED          (   GAMMA_2_FIXED           ) 
            ) expu_correction ( 
                .op_i   (   res_sch ), 
                .res_o  (   res_cor )   
            );

            assign result   = res_cor;
        end else begin
            assign result   = res_sch;
        end
    endgenerate

endmodule