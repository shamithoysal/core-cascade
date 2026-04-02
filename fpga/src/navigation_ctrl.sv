`default_nettype none
`timescale 1ns/1ns

module navigation_ctrl (
    input  wire clk,
    input  wire reset,

    // Clean pulses from input_conditioner
    input  wire btn_u, btn_d, btn_l, btn_r, btn_c,
    input  wire zoom_mode, // 0 = In, 1 = Out

    // Current values from config_regs
    input  wire [31:0] curr_x,
    input  wire [31:0] curr_y,
    input  wire [31:0] curr_dx,
    input  wire [31:0] curr_dy,

    // The Shadow Outputs
    output reg [31:0] next_x,
    output reg [31:0] next_y,
    output reg [31:0] next_dx,
    output reg [31:0] next_dy,
    output reg done
);

    localparam IDLE   = 2'b00;
    localparam CALC   = 2'b01;
    localparam FINISH = 2'b10;
    reg [1:0] state;

    wire [31:0] step_x = (curr_dx << 5); 
    wire [31:0] step_y = (curr_dy << 5);

    // --- Button Latches ---
    reg latched_u, latched_d, latched_l, latched_r, latched_c;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            done  <= 0;
            next_x <= 0; next_y <= 0; next_dx <= 0; next_dy <= 0;
            latched_u <= 0; latched_d <= 0; latched_l <= 0; latched_r <= 0; latched_c <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (btn_u || btn_d || btn_l || btn_r || btn_c) begin
                        state <= CALC;
                        // Load current state as the baseline
                        next_x  <= curr_x;
                        next_y  <= curr_y;
                        next_dx <= curr_dx;
                        next_dy <= curr_dy;
                        
                        // LATCH THE PULSES so CALC can see them on the next cycle
                        latched_u <= btn_u;
                        latched_d <= btn_d;
                        latched_l <= btn_l;
                        latched_r <= btn_r;
                        latched_c <= btn_c;
                    end
                end

                CALC: begin
                    // Use the latched values to do the math
                    if (latched_u) next_y <= next_y - step_y;
                    if (latched_d) next_y <= next_y + step_y;
                    if (latched_l) next_x <= next_x - step_x;
                    if (latched_r) next_x <= next_x + step_x;

                    // Perfect Center-Anchored Zoom Logic
                    if (latched_c) begin
                        if (!zoom_mode) begin // ZOOM IN
                            next_dx <= curr_dx - (curr_dx >> 2);
                            next_dy <= curr_dy - (curr_dy >> 2);
                            // Nudge inward by half the lost screen dimensions (800x600 grid)
                            next_x  <= curr_x + (curr_dx * 100);
                            next_y  <= curr_y + (curr_dy * 75);
                        end else begin       // ZOOM OUT
                            next_dx <= curr_dx + (curr_dx >> 2);
                            next_dy <= curr_dy + (curr_dy >> 2);
                            // Nudge outward by half the gained screen dimensions
                            next_x  <= curr_x - (curr_dx * 100);
                            next_y  <= curr_y - (curr_dy * 75);
                        end
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done  <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule