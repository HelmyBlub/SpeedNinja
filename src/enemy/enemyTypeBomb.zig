const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const enemyObjectBombZig = @import("enemyObjectBomb.zig");

pub const EnemyTypeBombData = struct {
    moveInterval: i32 = 3000,
    bombExplodeDelay: i32 = 2000,
    direction: u8 = 0,
    nextMoveTime: ?i64 = null,
};

pub fn create() enemyZig.EnemyFunctions {
    return enemyZig.EnemyFunctions{
        .createSpawnEnemyEntryEnemy = createSpawnEnemyEntryEnemy,
        .tick = tick,
        .setupVerticesGround = setupVerticesGround,
        .scaleEnemyForNewGamePlus = scaleEnemyForNewGamePlus,
    };
}

fn scaleEnemyForNewGamePlus(enemy: *enemyZig.Enemy, newGamePlus: u32) void {
    const data = &enemy.enemyTypeData.bomb;
    data.bombExplodeDelay = @divFloor(data.bombExplodeDelay, @as(i32, @intCast(newGamePlus + 1)));
    data.moveInterval = @divFloor(data.moveInterval, @as(i32, @intCast(newGamePlus + 1)));
}

pub fn setupMovePiece(state: *main.GameState) !void {
    const steps: []movePieceZig.MoveStep = try state.allocator.alloc(movePieceZig.MoveStep, 1);
    steps[0].stepCount = 2;
    steps[0].direction = movePieceZig.DIRECTION_UP;
    state.enemyData.bombEnemyMovePiece = .{ .steps = steps };
}

fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_ENEMY_BOMB,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .bomb = .{},
        },
    };
}

fn tick(enemy: *enemyZig.Enemy, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &enemy.enemyTypeData.bomb;
    if (data.nextMoveTime) |nextMoveTime| {
        if (nextMoveTime <= state.gameTime) {
            try enemyObjectBombZig.spawnBomb(enemy.position, data.bombExplodeDelay, state);
            try movePieceZig.attackMovePieceCheckPlayerHit(&enemy.position, enemy.imageIndex, state.enemyData.bombEnemyMovePiece, data.direction, state);
            data.nextMoveTime = null;
        }
    } else {
        data.direction = std.crypto.random.int(u2);
        const stepDirection = movePieceZig.getStepDirection(data.direction);
        const borderX: f32 = @floatFromInt(state.mapData.tileRadiusWidth * main.TILESIZE);
        const borderY: f32 = @floatFromInt(state.mapData.tileRadiusHeight * main.TILESIZE);
        const stepDistance: f32 = @floatFromInt(state.enemyData.bombEnemyMovePiece.steps[0].stepCount);
        if (stepDirection.x < 0 and enemy.position.x - stepDistance > -borderX or
            stepDirection.x > 0 and enemy.position.x + stepDistance < borderX or
            stepDirection.y < 0 and enemy.position.y - stepDistance > -borderY or
            stepDirection.y > 0 and enemy.position.y + stepDistance < borderY)
        {
            data.nextMoveTime = state.gameTime + data.moveInterval;
        }
    }
}

fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = enemy.enemyTypeData.bomb;
    if (data.nextMoveTime) |nextMoveTime| {
        const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(nextMoveTime - state.gameTime)) / @as(f32, @floatFromInt(data.moveInterval))));
        const enemyTile = main.gamePositionToTilePosition(enemy.position);
        try enemyVulkanZig.setupVerticesGroundForMovePiece(enemyTile, state.enemyData.bombEnemyMovePiece, data.direction, fillPerCent, state);
    }
}
