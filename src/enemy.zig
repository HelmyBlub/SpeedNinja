const std = @import("std");
const main = @import("main.zig");
const imageZig = @import("image.zig");
const movePieceZig = @import("movePiece.zig");

pub const EnemyType = enum {
    nothing,
    attack,
    move,
};

pub const EnemyTypeAttackData = struct {
    delay: i64,
    direction: u8,
    startTime: ?i64 = null,
};

const EnemyTypeSpawnLevelData = struct {
    enemyType: EnemyType,
    startingLevel: u32,
    leavingLevel: ?u32,
    baseProbability: f32,
};

pub const EnemyTypeData = union(EnemyType) {
    nothing,
    attack: EnemyTypeAttackData,
    move: EnemyTypeAttackData,
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

pub const EnemyDeathAnimation = struct {
    position: main.Position,
    deathTime: i64,
    cutAngle: f32,
    force: f32,
    imageIndex: u8,
};

pub const MoveAttackWarningTile = struct {
    position: main.TilePosition,
    direction: u8,
};

const ENEMY_TYPE_SPAWN_LEVEL_DATA = [_]EnemyTypeSpawnLevelData{
    .{ .baseProbability = 0.1, .enemyType = .nothing, .startingLevel = 1, .leavingLevel = 3 },
    .{ .baseProbability = 1, .enemyType = .attack, .startingLevel = 2, .leavingLevel = null },
    .{ .baseProbability = 1, .enemyType = .move, .startingLevel = 5, .leavingLevel = null },
};

pub fn tickEnemies(state: *main.GameState) !void {
    const enemies = &state.enemies;
    for (enemies.items) |*enemy| {
        switch (enemy.enemyTypeData) {
            .nothing => {},
            .attack => |*data| {
                if (data.startTime) |startTime| {
                    if (startTime + data.delay < state.gameTime) {
                        const stepDirection = movePieceZig.getStepDirection(data.direction);
                        const hitPosition: main.Position = .{
                            .x = enemy.position.x + stepDirection.x * main.TILESIZE,
                            .y = enemy.position.y + stepDirection.y * main.TILESIZE,
                        };
                        try checkPlayerHit(hitPosition, state);
                        data.startTime = null;
                    }
                } else {
                    data.startTime = state.gameTime;
                    data.direction = std.crypto.random.int(u2);
                }
            },
            .move => |*data| {
                if (data.startTime) |startTime| {
                    if (startTime + data.delay < state.gameTime) {
                        const stepDirection = movePieceZig.getStepDirection(data.direction);
                        const hitPosition: main.Position = .{
                            .x = enemy.position.x + stepDirection.x * main.TILESIZE,
                            .y = enemy.position.y + stepDirection.y * main.TILESIZE,
                        };
                        try checkPlayerHit(hitPosition, state);
                        enemy.position = hitPosition;
                        data.startTime = null;
                    }
                } else {
                    data.direction = std.crypto.random.int(u2);
                    const stepDirection = movePieceZig.getStepDirection(data.direction);
                    const border: f32 = @floatFromInt(state.mapTileRadius * main.TILESIZE);
                    if (stepDirection.x < 0 and enemy.position.x > -border or
                        stepDirection.x > 0 and enemy.position.x < border or
                        stepDirection.y < 0 and enemy.position.y > -border or
                        stepDirection.y > 0 and enemy.position.y < border)
                    {
                        data.startTime = state.gameTime;
                    }
                }
            },
        }
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
    state.enemyDeath = std.ArrayList(EnemyDeathAnimation).init(state.allocator);
    state.enemies = std.ArrayList(Enemy).init(state.allocator);
    state.enemySpawnData.enemyEntries = std.ArrayList(EnemySpawnEntry).init(state.allocator);
    try setupSpawnEnemiesOnLevelChange(state);
}

fn createSpawnEnemyEntryEnemy(enemyType: EnemyType) Enemy {
    switch (enemyType) {
        .nothing => {
            return .{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_EVIL_TREE, .position = .{ .x = 0, .y = 0 } };
        },
        .attack => {
            return .{
                .imageIndex = imageZig.IMAGE_EVIL_TREE,
                .position = .{ .x = 0, .y = 0 },
                .enemyTypeData = .{
                    .attack = .{
                        .delay = 5000,
                        .direction = std.crypto.random.int(u2),
                    },
                },
            };
        },
        .move => {
            return .{
                .imageIndex = imageZig.IMAGE_ENEMY_MOVING,
                .position = .{ .x = 0, .y = 0 },
                .enemyTypeData = .{
                    .move = .{
                        .delay = 4000,
                        .direction = std.crypto.random.int(u2),
                    },
                },
            };
        },
    }
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
    state.enemyDeath.deinit();
    state.enemies.deinit();
}

fn checkPlayerHit(position: main.Position, state: *main.GameState) !void {
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
    const enemyCount = state.round + @min(10, state.level - 1);
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
