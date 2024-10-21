// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import hwpe_stream_package::*;
import softex_pkg::*;

module softex_x_buffer #(
    parameter int unsigned              DATA_WIDTH      = DATA_W - 32       ,
    parameter int unsigned              STRB_WIDTH      = DATA_WIDTH / 8    ,
    parameter int unsigned              DEPTH           = NUM_REGS_ROW_ACC  ,
    parameter int unsigned              CNT_WIDTH       = BUF_CNT_WIDTH     , 
    parameter logic                     LATCH_BUFFER    = USE_LATCH_BUF
) (
    input   logic                   clk_i       ,
    input   logic                   rst_ni      ,
    input   logic                   clear_i     ,
    input   x_buffer_ctrl_t         ctrl_i      ,
    output  x_buffer_flags_t        flags_o     ,

    hwpe_stream_intf_stream.sink    buffer_i    ,
    hwpe_stream_intf_stream.source  buffer_o   
);

    localparam int unsigned ADDR_LEN    = (DEPTH == 1) ? 1 : $clog2(DEPTH);

    logic [ADDR_LEN-1:0]    read_pointer_d, read_pointer_q,
                            write_pointer_d, write_pointer_q,
                            buf_start_pointer_q;

    logic [CNT_WIDTH-1:0]   loop_cnt;
    logic                   loop_cnt_en, loop_cnt_clr;

    logic                   loop_flg;
    logic                   loop_flg_en, loop_flg_clr;

    logic                   buffer_fill, buf_start_pointer_en;

    logic                   last_read;

    logic [DEPTH-1:0] [DATA_WIDTH+STRB_WIDTH-1:0]  buf_registers;

    enum logic [1:0] { EMPTY, MIDDLE, FULL, LOOP} current_state, next_state;

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

    always_ff @(posedge clk_i or negedge rst_ni) begin : buf_start_register
        if (~rst_ni) begin
            buf_start_pointer_q <= '0;
        end else begin
            if (clear_i) begin
                buf_start_pointer_q <= '0;
            end else if (buf_start_pointer_en) begin
                buf_start_pointer_q <= write_pointer_q;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : loop_counter
        if (~rst_ni) begin
            loop_cnt <= '0;
        end else begin
            if (clear_i || loop_cnt_clr) begin
                loop_cnt <= '0;
            end else if (loop_cnt_en) begin
                loop_cnt <= loop_cnt + 1;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : loop_flag
        if (~rst_ni) begin
            loop_flg <= '0;
        end else begin
            if (clear_i || loop_flg_clr) begin
                loop_flg <= '0;
            end else if (loop_flg_en) begin
                loop_flg <= '1;
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

    always_comb begin
        buffer_i.ready          = '0;
        buffer_o.valid          = '0;

        loop_cnt_clr            = '0;
        loop_cnt_en             = '0;

        loop_flg_en             = '0;
        loop_flg_clr            = '0;

        write_pointer_d         = write_pointer_q;
        read_pointer_d          = read_pointer_q;

        buf_start_pointer_en    = '0;

        last_read               = '0;

        next_state              = current_state;

        case (current_state)
            EMPTY: begin
                buffer_i.ready  = '1;
                buffer_o.valid  = '0;

                if (buffer_i.valid) begin
                    next_state = MIDDLE;

                    if (write_pointer_q == DEPTH - 1) begin
                        write_pointer_d = '0;
                    end else begin
                        write_pointer_d = write_pointer_q + 1; 
                    end

                    if (ctrl_i.loop && ~loop_flg) begin
                        buf_start_pointer_en    = '1;
                        loop_flg_en             = '1;
                    end

                    if (loop_flg && ((write_pointer_q == (buf_start_pointer_q - 1)) || ((write_pointer_q == DEPTH - 1) && (buf_start_pointer_q == '0)))) begin
                        next_state = LOOP;
                    end
                end
            end

            MIDDLE: begin
                buffer_i.ready  = '1;
                buffer_o.valid  = '1;

                if (buffer_i.valid && buffer_o.ready) begin
                    if (write_pointer_q == DEPTH - 1) begin
                        write_pointer_d = '0;
                    end else begin
                        write_pointer_d = write_pointer_q + 1; 
                    end

                    if (read_pointer_q == DEPTH - 1) begin
                        read_pointer_d = '0;
                    end else begin
                        read_pointer_d = read_pointer_q + 1; 
                    end

                    if (ctrl_i.loop && ~loop_flg) begin
                        buf_start_pointer_en    = '1;
                        loop_flg_en             = '1;
                    end 

                    if (loop_flg && ((write_pointer_q == (buf_start_pointer_q - 1)) || ((write_pointer_q == DEPTH - 1) && (buf_start_pointer_q == '0)))) begin
                        next_state = LOOP;
                    end
                end else if (~buffer_i.valid && buffer_o.ready) begin
                    if ((read_pointer_q == write_pointer_q - 1) || ((read_pointer_q == DEPTH - 1) && (write_pointer_q == '0))) begin
                        next_state = EMPTY;
                    end
                    
                    if (read_pointer_q == DEPTH - 1) begin
                        read_pointer_d = '0;
                    end else begin
                        read_pointer_d = read_pointer_q + 1; 
                    end
                end else if (buffer_i.valid && ~buffer_o.ready) begin
                    if ((write_pointer_q == read_pointer_q - 1) || ((write_pointer_q == DEPTH - 1) && (read_pointer_q == '0))) begin
                        next_state = FULL;
                    end

                    if (write_pointer_q == DEPTH - 1) begin
                        write_pointer_d = '0;
                    end else begin
                        write_pointer_d = write_pointer_q + 1; 
                    end

                    if (ctrl_i.loop && ~loop_flg) begin
                        buf_start_pointer_en    = '1;
                        loop_flg_en             = '1;
                    end 
                    
                    if (loop_flg && ((write_pointer_q == (buf_start_pointer_q - 1)) || ((write_pointer_q == DEPTH - 1) && (buf_start_pointer_q == '0)))) begin
                        next_state = LOOP;
                    end
                end
            end

            FULL: begin
                buffer_i.ready  = '0;
                buffer_o.valid  = '1;

                if (buffer_o.ready) begin
                    next_state = MIDDLE;

                    if (read_pointer_q == DEPTH - 1) begin
                        read_pointer_d = '0;
                    end else begin
                        read_pointer_d = read_pointer_q + 1; 
                    end
                end
            end

            LOOP: begin
                buffer_i.ready  = '0;
                buffer_o.valid  = '1;

                if (buffer_o.ready) begin
                    if (read_pointer_q == DEPTH - 1) begin
                        read_pointer_d = '0;
                    end else begin
                        read_pointer_d = read_pointer_q + 1; 
                    end

                    if ((read_pointer_q == buf_start_pointer_q - 1) || ((read_pointer_q == DEPTH - 1) && (buf_start_pointer_q == '0))) begin
                        if (loop_cnt == (ctrl_i.num_loops - 2)) begin
                            loop_cnt_clr    = '1;
                            loop_flg_clr    = '1;
                            next_state      = FULL;
                        end else begin
                            loop_cnt_en = '1;
                        end
                    end
                end
            end
        endcase
    end

    if (LATCH_BUFFER == 0) begin : gen_ff_buffer
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (~rst_ni) begin
                for (int i = 0; i < DEPTH; i++) begin
                    buf_registers[i] <= '0;
                end
            end else if (clear_i) begin
                for (int i = 0; i < DEPTH; i++) begin
                    buf_registers[i] <= '0;
                end
            end else begin
                if ((buffer_i.ready == '1) && (buffer_i.valid == '1)) begin
                    buf_registers[write_pointer_q] <= {buffer_i.strb, buffer_i.data};
                end
            end
        end

      assign {buffer_o.strb, buffer_o.data} = buf_registers[read_pointer_q];
    end else begin : gen_latch_buffer
        hwpe_stream_fifo_scm #(
            .ADDR_WIDTH (   ADDR_LEN                ),
            .DATA_WIDTH (   DATA_WIDTH + STRB_WIDTH )
        ) i_latch_buffer (
            .clk            (   clk_i                           ),
            .rst_n          (   rst_ni                          ),
            .ReadEnable     (   1'b1                            ),
            .ReadAddr       (   read_pointer_d                  ),
            .ReadData       (   {buffer_o.strb, buffer_o.data}  ),
            .WriteEnable    (   buffer_i.ready & buffer_i.valid ),
            .WriteAddr      (   write_pointer_q                 ),
            .WriteData      (   {buffer_i.strb, buffer_i.data}  )
        );
    end

endmodule