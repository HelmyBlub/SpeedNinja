const std = @import("std");
const zigimg = @import("zigimg");
const initVulkanZig = @import("vulkan/initVulkan.zig");
const vk = initVulkanZig.vk;
const main = @import("main.zig");

pub const IMAGE_DOG = 0;
pub const IMAGE_WHITE_RECTANGLE = 1;
pub const IMAGE_EVIL_TREE = 2;
pub const IMAGE_BLADE = 3;
pub const IMAGE_NINJA_DOG_PAW = 4;
pub const IMAGE_EYE_CLOSED = 5;
pub const IMAGE_EYE_LEFT = 6;
pub const IMAGE_EYE_RIGHT = 7;
pub const IMAGE_PUPIL_LEFT = 8;
pub const IMAGE_PUPIL_RIGHT = 9;
pub const IMAGE_DOG_EAR = 10;
pub const IMAGE_BANDANA_TAIL = 11;
pub const IMAGE_DOG_TAIL = 12;
pub const IMAGE_WARNING_TILE = 13;
pub const IMAGE_WARNING_TILE_FILLED = 14;
pub const IMAGE_PLUS = 15;
pub const IMAGE_CUT = 16;
pub const IMAGE_ARROW_RIGHT = 17;
pub const IMAGE_BORDER_TILE = 18;
pub const IMAGE_COMBINE = 19;
pub const IMAGE_SHADOW = 20;
pub const IMAGE_EVIL_TOWER = 21;
pub const IMAGE_BOSS_ROTATE = 22;
pub const IMAGE_CIRCLE = 23;
pub const IMAGE_BOSS_ROTATE_PILLAR = 24;
pub const IMAGE_LASER = 25;
pub const IMAGE_RED_ARROW = 26;
pub const IMAGE_RED_ARROW_FILLED = 27;
pub const IMAGE_ENEMY_MOVING = 28;
pub const IMAGE_BOSS_ROLL = 29;
pub const IMAGE_CANNON_BALL = 30;

pub var IMAGE_DATA = [_]ImageData{
    .{ .path = "images/ninjaDog.png" },
    .{ .path = "images/whiteRectangle.png" },
    .{ .path = "images/evilTree.png" },
    .{ .path = "images/ninjablade.png" },
    .{ .path = "images/ninjaDogPaw.png" },
    .{ .path = "images/eyeClosed.png" },
    .{ .path = "images/eyeLeft.png" },
    .{ .path = "images/eyeRight.png" },
    .{ .path = "images/pupilLeft.png" },
    .{ .path = "images/pupilRight.png" },
    .{ .path = "images/dogEar.png" },
    .{ .path = "images/bandanaTail.png" },
    .{ .path = "images/dogTail.png" },
    .{ .path = "images/warningTile.png" },
    .{ .path = "images/warningTileFilled.png" },
    .{ .path = "images/plus.png" },
    .{ .path = "images/cut.png" },
    .{ .path = "images/arrow.png" },
    .{ .path = "images/borderTile.png" },
    .{ .path = "images/combine.png" },
    .{ .path = "images/shadow.png", .scale = 0.1 },
    .{ .path = "images/evilTower.png" },
    .{ .path = "images/bossRotate.png" },
    .{ .path = "images/circle.png", .scale = 0.1 },
    .{ .path = "images/bossRotatePillar.png" },
    .{ .path = "images/laser.png", .scale = 0.1 },
    .{ .path = "images/redArrow.png" },
    .{ .path = "images/redArrowFilled.png" },
    .{ .path = "images/enemyMoving.png" },
    .{ .path = "images/bossRoll.png" },
    .{ .path = "images/cannonBall.png" },
};
pub const IMAGE_DOG__CENTER: main.Position = .{ .x = 100, .y = 100 };

pub const IMAGE_DOG__EAR_LEFT: main.Position = .{ .x = 68, .y = 31 };
pub const IMAGE_DOG__EAR_RIGHT: main.Position = .{ .x = 132, .y = 31 };
pub const IMAGE_DOG_EAR__ANKER: main.Position = .{ .x = 14, .y = 6 };

pub const IMAGE_DOG__EYE_LEFT: main.Position = .{ .x = 87, .y = 35 };
pub const IMAGE_DOG__EYE_RIGHT: main.Position = .{ .x = 113, .y = 35 };

pub const IMAGE_DOG__BANDANA_TAIL: main.Position = .{ .x = 131, .y = 25 };
pub const IMAGE_BANDANA__ANKER: main.Position = .{ .x = 1, .y = 3 };

pub const IMAGE_DOG__TAIL: main.Position = .{ .x = 97, .y = 152 };
pub const IMAGE_DOG_TAIL__ANKER: main.Position = .{ .x = 2, .y = 4 };

pub const IMAGE_DOG__LEFT_ARM_ROTATE_POINT: main.Position = .{ .x = 77, .y = 106 };
pub const IMAGE_DOG__RIGHT_ARM_ROTATE_POINT: main.Position = .{ .x = 116, .y = 106 };
pub const IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT: main.Position = .{ .x = 8, .y = 3 };
pub const IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT: main.Position = .{ .x = 8, .y = 46 };

