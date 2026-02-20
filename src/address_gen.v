`timescale 1ns / 1ps


module address_gen#(parameter address_bits = 30,
parameter width_framebuffer = 10,
parameter framebuffer_base = 1000)(
input [9:0] x,y, // from the VGA buffer 
output [address_bits-1:0] address_xy
    );
    assign address_xy = framebuffer_base + (x + (y)*(width_framebuffer));
endmodule
