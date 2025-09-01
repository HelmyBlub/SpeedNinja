const std = @import("std");
const imageZig = @import("image.zig");
const main = @import("main.zig");

const EquipmentSlots = struct {
    head: EquipmentData = .{ .quipmentType = .none, .imageIndex = imageZig.IMAGE_DOG },
    body: EquipmentData = .{ .quipmentType = .{ .hp = 1 }, .imageIndex = imageZig.IMAGE_NINJA_CHEST_ARMOR_1 },
    feet: EquipmentData = .{ .quipmentType = .none, .imageIndex = imageZig.IMAGE_DOG },
    weapon: EquipmentData = .{ .quipmentType = .{ .damage = 1 }, .imageIndex = imageZig.IMAGE_BLADE },
};

const EquipmentData = struct {
    quipmentType: EquipmentTypeData,
    imageIndex: u8,
};

const EquipmentType = enum {
    none,
    hp,
    damage,
};

const EquipmentTypeData = union(EquipmentType) {
    none,
    hp: u8,
    damage: u8,
};
