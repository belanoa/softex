// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

`include "sfm_macros.svh"

import hwpe_stream_package::*;
import sfm_pkg::*;

module sfm_datapath #(
    parameter fpnew_pkg::fp_format_e    IN_FPFORMAT         = FPFORMAT_IN       ,
    parameter fpnew_pkg::fp_format_e    ACC_FPFORMAT        = FPFORMAT_ACC      ,
    parameter sfm_pkg::regs_config_t    REG_POS             = DEFAULT_REG_POS   ,
    parameter int unsigned              VECT_WIDTH          = N_ROWS            ,
    parameter int unsigned              SUM_REGS_IN         = NUM_REGS_SUM_IN   ,
    parameter int unsigned              SUM_REGS_ACC        = NUM_REGS_SUM_ACC  ,
    parameter int unsigned              MAX_REGS            = NUM_REGS_MAX      ,
    parameter int unsigned              EXP_REGS            = NUM_REGS_EXPU     ,
    parameter int unsigned              FMA_REGS_IN         = NUM_REGS_FMA_IN   ,
    parameter int unsigned              FMA_REGS_ACC        = NUM_REGS_FMA_ACC  ,

    localparam int unsigned IN_WIDTH    = fpnew_pkg::fp_width(IN_FPFORMAT)
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

    localparam int unsigned ACC_WIDTH       = fpnew_pkg::fp_width(ACC_FPFORMAT);
    localparam int unsigned VECT_SUM_DELAY  = $clog2(VECT_WIDTH) * SUM_REGS_ACC;

    logic [IN_WIDTH - 1 : 0]    old_max,
                                new_max,
                                max_diff,
                                scal_exp_res,
                                exp_delay,
                                inv_cast;

    logic [ACC_WIDTH - 1 : 0]   sum_res,
                                acc_i_add,
                                inv_pre_cast,
                                inv_cast_res;

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
            cast_valid,
            mul_valid,
            mul_ready;

    logic   addmul_o_busy,
            exp_o_busy,
            sum_o_busy;

    logic [1:0] addmul_ready;

    logic [VECT_WIDTH - 1 : 0] [IN_WIDTH - 1 : 0]   delayed_data,
                                                    diff_vect,
                                                    exp_vect,
                                                    mul_res;

    logic [VECT_WIDTH - 1 : 0]  delayed_strb,
                                exp_strb,
                                diff_strb,
                                mul_strb; 

    logic   addmul_o_tag,
            expu_o_tag,
            sum_o_tag;

    sfm_pkg::operation_t    addmul_op;

    flags_fifo_t    add_fifo_o_flgs;

    hwpe_stream_intf_stream #(.DATA_WIDTH(IN_WIDTH))    fact_fifo_d (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(IN_WIDTH))    fact_fifo_q (.clk(clk_i));

    hwpe_stream_intf_stream #(.DATA_WIDTH(IN_WIDTH * VECT_WIDTH + 1))  add_fifo_d  (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(IN_WIDTH * VECT_WIDTH + 1))  add_fifo_q  (.clk(clk_i));
                            
    assign ready_o  = max_ready & delay_ready;
    assign valid_o  = mul_valid;

    assign strb_o   = mul_strb;
    assign res_o    = mul_res;

    assign flags_o.datapath_busy = |{addmul_o_busy, exp_o_busy, sum_o_busy, ~add_fifo_o_flgs.empty};

    // During the normalisation step "i_addmul_time_mux" is used to both
    // substract the maximum value to the input and to normalise the 
    // exponentiated score

    assign fma_arb_cnt_enable = ctrl_i.dividing & addmul_ready [fma_arb_cnt];
    always_ff @(posedge clk_i or negedge rst_ni) begin : fma_arbitration_counter
        if (~rst_ni) begin
            fma_arb_cnt <= '0;
        end else begin
            if (clear_i | ctrl_i.clear_regs) begin
                fma_arb_cnt <= '0;
            end else if (fma_arb_cnt_enable) begin
                fma_arb_cnt <= fma_arb_cnt + 1;
            end else begin
                fma_arb_cnt <= fma_arb_cnt;
            end
        end
    end

    assign flags_o.max  = new_max;

    sfm_fp_glob_minmax #(
        .FPFORMAT   (   IN_FPFORMAT     ),
        .REG_POS    (   REG_POS         ),
        .NUM_REGS   (   MAX_REGS        ),
        .VECT_WIDTH (   VECT_WIDTH      )
    ) i_global_maximum (
        .clk_i           (  clk_i                           ),
        .rst_ni          (  rst_ni                          ),
        .clear_i         (  clear_i | ctrl_i.clear_regs     ),
        .enable_i        (  '1                              ),
        .valid_i         (  valid_i & ~ctrl_i.disable_max   ),
        .ready_i         (  max_diff_ready & diff_ready     ),
        .operation_i     (  sfm_pkg::MAX                    ),
        .strb_i          (  strb_i                          ),
        .vect_i          (  data_i                          ),
        .load_i          (  ctrl_i.max                      ),
        .load_en_i       (  ctrl_i.load_max                 ),
        .cur_minmax_o    (  old_max                         ),
        .new_minmax_o    (  new_max                         ),
        .new_flg_o       (  new_max_flag                    ),
        .valid_o         (  max_valid                       ),
        .ready_o         (  max_ready                       )
    );

    fpnew_fma #(
        .FpFormat       (   IN_FPFORMAT             ),
        .NumPipeRegs    (   SUM_REGS_IN             ),
        .PipeConfig     (   fpnew_pkg::DISTRIBUTED  ),
        .TagType        (   logic                   ),
        .AuxType        (   logic                   )
    ) i_new_old_max_diff (
        .clk_i              (   clk_i                                   ),
        .rst_ni             (   rst_ni                                  ),
        .operands_i         (   {new_max, old_max, {(IN_WIDTH){1'b0}}}  ),
        .is_boxed_i         (   '1                                      ),
        .rnd_mode_i         (   fpnew_pkg::RNE                          ),
        .op_i               (   fpnew_pkg::ADD                          ),
        .op_mod_i           (   '1                                      ),
        .tag_i              (   '0                                      ),
        .mask_i             (   '1                                      ),
        .aux_i              (   '0                                      ),
        .in_valid_i         (   new_max_flag & max_valid                ),
        .in_ready_o         (   max_diff_ready                          ),
        .flush_i            (   clear_i                                 ),
        .result_o           (   max_diff                                ),
        .status_o           (                                           ),
        .extension_bit_o    (                                           ),
        .tag_o              (                                           ),
        .mask_o             (                                           ),
        .aux_o              (                                           ),
        .out_valid_o        (   max_diff_valid                          ),
        .out_ready_i        (   scal_exp_ready                          ),
        .busy_o             (                                           )
    );

    expu_top #(
        .FPFORMAT               (   IN_FPFORMAT ),
        .REG_POS                (   REG_POS     ),
        .NUM_REGS               (   EXP_REGS    ),
        .N_ROWS                 (   1           )
    ) i_scal_exp (
        .clk_i      (   clk_i               ),
        .rst_ni     (   rst_ni              ),
        .clear_i    (   clear_i             ),
        .enable_i   (   '1                  ),
        .valid_i    (   max_diff_valid      ),
        .ready_i    (   fact_fifo_d.ready   ),
        .strb_i     (   '1                  ),
        .op_i       (   max_diff            ),
        .res_o      (   scal_exp_res        ),
        .valid_o    (   scal_exp_valid      ),
        .ready_o    (   scal_exp_ready      ),
        .strb_o     (                       )
    );

    assign fact_fifo_d.valid    = scal_exp_valid;
    assign fact_fifo_d.data     = scal_exp_res;
    assign fact_fifo_d.strb     = '1;

    hwpe_stream_fifo #(
        .DATA_WIDTH (   IN_WIDTH                                                            ),
        .FIFO_DEPTH (   VECT_SUM_DELAY % 2 == 0 ? VECT_SUM_DELAY + 2 : VECT_SUM_DELAY + 3   )   //FIFO_DEPTH must be a multiple of 2
    ) i_fact_fifo (
        .clk_i      (   clk_i       ),
        .rst_ni     (   rst_ni      ),
        .clear_i    (   clear_i     ),
        .flags_o    (               ),
        .push_i     (   fact_fifo_d ),
        .pop_o      (   fact_fifo_q )
    );

    assign fact_fifo_q.ready    = acc_ready & sum_o_tag;

    sfm_delay #(
        .NUM_REGS   (   MAX_REGS    ),
        .DATA_WIDTH (   IN_WIDTH    ),
        .NUM_ROWS   (   VECT_WIDTH  )
    ) i_data_delay (
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
        .NUM_REGS           (   FMA_REGS_IN ),
        .VECT_WIDTH         (   VECT_WIDTH  ),
        .TAG_TYPE           (   logic       )    
    ) i_addmul_time_mux (
        .clk_i              (   clk_i                                           ),
        .rst_ni             (   rst_ni                                          ),
        .clear_i            (   clear_i                                         ),
        .enable_i           (   '1                                              ),
        .round_mode_i       (   fpnew_pkg::RNE                                  ),
        .operation_i        (   addmul_op                                       ),
        .op_mod_add_i       (   '1                                              ),
        .op_mod_mul_i       (   '0                                              ),
        .busy_o             (   addmul_o_busy                                   ),
        .add_valid_i        (   delay_valid                                     ),
        .add_scal_valid_i   (   '1                                              ),
        .add_ready_i        (   exp_ready                                       ),
        .add_strb_i         (   delayed_strb                                    ),
        .add_vect_i         (   delayed_data                                    ),
        .add_scal_i         (   new_max                                         ),
        .add_tag_i          (   new_max_flag & max_valid                        ),
        .add_valid_o        (   diff_valid                                      ),
        .add_ready_o        (   diff_ready                                      ),
        .add_strb_o         (   diff_strb                                       ),
        .add_res_o          (   diff_vect                                       ),
        .add_tag_o          (   addmul_o_tag                                    ),
        .mul_valid_i        (   add_fifo_q.valid                                ),
        .mul_scal_valid_i   (   cast_valid                                      ),
        .mul_ready_i        (   ready_i                                         ),
        .mul_strb_i         (   add_fifo_q.strb [VECT_WIDTH - 1 : 0]            ),
        .mul_vect_i         (   add_fifo_q.data [IN_WIDTH * VECT_WIDTH - 1 : 0] ),
        .mul_scal_i         (   inv_cast                                        ),
        .mul_valid_o        (   mul_valid                                       ),
        .mul_ready_o        (   mul_ready                                       ),
        .mul_strb_o         (   mul_strb                                        ),
        .mul_res_o          (   mul_res                                         )       
    );

    expu_top #(
        .FPFORMAT               (   IN_FPFORMAT ),
        .REG_POS                (   REG_POS     ),
        .NUM_REGS               (   EXP_REGS    ),
        .N_ROWS                 (   VECT_WIDTH  ),
        .TAG_TYPE               (   logic       )
    ) i_vect_exp (
        .clk_i      (   clk_i               ),
        .rst_ni     (   rst_ni              ),
        .clear_i    (   clear_i             ),
        .enable_i   (   '1                  ),
        .valid_i    (   diff_valid          ),
        .ready_i    (   add_fifo_d.ready    ),
        .strb_i     (   diff_strb           ),
        .op_i       (   diff_vect           ),
        .tag_i      (   addmul_o_tag        ),
        .res_o      (   exp_vect            ),
        .valid_o    (   exp_valid           ),
        .ready_o    (   exp_ready           ),
        .strb_o     (   exp_strb            ),
        .tag_o      (   expu_o_tag          ),
        .busy_o     (   exp_o_busy          )
    );

    assign add_fifo_d.valid = exp_valid;
    assign add_fifo_d.data  = {expu_o_tag, exp_vect};
    assign add_fifo_d.strb  = {{(IN_WIDTH / 8 * VECT_WIDTH - VECT_WIDTH){1'b0}}, exp_strb};

    hwpe_stream_fifo #(
        .DATA_WIDTH (   IN_WIDTH * VECT_WIDTH + 1   ),
        .FIFO_DEPTH (   2                           )
    ) i_add_fifo (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .clear_i    (   clear_i         ),
        .flags_o    (   add_fifo_o_flgs ),
        .push_i     (   add_fifo_d      ),
        .pop_o      (   add_fifo_q      )
    );

    assign add_fifo_q.ready = ctrl_i.dividing ? mul_ready : sum_ready;

    sfm_fp_red_sum #(
        .IN_FPFORMAT    (   IN_FPFORMAT     ),
        .ACC_FPFORMAT   (   ACC_FPFORMAT    ),
        .REG_POS        (   REG_POS         ),
        .NUM_REGS       (   SUM_REGS_ACC    ),
        .VECT_WIDTH     (   VECT_WIDTH      ),
        .TAG_TYPE       (   logic           )
    ) i_vect_sum (
        .clk_i      (   clk_i                                           ),
        .rst_ni     (   rst_ni                                          ),
        .clear_i    (   clear_i                                         ),
        .enable_i   (   '1                                              ),
        .valid_i    (   add_fifo_q.valid & ~ctrl_i.dividing             ),
        .ready_i    (   acc_ready                                       ),
        .mode_i     (   fpnew_pkg::RNE                                  ),
        .strb_i     (   add_fifo_q.strb [VECT_WIDTH - 1 : 0]            ),
        .vect_i     (   add_fifo_q.data [IN_WIDTH * VECT_WIDTH - 1 : 0] ),
        .tag_i      (   add_fifo_q.data [IN_WIDTH * VECT_WIDTH]         ),
        .res_o      (   sum_res                                         ),
        .strb_o     (                                                   ),
        .valid_o    (   sum_valid                                       ),
        .ready_o    (   sum_ready                                       ),
        .tag_o      (   sum_o_tag                                       ),
        .busy_o     (   sum_o_busy                                      )
    );

    assign acc_i_add = ctrl_i.load_denominator ? ctrl_i.denominator : sum_res;

    sfm_acc_top #(  
        .ACC_FPFORMAT       (   ACC_FPFORMAT        ),
        .ADD_FPFORMAT       (   ACC_FPFORMAT        ),
        .MUL_FPFORMAT       (   IN_FPFORMAT         ),
        .NUM_REGS_FMA       (   FMA_REGS_ACC        ),
        .ROUND_MODE         (   fpnew_pkg::RNE      )
    ) i_denominator_accumulator (
        .clk_i          (   clk_i                               ),     
        .rst_ni         (   rst_ni                              ),     
        .clear_i        (   clear_i | ctrl_i.clear_regs         ),
        .ctrl_i         (   ctrl_i.accumulator_ctrl             ),    
        .add_valid_i    (   sum_valid | ctrl_i.load_denominator ),
        .add_i          (   acc_i_add                           ),      
        .mul_valid_i    (   fact_fifo_q.valid & sum_o_tag       ),
        .mul_i          (   fact_fifo_q.data                    ),         
        .ready_o        (   acc_ready                           ),    
        .valid_o        (   acc_valid                           ),
        .flags_o        (   flags_o.accumulator_flags           ),
        .acc_o          (   inv_pre_cast                        )
    );

    fpnew_cast_multi #(
        .FpFmtConfig    (   `FMT_TO_CONF(ACC_FPFORMAT, IN_FPFORMAT) ),
        .IntFmtConfig   (   '0                                      ),
        .NumPipeRegs    (   0                                       ),
        .PipeConfig     (   fpnew_pkg::BEFORE                       ),
        .TagType        (   logic                                   ),
        .AuxType        (   logic                                   )
    ) i_inv_cast (
        .clk_i              (   clk_i           ),
        .rst_ni             (   rst_ni          ),
        .operands_i         (   inv_pre_cast    ),
        .is_boxed_i         (   '1              ),
        .rnd_mode_i         (   fpnew_pkg::RNE  ),
        .op_i               (   '0              ),
        .op_mod_i           (   '0              ),
        .src_fmt_i          (   ACC_FPFORMAT    ),
        .dst_fmt_i          (   IN_FPFORMAT     ),
        .int_fmt_i          (   '0              ),
        .tag_i              (   '0              ),
        .mask_i             (   '0              ),
        .aux_i              (   '0              ),
        .in_valid_i         (   acc_valid       ),
        .in_ready_o         (                   ),
        .flush_i            (   '0              ),
        .result_o           (   inv_cast_res    ),
        .status_o           (                   ),
        .extension_bit_o    (                   ),
        .tag_o              (                   ),
        .mask_o             (                   ),
        .aux_o              (                   ),
        .out_valid_o        (   cast_valid      ),
        .out_ready_i        (   '1              ),
        .busy_o             (                   )
    );

    assign inv_cast = inv_cast_res;

endmodule