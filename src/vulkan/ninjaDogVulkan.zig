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
        addTiranglesForSprite(position, imageZig.IMAGE_BLADE, 0, state);
    }
    addTiranglesForSprite(position, imageZig.IMAGE_DOG, 0, state);
    const imageDataDog = imageZig.IMAGE_DATA[imageZig.IMAGE_DOG];
    const imageDataDogPaw = imageZig.IMAGE_DATA[imageZig.IMAGE_NINJA_DOG_PAW];
    const leftArmSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2 - imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x + @as(f32, @floatFromInt(imageDataDogPaw.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2 - imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y + @as(f32, @floatFromInt(imageDataDogPaw.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    addTiranglesForSprite(leftArmSpritePosition, imageZig.IMAGE_NINJA_DOG_PAW, 0, state);
    const rightArmSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2 - imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x + @as(f32, @floatFromInt(imageDataDogPaw.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2 - imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y + @as(f32, @floatFromInt(imageDataDogPaw.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    addTiranglesForSprite(rightArmSpritePosition, imageZig.IMAGE_NINJA_DOG_PAW, 0, state);
    if (paintData.bladeDrawn) {
        addTiranglesForSprite(position, imageZig.IMAGE_BLADE, @as(f32, @floatFromInt(state.gameTime)) / 128, state);
    }
}

fn addTiranglesForSprite(position: main.Position, imageIndex: u8, rotateAngle: f32, state: *main.GameState) void {
    const ninjaDogData = &state.vkState.ninjaDogData;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const imageData = imageZig.IMAGE_DATA[imageIndex];
    const halfSizeWidth: f32 = @as(f32, @floatFromInt(imageData.width)) / imageZig.IMAGE_TO_GAME_SIZE / 2;
    const halfSizeHeigh: f32 = @as(f32, @floatFromInt(imageData.height)) / imageZig.IMAGE_TO_GAME_SIZE / 2;
    const corners: [4]main.Position = [4]main.Position{
        main.Position{ .x = -halfSizeWidth, .y = -halfSizeHeigh },
        main.Position{ .x = halfSizeWidth, .y = -halfSizeHeigh },
        main.Position{ .x = halfSizeWidth, .y = halfSizeHeigh },
        main.Position{ .x = -halfSizeWidth, .y = halfSizeHeigh },
    };
    const verticeOrder = [_]usize{ 0, 1, 2, 0, 2, 3 };
    for (verticeOrder) |verticeIndex| {
        const cornerPosOffset = corners[verticeIndex];
        const rotatedOffset = paintVulkanZig.rotateAroundPoint(cornerPosOffset, .{ .x = 0, .y = 0 }, rotateAngle);
        const vulkan: main.Position = .{
            .x = (rotatedOffset.x - state.camera.position.x + position.x) * state.camera.zoom * onePixelXInVulkan,
            .y = (rotatedOffset.y - state.camera.position.y + position.y) * state.camera.zoom * onePixelYInVulkan,
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
