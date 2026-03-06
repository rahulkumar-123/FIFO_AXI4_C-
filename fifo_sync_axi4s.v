`timescale 1ns / 1ps

module fifo_sync_axi4s #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4, // DEPTH = 16
    parameter PROG_FULL_THRESH = 12,
    parameter PROG_EMPTY_THRESH = 4
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // slave in
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,

    // master out
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [(DATA_WIDTH/8)-1:0] m_axis_tkeep,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    
    // Status Flags
    output wire                   almost_full,
    output wire                   almost_empty
);

    // mem layout: [tlast | tkeep | tdata]
    localparam KEEP_WIDTH = DATA_WIDTH / 8;
    localparam MEM_WIDTH  = DATA_WIDTH + KEEP_WIDTH + 1;
    localparam DEPTH      = 1 << ADDR_WIDTH;

    reg [MEM_WIDTH-1:0] mem [0:DEPTH-1];

    // ptrs (msb is wrap bit)
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    wire full;
    wire empty;
    wire wr_en;
    wire rd_en;
    
    wire [ADDR_WIDTH:0] data_count;

    // Data Count calculation for thresholds
    assign data_count = wr_ptr - rd_ptr;
    assign almost_full  = (data_count >= PROG_FULL_THRESH);
    assign almost_empty = (data_count <= PROG_EMPTY_THRESH);

    // eval flags
    assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && 
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    assign empty = (wr_ptr == rd_ptr);

    // axis protocol hooks
    assign s_axis_tready = ~full;
    assign m_axis_tvalid = ~empty;

    assign wr_en = s_axis_tvalid & s_axis_tready;
    assign rd_en = m_axis_tvalid & m_axis_tready;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= {s_axis_tlast, s_axis_tkeep, s_axis_tdata};
            wr_ptr <= wr_ptr + 1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (rd_en) begin
            rd_ptr <= rd_ptr + 1;
        end
    end

    // fwft async read
    wire [MEM_WIDTH-1:0] read_data = mem[rd_ptr[ADDR_WIDTH-1:0]];
    
    assign m_axis_tdata = read_data[DATA_WIDTH-1:0];
    assign m_axis_tkeep = read_data[DATA_WIDTH+KEEP_WIDTH-1:DATA_WIDTH];
    assign m_axis_tlast = read_data[MEM_WIDTH-1];

endmodule
