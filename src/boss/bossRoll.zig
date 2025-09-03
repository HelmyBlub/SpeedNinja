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

const RollState = enum {
    chooseRandomMovePiece,
    executeMovePiece,
};

const AttackDelayed = struct {
    firedFromPosition: main.TilePosition,
    targetPosition: main.TilePosition,
    hitTime: i64,
};

pub const BossRollData = struct {
    nextStateTime: i64 = 0,
    state: RollState = .chooseRandomMovePiece,
    attackTilePositions: std.ArrayList(AttackDelayed),
    moveChargeTime: i64 = 3000,
    attackDelay: i64 = 4000,
    movePieces: [2]movePieceZig.MovePiece,
    movePieceIndex: usize = 0,
    moveDirection: u8 = 0,
    moveAttackTiles: std.ArrayList(enemyZig.MoveAttackWarningTile),
};

const BOSS_NAME = "Roll";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 15,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
        .deinit = deinit,
        .onPlayerMoved = onPlayerMoved,
    };
}

fn deinit(boss: *bossZig.Boss, allocator: std.mem.Allocator) void {
    const rollData = &boss.typeData.roll;
    for (rollData.movePieces) |movePiece| {
        allocator.free(movePiece.steps);
    }
    rollData.moveAttackTiles.deinit();
    rollData.attackTilePositions.deinit();
}

fn onPlayerMoved(boss: *bossZig.Boss, player: *main.Player, state: *main.GameState) !void {
    const rollData = &boss.typeData.roll;
    try rollData.attackTilePositions.append(AttackDelayed{
        .hitTime = state.gameTime + rollData.attackDelay,
        .targetPosition = main.gamePositionToTilePosition(player.position),
        .firedFromPosition = main.gamePositionToTilePosition(boss.position),
    });
    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_BOSS_ROOL_SHOOT_INDICIES[0..], 0, 1);
}

