const std = @import("std");
const main = @import("main.zig");
const imageZig = @import("image.zig");
const movePieceZig = @import("movePiece.zig");

pub const LevelBossData = struct {
    name: []const u8,
    appearsOnLevel: usize,
    startLevel: *const fn (state: *main.GameState) anyerror!void,
};

const StompState = enum {
    searchTarget,
    moveToTarget,
    chargeStomp,
    wait,
};

pub const Boss = struct {
    imageIndex: u8,
    position: main.Position,
    inAir: bool = false,
    maxHp: u32,
    hp: u32,
    nextStateTime: i64 = 0,
    speed: f32 = 2,
    attackTilePosition: main.TilePosition = .{ .x = 0, .y = 0 },
    state: StompState = .searchTarget,
    attackChargeTime: i64 = 2000,
    idleAfterAttackTime: i64 = 3000,
    attackTileRadius: i8 = 1,
};

const LEVEL_BOSS_DATA = [_]LevelBossData{
    LevelBossData{
        .name = "Stomp",
        .appearsOnLevel = 2,
        .startLevel = startBossStomp,
    },
};

pub fn isBossLevel(level: u32) bool {
    for (LEVEL_BOSS_DATA) |bossData| {
        if (bossData.appearsOnLevel == level) return true;
    }
    return false;
}

pub fn startBossLevel(state: *main.GameState) !void {
    for (LEVEL_BOSS_DATA) |bossData| {
        if (bossData.appearsOnLevel == state.level) {
            try bossData.startLevel(state);
            state.gamePhase = .boss;
        }
    }
}

fn startBossStomp(state: *main.GameState) !void {
    try state.bosses.append(.{
        .hp = 10,
        .maxHp = 10,
        .imageIndex = imageZig.IMAGE_EVIL_TREE,
        .position = .{ .x = 0, .y = 0 },
    });
    state.mapTileRadius = 6;
    main.adjustZoom(state);
}

pub fn tickBosses(state: *main.GameState, passedTime: i64) void {
    for (state.bosses.items) |*boss| {
        tickBoss(boss, passedTime, state);
    }
}

pub fn isBossHit(hitArea: main.TileRectangle, playerBladeRotation: f32, state: *main.GameState) !bool {
    var aBossHit = false;
    var bossIndex: usize = 0;
    while (bossIndex < state.bosses.items.len) {
        const boss = &state.bosses.items[bossIndex];
        if (!boss.inAir) {
            const bossTile = main.gamePositionToTilePosition(boss.position);
            if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
                aBossHit = true;
                boss.hp -|= 1;
                if (boss.hp == 0) {
                    const deadBoss = state.bosses.swapRemove(bossIndex);
                    const cutAngle = playerBladeRotation + std.math.pi / 2.0;
                    try state.enemyDeath.append(
                        .{
                            .deathTime = state.gameTime,
                            .position = deadBoss.position,
                            .cutAngle = cutAngle,
                            .force = std.crypto.random.float(f32) + 0.2,
                        },
                    );
                    continue;
                }
            }
        }
        bossIndex += 1;
    }
    return aBossHit;
}

fn tickBoss(boss: *Boss, passedTime: i64, state: *main.GameState) void {
    switch (boss.state) {
        .searchTarget => {
            boss.inAir = true;
            const randomPlayerIndex: usize = @intFromFloat(std.crypto.random.float(f32) * @as(f32, @floatFromInt(state.players.items.len)));
            const playerTile = main.gamePositionToTilePosition(state.players.items[randomPlayerIndex].position);
            boss.attackTilePosition = playerTile;
            boss.state = .moveToTarget;
        },
        .moveToTarget => {
            const targetPosition = main.tilePositionToGamePosition(boss.attackTilePosition);
            const moveDiff: main.Position = .{
                .x = boss.position.x - targetPosition.x,
                .y = boss.position.y - targetPosition.y,
            };
            const distance = main.calculateDistance(boss.position, targetPosition);
            if (distance > boss.speed) {
                boss.position.x -= (moveDiff.x / distance * @as(f32, @floatFromInt(passedTime))) / 10;
                boss.position.y -= (moveDiff.y / distance * @as(f32, @floatFromInt(passedTime))) / 10;
            } else {
                boss.position = targetPosition;
                boss.nextStateTime = state.gameTime + boss.attackChargeTime;
                boss.state = .chargeStomp;
            }
        },
        .chargeStomp => {
            if (boss.nextStateTime <= state.gameTime) {
                boss.inAir = false;
                boss.nextStateTime = state.gameTime + boss.idleAfterAttackTime;
                boss.state = .wait;
                const damageTileRectangle: main.TileRectangle = .{
                    .pos = .{ .x = boss.attackTilePosition.x - boss.attackTileRadius, .y = boss.attackTilePosition.y - boss.attackTileRadius },
                    .height = boss.attackTileRadius * 2 + 1,
                    .width = boss.attackTileRadius * 2 + 1,
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
            if (boss.nextStateTime <= state.gameTime) {
                boss.state = .searchTarget;
            }
        },
    }
}
