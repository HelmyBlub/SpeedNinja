const std = @import("std");
const main = @import("main.zig");
const shopZig = @import("shop.zig");
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

    const level = try reader.readInt(u32, .little);
    const newGamePlus = try reader.readInt(u32, .little);
    const timePlayed = try reader.readInt(i64, .little);
    const continueDataBossesAced = try reader.readInt(u32, .little);
    const continueDataFreeContinues = try reader.readInt(u32, .little);
    const continueDataPaidContinues = try reader.readInt(u32, .little);
    const continueDataNextBossAceFreeContinue = try reader.readInt(u32, .little);
    const continueDataNextBossAceFreeContinueIncrease = try reader.readInt(u32, .little);

    const timestamp = std.time.milliTimestamp();
    try main.restart(state, newGamePlus);
    state.statistics.active = false;
    state.statistics.runStartedTime = timestamp - timePlayed;
    state.level = level - 1;
    state.continueData.bossesAced = continueDataBossesAced;
    state.continueData.freeContinues = continueDataFreeContinues;
    state.continueData.paidContinues = continueDataPaidContinues;
    state.continueData.nextBossAceFreeContinue = continueDataNextBossAceFreeContinue;
    state.continueData.nextBossAceFreeContinueIncrease = continueDataNextBossAceFreeContinueIncrease;
    try shopZig.startShoppingPhase(state);
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
        _ = try writer.writeInt(u32, player.money, .little);
    }
}
