const std = @import("std");
const main = @import("main.zig");
const imageZig = @import("image.zig");
const movePieceZig = @import("movePiece.zig");
const bossZig = @import("boss/boss.zig");
const mapTileZig = @import("mapTile.zig");
const equipmentZig = @import("equipment.zig");
const statsZig = @import("stats.zig");
const playerZig = @import("player.zig");
const shopVulkanZig = @import("vulkan/shopVulkan.zig");
const soundMixerZig = @import("soundMixer.zig");

const ShopOption = enum {
    none,
    add,
    delete,
    cut,
    combine,
};

const CombineStep = enum {
    selectPiece1,
    selectPiece2,
    selectDirection,
    reset,
};

const ShopOptionData = union(ShopOption) {
    none,
    add: struct {
        selectedIndex: usize = 0,
    },
    delete: struct {
        selectedIndex: usize = 0,
    },
    cut: struct {
        selectedIndex: usize = 0,
        gridCutOffset: ?main.TilePosition = null,
        isOnMovePiece: bool = false,
    },
    combine: struct {
        pieceIndex1: usize = 0,
        pieceIndex2: ?usize = null,
        direction: u8 = 0,
        combineStep: CombineStep = .selectPiece1,
    },
};

pub const PlayerShopButton = struct {
    tileOffset: main.TilePosition,
    imageIndex: u8,
    imageRotate: f32 = 0,
    option: ShopOption = .none,
    execute: *const fn (player: *playerZig.Player, state: *main.GameState) anyerror!void,
    isVisible: ?*const fn (player: *playerZig.Player) bool = null,
    getAlpha: ?*const fn (player: *playerZig.Player) f32 = null,
    moreVerticeSetups: ?*const fn (player: *playerZig.Player, shopButton: PlayerShopButton, state: *main.GameState) anyerror!void = null,
};

pub const GRID_SIZE = 8;
pub const GRID_OFFSET: main.TilePosition = .{ .x = 1, .y = 1 };
pub const EARLY_SHOP_GRID_SIZE = 2;

pub const ShopPlayerData = struct {
    piecesToBuy: [3]?movePieceZig.MovePiece = [3]?movePieceZig.MovePiece{ null, null, null },
    selectedOption: ShopOptionData = .none,
    pieceShopTopLeft: main.TilePosition = .{ .x = -4, .y = -4 },
    gridDisplayPiece: ?movePieceZig.MovePiece = null,
    gridDisplayPieceOffset: main.TilePosition = .{ .x = 4, .y = 4 },
};

pub const ShopBuyOption = struct {
    tilePosition: main.TilePosition,
    price: u32,
    imageIndex: u8,
    imageScale: f32 = 1,
    equipment: equipmentZig.EquipmentSlotData,
};

pub const ShopData = struct {
    buyOptions: std.ArrayList(ShopBuyOption),
    equipOptionsLastLevelInShop: [equipmentZig.EQUIPMENT_SHOP_OPTIONS.len]u32 = undefined,
    exitShopArea: main.TileRectangle = .{ .pos = .{ .x = GRID_SIZE - 1, .y = -4 }, .height = 2, .width = 2 },
};

