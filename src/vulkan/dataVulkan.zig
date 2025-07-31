const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;

pub const VkCameraData = struct {
    transform: [4][4]f32,
    translate: [2]f32,
};

pub const LAYER1_INDEX_GROUND = 0;
pub const LAYER2_INDEX = 1;
pub const LAYER3_INDEX_UX = 2;

pub const VkVerticeDataCut = struct {
    triangle: usize,
    lines: usize,
    sprites: usize,
    spritesComplex: usize,
    font: usize,
};

pub const VkVerticeData = struct {
    dataDrawCut: std.ArrayList(VkVerticeDataCut) = undefined,
    triangles: VkColoredVertexes = .{},
    lines: VkColoredVertexes = .{},
    sprites: VkSprites = .{},
    spritesComplex: VkSpriteComplex = .{},
    font: VkFont = .{},
};

pub const VkColoredVertexes = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []ColoredVertex = undefined,
    verticeCount: usize = 0,
    vertexBufferCleanUp: []?vk.VkBuffer = undefined,
    vertexBufferMemoryCleanUp: []?vk.VkDeviceMemory = undefined,
};

pub const VkSprites = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []SpriteVertex = undefined,
    verticeCount: usize = 0,
    vertexBufferCleanUp: []?vk.VkBuffer = undefined,
    vertexBufferMemoryCleanUp: []?vk.VkDeviceMemory = undefined,
};

pub const VkSpriteComplex = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []SpriteComplexVertex = undefined,
    verticeCount: usize = 0,
    vertexBufferCleanUp: []?vk.VkBuffer = undefined,
    vertexBufferMemoryCleanUp: []?vk.VkDeviceMemory = undefined,
};

pub const VkFont = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []FontVertex = undefined,
    verticeCount: usize = 0,
    vertexBufferCleanUp: []?vk.VkBuffer = undefined,
    vertexBufferMemoryCleanUp: []?vk.VkDeviceMemory = undefined,
};

pub const SpriteVertex = struct {
    pos: [2]f32,
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
        attributeDescriptions[0].format = vk.VK_FORMAT_R32G32_SFLOAT;
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

pub const SpriteComplexVertex = struct {
    pos: [2]f32,
    tex: [2]f32,
    alpha: f32,
    imageIndex: u8,

    pub fn getBindingDescription() vk.VkVertexInputBindingDescription {
        const bindingDescription: vk.VkVertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(SpriteComplexVertex),
            .inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        return bindingDescription;
    }

    pub fn getAttributeDescriptions() [4]vk.VkVertexInputAttributeDescription {
        var attributeDescriptions: [4]vk.VkVertexInputAttributeDescription = .{ undefined, undefined, undefined, undefined };
        attributeDescriptions[0].binding = 0;
        attributeDescriptions[0].location = 0;
        attributeDescriptions[0].format = vk.VK_FORMAT_R32G32_SFLOAT;
        attributeDescriptions[0].offset = @offsetOf(SpriteComplexVertex, "pos");
        attributeDescriptions[1].binding = 0;
        attributeDescriptions[1].location = 1;
        attributeDescriptions[1].format = vk.VK_FORMAT_R32G32_SFLOAT;
        attributeDescriptions[1].offset = @offsetOf(SpriteComplexVertex, "tex");
        attributeDescriptions[2].binding = 0;
        attributeDescriptions[2].location = 2;
        attributeDescriptions[2].format = vk.VK_FORMAT_R32_SFLOAT;
        attributeDescriptions[2].offset = @offsetOf(SpriteComplexVertex, "alpha");
        attributeDescriptions[3].binding = 0;
        attributeDescriptions[3].location = 3;
        attributeDescriptions[3].format = vk.VK_FORMAT_R8_UINT;
        attributeDescriptions[3].offset = @offsetOf(SpriteComplexVertex, "imageIndex");
        return attributeDescriptions;
    }
};

pub const ColoredVertex = struct {
    pos: [2]f32,
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
        attributeDescriptions[0].format = vk.VK_FORMAT_R32G32_SFLOAT;
        attributeDescriptions[0].offset = @offsetOf(ColoredVertex, "pos");
        attributeDescriptions[1].binding = 0;
        attributeDescriptions[1].location = 1;
        attributeDescriptions[1].format = vk.VK_FORMAT_R32G32B32_SFLOAT;
        attributeDescriptions[1].offset = @offsetOf(ColoredVertex, "color");
        return attributeDescriptions;
    }
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
