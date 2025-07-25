const std = @import("std");
const main = @import("main.zig");
const imageZig = @import("image.zig");
const movePieceZig = @import("movePiece.zig");

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

pub const ShopButton = struct {
    tileOffset: main.TilePosition,
    imageIndex: u8,
    imageRotate: f32 = 0,
    option: ShopOption = .none,
    execute: *const fn (player: *main.Player, state: *main.GameState) anyerror!void,
    isVisible: ?*const fn (player: *main.Player) bool = null,
};

pub const GRID_SIZE = 8;
pub const GRID_OFFSET: main.TilePosition = .{ .x = 1, .y = 1 };

pub const ShopPlayerData = struct {
    piecesToBuy: [3]?movePieceZig.MovePiece = [3]?movePieceZig.MovePiece{ null, null, null },
    selectedOption: ShopOptionData = .none,
    pieceShopTopLeft: main.TilePosition = .{ .x = -4, .y = -4 },
    gridDisplayPiece: ?movePieceZig.MovePiece = null,
    gridDisplayPieceOffset: main.TilePosition = .{ .x = 4, .y = 4 },
};

pub const SHOP_BUTTONS = [_]ShopButton{
    .{
        .execute = executeShopPhaseEnd,
        .imageIndex = 0,
        .tileOffset = .{ .x = GRID_SIZE + 3, .y = 0 },
    },
    .{
        .execute = executeAddPiece,
        .imageIndex = imageZig.IMAGE_PLUS,
        .tileOffset = .{ .x = 1, .y = 0 },
        .option = .add,
    },
    .{
        .execute = executeDeletePiece,
        .imageIndex = imageZig.IMAGE_WARNING_TILE,
        .tileOffset = .{ .x = 2, .y = 0 },
        .option = .delete,
    },
    .{
        .execute = executeCutPiece,
        .imageIndex = imageZig.IMAGE_CUT,
        .tileOffset = .{ .x = 3, .y = 0 },
        .option = .cut,
    },
    .{
        .execute = executeCombinePiece,
        .imageIndex = imageZig.IMAGE_COMBINE,
        .tileOffset = .{ .x = 4, .y = 0 },
        .option = .combine,
    },
    .{
        .execute = executeArrowLeft,
        .imageIndex = imageZig.IMAGE_ARROW_RIGHT,
        .imageRotate = std.math.pi,
        .tileOffset = .{ .x = 0, .y = 1 },
    },
    .{
        .execute = executeArrowRight,
        .imageIndex = imageZig.IMAGE_ARROW_RIGHT,
        .tileOffset = .{ .x = 0, .y = 2 },
    },
    .{
        .execute = executePay,
        .imageIndex = imageZig.IMAGE_BORDER_TILE,
        .tileOffset = .{ .x = 0, .y = 5 },
    },
    .{
        .execute = executeNextStep,
        .imageIndex = imageZig.IMAGE_BORDER_TILE,
        .tileOffset = .{ .x = 0, .y = 3 },
        .isVisible = isNextStepButtonVisible,
    },
};

pub fn executeShopActionForPlayer(player: *main.Player, state: *main.GameState) !void {
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
}