pub const SHOP_BUTTONS = [_]PlayerShopButton{
    .{
        .execute = executeAddPiece,
        .imageIndex = imageZig.IMAGE_PLUS,
        .tileOffset = .{ .x = 3, .y = 0 },
        .option = .add,
    },
    .{
        .execute = executeDeletePiece,
        .imageIndex = imageZig.IMAGE_WARNING_TILE,
        .tileOffset = .{ .x = 4, .y = 0 },
        .option = .delete,
    },
    .{
        .execute = executeCutPiece,
        .imageIndex = imageZig.IMAGE_CUT,
        .tileOffset = .{ .x = 5, .y = 0 },
        .option = .cut,
    },
    .{
        .execute = executeCombinePiece,
        .imageIndex = imageZig.IMAGE_COMBINE,
        .tileOffset = .{ .x = 6, .y = 0 },
        .option = .combine,
    },
    .{
        .execute = executeArrowLeft,
        .imageIndex = imageZig.IMAGE_ARROW_RIGHT,
        .imageRotate = std.math.pi,
        .tileOffset = .{ .x = 0, .y = 1 },
        .getAlpha = arrowButtonAlpha,
    },
    .{
        .execute = executeArrowRight,
        .imageIndex = imageZig.IMAGE_ARROW_RIGHT,
        .tileOffset = .{ .x = 0, .y = 2 },
        .getAlpha = arrowButtonAlpha,
    },
    .{
        .execute = executePay,
        .imageIndex = imageZig.IMAGE_BORDER_TILE,
        .tileOffset = .{ .x = 0, .y = 5 },
        .moreVerticeSetups = shopVulkanZig.payMoreVerticeSetups,
        .getAlpha = payButtonAlpha,
    },
    .{
        .execute = executeNextStep,
        .imageIndex = imageZig.IMAGE_BORDER_TILE,
        .tileOffset = .{ .x = 0, .y = 3 },
        .isVisible = isNextStepButtonVisible,
        .moreVerticeSetups = shopVulkanZig.nextStepMoreVerticeSetups,
    },
};

pub fn executeShopActionForPlayer(player: *playerZig.Player, state: *main.GameState) !void {
    const playerTile: main.TilePosition = main.gamePositionToTilePosition(player.position);
    const shopTopLeftTile = player.shop.pieceShopTopLeft;
    for (SHOP_BUTTONS) |shopButton| {
        if (shopButton.isVisible != null and !shopButton.isVisible.?(player)) continue;
        const checkPosition: main.TilePosition = .{ .x = shopButton.tileOffset.x + shopTopLeftTile.x, .y = shopButton.tileOffset.y + shopTopLeftTile.y };
        if (checkPosition.x == playerTile.x and checkPosition.y == playerTile.y) {
            try shopButton.execute(player, state);
            return;
        }
    }
    const gridPosition: main.TilePosition = .{ .x = GRID_OFFSET.x + shopTopLeftTile.x, .y = GRID_OFFSET.y + shopTopLeftTile.y };
    if (gridPosition.x <= playerTile.x and gridPosition.y <= playerTile.y and gridPosition.y + GRID_SIZE > playerTile.x and gridPosition.y + GRID_SIZE > playerTile.y) {
        try executeGridTile(player, state);
        return;
    }

    for (state.shop.buyOptions.items, 0..) |*buyOption, buyIndex| {
        if (buyOption.tilePosition.x == playerTile.x and buyOption.tilePosition.y == playerTile.y) {
            if (player.money >= buyOption.price) {
                const optOldEquip = equipmentZig.getEquipSlot(buyOption.equipment.slotTypeData, player);
                if (equipmentZig.equip(buyOption.equipment, true, player)) {
                    try playerZig.changePlayerMoneyBy(-@as(i32, @intCast(buyOption.price)), player, true, state);
                    if (optOldEquip) |old| {
                        buyOption.price = 0;
                        buyOption.equipment = old;
                        buyOption.imageIndex = old.imageIndex;
                    } else {
                        _ = state.shop.buyOptions.swapRemove(buyIndex);
                    }
                }
            } else {
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION_FAIL, 0, 0.5);
            }
            return;
        }
    }
    if (main.isTilePositionInTileRectangle(playerTile, state.shop.exitShopArea)) {
        try main.endShoppingPhase(state);
    }
}

pub fn getShopEarlyTriggerPosition(state: *main.GameState) main.TileRectangle {
    return main.TileRectangle{
        .pos = .{
            .x = @intCast(state.mapData.tileRadiusWidth + 2),
            .y = @intCast(@divFloor(state.mapData.tileRadiusHeight, 2) - 1),
        },
        .height = EARLY_SHOP_GRID_SIZE,
        .width = EARLY_SHOP_GRID_SIZE,
    };
}

