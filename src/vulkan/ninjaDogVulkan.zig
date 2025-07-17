const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");

const DEATH_DURATION = 3000;

pub const VkNinjaDogData = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []dataVulkanZig.SpriteComplexVertex = undefined,
    verticeCount: usize = 0,
    pub const MAX_VERTICES = 2000; //TODO not checked limit
};

pub const NinjaDogPaintData = struct {
    bladeDrawn: bool = false,
    bladeRotation: f32 = std.math.pi * 0.25,
    leftPawOffset: main.Position = .{ .x = 0, .y = 0 },
    rightPawOffset: main.Position = .{ .x = 0, .y = 0 },
};

const NinjaDogAnimationState = enum {
    drawBlade,
    bladeToFront,
    bladeToCenter,
};

pub const NinjaDogAnimationStateData = union(NinjaDogAnimationState) {
    drawBlade: NinjaDogAnimationStateDataTypePosition,
    bladeToFront: NinjaDogAnimationStateDataTypeAngle,
    bladeToCenter: NinjaDogAnimationStateDataType2PositionAndAngle,
};

const NinjaDogAnimationStateDataType2PositionAndAngle = struct {
    position1: main.Position,
    position2: main.Position,
    angle: f32,
    startTime: i64,
    duration: i64,
};

const NinjaDogAnimationStateDataTypePosition = struct {
    position: main.Position,
    startTime: i64,
    duration: i64,
};

const NinjaDogAnimationStateDataTypeAngle = struct {
    angle: f32,
    startTime: i64,
    duration: i64,
};

pub fn tickNinjaDogAnimation(state: *main.GameState) void {
    if (state.player.animateData) |animationData| {
        switch (animationData) {
            .drawBlade => |data| {
                const leftHandTarget: main.Position = .{
                    .x = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x - imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x + imageZig.IMAGE_DOG__BLADE_BACK.x,
                    .y = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y - imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.y + imageZig.IMAGE_DOG__BLADE_BACK.y,
                };
                const perCent: f32 = @min(1, @as(f32, @floatFromInt(state.gameTime - data.startTime)) / @as(f32, @floatFromInt(data.duration)));
                state.player.ninjaDogPaintData.leftPawOffset = .{
                    .x = data.position.x + (leftHandTarget.x - data.position.x) * perCent,
                    .y = data.position.y + (leftHandTarget.y - data.position.y) * perCent,
                };
                if (perCent >= 1) {
                    state.player.animateData = .{
                        .bladeToFront = .{ .angle = state.player.ninjaDogPaintData.bladeRotation, .duration = 1000, .startTime = state.gameTime },
                    };
                }
            },
            .bladeToFront => |data| {
                const perCent: f32 = @min(1, @as(f32, @floatFromInt(state.gameTime - data.startTime)) / @as(f32, @floatFromInt(data.duration)));
                const targetAngle = std.math.pi * -0.75;
                state.player.ninjaDogPaintData.bladeRotation = data.angle + (targetAngle - data.angle) * perCent;
                if (perCent >= 1) {
                    state.player.ninjaDogPaintData.bladeDrawn = true;
                    state.player.animateData = .{
                        .bladeToCenter = .{
                            .angle = state.player.ninjaDogPaintData.bladeRotation,
                            .duration = 1000,
                            .startTime = state.gameTime,
                            .position1 = state.player.ninjaDogPaintData.leftPawOffset,
                            .position2 = state.player.ninjaDogPaintData.rightPawOffset,
                        },
                    };
                }
            },
            .bladeToCenter => |data| {
                const perCent: f32 = @max(@min(1, @as(f32, @floatFromInt(state.gameTime - data.startTime)) / @as(f32, @floatFromInt(data.duration))), 0);
                const targetAngle = std.math.pi * 1.5;
                const leftHandTarget: main.Position = .{
                    .x = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x - imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x + imageZig.IMAGE_DOG__BLADE_CENTER_HOLD.x,
                    .y = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y - imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.y + imageZig.IMAGE_DOG__BLADE_CENTER_HOLD.y,
                };
                const rightHandTarget: main.Position = .{
                    .x = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x - imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.x + imageZig.IMAGE_DOG__BLADE_CENTER_HOLD.x,
                    .y = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y - imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.y + imageZig.IMAGE_DOG__BLADE_CENTER_HOLD.y,
                };
                state.player.ninjaDogPaintData.leftPawOffset = .{
                    .x = data.position1.x + (leftHandTarget.x - data.position1.x) * perCent,
                    .y = data.position1.y + (leftHandTarget.y - data.position1.y) * perCent,
                };
                state.player.ninjaDogPaintData.rightPawOffset = .{
                    .x = data.position2.x + (rightHandTarget.x - data.position2.x) * perCent,
                    .y = data.position2.y + (rightHandTarget.y - data.position2.y) * perCent,
                };
                state.player.ninjaDogPaintData.bladeRotation = data.angle + (targetAngle - data.angle) * perCent;
                if (perCent >= 1) {
                    state.player.animateData = null;
                }
            },
        }
    }
}

