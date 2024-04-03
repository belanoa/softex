module sfm_fp_vect_addmul #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = fpnew_pkg::FP16ALT    ,
    parameter sfm_pkg::regs_config_t    REG_POS                 = sfm_pkg::BEFORE       ,
    parameter int unsigned              NUM_REGS                = 0                     ,
    parameter int unsigned              VECT_WIDTH              = 1                     ,
    parameter type                      TAG_TYPE                = logic                 ,

    localparam int unsigned             WIDTH           = fpnew_pkg::fp_width(FPFORMAT)     ,
    localparam fpnew_pkg::pipe_config_t REG_POS_CVFPU   = sfm_pkg::sfm_to_cvfpu(REG_POS)
) (
    input   logic                                       clk_i               ,
    input   logic                                       rst_ni              ,
    input   logic                                       clear_i             ,
    input   logic                                       enable_i            ,
    input   fpnew_pkg::roundmode_e                      round_mode_i        ,
    input   sfm_pkg::operation_t                        operation_i         ,
    input   logic                                       op_mod_add_i        ,
    input   logic                                       op_mod_mul_i        ,
    output  logic                                       busy_o              ,
    
    input   logic                                       add_valid_i         ,
    input   logic                                       add_scal_valid_i    ,
    input   logic                                       add_ready_i         ,
    input   logic [VECT_WIDTH - 1 : 0]                  add_strb_i          ,
    input   logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  add_vect_i          ,
    input   logic [WIDTH - 1 : 0]                       add_scal_i          ,
    input   TAG_TYPE                                    add_tag_i           ,
    output  logic                                       add_valid_o         ,
    output  logic                                       add_ready_o         ,
    output  logic [VECT_WIDTH - 1 : 0]                  add_strb_o          ,
    output  logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  add_res_o           ,
    output  TAG_TYPE                                    add_tag_o           ,

    input   logic                                       mul_valid_i         ,
    input   logic                                       mul_scal_valid_i    ,
    input   logic                                       mul_ready_i         ,
    input   logic [VECT_WIDTH - 1 : 0]                  mul_strb_i          ,
    input   logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  mul_vect_i          ,
    input   logic [WIDTH - 1 : 0]                       mul_scal_i          ,
    input   TAG_TYPE                                    mul_tag_i           ,
    output  logic                                       mul_valid_o         ,
    output  logic                                       mul_ready_o         ,
    output  logic [VECT_WIDTH - 1 : 0]                  mul_strb_o          ,
    output  logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  mul_res_o           ,
    output  TAG_TYPE                                    mul_tag_o       
);

    logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  fma_res;
    logic [VECT_WIDTH - 1 : 0]                  fma_o_strb;
    TAG_TYPE                                    fma_o_tag;

    logic [VECT_WIDTH - 1 : 0] [2 : 0] [WIDTH - 1 : 0]  fma_operands;
    logic [VECT_WIDTH - 1 : 0]                          fma_valids,
                                                        fma_readies;

    logic   fma_i_valid,
            fma_i_ready;

    TAG_TYPE    fma_i_aux;

    TAG_TYPE [VECT_WIDTH - 1 : 0] fma_o_auxs;

    fpnew_pkg::operation_e  fpnew_op;

    sfm_pkg::operation_t [VECT_WIDTH - 1 : 0]   o_operations;
    
    logic   op_mod;

    logic   [VECT_WIDTH - 1 : 0]    strb,
                                    busy;

    assign fpnew_op     = operation_i == sfm_pkg::MUL ? fpnew_pkg::MUL : fpnew_pkg::ADD;
    assign op_mod       = operation_i == sfm_pkg::MUL ? op_mod_mul_i : op_mod_add_i;
    assign strb         = operation_i == sfm_pkg::MUL ? mul_strb_i : add_strb_i;

    assign fma_i_valid  = operation_i == sfm_pkg::MUL ? mul_valid_i & mul_scal_valid_i : add_valid_i & add_scal_valid_i;
    assign fma_i_ready  = o_operations [0] == sfm_pkg::MUL ? mul_ready_i : add_ready_i;

    assign fma_i_aux    = operation_i == sfm_pkg::MUL ? mul_tag_i : add_tag_i;

    for (genvar i = 0; i < VECT_WIDTH; i++) begin
        assign fma_operands [i][0] = mul_scal_i;
        assign fma_operands [i][1] = operation_i == sfm_pkg::MUL ? mul_vect_i [i] : add_vect_i [i];
        assign fma_operands [i][2] = add_scal_i;

        fpnew_fma #(
            .FpFormat       (   FPFORMAT                ),
            .NumPipeRegs    (   NUM_REGS                ),
            .PipeConfig     (   REG_POS_CVFPU           ),
            .TagType        (   sfm_pkg::operation_t    ),
            .AuxType        (   TAG_TYPE                )
        ) i_addmul_fma (
            .clk_i              (   clk_i               ),
            .rst_ni             (   rst_ni              ),
            .operands_i         (   fma_operands [i]    ),
            .is_boxed_i         (   '1                  ),
            .rnd_mode_i         (   round_mode_i        ),
            .op_i               (   fpnew_op            ),
            .op_mod_i           (   op_mod              ),
            .tag_i              (   operation_i         ),
            .mask_i             (   strb [i]            ),
            .aux_i              (   fma_i_aux           ),
            .in_valid_i         (   fma_i_valid         ),
            .in_ready_o         (   fma_readies [i]     ),
            .flush_i            (   clear_i             ),
            .result_o           (   fma_res [i]         ),
            .status_o           (   ),
            .extension_bit_o    (   ),
            .tag_o              (   o_operations [i]    ),
            .mask_o             (   fma_o_strb [i]      ),
            .aux_o              (   fma_o_auxs [i]      ),
            .out_valid_o        (   fma_valids [i]      ),
            .out_ready_i        (   fma_i_ready         ),
            .busy_o             (   busy [i]            )
        );
    end

    assign fma_o_tag    = fma_o_auxs [0];

    assign busy_o       = |busy;

    assign add_res_o    = fma_res;
    assign add_strb_o   = fma_o_strb;
    assign add_tag_o    = fma_o_tag;

    assign mul_res_o    = fma_res;
    assign mul_strb_o   = fma_o_strb;
    assign mul_tag_o    = fma_o_tag;

    assign add_ready_o  = operation_i == sfm_pkg::ADD ? fma_readies [0] & add_scal_valid_i : '0;
    assign mul_ready_o  = operation_i == sfm_pkg::MUL ? fma_readies [0] & mul_scal_valid_i : '0;

    assign add_valid_o  = o_operations [0] == sfm_pkg::ADD ? fma_valids [0] : '0;
    assign mul_valid_o  = o_operations [0] == sfm_pkg::MUL ? fma_valids [0] : '0;

endmodule