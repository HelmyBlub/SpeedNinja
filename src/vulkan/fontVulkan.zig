const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const inputZig = @import("../input.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const playerZig = @import("../player.zig");

pub const VkFontData = struct {
    mipLevels: u32 = undefined,
    textureImage: vk.VkImage = undefined,
    textureImageMemory: vk.VkDeviceMemory = undefined,
    textureImageView: vk.VkImageView = undefined,
};

/// returns game width of text
pub fn paintTextGameMap(chars: []const u8, gamePosition: main.Position, fontSize: f32, color: [4]f32, vkFont: *dataVulkanZig.VkFont, state: *main.GameState) f32 {
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const vulkanPos: main.Position = .{
        .x = (-state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
        .y = (-state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
    };
    const zoomedFontSize = fontSize * state.camera.zoom;
    const vulkanWidth = paintText(chars, vulkanPos, zoomedFontSize, color, vkFont);
    return vulkanWidth / onePixelXInVulkan / state.camera.zoom;
}

/// returns vulkan surface width of text
pub fn paintText(chars: []const u8, vulkanSurfacePosition: main.Position, fontSize: f32, color: [4]f32, vkFont: *dataVulkanZig.VkFont) f32 {
    var texX: f32 = 0;
    var texWidth: f32 = 0;
    var xOffset: f32 = 0;
    for (chars) |char| {
        if (vkFont.verticeCount >= vkFont.vertices.len) break;
        charToTexCoords(char, &texX, &texWidth);
        vkFont.vertices[vkFont.verticeCount] = .{
            .pos = .{ vulkanSurfacePosition.x + xOffset, vulkanSurfacePosition.y },
            .color = color,
            .texX = texX,
            .texWidth = texWidth,
            .size = fontSize,
        };
        xOffset += texWidth * 1600 / windowSdlZig.windowData.widthFloat * 2 / 40 * fontSize * 0.8;
        vkFont.verticeCount += 1;
    }
    return xOffset;
}

pub fn getTextVulkanWidth(chars: []const u8, fontSize: f32) f32 {
    var texWidth: f32 = 0;
    var texX: f32 = 0;
    var textWidth: f32 = 0;
    for (chars) |char| {
        charToTexCoords(char, &texX, &texWidth);
        textWidth += texWidth * 1600 / windowSdlZig.windowData.widthFloat * 2 / 40 * fontSize * 0.8;
    }
    return textWidth;
}

/// returns game width of text
pub fn paintNumberGameMap(number: anytype, gamePosition: main.Position, fontSize: f32, color: [4]f32, vkFont: *dataVulkanZig.VkFont, state: *main.GameState) !f32 {
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const vulkanPos: main.Position = .{
        .x = (-state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
        .y = (-state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
    };
    const zoomedFontSize = fontSize * state.camera.zoom;
    const vulkanWidth = try paintNumber(number, vulkanPos, zoomedFontSize, color, vkFont);
    return vulkanWidth / onePixelXInVulkan / state.camera.zoom;
}

/// time in hh:mm:ss format
pub fn paintTime(timeMilli: i64, vulkanSurfacePosition: main.Position, fontSize: f32, showOneMilli: bool, color: [4]f32, vkFont: *dataVulkanZig.VkFont) !f32 {
    var zeroPrefix = false;
    var textWidth: f32 = 0;
    const absTimeMilli = @abs(timeMilli);
    if (timeMilli < 0) {
        textWidth += paintText("-", .{ .x = vulkanSurfacePosition.x + textWidth, .y = vulkanSurfacePosition.y }, fontSize, color, vkFont);
    }
    if (absTimeMilli >= 60 * 60 * 1000) {
        const hours = @divFloor(absTimeMilli, 1000 * 60 * 60);
        textWidth += try paintNumber(hours, .{ .x = vulkanSurfacePosition.x + textWidth, .y = vulkanSurfacePosition.y }, fontSize, color, vkFont);
        textWidth += paintText(":", .{ .x = vulkanSurfacePosition.x + textWidth, .y = vulkanSurfacePosition.y }, fontSize, color, vkFont);
        zeroPrefix = true;
    }
    if (absTimeMilli >= 60 * 1000) {
        const minutes = @mod(@divFloor(absTimeMilli, 1000 * 60), 60);
        textWidth += try paintNumberWithZeroPrefix(minutes, .{ .x = vulkanSurfacePosition.x + textWidth, .y = vulkanSurfacePosition.y }, fontSize, color, vkFont, zeroPrefix);
        textWidth += paintText(":", .{ .x = vulkanSurfacePosition.x + textWidth, .y = vulkanSurfacePosition.y }, fontSize, color, vkFont);
        zeroPrefix = true;
    }
    textWidth += try paintNumberWithZeroPrefix(@mod(@divFloor(absTimeMilli, 1000), 60), .{ .x = vulkanSurfacePosition.x + textWidth, .y = vulkanSurfacePosition.y }, fontSize, color, vkFont, zeroPrefix);
    if (showOneMilli) {
        const milli = @mod(@divFloor(absTimeMilli, 100), 10);
        textWidth += paintText(".", .{ .x = vulkanSurfacePosition.x + textWidth, .y = vulkanSurfacePosition.y }, fontSize, color, vkFont);
        textWidth += try paintNumberWithZeroPrefix(milli, .{ .x = vulkanSurfacePosition.x + textWidth, .y = vulkanSurfacePosition.y }, fontSize, color, vkFont, false);
    }
    return textWidth;
}

pub fn paintNumber(number: anytype, vulkanSurfacePosition: main.Position, fontSize: f32, color: [4]f32, vkFont: *dataVulkanZig.VkFont) !f32 {
    return paintNumberWithZeroPrefix(number, vulkanSurfacePosition, fontSize, color, vkFont, false);
}

fn paintNumberWithZeroPrefix(number: anytype, vulkanSurfacePosition: main.Position, fontSize: f32, color: [4]f32, vkFont: *dataVulkanZig.VkFont, singleZeroPrefixWhenSmallerTen: bool) !f32 {
    const max_len = 20;
    var buf: [max_len]u8 = undefined;
    var numberAsString: []u8 = undefined;
    if (@TypeOf(number) == f32) {
        numberAsString = try std.fmt.bufPrint(&buf, "{d:.1}", .{number});
    } else {
        if (singleZeroPrefixWhenSmallerTen and number < 10) {
            numberAsString = try std.fmt.bufPrint(&buf, "0{d}", .{number});
        } else {
            numberAsString = try std.fmt.bufPrint(&buf, "{d}", .{number});
        }
    }

    var texX: f32 = 0;
    var texWidth: f32 = 0;
    var xOffset: f32 = 0;
    for (numberAsString) |char| {
        if (vkFont.verticeCount >= vkFont.vertices.len) break;
        charToTexCoords(char, &texX, &texWidth);
        vkFont.vertices[vkFont.verticeCount] = .{
            .pos = .{ vulkanSurfacePosition.x + xOffset, vulkanSurfacePosition.y },
            .color = color,
            .texX = texX,
            .texWidth = texWidth,
            .size = fontSize,
        };
        xOffset += texWidth * 1600 / windowSdlZig.windowData.widthFloat * 2 / 40 * fontSize * 0.8;
        vkFont.verticeCount += 1;
    }
    return xOffset;
}

/// returns game width
pub fn verticesForDisplayButton(topLeft: main.Position, action: inputZig.PlayerAction, fontSize: f32, player: *playerZig.Player, state: *main.GameState) f32 {
    const buttonInfo = inputZig.getDisplayInfoForPlayerAction(player, action, state);
    if (buttonInfo == null) return 0;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const keyImagePos: main.Position = .{
        .x = topLeft.x + onePixelXInVulkan * fontSize / 2,
        .y = topLeft.y + onePixelYInVulkan * fontSize / 2,
    };
    switch (buttonInfo.?.device) {
        .gamepad => paintVulkanZig.verticesForComplexSpriteVulkan(keyImagePos, imageZig.IMAGE_CIRCLE, fontSize * 0.8, fontSize * 0.8, 1, 0, false, false, state),
        .keyboard => paintVulkanZig.verticesForComplexSpriteVulkan(keyImagePos, imageZig.IMAGE_KEY_BLANK, fontSize, fontSize, 1, 0, false, false, state),
    }
    if (buttonInfo.?.text.len == 1 or (buttonInfo.?.text.len == 2 and std.mem.startsWith(u8, buttonInfo.?.text, "K"))) {
        _ = paintText(buttonInfo.?.text, .{
            .x = topLeft.x + onePixelXInVulkan * fontSize / 4,
            .y = topLeft.y + onePixelYInVulkan * fontSize / 4,
        }, fontSize / 2, .{ 1, 1, 1, 1 }, &state.vkState.verticeData.font);
    } else if (std.mem.eql(u8, buttonInfo.?.text, "Right")) {
        paintVulkanZig.verticesForComplexSpriteVulkan(keyImagePos, imageZig.IMAGE_ARROW_RIGHT, fontSize * 0.8, fontSize * 0.8, 1, 0, false, false, state);
    } else if (std.mem.eql(u8, buttonInfo.?.text, "Left")) {
        paintVulkanZig.verticesForComplexSpriteVulkan(keyImagePos, imageZig.IMAGE_ARROW_RIGHT, fontSize * 0.8, fontSize * 0.8, 1, 0, true, false, state);
    } else if (std.mem.eql(u8, buttonInfo.?.text, "Up")) {
        paintVulkanZig.verticesForComplexSpriteVulkan(keyImagePos, imageZig.IMAGE_ARROW_RIGHT, fontSize * 0.8, fontSize * 0.8, 1, -std.math.pi / 2.0, false, false, state);
    } else if (std.mem.eql(u8, buttonInfo.?.text, "Down")) {
        paintVulkanZig.verticesForComplexSpriteVulkan(keyImagePos, imageZig.IMAGE_ARROW_RIGHT, fontSize * 0.8, fontSize * 0.8, 1, std.math.pi / 2.0, false, false, state);
    }
    return onePixelXInVulkan * fontSize;
}

pub fn initFont(state: *main.GameState) !void {
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

pub fn destroyFont(vkState: *initVulkanZig.VkState) void {
    vk.vkDestroyImageView.?(vkState.logicalDevice, vkState.font.textureImageView, null);
    vk.vkDestroyImage.?(vkState.logicalDevice, vkState.font.textureImage, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, vkState.font.textureImageMemory, null);
}

pub fn charToTexCoords(char: u8, texX: *f32, texWidth: *f32) void {
    const fontImageWidth = 1600.0;
    const imageCharSeperatePixels = [_]f32{ 0, 50, 88, 117, 142, 170, 198, 232, 262, 277, 307, 338, 365, 413, 445, 481, 508, 541, 569, 603, 638, 674, 711, 760, 801, 837, 873, 902, 931, 968, 1003, 1037, 1072, 1104, 1142, 1175, 1205, 1238, 1283, 1302, 1322, 1367, 1410, 1448, 1477 };
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
        '/' => {
            index = 43;
        },
        else => {
            texX.* = 0;
            texWidth.* = 1;
        },
    }
    texX.* = imageCharSeperatePixels[index] / fontImageWidth;
    texWidth.* = (imageCharSeperatePixels[index + 1] - imageCharSeperatePixels[index]) / fontImageWidth;
}
