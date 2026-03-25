`timescale 1ns / 1ps
`default_nettype none

module top_vga #(
    parameter int address_bits = 19, 
    parameter int max_iter = 256
)(
    input  wire clk,
    input  wire reset,
    
    // ==========================================
    // EXTERNAL MEMORY INTERFACE (To BRAM in GPU)
    // ==========================================
    output logic [address_bits-1:0] vga_address_out, // Sends requested (x,y) address to BRAM
    input  wire  [31:0] bram_data_in,                // Receives the iteration data from BRAM
    
    // ==========================================
    // PHYSICAL VGA PINS
    // ==========================================
    output logic hsync, 
    output logic vsync,
    output logic [23:0] rgb
);

    // Internal interconnect logic
    logic [9:0] x, y;
    logic [address_bits-1:0] address_xy;
    logic [23:0] sw;
    logic [31:0] iteration_count;
    
    // 1. Send the calculated address OUT to the BRAM
    assign vga_address_out = address_xy;
    
    // 2. Route the incoming BRAM data directly to our iteration count wire
    // (Since we updated palette_index.sv to accept a 32-bit input)
    assign iteration_count = bram_data_in;

    // ---------------------------------------------------------
    // SUB-MODULE INSTANTIATIONS
    // ---------------------------------------------------------
    
    // VGA Controller Wrapper
    rgb_buffer u1 (
        .clk_100MHz(clk),
        .reset(reset),
        .sw(sw),
        .hsync(hsync),
        .vsync(vsync),
        .rgb(rgb),
        .x(x),
        .y(y)
    );
                  
    // 1D Address Calculator
    address_gen u2 (
        .x(x),
        .y(y),
        .address_xy(address_xy)
    );
                    
    // Color Lookup Table
    palette_index u3 (
        .iteration_count(iteration_count),
        .sw(sw)
    );
                    
endmodule