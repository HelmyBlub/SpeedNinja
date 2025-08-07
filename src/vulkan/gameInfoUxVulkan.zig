const std = @import("std");
const main = @import("../main.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");

pub fn setupVertices(state: *main.GameState) !void {
    const fontSize = 30;
    var textWidthRound: f32 = -0.2;
    const verticeData = &state.vkState.verticeData;
    const fontVertices = &verticeData.font;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;

    if (state.gamePhase == .boss) {
        if (state.bosses.items.len > 0) {
            const boss = state.bosses.items[0];
            textWidthRound += fontVulkanZig.paintText("Level: ", .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
            textWidthRound += try fontVulkanZig.paintNumber(state.level, .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices) + onePixelXInVulkan * 20;
            textWidthRound += fontVulkanZig.paintText(boss.name, .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices) + onePixelXInVulkan * 20;
            textWidthRound += try fontVulkanZig.paintNumber(boss.hp, .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
            textWidthRound += fontVulkanZig.paintText("/", .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
            textWidthRound += try fontVulkanZig.paintNumber(boss.maxHp, .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);

            const left = -0.5;
            const top = -0.99;
            const width = 1;
            const height = onePixelYInVulkan * fontSize;
            const fillPerCent = @as(f32, @floatFromInt(boss.hp)) / @as(f32, @floatFromInt(boss.maxHp));
            paintVulkanZig.verticesForRectangle(left, top, width * fillPerCent, height, .{ 1, 0, 0 }, null, &verticeData.triangles);
            paintVulkanZig.verticesForRectangle(left, top, width, height, .{ 1, 0, 0 }, &verticeData.lines, null);
        }
    } else {
        textWidthRound -= 0.2;
        if (state.gamePhase == .combat) {
            textWidthRound += fontVulkanZig.paintText("Round: ", .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
            textWidthRound += try fontVulkanZig.paintNumber(state.round, .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
        }
        textWidthRound += fontVulkanZig.paintText(" Level: ", .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
        textWidthRound += try fontVulkanZig.paintNumber(state.level, .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
        textWidthRound += fontVulkanZig.paintText(" Money: $", .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
        textWidthRound += try fontVulkanZig.paintNumber(state.players.items[0].money, .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
        textWidthRound += fontVulkanZig.paintText(" Play Time: ", .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
        var zeroPrefix = false;
        if (state.gameTime >= 60 * 1000) {
            const minutes = @divFloor(state.gameTime, 1000 * 60);
            textWidthRound += try fontVulkanZig.paintNumber(minutes, .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
            textWidthRound += fontVulkanZig.paintText(":", .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices);
            zeroPrefix = true;
        }
        _ = try fontVulkanZig.paintNumberWithZeroPrefix(@mod(@divFloor(state.gameTime, 1000), 60), .{ .x = textWidthRound, .y = -0.99 }, fontSize, fontVertices, zeroPrefix);

        if (state.round > 1) {
            if (state.gamePhase == .combat) {
                const textWidthTime = fontVulkanZig.paintText("Time: ", .{ .x = 0, .y = -0.9 }, fontSize, fontVertices);
                const remainingTime: i64 = @max(0, @divFloor(state.roundEndTimeMS - state.gameTime, 1000));
                _ = try fontVulkanZig.paintNumber(remainingTime, .{ .x = textWidthTime, .y = -0.9 }, fontSize, fontVertices);
            }
        }
    }
}
