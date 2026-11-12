-- Art du Guerrier : icônes des cartes et des bibelots, voies, classe et ressource (Rage).
-- Champ `tga` = icône améliorée de Media/Icons (tools/build_media.py --icons-only la copie depuis
-- ~/Téléchargements/ICONS) ; `spell` = repli par l'icône du sort ; `icon` = repli par chemin du client.
local _, ns = ...

local Art = ns.Art
local hex = Art.hex

local function I(tga, spell)
  return { tga = tga, spell = spell, icon = "Interface\\Icons\\" .. tga:lower() }
end

local cards = {
  strike             = I("Ability_Warrior_PunishingBlow"),
  defend             = I("Ability_Warrior_DefensiveStance"),
  heroic_strike      = I("Ability_Rogue_Ambush", 78),
  bloodrage          = I("Ability_Racial_BloodRage", 2687),
  rend               = I("Ability_Gouge", 772),
  overpower          = I("Ability_MeleeDamage", 7384),
  slam               = I("Ability_Warrior_DecisiveStrike", 1464),
  cleave             = I("Ability_Warrior_Cleave", 845),
  mortal_strike      = I("Ability_Warrior_SavageBlow", 12294),
  execute            = I("INV_Sword_48", 5308),
  colossus_smash     = I("Ability_Warrior_ColossusSmash", 167105),
  pummel             = I("INV_Gauntlets_04", 6552),
  bladestorm         = I("Ability_Warrior_Bladestorm", 46924),
  deep_wounds        = I("Ability_BackStab", 12162),
  raging_blow        = I("Ability_Hunter_SwiftStrike", 85288),
  whirlwind          = I("Ability_Whirlwind", 1680),
  victory_rush       = I("Ability_Warrior_VictoryRush", 34428),
  berserker_rage     = I("Spell_Nature_AncestralGuardian", 18499),
  bloodthirst        = I("Spell_Nature_BloodLust", 23881),
  rampage            = I("Ability_Warrior_Rampage", 184367),
  battle_shout       = I("Ability_Warrior_BattleShout", 6673),
  onslaught          = I("Ability_Warrior_UnrelentingAssault", 315720),
  enrage             = I("Ability_Warrior_InnerRage", 184361),
  recklessness       = I("Ability_CriticalStrike", 1719),
  shield_block       = I("Ability_Defend", 2565),
  revenge            = I("Ability_Warrior_Revenge", 6572),
  thunder_clap       = I("Ability_ThunderClap", 6343),
  devastate          = I("Ability_Warrior_Devastate", 20243),
  demoralizing_shout = I("Ability_Warrior_WarCry", 1160),
  shield_slam        = I("INV_Shield_05", 23922),
  ignore_pain        = I("Ability_Warrior_RenewedVigor", 190456),
  retaliation        = I("Ability_Warrior_Challange", 20230),
  shield_wall        = I("Ability_Warrior_ShieldWall", 871),
  last_stand         = I("Spell_Holy_AshesToAshes", 12975),
}
for id, e in pairs(cards) do Art.cards[id] = e end

-- Corps des cartes : les cartes de départ en or (règle commune), la Protection en bleu par son
-- premier effet d'Absorption, le reste en ivoire.

Art.paths.arms       = { name = "Arms",       ring = hex("#b0743a"), ink = hex("#6b3f12") }
Art.paths.fury       = { name = "Fury",       ring = hex("#c0392b"), ink = hex("#7a1d12") }
Art.paths.protection = { name = "Protection", ring = hex("#8aa2b8"), ink = hex("#34506b") }

Art.relics.battle_standard     = I("INV_Banner_02")
Art.relics.diamond_flask       = I("INV_Drink_01")
Art.relics.hand_of_justice     = I("INV_Jewelry_Talisman_01")
Art.relics.lionheart_helm      = I("INV_Helmet_36")
Art.relics.force_reactive_disk = I("INV_Shield_20")
Art.relics.skullflame_shield   = I("INV_Shield_03")

-- Icône d'un DoT selon sa source (Combat.applyStatus(..., icon) : Rend, Deep Wounds).
Art.statusIcons = Art.statusIcons or {}
Art.statusIcons.bleed = I("Ability_Gouge")

Art.classes.warrior = I("ClassIcon_Warrior")
Art.classes.warrior.wow = "WARRIOR"
Art.classes.warrior.resource = { tga = "Ability_Warrior_FocusedRage", icon = "Interface\\Icons\\ability_warrior_focusedrage",
  color = "attackText" }
