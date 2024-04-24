// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import sfm_pkg::*;

module sfm_acc_ctrl #(
    parameter int unsigned  N_INV_ITERS = N_NEWTON_ITERS            ,
    parameter logic         COMB_INV    = NUM_REGS_INV_APPR == 0    
) (
    input   logic                           clk_i               ,
    input   logic                           rst_ni              ,
    input   logic                           clear_i             ,
    input   sfm_pkg::accumulator_ctrl_t     ctrl_i              ,
    output  sfm_pkg::accumulator_flags_t    flags_o             ,
    output  sfm_pkg::acc_datapath_ctrl_t    ctrl_datapath_o     ,
    input   sfm_pkg::acc_datapath_flags_t   flags_datapath_i    
);

    typedef enum logic [3:0] {
        IDLE,
        COMPUTING,
        FINISHING,
        REDUCTION,
        INVERSION,
        INV_MUL,
        INV_FMA,
        FINISHED
    } acc_state_t;

    acc_state_t current_state,
                next_state;

    logic [$clog2(N_INV_ITERS) + 1 : 0] iteration_cnt;
    logic iteration_cnt_enable;

    logic   disable_ready,
            push_fma_res,
            red_out_cnt,
            red_out_cnt_enable,
            inv_enable,
            reducing,
            inverting,
            inv_fma,
            res_valid,
            fma_inv_valid,
            first_inv_iter,
            accumulation_done,
            inversion_done;

    logic   den_enable;


    always_ff @(posedge clk_i or negedge rst_ni) begin : state_register
        if (~rst_ni) begin
            current_state <= IDLE;
        end else begin
            if (clear_i) begin
                current_state <= IDLE;
            end else begin
                current_state <= next_state;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : red_out_counter
        if (~rst_ni) begin
            red_out_cnt <= '0;
        end else begin
            if (clear_i) begin
                red_out_cnt <= '0;
            end else if (red_out_cnt_enable & flags_datapath_i.fma_o_valid) begin
                red_out_cnt <= ~red_out_cnt;
            end else begin
                red_out_cnt <= red_out_cnt;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : iteration_counter
        if (~rst_ni) begin
            iteration_cnt <= '0;
        end else begin
            if (clear_i) begin
                iteration_cnt <= '0;
            end else if (iteration_cnt_enable) begin
                iteration_cnt <= iteration_cnt + 1;
            end else begin
                iteration_cnt <= iteration_cnt;
            end
        end
    end

    assign flags_o.reducing     = reducing;
    assign flags_o.acc_done     = accumulation_done;
    assign flags_o.inv_done     = inversion_done;

    assign flags_o.denominator  = flags_datapath_i.denominator;
    assign flags_o.reciprocal   = flags_datapath_i.reciprocal;

    assign ctrl_datapath_o.reducing         = reducing;
    assign ctrl_datapath_o.inverting        = inverting;
    assign ctrl_datapath_o.inv_fma          = inv_fma;
    assign ctrl_datapath_o.res_valid        = res_valid;
    assign ctrl_datapath_o.push_fma_res     = push_fma_res;
    assign ctrl_datapath_o.disable_ready    = disable_ready;
    assign ctrl_datapath_o.den_enable       = den_enable;
    assign ctrl_datapath_o.inv_enable       = inv_enable;
    assign ctrl_datapath_o.new_inv_iter     = iteration_cnt_enable;
    assign ctrl_datapath_o.fma_inv_valid    = fma_inv_valid;
    assign ctrl_datapath_o.first_inv_iter   = first_inv_iter;

    assign ctrl_datapath_o.load_reciprocal  = ctrl_i.load_reciprocal;
    assign ctrl_datapath_o.reciprocal       = ctrl_i.reciprocal;

    always_comb begin : sfm_accumulator_fsm
        next_state              = current_state;
        res_valid               = '0;
        disable_ready           = '0;
        push_fma_res            = '0;
        red_out_cnt_enable      = '0;
        iteration_cnt_enable    = '0;
        den_enable              = '0;
        inv_enable              = '0;
        reducing                = '0;
        inverting               = '0;
        fma_inv_valid           = '0;
        inv_fma                 = '0;
        first_inv_iter          = '0;
        accumulation_done       = '0;
        inversion_done          = '0;

        unique case (current_state)
            IDLE: begin
                if (flags_datapath_i.addend_valid) begin
                    next_state = COMPUTING;
                end else if (ctrl_i.load_reciprocal) begin
                    next_state = FINISHED;
                end
            end

            COMPUTING: begin
                if (ctrl_i.acc_finished) begin
                    next_state = FINISHING;
                end
            end

            // We wait for the datapath to be empty
            FINISHING: begin
                if (flags_datapath_i.addend_empty & &flags_datapath_i.factor_empty & ~flags_datapath_i.addend_valid) begin
                    next_state          = REDUCTION;
                    push_fma_res        = '1;
                    red_out_cnt_enable  = '1;
                    reducing            = '1;
                end
            end

            // As the FMA has a non-unitary latency, the FMA_REGS partial accumulations in flight need to be 
            // compresed into one
            REDUCTION: begin
                disable_ready       = '1;
                red_out_cnt_enable  = '1;
                push_fma_res        = ~red_out_cnt; // Every other valid FMA output we push a new sum
                reducing            = '1;

                // Once only 1 operation is in flight we can proceed
                if (flags_datapath_i.last_op_in_flight & flags_datapath_i.fma_o_valid) begin
                    accumulation_done   = '1;
                    den_enable          = '1;

                    if (ctrl_i.acc_only) begin
                        next_state = IDLE;
                    end else begin
                        inverting       = '1;
                        push_fma_res    = '0;
                        inv_enable      = '1;


                        //FIXME
                        if (COMB_INV) begin
                            next_state      = INV_FMA;
                            fma_inv_valid   = '1;
                            inv_fma         = '1;
                            first_inv_iter  = '1;
                        end else begin
                            next_state = INVERSION;
                        end
                    end
                end
            end

            // We are waiting for the first approximation of the reciprocal of the denominator to be computed
            INVERSION: begin
                inverting = '1;

                if (flags_datapath_i.inv_appr_valid) begin
                    next_state = INV_FMA;
                    fma_inv_valid = '1;
                    inv_fma = '1;
                end
            end

            // First half of the Newton-Raphson iteration (2 - a * x_n)
            INV_FMA: begin
                inverting = '1;
                

                if (flags_datapath_i.fma_o_valid) begin
                    next_state = INV_MUL;
                    fma_inv_valid = '1;
                end
            end
            
            // Second half of the Newton-Raphson iteration (x_n * (2 - a * x_n))
            INV_MUL: begin
                inverting = '1;
                
                if (flags_datapath_i.fma_o_valid) begin
                    iteration_cnt_enable = '1;

                    if (iteration_cnt == (N_INV_ITERS - 1)) begin
                        next_state = FINISHED;
                    end else begin
                        next_state = INV_FMA;
                        inv_fma = '1;
                        fma_inv_valid = '1;
                    end
                end
            end

            FINISHED: begin
                res_valid       = '1;
                disable_ready   = '0;
                inversion_done  = '1;

                if (flags_datapath_i.addend_valid) begin
                    next_state = COMPUTING;
                end
            end
        endcase
    end

endmodule