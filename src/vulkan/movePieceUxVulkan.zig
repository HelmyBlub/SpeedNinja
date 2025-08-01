const std = @import("std");
const main = @import("../main.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");
const movePieceZig = @import("../movePiece.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");

const INITIAL_PIECE_COLOR: [3]f32 = .{ 0.0, 0.0, 1 };

pub fn setupVertices(state: *main.GameState) !void {
    const verticeData = &state.vkState.verticeData;

    for (state.players.items) |*player| {
        verticesForMoveOptions(player, verticeData);
    }

    const fontSize = 30;
    const player = state.players.items[0];
    const remainingPieces = player.availableMovePieces.items.len + player.moveOptions.items.len;
    const totalPieces = player.totalMovePieces.items.len;
    var textWidthPieces = try fontVulkanZig.paintNumber(remainingPieces, .{ .x = 0.5, .y = 0.8 }, fontSize, &verticeData.font);
    textWidthPieces += fontVulkanZig.paintText(":", .{ .x = 0.5 + textWidthPieces, .y = 0.8 }, fontSize, &verticeData.font);
    _ = try fontVulkanZig.paintNumber(totalPieces, .{ .x = 0.5 + textWidthPieces, .y = 0.8 }, fontSize, &verticeData.font);
}

fn verticesForMoveOptions(player: *main.Player, verticeData: *dataVulkanZig.VkVerticeData) void {
    if (player.moveOptions.items.len == 0) return;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const size = main.TILESIZE;
    const width = size * onePixelXInVulkan;
    const height = size * onePixelYInVulkan;
    const pieceXSpacing = width * 8;
    const someWidth = @as(f32, @floatFromInt(player.moveOptions.items.len - 1)) * pieceXSpacing - width / 2;
    var startX: f32 = -someWidth / 2;
    const startY = 0.9;

    const lines = &verticeData.lines;
    const triangles = &verticeData.triangles;
    for (player.moveOptions.items, 0..) |option, index| {
        const fillColor: [3]f32 = .{ 0.25, 0.25, 0.25 };
        const selctedColor: [3]f32 = .{ 0.07, 0.07, 0.07 };
        const rectFillColor = if (player.choosenMoveOptionIndex != null and player.choosenMoveOptionIndex.? == index) selctedColor else fillColor;
        _ = verticesForMovePiece(option, rectFillColor, startX, startY, width, height, 0, false, lines, triangles);
        startX += pieceXSpacing;
    }
}

pub fn verticesForMovePiece(
    movePiece: movePieceZig.MovePiece,
    fillColor: [3]f32,
    vulkanX: f32,
    vulkanY: f32,
    vulkanTileWidth: f32,
    vulkanTileHeight: f32,
    direction: u8,
    skipInitialRect: bool,
    lines: *dataVulkanZig.VkColoredVertexes,
    triangles: *dataVulkanZig.VkColoredVertexes,
) struct { x: f32, y: f32 } {
    var x: f32 = vulkanX;
    var y: f32 = vulkanY;
    var sizeFactor: f32 = 1;
    const factor = 0.9;
    if (!skipInitialRect) paintVulkanZig.verticesForRectangle(x, y, vulkanTileWidth, vulkanTileHeight, INITIAL_PIECE_COLOR, lines, triangles);
    for (movePiece.steps) |step| {
        const modStepDirection = @mod(step.direction + direction, 4);
        const stepDirection = movePieceZig.getStepDirection(modStepDirection);
        sizeFactor *= factor;
        for (0..step.stepCount) |i| {
            x += stepDirection.x * vulkanTileWidth;
            y += stepDirection.y * vulkanTileHeight;
            var modWidth = vulkanTileWidth;
            var modHeight = vulkanTileHeight;
            var tempX = x;
            var tempY = y;
            switch (modStepDirection) {
                movePieceZig.DIRECTION_RIGHT => {
                    modHeight *= sizeFactor;
                    const offsetBasedOnSizeFactor = vulkanTileWidth * (1 - sizeFactor) / 2;
                    tempX -= offsetBasedOnSizeFactor;
                    tempY += vulkanTileHeight * (1 - sizeFactor) / 2;
                    if (i == 0) {
                        const offsetBasedOnOldSizeFactor = vulkanTileWidth * (1 - sizeFactor / factor) / 2;
                        tempX -= offsetBasedOnOldSizeFactor - offsetBasedOnSizeFactor;
                        modWidth -= offsetBasedOnSizeFactor - offsetBasedOnOldSizeFactor;
                    }
                },
                movePieceZig.DIRECTION_LEFT => {
                    modHeight *= sizeFactor;
                    const offsetBasedOnSizeFactor = vulkanTileWidth * (1 - sizeFactor) / 2;
                    tempX += offsetBasedOnSizeFactor;
                    tempY += vulkanTileHeight * (1 - sizeFactor) / 2;
                    if (i == 0) {
                        const offsetBasedOnOldSizeFactor = vulkanTileWidth * (1 - sizeFactor / factor) / 2;
                        modWidth -= offsetBasedOnSizeFactor - offsetBasedOnOldSizeFactor;
                    }
                },
                movePieceZig.DIRECTION_UP => {
                    modWidth *= sizeFactor;
                    tempX += vulkanTileWidth * (1 - sizeFactor) / 2;
                    const offsetBasedOnSizeFactor = (vulkanTileHeight * (1 - sizeFactor) / 2.0);
                    tempY += offsetBasedOnSizeFactor;
                    if (i == 0) {
                        const offsetBasedOnOldSizeFactor = (vulkanTileHeight * (1 - sizeFactor / factor) / 2.0);
                        modHeight -= offsetBasedOnSizeFactor - offsetBasedOnOldSizeFactor;
                    }
                },
                else => {
                    modWidth *= sizeFactor;
                    const offsetBasedOnSizeFactor = (vulkanTileHeight * (1 - sizeFactor) / 2.0);
                    tempX += vulkanTileWidth * (1 - sizeFactor) / 2;
                    tempY -= offsetBasedOnSizeFactor;
                    if (i == 0) {
                        const offsetBasedOnOldSizeFactor = vulkanTileHeight * (1 - sizeFactor / factor) / 2;
                        tempY -= offsetBasedOnOldSizeFactor - offsetBasedOnSizeFactor;
                        modHeight -= offsetBasedOnSizeFactor - offsetBasedOnOldSizeFactor;
                    }
                },
            }

            paintVulkanZig.verticesForRectangle(tempX, tempY, modWidth, modHeight, fillColor, lines, triangles);
        }
    }
    return .{ .x = x, .y = y };
}
