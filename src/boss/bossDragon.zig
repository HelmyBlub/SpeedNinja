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
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &boss.typeData.dragon;
    if (data.nextStateTime == null or data.nextStateTime.? <= state.gameTime) {
        if (data.state == .ground) data.state = .standing else data.state = .ground;
        data.nextStateTime = state.gameTime + 2_000;
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

    if (data.state == .standing) {
        for (0..2) |index| {
            const foot = data.feet[index];
            paintVulkanZig.verticesForComplexSpriteDefault(foot, imageZig.IMAGE_BOSS_DRAGON_FOOT, &state.vkState.verticeData.spritesComplex, state);
        }
        const tailPosition: main.Position = .{
            .x = boss.position.x,
            .y = boss.position.y - 70,
        };
        paintVulkanZig.verticesForComplexSpriteDefault(tailPosition, imageZig.IMAGE_BOSS_DRAGON_TAIL, &state.vkState.verticeData.spritesComplex, state);
        const wingLeftPosition: main.Position = .{
            .x = boss.position.x - 50,
            .y = boss.position.y - 80,
        };
        paintVulkanZig.verticesForComplexSprite(wingLeftPosition, imageZig.IMAGE_BOSS_DRAGON_WING, &state.vkState.verticeData.spritesComplex, 1, 1, false, false, state);
        const wingRightPosition: main.Position = .{
            .x = boss.position.x + 50,
            .y = boss.position.y - 80,
        };
        paintVulkanZig.verticesForComplexSprite(wingRightPosition, imageZig.IMAGE_BOSS_DRAGON_WING, &state.vkState.verticeData.spritesComplex, 1, 1, true, false, state);
        const bodyPosition: main.Position = .{
            .x = boss.position.x,
            .y = boss.position.y - 60,
        };
        paintVulkanZig.verticesForComplexSprite(bodyPosition, imageZig.IMAGE_BOSS_DRAGON_BODY_BOTTOM, &state.vkState.verticeData.spritesComplex, 1, 1, false, false, state);
        for (2..4) |index| {
            const foot = data.feet[index];
            const footInAirPos: main.Position = .{
                .x = foot.x,
                .y = foot.y - 100,
            };
            paintVulkanZig.verticesForComplexSpriteDefault(footInAirPos, imageZig.IMAGE_BOSS_DRAGON_FOOT, &state.vkState.verticeData.spritesComplex, state);
        }
        const headPosition: main.Position = .{
            .x = boss.position.x,
            .y = boss.position.y - 115,
        };
        paintVulkanZig.verticesForComplexSpriteDefault(headPosition, imageZig.IMAGE_BOSS_DRAGON_HEAD, &state.vkState.verticeData.spritesComplex, state);
    }
    if (data.state == .ground) {
        for (data.feet) |foot| {
            paintVulkanZig.verticesForComplexSpriteDefault(foot, imageZig.IMAGE_BOSS_DRAGON_FOOT, &state.vkState.verticeData.spritesComplex, state);
        }
        const tailPosition: main.Position = .{
            .x = boss.position.x,
            .y = boss.position.y - 70,
        };
        paintVulkanZig.verticesForComplexSpriteDefault(tailPosition, imageZig.IMAGE_BOSS_DRAGON_TAIL, &state.vkState.verticeData.spritesComplex, state);
        paintVulkanZig.verticesForComplexSprite(boss.position, imageZig.IMAGE_BOSS_DRAGON_BODY_TOP, &state.vkState.verticeData.spritesComplex, 1, 1, false, false, state);
        const wingLeftPosition: main.Position = .{
            .x = boss.position.x - 50,
            .y = boss.position.y + 10,
        };
        paintVulkanZig.verticesForComplexSprite(wingLeftPosition, imageZig.IMAGE_BOSS_DRAGON_WING, &state.vkState.verticeData.spritesComplex, 1, 1, false, true, state);
        const wingRightPosition: main.Position = .{
            .x = boss.position.x + 50,
            .y = boss.position.y + 10,
        };
        paintVulkanZig.verticesForComplexSprite(wingRightPosition, imageZig.IMAGE_BOSS_DRAGON_WING, &state.vkState.verticeData.spritesComplex, 1, 1, true, true, state);
        const headPosition: main.Position = .{
            .x = boss.position.x,
            .y = boss.position.y + 45,
        };
        paintVulkanZig.verticesForComplexSpriteDefault(headPosition, imageZig.IMAGE_BOSS_DRAGON_HEAD, &state.vkState.verticeData.spritesComplex, state);
    }
}