pub fn isPlayerInShopTrigger(player: *playerZig.Player, state: *main.GameState) bool {
    if (state.gamePhase == .shopping) return false;
    if (state.round < state.roundToReachForNextLevel) return false;
    const tileRectangle = getShopEarlyTriggerPosition(state);
    const playerTile = main.gamePositionToTilePosition(player.position);
    return main.isTilePositionInTileRectangle(playerTile, tileRectangle);
}

pub fn startShoppingPhase(state: *main.GameState) !void {
    if (!state.gameOver) try statsZig.statsOnLevelFinished(state);
    state.suddenDeath = 0;
    state.camera.position = .{ .x = 0, .y = 0 };
    mapTileZig.setMapType(.default, state);
    state.gamePhase = .shopping;
    state.enemyData.enemies.clearRetainingCapacity();
    state.enemyData.enemyObjects.clearRetainingCapacity();
    mapTileZig.resetMapTiles(state.mapData.tiles);
    bossZig.clearBosses(state);
    try randomizeShop(state);
    for (state.players.items) |*player| {
        player.shop.gridDisplayPiece = null;
        player.shop.selectedOption = .none;
        if (player.isDead) player.isDead = false;
        player.position.x = @as(f32, @floatFromInt(player.shop.pieceShopTopLeft.x + GRID_SIZE / 2)) * main.TILESIZE;
        player.position.y = @as(f32, @floatFromInt(player.shop.pieceShopTopLeft.y + GRID_SIZE / 2)) * main.TILESIZE;
        try movePieceZig.resetPieces(player, true, state);
    }
    try mapTileZig.setMapRadius(5, 5, state);
    main.adjustZoom(state);
}

pub fn randomizeShop(state: *main.GameState) !void {
    for (state.players.items) |*player| {
        for (player.shop.piecesToBuy, 0..) |optPiece, index| {
            if (optPiece) |piece| {
                state.allocator.free(piece.steps);
                player.shop.piecesToBuy[index] = null;
            }
        }
    }

    for (state.players.items) |*player| {
        var pieceToBuyIndex: usize = 0;
        toBuy: while (pieceToBuyIndex < player.shop.piecesToBuy.len) {
            const randomPiece = try movePieceZig.createRandomMovePiece(state.allocator);
            for (player.shop.piecesToBuy) |otherPiece| {
                if (otherPiece != null and movePieceZig.areSameMovePieces(randomPiece, otherPiece.?)) {
                    state.allocator.free(randomPiece.steps);
                    continue :toBuy;
                }
            }
            player.shop.piecesToBuy[pieceToBuyIndex] = randomPiece;
            pieceToBuyIndex += 1;
        }
    }

    try randomizeBuyableEquipment(3, state);
}

fn randomizeBuyableEquipment(maxShopOptions: usize, state: *main.GameState) !void {
    state.shop.buyOptions.clearRetainingCapacity();
    var blacklistedIndexes: std.ArrayList(usize) = std.ArrayList(usize).init(state.allocator);
    defer blacklistedIndexes.deinit();

    var shopOptionsCount: usize = 0;
    while (shopOptionsCount < maxShopOptions) {
        const optRandomEquipIndex = getRandomEquipmentIndexForShop(blacklistedIndexes.items, shopOptionsCount, state);
        if (optRandomEquipIndex == null) break;
        const randomEquip = equipmentZig.getEquipmentOptionByIndexScaledToLevel(optRandomEquipIndex.?, state.level);
        try blacklistedIndexes.append(optRandomEquipIndex.?);

        try state.shop.buyOptions.append(.{
            .price = state.level * randomEquip.basePrice,
            .tilePosition = .{ .x = 6 + @as(i32, @intCast(shopOptionsCount * 2)), .y = 3 },
            .imageIndex = randomEquip.shopDisplayImage,
            .imageScale = randomEquip.imageScale,
            .equipment = randomEquip.equipment,
        });
        state.shop.equipOptionsLastLevelInShop[optRandomEquipIndex.?] = state.level;
        shopOptionsCount += 1;
    }
}