pub const IMAGE_DOG__BLADE_BACK: main.Position = .{ .x = 65, .y = 85 };
pub const IMAGE_DOG__BLADE_CENTER_HOLD: main.Position = .{ .x = 97, .y = 149 };
pub const IMAGE_BLADE__HAND_HOLD_POINT: main.Position = .{ .x = 13, .y = 12 };
pub const IMAGE_TO_GAME_SIZE = 10;

pub const ImageData = struct {
    path: []const u8,
    width: usize = undefined,
    height: usize = undefined,
    scale: f32 = 1,
};

pub fn getImageCenter(imageIndex: usize) main.Position {
    const image = IMAGE_DATA[imageIndex];
    return main.Position{
        .x = @as(f32, @floatFromInt(image.width)) / 2.0,
        .y = @as(f32, @floatFromInt(image.height)) / 2.0,
    };
}

pub fn createVulkanTextureSprites(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    vkState.spriteImages.textureImage = try allocator.alloc(vk.VkImage, IMAGE_DATA.len);
    vkState.spriteImages.textureImageMemory = try allocator.alloc(vk.VkDeviceMemory, IMAGE_DATA.len);
    vkState.spriteImages.mipLevels = try allocator.alloc(u32, IMAGE_DATA.len);

    for (0..IMAGE_DATA.len) |i| {
        try createVulkanTextureImage(vkState, allocator, IMAGE_DATA[i].path, &vkState.spriteImages.mipLevels[i], &vkState.spriteImages.textureImage[i], &vkState.spriteImages.textureImageMemory[i], i);
    }

    vkState.spriteImages.textureImageView = try allocator.alloc(vk.VkImageView, IMAGE_DATA.len);
    for (0..IMAGE_DATA.len) |i| {
        vkState.spriteImages.textureImageView[i] = try initVulkanZig.createImageView(vkState.spriteImages.textureImage[i], vk.VK_FORMAT_R8G8B8A8_SRGB, vkState.spriteImages.mipLevels[i], vk.VK_IMAGE_ASPECT_COLOR_BIT, vkState);
    }
}

pub fn createVulkanTextureImage(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator, filePath: []const u8, mipLevels: *u32, textureImage: *vk.VkImage, textureImageMemory: *vk.VkDeviceMemory, optImageIndex: ?usize) !void {
    var image = try zigimg.Image.fromFilePath(allocator, filePath);
    defer image.deinit();
    try image.convert(.rgba32);
    if (optImageIndex) |imageIndex| {
        IMAGE_DATA[imageIndex].height = image.height;
        IMAGE_DATA[imageIndex].width = image.width;
    }

    var stagingBuffer: vk.VkBuffer = undefined;
    defer vk.vkDestroyBuffer.?(vkState.logicalDevice, stagingBuffer, null);
    var stagingBufferMemory: vk.VkDeviceMemory = undefined;
    defer vk.vkFreeMemory.?(vkState.logicalDevice, stagingBufferMemory, null);
    try initVulkanZig.createBuffer(
        image.imageByteSize(),
        vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &stagingBuffer,
        &stagingBufferMemory,
        vkState,
    );

    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, stagingBufferMemory, 0, image.imageByteSize(), 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    @memcpy(
        @as([*]u8, @ptrCast(data))[0..image.imageByteSize()],
        @as([*]u8, @ptrCast(image.pixels.asBytes())),
    );
    vk.vkUnmapMemory.?(vkState.logicalDevice, stagingBufferMemory);
    const imageWidth: u32 = @intCast(image.width);
    const imageHeight: u32 = @intCast(image.height);
    const log2: f32 = @log2(@as(f32, @floatFromInt(@max(imageWidth, imageHeight))));
    mipLevels.* = @as(u32, @intFromFloat(log2)) + 1;
    try initVulkanZig.createImage(
        imageWidth,
        imageHeight,
        mipLevels.*,
        vk.VK_SAMPLE_COUNT_1_BIT,
        vk.VK_FORMAT_R8G8B8A8_SRGB,
        vk.VK_IMAGE_TILING_OPTIMAL,
        vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT | vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT | vk.VK_IMAGE_USAGE_SAMPLED_BIT,
        vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        textureImage,
        textureImageMemory,
        vkState,
    );

    try transitionVulkanImageLayout(
        textureImage.*,
        vk.VK_IMAGE_LAYOUT_UNDEFINED,
        vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        mipLevels.*,
        vkState,
    );
    try copyBufferToImage(stagingBuffer, textureImage.*, imageWidth, imageHeight, vkState);
    try generateVulkanMipmaps(
        textureImage.*,
        vk.VK_FORMAT_R8G8B8A8_SRGB,
        @intCast(imageWidth),
        @intCast(imageHeight),
        mipLevels.*,
        vkState,
    );
}

