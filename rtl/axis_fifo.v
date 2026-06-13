module axis_fifo #(
    parameter DW    = 32,
    parameter DEPTH = 16
)(
    input                          clk,
    input                          rst_n,

    input                          wr_valid,
    output                         wr_ready,
    input      [DW-1:0]            wr_data,

    output                         rd_valid,
    input                          rd_ready,
    output     [DW-1:0]            rd_data,

    output     [$clog2(DEPTH):0]   count
);

localparam AW = $clog2(DEPTH);

reg [DW-1:0] mem [0:DEPTH-1];
reg [AW:0]   wr_ptr;
reg [AW:0]   rd_ptr;

wire empty = (wr_ptr == rd_ptr);
wire full  = (wr_ptr[AW] != rd_ptr[AW]) && (wr_ptr[AW-1:0] == rd_ptr[AW-1:0]);

assign wr_ready = !full;
assign rd_valid = !empty;
assign rd_data  = mem[rd_ptr[AW-1:0]];
assign count    = wr_ptr - rd_ptr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        wr_ptr <= {(AW+1){1'b0}};
    else if (wr_valid && wr_ready) begin
        mem[wr_ptr[AW-1:0]] <= wr_data;
        wr_ptr <= wr_ptr + 1'b1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        rd_ptr <= {(AW+1){1'b0}};
    else if (rd_valid && rd_ready)
        rd_ptr <= rd_ptr + 1'b1;
end

endmodule