///mode=0 only weapons
///mode=1 no weapons
///mode>1 everything
fn getRandomEquipmentIndexForShop(blacklistedIndexes: []usize, mode: usize, state: *main.GameState) ?usize {
    var totalProbability: u32 = 0;
    main: for (0..state.shop.equipOptionsLastLevelInShop.len) |index| {
        if (mode == 0 and equipmentZig.EQUIPMENT_SHOP_OPTIONS[index].equipment.slotTypeData != .weapon) continue;
        if (mode == 1 and equipmentZig.EQUIPMENT_SHOP_OPTIONS[index].equipment.slotTypeData == .weapon) continue;
        for (blacklistedIndexes) |blacklisted| {
            if (blacklisted == index) continue :main;
        }
        const level = state.shop.equipOptionsLastLevelInShop[index];
        totalProbability += @max(1, state.level -| level);
    }
    const random = std.crypto.random.intRangeLessThan(usize, 0, totalProbability);
    totalProbability = 0;
    main: for (0..state.shop.equipOptionsLastLevelInShop.len) |index| {
        if (mode == 0 and equipmentZig.EQUIPMENT_SHOP_OPTIONS[index].equipment.slotTypeData != .weapon) continue;
        if (mode == 1 and equipmentZig.EQUIPMENT_SHOP_OPTIONS[index].equipment.slotTypeData == .weapon) continue;
        for (blacklistedIndexes) |blacklisted| {
            if (blacklisted == index) continue :main;
        }
        const level = state.shop.equipOptionsLastLevelInShop[index];
        totalProbability += @max(1, state.level -| level);
        if (random <= totalProbability) {
            return index;
        }
    }
    return null;
}

pub fn executeGridTile(player: *playerZig.Player, state: *main.GameState) !void {
    _ = state;
    switch (player.shop.selectedOption) {
        .cut => |*data| {
            const playerTile: main.TilePosition = main.gamePositionToTilePosition(player.position);
            const playerGridTile: main.TilePosition = .{
                .x = playerTile.x - player.shop.pieceShopTopLeft.x - GRID_OFFSET.x,
                .y = playerTile.y - player.shop.pieceShopTopLeft.y - GRID_OFFSET.y,
            };

            if (movePieceZig.isTilePositionOnMovePiece(playerGridTile, player.shop.gridDisplayPieceOffset, player.shop.gridDisplayPiece.?, true)) {
                data.gridCutOffset = playerGridTile;
                data.isOnMovePiece = true;
            } else if (!data.isOnMovePiece) {
                data.gridCutOffset = playerGridTile;
            }
        },
        else => {},
    }
}

pub fn executeNextStep(player: *playerZig.Player, state: *main.GameState) !void {
    switch (player.shop.selectedOption) {
        .combine => |*data| {
            switch (data.combineStep) {
                .selectPiece1 => {
                    if (player.totalMovePieces.items.len > 1) {
                        data.pieceIndex2 = @mod(data.pieceIndex1 + 1, player.totalMovePieces.items.len);
                        data.combineStep = .selectPiece2;
                        const steps = player.shop.gridDisplayPiece.?.steps;
                        data.direction = @mod(steps[steps.len - 1].direction + 1, 4);
                    }
                },
                .selectPiece2 => {
                    data.combineStep = .selectDirection;
                },
                .selectDirection => {
                    data.combineStep = .reset;
                },
                .reset => {
                    data.combineStep = .selectPiece1;
                    data.direction = 0;
                    data.pieceIndex2 = null;
                },
            }
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
        },
        else => {},
    }
}

