const std = @import("std");
const windowSdlZig = @import("windowSdl.zig");
const initVulkanZig = @import("vulkan/initVulkan.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");

pub const TILESIZE = 20;
pub const GameState = struct {
    vkState: initVulkanZig.VkState = .{},
    allocator: std.mem.Allocator = undefined,
    camera: Camera = .{ .position = .{ .x = 0, .y = 0 }, .zoom = 1 },
    movePieces: []const MovePiece,
    round: u32 = 1,
    roundEndTime: ?i64 = null,
    mapTileRadius: u32 = 16,
    enemies: std.ArrayList(Position),
    player: Player,
    gameEnded: bool = false,
};

pub const DIRECTION_RIGHT = 0;
pub const DIRECTION_DOWN = 1;
pub const DIRECTION_LEFT = 2;
pub const DIRECTION_UP = 3;

pub const Player = struct {
    position: Position = .{ .x = 0, .y = 0 },
    choosenMoveOptionIndex: ?usize = null,
    moveOptions: std.ArrayList(MovePiece),
};

pub const MovePiece = struct {
    steps: []const MoveStep,
};

pub const MoveStep = struct {
    direction: u8,
    stepCount: u8,
};

pub const Position: type = struct {
    x: f32,
    y: f32,
};

pub const Camera: type = struct {
    position: Position,
    zoom: f32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try startGame(allocator);
}

fn startGame(allocator: std.mem.Allocator) !void {
    std.debug.print("game run start\n", .{});
    var state: GameState = try createGameState(allocator);
    defer destroyGameState(&state);
    try mainLoop(&state);
}

fn mainLoop(state: *GameState) !void {
    while (!state.gameEnded) {
        if (state.enemies.items.len == 0) {
            state.roundEndTime = std.time.timestamp() + 30;
            state.round += 1;
            try setupEnemies(state);
        }
        if (state.roundEndTime != null and state.roundEndTime.? < std.time.timestamp()) {
            state.roundEndTime = null;
            state.round = 1;
        }
        try windowSdlZig.handleEvents(state);
        try paintVulkanZig.drawFrame(state);
        std.Thread.sleep(5_000_000);
    }
}

fn createGameState(allocator: std.mem.Allocator) !GameState {
    var state: GameState = .{
        .movePieces = createMovePieces(),
        .player = .{
            .moveOptions = std.ArrayList(MovePiece).init(allocator),
        },
        .enemies = std.ArrayList(Position).init(allocator),
    };
    state.allocator = allocator;
    try windowSdlZig.initWindowSdl();
    try initVulkanZig.initVulkan(&state);
    try setRandomMovePiece(0, &state);
    try setRandomMovePiece(1, &state);
    try setRandomMovePiece(2, &state);
    try setupEnemies(&state);

    return state;
}

fn destroyGameState(state: *GameState) void {
    initVulkanZig.destroyPaintVulkan(&state.vkState, state.allocator) catch {
        std.debug.print("failed to destroy window and vulkan\n", .{});
    };
    windowSdlZig.destroyWindowSdl();
    state.player.moveOptions.deinit();
    state.enemies.deinit();
}

pub fn setRandomMovePiece(index: usize, state: *GameState) !void {
    const rand = std.crypto.random;
    const randomPiece: usize = @intFromFloat(rand.float(f32) * @as(f32, @floatFromInt(state.movePieces.len)));
    if (state.player.moveOptions.items.len <= index) {
        try state.player.moveOptions.append(state.movePieces[randomPiece]);
    } else {
        state.player.moveOptions.items[index] = state.movePieces[randomPiece];
    }
}

fn setupEnemies(state: *GameState) !void {
    state.enemies.clearRetainingCapacity();
    const rand = std.crypto.random;
    const length = 16;
    for (0..state.round) |_| {
        const randomTileX: i16 = @as(i16, @intFromFloat(rand.float(f32) * length)) - length / 2;
        const randomTileY: i16 = @as(i16, @intFromFloat(rand.float(f32) * length)) - length / 2;
        try state.enemies.append(.{
            .x = @floatFromInt(randomTileX * TILESIZE),
            .y = @floatFromInt(randomTileY * TILESIZE),
        });
    }
}

fn createMovePieces() []const MovePiece {
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
            .{ .direction = DIRECTION_RIGHT, .stepCount = 2 },
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

pub fn movePlayerByMovePiece(movePieceIndex: usize, directionInput: u8, state: *GameState) !void {
    for (state.player.moveOptions.items[movePieceIndex].steps) |step| {
        const direction = @mod(step.direction + directionInput + 1, 4);
        const stepAmount: f32 = @as(f32, @floatFromInt(step.stepCount)) * TILESIZE;
        checkEnemyHitOnMoveStep(stepAmount, direction, state);
        switch (direction) {
            DIRECTION_RIGHT => {
                state.player.position.x += stepAmount;
            },
            DIRECTION_DOWN => {
                state.player.position.y += stepAmount;
            },
            DIRECTION_LEFT => {
                state.player.position.x -= stepAmount;
            },
            else => {
                state.player.position.y -= stepAmount;
            },
        }
    }
    try setRandomMovePiece(movePieceIndex, state);
}

fn checkEnemyHitOnMoveStep(stepAmount: f32, direction: u8, state: *GameState) void {
    var position: Position = state.player.position;
    var enemyIndex: usize = 0;
    var left: f32 = position.x - TILESIZE / 2;
    var top: f32 = position.y - TILESIZE / 2;
    var width: f32 = TILESIZE;
    var height: f32 = TILESIZE;
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

    while (enemyIndex < state.enemies.items.len) {
        const enemy = state.enemies.items[enemyIndex];
        if (enemy.x > left and enemy.x < left + width and enemy.y > top and enemy.y < top + height) {
            _ = state.enemies.swapRemove(enemyIndex);
        } else {
            enemyIndex += 1;
        }
    }
    position.x += stepAmount;
}
