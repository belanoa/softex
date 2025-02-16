// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

timeunit 1ps;
timeprecision 1ps;

module softex_tb;
    parameter real          PROB_STALL = 0.0;
    parameter int unsigned  NC = 1;
    parameter int unsigned  ID = 10;
    parameter int unsigned  DW = 128 + 32;
    parameter int unsigned  MP = DW/32;
    parameter int unsigned  MEMORY_SIZE = 192*1024;
    parameter int unsigned  STACK_MEMORY_SIZE = 192*1024;
    parameter int unsigned  PULP_XPULP = 1;
    parameter int unsigned  FPU = 0;
    parameter int unsigned  PULP_ZFINX = 0;
    parameter logic [31:0]  BASE_ADDR = 32'h1c000000;
    parameter logic [31:0]  STACK_BASE_ADDR = 32'h1c040000;
    parameter logic [31:0]  HWPE_ADDR_BASE_BIT = 20;
    parameter string        STIM_INSTR = "./stim_instr.txt";
    parameter string        STIM_DATA  = "./stim_data.txt";
    parameter int unsigned  OUTPUT_SIZE = 2;
    parameter int unsigned  USE_ECC = 0;
    parameter int unsigned  EW = (USE_ECC) ? 43 : 1; // 35 data check-bit + 8 meta check-bit

    logic clk;
    logic rst_n;
    logic test_mode;
    logic fetch_enable;
    logic busy;
    logic [31:0] core_boot_addr;

    hwpe_stream_intf_tcdm instr[0:0]  (.clk(clk));
    hwpe_stream_intf_tcdm stack[0:0]  (.clk(clk));
    hwpe_stream_intf_tcdm tcdm [MP:0] (.clk(clk));

    logic [NC-1:0][1:0] evt;

    logic [MP-1:0]       tcdm_req;
    logic [MP-1:0]       tcdm_gnt;
    logic [MP-1:0][31:0] tcdm_add;
    logic [MP-1:0]       tcdm_wen;
    logic [MP-1:0][3:0]  tcdm_be;
    logic [MP-1:0][31:0] tcdm_data;
    logic [MP-1:0]       tcdm_r_ready;
    logic [EW-1:0]       tcdm_ecc;
    logic [MP-1:0] [7:0] tcdm_id;
    logic [MP-1:0][31:0] tcdm_r_data;
    logic [MP-1:0]       tcdm_r_valid;
    logic                tcdm_r_opc;
    logic                tcdm_r_user;
    logic          [7:0] tcdm_r_id;
    logic [EW-1:0]       tcdm_r_ecc;

    logic          periph_req;
    logic          periph_gnt;
    logic [31:0]   periph_add;
    logic          periph_wen;
    logic [3:0]    periph_be;
    logic [31:0]   periph_data;
    logic [ID-1:0] periph_id;
    logic [31:0]   periph_r_data;
    logic          periph_r_valid;
    logic [ID-1:0] periph_r_id;

    logic          instr_req;
    logic          instr_gnt;
    logic          instr_rvalid;
    logic [31:0]   instr_addr;
    logic [31:0]   instr_rdata;

    logic          data_req;
    logic          data_gnt;
    logic          data_rvalid;
    logic          data_we;
    logic [3:0]    data_be;
    logic [31:0]   data_addr;
    logic [31:0]   data_wdata;
    logic [31:0]   data_rdata;
    logic          data_err;
    logic          core_sleep;

    // ATI timing parameters.
    localparam TCP = 1.0ns; // clock period, 1 GHz clock
    localparam TA  = 0.2ns; // application time
    localparam TT  = 0.8ns; // test time

    // Performs one entire clock cycle.
    task cycle;
        clk <= #(TCP/2) 0;
        clk <= #TCP 1;
        #TCP;
    endtask

    // bindings
    always_comb
    begin : bind_periph
        periph_req  = data_req & data_addr[HWPE_ADDR_BASE_BIT];
        periph_add  = data_addr;
        periph_wen  = ~data_we;
        periph_be   = data_be;
        periph_data = data_wdata;
        periph_id   = '0;
    end
    
    always_comb
    begin : bind_instrs
        instr[0].req  = instr_req;
        instr[0].add  = instr_addr;
        instr[0].wen  = 1'b1;
        instr[0].be   = '0;
        instr[0].data = '0;
        instr_gnt    = instr[0].gnt;
        instr_rdata  = instr[0].r_data;
        instr_rvalid = instr[0].r_valid;
    end
    
    always_comb
    begin : bind_stack
        stack[0].req  = data_req & (data_addr [31 -: 12] == 12'h1c0) & (data_addr [19 -: 2] == 2'b01);
        stack[0].add  = data_addr;
        stack[0].wen  = ~data_we;
        stack[0].be   = data_be;
        stack[0].data = data_wdata;
    end
    
    logic other_r_valid;
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            other_r_valid <= '0;
        else
            other_r_valid <= data_req & (data_addr[31:24] == 8'h80);
    end

    for(genvar ii=0; ii<MP; ii++) begin : tcdm_binding
        assign tcdm[ii].req     = tcdm_req     [ii];
        assign tcdm[ii].add     = tcdm_add     [ii];
        assign tcdm[ii].wen     = tcdm_wen     [ii];
        assign tcdm[ii].be      = tcdm_be      [ii];
        if (~USE_ECC)
            assign tcdm[ii].data = tcdm_data    [ii];
        //assign tcdm[ii].r_ready = tcdm_r_ready [ii];
        //assign tcdm[ii].id      = tcdm_id      [ii];
        assign tcdm_gnt     [ii] = tcdm[ii].gnt;
        assign tcdm_r_data  [ii] = tcdm[ii].r_data;
        assign tcdm_r_valid [ii] = tcdm[ii].r_valid;
    end

    assign tcdm[MP].req     = data_req & (data_addr[31:24] != '0) & (data_addr[31:24] != 8'h80) & ~data_addr[HWPE_ADDR_BASE_BIT];
    assign tcdm[MP].add     = data_addr;
    assign tcdm[MP].wen     = ~data_we;
    assign tcdm[MP].be      = data_be;
    assign tcdm[MP].data    = data_wdata;
    //assign tcdm[MP].r_ready = '1;
    //assign tcdm[MP].id      = '0;
    assign tcdm_r_opc   = 0;
    assign tcdm_r_user  = 0;
    assign tcdm_r_id    = tcdm_id [0];
    assign data_gnt    = periph_req ?
                         periph_gnt : stack[0].req ?
                                      stack[0].gnt : tcdm[MP].req ?
                                                     tcdm[MP].gnt : '1;

    assign data_rdata  = periph_r_valid ? periph_r_data  :
                                          stack[0].r_valid ? stack[0].r_data  :
                                                             tcdm[MP].r_valid ? tcdm[MP].r_data : '0;

    assign data_rvalid = periph_r_valid   |
                         stack[0].r_valid |
                         tcdm[MP].r_valid |
                         other_r_valid    ;

    if (USE_ECC) begin : gen_ecc_dec_enc
        logic [MP-1:0][1:0] err_on_data;
        // REQUEST PHASE DECODING PAYLOAD ONLY
        for(genvar ii=0; ii<MP; ii++) begin : data_decoding
            hsiao_ecc_dec #(
                .DataWidth ( 32 )
            ) i_data_dec (
                .in         ( { tcdm_ecc[(ii+1)*7-1+8:ii*7+8], tcdm_data[ii] } ),
                .out        ( tcdm[ii].data ),
                .syndrome_o ( ),
                .err_o      (err_on_data[ii])
            );
        end

        // RESPONSE PHASE ENCODING
        logic [MP-1:0][38:0] tcdm_r_data_enc;
        for(genvar ii=0; ii<MP; ii++) begin : r_data_encoding
            hsiao_ecc_enc #(
                .DataWidth ( 32 )
            ) i_r_data_enc (
                .in  (tcdm[ii].r_data),
                .out (tcdm_r_data_enc[ii])
            );
            assign tcdm_r_ecc[(ii+1)*7-1:ii*7] = tcdm_r_data_enc[ii][38:32];
        end
        assign tcdm_r_ecc[EW-1:(7*MP)] = '0;
    end else begin : gen_no_r_ecc
        assign tcdm_r_ecc = '0;
    end

    softex_wrap #(
        .ID_WIDTH           ( ID                 ),
        .N_CORES            ( NC                 ),
        .DW                 ( DW                 ),
        .EW                 ( EW                 ),
        .MP                 ( MP                 )
    ) i_softex_wrap      (
        .clk_i              ( clk                ),
        .rst_ni             ( rst_n              ),
        .test_mode_i        ( test_mode          ),
        .evt_o              ( evt                ),
        .busy_o             ( busy               ),
        .tcdm_req_o         ( tcdm_req           ),
        .tcdm_add_o         ( tcdm_add           ),
        .tcdm_wen_o         ( tcdm_wen           ),
        .tcdm_be_o          ( tcdm_be            ),
        .tcdm_data_o        ( tcdm_data          ),
        .tcdm_r_ready_o     ( tcdm_r_ready       ),
        .tcdm_ecc_o         ( tcdm_ecc           ),
        .tcdm_id_o          ( tcdm_id            ),
        .tcdm_gnt_i         ( tcdm_gnt           ),
        .tcdm_r_data_i      ( tcdm_r_data        ),
        .tcdm_r_valid_i     ( tcdm_r_valid       ),
        .tcdm_r_opc_i       ( tcdm_r_opc         ),
        .tcdm_r_user_i      ( tcdm_r_user        ),
        .tcdm_r_id_i        ( tcdm_r_id          ),
        .tcdm_r_ecc_i       ( tcdm_r_ecc         ),
        .periph_req_i       ( periph_req         ),
        .periph_gnt_o       ( periph_gnt         ),
        .periph_add_i       ( periph_add         ),
        .periph_wen_i       ( periph_wen         ),
        .periph_be_i        ( periph_be          ),
        .periph_data_i      ( periph_data        ),
        .periph_id_i        ( periph_id          ),
        .periph_r_data_o    ( periph_r_data      ),
        .periph_r_valid_o   ( periph_r_valid     ),
        .periph_r_id_o      ( periph_r_id        )
    );

    tb_dummy_memory  #(
        .MP             ( MP + 1        ),
        .MEMORY_SIZE    ( MEMORY_SIZE   ),
        .BASE_ADDR      ( 32'h1c010000  ),
        .PROB_STALL     ( PROB_STALL    ),
        .TCP            ( TCP           ),
        .TA             ( TA            ),
        .TT             ( TT            )
    ) i_dummy_dmemory (
        .clk_i          ( clk           ),
        .rst_ni         ( rst_n         ),
        .clk_delayed_i  ( '0            ),
        .randomize_i    ( 1'b0          ),
        .enable_i       ( 1'b1          ),
        .stallable_i    ( 1'b1          ),
        .tcdm           ( tcdm          )
    );

    tb_dummy_memory  #(
        .MP             ( 1           ),
        .MEMORY_SIZE    ( MEMORY_SIZE ),
        .BASE_ADDR      ( BASE_ADDR   ),
        .PROB_STALL     ( 0           ),
        .TCP            ( TCP         ),
        .TA             ( TA          ),
        .TT             ( TT          )
    ) i_dummy_imemory (
        .clk_i          ( clk         ),
        .rst_ni         ( rst_n       ),
        .clk_delayed_i  ( '0          ),
        .randomize_i    ( 1'b0        ),
        .enable_i       ( 1'b1        ),
        .stallable_i    ( 1'b0        ),
        .tcdm           ( instr       )
    );

    tb_dummy_memory       #(
        .MP                  ( 1                 ),
        .MEMORY_SIZE         ( STACK_MEMORY_SIZE ),
        .BASE_ADDR           ( STACK_BASE_ADDR   ),
        .PROB_STALL          ( 0                 ),
        .TCP                 ( TCP               ),
        .TA                  ( TA                ),
        .TT                  ( TT                )
    ) i_dummy_stack_memory (
        .clk_i               ( clk               ),
        .rst_ni              ( rst_n             ),
        .clk_delayed_i       ( '0                ),
        .randomize_i         ( 1'b0              ),
        .enable_i            ( 1'b1              ),
        .stallable_i         ( 1'b0              ),
        .tcdm                ( stack             )
    );

    ibex_core #(

    ) i_ibex_core (

         // Clock and Reset
        .clk_i              (   clk                         ),
        .rst_ni             (   rst_n                       ),

        .test_en_i          (   '0                          ),     // enable all clock gates for testing

        .hart_id_i          (   '0                          ),
        .boot_addr_i        (   core_boot_addr              ),

        // Instruction memory interface
        .instr_req_o        (   instr_req                   ),

        .instr_gnt_i        (   instr_gnt                   ),
        .instr_rvalid_i     (   instr_rvalid                ),
        .instr_addr_o       (   instr_addr                  ),
        .instr_rdata_i      (   instr_rdata                 ),
        .instr_err_i        (   '0                          ),

        // Data memory interface
        .data_req_o         (   data_req                    ),
        .data_gnt_i         (   data_gnt                    ),
        .data_rvalid_i      (   data_rvalid                 ),
        .data_we_o          (   data_we                     ),
        .data_be_o          (   data_be                     ),
        .data_addr_o        (   data_addr                   ),
        .data_wdata_o       (   data_wdata                  ),
        .data_rdata_i       (   data_rdata                  ),
        .data_err_i         (   '0                          ),

        // Interrupt inputs
        .irq_software_i     (   '0                          ),
        .irq_timer_i        (   '0                          ),
        .irq_external_i     (   '0                          ),
        .irq_fast_i         (   '0                          ),
        .irq_nm_i           (   '0                          ),       // non-maskeable interrupt
        .irq_x_i            (   {28'd0, evt[0][0], 3'd0}    ),
        .irq_x_ack_o        (                               ),
        .irq_x_ack_id_o     (                               ),

        // External performance counters
        .external_perf_i    (   '0                          ), // Bind to zero if unused

        // Debug Interface
        .debug_req_i        (   '0                          ),

        // CPU Control Signals
        .fetch_enable_i     (   fetch_enable                ),
        .alert_minor_o      (                               ),
        .alert_major_o      (                               ),
        .core_sleep_o       (   core_sleep                  )
    );
    

    initial begin
        clk <= 1'b0;
        rst_n <= 1'b0;
        core_boot_addr = 32'h0;

        for (int i = 0; i < 20; i++)
            cycle();
        
        rst_n <= #TA 1'b1;
        core_boot_addr = 32'h1C000000;

        for (int i = 0; i < 10; i++)
            cycle();
        
        rst_n <= #TA 1'b0;

        for (int i = 0; i < 10; i++)
            cycle();

        rst_n <= #TA 1'b1;

        while(1) begin
            cycle();
        end
    end
  
    int f_golden;

    logic done = 0;

    always_ff @(posedge clk)
    begin
        if((data_addr == 32'h80000000 ) && (data_we & data_req == 1'b1)) begin
            done = 1;
        end
    end

    int unsigned error_threshold = 3;

    initial begin
        integer id;
        int cnt_rd, cnt_wr;

        int unsigned pos, n, data, difference, errors, tot_err_ulp;

        test_mode = 1'b0;
        fetch_enable = 1'b0;

        // load instruction memory
        $readmemh(STIM_INSTR, softex_tb.i_dummy_imemory.memory);
        $readmemh(STIM_DATA,  softex_tb.i_dummy_dmemory.memory);

        #(100*TCP);
        fetch_enable = 1'b1;

        #(100*TCP);
        
        while(~core_sleep || ~done)
            #(TCP);

        cnt_rd = softex_tb.i_dummy_dmemory.cnt_rd[0] + softex_tb.i_dummy_dmemory.cnt_rd[1] + softex_tb.i_dummy_dmemory.cnt_rd[2] + softex_tb.i_dummy_dmemory.cnt_rd[3] + softex_tb.i_dummy_dmemory.cnt_rd[4] + softex_tb.i_dummy_dmemory.cnt_rd[5] + softex_tb.i_dummy_dmemory.cnt_rd[6] + softex_tb.i_dummy_dmemory.cnt_rd[7] + softex_tb.i_dummy_dmemory.cnt_rd[8];
        cnt_wr = softex_tb.i_dummy_dmemory.cnt_wr[0] + softex_tb.i_dummy_dmemory.cnt_wr[1] + softex_tb.i_dummy_dmemory.cnt_wr[2] + softex_tb.i_dummy_dmemory.cnt_wr[3] + softex_tb.i_dummy_dmemory.cnt_wr[4] + softex_tb.i_dummy_dmemory.cnt_wr[5] + softex_tb.i_dummy_dmemory.cnt_wr[6] + softex_tb.i_dummy_dmemory.cnt_wr[7] + softex_tb.i_dummy_dmemory.cnt_wr[8];
        
        $display("[TB] - cnt_rd=%-8d", cnt_rd);
        $display("[TB] - cnt_wr=%-8d", cnt_wr);

        f_golden = $fopen("golden-model/golden.txt", "r");

        errors = 0;
        tot_err_ulp = 0;

        pos = 0;

        while ($fscanf(f_golden, "%d", n) == 1) begin
            data = ((softex_tb.i_dummy_dmemory.memory[pos >> $clog2(4/OUTPUT_SIZE)] >> (8 * OUTPUT_SIZE * pos[$clog2(4/OUTPUT_SIZE)-1:0])) & (2**(8*OUTPUT_SIZE)-1)/*'h000000FF*/);

            difference = n > data ? n - data : data - n;

            tot_err_ulp += difference;

            if (difference > error_threshold) begin
                errors += 1;

                $error("[TB] - Mismatch!    Expected: 0x%h\tWas: 0x%h\tPosition: %d\tDifference: %d", n, data, pos, difference);
            end

            pos += 1;
        end

        $display("[TB] - Errors: %d", errors);

        $display("[TB] - Average Absolute Error in ULPs: %f", real'(tot_err_ulp) / real'(pos));

        $finish;
    end

endmodule