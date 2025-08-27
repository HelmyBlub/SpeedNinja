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

const DragonLandingStompData = struct {
    stompTime: i64,
    stompHeight: f32 = 0,
};

const DragonBodyStompData = struct {
    stompTime: ?i64 = null,
    standUpMaxPerCent: f32 = 0,
    targetPlayerIndex: ?usize = null,
};

const DragonActionData = union(DragonAction) {
    flyingOver: DragonMoveData,
    landing: DragonMoveData,
    landingStomp: DragonLandingStompData,
    bodyStomp: DragonBodyStompData,
};

pub const BossDragonData = struct {
    action: DragonActionData,
    state: DragonState = .ground,
    nextStateTime: ?i64 = null,
    inAirHeight: f32 = 150,
    direction: f32 = 0,
    movingFeetPair1: bool = false,
    feetOffset: [4]main.Position = [4]main.Position{
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
    },
    paint: struct {
        standingPerCent: f32 = 0,
        wingsFlapStarted: ?i64 = null,
        stopWings: bool = false,
        rotation: f32 = 0,
    } = .{},
};

const BOSS_NAME = "Dragon";
const LANDING_STOMP_DELAY = 2000;
const LANDING_STOMP_AREA_RADIUS_X = 2;
const LANDING_STOMP_AREA_RADIUS_Y = 1;
const LANDING_STOMP_AREA_OFFSET: main.Position = .{ .x = 0, .y = -main.TILESIZE };
const BODY_STOMP_DELAY = 1500;
const BODY_STOMP_AREA_RADIUS_X = 2;
const BODY_STOMP_AREA_RADIUS_Y = 2;
const STAND_UP_SPEED = 0.0005;
const DEFAULT_FEET_OFFSET = [4]main.Position{
    .{ .x = -1 * main.TILESIZE, .y = -1 * main.TILESIZE },
    .{ .x = 1 * main.TILESIZE, .y = -1 * main.TILESIZE },
    .{ .x = -1 * main.TILESIZE, .y = 1 * main.TILESIZE },
    .{ .x = 1 * main.TILESIZE, .y = 1 * main.TILESIZE },
};

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
            const direction = main.calculateDirection(boss.position, actionData.targetPos);
            data.direction = direction;
            const distance: f32 = actionData.speed * @as(f32, @floatFromInt(passedTime));
            boss.position = main.moveByDirectionAndDistance(boss.position, direction, distance);
            if (main.calculateDistance(boss.position, actionData.targetPos) <= actionData.speed * 16) {
                boss.position = actionData.targetPos;
                data.paint.standingPerCent = 1;
                data.action = .{ .landing = .{ .speed = 0.1, .targetPos = .{ .x = 0, .y = 0 } } };
            }
        },
        .landing => |actionData| {
            const direction = main.calculateDirection(boss.position, actionData.targetPos);
            data.direction = direction;
            const distance: f32 = actionData.speed * @as(f32, @floatFromInt(passedTime));
            boss.position = main.moveByDirectionAndDistance(boss.position, direction, distance);
            const distanceToTarget = main.calculateDistance(boss.position, actionData.targetPos);
            if (distanceToTarget < data.inAirHeight * 0.75) {
                data.inAirHeight = @max(0, data.inAirHeight - distance);
            }
            if (distanceToTarget <= actionData.speed * 16) {
                boss.position = actionData.targetPos;
                data.action = .{ .landingStomp = .{ .stompTime = state.gameTime + LANDING_STOMP_DELAY } };
                data.paint.stopWings = true;
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
                data.action = .{ .bodyStomp = .{} };
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
            try tickBodyStomp(stompData, boss, passedTime, state);
        },
    }
    adjustFeetToTiles(boss);
}

fn adjustFeetToTiles(boss: *bossZig.Boss) void {
    const data = &boss.typeData.dragon;
    for (0..4) |index| {
        if (data.inAirHeight > 10 or (index >= 2 and data.paint.standingPerCent > 0.2)) {
            data.feetOffset[index] = .{ .x = 0, .y = 0 };
            continue;
        }
        var moveFeet = true;
        if (data.movingFeetPair1) {
            if (index != 0 and index != 2) {
                moveFeet = false;
            }
        } else {
            if (index == 0 or index == 2) {
                moveFeet = false;
            }
        }
        if (moveFeet) {
            const shouldBeOffset = getFootShouldBeOffset(index, boss);
            const direction = main.calculateDirection(data.feetOffset[index], shouldBeOffset);
            data.feetOffset[index] = main.moveByDirectionAndDistance(data.feetOffset[index], direction, 0.2);
            const distance = main.calculateDistance(shouldBeOffset, data.feetOffset[index]);
            if (distance < 2) {
                data.movingFeetPair1 = !data.movingFeetPair1;
            }
        } else {
            data.feetOffset[index] = getFootToCurrentTileOffset(index, boss);
        }
    }
}