fn startBoss(state: *main.GameState) !void {
    const scaledHp = bossZig.getHpScalingForLevel(10, state.level);
    try state.bosses.append(.{
        .hp = scaledHp,
        .maxHp = scaledHp,
        .imageIndex = imageZig.IMAGE_BOSS_ROLL,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .typeData = .{ .roll = .{
            .movePieces = .{
                try movePieceZig.createRandomMovePiece(state.allocator),
                try movePieceZig.createRandomMovePiece(state.allocator),
            },
            .moveAttackTiles = std.ArrayList(enemyZig.MoveAttackWarningTile).init(state.allocator),
            .attackTilePositions = std.ArrayList(AttackDelayed).init(state.allocator),
        } },
    });
    try mapTileZig.setMapRadius(6, state);
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const rollData = &boss.typeData.roll;
    _ = passedTime;

    var attackTileIndex: usize = 0;
    while (rollData.attackTilePositions.items.len > attackTileIndex) {
        const attackTile = rollData.attackTilePositions.items[attackTileIndex];
        if (attackTile.hitTime <= state.gameTime) {
            for (state.players.items) |*player| {
                const playerTile = main.gamePositionToTilePosition(player.position);
                if (playerTile.x == attackTile.targetPosition.x and playerTile.y == attackTile.targetPosition.y) {
                    try main.playerHit(player, state);
                }
            }
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_BALL_GROUND_INDICIES[0..], 0, 1);
            _ = rollData.attackTilePositions.swapRemove(attackTileIndex);
        } else {
            attackTileIndex += 1;
        }
    }

    switch (rollData.state) {
        .chooseRandomMovePiece => {
            rollData.movePieceIndex = std.crypto.random.intRangeLessThan(usize, 0, rollData.movePieces.len);
            rollData.state = .executeMovePiece;
            rollData.nextStateTime = state.gameTime + rollData.moveChargeTime;
            const movePiece = rollData.movePieces[rollData.movePieceIndex];
            const gridBorder: f32 = @floatFromInt(state.mapData.tileRadius * main.TILESIZE);
            var validMovePosition = false;
            while (!validMovePosition) {
                var bossPositionAfterPiece = boss.position;
                rollData.moveDirection = std.crypto.random.intRangeLessThan(u8, 0, 4);
                try movePieceZig.movePositionByPiece(&bossPositionAfterPiece, movePiece, rollData.moveDirection, state);
                validMovePosition = bossPositionAfterPiece.x >= -gridBorder and bossPositionAfterPiece.x <= gridBorder and bossPositionAfterPiece.y >= -gridBorder and bossPositionAfterPiece.y <= gridBorder;
            }

            try enemyZig.fillMoveAttackWarningTiles(boss.position, &rollData.moveAttackTiles, movePiece, rollData.moveDirection);
        },
        .executeMovePiece => {
            if (rollData.nextStateTime <= state.gameTime) {
                try movePieceZig.attackMovePieceCheckPlayerHit(&boss.position, rollData.movePieces[rollData.movePieceIndex], rollData.moveDirection, state);
                rollData.state = .chooseRandomMovePiece;
                rollData.moveAttackTiles.clearRetainingCapacity();
            }
        },
    }
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) !void {
    const rollData = boss.typeData.roll;
    for (rollData.attackTilePositions.items) |attackTile| {
        const fillPerCent: f32 = @min(1, @max(0, 1 - @as(f32, @floatFromInt(attackTile.hitTime - state.gameTime)) / @as(f32, @floatFromInt(rollData.attackDelay))));
        enemyVulkanZig.addWarningTileSprites(.{
            .x = @as(f32, @floatFromInt(attackTile.targetPosition.x)) * main.TILESIZE,
            .y = @as(f32, @floatFromInt(attackTile.targetPosition.y)) * main.TILESIZE,
        }, fillPerCent, state);
    }

    if (rollData.state == .executeMovePiece) {
        const fillPerCent: f32 = @min(1, @max(0, 1 - @as(f32, @floatFromInt(rollData.nextStateTime - state.gameTime)) / @as(f32, @floatFromInt(rollData.moveChargeTime))));
        for (rollData.moveAttackTiles.items) |moveAttack| {
            const attackPosition: main.Position = .{
                .x = @as(f32, @floatFromInt(moveAttack.position.x)) * main.TILESIZE,
                .y = @as(f32, @floatFromInt(moveAttack.position.y)) * main.TILESIZE,
            };
            const rotation: f32 = @as(f32, @floatFromInt(moveAttack.direction)) * std.math.pi / 2.0;
            enemyVulkanZig.addRedArrowTileSprites(attackPosition, fillPerCent, rotation, state);
        }
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const rollData = boss.typeData.roll;
    paintVulkanZig.verticesForComplexSpriteDefault(boss.position, boss.imageIndex, state);
    for (rollData.attackTilePositions.items) |attack| {
        if (attack.hitTime > state.gameTime + @divFloor(rollData.attackDelay * 3, 4)) {
            const timePassed: f32 = @floatFromInt(rollData.attackDelay - (attack.hitTime - state.gameTime));
            const cannonBallPosiion: main.Position = .{
                .x = boss.position.x,
                .y = boss.position.y - timePassed / 2,
            };
            paintVulkanZig.verticesForComplexSpriteDefault(cannonBallPosiion, imageZig.IMAGE_CANNON_BALL, state);
        } else if (attack.hitTime >= state.gameTime - @divFloor(rollData.attackDelay * 3, 4)) {
            const timeUntilHit: f32 = @floatFromInt(attack.hitTime - state.gameTime);
            const targetPosition = main.tilePositionToGamePosition(attack.targetPosition);
            const cannonBallPosiion: main.Position = .{
                .x = targetPosition.x,
                .y = targetPosition.y - timeUntilHit / 2,
            };
            paintVulkanZig.verticesForComplexSpriteDefault(cannonBallPosiion, imageZig.IMAGE_CANNON_BALL, state);
        }
    }
}
