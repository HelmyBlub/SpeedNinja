const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");
const bossZig = @import("../boss/boss.zig");
const enemyZig = @import("../enemy/enemy.zig");

pub fn setupVertices(state: *main.GameState) void {
    for (state.enemyData.enemies.items) |*enemy| {
        if (enemyZig.ENEMY_FUNCTIONS.get(enemy.enemyTypeData).setupVertices) |fVertices| {
            fVertices(enemy, state);
        } else {
            paintVulkanZig.verticesForComplexSpriteDefault(enemy.position, enemy.imageIndex, state);
        }
    }
}

pub fn setupVerticesGround(state: *main.GameState) !void {
    for (state.enemyData.enemies.items) |*enemy| {
        if (enemyZig.ENEMY_FUNCTIONS.get(enemy.enemyTypeData).setupVerticesGround) |ground| try ground(enemy, state);
    }
    for (state.bosses.items) |*boss| {
        try bossZig.LEVEL_BOSS_DATA.get(boss.typeData).setupVerticesGround(boss, state);
    }
}

pub fn setupVerticesForBosses(state: *main.GameState) void {
    for (state.bosses.items) |*boss| {
        bossZig.LEVEL_BOSS_DATA.get(boss.typeData).setupVertices(boss, state);
    }
}

pub fn addWarningShurikenSprites(gamePosition: main.Position, fillPerCent: f32, state: *main.GameState) void {
    addWarningTileSpritesWithImageIndex(gamePosition, fillPerCent, imageZig.IMAGE_WARNING_SHURIKEN, imageZig.IMAGE_WARNING_SHURIKEN_FILLED, state);
}

pub fn addWarningTileSprites(gamePosition: main.Position, fillPerCent: f32, state: *main.GameState) void {
    addWarningTileSpritesWithImageIndex(gamePosition, fillPerCent, imageZig.IMAGE_WARNING_TILE, imageZig.IMAGE_WARNING_TILE_FILLED, state);
}

fn addWarningTileSpritesWithImageIndex(gamePosition: main.Position, fillPerCent: f32, imageIndex: u8, imageIndexFilled: u8, state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;
    if (verticeData.spritesComplex.verticeCount + 12 >= verticeData.spritesComplex.vertices.len) return;
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
            verticeData.spritesComplex.vertices[verticeData.spritesComplex.verticeCount] = dataVulkanZig.SpriteComplexVertex{
                .pos = .{ vulkan.x, vulkan.y },
                .imageIndex = if (i < 2) imageIndexFilled else imageIndex,
                .alpha = 0.7,
                .tex = texPos,
            };
            verticeData.spritesComplex.verticeCount += 1;
        }
    }
}

pub fn setupVerticesGroundForMovePiece(startTile: main.TilePosition, movePiece: movePieceZig.MovePiece, executeDirection: u8, fillPerCent: f32, state: *main.GameState) !void {
    try movePieceZig.executeMovePieceWithCallbackPerStep(f32, movePiece, executeDirection, startTile, fillPerCent, setupVerticesGroundStepFunction, state);
}

fn setupVerticesGroundStepFunction(pos: main.TilePosition, visualizedDirection: u8, fillPerCent: f32, state: *main.GameState) !void {
    const attackPosition: main.Position = .{
        .x = @as(f32, @floatFromInt(pos.x)) * main.TILESIZE,
        .y = @as(f32, @floatFromInt(pos.y)) * main.TILESIZE,
    };
    const rotation: f32 = @as(f32, @floatFromInt(visualizedDirection)) * std.math.pi / 2.0;
    addRedArrowTileSprites(attackPosition, fillPerCent, rotation, state);
}

pub fn addRedArrowTileSprites(gamePosition: main.Position, fillPerCent: f32, rotation: f32, state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;
    if (verticeData.spritesComplex.verticeCount + 12 >= verticeData.spritesComplex.vertices.len) return;
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
            const rotatedOffset = paintVulkanZig.rotateAroundPoint(cornerPosOffset, .{ .x = 0, .y = 0 }, rotation);

            const vulkan: main.Position = .{
                .x = (rotatedOffset.x - state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
                .y = (rotatedOffset.y - state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
            };
            const texPos: [2]f32 = .{
                (cornerPosOffset.x / halfSizeWidth + 1) / 2,
                (cornerPosOffset.y / halfSizeHeigh + 1) / 2,
            };
            verticeData.spritesComplex.vertices[verticeData.spritesComplex.verticeCount] = dataVulkanZig.SpriteComplexVertex{
                .pos = .{ vulkan.x, vulkan.y },
                .imageIndex = if (i < 2) imageZig.IMAGE_RED_ARROW_FILLED else imageZig.IMAGE_RED_ARROW,
                .alpha = 0.7,
                .tex = texPos,
            };
            verticeData.spritesComplex.verticeCount += 1;
        }
    }
}
