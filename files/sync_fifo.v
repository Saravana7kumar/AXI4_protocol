module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
)(
    input                 clk,
    input                 rst_n,
    input                 wr_en,
    input  [WIDTH-1:0]    wr_data,
    input                 rd_en,
    output [WIDTH-1:0]    rd_data,
    output                full,
    output                empty
);

    localparam PW = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [PW:0] wr_ptr;
    reg [PW:0] rd_ptr;

    assign empty   = (wr_ptr == rd_ptr);
    assign full    = (wr_ptr[PW] != rd_ptr[PW]) && (wr_ptr[PW-1:0] == rd_ptr[PW-1:0]);
    assign rd_data = mem[rd_ptr[PW-1:0]];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr[PW-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (rd_en && !empty)
                rd_ptr <= rd_ptr + 1'b1;
        end
    end

endmodule