fn getFootShouldBeOffset(index: usize, boss: *bossZig.Boss) main.Position {
    const data = &boss.typeData.dragon;
    if (data.inAirHeight > 10 or (index >= 2 and data.paint.standingPerCent > 0.2)) {
        return .{ .x = 0, .y = 0 };
    }
    const defaultFootOffset = DEFAULT_FEET_OFFSET[index];
    const rotatedOffset = main.rotateAroundPoint(defaultFootOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const footPosition: main.Position = .{ .x = boss.position.x + rotatedOffset.x, .y = boss.position.y + rotatedOffset.y };
    const tilePos = main.gamePositionToTilePosition(footPosition);
    const alignedToTilePos = main.tilePositionToGamePosition(tilePos);
    const alignedOffset: main.Position = .{ .x = alignedToTilePos.x - boss.position.x, .y = alignedToTilePos.y - boss.position.y };
    const unrotatedDefaultOffset = main.rotateAroundPoint(alignedOffset, .{ .x = 0, .y = 0 }, -data.paint.rotation);
    return .{ .x = unrotatedDefaultOffset.x - defaultFootOffset.x, .y = unrotatedDefaultOffset.y - defaultFootOffset.y };
}

fn getFootToCurrentTileOffset(index: usize, boss: *bossZig.Boss) main.Position {
    const data = &boss.typeData.dragon;
    if (data.inAirHeight > 10 or (index >= 2 and data.paint.standingPerCent > 0.2)) {
        return .{ .x = 0, .y = 0 };
    }
    const footOffset: main.Position = .{ .x = data.feetOffset[index].x + DEFAULT_FEET_OFFSET[index].x, .y = data.feetOffset[index].y + DEFAULT_FEET_OFFSET[index].y };
    const rotatedOffset = main.rotateAroundPoint(footOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const footPosition: main.Position = .{ .x = boss.position.x + rotatedOffset.x, .y = boss.position.y + rotatedOffset.y };
    const tilePos = main.gamePositionToTilePosition(footPosition);
    const alignedToTilePos = main.tilePositionToGamePosition(tilePos);
    const alignedOffset: main.Position = .{ .x = alignedToTilePos.x - boss.position.x, .y = alignedToTilePos.y - boss.position.y };
    const unrotatedToTileOffset = main.rotateAroundPoint(alignedOffset, .{ .x = 0, .y = 0 }, -data.paint.rotation);
    return .{ .x = unrotatedToTileOffset.x - DEFAULT_FEET_OFFSET[index].x, .y = unrotatedToTileOffset.y - DEFAULT_FEET_OFFSET[index].y };
}

fn tickBodyStomp(stompData: *DragonBodyStompData, boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    if (stompData.stompTime == null and data.paint.standingPerCent < 1) {
        const distanceUp: f32 = STAND_UP_SPEED * @as(f32, @floatFromInt(passedTime));
        data.paint.standingPerCent = @min(1, data.paint.standingPerCent + distanceUp);
    } else if (stompData.targetPlayerIndex == null) {
        stompData.targetPlayerIndex = std.crypto.random.intRangeLessThan(usize, 0, state.players.items.len);
    } else if (stompData.stompTime == null) {
        const targetPlayer = state.players.items[stompData.targetPlayerIndex.?];
        const direction = main.calculateDirection(boss.position, targetPlayer.position);
        setDirection(boss, direction);
        const distance = main.calculateDistance(boss.position, targetPlayer.position);
        if (distance > 40) {
            const moveDistance: f32 = 0.02 * @as(f32, @floatFromInt(passedTime));
            boss.position = main.moveByDirectionAndDistance(boss.position, data.direction, moveDistance);
        } else {
            stompData.stompTime = state.gameTime + BODY_STOMP_DELAY;
        }
    } else {
        const stompTime = stompData.stompTime.?;
        const stompPerCent: f32 = 1 - @max(0, @as(f32, @floatFromInt(stompTime - state.gameTime)) / BODY_STOMP_DELAY);

        const stompStartPerCent = 0.5;
        if (stompPerCent > stompStartPerCent) {
            data.paint.standingPerCent = @sqrt((1 - stompPerCent) / (1 - stompStartPerCent));
        }
        if (stompTime <= state.gameTime) {
            data.action = .{ .bodyStomp = .{} };
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
            const footOffset2: main.Position = .{ .x = footOffset.x + DEFAULT_FEET_OFFSET[footIndex].x, .y = footOffset.y + DEFAULT_FEET_OFFSET[footIndex].y };
            const rotatedOffset = main.rotateAroundPoint(footOffset2, .{ .x = 0, .y = 0 }, data.paint.rotation);
            const footPos: main.Position = .{ .x = boss.position.x + rotatedOffset.x, .y = boss.position.y + rotatedOffset.y };
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

fn setDirection(boss: *bossZig.Boss, newDirection: f32) void {
    const data = &boss.typeData.dragon;
    const rotationPivot: main.Position = .{
        .x = 0,
        .y = -main.TILESIZE * data.paint.standingPerCent,
    };
    const oldOffset = main.rotateAroundPoint(.{ .x = 0, .y = 0 }, rotationPivot, data.direction - std.math.pi / 2.0);
    const newOffset = main.rotateAroundPoint(.{ .x = 0, .y = 0 }, rotationPivot, newDirection - std.math.pi / 2.0);
    boss.position.x = boss.position.x - oldOffset.x + newOffset.x;
    boss.position.y = boss.position.y - oldOffset.y + newOffset.y;
    data.direction = newDirection;
    data.paint.rotation = data.direction - std.math.pi / 2.0;
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
            if (stompData.stompTime) |stompTime| {
                const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(stompTime - state.gameTime)) / BODY_STOMP_DELAY));
                const sizeX: usize = @intCast(BODY_STOMP_AREA_RADIUS_X * 2 + 1);
                const sizeY: usize = @intCast(BODY_STOMP_AREA_RADIUS_Y * 2 + 1);
                for (0..sizeX) |i| {
                    const offsetX: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(i)) - BODY_STOMP_AREA_RADIUS_X)) * main.TILESIZE;
                    for (0..sizeY) |j| {
                        const offsetY: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(j)) - BODY_STOMP_AREA_RADIUS_Y)) * main.TILESIZE;
                        const tilePos: main.TilePosition = main.gamePositionToTilePosition(.{
                            .x = boss.position.x + offsetX,
                            .y = boss.position.y + offsetY,
                        });
                        enemyVulkanZig.addWarningTileSprites(.{
                            .x = @floatFromInt(tilePos.x * main.TILESIZE),
                            .y = @floatFromInt(tilePos.y * main.TILESIZE),
                        }, fillPerCent, state);
                    }
                }
            }
        },
        else => {},
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = &boss.typeData.dragon;
    data.paint.rotation = data.direction - std.math.pi / 2.0;
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
        const footOffset: main.Position = .{ .x = data.feetOffset[index].x + DEFAULT_FEET_OFFSET[index].x, .y = data.feetOffset[index].y + DEFAULT_FEET_OFFSET[index].y };
        const rotatedOffset = main.rotateAroundPoint(footOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
        const footPos: main.Position = .{ .x = boss.position.x + rotatedOffset.x, .y = boss.position.y + rotatedOffset.y - data.inAirHeight };
        paintVulkanZig.verticesForComplexSpriteWithRotate(footPos, imageZig.IMAGE_BOSS_DRAGON_FOOT, data.paint.rotation, state);
    }
}

fn paintDragonFrontFeet(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    for (2..4) |index| {
        const footOffset: main.Position = .{ .x = data.feetOffset[index].x + DEFAULT_FEET_OFFSET[index].x, .y = data.feetOffset[index].y + DEFAULT_FEET_OFFSET[index].y };
        const bodyRotationOffset: main.Position = .{
            .x = 0,
            .y = -100 * data.paint.standingPerCent,
        };
        const bodyRotatedOffset = main.rotateAroundPoint(bodyRotationOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
        const feetRotatedOffset = main.rotateAroundPoint(footOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);

        const footInAirPos: main.Position = .{
            .x = boss.position.x + feetRotatedOffset.x + bodyRotatedOffset.x,
            .y = boss.position.y + feetRotatedOffset.y + bodyRotatedOffset.y - data.inAirHeight,
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
