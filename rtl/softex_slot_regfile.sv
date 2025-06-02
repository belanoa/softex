
module softex_slot_regfile
import softex_pkg::*;
import hwpe_stream_package::*;
import hci_package::*;
#(
    parameter int unsigned  DATA_WIDTH      = DATA_W                ,
    parameter int unsigned  N_STATE_SLOTS   = N_CTRL_STATE_SLOTS    ,
    parameter int unsigned  N_BITS_ADDR     = SLOT_ADDR_BITS        ,
    parameter int unsigned  N_CONTEXT       = N_CTRL_CNTX           ,
    parameter int unsigned  IN_WIDTH        = WIDTH_IN              ,
    parameter int unsigned  ACC_WIDTH       = WIDTH_ACC             
) (
    input   logic                       clk_i           ,
    input   logic                       rst_ni          ,
    input   logic                       clear_i         ,
    input   slot_regfile_ctrl_t         ctrl_i          ,
    
    output  slot_t                      slot_o          ,
    output  hci_streamer_ctrl_t         store_ctrl_o    ,
    output  hci_streamer_ctrl_t         load_ctrl_o     ,

    hwpe_stream_intf_stream.source      store_o         ,
    hwpe_stream_intf_stream.sink        load_i          
);

    /*  The values of the maximum and denominator of each unfinished partial operation are stored in                    *
     *  "state slots", registers used to restore the state of the datapath every time the user resumes                  *
     *  one of these operations.                                                                                        *
     *  Only a fraction of the slots are stored inside the accelerator: the majority of the slots                       *
     *  are stored in memory and loaded only when necessary.                                                            *
     *  The slots can be altered by pushing 2 kinds of operations:                                                      *
     *  Requests, pushed as soon as a new partial operation is requested, divided into:                                 *
     *      - ALLOC, used to at the start of the operation to reserve a slot and mark it as valid                       *
     *      - LOAD, used before starting each partial operation to request a specific slot to be loaded if it is not    *
                    in the accelerator                                                                                  *
     *  Updates, pushed at the end of each partial operation, divided into:                                             *
     *      - UPDATE, used at the end of each partial operation to update the current maximum and denominator           *
     *      - FREE, used at the end of the operation to free the slot and make it available to other users              */

    typedef struct packed {
        logic [ACC_WIDTH - 1 : 0]       denominator;
        logic [IN_WIDTH - 1 : 0]        maximum;

        logic [$clog2(N_CONTEXT) : 0]   uses;
        logic                           valid;
        logic [N_BITS_ADDR -1 : 0]      id;
    } reg_slot_t;

    typedef enum logic [1:0] {
        IDLE,
        WAIT_STORE,
        WAIT_LOAD,
        FINISHED
    } fsm_state_t;

    flags_fifo_t    req_fifo_flags,
                    update_fifo_flags;

    reg_slot_t [N_STATE_SLOTS - 1 : 0] slots_q;
    reg_slot_t slot_d;

    logic [$clog2(N_STATE_SLOTS) - 1 : 0]   free_slot_ptr;
    logic   free_valid;

    logic [$clog2(N_STATE_SLOTS) - 1 : 0]   zero_uses_slot_ptr;

    logic [$clog2(N_STATE_SLOTS) - 1 : 0]   slot_out_ptr;

    logic [N_BITS_ADDR - 1 : 0] op_addr;

    logic   request_pop,
            update_pop;

    logic       target_present;
    reg_slot_t  target_slot;

    logic [$clog2(N_STATE_SLOTS) - 1 : 0]   target_slot_ptr;

    logic [N_STATE_SLOTS - 1 : 0]   target_enable;

    slot_req_op_t       current_request;
    slot_update_op_t    current_update;

    logic   request_valid,
            update_valid;

    logic       slot_present;
    reg_slot_t  requested_slot;

    fsm_state_t current_state,
                next_state;

    logic   start_load,
            start_store;

    logic   store_valid;

    logic   moving_data;

    logic   inc_uses,
            dec_uses,
            flush,
            acquire,
            update,
            slot_enable;

    hwpe_stream_intf_stream #(.DATA_WIDTH(N_BITS_ADDR + 1))  slot_req_fifo_d  (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(N_BITS_ADDR + 1))  slot_req_fifo_q  (.clk(clk_i));

    hwpe_stream_intf_stream #(.DATA_WIDTH(N_BITS_ADDR + 1 +  IN_WIDTH + ACC_WIDTH))  slot_update_fifo_d  (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(N_BITS_ADDR + 1 +  IN_WIDTH + ACC_WIDTH))  slot_update_fifo_q  (.clk(clk_i));

    // Output assignment

    always_comb begin : slot_present_assignment
        slot_present = '0;

        for (int i = 0; i < N_STATE_SLOTS; i++) begin
            if ((slots_q[i].id == ctrl_i.addr) && slots_q[i].valid) begin
                slot_present = '1;
            end
        end
    end

    always_comb begin : requested_slot_assignment
        requested_slot = slots_q [0];

        for (int i = 0; i < N_STATE_SLOTS; i++) begin
            if (slots_q[i].id == ctrl_i.addr) begin
                requested_slot = slots_q [i];
            end
        end
    end

    assign slot_o.valid         = slot_present & (~update_valid | (current_update.addr != ctrl_i.addr)); // We must make sure the slot we want to read is not being updated
    assign slot_o.denominator   = requested_slot.denominator;
    assign slot_o.maximum       = requested_slot.maximum;


    // Target slot assignments

    // When we are in the middle of moving a slot, the address of the target must remain constant
    assign op_addr = (update_valid & ~moving_data) ? current_update.addr : current_request.addr;

    always_comb begin : target_present_assignment
        target_present = '0;

        for (int i = 0; i < N_STATE_SLOTS; i++) begin
            if ((slots_q[i].id == op_addr) && slots_q[i].valid) begin
                target_present = '1;
            end
        end
    end

    always_comb begin : target_slot_ptr_assignment
        target_slot_ptr = '0;

        for (int i = 0; i < N_STATE_SLOTS; i++) begin
            if ((slots_q[i].id == op_addr) && slots_q[i].valid) begin
                target_slot_ptr = i;
            end
        end
    end

    // Free slot assignments

    always_comb begin : free_valid_assignment
        free_valid = '0;

        for (int i = 0; i < N_STATE_SLOTS; i++) begin
            if (~slots_q[i].valid) begin
                free_valid = '1;
                break;
            end
        end
    end

    always_comb begin : free_slot_ptr_assignment
        free_slot_ptr = '0;

        for (int i = 0; i < N_STATE_SLOTS; i++) begin
            if (~slots_q[i].valid) begin
                free_slot_ptr = i;
                break;
            end
        end
    end


    // 0 uses slot

    always_comb begin : zero_uses_slot_ptr_assignment
        zero_uses_slot_ptr = '0;

        for (int i = 0; i < N_STATE_SLOTS; i++) begin
            if (slots_q[i].uses == '0) begin
                zero_uses_slot_ptr = i;
                break;
            end
        end
    end

    // This is the index of the slot that will be replaced
    assign slot_out_ptr = free_valid ? free_slot_ptr : zero_uses_slot_ptr;

    assign current_request  = slot_req_op_t'(slot_req_fifo_q.data);
    assign current_update   = slot_update_op_t'(slot_update_fifo_q.data);

    assign request_valid    = slot_req_fifo_q.valid;
    assign update_valid     = slot_update_fifo_q.valid;

    assign slot_req_fifo_d.data     = {ctrl_i.req_op};
    assign slot_req_fifo_d.valid    = ctrl_i.req_valid;
    assign slot_req_fifo_d.strb     = '1;

    hwpe_stream_fifo #(
        .DATA_WIDTH (   N_BITS_ADDR + 1                                     ),
        .FIFO_DEPTH (   N_CONTEXT % 2 == 0 ? N_CONTEXT + 2 : N_CONTEXT + 1  )   //FIFO_DEPTH must be a multiple of 2
    ) i_req_fifo (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .clear_i    (   clear_i         ),
        .flags_o    (   req_fifo_flags  ),
        .push_i     (   slot_req_fifo_d ),
        .pop_o      (   slot_req_fifo_q )
    );

    assign slot_req_fifo_q.ready    = request_pop;


    assign slot_update_fifo_d.data  = {ctrl_i.update_op};
    assign slot_update_fifo_d.valid = ctrl_i.update_valid;
    assign slot_update_fifo_d.strb  = '1;

    hwpe_stream_fifo #(
        .DATA_WIDTH (   N_BITS_ADDR + 1 + IN_WIDTH + ACC_WIDTH  ),
        .FIFO_DEPTH (   2                                       )
    ) i_update_fifo (
        .clk_i      (   clk_i               ),
        .rst_ni     (   rst_ni              ),
        .clear_i    (   clear_i             ),
        .flags_o    (   update_fifo_flags   ),
        .push_i     (   slot_update_fifo_d  ),
        .pop_o      (   slot_update_fifo_q  )
    );

    assign slot_update_fifo_q.ready    = update_pop;


    assign load_i.ready     = '1;

    assign store_o.valid    = store_valid;
    assign store_o.data     = {{((DATA_WIDTH - 64)){1'b0}}, {(32 - ACC_WIDTH){1'b0}}, {1'b1, slots_q[slot_out_ptr].denominator[ACC_WIDTH - 2 : 0]}, {(32 - IN_WIDTH){1'b0}}, slots_q[slot_out_ptr].maximum};
    assign store_o.strb     = {{((DATA_WIDTH - 64) / 8){1'b0}}, {8{1'b1}}};


    assign load_ctrl_o.req_start                        = start_load;

    assign load_ctrl_o.addressgen_ctrl.base_addr        = ctrl_i.cache_base_addr + (current_request.addr << 3);
    assign load_ctrl_o.addressgen_ctrl.tot_len          = 1;
    assign load_ctrl_o.addressgen_ctrl.d0_len           = '0;
    assign load_ctrl_o.addressgen_ctrl.d0_stride        = '0;
    assign load_ctrl_o.addressgen_ctrl.d1_len           = '0;
    assign load_ctrl_o.addressgen_ctrl.d1_stride        = '0;
    assign load_ctrl_o.addressgen_ctrl.d2_stride        = '0;
    assign load_ctrl_o.addressgen_ctrl.dim_enable_1h    = '0;


    assign store_ctrl_o.req_start                       = start_store;

    assign store_ctrl_o.addressgen_ctrl.base_addr       = ctrl_i.cache_base_addr + (slots_q[slot_out_ptr].id << 3);
    assign store_ctrl_o.addressgen_ctrl.tot_len         = 1;
    assign store_ctrl_o.addressgen_ctrl.d0_len          = '0;
    assign store_ctrl_o.addressgen_ctrl.d0_stride       = '0;
    assign store_ctrl_o.addressgen_ctrl.d1_len          = '0;
    assign store_ctrl_o.addressgen_ctrl.d1_stride       = '0;
    assign store_ctrl_o.addressgen_ctrl.d2_stride       = '0;
    assign store_ctrl_o.addressgen_ctrl.dim_enable_1h   = '0;


    // FSM

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

    always_comb begin : slot_regfile_sfm
        next_state      = current_state;
        request_pop     = '0;
        update_pop      = '0;
        start_load      = '0;
        start_store     = '0;
        store_valid     = '0;
        inc_uses        = '0;
        dec_uses        = '0;
        flush           = '0;
        acquire         = '0;
        update          = '0;
        slot_enable     = '0;
        moving_data     = '0;

        case (current_state)
            IDLE: begin
                if (update_valid) begin // Update operations are priorital
                    if (current_update.op == UPDATE) begin
                        dec_uses    = '1;
                        update      = '1;
                    end else begin
                        flush       = '1;
                    end

                    slot_enable     = '1;
                    update_pop      = '1;
                end else if (request_valid) begin
                    if (target_present) begin   // This can only happen with LOAD operations
                        inc_uses    = '1;
                        slot_enable = '1;
                        request_pop = '1;
                    end else if (free_valid) begin  // The slot is not loaded but there is room for it
                        if (current_request.op == LOAD) begin
                            start_load  = '1;

                            next_state  = WAIT_LOAD;
                        end else begin  
                            acquire     = '1;
                            slot_enable = '1;
                            request_pop = '1;
                        end
                    end else begin  // A slot has to be stored before loading / acquiring the new one
                        start_store = '1;
                        store_valid = '1;

                        next_state  = WAIT_STORE;
                    end
                end
            end

            WAIT_STORE: begin
                store_valid = '1;
                moving_data = '1;

                //We wait for the ready signal to be asserted
                if (store_o.ready) begin
                    if (current_request.op == ALLOC) begin
                        acquire     = '1;
                        slot_enable = '1;
                        request_pop = '1;

                        next_state  = FINISHED;
                    end else begin
                        start_load  = '1;

                        next_state  = WAIT_LOAD;
                    end
                end
            end

            WAIT_LOAD: begin
                moving_data = '1;

                //We wait for the valid signal to be asserted
                if (load_i.valid) begin
                    slot_enable = '1;
                    request_pop = '1;

                    next_state  = FINISHED;
                end
            end

            FINISHED: begin
                //The sole purpose of this state is to wait one clock cycle before a laod/store
                next_state = IDLE;
            end
        endcase
    end

    always_comb begin : slot_d_assignment
        slot_d = slots_q [target_slot_ptr];

        // Maximum and denominator

        if (update) begin
            slot_d.denominator  = current_update.denominator;
            slot_d.maximum      = current_update.maximum;
        end else if (load_i.valid) begin
            slot_d.maximum      = load_i.data [IN_WIDTH - 1 : 0];
            slot_d.denominator  = {1'b0, load_i.data [32 + ACC_WIDTH - 2 -: ACC_WIDTH - 1]};
        end

        // Valid

        if (flush) begin
            slot_d.valid    = '0;
        end else if (acquire) begin
            slot_d.valid    = '1;
        end else if (load_i.valid) begin
            slot_d.valid    = '1;
        end

        // Uses

        if (dec_uses) begin
            slot_d.uses = slots_q[target_slot_ptr].uses - 1;
        end else if (inc_uses) begin
            slot_d.uses = slots_q[target_slot_ptr].uses + 1;
        end else if (acquire) begin
            slot_d.uses = 1;
        end else if (load_i.valid) begin
            slot_d.uses = 1;
        end else if (flush) begin
            slot_d.uses = '0;
        end

        // Address

        if (acquire) begin
            slot_d.id   = current_request.addr;
        end else if (load_i.valid) begin
            slot_d.id   = current_request.addr;
        end
    end

    for (genvar i = 0; i < N_STATE_SLOTS; i++) begin : generate_state_slots
        // If the target is not present when we update this means that we are replacing a slot 
        assign target_enable [i]    = slot_enable && (
                                        target_present  ?   target_slot_ptr     == i    :
                                        free_valid      ?   free_slot_ptr       == i    :
                                                            zero_uses_slot_ptr  == i
                                    );

        always_ff @(posedge clk_i or negedge rst_ni) begin : slot_register
            if (~rst_ni) begin
                slots_q [i] <= '0;
            end else begin
                if (clear_i) begin
                    slots_q [i] <= '0;
                end else if (target_enable [i]) begin
                    slots_q [i] <= slot_d;
                end
            end
        end
    end

endmodule