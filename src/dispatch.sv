`default_nettype none
`timescale 1ns/1ns

module dispatch #(
    parameter NUM_CORES = 2,
    parameter THREADS_PER_BLOCK = 4
) (
    input wire clk,
    input wire reset,
    input wire start,

    input wire [31:0] thread_count, 

    input wire [NUM_CORES-1:0] core_done, 
    output reg [NUM_CORES-1:0] core_start,
    output reg [NUM_CORES-1:0] core_reset,
    output reg [31:0] core_block_id [NUM_CORES-1:0], 
    output reg [$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0],

    output reg done,
    output wire [31:0] blocks_dispatched_debug, 
    output wire [31:0] blocks_done_debug 
);
    wire [31:0] total_blocks;
    assign total_blocks = (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

    reg [31:0] blocks_dispatched;
    reg [31:0] blocks_done;
    reg active; 

    // Declare loop variable outside the always block to keep Vivado happy
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            done <= 0;
            blocks_dispatched <= 0; 
            blocks_done <= 0;       
            active <= 0;            

            for (i = 0; i < NUM_CORES; i = i + 1) begin
                core_start[i] <= 0;
                core_reset[i] <= 1; 
                core_block_id[i] <= 0;
                core_thread_count[i] <= THREADS_PER_BLOCK;
            end
        end else begin
            if (start) begin
                active <= 1;
                blocks_dispatched <= 0;
                blocks_done <= 0;
                done <= 0;
                for (i = 0; i < NUM_CORES; i = i + 1) begin
                    core_reset[i] <= 1;
                    core_start[i] <= 0;
                end
            end

            if (active && !start) begin    
                // 1. Check for completed cores (Free them up)
                for (i = 0; i < NUM_CORES; i = i + 1) begin
                    if (core_start[i] && core_done[i]) begin
                        core_reset[i] <= 1; 
                        core_start[i] <= 0;
                        blocks_done <= blocks_done + 1; 
                    end
                end

                // 2. TIMING FIX: Deal ONE block to ONE core per clock cycle.
                for (i = 0; i < NUM_CORES; i = i + 1) begin
                    if (core_reset[i] && (blocks_dispatched < total_blocks)) begin 
                        core_reset[i] <= 0; 
                        core_start[i] <= 1;
                        core_block_id[i] <= blocks_dispatched;
                        
                        if (blocks_dispatched == total_blocks - 1 && (thread_count % THREADS_PER_BLOCK != 0)) begin
                            core_thread_count[i] <= (thread_count % THREADS_PER_BLOCK);
                        end else begin
                            core_thread_count[i] <= THREADS_PER_BLOCK;
                        end

                        blocks_dispatched <= blocks_dispatched + 1; 
                        
                        // Break out immediately so Vivado only synthesizes ONE adder!
                        break; 
                    end
                end

                if (blocks_done == total_blocks && total_blocks > 0) begin 
                    done <= 1;
                    active <= 0; 
                end
            end
        end
    end

    assign blocks_dispatched_debug = blocks_dispatched;
    assign blocks_done_debug = blocks_done;             
endmodule