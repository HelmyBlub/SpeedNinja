const std = @import("std");
const main = @import("main.zig");
const fontVulkanZig = @import("vulkan/fontVulkan.zig");
const windowSdlZig = @import("windowSdl.zig");
const fileSaveZig = @import("fileSave.zig");

pub const Statistics = struct {
    active: bool = true,
    runStartedTime: i64 = 0,
    totalShoppingTime: i64 = 0,
    levelDataWithPlayerCount: std.ArrayList(LevelStatiscticsWithPlayerCount),
};

const LevelStatiscticsWithPlayerCount = struct {
    playerCount: u32,
    levelDatas: std.ArrayList(LevelStatistics),
};

const LevelStatistics = struct {
    fastestTime: ?i64 = null,
    currentTime: i64 = 0,
    fastestTotalTime: ?i64 = null,
    currentTotalTime: i64 = 0,
    currentRound: u32 = 0,
    currentShoppingTime: i64 = 0,
};

const FILE_NAME_STATISTICS_DATA = "statistics.dat";
const SAFE_FILE_VERSION: u8 = 1;

pub fn statsOnLevelFinished(state: *main.GameState) !void {
    if (!state.statistics.active) return;
    if (state.level == 0) return;
    const levelDatas: []LevelStatistics = try getLevelDatas(state);
    const currentLevelData = &levelDatas[state.level - 1];
    const currentTime = std.time.milliTimestamp();
    currentLevelData.currentTotalTime = currentTime - state.statistics.runStartedTime;
    currentLevelData.currentRound = state.round;
    if (state.level == 1) {
        currentLevelData.currentTime = currentLevelData.currentTotalTime;
    } else {
        const lastLevelData = &levelDatas[state.level - 2];
        currentLevelData.currentTime = currentTime - lastLevelData.currentTotalTime - lastLevelData.currentShoppingTime;
    }
}

pub fn statsOnLevelShopFinishedAndNextLevelStart(state: *main.GameState) !void {
    if (!state.statistics.active) return;
    if (state.level == 0) return;
    const levelDatas: []LevelStatistics = try getLevelDatas(state);
    const currentLevelData = &levelDatas[state.level - 1];
    const currentTime = std.time.milliTimestamp();
    currentLevelData.currentShoppingTime = currentTime - currentLevelData.currentTotalTime;
    state.statistics.totalShoppingTime += currentLevelData.currentShoppingTime;
}

pub fn statsSaveOnRestart(state: *main.GameState) !void {
    state.statistics.runStartedTime = std.time.milliTimestamp();
    state.statistics.totalShoppingTime = 0;
    if (!state.statistics.active) {
        state.statistics.active = true;
        return;
    }
    if (state.level == 0) return;
    const levelDatas: []LevelStatistics = try getLevelDatas(state);
    var saveToFile = false;
    const isNewBestTotalTime = checkIfIsNewBestTotalTime(levelDatas, state);

    for (levelDatas, 0..) |*levelData, index| {
        const shopping: u8 = if (state.gamePhase == .shopping) 1 else 0;
        if (state.level - 1 + shopping <= index) break;
        if (levelData.fastestTime == null or levelData.currentTime < levelData.fastestTime.?) {
            levelData.fastestTime = levelData.currentTime;
            saveToFile = true;
        }
        if (isNewBestTotalTime) {
            levelData.fastestTotalTime = levelData.currentTotalTime;
            saveToFile = true;
        }
    }
    if (saveToFile) {
        try saveStatisticsDataToFile(state);
    }
    state.statistics.active = true;
}

fn checkIfIsNewBestTotalTime(levelDatas: []LevelStatistics, state: *main.GameState) bool {
    var isNewBestTotal: bool = false;
    if (state.gamePhase == .shopping) {
        var hasReachedHigherLevelBefore = false;
        if (levelDatas.len > state.level) {
            const nextLevelData = levelDatas[state.level];
            if (nextLevelData.fastestTotalTime != null) {
                hasReachedHigherLevelBefore = true;
            }
        }
        if (!hasReachedHigherLevelBefore) {
            const levelData = levelDatas[state.level - 1];
            if (levelData.fastestTotalTime == null or levelData.currentTotalTime < levelData.fastestTotalTime.?) {
                isNewBestTotal = true;
            }
        }
    } else {
        var hasReachedHigherLevelBefore = false;
        const currentLevelData = levelDatas[state.level - 1];
        if (currentLevelData.fastestTotalTime != null) {
            hasReachedHigherLevelBefore = true;
        }
        if (!hasReachedHigherLevelBefore) {
            const highestDefeatedLevelData = levelDatas[state.level - 2];
            if (highestDefeatedLevelData.fastestTotalTime == null or highestDefeatedLevelData.currentTotalTime < highestDefeatedLevelData.fastestTotalTime.?) {
                isNewBestTotal = true;
            }
        }
    }
    if (isNewBestTotal) {
        std.debug.print("new best score\n", .{});
    }
    return isNewBestTotal;
}

