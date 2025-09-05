const std = @import("std");
const windowSdlZig = @import("windowSdl.zig");
const initVulkanZig = @import("vulkan/initVulkan.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const movePieceZig = @import("movePiece.zig");
const ninjaDogVulkanZig = @import("vulkan/ninjaDogVulkan.zig");
const soundMixerZig = @import("soundMixer.zig");
const enemyZig = @import("enemy/enemy.zig");
const enemyObjectZig = @import("enemy/enemyObject.zig");
const shopZig = @import("shop.zig");
const bossZig = @import("boss/boss.zig");
const imageZig = @import("image.zig");
const mapTileZig = @import("mapTile.zig");
const equipmentZig = @import("equipment.zig");

pub const GamePhase = enum {
    combat,
    shopping,
    boss,
};
pub const COLOR_TILE_GREEN: [3]f32 = colorConv(0.533, 0.80, 0.231);
pub const COLOR_SKY_BLUE: [3]f32 = colorConv(0.529, 0.808, 0.922);
pub const COLOR_STONE_WALL: [3]f32 = colorConv(0.573, 0.522, 0.451);

pub const TILESIZE = 20;
pub const GameState = struct {
    vkState: initVulkanZig.VkState = .{},
    allocator: std.mem.Allocator = undefined,
    camera: Camera = .{ .position = .{ .x = 0, .y = 0 }, .zoom = 1 },
    gameTime: i64 = 0,
    round: u32 = 1,
    level: u32 = 1,
    roundToReachForNextLevel: usize = 5,
    bonusTimePerRoundFinished: i32 = 5000,
    minimalTimePerRequiredRounds: i32 = 60_000,
    mapData: mapTileZig.MapData,
    levelInitialTime: i32 = 60_000,
    roundEndTimeMS: i64 = 0,
    roundStartedTime: i64 = 0,
    playerImmunityFrames: i64 = 1000,
    bosses: std.ArrayList(bossZig.Boss) = undefined,
    enemyData: enemyZig.EnemyData = .{},
    spriteCutAnimations: std.ArrayList(CutSpriteAnimation) = undefined,
    mapObjects: std.ArrayList(MapObject) = undefined,
    players: std.ArrayList(Player),
    soundMixer: ?soundMixerZig.SoundMixer = null,
    gameEnded: bool = false,
    gamePhase: GamePhase = .combat,
    shop: shopZig.ShopData,
    lastBossDefeatedTime: i64 = 0,
    timerStarted: bool = false,
};

pub const Player = struct {
    position: Position = .{ .x = 0, .y = 0 },
    damage: u32 = 0,
    damagePerCentFactor: f32 = 1,
    immunUntilTime: i64 = 0,
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
    isDead: bool = false,
    shop: shopZig.ShopPlayerData = .{},
    inAirHeight: f32 = 0,
    fallVelocity: f32 = 0,
    startedFallingState: ?i64 = null,
    fallingStateDamageDelay: i32 = 1500,
    equipment: equipmentZig.EquipmentSlotsData = .{},
    moneyBonusPerCent: f32 = 0,
    hasWeaponHammer: bool = false,
    hasWeaponKunai: bool = false,
    hasBlindfold: bool = false,
};

pub const MapObjectType = enum {
    kunai,
};

pub const MabObjectKunaiData = struct {
    direction: u8,
    speed: f32,
    deleteTime: i64,
};

pub const MapObjectTypeData = union(MapObjectType) {
    kunai: MabObjectKunaiData,
};

pub const MapObject = struct {
    position: Position,
    typeData: MapObjectTypeData,
};

pub const AfterImage = struct {
    paintData: ninjaDogVulkanZig.NinjaDogPaintData,
    position: Position,
    deleteTime: i64,
};

pub const ColorOrImageIndex = enum {
    color,
    imageIndex,
};

pub const ColorOrImageIndexData = union(ColorOrImageIndex) {
    color: [3]f32,
    imageIndex: u8,
};

pub const CutSpriteAnimation = struct {
    position: Position,
    deathTime: i64,
    cutAngle: f32,
    force: f32,
    colorOrImageIndex: ColorOrImageIndexData,
    imageToGameScaleFactor: f32 = 1.0 / @as(f32, @floatFromInt(imageZig.IMAGE_TO_GAME_SIZE)) / 2.0,
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
    if (player.immunUntilTime >= state.gameTime) return;
    if (!try equipmentZig.damageTakenByEquipment(player, state)) {
        player.isDead = true;
    }
    player.immunUntilTime = state.gameTime + state.playerImmunityFrames;
    try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_PLAYER_HIT, 0, 1);
}

