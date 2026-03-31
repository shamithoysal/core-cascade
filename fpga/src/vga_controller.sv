`timescale 1ns / 1ps
`default_nettype none

module vga_controller(
    input  wire clk_40MHz,  // Fed directly from the Clocking Wizard
    input  wire reset,      
    output wire video_on,   
    output wire hsync,      
    output wire vsync,      
    output wire [10:0] x,   // 11 bits needed to count up to 1055
    output wire [10:0] y     
);
    
    // 800x600 @ 60Hz VESA parameters
    parameter HD = 800;             
    parameter HF = 40;              
    parameter HB = 88;              
    parameter HR = 128;              
    parameter HMAX = HD+HF+HB+HR-1; // 1055

    parameter VD = 600;             
    parameter VF = 1;              
    parameter VB = 23;              
    parameter VR = 4;               
    parameter VMAX = VD+VF+VB+VR-1; // 627
    
    // Registers (The Chu Architecture)
    reg [10:0] h_count_reg = 0, h_count_next;
    reg [10:0] v_count_reg = 0, v_count_next;
    reg v_sync_reg = 1'b0, h_sync_reg = 1'b0;
    wire v_sync_next, h_sync_next;
    
    // Register Control (Triggering perfectly on the 40MHz edge)
    always_ff @(posedge clk_40MHz) begin
        if(reset) begin
            v_count_reg <= 0;
            h_count_reg <= 0;
            v_sync_reg  <= 1'b0;
            h_sync_reg  <= 1'b0;
        end else begin 
            v_count_reg <= v_count_next;
            h_count_reg <= h_count_next;
            v_sync_reg  <= v_sync_next;
            h_sync_reg  <= h_sync_next;
        end
    end
         
    // Combinational Next-State Logic
    always_comb begin
        h_count_next = h_count_reg;
        v_count_next = v_count_reg;
        
        if(h_count_reg == HMAX) begin
            h_count_next = 0;
            if(v_count_reg == VMAX)
                v_count_next = 0;
            else
                v_count_next = v_count_reg + 1;
        end else begin
            h_count_next = h_count_reg + 1;
        end
    end
    
    // Sync Logic: POSITIVE polarity for 800x600 (Rests at 0, pulses to 1)
    assign h_sync_next = (h_count_reg >= (HD+HF) && h_count_reg <= (HD+HF+HR-1));
    assign v_sync_next = (v_count_reg >= (VD+VF) && v_count_reg <= (VD+VF+VR-1));
    
    // Outputs
    assign video_on = (h_count_reg < HD) && (v_count_reg < VD);
    assign hsync  = h_sync_reg;
    assign vsync  = v_sync_reg;
    assign x      = h_count_reg;
    assign y      = v_count_reg;
            
endmodule