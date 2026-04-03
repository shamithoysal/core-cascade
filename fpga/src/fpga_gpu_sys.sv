`default_nettype none
`timescale 1ns/1ns

module fpga_gpu_sys (
    input wire clk_95mhz, 
    input wire clk_40mhz,
    input wire reset,
    input wire start,

    input wire btnC_pulse, btnU_pulse, btnD_pulse, btnL_pulse, btnR_pulse,
    input wire sw0_sync,   
    input wire sw15_sync,  

    output wire done,
    output wire [31:0] debug_pixel_out,
    
    output wire [11:0] vga_color_out,
    output wire hsync,
    output wire vsync
);

    // --- 1. PROGRAM MEMORY (ROM) ---
    (* ram_style = "distributed" *) reg [15:0] program_mem [0:255];
    initial $readmemh("program_mem.hex", program_mem);
    
    logic [7:0] p_read_addr [7:0]; 
    logic [15:0] p_read_data [7:0]; 
    logic [7:0] p_read_valid; 
        
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : rom_ports
            always_comb begin
                p_read_data[i] = program_mem[p_read_addr[i]];
            end
        end
    endgenerate

    // --- 2. DYNAMIC CONFIGURATION ---
    reg [31:0] config_regs [0:7];
    wire [31:0] shadow_x, shadow_y, shadow_dx, shadow_dy;
    wire nav_done;

    navigation_ctrl nav_unit (
        .clk(clk_95mhz),
        .reset(reset || sw15_sync),
        .btn_u(btnU_pulse), .btn_d(btnD_pulse), .btn_l(btnL_pulse), .btn_r(btnR_pulse), .btn_c(btnC_pulse),
        .zoom_mode(sw0_sync),
        .curr_x(config_regs[0]), .curr_y(config_regs[1]),
        .curr_dx(config_regs[2]), .curr_dy(config_regs[3]),
        .next_x(shadow_x), .next_y(shadow_y), .next_dx(shadow_dx), .next_dy(shadow_dy),
        .done(nav_done)
    );

    // CDC FIX: Bring 40MHz vsync safely into the 95MHz domain
    (* ASYNC_REG = "TRUE" *) reg vsync_sync_0, vsync_safe;
    always_ff @(posedge clk_95mhz) begin
        vsync_sync_0 <= vsync;
        vsync_safe   <= vsync_sync_0;
    end

    reg nav_pending = 0;
    reg [2:0] sys_state = 3'd0; 

    always_ff @(posedge clk_95mhz) begin
        if (reset || sw15_sync) begin
            config_regs[0] <= 32'hFD400000;
            config_regs[1] <= 32'hFE800000;
            config_regs[2] <= 32'h00014CCC;
            config_regs[3] <= 32'h00014CCC;
            config_regs[4] <= 32'd255;      
            config_regs[5] <= 32'h04000000;
            config_regs[6] <= 32'd800;      
            config_regs[7] <= 32'h000051EC;
            
            nav_pending <= 0;
            sys_state <= 3'd0; 
        end else begin
            if (nav_done) nav_pending <= 1;

            if (sys_state == 3'd4) begin
                if (nav_pending && vsync_safe) begin // USE THE SYNCHRONIZED SIGNAL HERE
                    config_regs[0] <= shadow_x;
                    config_regs[1] <= shadow_y;
                    config_regs[2] <= shadow_dx;
                    config_regs[3] <= shadow_dy;
                    nav_pending <= 0;
                    sys_state <= 3'd0; 
                end
            end else begin
                sys_state <= sys_state + 1;
            end
        end
    end

    wire combined_reset = (sys_state == 3'd0) || (sys_state == 3'd1);
    wire auto_we        = (sys_state == 3'd2);
    wire combined_start = (sys_state == 3'd3) || start;


    // --- 3. THE FRAMEBUFFER (BRAM) ---
    logic [0:0] d_write_valid;
    logic [0:0] d_read_valid; 
    logic [18:0] d_read_addr [0:0];
    logic [18:0] d_write_addr [0:0];
    logic [31:0] d_write_data [0:0];
    
    logic [31:0] bram_read_data [0:0]; 
    logic [31:0] final_read_data [0:0];

    wire [7:0] bram_dout_8bit; 
    wire [7:0] bram_portb_out;
    
    logic [0:0] d_read_ready_delayed; 
    always_ff @(posedge clk_95mhz) begin
        d_read_ready_delayed[0] <= d_read_valid[0];
    end

    bram #(
        .ADDR_WIDTH(19),  
        .DATA_WIDTH(8)    
    ) fb_bram (
        .clka(clk_95mhz),
        .wea(d_write_valid[0]),
        .addra(d_write_valid[0] ? d_write_addr[0][18:0] : d_read_addr[0][18:0]),
        .dina(d_write_data[0][7:0]), 
        .douta(bram_dout_8bit),
        
        .clkb(clk_40mhz), 
        .web(1'b0),
        .addrb(pixel_index[18:0]), 
        .dinb(8'h0),
        .doutb(bram_portb_out)
    );

    assign bram_read_data[0] = {24'd0, bram_dout_8bit};
    assign final_read_data[0] = (d_read_addr[0] < 19'd10) ? config_regs[d_read_addr[0]] : bram_read_data[0];

    // --- 4. VGA DISPLAY SUBSYSTEM ---
    wire video_on_raw, hsync_raw, vsync_raw;
    wire [10:0] vga_x, vga_y;

    // CDC FIX: Bring 95MHz reset safely into the 40MHz domain
    (* ASYNC_REG = "TRUE" *) reg vga_rst_meta, vga_rst_sync;
    always_ff @(posedge clk_40mhz) begin
        vga_rst_meta <= (reset || sw15_sync);
        vga_rst_sync <= vga_rst_meta;
    end
    
    vga_controller vga_ctrl (
        .clk_40MHz(clk_40mhz),
        .reset(vga_rst_sync),
        .hsync(hsync_raw),
        .vsync(vsync_raw),
        .video_on(video_on_raw),
        .x(vga_x),
        .y(vga_y)
    );

    reg video_on_d;
    reg hsync_reg, vsync_reg;

    always_ff @(posedge clk_40mhz) begin
        video_on_d <= video_on_raw;
        hsync_reg  <= hsync_raw;
        vsync_reg  <= vsync_raw;
    end

    assign hsync = hsync_reg;
    assign vsync = vsync_reg;

    wire [19:0] pixel_index = (vga_y * 800) + vga_x; 

    wire [11:0] mapped_color;
    color_mapper cmap (
        .iter_count(video_on_d ? bram_portb_out : 8'h00),
        .vga_color(mapped_color)
    );

    assign vga_color_out = video_on_d ? mapped_color : 12'h000;

    // --- 5. THE GPU CORE ---
    gpu #(
        .DATA_MEM_ADDR_BITS(19), 
        .DATA_MEM_DATA_BITS(32), 
        .DATA_MEM_NUM_CHANNELS(1), 
        .PROGRAM_MEM_ADDR_BITS(8), 
        .PROGRAM_MEM_DATA_BITS(16), 
        .PROGRAM_MEM_NUM_CHANNELS(8), 
        .NUM_CORES(8)
    ) core (
        .clk(clk_95mhz), 
        .reset(combined_reset), 
        .start(combined_start), 
        .done(done),
        
        .device_control_write_enable(auto_we), 
        .device_control_data(32'd480000),  
        
        .program_mem_read_valid(p_read_valid), 
        .program_mem_read_address(p_read_addr), 
        .program_mem_read_ready(8'hFF), 
        .program_mem_read_data(p_read_data),
        
        .data_mem_read_valid(d_read_valid), .data_mem_read_address(d_read_addr), 
        .data_mem_read_ready(d_read_ready_delayed), .data_mem_read_data(final_read_data), 
        
        .data_mem_write_valid(d_write_valid), .data_mem_write_address(d_write_addr), 
        .data_mem_write_data(d_write_data), .data_mem_write_ready(1'b1)
    );

    assign debug_pixel_out = bram_read_data[0];
    
endmodule