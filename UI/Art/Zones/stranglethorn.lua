-- Art de la zone Stranglethorn Vale (`stranglethorn`) : modèles des ennemis (Art.enemies), personnages des
-- rencontres (Art.npcs), icônes (cartes, bibelots, intention Hex, case Gurubashi Arena), vue de zone
-- ns.ZoneViews.stranglethorn (carte visée par un Hex, lanceurs, Death Hex, cartes Hexed) et décors peints de la
-- jungle (Art.paintings, peints par la zone avec les formes du peintre, UI/Scene.lua S.paintKit). Guide :
-- docs/zones.md ; fiche : docs/zones/stranglethorn.md.
local _, ns = ...

local Art = ns.Art

local function I(tga)
  return { tga = tga, icon = "Interface\\Icons\\" .. tga:lower() }
end

---------------------------------------------------------------------------
-- Modèles. Candidats dans l'ordre (UI/Scene.lua, S.loadModel) : la créature de la version classique (identifiant
-- de mémoire, absente des caches du client Forever : le client la demande au serveur), puis des affichages de la
-- même famille relevés dans le cache du client (tools/wdb_creatures.py, 13/11/2026, « repli »), puis le fichier
-- de modèle de la fiche (FileDataID de wow_model_search, sans les peaux propres), puis le médaillon.
---------------------------------------------------------------------------

-- replis du cache : trolls Witherbark (2552 : 3986, 3990), Frostmane (1120 : 5608), Frostmane Headhunter
-- (1123 : 5626) ; Young Panther (683 : 2437) ; Highland Lashtail (1016 : 673), Mottled Raptor (1020 : 960),
-- Highland Raptor (1015 : 138620) ; Young Stranglethorn Tiger (681 : 138617) ; Tigre (252489 : 5556, frFR) ;
-- Daggerspine Shorehunter (2369 : 11255), Naga Siren (10956 : 11263) ; Defias Pirate (657 : 2347, 2348) ;
-- Bart Tidewater (1481 : 4429) ; Insane Ghoul (511 : 828), Disturbed Ghoul (264551 : 569) ; totems Healing
-- Stream (3527 : 4587), Grounding (5925 : 4590), Stoneclaw (3579 : 4588).
local TROLL = { 3986, 3990, 5608 }
Art.enemies.bloodscalp_witch_doctor = { creature = 660, display = TROLL, files = { { 126248, "jungle troll caster" } },
  icon = I("INV_Misc_Head_Troll_01") }
Art.enemies.skullsplitter_mystic = { creature = 780, display = { 3990, 3986, 5608 }, files = { { 126248, "jungle troll caster" } },
  icon = I("INV_Misc_Head_Troll_02") }
Art.enemies.bloodscalp_headhunter = { creature = 671, display = { 5626, 3986, 3990 }, files = { { 126244, "troll" } },
  icon = I("INV_Spear_04") }
-- Zanzil Naga : créature de la version classique inconnue ; repli : Daggerspine Shorehunter (naga mâle, cache)
Art.enemies.zanzil_naga = { creature = 2369, display = { 11255, 11263 }, files = { { 125078, "naga male" } },
  icon = I("Achievement_Boss_EliteNagaMale") }
Art.enemies.shadowmaw_panther = { creature = 684, display = { 2437 }, files = { { 126171, "tiger" } },
  icon = I("Ability_Mount_BlackPanther") }
Art.enemies.lashtail_raptor = { creature = 686, display = { 673, 960, 138620 }, files = { { 125559, "raptor" } },
  icon = I("Ability_Hunter_Pet_Raptor") }
-- Mistvale Gorilla : aucun singe dans les caches ; 837 = affichage de mémoire (non vérifiable hors jeu)
Art.enemies.mistvale_gorilla = { creature = 1557, display = { 837 }, files = { { 124263, "gorilla" } }, scale = 1.1,
  icon = I("Ability_Hunter_Pet_Gorilla") }
Art.enemies.bloodsail_swashbuckler = { creature = 1563, display = { 2347, 2348, 4429 },
  icon = I("INV_Misc_Bandana_01") }
Art.enemies.king_bangalash = { creature = 731, display = { 5556, 138617 }, files = { { 126171, "tiger" } }, scale = 1.25,
  icon = I("Ability_Mount_JungleTiger") }
Art.enemies.young_stranglethorn_tiger = { creature = 681, display = { 138617, 5556 }, files = { { 126173, "tiger cub" } },
  scale = 0.85, icon = I("Ability_Mount_JungleTiger") }
Art.enemies.mokk_the_savage = { creature = 1514, display = { 837 }, files = { { 124263, "gorilla" } }, scale = 1.3,
  icon = I("Ability_Hunter_Pet_Gorilla") }
Art.enemies.zanzil_the_outcast = { creature = 2534, display = { 3990, 3986 }, files = { { 126248, "jungle troll caster" } },
  scale = 1.15, icon = I("Achievement_ZulGurub_Zanzil") }
Art.enemies.zanzil_zombie = { creature = 1488, display = { 828, 569 }, files = { { 126570, "zombie" } },
  icon = I("Spell_Shadow_RaiseDead") }
-- Jin'do the Hexxer (11380) ; repli : trolls du cache, puis le modèle du chef troll de la jungle
Art.enemies.jindo = { creature = 11380, display = { 3990, 3986 }, files = { { 126247, "jungle troll boss" } }, scale = 1.25,
  icon = I("Achievement_ZulGurub_Jindo") }
Art.enemies.healing_ward = { creature = 14987, display = { 4587 }, files = { { 126018, "healing totem" } }, scale = 0.9,
  icon = I("Spell_Nature_HealingWaveGreater") }
Art.enemies.brain_wash_totem = { creature = 15112, display = { 4590, 4588 }, files = { { 967881, "orc totem" } }, scale = 0.9,
  icon = I("Spell_Shadow_ShadowWordDominate") }

-- Personnages des rencontres (créature de la version classique, puis replis du cache).
-- Gobelins : Capitaine Vertepeau (647 : 7113, frFR), Ingénieur gobelin (622 : 7109), Artisan gobelin (1731 : 7110),
-- Sculpteur gobelin (641 : 7111), Constructeur naval gobelin (3947 : 7112), Cogneur de Baie-du-Butin (4624 : 7102).
-- Nains : Grif Wildheart (1231 : 3558), Torren Squarejaw (1153 : 1656), Jern Hornhelm (1105 : 1572).
Art.npcs.hemet_nesingwary = { creature = 715, display = { 3558, 1656, 1572 }, icon = I("Achievement_Character_Dwarf_Male") }
Art.npcs.ajeck_rouack = { creature = 717, display = { 2372, 4429, 2347 }, icon = I("INV_Weapon_Rifle_04") }
Art.npcs.baron_revilgaz = { creature = 2496, display = { 7113, 7109, 7102 }, icon = I("INV_Misc_Coin_02") }
Art.npcs.riggle_bassbait = { creature = 15077, display = { 7110, 7111, 7112 }, icon = I("INV_Fishingpole_02") }
Art.npcs.fleet_master_seahorn = { creature = 2487, display = { 7113, 7112, 4429 }, icon = I("INV_Misc_Ammo_Gunpowder_01") }
Art.npcs.rinwosho = { creature = 14921, display = { 3990, 3986, 5608 }, icon = I("Achievement_Character_Troll_Male") }
Art.npcs.witch_doctor_unbagwa = { creature = 1449, display = { 3986, 5626, 5608 }, icon = I("INV_Misc_Head_Troll_02") }
-- Surveyor Brannock (inventé, fiche) : un nain de la Ligue des explorateurs du cache, Torren Squarejaw (1153)
Art.npcs.explorer_dwarf = { creature = 1153, display = { 1656, 1572, 3558 }, icon = I("INV_Misc_Head_Dwarf_01") }
Art.npcs.short_john_mithril = { creature = 14508, display = { 4429, 2347, 7113 }, icon = I("ACHIEVEMENT_ARENA_2V2_1") }

