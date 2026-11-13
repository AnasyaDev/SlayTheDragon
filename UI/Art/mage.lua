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
  -- épiques (une par zone)
  mirror_image      = I("Spell_Magic_LesserInvisibilty", 55342),
  molten_armor      = I("Spell_Fire_FireArmor", 30482),
  water_elemental   = I("Spell_Frost_SummonWaterElemental_2", 31687),
  fingers_of_frost  = I("Ability_Mage_WintersGrasp", 44543),
  arcane_meditation = I("Spell_Shadow_ManaBurn", 18462),
  conflagration     = I("Ability_Mage_WorldInFlames", 205023),
  rule_of_threes    = I("Spell_Arcane_ArcanePotency", 264354),
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
    -- ce que l'épique change pendant le tour (mana gardé, rang de la carte, cible de l'élémentaire…)
    host.epic = W.label(host, "bold", 12.5, Art.hex("#d9a6ff"))
    host.epic:SetPoint("RIGHT", host, "RIGHT", -4, 0)
    host.epic:SetJustifyH("RIGHT")
    -- icône de l'épique à gauche de sa ligne (infobulle = la carte)
    local eb = CreateFrame("Frame", nil, host)
    eb:SetSize(18, 18)
    eb:SetPoint("RIGHT", host.epic, "LEFT", -5, 0)
    eb:EnableMouse(true)
    eb.slot = W.slotOn(eb, 18)
    W.tooltip(eb, function(tt, f)
      if f.epicId then W.fillCardTooltip(tt, f.epicId, f.epicUp, { full = true }) end
    end, "ANCHOR_TOP")
    eb:Hide()
    host.epicBox = eb
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
    local hot = hotStreakInPlay(c)
    if hot then
      host.fire:SetText("Fire " .. math.min(c.turn.bySchool.fire or 0, 2) .. "/2")
      host.fire:Show()
    else
      host.fire:Hide()
    end
    -- ligne de l'épique : seule au milieu, ou sous la deuxième incantation et le compte Fire (deux lignes)
    local text = Art.mageEpicText(c)
    local two = text ~= nil and (hot or e ~= nil)
    host.fire:ClearAllPoints()
    host.fire:SetPoint("RIGHT", host, "RIGHT", -4, two and 9 or 0)
    host.name:ClearAllPoints()
    host.name:SetPoint("LEFT", host, "LEFT", 32, two and 9 or 0)
    host.epic:ClearAllPoints()
    host.epic:SetPoint("RIGHT", host, "RIGHT", -4, two and -11 or 0)
    local eb = host.epicBox
    if text then
      host.epic:SetText(text)
      host.epic:Show()
      local id, src = ns.Combat.mageEpic(c)
      if eb.epicId ~= id then W.setIcon(eb.slot.icon, Art.cards[id], "card:" .. id) end
      eb.epicId, eb.epicUp = id, src.up
      eb:Show()
    else
      host.epic:Hide()
      eb.epicId = nil
      eb:Hide()
    end
  end,
  -- épiques : le nom de l'épique s'élève au-dessus de l'unité qu'elle touche (coup de l'élémentaire, image
  -- miroir, feu transmis) ou du héros (Cast parti tout de suite, carte résolue deux fois)
  event = function(host, ev, view)
    if ev.t ~= "epic" then return end
    local d = ns.Cards[ev.id]
    if not d then return end
    local ref = ev.dst or ev.src or "player"
    view:Push(0.15, function()
      local x, y = view:UnitPos(ref)
      if not x then x, y = view:UnitPos("player") end
      if x then ns.Widgets.float(view.parent, x, y - 95, d.name, Art.hex("#d9a6ff"), 15, 1.1, 22) end
    end)
  end,
}

-- Texte de la vue du Mage pour son épique (nil : rien à montrer). Ne lit que le combat.
function Art.mageEpicText(c)
  if not ns.Combat.mageEpic then return nil end
  local id, src = ns.Combat.mageEpic(c)
  if not id then return nil end
  local d = ns.Card.def(src)
  if id == "arcane_meditation" then
    return ("Mana kept: %d/%d"):format(math.min(math.max(c.player.mana or 0, 0), d.epicN), d.epicN)
  elseif id == "rule_of_threes" then
    if not ns.Combat.epicTurn(src, c.round) then return "Threes: next turn" end
    if ns.Combat.ruleOfThreesNext(c, src) then return "Next Attack: twice" end
    local n = c.turn.played
    if d.epicEvery then n = n % 3 end
    if not d.epicEvery and n >= 3 then return nil end
    return ("Cards played: %d/3"):format(n)
  elseif id == "water_elemental" then
    -- le coup part au début du prochain tour : la vue dit s'il part et sur qui
    if not ns.Combat.epicTurn(src, c.round + 1) then return "Elemental rests next turn" end
    local t = ns.Combat.elementalTarget(c)
    return t and ("Elemental: " .. ns.Enemies[t.id].name) or nil
  elseif id == "fingers_of_frost" then
    for i = 1, #c.enemies do
      if ns.Combat.isFrozen(c.enemies[i]) then return "Frozen: Cast at once" end
    end
    return "No Frozen enemy"
  elseif id == "mirror_image" then
    return "Cast cards hit twice"
  elseif id == "molten_armor" then
    return ("When hit: DoT %d"):format(d.epicN)
  elseif id == "conflagration" then
    local n = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead and (e.st.pain or 0) > 0 then n = n + 1 end
    end
    return n > 0 and ("DoT spreads on death: %d"):format(n) or "No enemy with DoT"
  end
  return nil
end
