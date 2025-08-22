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
const enemyObjectFireZig = @import("../enemy/enemyObjectFire.zig");

pub const BossFireRollData = struct {
    movePieces: [2]movePieceZig.MovePiece,
    movePieceIndex: usize = 0,
    moveDirection: u8 = 0,
    fireDuration: i32 = 10_000,
};

const BOSS_NAME = "Fire Roll";

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 45,
        .startLevel = startBoss,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
        .deinit = deinit,
        .onPlayerMoved = onPlayerMoved,
    };
}

fn deinit(boss: *bossZig.Boss, allocator: std.mem.Allocator) void {
    const rollData = &boss.typeData.fireRoll;
    for (rollData.movePieces) |movePiece| {
        allocator.free(movePiece.steps);
    }
}

fn onPlayerMoved(boss: *bossZig.Boss, player: *main.Player, state: *main.GameState) !void {
    const data = &boss.typeData.fireRoll;
    _ = player;
    try attackMoveWithFirePlacing(boss, data.movePieces[data.movePieceIndex], data.moveDirection, state);
    try chooseMovePiece(boss, state);
}

fn attackMoveWithFirePlacing(boss: *bossZig.Boss, movePiece: movePieceZig.MovePiece, executeDirection: u8, state: *main.GameState) !void {
    const startPosition: main.TilePosition = main.gamePositionToTilePosition(boss.position);
    try movePieceZig.executeMovePieceWithCallbackPerStep(
        *bossZig.Boss,
        movePiece,
        executeDirection,
        startPosition,
        boss,
        attackMoveWithFirePlacingCallback,
        state,
    );
}

fn attackMoveWithFirePlacingCallback(hitPosition: main.TilePosition, visualizedDirection: u8, boss: *bossZig.Boss, state: *main.GameState) !void {
    try movePieceZig.moveEnemyAndCheckPlayerHitOnMoveStep(hitPosition, visualizedDirection, &boss.position, state);
    const data = &boss.typeData.fireRoll;
    try enemyObjectFireZig.spawnFire(boss.position, data.fireDuration, state);
}

fn startBoss(state: *main.GameState) !void {
    try state.bosses.append(.{
        .hp = 10,
        .maxHp = 10,
        .imageIndex = imageZig.IMAGE_BOSS_FIREROLL,
        .position = .{ .x = 0, .y = 0 },
        .name = BOSS_NAME,
        .typeData = .{ .fireRoll = .{
            .movePieces = .{
                try movePieceZig.createRandomMovePiece(state.allocator),
                try movePieceZig.createRandomMovePiece(state.allocator),
            },
        } },
    });
    try mapTileZig.setMapRadius(6, state);
    main.adjustZoom(state);
}

fn chooseMovePiece(boss: *bossZig.Boss, state: *main.GameState) !void {
    const data = &boss.typeData.fireRoll;
    data.movePieceIndex = std.crypto.random.intRangeLessThan(usize, 0, data.movePieces.len);
    const movePiece = data.movePieces[data.movePieceIndex];
    const gridBorder: f32 = @floatFromInt(state.mapData.tileRadius * main.TILESIZE);
    var validMovePosition = false;
    while (!validMovePosition) {
        var bossPositionAfterPiece = boss.position;
        data.moveDirection = std.crypto.random.intRangeLessThan(u8, 0, 4);
        try movePieceZig.movePositionByPiece(&bossPositionAfterPiece, movePiece, data.moveDirection, state);
        validMovePosition = bossPositionAfterPiece.x >= -gridBorder and bossPositionAfterPiece.x <= gridBorder and bossPositionAfterPiece.y >= -gridBorder and bossPositionAfterPiece.y <= gridBorder;
    }
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) !void {
    const data = boss.typeData.fireRoll;
    const bossTile = main.gamePositionToTilePosition(boss.position);
    try enemyVulkanZig.setupVerticesGroundForMovePiece(
        bossTile,
        data.movePieces[data.movePieceIndex],
        data.moveDirection,
        1,
        state,
    );
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    paintVulkanZig.verticesForComplexSpriteDefault(boss.position, boss.imageIndex, state);
}
