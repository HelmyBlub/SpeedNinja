const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const dataVulkanZig = @import("dataVulkan.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const movePieceZig = @import("../movePiece.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const shopZig = @import("../shop.zig");
const playerUxVulkanZig = @import("playerUxVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const equipmentZig = @import("../equipment.zig");
const playerZig = @import("../player.zig");

pub fn setupVertices(state: *main.GameState) !void {
    if (state.gamePhase != .shopping) return;
    try verticesForMovePieceModifications(state);
    try verticesForBuyOptions(state);
    try verticesForExitShop(state);
    try verticesForAfk(state);
}

fn verticesForAfk(state: *main.GameState) !void {
    if (state.players.items.len <= 1) return;
    var afkPlayerCount: u32 = 0;
    const fontSize = 12;
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    for (state.players.items) |player| {
        if (player.inputData.lastInputTime + shopZig.SHOP_AFK_TIMER < state.gameTime) {
            afkPlayerCount += 1;
            _ = fontVulkanZig.paintTextGameMap("AFK", .{
                .x = player.position.x,
                .y = player.position.y,
            }, fontSize, textColor, state);
        }
    }
    if (afkPlayerCount > 0) {
        const tileRectangle = state.shop.afkKickArea;
        const onePixelXInVulkan = 2 / state.windowData.widthFloat;
        const onePixelYInVulkan = 2 / state.windowData.heightFloat;
        const kickAfkTopLeft: main.Position = .{
            .x = @floatFromInt(tileRectangle.pos.x * main.TILESIZE),
            .y = @floatFromInt(tileRectangle.pos.y * main.TILESIZE),
        };
        const vulkan: main.Position = .{
            .x = (-state.camera.position.x + kickAfkTopLeft.x) * state.camera.zoom * onePixelXInVulkan,
            .y = (-state.camera.position.y + kickAfkTopLeft.y) * state.camera.zoom * onePixelYInVulkan,
        };
        const halveVulkanTileSizeX = main.TILESIZE * onePixelXInVulkan * state.camera.zoom / 2;
        const halveVulkanTileSizeY = main.TILESIZE * onePixelYInVulkan * state.camera.zoom / 2;
        const width = main.TILESIZE * shopZig.EARLY_SHOP_GRID_SIZE * onePixelXInVulkan * state.camera.zoom;
        const height = main.TILESIZE * shopZig.EARLY_SHOP_GRID_SIZE * onePixelYInVulkan * state.camera.zoom;
        const left = vulkan.x - halveVulkanTileSizeX;
        const top = vulkan.y - halveVulkanTileSizeY;

        paintVulkanZig.verticesForRectangle(left, top, width, height, .{ 1, 1, 1, 1 }, &state.vkState.verticeData.lines, null);
        if (state.shop.kickStartTime) |kickStartTime| {
            const fillPerCent: f32 = @as(f32, @floatFromInt(state.gameTime - kickStartTime)) / @as(f32, @floatFromInt(state.shop.durationToKick));
            paintVulkanZig.verticesForRectangle(left, top, width * fillPerCent, height, .{ 0, 0, 0, 1 }, null, &state.vkState.verticeData.triangles);
        }

        _ = fontVulkanZig.paintTextGameMap("KICK", .{
            .x = kickAfkTopLeft.x - main.TILESIZE / 2,
            .y = kickAfkTopLeft.y - main.TILESIZE / 2,
        }, fontSize, textColor, state);
        _ = fontVulkanZig.paintTextGameMap("AFK", .{
            .x = kickAfkTopLeft.x - main.TILESIZE / 2,
            .y = kickAfkTopLeft.y - main.TILESIZE / 2 + fontSize,
        }, fontSize, textColor, state);

        if (state.players.items.len > 1) {
            const textPos: main.Position = .{
                .x = kickAfkTopLeft.x - main.TILESIZE / 2,
                .y = kickAfkTopLeft.y - main.TILESIZE / 2 - fontSize,
            };
            var textWidth: f32 = 0;
            textWidth += try fontVulkanZig.paintNumberGameMap(state.shop.playersOnAfkKick, textPos, fontSize, textColor, state);
            textWidth += fontVulkanZig.paintTextGameMap("/", .{
                .x = textPos.x + textWidth,
                .y = textPos.y,
            }, fontSize, textColor, state);
            textWidth += try fontVulkanZig.paintNumberGameMap(state.players.items.len - afkPlayerCount, .{
                .x = textPos.x + textWidth,
                .y = textPos.y,
            }, fontSize, textColor, state);
            paintVulkanZig.verticesForComplexSprite(
                .{ .x = textPos.x + textWidth + fontSize, .y = textPos.y + fontSize / 2 },
                imageZig.IMAGE_CHECKMARK,
                3,
                3,
                1,
                0,
                false,
                false,
                state,
            );
        }
    }
}

fn verticesForExitShop(state: *main.GameState) !void {
    const text: ?[]const u8 = if (@mod(state.level, 5) == 4) "Boss" else null;
    try paintVulkanZig.verticesForStairsWithText(state.shop.exitShopArea, text, state.shop.playersOnExit, state);
}

fn verticesForMovePieceModifications(state: *main.GameState) !void {
    const verticeData = &state.vkState.verticeData;
    for (state.players.items) |*player| {
        try paintGrid(player, state);
        if (player.shop.pieceShopTopLeft == null) continue;
        const playerShopPos = player.shop.pieceShopTopLeft.?;
        for (shopZig.SHOP_BUTTONS) |shopButton| {
            if (shopButton.isVisible != null and !shopButton.isVisible.?(player)) continue;
            const shopButtonGamePosition: main.Position = .{
                .x = @floatFromInt((playerShopPos.x + shopButton.tileOffset.x) * main.TILESIZE),
                .y = @floatFromInt((playerShopPos.y + shopButton.tileOffset.y) * main.TILESIZE),
            };
            if (shopButton.option != .none and shopButton.option == player.shop.selectedOption) {
                rectangleForTile(shopButtonGamePosition, .{ 0, 0, 1, 1 }, verticeData, false, state);
            }
            if (shopButton.moreVerticeSetups) |moreVertices| try moreVertices(player, shopButton, state);
            var alpha: f32 = 1;
            if (shopButton.getAlpha != null) alpha = shopButton.getAlpha.?(player);
            if (shopButton.imageRotate != 0) {
                paintVulkanZig.verticesForComplexSpriteWithRotate(shopButtonGamePosition, shopButton.imageIndex, shopButton.imageRotate, alpha, state);
            } else {
                paintVulkanZig.verticesForComplexSprite(shopButtonGamePosition, shopButton.imageIndex, 1, 1, alpha, 0, false, false, state);
            }
        }
    }
}

fn verticesForBuyOptions(state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    for (state.shop.buyOptions.items) |buyOption| {
        const buyOptionGamePosition: main.Position = .{
            .x = @floatFromInt(buyOption.tilePosition.x * main.TILESIZE),
            .y = @floatFromInt(buyOption.tilePosition.y * main.TILESIZE),
        };
        var moneyDisplayPos: main.Position = .{
            .x = buyOptionGamePosition.x - main.TILESIZE / 2,
            .y = buyOptionGamePosition.y - main.TILESIZE / 4,
        };
        const fontSize = 7;
        if (buyOption.price > 0) {
            paintVulkanZig.verticesForComplexSprite(buyOptionGamePosition, imageZig.IMAGE_SHOP_PODEST, 1.5, 1.5, 1, 0, false, false, state);
            paintVulkanZig.verticesForComplexSprite(.{
                .x = buyOptionGamePosition.x,
                .y = buyOptionGamePosition.y - main.TILESIZE / 2 - 4,
            }, buyOption.imageIndex, buyOption.imageScale, buyOption.imageScale, 1, 0, false, false, state);
            moneyDisplayPos.x += fontVulkanZig.paintTextGameMap("$", moneyDisplayPos, fontSize, textColor, state);
            _ = try fontVulkanZig.paintNumberGameMap(buyOption.price, moneyDisplayPos, fontSize, textColor, state);
        } else {
            paintVulkanZig.verticesForComplexSprite(buyOptionGamePosition, buyOption.imageIndex, buyOption.imageScale, buyOption.imageScale, 1, 0, false, false, state);
        }
        const secondaryInfoPosition: main.Position = .{
            .x = buyOptionGamePosition.x - main.TILESIZE / 2,
            .y = buyOptionGamePosition.y + main.TILESIZE / 2,
        };
        if (buyOption.equipment) |equipment| {
            var secondaryEffect: ?equipmentZig.SecondaryEffect = null;
            switch (equipment.effectType) {
                .hp => |data| {
                    const hpDisplayTextPos: main.Position = .{
                        .x = secondaryInfoPosition.x + main.TILESIZE / 2,
                        .y = secondaryInfoPosition.y + fontSize + 1,
                    };
                    const textWidth = try fontVulkanZig.paintNumberGameMap(data.hp, hpDisplayTextPos, fontSize, textColor, state);
                    const hpDisplayIconPos: main.Position = .{
                        .x = hpDisplayTextPos.x + textWidth / 2,
                        .y = hpDisplayTextPos.y + fontSize / 2,
                    };
                    paintVulkanZig.verticesForComplexSprite(hpDisplayIconPos, imageZig.IMAGE_ICON_HP, 2.5, 2.5, 1, 0, false, false, state);
                    secondaryEffect = data.effect;
                },
                .damage => |data| {
                    const damageDisplayTextPos: main.Position = .{
                        .x = secondaryInfoPosition.x + main.TILESIZE / 2,
                        .y = secondaryInfoPosition.y + fontSize + 1,
                    };
                    _ = try fontVulkanZig.paintNumberGameMap(data.damage, damageDisplayTextPos, fontSize, textColor, state);
                    const DamageDisplayIconPos: main.Position = .{
                        .x = damageDisplayTextPos.x - 2.5,
                        .y = damageDisplayTextPos.y + fontSize / 2,
                    };
                    paintVulkanZig.verticesForComplexSprite(DamageDisplayIconPos, imageZig.IMAGE_ICON_DAMAGE, 2, 2, 1, 0, false, false, state);
                    secondaryEffect = data.effect;
                },
                .damagePerCent => |data| {
                    const damageDisplayTextPos: main.Position = .{
                        .x = secondaryInfoPosition.x + 2,
                        .y = secondaryInfoPosition.y + fontSize + 1,
                    };
                    const textWidth = fontVulkanZig.paintTextGameMap("x", damageDisplayTextPos, fontSize, textColor, state);
                    _ = try fontVulkanZig.paintNumberGameMap((data.factor + 1), .{ .x = damageDisplayTextPos.x + textWidth, .y = damageDisplayTextPos.y }, fontSize, textColor, state);
                    const DamageDisplayIconPos: main.Position = .{
                        .x = damageDisplayTextPos.x - 2.5,
                        .y = damageDisplayTextPos.y + fontSize / 2,
                    };
                    paintVulkanZig.verticesForComplexSprite(DamageDisplayIconPos, imageZig.IMAGE_ICON_DAMAGE, 2, 2, 1, 0, false, false, state);
                    secondaryEffect = data.effect;
                },
                else => {},
            }
            if (secondaryEffect) |secEffect| {
                const secEffectDisplayPos: main.Position = .{
                    .x = secondaryInfoPosition.x,
                    .y = secondaryInfoPosition.y + (fontSize + 1) * 2,
                };
                equipmentZig.setupVerticesForShopEquipmentSecondaryEffect(secEffectDisplayPos, secEffect, fontSize, state);
            }
        }
    }
}

fn paintGrid(player: *playerZig.Player, state: *main.GameState) !void {
    const verticeData = &state.vkState.verticeData;

    if (player.shop.pieceShopTopLeft == null) return;
    const playerShopPos = player.shop.pieceShopTopLeft.?;
    const gridGameTopLeft: main.Position = .{
        .x = @floatFromInt((playerShopPos.x + shopZig.GRID_OFFSET.x) * main.TILESIZE),
        .y = @floatFromInt((playerShopPos.y + shopZig.GRID_OFFSET.y) * main.TILESIZE),
    };
    const onePixelXInVulkan = 2 / state.windowData.widthFloat;
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;
    const size = main.TILESIZE * shopZig.GRID_SIZE;

    const vulkan: main.Position = .{
        .x = (-state.camera.position.x + gridGameTopLeft.x) * state.camera.zoom * onePixelXInVulkan,
        .y = (-state.camera.position.y + gridGameTopLeft.y) * state.camera.zoom * onePixelYInVulkan,
    };
    const halveVulkanTileSizeX = main.TILESIZE * onePixelXInVulkan * state.camera.zoom / 2;
    const halveVulkanTileSizeY = main.TILESIZE * onePixelYInVulkan * state.camera.zoom / 2;
    const width = size * onePixelXInVulkan * state.camera.zoom;
    const height = size * onePixelYInVulkan * state.camera.zoom;
    const left = vulkan.x - halveVulkanTileSizeX;
    const top = vulkan.y - halveVulkanTileSizeY;

    const triangles = &verticeData.triangles;
    if (triangles.verticeCount + 6 < triangles.vertices.len) {
        const fillColor: [4]f32 = .{ 1, 1, 1, 1 };
        triangles.vertices[triangles.verticeCount] = .{ .pos = .{ left, top }, .color = fillColor };
        triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = fillColor };
        triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ left, top + height }, .color = fillColor };
        triangles.vertices[triangles.verticeCount + 3] = .{ .pos = .{ left, top }, .color = fillColor };
        triangles.vertices[triangles.verticeCount + 4] = .{ .pos = .{ left + width, top }, .color = fillColor };
        triangles.vertices[triangles.verticeCount + 5] = .{ .pos = .{ left + width, top + height }, .color = fillColor };
        triangles.verticeCount += 6;
    }

    paintMovePieceInGrid(player, gridGameTopLeft, state);
    const pieceSelectionOffset: main.Position = .{
        .x = gridGameTopLeft.x - main.TILESIZE - main.TILESIZE / 2,
        .y = gridGameTopLeft.y - main.TILESIZE - main.TILESIZE / 4,
    };
    switch (player.shop.selectedOption) {
        .add => |data| {
            try verticesForMovePieceCount(data.selectedIndex + 1, player.shop.piecesToBuy.len, pieceSelectionOffset, state);
        },
        .cut => |data| {
            try verticesForMovePieceCount(data.selectedIndex + 1, player.totalMovePieces.items.len, pieceSelectionOffset, state);
        },
        .delete => |data| {
            try verticesForMovePieceCount(data.selectedIndex + 1, player.totalMovePieces.items.len, pieceSelectionOffset, state);
        },
        .combine => |data| {
            try verticesForMovePieceCount(data.pieceIndex1 + 1, player.totalMovePieces.items.len, .{
                .x = pieceSelectionOffset.x,
                .y = pieceSelectionOffset.y - main.TILESIZE / 4,
            }, state);
            if (data.pieceIndex2) |pieceIndex2| {
                try verticesForMovePieceCount(pieceIndex2 + 1, player.totalMovePieces.items.len, .{
                    .x = pieceSelectionOffset.x,
                    .y = pieceSelectionOffset.y + main.TILESIZE / 4,
                }, state);
            }
        },
        .none => {},
    }
    if (player.shop.selectedOption == .cut) {
        const cut = player.shop.selectedOption.cut;
        if (cut.gridCutOffset) |gridCutOffset| {
            const gamePositionCut: main.Position = .{
                .x = gridGameTopLeft.x + @as(f32, @floatFromInt(gridCutOffset.x * main.TILESIZE)),
                .y = gridGameTopLeft.y + @as(f32, @floatFromInt(gridCutOffset.y * main.TILESIZE)),
            };
            paintVulkanZig.verticesForComplexSpriteDefault(gamePositionCut, imageZig.IMAGE_CUT, state);
        }
    }
}

