const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const movePieceZig = @import("../movePiece.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const enemyZig = @import("enemy.zig");

pub const EnemyProjectile = struct {
    imageIndex: u8,
    position: main.Position,
    direction: u8,
    moveInterval: i32,
    nextMoveTime: i64,
};

pub fn spawnProjectile(position: main.Position, direction: u8, imageIndex: u8, moveInterval: i32, state: *main.GameState) !void {
    try state.enemyProjectiles.append(.{
        .direction = direction,
        .imageIndex = imageIndex,
        .moveInterval = moveInterval,
        .nextMoveTime = moveInterval + state.gameTime,
        .position = position,
    });
}

pub fn setupVertices(state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;
    const rotation: f32 = @mod(@as(f32, @floatFromInt(state.gameTime)) / 150, std.math.pi * 2);
    for (state.enemyProjectiles.items) |projectile| {
        paintVulkanZig.verticesForComplexSpriteWithRotate(
            projectile.position,
            projectile.imageIndex,
            rotation,
            &verticeData.spritesComplex,
            state,
        );
    }
}

pub fn tickProjectiles(state: *main.GameState) !void {
    var currentIndex: usize = 0;
    const despawnRange: f32 = @as(f32, @floatFromInt(state.mapTileRadius + 4)) * main.TILESIZE;
    while (currentIndex < state.enemyProjectiles.items.len) {
        const projectile = &state.enemyProjectiles.items[currentIndex];
        if (projectile.nextMoveTime <= state.gameTime) {
            projectile.nextMoveTime = state.gameTime + projectile.moveInterval;
            const stepDirection = movePieceZig.getStepDirection(projectile.direction);
            projectile.position = .{
                .x = projectile.position.x + stepDirection.x * main.TILESIZE,
                .y = projectile.position.y + stepDirection.y * main.TILESIZE,
            };
        }
        try enemyZig.checkPlayerHit(projectile.position, state);
        if (projectile.position.x < -despawnRange or projectile.position.x > despawnRange or
            projectile.position.y < -despawnRange or projectile.position.y > despawnRange)
        {
            _ = state.enemyProjectiles.swapRemove(currentIndex);
        } else {
            currentIndex += 1;
        }
    }
}

pub fn isHitByProjectile(position: main.Position, state: *main.GameState) bool {
    for (state.enemyProjectiles.items) |*projectile| {
        if (projectile.position.x > position.x - main.TILESIZE / 2 and projectile.position.x < position.x + main.TILESIZE / 2 and
            projectile.position.y > position.y - main.TILESIZE / 2 and projectile.position.y < position.y + main.TILESIZE / 2)
        {
            return true;
        }
    }
    return false;
}
