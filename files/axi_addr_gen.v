module axi_addr_gen #(
    parameter ADDR_W = 32
)(
    input      [ADDR_W-1:0] addr,
    input      [2:0]        size,
    input      [7:0]        len,
    input      [1:0]        burst,
    output reg [ADDR_W-1:0] next_addr
);

    reg [ADDR_W-1:0] bytes;
    reg [ADDR_W-1:0] aligned;
    reg [ADDR_W-1:0] total;
    reg [ADDR_W-1:0] lower;
    reg [ADDR_W-1:0] upper;
    reg [ADDR_W-1:0] step;

    always @(*) begin
        bytes   = {{(ADDR_W-1){1'b0}}, 1'b1} << size;
        aligned = addr & ~(bytes - 1'b1);
        total   = bytes * (len + 1'b1);
        lower   = addr & ~(total - 1'b1);
        upper   = lower + total;
        step    = aligned + bytes;

        case (burst)
            2'b00:   next_addr = addr;
            2'b10:   next_addr = (step == upper) ? lower : step;
            default: next_addr = step;
        endcase
    end

endmodule
