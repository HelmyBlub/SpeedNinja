const std = @import("std");
const main = @import("../main.zig");
const initVulkanZig = @import("initVulkan.zig");
const vk = initVulkanZig.vk;
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const soundMixerZig = @import("../soundMixer.zig");

const DEATH_DURATION = 3000;

pub const VkNinjaDogData = struct {
    vertexBuffer: vk.VkBuffer = undefined,
    vertexBufferMemory: vk.VkDeviceMemory = undefined,
    vertices: []dataVulkanZig.SpriteComplexVertex = undefined,
    verticeCount: usize = 0,
    pub const MAX_VERTICES = 8000; //TODO not checked limit
};

pub const NinjaDogPaintData = struct {
    bladeDrawn: bool = false,
    blinking: bool = false,
    bladeRotation: f32 = std.math.pi * 0.25,
    pawWaveOffset: f32 = 0,
    leftPawOffset: main.Position = .{ .x = 0, .y = 0 },
    rightPawOffset: main.Position = .{ .x = 0, .y = 0 },
    leftPupilOffset: main.Position = .{ .x = 0, .y = 0 },
    rightPupilOffset: main.Position = .{ .x = 0, .y = 0 },
    leftEarRotation: f32 = 0,
    rightEarRotation: f32 = 0,
    bandana1Rotation: f32 = 0,
    bandana1WaveOffset: f32 = 1,
    bandana2Rotation: f32 = 0,
    bandana2WaveOffset: f32 = 0,
    tailRotation: f32 = 0,
    tailBend: f32 = 0,
};

const NinjaDogAnimationStatePaw = enum {
    drawBlade,
    bladeToFront,
    bladeToCenter,
};

pub const NinjaDogAnimationStatePawData = union(NinjaDogAnimationStatePaw) {
    drawBlade: NinjaDogAnimationStateDataTypePosition,
    bladeToFront: NinjaDogAnimationStateDataTypeAngle,
    bladeToCenter: NinjaDogAnimationStateDataType2PositionAndAngle,
};

const NinjaDogAnimationStateEye = enum {
    moveEyes,
    blink,
};

pub const NinjaDogAnimationStateEyeData = union(NinjaDogAnimationStateEye) {
    moveEyes: NinjaDogAnimationStateDataType2Position,
    blink: NinjaDogAnimationStateDataTypeBasic,
};

pub const NinjaDogAnimationStateData = struct {
    paws: ?NinjaDogAnimationStatePawData = null,
    eyes: ?NinjaDogAnimationStateEyeData = null,
    ears: NinjaDogAnimationStateDataTypeEars = .{},
};

const NinjaDogAnimationStateDataTypeEars = struct {
    leftVelocity: f32 = 0,
    rightVelocity: f32 = 0,
    lastUpdateTime: i64 = 0,
};

const NinjaDogAnimationStateDataTypeBasic = struct {
    startTime: i64,
    duration: i64,
};

const NinjaDogAnimationStateDataType2Position = struct {
    position1: main.Position,
    position2: main.Position,
    startTime: i64,
    duration: i64,
};

const NinjaDogAnimationStateDataType2PositionAndAngle = struct {
    position1: main.Position,
    position2: main.Position,
    angle: f32,
    startTime: i64,
    duration: i64,
};

const NinjaDogAnimationStateDataTypePosition = struct {
    position: main.Position,
    startTime: i64,
    duration: i64,
};

const NinjaDogAnimationStateDataTypeAngle = struct {
    angle: f32,
    startTime: i64,
    duration: i64,
};

pub fn tickNinjaDogAnimation(player: *main.Player, timePassed: i64, state: *main.GameState) !void {
    try tickNinjaDogPawAnimation(player, timePassed, state);
    tickNinjaDogEyeAnimation(player, state);
    tickNinjaDogEarAnimation(player, state);
    tickNinjaDogBandanaAnimation(player, timePassed);
    tickNinjaDogTailAnimation(player, state);
}

fn tickNinjaDogTailAnimation(player: *main.Player, state: *main.GameState) void {
    const paintData = &player.paintData;
    paintData.tailBend = @sin(@as(f32, @floatFromInt(state.gameTime)) / 400) * 0.5;
}

