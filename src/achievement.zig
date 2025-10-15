const std = @import("std");
const main = @import("main.zig");

pub const AchievementData = struct {
    steamName: []const u8,
    trackingActive: bool = false,
    achieved: bool = false,
};

pub const AchievementsEnum = enum {
    destroyFirstEnemy,
    destroyBoss1,
    destroyBoss2,
    destroyBoss3,
    destroyBoss4,
    destroyBoss5,
    destroyBoss6,
    destroyBoss7,
    destroyBoss8,
    destroyBoss9,
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
    .destroyFirstEnemy = .{ .steamName = "DestroyFirstEnemy" },
    .destroyBoss1 = .{ .steamName = "DestroyBoss1" },
    .destroyBoss2 = .{ .steamName = "DestroyBoss2" },
    .destroyBoss3 = .{ .steamName = "DestroyBoss3" },
    .destroyBoss4 = .{ .steamName = "DestroyBoss4" },
    .destroyBoss5 = .{ .steamName = "DestroyBoss5" },
    .destroyBoss6 = .{ .steamName = "DestroyBoss6" },
    .destroyBoss7 = .{ .steamName = "DestroyBoss7" },
    .destroyBoss8 = .{ .steamName = "DestroyBoss8" },
    .destroyBoss9 = .{ .steamName = "DestroyBoss9" },
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
    if (!state.achievements.get(.destroyFirstEnemy).achieved) state.achievements.getPtr(.destroyFirstEnemy).trackingActive = true;
    if (!state.achievements.get(.destroyBoss1).achieved) state.achievements.getPtr(.destroyBoss1).trackingActive = true;
    if (!state.achievements.get(.destroyBoss2).achieved) state.achievements.getPtr(.destroyBoss2).trackingActive = true;
    if (!state.achievements.get(.destroyBoss3).achieved) state.achievements.getPtr(.destroyBoss3).trackingActive = true;
    if (!state.achievements.get(.destroyBoss4).achieved) state.achievements.getPtr(.destroyBoss4).trackingActive = true;
    if (!state.achievements.get(.destroyBoss5).achieved) state.achievements.getPtr(.destroyBoss5).trackingActive = true;
    if (!state.achievements.get(.destroyBoss6).achieved) state.achievements.getPtr(.destroyBoss6).trackingActive = true;
    if (!state.achievements.get(.destroyBoss7).achieved) state.achievements.getPtr(.destroyBoss7).trackingActive = true;
    if (!state.achievements.get(.destroyBoss8).achieved) state.achievements.getPtr(.destroyBoss8).trackingActive = true;
    if (!state.achievements.get(.destroyBoss9).achieved) state.achievements.getPtr(.destroyBoss9).trackingActive = true;
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

pub fn awardAchievement(achievementEnum: AchievementsEnum, state: *main.GameState) void {
    const achievement = state.achievements.getPtr(achievementEnum);
    if (!achievement.achieved and achievement.trackingActive) {
        std.debug.print("gained achievement {}\n", .{achievementEnum});
        achievement.achieved = true;
    }
}

pub fn awardBossDestroyed(state: *main.GameState) void {
    switch (state.level) {
        5 => awardAchievement(.destroyBoss1, state),
        10 => awardAchievement(.destroyBoss2, state),
        15 => awardAchievement(.destroyBoss3, state),
        20 => awardAchievement(.destroyBoss4, state),
        25 => {
            awardAchievement(.destroyBoss5, state);
            if (state.newGamePlus == 1) awardAchievement(.beatBoss5OnNewGamePlus1, state);
            if (state.newGamePlus == 2) awardAchievement(.beatBoss5OnNewGamePlus2, state);
            awardAchievement(.beatBoss5WithoutSpendingMoney, state);
        },
        30 => awardAchievement(.destroyBoss6, state),
        35 => awardAchievement(.destroyBoss7, state),
        40 => awardAchievement(.destroyBoss8, state),
        45 => awardAchievement(.destroyBoss9, state),
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
}
