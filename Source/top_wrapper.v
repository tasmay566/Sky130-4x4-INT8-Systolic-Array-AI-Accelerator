module top_wrapper (
    input  wire        clk,
    input  wire        reset,
    
    // Control Signals
    input  wire        start_load_weights,
    input  wire        start_compute,
    
    // 32-bit Data Input Bus
    input  wire [31:0] data_in,
    
    // 32-bit Data Output Bus
    output reg  [31:0] data_out,
    output reg         valid_out
);

    // 1. FSM States
    localparam STATE_IDLE      = 3'd0;
    localparam STATE_WGT_LOWER = 3'd1;
    localparam STATE_WGT_UPPER = 3'd2;
    localparam STATE_ACT_LOWER = 3'd3;
    localparam STATE_ACT_UPPER = 3'd4;

    reg [2:0] state;
    reg [3:0] count; // To count up to 4 rows/columns

    // 2. The Internal Waiting Room
    reg [63:0] shared_buffer;
    reg        load_weight_internal;

    // 3. The 128-bit output wire from the 4x4 core (4 cols * 32 bits)
    wire [127:0] internal_psum_wire;

    // 4. The Single-Block Synchronous FSM
    always @(posedge clk) begin
        if (reset) begin
            state                <= STATE_IDLE;
            shared_buffer        <= 64'd0;
            load_weight_internal <= 1'b0;
            count                <= 4'd0;
            data_out             <= 32'd0;
            valid_out            <= 1'b0;
        end else begin
            // =========================================================
            // OUTPUT ROUTING: The 4x4 "XOR Fold"
            // We XOR all 4 columns together into the 32-bit output pad.
            // This forces Yosys to synthesize the entire 4x4 array 
            // without needing 128 physical output pins!
            // =========================================================
            data_out <= internal_psum_wire[31:0]   ^
                        internal_psum_wire[63:32]  ^
                        internal_psum_wire[95:64]  ^
                        internal_psum_wire[127:96];
            
            // Default valid signal
            valid_out <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    load_weight_internal <= 1'b0;
                    count <= 4'd0;
                    
                    // Look for command pulses to jump into action
                    if (start_load_weights) begin
                        state <= STATE_WGT_LOWER;
                    end else if (start_compute) begin
                        state <= STATE_ACT_LOWER;
                    end
                end

                // --- WEIGHT LOADING PIPELINE ---
                STATE_WGT_LOWER: begin
                    shared_buffer[31:0]  <= data_in;
                    load_weight_internal <= 1'b0;     // Array is frozen
                    state                <= STATE_WGT_UPPER;
                end

                STATE_WGT_UPPER: begin
                    shared_buffer[63:32] <= data_in;
                    load_weight_internal <= 1'b1;     // Array shifts on next clock edge!
                    
                    if (count == 4'd3) begin          // 0 to 3 = 4 rows loaded
                        state <= STATE_IDLE;
                    end else begin
                        count <= count + 1'b1;
                        state <= STATE_WGT_LOWER;
                    end
                end

                // --- ACTIVATION STREAMING PIPELINE ---
                STATE_ACT_LOWER: begin
                    shared_buffer[31:0]  <= data_in;
                    load_weight_internal <= 1'b0;     // Side doors open, top doors locked
                    state                <= STATE_ACT_UPPER;
                end

                STATE_ACT_UPPER: begin
                    shared_buffer[63:32] <= data_in;
                    load_weight_internal <= 1'b0;     // Side doors open, top doors locked
                    valid_out            <= 1'b1;     // Flag that Matrix A is actively streaming
                    
                    if (count == 4'd3) begin          // 0 to 3 = 4 columns streamed
                        state <= STATE_IDLE;
                    end else begin
                        count <= count + 1'b1;
                        state <= STATE_ACT_LOWER;
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

    // 5. Instantiate the 4x4 Core Engine
    top_accelerator core_engine (
        .clk(clk),
        .reset(reset),
        
        // Feed only the lower 32 bits (4 x 8-bit inputs) into the array
        .weight_in_top(shared_buffer[31:0]), 
        .act_in_flat(shared_buffer[31:0]),   
        
        .load_weight(load_weight_internal),
        
        // Top partial sums tied to ground (0) for 128 bits
        .psum_in_top(128'd0), 
        
        // The math output drops onto the internal wire
        .psum_out_bottom(internal_psum_wire) 
    );

endmodule