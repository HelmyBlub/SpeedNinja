const std = @import("std");
const main = @import("../main.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");
const bossZig = @import("../boss/boss.zig");
const inputZig = @import("../input.zig");
const playerZig = @import("../player.zig");
const imageZig = @import("../image.zig");

pub fn setupVertices(state: *main.GameState) !void {
    const fontSize = 30;
    const verticeData = &state.vkState.verticeData;
    const fontVertices = &verticeData.font;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const textColor: [3]f32 = .{ 1, 1, 1 };

    if (state.gamePhase == .boss) {
        if (state.bosses.items.len == 0) return;
        const spacingX = onePixelXInVulkan * 5;
        const top = -0.99;
        const height = onePixelYInVulkan * fontSize;
        const length = @as(f32, @floatFromInt(state.bosses.items.len));
        const width: f32 = @min(1, 1.8 / length);
        var currentLeft = -((width * length + spacingX * (length - 1)) / 2);
        for (state.bosses.items) |*boss| {
            try setupVerticesBossHpBar(boss, top, currentLeft, height, width, state);
            currentLeft += width + spacingX;
        }
    }
    try verticesForTimer(state);
    try verticesForLevelRoundNewGamePlus(state);

    if (state.gameOver) {
        const gameOverPos: main.Position = .{ .x = -0.4, .y = -0.1 };
        _ = fontVulkanZig.paintText("GAME OVER", gameOverPos, 120, textColor, fontVertices);
        const optContinueCosts = main.getMoneyCostsForContinue(state);
        if (optContinueCosts) |continueCosts| {
            const continuePos: main.Position = .{ .x = gameOverPos.x, .y = gameOverPos.y + 120 * onePixelYInVulkan };
            const offsetX = fontVulkanZig.paintText("Continue: $", continuePos, 60, textColor, fontVertices);
            _ = try fontVulkanZig.paintNumber(continueCosts, .{ .x = continuePos.x + offsetX, .y = continuePos.y }, 60, textColor, fontVertices);
        }
    }
    try verticesForLeaveJoinInfo(state);
    verticsForTutorial(state);
}

fn verticesForTimer(state: *main.GameState) !void {
    const verticeData = &state.vkState.verticeData;
    const fontVertices = &verticeData.font;
    const textColor: [3]f32 = .{ 1, 1, 1 };
    const fontSize = 50;
    const isBossTimer = state.gamePhase == .boss and state.newGamePlus >= 2 and state.level != main.LEVEL_COUNT;
    if (state.round > 1 and state.gamePhase == .combat or isBossTimer) {
        const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
        const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
        var timePos: main.Position = .{
            .x = 0,
            .y = -0.99,
        };
        if (isBossTimer) {
            timePos.y += 36 * onePixelYInVulkan;
        }
        paintVulkanZig.verticesForComplexSpriteVulkan(
            .{ .x = timePos.x - fontSize / 2 * onePixelXInVulkan, .y = timePos.y + fontSize / 2 * onePixelYInVulkan },
            imageZig.IMAGE_CLOCK,
            fontSize,
            fontSize,
            1,
            0,
            false,
            false,
            state,
        );
        const remainingTime: i64 = @max(0, @divFloor(state.suddenDeathTimeMs - state.gameTime, 1000));
        _ = try fontVulkanZig.paintNumber(remainingTime, .{ .x = timePos.x, .y = timePos.y }, fontSize, textColor, fontVertices);
    }
}

