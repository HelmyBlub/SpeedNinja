const std = @import("std");
const windowSdlZig = @import("windowSdl.zig");
const initVulkanZig = @import("vulkan/initVulkan.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const movePieceZig = @import("movePiece.zig");

pub const TILESIZE = 20;
pub const GameState = struct {
    vkState: initVulkanZig.VkState = .{},
    allocator: std.mem.Allocator = undefined,
    camera: Camera = .{ .position = .{ .x = 0, .y = 0 }, .zoom = 1 },
    movePieces: []const movePieceZig.MovePiece,
    round: u32 = 1,
    roundEndTime: ?i64 = null,
    mapTileRadius: u32 = 16,
    enemies: std.ArrayList(Position),
    player: Player,
    highscore: u32 = 0,
    lastScore: u32 = 0,
    gameEnded: bool = false,
};

pub const Player = struct {
    position: Position = .{ .x = 0, .y = 0 },
    choosenMoveOptionIndex: ?usize = null,
    moveOptions: std.ArrayList(movePieceZig.MovePiece),
    usedMovePieces: std.ArrayList(movePieceZig.MovePiece),
    availableMovePieces: std.ArrayList(movePieceZig.MovePiece),
};

pub const Position: type = struct {
    x: f32,
    y: f32,
};

pub const Camera: type = struct {
    position: Position,
    zoom: f32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try startGame(allocator);
}

fn startGame(allocator: std.mem.Allocator) !void {
    std.debug.print("game run start\n", .{});
    var state: GameState = try createGameState(allocator);
    defer destroyGameState(&state);
    try mainLoop(&state);
}

fn mainLoop(state: *GameState) !void {
    while (!state.gameEnded) {
        if (state.enemies.items.len == 0) {
            state.roundEndTime = std.time.timestamp() + 30;
            state.round += 1;
            try setupEnemies(state);
        }
        if (state.roundEndTime != null and state.roundEndTime.? < std.time.timestamp()) {
            state.roundEndTime = null;
            state.lastScore = state.round;
            if (state.round > state.highscore) state.highscore = state.round;
            state.round = 1;
            try movePieceZig.resetPieces(state);
            try setupEnemies(state);
        }
        try windowSdlZig.handleEvents(state);
        try paintVulkanZig.drawFrame(state);
        std.Thread.sleep(5_000_000);
    }
}

fn createGameState(allocator: std.mem.Allocator) !GameState {
    var state: GameState = .{
        .movePieces = movePieceZig.createMovePieces(),
        .player = .{
            .moveOptions = std.ArrayList(movePieceZig.MovePiece).init(allocator),
            .availableMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
            .usedMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        },
        .enemies = std.ArrayList(Position).init(allocator),
    };
    state.allocator = allocator;
    try windowSdlZig.initWindowSdl();
    try initVulkanZig.initVulkan(&state);
    try movePieceZig.setupMovePieces(&state);
    try setupEnemies(&state);

    return state;
}

fn destroyGameState(state: *GameState) void {
    initVulkanZig.destroyPaintVulkan(&state.vkState, state.allocator) catch {
        std.debug.print("failed to destroy window and vulkan\n", .{});
    };
    windowSdlZig.destroyWindowSdl();
    state.player.moveOptions.deinit();
    state.player.availableMovePieces.deinit();
    state.player.usedMovePieces.deinit();
    state.enemies.deinit();
}

fn setupEnemies(state: *GameState) !void {
    state.enemies.clearRetainingCapacity();
    const rand = std.crypto.random;
    const length = 16;
    for (0..state.round) |_| {
        const randomTileX: i16 = @as(i16, @intFromFloat(rand.float(f32) * length)) - length / 2;
        const randomTileY: i16 = @as(i16, @intFromFloat(rand.float(f32) * length)) - length / 2;
        try state.enemies.append(.{
            .x = @floatFromInt(randomTileX * TILESIZE),
            .y = @floatFromInt(randomTileY * TILESIZE),
        });
    }
}
