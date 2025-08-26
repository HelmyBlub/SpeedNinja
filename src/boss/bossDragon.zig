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

const DragonAction = enum {
    flyingOver,
    landing,
    landingStomp,
    bodyStomp,
};

const DragonMoveData = struct {
    targetPos: main.Position,
    speed: f32,
};

const DragonMoveStompData = struct {
    stompTime: i64,
    stompHeight: f32 = 0,
};

const DrgonActionData = union(DragonAction) {
    flyingOver: DragonMoveData,
    landing: DragonMoveData,
    landingStomp: DragonMoveStompData,
    bodyStomp: DragonMoveStompData,
};

pub const BossDragonData = struct {
    action: DrgonActionData,
    state: DragonState = .ground,
    nextStateTime: ?i64 = null,
    inAirHeight: f32 = 150,
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
        stopWings: bool = false,
    } = .{},
};

const BOSS_NAME = "Dragon";
const LANDING_STOMP_DELAY = 2000;
const LANDING_STOMP_AREA_RADIUS_X = 2;
const LANDING_STOMP_AREA_RADIUS_Y = 1;
const LANDING_STOMP_AREA_OFFSET: main.Position = .{ .x = 0, .y = -main.TILESIZE };
const BODY_STOMP_DELAY = 2000;
const BODY_STOMP_AREA_RADIUS_X = 2;
const BODY_STOMP_AREA_RADIUS_Y = 2;

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
        .typeData = .{ .dragon = .{ .action = .{ .flyingOver = .{ .speed = 0.3, .targetPos = .{ .x = 0, .y = -300 } } } } },
    };
    boss.typeData.dragon.paint.rotation = 1;
    boss.typeData.dragon.paint.wingsFlapStarted = state.gameTime;
    boss.typeData.dragon.paint.stopWings = false;
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
    const data = &boss.typeData.dragon;
    switch (data.action) {
        .flyingOver => |actionData| {
            const rotation = main.calculateDirection(boss.position, actionData.targetPos);
            data.paint.rotation = rotation - std.math.pi / 2.0;
            const distance: f32 = actionData.speed * @as(f32, @floatFromInt(passedTime));
            boss.position = main.moveByDirectionAndDistance(boss.position, rotation, distance);
            if (main.calculateDistance(boss.position, actionData.targetPos) <= actionData.speed * 16) {
                boss.position = actionData.targetPos;
                data.paint.standingPerCent = 1;
                data.action = .{ .landing = .{ .speed = 0.1, .targetPos = .{ .x = 0, .y = 0 } } };
            }
        },
        .landing => |actionData| {
            const rotation = main.calculateDirection(boss.position, actionData.targetPos);
            data.paint.rotation = rotation - std.math.pi / 2.0;
            const distance: f32 = actionData.speed * @as(f32, @floatFromInt(passedTime));
            boss.position = main.moveByDirectionAndDistance(boss.position, rotation, distance);
            const distanceToTarget = main.calculateDistance(boss.position, actionData.targetPos);
            if (distanceToTarget < data.inAirHeight * 0.75) {
                data.inAirHeight = @max(0, data.inAirHeight - distance);
            }
            if (distanceToTarget <= actionData.speed * 16) {
                boss.position = actionData.targetPos;
                data.action = .{ .landingStomp = .{ .stompTime = state.gameTime + LANDING_STOMP_DELAY } };
                data.paint.stopWings = true;
                data.paint.rotation = 0;
            }
        },
        .landingStomp => |*stompData| {
            const stompPerCent: f32 = 1 - @max(0, @as(f32, @floatFromInt(stompData.stompTime - state.gameTime)) / LANDING_STOMP_DELAY);
            const stompStartPerCent = 0.9;
            if (stompPerCent < stompStartPerCent) {
                const distanceUp: f32 = 0.02 * @as(f32, @floatFromInt(passedTime));
                data.inAirHeight += distanceUp;
                stompData.stompHeight = data.inAirHeight;
            } else {
                data.inAirHeight = stompData.stompHeight * @sqrt((1 - stompPerCent) / (1 - stompStartPerCent));
            }
            if (stompData.stompTime <= state.gameTime) {
                data.action = .{ .bodyStomp = .{ .stompTime = state.gameTime + BODY_STOMP_DELAY } };
                data.inAirHeight = 0;
                try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_STOMP_INDICIES[0..], 0, 1);
                const attackTileCenter = main.gamePositionToTilePosition(.{ .x = boss.position.x + LANDING_STOMP_AREA_OFFSET.x, .y = boss.position.y + LANDING_STOMP_AREA_OFFSET.y });
                const damageTileRectangle: main.TileRectangle = .{
                    .pos = .{ .x = attackTileCenter.x - LANDING_STOMP_AREA_RADIUS_X, .y = attackTileCenter.y - LANDING_STOMP_AREA_RADIUS_Y },
                    .width = LANDING_STOMP_AREA_RADIUS_X * 2 + 1,
                    .height = LANDING_STOMP_AREA_RADIUS_Y * 2 + 1,
                };
                for (state.players.items) |*player| {
                    const playerTile = main.gamePositionToTilePosition(player.position);
                    if (main.isTilePositionInTileRectangle(playerTile, damageTileRectangle)) {
                        try main.playerHit(player, state);
                    }
                }
            }
        },
        .bodyStomp => |*stompData| {
            const stompPerCent: f32 = 1 - @max(0, @as(f32, @floatFromInt(stompData.stompTime - state.gameTime)) / BODY_STOMP_DELAY);
            const stompStartPerCent = 0.8;
            if (stompPerCent < stompStartPerCent) {
                const distanceUp: f32 = 0.0005 * @as(f32, @floatFromInt(passedTime));
                data.paint.standingPerCent = @min(1, data.paint.standingPerCent + distanceUp);
                stompData.stompHeight = data.paint.standingPerCent;
            } else {
                data.paint.standingPerCent = stompData.stompHeight * @sqrt((1 - stompPerCent) / (1 - stompStartPerCent));
            }
            if (stompData.stompTime <= state.gameTime) {
                data.action = .{ .bodyStomp = .{ .stompTime = state.gameTime + BODY_STOMP_DELAY } };
                try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_STOMP_INDICIES[0..], 0, 1);
                const attackTileCenter = main.gamePositionToTilePosition(.{ .x = boss.position.x, .y = boss.position.y });
                const damageTileRectangle: main.TileRectangle = .{
                    .pos = .{ .x = attackTileCenter.x - BODY_STOMP_AREA_RADIUS_X, .y = attackTileCenter.y - BODY_STOMP_AREA_RADIUS_Y },
                    .width = BODY_STOMP_AREA_RADIUS_X * 2 + 1,
                    .height = BODY_STOMP_AREA_RADIUS_Y * 2 + 1,
                };
                for (state.players.items) |*player| {
                    const playerTile = main.gamePositionToTilePosition(player.position);
                    if (main.isTilePositionInTileRectangle(playerTile, damageTileRectangle)) {
                        try main.playerHit(player, state);
                    }
                }
            }
        },
        // else => {
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
        // },
    }
}

