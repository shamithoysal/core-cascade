#include <iostream>
#include <chrono>
#include <SDL2/SDL.h>
#include "Vgpu_system.h"
#include "verilated.h"

// --- UPDATED RESOLUTION ---
const int WIDTH = 64;
const int HEIGHT = 48;
const int FB_OFFSET = 10; 

// --- CAMERA STATE (Centered for 160x120) ---
float cam_x = -2.0f;
float cam_y = -1.0f;
float cam_dx = 0.046875f; 
float cam_dy = 0.041666f; 

// Converts a standard C++ float into your custom Q8.24 hardware format
int32_t to_q8_24(float val) {
    return (int32_t)(val * 16777216.0f); // 16,777,216 is 2^24
}

// BRAM Injection Function
void write_bram(Vgpu_system* top, int address, int32_t data) {
    top->host_write_enable = 1;
    top->host_write_address = address;
    top->host_write_data = data;
    top->clk = 1; top->eval(); // Tick
    top->clk = 0; top->eval(); // Tock
    top->host_write_enable = 0;
}

uint32_t get_color(uint32_t iter) {
    if (iter >= 255) return 0xFF000000; 
    uint8_t r = (iter * 14) % 256;
    uint8_t g = (iter * 4) % 256;
    uint8_t b = (iter * 19) % 256;
    return (0xFF000000 | (r << 16) | (g << 8) | b);
}

void tick(Vgpu_system* top) {
    top->clk = 1; top->eval();
    top->clk = 0; top->eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vgpu_system* top = new Vgpu_system;

    SDL_Init(SDL_INIT_VIDEO);
    
    // --- UPDATED WINDOW SCALE (5x) ---
    SDL_Window* window = SDL_CreateWindow("Core-Cascade: 160x120 Flight Sim", 
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIDTH * 10, HEIGHT * 10, 0);
    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    SDL_RenderSetScale(renderer, 10, 10); 
    SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, 
        SDL_TEXTUREACCESS_STREAMING, WIDTH, HEIGHT);
    
    uint32_t* pixels = new uint32_t[WIDTH * HEIGHT];

    std::cout << "[SYSTEM] Booting GPU..." << std::endl;
    top->clk = 0; top->reset = 1; top->start = 0; top->host_write_enable = 0; top->eval();
    for(int i = 0; i < 10; i++) tick(top); 
    top->reset = 0; 
    for(int i = 0; i < 10; i++) tick(top); 

    std::cout << "\n=== CONTROLS ===" << std::endl;
    std::cout << "W/A/S/D : Pan Camera" << std::endl;
    std::cout << "Q/E     : Zoom In / Zoom Out (Center Anchored)" << std::endl;
    std::cout << "SPACE   : Re-Render Frame\n" << std::endl;

    bool running = true;
    bool needs_recompute = true; 

    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) running = false;
            if (e.type == SDL_KEYDOWN) {
                // Calculate movement speed based on current zoom level
                float pan_speed = cam_dx * 10.0f; 
                
                switch (e.key.keysym.sym) {
                    case SDLK_w: cam_y -= pan_speed; needs_recompute = true; break;
                    case SDLK_s: cam_y += pan_speed; needs_recompute = true; break;
                    case SDLK_a: cam_x -= pan_speed; needs_recompute = true; break;
                    case SDLK_d: cam_x += pan_speed; needs_recompute = true; break;
                    
                    case SDLK_q: { // ZOOM IN
                        float old_w = WIDTH * cam_dx;
                        float old_h = HEIGHT * cam_dy;
                        cam_dx *= 0.8f; 
                        cam_dy *= 0.8f; 
                        // Shift origin to keep the center fixed
                        cam_x += (old_w - (WIDTH * cam_dx)) / 2.0f;
                        cam_y += (old_h - (HEIGHT * cam_dy)) / 2.0f;
                        needs_recompute = true; 
                        break; 
                    }
                    case SDLK_e: { // ZOOM OUT
                        float old_w = WIDTH * cam_dx;
                        float old_h = HEIGHT * cam_dy;
                        cam_dx *= 1.25f; 
                        cam_dy *= 1.25f; 
                        // Shift origin to keep the center fixed
                        cam_x += (old_w - (WIDTH * cam_dx)) / 2.0f;
                        cam_y += (old_h - (HEIGHT * cam_dy)) / 2.0f;
                        needs_recompute = true; 
                        break; 
                    }
                    case SDLK_SPACE: needs_recompute = true; break;
                }
            }
        }

        if (needs_recompute) {
            std::cout << "[CAMERA] X: " << cam_x << " | Y: " << cam_y << " | DX: " << cam_dx << std::endl;
            
            // 1. INJECT THE NEW COORDINATES INTO BRAM
            write_bram(top, 0, to_q8_24(cam_x));  // Address 0 = X_START
            write_bram(top, 1, to_q8_24(cam_y));  // Address 1 = Y_START
            write_bram(top, 2, to_q8_24(cam_dx)); // Address 2 = DX
            write_bram(top, 3, to_q8_24(cam_dy)); // Address 3 = DY

            // 2. HARD RESET TO CLEAR THE 'DONE' WIRE
            top->reset = 1; tick(top);
            top->reset = 0; tick(top);

            // 3. DISPATCH THREADS
            top->device_control_write_enable = 1; 
            top->device_control_data = 3072; // --- UPDATED FOR 160x120 ---
            tick(top);
            top->device_control_write_enable = 0;
            tick(top);

            // 4. FIRE!
            top->start = 1; tick(top);
            top->start = 0; tick(top);

            uint64_t cycles = 0;
            auto start_time = std::chrono::high_resolution_clock::now();
            
            while (!top->done) {
                tick(top);
                cycles++;
                
                // Live Screen Updates
                if (cycles % 500000 == 0) {
                    SDL_Event temp_e;
                    while (SDL_PollEvent(&temp_e)) if (temp_e.type == SDL_QUIT) { running = false; break; }

                    for (int i = 0; i < WIDTH * HEIGHT; i++) {
                        top->host_read_address = FB_OFFSET + i;
                        tick(top); pixels[i] = get_color(top->host_read_data); cycles++; 
                    }
                    SDL_UpdateTexture(texture, NULL, pixels, WIDTH * sizeof(uint32_t));
                    SDL_RenderClear(renderer);
                    SDL_RenderCopy(renderer, texture, NULL, NULL);
                    SDL_RenderPresent(renderer);
                }
                if (!running) break; 
            }
            
            if (top->done) {
                auto end_time = std::chrono::high_resolution_clock::now();
                auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
                std::cout << "[SUCCESS] " << duration.count() << " ms (" << cycles << " cycles)\n" << std::endl;
                
                for (int i = 0; i < WIDTH * HEIGHT; i++) {
                    top->host_read_address = FB_OFFSET + i;
                    tick(top); pixels[i] = get_color(top->host_read_data);
                }
                SDL_UpdateTexture(texture, NULL, pixels, WIDTH * sizeof(uint32_t));
                SDL_RenderClear(renderer);
                SDL_RenderCopy(renderer, texture, NULL, NULL);
                SDL_RenderPresent(renderer);
            }
            needs_recompute = false;
        }
        SDL_Delay(16);
    }

    delete top; delete[] pixels; SDL_Quit();
    return 0;
}