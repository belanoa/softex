// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import hwpe_stream_package::*;
import hci_package::*;
import softex_pkg::*;

module softex_ab_addressgen #(
    parameter int unsigned              N_ELEMS         = (DATA_W - 32) / WIDTH_IN  ,
    parameter int unsigned              N_BLOCKS        = BUF_AB_BLOCKS             ,
    parameter int unsigned              ELEM_WIDTH      = WIDTH_IN                  ,
    parameter int unsigned              CNT_WIDTH       = BUF_CNT_WIDTH             ,
    parameter int unsigned              ELEM_READS      = NUM_REGS_FMA_IN                      
) (
    input   logic                   clk_i           ,
    input   logic                   rst_ni          ,
    input   logic                   clear_i         ,
    input   ab_addressgen_ctrl_t    ctrl_i          ,
    input   hci_streamer_flags_t    stream_flags_i  ,
    output  hci_streamer_ctrl_t     stream_ctrl_o   
);

    enum logic [1:0]    { IDLE, FIRST_FILL, BACKWARD, FORWARD } current_state, next_state;

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

    always_comb begin : fsm
        next_state      = current_state;
        stream_ctrl_o   = '0;

        stream_ctrl_o.addressgen_ctrl.d0_stride = N_ELEMS * ELEM_WIDTH / 8;
        stream_ctrl_o.addressgen_ctrl.base_addr = ctrl_i.base_addr;

        case (current_state)
            IDLE: begin
                if (ctrl_i.addressgen_start) begin
                    next_state  = FIRST_FILL;

                    stream_ctrl_o.addressgen_ctrl.tot_len   = ctrl_i.ab_buf_ctrl.num_blocks + 1;
                    
                    stream_ctrl_o.req_start = '1;
                end
            end

            FIRST_FILL: begin
                stream_ctrl_o.addressgen_ctrl.tot_len   = ctrl_i.ab_buf_ctrl.num_blocks + 1;

                if (stream_flags_i.done) begin
                    if (ctrl_i.ab_buf_ctrl.num_blocks == N_BLOCKS - 1) begin
                        next_state  = IDLE;
                    end else begin
                        next_state  = BACKWARD;
                    end
                end
            end

            BACKWARD: begin
                stream_ctrl_o.req_start                 = stream_flags_i.ready_start;
                stream_ctrl_o.addressgen_ctrl.tot_len   = ctrl_i.ab_buf_ctrl.num_blocks + 1 - N_BLOCKS;
                stream_ctrl_o.addressgen_ctrl.base_addr = ctrl_i.base_addr + (ctrl_i.ab_buf_ctrl.num_blocks - N_BLOCKS) * N_ELEMS * ELEM_WIDTH / 8;
                stream_ctrl_o.addressgen_ctrl.d0_stride = -(N_ELEMS * ELEM_WIDTH / 8);

                if (stream_flags_i.done) begin
                    if (ctrl_i.x_done) begin
                        next_state  = IDLE;
                    end else begin
                        next_state  = FORWARD;
                    end
                end
            end

            FORWARD: begin
                stream_ctrl_o.req_start                 = stream_flags_i.ready_start;
                stream_ctrl_o.addressgen_ctrl.tot_len   = ctrl_i.ab_buf_ctrl.num_blocks + 1 - N_BLOCKS;
                stream_ctrl_o.addressgen_ctrl.base_addr = ctrl_i.base_addr + (N_ELEMS * ELEM_WIDTH / 8) * N_BLOCKS;

                if (stream_flags_i.done) begin
                    if (ctrl_i.x_done) begin
                        next_state  = IDLE;
                    end else begin
                        next_state  = BACKWARD;
                    end
                end
            end
        endcase
    end

endmodule