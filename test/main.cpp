#include <iostream>
#include <SDL2/SDL.h>
#include "Vgpu_system.h"
#include "verilated.h"

const int WIDTH = 640;
const int HEIGHT = 480;
const int FB_OFFSET = 10; 

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
    SDL_Window* window = SDL_CreateWindow("Core-Cascade: 640x480 Full Render", 
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, 0);
    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, 
        SDL_TEXTUREACCESS_STREAMING, WIDTH, HEIGHT);
    
    uint32_t* pixels = new uint32_t[WIDTH * HEIGHT];

    std::cout << "[SYSTEM] Resetting Hardware..." << std::endl;
    top->clk = 0; top->reset = 1; top->start = 0; top->eval();
    for(int i = 0; i < 10; i++) tick(top); 
    top->reset = 0; 
    for(int i = 0; i < 10; i++) tick(top); 

    std::cout << "[SYSTEM] Ready. Press SPACE to Render 640x480." << std::endl;

    bool running = true;
    bool needs_recompute = true; 

    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) running = false;
            if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_SPACE) {
                needs_recompute = true;
            }
        }

        if (needs_recompute) {
            std::cout << "\n[DISPATCH] Starting 307,200 thread render..." << std::endl;
            top->device_control_write_enable = 1; 
            top->device_control_data = 307200; 
            tick(top);
            top->device_control_write_enable = 0;
            tick(top);

            top->start = 1; tick(top);
            top->start = 0; tick(top);

            uint64_t cycles = 0;
            while (!top->done) {
                tick(top);
                cycles++;
                if (cycles % 10000000 == 0) {
                    std::cout << " -> " << (cycles / 1000000) << " Million cycles..." << std::endl;
                }
                if (cycles > 500000000) { // 500M cycle safety limit
                    std::cout << "[FATAL] Timeout reached!" << std::endl;
                    break;
                }
            }
            
            if (top->done) {
                std::cout << "[SUCCESS] Rendered in " << cycles << " cycles!" << std::endl;
                for (int i = 0; i < WIDTH * HEIGHT; i++) {
                    top->host_read_address = FB_OFFSET + i;
                    tick(top); 
                    pixels[i] = get_color(top->host_read_data);
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