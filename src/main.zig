const std = @import("std");
const sdl = @cImport(@cInclude("SDL.h"));
const CHIP8 = @import("chip8.zig");
const process = std.process;

var window: ?*sdl.SDL_Window = null;
var renderer: ?*sdl.SDL_Renderer = null;
var texture: ?*sdl.SDL_Texture = null;

var cpu: *CHIP8 = undefined;

pub fn init() void {
    if (sdl.SDL_Init(sdl.SDL_INIT_EVERYTHING) < 0) {
        @panic("SDL Initialization Failed!");
    }

    window = sdl.SDL_CreateWindow("CHIP8", sdl.SDL_WINDOWPOS_CENTERED, sdl.SDL_WINDOWPOS_CENTERED, 1024, 512, 0);
    if (window == null)
        @panic("Window Creation Failed!");

    renderer = sdl.SDL_CreateRenderer(window, -1, 0);
    if (renderer == null)
        @panic("SDL Renderer Initialization failed");

    texture = sdl.SDL_CreateTexture(renderer, sdl.SDL_PIXELFORMAT_RGBA8888, sdl.SDL_TEXTUREACCESS_STREAMING, 64, 32);
}

pub fn deinit() void {
    sdl.SDL_DestroyWindow(window);
    sdl.SDL_Quit();
}

pub fn loadROM(filename: []const u8) !void {
    var inputFile = try std.fs.cwd().openFile(filename, .{});
    defer inputFile.close();

    var size = try inputFile.getEndPos();
    var reader = inputFile.reader();

    var i : usize = 0;
    while(i < size) : (i += 1) {
        cpu.memory[i + 0x200] = try reader.readByte();
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    init();
    defer deinit();

    cpu = try allocator.create(CHIP8);
    cpu.init();

    // LOAD A ROM
    var arg_it = try process.argsWithAllocator(allocator);
    _ = arg_it.skip();

    var filename = arg_it.next() orelse {
        std.debug.print("No Rom given\n", .{});
        return;
    };

    try loadROM(filename);

    var keep_open = true;
    while (keep_open) {
        cpu.cycle();

        var e: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&e) > 0) {
            switch (e.type) {
                sdl.SDL_QUIT => keep_open = false,
                else => {},
            }
        }

        _ = sdl.SDL_RenderClear(renderer);


        var bytes: ?[*]u32 = null;
        var pitch: c_int = 0;

        _ = sdl.SDL_LockTexture(texture, null, @ptrCast([*c]?*anyopaque, &bytes), &pitch);

        for(cpu.graphics, 0..) |g, idx| {
            bytes.?[idx] = if(g == 1) 0xFFFFFFFF else 0x000000FF;
        }

        sdl.SDL_UnlockTexture(texture);

        _ = sdl.SDL_RenderCopy(renderer, texture, null, null);
        _ = sdl.SDL_RenderPresent(renderer);

        std.time.sleep(16 * 1000 * 1000);
    }
}
