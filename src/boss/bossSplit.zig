const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");
const enemyProjectileZig = @import("../enemy/enemyProjectile.zig");

pub const BossSplitData = struct {
    splits: std.ArrayList(BossSplitPartData),
};

const BossSplitPartData = struct {
    inAir: bool = false,
    position: main.Position,
    attackChargeTime: i64 = 6000,
    attackVisualizeTime: i64 = 2000,
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

fn startBoss(state: *main.GameState, bossDataIndex: usize) !void {
    var bossTypeData: BossSplitData = .{ .splits = std.ArrayList(BossSplitPartData).init(state.allocator) };
    const bossHp = 10;
    const maxSplits = 3;
    const splitEachXHealth = @divFloor(bossHp, std.math.pow(u32, 2, maxSplits));
    try bossTypeData.splits.append(.{
        .hp = bossHp,
        .splitOnHp = bossHp - splitEachXHealth,
        .remainingSpltits = maxSplits,
        .position = .{ .x = 0, .y = 0 },
    });

    try state.bosses.append(.{
        .hp = bossHp,
        .maxHp = bossHp,
        .imageIndex = imageZig.IMAGE_EVIL_TOWER,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .dataIndex = bossDataIndex,
        .typeData = .{ .split = bossTypeData },
    });
    state.mapTileRadius = 6;
    main.adjustZoom(state);
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
                    try enemyProjectileZig.spawnProjectile(spawnPosition, @intCast(direction), imageZig.IMAGE_SHURIKEN, 1000, state);
                }
                bossSplit.nextAttackTime = null;
            }
        } else {
            if (!bossSplit.inAir) {
                bossSplit.nextAttackTime = state.gameTime + bossSplit.attackChargeTime;
            }
        }
    }
}

fn isBossHit(boss: *bossZig.Boss, hitArea: main.TileRectangle, state: *main.GameState) !bool {
    var somethingHit = false;
    const splitData = &boss.typeData.split;
    var currentIndex: usize = 0;
    while (currentIndex < splitData.splits.items.len) {
        const bossSplit = &splitData.splits.items[currentIndex];
        if (!bossSplit.inAir) {
            const bossTile = main.gamePositionToTilePosition(bossSplit.position);
            if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
                if (bossSplit.hp > 0) {
                    boss.hp -|= 1;
                    bossSplit.hp -|= 1;
                    somethingHit = true;
                }
            }
        }
        if (bossSplit.hp == 0) {
            _ = splitData.splits.swapRemove(currentIndex);
        } else {
            try checkAndSplitBoss(splitData, bossSplit, state);
            currentIndex += 1;
        }
    }
    return somethingHit;
}

fn checkAndSplitBoss(splitData: *BossSplitData, bossSplit: *BossSplitPartData, state: *main.GameState) !void {
    if (bossSplit.hp <= bossSplit.splitOnHp) {
        bossSplit.inAir = true;
        bossSplit.nextAttackTime = null;
        bossSplit.flyToPosition = bossSplit.position;
        bossSplit.flyToPosition.?.x += main.TILESIZE * 2;
        bossSplit.remainingSpltits -|= 1;
        bossSplit.cutAtPosition = bossSplit.position;
        bossSplit.flyCutStart = state.gameTime;
        const distance = main.calculateDistance(bossSplit.position, bossSplit.flyToPosition.?);
        const distancePerTime = 5.0;
        bossSplit.flyCutDuration = @intFromFloat(distance * distancePerTime);
        const hp = @divFloor(bossSplit.hp, 2);
        const splitEachXHealth = @divFloor(hp, std.math.pow(u32, 2, bossSplit.remainingSpltits));
        bossSplit.hp -= hp;
        bossSplit.splitOnHp = bossSplit.hp - splitEachXHealth;
        var bossSplit2: BossSplitPartData = .{
            .position = bossSplit.position,
            .flyToPosition = .{ .x = bossSplit.position.x, .y = bossSplit.position.y + main.TILESIZE },
            .cutAtPosition = bossSplit.position,
            .inAir = true,
            .hp = hp,
            .splitOnHp = hp - splitEachXHealth,
            .remainingSpltits = bossSplit.remainingSpltits,
            .flyCutStart = state.gameTime,
        };
        const distance2 = main.calculateDistance(bossSplit.position, bossSplit2.flyToPosition.?);
        bossSplit2.flyCutDuration = @intFromFloat(distance2 * distancePerTime);
        try splitData.splits.append(bossSplit2);
    }
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) void {
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
            bossPosition.y -= main.TILESIZE / 2;
        }
        if (bossPosition.y != bossSplit.position.y) {
            paintVulkanZig.verticesForComplexSpriteScale(.{
                .x = bossSplit.position.x,
                .y = bossSplit.position.y + 5,
            }, imageZig.IMAGE_SHADOW, &state.vkState.verticeData.spritesComplex, 0.75, state);
        }
        paintVulkanZig.verticesForComplexSpriteDefault(bossPosition, boss.imageIndex, &state.vkState.verticeData.spritesComplex, state);
    }
}
