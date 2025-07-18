const std = @import("std");
const main = @import("main.zig");
const ninjaDogVulkanZig = @import("vulkan/ninjaDogVulkan.zig");
const soundMixerZig = @import("soundMixer.zig");

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
            .{ .direction = DIRECTION_UP, .stepCount = 1 },
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
    if (state.player.executeMovePiece) |executeMovePiece| {
        const step = executeMovePiece.steps[0];
        if (executeMovePiece.steps.len > 1) {
            state.player.executeMovePiece = .{ .steps = executeMovePiece.steps[1..] };
        } else {
            state.player.executeMovePiece = null;
        }
        const direction = @mod(step.direction + state.player.executeDirection + 1, 4);
        if (!state.player.slashedLastMoveTile) ninjaDogVulkanZig.movedAnimate(direction, state);
        switch (direction) {
            DIRECTION_RIGHT => {
                try stepAndCheckEnemyHit(step.stepCount, direction, .{ .x = 1, .y = 0 }, state);
            },
            DIRECTION_DOWN => {
                try stepAndCheckEnemyHit(step.stepCount, direction, .{ .x = 0, .y = 1 }, state);
            },
            DIRECTION_LEFT => {
                try stepAndCheckEnemyHit(step.stepCount, direction, .{ .x = -1, .y = 0 }, state);
            },
            else => {
                try stepAndCheckEnemyHit(step.stepCount, direction, .{ .x = 0, .y = -1 }, state);
            },
        }
        if (state.player.executeMovePiece == null) {
            ninjaDogVulkanZig.moveHandToCenter(state);
        }
    }
}

pub fn stepAndCheckEnemyHit(stepCount: u8, direction: u8, stepDirection: main.Position, state: *main.GameState) !void {
    for (0..stepCount) |_| {
        state.player.slashedLastMoveTile = false;
        try ninjaDogVulkanZig.addAfterImages(1, stepDirection, state.player, state);
        state.player.position.x += stepDirection.x * main.TILESIZE;
        state.player.position.y += stepDirection.y * main.TILESIZE;
        if (try checkEnemyHitOnMoveStep(0, direction, state)) {
            ninjaDogVulkanZig.bladeSlashAnimate(state);
            state.player.slashedLastMoveTile = true;
        }
    }
}

pub fn movePlayerByMovePiece(movePieceIndex: usize, directionInput: u8, state: *main.GameState) !void {
    if (state.player.executeMovePiece != null) return;
    state.player.executeMovePiece = state.player.moveOptions.items[movePieceIndex];
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

fn checkEnemyHitOnMoveStep(stepAmount: f32, direction: u8, state: *main.GameState) !bool {
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
    var hitSomething = false;
    while (enemyIndex < state.enemies.items.len) {
        const enemy = state.enemies.items[enemyIndex];
        if (enemy.x > left and enemy.x < left + width and enemy.y > top and enemy.y < top + height) {
            const deadEnemy = state.enemies.swapRemove(enemyIndex);
            const cutAngle = state.player.paintData.bladeRotation + std.math.pi / 2.0;
            try state.enemyDeath.append(.{ .deathTime = state.gameTime, .position = deadEnemy, .cutAngle = cutAngle, .force = rand.float(f32) + 0.2 });
            try resetPieces(state);
            hitSomething = true;
        } else {
            enemyIndex += 1;
        }
    }
    position.x += stepAmount;
    return hitSomething;
}
