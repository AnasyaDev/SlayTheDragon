-- Art de la zone Swamp of Sorrows (`swamp`) : modèles des ennemis et des personnages, icônes des cartes,
-- bibelots, états et intentions, textes des actions de la zone, décors peints (marécage vert sombre, arbres
-- morts, mares, roseaux) et vue de zone ns.ZoneViews.swamp (dormeurs : « Asleep 2 », ouverture en gris).
-- Guide : docs/zones.md ; fiche : docs/zones/swamp.md (§ 10, modèles et icônes).
--
-- Modèles : le cache de créatures du client Forever ne connaît aucune créature du marais (vérifié le
-- 14/11/2026 avec tools/wdb_creatures.py, caches _forever_, _classic_era_, _classic_, _anniversary_,
-- _retail_). Chaque entrée garde la créature de la fiche en tête (le client la demande au serveur), puis des
-- affichages de la même famille trouvés dans ces caches, notés « repli ». FileDataID des icônes confirmés par
-- wow_icon_search.
local _, ns = ...
local Art = ns.Art
local S = ns.Swamp

---------------------------------------------------------------------------
-- Ennemis
---------------------------------------------------------------------------
local CROC = { icon = 132187, tga = "Ability_Hunter_Pet_Crocolisk" }
local WHELP = { icon = 134157, tga = "INV_Misc_Head_Dragon_Green" }
local MURLOC = { icon = 134169, tga = "INV_Misc_Head_Murloc_01" }
local E = Art.enemies
-- Sawtooth Crocolisk (1082) ; repli : Wetlands Crocolisk (1036), Loch Crocolisk (1034), Large Loch (831)
-- (wide : cadre du modèle élargi, la queue d'un crocilisque de trois quarts sortait du cadre)
E.sawtooth_crocolisk = { creature = 1082, display = { 1036, 1034, 831 }, wide = 1.6, icon = CROC }
-- Dreaming Whelp (741) ; repli : Jade (1063, dragonnet vert du marais, 7975), Black Dragon Whelp (387)
E.dreaming_whelp = { creature = 741, display = { 7975, 387 }, scale = 0.85, icon = WHELP }
E.somnus_whelp = { creature = 741, display = { 7975, 387 }, scale = 0.8, icon = WHELP }
-- Swampwalker (764) ; repli : Timberling Mire Beast (863, bête des tourbières), Mirelow (631)
E.swampwalker = { creature = 764, display = { 863, 631 }, scale = 1.1,
  icon = { icon = 136100, tga = "Spell_Nature_StrangleVines" } }
-- Green Scalebane (744), Wyrmkin Dreamwalker (743) ; repli : Lord Captain Wyrmak (7976, dragonkin vert),
-- Flamescale Wyrmkin (8309)
E.green_scalebane = { creature = 744, display = { 7976, 8309 }, icon = WHELP }
E.wyrmkin_dreamwalker = { creature = 743, display = { 7976, 8309 }, icon = { icon = 136090, tga = "Spell_Nature_Sleep" } }
-- Marsh Oracle (752), Marsh Inkspewer (750) ; repli : Murloc Flesheater (506), Forager (441), Streamrunner (527)
E.marsh_oracle = { creature = 752, display = { 527, 506, 441 }, icon = MURLOC }
E.marsh_inkspewer = { creature = 750, display = { 506, 441, 983 }, icon = MURLOC }
-- Deathstrike Tarantula (769) ; repli : Greater Tarantula (520), Tarantula (366)
E.deathstrike_tarantula = { creature = 769, display = { 520, 366 }, icon = { icon = 132196, tga = "Ability_Hunter_Pet_Spider" } }
-- Lost Ones (759, 760) ; repli : Lost One Refugee (19162 : 11650, 152), Lost One Chieftain (10921)
E.lost_one_hunter = { creature = 759, display = { 11650, 152, 10921 }, icon = { icon = 135127, tga = "INV_Spear_04" } }
E.lost_one_muckdweller = { creature = 760, display = { 152, 11650 }, icon = { icon = 134227, tga = "INV_Misc_Horn_01" } }
-- Élites : Lost One Chieftain (763, 10921), Lord Captain Wyrmak (14445, 7976), Gilmorian (14447, 4920)
E.lost_one_chieftain = { creature = 763, display = 10921, scale = 1.15, icon = { icon = 135131, tga = "INV_Spear_08" } }
E.wyrmak = { creature = 14445, display = 7976, scale = 1.2, icon = WHELP }
E.gilmorian = { creature = 14447, display = 4920, scale = 1.15, icon = { icon = 1391617, tga = "INV_Misc_NagaMale" } }
-- Somnus (12900) ; repli : Sleeping Dragon (9417, 8574), Veridian Netherwing Drake (21522), Rogue Black Drake (6374)
E.somnus = { creature = 12900, display = { 8574, 21522, 6374 }, scale = 1.35,
  icon = { icon = 1354172, tga = "INV_Misc_Head_Dragon_Green_Nightmare" } }
Art.ui.mapBoss.swamp = E.somnus.icon -- boss du parcours : Somnus

---------------------------------------------------------------------------
-- Personnages des rencontres
---------------------------------------------------------------------------
local N = Art.npcs
-- Dispatch Commander Ruag (7623) ; repli : Orc Refugee (18559), Blackrock Grunt (6033)
N.dispatch_commander_ruag = { creature = 7623, display = { 18559, 6033 }, icon = { icon = 134170, tga = "INV_Misc_Head_Orc_01" } }
-- Fel'Zerul (1443, troll de Stonard) ; repli : Witherbark Troll (3986), Frostmane Troll (5608)
N.fel_zerul = { creature = 1443, display = { 3986, 5608 }, icon = { icon = 134177, tga = "INV_Misc_Head_Troll_01" } }
-- Galen Goodward (5391) ; repli : fermiers humains de la Marche (Ray 3614, Saldean 1943)
N.galen_goodward = { creature = 5391, display = { 3614, 1943 }, icon = { icon = 134166, tga = "INV_Misc_Head_Human_01" } }
-- Magtoor (1776) ; repli : Lost One Chieftain (10921), Lost One Refugee (152)
N.magtoor = { creature = 1776, display = { 10921, 152 }, icon = { icon = 236442, tga = "Achievement_Character_Draenei_Male" } }
-- Lost One Cook (1106, affichage 152 dans les caches)
N.lost_one_cook = { creature = 1106, display = { 152, 11650 }, icon = { icon = 134004, tga = "INV_Misc_Food_48" } }
-- pêcheur de Stonard (personnage sans créature propre) : repli Orc Refugee (19150 : 18559, 18556, 18557)
N.stonard_fisherman = { creature = 19150, display = { 18559, 18556, 18557 }, icon = { icon = 133888, tga = "INV_Misc_Fish_02" } }
-- rencontres sans personnage : on montre ce que le joueur voit (le Green Scalebane endormi sur les marches,
-- une Deathstrike Tarantula de la grotte de Cortello)
N.atalai_chest = { creature = 744, display = { 7976, 8309 }, icon = { icon = 132595, tga = "INV_Box_02" } }
-- (araignée : large et basse, de trois quarts dans le cadre étroit des PNJ, 170 × 200 : wide, Scene.setWide)
N.cortello_scroll = { creature = 769, display = { 520, 366 }, wide = 1.6, icon = { icon = 134939, tga = "INV_Scroll_03" } }

---------------------------------------------------------------------------
-- Cartes, bibelots, état, intentions
---------------------------------------------------------------------------
Art.cards.dream_dust = { icon = 132855, tga = "INV_Enchant_DustDream" }
Art.cards.dreamless_sleep_potion = { icon = 134802, tga = "INV_Potion_22" }

Art.relics.green_dragonscale = { icon = 134313, tga = "INV_Misc_MonsterScales_11" }
Art.relics.tender_crocolisk_meat = { icon = 134004, tga = "INV_Misc_Food_48" }
Art.relics.atalai_artifact = { icon = 134232, tga = "INV_Misc_Idol_03" }
Art.relics.chained_essence_of_eranikus = { icon = 136016, tga = "Spell_Nature_CorrosiveBreath" }
Art.relics.egg_of_hakkar = { icon = 134430, tga = "INV_Misc_ShadowEgg" }
Art.relics.essence_of_eranikus = { icon = 134104, tga = "INV_Misc_Gem_Emerald_01" }

local SLEEP = { icon = 136090, tga = "Spell_Nature_Sleep" }
Art.statuses.asleep = SLEEP
Art.statusShort.asleep = "skips its next N turns, damage wakes it up."

Art.intents.sleep = { icon = 136090, color = "defend", tga = "Spell_Nature_Sleep" }
Art.intents.lull = { icon = 136090, color = "watch", tga = "Spell_Nature_Sleep" }
Art.intents.alarm = { icon = 134227, color = "watch", tga = "INV_Misc_Horn_01" }
Art.intentName.sleep = "Asleep"
Art.intentName.lull = "Lull"
Art.intentName.alarm = "Alarm"

-- Chiffre de la bulle : Lull = PV rendus à la cible (rien sans cible), Alarm = dormeurs réveillés.
Art.intentParts.lull = function(c, e, a)
  if S.lullTarget(c, e) then return "+" .. (a.heal or 8) end
  return "-"
end
Art.intentParts.alarm = function(c, e) return "Wakes " .. S.asleepAllies(c, e) end
Art.intentParts.block_wounded = function(c, e, a) return "+" .. a[2] end

Art.actionText.lull = function(a, c, e)
  local t = S.lullTarget(c, e)
  local who = t and Art.enemyLabel(t) or "no target now"
  return "Puts its most wounded awake ally to sleep (Asleep " .. (a[2] or 2) .. ") and heals it "
    .. (a.heal or 8) .. ". Target: " .. who .. "."
end
Art.actionText.alarm = function(a, c, e)
  return "Wakes up all sleeping allies (" .. S.asleepAllies(c, e) .. " now). They act next turn."
end
Art.actionText.slumber = function(a) return "Falls asleep (Asleep " .. (a[2] or 2) .. ")." end
Art.actionText.block_wounded = function(a) return "Gives " .. a[2] .. " Absorb to its most wounded ally." end

function Art.enemyLabel(e)
  return ns.Combat.enemyName(e)
end

---------------------------------------------------------------------------
-- Vue de zone : dormeurs, ouvertures, Slumber
---------------------------------------------------------------------------
local function openerLine(c, e)
  local op = S.opener(e)
  local mv = op and ns.Combat.moveOf(e.id, op)
  if not mv then return "No opener: it resumes its usual moves." end
  local dmg
  for _, a in ipairs(mv.actions) do
    if a[1] == "attack" then
      dmg = ns.Combat.calcDamage(c, e, c.player, ns.Combat.enemyBase(c, e, a)) .. ((a.times or 1) > 1 and (" x" .. a.times) or "")
      break
    end
  end
  return "On waking: " .. mv.name .. (dmg and (" (" .. dmg .. ")") or "") .. "."
end

ns.ZoneViews.swamp = {
  intent = function(c, e)
    if S.asleep(e) then
      local n = e.st.asleep
      return { icon = Art.intents.sleep, key = "intent:sleep", text = "Asleep " .. n, color = "defend",
        title = "Asleep " .. n,
        tip = "Skips its next " .. n .. " turn" .. (n > 1 and "s" or "") .. ". Damage wakes it up.\n"
          .. "Rude Awakening: the first single-target hit on it deals +50%, and it acts this round.\n"
          .. "Hits to all and DoT wake it without the bonus: it acts next round.\n" .. openerLine(c, e) }
    end
    if e.intent == S.SLEEP then
      return { icon = Art.intents.sleep, key = "intent:sleep", text = "Waking", color = "watch",
        title = "Waking up", tip = "It woke up too late to act this round: it acts next turn.\n" .. openerLine(c, e) }
    end
    return nil
  end,

  -- ouverture annoncée (réveillé, pas encore jouée) : corne à droite du chiffre
  intentBadge = function(c, e)
    if S.pending(e) and e.intent == S.opener(e) then
      return { icon = SLEEP, key = "badge:opener", tip = "Opener: its first move after it wakes up." }
    end
    return nil
  end,

  -- fiche : sommeil (règle, tours restants, ouverture), Slumber (soin pendant le sommeil : compteur gardé sous le
  -- cadre), Lulled
  enemyInfo = function(c, e)
    local list = {}
    local s = e.zs and e.zs.swamp
    if S.asleep(e) then
      local n = e.st.asleep
      list[#list + 1] = { name = "Asleep", text = "skips its turns while asleep. Damage wakes it up. Rude Awakening: "
        .. "the first single-target hit on it deals 50% more, and it acts this round. Hits on all enemies and DoT wake "
        .. "it without the bonus: it acts next round.",
        lines = { { "Asleep for " .. n .. " more turn" .. (n > 1 and "s" or "") .. ". " .. openerLine(c, e), "defendText" } } }
    elseif e.intent == S.SLEEP then
      list[#list + 1] = { name = "Waking up", text = "it woke up too late to act this round: it acts next turn.",
        lines = { { openerLine(c, e), "defendText" } } }
    end
    if S.asleep(e) and s and (s.mend or 0) > 0 then
      list[#list + 1] = { name = "Slumber", text = "heals " .. s.mend .. " at each of its turns while asleep.",
        compact = { icon = Art.intents.heal, key = "badge:mend", text = "+" .. s.mend, color = "healText" } }
    end
    if s and s.lulled then
      list[#list + 1] = { name = "Lulled", text = "already put back to sleep once: Lull can't target it again." }
    end
    return list
  end,
}

---------------------------------------------------------------------------
-- Décors peints : Misty Valley (route), Fallow Sanctuary (camp), Stonard (marchand), marches du temple
-- (colline), nuit, Pool of Tears (boss), Misty Reed Strand (côte)
---------------------------------------------------------------------------
Art.palettes.swamp = {
  -- jour voilé : ciel gris-vert, brume jaunâtre à l'horizon, eau sombre, mousse et roseaux bruns
  sky = { "#5b7268", "#8c9e8a", "#c3c6a0" }, sun = "#e4e2c0", sunGlow = { "#e3dda6", 0.46 },
  cloud = { "#d9dcc7", 0.28 },
  hillsBack = "#6c7e6e", hillsFront = "#3e4f40", mound = "#4a5a45", moundLight = { "#7d8c63", 0.4 },
  trees = "#344232", haze = { "#b4bf9f", 0.62 },
  patches = { "#55674a", "#4a5c44", "#5e7052", "#4c5d46", "#596a4b" }, hedge = { "#232c1d", 0.4 },
  fieldsNear = { "#4a5937", "#262f1c" }, furrowDark = { "#161d11", 0.3 }, furrowLight = { "#7a8758", 0.12 },
  road = { "#6c6446", "#4b4330" }, roadEdge = "#30301f",
  water = { "#2f3f39", "#a3b39a" }, waterEdge = "#1b2416", moss = { "#6e7d45", 0.7 },
  far = { main = "#3e4c40", dark = "#2e3a30", wood = "#46503a" },
  mid = { main = "#2c2c1f", dark = "#1b1c13", wood = "#4f4630", crate = "#5c5235" },
  flag = "#8a2a1c", smoke = { "#cfd4c0", 0.45 },
  ground = { "#0e130b", 0.62 }, stalk = "#262d16", ears = { "#3e2b17", "#4c3620", "#33251a" },
}
Art.palettes.swamp_night = {
  night = true,
  sky = { "#070f12", "#13221f", "#2a3a32" }, moon = "#dfe6cf", moonGlow = { "#8fb09a", 0.3 },
  stars = "#e6eedc", cloud = { "#3f564c", 0.3 },
  hillsBack = "#18241f", hillsFront = "#16201b", mound = "#18221b", moundLight = { "#2f4237", 0.4 },
  trees = "#0f1813", haze = { "#3a5246", 0.45 },
  patches = { "#1f2a22", "#1b251e", "#222d24", "#1a231c", "#202a21" }, hedge = { "#080b08", 0.45 },
  fieldsNear = { "#1a2218", "#0b0f0a" }, furrowDark = { "#050705", 0.3 }, furrowLight = { "#3c4c3e", 0.1 },
  road = { "#2f3127", "#1e1f18" }, roadEdge = "#0f100b",
  water = { "#0f1916", "#4f6a5d" }, waterEdge = "#060906", moss = { "#24301d", 0.7 },
  far = { main = "#101814", dark = "#0b110e", light = "#e9b964" },
  mid = { main = "#0b0d09", dark = "#060705", wood = "#15160f", crate = "#1b1b13" },
  flag = "#2a120e", smoke = { "#4c5a52", 0.4 },
  ground = { "#020302", 0.66 }, stalk = "#0c0f08", ears = { "#17110b", "#1d150d", "#140f0a" },
}
-- Pool of Tears : même marais, lumière verte du temple englouti
Art.palettes.swamp_pool = setmetatable({
  sky = { "#3f5a54", "#6f8a7c", "#a9bd96" }, sun = "#e8f2c8", sunGlow = { "#bfe2a0", 0.45 },
  haze = { "#9fbf98", 0.66 }, water = { "#24413a", "#9fd0a8" },
  far = { main = "#4a5c4a", dark = "#2f3c31", light = "#9fe08a" },
}, { __index = Art.palettes.swamp })

-- lisière de saules et de cyprès sur l'horizon : rangée de bosses sombres serrées (suite fixe)
local CANOPY = {}
for i = 0, 15 do
  local h = math.sin(i * 12.9898) * 43758.5453
  h = h - math.floor(h)
  CANOPY[#CANOPY + 1] = { i * 70 - 10 + 20 * h, 70 + 70 * h, 9 + 16 * h }
end
---------------------------------------------------------------------------
-- Accessoires et mares du marais, peints par le plan « ground » de la zone (S.landscape, layers ; kit du
-- peintre S.paintKit) : arbres morts à mousse pendante, huttes des Lost Ones, huttes et tour de guet orques,
-- temple englouti, touffes de roseaux, mares à reflets. Entrée d'Art.paintings : `pools = { { cx, cy, l, h } }`,
-- `items = { { genre, x, y du pied, échelle, plan ("far" | "mid"), variante } }` ; palette : water, waterEdge, moss.
---------------------------------------------------------------------------
local sin, cos, floor, PI = math.sin, math.cos, math.floor, math.pi
local SP = {}
-- Arbre mort (marais) : fût penché, branches nues qui se divisent, mousse pendante (pal.moss), racines.
-- Variante 1 à 3 : forme des branches (suite fixe).
function SP.deadtree(K, f, g, P, c, pal, x, y, s, variant)
  local v = tonumber(variant) or 1
  local lean = (K.hash(v, 11) - 0.5) * 0.18
  local H = (88 + 30 * K.hash(v, 12)) * s
  local tx, ty = x + sin(lean) * H, y - cos(lean) * H
  -- racines et fût (plus épais en bas)
  K.bar(f, g, P[1], c.dark, x - 7 * s, y - 3 * s, 18 * s, 3 * s, 0.5)
  K.bar(f, g, P[1], c.dark, x + 8 * s, y - 3 * s, 20 * s, 3 * s, -0.45)
  K.bar(f, g, P[1], c.dark, (x + tx) / 2, (y + ty) / 2 - 2 * s, H, 7 * s, PI / 2 - lean)
  K.bar(f, g, P[1], c.dark, x + sin(lean) * H * 0.2, y - H * 0.2, H * 0.4, 10 * s, PI / 2 - lean)
  -- branches : trois étages, chacune avec une fourche
  for k = 1, 3 do
    local t = 0.45 + 0.17 * k
    local bx, by = x + sin(lean) * H * t, y - cos(lean) * H * t
    local side = ((k + v) % 2 == 0) and 1 or -1
    local a = PI / 2 - lean - side * (0.7 + 0.35 * K.hash(v * 7 + k, 13))
    local L = (34 - 6 * k + 14 * K.hash(v * 5 + k, 14)) * s
    local ex, ey = bx + cos(a) * L, by - sin(a) * L
    K.bar(f, g, P[2], c.dark, (bx + ex) / 2, (by + ey) / 2, L, (3.6 - 0.6 * k) * s, a)
    local a2 = a + side * 0.55
    K.bar(f, g, P[2], c.dark, ex + cos(a2) * 7 * s, ey - sin(a2) * 7 * s, 15 * s, 1.6 * s, a2)
    K.bar(f, g, P[2], c.dark, ex + cos(a - side * 0.4) * 6 * s, ey - sin(a - side * 0.4) * 6 * s, 12 * s, 1.4 * s, a - side * 0.4)
    -- mousse qui pend de la branche
    if pal.moss then
      for m = 1, 3 do
        local mx = bx + (ex - bx) * (0.3 + 0.25 * m)
        local my = by + (ey - by) * (0.3 + 0.25 * m)
        local ml = (10 + 12 * K.hash(v * 13 + k * 3 + m, 15)) * s
        K.bar(f, g, P[3], pal.moss[1], mx, my + ml / 2, ml, 1.4 * s, PI / 2, pal.moss[2])
      end
    end
  end
  -- cime cassée
  K.bar(f, g, P[2], c.dark, tx, ty - 6 * s, 14 * s, 3 * s, PI / 2 - lean - 0.3)
end

-- Hutte des Lost Ones (Fallow Sanctuary) : panse ronde en terre, toit de roseaux en cône, porte sombre.
function SP.hut(K, f, g, P, c, pal, x, y, s)
  K.oval(f, g, P[1], c.main, x, y - 16 * s, 58 * s, 36 * s)
  K.box(f, g, P[1], c.main, x - 29 * s, y - 16 * s, 58 * s, 16 * s)
  K.tri(f, g, P[2], c.wood, x, y - 26 * s, 74 * s, 40 * s)
  K.box(f, g, P[2], c.dark, x - 37 * s, y - 28 * s, 74 * s, 2.5 * s)
  K.oval(f, g, P[3], c.dark, x + 8 * s, y - 11 * s, 14 * s, 22 * s)
  K.box(f, g, P[3], c.dark, x + 1 * s, y - 11 * s, 14 * s, 11 * s)
  if c.light then K.box(f, g, P[3], c.light, x - 16 * s, y - 20 * s, 6 * s, 5 * s) end
end

-- Hutte orque de Stonard : murs de rondins, toit de peaux en triangle hérissé de piques, bannière.
function SP.orchut(K, f, g, P, c, pal, x, y, s)
  K.box(f, g, P[1], c.wood, x - 38 * s, y - 30 * s, 76 * s, 30 * s + 1)
  for i = 0, 5 do K.box(f, g, P[2], c.dark, x - 36 * s + i * 14.4 * s, y - 30 * s, 1.2 * s, 30 * s) end
  K.tri(f, g, P[2], c.main, x, y - 28 * s, 96 * s, 36 * s)
  for k = -1, 1, 2 do
    K.bar(f, g, P[3], c.dark, x + k * 40 * s, y - 34 * s, 22 * s, 2.4 * s, k * 0.75)
    K.bar(f, g, P[3], c.dark, x + k * 22 * s, y - 50 * s, 18 * s, 2 * s, k * 0.9)
  end
  K.box(f, g, P[3], c.dark, x - 8 * s, y - 20 * s, 16 * s, 20 * s)
  if c.light then K.box(f, g, P[3], c.light, x - 6 * s, y - 18 * s, 12 * s, 16 * s) end
  K.box(f, g, P[3], c.dark, x + 30 * s, y - 70 * s, 1.6 * s, 40 * s)
  K.box(f, g, P[3], pal.flag, x + 31.6 * s, y - 70 * s, 11 * s, 18 * s)
end

-- Tour de guet orque : quatre poteaux en biais, plate-forme, toit pointu hérissé.
function SP.watchtower(K, f, g, P, c, pal, x, y, s)
  K.bar(f, g, P[1], c.wood, x - 12 * s, y - 40 * s, 82 * s, 3 * s, PI / 2 - 0.12)
  K.bar(f, g, P[1], c.wood, x + 12 * s, y - 40 * s, 82 * s, 3 * s, PI / 2 + 0.12)
  K.bar(f, g, P[1], c.wood, x, y - 44 * s, 30 * s, 2 * s, 0.9)
  K.bar(f, g, P[1], c.wood, x, y - 44 * s, 30 * s, 2 * s, -0.9)
  K.box(f, g, P[2], c.main, x - 20 * s, y - 88 * s, 40 * s, 12 * s)
  K.tri(f, g, P[2], c.dark, x, y - 88 * s, 46 * s, 28 * s)
  for k = -1, 1, 2 do K.bar(f, g, P[3], c.dark, x + k * 24 * s, y - 90 * s, 14 * s, 1.8 * s, k * 0.6) end
  if c.light then K.box(f, g, P[3], c.light, x - 4 * s, y - 86 * s, 8 * s, 7 * s) end
end

-- Touffe de roseaux au bord d'une mare : tiges fines penchées (pal.stalk), massettes brunes (pal.ears).
function SP.reeds(K, f, g, P, c, pal, x, y, s, variant)
  local n = tonumber(variant) or 9
  for i = 1, n do
    local h1, h2, h3 = K.hash(x + i, 21), K.hash(y + i, 22), K.hash(i * 3 + x, 23)
    local bx = x + (h1 - 0.5) * 46 * s
    local L, lean = (22 + 26 * h2) * s, (h3 - 0.5) * 0.6
    local th = PI / 2 - lean
    K.bar(f, g, P[2], pal.stalk, bx + sin(lean) * L / 2, y - cos(lean) * L / 2, L, 1.3 * s, th)
    if h2 > 0.35 then
      local ear = K.oval(f, g, P[3], pal.ears[1 + floor(h1 * #pal.ears)], bx + sin(lean) * (L + 3 * s), y - cos(lean) * (L + 3 * s),
        8 * s, 3.4 * s)
      if ear.SetRotation then ear:SetRotation(th) end
    end
  end
end

-- Temple d'Atal'Hakkar à demi englouti : gradins de pierre moussue, sanctuaire au sommet, porte sombre.
function SP.temple(K, f, g, P, c, pal, x, y, s)
  local widths = { 230, 186, 144, 104 }
  local yy = y
  for i, w in ipairs(widths) do
    local h = 22 * s
    K.box(f, g, P[1], c.main, x - w / 2 * s, yy - h, w * s, h + 1)
    -- flanc droit à l'ombre (volume), arête claire du gradin, joints des blocs
    K.box(f, g, P[2], c.dark, x + w * 0.18 * s, yy - h, w * 0.32 * s, h + 1, 0.35)
    K.box(f, g, P[2], c.dark, x - w / 2 * s, yy - h, w * s, 2.2 * s)
    for j = 1, floor(w / 26) do
      K.box(f, g, P[2], c.dark, x - w / 2 * s + j * 26 * s, yy - h + 3 * s, 1 * s, h - 4 * s, 0.4)
    end
    if pal.moss then
      -- mousse en coulures fondues et lianes qui pendent des arêtes
      for m = 1, 3 do
        local mx = x - w / 2 * s + w * s * K.hash(i * 9 + m, 16)
        K.blur(f, g, P[2], pal.moss[1], mx, yy - h + 6 * s, (18 + 16 * K.hash(i + m, 17)) * s, (10 + 8 * K.hash(m, i)) * s, 0.55)
        local vl = (8 + 14 * K.hash(i * 5 + m, 24)) * s
        K.bar(f, g, P[3], pal.moss[1], mx + 6 * s, yy - h + 2 * s + vl / 2, vl, 1.2 * s, PI / 2, pal.moss[2])
      end
    end
    yy = yy - h
  end
  -- escalier central
  K.box(f, g, P[2], c.dark, x - 14 * s, yy, 28 * s, (y - yy), 0.35)
  for k = 1, 8 do K.box(f, g, P[3], c.main, x - 14 * s, yy + k * 11 * s, 28 * s, 1.4 * s, 0.5) end
  -- sanctuaire
  K.box(f, g, P[1], c.main, x - 34 * s, yy - 30 * s, 68 * s, 31 * s)
  K.box(f, g, P[2], c.dark, x - 38 * s, yy - 36 * s, 76 * s, 7 * s)
  K.box(f, g, P[3], c.dark, x - 10 * s, yy - 24 * s, 20 * s, 24 * s)
  if c.light then K.blur(f, g, P[3], c.light, x, yy - 12 * s, 44 * s, 30 * s, 0.55) end
end


local GROUND_W = { deadtree = 44, hut = 74, orchut = 96, watchtower = 54 }
local function swampGround(K, f, g, sp, pal)
  local LV = K.LV
  local wt = pal.water
  for i, p in ipairs(wt and sp.pools or {}) do
    local cx, cy, w, h = p[1], p[2], p[3], p[4]
    K.blur(f, g, LV.furrows, pal.waterEdge or wt[1], cx, cy + h * 0.1, w * 1.2, h * 1.7, 0.5)
    K.oval(f, g, LV.furrows, wt[1], cx, cy, w, h)
    K.oval(f, g, LV.furrows, K.mix(wt[1], wt[2], 0.35), cx - w * 0.04, cy - h * 0.12, w * 0.84, h * 0.6, 0.8)
    K.blur(f, g, LV.furrows, wt[2], cx - w * 0.08, cy - h * 0.22, w * 0.6, h * 0.5, 0.35)
    for k = 1, 4 do
      local yy2 = cy - h * 0.3 + h * 0.18 * k
      local ww = w * (0.18 + 0.32 * K.hash(i * 7 + k, 18))
      K.box(f, g, LV.furrows, wt[2], cx - w * 0.3 + w * 0.5 * K.hash(i + k, 19) - ww / 2, yy2, ww, 1.2, 0.35)
    end
  end
  for _, p in ipairs(sp.items or {}) do
    local kind, plan, s = p[1], p[5] or "mid", p[4] or 1
    if GROUND_W[kind] and plan == "mid" then
      K.blur(f, g, LV.furrows, pal.ground[1], p[2] + 6 * s, p[3] - 1, GROUND_W[kind] * s * 1.3, 14 * s, 0.55)
    end
    local fn = SP[kind]
    if fn then fn(K, f, g, LV[plan], pal[plan], pal, p[2], p[3], s, p[6]) end
  end
end
local SWAMP_LAYERS = { ground = swampGround }

local SW_SKY = {
  clouds = { { 160, 64, 300, 40 }, { 470, 36, 240, 28 }, { 760, 96, 320, 36 }, { 990, 52, 200, 26 } },
  hills = { back = { { 120, 520, 30 }, { 560, 640, 22 }, { 960, 540, 34 } }, front = CANOPY },
  trees = { { 40, 5 }, { 160, 3 }, { 290, 6 }, { 410, 4 }, { 540, 5 }, { 650, 3 }, { 770, 6 }, { 880, 4 }, { 1010, 5 } },
}
local function swamp(t, pal)
  t.pal, t.horizon, t.field = pal or "swamp", t.horizon or 198, t.field or 232
  t.clouds, t.hills, t.trees = t.clouds or SW_SKY.clouds, t.hills or SW_SKY.hills, t.trees or SW_SKY.trees
  t.furrows = false
  t.layers = SWAMP_LAYERS
  -- accessoires du marais (plan « ground » de la zone) ; les accessoires communs (cart, smoke) restent à props
  local props, items = {}, {}
  for _, p in ipairs(t.props or {}) do
    if SP[p[1]] then items[#items + 1] = p else props[#props + 1] = p end
  end
  t.props, t.items = props, items
  t.shadows = t.shadows or { { 260, 300, 520, 50 }, { 840, 262, 420, 30 } }
  return t
end
-- arbres morts du plan lointain (x, y du pied, échelle, variante) et du plan moyen
local function trees(list, plan)
  local out = {}
  for _, t in ipairs(list) do out[#out + 1] = { "deadtree", t[1], t[2], t[3], plan or "far", t[4] } end
  return out
end
local function concat(...)
  local out = {}
  for _, l in ipairs({ ... }) do for _, x in ipairs(l) do out[#out + 1] = x end end
  return out
end

-- arbres morts minuscules sur la ligne des mares lointaines (profondeur)
local FAR = trees({ { 30, 232, 0.28, 1 }, { 180, 230, 0.32, 3 }, { 240, 233, 0.25, 2 }, { 470, 231, 0.3, 1 },
  { 610, 232, 0.27, 2 }, { 780, 230, 0.33, 3 }, { 840, 233, 0.26, 1 }, { 1000, 231, 0.3, 2 } })
local function reeds(list)
  local out = {}
  for _, r in ipairs(list) do out[#out + 1] = { "reeds", r[1], r[2], r[3], "mid", r[4] } end
  return out
end
local ROAD_TREES = concat(FAR, reeds({ { 380, 306, 0.9, 8 }, { 110, 300, 0.8, 7 }, { 990, 344, 1.0, 9 }, { 700, 256, 0.55, 6 } }),
  trees({ { 96, 232, 0.55, 1 }, { 300, 232, 0.45, 2 }, { 690, 232, 0.5, 3 }, { 930, 232, 0.6, 2 } }),
  trees({ { 70, 320, 1.15, 3 }, { 980, 304, 1.0, 1 } }, "mid"))
local ROAD_POOLS = { { 230, 300, 300, 34 }, { 860, 340, 260, 30 }, { 760, 252, 170, 12 }, { 340, 252, 140, 10 } }
local REEDS = { { -6, 140, 30 }, { 900, 1040, 28 } }

Art.paintings = Art.paintings or {}
local P = Art.paintings
-- Misty Valley : piste de boue entre les mares, arbres morts, roseaux au premier plan
P.swamp_road = swamp({ sun = { 812, 86, 20 }, road = { 560, 500, 10, 330, -90 }, pools = ROAD_POOLS,
  props = ROAD_TREES, wheat = REEDS })
P.swamp_night = swamp({ moon = { 820, 72, 17 }, road = { 560, 500, 10, 330, -90 }, pools = ROAD_POOLS,
  props = ROAD_TREES, wheat = REEDS }, "swamp_night")
-- Fallow Sanctuary : huttes des Lost Ones sur la berge, foyer, arbres morts
P.swamp_camp = swamp({ sun = { 880, 92, 18 }, pools = { { 820, 320, 340, 34 }, { 160, 254, 200, 12 } },
  props = concat(FAR, trees({ { 120, 232, 0.5, 2 }, { 980, 232, 0.55, 1 } }), reeds({ { 680, 316, 0.9, 8 }, { 960, 324, 0.9, 8 } }),
    { { "hut", 560, 236, 0.75, "far" }, { "hut", 300, 290, 1.25, "mid" }, { "hut", 468, 268, 0.95, "mid" },
      { "smoke", 392, 300, 1.0, "mid" } },
    trees({ { 660, 300, 1.05, 3 }, { 40, 330, 1.2, 1 } }, "mid")),
  wheat = REEDS })
-- Stonard : huttes orques, tour de guet, bannière de la Horde, charrette de caisses
P.swamp_shop = swamp({ sun = { 860, 80, 20 }, road = { 470, 640, 8, 290, 40 }, pools = { { 170, 320, 260, 30 } },
  props = concat(FAR, trees({ { 60, 232, 0.5, 3 }, { 990, 232, 0.55, 2 } }), reeds({ { 300, 318, 0.9, 8 }, { 40, 322, 0.8, 7 } }),
    { { "watchtower", 260, 232, 0.9, "far" }, { "orchut", 380, 232, 0.8, "far" }, { "orchut", 860, 236, 0.95, "far" },
      { "cart", 750, 300, 1.25, "mid", "crates" }, { "orchut", 140, 286, 1.2, "mid" } }),
  wheat = REEDS })
-- Marches du temple d'Atal'Hakkar : le temple englouti au fond de l'eau, arbres morts
P.swamp_temple = swamp({ sun = { 200, 80, 20 }, horizon = 190, field = 236,
  pools = { { 520, 256, 560, 22 }, { 220, 320, 280, 30 }, { 880, 330, 240, 28 } },
  props = concat(FAR, { { "temple", 520, 250, 0.85, "far" } }, reeds({ { 280, 258, 0.6, 7 }, { 770, 260, 0.6, 7 },
    { 340, 318, 0.9, 8 }, { 760, 332, 0.9, 8 } }),
    trees({ { 160, 232, 0.6, 1 }, { 860, 232, 0.55, 3 } }), trees({ { 50, 320, 1.1, 2 }, { 990, 310, 1.05, 3 } }, "mid")),
  wheat = REEDS })
-- Pool of Tears : la grande mare au pied du temple, lumière verte
P.swamp_pool = swamp({ sun = { 520, 70, 16 }, horizon = 186, field = 228,
  pools = { { 517, 310, 820, 80 }, { 140, 250, 200, 12 }, { 900, 250, 220, 12 } },
  props = concat(FAR, { { "temple", 517, 246, 0.95, "far" } }, reeds({ { 150, 318, 1.0, 9 }, { 880, 322, 1.0, 9 },
    { 240, 254, 0.55, 6 }, { 800, 254, 0.55, 6 } }),
    trees({ { 90, 232, 0.6, 2 }, { 940, 232, 0.6, 1 } }), trees({ { 30, 330, 1.2, 3 }, { 1010, 320, 1.15, 1 } }, "mid")),
  wheat = { { -6, 120, 26 }, { 916, 1040, 26 } } }, "swamp_pool")
-- Misty Reed Strand : la côte, eau jusqu'à l'horizon, roseaux
P.swamp_strand = swamp({ sun = { 300, 90, 22 }, hills = { back = { { 900, 380, 18 } } }, trees = { { 960, 3 } },
  pools = { { 517, 214, 1300, 34 }, { 300, 290, 420, 30 }, { 820, 330, 300, 26 } },
  props = concat(trees({ { 1000, 232, 0.55, 2 } }), trees({ { 960, 312, 1.1, 3 } }, "mid"),
    reeds({ { 480, 296, 0.9, 9 }, { 140, 300, 0.9, 8 }, { 700, 336, 1.0, 9 } })),
  wheat = { { -6, 260, 44 }, { 880, 1040, 24 } } })

Art.scenes.swamp_road = { paint = "swamp_road" }
Art.scenes.swamp_night = { paint = "swamp_night" }
Art.scenes.swamp_camp = { paint = "swamp_camp" }
Art.scenes.swamp_shop = { paint = "swamp_shop" }
Art.scenes.swamp_temple = { paint = "swamp_temple" }
Art.scenes.swamp_pool = { paint = "swamp_pool" }
Art.scenes.swamp_strand = { paint = "swamp_strand" }
