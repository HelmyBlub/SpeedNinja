const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");

const StompState = enum {
    searchTarget,
    moveToTarget,
    chargeStomp,
    wait,
};

pub const BossStompData = struct {
    inAir: bool = false,
    nextStateTime: i64 = 0,
    attackTilePosition: main.TilePosition = .{ .x = 0, .y = 0 },
    speed: f32 = 2,
    state: StompState = .searchTarget,
    attackChargeTime: i64 = 2000,
    idleAfterAttackTime: i64 = 3000,
    attackTileRadius: i8 = 1,
};

const BOSS_NAME = "Stomp";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 5,
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
        .imageIndex = imageZig.IMAGE_EVIL_TOWER,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .dataIndex = bossDataIndex,
        .typeData = .{ .stomp = .{} },
    });
    state.mapTileRadius = 6;
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const stompData = &boss.typeData.stomp;
    switch (stompData.state) {
        .searchTarget => {
            stompData.inAir = true;
            const randomPlayerIndex: usize = @intFromFloat(std.crypto.random.float(f32) * @as(f32, @floatFromInt(state.players.items.len)));
            const playerTile = main.gamePositionToTilePosition(state.players.items[randomPlayerIndex].position);
            stompData.attackTilePosition = playerTile;
            if (stompData.attackTilePosition.x > state.mapTileRadius) {
                stompData.attackTilePosition.x = @intCast(state.mapTileRadius);
            } else if (stompData.attackTilePosition.x < -@as(i32, @intCast(state.mapTileRadius))) {
                stompData.attackTilePosition.x = -@as(i32, @intCast(state.mapTileRadius));
            }
            if (stompData.attackTilePosition.y > state.mapTileRadius) {
                stompData.attackTilePosition.y = @intCast(state.mapTileRadius);
            } else if (stompData.attackTilePosition.y < -@as(i32, @intCast(state.mapTileRadius))) {
                stompData.attackTilePosition.y = -@as(i32, @intCast(state.mapTileRadius));
            }
            stompData.state = .moveToTarget;
        },
        .moveToTarget => {
            const targetPosition = main.tilePositionToGamePosition(stompData.attackTilePosition);
            const moveDiff: main.Position = .{
                .x = boss.position.x - targetPosition.x,
                .y = boss.position.y - targetPosition.y,
            };
            const distance = main.calculateDistance(boss.position, targetPosition);
            if (distance > stompData.speed) {
                boss.position.x -= (moveDiff.x / distance * @as(f32, @floatFromInt(passedTime))) / 10;
                boss.position.y -= (moveDiff.y / distance * @as(f32, @floatFromInt(passedTime))) / 10;
            } else {
                boss.position = targetPosition;
                stompData.nextStateTime = state.gameTime + stompData.attackChargeTime;
                stompData.state = .chargeStomp;
            }
        },
        .chargeStomp => {
            if (stompData.nextStateTime <= state.gameTime) {
                stompData.inAir = false;
                stompData.nextStateTime = state.gameTime + stompData.idleAfterAttackTime;
                stompData.state = .wait;
                try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_STOMP_INDICIES[0..], 0);
                const damageTileRectangle: main.TileRectangle = .{
                    .pos = .{ .x = stompData.attackTilePosition.x - stompData.attackTileRadius, .y = stompData.attackTilePosition.y - stompData.attackTileRadius },
                    .height = stompData.attackTileRadius * 2 + 1,
                    .width = stompData.attackTileRadius * 2 + 1,
                };
                for (state.players.items) |*player| {
                    const playerTile = main.gamePositionToTilePosition(player.position);
                    if (main.isTilePositionInTileRectangle(playerTile, damageTileRectangle)) {
                        player.hp -|= 1;
                    }
                }
            }
        },
        .wait => {
            if (stompData.nextStateTime <= state.gameTime) {
                stompData.state = .searchTarget;
            }
        },
    }
}

fn isBossHit(boss: *bossZig.Boss, hitArea: main.TileRectangle, state: *main.GameState) bool {
    _ = state;
    const stompData = &boss.typeData.stomp;
    if (!stompData.inAir) {
        const bossTile = main.gamePositionToTilePosition(boss.position);
        if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
            boss.hp -|= 1;
            return true;
        }
    }
    return false;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) void {
    const stompData = boss.typeData.stomp;
    if (stompData.state == .chargeStomp) {
        const fillPerCent: f32 = @min(1, @max(0, @as(f32, @floatFromInt(stompData.attackChargeTime + state.gameTime - stompData.nextStateTime)) / @as(f32, @floatFromInt(stompData.attackChargeTime))));
        const size: usize = @intCast(stompData.attackTileRadius * 2 + 1);
        for (0..size) |i| {
            const offsetX: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(i)) - stompData.attackTileRadius)) * main.TILESIZE;
            for (0..size) |j| {
                const offsetY: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(j)) - stompData.attackTileRadius)) * main.TILESIZE;
                enemyVulkanZig.addWarningTileSprites(.{
                    .x = boss.position.x + offsetX,
                    .y = boss.position.y + offsetY,
                }, fillPerCent, state);
            }
        }
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    var bossPosition = boss.position;
    const stompData = boss.typeData.stomp;
    if (stompData.inAir) {
        bossPosition.y -= main.TILESIZE / 2;
    }
    if (stompData.state == .wait) {
        if (stompData.nextStateTime < state.gameTime + 750) {
            const perCent = @max(0, @as(f32, @floatFromInt(stompData.nextStateTime - state.gameTime)) / 750.0);
            bossPosition.y -= main.TILESIZE / 2 * (1 - perCent);
        }
    }
    if (bossPosition.y != boss.position.y) {
        paintVulkanZig.verticesForComplexSpriteScale(.{
            .x = boss.position.x,
            .y = boss.position.y + 5,
        }, imageZig.IMAGE_SHADOW, &state.vkState.verticeData.spritesComplex, 0.75, state);
    }
    paintVulkanZig.verticesForComplexSpriteDefault(bossPosition, boss.imageIndex, &state.vkState.verticeData.spritesComplex, state);
}
