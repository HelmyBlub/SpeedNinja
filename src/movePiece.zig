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

pub fn setRandomMovePiece(player: *main.Player, index: usize) !void {
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

pub fn setupMovePieces(player: *main.Player, state: *main.GameState) !void {
    try player.availableMovePieces.appendSlice(state.movePieces);
    try setRandomMovePiece(player, 0);
    try setRandomMovePiece(player, 1);
    try setRandomMovePiece(player, 2);
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

pub fn tickPlayerMovePiece(player: *main.Player, state: *main.GameState) !void {
    if (player.executeMovePiece) |executeMovePiece| {
        const step = executeMovePiece.steps[0];
        if (executeMovePiece.steps.len > 1) {
            player.executeMovePiece = .{ .steps = executeMovePiece.steps[1..] };
        } else {
            player.executeMovePiece = null;
        }
        const direction = @mod(step.direction + player.executeDirection + 1, 4);
        if (!player.slashedLastMoveTile) ninjaDogVulkanZig.movedAnimate(player, direction);
        switch (direction) {
            DIRECTION_RIGHT => {
                try stepAndCheckEnemyHit(player, step.stepCount, direction, .{ .x = 1, .y = 0 }, state);
            },
            DIRECTION_DOWN => {
                try stepAndCheckEnemyHit(player, step.stepCount, direction, .{ .x = 0, .y = 1 }, state);
            },
            DIRECTION_LEFT => {
                try stepAndCheckEnemyHit(player, step.stepCount, direction, .{ .x = -1, .y = 0 }, state);
            },
            else => {
                try stepAndCheckEnemyHit(player, step.stepCount, direction, .{ .x = 0, .y = -1 }, state);
            },
        }
        if (player.executeMovePiece == null) {
            ninjaDogVulkanZig.moveHandToCenter(player, state);
        }
    }
}

fn stepAndCheckEnemyHit(player: *main.Player, stepCount: u8, direction: u8, stepDirection: main.Position, state: *main.GameState) !void {
    for (0..stepCount) |_| {
        player.slashedLastMoveTile = false;
        try ninjaDogVulkanZig.addAfterImages(1, stepDirection, player, state);
        player.position.x += stepDirection.x * main.TILESIZE;
        player.position.y += stepDirection.y * main.TILESIZE;
        if (try checkEnemyHitOnMoveStep(player, 0, direction, state)) {
            ninjaDogVulkanZig.bladeSlashAnimate(player);
            player.slashedLastMoveTile = true;
        }
    }
}

pub fn movePlayerByMovePiece(player: *main.Player, movePieceIndex: usize, directionInput: u8, state: *main.GameState) !void {
    if (player.executeMovePiece != null) return;
    player.executeMovePiece = player.moveOptions.items[movePieceIndex];
    player.executeDirection = directionInput;
    try setRandomMovePiece(player, movePieceIndex);
    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_NINJA_MOVE_INDICIES[0..], 0);
}

pub fn resetPieces(player: *main.Player) !void {
    try player.availableMovePieces.appendSlice(player.usedMovePieces.items);
    player.usedMovePieces.clearRetainingCapacity();
    while (player.moveOptions.items.len < 3) {
        try setRandomMovePiece(player, 3);
    }
}

fn checkEnemyHitOnMoveStep(player: *main.Player, stepAmount: f32, direction: u8, state: *main.GameState) !bool {
    var position: main.Position = player.position;
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
            const cutAngle = player.paintData.bladeRotation + std.math.pi / 2.0;
            try state.enemyDeath.append(.{ .deathTime = state.gameTime, .position = deadEnemy, .cutAngle = cutAngle, .force = rand.float(f32) + 0.2 });
            try resetPieces(player);
            hitSomething = true;
        } else {
            enemyIndex += 1;
        }
    }
    position.x += stepAmount;
    return hitSomething;
}
