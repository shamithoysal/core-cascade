`default_nettype none

module nexys_top (
    input  wire clk_100mhz,
    
    // Physical Buttons (The D-Pad)
    input  wire btnC, btnU, btnD, btnL, btnR,
    
    // Physical Switches
    input  wire [15:0] sw,
    
    // Outputs
    output wire [7:0] anode,
    output wire [7:0] cathode,
    output wire led15,  
    output wire led14,  
    output wire led0,   
    
    // Physical VGA Pins
    output wire [3:0] VGA_R, VGA_G, VGA_B,
    output wire VGA_HS, VGA_VS
);

    // --- 0. CLOCK GENERATION (Moved to the absolute top!) ---
    wire clk_95mhz; // Main system clock
    wire clk_40mhz; // VGA clock
    
    clk_wiz_0 pixel_clock_gen (
        .clk_in1(clk_100mhz),
        .clk_out1(clk_40mhz),
        .clk_out2(clk_95mhz)
    );

    // --- 1. INPUT CONDITIONING (Now running on 95 MHz) ---
    wire clean_btnC, clean_btnU, clean_btnD, clean_btnL, clean_btnR;
    
    input_conditioner #(.DETECT_FALLING(1)) cond_C (.clk(clk_95mhz), .raw_in(btnC), .pulse_out(clean_btnC));
    input_conditioner #(.DETECT_FALLING(1)) cond_U (.clk(clk_95mhz), .raw_in(btnU), .pulse_out(clean_btnU));
    input_conditioner #(.DETECT_FALLING(1)) cond_D (.clk(clk_95mhz), .raw_in(btnD), .pulse_out(clean_btnD));
    input_conditioner #(.DETECT_FALLING(1)) cond_L (.clk(clk_95mhz), .raw_in(btnL), .pulse_out(clean_btnL));
    input_conditioner #(.DETECT_FALLING(1)) cond_R (.clk(clk_95mhz), .raw_in(btnR), .pulse_out(clean_btnR));

    // Synchronize switches (Added ASYNC_REG attribute for safety)
    (* ASYNC_REG = "TRUE" *) reg sync_sw0_0, sync_sw0_1;
    (* ASYNC_REG = "TRUE" *) reg sync_sw15_0, sync_sw15_1;
    always_ff @(posedge clk_95mhz) begin
        sync_sw0_0  <= sw[0];  sync_sw0_1  <= sync_sw0_0;
        sync_sw15_0 <= sw[15]; sync_sw15_1 <= sync_sw15_0;
    end

    // --- 2. GPU SYSTEM INSTANTIATION ---
    wire gpu_done;
    wire [31:0] dummy_pixel_data;
    wire [11:0] top_vga_color;

    fpga_gpu_sys system (
        .clk_95mhz(clk_95mhz), 
        .clk_40mhz(clk_40mhz),
        .reset(1'b0), 
        .start(1'b0), 
        
        .btnC_pulse(clean_btnC), .btnU_pulse(clean_btnU), .btnD_pulse(clean_btnD),
        .btnL_pulse(clean_btnL), .btnR_pulse(clean_btnR),
        .sw0_sync(sync_sw0_1), .sw15_sync(sync_sw15_1),
        
        .done(gpu_done),
        .debug_pixel_out(dummy_pixel_data),
        .vga_color_out(top_vga_color),
        .hsync(VGA_HS),
        .vsync(VGA_VS)
    );

    assign {VGA_R, VGA_G, VGA_B} = top_vga_color;

    // --- 3. PERIPHERALS & UI ---
    assign led15 = gpu_done;       
    assign led14 = ^dummy_pixel_data; 
    assign led0  = sync_sw0_1;     

    reg [31:0] cycle_counter = 0;
    always_ff @(posedge clk_95mhz) begin
        if (sync_sw15_1 || clean_btnC || clean_btnU || clean_btnD || clean_btnL || clean_btnR) begin
            cycle_counter <= 0; 
        end else if (!gpu_done) begin
            cycle_counter <= cycle_counter + 1;
        end
    end

    seven_seg display (
        .clk(clk_95mhz),
        .data(cycle_counter),
        .anode(anode),
        .cathode(cathode)
    );
endmodule