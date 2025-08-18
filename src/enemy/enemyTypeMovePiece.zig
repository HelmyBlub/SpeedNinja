const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");

pub const EnemyTypeMovePieceData = struct {
    direction: ?u8 = null,
    executeMove: bool = false,
};

pub fn create() enemyZig.EnemyFunctions {
    return enemyZig.EnemyFunctions{
        .createSpawnEnemyEntryEnemy = createSpawnEnemyEntryEnemy,
        .tick = tick,
        .setupVerticesGround = setupVerticesGround,
    };
}

fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_ENEMY_MOVING,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .movePiece = .{},
        },
    };
}

fn tick(enemy: *enemyZig.Enemy, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &enemy.enemyTypeData.movePiece;
    if (state.enemyData.movePieceEnemyMovePiece == null) {
        state.enemyData.movePieceEnemyMovePiece = try createRandomMovePiece(state.allocator);
    }
    if (data.direction == null) {
        data.direction = std.crypto.random.int(u2);
    }
    if (data.executeMove) {
        movePieceZig.movePositionByPiece(&enemy.position, state.enemyData.movePieceEnemyMovePiece.?, data.direction.?);
        data.direction = std.crypto.random.int(u2);
        data.executeMove = false;
    }
}

fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) void {
    const data = enemy.enemyTypeData.movePiece;
    if (state.enemyData.movePieceEnemyMovePiece == null or data.direction == null) return;
    const enemyDirection = data.direction.?;
    const movePiece = state.enemyData.movePieceEnemyMovePiece.?;
    var curTilePos = main.gamePositionToTilePosition(enemy.position);
    for (movePiece.steps, 0..) |step, stepIndex| {
        const currDirection = @mod(step.direction + enemyDirection + 1, 4);
        const stepDirection = movePieceZig.getStepDirectionTile(currDirection);
        for (0..step.stepCount) |stepCountIndex| {
            curTilePos.x += stepDirection.x;
            curTilePos.y += stepDirection.y;
            var visualizedDirection = currDirection;
            if (stepCountIndex == step.stepCount - 1 and movePiece.steps.len > stepIndex + 1) {
                visualizedDirection = @mod(movePiece.steps[stepIndex + 1].direction + enemyDirection + 1, 4);
            }
            const attackPosition: main.Position = .{
                .x = @as(f32, @floatFromInt(curTilePos.x)) * main.TILESIZE,
                .y = @as(f32, @floatFromInt(curTilePos.y)) * main.TILESIZE,
            };
            const rotation: f32 = @as(f32, @floatFromInt(visualizedDirection)) * std.math.pi / 2.0;
            enemyVulkanZig.addRedArrowTileSprites(attackPosition, 1, rotation, state);
        }
    }
}

pub fn createRandomMovePiece(allocator: std.mem.Allocator) !movePieceZig.MovePiece {
    const stepsLength: usize = @intFromFloat(std.crypto.random.float(f32) * 2.0 + 2);
    const steps: []movePieceZig.MoveStep = try allocator.alloc(movePieceZig.MoveStep, stepsLength);
    const movePiece: movePieceZig.MovePiece = .{ .steps = steps };
    var currDirection: u8 = movePieceZig.DIRECTION_UP;
    for (movePiece.steps) |*step| {
        step.direction = currDirection;
        step.stepCount = @as(u8, @intFromFloat(std.crypto.random.float(f32) * 2.0)) + 1;
        currDirection = @mod(currDirection + (@as(u8, @intFromFloat(std.crypto.random.float(f32) * 2.0)) * 2 + 1), 4);
    }
    return movePiece;
}
