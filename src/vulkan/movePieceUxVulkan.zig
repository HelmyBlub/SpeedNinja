const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const dataVulkanZig = @import("dataVulkan.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const movePieceZig = @import("../movePiece.zig");
const fontVulkanZig = @import("fontVulkan.zig");

const INITIAL_PIECE_COLOR: [3]f32 = .{ 0.0, 0.0, 1 };

pub const VkMovePiecesUx = struct {
    triangles: dataVulkanZig.VkTriangles = undefined,
    lines: dataVulkanZig.VkLines = undefined,
    sprites: dataVulkanZig.VkSprites = undefined,
    font: dataVulkanZig.VkFont = undefined,
    const UX_RECTANGLES = 100;
    pub const MAX_VERTICES_TRIANGLES = 6 * UX_RECTANGLES;
    pub const MAX_VERTICES_LINES = 8 * UX_RECTANGLES;
    pub const MAX_VERTICES_SPRITES = UX_RECTANGLES;
    pub const MAX_VERTICES_FONT = 50;
};

pub fn setupVertices(state: *main.GameState) !void {
    const movePieceUx = &state.vkState.movePieceUx;
    movePieceUx.lines.verticeCount = 0;
    movePieceUx.triangles.verticeCount = 0;
    movePieceUx.sprites.verticeCount = 0;
    movePieceUx.font.verticeCount = 0;

    for (state.players.items) |*player| {
        verticesForMoveOptions(player, movePieceUx);
    }

    const fontSize = 30;
    const player = state.players.items[0];
    const remainingPieces = player.availableMovePieces.items.len + player.moveOptions.items.len;
    const totalPieces = player.totalMovePieces.items.len;
    var textWidthPieces = try fontVulkanZig.paintNumber(remainingPieces, .{ .x = 0.5, .y = 0.8 }, fontSize, &movePieceUx.font);
    textWidthPieces += fontVulkanZig.paintText(":", .{ .x = 0.5 + textWidthPieces, .y = 0.8 }, fontSize, &movePieceUx.font);
    _ = try fontVulkanZig.paintNumber(totalPieces, .{ .x = 0.5 + textWidthPieces, .y = 0.8 }, fontSize, &movePieceUx.font);

    try setupVertexDataForGPU(&state.vkState);
}

fn verticesForMoveOptions(player: *main.Player, movePieceUx: *VkMovePiecesUx) void {
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

    const lines = &movePieceUx.lines;
    const triangles = &movePieceUx.triangles;
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
    lines: *dataVulkanZig.VkLines,
    triangles: *dataVulkanZig.VkTriangles,
) struct { x: f32, y: f32 } {
    var x: f32 = vulkanX;
    var y: f32 = vulkanY;
    var sizeFactor: f32 = 1;
    const factor = 0.9;
    if (!skipInitialRect) verticesForRectangle(x, y, vulkanTileWidth, vulkanTileHeight, INITIAL_PIECE_COLOR, lines, triangles);
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

            verticesForRectangle(tempX, tempY, modWidth, modHeight, fillColor, lines, triangles);
        }
    }
    return .{ .x = x, .y = y };
}

pub fn verticesForRectangle(x: f32, y: f32, width: f32, height: f32, fillColor: [3]f32, lines: *dataVulkanZig.VkLines, triangles: *dataVulkanZig.VkTriangles) void {
    if (triangles.verticeCount + 6 >= triangles.vertices.len) return;
    triangles.vertices[triangles.verticeCount] = .{ .pos = .{ x, y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ x + width, y + height }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ x, y + height }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 3] = .{ .pos = .{ x, y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 4] = .{ .pos = .{ x + width, y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 5] = .{ .pos = .{ x + width, y + height }, .color = fillColor };
    triangles.verticeCount += 6;

    if (lines.verticeCount + 8 >= lines.vertices.len) return;
    const borderColor: [3]f32 = .{ 0, 0, 0 };
    lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ x, y }, .color = borderColor };
    lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ x + width, y }, .color = borderColor };
    lines.vertices[lines.verticeCount + 2] = .{ .pos = .{ x, y }, .color = borderColor };
    lines.vertices[lines.verticeCount + 3] = .{ .pos = .{ x, y + height }, .color = borderColor };
    lines.vertices[lines.verticeCount + 4] = .{ .pos = .{ x + width, y }, .color = borderColor };
    lines.vertices[lines.verticeCount + 5] = .{ .pos = .{ x + width, y + height }, .color = borderColor };
    lines.vertices[lines.verticeCount + 6] = .{ .pos = .{ x, y + height }, .color = borderColor };
    lines.vertices[lines.verticeCount + 7] = .{ .pos = .{ x + width, y + height }, .color = borderColor };
    lines.verticeCount += 8;
}