fn verticesForMovePieceCount(current: anytype, max: anytype, position: main.Position, state: *main.GameState) !void {
    const fontSize: f32 = @as(f32, @floatFromInt(main.TILESIZE)) / 2.2;
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    var textWidth = try fontVulkanZig.paintNumberGameMap(current, position, fontSize, textColor, state);
    textWidth += fontVulkanZig.paintTextGameMap("/", .{
        .x = position.x + textWidth,
        .y = position.y,
    }, fontSize, textColor, state);
    _ = try fontVulkanZig.paintNumberGameMap(max, .{
        .x = position.x + textWidth,
        .y = position.y,
    }, fontSize, textColor, state);
}

fn paintMovePieceInGrid(player: *playerZig.Player, gridGameTopLeft: main.Position, state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;
    if (player.shop.gridDisplayPiece == null) return;
    const gridDisplayPiece = player.shop.gridDisplayPiece.?;

    const onePixelXInVulkan = 2 / state.windowData.widthFloat;
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;
    var factor: f32 = 1;
    var gamePosOffsetX = @as(f32, @floatFromInt(player.shop.gridDisplayPieceOffset.x)) * main.TILESIZE;
    var gamePosOffsetY = @as(f32, @floatFromInt(player.shop.gridDisplayPieceOffset.y)) * main.TILESIZE;
    if (player.shop.selectedOption == .combine) {
        const boundingBox = movePieceZig.getBoundingBox(gridDisplayPiece);
        const maxSize: f32 = @floatFromInt(@max(boundingBox.width, boundingBox.height));
        factor = @min(1, shopZig.GRID_SIZE / maxSize);
        gamePosOffsetX = -@as(f32, @floatFromInt(boundingBox.pos.x)) * main.TILESIZE * factor;
        gamePosOffsetY = -@as(f32, @floatFromInt(boundingBox.pos.y)) * main.TILESIZE * factor;
        if (shopZig.GRID_SIZE > boundingBox.width) {
            const diffX = @as(f32, @floatFromInt(shopZig.GRID_SIZE - boundingBox.width));
            gamePosOffsetX += @round(diffX / 2) * main.TILESIZE * factor;
        }
        if (shopZig.GRID_SIZE > boundingBox.height) {
            const diffY = @as(f32, @floatFromInt(shopZig.GRID_SIZE - boundingBox.height));
            gamePosOffsetY += @round(diffY / 2) * main.TILESIZE * factor;
        }
    }
    const size: f32 = main.TILESIZE * factor;
    const gamePosition = .{
        .x = gridGameTopLeft.x + gamePosOffsetX,
        .y = gridGameTopLeft.y + gamePosOffsetY,
    };
    const vulkan: main.Position = .{
        .x = (-state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
        .y = (-state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
    };
    const width = size * onePixelXInVulkan * state.camera.zoom;
    const height = size * onePixelYInVulkan * state.camera.zoom;
    var left = vulkan.x - width / 2 / factor;
    var top = vulkan.y - height / 2 / factor;

    const fillColor: [4]f32 = .{ 0.25, 0.25, 0.25, 1 };
    const endPos = playerUxVulkanZig.verticesForMovePiece(
        gridDisplayPiece,
        fillColor,
        left,
        top,
        width,
        height,
        0,
        false,
        &verticeData.lines,
        &verticeData.triangles,
    );
    left = endPos.x;
    top = endPos.y;

    if (player.shop.selectedOption == .combine and player.shop.selectedOption.combine.pieceIndex2 != null) {
        const displayPiece2 = player.totalMovePieces.items[player.shop.selectedOption.combine.pieceIndex2.?];
        const directionChange = player.shop.selectedOption.combine.direction;
        _ = playerUxVulkanZig.verticesForMovePiece(
            displayPiece2,
            fillColor,
            left,
            top,
            width,
            height,
            directionChange,
            false,
            &verticeData.lines,
            &verticeData.triangles,
        );
    }
}

fn rectangleForTile(gamePosition: main.Position, fillColor: [4]f32, verticeData: *dataVulkanZig.VkVerticeData, withOutline: bool, state: *main.GameState) void {
    const onePixelXInVulkan = 2 / state.windowData.widthFloat;
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;
    const size = main.TILESIZE;

    const vulkan: main.Position = .{
        .x = (-state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
        .y = (-state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
    };
    const width = size * onePixelXInVulkan * state.camera.zoom;
    const height = size * onePixelYInVulkan * state.camera.zoom;
    const left = vulkan.x - width / 2;
    const top = vulkan.y - height / 2;

    const triangles = &verticeData.triangles;
    if (triangles.verticeCount + 6 >= triangles.vertices.len) return;
    triangles.vertices[triangles.verticeCount] = .{ .pos = .{ left, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ left, top + height }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 3] = .{ .pos = .{ left, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 4] = .{ .pos = .{ left + width, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 5] = .{ .pos = .{ left + width, top + height }, .color = fillColor };
    triangles.verticeCount += 6;
    if (withOutline) {
        const borderColor: [4]f32 = .{ 0, 0, 0, 1 };
        const lines = &verticeData.lines;
        if (lines.verticeCount + 8 >= lines.vertices.len) return;
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top }, .color = borderColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top }, .color = borderColor };
        lines.vertices[lines.verticeCount + 2] = .{ .pos = .{ left, top }, .color = borderColor };
        lines.vertices[lines.verticeCount + 3] = .{ .pos = .{ left, top + height }, .color = borderColor };
        lines.vertices[lines.verticeCount + 4] = .{ .pos = .{ left + width, top }, .color = borderColor };
        lines.vertices[lines.verticeCount + 5] = .{ .pos = .{ left + width, top + height }, .color = borderColor };
        lines.vertices[lines.verticeCount + 6] = .{ .pos = .{ left, top + height }, .color = borderColor };
        lines.vertices[lines.verticeCount + 7] = .{ .pos = .{ left + width, top + height }, .color = borderColor };
        lines.verticeCount += 8;
    }
}

pub fn payMoreVerticeSetups(player: *playerZig.Player, shopButton: shopZig.PlayerShopButton, state: *main.GameState) anyerror!void {
    if (player.shop.pieceShopTopLeft == null) return;
    const shopPos = player.shop.pieceShopTopLeft.?;
    const shopButtonGamePosition: main.Position = .{
        .x = @floatFromInt((shopPos.x + shopButton.tileOffset.x) * main.TILESIZE),
        .y = @floatFromInt((shopPos.y + shopButton.tileOffset.y) * main.TILESIZE),
    };
    const pricePosition: main.Position = .{
        .x = shopButtonGamePosition.x - main.TILESIZE / 2,
        .y = shopButtonGamePosition.y,
    };
    const alpha: f32 = shopZig.payButtonAlpha(player);
    const fontSize: f32 = @as(f32, @floatFromInt(main.TILESIZE)) / 2.2;
    const textColor: [4]f32 = .{ 1, 1, 1, alpha };
    const width = fontVulkanZig.paintTextGameMap("$", pricePosition, fontSize, textColor, state);
    _ = try fontVulkanZig.paintNumberGameMap(state.level, .{
        .x = pricePosition.x + width,
        .y = pricePosition.y,
    }, fontSize, textColor, state);
    if (player.shop.selectedOption != .none) {
        for (shopZig.SHOP_BUTTONS) |otherShopButton| {
            if (otherShopButton.option == player.shop.selectedOption) {
                const toolDisplayPosition: main.Position = .{
                    .x = shopButtonGamePosition.x,
                    .y = shopButtonGamePosition.y - main.TILESIZE / 4,
                };
                paintVulkanZig.verticesForComplexSprite(toolDisplayPosition, otherShopButton.imageIndex, 0.5, 0.5, alpha, 0, false, false, state);
                break;
            }
        }
    }
}

pub fn nextStepMoreVerticeSetups(player: *playerZig.Player, shopButton: shopZig.PlayerShopButton, state: *main.GameState) anyerror!void {
    if (player.shop.pieceShopTopLeft == null) return;
    const shopPos = player.shop.pieceShopTopLeft.?;
    const shopButtonGamePosition: main.Position = .{
        .x = @floatFromInt((shopPos.x + shopButton.tileOffset.x) * main.TILESIZE),
        .y = @floatFromInt((shopPos.y + shopButton.tileOffset.y) * main.TILESIZE),
    };
    const stepPosition: main.Position = .{
        .x = shopButtonGamePosition.x - main.TILESIZE / 2,
        .y = shopButtonGamePosition.y - main.TILESIZE / 2,
    };
    const fontSize: f32 = @as(f32, @floatFromInt(main.TILESIZE)) / 2.2;
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    if (player.shop.selectedOption == .combine) {
        var displayStep: u32 = 1;
        switch (player.shop.selectedOption.combine.combineStep) {
            .selectPiece1 => displayStep = 1,
            .selectPiece2 => displayStep = 2,
            .selectDirection => displayStep = 3,
            .reset => displayStep = 4,
        }
        if (displayStep < 3) {
            const width = try fontVulkanZig.paintNumberGameMap(displayStep, stepPosition, fontSize, textColor, state);
            _ = fontVulkanZig.paintTextGameMap("/2", .{ .x = stepPosition.x + width, .y = stepPosition.y }, fontSize, textColor, state);
            const checkmarkPosition: main.Position = .{
                .x = shopButtonGamePosition.x,
                .y = shopButtonGamePosition.y + main.TILESIZE / 4,
            };
            paintVulkanZig.verticesForComplexSprite(checkmarkPosition, imageZig.IMAGE_CHECKMARK, 2, 2, 1, 0, false, false, state);
        } else if (displayStep == 3) {
            const checkmarkPosition: main.Position = .{
                .x = shopButtonGamePosition.x,
                .y = shopButtonGamePosition.y,
            };
            const rotate: f32 = @as(f32, @floatFromInt(state.gameTime)) / 500;
            paintVulkanZig.verticesForComplexSprite(checkmarkPosition, imageZig.IMAGE_ICON_REFRESH, 3, 3, 1, rotate, false, false, state);
        } else {
            _ = fontVulkanZig.paintTextGameMap("Reset", .{
                .x = shopButtonGamePosition.x - main.TILESIZE / 2,
                .y = shopButtonGamePosition.y,
            }, fontSize, textColor, state);
        }
    }
}
