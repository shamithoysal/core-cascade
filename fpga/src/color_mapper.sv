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
            // CHANGED: Using bits [5:2] instead of [7:4].
            // This makes bands 4x thinner and causes the 16-color palette 
            // to loop (Hardware Modulo), creating continuous ripples.
            case (iter_count[5:2])
                // --- Deep Void ---
                4'h0: vga_color = 12'h102; // Almost black indigo
                4'h1: vga_color = 12'h204; // Very dark purple
                4'h2: vga_color = 12'h306; // Dark purple
                4'h3: vga_color = 12'h508; // Deep violet

                // --- The Glow ---
                4'h4: vga_color = 12'h70A; // Violet
                4'h5: vga_color = 12'h90C; // Deep Magenta
                4'h6: vga_color = 12'hB1D; // Magenta
                4'h7: vga_color = 12'hD2E; // Bright Magenta

                // --- The Halo ---
                4'h8: vga_color = 12'hE3F; // Pink
                4'h9: vga_color = 12'hF4F; // Hot Pink
                4'hA: vga_color = 12'hF6B; // Neon Pink
                4'hB: vga_color = 12'hF87; // Peachy Pink / Coral

                // --- The Chaotic Event Horizon ---
                4'hC: vga_color = 12'hF50; // Neon Orange
                4'hD: vga_color = 12'h2D2; // Toxic Green
                4'hE: vga_color = 12'h0EC; // Neon Cyan
                4'hF: vga_color = 12'h468; // Dim blue (Smoothes the loop back into 4'h0)
                
                default: vga_color = 12'h000; // Black fallback
            endcase
        end
    end
endmodule