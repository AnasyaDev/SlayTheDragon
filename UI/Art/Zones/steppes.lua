-- Art de la zone Burning Steppes (`steppes`) : modèles des ennemis et des personnages, icônes des cartes et
-- bibelots du commun, décors peints (roche brûlée, lave, ciel rouge), vue de la règle Wildfire
-- (ns.ZoneViews.steppes : jeton, prévision des Stoke, brûlure hachurée sur la barre de PV).
-- Guide : docs/zones.md ; fiche : docs/zones/steppes.md.
local _, ns = ...

local Art = ns.Art
local sin, cos, floor, PI, min, max = math.sin, math.cos, math.floor, math.pi, math.min, math.max

local function I(tga)
  return { tga = tga, icon = "Interface\\Icons\\" .. tga:lower() }
end

---------------------------------------------------------------------------
-- Ennemis et personnages
---------------------------------------------------------------------------
-- Créatures de la fiche (base Questie, Classic), puis affichages relevés dans le cache de créatures du
-- client Forever (tools/wdb_creatures.py, 13/11/2026). Une créature absente des deux caches reste en tête
-- (le client la demande au serveur) ; ses affichages sont ceux d'un voisin de la même famille (« repli »).
local HEAD_ORC = I("INV_Misc_Head_Orc_01")
local HEAD_DRAGON = I("INV_Misc_Head_Dragon_Black")
local WORG = I("Ability_Mount_BlackDireWolf")
Art.enemies.blackrock_soldier = { creature = 7025, display = { 6047, 6033, 6044 }, icon = HEAD_ORC } -- repli : Pourfendeur, Grunt, Champion rochenoire
Art.enemies.blackrock_sorcerer = { creature = 7026, display = { 6046, 6030, 6048 }, icon = I("Spell_Fire_FlameBolt") } -- 6046 : la créature
Art.enemies.blackrock_worg = { creature = 7055, display = { 780, 11421 }, wide = 1.3, icon = WORG } -- repli : Noirworg affamé, Worg
Art.enemies.black_dragonspawn = { creature = 7040, display = { 2554 }, scale = 1.1, icon = HEAD_DRAGON } -- repli : Draconide Flammécaille
Art.enemies.black_wyrmkin = { creature = 7041, display = { 8309, 2554 }, icon = HEAD_DRAGON } -- repli : Wyrmide Flammécaille
Art.enemies.firegut_brute = { creature = 7035, display = { 1054, 1052, 415 }, scale = 1.1, icon = I("INV_Misc_MonsterHead_03") } -- repli : ogres Boulderfist, Splinter Fist
Art.enemies.firegut_ogre_mage = { creature = 7034, display = { 326 }, icon = I("Spell_Fire_Fire") } -- repli : Splinter Fist Fire Weaver
Art.enemies.flamekin_torcher = { creature = 9778, display = { 10817, 10814 }, icon = I("Spell_Fire_Immolation") } -- 10817 : la créature
Art.enemies.thaurissan_firewalker = { creature = 7037, display = { 7796, 7797, 825 }, icon = I("Spell_Fire_Fire") } -- repli : Forge-vapeur Sombrefer
Art.enemies.gruklash = { creature = 8979, display = { 6044, 6047 }, scale = 1.15, icon = HEAD_ORC } -- repli : Champion rochenoire
Art.enemies.thauris_balgarr = { creature = 8978, display = { 3954, 825 }, scale = 1.1, icon = I("INV_Misc_Bomb_08") } -- repli : Dark Iron Bombardier
-- Mine : aucun affichage connu ni voisin de la même famille (liste vide) ; modèle du sort (creature/spells/landmine01.m2) puis celui d'Alterac
Art.enemies.dark_iron_land_mine = { creature = 8035, display = {}, files = { { 126022, "land mine" }, { 201156, "Alterac land mine" } },
  icon = I("INV_Misc_Bomb_02") }
-- Volchan : géant de lave, aucun affichage connu ; repli : élémentaire de feu (Captive Fire Elemental, 1070),
-- puis le modèle du géant de lave (wow_model_search)
Art.enemies.volchan = { creature = 10119, display = { 1070 }, files = { { 524124, "molten giant" } }, scale = 1.25,
  icon = I("Spell_Fire_Volcano") }
Art.enemies.grark_lorkrub = { creature = 9520, display = { 6044, 6047 }, scale = 1.2, icon = I("INV_Misc_Head_Orc_02") } -- repli : Champion rochenoire
Art.ui.mapBoss.steppes = Art.enemies.grark_lorkrub.icon -- boss du parcours : Grark Lorkrub
Art.enemies.ember_worg = { creature = 9690, display = { 9370, 780 }, wide = 1.3, icon = I("Spell_Fire_LavaSpawn") } -- repli : Worg de braise géant

