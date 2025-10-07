const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const enemyZig = @import("../enemy/enemy.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");
const mapTileZig = @import("../mapTile.zig");
const enemyTypeIceAttackZig = @import("../enemy/enemyTypeIceAttack.zig");
const playerZig = @import("../player.zig");

const SnowballState = enum {
    stationary,
    rolling,
};

pub const BossSnowballData = struct {
    nextStateTime: i64 = 0,
    state: SnowballState = .stationary,
    maxEnemyToSpawn: u8 = 19,
    enemyToSpawn: u8 = 19,
    rollDirection: u8 = 0,
    nextRollTime: i64 = 0,
    rollInterval: i32 = 400,
};

const BOSS_NAME = "Snowball";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 35,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
    };
}

fn startBoss(state: *main.GameState) !void {
    const levelScaledHp = bossZig.getHpScalingForLevel(10, state);
    const scaledHp: u32 = levelScaledHp * @as(u32, @intCast(state.players.items.len));
    var snowball: bossZig.Boss = .{
        .hp = scaledHp,
        .maxHp = scaledHp,
        .imageIndex = imageZig.IMAGE_BOSS_SNOWBALL,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .typeData = .{ .snowball = .{} },
    };
    if (state.newGamePlus > 0) {
        snowball.typeData.snowball.rollInterval = @divFloor(snowball.typeData.snowball.rollInterval, @as(i32, @intCast(state.newGamePlus + 1)));
        snowball.typeData.snowball.maxEnemyToSpawn = @min(snowball.typeData.snowball.maxEnemyToSpawn * (state.newGamePlus + 1), 60);
        snowball.typeData.snowball.enemyToSpawn = snowball.typeData.snowball.maxEnemyToSpawn;
    }
    try state.bosses.append(snowball);
    try mapTileZig.setMapRadius(6, 6, state);
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &boss.typeData.snowball;
    if (data.state == .rolling) {
        if (data.nextRollTime <= state.gameTime) {
            const stepDirection = movePieceZig.getStepDirection(data.rollDirection);
            const hitPosition: main.Position = .{
                .x = boss.position.x + stepDirection.x * main.TILESIZE,
                .y = boss.position.y + stepDirection.y * main.TILESIZE,
            };
            try enemyZig.checkStationaryPlayerHit(hitPosition, state);
            boss.position = hitPosition;
            data.nextRollTime = state.gameTime + data.rollInterval;
            const tilePos = main.gamePositionToTilePosition(boss.position);
            const tileType = mapTileZig.getMapTilePositionType(tilePos, &state.mapData);
            if (tileType == .ice) {
                mapTileZig.setMapTilePositionType(tilePos, .normal, &state.mapData, false, state);
            } else if (tileType == .normal) {
                mapTileZig.setMapTilePositionType(tilePos, .ice, &state.mapData, false, state);
            }
            if (!canRollInDirection(boss, data.rollDirection, state)) {
                data.state = .stationary;
            }
        }
    }
}

fn canRollInDirection(boss: *bossZig.Boss, direction: u8, state: *main.GameState) bool {
    const iMapTileRadiusWidth: i32 = @intCast(state.mapData.tileRadiusWidth);
    const iMapTileRadiusHeight: i32 = @intCast(state.mapData.tileRadiusHeight);
    const initialTilePos = main.gamePositionToTilePosition(boss.position);
    const stepDirection = movePieceZig.getStepDirectionTile(direction);
    if (stepDirection.x > 0 and initialTilePos.x >= iMapTileRadiusWidth or stepDirection.x < 0 and initialTilePos.x <= -iMapTileRadiusWidth or
        stepDirection.y > 0 and initialTilePos.y >= iMapTileRadiusHeight or stepDirection.y < 0 and initialTilePos.y <= -iMapTileRadiusHeight)
    {
        return false;
    }
    return true;
}

