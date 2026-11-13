-- Art de la zone Duskwood (`duskwood`) : modèles des ennemis et des personnages, icônes des Curses, des
-- cartes, bibelots et états, intention « Curse », case WANTED, décors peints (forêt noire, cimetière, lune) et
-- vue de zone ns.ZoneViews.duskwood (UI/ZoneView.lua). Guide : docs/zones.md ; fiche : docs/zones/duskwood.md.
-- Identifiants de créatures et d'affichages : cache de créatures du client Forever (tools/wdb_creatures.py,
-- lecture seule, 13/11/2026) ; « repli » = affichage voisin de la même famille quand la créature manque.
local _, ns = ...

local Art = ns.Art
local hex = Art.hex
local Card = ns.Card

-- Icône embarquée (Media/Icons, tools/build_media.py --icons-only) avec repli par chemin du client.
local function I(tga)
  return { tga = tga, icon = "Interface\\Icons\\" .. tga:lower() }
end

---------------------------------------------------------------------------
-- Ennemis, élites, boss
---------------------------------------------------------------------------
local WOLF, SPIDER, UNDEAD = I("Ability_Hunter_Pet_Wolf"), I("Ability_Hunter_Pet_Spider"), I("INV_Misc_Head_Undead_01")
local enemies = {
  dark_runner     = { creature = 205, display = 736, icon = WOLF },                       -- Nightbane Dark Runner
  vile_fang       = { creature = 206, display = 522, icon = WOLF },                       -- Nightbane Vile Fang
  shadow_weaver   = { creature = 533, display = 203, icon = I("Spell_Shadow_ShadowBolt") }, -- Nightbane Shadow Weaver
  plague_spreader = { creature = 604, display = 519, icon = I("Spell_Shadow_PlagueCloud") },
  venom_spider    = { creature = 217, display = 955, icon = SPIDER },                     -- Venom Web Spider
  pygmy_spider    = { creature = 539, display = 958, icon = SPIDER },                     -- Pygmy Venom Web Spider
  pygmy_brood     = { creature = 539, display = 958, icon = SPIDER },                     -- petits de Naraxis
  rotted_one      = { creature = 948, display = 137, icon = UNDEAD },
  splinter_fist   = { creature = 212, display = 610, icon = I("INV_Misc_MonsterHead_02") }, -- Splinter Fist Warrior
  night_runner    = { creature = 215, display = { 4276, 4278 }, icon = I("Ability_Rogue_Ambush") },
  stitches        = { creature = 412, display = 1693, scale = 1.25, icon = I("INV_Misc_Head_Undead_02") },
  -- Naraxis : absente des caches ; repli : Venom Web Spider (217, affichage 955) agrandie, puis Giant Webwood
  -- Spider (2001, affichage 6808)
  naraxis         = { creature = 217, display = { 955, 6808 }, scale = 1.4, icon = I("INV_Misc_MonsterSpiderCarapace_01") },
  morladim        = { creature = 522, display = 612, scale = 1.15, icon = I("INV_Misc_Bone_HumanSkull_02") },
  morbent_fel     = { creature = 1200, display = 4272, scale = 1.15, icon = I("Spell_Shadow_RaiseDead") },
  fetid_corpse    = { creature = 1270, display = 559, icon = UNDEAD },
}
for id, e in pairs(enemies) do Art.enemies[id] = e end

