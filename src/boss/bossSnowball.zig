const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const enemyZig = @import("../enemy/enemy.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");
const mapTileZig = @import("../mapTile.zig");

const SnowballState = enum {
    stationary,
    rolling,
    collecting,
};

pub const BossSnowballData = struct {
    nextStateTime: i64 = 0,
    state: SnowballState = .stationary,
    iceCount: u8 = 20,
    rollDirection: u8 = 0,
    nextRollTime: i64 = 0,
    rollInterval: i32 = 500,
};

const BOSS_NAME = "Snowball";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 35,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
    };
}

fn startBoss(state: *main.GameState, bossDataIndex: usize) !void {
    try state.bosses.append(.{
        .hp = 10,
        .maxHp = 10,
        .imageIndex = imageZig.IMAGE_BOSS_SNOWBALL,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .dataIndex = bossDataIndex,
        .typeData = .{ .snowball = .{} },
    });
    try mapTileZig.setMapRadius(6, state);
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &boss.typeData.snowball;
    if (data.state == .rolling) {
        if (data.nextRollTime <= state.gameTime) {
            const stepDirection = movePieceZig.getStepDirection(data.rollDirection);
            const hitPosition: main.Position = .{
                .x = boss.position.x + stepDirection.x * main.TILESIZE,
                .y = boss.position.y + stepDirection.y * main.TILESIZE,
            };
            try enemyZig.checkStationaryPlayerHit(hitPosition, state);
            boss.position = hitPosition;
            data.nextRollTime = state.gameTime + data.rollInterval;
            const tilePos = main.gamePositionToTilePosition(boss.position);
            const tileType = mapTileZig.getMapTilePositionType(tilePos, &state.mapData);
            if (tileType == .ice) {
                data.iceCount +|= 1;
                mapTileZig.setMapTilePositionType(tilePos, .normal, &state.mapData);
            } else if (tileType == .normal) {
                if (data.iceCount > 0) {
                    mapTileZig.setMapTilePositionType(tilePos, .ice, &state.mapData);
                    data.iceCount -|= 1;
                }
            }
            if (data.iceCount == 0 or !canRollInDirection(boss, data.rollDirection, state)) {
                data.state = .stationary;
            }
        }
    }
}

fn canRollInDirection(boss: *bossZig.Boss, direction: u8, state: *main.GameState) bool {
    const iMapTileRadius: i32 = @intCast(state.mapData.tileRadius);
    const initialTilePos = main.gamePositionToTilePosition(boss.position);
    const stepDirection = movePieceZig.getStepDirectionTile(direction);
    if (stepDirection.x > 0 and initialTilePos.x >= iMapTileRadius or stepDirection.x < 0 and initialTilePos.x <= -iMapTileRadius or
        stepDirection.y > 0 and initialTilePos.y >= iMapTileRadius or stepDirection.y < 0 and initialTilePos.y <= -iMapTileRadius)
    {
        return false;
    }
    return true;
}

fn isBossHit(boss: *bossZig.Boss, player: *main.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    _ = cutRotation;
    _ = player;
    const data = &boss.typeData.snowball;
    const bossTile = main.gamePositionToTilePosition(boss.position);
    if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
        if (!canRollInDirection(boss, hitDirection, state)) {
            data.state = .stationary;
        } else {
            data.rollDirection = hitDirection;
            data.nextRollTime = state.gameTime;
            data.state = .rolling;
        }
        if (data.iceCount == 0) {
            boss.hp -|= 1;
        }
        return true;
    }
    return false;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = &boss.typeData.snowball;
    if (data.state == .rolling) {
        const moveStep = movePieceZig.getStepDirection(data.rollDirection);
        const attackPosition: main.Position = .{
            .x = boss.position.x + moveStep.x * main.TILESIZE,
            .y = boss.position.y + moveStep.y * main.TILESIZE,
        };
        const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(data.nextRollTime - state.gameTime)) / @as(f32, @floatFromInt(data.rollInterval))));
        const rotation: f32 = @as(f32, @floatFromInt(data.rollDirection)) * std.math.pi / 2.0;
        enemyVulkanZig.addRedArrowTileSprites(attackPosition, fillPerCent, rotation, state);
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    paintVulkanZig.verticesForComplexSpriteDefault(boss.position, boss.imageIndex, &state.vkState.verticeData.spritesComplex, state);
}
