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
    head: ?EquipmentData = null,
    body: ?EquipmentData = null,
    feet: ?EquipmentData = null,
    weapon: ?EquipmentData = null,
};

const EquipmentSlotTypeData = union(EquipmentSlotTypes) {
    head: EquipmentHeadData,
    body,
    feet,
    weapon,
};

pub const EquipmentData = struct {
    effectType: EquipmentEffectTypeData,
    imageIndex: u8,
    slotTypeData: EquipmentSlotTypeData,
};

const EquipmentHeadData = struct {
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

pub const EquipmentShopOptions = struct {
    basePrice: u32,
    shopDisplayImage: u8,
    equipment: EquipmentData,
};

pub const EQUIPMENT_SHOP_OPTIONS = [_]EquipmentShopOptions{
    .{
        .basePrice = 5,
        .shopDisplayImage = imageZig.IMAGE_NINJA_HEAD,
        .equipment = .{
            .effectType = .{ .hp = 1 },
            .imageIndex = imageZig.IMAGE_NINJA_HEAD,
            .slotTypeData = .{ .head = .{ .bandana = true, .earImageIndex = imageZig.IMAGE_NINJA_EAR } },
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_NINJA_CHEST_ARMOR_2,
        .equipment = .{
            .effectType = .{ .hp = 2 },
            .imageIndex = imageZig.IMAGE_NINJA_CHEST_ARMOR_2,
            .slotTypeData = .body,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_MILITARY_HELMET,
        .equipment = .{
            .effectType = .{ .hp = 2 },
            .imageIndex = imageZig.IMAGE_MILITARY_HELMET,
            .slotTypeData = .{
                .head = .{
                    .bandana = false,
                    .earImageIndex = imageZig.IMAGE_DOG_EAR,
                    .imageIndexLayer1 = imageZig.IMAGE_DOG_HEAD,
                    .offset = imageZig.IMAGE_MILITARY_HELMET__OFFSET_GAME,
                },
            },
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_MILITARY_BOOTS,
        .equipment = .{
            .effectType = .{ .hp = 2 },
            .imageIndex = imageZig.IMAGE_MILITARY_BOOTS,
            .slotTypeData = .feet,
        },
    },
};

pub fn equipStarterEquipment(player: *main.Player) void {
    equip(.{
        .effectType = .{ .hp = 1 },
        .imageIndex = imageZig.IMAGE_NINJA_HEAD,
        .slotTypeData = .{ .head = .{ .bandana = true, .earImageIndex = imageZig.IMAGE_NINJA_EAR } },
    }, player);
    equip(.{ .effectType = .{ .hp = 1 }, .imageIndex = imageZig.IMAGE_NINJA_CHEST_ARMOR_1, .slotTypeData = .body }, player);
    equip(.{ .effectType = .none, .imageIndex = imageZig.IMAGE_NINJA_FEET, .slotTypeData = .feet }, player);
    equip(.{ .effectType = .{ .damage = 1 }, .imageIndex = imageZig.IMAGE_BLADE, .slotTypeData = .weapon }, player);
}

pub fn equip(equipment: EquipmentData, player: *main.Player) void {
    switch (equipment.slotTypeData) {
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

pub fn unequip(slotType: EquipmentSlotTypes, player: *main.Player) void {
    switch (slotType) {
        .body => {
            equipBody(null, player);
        },
        .feet => {
            equipFeet(null, player);
        },
        .head => {
            equipHead(null, player);
        },
        .weapon => {
            equipWeapon(null, player);
        },
    }
}

pub fn damageTakenByEquipment(player: *main.Player, state: *main.GameState) !bool {
    var equipBrokenImageIndex: ?u8 = null;
    var equipTookDamage = false;
    inline for (@typeInfo(EquipmentSlotsData).@"struct".fields) |field| {
        const valPtr: *?EquipmentData = &@field(player.equipment, field.name);
        if (valPtr.* != null) {
            const effectType: EquipmentEffectTypeData = valPtr.*.?.effectType;
            if (effectType == .hp) {
                valPtr.*.?.effectType.hp -= 1;
                equipTookDamage = true;
                if (valPtr.*.?.effectType.hp == 0) {
                    equipBrokenImageIndex = valPtr.*.?.imageIndex;
                    unequip(valPtr.*.?.slotTypeData, player);
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

fn equipHead(optHead: ?EquipmentData, player: *main.Player) void {
    const optOld = player.equipment.head;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optHead) |new| new.effectType else null;
    equipmentEffect(optNewEffectType, optOldEffectType, player);

    player.equipment.head = optHead;
    if (optHead) |head| {
        player.paintData.headLayer1ImageIndex = head.slotTypeData.head.imageIndexLayer1;
        player.paintData.headLayer2ImageIndex = head.imageIndex;
        player.paintData.earImageIndex = head.slotTypeData.head.earImageIndex;
        player.paintData.headLayer2Offset = head.slotTypeData.head.offset;
        player.paintData.hasBandana = head.slotTypeData.head.bandana;
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

fn equipWeapon(optWeapon: ?EquipmentData, player: *main.Player) void {
    const optOld = player.equipment.weapon;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optWeapon) |new| new.effectType else null;
    equipmentEffect(optNewEffectType, optOldEffectType, player);
    player.equipment.weapon = optWeapon;
    if (optWeapon) |weapon| {
        player.paintData.weaponImageIndex = weapon.imageIndex;
    } else {
        player.paintData.weaponImageIndex = imageZig.IMAGE_BLADE;
    }
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
