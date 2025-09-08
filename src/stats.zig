const std = @import("std");
const main = @import("main.zig");

pub const Statistics = struct {
    active: bool = true,
    levelDataWithPlayerCount: std.ArrayList(LevelStatiscticsWithPlayerCount),
};

const LevelStatiscticsWithPlayerCount = struct {
    playerCount: u32,
    levelDatas: std.ArrayList(LevelStatistics),
};

const LevelStatistics = struct {
    reachedCounter: u32 = 0,
    fastestTime: ?i64 = null,
    fastestPace: ?i64 = null,
    highestRound: u32 = 0,
    tookDamageCounter: u32 = 0,
    currentShoppingTime: i64 = 0,
    currentTime: i64 = 0,
    currentRound: u32 = 0,
    currentPace: i64 = 0,
};

pub fn statsOnLevelFinished(state: *main.GameState) !void {
    if (!state.statistics.active) return;
    if (state.level == 0) return;
    const playerCount = state.players.items.len;
    var levelData: ?*LevelStatistics = null;
    for (state.statistics.levelDataWithPlayerCount.items) |*levelDataForPlayerCount| {
        if (playerCount == levelDataForPlayerCount.playerCount) {
            if (levelDataForPlayerCount.levelDatas.items.len >= state.level) {
                levelData = &levelDataForPlayerCount.levelDatas.items[state.level - 1];
            } else {
                try levelDataForPlayerCount.levelDatas.append(.{});
                levelData = &levelDataForPlayerCount.levelDatas.items[state.level - 1];
            }
        }
    }
    levelData.?.currentPace = state.gameTime;
    levelData.?.currentRound = state.round;
    // levelData.?.currentTime
}

pub fn createStatistics(allocator: std.mem.Allocator) Statistics {
    return Statistics{
        .active = true,
        .levelDataWithPlayerCount = std.ArrayList(LevelStatiscticsWithPlayerCount).init(allocator),
    };
}

pub fn destoryStatistics(state: *main.GameState) void {
    for (state.statistics.levelDataWithPlayerCount.items) |*forPlayerCount| {
        forPlayerCount.levelDatas.deinit();
    }
    state.statistics.levelDataWithPlayerCount.deinit();
}
