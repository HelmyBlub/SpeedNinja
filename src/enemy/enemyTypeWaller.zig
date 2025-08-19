const std = @import("std");
const main = @import("../main.zig");
const enemyZig = @import("enemy.zig");
const movePieceZig = @import("../movePiece.zig");
const imageZig = @import("../image.zig");
const mapTileZig = @import("../mapTile.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");

pub const EnemyTypeWallerData = struct {
    placedWall: bool = false,
    delay: i64 = 3000,
    direction: u8 = 0,
    attackTime: ?i64 = null,
};

pub fn create() enemyZig.EnemyFunctions {
    return enemyZig.EnemyFunctions{
        .createSpawnEnemyEntryEnemy = createSpawnEnemyEntryEnemy,
        .tick = tick,
        .setupVerticesGround = setupVerticesGround,
    };
}

fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_ENEMY_WALLER,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .waller = .{},
        },
    };
}

fn tick(enemy: *enemyZig.Enemy, passedTime: i64, state: *main.GameState) !void {
    _ = passedTime;
    const data = &enemy.enemyTypeData.waller;
    if (data.attackTime) |attackTime| {
        if (attackTime <= state.gameTime) {
            const stepDirection = movePieceZig.getStepDirection(data.direction);
            const hitPosition: main.Position = .{
                .x = enemy.position.x + stepDirection.x * main.TILESIZE,
                .y = enemy.position.y + stepDirection.y * main.TILESIZE,
            };
            try enemyZig.checkPlayerHit(hitPosition, state);
            if (!data.placedWall) {
                const tilePosition = main.gamePositionToTilePosition(hitPosition);
                if (main.isTileEmpty(tilePosition, state)) {
                    mapTileZig.setMapTilePositionType(tilePosition, .wall, &state.mapData);
                }
                data.placedWall = true;
            }
            data.attackTime = null;
        }
    } else {
        const tilePosition = main.gamePositionToTilePosition(enemy.position);
        var validHitDirectionCount: u8 = 0;
        var validHitDirections = [_]?u8{ null, null, null, null };
        if (mapTileZig.getMapTilePositionType(.{ .x = tilePosition.x - 1, .y = tilePosition.y }, &state.mapData) != .wall) {
            validHitDirections[validHitDirectionCount] = movePieceZig.DIRECTION_LEFT;
            validHitDirectionCount += 1;
        }
        if (mapTileZig.getMapTilePositionType(.{ .x = tilePosition.x + 1, .y = tilePosition.y }, &state.mapData) != .wall) {
            validHitDirections[validHitDirectionCount] = movePieceZig.DIRECTION_RIGHT;
            validHitDirectionCount += 1;
        }
        if (mapTileZig.getMapTilePositionType(.{ .x = tilePosition.x, .y = tilePosition.y - 1 }, &state.mapData) != .wall) {
            validHitDirections[validHitDirectionCount] = movePieceZig.DIRECTION_UP;
            validHitDirectionCount += 1;
        }
        if (mapTileZig.getMapTilePositionType(.{ .x = tilePosition.x, .y = tilePosition.y + 1 }, &state.mapData) != .wall) {
            validHitDirections[validHitDirectionCount] = movePieceZig.DIRECTION_DOWN;
            validHitDirectionCount += 1;
        }
        if (validHitDirectionCount > 0) {
            const randomDirectionIndex = std.crypto.random.intRangeLessThan(usize, 0, validHitDirectionCount);
            data.direction = validHitDirections[randomDirectionIndex].?;
        }
        if (!data.placedWall and validHitDirectionCount <= 2) data.placedWall = true;
        if (validHitDirectionCount < 2) {
            removeOneRandomAdjacentWall(tilePosition, state);
        }
        data.attackTime = state.gameTime + data.delay;
    }
}

fn removeOneRandomAdjacentWall(tilePosition: main.TilePosition, state: *main.GameState) void {
    var invalidHitDirectionCount: u8 = 0;
    var invalidHitDirections = [_]?u8{ null, null, null, null };
    if (mapTileZig.getMapTilePositionType(.{ .x = tilePosition.x - 1, .y = tilePosition.y }, &state.mapData) == .wall) {
        invalidHitDirections[invalidHitDirectionCount] = movePieceZig.DIRECTION_LEFT;
        invalidHitDirectionCount += 1;
    }
    if (mapTileZig.getMapTilePositionType(.{ .x = tilePosition.x + 1, .y = tilePosition.y }, &state.mapData) == .wall) {
        invalidHitDirections[invalidHitDirectionCount] = movePieceZig.DIRECTION_RIGHT;
        invalidHitDirectionCount += 1;
    }
    if (mapTileZig.getMapTilePositionType(.{ .x = tilePosition.x, .y = tilePosition.y - 1 }, &state.mapData) == .wall) {
        invalidHitDirections[invalidHitDirectionCount] = movePieceZig.DIRECTION_UP;
        invalidHitDirectionCount += 1;
    }
    if (mapTileZig.getMapTilePositionType(.{ .x = tilePosition.x, .y = tilePosition.y + 1 }, &state.mapData) == .wall) {
        invalidHitDirections[invalidHitDirectionCount] = movePieceZig.DIRECTION_DOWN;
        invalidHitDirectionCount += 1;
    }
    const randomDirectionIndex = std.crypto.random.intRangeLessThan(usize, 0, invalidHitDirectionCount);
    const direction = invalidHitDirections[randomDirectionIndex].?;
    const stepDirection = movePieceZig.getStepDirectionTile(direction);
    const hitTilePosition: main.TilePosition = .{
        .x = tilePosition.x + stepDirection.x,
        .y = tilePosition.y + stepDirection.y,
    };
    mapTileZig.setMapTilePositionType(hitTilePosition, .normal, &state.mapData);
}

fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
    const data = enemy.enemyTypeData.waller;
    if (data.attackTime) |attackTime| {
        const moveStep = movePieceZig.getStepDirection(data.direction);
        const attackPosition: main.Position = .{
            .x = enemy.position.x + moveStep.x * main.TILESIZE,
            .y = enemy.position.y + moveStep.y * main.TILESIZE,
        };
        const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(attackTime - state.gameTime)) / @as(f32, @floatFromInt(data.delay))));
        enemyVulkanZig.addWarningTileSprites(attackPosition, fillPerCent, state);
    }
}
