const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const initVulkanZig = @import("initVulkan.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const vk = initVulkanZig.vk;
const movePieceUxVulkanZig = @import("movePieceUxVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const mapGridVulkanZig = @import("mapGridVulkan.zig");
const cutSpriteVulkan = @import("cutSpriteVulkan.zig");
const ninjaDogVulkanZig = @import("ninjaDogVulkan.zig");
const enemyVulkanZig = @import("enemyVulkan.zig");
const shopVulkanZig = @import("shopVulkan.zig");
const choosenMovePieceVulkanZig = @import("choosenMovePieceVisualizationVulkan.zig");

pub fn drawFrame(state: *main.GameState) !void {
    const vkState = &state.vkState;
    try setupVerticesForSprites(state);
    try movePieceUxVulkanZig.setupVertices(state);
    if (!try initVulkanZig.createSwapChainRelatedStuffAndCheckWindowSize(state, state.allocator)) return;
    try updateUniformBuffer(state);
    if (vk.vkWaitForFences.?(vkState.logicalDevice, 1, &vkState.inFlightFence[vkState.currentFrame], vk.VK_TRUE, std.math.maxInt(u64)) != vk.VK_SUCCESS) return;
    if (vk.vkResetFences.?(vkState.logicalDevice, 1, &vkState.inFlightFence[vkState.currentFrame]) != vk.VK_SUCCESS) return;
    var imageIndex: u32 = undefined;

    const acquireImageResult = vk.vkAcquireNextImageKHR.?(
        vkState.logicalDevice,
        vkState.swapchain,
        std.math.maxInt(u64),
        vkState.imageAvailableSemaphore[vkState.currentFrame],
        null,
        &imageIndex,
    );

    if (acquireImageResult == vk.VK_ERROR_OUT_OF_DATE_KHR) {
        try initVulkanZig.recreateSwapChain(state, state.allocator);
        return;
    } else if (acquireImageResult != vk.VK_SUCCESS and acquireImageResult != vk.VK_SUBOPTIMAL_KHR) {
        return error.failedToAcquireSwapChainImage;
    }
    _ = vk.vkResetCommandBuffer.?(vkState.commandBuffer[vkState.currentFrame], 0);
    try recordCommandBuffer(vkState.commandBuffer[vkState.currentFrame], imageIndex, state);

    var submitInfo = vk.VkSubmitInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &[_]vk.VkSemaphore{vkState.imageAvailableSemaphore[vkState.currentFrame]},
        .pWaitDstStageMask = &[_]vk.VkPipelineStageFlags{vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
        .commandBufferCount = 1,
        .pCommandBuffers = &vkState.commandBuffer[vkState.currentFrame],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &[_]vk.VkSemaphore{vkState.submitSemaphores[imageIndex]},
    };
    try initVulkanZig.vkcheck(vk.vkQueueSubmit.?(vkState.queue, 1, &submitInfo, vkState.inFlightFence[vkState.currentFrame]), "Failed to Queue Submit.");

    var presentInfo = vk.VkPresentInfoKHR{
        .sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &[_]vk.VkSemaphore{vkState.submitSemaphores[imageIndex]},
        .swapchainCount = 1,
        .pSwapchains = &[_]vk.VkSwapchainKHR{vkState.swapchain},
        .pImageIndices = &imageIndex,
    };
    const presentResult = vk.vkQueuePresentKHR.?(vkState.queue, &presentInfo);

    if (presentResult == vk.VK_ERROR_OUT_OF_DATE_KHR or presentResult == vk.VK_SUBOPTIMAL_KHR) {
        try initVulkanZig.recreateSwapChain(state, state.allocator);
    } else if (presentResult != vk.VK_SUCCESS) {
        return error.failedToPresentSwapChainImage;
    }

    vkState.currentFrame = (vkState.currentFrame + 1) % initVulkanZig.VkState.MAX_FRAMES_IN_FLIGHT;
}

pub fn verticesForComplexSprite(gamePosition: main.Position, imageIndex: u8, vkSpriteComplex: *dataVulkanZig.VkSpriteComplex, state: *main.GameState) void {
    if (vkSpriteComplex.verticeCount + 6 >= vkSpriteComplex.vertices.len) return;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const halfSizeWidth: f32 = main.TILESIZE / 2;
    const halfSizeHeigh: f32 = main.TILESIZE / 2;
    const points = [_]main.Position{
        main.Position{ .x = -halfSizeWidth, .y = halfSizeHeigh },
        main.Position{ .x = -halfSizeWidth, .y = -halfSizeHeigh },
        main.Position{ .x = halfSizeWidth, .y = halfSizeHeigh },
        main.Position{ .x = halfSizeWidth, .y = -halfSizeHeigh },
    };

    for (0..points.len - 2) |i| {
        const pointsIndexes = [_]usize{ i, i + 1 + @mod(i, 2), i + 2 - @mod(i, 2) };
        for (pointsIndexes) |verticeIndex| {
            const cornerPosOffset = points[verticeIndex];
            const vulkan: main.Position = .{
                .x = (cornerPosOffset.x - state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
                .y = (cornerPosOffset.y - state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
            };
            const texPos: [2]f32 = .{
                (cornerPosOffset.x / halfSizeWidth + 1) / 2,
                (cornerPosOffset.y / halfSizeHeigh + 1) / 2,
            };
            vkSpriteComplex.vertices[vkSpriteComplex.verticeCount] = dataVulkanZig.SpriteComplexVertex{
                .pos = .{ vulkan.x, vulkan.y },
                .imageIndex = imageIndex,
                .alpha = 1,
                .tex = texPos,
            };
            vkSpriteComplex.verticeCount += 1;
        }
    }
}

pub fn verticesForComplexSpriteWithRotate(gamePosition: main.Position, imageIndex: u8, rotation: f32, vkSpriteComplex: *dataVulkanZig.VkSpriteComplex, state: *main.GameState) void {
    if (vkSpriteComplex.verticeCount + 6 >= vkSpriteComplex.vertices.len) return;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const halfSizeWidth: f32 = main.TILESIZE / 2;
    const halfSizeHeigh: f32 = main.TILESIZE / 2;
    const points = [_]main.Position{
        main.Position{ .x = -halfSizeWidth, .y = halfSizeHeigh },
        main.Position{ .x = -halfSizeWidth, .y = -halfSizeHeigh },
        main.Position{ .x = halfSizeWidth, .y = halfSizeHeigh },
        main.Position{ .x = halfSizeWidth, .y = -halfSizeHeigh },
    };

    for (0..points.len - 2) |i| {
        const pointsIndexes = [_]usize{ i, i + 1 + @mod(i, 2), i + 2 - @mod(i, 2) };
        for (pointsIndexes) |verticeIndex| {
            const cornerPosOffset = points[verticeIndex];
            const rotatedOffset = rotateAroundPoint(cornerPosOffset, .{ .x = 0, .y = 0 }, rotation);
            const vulkan: main.Position = .{
                .x = (rotatedOffset.x - state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
                .y = (rotatedOffset.y - state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
            };
            const texPos: [2]f32 = .{
                (cornerPosOffset.x / halfSizeWidth + 1) / 2,
                (cornerPosOffset.y / halfSizeHeigh + 1) / 2,
            };
            vkSpriteComplex.vertices[vkSpriteComplex.verticeCount] = dataVulkanZig.SpriteComplexVertex{
                .pos = .{ vulkan.x, vulkan.y },
                .imageIndex = imageIndex,
                .alpha = 1,
                .tex = texPos,
            };
            vkSpriteComplex.verticeCount += 1;
        }
    }
}

fn resetVerticeData(state: *main.GameState) !void {
    const vkState = &state.vkState;
    const verticeData = &vkState.verticeData;
    const increaseBy = 200;
    if (verticeData.triangles.vertexBufferCleanUp[vkState.currentFrame] != null) {
        vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.triangles.vertexBufferCleanUp[vkState.currentFrame].?, null);
        vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.triangles.vertexBufferMemoryCleanUp[vkState.currentFrame].?, null);
        verticeData.triangles.vertexBufferCleanUp[vkState.currentFrame] = null;
        verticeData.triangles.vertexBufferMemoryCleanUp[vkState.currentFrame] = null;
    }
    if (verticeData.triangles.verticeCount + increaseBy * 3 > verticeData.triangles.vertices.len) {
        verticeData.triangles.vertexBufferCleanUp[vkState.currentFrame] = verticeData.triangles.vertexBuffer;
        verticeData.triangles.vertexBufferMemoryCleanUp[vkState.currentFrame] = verticeData.triangles.vertexBufferMemory;
        try initVulkanZig.createVertexBufferColored(vkState, &verticeData.triangles, verticeData.triangles.vertices.len + increaseBy * 3, state.allocator);
    }
    verticeData.triangles.verticeCount = 0;

    if (verticeData.lines.vertexBufferCleanUp[vkState.currentFrame] != null) {
        vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.lines.vertexBufferCleanUp[vkState.currentFrame].?, null);
        vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.lines.vertexBufferMemoryCleanUp[vkState.currentFrame].?, null);
        verticeData.lines.vertexBufferCleanUp[vkState.currentFrame] = null;
        verticeData.lines.vertexBufferMemoryCleanUp[vkState.currentFrame] = null;
    }
    if (verticeData.lines.verticeCount + increaseBy * 2 > verticeData.lines.vertices.len) {
        verticeData.lines.vertexBufferCleanUp[vkState.currentFrame] = verticeData.lines.vertexBuffer;
        verticeData.lines.vertexBufferMemoryCleanUp[vkState.currentFrame] = verticeData.lines.vertexBufferMemory;
        try initVulkanZig.createVertexBufferColored(vkState, &verticeData.lines, verticeData.lines.vertices.len + increaseBy * 2, state.allocator);
    }
    verticeData.lines.verticeCount = 0;

    if (verticeData.sprites.vertexBufferCleanUp[vkState.currentFrame] != null) {
        vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.sprites.vertexBufferCleanUp[vkState.currentFrame].?, null);
        vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.sprites.vertexBufferMemoryCleanUp[vkState.currentFrame].?, null);
        verticeData.sprites.vertexBufferCleanUp[vkState.currentFrame] = null;
        verticeData.sprites.vertexBufferMemoryCleanUp[vkState.currentFrame] = null;
    }
    if (verticeData.sprites.verticeCount + increaseBy > verticeData.sprites.vertices.len) {
        verticeData.sprites.vertexBufferCleanUp[vkState.currentFrame] = verticeData.v.vertexBuffer;
        verticeData.sprites.vertexBufferMemoryCleanUp[vkState.currentFrame] = verticeData.sprites.vertexBufferMemory;
        try initVulkanZig.createVertexBufferSprites(vkState, &verticeData.sprites, verticeData.sprites.vertices.len + increaseBy, state.allocator);
    }
    verticeData.sprites.verticeCount = 0;

    if (verticeData.spritesComplex.vertexBufferCleanUp[vkState.currentFrame] != null) {
        vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.spritesComplex.vertexBufferCleanUp[vkState.currentFrame].?, null);
        vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.spritesComplex.vertexBufferMemoryCleanUp[vkState.currentFrame].?, null);
        verticeData.spritesComplex.vertexBufferCleanUp[vkState.currentFrame] = null;
        verticeData.spritesComplex.vertexBufferMemoryCleanUp[vkState.currentFrame] = null;
    }
    if (verticeData.spritesComplex.verticeCount + increaseBy * 6 > verticeData.spritesComplex.vertices.len) {
        verticeData.spritesComplex.vertexBufferCleanUp[vkState.currentFrame] = verticeData.v.vertexBuffer;
        verticeData.spritesComplex.vertexBufferMemoryCleanUp[vkState.currentFrame] = verticeData.spritesComplex.vertexBufferMemory;
        try initVulkanZig.createVertexBufferSpritesComplex(vkState, &verticeData.spritesComplex, verticeData.spritesComplex.vertices.len + increaseBy * 6, state.allocator);
    }
    verticeData.spritesComplex.verticeCount = 0;

    if (verticeData.font.vertexBufferCleanUp[vkState.currentFrame] != null) {
        vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.font.vertexBufferCleanUp[vkState.currentFrame].?, null);
        vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.font.vertexBufferMemoryCleanUp[vkState.currentFrame].?, null);
        verticeData.font.vertexBufferCleanUp[vkState.currentFrame] = null;
        verticeData.font.vertexBufferMemoryCleanUp[vkState.currentFrame] = null;
    }
    if (verticeData.font.verticeCount + increaseBy > verticeData.font.vertices.len) {
        verticeData.font.vertexBufferCleanUp[vkState.currentFrame] = verticeData.v.vertexBuffer;
        verticeData.font.vertexBufferMemoryCleanUp[vkState.currentFrame] = verticeData.font.vertexBufferMemory;
        try initVulkanZig.createVertexBufferSpritesFont(vkState, &verticeData.font, verticeData.font.vertices.len + increaseBy, state.allocator);
    }
    verticeData.font.verticeCount = 0;
}