pub fn createStatistics(allocator: std.mem.Allocator) Statistics {
    return Statistics{
        .active = true,
        .levelDataWithPlayerCount = std.ArrayList(LevelStatiscticsWithPlayerCount).init(allocator),
    };
}

pub fn destroyAndSave(state: *main.GameState) !void {
    try statsSaveOnRestart(state);

    for (state.statistics.levelDataWithPlayerCount.items) |*forPlayerCount| {
        forPlayerCount.levelDatas.deinit();
    }
    state.statistics.levelDataWithPlayerCount.deinit();
}

pub fn setupVertices(state: *main.GameState) !void {
    if (!state.statistics.active) return;
    if (state.level <= 1) return;
    const textColor: [3]f32 = .{ 1, 1, 1 };
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const topLeft: main.Position = .{ .x = -0.99, .y = -0.5 };
    const levelDatas: []LevelStatistics = try getLevelDatas(state);
    const fontSize = 16;
    const firstDisplayLevel = if (state.level > 10) state.level - 10 else 1;
    const levelTextWidth = fontVulkanZig.paintText("Level  ", .{ .x = topLeft.x, .y = topLeft.y }, fontSize, textColor, &state.vkState.verticeData.font);
    const offsetX1 = topLeft.x + levelTextWidth;
    const timeTextWidth = fontVulkanZig.paintText("Time      ", .{ .x = offsetX1, .y = topLeft.y }, fontSize, textColor, &state.vkState.verticeData.font);
    const offsetX2 = offsetX1 + timeTextWidth;
    const diffTotalTextWidth = fontVulkanZig.paintText("DiffTotal  ", .{ .x = offsetX2, .y = topLeft.y }, fontSize, textColor, &state.vkState.verticeData.font);
    const offsetX3 = offsetX2 + diffTotalTextWidth;
    _ = fontVulkanZig.paintText("DiffLevel", .{ .x = offsetX3, .y = topLeft.y }, fontSize, textColor, &state.vkState.verticeData.font);
    const red: [3]f32 = .{ 0.7, 0, 0 };
    const green: [3]f32 = .{ 0.1, 1, 0.1 };
    const currentTime = std.time.milliTimestamp();
    for (firstDisplayLevel..state.level + 1) |level| {
        const levelData = levelDatas[level - 1];
        const offsetY = onePixelYInVulkan * @as(f32, @floatFromInt(fontSize * (level - firstDisplayLevel + 1)));
        _ = try fontVulkanZig.paintNumber(level, .{ .x = topLeft.x, .y = topLeft.y + offsetY }, fontSize, textColor, &state.vkState.verticeData.font);
        var currentTotalTime = levelData.currentTotalTime;
        if (currentTotalTime == 0) {
            currentTotalTime = state.gameTime;
        }
        _ = try fontVulkanZig.paintTime(currentTotalTime, .{ .x = offsetX1, .y = topLeft.y + offsetY }, fontSize, true, textColor, &state.vkState.verticeData.font);
        if (levelData.fastestTotalTime != null and levelData.fastestTime != null) {
            var levelCurrentTime = levelData.currentTime;
            if (levelCurrentTime == 0) {
                if (level > 1) {
                    const lastLevelData = &levelDatas[level - 2];
                    levelCurrentTime = currentTime - lastLevelData.currentTotalTime - lastLevelData.currentShoppingTime;
                } else {
                    levelCurrentTime = currentTime;
                }
            }
            const diffTotal = currentTotalTime - levelData.fastestTotalTime.?;
            var color: [3]f32 = if (diffTotal > 0) red else green;
            if (diffTotal > 0) {
                const plusWidth = fontVulkanZig.paintText("+", .{ .x = offsetX2, .y = topLeft.y + offsetY }, fontSize, color, &state.vkState.verticeData.font);
                _ = try fontVulkanZig.paintTime(diffTotal, .{ .x = offsetX2 + plusWidth, .y = topLeft.y + offsetY }, fontSize, true, color, &state.vkState.verticeData.font);
            } else {
                _ = try fontVulkanZig.paintTime(diffTotal, .{ .x = offsetX2, .y = topLeft.y + offsetY }, fontSize, true, color, &state.vkState.verticeData.font);
            }
            const diff = levelCurrentTime - levelData.fastestTime.?;
            color = if (diff > 0) red else green;
            if (diff > 0) {
                const plusWidth = fontVulkanZig.paintText("+", .{ .x = offsetX3, .y = topLeft.y + offsetY }, fontSize, color, &state.vkState.verticeData.font);
                _ = try fontVulkanZig.paintTime(diff, .{ .x = offsetX3 + plusWidth, .y = topLeft.y + offsetY }, fontSize, true, color, &state.vkState.verticeData.font);
            } else {
                _ = try fontVulkanZig.paintTime(diff, .{ .x = offsetX3, .y = topLeft.y + offsetY }, fontSize, true, color, &state.vkState.verticeData.font);
            }
        }
    }
}

