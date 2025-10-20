const std = @import("std");
const main = @import("main.zig");
const playerZig = @import("player.zig");
const inputZig = @import("input.zig");

pub const AutoTestData = struct {
    mode: TestMode = .record,
    recordRunEventData: std.ArrayList(GameEventData),
    recordRunStartSeed: u64 = 0,
    recordNewGamePlus: u32 = 0,
    recordFreezeTime: bool = false,
    replayRunInputsIndex: usize = 0,
    replayFreezeTickCounter: u32 = 0,
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
    state.autoTest.recordRunStartSeed = randomSeed;
    state.seededRandom.seed(state.autoTest.recordRunStartSeed);
    state.autoTest.recordRunEventData.clearRetainingCapacity();
    state.autoTest.recordNewGamePlus = state.newGamePlus;
    state.autoTest.recordFreezeTime = state.timeFreezeOnHit;
}

pub fn recordPlayerInput(action: inputZig.PlayerAction, player: *playerZig.Player, state: *main.GameState) !void {
    if (state.autoTest.mode != .record) return;
    for (state.players.items, 0..) |*playerIt, index| {
        if (player == playerIt) {
            try state.autoTest.recordRunEventData.append(.{ .gameTime = state.gameTime, .eventData = .{ .playerInput = .{ .action = action, .playerIndex = index } } });
            break;
        }
    }
}

pub fn tickRecordRun(state: *main.GameState) !void {
    if (state.autoTest.mode != .record) return;
    if (state.autoTest.recordRunEventData.items.len == 0) return;
    const last = &state.autoTest.recordRunEventData.items[state.autoTest.recordRunEventData.items.len - 1];
    if (last.eventData == .freezeTime) {
        last.eventData.freezeTime += 1;
    }
}

pub fn recordFreezeTime(state: *main.GameState) !void {
    if (state.autoTest.mode != .record) return;
    if (state.timeFreezeStart != null) {
        try state.autoTest.recordRunEventData.append(.{ .gameTime = state.gameTime, .eventData = .{ .freezeTime = 0 } });
    }
}

pub fn replayRecording(state: *main.GameState) !void {
    if (state.autoTest.recordRunEventData.items.len == 0) return;
    state.autoTest.mode = .replay;
    state.autoTest.replayRunInputsIndex = 0;
    state.seededRandom.seed(state.autoTest.recordRunStartSeed);
    state.timeFreezeOnHit = state.autoTest.recordFreezeTime;
    try main.runStart(state, state.autoTest.recordNewGamePlus);
}

pub fn tickReplayInputs(state: *main.GameState) !void {
    if (state.autoTest.mode != .replay) return;
    if (state.timeFreezeStart) |_| {
        if (state.autoTest.replayFreezeTickCounter > 0) {
            state.autoTest.replayFreezeTickCounter -= 1;
            return;
        }
        state.timeFreezeStart = null;
    }
    while (true) {
        const nextAction = state.autoTest.recordRunEventData.items[state.autoTest.replayRunInputsIndex];
        if (state.gameTime == nextAction.gameTime) {
            switch (nextAction.eventData) {
                .playerInput => |data| {
                    try inputZig.handlePlayerAction(data.action, &state.players.items[data.playerIndex], state);
                    state.autoTest.replayRunInputsIndex += 1;
                    if (state.autoTest.recordRunEventData.items.len <= state.autoTest.replayRunInputsIndex) {
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
