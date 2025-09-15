const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");
const enemyObjectProjectileZig = @import("../enemy/enemyObjectProjectile.zig");
const mapTileZig = @import("../mapTile.zig");

pub const BossSplitData = struct {
    splits: std.ArrayList(BossSplitPartData),
    shurikenMoveInterval: i32 = 1000,
    maxSplits: u8,
};

const BossSplitPartData = struct {
    inAir: bool = false,
    position: main.Position,
    attackChargeTime: i16 = 3000,
    attackVisualizeTime: i16 = 2000,
    waitAfterAttackTime: i16 = 3000,
    waitUntilTime: ?i64 = null,
    nextAttackTime: ?i64 = null,
    flyToPosition: ?main.Position = null,
    cutAtPosition: ?main.Position = null,
    flyCutDuration: i64 = 0,
    flyCutStart: i64 = 0,
    hp: u32,
    splitOnHp: u32,
    remainingSpltits: u32,
};

const BOSS_NAME = "Split";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 20,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
        .deinit = deinit,
    };
}

fn startBoss(state: *main.GameState) !void {
    const scaledHp = bossZig.getHpScalingForLevel(10, state.level);
    const maxSplits = 3;
    var bossTypeData: BossSplitData = .{
        .splits = std.ArrayList(BossSplitPartData).init(state.allocator),
        .maxSplits = maxSplits,
    };
    const bossHp = scaledHp;
    const splitEachXHealth = @divFloor(bossHp, std.math.pow(u32, 2, maxSplits));
    try bossTypeData.splits.append(.{
        .hp = bossHp,
        .splitOnHp = bossHp - splitEachXHealth,
        .remainingSpltits = maxSplits,
        .position = .{ .x = 0, .y = 0 },
    });

    var boss: bossZig.Boss = .{
        .hp = bossHp,
        .maxHp = bossHp,
        .imageIndex = imageZig.IMAGE_BOSS_SLIME,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .typeData = .{ .split = bossTypeData },
    };
    const newGamePlus = main.getNewGamePlus(state.level);
    if (newGamePlus > 0) {
        boss.typeData.split.shurikenMoveInterval = @divFloor(boss.typeData.split.shurikenMoveInterval, @as(i32, @intCast(newGamePlus + 1)));
        scaleSplitToNewGamePlus(&boss.typeData.split.splits.items[0], newGamePlus);
    }
    try state.bosses.append(boss);
    try mapTileZig.setMapRadius(6, state);
    main.adjustZoom(state);
}

fn scaleSplitToNewGamePlus(split: *BossSplitPartData, newGamePlus: u32) void {
    if (newGamePlus == 0) return;
    split.attackChargeTime = @divFloor(split.attackChargeTime, @as(i16, @intCast(newGamePlus + 1)));
    split.attackVisualizeTime = @divFloor(split.attackVisualizeTime, @as(i16, @intCast(newGamePlus + 1)));
    split.waitAfterAttackTime = @divFloor(split.waitAfterAttackTime, @as(i16, @intCast(newGamePlus + 1)));
}

fn deinit(boss: *bossZig.Boss, allocator: std.mem.Allocator) void {
    _ = allocator;
    const splitData = &boss.typeData.split;
    splitData.splits.deinit();
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const splitData = &boss.typeData.split;
    for (splitData.splits.items) |*bossSplit| {
        if (bossSplit.nextAttackTime) |nextAttackTime| {
            if (nextAttackTime <= state.gameTime) {
                for (0..4) |direction| {
                    const stepDirection = movePieceZig.getStepDirection(@intCast(direction));
                    const spawnPosition: main.Position = .{
                        .x = bossSplit.position.x + stepDirection.x * main.TILESIZE,
                        .y = bossSplit.position.y + stepDirection.y * main.TILESIZE,
                    };
                    try enemyObjectProjectileZig.spawnProjectile(
                        spawnPosition,
                        @intCast(direction),
                        imageZig.IMAGE_SHURIKEN,
                        splitData.shurikenMoveInterval,
                        false,
                        state,
                    );
                }
                bossSplit.nextAttackTime = null;
                bossSplit.waitUntilTime = state.gameTime + bossSplit.waitAfterAttackTime;
            }
        } else {
            if (!bossSplit.inAir) {
                if (bossSplit.waitUntilTime) |waitTime| {
                    if (waitTime <= state.gameTime) {
                        bossSplit.waitUntilTime = null;
                    }
                } else {
                    bossSplit.nextAttackTime = state.gameTime + bossSplit.attackChargeTime;
                }
            } else {
                if (bossSplit.flyCutStart + bossSplit.flyCutDuration <= state.gameTime) {
                    bossSplit.inAir = false;
                    bossSplit.position = bossSplit.flyToPosition.?;
                } else {
                    const flyPerCent: f32 = @as(f32, @floatFromInt(state.gameTime - bossSplit.flyCutStart)) / @as(f32, @floatFromInt(bossSplit.flyCutDuration));
                    bossSplit.position = .{
                        .x = bossSplit.cutAtPosition.?.x + (bossSplit.flyToPosition.?.x - bossSplit.cutAtPosition.?.x) * flyPerCent,
                        .y = bossSplit.cutAtPosition.?.y + (bossSplit.flyToPosition.?.y - bossSplit.cutAtPosition.?.y) * flyPerCent,
                    };
                }
            }
        }
    }
}

