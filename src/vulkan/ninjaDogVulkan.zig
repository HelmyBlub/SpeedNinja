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
    pub const MAX_VERTICES = 200;
};

pub const NinjaDogPaintData = struct {
    bladeDrawn: bool = false,
    bladeRotation: f32 = 0,
    leftPawOffset: main.Position = .{ .x = 0, .y = 0 },
    rightPawOffset: main.Position = .{ .x = 0, .y = 0 },
};

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
    if (!paintData.bladeDrawn) {
        addTiranglesForSprite(position, imageZig.IMAGE_BLADE__HAND_HOLD_POINT, imageZig.IMAGE_BLADE, 0, null, null, state);
    }
    addTiranglesForSprite(position, imageZig.IMAGE_DOG__CENTER, imageZig.IMAGE_DOG, 0, null, null, state);
    const imageDataDog = imageZig.IMAGE_DATA[imageZig.IMAGE_DOG];
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
    state.player.ninjaDogPaintData.bladeDrawn = true;
    state.player.ninjaDogPaintData.bladeRotation = std.math.pi * 1.5;
    state.player.ninjaDogPaintData.leftPawOffset = .{ .x = 20, .y = 0 };
    state.player.ninjaDogPaintData.rightPawOffset = .{ .x = -20, .y = 10 };
}

fn calcScalingAndRotation(baseAnker: main.Position, zeroOffset: main.Position, targetOffset: main.Position) struct { angle: f32, scale: f32 } {
    const zeroAndTargetOffset: main.Position = .{ .x = zeroOffset.x + targetOffset.x, .y = zeroOffset.y + targetOffset.y };
    const distance = main.calculateDistance(baseAnker, zeroOffset);
    const distance2 = main.calculateDistance(baseAnker, zeroAndTargetOffset);
    const scale: f32 = distance2 / distance;
    // calc angle change from zeroOffset to shouldBeOffset
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
