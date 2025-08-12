const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const movePieceZig = @import("../movePiece.zig");
const enemyObjectZig = @import("enemyObject.zig");
const enemyTypeAttackZig = @import("enemyTypeAttack.zig");
const enemyTypeMoveZig = @import("enemyTypeMove.zig");
const enemyTypeMoveWithPlayerZig = @import("enemyTypeMoveWithPlayer.zig");
const enemyTypeProjectileAttackZig = @import("enemyTypeProjectileAttack.zig");
const enemyTypePutFireZig = @import("enemyTypePutFire.zig");
const enemyTypeBlockZig = @import("enemyTypeBlock.zig");

pub const EnemyType = enum {
    nothing,
    attack,
    move,
    moveWithPlayer,
    projectileAttack,
    putFire,
    block,
};

const EnemyTypeSpawnLevelData = struct {
    enemyType: EnemyType,
    startingLevel: u32,
    leavingLevel: ?u32,
    baseProbability: f32,
};

pub const EnemyTypeDelayedActionData = struct {
    delay: i64,
    direction: u8,
    startTime: ?i64 = null,
};

pub const EnemyTypeData = union(EnemyType) {
    nothing,
    attack: EnemyTypeDelayedActionData,
    move: EnemyTypeDelayedActionData,
    moveWithPlayer: enemyTypeMoveWithPlayerZig.EnemyTypeMoveWithPlayerData,
    projectileAttack: EnemyTypeDelayedActionData,
    putFire: enemyTypePutFireZig.EnemyTypePutFireData,
    block: enemyTypeBlockZig.EnemyTypeBlockData,
};

pub const Enemy = struct {
    imageIndex: u8,
    position: main.Position,
    enemyTypeData: EnemyTypeData,
};

pub const EnemySpawnData = struct {
    enemyEntries: std.ArrayList(EnemySpawnEntry),
};

const EnemySpawnEntry = struct {
    enemy: Enemy,
    probability: f32,
    calcedProbabilityStart: f32 = 0,
    calcedProbabilityEnd: f32 = 0,
};

pub const CutSpriteAnimation = struct {
    position: main.Position,
    deathTime: i64,
    cutAngle: f32,
    force: f32,
    imageIndex: u8,
    imageToGameScaleFactor: f32 = 1.0 / @as(f32, @floatFromInt(imageZig.IMAGE_TO_GAME_SIZE)) / 2.0,
};

pub const MoveAttackWarningTile = struct {
    position: main.TilePosition,
    direction: u8,
};

const ENEMY_TYPE_SPAWN_LEVEL_DATA = [_]EnemyTypeSpawnLevelData{
    .{ .baseProbability = 0.1, .enemyType = .nothing, .startingLevel = 1, .leavingLevel = 3 },
    .{ .baseProbability = 1, .enemyType = .attack, .startingLevel = 2, .leavingLevel = 10 },
    .{ .baseProbability = 1, .enemyType = .move, .startingLevel = 5, .leavingLevel = 15 },
    .{ .baseProbability = 1, .enemyType = .moveWithPlayer, .startingLevel = 10, .leavingLevel = 20 },
    .{ .baseProbability = 1, .enemyType = .projectileAttack, .startingLevel = 15, .leavingLevel = 25 },
    .{ .baseProbability = 1, .enemyType = .putFire, .startingLevel = 20, .leavingLevel = null },
    .{ .baseProbability = 1, .enemyType = .block, .startingLevel = 25, .leavingLevel = null },
};

pub fn tickEnemies(passedTime: i64, state: *main.GameState) !void {
    for (state.enemies.items) |*enemy| {
        switch (enemy.enemyTypeData) {
            .attack => {
                try enemyTypeAttackZig.tick(enemy, state);
            },
            .move => {
                try enemyTypeMoveZig.tick(enemy, state);
            },
            .projectileAttack => {
                try enemyTypeProjectileAttackZig.tick(enemy, state);
            },
            .putFire => {
                try enemyTypePutFireZig.tick(enemy, state);
            },
            .block => {
                try enemyTypeBlockZig.tick(enemy, state);
            },
            else => {},
        }
    }
    try enemyObjectZig.tick(passedTime, state);
}

