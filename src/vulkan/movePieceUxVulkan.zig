const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const dataVulkanZig = @import("dataVulkan.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const movePieceZig = @import("../movePiece.zig");
const fontVulkanZig = @import("fontVulkan.zig");

pub const VkMovePiecesUx = struct {
    triangles: dataVulkanZig.VkTriangles = undefined,
    lines: dataVulkanZig.VkLines = undefined,
    sprites: dataVulkanZig.VkSprites = undefined,
    font: fontVulkanZig.VkFont = undefined,
    const UX_RECTANGLES = 100;
    pub const MAX_VERTICES_TRIANGLES = 6 * UX_RECTANGLES;
    pub const MAX_VERTICES_LINES = 8 * UX_RECTANGLES;
    pub const MAX_VERTICES_SPRITES = UX_RECTANGLES;
    pub const MAX_VERTICES_FONT = 50;
};

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
    movePieceUx.font.vertices = try allocator.alloc(fontVulkanZig.FontVertex, VkMovePiecesUx.MAX_VERTICES_FONT);
    try initVulkanZig.createBuffer(
        @sizeOf(fontVulkanZig.FontVertex) * movePieceUx.font.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &movePieceUx.font.vertexBuffer,
        &movePieceUx.font.vertexBufferMemory,
        vkState,
    );
}

pub fn setupVertices(state: *main.GameState) !void {
    const movePieceUx = &state.vkState.movePieceUx;
    movePieceUx.lines.verticeCount = 0;
    movePieceUx.triangles.verticeCount = 0;
    movePieceUx.sprites.verticeCount = 0;
    movePieceUx.font.verticeCount = 0;
    const startColor: [3]f32 = .{ 0.0, 0.0, 1 };
    const fillColor: [3]f32 = .{ 0.25, 0.25, 0.25 };
    const selctedColor: [3]f32 = .{ 0.07, 0.07, 0.07 };

    for (state.players.items) |player| {
        for (player.moveOptions.items, 0..) |movePiece, index| {
            const rectFillColor = if (player.choosenMoveOptionIndex != null and player.choosenMoveOptionIndex.? == index) selctedColor else fillColor;
            var x: i8 = 0;
            var y: i8 = 0;
            setupRectangleVertices(x, y, movePieceUx, index, player.moveOptions.items.len, startColor);
            for (movePiece.steps) |step| {
                const stepX: i8 = if (step.direction == 0) 1 else if (step.direction == 2) -1 else 0;
                const stepY: i8 = if (step.direction == 1) 1 else if (step.direction == 3) -1 else 0;
                for (0..step.stepCount) |_| {
                    x += stepX;
                    y += stepY;
                    setupRectangleVertices(x, y, movePieceUx, index, player.moveOptions.items.len, rectFillColor);
                }
            }
        }

        if (player.choosenMoveOptionIndex) |index| {
            const lines = &movePieceUx.lines;
            const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
            const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
            const zoomedTileSize = main.TILESIZE * state.camera.zoom;
            const baseWidth = zoomedTileSize * onePixelXInVulkan;
            const baseHeight = zoomedTileSize * onePixelYInVulkan;
            for (0..4) |direction| {
                var step: f32 = 0;
                var position: main.Position = .{
                    .x = player.position.x * state.camera.zoom,
                    .y = player.position.y * state.camera.zoom,
                };

                const lineColor: [3]f32 = .{
                    if (direction == 0) 0.5 else 0,
                    if (direction == 1) 0.2 else 0,
                    if (direction == 2) 0.5 else 0,
                };

                var lastPosition: main.Position = position;
                var lastMoveDirection: usize = 0;
                var moveDirection: usize = 0;
                for (player.moveOptions.items[index].steps, 0..) |moveStep, moveStepIndex| {
                    lastMoveDirection = moveDirection;
                    moveDirection = @mod(moveStep.direction + direction, 4);
                    const moveX: f32 = if (moveDirection == 0) zoomedTileSize else if (moveDirection == 2) -zoomedTileSize else 0;
                    const moveY: f32 = if (moveDirection == 1) zoomedTileSize else if (moveDirection == 3) -zoomedTileSize else 0;
                    for (0..moveStep.stepCount) |stepCount| {
                        step += 1;
                        const recFator = 1 / (1 + step / 8);
                        lastPosition = position;
                        position.x += moveX;
                        position.y += moveY;
                        if (moveStepIndex == 0 and stepCount == 0) continue;
                        if (lines.verticeCount + 8 >= lines.vertices.len) break;
                        const left = (lastPosition.x - zoomedTileSize / 2 * recFator) * onePixelXInVulkan;
                        const top = (lastPosition.y - zoomedTileSize / 2 * recFator) * onePixelYInVulkan;
                        const width = baseWidth * recFator;
                        const height = baseHeight * recFator;
                        if (moveDirection != movePieceZig.DIRECTION_UP and !(stepCount == 0 and lastMoveDirection == movePieceZig.DIRECTION_DOWN) and !(stepCount > 0 and moveDirection == movePieceZig.DIRECTION_DOWN)) {
                            lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top }, .color = lineColor };
                            lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top }, .color = lineColor };
                            lines.verticeCount += 2;
                        }
                        if (moveDirection != movePieceZig.DIRECTION_DOWN and !(stepCount == 0 and lastMoveDirection == movePieceZig.DIRECTION_UP) and !(stepCount > 0 and moveDirection == movePieceZig.DIRECTION_UP)) {
                            lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top + height }, .color = lineColor };
                            lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = lineColor };
                            lines.verticeCount += 2;
                        }
                        if (moveDirection != movePieceZig.DIRECTION_LEFT and !(stepCount == 0 and lastMoveDirection == movePieceZig.DIRECTION_RIGHT) and !(stepCount > 0 and moveDirection == movePieceZig.DIRECTION_RIGHT)) {
                            lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top }, .color = lineColor };
                            lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left, top + height }, .color = lineColor };
                            lines.verticeCount += 2;
                        }
                        if (moveDirection != movePieceZig.DIRECTION_RIGHT and !(stepCount == 0 and lastMoveDirection == movePieceZig.DIRECTION_LEFT) and !(stepCount > 0 and moveDirection == movePieceZig.DIRECTION_LEFT)) {
                            lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left + width, top }, .color = lineColor };
                            lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = lineColor };
                            lines.verticeCount += 2;
                        }
                    }
                }
                const recFator = 1 / (1 + step / 4);
                const left = (position.x - zoomedTileSize / 2 * recFator) * onePixelXInVulkan;
                const top = (position.y - zoomedTileSize / 2 * recFator) * onePixelYInVulkan;
                const width = baseWidth * recFator;
                const height = baseHeight * recFator;
                if (moveDirection != movePieceZig.DIRECTION_DOWN) {
                    lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top }, .color = lineColor };
                    lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top }, .color = lineColor };
                    lines.verticeCount += 2;
                }
                if (moveDirection != movePieceZig.DIRECTION_UP) {
                    lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top + height }, .color = lineColor };
                    lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = lineColor };
                    lines.verticeCount += 2;
                }
                if (moveDirection != movePieceZig.DIRECTION_RIGHT) {
                    lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top }, .color = lineColor };
                    lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left, top + height }, .color = lineColor };
                    lines.verticeCount += 2;
                }
                if (moveDirection != movePieceZig.DIRECTION_LEFT) {
                    lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left + width, top }, .color = lineColor };
                    lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = lineColor };
                    lines.verticeCount += 2;
                }
            }
        }
    }

    const fontSize = 30;
    const player = state.players.items[0];
    const remainingPieces = player.availableMovePieces.items.len + player.moveOptions.items.len;
    const totalPieces = remainingPieces + player.usedMovePieces.items.len;
    var textWidthPieces = try fontVulkanZig.paintNumber(remainingPieces, .{ .x = 0.5, .y = 0.8 }, fontSize, &movePieceUx.font);
    textWidthPieces += fontVulkanZig.paintText(":", .{ .x = 0.5 + textWidthPieces, .y = 0.8 }, fontSize, &movePieceUx.font);
    _ = try fontVulkanZig.paintNumber(totalPieces, .{ .x = 0.5 + textWidthPieces, .y = 0.8 }, fontSize, &movePieceUx.font);

    try setupVertexDataForGPU(&state.vkState);
}

