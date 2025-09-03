const std = @import("std");
const imageZig = @import("image.zig");
const main = @import("main.zig");

pub const EquipmentSlotTypes = enum {
    head,
    body,
    feet,
    weapon,
};

pub const EquipmentSlotsData = struct {
    head: ?EquipmentHeadData = null,
    body: ?EquipmentData = null,
    feet: ?EquipmentData = null,
    weapon: ?EquipmentData = null,
};

pub const EquipmentSlotTypeData = union(EquipmentSlotTypes) {
    head: ?EquipmentHeadData,
    body: ?EquipmentData,
    feet: ?EquipmentData,
    weapon: ?EquipmentData,
};

const EquipmentData = struct {
    effectType: EquipmentEffectTypeData,
    imageIndex: u8,
};

const EquipmentHeadData = struct {
    effectType: EquipmentEffectTypeData,
    imageIndex: u8,
    bandana: bool,
    imageIndexLayer1: ?u8 = null,
    earImageIndex: u8 = imageZig.IMAGE_DOG_EAR,
    offset: main.Position = .{ .x = 0, .y = 0 },
};

const EquipmentEffectType = enum {
    none,
    hp,
    damage,
};

const EquipmentEffectTypeData = union(EquipmentEffectType) {
    none,
    hp: u8,
    damage: u8,
};

pub fn equipStarterEquipment(player: *main.Player) void {
    equipHead(.{ .effectType = .{ .hp = 1 }, .imageIndex = imageZig.IMAGE_NINJA_HEAD, .bandana = true, .earImageIndex = imageZig.IMAGE_NINJA_EAR }, player);
    equipBody(.{ .effectType = .{ .hp = 1 }, .imageIndex = imageZig.IMAGE_NINJA_CHEST_ARMOR_1 }, player);
    equipFeet(.{ .effectType = .none, .imageIndex = imageZig.IMAGE_NINJA_FEET }, player);
    equipWeapon(.{ .effectType = .{ .damage = 1 }, .imageIndex = imageZig.IMAGE_BLADE }, player);
}

pub fn equip(equipment: EquipmentSlotTypeData, player: *main.Player) void {
    switch (equipment) {
        .body => {
            equipBody(equipment.body, player);
        },
        .feet => {
            equipFeet(equipment.feet, player);
        },
        .head => {
            equipHead(equipment.head, player);
        },
        .weapon => {
            equipWeapon(equipment.weapon.?, player);
        },
    }
}

pub fn damageTakenByEquipment(player: *main.Player, state: *main.GameState) !bool {
    var equipBrokenImageIndex: ?u8 = null;
    var equipTookDamage = false;
    inline for (@typeInfo(EquipmentSlotsData).@"struct".fields) |field| {
        const valPtr = &@field(player.equipment, field.name);
        if (valPtr.* != null) {
            const effectType: EquipmentEffectTypeData = valPtr.*.?.effectType;
            if (effectType == .hp) {
                valPtr.*.?.effectType.hp -= 1;
                equipTookDamage = true;
                if (valPtr.*.?.effectType.hp == 0) {
                    equipBrokenImageIndex = valPtr.*.?.imageIndex;
                    equip(@unionInit(EquipmentSlotTypeData, field.name, null), player);
                }
                break;
            }
        }
    }
    if (equipBrokenImageIndex) |imageIndex| {
        try state.spriteCutAnimations.append(
            .{
                .deathTime = state.gameTime,
                .position = player.position,
                .cutAngle = 0,
                .force = 1.2,
                .colorOrImageIndex = .{ .imageIndex = imageIndex },
            },
        );
    }
    return equipTookDamage;
}

fn equipHead(optHead: ?EquipmentHeadData, player: *main.Player) void {
    const optOld = player.equipment.head;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optHead) |new| new.effectType else null;
    equipmentEffect(optNewEffectType, optOldEffectType, player);

    player.equipment.head = optHead;
    if (optHead) |head| {
        player.paintData.headLayer1ImageIndex = head.imageIndexLayer1;
        player.paintData.headLayer2ImageIndex = head.imageIndex;
        player.paintData.earImageIndex = head.earImageIndex;
        player.paintData.headLayer2Offset = head.offset;
        player.paintData.hasBandana = head.bandana;
    } else {
        player.paintData.headLayer1ImageIndex = null;
        player.paintData.headLayer2ImageIndex = imageZig.IMAGE_DOG_HEAD;
        player.paintData.earImageIndex = imageZig.IMAGE_DOG_EAR;
        player.paintData.headLayer2Offset = .{ .x = 0, .y = 0 };
        player.paintData.hasBandana = false;
    }
}

fn equipBody(optBody: ?EquipmentData, player: *main.Player) void {
    const optOld = player.equipment.body;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optBody) |new| new.effectType else null;
    equipmentEffect(optNewEffectType, optOldEffectType, player);
    player.equipment.body = optBody;
    if (optBody) |body| {
        player.paintData.chestArmorImageIndex = body.imageIndex;
    } else {
        player.paintData.chestArmorImageIndex = imageZig.IMAGE_NINJA_BODY_NO_ARMOR;
    }
}

fn equipFeet(optFeet: ?EquipmentData, player: *main.Player) void {
    const optOld = player.equipment.feet;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optFeet) |new| new.effectType else null;
    equipmentEffect(optNewEffectType, optOldEffectType, player);

    player.equipment.feet = optFeet;
    if (optFeet) |feet| {
        player.paintData.feetImageIndex = feet.imageIndex;
    } else {
        player.paintData.feetImageIndex = imageZig.IMAGE_NINJA_FEET;
    }
}

fn equipWeapon(weapon: EquipmentData, player: *main.Player) void {
    const optOld = player.equipment.weapon;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    equipmentEffect(weapon.effectType, optOldEffectType, player);
    player.equipment.weapon = weapon;
    player.paintData.weaponImageIndex = weapon.imageIndex;
}

fn equipmentEffect(optNewEffectType: ?EquipmentEffectTypeData, optOldEffectType: ?EquipmentEffectTypeData, player: *main.Player) void {
    _ = player;
    if (optOldEffectType) |oldEffectType| {
        switch (oldEffectType) {
            .none => {},
            .damage => {},
            .hp => {},
        }
    }
    if (optNewEffectType) |newEffectType| {
        switch (newEffectType) {
            .none => {},
            .damage => {},
            .hp => {},
        }
    }
}
