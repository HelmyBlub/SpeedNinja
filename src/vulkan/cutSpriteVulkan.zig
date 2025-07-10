const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");

pub const VkCutSpriteData = struct {
    vkCutSprite: VkCutSprite = .{},
    graphicsPipeline: vk.VkPipeline = undefined,
};

pub const VkCutSprite = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []CutSpriteVertex = undefined,
    verticeCount: usize = 0,
    pub const MAX_VERTICES = 50;
};

pub const CutSpriteVertex = struct {
    pos: [2]f64,
    imageIndex: u8,
    size: u8,
    cutAngle: f32,
    animationPerCent: f32,

    pub fn getBindingDescription() vk.VkVertexInputBindingDescription {
        const bindingDescription: vk.VkVertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(CutSpriteVertex),
            .inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        return bindingDescription;
    }

    pub fn getAttributeDescriptions() [5]vk.VkVertexInputAttributeDescription {
        const attributeDescriptions = [_]vk.VkVertexInputAttributeDescription{ .{
            .binding = 0,
            .location = 0,
            .format = vk.VK_FORMAT_R64G64_SFLOAT,
            .offset = @offsetOf(CutSpriteVertex, "pos"),
        }, .{
            .binding = 0,
            .location = 1,
            .format = vk.VK_FORMAT_R8_UINT,
            .offset = @offsetOf(CutSpriteVertex, "imageIndex"),
        }, .{
            .binding = 0,
            .location = 2,
            .format = vk.VK_FORMAT_R8_UINT,
            .offset = @offsetOf(CutSpriteVertex, "size"),
        }, .{
            .binding = 0,
            .location = 3,
            .format = vk.VK_FORMAT_R32_SFLOAT,
            .offset = @offsetOf(CutSpriteVertex, "cutAngle"),
        }, .{
            .binding = 0,
            .location = 4,
            .format = vk.VK_FORMAT_R32_SFLOAT,
            .offset = @offsetOf(CutSpriteVertex, "animationPerCent"),
        } };
        return attributeDescriptions;
    }
};

fn setupVertices(state: *main.GameState) !void {
    const cutSprite = &state.vkState.cutSpriteData.vkCutSprite;
    cutSprite.verticeCount = 0;
    for (state.enemyDeath.items) |enemyDeath| {
        cutSprite.vertices[cutSprite.verticeCount] = CutSpriteVertex{
            .pos = .{ enemyDeath.position.x, enemyDeath.position.y },
            .animationPerCent = 0,
            .cutAngle = 0,
            .imageIndex = imageZig.IMAGE_EVIL_TREE,
            .size = 20,
        };
        cutSprite.verticeCount += 1;
    }

    try setupVertexDataForGPU(&state.vkState);
}

pub fn create(state: *main.GameState) !void {
    try createGraphicsPipeline(&state.vkState, state.allocator);
    try createVertexBuffer(&state.vkState, state.allocator);
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    const cutSprite = vkState.cutSpriteData;
    vk.vkDestroyBuffer.?(vkState.logicalDevice, cutSprite.vkCutSprite.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, cutSprite.vkCutSprite.vertexBufferMemory, null);
    vk.vkDestroyPipeline.?(vkState.logicalDevice, cutSprite.graphicsPipeline, null);
    allocator.free(cutSprite.vkCutSprite.vertices);
}

fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    const cutSprite = vkState.cutSpriteData;
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, cutSprite.vkCutSprite.vertexBufferMemory, 0, @sizeOf(CutSpriteVertex) * cutSprite.vkCutSprite.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpu_vertices: [*]CutSpriteVertex = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, cutSprite.vkCutSprite.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, cutSprite.vkCutSprite.vertexBufferMemory);
}

pub fn recordCommandBuffer(commandBuffer: vk.VkCommandBuffer, state: *main.GameState) !void {
    try setupVertices(state);
    const vkState = &state.vkState;

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.cutSpriteData.graphicsPipeline);
    const vertexBuffers: [1]vk.VkBuffer = .{vkState.cutSpriteData.vkCutSprite.vertexBuffer};
    const offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(vkState.cutSpriteData.vkCutSprite.verticeCount), 1, 0, 0);
}

fn createVertexBuffer(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    vkState.cutSpriteData.vkCutSprite.vertices = try allocator.alloc(CutSpriteVertex, VkCutSprite.MAX_VERTICES);
    try initVulkanZig.createBuffer(
        @sizeOf(CutSpriteVertex) * vkState.cutSpriteData.vkCutSprite.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.cutSpriteData.vkCutSprite.vertexBuffer,
        &vkState.cutSpriteData.vkCutSprite.vertexBufferMemory,
        vkState,
    );
}

fn createGraphicsPipeline(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    const vertShaderCode = try initVulkanZig.readShaderFile("shaders/cutSpriteVert.spv", allocator);
    defer allocator.free(vertShaderCode);
    const fragShaderCode = try initVulkanZig.readShaderFile("shaders/imageFrag.spv", allocator);
    defer allocator.free(fragShaderCode);
    const geomShaderCode = try initVulkanZig.readShaderFile("shaders/cutSpriteGeom.spv", allocator);
    defer allocator.free(geomShaderCode);
    const vertShaderModule = try initVulkanZig.createShaderModule(vertShaderCode, vkState);
    defer vk.vkDestroyShaderModule.?(vkState.logicalDevice, vertShaderModule, null);
    const fragShaderModule = try initVulkanZig.createShaderModule(fragShaderCode, vkState);
    defer vk.vkDestroyShaderModule.?(vkState.logicalDevice, fragShaderModule, null);
    const geomCitizenComplexShaderModule = try initVulkanZig.createShaderModule(geomShaderCode, vkState);
    defer vk.vkDestroyShaderModule.?(vkState.logicalDevice, geomCitizenComplexShaderModule, null);

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
        .module = geomCitizenComplexShaderModule,
        .pName = "main",
    };

    const shaderStagesCitizenComplex = [_]vk.VkPipelineShaderStageCreateInfo{ vertShaderStageInfo, fragShaderStageInfo, geomShaderStageInfo };
    const bindingDescription = CutSpriteVertex.getBindingDescription();
    const attributeDescriptions = CutSpriteVertex.getAttributeDescriptions();
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

    var pipelineInfoCitizenComplex = vk.VkGraphicsPipelineCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = shaderStagesCitizenComplex.len,
        .pStages = &shaderStagesCitizenComplex,
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
    if (vk.vkCreateGraphicsPipelines.?(vkState.logicalDevice, null, 1, &pipelineInfoCitizenComplex, null, &vkState.cutSpriteData.graphicsPipeline) != vk.VK_SUCCESS) return error.citizenGraphicsPipeline;
}
