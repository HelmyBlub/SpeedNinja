const std = @import("std");
const main = @import("main.zig");
const imageZig = @import("image.zig");
const movePieceZig = @import("movePiece.zig");

pub const EnemyType = enum {
    nothing,
    attack,
};

pub const EnemyTypeAttackData = struct {
    delay: i64,
    direction: u8,
    startTime: i64,
};

pub const EnemyTypeData = union(EnemyType) {
    nothing,
    attack: EnemyTypeAttackData,
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
};

pub fn tickEnemies(state: *main.GameState) !void {
    const enemies = &state.enemies;
    for (enemies.items) |*enemy| {
        switch (enemy.enemyTypeData) {
            .nothing => {},
            .attack => |*data| {
                if (data.startTime + data.delay < state.gameTime) {
                    const stepDirection = movePieceZig.getStepDirection(data.direction);
                    const hitPosition: main.Position = .{
                        .x = enemy.position.x + stepDirection.x * main.TILESIZE,
                        .y = enemy.position.y + stepDirection.y * main.TILESIZE,
                    };
                    checkPlayerHit(hitPosition, state);
                    data.startTime = state.gameTime;
                    data.direction = std.crypto.random.int(u2);
                }
            },
        }
    }
}

pub fn initEnemy(state: *main.GameState) !void {
    state.enemyDeath = std.ArrayList(EnemyDeathAnimation).init(state.allocator);
    state.enemies = std.ArrayList(Enemy).init(state.allocator);
    state.enemySpawnData.enemyEntries = std.ArrayList(EnemySpawnEntry).init(state.allocator);
    try state.enemySpawnData.enemyEntries.append(EnemySpawnEntry{
        .enemy = .{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_EVIL_TREE, .position = .{ .x = 0, .y = 0 } },
        .probability = 1,
    });
    try state.enemySpawnData.enemyEntries.append(EnemySpawnEntry{
        .enemy = .{
            .imageIndex = imageZig.IMAGE_EVIL_TREE,
            .position = .{ .x = 0, .y = 0 },
            .enemyTypeData = .{
                .attack = .{
                    .delay = 5000,
                    .direction = std.crypto.random.int(u2),
                    .startTime = state.gameTime,
                },
            },
        },
        .probability = 0.5,
    });
    calcAndSetEnemySpawnProbabilities(&state.enemySpawnData);
}

pub fn destroyEnemy(state: *main.GameState) void {
    state.enemySpawnData.enemyEntries.deinit();
    state.enemyDeath.deinit();
    state.enemies.deinit();
}

fn checkPlayerHit(position: main.Position, state: *main.GameState) void {
    for (state.players.items) |*player| {
        if (player.position.x > position.x - main.TILESIZE / 2 and player.position.x < position.x + main.TILESIZE / 2 and
            player.position.y > position.y - main.TILESIZE / 2 and player.position.y < position.y + main.TILESIZE / 2)
        {
            player.hp -|= 1;
        }
    }
}

pub fn setupEnemies(state: *main.GameState) !void {
    const enemies = &state.enemies;
    enemies.clearRetainingCapacity();
    const rand = std.crypto.random;
    const length: f32 = @floatFromInt(state.mapTileRadius * 2 + 1);
    const enemyCount = state.round;
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
    enemySpawnData.enemyEntries.items[enemySpawnData.enemyEntries.items.len - 1].calcedProbabilityEnd = 1;
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
