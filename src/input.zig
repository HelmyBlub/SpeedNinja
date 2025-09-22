const std = @import("std");
const main = @import("main.zig");
const windowSdlZig = @import("windowSdl.zig");
const sdl = windowSdlZig.sdl;
const movePieceZig = @import("movePiece.zig");
const shopZig = @import("shop.zig");

pub const PlayerInputData = struct {
    inputDevice: ?InputDeviceData = null,
    lastInputDevice: ?InputDeviceData = null,
    axis0DeadZone: bool = true,
    axis1DeadZone: bool = true,
    axis0Id: u8 = 0,
    axis1Id: u8 = 0,
};

pub const InputJoinData = struct {
    inputDeviceDatas: std.ArrayList(InputJoinDeviceData),
};

pub const InputJoinDeviceData = struct {
    deviceData: InputDeviceData,
    pressTime: i64,
};

pub const InputDevice = enum {
    keyboard,
    gamepad,
};

const InputDeviceData = union(InputDevice) {
    keyboard: ?u32,
    gamepad: u32,
};

pub const PlayerAction = enum {
    pieceSelect1,
    pieceSelect2,
    pieceSelect3,
    moveUp,
    moveDown,
    moveLeft,
    moveRight,
};

const KeyboardKeyBind = struct {
    action: PlayerAction,
    sdlKeyCode: c_int,
};

pub const ButtonDisplay = struct {
    text: []const u8,
    device: InputDevice,
};

const KEYBOARD_MAPPING_1 = [_]KeyboardKeyBind{
    .{ .action = .moveDown, .sdlKeyCode = sdl.SDL_SCANCODE_S },
    .{ .action = .moveUp, .sdlKeyCode = sdl.SDL_SCANCODE_W },
    .{ .action = .moveLeft, .sdlKeyCode = sdl.SDL_SCANCODE_A },
    .{ .action = .moveRight, .sdlKeyCode = sdl.SDL_SCANCODE_D },
    .{ .action = .pieceSelect1, .sdlKeyCode = sdl.SDL_SCANCODE_1 },
    .{ .action = .pieceSelect2, .sdlKeyCode = sdl.SDL_SCANCODE_2 },
    .{ .action = .pieceSelect3, .sdlKeyCode = sdl.SDL_SCANCODE_3 },
};
const KEYBOARD_MAPPING_2 = [_]KeyboardKeyBind{
    .{ .action = .moveDown, .sdlKeyCode = sdl.SDL_SCANCODE_DOWN },
    .{ .action = .moveUp, .sdlKeyCode = sdl.SDL_SCANCODE_UP },
    .{ .action = .moveLeft, .sdlKeyCode = sdl.SDL_SCANCODE_LEFT },
    .{ .action = .moveRight, .sdlKeyCode = sdl.SDL_SCANCODE_RIGHT },
    .{ .action = .pieceSelect1, .sdlKeyCode = sdl.SDL_SCANCODE_KP_1 },
    .{ .action = .pieceSelect2, .sdlKeyCode = sdl.SDL_SCANCODE_KP_2 },
    .{ .action = .pieceSelect3, .sdlKeyCode = sdl.SDL_SCANCODE_KP_3 },
};
const KEYBOARD_MAPPING_3 = [_]KeyboardKeyBind{
    .{ .action = .moveDown, .sdlKeyCode = sdl.SDL_SCANCODE_K },
    .{ .action = .moveUp, .sdlKeyCode = sdl.SDL_SCANCODE_I },
    .{ .action = .moveLeft, .sdlKeyCode = sdl.SDL_SCANCODE_J },
    .{ .action = .moveRight, .sdlKeyCode = sdl.SDL_SCANCODE_L },
    .{ .action = .pieceSelect1, .sdlKeyCode = sdl.SDL_SCANCODE_7 },
    .{ .action = .pieceSelect2, .sdlKeyCode = sdl.SDL_SCANCODE_8 },
    .{ .action = .pieceSelect3, .sdlKeyCode = sdl.SDL_SCANCODE_9 },
};
const KEYBOARD_MAPPINGS = [_][]const KeyboardKeyBind{
    &KEYBOARD_MAPPING_1,
    &KEYBOARD_MAPPING_2,
    &KEYBOARD_MAPPING_3,
};

pub fn handlePlayerInput(event: sdl.SDL_Event, state: *main.GameState) !void {
    for (state.players.items) |*player| {
        if (player.inputData.inputDevice) |device| {
            switch (device) {
                .gamepad => |gamepadId| {
                    try handlePlayerGamepadInput(event, player, gamepadId, state);
                },
                .keyboard => |mappingIndex| {
                    try handlePlayerKeyboardInput(event, player, mappingIndex, state);
                },
            }
        } else {
            try handlePlayerGamepadInput(event, player, null, state);
            try handlePlayerKeyboardInput(event, player, null, state);
        }
    }
    try handleCheckPlayerJoin(event, state);
}

