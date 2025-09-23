const std = @import("std");
const windowSdlZig = @import("windowSdl.zig");
const initVulkanZig = @import("vulkan/initVulkan.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const movePieceZig = @import("movePiece.zig");
const ninjaDogVulkanZig = @import("vulkan/ninjaDogVulkan.zig");
const soundMixerZig = @import("soundMixer.zig");
const enemyZig = @import("enemy/enemy.zig");
const enemyObjectZig = @import("enemy/enemyObject.zig");
const enemyObjectFallDownZig = @import("enemy/enemyObjectFallDown.zig");
const shopZig = @import("shop.zig");
const bossZig = @import("boss/boss.zig");
const imageZig = @import("image.zig");
const mapTileZig = @import("mapTile.zig");
const equipmentZig = @import("equipment.zig");
const statsZig = @import("stats.zig");
const verifyMapZig = @import("verifyMap.zig");
const inputZig = @import("input.zig");

pub const GamePhase = enum {
    combat,
    shopping,
    boss,
};
pub const COLOR_TILE_GREEN: [3]f32 = colorConv(0.533, 0.80, 0.231);
pub const COLOR_SKY_BLUE: [3]f32 = colorConv(0.529, 0.808, 0.922);
pub const COLOR_STONE_WALL: [3]f32 = colorConv(0.573, 0.522, 0.451);
pub const LEVEL_COUNT = 50;
pub const PLAYER_JOIN_BUTTON_HOLD_DURATION = 3000;

pub const TILESIZE = 20;
pub const GameState = struct {
    vkState: initVulkanZig.VkState = .{},
    allocator: std.mem.Allocator = undefined,
    camera: Camera = .{ .position = .{ .x = 0, .y = 0 }, .zoom = 1 },
    gameTime: i64 = 0,
    round: u32 = 1,
    level: u32 = 0,
    newGamePlus: u32 = 0,
    roundToReachForNextLevel: usize = 5,
    bonusTimePerRoundFinished: i32 = 5000,
    minimalTimePerRequiredRounds: i32 = 60_000,
    mapData: mapTileZig.MapData,
    suddenDeathTimeMs: i64 = 0,
    roundStartedTime: i64 = 0,
    playerImmunityFrames: i64 = 1000,
    bosses: std.ArrayList(bossZig.Boss) = undefined,
    enemyData: enemyZig.EnemyData = .{},
    spriteCutAnimations: std.ArrayList(CutSpriteAnimation) = undefined,
    mapObjects: std.ArrayList(MapObject) = undefined,
    players: std.ArrayList(Player),
    playerTookDamageOnLevel: bool = false,
    soundMixer: ?soundMixerZig.SoundMixer = null,
    gameEnded: bool = false,
    gamePhase: GamePhase = .combat,
    shop: shopZig.ShopData,
    lastBossDefeatedTime: i64 = 0,
    statistics: statsZig.Statistics,
    suddenDeath: u32 = 0,
    gameOver: bool = false,
    gameOverRealTime: i64 = 0,
    verifyMapData: verifyMapZig.VerifyMapData = .{},
    continueData: ContinueData = .{},
    soundData: SoundData = .{},
    inputJoinData: inputZig.InputJoinData,
    tempStringBuffer: []u8,
    tutorialData: TutorialData = .{},
};

pub const TutorialData = struct {
    active: bool = true,
    firstKeyDownInput: ?i64 = null,
    playerFirstValidPieceSelection: ?i64 = null,
    playerFirstValidMove: bool = false,
};

pub const SoundData = struct {
    suddenDeathPlayed: bool = false,
    warningSoundPlayed: bool = false,
    tickSoundPlayedCounter: u32 = 0,
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
    equipment: equipmentZig.EquipmentData = .{},
    moneyBonusPerCent: f32 = 0,
    lastMoveDirection: ?u8 = null,
    uxData: PlayerUxData = .{},
    inputData: inputZig.PlayerInputData = .{},
};

const PlayerUxData = struct {
    vulkanTopLeft: Position = .{ .x = 0, .y = 0 },
    vulkanScale: f32 = 0.4,
    vertical: bool = false,
    piecesRefreshedVisualization: ?i64 = null,
    visualizeMovePieceChangeFromShop: ?i32 = null,
    visualizationDuration: i32 = 1500,
    visualizeMoney: ?i32 = null,
    visualizeMoneyUntil: ?i64 = null,
    visualizeHpChange: ?i32 = null,
    visualizeHpChangeUntil: ?i64 = null,
    visualizeChoiceKeys: bool = true,
    visualizeMovementKeys: bool = true,
};

const ContinueData = struct {
    freeContinues: u32 = 0,
    bossesAced: u32 = 0,
    nextBossAceFreeContinue: u32 = 1,
    nextBossAceFreeContinueIncrease: u32 = 2,
    paidContinues: u32 = 0,
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
    if (player.isDead) return;
    if (!try equipmentZig.damageTakenByEquipment(player, state)) {
        player.isDead = true;
        state.gameOver = isGameOver(state);
        if (state.gameOver) {
            state.gameOverRealTime = std.time.milliTimestamp();
        }
        try ninjaDogDeathCutSprites(player, state);
    } else {
        try movePieceZig.resetPieces(player, true, state);
    }

    if (player.uxData.visualizeHpChange != null) {
        player.uxData.visualizeHpChange.? -= 1;
    } else {
        player.uxData.visualizeHpChange = -1;
    }
    player.uxData.visualizeHpChangeUntil = state.gameTime + player.uxData.visualizationDuration;

    player.immunUntilTime = state.gameTime + state.playerImmunityFrames;
    state.playerTookDamageOnLevel = true;
    try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_PLAYER_HIT, 0, 1);
}

