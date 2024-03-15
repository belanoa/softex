module sfm_accumulator #(
    parameter fpnew_pkg::fp_format_e    ACC_FPFORMAT        = fpnew_pkg::FP32       ,
    parameter fpnew_pkg::fp_format_e    ADD_FPFORMAT        = fpnew_pkg::FP32       ,
    parameter fpnew_pkg::fp_format_e    MUL_FPFORMAT        = fpnew_pkg::FP16ALT    ,
    parameter int unsigned              FACTOR_FIFO_DEPTH   = 5                     ,
    parameter int unsigned              ADDEND_FIFO_DEPTH   = 3                     ,
    parameter int unsigned              N_FACT_FIFO         = 1                     ,
    parameter int unsigned              N_ADD_FIFO          = 1                     ,   //Different values will most likely be never supproted
    parameter int unsigned              NUM_REGS_FMA        = 3                     ,   
    parameter fpnew_pkg::roundmode_e    ROUND_MODE          = fpnew_pkg::RNE        ,         

    localparam int unsigned             ACC_WIDTH       = fpnew_pkg::fp_width(ACC_FPFORMAT) ,
    localparam int unsigned             ADD_WIDTH       = fpnew_pkg::fp_width(ADD_FPFORMAT) ,
    localparam int unsigned             MUL_WIDTH       = fpnew_pkg::fp_width(MUL_FPFORMAT) ,
    localparam fpnew_pkg::pipe_config_t REG_POS_CVFPU   = fpnew_pkg::BEFORE
) (
    input   logic                       clk_i       ,
    input   logic                       rst_ni      ,
    input   logic                       clear_i     ,
    input   logic                       add_valid_i ,
    input   logic [ADD_WIDTH - 1 : 0]   add_i       ,
    input   logic                       mul_valid_i ,
    input   logic [MUL_WIDTH - 1 : 0]   mul_i       ,
    //input   logic                       strb_i      , Let's just ignore it for the time being
    input   logic                       finish_i    ,
    output  logic                       ready_o     ,
    output  logic                       valid_o     ,
    output  logic [ACC_WIDTH - 1 : 0]   acc_o
);

    typedef enum logic [2:0] { IDLE, COMPUTING, FINISHING, REDUCTION, /*OTHER STUFF*/ FINISHED } acc_states_t;
    
    typedef struct packed {
        logic [MUL_WIDTH - 1 : 0]                               value;
        logic [$clog2(FACTOR_FIFO_DEPTH * N_FACT_FIFO) - 1 : 0] tag;
        logic [$clog2(NUM_REGS_FMA) - 1 : 0]                    uses;
    } factor_t;

    typedef struct packed {
        logic [MUL_WIDTH - 1 : 0]                               value;
        logic [$clog2(FACTOR_FIFO_DEPTH * N_FACT_FIFO) - 1 : 0] tag;
    } addend_t;

    acc_states_t    current_state,
                    next_state;

    logic [$clog2(NUM_REGS_FMA) - 1 : 0] op_in_flight_cnt;
    logic   op_cnt_enable_inc,
            op_cnt_enable_dec;

    logic [$clog2(FACTOR_FIFO_DEPTH * N_FACT_FIFO) - 1 : 0] tag_cnt;
    logic tag_cnt_enable;

    logic   active_q,
            disable_ready,
            push_fma_res,
            red_out_cnt,
            red_out_cnt_enable,
            reducing;


    //Addend FIFO Signals
    addend_t    addend,
                i_addend;
    logic       addend_pop,
                addend_push,
                addend_match;

    logic       addend_full,
                addend_empty;

    //Factor FIFO(s) Signals
    factor_t [N_FACT_FIFO - 1 : 0]                              factor;
    factor_t                                                    i_factor;

    logic [N_FACT_FIFO - 1 : 0]                                 factor_pop,
                                                                factor_push;

    logic [N_FACT_FIFO - 1 : 0]                                 factor_full,
                                                                factor_empty,
                                                                factor_match;

    logic [N_FACT_FIFO - 1 : 0] [$clog2(NUM_REGS_FMA) - 1 : 0]  factor_uses_cnt;
    logic [N_FACT_FIFO - 1 : 0]                                 factor_uses_cnt_enable;

    logic [$clog2(N_FACT_FIFO) - 1 : 0]                         factor_cnt;
    logic                                                       factor_cnt_enable;

    
    //FMA Signals
    fpnew_pkg::operation_e                                  fma_operation;
    logic                                                   fma_i_valid,
                                                            fma_o_valid;

    logic [$clog2(FACTOR_FIFO_DEPTH * N_FACT_FIFO) - 1 : 0] fma_i_tag,
                                                            fma_o_tag;

    logic [ACC_WIDTH - 1 : 0]                               fma_factor;
    logic [ACC_WIDTH - 1 : 0]                               fma_addend;

    logic [3 * ACC_WIDTH - 1 : 0]                           fma_operands;
    logic [ACC_WIDTH - 1 : 0]                               fma_res;

    logic                                                   fma_o_ready;



    always_ff @(posedge clk_i or negedge rst_ni) begin : active_register
        if (~rst_ni) begin
            active_q <= '0;
        end else begin
            if (clear_i | finish_i) begin
                active_q <= '0;
            end else if (add_valid_i) begin
                active_q <= '1;
            end else begin
                active_q <= active_q;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : state_register
        if (~rst_ni) begin
            current_state <= IDLE;
        end else begin
            if (clear_i) begin
                current_state <= IDLE;
            end else begin
                current_state <= next_state;
            end
        end
    end

    assign op_cnt_enable_inc = addend_pop & op_in_flight_cnt != (NUM_REGS_FMA - 1);
    assign op_cnt_enable_dec = reducing & fma_i_valid;
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

    assign factor_cnt_enable = |factor_push;
    always_ff @(posedge clk_i or negedge rst_ni) begin : factor_counter
        if (~rst_ni) begin
            factor_cnt <= '0;
        end else begin
            if (clear_i) begin
                factor_cnt <= '0;
            end else if (factor_cnt_enable) begin
                if (factor_cnt == (N_FACT_FIFO - 1)) begin
                    factor_cnt <= '0;
                end else begin
                    factor_cnt <= factor_cnt + 1;
                end
            end else begin
                factor_cnt <= factor_cnt;
            end
        end
    end


    assign tag_cnt_enable = |factor_push;
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

    always_ff @(posedge clk_i or negedge rst_ni) begin : red_out_counter
        if (~rst_ni) begin
            red_out_cnt <= '0;
        end else begin
            if (clear_i) begin
                red_out_cnt <= '0;
            end else if (red_out_cnt_enable & fma_o_valid) begin
                red_out_cnt <= ~red_out_cnt;
            end else begin
                red_out_cnt <= red_out_cnt;
            end
        end
    end

    always_comb begin : sfm_accumulator_fsm
        next_state          = current_state;
        valid_o             = '0;
        disable_ready       = '0;
        push_fma_res       = '0;
        red_out_cnt_enable  = '0;
        reducing            = '0;

        unique case (current_state)
            IDLE: begin
                if (add_valid_i) begin
                    next_state = COMPUTING;
                end
            end

            COMPUTING: begin
                if (finish_i) begin
                    next_state = FINISHING;
                end
            end

            FINISHING: begin
                //disable_ready = '1;     //Remove it from here?

                if (addend_empty & &factor_empty) begin
                    next_state          = REDUCTION;
                    push_fma_res       = '1;
                    red_out_cnt_enable  = '1;
                end
            end

            REDUCTION: begin
                disable_ready       = '1;
                red_out_cnt_enable  = '1;
                push_fma_res       = ~red_out_cnt;
                reducing            = '1;

                if (op_in_flight_cnt == 0 & fma_o_valid) begin
                    next_state = FINISHED;
                    push_fma_res = '0;
                end
            end

            FINISHED: begin
                valid_o = '1;
                disable_ready = '0;

                if (add_valid_i) begin
                    next_state = COMPUTING;
                end
            end
        endcase
    end

    assign addend_match = (|factor_match ? ((fma_o_tag + 1) == addend.tag) : (fma_o_tag == addend.tag)) & fma_o_valid & ~addend_empty;
    assign addend_pop   = reducing ? (addend_match & fma_o_valid) : (addend_match | (~fma_o_valid & ~addend_empty));
    assign addend_push  = (add_valid_i & ready_o) | (push_fma_res & fma_o_valid);

    assign i_addend.value   = push_fma_res ? fma_res : add_i;
    assign i_addend.tag     = tag_cnt_enable ? (tag_cnt + 1) : (tag_cnt);

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

    assign i_factor.value   = mul_i;
    assign i_factor.tag     = tag_cnt;
    assign i_factor.uses    = op_in_flight_cnt;

    for (genvar i = 0; i < N_FACT_FIFO; i++) begin : gen_factor_fifos
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
            .full_o     (   factor_full [i]     ),
            .empty_o    (   factor_empty [i]    ),
            .usage_o    (   ),
            .data_i     (   i_factor            ),
            .push_i     (   factor_push [i]     ),          
            .data_o     (   factor [i]          ),
            .pop_i      (   factor_pop [i]      )
        );

        assign factor_match [i] = (factor[i].tag == fma_o_tag) & fma_o_valid & ~factor_empty[i] & ((factor[i].tag != addend.tag) | addend_empty);
        assign factor_uses_cnt_enable [i] = factor_match [i];

        assign factor_push [i] = mul_valid_i & (factor_cnt == i ? '1 : '0) & ready_o;
        assign factor_pop [i] = (factor_uses_cnt [i] == (factor[i].uses)) & factor_uses_cnt_enable [i];

        always_ff @(posedge clk_i or negedge rst_ni) begin : factor_uses_counter
            if (~rst_ni) begin
                factor_uses_cnt [i] <= '0;
            end else begin
                if (clear_i) begin
                    factor_uses_cnt [i] <= '0;
                end else if (factor_uses_cnt_enable [i]) begin
                    if (factor_uses_cnt [i] == (factor[i].uses)) begin
                        factor_uses_cnt [i] <= '0;
                    end else begin
                        factor_uses_cnt [i] <= factor_uses_cnt [i] + 1;
                    end
                end else begin
                    factor_uses_cnt [i] <= factor_uses_cnt [i];
                end
            end
        end
    end

    always_comb begin
        fma_factor = factor[0].value;

        for (int i = 0; i < N_FACT_FIFO; i++) begin
            if (factor_match [i]) begin
                fma_factor = factor[i].value;
                break;
            end
        end
    end


    always_comb begin : fma_op_selection
        unique casex ({fma_o_valid, |factor_match, addend_match})
            3'b0??: fma_operation = fpnew_pkg::ADD;
            3'b100: fma_operation = fpnew_pkg::ADD; //Should not happen
            3'b110: fma_operation = fpnew_pkg::MUL;
            3'b101: fma_operation = fpnew_pkg::ADD;
            3'b111: fma_operation = fpnew_pkg::FMADD;
        endcase
    end


    assign fma_i_valid  = reducing ? (~addend_empty & fma_o_valid) : (~addend_empty | (~(|factor_empty) & fma_o_valid));
    assign fma_i_tag    = |factor_uses_cnt_enable ? (fma_o_tag + 1) : (fma_o_valid ? fma_o_tag : addend.tag);

    assign fma_addend   = (fma_o_valid & addend_match) ? addend.value : '0;
    
    assign fma_operands = fma_o_valid ? {fma_addend, fma_res, fma_factor} : {fma_addend, addend.value, fma_factor};

    fpnew_fma #(
        .FpFormat       (   ACC_FPFORMAT                                            ),
        .NumPipeRegs    (   NUM_REGS_FMA                                            ),
        .PipeConfig     (   REG_POS_CVFPU                                           ),
        .TagType        (   logic [$clog2(FACTOR_FIFO_DEPTH * N_FACT_FIFO) - 1 : 0] ),
        .AuxType        (   logic                                                   )
    ) accumulator_fma (
        .clk_i              (   clk_i                       ),
        .rst_ni             (   rst_ni                      ),
        .operands_i         (   fma_operands                ),
        .is_boxed_i         (   '1                          ),
        .rnd_mode_i         (   ROUND_MODE                  ),
        .op_i               (   fma_operation               ),
        .op_mod_i           (   '0                          ),
        .tag_i              (   fma_i_tag                   ),
        .mask_i             (   '1                          ),
        .aux_i              (   '0                          ),
        .in_valid_i         (   fma_i_valid                 ),
        .in_ready_o         (   fma_o_ready                 ),
        .flush_i            (   clear_i                     ),
        .result_o           (   fma_res                     ),
        .status_o           (   ),
        .extension_bit_o    (   ),
        .tag_o              (   fma_o_tag                   ),
        .mask_o             (   ),
        .aux_o              (   ),
        .out_valid_o        (   fma_o_valid                 ),
        .out_ready_i        (   fma_o_ready | ~addend_empty ),
        .busy_o             (   )
    );

    assign ready_o = ~(addend_full | |factor_full) & ~disable_ready;

endmodule