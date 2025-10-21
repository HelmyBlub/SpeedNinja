const std = @import("std");
const main = @import("../main.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");
const movePieceZig = @import("../movePiece.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const imageZig = @import("../image.zig");
const inputZig = @import("../input.zig");
const playerZig = @import("../player.zig");

pub fn setupVertices(state: *main.GameState) !void {
    const verticeData = &state.vkState.verticeData;

    for (state.players.items) |*player| {
        verticesForMoveOptions(player, verticeData, state);
        try verticesForPlayerData(player, state);
        verticeForPlayerStateInfo(player, state);
    }
}

pub fn verticesForHoverInformation(state: *main.GameState) !void {
    const maxPlayerInfo = @min(4, state.players.items.len);
    for (0..maxPlayerInfo) |playerIndex| {
        const player = &state.players.items[playerIndex];
        if (main.isPositionInRectangle(state.vulkanMousePosition, player.uxData.infoRecDamage)) {
            const posX = if (player.uxData.infoRecDamage.pos.x < 0) player.uxData.infoRecDamage.pos.x + player.uxData.infoRecDamage.width else player.uxData.infoRecDamage.pos.x;
            fontVulkanZig.verticesForInfoBox(&[_][]const u8{
                "Damage",
                "Only relevant for bosses",
            }, .{ .x = posX, .y = player.uxData.infoRecDamage.pos.y }, player.uxData.infoRecDamage.pos.x < 0, state);
        } else if (main.isPositionInRectangle(state.vulkanMousePosition, player.uxData.infoRecHealth)) {
            const posX = if (player.uxData.infoRecHealth.pos.x < 0) player.uxData.infoRecHealth.pos.x + player.uxData.infoRecHealth.width else player.uxData.infoRecHealth.pos.x;
            fontVulkanZig.verticesForInfoBox(&[_][]const u8{
                "Health",
            }, .{ .x = posX, .y = player.uxData.infoRecHealth.pos.y }, player.uxData.infoRecDamage.pos.x < 0, state);
        } else if (main.isPositionInRectangle(state.vulkanMousePosition, player.uxData.infoRecMoney)) {
            const posX = if (player.uxData.infoRecMoney.pos.x < 0) player.uxData.infoRecMoney.pos.x + player.uxData.infoRecMoney.width else player.uxData.infoRecMoney.pos.x;
            fontVulkanZig.verticesForInfoBox(&[_][]const u8{
                "Money",
                "Can be spend in shop",
                "Gained when finishing rounds or beating bosses",
            }, .{ .x = posX, .y = player.uxData.infoRecMoney.pos.y }, player.uxData.infoRecDamage.pos.x < 0, state);
        } else if (main.isPositionInRectangle(state.vulkanMousePosition, player.uxData.infoRecMovePieceCount)) {
            const posX = if (player.uxData.infoRecMovePieceCount.pos.x < 0) player.uxData.infoRecMovePieceCount.pos.x + player.uxData.infoRecMovePieceCount.width else player.uxData.infoRecMovePieceCount.pos.x;
            fontVulkanZig.verticesForInfoBox(&[_][]const u8{
                "Remaining Move Piece Count",
                "Player takes damage when reaching 0",
                "Refreshes on doing or taking damage",
            }, .{ .x = posX, .y = player.uxData.infoRecMovePieceCount.pos.y }, player.uxData.infoRecDamage.pos.x < 0, state);
        } else if (main.isPositionInRectangle(state.vulkanMousePosition, player.uxData.infoRecMovePieces)) {
            const posX = if (player.uxData.infoRecMovePieces.pos.x < 0) player.uxData.infoRecMovePieces.pos.x + player.uxData.infoRecMovePieces.width else player.uxData.infoRecMovePieces.pos.x;
            fontVulkanZig.verticesForInfoBox(&[_][]const u8{
                "Player Move Pieces",
                "Moving through an enemy kills it",
                "Blue Square is initial position",
                "Visualizes how player would move if moving up",
                "Based on input direction it will move player by a rotated version",
            }, .{ .x = posX, .y = player.uxData.infoRecMovePieces.pos.y }, player.uxData.infoRecDamage.pos.x < 0, state);
        }
    }
}

fn verticeForPlayerStateInfo(player: *playerZig.Player, state: *main.GameState) void {
    if (player.isDead) {
        const red: [4]f32 = .{ 1, 0, 0, 1 };
        verticeForInfo(player, "Dead", red, state);
    } else if (player.phase == .shopping and state.gamePhase == .combat) {
        const white: [4]f32 = .{ 1, 1, 1, 1 };
        verticeForInfo(player, "Shop", white, state);
    }
}

fn verticeForInfo(player: *playerZig.Player, text: *const [4]u8, textColor: [4]f32, state: *main.GameState) void {
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;
    const fontSize = player.uxData.vulkanScale * state.windowData.heightFloat / 12;
    _ = fontVulkanZig.paintText(text[0..1], .{
        .x = player.uxData.vulkanTopLeft.x,
        .y = player.uxData.vulkanTopLeft.y + onePixelYInVulkan * fontSize,
    }, fontSize, textColor, state);
    _ = fontVulkanZig.paintText(text[1..2], .{
        .x = player.uxData.vulkanTopLeft.x,
        .y = player.uxData.vulkanTopLeft.y + onePixelYInVulkan * fontSize * 2,
    }, fontSize, textColor, state);
    _ = fontVulkanZig.paintText(text[2..3], .{
        .x = player.uxData.vulkanTopLeft.x,
        .y = player.uxData.vulkanTopLeft.y + onePixelYInVulkan * fontSize * 3,
    }, fontSize, textColor, state);
    _ = fontVulkanZig.paintText(text[3..4], .{
        .x = player.uxData.vulkanTopLeft.x,
        .y = player.uxData.vulkanTopLeft.y + onePixelYInVulkan * fontSize * 4,
    }, fontSize, textColor, state);
}

fn verticesForPlayerData(player: *playerZig.Player, state: *main.GameState) !void {
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;
    var vulkanPos: main.Position = player.uxData.vulkanTopLeft;
    var height: f32 = 0;
    const spacingFactor = 1.1;
    height = player.uxData.vulkanScale / 4 / spacingFactor;
    const fontSize = height / 4 / onePixelYInVulkan;
    const pieceYSpacing = height * spacingFactor;
    vulkanPos.y += pieceYSpacing * 3;
    try verticesForPlayerPieceCounter(vulkanPos, fontSize, player, state);
    try verticesForPlayerDamage(vulkanPos, fontSize, player, state);
    try verticesForPlayerHp(vulkanPos, fontSize, player, state);
    try verticesForPlayerMoney(vulkanPos, fontSize, player, state);
}

fn verticesForPlayerDamage(vulkanPos: main.Position, fontSize: f32, player: *playerZig.Player, state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const onePixelXInVulkan = 2 / state.windowData.widthFloat;
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;
    const damageDisplayTextPos: main.Position = .{
        .x = vulkanPos.x + fontSize * onePixelXInVulkan,
        .y = vulkanPos.y + fontSize * onePixelYInVulkan,
    };
    const playerTotalDamage = playerZig.getPlayerDamage(player);
    const playerWeaponDamage = player.damage;
    const bonusDamage = playerTotalDamage - playerWeaponDamage;
    var damageTextWidth: f32 = 0;
    damageTextWidth += try fontVulkanZig.paintNumber(playerWeaponDamage, damageDisplayTextPos, fontSize, textColor, state);
    if (bonusDamage > 0) {
        damageTextWidth += fontVulkanZig.paintText("+", .{
            .x = damageDisplayTextPos.x + damageTextWidth,
            .y = damageDisplayTextPos.y,
        }, fontSize, textColor, state);
        damageTextWidth += try fontVulkanZig.paintNumber(bonusDamage, .{
            .x = damageDisplayTextPos.x + damageTextWidth,
            .y = damageDisplayTextPos.y,
        }, fontSize, textColor, state);
    }
    const damageDisplayIconPos: main.Position = .{
        .x = damageDisplayTextPos.x - onePixelXInVulkan * fontSize / 2,
        .y = damageDisplayTextPos.y + onePixelYInVulkan * fontSize / 2,
    };
    paintVulkanZig.verticesForComplexSpriteVulkan(
        damageDisplayIconPos,
        imageZig.IMAGE_ICON_DAMAGE,
        fontSize,
        fontSize,
        1,
        0,
        false,
        false,
        state,
    );
    player.uxData.infoRecDamage = .{ .pos = .{
        .x = vulkanPos.x,
        .y = damageDisplayTextPos.y,
    }, .width = damageTextWidth + fontSize * onePixelXInVulkan + 5 * onePixelXInVulkan, .height = fontSize * onePixelYInVulkan };
}

fn verticesForPlayerHp(vulkanPos: main.Position, fontSize: f32, player: *playerZig.Player, state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const onePixelXInVulkan = 2 / state.windowData.widthFloat;
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;
    const hpDisplayTextPos: main.Position = .{
        .x = vulkanPos.x + onePixelXInVulkan * fontSize * 0.3,
        .y = vulkanPos.y + fontSize * onePixelYInVulkan * 2,
    };
    const playerHp = playerZig.getPlayerTotalHp(player);
    var width = try fontVulkanZig.paintNumber(playerHp, hpDisplayTextPos, fontSize * 0.8, textColor, state);
    const hpDisplayIconPos: main.Position = .{
        .x = hpDisplayTextPos.x + onePixelXInVulkan * fontSize / 4,
        .y = hpDisplayTextPos.y + onePixelYInVulkan * fontSize / 3,
    };
    paintVulkanZig.verticesForComplexSpriteVulkan(
        hpDisplayIconPos,
        imageZig.IMAGE_ICON_HP,
        fontSize * 1.3,
        fontSize * 1.3,
        1,
        0,
        false,
        false,
        state,
    );
    if (player.uxData.visualizeHpChange) |hpChange| {
        if (player.uxData.visualizeHpChangeUntil == null) player.uxData.visualizeHpChangeUntil = state.gameTime + player.uxData.visualizationDuration;
        if (player.uxData.visualizeHpChangeUntil.? > state.gameTime and hpChange != 0) {
            const red: [4]f32 = .{ 0.7, 0, 0, 1 };
            const green: [4]f32 = .{ 0.1, 1, 0.1, 1 };
            var color = red;
            if (hpChange >= 0) {
                color = green;
                width += fontVulkanZig.paintText("+", .{
                    .x = hpDisplayTextPos.x + width,
                    .y = hpDisplayTextPos.y,
                }, fontSize, color, state);
            }
            width += try fontVulkanZig.paintNumber(hpChange, .{
                .x = hpDisplayTextPos.x + width,
                .y = hpDisplayTextPos.y,
            }, fontSize, color, state);
        } else {
            player.uxData.visualizeHpChange = null;
        }
    }
    player.uxData.infoRecHealth = .{ .pos = .{
        .x = vulkanPos.x,
        .y = hpDisplayTextPos.y,
    }, .width = width + fontSize * onePixelXInVulkan + 5 * onePixelXInVulkan, .height = fontSize * onePixelYInVulkan };
}

fn verticesForPlayerMoney(vulkanPos: main.Position, fontSize: f32, player: *playerZig.Player, state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const onePixelXInVulkan = 2 / state.windowData.widthFloat;
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;
    const moneyDisplayTextPos: main.Position = .{
        .x = vulkanPos.x,
        .y = vulkanPos.y + fontSize * onePixelYInVulkan * 3,
    };
    var moneyTextWidth = fontVulkanZig.paintText("$", moneyDisplayTextPos, fontSize, textColor, state);
    moneyTextWidth += try fontVulkanZig.paintNumber(player.money, .{
        .x = moneyDisplayTextPos.x + moneyTextWidth,
        .y = moneyDisplayTextPos.y,
    }, fontSize, textColor, state);
    if (player.uxData.visualizeMoney) |moneyChange| {
        if (player.uxData.visualizeMoneyUntil == null) player.uxData.visualizeMoneyUntil = state.gameTime + player.uxData.visualizationDuration;
        if (player.uxData.visualizeMoneyUntil.? > state.gameTime) {
            const red: [4]f32 = .{ 0.7, 0, 0, 1 };
            const green: [4]f32 = .{ 0.1, 1, 0.1, 1 };
            var color = red;
            if (moneyChange >= 0) {
                color = green;
                moneyTextWidth += fontVulkanZig.paintText("+", .{
                    .x = moneyDisplayTextPos.x + moneyTextWidth,
                    .y = moneyDisplayTextPos.y,
                }, fontSize, color, state);
            }
            moneyTextWidth += try fontVulkanZig.paintNumber(moneyChange, .{
                .x = moneyDisplayTextPos.x + moneyTextWidth,
                .y = moneyDisplayTextPos.y,
            }, fontSize, color, state);
        } else {
            player.uxData.visualizeMoney = null;
        }
    }
    player.uxData.infoRecMoney = .{ .pos = .{
        .x = vulkanPos.x,
        .y = moneyDisplayTextPos.y,
    }, .width = moneyTextWidth + fontSize * onePixelXInVulkan + 5 * onePixelXInVulkan, .height = fontSize * onePixelYInVulkan };
}

fn verticesForPlayerPieceCounter(vulkanPos: main.Position, fontSize: f32, player: *playerZig.Player, state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const onePixelXInVulkan = 2 / state.windowData.widthFloat;
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;
    const iconPos: main.Position = .{
        .x = vulkanPos.x + onePixelXInVulkan * fontSize / 2,
        .y = vulkanPos.y + onePixelYInVulkan * fontSize / 2,
    };
    paintVulkanZig.verticesForComplexSpriteVulkan(
        iconPos,
        imageZig.IMAGE_ICON_MOVE_PIECE,
        fontSize,
        fontSize,
        1,
        0,
        false,
        false,
        state,
    );
    const textPosX: f32 = iconPos.x + onePixelXInVulkan * fontSize / 2;
    var width: f32 = 0;
    if (state.gamePhase == .shopping) {
        const totalPieces = player.totalMovePieces.items.len;
        width = try fontVulkanZig.paintNumber(totalPieces, .{ .x = textPosX, .y = vulkanPos.y }, fontSize, textColor, state);
    } else {
        const remainingPieces = player.availableMovePieces.items.len + player.moveOptions.items.len;
        width = try fontVulkanZig.paintNumber(remainingPieces, .{ .x = textPosX, .y = vulkanPos.y }, fontSize, textColor, state);
    }
    if (player.uxData.piecesRefreshedVisualization != null and player.uxData.piecesRefreshedVisualization.? + player.uxData.visualizationDuration >= state.gameTime) {
        const refreshIconPos: main.Position = .{
            .x = textPosX + onePixelXInVulkan * fontSize / 2 + width,
            .y = vulkanPos.y + onePixelYInVulkan * fontSize / 2,
        };
        const rotation: f32 = @as(f32, @floatFromInt(state.gameTime - player.uxData.visualizationDuration)) / 200;
        paintVulkanZig.verticesForComplexSpriteVulkan(
            refreshIconPos,
            imageZig.IMAGE_ICON_REFRESH,
            fontSize,
            fontSize,
            1,
            rotation,
            false,
            false,
            state,
        );
    } else if (player.uxData.visualizeMovePieceChangeFromShop) |change| {
        const red: [4]f32 = .{ 0.7, 0, 0, 1 };
        const green: [4]f32 = .{ 0.1, 1, 0.1, 1 };
        var color = red;
        if (change >= 0) {
            color = green;
            width += fontVulkanZig.paintText("+", .{
                .x = textPosX + width,
                .y = vulkanPos.y,
            }, fontSize, color, state);
        }
        _ = try fontVulkanZig.paintNumber(change, .{
            .x = textPosX + width,
            .y = vulkanPos.y,
        }, fontSize, color, state);
        if (player.uxData.visualizeMoney == null) player.uxData.visualizeMovePieceChangeFromShop = null;
    }
    player.uxData.infoRecMovePieceCount = .{ .pos = .{
        .x = vulkanPos.x,
        .y = vulkanPos.y,
    }, .width = width + fontSize * onePixelXInVulkan + 5 * onePixelXInVulkan, .height = fontSize * onePixelYInVulkan };
}

fn verticesForMoveOptions(player: *playerZig.Player, verticeData: *dataVulkanZig.VkVerticeData, state: *main.GameState) void {
    const onePixelXInVulkan = 2 / state.windowData.widthFloat;
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;
    var width: f32 = 0;
    var height: f32 = 0;
    const spacingFactor = 1.1;
    const playerInputDevice = inputZig.getPlayerInputDevice(player);
    const verticesForMovementKey = if (player.uxData.visualizeMovementKeys and (playerInputDevice == null or playerInputDevice.? == .keyboard)) true else false;
    height = player.uxData.vulkanScale / 4 / spacingFactor;
    width = height / onePixelYInVulkan * onePixelXInVulkan;
    if (verticesForMovementKey) {
        width *= 3.0 / 4.0;
        height *= 3.0 / 4.0;
    }

    const startX = player.uxData.vulkanTopLeft.x;
    var startY = player.uxData.vulkanTopLeft.y + height * ((spacingFactor - 1) * 0.5);

    const gameInfoTopHeight = (30 * state.uxData.settingsMenuUx.uiSizeDelayed + 10) * onePixelYInVulkan;
    const gameInfoLeftWidth = 200 * onePixelYInVulkan;
    if (startY < -1 + gameInfoTopHeight and startX < -1 + gameInfoLeftWidth) {
        const cutAmount = -1 + gameInfoTopHeight - startY;
        startY = -1 + gameInfoTopHeight;
        height -= cutAmount / 3;
    }
    const pieceYSpacing = height * spacingFactor;

    const fontSize = height / 4 / onePixelYInVulkan;
    if (verticesForMovementKey) {
        var keyDisplayWidth: f32 = 0;
        const keyFontSize = fontSize * 1.3;
        const keyY = startY + keyFontSize * onePixelYInVulkan * 1.3;
        keyDisplayWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = startX, .y = keyY }, .moveLeft, keyFontSize, player, state);
        _ = fontVulkanZig.verticesForDisplayButton(.{ .x = startX + keyDisplayWidth, .y = keyY - keyFontSize * onePixelYInVulkan }, .moveUp, keyFontSize, player, state);
        keyDisplayWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = startX + keyDisplayWidth, .y = keyY }, .moveDown, keyFontSize, player, state);
        keyDisplayWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = startX + keyDisplayWidth, .y = keyY }, .moveRight, keyFontSize, player, state);
        startY += pieceYSpacing;
    }

    const lines = &verticeData.lines;
    const triangles = &verticeData.triangles;
    const fillColor: [4]f32 = .{ 0.25, 0.25, 0.25, 1 };
    const selctedColor: [4]f32 = .{ 0.07, 0.07, 0.07, 1 };
    player.uxData.infoRecMovePieces = .{ .pos = .{ .x = startX, .y = startY }, .width = width, .height = pieceYSpacing * 3 };
    for (0..3) |index| {
        if (player.moveOptions.items.len <= index) {
            paintVulkanZig.verticesForRectangle(startX, startY, width, height, .{ 0.8, 0, 0, 1 }, lines, triangles);
        } else {
            const option = player.moveOptions.items[index];
            const boundingBox = movePieceZig.getBoundingBox(option);
            var rectPieceFillColor = fillColor;
            var rectFillColor: [4]f32 = .{ 1.0, 1.0, 1.0, 1 };
            if (!player.isDead and player.choosenMoveOptionIndex != null and player.choosenMoveOptionIndex.? == index) {
                rectPieceFillColor = selctedColor;
                rectFillColor = .{ 0.2, 0.2, 0.8, 1 };
            }
            if (player.equipment.hasEyePatch and index != 0) {
                rectFillColor[3] = 0.5;
                rectPieceFillColor[3] = 0.5;
            }
            paintVulkanZig.verticesForRectangle(startX, startY, width, height, rectFillColor, lines, triangles);
            var pieceDownScale: f32 = 4;
            if (boundingBox.width > 4 or boundingBox.height > 4) {
                pieceDownScale = @floatFromInt(@max(boundingBox.height, boundingBox.width));
            }
            const stepWidth = width / pieceDownScale;
            const stepHeight = height / pieceDownScale;
            var offsetX: f32 = @as(f32, @floatFromInt(boundingBox.pos.x)) * stepWidth;
            var offsetY: f32 = @as(f32, @floatFromInt(boundingBox.pos.y)) * stepHeight;
            if (pieceDownScale > @as(f32, @floatFromInt(boundingBox.width))) {
                const diffX = pieceDownScale - @as(f32, @floatFromInt(boundingBox.width));
                offsetX -= diffX / 2 * stepWidth;
            }
            if (pieceDownScale > @as(f32, @floatFromInt(boundingBox.height))) {
                const diffY = pieceDownScale - @as(f32, @floatFromInt(boundingBox.height));
                offsetY -= diffY / 2 * stepHeight;
            }
            _ = verticesForMovePiece(
                option,
                rectPieceFillColor,
                startX - offsetX,
                startY - offsetY,
                stepWidth,
                stepHeight,
                0,
                false,
                lines,
                triangles,
            );
        }
        if (player.equipment.hasEyePatch) {
            if (index == 1 or index == 2) {
                const eyePatchData = imageZig.IMAGE_DATA[imageZig.IMAGE_EYEPATCH];
                const scale: f32 = 0.5;
                const eyePatchWidth = @as(f32, @floatFromInt(eyePatchData.width)) * scale;
                const eyePatchHeight = @as(f32, @floatFromInt(eyePatchData.height)) * scale;
                paintVulkanZig.verticesForComplexSpriteVulkan(
                    .{ .x = startX + eyePatchWidth / 2 * onePixelXInVulkan, .y = startY + eyePatchHeight / 2 * onePixelYInVulkan },
                    imageZig.IMAGE_EYEPATCH,
                    eyePatchWidth,
                    eyePatchHeight,
                    1,
                    0,
                    false,
                    false,
                    state,
                );
            }
        }
        if (player.uxData.visualizeChoiceKeys) {
            switch (index) {
                0 => {
                    _ = fontVulkanZig.verticesForDisplayButton(.{ .x = startX, .y = startY }, .pieceSelect1, fontSize, player, state);
                },
                1 => {
                    if (!player.equipment.hasEyePatch) {
                        _ = fontVulkanZig.verticesForDisplayButton(.{ .x = startX, .y = startY }, .pieceSelect2, fontSize, player, state);
                    }
                },
                else => {
                    if (!player.equipment.hasEyePatch) {
                        _ = fontVulkanZig.verticesForDisplayButton(.{ .x = startX, .y = startY }, .pieceSelect3, fontSize, player, state);
                    }
                },
            }
        }
        startY += pieceYSpacing;
    }
}

