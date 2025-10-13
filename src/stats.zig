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
    vulkanPosition: main.Position = .{ .x = 0, .y = 0 },
    fontSize: f32 = 16,
    columnsData: []ColumnData = &COLUMNS_DATA,
    currentTimestamp: i64 = 0,
    displayBestRun: bool = true,
    displayNextLevelCount: u8 = 5,
    displayLevelCount: u8 = 5,
    displayGoldRun: bool = true,
    displayGoldRunValue: ?i64 = null,
    displayGoldRunLevel: u32 = 0,
    displayBestPossibleTime: bool = true,
    displayBestPossibleTimeValue: ?i64 = null,
    displayBestPossibleTimeLevel: u32 = 0,
    displayTimeInShop: bool = true,
    groupingLevelsInFive: bool = true,
};

const ColumnData = struct {
    name: []const u8,
    display: bool,
    pixelWidth: f32,
    setupVertices: *const fn (level: u32, levelDatas: []LevelStatistics, paintPos: main.Position, columnData: ColumnData, state: *main.GameState) anyerror!void,
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
    .{ .name = "Level", .display = true, .pixelWidth = 70, .setupVertices = setupVerticesLevel },
    .{ .name = "Time", .display = true, .pixelWidth = 100, .setupVertices = setupVerticesTime },
    .{ .name = "+/-", .display = true, .pixelWidth = 80, .setupVertices = setupVerticesTotalDiff },
    .{ .name = "Gold", .display = true, .pixelWidth = 80, .setupVertices = setupVerticesLevelDiff },
};

