`default_nettype none

module input_conditioner #(
    parameter CLK_FREQ = 100_000_000,
    parameter DETECT_FALLING = 1 // 1 for pulse on release, 0 for pulse on press
)(
    input  wire clk,
    input  wire raw_in,
    output reg  pulse_out
);

    // 1. Two-Stage Synchronizer (Metastability Guard)
    // 
    reg sync_0, sync_1;
    always @(posedge clk) begin
        sync_0 <= raw_in;
        sync_1 <= sync_0;
    end

    // 2. Debouncer (Ignore Noise < 10ms)
    // 
    localparam THRESHOLD = CLK_FREQ / 100; // 10ms
    reg [19:0] count;
    reg stable_in;

    always @(posedge clk) begin
        if (sync_1 != stable_in) begin
            if (count == THRESHOLD) begin
                stable_in <= sync_1;
                count <= 0;
            end else begin
                count <= count + 1;
            end
        end else begin
            count <= 0;
        end
    end

    // 3. Edge Detector (Pulse Generator)
    // 
    reg prev_stable;
    always @(posedge clk) begin
        prev_stable <= stable_in;
        if (DETECT_FALLING)
            pulse_out <= (prev_stable && !stable_in); // Falling Edge (Release)
        else
            pulse_out <= (!prev_stable && stable_in); // Rising Edge (Press)
    end

endmodule