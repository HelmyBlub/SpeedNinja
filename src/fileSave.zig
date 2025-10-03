const std = @import("std");
const main = @import("main.zig");
const shopZig = @import("shop.zig");
const playerZig = @import("player.zig");
const inputZig = @import("input.zig");
const equipmentZig = @import("equipment.zig");
const movePieceZig = @import("movePiece.zig");

const SAFE_FILE_VERSION_SAVE_RUN: u8 = 0;
const FILE_NAME_SAVE_RUN = "currenRun.dat";

pub fn getSavePath(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const directory_path = try getSaveDirectoryPath(allocator);
    defer allocator.free(directory_path);
    try std.fs.cwd().makePath(directory_path);

    const full_path = try std.fs.path.join(allocator, &.{ directory_path, filename });
    return full_path;
}

pub fn getSaveDirectoryPath(allocator: std.mem.Allocator) ![]const u8 {
    const game_name = "SpeedTacticNinja";
    const save_folder = "saves";

    const base_dir = try std.fs.getAppDataDir(allocator, game_name);
    defer allocator.free(base_dir);

    const directory_path = try std.fs.path.join(allocator, &.{ base_dir, save_folder });
    return directory_path;
}

pub fn deleteFile(filename: []const u8, allocator: std.mem.Allocator) !void {
    const filepath = try getSavePath(allocator, filename);
    defer allocator.free(filepath);
    try std.fs.deleteFileAbsolute(filepath);
}

pub fn loadCurrentRunFromFile(state: *main.GameState) !void {
    const filepath = try getSavePath(state.allocator, FILE_NAME_SAVE_RUN);
    defer state.allocator.free(filepath);

    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    const reader = file.reader();
    const safeFileVersion = try reader.readByte();
    if (safeFileVersion != SAFE_FILE_VERSION_SAVE_RUN) {
        // std.debug.print("not loading outdated save file version");
    }

    const timestamp = std.time.milliTimestamp();
    {
        const level = try reader.readInt(u32, .little);
        const newGamePlus = try reader.readInt(u32, .little);
        const timePlayed = try reader.readInt(i64, .little);
        const continueDataBossesAced = try reader.readInt(u32, .little);
        const continueDataFreeContinues = try reader.readInt(u32, .little);
        const continueDataPaidContinues = try reader.readInt(u32, .little);
        const continueDataNextBossAceFreeContinue = try reader.readInt(u32, .little);
        const continueDataNextBossAceFreeContinueIncrease = try reader.readInt(u32, .little);
        try main.restart(state, newGamePlus);
        state.statistics.active = false;
        state.statistics.runStartedTime = timestamp - timePlayed;
        state.level = level - 1;
        state.continueData.bossesAced = continueDataBossesAced;
        state.continueData.freeContinues = continueDataFreeContinues;
        state.continueData.paidContinues = continueDataPaidContinues;
        state.continueData.nextBossAceFreeContinue = continueDataNextBossAceFreeContinue;
        state.continueData.nextBossAceFreeContinueIncrease = continueDataNextBossAceFreeContinueIncrease;
    }
    const playerCount = try reader.readInt(usize, .little);
    for (0..playerCount) |index| {
        const inputDeviceData = try readInputDeviceData(reader, state);
        if (state.players.items.len <= index) {
            try playerZig.playerJoin(.{ .inputDevice = inputDeviceData }, state);
        } else {
            state.players.items[index].inputData.inputDevice = inputDeviceData;
        }
        const player: *playerZig.Player = &state.players.items[index];
        player.money = try reader.readInt(u32, .little);
        try readPlayerMovePieces(player, reader, state);
    }
    try shopZig.startShoppingPhase(state);
    try readShopBuyOptions(reader, state);
}

pub fn saveCurrentRunToFile(state: *main.GameState) !void {
    if (state.gameOver or state.gamePhase == .finished or state.level <= 2) {
        deleteFile(FILE_NAME_SAVE_RUN, state.allocator) catch {};
        return;
    }
    const filepath = try getSavePath(state.allocator, FILE_NAME_SAVE_RUN);
    defer state.allocator.free(filepath);

    const file = try std.fs.cwd().createFile(filepath, .{ .truncate = true });
    defer file.close();

    const timestamp = std.time.milliTimestamp();
    const writer = file.writer();
    _ = try writer.writeByte(SAFE_FILE_VERSION_SAVE_RUN);
    const saveLevel = if (state.gamePhase == .shopping) state.level + 1 else state.level;
    _ = try writer.writeInt(u32, saveLevel, .little);
    _ = try writer.writeInt(u32, state.newGamePlus, .little);
    const timePlayed: i64 = timestamp - state.statistics.runStartedTime;
    _ = try writer.writeInt(i64, timePlayed, .little);
    _ = try writer.writeInt(u32, state.continueData.bossesAced, .little);
    _ = try writer.writeInt(u32, state.continueData.freeContinues, .little);
    _ = try writer.writeInt(u32, state.continueData.paidContinues, .little);
    _ = try writer.writeInt(u32, state.continueData.nextBossAceFreeContinue, .little);
    _ = try writer.writeInt(u32, state.continueData.nextBossAceFreeContinueIncrease, .little);

    _ = try writer.writeInt(usize, state.players.items.len, .little);
    for (state.players.items) |*player| {
        try writeInputDeviceData(player, writer);
        _ = try writer.writeInt(u32, player.money, .little);
        try writePlayerMovePieces(player, writer);
        //equipment
    }
    try writeShopBuyOptions(writer, state);
}