fn tickNinjaDogEarAnimation(player: *main.Player, state: *main.GameState) void {
    const rand = std.crypto.random;
    if (@abs(player.animateData.ears.leftVelocity) < 0.005 and @abs(player.paintData.leftEarRotation) < 0.05) {
        player.animateData.ears.leftVelocity = std.math.sign(player.animateData.ears.leftVelocity) * (rand.float(f32) * 0.005 + 0.010);
    }
    if (@abs(player.animateData.ears.rightVelocity) < 0.005 and @abs(player.paintData.rightEarRotation) < 0.01) {
        player.animateData.ears.rightVelocity = std.math.sign(player.animateData.ears.rightVelocity) * (rand.float(f32) * 0.005 + 0.010);
    }
    player.paintData.leftEarRotation += player.animateData.ears.leftVelocity;
    player.paintData.rightEarRotation += player.animateData.ears.rightVelocity;
    const timeDiffToVelocity = @as(f32, @floatFromInt(state.gameTime - player.animateData.ears.lastUpdateTime)) / 16000;
    player.animateData.ears.lastUpdateTime = state.gameTime;
    const dampenFactor = 1.4;
    if (player.animateData.ears.leftVelocity > 0 and player.paintData.leftEarRotation > 0) {
        player.animateData.ears.leftVelocity -= timeDiffToVelocity * dampenFactor;
    } else if (player.animateData.ears.leftVelocity <= 0 and player.paintData.leftEarRotation > 0) {
        player.animateData.ears.leftVelocity -= timeDiffToVelocity / dampenFactor;
    } else {
        player.animateData.ears.leftVelocity += timeDiffToVelocity;
    }
    if (player.animateData.ears.rightVelocity > 0 and player.paintData.rightEarRotation > 0) {
        player.animateData.ears.rightVelocity -= timeDiffToVelocity * dampenFactor;
    } else if (player.animateData.ears.rightVelocity <= 0 and player.paintData.rightEarRotation > 0) {
        player.animateData.ears.rightVelocity -= timeDiffToVelocity / dampenFactor;
    } else {
        player.animateData.ears.rightVelocity += timeDiffToVelocity;
    }
}

fn tickNinjaDogBandanaAnimation(player: *main.Player, timePassed: i64) void {
    const rand = std.crypto.random;
    const paintData = &player.paintData;

    const timePassedFloatFactor = @as(f32, @floatFromInt(timePassed)) * 0.01;
    if (@abs(paintData.bandana1Rotation) > 0.2) {
        paintData.bandana1Rotation *= 1 - timePassedFloatFactor * 0.05;
        paintData.bandana2Rotation *= 1 - timePassedFloatFactor * 0.05;
    }
    paintData.bandana1WaveOffset = @mod(player.paintData.bandana1WaveOffset + (rand.float(f32) + 1) * timePassedFloatFactor * 0.5, std.math.pi * 2);
    paintData.bandana2WaveOffset = @mod(player.paintData.bandana2WaveOffset + (rand.float(f32) + 1) * timePassedFloatFactor * 0.5, std.math.pi * 2);
}

fn tickNinjaDogEyeAnimation(player: *main.Player, state: *main.GameState) void {
    if (player.animateData.eyes) |animateEye| {
        switch (animateEye) {
            .blink => |data| {
                if (state.gameTime >= data.startTime) {
                    if (state.gameTime <= data.startTime + data.duration) {
                        player.paintData.blinking = true;
                    } else {
                        player.paintData.blinking = false;
                        player.animateData.eyes = null;
                    }
                }
            },
            .moveEyes => |data| {
                const perCent: f32 = @max(@min(1, @as(f32, @floatFromInt(state.gameTime - data.startTime)) / @as(f32, @floatFromInt(data.duration))), 0);
                player.paintData.leftPupilOffset = .{
                    .x = data.position1.x + (data.position2.x - data.position1.x) * perCent,
                    .y = data.position1.y + (data.position2.y - data.position1.y) * perCent,
                };
                player.paintData.rightPupilOffset = player.paintData.leftPupilOffset;
                if (perCent >= 1) {
                    player.animateData.eyes = null;
                }
            },
        }
    } else {
        const rand = std.crypto.random;
        if (rand.float(f32) < 0.6) {
            player.animateData.eyes = .{ .moveEyes = .{
                .duration = 100,
                .position1 = player.paintData.leftPupilOffset,
                .position2 = .{ .x = rand.float(f32) * 10 - 5, .y = rand.float(f32) * 6 - 3 },
                .startTime = state.gameTime + 1000 + @as(i64, @intFromFloat(rand.float(f32) * 2000)),
            } };
        } else {
            player.animateData.eyes = .{ .blink = .{
                .duration = 300,
                .startTime = state.gameTime + 100 + @as(i64, @intFromFloat(rand.float(f32) * 1000)),
            } };
        }
    }
}

