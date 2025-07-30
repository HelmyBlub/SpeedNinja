const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");

pub const VkFontData = struct {
    vkFont: VkFont = undefined,
    graphicsPipeline: vk.VkPipeline = undefined,
    graphicsPipelineSubpass0: vk.VkPipeline = undefined,
    mipLevels: u32 = undefined,
    textureImage: vk.VkImage = undefined,
    textureImageMemory: vk.VkDeviceMemory = undefined,
    textureImageView: vk.VkImageView = undefined,
};

pub const VkFont = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []FontVertex = undefined,
    verticeCount: usize = 0,
    pub const MAX_VERTICES = 100;
};

pub const FontVertex = struct {
    pos: [2]f32,
    texX: f32,
    texWidth: f32,
    size: f32,
    color: [3]f32,

    pub fn getBindingDescription() vk.VkVertexInputBindingDescription {
        const bindingDescription: vk.VkVertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(FontVertex),
            .inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        return bindingDescription;
    }

    pub fn getAttributeDescriptions() [5]vk.VkVertexInputAttributeDescription {
        const attributeDescriptions = [_]vk.VkVertexInputAttributeDescription{ .{
            .binding = 0,
            .location = 0,
            .format = vk.VK_FORMAT_R32G32_SFLOAT,
            .offset = @offsetOf(FontVertex, "pos"),
        }, .{
            .binding = 0,
            .location = 1,
            .format = vk.VK_FORMAT_R32_SFLOAT,
            .offset = @offsetOf(FontVertex, "texX"),
        }, .{
            .binding = 0,
            .location = 2,
            .format = vk.VK_FORMAT_R32_SFLOAT,
            .offset = @offsetOf(FontVertex, "texWidth"),
        }, .{
            .binding = 0,
            .location = 3,
            .format = vk.VK_FORMAT_R32_SFLOAT,
            .offset = @offsetOf(FontVertex, "size"),
        }, .{
            .binding = 0,
            .location = 4,
            .format = vk.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = @offsetOf(FontVertex, "color"),
        } };
        return attributeDescriptions;
    }
};

fn setupVertices(state: *main.GameState) !void {
    state.vkState.font.vkFont.verticeCount = 0;
    const fontSize = 30;
    var textWidthRound: f32 = -0.2;
    textWidthRound += paintText("Round: ", .{ .x = textWidthRound, .y = -0.99 }, fontSize, &state.vkState.font.vkFont);
    textWidthRound += try paintNumber(state.round, .{ .x = textWidthRound, .y = -0.99 }, fontSize, &state.vkState.font.vkFont);
    textWidthRound += paintText(" Level: ", .{ .x = textWidthRound, .y = -0.99 }, fontSize, &state.vkState.font.vkFont);
    textWidthRound += try paintNumber(state.level, .{ .x = textWidthRound, .y = -0.99 }, fontSize, &state.vkState.font.vkFont);
    textWidthRound += paintText(" Money: $", .{ .x = textWidthRound, .y = -0.99 }, fontSize, &state.vkState.font.vkFont);
    _ = try paintNumber(state.players.items[0].money, .{ .x = textWidthRound, .y = -0.99 }, fontSize, &state.vkState.font.vkFont);

    if (state.round > 1) {
        if (state.gamePhase == .combat) {
            const textWidthTime = paintText("Time: ", .{ .x = 0, .y = -0.9 }, fontSize, &state.vkState.font.vkFont);
            const remainingTime: i64 = @max(0, @divFloor(state.roundEndTimeMS - state.gameTime, 1000));
            _ = try paintNumber(remainingTime, .{ .x = textWidthTime, .y = -0.9 }, fontSize, &state.vkState.font.vkFont);
        }
    }
    if (state.highscore > 0) {
        const textWidthTime = paintText("Highscore: ", .{ .x = 0.5, .y = -0.99 }, fontSize, &state.vkState.font.vkFont);
        _ = try paintNumber(state.highscore, .{ .x = 0.5 + textWidthTime, .y = -0.99 }, fontSize, &state.vkState.font.vkFont);
    }
    if (state.lastScore > 0) {
        const textWidthTime = paintText("last score: ", .{ .x = -0.65, .y = -0.99 }, fontSize, &state.vkState.font.vkFont);
        _ = try paintNumber(state.lastScore, .{ .x = -0.65 + textWidthTime, .y = -0.99 }, fontSize, &state.vkState.font.vkFont);
    }
    try setupVertexDataForGPU(&state.vkState);
}

