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
        .scaleEnemyForNewGamePlus = scaleEnemyForNewGamePlus,
    };
}

fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_EVIL_TREE,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .attack = .{
                .delay = 5000,
            },
        },
    };
}

fn scaleEnemyForNewGamePlus(enemy: *enemyZig.Enemy, newGamePlus: u32) void {
    const data = &enemy.enemyTypeData.attack;
    data.delay = @divFloor(data.delay, @as(i32, @intCast(newGamePlus + 1)));
}

fn tick(enemy: *enemyZig.Enemy, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &enemy.enemyTypeData.attack;
    if (data.startTime) |startTime| {
        if (startTime + data.delay < state.gameTime) {
            const stepDirection = movePieceZig.getStepDirection(data.direction);
            const hitPosition: main.Position = .{
                .x = enemy.position.x + stepDirection.x * main.TILESIZE,
                .y = enemy.position.y + stepDirection.y * main.TILESIZE,
            };
            try enemyZig.checkPlayerHit(hitPosition, state);
            data.startTime = null;
        }
    } else {
        data.startTime = state.gameTime;
        data.direction = std.crypto.random.int(u2);
    }
}

fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = enemy.enemyTypeData.attack;
    if (data.startTime) |startTime| {
        const moveStep = movePieceZig.getStepDirection(data.direction);
        const attackPosition: main.Position = .{
            .x = enemy.position.x + moveStep.x * main.TILESIZE,
            .y = enemy.position.y + moveStep.y * main.TILESIZE,
        };
        const fillPerCent: f32 = @min(1, @max(0, @as(f32, @floatFromInt(state.gameTime - startTime)) / @as(f32, @floatFromInt(data.delay))));
        enemyVulkanZig.addWarningTileSprites(attackPosition, fillPerCent, state);
    }
}
