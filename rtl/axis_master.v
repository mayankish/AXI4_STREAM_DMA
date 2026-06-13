module axis_master #(
    parameter DW = 32,
    parameter LW = 16
)(
    input                  clk,
    input                  rst_n,

    input                  start,
    input      [LW-1:0]    length,

    input                  fifo_rd_valid,
    output                 fifo_rd_ready,
    input      [DW-1:0]    fifo_rd_data,

    output                 m_axis_tvalid,
    input                  m_axis_tready,
    output     [DW-1:0]    m_axis_tdata,
    output                 m_axis_tlast,

    output reg             busy,
    output reg             done
);

reg [LW-1:0] total;
reg [LW-1:0] beat_cnt;

assign m_axis_tvalid = busy && fifo_rd_valid;
assign m_axis_tdata  = fifo_rd_data;
assign m_axis_tlast  = busy && (beat_cnt == total - 1'b1);
assign fifo_rd_ready = busy && m_axis_tready;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        busy     <= 1'b0;
        done     <= 1'b0;
        total    <= {LW{1'b0}};
        beat_cnt <= {LW{1'b0}};
    end else begin
        done <= 1'b0;
        if (start && !busy) begin
            busy     <= 1'b1;
            total    <= length;
            beat_cnt <= {LW{1'b0}};
        end else if (busy && m_axis_tvalid && m_axis_tready) begin
            if (beat_cnt == total - 1'b1) begin
                busy <= 1'b0;
                done <= 1'b1;
            end else begin
                beat_cnt <= beat_cnt + 1'b1;
            end
        end
    end
end

endmodule
