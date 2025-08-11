const std = @import("std");
const main = @import("../main.zig");
const enemyObjectProjectileZig = @import("enemyObjectProjectile.zig");
const enemyObjectFireZig = @import("enemyObjectFire.zig");

const EnemyObjectTypes = enum {
    projectile,
    fire,
};

const EnemyObjectTypeData = union(EnemyObjectTypes) {
    projectile: enemyObjectProjectileZig.EnemyProjectile,
    fire: enemyObjectFireZig.EnemyFire,
};

pub const EnemyObject = struct {
    position: main.Position,
    functionsIndex: usize,
    typeData: EnemyObjectTypeData,
};

pub const EnemyObjectFunctions = struct {
    tick: *const fn (object: *EnemyObject, passedTime: i64, state: *main.GameState) anyerror!void,
    shouldBeRemoved: *const fn (object: *EnemyObject, state: *main.GameState) bool,
    setupVerticesGround: ?*const fn (object: *EnemyObject, state: *main.GameState) void = null,
    setupVertices: *const fn (object: *EnemyObject, state: *main.GameState) void,
    hitCheckMovingPlayer: ?*const fn (object: *EnemyObject, player: *main.Player, state: *main.GameState) bool = null,
};

pub const ENEMY_OBJECT_FUNCTIONS = [_]EnemyObjectFunctions{
    enemyObjectProjectileZig.createEnemyObjectFunctions(),
    enemyObjectFireZig.createEnemyObjectFunctions(),
};

pub fn setupVerticesGround(state: *main.GameState) void {
    for (state.enemyObjects.items) |*object| {
        if (ENEMY_OBJECT_FUNCTIONS[object.functionsIndex].setupVerticesGround) |setup| setup(object, state);
    }
}

pub fn setupVertices(state: *main.GameState) void {
    for (state.enemyObjects.items) |*object| {
        ENEMY_OBJECT_FUNCTIONS[object.functionsIndex].setupVertices(object, state);
    }
}

pub fn tick(passedTime: i64, state: *main.GameState) !void {
    var currentIndex: usize = 0;
    while (currentIndex < state.enemyObjects.items.len) {
        const object = &state.enemyObjects.items[currentIndex];
        const functions = ENEMY_OBJECT_FUNCTIONS[object.functionsIndex];
        if (functions.shouldBeRemoved(object, state)) {
            _ = state.enemyObjects.swapRemove(currentIndex);
        } else {
            try functions.tick(object, passedTime, state);
            currentIndex += 1;
        }
    }
}

pub fn checkHitMovingPlayer(player: *main.Player, state: *main.GameState) bool {
    for (state.enemyObjects.items) |*object| {
        const functions = ENEMY_OBJECT_FUNCTIONS[object.functionsIndex];
        if (functions.hitCheckMovingPlayer) |hitCheckMovingPlayer| {
            if (hitCheckMovingPlayer(object, player, state)) {
                return true;
            }
        }
    }
    return false;
}
