const std = @import("std");
const main = @import("main.zig");
const imageZig = @import("image.zig");
const movePieceZig = @import("movePiece.zig");

pub const LevelBossData = struct {
    name: []const u8,
    appearsOnLevel: usize,
    startLevel: *const fn (state: *main.GameState) anyerror!void,
};

pub const Boss = struct {
    imageIndex: u8,
    position: main.Position,
    inAir: bool = false,
    maxHp: u32,
    hp: u32,
    attackStartTime: ?i64 = null,
    attackTilePosition: ?main.TilePosition = null,
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
}

pub fn tickBosses(state: *main.GameState) void {
    for (state.bosses.items) |*boss| {
        tickBoss(boss);
    }
}

pub fn isBossHit(hitArea: main.TileRectangle, state: *main.GameState) bool {
    var aBossHit = false;
    for (state.bosses.items) |*boss| {
        if (boss.inAir) continue;
        const bossTile = main.gamePositionToTilePosition(boss.position);
        if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
            aBossHit = true;
        }
    }
    return aBossHit;
}

fn tickBoss(boss: *Boss) void {
    if (boss.attackStartTime == null) {
        //
    } else {
        //
    }
}