pub fn onPlayerMoved(player: *main.Player, state: *main.GameState) !void {
    for (state.enemies.items) |*enemy| {
        switch (enemy.enemyTypeData) {
            .moveWithPlayer => {
                try enemyTypeMoveWithPlayerZig.onPlayerMoved(enemy, player, state);
            },
            else => {},
        }
    }
}

fn createSpawnEnemyEntryEnemy(enemyType: EnemyType) Enemy {
    switch (enemyType) {
        .nothing => {
            return .{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_EVIL_TREE, .position = .{ .x = 0, .y = 0 } };
        },
        .attack => {
            return enemyTypeAttackZig.createSpawnEnemyEntryEnemy();
        },
        .move => {
            return enemyTypeMoveZig.createSpawnEnemyEntryEnemy();
        },
        .moveWithPlayer => {
            return enemyTypeMoveWithPlayerZig.createSpawnEnemyEntryEnemy();
        },
        .projectileAttack => {
            return enemyTypeProjectileAttackZig.createSpawnEnemyEntryEnemy();
        },
        .putFire => {
            return enemyTypePutFireZig.createSpawnEnemyEntryEnemy();
        },
        .block => {
            return enemyTypeBlockZig.createSpawnEnemyEntryEnemy();
        },
    }
}

pub fn fillMoveAttackWarningTiles(startPosition: main.Position, tileList: *std.ArrayList(MoveAttackWarningTile), movePiece: movePieceZig.MovePiece, direction: u8) !void {
    var curTilePos = main.gamePositionToTilePosition(startPosition);
    for (movePiece.steps, 0..) |step, stepIndex| {
        const currDirection = @mod(step.direction + direction + 1, 4);
        const stepDirection = movePieceZig.getStepDirectionTile(currDirection);
        for (0..step.stepCount) |stepCountIndex| {
            curTilePos.x += stepDirection.x;
            curTilePos.y += stepDirection.y;
            var visualizedDirection = currDirection;
            if (stepCountIndex == step.stepCount - 1 and movePiece.steps.len > stepIndex + 1) {
                visualizedDirection = @mod(movePiece.steps[stepIndex + 1].direction + direction + 1, 4);
            }
            try tileList.append(.{ .direction = visualizedDirection, .position = curTilePos });
        }
    }
}

pub fn initEnemy(state: *main.GameState) !void {
    state.spriteCutAnimations = std.ArrayList(CutSpriteAnimation).init(state.allocator);
    state.enemies = std.ArrayList(Enemy).init(state.allocator);
    state.enemySpawnData.enemyEntries = std.ArrayList(EnemySpawnEntry).init(state.allocator);
    state.enemyObjects = std.ArrayList(enemyObjectZig.EnemyObject).init(state.allocator);
    try setupSpawnEnemiesOnLevelChange(state);
}

pub fn setupSpawnEnemiesOnLevelChange(state: *main.GameState) !void {
    if (state.level == 1) {
        state.enemySpawnData.enemyEntries.clearRetainingCapacity();
    }
    for (ENEMY_TYPE_SPAWN_LEVEL_DATA) |data| {
        if (data.startingLevel == state.level) {
            try state.enemySpawnData.enemyEntries.append(.{ .probability = 1, .enemy = createSpawnEnemyEntryEnemy(data.enemyType) });
        }
        if (data.leavingLevel == state.level) {
            for (state.enemySpawnData.enemyEntries.items, 0..) |entry, index| {
                if (entry.enemy.enemyTypeData == data.enemyType) {
                    _ = state.enemySpawnData.enemyEntries.swapRemove(index);
                    break;
                }
            }
        }
    }
    scaleEnemiesToLevel(state);
}

fn scaleEnemiesToLevel(state: *main.GameState) void {
    for (state.enemySpawnData.enemyEntries.items) |*entry| {
        for (ENEMY_TYPE_SPAWN_LEVEL_DATA) |data| {
            if (entry.enemy.enemyTypeData == data.enemyType) {
                const baseProbability = data.baseProbability;
                const enemyLevel = state.level - data.startingLevel + 1;
                const levelDependentProbability = @min(1, @as(f32, @floatFromInt(enemyLevel)) / 10.0);
                entry.probability = baseProbability * levelDependentProbability;
                break;
            }
        }
    }
    calcAndSetEnemySpawnProbabilities(&state.enemySpawnData);
}

