const std = @import("std");
const buildin = @import("builtin");
pub const sdl = @cImport({
    @cDefine("VK_NO_PROTOTYPES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cInclude("SDL3/SDL_vulkan.h");
});
const main = @import("main.zig");
const movePieceZig = @import("movePiece.zig");

pub const WindowData = struct {
    window: *sdl.SDL_Window = undefined,
    widthFloat: f32 = 1600,
    heightFloat: f32 = 800,
};

pub var windowData: WindowData = .{};

pub fn initWindowSdl() !void {
    _ = sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO);
    const flags = sdl.SDL_WINDOW_VULKAN | sdl.SDL_WINDOW_RESIZABLE;
    windowData.window = try (sdl.SDL_CreateWindow("Speed Ninja", @intFromFloat(windowData.widthFloat), @intFromFloat(windowData.heightFloat), flags) orelse error.createWindow);
    _ = sdl.SDL_ShowWindow(windowData.window);
}

pub fn destroyWindowSdl() void {
    sdl.SDL_DestroyWindow(windowData.window);
    sdl.SDL_Quit();
}

pub fn getSurfaceForVulkan(instance: sdl.VkInstance) sdl.VkSurfaceKHR {
    var surface: sdl.VkSurfaceKHR = undefined;
    _ = sdl.SDL_Vulkan_CreateSurface(windowData.window, instance, null, &surface);
    return surface;
}

pub fn getWindowSize(width: *u32, height: *u32) void {
    var w: c_int = undefined;
    var h: c_int = undefined;
    _ = sdl.SDL_GetWindowSize(windowData.window, &w, &h);
    width.* = @intCast(w);
    height.* = @intCast(h);
}

pub fn toggleFullscreen() bool {
    const flags = sdl.SDL_GetWindowFlags(windowData.window);
    if ((flags & sdl.SDL_WINDOW_FULLSCREEN) == 0) {
        _ = sdl.SDL_SetWindowFullscreen(windowData.window, true);
        return true;
    } else {
        _ = sdl.SDL_SetWindowFullscreen(windowData.window, false);
        return false;
    }
}

pub fn handleEvents(state: *main.GameState) !void {
    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&event)) {
        if (event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP) {
            //placeholder
        }
        if (event.type == sdl.SDL_EVENT_QUIT) {
            std.debug.print("clicked window X \n", .{});
            state.gameEnded = true;
        }
        if (event.type == sdl.SDL_EVENT_KEY_DOWN) {
            if (event.key.scancode == sdl.SDL_SCANCODE_LEFT or event.key.scancode == sdl.SDL_SCANCODE_A) {
                if (state.player.choosenMoveOptionIndex) |index| {
                    try movePieceZig.movePlayerByMovePiece(index, movePieceZig.DIRECTION_LEFT, state);
                    state.player.choosenMoveOptionIndex = null;
                }
            } else if (event.key.scancode == sdl.SDL_SCANCODE_RIGHT or event.key.scancode == sdl.SDL_SCANCODE_D) {
                if (state.player.choosenMoveOptionIndex) |index| {
                    try movePieceZig.movePlayerByMovePiece(index, movePieceZig.DIRECTION_RIGHT, state);
                    state.player.choosenMoveOptionIndex = null;
                }
            } else if (event.key.scancode == sdl.SDL_SCANCODE_UP or event.key.scancode == sdl.SDL_SCANCODE_W) {
                if (state.player.choosenMoveOptionIndex) |index| {
                    try movePieceZig.movePlayerByMovePiece(index, movePieceZig.DIRECTION_UP, state);
                    state.player.choosenMoveOptionIndex = null;
                }
            } else if (event.key.scancode == sdl.SDL_SCANCODE_DOWN or event.key.scancode == sdl.SDL_SCANCODE_S) {
                if (state.player.choosenMoveOptionIndex) |index| {
                    try movePieceZig.movePlayerByMovePiece(index, movePieceZig.DIRECTION_DOWN, state);
                    state.player.choosenMoveOptionIndex = null;
                }
            } else if (event.key.scancode == sdl.SDL_SCANCODE_1) {
                setMoveOptionIndex(0, state);
            } else if (event.key.scancode == sdl.SDL_SCANCODE_2) {
                setMoveOptionIndex(1, state);
            } else if (event.key.scancode == sdl.SDL_SCANCODE_3) {
                setMoveOptionIndex(2, state);
            }
        }
    }
}

pub fn setMoveOptionIndex(index: usize, state: *main.GameState) void {
    if (state.player.moveOptions.items.len > index) {
        state.player.choosenMoveOptionIndex = index;
        state.player.ninjaDogPaintData.bladeDrawn = true;
    }
}

pub fn mouseWindowPositionToGameMapPoisition(x: f32, y: f32, camera: main.Camera) main.Position {
    var width: u32 = 0;
    var height: u32 = 0;
    getWindowSize(&width, &height);
    const widthFloat = @as(f64, @floatFromInt(width));
    const heightFloat = @as(f64, @floatFromInt(height));

    return main.Position{
        .x = (x - widthFloat / 2) / camera.zoom + camera.position.x,
        .y = (y - heightFloat / 2) / camera.zoom + camera.position.y,
    };
}

pub fn mouseWindowPositionToVulkanSurfacePoisition(x: f32, y: f32) main.Position {
    var width: u32 = 0;
    var height: u32 = 0;
    getWindowSize(&width, &height);
    const widthFloat = @as(f64, @floatFromInt(width));
    const heightFloat = @as(f64, @floatFromInt(height));

    return main.Position{
        .x = x / widthFloat * 2 - 1,
        .y = y / heightFloat * 2 - 1,
    };
}