pub fn getPlayerDamage(player: *Player) u32 {
    return @as(u32, @intFromFloat(@round(@as(f32, @floatFromInt(player.damage)) * player.damagePerCentFactor)));
}

fn startGame(allocator: std.mem.Allocator) !void {
    std.debug.print("game run start\n", .{});
    var state: GameState = undefined;
    try createGameState(&state, allocator);
    defer destroyGameState(&state);
    try mainLoop(&state);
}

fn debugTextAfterBossLevelFinished(state: *GameState) void {
    std.debug.print("lvl {d} finished in ", .{state.level});
    const secondsPassed = @divFloor(state.gameTime - state.lastBossDefeatedTime, 1000);
    const seconds = @mod(secondsPassed, 60);
    const minutes = @divFloor(secondsPassed, 60);
    if (minutes > 0) std.debug.print("{d}:", .{minutes});
    if (seconds < 10) std.debug.print("0", .{});
    std.debug.print("{d}", .{seconds});
    std.debug.print(" and total ", .{});
    const totalSecondsPassed = @divFloor(state.gameTime, 1000);
    const totalSeconds = @mod(totalSecondsPassed, 60);
    const totalMinutes = @divFloor(totalSecondsPassed, 60);
    if (totalMinutes > 0) std.debug.print("{d}:", .{totalMinutes});
    if (totalSeconds < 10) std.debug.print("0", .{});
    std.debug.print("{d}\n", .{totalSeconds});
}

fn mainLoop(state: *GameState) !void {
    var lastTime = std.time.milliTimestamp();
    var currentTime = lastTime;
    var passedTime: i64 = 0;
    while (!state.gameEnded) {
        if (state.enemyData.enemies.items.len == 0 and state.gamePhase == .combat) {
            try startNextRound(state);
        } else if (shouldEndLevel(state)) {
            if (state.gamePhase == .boss) {
                debugTextAfterBossLevelFinished(state);
                state.lastBossDefeatedTime = state.gameTime;
                for (state.players.items) |*player| {
                    player.money += @as(u32, @intFromFloat(@as(f32, @floatFromInt(state.level)) * 10.0 * (1.0 + player.moneyBonusPerCent)));
                }
            }
            try shopZig.startShoppingPhase(state);
        } else if (shouldRestart(state)) {
            try restart(state);
        }
        try windowSdlZig.handleEvents(state);
        try tickPlayers(state, passedTime);
        tickClouds(state, passedTime);
        try enemyZig.tickEnemies(passedTime, state);
        try bossZig.tickBosses(state, passedTime);
        tickMapObjects(state, passedTime);
        try paintVulkanZig.drawFrame(state);
        std.Thread.sleep(5_000_000);
        lastTime = currentTime;
        currentTime = std.time.milliTimestamp();
        passedTime = currentTime - lastTime;
        if (passedTime > 16) {
            passedTime = 16;
        }
        if (!state.timerStarted) passedTime = 0;
        state.gameTime += passedTime;
    }
}

fn tickMapObjects(state: *GameState, passedTime: i64) void {
    var currentIndex: usize = 0;
    while (currentIndex < state.mapObjects.items.len) {
        const mapObject = &state.mapObjects.items[currentIndex];
        switch (mapObject.typeData) {
            .kunai => |kunaiData| {
                if (kunaiData.deleteTime <= state.gameTime) {
                    _ = state.mapObjects.swapRemove(currentIndex);
                    continue;
                } else {
                    const fPassedTime = @as(f32, @floatFromInt(passedTime)) / 100;
                    const stepDirection = movePieceZig.getStepDirection(kunaiData.direction);
                    mapObject.position.x += stepDirection.x * kunaiData.speed * fPassedTime;
                    mapObject.position.y += stepDirection.y * kunaiData.speed * fPassedTime;
                }
            },
        }
        currentIndex += 1;
    }
}

