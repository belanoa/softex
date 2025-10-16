// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

module softex_ctrl
    import hci_package::*;
    import hwpe_stream_package::*;
    import softex_pkg::*;
#(
    parameter int unsigned              N_CORES             = 1                     ,
    parameter int unsigned              N_CONTEXT           = N_CTRL_CNTX           ,
    parameter int unsigned              IO_REGS             = N_CTRL_REGS           ,
    parameter int unsigned              ID_WIDTH            = 8                     ,
    parameter int unsigned              N_STATE_SLOTS       = N_CTRL_STATE_SLOTS    ,
    parameter int unsigned              DATA_WIDTH          = DATA_W - 32           ,
    parameter int unsigned              INT_WIDTH           = INT_W                 ,
    parameter int unsigned              WEIGHT_LEN_WIDTH    = BUF_CNT_WIDTH         ,
    parameter fpnew_pkg::fp_format_e    IN_FPFORMAT         = FPFORMAT_IN           ,
    parameter fpnew_pkg::fp_format_e    ACC_FPFORMAT        = FPFORMAT_ACC
) (
    input   logic                           clk_i               ,
    input   logic                           rst_ni              ,
    input   logic                           enable_i            ,
    input   hci_streamer_flags_t            in_stream_flags_i   ,
    input   hci_streamer_flags_t            out_stream_flags_i  ,
    input   datapath_flags_t                datapath_flgs_i     ,
    input   slot_t                          state_slot_i        ,
    output  logic                           clear_o             ,
    output  logic                           busy_o              ,
    output  logic [N_CORES - 1 : 0] [1 : 0] evt_o               ,
    output  hci_streamer_ctrl_t             in_stream_ctrl_o    ,
    output  hci_streamer_ctrl_t             out_stream_ctrl_o   ,
    output  x_buffer_ctrl_t                 x_buffer_ctrl_o     ,
    output  ab_buffer_ctrl_t                a_buffer_ctrl_o     ,
    output  ab_buffer_ctrl_t                b_buffer_ctrl_o     ,
    output  ab_addressgen_ctrl_t            a_addressgen_ctrl_o ,
    output  ab_addressgen_ctrl_t            b_addressgen_ctrl_o ,
    output  datapath_ctrl_t                 datapath_ctrl_o     ,
    output  slot_regfile_ctrl_t             slot_ctrl_o         ,
    output  cast_ctrl_t                     in_cast_ctrl_o      ,
    output  cast_ctrl_t                     out_cast_ctrl_o     ,
    input   softex_config_t                 config_i            ,
    input   logic                           config_valid_i
);

    localparam int unsigned IN_WIDTH    = fpnew_pkg::fp_width(IN_FPFORMAT);
    localparam int unsigned ACC_WIDTH   = fpnew_pkg::fp_width(ACC_FPFORMAT);

    // The number of bits read when the input is integer
    localparam int unsigned DATA_WIDTH_INT  = INT_WIDTH * DATA_WIDTH / IN_WIDTH > DATA_WIDTH ? DATA_WIDTH : INT_WIDTH * DATA_WIDTH / IN_WIDTH;

    typedef enum logic [3:0] {
        IDLE,
        WAIT_SLOT_VALID,
        ACCUMULATION,
        WAIT_DATAPATH_EMPTY,
        WAIT_ACCUMULATION,
        WAIT_INVERSION,
        DIVIDING,
        EXP_SUM,
        FINISHED
    } softex_state_t;

    typedef struct packed {
        logic                       valid;
        logic [IN_WIDTH - 1 : 0]    max;
        logic [ACC_WIDTH - 1 : 0]   denominator;
    } state_slot_t;

    softex_state_t current_state,
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
            last,
            set_cache_addr,
            acquire_slot,
            no_operation,
            cast_input,
            cast_output,
            gelu_mode;

    logic [WEIGHT_LEN_WIDTH-1:0]    weight_len;

    logic [31 : 0]  slot_cache_base_addr;
    logic   cache_base_addr_en;

    logic   state_slot_en,
            state_slot_clear;

    logic [16 : 0]   current_slot;

    logic [$clog2(DATA_WIDTH / 8) - 1 : 0]  length_lftovr,
                                            int_length_lftovr;

    logic   lftovr_inc,
            int_lftovr_inc;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            slot_cache_base_addr <= '0;
        end else begin
            if (clear) begin
                slot_cache_base_addr <= '0;
            end else if (cache_base_addr_en) begin
                slot_cache_base_addr <= config_i.cache_base_addr;
            end
        end
    end


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

    assign length_lftovr        = config_i.tot_len [$clog2(DATA_WIDTH / 8) - 1 : 0];

    // If the total length of the vector is not a multiple of the data width we need to increse the number of loads / stores by one
    assign lftovr_inc           = length_lftovr != '0;

    // Same as before but with integer inputs
    assign int_length_lftovr    = config_i.tot_len [$clog2(DATA_WIDTH_INT / 8) - 1 : 0];

    assign int_lftovr_inc       = int_length_lftovr != '0;

    assign in_stream_ctrl_o.req_start                       = in_start;
    assign in_stream_ctrl_o.addressgen_ctrl.base_addr       = config_i.in_addr;
    assign in_stream_ctrl_o.addressgen_ctrl.tot_len         = cast_input ? config_i.tot_len / (DATA_WIDTH_INT / 8) + int_length_lftovr : config_i.tot_len / (DATA_WIDTH / 8) + lftovr_inc;
    assign in_stream_ctrl_o.addressgen_ctrl.d0_len          = config_i.tot_len;   // Used by the strobe generator
    assign in_stream_ctrl_o.addressgen_ctrl.d0_stride       = cast_input ? DATA_WIDTH_INT / 8 : DATA_WIDTH / 8;
    assign in_stream_ctrl_o.addressgen_ctrl.d1_len          = '0;
    assign in_stream_ctrl_o.addressgen_ctrl.d1_stride       = '0;
    assign in_stream_ctrl_o.addressgen_ctrl.d2_stride       = '0;
    assign in_stream_ctrl_o.addressgen_ctrl.dim_enable_1h   = '0;

    assign out_stream_ctrl_o.req_start                      = out_start;
    assign out_stream_ctrl_o.addressgen_ctrl.base_addr      = config_i.out_addr;
    assign out_stream_ctrl_o.addressgen_ctrl.tot_len        = cast_output ? config_i.tot_len / (DATA_WIDTH_INT / 8) + int_length_lftovr : config_i.tot_len / (DATA_WIDTH / 8) + lftovr_inc;
    assign out_stream_ctrl_o.addressgen_ctrl.d0_len         = config_i.tot_len;   // Used by the strobe generator
    assign out_stream_ctrl_o.addressgen_ctrl.d0_stride      = cast_output ? DATA_WIDTH_INT / 8 : DATA_WIDTH / 8;
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


    assign datapath_ctrl_o.softmax_mode                     = ~gelu_mode;

    assign x_buffer_ctrl_o.loop                             = gelu_mode;
    assign x_buffer_ctrl_o.num_loops                        = weight_len;

    assign a_buffer_ctrl_o.num_blocks                       = (weight_len - 1) >> $clog2(BUF_AB_ELEMENTS);
    assign a_buffer_ctrl_o.leftover                         = (weight_len - 1);

    assign b_buffer_ctrl_o.num_blocks                       = (weight_len - 1) >> $clog2(BUF_AB_ELEMENTS);
    assign b_buffer_ctrl_o.leftover                         = (weight_len - 1);

    assign a_addressgen_ctrl_o.addressgen_start             = in_start & gelu_mode;
    assign a_addressgen_ctrl_o.x_done                       = in_stream_flags_i.ready_start;
    assign a_addressgen_ctrl_o.base_addr                    = config_i.a_addr;
    assign a_addressgen_ctrl_o.ab_buf_ctrl                  = a_buffer_ctrl_o;

    assign b_addressgen_ctrl_o.addressgen_start             = in_start & gelu_mode;
    assign b_addressgen_ctrl_o.x_done                       = in_stream_flags_i.ready_start;
    assign b_addressgen_ctrl_o.base_addr                    = config_i.b_addr;
    assign b_addressgen_ctrl_o.ab_buf_ctrl                  = b_buffer_ctrl_o;

    assign datapath_ctrl_o.max                              = state_slot_i.maximum;
    assign datapath_ctrl_o.denominator                      = state_slot_i.denominator;
    assign datapath_ctrl_o.accumulator_ctrl.reciprocal      = state_slot_i.denominator;

    assign acc_only                                         = config_i.acc_only;       // We stop as soon as the denominator is valid, no inversion is performed
    assign div_only                                         = config_i.div_only;       // Only perform the normalisation step. The maximum and the denominator are recovered from the state slot
    assign last                                             = config_i.last;           // We are performing the last partial accumulation / normalisation
    assign set_cache_addr                                   = config_i.set_cache_addr; // Sets the base address of the state slot cache
    assign acquire_slot                                     = config_i.acquire_slot;   // This is the first partial iteration of a new operation
    assign no_operation                                     = config_i.no_op;          // No operation has to be performed; currently used to update the cache address without necessarily starting an operation
    assign cast_input                                       = '0;                      // Cast the input from fixed point to floating point
    assign cast_output                                      = '0;                      // Cast the output from floating point to fixed point
    assign gelu_mode                                        = config_i.gelu_mode;      // We are using SoftEx to perform the GELU activation

    assign current_slot                                     = config_i.slot;
    assign weight_len                                       = config_i.weight_len;
    assign in_cast_ctrl_o.int_bits                          = '0;
    assign in_cast_ctrl_o.is_signed                         = '0;
    assign in_cast_ctrl_o.enable                            = '0;

    assign out_cast_ctrl_o.int_bits                         = '0;
    assign out_cast_ctrl_o.is_signed                        = '0;
    assign out_cast_ctrl_o.enable                           = '0;

    assign slot_ctrl_o.cache_base_addr                      = slot_cache_base_addr;
    assign slot_ctrl_o.addr                                 = current_slot;

    assign slot_ctrl_o.req_valid                            = config_valid_i;
    assign slot_ctrl_o.req_op.addr                          = config_i.slot;
    assign slot_ctrl_o.req_op.op                            = config_i.acquire_slot ? ALLOC : LOAD;


    assign slot_ctrl_o.update_valid                         = state_slot_en;
    assign slot_ctrl_o.update_op.addr                       = current_slot;
    assign slot_ctrl_o.update_op.op                         = last & div_only ? FREE : UPDATE;
    assign slot_ctrl_o.update_op.maximum                    = datapath_flgs_i.max;
    assign slot_ctrl_o.update_op.denominator                = (acc_only & ~last) ? datapath_flgs_i.accumulator_flags.denominator : datapath_flgs_i.accumulator_flags.reciprocal;

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
        cache_base_addr_en  = '0;

        case (current_state)
            IDLE: begin
                busy_o = '0;

                if (config_valid_i) begin
                    if (set_cache_addr) begin
                        cache_base_addr_en = '1;
                    end

                    if (gelu_mode) begin
                        next_state  = EXP_SUM;

                        in_start    = '1;
                        out_start   = '1;
                    end else if (~no_operation) begin
                        if (~state_slot_i.valid & (acc_only | div_only)) begin
                            next_state = WAIT_SLOT_VALID;
                        end else begin
                            casex ({div_only, acc_only})
                                2'b00:  next_state  = ACCUMULATION;
                                2'b01:  next_state  = ACCUMULATION;
                                2'b1?:  next_state  = DIVIDING;
                            endcase

                            if ((acc_only | div_only) & ~acquire_slot) begin
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
                    end else begin
                        slave_done = '1;
                    end
                end
            end

            WAIT_SLOT_VALID: begin
                if (state_slot_i.valid) begin
                    if (~acquire_slot) begin
                        dp_load_max = '1;
                    end

                    if (acc_only) begin
                        next_state          = ACCUMULATION;
                        in_start            = '1;

                        if (~acquire_slot) begin
                            dp_load_denominator = '1;
                        end
                    end else begin
                        next_state          = DIVIDING;
                        out_start           = '1;
                        in_start            = '1;

                        if (~acquire_slot) begin
                            dp_load_reciprocal  = '1;
                        end
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

            EXP_SUM: begin
                if (out_stream_flags_i.done) begin
                    next_state  = FINISHED;
                end
            end

            FINISHED: begin
                dp_dividing = '0;
                slave_done  = '1;
                busy_o      = '0;
                clear_regs  = '1;

                // The slot only needs to be updated if we are accumulating or if this is the last normalisation iteration
                if (acc_only | (div_only & last)) begin
                    state_slot_en = '1;
                end

                next_state      = IDLE;
            end
        endcase
    end

    assign clear_o  = '0;

    assign  evt_o   = slave_done; // FIXME

endmodule