fn tickNinjaDogPawAnimation(player: *main.Player, timePassed: i64, state: *main.GameState) !void {
    player.paintData.pawWaveOffset = @mod(player.paintData.pawWaveOffset + @as(f32, @floatFromInt(timePassed)) / 300, std.math.pi * 2);
    if (player.animateData.paws) |animationData| {
        switch (animationData) {
            .drawBlade => |data| {
                const leftHandTarget: main.Position = .{
                    .x = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x - imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x + imageZig.IMAGE_DOG__BLADE_BACK.x,
                    .y = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y - imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.y + imageZig.IMAGE_DOG__BLADE_BACK.y,
                };
                const perCent: f32 = @min(1, @as(f32, @floatFromInt(state.gameTime - data.startTime)) / @as(f32, @floatFromInt(data.duration)));
                player.paintData.leftPawOffset = .{
                    .x = data.position.x + (leftHandTarget.x - data.position.x) * perCent,
                    .y = data.position.y + (leftHandTarget.y - data.position.y) * perCent,
                };
                if (perCent >= 1) {
                    player.animateData.paws = .{
                        .bladeToFront = .{ .angle = player.paintData.bladeRotation, .duration = 1000, .startTime = state.gameTime },
                    };
                    try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_BLADE_DRAW, 0);
                }
            },
            .bladeToFront => |data| {
                const perCent: f32 = @min(1, @as(f32, @floatFromInt(state.gameTime - data.startTime)) / @as(f32, @floatFromInt(data.duration)));
                const targetAngle = std.math.pi * -0.75;
                player.paintData.bladeRotation = data.angle + (targetAngle - data.angle) * perCent;
                if (perCent >= 1) {
                    player.paintData.bladeDrawn = true;
                    player.animateData.paws = .{
                        .bladeToCenter = .{
                            .angle = player.paintData.bladeRotation,
                            .duration = 1000,
                            .startTime = state.gameTime,
                            .position1 = player.paintData.leftPawOffset,
                            .position2 = player.paintData.rightPawOffset,
                        },
                    };
                }
            },
            .bladeToCenter => |data| {
                const perCent: f32 = @max(@min(1, @as(f32, @floatFromInt(state.gameTime - data.startTime)) / @as(f32, @floatFromInt(data.duration))), 0);
                const targetAngle = std.math.pi * 1.5;
                const leftHandTarget: main.Position = .{
                    .x = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x - imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x + imageZig.IMAGE_DOG__BLADE_CENTER_HOLD.x,
                    .y = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y - imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.y + imageZig.IMAGE_DOG__BLADE_CENTER_HOLD.y,
                };
                const rightHandTarget: main.Position = .{
                    .x = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x - imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.x + imageZig.IMAGE_DOG__BLADE_CENTER_HOLD.x,
                    .y = imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y - imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.y + imageZig.IMAGE_DOG__BLADE_CENTER_HOLD.y,
                };
                player.paintData.leftPawOffset = .{
                    .x = data.position1.x + (leftHandTarget.x - data.position1.x) * perCent,
                    .y = data.position1.y + (leftHandTarget.y - data.position1.y) * perCent,
                };
                player.paintData.rightPawOffset = .{
                    .x = data.position2.x + (rightHandTarget.x - data.position2.x) * perCent,
                    .y = data.position2.y + (rightHandTarget.y - data.position2.y) * perCent,
                };
                player.paintData.bladeRotation = data.angle + (targetAngle - data.angle) * perCent;
                if (perCent >= 1) {
                    player.animateData.paws = null;
                }
            },
        }
    }
}

fn setupVertices(state: *main.GameState) !void {
    const ninjaDogData = &state.vkState.ninjaDogData;
    ninjaDogData.verticeCount = 0;

    for (state.players.items) |*player| {
        var currentAfterImageIndex: usize = 0;
        while (currentAfterImageIndex < player.afterImages.items.len) {
            if (ninjaDogData.verticeCount + 1 >= ninjaDogData.vertices.len) break;
            const afterImage = player.afterImages.items[currentAfterImageIndex];
            if (afterImage.deleteTime < state.gameTime) {
                _ = player.afterImages.swapRemove(currentAfterImageIndex);
                continue;
            }
            drawNinjaDog(afterImage.position, afterImage.paintData, state);
            currentAfterImageIndex += 1;
        }

        drawNinjaDog(player.position, player.paintData, state);
    }

    try setupVertexDataForGPU(&state.vkState);
}

