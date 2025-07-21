const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const soundMixerZig = @import("../soundMixer.zig");
const ninjaDogVulkan = @import("ninjaDogVulkan.zig");
const movePieceZig = @import("../movePiece.zig");

pub const VkEnemyData = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []dataVulkanZig.SpriteComplexVertex = undefined,
    verticeCount: usize = 0,
    pub const MAX_VERTICES = 200; //TODO not checked limit
};

fn setupVertices(state: *main.GameState) !void {
    state.vkState.enemyData.verticeCount = 0;
    for (state.enemies.items) |enemy| {
        switch (enemy.enemyTypeData) {
            .nothing => {},
            .attack => |data| {
                const moveStep = movePieceZig.getStepDirection(data.direction);
                const attackPosition: main.Position = .{
                    .x = enemy.position.x + moveStep.x * main.TILESIZE,
                    .y = enemy.position.y + moveStep.y * main.TILESIZE,
                };
                const fillPerCent: f32 = @min(1, @max(0, @as(f32, @floatFromInt(state.gameTime - data.startTime)) / @as(f32, @floatFromInt(data.delay))));
                addWarningTileSprites(attackPosition, moveStep, fillPerCent, state);
            },
        }
    }
    try setupVertexDataForGPU(&state.vkState);
}

pub fn addWarningTileSprites(gamePosition: main.Position, direction: main.Position, fillPerCent: f32, state: *main.GameState) void {
    _ = direction;
    const enemyData = &state.vkState.enemyData;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const imageData = imageZig.IMAGE_DATA[imageZig.IMAGE_WARNING_TILE];
    const scaling = 2;
    const halfSizeWidth: f32 = @as(f32, @floatFromInt(imageData.width)) / imageZig.IMAGE_TO_GAME_SIZE / 2 * scaling;
    const halfSizeHeigh: f32 = @as(f32, @floatFromInt(imageData.height)) / imageZig.IMAGE_TO_GAME_SIZE / 2 * scaling;
    const points = [_]main.Position{
        main.Position{ .x = -halfSizeWidth, .y = halfSizeHeigh },
        main.Position{ .x = -halfSizeWidth, .y = -halfSizeHeigh },
        main.Position{ .x = -halfSizeWidth + halfSizeWidth * 2 * fillPerCent, .y = halfSizeHeigh },
        main.Position{ .x = -halfSizeWidth + halfSizeWidth * 2 * fillPerCent, .y = -halfSizeHeigh },
        main.Position{ .x = halfSizeWidth, .y = halfSizeHeigh },
        main.Position{ .x = halfSizeWidth, .y = -halfSizeHeigh },
    };

    for (0..points.len - 2) |i| {
        const pointsIndexes = [_]usize{ i, i + 1 + @mod(i, 2), i + 2 - @mod(i, 2) };
        for (pointsIndexes) |verticeIndex| {
            const cornerPosOffset = points[verticeIndex];
            const vulkan: main.Position = .{
                .x = (cornerPosOffset.x - state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
                .y = (cornerPosOffset.y - state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
            };
            const texPos: [2]f32 = .{
                (cornerPosOffset.x / halfSizeWidth + 1) / 2,
                (cornerPosOffset.y / halfSizeHeigh + 1) / 2,
            };
            enemyData.vertices[enemyData.verticeCount] = dataVulkanZig.SpriteComplexVertex{
                .pos = .{ vulkan.x, vulkan.y },
                .imageIndex = if (i < 2) imageZig.IMAGE_WARNING_TILE_FILLED else imageZig.IMAGE_WARNING_TILE,
                .alpha = 1,
                .tex = texPos,
            };
            enemyData.verticeCount += 1;
        }
    }
}

pub fn create(state: *main.GameState) !void {
    try createVertexBuffer(&state.vkState, state.allocator);
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    const enemies = vkState.enemyData;
    vk.vkDestroyBuffer.?(vkState.logicalDevice, enemies.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, enemies.vertexBufferMemory, null);
    allocator.free(enemies.vertices);
}

fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    const enemy = vkState.enemyData;
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, enemy.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.SpriteComplexVertex) * enemy.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpu_vertices: [*]dataVulkanZig.SpriteComplexVertex = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, enemy.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, enemy.vertexBufferMemory);
}

pub fn recordCommandBuffer(commandBuffer: vk.VkCommandBuffer, state: *main.GameState) !void {
    try setupVertices(state);
    const vkState = &state.vkState;

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.spriteComplex);
    const vertexBuffers: [1]vk.VkBuffer = .{vkState.enemyData.vertexBuffer};
    const offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(vkState.enemyData.verticeCount), 1, 0, 0);
}

fn createVertexBuffer(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    vkState.enemyData.vertices = try allocator.alloc(dataVulkanZig.SpriteComplexVertex, VkEnemyData.MAX_VERTICES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.SpriteComplexVertex) * vkState.enemyData.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.enemyData.vertexBuffer,
        &vkState.enemyData.vertexBufferMemory,
        vkState,
    );
}
