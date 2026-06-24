module data_skew_buffer #(
    parameter N = 4,
    parameter ACT_WIDTH = 8
)(
    input  wire clk,
    input  wire reset,
    
    // The raw, unskewed matrix column coming from the host CPU
    input  wire signed [(N * ACT_WIDTH)-1:0]  act_in_flat,
    
    // The staggered "wavefront" output going to the Systolic Array
    output wire signed [(N * ACT_WIDTH)-1:0]  act_out_skewed
);

//here, act_in_flat represent the vertical array of the input matrix elements.
//act_out_skewed represents the vertical array of the skewed, ie delayed elements(staircase) that are passing to the PEs

//note: here, it is assumed that the act_in_flat is the array which containes the elements of the rows of the original input matrix.
/*for eg for a 2x2 matrix, act_in_flat ={a00 ----> PE00
                                         a01}----> PE10  */




genvar row;

generate
    for( row=0; row<N ; row= row+1) begin: skew_logic

        //for the very first row, there is no need of any dff, so act_out_skewed is directly assigned as act_in_flat
        if( row==0) begin
            assign act_out_skewed[(row*ACT_WIDTH) +: ACT_WIDTH] = act_in_flat[(row*ACT_WIDTH) +: ACT_WIDTH];
        end 



        //for row>0, we need dffs in order to create delays. Here, the 'shift_reg' is nothing but the dff.
        else begin

            reg signed [ACT_WIDTH-1:0] shift_reg [0:row-1];  //number of dffs needed is equal to the index of the row.
            integer i;  //i represents the index of the dff. i=0 is the first dff of the row ie, the leftmost dff.

            always@(posedge clk) begin
                if(reset) begin
                    for(i=0; i<row; i=i+1) begin
                        shift_reg[i]<=0;
                    end
                end
                else begin 
                    shift_reg[0]<= act_in_flat[(row*ACT_WIDTH) +: ACT_WIDTH]; //this is the core logic of this skew buffer
                    
                    for(i=1; i<row; i=i+1) begin
                        shift_reg[i]<= shift_reg[i-1];  //the current dff needs to be updated with the value before it in the consecutive clock cycle
                    end
                    end
            end



        assign act_out_skewed[(row*ACT_WIDTH) +: ACT_WIDTH] = shift_reg[row-1];


        end
    end
endgenerate
endmodule



