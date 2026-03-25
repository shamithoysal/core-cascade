`timescale 1ns/1ps
`default_nettype none

module framebuffer_bram (
    // ==========================================
    // PORT 1: GPU WRITE PORT (Clocked by GPU)
    // ==========================================
    input  wire clk_gpu,
    input  wire mem_write_valid,
    input  wire [18:0] mem_write_address,
    input  wire [31:0] mem_write_data,
    output wire mem_write_ready,      // Added handshake signal

    // ==========================================
    // PORT 2: GPU READ PORT (Clocked by GPU)
    // ==========================================
    // Uses clk_gpu from above
    input  wire mem_read_valid,
    input  wire [18:0] mem_read_address,
    output reg  [31:0] mem_read_data,
    output wire mem_read_ready,       // Added handshake signal

    // ==========================================
    // PORT 3: VGA READ PORT (Clocked by VGA)
    // ==========================================
    input  wire clk_vga,
    input  wire [18:0] vga_address,
    output reg  [31:0] vga_read_data
);

    // The massive memory array (524,288 addresses of 32-bit words)
    reg [31:0] memory_array [0:524287];

    // ==========================================
    // HANDSHAKE LOGIC
    // ==========================================
    // FPGA Block RAM is always ready to accept an operation on the next clock edge.
    // Tying these high perfectly matches your controller's READ_WAITING state!
    assign mem_write_ready = 1'b1;
    assign mem_read_ready  = 1'b1;

    // ==========================================
    // INITIALIZATION (USING .HEX FILE)
    // ==========================================
    initial begin
        // Synthesis tools (like Vivado/Quartus) FULLY support $readmemh.
        // It will embed the contents of data_mem.hex directly into the FPGA bitstream!
        $readmemh("data_mem.hex", memory_array);
    end

    // ==========================================
    // GPU SYNCHRONOUS LOGIC (WRITE & READ)
    // ==========================================
    always_ff @(posedge clk_gpu) begin
        // Write Port
        if (mem_write_valid) begin
            memory_array[mem_write_address] <= mem_write_data;
        end
        
        // Read Port
        if (mem_read_valid) begin
            mem_read_data <= memory_array[mem_read_address]; 
        end
    end

    // ==========================================
    // VGA SYNCHRONOUS LOGIC (READ ONLY)
    // ==========================================
    always_ff @(posedge clk_vga) begin
        // The VGA controller will ask for an address, and the data 
        // will appear on 'vga_read_data' on the NEXT clock cycle.
        vga_read_data <= memory_array[vga_address];
    end

endmodule