-- Personnages des rencontres (repli : voisins de même apparence du cache)
Art.npcs.oralius = { creature = 9177, display = { 4147, 4141 }, icon = I("INV_Misc_Note_06") } -- repli : Captain Nials, Lieutenant Valorcall
Art.npcs.marshal_maxwell = { creature = 9560, display = { 3454, 1985 }, icon = I("INV_Banner_01") } -- repli : Marshal Marris, Dughan
Art.npcs.ragged_john = { creature = 9563, display = { 3614, 1943 }, icon = I("INV_Misc_Horn_01") } -- repli : fermiers humains
Art.npcs.mathredis_firestar = { creature = 9836, display = { 5076, 10610 }, icon = I("INV_Relics_LibramofHope") } -- repli : Andromath
Art.npcs.tinkee_steamboil = { creature = 10267, display = { 7110, 7109 }, icon = I("INV_Misc_EngGizmos_19") } -- repli : artisan gobelin
Art.npcs.helendis_riverhorn = { creature = 9562, display = { 4141, 1861 }, icon = I("INV_Potion_24") } -- repli : Lieutenant Valorcall
Art.npcs.yuka_screwspigot = { creature = 9544, display = { 7111, 7110 }, icon = I("INV_Misc_Bag_10") } -- repli : sculpteur gobelin
Art.npcs.cyrus_therepentous = { creature = 9459, display = { 2961, 5076 }, icon = I("INV_Misc_Head_Dragon_Black") } -- repli : Bishop DeLavey
-- Affiche lue par le crieur du camp : Town Crier (468) ; Crier Goodman (2198) ; puis l'affiche elle-même
Art.npcs.wanted_poster = { creature = 468, display = { 4310, 1525 },
  files = { { 199473, "wanted poster" }, { 199428, "wanted poster (wood)" } }, icon = I("INV_BountyHunting") }

---------------------------------------------------------------------------
-- Cartes, bibelots, icônes de la règle
---------------------------------------------------------------------------
Art.cards.greater_fire_protection_potion = I("INV_Potion_24")
Art.cards.thorium_grenade = I("INV_Misc_Bomb_05")
Art.relics.blackrock_medallion = I("INV_Jewelry_Amulet_04")
Art.relics.gortesh_head = I("INV_Misc_Head_Orc_02")
Art.relics.draco_incarcinatrix = I("INV_Misc_EngGizmos_19")
Art.relics.libram_of_resilience = I("INV_Relics_LibramofHope")
Art.relics.libram_of_voracity = I("INV_Relics_LibramofTruth")
Art.relics.heart_of_the_mountain = I("INV_Stone_15")

local FLAME = I("Spell_Fire_BurningSpeed")  -- jeton Wildfire
local STOKE = I("Spell_Fire_FlameShock")    -- Stoke dans une intention
local DOUSE = I("Spell_Frost_SummonWaterElemental")
Art.wildfire = { flame = FLAME, stoke = STOKE, douse = DOUSE }

---------------------------------------------------------------------------
-- Intentions : Stoke, Ignite
---------------------------------------------------------------------------
local function rounds(n) return n .. " round" .. (n > 1 and "s" or "") end
Art.intentParts.stoke = function(c, e, a) return "+" .. (a[2] or 1) end
Art.actionText.stoke = function(a)
  local n = a[2] or 1
  return "Stoke " .. n .. ": Wildfire " .. rounds(n) .. " sooner. If the ground already burns, its burn rises by "
    .. 2 * n .. "."
end
Art.actionText.ignite = function(a)
  return "Ignite: the ground burns at once. If it already burns, its burn rises by " .. (a[2] or 0) .. "."
end

---------------------------------------------------------------------------
-- Vue de la règle
---------------------------------------------------------------------------
local function hasStoke(e)
  local mv = ns.Enemies[e.id].moves[e.intent]
  local n = 0
  for _, a in ipairs(mv and mv.actions or {}) do if a[1] == "stoke" then n = n + (a[2] or 1) end end
  return n
end

local V = {}
ns.ZoneViews.steppes = V

-- Jeton en haut au centre : compte à rebours (flamme grise) ou brûlure (flamme rouge), et la valeur
-- après le tour ennemi quand des Stoke sont annoncés.
function V.counter(c)
  local WF = ns.Wildfire
  local z = WF and WF.state(c)
  if not z then return nil end
  local fc = WF.forecast(c)
  local spec = { icon = FLAME, key = "steppes:wildfire" }
  if z.left > 0 then
    spec.text = "Wildfire in " .. z.left .. (fc.left ~= z.left and (" → " .. fc.left) or "")
    spec.hot = fc.burnNow
    local tip = "Ignites in " .. rounds(z.left) .. ". Each enemy death delays it by 1."
    if fc.stoke > 0 then
      tip = tip .. " Enemy Stoke this turn: " .. rounds(z.left - fc.left) .. " sooner."
    end
    if fc.burnNow then
      tip = tip .. " It ignites during the enemy turn: you lose " .. fc.blaze .. " HP at the end of this round."
    end
    spec.tip = tip
  else
    spec.text = "Wildfire " .. z.blaze .. (fc.blaze ~= z.blaze and (" → " .. fc.blaze) or "")
    spec.hot = true
    spec.tip = "End of round: you lose " .. fc.blaze .. " HP, then it rises by " .. z.step
      .. ". Kill an enemy to skip this round's burn."
  end
  return spec
