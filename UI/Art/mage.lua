-- Art du Mage : icônes des cartes et des bibelots (noms de la fiche docs/classes/mage.md), voies, écoles,
-- classe, ressource (Charges), état Ice Block, icône du DoT de feu, et vue de classe
-- (ns.ClassViews.mage : deuxième incantation en cours, compte Fire du tour sous Hot Streak).
-- Champ `tga` = icône améliorée de Media/Icons (tools/build_media.py --icons-only la copie depuis
-- ~/Téléchargements/ICONS) ; `spell` = repli par l'icône du sort ; `icon` = repli par chemin du client.
local _, ns = ...

local Art = ns.Art
local hex = Art.hex

local function I(tga, spell)
  return { tga = tga, spell = spell, icon = "Interface\\Icons\\" .. tga:lower() }
end

local cards = {
  fireball          = I("Spell_Fire_FlameBolt", 133),
  frostbolt         = I("Spell_Frost_FrostBolt02", 116),
  mana_shield       = I("Spell_Shadow_DetectLesserInvisibility", 1463),
  arcane_blast      = I("Spell_Arcane_Blast", 30451),
  fire_blast        = I("Spell_Fire_Fireball", 2136),
  scorch            = I("Spell_Fire_SoulBurn", 2948),
  flamestrike       = I("Spell_Fire_SelfDestruct", 2120),
  blazing_barrier   = I("ABILITY_MAGE_MOLTENARMOR", 235313),
  pyroblast         = I("Spell_Fire_Fireball02", 11366),
  hot_streak        = I("Ability_Mage_HotStreak", 195283),
  living_bomb       = I("Ability_Mage_LivingBomb", 44457),
  phoenix_flames    = I("artifactability_FireMage_PhoenixBolt", 257541),
  ignite            = I("SPELL_FIRE_INCINERATE", 12846),
  combustion        = I("Spell_Fire_SealOfFire", 190319),
  ice_lance         = I("Spell_Frost_FrostBlast", 30455),
  frost_nova        = I("Spell_Frost_FrostNova", 122),
  ice_barrier       = I("Spell_Ice_Lament", 11426),
  cone_of_cold      = I("Spell_Frost_Glacier", 120),
  flurry            = I("Ability_warlock_burningembersblue", 44614),
  blizzard          = I("Spell_Frost_IceStorm", 10),
  glacial_spike     = I("Spell_Frost_Frostbolt", 199786),
  ice_block         = I("Spell_Frost_Frost", 45438),
  deep_freeze       = I("Ability_Mage_DeepFreeze", 44572),
  shatter           = I("Spell_Frost_WizardMark", 12982),
  arcane_missiles   = I("Spell_Nature_StarFall", 5143),
  arcane_explosion  = I("Spell_Nature_WispSplode", 1449),
  prismatic_barrier = I("Spell_MageArmor", 235450),
  arcane_barrage    = I("Ability_Mage_ArcaneBarrage", 44425),
  counterspell      = I("Spell_Frost_IceShock", 2139),
  evocation         = I("Spell_Nature_Purge", 12051),
  polymorph         = I("Spell_Nature_Polymorph", 118),
  presence_of_mind  = I("Spell_Nature_EnchantArmor", 205025),
  arcane_power      = I("Spell_Nature_Lightning", 12042),
  arcane_surge      = I("Ability_Mage_ArcaneSurge", 365350),
}
for id, e in pairs(cards) do Art.cards[id] = e end