/// returns vulkan surface width of text
pub fn paintText(chars: []const u8, vulkanSurfacePosition: main.Position, fontSize: f32, vkFont: *VkFont) f32 {
    var texX: f32 = 0;
    var texWidth: f32 = 0;
    var xOffset: f32 = 0;
    for (chars) |char| {
        if (vkFont.verticeCount >= vkFont.vertices.len) break;
        charToTexCoords(char, &texX, &texWidth);
        vkFont.vertices[vkFont.verticeCount] = .{
            .pos = .{ vulkanSurfacePosition.x + xOffset, vulkanSurfacePosition.y },
            .color = .{ 1, 0, 0 },
            .texX = texX,
            .texWidth = texWidth,
            .size = fontSize,
        };
        xOffset += texWidth * 1600 / windowSdlZig.windowData.widthFloat * 2 / 40 * fontSize * 0.8;
        vkFont.verticeCount += 1;
    }
    return xOffset;
}

pub fn getCharFontVertex(char: u8, vulkanSurfacePosition: main.Position, fontSize: f32) FontVertex {
    var texX: f32 = 0;
    var texWidth: f32 = 0;
    charToTexCoords(char, &texX, &texWidth);
    return .{
        .pos = .{ vulkanSurfacePosition.x, vulkanSurfacePosition.y },
        .color = .{ 1, 0, 0 },
        .texX = texX,
        .texWidth = texWidth,
        .size = fontSize,
    };
}

pub fn paintNumber(number: anytype, vulkanSurfacePosition: main.Position, fontSize: f32, vkFont: *VkFont) !f32 {
    const max_len = 20;
    var buf: [max_len]u8 = undefined;
    var numberAsString: []u8 = undefined;
    if (@TypeOf(number) == f32) {
        numberAsString = try std.fmt.bufPrint(&buf, "{d:.1}", .{number});
    } else {
        numberAsString = try std.fmt.bufPrint(&buf, "{d}", .{number});
    }

    var texX: f32 = 0;
    var texWidth: f32 = 0;
    var xOffset: f32 = 0;
    const spacingPosition = (numberAsString.len + 2) % 3;
    const spacing = 20 / windowSdlZig.windowData.widthFloat * 2 / 40 * fontSize * 0.8;
    for (numberAsString, 0..) |char, i| {
        if (vkFont.verticeCount >= vkFont.vertices.len) break;
        charToTexCoords(char, &texX, &texWidth);
        vkFont.vertices[vkFont.verticeCount] = .{
            .pos = .{ vulkanSurfacePosition.x + xOffset, vulkanSurfacePosition.y },
            .color = .{ 1, 0, 0 },
            .texX = texX,
            .texWidth = texWidth,
            .size = fontSize,
        };
        xOffset += texWidth * 1600 / windowSdlZig.windowData.widthFloat * 2 / 40 * fontSize * 0.8;
        if (i % 3 == spacingPosition) xOffset += spacing;
        vkFont.verticeCount += 1;
    }
    return xOffset;
}