pub fn drawNinjaDog(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const imageDataDog = imageZig.IMAGE_DATA[imageZig.IMAGE_DOG];
    drawDogTail(position, paintData, state);
    if (!paintData.bladeDrawn) {
        const bladeBackPosition: main.Position = .{
            .x = position.x + (imageZig.IMAGE_DOG__BLADE_BACK.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
            .y = position.y + (imageZig.IMAGE_DOG__BLADE_BACK.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        };
        addTiranglesForSprite(bladeBackPosition, imageZig.IMAGE_BLADE__HAND_HOLD_POINT, imageZig.IMAGE_BLADE, paintData.bladeRotation, null, null, state);
    }
    drawBandana(position, paintData, state);
    drawEars(position, paintData, state);
    addTiranglesForSprite(position, imageZig.IMAGE_DOG__CENTER, imageZig.IMAGE_DOG, 0, null, null, state);
    drawEyes(position, paintData, state);
    const leftArmSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    const leftPawWithWaveOffset: main.Position = .{ .x = paintData.leftPawOffset.x, .y = paintData.leftPawOffset.y + @sin(paintData.pawWaveOffset) * 2 };
    const leftArmValues = calcScalingAndRotation(imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT, imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT, leftPawWithWaveOffset);
    addTiranglesForSprite(
        leftArmSpritePosition,
        imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT,
        imageZig.IMAGE_NINJA_DOG_PAW,
        leftArmValues.angle,
        imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT,
        .{ .x = 1, .y = leftArmValues.scale },
        state,
    );
    const rightArmSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    const rightPawWithWaveOffset: main.Position = .{ .x = paintData.rightPawOffset.x, .y = paintData.rightPawOffset.y + @sin(paintData.pawWaveOffset) * 2 };
    const rightArmValues = calcScalingAndRotation(imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT, imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT, rightPawWithWaveOffset);
    addTiranglesForSprite(
        rightArmSpritePosition,
        imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT,
        imageZig.IMAGE_NINJA_DOG_PAW,
        rightArmValues.angle,
        imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT,
        .{ .x = 1, .y = rightArmValues.scale },
        state,
    );
    if (paintData.bladeDrawn) {
        const leftHandBladePosition: main.Position = .{
            .x = leftArmSpritePosition.x + (imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x - imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x + leftPawWithWaveOffset.x) / imageZig.IMAGE_TO_GAME_SIZE,
            .y = leftArmSpritePosition.y + (imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y - imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y + leftPawWithWaveOffset.y) / imageZig.IMAGE_TO_GAME_SIZE,
        };
        addTiranglesForSprite(
            leftHandBladePosition,
            imageZig.IMAGE_BLADE__HAND_HOLD_POINT,
            imageZig.IMAGE_BLADE,
            paintData.bladeRotation,
            imageZig.IMAGE_BLADE__HAND_HOLD_POINT,
            null,
            state,
        );
    }
}

fn drawDogTail(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const imageDataDog = imageZig.IMAGE_DATA[imageZig.IMAGE_DOG];
    const dogTailSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__TAIL.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__TAIL.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    addTiranglesForSpriteWithBend(
        dogTailSpritePosition,
        imageZig.IMAGE_DOG_TAIL__ANKER,
        imageZig.IMAGE_DOG_TAIL,
        paintData.tailRotation,
        null,
        null,
        paintData.tailBend,
        state,
    );
}

fn drawBandana(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const imageDataDog = imageZig.IMAGE_DATA[imageZig.IMAGE_DOG];
    const bandanaSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__BANDANA_TAIL.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__BANDANA_TAIL.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    const bandana2SpritePosition: main.Position = .{
        .x = bandanaSpritePosition.x,
        .y = bandanaSpritePosition.y + 0.5,
    };
    addTiranglesForSpriteWithWaveAnimation(
        bandanaSpritePosition,
        imageZig.IMAGE_BANDANA__ANKER,
        imageZig.IMAGE_BANDANA_TAIL,
        paintData.bandana1Rotation,
        null,
        null,
        paintData.bandana1WaveOffset,
        state,
    );
    addTiranglesForSpriteWithWaveAnimation(
        bandana2SpritePosition,
        imageZig.IMAGE_BANDANA__ANKER,
        imageZig.IMAGE_BANDANA_TAIL,
        paintData.bandana2Rotation,
        null,
        null,
        paintData.bandana2WaveOffset,
        state,
    );
}

fn drawEars(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const imageDataDog = imageZig.IMAGE_DATA[imageZig.IMAGE_DOG];
    const leftEarSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__EAR_LEFT.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__EAR_LEFT.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    const rightEarSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__EAR_RIGHT.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__EAR_RIGHT.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    addTiranglesForSprite(leftEarSpritePosition, imageZig.IMAGE_DOG_EAR__ANKER, imageZig.IMAGE_DOG_EAR, paintData.leftEarRotation, null, null, state);
    addTiranglesForSprite(rightEarSpritePosition, imageZig.IMAGE_DOG_EAR__ANKER, imageZig.IMAGE_DOG_EAR, paintData.rightEarRotation, null, null, state);
}

fn drawEyes(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const imageDataDog = imageZig.IMAGE_DATA[imageZig.IMAGE_DOG];
    const leftEyeSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__EYE_LEFT.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__EYE_LEFT.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    const rightEyeSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__EYE_RIGHT.x - @as(f32, @floatFromInt(imageDataDog.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__EYE_RIGHT.y - @as(f32, @floatFromInt(imageDataDog.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    if (!paintData.blinking) {
        const leftPupilSpritePosition: main.Position = .{
            .x = leftEyeSpritePosition.x + paintData.leftPupilOffset.x / imageZig.IMAGE_TO_GAME_SIZE,
            .y = leftEyeSpritePosition.y + paintData.leftPupilOffset.y / imageZig.IMAGE_TO_GAME_SIZE,
        };
        const rightPupilSpritePosition: main.Position = .{
            .x = rightEyeSpritePosition.x + paintData.rightPupilOffset.x / imageZig.IMAGE_TO_GAME_SIZE,
            .y = rightEyeSpritePosition.y + paintData.rightPupilOffset.y / imageZig.IMAGE_TO_GAME_SIZE,
        };
        addTiranglesForSprite(leftPupilSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_PUPIL_LEFT), imageZig.IMAGE_PUPIL_LEFT, 0, null, null, state);
        addTiranglesForSprite(rightPupilSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_PUPIL_RIGHT), imageZig.IMAGE_PUPIL_RIGHT, 0, null, null, state);
        addTiranglesForSprite(leftEyeSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_EYE_LEFT), imageZig.IMAGE_EYE_LEFT, 0, null, null, state);
        addTiranglesForSprite(rightEyeSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_EYE_RIGHT), imageZig.IMAGE_EYE_RIGHT, 0, null, null, state);
    } else {
        addTiranglesForSprite(leftEyeSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_EYE_CLOSED), imageZig.IMAGE_EYE_CLOSED, 0, null, null, state);
        addTiranglesForSprite(rightEyeSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_EYE_CLOSED), imageZig.IMAGE_EYE_CLOSED, 0, null, null, state);
    }
}

