const std = @import("std");
const main = @import("../main.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");
const movePieceZig = @import("../movePiece.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const imageZig = @import("../image.zig");

const INITIAL_PIECE_COLOR: [3]f32 = .{ 0.0, 0.0, 1 };

pub fn setupVertices(state: *main.GameState) !void {
    const verticeData = &state.vkState.verticeData;

    for (state.players.items) |*player| {
        verticesForMoveOptions(player, verticeData);
        try verticesForPlayerData(player, verticeData, state);
    }
}

fn verticesForPlayerData(player: *main.Player, verticeData: *dataVulkanZig.VkVerticeData, state: *main.GameState) !void {
    const textColor: [3]f32 = .{ 1, 1, 1 };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;

    var vulkanPos: main.Position = player.uxData.vulkanTopLeft;
    var width: f32 = 0;
    var height: f32 = 0;
    const spacingFactor = 1.1;
    if (player.uxData.vertical) {
        height = player.uxData.vulkanScale / 4 / spacingFactor;
        width = height / onePixelYInVulkan * onePixelXInVulkan;
    } else {
        width = player.uxData.vulkanScale / 4 / spacingFactor;
        height = width / onePixelXInVulkan * onePixelYInVulkan;
    }
    const fontSize = height / 4 / onePixelYInVulkan;
    if (player.uxData.vertical) {
        const pieceYSpacing = height * spacingFactor;
        vulkanPos.y += pieceYSpacing * 3;
    } else {
        const pieceXSpacing = width * spacingFactor;
        vulkanPos.x += pieceXSpacing * 3;
    }
    try verticesForPlayerPieceCounter(vulkanPos, fontSize, player, verticeData, state);
    const damageDisplayTextPos: main.Position = .{
        .x = vulkanPos.x + fontSize * onePixelXInVulkan,
        .y = vulkanPos.y + fontSize * onePixelYInVulkan,
    };
    const playerTotalDamage = main.getPlayerDamage(player);
    const playerWeaponDamage = player.damage;
    const bonusDamage = playerTotalDamage - playerWeaponDamage;
    var damageTextWidth: f32 = 0;
    damageTextWidth += try fontVulkanZig.paintNumber(playerWeaponDamage, damageDisplayTextPos, fontSize, textColor, &verticeData.font);
    if (bonusDamage > 0) {
        damageTextWidth += fontVulkanZig.paintText("+", .{
            .x = damageDisplayTextPos.x + damageTextWidth,
            .y = damageDisplayTextPos.y,
        }, fontSize, textColor, &verticeData.font);
        _ = try fontVulkanZig.paintNumber(bonusDamage, .{
            .x = damageDisplayTextPos.x + damageTextWidth,
            .y = damageDisplayTextPos.y,
        }, fontSize, textColor, &verticeData.font);
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

    const hpDisplayTextPos: main.Position = .{
        .x = vulkanPos.x + onePixelXInVulkan * fontSize * 0.3,
        .y = vulkanPos.y + fontSize * onePixelYInVulkan * 2,
    };
    const playerHp = main.getPlayerTotalHp(player);
    _ = try fontVulkanZig.paintNumber(playerHp, hpDisplayTextPos, fontSize * 0.8, textColor, &verticeData.font);
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
    const moneyDisplayTextPos: main.Position = .{
        .x = vulkanPos.x,
        .y = vulkanPos.y + fontSize * onePixelYInVulkan * 3,
    };
    const moneyTextWidth = fontVulkanZig.paintText("$", moneyDisplayTextPos, fontSize, textColor, &verticeData.font);
    _ = try fontVulkanZig.paintNumber(player.money, .{
        .x = moneyDisplayTextPos.x + moneyTextWidth,
        .y = moneyDisplayTextPos.y,
    }, fontSize, textColor, &verticeData.font);
}

fn verticesForPlayerPieceCounter(vulkanPos: main.Position, fontSize: f32, player: *main.Player, verticeData: *dataVulkanZig.VkVerticeData, state: *main.GameState) !void {
    const textColor: [3]f32 = .{ 1, 1, 1 };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
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
        width = try fontVulkanZig.paintNumber(totalPieces, .{ .x = textPosX, .y = vulkanPos.y }, fontSize, textColor, &verticeData.font);
    } else {
        const remainingPieces = player.availableMovePieces.items.len + player.moveOptions.items.len;
        width = try fontVulkanZig.paintNumber(remainingPieces, .{ .x = textPosX, .y = vulkanPos.y }, fontSize, textColor, &verticeData.font);
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
    }
}

fn verticesForMoveOptions(player: *main.Player, verticeData: *dataVulkanZig.VkVerticeData) void {
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    var width: f32 = 0;
    var height: f32 = 0;
    const spacingFactor = 1.1;
    if (player.uxData.vertical) {
        height = player.uxData.vulkanScale / 4 / spacingFactor;
        width = height / onePixelYInVulkan * onePixelXInVulkan;
    } else {
        width = player.uxData.vulkanScale / 4 / spacingFactor;
        height = width / onePixelXInVulkan * onePixelYInVulkan;
    }

    const pieceXSpacing = width * spacingFactor;
    const pieceYSpacing = height * spacingFactor;
    var startX = player.uxData.vulkanTopLeft.x;
    var startY = player.uxData.vulkanTopLeft.y;

    const lines = &verticeData.lines;
    const triangles = &verticeData.triangles;
    const fillColor: [3]f32 = .{ 0.25, 0.25, 0.25 };
    const selctedColor: [3]f32 = .{ 0.07, 0.07, 0.07 };
    for (0..3) |index| {
        if (player.moveOptions.items.len <= index) {
            paintVulkanZig.verticesForRectangle(startX, startY, width, height, .{ 0.8, 0, 0 }, lines, triangles);
        } else {
            const option = player.moveOptions.items[index];
            const boundingBox = movePieceZig.getBoundingBox(option);
            var rectPieceFillColor = fillColor;
            var rectFillColor: [3]f32 = .{ 1.0, 1.0, 1.0 };
            if (player.choosenMoveOptionIndex != null and player.choosenMoveOptionIndex.? == index) {
                rectPieceFillColor = selctedColor;
                rectFillColor = .{ 0.2, 0.2, 0.8 };
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
        if (player.uxData.vertical) {
            startY += pieceYSpacing;
        } else {
            startX += pieceXSpacing;
        }
    }
}

pub fn verticesForMovePiece(
    movePiece: movePieceZig.MovePiece,
    fillColor: [3]f32,
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
    if (!skipInitialRect) paintVulkanZig.verticesForRectangle(x, y, vulkanTileWidth, vulkanTileHeight, INITIAL_PIECE_COLOR, lines, triangles);
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
