module sfm_fp_vect_addsub #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = fpnew_pkg::FP16ALT   ,
    parameter sfm_pkg::regs_config_t    REG_POS                 = sfm_pkg::BEFORE   ,
    parameter int unsigned              NUM_REGS                = 0                 ,
    parameter int unsigned              VECT_WIDTH              = 1                 ,

    localparam int unsigned             WIDTH           = fpnew_pkg::fp_width(FPFORMAT)     ,
    localparam fpnew_pkg::pipe_config_t REG_POS_CVFPU   = sfm_pkg::sfm_to_cvfpu(REG_POS)
) (
    input   logic                                       clk_i           ,
    input   logic                                       rst_ni          ,
    input   logic                                       clear_i         ,
    input   logic                                       enable_i        ,
    input   logic                                       valid_i         ,
    input   logic                                       ready_i         ,
    input   fpnew_pkg::roundmode_e                      round_mode_i    ,
    input   sfm_pkg::operation_t                        operation_i     ,
    input   logic [VECT_WIDTH - 1 : 0]                  strb_i          ,
    input   logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  vect_i          ,
    input   logic [WIDTH - 1 : 0]                       scal_i          ,
    output  logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]       res_o           ,
    output  logic [VECT_WIDTH - 1 : 0]                  strb_o          ,
    output  logic                                       valid_o         ,
    output  logic                                       ready_o
);

    logic [VECT_WIDTH - 1 : 0] [2 : 0] [WIDTH - 1 : 0]  operands;
    logic [VECT_WIDTH - 1 : 0]                          valids,
                                                        readies;

    for (genvar i = 0; i < VECT_WIDTH; i++) begin
        assign operands [i][0] = 'b1;
        assign operands [i][1] = vect_i [i];
        assign operands [i][2] = scal_i;

        fpnew_fma #(
            .FpFormat       (   FPFORMAT        ),
            .NumPipeRegs    (   NUM_REGS        ),
            .PipeConfig     (   REG_POS_CVFPU   ),
            .TagType        (   logic           ),
            .AuxType        (   logic           )
        ) i_sum (
            .clk_i              (   clk_i           ),
            .rst_ni             (   rst_ni          ),
            .operands_i         (   operands [i]    ),
            .is_boxed_i         (   '1              ),
            .rnd_mode_i         (   round_mode_i    ),
            .op_i               (   fpnew_pkg::ADD  ),
            .op_mod_i           (   operation_i     ),
            .tag_i              (   '0              ),
            .mask_i             (   strb_i [i]      ),
            .aux_i              (   '0              ),
            .in_valid_i         (   valid_i         ),
            .in_ready_o         (   readies [i]     ),
            .flush_i            (   clear_i         ),
            .result_o           (   res_o [i]       ),
            .status_o           (   ),
            .extension_bit_o    (   ),
            .tag_o              (   ),
            .mask_o             (   strb_o [i]      ),
            .aux_o              (   ),
            .out_valid_o        (   valids [i]      ),
            .out_ready_i        (   ready_i         ),
            .busy_o             (   )
        );
    end

    assign valid_o = valids [0];
    assign ready_o = readies [0];

endmodule