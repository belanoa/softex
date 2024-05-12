// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import fpnew_pkg::*;

package softex_pkg;
    parameter int unsigned  DATA_W  = 128 + 32;

    parameter int unsigned  N_CTRL_CNTX         = 2;
    parameter int unsigned  N_CTRL_REGS         = 6;
    parameter int unsigned  N_CTRL_STATE_SLOTS  = 2;

    parameter fpnew_pkg::fp_format_e    FPFORMAT_IN     = fpnew_pkg::FP16ALT;
    parameter fpnew_pkg::fp_format_e    FPFORMAT_ACC    = fpnew_pkg::FP32;
    parameter int unsigned              N_NEWTON_ITERS  = 2;
    parameter int unsigned              ACC_FACT_FIFO_D = 3;
    parameter int unsigned              N_BITS_INV      = 7;
    parameter int unsigned              SLOT_ADDR_BITS  = 8;

    parameter int unsigned  NUM_REGS_EXPU       = 1;
    parameter int unsigned  NUM_REGS_FMA_IN     = 1;
    parameter int unsigned  NUM_REGS_FMA_ACC    = 3;
    parameter int unsigned  NUM_REGS_SUM_IN     = 1;
    parameter int unsigned  NUM_REGS_SUM_ACC    = 2;
    parameter int unsigned  NUM_REGS_MAX        = 0;
    parameter int unsigned  NUM_REGS_INV_APPR   = 1;

    localparam int unsigned WIDTH_IN    = fpnew_pkg::fp_width(FPFORMAT_IN);
    localparam int unsigned WIDTH_ACC   = fpnew_pkg::fp_width(FPFORMAT_ACC);

    parameter int unsigned  INT_W       = 8;

    parameter int unsigned  N_ROWS  = (DATA_W - 32) / WIDTH_IN;

    //Exponential unit constants
    parameter int unsigned  EXPU_A_FRACTION             = 14;
    parameter logic         EXPU_ENABLE_ROUNDING        = 1;
    parameter logic         EXPU_ENABLE_MANT_CORRECTION = 1;
    parameter int unsigned  EXPU_COEFFICIENT_FRACTION   = 4;
    parameter int unsigned  EXPU_CONSTANT_FRACTION      = 7;
    parameter int unsigned  EXPU_MUL_SURPLUS_BITS       = 1;
    parameter int unsigned  EXPU_NOT_SURPLUS_BITS       = 0;
    parameter real          EXPU_ALPHA_REAL             = 0.24609375;
    parameter real          EXPU_BETA_REAL              = 0.41015625;
    parameter real          EXPU_GAMMA_1_REAL           = 2.8359375;
    parameter real          EXPU_GAMMA_2_REAL           = 2.16796875;
    parameter int unsigned  EXPU_ALPHA_FIXED            = int'(EXPU_ALPHA_REAL * 2 ** EXPU_COEFFICIENT_FRACTION);
    parameter int unsigned  EXPU_BETA_FIXED             = int'(EXPU_BETA_REAL * 2 ** EXPU_COEFFICIENT_FRACTION);
    parameter int unsigned  EXPU_GAMMA_1_FIXED          = int'(EXPU_GAMMA_1_REAL * 2 ** EXPU_CONSTANT_FRACTION);
    parameter int unsigned  EXPU_GAMMA_2_FIXED          = int'(EXPU_GAMMA_2_REAL * 2 ** EXPU_CONSTANT_FRACTION);

    //Register file indexes
    parameter int unsigned  IN_ADDR         = 0;
    parameter int unsigned  OUT_ADDR        = 1;
    parameter int unsigned  TOT_LEN         = 2;
    parameter int unsigned  COMMANDS        = 3;
    parameter int unsigned  CACHE_BASE_ADDR = 4;
    parameter int unsigned  CAST_CTRL       = 5;

    parameter int unsigned  CMD_ACC_ONLY        = 0;
    parameter int unsigned  CMD_DIV_ONLY        = 1;
    parameter int unsigned  CMD_ACQUIRE_SLOT    = 2;
    parameter int unsigned  CMD_LAST            = 3;
    parameter int unsigned  CMD_SET_CACHE_ADDR  = 4;
    parameter int unsigned  CMD_NO_OP           = 5;
    parameter int unsigned  CMD_INT_INPUT       = 6;
    parameter int unsigned  CMD_INT_OUTPUT      = 7;

    typedef enum int unsigned   { BEFORE, AFTER, AROUND }   regs_config_t;
    typedef enum logic          { MIN, MAX }                min_max_mode_t;
    typedef enum logic          { ADD, MUL }                operation_t;

    parameter regs_config_t DEFAULT_REG_POS = AROUND;

    typedef struct packed {
        logic                       reducing;
        logic                       acc_done;
        logic                       inv_done;

        logic [WIDTH_ACC - 1 : 0]   denominator;
        logic [WIDTH_ACC - 1 : 0]   reciprocal;
    } accumulator_flags_t;

    typedef struct packed {
        logic                       acc_finished;
        logic                       acc_only;
        logic                       load_reciprocal;

        logic [WIDTH_ACC - 1 : 0]   reciprocal;
    } accumulator_ctrl_t;

    typedef struct packed {
        logic                       datapath_busy;

        logic [WIDTH_IN - 1 : 0]    max;

        accumulator_flags_t accumulator_flags;
    } datapath_flags_t;

    typedef struct packed {
        logic                       disable_max;
        logic                       dividing;
        logic                       clear_regs;
        logic                       load_max;
        logic                       load_denominator;

        logic [WIDTH_IN - 1 : 0]    max;
        logic [WIDTH_ACC - 1 : 0]   denominator;

        accumulator_ctrl_t          accumulator_ctrl;
    } datapath_ctrl_t;

    typedef struct packed {
        logic                       addend_valid;
        logic                       addend_empty;
        logic                       factor_empty;
        logic                       fma_o_valid;
        logic                       inv_appr_valid;
        logic                       last_op_in_flight;

        logic [WIDTH_ACC - 1: 0]    denominator;
        logic [WIDTH_ACC - 1: 0]    reciprocal;
    } acc_datapath_flags_t;

    typedef struct packed {
        logic                       reducing;
        logic                       inverting;
        logic                       inv_fma;
        logic                       res_valid;
        logic                       push_fma_res;
        logic                       disable_ready;
        logic                       den_enable;
        logic                       inv_enable;
        logic                       new_inv_iter;
        logic                       fma_inv_valid;
        logic                       first_inv_iter;

        logic                       load_reciprocal;

        logic [WIDTH_ACC - 1: 0]    reciprocal;
    } acc_datapath_ctrl_t;

    typedef enum logic {ALLOC, LOAD} slot_req_op_e;
    typedef enum logic {UPDATE, FREE} slot_update_op_e;

    typedef struct packed {
        logic [WIDTH_IN - 1 : 0]    maximum;
        logic [WIDTH_ACC - 1 : 0]   denominator;
        logic                       valid;
    } slot_t;

    typedef struct packed {
        slot_req_op_e                       op;
        logic [SLOT_ADDR_BITS -1 : 0]       addr;
    } slot_req_op_t;

    typedef struct packed {
        slot_update_op_e                    op;
        logic [SLOT_ADDR_BITS -1 : 0]       addr;

        logic [WIDTH_IN - 1 : 0]            maximum;
        logic [WIDTH_ACC - 1 : 0]           denominator;
    } slot_update_op_t;

    typedef struct packed {
        logic [31 : 0]                  cache_base_addr;

        logic [SLOT_ADDR_BITS - 1 : 0]  addr;

        logic                           req_valid;
        slot_req_op_t                   req_op;

        logic                           update_valid;
        slot_update_op_t                update_op;
    } slot_regfile_ctrl_t;

    typedef struct packed {
        logic signed [6 : 0]    int_bits;
        logic                   is_signed;

        logic                   enable;
    } cast_ctrl_t;

    function automatic softex_to_cvfpu(softex_pkg::regs_config_t arg);
        fpnew_pkg::pipe_config_t res;

        unique case (arg)
            softex_pkg::BEFORE :   res = fpnew_pkg::BEFORE;
            softex_pkg::AFTER  :   res = fpnew_pkg::AFTER;
            softex_pkg::AROUND :   res = fpnew_pkg::DISTRIBUTED;
        endcase

        return res;
    endfunction

    function automatic fmt_to_conf(int unsigned fpformat1, int unsigned fpformat2);
        int unsigned tmp = {{2**fpformat1} | {2**fpformat2}};

        int unsigned res = {<<{tmp [fpnew_pkg::NUM_FP_FORMATS - 1 : 0]}};

        return res;
    endfunction
endpackage