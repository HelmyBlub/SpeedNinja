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
const shopZig = @import("shop.zig");

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
        if (event.type == sdl.SDL_EVENT_MOUSE_MOTION) {
            //placeholder
        }
        if (event.type == sdl.SDL_EVENT_QUIT) {
            std.debug.print("clicked window X \n", .{});
            state.gameEnded = true;
        }
        if (event.type == sdl.SDL_EVENT_KEY_DOWN) {
            for (state.players.items) |*player| {
                if (event.key.scancode == sdl.SDL_SCANCODE_LEFT or event.key.scancode == sdl.SDL_SCANCODE_A) {
                    if (player.choosenMoveOptionIndex) |index| {
                        try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_LEFT, state);
                    } else if (state.gamePhase == .shopping) {
                        player.position.x -= main.TILESIZE;
                        try shopZig.executeShopActionForPlayer(player, state);
                    }
                } else if (event.key.scancode == sdl.SDL_SCANCODE_RIGHT or event.key.scancode == sdl.SDL_SCANCODE_D) {
                    if (player.choosenMoveOptionIndex) |index| {
                        try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_RIGHT, state);
                    } else if (state.gamePhase == .shopping) {
                        player.position.x += main.TILESIZE;
                        try shopZig.executeShopActionForPlayer(player, state);
                    }
                } else if (event.key.scancode == sdl.SDL_SCANCODE_UP or event.key.scancode == sdl.SDL_SCANCODE_W) {
                    if (player.choosenMoveOptionIndex) |index| {
                        try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_UP, state);
                    } else if (state.gamePhase == .shopping) {
                        player.position.y -= main.TILESIZE;
                        try shopZig.executeShopActionForPlayer(player, state);
                    }
                } else if (event.key.scancode == sdl.SDL_SCANCODE_DOWN or event.key.scancode == sdl.SDL_SCANCODE_S) {
                    if (player.choosenMoveOptionIndex) |index| {
                        try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_DOWN, state);
                    } else if (state.gamePhase == .shopping) {
                        player.position.y += main.TILESIZE;
                        try shopZig.executeShopActionForPlayer(player, state);
                    }
                } else if (event.key.scancode == sdl.SDL_SCANCODE_1) {
                    movePieceZig.setMoveOptionIndex(player, 0, state);
                } else if (event.key.scancode == sdl.SDL_SCANCODE_2) {
                    movePieceZig.setMoveOptionIndex(player, 1, state);
                } else if (event.key.scancode == sdl.SDL_SCANCODE_3) {
                    movePieceZig.setMoveOptionIndex(player, 2, state);
                } else if (event.key.scancode == sdl.SDL_SCANCODE_F1) {
                    try main.startNextLevel(state);
                } else if (event.key.scancode == sdl.SDL_SCANCODE_F2) {
                    if (state.gamePhase == .combat) {
                        try main.startNextRound(state);
                    }
                } else if (event.key.scancode == sdl.SDL_SCANCODE_F3) {
                    if (state.gamePhase != .shopping) try shopZig.startShoppingPhase(state);
                } else if (event.key.scancode == sdl.SDL_SCANCODE_F4) {
                    try main.restart(state);
                } else if (event.key.scancode == sdl.SDL_SCANCODE_F5) {
                    state.level = 49;
                    try main.startNextLevel(state);
                }
            }
        }
    }
}

pub fn mouseWindowPositionToGameMapPoisition(x: f32, y: f32, camera: main.Camera) main.Position {
    var width: u32 = 0;
    var height: u32 = 0;
    getWindowSize(&width, &height);
    const widthFloatWindow = @as(f64, @floatFromInt(width));
    const heightFloatWindow = @as(f64, @floatFromInt(height));

    const scaleToPixelX = windowData.widthFloat / widthFloatWindow;
    const scaleToPixelY = windowData.heightFloat / heightFloatWindow;

    return main.Position{
        .x = (x - widthFloatWindow / 2) * scaleToPixelX / camera.zoom + camera.position.x,
        .y = (y - heightFloatWindow / 2) * scaleToPixelY / camera.zoom + camera.position.y,
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
