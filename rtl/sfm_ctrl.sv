// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import hci_package::*;
import hwpe_stream_package::*;
import sfm_pkg::*;

module sfm_ctrl #(
    parameter int unsigned              N_CORES         = 1                     ,
    parameter int unsigned              N_CONTEXT       = 2                     ,
    parameter int unsigned              IO_REGS         = 4                     ,
    parameter int unsigned              ID_WIDTH        = 8                     ,
    parameter int unsigned              N_STATE_SLOTS   = 2                     ,
    parameter int unsigned              DATA_WIDTH      = 128                   ,
    parameter fpnew_pkg::fp_format_e    IN_FPFORMAT     = fpnew_pkg::FP16ALT    ,
    parameter fpnew_pkg::fp_format_e    ACC_FPFORMAT    = fpnew_pkg::FP32       
) (
    input   logic                           clk_i               ,
    input   logic                           rst_ni              ,
    input   logic                           enable_i            ,
    input   hci_streamer_flags_t            in_stream_flags_i   ,
    input   hci_streamer_flags_t            out_stream_flags_i  ,
    input   sfm_pkg::datapath_flags_t       datapath_flgs_i     ,
    output  logic                           clear_o             ,
    output  logic                           busy_o              ,
    output  logic [N_CORES - 1 : 0] [1 : 0] evt_o               ,
    output  hci_streamer_ctrl_t             in_stream_ctrl_o    ,
    output  hci_streamer_ctrl_t             out_stream_ctrl_o   ,
    output  sfm_pkg::datapath_ctrl_t        datapath_ctrl_o     ,

    hwpe_ctrl_intf_periph.slave             periph
);

    localparam int unsigned IN_WIDTH    = fpnew_pkg::fp_width(IN_FPFORMAT);
    localparam int unsigned ACC_WIDTH   = fpnew_pkg::fp_width(ACC_FPFORMAT);

    typedef enum logic [2:0] {
        IDLE,
        ACCUMULATION,
        WAIT_DATAPATH_EMPTY,
        WAIT_ACCUMULATION,
        WAIT_INVERSION,
        DIVIDING,
        FINISHED
    } sfm_state_t;

    typedef struct packed {
        logic                       valid;
        logic [IN_WIDTH - 1 : 0]    max;
        logic [ACC_WIDTH - 1 : 0]   denominator;
    } state_slot_t;

    sfm_state_t current_state,
                next_state;

    logic   in_start,
            out_start;

    logic   dp_acc_finished,
            dp_dividing,
            dp_disable_max,
            dp_load_max,
            dp_load_denominator,
            dp_load_reciprocal;

    logic   clear,
            clear_regs;

    logic   slave_done;

    logic   acc_only,
            div_only,
            last;

    state_slot_t [N_STATE_SLOTS - 1 : 0]    state_slot_q;
    state_slot_t                            state_slot_d;

    logic   state_slot_en,
            state_slot_clear;

    logic [$clog2(N_STATE_SLOTS) - 1 : 0]   current_slot,
                                            free_slot_ptr;

    logic [N_STATE_SLOTS - 1 : 0]   slot_locked;

    logic   slot_free,
            slot_select,
            slot_req;

    logic [$clog2(DATA_WIDTH / 8) - 1 : 0]  length_lftovr;

    logic   lftovr_inc;

    hwpe_ctrl_package::ctrl_regfile_t   reg_file;
    hwpe_ctrl_package::ctrl_slave_t     ctrl_slave;
    hwpe_ctrl_package::flags_slave_t    flgs_slave;

    assign state_slot_d.valid       = '1;
    assign state_slot_d.max         = datapath_flgs_i.max;

    //As we never need both the denominator and its reciprocal, state_slot.denominator is used for both
    assign state_slot_d.denominator = (acc_only & ~last) ? datapath_flgs_i.accumulator_flags.denominator : datapath_flgs_i.accumulator_flags.reciprocal;

    for (genvar i = 0; i < N_STATE_SLOTS; i++) begin
        always_ff @(posedge clk_i or negedge rst_ni) begin : state_slot
            if (~rst_ni) begin
                state_slot_q [i] <= '0;
            end else begin
                if (clear | (state_slot_clear && (i == current_slot))) begin
                    state_slot_q [i] <= '0;
                end else if (state_slot_en && (i == current_slot)) begin
                    state_slot_q [i] <= state_slot_d;
                end else begin
                    state_slot_q [i] <= state_slot_q [i];
                end
            end
        end
    end

    assign datapath_ctrl_o.max                          = state_slot_q[current_slot].max;
    assign datapath_ctrl_o.denominator                  = state_slot_q[current_slot].denominator;
    assign datapath_ctrl_o.accumulator_ctrl.reciprocal  = state_slot_q[current_slot].denominator;

    for (genvar i = 0; i < N_STATE_SLOTS; i++) begin
        always_ff @(posedge clk_i or negedge rst_ni) begin : slot_locked_register
            if (~rst_ni) begin
                slot_locked [i] <= '0;
            end else begin
                if (clear | (state_slot_clear && (i == current_slot))) begin
                    slot_locked [i] <= '0;
                end else if ((i == free_slot_ptr) & slot_select) begin
                    slot_locked [i] <= '1;
                end else begin
                    slot_locked [i] <= slot_locked [i];
                end
            end
        end
    end

    assign slot_free    = ~&slot_locked;

    always_comb begin : free_slot_ptr_assignment
        free_slot_ptr   = '0;

        for (int i = 0; i < N_STATE_SLOTS; i++) begin
            if (~slot_locked[i]) begin
                free_slot_ptr = i;
                break;
            end
        end
    end

    assign slot_select = flgs_slave.ext_re & periph.req;

    hwpe_ctrl_slave  #(
        .N_CORES        (   N_CORES         ),
        .N_CONTEXT      (   N_CONTEXT       ),
        .N_IO_REGS      (   IO_REGS         ),
        .N_GENERIC_REGS (   0               ),
        .ID_WIDTH       (   ID_WIDTH        )
    ) i_slave (
        .clk_i      (   clk_i       ),
        .rst_ni     (   rst_ni      ),
        .clear_o    (   clear       ),
        .cfg        (   periph      ),
        .ctrl_i     (   ctrl_slave  ),
        .flags_o    (   flgs_slave  ),
        .reg_file   (   reg_file    )
    );
    

    always_ff @(posedge clk_i or negedge rst_ni) begin : state_register
        if (~rst_ni) begin
            current_state <= IDLE;
        end else begin
            if (clear) begin
                current_state <= IDLE;
            end else begin
                current_state <= next_state;
            end
        end
    end

    assign length_lftovr    = reg_file.hwpe_params [TOT_LEN] [$clog2(DATA_WIDTH / 8) - 1 : 0];

    // If the total length of the vector is not multiple of the data width we need to increse the number of loads / stores by one
    assign lftovr_inc       = length_lftovr != '0;

    assign in_stream_ctrl_o.req_start                       = in_start;
    assign in_stream_ctrl_o.addressgen_ctrl.base_addr       = reg_file.hwpe_params [IN_ADDR];
    assign in_stream_ctrl_o.addressgen_ctrl.tot_len         = reg_file.hwpe_params [TOT_LEN] / (DATA_WIDTH / 8) + lftovr_inc;
    assign in_stream_ctrl_o.addressgen_ctrl.d0_len          = reg_file.hwpe_params [TOT_LEN];   //Not used by the address generator per se but still necessary
    assign in_stream_ctrl_o.addressgen_ctrl.d0_stride       = DATA_WIDTH / 8;
    assign in_stream_ctrl_o.addressgen_ctrl.d1_len          = '0;
    assign in_stream_ctrl_o.addressgen_ctrl.d1_stride       = '0;
    assign in_stream_ctrl_o.addressgen_ctrl.d2_stride       = '0;
    assign in_stream_ctrl_o.addressgen_ctrl.dim_enable_1h   = '0;

    assign out_stream_ctrl_o.req_start                      = out_start;
    assign out_stream_ctrl_o.addressgen_ctrl.base_addr      = reg_file.hwpe_params [OUT_ADDR];
    assign out_stream_ctrl_o.addressgen_ctrl.tot_len        = reg_file.hwpe_params [TOT_LEN] / (DATA_WIDTH / 8) + lftovr_inc;
    assign out_stream_ctrl_o.addressgen_ctrl.d0_len         = reg_file.hwpe_params [TOT_LEN];
    assign out_stream_ctrl_o.addressgen_ctrl.d0_stride      = DATA_WIDTH / 8;
    assign out_stream_ctrl_o.addressgen_ctrl.d1_len         = '0;
    assign out_stream_ctrl_o.addressgen_ctrl.d1_stride      = '0;
    assign out_stream_ctrl_o.addressgen_ctrl.d2_stride      = '0;
    assign out_stream_ctrl_o.addressgen_ctrl.dim_enable_1h  = '0;

    assign datapath_ctrl_o.accumulator_ctrl.acc_finished    = dp_acc_finished;
    assign datapath_ctrl_o.accumulator_ctrl.acc_only        = acc_only & ~last;
    assign datapath_ctrl_o.dividing                         = dp_dividing;
    assign datapath_ctrl_o.disable_max                      = dp_disable_max;
    assign datapath_ctrl_o.clear_regs                       = clear_regs;
    assign datapath_ctrl_o.load_max                         = dp_load_max;
    assign datapath_ctrl_o.load_denominator                 = dp_load_denominator;
    assign datapath_ctrl_o.accumulator_ctrl.load_reciprocal = dp_load_reciprocal;

    assign acc_only                                         = reg_file.hwpe_params [COMMANDS] [CMD_ACC_ONLY];   //We stop as soon as the denominator is valid, no inversion is performed
    assign div_only                                         = reg_file.hwpe_params [COMMANDS] [CMD_DIV_ONLY];   //Only perform the normalisation step. The maximum and the denominator are recovered from the state slot
    assign last                                             = reg_file.hwpe_params [COMMANDS] [CMD_LAST];       //We are performing the last partial accumulation / normalisation
    
    assign current_slot                                     = reg_file.hwpe_params [COMMANDS] [31 -: 16];

    assign ctrl_slave.done                                  = slave_done;
    assign ctrl_slave.evt                                   = '0;

    //The extension is used to acquire a state slot
    assign ctrl_slave.ext_flags                             = {slot_free, {(32 - $clog2(N_STATE_SLOTS) - 1){1'b0}}, free_slot_ptr};

    always_comb begin : ctrl_sfm
        next_state          = current_state;
        out_start           = '0;
        in_start            = '0;
        dp_acc_finished     = '0;
        dp_disable_max      = '0;
        dp_dividing         = '0;
        slave_done          = '0;
        busy_o              = '1;
        clear_regs          = '0;
        state_slot_en       = '0;
        state_slot_clear    = '0;
        dp_load_max         = '0;
        dp_load_denominator = '0;
        dp_load_reciprocal  = '0;
        
        case (current_state)
            IDLE: begin
                busy_o = '0;

                if (flgs_slave.start) begin
                    casex ({div_only, acc_only})
                        2'b00:  next_state  = ACCUMULATION;
                        2'b01:  next_state  = ACCUMULATION;
                        2'b1?:  next_state  = DIVIDING;
                    endcase

                    if (state_slot_q[current_slot].valid) begin
                        dp_load_max = '1;

                        if (acc_only) begin
                            dp_load_denominator = '1;
                        end else begin
                            dp_load_reciprocal  = '1;
                        end
                    end
                    
                    if (~div_only) begin
                        in_start    = '1;
                    end else begin
                        out_start   = '1;
                        in_start    = '1;
                    end
                end
            end

            ACCUMULATION: begin
                if (in_stream_flags_i.done) begin
                    next_state = WAIT_DATAPATH_EMPTY;
                end
            end

            WAIT_DATAPATH_EMPTY: begin
                if (~datapath_flgs_i.datapath_busy) begin
                    next_state      = WAIT_ACCUMULATION;
                    dp_acc_finished = '1;
                end
            end

            WAIT_ACCUMULATION: begin
                dp_acc_finished = '1;
                dp_disable_max  = '1;

                if (datapath_flgs_i.accumulator_flags.acc_done) begin
                    if (acc_only & ~last) begin
                        next_state          = FINISHED;
                    end else begin
                        if (~acc_only) begin
                            dp_acc_finished = '0;
                            out_start       = '1;
                            in_start        = '1;
                        end

                        next_state      = WAIT_INVERSION;
                    end
                end
            end

            WAIT_INVERSION: begin
                dp_dividing     = '1;
                dp_disable_max  = '1;

                if (datapath_flgs_i.accumulator_flags.inv_done) begin
                    if (acc_only) begin
                        next_state = FINISHED;
                    end else begin
                        next_state = DIVIDING;
                    end
                end
            end

            DIVIDING: begin
                dp_dividing     = '1;
                dp_disable_max  = '1;

                if (out_stream_flags_i.done) begin
                    next_state  = FINISHED;
                end
            end

            FINISHED: begin
                dp_dividing     = '0;
                slave_done = '1;
                busy_o          = '0;
                clear_regs      = '1;

                if (acc_only) begin
                    state_slot_en = '1;
                end

                if (div_only & last) begin
                    state_slot_clear = '1;
                end

                next_state      = IDLE;
            end
        endcase
    end

    assign clear_o  = clear;

    assign  evt_o   = flgs_slave.evt;

endmodule