pub fn executePay(player: *playerZig.Player, state: *main.GameState) !void {
    switch (player.shop.selectedOption) {
        .delete => |*data| {
            const cost = state.level;
            if (player.money >= cost and player.totalMovePieces.items.len > 1) {
                try movePieceZig.removeMovePiece(player, data.selectedIndex, state.allocator);
                try playerZig.changePlayerMoneyBy(-@as(i32, @intCast(cost)), player, true, state);
                if (player.uxData.visualizeMovePieceChangeFromShop == null) {
                    player.uxData.visualizeMovePieceChangeFromShop = -1;
                } else {
                    player.uxData.visualizeMovePieceChangeFromShop.? += -1;
                }

                if (player.totalMovePieces.items.len <= data.selectedIndex) {
                    data.selectedIndex -= 1;
                }
                setGridDisplayPiece(player, player.totalMovePieces.items[data.selectedIndex]);
            } else {
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION_FAIL, 0, 0.5);
            }
            if (player.moveOptions.items.len == 0) {
                try movePieceZig.resetPieces(player, false, state);
            }
        },
        .add => |*data| {
            const cost = state.level;
            if (player.money >= cost) {
                if (player.shop.piecesToBuy[data.selectedIndex]) |buyPiece| {
                    try playerZig.changePlayerMoneyBy(-@as(i32, @intCast(cost)), player, true, state);
                    if (player.uxData.visualizeMovePieceChangeFromShop == null) {
                        player.uxData.visualizeMovePieceChangeFromShop = 1;
                    } else {
                        player.uxData.visualizeMovePieceChangeFromShop.? += 1;
                    }

                    try movePieceZig.addMovePiece(player, buyPiece);
                    var isDifferentPiece = false;
                    while (!isDifferentPiece) {
                        isDifferentPiece = true;
                        const newBuyPiece = try movePieceZig.createRandomMovePiece(state.allocator);
                        for (player.shop.piecesToBuy) |pieceToBuy| {
                            if (pieceToBuy) |piece| {
                                if (movePieceZig.areSameMovePieces(piece, newBuyPiece)) {
                                    isDifferentPiece = false;
                                    break;
                                }
                            }
                        }
                        if (!isDifferentPiece) {
                            state.allocator.free(newBuyPiece.steps);
                        } else {
                            player.shop.piecesToBuy[data.selectedIndex] = newBuyPiece;
                        }
                    }
                    setGridDisplayPiece(player, player.shop.piecesToBuy[data.selectedIndex]);
                }
            } else {
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION_FAIL, 0, 0.5);
            }
        },
        .cut => |*data| {
            const cost = state.level;
            if (player.money >= cost and data.isOnMovePiece and data.gridCutOffset != null and player.shop.gridDisplayPiece != null) {
                try playerZig.changePlayerMoneyBy(-@as(i32, @intCast(cost)), player, true, state);
                try movePieceZig.cutTilePositionOnMovePiece(player, data.gridCutOffset.?, player.shop.gridDisplayPieceOffset, data.selectedIndex, state);
                data.gridCutOffset = null;
                setGridDisplayPiece(player, player.totalMovePieces.items[data.selectedIndex]);
            } else {
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION_FAIL, 0, 0.5);
            }
        },
        .combine => |*data| {
            const cost = state.level;
            if (player.money >= cost and data.pieceIndex2 != null and (data.combineStep == .selectDirection or data.combineStep == .reset)) {
                try playerZig.changePlayerMoneyBy(-@as(i32, @intCast(cost)), player, true, state);
                player.uxData.visualizeMovePieceChangeFromShop = -1;
                try movePieceZig.combineMovePieces(player, data.pieceIndex1, data.pieceIndex2.?, data.direction, state);
                if (data.pieceIndex1 > data.pieceIndex2.?) {
                    data.pieceIndex1 -= 1;
                }
                setGridDisplayPiece(player, player.totalMovePieces.items[data.pieceIndex1]);
                data.pieceIndex2 = null;
                data.combineStep = .selectPiece1;
                if (player.moveOptions.items.len == 0) {
                    try movePieceZig.resetPieces(player, false, state);
                }
            } else {
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION_FAIL, 0, 0.5);
            }
        },
        else => {
            try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION_FAIL, 0, 0.5);
        },
    }
}