pub fn swordHandsCentered(player: *main.Player, state: *main.GameState) void {
    if (player.animateData.paws == null and player.paintData.bladeDrawn == false) {
        player.animateData.paws = .{ .drawBlade = .{
            .duration = 500,
            .position = player.paintData.leftPawOffset,
            .startTime = state.gameTime,
        } };
    }
}

pub fn bladeSlashAnimate(player: *main.Player) void {
    if (player.animateData.paws != null) player.animateData.paws = null;
    const pawAngle = @mod(player.paintData.bladeRotation + std.math.pi, std.math.pi * 2);
    setPawAndBladeAngle(player, pawAngle);
}

pub fn movedAnimate(player: *main.Player, direction: u8) void {
    const handDirection = direction + 2;
    const baseAngle: f32 = @as(f32, @floatFromInt(handDirection)) * std.math.pi * 0.5;
    if (player.animateData.paws != null) player.animateData.paws = null;
    const rand = std.crypto.random;
    const randomPawAngle = @mod(rand.float(f32) * std.math.pi / 2.0 - std.math.pi / 4.0 + baseAngle, std.math.pi * 2);
    setPawAndBladeAngle(player, randomPawAngle);
    setEyeLookDirection(player, direction);
    setEarDirection(player, direction);
    setBandanaDirection(player, direction);
    setDogTailDirection(player, direction);
}

fn setPawAndBladeAngle(player: *main.Player, angle: f32) void {
    player.paintData.leftPawOffset = .{
        .x = @cos(angle) * 40 - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x + imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x,
        .y = @sin(angle) * 40 - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y + imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y,
    };
    player.paintData.rightPawOffset = .{
        .x = player.paintData.leftPawOffset.x + imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x - imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.x,
        .y = player.paintData.leftPawOffset.y,
    };
    player.paintData.bladeDrawn = true;
    player.paintData.bladeRotation = angle;
}

fn setEarDirection(player: *main.Player, direction: u8) void {
    const floatRotation = @mod((@as(f32, @floatFromInt(direction)) - 1) * std.math.pi / 2.0, std.math.pi * 2) - std.math.pi;
    player.paintData.leftEarRotation = floatRotation;
    player.paintData.rightEarRotation = floatRotation;
    const earVelocity: f32 = if (floatRotation > 0) 0.01 else -0.01;
    player.animateData.ears.leftVelocity = earVelocity;
    player.animateData.ears.rightVelocity = earVelocity;
}

fn setDogTailDirection(player: *main.Player, direction: u8) void {
    const floatRotation = @mod((@as(f32, @floatFromInt(direction))) * std.math.pi / 2.0, std.math.pi * 2) - std.math.pi;
    player.paintData.tailRotation = floatRotation;
}

fn setBandanaDirection(player: *main.Player, direction: u8) void {
    const floatRotation = @mod((@as(f32, @floatFromInt(direction))) * std.math.pi / 2.0, std.math.pi * 2) - std.math.pi;
    player.paintData.bandana1Rotation = floatRotation;
    player.paintData.bandana2Rotation = floatRotation;
}

fn setEyeLookDirection(player: *main.Player, direction: u8) void {
    const floatDirection = @as(f32, @floatFromInt(direction)) * std.math.pi / 2.0;
    player.paintData.leftPupilOffset = .{
        .x = @cos(floatDirection) * 5,
        .y = @sin(floatDirection) * 3,
    };
    player.paintData.rightPupilOffset = player.paintData.leftPupilOffset;
    player.paintData.blinking = false;
    player.animateData.eyes = null;
}

