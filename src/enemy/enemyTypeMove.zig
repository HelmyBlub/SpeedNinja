const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");

pub fn create() enemyZig.EnemyFunctions {
    return enemyZig.EnemyFunctions{
        .createSpawnEnemyEntryEnemy = createSpawnEnemyEntryEnemy,
        .tick = tick,
        .setupVerticesGround = setupVerticesGround,
    };
}

fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_ENEMY_MOVING,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .move = .{
                .delay = 4000,
            },
        },
    };
}

fn tick(enemy: *enemyZig.Enemy, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &enemy.enemyTypeData.move;
    if (data.startTime) |startTime| {
        if (startTime + data.delay < state.gameTime) {
            const stepDirection = movePieceZig.getStepDirection(data.direction);
            const hitPosition: main.Position = .{
                .x = enemy.position.x + stepDirection.x * main.TILESIZE,
                .y = enemy.position.y + stepDirection.y * main.TILESIZE,
            };
            try enemyZig.checkPlayerHit(hitPosition, state);
            enemy.position = hitPosition;
            data.startTime = null;
        }
    } else {
        data.direction = std.crypto.random.int(u2);
        const stepDirection = movePieceZig.getStepDirection(data.direction);
        const border: f32 = @floatFromInt(state.mapData.tileRadius * main.TILESIZE);
        if (stepDirection.x < 0 and enemy.position.x > -border or
            stepDirection.x > 0 and enemy.position.x < border or
            stepDirection.y < 0 and enemy.position.y > -border or
            stepDirection.y > 0 and enemy.position.y < border)
        {
            data.startTime = state.gameTime;
        }
    }
}

fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) void {
    const data = enemy.enemyTypeData.move;
    if (data.startTime) |startTime| {
        const moveStep = movePieceZig.getStepDirection(data.direction);
        const attackPosition: main.Position = .{
            .x = enemy.position.x + moveStep.x * main.TILESIZE,
            .y = enemy.position.y + moveStep.y * main.TILESIZE,
        };
        const fillPerCent: f32 = @min(1, @max(0, @as(f32, @floatFromInt(state.gameTime - startTime)) / @as(f32, @floatFromInt(data.delay))));
        const rotation: f32 = @as(f32, @floatFromInt(data.direction)) * std.math.pi / 2.0;
        enemyVulkanZig.addRedArrowTileSprites(attackPosition, fillPerCent, rotation, state);
    }
}
