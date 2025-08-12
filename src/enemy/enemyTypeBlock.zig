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
    minTurnInterval: i32 = 4000,
};

pub fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_ENEMY_SHIELD,
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
        const closestPlayer = main.findClosestPlayer(enemy.position, state);
        if (closestPlayer.executeMovePiece == null) {
            const direction = main.getDirectionFromTo(enemy.position, closestPlayer.position);
            if (direction != data.direction) {
                data.direction = direction;
                data.lastTurnTime = state.gameTime;
            }
        }
    }
}

pub fn isEnemyHit(enemy: *enemyZig.Enemy, hitArea: main.TileRectangle, hitDirection: u8) bool {
    const data = &enemy.enemyTypeData.block;
    const enemyTile = main.gamePositionToTilePosition(enemy.position);
    if (main.isTilePositionInTileRectangle(enemyTile, hitArea)) {
        if (@mod(hitDirection + 2, 4) == data.direction) return false;
        return true;
    }
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
