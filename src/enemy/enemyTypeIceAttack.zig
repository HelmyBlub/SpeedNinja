const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const enemyObjectProjectileZig = @import("enemyObjectProjectile.zig");

pub const DelayedAttackWithCooldown = struct {
    direction: u8,
    startTime: ?i64 = null,
    waitUntil: ?i64 = null,
    delay: i64 = 1500,
    cooldown: i32 = 500,
    attackMovementInterval: i32 = 500,
};

pub fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_ENEMY_SHURIKEN_THROWER,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .ice = .{
                .direction = std.crypto.random.int(u2),
            },
        },
    };
}

pub fn tick(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = &enemy.enemyTypeData.ice;
    if (data.startTime) |startTime| {
        if (startTime + data.delay < state.gameTime) {
            const stepDirection = movePieceZig.getStepDirection(data.direction);
            const spawnPosition: main.Position = .{
                .x = enemy.position.x + stepDirection.x * main.TILESIZE,
                .y = enemy.position.y + stepDirection.y * main.TILESIZE,
            };
            try enemyObjectProjectileZig.spawnProjectile(spawnPosition, data.direction, imageZig.IMAGE_SHURIKEN, data.attackMovementInterval, state);
            data.startTime = null;
            data.waitUntil = state.gameTime + data.cooldown;
        }
    } else if (data.waitUntil) |waitUntil| {
        if (waitUntil <= state.gameTime) data.waitUntil = null;
    } else {
        const enemyTile = main.gamePositionToTilePosition(enemy.position);
        for (state.players.items) |player| {
            const playerTile = main.gamePositionToTilePosition(player.position);
            if (enemyTile.x == playerTile.x) {
                data.startTime = state.gameTime;
                if (enemyTile.y > playerTile.y) {
                    data.direction = movePieceZig.DIRECTION_UP;
                } else {
                    data.direction = movePieceZig.DIRECTION_DOWN;
                }
            } else if (enemyTile.y == playerTile.y) {
                data.startTime = state.gameTime;
                if (enemyTile.x > playerTile.x) {
                    data.direction = movePieceZig.DIRECTION_LEFT;
                } else {
                    data.direction = movePieceZig.DIRECTION_RIGHT;
                }
            }
        }
    }
}

pub fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) void {
    const data = enemy.enemyTypeData.ice;
    if (data.startTime) |startTime| {
        const moveStep = movePieceZig.getStepDirection(data.direction);
        const attackPosition: main.Position = .{
            .x = enemy.position.x + moveStep.x * main.TILESIZE,
            .y = enemy.position.y + moveStep.y * main.TILESIZE,
        };
        const fillPerCent: f32 = @min(1, @max(0, @as(f32, @floatFromInt(state.gameTime - startTime)) / @as(f32, @floatFromInt(data.delay))));
        enemyVulkanZig.addWarningShurikenSprites(attackPosition, fillPerCent, state);
    }
}