fn isBossHit(boss: *bossZig.Boss, player: *main.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    _ = hitDirection;
    var somethingHit = false;
    const splitData = &boss.typeData.split;
    var currentIndex: usize = 0;
    while (currentIndex < splitData.splits.items.len) {
        const bossSplit = &splitData.splits.items[currentIndex];
        if (!bossSplit.inAir) {
            const bossTile = main.gamePositionToTilePosition(bossSplit.position);
            if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
                if (bossSplit.hp > 0) {
                    const damage = @min(bossSplit.hp, main.getPlayerDamage(player));
                    boss.hp -|= damage;
                    bossSplit.hp -|= damage;
                    somethingHit = true;
                }
            }
        }
        if (bossSplit.hp == 0) {
            const removed = splitData.splits.swapRemove(currentIndex);
            boss.position = bossSplit.position;
            if (boss.hp > 0) {
                const cutAngle = cutRotation + std.math.pi / 2.0;
                const sizeFactor: f32 = @as(f32, @floatFromInt(bossSplit.remainingSpltits)) / @as(f32, @floatFromInt(splitData.maxSplits));
                const defaultSizeFactor: f32 = 1.0 / @as(f32, @floatFromInt(imageZig.IMAGE_TO_GAME_SIZE)) / 2.0;
                try state.spriteCutAnimations.append(
                    .{
                        .deathTime = state.gameTime,
                        .position = removed.position,
                        .cutAngle = cutAngle,
                        .force = std.crypto.random.float(f32) + 0.2,
                        .colorOrImageIndex = .{ .imageIndex = boss.imageIndex },
                        .imageToGameScaleFactor = sizeFactor * defaultSizeFactor,
                    },
                );
            }
        } else {
            try checkAndSplitBoss(splitData, bossSplit, state);
            currentIndex += 1;
        }
    }
    return somethingHit;
}

fn checkAndSplitBoss(splitData: *BossSplitData, bossSplit: *BossSplitPartData, state: *main.GameState) !void {
    if (bossSplit.hp <= bossSplit.splitOnHp and bossSplit.hp >= 2) {
        bossSplit.flyToPosition = getRandomFlyToPosition(splitData, state);
        var secondRandomFlyTo = getRandomFlyToPosition(splitData, state);
        while (secondRandomFlyTo.x == bossSplit.flyToPosition.?.x and secondRandomFlyTo.y == bossSplit.flyToPosition.?.y) {
            secondRandomFlyTo = getRandomFlyToPosition(splitData, state);
        }
        bossSplit.inAir = true;
        bossSplit.nextAttackTime = null;
        bossSplit.remainingSpltits -|= 1;
        bossSplit.cutAtPosition = bossSplit.position;
        bossSplit.flyCutStart = state.gameTime;
        const distance = main.calculateDistance(bossSplit.position, bossSplit.flyToPosition.?);
        const timePerDistance = 15.0;
        bossSplit.flyCutDuration = @intFromFloat(distance * timePerDistance);
        const hp = @divFloor(bossSplit.hp, 2);
        const splitEachXHealth = @max(1, @divFloor(hp, std.math.pow(u32, 2, bossSplit.remainingSpltits)));
        bossSplit.hp -= hp;
        bossSplit.splitOnHp = bossSplit.hp - splitEachXHealth;
        var bossSplit2: BossSplitPartData = .{
            .position = bossSplit.position,
            .flyToPosition = secondRandomFlyTo,
            .cutAtPosition = bossSplit.position,
            .inAir = true,
            .hp = hp,
            .splitOnHp = hp - splitEachXHealth,
            .remainingSpltits = bossSplit.remainingSpltits,
            .flyCutStart = state.gameTime,
        };
        scaleSplitToNewGamePlus(&bossSplit2, main.getNewGamePlus(state.level));
        const distance2 = main.calculateDistance(bossSplit.position, bossSplit2.flyToPosition.?);
        bossSplit2.flyCutDuration = @intFromFloat(distance2 * timePerDistance);
        try splitData.splits.append(bossSplit2);
    }
}

