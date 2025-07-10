const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const dataVulkanZig = @import("dataVulkan.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");

pub const VkMapGridUx = struct {
    lines: dataVulkanZig.VkLines = undefined,
    pub const MAX_VERTICES_LINES = 200;
};

pub fn create(state: *main.GameState) !void {
    try createVertexBuffers(&state.vkState, state.allocator);
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    const mapGrid = &vkState.mapGrid;
    vk.vkDestroyBuffer.?(vkState.logicalDevice, mapGrid.lines.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, mapGrid.lines.vertexBufferMemory, null);
    allocator.free(mapGrid.lines.vertices);
}

fn createVertexBuffers(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    const mapGrid = &vkState.mapGrid;
    mapGrid.lines.vertices = try allocator.alloc(dataVulkanZig.ColoredVertex, VkMapGridUx.MAX_VERTICES_LINES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.ColoredVertex) * mapGrid.lines.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &mapGrid.lines.vertexBuffer,
        &mapGrid.lines.vertexBufferMemory,
        vkState,
    );
}

pub fn setupVertices(state: *main.GameState) !void {
    const mapGrid = &state.vkState.mapGrid;
    mapGrid.lines.verticeCount = 0;
    const lines = &mapGrid.lines;
    const color: [3]f32 = .{ 0.25, 0.25, 0.25 };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const zoomedTileSize = main.TILESIZE * state.camera.zoom;
    const mapRadius: f32 = @as(f32, @floatFromInt(state.mapTileRadius)) * zoomedTileSize;
    const left: f32 = (-mapRadius - zoomedTileSize / 2) * onePixelXInVulkan;
    const right: f32 = (mapRadius + zoomedTileSize * 0.5) * onePixelXInVulkan;
    const top: f32 = (-mapRadius - zoomedTileSize / 2) * onePixelYInVulkan;
    const bottom: f32 = (mapRadius + zoomedTileSize * 0.5) * onePixelYInVulkan;
    for (0..(state.mapTileRadius * 2 + 2)) |i| {
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
    try setupVertexDataForGPU(&state.vkState);
}

fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    const mapGrid = &vkState.mapGrid;
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, mapGrid.lines.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.ColoredVertex) * mapGrid.lines.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpu_vertices: [*]dataVulkanZig.ColoredVertex = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, mapGrid.lines.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, mapGrid.lines.vertexBufferMemory);
}

pub fn recordCommandBuffer(commandBuffer: vk.VkCommandBuffer, state: *main.GameState) !void {
    try setupVertices(state);
    const mapGrid = &state.vkState.mapGrid;
    const vkState = &state.vkState;

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.linesSubpass0);
    var vertexBuffers: [1]vk.VkBuffer = .{mapGrid.lines.vertexBuffer};
    var offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(mapGrid.lines.verticeCount), 1, 0, 0);
}
