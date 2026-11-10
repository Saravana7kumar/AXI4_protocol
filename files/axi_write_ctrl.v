module axi_write_ctrl #(
    parameter ADDR_W     = 32,
    parameter DATA_W     = 32,
    parameter ID_W       = 4,
    parameter MEM_DEPTH  = 1024,
    parameter FIFO_DEPTH = 4
)(
    input                           clk,
    input                           rst_n,

    input      [ID_W-1:0]           awid,
    input      [ADDR_W-1:0]         awaddr,
    input      [7:0]                awlen,
    input      [2:0]                awsize,
    input      [1:0]                awburst,
    input                           awvalid,
    output                          awready,

    input      [DATA_W-1:0]         wdata,
    input      [DATA_W/8-1:0]       wstrb,
    input                           wlast,
    input                           wvalid,
    output                          wready,

    output     [ID_W-1:0]           bid,
    output     [1:0]                bresp,
    output                          bvalid,
    input                           bready,

    output                          mem_we,
    output     [$clog2(MEM_DEPTH)-1:0] mem_addr,
    output     [DATA_W-1:0]         mem_wdata,
    output     [DATA_W/8-1:0]       mem_wstrb
);

    localparam ADDR_LSB = $clog2(DATA_W/8);
    localparam MEM_AW   = $clog2(MEM_DEPTH);
    localparam AW_W     = ID_W + ADDR_W + 8 + 3 + 2;

    wire aw_full;
    wire aw_empty;
    wire [AW_W-1:0] aw_out;
    wire aw_pop;

    sync_fifo #(.WIDTH(AW_W), .DEPTH(FIFO_DEPTH)) aw_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (awvalid && awready),
        .wr_data ({awid, awaddr, awlen, awsize, awburst}),
        .rd_en   (aw_pop),
        .rd_data (aw_out),
        .full    (aw_full),
        .empty   (aw_empty)
    );

    assign awready = !aw_full;

    wire [1:0]       f_burst = aw_out[1:0];
    wire [2:0]       f_size  = aw_out[4:2];
    wire [7:0]       f_len   = aw_out[12:5];
    wire [ADDR_W-1:0] f_addr = aw_out[13 +: ADDR_W];
    wire [ID_W-1:0]  f_id    = aw_out[13+ADDR_W +: ID_W];

    wire f_bad;

    axi_burst_check #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) chk (
        .addr  (f_addr),
        .len   (f_len),
        .size  (f_size),
        .burst (f_burst),
        .bad   (f_bad)
    );

    reg                busy;
    reg [ID_W-1:0]     id;
    reg [ADDR_W-1:0]   addr;
    reg [7:0]          len;
    reg [2:0]          size;
    reg [1:0]          burst;
    reg [7:0]          beat;
    reg                err;

    wire [ADDR_W-1:0] next_addr;

    axi_addr_gen #(.ADDR_W(ADDR_W)) gen (
        .addr      (addr),
        .size      (size),
        .len       (len),
        .burst     (burst),
        .next_addr (next_addr)
    );

    assign aw_pop = !busy && !aw_empty;

    wire b_full;
    wire b_empty;
    wire [ID_W+1:0] b_out;

    assign wready = busy && !b_full;

    wire wr_fire       = wvalid && wready;
    wire last_expected = (beat == len);
    wire beat_err      = wr_fire && (wlast != last_expected);
    wire in_range      = ((addr >> (ADDR_LSB + MEM_AW)) == 0);
    wire bad_now       = err || beat_err || !in_range;
    wire b_push        = wr_fire && last_expected;

    assign mem_we    = wr_fire && !err && in_range;
    assign mem_addr  = addr[ADDR_LSB +: MEM_AW];
    assign mem_wdata = wdata;
    assign mem_wstrb = wstrb;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy  <= 1'b0;
            id    <= 0;
            addr  <= 0;
            len   <= 0;
            size  <= 0;
            burst <= 0;
            beat  <= 0;
            err   <= 1'b0;
        end else if (aw_pop) begin
            busy  <= 1'b1;
            id    <= f_id;
            addr  <= f_addr;
            len   <= f_len;
            size  <= f_size;
            burst <= f_burst;
            beat  <= 0;
            err   <= f_bad;
        end else if (wr_fire) begin
            err <= bad_now;
            if (last_expected) begin
                busy <= 1'b0;
            end else begin
                beat <= beat + 1'b1;
                addr <= next_addr;
            end
        end
    end

    sync_fifo #(.WIDTH(ID_W+2), .DEPTH(FIFO_DEPTH)) b_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (b_push),
        .wr_data ({id, (bad_now ? 2'b10 : 2'b00)}),
        .rd_en   (bvalid && bready),
        .rd_data (b_out),
        .full    (b_full),
        .empty   (b_empty)
    );

    assign bvalid = !b_empty;
    assign bid    = b_out[ID_W+1:2];
    assign bresp  = b_out[1:0];

endmodule