-- Corps des cartes : règle commune (départ en or, premier effet d'Absorb en bleu, le reste en ivoire).

Art.paths.fire   = { name = "Fire",   ring = hex("#e2863b"), ink = hex("#8a3a12") }
Art.paths.frost  = { name = "Frost",  ring = hex("#6fb7e8"), ink = hex("#24577f") }
Art.paths.arcane = { name = "Arcane", ring = hex("#b77be6"), ink = hex("#5a2a82") }

Art.schoolName.fire, Art.schoolName.frost, Art.schoolName.arcane = "Fire", "Frost", "Arcane"
Art.schools.fire   = I("Spell_Fire_FlameBolt")
Art.schools.frost  = I("Spell_Frost_FrostBolt02")
Art.schools.arcane = I("Spell_Arcane_Blast")

Art.relics.apprentice_wand        = I("INV_Wand_01")
Art.relics.tome_arcane_brilliance = I("INV_Misc_Book_09")
Art.relics.robe_archmage          = I("INV_Chest_Cloth_25")
Art.relics.glacial_cloak          = I("INV_Misc_Cape_18")
Art.relics.fire_ruby              = I("INV_Misc_Gem_Ruby_02")
Art.relics.mind_quickening_gem    = I("INV_Misc_Gem_Sapphire_01")

-- DoT de feu (Fireball, Flamestrike, Living Bomb, Ignite : apply … icon = "burn").
Art.statusIcons = Art.statusIcons or {}
Art.statusIcons.burn = I("Spell_Fire_Immolation")

-- État Ice Block (Core/Classes/mage.lua) : jeton et définition courte.
Art.statuses.ice_block = I("Spell_Frost_Frost")
Art.statusShort.ice_block = "takes no damage from attacks until the next turn."

Art.classes.mage = I("ClassIcon_Mage")
Art.classes.mage.wow = "MAGE"
Art.classes.mage.resource = { tga = "Spell_Arcane_Arcane01", icon = "Interface\\Icons\\spell_arcane_arcane01",
  color = "watchText" }

-- Vue de classe (zone libre sous les états du héros, 300 × 40) : la deuxième incantation en cours (la
-- barre commune ne montre que la première), celle qu'une interruption couperait d'abord ; à droite, le
-- compte des cartes Fire du tour quand Hot Streak est en jeu (« Fire 1/2 »). Ne lit que le combat.
local function hotStreakInPlay(c)
  local powers = c.player.powers
  for i = 1, #powers do if powers[i].id == "hot_streak" then return true end end
  return false
end

ns.ClassViews.mage = {
  build = function(host)
    local W, C = ns.Widgets, Art.C
    local box = CreateFrame("Frame", nil, host)
    box:SetSize(26, 26)
    box:SetPoint("LEFT", host, "LEFT", 0, 0)
    box:EnableMouse(true)
    box.slot = W.slotOn(box, 26)
    W.tooltip(box, function(tt)
      local c = ns.Controller.combat()
      local more = c and c.player.castMore
      local e = more and more[#more]
      if not e then return end
      W.fillCardTooltip(tt, e.card.id, e.card.up, { full = true })
      tt:AddLine("An interrupt cancels this cast first.", 1, 0.5, 0.4, true)
    end, "ANCHOR_TOP")
    host.box = box
    host.name = W.label(host, "bold", 12.5, C.text)
    host.name:SetPoint("LEFT", host, "LEFT", 32, 0)
    host.name:SetWidth(190)
    host.name:SetJustifyH("LEFT")
    host.name:SetWordWrap(false)
    host.fire = W.label(host, "bold", 12.5, C.goldText)
    host.fire:SetPoint("RIGHT", host, "RIGHT", -4, 0)
    host.fire:SetJustifyH("RIGHT")
  end,
  render = function(host, c)
    local W = ns.Widgets
    local more = c.player.castMore
    local e = more and more[#more]
    if e then
      W.setIcon(host.box.slot.icon, W.cardArt(e.card.id), "card:" .. e.card.id)
      host.name:SetText("2nd cast: " .. ns.Card.def(e.card).name)
      host.box:Show()
      host.name:Show()
    else
      host.box:Hide()
      host.name:Hide()
    end
    if hotStreakInPlay(c) then
      host.fire:SetText("Fire " .. math.min(c.turn.bySchool.fire or 0, 2) .. "/2")
      host.fire:Show()
    else
      host.fire:Hide()
    end
  end,
}
