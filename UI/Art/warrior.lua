-- Art du Guerrier : icônes des cartes et des bibelots, voies, classe et ressource (Rage).
-- Champ `tga` = icône améliorée de Media/Icons (tools/build_media.py --icons-only la copie depuis
-- le pack d'icônes local) ; `spell` = repli par l'icône du sort ; `icon` = repli par chemin du client.
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

-- Vue de classe : rien d'écrit sur la scène ; la note de l'épique va sur son jeton des états du héros
-- (W.noteToken) : ligne actuelle dans l'infobulle, compteur sur l'icône, icône atténuée si la règle est
-- inactive :
--   Death Wish         « Attacks +50%, no Absorb »
--   Thunderous Roar    « Roar in 3 Rage: 3 to all »                     compteur 3 (Rage qui manque)
--   Sweeping Strikes   « Targeted hits splash 2 others for half »     compteur 1 ; atténuée seul
--   Titan's Grip       « Attacks this turn: 0/2, each twice »           compteur 0/2
--   Shield Charge      « End of turn: 7 to Defias Thug »                compteur 7 ; atténuée sans Absorb
--   Anger Management   « Each Rage spent: Cooldowns −1 »                atténuée sans recharge
--   Avatar             « Rage up to 10, +2 next turn » ; à 10 Rage « Rage 10: Attacks +1, +2 next turn » (+1)
-- Renvoie ligne, compteur, inactive (nil : rien à dire). Ne lit que le combat ; lu aussi par le harnais.
local function n(v) return "|cffffffff" .. tostring(v) .. "|r" end

function Art.warriorEpicLine(c, want)
  local Wr = ns.Warrior
  if not Wr then return nil end
  local id, up = Wr.epicOf(c, want)
  if not id then return nil end
  local E = Wr.EPIC
  if id == "death_wish" then
    return ("Attacks %s, no Absorb"):format(n("+" .. math.floor((Wr.num("death_wish", "mult", up) - 1) * 100 + 0.5) .. "%"))
  elseif id == "thunderous_roar" then
    local T = E.thunderous_roar
    local left = math.max(1, T.at - (c.player.res or 0))
    return ("Roar in %s Rage: %s to all"):format(n(left), n(Wr.num("thunderous_roar", "damage", up))), tostring(left)
  elseif id == "sweeping_strikes" then
    local alive = #ns.Combat.aliveEnemies(c)
    if alive < 2 then return nil, nil, true end
    local k = math.min(alive - 1, Wr.num("sweeping_strikes", "targets", up))
    return ("Targeted hits splash %s other%s for half"):format(n(k), k > 1 and "s" or ""), tostring(k)
  elseif id == "titans_grip" then
    local lim = E.titans_grip.limit
    local done = math.min(c.cls.tgAttacks or 0, lim)
    return ("Attacks this turn: %s/%d, each twice"):format(n(done), lim), done .. "/" .. lim
  elseif id == "shield_charge" then
    local dmg = Wr.chargeDamage(c, up)
    local t = dmg > 0 and Wr.chargeTarget(c)
    if not t then return nil, nil, true end
    local d = ns.Enemies[t.id]
    local hit = ns.Combat.calcDamage(c, c.player, t, dmg)
    return ("End of turn: %s to %s"):format(n(hit), d and d.name or "the target"), tostring(hit)
  elseif id == "anger_management" then
    if #c.cooldown == 0 then return nil, nil, true end
    local A = E.anger_management
    local per = A.per
    local steps = Wr.num("anger_management", "steps", up)
    if per > 1 then
      local spent = c.cls.amSpent or 0
      return ("Rage spent: %s/%d, then Cooldowns −%d"):format(n(spent), per, steps), spent .. "/" .. per
    end
    return ("Each Rage spent: Cooldowns %s"):format(n("−" .. steps))
  elseif id == "avatar" then
    local gain = n("+" .. Wr.num("avatar", "gain", up))
    local bonus = Wr.avatarBonus(c)
    if bonus > 0 then
      return ("Rage %s: Attacks %s, %s next turn"):format(n(c.player.res), n("+" .. bonus), gain), "+" .. bonus
    end
    -- plafond du combat (Avatar, talent Unbridled Wrath : Combat.resCap)
    return ("Rage up to %s, %s next turn"):format(n(ns.Combat.resCap(c) or E.avatar.cap), gain)
  end
  return nil
end

ns.ClassViews.warrior = {
  tokens = function(c, list)
    ns.Widgets.noteEpics(c, list, Art.warriorEpicLine)
  end,
}
