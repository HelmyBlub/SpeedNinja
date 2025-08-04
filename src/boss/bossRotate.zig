const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");

pub const BossRotateData = struct {
    nextStateTime: i64 = 0,
    immune: bool = true,
};

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .name = "Rotate",
        .appearsOnLevel = 10,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
    };
}

fn startBoss(state: *main.GameState) !void {
    try state.bosses.append(.{
        .hp = 20,
        .maxHp = 20,
        .imageIndex = imageZig.IMAGE_EVIL_TOWER,
        .position = .{ .x = 0, .y = 0 },
        .name = bossZig.LEVEL_BOSS_DATA[1].name,
        .dataIndex = 1,
        .typeData = .{ .rotate = .{} },
    });
    state.mapTileRadius = 6;
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = state;
    _ = passedTime;
    _ = boss;
}

fn isBossHit(boss: *bossZig.Boss, hitArea: main.TileRectangle, state: *main.GameState) bool {
    _ = state;
    _ = hitArea;
    _ = boss;
    return false;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) void {
    _ = boss;
    _ = state;
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const bossPosition = boss.position;
    if (bossPosition.y != boss.position.y) {
        paintVulkanZig.verticesForComplexSpriteScale(.{
            .x = boss.position.x,
            .y = boss.position.y + 5,
        }, imageZig.IMAGE_SHADOW, &state.vkState.verticeData.spritesComplex, 0.75, state);
    }
    paintVulkanZig.verticesForComplexSpriteDefault(bossPosition, boss.imageIndex, &state.vkState.verticeData.spritesComplex, state);
}
