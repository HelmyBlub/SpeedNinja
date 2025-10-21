const std = @import("std");
const main = @import("main.zig");
const playerZig = @import("player.zig");
const inputZig = @import("input.zig");

pub const AutoTestData = struct {
    mode: TestMode = .record,
    recording: Recording,
    replayRunInputsIndex: usize = 0,
    replayFreezeTickCounter: u32 = 0,
    maxSpeed: bool = true,
};

pub const Recording = struct {
    runEventData: std.ArrayList(GameEventData),
    runStartSeed: u64 = 0,
    newGamePlus: u32 = 0,
    freezeTime: bool = false,
};

pub const RecordingForFile = struct {
    runEventData: []GameEventData,
    runStartSeed: u64 = 0,
    newGamePlus: u32 = 0,
    freezeTime: bool = false,
};

pub const TestMode = enum {
    record,
    replay,
    none,
};

pub const GameEventData = struct {
    gameTime: i64,
    eventData: GameEventTypeData,
};

const GameEventType = enum {
    playerInput,
    freezeTime,
};

const GameEventTypeData = union(GameEventType) {
    playerInput: PlayerInputData,
    freezeTime: u32,
};

const PlayerInputData = struct {
    playerIndex: usize,
    action: inputZig.PlayerAction,
};

pub fn startRecordingRun(state: *main.GameState) void {
    if (state.autoTest.mode != .record) return;
    const randomSeed = std.crypto.random.int(u64);
    state.autoTest.recording.runStartSeed = randomSeed;
    state.seededRandom.seed(state.autoTest.recording.runStartSeed);
    state.autoTest.recording.runEventData.clearRetainingCapacity();
    state.autoTest.recording.newGamePlus = state.newGamePlus;
    state.autoTest.recording.freezeTime = state.timeFreezeOnHit;
}

pub fn recordPlayerInput(action: inputZig.PlayerAction, player: *playerZig.Player, state: *main.GameState) !void {
    if (state.autoTest.mode != .record) return;
    for (state.players.items, 0..) |*playerIt, index| {
        if (player == playerIt) {
            try state.autoTest.recording.runEventData.append(.{ .gameTime = state.gameTime, .eventData = .{ .playerInput = .{ .action = action, .playerIndex = index } } });
            break;
        }
    }
}

pub fn tickRecordRun(state: *main.GameState) !void {
    if (state.autoTest.mode != .record) return;
    if (state.autoTest.recording.runEventData.items.len == 0) return;

    if (state.timeFreezeStart != null) {
        const last = &state.autoTest.recording.runEventData.items[state.autoTest.recording.runEventData.items.len - 1];
        if (last.eventData == .freezeTime) {
            last.eventData.freezeTime += 1;
        } else {
            try state.autoTest.recording.runEventData.append(.{ .gameTime = state.gameTime, .eventData = .{ .freezeTime = 1 } });
        }
    }
}

pub fn recordFreezeTime(state: *main.GameState) !void {
    if (state.autoTest.mode != .record) return;
    if (state.timeFreezeStart != null) {
        try state.autoTest.recording.runEventData.append(.{ .gameTime = state.gameTime, .eventData = .{ .freezeTime = 0 } });
    }
}

pub fn replayRecording(state: *main.GameState) !void {
    if (state.autoTest.recording.runEventData.items.len == 0) return;
    state.autoTest.mode = .replay;
    state.autoTest.replayRunInputsIndex = 0;
    state.seededRandom.seed(state.autoTest.recording.runStartSeed);
    state.timeFreezeOnHit = state.autoTest.recording.freezeTime;
    try main.runStart(state, state.autoTest.recording.newGamePlus);
}

pub fn tickReplayInputs(state: *main.GameState) !void {
    if (state.autoTest.mode != .replay) return;
    if (state.timeFreezeStart) |_| {
        if (state.autoTest.replayFreezeTickCounter > 1) {
            state.autoTest.replayFreezeTickCounter -= 1;
            return;
        }
    }
    while (true) {
        const nextAction = state.autoTest.recording.runEventData.items[state.autoTest.replayRunInputsIndex];
        if (state.gameTime == nextAction.gameTime) {
            switch (nextAction.eventData) {
                .playerInput => |data| {
                    try inputZig.handlePlayerAction(data.action, &state.players.items[data.playerIndex], state);
                    state.autoTest.replayRunInputsIndex += 1;
                    if (state.autoTest.recording.runEventData.items.len <= state.autoTest.replayRunInputsIndex) {
                        state.autoTest.mode = .none;
                        return;
                    }
                },
                .freezeTime => |data| {
                    state.autoTest.replayRunInputsIndex += 1;
                    state.autoTest.replayFreezeTickCounter = data;
                    return;
                },
            }
        } else {
            return;
        }
    }
}

pub fn saveRecordingToFile(state: *main.GameState) !void {
    if (state.autoTest.recording.runEventData.items.len == 0) return;
    const recordingForFile: RecordingForFile = .{
        .freezeTime = state.autoTest.recording.freezeTime,
        .newGamePlus = state.autoTest.recording.newGamePlus,
        .runStartSeed = state.autoTest.recording.runStartSeed,
        .runEventData = state.autoTest.recording.runEventData.items,
    };
    const json_bytes = try std.json.stringifyAlloc(
        state.allocator,
        recordingForFile,
        .{
            .whitespace = .indent_2, // pretty print
        },
    );
    defer state.allocator.free(json_bytes);
    const file = try std.fs.cwd().createFile("output.json", .{ .truncate = true });
    defer file.close();
    try file.writeAll(json_bytes);
}

pub fn loadRecordingFromFileAndReplay(state: *main.GameState) !void {
    const file = try std.fs.cwd().openFile("output.json", .{});
    defer file.close();

    const file_data = try file.readToEndAlloc(state.allocator, std.math.maxInt(usize));
    defer state.allocator.free(file_data);

    const parsed = try std.json.parseFromSlice(RecordingForFile, state.allocator, file_data, .{});
    defer parsed.deinit();

    state.autoTest.recording.freezeTime = parsed.value.freezeTime;
    state.autoTest.recording.newGamePlus = parsed.value.newGamePlus;
    state.autoTest.recording.runStartSeed = parsed.value.runStartSeed;
    state.autoTest.recording.runEventData.clearAndFree();
    try state.autoTest.recording.runEventData.appendSlice(parsed.value.runEventData);

    try replayRecording(state);
}
