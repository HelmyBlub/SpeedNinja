const std = @import("std");
const imageZig = @import("image.zig");
const main = @import("main.zig");

pub const EquipmentSlotTypes = enum {
    head,
    body,
    feet,
    weapon,
};

pub const EquipmentSlotTypeData = union(EquipmentSlotTypes) {
    head: EquipmentHeadData,
    body: EquipmentData,
    feet: EquipmentData,
    weapon: EquipmentData,
};

const EquipmentData = struct {
    quipmentType: EquipmentTypeData,
    imageIndex: u8,
};

const EquipmentHeadData = struct {
    quipmentType: EquipmentTypeData,
    bandana: bool,
    imageIndexLayer1: ?u8 = null,
    imageIndexLayer2: u8,
    earImageIndex: u8 = imageZig.IMAGE_DOG_EAR,
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

pub fn equipStarterEquipment(player: *main.Player) void {
    equipHead(.{ .head = .{ .quipmentType = .none, .imageIndexLayer2 = imageZig.IMAGE_NINJA_HEAD, .bandana = true, .earImageIndex = imageZig.IMAGE_NINJA_EAR } }, player);
    equipBody(.{ .body = .{ .quipmentType = .{ .hp = 1 }, .imageIndex = imageZig.IMAGE_NINJA_CHEST_ARMOR_1 } }, player);
    equipFeet(.{ .feet = .{ .quipmentType = .none, .imageIndex = imageZig.IMAGE_NINJA_FEET } }, player);
    equipWeapon(.{ .weapon = .{ .quipmentType = .{ .damage = 1 }, .imageIndex = imageZig.IMAGE_BLADE } }, player);
}

pub fn equip(equipment: EquipmentSlotTypeData, player: *main.Player) void {
    switch (equipment) {
        .body => {
            equipBody(equipment, player);
        },
        .feet => {
            equipFeet(equipment, player);
        },
        .head => {
            equipHead(equipment, player);
        },
        .weapon => {
            equipWeapon(equipment, player);
        },
    }
}

fn equipHead(head: EquipmentSlotTypeData, player: *main.Player) void {
    player.equipment.set(.head, head);
    player.paintData.headLayer1ImageIndex = head.head.imageIndexLayer1;
    player.paintData.headLayer2ImageIndex = head.head.imageIndexLayer2;
    player.paintData.earImageIndex = head.head.earImageIndex;
}

fn equipBody(body: EquipmentSlotTypeData, player: *main.Player) void {
    const oldBody = player.equipment.get(.body);
    const optOldEffectType = if (oldBody) |old| old.body.quipmentType else null;
    equipmentEffect(body.body.quipmentType, optOldEffectType, player);
    player.equipment.set(.body, body);
    player.paintData.chestArmorImageIndex = body.body.imageIndex;
}

fn equipFeet(feet: EquipmentSlotTypeData, player: *main.Player) void {
    player.equipment.set(.feet, feet);
    player.paintData.feetImageIndex = feet.feet.imageIndex;
}

fn equipWeapon(weapon: EquipmentSlotTypeData, player: *main.Player) void {
    player.equipment.set(.weapon, weapon);
    player.paintData.weaponImageIndex = weapon.weapon.imageIndex;
}

fn equipmentEffect(newEffectType: EquipmentTypeData, optOldEffectType: ?EquipmentTypeData, player: *main.Player) void {
    if (optOldEffectType) |oldEffectType| {
        switch (oldEffectType) {
            .none => {},
            .damage => {},
            .hp => |hp| {
                if (player.hp == 0) std.debug.print("bug: no hp left when unequiping armor\n", .{});
                player.hp -|= hp;
            },
        }
    }
    switch (newEffectType) {
        .none => {},
        .damage => {},
        .hp => |hp| {
            player.hp += hp;
        },
    }
}
