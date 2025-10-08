const std = @import("std");
const main = @import("../main.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const vk = paintVulkanZig.vk;
const fontVulkanZig = @import("fontVulkan.zig");
const imageZig = @import("../image.zig");
const inputZig = @import("../input.zig");
const windowSdlZig = @import("../windowSdl.zig");
const playerZig = @import("../player.zig");

pub const SettingsUx = struct {
    menuOpen: bool = false,
    settingsIcon: main.Rectangle = undefined,
    uiSizeDelayed: f32 = 1,
    uiTabs: [2]UiTabsData = [_]UiTabsData{
        .{ .uiElements = &UI_ELEMENTS_MAIN, .label = "main" },
        .{ .uiElements = &UI_ELEMENTS_SPEEDRUN_STATS, .label = "stats" },
    },
    activeTabIndex: usize = 0,
    hoverTabIndex: ?usize = null,
    baseFontSize: f32 = 26,
    settingsIconHovered: bool = false,
};
const BUTTON_HOLD_DURATION_MS = 2000;
const SPACING_PIXELS = 5.0;
var UI_ELEMENTS_MAIN = [_]UiElementData{
    .{ .holdButton = .{ .label = "Restart", .onHoldDurationFinished = onHoldButtonRestart } },
    .{ .holdButton = .{ .label = "Kick Players", .onHoldDurationFinished = onHoldButtonKickPlayers } },
    .{ .checkbox = .{ .label = "Fullscreen", .onSetChecked = onCheckboxFullscreen } },
    .{ .checkbox = .{ .label = "Time Freeze", .onSetChecked = onCheckboxFreezeOnHit, .checked = true } },
    .{ .slider = .{ .label = "Volume", .valuePerCent = 1, .onChange = onSliderChangeVolume } },
    .{ .slider = .{ .label = "UI Size", .valuePerCent = 0.5, .onStopHolding = onSliderStopHoldingUxSize } },
    .{ .holdButton = .{ .label = "Quit", .onHoldDurationFinished = onHoldButtonQuit } },
};

var UI_ELEMENTS_SPEEDRUN_STATS = [_]UiElementData{
    .{ .checkbox = .{ .label = "Speedrun Stats", .onSetChecked = onCheckboxSpeedrunStats, .checked = true } },
    .{ .checkbox = .{ .label = "Column Time", .onSetChecked = onCheckboxStatsColumnTime, .checked = true } },
    .{ .checkbox = .{ .label = "Column +/-", .onSetChecked = onCheckboxStatsColumnPlusMinus, .checked = true } },
    .{ .checkbox = .{ .label = "Column Gold", .onSetChecked = onCheckboxStatsColumnGold, .checked = true } },
    .{ .checkbox = .{ .label = "Next Level", .onSetChecked = onCheckboxStatsNextLevel, .checked = true } },
};

const UiElement = enum {
    slider,
    checkbox,
    holdButton,
};

const UiTabsData = struct {
    label: []const u8,
    uiElements: []UiElementData,
    labelRec: main.Rectangle = .{ .pos = .{ .x = 0, .y = 0 }, .width = 0, .height = 0 },
    contentRec: main.Rectangle = .{ .pos = .{ .x = 0, .y = 0 }, .width = 0, .height = 0 },
};

const UiElementData = union(UiElement) {
    slider: UiElementSliderData,
    checkbox: UiElementCheckboxData,
    holdButton: UiElementHoldButtonData,
};

const UiElementHoldButtonData = struct {
    rec: main.Rectangle = undefined,
    holdStartTime: ?i64 = null,
    hovering: bool = false,
    label: []const u8,
    baseHeight: f32 = 80,
    onHoldDurationFinished: *const fn (state: *main.GameState) anyerror!void,
};

const UiElementCheckboxData = struct {
    rec: main.Rectangle = undefined,
    checked: bool = false,
    hovering: bool = false,
    label: []const u8,
    baseSize: f32 = 50,
    onSetChecked: *const fn (checked: bool, state: *main.GameState) anyerror!void,
};

const UiElementSliderData = struct {
    recSlider: main.Rectangle = undefined,
    recDragArea: main.Rectangle = undefined,
    valuePerCent: f32,
    hovering: bool = false,
    holding: bool = false,
    label: []const u8,
    baseHeight: f32 = 40,
    onChange: ?*const fn (sliderPerCent: f32, state: *main.GameState) anyerror!void = null,
    onStopHolding: ?*const fn (sliderPerCent: f32, state: *main.GameState) anyerror!void = null,
};

pub fn setupUiLocations(state: *main.GameState) void {
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    const uiSizeFactor = settingsMenuUx.uiSizeDelayed;
    const vulkanSpacingX = SPACING_PIXELS * onePixelXInVulkan * uiSizeFactor;
    const vulkanSpacingY = SPACING_PIXELS * onePixelYInVulkan * uiSizeFactor;
    const vulkanSpacingLargerY = 20.0 * onePixelYInVulkan * uiSizeFactor;
    const sliderSpacingX = 20.0 * onePixelXInVulkan * uiSizeFactor;
    const sliderWidth = 20 * onePixelXInVulkan * uiSizeFactor;
    const dragAreaWidth = 255 * onePixelXInVulkan * uiSizeFactor - sliderSpacingX * 2 - sliderWidth;

    const iconWidth = 40 * onePixelXInVulkan * uiSizeFactor;
    const iconHeight = 40 * onePixelYInVulkan * uiSizeFactor;
    settingsMenuUx.settingsIcon = .{
        .height = iconHeight,
        .width = iconWidth,
        .pos = .{
            .x = 1 - iconWidth - vulkanSpacingX,
            .y = -1 + vulkanSpacingY,
        },
    };

    const tabsHeight = settingsMenuUx.baseFontSize * 2 / windowSdlZig.windowData.heightFloat * uiSizeFactor + vulkanSpacingY * 2;
    var tabOffsetX: f32 = 0;
    for (0..settingsMenuUx.uiTabs.len) |tabCount| {
        const tabIndex = settingsMenuUx.uiTabs.len - 1 - tabCount;
        const tab = &settingsMenuUx.uiTabs[tabIndex];
        const tabTextWidth = fontVulkanZig.getTextVulkanWidth(tab.label, settingsMenuUx.baseFontSize) * uiSizeFactor;
        const tabWidth = tabTextWidth + vulkanSpacingX * 2;
        tab.labelRec = .{
            .pos = .{ .x = 0.99 - tabWidth + tabOffsetX, .y = -1 + vulkanSpacingY + iconHeight },
            .width = tabWidth,
            .height = tabsHeight,
        };
        tabOffsetX -= tab.labelRec.width;
    }
    for (&settingsMenuUx.uiTabs) |*tab| {
        var maxTabWidth: f32 = 0;
        tab.contentRec.width = 0;
        tab.contentRec.height = 0;
        tab.contentRec.pos.y = tab.labelRec.pos.y + tab.labelRec.height;

        var offsetY: f32 = tab.contentRec.pos.y;
        for (tab.uiElements) |*element| {
            switch (element.*) {
                .holdButton => |*data| {
                    const textWidthEstimate = fontVulkanZig.getTextVulkanWidth(data.label, settingsMenuUx.baseFontSize) * uiSizeFactor;
                    data.rec = main.Rectangle{
                        .height = data.baseHeight / windowSdlZig.windowData.heightFloat * uiSizeFactor,
                        .width = textWidthEstimate + vulkanSpacingX * 2,
                        .pos = .{
                            .x = tab.contentRec.pos.x + vulkanSpacingX,
                            .y = offsetY + vulkanSpacingY,
                        },
                    };
                    const widthEstimate = data.rec.width + vulkanSpacingX * 2;
                    if (widthEstimate > maxTabWidth) maxTabWidth = widthEstimate;
                    offsetY = data.rec.pos.y + data.rec.height;
                },
                .checkbox => |*data| {
                    data.rec = main.Rectangle{
                        .height = data.baseSize / windowSdlZig.windowData.heightFloat * uiSizeFactor,
                        .width = data.baseSize / windowSdlZig.windowData.widthFloat * uiSizeFactor,
                        .pos = .{
                            .x = tab.contentRec.pos.x + vulkanSpacingX,
                            .y = offsetY + vulkanSpacingLargerY,
                        },
                    };
                    const textWidthEstimate = fontVulkanZig.getTextVulkanWidth(data.label, settingsMenuUx.baseFontSize) * uiSizeFactor;
                    const widthEstimate = textWidthEstimate + data.rec.width + vulkanSpacingX * 3;
                    if (widthEstimate > maxTabWidth) maxTabWidth = widthEstimate;
                    offsetY = data.rec.pos.y + data.rec.height;
                },
                .slider => |*data| {
                    const labelOffsetY = settingsMenuUx.baseFontSize * onePixelYInVulkan;
                    offsetY += labelOffsetY;
                    const sliderOffsetX = data.valuePerCent * dragAreaWidth;
                    data.recSlider = main.Rectangle{
                        .height = data.baseHeight / windowSdlZig.windowData.heightFloat * uiSizeFactor,
                        .width = sliderWidth,
                        .pos = .{
                            .x = tab.contentRec.pos.x + sliderOffsetX + vulkanSpacingX,
                            .y = offsetY + vulkanSpacingLargerY,
                        },
                    };
                    data.recDragArea = main.Rectangle{
                        .height = data.baseHeight / 4 / windowSdlZig.windowData.heightFloat * uiSizeFactor,
                        .width = dragAreaWidth,
                        .pos = .{
                            .x = tab.contentRec.pos.x + sliderWidth / 2 + vulkanSpacingX,
                            .y = data.recSlider.pos.y + data.baseHeight / 8 * 3 / windowSdlZig.windowData.heightFloat * uiSizeFactor,
                        },
                    };
                    const textWidthEstimate = fontVulkanZig.getTextVulkanWidth(data.label, settingsMenuUx.baseFontSize) * uiSizeFactor;
                    const numberWidthEstimate = settingsMenuUx.baseFontSize * uiSizeFactor * 3 * onePixelXInVulkan + vulkanSpacingX * 2;
                    const widthEstimate = @max(dragAreaWidth + sliderWidth, textWidthEstimate + numberWidthEstimate) + vulkanSpacingX * 2;
                    if (widthEstimate > maxTabWidth) maxTabWidth = widthEstimate;
                    offsetY = data.recSlider.pos.y + data.recSlider.height;
                },
            }
            tab.contentRec.height = offsetY - tab.contentRec.pos.y + vulkanSpacingY;
            tab.contentRec.width = maxTabWidth;
        }
    }
    for (&settingsMenuUx.uiTabs) |*tab| {
        tab.contentRec.pos.x = 0.99 - tab.contentRec.width;
        for (tab.uiElements) |*element| {
            switch (element.*) {
                .holdButton => |*data| {
                    data.rec.pos.x = tab.contentRec.pos.x + vulkanSpacingX;
                },
                .checkbox => |*data| {
                    data.rec.pos.x = tab.contentRec.pos.x + vulkanSpacingX;
                },
                .slider => |*data| {
                    data.recDragArea.pos.x = tab.contentRec.pos.x + sliderWidth / 2 + vulkanSpacingX;
                    const sliderOffsetX = data.valuePerCent * dragAreaWidth;
                    data.recSlider.pos.x = tab.contentRec.pos.x + sliderOffsetX + vulkanSpacingX;
                },
            }
        }
    }
}

pub fn mouseMove(mouseWindowPosition: main.Position, state: *main.GameState) !void {
    const vulkanMousePos = windowSdlZig.mouseWindowPositionToVulkanSurfacePoisition(mouseWindowPosition.x, mouseWindowPosition.y);
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    if (main.isPositionInRectangle(vulkanMousePos, settingsMenuUx.settingsIcon)) {
        settingsMenuUx.settingsIconHovered = true;
        return;
    }
    if (settingsMenuUx.settingsIconHovered) {
        settingsMenuUx.settingsIconHovered = false;
    }
    if (!settingsMenuUx.menuOpen) return;

    settingsMenuUx.hoverTabIndex = null;
    for (&settingsMenuUx.uiTabs, 0..) |*tab, tabIndex| {
        if (main.isPositionInRectangle(vulkanMousePos, tab.labelRec)) {
            settingsMenuUx.hoverTabIndex = tabIndex;
            break;
        }
    }

    const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
    for (currentTab.uiElements) |*element| {
        switch (element.*) {
            .holdButton => |*data| {
                if (main.isPositionInRectangle(vulkanMousePos, data.rec)) {
                    data.hovering = true;
                } else {
                    data.hovering = false;
                    if (data.holdStartTime != null) {
                        data.holdStartTime = null;
                    }
                }
            },
            .checkbox => |*data| {
                if (main.isPositionInRectangle(vulkanMousePos, data.rec)) {
                    data.hovering = true;
                } else {
                    data.hovering = false;
                }
            },
            .slider => |*data| {
                if (main.isPositionInRectangle(vulkanMousePos, data.recSlider)) {
                    data.hovering = true;
                } else {
                    data.hovering = false;
                }
                if (data.holding) {
                    data.valuePerCent = @min(@max(0, @as(f32, @floatCast(vulkanMousePos.x - data.recDragArea.pos.x)) / data.recDragArea.width), 1);
                    if (data.onChange) |onChange| try onChange(data.valuePerCent, state);
                    setupUiLocations(state);
                }
            },
        }
    }
}

pub fn mouseUp(mouseWindowPosition: main.Position, state: *main.GameState) !void {
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
    for (currentTab.uiElements) |*element| {
        switch (element.*) {
            .holdButton => |*data| {
                data.holdStartTime = null;
            },
            .checkbox => {},
            .slider => |*data| {
                if (data.holding) {
                    const vulkanMousePos = windowSdlZig.mouseWindowPositionToVulkanSurfacePoisition(mouseWindowPosition.x, mouseWindowPosition.y);
                    data.valuePerCent = @min(@max(0, @as(f32, @floatCast(vulkanMousePos.x - data.recDragArea.pos.x)) / data.recDragArea.width), 1);
                    if (data.onChange) |onChange| try onChange(data.valuePerCent, state);
                    if (data.onStopHolding) |stopHold| try stopHold(data.valuePerCent, state);
                }
                data.holding = false;
            },
        }
    }
}

pub fn mouseDown(mouseWindowPosition: main.Position, state: *main.GameState) !void {
    const vulkanMousePos = windowSdlZig.mouseWindowPositionToVulkanSurfacePoisition(mouseWindowPosition.x, mouseWindowPosition.y);
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    if (main.isPositionInRectangle(vulkanMousePos, settingsMenuUx.settingsIcon)) {
        settingsMenuUx.menuOpen = !settingsMenuUx.menuOpen;
        return;
    }
    if (!settingsMenuUx.menuOpen) return;
    for (&settingsMenuUx.uiTabs, 0..) |*tab, tabIndex| {
        if (main.isPositionInRectangle(vulkanMousePos, tab.labelRec)) {
            settingsMenuUx.activeTabIndex = tabIndex;
            return;
        }
    }
    const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
    for (currentTab.uiElements) |*element| {
        switch (element.*) {
            .holdButton => |*data| {
                if (main.isPositionInRectangle(vulkanMousePos, data.rec)) {
                    data.holdStartTime = std.time.milliTimestamp();
                    return;
                }
            },
            .checkbox => |*data| {
                if (main.isPositionInRectangle(vulkanMousePos, data.rec)) {
                    data.checked = !data.checked;
                    try data.onSetChecked(data.checked, state);
                    return;
                }
            },
            .slider => |*data| {
                const interactBox: main.Rectangle = .{
                    .pos = .{ .x = data.recDragArea.pos.x - data.recSlider.width / 2, .y = data.recSlider.pos.y },
                    .width = data.recDragArea.width + data.recSlider.width,
                    .height = data.recSlider.height,
                };
                if (main.isPositionInRectangle(vulkanMousePos, interactBox)) {
                    data.valuePerCent = @min(@max(0, @as(f32, @floatCast(vulkanMousePos.x - data.recDragArea.pos.x)) / data.recDragArea.width), 1);
                    data.holding = true;
                    setupUiLocations(state);
                    return;
                }
            },
        }
    }
}

pub fn tick(state: *main.GameState) !void {
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    const timestamp = std.time.milliTimestamp();
    const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
    for (currentTab.uiElements) |*element| {
        switch (element.*) {
            .holdButton => |*data| {
                if (data.holdStartTime != null and data.holdStartTime.? + BUTTON_HOLD_DURATION_MS < timestamp) {
                    data.holdStartTime = null;
                    try data.onHoldDurationFinished(state);
                }
            },
            else => {},
        }
    }
}

pub fn setupVertices(state: *main.GameState) !void {
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const verticeData = &state.vkState.verticeData;
    const buttonFillColor: [4]f32 = .{ 0.7, 0.7, 0.7, 1 };
    const hoverColor: [4]f32 = .{ 0.4, 0.4, 0.4, 1 };
    const color: [4]f32 = .{ 1, 1, 1, 1 };
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    const uiSizeFactor = settingsMenuUx.uiSizeDelayed;
    const icon = settingsMenuUx.settingsIcon;

    if (settingsMenuUx.settingsIconHovered) {
        paintVulkanZig.verticesForRectangle(icon.pos.x, icon.pos.y, icon.width, icon.height, color, &verticeData.lines, &verticeData.triangles);
    }
    paintVulkanZig.verticesForComplexSpriteVulkan(.{
        .x = icon.pos.x + icon.width / 2,
        .y = icon.pos.y + icon.height / 2,
    }, imageZig.IMAGE_SETTINGS_ICON, icon.width / onePixelXInVulkan, icon.height / onePixelYInVulkan, 1, 0, false, false, state);

    if (settingsMenuUx.menuOpen) {
        const vulkanSpacingX = SPACING_PIXELS * onePixelXInVulkan * uiSizeFactor;
        const vulkanSpacingY = SPACING_PIXELS * onePixelYInVulkan * uiSizeFactor;
        const fontSize: f32 = settingsMenuUx.baseFontSize * uiSizeFactor;
        const fontVulkanHeight = fontSize * onePixelYInVulkan;
        const menuRec = settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex].contentRec;
        paintVulkanZig.verticesForRectangle(menuRec.pos.x, menuRec.pos.y, menuRec.width, menuRec.height, color, &verticeData.lines, &verticeData.triangles);
        const timestamp = std.time.milliTimestamp();
        var tabsOffsetX: f32 = 0;
        for (settingsMenuUx.uiTabs, 0..) |tab, tabIndex| {
            const tabsAlpha: f32 = if (tabIndex == settingsMenuUx.activeTabIndex) 1 else 0.5;
            const textWidth = fontVulkanZig.paintText(tab.label, .{
                .x = tab.labelRec.pos.x + vulkanSpacingX,
                .y = tab.labelRec.pos.y + vulkanSpacingY,
            }, fontSize, .{ 1, 1, 1, tabsAlpha }, &verticeData.font);
            if (tabIndex == settingsMenuUx.activeTabIndex) {
                const lines = &verticeData.lines;
                if (lines.verticeCount + 6 < lines.vertices.len) {
                    const borderColor: [4]f32 = .{ 0, 0, 0, 1 };
                    lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ tab.labelRec.pos.x, tab.labelRec.pos.y }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ tab.labelRec.pos.x + tab.labelRec.width, tab.labelRec.pos.y }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 2] = .{ .pos = .{ tab.labelRec.pos.x, tab.labelRec.pos.y }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 3] = .{ .pos = .{ tab.labelRec.pos.x, tab.labelRec.pos.y + tab.labelRec.height }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 4] = .{ .pos = .{ tab.labelRec.pos.x + tab.labelRec.width, tab.labelRec.pos.y }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 5] = .{ .pos = .{ tab.labelRec.pos.x + tab.labelRec.width, tab.labelRec.pos.y + tab.labelRec.height }, .color = borderColor };
                    lines.verticeCount += 6;
                }
                if (tabIndex == settingsMenuUx.hoverTabIndex) {
                    paintVulkanZig.verticesForRectangle(tab.labelRec.pos.x, tab.labelRec.pos.y, tab.labelRec.width, tab.labelRec.height, hoverColor, null, &verticeData.triangles);
                }
            } else {
                const triangles = if (tabIndex == settingsMenuUx.hoverTabIndex) &verticeData.triangles else null;
                paintVulkanZig.verticesForRectangle(tab.labelRec.pos.x, tab.labelRec.pos.y, tab.labelRec.width, tab.labelRec.height, hoverColor, &verticeData.lines, triangles);
            }
            tabsOffsetX += textWidth + vulkanSpacingX * 2;
        }
        const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
        for (currentTab.uiElements) |*element| {
            switch (element.*) {
                .holdButton => |*data| {
                    const restartFillColor = if (data.hovering) hoverColor else buttonFillColor;
                    paintVulkanZig.verticesForRectangle(data.rec.pos.x, data.rec.pos.y, data.rec.width, data.rec.height, restartFillColor, &verticeData.lines, &verticeData.triangles);
                    if (data.holdStartTime) |time| {
                        const timeDiff = @max(0, time + BUTTON_HOLD_DURATION_MS - timestamp);
                        const fillPerCent: f32 = 1 - @as(f32, @floatFromInt(timeDiff)) / BUTTON_HOLD_DURATION_MS;
                        const holdRecColor: [4]f32 = .{ 0.2, 0.2, 0.2, 1 };
                        paintVulkanZig.verticesForRectangle(data.rec.pos.x, data.rec.pos.y, data.rec.width * fillPerCent, data.rec.height, holdRecColor, &verticeData.lines, &verticeData.triangles);
                    }
                    _ = fontVulkanZig.paintText(data.label, .{
                        .x = data.rec.pos.x,
                        .y = data.rec.pos.y + (data.rec.height - fontVulkanHeight) / 2,
                    }, fontSize, textColor, &verticeData.font);
                },
                .checkbox => |*data| {
                    const checkboxFillColor = if (data.hovering) hoverColor else buttonFillColor;
                    paintVulkanZig.verticesForRectangle(data.rec.pos.x, data.rec.pos.y, data.rec.width, data.rec.height, checkboxFillColor, &verticeData.lines, &verticeData.triangles);
                    _ = fontVulkanZig.paintText(data.label, .{
                        .x = data.rec.pos.x + data.rec.width * 1.05,
                        .y = data.rec.pos.y - data.rec.height * 0.1,
                    }, fontSize, textColor, &verticeData.font);
                    if (data.checked) {
                        paintVulkanZig.verticesForComplexSpriteVulkan(.{
                            .x = data.rec.pos.x + data.rec.width / 2,
                            .y = data.rec.pos.y + data.rec.height / 2,
                        }, imageZig.IMAGE_CHECKMARK, data.rec.width / onePixelXInVulkan, data.rec.height / onePixelYInVulkan, 1, 0, false, false, state);
                    }
                },
                .slider => |*data| {
                    paintVulkanZig.verticesForRectangle(data.recDragArea.pos.x, data.recDragArea.pos.y, data.recDragArea.width, data.recDragArea.height, color, &verticeData.lines, &verticeData.triangles);
                    const sliderFillColor = if (data.hovering) hoverColor else buttonFillColor;
                    paintVulkanZig.verticesForRectangle(data.recSlider.pos.x, data.recSlider.pos.y, data.recSlider.width, data.recSlider.height, sliderFillColor, &verticeData.lines, &verticeData.triangles);

                    const textWidthVolume = fontVulkanZig.paintText(
                        data.label,
                        .{ .x = data.recDragArea.pos.x, .y = data.recSlider.pos.y - fontVulkanHeight },
                        fontSize,
                        textColor,
                        &verticeData.font,
                    );
                    _ = try fontVulkanZig.paintNumber(
                        @as(u32, @intFromFloat(data.valuePerCent * 100)),
                        .{ .x = data.recDragArea.pos.x + textWidthVolume + fontSize * onePixelXInVulkan, .y = data.recSlider.pos.y - fontVulkanHeight },
                        fontSize,
                        textColor,
                        &verticeData.font,
                    );
                },
            }
        }
    }
}

