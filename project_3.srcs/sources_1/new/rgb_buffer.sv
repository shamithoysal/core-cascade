`timescale 1ns / 1ps
`default_nettype none

module rgb_buffer(
    input  wire clk_100MHz,      
    input  wire reset,
    input  wire [23:0] sw,       
    output logic hsync, 
    output logic vsync,
    output logic [23:0] rgb,     
    output logic [9:0] x, y
);
    
    logic [23:0] rgb_reg;    
    logic video_on;         

    vga_controller vga_c(
        .clk_100MHz(clk_100MHz), 
        .reset(reset), 
        .hsync(hsync), 
        .vsync(vsync),
        .video_on(video_on), 
        .p_tick(), 
        .x(x), 
        .y(y)
    );

    always_ff @(posedge clk_100MHz or posedge reset) begin
        if (reset)
            rgb_reg <= '0;
        else
            rgb_reg <= sw;
    end
    
    assign rgb = video_on ? rgb_reg : 24'b0;   
        
endmodule