const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const windowSdlZig = @import("../windowSdl.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const soundMixerZig = @import("../soundMixer.zig");
const playerZig = @import("../player.zig");

const DEATH_DURATION = 3000;

pub const NinjaDogPaintData = struct {
    weaponDrawn: bool = false,
    blinking: bool = false,
    weaponRotation: f32 = std.math.pi * 0.25,
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
    chestArmorImageIndex: u8 = imageZig.IMAGE_NINJA_CHEST_ARMOR_1,
    headLayer1ImageIndex: ?u8 = null,
    headLayer2ImageIndex: u8 = imageZig.IMAGE_NINJA_HEAD,
    headLayer2Offset: main.Position = .{ .x = 0, .y = 0 },
    earImageIndex: u8 = imageZig.IMAGE_NINJA_EAR,
    feetImageIndex: u8 = imageZig.IMAGE_NINJA_FEET,
    weaponImageIndex: u8 = imageZig.IMAGE_BLADE,
    hasBandana: bool = true,
    drawLeftEye: bool = true,
    drawRightEye: bool = true,
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
    lastUpdateTime: ?i64 = null,
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

pub fn tickNinjaDogAnimation(player: *playerZig.Player, timePassed: i64, state: *main.GameState) !void {
    try tickNinjaDogPawAnimation(player, timePassed, state);
    tickNinjaDogEyeAnimation(player, state);
    tickNinjaDogEarAnimation(player, state);
    tickNinjaDogBandanaAnimation(player, timePassed);
    tickNinjaDogTailAnimation(player, state);
}

fn tickNinjaDogTailAnimation(player: *playerZig.Player, state: *main.GameState) void {
    const paintData = &player.paintData;
    paintData.tailBend = @sin(@as(f32, @floatFromInt(state.gameTime)) / 400) * 0.5;
}

fn tickNinjaDogEarAnimation(player: *playerZig.Player, state: *main.GameState) void {
    const rand = std.crypto.random;
    if (@abs(player.animateData.ears.leftVelocity) < 0.005 and @abs(player.paintData.leftEarRotation) < 0.05) {
        player.animateData.ears.leftVelocity = std.math.sign(player.animateData.ears.leftVelocity) * (rand.float(f32) * 0.005 + 0.010);
    }
    if (@abs(player.animateData.ears.rightVelocity) < 0.005 and @abs(player.paintData.rightEarRotation) < 0.01) {
        player.animateData.ears.rightVelocity = std.math.sign(player.animateData.ears.rightVelocity) * (rand.float(f32) * 0.005 + 0.010);
    }
    player.paintData.leftEarRotation += player.animateData.ears.leftVelocity;
    player.paintData.rightEarRotation += player.animateData.ears.rightVelocity;
    if (player.animateData.ears.lastUpdateTime == null) {
        player.animateData.ears.lastUpdateTime = state.gameTime;
    }
    const timeDiffToVelocity = @as(f32, @floatFromInt(state.gameTime - player.animateData.ears.lastUpdateTime.?)) / 16000;
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

fn tickNinjaDogBandanaAnimation(player: *playerZig.Player, timePassed: i64) void {
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

fn tickNinjaDogEyeAnimation(player: *playerZig.Player, state: *main.GameState) void {
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

fn tickNinjaDogPawAnimation(player: *playerZig.Player, timePassed: i64, state: *main.GameState) !void {
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
                        .bladeToFront = .{ .angle = player.paintData.weaponRotation, .duration = 1000, .startTime = state.gameTime },
                    };
                    try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_BLADE_DRAW, 0, 1);
                }
            },
            .bladeToFront => |data| {
                const perCent: f32 = @min(1, @as(f32, @floatFromInt(state.gameTime - data.startTime)) / @as(f32, @floatFromInt(data.duration)));
                const targetAngle = std.math.pi * -0.75;
                player.paintData.weaponRotation = data.angle + (targetAngle - data.angle) * perCent;
                if (perCent >= 1) {
                    player.paintData.weaponDrawn = true;
                    player.animateData.paws = .{
                        .bladeToCenter = .{
                            .angle = player.paintData.weaponRotation,
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
                player.paintData.weaponRotation = data.angle + (targetAngle - data.angle) * perCent;
                if (perCent >= 1) {
                    player.animateData.paws = null;
                }
            },
        }
    }
}

pub fn setupVertices(state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;

    for (state.players.items) |*player| {
        if (player.isDead) continue;
        var currentAfterImageIndex: usize = 0;
        while (currentAfterImageIndex < player.afterImages.items.len) {
            if (verticeData.spritesComplex.verticeCount + 1 >= verticeData.spritesComplex.vertices.len) break;
            const afterImage = player.afterImages.items[currentAfterImageIndex];
            if (afterImage.deleteTime < state.gameTime) {
                _ = player.afterImages.swapRemove(currentAfterImageIndex);
                continue;
            }
            drawNinjaDog(afterImage.position, afterImage.paintData, state);
            currentAfterImageIndex += 1;
        }
        const drawPosition: main.Position = .{
            .x = player.position.x,
            .y = player.position.y - player.inAirHeight,
        };
        drawNinjaDog(drawPosition, player.paintData, state);
    }
}

pub fn drawNinjaDog(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const dogSize = imageZig.IMAGE_DOG_TOTAL_SIZE;
    drawDogTail(position, paintData, state);
    if (!paintData.weaponDrawn) {
        const bladeBackPosition: main.Position = .{
            .x = position.x + (imageZig.IMAGE_DOG__BLADE_BACK.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
            .y = position.y + (imageZig.IMAGE_DOG__BLADE_BACK.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        };
        addTiranglesForSprite(bladeBackPosition, imageZig.IMAGE_BLADE__HAND_HOLD_POINT, paintData.weaponImageIndex, paintData.weaponRotation, null, null, state);
    }
    drawHead(position, paintData, state);
    drawFeet(position, paintData, state);

    const chestSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__CENTER_BODY.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__CENTER_BODY.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    addTiranglesForSprite(chestSpritePosition, imageZig.getImageCenter(paintData.chestArmorImageIndex), paintData.chestArmorImageIndex, 0, null, null, state);
    drawEyes(position, paintData, state);
    const leftArmSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
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
        .x = position.x + (imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
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
    if (paintData.weaponDrawn) {
        const leftHandBladePosition: main.Position = .{
            .x = leftArmSpritePosition.x + (imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x - imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x + leftPawWithWaveOffset.x) / imageZig.IMAGE_TO_GAME_SIZE,
            .y = leftArmSpritePosition.y + (imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y - imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y + leftPawWithWaveOffset.y) / imageZig.IMAGE_TO_GAME_SIZE,
        };
        addTiranglesForSprite(
            leftHandBladePosition,
            imageZig.IMAGE_BLADE__HAND_HOLD_POINT,
            paintData.weaponImageIndex,
            paintData.weaponRotation,
            imageZig.IMAGE_BLADE__HAND_HOLD_POINT,
            null,
            state,
        );
    }
}

fn drawFeet(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const dogSize = imageZig.IMAGE_DOG_TOTAL_SIZE;
    const headPosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__FEET.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__FEET.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    addTiranglesForSprite(
        headPosition,
        imageZig.IMAGE_DOG_FEET__ANKER,
        paintData.feetImageIndex,
        0,
        null,
        null,
        state,
    );
}

fn drawHead(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const dogSize = imageZig.IMAGE_DOG_TOTAL_SIZE;
    if (paintData.hasBandana) drawBandana(position, paintData, state);
    drawEars(position, paintData, state);
    const headPosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__HEAD.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__HEAD.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    if (paintData.headLayer1ImageIndex) |imageIndex| {
        addTiranglesForSprite(
            headPosition,
            imageZig.IMAGE_DOG_HEAD__ANKER,
            imageIndex,
            0,
            null,
            null,
            state,
        );
    }
    addTiranglesForSprite(
        .{ .x = headPosition.x + paintData.headLayer2Offset.x, .y = headPosition.y + paintData.headLayer2Offset.y },
        imageZig.IMAGE_DOG_HEAD__ANKER,
        paintData.headLayer2ImageIndex,
        0,
        null,
        null,
        state,
    );
}

fn drawDogTail(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const dogSize = imageZig.IMAGE_DOG_TOTAL_SIZE;
    const dogTailSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__TAIL.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__TAIL.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    paintVulkanZig.addTiranglesForSpriteWithBend(
        dogTailSpritePosition,
        imageZig.IMAGE_DOG_TAIL__ANKER,
        imageZig.IMAGE_DOG_TAIL,
        paintData.tailRotation,
        null,
        null,
        paintData.tailBend,
        true,
        1,
        state,
    );
}

fn drawBandana(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const dogSize = imageZig.IMAGE_DOG_TOTAL_SIZE;
    const bandanaSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__BANDANA_TAIL.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__BANDANA_TAIL.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
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
    const dogSize = imageZig.IMAGE_DOG_TOTAL_SIZE;
    const leftEarSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__EAR_LEFT.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__EAR_LEFT.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    const rightEarSpritePosition: main.Position = .{
        .x = position.x + (imageZig.IMAGE_DOG__EAR_RIGHT.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        .y = position.y + (imageZig.IMAGE_DOG__EAR_RIGHT.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
    };
    addTiranglesForSprite(leftEarSpritePosition, imageZig.IMAGE_DOG_EAR__ANKER, paintData.earImageIndex, paintData.leftEarRotation, null, null, state);
    addTiranglesForSprite(rightEarSpritePosition, imageZig.IMAGE_DOG_EAR__ANKER, paintData.earImageIndex, paintData.rightEarRotation, null, null, state);
}

fn drawEyes(position: main.Position, paintData: NinjaDogPaintData, state: *main.GameState) void {
    const dogSize = imageZig.IMAGE_DOG_TOTAL_SIZE;
    if (paintData.drawLeftEye) {
        const leftEyeSpritePosition: main.Position = .{
            .x = position.x + (imageZig.IMAGE_DOG__EYE_LEFT.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
            .y = position.y + (imageZig.IMAGE_DOG__EYE_LEFT.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        };
        if (!paintData.blinking) {
            const leftPupilSpritePosition: main.Position = .{
                .x = leftEyeSpritePosition.x + paintData.leftPupilOffset.x / imageZig.IMAGE_TO_GAME_SIZE,
                .y = leftEyeSpritePosition.y + paintData.leftPupilOffset.y / imageZig.IMAGE_TO_GAME_SIZE,
            };
            addTiranglesForSprite(leftPupilSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_PUPIL_LEFT), imageZig.IMAGE_PUPIL_LEFT, 0, null, null, state);
            addTiranglesForSprite(leftEyeSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_EYE_LEFT), imageZig.IMAGE_EYE_LEFT, 0, null, null, state);
        } else {
            addTiranglesForSprite(leftEyeSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_EYE_CLOSED), imageZig.IMAGE_EYE_CLOSED, 0, null, null, state);
        }
    }
    if (paintData.drawRightEye) {
        const rightEyeSpritePosition: main.Position = .{
            .x = position.x + (imageZig.IMAGE_DOG__EYE_RIGHT.x - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
            .y = position.y + (imageZig.IMAGE_DOG__EYE_RIGHT.y - @as(f32, @floatFromInt(dogSize)) / 2) / imageZig.IMAGE_TO_GAME_SIZE,
        };
        if (!paintData.blinking) {
            const rightPupilSpritePosition: main.Position = .{
                .x = rightEyeSpritePosition.x + paintData.rightPupilOffset.x / imageZig.IMAGE_TO_GAME_SIZE,
                .y = rightEyeSpritePosition.y + paintData.rightPupilOffset.y / imageZig.IMAGE_TO_GAME_SIZE,
            };
            addTiranglesForSprite(rightPupilSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_PUPIL_RIGHT), imageZig.IMAGE_PUPIL_RIGHT, 0, null, null, state);
            addTiranglesForSprite(rightEyeSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_EYE_RIGHT), imageZig.IMAGE_EYE_RIGHT, 0, null, null, state);
        } else {
            addTiranglesForSprite(rightEyeSpritePosition, imageZig.getImageCenter(imageZig.IMAGE_EYE_CLOSED), imageZig.IMAGE_EYE_CLOSED, 0, null, null, state);
        }
    }
}

pub fn swordHandsCentered(player: *playerZig.Player, state: *main.GameState) void {
    if (player.animateData.paws == null and player.paintData.weaponDrawn == false) {
        player.animateData.paws = .{ .drawBlade = .{
            .duration = 500,
            .position = player.paintData.leftPawOffset,
            .startTime = state.gameTime,
        } };
    }
}

pub fn bladeSlashAnimate(player: *playerZig.Player) void {
    if (player.animateData.paws != null) player.animateData.paws = null;
    const pawAngle = @mod(player.paintData.weaponRotation + std.math.pi, std.math.pi * 2);
    setPawAndBladeAngle(player, pawAngle);
}

pub fn movedAnimate(player: *playerZig.Player, direction: u8) void {
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

fn setPawAndBladeAngle(player: *playerZig.Player, angle: f32) void {
    player.paintData.leftPawOffset = .{
        .x = @cos(angle) * 40 - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.x + imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.x,
        .y = @sin(angle) * 40 - imageZig.IMAGE_NINJA_DOG_PAW__HAND_HOLD_POINT.y + imageZig.IMAGE_NINJA_DOG_PAW__ARM_ROTATE_POINT.y,
    };
    player.paintData.rightPawOffset = .{
        .x = player.paintData.leftPawOffset.x + imageZig.IMAGE_DOG__LEFT_ARM_ROTATE_POINT.x - imageZig.IMAGE_DOG__RIGHT_ARM_ROTATE_POINT.x,
        .y = player.paintData.leftPawOffset.y,
    };
    player.paintData.weaponDrawn = true;
    player.paintData.weaponRotation = angle;
}

fn setEarDirection(player: *playerZig.Player, direction: u8) void {
    const floatRotation = @mod((@as(f32, @floatFromInt(direction)) - 1) * std.math.pi / 2.0, std.math.pi * 2) - std.math.pi;
    player.paintData.leftEarRotation = floatRotation;
    player.paintData.rightEarRotation = floatRotation;
    const earVelocity: f32 = if (floatRotation > 0) 0.01 else -0.01;
    player.animateData.ears.leftVelocity = earVelocity;
    player.animateData.ears.rightVelocity = earVelocity;
}

fn setDogTailDirection(player: *playerZig.Player, direction: u8) void {
    const floatRotation = @mod((@as(f32, @floatFromInt(direction))) * std.math.pi / 2.0, std.math.pi * 2) - std.math.pi;
    player.paintData.tailRotation = floatRotation;
}

fn setBandanaDirection(player: *playerZig.Player, direction: u8) void {
    const floatRotation = @mod((@as(f32, @floatFromInt(direction))) * std.math.pi / 2.0, std.math.pi * 2) - std.math.pi;
    player.paintData.bandana1Rotation = floatRotation;
    player.paintData.bandana2Rotation = floatRotation;
}

fn setEyeLookDirection(player: *playerZig.Player, direction: u8) void {
    const floatDirection = @as(f32, @floatFromInt(direction)) * std.math.pi / 2.0;
    player.paintData.leftPupilOffset = .{
        .x = @cos(floatDirection) * 5,
        .y = @sin(floatDirection) * 3,
    };
    player.paintData.rightPupilOffset = player.paintData.leftPupilOffset;
    player.paintData.blinking = false;
    player.animateData.eyes = null;
}

pub fn moveHandToCenter(player: *playerZig.Player, state: *main.GameState) void {
    player.animateData.paws = .{ .bladeToCenter = .{
        .angle = player.paintData.weaponRotation,
        .duration = 1000,
        .position1 = player.paintData.leftPawOffset,
        .position2 = player.paintData.rightPawOffset,
        .startTime = state.gameTime + 500,
    } };
}

pub fn addAfterImages(stepCount: usize, stepDirection: main.Position, player: *playerZig.Player, state: *main.GameState) !void {
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
    const verticeData = &state.vkState.verticeData;
    if (verticeData.spritesComplex.vertices.len <= verticeData.spritesComplex.verticeCount + 6) return;
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
        const rotatedOffset = main.rotateAroundPoint(cornerPosOffset, rotatePivot, rotateAngle);
        const vulkan: main.Position = .{
            .x = (rotatedOffset.x - state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
            .y = (rotatedOffset.y - state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
        };
        const texPos: [2]f32 = .{
            if (cornerPosOffset.x < imageAnkerXHalf) 0 else 1,
            if (cornerPosOffset.y < imageAnkerYHalf) 0 else 1,
        };

        verticeData.spritesComplex.vertices[verticeData.spritesComplex.verticeCount] = dataVulkanZig.SpriteComplexVertex{
            .pos = .{ vulkan.x, vulkan.y },
            .imageIndex = imageIndex,
            .alpha = 1,
            .tex = texPos,
        };
        verticeData.spritesComplex.verticeCount += 1;
    }
}

fn addTiranglesForSpriteWithWaveAnimation(gamePosition: main.Position, imageAnkerPosition: main.Position, imageIndex: u8, rotateAngle: f32, rotatePoint: ?main.Position, optScale: ?main.Position, waveOffset: f32, state: *main.GameState) void {
    const scale: main.Position = if (optScale) |s| s else .{ .x = 1, .y = 1 };
    const verticeData = &state.vkState.verticeData;
    if (verticeData.spritesComplex.vertices.len <= verticeData.spritesComplex.verticeCount + 24) return;
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
            const rotatedOffset = main.rotateAroundPoint(waveOffsetPos, rotatePivot, rotateAngle);
            const vulkan: main.Position = .{
                .x = (rotatedOffset.x - state.camera.position.x + gamePosition.x) * state.camera.zoom * onePixelXInVulkan,
                .y = (rotatedOffset.y - state.camera.position.y + gamePosition.y) * state.camera.zoom * onePixelYInVulkan,
            };
            verticeData.spritesComplex.vertices[verticeData.spritesComplex.verticeCount] = dataVulkanZig.SpriteComplexVertex{
                .pos = .{ vulkan.x, vulkan.y },
                .imageIndex = imageIndex,
                .alpha = 1,
                .tex = texPos,
            };
            verticeData.spritesComplex.verticeCount += 1;
        }
    }
}
