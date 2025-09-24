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
    const verticeData = &state.vkState.verticeData;
    const textColor: [3]f32 = .{ 1, 1, 1 };
    if (state.gamePhase == .shopping) {
        const player = &state.players.items[0];
        try paintGrid(player, state);
        const player0ShopPos = player.shop.pieceShopTopLeft;
        for (shopZig.SHOP_BUTTONS) |shopButton| {
            if (shopButton.isVisible != null and !shopButton.isVisible.?(player)) continue;
            const shopButtonGamePosition: main.Position = .{
                .x = @floatFromInt((player0ShopPos.x + shopButton.tileOffset.x) * main.TILESIZE),
                .y = @floatFromInt((player0ShopPos.y + shopButton.tileOffset.y) * main.TILESIZE),
            };
            if (shopButton.option != .none and shopButton.option == player.shop.selectedOption) {
                rectangleForTile(shopButtonGamePosition, .{ 0, 0, 1 }, verticeData, false, state);
            }
            if (shopButton.moreVerticeSetups) |moreVertices| try moreVertices(player, shopButton, state);
            if (shopButton.imageRotate != 0) {
                paintVulkanZig.verticesForComplexSpriteWithRotate(shopButtonGamePosition, shopButton.imageIndex, shopButton.imageRotate, 1, state);
            } else {
                paintVulkanZig.verticesForComplexSpriteDefault(shopButtonGamePosition, shopButton.imageIndex, state);
            }
        }

        for (state.shop.buyOptions.items) |buyOption| {
            const buyOptionGamePosition: main.Position = .{
                .x = @floatFromInt(buyOption.tilePosition.x * main.TILESIZE),
                .y = @floatFromInt(buyOption.tilePosition.y * main.TILESIZE),
            };
            paintVulkanZig.verticesForComplexSprite(buyOptionGamePosition, buyOption.imageIndex, buyOption.imageScale, buyOption.imageScale, 1, 0, false, false, state);
            const startingInfoTopLeftDisplayPos: main.Position = .{
                .x = buyOptionGamePosition.x - main.TILESIZE / 2,
                .y = buyOptionGamePosition.y + main.TILESIZE / 2,
            };
            var moneyDisplayPos: main.Position = startingInfoTopLeftDisplayPos;
            const fontSize = 8;
            if (buyOption.price > 0) {
                moneyDisplayPos.x += fontVulkanZig.paintTextGameMap("$", moneyDisplayPos, fontSize, textColor, &state.vkState.verticeData.font, state);
                _ = try fontVulkanZig.paintNumberGameMap(buyOption.price, moneyDisplayPos, fontSize, textColor, &state.vkState.verticeData.font, state);
            }
            var secondaryEffect: ?equipmentZig.SecondaryEffect = null;
            switch (buyOption.equipment.effectType) {
                .hp => |data| {
                    const hpDisplayTextPos: main.Position = .{
                        .x = moneyDisplayPos.x,
                        .y = moneyDisplayPos.y + fontSize + 1,
                    };
                    const textWidth = try fontVulkanZig.paintNumberGameMap(data.hp, hpDisplayTextPos, fontSize, textColor, &state.vkState.verticeData.font, state);
                    const hpDisplayIconPos: main.Position = .{
                        .x = hpDisplayTextPos.x + textWidth / 2,
                        .y = hpDisplayTextPos.y + fontSize / 2,
                    };
                    paintVulkanZig.verticesForComplexSprite(hpDisplayIconPos, imageZig.IMAGE_ICON_HP, 2.5, 2.5, 1, 0, false, false, state);
                    secondaryEffect = data.effect;
                },
                .damage => |data| {
                    const damageDisplayTextPos: main.Position = .{
                        .x = moneyDisplayPos.x + 2,
                        .y = moneyDisplayPos.y + fontSize + 1,
                    };
                    _ = try fontVulkanZig.paintNumberGameMap(data.damage, damageDisplayTextPos, fontSize, textColor, &state.vkState.verticeData.font, state);
                    const DamageDisplayIconPos: main.Position = .{
                        .x = damageDisplayTextPos.x - 2.5,
                        .y = damageDisplayTextPos.y + fontSize / 2,
                    };
                    paintVulkanZig.verticesForComplexSprite(DamageDisplayIconPos, imageZig.IMAGE_ICON_DAMAGE, 2, 2, 1, 0, false, false, state);
                    secondaryEffect = data.effect;
                },
                .damagePerCent => |data| {
                    const damageDisplayTextPos: main.Position = .{
                        .x = moneyDisplayPos.x + 2,
                        .y = moneyDisplayPos.y + fontSize + 1,
                    };
                    const textWidth = fontVulkanZig.paintTextGameMap("x", damageDisplayTextPos, fontSize, textColor, &state.vkState.verticeData.font, state);
                    _ = try fontVulkanZig.paintNumberGameMap((data.factor + 1), .{ .x = damageDisplayTextPos.x + textWidth, .y = damageDisplayTextPos.y }, fontSize, textColor, &state.vkState.verticeData.font, state);
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
                    .x = startingInfoTopLeftDisplayPos.x,
                    .y = startingInfoTopLeftDisplayPos.y + (fontSize + 1) * 2,
                };
                equipmentZig.setupVerticesForShopEquipmentSecondaryEffect(secEffectDisplayPos, secEffect, fontSize, state);
            }
        }
    }
}

