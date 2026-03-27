`default_nettype none

module nexys_top (
    input wire clk_100mhz,
    input wire btnC, // Center Button: Start
    input wire btnU, // Up Button: Hard Reset
    
    output wire [7:0] anode,
    output wire [7:0] cathode,
    output wire led15,  // DONE indicator
    output wire led14
);

    wire gpu_done;
    reg [31:0] cycle_counter = 0;
    wire [31:0] dummy_pixel_data;
    
    typedef enum logic [1:0] {IDLE, RUNNING, DONE} state_t;
    state_t state = IDLE;

    reg gpu_start = 0;

    always_ff @(posedge clk_100mhz) begin
        if (btnU) begin
            state <= IDLE;
            cycle_counter <= 0;
            gpu_start <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (btnC) begin
                        state <= RUNNING;
                        gpu_start <= 1; // Pulse start
                    end
                end
                RUNNING: begin
                    gpu_start <= 0; // Turn off start pulse
                    cycle_counter <= cycle_counter + 1;
                    if (gpu_done) state <= DONE;
                end
                DONE: begin
                    // Freeze counter, wait for reset
                end
            endcase
        end
    end

    assign led15 = (state == DONE);
    assign led14 = ^dummy_pixel_data;

    // Instantiate GPU
    fpga_gpu_sys system (
        .clk(clk_100mhz),
        .reset(btnU),
        .start(gpu_start),
        .done(gpu_done),
        .debug_pixel_out(dummy_pixel_data)
    );

    // Instantiate 7-Segment
    seven_seg display (
        .clk(clk_100mhz),
        .data(cycle_counter),
        .anode(anode),
        .cathode(cathode)
    );

endmodule