pub fn initFont(state: *main.GameState) !void {
    try createGraphicsPipeline(&state.vkState, state.allocator);
    try createVertexBuffer(&state.vkState, state.allocator);
    try imageZig.createVulkanTextureImage(
        &state.vkState,
        state.allocator,
        "images/myfont.png",
        &state.vkState.font.mipLevels,
        &state.vkState.font.textureImage,
        &state.vkState.font.textureImageMemory,
        null,
    );
    state.vkState.font.textureImageView = try initVulkanZig.createImageView(
        state.vkState.font.textureImage,
        vk.VK_FORMAT_R8G8B8A8_SRGB,
        state.vkState.font.mipLevels,
        vk.VK_IMAGE_ASPECT_COLOR_BIT,
        &state.vkState,
    );
}

pub fn destroyFont(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    vk.vkDestroyImageView.?(vkState.logicalDevice, vkState.font.textureImageView, null);
    vk.vkDestroyImage.?(vkState.logicalDevice, vkState.font.textureImage, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, vkState.font.textureImageMemory, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, vkState.font.vkFont.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, vkState.font.vkFont.vertexBufferMemory, null);
    vk.vkDestroyPipeline.?(vkState.logicalDevice, vkState.font.graphicsPipeline, null);
    vk.vkDestroyPipeline.?(vkState.logicalDevice, vkState.font.graphicsPipelineSubpass0, null);
    allocator.free(vkState.font.vkFont.vertices);
}

fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, vkState.font.vkFont.vertexBufferMemory, 0, @sizeOf(FontVertex) * vkState.font.vkFont.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpu_vertices: [*]FontVertex = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, vkState.font.vkFont.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, vkState.font.vkFont.vertexBufferMemory);
}

pub fn recordFontCommandBuffer(commandBuffer: vk.VkCommandBuffer, state: *main.GameState) !void {
    try setupVertices(state);
    const vkState = &state.vkState;

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.font.graphicsPipeline);
    const vertexBuffers: [1]vk.VkBuffer = .{vkState.font.vkFont.vertexBuffer};
    const offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(vkState.font.vkFont.verticeCount), 1, 0, 0);
}

pub fn charToTexCoords(char: u8, texX: *f32, texWidth: *f32) void {
    const fontImageWidth = 1600.0;
    const imageCharSeperatePixels = [_]f32{ 0, 50, 88, 117, 142, 170, 198, 232, 262, 277, 307, 338, 365, 413, 445, 481, 508, 541, 569, 603, 638, 674, 711, 760, 801, 837, 873, 902, 931, 968, 1003, 1037, 1072, 1104, 1142, 1175, 1205, 1238, 1282, 1302, 1322, 1367, 1410, 1448 };
    var index: usize = 0;
    switch (char) {
        'a', 'A' => {
            index = 0;
        },
        'b', 'B' => {
            index = 1;
        },
        'c', 'C' => {
            index = 2;
        },
        'd', 'D' => {
            index = 3;
        },
        'e', 'E' => {
            index = 4;
        },
        'f', 'F' => {
            index = 5;
        },
        'g', 'G' => {
            index = 6;
        },
        'h', 'H' => {
            index = 7;
        },
        'i', 'I' => {
            index = 8;
        },
        'j', 'J' => {
            index = 9;
        },
        'k', 'K' => {
            index = 10;
        },
        'l', 'L' => {
            index = 11;
        },
        'm', 'M' => {
            index = 12;
        },
        'n', 'N' => {
            index = 13;
        },
        'o', 'O' => {
            index = 14;
        },
        'p', 'P' => {
            index = 15;
        },
        'q', 'Q' => {
            index = 16;
        },
        'r', 'R' => {
            index = 17;
        },
        's', 'S' => {
            index = 18;
        },
        't', 'T' => {
            index = 19;
        },
        'u', 'U' => {
            index = 20;
        },
        'v', 'V' => {
            index = 21;
        },
        'w', 'W' => {
            index = 22;
        },
        'x', 'X' => {
            index = 23;
        },
        'y', 'Y' => {
            index = 24;
        },
        'z', 'Z' => {
            index = 25;
        },
        '0' => {
            index = 26;
        },
        '1' => {
            index = 27;
        },
        '2' => {
            index = 28;
        },
        '3' => {
            index = 29;
        },
        '4' => {
            index = 30;
        },
        '5' => {
            index = 31;
        },
        '6' => {
            index = 32;
        },
        '7' => {
            index = 33;
        },
        '8' => {
            index = 34;
        },
        '9' => {
            index = 35;
        },
        ':' => {
            index = 36;
        },
        '%' => {
            index = 37;
        },
        ' ' => {
            index = 38;
        },
        '.' => {
            index = 39;
        },
        '+' => {
            index = 40;
        },
        '-' => {
            index = 41;
        },
        '$' => {
            index = 42;
        },
        else => {
            texX.* = 0;
            texWidth.* = 1;
        },
    }
    texX.* = imageCharSeperatePixels[index] / fontImageWidth;
    texWidth.* = (imageCharSeperatePixels[index + 1] - imageCharSeperatePixels[index]) / fontImageWidth;
}

