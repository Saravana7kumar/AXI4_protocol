module axi_burst_check #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32
)(
    input  [ADDR_W-1:0] addr,
    input  [7:0]        len,
    input  [2:0]        size,
    input  [1:0]        burst,
    output              bad
);

    wire [11:0] low  = addr[11:0] & ~((12'd1 << size) - 12'd1);
    wire [16:0] span = {5'd0, low} + (({9'd0, len} + 17'd1) << size);

    wire crosses_4k = (burst == 2'b01) && (span > 17'h1000);
    wire wrap_len_ok = (len == 8'd1) || (len == 8'd3) || (len == 8'd7) || (len == 8'd15);
    wire wrap_bad = (burst == 2'b10) && !wrap_len_ok;
    wire reserved = (burst == 2'b11);
    wire size_bad = (size > $clog2(DATA_W/8));

    assign bad = crosses_4k || wrap_bad || reserved || size_bad;

endmodule
