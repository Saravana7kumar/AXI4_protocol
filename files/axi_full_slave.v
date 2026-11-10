module axi_full_slave #(
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
    input                           rready,

    output                          mem_we,
    output     [$clog2(MEM_DEPTH)-1:0] mem_waddr,
    output     [DATA_W-1:0]         mem_wdata,
    output     [DATA_W/8-1:0]       mem_wstrb,
    output     [$clog2(MEM_DEPTH)-1:0] mem_raddr,
    input      [DATA_W-1:0]         mem_rdata
);

    axi_write_ctrl #(
        .ADDR_W(ADDR_W), .DATA_W(DATA_W), .ID_W(ID_W),
        .MEM_DEPTH(MEM_DEPTH), .FIFO_DEPTH(FIFO_DEPTH)
    ) wr_ctrl (
        .clk(clk), .rst_n(rst_n),
        .awid(awid), .awaddr(awaddr), .awlen(awlen), .awsize(awsize),
        .awburst(awburst), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wlast(wlast), .wvalid(wvalid), .wready(wready),
        .bid(bid), .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .mem_we(mem_we), .mem_addr(mem_waddr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb)
    );

    axi_read_ctrl #(
        .ADDR_W(ADDR_W), .DATA_W(DATA_W), .ID_W(ID_W),
        .MEM_DEPTH(MEM_DEPTH), .FIFO_DEPTH(FIFO_DEPTH)
    ) rd_ctrl (
        .clk(clk), .rst_n(rst_n),
        .arid(arid), .araddr(araddr), .arlen(arlen), .arsize(arsize),
        .arburst(arburst), .arvalid(arvalid), .arready(arready),
        .rid(rid), .rdata(rdata), .rresp(rresp), .rlast(rlast),
        .rvalid(rvalid), .rready(rready),
        .mem_addr(mem_raddr), .mem_rdata(mem_rdata)
    );

endmodule
