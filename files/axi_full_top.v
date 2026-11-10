module axi_full_top #(
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
    input                           rready
);

    wire                       mem_we;
    wire [$clog2(MEM_DEPTH)-1:0] mem_waddr;
    wire [DATA_W-1:0]          mem_wdata;
    wire [DATA_W/8-1:0]        mem_wstrb;
    wire [$clog2(MEM_DEPTH)-1:0] mem_raddr;
    wire [DATA_W-1:0]          mem_rdata;

    axi_full_slave #(
        .ADDR_W(ADDR_W), .DATA_W(DATA_W), .ID_W(ID_W),
        .MEM_DEPTH(MEM_DEPTH), .FIFO_DEPTH(FIFO_DEPTH)
    ) slave (
        .clk(clk), .rst_n(rst_n),
        .awid(awid), .awaddr(awaddr), .awlen(awlen), .awsize(awsize),
        .awburst(awburst), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wlast(wlast), .wvalid(wvalid), .wready(wready),
        .bid(bid), .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .arid(arid), .araddr(araddr), .arlen(arlen), .arsize(arsize),
        .arburst(arburst), .arvalid(arvalid), .arready(arready),
        .rid(rid), .rdata(rdata), .rresp(rresp), .rlast(rlast),
        .rvalid(rvalid), .rready(rready),
        .mem_we(mem_we), .mem_waddr(mem_waddr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_raddr(mem_raddr), .mem_rdata(mem_rdata)
    );

    axi_mem #(.DATA_W(DATA_W), .DEPTH(MEM_DEPTH)) memory (
        .clk(clk),
        .we(mem_we),
        .waddr(mem_waddr),
        .wdata(mem_wdata),
        .wstrb(mem_wstrb),
        .raddr(mem_raddr),
        .rdata(mem_rdata)
    );

endmodule
