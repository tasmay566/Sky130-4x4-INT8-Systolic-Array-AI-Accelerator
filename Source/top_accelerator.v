module top_accelerator #(
    parameter N=4,
    parameter ACT_WIDTH =8,
    parameter WGT_WIDTH= 8,
    parameter PSUM_WIDTH= 32
)(
    input wire clk,
    input wire reset,
    input load_weight,

    input wire signed [(N*PSUM_WIDTH)-1:0] psum_in_top,
    input wire signed [(N*WGT_WIDTH)-1:0] weight_in_top,

    input wire signed [(N*ACT_WIDTH)-1:0] act_in_flat,

    output wire signed [(N*ACT_WIDTH)-1:0] act_out_right,

    output wire signed [(N*PSUM_WIDTH)-1:0] psum_out_bottom 
);


wire signed [(N*ACT_WIDTH)-1:0] skewed_act_wires;  /*this is a wire that is connecting the act_out_skewed wire of data_skew_buffer module 
                                                with the act_in_left wire of the systolic_array module*/


data_skew_buffer #(
    .N(N),
    .ACT_WIDTH(ACT_WIDTH)
)  skew_inst(
    .clk(clk),
    .reset(reset),
    .act_in_flat(act_in_flat),
    .act_out_skewed(skewed_act_wires)
);

systolic_array #(
    .N(N),
    .ACT_WIDTH(ACT_WIDTH),
    .WGT_WIDTH(WGT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH)
) systolic_array_inst(
    .clk(clk),
    .reset(reset),
    .load_weight(load_weight),

    .act_in_left(skewed_act_wires),
    .act_out_right(act_out_right),

    .psum_in_top(psum_in_top),
    .weight_in_top(weight_in_top),

    .psum_out_bottom(psum_out_bottom)
    );


endmodule

