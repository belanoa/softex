import hwpe_stream_package::*;
import hci_package::*;

module sfm_streamer #(
    parameter int unsigned  DATA_WIDTH  = 128   ,
    parameter int unsigned  ADDR_WIDTH  = 32    
) (
    input   logic                   clk_i               ,
    input   logic                   rst_ni              ,
    input   logic                   clear_i             ,
    input   logic                   enable_i            ,
    input   hci_streamer_ctrl_t     in_stream_ctrl_i    ,
    input   hci_streamer_ctrl_t     out_stream_ctrl_i   ,
    output  hci_streamer_flags_t    in_stream_flags_o   ,
    output  hci_streamer_flags_t    out_stream_flags_o  ,

    hwpe_stream_intf_stream.source  in_stream_o         ,
    hwpe_stream_intf_stream.sink    out_stream_i        ,

    hci_core_intf.master            tcdm                
);

    hci_streamer_ctrl_t     in_stream_ctrl,
                            out_stream_ctrl;

    logic [31:0]    load_cnt_d,
                    load_cnt_q;
    logic           load_cnt_enable;

    logic [31:0]    store_cnt_d,
                    store_cnt_q;
    logic           store_cnt_enable;

    logic [$clog2(DATA_WIDTH / 8) - 1 : 0]  i_init_lftovr,
                                            i_length_lftovr,
                                            i_final_lftovr,
                                            o_init_lftovr,
                                            o_length_lftovr,
                                            o_final_lftovr;

    logic   i_init_inc,
            i_final_inc,
            o_init_inc,
            o_final_inc;

    logic [DATA_WIDTH / 8 - 1 : 0]  i_strb,
                                    i_init_strb,
                                    i_final_strb,
                                    o_strb,
                                    o_init_strb,
                                    o_final_strb;

    logic [1:0] reqs,
                r_valids;

    hwpe_stream_intf_stream #(
        .DATA_WIDTH (   DATA_WIDTH  )
    ) in_stream (
        .clk(   clk_i   )
    );

    hwpe_stream_intf_stream #(
        .DATA_WIDTH (   DATA_WIDTH  )
    ) out_stream (
        .clk(   clk_i   )
    );

    hci_core_intf #(
        .DW (   DATA_WIDTH  ),
        .UW (   1           )
    ) ldst_tcdm ( 
        .clk    (   clk_i   ) 
    );

    hci_core_intf #(
        .DW (   DATA_WIDTH  ),
        .UW (   1           )
    ) mux_i_tcdm [1:0] (
        .clk    (   clk_i   )
    );

    hci_core_mux_ooo #(
        .NB_CHAN    (   2           ),
        .DW         (   DATA_WIDTH  ),
        .AW         (   ),
        .BW         (   ),
        .WW         (   ),
        .UW         (   ),
        .OW         (   )
    ) i_ldst_mux (
        .clk_i              (   clk_i       ),
        .rst_ni             (   rst_ni      ),
        .clear_i            (   clear_i     ),
        .priority_force_i   (   '0          ),
        .priority_i         (   '0          ),
        .in                 (   mux_i_tcdm  ),
        .out                (   ldst_tcdm   )
    );

    hci_core_r_valid_filter i_tcdm_filter (
        .clk_i       (  clk_i           ),
        .rst_ni      (  rst_ni          ),
        .clear_i     (  clear_i         ),
        .enable_i    (  1'b1            ),
        .tcdm_slave  (  ldst_tcdm       ),
        .tcdm_master (  tcdm            )
    );

    ///////////////////////////////////

    assign i_init_lftovr    = in_stream_ctrl_i.addressgen_ctrl.base_addr [$clog2(DATA_WIDTH / 8) - 1 : 0];
    assign i_length_lftovr  = in_stream_ctrl_i.addressgen_ctrl.d0_len [$clog2(DATA_WIDTH / 8) - 1 : 0];
    assign i_final_lftovr   = i_length_lftovr - (~i_init_lftovr + 1'b1);

    assign i_init_inc   = |i_init_lftovr;
    assign i_final_inc  = i_length_lftovr > (~i_init_lftovr + 1'b1);

    always_comb begin
        i_init_strb = '1;

        for (int i = 0; i < DATA_WIDTH / 8; i++) begin
            if (i < i_init_lftovr) begin
                i_init_strb [i] = 1'b0;
            end 
        end
    end

    always_comb begin
        i_final_strb = '1;

        if (i_final_lftovr != '0) begin
            for (int i = 0; i < DATA_WIDTH / 8; i++) begin
                if (i >= i_final_lftovr) begin
                    i_final_strb [i] = 1'b0;
                end 
            end
        end
    end

    assign in_stream_ctrl.req_start = in_stream_ctrl_i.req_start;

    assign in_stream_ctrl.addressgen_ctrl.base_addr     = {in_stream_ctrl_i.addressgen_ctrl.base_addr [31 : $clog2(DATA_WIDTH / 8)], {($clog2(DATA_WIDTH / 8)){1'b0}}}; //We're assuming DATA_WIDTH is a power of 2
    assign in_stream_ctrl.addressgen_ctrl.tot_len       = in_stream_ctrl_i.addressgen_ctrl.tot_len + i_init_inc + i_final_inc;
    assign in_stream_ctrl.addressgen_ctrl.d0_len        = in_stream_ctrl_i.addressgen_ctrl.d0_len;
    assign in_stream_ctrl.addressgen_ctrl.d0_stride     = in_stream_ctrl_i.addressgen_ctrl.d0_stride;
    assign in_stream_ctrl.addressgen_ctrl.d1_len        = in_stream_ctrl_i.addressgen_ctrl.d1_len;
    assign in_stream_ctrl.addressgen_ctrl.d1_stride     = in_stream_ctrl_i.addressgen_ctrl.d1_stride;
    assign in_stream_ctrl.addressgen_ctrl.d2_stride     = in_stream_ctrl_i.addressgen_ctrl.d2_stride;
    assign in_stream_ctrl.addressgen_ctrl.dim_enable_1h = in_stream_ctrl_i.addressgen_ctrl.dim_enable_1h;


    assign load_cnt_enable  = in_stream_o.valid & in_stream_o.ready;
    assign load_cnt_d       = (load_cnt_q == (in_stream_ctrl.addressgen_ctrl.tot_len - 1)) ? '0 : (load_cnt_q + 1);

    always_ff @(posedge clk_i or negedge rst_ni) begin : load_counter
        if (~rst_ni) begin
            load_cnt_q <= '0;
        end else begin
            if (clear_i) begin
                load_cnt_q <= '0;
            end else if (load_cnt_enable) begin
                load_cnt_q <= load_cnt_d;
            end else begin
                load_cnt_q <= load_cnt_q;
            end
        end
    end

    always_comb begin
        if (load_cnt_q == '0) begin
            i_strb = i_init_strb;
        end else if (load_cnt_q == (in_stream_ctrl.addressgen_ctrl.tot_len - 1)) begin
            i_strb = i_final_strb;
        end else begin
            i_strb = '1;
        end
    end

    assign  in_stream_o.valid   = in_stream.valid;
    assign  in_stream_o.data    = in_stream.data;
    assign  in_stream_o.strb    = i_strb;

    assign  in_stream.ready     = in_stream_o.ready;

    hci_core_intf #(
        .DW (   DATA_WIDTH  ),
        .UW (   1           )
    ) load_fifo (
        .clk    (   clk_i   )
    );

    hci_core_source #(
        .DATA_WIDTH             (   DATA_WIDTH  ),
        .MISALIGNED_ACCESSES    (   0           )
    ) i_stream_in (
        .clk_i          (   clk_i               ),
        .rst_ni         (   rst_ni              ),
        .test_mode_i    (   '0                  ),
        .clear_i        (   clear_i             ),
        .enable_i       (   enable_i            ),
        .tcdm           (   load_fifo           ),
        .stream         (   in_stream           ),
        .ctrl_i         (   in_stream_ctrl      ),
        .flags_o        (   in_stream_flags_o   )
    );

    hci_core_fifo #(
        .FIFO_DEPTH (   2           ),
        .DW         (   DATA_WIDTH  )
    ) i_load_fifo (
        .clk_i       (  clk_i           ),
        .rst_ni      (  rst_ni          ),
        .clear_i     (  clear_i         ),
        .flags_o     (                  ),
        .tcdm_slave  (  load_fifo       ),
        .tcdm_master (  mux_i_tcdm [0]  )
    );

    /////////////////////////////////

    assign o_init_lftovr    = out_stream_ctrl_i.addressgen_ctrl.base_addr [$clog2(DATA_WIDTH / 8) - 1 : 0];
    assign o_length_lftovr  = out_stream_ctrl_i.addressgen_ctrl.d0_len [$clog2(DATA_WIDTH / 8) - 1 : 0];
    assign o_final_lftovr   = o_length_lftovr - (~o_init_lftovr + 1'b1);

    assign o_init_inc   = |o_init_lftovr;
    assign o_final_inc  = o_length_lftovr > (~o_init_lftovr + 1'b1);

    always_comb begin
        o_init_strb = '1;

        for (int i = 0; i < DATA_WIDTH / 8; i++) begin
            if (i < o_init_lftovr) begin
                o_init_strb [i] = 1'b0;
            end 
        end
    end

    always_comb begin
        o_final_strb = '1;

        if (o_final_lftovr != '0) begin
            for (int i = 0; i < DATA_WIDTH / 8; i++) begin
                if (i >= o_final_lftovr) begin
                    o_final_strb [i] = 1'b0;
                end 
            end
        end
    end

    assign out_stream_ctrl.req_start = out_stream_ctrl_i.req_start;

    assign out_stream_ctrl.addressgen_ctrl.base_addr     = {out_stream_ctrl_i.addressgen_ctrl.base_addr [31 : $clog2(DATA_WIDTH / 8)], {($clog2(DATA_WIDTH / 8)){1'b0}}}; //We're assuming DATA_WIDTH is a power of 2
    assign out_stream_ctrl.addressgen_ctrl.tot_len       = out_stream_ctrl_i.addressgen_ctrl.tot_len + o_init_inc + o_final_inc;
    assign out_stream_ctrl.addressgen_ctrl.d0_len        = out_stream_ctrl_i.addressgen_ctrl.d0_len;
    assign out_stream_ctrl.addressgen_ctrl.d0_stride     = out_stream_ctrl_i.addressgen_ctrl.d0_stride;
    assign out_stream_ctrl.addressgen_ctrl.d1_len        = out_stream_ctrl_i.addressgen_ctrl.d1_len;
    assign out_stream_ctrl.addressgen_ctrl.d1_stride     = out_stream_ctrl_i.addressgen_ctrl.d1_stride;
    assign out_stream_ctrl.addressgen_ctrl.d2_stride     = out_stream_ctrl_i.addressgen_ctrl.d2_stride;
    assign out_stream_ctrl.addressgen_ctrl.dim_enable_1h = out_stream_ctrl_i.addressgen_ctrl.dim_enable_1h;


    assign store_cnt_enable  = out_stream_i.valid & out_stream_i.ready;
    assign store_cnt_d       = store_cnt_q == (out_stream_ctrl.addressgen_ctrl.tot_len - 1) ? '0 : (store_cnt_q + 1);

    always_ff @(posedge clk_i or negedge rst_ni) begin : store_counter
        if (~rst_ni) begin
            store_cnt_q <= '0;
        end else begin
            if (clear_i) begin
                store_cnt_q <= '0;
            end else if (store_cnt_enable) begin
                store_cnt_q <= store_cnt_d;
            end else begin
                store_cnt_q <= store_cnt_q;
            end
        end
    end

    always_comb begin
        if (store_cnt_q == '0) begin
            o_strb = o_init_strb;
        end else if (store_cnt_q == (in_stream_ctrl.addressgen_ctrl.tot_len - 1)) begin
            o_strb = o_final_strb;
        end else begin
            o_strb = '1;
        end
    end

    assign  out_stream.valid   = out_stream_i.valid;
    assign  out_stream.data    = out_stream_i.data;
    assign  out_stream.strb    = out_stream_i.strb & o_strb;

    assign  out_stream_i.ready = out_stream.ready;

    hci_core_intf #(
        .DW (   DATA_WIDTH  ),
        .UW (   1           )
    ) store_fifo (
        .clk    (   clk_i   )
    );

    hci_core_sink #(
        .DATA_WIDTH             (   DATA_WIDTH  ),
        .MISALIGNED_ACCESSES    (   0           )
    ) i_stream_out (
        .clk_i          (   clk_i               ),
        .rst_ni         (   rst_ni              ),
        .test_mode_i    (   '0                  ),
        .clear_i        (   clear_i             ),
        .enable_i       (   enable_i            ),
        .tcdm           (   store_fifo          ),
        .stream         (   out_stream          ),
        .ctrl_i         (   out_stream_ctrl     ),
        .flags_o        (   out_stream_flags_o  )
    );

    hci_core_fifo #(
        .FIFO_DEPTH (   2           ),
        .DW         (   DATA_WIDTH  )
    ) i_store_fifo (
        .clk_i       (  clk_i           ),
        .rst_ni      (  rst_ni          ),
        .clear_i     (  clear_i         ),
        .flags_o     (                  ),
        .tcdm_slave  (  store_fifo      ),
        .tcdm_master (  mux_i_tcdm [1]  )
    ); 


endmodule