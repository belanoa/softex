`define SIGN(FPFORMAT)      fpnew_pkg::fp_width(FPFORMAT) - 1
`define EXPONENT(FPFORMAT)  fpnew_pkg::fp_width(FPFORMAT) - 2 -: fpnew_pkg::exp_bits(FPFORMAT)
`define MANTISSA(FPFORMAT)  fpnew_pkg::man_bits(FPFORMAT) - 1 : 0

`define FP_GT(A, B, FPFORMAT)   (A[`SIGN(FPFORMAT)] < B[`SIGN(FPFORMAT)]) | \
                                ((A[`SIGN(FPFORMAT)] == B[`SIGN(FPFORMAT)]) & (B[`SIGN(FPFORMAT)] == 0) & (A[`EXPONENT(FPFORMAT)] > B[`EXPONENT(FPFORMAT)])) | \
                                ((A[`SIGN(FPFORMAT)] == B[`SIGN(FPFORMAT)]) & (B[`SIGN(FPFORMAT)] == 0) & (A[`EXPONENT(FPFORMAT)] == B[`EXPONENT(FPFORMAT)]) & (A[`MANTISSA(FPFORMAT)] > B[`MANTISSA(FPFORMAT)])) | \
                                ((A[`SIGN(FPFORMAT)] == B[`SIGN(FPFORMAT)]) & (B[`SIGN(FPFORMAT)] == 1) & (A[`EXPONENT(FPFORMAT)] < B[`EXPONENT(FPFORMAT)])) | \
                                ((A[`SIGN(FPFORMAT)] == B[`SIGN(FPFORMAT)]) & (B[`SIGN(FPFORMAT)] == 1) & (A[`EXPONENT(FPFORMAT)] == B[`EXPONENT(FPFORMAT)]) & (A[`MANTISSA(FPFORMAT)] < B[`MANTISSA(FPFORMAT)]))

`define FP_LT(A, B, FPFORMAT)   (A[`SIGN(FPFORMAT)] > B[`SIGN(FPFORMAT)]) | \
                                ((A[`SIGN(FPFORMAT)] == B[`SIGN(FPFORMAT)]) & (B[`SIGN(FPFORMAT)] == 0) & (A[`EXPONENT(FPFORMAT)] < B[`EXPONENT(FPFORMAT)])) | \
                                ((A[`SIGN(FPFORMAT)] == B[`SIGN(FPFORMAT)]) & (B[`SIGN(FPFORMAT)] == 0) & (A[`EXPONENT(FPFORMAT)] == B[`EXPONENT(FPFORMAT)]) & (A[`MANTISSA(FPFORMAT)] < B[`MANTISSA(FPFORMAT)])) | \
                                ((A[`SIGN(FPFORMAT)] == B[`SIGN(FPFORMAT)]) & (B[`SIGN(FPFORMAT)] == 1) & (A[`EXPONENT(FPFORMAT)] > B[`EXPONENT(FPFORMAT)])) | \
                                ((A[`SIGN(FPFORMAT)] == B[`SIGN(FPFORMAT)]) & (B[`SIGN(FPFORMAT)] == 1) & (A[`EXPONENT(FPFORMAT)] == B[`EXPONENT(FPFORMAT)]) & (A[`MANTISSA(FPFORMAT)] > B[`MANTISSA(FPFORMAT)]))

`define POS_INFTY(FPFORMAT) {1'b0, {fpnew_pkg::exp_bits(FPFORMAT){1'b1}}, {fpnew_pkg::man_bits(FPFORMAT){1'b0}}}
`define NEG_INFTY(FPFORMAT) {1'b1, {fpnew_pkg::exp_bits(FPFORMAT){1'b1}}, {fpnew_pkg::man_bits(FPFORMAT){1'b0}}}

`define FP_CAST_UP(NUM, SRC_FPFORMAT, DEST_FPFORMAT) {NUM[`SIGN(SRC_FPFORMAT)], {(fpnew_pkg::exp_bits(DEST_FPFORMAT)  - fpnew_pkg::exp_bits(SRC_FPFORMAT)){1'b0}}, NUM[`EXPONENT(SRC_FPFORMAT)], NUM[`MANTISSA(SRC_FPFORMAT)], {(fpnew_pkg::man_bits(DEST_FPFORMAT)  - fpnew_pkg::man_bits(SRC_FPFORMAT)){1'b0}}}