fn recordCommandBuffer(commandBuffer: vk.VkCommandBuffer, imageIndex: u32, state: *main.GameState) !void {
    const vkState = &state.vkState;
    var beginInfo = vk.VkCommandBufferBeginInfo{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    };
    try initVulkanZig.vkcheck(vk.vkBeginCommandBuffer.?(commandBuffer, &beginInfo), "Failed to Begin Command Buffer.");

    const renderPassInfo = vk.VkRenderPassBeginInfo{
        .sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = vkState.renderPass,
        .framebuffer = vkState.framebuffers.?[imageIndex],
        .renderArea = vk.VkRect2D{
            .offset = vk.VkOffset2D{ .x = 0, .y = 0 },
            .extent = vkState.swapchainInfo.extent,
        },
        .clearValueCount = 2,
        .pClearValues = &[_]vk.VkClearValue{
            .{ .color = vk.VkClearColorValue{ .float32 = [_]f32{ 63.0 / 256.0, 155.0 / 256.0, 11.0 / 256.0, 1.0 } } },
            .{ .depthStencil = vk.VkClearDepthStencilValue{ .depth = 1.0, .stencil = 0.0 } },
        },
    };
    vk.vkCmdBeginRenderPass.?(commandBuffer, &renderPassInfo, vk.VK_SUBPASS_CONTENTS_INLINE);

    var viewport = vk.VkViewport{
        .x = 0.0,
        .y = 0.0,
        .width = @floatFromInt(vkState.swapchainInfo.extent.width),
        .height = @floatFromInt(vkState.swapchainInfo.extent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };
    vk.vkCmdSetViewport.?(commandBuffer, 0, 1, &viewport);
    var scissor = vk.VkRect2D{
        .offset = vk.VkOffset2D{ .x = 0, .y = 0 },
        .extent = vkState.swapchainInfo.extent,
    };
    vk.vkCmdSetScissor.?(commandBuffer, 0, 1, &scissor);
    vk.vkCmdBindDescriptorSets.?(
        commandBuffer,
        vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
        vkState.pipelineLayout,
        0,
        1,
        &vkState.descriptorSets[vkState.currentFrame],
        0,
        null,
    );
    try mapGridVulkanZig.recordCommandBuffer(commandBuffer, state);
    try shopVulkanZig.recordCommandBuffer(commandBuffer, state);
    try choosenMovePieceVulkanZig.recordCommandBuffer(commandBuffer, state);
    try enemyVulkanZig.recordCommandBuffer(commandBuffer, state);
    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.spriteComplex);
    const vertexBuffers: [1]vk.VkBuffer = .{vkState.spriteData.vertexBuffer};
    const offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(vkState.spriteData.verticeCount), 1, 0, 0);
    try cutSpriteVulkan.recordCommandBuffer(commandBuffer, state);
    try ninjaDogVulkanZig.recordCommandBuffer(commandBuffer, state);
    vk.vkCmdNextSubpass.?(commandBuffer, vk.VK_SUBPASS_CONTENTS_INLINE);
    vk.vkCmdNextSubpass.?(commandBuffer, vk.VK_SUBPASS_CONTENTS_INLINE);
    try movePieceUxVulkanZig.recordCommandBuffer(commandBuffer, state);
    try fontVulkanZig.recordFontCommandBuffer(commandBuffer, state);

    vk.vkCmdEndRenderPass.?(commandBuffer);
    try initVulkanZig.vkcheck(vk.vkEndCommandBuffer.?(commandBuffer), "Failed to End Command Buffer.");
}