fn setupVertices(state: *main.GameState) !void {
    const ninjaDogData = &state.vkState.ninjaDogData;
    ninjaDogData.verticeCount = 0;

    var currentAfterImageIndex: usize = 0;
    while (currentAfterImageIndex < state.player.afterImages.items.len) {
        if (ninjaDogData.verticeCount + 1 >= ninjaDogData.vertices.len) break;
        const afterImage = state.player.afterImages.items[currentAfterImageIndex];
        if (afterImage.deleteTime < state.gameTime) {
            _ = state.player.afterImages.swapRemove(currentAfterImageIndex);
            continue;
        }
        drawNinjaDog(afterImage.position, afterImage.paintData, state);
        currentAfterImageIndex += 1;
    }

    drawNinjaDog(state.player.position, state.player.ninjaDogPaintData, state);

    try setupVertexDataForGPU(&state.vkState);
}

pub fn drawNinjaDog(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const imageDataDog = imageZig.IMAGE_DATA[imageZig.IMAGE_DOG];
    if (!paintData.bladeDrawn) {
        const bladeBackPosition: main.Position = .{
            .x = position.x + (imageZig.IMAGE_DOG__BLADE_BACK.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
            .y = position.y + (imageZig.IMAGE_DOG__BLADE_BACK.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        };
        addTiranglesForSprite(bladeBackPosition, imageZig.IMAGE_BLADE__HAND_HOLD_POINT, imageZig.IMAGE_BLADE, paintData.bladeRotation, null, null, state);
    }
    addTiranglesForSprite(position, imageZig.IMAGE_DOG__CENTER, imageZig.IMAGE_DOG, 0, null, null, state);
    const leftArmSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    const leftArmValues = calcScalingAndRotation(imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT, imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT, paintData.leftPawOffset);
    addTiranglesForSprite(
        leftArmSpritePosition,
        imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT,
        imageZig.IMAGE_NINJA_DOG_PAW,
        leftArmValues.angle,
        imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT,
        .{ .x = 1, .y = leftArmValues.scale },
        state,
    );
    const rightArmSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    const rightArmValues = calcScalingAndRotation(imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT, imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT, paintData.rightPawOffset);
    addTiranglesForSprite(
        rightArmSpritePosition,
        imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT,
        imageZig.IMAGE_NINJA_DOG_PAW,
        rightArmValues.angle,
        imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT,
        .{ .x = 1, .y = rightArmValues.scale },
        state,
    );
    if (paintData.bladeDrawn) {
        const leftHandBladePosition: main.Position = .{
            .x = leftArmSpritePosition.x + (imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x - imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x + paintData.leftPawOffset.x) / imageZig.IMAGE_TO_GAME_SIZE,
            .y = leftArmSpritePosition.y + (imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y - imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y + paintData.leftPawOffset.y) / imageZig.IMAGE_TO_GAME_SIZE,
        };
        addTiranglesForSprite(
            leftHandBladePosition,
            imageZig.IMAGE_BLADE__HAND_HOLD_POINT,
            imageZig.IMAGE_BLADE,
            paintData.bladeRotation,
            imageZig.IMAGE_BLADE__HAND_HOLD_POINT,
            null,
            state,
        );
    }
}

pub fn swordHandsCentered(state: *main.GameState) void {
    if (state.player.animateData == null and state.player.ninjaDogPaintData.bladeDrawn == false) {
        state.player.animateData = .{ .drawBlade = .{
            .duration = 500,
            .position = state.player.ninjaDogPaintData.leftPawOffset,
            .startTime = state.gameTime,
        } };
    }
}

pub fn bladeSlashAnimate(state: *main.GameState) void {
    if (state.player.animateData != null) state.player.animateData = null;
    const pawAngle = @mod(state.player.ninjaDogPaintData.bladeRotation + std.math.pi, std.math.pi * 2);
    setPawAndBladeAngle(pawAngle, state);
}

pub fn movedAnimate(direction: u8, state: *main.GameState) void {
    const handDirection = direction + 2;
    const baseAngle: f32 = @as(f32, @floatFromInt(handDirection)) * std.math.pi * 0.5;
    if (state.player.animateData != null) state.player.animateData = null;
    const rand = std.crypto.random;
    const randomPawAngle = @mod(rand.float(f32) * std.math.pi / 2.0 - std.math.pi / 4.0 + baseAngle, std.math.pi * 2);
    setPawAndBladeAngle(randomPawAngle, state);
}

fn setPawAndBladeAngle(angle: f32, state: *main.GameState) void {
    state.player.ninjaDogPaintData.leftPawOffset = .{
        .x = @cos(angle) * 40 - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x + imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x,
        .y = @sin(angle) * 40 - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y + imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y,
    };
    state.player.ninjaDogPaintData.rightPawOffset = .{
        .x = state.player.ninjaDogPaintData.leftPawOffset.x + imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x - imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.x,
        .y = state.player.ninjaDogPaintData.leftPawOffset.y,
    };
    state.player.ninjaDogPaintData.bladeDrawn = true;
    state.player.ninjaDogPaintData.bladeRotation = angle;
}

pub fn moveHandToCenter(state: *main.GameState) void {
    state.player.animateData = .{ .bladeToCenter = .{
        .angle = state.player.ninjaDogPaintData.bladeRotation,
        .duration = 1000,
        .position1 = state.player.ninjaDogPaintData.leftPawOffset,
        .position2 = state.player.ninjaDogPaintData.rightPawOffset,
        .startTime = state.gameTime + 500,
    } };
}

pub fn addAfterImages(stepCount: usize, stepDirection: main.Position, player: main.Player, state: *main.GameState) !void {
    for (0..stepCount) |i| {
        try state.player.afterImages.append(.{
            .deleteTime = state.gameTime + 75 + @as(i64, @intCast(i)) * 10,
            .position = .{
                .x = state.player.position.x + stepDirection.x * @as(f32, @floatFromInt(i)) * main.TILESIZE,
                .y = state.player.position.y + stepDirection.y * @as(f32, @floatFromInt(i)) * main.TILESIZE,
            },
            .paintData = player.ninjaDogPaintData,
        });
    }
}

fn calcScalingAndRotation(baseAnker: main.Position, zeroOffset: main.Position, targetOffset: main.Position) struct { angle: f32, scale: f32 } {
    const zeroAndTargetOffset: main.Position = .{ .x = zeroOffset.x + targetOffset.x, .y = zeroOffset.y + targetOffset.y };
    const distance = main.calculateDistance(baseAnker, zeroOffset);
    const distance2 = main.calculateDistance(baseAnker, zeroAndTargetOffset);
    const scale: f32 = distance2 / distance;
    const angle = angleAtB(zeroOffset, baseAnker, zeroAndTargetOffset);
    return .{ .angle = angle, .scale = scale };
}

fn angleAtB(a: main.Position, b: main.Position, c: main.Position) f32 {
    const vectorBA = main.Position{
        .x = a.x - b.x,
        .y = a.y - b.y,
    };
    const vectorBC = main.Position{
        .x = c.x - b.x,
        .y = c.y - b.y,
    };

    const dot = vectorBA.x * vectorBC.x + vectorBA.y * vectorBC.y;
    const cross = vectorBA.x * vectorBC.y - vectorBA.y * vectorBC.x;
    return std.math.atan2(cross, dot);
}

/// rotatePoint = image coordinates
fn addTiranglesForSprite(paintPosition: main.Position, imageAnkerPosition: main.Position, imageIndex: u8, rotateAngle: f32, rotatePoint: ?main.Position, optScale: ?main.Position, state: *main.GameState) void {
    const scale: main.Position = if (optScale) |s| s else .{ .x = 1, .y = 1 };
    const ninjaDogData = &state.vkState.ninjaDogData;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const imageData = imageZig.IMAGE_DATA[imageIndex];
    const halfSizeWidth: f32 = @as(f32, @floatFromInt(imageData.width)) / imageZig.IMAGE_TO_GAME_SIZE / 2 * scale.x;
    const halfSizeHeigh: f32 = @as(f32, @floatFromInt(imageData.height)) / imageZig.IMAGE_TO_GAME_SIZE / 2 * scale.y;
    const imageAnkerXHalf = (@as(f32, @floatFromInt(imageData.width)) / 2 - imageAnkerPosition.x) / imageZig.IMAGE_TO_GAME_SIZE * scale.x;
    const imageAnkerYHalf = (@as(f32, @floatFromInt(imageData.height)) / 2 - imageAnkerPosition.y) / imageZig.IMAGE_TO_GAME_SIZE * scale.y;
    const corners: [4]main.Position = [4]main.Position{
        main.Position{ .x = -halfSizeWidth + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = -halfSizeWidth + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
    };
    const verticeOrder = [_]usize{ 0, 1, 2, 0, 2, 3 };
    for (verticeOrder) |verticeIndex| {
        const cornerPosOffset = corners[verticeIndex];
        const rotatePivot: main.Position = if (rotatePoint) |p| .{
            .x = (p.x - @as(f32, @floatFromInt(imageData.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE * scale.x + imageAnkerXHalf,
            .y = (p.y - @as(f32, @floatFromInt(imageData.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE * scale.y + imageAnkerYHalf,
        } else .{ .x = 0, .y = 0 };
        const rotatedOffset = paintVulkanZig.rotateAroundPoint(cornerPosOffset, rotatePivot, rotateAngle);
        const vulkan: main.Position = .{
            .x = (rotatedOffset.x - state.camera.position.x + paintPosition.x) * state.camera.zoom * onePixelXInVulkan,
            .y = (rotatedOffset.y - state.camera.position.y + paintPosition.y) * state.camera.zoom * onePixelYInVulkan,
        };
        const texPos: [2]f32 = .{
            if (cornerPosOffset.x < 0) 0 else 1,
            if (cornerPosOffset.y < 0) 0 else 1,
        };
        ninjaDogData.vertices[ninjaDogData.verticeCount] = dataVulkanZig.SpriteComplexVertex{
            .pos = .{ vulkan.x, vulkan.y },
            .imageIndex = imageIndex,
            .alpha = 1,
            .tex = texPos,
        };
        ninjaDogData.verticeCount += 1;
    }
}

pub fn create(state: *main.GameState) !void {
    try createVertexBuffer(&state.vkState, state.allocator);
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    const ninjaDog = vkState.ninjaDogData;
    vk.vkDestroyBuffer.?(vkState.logicalDevice, ninjaDog.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, ninjaDog.vertexBufferMemory, null);
    allocator.free(ninjaDog.vertices);
}

fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    const ninjaDog = vkState.ninjaDogData;
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, ninjaDog.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.SpriteComplexVertex) * ninjaDog.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpu_vertices: [*]dataVulkanZig.SpriteComplexVertex = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, ninjaDog.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, ninjaDog.vertexBufferMemory);
}

pub fn recordCommandBuffer(commandBuffer: vk.VkCommandBuffer, state: *main.GameState) !void {
    try setupVertices(state);
    const vkState = &state.vkState;

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.spriteComplex);
    const vertexBuffers: [1]vk.VkBuffer = .{vkState.ninjaDogData.vertexBuffer};
    const offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(vkState.ninjaDogData.verticeCount), 1, 0, 0);
}

fn createVertexBuffer(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    vkState.ninjaDogData.vertices = try allocator.alloc(dataVulkanZig.SpriteComplexVertex, VkNinjaDogData.MAX_VERTICES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.SpriteComplexVertex) * vkState.ninjaDogData.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.ninjaDogData.vertexBuffer,
        &vkState.ninjaDogData.vertexBufferMemory,
        vkState,
    );
}
