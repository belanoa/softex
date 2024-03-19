`include "sfm_macros.svh"

module sfm_den_inverter #(
    parameter fpnew_pkg::fp_format_e    IN_FPFORMAT     = fpnew_pkg::FP32       ,
    parameter fpnew_pkg::fp_format_e    OUT_FPFORMAT    = fpnew_pkg::FP16ALT    ,
    parameter sfm_pkg::regs_config_t    REG_POS         = sfm_pkg::BEFORE       ,
    parameter int unsigned              NUM_REGS        = 2                     ,

    localparam int unsigned IN_WIDTH            = fpnew_pkg::fp_width(IN_FPFORMAT)  ,
    localparam int unsigned OUT_WIDTH           = fpnew_pkg::fp_width(OUT_FPFORMAT) ,
    localparam int unsigned OUT_MANTISSA_BITS   = fpnew_pkg::man_bits(OUT_FPFORMAT) ,
    localparam int unsigned OUT_EXPONENT_BITS   = fpnew_pkg::exp_bits(OUT_FPFORMAT) ,
    localparam int unsigned OUT_BIAS            = fpnew_pkg::bias(OUT_FPFORMAT)     
) (
    input   logic                       clk_i   ,
    input   logic                       rst_ni  ,
    input   logic                       clear_i ,
    input   logic                       valid_i ,
    input   logic                       ready_i ,
    input   logic [IN_WIDTH - 1 : 0]    den_i   ,
    output  logic                       ready_o ,
    output  logic                       valid_o ,
    output  logic [OUT_WIDTH - 1 : 0]   inv_o
);

    logic [OUT_WIDTH - 1 : 0]   cast_den,
                                cast_den_del,
                                res;

    logic [OUT_EXPONENT_BITS - 1 : 0]   exponent,
                                        out_exponent;

    logic [OUT_MANTISSA_BITS - 1 : 0]   mantissa,
                                        mantissa_n,
                                        out_mantissa;

    logic [2 * OUT_MANTISSA_BITS - 2 : 0]   mantissa_prod;

    logic sign;

    assign cast_den = `FP_CAST_DOWN(den_i, IN_FPFORMAT, OUT_FPFORMAT);

    sfm_pipeline #(
        .REG_POS    (   REG_POS     ),
        .NUM_REGS   (   NUM_REGS    ),
        .WIDTH_IN   (   OUT_WIDTH   ),
        .NUM_IN     (   1           ),
        .WIDTH_OUT  (   OUT_WIDTH   ),
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
        .i_data_i   (   cast_den        ),
        .i_data_o   (   cast_den_del    ),
        .o_data_i   (   res             ),
        .o_data_o   (   inv_o           ),
        .i_strb_i   (   '1              ),
        .i_strb_o   (                   ),
        .o_strb_i   (   '1              ),
        .o_strb_o   (                   )    
    );

    assign mantissa = cast_den_del [OUT_MANTISSA_BITS - 1 : 0];
    assign exponent = cast_den_del [`EXPONENT(OUT_FPFORMAT)];
    assign sign     = cast_den_del [`SIGN(OUT_FPFORMAT)];

    assign mantissa_n = ~mantissa;

    assign out_exponent = (mantissa == '0) ? 2 * OUT_BIAS - exponent : 2 * OUT_BIAS - 1 - exponent;

    assign mantissa_prod = mantissa_n [OUT_MANTISSA_BITS - 2 : 0] * mantissa_n;
    assign out_mantissa = (mantissa == '0) ? '0 : mantissa_prod [2 * OUT_MANTISSA_BITS - 2 -: OUT_MANTISSA_BITS];

    assign res = {sign, out_exponent, out_mantissa};

endmodule