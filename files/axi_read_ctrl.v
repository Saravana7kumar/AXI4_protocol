module axi_read_ctrl #(
    parameter ADDR_W     = 32,
    parameter DATA_W     = 32,
    parameter ID_W       = 4,
    parameter MEM_DEPTH  = 1024,
    parameter FIFO_DEPTH = 4
)(
    input                           clk,
    input                           rst_n,

    input      [ID_W-1:0]           arid,
    input      [ADDR_W-1:0]         araddr,
    input      [7:0]                arlen,
    input      [2:0]                arsize,
    input      [1:0]                arburst,
    input                           arvalid,
    output                          arready,

    output     [ID_W-1:0]           rid,
    output     [DATA_W-1:0]         rdata,
    output     [1:0]                rresp,
    output                          rlast,
    output                          rvalid,
    input                           rready,

    output     [$clog2(MEM_DEPTH)-1:0] mem_addr,
    input      [DATA_W-1:0]         mem_rdata
);

    localparam ADDR_LSB = $clog2(DATA_W/8);
    localparam MEM_AW   = $clog2(MEM_DEPTH);
    localparam AR_W     = ID_W + ADDR_W + 8 + 3 + 2;

    wire ar_full;
    wire ar_empty;
    wire [AR_W-1:0] ar_out;
    wire ar_pop;

    sync_fifo #(.WIDTH(AR_W), .DEPTH(FIFO_DEPTH)) ar_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (arvalid && arready),
        .wr_data ({arid, araddr, arlen, arsize, arburst}),
        .rd_en   (ar_pop),
        .rd_data (ar_out),
        .full    (ar_full),
        .empty   (ar_empty)
    );

    assign arready = !ar_full;

    wire [1:0]        f_burst = ar_out[1:0];
    wire [2:0]        f_size  = ar_out[4:2];
    wire [7:0]        f_len   = ar_out[12:5];
    wire [ADDR_W-1:0] f_addr  = ar_out[13 +: ADDR_W];
    wire [ID_W-1:0]   f_id    = ar_out[13+ADDR_W +: ID_W];

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

    assign ar_pop = !busy && !ar_empty;

    wire in_range = ((addr >> (ADDR_LSB + MEM_AW)) == 0);
    wire r_fire   = rvalid && rready;

    assign rvalid   = busy;
    assign rid      = id;
    assign rlast    = (beat == len);
    assign rdata    = (in_range && !err) ? mem_rdata : {DATA_W{1'b0}};
    assign rresp    = (err || !in_range) ? 2'b10 : 2'b00;
    assign mem_addr = addr[ADDR_LSB +: MEM_AW];

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
        end else if (ar_pop) begin
            busy  <= 1'b1;
            id    <= f_id;
            addr  <= f_addr;
            len   <= f_len;
            size  <= f_size;
            burst <= f_burst;
            beat  <= 0;
            err   <= f_bad;
        end else if (r_fire) begin
            if (rlast) begin
                busy <= 1'b0;
            end else begin
                beat <= beat + 1'b1;
                addr <= next_addr;
            end
        end
    end

endmodule
