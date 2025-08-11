const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");
const enemyZig = @import("../enemy/enemy.zig");
const enemyObjectFireZig = @import("../enemy/enemyObjectFire.zig");

pub const BossSnakeData = struct {
    nextMoveTime: i64 = 0,
    fireDuration: i32 = 5200,
    moveInterval: i64 = 400,
    nextMoveDirection: u8,
    snakeBodyParts: std.ArrayList(main.Position),
};

const BOSS_NAME = "Snake";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 25,
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
    const snakeData = &boss.typeData.snake;
    snakeData.snakeBodyParts.deinit();
}

fn startBoss(state: *main.GameState, bossDataIndex: usize) !void {
    var snakeBoss: bossZig.Boss = .{
        .hp = 20,
        .maxHp = 20,
        .imageIndex = imageZig.IMAGE_EVIL_TOWER,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .dataIndex = bossDataIndex,
        .typeData = .{ .snake = .{
            .nextMoveDirection = std.crypto.random.intRangeLessThan(u8, 0, 4),
            .snakeBodyParts = std.ArrayList(main.Position).init(state.allocator),
        } },
    };
    for (0..9) |_| {
        try snakeBoss.typeData.snake.snakeBodyParts.append(.{ .x = 0, .y = 0 });
    }
    try enemyObjectFireZig.spawnFire(snakeBoss.position, snakeBoss.typeData.snake.fireDuration, state);
    try state.bosses.append(snakeBoss);
    state.mapTileRadius = 7;
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const snakeData = &boss.typeData.snake;
    if (snakeData.nextMoveTime <= state.gameTime) {
        const stepDirection = movePieceZig.getStepDirection(snakeData.nextMoveDirection);
        const movePosition: main.Position = .{
            .x = boss.position.x + stepDirection.x * main.TILESIZE,
            .y = boss.position.y + stepDirection.y * main.TILESIZE,
        };
        try enemyZig.checkPlayerHit(movePosition, state);
        try enemyObjectFireZig.spawnFire(movePosition, snakeData.fireDuration, state);
        _ = snakeData.snakeBodyParts.orderedRemove(0);
        try snakeData.snakeBodyParts.append(boss.position);
        boss.position = movePosition;
        snakeData.nextMoveTime = state.gameTime + snakeData.moveInterval;
        var isNextDirectionValied = false;
        const lastDirection = snakeData.nextMoveDirection;
        const border: f32 = @floatFromInt(state.mapTileRadius * main.TILESIZE);
        while (!isNextDirectionValied) {
            snakeData.nextMoveDirection = std.crypto.random.int(u2);
            if (lastDirection == @mod(snakeData.nextMoveDirection + 2, 4)) {
                snakeData.nextMoveDirection = lastDirection; // double probablily for keeping direciton, but no 180 turns
            }
            const nextStepDirection = movePieceZig.getStepDirection(snakeData.nextMoveDirection);
            isNextDirectionValied = nextStepDirection.x < 0 and boss.position.x > -border or
                nextStepDirection.x > 0 and boss.position.x < border or
                nextStepDirection.y < 0 and boss.position.y > -border or
                nextStepDirection.y > 0 and boss.position.y < border;
        }
    }
}

fn isBossHit(boss: *bossZig.Boss, hitArea: main.TileRectangle, cutRotation: f32, state: *main.GameState) !bool {
    const snakeData = &boss.typeData.snake;
    const bossTile = main.gamePositionToTilePosition(boss.position);
    if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
        boss.hp -|= 1;
        try checkLooseBodyPart(boss, boss.position, cutRotation, state);
        return true;
    }
    for (snakeData.snakeBodyParts.items) |snakeBodyPart| {
        const partTile = main.gamePositionToTilePosition(snakeBodyPart);
        if (main.isTilePositionInTileRectangle(partTile, hitArea)) {
            boss.hp -|= 1;
            try checkLooseBodyPart(boss, snakeBodyPart, cutRotation, state);
            return true;
        }
    }
    return false;
}

fn checkLooseBodyPart(boss: *bossZig.Boss, hitPosition: main.Position, cutRotation: f32, state: *main.GameState) !void {
    const snakeData = &boss.typeData.snake;
    const loosePartOnHp: usize = snakeData.snakeBodyParts.items.len * 2;
    if (boss.hp <= loosePartOnHp) {
        _ = snakeData.snakeBodyParts.orderedRemove(0);
        if (boss.hp > 0) {
            try state.spriteCutAnimations.append(
                .{ .deathTime = state.gameTime, .position = hitPosition, .cutAngle = cutRotation, .force = 1.2, .imageIndex = boss.imageIndex },
            );
        }
    }
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) void {
    _ = state;
    const snakeData = boss.typeData.snake;
    _ = snakeData;
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const snakeData = boss.typeData.snake;
    for (snakeData.snakeBodyParts.items) |bodyPart| {
        paintVulkanZig.verticesForComplexSpriteDefault(bodyPart, boss.imageIndex, &state.vkState.verticeData.spritesComplex, state);
    }
    paintVulkanZig.verticesForComplexSpriteDefault(boss.position, boss.imageIndex, &state.vkState.verticeData.spritesComplex, state);
}
