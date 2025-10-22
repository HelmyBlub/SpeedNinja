const std = @import("std");
const windowSdlZig = @import("windowSdl.zig");
const sdl = @import("windowSdl.zig").sdl;
const main = @import("main.zig");

pub const OnStartErrorDisplay = struct {
    displayStrings: std.ArrayList(StringAllocData),
};

pub const StringAllocData = struct {
    needDealloc: bool = false,
    string: []const u8,
};

pub fn displayLastErrorMessageInWindow(state: *main.GameState) !void {
    if (state.windowData.window == null) return;
    const window = state.windowData.window.?;
    const renderer = sdl.SDL_CreateRenderer(window, null);
    if (renderer == null) {
        std.debug.print("SDL_CreateRenderer Error: {s}\n", .{sdl.SDL_GetError()});
        return error.SDLRendererError;
    }
    defer sdl.SDL_DestroyRenderer(renderer);

    var event: sdl.SDL_Event = undefined;
    std.debug.print("started backup renderer\n", .{});
    while (true) {
        while (sdl.SDL_PollEvent(&event)) {
            if (event.type == sdl.SDL_EVENT_QUIT) return;
        }
        _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, sdl.SDL_ALPHA_OPAQUE);
        _ = sdl.SDL_RenderClear(renderer);
        _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 255, 255, sdl.SDL_ALPHA_OPAQUE);
        _ = sdl.SDL_SetRenderScale(renderer, 2.0, 2.0);
        for (state.onStartError.displayStrings.items, 0..) |item, index| {
            _ = sdl.SDL_RenderDebugText(renderer, 20, 20 + @as(f32, @floatFromInt(index)) * 20, @ptrCast(item.string));
        }
        _ = sdl.SDL_SetRenderScale(renderer, 1.0, 1.0);
        _ = sdl.SDL_RenderPresent(renderer);

        sdl.SDL_Delay(16);
    }
}
