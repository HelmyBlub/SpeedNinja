const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const mapTileZig = @import("../mapTile.zig");

const DragonState = enum {
    standing,
    ground,
};

pub const BossDragonData = struct {
    state: DragonState = .ground,
    nextStateTime: ?i64 = null,
    feet: [4]main.Position = [4]main.Position{
        .{ .x = -1 * main.TILESIZE, .y = -1 * main.TILESIZE },
        .{ .x = 1 * main.TILESIZE, .y = -1 * main.TILESIZE },
        .{ .x = -1 * main.TILESIZE, .y = 1 * main.TILESIZE },
        .{ .x = 1 * main.TILESIZE, .y = 1 * main.TILESIZE },
    },
    paint: struct {
        standingPerCent: f32 = 0,
    } = .{},
};

const BOSS_NAME = "Dragon";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 50,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
    };
}

fn startBoss(state: *main.GameState) !void {
    try state.bosses.append(.{
        .hp = 50,
        .maxHp = 50,
        .imageIndex = imageZig.IMAGE_EVIL_TOWER,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .typeData = .{ .dragon = .{} },
    });
    try mapTileZig.setMapRadius(6, state);
    state.paintData.backgroundColor = main.COLOR_SKY_BLUE;
    for (state.paintData.backClouds[0..]) |*backCloud| {
        backCloud.position.x = -500 + std.crypto.random.float(f32) * 1000;
        backCloud.position.y = -150 + std.crypto.random.float(f32) * 150;
        backCloud.sizeFactor = 5;
        backCloud.speed = 0.02;
    }
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    const changeTime = 2000;
    if (data.nextStateTime == null or data.nextStateTime.? <= state.gameTime) {
        if (data.state == .ground) data.state = .standing else data.state = .ground;
        data.nextStateTime = state.gameTime + changeTime;
    }
    if (data.state == .ground) {
        if (data.paint.standingPerCent > 0) {
            data.paint.standingPerCent = @max(0, data.paint.standingPerCent - @as(f32, @floatFromInt(passedTime)) / changeTime);
        }
    }
    if (data.state == .standing) {
        if (data.paint.standingPerCent < 1) {
            data.paint.standingPerCent = @min(data.paint.standingPerCent + @as(f32, @floatFromInt(passedTime)) / changeTime, 1);
        }
    }
}

fn isBossHit(boss: *bossZig.Boss, player: *main.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    _ = state;
    _ = cutRotation;
    _ = hitDirection;
    _ = player;
    const data = &boss.typeData.dragon;
    for (data.feet) |foot| {
        const footTile = main.gamePositionToTilePosition(foot);
        if (main.isTilePositionInTileRectangle(footTile, hitArea)) {
            boss.hp -|= 1;
            return true;
        }
    }
    return false;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) !void {
    const data = boss.typeData.dragon;
    _ = data;
    _ = state;
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;

    for (0..2) |index| {
        const foot = data.feet[index];
        paintVulkanZig.verticesForComplexSpriteDefault(foot, imageZig.IMAGE_BOSS_DRAGON_FOOT, state);
    }
    if (data.paint.standingPerCent < 0.5) {
        for (2..4) |index| {
            const foot = data.feet[index];
            const footInAirPos: main.Position = .{
                .x = foot.x,
                .y = foot.y - 100 * data.paint.standingPerCent,
            };
            paintVulkanZig.verticesForComplexSpriteDefault(footInAirPos, imageZig.IMAGE_BOSS_DRAGON_FOOT, state);
        }
    }
    const tailPosition: main.Position = .{
        .x = boss.position.x,
        .y = boss.position.y - 70,
    };
    paintVulkanZig.verticesForComplexSpriteDefault(tailPosition, imageZig.IMAGE_BOSS_DRAGON_TAIL, state);
    if (data.paint.standingPerCent > 0.5) paintDragonWings(boss, state);
    paintDragonBody(boss, state);
    if (data.paint.standingPerCent <= 0.5) paintDragonWings(boss, state);

    if (data.paint.standingPerCent >= 0.5) {
        for (2..4) |index| {
            const foot = data.feet[index];
            const footInAirPos: main.Position = .{
                .x = foot.x,
                .y = foot.y - 100 * data.paint.standingPerCent,
            };
            paintVulkanZig.verticesForComplexSpriteDefault(footInAirPos, imageZig.IMAGE_BOSS_DRAGON_FOOT, state);
        }
    }
    const headPosition: main.Position = .{
        .x = boss.position.x,
        .y = boss.position.y + 45 - 160 * data.paint.standingPerCent,
    };
    paintVulkanZig.verticesForComplexSpriteDefault(headPosition, imageZig.IMAGE_BOSS_DRAGON_HEAD, state);
}

fn paintDragonWings(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    const wingLeftPosition: main.Position = .{
        .x = boss.position.x - 50,
        .y = boss.position.y + 10 - 90 * data.paint.standingPerCent,
    };
    const wingRightPosition: main.Position = .{
        .x = boss.position.x + 50,
        .y = boss.position.y + 10 - 90 * data.paint.standingPerCent,
    };
    const scaleY = 0.1 + @abs(data.paint.standingPerCent - 0.5) * 2 * 0.9;
    if (data.paint.standingPerCent > 0.5) {
        paintVulkanZig.verticesForComplexSprite(wingLeftPosition, imageZig.IMAGE_BOSS_DRAGON_WING, 1, scaleY, 1, false, false, state);
        paintVulkanZig.verticesForComplexSprite(wingRightPosition, imageZig.IMAGE_BOSS_DRAGON_WING, 1, scaleY, 1, true, false, state);
    } else {
        paintVulkanZig.verticesForComplexSprite(wingLeftPosition, imageZig.IMAGE_BOSS_DRAGON_WING, 1, scaleY, 1, false, true, state);
        paintVulkanZig.verticesForComplexSprite(wingRightPosition, imageZig.IMAGE_BOSS_DRAGON_WING, 1, scaleY, 1, true, true, state);
    }
}

fn paintDragonBody(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    const bodyPosition: main.Position = .{
        .x = boss.position.x,
        .y = boss.position.y - 60 * data.paint.standingPerCent,
    };
    const scaleY = 0.5 + @abs(data.paint.standingPerCent - 0.5);
    paintVulkanZig.verticesForComplexSpriteWithCut(
        bodyPosition,
        imageZig.IMAGE_BOSS_DRAGON_BODY_BOTTOM,
        1 - data.paint.standingPerCent,
        1,
        1,
        1,
        scaleY,
        state,
    );
    paintVulkanZig.verticesForComplexSpriteWithCut(
        bodyPosition,
        imageZig.IMAGE_BOSS_DRAGON_BODY_TOP,
        0,
        1 - data.paint.standingPerCent,
        1,
        1,
        scaleY,
        state,
    );
}