pub fn getDisplayInfoForPlayerAction(player: *main.Player, action: PlayerAction, state: *main.GameState) ?ButtonDisplay {
    var inputDevice: ?InputDeviceData = null;
    if (player.inputData.inputDevice == null) {
        if (player.inputData.lastInputDevice == null or player.inputData.lastInputDevice.? == .keyboard) {
            inputDevice = .{ .keyboard = 0 };
        } else {
            inputDevice = player.inputData.lastInputDevice;
        }
    } else {
        inputDevice = player.inputData.inputDevice;
        if (inputDevice.? == .keyboard and inputDevice.?.keyboard == null) {
            inputDevice = .{ .keyboard = 0 };
        }
    }
    if (inputDevice == null) return null;
    switch (inputDevice.?) {
        .keyboard => |index| {
            const mappings = KEYBOARD_MAPPINGS[index.?];
            for (mappings) |mapping| {
                if (mapping.action == action) {
                    const text = getDisplayTextForScancode(@intCast(mapping.sdlKeyCode), state);
                    return ButtonDisplay{ .text = text, .device = .keyboard };
                }
            }
            return null;
        },
        .gamepad => |_| {
            switch (action) {
                .pieceSelect1 => {
                    return ButtonDisplay{ .text = "A", .device = .gamepad };
                },
                .pieceSelect2 => {
                    return ButtonDisplay{ .text = "B", .device = .gamepad };
                },
                .pieceSelect3 => {
                    return ButtonDisplay{ .text = "X", .device = .gamepad };
                },
                else => {
                    return null;
                },
            }
        },
    }
}

fn getDisplayTextForScancode(scancode: c_uint, state: *main.GameState) []const u8 {
    const cString = sdl.SDL_GetScancodeName(scancode);
    const zigString: []const u8 = std.mem.span(cString);
    if (zigString.len > 1) {
        if (std.mem.startsWith(u8, zigString, "Keypad")) {
            state.tempStringBuffer[0] = 'K';
            state.tempStringBuffer[1] = zigString[zigString.len - 1];
            return state.tempStringBuffer[0..2];
        } else {
            std.debug.print("displayKeyToScancode: {s}\n", .{zigString});
        }
        return "0";
    } else {
        return zigString;
    }
}

fn handleCheckPlayerJoin(event: sdl.SDL_Event, state: *main.GameState) !void {
    if (event.type == sdl.SDL_EVENT_KEY_DOWN) {
        const mappingIndex = getKeyboardMappingIndex(event);
        if (mappingIndex == null) return;
        for (state.players.items) |*player| {
            if (player.inputData.inputDevice != null and player.inputData.inputDevice.? == .keyboard and player.inputData.inputDevice.?.keyboard == mappingIndex) return;
        }
        for (state.inputJoinData.inputDeviceDatas.items) |joinData| {
            if (joinData.deviceData == .keyboard and joinData.deviceData.keyboard == mappingIndex) return;
        }
        try state.inputJoinData.inputDeviceDatas.append(.{ .pressTime = std.time.milliTimestamp(), .deviceData = .{ .keyboard = mappingIndex } });
    }
    if (event.type == sdl.SDL_EVENT_KEY_UP) {
        const mappingIndex = getKeyboardMappingIndex(event);
        if (mappingIndex == null) return;
        for (state.inputJoinData.inputDeviceDatas.items, 0..) |joinData, index| {
            if (joinData.deviceData == .keyboard and joinData.deviceData.keyboard == mappingIndex) {
                _ = state.inputJoinData.inputDeviceDatas.swapRemove(index);
                return;
            }
        }
    }

    if (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN) {
        for (state.players.items) |*player| {
            if (player.inputData.inputDevice != null and player.inputData.inputDevice.? == .gamepad and player.inputData.inputDevice.?.gamepad == event.gdevice.which) {
                return;
            }
        }
        for (state.inputJoinData.inputDeviceDatas.items) |joinData| {
            if (joinData.deviceData == .gamepad and joinData.deviceData.gamepad == event.gdevice.which) return;
        }
        try state.inputJoinData.inputDeviceDatas.append(.{ .pressTime = std.time.milliTimestamp(), .deviceData = .{ .gamepad = event.gdevice.which } });
    }
    if (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_UP) {
        for (state.inputJoinData.inputDeviceDatas.items, 0..) |joinData, index| {
            if (joinData.deviceData == .gamepad and joinData.deviceData.gamepad == event.gdevice.which) {
                _ = state.inputJoinData.inputDeviceDatas.swapRemove(index);
                return;
            }
        }
    }
}

fn getKeyboardMappingIndex(event: sdl.SDL_Event) ?u32 {
    for (KEYBOARD_MAPPINGS, 0..) |keyMappings, index| {
        for (keyMappings) |mapping| {
            if (mapping.sdlKeyCode == event.key.scancode) return @intCast(index);
        }
    }
    return null;
}