pub fn verticesForMovePiece(
    movePiece: movePieceZig.MovePiece,
    fillColor: [4]f32,
    vulkanX: f32,
    vulkanY: f32,
    vulkanTileWidth: f32,
    vulkanTileHeight: f32,
    direction: u8,
    skipInitialRect: bool,
    lines: *dataVulkanZig.VkColoredVertexes,
    triangles: *dataVulkanZig.VkColoredVertexes,
) struct { x: f32, y: f32 } {
    var x: f32 = vulkanX;
    var y: f32 = vulkanY;
    var sizeFactor: f32 = 1;
    const factor = 0.9;
    if (!skipInitialRect) paintVulkanZig.verticesForRectangle(x, y, vulkanTileWidth, vulkanTileHeight, .{ 0.0, 0.0, 1, fillColor[3] }, lines, triangles);
    for (movePiece.steps) |step| {
        const modStepDirection = @mod(step.direction + direction, 4);
        const stepDirection = movePieceZig.getStepDirection(modStepDirection);
        sizeFactor *= factor;
        for (0..step.stepCount) |i| {
            x += stepDirection.x * vulkanTileWidth;
            y += stepDirection.y * vulkanTileHeight;
            var modWidth = vulkanTileWidth;
            var modHeight = vulkanTileHeight;
            var tempX = x;
            var tempY = y;
            switch (modStepDirection) {
                movePieceZig.DIRECTION_RIGHT => {
                    modHeight *= sizeFactor;
                    const offsetBasedOnSizeFactor = vulkanTileWidth * (1 - sizeFactor) / 2;
                    tempX -= offsetBasedOnSizeFactor;
                    tempY += vulkanTileHeight * (1 - sizeFactor) / 2;
                    if (i == 0) {
                        const offsetBasedOnOldSizeFactor = vulkanTileWidth * (1 - sizeFactor / factor) / 2;
                        tempX -= offsetBasedOnOldSizeFactor - offsetBasedOnSizeFactor;
                        modWidth -= offsetBasedOnSizeFactor - offsetBasedOnOldSizeFactor;
                    }
                },
                movePieceZig.DIRECTION_LEFT => {
                    modHeight *= sizeFactor;
                    const offsetBasedOnSizeFactor = vulkanTileWidth * (1 - sizeFactor) / 2;
                    tempX += offsetBasedOnSizeFactor;
                    tempY += vulkanTileHeight * (1 - sizeFactor) / 2;
                    if (i == 0) {
                        const offsetBasedOnOldSizeFactor = vulkanTileWidth * (1 - sizeFactor / factor) / 2;
                        modWidth -= offsetBasedOnSizeFactor - offsetBasedOnOldSizeFactor;
                    }
                },
                movePieceZig.DIRECTION_UP => {
                    modWidth *= sizeFactor;
                    tempX += vulkanTileWidth * (1 - sizeFactor) / 2;
                    const offsetBasedOnSizeFactor = (vulkanTileHeight * (1 - sizeFactor) / 2.0);
                    tempY += offsetBasedOnSizeFactor;
                    if (i == 0) {
                        const offsetBasedOnOldSizeFactor = (vulkanTileHeight * (1 - sizeFactor / factor) / 2.0);
                        modHeight -= offsetBasedOnSizeFactor - offsetBasedOnOldSizeFactor;
                    }
                },
                else => {
                    modWidth *= sizeFactor;
                    const offsetBasedOnSizeFactor = (vulkanTileHeight * (1 - sizeFactor) / 2.0);
                    tempX += vulkanTileWidth * (1 - sizeFactor) / 2;
                    tempY -= offsetBasedOnSizeFactor;
                    if (i == 0) {
                        const offsetBasedOnOldSizeFactor = vulkanTileHeight * (1 - sizeFactor / factor) / 2;
                        tempY -= offsetBasedOnOldSizeFactor - offsetBasedOnSizeFactor;
                        modHeight -= offsetBasedOnSizeFactor - offsetBasedOnOldSizeFactor;
                    }
                },
            }

            paintVulkanZig.verticesForRectangle(tempX, tempY, modWidth, modHeight, fillColor, lines, triangles);
        }
    }
    return .{ .x = x, .y = y };
}
