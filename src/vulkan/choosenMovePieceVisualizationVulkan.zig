const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const dataVulkanZig = @import("dataVulkan.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const movePieceZig = @import("../movePiece.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const movePieceVulkanZig = @import("movePieceUxVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");

pub const VkChoosenMovePieceVisualization = struct {
    triangles: dataVulkanZig.VkTriangles = undefined,
    lines: dataVulkanZig.VkLines = undefined,
};

const UX_RECTANGLES = 200; //TODO size
const MAX_VERTICES_TRIANGLES = 6 * UX_RECTANGLES;
const MAX_VERTICES_LINES = 8 * UX_RECTANGLES;

pub fn setupVertices(state: *main.GameState) !void {
    const choosen = &state.vkState.choosenMovePiece;
    choosen.lines.verticeCount = 0;
    choosen.triangles.verticeCount = 0;
    for (state.players.items) |*player| {
        verticesForChoosenMoveOptionVisualization(player, &choosen.lines, &choosen.triangles, state);
    }
    try setupVertexDataForGPU(&state.vkState);
}

fn verticesForChoosenMoveOptionVisualization(player: *main.Player, lines: *dataVulkanZig.VkLines, triangles: *dataVulkanZig.VkTriangles, state: *main.GameState) void {
    if (player.choosenMoveOptionIndex) |index| {
        const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
        const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
        const zoomedTileSize = main.TILESIZE * state.camera.zoom;
        const baseWidth = zoomedTileSize * onePixelXInVulkan;
        const baseHeight = zoomedTileSize * onePixelYInVulkan;
        const movePiece = player.moveOptions.items[index];
        _ = triangles;
        for (0..4) |direction| {
            // if (direction == @mod(@divFloor(state.gameTime, 1000), 4)) {
            //     const left = (player.position.x * state.camera.zoom - zoomedTileSize / 2) * onePixelXInVulkan;
            //     const top = (player.position.y * state.camera.zoom - zoomedTileSize / 2) * onePixelYInVulkan;
            //     _ = movePieceVulkanZig.verticesForMovePiece(movePiece, .{ 0.25, 0.25, 0.25 }, left, top, baseWidth, baseHeight, @intCast(direction), true, lines, triangles);
            //     continue;
            // }
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
            for (movePiece.steps, 0..) |moveStep, moveStepIndex| {
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
            // const recFator = 1 / (1 + step / 4);
            // const left = (position.x - zoomedTileSize / 2 * recFator) * onePixelXInVulkan;
            // const top = (position.y - zoomedTileSize / 2 * recFator) * onePixelYInVulkan;
            // const width = baseWidth * recFator;
            // const height = baseHeight * recFator;
            // if (moveDirection != movePieceZig.DIRECTION_DOWN) {
            //     lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top }, .color = lineColor };
            //     lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top }, .color = lineColor };
            //     lines.verticeCount += 2;
            // }
            // if (moveDirection != movePieceZig.DIRECTION_UP) {
            //     lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top + height }, .color = lineColor };
            //     lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = lineColor };
            //     lines.verticeCount += 2;
            // }
            // if (moveDirection != movePieceZig.DIRECTION_RIGHT) {
            //     lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top }, .color = lineColor };
            //     lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left, top + height }, .color = lineColor };
            //     lines.verticeCount += 2;
            // }
            // if (moveDirection != movePieceZig.DIRECTION_LEFT) {
            //     lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left + width, top }, .color = lineColor };
            //     lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = lineColor };
            //     lines.verticeCount += 2;
            // }
            const left = (position.x) * onePixelXInVulkan;
            const top = (position.y) * onePixelYInVulkan;
            verticesForArrowCorner(left, top, baseWidth, baseHeight, @intCast(moveDirection), lineColor, lines);
        }
    }
}

fn verticesForArrowCorner(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, arrowDirection: u8, lineColor: [3]f32, lines: *dataVulkanZig.VkLines) void {
    const offsets = [_]main.Position{
        .{ .x = -0.5, .y = -0.20 },
        .{ .x = 0.0, .y = -0.20 },
        .{ .x = 0.0, .y = -0.5 },
        .{ .x = 0.5, .y = 0 },
        .{ .x = 0.0, .y = 0.5 },
        .{ .x = 0.0, .y = 0.20 },
        .{ .x = -0.5, .y = 0.20 },
        .{ .x = -0.5, .y = -0.20 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var lastPos: main.Position = .{ .x = vulkanX, .y = vulkanY };
    var angle: f32 = 0;
    switch (arrowDirection) {
        movePieceZig.DIRECTION_UP => {
            angle = std.math.pi * 3.0 / 2.0;
        },
        movePieceZig.DIRECTION_DOWN => {
            angle = std.math.pi / 2.0;
        },
        movePieceZig.DIRECTION_LEFT => {
            angle = std.math.pi;
        },
        else => {},
    }
    var rotatedOffset = paintVulkanZig.rotateAroundPoint(offsets[0], .{ .x = 0, .y = 0 }, angle);
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        rotatedOffset = paintVulkanZig.rotateAroundPoint(offsets[i], .{ .x = 0, .y = 0 }, angle);
        currentPos = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesForEnd() void {
    //
}

fn verticesMiddleShapeDashLine() void {
    //
}

pub fn create(state: *main.GameState) !void {
    try createVertexBuffers(&state.vkState, state.allocator);
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    const choosenMovePiece = &vkState.choosenMovePiece;
    vk.vkDestroyBuffer.?(vkState.logicalDevice, choosenMovePiece.triangles.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, choosenMovePiece.lines.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, choosenMovePiece.triangles.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, choosenMovePiece.lines.vertexBufferMemory, null);
    allocator.free(choosenMovePiece.triangles.vertices);
    allocator.free(choosenMovePiece.lines.vertices);
}

fn createVertexBuffers(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    const choosenMovePiece = &vkState.choosenMovePiece;
    choosenMovePiece.triangles.vertices = try allocator.alloc(dataVulkanZig.ColoredVertex, MAX_VERTICES_TRIANGLES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.ColoredVertex) * choosenMovePiece.triangles.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &choosenMovePiece.triangles.vertexBuffer,
        &choosenMovePiece.triangles.vertexBufferMemory,
        vkState,
    );
    choosenMovePiece.lines.vertices = try allocator.alloc(dataVulkanZig.ColoredVertex, MAX_VERTICES_LINES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.ColoredVertex) * choosenMovePiece.lines.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &choosenMovePiece.lines.vertexBuffer,
        &choosenMovePiece.lines.vertexBufferMemory,
        vkState,
    );
}

fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    const choosenMovePiece = &vkState.choosenMovePiece;
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, choosenMovePiece.triangles.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.ColoredVertex) * choosenMovePiece.triangles.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    var gpu_vertices: [*]dataVulkanZig.ColoredVertex = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, choosenMovePiece.triangles.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, choosenMovePiece.triangles.vertexBufferMemory);

    if (vk.vkMapMemory.?(vkState.logicalDevice, choosenMovePiece.lines.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.ColoredVertex) * choosenMovePiece.lines.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    gpu_vertices = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, choosenMovePiece.lines.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, choosenMovePiece.lines.vertexBufferMemory);
}

pub fn recordCommandBuffer(commandBuffer: vk.VkCommandBuffer, state: *main.GameState) !void {
    try setupVertices(state);
    const choosenMovePiece = &state.vkState.choosenMovePiece;
    const vkState = &state.vkState;
    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.triangleSubpass0);
    var vertexBuffers: [1]vk.VkBuffer = .{choosenMovePiece.triangles.vertexBuffer};
    var offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(choosenMovePiece.triangles.verticeCount), 1, 0, 0);

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.linesSubpass0);
    vertexBuffers = .{choosenMovePiece.lines.vertexBuffer};
    offsets = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(choosenMovePiece.lines.verticeCount), 1, 0, 0);
}
