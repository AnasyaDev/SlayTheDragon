-- Art de la zone Wetlands (`wetlands`) : modèles des ennemis (Art.enemies), personnages des rencontres
-- (Art.npcs), icônes des cartes, bibelots, états (Art.cards, Art.relics, Art.statuses, Art.statusShort), case
-- du Gryphon Master (Art.ui.map), décors peints (Art.scenes, Art.paintings, Art.palettes) et vue de zone
-- ns.ZoneViews.wetlands (UI/ZoneView.lua) : primes de meute sous chaque ennemi, Charge de Modr, limon.
-- Guide : docs/zones.md. Champ `tga` = icône améliorée de Media/Icons (tools/build_media.py --icons-only la
-- copie depuis ~/Téléchargements/ICONS) ; `icon` = repli par chemin du client.
--
-- Modèles : identifiants lus dans le cache de créatures du client Forever (tools/wdb_creatures.py, 13/11/2026) :
-- la créature, puis son affichage, puis des affichages de la même famille (repli). Sarltooth et Ormer
-- Ironbraid sont absents des caches : affichages voisins seulement (notés « repli »).
local _, ns = ...

local Art = ns.Art

local function I(tga)
  return { tga = tga, icon = "Interface\\Icons\\" .. tga:lower() }
end

local MURLOC, GNOLL, RAPTOR = I("INV_Misc_Head_Murloc_01"), I("INV_Misc_Head_Gnoll_01"), I("Ability_Hunter_Pet_Raptor")
local ORC, CROC = I("INV_Misc_Head_Orc_01"), I("Ability_Hunter_Pet_Crocolisk")

---------------------------------------------------------------------------
-- Ennemis
---------------------------------------------------------------------------

local enemies = {
  -- Bluegill Raider (1418) ; Bluegill Murloc (1024), Bluegill Puddlejumper (1025)
  bluegill_raider = { creature = 1418, display = { 391, 486, 983 }, icon = MURLOC },
  -- Mosshide Brute (1012) ; Mosshide Gnoll (1007), Mosshide Mistweaver (1009)
  mosshide_brute = { creature = 1012, display = { 3196, 3199, 3197 }, icon = GNOLL },
  -- Mosshide Mystic (1013) ; Mosshide Mistweaver (1009)
  mosshide_mystic = { creature = 1013, display = { 714, 3197 }, icon = GNOLL },
  -- Mosshide Alpha (1014) ; Mosshide Brute (1012)
  mosshide_alpha = { creature = 1014, display = { 543, 3196 }, scale = 1.1, icon = GNOLL },
  -- Mottled Screecher (1021) ; Mottled Raptor (1020)
  mottled_screecher = { creature = 1021, display = { 677, 960 }, icon = RAPTOR },
  mottled_raptor = { creature = 1020, display = { 960, 677 }, icon = RAPTOR },
  -- Mottled Scytheclaw (1022)
  mottled_scytheclaw = { creature = 1022, display = { 648, 960 }, icon = RAPTOR },
  -- Sarltooth (absent des caches) : repli Mottled Scytheclaw (1022) agrandi, puis Mottled Raptor (1020)
  sarltooth = { creature = 1022, display = { 648, 960 }, scale = 1.3, icon = RAPTOR },
  -- Dragonmaw Raider (1034) ; Dragonmaw Swamprunner (1035)
  dragonmaw_raider = { creature = 1034, display = { 4916, 4917 }, icon = ORC },
  -- Dragonmaw Centurion (1036 : l'armure de Ma'ruk Wyrmscale, décisions du 13/11/2026) ; Raider (1034)
  dragonmaw_centurion = { creature = 1036, display = { 4919, 4916 }, scale = 1.15,
    icon = I("INV_Misc_MonsterScales_08") },
  -- Wetlands Crocolisk (1400) ; Young (1417), Giant Wetlands Crocolisk (2089)
  wetlands_crocolisk = { creature = 1400, display = { 1036, 1035, 925 }, icon = CROC },
  -- Black Ooze (1032) ; Crimson Ooze (1031), Monstrous Ooze (1033)
  black_ooze = { creature = 1032, display = { 767, 11138, 11139 }, icon = I("INV_Misc_Food_Legion_gooSlime_chunk") },
  -- Black Slime (1030)
  black_slime = { creature = 1030, display = { 360, 767 }, icon = I("INV_Misc_Food_Legion_gooSlime_chunk") },
  -- Modr (271460, golem de Dun Modr, contenu Forever, échelle 2 dans le cache) ; repli : Fen Creeper (1040)
  modr = { creature = 271460, display = { 473, 2023 }, scale = 1.3, icon = I("Spell_Nature_Earthquake") },
  -- Chieftain Nek'rosh (2091) ; Dragonmaw Shadowwarder (1038)
  nekrosh = { creature = 2091, display = { 4915, 4924 }, scale = 1.15, icon = ORC },
  -- Dragonmaw Bonewarder (1057) ; Dragonmaw Shadowwarder (1038)
  dragonmaw_bonewarder = { creature = 1057, display = { 4918, 4924 }, icon = I("Spell_Shadow_ShadowBolt") },
  -- Crimson Whelp (1069) ; Red Whelp (1042), Flamesnorting Whelp (1044)
  crimson_whelp = { creature = 1069, display = { 505, 9583, 8712 }, icon = I("INV_Misc_Head_Dragon_Red") },
}
for id, e in pairs(enemies) do Art.enemies[id] = e end

---------------------------------------------------------------------------
-- Personnages des rencontres
---------------------------------------------------------------------------

local npcs = {
  -- James Halloran (2094, Menethil Harbor) ; repli : Donald Rabonne <Fisherman> (2367), Jarel Moor (1305)
  james_halloran = { creature = 2094, display = { 1408, 3693, 1490 }, icon = I("INV_Misc_LeatherScrap_02") },
  -- Ormer Ironbraid (absent des caches) : repli Longbraid the Grim (1071, nain des Wetlands), Prospector
  -- Stormpike (1356), Archaeologist Flagongut (2911)
  ormer_ironbraid = { creature = 1071, display = { 1671, 3594, 1650 }, icon = I("INV_Misc_StoneTablet_05") },
  -- Rethiel the Greenwarden (1244) ; repli : Alfina Noctemire (270459), Sentinel Kyra Starsong (2081)
  rethiel = { creature = 1244, display = { 480, 2191, 1682 }, icon = I("INV_Stone_04") },
  -- Longbraid the Grim (1071) ; repli : Captain Stoutfist (2104), Prospector Stormpike (1356)
  longbraid = { creature = 1071, display = { 1671, 5409, 3594 }, icon = I("Ability_Warrior_DefensiveStance") },
  -- Mikhail <Bartender> (4963, Deepwater Tavern) ; repli : Barkeep Kelly (2366), Joachim Brenlow (1311)
  mikhail = { creature = 4963, display = { 2964, 3691, 1491 }, icon = I("INV_Drink_17") },
  -- Sida (2111) ; repli : Liv Bradford (203475), James Halloran (2094)
  sida = { creature = 2111, display = { 1407, 8632, 1408 }, icon = I("INV_Misc_Food_Legion_gooSlime_chunk") },
  -- Archaeologist Flagongut (2911) ; Chief Archaeologist Greywhisker (2912), Archaeologist Hollee (2913)
  flagongut = { creature = 2911, display = { 1650, 1665, 1286 }, icon = I("INV_Misc_Bone_04") },
  -- Captain Stoutfist (2104, Menethil Keep) ; repli : Longbraid the Grim (1071), Menethil Sentry (1434)
  stoutfist = { creature = 2104, display = { 5409, 1671, 2677 }, icon = I("INV_Banner_02") },
  -- Shellei Brondir <Gryphon Master> (1571, Menethil Harbor) ; repli : Thorgrum Borrelson (1572), Gryth Thurden (1573)
  shellei_brondir = { creature = 1571, display = { 5130, 5037, 3007 }, icon = I("Ability_Mount_Gryphon_01") },
}
for id, e in pairs(npcs) do Art.npcs[id] = e end

