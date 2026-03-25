`timescale 1ns / 1ps
`default_nettype none

module palette_index #(
    parameter int max_iter = 256
)(
    input  wire [31:0] iteration_count,  // from the framebuffer
    output logic [23:0] sw               // RGB color output
);

    always_comb begin
        if (iteration_count == 32'd255) begin
            sw = 24'h000000; // Inside Mandelbrot (converging)
        end
        else if (iteration_count < 4)  begin sw = 24'h000010; end 
        else if (iteration_count < 8)  begin sw = 24'h000020; end
        else if (iteration_count < 12) begin sw = 24'h000030; end
        else if (iteration_count < 16) begin sw = 24'h000050; end
        else if (iteration_count < 24) begin sw = 24'h000080; end
        else if (iteration_count < 32) begin sw = 24'h0010A0; end
        else if (iteration_count < 40) begin sw = 24'h0020C0; end
        else if (iteration_count < 48) begin sw = 24'h0040E0; end
        else if (iteration_count < 64) begin sw = 24'h0060FF; end
        else if (iteration_count < 96) begin sw = 24'h0080FF; end
        else if (iteration_count < 128)begin sw = 24'h00A0FF; end
        else if (iteration_count < 192)begin sw = 24'h00E0FF; end
        else begin 
            sw = 24'hFFFFFF; // Default fallback
        end
    end

endmodule