fn writePlayerMovePieces(player: *playerZig.Player, writer: anytype) !void {
    _ = try writer.writeInt(usize, player.totalMovePieces.items.len, .little);
    for (player.totalMovePieces.items) |movePiece| {
        _ = try writer.writeInt(usize, movePiece.steps.len, .little);
        for (movePiece.steps) |step| {
            _ = try writer.writeInt(u8, step.direction, .little);
            _ = try writer.writeInt(u8, step.stepCount, .little);
        }
    }
}

fn readPlayerMovePieces(player: *playerZig.Player, reader: anytype, state: *main.GameState) !void {
    for (player.totalMovePieces.items) |movePiece| {
        state.allocator.free(movePiece.steps);
    }
    player.totalMovePieces.clearRetainingCapacity();
    player.availableMovePieces.clearRetainingCapacity();
    player.moveOptions.clearRetainingCapacity();
    const movePieceCount = try reader.readInt(usize, .little);
    for (0..movePieceCount) |_| {
        const stepsCount = try reader.readInt(usize, .little);
        const steps: []movePieceZig.MoveStep = try state.allocator.alloc(movePieceZig.MoveStep, stepsCount);
        const movePiece: movePieceZig.MovePiece = .{ .steps = steps };
        for (steps) |*step| {
            step.direction = try reader.readInt(u8, .little);
            step.stepCount = try reader.readInt(u8, .little);
        }
        try player.totalMovePieces.append(movePiece);
    }
}

fn writeShopBuyOptions(writer: anytype, state: *main.GameState) !void {
    _ = try writer.writeInt(usize, state.shop.buyOptions.items.len, .little);
    for (state.shop.buyOptions.items) |buyOption| {
        var matchingEquipIndex: u8 = 0;
        for (equipmentZig.EQUIPMENT_SHOP_OPTIONS, 0..) |equipmentShopOption, equipIndex| {
            if (equipmentShopOption.shopDisplayImage == buyOption.imageIndex) {
                matchingEquipIndex = @intCast(equipIndex);
                break;
            }
        }
        _ = try writer.writeInt(u8, matchingEquipIndex, .little);
    }
}

fn readShopBuyOptions(reader: anytype, state: *main.GameState) !void {
    const buyOptionCount = try reader.readInt(usize, .little);
    for (0..buyOptionCount) |index| {
        const equipIndex = try reader.readInt(u8, .little);
        if (index < state.shop.buyOptions.items.len) {
            const randomEquip = equipmentZig.getEquipmentOptionByIndexScaledToLevel(equipIndex, state.level);
            const pos = state.shop.buyOptions.items[index].tilePosition;
            state.shop.buyOptions.items[index] = .{
                .price = state.level * randomEquip.basePrice,
                .tilePosition = pos,
                .imageIndex = randomEquip.shopDisplayImage,
                .imageScale = randomEquip.imageScale,
                .equipment = randomEquip.equipment,
            };
        }
    }
}

fn writeInputDeviceData(player: *playerZig.Player, writer: anytype) !void {
    const inputDeviceInt: u8 = if (player.inputData.inputDevice) |device| @as(u8, @intFromEnum(device)) + 1 else 0;
    _ = try writer.writeInt(u8, inputDeviceInt, .little);
    if (inputDeviceInt > 0) {
        switch (player.inputData.inputDevice.?) {
            .gamepad => |id| {
                _ = try writer.writeInt(u32, id, .little);
            },
            .keyboard => |optId| {
                if (optId) |id| {
                    _ = try writer.writeInt(u32, id + 1, .little);
                } else {
                    _ = try writer.writeInt(u32, 0, .little);
                }
            },
        }
    }
}

fn readInputDeviceData(reader: anytype, state: *main.GameState) !?inputZig.InputDeviceData {
    const inputDeviceInt = try reader.readInt(u8, .little);
    var inputDeviceData: ?inputZig.InputDeviceData = null;
    if (inputDeviceInt > 0) {
        const inputDevice: inputZig.InputDevice = try std.meta.intToEnum(inputZig.InputDevice, inputDeviceInt - 1);
        switch (inputDevice) {
            .gamepad => {
                const gamepadId = try reader.readInt(u32, .little);
                inputDeviceData = .{ .gamepad = gamepadId };
                try state.inputJoinData.disconnectedGamepads.append(gamepadId);
            },
            .keyboard => {
                const keyboardMappingId = try reader.readInt(u32, .little);
                if (keyboardMappingId == 0) {
                    inputDeviceData = .{ .keyboard = null };
                } else {
                    if (keyboardMappingId <= inputZig.KEYBOARD_MAPPINGS.len) {
                        inputDeviceData = .{ .keyboard = keyboardMappingId - 1 };
                    }
                }
            },
        }
    }

    return inputDeviceData;
}
