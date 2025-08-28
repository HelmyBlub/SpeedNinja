const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const mapTileZig = @import("../mapTile.zig");
const enemyObjectFireZig = @import("../enemy/enemyObjectFire.zig");
const movePieceZig = @import("../movePiece.zig");

const DragonPhase = enum {
    phase1,
    phase2,
};

const DragonAction = enum {
    flyingOver,
    landing,
    landingStomp,
    bodyStomp,
    transitionFlyingPhase,
    wingBlast,
    fireBreath,
};

const DragonActionData = union(DragonAction) {
    flyingOver: DragonMoveData,
    landing: DragonMoveData,
    landingStomp: DragonLandingStompData,
    bodyStomp: DragonBodyStompData,
    transitionFlyingPhase: DragonTransitionFlyingData,
    wingBlast: DragonWingBlastData,
    fireBreath: DragonFireBreathData,
};

const DragonFireBreathData = struct {
    nextFireSpitTickTime: ?i64 = null,
    firstFireSpitDelay: i32 = 2000,
    spitInterval: i32 = 100,
    targetPlayerIndex: usize = 0,
    spitEndTime: i64 = 0,
    spitDuration: i32 = 2500,
};

const DragonWingBlastData = struct {
    direction: ?u8 = null,
    nextMoveTickTime: ?i64 = null,
    firstMoveTickDelay: i32 = 2000,
    moveInterval: i32 = 250,
    maxMoveTicks: u16 = 10,
    moveTickCount: u16 = 0,
};

const DragonMoveData = struct {
    targetPos: main.Position,
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

const DragonTransitionFlyingData = struct {
    keepCameraUntilTime: ?i64 = null,
    moveCameraToDefaultTime: ?i64 = null,
    cameraDone: bool = false,
    dragonFlyPositionIndex: usize = 0,
    fireSpawnTile: ?i32 = null,
};

pub const BossDragonData = struct {
    action: DragonActionData,
    phase: DragonPhase = .phase1,
    nextStateTime: ?i64 = null,
    inAirHeight: f32 = DEFAULT_FYLING_HEIGHT,
    direction: f32 = 0,
    movingFeetPair1: bool = false,
    openMouth: bool = false,
    feetOffset: [4]main.Position = [4]main.Position{
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
    },
    paint: struct {
        standingPerCent: f32 = 0,
        mouthOpenPerCent: f32 = 0,
        wingsFlapStarted: ?i64 = null,
        wingFlapSpeedFactor: f32 = 1,
        stopWings: bool = false,
        rotation: f32 = 0,
    } = .{},
};

const DEFAULT_FYLING_HEIGHT = 150;
const BOSS_NAME = "Dragon";
const LANDING_STOMP_DELAY = 2000;
const LANDING_STOMP_AREA_RADIUS_X = 2;
const LANDING_STOMP_AREA_RADIUS_Y = 1;
const LANDING_STOMP_AREA_OFFSET: main.Position = .{ .x = 0, .y = -main.TILESIZE };
const BODY_STOMP_DELAY = 1500;
const BODY_STOMP_AREA_RADIUS_X = 2;
const BODY_STOMP_AREA_RADIUS_Y = 2;
const STAND_UP_SPEED = 0.0005;
const FLYING_TRANSITION_CAMERA_WAIT_TIME = 2000;
const FLYING_TRANSITION_CAMERA_MOVE_DURATION = 2000;
const FLYING_TRANSITION_CAMERA_OFFSET_Y = -300;
const DEFAULT_FLYING_SPEED = 0.3;
const DEFAULT_FEET_OFFSET = [4]main.Position{
    .{ .x = -1 * main.TILESIZE, .y = -1 * main.TILESIZE },
    .{ .x = 1 * main.TILESIZE, .y = -1 * main.TILESIZE },
    .{ .x = -1 * main.TILESIZE, .y = 1 * main.TILESIZE },
    .{ .x = 1 * main.TILESIZE, .y = 1 * main.TILESIZE },
};
const FLYING_TRANSITION_DRAGON_POSITIONS = [4]main.Position{
    .{ .x = 25 * main.TILESIZE, .y = 0 },
    .{ .x = -25 * main.TILESIZE, .y = 0 },
    .{ .x = 0, .y = 25 * main.TILESIZE },
    .{ .x = 0, .y = -25 * main.TILESIZE },
};
const PHASE_2_TRANSITION_PER_CENT = 0.80;

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 50,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
        .onPlayerMoveEachTile = onPlayerMoveEachTile,
    };
}

