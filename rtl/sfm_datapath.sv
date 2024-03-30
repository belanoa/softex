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
    input   sfm_pkg::datapath_ctrl_t                        ctrl_i      ,
    input   logic [VECT_WIDTH - 1 : 0]                      strb_i      ,
    input   logic [VECT_WIDTH - 1 : 0] [IN_WIDTH - 1 : 0]   data_i      ,
    output  logic                                           valid_o     ,
    output  logic                                           ready_o     ,
    output  sfm_pkg::datapath_flags_t                       flags_o     ,
    output  logic [VECT_WIDTH - 1 : 0]                      strb_o      ,
    output  logic [VECT_WIDTH - 1 : 0] [IN_WIDTH - 1 : 0]   res_o   
);

    logic [IN_WIDTH - 1 : 0]    old_max,
                                new_max,
                                max_diff,
                                scal_exp_res,
                                exp_delay,
                                inv_cast;

    logic [ACC_WIDTH - 1 : 0]   sum_res,
                                inv_pre_cast;

    logic   fma_arb_cnt,
            fma_arb_cnt_enable;

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
            acc_ready,
            acc_valid,
            mul_valid,
            mul_ready;

    logic [1:0] addmul_ready;

    logic [VECT_WIDTH - 1 : 0] [IN_WIDTH - 1 : 0]   delayed_data,
                                                    diff_vect,
                                                    exp_vect,
                                                    mul_res;

    logic [VECT_WIDTH - 1 : 0]  delayed_strb,
                                exp_strb,
                                diff_strb,
                                mul_strb; 

    sfm_pkg::operation_t    addmul_op;

                            
    assign ready_o  = max_ready & delay_ready;
    assign valid_o  = mul_valid;

    assign strb_o   = mul_strb;
    assign res_o    = mul_res;

    assign fma_arb_cnt_enable = ctrl_i.dividing & addmul_ready [fma_arb_cnt]; //TODO
    always_ff @(posedge clk_i or negedge rst_ni) begin : fma_arbitration_counter
        if (~rst_ni) begin
            fma_arb_cnt <= '0;
        end else begin
            if (clear_i) begin
                fma_arb_cnt <= '0;
            end else if (fma_arb_cnt_enable) begin
                fma_arb_cnt <= fma_arb_cnt + 1;
            end else begin
                fma_arb_cnt <= fma_arb_cnt;
            end
        end
    end

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
        .valid_i         (  valid_i & ~ctrl_i.dividing       ),
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
        .operation_i    (   '1                          ),
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
        .REG_POS                (   sfm_pkg::BEFORE     ),
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


    assign addmul_op        = fma_arb_cnt == '0 ? sfm_pkg::ADD : sfm_pkg::MUL;

    assign addmul_ready [0] = diff_ready;
    assign addmul_ready [1] = mul_ready;

    sfm_fp_vect_addmul #(
        .FPFORMAT           (   IN_FPFORMAT ),      
        .REG_POS            (   REG_POS     ),      
        .NUM_REGS           (   ADD_REGS    ),      
        .VECT_WIDTH         (   VECT_WIDTH  ),      
        .ADD_OUT_FIFO_DEPTH (   0           ),      
        .MUL_OUT_FIFO_DEPTH (   1           )      
    ) i_addmul_time_mux (
        .clk_i          (   clk_i           ),
        .rst_ni         (   rst_ni          ),
        .clear_i        (   clear_i         ),
        .enable_i       (   '1              ),
        .round_mode_i   (   fpnew_pkg::RNE  ),
        .operation_i    (   addmul_op       ),
        .op_mod_add_i   (   '1              ),
        .op_mod_mul_i   (   '0              ),
        .add_valid_i    (   delay_valid     ),
        .add_ready_i    (   exp_ready       ),
        .add_strb_i     (   delayed_strb    ),
        .add_vect_i     (   delayed_data    ),
        .add_scal_i     (   new_max         ),
        .add_valid_o    (   diff_valid      ),
        .add_ready_o    (   diff_ready      ),
        .add_strb_o     (   diff_strb       ),
        .add_res_o      (   diff_vect       ),
        .mul_valid_i    (   exp_valid       ),
        .mul_ready_i    (   ready_i         ),
        .mul_strb_i     (   exp_strb        ),
        .mul_vect_i     (   exp_vect        ),
        .mul_scal_i     (   inv_cast        ),
        .mul_valid_o    (   mul_valid       ),
        .mul_ready_o    (   mul_ready       ),
        .mul_strb_o     (   mul_strb        ),
        .mul_res_o      (   mul_res         )       
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
        .clk_i      (   clk_i                               ),
        .rst_ni     (   rst_ni                              ),
        .clear_i    (   clear_i                             ),
        .enable_i   (   '1                                  ),
        .valid_i    (   diff_valid                          ),
        .ready_i    (   ctrl_i.dividing ? mul_ready : sum_ready  ),
        .strb_i     (   diff_strb                           ),
        .op_i       (   diff_vect                           ),
        .res_o      (   exp_vect                            ),
        .valid_o    (   exp_valid                           ),
        .ready_o    (   exp_ready                           ),
        .strb_o     (   exp_strb                            )
    );

    sfm_fp_red_sum #(
        .IN_FPFORMAT    (   IN_FPFORMAT     ),
        .ACC_FPFORMAT   (   ACC_FPFORMAT    ),
        .REG_POS        (   REG_POS         ),
        .NUM_REGS       (   ADD_REGS        ),
        .VECT_WIDTH     (   VECT_WIDTH      )
    ) vect_sum (
        .clk_i      (   clk_i                   ),
        .rst_ni     (   rst_ni                  ),
        .clear_i    (   clear_i                 ),
        .enable_i   (   '1                      ),
        .valid_i    (   exp_valid & ~ctrl_i.dividing ),
        .ready_i    (   acc_ready               ),
        .mode_i     (   fpnew_pkg::RNE          ),
        .strb_i     (   exp_strb                ),
        .vect_i     (   exp_vect                ),
        .res_o      (   sum_res                 ),
        .strb_o     (                           ),
        .valid_o    (   sum_valid               ),
        .ready_o    (   sum_ready               )
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
        .clk_i          (   clk_i                       ),     
        .rst_ni         (   rst_ni                      ),     
        .clear_i        (   clear_i                     ),
        .ctrl_i         (   ctrl_i.accumulator_ctrl     ),    
        .add_valid_i    (   sum_valid                   ),
        .add_i          (   sum_res                     ),      
        .mul_valid_i    (   exp_delay_valid             ),
        .mul_i          (   exp_delay                   ),      
        //.finish_i       (   ctrl_i.acc_finished ),   
        .ready_o        (   acc_ready                   ),    
        .valid_o        (   acc_valid                   ),
        .flags_o        (   flags_o.accumulator_flags   ),
        .acc_o          (   inv_pre_cast                )
    );

    fpnew_cast_multi #(
        .FpFmtConfig    (   '1                  ),
        .IntFmtConfig   (   '0                  ),
        .NumPipeRegs    (   0                   ),
        .PipeConfig     (   fpnew_pkg::BEFORE   ),
        .TagType        (   logic               ),
        .AuxType        (   logic               )
    ) i_inv_cast (
        .clk_i              (   clk_i                   ),
        .rst_ni             (   rst_ni                  ),
        .operands_i         (   inv_pre_cast            ),
        .is_boxed_i         (   '1                      ),
        .rnd_mode_i         (   fpnew_pkg::RNE          ),
        .op_i               (   '0                      ),
        .op_mod_i           (   '0                      ),
        .src_fmt_i          (   ACC_FPFORMAT            ),
        .dst_fmt_i          (   IN_FPFORMAT             ),
        .int_fmt_i          (   '0                      ),
        .tag_i              (   '0                      ),
        .mask_i             (   '0                      ),
        .aux_i              (   '0                      ),
        .in_valid_i         (   '1                      ),
        .in_ready_o         (                           ),
        .flush_i            (   '0                      ),
        .result_o           (   inv_cast                ),
        .status_o           (                           ),
        .extension_bit_o    (                           ),
        .tag_o              (                           ),
        .mask_o             (                           ),
        .aux_o              (                           ),
        .out_valid_o        (                           ),
        .out_ready_i        (   '1                      ),
        .busy_o             (                           )
    );

endmodule