pub fn statsOnLevelFinished(state: *main.GameState) !void {
    const currentTime = std.time.milliTimestamp();
    if (state.level == main.LEVEL_COUNT and state.gamePhase == .finished) state.statistics.runFinishedTime = currentTime - state.statistics.runStartedTime;
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
    if (!state.statistics.uxData.display) return;
    if (state.level == 0) return;
    if (state.players.items.len > 1 and state.gamePhase != .shopping and state.gamePhase != .finished) return;
    state.statistics.uxData.currentTimestamp = std.time.milliTimestamp();
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const topLeft: main.Position = state.statistics.uxData.vulkanPosition;
    const levelDatas: []LevelStatistics = try getLevelDatas(state);
    state.statistics.uxData.fontSize = 16 * state.uxData.settingsMenuUx.uiSizeDelayed;
    const fontSize = state.statistics.uxData.fontSize;
    var columnOffsetX: f32 = 0;
    for (state.statistics.uxData.columnsData) |column| {
        if (!column.display) continue;
        const columnWidth = column.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
        const textWidht = fontVulkanZig.getTextVulkanWidth(column.name, fontSize);
        _ = fontVulkanZig.paintText(column.name, .{
            .x = topLeft.x + columnOffsetX + columnWidth - textWidht,
            .y = topLeft.y,
        }, fontSize, textColor, &state.vkState.verticeData.font);
        columnOffsetX += columnWidth;
    }
    var firstDisplayLevelWithoutMult: usize = 0;
    const groupingMultiplay: usize = if (state.statistics.uxData.groupingLevelsInFive) 5 else 1;
    if (state.level > state.statistics.uxData.displayLevelCount * groupingMultiplay) {
        if (state.statistics.uxData.groupingLevelsInFive) {
            firstDisplayLevelWithoutMult = @divFloor(state.level + 4, groupingMultiplay) - state.statistics.uxData.displayLevelCount;
        } else {
            firstDisplayLevelWithoutMult = state.level - state.statistics.uxData.displayLevelCount;
        }
    } else {
        firstDisplayLevelWithoutMult = 1;
    }
    var lastDisplayLevelWithoutMultPlusOne: usize = 0;
    if (state.statistics.uxData.groupingLevelsInFive) {
        lastDisplayLevelWithoutMultPlusOne = @min(@divFloor(main.LEVEL_COUNT, groupingMultiplay), @divFloor(state.level + 4 + state.statistics.uxData.displayNextLevelCount, groupingMultiplay)) + 1;
    } else {
        lastDisplayLevelWithoutMultPlusOne = @min(main.LEVEL_COUNT, state.level + state.statistics.uxData.displayNextLevelCount) + 1;
    }
    for (firstDisplayLevelWithoutMult..lastDisplayLevelWithoutMultPlusOne) |levelWithoutMult| {
        const level = groupingMultiplay * levelWithoutMult;
        const row: f32 = @as(f32, @floatFromInt(levelWithoutMult - firstDisplayLevelWithoutMult)) + 1;
        columnOffsetX = 0;
        for (state.statistics.uxData.columnsData) |column| {
            if (!column.display) continue;
            try column.setupVertices(@intCast(level), levelDatas, .{ .x = topLeft.x + columnOffsetX, .y = topLeft.y + row * fontSize * onePixelYInVulkan }, column, state);
            columnOffsetX += column.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
        }
    }
    var currentY = topLeft.y + @as(f32, @floatFromInt(lastDisplayLevelWithoutMultPlusOne - firstDisplayLevelWithoutMult + 1)) * fontSize * onePixelYInVulkan;
    if (state.statistics.uxData.displayTimeInShop) {
        var shopppingTime = state.statistics.totalShoppingTime;
        if (state.gamePhase == .shopping) {
            shopppingTime += state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - levelDatas[state.level - 1].currentTotalTime;
        }
        const textWidth = fontVulkanZig.paintText("Shop: ", .{
            .x = topLeft.x,
            .y = currentY,
        }, fontSize, textColor, &state.vkState.verticeData.font);
        _ = try fontVulkanZig.paintTime(shopppingTime, .{
            .x = topLeft.x + textWidth,
            .y = currentY,
        }, fontSize, true, textColor, &state.vkState.verticeData.font);
        currentY += fontSize * onePixelYInVulkan;
    }
    currentY += fontSize * onePixelYInVulkan;
    if (state.statistics.uxData.displayBestPossibleTime) {
        if (state.statistics.uxData.displayBestPossibleTimeValue == null) {
            try calculateSumOfGoldsOfRemainingLevels(state);
        }
        var pastTimePart: ?i64 = null;
        if (state.gamePhase == .shopping) {
            if (levelDatas.len > state.level and levelDatas[state.level].fastestTime != null) {
                const lastLevelFinishTime = levelDatas[state.level - 1].currentTotalTime;
                const currentLevelEstimate = @max(levelDatas[state.level].fastestTime.?, state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - lastLevelFinishTime);
                pastTimePart = lastLevelFinishTime + currentLevelEstimate;
            }
        } else if (state.level == 1) {
            if (levelDatas[0].fastestTime) |fastestTime| {
                pastTimePart = @max(fastestTime, state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime);
            }
        } else {
            if (levelDatas[state.level - 1].fastestTime) |fastestTime| {
                const lastLevelFinishTime = levelDatas[state.level - 2].currentTotalTime;
                const currentLevelEstimate = @max(fastestTime, state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - lastLevelFinishTime);
                pastTimePart = lastLevelFinishTime + currentLevelEstimate;
            }
        }
        if (pastTimePart) |timePart| {
            try displayTextNumberTextTime(
                "Best Possible Time: Level ",
                state.statistics.uxData.displayBestPossibleTimeLevel,
                " in ",
                state.statistics.uxData.displayBestPossibleTimeValue.? + timePart,
                .{ .x = topLeft.x, .y = currentY },
                fontSize,
                textColor,
                state,
            );
            currentY += fontSize * onePixelYInVulkan;
        }
    }
    if (state.statistics.uxData.displayBestRun) {
        var furthestDataIndex: usize = 0;
        for (levelDatas, 0..) |level, index| {
            if (level.fastestTotalTime != null) {
                furthestDataIndex = index;
            }
        }
        if (levelDatas[furthestDataIndex].fastestTotalTime) |fastestTotalTime| {
            try displayTextNumberTextTime(
                "Best Run: Level ",
                furthestDataIndex + 1,
                " in ",
                fastestTotalTime,
                .{ .x = topLeft.x, .y = currentY },
                fontSize,
                textColor,
                state,
            );
            currentY += fontSize * onePixelYInVulkan;
        }
    }
    if (state.statistics.uxData.displayGoldRun) {
        if (state.statistics.uxData.displayGoldRunValue == null) {
            try calculateSumOfGolds(state);
        }
        if (state.statistics.uxData.displayGoldRunValue) |goldRunTime| {
            try displayTextNumberTextTime(
                "Gold Run: Level ",
                state.statistics.uxData.displayGoldRunLevel,
                " in ",
                goldRunTime,
                .{ .x = topLeft.x, .y = currentY },
                fontSize,
                textColor,
                state,
            );
            currentY += fontSize * onePixelYInVulkan;
        }
    }
}