---------------------------------------------------------------------------
-- Cartes, bibelots, états, case de parcours
---------------------------------------------------------------------------

Art.cards.crocolisk_gumbo = I("INV_Misc_Food_65")
Art.cards.fire_oil = I("INV_Potion_38")

local relics = {
  crude_flint = I("INV_Stone_04"),
  young_crocolisk_skin = I("INV_Misc_LeatherScrap_02"),
  flagonguts_fossil = I("INV_Misc_Bone_04"),
  dragonmaw_war_banner = I("INV_Banner_02"),
  cursed_eye_of_paleth = I("INV_Misc_Eye_02"),
  goaz_stone = I("INV_Misc_StoneTablet_05"),
}
for id, e in pairs(relics) do Art.relics[id] = e end

Art.statuses.earthen_charge = I("Spell_Nature_Earthquake")
Art.statuses.wyrmscale = I("INV_Misc_MonsterScales_08")
Art.statuses.mortal_wound = I("Ability_Warrior_SavageBlow")
Art.statusShort.mortal_wound = "healing received is halved."
Art.statusShort.earthen_charge = "Seismic Slam deals 8 more per Charge."
Art.statusShort.wyrmscale = "the next hit it takes deals 10 less damage."

Art.ui.map.gryphon_master = I("Ability_Mount_Gryphon_01")

-- Infobulle de l'action « discharge » (Seismic Slam de Modr).
Art.actionText.discharge = function() return "Earthen Charges drop to 0." end

---------------------------------------------------------------------------
-- Vue de zone : primes de meute, chef, dispersion, Charge de Modr, limon
---------------------------------------------------------------------------

local PAW, PAW_DIM, CROWN = I("INV_Misc_Bearpaw_brown"), I("INV_Misc_Bearpaw_black"), I("INV_Crown_01")
local SHORT = { force = "Str", heal = "HP", absorb = "Abs" }
local COLOR = { force = "attackText", heal = "healText", absorb = "defendText" }
local LONG = { force = "Strength %d", heal = "heal %d", absorb = "%d Absorb" }

local function packTip(b)
  return "Pack: when it dies, the rest of its pack gains " .. LONG[b[1]]:format(b[2])
    .. ". Packmates killed by the same card gain nothing."
end

local function packBadge(c, e)
  local WL = ns.Wetlands
  local d = ns.Enemies[e.id]
  if not (d.pack or d.packLeader) then return nil end
  if WL.scattered(e) then
    return { icon = PAW_DIM, text = "Scattered", color = "textDim", dim = true, key = "wl:scattered",
      tip = "Scattered: no longer part of a pack. It gives and gains no Pack bonus." }
  end
  if d.packLeader then
    return { icon = CROWN, text = "Pack Leader", color = "goldText", key = "wl:leader",
      tip = "Pack Leader: when it dies, its pack scatters. Bonuses from the same card are lost, and the others no longer give or gain Pack bonuses." }
  end
  local b = WL.bonus(e)
  if b then
    local txt = b[1] == "heal" and ("+" .. b[2] .. " HP") or ("+" .. b[2] .. " " .. SHORT[b[1]])
    return { icon = PAW, text = "Pack: " .. txt, color = COLOR[b[1]], key = "wl:paw", tip = packTip(b) }
  end
  return { icon = PAW, text = "Pack", color = "textSoft", key = "wl:paw",
    tip = "Pack: gains the bonus of each packmate that dies. Gives no bonus itself." }
end