---------------------------------------------------------------------------
-- Icônes : cartes, bibelots, intention, case de parcours
---------------------------------------------------------------------------

local HEX_ICON = I("Spell_Shaman_Hex")
local DEATH_HEX_ICON = I("Spell_Shadow_CurseOfMannoroth")

Art.cards.hexed = HEX_ICON
Art.cards.jungle_remedy = I("INV_Potion_12")
Art.cards.rumsey_rum_black_label = I("INV_Drink_04")

Art.relics.green_hills_of_stranglethorn = I("INV_Misc_Book_09")
Art.relics.shrunken_head = I("INV_Misc_Head_Troll_01")
Art.relics.gorilla_fang = I("INV_Misc_MonsterFang_01")
Art.relics.nesingwary_4000 = I("INV_Weapon_Rifle_04")
Art.relics.jindos_bag_of_whammies = I("INV_Misc_Bag_10_Green")
Art.relics.zandalarian_hero_charm = I("INV_ZulGurubTrinket")

Art.intents.hex = { tga = "Spell_Shaman_Hex", icon = "Interface\\Icons\\spell_shaman_hex", color = "watch" }
Art.intentName.hex = "Hex"
Art.ui.map.gurubashi_arena = I("ACHIEVEMENT_ARENA_2V2_1")

---------------------------------------------------------------------------
-- Vue de zone : ce que le Hex va faire, lisible avant de jouer
---------------------------------------------------------------------------

local function ST() return ns.Stranglethorn end

-- Carte visée par chaque lanceur (même calcul que le verrouillage : ns.Stranglethorn.plan).
local function targetOf(c, e)
  for _, p in ipairs(ST().plan(c)) do
    if p.enemy == e then return p.index and c.hand[p.index] or false end
  end
  return nil
end

local function cardName(inst) return ns.Card.def(inst).name end
local function short(s, n) if #s > n then return s:sub(1, n - 1) .. "." end return s end

-- Chiffre de la bulle : « Hex » ; infobulle : la carte visée.
Art.intentParts.hex = function() return "Hex" end
Art.actionText.hex = function(a, c, e)
  if not c or not e then return nil end
  local inst = targetOf(c, e)
  if inst then return "Target now: " .. cardName(inst) .. ". It changes as you play cards." end
  if inst == false then return "Your hand is empty: the hex will find no card." end
  return nil
end