fn displayTextNumberTextTime(text1: []const u8, number: anytype, text2: []const u8, time: i64, topLeft: main.Position, fontSize: f32, textColor: [4]f32, state: *main.GameState) !void {
    var textWidth: f32 = 0;
    textWidth += fontVulkanZig.paintText(text1, .{
        .x = topLeft.x + textWidth,
        .y = topLeft.y,
    }, fontSize, textColor, &state.vkState.verticeData.font);
    textWidth += try fontVulkanZig.paintNumber(number, .{
        .x = topLeft.x + textWidth,
        .y = topLeft.y,
    }, fontSize, textColor, &state.vkState.verticeData.font);
    textWidth += fontVulkanZig.paintText(text2, .{
        .x = topLeft.x + textWidth,
        .y = topLeft.y,
    }, fontSize, textColor, &state.vkState.verticeData.font);
    _ = try fontVulkanZig.paintTime(time, .{
        .x = topLeft.x + textWidth,
        .y = topLeft.y,
    }, fontSize, true, textColor, &state.vkState.verticeData.font);
}

fn setupVerticesLevel(level: u32, levelDatas: []LevelStatistics, paintPos: main.Position, columnData: ColumnData, state: *main.GameState) anyerror!void {
    _ = levelDatas;
    const currentDisplayLevelOfPlayer = if (state.statistics.uxData.groupingLevelsInFive) @divFloor(state.level + 4, 5) * 5 else state.level;
    const alpha: f32 = if (level > currentDisplayLevelOfPlayer) 0.5 else 1;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const columnWidth = columnData.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
    const textWidth = fontVulkanZig.getTextVulkanWidth(columnData.name, state.statistics.uxData.fontSize);
    _ = try fontVulkanZig.paintNumber(level, .{
        .x = paintPos.x + columnWidth - textWidth,
        .y = paintPos.y,
    }, state.statistics.uxData.fontSize, .{ 1, 1, 1, alpha }, &state.vkState.verticeData.font);
}

fn setupVerticesTime(level: u32, levelDatas: []LevelStatistics, paintPos: main.Position, columnData: ColumnData, state: *main.GameState) anyerror!void {
    const currentDisplayLevelOfPlayer = if (state.statistics.uxData.groupingLevelsInFive) @divFloor(state.level + 4, 5) * 5 else state.level;
    const alpha: f32 = if (level > currentDisplayLevelOfPlayer) 0.5 else 1;
    const textColor: [4]f32 = .{ 1, 1, 1, alpha };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const columnWidth = columnData.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
    if (level - 1 < levelDatas.len) {
        const levelData = levelDatas[level - 1];
        var displayTime = levelData.currentTotalTime;
        if (state.statistics.uxData.groupingLevelsInFive and @divFloor(level, 5) == @divFloor(state.level + 4, 5) and (state.gamePhase != .shopping or @mod(state.level, 5) != 0)) {
            displayTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime;
        } else if (level == state.level and state.gamePhase != .shopping) {
            displayTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime;
        } else if (level > state.level) {
            if (levelData.fastestTotalTime) |fastestTotalTime| {
                displayTime = fastestTotalTime;
            } else {
                const textWidht = fontVulkanZig.getTextVulkanWidth("--", state.statistics.uxData.fontSize);
                const paintX = paintPos.x + columnWidth - textWidht;
                _ = fontVulkanZig.paintText("--", .{ .x = paintX, .y = paintPos.y }, state.statistics.uxData.fontSize, textColor, &state.vkState.verticeData.font);
                return;
            }
        }
        const textWidht = try fontVulkanZig.getTimeTextVulkanWidth(displayTime, state.statistics.uxData.fontSize, true);
        const paintX = paintPos.x + columnWidth - textWidht;
        _ = try fontVulkanZig.paintTime(displayTime, .{ .x = paintX, .y = paintPos.y }, state.statistics.uxData.fontSize, true, textColor, &state.vkState.verticeData.font);
    } else {
        const textWidht = fontVulkanZig.getTextVulkanWidth("--", state.statistics.uxData.fontSize);
        const paintX = paintPos.x + columnWidth - textWidht;
        _ = fontVulkanZig.paintText("--", .{ .x = paintX, .y = paintPos.y }, state.statistics.uxData.fontSize, textColor, &state.vkState.verticeData.font);
    }
}