fn tickPlayers(state: *GameState, passedTime: i64) !void {
    for (state.players.items) |*player| {
        if (player.inAirHeight > 0) {
            const fPassedTime = @as(f32, @floatFromInt(passedTime));
            player.fallVelocity = @min(5, player.fallVelocity + fPassedTime * 0.001);
            player.inAirHeight -= player.fallVelocity * fPassedTime;
            if (player.inAirHeight < 0) {
                player.fallVelocity = 0;
                player.inAirHeight = 0;
            }
        } else {
            try movePieceZig.tickPlayerMovePiece(player, state);
        }
        if (player.startedFallingState) |time| {
            if (state.mapData.mapType == .top) {
                if (time + player.fallingStateDamageDelay <= state.gameTime) {
                    try playerHit(player, state);
                }
            } else {
                player.startedFallingState = null;
            }
        }
        try ninjaDogVulkanZig.tickNinjaDogAnimation(player, passedTime, state);
    }
}

fn tickClouds(state: *GameState, passedTime: i64) void {
    if (state.mapData.mapType != .top) return;
    const fPassedTime: f32 = @floatFromInt(passedTime);
    for (state.mapData.paintData.backClouds[0..]) |*backCloud| {
        if (backCloud.position.x > 600) {
            backCloud.position.x = -600 + std.crypto.random.float(f32) * 200;
            backCloud.position.y = -150 + std.crypto.random.float(f32) * 150;
            backCloud.sizeFactor = 5;
            backCloud.speed = 0.02;
        }
        backCloud.position.x += backCloud.speed * fPassedTime;
    }
    if (state.mapData.paintData.frontCloud.position.x > 1000) {
        state.mapData.paintData.frontCloud.position.x = -800 + std.crypto.random.float(f32) * 300;
        state.mapData.paintData.frontCloud.position.y = -150 + std.crypto.random.float(f32) * 300;
        state.mapData.paintData.frontCloud.sizeFactor = 15;
        state.mapData.paintData.frontCloud.speed = 0.1;
    }

    state.mapData.paintData.frontCloud.position.x += state.mapData.paintData.frontCloud.speed * fPassedTime;
}

