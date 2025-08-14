const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const enemyObjectProjectileZig = @import("enemyObjectProjectile.zig");

pub fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_ENEMY_SHURIKEN_THROWER,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .projectileAttack = .{
                .delay = 5000,
                .direction = std.crypto.random.int(u2),
            },
        },
    };
}

pub fn tick(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = &enemy.enemyTypeData.projectileAttack;
    if (data.startTime) |startTime| {
        if (startTime + data.delay < state.gameTime) {
            const stepDirection = movePieceZig.getStepDirection(data.direction);
            const spawnPosition: main.Position = .{
                .x = enemy.position.x + stepDirection.x * main.TILESIZE,
                .y = enemy.position.y + stepDirection.y * main.TILESIZE,
            };
            try enemyObjectProjectileZig.spawnProjectile(
                spawnPosition,
                data.direction,
                imageZig.IMAGE_SHURIKEN,
                1000,
                false,
                state,
            );
            data.startTime = null;
        }
    } else {
        data.startTime = state.gameTime;
        data.direction = std.crypto.random.int(u2);
    }
}

pub fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) void {
    const data = enemy.enemyTypeData.projectileAttack;
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
