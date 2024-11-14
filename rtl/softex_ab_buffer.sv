// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import hwpe_stream_package::*;
import softex_pkg::*;

module softex_ab_buffer #(
    parameter int unsigned              N_ELEMS         = (DATA_W - 32) / WIDTH_IN  ,
    parameter int unsigned              N_BLOCKS        = BUF_AB_BLOCKS             ,
    parameter int unsigned              ELEM_WIDTH      = WIDTH_IN                  ,
    parameter int unsigned              STRB_WIDTH      = WIDTH_IN / 8              ,
    parameter int unsigned              CNT_WIDTH       = BUF_CNT_WIDTH             ,
    parameter int unsigned              ELEM_READS      = NUM_REGS_ROW_ACC          ,
    parameter logic                     LATCH_BUFFER    = USE_LATCH_BUF              
) (
    input   logic                   clk_i       ,
    input   logic                   rst_ni      ,
    input   logic                   clear_i     ,
    input   ab_buffer_ctrl_t        ctrl_i      ,
    output  ab_buffer_flags_t       flags_o     ,

    hwpe_stream_intf_stream.sink    buffer_i    ,
    hwpe_stream_intf_stream.source  buffer_o   
);

    localparam int unsigned B_ADDR_LEN  = (N_BLOCKS == 1) ? 1 : $clog2(N_BLOCKS);
    localparam int unsigned E_ADDR_LEN  = (N_ELEMS == 1) ? 1 : $clog2(N_ELEMS); 

    logic [B_ADDR_LEN-1:0]  read_pointer_d, read_pointer_q,
                            write_pointer_d, write_pointer_q,
                            buf_start_pointer_q;

    logic [E_ADDR_LEN-1:0]  e_read_pointer_d, e_read_pointer_q;

    logic [CNT_WIDTH-1:0]   block_read_cnt;
    logic                   block_read_cnt_en, block_read_cnt_clr;

    logic [$clog2(ELEM_READS)-1:0]  elem_read_cnt;
    logic                           elem_read_cnt_en;

    logic                   dir_toggle;

    logic                   last_blk, write_done;

    logic                   last_weight;

    logic [CNT_WIDTH-$clog2(N_BLOCKS)-1:0]  buffer_read_cnt, num_buffer_reads;
    logic [$clog2(N_BLOCKS)-1:0]            block_leftover;

    logic [N_BLOCKS-1:0] [N_ELEMS-1:0] [ELEM_WIDTH-1:0] buf_registers;

    logic [N_ELEMS-1:0] [ELEM_WIDTH-1:0]    block_data_out;
    logic [N_ELEMS-1:0] [STRB_WIDTH-1:0]    block_strb_out;

    enum logic [1:0] { EMPTY, MIDDLE, FULL, BOUNCE }    current_state, next_state;
    enum logic       { FORWARD, BACKWARD }              direction;

    always_ff @(posedge clk_i or negedge rst_ni) begin : read_pointer_register
        if (~rst_ni) begin
            read_pointer_q <= '0;
        end else begin
            if (clear_i) begin
                read_pointer_q <= '0;
            end else begin
                read_pointer_q <= read_pointer_d;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : element_read_pointer_register
        if (~rst_ni) begin
            e_read_pointer_q <= '0;
        end else begin
            if (clear_i) begin
                e_read_pointer_q <= '0;
            end else begin
                e_read_pointer_q <= e_read_pointer_d;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : write_pointer_register
        if (~rst_ni) begin
            write_pointer_q <= '0;
        end else begin
            if (clear_i) begin
                write_pointer_q <= '0;
            end else begin
                write_pointer_q <= write_pointer_d;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : direction_register
        if (~rst_ni) begin
            direction <= FORWARD;
        end else begin
            if (clear_i) begin
                direction <= FORWARD;
            end else if (dir_toggle) begin
                direction <= ~direction;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : block_read_counter
        if (~rst_ni) begin
            block_read_cnt <= '0;
        end else begin
            if (clear_i || block_read_cnt_clr) begin
                block_read_cnt <= '0;
            end else if (block_read_cnt_en) begin
                block_read_cnt <= block_read_cnt + 1;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : element_read_counter
        if (~rst_ni) begin
            elem_read_cnt <= '0;
        end else begin
            if (clear_i) begin
                elem_read_cnt <= '0;
            end else if (elem_read_cnt_en) begin
                if (elem_read_cnt == ELEM_READS - 1) begin
                    elem_read_cnt <= '0;
                end else begin
                    elem_read_cnt <= elem_read_cnt + 1;
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : state_register
        if (~rst_ni) begin
            current_state <= EMPTY;
        end else begin
            if (clear_i) begin
                current_state <= EMPTY;
            end else begin
                current_state <= next_state;
            end
        end
    end

    // We can do this as N_BLOCKS has to be a power of 2
    assign buffer_read_cnt      = block_read_cnt >> $clog2(N_BLOCKS);
    assign block_leftover       = ctrl_i.num_blocks[$clog2(N_BLOCKS)-1:0];
    assign num_buffer_reads     = ctrl_i.num_blocks >> $clog2(N_BLOCKS);

    assign last_blk             = ((buffer_read_cnt == num_buffer_reads - 1) && (read_pointer_q > block_leftover)) || (buffer_read_cnt == num_buffer_reads);

    assign write_done           = last_blk && (direction == FORWARD ? (write_pointer_q == block_leftover) : (write_pointer_q == '0));

    always_comb begin
        buffer_i.ready      = '0;
        buffer_o.valid      = '0;

        dir_toggle          = '0;

        write_pointer_d     = write_pointer_q;
        read_pointer_d      = read_pointer_q;
        e_read_pointer_d    = e_read_pointer_q;

        elem_read_cnt_en    = '0;

        block_read_cnt_en   = '0;
        block_read_cnt_clr  = '0;

        last_weight         = '0;

        next_state          = current_state;

        case (current_state)
            EMPTY: begin
                buffer_i.ready  = '1;
                buffer_o.valid  = '0;

                if (buffer_i.valid) begin
                    if (write_done) begin
                        next_state = BOUNCE;
                    end else begin

                        next_state = MIDDLE;

                        if (direction == FORWARD) begin
                            if (write_pointer_q == N_BLOCKS - 1) begin
                                write_pointer_d = '0;
                            end else begin
                                write_pointer_d = write_pointer_q + 1; 
                            end
                        end else begin
                            if (write_pointer_q == '0) begin
                                write_pointer_d = N_BLOCKS - 1;
                            end else begin
                                write_pointer_d = write_pointer_q - 1; 
                            end
                        end
                    end
                end
            end

            MIDDLE: begin
                buffer_i.ready  = '1;
                buffer_o.valid  = '1;

                if (buffer_i.valid && buffer_o.ready) begin
                    elem_read_cnt_en    = '1;

                    if (direction == FORWARD) begin
                        if (write_done) begin
                            next_state = BOUNCE;
                        end else begin
                            if (write_pointer_q == N_BLOCKS - 1) begin
                                write_pointer_d = '0;
                            end else begin
                                write_pointer_d = write_pointer_q + 1; 
                            end
                        end

                        if ((e_read_pointer_q == N_ELEMS - 1) && (elem_read_cnt == ELEM_READS - 1)) begin
                            block_read_cnt_en   = '1;
                            e_read_pointer_d    = '0;

                            if (read_pointer_q == N_BLOCKS - 1) begin
                                read_pointer_d  = '0;
                            end else begin
                                read_pointer_d  = read_pointer_q + 1; 
                            end
                        end else begin
                            if (elem_read_cnt == ELEM_READS - 1) begin
                                e_read_pointer_d    = e_read_pointer_q + 1;
                            end

                            if ((~write_done) && ((write_pointer_q == read_pointer_q - 1) || ((write_pointer_q == N_BLOCKS - 1) && (read_pointer_q == '0)))) begin
                                next_state = FULL;
                            end
                        end
                    end else begin
                        if (write_done) begin
                            next_state = BOUNCE;
                        end else begin
                            if (write_pointer_q == '0) begin
                                write_pointer_d = N_BLOCKS - 1;
                            end else begin
                                write_pointer_d = write_pointer_q - 1; 
                            end
                        end

                        if ((e_read_pointer_q == '0) && (elem_read_cnt == ELEM_READS - 1)) begin
                            block_read_cnt_en   = '1;
                            e_read_pointer_d    = N_ELEMS - 1;

                            if (read_pointer_q == '0) begin
                                read_pointer_d  = N_BLOCKS - 1;
                            end else begin
                                read_pointer_d  = read_pointer_q - 1; 
                            end
                        end else begin
                            if (elem_read_cnt == ELEM_READS - 1) begin
                                e_read_pointer_d    = e_read_pointer_q - 1;
                            end

                            if ((~write_done) && ((write_pointer_q == read_pointer_q + 1) || ((write_pointer_q == '0) && (read_pointer_q == N_BLOCKS - 1)))) begin
                                next_state = FULL;
                            end
                        end
                    end
                end else if (~buffer_i.valid && buffer_o.ready) begin
                    elem_read_cnt_en    = '1;
                    
                    if (direction == FORWARD) begin
                        if ((e_read_pointer_q == N_ELEMS - 1) && (elem_read_cnt == ELEM_READS - 1)) begin
                            block_read_cnt_en   = '1;
                            e_read_pointer_d    = '0;

                            if (read_pointer_q == N_BLOCKS - 1) begin
                                read_pointer_d  = '0;
                            end else begin
                                read_pointer_d  = read_pointer_q + 1; 
                            end

                            if ((read_pointer_q == write_pointer_q - 1) || ((read_pointer_q == N_BLOCKS - 1) && (write_pointer_q == '0))) begin
                                next_state      = EMPTY;
                            end
                        end else begin
                            if (elem_read_cnt == ELEM_READS - 1) begin
                                e_read_pointer_d    = e_read_pointer_q + 1;
                            end
                        end
                    end else begin
                        if ((e_read_pointer_q == '0) && (elem_read_cnt == ELEM_READS - 1)) begin
                            block_read_cnt_en   = '1;
                            e_read_pointer_d    = N_ELEMS - 1;

                            if (read_pointer_q == '0) begin
                                read_pointer_d  = N_BLOCKS - 1;
                            end else begin
                                read_pointer_d  = read_pointer_q - 1; 
                            end

                            if ((read_pointer_q == write_pointer_q + 1) || ((read_pointer_q == '0) && (write_pointer_q == N_BLOCKS - 1))) begin
                                next_state = EMPTY;
                            end
                        end else begin
                            if ((elem_read_cnt == ELEM_READS - 1)) begin
                                e_read_pointer_d    = e_read_pointer_q - 1;
                            end
                        end
                    end
                end else if (buffer_i.valid && ~buffer_o.ready) begin
                    if (direction == FORWARD) begin
                        if (write_done) begin
                            next_state = BOUNCE;
                        end else begin
                            if ((write_pointer_q == read_pointer_q - 1) || ((write_pointer_q == N_BLOCKS - 1) && (read_pointer_q == '0))) begin
                                next_state = FULL;
                            end

                            if (write_pointer_q == N_BLOCKS - 1) begin
                                write_pointer_d = '0;
                            end else begin
                                write_pointer_d = write_pointer_q + 1; 
                            end
                        end
                    end else begin
                        if (write_done) begin
                            next_state = BOUNCE;
                        end else begin
                            if ((write_pointer_q == read_pointer_q + 1) || ((write_pointer_q == '0) && (read_pointer_q == N_BLOCKS - 1))) begin
                                next_state = FULL;
                            end
    
                            if (write_pointer_q == '0) begin
                                write_pointer_d = N_BLOCKS - 1;
                            end else begin
                                write_pointer_d = write_pointer_q - 1; 
                            end
                        end
                    end
                end
            end

            FULL: begin
                buffer_i.ready  = '0;
                buffer_o.valid  = '1;

                if (buffer_o.ready) begin
                    elem_read_cnt_en    = '1;

                    if (direction == FORWARD) begin
                        if ((e_read_pointer_q == N_ELEMS - 1) && (elem_read_cnt == ELEM_READS - 1)) begin
                            next_state = MIDDLE;

                            block_read_cnt_en   = '1;
                            e_read_pointer_d    = '0;

                            if (read_pointer_q == N_BLOCKS - 1) begin
                                read_pointer_d  = '0;
                            end else begin
                                read_pointer_d  = read_pointer_q + 1; 
                            end
                        end else begin
                            if (elem_read_cnt == ELEM_READS - 1) begin
                                e_read_pointer_d    = e_read_pointer_q + 1;
                            end
                        end
                    end else begin
                        if ((e_read_pointer_q == '0) && (elem_read_cnt == ELEM_READS - 1)) begin
                            next_state = MIDDLE;

                            block_read_cnt_en   = '1;
                            e_read_pointer_d    = N_ELEMS - 1;

                            if (read_pointer_q == '0) begin
                                read_pointer_d  = N_BLOCKS - 1;
                            end else begin
                                read_pointer_d  = read_pointer_q - 1; 
                            end
                        end else begin
                            if (elem_read_cnt == ELEM_READS - 1) begin
                                e_read_pointer_d    = e_read_pointer_q - 1;
                            end
                        end
                    end
                end
            end

            BOUNCE: begin
                buffer_i.ready  = '0;
                buffer_o.valid  = '1;
                
                if (buffer_o.ready) begin
                    elem_read_cnt_en    = '1;

                    if (direction == FORWARD) begin
                        last_weight = (read_pointer_q == write_pointer_q) && (e_read_pointer_q == ctrl_i.leftover);

                        if ((read_pointer_q == write_pointer_q) && (e_read_pointer_q == ctrl_i.leftover) && (elem_read_cnt == ELEM_READS - 1)) begin
                            next_state          = buffer_read_cnt == '0 ? BOUNCE : FULL;
                            dir_toggle          = '1;
                            block_read_cnt_clr  = '1;

                            if (buffer_read_cnt == '0) begin
                                write_pointer_d = '0;
                            end
                        end else if ((e_read_pointer_q == N_ELEMS - 1) && (elem_read_cnt == ELEM_READS - 1)) begin
                            block_read_cnt_en   = '1;
                            e_read_pointer_d    = '0;

                            if (read_pointer_q == N_BLOCKS - 1) begin
                                read_pointer_d  = '0;
                            end else begin
                                read_pointer_d  = read_pointer_q + 1; 
                            end
                        end else begin
                            if (elem_read_cnt == ELEM_READS - 1) begin
                                e_read_pointer_d    = e_read_pointer_q + 1;
                            end
                        end
                    end else begin
                        last_weight = (e_read_pointer_q == '0) && (read_pointer_q == write_pointer_q);

                        if ((e_read_pointer_q == '0) && (elem_read_cnt == ELEM_READS - 1)) begin
                            if (read_pointer_q == write_pointer_q) begin
                                next_state          = buffer_read_cnt == '0 ? BOUNCE : FULL;
                                dir_toggle          = '1;
                                block_read_cnt_clr  = '1;

                                if (buffer_read_cnt == '0) begin
                                    write_pointer_d = ctrl_i.num_blocks;
                                end
                            end else begin
                                block_read_cnt_en   = '1;
                                e_read_pointer_d    = N_ELEMS - 1;

                                if (read_pointer_q == '0) begin
                                    read_pointer_d  = N_BLOCKS - 1;
                                end else begin
                                    read_pointer_d  = read_pointer_q - 1; 
                                end
                            end
                        end else begin
                            if (elem_read_cnt == ELEM_READS - 1) begin
                                e_read_pointer_d    = e_read_pointer_q - 1;
                            end
                        end
                    end
                end
            end
        endcase
    end

    if (LATCH_BUFFER == 0) begin : gen_ff_buffer
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (~rst_ni) begin
                for (int i = 0; i < N_BLOCKS; i++) begin
                    buf_registers[i] <= '0;
                end
            end else if (clear_i) begin
                for (int i = 0; i < N_BLOCKS; i++) begin
                    buf_registers[i] <= '0;
                end
            end else begin
                if ((buffer_i.ready == '1) && (buffer_i.valid == '1)) begin
                    buf_registers[write_pointer_q] <= {buffer_i.strb, buffer_i.data};
                end
            end
        end

        assign {block_strb_out, block_data_out} = buf_registers[read_pointer_q];

        assign buffer_o.data    = {last_weight, block_data_out[e_read_pointer_q]};
        assign buffer_o.strb    = block_strb_out[e_read_pointer_q];
    end else begin : gen_latch_buffer
        hwpe_stream_fifo_scm #(
            .ADDR_WIDTH (   B_ADDR_LEN                              ),
            .DATA_WIDTH (   ELEM_WIDTH*N_ELEMS + STRB_WIDTH*N_ELEMS )
        ) i_latch_buffer (
            .clk            (   clk_i                               ),
            .rst_n          (   rst_ni                              ),
            .ReadEnable     (   1'b1                                ),
            .ReadAddr       (   read_pointer_d                      ),
            .ReadData       (   {block_strb_out, block_data_out}    ),
            .WriteEnable    (   buffer_i.ready & buffer_i.valid     ),
            .WriteAddr      (   write_pointer_q                     ),
            .WriteData      (   {buffer_i.strb, buffer_i.data}      )
        );

        assign buffer_o.data    = {last_weight, block_data_out[e_read_pointer_q]};
        assign buffer_o.strb    = block_strb_out[e_read_pointer_q];
    end

endmodule