fn setupVerticesLevelDiff(level: u32, levelDatas: []LevelStatistics, paintPos: main.Position, columnData: ColumnData, state: *main.GameState) anyerror!void {
    if (level - 1 >= levelDatas.len) return;
    const levelData = levelDatas[level - 1];
    if (levelData.fastestTime) |levelFastestTime| {
        var fastestTime = levelFastestTime;
        if (state.statistics.uxData.groupingLevelsInFive) {
            for (1..5) |i| {
                fastestTime += levelDatas[level - i - 1].fastestTime.?;
            }
        }
        const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
        const columnWidth = columnData.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
        const fontSize = state.statistics.uxData.fontSize;
        const currentDisplayLevelOfPlayer = if (state.statistics.uxData.groupingLevelsInFive) @divFloor(state.level - 1, 5) * 5 + 5 else state.level;
        if (level > currentDisplayLevelOfPlayer) {
            const textWidht = try fontVulkanZig.getTimeTextVulkanWidth(fastestTime, fontSize, true);
            const paintX = paintPos.x + columnWidth - textWidht;
            _ = try fontVulkanZig.paintTime(fastestTime, .{ .x = paintX, .y = paintPos.y }, fontSize, true, .{ 1, 1, 1, 0.5 }, &state.vkState.verticeData.font);
        } else {
            const red: [4]f32 = .{ 0.7, 0, 0, 1 };
            const green: [4]f32 = .{ 0.1, 1, 0.1, 1 };
            var levelCurrentTime = levelData.currentTime;
            if (state.statistics.uxData.groupingLevelsInFive) {
                if (currentDisplayLevelOfPlayer == level) {
                    if (state.level == 1) {
                        if (state.gamePhase != .shopping) {
                            levelCurrentTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime;
                        } else {
                            levelCurrentTime = levelDatas[0].currentTime;
                        }
                    } else {
                        const levelItCount = @mod(state.level - 1, 5);
                        levelCurrentTime = 0;
                        for (0..levelItCount) |i| {
                            levelCurrentTime += levelDatas[level - (4 - i) - 1].currentTime;
                        }
                        if (state.gamePhase != .shopping) {
                            const lastLevelData = &levelDatas[state.level - 2];
                            levelCurrentTime += state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - lastLevelData.currentTotalTime - lastLevelData.currentShoppingTime;
                        } else {
                            levelCurrentTime += levelDatas[state.level - 1].currentTime;
                        }
                    }
                } else {
                    for (1..5) |i| {
                        levelCurrentTime += levelDatas[level - i - 1].currentTime;
                    }
                }
            } else if (level == state.level and state.gamePhase != .shopping) {
                if (level > 1) {
                    const lastLevelData = &levelDatas[level - 2];
                    levelCurrentTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - lastLevelData.currentTotalTime - lastLevelData.currentShoppingTime;
                } else {
                    levelCurrentTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime;
                }
            }
            const diff = levelCurrentTime - fastestTime;
            const color = if (diff > 0) red else green;
            const textWidht = try fontVulkanZig.getTimeTextVulkanWidth(diff, fontSize, true);
            if (diff > 0) {
                const textPlusWidht = fontVulkanZig.getTextVulkanWidth("+", fontSize);
                const paintX = paintPos.x + columnWidth - textWidht - textPlusWidht;
                const plusWidth = fontVulkanZig.paintText("+", .{ .x = paintX, .y = paintPos.y }, fontSize, color, &state.vkState.verticeData.font);
                _ = try fontVulkanZig.paintTime(diff, .{ .x = paintX + plusWidth, .y = paintPos.y }, fontSize, true, color, &state.vkState.verticeData.font);
            } else {
                const paintX = paintPos.x + columnWidth - textWidht;
                _ = try fontVulkanZig.paintTime(diff, .{ .x = paintX, .y = paintPos.y }, fontSize, true, color, &state.vkState.verticeData.font);
            }
        }
    }
}

