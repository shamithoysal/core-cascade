`default_nettype none

module nexys_top (
    input  wire clk_100mhz,
    
    // Physical Buttons (The D-Pad)
    input  wire btnC, // Center: Zoom In/Out
    input  wire btnU, // Up: Pan Up
    input  wire btnD, // Down: Pan Down
    input  wire btnL, // Left: Pan Left
    input  wire btnR, // Right: Pan Right
    
    // Physical Switches
    input  wire [15:0] sw, // sw[0] = Zoom Mode, sw[15] = Nuclear Reset
    
    // Outputs
    output wire [7:0] anode,
    output wire [7:0] cathode,
    output wire led15,  // Lights up when GPU is DONE
    output wire led14,  // Dummy pixel toggle
    output wire led0,   // Indicates Zoom OUT mode is active
    
    // Physical VGA Pins
    output wire [3:0] VGA_R,
    output wire [3:0] VGA_G,
    output wire [3:0] VGA_B,
    output wire VGA_HS,
    output wire VGA_VS
);

    // --- 1. INPUT CONDITIONING (The Clean Room) ---
    wire clean_btnC, clean_btnU, clean_btnD, clean_btnL, clean_btnR;
    
    // DETECT_FALLING = 1 means it only triggers when you RELEASE the button
    input_conditioner #(.DETECT_FALLING(1)) cond_C (.clk(clk_100mhz), .raw_in(btnC), .pulse_out(clean_btnC));
    input_conditioner #(.DETECT_FALLING(1)) cond_U (.clk(clk_100mhz), .raw_in(btnU), .pulse_out(clean_btnU));
    input_conditioner #(.DETECT_FALLING(1)) cond_D (.clk(clk_100mhz), .raw_in(btnD), .pulse_out(clean_btnD));
    input_conditioner #(.DETECT_FALLING(1)) cond_L (.clk(clk_100mhz), .raw_in(btnL), .pulse_out(clean_btnL));
    input_conditioner #(.DETECT_FALLING(1)) cond_R (.clk(clk_100mhz), .raw_in(btnR), .pulse_out(clean_btnR));

    // Synchronize switches to prevent metastability
    reg sync_sw0_0, sync_sw0_1;
    reg sync_sw15_0, sync_sw15_1;
    always_ff @(posedge clk_100mhz) begin
        sync_sw0_0  <= sw[0];  sync_sw0_1  <= sync_sw0_0;
        sync_sw15_0 <= sw[15]; sync_sw15_1 <= sync_sw15_0;
    end

    // --- 2. GPU SYSTEM INSTANTIATION ---
    wire gpu_done;
    wire [31:0] dummy_pixel_data;
    wire [11:0] top_vga_color;

    fpga_gpu_sys system (
        .clk(clk_100mhz),
        .reset(1'b0), // Reset is now handled internally via sw[15] nuclear option
        .start(1'b0), // Start is now handled by the auto-start pulse internally
        
        // The Interactive Hooks
        .btnC_pulse(clean_btnC),
        .btnU_pulse(clean_btnU),
        .btnD_pulse(clean_btnD),
        .btnL_pulse(clean_btnL),
        .btnR_pulse(clean_btnR),
        .sw0_sync(sync_sw0_1),
        .sw15_sync(sync_sw15_1),
        
        // Outputs
        .done(gpu_done),
        .debug_pixel_out(dummy_pixel_data),
        .vga_color_out(top_vga_color),
        .hsync(VGA_HS),
        .vsync(VGA_VS)
    );

    // Map 12-bit color to physical pins
    assign {VGA_R, VGA_G, VGA_B} = top_vga_color;

    // --- 3. PERIPHERALS & UI ---
    assign led15 = gpu_done;       // High when finished rendering
    assign led14 = ^dummy_pixel_data; // Prevent logic optimization
    assign led0  = sync_sw0_1;     // Visual indicator for "Zoom Out" mode

    // Cycle counter: Only counts while GPU is actively calculating
    reg [31:0] cycle_counter = 0;
    always_ff @(posedge clk_100mhz) begin
        if (sync_sw15_1 || clean_btnC || clean_btnU || clean_btnD || clean_btnL || clean_btnR) begin
            cycle_counter <= 0; // Reset counter on any movement
        end else if (!gpu_done) begin
            cycle_counter <= cycle_counter + 1;
        end
    end

    seven_seg display (
        .clk(clk_100mhz),
        .data(cycle_counter),
        .anode(anode),
        .cathode(cathode)
    );

endmodule