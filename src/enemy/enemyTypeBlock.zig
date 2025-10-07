const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const soundMixerZig = @import("../soundMixer.zig");
const playerZig = @import("../player.zig");

pub const EnemyTypeBlockData = struct {
    direction: u8,
    lastTurnTime: i64 = 0,
    minTurnInterval: i32 = 4000,
    aoeAttackDelay: i32 = 2000,
    aoeAttackTime: ?i64 = null,
    aoeDamageVisualization: ?i64 = null,
    aoeDamageVisualizationDuration: i32 = 250,
    attackTileRadius: i8 = 1,
};

pub fn create() enemyZig.EnemyFunctions {
    return enemyZig.EnemyFunctions{
        .createSpawnEnemyEntryEnemy = createSpawnEnemyEntryEnemy,
        .tick = tick,
        .setupVerticesGround = setupVerticesGround,
        .setupVertices = setupVertices,
        .isEnemyHit = isEnemyHit,
        .scaleEnemyForNewGamePlus = scaleEnemyForNewGamePlus,
    };
}

fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
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

fn scaleEnemyForNewGamePlus(enemy: *enemyZig.Enemy, newGamePlus: u32) void {
    const data = &enemy.enemyTypeData.block;
    data.aoeAttackDelay = @divFloor(data.aoeAttackDelay, @as(i32, @intCast(newGamePlus + 1)));
    data.minTurnInterval = @divFloor(data.minTurnInterval, @as(i32, @intCast(newGamePlus + 1)));
}

fn tick(enemy: *enemyZig.Enemy, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &enemy.enemyTypeData.block;
    if (data.lastTurnTime + data.minTurnInterval < state.gameTime) {
        const closestPlayer = playerZig.findClosestPlayer(enemy.position, state);
        if (closestPlayer.executeMovePiece == null) {
            const direction = main.getDirectionFromTo(enemy.position, closestPlayer.position);
            if (direction != data.direction) {
                data.direction = direction;
                data.lastTurnTime = state.gameTime;
            }
        }
    }
    if (data.aoeAttackTime != null and data.aoeAttackTime.? <= state.gameTime) {
        data.aoeAttackTime = null;
        const enemyTile = main.gamePositionToTilePosition(enemy.position);
        const attackRadius = data.attackTileRadius;
        const damageTileRectangle: main.TileRectangle = .{
            .pos = .{ .x = enemyTile.x - attackRadius, .y = enemyTile.y - attackRadius },
            .height = attackRadius * 2 + 1,
            .width = attackRadius * 2 + 1,
        };
        for (state.players.items) |*player| {
            const playerTile = main.gamePositionToTilePosition(player.position);
            if (main.isTilePositionInTileRectangle(playerTile, damageTileRectangle)) {
                try playerZig.playerHit(player, state);
            }
        }
        data.aoeDamageVisualization = state.gameTime + data.aoeDamageVisualizationDuration;
    }
    if (data.aoeDamageVisualization) |visualizationTime| {
        if (visualizationTime <= state.gameTime) {
            data.aoeDamageVisualization = null;
        }
    }
}

fn isEnemyHit(enemy: *enemyZig.Enemy, hitArea: main.TileRectangle, hitDirection: u8, state: *main.GameState) !bool {
    const data = &enemy.enemyTypeData.block;
    const enemyTile = main.gamePositionToTilePosition(enemy.position);
    if (main.isTilePositionInTileRectangle(enemyTile, hitArea)) {
        if (@mod(hitDirection + 2, 4) == data.direction) {
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_ENEMY_BLOCK_INDICIES[0..], 0, 1);
            if (data.aoeAttackTime == null) data.aoeAttackTime = state.gameTime + data.aoeAttackDelay;
            return false;
        }
        return true;
    }
    return false;
}

fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = enemy.enemyTypeData.block;
    if (data.aoeDamageVisualization) |visualizationTime| {
        if (visualizationTime > state.gameTime) {
            const alphaPerCent: f32 = @as(f32, @floatFromInt(visualizationTime - state.gameTime)) / @as(f32, @floatFromInt(data.aoeDamageVisualizationDuration));
            paintVulkanZig.verticesForGameRectangle(
                .{
                    .pos = .{ .x = enemy.position.x - main.TILESIZE, .y = enemy.position.y - main.TILESIZE },
                    .width = (@as(f32, @floatFromInt(data.attackTileRadius)) * 2 + 1) * main.TILESIZE,
                    .height = (@as(f32, @floatFromInt(data.attackTileRadius)) * 2 + 1) * main.TILESIZE,
                },
                .{ 0.8, 0, 0, alphaPerCent },
                state,
            );
        }
    }
    if (data.aoeAttackTime) |attackTime| {
        const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(attackTime - state.gameTime)) / @as(f32, @floatFromInt(data.aoeAttackDelay))));
        const size: usize = @intCast(data.attackTileRadius * 2 + 1);
        for (0..size) |i| {
            const offsetX: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(i)) - data.attackTileRadius)) * main.TILESIZE;
            for (0..size) |j| {
                const offsetY: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(j)) - data.attackTileRadius)) * main.TILESIZE;
                enemyVulkanZig.addWarningTileSprites(.{
                    .x = enemy.position.x + offsetX,
                    .y = enemy.position.y + offsetY,
                }, fillPerCent, state);
            }
        }
    }
}

fn setupVertices(enemy: *enemyZig.Enemy, state: *main.GameState) void {
    const data = enemy.enemyTypeData.block;
    const rotation: f32 = @as(f32, @floatFromInt(data.direction)) * std.math.pi / 2.0;
    paintVulkanZig.verticesForComplexSpriteWithRotate(enemy.position, enemy.imageIndex, rotation, 1, state);
}
