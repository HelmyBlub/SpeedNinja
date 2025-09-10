const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const movePieceZig = @import("../movePiece.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const enemyZig = @import("enemy.zig");
const enemyObjectZig = @import("enemyObject.zig");

pub const EnemyFallDown = struct {
    hitTime: i64,
    delay: i32,
    hitCalcDone: bool = false,
};

pub fn createEnemyObjectFunctions() enemyObjectZig.EnemyObjectFunctions {
    return enemyObjectZig.EnemyObjectFunctions{
        .setupVertices = setupVertices,
        .tick = tick,
        .shouldBeRemoved = shouldBeRemoved,
        .setupVerticesGround = setupVerticesGround,
    };
}

pub fn spawnFallDown(position: main.Position, hitDelay: i32, state: *main.GameState) !void {
    try state.enemyData.enemyObjects.append(.{
        .position = position,
        .typeData = .{ .fallDown = .{
            .hitTime = state.gameTime + hitDelay,
            .delay = hitDelay,
        } },
    });
}

fn setupVertices(object: *enemyObjectZig.EnemyObject, state: *main.GameState) void {
    const fallDown = &object.typeData.fallDown;
    const timeUntilHit: f32 = @floatFromInt(fallDown.hitTime - state.gameTime);
    const cannonBallPosiion: main.Position = .{
        .x = object.position.x,
        .y = object.position.y - timeUntilHit / 2,
    };
    paintVulkanZig.verticesForComplexSpriteDefault(cannonBallPosiion, imageZig.IMAGE_CANNON_BALL, state);
}

fn tick(object: *enemyObjectZig.EnemyObject, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const fallDown = &object.typeData.fallDown;
    if (!fallDown.hitCalcDone and fallDown.hitTime <= state.gameTime) {
        const hitPosition: main.Position = .{
            .x = object.position.x,
            .y = object.position.y,
        };
        try enemyZig.checkStationaryPlayerHit(hitPosition, state);
        fallDown.hitCalcDone = true;
    }
}

fn shouldBeRemoved(object: *enemyObjectZig.EnemyObject, state: *main.GameState) bool {
    _ = state;
    const fallDown = &object.typeData.fallDown;
    return fallDown.hitCalcDone;
}

fn setupVerticesGround(object: *enemyObjectZig.EnemyObject, state: *main.GameState) void {
    const fallDown = &object.typeData.fallDown;
    const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(fallDown.hitTime - state.gameTime)) / @as(f32, @floatFromInt(fallDown.delay))));
    enemyVulkanZig.addWarningTileSprites(.{
        .x = object.position.x,
        .y = object.position.y,
    }, fillPerCent, state);
}
