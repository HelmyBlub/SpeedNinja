const std = @import("std");
const main = @import("main.zig");
const imageZig = @import("image.zig");
const movePieceZig = @import("movePiece.zig");

const ShopOption = enum {
    none,
    add,
    delete,
};

const ShopOptionData = union(ShopOption) {
    none,
    add: struct {
        selectedIndex: usize,
    },
    delete,
};

pub const ShopButton = struct {
    tileOffset: main.TilePosition,
    imageIndex: u8,
    imageRotate: f32 = 0,
    option: ShopOption = .none,
    execute: *const fn (player: *main.Player, state: *main.GameState) anyerror!void,
};

pub const LEFT_BUTTON_OFFSET: main.TilePosition = .{ .x = 0, .y = GRID_SIZE / 2 };
pub const GRID_SIZE = 8;
pub const GRID_OFFSET: main.TilePosition = .{ .x = 1, .y = 1 };
pub const RIGHT_BUTTON_OFFSET: main.TilePosition = .{ .x = GRID_SIZE + 2, .y = GRID_SIZE / 2 };

pub const ShopPlayerData = struct {
    piecesToBuy: [3]?movePieceZig.MovePiece = [3]?movePieceZig.MovePiece{ null, null, null },
    selectedOption: ShopOptionData = .none,
    pieceShopTopLeft: main.TilePosition = .{ .x = -4, .y = -4 },
    gridDisplayPiece: ?movePieceZig.MovePiece = null,
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
};

pub fn executeShopActionForPlayer(player: *main.Player, state: *main.GameState) !void {
    const playerTile: main.TilePosition = .{
        .x = @intFromFloat(@floor((player.position.x + main.TILESIZE / 2) / main.TILESIZE)),
        .y = @intFromFloat(@floor((player.position.y + main.TILESIZE / 2) / main.TILESIZE)),
    };
    const shopTopLeftTile = player.shop.pieceShopTopLeft;
    for (SHOP_BUTTONS) |shopButton| {
        const checkPosition: main.TilePosition = .{ .x = shopButton.tileOffset.x + shopTopLeftTile.x, .y = shopButton.tileOffset.y + shopTopLeftTile.y };
        if (checkPosition.x == playerTile.x and checkPosition.y == playerTile.y) {
            try shopButton.execute(player, state);
            return;
        }
    }
}

pub fn executeArrowRight(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    _ = player;
    std.debug.print("shop arrow right\n", .{});
}

pub fn executeArrowLeft(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    _ = player;
    std.debug.print("shop arrow left\n", .{});
}

pub fn executeDeletePiece(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    std.debug.print("shop delete\n", .{});
    player.shop.selectedOption = .delete;
}

pub fn executeAddPiece(player: *main.Player, state: *main.GameState) !void {
    _ = state;
    std.debug.print("shop add\n", .{});
    player.shop.selectedOption = .{ .add = .{ .selectedIndex = 0 } };
}

pub fn executeShopPhaseEnd(player: *main.Player, state: *main.GameState) !void {
    _ = player;
    std.debug.print("shop phase end\n", .{});
    try main.endShoppingPhase(state);
}
