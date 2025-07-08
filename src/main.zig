const std = @import("std");
const windowSdlZig = @import("windowSdl.zig");
const initVulkanZig = @import("vulkan/initVulkan.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");

pub const GameState = struct {
    vkState: initVulkanZig.VkState = .{},
    allocator: std.mem.Allocator = undefined,
    camera: Camera = .{ .position = .{ .x = 0, .y = 0 }, .zoom = 1 },
    player: Player,
    gameEnded: bool = false,
};

pub const Player = struct {
    position: Position = .{ .x = 0, .y = 0 },
    choosenMoveOptionIndex: ?usize = null,
    moveOptions: []const MovePiece,
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
    const movePieces: [3]MovePiece = [3]MovePiece{
        .{ .steps = &[3]MoveStep{
            .{ .direction = 0, .stepCount = 2 },
            .{ .direction = 1, .stepCount = 2 },
            .{ .direction = 0, .stepCount = 2 },
        } },
        .{ .steps = &[3]MoveStep{
            .{ .direction = 0, .stepCount = 2 },
            .{ .direction = 3, .stepCount = 2 },
            .{ .direction = 0, .stepCount = 2 },
        } },
        .{ .steps = &[3]MoveStep{
            .{ .direction = 0, .stepCount = 2 },
            .{ .direction = 1, .stepCount = 2 },
            .{ .direction = 2, .stepCount = 2 },
        } },
    };
    var state: GameState = .{
        .player = .{ .moveOptions = &movePieces },
    };
    try createGameState(allocator, &state);
    defer destroyGameState(&state);
    try mainLoop(&state);
}

fn mainLoop(state: *GameState) !void {
    while (!state.gameEnded) {
        try windowSdlZig.handleEvents(state);
        try paintVulkanZig.drawFrame(state);
    }
}

fn createGameState(allocator: std.mem.Allocator, state: *GameState) !void {
    state.allocator = allocator;
    try windowSdlZig.initWindowSdl();
    try initVulkanZig.initVulkan(state);
}

fn destroyGameState(state: *GameState) void {
    initVulkanZig.destroyPaintVulkan(&state.vkState, state.allocator) catch {
        std.debug.print("failed to destroy window and vulkan\n", .{});
    };
    windowSdlZig.destroyWindowSdl();
}

pub fn movePlayerByMovePiece(movePieceIndex: usize, directionInput: u8, state: *GameState) void {
    const moveStepSize = 20;
    for (state.player.moveOptions[movePieceIndex].steps) |step| {
        const direction = @mod(step.direction + directionInput, 4);
        const stepAmount: f32 = @as(f32, @floatFromInt(step.stepCount)) * moveStepSize;
        switch (direction) {
            0 => {
                state.player.position.x += stepAmount;
            },
            1 => {
                state.player.position.y += stepAmount;
            },
            2 => {
                state.player.position.x -= stepAmount;
            },
            else => {
                state.player.position.y -= stepAmount;
            },
        }
    }
}