fn onHoldButtonRestart(state: *main.GameState) anyerror!void {
    try main.restart(state, state.newGamePlus);
}

fn onHoldButtonKickPlayers(state: *main.GameState) anyerror!void {
    for (1..state.players.items.len) |_| {
        try playerZig.playerLeave(1, state);
    }
}

fn onHoldButtonQuit(state: *main.GameState) anyerror!void {
    state.gameQuit = true;
}

fn onCheckboxFullscreen(checked: bool, state: *main.GameState) anyerror!void {
    _ = state;
    _ = windowSdlZig.setFullscreen(checked);
}

fn onCheckboxFreezeOnHit(checked: bool, state: *main.GameState) anyerror!void {
    state.timeFreezeOnHit = checked;
}

fn onCheckboxSpeedrunStats(checked: bool, state: *main.GameState) anyerror!void {
    state.statistics.uxData.display = checked;
}

fn onCheckboxStatsColumnTime(checked: bool, state: *main.GameState) anyerror!void {
    for (state.statistics.uxData.columnsData) |*column| {
        if (std.mem.eql(u8, "Time", column.name)) {
            column.display = checked;
        }
    }
}

fn onCheckboxStatsColumnPlusMinus(checked: bool, state: *main.GameState) anyerror!void {
    for (state.statistics.uxData.columnsData) |*column| {
        if (std.mem.eql(u8, "+/-", column.name)) {
            column.display = checked;
        }
    }
}

fn onCheckboxStatsColumnGold(checked: bool, state: *main.GameState) anyerror!void {
    for (state.statistics.uxData.columnsData) |*column| {
        if (std.mem.eql(u8, "Gold", column.name)) {
            column.display = checked;
        }
    }
}

fn onCheckboxStatsNextLevel(checked: bool, state: *main.GameState) anyerror!void {
    state.statistics.uxData.displayNextLevelData = checked;
}

fn onSliderChangeVolume(sliderPerCent: f32, state: *main.GameState) anyerror!void {
    state.soundMixer.?.volume = sliderPerCent;
}

fn onSliderStopHoldingUxSize(sliderPerCent: f32, state: *main.GameState) anyerror!void {
    state.uxData.settingsMenuUx.uiSizeDelayed = 0.5 + sliderPerCent;
    setupUiLocations(state);
}
