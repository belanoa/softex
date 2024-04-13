import hwpe_stream_package::*;
import hci_package::*;

module sfm_streamer_strb_gen #(
    parameter int unsigned  DW  = 128   
) (
    input   logic                   clk_i           ,
    input   logic                   rst_ni          ,
    input   logic                   clear_i         ,
    input   hci_streamer_ctrl_t     stream_ctrl_i   ,

    hwpe_stream_intf_stream.sink    stream_i        ,
    hwpe_stream_intf_stream.source  stream_o    
);

    localparam int unsigned ACTUAL_DW   = DW - 32;

    logic [31:0]    handshake_cnt_d,
                    handshake_cnt_q;
    logic           handshake_cnt_enable;

    logic [$clog2(ACTUAL_DW / 8) - 1 : 0]   length_lftovr;

    logic   is_lftovr;

    logic [ACTUAL_DW / 8 - 1 : 0]   strb,
                                    final_strb;

    assign length_lftovr    = stream_ctrl_i.addressgen_ctrl.d0_len [$clog2(ACTUAL_DW / 8) - 1 : 0];

    assign is_lftovr        = |length_lftovr;


    /*  If the length of the vector to load is not a multiple of the bandwidth, *
     *  the final load / store will only contain "length_lftovr" valid bytes.   *    
     *  The remaining bytes have to be filtered out by altering the strobe of   *
     *  the final load / store.                                                 */

    always_comb begin
        final_strb = '1;

        for (int i = 0; i < ACTUAL_DW / 8; i++) begin
            if (i >= length_lftovr) begin
                final_strb [i] = 1'b0;
            end 
        end
    end

    assign handshake_cnt_enable  = stream_i.valid & stream_i.ready & is_lftovr;
    assign handshake_cnt_d       = (handshake_cnt_q == (stream_ctrl_i.addressgen_ctrl.tot_len - 1)) ? '0 : (handshake_cnt_q + 1);

    always_ff @(posedge clk_i or negedge rst_ni) begin : handshake_counter
        if (~rst_ni) begin
            handshake_cnt_q <= '0;
        end else begin
            if (clear_i) begin
                handshake_cnt_q <= '0;
            end else if (handshake_cnt_enable) begin
                handshake_cnt_q <= handshake_cnt_d;
            end else begin
                handshake_cnt_q <= handshake_cnt_q;
            end
        end
    end

    always_comb begin
        if (handshake_cnt_q == (stream_ctrl_i.addressgen_ctrl.tot_len - 1)) begin
            strb = final_strb;
        end else begin
            strb = '1;
        end
    end

    assign  stream_o.valid   = stream_i.valid;
    assign  stream_o.data    = stream_i.data;
    assign  stream_o.strb    = {32'b0, strb};

    assign  stream_i.ready   = stream_o.ready;
    
endmodule