const std = @import("std");
const windowSdlZig = @import("windowSdl.zig");
const initVulkanZig = @import("vulkan/initVulkan.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const movePieceZig = @import("movePiece.zig");

pub const TILESIZE = 20;
pub const BASE_MAP_TILE_RADIUS = 3;
pub const GameState = struct {
    vkState: initVulkanZig.VkState = .{},
    allocator: std.mem.Allocator = undefined,
    camera: Camera = .{ .position = .{ .x = 0, .y = 0 }, .zoom = 1 },
    movePieces: []const movePieceZig.MovePiece,
    gameTime: i64 = 0,
    round: u32 = 1,
    roundEndTimeMS: i64 = 30_000,
    mapTileRadius: u32 = BASE_MAP_TILE_RADIUS,
    enemies: std.ArrayList(Position),
    enemyDeath: std.ArrayList(EnemyDeathAnimation),
    player: Player,
    highscore: u32 = 0,
    lastScore: u32 = 0,
    gameEnded: bool = false,
};

pub const Player = struct {
    position: Position = .{ .x = 0, .y = 0 },
    executeMovePice: ?movePieceZig.MovePiece = null,
    executeDirection: u8 = 0,
    afterImages: std.ArrayList(AfterImage),
    choosenMoveOptionIndex: ?usize = null,
    moveOptions: std.ArrayList(movePieceZig.MovePiece),
    usedMovePieces: std.ArrayList(movePieceZig.MovePiece),
    availableMovePieces: std.ArrayList(movePieceZig.MovePiece),
};

pub const AfterImage = struct {
    position: Position,
    deleteTime: i64,
};

pub const EnemyDeathAnimation = struct {
    position: Position,
    deathTime: i64,
    cutAngle: f32,
    force: f32,
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
    var lastTime = std.time.milliTimestamp();
    var currentTime = lastTime;
    while (!state.gameEnded) {
        if (state.enemies.items.len == 0) {
            state.roundEndTimeMS = state.gameTime + 30_000;
            state.round += 1;
            state.mapTileRadius = BASE_MAP_TILE_RADIUS + @as(u32, @intFromFloat(@sqrt(@as(f32, @floatFromInt(state.round)))));
            adjustZoom(state);
            try setupEnemies(state);
        }
        if ((state.round > 1 and state.roundEndTimeMS < state.gameTime) or state.player.moveOptions.items.len == 0) {
            try restart(state);
        }
        try windowSdlZig.handleEvents(state);
        try movePieceZig.tickPlayerMovePiece(state);
        try paintVulkanZig.drawFrame(state);
        std.Thread.sleep(5_000_000);
        lastTime = currentTime;
        currentTime = std.time.milliTimestamp();
        state.gameTime += currentTime - lastTime;
    }
}

pub fn restart(state: *GameState) !void {
    state.lastScore = state.round;
    if (state.round > state.highscore) state.highscore = state.round;
    state.round = 1;
    state.mapTileRadius = BASE_MAP_TILE_RADIUS;
    state.gameTime = 0;
    adjustZoom(state);
    state.player.position.x = 0;
    state.player.position.y = 0;
    state.player.afterImages.clearRetainingCapacity();
    state.enemyDeath.clearRetainingCapacity();
    state.player.executeMovePice = null;
    try movePieceZig.resetPieces(state);
    try setupEnemies(state);
}

pub fn adjustZoom(state: *GameState) void {
    const mapSize: f32 = @floatFromInt((state.mapTileRadius * 2 + 1) * TILESIZE);
    const targetMapScreenPerCent = 0.75;
    const widthPerCent = mapSize / windowSdlZig.windowData.widthFloat;
    const heightPerCent = mapSize / windowSdlZig.windowData.heightFloat;
    const biggerPerCent = @max(widthPerCent, heightPerCent);
    state.camera.zoom = targetMapScreenPerCent / biggerPerCent;
}

fn createGameState(allocator: std.mem.Allocator) !GameState {
    var state: GameState = .{
        .movePieces = movePieceZig.createMovePieces(),
        .player = .{
            .moveOptions = std.ArrayList(movePieceZig.MovePiece).init(allocator),
            .availableMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
            .usedMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
            .afterImages = std.ArrayList(AfterImage).init(allocator),
        },
        .enemyDeath = std.ArrayList(EnemyDeathAnimation).init(allocator),
        .enemies = std.ArrayList(Position).init(allocator),
    };
    state.allocator = allocator;
    try windowSdlZig.initWindowSdl();
    try initVulkanZig.initVulkan(&state);
    try movePieceZig.setupMovePieces(&state);
    try setupEnemies(&state);
    adjustZoom(&state);

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
    state.player.afterImages.deinit();
    state.enemyDeath.deinit();
    state.enemies.deinit();
}

fn setupEnemies(state: *GameState) !void {
    state.enemies.clearRetainingCapacity();
    const rand = std.crypto.random;
    const length: f32 = @floatFromInt(state.mapTileRadius * 2 + 1);
    while (state.enemies.items.len < state.round) {
        const randomTileX: i16 = @as(i16, @intFromFloat(rand.float(f32) * length - length / 2));
        const randomTileY: i16 = @as(i16, @intFromFloat(rand.float(f32) * length - length / 2));
        const randomPos: Position = .{
            .x = @floatFromInt(randomTileX * TILESIZE),
            .y = @floatFromInt(randomTileY * TILESIZE),
        };
        if (canSpawnEnemyOnTile(randomPos, state)) try state.enemies.append(randomPos);
    }
}

fn canSpawnEnemyOnTile(position: Position, state: *GameState) bool {
    for (state.enemies.items) |enemy| {
        if (@abs(enemy.x - position.x) < TILESIZE / 2 and @abs(enemy.y - position.y) < TILESIZE / 2) return false;
    }
    if (@abs(state.player.position.x - position.x) < TILESIZE / 2 and @abs(state.player.position.y - position.y) < TILESIZE / 2) return false;
    return true;
}
