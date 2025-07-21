const std = @import("std");
const windowSdlZig = @import("windowSdl.zig");
const initVulkanZig = @import("vulkan/initVulkan.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const movePieceZig = @import("movePiece.zig");
const ninjaDogVulkanZig = @import("vulkan/ninjaDogVulkan.zig");
const soundMixerZig = @import("soundMixer.zig");

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
    players: std.ArrayList(Player),
    highscore: u32 = 0,
    lastScore: u32 = 0,
    soundMixer: ?soundMixerZig.SoundMixer = null,
    gameEnded: bool = false,
};

pub const Player = struct {
    position: Position = .{ .x = 0, .y = 0 },
    executeMovePiece: ?movePieceZig.MovePiece = null,
    executeDirection: u8 = 0,
    afterImages: std.ArrayList(AfterImage),
    choosenMoveOptionIndex: ?usize = null,
    moveOptions: std.ArrayList(movePieceZig.MovePiece),
    usedMovePieces: std.ArrayList(movePieceZig.MovePiece),
    availableMovePieces: std.ArrayList(movePieceZig.MovePiece),
    paintData: ninjaDogVulkanZig.NinjaDogPaintData = .{},
    animateData: ninjaDogVulkanZig.NinjaDogAnimationStateData = .{},
    slashedLastMoveTile: bool = false,
};

pub const AfterImage = struct {
    paintData: ninjaDogVulkanZig.NinjaDogPaintData,
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
    var state: GameState = undefined;
    try createGameState(&state, allocator);
    defer destroyGameState(&state);
    try mainLoop(&state);
}

fn mainLoop(state: *GameState) !void {
    var lastTime = std.time.milliTimestamp();
    var currentTime = lastTime;
    var passedTime: i64 = 0;
    while (!state.gameEnded) {
        if (state.enemies.items.len == 0) {
            state.roundEndTimeMS = state.gameTime + 30_000;
            state.round += 1;
            state.mapTileRadius = BASE_MAP_TILE_RADIUS + @as(u32, @intFromFloat(@sqrt(@as(f32, @floatFromInt(state.round)))));
            adjustZoom(state);
            try setupEnemies(state);
        }
        if (shouldRestart(state)) {
            try restart(state);
        }
        try windowSdlZig.handleEvents(state);
        for (state.players.items) |*player| {
            try movePieceZig.tickPlayerMovePiece(player, state);
            try ninjaDogVulkanZig.tickNinjaDogAnimation(player, passedTime, state);
        }
        try paintVulkanZig.drawFrame(state);
        std.Thread.sleep(5_000_000);
        lastTime = currentTime;
        currentTime = std.time.milliTimestamp();
        passedTime = currentTime - lastTime;
        state.gameTime += passedTime;
    }
}

fn shouldRestart(state: *GameState) bool {
    return (state.round > 1 and state.roundEndTimeMS < state.gameTime) or allPlayerOutOfMoveOptions(state);
}

fn allPlayerOutOfMoveOptions(state: *GameState) bool {
    for (state.players.items) |player| {
        if (player.moveOptions.items.len > 0) return false;
        if (player.executeMovePiece != null) return false;
    }
    return true;
}

pub fn restart(state: *GameState) !void {
    state.lastScore = state.round;
    if (state.round > state.highscore) state.highscore = state.round;
    state.round = 1;
    state.mapTileRadius = BASE_MAP_TILE_RADIUS;
    state.gameTime = 0;
    adjustZoom(state);
    for (state.players.items) |*player| {
        player.position.x = 0;
        player.position.y = 0;
        player.afterImages.clearRetainingCapacity();
        player.animateData = .{};
        player.paintData = .{};
        player.executeMovePiece = null;
        try movePieceZig.resetPieces(player);
    }

    state.enemyDeath.clearRetainingCapacity();
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

fn createGameState(state: *GameState, allocator: std.mem.Allocator) !void {
    state.* = .{
        .movePieces = movePieceZig.createMovePieces(),
        .players = std.ArrayList(Player).init(allocator),
        .enemyDeath = std.ArrayList(EnemyDeathAnimation).init(allocator),
        .enemies = std.ArrayList(Position).init(allocator),
    };
    state.allocator = allocator;
    try state.players.append(createPlayer(allocator));
    try windowSdlZig.initWindowSdl();
    try initVulkanZig.initVulkan(state);
    try movePieceZig.setupMovePieces(&state.players.items[0], state);
    try setupEnemies(state);
    try soundMixerZig.createSoundMixer(state, state.allocator);
    adjustZoom(state);
}

fn createPlayer(allocator: std.mem.Allocator) Player {
    return .{
        .moveOptions = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .availableMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .usedMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .afterImages = std.ArrayList(AfterImage).init(allocator),
    };
}

fn destroyGameState(state: *GameState) void {
    initVulkanZig.destroyPaintVulkan(&state.vkState, state.allocator) catch {
        std.debug.print("failed to destroy window and vulkan\n", .{});
    };
    soundMixerZig.destroySoundMixer(state);
    windowSdlZig.destroyWindowSdl();
    for (state.players.items) |player| {
        player.moveOptions.deinit();
        player.availableMovePieces.deinit();
        player.usedMovePieces.deinit();
        player.afterImages.deinit();
    }
    state.players.deinit();
    state.enemyDeath.deinit();
    state.enemies.deinit();
}

fn setupEnemies(state: *GameState) !void {
    state.enemies.clearRetainingCapacity();
    const rand = std.crypto.random;
    const length: f32 = @floatFromInt(state.mapTileRadius * 2 + 1);
    const enemyCount = state.round;
    while (state.enemies.items.len < enemyCount) {
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
    for (state.players.items) |player| {
        if (@abs(player.position.x - position.x) < TILESIZE / 2 and @abs(player.position.y - position.y) < TILESIZE / 2) return false;
    }
    return true;
}

pub fn calculateDistance(pos1: Position, pos2: Position) f32 {
    const diffX = pos1.x - pos2.x;
    const diffY = pos1.y - pos2.y;
    return @floatCast(@sqrt(diffX * diffX + diffY * diffY));
}
