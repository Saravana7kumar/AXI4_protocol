module axi_mem #(
    parameter DATA_W = 32,
    parameter DEPTH  = 1024
)(
    input                       clk,
    input                       we,
    input  [$clog2(DEPTH)-1:0]  waddr,
    input  [DATA_W-1:0]         wdata,
    input  [DATA_W/8-1:0]       wstrb,
    input  [$clog2(DEPTH)-1:0]  raddr,
    output [DATA_W-1:0]         rdata
);

    reg [DATA_W-1:0] mem [0:DEPTH-1];
    integer i;
    integer j;

    initial begin
        for (j = 0; j < DEPTH; j = j + 1)
            mem[j] = 0;
    end

    always @(posedge clk) begin
        if (we) begin
            for (i = 0; i < DATA_W/8; i = i + 1) begin
                if (wstrb[i])
                    mem[waddr][8*i +: 8] <= wdata[8*i +: 8];
            end
        end
    end

    assign rdata = mem[raddr];

endmodule
