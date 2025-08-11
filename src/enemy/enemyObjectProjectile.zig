const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const movePieceZig = @import("../movePiece.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const enemyZig = @import("enemy.zig");
const enemyObjectZig = @import("enemyObject.zig");

pub const EnemyProjectile = struct {
    imageIndex: u8,
    direction: u8,
    moveInterval: i32,
    nextMoveTime: i64,
};

pub fn createEnemyObjectFunctions() enemyObjectZig.EnemyObjectFunctions {
    return enemyObjectZig.EnemyObjectFunctions{
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
        .tick = tick,
        .hitCheckMovingPlayer = hitCheckMovingPlayer,
        .shouldBeRemoved = shouldBeRemoved,
    };
}

pub fn spawnProjectile(position: main.Position, direction: u8, imageIndex: u8, moveInterval: i32, state: *main.GameState) !void {
    try state.enemyObjects.append(.{
        .position = position,
        .functionsIndex = 0,
        .typeData = .{ .projectile = .{
            .direction = direction,
            .imageIndex = imageIndex,
            .moveInterval = moveInterval,
            .nextMoveTime = moveInterval + state.gameTime,
        } },
    });
}

fn setupVerticesGround(object: *enemyObjectZig.EnemyObject, state: *main.GameState) void {
    const projectileData = object.typeData.projectile;
    const moveStep = movePieceZig.getStepDirection(projectileData.direction);
    const attackPosition: main.Position = .{
        .x = object.position.x + moveStep.x * main.TILESIZE,
        .y = object.position.y + moveStep.y * main.TILESIZE,
    };
    const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(projectileData.nextMoveTime - state.gameTime)) / @as(f32, @floatFromInt(projectileData.moveInterval))));
    const rotation: f32 = @as(f32, @floatFromInt(projectileData.direction)) * std.math.pi / 2.0;
    enemyVulkanZig.addRedArrowTileSprites(attackPosition, fillPerCent, rotation, state);
}

fn setupVertices(object: *enemyObjectZig.EnemyObject, state: *main.GameState) void {
    const projectileData = object.typeData.projectile;
    const rotation: f32 = @mod(@as(f32, @floatFromInt(state.gameTime)) / 150, std.math.pi * 2);
    paintVulkanZig.verticesForComplexSpriteWithRotate(
        object.position,
        projectileData.imageIndex,
        rotation,
        &state.vkState.verticeData.spritesComplex,
        state,
    );
}

fn tick(object: *enemyObjectZig.EnemyObject, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const projectileData = &object.typeData.projectile;
    if (projectileData.nextMoveTime <= state.gameTime) {
        projectileData.nextMoveTime = state.gameTime + projectileData.moveInterval;
        const stepDirection = movePieceZig.getStepDirection(projectileData.direction);
        object.position = .{
            .x = object.position.x + stepDirection.x * main.TILESIZE,
            .y = object.position.y + stepDirection.y * main.TILESIZE,
        };
    }
    try enemyZig.checkPlayerHit(object.position, state);
}

fn shouldBeRemoved(object: *enemyObjectZig.EnemyObject, state: *main.GameState) bool {
    const despawnRange: f32 = @as(f32, @floatFromInt(state.mapTileRadius + 4)) * main.TILESIZE;
    if (object.position.x < -despawnRange or object.position.x > despawnRange or
        object.position.y < -despawnRange or object.position.y > despawnRange)
    {
        return true;
    }
    return false;
}

fn hitCheckMovingPlayer(object: *enemyObjectZig.EnemyObject, player: *main.Player, state: *main.GameState) bool {
    _ = state;
    const position = player.position;
    return object.position.x > position.x - main.TILESIZE / 2 and object.position.x < position.x + main.TILESIZE / 2 and
        object.position.y > position.y - main.TILESIZE / 2 and object.position.y < position.y + main.TILESIZE / 2;
}