ns.ZoneViews.wetlands = {
  enemyBadges = function(c, e)
    local list = {}
    local pb = packBadge(c, e)
    if pb then list[#list + 1] = pb end
    local d = ns.Enemies[e.id]
    local WL = ns.Wetlands
    if d.chargeAt then
      local lost = WL.lostSince(e)
      local pending = WL.chargePending(c, e)
      list[#list + 1] = { icon = I("Spell_Nature_Earthquake"),
        text = ("Charge: %d/%d dmg"):format(math.min(lost, d.chargeAt), d.chargeAt),
        color = pending and "attackText" or "healText", key = "wl:charge",
        tip = ("Earthen Charge: at the start of its turn, if it lost less than %d HP since its last turn, it gains "
          .. "1 Charge (3 at most). Seismic Slam deals 8 more per Charge. Lost so far: %d."):format(d.chargeAt, lost) }
    end
    if d.splits then
      list[#list + 1] = { icon = I("INV_Misc_Food_Legion_gooSlime_chunk"), text = "Splits: " .. d.splits .. " Slimes",
        color = "textSoft", key = "wl:split", tip = "When it dies, " .. d.splits .. " Black Slimes take its place." }
    end
    return list
  end,
  -- Petite flèche de prime : du mort vers chaque survivant (0,25 s), texte flottant d'office (ZR.float).
  event = function(host, ev, view)
    if ev.t ~= "pack" then return end
    view:Push(0, function()
      local x1, y1 = view:UnitPos(ev.src)
      local x2, y2 = view:UnitPos(ev.dst)
      if not (x1 and x2) then return end
      local W = ns.Widgets
      local f = host.packPool and host.packPool[ev.dst]
      host.packPool = host.packPool or {}
      if not f then
        f = CreateFrame("Frame", nil, view.parent)
        f:SetSize(20, 20)
        f:SetFrameLevel((view.hz and view.hz:GetFrameLevel() or 1) + 80)
        f.icon = f:CreateTexture(nil, "OVERLAY")
        f.icon:SetAllPoints()
        host.packPool[ev.dst] = f
      end
      W.setIcon(f.icon, PAW, "wl:paw")
      W.fly(f, view.parent, x1, y1 - 40, x2, y2 - 40, 1, 1, 1, 0.2, 0.25, function() f:Hide() end, 30)
    end)
  end,
}

---------------------------------------------------------------------------
-- Décors peints (UI/Scene.lua, S.landscape ; boîte à outils K = S.paintKit) : marais des Wetlands
---------------------------------------------------------------------------
-- Ciel couvert gris-bleu, brume basse, eau entre les touffes d'herbe, roseaux à massettes au premier plan ;
-- accessoires propres à la zone (Art.paintProps) : arbre des marais, bateau, ponton, donjon de Menethil,
-- bannière, ruine, rochers, tente orque, échafaudage de fouilles, porte de Grim Batol. Plans libres
-- (sp.before) : mer, montagnes, mares, bancs de brume, pluie.

Art.palettes.wetlands = {
  sky = { "#6f7f8b", "#9aa6a8", "#c5c8b9" }, sun = "#c6cbc1", sunGlow = { "#dfe3d0", 0.3 },
  cloud = { "#e3e6dd", 0.34 }, cloudDark = { "#5f6d76", 0.32 },
  hillsBack = "#7f8c8a", hillsFront = "#6a7868", mound = "#5c6a4c", moundLight = { "#8a9670", 0.45 },
  trees = "#4a5944", haze = { "#cdd3c6", 0.55 },
  patches = { "#7a8758", "#6c7a4d", "#878d5c", "#728061", "#838659" }, hedge = { "#38422c", 0.35 },
  fieldsNear = { "#6b7845", "#38432a" }, furrowDark = { "#232b19", 0.22 }, furrowLight = { "#a6b47a", 0.18 },
  road = { "#8e8064", "#5f523a" }, roadEdge = "#433826",
  far = { main = "#6c7470", dark = "#565e5b", wood = "#6e6a5c", crate = "#77705c", stone = "#7a817c" },
  mid = { main = "#3a3a2e", dark = "#272820", wood = "#6a5a3d", crate = "#86704a", stone = "#7d7f76" },
  flag = "#3d5a8a", banner = "#7d2219", smoke = { "#d6d9d1", 0.42 },
  ground = { "#1a2013", 0.55 }, stalk = "#2c3620", ears = { "#5a3b22", "#4b311c", "#654428" }, cattail = true,
  water = { "#a9b8b6", "#4f6466" }, mud = { "#2a2f1d", 0.45 }, canopy = { "#3f4f34", "#55673f" },
  moss = { "#6f7d52", 0.7 }, sail = "#d8d2bd", rain = { "#dfe6e6", 0.07 },
}

-- Nuit (feu de camp) : même marais, bleu-vert sombre, lune voilée, fenêtres éclairées.
Art.palettes.wetlands_night = {
  night = true,
  sky = { "#070d18", "#122031", "#26384a" }, moon = "#e2e4d6", moonGlow = { "#8fa6bf", 0.3 },
  stars = "#e8ecdf", cloud = { "#3f5266", 0.32 }, cloudDark = { "#0d1622", 0.4 },
  hillsBack = "#1c2733", hillsFront = "#1d2a2c", mound = "#1d2726", moundLight = { "#2f3d44", 0.45 },
  trees = "#121b1e", haze = { "#3a4c5c", 0.4 },
  patches = { "#253029", "#212b25", "#28322a", "#1f2924", "#29322a" }, hedge = { "#0a0e0c", 0.45 },
  fieldsNear = { "#202a22", "#0f1511" }, furrowDark = { "#06090a", 0.3 }, furrowLight = { "#4f6070", 0.12 },
  road = { "#3e4440", "#272b28" }, roadEdge = "#141815",
  far = { main = "#141c22", dark = "#0e1419", light = "#f0c264", wood = "#171d21", crate = "#1a2024", stone = "#1a232a" },
  mid = { main = "#10140f", dark = "#0a0d0a", wood = "#1d2019", crate = "#262820", stone = "#2a3032", light = "#f0b85a" },
  flag = "#1b2738", banner = "#3a1410", smoke = { "#56636f", 0.38 },
  ground = { "#030504", 0.62 }, stalk = "#0d120c", ears = { "#1e1a14", "#19160f", "#231d16" }, cattail = true,
  water = { "#53697a", "#121c22" }, mud = { "#020302", 0.5 }, canopy = { "#0e1612", "#16221a" },
  moss = { "#1f2a1e", 0.7 }, sail = "#3a3f40", rain = { "#8ea0ae", 0.06 },
}

-- Portes de Grim Batol (boss) : ciel lourd teinté de fumée, roche sombre, lueur des forges.
Art.palettes.wetlands_gates = {
  sky = { "#3b3236", "#6d5550", "#a8806a" }, sun = "#b98a6c", sunGlow = { "#d9875a", 0.35 },
  cloud = { "#8c7468", 0.36 }, cloudDark = { "#2a2226", 0.42 },
  hillsBack = "#4d4446", hillsFront = "#3f3b37", mound = "#3a3632", moundLight = { "#6a5a4c", 0.4 },
  trees = "#2c2e26", haze = { "#9c7f6c", 0.42 },
  patches = { "#5e5744", "#55503d", "#635a46", "#59533f", "#5f5642" }, hedge = { "#24261c", 0.4 },
  fieldsNear = { "#56503a", "#2a2419" }, furrowDark = { "#15160e", 0.25 }, furrowLight = { "#8a8160", 0.15 },
  road = { "#6f6048", "#43382a" }, roadEdge = "#2b241a",
  far = { main = "#3a3335", dark = "#2b2628", light = "#ff8a3a", wood = "#3d3430", crate = "#43392f", stone = "#463e3d" },
  mid = { main = "#2a2622", dark = "#1b1916", wood = "#4d3d2a", crate = "#5e4a32", stone = "#4a4440", light = "#ff8a3a" },
  flag = "#7d2219", banner = "#8a1f16", smoke = { "#5a5050", 0.45 },
  ground = { "#120f0b", 0.6 }, stalk = "#22261a", ears = { "#3e2a1a", "#352416", "#46301d" }, cattail = true,
  water = { "#8a7f72", "#3a3a34" }, mud = { "#15130d", 0.45 }, canopy = { "#2a3024", "#384030" },
  moss = { "#4a5038", 0.7 }, sail = "#a59a86", rain = { "#c9b8a8", 0.05 }, rock = "#3c3638",
  rockLight = { "#7a6656", 0.4 }, glow = "#ff7a2a",
}

local PI = math.pi
local sin, cos = math.sin, math.cos

-- Niveaux propres aux mares (au-dessus des champs proches, sous la route et le plan moyen).
local WATER = { mud = { "BACKGROUND", 3 }, water = { "BACKGROUND", 4 }, shine = { "BACKGROUND", 5 } }

local P = {}
Art.paintProps = Art.paintProps or {}

-- Arbre des marais : tronc tordu en trois tronçons, branches, houppier de taches fondues et de masses,
-- mousse qui pend. Variante « dead » : nu.
function P.marsh_tree(f, g, Pl, c, pal, x, y, s, variant, K)
  local ang = { 0.08, -0.12, 0.1 }
  local cx, cy = x, y
  for i = 1, 3 do
    local L = 34 * s
    local a = PI / 2 + ang[i]
    local nx, ny = cx + cos(a) * L, cy - sin(a) * L
    K.bar(f, g, Pl[1], c.dark, (cx + nx) / 2, (cy + ny) / 2, L + 2, (11 - i * 2.5) * s, a)
    cx, cy = nx, ny
  end
  local tx, ty = cx, cy
  for k = 1, 4 do
    local a = PI / 2 + (k - 2.5) * 0.62
    local L = (26 + 10 * K.hash(x + k, 3)) * s
    K.bar(f, g, Pl[1], c.dark, tx + cos(a) * L / 2, ty - sin(a) * L / 2 + 10 * s, L, 3.2 * s, a)
  end
  if variant == "dead" then return end
  -- houppier en dôme de saule des marais : deux rangées de masses (la plus haute au centre), dessous plus
  -- sombre, reflets clairs sur le dessus, longs rideaux de mousse qui pendent des bords
  local cp = pal.canopy
  local rows = { { n = 7, w = 112, lift = 6, arc = 26, size = 30 }, { n = 4, w = 64, lift = 34, arc = 16, size = 28 } }
  for r, row in ipairs(rows) do
    for k = 1, row.n do
      local t = (k - 0.5) / row.n
      local hx = tx + (t - 0.5) * row.w * s + (K.hash(x + r, k) - 0.5) * 12 * s
      local hy = ty - row.lift * s - sin(t * PI) * row.arc * s + (K.hash(y + r, k) - 0.5) * 8 * s
      local w = (row.size + 14 * K.hash(x + 7 * r, k)) * s
      K.blur(f, g, Pl[2], cp[1], hx, hy, w * 1.6, w * 1.3, 0.8)
      K.oval(f, g, Pl[2], cp[1], hx, hy, w, w * 0.78)
    end
  end
  K.blur(f, g, Pl[3], pal.ground[1], tx, ty + 4 * s, 104 * s, 18 * s, 0.4)
  for k = 1, 6 do
    local t = (k - 0.5) / 6
    K.blur(f, g, Pl[3], cp[2], tx + (t - 0.5) * 84 * s, ty - 30 * s - sin(t * PI) * 30 * s, 26 * s, 12 * s, 0.5)
  end
  local ms = pal.moss
  for k = 1, 11 do
    local t = (k - 0.5) / 11
    local mx = tx + (t - 0.5) * 108 * s + (K.hash(x * 3, k) - 0.5) * 6 * s
    local top = ty - 2 * s - sin(t * PI) * 10 * s
    local L = (16 + 26 * K.hash(y * 3, k)) * (0.6 + 0.4 * math.abs(t - 0.5) * 2) * s
    K.box(f, g, Pl[3], ms[1], mx, top, 1.4 * s, L, ms[2] * 0.8)
  end
end

-- Rochers : trois blocs arrondis, face éclairée en haut.
function P.rocks(f, g, Pl, c, pal, x, y, s, variant, K)
  local col = pal.rock or c.stone or c.main
  for k = 1, 3 do
    local w = (26 + 16 * K.hash(x, k)) * s
    local h = w * (0.6 + 0.2 * K.hash(y, k))
    local rx = x + (k - 2) * 22 * s
    K.oval(f, g, Pl[2], col, rx, y - h / 2 + 2, w, h)
    K.blur(f, g, Pl[3], (pal.rockLight or { "#a5a89a", 0.35 })[1], rx - w * 0.15, y - h * 0.72, w * 0.6, h * 0.35,
      (pal.rockLight or { "#a5a89a", 0.35 })[2])
  end
  K.blur(f, g, Pl[1], pal.ground[1], x, y, 90 * s, 12 * s, 0.5)
end

-- Bateau à quai : coque (deux bandes et proue), château arrière, mât, vergues, voile carguée, pavillon.
function P.ship(f, g, Pl, c, pal, x, y, s, variant, K)
  K.box(f, g, Pl[2], c.wood, x - 70 * s, y - 22 * s, 140 * s, 14 * s)
  K.box(f, g, Pl[2], c.dark, x - 62 * s, y - 9 * s, 124 * s, 9 * s)
  K.bar(f, g, Pl[2], c.wood, x + 74 * s, y - 20 * s, 26 * s, 9 * s, 0.35)
  K.box(f, g, Pl[2], c.wood, x - 70 * s, y - 36 * s, 34 * s, 15 * s)
  K.box(f, g, Pl[3], c.dark, x - 70 * s, y - 25 * s, 140 * s, 2 * s)
  local masts = variant == "small" and { 0 } or { -14, 30 }
  for _, m in ipairs(masts) do
    local mx = x + m * s
    K.box(f, g, Pl[1], c.dark, mx - 1.6 * s, y - 120 * s, 3.2 * s, 100 * s)
    K.box(f, g, Pl[1], c.dark, mx - 24 * s, y - 104 * s, 48 * s, 2.4 * s)
    K.box(f, g, Pl[1], c.dark, mx - 18 * s, y - 72 * s, 36 * s, 2.4 * s)
    K.box(f, g, Pl[2], pal.sail, mx - 22 * s, y - 102 * s, 44 * s, 7 * s, 0.92)
    K.box(f, g, Pl[2], pal.sail, mx - 16 * s, y - 70 * s, 32 * s, 6 * s, 0.92)
  end
  K.box(f, g, Pl[3], pal.flag, x + masts[#masts] * s + 1.6 * s, y - 120 * s, 14 * s, 8 * s)
  if c.light then K.box(f, g, Pl[3], c.light, x - 60 * s, y - 32 * s, 5 * s, 4 * s) end
end

-- Ponton : platelage de x à x2 (variante = x2), pieux plantés dans l'eau, reflets.
function P.pier(f, g, Pl, c, pal, x, y, s, x2, K)
  x2 = x2 or (x + 200)
  K.box(f, g, Pl[2], c.wood, x, y - 8 * s, x2 - x, 6 * s)
  K.box(f, g, Pl[3], c.dark, x, y - 2 * s, x2 - x, 1.5 * s)
  local n = math.floor((x2 - x) / (34 * s))
  for i = 0, n do
    local px = x + (x2 - x) * (n > 0 and i / n or 0)
    K.box(f, g, Pl[1], c.dark, px - 2 * s, y - 10 * s, 4 * s, 22 * s)
    K.box(f, g, Pl[1], pal.water[1], px - 3 * s, y + 13 * s, 6 * s, 1.2, 0.35)
  end
end

-- Ombre d'un volume de pierre (voile sombre sur la face droite) et assises (traits fins).
local function stoneShade(f, g, K, lv, x, y, w, h, s)
  K.box(f, g, lv, "#000000", x + w * 0.62, y, w * 0.38, h, 0.16)
  for i = 1, math.floor(h / (9 * s)) do K.box(f, g, lv, "#000000", x, y + i * 9 * s, w, 0.8, 0.1) end
end

-- Donjon de Menethil : courtine crénelée, deux tours carrées, porte, toit sombre ; fenêtres la nuit.
function P.keep(f, g, Pl, c, pal, x, y, s, variant, K)
  local st = c.stone or c.main
  K.box(f, g, Pl[2], st, x - 70 * s, y - 46 * s, 140 * s, 46 * s)
  stoneShade(f, g, K, Pl[3], x - 70 * s, y - 46 * s, 140 * s, 46 * s, s)
  for i = 0, 8 do K.box(f, g, Pl[2], st, x - 70 * s + i * 16 * s, y - 52 * s, 9 * s, 7 * s) end
  for _, tx in ipairs({ -78, 56 }) do
    K.box(f, g, Pl[2], st, x + tx * s, y - 92 * s, 22 * s, 92 * s)
    stoneShade(f, g, K, Pl[3], x + tx * s, y - 92 * s, 22 * s, 92 * s, s)
    for i = 0, 2 do K.box(f, g, Pl[2], st, x + tx * s + i * 8 * s, y - 98 * s, 5 * s, 7 * s) end
    K.box(f, g, Pl[3], c.light or c.dark, x + (tx + 9) * s, y - 76 * s, 4 * s, 9 * s)
  end
  K.box(f, g, Pl[1], st, x - 22 * s, y - 84 * s, 44 * s, 84 * s)
  K.box(f, g, Pl[1], "#000000", x + 6 * s, y - 84 * s, 16 * s, 38 * s, 0.16)
  K.diamond(f, g, Pl[1], c.dark, x, y - 84 * s, 26 * s)
  K.blur(f, g, Pl[3], (pal.moss or { "#6f7d52", 0.7 })[1], x, y - 2 * s, 150 * s, 10 * s, 0.35)
  K.oval(f, g, Pl[3], c.dark, x, y - 22 * s, 20 * s, 18 * s)
  K.box(f, g, Pl[3], c.dark, x - 10 * s, y - 22 * s, 20 * s, 22 * s)
  if c.light then
    for i = -1, 1, 2 do K.box(f, g, Pl[3], c.light, x + i * 30 * s - 2 * s, y - 34 * s, 4 * s, 7 * s) end
  end
  K.box(f, g, Pl[3], c.dark, x - 0.8 * s, y - 130 * s, 1.6 * s, 26 * s)
  K.box(f, g, Pl[3], pal.flag, x + 0.8 * s, y - 130 * s, 16 * s, 9 * s)
end

-- Bannière de guerre : mât, étendard long qui pend, pointe fendue.
function P.banner(f, g, Pl, c, pal, x, y, s, variant, K)
  K.box(f, g, Pl[1], c.dark, x - 1.5 * s, y - 96 * s, 3 * s, 96 * s)
  K.box(f, g, Pl[1], c.dark, x - 11 * s, y - 92 * s, 22 * s, 2.5 * s)
  K.box(f, g, Pl[2], pal.banner, x - 9 * s, y - 90 * s, 18 * s, 40 * s)
  K.bar(f, g, Pl[2], pal.banner, x - 5 * s, y - 48 * s, 12 * s, 5 * s, 1.2)
  K.bar(f, g, Pl[2], pal.banner, x + 5 * s, y - 48 * s, 12 * s, 5 * s, -1.2)
  K.box(f, g, Pl[3], c.dark, x - 4 * s, y - 80 * s, 8 * s, 8 * s, 0.6)
end

-- Ruine de Dun Modr : pans de mur à hauteurs inégales, sommets cassés en gradins, meurtrières, arche
-- (voussoirs sombres), lierre au pied, éboulis. Ombre et assises comme le donjon.
function P.ruin(f, g, Pl, c, pal, x, y, s, variant, K)
  local st = c.stone or c.main
  local hs = { 58, 84, 40, 70, 30 }
  for i = 1, 5 do
    local wx = x + (i - 3) * 23 * s
    local h = hs[i] * s * (0.75 + 0.5 * K.hash(x, i))
    local w = 23 * s
    K.box(f, g, Pl[2], st, wx - w / 2, y - h, w, h)
    -- sommet cassé : deux ou trois gradins
    local steps = 2 + math.floor(K.hash(y, i) * 2)
    for j = 1, steps do
      local sw = w * (1 - j / (steps + 1))
      local left = K.hash(x + j, i) < 0.5
      K.box(f, g, Pl[2], st, left and (wx - w / 2) or (wx + w / 2 - sw), y - h - j * 5 * s, sw, 5 * s + 1)
    end
    stoneShade(f, g, K, Pl[3], wx - w / 2, y - h, w, h, s)
    if h > 50 * s then K.box(f, g, Pl[3], c.dark, wx - 1.5 * s, y - h * 0.7, 3 * s, 8 * s, 0.8) end
  end
  -- arche : vide sombre, voussoirs
  K.oval(f, g, Pl[3], c.dark, x, y - 30 * s, 28 * s, 32 * s)
  K.box(f, g, Pl[3], c.dark, x - 14 * s, y - 30 * s, 28 * s, 30 * s)
  for k = 0, 6 do
    local a = PI * k / 6
    K.bar(f, g, Pl[3], "#000000", x + cos(a) * 16 * s, y - 30 * s - sin(a) * 18 * s, 6 * s, 1, a + PI / 2, 0.25)
  end
  -- lierre et mousse au pied, éboulis
  local ms = pal.moss or { "#6f7d52", 0.7 }
  for k = 1, 4 do
    K.blur(f, g, Pl[3], ms[1], x + (k - 2.5) * 30 * s, y - 10 * s - 14 * s * K.hash(x, k + 9), 26 * s, 22 * s, 0.45)
  end
  for k = 1, 4 do
    local bx = x + (28 + k * 13 + 14 * K.hash(x, k + 20)) * s
    local bw = (6 + 12 * K.hash(y, k)) * s
    K.oval(f, g, Pl[2], st, bx, y - 3 * s - 5 * K.hash(x + 3, k) * s, bw, bw * (0.55 + 0.3 * K.hash(x, k)))
  end
  K.blur(f, g, Pl[1], pal.ground[1], x, y, 170 * s, 14 * s, 0.45)
end

-- Tente orque : peaux tendues, deux perches croisées qui dépassent, entrée sombre.
function P.orc_tent(f, g, Pl, c, pal, x, y, s, variant, K)
  K.bar(f, g, Pl[1], c.dark, x - 10 * s, y - 50 * s, 40 * s, 3 * s, 1.25)
  K.bar(f, g, Pl[1], c.dark, x + 10 * s, y - 50 * s, 40 * s, 3 * s, -1.25)
  K.tri(f, g, Pl[2], c.wood, x, y, 76 * s, 46 * s)
  -- pan à l'ombre (voile sur la moitié droite), coutures des peaux, entrée
  for i = 1, 11 do
    local yy = y - 46 * s + (i - 0.5) * 46 * s / 11
    local half = 38 * s * (i - 0.5) / 11
    K.box(f, g, Pl[3], "#000000", x, yy - 2.1 * s, half, 4.2 * s + 0.4, 0.18)
  end
  K.bar(f, g, Pl[3], c.dark, x - 16 * s, y - 22 * s, 48 * s, 1, 1.0, 0.45)
  K.bar(f, g, Pl[3], c.dark, x + 18 * s, y - 20 * s, 44 * s, 1, -1.0, 0.45)
  K.tri(f, g, Pl[3], c.dark, x + 4 * s, y, 22 * s, 24 * s)
  K.blur(f, g, Pl[1], pal.ground[1], x, y, 96 * s, 12 * s, 0.5)
end

-- Échafaudage des fouilles de Whelgar : poteaux, traverses, croisillon, palan.
function P.scaffold(f, g, Pl, c, pal, x, y, s, variant, K)
  for _, px in ipairs({ -30, 30 }) do K.box(f, g, Pl[1], c.wood, x + px * s - 2 * s, y - 70 * s, 4 * s, 70 * s) end
  for _, h in ipairs({ 30, 62 }) do K.box(f, g, Pl[2], c.wood, x - 34 * s, y - h * s, 68 * s, 3 * s) end
  K.bar(f, g, Pl[2], c.dark, x, y - 46 * s, 70 * s, 2 * s, 0.5)
  K.bar(f, g, Pl[2], c.dark, x, y - 46 * s, 70 * s, 2 * s, -0.5)
  K.box(f, g, Pl[3], c.dark, x + 14 * s, y - 62 * s, 1.2 * s, 26 * s)
  K.box(f, g, Pl[3], c.crate, x + 10 * s, y - 38 * s, 9 * s, 8 * s)
end

-- Porte de Grim Batol : deux tours massives à pointes, linteau, arche sombre avec lueur, bannières.
function P.gate(f, g, Pl, c, pal, x, y, s, variant, K)
  local st = c.stone or c.main
  K.blur(f, g, Pl[1], pal.glow or "#ff7a2a", x, y - 40 * s, 90 * s, 80 * s, 0.35)
  K.oval(f, g, Pl[1], c.dark, x, y - 60 * s, 64 * s, 60 * s)
  K.box(f, g, Pl[1], c.dark, x - 32 * s, y - 60 * s, 64 * s, 60 * s)
  K.blur(f, g, Pl[2], pal.glow or "#ff7a2a", x, y - 18 * s, 50 * s, 36 * s, 0.4)
  for _, tx in ipairs({ -62, 62 }) do
    K.box(f, g, Pl[2], st, x + tx * s - 26 * s, y - 150 * s, 52 * s, 150 * s)
    stoneShade(f, g, K, Pl[3], x + tx * s - 26 * s, y - 150 * s, 52 * s, 150 * s, s * 1.4)
    K.tri(f, g, Pl[2], st, x + tx * s, y - 150 * s, 60 * s, 30 * s)
    for k = -1, 1, 2 do K.tri(f, g, Pl[3], c.dark, x + tx * s + k * 20 * s, y - 150 * s, 8 * s, 22 * s) end
    K.box(f, g, Pl[3], c.light or c.dark, x + tx * s - 3 * s, y - 112 * s, 6 * s, 10 * s)
  end
  K.box(f, g, Pl[2], st, x - 40 * s, y - 112 * s, 80 * s, 22 * s)
  K.box(f, g, Pl[3], c.dark, x - 40 * s, y - 92 * s, 80 * s, 2 * s)
  for _, bx in ipairs({ -62, 62 }) do
    K.box(f, g, Pl[3], pal.banner, x + bx * s - 10 * s, y - 136 * s, 20 * s, 56 * s)
    K.box(f, g, Pl[3], c.dark, x + bx * s - 4 * s, y - 120 * s, 8 * s, 8 * s, 0.7)
  end
end

-- Maison de Menethil : murs de pierre, toit sombre (la ferme commune sous les couleurs du port).
function P.harbor_house(f, g, Pl, c, pal, x, y, s, variant, K)
  local st = c.stone or c.main
  K.diamond(f, g, Pl[1], c.dark, x, y - 34 * s, 34 * s)
  K.box(f, g, Pl[2], st, x - 30 * s, y - 34 * s, 60 * s, 35 * s)
  stoneShade(f, g, K, Pl[3], x - 30 * s, y - 34 * s, 60 * s, 35 * s, s)
  K.box(f, g, Pl[1], c.dark, x + 12 * s, y - 70 * s, 7 * s, 18 * s)
  K.box(f, g, Pl[3], c.dark, x - 4 * s, y - 15 * s, 8 * s, 15 * s)
  K.box(f, g, Pl[3], c.light or c.dark, x - 21 * s, y - 26 * s, 7 * s, 7 * s, c.light and 1 or 0.7)
  K.box(f, g, Pl[3], c.light or c.dark, x + 14 * s, y - 26 * s, 7 * s, 7 * s, c.light and 1 or 0.7)
end

-- Caisses et tonneaux empilés (quai, marché).
function P.cargo(f, g, Pl, c, pal, x, y, s, variant, K)
  K.blur(f, g, Pl[1], pal.ground[1], x + 8 * s, y, 110 * s, 12 * s, 0.5)
  K.box(f, g, Pl[2], c.crate, x - 40 * s, y - 24 * s, 26 * s, 24 * s)
  K.box(f, g, Pl[2], c.crate, x - 12 * s, y - 20 * s, 22 * s, 20 * s)
  K.box(f, g, Pl[2], c.crate, x - 34 * s, y - 44 * s, 20 * s, 20 * s)
  K.oval(f, g, Pl[2], c.wood, x + 26 * s, y - 15 * s, 24 * s, 30 * s)
  K.box(f, g, Pl[3], c.dark, x + 14 * s, y - 20 * s, 24 * s, 2 * s)
  K.box(f, g, Pl[3], c.dark, x + 14 * s, y - 10 * s, 24 * s, 2 * s)
  for _, bx in ipairs({ -40, -12 }) do K.box(f, g, Pl[3], c.dark, x + bx * s, y - 13 * s, 24 * s, 1.5 * s, 0.7) end
end

for k, fn in pairs(P) do Art.paintProps[k] = fn end

-- Plans libres -------------------------------------------------------------------------------------------

-- Mare : bord de vase fondu, eau profonde, reflet du ciel, rides.
local function pool(f, g, K, pal, cx, cy, w, h)
  K.blur(f, g, WATER.mud, pal.mud[1], cx, cy + 2, w * 1.3, h * 1.9, pal.mud[2])
  K.oval(f, g, WATER.water, pal.water[2], cx, cy, w, h)
  K.blur(f, g, WATER.shine, pal.water[1], cx - w * 0.12, cy - h * 0.12, w * 0.85, h * 0.7, 0.55)
  for i = 1, 3 do
    K.box(f, g, WATER.shine, pal.water[1], cx - w * (0.2 + 0.1 * K.hash(cx, i)), cy + (i - 2) * h * 0.24,
      w * (0.22 + 0.2 * K.hash(cy, i)), 1, 0.4)
  end
end

-- Mer : bande de l'horizon jusqu'à y1 (dégradé), reflets en traits, écume au bord ; côté terre (x0 > 0),
-- rivage fondu : la bande s'éclaircit en tranches vers la gauche.
local function sea(f, g, K, pal, x0, x1, y1)
  local hz = K.hz
  local top, bottom = K.rgb(pal.water[1]), K.rgb(pal.water[2])
  local fade = x0 > 0 and 60 or 0
  for i = 1, fade > 0 and 6 or 0 do
    local a = i / 7
    K.vgrad(f, g, K.LV.haze, K.withAlpha(top, a), K.withAlpha(bottom, a), x0 + (i - 1) * 10, hz - 2, 10.5, y1 - hz + 2)
  end
  K.vgrad(f, g, K.LV.haze, top, bottom, x0 + fade, hz - 2, x1 - x0 - fade, y1 - hz + 2)
  for i = 1, 26 do
    local t = K.hash(i, 21)
    local yy = hz + 3 + (y1 - hz - 6) * t * t
    K.box(f, g, WATER.mud, pal.water[1], x0 + (x1 - x0) * K.hash(i, 22), yy, 20 + 70 * t, 1, 0.3)
  end
  K.blur(f, g, WATER.mud, pal.water[1], (x0 + x1) / 2, y1, x1 - x0, 10, 0.5)
end

-- Chaîne de montagnes : chaque massif = un grand pic et des épaulements (pics plus petits posés sur ses
-- flancs, crête dentelée) ; flanc droit à l'ombre (voile fondu), arête éclairée à gauche.
local function peaks(f, g, K, pal, list, lv, col, shade)
  for _, p in ipairs(list) do
    local x, w, h = p[1], p[2], p[3]
    local base = K.hz + 6
    K.tri(f, g, lv, col, x, base, w, h)
    for k = 1, 6 do
      local side = (k % 2 == 1) and -1 or 1
      local d = (0.08 + 0.11 * math.floor((k + 1) / 2)) * w * side + (K.hash(x, k) - 0.5) * 0.05 * w
      local sh = h * (0.26 + 0.16 * K.hash(w, k))
      local sw = w * (0.16 + 0.1 * K.hash(h, k))
      local by = base - (h * (1 - math.abs(d) / (w / 2))) + sh * 0.62
      K.tri(f, g, lv, col, x + d, by, sw, sh)
    end
    K.blur(f, g, lv, shade or "#000000", x + w * 0.2, base - h * 0.42, w * 0.5, h * 0.95, 0.24)
    K.blur(f, g, lv, pal.haze[1], x - w * 0.12, base - h * 0.6, w * 0.16, h * 0.55, 0.12)
  end
end

-- Bancs de brume : taches fondues claires étirées (sous le plan moyen).
local function mist(f, g, K, pal, list)
  for _, m in ipairs(list) do K.blur(f, g, K.LV.haze, pal.haze[1], m[1], m[2], m[3], m[4], pal.haze[2] * (m[5] or 0.8)) end
end

-- Nuages lourds du ciel couvert.
local function overcast(f, g, K, pal, list)
  for _, c in ipairs(list) do K.blur(f, g, K.LV.clouds, pal.cloudDark[1], c[1], c[2], c[3], c[4], pal.cloudDark[2]) end
end

-- Pluie fine : traits obliques très légers sur tout le décor (au-dessus des personnages : niveau fumée).
local function rain(f, g, K, pal, n)
  local rc = pal.rain
  for i = 1, n do
    local x, y = K.hash(i, 31) * (K.W + 60) - 30, K.hash(i, 32) * K.H
    K.bar(f, g, K.LV.smoke, rc[1], x, y, 22 + 12 * K.hash(i, 33), 1, 1.95, rc[2])
  end
end

-- Herbes du marais : touffes sombres sur le sol proche (rangées fixes).
local function tufts(f, g, K, pal, n)
  for i = 1, n do
    local t = K.hash(i, 41)
    local x, y = K.hash(i, 42) * K.W, K.fl + 6 + (K.H - K.fl - 20) * t
    local s = 0.5 + t
    K.blur(f, g, K.LV.furrows, pal.mud[1], x, y, 30 * s, 7 * s, pal.mud[2] * 0.9)
    for k = -1, 1 do
      K.bar(f, g, K.LV.furrows, pal.stalk, x + k * 3 * s, y - 5 * s, 11 * s, 1.2, PI / 2 - k * 0.35, 0.8)
    end
  end
end

local function wl(t, pal)
  t.pal, t.horizon, t.field, t.furrows = pal or "wetlands", t.horizon or 186, t.field or 226, false
  return t
end

local CLOUDS = { { 160, 64, 300, 50 }, { 470, 34, 260, 34 }, { 760, 92, 320, 44 }, { 990, 48, 220, 36 } }
local DARK = { { 280, 40, 520, 70 }, { 820, 30, 480, 60 }, { 560, 120, 600, 40 } }
local HILLS = { back = { { 120, 520, 40 }, { 560, 640, 26 }, { 950, 500, 44 } }, front = { { 320, 420, 16 }, { 800, 520, 14 } } }

-- Route : la chaussée des marais entre Menethil et Dun Modr.
local function roadBefore(f, g, K, sp)
  local pal = K.pal
  overcast(f, g, K, pal, DARK)
  pool(f, g, K, pal, 170, 262, 190, 26)
  pool(f, g, K, pal, 330, 236, 110, 12)
  pool(f, g, K, pal, 860, 252, 230, 24)
  pool(f, g, K, pal, 990, 300, 160, 30)
  pool(f, g, K, pal, 70, 330, 150, 30)
  mist(f, g, K, pal, { { 240, 214, 520, 30 }, { 820, 210, 560, 26 } })
  tufts(f, g, K, pal, 34)
  if sp.rain then rain(f, g, K, pal, sp.rain) end
end

local ROAD_PROPS = {
  { "keep", 98, 186, 0.42, "far" }, { "marsh_tree", 26, 300, 1.15, "mid" }, { "marsh_tree", 262, 250, 0.8, "mid" },
  { "marsh_tree", 772, 236, 0.7, "mid", "dead" }, { "marsh_tree", 952, 318, 1.25, "mid" }, { "rocks", 640, 262, 0.6, "mid" },
}
local REEDS = { { -6, 140, 26 }, { 890, 1040, 24 } }

Art.paintings = Art.paintings or {}
local paintings = {
  wetlands_road = wl({ sun = { 820, 70, 20 }, clouds = CLOUDS, hills = HILLS,
    trees = { { 40, 4 }, { 430, 3 }, { 610, 5 }, { 1000, 3 } }, road = { 520, 470, 9, 360, -60 },
    props = ROAD_PROPS, wheat = REEDS, rain = 70, before = roadBefore }),
  wetlands_night = wl({ moon = { 820, 66, 16 }, clouds = CLOUDS, hills = HILLS,
    trees = { { 40, 4 }, { 430, 3 }, { 610, 5 }, { 1000, 3 } }, road = { 520, 470, 9, 360, -60 },
    props = ROAD_PROPS, wheat = REEDS, rain = 50, before = roadBefore }, "wetlands_night"),
  -- Fouilles de Whelgar : colline, échafaudages et pierres levées, raptors absents, mares au pied.
  wetlands_hill = wl({ sun = { 200, 70, 20 }, clouds = CLOUDS, hills = HILLS, mound = { 600, 120, 620 },
    trees = { { 40, 4 }, { 1000, 3 } }, road = { 560, 470, 8, 330, 40 },
    props = { { "scaffold", 560, 140, 0.8, "far" }, { "scaffold", 668, 150, 0.6, "far" },
      { "rocks", 480, 176, 0.5, "far" }, { "ruin", 740, 186, 0.35, "far" },
      { "marsh_tree", 70, 304, 1.1, "mid" }, { "marsh_tree", 930, 290, 1.0, "mid", "dead" }, { "rocks", 840, 300, 0.9, "mid" } },
    wheat = REEDS,
    before = function(f, g, K, sp)
      local pal = K.pal
      overcast(f, g, K, pal, DARK)
      pool(f, g, K, pal, 230, 262, 210, 22)
      pool(f, g, K, pal, 900, 262, 200, 20)
      mist(f, g, K, pal, { { 300, 208, 520, 24 }, { 880, 206, 420, 22 } })
      tufts(f, g, K, pal, 28)
    end }),
  -- Angerfang Encampment : tentes orques, bannières rouges, foyers, palissade, terre battue.
  wetlands_camp = wl({ sun = { 860, 76, 20 }, clouds = CLOUDS, hills = { back = HILLS.back, front = { { 500, 700, 22 } } },
    trees = { { 60, 3 }, { 980, 4 } },
    props = { { "orc_tent", 190, 286, 1.25, "mid" }, { "orc_tent", 420, 262, 0.95, "mid" }, { "orc_tent", 640, 252, 0.8, "mid" },
      { "banner", 300, 262, 1.0, "mid" }, { "banner", 548, 246, 0.8, "mid" }, { "banner", 840, 296, 1.15, "mid" },
      { "smoke", 520, 292, 1.0, "mid" }, { "smoke", 98, 300, 0.8, "mid" },
      { "fence", 690, 252, 1034, 270, "mid" }, { "rocks", 940, 214, 0.5, "far" } },
    wheat = { { -6, 90, 18 }, { 930, 1040, 20 } },
    before = function(f, g, K, sp)
      local pal = K.pal
      overcast(f, g, K, pal, DARK)
      K.blur(f, g, WATER.mud, pal.road[2], 460, 300, 900, 120, 0.55) -- terre battue du camp
      pool(f, g, K, pal, 860, 330, 180, 26)
      mist(f, g, K, pal, { { 520, 206, 900, 26 } })
      tufts(f, g, K, pal, 18)
    end }),
  -- Menethil Harbor, marché : donjon et maisons de pierre, mâts au quai, caisses, charrette chargée.
  wetlands_shop = wl({ sun = { 860, 70, 20 }, clouds = CLOUDS, hills = { back = { { 160, 420, 30 } } },
    trees = { { 30, 3 } }, horizon = 182,
    props = { { "keep", 250, 186, 0.75, "far" }, { "harbor_house", 410, 200, 0.75, "far" }, { "harbor_house", 104, 204, 0.6, "far" },
      { "ship", 760, 206, 0.62, "far" }, { "ship", 940, 200, 0.45, "far", "small" },
      { "cart", 720, 304, 1.25, "mid", "crates" }, { "cargo", 420, 296, 1.0, "mid" }, { "harbor_house", 140, 300, 1.1, "mid" } },
    wheat = { { -6, 60, 12 }, { 960, 1040, 12 } },
    before = function(f, g, K, sp)
      local pal = K.pal
      overcast(f, g, K, pal, DARK)
      sea(f, g, K, pal, 560, 1034, 214)
      K.blur(f, g, WATER.mud, pal.road[1], 520, 316, 1100, 120, 0.5) -- pavé du quai
      mist(f, g, K, pal, { { 800, 200, 520, 18, 0.6 } })
    end }),
  -- Menethil Harbor, les quais : la baie, deux navires, le ponton, le donjon au loin.
  wetlands_coast = wl({ sun = { 300, 72, 20 }, clouds = CLOUDS, hills = { back = { { 940, 380, 34 } } },
    trees = { { 990, 3 } }, horizon = 176, field = 260,
    props = { { "keep", 900, 178, 0.55, "far" }, { "harbor_house", 790, 190, 0.5, "far" },
      { "ship", 420, 244, 1.0, "far" }, { "ship", 150, 214, 0.55, "far", "small" },
      { "pier", 560, 262, 1.0, "mid", 1034 }, { "cargo", 760, 252, 0.8, "mid" }, { "cargo", 960, 300, 1.1, "mid" } },
    wheat = { { 880, 1040, 16 } },
    before = function(f, g, K, sp)
      local pal = K.pal
      overcast(f, g, K, pal, DARK)
      sea(f, g, K, pal, 0, 1034, 300)
      mist(f, g, K, pal, { { 400, 190, 800, 22, 0.6 } })
    end }),
  -- Dun Modr : murs cassés, arche, rivière, rochers.
  wetlands_ruins = wl({ sun = { 160, 70, 20 }, clouds = CLOUDS, hills = HILLS, trees = { { 30, 4 }, { 1000, 3 } },
    props = { { "ruin", 300, 214, 0.9, "far" }, { "ruin", 720, 220, 1.2, "far" }, { "rocks", 520, 232, 0.8, "far" },
      { "ruin", 120, 312, 1.3, "mid" }, { "rocks", 880, 300, 1.1, "mid" }, { "marsh_tree", 980, 252, 0.8, "mid", "dead" } },
    wheat = REEDS,
    before = function(f, g, K, sp)
      local pal = K.pal
      overcast(f, g, K, pal, DARK)
      pool(f, g, K, pal, 520, 300, 560, 40)
      pool(f, g, K, pal, 900, 236, 240, 14)
      mist(f, g, K, pal, { { 500, 210, 900, 30 } })
      tufts(f, g, K, pal, 24)
    end }),
  -- Portes de Grim Batol (boss) : montagnes sombres, la porte et ses bannières, fumée, lueur.
  wetlands_gates = wl({ sun = { 860, 92, 22 }, clouds = CLOUDS, hills = { back = { { 160, 500, 30 } } },
    trees = { { 30, 3 } }, road = { 517, 520, 10, 340, 0 },
    props = { { "gate", 517, 214, 1.0, "far" }, { "banner", 330, 280, 1.1, "mid" }, { "banner", 710, 280, 1.1, "mid" },
      { "rocks", 160, 300, 1.2, "mid" }, { "rocks", 900, 296, 1.1, "mid" }, { "smoke", 250, 230, 0.8, "far" },
      { "smoke", 820, 236, 0.8, "far" } },
    wheat = { { -6, 100, 16 }, { 940, 1040, 16 } },
    before = function(f, g, K, sp)
      local pal = K.pal
      overcast(f, g, K, pal, DARK)
      peaks(f, g, K, pal, { { 180, 420, 120 }, { 880, 460, 140 } }, K.LV.hillsBack, pal.hillsBack, pal.cloudDark[1])
      peaks(f, g, K, pal, { { 517, 640, 200 } }, K.LV.hillsFront, pal.rock, pal.cloudDark[1])
      K.blur(f, g, K.LV.hillsFront, pal.glow, 517, 190, 260, 60, 0.18)
      mist(f, g, K, pal, { { 517, 214, 1000, 30, 0.7 } })
      tufts(f, g, K, pal, 16)
    end }, "wetlands_gates"),
}
for k, v in pairs(paintings) do Art.paintings[k] = v end

for _, k in ipairs({ "road", "hill", "camp", "shop", "night", "coast", "ruins", "gates" }) do
  Art.scenes["wetlands_" .. k] = { paint = "wetlands_" .. k }
end
