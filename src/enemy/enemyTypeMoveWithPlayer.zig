const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const playerZig = @import("../player.zig");

pub const EnemyTypeMoveWithPlayerData = struct {
    direction: u8,
    waitCount: u32 = 0,
    moveDistance: u8 = 1,
    maxMoveDistance: u8 = 1,
};

pub fn create() enemyZig.EnemyFunctions {
    return enemyZig.EnemyFunctions{
        .createSpawnEnemyEntryEnemy = createSpawnEnemyEntryEnemy,
        .onPlayerMoved = onPlayerMoved,
        .setupVerticesGround = setupVerticesGround,
        .scaleEnemyForNewGamePlus = scaleEnemyForNewGamePlus,
    };
}

fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_ENEMY_EYE,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .moveWithPlayer = .{
                .direction = std.crypto.random.int(u2),
            },
        },
    };
}

fn scaleEnemyForNewGamePlus(enemy: *enemyZig.Enemy, newGamePlus: u32) void {
    const data = &enemy.enemyTypeData.moveWithPlayer;
    data.maxMoveDistance += @min(newGamePlus, 3);
}

fn onPlayerMoved(enemy: *enemyZig.Enemy, player: *playerZig.Player, state: *main.GameState) !void {
    _ = player;
    const data = &enemy.enemyTypeData.moveWithPlayer;
    data.waitCount += 1;
    if (data.waitCount < state.players.items.len) return;
    const stepDirection = movePieceZig.getStepDirection(data.direction);
    for (0..data.moveDistance) |_| {
        const hitPosition: main.Position = .{
            .x = enemy.position.x + stepDirection.x * main.TILESIZE,
            .y = enemy.position.y + stepDirection.y * main.TILESIZE,
        };
        try enemyZig.checkPlayerHit(hitPosition, state);
        enemy.position = hitPosition;
    }
    data.waitCount = 0;

    var validDirection: bool = false;
    const borderX: f32 = @floatFromInt(state.mapData.tileRadiusWidth * main.TILESIZE);
    const borderY: f32 = @floatFromInt(state.mapData.tileRadiusHeight * main.TILESIZE);
    while (!validDirection) {
        data.direction = std.crypto.random.int(u2);
        const newStepDirection = movePieceZig.getStepDirection(data.direction);
        data.moveDistance = std.crypto.random.intRangeAtMost(u8, 1, data.maxMoveDistance);
        const fMoveDistance: f32 = @floatFromInt(data.moveDistance * main.TILESIZE);
        validDirection = newStepDirection.x < 0 and enemy.position.x - fMoveDistance > -borderX or
            newStepDirection.x > 0 and enemy.position.x + fMoveDistance < borderX or
            newStepDirection.y < 0 and enemy.position.y - fMoveDistance > -borderY or
            newStepDirection.y > 0 and enemy.position.y + fMoveDistance < borderY;
    }
}

fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = enemy.enemyTypeData.moveWithPlayer;
    const moveStep = movePieceZig.getStepDirection(data.direction);
    const fillPerCent: f32 = @as(f32, @floatFromInt(data.waitCount + 1)) / @as(f32, @floatFromInt(state.players.items.len));
    for (0..data.moveDistance) |i| {
        const fi = @as(f32, @floatFromInt(i + 1));
        const attackPosition: main.Position = .{
            .x = enemy.position.x + moveStep.x * main.TILESIZE * fi,
            .y = enemy.position.y + moveStep.y * main.TILESIZE * fi,
        };
        enemyVulkanZig.addWarningTileSprites(attackPosition, fillPerCent, state);
    }
}
