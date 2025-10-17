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
const playerZig = @import("../player.zig");

const PositionDelayed = struct {
    pos: main.TilePosition,
    hitTime: i64,
};

const BombPositionDelayed = struct {
    position: main.Position,
    spawnPosition: main.Position,
    targetPosition: main.Position,
    reachTargetTime: i64,
    explodeTime: ?i64 = null,
};

pub const BossWallerData = struct {
    wallDelay: i64 = 3000,
    wallAttackTiles: std.ArrayList(PositionDelayed),
    bombNextTime: ?i64 = null,
    bombThrowInterval: i32 = 1000,
    bombAoeSize: u8 = 1,
    bombFlyTime: i32 = 1000,
    bombExplodeDelay: i32 = 2000,
    bombs: std.ArrayList(BombPositionDelayed),
    counterForNoneCloseBombs: u8 = 0,
};

const BOSS_NAME = "Waller";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 40,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
        .deinit = deinit,
        .onPlayerMoveEachTile = onPlayerMoveEachTile,
    };
}

fn deinit(boss: *bossZig.Boss, allocator: std.mem.Allocator) void {
    _ = allocator;
    const data = &boss.typeData.waller;
    data.bombs.deinit();
    data.wallAttackTiles.deinit();
}

fn onPlayerMoveEachTile(boss: *bossZig.Boss, player: *playerZig.Player, state: *main.GameState) !void {
    const data = &boss.typeData.waller;
    const tilePosition = main.gamePositionToTilePosition(player.position);
    try data.wallAttackTiles.append(.{
        .pos = tilePosition,
        .hitTime = state.gameTime + data.wallDelay,
    });
}

