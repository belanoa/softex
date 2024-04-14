`include "sfm_macros.svh"

module sfm_fp_add_rec #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT    = fpnew_pkg::FP32   ,
    parameter int unsigned              N_INP       = 1                 ,
    parameter int unsigned              NUM_REGS    = 0                 ,
    parameter sfm_pkg::regs_config_t    REG_POS     = sfm_pkg::BEFORE   ,
    parameter type                      TAG_TYPE    = logic             ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT)
) (
    input   logic                                   clk_i   ,
    input   logic                                   rst_ni  ,
    input   logic                                   clear_i ,
    input   logic                                   valid_i ,
    input   logic                                   ready_i ,
    input   logic [N_INP - 1 : 0] [WIDTH - 1 : 0]   op_i    ,
    input   logic [N_INP - 1 : 0]                   strb_i  ,
    input   fpnew_pkg::roundmode_e                  mode_i  ,
    input   TAG_TYPE                                tag_i   ,
    output  logic                                   ready_o ,
    output  logic                                   valid_o ,
    output  logic [WIDTH - 1 : 0]                   res_o   ,
    output  logic                                   strb_o  ,
    output  TAG_TYPE                                tag_o   ,
    output  logic                                   busy_o  
);

    //The vector to be reduced is split into 2 smaller vectors (A and B)
    //which will be reduced separately

    localparam int unsigned             A_WIDTH         = (N_INP + 1) / 2;
    localparam int unsigned             B_WIDTH         = N_INP - A_WIDTH;
    localparam fpnew_pkg::pipe_config_t REG_POS_CVFPU   = sfm_pkg::sfm_to_cvfpu(REG_POS);

    logic [A_WIDTH - 1 : 0] [WIDTH - 1 : 0] a;
    logic [B_WIDTH - 1 : 0] [WIDTH - 1 : 0] b;

    logic [WIDTH - 1 : 0]   res_a,
                            res_b;

    logic   o_strb_a,
            o_strb_b;

    logic [A_WIDTH - 1 : 0] i_strb_a;
    logic [B_WIDTH - 1 : 0] i_strb_b;

    logic   sum_mask,
            sum_valid;

    logic   o_valid_a,
            o_valid_b,
            o_ready_a,
            o_ready_b,
            o_ready_sum;

    logic   o_valid_b_del,
            o_ready_b_del,
            o_strb_b_del;

    logic   a_o_busy,
            fma_o_busy;

    logic [WIDTH - 1 : 0]   res_b_del;

    logic [2 : 0][WIDTH - 1 : 0]    operands;

    TAG_TYPE    a_o_tag;

    if (N_INP != 1) begin
        assign a = op_i [A_WIDTH - 1 : 0];
        assign b = op_i [N_INP - 1 -: B_WIDTH];

        assign i_strb_a = strb_i [A_WIDTH - 1 : 0];
        assign i_strb_b = strb_i [N_INP - 1 -: B_WIDTH];
    end

    if (N_INP == 1) begin : gen_identity
        //If the module is instantiated with only one input
        //no operation has to be performed

        assign valid_o  = valid_i;
        assign ready_o  = ready_i;
        assign res_o    = op_i;
        assign strb_o   = strb_i;
        assign tag_o    = tag_i;
        assign busy_o   = '0;
    end else if (N_INP == 2) begin : gen_a_plus_b
        //If we only have 2 inputs we just sum them

        assign operands [0] = '0;
        assign operands [1] = strb_i [0] ? a : '0;
        assign operands [2] = strb_i [1] ? b : '0;

        fpnew_fma #(
            .FpFormat       (   FPFORMAT        ),
            .NumPipeRegs    (   NUM_REGS        ),
            .PipeConfig     (   REG_POS_CVFPU   ),
            .TagType        (   TAG_TYPE        ),
            .AuxType        (   logic           )
        ) i_sum (
            .clk_i              (   clk_i           ),
            .rst_ni             (   rst_ni          ),
            .operands_i         (   operands        ),
            .is_boxed_i         (   '1              ),
            .rnd_mode_i         (   mode_i          ),
            .op_i               (   fpnew_pkg::ADD  ),
            .op_mod_i           (   '0              ),
            .tag_i              (   tag_i           ),
            .mask_i             (   |strb_i         ),
            .aux_i              (   '0              ),
            .in_valid_i         (   valid_i         ),
            .in_ready_o         (   ready_o         ),
            .flush_i            (   clear_i         ),
            .result_o           (   res_o           ),
            .status_o           (                   ),
            .extension_bit_o    (                   ),
            .tag_o              (   tag_o           ),
            .mask_o             (   strb_o          ),
            .aux_o              (                   ),
            .out_valid_o        (   valid_o         ),
            .out_ready_i        (   ready_i         ),
            .busy_o             (   busy_o          )
        );
    end else begin : gen_recursion
        //Here we just instantiate 2 recursive blocks and sum their results

         sfm_fp_add_rec #(
            .FPFORMAT   (   FPFORMAT    ),
            .N_INP      (   A_WIDTH     ),
            .NUM_REGS   (   NUM_REGS    ),
            .REG_POS    (   REG_POS     ),
            .TAG_TYPE   (   TAG_TYPE    )
         ) i_a_sum (
            .clk_i      (   clk_i       ),
            .rst_ni     (   rst_ni      ),
            .clear_i    (   clear_i     ),
            .valid_i    (   valid_i     ),
            .ready_i    (   o_ready_sum ),
            .op_i       (   a           ),
            .strb_i     (   i_strb_a    ),
            .mode_i     (   mode_i      ),
            .tag_i      (   tag_i       ),
            .ready_o    (   o_ready_a   ),
            .valid_o    (   o_valid_a   ),
            .res_o      (   res_a       ),
            .strb_o     (   o_strb_a    ),
            .tag_o      (   a_o_tag     ),
            .busy_o     (   a_o_busy    )
        );

        sfm_fp_add_rec #(
            .FPFORMAT   (   FPFORMAT    ),
            .N_INP      (   B_WIDTH     ),
            .NUM_REGS   (   NUM_REGS    ),
            .REG_POS    (   REG_POS     ),
            .TAG_TYPE   (   TAG_TYPE    )
        ) i_b_sum (
            .clk_i      (   clk_i       ),
            .rst_ni     (   rst_ni      ),
            .clear_i    (   clear_i     ),
            .valid_i    (   valid_i     ),
            .ready_i    (   o_ready_sum ),
            .op_i       (   b           ),
            .strb_i     (   i_strb_b    ),
            .mode_i     (   mode_i      ),
            .tag_i      (   '0          ),
            .ready_o    (   o_ready_b   ),
            .valid_o    (   o_valid_b   ),
            .res_o      (   res_b       ),
            .strb_o     (   o_strb_b    ),
            .tag_o      (               ),
            .busy_o     (               )
        );

        if ((A_WIDTH > B_WIDTH) && ($countones(B_WIDTH) == 1)) begin : gen_b_delay
            //When A_WIDTH is greater than B_WIDTH and B_WIDTH is a power of 2
            //B need one less recursion than A, forcing us to add a delay on B

            sfm_delay #(
                .NUM_REGS   (   NUM_REGS    ),
                .DATA_WIDTH (   WIDTH       ),
                .NUM_ROWS   (   1           )
            ) i_b_delay (
                .clk_i      (   clk_i           ),
                .rst_ni     (   rst_ni          ),
                .enable_i   (   '1              ),
                .clear_i    (   clear_i         ),
                .valid_i    (   o_valid_b       ),
                .ready_i    (   o_ready_b       ),
                .data_i     (   res_b           ),
                .strb_i     (   o_strb_b        ),
                .valid_o    (   o_valid_b_del   ),
                .ready_o    (   o_ready_b_del   ),
                .data_o     (   res_b_del       ),
                .strb_o     (   o_strb_b_del    )
            );

            assign ready_o      = o_ready_a & o_ready_b_del;

            assign operands [0] = '0;
            assign operands [1] = o_strb_a ? res_a : '0;
            assign operands [2] = o_strb_b_del ? res_b_del : '0;

            assign sum_mask     = o_strb_a | o_strb_b_del;
            assign sum_valid    = o_valid_a | o_valid_b_del;
        end else begin
            assign ready_o      = o_ready_a & o_ready_b;

            assign operands [0] = '0;
            assign operands [1] = o_strb_a ? res_a : '0;
            assign operands [2] = o_strb_b ? res_b : '0;

            assign sum_mask     = o_strb_a | o_strb_b;
            assign sum_valid    = o_valid_a | o_valid_b;
        end

        fpnew_fma #(
            .FpFormat       (   FPFORMAT        ),
            .NumPipeRegs    (   NUM_REGS        ),
            .PipeConfig     (   REG_POS_CVFPU   ),
            .TagType        (   TAG_TYPE        ),
            .AuxType        (   logic           )
        ) i_sum (
            .clk_i              (   clk_i           ),
            .rst_ni             (   rst_ni          ),
            .operands_i         (   operands        ),
            .is_boxed_i         (   '1              ),
            .rnd_mode_i         (   mode_i          ),
            .op_i               (   fpnew_pkg::ADD  ),
            .op_mod_i           (   '0              ),
            .tag_i              (   a_o_tag         ),
            .mask_i             (   sum_mask        ),
            .aux_i              (   '0              ),
            .in_valid_i         (   sum_valid       ),
            .in_ready_o         (   o_ready_sum     ),
            .flush_i            (   clear_i         ),
            .result_o           (   res_o           ),
            .status_o           (                   ),
            .extension_bit_o    (                   ),
            .tag_o              (   tag_o           ),
            .mask_o             (   strb_o          ),
            .aux_o              (                   ),
            .out_valid_o        (   valid_o         ),
            .out_ready_i        (   ready_i         ),
            .busy_o             (   fma_o_busy      )
        );

        assign busy_o = a_o_busy | fma_o_busy;
    end

endmodule