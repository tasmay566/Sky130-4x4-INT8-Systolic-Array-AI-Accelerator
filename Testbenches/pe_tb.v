`timescale 1ns/1ps
module pe_tb;

parameter ACT_WIDTH = 8;
parameter WGT_WIDTH=8;
parameter PSUM_WIDTH=32;

reg clk;
reg reset;

reg signed [ACT_WIDTH-1:0] act_in;
reg signed [PSUM_WIDTH-1:0] psum_in;
reg signed [WGT_WIDTH-1:0] weight_in;
reg load_weight;

wire signed [ACT_WIDTH-1:0] act_out;
wire signed [PSUM_WIDTH-1:0] psum_out;

pe # (
    .ACT_WIDTH(ACT_WIDTH),
    .WGT_WIDTH(WGT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH)
)  dut(
    .clk(clk),
    .reset(reset),
    .act_in(act_in),
    .psum_in(psum_in),
    .weight_in(weight_in),
    .load_weight(load_weight),
    .act_out(act_out),
    .psum_out(psum_out)
);


always #5 clk= ~clk;

initial begin
        $monitor("Time=%0t | rst=%b ld_wgt=%b | wgt_in=%3d act_in=%3d psum_in=%4d | act_out=%3d psum_out=%4d", 
                 $time, reset, load_weight, weight_in, act_in, psum_in, act_out, psum_out);
    end

initial begin
    $dumpfile("pe_tb.vcd");
        $dumpvars(0, pe_tb);

        clk = 0;
        reset = 1;
        load_weight = 0;
        act_in = 0;
        weight_in = 0;
        psum_in = 0;

        #20;
        reset=0;

        @(posedge clk);
        #1;
        load_weight = 1;
        weight_in = -4;

        @(posedge clk);
        #1;
        load_weight = 0;
        act_in=10;
        psum_in=5;

        @(posedge clk);
        #1;
        act_in=-3;
        psum_in=6;

       

        @(posedge clk);
        #1;

        #10;
        $finish;
end
endmodule