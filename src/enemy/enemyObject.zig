const std = @import("std");
const main = @import("../main.zig");
const enemyObjectProjectileZig = @import("enemyObjectProjectile.zig");
const enemyObjectFireZig = @import("enemyObjectFire.zig");
const enemyObjectBombZig = @import("enemyObjectBomb.zig");
const enemyObjectFallDownZig = @import("enemyObjectFallDown.zig");
const playerZig = @import("../player.zig");

const EnemyObjectTypes = enum {
    projectile,
    fire,
    bomb,
    fallDown,
};

const EnemyObjectTypeData = union(EnemyObjectTypes) {
    projectile: enemyObjectProjectileZig.EnemyProjectile,
    fire: enemyObjectFireZig.EnemyFire,
    bomb: enemyObjectBombZig.EnemyBomb,
    fallDown: enemyObjectFallDownZig.EnemyFallDown,
};

pub const ENEMY_OBJECT_FUNCTIONS = std.EnumArray(EnemyObjectTypes, EnemyObjectFunctions).init(.{
    .projectile = enemyObjectProjectileZig.createEnemyObjectFunctions(),
    .fire = enemyObjectFireZig.createEnemyObjectFunctions(),
    .bomb = enemyObjectBombZig.createEnemyObjectFunctions(),
    .fallDown = enemyObjectFallDownZig.createEnemyObjectFunctions(),
});

pub const EnemyObject = struct {
    position: main.Position,
    typeData: EnemyObjectTypeData,
};

pub const EnemyObjectFunctions = struct {
    tick: *const fn (object: *EnemyObject, passedTime: i64, state: *main.GameState) anyerror!void,
    shouldBeRemoved: *const fn (object: *EnemyObject, state: *main.GameState) bool,
    setupVerticesGround: ?*const fn (object: *EnemyObject, state: *main.GameState) void = null,
    setupVertices: *const fn (object: *EnemyObject, state: *main.GameState) void,
    hitCheckMovingPlayer: ?*const fn (object: *EnemyObject, player: *playerZig.Player, state: *main.GameState) bool = null,
};

pub fn setupVerticesGround(state: *main.GameState) void {
    for (state.enemyData.enemyObjects.items) |*object| {
        if (ENEMY_OBJECT_FUNCTIONS.get(object.typeData).setupVerticesGround) |setup| setup(object, state);
    }
}

pub fn setupVertices(state: *main.GameState) void {
    for (state.enemyData.enemyObjects.items) |*object| {
        ENEMY_OBJECT_FUNCTIONS.get(object.typeData).setupVertices(object, state);
    }
}

pub fn tick(passedTime: i64, state: *main.GameState) !void {
    var currentIndex: usize = 0;
    while (currentIndex < state.enemyData.enemyObjects.items.len) {
        const object = &state.enemyData.enemyObjects.items[currentIndex];
        const functions = ENEMY_OBJECT_FUNCTIONS.get(object.typeData);
        if (functions.shouldBeRemoved(object, state)) {
            _ = state.enemyData.enemyObjects.orderedRemove(currentIndex);
        } else {
            try functions.tick(object, passedTime, state);
            currentIndex += 1;
        }
    }
}

pub fn checkHitMovingPlayer(player: *playerZig.Player, state: *main.GameState) bool {
    for (state.enemyData.enemyObjects.items) |*object| {
        const functions = ENEMY_OBJECT_FUNCTIONS.get(object.typeData);
        if (functions.hitCheckMovingPlayer) |hitCheckMovingPlayer| {
            if (hitCheckMovingPlayer(object, player, state)) {
                return true;
            }
        }
    }
    return false;
}
