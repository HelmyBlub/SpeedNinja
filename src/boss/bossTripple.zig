const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");
const enemyObjectProjectileZig = @import("../enemy/enemyObjectProjectile.zig");
const enemyObjectFireZig = @import("../enemy/enemyObjectFire.zig");
const mapTileZig = @import("../mapTile.zig");

const AttackDelayed = struct {
    targetPosition: main.TilePosition,
    hitTime: i64,
};

pub const BossTrippleData = struct {
    direction: u8,
    lastTurnTime: i64 = 0,
    attacksPerBeingHit: u32 = 1,
    minTurnInterval: i32 = 4000,
    enabledShuriken: bool = false,
    shurikenRepeat: u32 = 0,
    shurikenDelay: i32 = 2000,
    shurikenMoveInterval: i32 = 1000,
    shurikenThrowTime: ?i64 = null,
    enabledFire: bool = false,
    fireDuration: i32 = 12000,
    enabledAirAttack: bool = false,
    airAttackRepeat: u32 = 0,
    airAttackPosition: std.ArrayList(AttackDelayed),
    airAttackPlayerOnStationary: ?*main.Player = null,
    airAttackRepeatNextTime: i64 = 0,
    airAttackDelay: i32 = 2000,
};

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 30,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
        .deinit = deinit,
    };
}

fn deinit(boss: *bossZig.Boss, allocator: std.mem.Allocator) void {
    _ = allocator;
    const trippleData = &boss.typeData.tripple;
    trippleData.airAttackPosition.deinit();
}

fn startBoss(state: *main.GameState) !void {
    const scaledHp = bossZig.getHpScalingForLevel(5, state);
    const bossHp = scaledHp;
    var boss1: bossZig.Boss = .{
        .hp = bossHp,
        .maxHp = bossHp,
        .imageIndex = imageZig.IMAGE_BOSS_TRIPPLE,
        .position = .{ .x = -1 * main.TILESIZE, .y = -1 * main.TILESIZE },
        .name = "Trip",
        .typeData = .{ .tripple = .{
            .direction = 0,
            .airAttackPosition = std.ArrayList(AttackDelayed).init(state.allocator),
            .enabledAirAttack = true,
        } },
    };
    scaleBossToNewGamePlus(&boss1.typeData.tripple, state.newGamePlus);
    try state.bosses.append(boss1);
    var boss2: bossZig.Boss = .{
        .hp = bossHp,
        .maxHp = bossHp,
        .imageIndex = imageZig.IMAGE_BOSS_TRIPPLE,
        .position = .{ .x = 3 * main.TILESIZE, .y = 0 },
        .name = "Ripp",
        .typeData = .{ .tripple = .{
            .direction = 0,
            .airAttackPosition = std.ArrayList(AttackDelayed).init(state.allocator),
            .enabledFire = true,
        } },
    };
    scaleBossToNewGamePlus(&boss2.typeData.tripple, state.newGamePlus);
    try state.bosses.append(boss2);
    var boss3: bossZig.Boss = .{
        .hp = bossHp,
        .maxHp = bossHp,
        .imageIndex = imageZig.IMAGE_BOSS_TRIPPLE,
        .position = .{ .x = 0, .y = 3 * main.TILESIZE },
        .name = "Ipple",
        .typeData = .{ .tripple = .{
            .direction = 0,
            .airAttackPosition = std.ArrayList(AttackDelayed).init(state.allocator),
            .enabledShuriken = true,
        } },
    };
    scaleBossToNewGamePlus(&boss3.typeData.tripple, state.newGamePlus);
    try state.bosses.append(boss3);
    try mapTileZig.setMapRadius(6, state);
    main.adjustZoom(state);
}

