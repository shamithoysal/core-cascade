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
    input wire [31:0] thread_count, // Expanded

    // Core States
    input wire [NUM_CORES-1:0] core_done, 
    output reg [NUM_CORES-1:0] core_start,
    output reg [NUM_CORES-1:0] core_reset,
    output reg [31:0] core_block_id [NUM_CORES-1:0], // Expanded
    output reg [$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0],

    // Kernel Execution
    output reg done,
    
    // DEBUG PORTS
    output wire [31:0] blocks_dispatched_debug, // Expanded
    output wire [31:0] blocks_done_debug // Expanded
);
    // Calculate the total number of blocks
    wire [31:0] total_blocks;
    assign total_blocks = (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

    reg [31:0] blocks_dispatched;
    reg [31:0] blocks_done;
    
    // Active state to keep dispatcher running after 'start' pulse drops
    reg active; 

    always @(posedge clk) begin
        if (reset) begin
            done <= 0;
            blocks_dispatched <= 0; 
            blocks_done <= 0;       
            active <= 0;            

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
                
                // ---- DISPATCH ACCUMULATORS ----
                integer next_dispatched;
                integer next_done;
                
                next_dispatched = blocks_dispatched; // Blocking read
                next_done = blocks_done;             // Blocking read

                // Logic 1: Dispatch new blocks to cores that just finished resetting
                for (int i = 0; i < NUM_CORES; i++) begin
                    if (core_reset[i]) begin 
                        core_reset[i] <= 0; // Release reset

                        // If there is work left, start the core
                        if (next_dispatched < total_blocks) begin 
                            core_start[i] <= 1;
                            core_block_id[i] <= next_dispatched;
                            
                            // Calculate partial threads for last block using the updated accumulator
                            core_thread_count[i] <= (next_dispatched == total_blocks - 1 && (thread_count % THREADS_PER_BLOCK != 0)) 
                                ? (thread_count % THREADS_PER_BLOCK)
                                : THREADS_PER_BLOCK;

                            // Update accumulator IMMEDIATELY so the next core sees it
                            next_dispatched = next_dispatched + 1; 
                        end
                    end
                end

                // Logic 2: Check for completed cores
                for (int i = 0; i < NUM_CORES; i++) begin
                    if (core_start[i] && core_done[i]) begin
                        // Core finished execution
                        core_reset[i] <= 1; // Reset it so it can pick up next block in next cycle
                        core_start[i] <= 0;
                        
                        // Update done accumulator IMMEDIATELY
                        next_done = next_done + 1; 
                    end
                end

                // ---- COMMIT STATE ----
                // Dump the final accumulated values into the physical registers at the clock edge
                blocks_dispatched <= next_dispatched;
                blocks_done <= next_done;

                // Check if job is finished
                if (next_done == total_blocks) begin 
                    done <= 1;
                    active <= 0; // Turn off dispatcher
                end
            end
        end
    end

    assign blocks_dispatched_debug = blocks_dispatched;
    assign blocks_done_debug = blocks_done;             
endmodule