`default_nettype none
`timescale 1ns/1ns

module dispatch #(
    parameter NUM_CORES = 2,
    parameter THREADS_PER_BLOCK = 4
) (
    input wire clk,
    input wire reset,
    input wire start,

    // Kernel Metadata
    input wire [7:0] thread_count,

    // Core States
    // Note: In strict Verilog, inputs driven by wires should be wire, but SV allows reg.
    input reg [NUM_CORES-1:0] core_done, 
    output reg [NUM_CORES-1:0] core_start,
    output reg [NUM_CORES-1:0] core_reset,
    output reg [7:0] core_block_id [NUM_CORES-1:0],
    output reg [$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0],

    // Kernel Execution
    output reg done,
    // DEBUG PORTS
    output wire [7:0] blocks_dispatched_debug,
    output wire [7:0] blocks_done_debug
);
    // Calculate the total number of blocks
    wire [7:0] total_blocks;
    assign total_blocks = (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

    reg [7:0] blocks_dispatched;
    reg [7:0] blocks_done;
    
    // NEW: Active state to keep dispatcher running after 'start' pulse drops
    reg active; 

    always @(posedge clk) begin
        if (reset) begin
            done <= 0;
            blocks_dispatched <= 0; // Use Non-Blocking assignments
            blocks_done <= 0;       // Use Non-Blocking assignments
            active <= 0;            // Reset active state

            for (int i = 0; i < NUM_CORES; i++) begin
                core_start[i] <= 0;
                core_reset[i] <= 1; // Keep cores in reset initially
                core_block_id[i] <= 0;
                core_thread_count[i] <= THREADS_PER_BLOCK;
            end
        end else begin
            // 1. Latch the start signal
            if (start) begin
                active <= 1;
                // Reset internal counters on start
                blocks_dispatched <= 0;
                blocks_done <= 0;
                done <= 0;
                // Reset all cores to prepare for new job
                for (int i = 0; i < NUM_CORES; i++) begin
                    core_reset[i] <= 1;
                end
            end

            // 2. Main Logic runs if Active OR Start is high
            if (active || start) begin    
                
                // Check if job is finished
                if (blocks_done == total_blocks) begin 
                    done <= 1;
                    active <= 0; // Turn off dispatcher
                end

                // Logic 1: Dispatch new blocks to cores that just finished resetting
                for (int i = 0; i < NUM_CORES; i++) begin
                    if (core_reset[i]) begin 
                        core_reset[i] <= 0; // Release reset

                        // If there is work left, start the core
                        if (blocks_dispatched < total_blocks) begin 
                            core_start[i] <= 1;
                            core_block_id[i] <= blocks_dispatched;
                            
                            // Calculate partial threads for last block
                            core_thread_count[i] <= (blocks_dispatched == total_blocks - 1 && (thread_count % THREADS_PER_BLOCK != 0)) 
                                ? (thread_count % THREADS_PER_BLOCK)
                                : THREADS_PER_BLOCK;

                            blocks_dispatched <= blocks_dispatched + 1;
                        end
                    end
                end

                // Logic 2: Check for completed cores
                for (int i = 0; i < NUM_CORES; i++) begin
                    if (core_start[i] && core_done[i]) begin
                        // Core finished execution
                        core_reset[i] <= 1; // Reset it so it can pick up next block in next cycle
                        core_start[i] <= 0;
                        blocks_done <= blocks_done + 1; // Increment finished count
                    end
                end
            end
        end
    end

    assign blocks_dispatched_debug = blocks_dispatched;
    assign blocks_done_debug = blocks_done;             
endmodule