fn scaleBossToNewGamePlus(tripple: *BossTrippleData, newGamePlus: u32) void {
    if (newGamePlus == 0) return;
    tripple.minTurnInterval = @divFloor(tripple.minTurnInterval, @as(i32, @intCast(newGamePlus + 1)));
    tripple.shurikenDelay = @divFloor(tripple.shurikenDelay, @as(i32, @intCast(newGamePlus + 1)));
    tripple.shurikenMoveInterval = @divFloor(tripple.shurikenMoveInterval, @as(i32, @intCast(newGamePlus + 1)));
    tripple.airAttackDelay = @divFloor(tripple.airAttackDelay, @as(i32, @intCast(newGamePlus + 1)));
    tripple.fireDuration += @intCast(newGamePlus * 6000);
    tripple.attacksPerBeingHit += @min(newGamePlus, 3);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const trippleData = &boss.typeData.tripple;
    if (trippleData.lastTurnTime + trippleData.minTurnInterval < state.gameTime) {
        const closestPlayer = main.findClosestPlayer(boss.position, state);
        if (closestPlayer.executeMovePiece == null) {
            const direction = main.getDirectionFromTo(boss.position, closestPlayer.position);
            if (direction != trippleData.direction) {
                trippleData.direction = direction;
                trippleData.lastTurnTime = state.gameTime;
            }
        }
    }
    if (trippleData.shurikenThrowTime) |throwTime| {
        if (throwTime <= state.gameTime) {
            for (0..4) |direction| {
                const stepDirection = movePieceZig.getStepDirection(@intCast(direction));
                const spawnPosition: main.Position = .{
                    .x = boss.position.x + stepDirection.x * main.TILESIZE,
                    .y = boss.position.y + stepDirection.y * main.TILESIZE,
                };
                try enemyObjectProjectileZig.spawnProjectile(
                    spawnPosition,
                    @intCast(direction),
                    imageZig.IMAGE_SHURIKEN,
                    trippleData.shurikenMoveInterval,
                    false,
                    state,
                );
            }
            trippleData.shurikenRepeat -|= 1;
            if (trippleData.shurikenRepeat > 0) {
                trippleData.shurikenThrowTime = state.gameTime + trippleData.shurikenDelay;
            } else {
                trippleData.shurikenThrowTime = null;
            }
        }
    }

    if (trippleData.airAttackPlayerOnStationary) |player| {
        if (player.executeMovePiece == null) {
            if (trippleData.airAttackRepeatNextTime < state.gameTime) {
                const targetTile = main.gamePositionToTilePosition(player.position);
                try trippleData.airAttackPosition.append(.{ .hitTime = state.gameTime + trippleData.airAttackDelay, .targetPosition = targetTile });
                trippleData.airAttackRepeat -|= 1;
                if (trippleData.airAttackRepeat == 0) {
                    trippleData.airAttackPlayerOnStationary = null;
                } else {
                    trippleData.airAttackRepeatNextTime = state.gameTime + trippleData.airAttackDelay;
                }
            }
        }
    }
    var airAttackIndex: usize = 0;
    while (trippleData.airAttackPosition.items.len > airAttackIndex) {
        const attackTile = trippleData.airAttackPosition.items[airAttackIndex];
        if (attackTile.hitTime <= state.gameTime) {
            for (state.players.items) |*player| {
                const playerTile = main.gamePositionToTilePosition(player.position);
                if (playerTile.x == attackTile.targetPosition.x and playerTile.y == attackTile.targetPosition.y) {
                    try main.playerHit(player, state);
                }
            }
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_BALL_GROUND_INDICIES[0..], 0, 1);
            _ = trippleData.airAttackPosition.swapRemove(airAttackIndex);
        } else {
            airAttackIndex += 1;
        }
    }
}

fn isBossHit(boss: *bossZig.Boss, player: *main.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    const trippleData = &boss.typeData.tripple;
    _ = cutRotation;
    const bossTile = main.gamePositionToTilePosition(boss.position);
    if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
        const shieldCount = getShieldCount(state);
        const hitCompareDirection = @mod(hitDirection + 2, 4);
        const shield1Direction = trippleData.direction;
        const shield2Direction = @mod(trippleData.direction + 1, 4);
        const shield3Direction = @mod(trippleData.direction + 3, 4);
        const hitShield = shieldCount > 0 and hitCompareDirection == shield1Direction or shieldCount > 1 and hitCompareDirection == shield2Direction or shieldCount > 2 and hitCompareDirection == shield3Direction;
        try executeAttack(boss, player, hitDirection, state);
        if (hitShield) {
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_ENEMY_BLOCK_INDICIES[0..], 0, 1);
        } else {
            boss.hp -|= main.getPlayerDamage(player);
            if (boss.hp == 0) {
                for (state.bosses.items) |*otherBoss| {
                    if (otherBoss.typeData == .tripple) {
                        if (trippleData.enabledAirAttack) otherBoss.typeData.tripple.enabledAirAttack = true;
                        if (trippleData.enabledShuriken) otherBoss.typeData.tripple.enabledShuriken = true;
                        if (trippleData.enabledFire) otherBoss.typeData.tripple.enabledFire = true;
                    }
                }
            } else {
                boss.position = getRandomFreePosition(state);
            }
            return true;
        }
    }
    return false;
}

