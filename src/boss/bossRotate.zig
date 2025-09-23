const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");
const ninjaDogVulkanZig = @import("../vulkan/ninjaDogVulkan.zig");
const soundMixerZig = @import("../soundMixer.zig");
const mapTileZig = @import("../mapTile.zig");

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
    visualizeAttackUntil: ?i64 = null,
    attackAngle: f32 = 0,
    attackTiles: std.ArrayList(main.TilePosition),
};

const BOSS_NAME = "Rotate";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 10,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
        .deinit = deinit,
    };
}

fn deinit(boss: *bossZig.Boss, allocator: std.mem.Allocator) void {
    _ = allocator;
    const rotateData = &boss.typeData.rotate;
    rotateData.attackTiles.deinit();
}

fn startBoss(state: *main.GameState) !void {
    const levelScaledHp = bossZig.getHpScalingForLevel(10, state);
    const scaledHp: u32 = levelScaledHp * @as(u32, @intCast(state.players.items.len));
    var boss: bossZig.Boss = .{
        .hp = scaledHp,
        .maxHp = scaledHp,
        .imageIndex = imageZig.IMAGE_BOSS_ROTATE,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .typeData = .{ .rotate = .{
            .attackTiles = std.ArrayList(main.TilePosition).init(state.allocator),
        } },
    };
    if (state.newGamePlus > 0) {
        boss.typeData.rotate.rebuildTime = @divFloor(boss.typeData.rotate.rebuildTime, @as(i32, @intCast(state.newGamePlus + 1)));
        boss.typeData.rotate.attackInterval = @divFloor(boss.typeData.rotate.attackInterval, @as(i32, @intCast(state.newGamePlus + 1)));
    }
    try state.bosses.append(boss);
    try mapTileZig.setMapRadius(6, state);
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const rotateData = &boss.typeData.rotate;
    if (rotateData.attackTime == null) {
        if (rotateData.visualizeAttackUntil == null or rotateData.visualizeAttackUntil.? <= state.gameTime) {
            rotateData.attackTime = state.gameTime + rotateData.attackInterval;
            try spawnAttackTiles(boss);
        }
    } else if (state.gameTime >= rotateData.attackTime.?) {
        try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_PEW_INDICIES[0..], 0, 1);
        rotateData.attackTime = null;
        rotateData.visualizeAttackUntil = state.gameTime + 250;
        for (state.players.items) |*player| {
            const playerTile = main.gamePositionToTilePosition(player.position);
            for (rotateData.attackTiles.items) |tile| {
                if (playerTile.x == tile.x and playerTile.y == tile.y) {
                    try main.playerHit(player, state);
                    break;
                }
            }
        }
        rotateData.attackTiles.clearRetainingCapacity();
    }
    switch (rotateData.state) {
        .spawnPillars => {
            if (!rotateData.immune) try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_IMMUNITY_UP, 0, 1);
            rotateData.immune = true;
            rotateData.state = .immune;
            const spawnDistance = main.TILESIZE * 3;
            try state.enemyData.enemies.append(.{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_BOSS_ROTATE_PILLAR, .position = .{
                .x = -spawnDistance,
                .y = -spawnDistance,
            } });
            try state.enemyData.enemies.append(.{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_BOSS_ROTATE_PILLAR, .position = .{
                .x = spawnDistance,
                .y = -spawnDistance,
            } });
            try state.enemyData.enemies.append(.{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_BOSS_ROTATE_PILLAR, .position = .{
                .x = spawnDistance,
                .y = spawnDistance,
            } });
            try state.enemyData.enemies.append(.{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_BOSS_ROTATE_PILLAR, .position = .{
                .x = -spawnDistance,
                .y = spawnDistance,
            } });
        },
        .immune => {
            if (state.enemyData.enemies.items.len == 0) {
                rotateData.immune = false;
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_IMMUNITY_DOWN, 0, 1);
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

fn spawnAttackTiles(boss: *bossZig.Boss) !void {
    const rotateData = &boss.typeData.rotate;
    rotateData.attackAngle = @mod(rotateData.attackAngle + 0.3, std.math.pi * 2.0);
    const moveX = @cos(rotateData.attackAngle);
    const moveY = @sin(rotateData.attackAngle);
    var offset: main.Position = .{ .x = 0, .y = 0 };
    for (0..8) |_| {
        offset.x += moveX * main.TILESIZE;
        offset.y += moveY * main.TILESIZE;
        const tilePos = main.gamePositionToTilePosition(.{
            .x = offset.x + boss.position.x,
            .y = offset.y + boss.position.y,
        });
        try rotateData.attackTiles.append(tilePos);
        const tilePos2 = main.gamePositionToTilePosition(.{
            .x = -offset.x + boss.position.x,
            .y = -offset.y + boss.position.y,
        });
        try rotateData.attackTiles.append(tilePos2);
    }
}

fn isBossHit(boss: *bossZig.Boss, player: *main.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    _ = hitDirection;
    _ = state;
    _ = cutRotation;
    const rotate = &boss.typeData.rotate;
    if (!rotate.immune) {
        const bossTile = main.gamePositionToTilePosition(boss.position);
        if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
            boss.hp -|= main.getPlayerDamage(player);
            return true;
        }
    }
    return false;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) !void {
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

    const lines = &state.vkState.verticeData.lines;
    const color: [3]f32 = .{ 0.0, 0.0, 0.0 };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const fromVulkan: main.Position = .{
        .x = boss.position.x * state.camera.zoom * onePixelXInVulkan,
        .y = boss.position.y * state.camera.zoom * onePixelYInVulkan,
    };
    for (state.enemyData.enemies.items) |enemy| {
        if (lines.verticeCount + 2 >= lines.vertices.len) break;
        const toVulkan: main.Position = .{
            .x = enemy.position.x * state.camera.zoom * onePixelXInVulkan,
            .y = enemy.position.y * state.camera.zoom * onePixelYInVulkan,
        };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ fromVulkan.x, fromVulkan.y }, .color = color };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ toVulkan.x, toVulkan.y }, .color = color };
        lines.verticeCount += 2;
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const bossPosition = boss.position;
    const rotate = boss.typeData.rotate;

    var alpha: f32 = 1;
    if (rotate.state == .rebuildPillars) {
        const timePerCent = @min(1, @max(0, 1 - @as(f32, @floatFromInt(rotate.nextStateTime - state.gameTime)) / @as(f32, @floatFromInt(rotate.rebuildTime))));
        alpha = timePerCent;
    }
    paintVulkanZig.verticesForComplexSpriteWithRotate(bossPosition, boss.imageIndex, rotate.attackAngle, 1, state);
    if (alpha > 0) {
        paintVulkanZig.verticesForComplexSpriteWithCut(
            boss.position,
            imageZig.IMAGE_CIRCLE,
            0,
            alpha,
            @max(alpha, 0.5),
            0,
            1,
            1,
            state,
        );
    }

    if (rotate.visualizeAttackUntil != null and rotate.visualizeAttackUntil.? >= state.gameTime) {
        const imageData = imageZig.IMAGE_DATA[imageZig.IMAGE_LASER];
        const moveX = @cos(rotate.attackAngle);
        const moveY = @sin(rotate.attackAngle);
        const scale: f32 = @as(f32, @floatFromInt(main.TILESIZE * imageZig.IMAGE_TO_GAME_SIZE)) / @as(f32, @floatFromInt(imageData.width)) * 1.03;
        var offset: main.Position = .{ .x = 0, .y = 0 };
        for (0..8) |_| {
            offset.x += moveX * main.TILESIZE;
            offset.y += moveY * main.TILESIZE;
            var laserPosition: main.Position = .{
                .x = boss.position.x + offset.x,
                .y = boss.position.y + offset.y,
            };
            ninjaDogVulkanZig.addTiranglesForSprite(
                laserPosition,
                imageZig.getImageCenter(imageZig.IMAGE_LASER),
                imageZig.IMAGE_LASER,
                rotate.attackAngle,
                null,
                .{ .x = scale, .y = scale },
                state,
            );
            laserPosition = .{
                .x = boss.position.x - offset.x,
                .y = boss.position.y - offset.y,
            };
            ninjaDogVulkanZig.addTiranglesForSprite(
                laserPosition,
                imageZig.getImageCenter(imageZig.IMAGE_LASER),
                imageZig.IMAGE_LASER,
                rotate.attackAngle,
                null,
                .{ .x = scale, .y = scale },
                state,
            );
        }
    }
}