fn isBossHit(boss: *bossZig.Boss, player: *main.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    _ = state;
    _ = cutRotation;
    _ = hitDirection;
    _ = player;
    const data = &boss.typeData.dragon;
    if (data.inAirHeight < 5) {
        for (data.feetOffset, 0..) |footOffset, footIndex| {
            const footPos: main.Position = .{ .x = boss.position.x + footOffset.x, .y = boss.position.y + footOffset.y };
            const footTile = main.gamePositionToTilePosition(footPos);
            if (footIndex >= 2 and data.paint.standingPerCent > 0.2) {
                continue;
            }
            if (main.isTilePositionInTileRectangle(footTile, hitArea)) {
                boss.hp -|= 1;
                return true;
            }
        }
    }
    return false;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) !void {
    const data = boss.typeData.dragon;
    switch (data.action) {
        .landingStomp => |stompData| {
            const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(stompData.stompTime - state.gameTime)) / LANDING_STOMP_DELAY));
            const sizeX: usize = @intCast(LANDING_STOMP_AREA_RADIUS_X * 2 + 1);
            const sizeY: usize = @intCast(LANDING_STOMP_AREA_RADIUS_Y * 2 + 1);
            for (0..sizeX) |i| {
                const offsetX: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(i)) - LANDING_STOMP_AREA_RADIUS_X)) * main.TILESIZE + LANDING_STOMP_AREA_OFFSET.x;
                for (0..sizeY) |j| {
                    const offsetY: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(j)) - LANDING_STOMP_AREA_RADIUS_Y)) * main.TILESIZE + LANDING_STOMP_AREA_OFFSET.y;
                    enemyVulkanZig.addWarningTileSprites(.{
                        .x = boss.position.x + offsetX,
                        .y = boss.position.y + offsetY,
                    }, fillPerCent, state);
                }
            }
        },
        .bodyStomp => |stompData| {
            const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(stompData.stompTime - state.gameTime)) / LANDING_STOMP_DELAY));
            const sizeX: usize = @intCast(BODY_STOMP_AREA_RADIUS_X * 2 + 1);
            const sizeY: usize = @intCast(BODY_STOMP_AREA_RADIUS_Y * 2 + 1);
            for (0..sizeX) |i| {
                const offsetX: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(i)) - BODY_STOMP_AREA_RADIUS_X)) * main.TILESIZE;
                for (0..sizeY) |j| {
                    const offsetY: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(j)) - BODY_STOMP_AREA_RADIUS_Y)) * main.TILESIZE;
                    enemyVulkanZig.addWarningTileSprites(.{
                        .x = boss.position.x + offsetX,
                        .y = boss.position.y + offsetY,
                    }, fillPerCent, state);
                }
            }
        },
        else => {},
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    paintShadow(boss, state);
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

