const std = @import("std");
const main = @import("../main.zig");
const windowSdlZig = @import("../windowSdl.zig");
const shopZig = @import("../shop.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const imageZig = @import("../image.zig");

const GATE_OPEN_DURATION = 2000;

pub fn setupVertices(state: *main.GameState) !void {
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
    try verticesForEnterShop(state);
}

fn verticesForEnterShop(state: *main.GameState) !void {
    if (state.gamePhase != .combat) return;
    const verticeData = &state.vkState.verticeData;
    const tileRectangle = shopZig.getShopEarlyTriggerPosition(state);
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const gridEnterShopTopLeft: main.Position = .{
        .x = @floatFromInt(tileRectangle.pos.x * main.TILESIZE),
        .y = @floatFromInt(tileRectangle.pos.y * main.TILESIZE),
    };
    const vulkan: main.Position = .{
        .x = (-state.camera.position.x + gridEnterShopTopLeft.x) * state.camera.zoom * onePixelXInVulkan,
        .y = (-state.camera.position.y + gridEnterShopTopLeft.y) * state.camera.zoom * onePixelYInVulkan,
    };
    const halveVulkanTileSizeX = main.TILESIZE * onePixelXInVulkan * state.camera.zoom / 2;
    const halveVulkanTileSizeY = main.TILESIZE * onePixelYInVulkan * state.camera.zoom / 2;
    const width = main.TILESIZE * shopZig.EARLY_SHOP_GRID_SIZE * onePixelXInVulkan * state.camera.zoom;
    const height = main.TILESIZE * shopZig.EARLY_SHOP_GRID_SIZE * onePixelYInVulkan * state.camera.zoom;
    const left = vulkan.x - halveVulkanTileSizeX;
    const top = vulkan.y - halveVulkanTileSizeY;
    const fontSize = 26;
    paintVulkanZig.verticesForRectangle(left, top, width, height, .{ 1, 1, 1 }, &verticeData.lines, null);
    paintVulkanZig.verticesForComplexSprite(
        .{ .x = gridEnterShopTopLeft.x + main.TILESIZE / 2, .y = gridEnterShopTopLeft.y + main.TILESIZE },
        imageZig.IMAGE_STAIRS,
        4,
        4,
        1,
        0,
        false,
        false,
        state,
    );
    if (state.round < state.roundToReachForNextLevel) {
        paintVulkanZig.verticesForComplexSprite(
            .{ .x = gridEnterShopTopLeft.x + main.TILESIZE / 2, .y = gridEnterShopTopLeft.y + main.TILESIZE / 2 },
            imageZig.IMAGE_GATE,
            4,
            4,
            1,
            0,
            false,
            false,
            state,
        );
        const textColor = .{ 0.7, 0, 0 };
        _ = try fontVulkanZig.paintNumberGameMap(state.roundToReachForNextLevel - state.round, .{
            .x = gridEnterShopTopLeft.x,
            .y = gridEnterShopTopLeft.y,
        }, fontSize, textColor, &verticeData.font, state);
    } else if (state.gateOpenTime != null and state.gateOpenTime.? + GATE_OPEN_DURATION > state.gameTime) {
        const timePerCent = 1 - @as(f32, @floatFromInt(state.gateOpenTime.? + GATE_OPEN_DURATION - state.gameTime)) / GATE_OPEN_DURATION;
        paintVulkanZig.verticesForComplexSprite(
            .{ .x = gridEnterShopTopLeft.x + main.TILESIZE / 2, .y = gridEnterShopTopLeft.y + main.TILESIZE / 2 - timePerCent * main.TILESIZE * 2 },
            imageZig.IMAGE_GATE,
            4,
            4,
            1,
            0,
            false,
            false,
            state,
        );
    }
}
