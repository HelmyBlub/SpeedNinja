const std = @import("std");
const main = @import("main.zig");

pub const MovePiece = struct {
    steps: []const MoveStep,
};

pub const MoveStep = struct {
    direction: u8,
    stepCount: u8,
};

pub const DIRECTION_RIGHT = 0;
pub const DIRECTION_DOWN = 1;
pub const DIRECTION_LEFT = 2;
pub const DIRECTION_UP = 3;

pub fn setRandomMovePiece(index: usize, state: *main.GameState) !void {
    const player = &state.player;
    const rand = std.crypto.random;
    if (player.availableMovePieces.items.len > 0) {
        const randomPieceIndex: usize = @intFromFloat(rand.float(f32) * @as(f32, @floatFromInt(player.availableMovePieces.items.len)));
        const randomPiece = player.availableMovePieces.swapRemove(randomPieceIndex);
        if (player.moveOptions.items.len <= index) {
            try player.moveOptions.append(randomPiece);
        } else {
            try player.usedMovePieces.append(player.moveOptions.items[index]);
            player.moveOptions.items[index] = randomPiece;
        }
    } else if (player.moveOptions.items.len > index) {
        const removedPiece = player.moveOptions.swapRemove(index);
        try player.usedMovePieces.append(removedPiece);
    }
}

pub fn setupMovePieces(state: *main.GameState) !void {
    try state.player.availableMovePieces.appendSlice(state.movePieces);
    try setRandomMovePiece(0, state);
    try setRandomMovePiece(1, state);
    try setRandomMovePiece(2, state);
}

pub fn createMovePieces() []const MovePiece {
    const movePieces = [_]MovePiece{
        .{ .steps = &[_]MoveStep{
            .{ .direction = DIRECTION_UP, .stepCount = 2 },
            .{ .direction = DIRECTION_RIGHT, .stepCount = 2 },
            .{ .direction = DIRECTION_UP, .stepCount = 2 },
        } },
        .{ .steps = &[_]MoveStep{
            .{ .direction = DIRECTION_UP, .stepCount = 2 },
            .{ .direction = DIRECTION_LEFT, .stepCount = 2 },
            .{ .direction = DIRECTION_UP, .stepCount = 2 },
        } },
        .{ .steps = &[_]MoveStep{
            .{ .direction = DIRECTION_UP, .stepCount = 2 },
            .{ .direction = DIRECTION_LEFT, .stepCount = 2 },
            .{ .direction = DIRECTION_DOWN, .stepCount = 1 },
        } },
        .{ .steps = &[_]MoveStep{
            .{ .direction = DIRECTION_UP, .stepCount = 1 },
            .{ .direction = DIRECTION_RIGHT, .stepCount = 1 },
            .{ .direction = DIRECTION_UP, .stepCount = 1 },
            .{ .direction = DIRECTION_RIGHT, .stepCount = 1 },
            .{ .direction = DIRECTION_UP, .stepCount = 1 },
        } },
        .{ .steps = &[_]MoveStep{
            .{ .direction = DIRECTION_UP, .stepCount = 2 },
        } },
        .{ .steps = &[_]MoveStep{
            .{ .direction = DIRECTION_UP, .stepCount = 3 },
        } },
        .{ .steps = &[_]MoveStep{
            .{ .direction = DIRECTION_UP, .stepCount = 4 },
        } },
    };
    return &movePieces;
}