---------------------------------------------------------------------------
-- Personnages des rencontres
---------------------------------------------------------------------------
-- Personnage lui-même, puis deux affichages de gens de Darkshire du même cache (repli d'apparence).
local npcs = {
  -- Tavernkeep Smitts (273) ; Councilman Millstipe (270), Role Dreuger (269)
  tavernkeep_smitts = { creature = 273, display = { 1731, 1724, 4309 }, icon = I("INV_Drink_08") },
  -- Commander Althea Ebonlocke (264) ; Sirra Von'Indi (268), Madame Eva (265)
  althea_ebonlocke  = { creature = 264, display = { 4322, 4324, 4323 }, icon = I("INV_Misc_Lantern_01") },
  -- Sven Yorgen (311) ; Role Dreuger (269), Watcher Backus (840)
  sven_yorgen       = { creature = 311, display = { 4327, 4309, 2380 }, icon = I("INV_Misc_Head_Human_01") },
  -- Madame Eva (265) ; Sirra Von'Indi (268), Commander Althea Ebonlocke (264)
  madame_eva        = { creature = 265, display = { 4323, 4324, 4322 }, icon = I("INV_Misc_Orb_04") },
  -- Abercrombie (289) ; Jonathan Carevin (661), Councilman Millstipe (270)
  abercrombie       = { creature = 289, display = { 4328, 4338, 1724 }, icon = I("INV_Misc_Bone_02") },
  -- Viktori Prism'Antras (276) ; Lord Ello Ebonlocke (263), Ambassador Berrybuck (271)
  viktori           = { creature = 276, display = { 4326, 4321, 1713 }, icon = I("INV_Misc_Spyglass_02") },
  -- Jonathan Carevin (661) ; Scott Carevin (3138), Benjamin Carevin (664)
  jonathan_carevin  = { creature = 661, display = { 4338, 4339, 221 }, icon = I("INV_Misc_Bone_HumanSkull_01") },
  -- Watcher Dodds (888) ; Watcher Backus (840), Watcher Cutford (1436)
  watcher_dodds     = { creature = 888, display = { 2384, 2380, 2383 }, icon = I("INV_Misc_Web_01") },
  -- Watcher Backus <The Night Watch> (840), qui pose l'affiche WANTED ; Watcher Cutford (1436), Watcher Ladimore (576)
  watcher_backus    = { creature = 840, display = { 2380, 2383, 2375 }, icon = I("INV_Misc_Note_01") },
}
for id, e in pairs(npcs) do Art.npcs[id] = e end

---------------------------------------------------------------------------
-- Cartes, bibelots, états, intentions, case de parcours
---------------------------------------------------------------------------
-- Curses : corps violet assombri (cadre noir et violet de la fiche).
local CURSE_TINT = { 0.5, 0.36, 0.62 }
local function curse(tga) local e = I(tga) e.body, e.tint = "violet", CURSE_TINT return e end
local cards = {
  rabies            = curse("Ability_Creature_Disease_02"),
  curse_of_weakness = curse("Warlock_Curse_Weakness"),
  web               = curse("Spell_Nature_Web"),
  fevered_plague    = curse("Spell_Shadow_PlagueCloud"),
  curse_of_tongues  = curse("Spell_Shadow_CurseOfTounges"),
  morbents_bane     = I("INV_Misc_Powder_Purple"),
  anti_venom        = I("INV_Alchemy_90_AntiVenom"),
  zombie_juice      = I("INV_Drink_08"),
}
for id, e in pairs(cards) do Art.cards[id] = e end

local relics = {
  ogres_monocle          = I("INV_Misc_Spyglass_02"),
  night_watch_shortsword = I("INV_Sword_04"),
  mistmantle_family_ring = I("INV_Jewelry_Ring_03"),
  ghoul_rib              = I("INV_Misc_Bone_02"),
  morladims_skull        = I("INV_Misc_Bone_HumanSkull_01"),
  morbents_bane_relic    = I("INV_Misc_Powder_Purple"),
}
for id, e in pairs(relics) do Art.relics[id] = e end

local CURSE_ICON = I("Spell_Shadow_Curse")
Art.statuses.unholy_shield = I("Spell_Shadow_AntiMagicShell")
Art.statusShort.unholy_shield = "takes half damage. Morbent's Bane removes it."
Art.intents.curse = { tga = "Spell_Shadow_Curse", icon = "Interface\\Icons\\spell_shadow_curse", color = "watch" }
Art.intentName.curse = "Curse"
Art.ui.map.wanted_poster = I("INV_Misc_Note_01")

local PILE = { discard = "your discard", draw = "the top of your draw pile", hand = "your hand" }
local function curseName(id, n)
  local d = ns.Cards[id]
  return ((n or 1) > 1 and (n .. " × ") or "") .. (d and d.name or id)
end

-- Bulle d'intention d'un Hex : « +1 » (Curses posées) ; infobulle : la Curse et la pile visée.
Art.intentParts.curse = function(c, e, a) return "+" .. (a.n or 1) end
Art.actionText.curse = function(a)
  return "Curse: adds " .. curseName(a[2], a.n) .. " to " .. (PILE[a.to or "discard"] or PILE.discard) .. "."
end
Art.actionText.gorge = function(a, c, e)
  local n = c and e and ns.Duskwood.count(c, e.uid, "fevered_plague") or 0
  return "Gains Strength " .. (a[2] or 1) .. " per Fevered Plague of his in your cards (now " .. n .. ")."
end

---------------------------------------------------------------------------
-- Vue de zone : Bite sous l'intention, « Curse N » sous chaque lanceur, Curses de la main marquées,
-- pastilles violettes sur les piles, jeton « Curses N/6 »
---------------------------------------------------------------------------
local DW = ns.Duskwood

-- Action d'attaque à Bite (drapeau curse) de l'intention annoncée, ou nil.
local function biteOf(e)
  local mv = ns.Enemies[e.id].moves[e.intent]
  for _, a in ipairs(mv and mv.actions or {}) do
    if a[1] == "attack" and a.curse then return a end
  end
  return nil
end

local CURSE_RIM = { 0.78, 0.45, 1, 1 }

ns.ZoneViews.duskwood = {
  -- jeton en haut au centre : Curses en jeu sur le plafond (seulement s'il y en a)
  counter = function(c)
    local n = DW.count(c)
    if n == 0 then return nil end
    return { icon = CURSE_ICON, key = "dw:counter", text = "Curses " .. n .. "/" .. DW.CAP, hot = n >= DW.CAP,
      tip = "Curses in your cards: " .. n .. " of " .. DW.CAP .. ". Past " .. DW.CAP .. ", enemies can't add more."
        .. " Play a Curse to exhaust it, or kill the enemy that cast it." }
  end,
  -- Bite : petite icône de la Curse à droite du chiffre de l'attaque
  intentBadge = function(c, e)
    local a = biteOf(e)
    if not a then return nil end
    local d = ns.Cards[a.curse]
    return { icon = Art.cards[a.curse] or CURSE_ICON, key = "dw:bite:" .. a.curse,
      tip = "Bite: if this attack costs you HP, adds " .. (d and d.name or a.curse) .. " to your discard." }
  end,
  -- « Curse N » sous le lanceur : ses Curses encore en jeu (levées à sa mort)
  enemyBadges = function(c, e)
    local n = DW.count(c, e.uid)
    if n == 0 then return nil end
    local name = ns.Combat.enemyName(e)
    return { { icon = CURSE_ICON, key = "dw:caster", text = "Curse " .. n, color = "watchText",
      tip = n .. " Curse" .. (n > 1 and "s" or "") .. " from " .. name .. " in your cards. All of them are lifted when "
        .. name .. " dies." } }
  end,
  -- Curse en main : liseré violet ; infobulle : son lanceur
  handMark = function(c, i, inst)
    local d = Card.def(inst)
    if not d.curse then return nil end
    local e = inst.src and ns.Combat.enemyByUid(c, inst.src)
    local who = e and ns.Combat.enemyName(e) or "an enemy"
    return { rim = CURSE_RIM, icon = CURSE_ICON, key = "dw:hand",
      tip = "Curse from " .. who .. ". Lifted when " .. who .. " dies." }
  end,
  -- pastilles violettes sur les piles (nombre de Curses dans la pioche et la défausse)
  build = function(host, view)
    local W = ns.Widgets
    host.dwPiles = {}
    for _, key in ipairs({ "draw", "discard" }) do
      local pile = key == "draw" and view.drawPile or view.discardPile
      local b = CreateFrame("Frame", nil, host)
      b:SetSize(26, 26)
      b:SetFrameLevel((pile and pile:GetFrameLevel() or host:GetFrameLevel()) + 6)
      b:EnableMouse(false)
      b.disc = W.disc(b, "ARTWORK", 0, hex("#5a2a78"))
      b.disc:SetAllPoints()
      b.icon = b:CreateTexture(nil, "ARTWORK", nil, 1)
      b.icon:SetPoint("CENTER", 0, 0)
      b.icon:SetSize(16, 16)
      W.setIcon(b.icon, CURSE_ICON, "dw:pile")
      b.icon:SetAlpha(0.35)
      b.text = W.label(b, "heavy", 13, Art.C.watchText, "OVERLAY")
      b.text:SetPoint("CENTER", 0, 0.5)
      if pile then b:SetPoint("CENTER", pile, "TOPRIGHT", -4, -4) end
      b:Hide()
      host.dwPiles[key] = b
    end
  end,
  render = function(host, c, view)
    for key, b in pairs(host.dwPiles or {}) do
      local n = 0
      for _, inst in ipairs(c[key]) do if Card.def(inst).curse then n = n + 1 end end
      if n > 0 and not c.result then
        b.text:SetText(n)
        b:Show()
      else
        b:Hide()
      end
    end
  end,
}

---------------------------------------------------------------------------
-- Décors peints : forêt noire sous la lune, cimetière de Raven Hill, camp de Sven, Darkshire, Twilight
-- Grove, cimetière de Tranquil Gardens (boss)
---------------------------------------------------------------------------
-- Palettes : mêmes clés que celle de Westfall (UI/Art.lua), plus back (lisière du fond), rim (liseré de lune
-- des silhouettes), glow (lueur des lanternes), web (toiles). Tons bleu nuit et violet désaturé, ciel
-- plus clair à l'horizon (Duskwood : crépuscule permanent).
Art.palettes.duskwood = {
  night = true,
  sky = { "#121731", "#2a3157", "#605d7c" }, moon = "#ebe8da", moonGlow = { "#a9b4d8", 0.34 },
  stars = "#cfd6ea", cloud = { "#3a4264", 0.34 },
  hillsBack = "#252b45", hillsFront = "#1d2236", mound = "#1d2230", moundLight = { "#3c4763", 0.42 },
  trees = "#151a28", haze = { "#4d5574", 0.46 },
  patches = { "#262c33", "#20262c", "#2a2f33", "#1d2328", "#2c3134" }, hedge = { "#0b0d12", 0.4 },
  fieldsNear = { "#22272b", "#101215" }, furrowDark = { "#060709", 0.32 }, furrowLight = { "#4a5268", 0.1 },
  road = { "#4f4a45", "#2c2825" }, roadEdge = "#15130f",
  back = { main = "#262d45", dark = "#1d2338" },
  far = { main = "#1a1f2f", dark = "#121622", light = "#e8b860", rim = { "#6f7ea8", 0.2 } },
  mid = { main = "#0f1217", dark = "#08090c", wood = "#2a2522", crate = "#3a3129", light = "#ffcf7a",
    rim = { "#8c98c6", 0.24 } },
  flag = "#2c3c5e", smoke = { "#5b6377", 0.4 },
  ground = { "#030305", 0.62 }, stalk = "#0c0e10", ears = { "#15181b", "#111316", "#1a1d21" },
  glow = { "#ffb24a", 0.34 }, web = { "#b9c0d6", 0.42 },
}
-- Feu de camp : la même forêt, nuit noire étoilée.
Art.palettes.duskwood_night = {
  night = true,
  sky = { "#070a18", "#121a33", "#2c3350" }, moon = "#e4e2d4", moonGlow = { "#8c9cc8", 0.3 },
  stars = "#e6e8f2", cloud = { "#2a3150", 0.3 },
  hillsBack = "#161b2c", hillsFront = "#121624", mound = "#141824", moundLight = { "#2c3550", 0.4 },
  trees = "#0e111c", haze = { "#343c5a", 0.4 },
  patches = { "#181c22", "#151a1f", "#1b1f23", "#13171b", "#1c2024" }, hedge = { "#060709", 0.45 },
  fieldsNear = { "#171a1e", "#08090b" }, furrowDark = { "#030304", 0.32 }, furrowLight = { "#3a4058", 0.08 },
  road = { "#38352f", "#211e1b" }, roadEdge = "#0c0b09",
  back = { main = "#1a2033", dark = "#141a2a" },
  far = { main = "#111522", dark = "#0b0e18", light = "#f0c264", rim = { "#5c6a94", 0.18 } },
  mid = { main = "#0a0c10", dark = "#050608", wood = "#1e1b19", crate = "#2a2420", light = "#ffcf7a",
    rim = { "#76839f", 0.2 } },
  flag = "#1c2333", smoke = { "#4b5267", 0.4 },
  ground = { "#020203", 0.66 }, stalk = "#08090b", ears = { "#101215", "#0d0f11", "#131518" },
  glow = { "#ffb24a", 0.38 }, web = { "#9aa2ba", 0.38 },
}
-- Tranquil Gardens (boss) : brume violette, lueur verte du mausolée de Morbent Fel.
Art.palettes.duskwood_boss = {
  night = true,
  sky = { "#0f0a1f", "#2a1c42", "#5a4568" }, moon = "#dfe9d6", moonGlow = { "#9fc4a8", 0.3 },
  stars = "#d8e2d6", cloud = { "#3a2c56", 0.34 },
  hillsBack = "#231c38", hillsFront = "#1b1630", mound = "#1a1628", moundLight = { "#3b3258", 0.42 },
  trees = "#130f20", haze = { "#5a4a7a", 0.48 },
  patches = { "#241f2e", "#1f1b28", "#28222f", "#1c1925", "#2a2431" }, hedge = { "#09070e", 0.4 },
  fieldsNear = { "#1f1b26", "#0e0c12" }, furrowDark = { "#050408", 0.32 }, furrowLight = { "#4a4268", 0.1 },
  road = { "#463f4a", "#27222b" }, roadEdge = "#110e13",
  back = { main = "#2a2242", dark = "#201a34" },
  far = { main = "#1b1629", dark = "#120f1d", light = "#9cf0a8", rim = { "#7a8cb0", 0.2 } },
  mid = { main = "#0f0c15", dark = "#07060a", wood = "#241f22", crate = "#33292c", light = "#9cf0a8",
    rim = { "#8f9cc8", 0.24 } },
  flag = "#2c2440", smoke = { "#5b5377", 0.4 },
  ground = { "#030205", 0.64 }, stalk = "#0b090e", ears = { "#141118", "#100e14", "#18151c" },
  glow = { "#7cf09a", 0.3 }, web = { "#b9c0d6", 0.42 },
}

local DW_SKY = { clouds = { { 170, 58, 300, 30 }, { 520, 34, 240, 22 }, { 900, 108, 280, 26 } },
  hills = { back = { { 120, 560, 30 }, { 560, 620, 22 }, { 960, 520, 34 } }, front = { { 320, 420, 14 }, { 780, 520, 12 } } },
  trees = {} }
local function dusk(t, pal)
  t.pal, t.horizon, t.field = pal or "duskwood", t.horizon or 196, t.field or 232
  t.clouds, t.hills, t.trees = t.clouds or DW_SKY.clouds, t.hills or DW_SKY.hills, t.trees or DW_SKY.trees
  t.furrows = false
  t.shadows = t.shadows or { { 250, 300, 600, 70 }, { 860, 262, 460, 40 }, { 520, 372, 700, 60 } }
  return t
end

-- Forêt sur la route de Raven Hill : lisières sombres des deux côtés, arbres morts, réverbère, brume.
local ROAD_PROPS = {
  { "treeline", -10, 198, 1.1, "back", 1044 },
  { "treeline", -20, 214, 1.7, "far", 330 }, { "treeline", 700, 214, 1.8, "far", 1060 },
  { "deadtree", 412, 214, 0.55, "far" }, { "deadtree", 648, 210, 0.5, "far" },
  { "mist", 60, 240, 1.0, "mid", 980 },
  { "oak", 46, 310, 1.55, "mid" }, { "oak", 990, 306, 1.6, "mid" },
  { "deadtree", 196, 292, 1.25, "mid" }, { "deadtree", 846, 284, 1.05, "mid" },
  { "lamppost", 676, 268, 0.85, "mid" }, { "fence", 730, 290, 880, 278, "mid" },
}
local ROAD = { 517, 470, 7, 330, 46 }
local GRASS = { { -6, 104, 18 }, { 936, 1040, 18 } }

Art.paintings = Art.paintings or {}
local P = Art.paintings
P.duskwood_road = dusk({ moon = { 806, 72, 21 }, road = ROAD, props = ROAD_PROPS, wheat = GRASS })
P.duskwood_night = dusk({ moon = { 806, 66, 17 }, road = ROAD, props = ROAD_PROPS, wheat = GRASS }, "duskwood_night")

-- Raven Hill Cemetery : la colline, son mausolée, croix et pierres tombales, grille rouillée.
P.duskwood_graveyard = dusk({ moon = { 214, 66, 22 }, mound = { 590, 150, 720 },
  road = { 590, 500, 5, 260, -30 },
  props = {
    { "treeline", -10, 198, 1.0, "back", 1044 },
    { "crypt", 590, 154, 0.8, "far" },
    { "deadtree", 452, 176, 0.62, "far" }, { "deadtree", 742, 186, 0.58, "far" },
    { "tombstone", 400, 204, 0.62, "far" }, { "tombstone", 470, 196, 0.6, "far", "cross" },
    { "tombstone", 520, 182, 0.55, "far" }, { "tombstone", 668, 184, 0.55, "far", "cross" },
    { "tombstone", 712, 200, 0.6, "far" }, { "tombstone", 790, 212, 0.62, "far", "cross" },
    { "tombstone", 350, 222, 0.7, "far" }, { "tombstone", 838, 226, 0.7, "far" },
    { "mist", 140, 246, 1.0, "mid", 1000 },
    { "deadtree", 70, 300, 1.45, "mid" }, { "deadtree", 978, 296, 1.35, "mid" },
    { "tombstone", 190, 302, 1.15, "mid", "cross" }, { "tombstone", 262, 290, 1.0, "mid" },
    { "tombstone", 790, 296, 1.1, "mid" }, { "tombstone", 870, 306, 1.2, "mid", "cross" },
    { "fence", -6, 288, 300, 298, "mid" }, { "fence", 752, 300, 1040, 288, "mid" },
  },
  wheat = GRASS })

-- Camp de Sven Yorgen : clairière, tente, feu, charrette, lisière tout autour.
P.duskwood_camp = dusk({ moon = { 880, 70, 18 },
  props = {
    { "treeline", -10, 198, 1.1, "back", 1044 },
    { "treeline", -20, 214, 1.6, "far", 420 }, { "treeline", 640, 214, 1.7, "far", 1060 },
    { "deadtree", 520, 210, 0.55, "far" },
    { "oak", 60, 306, 1.5, "mid" }, { "oak", 980, 304, 1.55, "mid" },
    { "tent", 312, 290, 1.3, "mid" }, { "tent", 196, 274, 0.9, "mid" },
    { "smoke", 430, 292, 1.0, "mid" }, { "cart", 770, 296, 1.1, "mid" },
    { "deadtree", 870, 280, 0.95, "mid" },
  },
  wheat = GRASS })

-- Darkshire : maisons aux fenêtres éclairées, tour de la Night Watch, réverbères, charrette du marchand.
P.duskwood_shop = dusk({ moon = { 150, 64, 20 }, road = { 470, 610, 8, 290, 30 },
  props = {
    { "treeline", -10, 198, 1.1, "back", 1044 },
    { "tower", 760, 232, 0.9, "far" },
    { "farmhouse", 300, 232, 1.0, "far" }, { "shed", 382, 232, 0.8, "far" },
    { "farmhouse", 600, 232, 0.85, "far" }, { "shed", 900, 232, 0.8, "far" },
    { "farmhouse", 120, 232, 0.75, "far" },
    { "lamppost", 230, 290, 1.1, "mid" }, { "lamppost", 676, 282, 1.0, "mid" },
    { "cart", 790, 304, 1.25, "mid", "crates" },
    { "oak", 40, 306, 1.4, "mid" }, { "fence", 880, 296, 1040, 286, "mid" },
  },
  wheat = GRASS })

-- Twilight Grove : forêt dense sans route, toiles entre les branches, brume.
P.duskwood_woods = dusk({ moon = { 520, 52, 16 },
  props = {
    { "treeline", -10, 200, 1.2, "back", 1044 },
    { "treeline", -20, 218, 1.9, "far", 1060 },
    { "deadtree", 300, 218, 0.7, "far" }, { "deadtree", 720, 214, 0.75, "far" },
    { "mist", 80, 250, 1.1, "mid", 980 },
    { "oak", 40, 312, 1.7, "mid" }, { "oak", 1000, 308, 1.7, "mid" },
    { "deadtree", 182, 296, 1.35, "mid" }, { "deadtree", 860, 292, 1.3, "mid" },
    { "deadtree", 560, 268, 0.9, "mid" },
    { "web", 230, 200, 1.1, "mid" }, { "web", 818, 196, 1.0, "mid" }, { "web", 560, 176, 0.7, "mid" },
  },
  wheat = GRASS })

-- Tranquil Gardens Cemetery (boss) : mausolée éclairé de vert, tombes, arbres morts, brume violette.
P.duskwood_boss = dusk({ moon = { 830, 60, 20 }, mound = { 520, 170, 640 },
  props = {
    { "treeline", -10, 200, 1.1, "back", 1044 },
    { "crypt", 520, 186, 1.0, "far", "lit" },
    { "tombstone", 370, 214, 0.65, "far", "cross" }, { "tombstone", 420, 204, 0.6, "far" },
    { "tombstone", 640, 202, 0.6, "far" }, { "tombstone", 700, 214, 0.66, "far", "cross" },
    { "deadtree", 300, 214, 0.7, "far" }, { "deadtree", 760, 210, 0.65, "far" },
    { "mist", 40, 250, 1.2, "mid", 1000 },
    { "deadtree", 64, 300, 1.5, "mid" }, { "deadtree", 980, 296, 1.45, "mid" },
    { "tombstone", 180, 300, 1.2, "mid" }, { "tombstone", 250, 290, 1.0, "mid", "cross" },
    { "tombstone", 830, 302, 1.15, "mid", "cross" }, { "tombstone", 900, 290, 1.0, "mid" },
    { "fence", -6, 292, 280, 300, "mid" }, { "fence", 760, 300, 1040, 290, "mid" },
  },
  wheat = GRASS }, "duskwood_boss")

for _, key in ipairs({ "road", "night", "graveyard", "camp", "shop", "woods", "boss" }) do
  Art.scenes["duskwood_" .. key] = { paint = "duskwood_" .. key }
end
