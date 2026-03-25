`timescale 1ns / 1ps
`default_nettype none

module address_gen #(
    parameter int address_bits = 19,
    parameter int width_framebuffer = 640,
    parameter int framebuffer_base = 10
)(
    input  wire [9:0] x, y, // from the VGA buffer 
    output logic [address_bits-1:0] address_xy
);

    assign address_xy = framebuffer_base + (x + (y * width_framebuffer));

endmodule