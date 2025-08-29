const std = @import("std");
const main = @import("main.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const windowSdlZig = @import("windowSdl.zig");

pub const MapTileType = enum {
    normal,
    ice,
    wall,
};

pub const MapType = enum {
    top,
    default,
};

pub const MapData = struct {
    paintData: PaintData = .{},
    tiles: []MapTileType,
    tileRadius: u32,
    mapType: MapType = .default,
};

pub const Cloud = struct {
    sizeFactor: f32 = 0,
    speed: f32 = 0,
    position: main.Position = .{ .x = 2000, .y = 0 },
};

pub const PaintData = struct {
    backgroundColor: [3]f32 = main.COLOR_TILE_GREEN,
    backClouds: [3]Cloud = .{ .{}, .{}, .{} },
    frontCloud: Cloud = .{},
};

pub const BASE_MAP_TILE_RADIUS = 3;

pub fn setMapType(mapType: MapType, state: *main.GameState) void {
    state.mapData.mapType = mapType;
    switch (mapType) {
        .default => state.mapData.paintData.backgroundColor = main.COLOR_TILE_GREEN,
        .top => {
            state.mapData.paintData.backgroundColor = main.COLOR_SKY_BLUE;
            for (state.mapData.paintData.backClouds[0..]) |*backCloud| {
                backCloud.position.x = -500 + std.crypto.random.float(f32) * 1000;
                backCloud.position.y = -150 + std.crypto.random.float(f32) * 150;
                backCloud.sizeFactor = 5;
                backCloud.speed = 0.02;
            }
        },
    }
}

pub fn createMapData(allocator: std.mem.Allocator) !MapData {
    const tileLength = (BASE_MAP_TILE_RADIUS * 2 + 1);
    const tiles = try allocator.alloc(MapTileType, tileLength * tileLength);
    resetMapTiles(tiles);
    return MapData{
        .tileRadius = BASE_MAP_TILE_RADIUS,
        .tiles = tiles,
    };
}

pub fn deinit(state: *main.GameState) void {
    state.allocator.free(state.mapData.tiles);
}

pub fn getMapTilePositionType(tile: main.TilePosition, mapData: *MapData) MapTileType {
    const index = tilePositionToTileIndex(tile, mapData.tileRadius);
    if (index == null or index.? >= mapData.tiles.len) return .normal;
    return mapData.tiles[index.?];
}

pub fn setMapTilePositionType(tile: main.TilePosition, tileType: MapTileType, mapData: *MapData) void {
    const index = tilePositionToTileIndex(tile, mapData.tileRadius);
    if (index == null or index.? >= mapData.tiles.len) return;
    mapData.tiles[index.?] = tileType;
}

fn tilePositionToTileIndex(tilePosition: main.TilePosition, tileRadius: u32) ?usize {
    const iTileRadius = @as(i32, @intCast(tileRadius));
    const tileLength = (tileRadius * 2 + 1);
    if (@abs(tilePosition.x) > iTileRadius) return null;
    if (@abs(tilePosition.y) > iTileRadius) return null;
    return @as(u32, @intCast(tilePosition.x + iTileRadius)) + @as(u32, @intCast(tilePosition.y + iTileRadius)) * tileLength;
}

fn tileIndexToTilePosition(tileIndex: usize, tileRadius: u32) main.TilePosition {
    const iTileRadius = @as(i32, @intCast(tileRadius));
    const tileLength = (tileRadius * 2 + 1);
    return main.TilePosition{
        .x = @as(i32, @intCast(@mod(tileIndex, tileLength))) - iTileRadius,
        .y = @as(i32, @intCast(@divFloor(tileIndex, tileLength))) - iTileRadius,
    };
}

pub fn setMapRadius(tileRadius: u32, state: *main.GameState) !void {
    if (tileRadius == state.mapData.tileRadius) return;
    const tileLength = (tileRadius * 2 + 1);
    const tiles = try state.allocator.alloc(MapTileType, tileLength * tileLength);
    resetMapTiles(tiles);
    for (0..state.mapData.tiles.len) |oldTileIndex| {
        const tilePosition = tileIndexToTilePosition(oldTileIndex, state.mapData.tileRadius);
        const newTileIndex = tilePositionToTileIndex(tilePosition, tileRadius);
        if (newTileIndex == null or newTileIndex.? >= tiles.len) continue;
        tiles[newTileIndex.?] = state.mapData.tiles[oldTileIndex];
    }
    state.mapData.tileRadius = tileRadius;
    state.allocator.free(state.mapData.tiles);
    state.mapData.tiles = tiles;
}

pub fn resetMapTiles(tiles: []MapTileType) void {
    for (0..tiles.len) |i| {
        tiles[i] = .normal;
    }
}

pub fn setupVertices(state: *main.GameState) void {
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const width = onePixelXInVulkan * main.TILESIZE * state.camera.zoom;
    const height = onePixelYInVulkan * main.TILESIZE * state.camera.zoom;
    for (0..state.mapData.tiles.len) |i| {
        const tileType = state.mapData.tiles[i];
        const tilePosition = tileIndexToTilePosition(i, state.mapData.tileRadius);
        const tileGamePosition: main.Position = .{
            .x = @floatFromInt(tilePosition.x * main.TILESIZE),
            .y = @floatFromInt(tilePosition.y * main.TILESIZE),
        };
        const vulkan: main.Position = .{
            .x = (-state.camera.position.x + tileGamePosition.x - main.TILESIZE / 2) * state.camera.zoom * onePixelXInVulkan,
            .y = (-state.camera.position.y + tileGamePosition.y - main.TILESIZE / 2) * state.camera.zoom * onePixelYInVulkan,
        };
        switch (tileType) {
            .ice => {
                paintVulkanZig.verticesForRectangle(vulkan.x, vulkan.y, width, height, .{ 0, 0, 1 }, null, &state.vkState.verticeData.triangles);
            },
            .wall => {
                paintVulkanZig.verticesForRectangle(vulkan.x, vulkan.y, width, height, .{ 0, 0, 0 }, null, &state.vkState.verticeData.triangles);
            },
            else => {
                paintVulkanZig.verticesForRectangle(vulkan.x, vulkan.y, width, height, main.COLOR_TILE_GREEN, null, &state.vkState.verticeData.triangles);
            },
        }
    }
    if (state.mapData.mapType == .top) {
        stoneWallVertices(state);
    }
}

fn stoneWallVertices(state: *main.GameState) void {
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const iRadius: i32 = @intCast(state.mapData.tileRadius);
    const platformGameBottom: f32 = @floatFromInt((state.mapData.tileRadius + 1) * main.TILESIZE);
    const platformGameLeft: f32 = @floatFromInt(-iRadius * main.TILESIZE);
    const platformGameRight: f32 = @floatFromInt((state.mapData.tileRadius + 1) * main.TILESIZE);

    const platformVulkanBottom: f32 = (-state.camera.position.y + platformGameBottom - main.TILESIZE / 2) * state.camera.zoom * onePixelYInVulkan;
    const platformVulkanLeft: f32 = (-state.camera.position.x + platformGameLeft - main.TILESIZE / 2) * state.camera.zoom * onePixelXInVulkan;
    const platformVulkanRight: f32 = (-state.camera.position.x + platformGameRight - main.TILESIZE / 2) * state.camera.zoom * onePixelXInVulkan;

    const triangles = &state.vkState.verticeData.triangles;
    if (triangles.verticeCount + 6 >= triangles.vertices.len) return;
    const fillColor = main.COLOR_STONE_WALL;
    const inMovement = onePixelXInVulkan * 15;
    triangles.vertices[triangles.verticeCount] = .{ .pos = .{ platformVulkanLeft, platformVulkanBottom }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ platformVulkanRight - inMovement, 1 }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ platformVulkanLeft + inMovement, 1 }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 3] = .{ .pos = .{ platformVulkanLeft, platformVulkanBottom }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 4] = .{ .pos = .{ platformVulkanRight, platformVulkanBottom }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 5] = .{ .pos = .{ platformVulkanRight - inMovement, 1 }, .color = fillColor };
    triangles.verticeCount += 6;
}