end

-- Petite flamme à droite de l'intention qui contient un Stoke.
function V.intentBadge(c, e)
  local n = hasStoke(e)
  if n == 0 then return nil end
  return { icon = STOKE, key = "steppes:stoke", tip = "Stoke " .. n .. ": Wildfire " .. rounds(n) .. " sooner." }
end

-- Serviteur : sa mort ne recule pas le feu (flamme grisée).
function V.enemyBadges(c, e)
  if not ns.Wildfire or not ns.Wildfire.state(c) or not e.minion then return nil end
  return { { icon = FLAME, key = "steppes:minion", text = "", dim = true,
    tip = "Minion: its death does not delay Wildfire." } }
end

-- Brûlure de fin de round hachurée sur la barre de PV du joueur.
local STRIPE, STRIPES = 4, 40
function V.build(host, view)
  local bar = view.playerHp
  if not bar then return end
  local h = CreateFrame("Frame", nil, bar)
  h:SetFrameLevel(bar:GetFrameLevel() + 2)
  h:EnableMouse(false)
  h.stripes = {}
  for i = 1, STRIPES do
    local t = h:CreateTexture(nil, "OVERLAY", nil, 1)
    t:SetColorTexture(0.85, 0.2, 0.05, 0.92)
    h.stripes[i] = t
  end
  h.edge = h:CreateTexture(nil, "OVERLAY", nil, 2)
  h.edge:SetColorTexture(1, 0.55, 0.15, 0.95)
  h:Hide()
  host.hatch = h
end

function V.render(host, c, view)
  local h = host.hatch
  if not h then return end
  local WF = ns.Wildfire
  local fc = WF and WF.forecast(c)
  local p = c.player
  if not fc or not fc.burnNow or c.result or p.hp <= 0 then
    h:Hide()
    return
  end
  local bar = view.playerHp
  local w = bar.w or bar:GetWidth() or 100
  local bh = bar:GetHeight() or 12
  local loss = min(fc.blaze, p.hp)
  local x1 = w * max(0, min(1, p.hp / p.maxHp))
  local x0 = w * max(0, (p.hp - loss) / p.maxHp)
  local width = max(2, x1 - x0)
  h:ClearAllPoints()
  h:SetPoint("TOPLEFT", bar, "TOPLEFT", x0, 0)
  h:SetSize(width, bh)
  local n = 0
  for i, t in ipairs(h.stripes) do
    local sx = (i - 1) * STRIPE
    if sx < width then
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", h, "TOPLEFT", sx, 0)
      t:SetSize(min(STRIPE / 2, width - sx), bh)
      t:Show()
      n = n + 1
    else
      t:Hide()
    end
  end
  h.edge:ClearAllPoints()
  h.edge:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
  h.edge:SetSize(1, bh)
  h.shown = n
  h:Show()
end

---------------------------------------------------------------------------
-- Décors peints : roche brûlée, coulées de lave, ciel rouge (Art.paintings, S.landscape, plans de zone)
---------------------------------------------------------------------------

-- Palette de jour (ciel de fumée rouge, plaine de cendres) et de nuit ; couleurs propres :
-- lava = { cœur, chaud, lueur, croûte }, rock = { masse, ombre, face éclairée, reflet de la lave }, ember.
local DAY = {
  sky = { "#2a1311", "#7a2c1a", "#d2672e" }, sun = "#ffb27a", sunGlow = { "#ff6a2a", 0.4 },
  cloud = { "#3b211b", 0.5 },
  hillsBack = "#5a2f25", hillsFront = "#2b1814", mound = "#2e1d17", moundLight = { "#7a3a22", 0.4 },
  trees = "#24140f", haze = { "#c4572c", 0.38 },
  patches = { "#58403a", "#523b33", "#5e4438", "#4d3730", "#56403a" }, hedge = { "#1a0e0b", 0.3 },
  fieldsNear = { "#4d3428", "#21150f" }, furrowDark = { "#120a08", 0.25 }, furrowLight = { "#ff8a3a", 0.05 },
  road = { "#6a5242", "#3f3028" }, roadEdge = "#24180f",
  far = { main = "#3a2019", dark = "#26150f", light = "#ff9a44" },
  mid = { main = "#26170f", dark = "#140b07", wood = "#6a4a30", crate = "#7a5636" },
  flag = "#8e1c12", smoke = { "#2d1c18", 0.55 },
  ground = { "#0b0504", 0.6 }, stalk = "#1d120d", ears = { "#ff7a26", "#d9481c", "#ffb04a" },
  lava = { "#ffe08a", "#ff7a1e", "#ff4a14", "#2a110a" }, rock = { "#2e1e18", "#160d0a", "#5c3b2c", "#ff6a26" },
  ember = "#ffb04a",
}
local function copy(t, over)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  for k, v in pairs(over or {}) do r[k] = v end
  return r
end
Art.palettes.steppes = DAY
-- Morgan's Vigil : bannières bleues de l'Alliance, toile claire
Art.palettes.steppes_vigil = copy(DAY, { flag = "#2e4f8e", smoke = { "#8a7468", 0.45 },
  mid = { main = "#2a1a12", dark = "#160c08", wood = "#9a8a72", crate = "#7a5636" } })