fn handlePlayerKeyboardInput(event: sdl.SDL_Event, player: *main.Player, keyboardMappingIndex: ?u32, state: *main.GameState) !void {
    if (event.type != sdl.SDL_EVENT_KEY_DOWN) return;
    if (keyboardMappingIndex) |index| {
        const keyMapping = KEYBOARD_MAPPINGS[index];
        for (keyMapping) |mapping| {
            if (mapping.sdlKeyCode == event.key.scancode) {
                try handlePlayerAction(mapping.action, player, state);
            }
        }
    } else {
        for (KEYBOARD_MAPPINGS, 0..) |keyMappings, index| {
            for (keyMappings) |mapping| {
                if (mapping.sdlKeyCode == event.key.scancode) {
                    player.inputData.lastInputDevice = .{ .keyboard = @intCast(index) };
                    try handlePlayerAction(mapping.action, player, state);
                }
            }
        }
    }
}

fn handlePlayerGamepadInput(event: sdl.SDL_Event, player: *main.Player, gamepadId: ?u32, state: *main.GameState) !void {
    if (gamepadId != null and event.gdevice.which != gamepadId) return;
    const deadzone = 15000;
    switch (event.type) {
        sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION => {
            if (gamepadId == null) player.inputData.lastInputDevice = .{ .gamepad = event.gdevice.which };
            const deadZone = player.inputData.axis0DeadZone and player.inputData.axis1DeadZone;
            if (@mod(event.gaxis.axis, 2) == 1) {
                if (event.gaxis.value > deadzone) {
                    if (deadZone) {
                        try handlePlayerAction(.moveDown, player, state);
                    }
                    player.inputData.axis1Id = event.gaxis.axis;
                    player.inputData.axis1DeadZone = false;
                } else if (event.gaxis.value < -deadzone) {
                    if (deadZone) {
                        try handlePlayerAction(.moveUp, player, state);
                    }
                    player.inputData.axis1Id = event.gaxis.axis;
                    player.inputData.axis1DeadZone = false;
                } else if (player.inputData.axis1Id == event.gaxis.axis) {
                    player.inputData.axis1DeadZone = true;
                }
            } else {
                if (event.gaxis.value > deadzone) {
                    if (deadZone) {
                        try handlePlayerAction(.moveRight, player, state);
                    }
                    player.inputData.axis0Id = event.gaxis.axis;
                    player.inputData.axis0DeadZone = false;
                } else if (event.gaxis.value < -deadzone) {
                    if (deadZone) {
                        try handlePlayerAction(.moveLeft, player, state);
                    }
                    player.inputData.axis0Id = event.gaxis.axis;
                    player.inputData.axis0DeadZone = false;
                } else if (player.inputData.axis0Id == event.gaxis.axis) {
                    player.inputData.axis0DeadZone = true;
                }
            }
        },
        sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN => {
            if (gamepadId == null) player.inputData.lastInputDevice = .{ .gamepad = event.gdevice.which };
            if (event.gbutton.button == 0) try handlePlayerAction(.pieceSelect1, player, state);
            if (event.gbutton.button == 1) try handlePlayerAction(.pieceSelect2, player, state);
            if (event.gbutton.button == 2) try handlePlayerAction(.pieceSelect3, player, state);
        },
        else => {},
    }
}

fn handlePlayerAction(action: PlayerAction, player: *main.Player, state: *main.GameState) !void {
    switch (action) {
        .moveLeft => {
            if (player.choosenMoveOptionIndex) |index| {
                try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_LEFT, state);
            } else if (state.gamePhase == .shopping) {
                player.position.x -= main.TILESIZE;
                try shopZig.executeShopActionForPlayer(player, state);
            }
        },
        .moveRight => {
            if (player.choosenMoveOptionIndex) |index| {
                try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_RIGHT, state);
            } else if (state.gamePhase == .shopping) {
                player.position.x += main.TILESIZE;
                try shopZig.executeShopActionForPlayer(player, state);
            }
        },
        .moveUp => {
            if (player.choosenMoveOptionIndex) |index| {
                try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_UP, state);
            } else if (state.gamePhase == .shopping) {
                player.position.y -= main.TILESIZE;
                try shopZig.executeShopActionForPlayer(player, state);
            }
        },
        .moveDown => {
            if (player.choosenMoveOptionIndex) |index| {
                try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_DOWN, state);
            } else if (state.gamePhase == .shopping) {
                player.position.y += main.TILESIZE;
                try shopZig.executeShopActionForPlayer(player, state);
            }
        },
        .pieceSelect1 => {
            movePieceZig.setMoveOptionIndex(player, 0, state);
            if (state.gameOver and state.level > 1) {
                try main.executeContinue(state);
            }
        },
        .pieceSelect2 => {
            movePieceZig.setMoveOptionIndex(player, 1, state);
        },
        .pieceSelect3 => {
            movePieceZig.setMoveOptionIndex(player, 2, state);
        },
    }
}
