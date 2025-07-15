const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");

const DEATH_DURATION = 3000;

pub const VkCutSpriteData = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []dataVulkanZig.SpriteComplexVertex = undefined,
    verticeCount: usize = 0,
    pub const MAX_VERTICES = 200;
};

fn setupVertices(state: *main.GameState) !void {
    const cutSprite = &state.vkState.cutSpriteData;
    cutSprite.verticeCount = 0;
    var enemyDeathIndex: usize = 0;

    while (enemyDeathIndex < state.enemyDeath.items.len) {
        if (cutSprite.vertices.len <= cutSprite.verticeCount) break;
        const enemyDeath = state.enemyDeath.items[enemyDeathIndex];
        if (enemyDeath.deathTime + DEATH_DURATION < state.gameTime) {
            _ = state.enemyDeath.swapRemove(enemyDeathIndex);
            continue;
        }
        setupVerticesForEnemyDeath(enemyDeath, state);
        enemyDeathIndex += 1;
    }

    try setupVertexDataForGPU(&state.vkState);
}

pub fn create(state: *main.GameState) !void {
    try createVertexBuffer(&state.vkState, state.allocator);
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    const cutSprite = vkState.cutSpriteData;
    vk.vkDestroyBuffer.?(vkState.logicalDevice, cutSprite.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, cutSprite.vertexBufferMemory, null);
    allocator.free(cutSprite.vertices);
}

fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    const cutSprite = vkState.cutSpriteData;
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, cutSprite.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.SpriteComplexVertex) * cutSprite.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpu_vertices: [*]dataVulkanZig.SpriteComplexVertex = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, cutSprite.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, cutSprite.vertexBufferMemory);
}

pub fn recordCommandBuffer(commandBuffer: vk.VkCommandBuffer, state: *main.GameState) !void {
    try setupVertices(state);
    const vkState = &state.vkState;

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.spriteComplex);
    const vertexBuffers: [1]vk.VkBuffer = .{vkState.cutSpriteData.vertexBuffer};
    const offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(vkState.cutSpriteData.verticeCount), 1, 0, 0);
}

fn createVertexBuffer(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    vkState.cutSpriteData.vertices = try allocator.alloc(dataVulkanZig.SpriteComplexVertex, VkCutSpriteData.MAX_VERTICES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.SpriteComplexVertex) * vkState.cutSpriteData.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.cutSpriteData.vertexBuffer,
        &vkState.cutSpriteData.vertexBufferMemory,
        vkState,
    );
}

