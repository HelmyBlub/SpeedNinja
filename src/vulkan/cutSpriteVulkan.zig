const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const enemyZig = @import("../enemy/enemy.zig");

const DEATH_DURATION = 3000;

pub fn setupVertices(state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;
    var cutSpriteIndex: usize = 0;

    while (cutSpriteIndex < state.spriteCutAnimations.items.len) {
        if (verticeData.spritesComplex.vertices.len <= verticeData.spritesComplex.verticeCount + 12) break;
        const cutSprite = state.spriteCutAnimations.items[cutSpriteIndex];
        if (cutSprite.deathTime + DEATH_DURATION < state.gameTime) {
            _ = state.spriteCutAnimations.swapRemove(cutSpriteIndex);
            continue;
        }
        setupVerticesForCutSprite(cutSprite, state);
        cutSpriteIndex += 1;
    }
}

fn setupVerticesForCutSprite(cutSprite: main.CutSpriteAnimation, state: *main.GameState) void {
    const normal: main.Position = .{ .x = @cos(cutSprite.cutAngle), .y = @sin(cutSprite.cutAngle) };
    var width: f32 = 0;
    var height: f32 = 0;
    if (cutSprite.colorOrImageIndex == .imageIndex) {
        const imageData = imageZig.IMAGE_DATA[cutSprite.colorOrImageIndex.imageIndex];
        width = @as(f32, @floatFromInt(imageData.width)) * imageData.scale;
        height = @as(f32, @floatFromInt(imageData.height)) * imageData.scale;
    } else {
        width = main.TILESIZE * imageZig.IMAGE_TO_GAME_SIZE;
        height = main.TILESIZE * imageZig.IMAGE_TO_GAME_SIZE;
    }
    const corners: [4]main.Position = [4]main.Position{
        main.Position{ .x = -width, .y = -height },
        main.Position{ .x = width, .y = -height },
        main.Position{ .x = width, .y = height },
        main.Position{ .x = -width, .y = height },
    };

    var distanceToCutLine: [4]f32 = undefined;
    for (0..4) |i| {
        distanceToCutLine[i] = corners[i].x * normal.x + corners[i].y * normal.y;
    }

    // Split lists for each side
    var positionsPositive: [6]main.Position = undefined;
    var positionsNegative: [6]main.Position = undefined;
    var counterP: usize = 0;
    var counterN: usize = 0;

    // Build polygon outline for each half
    for (0..4) |i| {
        const j = (i + 1) % 4;

        const cornerI = corners[i];
        const cornerJ = corners[j];

        const di: f32 = distanceToCutLine[i];
        const dj: f32 = distanceToCutLine[j];

        // Add current vertex to its side
        if (di >= 0.0) {
            positionsPositive[counterP] = cornerI;
            counterP += 1;
        } else {
            positionsNegative[counterN] = cornerI;
            counterN += 1;
        }

        // Check edge crossing
        if (di * dj < 0.0) {
            const t = di / (di - dj);
            const cutPoint: main.Position = .{ .x = cornerI.x + t * (cornerJ.x - cornerI.x), .y = cornerI.y + t * (cornerJ.y - cornerI.y) };
            positionsPositive[counterP] = cutPoint;
            positionsNegative[counterN] = cutPoint;
            counterP += 1;
            counterN += 1;
        }
    }

    const offsetX: f32 = @as(f32, @floatFromInt(state.gameTime - cutSprite.deathTime)) / 32 * cutSprite.force;
    const offsetY: f32 = calculateOffsetY(cutSprite, state);
    const centerOfRotatePositive: main.Position = .{
        .x = (positionsPositive[0].x + positionsPositive[1].x + positionsPositive[2].x + positionsPositive[3].x) / 4,
        .y = (positionsPositive[0].y + positionsPositive[1].y + positionsPositive[2].y + positionsPositive[3].y) / 4,
    };
    const centerOfRotateNegative: main.Position = .{
        .x = (positionsNegative[0].x + positionsNegative[1].x + positionsNegative[2].x + positionsNegative[3].x) / 4,
        .y = (positionsNegative[0].y + positionsNegative[1].y + positionsNegative[2].y + positionsNegative[3].y) / 4,
    };
    addTriangle(.{ positionsPositive[0], positionsPositive[1], positionsPositive[2] }, cutSprite, -offsetX, offsetY, centerOfRotatePositive, state);
    addTriangle(.{ positionsPositive[0], positionsPositive[2], positionsPositive[3] }, cutSprite, -offsetX, offsetY, centerOfRotatePositive, state);
    addTriangle(.{ positionsNegative[0], positionsNegative[1], positionsNegative[2] }, cutSprite, offsetX, offsetY, centerOfRotateNegative, state);
    addTriangle(.{ positionsNegative[0], positionsNegative[2], positionsNegative[3] }, cutSprite, offsetX, offsetY, centerOfRotateNegative, state);
}

