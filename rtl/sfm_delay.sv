`include "common_cells/registers.svh"

module sfm_delay #(
    parameter int unsigned  NUM_REGS    = 0,
    parameter int unsigned  DATA_WIDTH  = 1,
    parameter int unsigned  NUM_ROWS    = 1
) (
    input   logic                                           clk_i       ,
    input   logic                                           rst_ni      ,
    input   logic                                           enable_i    ,
    input   logic                                           clear_i     ,
    input   logic                                           valid_i     ,
    input   logic                                           ready_i     ,
    input   logic [NUM_ROWS - 1 : 0] [DATA_WIDTH - 1 : 0]   data_i      ,
    input   logic [NUM_ROWS - 1 : 0]                        strb_i      ,
    output  logic                                           valid_o     ,
    output  logic                                           ready_o     ,
    output  logic [NUM_ROWS - 1 : 0] [DATA_WIDTH - 1 : 0]   data_o      ,
    output  logic [NUM_ROWS - 1 : 0]                        strb_o      
);

    logic [NUM_REGS : 0] [NUM_ROWS - 1 : 0] [DATA_WIDTH - 1 : 0]    data;
    logic [NUM_REGS : 0] [NUM_ROWS - 1 : 0]                         strb;

    logic [NUM_REGS : 0]    valid_reg;

    logic [NUM_REGS : 0]                        reg_en_n;
    logic [NUM_ROWS - 1 : 0] [NUM_REGS - 1 : 0] row_enable;


    assign ready_o  = ~reg_en_n [0] & enable_i;

    for (genvar i = 0; i < NUM_REGS; i++) begin : reg_enable_assignment
        assign reg_en_n [i] = reg_en_n [i + 1] & valid_reg [i + 1];
    end
    assign reg_en_n [NUM_REGS] = ~ready_i;


    assign valid_reg [0]    = valid_i;
    for (genvar i = 0; i < NUM_REGS; i++) begin : valid_registers
        `FFLARNC(valid_reg [i + 1], valid_reg [i],  enable_i & ~reg_en_n [i],   clear_i,    '0, clk_i,  rst_ni)
    end
    assign valid_o  = valid_reg [NUM_REGS];


    always_comb begin : row_enable_assignment
        for (int i = 0; i < NUM_ROWS; i++) begin
            for (int j = 0; j < NUM_REGS; j++) begin
                row_enable [i][j]   = enable_i & ~reg_en_n [j] & strb [j][i] & valid_reg [j];
            end
        end
    end


    assign strb [0] = strb_i;
    for (genvar i = 0; i < NUM_REGS; i++) begin : strb_registers
        `FFLARNC(strb [i + 1],  strb [i],   enable_i & ~reg_en_n [i],   clear_i,    '0, clk_i,  rst_ni)
    end
    assign strb_o = strb [NUM_REGS];


    assign data [0] = data_i;
    for (genvar i = 0; i < NUM_ROWS; i++) begin : data_registers
        for (genvar j = 0; j < NUM_REGS; j++) begin
            `FFLARNC(data [j + 1][i],  data [j][i],   row_enable [i][j],  clear_i,    '0, clk_i,  rst_ni)
        end
    end
    assign data_o = data [NUM_REGS];

endmodule