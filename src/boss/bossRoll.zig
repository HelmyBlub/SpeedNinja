const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const enemyZig = @import("../enemy.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");

const RollState = enum {
    chooseRandomMovePiece,
    executeMovePiece,
};

const AttackDelayed = struct {
    position: main.TilePosition,
    hitTime: i64,
};

pub const BossRollData = struct {
    nextStateTime: i64 = 0,
    state: RollState = .chooseRandomMovePiece,
    attackTilePositions: std.ArrayList(AttackDelayed),
    moveChargeTime: i64 = 3000,
    attackDelay: i64 = 4000,
    attackHitTime: ?i64 = null,
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
        .isBossHit = isBossHit,
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
        .position = main.gamePositionToTilePosition(player.position),
    });
}

fn startBoss(state: *main.GameState, bossDataIndex: usize) !void {
    try state.bosses.append(.{
        .hp = 10,
        .maxHp = 10,
        .imageIndex = imageZig.IMAGE_EVIL_TOWER,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .dataIndex = bossDataIndex,
        .typeData = .{ .roll = .{
            .movePieces = .{
                try movePieceZig.createRandomMovePiece(state.allocator),
                try movePieceZig.createRandomMovePiece(state.allocator),
            },
            .moveAttackTiles = std.ArrayList(enemyZig.MoveAttackWarningTile).init(state.allocator),
            .attackTilePositions = std.ArrayList(AttackDelayed).init(state.allocator),
        } },
    });
    state.mapTileRadius = 6;
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
                if (playerTile.x == attackTile.position.x and playerTile.y == attackTile.position.y) {
                    player.hp -|= 1;
                }
            }
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
            const gridBorder: f32 = @floatFromInt(state.mapTileRadius * main.TILESIZE);
            var validMovePosition = false;
            while (!validMovePosition) {
                var bossPositionAfterPiece = boss.position;
                rollData.moveDirection = std.crypto.random.intRangeLessThan(u8, 0, 4);
                movePieceZig.movePositionByPiece(&bossPositionAfterPiece, movePiece, rollData.moveDirection);
                validMovePosition = bossPositionAfterPiece.x > -gridBorder and bossPositionAfterPiece.x < gridBorder and bossPositionAfterPiece.y > -gridBorder and bossPositionAfterPiece.y < gridBorder;
            }

            try enemyZig.fillMoveAttackWarningTiles(boss.position, &rollData.moveAttackTiles, movePiece, rollData.moveDirection);
        },
        .executeMovePiece => {
            if (rollData.nextStateTime <= state.gameTime) {
                movePieceZig.attackMoveCheckPlayerHit(&boss.position, rollData.movePieces[rollData.movePieceIndex], rollData.moveDirection, state);
                rollData.state = .chooseRandomMovePiece;
                rollData.moveAttackTiles.clearRetainingCapacity();
            }
        },
    }
}

fn isBossHit(boss: *bossZig.Boss, hitArea: main.TileRectangle, state: *main.GameState) bool {
    _ = state;
    const bossTile = main.gamePositionToTilePosition(boss.position);
    if (main.isTilePositionInTileRectangle(bossTile, hitArea)) {
        boss.hp -|= 1;
        return true;
    }
    return false;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) void {
    const rollData = boss.typeData.roll;
    for (rollData.attackTilePositions.items) |attackTile| {
        const fillPerCent: f32 = @min(1, @max(0, 1 - @as(f32, @floatFromInt(attackTile.hitTime - state.gameTime)) / @as(f32, @floatFromInt(rollData.attackDelay))));
        enemyVulkanZig.addWarningTileSprites(.{
            .x = @as(f32, @floatFromInt(attackTile.position.x)) * main.TILESIZE,
            .y = @as(f32, @floatFromInt(attackTile.position.y)) * main.TILESIZE,
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
    paintVulkanZig.verticesForComplexSpriteDefault(boss.position, boss.imageIndex, &state.vkState.verticeData.spritesComplex, state);
}