fn calculateOffsetY(cutSprite: main.CutSpriteAnimation, state: *main.GameState) f32 {
    const iterations: f32 = @as(f32, @floatFromInt(@abs(state.gameTime - cutSprite.deathTime))) / 8;
    const velocity = cutSprite.force;
    const changePerIteration = 0.01;
    const itEndVelocity = cutSprite.force - changePerIteration * iterations;
    const avgVelocity = (itEndVelocity + velocity) / 2;
    return -avgVelocity * iterations / 2;
}

fn addTriangle(points: [3]main.Position, cutSprite: main.CutSpriteAnimation, offsetX: f32, offsetY: f32, rotateCenter: main.Position, state: *main.GameState) void {
    const scale = cutSprite.imageToGameScaleFactor;
    const verticeData = &state.vkState.verticeData;
    if (verticeData.spritesComplex.vertices.len <= verticeData.spritesComplex.verticeCount + 3) return;
    const alpha = 1 - @as(f32, @floatFromInt(state.gameTime - cutSprite.deathTime)) / DEATH_DURATION;
    const rotate: f32 = @as(f32, @floatFromInt(state.gameTime - cutSprite.deathTime)) / 512 * cutSprite.force;
    var width: f32 = main.TILESIZE;
    var height: f32 = main.TILESIZE;
    if (cutSprite.colorOrImageIndex == .imageIndex) {
        const imageData = imageZig.IMAGE_DATA[cutSprite.colorOrImageIndex.imageIndex];
        width = @as(f32, @floatFromInt(imageData.width)) * imageData.scale;
        height = @as(f32, @floatFromInt(imageData.height)) * imageData.scale;
    } else {
        if (verticeData.triangles.vertices.len <= verticeData.triangles.verticeCount + 3) return;
        width = main.TILESIZE * imageZig.IMAGE_TO_GAME_SIZE;
        height = main.TILESIZE * imageZig.IMAGE_TO_GAME_SIZE;
    }
    const onePixelXInVulkan = 2 / state.windowData.widthFloat;
    const onePixelYInVulkan = 2 / state.windowData.heightFloat;

    for (points) |point| {
        const rotatedPoint = main.rotateAroundPoint(point, rotateCenter, rotate);
        const vulkan: main.Position = .{
            .x = (rotatedPoint.x * scale - state.camera.position.x + cutSprite.position.x + offsetX) * state.camera.zoom * onePixelXInVulkan,
            .y = (rotatedPoint.y * scale - state.camera.position.y + cutSprite.position.y + offsetY) * state.camera.zoom * onePixelYInVulkan,
        };
        if (cutSprite.colorOrImageIndex == .imageIndex) {
            const texPos: main.Position = .{
                .x = (point.x / width + 1) / 2,
                .y = (point.y / height + 1) / 2,
            };
            verticeData.spritesComplex.vertices[verticeData.spritesComplex.verticeCount] = dataVulkanZig.SpriteComplexVertex{
                .pos = .{ vulkan.x, vulkan.y },
                .tex = .{ texPos.x, texPos.y },
                .imageIndex = cutSprite.colorOrImageIndex.imageIndex,
                .alpha = alpha,
            };
            verticeData.spritesComplex.verticeCount += 1;
        } else {
            verticeData.triangles.vertices[verticeData.triangles.verticeCount] = dataVulkanZig.ColoredVertex{
                .pos = .{ vulkan.x, vulkan.y },
                .color = cutSprite.colorOrImageIndex.color,
            };
            verticeData.triangles.verticeCount += 1;
        }
    }
}
