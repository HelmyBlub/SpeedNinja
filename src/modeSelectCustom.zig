const std = @import("std");
const main = @import("main.zig");
const mapTileZig = @import("mapTile.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const fontVulkanZig = @import("vulkan/fontVulkan.zig");
const playerZig = @import("player.zig");
const achievementZig = @import("achievement.zig");

pub const ModeCustomData = struct {
    newGamePlus: u32 = 0,
    config: main.GameConfig = .{},
    stairs: struct { rec: main.TileRectangle = .{ .pos = .{ .x = 4, .y = 0 }, .width = 2, .height = 2 }, playerCount: u32 = 0 } = .{},
};

const CustomizeOption = struct {
    tilePos: main.TilePosition,
    name: []const u8,
    onChange: *const fn (leftInput: bool, state: *main.GameState) void,
    setupVerticesForValue: *const fn (option: CustomizeOption, state: *main.GameState) anyerror!void,
};

const CUSTOMIZE_OPTIONS = [_]CustomizeOption{
    .{ .name = "NG+", .tilePos = .{ .x = -2, .y = 0 }, .onChange = onChangeNewGamePlus, .setupVerticesForValue = setupVerticesNewGamePlus },
    .{ .name = "Round Required", .tilePos = .{ .x = -2, .y = 2 }, .onChange = onChangeRoundRequired, .setupVerticesForValue = setupVerticesRoundRequired },
    .{ .name = "Max Time Per Round", .tilePos = .{ .x = -2, .y = 4 }, .onChange = onChangeTimeForRequiredRound, .setupVerticesForValue = setupVerticesTimeForRequiredRound },
    .{ .name = "Bonus Time For Additional Rounds", .tilePos = .{ .x = -2, .y = 6 }, .onChange = onChangeTimeForAdditionalRound, .setupVerticesForValue = setupVerticesTimeForAdditionalRound },
};

pub fn startModeCustom(state: *main.GameState) !void {
    try mapTileZig.setMapRadius(6, 6, state);
    main.adjustZoom(state);
}

pub fn setupVerticesCustom(state: *main.GameState) !void {
    const modeCustomData = &state.modeSelect.modeCustomData;
    try paintVulkanZig.verticesForStairsWithText(
        modeCustomData.stairs.rec,
        "Start",
        modeCustomData.stairs.playerCount,
        state,
    );
    for (CUSTOMIZE_OPTIONS) |option| {
        try setupVerticesCustomOptionDefault(option, state);
        try option.setupVerticesForValue(option, state);
    }
}

pub fn onPlayerMoveActionFinished(player: *playerZig.Player, state: *main.GameState) !void {
    const modeCustomData = &state.modeSelect.modeCustomData;
    modeCustomData.stairs.playerCount = 0;
    for (state.players.items) |*otherPlayer| {
        const playerTile = main.gamePositionToTilePosition(otherPlayer.position);
        if (main.isTilePositionInTileRectangle(playerTile, modeCustomData.stairs.rec)) {
            modeCustomData.stairs.playerCount += 1;
        }
    }
    if (modeCustomData.stairs.playerCount == state.players.items.len) {
        try main.runStart(state, modeCustomData.newGamePlus);
        state.config = modeCustomData.config;
        achievementZig.stopTrackingAchievmentForThisRun(state);
        state.statistics.active = false;
        return;
    }

    const playerTile = main.gamePositionToTilePosition(player.position);
    for (CUSTOMIZE_OPTIONS) |option| {
        if (playerTile.x == option.tilePos.x - 1 and playerTile.y == option.tilePos.y) {
            option.onChange(true, state);
        } else if (playerTile.x == option.tilePos.x + 1 and playerTile.y == option.tilePos.y) {
            option.onChange(false, state);
        }
    }
}

fn setupVerticesCustomOptionDefault(option: CustomizeOption, state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const fontSize = 7;
    const leftButtonPos: main.Position = .{
        .x = @floatFromInt((option.tilePos.x - 1) * main.TILESIZE),
        .y = @floatFromInt(option.tilePos.y * main.TILESIZE),
    };
    const rightButtonPos: main.Position = .{
        .x = @floatFromInt((option.tilePos.x + 1) * main.TILESIZE),
        .y = @floatFromInt(option.tilePos.y * main.TILESIZE),
    };
    _ = fontVulkanZig.paintTextGameMap("+", .{
        .x = rightButtonPos.x,
        .y = rightButtonPos.y,
    }, fontSize, textColor, state);
    _ = fontVulkanZig.paintTextGameMap("-", .{
        .x = leftButtonPos.x,
        .y = leftButtonPos.y,
    }, fontSize, textColor, state);
    _ = fontVulkanZig.paintTextGameMap(option.name, .{
        .x = leftButtonPos.x,
        .y = leftButtonPos.y - fontSize,
    }, fontSize, textColor, state);
}

fn onChangeNewGamePlus(leftInput: bool, state: *main.GameState) void {
    if (leftInput) {
        state.modeSelect.modeCustomData.newGamePlus -|= 1;
    } else {
        state.modeSelect.modeCustomData.newGamePlus = @min(10, state.modeSelect.modeCustomData.newGamePlus + 1);
    }
}

fn setupVerticesNewGamePlus(option: CustomizeOption, state: *main.GameState) anyerror!void {
    try displayNumberAtOption(option, state.modeSelect.modeCustomData.newGamePlus, state);
}

fn onChangeRoundRequired(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.roundToReachForNextLevel = @max(config.roundToReachForNextLevel - 1, 2);
    } else {
        config.roundToReachForNextLevel = @min(100, config.roundToReachForNextLevel + 1);
    }
}

fn setupVerticesRoundRequired(option: CustomizeOption, state: *main.GameState) anyerror!void {
    try displayNumberAtOption(option, state.modeSelect.modeCustomData.config.roundToReachForNextLevel - 1, state);
}

fn onChangeTimeForRequiredRound(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.minimalTimePerRequiredRounds = @max(config.minimalTimePerRequiredRounds - 10000, 10_000);
    } else {
        config.minimalTimePerRequiredRounds = @min(300_000, config.minimalTimePerRequiredRounds + 10_000);
    }
}

fn setupVerticesTimeForRequiredRound(option: CustomizeOption, state: *main.GameState) anyerror!void {
    const displayValue = @divFloor(state.modeSelect.modeCustomData.config.minimalTimePerRequiredRounds, 1000);
    try displayNumberAtOption(option, displayValue, state);
}

fn onChangeTimeForAdditionalRound(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.bonusTimePerRoundFinished = @max(config.bonusTimePerRoundFinished - 1000, 1_000);
    } else {
        config.bonusTimePerRoundFinished = @min(60_000, config.bonusTimePerRoundFinished + 1_000);
    }
}

fn setupVerticesTimeForAdditionalRound(option: CustomizeOption, state: *main.GameState) anyerror!void {
    const displayValue = @divFloor(state.modeSelect.modeCustomData.config.bonusTimePerRoundFinished, 1000);
    try displayNumberAtOption(option, displayValue, state);
}

fn displayNumberAtOption(option: CustomizeOption, number: anytype, state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const fontSize = 7;
    const startTopLeft: main.Position = .{
        .x = @floatFromInt(option.tilePos.x * main.TILESIZE),
        .y = @floatFromInt(option.tilePos.y * main.TILESIZE),
    };
    _ = try fontVulkanZig.paintNumberGameMap(number, .{
        .x = startTopLeft.x,
        .y = startTopLeft.y,
    }, fontSize, textColor, state);
}
