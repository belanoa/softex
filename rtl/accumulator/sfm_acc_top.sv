module sfm_acc_top #(
    parameter fpnew_pkg::fp_format_e    ACC_FPFORMAT        = fpnew_pkg::FP32                   ,
    parameter fpnew_pkg::fp_format_e    ADD_FPFORMAT        = fpnew_pkg::FP32                   ,
    parameter fpnew_pkg::fp_format_e    MUL_FPFORMAT        = fpnew_pkg::FP16ALT                ,
    parameter int unsigned              N_INV_ITERS         = 2                                 ,
    parameter int unsigned              NUM_REGS_FMA        = 3                                 , 
    parameter int unsigned              FACTOR_FIFO_DEPTH   = 4                                 ,
    parameter int unsigned              ADDEND_FIFO_DEPTH   = NUM_REGS_FMA * FACTOR_FIFO_DEPTH  ,
    parameter int unsigned              N_FACT_FIFO         = 1                                 ,  
    parameter fpnew_pkg::roundmode_e    ROUND_MODE          = fpnew_pkg::RNE                    ,

    localparam int unsigned ACC_WIDTH   = fpnew_pkg::fp_width(ACC_FPFORMAT),
    localparam int unsigned ADD_WIDTH   = fpnew_pkg::fp_width(ADD_FPFORMAT),
    localparam int unsigned MUL_WIDTH   = fpnew_pkg::fp_width(MUL_FPFORMAT)
) (
    input   logic                           clk_i       ,
    input   logic                           rst_ni      ,
    input   logic                           clear_i     ,
    input   sfm_pkg::accumulator_ctrl_t     ctrl_i      ,
    input   logic                           add_valid_i ,
    input   logic [ADD_WIDTH - 1 : 0]       add_i       ,
    input   logic                           mul_valid_i ,
    input   logic [MUL_WIDTH - 1 : 0]       mul_i       ,
    output  logic                           ready_o     ,
    output  logic                           valid_o     ,
    output  sfm_pkg::accumulator_flags_t    flags_o     ,
    output  logic [ACC_WIDTH - 1 : 0]       acc_o
);

    sfm_pkg::acc_datapath_ctrl_t    datapath_ctrl;
    sfm_pkg::acc_datapath_flags_t   datapath_flags;

    sfm_acc_ctrl #(
        .N_INV_ITERS    (   N_INV_ITERS )
    ) i_acc_ctrl (
        .clk_i              (   clk_i           ),
        .rst_ni             (   rst_ni          ),
        .clear_i            (   clear_i         ),
        .ctrl_i             (   ctrl_i          ),
        .flags_o            (   flags_o         ),
        .ctrl_datapath_o    (   datapath_ctrl   ),
        .flags_datapath_i   (   datapath_flags  )
    );

    sfm_acc_datapath #(
        .ACC_FPFORMAT       (   ACC_FPFORMAT        ),
        .ADD_FPFORMAT       (   ADD_FPFORMAT        ),
        .MUL_FPFORMAT       (   MUL_FPFORMAT        ),
        .NUM_REGS_FMA       (   NUM_REGS_FMA        ),
        .FACTOR_FIFO_DEPTH  (   FACTOR_FIFO_DEPTH   ),
        .ADDEND_FIFO_DEPTH  (   ADDEND_FIFO_DEPTH   ),
        .N_FACT_FIFO        (   N_FACT_FIFO         ),
        .ROUND_MODE         (   ROUND_MODE          )
    ) i_acc_datapath (
        .clk_i          (   clk_i           ),
        .rst_ni         (   rst_ni          ),
        .clear_i        (   clear_i         ),
        .ctrl_i         (   datapath_ctrl   ),
        .add_valid_i    (   add_valid_i     ),
        .add_i          (   add_i           ),
        .mul_valid_i    (   mul_valid_i     ),
        .mul_i          (   mul_i           ),
        .ready_o        (   ready_o         ),
        .valid_o        (   valid_o         ),
        .flags_o        (   datapath_flags  ),
        .acc_o          (   acc_o           )
    );

endmodule