pub fn moveHandToCenter(player: *main.Player, state: *main.GameState) void {
    player.animateData.paws = .{ .bladeToCenter = .{
        .angle = player.paintData.bladeRotation,
        .duration = 1000,
        .position1 = player.paintData.leftPawOffset,
        .position2 = player.paintData.rightPawOffset,
        .startTime = state.gameTime + 500,
    } };
}

pub fn addAfterImages(stepCount: usize, stepDirection: main.Position, player: *main.Player, state: *main.GameState) !void {
    for (0..stepCount) |i| {
        try player.afterImages.append(.{
            .deleteTime = state.gameTime + 75 + @as(i64, @intCast(i)) * 10,
            .position = .{
                .x = player.position.x + stepDirection.x * @as(f32, @floatFromInt(i)) * main.TILESIZE,
                .y = player.position.y + stepDirection.y * @as(f32, @floatFromInt(i)) * main.TILESIZE,
            },
            .paintData = player.paintData,
        });
    }
}

fn calcScalingAndRotation(baseAnker: main.Position, zeroOffset: main.Position, targetOffset: main.Position) struct { angle: f32, scale: f32 } {
    const zeroAndTargetOffset: main.Position = .{ .x = zeroOffset.x + targetOffset.x, .y = zeroOffset.y + targetOffset.y };
    const distance = main.calculateDistance(baseAnker, zeroOffset);
    const distance2 = main.calculateDistance(baseAnker, zeroAndTargetOffset);
    const scale: f32 = distance2 / distance;
    const angle = angleAtB(zeroOffset, baseAnker, zeroAndTargetOffset);
    return .{ .angle = angle, .scale = scale };
}

fn angleAtB(a: main.Position, b: main.Position, c: main.Position) f32 {
    const vectorBA = main.Position{
        .x = a.x - b.x,
        .y = a.y - b.y,
    };
    const vectorBC = main.Position{
        .x = c.x - b.x,
        .y = c.y - b.y,
    };

    const dot = vectorBA.x * vectorBC.x + vectorBA.y * vectorBC.y;
    const cross = vectorBA.x * vectorBC.y - vectorBA.y * vectorBC.x;
    return std.math.atan2(cross, dot);
}