fn verticesForLevelRoundNewGamePlus(state: *main.GameState) !void {
    const textColor: [3]f32 = .{ 1, 1, 1 };
    const fontSize = 30;
    const verticeData = &state.vkState.verticeData;
    const fontVertices = &verticeData.font;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    var textWidth: f32 = 0;
    const levelPos: main.Position = .{
        .x = -0.99,
        .y = -0.99,
    };
    const paddingX = 2 * onePixelXInVulkan;
    const paddingY = 2 * onePixelYInVulkan;
    if (state.level > 4) {
        textWidth += fontVulkanZig.paintText("L ", .{ .x = levelPos.x, .y = levelPos.y }, fontSize, textColor, fontVertices);
    } else {
        textWidth += fontVulkanZig.paintText("Level ", .{ .x = levelPos.x, .y = levelPos.y }, fontSize, textColor, fontVertices);
    }
    textWidth += try fontVulkanZig.paintNumber(state.level, .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, fontVertices);
    paintVulkanZig.verticesForRectangle(levelPos.x - paddingX, levelPos.y - paddingY, textWidth + paddingX * 3, fontSize * onePixelYInVulkan + paddingY * 2, .{ 1, 1, 1 }, &verticeData.lines, &verticeData.triangles);

    if (state.newGamePlus > 0) {
        textWidth += paddingX * 6;
        const newGamePlusStartX = textWidth;
        if (state.level > 4) {
            textWidth += fontVulkanZig.paintText("NG+", .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, fontVertices);
        } else {
            textWidth += fontVulkanZig.paintText("NewGame+ ", .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, fontVertices);
        }
        textWidth += try fontVulkanZig.paintNumber(state.newGamePlus, .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, fontVertices);
        paintVulkanZig.verticesForRectangle(levelPos.x + newGamePlusStartX - paddingX, levelPos.y - paddingY, textWidth - newGamePlusStartX + paddingX * 3, fontSize * onePixelYInVulkan + paddingY * 2, .{ 1, 1, 1 }, &verticeData.lines, &verticeData.triangles);
    }

    if (state.gamePhase != .boss) {
        textWidth += paddingX * 6;
        const roundStartX = textWidth;
        if (state.level > 4) {
            textWidth += fontVulkanZig.paintText("R ", .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, fontVertices);
        } else {
            textWidth += fontVulkanZig.paintText("Round ", .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, fontVertices);
        }
        textWidth += try fontVulkanZig.paintNumber(state.round, .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, fontVertices);
        paintVulkanZig.verticesForRectangle(levelPos.x + roundStartX - paddingX, levelPos.y - paddingY, textWidth - roundStartX + paddingX * 3, fontSize * onePixelYInVulkan + paddingY * 2, .{ 1, 1, 1 }, &verticeData.lines, &verticeData.triangles);
    }
}

fn verticsForTutorial(state: *main.GameState) void {
    const textColor: [3]f32 = .{ 1, 1, 1 };
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const fontVertices = &state.vkState.verticeData.font;
    if (state.tutorialData.active and state.tutorialData.firstKeyDownInput != null) {
        if (state.tutorialData.playerFirstValidMove or state.players.items.len > 1) {
            state.tutorialData.active = false;
        } else {
            const realTime = std.time.milliTimestamp();
            const fontSizeTutorial = 60;
            const height = fontSizeTutorial * onePixelYInVulkan;
            const hintWaitDelay = 10_000;
            if (state.tutorialData.firstKeyDownInput.? + hintWaitDelay < realTime) {
                var textWidth: f32 = 0;
                const left: comptime_float = -0.5;
                const top: f32 = 0 + height / 2;
                const player = &state.players.items[0];
                if (state.tutorialData.playerFirstValidPieceSelection == null) {
                    textWidth += fontVulkanZig.paintText("Press ", .{ .x = left + textWidth, .y = top }, fontSizeTutorial, textColor, fontVertices);
                    textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .pieceSelect1, fontSizeTutorial, player, state);
                    textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .pieceSelect2, fontSizeTutorial, player, state);
                    textWidth += fontVulkanZig.paintText("or ", .{ .x = left + textWidth, .y = top }, fontSizeTutorial, textColor, fontVertices);
                    textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .pieceSelect3, fontSizeTutorial, player, state);
                } else if (!state.tutorialData.playerFirstValidMove and state.tutorialData.playerFirstValidPieceSelection.? + hintWaitDelay < realTime) {
                    const inputDevice = inputZig.getPlayerInputDevice(player);
                    if (inputDevice == null or inputDevice.? == .keyboard) {
                        textWidth += fontVulkanZig.paintText("Press ", .{ .x = left + textWidth, .y = top }, fontSizeTutorial, textColor, fontVertices);
                        textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .moveUp, fontSizeTutorial, player, state);
                        textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .moveLeft, fontSizeTutorial, player, state);
                        textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .moveDown, fontSizeTutorial, player, state);
                        textWidth += fontVulkanZig.paintText("or ", .{ .x = left + textWidth, .y = top }, fontSizeTutorial, textColor, fontVertices);
                        textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .moveRight, fontSizeTutorial, player, state);
                    } else {
                        textWidth += fontVulkanZig.paintText("Use Analog Stick ", .{ .x = left + textWidth, .y = top }, fontSizeTutorial, textColor, fontVertices);
                    }
                }
            }
        }
    }
}

