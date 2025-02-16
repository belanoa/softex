// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
// Yvan Tortorella <yvan.tortorella@unibo.it>
//

`include "hci_helpers.svh"

import hwpe_stream_package::*;
import hci_package::*;
import softex_pkg::*;

module softex_streamer #(
    parameter hci_size_parameter_t `HCI_SIZE_PARAM(Tcdm) = '0,
    parameter int unsigned ACTUAL_DW = 0
) (
    input   logic                   clk_i               ,
    input   logic                   rst_ni              ,
    input   logic                   clear_i             ,
    input   logic                   enable_i            ,
    input   cast_ctrl_t             in_cast_i           ,
    input   cast_ctrl_t             out_cast_i          ,
    input   hci_streamer_ctrl_t     in_stream_ctrl_i    ,
    input   hci_streamer_ctrl_t     out_stream_ctrl_i   ,
    input   hci_streamer_ctrl_t     slot_in_ctrl_i      ,
    input   hci_streamer_ctrl_t     slot_out_ctrl_i     ,
    output  hci_streamer_flags_t    in_stream_flags_o   ,
    output  hci_streamer_flags_t    out_stream_flags_o  ,
    output  hci_streamer_flags_t    slot_in_flags_o     ,
    output  hci_streamer_flags_t    slot_out_flags_o    ,

    hwpe_stream_intf_stream.source  in_stream_o         ,
    hwpe_stream_intf_stream.sink    out_stream_i        ,
    hwpe_stream_intf_stream.source  slot_in_stream_o    ,
    hwpe_stream_intf_stream.sink    slot_out_stream_i   ,

    hci_core_intf.initiator         tcdm
);

    localparam int unsigned DW = `HCI_SIZE_GET_DW(Tcdm);
    localparam int unsigned EW = `HCI_SIZE_GET_EW(Tcdm);

    // this localparam is reused for all internal, non-ecc HCI interfaces
    localparam hci_size_parameter_t `HCI_SIZE_PARAM(Tcdm_no_ecc) = '{
        DW:  DW,
        AW:  DEFAULT_AW,
        BW:  DEFAULT_BW,
        UW:  DEFAULT_UW,
        IW:  DEFAULT_IW,
        EW:  DEFAULT_EW,
        EHW: DEFAULT_EHW
    };

    hwpe_stream_intf_stream #(
        .DATA_WIDTH ( ACTUAL_DW )
    ) in_stream (
        .clk(   clk_i   )
    );

    hwpe_stream_intf_stream #(
        .DATA_WIDTH ( ACTUAL_DW )
    ) out_stream (
        .clk(   clk_i   )
    );

    hwpe_stream_intf_stream #(
        .DATA_WIDTH ( ACTUAL_DW )
    ) in_stream_pre_cast (
        .clk(   clk_i   )
    );

    hwpe_stream_intf_stream #(
        .DATA_WIDTH ( ACTUAL_DW )
    ) out_stream_post_cast (
        .clk(   clk_i   )
    );

    hci_core_intf #(
        .DW ( DW )
    ) tcdm_no_ecc (
        .clk    (   clk_i   )
    );

    hci_core_intf #(
        .DW ( DW )
    ) ldst_tcdm [0:0] (
        .clk    (   clk_i   )
    );

    hci_core_intf #(
        .DW ( DW )
    ) load_tcdm (
        .clk    (   clk_i   )
    );

    hci_core_intf #(
        .DW ( DW )
    ) store_tcdm (
        .clk    (   clk_i   )
    );

    hci_core_intf #(
        .DW ( DW  )
    ) mux_i_tcdm [1:0] (
        .clk    (   clk_i   )
    );

    if (EW > 1) begin : gen_ecc_encoder
        errs_streamer_t ecc_errors;
        logic [DW/ECC_CHUNK_SIZE-1:0] data_single_err, data_multi_err;
        logic                         meta_single_err, meta_multi_err;

        hci_ecc_enc #(
            .DW ( DW ),
            .`HCI_SIZE_PARAM(tcdm_target)    ( `HCI_SIZE_PARAM(Tcdm_no_ecc) ),
            .`HCI_SIZE_PARAM(tcdm_initiator) ( `HCI_SIZE_PARAM(Tcdm)        )
        ) i_hci_ecc_enc (
            .r_data_single_err_o ( data_single_err ),
            .r_data_multi_err_o  ( data_multi_err  ),
            .r_meta_single_err_o ( meta_single_err ),
            .r_meta_multi_err_o  ( meta_multi_err  ),
            .tcdm_target         ( tcdm_no_ecc     ),
            .tcdm_initiator      ( tcdm            )
        );

        assign ecc_errors.data_single_err = data_single_err & {ECC_N_CHUNK{tcdm.r_valid}};
        assign ecc_errors.data_multi_err  = data_multi_err  & {ECC_N_CHUNK{tcdm.r_valid}};
        assign ecc_errors.meta_single_err = meta_single_err & (tcdm.req & tcdm.gnt);
        assign ecc_errors.meta_multi_err  = meta_multi_err  & (tcdm.req & tcdm.gnt);
    end else begin : gen_no_ecc_assign
        hci_core_assign i_no_ecc_assign ( .tcdm_target (tcdm_no_ecc), .tcdm_initiator (tcdm) );
    end

    hci_core_mux_dynamic #(
        .NB_IN_CHAN             ( 2                            ),
        .NB_OUT_CHAN            ( 1                            ),
        .`HCI_SIZE_PARAM(in)    ( `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_ldst_mux (
        .clk_i              (   clk_i       ),
        .rst_ni             (   rst_ni      ),
        .clear_i            (   clear_i     ),
        .in                 (   mux_i_tcdm  ),
        .out                (   ldst_tcdm   )
    );

    hci_core_r_valid_filter #(
        .`HCI_SIZE_PARAM(tcdm_target)   ( `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_tcdm_r_valid_filter (
        .clk_i          (  clk_i            ),
        .rst_ni         (  rst_ni           ),
        .clear_i        (  clear_i          ),
        .enable_i       (  1'b1             ),
        .tcdm_target    (  ldst_tcdm [0]    ),
        .tcdm_initiator (  tcdm_no_ecc      )
    );

    /*      LOAD CHANNEL      */

    softex_cast_in #(
        .DATA_WIDTH (   ACTUAL_DW  )
    ) i_cast_in (
        .ctrl_i     (   in_cast_i           ),
        .stream_i   (   in_stream_pre_cast  ),
        .stream_o   (   in_stream_o         )
    );

    softex_streamer_strb_gen #(
        .DW (   ACTUAL_DW  )
    ) i_load_strb_gen (
        .clk_i          (   clk_i               ),
        .rst_ni         (   rst_ni              ),
        .clear_i        (   clear_i             ),
        .stream_ctrl_i  (   in_stream_ctrl_i    ),
        .stream_i       (   in_stream           ),
        .stream_o       (   in_stream_pre_cast  )
    );

    hci_core_intf #(
        .DW ( DW )
    ) load_mux_i_tcdm [1:0] (
        .clk    (   clk_i   )
    );

    hci_core_source #(
        .MISALIGNED_ACCESSES    (   1                            ),
        .`HCI_SIZE_PARAM(tcdm)  (   `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_stream_in (
        .clk_i          (   clk_i               ),
        .rst_ni         (   rst_ni              ),
        .test_mode_i    (   '0                  ),
        .clear_i        (   clear_i             ),
        .enable_i       (   enable_i            ),
        .tcdm           (   load_mux_i_tcdm [0] ),
        .stream         (   in_stream           ),
        .ctrl_i         (   in_stream_ctrl_i    ),
        .flags_o        (   in_stream_flags_o   )
    );

    hci_core_source #(
        .MISALIGNED_ACCESSES    (   1                            ),
        .`HCI_SIZE_PARAM(tcdm)  (   `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_slot_in (
        .clk_i          (   clk_i               ),
        .rst_ni         (   rst_ni              ),
        .test_mode_i    (   '0                  ),
        .clear_i        (   clear_i             ),
        .enable_i       (   enable_i            ),
        .tcdm           (   load_mux_i_tcdm [1] ),
        .stream         (   slot_in_stream_o    ),
        .ctrl_i         (   slot_in_ctrl_i      ),
        .flags_o        (   slot_in_flags_o     )
    );

    hci_core_intf #(
        .DW ( DW )
    ) load_fifo (
        .clk    (   clk_i   )
    );

    hci_core_mux_ooo #(
        .NB_CHAN                (   2                            ),
        .`HCI_SIZE_PARAM(out)   (   `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_load_mux (
        .clk_i              (   clk_i           ),
        .rst_ni             (   rst_ni          ),
        .clear_i            (   clear_i         ),
        .priority_force_i   (   '0              ),
        .priority_i         (   '0              ),
        .in                 (   load_mux_i_tcdm ),
        .out                (   load_fifo       )
    );

    hci_core_fifo #(
        .FIFO_DEPTH                         (   2                            ),
        .`HCI_SIZE_PARAM(tcdm_initiator)    (   `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_load_fifo (
        .clk_i          (  clk_i        ),
        .rst_ni         (  rst_ni       ),
        .clear_i        (  clear_i      ),
        .flags_o        (               ),
        .tcdm_target    (  load_fifo    ),
        .tcdm_initiator (  load_tcdm    )
    );

    hci_core_r_id_filter #(
        .`HCI_SIZE_PARAM(tcdm_target)   (   `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_load_r_id_filter (
        .clk_i          (   clk_i           ),
        .rst_ni         (   rst_ni          ),
        .clear_i        (   clear_i         ),
        .enable_i       (   enable_i        ),
        .tcdm_target    (   load_tcdm       ),
        .tcdm_initiator (   mux_i_tcdm [0]  )
    );

    /*      STORE CHANNEL      */

    softex_cast_out #(
        .DATA_WIDTH (   ACTUAL_DW  )
    ) i_cast_out (
        .ctrl_i     (   out_cast_i              ),
        .stream_i   (   out_stream_i            ),
        .stream_o   (   out_stream_post_cast    )
    );

    softex_streamer_strb_gen #(
        .DW (   ACTUAL_DW  )
    ) i_store_strb_gen (
        .clk_i          (   clk_i                   ),
        .rst_ni         (   rst_ni                  ),
        .clear_i        (   clear_i                 ),
        .stream_ctrl_i  (   out_stream_ctrl_i       ),
        .stream_i       (   out_stream_post_cast    ),
        .stream_o       (   out_stream              )
    );

    hci_core_intf #(
        .DW ( DW )
    ) store_mux_i_tcdm [1:0] (
        .clk    (   clk_i   )
    );

    hci_core_sink #(
        .MISALIGNED_ACCESSES    (   1                            ),
        .`HCI_SIZE_PARAM(tcdm)  (   `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_stream_out (
        .clk_i          (   clk_i                   ),
        .rst_ni         (   rst_ni                  ),
        .test_mode_i    (   '0                      ),
        .clear_i        (   clear_i                 ),
        .enable_i       (   enable_i                ),
        .tcdm           (   store_mux_i_tcdm [0]    ),
        .stream         (   out_stream              ),
        .ctrl_i         (   out_stream_ctrl_i       ),
        .flags_o        (   out_stream_flags_o      )
    );

    hci_core_sink #(
        .MISALIGNED_ACCESSES    (   1                            ),
        .`HCI_SIZE_PARAM(tcdm)  (   `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_slot_out (
        .clk_i          (   clk_i                   ),
        .rst_ni         (   rst_ni                  ),
        .test_mode_i    (   '0                      ),
        .clear_i        (   clear_i                 ),
        .enable_i       (   enable_i                ),
        .tcdm           (   store_mux_i_tcdm [1]    ),
        .stream         (   slot_out_stream_i       ),
        .ctrl_i         (   slot_out_ctrl_i         ),
        .flags_o        (   slot_out_flags_o        )
    );

    hci_core_intf #(
        .DW ( DW )
    ) store_fifo (
        .clk    (   clk_i   )
    );

    hci_core_mux_ooo #(
        .NB_CHAN                (   2                            ),
        .`HCI_SIZE_PARAM(out)   (   `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_store_mux (
        .clk_i              (   clk_i               ),
        .rst_ni             (   rst_ni              ),
        .clear_i            (   clear_i             ),
        .priority_force_i   (   '0                  ),
        .priority_i         (   '0                  ),
        .in                 (   store_mux_i_tcdm    ),
        .out                (   store_fifo          )
    );

    hci_core_fifo #(
        .FIFO_DEPTH                         (   2                            ),
        .`HCI_SIZE_PARAM(tcdm_initiator)    (   `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_store_fifo (
        .clk_i          (  clk_i        ),
        .rst_ni         (  rst_ni       ),
        .clear_i        (  clear_i      ),
        .flags_o        (               ),
        .tcdm_target    (  store_fifo   ),
        .tcdm_initiator (  store_tcdm   )
    ); 
    
    hci_core_r_id_filter #(
        .`HCI_SIZE_PARAM(tcdm_target)   (   `HCI_SIZE_PARAM(Tcdm_no_ecc) )
    ) i_store_r_id_filter (
        .clk_i          (   clk_i           ),
        .rst_ni         (   rst_ni          ),
        .clear_i        (   clear_i         ),
        .enable_i       (   enable_i        ),
        .tcdm_target    (   store_tcdm      ),
        .tcdm_initiator (   mux_i_tcdm [1]  )
    );

endmodule