fn startBoss(state: *main.GameState) !void {
    var boss: bossZig.Boss = .{
        .hp = 50,
        .maxHp = 50,
        .imageIndex = imageZig.IMAGE_EVIL_TOWER,
        .position = .{ .x = 0, .y = 800 },
        .name = BOSS_NAME,
        .typeData = .{ .dragon = .{ .action = .{ .flyingOver = .{ .targetPos = .{ .x = 0, .y = -300 } } } } },
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

fn onPlayerMoveEachTile(boss: *bossZig.Boss, player: *main.Player, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    switch (data.action) {
        .fireBreath => |*fireBreathData| {
            if (fireBreathData.spitEndTime - fireBreathData.spitDuration <= state.gameTime) {
                if (player == &state.players.items[fireBreathData.targetPlayerIndex]) {
                    fireBreathData.nextFireSpitTickTime = state.gameTime + fireBreathData.spitInterval;
                    const targetPos = player.position;
                    try enemyObjectFireZig.spawnFlyingEternalFire(boss.position, targetPos, 100, state);
                }
            }
        },
        else => {},
    }
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    switch (data.action) {
        .flyingOver => |actionData| {
            if (moveBossTick(boss, actionData.targetPos, passedTime, DEFAULT_FLYING_SPEED)) {
                data.paint.standingPerCent = 1;
                data.action = .{ .landing = .{ .targetPos = .{ .x = 0, .y = 0 } } };
            }
        },
        .landing => |actionData| {
            const direction = main.calculateDirection(boss.position, actionData.targetPos);
            data.direction = direction;
            const landingSpeed = 0.1;
            const distance: f32 = landingSpeed * @as(f32, @floatFromInt(passedTime));
            boss.position = main.moveByDirectionAndDistance(boss.position, direction, distance);
            const distanceToTarget = main.calculateDistance(boss.position, actionData.targetPos);
            if (distanceToTarget < data.inAirHeight * 0.75) {
                data.inAirHeight = @max(0, data.inAirHeight - distance);
            }
            if (distanceToTarget <= landingSpeed * 16) {
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
                chooseNextAttack(boss);
            }
        },
        .bodyStomp => |*stompData| {
            try tickBodyStomp(stompData, boss, passedTime, state);
        },
        .transitionFlyingPhase => |*flyingData| {
            try tickTransitionFlyingPhase(flyingData, boss, passedTime, state);
        },
        .wingBlast => |*wingBlastData| {
            try tickWingBlastAction(wingBlastData, boss, passedTime, state);
        },
        .fireBreath => |*fireBreathData| {
            try tickFireBreathAction(fireBreathData, boss, passedTime, state);
        },
    }
    adjustFeetToTiles(boss, passedTime);
    if (data.openMouth) {
        if (data.paint.mouthOpenPerCent < 1) {
            data.paint.mouthOpenPerCent += @as(f32, @floatFromInt(passedTime)) * 0.001;
            if (data.paint.mouthOpenPerCent > 1) data.paint.mouthOpenPerCent = 1;
        }
    } else {
        if (data.paint.mouthOpenPerCent > 0) {
            data.paint.mouthOpenPerCent -= @as(f32, @floatFromInt(passedTime)) * 0.001;
            if (data.paint.mouthOpenPerCent < 0) data.paint.mouthOpenPerCent = 0;
        }
    }
}

fn tickFireBreathAction(fireBreathData: *DragonFireBreathData, boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    if (fireBreathData.nextFireSpitTickTime == null) {
        fireBreathData.nextFireSpitTickTime = state.gameTime + fireBreathData.firstFireSpitDelay;
        fireBreathData.targetPlayerIndex = std.crypto.random.intRangeLessThan(usize, 0, state.players.items.len);
        fireBreathData.spitEndTime = fireBreathData.nextFireSpitTickTime.? + fireBreathData.spitDuration;
        setDirection(boss, std.math.pi / 2.0);
        data.openMouth = true;
    } else {
        standUpTick(boss, passedTime);
        if (fireBreathData.nextFireSpitTickTime.? <= state.gameTime) {
            fireBreathData.nextFireSpitTickTime = state.gameTime + fireBreathData.spitInterval;
            const targetPos = state.players.items[fireBreathData.targetPlayerIndex].position;
            try enemyObjectFireZig.spawnFlyingEternalFire(boss.position, targetPos, 100, state);
        }
        if (fireBreathData.spitEndTime <= state.gameTime) {
            data.openMouth = false;
            chooseNextAttack(boss);
        }
    }
}

fn tickWingBlastAction(wingBlastData: *DragonWingBlastData, boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    if (wingBlastData.nextMoveTickTime == null) {
        wingBlastData.nextMoveTickTime = state.gameTime + wingBlastData.firstMoveTickDelay;
        wingBlastData.direction = std.crypto.random.intRangeLessThan(u8, 0, 4);
        const bossDirection: f32 = @as(f32, @floatFromInt(wingBlastData.direction.?)) * std.math.pi / 2;
        setDirection(boss, bossDirection);
        data.paint.stopWings = false;
        data.paint.wingsFlapStarted = state.gameTime;
        data.paint.wingFlapSpeedFactor = 1;
    } else {
        standUpTick(boss, passedTime);
        data.paint.wingFlapSpeedFactor = @min(data.paint.wingFlapSpeedFactor + 0.002, 3);
        const nextMoveTickTime = wingBlastData.nextMoveTickTime.?;
        if (nextMoveTickTime <= state.gameTime) {
            wingBlastData.nextMoveTickTime = state.gameTime + wingBlastData.moveInterval;
            wingBlastData.moveTickCount += 1;
            const stepDirection = movePieceZig.getStepDirection(wingBlastData.direction.?);
            for (state.players.items) |*player| {
                player.position.x += stepDirection.x * main.TILESIZE;
                player.position.y += stepDirection.y * main.TILESIZE;
                const tilePos = main.gamePositionToTilePosition(player.position);
                if (@abs(tilePos.x) > state.mapData.tileRadius or @abs(tilePos.y) > state.mapData.tileRadius) {
                    try main.playerHit(player, state);
                }
            }
            for (state.enemyData.enemyObjects.items) |*object| {
                object.position.x += stepDirection.x * main.TILESIZE;
                object.position.y += stepDirection.y * main.TILESIZE;
            }
            if (wingBlastData.maxMoveTicks <= wingBlastData.moveTickCount) {
                data.paint.stopWings = true;
                data.paint.wingFlapSpeedFactor = 1;
                chooseNextAttack(boss);
            }
        }
    }
}

fn chooseNextAttack(boss: *bossZig.Boss) void {
    std.debug.print("next attack {}\n", .{boss.typeData.dragon.action});
    const data = &boss.typeData.dragon;
    switch (data.phase) {
        .phase1 => data.action = .{ .bodyStomp = .{} },
        .phase2 => {
            const randomIndex = std.crypto.random.intRangeLessThan(usize, 0, 3);
            if (randomIndex == 0) data.action = .{ .bodyStomp = .{} };
            if (randomIndex == 1) data.action = .{ .wingBlast = .{} };
            if (randomIndex == 2) data.action = .{ .fireBreath = .{} };
        },
    }
}

fn moveBossTick(boss: *bossZig.Boss, targetPos: main.Position, passedTime: i64, speed: f32) bool {
    const data = &boss.typeData.dragon;
    const direction = main.calculateDirection(boss.position, targetPos);
    data.direction = direction;
    const distance: f32 = DEFAULT_FLYING_SPEED * @as(f32, @floatFromInt(passedTime));
    boss.position = main.moveByDirectionAndDistance(boss.position, direction, distance);
    if (main.calculateDistance(boss.position, targetPos) <= speed * 16) {
        boss.position = targetPos;
        return true;
    }
    return false;
}

fn tickTransitionFlyingPhase(flyingData: *DragonTransitionFlyingData, boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    if (!flyingData.cameraDone) {
        if (flyingData.moveCameraToDefaultTime == null) {
            if (flyingData.keepCameraUntilTime == null) {
                flyingData.keepCameraUntilTime = state.gameTime + FLYING_TRANSITION_CAMERA_WAIT_TIME;
                state.camera.position.y = FLYING_TRANSITION_CAMERA_OFFSET_Y;
                data.inAirHeight -= FLYING_TRANSITION_CAMERA_OFFSET_Y;
                for (state.paintData.backClouds[0..]) |*cloud| {
                    cloud.position.y += FLYING_TRANSITION_CAMERA_OFFSET_Y;
                }
                for (state.players.items) |*player| {
                    player.inAirHeight -= FLYING_TRANSITION_CAMERA_OFFSET_Y;
                }
                state.paintData.frontCloud.position.y += FLYING_TRANSITION_CAMERA_OFFSET_Y;
            } else if (flyingData.keepCameraUntilTime.? <= state.gameTime) {
                flyingData.moveCameraToDefaultTime = state.gameTime + FLYING_TRANSITION_CAMERA_MOVE_DURATION;
            }
        } else {
            const movePerCent: f32 = @max(0, @as(f32, @floatFromInt(flyingData.moveCameraToDefaultTime.? - state.gameTime)) / FLYING_TRANSITION_CAMERA_MOVE_DURATION);
            state.camera.position.y = FLYING_TRANSITION_CAMERA_OFFSET_Y * movePerCent;
            if (movePerCent == 0) {
                flyingData.cameraDone = true;
            }
        }
    }
    if (flyingData.dragonFlyPositionIndex < FLYING_TRANSITION_DRAGON_POSITIONS.len) {
        if (flyingData.moveCameraToDefaultTime != null) {
            if (data.inAirHeight > DEFAULT_FYLING_HEIGHT) {
                data.inAirHeight -= DEFAULT_FLYING_SPEED * @as(f32, @floatFromInt(passedTime));
            }
            var currentTargetPos = FLYING_TRANSITION_DRAGON_POSITIONS[flyingData.dragonFlyPositionIndex];
            const randomPlayerIndex = std.crypto.random.intRangeLessThan(usize, 0, state.players.items.len);
            switch (flyingData.dragonFlyPositionIndex) {
                0 => {
                    const fMapRadius = @as(f32, @floatFromInt(state.mapData.tileRadius * main.TILESIZE));
                    const offsetY: f32 = @max(@min(fMapRadius, state.players.items[randomPlayerIndex].position.y), -fMapRadius);
                    currentTargetPos.y = offsetY;
                },
                1 => currentTargetPos.y = boss.position.y,
                2 => {
                    const fMapRadius = @as(f32, @floatFromInt(state.mapData.tileRadius * main.TILESIZE));
                    const offsetX: f32 = @max(@min(fMapRadius, state.players.items[randomPlayerIndex].position.x), -fMapRadius);
                    currentTargetPos.x = offsetX;
                },
                3 => currentTargetPos.x = boss.position.x,
                else => {},
            }

            if (moveBossTick(boss, currentTargetPos, passedTime, DEFAULT_FLYING_SPEED)) {
                flyingData.dragonFlyPositionIndex += 1;
                if (flyingData.dragonFlyPositionIndex == 1 or flyingData.dragonFlyPositionIndex == 3) {
                    flyingData.fireSpawnTile = @intCast(state.mapData.tileRadius);
                }
            }
            const bossTilePos = main.gamePositionToTilePosition(boss.position);
            if (flyingData.dragonFlyPositionIndex == 1) {
                if (flyingData.fireSpawnTile.? >= bossTilePos.x and -@as(i32, @intCast(state.mapData.tileRadius)) <= flyingData.fireSpawnTile.?) {
                    flyingData.fireSpawnTile.? -= 1;
                    const flyToPosition = main.tilePositionToGamePosition(main.gamePositionToTilePosition(boss.position));
                    const fireSpawn: main.Position = .{ .x = boss.position.x, .y = boss.position.y };
                    try enemyObjectFireZig.spawnFlyingEternalFire(fireSpawn, flyToPosition, data.inAirHeight, state);
                }
            }
            if (flyingData.dragonFlyPositionIndex == 3) {
                if (flyingData.fireSpawnTile.? >= bossTilePos.y and -@as(i32, @intCast(state.mapData.tileRadius)) <= flyingData.fireSpawnTile.?) {
                    flyingData.fireSpawnTile.? -= 1;
                    const flyToPosition = main.tilePositionToGamePosition(main.gamePositionToTilePosition(boss.position));
                    const fireSpawn: main.Position = .{ .x = boss.position.x, .y = boss.position.y };
                    try enemyObjectFireZig.spawnFlyingEternalFire(fireSpawn, flyToPosition, data.inAirHeight, state);
                }
            }
        }
    } else {
        data.paint.standingPerCent = 1;
        data.action = .{ .landing = .{ .targetPos = .{ .x = 0, .y = 0 } } };
    }
}

fn adjustFeetToTiles(boss: *bossZig.Boss, passedTime: i64) void {
    const data = &boss.typeData.dragon;
    for (0..4) |index| {
        if (data.inAirHeight > 10 or (index >= 2 and data.paint.standingPerCent > 0.2)) {
            data.feetOffset[index] = .{ .x = 0, .y = 0 };
            continue;
        }
        var moveFeet = true;
        if (data.movingFeetPair1) {
            if (index != 0 and index != 3) {
                moveFeet = false;
            }
        } else {
            if (index == 0 or index == 3) {
                moveFeet = false;
            }
        }
        if (moveFeet) {
            const shouldBeOffset = getFootShouldBeOffset(index, boss);
            const direction = main.calculateDirection(data.feetOffset[index], shouldBeOffset);
            const moveDistance: f32 = @as(f32, @floatFromInt(passedTime)) * 0.04;
            data.feetOffset[index] = main.moveByDirectionAndDistance(data.feetOffset[index], direction, moveDistance);
            const distance = main.calculateDistance(shouldBeOffset, data.feetOffset[index]);
            if (distance < 2) {
                data.feetOffset[index] = shouldBeOffset;
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

fn standUpTick(boss: *bossZig.Boss, passedTime: i64) void {
    const data = &boss.typeData.dragon;
    const distanceUp: f32 = STAND_UP_SPEED * @as(f32, @floatFromInt(passedTime));
    data.paint.standingPerCent = @min(1, data.paint.standingPerCent + distanceUp);
}

fn tickBodyStomp(stompData: *DragonBodyStompData, boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    if (stompData.stompTime == null and data.paint.standingPerCent < 1) {
        standUpTick(boss, passedTime);
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
            const hpPerCent: f32 = @as(f32, @floatFromInt(boss.hp)) / @as(f32, @floatFromInt(boss.maxHp));
            if (data.phase == .phase1 and hpPerCent < PHASE_2_TRANSITION_PER_CENT) {
                data.action = .{ .transitionFlyingPhase = .{} };
                data.phase = .phase2;
                try cutTilesForGroundBreakingEffect(state);
            } else {
                chooseNextAttack(boss);
            }
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

fn cutTilesForGroundBreakingEffect(state: *main.GameState) !void {
    const mapGridSize = state.mapData.tileRadius * 2 + 1;
    const fMapTileRadius: f32 = @floatFromInt(state.mapData.tileRadius);
    for (0..mapGridSize) |i| {
        const x: f32 = (@as(f32, @floatFromInt(i)) - fMapTileRadius) * main.TILESIZE;
        for (0..mapGridSize) |j| {
            const y: f32 = (@as(f32, @floatFromInt(j)) - fMapTileRadius) * main.TILESIZE;
            try state.spriteCutAnimations.append(.{
                .deathTime = state.gameTime,
                .position = .{ .x = x, .y = y + FLYING_TRANSITION_CAMERA_OFFSET_Y },
                .cutAngle = 0,
                .force = -1,
                .colorOrImageIndex = .{ .color = main.COLOR_TILE_GREEN },
            });
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
        .wingBlast => |wingBlastData| {
            if (wingBlastData.nextMoveTickTime) |nextMoveTime| {
                const rotation: f32 = @as(f32, @floatFromInt(wingBlastData.direction.?)) * std.math.pi / 2.0;
                const duration = if (wingBlastData.moveTickCount == 0) wingBlastData.firstMoveTickDelay else wingBlastData.moveInterval;
                const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(nextMoveTime - state.gameTime)) / @as(f32, @floatFromInt(duration))));
                const stepDirection = movePieceZig.getStepDirection(wingBlastData.direction.?);
                for (state.players.items) |player| {
                    enemyVulkanZig.addRedArrowTileSprites(.{
                        .x = player.position.x + stepDirection.x * main.TILESIZE,
                        .y = player.position.y + stepDirection.y * main.TILESIZE,
                    }, fillPerCent, rotation, state);
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
    paintVulkanZig.verticesForComplexSpriteWithRotate(headPosition, imageZig.IMAGE_BOSS_DRAGON_HEAD_LAYER1, data.paint.rotation, state);
    const scaleY = 1 - (data.paint.mouthOpenPerCent * 0.5);
    paintVulkanZig.verticesForComplexSprite(
        headPosition,
        imageZig.IMAGE_BOSS_DRAGON_HEAD_LAYER2,
        1,
        scaleY,
        1,
        data.paint.rotation,
        false,
        false,
        state,
    );
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
        wingsFlap = @sin(@as(f32, @floatFromInt((state.gameTime - time))) * data.paint.wingFlapSpeedFactor / 200);
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
