module sfm_fp_vect_addmul #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = fpnew_pkg::FP16ALT    ,
    parameter sfm_pkg::regs_config_t    REG_POS                 = sfm_pkg::BEFORE       ,
    parameter int unsigned              NUM_REGS                = 0                     ,
    parameter int unsigned              VECT_WIDTH              = 1                     ,
    parameter int unsigned              ADD_OUT_FIFO_DEPTH      = 0                     ,
    parameter int unsigned              MUL_OUT_FIFO_DEPTH      = 1                     ,

    localparam int unsigned             WIDTH           = fpnew_pkg::fp_width(FPFORMAT)     ,
    localparam fpnew_pkg::pipe_config_t REG_POS_CVFPU   = sfm_pkg::sfm_to_cvfpu(REG_POS)
) (
    input   logic                                       clk_i           ,
    input   logic                                       rst_ni          ,
    input   logic                                       clear_i         ,
    input   logic                                       enable_i        ,
    input   fpnew_pkg::roundmode_e                      round_mode_i    ,
    input   sfm_pkg::operation_t                        operation_i     ,
    input   logic                                       op_mod_add_i    ,
    input   logic                                       op_mod_mul_i    ,
    
    input   logic                                       add_valid_i     ,
    input   logic                                       add_ready_i     ,
    input   logic [VECT_WIDTH - 1 : 0]                  add_strb_i      ,
    input   logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  add_vect_i      ,
    input   logic [WIDTH - 1 : 0]                       add_scal_i      ,
    output  logic                                       add_valid_o     ,
    output  logic                                       add_ready_o     ,
    output  logic [VECT_WIDTH - 1 : 0]                  add_strb_o      ,
    output  logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  add_res_o       ,

    input   logic                                       mul_valid_i     ,
    input   logic                                       mul_ready_i     ,
    input   logic [VECT_WIDTH - 1 : 0]                  mul_strb_i      ,
    input   logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  mul_vect_i      ,
    input   logic [WIDTH - 1 : 0]                       mul_scal_i      ,
    output  logic                                       mul_valid_o     ,
    output  logic                                       mul_ready_o     ,
    output  logic [VECT_WIDTH - 1 : 0]                  mul_strb_o      ,
    output  logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  mul_res_o       
);

    typedef struct packed {
        logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  data;
        logic [VECT_WIDTH - 1 : 0]                  strb;
    } fifo_element_t;

    logic [VECT_WIDTH - 1 : 0] [2 : 0] [WIDTH - 1 : 0]  fma_operands;
    logic [VECT_WIDTH - 1 : 0]                          fma_valids,
                                                        fma_readies;

    logic   fma_i_valid,
            fma_i_ready;

    fifo_element_t  in_fifo,
                    add_fifo_out,
                    mul_fifo_out;

    logic   add_fifo_full,
            add_fifo_empty,
            add_fifo_push,
            add_fifo_pop;

    logic   mul_fifo_full,
            mul_fifo_empty,
            mul_fifo_push,
            mul_fifo_pop;

    fpnew_pkg::operation_e  fpnew_op;

    sfm_pkg::operation_t [VECT_WIDTH - 1 : 0]   o_operations;
    
    logic   op_mod;

    logic   [VECT_WIDTH - 1 : 0]    strb;

    //TODO Instantiate 2 FIFOs for the outputs

    assign fpnew_op     = operation_i == sfm_pkg::MUL ? fpnew_pkg::MUL : fpnew_pkg::ADD;
    assign op_mod       = operation_i == sfm_pkg::MUL ? op_mod_mul_i : op_mod_add_i;
    assign strb         = operation_i == sfm_pkg::MUL ? mul_strb_i : add_strb_i;

    assign fma_i_valid  = operation_i == sfm_pkg::MUL ? mul_valid_i : add_valid_i;
    assign fma_i_ready  = o_operations [0] == sfm_pkg::MUL ? ~mul_fifo_full : ~add_fifo_full;

    for (genvar i = 0; i < VECT_WIDTH; i++) begin
        assign fma_operands [i][0] = mul_scal_i;
        assign fma_operands [i][1] = operation_i == sfm_pkg::MUL ? mul_vect_i [i] : add_vect_i [i];
        assign fma_operands [i][2] = add_scal_i;

        fpnew_fma #(
            .FpFormat       (   FPFORMAT                ),
            .NumPipeRegs    (   NUM_REGS                ),
            .PipeConfig     (   REG_POS_CVFPU           ),
            .TagType        (   sfm_pkg::operation_t    ),
            .AuxType        (   logic                   )
        ) i_sum (
            .clk_i              (   clk_i               ),
            .rst_ni             (   rst_ni              ),
            .operands_i         (   fma_operands [i]    ),
            .is_boxed_i         (   '1                  ),
            .rnd_mode_i         (   round_mode_i        ),
            .op_i               (   fpnew_op            ),
            .op_mod_i           (   op_mod              ),
            .tag_i              (   operation_i         ),
            .mask_i             (   strb [i]            ),
            .aux_i              (   '0                  ),
            .in_valid_i         (   fma_i_valid         ),
            .in_ready_o         (   fma_readies [i]     ),
            .flush_i            (   clear_i             ),
            .result_o           (   in_fifo.data [i]    ),
            .status_o           (   ),
            .extension_bit_o    (   ),
            .tag_o              (   o_operations [i]    ),
            .mask_o             (   in_fifo.strb [i]    ),
            .aux_o              (   ),
            .out_valid_o        (   fma_valids [i]      ),
            .out_ready_i        (   fma_i_ready         ),
            .busy_o             (   )
        );
    end

    assign add_fifo_push    = o_operations [0] == sfm_pkg::ADD ? fma_valids [0] & (ADD_OUT_FIFO_DEPTH == 0 ? add_ready_i : ~add_fifo_full) : '0;
    assign add_fifo_pop     = add_ready_i & (ADD_OUT_FIFO_DEPTH == 0 ? (fma_valids [0] & (o_operations [0] == sfm_pkg::ADD)) : ~add_fifo_empty);

    fifo_v3 #(
        .FALL_THROUGH   (   0                   ),
        .DEPTH          (   ADD_OUT_FIFO_DEPTH  ),
        .dtype          (   fifo_element_t      )
    ) i_add_fifo (
        .clk_i       (  clk_i           ),            
        .rst_ni      (  rst_ni          ),           
        .flush_i     (  clear_i         ),          
        .testmode_i  (  '0              ),
        .full_o      (  add_fifo_full   ),           
        .empty_o     (  add_fifo_empty  ),          
        .usage_o     (),  
        .data_i      (  in_fifo         ),          
        .push_i      (  add_fifo_push   ),          
        .data_o      (  add_fifo_out    ),          
        .pop_i       (  add_fifo_pop    )     
    );

    assign mul_fifo_push    = o_operations [0] == sfm_pkg::MUL ? fma_valids [0] & (MUL_OUT_FIFO_DEPTH == 0 ? mul_ready_i : ~mul_fifo_full) : '0;
    assign mul_fifo_pop     = mul_ready_i & (MUL_OUT_FIFO_DEPTH == 0 ? (fma_valids [0] & (o_operations [0] == sfm_pkg::MUL)) : ~mul_fifo_empty);

    fifo_v3 #(
        .FALL_THROUGH   (   0                   ),
        .DEPTH          (   MUL_OUT_FIFO_DEPTH  ),
        .dtype          (   fifo_element_t      )
    ) i_mul_fifo (
        .clk_i       (  clk_i           ),
        .rst_ni      (  rst_ni          ),
        .flush_i     (  clear_i         ),
        .testmode_i  (  '0              ),
        .full_o      (  mul_fifo_full   ),
        .empty_o     (  mul_fifo_empty  ),
        .usage_o     (),
        .data_i      (  in_fifo         ),
        .push_i      (  mul_fifo_push   ),
        .data_o      (  mul_fifo_out    ),
        .pop_i       (  mul_fifo_pop    )
    );

    assign add_res_o    = add_fifo_out.data;
    assign add_strb_o   = add_fifo_out.strb;

    assign mul_res_o    = mul_fifo_out.data;
    assign mul_strb_o   = mul_fifo_out.strb;

    assign add_ready_o  = operation_i == sfm_pkg::ADD ? fma_readies [0] : '0;
    assign mul_ready_o  = operation_i == sfm_pkg::MUL ? fma_readies [0] : '0;

    assign add_valid_o  = ~add_fifo_empty;
    assign mul_valid_o  = ~mul_fifo_empty;

endmodule