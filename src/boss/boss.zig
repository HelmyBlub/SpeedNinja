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
const bossWallerZig = @import("bossWaller.zig");
const bossFireRollZig = @import("bossFireRoll.zig");

pub const LevelBossData = struct {
    appearsOnLevel: usize,
    startLevel: *const fn (state: *main.GameState) anyerror!void,
    tickBoss: ?*const fn (boss: *Boss, passedTime: i64, state: *main.GameState) anyerror!void = null,
    isBossHit: ?*const fn (boss: *Boss, player: *main.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) anyerror!bool = null,
    setupVerticesGround: *const fn (boss: *Boss, state: *main.GameState) anyerror!void,
    setupVertices: *const fn (boss: *Boss, state: *main.GameState) void,
    onPlayerMoved: ?*const fn (boss: *Boss, player: *main.Player, state: *main.GameState) anyerror!void = null,
    onPlayerMoveEachTile: ?*const fn (boss: *Boss, player: *main.Player, state: *main.GameState) anyerror!void = null,
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
    waller,
    fireRoll,
};

const BossTypeData = union(BossTypes) {
    stomp: bossStompZig.BossStompData,
    rotate: bossRotateZig.BossRotateData,
    roll: bossRollZig.BossRollData,
    split: bossSplitZig.BossSplitData,
    snake: bossSnakeZig.BossSnakeData,
    tripple: bossTrippleZig.BossTrippleData,
    snowball: bossSnowballZig.BossSnowballData,
    waller: bossWallerZig.BossWallerData,
    fireRoll: bossFireRollZig.BossFireRollData,
};

pub const LEVEL_BOSS_DATA = std.EnumArray(BossTypes, LevelBossData).init(.{
    .stomp = bossStompZig.createBoss(),
    .rotate = bossRotateZig.createBoss(),
    .roll = bossRollZig.createBoss(),
    .split = bossSplitZig.createBoss(),
    .snake = bossSnakeZig.createBoss(),
    .tripple = bossTrippleZig.createBoss(),
    .snowball = bossSnowballZig.createBoss(),
    .waller = bossWallerZig.createBoss(),
    .fireRoll = bossFireRollZig.createBoss(),
});

pub const Boss = struct {
    imageIndex: u8,
    position: main.Position,
    maxHp: u32,
    hp: u32,
    name: []const u8,
    typeData: BossTypeData,
};

pub fn onPlayerMoved(player: *main.Player, state: *main.GameState) !void {
    for (state.bosses.items) |*boss| {
        const levelBossData = LEVEL_BOSS_DATA.get(boss.typeData);
        if (levelBossData.onPlayerMoved) |opm| try opm(boss, player, state);
    }
}

pub fn onPlayerMoveEachTile(player: *main.Player, state: *main.GameState) !void {
    for (state.bosses.items) |*boss| {
        const levelBossData = LEVEL_BOSS_DATA.get(boss.typeData);
        if (levelBossData.onPlayerMoveEachTile) |opm| try opm(boss, player, state);
    }
}

pub fn clearBosses(state: *main.GameState) void {
    for (state.bosses.items) |*boss| {
        const levelBossData = LEVEL_BOSS_DATA.get(boss.typeData);
        if (levelBossData.deinit) |deinit| deinit(boss, state.allocator);
    }
    state.bosses.clearRetainingCapacity();
}

pub fn isBossLevel(level: u32) bool {
    for (LEVEL_BOSS_DATA.values) |bossData| {
        if (bossData.appearsOnLevel == level) return true;
    }
    return false;
}

pub fn startBossLevel(state: *main.GameState) !void {
    for (LEVEL_BOSS_DATA.values) |bossData| {
        if (bossData.appearsOnLevel == state.level) {
            try bossData.startLevel(state);
            state.gamePhase = .boss;
        }
    }
}

pub fn isBossHit(hitArea: main.TileRectangle, player: *main.Player, hitDirection: u8, state: *main.GameState) !bool {
    var aBossHit = false;
    var bossIndex: usize = 0;
    while (bossIndex < state.bosses.items.len) {
        const boss = &state.bosses.items[bossIndex];
        const levelBossData = LEVEL_BOSS_DATA.get(boss.typeData);
        if (levelBossData.isBossHit) |isHitFunction| {
            if (try isHitFunction(boss, player, hitArea, player.paintData.bladeRotation, hitDirection, state)) aBossHit = true;
        } else {
            if (isBossHitDefault(boss, hitArea)) aBossHit = true;
        }
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

fn isBossHitDefault(boss: *Boss, hitArea: main.TileRectangle) bool {
    const bossTile = main.gamePositionToTilePosition(boss.position);
    if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
        boss.hp -|= 1;
        return true;
    }
    return false;
}

pub fn tickBosses(state: *main.GameState, passedTime: i64) !void {
    for (state.bosses.items) |*boss| {
        if (LEVEL_BOSS_DATA.get(boss.typeData).tickBoss) |fTickBoss| try fTickBoss(boss, passedTime, state);
    }
}
