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
    damageDelayedUntil: ?i64 = null,
    damageDelayDuration: i32 = 500,
    inAirHeight: f32 = 0,
};

pub fn createEnemyObjectFunctions() enemyObjectZig.EnemyObjectFunctions {
    return enemyObjectZig.EnemyObjectFunctions{
        .setupVertices = setupVertices,
        .tick = tick,
        .shouldBeRemoved = shouldBeRemoved,
    };
}

pub fn spawnEternalFire(spawnPosition: main.Position, flyToPosition: ?main.Position, inAirHeight: ?f32, state: *main.GameState) !void {
    try state.enemyData.enemyObjects.append(.{
        .position = spawnPosition,
        .typeData = .{ .fire = .{
            .imageIndex = imageZig.IMAGE_FIRE_ANIMATION,
            .removeTime = null,
            .flyToPosition = flyToPosition,
            .inAirHeight = if (flyToPosition != null) inAirHeight.? else 0,
        } },
    });
}

pub fn spawnFire(position: main.Position, duration: i32, fallDown: bool, state: *main.GameState) !void {
    if (fallDown) {
        try state.enemyData.enemyObjects.append(.{
            .position = position,
            .typeData = .{ .fire = .{
                .imageIndex = imageZig.IMAGE_FIRE_ANIMATION,
                .removeTime = state.gameTime + duration,
                .flyToPosition = position,
                .inAirHeight = 100,
            } },
        });
    } else {
        try state.enemyData.enemyObjects.append(.{
            .position = position,
            .typeData = .{ .fire = .{
                .imageIndex = imageZig.IMAGE_FIRE_ANIMATION,
                .removeTime = state.gameTime + duration,
            } },
        });
    }
}

fn setupVertices(object: *enemyObjectZig.EnemyObject, state: *main.GameState) void {
    const fire = object.typeData.fire;
    const animatePerCent: f32 = @mod(@as(f32, @floatFromInt(state.gameTime)) / 500, 1);
    if (fire.inAirHeight > 10) {
        paintVulkanZig.verticesForComplexSpriteAlpha(.{
            .x = object.position.x,
            .y = object.position.y + 5,
        }, imageZig.IMAGE_SHADOW, 0.75, state);
    }
    paintVulkanZig.verticesForComplexSpriteAnimated(.{
        .x = object.position.x,
        .y = object.position.y - fire.inAirHeight,
    }, fire.imageIndex, animatePerCent, 2, state);
}

fn tick(object: *enemyObjectZig.EnemyObject, passedTime: i64, state: *main.GameState) !void {
    const fire = &object.typeData.fire;
    if (fire.flyToPosition) |flyToPosition| {
        const direction = main.calculateDirection(object.position, flyToPosition);
        const moveDistance3D: f32 = @as(f32, @floatFromInt(passedTime)) * 0.1;
        const distance3D = main.calculateDistance3D(flyToPosition.x, flyToPosition.y, 0, object.position.x, object.position.y, fire.inAirHeight);
        const distance2D = main.calculateDistance(flyToPosition, object.position);
        const moveDistance2D: f32 = distance2D / distance3D * moveDistance3D;
        object.position = main.moveByDirectionAndDistance(object.position, direction, moveDistance2D);
        fire.inAirHeight = fire.inAirHeight - (moveDistance3D - moveDistance2D);
        if (distance3D < moveDistance3D * 2) {
            object.position = flyToPosition;
            fire.inAirHeight = 0;
            fire.flyToPosition = null;
            fire.damageDelayedUntil = state.gameTime + fire.damageDelayDuration;
        }
    } else {
        if (fire.damageDelayedUntil != null) {
            if (fire.damageDelayedUntil.? <= state.gameTime) {
                fire.damageDelayedUntil = null;
            }
        } else {
            try enemyZig.checkStationaryPlayerHit(object.position, state);
        }
    }
}

fn shouldBeRemoved(object: *enemyObjectZig.EnemyObject, state: *main.GameState) bool {
    const fire = object.typeData.fire;
    if (fire.removeTime == null) {
        if (fire.flyToPosition != null) return false;
        const tilePos = main.gamePositionToTilePosition(object.position);
        return @abs(tilePos.x) > state.mapData.tileRadius or @abs(tilePos.y) > state.mapData.tileRadius;
    }
    return fire.removeTime.? <= state.gameTime;
}
