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

pub fn createSpawnEnemyEntryEnemy() enemyZig.Enemy {
    return .{
        .imageIndex = imageZig.IMAGE_EVIL_TREE,
        .position = .{ .x = 0, .y = 0 },
        .enemyTypeData = .{
            .waller = .{},
        },
    };
}

pub fn tick(enemy: *enemyZig.Enemy, state: *main.GameState) !void {
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
                mapTileZig.setMapTilePositionType(tilePosition, .wall, &state.mapData);
                data.placedWall = true;
            }
            data.attackTime = null;
        }
    } else {
        if (data.placedWall) {
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
                const randomDirectionIndex = std.crypto.random.intRangeLessThan(u8, 0, validHitDirectionCount);
                data.direction = validHitDirections[randomDirectionIndex].?;
            }
        } else {
            //
        }
        data.attackTime = state.gameTime + data.delay;
    }
}

pub fn setupVerticesGround(enemy: *enemyZig.Enemy, state: *main.GameState) void {
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
