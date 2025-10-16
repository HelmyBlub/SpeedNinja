const std = @import("std");
const main = @import("main.zig");
const steamZig = @import("steam.zig");

pub const AchievementData = struct {
    steamName: []const u8,
    trackingActive: bool = false,
    achieved: bool = false,
};

pub const AchievementsEnum = enum {
    beatFirstEnemy,
    beatBoss1,
    beatBoss2,
    beatBoss3,
    beatBoss4,
    beatBoss5,
    beatBoss6,
    beatBoss7,
    beatBoss8,
    beatBoss9,
    beatGame,
    beatGamePlus1,
    beatBoss5OnNewGamePlus1,
    beatGamePlus2,
    beatBoss5OnNewGamePlus2,
    beatGameUnder45min,
    beatBoss5WithoutSpendingMoney,
    beatGameWithStartingMovePieces,
    beatGameWithoutTakingDamage,
};

pub const ACHIEVEMENTS = std.EnumArray(AchievementsEnum, AchievementData).init(.{
    .beatFirstEnemy = .{ .steamName = "BeatFirstEnemy" },
    .beatBoss1 = .{ .steamName = "BeatBoss1" },
    .beatBoss2 = .{ .steamName = "BeatBoss2" },
    .beatBoss3 = .{ .steamName = "BeatBoss3" },
    .beatBoss4 = .{ .steamName = "BeatBoss4" },
    .beatBoss5 = .{ .steamName = "BeatBoss5" },
    .beatBoss6 = .{ .steamName = "BeatBoss6" },
    .beatBoss7 = .{ .steamName = "BeatBoss7" },
    .beatBoss8 = .{ .steamName = "BeatBoss8" },
    .beatBoss9 = .{ .steamName = "BeatBoss9" },
    .beatGame = .{ .steamName = "BeatGame" },
    .beatGamePlus1 = .{ .steamName = "BeatNewGamePlus1" },
    .beatBoss5OnNewGamePlus1 = .{ .steamName = "BeatBoss5OnNewGamePlus1" },
    .beatGamePlus2 = .{ .steamName = "BeatNewGamePlus2" },
    .beatBoss5OnNewGamePlus2 = .{ .steamName = "BeatBoss5OnNewGamePlus2" },
    .beatGameUnder45min = .{ .steamName = "BeatUnder45Min" },
    .beatBoss5WithoutSpendingMoney = .{ .steamName = "BeatBoss5WithoutSpendingAnyMoney" },
    .beatGameWithStartingMovePieces = .{ .steamName = "BeatGameWithStartingMovePieces" },
    .beatGameWithoutTakingDamage = .{ .steamName = "BeatGameWithoutTakingDamage" },
});

