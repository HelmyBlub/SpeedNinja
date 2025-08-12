const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");

pub const EnemyTypeBlockData = struct {
    direction: u8,
    lastTurnTime: i64 = 0,
    minTurnInterval: i32 = 2000,
};

pub fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_EVIL_TREE,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .block = .{
                .direction = std.crypto.random.int(u2),
            },
        },
    };
}

pub fn tick(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = &enemy.enemyTypeData.block;
    if (data.lastTurnTime + data.minTurnInterval < state.gameTime) {
        data.direction = @mod(data.direction + 1, 4);
        data.lastTurnTime = state.gameTime;
        // find closest player
        // check direction
        // adjust direction if necessary
    }
}

pub fn isHit(enemy: *enemyZig.Enemy, hitMoveDirection: u8, hitPosition: main.Position) bool {
    const data = &enemy.enemyTypeData.block;
    _ = hitMoveDirection;
    _ = hitPosition;
    _ = data;
    return false;
}

pub fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) void {
    const data = enemy.enemyTypeData.block;
    _ = data;
    _ = state;
}

pub fn setupVertices(enemy: *enemyZig.Enemy, state: *main.GameState) void {
    const data = enemy.enemyTypeData.block;
    const rotation: f32 = @as(f32, @floatFromInt(data.direction)) * std.math.pi / 2.0;
    paintVulkanZig.verticesForComplexSpriteWithRotate(
        enemy.position,
        enemy.imageIndex,
        rotation,
        &state.vkState.verticeData.spritesComplex,
        state,
    );
}
