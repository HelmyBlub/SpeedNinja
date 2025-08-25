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

const DragonPhase = enum {
    flyingOver,
    landing,
    combatPhase1,
};

const DragonMoveData = struct {
    targetPos: main.Position,
    speed: f32,
};

const DrgonPhaseData = union(DragonPhase) {
    flyingOver: DragonMoveData,
    landing: DragonMoveData,
    combatPhase1,
};

pub const BossDragonData = struct {
    phase: DrgonPhaseData,
    state: DragonState = .ground,
    nextStateTime: ?i64 = null,
    feetOffset: [4]main.Position = [4]main.Position{
        .{ .x = -1 * main.TILESIZE, .y = -1 * main.TILESIZE },
        .{ .x = 1 * main.TILESIZE, .y = -1 * main.TILESIZE },
        .{ .x = -1 * main.TILESIZE, .y = 1 * main.TILESIZE },
        .{ .x = 1 * main.TILESIZE, .y = 1 * main.TILESIZE },
    },
    paint: struct {
        standingPerCent: f32 = 0,
        rotation: f32 = 0,
        wingsFlapStarted: ?i64 = null,
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
    var boss: bossZig.Boss = .{
        .hp = 50,
        .maxHp = 50,
        .imageIndex = imageZig.IMAGE_EVIL_TOWER,
        .position = .{ .x = 0, .y = 800 },
        .name = BOSS_NAME,
        .typeData = .{ .dragon = .{ .phase = .{ .flyingOver = .{ .speed = 0.3, .targetPos = .{ .x = 0, .y = -400 } } } } },
    };
    boss.typeData.dragon.paint.rotation = 1;
    boss.typeData.dragon.paint.wingsFlapStarted = state.gameTime;
    try mapTileZig.setMapRadius(6, state);
    state.paintData.backgroundColor = main.COLOR_SKY_BLUE;
    for (state.paintData.backClouds[0..]) |*backCloud| {
        backCloud.position.x = -500 + std.crypto.random.float(f32) * 1000;
        backCloud.position.y = -150 + std.crypto.random.float(f32) * 150;
        backCloud.sizeFactor = 5;
        backCloud.speed = 0.02;
    }
    main.adjustZoom(state);
    try state.bosses.append(boss);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = state;
    const data = &boss.typeData.dragon;
    switch (data.phase) {
        .flyingOver => |phaseData| {
            const rotation = main.calculateDirection(boss.position, phaseData.targetPos);
            data.paint.rotation = rotation - std.math.pi / 2.0;
            const distance: f32 = phaseData.speed * @as(f32, @floatFromInt(passedTime));
            boss.position = main.moveByDirectionAndDistance(boss.position, rotation, distance);
            if (main.calculateDistance(boss.position, phaseData.targetPos) <= phaseData.speed * 16) {
                boss.position = phaseData.targetPos;
                data.paint.standingPerCent = 1;
                data.phase = .{ .landing = .{ .speed = 0.1, .targetPos = .{ .x = 0, .y = 0 } } };
            }
        },
        .landing => |phaseData| {
            const rotation = main.calculateDirection(boss.position, phaseData.targetPos);
            data.paint.rotation = rotation - std.math.pi / 2.0;
            const distance: f32 = phaseData.speed * @as(f32, @floatFromInt(passedTime));
            boss.position = main.moveByDirectionAndDistance(boss.position, rotation, distance);
            if (main.calculateDistance(boss.position, phaseData.targetPos) <= phaseData.speed * 16) {
                boss.position = phaseData.targetPos;
                data.phase = .combatPhase1;
                data.paint.rotation = 0;
            }
        },
        else => {
            // const changeTime = 2000;
            // if (data.nextStateTime == null or data.nextStateTime.? <= state.gameTime) {
            //     if (data.state == .ground) data.state = .standing else data.state = .ground;
            //     data.nextStateTime = state.gameTime + changeTime;
            // }
            // if (data.state == .ground) {
            //     if (data.paint.standingPerCent > 0) {
            //         data.paint.standingPerCent = @max(0, data.paint.standingPerCent - @as(f32, @floatFromInt(passedTime)) / changeTime);
            //     }
            // }
            // if (data.state == .standing) {
            //     if (data.paint.standingPerCent < 1) {
            //         data.paint.standingPerCent = @min(data.paint.standingPerCent + @as(f32, @floatFromInt(passedTime)) / changeTime, 1);
            //     }
            // }
        },
    }
}

fn isBossHit(boss: *bossZig.Boss, player: *main.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    _ = state;
    _ = cutRotation;
    _ = hitDirection;
    _ = player;
    const data = &boss.typeData.dragon;
    for (data.feetOffset) |footOffset| {
        const footPos: main.Position = .{ .x = boss.position.x + footOffset.x, .y = boss.position.y + footOffset.y };
        const footTile = main.gamePositionToTilePosition(footPos);
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
    paintDragonBackFeet(boss, state);
    if (data.paint.standingPerCent < 0.5) {
        paintDragonFrontFeet(boss, state);
    }
    paintDragonTail(boss, state);
    if (data.paint.standingPerCent > 0.5) paintDragonWings(boss, state);
    paintDragonBody(boss, state);
    if (data.paint.standingPerCent <= 0.5) paintDragonWings(boss, state);

    if (data.paint.standingPerCent >= 0.5) {
        paintDragonFrontFeet(boss, state);
    }
    paintDragonHead(boss, state);
}

fn paintDragonHead(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    const headOffset: main.Position = .{
        .x = 0,
        .y = 45 - 160 * data.paint.standingPerCent,
    };
    const rotatedOffset = main.rotateAroundPoint(headOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const headPosition: main.Position = .{
        .x = boss.position.x + rotatedOffset.x,
        .y = boss.position.y + rotatedOffset.y,
    };
    paintVulkanZig.verticesForComplexSpriteWithRotate(headPosition, imageZig.IMAGE_BOSS_DRAGON_HEAD, data.paint.rotation, state);
}

fn paintDragonBackFeet(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    for (0..2) |index| {
        const footOffset = data.feetOffset[index];
        const footPos: main.Position = .{ .x = boss.position.x + footOffset.x, .y = boss.position.y + footOffset.y };
        paintVulkanZig.verticesForComplexSpriteWithRotate(footPos, imageZig.IMAGE_BOSS_DRAGON_FOOT, data.paint.rotation, state);
    }
}

fn paintDragonFrontFeet(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    for (2..4) |index| {
        const foot = data.feetOffset[index];
        const footOffset: main.Position = .{
            .x = 0,
            .y = -100 * data.paint.standingPerCent,
        };
        const rotatedOffset = main.rotateAroundPoint(footOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
        const footInAirPos: main.Position = .{
            .x = boss.position.x + foot.x + rotatedOffset.x,
            .y = boss.position.y + foot.y + rotatedOffset.y,
        };
        paintVulkanZig.verticesForComplexSpriteWithRotate(footInAirPos, imageZig.IMAGE_BOSS_DRAGON_FOOT, data.paint.rotation, state);
    }
}

fn paintDragonTail(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    const tailOffset: main.Position = .{
        .x = 0,
        .y = -70,
    };
    const rotatedOffset = main.rotateAroundPoint(tailOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const tailPosition: main.Position = .{
        .x = boss.position.x + rotatedOffset.x,
        .y = boss.position.y + rotatedOffset.y,
    };
    paintVulkanZig.verticesForComplexSpriteWithRotate(tailPosition, imageZig.IMAGE_BOSS_DRAGON_TAIL, data.paint.rotation, state);
}

fn paintDragonWings(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    const scaleY = 0.1 + @abs(data.paint.standingPerCent - 0.5) * 2 * 0.9;
    var scaleX: f32 = 1;
    var wingsFlap: f32 = 0;
    if (data.paint.wingsFlapStarted) |time| {
        wingsFlap = @sin(@as(f32, @floatFromInt(state.gameTime - time)) / 200);
        scaleX += (wingsFlap / 2);
    }
    const imageData = imageZig.IMAGE_DATA[imageZig.IMAGE_BOSS_DRAGON_WING];
    const imageToGameSizeFactor: f32 = imageData.scale / imageZig.IMAGE_TO_GAME_SIZE;
    const wingsFlapOffset = @as(f32, @floatFromInt(imageData.width)) * imageToGameSizeFactor * (1 - scaleX) / 2;

    const wingLeftOffset: main.Position = .{
        .x = 50 - wingsFlapOffset,
        .y = 10 - 90 * data.paint.standingPerCent,
    };
    const wingRightOffset: main.Position = .{
        .x = -50 + wingsFlapOffset,
        .y = 10 - 90 * data.paint.standingPerCent,
    };
    const rotatedLeftOffset = main.rotateAroundPoint(wingLeftOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const rotatedRightOffset = main.rotateAroundPoint(wingRightOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const wingLeftPosition: main.Position = .{
        .x = boss.position.x + rotatedLeftOffset.x,
        .y = boss.position.y + rotatedLeftOffset.y,
    };
    const wingRightPosition: main.Position = .{
        .x = boss.position.x + rotatedRightOffset.x,
        .y = boss.position.y + rotatedRightOffset.y,
    };

    if (data.paint.standingPerCent > 0.5) {
        paintVulkanZig.verticesForComplexSprite(wingLeftPosition, imageZig.IMAGE_BOSS_DRAGON_WING, scaleX, scaleY, 1, data.paint.rotation, true, false, state);
        paintVulkanZig.verticesForComplexSprite(wingRightPosition, imageZig.IMAGE_BOSS_DRAGON_WING, scaleX, scaleY, 1, data.paint.rotation, false, false, state);
    } else {
        paintVulkanZig.verticesForComplexSprite(wingLeftPosition, imageZig.IMAGE_BOSS_DRAGON_WING, scaleX, scaleY, 1, data.paint.rotation, true, true, state);
        paintVulkanZig.verticesForComplexSprite(wingRightPosition, imageZig.IMAGE_BOSS_DRAGON_WING, scaleX, scaleY, 1, data.paint.rotation, false, true, state);
    }
}

fn paintDragonBody(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    const bodyOffset: main.Position = .{
        .x = 0,
        .y = -60 * data.paint.standingPerCent,
    };
    const rotatedOffset = main.rotateAroundPoint(bodyOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const bodyPosition: main.Position = .{
        .x = boss.position.x + rotatedOffset.x,
        .y = boss.position.y + rotatedOffset.y,
    };
    const scaleY = 0.5 + @abs(data.paint.standingPerCent - 0.5);
    paintVulkanZig.verticesForComplexSpriteWithCut(
        bodyPosition,
        imageZig.IMAGE_BOSS_DRAGON_BODY_BOTTOM,
        1 - data.paint.standingPerCent,
        1,
        1,
        data.paint.rotation,
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
        data.paint.rotation,
        1,
        scaleY,
        state,
    );
}
