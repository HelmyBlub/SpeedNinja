const std = @import("std");
const main = @import("main.zig");
const fontVulkanZig = @import("vulkan/fontVulkan.zig");
const windowSdlZig = @import("windowSdl.zig");
const fileSaveZig = @import("fileSave.zig");

pub const Statistics = struct {
    active: bool = true,
    runStartedTime: i64 = 0,
    runFinishedTime: i64 = 0,
    totalShoppingTime: i64 = 0,
    levelDataWithPlayerCount: std.ArrayList(LevelStatiscticsWithPlayerCount),
    uxData: StatisticsUxData = .{},
};

pub const StatisticsUxData = struct {
    display: bool = true,
    fontSize: f32 = 16,
    columnsData: []ColumnData = &COLUMNS_DATA,
    currentTimestamp: i64 = 0,
    displayNextLevelData: bool = true,
};

const ColumnData = struct {
    name: []const u8,
    display: bool,
    pixelWidth: f32,
    setupVertices: *const fn (level: u32, levelDatas: []LevelStatistics, paintPos: main.Position, state: *main.GameState) anyerror!void,
};

const LevelStatiscticsWithPlayerCount = struct {
    playerCount: u32,
    newGamePlus: u32,
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
const SAFE_FILE_VERSION: u8 = 0;

var COLUMNS_DATA = [_]ColumnData{
    .{ .name = "Level", .display = true, .pixelWidth = 100, .setupVertices = setupVerticesLevel },
    .{ .name = "Time", .display = true, .pixelWidth = 100, .setupVertices = setupVerticesTime },
    .{ .name = "+/-", .display = true, .pixelWidth = 100, .setupVertices = setupVerticesTotalDiff },
    .{ .name = "Gold", .display = true, .pixelWidth = 100, .setupVertices = setupVerticesLevelDiff },
};

pub fn statsOnLevelFinished(state: *main.GameState) !void {
    const currentTime = std.time.milliTimestamp();
    if (state.level == main.LEVEL_COUNT and state.gamePhase == .finished) state.statistics.runFinishedTime = currentTime - state.statistics.runStartedTime;
    if (!state.statistics.active) return;
    if (state.level == 0) return;
    const levelDatas: []LevelStatistics = try getLevelDatas(state);
    const currentLevelData = &levelDatas[state.level - 1];
    currentLevelData.currentTotalTime = currentTime - state.statistics.runStartedTime;
    currentLevelData.currentRound = state.round;
    if (state.level == 1) {
        currentLevelData.currentTime = currentLevelData.currentTotalTime;
    } else {
        const lastLevelData = &levelDatas[state.level - 2];
        currentLevelData.currentTime = currentLevelData.currentTotalTime - lastLevelData.currentTotalTime - lastLevelData.currentShoppingTime;
    }
}

pub fn statsOnLevelShopFinishedAndNextLevelStart(state: *main.GameState) !void {
    if (!state.statistics.active) return;
    if (state.level == 0) return;
    const levelDatas: []LevelStatistics = try getLevelDatas(state);
    const currentLevelData = &levelDatas[state.level - 1];
    const currentTime = std.time.milliTimestamp();
    currentLevelData.currentShoppingTime = currentTime - state.statistics.runStartedTime - currentLevelData.currentTotalTime;
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
        const levelBeat: u8 = if (state.gamePhase == .shopping or state.gamePhase == .finished) 1 else 0;
        if (state.level - 1 + levelBeat <= index) break;
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
    if (state.gamePhase == .shopping or state.gamePhase == .finished) {
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
        if (!hasReachedHigherLevelBefore and state.level > 1) {
            const highestDefeatedLevelData = levelDatas[state.level - 2];
            if (highestDefeatedLevelData.fastestTotalTime == null or highestDefeatedLevelData.currentTotalTime < highestDefeatedLevelData.fastestTotalTime.?) {
                isNewBestTotal = true;
            }
        }
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
    if (!state.statistics.uxData.display) return;
    // if (state.level <= 1) return;
    if (state.players.items.len > 1 and state.gamePhase != .shopping and state.gamePhase != .finished) return;
    state.statistics.uxData.currentTimestamp = std.time.milliTimestamp();
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const topLeft: main.Position = .{ .x = 0.55, .y = -0.5 };
    const levelDatas: []LevelStatistics = try getLevelDatas(state);
    const fontSize = state.statistics.uxData.fontSize;
    const firstDisplayLevel = if (state.level > 10) state.level - 10 else 1;
    const lastDisplayLevel = if (state.statistics.uxData.displayNextLevelData and state.level < main.LEVEL_COUNT) state.level + 2 else state.level + 1;
    var columnOffsetX: f32 = 0;
    for (state.statistics.uxData.columnsData) |column| {
        if (!column.display) continue;
        _ = fontVulkanZig.paintText(column.name, .{ .x = topLeft.x + columnOffsetX, .y = topLeft.y }, fontSize, textColor, &state.vkState.verticeData.font);
        columnOffsetX += column.pixelWidth * onePixelXInVulkan;
    }
    for (firstDisplayLevel..lastDisplayLevel) |level| {
        const row: f32 = @as(f32, @floatFromInt(level - firstDisplayLevel)) + 1;
        columnOffsetX = 0;
        for (state.statistics.uxData.columnsData) |column| {
            if (!column.display) continue;
            try column.setupVertices(@intCast(level), levelDatas, .{ .x = topLeft.x + columnOffsetX, .y = topLeft.y + row * fontSize * onePixelYInVulkan }, state);
            columnOffsetX += column.pixelWidth * onePixelXInVulkan;
        }
    }
}

fn setupVerticesLevel(level: u32, levelDatas: []LevelStatistics, paintPos: main.Position, state: *main.GameState) anyerror!void {
    _ = levelDatas;
    const alpha: f32 = if (level > state.level) 0.5 else 1;
    _ = try fontVulkanZig.paintNumber(level, .{ .x = paintPos.x, .y = paintPos.y }, state.statistics.uxData.fontSize, .{ 1, 1, 1, alpha }, &state.vkState.verticeData.font);
}

fn setupVerticesTime(level: u32, levelDatas: []LevelStatistics, paintPos: main.Position, state: *main.GameState) anyerror!void {
    const alpha: f32 = if (level > state.level) 0.5 else 1;
    const textColor: [4]f32 = .{ 1, 1, 1, alpha };
    if (level - 1 < levelDatas.len) {
        const levelData = levelDatas[level - 1];
        var displayTime = levelData.currentTotalTime;
        if (level == state.level and state.gamePhase != .shopping) {
            displayTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime;
        } else if (level > state.level) {
            if (levelData.fastestTotalTime) |fastestTotalTime| {
                displayTime = fastestTotalTime;
            } else {
                _ = fontVulkanZig.paintText("--", paintPos, state.statistics.uxData.fontSize, textColor, &state.vkState.verticeData.font);
                return;
            }
        }
        _ = try fontVulkanZig.paintTime(displayTime, paintPos, state.statistics.uxData.fontSize, true, textColor, &state.vkState.verticeData.font);
    } else {
        _ = fontVulkanZig.paintText("--", paintPos, state.statistics.uxData.fontSize, textColor, &state.vkState.verticeData.font);
    }
}

fn setupVerticesLevelDiff(level: u32, levelDatas: []LevelStatistics, paintPos: main.Position, state: *main.GameState) anyerror!void {
    if (level - 1 < levelDatas.len) {
        const levelData = levelDatas[level - 1];
        if (levelData.fastestTime) |fastestTime| {
            const fontSize = state.statistics.uxData.fontSize;
            if (level > state.level) {
                _ = try fontVulkanZig.paintTime(fastestTime, .{ .x = paintPos.x, .y = paintPos.y }, fontSize, true, .{ 1, 1, 1, 0.5 }, &state.vkState.verticeData.font);
            } else {
                const red: [4]f32 = .{ 0.7, 0, 0, 1 };
                const green: [4]f32 = .{ 0.1, 1, 0.1, 1 };
                var levelCurrentTime = levelData.currentTime;
                if (level == state.level and state.gamePhase != .shopping) {
                    if (level > 1) {
                        const lastLevelData = &levelDatas[level - 2];
                        levelCurrentTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - lastLevelData.currentTotalTime - lastLevelData.currentShoppingTime;
                    } else {
                        levelCurrentTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime;
                    }
                }
                const diff = levelCurrentTime - fastestTime;
                const color = if (diff > 0) red else green;
                if (diff > 0) {
                    const plusWidth = fontVulkanZig.paintText("+", .{ .x = paintPos.x, .y = paintPos.y }, fontSize, color, &state.vkState.verticeData.font);
                    _ = try fontVulkanZig.paintTime(diff, .{ .x = paintPos.x + plusWidth, .y = paintPos.y }, fontSize, true, color, &state.vkState.verticeData.font);
                } else {
                    _ = try fontVulkanZig.paintTime(diff, .{ .x = paintPos.x, .y = paintPos.y }, fontSize, true, color, &state.vkState.verticeData.font);
                }
            }
        }
    }
}

fn setupVerticesTotalDiff(level: u32, levelDatas: []LevelStatistics, paintPos: main.Position, state: *main.GameState) anyerror!void {
    if (level - 1 < levelDatas.len) {
        const levelData = levelDatas[level - 1];
        if (levelData.fastestTotalTime) |fastestTime| {
            const fontSize = state.statistics.uxData.fontSize;
            if (level <= state.level) {
                const red: [4]f32 = .{ 0.7, 0, 0, 1 };
                const green: [4]f32 = .{ 0.1, 1, 0.1, 1 };
                var diffTotal: i64 = 0;
                if (level == state.level and state.gamePhase != .shopping) {
                    diffTotal = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - fastestTime;
                } else {
                    diffTotal = levelData.currentTotalTime - fastestTime;
                }

                const color: [4]f32 = if (diffTotal > 0) red else green;
                if (diffTotal > 0) {
                    const plusWidth = fontVulkanZig.paintText("+", .{ .x = paintPos.x, .y = paintPos.y }, fontSize, color, &state.vkState.verticeData.font);
                    _ = try fontVulkanZig.paintTime(diffTotal, .{ .x = paintPos.x + plusWidth, .y = paintPos.y }, fontSize, true, color, &state.vkState.verticeData.font);
                } else {
                    _ = try fontVulkanZig.paintTime(diffTotal, .{ .x = paintPos.x, .y = paintPos.y }, fontSize, true, color, &state.vkState.verticeData.font);
                }
            }
        }
    }
}

fn getLevelDatas(state: *main.GameState) ![]LevelStatistics {
    var optLevelDatas: ?*std.ArrayList(LevelStatistics) = null;
    for (state.statistics.levelDataWithPlayerCount.items) |*levelDataForPlayerCount| {
        if (state.players.items.len == levelDataForPlayerCount.playerCount and state.newGamePlus == levelDataForPlayerCount.newGamePlus) {
            optLevelDatas = &levelDataForPlayerCount.levelDatas;
        }
    }
    if (optLevelDatas == null) {
        try state.statistics.levelDataWithPlayerCount.append(.{
            .levelDatas = std.ArrayList(LevelStatistics).init(state.allocator),
            .playerCount = @intCast(state.players.items.len),
            .newGamePlus = state.newGamePlus,
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
    if (safeFileVersion != SAFE_FILE_VERSION) {
        // std.debug.print("not loading outdated save file version");
    }

    const statisticsForPlayerCountLength: usize = try reader.readInt(usize, .little);
    for (0..statisticsForPlayerCountLength) |_| {
        const playerCount = try reader.readInt(u32, .little);
        const newGamePlus = try reader.readInt(u32, .little);
        const levelDataLength: usize = try reader.readInt(usize, .little);
        try state.statistics.levelDataWithPlayerCount.append(.{
            .levelDatas = std.ArrayList(LevelStatistics).init(state.allocator),
            .playerCount = playerCount,
            .newGamePlus = newGamePlus,
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
        _ = try writer.writeInt(u32, statisticsForPlayerCount.newGamePlus, .little);
        _ = try writer.writeInt(usize, statisticsForPlayerCount.levelDatas.items.len, .little);
        for (statisticsForPlayerCount.levelDatas.items) |levelStatistics| {
            _ = try writer.writeInt(i64, if (levelStatistics.fastestTime) |ft| ft else -1, .little);
            _ = try writer.writeInt(i64, if (levelStatistics.fastestTotalTime) |ftt| ftt else -1, .little);
        }
    }
}
