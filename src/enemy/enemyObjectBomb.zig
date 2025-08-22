const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const movePieceZig = @import("../movePiece.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const enemyZig = @import("enemy.zig");
const enemyObjectZig = @import("enemyObject.zig");

pub const EnemyBomb = struct {
    explodeTime: i64,
    explodeDelay: i32,
    exploded: bool = false,
    explodeRadius: u8 = 1,
};

pub fn createEnemyObjectFunctions() enemyObjectZig.EnemyObjectFunctions {
    return enemyObjectZig.EnemyObjectFunctions{
        .setupVertices = setupVertices,
        .tick = tick,
        .shouldBeRemoved = shouldBeRemoved,
        .setupVerticesGround = setupVerticesGround,
    };
}

pub fn spawnBomb(position: main.Position, explodeDelay: i32, state: *main.GameState) !void {
    try state.enemyData.enemyObjects.append(.{
        .position = position,
        .typeData = .{ .bomb = .{
            .explodeTime = state.gameTime + explodeDelay,
            .explodeDelay = explodeDelay,
        } },
    });
}

fn setupVertices(object: *enemyObjectZig.EnemyObject, state: *main.GameState) void {
    paintVulkanZig.verticesForComplexSpriteDefault(object.position, imageZig.IMAGE_BOMB, state);
}

fn tick(object: *enemyObjectZig.EnemyObject, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const bomb = &object.typeData.bomb;
    if (!bomb.exploded and bomb.explodeTime <= state.gameTime) {
        const size = bomb.explodeRadius * 2 + 1;
        const fRadius: f32 = @floatFromInt(bomb.explodeRadius);
        for (0..size) |x| {
            for (0..size) |y| {
                const hitPosition: main.Position = .{
                    .x = object.position.x + (@as(f32, @floatFromInt(x)) - fRadius) * main.TILESIZE,
                    .y = object.position.y + (@as(f32, @floatFromInt(y)) - fRadius) * main.TILESIZE,
                };
                try enemyZig.checkStationaryPlayerHit(hitPosition, state);
            }
        }
        bomb.exploded = true;
    }
}

fn shouldBeRemoved(object: *enemyObjectZig.EnemyObject, state: *main.GameState) bool {
    _ = state;
    const bomb = object.typeData.bomb;
    return bomb.exploded;
}

fn setupVerticesGround(object: *enemyObjectZig.EnemyObject, state: *main.GameState) void {
    const bomb = object.typeData.bomb;
    const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(bomb.explodeTime - state.gameTime)) / @as(f32, @floatFromInt(bomb.explodeDelay))));
    const size: usize = @intCast(bomb.explodeRadius * 2 + 1);
    const fRadius: f32 = @floatFromInt(bomb.explodeRadius);
    for (0..size) |i| {
        const offsetX: f32 = (@as(f32, @floatFromInt(i)) - fRadius) * main.TILESIZE;
        for (0..size) |j| {
            const offsetY: f32 = (@as(f32, @floatFromInt(j)) - fRadius) * main.TILESIZE;
            enemyVulkanZig.addWarningTileSprites(.{
                .x = object.position.x + offsetX,
                .y = object.position.y + offsetY,
            }, fillPerCent, state);
        }
    }
}