/// rotatePoint = image coordinates
pub fn addTiranglesForSprite(gamePosition: main.Position, imageAnkerPosition: main.Position, imageIndex: u8, rotateAngle: f32, rotatePoint: ?main.Position, optScale: ?main.Position, state: *main.GameState) void {
    const scale: main.Position = if (optScale) |s| s else .{ .x = 1, .y = 1 };
    const ninjaDogData = &state.vkState.ninjaDogData;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const imageData = imageZig.IMAGE_DATA[imageIndex];
    const halfSizeWidth: f32 = @as(f32, @floatFromInt(imageData.width)) / imageZig.IMAGE_TO_GAME_SIZE / 2 * scale.x;
    const halfSizeHeigh: f32 = @as(f32, @floatFromInt(imageData.height)) / imageZig.IMAGE_TO_GAME_SIZE / 2 * scale.y;
    const imageAnkerXHalf = (@as(f32, @floatFromInt(imageData.width)) / 2 - imageAnkerPosition.x) / imageZig.IMAGE_TO_GAME_SIZE * scale.x;
    const imageAnkerYHalf = (@as(f32, @floatFromInt(imageData.height)) / 2 - imageAnkerPosition.y) / imageZig.IMAGE_TO_GAME_SIZE * scale.y;
    const corners: [4]main.Position = [4]main.Position{
        main.Position{ .x = -halfSizeWidth + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = -halfSizeWidth + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
    };
    const verticeOrder = [_]usize{ 0, 1, 2, 0, 2, 3 };
    for (verticeOrder) |verticeIndex| {
        const cornerPosOffset = corners[verticeIndex];
        const rotatePivot: main.Position = if (rotatePoint) |p| .{
            .x = (p.x - @as(f32, @floatFromInt(imageData.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE * scale.x + imageAnkerXHalf,
            .y = (p.y - @as(f32, @floatFromInt(imageData.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE * scale.y + imageAnkerYHalf,
        } else .{ .x = 0, .y = 0 };
        const rotatedOffset = paintVulkanZig.rotateAroundPoint(cornerPosOffset, rotatePivot, rotateAngle);
        const vulkan: main.Position = .{
            .x = (rotatedOffset.x - state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
            .y = (rotatedOffset.y - state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
        };
        const texPos: [2]f32 = .{
            if (cornerPosOffset.x < 0) 0 else 1,
            if (cornerPosOffset.y < 0) 0 else 1,
        };
        ninjaDogData.vertices[ninjaDogData.verticeCount] = dataVulkanZig.SpriteComplexVertex{
            .pos = .{ vulkan.x, vulkan.y },
            .imageIndex = imageIndex,
            .alpha = 1,
            .tex = texPos,
        };
        ninjaDogData.verticeCount += 1;
    }
}

fn addTiranglesForSpriteWithWaveAnimation(gamePosition: main.Position, imageAnkerPosition: main.Position, imageIndex: u8, rotateAngle: f32, rotatePoint: ?main.Position, optScale: ?main.Position, waveOffset: f32, state: *main.GameState) void {
    const scale: main.Position = if (optScale) |s| s else .{ .x = 1, .y = 1 };
    const ninjaDogData = &state.vkState.ninjaDogData;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const imageData = imageZig.IMAGE_DATA[imageIndex];
    const halfSizeWidth: f32 = @as(f32, @floatFromInt(imageData.width)) / imageZig.IMAGE_TO_GAME_SIZE / 2 * scale.x;
    const halfSizeHeigh: f32 = @as(f32, @floatFromInt(imageData.height)) / imageZig.IMAGE_TO_GAME_SIZE / 2 * scale.y;
    const imageAnkerXHalf = (@as(f32, @floatFromInt(imageData.width)) / 2 - imageAnkerPosition.x) / imageZig.IMAGE_TO_GAME_SIZE * scale.x;
    const imageAnkerYHalf = (@as(f32, @floatFromInt(imageData.height)) / 2 - imageAnkerPosition.y) / imageZig.IMAGE_TO_GAME_SIZE * scale.y;
    const quarterStep = halfSizeWidth / 2;
    const points = [_]main.Position{
        main.Position{ .x = -halfSizeWidth + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = -halfSizeWidth + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = -halfSizeWidth + quarterStep + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = -halfSizeWidth + quarterStep + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth - quarterStep + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth - quarterStep + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
    };
    for (0..points.len - 2) |i| {
        const pointsIndexes = [_]usize{ i, i + 1 + @mod(i, 2), i + 2 - @mod(i, 2) };
        for (pointsIndexes) |verticeIndex| {
            const cornerPosOffset = points[verticeIndex];
            const texPos: [2]f32 = .{
                ((cornerPosOffset.x - imageAnkerXHalf) / halfSizeWidth + 1) / 2,
                ((cornerPosOffset.y - imageAnkerYHalf) / halfSizeHeigh + 1) / 2,
            };
            const rotatePivot: main.Position = if (rotatePoint) |p| .{
                .x = (p.x - @as(f32, @floatFromInt(imageData.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE * scale.x + imageAnkerXHalf,
                .y = (p.y - @as(f32, @floatFromInt(imageData.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE * scale.y + imageAnkerYHalf,
            } else .{ .x = 0, .y = 0 };
            const waveOffsetPos: main.Position = .{
                .x = cornerPosOffset.x,
                .y = cornerPosOffset.y + @sin(cornerPosOffset.x + waveOffset) * 2 * texPos[0],
            };
            const rotatedOffset = paintVulkanZig.rotateAroundPoint(waveOffsetPos, rotatePivot, rotateAngle);
            const vulkan: main.Position = .{
                .x = (rotatedOffset.x - state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
                .y = (rotatedOffset.y - state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
            };
            ninjaDogData.vertices[ninjaDogData.verticeCount] = dataVulkanZig.SpriteComplexVertex{
                .pos = .{ vulkan.x, vulkan.y },
                .imageIndex = imageIndex,
                .alpha = 1,
                .tex = texPos,
            };
            ninjaDogData.verticeCount += 1;
        }
    }
}

fn addTiranglesForSpriteWithBend(gamePosition: main.Position, imageAnkerPosition: main.Position, imageIndex: u8, rotateAngle: f32, rotatePoint: ?main.Position, optScale: ?main.Position, bend: f32, state: *main.GameState) void {
    const scale: main.Position = if (optScale) |s| s else .{ .x = 1, .y = 1 };
    const ninjaDogData = &state.vkState.ninjaDogData;
    const onePixelXInVulkan = 2 / windowSdlZig.windowData.widthFloat;
    const onePixelYInVulkan = 2 / windowSdlZig.windowData.heightFloat;
    const imageData = imageZig.IMAGE_DATA[imageIndex];
    const halfSizeWidth: f32 = @as(f32, @floatFromInt(imageData.width)) / imageZig.IMAGE_TO_GAME_SIZE / 2 * scale.x;
    const halfSizeHeigh: f32 = @as(f32, @floatFromInt(imageData.height)) / imageZig.IMAGE_TO_GAME_SIZE / 2 * scale.y;
    const imageAnkerXHalf = (@as(f32, @floatFromInt(imageData.width)) / 2 - imageAnkerPosition.x) / imageZig.IMAGE_TO_GAME_SIZE * scale.x;
    const imageAnkerYHalf = (@as(f32, @floatFromInt(imageData.height)) / 2 - imageAnkerPosition.y) / imageZig.IMAGE_TO_GAME_SIZE * scale.y;
    const quarterStep = halfSizeWidth / 2;
    const points = [_]main.Position{
        main.Position{ .x = -halfSizeWidth + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = -halfSizeWidth + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = -halfSizeWidth + quarterStep + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = -halfSizeWidth + quarterStep + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth - quarterStep + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth - quarterStep + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth + imageAnkerXHalf, .y = halfSizeHeigh + imageAnkerYHalf },
        main.Position{ .x = halfSizeWidth + imageAnkerXHalf, .y = -halfSizeHeigh + imageAnkerYHalf },
    };
    for (0..points.len - 2) |i| {
        const pointsIndexes = [_]usize{ i, i + 1 + @mod(i, 2), i + 2 - @mod(i, 2) };
        for (pointsIndexes) |verticeIndex| {
            const cornerPosOffset = points[verticeIndex];
            const texPos: [2]f32 = .{
                ((cornerPosOffset.x - imageAnkerXHalf) / halfSizeWidth + 1) / 2,
                ((cornerPosOffset.y - imageAnkerYHalf) / halfSizeHeigh + 1) / 2,
            };
            const rotatePivot: main.Position = if (rotatePoint) |p| .{
                .x = (p.x - @as(f32, @floatFromInt(imageData.width)) / 2) / imageZig.IMAGE_TO_GAME_SIZE * scale.x + imageAnkerXHalf,
                .y = (p.y - @as(f32, @floatFromInt(imageData.height)) / 2) / imageZig.IMAGE_TO_GAME_SIZE * scale.y + imageAnkerYHalf,
            } else .{ .x = 0, .y = 0 };
            const bendAngle: f32 = rotateAngle + bend * texPos[0];
            const rotatedOffset = paintVulkanZig.rotateAroundPoint(cornerPosOffset, rotatePivot, bendAngle);
            const vulkan: main.Position = .{
                .x = (rotatedOffset.x - state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
                .y = (rotatedOffset.y - state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
            };
            ninjaDogData.vertices[ninjaDogData.verticeCount] = dataVulkanZig.SpriteComplexVertex{
                .pos = .{ vulkan.x, vulkan.y },
                .imageIndex = imageIndex,
                .alpha = 1,
                .tex = texPos,
            };
            ninjaDogData.verticeCount += 1;
        }
    }
}

pub fn create(state: *main.GameState) !void {
    try createVertexBuffer(&state.vkState, state.allocator);
}

pub fn destroy(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) void {
    const ninjaDog = vkState.ninjaDogData;
    vk.vkDestroyBuffer.?(vkState.logicalDevice, ninjaDog.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, ninjaDog.vertexBufferMemory, null);
    allocator.free(ninjaDog.vertices);
}

fn setupVertexDataForGPU(vkState: *initVulkanZig.VkState) !void {
    const ninjaDog = vkState.ninjaDogData;
    var data: ?*anyopaque = undefined;
    if (vk.vkMapMemory.?(vkState.logicalDevice, ninjaDog.vertexBufferMemory, 0, @sizeOf(dataVulkanZig.SpriteComplexVertex) * ninjaDog.vertices.len, 0, &data) != vk.VK_SUCCESS) return error.MapMemory;
    const gpu_vertices: [*]dataVulkanZig.SpriteComplexVertex = @ptrCast(@alignCast(data));
    @memcpy(gpu_vertices, ninjaDog.vertices[0..]);
    vk.vkUnmapMemory.?(vkState.logicalDevice, ninjaDog.vertexBufferMemory);
}

pub fn recordCommandBuffer(commandBuffer: vk.VkCommandBuffer, state: *main.GameState) !void {
    try setupVertices(state);
    const vkState = &state.vkState;

    vk.vkCmdBindPipeline.?(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, vkState.graphicsPipelines.spriteComplex);
    const vertexBuffers: [1]vk.VkBuffer = .{vkState.ninjaDogData.vertexBuffer};
    const offsets: [1]vk.VkDeviceSize = .{0};
    vk.vkCmdBindVertexBuffers.?(commandBuffer, 0, 1, &vertexBuffers[0], &offsets[0]);
    vk.vkCmdDraw.?(commandBuffer, @intCast(vkState.ninjaDogData.verticeCount), 1, 0, 0);
}

fn createVertexBuffer(vkState: *initVulkanZig.VkState, allocator: std.mem.Allocator) !void {
    vkState.ninjaDogData.vertices = try allocator.alloc(dataVulkanZig.SpriteComplexVertex, VkNinjaDogData.MAX_VERTICES);
    try initVulkanZig.createBuffer(
        @sizeOf(dataVulkanZig.SpriteComplexVertex) * vkState.ninjaDogData.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &vkState.ninjaDogData.vertexBuffer,
        &vkState.ninjaDogData.vertexBufferMemory,
        vkState,
    );
}
