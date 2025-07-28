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
                    lastPosition = position;
                    position.x += moveX;
                    position.y += moveY;
                    var x = position.x * onePixelXInVulkan;
                    var y = position.y * onePixelYInVulkan;
                    if (stepCount == moveStep.stepCount - 1) {
                        if (moveStepIndex == movePiece.steps.len - 1) {
                            verticesForSquare(x, y, baseWidth, baseHeight, lineColor, lines);
                            verticesForFilledArrow(x, y, baseWidth * 0.9, baseHeight * 0.9, @intCast(@mod(direction + 3, 4)), lineColor, lines, triangles);
                        } else {
                            const nextDirection = @mod(movePiece.steps[moveStepIndex + 1].direction + direction, 4);
                            var rotation: f32 = 0;
                            const offsetAngledX = baseWidth / 4.0;
                            const offsetAngledY = baseHeight / 4.0;
                            switch (moveDirection) {
                                movePieceZig.DIRECTION_UP => {
                                    if (nextDirection == movePieceZig.DIRECTION_LEFT) {
                                        rotation = std.math.pi * 1.25;
                                        x -= offsetAngledX;
                                        y += offsetAngledY;
                                    } else {
                                        rotation = std.math.pi * 1.75;
                                        x += offsetAngledX;
                                        y += offsetAngledY;
                                    }
                                },
                                movePieceZig.DIRECTION_DOWN => {
                                    if (nextDirection == movePieceZig.DIRECTION_LEFT) {
                                        rotation = std.math.pi * 0.75;
                                        x -= offsetAngledX;
                                        y -= offsetAngledY;
                                    } else {
                                        rotation = std.math.pi * 0.25;
                                        x += offsetAngledX;
                                        y -= offsetAngledY;
                                    }
                                },
                                movePieceZig.DIRECTION_LEFT => {
                                    if (nextDirection == movePieceZig.DIRECTION_UP) {
                                        rotation = std.math.pi * 1.25;
                                        x += offsetAngledX;
                                        y -= offsetAngledY;
                                    } else {
                                        x += offsetAngledX;
                                        y += offsetAngledY;
                                        rotation = std.math.pi * 0.75;
                                    }
                                },
                                else => {
                                    if (nextDirection == movePieceZig.DIRECTION_UP) {
                                        rotation = std.math.pi * -0.25;
                                        x -= offsetAngledX;
                                        y -= offsetAngledY;
                                    } else {
                                        rotation = std.math.pi * 0.25;
                                        x -= offsetAngledX;
                                        y += offsetAngledY;
                                    }
                                },
                            }
                            switch (direction) {
                                0 => {
                                    verticesMiddleDotted(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                                },
                                1 => {
                                    verticesMiddleArrowed(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                                },
                                2 => {
                                    verticesMiddleZigZag(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                                },
                                else => {
                                    verticesMiddleLine(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                                },
                            }
                        }
                    } else {
                        var rotation: f32 = 0;
                        switch (moveDirection) {
                            movePieceZig.DIRECTION_UP => {
                                rotation = std.math.pi * 3.0 / 2.0;
                            },
                            movePieceZig.DIRECTION_DOWN => {
                                rotation = std.math.pi / 2.0;
                            },
                            movePieceZig.DIRECTION_LEFT => {
                                rotation = std.math.pi;
                            },
                            else => {},
                        }
                        switch (direction) {
                            0 => {
                                verticesMiddleDotted(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                            },
                            1 => {
                                verticesMiddleArrowed(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                            },
                            2 => {
                                verticesMiddleZigZag(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                            },
                            else => {
                                verticesMiddleLine(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                            },
                        }
                    }
                }
            }
        }
    }
}

fn verticesForArrow(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, arrowDirection: u8, lineColor: [3]f32, lines: *dataVulkanZig.VkLines) void {
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

fn verticesForFilledArrow(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, arrowDirection: u8, fillColor: [3]f32, lines: *dataVulkanZig.VkLines, triangles: *dataVulkanZig.VkTriangles) void {
    if (triangles.verticeCount + 9 >= triangles.vertices.len) return;
    const lineColor: [3]f32 = .{ 0, 0, 0 };
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
    const offsets = [_]main.Position{
        paintVulkanZig.rotateAroundPoint(.{ .x = -0.5, .y = -0.20 }, .{ .x = 0, .y = 0 }, angle),
        paintVulkanZig.rotateAroundPoint(.{ .x = 0.0, .y = -0.20 }, .{ .x = 0, .y = 0 }, angle),
        paintVulkanZig.rotateAroundPoint(.{ .x = 0.0, .y = -0.5 }, .{ .x = 0, .y = 0 }, angle),
        paintVulkanZig.rotateAroundPoint(.{ .x = 0.5, .y = 0 }, .{ .x = 0, .y = 0 }, angle),
        paintVulkanZig.rotateAroundPoint(.{ .x = 0.0, .y = 0.5 }, .{ .x = 0, .y = 0 }, angle),
        paintVulkanZig.rotateAroundPoint(.{ .x = 0.0, .y = 0.20 }, .{ .x = 0, .y = 0 }, angle),
        paintVulkanZig.rotateAroundPoint(.{ .x = -0.5, .y = 0.20 }, .{ .x = 0, .y = 0 }, angle),
        paintVulkanZig.rotateAroundPoint(.{ .x = -0.5, .y = -0.20 }, .{ .x = 0, .y = 0 }, angle),
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var pos: [offsets.len]main.Position = undefined;
    for (0..pos.len) |i| {
        pos[i] = .{ .x = vulkanX + vulkanTileWidth * offsets[i].x, .y = vulkanY + vulkanTileHeight * offsets[i].y };
    }
    var lastPos: main.Position = .{ .x = 0, .y = 0 };
    var currentPos: main.Position = pos[0];
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        currentPos = pos[i];
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
    triangles.vertices[triangles.verticeCount + 0] = .{ .pos = .{ pos[0].x, pos[0].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ pos[1].x, pos[1].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ pos[5].x, pos[5].y }, .color = fillColor };
    triangles.verticeCount += 3;
    triangles.vertices[triangles.verticeCount + 0] = .{ .pos = .{ pos[0].x, pos[0].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ pos[5].x, pos[5].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ pos[6].x, pos[6].y }, .color = fillColor };
    triangles.verticeCount += 3;
    triangles.vertices[triangles.verticeCount + 0] = .{ .pos = .{ pos[2].x, pos[2].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ pos[3].x, pos[3].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ pos[4].x, pos[4].y }, .color = fillColor };
    triangles.verticeCount += 3;
}

fn verticesForSquare(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, lineColor: [3]f32, lines: *dataVulkanZig.VkLines) void {
    const offsets = [_]main.Position{
        .{ .x = -0.45, .y = -0.45 },
        .{ .x = 0.45, .y = -0.45 },
        .{ .x = 0.45, .y = 0.45 },
        .{ .x = -0.45, .y = 0.45 },
        .{ .x = -0.45, .y = -0.45 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var lastPos: main.Position = .{ .x = vulkanX, .y = vulkanY };
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * offsets[0].x, .y = vulkanY + vulkanTileHeight * offsets[0].y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        currentPos = .{ .x = vulkanX + vulkanTileWidth * offsets[i].x, .y = vulkanY + vulkanTileHeight * offsets[i].y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleLine(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [3]f32, lines: *dataVulkanZig.VkLines) void {
    const offsets = [_]main.Position{
        .{ .x = -0.3, .y = 0 },
        .{ .x = 0.3, .y = 0 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var lastPos: main.Position = .{ .x = vulkanX, .y = vulkanY };
    var rotatedOffset = paintVulkanZig.rotateAroundPoint(offsets[0], .{ .x = 0, .y = 0 }, rotation);
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        rotatedOffset = paintVulkanZig.rotateAroundPoint(offsets[i], .{ .x = 0, .y = 0 }, rotation);
        currentPos = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleZigZag(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [3]f32, lines: *dataVulkanZig.VkLines) void {
    const offsets = [_]main.Position{
        .{ .x = -0.3, .y = 0.2 },
        .{ .x = -0.1, .y = -0.2 },
        .{ .x = 0.1, .y = 0.2 },
        .{ .x = 0.3, .y = -0.2 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var lastPos: main.Position = .{ .x = vulkanX, .y = vulkanY };
    var rotatedOffset = paintVulkanZig.rotateAroundPoint(offsets[0], .{ .x = 0, .y = 0 }, rotation);
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        rotatedOffset = paintVulkanZig.rotateAroundPoint(offsets[i], .{ .x = 0, .y = 0 }, rotation);
        currentPos = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleDotted(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [3]f32, lines: *dataVulkanZig.VkLines) void {
    const offsets = [_]main.Position{
        .{ .x = -0.4, .y = 0 },
        .{ .x = -0.3, .y = 0 },
        .{ .x = -0.1, .y = 0 },
        .{ .x = 0.0, .y = 0 },
        .{ .x = 0.2, .y = 0 },
        .{ .x = 0.3, .y = 0 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    for (0..@divFloor(offsets.len, 2)) |i| {
        const rotatedOffset = paintVulkanZig.rotateAroundPoint(offsets[i * 2], .{ .x = 0, .y = 0 }, rotation);
        const rotatedOffset2 = paintVulkanZig.rotateAroundPoint(offsets[i * 2 + 1], .{ .x = 0, .y = 0 }, rotation);
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset.x, vulkanY + vulkanTileHeight * rotatedOffset.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset2.x, vulkanY + vulkanTileHeight * rotatedOffset2.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleArrowed(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [3]f32, lines: *dataVulkanZig.VkLines) void {
    const offsets = [_]main.Position{
        .{ .x = -0.3, .y = 0 },
        .{ .x = 0.3, .y = 0 },
        .{ .x = 0.3, .y = 0 },
        .{ .x = 0.15, .y = -0.15 },
        .{ .x = 0.3, .y = 0 },
        .{ .x = 0.15, .y = 0.15 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    for (0..@divFloor(offsets.len, 2)) |i| {
        const rotatedOffset = paintVulkanZig.rotateAroundPoint(offsets[i * 2], .{ .x = 0, .y = 0 }, rotation);
        const rotatedOffset2 = paintVulkanZig.rotateAroundPoint(offsets[i * 2 + 1], .{ .x = 0, .y = 0 }, rotation);
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset.x, vulkanY + vulkanTileHeight * rotatedOffset.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset2.x, vulkanY + vulkanTileHeight * rotatedOffset2.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
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
