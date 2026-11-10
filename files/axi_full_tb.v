`timescale 1ns/1ps

module axi_full_tb;

    parameter ADDR_W = 32;
    parameter DATA_W = 32;
    parameter ID_W   = 4;

    reg clk;
    reg rst_n;

    reg  [ID_W-1:0]     awid;
    reg  [ADDR_W-1:0]   awaddr;
    reg  [7:0]          awlen;
    reg  [2:0]          awsize;
    reg  [1:0]          awburst;
    reg                 awvalid;
    wire                awready;

    reg  [DATA_W-1:0]   wdata;
    reg  [DATA_W/8-1:0] wstrb;
    reg                 wlast;
    reg                 wvalid;
    wire                wready;

    wire [ID_W-1:0]     bid;
    wire [1:0]          bresp;
    wire                bvalid;
    reg                 bready;

    reg  [ID_W-1:0]     arid;
    reg  [ADDR_W-1:0]   araddr;
    reg  [7:0]          arlen;
    reg  [2:0]          arsize;
    reg  [1:0]          arburst;
    reg                 arvalid;
    wire                arready;

    wire [ID_W-1:0]     rid;
    wire [DATA_W-1:0]   rdata;
    wire [1:0]          rresp;
    wire                rlast;
    wire                rvalid;
    reg                 rready;

    integer errors;
    reg     stall_en;
    reg [DATA_W-1:0] rd_buf [0:255];

    axi_full_top #(
        .ADDR_W(ADDR_W), .DATA_W(DATA_W), .ID_W(ID_W),
        .MEM_DEPTH(1024), .FIFO_DEPTH(4)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .awid(awid), .awaddr(awaddr), .awlen(awlen), .awsize(awsize),
        .awburst(awburst), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wlast(wlast), .wvalid(wvalid), .wready(wready),
        .bid(bid), .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .arid(arid), .araddr(araddr), .arlen(arlen), .arsize(arsize),
        .arburst(arburst), .arvalid(arvalid), .arready(arready),
        .rid(rid), .rdata(rdata), .rresp(rresp), .rlast(rlast),
        .rvalid(rvalid), .rready(rready)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    function [DATA_W-1:0] pat;
        input [DATA_W-1:0] seed;
        input integer i;
        begin
            pat = seed + i;
        end
    endfunction

    task expect_eq;
        input [DATA_W-1:0] got;
        input [DATA_W-1:0] want;
        begin
            if (got !== want) begin
                errors = errors + 1;
                $display("%0t mismatch got %h want %h", $time, got, want);
            end
        end
    endtask

    task aw_send;
        input [ID_W-1:0]   id;
        input [ADDR_W-1:0] addr;
        input [7:0]        len;
        input [2:0]        size;
        input [1:0]        burst;
        begin
            awid = id;
            awaddr = addr;
            awlen = len;
            awsize = size;
            awburst = burst;
            awvalid = 1;
            @(posedge clk);
            while (!awready) @(posedge clk);
            #1 awvalid = 0;
        end
    endtask

    task w_send;
        input [7:0]        len;
        input [DATA_W-1:0] seed;
        integer i;
        begin
            for (i = 0; i <= len; i = i + 1) begin
                if (stall_en) begin
                    wvalid = 0;
                    repeat ($urandom % 3) @(posedge clk);
                    #1;
                end
                wdata = pat(seed, i);
                wstrb = {DATA_W/8{1'b1}};
                wlast = (i == len);
                wvalid = 1;
                @(posedge clk);
                while (!wready) @(posedge clk);
                #1;
            end
            wvalid = 0;
            wlast = 0;
        end
    endtask

    task b_wait;
        input [ID_W-1:0] id;
        input [1:0]      want;
        begin
            bready = 1;
            @(posedge clk);
            while (!bvalid) @(posedge clk);
            if (bid !== id || bresp !== want) begin
                errors = errors + 1;
                $display("%0t bad response id %h resp %b, wanted id %h resp %b", $time, bid, bresp, id, want);
            end
            #1 bready = 0;
        end
    endtask

    task write_burst;
        input [ID_W-1:0]   id;
        input [ADDR_W-1:0] addr;
        input [7:0]        len;
        input [2:0]        size;
        input [1:0]        burst;
        input [DATA_W-1:0] seed;
        input [1:0]        want;
        begin
            fork
                aw_send(id, addr, len, size, burst);
                w_send(len, seed);
            join
            b_wait(id, want);
        end
    endtask

    task read_burst;
        input [ID_W-1:0]   id;
        input [ADDR_W-1:0] addr;
        input [7:0]        len;
        input [2:0]        size;
        input [1:0]        burst;
        input [1:0]        want;
        integer i;
        begin
            arid = id;
            araddr = addr;
            arlen = len;
            arsize = size;
            arburst = burst;
            arvalid = 1;
            @(posedge clk);
            while (!arready) @(posedge clk);
            #1 arvalid = 0;
            for (i = 0; i <= len; i = i + 1) begin
                if (stall_en) begin
                    rready = 0;
                    repeat ($urandom % 3) @(posedge clk);
                    #1;
                end
                rready = 1;
                @(posedge clk);
                while (!rvalid) @(posedge clk);
                rd_buf[i] = rdata;
                if (rid !== id || rresp !== want || rlast !== (i == len)) begin
                    errors = errors + 1;
                    $display("%0t read beat %0d: id %h resp %b last %b", $time, i, rid, rresp, rlast);
                end
                #1;
            end
            rready = 0;
        end
    endtask

    integer k;
    integer n;
    reg [ADDR_W-1:0] a;
    reg [7:0]        l;
    reg [ID_W-1:0]   idr;
    reg [DATA_W-1:0] sd;

    initial begin
        errors  = 0;
        stall_en = 0;
        rst_n   = 0;
        awid = 0; awaddr = 0; awlen = 0; awsize = 0; awburst = 0; awvalid = 0;
        wdata = 0; wstrb = 0; wlast = 0; wvalid = 0;
        bready = 0;
        arid = 0; araddr = 0; arlen = 0; arsize = 0; arburst = 0; arvalid = 0;
        rready = 0;

        repeat (5) @(posedge clk);
        #1 rst_n = 1;
        @(posedge clk);
        #1;

        write_burst(4'd1, 32'h000, 8'd7, 3'd2, 2'b01, 32'h1000, 2'b00);
        read_burst (4'd1, 32'h000, 8'd7, 3'd2, 2'b01, 2'b00);
        for (k = 0; k < 8; k = k + 1) expect_eq(rd_buf[k], pat(32'h1000, k));

        for (k = 0; k < 8; k = k + 1) begin
            read_burst(4'd1, k * 4, 8'd0, 3'd2, 2'b01, 2'b00);
            expect_eq(rd_buf[0], pat(32'h1000, k));
        end

        write_burst(4'd2, 32'h040, 8'd3, 3'd2, 2'b01, 32'h00A0, 2'b00);
        read_burst (4'd2, 32'h048, 8'd3, 3'd2, 2'b10, 2'b00);
        expect_eq(rd_buf[0], pat(32'h00A0, 2));
        expect_eq(rd_buf[1], pat(32'h00A0, 3));
        expect_eq(rd_buf[2], pat(32'h00A0, 0));
        expect_eq(rd_buf[3], pat(32'h00A0, 1));

        write_burst(4'd3, 32'h080, 8'd3, 3'd2, 2'b00, 32'h0500, 2'b00);
        read_burst (4'd3, 32'h080, 8'd0, 3'd2, 2'b01, 2'b00);
        expect_eq(rd_buf[0], pat(32'h0500, 3));
        read_burst (4'd3, 32'h080, 8'd3, 3'd2, 2'b00, 2'b00);
        for (k = 0; k < 4; k = k + 1) expect_eq(rd_buf[k], pat(32'h0500, 3));

        fork
            begin
                aw_send(4'd2, 32'h100, 8'd3, 3'd2, 2'b01);
                aw_send(4'd3, 32'h200, 8'd5, 3'd2, 2'b01);
            end
            begin
                w_send(8'd3, 32'h1000);
                w_send(8'd5, 32'h2000);
            end
        join
        b_wait(4'd2, 2'b00);
        b_wait(4'd3, 2'b00);
        read_burst(4'd2, 32'h100, 8'd3, 3'd2, 2'b01, 2'b00);
        for (k = 0; k < 4; k = k + 1) expect_eq(rd_buf[k], pat(32'h1000, k));
        read_burst(4'd3, 32'h200, 8'd5, 3'd2, 2'b01, 2'b00);
        for (k = 0; k < 6; k = k + 1) expect_eq(rd_buf[k], pat(32'h2000, k));

        stall_en = 1;
        for (n = 0; n < 20; n = n + 1) begin
            a   = 32'h300 + (($urandom % 64) * 4);
            l   = $urandom % 16;
            idr = $urandom % 16;
            sd  = $urandom;
            write_burst(idr, a, l, 3'd2, 2'b01, sd, 2'b00);
            read_burst (idr, a, l, 3'd2, 2'b01, 2'b00);
            for (k = 0; k <= l; k = k + 1) expect_eq(rd_buf[k], pat(sd, k));
        end
        stall_en = 0;

        write_burst(4'd5, 32'hFF0, 8'd7, 3'd2, 2'b01, 32'h77, 2'b10);
        write_burst(4'd6, 32'h040, 8'd2, 3'd2, 2'b10, 32'h01, 2'b10);
        read_burst (4'd7, 32'h2000, 8'd1, 3'd2, 2'b01, 2'b10);
        expect_eq(rd_buf[0], 32'h0);
        expect_eq(rd_buf[1], 32'h0);

        if (errors == 0) $display("PASS: all checks passed");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #5000000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