fn executeAttack(boss: *bossZig.Boss, player: *main.Player, hitDirection: u8, state: *main.GameState) !void {
    const trippleData = &boss.typeData.tripple;
    if (trippleData.enabledAirAttack and trippleData.airAttackPlayerOnStationary == null) {
        trippleData.airAttackPlayerOnStationary = player;
        trippleData.airAttackRepeat += trippleData.attacksPerBeingHit;
    }
    if (trippleData.enabledFire) {
        const hitDirectionTurned = @mod(hitDirection + 2, 4);
        const stepDirection = movePieceZig.getStepDirection(hitDirectionTurned);
        for (0..trippleData.attacksPerBeingHit) |i| {
            const fi: f32 = @floatFromInt(i + 1);
            try enemyObjectFireZig.spawnFire(.{
                .x = boss.position.x + stepDirection.x * main.TILESIZE * fi,
                .y = boss.position.y + stepDirection.y * main.TILESIZE * fi,
            }, trippleData.fireDuration, true, state);
        }
    }
    if (trippleData.enabledShuriken) {
        trippleData.shurikenRepeat += trippleData.attacksPerBeingHit;
        if (trippleData.shurikenThrowTime == null) {
            trippleData.shurikenThrowTime = state.gameTime + trippleData.shurikenDelay;
        }
    }
}

fn getRandomFreePosition(state: *main.GameState) main.Position {
    var randomPos: main.Position = .{ .x = 0, .y = 0 };
    var validPosition = false;
    searchPos: while (!validPosition) {
        const mapTileRadiusI32 = @as(i32, @intCast(state.mapData.tileRadius));
        randomPos.x = @floatFromInt(std.crypto.random.intRangeAtMost(i32, -mapTileRadiusI32, mapTileRadiusI32) * main.TILESIZE);
        randomPos.y = @floatFromInt(std.crypto.random.intRangeAtMost(i32, -mapTileRadiusI32, mapTileRadiusI32) * main.TILESIZE);
        for (state.bosses.items) |bossSingle| {
            if (main.calculateDistance(randomPos, bossSingle.position) < main.TILESIZE * 3) {
                continue :searchPos;
            }
        }
        for (state.players.items) |player| {
            if (main.calculateDistance(randomPos, player.position) < main.TILESIZE) {
                continue :searchPos;
            }
        }
        validPosition = true;
    }
    return randomPos;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) !void {
    const trippleData = boss.typeData.tripple;
    if (trippleData.shurikenThrowTime) |throwTime| {
        const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(throwTime - state.gameTime)) / @as(f32, @floatFromInt(trippleData.shurikenDelay))));
        for (0..4) |direction| {
            const moveStep = movePieceZig.getStepDirection(@intCast(direction));
            const attackPosition: main.Position = .{
                .x = boss.position.x + moveStep.x * main.TILESIZE,
                .y = boss.position.y + moveStep.y * main.TILESIZE,
            };
            enemyVulkanZig.addWarningShurikenSprites(attackPosition, fillPerCent, state);
        }
    }
    for (trippleData.airAttackPosition.items) |attackTile| {
        const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(attackTile.hitTime - state.gameTime)) / @as(f32, @floatFromInt(trippleData.airAttackDelay))));
        enemyVulkanZig.addWarningTileSprites(.{
            .x = @as(f32, @floatFromInt(attackTile.targetPosition.x)) * main.TILESIZE,
            .y = @as(f32, @floatFromInt(attackTile.targetPosition.y)) * main.TILESIZE,
        }, fillPerCent, state);
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const trippleData = boss.typeData.tripple;
    const rotation: f32 = @as(f32, @floatFromInt(trippleData.direction)) * std.math.pi / 2.0;
    paintVulkanZig.verticesForComplexSpriteWithRotate(
        boss.position,
        boss.imageIndex,
        rotation,
        1,
        state,
    );
    const shieldCount = getShieldCount(state);
    const directionChange = [_]u8{ 0, 1, 3 };
    for (0..shieldCount) |i| {
        const shieldDirection: u8 = @mod(trippleData.direction + directionChange[i], 4);
        const shieldRotation: f32 = @as(f32, @floatFromInt(shieldDirection)) * std.math.pi / 2.0;
        const stepDirection = movePieceZig.getStepDirection(shieldDirection);
        paintVulkanZig.verticesForComplexSpriteWithRotate(
            .{ .x = boss.position.x + stepDirection.x * main.TILESIZE / 2, .y = boss.position.y + stepDirection.y * main.TILESIZE / 2 },
            imageZig.IMAGE_SHIELD,
            shieldRotation,
            1,
            state,
        );
    }
    for (trippleData.airAttackPosition.items) |airAttack| {
        const timeUntilHit: f32 = @floatFromInt(airAttack.hitTime - state.gameTime);
        const targetPosition = main.tilePositionToGamePosition(airAttack.targetPosition);
        const cannonBallPosiion: main.Position = .{
            .x = targetPosition.x,
            .y = targetPosition.y - timeUntilHit / 2,
        };
        paintVulkanZig.verticesForComplexSpriteDefault(cannonBallPosiion, imageZig.IMAGE_CANNON_BALL, state);
    }
}

fn getShieldCount(state: *main.GameState) usize {
    return @max(1, @min(3, 4 - state.bosses.items.len));
}
