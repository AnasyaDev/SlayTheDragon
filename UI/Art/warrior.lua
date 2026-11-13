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

-- Vue de classe (zone libre sous les états du héros, 300 × 40) : ligne de l'épique, comme celle du Voleur,
-- icône (infobulle : la carte) et ce qu'elle change maintenant :
--   Death Wish         « Attacks +50%, no Absorb »
--   Thunderous Roar    « Roar in 3 Rage: 3 to all »
--   Sweeping Strikes   « Targeted hits splash 1 other for half » (deux ennemis vivants au moins)
--   Titan's Grip       « Attacks this turn: 0/1, each twice »
--   Shield Charge      « End of turn: 7 to Defias Thug » (avec de l'Absorb)
--   Anger Management   « Each Rage spent: Cooldowns −1 » (une carte en recharge au moins)
--   Avatar             « Rage up to 10, +2 next turn »
-- Ne lit que le combat.
local EPIC_ICON = 22
local function n(v) return "|cffffffff" .. tostring(v) .. "|r" end

function Art.warriorEpicLine(c)
  local Wr = ns.Warrior
  if not Wr then return nil end
  local id, up = Wr.epicOf(c)
  if not id then return nil end
  local E = Wr.EPIC
  if id == "death_wish" then
    return ("Attacks %s, no Absorb"):format(n("+" .. math.floor((E.death_wish.mult - 1) * 100 + 0.5) .. "%"))
  elseif id == "thunderous_roar" then
    local T = E.thunderous_roar
    return ("Roar in %s Rage: %s to all"):format(n(math.max(1, T.at - (c.player.res or 0))), n(up and T.upDamage or T.damage))
  elseif id == "sweeping_strikes" then
    local alive = #ns.Combat.aliveEnemies(c)
    if alive < 2 then return nil end
    local k = math.min(alive - 1, up and E.sweeping_strikes.upTargets or E.sweeping_strikes.targets)
    return ("Targeted hits splash %s other%s for half"):format(n(k), k > 1 and "s" or "")
  elseif id == "titans_grip" then
    local lim = E.titans_grip.limit
    return ("Attacks this turn: %s/%d, each twice"):format(n(math.min(c.cls.tgAttacks or 0, lim)), lim)
  elseif id == "shield_charge" then
    local dmg = Wr.chargeDamage(c, up)
    local t = dmg > 0 and Wr.chargeTarget(c)
    if not t then return nil end
    local d = ns.Enemies[t.id]
    return ("End of turn: %s to %s"):format(n(ns.Combat.calcDamage(c, c.player, t, dmg)), d and d.name or "the target")
  elseif id == "anger_management" then
    if #c.cooldown == 0 then return nil end
    local A = E.anger_management
    local per = up and A.upPer or A.per
    local steps = up and A.upSteps or A.steps
    if per > 1 then
      return ("Rage spent: %s/%d, then Cooldowns −%d"):format(n(c.cls.amSpent or 0), per, steps)
    end
    return ("Each Rage spent: Cooldowns %s"):format(n("−" .. steps))
  elseif id == "avatar" then
    return ("Rage up to %s, %s next turn"):format(n(E.avatar.cap), n("+" .. (up and E.avatar.upGain or E.avatar.gain)))
  end
  return nil
end

ns.ClassViews.warrior = {
  build = function(host)
    local W = ns.Widgets
    local ep = CreateFrame("Frame", nil, host)
    ep:SetSize(EPIC_ICON, EPIC_ICON)
    ep:SetPoint("LEFT", host, "LEFT", 2, 0)
    ep:EnableMouse(true)
    ep.slot = W.slotOn(ep, EPIC_ICON)
    W.tooltip(ep, function(tt, f)
      if f.epicId then W.fillCardTooltip(tt, f.epicId, f.epicUp, { full = true }) end
    end, "ANCHOR_RIGHT")
    ep.text = W.label(host, "bold", 11, Art.C.goldText, "OVERLAY")
    ep.text:SetPoint("LEFT", ep, "RIGHT", 6, 0)
    ep:Hide()
    ep.text:Hide()
    host.epic = ep
  end,
  render = function(host, c)
    local W = ns.Widgets
    local ep = host.epic
    local id, up = ns.Warrior.epicOf(c)
    local line = id and Art.warriorEpicLine(c)
    if line then
      if ep.epicId ~= id then W.setIcon(ep.slot.icon, Art.cards[id], "card:" .. id) end
      ep.epicId, ep.epicUp = id, up
      ep.text:SetText(line)
      ep:Show()
      ep.text:Show()
    else
      ep.epicId = nil
      ep:Hide()
      ep.text:Hide()
    end
  end,
}
