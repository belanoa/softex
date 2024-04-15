`include "../sfm_macros.svh"

module sfm_acc_datapath #(
    parameter fpnew_pkg::fp_format_e    ACC_FPFORMAT        = fpnew_pkg::FP32                   ,
    parameter fpnew_pkg::fp_format_e    ADD_FPFORMAT        = fpnew_pkg::FP32                   ,
    parameter fpnew_pkg::fp_format_e    MUL_FPFORMAT        = fpnew_pkg::FP16ALT                ,
    parameter int unsigned              NUM_REGS_FMA        = 3                                 , 
    parameter int unsigned              FACTOR_FIFO_DEPTH   = 4                                 ,
    parameter int unsigned              ADDEND_FIFO_DEPTH   = NUM_REGS_FMA * FACTOR_FIFO_DEPTH  ,
    parameter int unsigned              N_FACT_FIFO         = 1                                 ,  
    parameter fpnew_pkg::roundmode_e    ROUND_MODE          = fpnew_pkg::RNE                    ,

    localparam int unsigned ACC_WIDTH   = fpnew_pkg::fp_width(ACC_FPFORMAT),
    localparam int unsigned ADD_WIDTH   = fpnew_pkg::fp_width(ADD_FPFORMAT),
    localparam int unsigned MUL_WIDTH   = fpnew_pkg::fp_width(MUL_FPFORMAT)
) (
    input   logic                           clk_i       ,
    input   logic                           rst_ni      ,
    input   logic                           clear_i     ,
    input   sfm_pkg::acc_datapath_ctrl_t    ctrl_i      ,
    input   logic                           add_valid_i ,
    input   logic [ADD_WIDTH - 1 : 0]       add_i       ,
    input   logic                           mul_valid_i ,
    input   logic [MUL_WIDTH - 1 : 0]       mul_i       ,
    output  logic                           ready_o     ,
    output  logic                           valid_o     ,
    output  sfm_pkg::acc_datapath_flags_t   flags_o     ,
    output  logic [ACC_WIDTH - 1 : 0]       acc_o    
);

    typedef struct packed {
        logic [MUL_WIDTH - 1 : 0]               value;
        logic [$clog2(NUM_REGS_FMA) - 1 : 0]    tag;
        logic [$clog2(NUM_REGS_FMA) - 1 : 0]    uses;
    } factor_t;

    typedef struct packed {
        logic [ADD_WIDTH - 1 : 0]           value;
        logic [$clog2(NUM_REGS_FMA) - 1: 0] tag;
    } addend_t;

    logic [$clog2(NUM_REGS_FMA) - 1 : 0] op_in_flight_cnt;
    logic   op_cnt_enable_inc,
            op_cnt_enable_dec;

    logic [$clog2(NUM_REGS_FMA) - 1: 0] tag_cnt;
    logic tag_cnt_enable;

    logic [ACC_WIDTH - 1 : 0]   den_q;

    logic   inv_appr_valid,
            inv_appr_enable;

    logic [ACC_WIDTH - 1 : 0]   inv_appr,
                                inv_appr_d,
                                inv_appr_q;


    //Addend FIFO Signals
    addend_t    addend,
                i_addend;
    logic       addend_pop,
                addend_push,
                addend_match;

    logic       addend_full,
                addend_empty;

    //Factor FIFO Signals
    factor_t                                factor;
    factor_t                                i_factor;

    logic                                   factor_pop,
                                            factor_push;

    logic                                   factor_full,
                                            factor_empty,
                                            factor_match;

    logic [$clog2(NUM_REGS_FMA) - 1 : 0]    factor_uses_cnt;
    logic                                   factor_uses_cnt_enable;

    
    //FMA Signals
    fpnew_pkg::operation_e                  fma_operation;

    logic                                   fma_i_valid,
                                            fma_i_ready,
                                            fma_o_valid,
                                            fma_o_ready;

    logic [$clog2(NUM_REGS_FMA) - 1 : 0]    fma_i_tag,
                                            fma_o_tag;

    logic [ADD_WIDTH - 1 : 0]               fma_addend_pre_cast;

    logic [ACC_WIDTH - 1 : 0]               fma_factor;
    logic [ACC_WIDTH - 1 : 0]               fma_addend;

    logic [3 * ACC_WIDTH - 1 : 0]           fma_operands;
    
    logic [ACC_WIDTH - 1 : 0]               fma_res;

    assign op_cnt_enable_inc = addend_pop & ~fma_o_valid & op_in_flight_cnt != (NUM_REGS_FMA);
    assign op_cnt_enable_dec = ctrl_i.reducing & fma_i_valid;
    always_ff @(posedge clk_i or negedge rst_ni) begin : op_in_flight_counter
        if (~rst_ni) begin
            op_in_flight_cnt <= '0;
        end else begin
            if (clear_i) begin
                op_in_flight_cnt <= '0;
            end else if (op_cnt_enable_dec) begin
                op_in_flight_cnt <= op_in_flight_cnt - 1;
            end else if (op_cnt_enable_inc) begin
                op_in_flight_cnt <= op_in_flight_cnt + 1;
            end else begin
                op_in_flight_cnt <= op_in_flight_cnt;
            end
        end
    end

    assign tag_cnt_enable = factor_push;
    always_ff @(posedge clk_i or negedge rst_ni) begin : tag_counter
        if (~rst_ni) begin
            tag_cnt <= '0;
        end else begin
            if (clear_i) begin
                tag_cnt <= '0;
            end else if (tag_cnt_enable) begin
                tag_cnt <= tag_cnt + 1;
            end else begin
                tag_cnt <= tag_cnt;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : denominator_register
        if (~rst_ni) begin
            den_q <= '0;
        end else begin
            if (clear_i) begin
                den_q <= '0;
            end else if (ctrl_i.den_enable) begin
                den_q <= fma_res;
            end else begin
                den_q <= den_q;
            end
        end
    end

    assign inv_appr_enable  = inv_appr_valid | (fma_o_valid & ctrl_i.new_inv_iter);
    assign inv_appr_d       = inv_appr_valid ? inv_appr : fma_res;
    always_ff @(posedge clk_i or negedge rst_ni) begin : inverse_approximation_register
        if (~rst_ni) begin
            inv_appr_q <= '0;
        end else begin
            if (clear_i) begin
                inv_appr_q <= '0;
            end else if (ctrl_i.load_reciprocal) begin
                inv_appr_q <= ctrl_i.reciprocal;
            end else if (inv_appr_enable) begin
                inv_appr_q <= inv_appr_d;
            end else begin
                inv_appr_q <= inv_appr_q;
            end
        end
    end

    /*  Addends are first pushed into a FIFO and assigned a tag,            *
     *  a monothonically increasing number that represents their            *
     *  scaling factor (i.e., the partial maximum associated with them).    *
     *  An addend is popped if:                                             *
     *      - its tag matches the one of the FMA output                     *
     *      - it is the first operand                                       *
     *      - its tag is different from the one of the FMA output but       *
     *        its tag matches the one of the factor                         */

    assign addend_match = (factor_match ? ((fma_o_tag + 1'b1) == addend.tag) : (fma_o_tag == addend.tag)) & fma_o_valid & ~addend_empty;
    assign addend_pop   = (ctrl_i.reducing | ctrl_i.inverting) ? (addend_match & fma_o_valid) : (addend_match | (~fma_o_valid & ~addend_empty));
    assign addend_push  = (add_valid_i & ready_o) | (ctrl_i.push_fma_res & fma_o_valid);

    assign i_addend.value   =   ctrl_i.push_fma_res ? fma_res : add_i;
    assign i_addend.tag     =   tag_cnt_enable ? (tag_cnt + 1) : (tag_cnt);

    fifo_v3 #(
        .FALL_THROUGH   (   '0                  ),
        .DATA_WIDTH     (                       ),
        .DEPTH          (   ADDEND_FIFO_DEPTH   ),
        .dtype          (   addend_t            )    
    ) addend_fifo (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .flush_i    (   clear_i         ),
        .testmode_i (   '0              ),
        .full_o     (   addend_full     ),
        .empty_o    (   addend_empty    ),
        .usage_o    (   ),
        .data_i     (   i_addend        ),
        .push_i     (   addend_push     ),    
        .data_o     (   addend          ),
        .pop_i      (   addend_pop      )
    );

    /*  Differently from addends, a number of uses is also associated with  *
     *  factors, as we need to correct the scaling factor of every partial  *
     *  accumulation in flight.                                             */

    assign i_factor.value   = mul_i;
    assign i_factor.tag     = tag_cnt;
    assign i_factor.uses    = op_cnt_enable_inc ? (op_in_flight_cnt + 1) : op_in_flight_cnt;


    fifo_v3 #(
        .FALL_THROUGH   (   '0                  ),
        .DATA_WIDTH     (                       ),
        .DEPTH          (   FACTOR_FIFO_DEPTH   ),
        .dtype          (   factor_t            )    
    ) factor_fifo_i (
        .clk_i      (   clk_i               ),
        .rst_ni     (   rst_ni              ),
        .flush_i    (   clear_i             ),
        .testmode_i (   '0                  ),
        .full_o     (   factor_full      ),
        .empty_o    (   factor_empty     ),
        .usage_o    (   ),
        .data_i     (   i_factor            ),
        .push_i     (   factor_push      ),          
        .data_o     (   factor           ),
        .pop_i      (   factor_pop       )
    );

    assign factor_match = (factor.tag == fma_o_tag) & fma_o_valid & ~factor_empty & ((factor.tag != addend.tag) | addend_empty);
    assign factor_uses_cnt_enable = factor_match;

    assign factor_push = mul_valid_i & ready_o;
    assign factor_pop = (factor_uses_cnt  == (factor.uses) - 1) & factor_uses_cnt_enable;

    always_ff @(posedge clk_i or negedge rst_ni) begin : factor_uses_counter
        if (~rst_ni) begin
            factor_uses_cnt <= '0;
        end else begin
            if (clear_i) begin
                factor_uses_cnt <= '0;
            end else if (factor_uses_cnt_enable) begin
                if (factor_uses_cnt  == (factor.uses) - 1) begin
                    factor_uses_cnt  <= '0;
                end else begin
                    factor_uses_cnt <= factor_uses_cnt + 1;
                end
            end else begin
                factor_uses_cnt <= factor_uses_cnt;
            end
        end
    end

    fpnew_cast_multi #(
        .FpFmtConfig    (   '1                  ),
        .IntFmtConfig   (   '0                  ),
        .NumPipeRegs    (   0                   ),
        .PipeConfig     (   fpnew_pkg::BEFORE   ),
        .TagType        (   logic               ),
        .AuxType        (   logic               )
    ) i_factor_cast (
        .clk_i              (   clk_i           ),
        .rst_ni             (   rst_ni          ),
        .operands_i         (   factor.value ),
        .is_boxed_i         (   '1              ),
        .rnd_mode_i         (   fpnew_pkg::RNE  ),
        .op_i               (   '0              ),
        .op_mod_i           (   '0              ),
        .src_fmt_i          (   MUL_FPFORMAT    ),
        .dst_fmt_i          (   ACC_FPFORMAT    ),
        .int_fmt_i          (   '0              ),
        .tag_i              (   '0              ),
        .mask_i             (   '0              ),
        .aux_i              (   '0              ),
        .in_valid_i         (   '1              ),
        .in_ready_o         (                   ),
        .flush_i            (   '0              ),
        .result_o           (   fma_factor      ),
        .status_o           (                   ),
        .extension_bit_o    (                   ),
        .tag_o              (                   ),
        .mask_o             (                   ),
        .aux_o              (                   ),
        .out_valid_o        (                   ),
        .out_ready_i        (   '1              ),
        .busy_o             (                   )
    );

    always_comb begin : fma_op_selection
        unique casex ({ctrl_i.inv_fma, ctrl_i.inverting, fma_o_valid, factor_match, addend_match})
            5'b?00??:   fma_operation = fpnew_pkg::ADD;
            5'b?0100:   fma_operation = fpnew_pkg::ADD;
            5'b?0110:   fma_operation = fpnew_pkg::MUL;
            5'b?0101:   fma_operation = fpnew_pkg::ADD;
            5'b?0111:   fma_operation = fpnew_pkg::FMADD;
            5'b01???:   fma_operation = fpnew_pkg::MUL;
            5'b11???:   fma_operation = fpnew_pkg::FMADD;

            default:    fma_operation = fpnew_pkg::ADD;
        endcase
    end

    assign fma_i_valid  = (ctrl_i.reducing ? (~addend_empty & fma_o_valid) : (~addend_empty | (~factor_empty & fma_o_valid))) | ctrl_i.fma_inv_valid;
    assign fma_i_tag    = factor_uses_cnt_enable ? (fma_o_tag + 1) : (fma_o_valid ? fma_o_tag : addend.tag);
    assign fma_i_ready  = (ctrl_i.reducing | ctrl_i.inverting) ? fma_o_valid : (~addend_empty | (~factor_empty));

    assign fma_addend_pre_cast = ((fma_o_valid & addend_match) ? addend.value : '0);

    fpnew_cast_multi #(
        .FpFmtConfig    (   '1                  ),
        .IntFmtConfig   (   '0                  ),
        .NumPipeRegs    (   0                   ),
        .PipeConfig     (   fpnew_pkg::BEFORE   ),
        .TagType        (   logic               ),
        .AuxType        (   logic               )
    ) i_addend_cast (
        .clk_i              (   clk_i               ),
        .rst_ni             (   rst_ni              ),
        .operands_i         (   fma_addend_pre_cast ),
        .is_boxed_i         (   '1                  ),
        .rnd_mode_i         (   fpnew_pkg::RNE      ),
        .op_i               (   '0                  ),
        .op_mod_i           (   '0                  ),
        .src_fmt_i          (   ADD_FPFORMAT        ),
        .dst_fmt_i          (   ACC_FPFORMAT        ),
        .int_fmt_i          (   '0                  ),
        .tag_i              (   '0                  ),
        .mask_i             (   '0                  ),
        .aux_i              (   '0                  ),
        .in_valid_i         (   '1                  ),
        .in_ready_o         (                       ),
        .flush_i            (   '0                  ),
        .result_o           (   fma_addend          ),
        .status_o           (                       ),
        .extension_bit_o    (                       ),
        .tag_o              (                       ),
        .mask_o             (                       ),
        .aux_o              (                       ),
        .out_valid_o        (                       ),
        .out_ready_i        (   '1                  ),
        .busy_o             (                       )
    );

    always_comb begin
        unique casex ({ctrl_i.inv_fma, ctrl_i.inverting, fma_o_valid})
            3'b?00:     fma_operands = {fma_addend, addend.value, fma_factor};
            3'b?01:     fma_operands = {fma_addend, fma_res, fma_factor};
            3'b11?:     fma_operands = {`FP_TWO(ACC_FPFORMAT), inv_appr_d, `FP_INV_SIGN(den_q, ACC_FPFORMAT)};  //First half of the Newton-Raphson iteration
            3'b01?:     fma_operands = {{ACC_WIDTH{1'b0}}, fma_res, inv_appr_q};    //Second half of the Newton-Raphson iteration

            default:    fma_operands = {fma_addend, addend.value, fma_factor};
        endcase
    end

    fpnew_fma #(
        .FpFormat       (   ACC_FPFORMAT                            ),
        .NumPipeRegs    (   NUM_REGS_FMA                            ),
        .PipeConfig     (   fpnew_pkg::DISTRIBUTED                  ),
        .TagType        (   logic [$clog2(NUM_REGS_FMA) - 1 : 0]    ),
        .AuxType        (   logic                                   )
    ) accumulator_fma (
        .clk_i              (   clk_i           ),
        .rst_ni             (   rst_ni          ),
        .operands_i         (   fma_operands    ),
        .is_boxed_i         (   '1              ),
        .rnd_mode_i         (   ROUND_MODE      ),
        .op_i               (   fma_operation   ),
        .op_mod_i           (   '0              ),
        .tag_i              (   fma_i_tag       ),
        .mask_i             (   '1              ),
        .aux_i              (   '0              ),
        .in_valid_i         (   fma_i_valid     ),
        .in_ready_o         (   fma_o_ready     ),
        .flush_i            (   clear_i         ),
        .result_o           (   fma_res         ),
        .status_o           (   ),
        .extension_bit_o    (   ),
        .tag_o              (   fma_o_tag       ),
        .mask_o             (   ),
        .aux_o              (   ),
        .out_valid_o        (   fma_o_valid     ),
        .out_ready_i        (   fma_i_ready     ),
        .busy_o             (   )
    );

    sfm_acc_den_inverter #(
        .FPFORMAT       (   ACC_FPFORMAT    ),
        .REG_POS        (   sfm_pkg::BEFORE ),
        .NUM_REGS       (   2               ),
        .N_MANT_BITS    (   7               )
    ) denominator_inverter (
        .clk_i      (   clk_i               ),
        .rst_ni     (   rst_ni              ),
        .clear_i    (   clear_i             ),
        .valid_i    (   ctrl_i.inv_enable   ),
        .ready_i    (   '1                  ),
        .den_i      (   fma_res             ),
        .ready_o    (                       ),
        .valid_o    (   inv_appr_valid      ),
        .inv_o      (   inv_appr            )
    );

    assign flags_o.addend_valid         = add_valid_i;
    assign flags_o.addend_empty         = addend_empty;
    assign flags_o.factor_empty         = factor_empty;
    assign flags_o.fma_o_valid          = fma_o_valid;
    assign flags_o.inv_appr_valid       = inv_appr_valid;
    assign flags_o.last_op_in_flight    = op_in_flight_cnt == 1;

    assign flags_o.denominator  = {{(32 - ACC_WIDTH){1'b0}}, den_q};
    assign flags_o.reciprocal   = {{(32 - ACC_WIDTH){1'b0}}, inv_appr_q};

    assign acc_o    = inv_appr_q;
    assign ready_o  = ~(addend_full | factor_full) & ~ctrl_i.disable_ready;
    assign valid_o  = ctrl_i.res_valid;

endmodule