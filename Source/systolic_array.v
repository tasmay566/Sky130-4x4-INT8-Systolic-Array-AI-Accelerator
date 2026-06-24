module systolic_array #(
    parameter N = 4,           // The grid size (N x N)
    parameter ACT_WIDTH = 8,
    parameter WGT_WIDTH = 8,
    parameter PSUM_WIDTH = 32
)(
    input wire clk,
    input wire reset,
    input wire load_weight,

    //The left edge (Activations flowing left to right)
    // N rows, each ACT_WIDTH wide. Flattened into one giant vector.
    input wire signed [(N * ACT_WIDTH)-1 : 0] act_in_left,

    //The top edge (Partial Sums flowing top to bottom)
    // N columns, each PSUM_WIDTH wide. (Usually driven to 0 by the testbench)
    input wire signed [(N * PSUM_WIDTH)-1 : 0] psum_in_top,

    //The weight loader
    // To load weights, we feed them into the top row, and they will shift down.
    // So we need N columns of weights entering from the top.
    input wire signed [(N * WGT_WIDTH)-1 : 0] weight_in_top,

    //The right edge, activations propagating through the row
    //N rows, each ACT_WIDTH wide.
    output wire signed [(N*ACT_WIDTH)-1:0] act_out_right,

    //The bottom edge, the result of pe flowing downwards
    //N columns, each PSUM_WIDTH wide.
    output wire signed [(N*PSUM_WIDTH)-1:0] psum_out_bottom
    
);

wire signed [ACT_WIDTH-1:0] act_wires [0:N-1][0:N];    //there are N rows of act wires and each row has N+1 columns of those act wires
wire signed [PSUM_WIDTH-1:0] psum_wires [0:N][0:N-1];  //there are N columns of psum wires and each column has N+1 rows of those psum wires. 
wire signed [WGT_WIDTH-1:0] weight_wires [0:N][0:N-1]; //there are N columns of weight wires and each column has N+1 rows of those weight wires.

genvar row, col;
generate
    


for(row=0; row<N; row=row+1) begin: leftmost_rightmost_act_wires
    assign act_wires [row][0] = act_in_left[(row*ACT_WIDTH) +: ACT_WIDTH];
    assign act_out_right[(row*ACT_WIDTH) +: ACT_WIDTH]= act_wires[row][N];
end

for(col=0; col<N; col=col+1) begin: topmost_bottommost_psum_wires
    assign psum_wires[0][col] = psum_in_top[(col*PSUM_WIDTH) +: PSUM_WIDTH];
    assign psum_out_bottom[(col*PSUM_WIDTH) +: PSUM_WIDTH] = psum_wires[N][col];
    
    assign weight_wires[0][col] = weight_in_top[(col*WGT_WIDTH) +: WGT_WIDTH];
end

for(row=0; row<N; row=row+1) begin:outer_loop
    for(col=0; col<N; col=col+1) begin: inner_loop

    pe #(
        .ACT_WIDTH(ACT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .WGT_WIDTH(WGT_WIDTH)
    ) 
    pe_inst(
        .clk(clk),
        .reset(reset),

        .load_weight(load_weight),
        .weight_in(weight_wires[row][col]),
        .weight_out(weight_wires[row+1][col]),

        .act_in(act_wires[row][col]),
        .psum_in(psum_wires[row][col]),

        .act_out(act_wires[row][col+1]),
        .psum_out(psum_wires[row+1][col])
    );    
    end
end  
    

endgenerate
endmodule