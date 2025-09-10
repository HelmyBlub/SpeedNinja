const std = @import("std");
const main = @import("../main.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");
const bossZig = @import("../boss/boss.zig");

pub fn setupVertices(state: *main.GameState) !void {
    const fontSize = 30;
    var textWidthRound: f32 = -0.2;
    const verticeData = &state.vkState.verticeData;
    const fontVertices = &verticeData.font;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const textColor: [3]f32 = .{ 1, 1, 1 };

    if (state.gamePhase == .boss) {
        if (state.bosses.items.len == 0) return;
        const spacingX = onePixelXInVulkan * 5;
        const top = -0.99;
        const height = onePixelYInVulkan * fontSize;
        const length = @as(f32, @floatFromInt(state.bosses.items.len));
        const width: f32 = @min(1, 1.8 / length);
        var currentLeft = -((width * length + spacingX * (length - 1)) / 2);
        for (state.bosses.items) |*boss| {
            try setupVerticesBossHpBar(boss, top, currentLeft, height, width, state);
            currentLeft += width + spacingX;
        }
    } else {
        textWidthRound -= 0.2;
        if (state.gamePhase == .combat) {
            textWidthRound += fontVulkanZig.paintText("Round: ", .{ .x = textWidthRound, .y = -0.99 }, fontSize, textColor, fontVertices);
            textWidthRound += try fontVulkanZig.paintNumber(state.round, .{ .x = textWidthRound, .y = -0.99 }, fontSize, textColor, fontVertices);
        }
        textWidthRound += fontVulkanZig.paintText(" Level: ", .{ .x = textWidthRound, .y = -0.99 }, fontSize, textColor, fontVertices);
        textWidthRound += try fontVulkanZig.paintNumber(state.level, .{ .x = textWidthRound, .y = -0.99 }, fontSize, textColor, fontVertices);
        textWidthRound += fontVulkanZig.paintText(" Money: $", .{ .x = textWidthRound, .y = -0.99 }, fontSize, textColor, fontVertices);
        textWidthRound += try fontVulkanZig.paintNumber(state.players.items[0].money, .{ .x = textWidthRound, .y = -0.99 }, fontSize, textColor, fontVertices);
        textWidthRound += fontVulkanZig.paintText(" Play Time: ", .{ .x = textWidthRound, .y = -0.99 }, fontSize, textColor, fontVertices);
        var zeroPrefix = false;
        if (state.gameTime >= 60 * 1000) {
            const minutes = @divFloor(state.gameTime, 1000 * 60);
            textWidthRound += try fontVulkanZig.paintNumber(minutes, .{ .x = textWidthRound, .y = -0.99 }, fontSize, textColor, fontVertices);
            textWidthRound += fontVulkanZig.paintText(":", .{ .x = textWidthRound, .y = -0.99 }, fontSize, textColor, fontVertices);
            zeroPrefix = true;
        }
        _ = try fontVulkanZig.paintNumberWithZeroPrefix(@mod(@divFloor(state.gameTime, 1000), 60), .{ .x = textWidthRound, .y = -0.99 }, fontSize, textColor, fontVertices, zeroPrefix);

        if (state.round > 1) {
            if (state.gamePhase == .combat) {
                const textWidthTime = fontVulkanZig.paintText("Time: ", .{ .x = 0, .y = -0.9 }, fontSize, textColor, fontVertices);
                const remainingTime: i64 = @max(0, @divFloor(state.roundEndTimeMS - state.gameTime, 1000));
                _ = try fontVulkanZig.paintNumber(remainingTime, .{ .x = textWidthTime, .y = -0.9 }, fontSize, textColor, fontVertices);
            }
        }
    }
    if (state.gameOver) {
        _ = fontVulkanZig.paintText("GAME OVER", .{ .x = -0.4, .y = -0.1 }, 120, textColor, fontVertices);
    }
}

fn setupVerticesBossHpBar(boss: *bossZig.Boss, top: f32, left: f32, height: f32, width: f32, state: *main.GameState) !void {
    const textColor: [3]f32 = .{ 1, 1, 1 };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const fontSize = height / onePixelYInVulkan;
    const verticeData = &state.vkState.verticeData;
    const fontVertices = &verticeData.font;
    var textWidthRound = left;
    textWidthRound += fontVulkanZig.paintText(boss.name, .{ .x = textWidthRound, .y = top }, fontSize, textColor, fontVertices) + onePixelXInVulkan * 20;
    textWidthRound += try fontVulkanZig.paintNumber(boss.hp, .{ .x = textWidthRound, .y = top }, fontSize, textColor, fontVertices);
    textWidthRound += fontVulkanZig.paintText("/", .{ .x = textWidthRound, .y = top }, fontSize, textColor, fontVertices);
    textWidthRound += try fontVulkanZig.paintNumber(boss.maxHp, .{ .x = textWidthRound, .y = top }, fontSize, textColor, fontVertices);

    const fillPerCent = @as(f32, @floatFromInt(boss.hp)) / @as(f32, @floatFromInt(boss.maxHp));
    paintVulkanZig.verticesForRectangle(left, top, width * fillPerCent, height, .{ 1, 0, 0 }, null, &verticeData.triangles);
    paintVulkanZig.verticesForRectangle(left, top, width, height, .{ 1, 0, 0 }, &verticeData.lines, null);
}
