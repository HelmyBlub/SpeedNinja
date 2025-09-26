const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const enemyObjectFireZig = @import("enemyObjectFire.zig");

pub const EnemyTypePutFireData = struct {
    delay: i64 = 3000,
    moveDirection: u8,
    nextMoveTime: ?i64 = null,
    fireDuration: u16 = 12000,
};

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
        .imageIndex = imageZig.IMAGE_ENEMY_FIRE,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .putFire = .{
                .moveDirection = std.crypto.random.int(u2),
            },
        },
    };
}

fn scaleEnemyForNewGamePlus(enemy: *enemyZig.Enemy, newGamePlus: u32) void {
    const data = &enemy.enemyTypeData.putFire;
    data.delay = @divFloor(data.delay, @as(i32, @intCast(newGamePlus + 1)));
}

fn tick(enemy: *enemyZig.Enemy, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &enemy.enemyTypeData.putFire;
    if (data.nextMoveTime) |nextMoveTime| {
        if (nextMoveTime < state.gameTime) {
            const stepDirection = movePieceZig.getStepDirection(data.moveDirection);
            const moveToPosition: main.Position = .{
                .x = enemy.position.x + stepDirection.x * main.TILESIZE,
                .y = enemy.position.y + stepDirection.y * main.TILESIZE,
            };
            try enemyZig.checkPlayerHit(moveToPosition, state);
            try enemyObjectFireZig.spawnFire(moveToPosition, data.fireDuration, false, state);
            enemy.position = moveToPosition;
            data.nextMoveTime = null;
        }
    } else {
        data.moveDirection = std.crypto.random.int(u2);
        const stepDirection = movePieceZig.getStepDirection(data.moveDirection);
        const borderX: f32 = @floatFromInt(state.mapData.tileRadiusWidth * main.TILESIZE);
        const borderY: f32 = @floatFromInt(state.mapData.tileRadiusHeight * main.TILESIZE);
        if (stepDirection.x < 0 and enemy.position.x > -borderX or
            stepDirection.x > 0 and enemy.position.x < borderX or
            stepDirection.y < 0 and enemy.position.y > -borderY or
            stepDirection.y > 0 and enemy.position.y < borderY)
        {
            data.nextMoveTime = state.gameTime + data.delay;
        }
    }
}

fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = enemy.enemyTypeData.putFire;
    if (data.nextMoveTime) |nextMoveTime| {
        const moveStep = movePieceZig.getStepDirection(data.moveDirection);
        const attackPosition: main.Position = .{
            .x = enemy.position.x + moveStep.x * main.TILESIZE,
            .y = enemy.position.y + moveStep.y * main.TILESIZE,
        };
        const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(nextMoveTime - state.gameTime)) / @as(f32, @floatFromInt(data.delay))));
        const rotation: f32 = @as(f32, @floatFromInt(data.moveDirection)) * std.math.pi / 2.0;
        enemyVulkanZig.addRedArrowTileSprites(attackPosition, fillPerCent, rotation, state);
    }
}
