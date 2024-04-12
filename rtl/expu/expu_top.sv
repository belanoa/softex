`include "common_cells/registers.svh"

import fpnew_pkg::*;
import sfm_pkg::*;

module expu_top #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = fpnew_pkg::FP16ALT    ,
    parameter sfm_pkg::regs_config_t    REG_POS                 = sfm_pkg::BEFORE       ,
    parameter int unsigned              NUM_REGS                = 0                     ,
    parameter int unsigned              N_ROWS                  = 1                     ,
    parameter int unsigned              A_FRACTION              = 14                    ,
    parameter logic                     ENABLE_ROUNDING         = 1                     ,
    parameter logic                     ENABLE_MANT_CORRECTION  = 1                     ,
    parameter int unsigned              COEFFICIENT_FRACTION    = 4                     ,
    parameter int unsigned              CONSTANT_FRACTION       = 7                     ,
    parameter int unsigned              MUL_SURPLUS_BITS        = 1                     ,
    parameter int unsigned              NOT_SURPLUS_BITS        = 0                     ,
    parameter real                      ALPHA_REAL              = 0.24609375            ,
    parameter real                      BETA_REAL               = 0.41015625            ,
    parameter real                      GAMMA_1_REAL            = 2.8359375             ,
    parameter real                      GAMMA_2_REAL            = 2.16796875            ,
    parameter type                      TAG_TYPE                = logic                 ,

    localparam int unsigned WIDTH           = fpnew_pkg::fp_width(FPFORMAT) ,
    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT) ,
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT)
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
            `FFLARNC(valid_reg [i + 1], valid_reg [i],  enable_i & ~reg_en_n [i],   clear_i,    '0, clk_i,  rst_ni)
        end
    endgenerate

    generate
        for (genvar i = 0; i < NUM_REGS; i++) begin : strobe_registers
            `FFLARNC(strb_reg [i + 1],  strb_reg [i],   enable_i & ~reg_en_n [i],   clear_i,    '0, clk_i,  rst_ni)
        end
    endgenerate

    generate
        for (genvar i = 0; i < NUM_REGS; i++) begin : tag_registers
            `FFLARNC(tag_reg [i + 1], tag_reg [i],  enable_i & ~reg_en_n [i],   clear_i,    '0, clk_i,  rst_ni)
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