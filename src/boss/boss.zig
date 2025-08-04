const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const movePieceZig = @import("../movePiece.zig");
const soundMixerZig = @import("../soundMixer.zig");
const bossStompZig = @import("bossStomp.zig");
const bossRotateZig = @import("bossRotate.zig");

pub const LevelBossData = struct {
    name: []const u8,
    appearsOnLevel: usize,
    startLevel: *const fn (state: *main.GameState) anyerror!void,
    tickBoss: *const fn (boss: *Boss, passedTime: i64, state: *main.GameState) anyerror!void,
    isBossHit: *const fn (boss: *Boss, hitArea: main.TileRectangle, state: *main.GameState) bool,
    setupVerticesGround: *const fn (boss: *Boss, state: *main.GameState) void,
    setupVertices: *const fn (boss: *Boss, state: *main.GameState) void,
};

const BossTypes = enum {
    stomp,
    rotate,
};

const BossTypeData = union(BossTypes) {
    stomp: bossStompZig.BossStompData,
    rotate: bossRotateZig.BossRotateData,
};

pub const Boss = struct {
    imageIndex: u8,
    dataIndex: usize,
    position: main.Position,
    maxHp: u32,
    hp: u32,
    name: []const u8,
    typeData: BossTypeData,
};

pub const LEVEL_BOSS_DATA = [_]LevelBossData{
    bossStompZig.createBoss(),
    bossRotateZig.createBoss(),
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

pub fn isBossHit(hitArea: main.TileRectangle, playerBladeRotation: f32, state: *main.GameState) !bool {
    var aBossHit = false;
    var bossIndex: usize = 0;
    while (bossIndex < state.bosses.items.len) {
        const boss = &state.bosses.items[bossIndex];
        if (LEVEL_BOSS_DATA[boss.dataIndex].isBossHit(boss, hitArea, state)) aBossHit = true;
        if (boss.hp == 0) {
            const deadBoss = state.bosses.swapRemove(bossIndex);
            const cutAngle = playerBladeRotation + std.math.pi / 2.0;
            try state.enemyDeath.append(
                .{
                    .deathTime = state.gameTime,
                    .position = deadBoss.position,
                    .cutAngle = cutAngle,
                    .force = std.crypto.random.float(f32) + 0.2,
                    .imageIndex = boss.imageIndex,
                },
            );
        } else {
            bossIndex += 1;
        }
    }
    return aBossHit;
}

pub fn tickBosses(state: *main.GameState, passedTime: i64) !void {
    for (state.bosses.items) |*boss| {
        try LEVEL_BOSS_DATA[boss.dataIndex].tickBoss(boss, passedTime, state);
    }
}