fn setupVerticesForSprites(state: *main.GameState) !void {
    const spriteData = &state.vkState.spriteData;
    spriteData.verticeCount = 0;
    try setupVertexDataForGPU(&state.vkState);
}

pub fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, vkState.spriteData.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.SpriteComplexVertex) * vkState.spriteData.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpuVertices: [*]dataVulkanZig.SpriteComplexVertex = @ptrCast(@alignCast(data));
    @memcpy(gpuVertices, vkState.spriteData.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, vkState.spriteData.vertexBufferMemory);
}

fn updateUniformBuffer(state: *main.GameState) !void {
    var ubo: dataVulkanZig.VkCameraData = .{
        .transform = .{
            .{ 2 / windowSdlZig.windowData.widthFloat, 0, 0.0, 0.0 },
            .{ 0, 2 / windowSdlZig.windowData.heightFloat, 0.0, 0.0 },
            .{ 0.0, 0.0, 1.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 1 / state.camera.zoom },
        },
        .translate = .{ -state.camera.position.x, -state.camera.position.y },
    };
    if (state.vkState.uniformBuffersMapped[state.vkState.currentFrame]) |data| {
        @memcpy(
            @as([*]u8, @ptrCast(data))[0..@sizeOf(dataVulkanZig.VkCameraData)],
            @as([*]u8, @ptrCast(&ubo)),
        );
    }
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    vk.vkDestroyBuffer.?(vkState.logicalDevice, vkState.spriteData.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, vkState.spriteData.vertexBufferMemory, null);
    allocator.free(vkState.spriteData.vertices);
}

pub fn rotateAroundPoint(point: main.Position, pivot: main.Position, angle: f32) main.Position {
    const translatedX = point.x - pivot.x;
    const translatedY = point.y - pivot.y;

    const s = @sin(angle);
    const c = @cos(angle);

    const rotatedX = c * translatedX - s * translatedY;
    const rotatedY = s * translatedX + c * translatedY;

    return main.Position{ .x = rotatedX + pivot.x, .y = rotatedY + pivot.y };
}