fn ninjaDogDeathCutSprites(player: *Player, state: *GameState) !void {
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = player.paintData.chestArmorImageIndex },
        .cutAngle = 1,
        .deathTime = state.gameTime,
        .force = 0.9,
        .position = player.position,
    });
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = player.paintData.headLayer2ImageIndex },
        .cutAngle = 1,
        .deathTime = state.gameTime,
        .force = 0.9,
        .position = .{ .x = player.position.x, .y = player.position.y - 8 },
    });
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = player.paintData.feetImageIndex },
        .cutAngle = 1,
        .deathTime = state.gameTime,
        .force = 0.9,
        .position = .{ .x = player.position.x, .y = player.position.y + 8 },
    });
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = player.paintData.weaponImageIndex },
        .cutAngle = 1,
        .deathTime = state.gameTime,
        .force = 0.9,
        .position = player.position,
    });
}

pub fn getPlayerDamage(player: *Player) u32 {
    return @as(u32, @intFromFloat(@round(@as(f32, @floatFromInt(player.damage)) * player.damagePerCentFactor)));
}

pub fn getPlayerTotalHp(player: *Player) u32 {
    if (player.isDead) return 0;
    var hp: u32 = 1;
    if (player.equipment.equipmentSlotsData.body != null and player.equipment.equipmentSlotsData.body.?.effectType == .hp) {
        hp += player.equipment.equipmentSlotsData.body.?.effectType.hp.hp;
    }
    if (player.equipment.equipmentSlotsData.head != null and player.equipment.equipmentSlotsData.head.?.effectType == .hp) {
        hp += player.equipment.equipmentSlotsData.head.?.effectType.hp.hp;
    }
    if (player.equipment.equipmentSlotsData.feet != null and player.equipment.equipmentSlotsData.feet.?.effectType == .hp) {
        hp += player.equipment.equipmentSlotsData.feet.?.effectType.hp.hp;
    }
    return hp;
}

fn startGame(allocator: std.mem.Allocator) !void {
    std.debug.print("game run start\n", .{});
    var state: GameState = undefined;
    try createGameState(&state, allocator);
    try mainLoop(&state);
    try destroyGameState(&state);
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
                state.lastBossDefeatedTime = state.gameTime;
                for (state.players.items) |*player| {
                    const amount = @as(i32, @intFromFloat(@as(f32, @floatFromInt(state.level)) * 10.0 * (1.0 + player.moneyBonusPerCent)));
                    changePlayerMoneyBy(amount, player, true);
                }
                if (state.playerTookDamageOnLevel == false) {
                    state.continueData.bossesAced += 1;
                    if (state.continueData.bossesAced >= state.continueData.nextBossAceFreeContinue) {
                        state.continueData.freeContinues += 1;
                        std.debug.print("free continue\n", .{});
                        state.continueData.nextBossAceFreeContinue += state.continueData.nextBossAceFreeContinueIncrease;
                        state.continueData.nextBossAceFreeContinueIncrease += 1;
                    }
                }
            }
            try shopZig.startShoppingPhase(state);
        }
        try suddenDeath(state);
        try windowSdlZig.handleEvents(state);
        try tickPlayers(state, passedTime);
        tickClouds(state, passedTime);
        try enemyZig.tickEnemies(passedTime, state);
        try bossZig.tickBosses(state, passedTime);
        tickMapObjects(state, passedTime);
        if (state.verifyMapData.checkReachable) try verifyMapZig.checkAndModifyMapIfNotEverythingReachable(state);
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