pub fn create(state: *main.GameState) !void {
    try createVertexBuffers(&state.vkState, state.allocator);
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    const movePieceUx = &vkState.movePieceUx;
    vk.vkDestroyBuffer.?(vkState.logicalDevice, movePieceUx.triangles.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, movePieceUx.lines.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, movePieceUx.sprites.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, movePieceUx.font.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, movePieceUx.triangles.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, movePieceUx.lines.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, movePieceUx.sprites.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, movePieceUx.font.vertexBufferMemory, null);
    allocator.free(movePieceUx.triangles.vertices);
    allocator.free(movePieceUx.lines.vertices);
    allocator.free(movePieceUx.sprites.vertices);
    allocator.free(movePieceUx.font.vertices);
}

fn createVertexBuffers(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    const movePieceUx = &vkState.movePieceUx;
    movePieceUx.triangles.vertices = try allocator.alloc(dataVulkanZig.ColoredVertex, VkMovePiecesUx.MAX_VERTICES_TRIANGLES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.ColoredVertex) * VkMovePiecesUx.MAX_VERTICES_TRIANGLES,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &movePieceUx.triangles.vertexBuffer,
        &movePieceUx.triangles.vertexBufferMemory,
        vkState,
    );
    movePieceUx.lines.vertices = try allocator.alloc(dataVulkanZig.ColoredVertex, VkMovePiecesUx.MAX_VERTICES_LINES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.ColoredVertex) * VkMovePiecesUx.MAX_VERTICES_LINES,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &movePieceUx.lines.vertexBuffer,
        &movePieceUx.lines.vertexBufferMemory,
        vkState,
    );
    movePieceUx.sprites.vertices = try allocator.alloc(dataVulkanZig.SpriteVertex, VkMovePiecesUx.MAX_VERTICES_SPRITES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.SpriteVertex) * VkMovePiecesUx.MAX_VERTICES_SPRITES,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &movePieceUx.sprites.vertexBuffer,
        &movePieceUx.sprites.vertexBufferMemory,
        vkState,
    );
    movePieceUx.font.vertices = try allocator.alloc(dataVulkanZig.FontVertex, VkMovePiecesUx.MAX_VERTICES_FONT);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.FontVertex) * movePieceUx.font.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &movePieceUx.font.vertexBuffer,
        &movePieceUx.font.vertexBufferMemory,
        vkState,
    );
}

fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    const movePieceUx = &vkState.movePieceUx;
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, movePieceUx.triangles.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.ColoredVertex) * movePieceUx.triangles.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    var gpu_vertices: [*]dataVulkanZig.ColoredVertex = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, movePieceUx.triangles.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, movePieceUx.triangles.vertexBufferMemory);

    if (vk.vkMapMemory.?(vkState.logicalDevice, movePieceUx.lines.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.ColoredVertex) * movePieceUx.lines.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    gpu_vertices = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, movePieceUx.lines.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, movePieceUx.lines.vertexBufferMemory);

    if (vk.vkMapMemory.?(vkState.logicalDevice, movePieceUx.sprites.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.SpriteVertex) * movePieceUx.sprites.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpuVerticesSprite: [*]dataVulkanZig.SpriteVertex = @ptrCast(@alignCast(data));
    @memcpy(gpuVerticesSprite, movePieceUx.sprites.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, movePieceUx.sprites.vertexBufferMemory);

    if (vk.vkMapMemory.?(vkState.logicalDevice, movePieceUx.font.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.FontVertex) * movePieceUx.font.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpuVerticesFont: [*]dataVulkanZig.FontVertex = @ptrCast(@alignCast(data));
    @memcpy(gpuVerticesFont, movePieceUx.font.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, movePieceUx.font.vertexBufferMemory);
}

pub fn recordCommandBuffer(commandBuffer: vk.VkCommandBuffer, state: *main.GameState) !void {
    const movePieceUx = &state.vkState.movePieceUx;
    const vkState = &state.vkState;
    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.triangle);
    var vertexBuffers: [1]vk.VkBuffer = .{movePieceUx.triangles.vertexBuffer};
    var offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(movePieceUx.triangles.verticeCount), 1, 0, 0);

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.sprite);
    vertexBuffers = .{movePieceUx.sprites.vertexBuffer};
    offsets = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(movePieceUx.sprites.verticeCount), 1, 0, 0);

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.lines);
    vertexBuffers = .{movePieceUx.lines.vertexBuffer};
    offsets = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(movePieceUx.lines.verticeCount), 1, 0, 0);

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.font.graphicsPipeline);
    vertexBuffers = .{movePieceUx.font.vertexBuffer};
    offsets = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(movePieceUx.font.verticeCount), 1, 0, 0);
}
