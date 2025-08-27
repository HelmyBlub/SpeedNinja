const std = @import("std");
const main = @import("../main.zig");
const windowSdlZig = @import("../windowSdl.zig");

pub fn setupVertices(state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;

    const lines = &verticeData.lines;
    const color: [3]f32 = .{ 0.25, 0.25, 0.25 };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const zoomedTileSize = main.TILESIZE * state.camera.zoom;
    const mapRadius: f32 = @as(f32, @floatFromInt(state.mapData.tileRadius)) * zoomedTileSize;
    const cameraOffsetX = state.camera.position.x * state.camera.zoom;
    const cameraOffsetY = state.camera.position.y * state.camera.zoom;
    const left: f32 = (-mapRadius - zoomedTileSize / 2 - cameraOffsetX) * onePixelXInVulkan;
    const right: f32 = (mapRadius + zoomedTileSize * 0.5 - cameraOffsetX) * onePixelXInVulkan;
    const top: f32 = (-mapRadius - zoomedTileSize / 2 - cameraOffsetY) * onePixelYInVulkan;
    const bottom: f32 = (mapRadius + zoomedTileSize * 0.5 - cameraOffsetY) * onePixelYInVulkan;
    for (0..(state.mapData.tileRadius * 2 + 2)) |i| {
        const floatIndex = @as(f32, @floatFromInt(i));
        const vulkanX = left + floatIndex * zoomedTileSize * onePixelXInVulkan;
        const vulkanY = top + floatIndex * zoomedTileSize * onePixelYInVulkan;
        if (lines.verticeCount + 4 >= lines.vertices.len) break;
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ vulkanX, top }, .color = color };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ vulkanX, bottom }, .color = color };
        lines.vertices[lines.verticeCount + 2] = .{ .pos = .{ left, vulkanY }, .color = color };
        lines.vertices[lines.verticeCount + 3] = .{ .pos = .{ right, vulkanY }, .color = color };
        lines.verticeCount += 4;
    }
}