pub fn executeArrowRight(player: *playerZig.Player, state: *main.GameState) !void {
    switch (player.shop.selectedOption) {
        .delete => |*data| {
            data.selectedIndex = @mod(data.selectedIndex + 1, player.totalMovePieces.items.len);
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
            setGridDisplayPiece(player, player.totalMovePieces.items[data.selectedIndex]);
        },
        .add => |*data| {
            data.selectedIndex = @mod(data.selectedIndex + 1, player.shop.piecesToBuy.len);
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
            setGridDisplayPiece(player, player.shop.piecesToBuy[data.selectedIndex]);
        },
        .cut => |*data| {
            data.selectedIndex = @mod(data.selectedIndex + 1, player.totalMovePieces.items.len);
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
            setGridDisplayPiece(player, player.totalMovePieces.items[data.selectedIndex]);
            data.gridCutOffset = null;
            data.isOnMovePiece = false;
        },
        .combine => |*data| {
            switch (data.combineStep) {
                .selectPiece1 => {
                    data.pieceIndex1 = @mod(data.pieceIndex1 + 1, player.totalMovePieces.items.len);
                    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
                    setGridDisplayPiece(player, player.totalMovePieces.items[data.pieceIndex1]);
                },
                .selectPiece2 => {
                    data.pieceIndex2 = @mod(data.pieceIndex2.? + 1, player.totalMovePieces.items.len);
                    if (data.pieceIndex2.? == data.pieceIndex1) {
                        data.pieceIndex2 = @mod(data.pieceIndex2.? + 1, player.totalMovePieces.items.len);
                    }
                    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
                },
                .selectDirection => {
                    data.direction = @mod(data.direction + 1, 4);
                    const steps = player.shop.gridDisplayPiece.?.steps;
                    if (@mod(data.direction + 1, 4) == steps[steps.len - 1].direction) {
                        data.direction = @mod(data.direction + 1, 4);
                    }
                    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
                },
                .reset => {
                    try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION_FAIL, 0, 0.5);
                },
            }
        },
        else => {
            try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION_FAIL, 0, 0.5);
        },
    }
}

pub fn executeArrowLeft(player: *playerZig.Player, state: *main.GameState) !void {
    switch (player.shop.selectedOption) {
        .delete => |*data| {
            if (data.selectedIndex == 0) {
                data.selectedIndex = player.totalMovePieces.items.len - 1;
            } else {
                data.selectedIndex -= 1;
            }
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
            setGridDisplayPiece(player, player.totalMovePieces.items[data.selectedIndex]);
        },
        .add => |*data| {
            if (data.selectedIndex == 0) {
                data.selectedIndex = player.shop.piecesToBuy.len - 1;
            } else {
                data.selectedIndex -= 1;
            }
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
            setGridDisplayPiece(player, player.shop.piecesToBuy[data.selectedIndex]);
        },
        .cut => |*data| {
            if (data.selectedIndex == 0) {
                data.selectedIndex = player.totalMovePieces.items.len - 1;
            } else {
                data.selectedIndex -= 1;
            }
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
            setGridDisplayPiece(player, player.totalMovePieces.items[data.selectedIndex]);
            data.gridCutOffset = null;
            data.isOnMovePiece = false;
        },
        .combine => |*data| {
            switch (data.combineStep) {
                .selectPiece1 => {
                    if (data.pieceIndex1 == 0) {
                        data.pieceIndex1 = player.totalMovePieces.items.len - 1;
                    } else {
                        data.pieceIndex1 -= 1;
                    }
                    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
                    setGridDisplayPiece(player, player.totalMovePieces.items[data.pieceIndex1]);
                },
                .selectPiece2 => {
                    if (data.pieceIndex2.? == 0) {
                        data.pieceIndex2 = player.totalMovePieces.items.len - 1;
                    } else {
                        data.pieceIndex2.? -= 1;
                    }
                    if (data.pieceIndex2 == data.pieceIndex1) {
                        if (data.pieceIndex2.? == 0) {
                            data.pieceIndex2 = player.totalMovePieces.items.len - 1;
                        } else {
                            data.pieceIndex2.? -= 1;
                        }
                    }
                    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
                },
                .selectDirection => {
                    data.direction = @mod(data.direction + 3, 4);
                    const steps = player.shop.gridDisplayPiece.?.steps;
                    if (@mod(data.direction + 1, 4) == steps[steps.len - 1].direction) {
                        data.direction = @mod(data.direction + 3, 4);
                    }
                    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
                },
                .reset => {
                    try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION_FAIL, 0, 0.5);
                },
            }
        },
        else => {
            try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION_FAIL, 0, 0.5);
        },
    }
}