pub fn startNextRound(state: *GameState) !void {
    state.enemyData.enemies.clearRetainingCapacity();
    const maxTime = state.gameTime + state.minimalTimePerRequiredRounds;
    if (state.round == 1) {
        state.roundEndTimeMS = state.gameTime + state.levelInitialTime;
    } else {
        state.roundEndTimeMS += state.bonusTimePerRoundFinished;
        if (state.roundEndTimeMS > maxTime) {
            state.roundEndTimeMS = maxTime;
        }
    }
    if (state.roundEndTimeMS < maxTime and state.round < state.roundToReachForNextLevel) {
        state.roundEndTimeMS = maxTime;
    }
    state.roundStartedTime = state.gameTime;
    state.round += 1;
    if (state.round > 1) {
        for (state.players.items) |*player| {
            player.money += @as(u32, @intFromFloat(@ceil(@as(f32, @floatFromInt(state.level)) * (1.0 + player.moneyBonusPerCent))));
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
    mapTileZig.setMapType(.default, state);
    state.camera.position = .{ .x = 0, .y = 0 };
    state.enemyData.enemies.clearRetainingCapacity();
    state.enemyData.enemyObjects.clearRetainingCapacity();
    mapTileZig.resetMapTiles(state.mapData.tiles);
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

pub fn findClosestPlayer(position: Position, state: *GameState) *Player {
    var shortestDistance: f32 = 0;
    var closestPlayer: ?*Player = null;
    for (state.players.items) |*player| {
        const tempDistance = calculateDistance(position, player.position);
        if (closestPlayer == null or tempDistance < shortestDistance) {
            shortestDistance = tempDistance;
            closestPlayer = player;
        }
    }
    return closestPlayer.?;
}

pub fn getDirectionFromTo(fromPosition: Position, toPosition: Position) u8 {
    const diffX = fromPosition.x - toPosition.x;
    const diffY = fromPosition.y - toPosition.y;
    if (@abs(diffX) > @abs(diffY)) {
        return if (diffX > 0) movePieceZig.DIRECTION_LEFT else movePieceZig.DIRECTION_RIGHT;
    } else {
        return if (diffY > 0) movePieceZig.DIRECTION_UP else movePieceZig.DIRECTION_DOWN;
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
        if (!player.isDead) return false;
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
    if (state.gameTime > 1000) {
        std.debug.print("ended on lvl {d} in time: ", .{state.level});
        const totalSecondsPassed = @divFloor(state.gameTime, 1000);
        const totalSeconds = @mod(totalSecondsPassed, 60);
        const totalMinutes = @divFloor(totalSecondsPassed, 60);
        if (totalMinutes > 0) std.debug.print("{d}:", .{totalMinutes});
        if (totalSeconds < 10) std.debug.print("0", .{});
        std.debug.print("{d}\n", .{totalSeconds});
    }
    mapTileZig.setMapType(.default, state);
    state.camera.position = .{ .x = 0, .y = 0 };
    state.level = 0;
    state.round = 0;
    state.gamePhase = .combat;
    state.gameTime = 0;
    state.timerStarted = false;
    state.roundStartedTime = 0;
    state.lastBossDefeatedTime = 0;
    if (state.enemyData.movePieceEnemyMovePiece) |movePiece| {
        state.allocator.free(movePiece.steps);
        state.enemyData.movePieceEnemyMovePiece = null;
    }
    mapTileZig.resetMapTiles(state.mapData.tiles);
    for (state.players.items) |*player| {
        player.money = 0;
        player.isDead = false;
        player.position.x = 0;
        player.position.y = 0;
        player.afterImages.clearRetainingCapacity();
        player.animateData = .{};
        player.paintData = .{};
        player.executeMovePiece = null;
        player.shop.gridDisplayPiece = null;
        player.shop.selectedOption = .none;
        player.immunUntilTime = 0;
        player.choosenMoveOptionIndex = null;
        equipmentZig.equipStarterEquipment(player);
        try movePieceZig.setupMovePieces(player, state);
    }
    bossZig.clearBosses(state);
    state.spriteCutAnimations.clearRetainingCapacity();
    state.mapObjects.clearAndFree();
    try startNextLevel(state);
}

pub fn adjustZoom(state: *GameState) void {
    const mapSize: f32 = @floatFromInt((state.mapData.tileRadius * 2 + 1) * TILESIZE);
    const targetMapScreenPerCent = 0.75;
    const widthPerCent = mapSize / windowSdlZig.windowData.widthFloat;
    const heightPerCent = mapSize / windowSdlZig.windowData.heightFloat;
    const biggerPerCent = @max(widthPerCent, heightPerCent);
    state.camera.zoom = targetMapScreenPerCent / biggerPerCent;
}

pub fn getClosestPlayer(position: Position, state: *GameState) struct { player: ?*Player, distance: f32 } {
    var closestPlayer: ?*Player = null;
    var closestDistance: f32 = 0;
    for (state.players.items) |*player| {
        const tempDistance = calculateDistance(player.position, position);
        if (closestPlayer == null or tempDistance < closestDistance) {
            closestPlayer = player;
            closestDistance = tempDistance;
        }
    }
    return .{ .player = closestPlayer, .distance = closestDistance };
}

fn createGameState(state: *GameState, allocator: std.mem.Allocator) !void {
    state.* = .{
        .players = std.ArrayList(Player).init(allocator),
        .bosses = std.ArrayList(bossZig.Boss).init(allocator),
        .shop = .{ .buyOptions = std.ArrayList(shopZig.ShopBuyOption).init(allocator) },
        .mapData = try mapTileZig.createMapData(allocator),
    };
    state.allocator = allocator;
    try windowSdlZig.initWindowSdl();
    try initVulkanZig.initVulkan(state);
    try soundMixerZig.createSoundMixer(state, state.allocator);
    try enemyZig.initEnemy(state);
    state.spriteCutAnimations = std.ArrayList(CutSpriteAnimation).init(state.allocator);
    state.mapObjects = std.ArrayList(MapObject).init(state.allocator);
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
        const levelBossData = bossZig.LEVEL_BOSS_DATA.get(boss.typeData);
        if (levelBossData.deinit) |deinit| deinit(boss, state.allocator);
    }
    state.bosses.deinit();
    state.shop.buyOptions.deinit();
    state.spriteCutAnimations.deinit();
    state.mapObjects.deinit();
    mapTileZig.deinit(state);
    enemyZig.destroyEnemyData(state);
}

pub fn isPositionEmpty(position: Position, state: *GameState) bool {
    const tilePosition = gamePositionToTilePosition(position);
    return isTileEmpty(tilePosition, state);
}

pub fn isTileEmpty(tilePosition: TilePosition, state: *GameState) bool {
    for (state.enemyData.enemies.items) |enemy| {
        const enemyTile = gamePositionToTilePosition(enemy.position);
        if (enemyTile.x == tilePosition.x and enemyTile.y == tilePosition.y) return false;
    }
    for (state.bosses.items) |boss| {
        const bossTile = gamePositionToTilePosition(boss.position);
        if (bossTile.x == tilePosition.x and bossTile.y == tilePosition.y) return false;
    }
    for (state.players.items) |player| {
        const playerTile = gamePositionToTilePosition(player.position);
        if (playerTile.x == tilePosition.x and playerTile.y == tilePosition.y) return false;
    }
    const mapTileType = mapTileZig.getMapTilePositionType(tilePosition, &state.mapData);
    if (mapTileType == .wall) return false;

    return true;
}

pub fn calculateDistance(pos1: Position, pos2: Position) f32 {
    const diffX = pos1.x - pos2.x;
    const diffY = pos1.y - pos2.y;
    return @floatCast(@sqrt(diffX * diffX + diffY * diffY));
}

pub fn calculateDistance3D(x1: f32, y1: f32, z1: f32, x2: f32, y2: f32, z2: f32) f32 {
    const diffX = x1 - x2;
    const diffY = y1 - y2;
    const diffZ = z1 - z2;
    return @floatCast(@sqrt(diffX * diffX + diffY * diffY + diffZ * diffZ));
}

pub fn calculateDirection(start: Position, end: Position) f32 {
    return @floatCast(std.math.atan2(end.y - start.y, end.x - start.x));
}

pub fn calculateDistancePointToLine(point: Position, linestart: Position, lineEnd: Position) f32 {
    const A: Position = .{ .x = point.x - linestart.x, .y = point.y - linestart.y };
    const B: Position = .{ .x = lineEnd.x - linestart.x, .y = lineEnd.y - linestart.y };

    const dot = A.x * B.x + A.y * B.y;
    const len_sq = B.x * B.x + B.y * B.y;
    var param: f32 = -1;
    if (len_sq != 0) //in case of 0 length line
        param = dot / len_sq;

    var xx: f32 = 0;
    var yy: f32 = 0;

    if (param < 0) {
        xx = linestart.x;
        yy = linestart.y;
    } else if (param > 1) {
        xx = lineEnd.x;
        yy = lineEnd.y;
    } else {
        xx = linestart.x + param * B.x;
        yy = linestart.y + param * B.y;
    }

    const dx = point.x - xx;
    const dy = point.y - yy;
    return @sqrt(dx * dx + dy * dy);
}

pub fn moveByDirectionAndDistance(position: Position, direction: f32, distance: f32) Position {
    return .{
        .x = position.x + @cos(direction) * distance,
        .y = position.y + @sin(direction) * distance,
    };
}

pub fn rotateAroundPoint(point: Position, pivot: Position, angle: f32) Position {
    const translatedX = point.x - pivot.x;
    const translatedY = point.y - pivot.y;

    const s = @sin(angle);
    const c = @cos(angle);

    const rotatedX = c * translatedX - s * translatedY;
    const rotatedY = s * translatedX + c * translatedY;

    return Position{ .x = rotatedX + pivot.x, .y = rotatedY + pivot.y };
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

pub fn colorConv(r: f32, g: f32, b: f32) [3]f32 {
    return .{ std.math.pow(f32, r, 2.2), std.math.pow(f32, g, 2.2), std.math.pow(f32, b, 2.2) };
}