fn paintShadow(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    if (data.inAirHeight > 1) {
        paintVulkanZig.verticesForComplexSprite(
            .{
                .x = boss.position.x,
                .y = boss.position.y + 5 - data.paint.standingPerCent * 20,
            },
            imageZig.IMAGE_SHADOW,
            4,
            4,
            0.75,
            0,
            false,
            false,
            state,
        );
    }
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
        .y = boss.position.y + rotatedOffset.y - data.inAirHeight,
    };
    paintVulkanZig.verticesForComplexSpriteWithRotate(headPosition, imageZig.IMAGE_BOSS_DRAGON_HEAD, data.paint.rotation, state);
}

fn paintDragonBackFeet(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    for (0..2) |index| {
        const footOffset = data.feetOffset[index];
        const footPos: main.Position = .{ .x = boss.position.x + footOffset.x, .y = boss.position.y + footOffset.y - data.inAirHeight };
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
            .y = boss.position.y + foot.y + rotatedOffset.y - data.inAirHeight,
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
        .y = boss.position.y + rotatedOffset.y - data.inAirHeight,
    };
    paintVulkanZig.verticesForComplexSpriteWithRotate(tailPosition, imageZig.IMAGE_BOSS_DRAGON_TAIL, data.paint.rotation, state);
}

fn paintDragonWings(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = &boss.typeData.dragon;
    const scaleY = 0.1 + @abs(data.paint.standingPerCent - 0.5) * 2 * 0.9;
    var scaleX: f32 = 1;
    var wingsFlap: f32 = 0;
    if (data.inAirHeight > 0 and data.paint.wingsFlapStarted == null) {
        data.paint.wingsFlapStarted = state.gameTime;
    }
    if (data.paint.wingsFlapStarted) |time| {
        wingsFlap = @sin(@as(f32, @floatFromInt(state.gameTime - time)) / 200);
        scaleX += (wingsFlap / 2);
        if (data.inAirHeight < 1 and data.paint.stopWings and @abs(wingsFlap) < 0.1) data.paint.wingsFlapStarted = null;
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
        .y = boss.position.y + rotatedLeftOffset.y - data.inAirHeight,
    };
    const wingRightPosition: main.Position = .{
        .x = boss.position.x + rotatedRightOffset.x,
        .y = boss.position.y + rotatedRightOffset.y - data.inAirHeight,
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
        .y = boss.position.y + rotatedOffset.y - data.inAirHeight,
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
