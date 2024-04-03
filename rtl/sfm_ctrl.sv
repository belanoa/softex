import hci_package::*;
import hwpe_stream_package::*;
import sfm_pkg::*;

module sfm_ctrl #(
    parameter int unsigned  N_CORES     = 1     ,
    parameter int unsigned  N_CONTEXT   = 2     ,
    parameter int unsigned  IO_REGS     = 4     ,
    parameter int unsigned  ID_WIDTH    = 8     ,
    parameter int unsigned  DATA_WIDTH  = 128   
) (
    input   logic                           clk_i               ,
    input   logic                           rst_ni              ,
    input   logic                           enable_i            ,
    input   hci_streamer_flags_t            in_stream_flags_i   ,
    input   hci_streamer_flags_t            out_stream_flags_i  ,
    input   sfm_pkg::datapath_flags_t       datapath_flgs_i     ,
    output  logic                           clear_o             ,
    output  logic                           busy_o              ,
    output  logic [N_CORES - 1 : 0] [1 : 0] evt_o               ,
    output  hci_streamer_ctrl_t             in_stream_ctrl_o    ,
    output  hci_streamer_ctrl_t             out_stream_ctrl_o   ,
    output  sfm_pkg::datapath_ctrl_t        datapath_ctrl_o     ,

    hwpe_ctrl_intf_periph.slave             periph
);

    typedef enum logic [2:0] {
        IDLE,
        ACCUMULATION,
        WAIT_DATAPATH_EMPTY,
        WAIT_ACCUMULATION,
        DIVIDING,
        FINISHED
    } sfm_state_t;

    sfm_state_t current_state,
                next_state;

    logic   in_start,
            out_start;

    logic   dp_acc_finished,
            dp_dividing;

    logic   clear;

    hwpe_ctrl_package::ctrl_regfile_t   reg_file;
    hwpe_ctrl_package::ctrl_slave_t     ctrl_slave;
    hwpe_ctrl_package::flags_slave_t    flgs_slave;

    hwpe_ctrl_slave  #(
        //.REGFILE_SCM    (   0               ),
        .N_CORES        (   N_CORES         ),
        .N_CONTEXT      (   N_CONTEXT       ),
        .N_IO_REGS      (   IO_REGS         ),
        //.N_GENERIC_REGS (   6               ),
        .ID_WIDTH       (   ID_WIDTH        )
    ) i_slave (
        .clk_i      (   clk_i       ),
        .rst_ni     (   rst_ni      ),
        .clear_o    (   clear       ),
        .cfg        (   periph      ),
        .ctrl_i     (   ctrl_slave  ),
        .flags_o    (   flgs_slave  ),
        .reg_file   (   reg_file    )
    );
    

    always_ff @(posedge clk_i or negedge rst_ni) begin : state_register
        if (~rst_ni) begin
            current_state <= IDLE;
        end else begin
            if (clear) begin
                current_state <= IDLE;
            end else begin
                current_state <= next_state;
            end
        end
    end

    assign in_stream_ctrl_o.req_start                       = in_start;
    assign in_stream_ctrl_o.addressgen_ctrl.base_addr       = reg_file.hwpe_params [IN_ADDR];
    assign in_stream_ctrl_o.addressgen_ctrl.tot_len         = reg_file.hwpe_params [TOT_LEN];
    assign in_stream_ctrl_o.addressgen_ctrl.d0_len          = '1;
    assign in_stream_ctrl_o.addressgen_ctrl.d0_stride       = DATA_WIDTH / 8;
    assign in_stream_ctrl_o.addressgen_ctrl.d1_len          = '0;
    assign in_stream_ctrl_o.addressgen_ctrl.d1_stride       = '0;
    assign in_stream_ctrl_o.addressgen_ctrl.d2_stride       = '0;
    assign in_stream_ctrl_o.addressgen_ctrl.dim_enable_1h   = '0;

    assign out_stream_ctrl_o.req_start                      = out_start;
    assign out_stream_ctrl_o.addressgen_ctrl.base_addr      = reg_file.hwpe_params [OUT_ADDR];
    assign out_stream_ctrl_o.addressgen_ctrl.tot_len        = reg_file.hwpe_params [TOT_LEN];
    assign out_stream_ctrl_o.addressgen_ctrl.d0_len         = '1;
    assign out_stream_ctrl_o.addressgen_ctrl.d0_stride      = DATA_WIDTH / 8;
    assign out_stream_ctrl_o.addressgen_ctrl.d1_len         = '0;
    assign out_stream_ctrl_o.addressgen_ctrl.d1_stride      = '0;
    assign out_stream_ctrl_o.addressgen_ctrl.d2_stride      = '0;
    assign out_stream_ctrl_o.addressgen_ctrl.dim_enable_1h  = '0;

    assign datapath_ctrl_o.accumulator_ctrl.acc_finished    = dp_acc_finished;
    assign datapath_ctrl_o.dividing                         = dp_dividing;

    always_comb begin : ctrl_sfm
        next_state      = current_state;
        out_start       = '0;
        in_start        = '0;
        dp_acc_finished = '0;
        dp_dividing     = '0;
        ctrl_slave      = '0;
        busy_o          = '1;
        
        case (current_state)
            IDLE: begin
                busy_o = '0;

                if (flgs_slave.start) begin
                    next_state  = ACCUMULATION;
                    in_start    = '1;
                end
            end

            ACCUMULATION: begin
                if (in_stream_flags_i.done) begin
                    next_state      = WAIT_DATAPATH_EMPTY;
                end
            end

            WAIT_DATAPATH_EMPTY: begin
                if (~datapath_flgs_i.datapath_busy) begin
                    next_state      = WAIT_ACCUMULATION;
                    dp_acc_finished = '1;
                end
            end

            WAIT_ACCUMULATION: begin
                dp_acc_finished = '1;

                if (datapath_flgs_i.accumulator_flags.reducing) begin
                    dp_acc_finished = '0;
                    out_start       = '1;
                    in_start        = '1;

                    next_state      = DIVIDING;
                end
            end

            DIVIDING: begin
                dp_dividing = '1;

                if (out_stream_flags_i.done) begin
                    dp_dividing     = '0;
                    ctrl_slave.done = '1;
                    busy_o          = '0;
                    next_state      = FINISHED;
                end
            end

            FINISHED: begin
                busy_o = '0;

            end
        endcase
    end

    assign clear_o  = clear;

    assign  evt_o   = flgs_slave.evt;

endmodule