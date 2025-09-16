const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");

pub const EnemyTypeMovePieceData = struct {
    direction: ?u8 = null,
    executeMoveTime: ?i64 = null,
    spawnDelay: ?i64 = null,
};

const OnPlayerMoveStepData = struct {
    playerTile: main.TilePosition,
    enemy: *enemyZig.Enemy,
};

pub fn create() enemyZig.EnemyFunctions {
    return enemyZig.EnemyFunctions{
        .createSpawnEnemyEntryEnemy = createSpawnEnemyEntryEnemy,
        .tick = tick,
        .setupVerticesGround = setupVerticesGround,
        .onPlayerMoveEachTile = onPlayerMoveEachTile,
    };
}

fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_ENEMY_MOVE_PIECE,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .movePiece = .{},
        },
    };
}

fn onPlayerMoveEachTile(enemy: *enemyZig.Enemy, player: *main.Player, state: *main.GameState) anyerror!void {
    const data = enemy.enemyTypeData.movePiece;
    if (state.enemyData.movePieceEnemyMovePiece == null or data.direction == null) return;
    const movePiece = state.enemyData.movePieceEnemyMovePiece.?;
    const enemyDirection = data.direction.?;
    const curTilePos = main.gamePositionToTilePosition(enemy.position);
    const playerTile = main.gamePositionToTilePosition(player.position);
    try movePieceZig.executeMovePieceWithCallbackPerStep(
        OnPlayerMoveStepData,
        movePiece,
        enemyDirection,
        curTilePos,
        .{ .playerTile = playerTile, .enemy = enemy },
        onPlayerMoveEachTileStepFunction,
        state,
    );
}

fn onPlayerMoveEachTileStepFunction(pos: main.TilePosition, visualizedDirection: u8, data: OnPlayerMoveStepData, state: *main.GameState) !void {
    _ = visualizedDirection;
    if (data.playerTile.x == pos.x and data.playerTile.y == pos.y) {
        data.enemy.enemyTypeData.movePiece.executeMoveTime = state.gameTime + 64;
    }
}

fn tick(enemy: *enemyZig.Enemy, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &enemy.enemyTypeData.movePiece;
    if (state.enemyData.movePieceEnemyMovePiece == null) {
        state.enemyData.movePieceEnemyMovePiece = try createRandomMovePiece(state);
    }
    if (data.spawnDelay == null) data.spawnDelay = state.gameTime + 64;
    if (data.spawnDelay.? > state.gameTime) return;
    if (data.direction == null) {
        try chooseDirection(enemy, state);
    }
    if (data.executeMoveTime) |executeTime| {
        if (executeTime <= state.gameTime) {
            try movePieceZig.attackMovePieceCheckPlayerHit(&enemy.position, state.enemyData.movePieceEnemyMovePiece.?, data.direction.?, state);
            try chooseDirection(enemy, state);
            data.executeMoveTime = null;
        }
    }
}

fn chooseDirection(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const movePiece = state.enemyData.movePieceEnemyMovePiece.?;
    const data = &enemy.enemyTypeData.movePiece;
    data.direction = try movePieceZig.getRandomValidMoveDirectionForMovePiece(enemy.position, movePiece, state);
}

fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = enemy.enemyTypeData.movePiece;
    if (state.enemyData.movePieceEnemyMovePiece == null or data.direction == null) return;
    const movePiece = state.enemyData.movePieceEnemyMovePiece.?;
    const enemyDirection = data.direction.?;
    const curTilePos = main.gamePositionToTilePosition(enemy.position);
    try enemyVulkanZig.setupVerticesGroundForMovePiece(curTilePos, movePiece, enemyDirection, 1, state);
}

fn setupVerticesGroundStepFunction(pos: main.TilePosition, visualizedDirection: u8, context: void, state: *main.GameState) !void {
    _ = context;
    const attackPosition: main.Position = .{
        .x = @as(f32, @floatFromInt(pos.x)) * main.TILESIZE,
        .y = @as(f32, @floatFromInt(pos.y)) * main.TILESIZE,
    };
    const rotation: f32 = @as(f32, @floatFromInt(visualizedDirection)) * std.math.pi / 2.0;
    enemyVulkanZig.addRedArrowTileSprites(attackPosition, 1, rotation, state);
}

fn createRandomMovePiece(state: *main.GameState) !movePieceZig.MovePiece {
    const newGamePlusBonusLength = @min(state.newGamePlus, 2);
    const stepsLength: usize = std.crypto.random.intRangeLessThan(usize, 0, 2) + 2 + newGamePlusBonusLength;
    const steps: []movePieceZig.MoveStep = try state.allocator.alloc(movePieceZig.MoveStep, stepsLength);
    const movePiece: movePieceZig.MovePiece = .{ .steps = steps };
    var currDirection: u8 = movePieceZig.DIRECTION_UP;
    for (movePiece.steps) |*step| {
        step.direction = currDirection;
        step.stepCount = @as(u8, @intFromFloat(std.crypto.random.float(f32) * 2.0)) + 1;
        currDirection = @mod(currDirection + (@as(u8, @intFromFloat(std.crypto.random.float(f32) * 2.0)) * 2 + 1), 4);
    }
    return movePiece;
}
