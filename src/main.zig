const std = @import("std");
const windowSdlZig = @import("windowSdl.zig");
const initVulkanZig = @import("vulkan/initVulkan.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const movePieceZig = @import("movePiece.zig");
const ninjaDogVulkanZig = @import("vulkan/ninjaDogVulkan.zig");
const soundMixerZig = @import("soundMixer.zig");
const enemyZig = @import("enemy/enemy.zig");
const enemyProjectileZig = @import("enemy/enemyProjectile.zig");
const shopZig = @import("shop.zig");
const bossZig = @import("boss/boss.zig");

pub const GamePhase = enum {
    combat,
    shopping,
    boss,
};

pub const TILESIZE = 20;
pub const BASE_MAP_TILE_RADIUS = 3;
pub const GameState = struct {
    vkState: initVulkanZig.VkState = .{},
    allocator: std.mem.Allocator = undefined,
    camera: Camera = .{ .position = .{ .x = 0, .y = 0 }, .zoom = 1 },
    gameTime: i64 = 0,
    round: u32 = 1,
    level: u32 = 1,
    roundToReachForNextLevel: usize = 5,
    bonusTimePerRoundFinished: i32 = 5000,
    minimalTimePerRequiredRounds: i32 = 35_000,
    levelInitialTime: i32 = 60_000,
    roundEndTimeMS: i64 = 0,
    mapTileRadius: u32 = BASE_MAP_TILE_RADIUS,
    bosses: std.ArrayList(bossZig.Boss) = undefined,
    enemies: std.ArrayList(enemyZig.Enemy) = undefined,
    enemyDeath: std.ArrayList(enemyZig.EnemyDeathAnimation) = undefined,
    enemySpawnData: enemyZig.EnemySpawnData = undefined,
    enemyProjectiles: std.ArrayList(enemyProjectileZig.EnemyProjectile) = undefined,
    players: std.ArrayList(Player),
    soundMixer: ?soundMixerZig.SoundMixer = null,
    gameEnded: bool = false,
    gamePhase: GamePhase = .combat,
};

pub const Player = struct {
    position: Position = .{ .x = 0, .y = 0 },
    executeMovePiece: ?movePieceZig.MovePiece = null,
    executeDirection: u8 = 0,
    afterImages: std.ArrayList(AfterImage),
    choosenMoveOptionIndex: ?usize = null,
    choosenMoveOptionVisualizationOverlapping: bool = false,
    moveOptions: std.ArrayList(movePieceZig.MovePiece),
    totalMovePieces: std.ArrayList(movePieceZig.MovePiece),
    availableMovePieces: std.ArrayList(movePieceZig.MovePiece),
    paintData: ninjaDogVulkanZig.NinjaDogPaintData = .{},
    animateData: ninjaDogVulkanZig.NinjaDogAnimationStateData = .{},
    slashedLastMoveTile: bool = false,
    money: u32 = 0,
    hp: u32 = 1,
    shop: shopZig.ShopPlayerData = .{},
};

pub const AfterImage = struct {
    paintData: ninjaDogVulkanZig.NinjaDogPaintData,
    position: Position,
    deleteTime: i64,
};

pub const Position = struct {
    x: f32,
    y: f32,
};

pub const TilePosition = struct {
    x: i32,
    y: i32,
};

pub const Camera = struct {
    position: Position,
    zoom: f32,
};

pub const TileRectangle = struct {
    pos: TilePosition,
    width: i32,
    height: i32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try startGame(allocator);
}

pub fn playerHit(player: *Player, state: *GameState) !void {
    player.hp -|= 1;
    try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_PLAYER_HIT, 0);
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
        if (state.enemies.items.len == 0 and state.gamePhase == .combat) {
            try startNextRound(state);
        } else if (shouldEndLevel(state)) {
            if (state.gamePhase == .boss) {
                for (state.players.items) |*player| {
                    player.money += state.level * 10;
                }
            }
            try shopZig.startShoppingPhase(state);
        } else if (shouldRestart(state)) {
            try restart(state);
        }
        try windowSdlZig.handleEvents(state);
        for (state.players.items) |*player| {
            try movePieceZig.tickPlayerMovePiece(player, state);
            try ninjaDogVulkanZig.tickNinjaDogAnimation(player, passedTime, state);
        }
        try enemyZig.tickEnemies(state);
        try bossZig.tickBosses(state, passedTime);
        try paintVulkanZig.drawFrame(state);
        std.Thread.sleep(5_000_000);
        lastTime = currentTime;
        currentTime = std.time.milliTimestamp();
        passedTime = currentTime - lastTime;
        if (passedTime > 16) {
            passedTime = 16;
        }
        state.gameTime += passedTime;
    }
}

pub fn startNextRound(state: *GameState) !void {
    state.enemies.clearRetainingCapacity();
    if (state.round == 1) {
        state.roundEndTimeMS = state.gameTime + state.levelInitialTime;
    } else {
        state.roundEndTimeMS += state.bonusTimePerRoundFinished;
    }
    if (state.roundEndTimeMS < state.gameTime + state.minimalTimePerRequiredRounds and state.round < state.roundToReachForNextLevel) {
        state.roundEndTimeMS = state.gameTime + state.minimalTimePerRequiredRounds;
    }
    state.round += 1;
    if (state.round > 1) {
        for (state.players.items) |*player| {
            player.money += state.level;
        }
    }
    try enemyZig.setupEnemies(state);
    adjustZoom(state);
}

