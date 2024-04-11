import fpnew_pkg::*;
import expu_pkg::*;

module expu_schraudolph #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT        = FP16ALT   ,
    parameter int unsigned              A_FRACTION      = 14        ,
    parameter logic                     ENABLE_ROUNDING = 1         ,

    localparam int unsigned WIDTH           = fpnew_pkg::fp_width(FPFORMAT) ,
    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT) ,
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT) ,
    localparam int unsigned BIAS            = fpnew_pkg::bias(FPFORMAT)     
) (
    input   logic [WIDTH - 1 : 0]   op_i    ,
    output  logic [WIDTH - 1 : 0]   res_o                
);

    localparam real         A_REAL              = 1 / $ln(2);

    localparam int unsigned A_INT_BITS          = $clog2(int'(A_REAL)) + 1;
    localparam int unsigned MANTISSA_INT_BITS   = 1;
    localparam int unsigned MAX_EXP             = BIAS + (EXPONENT_BITS - (A_INT_BITS + MANTISSA_INT_BITS));

    //Q<A_INT_BITS.A_FRACTION>
    localparam logic [A_INT_BITS + A_FRACTION - 1 : 0]  A   = int'(A_REAL * 2 ** A_FRACTION);

    logic                                       sign;
    logic [EXPONENT_BITS - 1 : 0]               exponent;
    //Q<1.MANTISSA_BITS>
    logic [MANTISSA_BITS : 0]                   mantissa;

    //Q<2.MANTISSA_BITS + A_FRACTION>
    logic [MANTISSA_BITS + A_FRACTION + A_INT_BITS : 0]     scaled_mantissa;

    logic [EXPONENT_BITS + MANTISSA_BITS : 0]               shifted_mantissa;
    logic [EXPONENT_BITS + MANTISSA_BITS - 1 : 0]           rounded_mantissa;
    logic [EXPONENT_BITS + MANTISSA_BITS - 1 : 0]           signed_mantissa;

    logic [EXPONENT_BITS - 1 : 0]   new_exponent;
    logic [MANTISSA_BITS - 1 : 0]   new_mantissa;

    logic   ovfr;

    assign sign     =   op_i   [MANTISSA_BITS + EXPONENT_BITS];
    assign exponent =   op_i   [MANTISSA_BITS + EXPONENT_BITS - 1 : MANTISSA_BITS];
    assign mantissa =   {1'b1, op_i [MANTISSA_BITS - 1 : 0]};

    assign scaled_mantissa  =   (mantissa * A);
    assign shifted_mantissa =   (scaled_mantissa [MANTISSA_BITS + A_FRACTION + A_INT_BITS : A_FRACTION - MANTISSA_BITS] >> (MAX_EXP - exponent));
    assign rounded_mantissa =   shifted_mantissa [EXPONENT_BITS + MANTISSA_BITS : 1] + (ENABLE_ROUNDING ? shifted_mantissa [0] : '0);
    assign signed_mantissa  =   sign == 1'b0 ? rounded_mantissa : -rounded_mantissa;

    assign ovfr =   (exponent > MAX_EXP) || (
                        (exponent == MAX_EXP) && (
                            scaled_mantissa [MANTISSA_BITS + A_FRACTION + A_INT_BITS] || (
                                (sign == 1'b1) && 
                                &scaled_mantissa [MANTISSA_BITS + A_FRACTION + A_INT_BITS - 1 -: EXPONENT_BITS]
                            )
                        )
                    );

    always_comb begin
        if (~ovfr) begin
            new_exponent    =   signed_mantissa [EXPONENT_BITS + MANTISSA_BITS - 1 : MANTISSA_BITS] + BIAS;
            new_mantissa    =   signed_mantissa [MANTISSA_BITS - 1 : 0];
        end else begin
            new_exponent    =   sign == 1'b0 ? '1 : '0;
            new_mantissa    =   '0;
        end
    end

    assign  res_o   = {1'b0, new_exponent, new_mantissa};

endmodule