fn verticesForLeaveJoinInfo(state: *main.GameState) !void {
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    var counter: usize = 0;
    const realTime = std.time.milliTimestamp();
    const fontSize = 60;
    const height = fontSize * onePixelYInVulkan;
    const verticeData = &state.vkState.verticeData;
    const fontVertices = &state.vkState.verticeData.font;
    if (state.inputJoinData.inputDeviceDatas.items.len > 0) {
        const textColor: [3]f32 = .{ 0.1, 1, 0.1 };
        for (state.inputJoinData.inputDeviceDatas.items) |joinData| {
            if (joinData.pressTime + 1_000 <= realTime) {
                var textWidth: f32 = 0;
                const left: comptime_float = 0;
                const top: f32 = -0.99 + height * @as(f32, @floatFromInt(counter + 1)) * 1.1;
                textWidth += fontVulkanZig.paintText("Player ", .{ .x = left + textWidth, .y = top }, fontSize, textColor, fontVertices);
                textWidth += try fontVulkanZig.paintNumber(state.players.items.len + counter + 1, .{ .x = left + textWidth, .y = top }, fontSize, textColor, fontVertices);
                textWidth += fontVulkanZig.paintText(" joining", .{ .x = left + textWidth, .y = top }, fontSize, textColor, fontVertices);

                const fillPerCent = @as(f32, @floatFromInt(realTime - joinData.pressTime)) / @as(f32, @floatFromInt(playerZig.PLAYER_JOIN_BUTTON_HOLD_DURATION));
                paintVulkanZig.verticesForRectangle(left, top, textWidth * fillPerCent, height, .{ 0.9, 0.9, 0.9 }, null, &verticeData.triangles);
                paintVulkanZig.verticesForRectangle(left, top, textWidth, height, .{ 0.9, 0.9, 0.9 }, &verticeData.lines, null);
                counter += 1;
            }
        }
    }
    for (state.players.items, 0..) |*player, index| {
        const textColor: [3]f32 = .{ 0.7, 0, 0 };
        if (player.inputData.holdingKeySinceForLeave != null and player.inputData.holdingKeySinceForLeave.? + 1_000 <= realTime) {
            var textWidth: f32 = 0;
            const left: comptime_float = 0;
            const top: f32 = -0.99 + height * @as(f32, @floatFromInt(counter + 1)) * 1.1;
            textWidth += fontVulkanZig.paintText("Player ", .{ .x = left + textWidth, .y = top }, fontSize, textColor, fontVertices);
            textWidth += try fontVulkanZig.paintNumber(index + 1, .{ .x = left + textWidth, .y = top }, fontSize, textColor, fontVertices);
            textWidth += fontVulkanZig.paintText(" leaving", .{ .x = left + textWidth, .y = top }, fontSize, textColor, fontVertices);

            const fillPerCent = @as(f32, @floatFromInt(realTime - player.inputData.holdingKeySinceForLeave.?)) / @as(f32, @floatFromInt(playerZig.PLAYER_JOIN_BUTTON_HOLD_DURATION));
            const fillWidth = textWidth * fillPerCent;
            paintVulkanZig.verticesForRectangle(left + textWidth - fillWidth, top, fillWidth, height, .{ 0.1, 0.1, 0.1 }, null, &verticeData.triangles);
            paintVulkanZig.verticesForRectangle(left, top, textWidth, height, .{ 0.1, 0.1, 0.1 }, &verticeData.lines, null);
            counter += 1;
        }
    }
}

fn setupVerticesBossHpBar(boss: *bossZig.Boss, top: f32, left: f32, height: f32, width: f32, state: *main.GameState) !void {
    const textColor: [3]f32 = .{ 1, 1, 1 };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const fontSize = height / onePixelYInVulkan;
    const verticeData = &state.vkState.verticeData;
    const fontVertices = &verticeData.font;
    var textWidthRound = left;
    textWidthRound += fontVulkanZig.paintText(boss.name, .{ .x = textWidthRound, .y = top }, fontSize, textColor, fontVertices) + onePixelXInVulkan * 20;
    textWidthRound += try fontVulkanZig.paintNumber(boss.hp, .{ .x = textWidthRound, .y = top }, fontSize, textColor, fontVertices);
    textWidthRound += fontVulkanZig.paintText("/", .{ .x = textWidthRound, .y = top }, fontSize, textColor, fontVertices);
    textWidthRound += try fontVulkanZig.paintNumber(boss.maxHp, .{ .x = textWidthRound, .y = top }, fontSize, textColor, fontVertices);

    const fillPerCent = @as(f32, @floatFromInt(boss.hp)) / @as(f32, @floatFromInt(boss.maxHp));
    paintVulkanZig.verticesForRectangle(left, top, width * fillPerCent, height, .{ 1, 0, 0 }, null, &verticeData.triangles);
    paintVulkanZig.verticesForRectangle(left, top, width, height, .{ 1, 0, 0 }, &verticeData.lines, null);
}
