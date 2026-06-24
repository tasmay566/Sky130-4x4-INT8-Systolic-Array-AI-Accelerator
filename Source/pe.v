module pe #( 
    parameter ACT_WIDTH = 8,   // 8-bit Activations (Inputs)
    parameter WGT_WIDTH = 8,   // 8-bit Weights 
    parameter PSUM_WIDTH = 32  // 32-bit Partial Sums (Accumulator)
)(
    input  wire                   clk,
    input  wire                   reset,
    input  wire signed [ACT_WIDTH-1:0]   act_in,     // Comes from the left
    input  wire signed [WGT_WIDTH-1:0]   weight_in,  // Loaded during configuration
    input  wire signed [PSUM_WIDTH-1:0]  psum_in,    // Comes from the top
    output reg  signed [ACT_WIDTH-1:0]   act_out,    // Goes to the right
    output reg  signed [PSUM_WIDTH-1:0]  psum_out,   // Goes to the bottom
    
    output wire signed [WGT_WIDTH-1:0]   weight_out, // Goes to the bottom for weight loading

    input wire load_weight    //control signal to load weight into the pe
);

reg signed [WGT_WIDTH-1:0] weight_reg;
assign weight_out = weight_reg;

always @(posedge clk) begin
if (reset) begin
    act_out<= 0;
    psum_out<=0;
    weight_reg<=0;
end
else if(load_weight) begin
    weight_reg<= weight_in;      //this loads the internal register inside the pe with the input weight
end
else begin

    psum_out <= (act_in*weight_reg) + psum_in;  //this is the core mathematical logic of the pe.
    act_out <= act_in;
end
    
end



endmodule

