const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;

pub const VkCameraData = struct {
    translate: [2]f64,
    transform: [4][4]f32,
};

pub const VkTriangles = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []ColoredVertex = undefined,
    verticeCount: usize = 0,
};

pub const VkLines = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []ColoredVertex = undefined,
    verticeCount: usize = 0,
};

pub const VkSprites = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []SpriteVertex = undefined,
    verticeCount: usize = 0,
};

pub const SpriteWithGlobalTransformVertex = struct {
    pos: [2]f64,
    imageIndex: u8,
    size: u8,
    rotate: f32,
    /// 0 => nothing cut, 1 => nothing left
    cutY: f32,

    pub fn getBindingDescription() vk.VkVertexInputBindingDescription {
        const bindingDescription: vk.VkVertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(SpriteWithGlobalTransformVertex),
            .inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        return bindingDescription;
    }

    pub fn getAttributeDescriptions() [5]vk.VkVertexInputAttributeDescription {
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
pub const SpriteVertex = struct {
    pos: [2]f64,
    imageIndex: u8,
    width: f32,
    height: f32,

    pub fn getBindingDescription() vk.VkVertexInputBindingDescription {
        const bindingDescription: vk.VkVertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(SpriteVertex),
            .inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        return bindingDescription;
    }

    pub fn getAttributeDescriptions() [4]vk.VkVertexInputAttributeDescription {
        var attributeDescriptions: [4]vk.VkVertexInputAttributeDescription = .{ undefined, undefined, undefined, undefined };
        attributeDescriptions[0].binding = 0;
        attributeDescriptions[0].location = 0;
        attributeDescriptions[0].format = vk.VK_FORMAT_R64G64_SFLOAT;
        attributeDescriptions[0].offset = @offsetOf(SpriteVertex, "pos");
        attributeDescriptions[1].binding = 0;
        attributeDescriptions[1].location = 1;
        attributeDescriptions[1].format = vk.VK_FORMAT_R8_UINT;
        attributeDescriptions[1].offset = @offsetOf(SpriteVertex, "imageIndex");
        attributeDescriptions[2].binding = 0;
        attributeDescriptions[2].location = 2;
        attributeDescriptions[2].format = vk.VK_FORMAT_R32_SFLOAT;
        attributeDescriptions[2].offset = @offsetOf(SpriteVertex, "width");
        attributeDescriptions[3].binding = 0;
        attributeDescriptions[3].location = 3;
        attributeDescriptions[3].format = vk.VK_FORMAT_R32_SFLOAT;
        attributeDescriptions[3].offset = @offsetOf(SpriteVertex, "height");
        return attributeDescriptions;
    }
};

pub const ColoredVertex = struct {
    pos: [2]f64,
    color: [3]f32,

    pub fn getBindingDescription() vk.VkVertexInputBindingDescription {
        const bindingDescription: vk.VkVertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(ColoredVertex),
            .inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        return bindingDescription;
    }

    pub fn getAttributeDescriptions() [2]vk.VkVertexInputAttributeDescription {
        var attributeDescriptions: [2]vk.VkVertexInputAttributeDescription = .{ undefined, undefined };
        attributeDescriptions[0].binding = 0;
        attributeDescriptions[0].location = 0;
        attributeDescriptions[0].format = vk.VK_FORMAT_R64G64_SFLOAT;
        attributeDescriptions[0].offset = @offsetOf(ColoredVertex, "pos");
        attributeDescriptions[1].binding = 0;
        attributeDescriptions[1].location = 1;
        attributeDescriptions[1].format = vk.VK_FORMAT_R32G32B32_SFLOAT;
        attributeDescriptions[1].offset = @offsetOf(ColoredVertex, "color");
        return attributeDescriptions;
    }
};

pub const SpriteData = struct {
    vertices: []SpriteWithGlobalTransformVertex = undefined,
    verticeUsedCount: usize = 0,
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
};
