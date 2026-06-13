`timescale 1ns/1ps

module tb_axis_dma_top;

localparam AW         = 16;
localparam DW         = 32;
localparam LW         = 8;
localparam FIFO_DEPTH = 16;
localparam MEM_SIZE   = 1024;
localparam MAX_BEATS  = 256;

reg               clk;
reg               rst_n;
reg               cfg_start;
reg  [AW-1:0]     cfg_addr;
reg  [LW-1:0]     cfg_len;
wire              status_busy;
wire              status_done;

wire [AW-1:0]     mem_addr;
wire              mem_re;
reg  [DW-1:0]     mem_rdata;
reg               mem_rvalid;

wire              m_axis_tvalid;
reg               m_axis_tready;
wire [DW-1:0]     m_axis_tdata;
wire              m_axis_tlast;

reg  [DW-1:0]     mem_array [0:MEM_SIZE-1];
reg  [DW-1:0]     rx_data   [0:MAX_BEATS-1];
reg               rx_last   [0:MAX_BEATS-1];
integer           rx_count;

integer           i, errors, transfer_num;
reg [31:0]        rand_word;

axis_dma_top #(.AW(AW), .DW(DW), .LW(LW), .FIFO_DEPTH(FIFO_DEPTH)) dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .cfg_start    (cfg_start),
    .cfg_addr     (cfg_addr),
    .cfg_len      (cfg_len),
    .status_busy  (status_busy),
    .status_done  (status_done),
    .mem_addr     (mem_addr),
    .mem_re       (mem_re),
    .mem_rdata    (mem_rdata),
    .mem_rvalid   (mem_rvalid),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tlast (m_axis_tlast)
);

initial clk = 1'b0;
always #5 clk = ~clk;

initial begin
    $dumpfile("sim/wave.vcd");
    $dumpvars(0, tb_axis_dma_top);
end

// synchronous memory model, 1-cycle read latency
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_rvalid <= 1'b0;
        mem_rdata  <= {DW{1'b0}};
    end else begin
        mem_rvalid <= mem_re;
        mem_rdata  <= mem_array[mem_addr];
    end
end

// randomised TREADY to exercise backpressure through the FIFO
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        m_axis_tready <= 1'b0;
    end else begin
        rand_word     = $random;
        m_axis_tready <= (rand_word[1:0] != 2'b00);
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_count <= 0;
    end else if (m_axis_tvalid && m_axis_tready) begin
        rx_data[rx_count] <= m_axis_tdata;
        rx_last[rx_count] <= m_axis_tlast;
        rx_count          <= rx_count + 1;
    end
end

task automatic run_transfer(input [AW-1:0] addr, input [LW-1:0] len);
    integer j;
    begin
        transfer_num = transfer_num + 1;
        rx_count     = 0;

        @(posedge clk);
        cfg_addr  = addr;
        cfg_len   = len;
        cfg_start = 1'b1;
        @(posedge clk);
        cfg_start = 1'b0;

        wait (status_done == 1'b1);
        @(posedge clk);

        if (rx_count !== len) begin
            errors = errors + 1;
            $display("T%0d: beat-count mismatch: expected %0d got %0d", transfer_num, len, rx_count);
        end

        for (j = 0; j < len; j = j + 1) begin
            if (rx_data[j] !== mem_array[addr + j]) begin
                errors = errors + 1;
                $display("T%0d: data mismatch beat %0d: expected %h got %h",
                          transfer_num, j, mem_array[addr+j], rx_data[j]);
            end
            if (rx_last[j] !== (j == len-1)) begin
                errors = errors + 1;
                $display("T%0d: tlast mismatch beat %0d: expected %0d got %0d",
                          transfer_num, j, (j == len-1), rx_last[j]);
            end
        end

        $display("T%0d: addr=%0d len=%0d -> %0d beats checked", transfer_num, addr, len, len);

        repeat (5) @(posedge clk);
    end
endtask

initial begin
    for (i = 0; i < MEM_SIZE; i = i + 1)
        mem_array[i] = $random;

    rst_n        = 1'b0;
    cfg_start    = 1'b0;
    cfg_addr     = {AW{1'b0}};
    cfg_len      = {LW{1'b0}};
    errors       = 0;
    transfer_num = 0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (3) @(posedge clk);

    run_transfer(16'd0,   8'd32);
    run_transfer(16'd100, 8'd1);
    run_transfer(16'd200, 8'd64);
    run_transfer(16'd512, 8'd17);

    $display("--------------------------------------------");
    if (errors == 0)
        $display("axis_dma TB: %0d transfers, RESULT: PASS", transfer_num);
    else
        $display("axis_dma TB: %0d transfers, %0d errors, RESULT: FAIL", transfer_num, errors);
    $display("--------------------------------------------");

    repeat (4) @(posedge clk);
    $finish;
end

initial begin
    #2000000;
    $display("TIMEOUT");
    $finish;
end

endmodule
