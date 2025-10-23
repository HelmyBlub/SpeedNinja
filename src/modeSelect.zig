const std = @import("std");
const main = @import("main.zig");
const mapTileZig = @import("mapTile.zig");
const bossZig = @import("boss/boss.zig");
const movePieceZig = @import("movePiece.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const playerZig = @import("player.zig");
const fontVulkanZig = @import("vulkan/fontVulkan.zig");
const imageZig = @import("image.zig");
const windowSdlZig = @import("windowSdl.zig");
const sdl = windowSdlZig.sdl;
const shopZig = @import("shop.zig");

pub const ModeSelectData = struct {
    modeStartRectangles: std.ArrayList(ModeStartRectangle),
    selectedMode: ModeData,
};

const ModeEnum = enum {
    none,
    normal,
    newGamePlus,
    practice,
};

const ModeData = union(enum) {
    none,
    normal,
    newGamePlus: u32,
    practice,
};

const ModeStartRectangle = struct {
    displayName: []const u8,
    deallocDisplayName: bool = false,
    rectangle: main.TileRectangle,
    playerOnRectangleCounter: u32 = 0,
    modeData: ModeData,
};

pub fn initModeSelectData(state: *main.GameState) !void {
    state.modeSelect.modeStartRectangles = std.ArrayList(ModeStartRectangle).init(state.allocator);
    try state.modeSelect.modeStartRectangles.append(.{ .displayName = "Normal Mode", .modeData = .normal, .rectangle = .{
        .pos = .{ .x = 4, .y = -4 },
        .height = 2,
        .width = 2,
    } });
    try state.modeSelect.modeStartRectangles.append(.{ .displayName = "Practice Mode", .modeData = .practice, .rectangle = .{
        .pos = .{ .x = -4, .y = -4 },
        .height = 2,
        .width = 2,
    } });
    if (state.highestNewGameDifficultyBeaten > -1) {
        for (0..@intCast(state.highestNewGameDifficultyBeaten + 1)) |_| {
            try addNextNewGamePlusMode(state);
        }
    }
}

pub fn addNextNewGamePlusMode(state: *main.GameState) !void {
    var nextNGPlus: u32 = 0;
    for (state.modeSelect.modeStartRectangles.items) |modeRec| {
        if (modeRec.modeData == .newGamePlus and modeRec.modeData.newGamePlus > nextNGPlus) nextNGPlus = modeRec.modeData.newGamePlus;
    }
    nextNGPlus += 1;
    if (nextNGPlus > state.highestNewGameDifficultyBeaten + 1) return;
    const length = 10 + std.math.log10(nextNGPlus);
    const stringAlloc = try state.allocator.alloc(u8, length);
    _ = try std.fmt.bufPrint(stringAlloc, "New Game+{d}", .{nextNGPlus});
    try state.modeSelect.modeStartRectangles.append(.{
        .displayName = stringAlloc,
        .deallocDisplayName = true,
        .modeData = .{ .newGamePlus = @intCast(nextNGPlus) },
        .rectangle = .{
            .pos = .{ .x = 4, .y = @as(i32, @intCast(nextNGPlus - 1)) * 3 - 1 },
            .height = 2,
            .width = 2,
        },
    });
}

pub fn setupVertices(state: *main.GameState) !void {
    if (state.gamePhase == .modeSelect) {
        const modeSelect = &state.modeSelect;
        for (modeSelect.modeStartRectangles.items) |mode| {
            try paintVulkanZig.verticesForStairsWithText(mode.rectangle, mode.displayName, mode.playerOnRectangleCounter, state);
        }
    } else {
        switch (state.modeSelect.selectedMode) {
            .practice => verticesForPracticeMode(state),
            else => {},
        }
    }
}

pub fn destroyModeSelectData(state: *main.GameState) void {
    const modeSelect = &state.modeSelect;
    for (modeSelect.modeStartRectangles.items) |item| {
        if (item.deallocDisplayName) state.allocator.free(item.displayName);
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
        player.position.x = 0;
        player.position.y = 0;
        try movePieceZig.setupMovePieces(player, state);
    }
    state.mapData.tileRadiusHeight = 4;
    state.mapData.tileRadiusWidth = 4;
    state.camera.position = .{ .x = 0, .y = 0 };
    mapTileZig.setMapType(.default, state);
    state.level = 0;
    main.adjustZoom(state);
}

fn onStartMode(modeData: ModeData, state: *main.GameState) !void {
    state.modeSelect.selectedMode = modeData;
    switch (modeData) {
        .none => {},
        .normal => try main.runStart(state, 0),
        .newGamePlus => |data| try main.runStart(state, data),
        .practice => try main.runStart(state, 0),
    }
}

fn verticesForPracticeMode(state: *main.GameState) void {
    const fontSize = 40 * state.uxData.settingsMenuUx.uiSizeDelayed;
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const basePosition: main.Position = .{ .x = 0.5, .y = 0.99 - (fontSize * onePixelYInVulkan) * 2 };
    const key1Text = "F1  Next Level";
    const key1TextWidth = fontVulkanZig.getTextVulkanWidth(key1Text, fontSize / 2, state);
    const leftOffsetX = key1TextWidth + onePixelXInVulkan * 10;
    const key1Pos: main.Position = .{ .x = basePosition.x - leftOffsetX, .y = basePosition.y };
    paintVulkanZig.verticesForComplexSpriteVulkan(key1Pos, imageZig.IMAGE_KEY_BLANK, fontSize, fontSize, 1, 0, false, false, state);
    _ = fontVulkanZig.paintText(key1Text, .{
        .x = key1Pos.x - onePixelXInVulkan * fontSize / 4 - onePixelXInVulkan * 2,
        .y = key1Pos.y - onePixelYInVulkan * fontSize / 4,
    }, fontSize / 2, .{ 1, 1, 1, 1 }, state);

    const key2Pos: main.Position = .{ .x = basePosition.x - leftOffsetX, .y = basePosition.y + onePixelYInVulkan * fontSize };
    paintVulkanZig.verticesForComplexSpriteVulkan(key2Pos, imageZig.IMAGE_KEY_BLANK, fontSize, fontSize, 1, 0, false, false, state);
    _ = fontVulkanZig.paintText("F2  Shop", .{
        .x = key2Pos.x - onePixelXInVulkan * fontSize / 4 - onePixelXInVulkan * 2,
        .y = key2Pos.y - onePixelYInVulkan * fontSize / 4,
    }, fontSize / 2, .{ 1, 1, 1, 1 }, state);

    const key3Pos: main.Position = basePosition;
    paintVulkanZig.verticesForComplexSpriteVulkan(key3Pos, imageZig.IMAGE_KEY_BLANK, fontSize, fontSize, 1, 0, false, false, state);
    _ = fontVulkanZig.paintText("F3  NewGame++", .{
        .x = key3Pos.x - onePixelXInVulkan * fontSize / 4 - onePixelXInVulkan * 2,
        .y = key3Pos.y - onePixelYInVulkan * fontSize / 4,
    }, fontSize / 2, .{ 1, 1, 1, 1 }, state);

    const key4Pos: main.Position = .{ .x = basePosition.x, .y = basePosition.y + onePixelYInVulkan * fontSize };
    paintVulkanZig.verticesForComplexSpriteVulkan(key4Pos, imageZig.IMAGE_KEY_BLANK, fontSize, fontSize, 1, 0, false, false, state);
    _ = fontVulkanZig.paintText("F4  Restart", .{
        .x = key4Pos.x - onePixelXInVulkan * fontSize / 4 - onePixelXInVulkan * 2,
        .y = key4Pos.y - onePixelYInVulkan * fontSize / 4,
    }, fontSize / 2, .{ 1, 1, 1, 1 }, state);
}

pub fn handlePracticeModeKeys(event: sdl.SDL_Event, state: *main.GameState) !void {
    if (event.key.scancode == sdl.SDL_SCANCODE_F1) {
        if (state.level == main.LEVEL_COUNT) {
            state.level = 0;
        }
        if (state.gamePhase != .shopping) try shopZig.startShoppingPhase(state, false);
        try main.startNextLevel(state);
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F2) {
        if (state.gamePhase != .shopping) state.level -= 1;
        try shopZig.startShoppingPhase(state, false);
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F3) {
        state.newGamePlus = @mod(state.newGamePlus + 1, 3);
        state.statistics.currentRunStats.newGamePlus = state.newGamePlus;
        if (state.gamePhase != .shopping) {
            state.level -= 1;
            try main.startNextLevel(state);
        }
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F4) {
        try main.runStart(state, state.newGamePlus);
    }
}
