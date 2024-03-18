module sfm_datapath #(
    parameter fpnew_pkg::fp_format_e    IN_FPFORMAT         = fpnew_pkg::FP16ALT            ,
    parameter fpnew_pkg::fp_format_e    ACC_FPFORMAT        = fpnew_pkg::FP32               ,
    parameter sfm_pkg::regs_config_t    REG_POS             = sfm_pkg::BEFORE               ,
    parameter int unsigned              VECT_WIDTH          = 1                             ,
    parameter int unsigned              ADD_REGS            = 3                             ,
    parameter int unsigned              MUL_REGS            = 3                             ,
    parameter int unsigned              MAX_REGS            = 1                             ,
    parameter int unsigned              EXP_REGS            = 2                             ,
    parameter int unsigned              FMA_REGS            = 3                             ,
    parameter int unsigned              FACTOR_FIFO_DEPTH   = 5                             ,
    parameter int unsigned              ADDEND_FIFO_DEPTH   = FACTOR_FIFO_DEPTH * FMA_REGS  ,

    localparam int unsigned IN_WIDTH        = fpnew_pkg::fp_width(IN_FPFORMAT)  ,
    localparam int unsigned ACC_WIDTH       = fpnew_pkg::fp_width(ACC_FPFORMAT) ,
    localparam int unsigned VECT_SUM_DELAY  = $clog2(VECT_WIDTH) * ADD_REGS
) (
    input   logic                                           clk_i       ,
    input   logic                                           rst_ni      ,
    input   logic                                           clear_i     ,
    input   logic                                           valid_i     ,
    input   logic                                           ready_i     ,
    input   logic                                           finish_i    ,       //This signal will most likely end up in a structure
    input   logic [VECT_WIDTH - 1 : 0]                      strb_i      ,
    input   logic [VECT_WIDTH - 1 : 0] [IN_WIDTH - 1 : 0]   data_i   ,
    output  logic                                           valid_o     ,
    output  logic                                           ready_o     ,
    output  logic [IN_WIDTH - 1 : 0]                        res_o   
);

    logic [IN_WIDTH - 1 : 0]    old_max,
                                new_max,
                                max_diff,
                                scal_exp_res,
                                exp_delay;

    logic [ACC_WIDTH - 1 : 0]   sum_res;

    logic   new_max_flag;

    logic   max_valid,
            max_ready,
            max_diff_valid,
            max_diff_ready,
            scal_exp_valid,
            scal_exp_ready,
            exp_delay_valid,
            exp_delay_ready,
            delay_valid,
            delay_ready,
            diff_valid,
            diff_ready,
            exp_valid,
            exp_ready,
            sum_valid,
            sum_ready,
            acc_ready;

    logic [VECT_WIDTH - 1 : 0] [IN_WIDTH - 1 : 0]   delayed_data,
                                                    diff_vect,
                                                    exp_vect;

    logic [VECT_WIDTH - 1 : 0]  delayed_strb,
                                exp_strb,
                                diff_strb; 

                            
    assign ready_o = max_ready & delay_ready;

    sfm_fp_glob_minmax #(
        .FPFORMAT   (   IN_FPFORMAT     ),
        .REG_POS    (   REG_POS         ),
        .NUM_REGS   (   MAX_REGS        ),
        .VECT_WIDTH (   VECT_WIDTH      ),
        .MM_MODE    (   sfm_pkg::MAX    )
    ) global_maximum (
        .clk_i           (  clk_i                       ),
        .rst_ni          (  rst_ni                      ),
        .clear_i         (  clear_i                     ),
        .enable_i        (  '1                          ),
        .valid_i         (  valid_i                     ),
        .ready_i         (  max_diff_ready & diff_ready ),
        .strb_i          (  strb_i                      ),
        .vect_i          (  data_i                      ),
        .cur_minmax_o    (  old_max                     ),
        .new_minmax_o    (  new_max                     ),
        .new_flg_o       (  new_max_flag                ),
        .valid_o         (  max_valid                   ),
        .ready_o         (  max_ready                   )
    );

    sfm_fp_vect_addsub #(
        .FPFORMAT   (   IN_FPFORMAT ),           
        .REG_POS    (   REG_POS     ),            
        .NUM_REGS   (   ADD_REGS    ),              
        .VECT_WIDTH (   1           )              
    ) new_old_max_diff (
        .clk_i          (   clk_i                       ),
        .rst_ni         (   rst_ni                      ),
        .clear_i        (   clear_i                     ),
        .enable_i       (   '1                          ),
        .valid_i        (   new_max_flag & max_valid    ),
        .ready_i        (   scal_exp_ready              ),
        .round_mode_i   (   fpnew_pkg::RNE              ),
        .operation_i    (   sfm_pkg::SUB                ),
        .strb_i         (   '1                          ),
        .vect_i         (   old_max                     ),
        .scal_i         (   new_max                     ),
        .res_o          (   max_diff                    ),
        .strb_o         (                               ),
        .valid_o        (   max_diff_valid              ),
        .ready_o        (   max_diff_ready              )
    );

    expu_top #(
        .FPFORMAT               (   IN_FPFORMAT         ),
        .REG_POS                (   expu_pkg::BEFORE    ),
        .NUM_REGS               (   EXP_REGS            ),
        .N_ROWS                 (   1                   ),
        .A_FRACTION             (   14                  ),
        .ENABLE_ROUNDING        (   1                   ),
        .ENABLE_MANT_CORRECTION (   1                   ),
        .COEFFICIENT_FRACTION   (   4                   ),
        .CONSTANT_FRACTION      (   7                   ),
        .MUL_SURPLUS_BITS       (   1                   ),
        .NOT_SURPLUS_BITS       (   0                   ),
        .ALPHA_REAL             (   0.24609375          ),
        .BETA_REAL              (   0.41015625          ),
        .GAMMA_1_REAL           (   2.8359375           ),
        .GAMMA_2_REAL           (   2.16796875          )
    ) scal_exp (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .clear_i    (   clear_i         ),
        .enable_i   (   '1              ),
        .valid_i    (   max_diff_valid  ),
        .ready_i    (   exp_delay_ready ),
        .strb_i     (   '1              ),
        .op_i       (   max_diff        ),
        .res_o      (   scal_exp_res    ),
        .valid_o    (   scal_exp_valid  ),
        .ready_o    (   scal_exp_ready  ),
        .strb_o     (                   )
    );

    sfm_delay #(
        .NUM_REGS   (   VECT_SUM_DELAY  ),  
        .DATA_WIDTH (   IN_WIDTH        ),
        .NUM_ROWS   (   1               )
    ) correction_delay (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .enable_i   (   '1              ),
        .clear_i    (   clear_i         ),
        .valid_i    (   scal_exp_valid  ),
        .ready_i    (   acc_ready       ),
        .data_i     (   scal_exp_res    ),
        .strb_i     (   '1              ),
        .valid_o    (   exp_delay_valid ),
        .ready_o    (   exp_delay_ready ),
        .data_o     (   exp_delay       ),
        .strb_o     (                   )
    ); 

    sfm_delay #(
        .NUM_REGS   (   MAX_REGS    ),
        .DATA_WIDTH (   IN_WIDTH    ),
        .NUM_ROWS   (   VECT_WIDTH  )
    ) data_delay (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .enable_i   (   '1              ),
        .clear_i    (   clear_i         ),
        .valid_i    (   valid_i         ),
        .ready_i    (   diff_ready      ),
        .data_i     (   data_i          ),
        .strb_i     (   strb_i          ),
        .valid_o    (   delay_valid     ),
        .ready_o    (   delay_ready     ),
        .data_o     (   delayed_data    ),
        .strb_o     (   delayed_strb    )
    ); 

    sfm_fp_vect_addsub #(
        .FPFORMAT   (   IN_FPFORMAT ),           
        .REG_POS    (   REG_POS     ),            
        .NUM_REGS   (   ADD_REGS    ),              
        .VECT_WIDTH (   VECT_WIDTH  )              
    ) vect_max_diff (
        .clk_i          (   clk_i           ),
        .rst_ni         (   rst_ni          ),
        .clear_i        (   clear_i         ),
        .enable_i       (   '1              ),
        .valid_i        (   delay_valid     ),
        .ready_i        (   exp_ready       ),
        .round_mode_i   (   fpnew_pkg::RNE  ),
        .operation_i    (   sfm_pkg::SUB    ),
        .strb_i         (   delayed_strb    ),
        .vect_i         (   delayed_data    ),
        .scal_i         (   new_max         ),
        .res_o          (   diff_vect       ),
        .strb_o         (   diff_strb       ),
        .valid_o        (   diff_valid      ),
        .ready_o        (   diff_ready      )
    );

    expu_top #(
        .FPFORMAT               (   IN_FPFORMAT         ),
        .REG_POS                (   expu_pkg::BEFORE    ),
        .NUM_REGS               (   EXP_REGS            ),
        .N_ROWS                 (   VECT_WIDTH          ),
        .A_FRACTION             (   14                  ),
        .ENABLE_ROUNDING        (   1                   ),
        .ENABLE_MANT_CORRECTION (   1                   ),
        .COEFFICIENT_FRACTION   (   4                   ),
        .CONSTANT_FRACTION      (   7                   ),
        .MUL_SURPLUS_BITS       (   1                   ),
        .NOT_SURPLUS_BITS       (   0                   ),
        .ALPHA_REAL             (   0.24609375          ),
        .BETA_REAL              (   0.41015625          ),
        .GAMMA_1_REAL           (   2.8359375           ),
        .GAMMA_2_REAL           (   2.16796875          )
    ) vect_exp (
        .clk_i      (   clk_i       ),
        .rst_ni     (   rst_ni      ),
        .clear_i    (   clear_i     ),
        .enable_i   (   '1          ),
        .valid_i    (   diff_valid  ),
        .ready_i    (   sum_ready   ),
        .strb_i     (   diff_strb   ),
        .op_i       (   diff_vect   ),
        .res_o      (   exp_vect    ),
        .valid_o    (   exp_valid   ),
        .ready_o    (   exp_ready   ),
        .strb_o     (   exp_strb    )
    );

    sfm_fp_red_sum #(
        .IN_FPFORMAT    (   IN_FPFORMAT     ),
        .ACC_FPFORMAT   (   ACC_FPFORMAT    ),
        .REG_POS        (   REG_POS         ),
        .NUM_REGS       (   ADD_REGS        ),
        .VECT_WIDTH     (   VECT_WIDTH      )
    ) vect_sum (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .clear_i    (   clear_i         ),
        .enable_i   (   '1              ),
        .valid_i    (   exp_valid       ),
        .ready_i    (   acc_ready       ),
        .mode_i     (   fpnew_pkg::RNE  ),
        .strb_i     (   exp_strb        ),
        .vect_i     (   exp_vect        ),
        .res_o      (   sum_res         ),
        .strb_o     (   ),
        .valid_o    (   sum_valid       ),
        .ready_o    (   sum_ready       )
    );

    sfm_accumulator #(  
        .ACC_FPFORMAT       (   ACC_FPFORMAT        ),
        .ADD_FPFORMAT       (   ACC_FPFORMAT        ),
        .MUL_FPFORMAT       (   IN_FPFORMAT         ),
        .FACTOR_FIFO_DEPTH  (   FACTOR_FIFO_DEPTH   ),
        .ADDEND_FIFO_DEPTH  (   ADDEND_FIFO_DEPTH   ),
        .N_FACT_FIFO        (   1                   ),
        .NUM_REGS_FMA       (   FMA_REGS            ),
        .ROUND_MODE         (   fpnew_pkg::RNE      )
    ) denominator_accumulator (
        .clk_i          (   clk_i           ),     
        .rst_ni         (   rst_ni          ),     
        .clear_i        (   clear_i         ),    
        .add_valid_i    (   sum_valid       ),
        .add_i          (   sum_res         ),      
        .mul_valid_i    (   exp_delay_valid ),
        .mul_i          (   exp_delay       ),      
        .finish_i       (   finish_i        ),   
        .ready_o        (   acc_ready       ),    
        .valid_o        (   ),    
        .acc_o          (   )
    );

endmodule