pub fn initAchievementsOnRestart(state: *main.GameState) void {
    if (!state.achievements.get(.beatFirstEnemy).achieved) state.achievements.getPtr(.beatFirstEnemy).trackingActive = true;
    if (!state.achievements.get(.beatBoss1).achieved) state.achievements.getPtr(.beatBoss1).trackingActive = true;
    if (!state.achievements.get(.beatBoss2).achieved) state.achievements.getPtr(.beatBoss2).trackingActive = true;
    if (!state.achievements.get(.beatBoss3).achieved) state.achievements.getPtr(.beatBoss3).trackingActive = true;
    if (!state.achievements.get(.beatBoss4).achieved) state.achievements.getPtr(.beatBoss4).trackingActive = true;
    if (!state.achievements.get(.beatBoss5).achieved) state.achievements.getPtr(.beatBoss5).trackingActive = true;
    if (!state.achievements.get(.beatBoss6).achieved) state.achievements.getPtr(.beatBoss6).trackingActive = true;
    if (!state.achievements.get(.beatBoss7).achieved) state.achievements.getPtr(.beatBoss7).trackingActive = true;
    if (!state.achievements.get(.beatBoss8).achieved) state.achievements.getPtr(.beatBoss8).trackingActive = true;
    if (!state.achievements.get(.beatBoss9).achieved) state.achievements.getPtr(.beatBoss9).trackingActive = true;
    if (!state.achievements.get(.beatGame).achieved) state.achievements.getPtr(.beatGame).trackingActive = true;

    if (state.newGamePlus == 1 and !state.achievements.get(.beatGamePlus1).achieved) state.achievements.getPtr(.beatGamePlus1).trackingActive = true;
    if (state.newGamePlus == 1 and !state.achievements.get(.beatBoss5OnNewGamePlus1).achieved) state.achievements.getPtr(.beatBoss5OnNewGamePlus1).trackingActive = true;
    if (state.newGamePlus == 2 and !state.achievements.get(.beatGamePlus2).achieved) state.achievements.getPtr(.beatGamePlus2).trackingActive = true;
    if (state.newGamePlus == 2 and !state.achievements.get(.beatBoss5OnNewGamePlus2).achieved) state.achievements.getPtr(.beatBoss5OnNewGamePlus2).trackingActive = true;
    if (!state.achievements.get(.beatGameUnder45min).achieved) state.achievements.getPtr(.beatGameUnder45min).trackingActive = true;
    if (!state.achievements.get(.beatBoss5WithoutSpendingMoney).achieved) state.achievements.getPtr(.beatBoss5WithoutSpendingMoney).trackingActive = true;
    if (!state.achievements.get(.beatGameWithStartingMovePieces).achieved) state.achievements.getPtr(.beatGameWithStartingMovePieces).trackingActive = true;
    if (!state.achievements.get(.beatGameWithoutTakingDamage).achieved) state.achievements.getPtr(.beatGameWithoutTakingDamage).trackingActive = true;
}

pub fn stopTrackingAchievmentForThisRun(state: *main.GameState) void {
    var iter = state.achievements.iterator();
    while (iter.next()) |*achieve| {
        achieve.value.trackingActive = false;
    }
}

pub fn awardAchievement(achievementEnum: AchievementsEnum, state: *main.GameState) void {
    const achievement = state.achievements.getPtr(achievementEnum);
    if (!achievement.achieved and achievement.trackingActive) {
        achievement.achieved = true;
        steamZig.setAchievement(achievementEnum, state);
    }
}

pub fn awardAchievementOnBossDefeated(state: *main.GameState) void {
    if (state.steam) |*steam| steam.preventStoreStats = true;
    switch (state.level) {
        5 => awardAchievement(.beatBoss1, state),
        10 => awardAchievement(.beatBoss2, state),
        15 => awardAchievement(.beatBoss3, state),
        20 => awardAchievement(.beatBoss4, state),
        25 => {
            awardAchievement(.beatBoss5, state);
            if (state.newGamePlus == 1) awardAchievement(.beatBoss5OnNewGamePlus1, state);
            if (state.newGamePlus == 2) awardAchievement(.beatBoss5OnNewGamePlus2, state);
            awardAchievement(.beatBoss5WithoutSpendingMoney, state);
        },
        30 => awardAchievement(.beatBoss6, state),
        35 => awardAchievement(.beatBoss7, state),
        40 => awardAchievement(.beatBoss8, state),
        45 => awardAchievement(.beatBoss9, state),
        50 => {
            awardAchievement(.beatGame, state);
            if (state.newGamePlus == 1) awardAchievement(.beatGamePlus1, state);
            if (state.newGamePlus == 2) awardAchievement(.beatGamePlus2, state);
            if (state.statistics.runFinishedTime - state.statistics.runFinishedTime < 45_000 * 60) awardAchievement(.beatGameUnder45min, state);
            awardAchievement(.beatGameWithoutTakingDamage, state);
            awardAchievement(.beatGameWithStartingMovePieces, state);
        },
        else => {},
    }
    if (state.steam) |*steam| steam.preventStoreStats = false;
    steamZig.storeAchievements(state);
}