fn paintGrid(player: *playerZig.Player, state: *main.GameState) !void {
    const verticeData = &state.vkState.verticeData;

    const player0ShopPos = player.shop.pieceShopTopLeft;
    const gridGameTopLeft: main.Position = .{
        .x = @floatFromInt((player0ShopPos.x + shopZig.GRID_OFFSET.x) * main.TILESIZE),
        .y = @floatFromInt((player0ShopPos.y + shopZig.GRID_OFFSET.y) * main.TILESIZE),
    };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
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
        const fillColor: [3]f32 = .{ 1, 1, 1 };
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
    const textColor: [3]f32 = .{ 1, 1, 1 };
    var textWidth = try fontVulkanZig.paintNumberGameMap(current, position, fontSize, textColor, &state.vkState.verticeData.font, state);
    textWidth += fontVulkanZig.paintTextGameMap(":", .{
        .x = position.x + textWidth,
        .y = position.y,
    }, fontSize, textColor, &state.vkState.verticeData.font, state);
    _ = try fontVulkanZig.paintNumberGameMap(max, .{
        .x = position.x + textWidth,
        .y = position.y,
    }, fontSize, textColor, &state.vkState.verticeData.font, state);
}

fn paintMovePieceInGrid(player: *playerZig.Player, gridGameTopLeft: main.Position, state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;
    if (player.shop.gridDisplayPiece == null) return;
    const gridDisplayPiece = player.shop.gridDisplayPiece.?;

    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const size = main.TILESIZE;
    const gamePosition = .{
        .x = gridGameTopLeft.x + @as(f32, @floatFromInt(player.shop.gridDisplayPieceOffset.x)) * main.TILESIZE,
        .y = gridGameTopLeft.y + @as(f32, @floatFromInt(player.shop.gridDisplayPieceOffset.y)) * main.TILESIZE,
    };
    const vulkan: main.Position = .{
        .x = (-state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
        .y = (-state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
    };
    const width = size * onePixelXInVulkan * state.camera.zoom;
    const height = size * onePixelYInVulkan * state.camera.zoom;
    var left = vulkan.x - width / 2;
    var top = vulkan.y - height / 2;

    const endPos = playerUxVulkanZig.verticesForMovePiece(
        gridDisplayPiece,
        .{ 0.25, 0.25, 0.25 },
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
            .{ 0.25, 0.25, 0.25 },
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

fn rectangleForTile(gamePosition: main.Position, fillColor: [3]f32, verticeData: *dataVulkanZig.VkVerticeData, withOutline: bool, state: *main.GameState) void {
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
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
        const borderColor: [3]f32 = .{ 0, 0, 0 };
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
    const shopPos = player.shop.pieceShopTopLeft;
    const shopButtonGamePosition: main.Position = .{
        .x = @floatFromInt((shopPos.x + shopButton.tileOffset.x) * main.TILESIZE),
        .y = @floatFromInt((shopPos.y + shopButton.tileOffset.y) * main.TILESIZE),
    };
    const pricePosition: main.Position = .{
        .x = shopButtonGamePosition.x - main.TILESIZE / 2,
        .y = shopButtonGamePosition.y,
    };
    const fontSize: f32 = @as(f32, @floatFromInt(main.TILESIZE)) / 2.2;
    const textColor: [3]f32 = .{ 1, 1, 1 };
    const width = fontVulkanZig.paintTextGameMap("$", pricePosition, fontSize, textColor, &state.vkState.verticeData.font, state);
    _ = try fontVulkanZig.paintNumberGameMap(state.level, .{
        .x = pricePosition.x + width,
        .y = pricePosition.y,
    }, fontSize, textColor, &state.vkState.verticeData.font, state);
    if (player.shop.selectedOption != .none) {
        for (shopZig.SHOP_BUTTONS) |otherShopButton| {
            if (otherShopButton.option == player.shop.selectedOption) {
                const toolDisplayPosition: main.Position = .{
                    .x = shopButtonGamePosition.x,
                    .y = shopButtonGamePosition.y - main.TILESIZE / 4,
                };
                paintVulkanZig.verticesForComplexSprite(toolDisplayPosition, otherShopButton.imageIndex, 0.5, 0.5, 1, 0, false, false, state);
                break;
            }
        }
    }
}
