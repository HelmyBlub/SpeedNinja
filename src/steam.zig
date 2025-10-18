const std = @import("std");
const main = @import("main.zig");
const achievementZig = @import("achievement.zig");

const ISteamUserStats = opaque {};
pub extern fn SteamAPI_InitFlat(err: ?*[1024]u8) callconv(.C) u32;
pub extern fn SteamAPI_Shutdown() callconv(.C) void;
pub extern fn SteamAPI_SteamUserStats_v013() callconv(.C) ?*ISteamUserStats;
pub extern fn SteamAPI_ISteamUserStats_StoreStats(ptr: ?*ISteamUserStats) callconv(.C) bool;
pub extern fn SteamAPI_ISteamUserStats_ClearAchievement(ptr: ?*ISteamUserStats, pchName: [*c]const u8) callconv(.C) bool;
pub extern fn SteamAPI_ISteamUserStats_SetAchievement(ptr: ?*ISteamUserStats, pchName: [*c]const u8) callconv(.C) bool;
pub extern fn SteamAPI_ISteamUserStats_GetAchievement(ptr: ?*ISteamUserStats, pchName: [*c]const u8, pbAchieved: *bool) callconv(.C) bool;

const ENABLED: bool = true;
pub const SteamData = struct {
    earliestNextStoreStats: i64,
    achievementToStore: bool = false,
    preventStoreStats: bool = false,
};
const MIN_STORE_INTERVAL = 60;

pub fn setAchievement(achievementEnum: achievementZig.AchievementsEnum, state: *main.GameState) void {
    if (state.steam) |*steam| {
        const achievement = state.achievements.getPtr(achievementEnum);
        if (achievement.achieved) {
            var achieved: bool = false;
            const success = SteamAPI_ISteamUserStats_GetAchievement(SteamAPI_SteamUserStats_v013(), @ptrCast(achievement.steamName), &achieved);
            if (!achieved and success) {
                _ = SteamAPI_ISteamUserStats_SetAchievement(SteamAPI_SteamUserStats_v013(), @ptrCast(achievement.steamName));
                steam.achievementToStore = true;
                if (!steam.preventStoreStats) {
                    storeAchievements(state);
                }
            }
        }
    }
}

pub fn storeAchievements(state: *main.GameState) void {
    if (state.steam) |*steam| {
        if (!steam.achievementToStore or steam.preventStoreStats) return;
        const timestamp = std.time.timestamp();
        if (steam.earliestNextStoreStats < timestamp) {
            _ = SteamAPI_ISteamUserStats_StoreStats(SteamAPI_SteamUserStats_v013());
            steam.earliestNextStoreStats = timestamp + MIN_STORE_INTERVAL;
            steam.achievementToStore = false;
        }
    }
}

pub fn steamInit(state: *main.GameState) void {
    if (!ENABLED) {
        std.debug.print("!!!!   steam disabled    !!!!!\n", .{});
        return;
    }
    if (SteamAPI_InitFlat(null) == 0) {
        state.steam = .{ .earliestNextStoreStats = std.time.timestamp() };
        std.debug.print("steam connected\n", .{});
    } else {
        std.debug.print("steam init failed\n", .{});
    }
}
