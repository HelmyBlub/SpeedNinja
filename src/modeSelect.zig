const std = @import("std");
const main = @import("main.zig");
const mapTileZig = @import("mapTile.zig");
const bossZig = @import("boss/boss.zig");
const movePieceZig = @import("movePiece.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const playerZig = @import("player.zig");

pub const ModeSelectData = struct {
    modeStartRectangles: std.ArrayList(ModeStartRectangle),
};

const ModeEnum = enum {
    normal,
    newGamePlus,
};

const ModeData = union(enum) {
    normal,
    newGamePlus: u32,
};

const ModeStartRectangle = struct {
    displayName: []const u8,
    rectangle: main.TileRectangle,
    playerOnRectangleCounter: u32 = 0,
    modeData: ModeData,
};

pub fn initModeSelectData(state: *main.GameState) !void {
    state.modeSelect.modeStartRectangles = std.ArrayList(ModeStartRectangle).init(state.allocator);
    if (state.highestNewGameDifficultyBeaten > -1) {
        try state.modeSelect.modeStartRectangles.append(.{ .displayName = "Normal Mode", .modeData = .normal, .rectangle = .{
            .pos = .{ .x = 4, .y = -4 },
            .height = 2,
            .width = 2,
        } });
        if (state.highestNewGameDifficultyBeaten > 0) {
            for (0..@intCast(state.highestNewGameDifficultyBeaten)) |i| {
                const length = 10 + std.math.log10(i + 1);
                const stringAlloc = try state.allocator.alloc(u8, length);
                _ = try std.fmt.bufPrint(stringAlloc, "New Game+{d}", .{i + 1});
                try state.modeSelect.modeStartRectangles.append(.{ .displayName = stringAlloc, .modeData = .{ .newGamePlus = @intCast(i + 1) }, .rectangle = .{
                    .pos = .{ .x = 4, .y = @as(i32, @intCast(i)) * 3 - 1 },
                    .height = 2,
                    .width = 2,
                } });
            }
        }
    }
}

pub fn setupVertices(state: *main.GameState) !void {
    if (state.gamePhase != .modeSelect) return;
    const modeSelect = &state.modeSelect;
    for (modeSelect.modeStartRectangles.items) |mode| {
        try paintVulkanZig.verticesForStairsWithText(mode.rectangle, mode.displayName, mode.playerOnRectangleCounter, state);
    }
}

pub fn destroyModeSelectData(state: *main.GameState) void {
    const modeSelect = &state.modeSelect;
    if (modeSelect.modeStartRectangles.items.len > 1) {
        for (1..modeSelect.modeStartRectangles.items.len) |i| {
            state.allocator.free(modeSelect.modeStartRectangles.items[i].displayName);
        }
    }
    modeSelect.modeStartRectangles.deinit();
}

pub fn onPlayerMoveActionFinished(state: *main.GameState) !void {
    if (state.gamePhase != .modeSelect) return;
    for (state.modeSelect.modeStartRectangles.items) |*mode| {
        mode.playerOnRectangleCounter = 0;
        for (state.players.items) |*player| {
            const playerTile = main.gamePositionToTilePosition(player.position);
            if (main.isTilePositionInTileRectangle(playerTile, mode.rectangle)) {
                mode.playerOnRectangleCounter += 1;
            }
        }
        if (mode.playerOnRectangleCounter == state.players.items.len) {
            try onStartMode(mode.modeData, state);
            return;
        }
    }
}

pub fn startModeSelect(state: *main.GameState) !void {
    state.gamePhase = .modeSelect;
    state.gameOver = false;
    mapTileZig.resetMapTiles(state.mapData.tiles);
    state.mapObjects.clearAndFree();
    bossZig.clearBosses(state);
    state.enemyData.enemies.clearRetainingCapacity();
    state.enemyData.enemyObjects.clearRetainingCapacity();
    for (state.players.items) |*player| {
        player.isDead = false;
        try movePieceZig.setupMovePieces(player, state);
    }
    state.mapData.tileRadiusHeight = 4;
    state.mapData.tileRadiusWidth = 4;
    main.adjustZoom(state);
}

fn onStartMode(modeData: ModeData, state: *main.GameState) !void {
    switch (modeData) {
        .normal => try main.runStart(state, 0),
        .newGamePlus => |data| try main.runStart(state, data),
    }
}
