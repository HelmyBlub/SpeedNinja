const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");

pub const EnemyTypeMoveWithPlayerData = struct {
    direction: u8,
    waitCount: u32 = 0,
};

pub fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
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

pub fn onPlayerMoved(enemy: *enemyZig.Enemy, player: *main.Player, state: *main.GameState) !void {
    _ = player;
    const data = &enemy.enemyTypeData.moveWithPlayer;
    data.waitCount += 1;
    if (data.waitCount < state.players.items.len) return;
    const stepDirection = movePieceZig.getStepDirection(data.direction);
    const hitPosition: main.Position = .{
        .x = enemy.position.x + stepDirection.x * main.TILESIZE,
        .y = enemy.position.y + stepDirection.y * main.TILESIZE,
    };
    try enemyZig.checkPlayerHit(hitPosition, state);
    enemy.position = hitPosition;
    data.waitCount = 0;

    var validDirection: bool = false;
    const border: f32 = @floatFromInt(state.mapTileRadius * main.TILESIZE);
    while (!validDirection) {
        data.direction = std.crypto.random.int(u2);
        const newStepDirection = movePieceZig.getStepDirection(data.direction);
        validDirection = newStepDirection.x < 0 and enemy.position.x > -border or
            newStepDirection.x > 0 and enemy.position.x < border or
            newStepDirection.y < 0 and enemy.position.y > -border or
            newStepDirection.y > 0 and enemy.position.y < border;
    }
}

pub fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) void {
    const data = enemy.enemyTypeData.moveWithPlayer;
    const moveStep = movePieceZig.getStepDirection(data.direction);
    const attackPosition: main.Position = .{
        .x = enemy.position.x + moveStep.x * main.TILESIZE,
        .y = enemy.position.y + moveStep.y * main.TILESIZE,
    };
    const fillPerCent: f32 = @as(f32, @floatFromInt(data.waitCount + 1)) / @as(f32, @floatFromInt(state.players.items.len));
    enemyVulkanZig.addWarningTileSprites(attackPosition, fillPerCent, state);
}
