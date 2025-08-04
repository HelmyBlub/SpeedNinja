const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");

const RotateState = enum {
    spawnPillars,
    immune,
    rebuildPillars,
};

pub const BossRotateData = struct {
    nextStateTime: i64 = 0,
    immune: bool = true,
    state: RotateState = .spawnPillars,
    rebuildTime: i64 = 10_000,
    attackInterval: i64 = 3_000,
    attackTime: ?i64 = null,
    attackAngle: f32 = 0,
    attackTiles: std.ArrayList(main.TilePosition),
};

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .name = "Rotate",
        .appearsOnLevel = 10,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
        .deinit = deinit,
    };
}

fn deinit(boss: *bossZig.Boss) void {
    const rotateData = &boss.typeData.rotate;
    rotateData.attackTiles.deinit();
}

fn startBoss(state: *main.GameState) !void {
    try state.bosses.append(.{
        .hp = 20,
        .maxHp = 20,
        .imageIndex = imageZig.IMAGE_EVIL_TOWER,
        .position = .{ .x = 0, .y = 0 },
        .name = bossZig.LEVEL_BOSS_DATA[1].name,
        .dataIndex = 1,
        .typeData = .{ .rotate = .{
            .attackTiles = std.ArrayList(main.TilePosition).init(state.allocator),
        } },
    });
    state.mapTileRadius = 6;
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const rotateData = &boss.typeData.rotate;
    if (rotateData.attackTime == null) {
        rotateData.attackTime = state.gameTime + rotateData.attackInterval;
        try rotateData.attackTiles.append(.{ .x = 1, .y = 1 });
        try rotateData.attackTiles.append(.{ .x = 2, .y = 2 });
    } else if (state.gameTime >= rotateData.attackTime.?) {
        rotateData.attackTime = null;
        for (state.players.items) |*player| {
            const playerTile = main.gamePositionToTilePosition(player.position);
            for (rotateData.attackTiles.items) |tile| {
                if (playerTile.x == tile.x and playerTile.y == tile.y) {
                    player.hp -|= 1;
                    break;
                }
            }
        }
        rotateData.attackTiles.clearRetainingCapacity();
    }
    switch (rotateData.state) {
        .spawnPillars => {
            rotateData.immune = true;
            rotateData.state = .immune;
            const spawnDistance = main.TILESIZE * 3;
            try state.enemies.append(.{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_EVIL_TREE, .position = .{
                .x = -spawnDistance,
                .y = -spawnDistance,
            } });
            try state.enemies.append(.{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_EVIL_TREE, .position = .{
                .x = spawnDistance,
                .y = -spawnDistance,
            } });
            try state.enemies.append(.{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_EVIL_TREE, .position = .{
                .x = spawnDistance,
                .y = spawnDistance,
            } });
            try state.enemies.append(.{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_EVIL_TREE, .position = .{
                .x = -spawnDistance,
                .y = spawnDistance,
            } });
        },
        .immune => {
            if (state.enemies.items.len == 0) {
                rotateData.immune = false;
                rotateData.state = .rebuildPillars;
                rotateData.nextStateTime = state.gameTime + rotateData.rebuildTime;
            }
        },
        .rebuildPillars => {
            if (state.gameTime >= rotateData.nextStateTime) {
                rotateData.state = .spawnPillars;
            }
        },
    }
}

fn isBossHit(boss: *bossZig.Boss, hitArea: main.TileRectangle, state: *main.GameState) bool {
    _ = state;
    const rotate = &boss.typeData.rotate;
    if (!rotate.immune) {
        const bossTile = main.gamePositionToTilePosition(boss.position);
        if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
            boss.hp -|= 1;
            return true;
        }
    }
    return false;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) void {
    const rotate = boss.typeData.rotate;
    if (rotate.attackTime) |attackTime| {
        const fillPerCent: f32 = @min(1, @max(0, @as(f32, @floatFromInt(rotate.attackInterval + state.gameTime - attackTime)) / @as(f32, @floatFromInt(rotate.attackInterval))));
        for (rotate.attackTiles.items) |tile| {
            enemyVulkanZig.addWarningTileSprites(.{
                .x = @as(f32, @floatFromInt(tile.x)) * main.TILESIZE,
                .y = @as(f32, @floatFromInt(tile.y)) * main.TILESIZE,
            }, fillPerCent, state);
        }
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const bossPosition = boss.position;
    if (bossPosition.y != boss.position.y) {
        paintVulkanZig.verticesForComplexSpriteScale(.{
            .x = boss.position.x,
            .y = boss.position.y + 5,
        }, imageZig.IMAGE_SHADOW, &state.vkState.verticeData.spritesComplex, 0.75, state);
    }
    paintVulkanZig.verticesForComplexSpriteDefault(bossPosition, boss.imageIndex, &state.vkState.verticeData.spritesComplex, state);
}
