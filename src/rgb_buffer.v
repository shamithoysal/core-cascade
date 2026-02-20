`timescale 1ns / 1ps
module rgb_buffer(
	input clk_100MHz,      // from FPGA
	input reset,
	input [23:0] sw,       // 24 bits for color
	output hsync, 
	output vsync,
	output [23:0] rgb ,     // 24 FPGA pins for RGB(8 per color)
	output [9:0] x,y
);
	
	// Signal Declaration
	reg [23:0] rgb_reg;    // register for 24-bit RGB DAC 
	wire video_on;         // Same signal as in controller

    // Instantiate VGA Controller
    vga_controller vga_c(.clk_100MHz(clk_100MHz), .reset(reset), .hsync(hsync), .vsync(vsync),
                         .video_on(video_on), .p_tick(), .x(x), .y(y));
    // RGB Buffer
    always @(posedge clk_100MHz or posedge reset)
    if (reset)
       rgb_reg <= 0;
    else
       rgb_reg <= sw;
    
    // Output
    assign rgb = (video_on) ? rgb_reg : 24'b0;   // while in display area RGB color = sw, else all OFF
        
endmodule