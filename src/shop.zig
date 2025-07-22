const std = @import("std");
const main = @import("main.zig");
const imageZig = @import("image.zig");
const movePieceZig = @import("movePiece.zig");

const ShopOption = enum {
    none,
    add,
    delete,
};

pub const LEFT_BUTTON_OFFSET: main.TilePosition = .{ .x = 0, .y = GIRD_SIZE / 2 };
pub const ADD_BUTTON_OFFSET: main.TilePosition = .{ .x = 1, .y = 0 };
pub const DELETE_BUTTON_OFFSET: main.TilePosition = .{ .x = 2, .y = 0 };
pub const GIRD_SIZE = 8;
pub const GRID_OFFSET: main.TilePosition = .{ .x = 1, .y = 1 };
pub const RIGHT_BUTTON_OFFSET: main.TilePosition = .{ .x = GIRD_SIZE + 2, .y = GIRD_SIZE / 2 };
pub const START_NEXT_LEVEL_BUTTON_OFFSET: main.TilePosition = .{ .x = GIRD_SIZE + 3, .y = 0 };

pub const ShopPlayerData = struct {
    piecesToBuy: []movePieceZig.MovePiece,
    selectedOption: ShopOption = .none,
    pieceShopTopLeft: main.TilePosition,
};

pub fn executeShopActionForPlayer(player: *main.Player, state: *main.GameState) !void {
    const playerTile: main.TilePosition = .{
        .x = @intFromFloat((player.position.x + main.TILESIZE / 2) / main.TILESIZE),
        .y = @intFromFloat((player.position.y + main.TILESIZE / 2) / main.TILESIZE),
    };
    const shopTopLeftTIle = player.shop.pieceShopTopLeft;
    var checkPosition: main.TilePosition = .{ .x = ADD_BUTTON_OFFSET.x + shopTopLeftTIle.x, .y = ADD_BUTTON_OFFSET.y + shopTopLeftTIle.y };
    if (checkPosition.x == playerTile.x and checkPosition.y == playerTile.y) {
        player.shop.selectedOption = .add;
        return;
    }
    checkPosition = .{ .x = DELETE_BUTTON_OFFSET.x + shopTopLeftTIle.x, .y = DELETE_BUTTON_OFFSET.y + shopTopLeftTIle.y };
    if (checkPosition.x == playerTile.x and checkPosition.y == playerTile.y) {
        player.shop.selectedOption = .delete;
        return;
    }
    checkPosition = .{ .x = START_NEXT_LEVEL_BUTTON_OFFSET.x + shopTopLeftTIle.x, .y = START_NEXT_LEVEL_BUTTON_OFFSET.y + shopTopLeftTIle.y };
    if (checkPosition.x == playerTile.x and checkPosition.y == playerTile.y) {
        try main.endShoppingPhase(state);
        return;
    }
}
