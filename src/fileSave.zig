const std = @import("std");

pub fn getSavePath(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const directory_path = try getSaveDirectoryPath(allocator);
    defer allocator.free(directory_path);
    try std.fs.cwd().makePath(directory_path);

    const full_path = try std.fs.path.join(allocator, &.{ directory_path, filename });
    return full_path;
}

pub fn getSaveDirectoryPath(allocator: std.mem.Allocator) ![]const u8 {
    const game_name = "SpeedNinja";
    const save_folder = "saves";

    const base_dir = try std.fs.getAppDataDir(allocator, game_name);
    defer allocator.free(base_dir);

    const directory_path = try std.fs.path.join(allocator, &.{ base_dir, save_folder });
    return directory_path;
}
