const std = @import("std");
const main = @import("main.zig");
const mapTileZig = @import("mapTile.zig");

const SearchDataTypes = enum {
    blocking,
    notVisited,
    notVisitedIce,
    visited,
    visitedIceSliding,
    visitedIceStationary,
};

pub fn checkAndModifyMapIfNotEverythingReachable(state: *main.GameState) !void {
    state.verifyMapReachable = false;
    const mapData: []SearchDataTypes = try state.allocator.alloc(SearchDataTypes, state.mapData.tiles.len);
    defer state.allocator.free(mapData);

    for (0..mapData.len) |index| {
        var value: SearchDataTypes = .notVisited;
        if (state.mapData.tiles[index] == .wall) value = .blocking;
        if (state.mapData.tiles[index] == .ice) value = .notVisitedIce;
        mapData[index] = value;
    }

    const mapSize = state.mapData.tileRadius * 2 + 1;
    var openNodes: std.ArrayList(usize) = std.ArrayList(usize).init(state.allocator);
    defer openNodes.deinit();
    for (0..mapSize) |index| {
        try appendNodeIndex(mapData, index, .{ .x = 0, .y = 1 }, &openNodes, state);
        const bottomRowIndex = mapData.len - index - 1;
        try appendNodeIndex(mapData, bottomRowIndex, .{ .x = 0, .y = -1 }, &openNodes, state);
        if (index < mapSize - 2) {
            const leftRowIndex = (index + 1) * mapSize;
            try appendNodeIndex(mapData, leftRowIndex, .{ .x = 1, .y = 0 }, &openNodes, state);
            const rightRowIndex = (mapSize - index - 1) * mapSize - 1;
            try appendNodeIndex(mapData, rightRowIndex, .{ .x = -1, .y = 0 }, &openNodes, state);
        }
    }

    while (openNodes.items.len > 0) {
        const currentNodeIndex = openNodes.swapRemove(0);
        if (@mod(currentNodeIndex, mapSize) > 0) {
            const leftIndex = currentNodeIndex - 1;
            try appendNodeIndex(mapData, leftIndex, .{ .x = -1, .y = 0 }, &openNodes, state);
        }
        if (@mod(currentNodeIndex, mapSize) < mapSize - 1) {
            const rightIndex = currentNodeIndex + 1;
            try appendNodeIndex(mapData, rightIndex, .{ .x = 1, .y = 0 }, &openNodes, state);
        }
        if (@divFloor(currentNodeIndex, mapSize) > 0) {
            const upIndex = currentNodeIndex - mapSize;
            try appendNodeIndex(mapData, upIndex, .{ .x = 0, .y = -1 }, &openNodes, state);
        }
        if (@divFloor(currentNodeIndex, mapSize) < mapSize - 1) {
            const downIndex = currentNodeIndex + mapSize;
            try appendNodeIndex(mapData, downIndex, .{ .x = 0, .y = 1 }, &openNodes, state);
        }
    }
    for (mapData, 0..) |data, index| {
        if (data == .notVisited or data == .notVisitedIce) {
            std.debug.print("notReachableIndex: {}\n", .{index});
        }
    }
}

fn appendNodeIndex(mapData: []SearchDataTypes, index: usize, stepDirection: main.TilePosition, openNodes: *std.ArrayList(usize), state: *main.GameState) !void {
    const mapSize = state.mapData.tileRadius * 2 + 1;
    switch (mapData[index]) {
        .notVisited => {
            try openNodes.append(index);
            mapData[index] = .visited;
        },
        .notVisitedIce, .visitedIceSliding => {
            var movedIndex = index;
            var previous: usize = 0;
            while (mapData[movedIndex] == .notVisitedIce or mapData[movedIndex] == .visitedIceSliding) {
                previous = movedIndex;
                mapData[movedIndex] = .visitedIceSliding;
                if (stepDirection.x < 0 and @mod(movedIndex, mapSize) == 0) return;
                if (stepDirection.x > 0 and @mod(movedIndex, mapSize) == mapSize - 1) return;
                if (stepDirection.y < 0 and movedIndex < mapSize) return;
                if (stepDirection.y > 0 and movedIndex >= mapData.len - mapSize) return;
                movedIndex = @as(u32, @intCast(@as(i32, @intCast(movedIndex)) + stepDirection.x + stepDirection.y * @as(i32, @intCast(mapSize))));
            }
            switch (mapData[movedIndex]) {
                .notVisited => {
                    try openNodes.append(index);
                    mapData[index] = .visited;
                },
                .blocking => {
                    try openNodes.append(previous);
                    mapData[previous] = .visitedIceStationary;
                },
                else => {},
            }
        },
        else => {},
    }
}
