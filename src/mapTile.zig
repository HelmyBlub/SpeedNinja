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
    tileRadiusWidth: u32,
    tileRadiusHeight: u32,
    mapType: MapType = .default,
};

pub const Cloud = struct {
    sizeFactor: f32 = 0,
    speed: f32 = 0,
    position: main.Position = .{ .x = 2000, .y = 0 },
};

pub const PaintData = struct {
    backgroundColor: [4]f32 = main.COLOR_TILE_GREEN,
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
                backCloud.position.x = -500 + state.seededRandom.random().float(f32) * 1000;
                backCloud.position.y = -150 + state.seededRandom.random().float(f32) * 150;
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
        .tileRadiusWidth = BASE_MAP_TILE_RADIUS,
        .tileRadiusHeight = BASE_MAP_TILE_RADIUS,
        .tiles = tiles,
    };
}

pub fn deinit(state: *main.GameState) void {
    state.allocator.free(state.mapData.tiles);
}

pub fn getMapTilePositionType(tile: main.TilePosition, mapData: *MapData) MapTileType {
    const index = tilePositionToTileIndex(tile, mapData.tileRadiusWidth, mapData.tileRadiusHeight);
    if (index == null or index.? >= mapData.tiles.len) return .normal;
    return mapData.tiles[index.?];
}

pub fn setMapTilePositionType(tile: main.TilePosition, tileType: MapTileType, mapData: *MapData, checkReachable: bool, state: *main.GameState) void {
    const index = tilePositionToTileIndex(tile, mapData.tileRadiusWidth, mapData.tileRadiusHeight);
    if (index == null or index.? >= mapData.tiles.len) return;
    mapData.tiles[index.?] = tileType;
    if (checkReachable and !state.verifyMapData.checkReachable) {
        state.verifyMapData.checkReachable = true;
    }
}

fn tilePositionToTileIndex(tilePosition: main.TilePosition, tileRadiusWidth: u32, tileRadiusHeight: u32) ?usize {
    const iTileRadiusWidth = @as(i32, @intCast(tileRadiusWidth));
    const iTileRadiusHeight = @as(i32, @intCast(tileRadiusHeight));
    const tileWidth = (tileRadiusWidth * 2 + 1);
    if (@abs(tilePosition.x) > iTileRadiusWidth) return null;
    if (@abs(tilePosition.y) > iTileRadiusHeight) return null;
    return @as(u32, @intCast(tilePosition.x + iTileRadiusWidth)) + @as(u32, @intCast(tilePosition.y + iTileRadiusHeight)) * tileWidth;
}

fn tileIndexToTilePosition(tileIndex: usize, mapData: *MapData) main.TilePosition {
    const iTileRadiusWidth = @as(i32, @intCast(mapData.tileRadiusWidth));
    const iTileRadiusHeight = @as(i32, @intCast(mapData.tileRadiusHeight));
    const tileLength = (mapData.tileRadiusWidth * 2 + 1);
    return main.TilePosition{
        .x = @as(i32, @intCast(@mod(tileIndex, tileLength))) - iTileRadiusWidth,
        .y = @as(i32, @intCast(@divFloor(tileIndex, tileLength))) - iTileRadiusHeight,
    };
}

pub fn setMapRadius(tileRadiusWidth: u32, tileRadiusHeight: u32, state: *main.GameState) !void {
    if (tileRadiusWidth == state.mapData.tileRadiusWidth and tileRadiusHeight == state.mapData.tileRadiusHeight) return;
    const tileWidth = (tileRadiusWidth * 2 + 1);
    const tileHeight = (tileRadiusHeight * 2 + 1);
    const tiles = try state.allocator.alloc(MapTileType, tileWidth * tileHeight);
    resetMapTiles(tiles);
    for (0..state.mapData.tiles.len) |oldTileIndex| {
        const tilePosition = tileIndexToTilePosition(oldTileIndex, &state.mapData);
        const newTileIndex = tilePositionToTileIndex(tilePosition, tileRadiusWidth, tileRadiusHeight);
        if (newTileIndex == null or newTileIndex.? >= tiles.len) continue;
        tiles[newTileIndex.?] = state.mapData.tiles[oldTileIndex];
    }
    state.mapData.tileRadiusWidth = tileRadiusWidth;
    state.mapData.tileRadiusHeight = tileRadiusHeight;
    state.allocator.free(state.mapData.tiles);
    state.mapData.tiles = tiles;
}

pub fn resetMapTiles(tiles: []MapTileType) void {
    for (0..tiles.len) |i| {
        tiles[i] = .normal;
    }
}

pub fn setupVertices(state: *main.GameState) void {
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const width = onePixelXInVulkan * main.TILESIZE * state.camera.zoom;
    const height = onePixelYInVulkan * main.TILESIZE * state.camera.zoom;
    for (0..state.mapData.tiles.len) |i| {
        const tileType = state.mapData.tiles[i];
        const tilePosition = tileIndexToTilePosition(i, &state.mapData);
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
                paintVulkanZig.verticesForRectangle(vulkan.x, vulkan.y, width, height, .{ 0, 0, 1, 1 }, null, &state.vkState.verticeData.triangles);
            },
            .wall => {
                paintVulkanZig.verticesForRectangle(vulkan.x, vulkan.y, width, height, .{ 0, 0, 0, 1 }, null, &state.vkState.verticeData.triangles);
            },
            else => {
                paintVulkanZig.verticesForRectangle(vulkan.x, vulkan.y, width, height, main.COLOR_TILE_GREEN, null, &state.vkState.verticeData.triangles);
            },
        }
    }
    if (state.mapData.mapType == .top) {
        if (state.gamePhase == .finished) {
            const horizonVulkanY = (-state.camera.position.y - main.TILESIZE * 11) * state.camera.zoom * onePixelYInVulkan;
            if (horizonVulkanY < 1) {
                paintVulkanZig.verticesForRectangle(-1, horizonVulkanY, 2, 3, main.COLOR_TILE_GREEN, null, &state.vkState.verticeData.triangles);
            }
        } else {
            stoneWallVertices(state);
        }
    }
}

fn stoneWallVertices(state: *main.GameState) void {
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const iRadiusWidth: i32 = @intCast(state.mapData.tileRadiusWidth);
    const platformGameBottom: f32 = @floatFromInt((state.mapData.tileRadiusHeight + 1) * main.TILESIZE);
    const platformGameLeft: f32 = @floatFromInt(-iRadiusWidth * main.TILESIZE);
    const platformGameRight: f32 = @floatFromInt((state.mapData.tileRadiusWidth + 1) * main.TILESIZE);

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
