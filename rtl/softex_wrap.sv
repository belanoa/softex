// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
// Yvan Tortorella <yvan.tortorella@unibo.it>
//

`include "hci_helpers.svh"

import hci_package::*;
import hwpe_ctrl_package::*;
import softex_pkg::*;

module softex_wrap #(
    parameter int unsigned              ID_WIDTH    = 8             ,
    parameter int unsigned              N_CORES     = 8             ,
    parameter int unsigned              DW          = DATA_W        ,
    parameter int unsigned              MP          = DW / 32       ,
    parameter fpnew_pkg::fp_format_e    FPFORMAT    = FPFORMAT_IN   
) (
    // global signals
    input  logic                      clk_i               ,
    input  logic                      rst_ni              ,
    input  logic                      test_mode_i         ,
    // events
    output logic [N_CORES-1:0][1:0]   evt_o               ,
    output logic                      busy_o              ,
    // tcdm master ports  
    output logic [      MP-1:0]       tcdm_req_o          ,
    input  logic [      MP-1:0]       tcdm_gnt_i          ,
    output logic [      MP-1:0][31:0] tcdm_add_o          ,
    output logic [      MP-1:0]       tcdm_wen_o          ,
    output logic [      MP-1:0][ 3:0] tcdm_be_o           ,
    output logic [      MP-1:0][31:0] tcdm_data_o         ,
    output logic [      MP-1:0]       tcdm_r_ready_o      ,
    output logic [      MP-1:0][ 7:0] tcdm_id_o           ,    
    input  logic [      MP-1:0][31:0] tcdm_r_data_i       ,
    input  logic [      MP-1:0]       tcdm_r_valid_i      ,
    input  logic                      tcdm_r_opc_i        ,
    input  logic                      tcdm_r_user_i       ,
    input  logic               [ 7:0] tcdm_r_id_i         ,
    // periph slave port  
    input  logic                      periph_req_i        ,
    output logic                      periph_gnt_o        ,
    input  logic [        31:0]       periph_add_i        ,
    input  logic                      periph_wen_i        ,
    input  logic [         3:0]       periph_be_i         ,
    input  logic [        31:0]       periph_data_i       ,
    input  logic [ID_WIDTH-1:0]       periph_id_i         ,
    output logic [        31:0]       periph_r_data_o     ,
    output logic                      periph_r_valid_o    ,
    output logic [ID_WIDTH-1:0]       periph_r_id_o
);

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT);

    localparam hci_package::hci_size_parameter_t `HCI_SIZE_PARAM(tcdm) = '{
      DW:  DW,
      AW:  hci_package::DEFAULT_AW,
      BW:  hci_package::DEFAULT_BW,
      UW:  hci_package::DEFAULT_UW,
      IW:  hci_package::DEFAULT_IW,
      EW:  hci_package::DEFAULT_EW,
      EHW: hci_package::DEFAULT_EHW
    };
    `HCI_INTF(tcdm, clk_i);

    hwpe_ctrl_intf_periph #(.ID_WIDTH(ID_WIDTH)) periph (.clk(clk_i));

    logic busy;
    logic [N_CORES-1:0][1:0] evt;

    `ifndef SYNTHESIS
        for(genvar ii=0; ii<MP; ii++) begin: gen_tcdm_binding
            assign tcdm_req_o       [ii] = tcdm.req;
            assign tcdm_add_o       [ii] = tcdm.add + ii*4;
            assign tcdm_wen_o       [ii] = tcdm.wen;
            assign tcdm_be_o        [ii] = tcdm.be[(ii+1)*4-1:ii*4];
            assign tcdm_data_o      [ii] = tcdm.data[(ii+1)*32-1:ii*32];
            assign tcdm_r_ready_o   [ii] = tcdm.r_ready;
            assign tcdm_id_o        [ii] = tcdm.id;
        end

        assign tcdm.gnt     = &(tcdm_gnt_i);
        assign tcdm.r_valid = &(tcdm_r_valid_i);
        assign tcdm.r_data  = { >> {tcdm_r_data_i} };
        assign tcdm.r_opc   = tcdm_r_opc_i;
        assign tcdm.r_user  = tcdm_r_user_i;
        assign tcdm.r_id    = tcdm_r_id_i;

        assign periph.req       = periph_req_i;
        assign periph.add       = periph_add_i;
        assign periph.wen       = periph_wen_i;
        assign periph.be        = periph_be_i;
        assign periph.data      = periph_data_i;
        assign periph.id        = periph_id_i;
        assign periph_gnt_o     = periph.gnt;
        assign periph_r_data_o  = periph.r_data;
        assign periph_r_valid_o = periph.r_valid;
        assign periph_r_id_o    = periph.r_id;

        assign busy_o   = busy;
        assign evt_o    = evt;
    `else
        always_ff @(posedge clk_i, negedge rst_ni) begin
            if (~rst_ni) begin
                // TCDM port
                for (int ii = 0; ii < MP; ii++) begin
                    tcdm_req_o      [ii] <= '0;
                    tcdm_add_o      [ii] <= '0;
                    tcdm_wen_o      [ii] <= '0;
                    tcdm_be_o       [ii] <= '0;
                    tcdm_data_o     [ii] <= '0;
                    tcdm_r_ready_o  [ii] <= '0;
                    tcdm_id_o       [ii] <= '0;
                end

                tcdm.gnt     <= '0;
                tcdm.r_valid <= '0;
                tcdm.r_data  <= '0;
                tcdm.r_opc   <= '0;
                tcdm.r_user  <= '0;
                tcdm.r_id    <= '0;

                // Control port
                periph.req     <= '0;
                periph.add     <= '0;
                periph.wen     <= '0;
                periph.be      <= '0;
                periph.data    <= '0;
                periph.id      <= '0;
                periph_gnt_o     <= '0;
                periph_r_data_o  <= '0;
                periph_r_valid_o <= '0;
                periph_r_id_o    <= '0;

                // Other
                busy_o           <= '0;
                evt_o            <= '0;
            end else begin
                // TCDM port
                for (int ii = 0; ii < MP; ii++) begin
                    tcdm_req_o       [ii] <= tcdm.req;
                    tcdm_add_o       [ii] <= tcdm.add + ii*4;
                    tcdm_wen_o       [ii] <= tcdm.wen;
                    tcdm_be_o        [ii] <= tcdm.be[ii*4+:4];
                    tcdm_data_o      [ii] <= tcdm.data[ii*32+:32];
                    tcdm_r_ready_o   [ii] <= tcdm.r_ready;
                    tcdm_id_o        [ii] <= tcdm.id;
                end

                tcdm.gnt     <= &(tcdm_gnt_i);
                tcdm.r_valid <= &(tcdm_r_valid_i);
                tcdm.r_data  <= { >> {tcdm_r_data_i} };
                tcdm.r_opc   <= tcdm_r_opc_i;
                tcdm.r_user  <= tcdm_r_user_i;
                tcdm.r_id    <= tcdm_r_id_i;

                // Control port
                periph.req     <= periph_req_i;
                periph.add     <= periph_add_i;
                periph.wen     <= periph_wen_i;
                periph.be      <= periph_be_i;
                periph.data    <= periph_data_i;
                periph.id      <= periph_id_i;
                periph_gnt_o     <= periph.gnt;
                periph_r_data_o  <= periph.r_data;
                periph_r_valid_o <= periph.r_valid;
                periph_r_id_o    <= periph.r_id;
                
                // Other
                busy_o           <= busy;
                evt_o            <= evt;
            end
        end
    `endif

    softex_top #(
        .FPFORMAT   (   FPFORMAT    ),
        .N_CORES    (   N_CORES     ),
        .`HCI_SIZE_PARAM(Tcdm) ( HCI_SIZE_tcdm )
    ) i_top (
        .clk_i  (   clk_i   ),
        .rst_ni (   rst_ni  ),
        .busy_o (   busy    ),
        .evt_o  (   evt     ),
        .tcdm   (   tcdm    ),
        .periph (   periph  ) 
    );

endmodule