fn generateVulkanMipmaps(image: vk.VkImage, imageFormat: vk.VkFormat, texWidth: i32, texHeight: i32, mipLevels: u32, vkState: *initVulkanZig.VkState) !void {
    var formatProperties: vk.VkFormatProperties = undefined;
    vk.vkGetPhysicalDeviceFormatProperties.?(vkState.physicalDevice, imageFormat, &formatProperties);

    if ((formatProperties.optimalTilingFeatures & vk.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT) == 0) return error.doesNotSupportOptimailTiling;

    const commandBuffer: vk.VkCommandBuffer = try initVulkanZig.beginSingleTimeCommands(vkState);

    var barrier: vk.VkImageMemoryBarrier = .{
        .sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .image = image,
        .srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
        .subresourceRange = .{
            .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseArrayLayer = 0,
            .layerCount = 1,
            .levelCount = 1,
        },
    };
    var mipWidth: i32 = texWidth;
    var mipHeight: i32 = texHeight;

    for (1..mipLevels) |i| {
        barrier.subresourceRange.baseMipLevel = @as(u32, @intCast(i)) - 1;
        barrier.oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        barrier.newLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT;

        vk.vkCmdPipelineBarrier.?(
            commandBuffer,
            vk.VK_PIPELINE_STAGE_TRANSFER_BIT,
            vk.VK_PIPELINE_STAGE_TRANSFER_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &barrier,
        );

        const blit: vk.VkImageBlit = .{
            .srcOffsets = .{
                .{ .x = 0, .y = 0, .z = 0 },
                .{ .x = mipWidth, .y = mipHeight, .z = 1 },
            },
            .srcSubresource = .{
                .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
                .mipLevel = @as(u32, @intCast(i)) - 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .dstOffsets = .{
                .{ .x = 0, .y = 0, .z = 0 },
                .{ .x = if (mipWidth > 1) @divFloor(mipWidth, 2) else 1, .y = if (mipHeight > 1) @divFloor(mipHeight, 2) else 1, .z = 1 },
            },
            .dstSubresource = .{
                .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
                .mipLevel = @as(u32, @intCast(i)),
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };
        vk.vkCmdBlitImage.?(
            commandBuffer,
            image,
            vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            image,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &blit,
            vk.VK_FILTER_LINEAR,
        );
        barrier.oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        barrier.newLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT;
        barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT;

        vk.vkCmdPipelineBarrier.?(
            commandBuffer,
            vk.VK_PIPELINE_STAGE_TRANSFER_BIT,
            vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &barrier,
        );
        if (mipWidth > 1) mipWidth = @divFloor(mipWidth, 2);
        if (mipHeight > 1) mipHeight = @divFloor(mipHeight, 2);
    }

    barrier.subresourceRange.baseMipLevel = mipLevels - 1;
    barrier.oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.newLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT;

    vk.vkCmdPipelineBarrier.?(
        commandBuffer,
        vk.VK_PIPELINE_STAGE_TRANSFER_BIT,
        vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        0,
        0,
        null,
        0,
        null,
        1,
        &barrier,
    );

    try initVulkanZig.endSingleTimeCommands(commandBuffer, vkState);
}

fn copyBufferToImage(buffer: vk.VkBuffer, image: vk.VkImage, width: u32, height: u32, vkState: *initVulkanZig.VkState) !void {
    const commandBuffer: vk.VkCommandBuffer = try initVulkanZig.beginSingleTimeCommands(vkState);
    const region: vk.VkBufferImageCopy = .{
        .bufferOffset = 0,
        .bufferRowLength = 0,
        .bufferImageHeight = 0,
        .imageSubresource = .{
            .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
            .mipLevel = 0,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .imageOffset = .{ .x = 0, .y = 0, .z = 0 },
        .imageExtent = .{ .width = width, .height = height, .depth = 1 },
    };
    vk.vkCmdCopyBufferToImage.?(
        commandBuffer,
        buffer,
        image,
        vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1,
        &region,
    );

    try initVulkanZig.endSingleTimeCommands(commandBuffer, vkState);
}

fn transitionVulkanImageLayout(image: vk.VkImage, oldLayout: vk.VkImageLayout, newLayout: vk.VkImageLayout, mipLevels: u32, vkState: *initVulkanZig.VkState) !void {
    const commandBuffer = try initVulkanZig.beginSingleTimeCommands(vkState);

    var barrier: vk.VkImageMemoryBarrier = .{
        .sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .oldLayout = oldLayout,
        .newLayout = newLayout,
        .srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresourceRange = .{
            .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = mipLevels,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .srcAccessMask = 0,
        .dstAccessMask = 0,
    };

    var sourceStage: vk.VkPipelineStageFlags = undefined;
    var destinationStage: vk.VkPipelineStageFlags = undefined;

    if (oldLayout == vk.VK_IMAGE_LAYOUT_UNDEFINED and newLayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;

        sourceStage = vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        destinationStage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT;
    } else if (oldLayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and newLayout == vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
        barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT;

        sourceStage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT;
        destinationStage = vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    } else {
        return error.unsuportetLayoutTransition;
    }

    vk.vkCmdPipelineBarrier.?(
        commandBuffer,
        sourceStage,
        destinationStage,
        0,
        0,
        null,
        0,
        null,
        1,
        &barrier,
    );
    try initVulkanZig.endSingleTimeCommands(commandBuffer, vkState);
}
