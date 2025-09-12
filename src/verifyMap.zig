const std = @import("std");
const main = @import("main.zig");
const mapTileZig = @import("mapTile.zig");

pub const VerifyMapData = struct {
    checkReachable: bool = false,
    lastCheckTime: i64 = 0,
};

const SearchDataTypes = enum {
    blocking,
    notVisited,
    notVisitedIce,
    visited,
    visitedIceSliding,
    visitedIceStationary,
};

pub fn checkAndModifyMapIfNotEverythingReachable(state: *main.GameState) !void {
    if (state.verifyMapData.lastCheckTime + 2500 > state.gameTime) return;
    state.verifyMapData.checkReachable = false;
    state.verifyMapData.lastCheckTime = state.gameTime;
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

    try handleOpenNodes(mapData, &openNodes, mapSize, state);
    std.debug.print("analyzed map\n", .{});
    printMapData(mapData, mapSize);
    for (mapData, 0..) |data, index| {
        if (data == .notVisited or data == .notVisitedIce) {
            std.debug.print("notReachableIndex: {}\n", .{index});
            try fixUnreachableIndex(mapData, index, mapSize, &openNodes, state);
        }
    }
}

fn fixUnreachableIndex(mapData: []SearchDataTypes, index: usize, mapSize: u32, openNodes: *std.ArrayList(usize), state: *main.GameState) !void {
    const neigborsStepDirections: [4]main.TilePosition = .{
        .{ .x = 0, .y = -1 },
        .{ .x = 1, .y = 0 },
        .{ .x = 0, .y = 1 },
        .{ .x = -1, .y = 0 },
    };
    for (neigborsStepDirections) |neighborOffset| {
        if (neighborOffset.x < 0 and @mod(index, mapSize) == 0) continue;
        if (neighborOffset.x > 0 and @mod(index, mapSize) == mapSize - 1) continue;
        if (neighborOffset.y < 0 and index < mapSize) continue;
        if (neighborOffset.y > 0 and index >= mapData.len - mapSize) continue;
        const movedIndex = @as(u32, @intCast(@as(i32, @intCast(index)) + neighborOffset.x + neighborOffset.y * @as(i32, @intCast(mapSize))));
        switch (mapData[movedIndex]) {
            .visitedIceSliding => {
                mapData[movedIndex] = .visited;
                try openNodes.append(movedIndex);
                state.mapData.tiles[movedIndex] = .normal;
                std.debug.print("removed ice to make reachable\n", .{});
                break;
            },
            .blocking => {
                mapData[movedIndex] = .notVisited;
                state.mapData.tiles[movedIndex] = .normal;
                var wallRemovalMadeIndexAccessible = false;
                for (neigborsStepDirections) |neighborOffset2| {
                    if (neighborOffset2.x < 0 and @mod(movedIndex, mapSize) == 0) continue;
                    if (neighborOffset2.x > 0 and @mod(movedIndex, mapSize) == mapSize - 1) continue;
                    if (neighborOffset2.y < 0 and movedIndex < mapSize) continue;
                    if (neighborOffset2.y > 0 and movedIndex >= mapData.len - mapSize) continue;
                    const movedIndex2 = @as(u32, @intCast(@as(i32, @intCast(movedIndex)) + neighborOffset2.x + neighborOffset2.y * @as(i32, @intCast(mapSize))));
                    if (mapData[movedIndex2] == .visited or mapData[movedIndex2] == .visitedIceStationary) {
                        std.debug.print("removed wall to make reachable\n", .{});
                        wallRemovalMadeIndexAccessible = true;
                        try openNodes.append(movedIndex2);
                        break;
                    }
                }
                if (!wallRemovalMadeIndexAccessible) {
                    std.debug.print("removed wall recursion\n", .{});
                    try fixUnreachableIndex(mapData, movedIndex, mapSize, openNodes, state);
                }
                break;
            },
            else => {},
        }
    }
    try handleOpenNodes(mapData, openNodes, mapSize, state);
}

fn handleOpenNodes(mapData: []SearchDataTypes, openNodes: *std.ArrayList(usize), mapSize: u32, state: *main.GameState) !void {
    while (openNodes.items.len > 0) {
        const currentNodeIndex = openNodes.swapRemove(0);
        if (@mod(currentNodeIndex, mapSize) > 0) {
            const leftIndex = currentNodeIndex - 1;
            try appendNodeIndex(mapData, leftIndex, .{ .x = -1, .y = 0 }, openNodes, state);
        }
        if (@mod(currentNodeIndex, mapSize) < mapSize - 1) {
            const rightIndex = currentNodeIndex + 1;
            try appendNodeIndex(mapData, rightIndex, .{ .x = 1, .y = 0 }, openNodes, state);
        }
        if (@divFloor(currentNodeIndex, mapSize) > 0) {
            const upIndex = currentNodeIndex - mapSize;
            try appendNodeIndex(mapData, upIndex, .{ .x = 0, .y = -1 }, openNodes, state);
        }
        if (@divFloor(currentNodeIndex, mapSize) < mapSize - 1) {
            const downIndex = currentNodeIndex + mapSize;
            try appendNodeIndex(mapData, downIndex, .{ .x = 0, .y = 1 }, openNodes, state);
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
                    try openNodes.append(movedIndex);
                    mapData[movedIndex] = .visited;
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

fn printMapData(mapData: []SearchDataTypes, mapSize: u32) void {
    for (0..mapSize) |y| {
        for (0..mapSize) |x| {
            var value: u8 = 0;
            switch (mapData[x + y * mapSize]) {
                .blocking => value = 0,
                .visited => value = 1,
                .visitedIceSliding => value = 2,
                .visitedIceStationary => value = 3,
                .notVisited => value = 9,
                .notVisitedIce => value = 8,
            }
            std.debug.print("{} ", .{value});
        }
        std.debug.print("\n", .{});
    }
}