pub fn destroyEnemy(state: *main.GameState) void {
    state.enemySpawnData.enemyEntries.deinit();
    state.spriteCutAnimations.deinit();
    state.enemies.deinit();
    state.enemyObjects.deinit();
}

pub fn checkStationaryPlayerHit(position: main.Position, state: *main.GameState) !void {
    for (state.players.items) |*player| {
        if (player.executeMovePiece == null) {
            if (player.position.x > position.x - main.TILESIZE / 2 and player.position.x < position.x + main.TILESIZE / 2 and
                player.position.y > position.y - main.TILESIZE / 2 and player.position.y < position.y + main.TILESIZE / 2)
            {
                try main.playerHit(player, state);
            }
        }
    }
}

pub fn checkPlayerHit(position: main.Position, state: *main.GameState) !void {
    for (state.players.items) |*player| {
        if (player.position.x > position.x - main.TILESIZE / 2 and player.position.x < position.x + main.TILESIZE / 2 and
            player.position.y > position.y - main.TILESIZE / 2 and player.position.y < position.y + main.TILESIZE / 2)
        {
            try main.playerHit(player, state);
        }
    }
}

pub fn setupEnemies(state: *main.GameState) !void {
    const enemies = &state.enemies;
    enemies.clearRetainingCapacity();
    if (state.enemySpawnData.enemyEntries.items.len == 0) return;
    const rand = std.crypto.random;
    const enemyCount = state.round + @min(5, (@divFloor(state.level - 1, 2)));
    state.mapTileRadius = main.BASE_MAP_TILE_RADIUS + @as(u32, @intFromFloat(@sqrt(@as(f32, @floatFromInt(enemyCount)))));
    const length: f32 = @floatFromInt(state.mapTileRadius * 2 + 1);
    while (enemies.items.len < enemyCount) {
        const randomTileX: i16 = @as(i16, @intFromFloat(rand.float(f32) * length - length / 2));
        const randomTileY: i16 = @as(i16, @intFromFloat(rand.float(f32) * length - length / 2));
        const randomPos: main.Position = .{
            .x = @floatFromInt(randomTileX * main.TILESIZE),
            .y = @floatFromInt(randomTileY * main.TILESIZE),
        };
        if (canSpawnEnemyOnTile(randomPos, state)) {
            const randomFloat = std.crypto.random.float(f32);
            for (state.enemySpawnData.enemyEntries.items) |entry| {
                if (randomFloat >= entry.calcedProbabilityStart and randomFloat < entry.calcedProbabilityEnd) {
                    var enemy = entry.enemy;
                    enemy.position = randomPos;
                    try enemies.append(enemy);
                }
            }
        }
    }
}

fn calcAndSetEnemySpawnProbabilities(enemySpawnData: *EnemySpawnData) void {
    var totalProbability: f32 = 0;
    for (enemySpawnData.enemyEntries.items) |entry| {
        totalProbability += entry.probability;
    }
    var currentProbability: f32 = 0;
    for (enemySpawnData.enemyEntries.items) |*entry| {
        entry.calcedProbabilityStart = currentProbability;
        currentProbability += entry.probability / totalProbability;
        entry.calcedProbabilityEnd = currentProbability;
    }
    if (enemySpawnData.enemyEntries.items.len > 0) {
        enemySpawnData.enemyEntries.items[enemySpawnData.enemyEntries.items.len - 1].calcedProbabilityEnd = 1;
    }
}

fn canSpawnEnemyOnTile(position: main.Position, state: *main.GameState) bool {
    for (state.enemies.items) |enemy| {
        if (@abs(enemy.position.x - position.x) < main.TILESIZE / 2 and @abs(enemy.position.y - position.y) < main.TILESIZE / 2) return false;
    }
    for (state.players.items) |player| {
        if (@abs(player.position.x - position.x) < main.TILESIZE / 2 and @abs(player.position.y - position.y) < main.TILESIZE / 2) return false;
    }
    return true;
}
