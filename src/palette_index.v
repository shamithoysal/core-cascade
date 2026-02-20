`timescale 1ns / 1ps


module palette_index#(parameter max_iter = 256)(
input [$clog2(max_iter)-1:0] iteration_count,  // from the framebuffer the count for the (x,y) iterations
output reg [23:0] sw // input to the VGA buffer for synchrnoisation with other parameters of the VGA buffer
    );
    always @(*) begin
    if (iteration_count == 8'd255) begin
        // Inside Mandelbrot (converging)
        sw = 24'h000000;
    end
    else if (iteration_count < 4) begin
        sw = 24'h000010;   // almost black blue
    end
    else if (iteration_count < 8) begin
        sw = 24'h000020;
    end
    else if (iteration_count < 12) begin
        sw = 24'h000030;
    end
    else if (iteration_count < 16) begin
        sw = 24'h000050;
    end
    else if (iteration_count < 24) begin
        sw = 24'h000080;
    end
    else if (iteration_count < 32) begin
        sw = 24'h0010A0;
    end
    else if (iteration_count < 40) begin
        sw = 24'h0020C0;
    end
    else if (iteration_count < 48) begin
        sw = 24'h0040E0;
    end
    else if (iteration_count < 64) begin
        sw = 24'h0060FF;
    end
    else if (iteration_count < 80) begin
        sw = 24'h0080FF;
    end
    else if (iteration_count < 96) begin
        sw = 24'h00A0FF;
    end
    else if (iteration_count < 112) begin
        sw = 24'h00C0FF;
    end
    else if (iteration_count < 128) begin
        sw = 24'h00E0FF;
    end
    else if (iteration_count < 160) begin
        sw = 24'h40FFFF;
    end
    else if (iteration_count < 192) begin
        sw = 24'h80FFFF;
    end
    else if (iteration_count < 224) begin
        sw = 24'hC0FFFF;
    end
    else begin
        sw = 24'hFFFFFF;
    end
end
endmodule