fn isBossHit(boss: *bossZig.Boss, player: *playerZig.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    _ = cutRotation;
    const data = &boss.typeData.snowball;
    const bossTile = main.gamePositionToTilePosition(boss.position);
    if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
        if (!canRollInDirection(boss, hitDirection, state)) {
            data.state = .stationary;
        } else {
            data.rollDirection = hitDirection;
            if (data.nextRollTime < state.gameTime) data.nextRollTime = state.gameTime + data.rollInterval;
            data.state = .rolling;
        }
        boss.hp -|= playerZig.getPlayerDamage(player);
        try checkSpawnEnemy(boss, state);
        return true;
    }
    return false;
}

fn checkSpawnEnemy(boss: *bossZig.Boss, state: *main.GameState) !void {
    if (boss.hp == 0) return;
    var spawnMore = true;
    while (spawnMore) {
        const data = &boss.typeData.snowball;
        const enemySpawnPerCent: f32 = @as(f32, @floatFromInt(boss.maxHp)) / @as(f32, @floatFromInt(data.maxEnemyToSpawn + 1)) * @as(f32, @floatFromInt(data.enemyToSpawn));
        const spawnOnHp: u32 = @intFromFloat(enemySpawnPerCent);
        if (boss.hp <= spawnOnHp) {
            var enemy = enemyZig.ENEMY_FUNCTIONS.get(.ice).createSpawnEnemyEntryEnemy();
            enemy.position = getRandomFreePosition(state);
            data.enemyToSpawn -|= 1;
            if (state.newGamePlus > 0) {
                if (enemyZig.ENEMY_FUNCTIONS.get(enemy.enemyTypeData).scaleEnemyForNewGamePlus) |scale| scale(&enemy, state.newGamePlus);
            }
            try state.enemyData.enemies.append(enemy);
        } else {
            spawnMore = false;
        }
    }
}

fn getRandomFreePosition(state: *main.GameState) main.Position {
    var randomPos: main.Position = .{ .x = 0, .y = 0 };
    var validPosition = false;
    searchPos: while (!validPosition) {
        const mapTileRadiusXI32 = @as(i32, @intCast(state.mapData.tileRadiusWidth));
        const mapTileRadiusYI32 = @as(i32, @intCast(state.mapData.tileRadiusHeight));
        randomPos.x = @floatFromInt(std.crypto.random.intRangeAtMost(i32, -mapTileRadiusXI32, mapTileRadiusXI32) * main.TILESIZE);
        randomPos.y = @floatFromInt(std.crypto.random.intRangeAtMost(i32, -mapTileRadiusYI32, mapTileRadiusYI32) * main.TILESIZE);
        for (state.bosses.items) |boss| {
            if (main.calculateDistance(randomPos, boss.position) < main.TILESIZE * 3) {
                continue :searchPos;
            }
        }
        for (state.enemyData.enemies.items) |enemy| {
            if (main.calculateDistance(randomPos, enemy.position) < main.TILESIZE) {
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
    const data = &boss.typeData.snowball;
    if (data.state == .rolling) {
        const moveStep = movePieceZig.getStepDirection(data.rollDirection);
        const attackPosition: main.Position = .{
            .x = boss.position.x + moveStep.x * main.TILESIZE,
            .y = boss.position.y + moveStep.y * main.TILESIZE,
        };
        const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(data.nextRollTime - state.gameTime)) / @as(f32, @floatFromInt(data.rollInterval))));
        const rotation: f32 = @as(f32, @floatFromInt(data.rollDirection)) * std.math.pi / 2.0;
        enemyVulkanZig.addRedArrowTileSprites(attackPosition, fillPerCent, rotation, state);
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const divider: f32 = @floatFromInt(boss.typeData.snowball.rollInterval);
    var rotation: f32 = if (boss.typeData.snowball.state == .rolling) @as(f32, @floatFromInt(state.gameTime)) / divider * 2 else 0;
    if (boss.typeData.snowball.rollDirection == movePieceZig.DIRECTION_LEFT) {
        rotation *= -1;
    }
    paintVulkanZig.verticesForComplexSprite(
        boss.position,
        boss.imageIndex,
        1,
        1,
        1,
        rotation,
        false,
        false,
        state,
    );
}
