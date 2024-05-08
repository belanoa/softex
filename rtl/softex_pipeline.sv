// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import softex_pkg::*;

module softex_pipeline #(
    parameter softex_pkg::regs_config_t REG_POS                 = DEFAULT_REG_POS   ,
    parameter int unsigned              NUM_REGS                = 0                 ,
    parameter int unsigned              WIDTH_IN                = 1                 ,
    parameter int unsigned              NUM_IN                  = 1                 ,
    parameter int unsigned              WIDTH_OUT               = WIDTH_IN          ,
    parameter int unsigned              NUM_OUT                 = NUM_IN            
) (
    input   logic                                       clk_i       ,
    input   logic                                       rst_ni      ,
    input   logic                                       enable_i    ,
    input   logic                                       clear_i     ,
    input   logic                                       valid_i     ,
    input   logic                                       ready_i     ,
    output  logic                                       valid_o     ,
    output  logic                                       ready_o     ,

    input   logic [NUM_IN - 1 : 0] [WIDTH_IN - 1 : 0]   i_data_i    ,
    output  logic [NUM_IN - 1 : 0] [WIDTH_IN - 1 : 0]   i_data_o    ,
    input   logic [NUM_OUT - 1 : 0] [WIDTH_OUT - 1 : 0] o_data_i    ,
    output  logic [NUM_OUT - 1 : 0] [WIDTH_OUT - 1 : 0] o_data_o    ,

    input   logic [NUM_IN - 1 : 0]                      i_strb_i    ,
    output  logic [NUM_IN - 1 : 0]                      i_strb_o    ,
    input   logic [NUM_OUT - 1 : 0]                     o_strb_i    ,
    output  logic [NUM_OUT - 1 : 0]                     o_strb_o    
);

    /*  This module is intended to be used to pipeline 
     *  a combinatorial block.
     *
     *          i_data_i
     *             ||
     *             \/       
     *  +-----------------------+
     *  |   i_data_registers    |
     *  +-----------------------+
     *             ||
     *             \/
     *          i_data_o
     *             ||
     *             \/
     *        COMBINATORIAL
     *           LOGIC
     *             ||
     *             \/
     *          o_data_i
     *             ||
     *             \/
     *  +-----------------------+
     *  |   o_data_registers    |
     *  +-----------------------+
     *             ||
     *             \/
     *          o_data_o
     */

    localparam int unsigned NUM_REGS_I  = (REG_POS == softex_pkg::AROUND) ? (NUM_REGS / 2) : ((REG_POS == softex_pkg::BEFORE) ? NUM_REGS : 0);
    localparam int unsigned NUM_REGS_O  = (REG_POS == softex_pkg::AROUND) ? (NUM_REGS - NUM_REGS / 2) : ((REG_POS == softex_pkg::BEFORE) ? 0 : NUM_REGS);

    logic [NUM_REGS_I : 0] [NUM_IN - 1 : 0] [WIDTH_IN - 1 : 0]    i_data;
    logic [NUM_REGS_O : 0] [NUM_OUT - 1 : 0] [WIDTH_OUT - 1 : 0]  o_data;

    logic [NUM_REGS_I : 0] [NUM_IN - 1 : 0]   i_strb;
    logic [NUM_REGS_O : 0] [NUM_OUT - 1 : 0]  o_strb;

    logic [NUM_IN - 1 : 0] [NUM_REGS_I - 1 : 0]   i_row_enable;
    logic [NUM_OUT - 1 : 0] [NUM_REGS_O - 1 : 0]  o_row_enable;

    logic [NUM_REGS : 0]    valid_reg;

    logic [NUM_REGS : 0]    reg_en_n;


    assign ready_o  = ~reg_en_n [0] & enable_i;

    for (genvar i = 0; i < NUM_REGS; i++) begin : reg_enable_assignment
        assign reg_en_n [i] = reg_en_n [i + 1] & valid_reg [i + 1];
    end
    assign reg_en_n [NUM_REGS] = ~ready_i;


    assign valid_reg [0]    = valid_i;
    for (genvar i = 0; i < NUM_REGS; i++) begin : valid_registers
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (~rst_ni) begin
                valid_reg [i + 1] <= '0;
            end else begin
                if (clear_i) begin
                    valid_reg [i + 1] <= '0;
                end else if (enable_i & ~reg_en_n [i]) begin
                    valid_reg [i + 1] <= valid_reg [i];
                end
            end
        end
    end
    assign valid_o  = valid_reg [NUM_REGS];


    always_comb begin : i_row_enable_assignment
        for (int i = 0; i < NUM_IN; i++) begin
            for (int j = 0; j < NUM_REGS_I; j++) begin
                i_row_enable [i][j]   = enable_i & ~reg_en_n [j] & i_strb [j][i] & valid_reg [j];
            end
        end
    end

    always_comb begin : o_row_enable_assignment
        for (int i = 0; i < NUM_OUT; i++) begin
            for (int j = 0; j < NUM_REGS_O; j++) begin
                o_row_enable [i][j]   = enable_i & ~reg_en_n [j + NUM_REGS_I] & o_strb [j + NUM_REGS_I][i] & valid_reg [j + NUM_REGS_I];
            end
        end
    end


    assign i_strb [0] = i_strb_i;
    for (genvar i = 0; i < NUM_REGS_I; i++) begin : i_strb_registers
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (~rst_ni) begin
                i_strb [i + 1] <= '0;
            end else begin
                if (clear_i) begin
                    i_strb [i + 1] <= '0;
                end else if (enable_i & ~reg_en_n [i]) begin
                    i_strb [i + 1] <= i_strb [i];
                end
            end
        end
    end
    assign i_strb_o = i_strb [NUM_REGS_I];

    assign o_strb [0] = o_strb_i;
    for (genvar i = 0; i < NUM_REGS_O; i++) begin : o_strb_registers
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (~rst_ni) begin
                o_strb [i + 1] <= '0;
            end else begin
                if (clear_i) begin
                    o_strb [i + 1] <= '0;
                end else if (enable_i & ~reg_en_n [i]) begin
                    o_strb [i + 1] <= o_strb [i];
                end
            end
        end
    end
    assign o_strb_o = o_strb [NUM_REGS_O];


    assign i_data [0] = i_data_i;
    for (genvar i = 0; i < NUM_IN; i++) begin : i_data_registers
        for (genvar j = 0; j < NUM_REGS_I; j++) begin
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (~rst_ni) begin
                    i_data [j + 1][i] <= '0;
                end else begin
                    if (clear_i) begin
                        i_data [j + 1][i] <= '0;
                    end else if (i_row_enable [i][j]) begin
                        i_data [j + 1][i] <=  i_data [j][i];
                    end
                end
            end
        end
    end
    assign i_data_o = i_data [NUM_REGS_I];

    assign o_data [0] = o_data_i;
    for (genvar i = 0; i < NUM_OUT; i++) begin : o_data_registers
        for (genvar j = 0; j < NUM_REGS_O; j++) begin
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (~rst_ni) begin
                    o_data [j + 1][i] <= '0;
                end else begin
                    if (clear_i) begin
                        o_data [j + 1][i] <= '0;
                    end else if (o_row_enable [i][j]) begin
                        o_data [j + 1][i] <=  o_data [j][i];
                    end
                end
            end
        end
    end
    assign o_data_o = o_data [NUM_REGS_O];

endmodule