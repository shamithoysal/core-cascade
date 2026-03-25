`timescale 1ns / 1ps
`default_nettype none

module vga_controller (
    input  wire clk_100MHz,   // from FPGA
    input  wire reset,        // system reset
    output logic video_on,    // ON while pixel counts for x and y are within display area
    output logic hsync,       // horizontal sync 
    output logic vsync,       // vertical sync 
    output logic p_tick,      // 25MHz pixel tick
    output logic [9:0] x,     // pixel count x
    output logic [9:0] y      // pixel count y
);
    
    // Internal Constants (Using localparam for SV best practice)
    localparam int HD = 640;             
    localparam int HF = 48;              
    localparam int HB = 16;              
    localparam int HR = 96;              
    localparam int HMAX = HD+HF+HB+HR-1; 
    
    localparam int VD = 480;             
    localparam int VF = 10;              
    localparam int VB = 33;              
    localparam int VR = 2;               
    localparam int VMAX = VD+VF+VB+VR-1; 

    // Generate 25MHz from 100MHz
    logic [1:0] r_25MHz;
    logic w_25MHz;
    
    always_ff @(posedge clk_100MHz or posedge reset) begin
        if(reset)
            r_25MHz <= '0;
        else
            r_25MHz <= r_25MHz + 1;
    end
    
    assign w_25MHz = (r_25MHz == 2'b00) ? 1'b1 : 1'b0; 
    assign p_tick = w_25MHz;

    // Counters and sync registers
    logic [9:0] h_count_reg, h_count_next;
    logic [9:0] v_count_reg, v_count_next;
    logic v_sync_reg, h_sync_reg;
    logic v_sync_next, h_sync_next;

    always_ff @(posedge clk_100MHz or posedge reset) begin
        if(reset) begin
            v_count_reg <= '0;
            h_count_reg <= '0;
            v_sync_reg  <= 1'b0;
            h_sync_reg  <= 1'b0;
        end else if(w_25MHz) begin
            v_count_reg <= v_count_next;
            h_count_reg <= h_count_next;
            v_sync_reg  <= v_sync_next;
            h_sync_reg  <= h_sync_next;
        end
    end
         
    always_comb begin
        h_count_next = h_count_reg;
        if(h_count_reg == HMAX)                 
            h_count_next = '0;
        else
            h_count_next = h_count_reg + 1;         
    end
  
    always_comb begin
        v_count_next = v_count_reg;
        if(h_count_reg == HMAX) begin                 
            if(v_count_reg == VMAX)           
                v_count_next = '0;
            else
                v_count_next = v_count_reg + 1;
        end
    end
        
    assign h_sync_next = (h_count_reg >= (HD+HB) && h_count_reg <= (HD+HB+HR-1));
    assign v_sync_next = (v_count_reg >= (VD+VB) && v_count_reg <= (VD+VB+VR-1));
    
    assign video_on = (h_count_reg < HD) && (v_count_reg < VD);
    
    assign hsync = h_sync_reg;
    assign vsync = v_sync_reg;
    assign x = h_count_reg;
    assign y = v_count_reg;

endmodule