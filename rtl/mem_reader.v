module mem_reader #(
    parameter AW = 32,
    parameter DW = 32,
    parameter LW = 16
)(
    input                  clk,
    input                  rst_n,

    input                  start,
    input      [AW-1:0]    base_addr,
    input      [LW-1:0]    length,

    output reg [AW-1:0]    mem_addr,
    output reg             mem_re,
    input      [DW-1:0]    mem_rdata,
    input                  mem_rvalid,

    output                 fifo_wr_valid,
    input                  fifo_wr_ready,
    output     [DW-1:0]    fifo_wr_data,

    output reg             busy,
    output reg             done
);

localparam S_IDLE  = 2'd0,
           S_CHECK = 2'd1,
           S_WAIT  = 2'd2;

reg [1:0]    state;
reg [LW-1:0] remaining;

assign fifo_wr_valid = (state == S_WAIT) && mem_rvalid;
assign fifo_wr_data  = mem_rdata;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state     <= S_IDLE;
        mem_addr  <= {AW{1'b0}};
        mem_re    <= 1'b0;
        remaining <= {LW{1'b0}};
        busy      <= 1'b0;
        done      <= 1'b0;
    end else begin
        done   <= 1'b0;
        mem_re <= 1'b0;
        case (state)
            S_IDLE: begin
                if (start) begin
                    mem_addr  <= base_addr;
                    remaining <= length;
                    busy      <= 1'b1;
                    state     <= S_CHECK;
                end
            end
            S_CHECK: begin
                if (remaining == {LW{1'b0}}) begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end else if (fifo_wr_ready) begin
                    mem_re <= 1'b1;
                    state  <= S_WAIT;
                end
            end
            S_WAIT: begin
                if (mem_rvalid) begin
                    mem_addr  <= mem_addr + 1'b1;
                    remaining <= remaining - 1'b1;
                    state     <= S_CHECK;
                end
            end
            default: state <= S_IDLE;
        endcase
    end
end

endmodule