fn setupVerticesTotalDiff(level: u32, levelDatas: []LevelStatistics, paintPos: main.Position, columnData: ColumnData, state: *main.GameState) anyerror!void {
    if (level - 1 >= levelDatas.len) return;
    const levelData = levelDatas[level - 1];
    if (levelData.fastestTotalTime) |fastestTime| {
        const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
        const columnWidth = columnData.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
        const fontSize = state.statistics.uxData.fontSize;
        const currentDisplayLevelOfPlayer = if (state.statistics.uxData.groupingLevelsInFive) @divFloor(state.level - 1, 5) * 5 + 5 else state.level;
        if (level <= currentDisplayLevelOfPlayer) {
            const red: [4]f32 = .{ 0.7, 0, 0, 1 };
            const green: [4]f32 = .{ 0.1, 1, 0.1, 1 };
            var diffTotal: i64 = 0;
            if (level > state.level or (level == state.level and state.gamePhase != .shopping)) {
                diffTotal = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - fastestTime;
            } else {
                diffTotal = levelData.currentTotalTime - fastestTime;
            }

            const color: [4]f32 = if (diffTotal > 0) red else green;
            const textWidht = try fontVulkanZig.getTimeTextVulkanWidth(diffTotal, fontSize, true);
            if (diffTotal > 0) {
                const textPlusWidht = fontVulkanZig.getTextVulkanWidth("+", fontSize);
                const paintX = paintPos.x + columnWidth - textWidht - textPlusWidht;
                const plusWidth = fontVulkanZig.paintText("+", .{ .x = paintX, .y = paintPos.y }, fontSize, color, &state.vkState.verticeData.font);
                _ = try fontVulkanZig.paintTime(diffTotal, .{ .x = paintX + plusWidth, .y = paintPos.y }, fontSize, true, color, &state.vkState.verticeData.font);
            } else {
                const paintX = paintPos.x + columnWidth - textWidht;
                _ = try fontVulkanZig.paintTime(diffTotal, .{ .x = paintX, .y = paintPos.y }, fontSize, true, color, &state.vkState.verticeData.font);
            }
        }
    }
}

pub fn getLevelDatas(state: *main.GameState) ![]LevelStatistics {
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

fn calculateSumOfGolds(state: *main.GameState) !void {
    const levelDatas: []LevelStatistics = try getLevelDatas(state);
    var sumOfGold: i64 = 0;
    for (levelDatas, 0..) |level, index| {
        if (level.fastestTime) |fastestTime| {
            sumOfGold += fastestTime;
            state.statistics.uxData.displayGoldRunLevel = @intCast(index + 1);
        }
    }
    if (sumOfGold > 0) {
        state.statistics.uxData.displayGoldRunValue = sumOfGold;
    } else {
        state.statistics.uxData.displayGoldRunValue = null;
    }
}

fn calculateSumOfGoldsOfRemainingLevels(state: *main.GameState) !void {
    const levelDatas: []LevelStatistics = try getLevelDatas(state);
    var sumOfGoldRemaining: i64 = 0;
    const startLevel = if (state.gamePhase == .shopping) state.level + 1 else state.level;
    for (startLevel..levelDatas.len) |index| {
        const level = levelDatas[index];
        if (level.fastestTime) |fastestTime| {
            sumOfGoldRemaining += fastestTime;
            state.statistics.uxData.displayBestPossibleTimeLevel = @intCast(index + 1);
        }
    }
    state.statistics.uxData.displayBestPossibleTimeValue = sumOfGoldRemaining;
}
