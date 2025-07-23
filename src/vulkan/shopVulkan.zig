const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const dataVulkanZig = @import("dataVulkan.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const movePieceZig = @import("../movePiece.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const shopZig = @import("../shop.zig");

pub const VkShopUx = struct {
    triangles: dataVulkanZig.VkTriangles = undefined,
    lines: dataVulkanZig.VkLines = undefined,
    sprites: dataVulkanZig.VkSpritesWithGlobalTransform = undefined,
    font: fontVulkanZig.VkFont = undefined,
    const UX_RECTANGLES = 100;
    pub const MAX_VERTICES_TRIANGLES = 6 * UX_RECTANGLES;
    pub const MAX_VERTICES_LINES = 8 * UX_RECTANGLES;
    pub const MAX_VERTICES_SPRITES = UX_RECTANGLES;
    pub const MAX_VERTICES_FONT = 50;
};

pub fn setupVertices(state: *main.GameState) !void {
    const shopUx = &state.vkState.shopUx;
    shopUx.lines.verticeCount = 0;
    shopUx.triangles.verticeCount = 0;
    shopUx.sprites.verticeCount = 0;
    shopUx.font.verticeCount = 0;
    if (state.gamePhase != .shopping) return;
    paintGrid(&state.players.items[0], state);
    const player0ShopPos = state.players.items[0].shop.pieceShopTopLeft;
    for (shopZig.SHOP_BUTTONS) |shopButton| {
        const shopButtonGamePosition: main.Position = .{
            .x = @floatFromInt((player0ShopPos.x + shopButton.tileOffset.x) * main.TILESIZE),
            .y = @floatFromInt((player0ShopPos.y + shopButton.tileOffset.y) * main.TILESIZE),
        };
        if (shopButton.option != .none and shopButton.option == state.players.items[0].shop.selectedOption) {
            rectangleForTile(shopButtonGamePosition, .{ 0, 0, 1 }, shopUx, false, state);
        }
        shopUx.sprites.vertices[shopUx.sprites.verticeCount] = .{
            .pos = .{ shopButtonGamePosition.x, shopButtonGamePosition.y },
            .imageIndex = shopButton.imageIndex,
            .size = main.TILESIZE,
            .rotate = shopButton.imageRotate,
            .cutY = 0,
        };
        shopUx.sprites.verticeCount += 1;
    }

    try setupVertexDataForGPU(&state.vkState);
}

fn paintGrid(player: *main.Player, state: *main.GameState) void {
    const shopUx = &state.vkState.shopUx;

    const player0ShopPos = player.shop.pieceShopTopLeft;
    const gridGameTopLeft: main.Position = .{
        .x = @floatFromInt((player0ShopPos.x + shopZig.GRID_OFFSET.x) * main.TILESIZE),
        .y = @floatFromInt((player0ShopPos.y + shopZig.GRID_OFFSET.y) * main.TILESIZE),
    };
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const size = main.TILESIZE * shopZig.GRID_SIZE;

    const vulkan: main.Position = .{
        .x = (-state.camera.position.x + gridGameTopLeft.x) * state.camera.zoom * onePixelXInVulkan,
        .y = (-state.camera.position.y + gridGameTopLeft.y) * state.camera.zoom * onePixelYInVulkan,
    };
    const halveVulkanTileSizeX = main.TILESIZE * onePixelXInVulkan * state.camera.zoom / 2;
    const halveVulkanTileSizeY = main.TILESIZE * onePixelYInVulkan * state.camera.zoom / 2;
    const width = size * onePixelXInVulkan * state.camera.zoom;
    const height = size * onePixelYInVulkan * state.camera.zoom;
    const left = vulkan.x - halveVulkanTileSizeX;
    const top = vulkan.y - halveVulkanTileSizeY;

    const triangles = &shopUx.triangles;
    const fillColor: [3]f32 = .{ 1, 1, 1 };
    triangles.vertices[triangles.verticeCount] = .{ .pos = .{ left, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ left, top + height }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 3] = .{ .pos = .{ left, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 4] = .{ .pos = .{ left + width, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 5] = .{ .pos = .{ left + width, top + height }, .color = fillColor };
    triangles.verticeCount += 6;

    paintMovePieceInGrid(player, gridGameTopLeft, state);
}

fn paintMovePieceInGrid(player: *main.Player, gridGameTopLeft: main.Position, state: *main.GameState) void {
    const shopUx = &state.vkState.shopUx;
    if (player.shop.gridDisplayPiece == null) return;
    const gridDisplayPiece = player.shop.gridDisplayPiece.?;
    var x: i8 = 4;
    var y: i8 = 4;
    rectangleForTile(.{
        .x = gridGameTopLeft.x + @as(f32, @floatFromInt(x)) * main.TILESIZE,
        .y = gridGameTopLeft.y + @as(f32, @floatFromInt(y)) * main.TILESIZE,
    }, .{ 0, 0, 1 }, shopUx, true, state);
    for (gridDisplayPiece.steps) |step| {
        const stepX: i8 = if (step.direction == 0) 1 else if (step.direction == 2) -1 else 0;
        const stepY: i8 = if (step.direction == 1) 1 else if (step.direction == 3) -1 else 0;
        for (0..step.stepCount) |_| {
            x += stepX;
            y += stepY;
            rectangleForTile(.{
                .x = gridGameTopLeft.x + @as(f32, @floatFromInt(x)) * main.TILESIZE,
                .y = gridGameTopLeft.y + @as(f32, @floatFromInt(y)) * main.TILESIZE,
            }, .{ 0.25, 0.25, 0.25 }, shopUx, true, state);
        }
    }
}

fn rectangleForTile(gamePosition: main.Position, fillColor: [3]f32, shopUx: *VkShopUx, withOutline: bool, state: *main.GameState) void {
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const size = main.TILESIZE;

    const vulkan: main.Position = .{
        .x = (-state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
        .y = (-state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
    };
    const width = size * onePixelXInVulkan * state.camera.zoom;
    const height = size * onePixelYInVulkan * state.camera.zoom;
    const left = vulkan.x - width / 2;
    const top = vulkan.y - height / 2;

    const triangles = &shopUx.triangles;
    triangles.vertices[triangles.verticeCount] = .{ .pos = .{ left, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ left + width, top + height }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ left, top + height }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 3] = .{ .pos = .{ left, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 4] = .{ .pos = .{ left + width, top }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 5] = .{ .pos = .{ left + width, top + height }, .color = fillColor };
    triangles.verticeCount += 6;
    if (withOutline) {
        const borderColor: [3]f32 = .{ 0, 0, 0 };
        const lines = &shopUx.lines;
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ left, top }, .color = borderColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ left + width, top }, .color = borderColor };
        lines.vertices[lines.verticeCount + 2] = .{ .pos = .{ left, top }, .color = borderColor };
        lines.vertices[lines.verticeCount + 3] = .{ .pos = .{ left, top + height }, .color = borderColor };
        lines.vertices[lines.verticeCount + 4] = .{ .pos = .{ left + width, top }, .color = borderColor };
        lines.vertices[lines.verticeCount + 5] = .{ .pos = .{ left + width, top + height }, .color = borderColor };
        lines.vertices[lines.verticeCount + 6] = .{ .pos = .{ left, top + height }, .color = borderColor };
        lines.vertices[lines.verticeCount + 7] = .{ .pos = .{ left + width, top + height }, .color = borderColor };
        lines.verticeCount += 8;
    }
}

pub fn create(state: *main.GameState) !void {
    try createVertexBuffers(&state.vkState, state.allocator);
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    const shopUx = &vkState.shopUx;
    vk.vkDestroyBuffer.?(vkState.logicalDevice, shopUx.triangles.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, shopUx.lines.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, shopUx.sprites.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, shopUx.font.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, shopUx.triangles.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, shopUx.lines.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, shopUx.sprites.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, shopUx.font.vertexBufferMemory, null);
    allocator.free(shopUx.triangles.vertices);
    allocator.free(shopUx.lines.vertices);
    allocator.free(shopUx.sprites.vertices);
    allocator.free(shopUx.font.vertices);
}

fn createVertexBuffers(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    const shopUx = &vkState.shopUx;
    shopUx.triangles.vertices = try allocator.alloc(dataVulkanZig.ColoredVertex, VkShopUx.MAX_VERTICES_TRIANGLES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.ColoredVertex) * VkShopUx.MAX_VERTICES_TRIANGLES,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &shopUx.triangles.vertexBuffer,
        &shopUx.triangles.vertexBufferMemory,
        vkState,
    );
    shopUx.lines.vertices = try allocator.alloc(dataVulkanZig.ColoredVertex, VkShopUx.MAX_VERTICES_LINES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.ColoredVertex) * VkShopUx.MAX_VERTICES_LINES,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &shopUx.lines.vertexBuffer,
        &shopUx.lines.vertexBufferMemory,
        vkState,
    );
    shopUx.sprites.vertices = try allocator.alloc(dataVulkanZig.SpriteWithGlobalTransformVertex, VkShopUx.MAX_VERTICES_SPRITES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.SpriteWithGlobalTransformVertex) * VkShopUx.MAX_VERTICES_SPRITES,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &shopUx.sprites.vertexBuffer,
        &shopUx.sprites.vertexBufferMemory,
        vkState,
    );
    shopUx.font.vertices = try allocator.alloc(fontVulkanZig.FontVertex, VkShopUx.MAX_VERTICES_FONT);
    try initVulkanZig.createBuffer(
        @sizeOf(fontVulkanZig.FontVertex) * shopUx.font.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &shopUx.font.vertexBuffer,
        &shopUx.font.vertexBufferMemory,
        vkState,
    );
}

fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    const shopUx = &vkState.shopUx;
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, shopUx.triangles.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.ColoredVertex) * shopUx.triangles.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    var gpu_vertices: [*]dataVulkanZig.ColoredVertex = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, shopUx.triangles.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, shopUx.triangles.vertexBufferMemory);

    if (vk.vkMapMemory.?(vkState.logicalDevice, shopUx.lines.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.ColoredVertex) * shopUx.lines.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    gpu_vertices = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, shopUx.lines.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, shopUx.lines.vertexBufferMemory);

    if (vk.vkMapMemory.?(vkState.logicalDevice, shopUx.sprites.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.SpriteWithGlobalTransformVertex) * shopUx.sprites.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpuVerticesSprite: [*]dataVulkanZig.SpriteWithGlobalTransformVertex = @ptrCast(@alignCast(data));
    @memcpy(gpuVerticesSprite, shopUx.sprites.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, shopUx.sprites.vertexBufferMemory);

    if (vk.vkMapMemory.?(vkState.logicalDevice, shopUx.font.vertexBufferMemory, 0, @sizeOf(fontVulkanZig.FontVertex) * shopUx.font.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpuVerticesFont: [*]fontVulkanZig.FontVertex = @ptrCast(@alignCast(data));
    @memcpy(gpuVerticesFont, shopUx.font.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, shopUx.font.vertexBufferMemory);
}

pub fn recordCommandBuffer(commandBuffer: vk.VkCommandBuffer, state: *main.GameState) !void {
    try setupVertices(state);
    const shopUx = &state.vkState.shopUx;
    const vkState = &state.vkState;
    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.triangleSubpass0);
    var vertexBuffers: [1]vk.VkBuffer = .{shopUx.triangles.vertexBuffer};
    var offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(shopUx.triangles.verticeCount), 1, 0, 0);

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.spriteWithGlobalTransform);
    vertexBuffers = .{shopUx.sprites.vertexBuffer};
    offsets = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(shopUx.sprites.verticeCount), 1, 0, 0);

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.linesSubpass0);
    vertexBuffers = .{shopUx.lines.vertexBuffer};
    offsets = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(shopUx.lines.verticeCount), 1, 0, 0);

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.font.graphicsPipelineSubpass0);
    vertexBuffers = .{shopUx.font.vertexBuffer};
    offsets = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(shopUx.font.verticeCount), 1, 0, 0);
}
