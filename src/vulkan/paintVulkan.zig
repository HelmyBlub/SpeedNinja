const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const windowSdlZig = @import("../windowSdl.zig");

const SpriteWithGlobalTransformVertex = struct {
    pos: [2]f64,
    imageIndex: u8,
    size: u8,
    rotate: f32,
    /// 0 => nothing cut, 1 => nothing left
    cutY: f32,

    fn getBindingDescription() vk.VkVertexInputBindingDescription {
        const bindingDescription: vk.VkVertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(SpriteWithGlobalTransformVertex),
            .inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        return bindingDescription;
    }

    fn getAttributeDescriptions() [5]vk.VkVertexInputAttributeDescription {
        var attributeDescriptions: [5]vk.VkVertexInputAttributeDescription = .{ undefined, undefined, undefined, undefined, undefined };
        attributeDescriptions[0].binding = 0;
        attributeDescriptions[0].location = 0;
        attributeDescriptions[0].format = vk.VK_FORMAT_R64G64_SFLOAT;
        attributeDescriptions[0].offset = @offsetOf(SpriteWithGlobalTransformVertex, "pos");
        attributeDescriptions[1].binding = 0;
        attributeDescriptions[1].location = 1;
        attributeDescriptions[1].format = vk.VK_FORMAT_R8_UINT;
        attributeDescriptions[1].offset = @offsetOf(SpriteWithGlobalTransformVertex, "imageIndex");
        attributeDescriptions[2].binding = 0;
        attributeDescriptions[2].location = 2;
        attributeDescriptions[2].format = vk.VK_FORMAT_R8_UINT;
        attributeDescriptions[2].offset = @offsetOf(SpriteWithGlobalTransformVertex, "size");
        attributeDescriptions[3].binding = 0;
        attributeDescriptions[3].location = 3;
        attributeDescriptions[3].format = vk.VK_FORMAT_R32_SFLOAT;
        attributeDescriptions[3].offset = @offsetOf(SpriteWithGlobalTransformVertex, "rotate");
        attributeDescriptions[4].binding = 0;
        attributeDescriptions[4].location = 4;
        attributeDescriptions[4].format = vk.VK_FORMAT_R32_SFLOAT;
        attributeDescriptions[4].offset = @offsetOf(SpriteWithGlobalTransformVertex, "cutY");
        return attributeDescriptions;
    }
};

pub const SpriteData = struct {
    vertices: []SpriteWithGlobalTransformVertex = undefined,
    vertexBufferSize: u64 = 0,
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
};

pub const VkCameraData = struct {
    translate: [2]f64,
    transform: [4][4]f32,
};

pub fn drawFrame(state: *main.GameState) !void {
    const vkState = &state.vkState;
    try setupVerticesForSprites(state);
    try setupVertexDataForGPU(vkState);
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
    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipeline);
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

    vk.vkCmdDraw.?(commandBuffer, 1, 1, 0, 0);
    vk.vkCmdNextSubpass.?(commandBuffer, vk.VK_SUBPASS_CONTENTS_INLINE);
    vk.vkCmdNextSubpass.?(commandBuffer, vk.VK_SUBPASS_CONTENTS_INLINE);

    vk.vkCmdEndRenderPass.?(commandBuffer);
    try initVulkanZig.vkcheck(vk.vkEndCommandBuffer.?(commandBuffer), "Failed to End Command Buffer.");
}

fn setupVerticesForSprites(state: *main.GameState) !void {
    state.vkState.spriteData.vertices[0] = .{
        .pos = .{ 0, 0 },
        .imageIndex = 0,
        .size = 20,
        .rotate = 0,
        .cutY = 0,
    };
}

pub fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, vkState.spriteData.vertexBufferMemory, 0, @sizeOf(SpriteWithGlobalTransformVertex) * vkState.spriteData.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpuVertices: [*]SpriteWithGlobalTransformVertex = @ptrCast(@alignCast(data));
    @memcpy(gpuVertices, vkState.spriteData.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, vkState.spriteData.vertexBufferMemory);
}

fn updateUniformBuffer(state: *main.GameState) !void {
    var ubo: VkCameraData = .{
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
            @as([*]u8, @ptrCast(data))[0..@sizeOf(VkCameraData)],
            @as([*]u8, @ptrCast(&ubo)),
        );
    }
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    vk.vkDestroyBuffer.?(vkState.logicalDevice, vkState.spriteData.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, vkState.spriteData.vertexBufferMemory, null);
    allocator.free(vkState.spriteData.vertices);
}

