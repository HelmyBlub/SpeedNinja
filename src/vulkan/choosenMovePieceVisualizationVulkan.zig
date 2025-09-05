const std = @import("std");
const main = @import("../main.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");
const movePieceZig = @import("../movePiece.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const mapTileZig = @import("../mapTile.zig");
const imageZig = @import("../image.zig");

pub const VkChoosenMovePieceVisualization = struct {
    triangles: dataVulkanZig.VkColoredVertexes = undefined,
    lines: dataVulkanZig.VkColoredVertexes = undefined,
};

const UX_RECTANGLES = 200; //TODO size
const MAX_VERTICES_TRIANGLES = 6 * UX_RECTANGLES;
const MAX_VERTICES_LINES = 8 * UX_RECTANGLES;

pub fn setupVertices(state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;
    for (state.players.items) |*player| {
        verticesForChoosenMoveOptionVisualization(player, &verticeData.lines, &verticeData.triangles, state);
    }
}

fn verticesForChoosenMoveOptionVisualization(player: *main.Player, lines: *dataVulkanZig.VkColoredVertexes, triangles: *dataVulkanZig.VkColoredVertexes, state: *main.GameState) void {
    if (player.hasBlindfold) return;
    if (player.choosenMoveOptionIndex) |index| {
        const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
        const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
        const zoomedTileSize = main.TILESIZE * state.camera.zoom;
        const baseWidth = zoomedTileSize * onePixelXInVulkan;
        const baseHeight = zoomedTileSize * onePixelYInVulkan;
        const movePiece = player.moveOptions.items[index];
        const pieceTotalSteps = movePieceZig.getMovePieceTotalStepes(movePiece);
        const highlightModLimit = @max(5, pieceTotalSteps + 1);
        for (0..4) |direction| {
            var gamePositionWithCameraOffset: main.Position = .{
                .x = player.position.x - state.camera.position.x,
                .y = player.position.y - state.camera.position.y,
            };

            const lineColorForDirection: [3]f32 = .{
                if (direction == 0) 0.5 else 0,
                if (direction == 1) 0.2 else 0,
                if (direction == 2) 0.5 else 0,
            };
            const highlightedLineColor: [3]f32 = .{ 1, 1, 1 };

            var lastGamePosition: main.Position = gamePositionWithCameraOffset;
            var lastMoveDirection: usize = 0;
            var moveDirection: usize = 0;
            var totalStepCount: usize = 0;
            for (movePiece.steps, 0..) |moveStep, moveStepIndex| {
                lastMoveDirection = moveDirection;
                moveDirection = @mod(moveStep.direction + direction, 4);
                const moveX: f32 = if (moveDirection == 0) main.TILESIZE else if (moveDirection == 2) -main.TILESIZE else 0;
                const moveY: f32 = if (moveDirection == 1) main.TILESIZE else if (moveDirection == 3) -main.TILESIZE else 0;
                var stepCount: usize = 0;
                while (stepCount < moveStep.stepCount) {
                    totalStepCount += 1;
                    const modColor = player.choosenMoveOptionVisualizationOverlapping and @mod(totalStepCount, highlightModLimit) == @mod(@as(usize, @intCast(@divFloor(state.gameTime, 100))), highlightModLimit);
                    const lineColor = if (modColor) highlightedLineColor else lineColorForDirection;
                    lastGamePosition = gamePositionWithCameraOffset;
                    const nextPosition: main.Position = .{
                        .x = gamePositionWithCameraOffset.x + moveX,
                        .y = gamePositionWithCameraOffset.y + moveY,
                    };
                    if (stepCount + 1 < moveStep.stepCount) {
                        const afterNextPosition: main.Position = .{
                            .x = nextPosition.x + moveX,
                            .y = nextPosition.y + moveY,
                        };
                        const afterTilePosition = main.gamePositionToTilePosition(afterNextPosition);
                        const afterTileType = mapTileZig.getMapTilePositionType(afterTilePosition, &state.mapData);
                        if (afterTileType == .wall) {
                            stepCount = moveStep.stepCount - 1;
                        }
                    }
                    const tilePosition = main.gamePositionToTilePosition(nextPosition);
                    const tileType = mapTileZig.getMapTilePositionType(tilePosition, &state.mapData);
                    if (tileType != .wall) {
                        gamePositionWithCameraOffset = nextPosition;
                    }
                    var x = gamePositionWithCameraOffset.x * onePixelXInVulkan * state.camera.zoom;
                    var y = gamePositionWithCameraOffset.y * onePixelYInVulkan * state.camera.zoom;
                    stepCount += 1;
                    if (stepCount == moveStep.stepCount and tileType == .ice) {
                        stepCount -= 1;
                    }
                    if (stepCount == moveStep.stepCount) {
                        if (moveStepIndex == movePiece.steps.len - 1) {
                            verticesForSquare(x, y, baseWidth, baseHeight, lineColor, lines);
                            verticesForFilledArrow(x, y, baseWidth * 0.9, baseHeight * 0.9, @intCast(@mod(direction + 3, 4)), lineColorForDirection, lines, triangles);
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
                if (player.hasWeaponKunai) {
                    const kunaiRange = 2;
                    for (1..kunaiRange + 1) |i| {
                        const fi: f32 = @floatFromInt(i);
                        const gamePosition: main.Position = .{
                            .x = gamePositionWithCameraOffset.x + state.camera.position.x + moveX * fi,
                            .y = gamePositionWithCameraOffset.y + state.camera.position.y + moveY * fi,
                        };
                        paintVulkanZig.verticesForComplexSpriteAlpha(gamePosition, imageZig.IMAGE_KUNAI_TILE_INDICATOR, 0.25, state);
                    }
                }
            }
            if (player.hasWeaponHammer) {
                const hammerPositionOffsets = [_]main.Position{
                    .{ .x = -main.TILESIZE, .y = -main.TILESIZE },
                    .{ .x = 0, .y = -main.TILESIZE },
                    .{ .x = main.TILESIZE, .y = -main.TILESIZE },
                    .{ .x = -main.TILESIZE, .y = 0 },
                    .{ .x = main.TILESIZE, .y = 0 },
                    .{ .x = -main.TILESIZE, .y = main.TILESIZE },
                    .{ .x = 0, .y = main.TILESIZE },
                    .{ .x = main.TILESIZE, .y = main.TILESIZE },
                };
                for (0..hammerPositionOffsets.len) |i| {
                    const gamePosition: main.Position = .{
                        .x = gamePositionWithCameraOffset.x + state.camera.position.x + hammerPositionOffsets[i].x,
                        .y = gamePositionWithCameraOffset.y + state.camera.position.y + hammerPositionOffsets[i].y,
                    };
                    paintVulkanZig.verticesForComplexSpriteAlpha(gamePosition, imageZig.IMAGE_HAMMER_TILE_INDICATOR, 0.25, state);
                }
            }
        }
    }
}

fn verticesForArrow(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, arrowDirection: u8, lineColor: [3]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
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
    var rotatedOffset = main.rotateAroundPoint(offsets[0], .{ .x = 0, .y = 0 }, angle);
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        rotatedOffset = main.rotateAroundPoint(offsets[i], .{ .x = 0, .y = 0 }, angle);
        currentPos = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesForFilledArrow(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, arrowDirection: u8, fillColor: [3]f32, lines: *dataVulkanZig.VkColoredVertexes, triangles: *dataVulkanZig.VkColoredVertexes) void {
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
        main.rotateAroundPoint(.{ .x = -0.5, .y = -0.20 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = 0.0, .y = -0.20 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = 0.0, .y = -0.5 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = 0.5, .y = 0 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = 0.0, .y = 0.5 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = 0.0, .y = 0.20 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = -0.5, .y = 0.20 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = -0.5, .y = -0.20 }, .{ .x = 0, .y = 0 }, angle),
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

fn verticesForSquare(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, lineColor: [3]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
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

fn verticesMiddleLine(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [3]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
    const offsets = [_]main.Position{
        .{ .x = -0.3, .y = 0 },
        .{ .x = 0.3, .y = 0 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var lastPos: main.Position = .{ .x = vulkanX, .y = vulkanY };
    var rotatedOffset = main.rotateAroundPoint(offsets[0], .{ .x = 0, .y = 0 }, rotation);
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        rotatedOffset = main.rotateAroundPoint(offsets[i], .{ .x = 0, .y = 0 }, rotation);
        currentPos = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleZigZag(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [3]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
    const offsets = [_]main.Position{
        .{ .x = -0.3, .y = 0.2 },
        .{ .x = -0.1, .y = -0.2 },
        .{ .x = 0.1, .y = 0.2 },
        .{ .x = 0.3, .y = -0.2 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var lastPos: main.Position = .{ .x = vulkanX, .y = vulkanY };
    var rotatedOffset = main.rotateAroundPoint(offsets[0], .{ .x = 0, .y = 0 }, rotation);
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        rotatedOffset = main.rotateAroundPoint(offsets[i], .{ .x = 0, .y = 0 }, rotation);
        currentPos = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleDotted(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [3]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
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
        const rotatedOffset = main.rotateAroundPoint(offsets[i * 2], .{ .x = 0, .y = 0 }, rotation);
        const rotatedOffset2 = main.rotateAroundPoint(offsets[i * 2 + 1], .{ .x = 0, .y = 0 }, rotation);
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset.x, vulkanY + vulkanTileHeight * rotatedOffset.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset2.x, vulkanY + vulkanTileHeight * rotatedOffset2.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleArrowed(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [3]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
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
        const rotatedOffset = main.rotateAroundPoint(offsets[i * 2], .{ .x = 0, .y = 0 }, rotation);
        const rotatedOffset2 = main.rotateAroundPoint(offsets[i * 2 + 1], .{ .x = 0, .y = 0 }, rotation);
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset.x, vulkanY + vulkanTileHeight * rotatedOffset.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset2.x, vulkanY + vulkanTileHeight * rotatedOffset2.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

pub fn isChoosenPieceVisualizationOverlapping(movePiece: movePieceZig.MovePiece) bool {
    var x1: i32 = 0;
    var y1: i32 = 0;
    for (0..movePiece.steps.len) |movePieceIndex1| {
        const movePiece1Steps = movePiece.steps[movePieceIndex1];
        const stepDirection = movePieceZig.getStepDirectionTile(movePiece1Steps.direction);
        for (0..movePiece1Steps.stepCount) |stepCount1| {
            x1 += stepDirection.x;
            y1 += stepDirection.y;
            if (x1 == 0 and y1 == 0) return true;
            var x2: i32 = x1;
            var y2: i32 = y1;
            for (movePieceIndex1..movePiece.steps.len) |movePieceIndex2| {
                const stepCount2Start = if (movePieceIndex2 == movePieceIndex1) stepCount1 + 1 else 0;
                const movePiece2Steps = movePiece.steps[movePieceIndex2];
                const stepDirection2 = movePieceZig.getStepDirectionTile(movePiece2Steps.direction);
                for (stepCount2Start..movePiece2Steps.stepCount) |_| {
                    x2 += stepDirection2.x;
                    y2 += stepDirection2.y;
                    if ((x1 == y2 and y1 == -x2) or (x1 == -x2 and y1 == -y2) or (x1 == -y2 and y1 == x2)) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}
