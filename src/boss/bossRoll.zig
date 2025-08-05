const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const movePieceZig = @import("../movePiece.zig");

const RollState = enum {
    chooseRandomMovePiece,
    executeMovePiece,
};

pub const BossStompData = struct {
    nextStateTime: i64 = 0,
    state: RollState = .chooseRandomMovePiece,
    attackTilePosition: main.TilePosition = .{ .x = 0, .y = 0 },
    attackChargeTime: i64 = 3000,
    attackHitTime: ?i64 = null,
    movePieces: [2]movePieceZig.MovePiece,
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
    };
}

fn deinit(boss: *bossZig.Boss, allocator: std.mem.Allocator) void {
    const rollData = &boss.typeData.roll;
    for (rollData.movePieces) |movePiece| {
        allocator.free(movePiece.steps);
    }
}

fn startBoss(state: *main.GameState, bossDataIndex: usize) !void {
    try state.bosses.append(.{
        .hp = 10,
        .maxHp = 10,
        .imageIndex = imageZig.IMAGE_EVIL_TOWER,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .dataIndex = bossDataIndex,
        .typeData = .{ .roll = .{ .movePieces = .{
            try movePieceZig.createRandomMovePiece(state.allocator),
            try movePieceZig.createRandomMovePiece(state.allocator),
        } } },
    });
    state.mapTileRadius = 6;
    main.adjustZoom(state);
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const rollData = &boss.typeData.roll;
    _ = passedTime;
    if (rollData.attackHitTime) |attackHitTime| {
        if (attackHitTime <= state.gameTime) {
            for (state.players.items) |*player| {
                const playerTile = main.gamePositionToTilePosition(player.position);
                if (playerTile.x == rollData.attackTilePosition.x and playerTile.y == rollData.attackTilePosition.y) {
                    player.hp -|= 1;
                }
            }
            rollData.attackHitTime = null;
        }
    } else {
        rollData.attackHitTime = state.gameTime + rollData.attackChargeTime;
        const randomPlayerIndex: usize = @as(usize, @intFromFloat(std.crypto.random.float(f32) * @as(f32, @floatFromInt(state.players.items.len))));
        rollData.attackTilePosition = main.gamePositionToTilePosition(state.players.items[randomPlayerIndex].position);
    }

    switch (rollData.state) {
        .chooseRandomMovePiece => {
            //
        },
        .executeMovePiece => {
            //
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
    if (rollData.attackHitTime) |attackHitTime| {
        const fillPerCent: f32 = @min(1, @max(0, 1 - @as(f32, @floatFromInt(attackHitTime - state.gameTime)) / @as(f32, @floatFromInt(rollData.attackChargeTime))));
        enemyVulkanZig.addWarningTileSprites(.{
            .x = @as(f32, @floatFromInt(rollData.attackTilePosition.x)) * main.TILESIZE,
            .y = @as(f32, @floatFromInt(rollData.attackTilePosition.y)) * main.TILESIZE,
        }, fillPerCent, state);
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    paintVulkanZig.verticesForComplexSpriteDefault(boss.position, boss.imageIndex, &state.vkState.verticeData.spritesComplex, state);
}