-- Flame Crest : toile rouge de la Horde, caisses des gobelins
Art.palettes.steppes_crest = copy(DAY, { flag = "#9a1e10",
  mid = { main = "#2a1a12", dark = "#160c08", wood = "#7a2a1a", crate = "#8a6238" } })
Art.palettes.steppes_night = copy(DAY, { night = true,
  sky = { "#0a0505", "#2a0e0a", "#6a2414" }, sun = nil, sunGlow = nil, moon = "#e8b88a", moonGlow = { "#ff7a3a", 0.22 },
  cloud = { "#1c0f0c", 0.55 }, hillsBack = "#2c1612", hillsFront = "#130a08", trees = "#0f0806",
  haze = { "#8a3418", 0.34 }, patches = { "#2a1d19", "#241915", "#30211b", "#1f1612", "#2a1e18" },
  fieldsNear = { "#2a1b14", "#0e0907" }, road = { "#3a2c24", "#1c1510" }, roadEdge = "#0e0907",
  far = { main = "#170d0a", dark = "#0e0806", light = "#ffa04a" },
  mid = { main = "#0f0907", dark = "#070403", wood = "#2a1c14", crate = "#2e2018" },
  smoke = { "#140b09", 0.6 }, ground = { "#030101", 0.66 }, stalk = "#0c0806",
  rock = { "#140c0a", "#080504", "#3a2218", "#ff6a26" } })

-- Montagne : carré tourné (angle de 90° au sommet, pentes de 45° ± tilt), placé par son sommet (ax, ay).
local function peak(K, f, g, lv, c, ax, ay, size, tilt, a)
  local phi = PI / 4 + (tilt or 0)
  local cs, sn, h = cos(phi), sin(phi), size / 2
  local bx, by
  for _, d in ipairs({ { h, h }, { h, -h }, { -h, h }, { -h, -h } }) do
    local x, y = d[1] * cs - d[2] * sn, d[1] * sn + d[2] * cs
    if not by or y > by then bx, by = x, y end
  end
  K.bar(f, g, lv, c, ax - bx, ay + by, size, size, phi, a)
  return phi
end

-- Arête gauche d'un sommet, éclairée (reflet du ciel rouge) : trait fin et translucide le long de la pente.
local function ridge(K, f, g, lv, c, a, ax, ay, size, tilt)
  local phi = PI / 4 + (tilt or 0)
  -- pente gauche : direction vers le bas à gauche d'angle (90° - phi) sous l'horizontale
  local th = phi
  local len = size * 0.55
  local dx, dy = -cos(th), sin(th)
  K.bar(f, g, lv, c, ax + dx * len / 2, ay + dy * len / 2, len, 2.2, th, a)
end

-- Panache de fumée qui monte en s'élargissant et dérive.
local function plume(K, f, g, lv, c, a, x, y, height, drift, n)
  for i = 1, n do
    local t = i / n
    K.blur(f, g, lv, c, x + drift * t * t + 6 * sin(i * 1.7), y - height * t, 20 + 90 * t, 18 + 60 * t,
      a * (1.15 - t))
  end
end

-- Lignes d'horizon : chaîne lointaine (brumeuse), massif du premier rang, lueurs des cratères et fumées.
local function skyline(K, f, g, sp, pal)
  local s = sp.steppes
  local L = K.LV
  for _, p in ipairs(s.back or {}) do peak(K, f, g, L.hillsBack, pal.hillsBack, p[1], p[2], p[3], p[4]) end
  for _, p in ipairs(s.front or {}) do peak(K, f, g, L.hillsFront, pal.hillsFront, p[1], p[2], p[3], p[4]) end
  for _, p in ipairs(s.front or {}) do ridge(K, f, g, L.trees, pal.lava[3], 0.28, p[1], p[2], p[3], p[4]) end
  for _, p in ipairs(s.back or {}) do ridge(K, f, g, L.trees, pal.sunGlow and pal.sunGlow[1] or pal.lava[3], 0.16, p[1], p[2], p[3], p[4]) end
  -- face éclairée par le bas (lave de la plaine) : voile chaud au pied du premier rang
  local hz = sp.horizon or 190
  K.blur(f, g, L.trees, pal.lava[3], K.W / 2, hz - 10, K.W * 1.3, 60, 0.22)
  for _, v in ipairs(s.craters or {}) do
    -- cratère : lueur sur le sommet, bouche plate, deux coulées sur la pente gauche, panache
    K.blur(f, g, L.trees, pal.lava[3], v[1], v[2] + 14, 120, 44, 0.45)
    K.box(f, g, L.trees, pal.lava[4], v[1] - 14, v[2] + 4, 28, 5, 0.9)
    K.blur(f, g, L.trees, pal.lava[2], v[1], v[2] + 6, 40, 12, 0.85)
    for k, d in ipairs({ { -1, 0.7, 46 }, { 1, 0.8, 34 } }) do
      local th = d[2]
      local x0, y0 = v[1] + d[1] * 6, v[2] + 8
      local dx, dy = d[1] * cos(th), sin(th)
      K.bar(f, g, L.trees, pal.lava[2], x0 + dx * d[3] / 2, y0 + dy * d[3] / 2, d[3], 2.4, d[1] > 0 and -th or th, 0.8)
      K.blur(f, g, L.trees, pal.lava[3], x0 + dx * d[3] / 2, y0 + dy * d[3] / 2, d[3] * 1.2, 16, 0.3)
    end
    plume(K, f, g, L.trees, pal.smoke[1], 0.5, v[1], v[2] - 8, v[3] or 150, v[4] or 90, 7)
  end
  -- affleurement (Slither Rock) : masse de roche sombre et aiguilles, sur l'horizon
  for _, o in ipairs(s.outcrops or {}) do
    for _, p in ipairs(o) do peak(K, f, g, L.trees, pal.rock[1], p[1], p[2], p[3], p[4]) end
    for _, p in ipairs(o) do ridge(K, f, g, L.trees, pal.lava[3], 0.3, p[1], p[2], p[3], p[4]) end
  end
  for _, v in ipairs(s.smokes or {}) do
    plume(K, f, g, L.trees, pal.smoke[1], 0.42, v[1], v[2], v[3] or 110, v[4] or 60, 6)
    K.blur(f, g, L.trees, pal.lava[3], v[1], v[2] + 4, 40, 14, 0.6)
  end
