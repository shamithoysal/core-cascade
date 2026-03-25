`timescale 1ns / 1ps
`default_nettype none

module fpga_top (
    // ==========================================
    // PHYSICAL BOARD PINS (Inputs)
    // ==========================================
    input  wire clk_100MHz,  // The main oscillator on your FPGA board (Pin E3)
    input  wire reset,       // Connect to a push button (e.g., BTNC Pin U18)
    input  wire start,       // Connect to a switch (e.g., SW0 Pin J15)
    
    // ==========================================
    // PHYSICAL BOARD PINS (Outputs)
    // ==========================================
    output logic done,       // Connect to an LED (e.g., LED0 Pin H17)
    output logic hsync,      // Connect to VGA HSYNC Pin (B11)
    output logic vsync,      // Connect to VGA VSYNC Pin (M2)
    
    // 12-bit VGA Output (4 bits per color for Nexys A7)
    output logic [3:0] vga_r, // 4 physical pins for Red
    output logic [3:0] vga_g, // 4 physical pins for Green
    output logic [3:0] vga_b  // 4 physical pins for Blue
);

    // ==========================================
    // INTERNAL TIED-OFF SIGNALS
    // ==========================================
    // Since the Nexys A7 lacks 32 switches, we safely tie these 
    // to zero inside the module so Vivado doesn't complain.
    logic device_control_write_enable = 1'b0;
    logic [31:0] device_control_data = 32'd0;

    // ==========================================
    // 1. CLOCK DIVIDER (100MHz to 25MHz)
    // ==========================================
    logic [1:0] clk_div;
    logic clk_25MHz;

    always_ff @(posedge clk_100MHz) begin
        if (reset) begin
            clk_div <= 2'b00;
        end else begin
            clk_div <= clk_div + 1'b1;
        end
    end
    assign clk_25MHz = clk_div[1]; // Toggles exactly at 25MHz

    // ==========================================
    // 2. THE BRIDGE WIRES
    // ==========================================
    logic [18:0] bridge_address;
    logic [31:0] bridge_data;
    
    // This wire catches the full 24-bit color from your VGA logic
    logic [23:0] internal_rgb; 

    // ==========================================
    // 3. INSTANTIATE BOX A: The GPU System
    // ==========================================
    gpu_system box_a_gpu (
        .clk(clk_100MHz),
        .reset(reset),
        .start(start),
        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),
        .done(done),

        // Plug the bridge wires into the BRAM's VGA door
        .clk_vga(clk_25MHz),
        .vga_address(bridge_address),
        .vga_read_data(bridge_data),

        // Debug Ports (Left unconnected)
        .current_pc(),
        .core_state(),
        .decoded_ret(),
        .blocks_dispatched(),
        .blocks_done()
    );

    // ==========================================
    // 4. INSTANTIATE BOX B: The VGA Wrapper
    // ==========================================
    top_vga box_b_vga (
        .clk(clk_25MHz),
        .reset(reset),
        
        // Plug the bridge wires into the VGA address generator
        .vga_address_out(bridge_address),
        .bram_data_in(bridge_data),
        
        // Output signals
        .hsync(hsync),
        .vsync(vsync),
        .rgb(internal_rgb) // The 24-bit True Color comes out here
    );

    // ==========================================
    // 5. COLOR TRUNCATION (24-bit to 12-bit) NEXYS DDR4
    // ==========================================
    // We drop the lowest 4 bits of each color channel and route 
    // the top 4 Most Significant Bits (MSBs) to the physical pins.
    assign vga_r = internal_rgb[23:20]; 
    assign vga_g = internal_rgb[15:12]; 
    assign vga_b = internal_rgb[7:4];   

endmodule