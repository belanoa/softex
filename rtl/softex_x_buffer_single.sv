// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import hwpe_stream_package::*;
import softex_pkg::*;

module softex_x_buffer_single #(
    parameter int unsigned              DATA_WIDTH      = DATA_W - 32       ,
    parameter int unsigned              STRB_WIDTH      = DATA_WIDTH / 8    ,
    parameter int unsigned              DEPTH           = 2                 ,
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

    logic [CNT_WIDTH-1:0]   handshake_cnt;
    logic                   handshake_cnt_en, handshake_cnt_clr;

    hwpe_stream_intf_stream #(.DATA_WIDTH(DATA_WIDTH))  stream_q    (.clk(clk_i));

    always_ff @(posedge clk_i or negedge rst_ni) begin : handshake_counter
        if (~rst_ni) begin
            handshake_cnt <= '0;
        end else begin
            if (clear_i || handshake_cnt_clr) begin
                handshake_cnt <= '0;
            end else if (handshake_cnt_en) begin
                handshake_cnt <= handshake_cnt + 1;
            end
        end
    end

    hwpe_stream_fifo #(
        .DATA_WIDTH     (   DATA_WIDTH      ),
        .FIFO_DEPTH     (   DEPTH           ),
        .LATCH_FIFO     (   LATCH_BUFFER    )
    ) i_fifo (
        .clk_i      (   clk_i       ),
        .rst_ni     (   rst_ni      ),
        .clear_i    (   clear       ),
        .flags_o    (               ),
        .push_i     (   buffer_i    ),
        .pop_o      (   stream_q    )
    );

    assign handshake_cnt_en     = (stream_q.valid & buffer_o.ready) & ctrl_i.loop;
    assign handshake_cnt_clr    = (handshake_cnt + 1) == ctrl_i.num_loops;

    assign buffer_o.data    = stream_q.data;
    assign buffer_o.valid   = stream_q.valid;
    assign stream_q.ready   = ctrl_i.loop ? (handshake_cnt_clr & buffer_o.ready) : buffer_o.ready;
    assign buffer_o.strb    = stream_q.strb; 

endmodule