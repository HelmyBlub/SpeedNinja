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
    eyes: bool = true,
};

const EquipmentEffectType = enum {
    none,
    hp,
    damage,
    damagePerCent,
};

const EquipmentEffectTypeData = union(EquipmentEffectType) {
    none,
    hp: u8,
    damage: EquipEffectDamageData,
    damagePerCent: EquipEffectDamagePerCentData,
};

const EquipEffectDamageData = struct {
    damage: u32,
    effect: SecondaryEffect = .none,
};

const EquipEffectDamagePerCentData = struct {
    factor: f32,
    effect: SecondaryEffect = .none,
};

const SecondaryEffect = enum {
    none,
    hammer,
    kunai,
    gold,
    blind,
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
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_BLADE,
        .equipment = .{
            .effectType = .{ .damage = .{ .damage = 10 } },
            .imageIndex = imageZig.IMAGE_BLADE,
            .slotTypeData = .weapon,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_HAMMER,
        .equipment = .{
            .effectType = .{ .damage = .{ .damage = 4, .effect = .hammer } },
            .imageIndex = imageZig.IMAGE_HAMMER,
            .slotTypeData = .weapon,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_KUNAI,
        .equipment = .{
            .effectType = .{ .damage = .{ .damage = 6, .effect = .kunai } },
            .imageIndex = imageZig.IMAGE_KUNAI,
            .slotTypeData = .weapon,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_GOLD_BLADE,
        .equipment = .{
            .effectType = .{ .damage = .{ .damage = 5, .effect = .gold } },
            .imageIndex = imageZig.IMAGE_GOLD_BLADE,
            .slotTypeData = .weapon,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_BLINDFOLD,
        .equipment = .{
            .effectType = .{ .damagePerCent = .{ .factor = 1, .effect = .blind } },
            .imageIndex = imageZig.IMAGE_BLINDFOLD,
            .slotTypeData = .{
                .head = .{
                    .bandana = false,
                    .eyes = false,
                    .earImageIndex = imageZig.IMAGE_DOG_EAR,
                    .imageIndexLayer1 = imageZig.IMAGE_DOG_HEAD,
                },
            },
        },
    },
};

pub fn getEquipmentOptionByIndexScaledToLevel(index: usize, level: u32) EquipmentShopOptions {
    var option = EQUIPMENT_SHOP_OPTIONS[index];
    if (option.equipment.effectType == .damage) {
        const damageScaledToLevel = @max(1, @divFloor(@divFloor(level + 10, 5) * option.equipment.effectType.damage.damage, 10));
        option.equipment.effectType.damage.damage = damageScaledToLevel;
    }
    return option;
}

pub fn equipStarterEquipment(player: *main.Player) void {
    _ = equip(.{
        .effectType = .{ .hp = 1 },
        .imageIndex = imageZig.IMAGE_NINJA_HEAD,
        .slotTypeData = .{ .head = .{ .bandana = true, .earImageIndex = imageZig.IMAGE_NINJA_EAR } },
    }, false, player);
    _ = equip(.{ .effectType = .{ .hp = 1 }, .imageIndex = imageZig.IMAGE_NINJA_CHEST_ARMOR_1, .slotTypeData = .body }, false, player);
    _ = equip(.{ .effectType = .none, .imageIndex = imageZig.IMAGE_NINJA_FEET, .slotTypeData = .feet }, false, player);
    _ = equip(.{ .effectType = .{ .damage = .{ .damage = 1 } }, .imageIndex = imageZig.IMAGE_BLADE, .slotTypeData = .weapon }, false, player);
}

/// return true if item equipted
pub fn equip(equipment: EquipmentData, preventDowngrade: bool, player: *main.Player) bool {
    switch (equipment.slotTypeData) {
        .body => {
            return equipBody(equipment, preventDowngrade, player);
        },
        .feet => {
            return equipFeet(equipment, preventDowngrade, player);
        },
        .head => {
            return equipHead(equipment, preventDowngrade, player);
        },
        .weapon => {
            return equipWeapon(equipment, preventDowngrade, player);
        },
    }
}

fn unequip(slotType: EquipmentSlotTypes, player: *main.Player) void {
    switch (slotType) {
        .body => {
            _ = equipBody(null, false, player);
        },
        .feet => {
            _ = equipFeet(null, false, player);
        },
        .head => {
            _ = equipHead(null, false, player);
        },
        .weapon => {
            _ = equipWeapon(null, false, player);
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

fn equipHead(optHead: ?EquipmentData, preventDowngrade: bool, player: *main.Player) bool {
    const optOld = player.equipment.head;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optHead) |new| new.effectType else null;
    if (preventDowngrade and isDowngrade(optOldEffectType, optNewEffectType)) return false;
    equipmentEffect(optNewEffectType, optOldEffectType, player);

    player.equipment.head = optHead;
    if (optHead) |head| {
        player.paintData.headLayer1ImageIndex = head.slotTypeData.head.imageIndexLayer1;
        player.paintData.headLayer2ImageIndex = head.imageIndex;
        player.paintData.earImageIndex = head.slotTypeData.head.earImageIndex;
        player.paintData.headLayer2Offset = head.slotTypeData.head.offset;
        player.paintData.hasBandana = head.slotTypeData.head.bandana;
        player.paintData.drawEyes = head.slotTypeData.head.eyes;
    } else {
        player.paintData.headLayer1ImageIndex = null;
        player.paintData.headLayer2ImageIndex = imageZig.IMAGE_DOG_HEAD;
        player.paintData.earImageIndex = imageZig.IMAGE_DOG_EAR;
        player.paintData.headLayer2Offset = .{ .x = 0, .y = 0 };
        player.paintData.hasBandana = false;
        player.paintData.drawEyes = true;
    }
    return true;
}

fn equipBody(optBody: ?EquipmentData, preventDowngrade: bool, player: *main.Player) bool {
    const optOld = player.equipment.body;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optBody) |new| new.effectType else null;
    if (preventDowngrade and isDowngrade(optOldEffectType, optNewEffectType)) return false;
    equipmentEffect(optNewEffectType, optOldEffectType, player);
    player.equipment.body = optBody;
    if (optBody) |body| {
        player.paintData.chestArmorImageIndex = body.imageIndex;
    } else {
        player.paintData.chestArmorImageIndex = imageZig.IMAGE_NINJA_BODY_NO_ARMOR;
    }
    return true;
}

fn isDowngrade(optOldEffectType: ?EquipmentEffectTypeData, optNewEffectType: ?EquipmentEffectTypeData) bool {
    if (optOldEffectType != null and optNewEffectType != null) {
        if (@as(EquipmentEffectType, optOldEffectType.?) == @as(EquipmentEffectType, optNewEffectType.?)) {
            switch (optOldEffectType.?) {
                .damage => |damage| {
                    if (damage.damage >= optNewEffectType.?.damage.damage and @as(SecondaryEffect, optOldEffectType.?.damage.effect) == @as(SecondaryEffect, optNewEffectType.?.damage.effect)) {
                        return true;
                    }
                },
                .damagePerCent => |data| {
                    if (data.factor >= optNewEffectType.?.damagePerCent.factor and @as(SecondaryEffect, optOldEffectType.?.damagePerCent.effect) == @as(SecondaryEffect, optNewEffectType.?.damagePerCent.effect)) {
                        return true;
                    }
                },
                .hp => |hp| {
                    if (hp >= optNewEffectType.?.hp) {
                        return true;
                    }
                },
                else => {},
            }
        }
    }
    return false;
}

fn equipFeet(optFeet: ?EquipmentData, preventDowngrade: bool, player: *main.Player) bool {
    const optOld = player.equipment.feet;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optFeet) |new| new.effectType else null;
    if (preventDowngrade and isDowngrade(optOldEffectType, optNewEffectType)) return false;
    equipmentEffect(optNewEffectType, optOldEffectType, player);
    player.equipment.feet = optFeet;
    if (optFeet) |feet| {
        player.paintData.feetImageIndex = feet.imageIndex;
    } else {
        player.paintData.feetImageIndex = imageZig.IMAGE_NINJA_FEET;
    }
    return true;
}

fn equipWeapon(optWeapon: ?EquipmentData, preventDowngrade: bool, player: *main.Player) bool {
    const optOld = player.equipment.weapon;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optWeapon) |new| new.effectType else null;
    if (preventDowngrade and isDowngrade(optOldEffectType, optNewEffectType)) return false;
    equipmentEffect(optNewEffectType, optOldEffectType, player);
    player.equipment.weapon = optWeapon;
    if (optWeapon) |weapon| {
        player.paintData.weaponImageIndex = weapon.imageIndex;
    } else {
        player.paintData.weaponImageIndex = imageZig.IMAGE_BLADE;
    }
    return true;
}

fn equipmentEffect(optNewEffectType: ?EquipmentEffectTypeData, optOldEffectType: ?EquipmentEffectTypeData, player: *main.Player) void {
    if (optOldEffectType) |oldEffectType| {
        var optSecondaryEffect: ?SecondaryEffect = null;
        switch (oldEffectType) {
            .none => {},
            .damage => |damage| {
                player.damage -= damage.damage;
                optSecondaryEffect = damage.effect;
            },
            .damagePerCent => |data| {
                player.damagePerCentFactor -= data.factor;
                optSecondaryEffect = data.effect;
            },
            .hp => {},
        }
        if (optSecondaryEffect) |secEffect| {
            switch (secEffect) {
                .hammer => {
                    player.hasWeaponHammer = false;
                },
                .kunai => {
                    player.hasWeaponKunai = false;
                },
                .gold => {
                    player.moneyBonusPerCent = 0;
                },
                .blind => {
                    player.hasBlindfold = false;
                },
                .none => {},
            }
        }
    }
    if (optNewEffectType) |newEffectType| {
        var optSecondaryEffect: ?SecondaryEffect = null;
        switch (newEffectType) {
            .none => {},
            .damage => |damage| {
                player.damage += damage.damage;
                optSecondaryEffect = damage.effect;
            },
            .damagePerCent => |data| {
                player.damagePerCentFactor += data.factor;
                optSecondaryEffect = data.effect;
            },
            .hp => {},
        }
        if (optSecondaryEffect) |secEffect| {
            switch (secEffect) {
                .hammer => {
                    player.hasWeaponHammer = true;
                },
                .kunai => {
                    player.hasWeaponKunai = true;
                },
                .gold => {
                    player.moneyBonusPerCent = 0.5;
                },
                .blind => {
                    player.hasBlindfold = true;
                },
                .none => {},
            }
        }
    }
}