fn setupVerticesForEnemyDeath(enemyDeath: main.EnemyDeathAnimation, state: *main.GameState) void {
    const halfSize = main.TILESIZE / 2;
    const normal: main.Position = .{ .x = @cos(enemyDeath.cutAngle), .y = @sin(enemyDeath.cutAngle) };
    const corners: [4]main.Position = [4]main.Position{
        main.Position{ .x = -halfSize, .y = -halfSize },
        main.Position{ .x = halfSize, .y = -halfSize },
        main.Position{ .x = halfSize, .y = halfSize },
        main.Position{ .x = -halfSize, .y = halfSize },
    };

    var distanceToCutLine: [4]f32 = undefined;
    for (0..4) |i| {
        distanceToCutLine[i] = corners[i].x * normal.x + corners[i].y * normal.y;
    }

    // Split lists for each side
    var positionsPositive: [6]main.Position = undefined;
    var positionsNegative: [6]main.Position = undefined;
    var counterP: usize = 0;
    var counterN: usize = 0;

    // Build polygon outline for each half
    for (0..4) |i| {
        const j = (i + 1) % 4;

        const cornerI = corners[i];
        const cornerJ = corners[j];

        const di: f32 = distanceToCutLine[i];
        const dj: f32 = distanceToCutLine[j];

        // Add current vertex to its side
        if (di >= 0.0) {
            positionsPositive[counterP] = cornerI;
            counterP += 1;
        } else {
            positionsNegative[counterN] = cornerI;
            counterN += 1;
        }

        // Check edge crossing
        if (di * dj < 0.0) {
            const t = di / (di - dj);
            const cutPoint: main.Position = .{ .x = cornerI.x + t * (cornerJ.x - cornerI.x), .y = cornerI.y + t * (cornerJ.y - cornerI.y) };
            positionsPositive[counterP] = cutPoint;
            positionsNegative[counterN] = cutPoint;
            counterP += 1;
            counterN += 1;
        }
    }

    const offsetX: f32 = @as(f32, @floatFromInt(state.gameTime - enemyDeath.deathTime)) / 32 * enemyDeath.force;
    const offsetY: f32 = calculateOffsetY(enemyDeath, state);
    const centerOfRotatePositive: main.Position = .{
        .x = (positionsPositive[0].x + positionsPositive[1].x + positionsPositive[2].x + positionsPositive[3].x) / 4,
        .y = (positionsPositive[0].y + positionsPositive[1].y + positionsPositive[2].y + positionsPositive[3].y) / 4,
    };
    const centerOfRotateNegative: main.Position = .{
        .x = (positionsNegative[0].x + positionsNegative[1].x + positionsNegative[2].x + positionsNegative[3].x) / 4,
        .y = (positionsNegative[0].y + positionsNegative[1].y + positionsNegative[2].y + positionsNegative[3].y) / 4,
    };
    addTriangle(.{ positionsPositive[0], positionsPositive[1], positionsPositive[2] }, enemyDeath, -offsetX, offsetY, centerOfRotatePositive, state);
    addTriangle(.{ positionsPositive[0], positionsPositive[2], positionsPositive[3] }, enemyDeath, -offsetX, offsetY, centerOfRotatePositive, state);
    addTriangle(.{ positionsNegative[0], positionsNegative[1], positionsNegative[2] }, enemyDeath, offsetX, offsetY, centerOfRotateNegative, state);
    addTriangle(.{ positionsNegative[0], positionsNegative[2], positionsNegative[3] }, enemyDeath, offsetX, offsetY, centerOfRotateNegative, state);
}

fn calculateOffsetY(enemyDeath: main.EnemyDeathAnimation, state: *main.GameState) f32 {
    const iterations: f32 = @as(f32, @floatFromInt(@abs(state.gameTime - enemyDeath.deathTime))) / 8;
    const velocity = enemyDeath.force;
    const changePerIteration = 0.01;
    const itEndVelocity = enemyDeath.force - changePerIteration * iterations;
    const avgVelocity = (itEndVelocity + velocity) / 2;
    return -avgVelocity * iterations / 2;
}

fn addTriangle(points: [3]main.Position, enemyDeath: main.EnemyDeathAnimation, offsetX: f32, offsetY: f32, rotateCenter: main.Position, state: *main.GameState) void {
    const alpha = 1 - @as(f32, @floatFromInt(state.gameTime - enemyDeath.deathTime)) / DEATH_DURATION;
    const rotate: f32 = @as(f32, @floatFromInt(state.gameTime - enemyDeath.deathTime)) / 512 * enemyDeath.force;
    const halfSize = main.TILESIZE / 2;
    const cutSprite = &state.vkState.cutSpriteData;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;

    for (points) |point| {
        const rotatedPoint = paintVulkanZig.rotateAroundPoint(point, rotateCenter, rotate);
        const vulkan: main.Position = .{
            .x = (rotatedPoint.x - state.camera.position.x + enemyDeath.position.x + offsetX) * state.camera.zoom * onePixelXInVulkan,
            .y = (rotatedPoint.y - state.camera.position.y + enemyDeath.position.y + offsetY) * state.camera.zoom * onePixelYInVulkan,
        };
        const texPos: main.Position = .{
            .x = (point.x / halfSize + 1) / 2,
            .y = (point.y / halfSize + 1) / 2,
        };
        cutSprite.vertices[cutSprite.verticeCount] = dataVulkanZig.SpriteComplexVertex{
            .pos = .{ vulkan.x, vulkan.y },
            .tex = .{ texPos.x, texPos.y },
            .imageIndex = imageZig.IMAGE_EVIL_TREE,
            .alpha = alpha,
        };
        cutSprite.verticeCount += 1;
    }
}
