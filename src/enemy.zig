const std = @import("std");
const main = @import("main.zig");
const imageZig = @import("image.zig");

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

pub fn tickEnemies(state: *main.GameState) !void {
    const enemies = &state.enemies;
    for (enemies.items) |*enemy| {
        switch (enemy.enemyTypeData) {
            .nothing => {},
            .attack => |*data| {
                if (data.startTime + data.delay < state.gameTime) {
                    data.startTime = state.gameTime;
                    data.direction = std.crypto.random.int(u2);
                }
            },
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
            // try enemies.append(.{ .imageIndex = imageZig.IMAGE_EVIL_TREE, .position = randomPos, .enemyTypeData = .nothing });
            try enemies.append(.{
                .imageIndex = imageZig.IMAGE_EVIL_TREE,
                .position = randomPos,
                .enemyTypeData = .{ .attack = .{
                    .delay = 5000,
                    .direction = std.crypto.random.int(u2),
                    .startTime = state.gameTime,
                } },
            });
        }
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