pub fn executeGridTile(player: *main.Player, state: *main.GameState) !void {
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

pub fn executeNextStep(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    switch (player.shop.selectedOption) {
        .combine => |*data| {
            switch (data.combineStep) {
                .selectPiece1 => {
                    data.pieceIndex2 = @mod(data.pieceIndex1 + 1, player.totalMovePieces.items.len);
                    data.combineStep = .selectPiece2;
                },
                .selectPiece2 => {
                    data.combineStep = .selectDirection;
                },
                .selectDirection => {
                    data.combineStep = .selectPiece1;
                    data.direction = 0;
                    data.pieceIndex2 = null;
                },
            }
        },
        else => {},
    }
}

pub fn executePay(player: *main.Player, state: *main.GameState) !void {
    switch (player.shop.selectedOption) {
        .delete => |*data| {
            const cost = state.level * 1;
            if (player.money >= cost and player.totalMovePieces.items.len > 1) {
                try movePieceZig.removeMovePiece(player, data.selectedIndex, state.allocator);
                player.money -= cost;
                if (player.totalMovePieces.items.len <= data.selectedIndex) {
                    data.selectedIndex -= 1;
                }
                player.shop.gridDisplayPiece = player.totalMovePieces.items[data.selectedIndex];
            }
        },
        .add => |*data| {
            const cost = state.level * 1;
            if (player.money >= cost and player.totalMovePieces.items.len > 1) {
                player.money -= cost;
                if (player.shop.piecesToBuy[data.selectedIndex]) |buyPiece| {
                    try movePieceZig.addMovePiece(player, buyPiece);
                    player.shop.piecesToBuy[data.selectedIndex] = try movePieceZig.createRandomMovePiece(state.allocator);
                    player.shop.gridDisplayPiece = player.shop.piecesToBuy[data.selectedIndex];
                }
            }
        },
        .cut => |*data| {
            const cost = state.level * 1;
            if (player.money >= cost and data.gridCutOffset != null and player.shop.gridDisplayPiece != null) {
                player.money -= cost;
                try movePieceZig.cutTilePositionOnMovePiece(player, data.gridCutOffset.?, player.shop.gridDisplayPieceOffset, data.selectedIndex, state);
                data.gridCutOffset = null;
                player.shop.gridDisplayPiece = player.totalMovePieces.items[data.selectedIndex];
            }
        },
        .combine => |*data| {
            const cost = state.level * 1;
            if (player.money >= cost and data.pieceIndex2 != null and data.combineStep == .selectDirection) {
                player.money -= cost;
                try movePieceZig.combineMovePieces(player, data.pieceIndex1, data.pieceIndex2.?, data.direction, state);
                if (data.pieceIndex1 > data.pieceIndex2.?) {
                    data.pieceIndex1 -= 1;
                }
                player.shop.gridDisplayPiece = player.totalMovePieces.items[data.pieceIndex1];
                data.pieceIndex2 = null;
                data.combineStep = .selectPiece1;
            }
        },
        else => {},
    }
}

pub fn executeArrowRight(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    switch (player.shop.selectedOption) {
        .delete => |*data| {
            data.selectedIndex = @min(data.selectedIndex + 1, player.totalMovePieces.items.len - 1);
            player.shop.gridDisplayPiece = player.totalMovePieces.items[data.selectedIndex];
        },
        .add => |*data| {
            data.selectedIndex = @min(data.selectedIndex + 1, player.shop.piecesToBuy.len - 1);
            player.shop.gridDisplayPiece = player.shop.piecesToBuy[data.selectedIndex];
        },
        .cut => |*data| {
            data.selectedIndex = @min(data.selectedIndex + 1, player.totalMovePieces.items.len - 1);
            player.shop.gridDisplayPiece = player.totalMovePieces.items[data.selectedIndex];
            data.gridCutOffset = null;
            data.isOnMovePiece = false;
        },
        .combine => |*data| {
            switch (data.combineStep) {
                .selectPiece1 => {
                    data.pieceIndex1 = @min(data.pieceIndex1 + 1, player.totalMovePieces.items.len - 1);
                    player.shop.gridDisplayPiece = player.totalMovePieces.items[data.pieceIndex1];
                },
                .selectPiece2 => {
                    data.pieceIndex2 = @min(data.pieceIndex2.? + 1, player.totalMovePieces.items.len - 1);
                    if (data.pieceIndex2 == data.pieceIndex1) {
                        data.pieceIndex2.? -|= 1;
                    }
                },
                .selectDirection => {
                    data.direction = @mod(data.direction + 1, 4);
                },
            }
        },
        else => {},
    }
}

pub fn executeArrowLeft(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    switch (player.shop.selectedOption) {
        .delete => |*data| {
            data.selectedIndex = data.selectedIndex -| 1;
            player.shop.gridDisplayPiece = player.totalMovePieces.items[data.selectedIndex];
        },
        .add => |*data| {
            data.selectedIndex = data.selectedIndex -| 1;
            player.shop.gridDisplayPiece = player.shop.piecesToBuy[data.selectedIndex];
        },
        .cut => |*data| {
            data.selectedIndex = data.selectedIndex -| 1;
            player.shop.gridDisplayPiece = player.totalMovePieces.items[data.selectedIndex];
            data.gridCutOffset = null;
            data.isOnMovePiece = false;
        },
        .combine => |*data| {
            switch (data.combineStep) {
                .selectPiece1 => {
                    data.pieceIndex1 = data.pieceIndex1 -| 1;
                    player.shop.gridDisplayPiece = player.totalMovePieces.items[data.pieceIndex1];
                },
                .selectPiece2 => {
                    data.pieceIndex2 = data.pieceIndex2.? -| 1;
                    if (data.pieceIndex2 == data.pieceIndex1) {
                        if (data.pieceIndex2 == 0) {
                            data.pieceIndex2 = @min(data.pieceIndex2.? + 1, player.totalMovePieces.items.len - 1);
                        } else {
                            data.pieceIndex2 = data.pieceIndex2.? -| 1;
                        }
                    }
                },
                .selectDirection => {
                    data.direction = @mod(data.direction + 3, 4);
                },
            }
        },
        else => {},
    }
}

pub fn executeDeletePiece(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    player.shop.selectedOption = .{ .delete = .{} };
    player.shop.gridDisplayPiece = player.totalMovePieces.items[0];
}

pub fn executeCutPiece(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    player.shop.selectedOption = .{ .cut = .{} };
    player.shop.gridDisplayPiece = player.totalMovePieces.items[0];
}

pub fn executeCombinePiece(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    player.shop.selectedOption = .{ .combine = .{} };
    player.shop.gridDisplayPiece = player.totalMovePieces.items[0];
}

pub fn executeAddPiece(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    player.shop.selectedOption = .{ .add = .{} };
    player.shop.gridDisplayPiece = player.shop.piecesToBuy[0].?;
}

pub fn executeShopPhaseEnd(player: *main.Player, state: *main.GameState) !void {
    _ = player;
    try main.endShoppingPhase(state);
}

fn isNextStepButtonVisible(player: *main.Player) bool {
    if (player.shop.selectedOption == .combine) return true;
    return false;
}
