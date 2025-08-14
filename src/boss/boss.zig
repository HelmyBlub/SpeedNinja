const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const movePieceZig = @import("../movePiece.zig");
const soundMixerZig = @import("../soundMixer.zig");
const bossStompZig = @import("bossStomp.zig");
const bossRotateZig = @import("bossRotate.zig");
const bossRollZig = @import("bossRoll.zig");
const bossSplitZig = @import("bossSplit.zig");
const bossSnakeZig = @import("bossSnake.zig");
const bossTrippleZig = @import("bossTripple.zig");
const bossSnowballZig = @import("bossSnowball.zig");

pub const LevelBossData = struct {
    appearsOnLevel: usize,
    startLevel: *const fn (state: *main.GameState, bossDataIndex: usize) anyerror!void,
    tickBoss: *const fn (boss: *Boss, passedTime: i64, state: *main.GameState) anyerror!void,
    isBossHit: *const fn (boss: *Boss, player: *main.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) anyerror!bool,
    setupVerticesGround: *const fn (boss: *Boss, state: *main.GameState) void,
    setupVertices: *const fn (boss: *Boss, state: *main.GameState) void,
    onPlayerMoved: ?*const fn (boss: *Boss, player: *main.Player, state: *main.GameState) anyerror!void = null,
    deinit: ?*const fn (boss: *Boss, allocator: std.mem.Allocator) void = null,
};

const BossTypes = enum {
    stomp,
    rotate,
    roll,
    split,
    snake,
    tripple,
    snowball,
};

const BossTypeData = union(BossTypes) {
    stomp: bossStompZig.BossStompData,
    rotate: bossRotateZig.BossRotateData,
    roll: bossRollZig.BossRollData,
    split: bossSplitZig.BossSplitData,
    snake: bossSnakeZig.BossSnakeData,
    tripple: bossTrippleZig.BossTrippleData,
    snowball: bossSnowballZig.BossSnowballData,
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
    bossRollZig.createBoss(),
    bossSplitZig.createBoss(),
    bossSnakeZig.createBoss(),
    bossTrippleZig.createBoss(),
    bossSnowballZig.createBoss(),
};

pub fn onPlayerMoved(player: *main.Player, state: *main.GameState) !void {
    for (state.bosses.items) |*boss| {
        const levelBossData = LEVEL_BOSS_DATA[boss.dataIndex];
        if (levelBossData.onPlayerMoved) |opm| try opm(boss, player, state);
    }
}

pub fn clearBosses(state: *main.GameState) void {
    for (state.bosses.items) |*boss| {
        const levelBossData = LEVEL_BOSS_DATA[boss.dataIndex];
        if (levelBossData.deinit) |deinit| deinit(boss, state.allocator);
    }
    state.bosses.clearRetainingCapacity();
}

pub fn isBossLevel(level: u32) bool {
    for (LEVEL_BOSS_DATA) |bossData| {
        if (bossData.appearsOnLevel == level) return true;
    }
    return false;
}

pub fn startBossLevel(state: *main.GameState) !void {
    for (LEVEL_BOSS_DATA, 0..) |bossData, index| {
        if (bossData.appearsOnLevel == state.level) {
            try bossData.startLevel(state, index);
            state.gamePhase = .boss;
        }
    }
}

pub fn isBossHit(hitArea: main.TileRectangle, player: *main.Player, hitDirection: u8, state: *main.GameState) !bool {
    var aBossHit = false;
    var bossIndex: usize = 0;
    while (bossIndex < state.bosses.items.len) {
        const boss = &state.bosses.items[bossIndex];
        const levelBossData = LEVEL_BOSS_DATA[boss.dataIndex];
        if (try levelBossData.isBossHit(boss, player, hitArea, player.paintData.bladeRotation, hitDirection, state)) aBossHit = true;
        if (boss.hp == 0) {
            var deadBoss = state.bosses.swapRemove(bossIndex);
            const cutAngle = player.paintData.bladeRotation + std.math.pi / 2.0;
            try state.spriteCutAnimations.append(
                .{
                    .deathTime = state.gameTime,
                    .position = deadBoss.position,
                    .cutAngle = cutAngle,
                    .force = std.crypto.random.float(f32) + 0.2,
                    .imageIndex = boss.imageIndex,
                },
            );
            if (levelBossData.deinit) |deinit| deinit(&deadBoss, state.allocator);
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