end

-- Points intermédiaires d'une ligne brisée (Catmull-Rom) : courbe douce passant par chaque point.
local function smooth(pts, n)
  local out = {}
  for i = 1, #pts - 1 do
    local p0, p1, p2, p3 = pts[max(1, i - 1)], pts[i], pts[i + 1], pts[min(#pts, i + 2)]
    for j = 0, n - 1 do
      local t = j / n
      local t2, t3 = t * t, t * t * t
      local function cr(a, b, c, d) return 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (3 * b - a - 3 * c + d) * t3) end
      out[#out + 1] = { cr(p0[1], p1[1], p2[1], p3[1]), cr(p0[2], p1[2], p2[2], p3[2]) }
    end
  end
  out[#out + 1] = pts[#pts]
  return out
end

-- Coulée de lave : lueur, croûte, lave, cœur ; largeur selon la distance à l'horizon.
local function river(K, f, g, pal, pts, hz, k)
  local L = K.LV
  pts = smooth(pts, 4)
  local lv = pal.lava
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local len = math.sqrt(dx * dx + dy * dy) + 2
    local ang = math.atan2(-dy, dx)
    local cx, cy = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
    local w = (1.5 + (cy - hz) * 0.11) * (k or 1)
    if i % 2 == 1 then K.blur(f, g, L.furrows, lv[3], cx, cy, len * 2.6, w * 5 + 12, 0.3) end
    -- croûte, lave, cœur opaques (aucun recouvrement translucide aux jointures) ; jointures arrondies
    K.bar(f, g, L.furrows, lv[4], cx, cy, len, w * 1.7, ang)
    K.bar(f, g, L.roadEdge, lv[2], cx, cy, len, w, ang)
    K.bar(f, g, L.road, lv[1], cx, cy, len, max(0.8, w * 0.38), ang)
    if i > 1 then
      K.oval(f, g, L.furrows, lv[4], a[1], a[2], w * 1.7, w * 1.7)
      K.oval(f, g, L.roadEdge, lv[2], a[1], a[2], w, w)
      K.oval(f, g, L.road, lv[1], a[1], a[2], max(0.8, w * 0.38), max(0.8, w * 0.38))
    end
  end
end

-- Rocher : masse, face éclairée (haut gauche), reflet de la lave (bas), ombre au sol.
local function rock(K, f, g, pal, x, y, w, h, glow)
  local L, r = K.LV, pal.rock
  K.blur(f, g, L.furrows, pal.ground[1], x + w * 0.1, y, w * 1.4, h * 0.35, 0.6)
  K.oval(f, g, L.mid[1], r[1], x, y - h / 2, w, h)
  K.oval(f, g, L.mid[2], r[3], x - w * 0.16, y - h * 0.7, w * 0.5, h * 0.4, 0.55)
  K.oval(f, g, L.mid[2], r[2], x + w * 0.2, y - h * 0.35, w * 0.55, h * 0.55, 0.7)
  if glow then K.blur(f, g, L.mid[3], r[4], x, y - h * 0.12, w * 0.9, h * 0.28, 0.35) end
end

-- Aiguille de roche : triangle étroit, arête éclairée.
local function spire(K, f, g, pal, x, y, w, h)
  local L, r = K.LV, pal.rock
  K.blur(f, g, L.furrows, pal.ground[1], x, y, w * 2, 10, 0.55)
  K.tri(f, g, L.mid[1], r[1], x, y, w, h)
  K.tri(f, g, L.mid[2], r[3], x - w * 0.18, y - h * 0.08, w * 0.3, h * 0.82)
end

-- Bannière du clan Blackrock (ou de l'Alliance : couleur de la palette) : mât, étoffe, emblème.
local function banner(K, f, g, pal, x, y, s, lv)
  local L = K.LV
  lv = lv or L.mid
  K.box(f, g, lv[1], pal.mid.dark, x - 1.5 * s, y - 70 * s, 3 * s, 70 * s)
  K.box(f, g, lv[1], pal.mid.dark, x - 9 * s, y - 70 * s, 18 * s, 2.5 * s)
  K.box(f, g, lv[2], pal.flag, x - 7 * s, y - 67 * s, 14 * s, 30 * s)
  K.oval(f, g, lv[3], pal.mid.dark, x, y - 54 * s, 7 * s, 7 * s, 0.8)
end

-- Brasero : socle de pierre, coupe de fer, trois langues de flamme, lueur au sol.
local function brazier(K, f, g, pal, x, y, s)
  local L = K.LV
  K.blur(f, g, L.furrows, pal.lava[3], x, y - 4 * s, 110 * s, 34 * s, 0.4)
  K.blur(f, g, L.furrows, pal.lava[3], x, y - 40 * s, 80 * s, 80 * s, 0.22)
  K.box(f, g, L.mid[1], pal.rock[1], x - 7 * s, y - 20 * s, 14 * s, 20 * s)
  K.box(f, g, L.mid[1], pal.rock[1], x - 10 * s, y - 4 * s, 20 * s, 4 * s)
  K.oval(f, g, L.mid[1], pal.mid.dark, x, y - 24 * s, 32 * s, 12 * s)
  for k, d in ipairs({ { -6, 20, 0.25 }, { 6, 18, -0.3 }, { 0, 28, 0 } }) do
    local fl = K.oval(f, g, L.mid[2], pal.lava[2], x + d[1] * s, y - 28 * s - d[2] * s / 2, 9 * s, d[2] * s, 0.95)
    if fl.SetRotation then fl:SetRotation(d[3]) end
  end
  K.oval(f, g, L.mid[3], pal.lava[1], x, y - 34 * s, 6 * s, 14 * s, 0.9)
end

-- Porte de Blackrock Stronghold : muraille, deux tours à créneaux, porte sombre, pointes, braseros.
local function fortress(K, f, g, pal, v)
  local L = K.LV
  local x, y, w, h = v[1], v[2], v[3], v[4]
  local c, d = pal.far.main, pal.far.dark
  K.box(f, g, L.far[1], c, x - w / 2, y - h, w, h)
  for i = 0, floor(w / 16) do
    K.box(f, g, L.far[1], c, x - w / 2 + i * 16, y - h - 6, 9, 7)
  end
  for _, tx in ipairs({ x - w / 2 - 6, x + w / 2 + 6 }) do
    K.box(f, g, L.far[2], d, tx - 22, y - h * 1.55, 44, h * 1.55)
    for i = 0, 2 do K.box(f, g, L.far[2], d, tx - 22 + i * 17, y - h * 1.55 - 8, 10, 9) end
    K.box(f, g, L.far[3], pal.far.light, tx - 3, y - h * 1.2, 6, 9, 0.9)
  end
  K.box(f, g, L.far[2], d, x - 30, y - h * 0.75, 60, h * 0.75)
  K.oval(f, g, L.far[2], d, x, y - h * 0.75, 60, 40)
  K.blur(f, g, L.far[3], pal.lava[3], x, y - 8, 70, 26, 0.55)
  for i = -3, 3 do
    K.bar(f, g, L.far[3], d, x + i * 30, y - h - 14, 22, 3, PI / 2 + i * 0.12)
  end
end

local function ground(K, f, g, sp, pal)
  local s = sp.steppes
  local hz = sp.horizon or 190
  for _, r in ipairs(s.rivers or {}) do river(K, f, g, pal, r, hz, r.k) end
  for _, l in ipairs(s.farLava or {}) do
    K.blur(f, g, K.LV.furrows, pal.lava[3], l[1], l[2], l[3] * 1.6, 10, 0.35)
    K.bar(f, g, K.LV.roadEdge, pal.lava[2], l[1], l[2], l[3], 1.2, l[4] or 0.02, 0.85)
  end
  for _, p in ipairs(s.pools or {}) do
    K.blur(f, g, K.LV.furrows, pal.lava[3], p[1], p[2], p[3] * 2.2, p[4] * 3, 0.4)
    K.oval(f, g, K.LV.roadEdge, pal.lava[2], p[1], p[2], p[3], p[4])
    K.oval(f, g, K.LV.road, pal.lava[1], p[1] - p[3] * 0.08, p[2] - p[4] * 0.05, p[3] * 0.5, p[4] * 0.42, 0.85)
  end
  -- fissures du sol proche : trois traits brisés, lueur
  for i = 1, s.cracks or 0 do
    local x, y = 40 + K.hash(i, 21) * (K.W - 80), hz + 70 + K.hash(i, 22) * (K.H - hz - 90)
    local len = 18 + 26 * K.hash(i, 23) * (y - hz) / (K.H - hz)
    K.blur(f, g, K.LV.furrows, pal.lava[3], x, y, len * 2.4, 12, 0.3)
    local a = (K.hash(i, 24) - 0.5) * 0.6
    for j = -1, 1 do
      K.bar(f, g, K.LV.roadEdge, pal.lava[2], x + j * len * 0.5, y + j * 1.5 * (j % 2 == 0 and 1 or -1),
        len * 0.55, 0.9 + (y - hz) * 0.005, a + j * 0.45, 0.7)
    end
  end
  for _, v in ipairs(s.fortress and { s.fortress } or {}) do fortress(K, f, g, pal, v) end
  for _, sp2 in ipairs(s.spires or {}) do spire(K, f, g, pal, sp2[1], sp2[2], sp2[3], sp2[4]) end
  for _, r in ipairs(s.rocks or {}) do rock(K, f, g, pal, r[1], r[2], r[3], r[4], r[5]) end
  for _, b in ipairs(s.banners or {}) do banner(K, f, g, pal, b[1], b[2], b[3] or 1, b[4] and K.LV[b[4]]) end
  for _, b in ipairs(s.braziers or {}) do brazier(K, f, g, pal, b[1], b[2], b[3] or 1) end
end

-- Premier plan : braises qui montent, rochers sombres des coins.
local function front(K, f, g, sp, pal)
  local s = sp.steppes
  local hz = sp.horizon or 190
  for i = 1, s.embers or 0 do
    local x, y = K.hash(i, 31) * K.W, hz - 60 + K.hash(i, 32) * (K.H - hz + 40)
    local d = 1.4 + K.hash(i, 33) * 2.2
    K.oval(f, g, K.LV.smoke, pal.ember, x, y, d, d, 0.35 + 0.5 * K.hash(i, 34))
  end
  for _, r in ipairs(s.foreground or {}) do
    K.oval(f, g, K.LV.ground, pal.rock[2], r[1], r[2], r[3], r[4], 0.92)
  end
end

local LAYERS = { skyline = skyline, ground = ground, front = front }

-- Une peinture des Steppes : horizon, collines vides (la chaîne est dessinée par skyline), pas de rangs de
-- champ ; `steppes` = plans propres (back, front, craters, smokes, rivers, pools, cracks, rocks, spires,
-- banners, braziers, fortress, embers, foreground).
local function steppes(t, pal)
  t.pal = pal or "steppes"
  t.horizon, t.field = t.horizon or 200, t.field or 236
  t.hills, t.trees, t.furrows, t.shadows = t.hills or {}, {}, false, {}
  t.clouds = t.clouds or { { 160, 54, 300, 40 }, { 560, 34, 260, 30 }, { 860, 92, 320, 36 } }
  t.layers = LAYERS
  return t
end

-- Blackrock Mountain au loin (centre gauche), chaîne de crêtes ; rangée lointaine plus claire
local MOUNTAIN_BACK = { { 120, 128, 150, 0.1 }, { 245, 96, 210, -0.12 }, { 340, 58, 290, 0.04 },
  { 455, 92, 230, 0.18 }, { 560, 126, 170, -0.2 }, { 700, 148, 150, 0.15 }, { 830, 136, 170, -0.08 },
  { 960, 150, 160, 0.2 } }
local MOUNTAIN_FRONT = { { 40, 170, 120, 0.2 }, { 190, 150, 150, -0.25 }, { 300, 132, 170, 0.12 },
  { 410, 150, 150, -0.15 }, { 620, 176, 110, 0.3 }, { 760, 168, 130, -0.2 }, { 900, 172, 120, 0.1 },
  { 1010, 160, 130, -0.15 } }
local ROAD_ROCKS = { { 96, 300, 84, 44, true }, { 168, 286, 40, 22 }, { 742, 306, 70, 36, true },
  { 930, 290, 56, 30 }, { 460, 252, 30, 14 } }

Art.paintings = Art.paintings or {}
local P = Art.paintings
-- Route de cendres entre Blackrock Pass et Morgan's Vigil.
P.steppes_road = steppes({ sun = { 690, 120, 16 }, road = { 470, 540, 8, 380, 60 },
  steppes = { back = MOUNTAIN_BACK, front = MOUNTAIN_FRONT, craters = { { 340, 62, 160, 120 } },
    smokes = { { 790, 196 }, { 120, 198, 90, -40 } },
    rivers = { { { 860, 206 }, { 830, 232 }, { 870, 262 }, { 830, 300 }, { 880, 345 }, { 850, 400 } } },
    pools = { { 640, 228, 46, 7 } }, cracks = 9, rocks = ROAD_ROCKS,
    farLava = { { 180, 214, 120, 0.03 }, { 300, 222, 70, -0.04 }, { 980, 218, 90, 0.02 } },
    spires = { { 1000, 276, 26, 70 }, { 30, 262, 22, 54 } }, embers = 36,
    foreground = { { 40, 392, 180, 60 }, { 1000, 396, 200, 70 } } },
  wheat = { { 120, 330, 10 }, { 640, 760, 9 } } })
-- La même, de nuit (feu de camp)
P.steppes_night = steppes({ moon = { 820, 66, 14 }, road = { 470, 540, 8, 380, 60 },
  steppes = P.steppes_road.steppes, wheat = P.steppes_road.wheat }, "steppes_night")
-- Slither Rock : rocher en surplomb, coulée sous un pont de pierre
P.steppes_hill = steppes({ sun = { 860, 112, 15 },
  steppes = { back = { { 600, 104, 220, 0.1 }, { 760, 84, 260, -0.1 }, { 900, 120, 200, 0.2 } },
    front = { { 700, 160, 150, 0.2 }, { 850, 150, 160, -0.2 }, { 1000, 170, 120, 0 } },
    craters = { { 760, 88, 150, 80 } }, smokes = { { 520, 198 } },
    rivers = { { { 520, 210 }, { 600, 240 }, { 560, 280 }, { 660, 330 }, { 620, 400 } }, k = 1.4 },
    pools = { { 860, 250, 70, 10 } }, cracks = 6,
    outcrops = { { { 300, 92, 150, 0.3 }, { 250, 128, 140, -0.25 }, { 380, 140, 110, 0.15 }, { 170, 160, 120, 0.1 },
      { 450, 168, 90, -0.2 } } },
    spires = { { 120, 300, 26, 64 }, { 900, 286, 22, 50 } },
    rocks = { { 150, 312, 110, 54, true }, { 820, 330, 90, 46, true }, { 980, 300, 60, 30 } }, embers = 30,
    foreground = { { 60, 396, 220, 70 } } },
  wheat = { { 380, 480, 8 }, { 880, 1020, 10 } } })
-- Morgan's Vigil : camp de l'Alliance, tentes, tour de guet, bannières bleues
P.steppes_camp = steppes({ sun = { 860, 110, 15 },
  props = { { "tower", 820, 236, 0.85, "far" }, { "tent", 300, 300, 1.3, "mid" }, { "tent", 470, 278, 1.0, "mid" },
    { "tent", 160, 282, 0.9, "mid" }, { "smoke", 390, 300, 1.0, "mid" }, { "fence", 560, 302, 1034, 286, "mid" } },
  steppes = { back = MOUNTAIN_BACK, front = MOUNTAIN_FRONT, craters = { { 340, 62, 160, 120 } },
    banners = { { 236, 292, 0.9 }, { 540, 290, 0.8 } }, rocks = { { 700, 318, 70, 34, true }, { 960, 330, 80, 40 } },
    cracks = 5, embers = 20, foreground = { { 1010, 396, 180, 60 } } },
  wheat = { { -6, 90, 10 }, { 900, 1040, 10 } } }, "steppes_vigil")
-- Flame Crest : comptoir de la Horde et des gobelins, charrette de caisses, bannières rouges, braseros
P.steppes_shop = steppes({ sun = { 220, 112, 15 }, road = { 520, 660, 8, 300, 40 },
  props = { { "tent", 180, 290, 1.2, "mid" }, { "tent", 330, 272, 0.9, "mid" },
    { "cart", 760, 304, 1.3, "mid", "crates" }, { "smoke", 620, 278, 0.8, "mid" } },
  steppes = { back = MOUNTAIN_BACK, front = MOUNTAIN_FRONT, craters = { { 340, 62, 160, 120 } },
    banners = { { 250, 284, 0.9 }, { 900, 296, 1.0 } }, braziers = { { 420, 296, 1.0 }, { 960, 314, 1.0 } },
    rocks = { { 60, 320, 90, 44, true } }, cracks = 4, embers = 24 },
  wheat = { { -6, 70, 8 }, { 980, 1040, 6 } } }, "steppes_crest")
-- Blackrock Stronghold : la montagne entière, la porte du clan, braseros et bannières, lave au pied
P.steppes_boss = steppes({ horizon = 214, field = 250,
  steppes = { back = { { 520, 18, 420, 0.03 }, { 300, 70, 300, -0.15 }, { 740, 64, 320, 0.15 },
      { 100, 120, 220, 0.1 }, { 940, 118, 220, -0.1 } },
    front = { { 200, 170, 170, 0.2 }, { 840, 168, 180, -0.2 }, { 40, 190, 120, 0 }, { 1000, 186, 130, 0 } },
    craters = { { 520, 24, 180, 120 } }, smokes = { { 260, 206, 80, -30 }, { 800, 206, 80, 40 } },
    fortress = { 520, 248, 300, 46 },
    banners = { { 330, 300, 1.1 }, { 712, 300, 1.1 } }, braziers = { { 420, 300, 1.1 }, { 622, 300, 1.1 } },
    rivers = { { { 80, 262 }, { 180, 280 }, { 140, 320 }, { 220, 400 } },
      { { 960, 262 }, { 870, 284 }, { 920, 330 }, { 840, 400 } } },
    cracks = 8, rocks = { { 40, 330, 90, 46, true }, { 1000, 340, 100, 50, true } }, embers = 40,
    foreground = { { 520, 404, 360, 40 } } } })

local SC = { "steppes_road", "steppes_hill", "steppes_camp", "steppes_shop", "steppes_night", "steppes_boss" }
for _, k in ipairs(SC) do Art.scenes[k] = { paint = k } end
