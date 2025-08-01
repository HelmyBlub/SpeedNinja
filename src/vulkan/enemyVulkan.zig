const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");

pub fn setupVertices(state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;
    for (state.enemies.items) |enemy| {
        switch (enemy.enemyTypeData) {
            .nothing => {},
            .attack => |data| {
                if (data.startTime) |startTime| {
                    const moveStep = movePieceZig.getStepDirection(data.direction);
                    const attackPosition: main.Position = .{
                        .x = enemy.position.x + moveStep.x * main.TILESIZE,
                        .y = enemy.position.y + moveStep.y * main.TILESIZE,
                    };
                    const fillPerCent: f32 = @min(1, @max(0, @as(f32, @floatFromInt(state.gameTime - startTime)) / @as(f32, @floatFromInt(data.delay))));
                    addWarningTileSprites(attackPosition, fillPerCent, state);
                }
            },
        }
    }
    for (state.enemies.items) |enemy| {
        paintVulkanZig.verticesForComplexSprite(enemy.position, enemy.imageIndex, &verticeData.spritesComplex, state);
    }
}

pub fn setupVerticesForBosses(state: *main.GameState) void {
    for (state.bosses.items) |boss| {
        var bossPosition = boss.position;
        if (boss.inAir) {
            bossPosition.y -= main.TILESIZE / 2;
        }
        if (boss.state == .chargeStomp) {
            const fillPerCent: f32 = @min(1, @max(0, @as(f32, @floatFromInt(boss.attackChargeTime + state.gameTime - boss.nextStateTime)) / @as(f32, @floatFromInt(boss.attackChargeTime))));
            const size: usize = @intCast(boss.attackTileRadius * 2 + 1);
            for (0..size) |i| {
                const offsetX: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(i)) - boss.attackTileRadius)) * main.TILESIZE;
                for (0..size) |j| {
                    const offsetY: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(j)) - boss.attackTileRadius)) * main.TILESIZE;
                    addWarningTileSprites(.{
                        .x = boss.position.x + offsetX,
                        .y = boss.position.y + offsetY,
                    }, fillPerCent, state);
                }
            }
        }
        paintVulkanZig.verticesForComplexSprite(bossPosition, boss.imageIndex, &state.vkState.verticeData.spritesComplex, state);
    }
}

fn addWarningTileSprites(gamePosition: main.Position, fillPerCent: f32, state: *main.GameState) void {
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
                .imageIndex = if (i < 2) imageZig.IMAGE_WARNING_TILE_FILLED else imageZig.IMAGE_WARNING_TILE,
                .alpha = 1,
                .tex = texPos,
            };
            verticeData.spritesComplex.verticeCount += 1;
        }
    }
}