fn createVertexBuffer(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    vkState.font.vkFont.vertices = try allocator.alloc(FontVertex, VkFont.MAX_VERTICES);
    try initVulkanZig.createBuffer(
        @sizeOf(FontVertex) * vkState.font.vkFont.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.font.vkFont.vertexBuffer,
        &vkState.font.vkFont.vertexBufferMemory,
        vkState,
    );
}

fn createGraphicsPipeline(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    const vertShaderCode = try initVulkanZig.readShaderFile("shaders/fontVert.spv", allocator);
    defer allocator.free(vertShaderCode);
    const vertShaderModule = try initVulkanZig.createShaderModule(vertShaderCode, vkState);
    defer vk.vkDestroyShaderModule.?(vkState.logicalDevice, vertShaderModule, null);
    const vertShaderStageInfo = vk.VkPipelineShaderStageCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = vk.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertShaderModule,
        .pName = "main",
    };

    const fragShaderCode = try initVulkanZig.readShaderFile("shaders/fontFrag.spv", allocator);
    defer allocator.free(fragShaderCode);
    const fragShaderModule = try initVulkanZig.createShaderModule(fragShaderCode, vkState);
    defer vk.vkDestroyShaderModule.?(vkState.logicalDevice, fragShaderModule, null);
    const fragShaderStageInfo = vk.VkPipelineShaderStageCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = fragShaderModule,
        .pName = "main",
    };

    const geomShaderCode = try initVulkanZig.readShaderFile("shaders/fontGeom.spv", allocator);
    defer allocator.free(geomShaderCode);
    const geomShaderModule = try initVulkanZig.createShaderModule(geomShaderCode, vkState);
    defer vk.vkDestroyShaderModule.?(vkState.logicalDevice, geomShaderModule, null);
    const geomShaderStageInfo = vk.VkPipelineShaderStageCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = vk.VK_SHADER_STAGE_GEOMETRY_BIT,
        .module = geomShaderModule,
        .pName = "main",
    };

    const shaderStages = [_]vk.VkPipelineShaderStageCreateInfo{ vertShaderStageInfo, fragShaderStageInfo, geomShaderStageInfo };
    const bindingDescription = FontVertex.getBindingDescription();
    const attributeDescriptions = FontVertex.getAttributeDescriptions();
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
        .subpass = 2,
        .basePipelineHandle = null,
        .pNext = null,
    };
    if (vk.vkCreateGraphicsPipelines.?(vkState.logicalDevice, null, 1, &pipelineInfo, null, &vkState.font.graphicsPipeline) != vk.VK_SUCCESS) return error.createGraphicsPipeline;

    var pipelineInfoSubpass0 = vk.VkGraphicsPipelineCreateInfo{
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
    if (vk.vkCreateGraphicsPipelines.?(vkState.logicalDevice, null, 1, &pipelineInfoSubpass0, null, &vkState.font.graphicsPipelineSubpass0) != vk.VK_SUCCESS) return error.createGraphicsPipeline;
}
