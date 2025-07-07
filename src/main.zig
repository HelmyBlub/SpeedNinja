const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    // const allocator = gpa.allocator();
    std.debug.print("test message\n", .{});
}