fn getRandomFlyToPosition(splitData: *BossSplitData, state: *main.GameState) main.Position {
    var randomPos: main.Position = .{ .x = 0, .y = 0 };
    var validPosition = false;
    searchPos: while (!validPosition) {
        const mapTileRadiusI32 = @as(i32, @intCast(state.mapData.tileRadius));
        randomPos.x = @floatFromInt(std.crypto.random.intRangeAtMost(i32, -mapTileRadiusI32, mapTileRadiusI32) * main.TILESIZE);
        randomPos.y = @floatFromInt(std.crypto.random.intRangeAtMost(i32, -mapTileRadiusI32, mapTileRadiusI32) * main.TILESIZE);
        for (splitData.splits.items) |bossSplit| {
            var splitPosition = bossSplit.position;
            if (bossSplit.inAir) {
                splitPosition = bossSplit.flyToPosition.?;
            }
            if (main.calculateDistance(randomPos, splitPosition) < main.TILESIZE * 3) {
                continue :searchPos;
            }
        }
        validPosition = true;
    }
    return randomPos;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) !void {
    const splitData = boss.typeData.split;
    for (splitData.splits.items) |*bossSplit| {
        if (bossSplit.nextAttackTime) |attackTime| {
            if (attackTime - state.gameTime < bossSplit.attackVisualizeTime) {
                const fillPerCent: f32 = @min(1, @max(0, @as(f32, @floatFromInt(bossSplit.attackVisualizeTime + state.gameTime - attackTime)) / @as(f32, @floatFromInt(bossSplit.attackVisualizeTime))));
                for (0..4) |direction| {
                    const moveStep = movePieceZig.getStepDirection(@intCast(direction));
                    const attackPosition: main.Position = .{
                        .x = bossSplit.position.x + moveStep.x * main.TILESIZE,
                        .y = bossSplit.position.y + moveStep.y * main.TILESIZE,
                    };
                    enemyVulkanZig.addWarningShurikenSprites(attackPosition, fillPerCent, state);
                }
            }
        }
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const splitData = boss.typeData.split;
    for (splitData.splits.items) |bossSplit| {
        var bossPosition = bossSplit.position;
        if (bossSplit.inAir) {
            const flyPerCent: f32 = @as(f32, @floatFromInt(state.gameTime - bossSplit.flyCutStart)) / @as(f32, @floatFromInt(bossSplit.flyCutDuration));
            const hightPerCent = @sin(flyPerCent * std.math.pi);
            bossPosition.y -= hightPerCent * @as(f32, @floatFromInt(bossSplit.flyCutDuration)) / 50;
        }
        if (bossPosition.y != bossSplit.position.y) {
            paintVulkanZig.verticesForComplexSpriteAlpha(.{
                .x = bossSplit.position.x,
                .y = bossSplit.position.y + 5,
            }, imageZig.IMAGE_SHADOW, 0.75, state);
        }
        const sizeFactor: f32 = @as(f32, @floatFromInt(bossSplit.remainingSpltits + 1)) / @as(f32, @floatFromInt(splitData.maxSplits));
        paintVulkanZig.verticesForComplexSprite(
            bossPosition,
            boss.imageIndex,
            sizeFactor,
            sizeFactor,
            1,
            0,
            false,
            false,
            state,
        );
    }
}