fn setupRectangleVertices(leftIndex: i8, topIndex: i8, movePieceUx: *VkMovePiecesUx, currentMovePieceIndex: usize, maxMovePieces: usize, fillColor: [3]f32) void {
    const borderColor: [3]f32 = .{ 0, 0, 0 };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const size = main.TILESIZE;
    const width = size * onePixelXInVulkan;
    const height = size * onePixelYInVulkan;
    const pieceXSpacing = width * 8;
    const someWidth = @as(f32, @floatFromInt(maxMovePieces - 1)) * pieceXSpacing - width / 2;
    const leftStart = -someWidth / 2;
    const left: f32 = @as(f32, @floatFromInt(leftIndex)) * width + leftStart + pieceXSpacing * @as(f32, @floatFromInt(currentMovePieceIndex));
    const offsetY = 0.9;
    const top: f32 = @as(f32, @floatFromInt(topIndex)) * height + offsetY;

    const lines = &movePieceUx.lines;
    const triangles = &movePieceUx.triangles;
    if (triangles.verticeCount + 6 >= triangles.vertices.len) return;
    triangles.vertices[triangles.verticeCount] = .{ .pos = .{ left, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ left, top + height }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 3] = .{ .pos = .{ left, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 4] = .{ .pos = .{ left + width, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 5] = .{ .pos = .{ left + width, top + height }, .color = fillColor };
    triangles.verticeCount += 6;

    if (lines.verticeCount + 8 >= lines.vertices.len) return;
    lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top }, .color = borderColor };
    lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top }, .color = borderColor };
    lines.vertices[lines.verticeCount + 2] = .{ .pos = .{ left, top }, .color = borderColor };
    lines.vertices[lines.verticeCount + 3] = .{ .pos = .{ left, top + height }, .color = borderColor };
    lines.vertices[lines.verticeCount + 4] = .{ .pos = .{ left + width, top }, .color = borderColor };
    lines.vertices[lines.verticeCount + 5] = .{ .pos = .{ left + width, top + height }, .color = borderColor };
    lines.vertices[lines.verticeCount + 6] = .{ .pos = .{ left, top + height }, .color = borderColor };
    lines.vertices[lines.verticeCount + 7] = .{ .pos = .{ left + width, top + height }, .color = borderColor };
    lines.verticeCount += 8;
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

    if (vk.vkMapMemory.?(vkState.logicalDevice, movePieceUx.font.vertexBufferMemory, 0, @sizeOf(fontVulkanZig.FontVertex) * movePieceUx.font.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpuVerticesFont: [*]fontVulkanZig.FontVertex = @ptrCast(@alignCast(data));
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
