const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");

pub const EnemyTypeAttackData = struct {
    delay: i64 = 5000,
    visualizeAttack: ?i64 = null,
    oldDirection: u8 = 0,
    direction: u8 = 0,
    startTime: ?i64 = null,
};
const ATTACK_VISUALIZE_DURATION = 250;

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
        .enemyTypeData = .{ .attack = .{} },
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
            try enemyZig.checkStationaryPlayerHit(hitPosition, state);
            data.oldDirection = data.direction;
            data.visualizeAttack = state.gameTime + ATTACK_VISUALIZE_DURATION;
            data.startTime = null;
        }
    } else {
        data.startTime = state.gameTime;
        data.direction = std.crypto.random.int(u2);
    }
}

fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = enemy.enemyTypeData.attack;
    if (data.visualizeAttack) |visualizationTime| {
        if (visualizationTime > state.gameTime) {
            const alphaPerCent: f32 = @as(f32, @floatFromInt(visualizationTime - state.gameTime)) / @as(f32, @floatFromInt(ATTACK_VISUALIZE_DURATION));
            const stepDirection = movePieceZig.getStepDirection(data.oldDirection);
            paintVulkanZig.verticesForGameRectangle(
                .{ .pos = .{
                    .x = enemy.position.x + main.TILESIZE * stepDirection.x,
                    .y = enemy.position.y + main.TILESIZE * stepDirection.y,
                }, .width = main.TILESIZE, .height = main.TILESIZE },
                .{ 0.8, 0, 0, alphaPerCent },
                state,
            );
        }
    }
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