pub fn tickPlayerMovePiece(state: *main.GameState) !void {
    if (state.player.executeMovePice) |executeMovePice| {
        const step = executeMovePice.steps[0];
        if (executeMovePice.steps.len > 1) {
            state.player.executeMovePice = .{ .steps = executeMovePice.steps[1..] };
        } else {
            state.player.executeMovePice = null;
        }
        const direction = @mod(step.direction + state.player.executeDirection + 1, 4);
        const stepAmount: f32 = @as(f32, @floatFromInt(step.stepCount)) * main.TILESIZE;
        try checkEnemyHitOnMoveStep(stepAmount, direction, state);
        switch (direction) {
            DIRECTION_RIGHT => {
                for (0..step.stepCount) |i| {
                    try state.player.afterImages.append(.{ .deleteTime = state.gameTime + 50 + @as(i64, @intCast(i)) * 10, .position = .{
                        .x = state.player.position.x + @as(f32, @floatFromInt(i)) * main.TILESIZE,
                        .y = state.player.position.y,
                    } });
                }
                state.player.position.x += stepAmount;
            },
            DIRECTION_DOWN => {
                for (0..step.stepCount) |i| {
                    try state.player.afterImages.append(.{ .deleteTime = state.gameTime + 50 + @as(i64, @intCast(i)) * 10, .position = .{
                        .x = state.player.position.x,
                        .y = state.player.position.y + @as(f32, @floatFromInt(i)) * main.TILESIZE,
                    } });
                }
                state.player.position.y += stepAmount;
            },
            DIRECTION_LEFT => {
                for (0..step.stepCount) |i| {
                    try state.player.afterImages.append(.{ .deleteTime = state.gameTime + 50 + @as(i64, @intCast(i)) * 10, .position = .{
                        .x = state.player.position.x - @as(f32, @floatFromInt(i)) * main.TILESIZE,
                        .y = state.player.position.y,
                    } });
                }
                state.player.position.x -= stepAmount;
            },
            else => {
                for (0..step.stepCount) |i| {
                    try state.player.afterImages.append(.{ .deleteTime = state.gameTime + 50 + @as(i64, @intCast(i)) * 10, .position = .{
                        .x = state.player.position.x,
                        .y = state.player.position.y - @as(f32, @floatFromInt(i)) * main.TILESIZE,
                    } });
                }
                state.player.position.y -= stepAmount;
            },
        }
    }
}

pub fn movePlayerByMovePiece(movePieceIndex: usize, directionInput: u8, state: *main.GameState) !void {
    if (state.player.executeMovePice != null) return;
    state.player.executeMovePice = state.player.moveOptions.items[movePieceIndex];
    state.player.executeDirection = directionInput;
    try setRandomMovePiece(movePieceIndex, state);
}

pub fn resetPieces(state: *main.GameState) !void {
    const player = &state.player;
    try player.availableMovePieces.appendSlice(player.usedMovePieces.items);
    player.usedMovePieces.clearRetainingCapacity();
    while (player.moveOptions.items.len < 3) {
        try setRandomMovePiece(3, state);
    }
}

fn checkEnemyHitOnMoveStep(stepAmount: f32, direction: u8, state: *main.GameState) !void {
    var position: main.Position = state.player.position;
    var enemyIndex: usize = 0;
    var left: f32 = position.x - main.TILESIZE / 2;
    var top: f32 = position.y - main.TILESIZE / 2;
    var width: f32 = main.TILESIZE;
    var height: f32 = main.TILESIZE;
    switch (direction) {
        DIRECTION_RIGHT => {
            width += stepAmount;
        },
        DIRECTION_DOWN => {
            height += stepAmount;
        },
        DIRECTION_LEFT => {
            left -= stepAmount;
            width += stepAmount;
        },
        else => {
            top -= stepAmount;
            height += stepAmount;
        },
    }

    const rand = std.crypto.random;
    while (enemyIndex < state.enemies.items.len) {
        const enemy = state.enemies.items[enemyIndex];
        if (enemy.x > left and enemy.x < left + width and enemy.y > top and enemy.y < top + height) {
            const deadEnemy = state.enemies.swapRemove(enemyIndex);
            const randomAngle = rand.float(f32) * std.math.pi;
            try state.enemyDeath.append(.{ .deathTime = state.gameTime, .position = deadEnemy, .cutAngle = randomAngle });
            try resetPieces(state);
        } else {
            enemyIndex += 1;
        }
    }
    position.x += stepAmount;
}
