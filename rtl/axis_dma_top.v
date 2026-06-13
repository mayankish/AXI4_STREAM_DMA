module axis_dma_top #(
    parameter AW         = 32,
    parameter DW         = 32,
    parameter LW         = 16,
    parameter FIFO_DEPTH = 16
)(
    input                  clk,
    input                  rst_n,

    input                  cfg_start,
    input      [AW-1:0]    cfg_addr,
    input      [LW-1:0]    cfg_len,
    output                 status_busy,
    output                 status_done,

    output     [AW-1:0]    mem_addr,
    output                 mem_re,
    input      [DW-1:0]    mem_rdata,
    input                  mem_rvalid,

    output                 m_axis_tvalid,
    input                  m_axis_tready,
    output     [DW-1:0]    m_axis_tdata,
    output                 m_axis_tlast
);

localparam T_IDLE = 1'b0,
           T_RUN  = 1'b1;

reg        t_state;
reg        start_pulse;

wire       reader_busy, reader_done;
wire       master_busy, master_done;
wire       fifo_wr_valid, fifo_wr_ready;
wire [DW-1:0] fifo_wr_data;
wire       fifo_rd_valid, fifo_rd_ready;
wire [DW-1:0] fifo_rd_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        t_state     <= T_IDLE;
        start_pulse <= 1'b0;
    end else begin
        start_pulse <= 1'b0;
        case (t_state)
            T_IDLE: begin
                if (cfg_start) begin
                    t_state     <= T_RUN;
                    start_pulse <= 1'b1;
                end
            end
            T_RUN: begin
                if (master_done)
                    t_state <= T_IDLE;
            end
            default: t_state <= T_IDLE;
        endcase
    end
end

assign status_busy = (t_state == T_RUN);
assign status_done = master_done;

mem_reader #(.AW(AW), .DW(DW), .LW(LW)) u_reader (
    .clk          (clk),
    .rst_n        (rst_n),
    .start        (start_pulse),
    .base_addr    (cfg_addr),
    .length       (cfg_len),
    .mem_addr     (mem_addr),
    .mem_re       (mem_re),
    .mem_rdata    (mem_rdata),
    .mem_rvalid   (mem_rvalid),
    .fifo_wr_valid(fifo_wr_valid),
    .fifo_wr_ready(fifo_wr_ready),
    .fifo_wr_data (fifo_wr_data),
    .busy         (reader_busy),
    .done         (reader_done)
);

axis_fifo #(.DW(DW), .DEPTH(FIFO_DEPTH)) u_fifo (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_valid(fifo_wr_valid),
    .wr_ready(fifo_wr_ready),
    .wr_data (fifo_wr_data),
    .rd_valid(fifo_rd_valid),
    .rd_ready(fifo_rd_ready),
    .rd_data (fifo_rd_data),
    .count   ()
);

axis_master #(.DW(DW), .LW(LW)) u_master (
    .clk          (clk),
    .rst_n        (rst_n),
    .start        (start_pulse),
    .length       (cfg_len),
    .fifo_rd_valid(fifo_rd_valid),
    .fifo_rd_ready(fifo_rd_ready),
    .fifo_rd_data (fifo_rd_data),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tlast (m_axis_tlast),
    .busy         (master_busy),
    .done         (master_done)
);

endmodule
