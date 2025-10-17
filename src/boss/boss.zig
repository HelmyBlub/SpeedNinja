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
const bossDragonZig = @import("bossDragon.zig");
const playerZig = @import("../player.zig");

pub const LevelBossData = struct {
    appearsOnLevel: usize,
    startLevel: *const fn (state: *main.GameState) anyerror!void,
    tickBoss: ?*const fn (boss: *Boss, passedTime: i64, state: *main.GameState) anyerror!void = null,
    isBossHit: ?*const fn (boss: *Boss, player: *playerZig.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) anyerror!bool = null,
    setupVerticesGround: *const fn (boss: *Boss, state: *main.GameState) anyerror!void,
    setupVertices: *const fn (boss: *Boss, state: *main.GameState) void,
    onPlayerMoved: ?*const fn (boss: *Boss, player: *playerZig.Player, state: *main.GameState) anyerror!void = null,
    onPlayerMoveEachTile: ?*const fn (boss: *Boss, player: *playerZig.Player, state: *main.GameState) anyerror!void = null,
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
    dragon,
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
    dragon: bossDragonZig.BossDragonData,
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
    .dragon = bossDragonZig.createBoss(),
});

pub const Boss = struct {
    imageIndex: u8,
    position: main.Position,
    maxHp: u32,
    hp: u32,
    name: []const u8,
    typeData: BossTypeData,
};

pub fn onPlayerMoved(player: *playerZig.Player, state: *main.GameState) !void {
    for (state.bosses.items) |*boss| {
        const levelBossData = LEVEL_BOSS_DATA.get(boss.typeData);
        if (levelBossData.onPlayerMoved) |opm| try opm(boss, player, state);
    }
}

pub fn onPlayerMoveEachTile(player: *playerZig.Player, state: *main.GameState) !void {
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
    const levelMod = @mod(@as(i32, @intCast(level - 1)), main.LEVEL_COUNT) + 1;
    for (LEVEL_BOSS_DATA.values) |bossData| {
        if (bossData.appearsOnLevel == levelMod) return true;
    }
    return false;
}

pub fn startBossLevel(state: *main.GameState) !void {
    const levelMod = @mod(@as(i32, @intCast(state.level - 1)), main.LEVEL_COUNT) + 1;
    for (LEVEL_BOSS_DATA.values) |bossData| {
        if (bossData.appearsOnLevel == levelMod) {
            try bossData.startLevel(state);
            state.gamePhase = .boss;
        }
    }
}

pub fn getHpScalingForLevel(hp: u32, state: *main.GameState) u32 {
    const newGamePlusFactor: u32 = state.newGamePlus + 1;
    return hp * (1 + @divFloor(state.level, 5)) * newGamePlusFactor;
}

pub fn isBossHit(hitArea: main.TileRectangle, player: *playerZig.Player, hitDirection: u8, state: *main.GameState) !bool {
    var aBossHit = false;
    var bossIndex: usize = 0;
    while (bossIndex < state.bosses.items.len) {
        const boss = &state.bosses.items[bossIndex];
        const levelBossData = LEVEL_BOSS_DATA.get(boss.typeData);
        if (levelBossData.isBossHit) |isHitFunction| {
            if (try isHitFunction(boss, player, hitArea, player.paintData.weaponRotation, hitDirection, state)) aBossHit = true;
        } else {
            if (isBossHitDefault(boss, playerZig.getPlayerDamage(player), hitArea)) aBossHit = true;
        }
        if (boss.hp == 0) {
            const cutAngle = player.paintData.weaponRotation + std.math.pi / 2.0;
            try removeBoss(bossIndex, cutAngle, state);
        } else {
            bossIndex += 1;
        }
    }
    return aBossHit;
}

fn removeBoss(bossIndex: usize, cutAngle: f32, state: *main.GameState) !void {
    var deadBoss = state.bosses.swapRemove(bossIndex);
    const levelBossData = LEVEL_BOSS_DATA.get(deadBoss.typeData);
    try state.spriteCutAnimations.append(
        .{
            .deathTime = state.gameTime,
            .position = deadBoss.position,
            .cutAngle = cutAngle,
            .force = state.seededRandom.random().float(f32) + 0.2,
            .colorOrImageIndex = .{ .imageIndex = deadBoss.imageIndex },
        },
    );
    if (levelBossData.deinit) |deinit| deinit(&deadBoss, state.allocator);
}

fn isBossHitDefault(boss: *Boss, damage: u32, hitArea: main.TileRectangle) bool {
    const bossTile = main.gamePositionToTilePosition(boss.position);
    if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
        boss.hp -|= damage;
        return true;
    }
    return false;
}

pub fn tickBosses(state: *main.GameState, passedTime: i64) !void {
    var bossIndex: usize = 0;
    while (bossIndex < state.bosses.items.len) {
        const boss = &state.bosses.items[bossIndex];
        if (LEVEL_BOSS_DATA.get(boss.typeData).tickBoss) |fTickBoss| try fTickBoss(boss, passedTime, state);
        if (boss.hp == 0) {
            try removeBoss(bossIndex, 1, state);
        } else {
            bossIndex += 1;
        }
    }
}
