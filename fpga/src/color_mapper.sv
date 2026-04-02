`default_nettype none

module color_mapper (
    input wire [7:0] iter_count,
    output reg [11:0] vga_color 
);
    always_comb begin
        if (iter_count == 8'hFF) begin 
            // The points inside the set remain stark black.
            vga_color = 12'h000; 
        end else begin
            // Artistic, High-Diversity, Polychromatic Gradient LUT
            // Sequenced: Deep Blue -> Teal -> Green -> Yellow -> Orange -> Red
            // We use the upper 4 bits of the iteration count to select the primary hye.
            case (iter_count[7:4])
                // --- Band 1: Deep Water Blue (Coldest escapees) ---
                4'h0: vga_color = 12'h002; // Very deep violet/blue
                4'h1: vga_color = 12'h004; 
                4'h2: vga_color = 12'h006;
                4'h3: vga_color = 12'h00A; // Bright navy

                // --- Band 2: Teal & Cyan Transition ---
                4'h4: vga_color = 12'h02A; // Deep Teal
                4'h5: vga_color = 12'h04A; 
                4'h6: vga_color = 12'h08C; // Mid Cyan
                4'h7: vga_color = 12'h0CC; // Bright Cyan

                // --- Band 3: Vibrant Greens ---
                4'h8: vga_color = 12'h0C8; // Blue-Green
                4'h9: vga_color = 12'h0C4;
                4'hA: vga_color = 12'h0C0; // Standard Green
                4'hB: vga_color = 12'h8C0; // Lime Green

                // --- Band 4: Golden Heat (Approaching set) ---
                4'hC: vga_color = 12'hCC0; // Bright Yellow/Gold
                4'hD: vga_color = 12'hCA0; // Mustard
                4'hE: vga_color = 12'hE60; // Vibrant Orange

                // --- Band 5: Electric Fire (Innermost rings) ---
                4'hF: vga_color = 12'hF00; // Bright Electric Red
                
                default: vga_color = 12'h000; // Black fallback
            endcase
        end
    end
endmodule