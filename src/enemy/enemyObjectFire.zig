const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const movePieceZig = @import("../movePiece.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const enemyZig = @import("enemy.zig");
const enemyObjectZig = @import("enemyObject.zig");

pub const EnemyFire = struct {
    imageIndex: u8,
    removeTime: i64,
};

pub fn createEnemyObjectFunctions() enemyObjectZig.EnemyObjectFunctions {
    return enemyObjectZig.EnemyObjectFunctions{
        .setupVertices = setupVertices,
        .tick = tick,
        .shouldBeRemoved = shouldBeRemoved,
    };
}

pub fn spawnFire(position: main.Position, duration: i32, state: *main.GameState) !void {
    try state.enemyData.enemyObjects.append(.{
        .position = position,
        .functionsIndex = 1, //TODO
        .typeData = .{ .fire = .{
            .imageIndex = imageZig.IMAGE_FIRE_ANIMATION,
            .removeTime = state.gameTime + duration,
        } },
    });
}

fn setupVertices(object: *enemyObjectZig.EnemyObject, state: *main.GameState) void {
    const fire = object.typeData.fire;
    const animatePerCent: f32 = @mod(@as(f32, @floatFromInt(state.gameTime)) / 500, 1);
    paintVulkanZig.verticesForComplexSpriteAnimated(
        object.position,
        fire.imageIndex,
        animatePerCent,
        2,
        &state.vkState.verticeData.spritesComplex,
        state,
    );
}

fn tick(object: *enemyObjectZig.EnemyObject, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    try enemyZig.checkStationaryPlayerHit(object.position, state);
}

fn shouldBeRemoved(object: *enemyObjectZig.EnemyObject, state: *main.GameState) bool {
    const fire = object.typeData.fire;
    return fire.removeTime <= state.gameTime;
}
