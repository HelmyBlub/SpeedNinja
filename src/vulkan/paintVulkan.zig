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
    try mapGridVulkanZig.recordCommandBuffer(commandBuffer, state);
    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.spriteWithGlobalTransform);
    const vertexBuffers: [1]vk.VkBuffer = .{vkState.spriteData.vertexBuffer};
    const offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
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

    vk.vkCmdDraw.?(commandBuffer, @intCast(vkState.spriteData.verticeUsedCount), 1, 0, 0);
    vk.vkCmdNextSubpass.?(commandBuffer, vk.VK_SUBPASS_CONTENTS_INLINE);
    vk.vkCmdNextSubpass.?(commandBuffer, vk.VK_SUBPASS_CONTENTS_INLINE);
    try movePieceUxVulkanZig.recordCommandBuffer(commandBuffer, state);
    try fontVulkanZig.recordFontCommandBuffer(commandBuffer, state);

    vk.vkCmdEndRenderPass.?(commandBuffer);
    try initVulkanZig.vkcheck(vk.vkEndCommandBuffer.?(commandBuffer), "Failed to End Command Buffer.");
}

fn setupVerticesForSprites(state: *main.GameState) !void {
    const spriteData = &state.vkState.spriteData;
    spriteData.verticeUsedCount = 0;

    spriteData.vertices[spriteData.verticeUsedCount] = .{
        .pos = .{ state.player.position.x, state.player.position.y },
        .imageIndex = imageZig.IMAGE_DOG,
        .size = main.TILESIZE,
        .rotate = 0,
        .cutY = 0,
    };
    spriteData.verticeUsedCount += 1;

    if (state.player.choosenMoveOptionIndex) |index| {
        for (0..4) |direction| {
            var position: main.Position = state.player.position;
            for (state.player.moveOptions.items[index].steps) |moveStep| {
                const moveDirection = @mod(moveStep.direction + direction, 4);
                const moveX: f32 = if (moveDirection == 0) main.TILESIZE else if (moveDirection == 2) -main.TILESIZE else 0;
                const moveY: f32 = if (moveDirection == 1) main.TILESIZE else if (moveDirection == 3) -main.TILESIZE else 0;
                for (0..moveStep.stepCount) |_| {
                    position.x += moveX;
                    position.y += moveY;
                    if (spriteData.verticeUsedCount >= spriteData.vertices.len) return;
                    spriteData.vertices[spriteData.verticeUsedCount] = .{
                        .pos = .{ position.x, position.y },
                        .imageIndex = imageZig.IMAGE_WHITE_RECTANGLE,
                        .size = main.TILESIZE,
                        .rotate = 0,
                        .cutY = 0,
                    };
                    spriteData.verticeUsedCount += 1;
                }
            }
        }
    }
    for (state.enemies.items) |enemy| {
        if (spriteData.verticeUsedCount >= spriteData.vertices.len) return;
        spriteData.vertices[spriteData.verticeUsedCount] = .{
            .pos = .{ enemy.x, enemy.y },
            .imageIndex = imageZig.IMAGE_TREE,
            .size = main.TILESIZE,
            .rotate = 0,
            .cutY = 0,
        };
        spriteData.verticeUsedCount += 1;
    }
    try setupVertexDataForGPU(&state.vkState);
}

pub fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, vkState.spriteData.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.SpriteWithGlobalTransformVertex) * vkState.spriteData.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpuVertices: [*]dataVulkanZig.SpriteWithGlobalTransformVertex = @ptrCast(@alignCast(data));
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

pub fn createVertexBuffer(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    vkState.spriteData.vertices = try allocator.alloc(dataVulkanZig.SpriteWithGlobalTransformVertex, 50);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.SpriteWithGlobalTransformVertex) * vkState.spriteData.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.spriteData.vertexBuffer,
        &vkState.spriteData.vertexBufferMemory,
        vkState,
    );
}
