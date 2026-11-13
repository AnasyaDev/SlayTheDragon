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
  -- cartes épiques (une par zone)
  death_wish         = I("Spell_Shadow_DeathPact", 12292),
  thunderous_roar    = I("Ability_Warrior_DragonRoar", 384318),
  sweeping_strikes   = I("Ability_Rogue_SliceDice", 12328),
  titans_grip        = I("Ability_Warrior_TitansGrip", 46917),
  shield_charge      = I("Ability_Warrior_ShieldCharge", 385952),
  anger_management   = I("Ability_Warrior_EndlessRage", 152278),
  avatar             = I("Warrior_Talent_Icon_Avatar", 107574),
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

-- Vue de classe (zone libre sous les états du héros, 300 × 40) : le compteur que l'épique demande pour jouer
-- (son icône est posée parmi les Powers par le socle des épiques) :
--   Titan's Grip       « Titan's Grip: 1/2 Attacks » (Attacks comptées du tour)
--   Shield Charge      « Shield Charge: 7 » (coup de fin de tour avec l'Absorb actuelle)
--   Anger Management   « Anger Management: 2/3 Rage » (Rage dépensée vers le prochain cran de recharge)
-- Le plafond de Rage d'Avatar se lit sur les crans (Combat.resCap). Ne lit que le combat.
function ns.Warrior.epicLabel(c)
  local Wr = ns.Warrior
  local id, up = Wr.epicOf(c)
  if id == "titans_grip" then
    local n = Wr.EPIC.titans_grip.limit
    return ("Titan's Grip: %d/%d Attacks"):format(math.min(c.cls.tgAttacks or 0, n), n)
  elseif id == "shield_charge" then
    return "Shield Charge: " .. Wr.chargeDamage(c, up)
  elseif id == "anger_management" then
    local per = up and Wr.EPIC.anger_management.upPer or Wr.EPIC.anger_management.per
    return ("Anger Management: %d/%d Rage"):format(c.cls.amSpent or 0, per)
  end
  return nil
end

ns.ClassViews.warrior = {
  build = function(host)
    local W, C = ns.Widgets, Art.C
    host.count = W.label(host, "bold", 12.5, C.goldText)
    host.count:SetPoint("LEFT", host, "LEFT", 4, 0)
    host.count:SetWidth(290)
    host.count:SetJustifyH("LEFT")
    host.count:SetWordWrap(false)
  end,
  render = function(host, c)
    local label = ns.Warrior.epicLabel(c)
    if label then
      host.count:SetText(label)
      host.count:Show()
    else
      host.count:Hide()
    end
  end,
}
