const std = @import("std");
const main = @import("main.zig");
const playerZig = @import("player.zig");
const inputZig = @import("input.zig");

pub const AutoTestData = struct {
    mode: TestMode = .record,
    recordRunInputsData: std.ArrayList(InputData),
    recordRunStartSeed: u64 = 0,
    recordNewGamePlus: u32 = 0,
    replayRunInputsIndex: usize = 0,
};

pub const TestMode = enum {
    record,
    replay,
    none,
};

pub const InputData = struct {
    playerIndex: usize,
    action: inputZig.PlayerAction,
    gameTime: i64,
};

pub fn startRecordingRun(state: *main.GameState) void {
    if (state.autoTest.mode != .record) return;
    const randomSeed = std.crypto.random.int(u64);
    state.autoTest.recordRunStartSeed = randomSeed;
    state.seededRandom.seed(state.autoTest.recordRunStartSeed);
    state.autoTest.recordRunInputsData.clearRetainingCapacity();
    state.autoTest.recordNewGamePlus = state.newGamePlus;
}

pub fn recordPlayerInput(action: inputZig.PlayerAction, player: *playerZig.Player, state: *main.GameState) !void {
    if (state.autoTest.mode != .record) return;
    for (state.players.items, 0..) |*playerIt, index| {
        if (player == playerIt) {
            try state.autoTest.recordRunInputsData.append(.{ .action = action, .playerIndex = index, .gameTime = state.gameTime });
            break;
        }
    }
}

pub fn replayRecording(state: *main.GameState) !void {
    if (state.autoTest.recordRunInputsData.items.len == 0) return;
    state.autoTest.mode = .replay;
    state.autoTest.replayRunInputsIndex = 0;
    state.seededRandom.seed(state.autoTest.recordRunStartSeed);
    try main.runStart(state, state.autoTest.recordNewGamePlus);
}

pub fn tickReplayInputs(state: *main.GameState) !void {
    if (state.autoTest.mode != .replay) return;
    if (state.timeFreezeStart) |_| {
        for (state.players.items) |*player| {
            if (player.executeMovePiece != null) {
                return;
            }
        }
        state.timeFreezeStart = null;
    } else {
        const nextAction = state.autoTest.recordRunInputsData.items[state.autoTest.replayRunInputsIndex];
        if (state.gameTime == nextAction.gameTime) {
            try inputZig.handlePlayerAction(nextAction.action, &state.players.items[nextAction.playerIndex], state);
            state.autoTest.replayRunInputsIndex += 1;
            if (state.autoTest.recordRunInputsData.items.len <= state.autoTest.replayRunInputsIndex) {
                state.autoTest.mode = .none;
            }
        }
    }
}
