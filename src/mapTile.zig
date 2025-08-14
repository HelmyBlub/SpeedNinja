const std = @import("std");
const main = @import("main.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const windowSdlZig = @import("windowSdl.zig");

pub const MapTileType = enum {
    normal,
    ice,
};

pub const MapData = struct {
    tiles: []MapTileType,
    tileRadius: u32,
};

pub const BASE_MAP_TILE_RADIUS = 3;

pub fn createMapData(allocator: std.mem.Allocator) !MapData {
    const tiles = try allocator.alloc(MapTileType, BASE_MAP_TILE_RADIUS * BASE_MAP_TILE_RADIUS);
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
    return mapData.tiles[index];
}

pub fn setMapTilePositionType(tile: main.TilePosition, tileType: MapTileType, mapData: *MapData) void {
    const index = tilePositionToTileIndex(tile, mapData.tileRadius);
    if (index == null or index.? >= mapData.tiles.len) return;
    mapData.tiles[index.?] = tileType;
}

fn tilePositionToTileIndex(tilePosition: main.TilePosition, tileRadius: u32) ?usize {
    const iTileRadius = @as(i32, @intCast(tileRadius));
    if (tilePosition.x < -iTileRadius) return null;
    if (tilePosition.y < -iTileRadius) return null;
    return @as(u32, @intCast(tilePosition.x + iTileRadius)) + @as(u32, @intCast(tilePosition.y + iTileRadius)) * tileRadius;
}

fn tileIndexToTilePosition(tileIndex: usize, tileRadius: u32) main.TilePosition {
    const iTileRadius = @as(i32, @intCast(tileRadius));
    return main.TilePosition{
        .x = @as(i32, @intCast(@mod(tileIndex, tileRadius))) - iTileRadius,
        .y = @as(i32, @intCast(@divFloor(tileIndex, tileRadius))) - iTileRadius,
    };
}

pub fn setMapRadius(tileRadius: u32, state: *main.GameState) !void {
    if (tileRadius == state.mapData.tileRadius) return;
    const tiles = try state.allocator.alloc(MapTileType, tileRadius * tileRadius);
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
            else => {},
        }
    }
}