pub fn createGraphicsPipelines(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    const vertShaderCode = try initVulkanZig.readShaderFile("shaders/spriteWithGlobalTransformVert.spv", allocator);
    defer allocator.free(vertShaderCode);
    const fragShaderCode = try initVulkanZig.readShaderFile("shaders/imageFrag.spv", allocator);
    defer allocator.free(fragShaderCode);
    const geomShaderCode = try initVulkanZig.readShaderFile("shaders/spriteWithGlobalTransformGeom.spv", allocator);
    defer allocator.free(geomShaderCode);
    const vertShaderModule = try initVulkanZig.createShaderModule(vertShaderCode, vkState);
    defer vk.vkDestroyShaderModule.?(vkState.logicalDevice, vertShaderModule, null);
    const fragShaderModule = try initVulkanZig.createShaderModule(fragShaderCode, vkState);
    defer vk.vkDestroyShaderModule.?(vkState.logicalDevice, fragShaderModule, null);
    const geomShaderModule = try initVulkanZig.createShaderModule(geomShaderCode, vkState);
    defer vk.vkDestroyShaderModule.?(vkState.logicalDevice, geomShaderModule, null);

    const vertShaderStageInfo = vk.VkPipelineShaderStageCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = vk.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertShaderModule,
        .pName = "main",
    };

    const fragShaderStageInfo = vk.VkPipelineShaderStageCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = fragShaderModule,
        .pName = "main",
    };

    const geomShaderStageInfo = vk.VkPipelineShaderStageCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = vk.VK_SHADER_STAGE_GEOMETRY_BIT,
        .module = geomShaderModule,
        .pName = "main",
    };

    const shaderStages = [_]vk.VkPipelineShaderStageCreateInfo{ vertShaderStageInfo, fragShaderStageInfo, geomShaderStageInfo };
    const bindingDescription = SpriteWithGlobalTransformVertex.getBindingDescription();
    const attributeDescriptions = SpriteWithGlobalTransformVertex.getAttributeDescriptions();
    var vertexInputInfo = vk.VkPipelineVertexInputStateCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &bindingDescription,
        .vertexAttributeDescriptionCount = attributeDescriptions.len,
        .pVertexAttributeDescriptions = &attributeDescriptions,
    };

    var inputAssembly = vk.VkPipelineInputAssemblyStateCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = vk.VK_PRIMITIVE_TOPOLOGY_POINT_LIST,
        .primitiveRestartEnable = vk.VK_FALSE,
    };

    var viewportState = vk.VkPipelineViewportStateCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = null,
        .scissorCount = 1,
        .pScissors = null,
    };

    var rasterizer = vk.VkPipelineRasterizationStateCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = vk.VK_FALSE,
        .rasterizerDiscardEnable = vk.VK_FALSE,
        .polygonMode = vk.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = vk.VK_CULL_MODE_BACK_BIT,
        .frontFace = vk.VK_FRONT_FACE_CLOCKWISE,
        .depthBiasEnable = vk.VK_FALSE,
        .depthBiasConstantFactor = 0.0,
        .depthBiasClamp = 0.0,
        .depthBiasSlopeFactor = 0.0,
    };

    var multisampling = vk.VkPipelineMultisampleStateCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = vk.VK_FALSE,
        .rasterizationSamples = vkState.msaaSamples,
        .minSampleShading = 1.0,
        .pSampleMask = null,
        .alphaToCoverageEnable = vk.VK_FALSE,
        .alphaToOneEnable = vk.VK_FALSE,
    };

    var colorBlendAttachment = vk.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = vk.VK_COLOR_COMPONENT_R_BIT | vk.VK_COLOR_COMPONENT_G_BIT | vk.VK_COLOR_COMPONENT_B_BIT | vk.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = vk.VK_TRUE,
        .srcColorBlendFactor = vk.VK_BLEND_FACTOR_SRC_ALPHA,
        .dstColorBlendFactor = vk.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .colorBlendOp = vk.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = vk.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = vk.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = vk.VK_BLEND_OP_ADD,
    };

    var colorBlending = vk.VkPipelineColorBlendStateCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = vk.VK_FALSE,
        .logicOp = vk.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &colorBlendAttachment,
        .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
    };

    const dynamicStates = [_]vk.VkDynamicState{
        vk.VK_DYNAMIC_STATE_VIEWPORT,
        vk.VK_DYNAMIC_STATE_SCISSOR,
    };

    var dynamicState = vk.VkPipelineDynamicStateCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = dynamicStates.len,
        .pDynamicStates = &dynamicStates,
    };

    var pipelineLayoutInfo = vk.VkPipelineLayoutCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &vkState.descriptorSetLayout,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
    };
    try initVulkanZig.vkcheck(vk.vkCreatePipelineLayout.?(vkState.logicalDevice, &pipelineLayoutInfo, null, &vkState.pipelineLayout), "Failed to create pipeline layout.");

    var pipelineInfo = vk.VkGraphicsPipelineCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = shaderStages.len,
        .pStages = &shaderStages,
        .pVertexInputState = &vertexInputInfo,
        .pInputAssemblyState = &inputAssembly,
        .pViewportState = &viewportState,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pColorBlendState = &colorBlending,
        .pDynamicState = &dynamicState,
        .layout = vkState.pipelineLayout,
        .renderPass = vkState.renderPass,
        .subpass = 0,
        .basePipelineHandle = null,
        .pNext = null,
    };
    try initVulkanZig.vkcheck(vk.vkCreateGraphicsPipelines.?(vkState.logicalDevice, null, 1, &pipelineInfo, null, &vkState.graphicsPipeline), "failed vkCreateGraphicsPipelines graphicsPipeline");
}

pub fn createVertexBuffer(vkState: *initVulkanZig.VkState, entityCount: u64, allocator: std.mem.Allocator) !void {
    if (vkState.spriteData.vertexBufferSize != 0) allocator.free(vkState.spriteData.vertices);
    vkState.spriteData.vertexBufferSize = entityCount + initVulkanZig.VkState.BUFFER_ADDITIOAL_SIZE;
    vkState.spriteData.vertices = try allocator.alloc(SpriteWithGlobalTransformVertex, vkState.spriteData.vertexBufferSize);
    try initVulkanZig.createBuffer(
        @sizeOf(SpriteWithGlobalTransformVertex) * vkState.spriteData.vertexBufferSize,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.spriteData.vertexBuffer,
        &vkState.spriteData.vertexBufferMemory,
        vkState,
    );
}