ns.ZoneViews.stranglethorn = {
  -- carte visée : liseré vert et icône du Hex, en direct
  handMark = function(c, i, inst)
    for _, p in ipairs(ST().plan(c)) do
      if p.index == i then
        return { rim = { 0.36, 1, 0.42, 1 }, icon = HEX_ICON, key = "hex:mark",
          tip = "Hex: " .. ns.Combat.enemyName(p.enemy) .. " turns this card into a Hexed card at the end of your "
            .. "turn. Play it, or interrupt or stun the caster." }
      end
    end
    return nil
  end,
  -- sous l'intention : la carte visée (lanceur), ou le Death Hex du Zanzil Naga
  enemyBadges = function(c, e)
    local def = ns.Enemies[e.id]
    local list = {}
    local inst
    if ST().hexing(c, e) then inst = targetOf(c, e) end
    if inst then
      list[#list + 1] = { icon = HEX_ICON, text = short(cardName(inst), 16), color = "watchText",
        tip = "Hex target: " .. cardName(inst) .. ", the costliest card left in your hand." }
    elseif inst == false then
      list[#list + 1] = { icon = HEX_ICON, text = "No card", dim = true, tip = "Your hand is empty: the hex will fail." }
    end
    if def.deathHex then
      list[#list + 1] = { icon = DEATH_HEX_ICON, text = "Death Hex", color = "watchText",
        tip = "On death: hexes the costliest card in your hand." }
    end
    return #list > 0 and list or nil
  end,
  -- cartes Hexed du combat (Take a Trophy en dépend)
  counter = function(c)
    local n = ST().hexedCount(c)
    if n == 0 then return nil end
    return { icon = HEX_ICON, text = n .. " Hexed", hot = true, key = "hex:counter",
      tip = "Hexed cards in your piles. Play one (1 mana) to get its card back in hand." }
  end,
}

---------------------------------------------------------------------------
-- Décors peints : la jungle (route, campement de Nesingwary, nuit), Booty Bay (côte et marchand), ruines trolls
-- (rencontres, colline), portes de Zul'Gurub (boss). Peints ici avec les formes du peintre (S.paintKit, UI/Scene.lua) :
-- ciel humide, collines boisées en plans brumeux, rangées de canopée de plus en plus sombres, palmiers, sous-bois au
-- pied de la canopée, sol de latérite moussu, feuilles et lianes du premier plan. Rien de tiré au hasard (K.hash).
---------------------------------------------------------------------------

-- Couches (sous l'illustration, BORDER 0) : un plan par couleur ; à niveau égal, seulement des formes de même
-- couleur ou des voiles translucides (l'ordre du client à niveau égal n'est pas garanti).
local LV = {
  sky = { "BACKGROUND", -8 }, glow = { "BACKGROUND", -7 }, orb = { "BACKGROUND", -6 },
  mtnBack = { "BACKGROUND", -5 }, mtnFront = { "BACKGROUND", -4 }, mtnHaze = { "BACKGROUND", -3 },
  canFar = { "BACKGROUND", -2 }, canFarHi = { "BACKGROUND", -1 },
  canMid = { "BACKGROUND", 0 }, canMidHi = { "BACKGROUND", 1 }, trunk = { "BACKGROUND", 2 }, crown = { "BACKGROUND", 3 },
  mist = { "BACKGROUND", 4 }, ground = { "BACKGROUND", 5 }, groundHi = { "BACKGROUND", 6 }, road = { "BACKGROUND", 7 },
  shrub = { "BORDER", -8 }, shrubHi = { "BORDER", -7 },
  p1 = { "BORDER", -6 }, p2 = { "BORDER", -5 }, p3 = { "BORDER", -4 },
  veil = { "BORDER", -3 }, leaf = { "BORDER", -2 }, top = { "BORDER", -1 },
}
local PROP_LV = { LV.p1, LV.p2, LV.p3 }

local sin, cos, floor, PI, sqrt, atan2 = math.sin, math.cos, math.floor, math.pi, math.sqrt, math.atan2

local function painter(f, g, K, pal)
  local P = {}
  local hash = K.hash
  -- segment de (x1, y1) à (x2, y2), épaisseur th
  function P.seg(lv, c, x1, y1, x2, y2, th, a)
    local dx, dy = x2 - x1, y2 - y1
    return K.bar(f, g, lv, c, (x1 + x2) / 2, (y1 + y2) / 2, sqrt(dx * dx + dy * dy) + 0.6, th, atan2(-dy, dx), a)
  end
  -- feuille (ovale allongé tourné) partant de (x, y) dans la direction ang (radians, sens trigonométrique)
  function P.leaf(lv, c, x, y, len, wid, ang, a)
    local t = K.oval(f, g, lv, c, x + cos(ang) * len / 2, y - sin(ang) * len / 2, len, wid, a)
    if t.SetRotation then t:SetRotation(ang) end
    return t
  end
  -- couronne d'arbre : quatre lobes de même couleur
  function P.crown(lv, c, x, y, r, few)
    K.oval(f, g, lv, c, x, y, 2.1 * r, 1.45 * r)
    K.oval(f, g, lv, c, x - 0.8 * r, y + 0.22 * r, 1.4 * r, 1.1 * r)
    K.oval(f, g, lv, c, x + 0.6 * r, y - 0.4 * r, 1.35 * r, 1.1 * r)
    if not few then K.oval(f, g, lv, c, x - 0.15 * r, y - 0.62 * r, 1.1 * r, 0.9 * r) end
  end
  -- rangée de canopée : couronnes de tailles variées le long d'une ligne ondulée, masse pleine dessous, lumière
  -- sur le haut des couronnes (voile)
  function P.canopy(lv, lvHi, c, hi, y, yb, r, seed, amp, few)
    local x, k = -r, 0
    while x < K.W + r do
      k = k + 1
      local big = hash(seed + k, 4) > 0.82
      local rr = r * (0.7 + 0.5 * hash(seed + k, 1)) * (big and 1.45 or 1)
      local yy = y + (amp or 10) * sin(x * 0.009 + seed) + 10 * (hash(seed + k, 2) - 0.5) - (big and 0.5 * rr or 0)
      P.crown(lv, c, x, yy, rr, few)
      if hi and (not few or k % 2 == 0) then K.blur(f, g, lvHi, hi[1], x - 0.3 * rr, yy - 0.55 * rr, 1.6 * rr, 0.85 * rr, hi[2]) end
      x = x + rr * (1.05 + 0.4 * hash(seed + k, 3))
    end
    K.box(f, g, lv, c, 0, y, K.W, yb - y)
  end
  -- palmier : tronc en courbe, palmes tombantes (deux feuilles par palme)
  function P.palm(x, y, h, lean, s, cT, cF, lvT, lvF)
    local n, px, py = 6, x, y
    for i = 1, n do
      local t = i / n
      local nx, ny = x + lean * h * t ^ 1.7, y - h * t
      P.seg(lvT, cT, px, py, nx, ny, (6.5 - 2.8 * t) * s)
      px, py = nx, ny
    end
    for k = 0, 6 do
      local a = PI / 2 + (k - 3) * 0.5 + 0.12 * sin(k * 2.3 + x)
      local droop = 0.5 + 0.3 * hash(k + floor(x), 4)
      local L = (36 + 12 * hash(k + floor(x), 5)) * s
      local side = (a > PI / 2) and 1 or -1
      local a1 = a - side * 0.05
      local ex, ey = px + cos(a1) * L * 0.55, py - sin(a1) * L * 0.55
      P.leaf(lvF, cF, px, py, L * 0.62, 7.5 * s, a1)
      P.leaf(lvF, cF, ex, ey, L * 0.6, 6 * s, math.abs(a - PI / 2) < 0.1 and a1 or a1 + side * droop)
    end
  end
  -- grand arbre émergent : tronc évasé, branches, couronne en trois nuages
  function P.tree(x, y, h, r, cT, cC, lvT, lvC, hi)
    P.seg(lvT, cT, x - 5, y, x + 2, y - h, 10)
    P.seg(lvT, cT, x - 10, y, x - 2, y - 14, 6)
    P.seg(lvT, cT, x + 1, y - h * 0.7, x - r * 0.75, y - h - r * 0.05, 4)
    P.seg(lvT, cT, x + 1, y - h * 0.78, x + r * 0.8, y - h - r * 0.15, 4)
    P.crown(lvC, cC, x - r * 0.55, y - h, r * 0.75)
    P.crown(lvC, cC, x + r * 0.6, y - h - r * 0.1, r * 0.7)
    P.crown(lvC, cC, x, y - h - r * 0.5, r * 0.85)
    if hi then K.blur(f, g, LV.mist, hi[1], x - r * 0.25, y - h - r * 0.9, 1.8 * r, r * 0.8, hi[2]) end
  end
  -- buisson du sous-bois : lobes sombres, feuilles dressées, lumière sur le dessus
  function P.bush(x, y, r, seed)
    local c = pal.shrub
    K.oval(f, g, LV.shrub, c, x, y - r * 0.45, 2.2 * r, 1.1 * r)
    K.oval(f, g, LV.shrub, c, x - 0.7 * r, y - r * 0.7, 1.2 * r, 1.0 * r)
    K.oval(f, g, LV.shrub, c, x + 0.55 * r, y - r * 0.85, 1.3 * r, 1.1 * r)
    for j = 1, 2 do
      local a = PI / 2 + (j - 1.5) * 1.1 + 0.3 * (hash(seed + j, 14) - 0.5)
      P.leaf(LV.shrub, c, x + (j - 1.5) * r * 0.8, y - r * 0.6, r * (1.1 + 0.5 * hash(seed + j, 15)), r * 0.35, a)
    end
    K.blur(f, g, LV.shrubHi, pal.shrubHi[1], x - 0.2 * r, y - r * 1.05, 1.8 * r, 0.7 * r, pal.shrubHi[2])
  end
  -- sous-bois au pied de la canopée : rangée de buissons (trouée laissée au chemin)
  function P.undergrowth(y, gap, seed, size)
    local x, k = -10, 0
    while x < K.W + 10 do
      k = k + 1
      local r = (size or 15) * (0.7 + 0.7 * hash(seed + k, 16))
      if not (gap and math.abs(x - gap[1]) < gap[2] + r) then P.bush(x, y + 6 * hash(seed + k, 17), r, seed + k * 7) end
      x = x + r * (1.5 + 0.9 * hash(seed + k, 18))
    end
  end
  -- touffe du premier plan : feuilles en éventail depuis un pied, nervure claire (voile)
  function P.fronds(x, y, s, a0, a1, n, seed)
    for i = 1, n do
      local t = (i - 0.5) / n
      local a = a0 + (a1 - a0) * t + 0.12 * (hash(seed + i, 6) - 0.5)
      local L = (74 + 56 * hash(seed + i, 7)) * s
      local wid = (17 + 12 * hash(seed + i, 8)) * s
      P.leaf(LV.leaf, pal.leaf, x, y, L, wid, a)
      P.seg(LV.top, pal.leafRib[1], x, y, x + cos(a) * L * 0.86, y - sin(a) * L * 0.86, 1.4 * s, pal.leafRib[2])
    end
  end
  -- liane qui pend du haut (même couleur et même couche que les feuilles du cadre)
  function P.vine(x, len, s, seed)
    local px, py = x, -4
    local n = floor(len / 16)
    for i = 1, n do
      local nx, ny = x + 7 * sin(i * 0.7 + seed), -4 + i * 16
      P.seg(LV.leaf, pal.leaf, px, py, nx, ny, 2.2 * s)
      if i % 2 == 0 then P.leaf(LV.leaf, pal.leaf, nx, ny, 14 * s, 6.5 * s, (i % 4 == 0) and 0.4 or (PI - 0.4)) end
      px, py = nx, ny
    end
  end
  -- feuillage qui retombe du haut de l'image
  function P.overhang(x0, x1, seed)
    for i = 0, floor((x1 - x0) / 30) do
      local x = x0 + i * 30 + 10 * hash(seed + i, 9)
      local a = -PI / 2 + 0.55 * (hash(seed + i, 10) - 0.5)
      P.leaf(LV.leaf, pal.leaf, x, -16, 56 + 34 * hash(seed + i, 11), 15 + 6 * hash(seed + i, 12), a)
    end
  end
  -- mousse sur la pierre (voiles verts)
  local function moss(lv, x, y, w, h, seed)
    if not pal.moss then return end
    for i = 1, 3 do
      K.blur(f, g, lv, pal.moss[1], x + w * (hash(seed + i, 12) - 0.5) * 0.9, y + h * hash(seed + i, 13) * 0.6,
        w * 0.45, h * 0.18 + 6, pal.moss[2])
    end
  end
  -- pyramide à degrés des trolls : gradins éclairés à gauche, escalier central, temple, mousse
  function P.ziggurat(x, y, w, h, n, lvs)
    local hh = h / n
    for i = 0, n - 1 do
      local ww = w * (1 - i * 0.62 / n)
      local yy = y - (i + 1) * hh
      K.box(f, g, lvs[1], pal.stone, x - ww / 2, yy, ww, hh + 0.6)
      K.box(f, g, lvs[2], pal.stoneDark, x + ww / 2 - ww * 0.17, yy, ww * 0.17, hh + 0.6)
      K.box(f, g, lvs[2], pal.stoneDark, x - ww / 2, yy + hh - 3, ww, 3)
      K.box(f, g, lvs[3], pal.stoneLight, x - ww / 2, yy, ww * 0.83, 2)
    end
    local sw = w * 0.16
    K.box(f, g, lvs[2], pal.stoneDark, x - sw / 2, y - h, sw, h)
    for i = 1, n * 2 do K.box(f, g, lvs[3], pal.stoneLight, x - sw / 2, y - i * h / (n * 2), sw, 1.4, 0.5) end
    local tw, th = w * 0.3, h * 0.24
    K.box(f, g, lvs[1], pal.stone, x - tw / 2, y - h - th, tw, th + 0.6)
    K.box(f, g, lvs[2], pal.stoneDark, x - tw * 0.18, y - h - th * 0.75, tw * 0.36, th * 0.75)
    K.box(f, g, lvs[3], pal.stoneLight, x - tw / 2 - 4, y - h - th - 4, tw + 8, 4)
    moss(lvs[3], x - w * 0.15, y - h * 0.9, w * 0.8, h, floor(x))
    K.blur(f, g, LV.groundHi, pal.groundDark[1], x, y - 2, w * 1.1, 26, 0.6)
  end
  -- colonne : fût, face à l'ombre, chapiteau ; brisée : morceau penché
  function P.pillar(x, y, h, w, broken, lvs)
    K.box(f, g, lvs[1], pal.stone, x - w / 2, y - h, w, h)
    K.box(f, g, lvs[2], pal.stoneDark, x + w * 0.16, y - h, w * 0.34, h)
    K.box(f, g, lvs[1], pal.stone, x - w * 0.75, y - h - 8, w * 1.5, 9)
    K.box(f, g, lvs[3], pal.stoneLight, x - w * 0.75, y - h - 8, w * 1.5, 2)
    if broken then K.bar(f, g, lvs[1], pal.stone, x - w * 0.2, y - h - 14, w * 0.9, 8, 0.5) end
    moss(lvs[3], x, y - h * 0.5, w * 1.6, h * 0.6, floor(x))
    K.blur(f, g, LV.groundHi, pal.groundDark[1], x + 4, y - 1, w * 2.6, 12, 0.55)
  end
  -- tête de pierre troll : crâne, arcade, yeux, défenses, bouche, mousse
  function P.head(x, y, s, lvs)
    K.oval(f, g, lvs[1], pal.stone, x, y - 30 * s, 46 * s, 58 * s)
    K.box(f, g, lvs[1], pal.stone, x - 20 * s, y - 30 * s, 40 * s, 30 * s)
    K.box(f, g, lvs[2], pal.stoneDark, x + 8 * s, y - 52 * s, 12 * s, 52 * s, 0.55)
    K.box(f, g, lvs[2], pal.stoneDark, x - 19 * s, y - 40 * s, 38 * s, 6 * s)
    K.oval(f, g, lvs[2], pal.stoneDark, x - 9 * s, y - 31 * s, 9 * s, 6 * s)
    K.oval(f, g, lvs[2], pal.stoneDark, x + 9 * s, y - 31 * s, 9 * s, 6 * s)
    K.box(f, g, lvs[2], pal.stoneDark, x - 12 * s, y - 14 * s, 24 * s, 4 * s)
    K.bar(f, g, lvs[3], pal.stoneLight, x - 14 * s, y - 16 * s, 16 * s, 3.4 * s, 1.1)
    K.bar(f, g, lvs[3], pal.stoneLight, x + 14 * s, y - 16 * s, 16 * s, 3.4 * s, PI - 1.1)
    if pal.eyes then
      K.oval(f, g, lvs[3], pal.eyes[1], x - 9 * s, y - 31 * s, 5 * s, 3 * s, pal.eyes[2])
      K.oval(f, g, lvs[3], pal.eyes[1], x + 9 * s, y - 31 * s, 5 * s, 3 * s, pal.eyes[2])
    end
    moss(lvs[3], x - 6 * s, y - 58 * s, 40 * s, 30 * s, floor(x) + 3)
    K.blur(f, g, LV.groundHi, pal.groundDark[1], x + 4, y - 1, 60 * s, 12 * s, 0.55)
  end
  -- torche ou brasero : mât, coupe, flamme, halo
  function P.torch(x, y, h, s, lvs)
    K.box(f, g, lvs[1], pal.woodDark, x - 2.2 * s, y - h, 4.4 * s, h)
    K.box(f, g, lvs[1], pal.woodDark, x - 8 * s, y - h - 5 * s, 16 * s, 6 * s)
    K.blur(f, g, LV.shrubHi, pal.fire[1], x, y - h - 12 * s, 150 * s, 110 * s, pal.fire[2])
    K.oval(f, g, lvs[2], "#ff7f24", x, y - h - 15 * s, 15 * s, 26 * s)
    K.oval(f, g, lvs[3], "#ffe08a", x, y - h - 11 * s, 6 * s, 12 * s)
  end
  -- navire : coque, liston, sabords éclairés, mâts, voiles, pavillon, sillage
  function P.ship(x, y, s, flag, lvs)
    K.box(f, g, lvs[1], pal.woodDark, x - 60 * s, y - 18 * s, 120 * s, 18 * s)
    K.bar(f, g, lvs[1], pal.woodDark, x + 62 * s, y - 14 * s, 26 * s, 12 * s, 0.55)
    K.bar(f, g, lvs[1], pal.woodDark, x - 62 * s, y - 13 * s, 18 * s, 15 * s, -0.45)
    K.box(f, g, lvs[1], pal.woodDark, x - 60 * s, y - 27 * s, 32 * s, 10 * s)
    K.box(f, g, lvs[2], pal.wood, x - 56 * s, y - 13 * s, 112 * s, 2.5 * s)
    for i = 0, 4 do K.box(f, g, lvs[3], pal.light, x - 40 * s + i * 20 * s, y - 9 * s, 4 * s, 3 * s, 0.6) end
    for i, mx in ipairs({ -24, 18 }) do
      local mh = (i == 1 and 84 or 98) * s
      K.box(f, g, lvs[2], pal.woodDark, x + mx * s - 1.5 * s, y - 18 * s - mh, 3 * s, mh)
      K.box(f, g, lvs[3], pal.sail, x + mx * s - 20 * s, y - 18 * s - mh * 0.92, 40 * s, mh * 0.32)
      K.box(f, g, lvs[3], pal.sail, x + mx * s - 16 * s, y - 18 * s - mh * 0.54, 32 * s, mh * 0.27)
    end
    K.box(f, g, lvs[3], flag, x + 19.5 * s, y - 18 * s - 98 * s, 14 * s, 8 * s)
    K.blur(f, g, LV.canFarHi, pal.glint[1], x, y + 2, 150 * s, 10 * s, 0.25)
  end
  -- maison gobeline sur pilotis : pilotis et passerelle, toit (derrière), mur en planches, fenêtres éclairées
  function P.hut(x, y, s, lvs)
    for i = -1, 1 do K.box(f, g, lvs[1], pal.woodDark, x + i * 20 * s - 1.8 * s, y - 30 * s, 3.6 * s, 30 * s) end
    K.box(f, g, lvs[1], pal.woodDark, x - 34 * s, y - 32 * s, 68 * s, 4 * s)
    K.diamond(f, g, lvs[1], pal.roof, x, y - 62 * s, 31 * s)
    K.box(f, g, lvs[2], pal.wood, x - 26 * s, y - 62 * s, 52 * s, 31 * s)
    for i = 1, 3 do K.box(f, g, lvs[3], pal.woodDark, x - 26 * s, y - 62 * s + i * 8 * s, 52 * s, 1, 0.45) end
    K.box(f, g, lvs[3], pal.light, x - 16 * s, y - 54 * s, 8 * s, 9 * s)
    K.box(f, g, lvs[3], pal.light, x + 8 * s, y - 54 * s, 8 * s, 9 * s)
  end
  -- falaise de la baie : masses de roche, faces éclairées, jungle sur la crête
  function P.cliff(cx, cy, w, h, side, seed)
    local c = pal.cliff
    K.oval(f, g, LV.canMid, c, cx, cy, w, h)
    K.oval(f, g, LV.canMid, c, cx - side * w * 0.18, cy + h * 0.12, w * 0.9, h * 0.9)
    K.box(f, g, LV.canMid, c, cx - w * 0.45, cy, w * 0.9, K.H - cy)
    for i = 1, 4 do
      K.blur(f, g, LV.canMidHi, pal.cliffHi[1], cx + side * w * (0.05 + 0.08 * i), cy - h * 0.28 + i * h * 0.12,
        w * 0.22, h * 0.3, pal.cliffHi[2])
    end
    K.blur(f, g, LV.canMidHi, pal.groundDark[1], cx - side * w * 0.2, cy + h * 0.3, w * 0.5, h * 0.5, 0.35)
    for i = 0, 9 do
      local t = i / 9
      local x = cx - w * 0.46 + t * w * 0.92
      local dy = h / 2 * sqrt(math.max(0, 1 - ((x - cx) / (w / 2)) ^ 2))
      local r = 13 + 9 * hash(seed + i, 28)
      P.crown(LV.trunk, pal.canMid, x, cy - dy + r * 0.5 + 10 * hash(seed + i, 29), r)
      K.blur(f, g, LV.crown, pal.canMidHi[1], x - r * 0.3, cy - dy - r * 0.1, r * 1.6, r * 0.8, pal.canMidHi[2])
    end
  end
  return P
end

-- Paysage de jungle par plans. sp : horizon, field (y du sol), sun | moon, clouds, mtn = { back, front }
-- ({ x, largeur, hauteur }), canopy = { far = { y, r, amp }, mid = { … } }, trees, palms, road, water, cliffs,
-- deck (quai), props ({ genre, … }), bushes ({ x, y, r }), fronds ({ x, y, échelle, a0, a1, n }), vines,
-- overhang, rays, flies (lucioles).
local function jungle(K, f, g, sp, pal)
  local P = painter(f, g, K, pal)
  local box, vgrad, oval, blur, rgb, mix, hash = K.box, K.vgrad, K.oval, K.blur, K.rgb, K.mix, K.hash
  local Wd, Hd = K.W, K.H
  local hz, fl = sp.horizon or 178, sp.field or 268
  -- ciel
  local sk = pal.sky
  local m = floor(hz * 0.6)
  vgrad(f, g, LV.sky, rgb(sk[1]), rgb(sk[2]), 0, 0, Wd, m)
  vgrad(f, g, LV.sky, rgb(sk[2]), rgb(sk[3]), 0, m - 1, Wd, fl - m + 4)
  local orb, body, glow = sp.sun or sp.moon, pal.sun or pal.moon, pal.sunGlow or pal.moonGlow
  if orb and body then
    blur(f, g, LV.glow, glow[1], orb[1], orb[2], orb[3] * 24, orb[3] * 16, glow[2])
    blur(f, g, LV.glow, glow[1], orb[1], orb[2], orb[3] * 7, orb[3] * 7, glow[2])
    oval(f, g, LV.orb, body, orb[1], orb[2], orb[3] * 2, orb[3] * 2)
  end
  if pal.stars then
    for i = 1, 40 do
      local x, y = hash(i, 21) * Wd, 6 + hash(i, 22) * (hz - 70)
      if not (orb and math.abs(x - orb[1]) < 60 and math.abs(y - orb[2]) < 60) then
        local d = 1.4 + hash(i, 23) * 1.6
        oval(f, g, LV.glow, pal.stars, x, y, d, d, 0.3 + 0.5 * hash(i, 24))
      end
    end
  end
  for _, c in ipairs(sp.clouds or {}) do
    blur(f, g, LV.orb, pal.cloud[1], c[1], c[2], c[3], c[4], pal.cloud[2])
    blur(f, g, LV.orb, pal.cloud[1], c[1] + c[3] * 0.2, c[2] + c[4] * 0.15, c[3] * 0.6, c[4] * 0.7, pal.cloud[2])
  end
  -- collines boisées : plan lointain bleuté, plan proche avec la cime des arbres en relief, ravins à l'ombre
  local mt = sp.mtn or {}
  if mt.back then
    box(f, g, LV.mtnBack, pal.mtnBack, 0, hz - 6, Wd, fl - hz + 6)
    for _, b in ipairs(mt.back) do
      oval(f, g, LV.mtnBack, pal.mtnBack, b[1], hz, b[2], b[3] * 2)
      oval(f, g, LV.mtnBack, pal.mtnBack, b[1] - b[2] * 0.12, hz - b[3] * 0.55, b[2] * 0.45, b[3] * 0.95)
    end
  end
  if mt.front then
    box(f, g, LV.mtnFront, pal.mtnFront, 0, hz + 8, Wd, fl - hz)
    for bi, b in ipairs(mt.front) do
      oval(f, g, LV.mtnFront, pal.mtnFront, b[1], hz + 8, b[2], b[3] * 2)
      local n = floor(b[2] / 26)
      for i = 0, n do
        local x = b[1] - b[2] * 0.45 + i * b[2] * 0.9 / n
        local dy = b[3] * sqrt(math.max(0, 1 - ((x - b[1]) / (b[2] / 2)) ^ 2))
        oval(f, g, LV.mtnFront, pal.mtnFront, x, hz + 8 - dy + 3, 18 + 8 * hash(bi * 13 + i, 30), 12 + 4 * hash(i, 31))
      end
      for i = 1, 3 do
        blur(f, g, LV.mtnHaze, pal.mtnShade[1], b[1] + b[2] * (0.05 + 0.12 * i), hz + 8 - b[3] * 0.25,
          b[2] * 0.1, b[3] * 1.3, pal.mtnShade[2])
      end
    end
  end
  blur(f, g, LV.mtnHaze, pal.mist[1], Wd / 2, hz + 4, Wd * 1.7, 64, pal.mist[2])
  for _, r in ipairs(sp.rays or {}) do
    if pal.ray then K.bar(f, g, LV.mtnHaze, pal.ray[1], r[1], r[2], r[3], r[4], r[5] or -1.05, pal.ray[2]) end
  end
  -- eau (côte) : de l'horizon au quai, reflets
  if sp.water then
    local w = sp.water
    vgrad(f, g, LV.canFar, rgb(pal.water[1]), rgb(pal.water[2]), 0, w[1], Wd, w[2] - w[1])
    for i = 1, 28 do
      local t = hash(i, 25) ^ 1.3
      local y = w[1] + 4 + (w[2] - w[1] - 8) * t
      box(f, g, LV.canFarHi, pal.glint[1], hash(i, 26) * Wd, y, 18 + 70 * hash(i, 27) * t, 1.2 + t, pal.glint[2])
    end
    if orb and sp.sun then blur(f, g, LV.canFarHi, glow[1], orb[1], w[1] + 34, 180, 60, glow[2] * 0.8) end
  end
  -- canopée lointaine puis moyenne
  local cn = sp.canopy or {}
  if cn.far then P.canopy(LV.canFar, LV.canFarHi, pal.canFar, pal.canFarHi, cn.far[1], fl + 2, cn.far[2], 11, cn.far[3], true) end
  if cn.mid then P.canopy(LV.canMid, LV.canMidHi, pal.canMid, pal.canMidHi, cn.mid[1], fl + 2, cn.mid[2], 37, cn.mid[3]) end
  for _, cl in ipairs(sp.cliffs or {}) do P.cliff(cl[1], cl[2], cl[3], cl[4], cl[5], floor(cl[1])) end
  -- arbres émergents et palmiers derrière le sol
  for _, t in ipairs(sp.trees or {}) do P.tree(t[1], t[2], t[3], t[4], pal.trunk, pal.crown, LV.trunk, LV.crown, pal.crownHi) end
  for _, p in ipairs(sp.palms or {}) do P.palm(p[1], p[2], p[3], p[4], p[5] or 1, pal.trunk, pal.crown, LV.trunk, LV.crown) end
  -- brume basse au pied de la canopée
  blur(f, g, LV.mist, pal.mist[1], Wd / 2, fl - 6, Wd * 1.5, 50, pal.mist[2] * 0.9)
  -- sol : latérite et mousse, ombres et taches de lumière
  vgrad(f, g, LV.ground, rgb(pal.ground[1]), rgb(pal.ground[2]), 0, fl, Wd, Hd - fl)
  for i = 1, 16 do
    local x, y = hash(i, 31) * Wd, fl + 12 + (Hd - fl - 20) * hash(i, 32)
    local w = 90 + 170 * hash(i, 33) * (0.4 + (y - fl) / (Hd - fl))
    local c = (i % 3 == 0) and pal.groundHi or ((i % 3 == 1) and pal.groundMoss or pal.groundDark)
    blur(f, g, LV.groundHi, c[1], x, y, w, w * 0.22, c[2])
  end
  -- chemin en perspective (tranches fines : bords lisses)
  if sp.road then
    local r = sp.road
    local y0, yy = fl + 2, fl + 2
    while yy < Hd do
      local t = (yy - y0) / (Hd - y0)
      local step = 1.6 + 3.2 * t
      local tm = math.min(1, (yy + step / 2 - y0) / (Hd - y0))
      local w = r[3] + (r[4] - r[3]) * tm
      local cx = r[1] + (r[2] - r[1]) * tm + (r[5] or 0) * sin(PI * tm)
      local e = 2 + 7 * tm
      box(f, g, LV.groundHi, pal.roadEdge[1], cx - w / 2 - e, yy, w + 2 * e, step + 0.6, pal.roadEdge[2])
      box(f, g, LV.road, mix(pal.road[1], pal.road[2], tm), cx - w / 2, yy, w, step + 0.6)
      yy = yy + step
    end
    -- bords : traits continus le long des deux lisières (cachent les marches des tranches)
    local function edge(t, side)
      local w = r[3] + (r[4] - r[3]) * t
      return r[1] + (r[2] - r[1]) * t + (r[5] or 0) * sin(PI * t) + side * w / 2, y0 + (Hd - y0) * t
    end
    for _, side in ipairs({ -1, 1 }) do
      for i = 0, 9 do
        local t1, t2 = i / 10, (i + 1) / 10
        local x1, y1 = edge(t1, side)
        local x2, y2 = edge(t2, side)
        P.seg(LV.shrubHi, pal.roadEdge[1], x1, y1, x2, y2, 2 + 7 * t2, pal.roadEdge[2] + 0.2)
      end
    end
  end
  -- quai de Booty Bay : planches, joints, bord éclairé
  if sp.deck then
    local d = sp.deck
    box(f, g, LV.road, pal.deck, 0, d, Wd, Hd - d)
    for i = 0, 7 do
      local y = d + (Hd - d) * (i / 8) ^ 1.25
      box(f, g, LV.shrub, pal.woodDark, 0, y, Wd, 0.8 + i * 0.22)
    end
    box(f, g, LV.shrubHi, pal.light, 0, d, Wd, 2, 0.35)
  end
  -- sous-bois au pied de la canopée, buissons isolés
  if sp.undergrowth ~= false and not sp.deck then
    local gap = sp.road and { sp.road[1], sp.road[3] / 2 + 8 }
    P.undergrowth(fl + 4, gap, 50, sp.shrubSize)
  end
  for i, b in ipairs(sp.bushes or {}) do P.bush(b[1], b[2], b[3], 70 + i * 11) end
  -- accessoires
  for _, p in ipairs(sp.props or {}) do
    local k = p[1]
    if k == "ziggurat" then P.ziggurat(p[2], p[3], p[4], p[5], p[6], PROP_LV)
    elseif k == "pillar" then P.pillar(p[2], p[3], p[4], p[5], p[6], PROP_LV)
    elseif k == "head" then P.head(p[2], p[3], p[4], PROP_LV)
    elseif k == "lintel" then
      box(f, g, LV.p1, pal.stone, p[2] - p[4] / 2, p[3], p[4], p[5])
      box(f, g, LV.p2, pal.stoneDark, p[2] - p[4] / 2, p[3] + p[5] - 4, p[4], 4)
      box(f, g, LV.p3, pal.stoneLight, p[2] - p[4] / 2, p[3], p[4], 2)
    elseif k == "torch" then P.torch(p[2], p[3], p[4], p[5] or 1, PROP_LV)
    elseif k == "glow" then blur(f, g, LV.shrubHi, pal.fire[1], p[2], p[3] - 10, 170 * p[4], 90 * p[4], pal.fire[2] * 1.6)
    elseif k == "ship" then P.ship(p[2], p[3], p[4], p[5] or "#1d1d22", { LV.canMidHi, LV.trunk, LV.crown })
    elseif k == "hut" then P.hut(p[2], p[3], p[4], PROP_LV)
    elseif k == "palm" then P.palm(p[2], p[3], p[4], p[5], p[6] or 1, pal.trunkNear or pal.trunk, pal.crownNear or pal.crown, LV.p1, LV.p2)
    elseif (ns.Scene and ns.Scene.PROPS or {})[k] then
      -- accessoires communs du peintre (tente, foyer, charrette) aux couleurs de la jungle
      blur(f, g, LV.groundHi, pal.groundDark[1], p[2] + 6, p[3] - 1, 90 * (p[4] or 1), 14 * (p[4] or 1), 0.5)
      ns.Scene.PROPS[k](f, g, PROP_LV, pal.mid, pal, p[2], p[3], p[4] or 1, p[5])
    end
  end
  -- voile du bas (sol des personnages)
  local v = pal.veil
  vgrad(f, g, LV.veil, K.withAlpha(v[1], 0), K.withAlpha(v[1], v[2]), 0, Hd - 136, Wd, 136)
  -- premier plan : feuilles, lianes, feuillage du haut, lucioles
  for _, fr in ipairs(sp.fronds or {}) do P.fronds(fr[1], fr[2], fr[3], fr[4], fr[5], fr[6], fr[7] or floor(fr[1])) end
  for _, vn in ipairs(sp.vines or {}) do P.vine(vn[1], vn[2], vn[3] or 1, vn[1] * 0.1) end
  for _, oh in ipairs(sp.overhang or {}) do P.overhang(oh[1], oh[2], oh[1]) end
  if sp.flies and pal.fly then
    for i = 1, sp.flies do
      local x, y = 40 + hash(i, 41) * (Wd - 80), fl - 50 + hash(i, 42) * (Hd - fl + 20)
      blur(f, g, LV.veil, pal.fly, x, y, 20, 20, 0.35)
      oval(f, g, LV.top, pal.fly, x, y, 3, 3, 0.9)
    end
  end
end

-- Palettes (clés propres à la jungle, lues par jungle()).
Art.palettes.stranglethorn = {
  sky = { "#5b8ea6", "#a1c4bd", "#e2e6bf" }, sun = "#fff8e0", sunGlow = { "#fff0b8", 0.42 }, cloud = { "#f4f6ea", 0.28 },
  mtnBack = "#8fae9e", mtnFront = "#6a9271", mtnShade = { "#2f5a40", 0.22 }, mist = { "#e1e9cc", 0.45 },
  canFar = "#527d50", canFarHi = { "#b5d48f", 0.24 }, canMid = "#2c5532", canMidHi = { "#86b86a", 0.24 },
  trunk = "#2a3622", crown = "#22452a", crownHi = { "#a6cc82", 0.2 },
  shrub = "#1c3a20", shrubHi = { "#6fa055", 0.3 },
  ground = { "#5e5230", "#2f2814" }, groundHi = { "#b08f55", 0.2 }, groundMoss = { "#4e7a32", 0.28 },
  groundDark = { "#17140a", 0.32 },
  road = { "#c08d58", "#8c5a30" }, roadEdge = { "#3a2c14", 0.5 },
  stone = "#8c8a72", stoneDark = "#5a5846", stoneLight = "#c9c4a4", moss = { "#5a8a36", 0.5 },
  leaf = "#122c17", leafRib = { "#5c8a45", 0.5 },
  veil = { "#0c170a", 0.6 }, ray = { "#fff3c4", 0.07 },
  wood = "#7a5634", woodDark = "#3a2616", fire = { "#ffb24a", 0.22 }, roof = "#6e3b22", light = "#f3cf7a",
  mid = { main = "#5d4a30", dark = "#2d2215", wood = "#d4c39a", crate = "#8a6a3e" }, smoke = { "#f2efe4", 0.5 },
}

Art.palettes.stranglethorn_night = {
  night = true,
  sky = { "#061220", "#102834", "#213f3d" }, moon = "#eef0dc", moonGlow = { "#9fc7c0", 0.28 }, stars = "#eef2dc",
  cloud = { "#3c5a5c", 0.22 },
  mtnBack = "#1a3230", mtnFront = "#13281e", mtnShade = { "#030a06", 0.35 }, mist = { "#5c7f7a", 0.24 },
  canFar = "#102318", canFarHi = { "#3e6a5a", 0.18 }, canMid = "#0a1910", canMidHi = { "#2d5a46", 0.18 },
  trunk = "#071008", crown = "#06120a", crownHi = { "#3e6a5a", 0.12 },
  shrub = "#05100a", shrubHi = { "#2a4a3a", 0.25 },
  ground = { "#1a1a12", "#0b0b07" }, groundHi = { "#3e4a3a", 0.16 }, groundMoss = { "#1e3a24", 0.25 },
  groundDark = { "#000000", 0.35 },
  road = { "#3a3426", "#24201a" }, roadEdge = { "#0a0906", 0.6 },
  stone = "#3a3d38", stoneDark = "#1f211d", stoneLight = "#5c6156", moss = { "#1f3a24", 0.45 },
  leaf = "#030805", leafRib = { "#1d3a26", 0.5 },
  veil = { "#000000", 0.66 }, fly = "#d8f27a",
  wood = "#2a2016", woodDark = "#120c08", fire = { "#ffa040", 0.3 }, roof = "#24140c", light = "#f0c264",
  mid = { main = "#1c1a14", dark = "#0c0b08", wood = "#3c372a", crate = "#2a241a" }, smoke = { "#56635e", 0.35 },
}

-- Booty Bay : eau turquoise, falaises, planches du quai.
Art.palettes.stranglethorn_coast = {
  sky = { "#4f8fbf", "#9cc8d8", "#e6efd6" }, sun = "#fff9e2", sunGlow = { "#fff2c0", 0.4 }, cloud = { "#fbfbf2", 0.36 },
  mtnBack = "#86ab9c", mtnFront = "#5f8a6a", mtnShade = { "#355a46", 0.25 }, mist = { "#eaf2df", 0.4 },
  water = { "#43a8a8", "#1b5a6c" }, glint = { "#e8fbf4", 0.45 },
  canFar = "#4f7d52", canFarHi = { "#a8c78f", 0.2 }, canMid = "#2d5534", canMidHi = { "#8cc070", 0.3 },
  cliff = "#4e5a48", cliffHi = { "#a0ab88", 0.28 },
  trunk = "#2a3a24", crown = "#24482b", crownHi = { "#9cc47f", 0.18 },
  shrub = "#1c3a20", shrubHi = { "#6fa055", 0.3 },
  ground = { "#7a5b38", "#4a341c" }, groundHi = { "#b08f5c", 0.2 }, groundMoss = { "#4e7a32", 0.2 },
  groundDark = { "#1f1a0e", 0.3 },
  road = { "#b98a58", "#8a5a32" }, roadEdge = { "#4a3a1e", 0.5 },
  stone = "#8f8a74", stoneDark = "#5e5a4a", stoneLight = "#c3bea2",
  leaf = "#16331b", leafRib = { "#5c8a45", 0.5 },
  veil = { "#140e06", 0.5 },
  wood = "#8a6a44", woodDark = "#5a3c22", deck = "#9a7648", roof = "#8a3a22", light = "#f6d38a", sail = "#efe6cc",
  fire = { "#ffb24a", 0.2 },
  mid = { main = "#5d4a30", dark = "#2d2215", wood = "#c8b48a", crate = "#9a7444" }, smoke = { "#e8e6da", 0.4 },
}

-- Portes de Zul'Gurub : crépuscule rouge (Hakkar), pierre sombre, braseros.
Art.palettes.stranglethorn_gates = {
  sky = { "#2a0f1c", "#7a2a2a", "#d27a4a" }, sun = "#ffd2a0", sunGlow = { "#ff7a4a", 0.4 }, cloud = { "#5a1e28", 0.35 },
  mtnBack = "#4a2a2e", mtnFront = "#2e2420", mtnShade = { "#12080a", 0.35 }, mist = { "#c86a4a", 0.22 },
  canFar = "#22301e", canFarHi = { "#a06a4a", 0.16 }, canMid = "#142014", canMidHi = { "#7a4a3a", 0.18 },
  trunk = "#0e140c", crown = "#0c1a0e", crownHi = { "#a05a3a", 0.1 },
  shrub = "#0a140a", shrubHi = { "#6a3a2a", 0.25 },
  ground = { "#3a2a1a", "#170f08" }, groundHi = { "#7a4a2a", 0.2 }, groundMoss = { "#2a3a1e", 0.25 },
  groundDark = { "#000000", 0.35 },
  road = { "#6a5a46", "#3e3326" }, roadEdge = { "#120c06", 0.6 },
  stone = "#5c5446", stoneDark = "#2c2820", stoneLight = "#8e8268", moss = { "#2f4a24", 0.45 },
  eyes = { "#ff5a2a", 0.85 },
  leaf = "#070d07", leafRib = { "#4a2a1a", 0.5 },
  veil = { "#050202", 0.62 }, ray = { "#ffb08a", 0.06 },
  wood = "#3a2416", woodDark = "#1a0f08", fire = { "#ff7a2a", 0.32 }, roof = "#3a1a10", light = "#ffb05a",
  mid = { main = "#2a2018", dark = "#120d08", wood = "#4a3a2a", crate = "#3a2a1a" }, smoke = { "#5a4a44", 0.35 },
}

-- Plans communs (jour et nuit) : vallée, deux canopées, palmiers, chemin qui monte.
local MTN = { back = { { 120, 330, 96 }, { 430, 300, 72 }, { 700, 360, 108 }, { 980, 300, 84 } },
  front = { { 250, 320, 56 }, { 560, 260, 40 }, { 870, 330, 64 } } }
local ROAD_PALMS = { { 176, 272, 150, 0.28, 1.0 }, { 252, 272, 118, -0.2, 0.85 }, { 812, 272, 160, -0.3, 1.05 },
  { 896, 272, 112, 0.22, 0.8 } }
local ROAD_FRONDS = { { -20, 404, 1.2, 0.2, 1.35, 7 }, { 70, 412, 0.8, 0.55, 1.6, 4 },
  { 1054, 404, 1.2, PI - 1.35, PI - 0.2, 7 }, { 964, 412, 0.8, PI - 1.6, PI - 0.55, 4 } }
local ROAD_BUSHES = { { 330, 318, 22 }, { 140, 352, 28 }, { 760, 322, 24 }, { 870, 350, 26 } }
local VINES = { { 34, 150 }, { 92, 96 }, { 958, 130 }, { 1004, 176 } }
local OVERHANG = { { -10, 210 }, { 850, 1050 } }

local function road(t)
  t.draw = jungle
  t.horizon, t.field = t.horizon or 178, t.field or 268
  t.mtn = t.mtn or MTN
  t.canopy = t.canopy or { far = { 222, 20, 12 }, mid = { 250, 30, 16 } }
  return t
end

Art.paintings.stranglethorn_road = road({ pal = "stranglethorn", sun = { 690, 66, 20 },
  clouds = { { 220, 54, 360, 30 }, { 830, 92, 300, 26 } },
  palms = ROAD_PALMS, trees = { { 520, 270, 72, 40 } },
  road = { 600, 520, 14, 420, -60 },
  rays = { { 760, 140, 420, 46 }, { 640, 160, 420, 30 }, { 880, 150, 380, 22 } },
  bushes = ROAD_BUSHES,
  props = { { "pillar", 92, 334, 66, 22, true }, { "head", 948, 340, 0.9 } },
  fronds = ROAD_FRONDS, vines = VINES, overhang = OVERHANG })

Art.paintings.stranglethorn_night = road({ pal = "stranglethorn_night", moon = { 760, 58, 16 },
  clouds = { { 260, 70, 360, 26 } },
  palms = ROAD_PALMS, trees = { { 520, 270, 72, 40 } },
  road = { 600, 520, 14, 420, -60 },
  bushes = ROAD_BUSHES,
  props = { { "pillar", 92, 334, 66, 22, true }, { "head", 948, 340, 0.9 }, { "torch", 452, 304, 46, 0.8 } },
  fronds = ROAD_FRONDS, vines = VINES, overhang = OVERHANG, flies = 12 })

-- Campement de Nesingwary : clairière, tentes, foyer, caisses.
Art.paintings.stranglethorn_camp = road({ pal = "stranglethorn", sun = { 220, 62, 20 },
  clouds = { { 520, 50, 380, 30 } },
  palms = { { 120, 270, 140, 0.25, 0.95 }, { 950, 270, 150, -0.25, 1.0 } }, trees = { { 680, 270, 66, 36 } },
  rays = { { 300, 140, 420, 40 }, { 200, 150, 380, 26 } },
  bushes = { { 160, 340, 26 }, { 990, 344, 28 } },
  props = { { "tent", 300, 318, 1.25 }, { "tent", 470, 302, 0.95 }, { "tent", 770, 314, 1.15 },
    { "glow", 604, 340, 1.0 }, { "smoke", 604, 342, 1.5 }, { "cart", 880, 334, 0.95, "crates" } },
  fronds = { { -20, 406, 1.1, 0.2, 1.35, 6 }, { 1054, 406, 1.1, PI - 1.35, PI - 0.2, 6 } },
  vines = { { 40, 120 }, { 990, 150 } }, overhang = { { -10, 170 }, { 890, 1050 } } })

-- Ruines trolls (Zul'Kunda, Zul'Mamwe) : pyramide à degrés, colonnes, têtes de pierre.
Art.paintings.stranglethorn_ruins = road({ pal = "stranglethorn", sun = { 860, 70, 20 },
  clouds = { { 300, 60, 360, 28 } },
  canopy = { far = { 230, 20, 12 }, mid = { 258, 30, 16 } },
  palms = { { 120, 272, 140, 0.25, 0.95 }, { 300, 274, 110, -0.2, 0.8 } },
  bushes = { { 480, 312, 22 }, { 800, 314, 24 }, { 150, 356, 26 } },
  props = { { "ziggurat", 640, 304, 320, 150, 5 }, { "pillar", 400, 322, 92, 26, false }, { "pillar", 880, 318, 70, 24, true },
    { "head", 230, 346, 1.1 }, { "head", 966, 350, 0.8 }, { "palm", 1000, 336, 120, -0.3, 0.9 } },
  road = { 640, 560, 30, 380, 30 },
  rays = { { 820, 150, 420, 40 } },
  fronds = ROAD_FRONDS, vines = { { 30, 160 }, { 1010, 120 } }, overhang = OVERHANG })

-- Booty Bay : la baie entre deux falaises, navires, maisons sur pilotis, quai en planches.
Art.paintings.stranglethorn_coast = { draw = jungle, pal = "stranglethorn_coast", horizon = 170, field = 300,
  sun = { 560, 60, 20 }, clouds = { { 300, 50, 400, 30 }, { 840, 80, 300, 24 } },
  mtn = { back = { { 520, 420, 50 } } },
  water = { 176, 304 },
  cliffs = { { 70, 190, 320, 330, 1 }, { 980, 182, 330, 344, -1 } },
  props = { { "ship", 470, 240, 0.8, "#1d1d22" }, { "ship", 706, 226, 0.6, "#a3221c" },
    { "hut", 250, 302, 1.0 }, { "hut", 822, 302, 0.95 }, { "palm", 168, 306, 120, 0.25, 0.9 },
    { "palm", 916, 306, 130, -0.25, 0.95 } },
  deck = 302,
  fronds = { { -20, 406, 1.0, 0.2, 1.3, 5 }, { 1054, 406, 1.0, PI - 1.3, PI - 0.2, 5 } },
  vines = { { 30, 110 } } }

-- Portes de Zul'Gurub (boss) : deux pyramides, l'entrée surmontée d'une tête aux yeux rouges, braseros.
Art.paintings.stranglethorn_gates = road({ pal = "stranglethorn_gates", sun = { 520, 150, 26 },
  clouds = { { 200, 60, 420, 34 }, { 840, 50, 380, 30 } },
  canopy = { far = { 236, 20, 12 }, mid = { 264, 30, 16 } },
  bushes = { { 380, 336, 24 }, { 664, 336, 24 } },
  props = { { "ziggurat", 250, 316, 330, 196, 6 }, { "ziggurat", 790, 316, 330, 196, 6 },
    { "pillar", 456, 320, 150, 34, false }, { "pillar", 584, 320, 150, 34, false },
    { "lintel", 520, 160, 190, 22 }, { "head", 520, 160, 1.15 },
    { "torch", 412, 334, 62, 1.25 }, { "torch", 628, 334, 62, 1.25 },
    { "head", 90, 356, 1.0 }, { "head", 950, 356, 1.0 } },
  road = { 520, 520, 64, 360, 0 },
  rays = { { 520, 110, 460, 70, -1.57 } },
  fronds = ROAD_FRONDS, vines = VINES, overhang = OVERHANG })

Art.scenes.stranglethorn_road = { paint = "stranglethorn_road" }   -- route et combats
Art.scenes.stranglethorn_night = { paint = "stranglethorn_night" } -- feu de camp
Art.scenes.stranglethorn_camp = { paint = "stranglethorn_camp" }   -- campement de Nesingwary
Art.scenes.stranglethorn_coast = { paint = "stranglethorn_coast" } -- Booty Bay (côte, marchand)
Art.scenes.stranglethorn_ruins = { paint = "stranglethorn_ruins" } -- ruines trolls
Art.scenes.stranglethorn_gates = { paint = "stranglethorn_gates" } -- Zul'Gurub (boss)