pub fn executeDeletePiece(player: *playerZig.Player, state: *main.GameState) !void {
    var initialSelectedIndex: usize = 0;
    switch (player.shop.selectedOption) {
        .cut => |data| initialSelectedIndex = data.selectedIndex,
        .combine => |data| initialSelectedIndex = data.pieceIndex1,
        .delete => return,
        else => {},
    }
    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
    player.shop.selectedOption = .{ .delete = .{ .selectedIndex = initialSelectedIndex } };
    setGridDisplayPiece(player, player.totalMovePieces.items[initialSelectedIndex]);
}

pub fn executeCutPiece(player: *playerZig.Player, state: *main.GameState) !void {
    var initialSelectedIndex: usize = 0;
    switch (player.shop.selectedOption) {
        .delete => |data| initialSelectedIndex = data.selectedIndex,
        .combine => |data| initialSelectedIndex = data.pieceIndex1,
        .cut => return,
        else => {},
    }
    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
    player.shop.selectedOption = .{ .cut = .{ .selectedIndex = initialSelectedIndex } };
    setGridDisplayPiece(player, player.totalMovePieces.items[initialSelectedIndex]);
}

pub fn executeCombinePiece(player: *playerZig.Player, state: *main.GameState) !void {
    var initialIndex: usize = 0;
    switch (player.shop.selectedOption) {
        .delete => |data| initialIndex = data.selectedIndex,
        .cut => |data| initialIndex = data.selectedIndex,
        .combine => return,
        else => {},
    }
    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
    player.shop.selectedOption = .{ .combine = .{ .pieceIndex1 = initialIndex } };
    setGridDisplayPiece(player, player.totalMovePieces.items[initialIndex]);
}

pub fn executeAddPiece(player: *playerZig.Player, state: *main.GameState) !void {
    if (player.shop.selectedOption == .add) return;
    player.shop.selectedOption = .{ .add = .{} };
    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
    setGridDisplayPiece(player, player.shop.piecesToBuy[0].?);
}

fn isNextStepButtonVisible(player: *playerZig.Player) bool {
    if (player.shop.selectedOption == .combine) return true;
    return false;
}

fn arrowButtonAlpha(player: *playerZig.Player) f32 {
    if (player.shop.selectedOption == .none) {
        return 0.4;
    }
    if (player.shop.selectedOption == .combine) {
        if (player.shop.selectedOption.combine.combineStep == .reset) {
            return 0.4;
        }
    }
    return 1;
}

pub fn payButtonAlpha(player: *playerZig.Player) f32 {
    if (player.shop.selectedOption == .none) {
        return 0.4;
    }
    if (player.shop.selectedOption == .combine) {
        if (player.shop.selectedOption.combine.combineStep == .selectPiece1 or player.shop.selectedOption.combine.combineStep == .selectPiece2) {
            return 0.4;
        }
    }
    return 1;
}

fn setGridDisplayPiece(player: *playerZig.Player, optMovePiece: ?movePieceZig.MovePiece) void {
    player.shop.gridDisplayPiece = optMovePiece;
    if (optMovePiece) |movePiece| {
        const boundingBox = movePieceZig.getBoundingBox(movePiece);
        const spaceX = @divFloor(GRID_SIZE - boundingBox.width, 2);
        player.shop.gridDisplayPieceOffset.x = spaceX - boundingBox.pos.x;
        const spaceY = @divFloor(GRID_SIZE - boundingBox.height, 2);
        player.shop.gridDisplayPieceOffset.y = spaceY - boundingBox.pos.y;
    }
}
