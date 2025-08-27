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
    removeTime: ?i64,
    flyToPosition: ?main.Position = null,
};

pub fn createEnemyObjectFunctions() enemyObjectZig.EnemyObjectFunctions {
    return enemyObjectZig.EnemyObjectFunctions{
        .setupVertices = setupVertices,
        .tick = tick,
        .shouldBeRemoved = shouldBeRemoved,
    };
}

pub fn spawnFlyingEternalFire(spawnPosition: main.Position, flyToPosition: main.Position, state: *main.GameState) !void {
    try state.enemyData.enemyObjects.append(.{
        .position = spawnPosition,
        .typeData = .{ .fire = .{
            .imageIndex = imageZig.IMAGE_FIRE_ANIMATION,
            .removeTime = null,
            .flyToPosition = flyToPosition,
        } },
    });
}

pub fn spawnFire(position: main.Position, duration: i32, state: *main.GameState) !void {
    try state.enemyData.enemyObjects.append(.{
        .position = position,
        .typeData = .{ .fire = .{
            .imageIndex = imageZig.IMAGE_FIRE_ANIMATION,
            .removeTime = state.gameTime + duration,
        } },
    });
}

fn setupVertices(object: *enemyObjectZig.EnemyObject, state: *main.GameState) void {
    const fire = object.typeData.fire;
    const animatePerCent: f32 = @mod(@as(f32, @floatFromInt(state.gameTime)) / 500, 1);
    paintVulkanZig.verticesForComplexSpriteAnimated(object.position, fire.imageIndex, animatePerCent, 2, state);
}

fn tick(object: *enemyObjectZig.EnemyObject, passedTime: i64, state: *main.GameState) !void {
    const fire = &object.typeData.fire;
    if (fire.flyToPosition) |flyToPosition| {
        const direction = main.calculateDirection(object.position, flyToPosition);
        const moveDistance: f32 = @as(f32, @floatFromInt(passedTime)) * 0.1;
        object.position = main.moveByDirectionAndDistance(object.position, direction, moveDistance);
        const distance = main.calculateDistance(flyToPosition, object.position);
        if (distance < moveDistance * 2) {
            object.position = flyToPosition;
            fire.flyToPosition = null;
        }
    } else {
        try enemyZig.checkStationaryPlayerHit(object.position, state);
    }
}

fn shouldBeRemoved(object: *enemyObjectZig.EnemyObject, state: *main.GameState) bool {
    const fire = object.typeData.fire;
    if (fire.removeTime == null) return false;
    return fire.removeTime.? <= state.gameTime;
}