pub fn endShoppingPhase(state: *GameState) !void {
    state.gamePhase = .combat;
    try startNextLevel(state);
}

pub fn startNextLevel(state: *GameState) !void {
    state.enemies.clearRetainingCapacity();
    state.enemyProjectiles.clearRetainingCapacity();
    state.gamePhase = .combat;
    state.level += 1;
    state.round = 0;
    bossZig.clearBosses(state);
    for (state.players.items) |*player| {
        try movePieceZig.resetPieces(player);
    }
    try enemyZig.setupSpawnEnemiesOnLevelChange(state);
    if (bossZig.isBossLevel(state.level)) {
        try bossZig.startBossLevel(state);
    } else {
        try startNextRound(state);
    }
}

fn shouldEndLevel(state: *GameState) bool {
    if (state.gamePhase == .combat and state.round >= state.roundToReachForNextLevel and state.roundEndTimeMS < state.gameTime) return true;
    if (state.gamePhase == .boss and state.bosses.items.len == 0) return true;
    return false;
}

fn shouldRestart(state: *GameState) bool {
    if (state.gamePhase == .shopping) return false;
    if (allPlayerOutOfMoveOptions(state)) return true;
    if (allPlayerNoHp(state)) return true;
    if (state.round > 1 and state.roundEndTimeMS < state.gameTime) return true;
    return false;
}

fn allPlayerNoHp(state: *GameState) bool {
    for (state.players.items) |player| {
        if (player.hp > 0) return false;
    }
    return true;
}

fn allPlayerOutOfMoveOptions(state: *GameState) bool {
    for (state.players.items) |player| {
        if (player.moveOptions.items.len > 0) return false;
        if (player.executeMovePiece != null) return false;
    }
    return true;
}

pub fn restart(state: *GameState) !void {
    state.level = 0;
    state.round = 0;
    state.mapTileRadius = BASE_MAP_TILE_RADIUS;
    state.gamePhase = .combat;
    state.gameTime = 0;
    for (state.players.items) |*player| {
        player.hp = 3;
        player.money = 0;
        player.position.x = 0;
        player.position.y = 0;
        player.afterImages.clearRetainingCapacity();
        player.animateData = .{};
        player.paintData = .{};
        player.executeMovePiece = null;
        player.shop.gridDisplayPiece = null;
        player.shop.selectedOption = .none;

        try movePieceZig.setupMovePieces(player, state);
    }
    bossZig.clearBosses(state);
    state.enemyDeath.clearRetainingCapacity();
    try startNextLevel(state);
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
        .players = std.ArrayList(Player).init(allocator),
        .bosses = std.ArrayList(bossZig.Boss).init(allocator),
    };
    state.allocator = allocator;
    try windowSdlZig.initWindowSdl();
    try initVulkanZig.initVulkan(state);
    try soundMixerZig.createSoundMixer(state, state.allocator);
    try enemyZig.initEnemy(state);
    try state.players.append(createPlayer(allocator));
    try restart(state);
}

fn createPlayer(allocator: std.mem.Allocator) Player {
    return .{
        .moveOptions = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .availableMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .totalMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
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
        if (player.totalMovePieces.items.len > 0) {
            for (player.totalMovePieces.items) |movePiece| {
                state.allocator.free(movePiece.steps);
            }
        }
        player.totalMovePieces.deinit();
        player.afterImages.deinit();
        for (player.shop.piecesToBuy) |optPiece| {
            if (optPiece) |piece| {
                state.allocator.free(piece.steps);
            }
        }
    }
    state.players.deinit();
    for (state.bosses.items) |*boss| {
        const levelBossData = bossZig.LEVEL_BOSS_DATA[boss.dataIndex];
        if (levelBossData.deinit) |deinit| deinit(boss, state.allocator);
    }
    state.bosses.deinit();
    enemyZig.destroyEnemy(state);
}

pub fn calculateDistance(pos1: Position, pos2: Position) f32 {
    const diffX = pos1.x - pos2.x;
    const diffY = pos1.y - pos2.y;
    return @floatCast(@sqrt(diffX * diffX + diffY * diffY));
}

pub fn isTilePositionInTileRectangle(tilePosition: TilePosition, tileRectangle: TileRectangle) bool {
    return tileRectangle.pos.x <= tilePosition.x and tileRectangle.pos.x + tileRectangle.width > tilePosition.x and
        tileRectangle.pos.y <= tilePosition.y and tileRectangle.pos.y + tileRectangle.height > tilePosition.y;
}

pub fn gamePositionToTilePosition(position: Position) TilePosition {
    return .{
        .x = @intFromFloat(@floor((position.x + TILESIZE / 2) / TILESIZE)),
        .y = @intFromFloat(@floor((position.y + TILESIZE / 2) / TILESIZE)),
    };
}

pub fn tilePositionToGamePosition(tilePosition: TilePosition) Position {
    return .{
        .x = @as(f32, @floatFromInt(tilePosition.x * TILESIZE)),
        .y = @as(f32, @floatFromInt(tilePosition.y * TILESIZE)),
    };
}
