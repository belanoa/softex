timeunit 1ps;
timeprecision 1ps;

import sfm_pkg::*;

class rng;
    int unsigned seed;

    function new(int unsigned seed);
        this.seed = seed;
    endfunction

    function int unsigned next;
        this.seed = $urandom(this.seed);

        return this.seed;
    endfunction
endclass

module sfm_fp_vect_minmax_tb;
    parameter real P_STALL_GEN = 0.20;
    parameter real P_STALL_RCV = 0.20;

    localparam TCp  = 1.0ns;
    localparam TA   = 0.2ns;

    localparam fpnew_pkg::fp_format_e   FPFORMAT        = fpnew_pkg::FP16ALT;
    localparam logic                    MANT_CORRECTION = 1'b1;
    localparam int unsigned             NUM_REGS        = 5;
    localparam int unsigned             N_ROWS          = 8;    

    localparam int unsigned WIDTH           = fpnew_pkg::fp_width(FPFORMAT);
    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT);
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT); 

    localparam int unsigned                     N_EXP   = 7;
    localparam logic                            SIGN    = 1'b0;
    localparam int unsigned                     N_MANT  = 2 ** MANTISSA_BITS;
    localparam logic [EXPONENT_BITS - 1 : 0]    MIN_EXP = 127;

    localparam int unsigned SEED = 210624;

    event   start_input_generation;
    event   start_recording;

    logic   gen_stall,
            rcv_stall;

    logic   clk,
            rst_n,
            enable,
            clear,
            valid,
            ready;

    logic   valid_o,
            ready_o;

    logic [N_ROWS - 1 : 0] strb_o;

    logic [N_ROWS - 1 : 0] strb;

    logic [N_ROWS - 1 : 0] [WIDTH - 1 : 0]  op,
                                            res_o;

    logic [EXPONENT_BITS - 1 : 0]   exp;
    logic [MANTISSA_BITS - 1 : 0]   mant;

    sfm_fp_vect_minmax #(      
        .FPFORMAT   (   FPFORMAT        ),
        .REG_POS    (   sfm_pkg::BEFORE ),
        .NUM_REGS   (   NUM_REGS        ),
        .VECT_WIDTH (   5               )
    ) sfm_fp_vect_minmax_dut (
        .clk_i      (   clk             ),
        .rst_ni     (   rst_n           ),
        .clear_i    (   clear           ),
        .enable_i   (   enable          ),
        .valid_i    (   valid           ),
        .ready_i    (   ready           ),
        .strb_i     (   strb            ),
        .vect_i     (   op              ),
        //.scal_i     (   '0              ),
        .mode_i     (   sfm_pkg::MAX    ),
        .res_o      (   res_o           ),
        //.new_flg_o  (   strb_o          ),
        .strb_o     (   strb_o          ),
        .valid_o    (   valid_o         ),
        .ready_o    (   ready_o         )
    );


    property ready_i_check;
        @(posedge clk) (valid_o && ~ready) |=> ($stable(res_o) && $stable(strb_o))
    endproperty

    property strb_o_check(strb, res);
            @(posedge clk) disable iff (~rst_n) (strb == 0) |-> (res == '0)
    endproperty

    assert property (ready_i_check);

    for (genvar i = 0; i < N_ROWS; i++) begin
        assert property (strb_o_check(strb_o [i], res_o [i]));
    end
    

    task clk_cycle;
        clk <= #(TCp / 2) 0;
        clk <= #TCp 1; 
        
        #TCp;
    endtask


    initial begin
        clk     <= '0;
        rst_n   <= '1;
        clear   <= '0;
        enable  <= '0;
        valid   <= '0;
        ready   <= '0;
        strb    <= '0;
        op      <= '0;

        exp = MIN_EXP;
        mant = 0;

        clk_cycle();

        rst_n <= #TA 1'b0;

        repeat(10)
            clk_cycle();

        rst_n <= #TA 1'b1;
        enable <= #TA 1'b1;

        ->start_input_generation;

        while (1) begin
            clk_cycle();
        end

    end

    rng random = new(SEED);

    initial begin : ready_generation
        while (1) begin
            rcv_stall = random.next() < int'(real'(unsigned'(2 ** 32 - 1)) * P_STALL_RCV);
            ready <= #TA ~rcv_stall;

            #TCp;
        end
    end

    initial begin : input_generation
        int fd_in;
        logic [WIDTH - 1 : 0] val;

        fd_in = $fopen("golden-model/input.txt", "r");

        if (fd_in == 0) begin
            $error("Could not open \"golden-model/input.txt\"; Make sure the golden model has been generated");
        end

        @(start_input_generation.triggered)

        while ($fscanf(fd_in, "%x", val) == 1) begin

            strb <= #TA random.next();
            op <= #TA {N_ROWS{val}};

            do begin
                gen_stall = random.next() < int'(real'(unsigned'(2 ** 32 - 1)) * P_STALL_GEN);
                valid <= #TA ~gen_stall;
                
                #TCp;
            end while (gen_stall);

            while (~ready_o) begin
                #TCp;
            end
        end

        $fclose(fd_in);
    end

    initial begin : output_check
        int fd_out;
        logic [WIDTH - 1 : 0] res;

        fd_out = $fopen("golden-model/result.txt", "r");

        $timeformat(-9, 2, "ns");

        if (fd_out == 0) begin
            $error("Could not open \"golden-model/result.txt\"; Make sure the golden model has been generated");
        end

        @(start_input_generation.triggered)

        while ($fscanf(fd_out, "%x\n", res) == 1) begin
            #TCp;
            
            while (~valid_o | ~ready) begin
                #TCp;
            end

            for (int i = 0; i < N_ROWS; i++) begin
                if (strb_o [i] && (res != res_o [i])) begin
                    $display("(%t) Mismatch!\tExpected %x, was %x;\tdifference:\t%x", $realtime(), res, res_o [i], res - res_o [i]);
                    break;
                end
            end
        end

        $fclose(fd_out);
        $finish;
    end

endmodule