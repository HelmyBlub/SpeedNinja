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
const mapTileZig = @import("../mapTile.zig");

pub const BossSnakeData = struct {
    nextMoveTime: i64 = 0,
    fireDuration: i32 = 5200,
    moveInterval: i64 = 400,
    nextMoveDirection: u8,
    snakeBodyParts: std.ArrayList(BodyPart),
};

const BodyPart = struct {
    pos: main.Position,
    rotation: f32,
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

fn startBoss(state: *main.GameState) !void {
    const scaledHp = bossZig.getHpScalingForLevel(20, state.level);
    var snakeBoss: bossZig.Boss = .{
        .hp = scaledHp,
        .maxHp = scaledHp,
        .imageIndex = imageZig.IMAGE_BOSS_SNAKE_HEAD,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .typeData = .{ .snake = .{
            .nextMoveDirection = std.crypto.random.intRangeLessThan(u8, 0, 4),
            .snakeBodyParts = std.ArrayList(BodyPart).init(state.allocator),
        } },
    };
    for (0..9) |_| {
        try snakeBoss.typeData.snake.snakeBodyParts.append(.{ .pos = .{ .x = 0, .y = 0 }, .rotation = 0 });
    }
    try enemyObjectFireZig.spawnFire(snakeBoss.position, snakeBoss.typeData.snake.fireDuration, state);
    try state.bosses.append(snakeBoss);
    try mapTileZig.setMapRadius(6, state);
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const snakeData = &boss.typeData.snake;
    if (snakeData.nextMoveTime <= state.gameTime) {
        try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_BOSS_SNAKE_MOVE_INDICIES[0..], 0, 0.5);
        const stepDirection = movePieceZig.getStepDirection(snakeData.nextMoveDirection);
        const movePosition: main.Position = .{
            .x = boss.position.x + stepDirection.x * main.TILESIZE,
            .y = boss.position.y + stepDirection.y * main.TILESIZE,
        };
        try enemyZig.checkPlayerHit(movePosition, state);
        try enemyObjectFireZig.spawnFire(movePosition, snakeData.fireDuration, state);
        var rotation: f32 = @as(f32, @floatFromInt(snakeData.nextMoveDirection)) * std.math.pi / 2.0;
        if (snakeData.snakeBodyParts.items.len > 0) {
            const beforePart = snakeData.snakeBodyParts.getLast();
            if (beforePart.pos.x != movePosition.x and beforePart.pos.y != movePosition.y) {
                if (@mod(rotation - beforePart.rotation, std.math.pi * 2.0) - std.math.pi < 0) {
                    rotation -= std.math.pi / 4.0;
                } else {
                    rotation += std.math.pi / 4.0;
                }
            }
        }
        _ = snakeData.snakeBodyParts.orderedRemove(0);
        try snakeData.snakeBodyParts.append(.{ .pos = boss.position, .rotation = rotation });
        boss.position = movePosition;
        snakeData.nextMoveTime = state.gameTime + snakeData.moveInterval;
        var isNextDirectionValied = false;
        const lastDirection = snakeData.nextMoveDirection;
        const border: f32 = @floatFromInt(state.mapData.tileRadius * main.TILESIZE);
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

fn isBossHit(boss: *bossZig.Boss, player: *main.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    _ = hitDirection;
    const snakeData = &boss.typeData.snake;
    const bossTile = main.gamePositionToTilePosition(boss.position);
    if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
        boss.hp -|= main.getPlayerDamage(player);
        try checkLooseBodyPart(boss, boss.position, cutRotation, state);
        return true;
    }
    for (snakeData.snakeBodyParts.items) |snakeBodyPart| {
        const partTile = main.gamePositionToTilePosition(snakeBodyPart.pos);
        if (main.isTilePositionInTileRectangle(partTile, hitArea)) {
            boss.hp -|= main.getPlayerDamage(player);
            try checkLooseBodyPart(boss, snakeBodyPart.pos, cutRotation, state);
            return true;
        }
    }
    return false;
}

fn checkLooseBodyPart(boss: *bossZig.Boss, hitPosition: main.Position, cutRotation: f32, state: *main.GameState) !void {
    const snakeData = &boss.typeData.snake;
    const loosePartOnHp: usize = snakeData.snakeBodyParts.items.len * 2;
    if (boss.hp <= loosePartOnHp and snakeData.snakeBodyParts.items.len > 1) {
        _ = snakeData.snakeBodyParts.orderedRemove(0);
        if (boss.hp > 0) {
            try state.spriteCutAnimations.append(
                .{ .deathTime = state.gameTime, .position = hitPosition, .cutAngle = cutRotation, .force = 1.2, .colorOrImageIndex = .{ .imageIndex = imageZig.IMAGE_BOSS_SNAKE_BODY } },
            );
        }
    }
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) !void {
    const snakeData = boss.typeData.snake;
    const moveStep = movePieceZig.getStepDirection(snakeData.nextMoveDirection);
    const attackPosition: main.Position = .{
        .x = boss.position.x + moveStep.x * main.TILESIZE,
        .y = boss.position.y + moveStep.y * main.TILESIZE,
    };
    const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(snakeData.nextMoveTime - state.gameTime)) / @as(f32, @floatFromInt(snakeData.moveInterval))));
    const rotation: f32 = @as(f32, @floatFromInt(snakeData.nextMoveDirection)) * std.math.pi / 2.0;
    enemyVulkanZig.addRedArrowTileSprites(attackPosition, fillPerCent, rotation, state);
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const snakeData = boss.typeData.snake;
    for (snakeData.snakeBodyParts.items) |bodyPart| {
        paintVulkanZig.verticesForComplexSpriteWithRotate(
            bodyPart.pos,
            imageZig.IMAGE_BOSS_SNAKE_BODY,
            bodyPart.rotation,
            1,
            state,
        );
    }
    const rotation: f32 = @as(f32, @floatFromInt(snakeData.nextMoveDirection)) * std.math.pi / 2.0;
    paintVulkanZig.verticesForComplexSpriteWithRotate(
        boss.position,
        boss.imageIndex,
        rotation,
        1,
        state,
    );
}