fn suddenDeath(state: *GameState) !void {
    if (state.gameOver) return;
    if (state.gamePhase == .shopping) return;
    if (state.gamePhase == .boss and state.newGamePlus < 2) return;
    if (state.newGamePlus >= 2 and state.level == LEVEL_COUNT) return;
    if (state.round <= 1 and state.gamePhase == .combat) return;

    const timeUntilSuddenDeath = state.suddenDeathTimeMs - state.gameTime;
    if (timeUntilSuddenDeath <= 0) {
        if (!state.soundData.suddenDeathPlayed) {
            try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SUDDEN_DEATH, 0, 1);
            state.soundData.suddenDeathPlayed = true;
        }
    } else {
        if (timeUntilSuddenDeath < 10_000) {
            if (!state.soundData.warningSoundPlayed) {
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_TIME_WARNING, 0, 1);
                state.soundData.warningSoundPlayed = true;
            }
            if (timeUntilSuddenDeath < 3000 - state.soundData.tickSoundPlayedCounter * 1000) {
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_LAST_SECONDS, 0, 1);
                state.soundData.tickSoundPlayedCounter += 1;
            }
        }
        return;
    }

    const overTime = state.gameTime - state.suddenDeathTimeMs;
    const spawnInterval = 1050;
    if (@divFloor(overTime, spawnInterval) >= state.suddenDeath) {
        state.suddenDeath += 1;
        const size = state.mapData.tileRadius * 2 + 3;
        const fRadius: f32 = @floatFromInt(state.mapData.tileRadius + 1);
        const fillWidth = @min(state.suddenDeath - 1, @divFloor(size, 2) + 1);
        if (state.suddenDeath > 1) {
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_BALL_GROUND_INDICIES[0..], 0, 1);
        }
        for (0..size) |i| {
            for (0..size) |j| {
                if (i > fillWidth and i < size - fillWidth - 1 and j > fillWidth and j < size - fillWidth - 1) continue;
                const x: f32 = (@as(f32, @floatFromInt(i)) - fRadius) * TILESIZE;
                const y: f32 = (@as(f32, @floatFromInt(j)) - fRadius) * TILESIZE;
                try enemyObjectFallDownZig.spawnFallDown(.{ .x = x, .y = y }, spawnInterval, false, state);
            }
        }
    }
    for (state.players.items) |*player| {
        const playerTile = gamePositionToTilePosition(player.position);
        if (@abs(playerTile.x) > state.mapData.tileRadius + 1 or @abs(playerTile.y) > state.mapData.tileRadius + 1) {
            try playerHit(player, state);
        }
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
        if (player.isDead) continue;
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
    const timestamp = std.time.milliTimestamp();
    if (state.gamePhase != .boss) {
        for (state.inputJoinData.inputDeviceDatas.items, 0..) |joinData, index| {
            if (joinData.pressTime + PLAYER_JOIN_BUTTON_HOLD_DURATION <= timestamp) {
                try playerJoin(.{ .inputDevice = joinData.deviceData }, state);
                _ = state.inputJoinData.inputDeviceDatas.swapRemove(index);
                break;
            }
        }
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
    const timeShoesBonusTime = equipmentZig.getTimeShoesBonusRoundTime(state);
    const maxTime = state.gameTime + state.minimalTimePerRequiredRounds + timeShoesBonusTime;
    if (state.round < state.roundToReachForNextLevel) {
        state.suddenDeathTimeMs = maxTime;
    } else {
        if (state.suddenDeathTimeMs < state.gameTime) state.suddenDeathTimeMs = state.gameTime;
        state.suddenDeathTimeMs += state.bonusTimePerRoundFinished;
        if (state.suddenDeathTimeMs > maxTime) {
            state.suddenDeathTimeMs = maxTime;
        }
    }
    state.suddenDeath = 0;
    state.soundData.suddenDeathPlayed = false;
    state.soundData.tickSoundPlayedCounter = 0;
    state.soundData.warningSoundPlayed = false;
    state.roundStartedTime = state.gameTime;
    state.round += 1;
    if (state.round > 1) {
        for (state.players.items) |*player| {
            const amount = @as(i32, @intFromFloat(@ceil(@as(f32, @floatFromInt(state.level)) * (1.0 + player.moneyBonusPerCent))));
            changePlayerMoneyBy(amount, player, true);
        }
    }
    try enemyZig.setupEnemies(state);
    adjustZoom(state);
}

pub fn endShoppingPhase(state: *GameState) !void {
    state.gamePhase = .combat;
    try statsZig.statsOnLevelShopFinishedAndNextLevelStart(state);
    try startNextLevel(state);
}

pub fn changePlayerMoneyBy(amount: i32, player: *Player, visualize: bool) void {
    player.money = @intCast(@as(i32, @intCast(player.money)) + amount);
    if (visualize and amount != 0) {
        if (player.uxData.visualizeMoney != null) {
            player.uxData.visualizeMoney.? += amount;
        } else {
            player.uxData.visualizeMoney = amount;
        }
        player.uxData.visualizeMoneyUntil = null;
    }
}

pub fn startNextLevel(state: *GameState) !void {
    if (state.level >= LEVEL_COUNT) {
        try restart(state, state.newGamePlus + 1);
        return;
    }
    mapTileZig.setMapType(.default, state);
    state.playerTookDamageOnLevel = false;
    state.suddenDeath = 0;
    state.soundData.suddenDeathPlayed = false;
    state.soundData.tickSoundPlayedCounter = 0;
    state.soundData.warningSoundPlayed = false;
    state.camera.position = .{ .x = 0, .y = 0 };
    state.enemyData.enemies.clearRetainingCapacity();
    state.enemyData.enemyObjects.clearRetainingCapacity();
    mapTileZig.resetMapTiles(state.mapData.tiles);
    state.gamePhase = .combat;
    state.level += 1;
    state.round = 0;
    bossZig.clearBosses(state);
    for (state.players.items) |*player| {
        try movePieceZig.resetPieces(player, false, state);
        player.lastMoveDirection = null;
        if (state.level > 1) {
            player.uxData.visualizeChoiceKeys = false;
            player.uxData.visualizeMovementKeys = false;
        }
    }
    try enemyZig.setupSpawnEnemiesOnLevelChange(state);
    if (bossZig.isBossLevel(state.level)) {
        if (state.newGamePlus >= 2) {
            const timeShoesBonusTime = equipmentZig.getTimeShoesBonusRoundTime(state);
            const maxTime = state.gameTime + state.minimalTimePerRequiredRounds * 2 + timeShoesBonusTime;
            state.suddenDeathTimeMs = maxTime;
        }

        try bossZig.startBossLevel(state);
    } else {
        try startNextRound(state);
    }
    movePlayerToLevelSpawnPosition(state);
}

pub fn movePlayerToLevelSpawnPosition(state: *GameState) void {
    const playerSpawnOffsets = [_]Position{
        .{ .x = -1, .y = -1 },
        .{ .x = 1, .y = 1 },
        .{ .x = 1, .y = -1 },
        .{ .x = -1, .y = 1 },
        .{ .x = 0, .y = -1 },
        .{ .x = 0, .y = 1 },
        .{ .x = 1, .y = 0 },
        .{ .x = -1, .y = 0 },
    };
    const mapRadius: f32 = @as(f32, @floatFromInt(state.mapData.tileRadius)) * TILESIZE;
    for (state.players.items, 0..) |*player, index| {
        player.position.x = playerSpawnOffsets[@mod(index, playerSpawnOffsets.len)].x * mapRadius;
        player.position.y = playerSpawnOffsets[@mod(index, playerSpawnOffsets.len)].y * mapRadius;
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
    if (state.gamePhase == .boss and state.bosses.items.len == 0) return true;
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

pub fn restart(state: *GameState, newGamePlus: u32) anyerror!void {
    try statsZig.statsSaveOnRestart(state);
    mapTileZig.setMapType(.default, state);
    state.gameOver = false;
    state.camera.position = .{ .x = 0, .y = 0 };
    state.level = 0;
    state.round = 0;
    state.newGamePlus = newGamePlus;
    state.gamePhase = .combat;
    state.gameTime = 0;
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
        player.lastMoveDirection = null;
        equipmentZig.equipStarterEquipment(player);
        try movePieceZig.setupMovePieces(player, state);
        player.uxData.visualizeHpChangeUntil = null;
        player.uxData.visualizeMoneyUntil = null;
        player.uxData.visualizeMovePieceChangeFromShop = null;
        player.uxData.piecesRefreshedVisualization = null;
        player.uxData.visualizeHpChange = null;
        player.uxData.visualizeMoney = null;
    }
    for (0..state.shop.equipOptionsLastLevelInShop.len) |i| {
        state.shop.equipOptionsLastLevelInShop[i] = 0;
    }
    bossZig.clearBosses(state);
    state.spriteCutAnimations.clearRetainingCapacity();
    state.mapObjects.clearAndFree();
    state.verifyMapData.lastCheckTime = 0;
    state.verifyMapData.checkReachable = false;
    try startNextLevel(state);
}

pub fn adjustZoom(state: *GameState) void {
    const mapSize: f32 = @floatFromInt((state.mapData.tileRadius * 2 + 1) * TILESIZE);
    const targetMapScreenPerCent = 0.75;
    const widthPerCent = mapSize / windowSdlZig.windowData.widthFloat;
    const heightPerCent = mapSize / windowSdlZig.windowData.heightFloat;
    const biggerPerCent = @max(widthPerCent, heightPerCent);
    state.camera.zoom = targetMapScreenPerCent / biggerPerCent;
    determinePlayerUxPositions(state);
}

pub fn playerJoin(playerInputData: inputZig.PlayerInputData, state: *GameState) !void {
    std.debug.print("player join: {}\n", .{playerInputData.inputDevice.?});
    try state.players.append(createPlayer(state.allocator));
    const player: *Player = &state.players.items[state.players.items.len - 1];
    player.inputData = playerInputData;
    for (0..state.players.items.len - 1) |index| {
        const otherPlayer = &state.players.items[index];
        if (otherPlayer.inputData.inputDevice == null) {
            if (player.inputData.inputDevice.? == .gamepad) {
                otherPlayer.inputData.inputDevice = .{ .keyboard = null };
            } else if (player.inputData.inputDevice.? == .keyboard) {
                if (player.inputData.inputDevice.?.keyboard == 0) {
                    otherPlayer.inputData.inputDevice = .{ .keyboard = 1 };
                } else {
                    otherPlayer.inputData.inputDevice = .{ .keyboard = 0 };
                }
                otherPlayer.uxData.visualizeMovementKeys = true;
            }
        } else if (player.inputData.inputDevice.? == .keyboard and otherPlayer.inputData.inputDevice.? == .keyboard and otherPlayer.inputData.inputDevice.?.keyboard == null) {
            if (player.inputData.inputDevice.?.keyboard == 0) {
                otherPlayer.inputData.inputDevice = .{ .keyboard = 1 };
            } else {
                otherPlayer.inputData.inputDevice = .{ .keyboard = 0 };
            }
            otherPlayer.uxData.visualizeMovementKeys = true;
        }
    }
    equipmentZig.equipStarterEquipment(player);
    try movePieceZig.setupMovePieces(player, state);
    state.statistics.active = false;
    determinePlayerUxPositions(state);
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

fn isGameOver(state: *GameState) bool {
    for (state.players.items) |*player| {
        if (!player.isDead) return false;
    }
    return true;
}

fn createGameState(state: *GameState, allocator: std.mem.Allocator) !void {
    state.* = .{
        .players = std.ArrayList(Player).init(allocator),
        .bosses = std.ArrayList(bossZig.Boss).init(allocator),
        .shop = .{ .buyOptions = std.ArrayList(shopZig.ShopBuyOption).init(allocator) },
        .mapData = try mapTileZig.createMapData(allocator),
        .statistics = statsZig.createStatistics(allocator),
        .inputJoinData = .{
            .inputDeviceDatas = std.ArrayList(inputZig.InputJoinDeviceData).init(allocator),
            .disconnectedGamepads = std.ArrayList(u32).init(allocator),
        },
        .tempStringBuffer = try allocator.alloc(u8, 20),
    };
    state.allocator = allocator;
    try windowSdlZig.initWindowSdl();
    try initVulkanZig.initVulkan(state);
    try soundMixerZig.createSoundMixer(state, state.allocator);
    try enemyZig.initEnemy(state);
    state.spriteCutAnimations = std.ArrayList(CutSpriteAnimation).init(state.allocator);
    state.mapObjects = std.ArrayList(MapObject).init(state.allocator);
    try state.players.append(createPlayer(allocator));
    statsZig.loadStatisticsDataFromFile(state);
    determinePlayerUxPositions(state);
    try restart(state, 0);
}

pub fn createPlayer(allocator: std.mem.Allocator) Player {
    return .{
        .moveOptions = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .availableMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .totalMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .afterImages = std.ArrayList(AfterImage).init(allocator),
    };
}

fn destroyGameState(state: *GameState) !void {
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
    state.inputJoinData.inputDeviceDatas.deinit();
    state.inputJoinData.disconnectedGamepads.deinit();
    state.allocator.free(state.tempStringBuffer);
    try statsZig.destroyAndSave(state);
    mapTileZig.deinit(state);
    enemyZig.destroyEnemyData(state);
}

pub fn executeContinue(state: *GameState) !void {
    if (state.gameOverRealTime + 1000 > std.time.milliTimestamp()) {
        return;
    }
    const optCost = getMoneyCostsForContinue(state);
    if (optCost == null) return;
    var openMoney = optCost.?;
    if (openMoney > 0) {
        const averagePlayerCosts = @divFloor(openMoney, state.players.items.len);
        for (state.players.items) |*player| {
            const pay = @min(averagePlayerCosts, player.money);
            changePlayerMoneyBy(-@as(i32, @intCast(pay)), player, true);
            openMoney -|= pay;
        }
        if (openMoney > 0) {
            for (state.players.items) |*player| {
                const pay = @min(openMoney, player.money);
                changePlayerMoneyBy(-@as(i32, @intCast(pay)), player, true);
                openMoney -|= pay;
                if (openMoney == 0) break;
            }
        }
        state.continueData.paidContinues +|= 1;
    } else {
        state.continueData.freeContinues -|= 1;
    }
    state.level -= 1;
    for (state.players.items) |*player| {
        if (player.equipment.equipmentSlotsData.head == null) {
            _ = equipmentZig.equip(equipmentZig.getEquipmentOptionByIndexScaledToLevel(0, state.level).equipment, true, player);
        }
        if (player.equipment.equipmentSlotsData.body == null) {
            _ = equipmentZig.equip(equipmentZig.getEquipmentOptionByIndexScaledToLevel(4, state.level).equipment, true, player);
        }
        player.isDead = false;
    }
    try shopZig.startShoppingPhase(state);
    state.gameOver = false;
}

/// returns null if players have not enough money for continue
pub fn getMoneyCostsForContinue(state: *GameState) ?u32 {
    if (state.level < 2) return null;
    if (state.continueData.freeContinues > 0) {
        return 0;
    }
    const costs: u32 = (state.continueData.paidContinues + 1) * state.level * 5 * @as(u32, @intCast(state.players.items.len));
    var maxPlayerMoney: u32 = 0;
    for (state.players.items) |*player| {
        maxPlayerMoney += player.money;
    }
    if (maxPlayerMoney < costs) return null;
    return costs;
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

pub fn determinePlayerUxPositions(state: *GameState) void {
    var scale: f32 = 1;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const isVertical = windowSdlZig.windowData.widthFloat < windowSdlZig.windowData.heightFloat;
    var diffScale: f32 = 0;
    if (state.players.items.len <= 2) {
        if (isVertical) {
            diffScale = windowSdlZig.windowData.heightFloat / windowSdlZig.windowData.widthFloat;
        } else {
            diffScale = windowSdlZig.windowData.widthFloat / windowSdlZig.windowData.heightFloat;
        }
        if (diffScale > 1.2) {
            scale = @max(1.0, @min(2.0, 1 + (diffScale - 1.2) * 2.0));
        }
    }

    const height = scale / 4.0;
    const width = height / onePixelYInVulkan * onePixelXInVulkan;
    const playerPosX = [_]f32{ -0.99, 0.99 - width };
    const playerPosY = [_]f32{ 0 - scale / 2.0, -1, 0 };

    for (state.players.items, 0..) |*player, index| {
        player.uxData.vulkanScale = scale;
        player.uxData.vertical = true;
        player.uxData.vulkanTopLeft.x = playerPosX[@mod(index, 2)];
        if (state.players.items.len <= 2) {
            player.uxData.vulkanTopLeft.y = playerPosY[0];
        } else {
            player.uxData.vulkanTopLeft.y = playerPosY[@mod(@divFloor(index, 2), 2) + 1];
        }
        if (isVertical) {
            player.uxData.vertical = false;
            const tempX = player.uxData.vulkanTopLeft.x;
            player.uxData.vulkanTopLeft.x = player.uxData.vulkanTopLeft.y;
            player.uxData.vulkanTopLeft.y = tempX;
        }
    }
}