fn getLevelDatas(state: *main.GameState) ![]LevelStatistics {
    var optLevelDatas: ?*std.ArrayList(LevelStatistics) = null;
    for (state.statistics.levelDataWithPlayerCount.items) |*levelDataForPlayerCount| {
        if (state.players.items.len == levelDataForPlayerCount.playerCount) {
            optLevelDatas = &levelDataForPlayerCount.levelDatas;
        }
    }
    if (optLevelDatas == null) {
        try state.statistics.levelDataWithPlayerCount.append(.{
            .levelDatas = std.ArrayList(LevelStatistics).init(state.allocator),
            .playerCount = @intCast(state.players.items.len),
        });
        optLevelDatas = &state.statistics.levelDataWithPlayerCount.items[state.statistics.levelDataWithPlayerCount.items.len - 1].levelDatas;
    }
    if (optLevelDatas.?.items.len < state.level) {
        try optLevelDatas.?.append(.{});
    }

    return optLevelDatas.?.items;
}

pub fn loadStatisticsDataFromFile(state: *main.GameState) void {
    const filepath = fileSaveZig.getSavePath(state.allocator, FILE_NAME_STATISTICS_DATA) catch return;
    defer state.allocator.free(filepath);

    loadFromFile(state, filepath) catch {
        //ignore for now
    };
}

fn loadFromFile(state: *main.GameState, filepath: []const u8) !void {
    const file = std.fs.cwd().openFile(filepath, .{}) catch return;
    defer file.close();

    const reader = file.reader();
    const safeFileVersion = try reader.readByte();
    _ = safeFileVersion;

    const statisticsForPlayerCountLength: usize = try reader.readInt(usize, .little);
    for (0..statisticsForPlayerCountLength) |_| {
        const playerCount = try reader.readInt(u32, .little);
        const levelDataLength: usize = try reader.readInt(usize, .little);
        try state.statistics.levelDataWithPlayerCount.append(.{
            .levelDatas = std.ArrayList(LevelStatistics).init(state.allocator),
            .playerCount = playerCount,
        });
        const levelDatas = &state.statistics.levelDataWithPlayerCount.items[state.statistics.levelDataWithPlayerCount.items.len - 1];
        for (0..levelDataLength) |levelDataIndex| {
            try levelDatas.levelDatas.append(.{});
            const levelData: *LevelStatistics = &levelDatas.levelDatas.items[levelDataIndex];
            levelData.fastestTime = try reader.readInt(i64, .little);
            if (levelData.fastestTime.? < 0) levelData.fastestTime = null;
            levelData.fastestTotalTime = try reader.readInt(i64, .little);
            if (levelData.fastestTotalTime.? < 0) levelData.fastestTotalTime = null;
        }
    }
}

fn saveStatisticsDataToFile(state: *main.GameState) !void {
    const filepath = try fileSaveZig.getSavePath(state.allocator, FILE_NAME_STATISTICS_DATA);
    defer state.allocator.free(filepath);

    const file = try std.fs.cwd().createFile(filepath, .{ .truncate = true });
    defer file.close();

    const writer = file.writer();
    _ = try writer.writeByte(SAFE_FILE_VERSION);
    _ = try writer.writeInt(usize, state.statistics.levelDataWithPlayerCount.items.len, .little);
    for (state.statistics.levelDataWithPlayerCount.items) |statisticsForPlayerCount| {
        _ = try writer.writeInt(u32, statisticsForPlayerCount.playerCount, .little);
        _ = try writer.writeInt(usize, statisticsForPlayerCount.levelDatas.items.len, .little);
        for (statisticsForPlayerCount.levelDatas.items) |levelStatistics| {
            _ = try writer.writeInt(i64, if (levelStatistics.fastestTime) |ft| ft else -1, .little);
            _ = try writer.writeInt(i64, if (levelStatistics.fastestTotalTime) |ftt| ftt else -1, .little);
        }
    }
}
