const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const dataVulkanZig = @import("dataVulkan.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");

pub const VkMovePiecesUx = struct {
    triangles: dataVulkanZig.VkTriangles = undefined,
    lines: dataVulkanZig.VkLines = undefined,
    sprites: dataVulkanZig.VkSprites = undefined,
    const UX_RECTANGLES = 50;
    pub const MAX_VERTICES_TRIANGLES = 6 * UX_RECTANGLES;
    pub const MAX_VERTICES_LINES = 8 * UX_RECTANGLES;
    pub const MAX_VERTICES_SPRITES = UX_RECTANGLES;
};

pub fn create(state: *main.GameState) !void {
    try createVertexBuffers(&state.vkState, state.allocator);
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    const movePieceUx = &vkState.movePieceUx;
    vk.vkDestroyBuffer.?(vkState.logicalDevice, movePieceUx.triangles.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, movePieceUx.lines.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, movePieceUx.sprites.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, movePieceUx.triangles.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, movePieceUx.lines.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, movePieceUx.sprites.vertexBufferMemory, null);
    allocator.free(movePieceUx.triangles.vertices);
    allocator.free(movePieceUx.lines.vertices);
    allocator.free(movePieceUx.sprites.vertices);
}

fn createVertexBuffers(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    vkState.movePieceUx.triangles.vertices = try allocator.alloc(dataVulkanZig.ColoredVertex, VkMovePiecesUx.MAX_VERTICES_TRIANGLES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.ColoredVertex) * VkMovePiecesUx.MAX_VERTICES_TRIANGLES,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.movePieceUx.triangles.vertexBuffer,
        &vkState.movePieceUx.triangles.vertexBufferMemory,
        vkState,
    );
    vkState.movePieceUx.lines.vertices = try allocator.alloc(dataVulkanZig.ColoredVertex, VkMovePiecesUx.MAX_VERTICES_LINES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.ColoredVertex) * VkMovePiecesUx.MAX_VERTICES_LINES,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.movePieceUx.lines.vertexBuffer,
        &vkState.movePieceUx.lines.vertexBufferMemory,
        vkState,
    );
    vkState.movePieceUx.sprites.vertices = try allocator.alloc(dataVulkanZig.SpriteVertex, VkMovePiecesUx.MAX_VERTICES_SPRITES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.SpriteVertex) * VkMovePiecesUx.MAX_VERTICES_SPRITES,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.movePieceUx.sprites.vertexBuffer,
        &vkState.movePieceUx.sprites.vertexBufferMemory,
        vkState,
    );
}

pub fn setupVertices(state: *main.GameState) !void {
    const movePieceUx = &state.vkState.movePieceUx;
    movePieceUx.lines.verticeCount = 0;
    movePieceUx.triangles.verticeCount = 0;
    movePieceUx.sprites.verticeCount = 0;
    const startColor: [3]f32 = .{ 0.0, 0.0, 1 };
    const fillColor: [3]f32 = .{ 0.25, 0.25, 0.25 };

    for (state.player.moveOptions.items, 0..) |movePiece, index| {
        var x: i8 = 0;
        var y: i8 = 0;
        setupRectangleVertices(x, y, movePieceUx, index, state.player.moveOptions.items.len, startColor);
        for (movePiece.steps) |step| {
            const stepX: i8 = if (step.direction == 0) 1 else if (step.direction == 2) -1 else 0;
            const stepY: i8 = if (step.direction == 1) 1 else if (step.direction == 3) -1 else 0;
            for (0..step.stepCount) |_| {
                x += stepX;
                y += stepY;
                setupRectangleVertices(x, y, movePieceUx, index, state.player.moveOptions.items.len, fillColor);
            }
        }
    }

    try setupVertexDataForGPU(&state.vkState);
}

fn setupRectangleVertices(leftIndex: i8, topIndex: i8, movePieceUx: *VkMovePiecesUx, currentMovePieceIndex: usize, maxMovePieces: usize, fillColor: [3]f32) void {
    const borderColor: [3]f32 = .{ 0, 0, 0 };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const size = 20;
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

    if (vk.vkMapMemory.?(vkState.logicalDevice, vkState.movePieceUx.lines.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.ColoredVertex) * movePieceUx.lines.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    gpu_vertices = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, movePieceUx.lines.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, movePieceUx.lines.vertexBufferMemory);

    if (vk.vkMapMemory.?(vkState.logicalDevice, movePieceUx.sprites.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.SpriteVertex) * movePieceUx.sprites.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpuVerticesSprite: [*]dataVulkanZig.SpriteVertex = @ptrCast(@alignCast(data));
    @memcpy(gpuVerticesSprite, movePieceUx.sprites.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, movePieceUx.sprites.vertexBufferMemory);
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
}