fn startBoss(state: *main.GameState) !void {
    const levelScaledHp = bossZig.getHpScalingForLevel(10, state);
    const scaledHp: u32 = @intFromFloat(@as(f32, @floatFromInt(levelScaledHp)) * (1.0 + @as(f32, @floatFromInt(state.players.items.len - 1)) * 0.5));
    var boss: bossZig.Boss = .{
        .hp = scaledHp,
        .maxHp = scaledHp,
        .imageIndex = imageZig.IMAGE_BOSS_WALLER,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .typeData = .{ .waller = .{
            .bombs = std.ArrayList(BombPositionDelayed).init(state.allocator),
            .wallAttackTiles = std.ArrayList(PositionDelayed).init(state.allocator),
        } },
    };
    if (state.newGamePlus > 0) {
        boss.typeData.waller.wallDelay = @divFloor(boss.typeData.waller.wallDelay, @as(i32, @intCast(state.newGamePlus + 1)));
        boss.typeData.waller.bombThrowInterval = @divFloor(boss.typeData.waller.bombThrowInterval, @as(i32, @intCast(state.newGamePlus + 1)));
        boss.typeData.waller.bombFlyTime = @divFloor(boss.typeData.waller.bombFlyTime, @as(i32, @intCast(state.newGamePlus + 1)));
        boss.typeData.waller.bombExplodeDelay = @divFloor(boss.typeData.waller.bombExplodeDelay, @as(i32, @intCast(state.newGamePlus + 1)));
    }
    try state.bosses.append(boss);
    try mapTileZig.setMapRadius(6, 6, state);
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &boss.typeData.waller;
    var currentWallAttackIndex: usize = 0;
    while (currentWallAttackIndex < data.wallAttackTiles.items.len) {
        const attackTile = data.wallAttackTiles.items[currentWallAttackIndex];
        if (attackTile.hitTime <= state.gameTime) {
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_WALL_PLACED_INDICIES[0..], 0, 1);
            for (state.players.items) |*player| {
                const playerTile = main.gamePositionToTilePosition(player.position);
                if (playerTile.x == attackTile.pos.x and playerTile.y == attackTile.pos.y) {
                    try playerZig.playerHit(player, state);
                    try state.spriteCutAnimations.append(.{ .colorOrImageIndex = .{ .color = .{ 0, 0, 0, 1 } }, .cutAngle = 0, .deathTime = state.gameTime, .position = player.position, .force = 0.5 });
                }
            }
            if (main.isTileEmpty(attackTile.pos, state)) {
                mapTileZig.setMapTilePositionType(attackTile.pos, .wall, &state.mapData, false, state);
            }
            _ = data.wallAttackTiles.swapRemove(currentWallAttackIndex);
        } else {
            currentWallAttackIndex += 1;
        }
    }

    if (data.bombNextTime != null) {
        if (data.bombNextTime.? <= state.gameTime) {
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_THROW_INDICIES[0..], 0, 0.5 / @as(f32, @floatFromInt(state.newGamePlus + 1)));
            var tileRadiusX = state.mapData.tileRadiusWidth;
            var tileRadiusY = state.mapData.tileRadiusHeight;
            if (data.counterForNoneCloseBombs > 4) {
                tileRadiusX = 1;
                tileRadiusY = 1;
            }

            const lengthX: f32 = @floatFromInt(tileRadiusX * 2 + 1);
            const lengthY: f32 = @floatFromInt(tileRadiusY * 2 + 1);
            const randomTileX: i16 = @as(i16, @intFromFloat(state.seededRandom.random().float(f32) * lengthX - lengthX / 2));
            const randomTileY: i16 = @as(i16, @intFromFloat(state.seededRandom.random().float(f32) * lengthY - lengthY / 2));
            const randomPos: main.Position = .{
                .x = @floatFromInt(randomTileX * main.TILESIZE),
                .y = @floatFromInt(randomTileY * main.TILESIZE),
            };
            try data.bombs.append(.{
                .spawnPosition = boss.position,
                .targetPosition = randomPos,
                .reachTargetTime = state.gameTime + data.bombFlyTime,
                .position = boss.position,
            });
            data.bombNextTime = state.gameTime + data.bombThrowInterval;
            if (@abs(randomTileX) > 1 or @abs(randomTileY) > 1) {
                data.counterForNoneCloseBombs += 1;
            } else {
                data.counterForNoneCloseBombs = 0;
            }
        }
    } else {
        data.bombNextTime = state.gameTime + data.bombThrowInterval;
    }

    var currentBombIndex: usize = 0;
    while (currentBombIndex < data.bombs.items.len) {
        const bomb = &data.bombs.items[currentBombIndex];
        if (bomb.explodeTime == null) {
            if (bomb.reachTargetTime <= state.gameTime) {
                bomb.explodeTime = state.gameTime + data.bombExplodeDelay;
                bomb.position = bomb.targetPosition;
            } else {
                const flyPerCent: f32 = 1 - @as(f32, @floatFromInt(bomb.reachTargetTime - state.gameTime)) / @as(f32, @floatFromInt(data.bombFlyTime));
                bomb.position = .{
                    .x = bomb.spawnPosition.x + (bomb.targetPosition.x - bomb.spawnPosition.x) * flyPerCent,
                    .y = bomb.spawnPosition.y + (bomb.targetPosition.y - bomb.spawnPosition.y) * flyPerCent,
                };
            }
        }
        if (bomb.explodeTime != null and bomb.explodeTime.? <= state.gameTime) {
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_EXPLODE_INDICIES[0..], 0, 1 / @as(f32, @floatFromInt(state.newGamePlus + 1)));
            const bombTilePosition = main.gamePositionToTilePosition(bomb.position);
            const damageTileRectangle: main.TileRectangle = .{
                .pos = .{ .x = bombTilePosition.x - data.bombAoeSize, .y = bombTilePosition.y - data.bombAoeSize },
                .height = data.bombAoeSize * 2 + 1,
                .width = data.bombAoeSize * 2 + 1,
            };
            for (state.players.items) |*player| {
                const playerTile = main.gamePositionToTilePosition(player.position);
                if (main.isTilePositionInTileRectangle(playerTile, damageTileRectangle)) {
                    try playerZig.playerHit(player, state);
                }
            }
            for (0..@intCast(damageTileRectangle.width)) |x| {
                for (0..@intCast(damageTileRectangle.height)) |y| {
                    mapTileZig.setMapTilePositionType(.{ .x = damageTileRectangle.pos.x + @as(i32, @intCast(x)), .y = damageTileRectangle.pos.y + @as(i32, @intCast(y)) }, .normal, &state.mapData, false, state);
                }
            }
            try state.spriteCutAnimations.append(.{ .colorOrImageIndex = .{ .imageIndex = imageZig.IMAGE_BOMB }, .cutAngle = 0, .deathTime = state.gameTime - 200, .position = bomb.position, .force = 0.5 });
            _ = data.bombs.swapRemove(currentBombIndex);
        } else {
            currentBombIndex += 1;
        }
    }
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) !void {
    const data = boss.typeData.waller;
    for (data.wallAttackTiles.items) |attackTile| {
        const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(attackTile.hitTime - state.gameTime)) / @as(f32, @floatFromInt(data.wallDelay))));
        enemyVulkanZig.addWarningTileSprites(.{
            .x = @as(f32, @floatFromInt(attackTile.pos.x)) * main.TILESIZE,
            .y = @as(f32, @floatFromInt(attackTile.pos.y)) * main.TILESIZE,
        }, fillPerCent, state);
    }

    for (data.bombs.items) |bomb| {
        if (bomb.explodeTime) |explodeTime| {
            const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(explodeTime - state.gameTime)) / @as(f32, @floatFromInt(data.bombExplodeDelay))));
            const size: usize = @intCast(data.bombAoeSize * 2 + 1);
            for (0..size) |i| {
                const offsetX: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(i)) - data.bombAoeSize)) * main.TILESIZE;
                for (0..size) |j| {
                    const offsetY: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(j)) - data.bombAoeSize)) * main.TILESIZE;
                    enemyVulkanZig.addWarningTileSprites(.{
                        .x = bomb.position.x + offsetX,
                        .y = bomb.position.y + offsetY,
                    }, fillPerCent, state);
                }
            }
        }
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.waller;
    paintVulkanZig.verticesForComplexSpriteDefault(boss.position, boss.imageIndex, state);

    for (data.bombs.items) |bomb| {
        var bombPosition = bomb.position;
        if (bomb.explodeTime == null) {
            const flyPerCent: f32 = 1 - @as(f32, @floatFromInt(bomb.reachTargetTime - state.gameTime)) / @as(f32, @floatFromInt(data.bombFlyTime));
            const hightPerCent = @sin(flyPerCent * std.math.pi);
            bombPosition.y -= hightPerCent * @as(f32, @floatFromInt(data.bombFlyTime)) / 50;
        }
        if (bombPosition.y != bomb.position.y) {
            paintVulkanZig.verticesForComplexSpriteAlpha(.{
                .x = bomb.position.x,
                .y = bomb.position.y + 5,
            }, imageZig.IMAGE_SHADOW, 0.75, state);
        }
        paintVulkanZig.verticesForComplexSpriteDefault(
            bombPosition,
            imageZig.IMAGE_BOMB,
            state,
        );
    }
}
