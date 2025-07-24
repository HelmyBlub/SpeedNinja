const std = @import("std");
const main = @import("main.zig");
const ninjaDogVulkanZig = @import("vulkan/ninjaDogVulkan.zig");
const soundMixerZig = @import("soundMixer.zig");
const shopZig = @import("shop.zig");

pub const MovePiece = struct {
    steps: []MoveStep,
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
            player.moveOptions.items[index] = randomPiece;
        }
    } else if (player.moveOptions.items.len > index) {
        _ = player.moveOptions.swapRemove(index);
    }
}

pub fn setupMovePieces(player: *main.Player, state: *main.GameState) !void {
    if (player.totalMovePieces.items.len > 0) {
        for (player.totalMovePieces.items) |movePiece| {
            state.allocator.free(movePiece.steps);
        }
        player.totalMovePieces.clearRetainingCapacity();
    }
    player.availableMovePieces.clearRetainingCapacity();
    player.moveOptions.clearRetainingCapacity();
    total: while (player.totalMovePieces.items.len < 7) {
        const randomPiece = try createRandomMovePiece(state.allocator);
        for (player.totalMovePieces.items) |otherPiece| {
            if (areSameMovePieces(randomPiece, otherPiece)) {
                state.allocator.free(randomPiece.steps);
                std.debug.print("prevented same piece\n", .{});
                continue :total;
            }
        }
        try player.totalMovePieces.append(randomPiece);
    }

    try player.availableMovePieces.appendSlice(player.totalMovePieces.items);
    try setRandomMovePiece(player, 0);
    try setRandomMovePiece(player, 1);
    try setRandomMovePiece(player, 2);
}

pub fn getStepDirection(direction: u8) main.Position {
    switch (direction) {
        DIRECTION_RIGHT => {
            return .{ .x = 1, .y = 0 };
        },
        DIRECTION_DOWN => {
            return .{ .x = 0, .y = 1 };
        },
        DIRECTION_LEFT => {
            return .{ .x = -1, .y = 0 };
        },
        else => {
            return .{ .x = 0, .y = -1 };
        },
    }
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
        try stepAndCheckEnemyHit(player, step.stepCount, direction, getStepDirection(direction), state);
        if (player.executeMovePiece == null) {
            ninjaDogVulkanZig.moveHandToCenter(player, state);
            if (state.gamePhase == .shopping) {
                try shopZig.executeShopActionForPlayer(player, state);
            }
        }
    }
}

fn stepAndCheckEnemyHit(player: *main.Player, stepCount: u8, direction: u8, stepDirection: main.Position, state: *main.GameState) !void {
    for (0..stepCount) |i| {
        player.slashedLastMoveTile = false;
        try ninjaDogVulkanZig.addAfterImages(1, stepDirection, player, state);
        player.position.x += stepDirection.x * main.TILESIZE;
        player.position.y += stepDirection.y * main.TILESIZE;
        if (try checkEnemyHitOnMoveStep(player, 0, direction, state)) {
            ninjaDogVulkanZig.bladeSlashAnimate(player);
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_BLADE_CUT_INDICIES[0..], i * 25);
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
    player.availableMovePieces.clearRetainingCapacity();
    try player.availableMovePieces.appendSlice(player.totalMovePieces.items);
    for (player.moveOptions.items) |moveOption| {
        for (player.availableMovePieces.items, 0..) |piece, index| {
            if (areSameMovePieces(moveOption, piece)) {
                _ = player.availableMovePieces.swapRemove(index);
                break;
            }
        }
    }
    while (player.moveOptions.items.len < 3 and player.availableMovePieces.items.len > 0) {
        try setRandomMovePiece(player, 3);
    }
}

pub fn areSameMovePieces(movePiece1: MovePiece, movePiece2: MovePiece) bool {
    if (movePiece1.steps.len != movePiece2.steps.len) return false;
    for (movePiece1.steps, movePiece2.steps) |stepA, stepB| {
        if (stepA.direction != stepB.direction) return false;
        if (stepA.stepCount != stepB.stepCount) return false;
    }
    return true;
}

pub fn removeMovePiece(player: *main.Player, movePieceIndex: usize, allocator: std.mem.Allocator) !void {
    const removedPiece = player.totalMovePieces.orderedRemove(movePieceIndex);
    var removed = false;
    for (player.moveOptions.items, 0..) |option, index| {
        if (areSameMovePieces(removedPiece, option)) {
            try setRandomMovePiece(player, index);
            removed = true;
        }
    }
    if (!removed) {
        for (player.availableMovePieces.items, 0..) |option, index| {
            if (areSameMovePieces(removedPiece, option)) {
                _ = player.availableMovePieces.swapRemove(index);
                removed = true;
            }
        }
    }
    allocator.free(removedPiece.steps);
}

pub fn createRandomMovePiece(allocator: std.mem.Allocator) !MovePiece {
    const stepsLength: usize = @intFromFloat(std.crypto.random.float(f32) * 3.0 + 1);
    const steps: []MoveStep = try allocator.alloc(MoveStep, stepsLength);
    const movePiece: MovePiece = .{ .steps = steps };
    var currDirection: u8 = DIRECTION_UP;
    for (movePiece.steps) |*step| {
        step.direction = currDirection;
        step.stepCount = @as(u8, @intFromFloat(std.crypto.random.float(f32) * 3.0)) + 1;
        currDirection = @mod(currDirection + (@as(u8, @intFromFloat(std.crypto.random.float(f32) * 2.0)) * 2 + 1), 4);
    }
    return movePiece;
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
        if (enemy.position.x > left and enemy.position.x < left + width and enemy.position.y > top and enemy.position.y < top + height) {
            const deadEnemy = state.enemies.swapRemove(enemyIndex);
            const cutAngle = player.paintData.bladeRotation + std.math.pi / 2.0;
            try state.enemyDeath.append(.{ .deathTime = state.gameTime, .position = deadEnemy.position, .cutAngle = cutAngle, .force = rand.float(f32) + 0.2 });
            try resetPieces(player);
            hitSomething = true;
        } else {
            enemyIndex += 1;
        }
    }
    position.x += stepAmount;
    return hitSomething;
}
