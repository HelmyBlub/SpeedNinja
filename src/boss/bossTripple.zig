const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");
const enemyObjectProjectileZig = @import("../enemy/enemyObjectProjectile.zig");

pub const BossTrippleData = struct {
    direction: u8,
    lastTurnTime: i64 = 0,
    minTurnInterval: i32 = 4000,
};

const BOSS_NAME = "Tripple";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 30,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
    };
}

fn startBoss(state: *main.GameState, bossDataIndex: usize) !void {
    const bossHp = 5;
    try state.bosses.append(.{
        .hp = bossHp,
        .maxHp = bossHp,
        .imageIndex = imageZig.IMAGE_BOSS_TRIPPLE,
        .position = .{ .x = -1 * main.TILESIZE, .y = -1 * main.TILESIZE },
        .name = "Trip",
        .dataIndex = bossDataIndex,
        .typeData = .{ .tripple = .{ .direction = 0 } },
    });
    try state.bosses.append(.{
        .hp = bossHp,
        .maxHp = bossHp,
        .imageIndex = imageZig.IMAGE_BOSS_TRIPPLE,
        .position = .{ .x = 3 * main.TILESIZE, .y = 0 },
        .name = "Ripp",
        .dataIndex = bossDataIndex,
        .typeData = .{ .tripple = .{ .direction = 0 } },
    });
    try state.bosses.append(.{
        .hp = bossHp,
        .maxHp = bossHp,
        .imageIndex = imageZig.IMAGE_BOSS_TRIPPLE,
        .position = .{ .x = 0, .y = 3 * main.TILESIZE },
        .name = "Ipple",
        .dataIndex = bossDataIndex,
        .typeData = .{ .tripple = .{ .direction = 0 } },
    });
    state.mapTileRadius = 6;
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const trippleData = &boss.typeData.tripple;
    if (trippleData.lastTurnTime + trippleData.minTurnInterval < state.gameTime) {
        const closestPlayer = main.findClosestPlayer(boss.position, state);
        if (closestPlayer.executeMovePiece == null) {
            const direction = main.getDirectionFromTo(boss.position, closestPlayer.position);
            if (direction != trippleData.direction) {
                trippleData.direction = direction;
                trippleData.lastTurnTime = state.gameTime;
            }
        }
    }
}

fn isBossHit(boss: *bossZig.Boss, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    const trippleData = &boss.typeData.tripple;
    _ = cutRotation;
    const bossTile = main.gamePositionToTilePosition(boss.position);
    if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
        if (@mod(hitDirection + 2, 4) == trippleData.direction) {
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_ENEMY_BLOCK_INDICIES[0..], 0, 1);
        } else {
            boss.hp -|= 1;
            return true;
        }
    }
    return false;
}

fn getRandomFlyToPosition(state: *main.GameState) main.Position {
    var randomPos: main.Position = .{ .x = 0, .y = 0 };
    var validPosition = false;
    searchPos: while (!validPosition) {
        const mapTileRadiusI32 = @as(i32, @intCast(state.mapTileRadius));
        randomPos.x = @floatFromInt(std.crypto.random.intRangeAtMost(i32, -mapTileRadiusI32, mapTileRadiusI32) * main.TILESIZE);
        randomPos.y = @floatFromInt(std.crypto.random.intRangeAtMost(i32, -mapTileRadiusI32, mapTileRadiusI32) * main.TILESIZE);
        for (state.bosses.items) |bossSingle| {
            if (main.calculateDistance(randomPos, bossSingle.position) < main.TILESIZE * 3) {
                continue :searchPos;
            }
        }
        validPosition = true;
    }
    return randomPos;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) void {
    const trippleData = boss.typeData.tripple;
    _ = state;
    _ = trippleData;
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const trippleData = boss.typeData.tripple;
    const rotation: f32 = @as(f32, @floatFromInt(trippleData.direction)) * std.math.pi / 2.0;
    paintVulkanZig.verticesForComplexSpriteWithRotate(
        boss.position,
        boss.imageIndex,
        rotation,
        &state.vkState.verticeData.spritesComplex,
        state,
    );
    const shieldCount = getShieldCount(state);
    const directionChange = [_]u8{ 0, 1, 3 };
    for (0..shieldCount) |i| {
        const shieldDirection: u8 = @mod(trippleData.direction + directionChange[i], 4);
        const shieldRotation: f32 = @as(f32, @floatFromInt(shieldDirection)) * std.math.pi / 2.0;
        const stepDirection = movePieceZig.getStepDirection(shieldDirection);
        paintVulkanZig.verticesForComplexSpriteWithRotate(
            .{ .x = boss.position.x + stepDirection.x * main.TILESIZE / 2, .y = boss.position.y + stepDirection.y * main.TILESIZE / 2 },
            imageZig.IMAGE_SHIELD,
            shieldRotation,
            &state.vkState.verticeData.spritesComplex,
            state,
        );
    }
}

fn getShieldCount(state: *main.GameState) usize {
    return @max(1, @min(3, 4 - state.bosses.items.len));
}
