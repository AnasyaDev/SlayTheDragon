-- Art de la zone Blackrock Mountain (`blackrock`) : modèles des ennemis et des personnages, icônes des
-- cartes, bibelots et états, case du Grim Guzzler, décors peints (intérieur de la montagne : le Molten
-- Span, le Detention Block, Blackrock Spire, le Grim Guzzler, la forge de la Black Anvil, la salle du trône
-- de Nefarian) et vue de zone ns.ZoneViews.blackrock (badges des règles de phase, de l'ouverture et de la
-- phase du combat final). Guide : docs/zones.md.
local _, ns = ...

local Art = ns.Art
local hex = Art.hex
local floor, max, min, sin, cos, PI = math.floor, math.max, math.min, math.sin, math.cos, math.pi

local function I(tga)
  return { tga = tga, icon = "Interface\\Icons\\" .. tga:lower() }
end

---------------------------------------------------------------------------
-- Ennemis : créature (identifiants de la version classique, absents des caches de créatures du client
-- Forever le 13/11/2026 : non vérifiables hors jeu, le client les demande au serveur), puis affichages de
-- créatures voisines relevés dans ces caches (tools/wdb_creatures.py ; noté « repli »), puis le médaillon.
---------------------------------------------------------------------------
local ORC = I("INV_Misc_Head_Orc_01")
local DWARF = I("INV_Misc_Head_Dwarf_01")
local DRAGON_BLACK = I("INV_Misc_Head_Dragon_Black")
-- Orcs rochenoires du cache frFR : Grunt (440) 6033, Champion (435) 6044, Pourfendeur (7027) 6047,
-- Sorcier (7026) 6046, Invocateur (4463) 6030 ; Sombrefer : Nain Sombrefer (1051) 825, Sentinelle
-- (8504) 7814 / 7815, Sous-chef (5846) 7798 ; dragonkin : Wyrmide Flammécaille (7043) 8309, Dragonnet
-- noir (441) 387, Drake torride (7046) 6377, Drake noir insoumis (14388) 6374 ; Flamme vive (3417) 1405 ;
-- golems de guerre (5853, 5854) 5747, 10801 ; squelettes (6412, 48) 158, 200.
Art.enemies.firebrand_grunt = { creature = 9045, display = { 6033, 6044 }, icon = ORC }
Art.enemies.rookery_whelp = { creature = 10161, display = { 387 }, icon = I("Ability_Hunter_Pet_DragonHawk") }
Art.enemies.rookery_whelpling = Art.enemies.rookery_whelp
Art.enemies.anvilrage_guardsman = { creature = 8891, display = { 7814, 7815, 825 }, icon = DWARF }
Art.enemies.anvilrage_medic = { creature = 8894, display = { 7798, 825 }, icon = I("INV_Misc_Head_Dwarf_02") }
Art.enemies.blazing_fireguard = { creature = 8910, display = { 1405, 1070 }, icon = I("Spell_Fire_Fire") }
Art.enemies.firebrand_pyromancer = { creature = 10316, display = { 6046, 6030 }, icon = I("Spell_Fire_FlameBolt") }
Art.enemies.blackhand_veteran = { creature = 9819, display = { 6047, 6044 }, icon = ORC }
Art.enemies.rage_talon_dragonspawn = { creature = 9096, display = { 8309 }, scale = 1.1, icon = DRAGON_BLACK }
Art.enemies.rookery_hatcher = { creature = 10683, display = { 8309 }, icon = DRAGON_BLACK }
Art.enemies.panzor = { creature = 8923, display = { 10801, 5747 }, scale = 1.2, icon = I("INV_Gizmo_02") }
Art.enemies.rend_gyth = { creature = 10339, display = { 6374 }, scale = 1.25, icon = I("INV_Misc_Head_Dragon_Bronze") }
Art.enemies.rend_blackhand = { creature = 10429, display = { 6044, 6047 }, scale = 1.15, icon = ORC }
Art.enemies.vaelastrasz = { creature = 13020, display = { 6377 }, scale = 1.3, icon = I("INV_Misc_Head_Dragon_Red") }
Art.enemies.nefarian = { creature = 10162, display = { 5076, 3585 }, scale = 1.1, icon = I("Achievement_Boss_Nefarion") }
Art.enemies.nefarian_dragon = { creature = 11583, display = { 6374 }, scale = 1.4, icon = I("Achievement_Boss_Nefarion") }
Art.enemies.red_drakonid = { creature = 14264, display = { 8309 }, icon = I("INV_Misc_Head_Dragon_Red") }
Art.enemies.blue_drakonid = { creature = 14261, display = { 8309 }, icon = I("INV_Misc_Head_Dragon_Blue") }
Art.enemies.bone_construct = { creature = 14605, display = { 200, 158 }, icon = I("Spell_Shadow_RaiseDead") }

-- Personnages des rencontres (même ordre : créature de la version classique, replis du cache).
Art.npcs.franclorn_forgewright = { creature = 8888, display = { 10700, 825 }, icon = DWARF } -- fantôme (250652), Nain Sombrefer (1051)
Art.npcs.lokhtos_darkbargainer = { creature = 12944, display = { 7798, 825 }, icon = DWARF }
Art.npcs.kharan_mighthammer = { creature = 9021, display = { 3411, 3422 }, icon = I("INV_Misc_Head_Dwarf_02") } -- nains de Forgefer
Art.npcs.marshal_windsor = { creature = 9023, display = { 2372, 2367 }, icon = I("INV_Misc_Head_Human_01") }
Art.npcs.tinkee_steamboil = { creature = 10267, display = { 7109, 7110 }, icon = I("INV_Misc_Head_Gnome_01") } -- gobelins
Art.npcs.lothos_riftwaker = { creature = 14387, display = { 5076, 3585 }, icon = I("INV_Misc_Head_Human_01") } -- mages humains
Art.npcs.bodley = { creature = 16033, display = { 12940, 6973 }, icon = I("INV_Misc_Head_Gnome_01") }       -- gnomes
Art.npcs.lord_victor_nefarius = { creature = 10162, display = { 5076, 3585 }, icon = I("Achievement_Boss_Nefarion") }
Art.npcs.plugger_spazzring = { creature = 9499, display = { 3047, 825 }, icon = I("INV_Drink_09") }  -- Firebrew l'aubergiste

---------------------------------------------------------------------------
-- Cartes, bibelots, états, case de parcours
---------------------------------------------------------------------------
Art.cards.dark_iron_bomb = I("INV_Misc_Bomb_05")
Art.cards.dark_iron_ale_mug = I("INV_Drink_05")

Art.relics.blood_of_the_mountain = I("INV_Misc_Gem_Bloodstone_02")
Art.relics.black_dragonscale = I("INV_Misc_MonsterScales_03")
Art.relics.shadowforge_key = I("INV_Misc_Key_08")
Art.relics.blackhands_breadth = I("INV_Misc_Gem_Ruby_01")
Art.relics.draconic_infused_emblem = I("INV_Misc_Head_Dragon_Black")
Art.relics.neltharions_tear = I("INV_Stone_15")

Art.statuses.fire_shield = I("Spell_Fire_FireArmor")
Art.statuses.cracked = I("Ability_Warrior_Rampage")
Art.statuses.essence_of_red = I("Spell_Fire_SealOfFire")
Art.statuses.burning_adrenaline = I("Spell_Fire_Incinerate")
Art.statuses.shadowflame_fury = I("Spell_Shadow_Shadowfury")
Art.statuses.veil_of_shadow = I("Spell_Shadow_GatherShadows")
Art.statuses.corrupted_healing = I("Spell_Shadow_ShadowMend")
Art.statuses.berserker_stance = I("Ability_Warrior_InnerRage")
Art.statuses.wild_polymorph = I("Spell_Nature_Polymorph")
Art.statuses.called_out = I("Spell_Nature_EarthBind")
Art.statuses.broken_bow = I("INV_Weapon_Bow_05")

Art.statusShort.fire_shield = "each hit of your Attacks on it: you lose N."
Art.statusShort.cracked = "takes 25% more damage."
Art.statusShort.essence_of_red = "+2 mana each turn."
Art.statusShort.burning_adrenaline = "Attacks deal 50% more, then lose 15 HP."
Art.statusShort.shadowflame_fury = "at the end: Nefarian gains Strength 8."
Art.statusShort.veil_of_shadow = "heals and Regen are halved."

Art.ui.map.grim_guzzler = I("INV_Drink_09")

-- Infobulles des actions de zone (intentions)
Art.actionText.class_call = function(a, c)
  local BR = ns.Blackrock
  local cc = BR.classCall(c and c.class)
  local s = ns.Statuses[cc.status]
  return "Applies " .. s.name .. " " .. (a[2] or BR.CALL_TURNS) .. " to you: " .. s.text
end
Art.actionText.call_drakonid = function() return "Calls a Drakonid to his side." end
Art.actionText.raise_bones = function(a, c, e)
  local n = min(ns.Blackrock.BONES_MAX, e and e.mem.fallen or 0)
  return "Raises " .. n .. " Bone Construct" .. (n == 1 and "" or "s") .. ", one per Drakonid slain."
end
Art.actionText.clear_status = function(a) return a.text end

---------------------------------------------------------------------------
-- Vue de zone : ce que les règles de phase font, lisible avant de jouer
---------------------------------------------------------------------------
local OPENING = I("Achievement_Zone_Blackrock_01")

ns.ZoneViews.blackrock = {
  -- intention en cours = ouverture d'une nouvelle phase
  intentBadge = function(c, e)
    local BR = ns.Blackrock
    if BR.opening(e) and BR.opening(e) == e.intent and not e.mem.forced then
      return { icon = OPENING, tip = "Opening move of its new phase." }
    end
  end,
  -- règles de phase qui ne sont pas des états : Invincible, Shadow of the Throne
  enemyBadges = function(c, e)
    local BR = ns.Blackrock
    local list = {}
    local cap = BR.maxHit(e)
    if cap then
      list[#list + 1] = { icon = I("Spell_Holy_PowerWordBarrier"), text = "Max " .. cap,
        tip = "Invincible: each hit deals at most " .. cap .. " to it. DoT is not a hit.", color = "goldText" }
    end
    if ns.Enemies[e.id].throne and (e.mem.phase or 0) == 0 then
      local on = BR.drakonidAlive(c)
      list[#list + 1] = { icon = I("Spell_Shadow_GatherShadows"), text = "Half", dim = not on, color = on and "goldText" or nil,
        tip = "Shadow of the Throne: takes half damage while a Drakonid lives." }
    end
    -- combat final : la phase en cours et ce qui vient (sous l'intention : le compteur du haut serait sur son cadre)
    if e.id == "nefarian" then
      local k = (e.mem.phase or 0) + 1
      local n = #ns.Enemies.nefarian.phases + 1
      local t = k == 1 and "Lord Victor Nefarius on his throne. Below 75%, Nefarian lands."
        or (k == 2 and "Nefarian calls on your class. Below 25%, the Drakonids slain rise again."
        or "Last phase. Shadowflame Fury: Strength 8 when it runs out.")
      list[#list + 1] = { icon = I("Achievement_Boss_Nefarion"), text = "Phase " .. k .. "/" .. n, tip = t,
        color = k == n and "attackText" or "goldText" }
    end
    return list
  end,
}

---------------------------------------------------------------------------
-- Décors peints : l'intérieur de la montagne (peintre « cavern », UI/Scene.lua : Art.painters)
---------------------------------------------------------------------------
-- Plans, du fond vers l'avant : fond de la caverne en dégradé (noir en haut, rougeoyant vers la lave),
-- lueur de la lave, paroi lointaine dans la brume de chaleur, silhouettes lointaines (Blackrock Spire,
-- tours et cheminées des Sombrefer), parois proches, lac de lave (croûtes, reflets), pont de pierre
-- en perspective, sol rocheux du premier plan (fissures de lave, éboulis), accessoires du plan moyen,
-- voûte et stalactites, chaînes, stalagmites du premier plan, voile du bas, braises. Coordonnées du décor
-- (1034 × 390, y vers le bas). Rien n'est tiré au hasard (suite fixe K.hash).
Art.painters = Art.painters or {}

-- Silhouette remplie vers le bas (ou vers le haut si up) : colonnes de dx, haut = interpolation des points
-- { { x, y }, … } triés ; dégradé du haut (ct) au bas (cb) de chaque colonne, base = y du bas.
local function ridge(K, f, g, lv, pts, base, dx, ct, cb, up)
  local i = 1
  local x = pts[1][1]
  local last = pts[#pts][1]
  while x < last do
    while pts[i + 1] and pts[i + 1][1] <= x do i = i + 1 end
    local a, b = pts[i], pts[i + 1] or pts[i]
    local t = (b[1] > a[1]) and (x + dx / 2 - a[1]) / (b[1] - a[1]) or 0
    if t > 1 then t = 1 end
    local y = a[2] + (b[2] - a[2]) * t
    if up then
      K.vgrad(f, g, lv, ct, cb, x, 0, dx + 0.6, y)
    elseif cb then
      K.vgrad(f, g, lv, ct, cb, x, y, dx + 0.6, base - y)
    else
      K.box(f, g, lv, ct, x, y, dx + 0.6, base - y)
    end
    x = x + dx
  end
  -- bord lissé : un trait tourné le long de chaque segment, posé juste sous la ligne (côté plein), couvre
  -- les marches des colonnes sans déborder
  local edge = up and (cb or ct) or ct
  for k = 1, #pts - 1 do
    local a, b = pts[k], pts[k + 1]
    local ddx, ddy = b[1] - a[1], b[2] - a[2]
    local len = math.sqrt(ddx * ddx + ddy * ddy)
    local sl = ddx > 0 and math.abs(ddy / ddx) or 0
    if sl > 0.25 and len > 0 then
      local th = math.min(14, sl * dx * 0.5 + 1.5)
      local nx, ny = -ddy / len, ddx / len -- normale vers le bas (y croissant) si ddx > 0
      if up then nx, ny = -nx, -ny end
      K.bar(f, g, lv, edge, (a[1] + b[1]) / 2 + nx * th / 2, (a[2] + b[2]) / 2 + ny * th / 2, len + 1, th,
        math.atan2(-ddy, ddx))
    end
  end
end

-- Points d'une ligne déchiquetée de x0 à x1 autour de y : pas `step`, écart amp, montée vers les bords
-- (edge = hauteur en plus aux deux extrémités, la caverne encadre le décor), graine seed.
local function jag(K, x0, x1, y, amp, step, seed, edge, dir)
  local pts = {}
  local n = floor((x1 - x0) / step)
  local ph1, ph2 = K.hash(seed, 1) * 6.28, K.hash(seed, 2) * 6.28
  for k = 0, n do
    local x = x0 + (x1 - x0) * k / n
    local u = (x - x0) / (x1 - x0)
    local e = edge and edge * ((math.abs(u - 0.5) * 2) ^ 2.2) or 0
    -- ondulation lente (deux sinus) et éclats de roche (suite fixe)
    local slow = 0.5 + 0.3 * sin(u * 7.1 + ph1) + 0.2 * sin(u * 17.3 + ph2)
    local h = amp * (0.25 + 0.55 * slow + 0.3 * K.hash(seed * 7 + k, 3)) + e
    pts[#pts + 1] = { x, y + (dir or -1) * h }
  end
  return pts
end

-- Pente d'une paroi proche vers son bord intérieur (côté du décor) : les derniers `frac` de la masse
-- descendent jusqu'à la base, au lieu d'une coupe verticale.
local function slope(pts, base, inner, frac)
  local x0, x1 = pts[1][1], pts[#pts][1]
  for _, p in ipairs(pts) do
    local u = (p[1] - x0) / (x1 - x0)
    if inner == "right" then u = 1 - u end
    if u < frac then
      local t = 1 - u / frac
      p[2] = p[2] + (base - p[2]) * (t ^ 1.6)
    end
  end
  return pts
end

-- Triangle pointe en bas (stalactite) de base w en (cx, ty), hauteur h, tranches de `step`.
local function itri(K, f, g, lv, c, cx, ty, w, h, step)
  local n = max(1, floor(h / (step or 3) + 0.5))
  local sh = h / n
  for i = 1, n do
    local ww = w * (n - i + 0.5) / n
    K.box(f, g, lv, c, cx - ww / 2, ty + (i - 1) * sh, ww, sh + 0.4)
  end
end
-- Triangle pointe en haut (stalagmite, flèche), base en (cx, by).
local function utri(K, f, g, lv, c, cx, by, w, h, step)
  local n = max(1, floor(h / (step or 3) + 0.5))
  local sh = h / n
  for i = 1, n do
    local ww = w * (i - 0.5) / n
    K.box(f, g, lv, c, cx - ww / 2, by - h + (i - 1) * sh, ww, sh + 0.4)
  end
end

-- Flamme : halo large, cœur orangé, pointe claire.
local function flame(K, f, g, lvGlow, lv, x, y, s, pal)
  K.blur(f, g, lvGlow, pal.fire[1], x, y - 4 * s, 120 * s, 90 * s, 0.35)
  K.blur(f, g, lv, pal.fire[1], x, y - 6 * s, 26 * s, 30 * s, 0.85)
  K.oval(f, g, lv, pal.fire[2], x, y - 7 * s, 9 * s, 14 * s, 0.95)
  K.oval(f, g, lv, pal.fire[3], x, y - 5 * s, 4 * s, 7 * s, 0.95)
end

-- Accessoires : (K, f, g, P = niveaux { fond, masse, détails }, c = couleurs du plan, pal, x, y du pied,
-- échelle, variante).
local PR = {}

-- Tour des Sombrefer : fût qui s'affine par paliers, créneaux, pointes, fenêtres rougeoyantes.
function PR.tower(K, f, g, P, c, pal, x, y, s)
  local hw = { 17, 14, 11.5 }
  for i = 1, 3 do K.box(f, g, P[1], c.main, x - hw[i] * s, y - 34 * i * s, 2 * hw[i] * s, 34 * s + 1) end
  local top = y - 102 * s
  for k = -1, 1 do K.box(f, g, P[2], c.main, x + (k * 8 - 3) * s, top - 6 * s, 6 * s, 7 * s) end
  utri(K, f, g, P[2], c.dark, x - 12 * s, top + 1, 6 * s, 22 * s, 2)
  utri(K, f, g, P[2], c.dark, x + 12 * s, top + 1, 6 * s, 22 * s, 2)
  if c.light then
    for i = 0, 2 do
      K.box(f, g, P[3], c.light, x - 2.5 * s, y - (22 + 34 * i) * s, 5 * s, 8 * s, 0.85)
      K.blur(f, g, P[3], c.light, x, y - (18 + 34 * i) * s, 22 * s, 18 * s, 0.25)
    end
  end
end

-- Cheminée de forge : fût étroit, bouche rougeoyante, panache de fumée qui monte et dérive.
function PR.chimney(K, f, g, P, c, pal, x, y, s)
  local h = 130 * s
  K.box(f, g, P[1], c.dark, x - 6 * s, y - h, 12 * s, h)
  K.box(f, g, P[2], c.main, x - 8 * s, y - h - 4 * s, 16 * s, 7 * s)
  K.blur(f, g, P[3], pal.glow[1], x, y - h - 4 * s, 34 * s, 20 * s, 0.5)
  local sm = pal.smoke
  for i = 1, 8 do
    local t = i / 8
    K.blur(f, g, P[1], sm[1], x + 60 * t * t * s, y - h - 14 * s - 120 * t * s, (16 + 70 * t) * s, (14 + 46 * t) * s,
      sm[2] * (1.1 - t))
  end
end

-- Blackrock Spire : piton déchiqueté, rampes et tours accrochées, fenêtres.
function PR.spire(K, f, g, P, c, pal, x, y, s)
  local pts = {}
  local prof = { { -1, 0 }, { -0.82, -0.18 }, { -0.66, -0.26 }, { -0.5, -0.45 }, { -0.38, -0.5 }, { -0.26, -0.72 },
    { -0.12, -0.8 }, { -0.05, -1 }, { 0.04, -0.92 }, { 0.16, -0.84 }, { 0.3, -0.62 }, { 0.44, -0.55 },
    { 0.6, -0.32 }, { 0.78, -0.22 }, { 1, 0 } }
  for _, p in ipairs(prof) do pts[#pts + 1] = { x + p[1] * 120 * s, y + p[2] * 230 * s } end
  ridge(K, f, g, P[1], pts, y, 3, K.rgb(c.main), K.rgb(c.dark))
  -- tours accrochées au flanc
  for k, tx in ipairs({ -52, 30, -8 }) do
    local ty = y - ({ 120, 140, 196 })[k] * s
    K.box(f, g, P[2], c.dark, x + tx * s - 6 * s, ty - 26 * s, 12 * s, 28 * s)
    utri(K, f, g, P[2], c.dark, x + tx * s, ty - 25 * s, 14 * s, 14 * s, 2)
    if c.light then K.box(f, g, P[3], c.light, x + tx * s - 1.5 * s, ty - 16 * s, 3 * s, 5 * s, 0.9) end
  end
  if c.light then
    for i = 1, 9 do
      local wx = x + (K.hash(i, 21) - 0.5) * 120 * s
      local wy = y - (30 + 150 * K.hash(i, 22)) * s
      K.box(f, g, P[3], c.light, wx, wy, 2.5 * s, 4 * s, 0.7)
    end
  end
end

-- Chute de lave tombant de la paroi dans le lac.
function PR.lavafall(K, f, g, P, c, pal, x, y, s, variant, top)
  local y0 = top or (y - 150 * s)
  K.blur(f, g, P[1], pal.glow[1], x, (y0 + y) / 2 + 20, 90 * s, (y - y0) * 1.2, 0.3)
  K.vgrad(f, g, P[2], K.withAlpha(pal.lava[4] or pal.lava[2], 0.2), K.rgb(pal.lava[1]), x - 5 * s, y0, 10 * s, y - y0)
  K.vgrad(f, g, P[3], K.withAlpha(pal.lava[3], 0), K.withAlpha(pal.lava[3], 0.75), x - 1.2 * s, y0 + 10, 2.4 * s, y - y0 - 12)
  K.vgrad(f, g, P[2], K.withAlpha(pal.lava[2], 0), K.withAlpha(pal.lava[1], 0.8), x + 9 * s, y0 + 30, 5 * s, y - y0 - 30)
  K.blur(f, g, P[3], pal.lava[3], x, y, 60 * s, 14 * s, 0.55)
end

-- Bannière du clan Blackrock : hampe, étoffe rouge, main noire, pointe.
function PR.banner(K, f, g, P, c, pal, x, y, s)
  K.box(f, g, P[1], c.dark, x - 1.6 * s, y - 120 * s, 3.2 * s, 120 * s)
  K.box(f, g, P[1], c.dark, x - 16 * s, y - 112 * s, 32 * s, 3 * s)
  K.vgrad(f, g, P[2], K.rgb(c.cloth), K.mix(c.cloth, "#000000", 0.35), x - 14 * s, y - 110 * s, 28 * s, 52 * s)
  utri(K, f, g, P[2], c.cloth, x - 7 * s, y - 50 * s, 14 * s, -0.001, 2)
  itri(K, f, g, P[2], c.cloth, x - 7 * s, y - 58.5 * s, 14 * s, 10 * s, 2)
  itri(K, f, g, P[2], c.cloth, x + 7 * s, y - 58.5 * s, 14 * s, 10 * s, 2)
  -- main noire
  K.oval(f, g, P[3], "#100808", x, y - 82 * s, 11 * s, 12 * s)
  for k = -1.5, 1.5 do K.box(f, g, P[3], "#100808", x + k * 3.2 * s - 1 * s, y - 98 * s, 2.2 * s, 12 * s) end
  utri(K, f, g, P[3], c.dark, x, y - 119 * s, 6 * s, 9 * s, 2)
end

-- Brasero : pieds, vasque, flammes et halo.
function PR.brazier(K, f, g, P, c, pal, x, y, s)
  K.bar(f, g, P[1], c.dark, x - 7 * s, y - 14 * s, 30 * s, 3 * s, 1.25)
  K.bar(f, g, P[1], c.dark, x + 7 * s, y - 14 * s, 30 * s, 3 * s, -1.25 + PI)
  K.oval(f, g, P[2], c.main, x, y - 30 * s, 34 * s, 12 * s)
  K.box(f, g, P[2], c.main, x - 17 * s, y - 36 * s, 34 * s, 6 * s)
  flame(K, f, g, P[1], P[3], x, y - 38 * s, s * 1.3, pal)
end

-- Torche au mur : support, flamme.
function PR.torch(K, f, g, P, c, pal, x, y, s)
  K.bar(f, g, P[1], c.dark, x, y + 8 * s, 18 * s, 3 * s, 1.35)
  flame(K, f, g, P[1], P[3], x, y, s, pal)
end

-- Cellule du Detention Block : renfoncement sombre, barreaux, traverses.
function PR.cell(K, f, g, P, c, pal, x, y, s)
  local w, h = 92 * s, 104 * s
  K.box(f, g, P[1], c.main, x - w / 2 - 8 * s, y - h - 12 * s, w + 16 * s, h + 12 * s)
  K.vgrad(f, g, P[1], K.rgb("#050303"), K.mix(c.dark, "#000000", 0.4), x - w / 2, y - h, w, h)
  for k = 0, 7 do
    local bx = x - w / 2 + 6 * s + k * (w - 12 * s) / 7
    K.box(f, g, P[3], c.light or c.dark, bx - 1.6 * s, y - h, 3.2 * s, h)
  end
  K.box(f, g, P[3], c.light or c.dark, x - w / 2, y - h + 10 * s, w, 3 * s)
  K.box(f, g, P[3], c.light or c.dark, x - w / 2, y - 18 * s, w, 3 * s)
end

-- Tonneau (debout) ; variante « lying » : couché (fût de la taverne).
function PR.barrel(K, f, g, P, c, pal, x, y, s, variant)
  if variant == "lying" then
    K.oval(f, g, P[1], c.wood, x, y - 16 * s, 44 * s, 32 * s)
    K.box(f, g, P[1], c.wood, x - 22 * s, y - 32 * s, 30 * s, 32 * s)
    K.oval(f, g, P[2], K.mix(c.wood, "#000000", 0.3), x + 9 * s, y - 16 * s, 26 * s, 32 * s)
    K.oval(f, g, P[3], c.dark, x + 9 * s, y - 16 * s, 6 * s, 6 * s)
    return
  end
  K.vgrad(f, g, P[1], K.rgb(c.wood), K.mix(c.wood, "#000000", 0.35), x - 15 * s, y - 40 * s, 30 * s, 40 * s)
  K.oval(f, g, P[2], K.mix(c.wood, "#ffffff", 0.08), x, y - 40 * s, 30 * s, 8 * s)
  for _, hy in ipairs({ 9, 30 }) do K.box(f, g, P[3], c.dark, x - 15 * s, y - hy * s, 30 * s, 3 * s) end
end

-- Comptoir du Grim Guzzler : plateau, façade de planches, chopes.
function PR.counter(K, f, g, P, c, pal, x, y, s, variant, x2)
  local x1 = x2 or (x + 300 * s)
  K.vgrad(f, g, P[1], K.rgb(c.wood), K.mix(c.wood, "#000000", 0.45), x, y - 46 * s, x1 - x, 46 * s)
  K.box(f, g, P[2], K.mix(c.wood, "#ffffff", 0.12), x - 6 * s, y - 52 * s, x1 - x + 12 * s, 7 * s)
  local n = floor((x1 - x) / (34 * s))
  for k = 1, n - 1 do K.box(f, g, P[3], c.dark, x + k * (x1 - x) / n, y - 45 * s, 1.6 * s, 44 * s, 0.7) end
  for k = 1, 4 do
    local mx = x + (x1 - x) * (0.12 + 0.24 * (k - 1) + 0.05 * K.hash(k, 31))
    K.box(f, g, P[3], c.crate, mx, y - 64 * s, 8 * s, 11 * s)
    K.oval(f, g, P[3], "#e8d9a0", mx + 4 * s, y - 64 * s, 8 * s, 3 * s, 0.9)
  end
end

-- Lanterne suspendue : chaînette, cage, lumière.
function PR.lantern(K, f, g, P, c, pal, x, y, s)
  K.box(f, g, P[1], c.dark, x - 0.8 * s, 0, 1.6 * s, y - 8 * s)
  K.blur(f, g, P[1], pal.fire[2], x, y, 90 * s, 70 * s, 0.3)
  K.box(f, g, P[2], c.dark, x - 6 * s, y - 9 * s, 12 * s, 18 * s)
  K.box(f, g, P[3], pal.fire[2], x - 4 * s, y - 6 * s, 8 * s, 12 * s, 0.95)
end

-- Enclume de la Black Anvil et âtre rougeoyant derrière.
function PR.anvil(K, f, g, P, c, pal, x, y, s)
  K.box(f, g, P[2], c.main, x - 16 * s, y - 26 * s, 32 * s, 26 * s)
  K.box(f, g, P[2], c.main, x - 30 * s, y - 40 * s, 60 * s, 14 * s)
  K.bar(f, g, P[2], c.main, x + 38 * s, y - 36 * s, 22 * s, 7 * s, 0.12)
  K.box(f, g, P[3], c.light or c.dark, x - 30 * s, y - 40 * s, 60 * s, 2 * s, 0.6)
end
function PR.hearth(K, f, g, P, c, pal, x, y, s)
  local w, h = 120 * s, 84 * s
  K.blur(f, g, P[1], pal.glow[1], x, y - h / 2, w * 3, h * 2.4, 0.3)
  -- maçonnerie : piédroits, linteau en blocs
  K.vgrad(f, g, P[1], K.rgb(c.main), K.rgb(c.dark), x - w / 2 - 22 * s, y - h - 30 * s, w + 44 * s, h + 30 * s)
  for k = 0, 5 do
    K.box(f, g, P[2], c.dark, x - w / 2 - 22 * s + k * (w + 44 * s) / 6, y - h - 30 * s, 2 * s, 28 * s, 0.8)
  end
  K.box(f, g, P[2], c.dark, x - w / 2 - 22 * s, y - h - 3 * s, w + 44 * s, 3 * s)
  -- foyer : sombre en haut, braise en bas, grille
  K.vgrad(f, g, P[2], K.rgb("#2a0a04"), K.rgb(pal.lava[1]), x - w / 2, y - h, w, h)
  K.blur(f, g, P[3], pal.lava[3], x, y - 12 * s, w * 0.85, 34 * s, 0.75)
  for k = 1, 5 do K.box(f, g, P[3], c.dark, x - w / 2 + k * w / 6 - 1.5 * s, y - h * 0.55, 3 * s, h * 0.55) end
  K.box(f, g, P[3], c.dark, x - w / 2, y - h * 0.55, w, 3 * s)
end

-- Étagère de la taverne : planches, bouteilles en silhouette.
function PR.shelf(K, f, g, P, c, pal, x, y, s, variant, x2)
  local x1 = x2 or (x + 200 * s)
  for row = 0, 1 do
    local yy = y - row * 38 * s
    K.box(f, g, P[1], c.wood, x, yy, x1 - x, 4 * s)
    local n = floor((x1 - x) / (12 * s))
    for k = 0, n - 1 do
      if K.hash(k + row * 31 + x, 33) > 0.35 then
        local bh = (12 + 12 * K.hash(k + row * 17 + x, 34)) * s
        local bx = x + k * (x1 - x) / n + 2 * s
        K.box(f, g, P[2], k % 3 == 0 and "#2a3a24" or (k % 3 == 1 and "#4a2418" or c.crate), bx, yy - bh, 6 * s, bh, 0.9)
        K.box(f, g, P[3], c.dark, bx + 2 * s, yy - bh - 4 * s, 2 * s, 4 * s)
      end
    end
  end
end

-- Murs en blocs (Detention Block) : rangs de joints sur la paroi du fond.
function PR.blocks(K, f, g, P, c, pal, x, y, s, variant, x2)
  local x1 = x2 or (x + 400 * s)
  for row = 0, 5 do
    local yy = y - row * 22 * s
    K.box(f, g, P[1], c.dark, x, yy, x1 - x, 1.4 * s, 0.6)
    local n = floor((x1 - x) / (46 * s))
    for k = 0, n do
      K.box(f, g, P[1], c.dark, x + (k + (row % 2) * 0.5) * (x1 - x) / n, yy - 22 * s, 1.4 * s, 22 * s, 0.5)
    end
  end
end

-- Pilier : base, fût éclairé d'un côté, chapiteau.
function PR.pillar(K, f, g, P, c, pal, x, y, s, variant, h)
  h = (h or 220) * s
  K.box(f, g, P[1], c.dark, x - 22 * s, y - 16 * s, 44 * s, 16 * s)
  K.box(f, g, P[1], c.main, x - 16 * s, y - h, 32 * s, h)
  K.box(f, g, P[2], c.light or c.main, x - 16 * s, y - h, 6 * s, h, 0.35)
  K.box(f, g, P[2], c.dark, x - 24 * s, y - h - 14 * s, 48 * s, 16 * s)
end

-- Trône de Nefarian : estrade à trois marches, siège, dossier à pointes, lueur.
function PR.throne(K, f, g, P, c, pal, x, y, s)
  K.blur(f, g, P[1], pal.glow[1], x, y - 110 * s, 300 * s, 260 * s, 0.4)
  for k = 0, 2 do K.box(f, g, P[1], k % 2 == 0 and c.main or c.dark, x - (110 - 22 * k) * s, y - (k + 1) * 12 * s, (220 - 44 * k) * s, 12 * s) end
  local by = y - 36 * s
  K.box(f, g, P[2], c.dark, x - 30 * s, by - 120 * s, 60 * s, 120 * s)
  utri(K, f, g, P[2], c.dark, x, by - 119 * s, 60 * s, 40 * s, 2)
  utri(K, f, g, P[2], c.dark, x - 38 * s, by - 60 * s, 14 * s, 70 * s, 2)
  utri(K, f, g, P[2], c.dark, x + 38 * s, by - 60 * s, 14 * s, 70 * s, 2)
  K.box(f, g, P[2], c.main, x - 40 * s, by - 40 * s, 80 * s, 40 * s)
  K.box(f, g, P[3], c.cloth, x - 18 * s, by - 112 * s, 36 * s, 70 * s, 0.9)
  K.oval(f, g, P[3], pal.glow[1], x, by - 92 * s, 12 * s, 12 * s, 0.9)
end

-- Crâne de dragon : boîte crânienne, museau, orbites, cornes.
function PR.skull(K, f, g, P, c, pal, x, y, s)
  local bone = K.mix(c.light or c.main, "#000000", 0.45)
  c = { light = bone, main = bone, dark = c.dark }
  K.oval(f, g, P[1], bone, x, y - 26 * s, 64 * s, 46 * s)
  K.bar(f, g, P[1], bone, x + 46 * s, y - 16 * s, 60 * s, 26 * s, -0.12)
  K.blur(f, g, P[2], "#000000", x + 30 * s, y - 8 * s, 120 * s, 30 * s, 0.35)
  K.oval(f, g, P[2], c.dark, x + 4 * s, y - 32 * s, 16 * s, 12 * s)
  K.oval(f, g, P[2], c.dark, x + 58 * s, y - 20 * s, 8 * s, 5 * s)
  for k = 1, 4 do K.bar(f, g, P[2], c.dark, x + (40 + 12 * k) * s, y - 5 * s, 2 * s, 8 * s, 0) end
  K.bar(f, g, P[3], c.light or c.main, x - 34 * s, y - 52 * s, 48 * s, 7 * s, 0.75)
  K.bar(f, g, P[3], c.light or c.main, x - 18 * s, y - 56 * s, 40 * s, 6 * s, 1.05)
end

-- Tente orque : peau tendue, ouverture, perches croisées.
function PR.tent(K, f, g, P, c, pal, x, y, s)
  utri(K, f, g, P[1], K.mix(c.wood, "#000000", 0.4), x, y, 74 * s, 50 * s, 2)
  -- pan gauche éclairé par la lave
  local n = 18
  for i = 1, n do
    local hh = 50 * s * (i - 0.5) / n
    K.box(f, g, P[1], K.mix(c.wood, pal.fire[1], 0.15 * i / n), x - 37 * s + (i - 1) * 37 * s / n, y - hh, 37 * s / n + 0.5, hh, 0.95)
  end
  utri(K, f, g, P[2], c.dark, x + 4 * s, y, 22 * s, 28 * s, 2)
  K.bar(f, g, P[3], c.dark, x - 6 * s, y - 52 * s, 16 * s, 2.4 * s, 1.1)
  K.bar(f, g, P[3], c.dark, x + 6 * s, y - 52 * s, 16 * s, 2.4 * s, -1.1 + PI)
end

-- Éboulis : quelques blocs ovales.
function PR.rocks(K, f, g, P, c, pal, x, y, s)
  for k = 1, 5 do
    local rx, rw = x + (K.hash(k + x, 41) - 0.5) * 60 * s, (10 + 18 * K.hash(k + x, 42)) * s
    K.oval(f, g, P[1], k % 2 == 0 and c.main or c.dark, rx, y - rw * 0.3, rw, rw * 0.7)
  end
end

-- Chaîne pendue de la voûte (x, du haut à y).
local function chain(K, f, g, lv, c, x, y, s)
  local n = floor(y / (9 * s))
  for k = 0, n do
    local w = (k % 2 == 0) and 5 * s or 2.5 * s
    K.oval(f, g, lv, c, x, k * 9 * s, w, 8 * s)
  end
end

function Art.painters.cavern(f, g, sp, K)
  local LV = K.LV
  local pal = Art.palettes[sp.pal] or Art.palettes.blackrock
  local Wd, Hd = K.W, K.H
  local hz, fl = sp.horizon or 214, sp.floor or 300
  -- 1. fond de la caverne : noir en haut, brun rougeoyant vers l'horizon (la lave éclaire la fumée)
  local bk = pal.back
  K.vgrad(f, g, LV.sky, K.rgb(bk[1]), K.rgb(bk[2]), 0, 0, Wd, floor(hz * 0.6))
  K.vgrad(f, g, LV.sky, K.rgb(bk[2]), K.rgb(bk[3]), 0, floor(hz * 0.6) - 1, Wd, hz - floor(hz * 0.6) + 12)
  -- lueur de la lave sur la fumée, au-dessus de l'horizon
  local gl = pal.glow
  for _, gx in ipairs(sp.glows or { Wd / 2 }) do
    K.blur(f, g, LV.sun, gl[1], gx, hz - 10, 900, 260, gl[2])
    K.blur(f, g, LV.sun, gl[1], gx, hz, 520, 90, gl[2] * 0.9)
  end
  -- fumée qui flotte sous la voûte
  for k = 1, 6 do
    local cx, cy = K.hash(k, 51) * Wd, 40 + 90 * K.hash(k, 52)
    K.blur(f, g, LV.clouds, pal.smoke[1], cx, cy, 260 + 200 * K.hash(k, 53), 50 + 40 * K.hash(k, 54), pal.smoke[2] * 0.7)
  end
  -- 2. paroi lointaine, dans la brume de chaleur
  local fw = sp.farWall or { amp = 70, edge = 40, seed = 1 }
  local hazeC = pal.haze[1]
  ridge(K, f, g, LV.clouds, jag(K, -10, Wd + 10, hz - fw.amp * 0.55, fw.amp * 0.7, 46, fw.seed + 40, fw.edge), hz + 12, 7,
    K.mix(pal.wallFar[1], hazeC, 0.35), K.mix(pal.wallFar[2], hazeC, 0.45))
  ridge(K, f, g, LV.clouds, jag(K, -10, Wd + 10, hz + 2, fw.amp, 30, fw.seed, fw.edge), hz + 12, 6,
    K.rgb(pal.wallFar[1]), K.rgb(pal.wallFar[2]))
  -- 3. silhouettes lointaines (Spire, tours, cheminées)
  local FAR = { LV.hillsBack, LV.hillsFront, LV.trees }
  for _, p in ipairs(sp.far or {}) do
    if PR[p[1]] then PR[p[1]](K, f, g, FAR, pal.far, pal, p[2], p[3], p[4] or 1, p[5], p[6]) end
  end
  -- brume de chaleur sur le lointain
  K.blur(f, g, LV.fieldsFar, pal.haze[1], Wd / 2, hz - 20, Wd * 1.7, 120, pal.haze[2])
  -- 4. parois proches : deux masses qui encadrent le décor
  local nw = sp.nearWall or { left = 210, right = 230, top = 70, seed = 3 }
  if nw.left and nw.left > 0 then
    ridge(K, f, g, LV.fieldsFar, slope(jag(K, -10, nw.left + 60, nw.top + 50, 46, 22, nw.seed, nil), fl + 20, "right", 0.8),
      fl + 20, 4, K.rgb(pal.wallNear[1]), K.rgb(pal.wallNear[2]))
  end
  if nw.right and nw.right > 0 then
    ridge(K, f, g, LV.fieldsFar, slope(jag(K, Wd - nw.right - 60, Wd + 10, nw.top + 40, 46, 22, nw.seed + 5, nil), fl + 20, "left", 0.8),
      fl + 20, 4, K.rgb(pal.wallNear[1]), K.rgb(pal.wallNear[2]))
  end
  -- reflets de lave sur les parois proches (bas des masses)
  if sp.lava then
    K.blur(f, g, LV.haze, gl[1], 90, hz + 30, 300, 120, gl[2] * 0.6)
    K.blur(f, g, LV.haze, gl[1], Wd - 100, hz + 30, 300, 120, gl[2] * 0.6)
  end
  -- 5. lac de lave : dégradé, croûtes sombres, reflets clairs, lueur au ras
  if sp.lava then
    local lv = pal.lava
    local y0, y1 = hz, sp.lava[2] or fl + 10
    local ym = y0 + (y1 - y0) * 0.35
    K.vgrad(f, g, LV.haze, K.rgb(lv[1]), K.rgb(lv[2]), 0, y0, Wd, ym - y0 + 1)
    K.vgrad(f, g, LV.haze, K.rgb(lv[2]), K.rgb(lv[4] or lv[2]), 0, ym, Wd, y1 - ym)
    -- plaques de croûte : petites et serrées au loin, larges devant (perspective)
    for k = 1, 56 do
      local t = K.hash(k, 62) ^ 0.8
      local cx = K.hash(k, 61) * Wd
      local cy = y0 + 3 + (y1 - y0 - 6) * t
      local w = (30 + 80 * K.hash(k, 63)) * (0.35 + 1.2 * t)
      K.blur(f, g, LV.far[1], pal.crust[1], cx, cy, w, w * (0.16 + 0.12 * t), pal.crust[2])
      K.oval(f, g, LV.far[1], pal.crust[1], cx, cy, w * 0.45, w * (0.06 + 0.05 * t), pal.crust[2] * 0.8)
    end
    -- veines claires entre les plaques
    for k = 1, 34 do
      local t = K.hash(k, 65) ^ 0.8
      local cx = K.hash(k, 64) * Wd
      local cy = y0 + 2 + (y1 - y0 - 4) * t
      K.bar(f, g, LV.far[2], lv[3], cx, cy, (8 + 30 * K.hash(k, 66)) * (0.4 + t), 0.8 + 1.6 * t,
        (K.hash(k, 67) - 0.5) * 0.25, 0.35 + 0.35 * K.hash(k, 68))
    end
    -- liseré brillant à l'horizon, chaleur qui monte
    K.box(f, g, LV.far[2], lv[3], 0, y0 - 1, Wd, 2, 0.45)
    K.blur(f, g, LV.far[2], lv[1], Wd / 2, y0 + 2, Wd * 1.4, 16, 0.4)
  end
  -- sol lointain entre l'horizon (ou le bord du lac) et le premier plan : jamais de trou noir
  do
    local y0 = sp.lava and (sp.lava[2] or fl + 10) - 2 or hz + 4
    if y0 < fl + 20 then
      K.vgrad(f, g, LV.haze, K.mix(pal.wallFar[2], pal.floor[1], 0.5), K.rgb(pal.floor[1]), 0, y0, Wd, fl + 22 - y0)
    end
    if not sp.lava then
      K.blur(f, g, LV.haze, pal.glow[1], Wd / 2, hz + 8, Wd * 1.2, 40, pal.glow[2] * 0.5)
    end
  end
  -- 6. pont de pierre (Molten Span) en perspective, parapets crénelés
  if sp.bridge then
    local r = sp.bridge
    local y0 = r.y0 or hz - 4
    local yy, k = y0, 0
    while yy < fl + 30 do
      local t = (yy - y0) / (fl + 30 - y0)
      local step = 1.4 + 2.2 * t
      local w = r[3] + (r[4] - r[3]) * t
      local cx = r[1] + (r[2] - r[1]) * t + (r[5] or 0) * sin(PI * t)
      local edge = 2 + 7 * t
      K.box(f, g, LV.far[3], pal.bridgeEdge, cx - w / 2 - edge, yy, w + 2 * edge, step + 0.6)
      K.box(f, g, LV.fieldsNear, K.mix(pal.bridge[2], pal.bridge[1], t), cx - w / 2, yy, w, step + 0.6)
      if k % 5 == 0 then K.box(f, g, LV.furrows, pal.bridgeEdge, cx - w / 2, yy, w, 0.8 + t, 0.5) end
      K.box(f, g, LV.furrows, pal.lava[1], cx - w / 2, yy, 1 + 2 * t, step + 0.6, 0.25)
      -- créneaux du parapet, tous les quelques tranches
      k = k + 1
      if k % 3 == 0 then
        local hh = 2 + 9 * t
        K.box(f, g, LV.furrows, pal.bridgeEdge, cx - w / 2 - edge, yy - hh, edge + 0.6, hh)
        K.box(f, g, LV.furrows, pal.bridgeEdge, cx + w / 2, yy - hh, edge + 0.6, hh)
      end
      yy = yy + step
    end
    -- lueur de la lave sous le tablier
    K.blur(f, g, LV.far[2], gl[1], r[1], y0 + 20, r[4] * 0.8, 50, 0.35)
  end
  -- 7. sol du premier plan : bord déchiqueté, dégradé, dalles ou roche, fissures de lave
  local fp = jag(K, -10, Wd + 10, fl, sp.floorAmp or 10, 24, sp.floorSeed or 9, nil)
  ridge(K, f, g, LV.roadEdge, fp, Hd + 2, 8, K.rgb(pal.floor[1]), K.rgb(pal.floor[2]))
  K.box(f, g, LV.road, pal.floorEdge, 0, fl - 1, Wd, 2, 0.35)
  K.blur(f, g, LV.road, pal.glow[1], Wd / 2, fl + 2, Wd * 1.3, 12, pal.glow[2] * 0.35)
  for k = 1, 14 do
    local rx = K.hash(k, 75) * Wd
    local rw = 8 + 16 * K.hash(k, 76)
    K.oval(f, g, LV.road, pal.floorEdge, rx, fl + 6 + 8 * K.hash(k, 77), rw, rw * 0.45, 0.7)
  end
  if sp.flagstones then
    for row = 0, 4 do
      local yr = fl + 8 + row * row * 5 + row * 10
      K.box(f, g, LV.road, pal.floorEdge, 0, yr, Wd, 1 + row * 0.5, 0.45)
      local n = 6 + row * 2
      for k = 0, n do
        local xx = (k + (row % 2) * 0.5) * Wd / n
        K.box(f, g, LV.road, pal.floorEdge, xx, yr, 1.2 + row * 0.4, 12 + row * 6, 0.35)
      end
    end
  end
  if sp.cracks ~= false then
    for k = 1, sp.cracks or 9 do
      local cx = K.hash(k, 71) * Wd
      local cy = fl + 12 + (Hd - fl - 20) * K.hash(k, 72)
      local len = 30 + 70 * K.hash(k, 73)
      local a = (K.hash(k, 74) - 0.5) * 0.7
      K.bar(f, g, LV.road, pal.lava[1], cx, cy, len, 2.2, a, 0.75)
      K.blur(f, g, LV.road, gl[1], cx, cy, len * 1.4, 16, 0.35)
    end
  end
  -- 8. accessoires du plan moyen, ombre fondue au pied
  local MID = { LV.mid[1], LV.mid[2], LV.mid[3] }
  for _, p in ipairs(sp.props or {}) do
    if PR[p[1]] then
      if p[5] ~= "nofloor" then K.blur(f, g, LV.road, pal.ground[1], p[2], p[3] - 1, 90 * (p[4] or 1), 14 * (p[4] or 1), 0.5) end
      PR[p[1]](K, f, g, MID, pal.mid, pal, p[2], p[3], p[4] or 1, p[6], p[7])
    end
  end
  -- 9. voûte et stalactites (cadre du haut), chaînes
  local ce = sp.ceiling or { y = 34, amp = 26, seed = 5 }
  if ce.y then
    ridge(K, f, g, LV.stalks, jag(K, -10, Wd + 10, ce.y, ce.amp, 30, ce.seed, 30, 1), 0, 6,
      K.rgb(pal.ceiling[1]), K.rgb(pal.ceiling[2]), true)
    for k = 1, ce.stalactites or 14 do
      local x = K.hash(k, 81) * Wd
      local w = 10 + 22 * K.hash(k, 82)
      local h = 24 + 60 * K.hash(k, 83)
      itri(K, f, g, LV.stalks, pal.ceiling[2], x, ce.y + 10, w, h, 3)
    end
  end
  for _, ch in ipairs(sp.chains or {}) do chain(K, f, g, LV.ears, pal.chain, ch[1], ch[2], ch[3] or 1) end
  -- 10. stalagmites du premier plan (aux bords) et voile du bas
  -- masses rocheuses de coin : silhouette déchiquetée en dôme, dégradé vers le noir
  for i, st in ipairs(sp.stalagmites or {}) do
    local x0, x1 = st[1] - st[2], st[1] + st[2]
    local pts = jag(K, x0, x1, Hd + 4, st[3], 10, 60 + i, nil)
    for _, p in ipairs(pts) do
      local u = (p[1] - x0) / (x1 - x0)
      p[2] = Hd + 4 - (Hd + 4 - p[2]) * (1 - (2 * u - 1) ^ 2) ^ 0.6
    end
    ridge(K, f, g, LV.stalks, pts, Hd + 4, 3, K.rgb(pal.wallNear[2]), K.rgb(pal.ceiling[1]))
  end
  local gr = pal.ground
  K.vgrad(f, g, LV.ground, K.withAlpha(gr[1], 0), K.withAlpha(gr[1], gr[2]), 0, Hd - 120, Wd, 120)
  -- 11. braises qui montent
  for k = 1, sp.embers or 34 do
    local x = K.hash(k, 91) * Wd
    local y = 30 + (Hd - 60) * K.hash(k, 92)
    local d = 1.6 + 2.6 * K.hash(k, 93)
    K.oval(f, g, LV.smoke, k % 3 == 0 and pal.fire[3] or pal.fire[2], x, y, d, d, 0.35 + 0.5 * K.hash(k, 94))
  end
end

-- Palettes (mêmes clés pour les six décors ; voir le peintre ci-dessus)
local BASE = {
  back = { "#07040a", "#1d0d0b", "#4a1a0c" }, glow = { "#ff6a1a", 0.55 }, smoke = { "#120a0a", 0.6 },
  haze = { "#a8401a", 0.22 },
  wallFar = { "#2a1410", "#4a1c10" }, wallNear = { "#130b0a", "#2a1210" }, ceiling = { "#0a0607", "#1a0e0c" },
  lava = { "#f08a28", "#b4320e", "#ffd47a", "#460e05" }, crust = { "#1a0704", 0.82 },
  bridge = { "#5a4438", "#2e2220" }, bridgeEdge = "#1a1210",
  floor = { "#33231e", "#120b0a" }, floorEdge = "#0c0706",
  far = { main = "#24120e", dark = "#160a08", light = "#ff9a40" },
  mid = { main = "#3a2a24", dark = "#140c0a", light = "#6a5a50", wood = "#5a3a22", crate = "#7a5432", cloth = "#8a1a12" },
  fire = { "#ff7a20", "#ffb84a", "#fff2c0" }, chain = "#0c0808", ground = { "#050303", 0.7 },
}
local function palette(over)
  local p = {}
  for k, v in pairs(BASE) do p[k] = v end
  for k, v in pairs(over or {}) do p[k] = v end
  return p
end
Art.palettes.blackrock = palette()
-- Detention Block : pierre froide, torches, peu de lave
Art.palettes.blackrock_prison = palette({ back = { "#050407", "#110c0d", "#2a1612" }, glow = { "#ff7a28", 0.32 },
  wallFar = { "#1c1414", "#2c1e1a" }, wallNear = { "#100c0c", "#22181a" }, floor = { "#2e2624", "#0e0a0a" },
  haze = { "#7a3a20", 0.14 }, mid = { main = "#3e3430", dark = "#141010", light = "#8a7e74", wood = "#4a3424",
  crate = "#6a4a30", cloth = "#7a1a12" } })
-- Grim Guzzler : bois chaud, lanternes, bière
Art.palettes.blackrock_tavern = palette({ back = { "#080505", "#1e120c", "#3e2412" }, glow = { "#ffae48", 0.42 },
  wallFar = { "#2a1a12", "#3a2414" }, wallNear = { "#140c08", "#2a1a10" }, floor = { "#3e2a1a", "#140c08" },
  haze = { "#a0602a", 0.14 }, fire = { "#ff9a30", "#ffd070", "#fff4d0" } })
-- Forge de la Black Anvil, la nuit (feu de camp) : plus sombre, l'âtre seul éclaire
Art.palettes.blackrock_forge = palette({ back = { "#040305", "#0c0708", "#2a0f08" }, glow = { "#ff5a14", 0.4 },
  wallFar = { "#1a0d0a", "#2a120c" }, wallNear = { "#0a0606", "#180c0a" }, floor = { "#241a16", "#080505" },
  haze = { "#8a2e14", 0.16 }, ground = { "#020101", 0.78 } })
-- Blackwing Lair : salle du trône, ombre violette et feu de dragon
Art.palettes.blackrock_lair = palette({ back = { "#06030a", "#160a1a", "#3a1220" }, glow = { "#c03a6a", 0.42 },
  wallFar = { "#1e1020", "#34162a" }, wallNear = { "#0e0810", "#1e0e1a" }, floor = { "#2a2028", "#0c080c" },
  haze = { "#6a2a5a", 0.18 }, smoke = { "#0a050c", 0.6 },
  far = { main = "#1e0e1c", dark = "#120812", light = "#ff6a8a" },
  mid = { main = "#3a2a34", dark = "#120a10", light = "#c8b8a8", wood = "#4a2a2a", crate = "#6a3a3a", cloth = "#5a0e1a" } })

local CEIL = { y = 30, amp = 24, seed = 5, stalactites = 16 }
Art.paintings = Art.paintings or {}
-- Molten Span : le pont au-dessus du lac de lave, la cité des Sombrefer au loin
Art.paintings.blackrock_span = { painter = "cavern", pal = "blackrock", horizon = 216, floor = 304,
  lava = { 216, 312 }, bridge = { 520, 520, 26, 300, 0 }, glows = { 300, 760 },
  farWall = { amp = 78, edge = 60, seed = 2 }, nearWall = { left = 150, right = 160, top = 96, seed = 3 },
  far = { { "tower", 330, 218, 0.9 }, { "tower", 404, 220, 0.6 }, { "chimney", 640, 220, 0.8 }, { "tower", 720, 220, 1.0 },
    { "chimney", 268, 220, 0.6 }, { "lavafall", 812, 222, 1.0, nil, 96 } },
  props = { { "brazier", 132, 318, 1.0 }, { "brazier", 902, 318, 1.0 }, { "rocks", 60, 380, 1.0 } },
  ceiling = CEIL, chains = { { 470, 90 }, { 590, 70 } }, stalagmites = { { 10, 80, 110 }, { 1026, 90, 130 } },
  cracks = 8 }
-- Detention Block : rangée de cellules dans un mur de blocs, torches, dalles
Art.paintings.blackrock_prison = { painter = "cavern", pal = "blackrock_prison", horizon = 292, floor = 302,
  farWall = { amp = 190, edge = 40, seed = 7 }, nearWall = { left = 110, right = 110, top = 60, seed = 4 },
  props = { { "blocks", 150, 300, 1.0, "nofloor", nil, 884 }, { "cell", 330, 300, 1.0 }, { "cell", 520, 300, 1.0 },
    { "cell", 710, 300, 1.0 }, { "torch", 425, 196, 1.2, "nofloor" }, { "torch", 615, 196, 1.2, "nofloor" },
    { "brazier", 160, 322, 1.0 }, { "brazier", 880, 322, 1.0 } },
  ceiling = { y = 26, amp = 14, seed = 8, stalactites = 8 }, chains = { { 250, 120 }, { 800, 140 } },
  flagstones = true, cracks = 0, embers = 14, stalagmites = { { 8, 60, 90 } } }
-- Blackrock Spire : Hordemar City, le piton, tentes et bannières du clan
Art.paintings.blackrock_spire = { painter = "cavern", pal = "blackrock", horizon = 226, floor = 300,
  lava = { 226, 296 }, glows = { 520 },
  farWall = { amp = 60, edge = 90, seed = 11 }, nearWall = { left = 120, right = 130, top = 110, seed = 12 },
  far = { { "spire", 520, 232, 1.0 }, { "lavafall", 300, 230, 0.8, nil, 110 }, { "chimney", 760, 232, 0.6 } },
  props = { { "tent", 220, 318, 1.2 }, { "tent", 830, 316, 1.1 }, { "banner", 330, 322, 1.0 }, { "banner", 700, 322, 1.0 },
    { "brazier", 520, 330, 1.1 } },
  ceiling = { y = 22, amp = 20, seed = 13, stalactites = 12 }, stalagmites = { { 10, 70, 100 }, { 1024, 80, 120 } } }
-- Grim Guzzler : comptoir, étagères de bouteilles, tonneaux, lanternes, cheminée
Art.paintings.blackrock_tavern = { painter = "cavern", pal = "blackrock_tavern", horizon = 294, floor = 304,
  farWall = { amp = 190, edge = 30, seed = 17 }, nearWall = { left = 100, right = 110, top = 70, seed = 18 },
  props = { { "hearth", 870, 300, 0.6 }, { "shelf", 320, 228, 1.0, "nofloor", nil, 470 }, { "shelf", 530, 228, 1.0, "nofloor", nil, 680 },
    { "counter", 300, 312, 1.0, nil, nil, 690 }, { "barrel", 210, 314, 1.1 }, { "barrel", 180, 316, 0.9 },
    { "barrel", 770, 314, 1.0, nil, "lying" }, { "barrel", 820, 330, 1.2 }, { "lantern", 360, 120, 1.0, "nofloor" },
    { "lantern", 640, 110, 1.0, "nofloor" } },
  ceiling = { y = 24, amp = 12, seed = 19, stalactites = 6 }, flagstones = true, cracks = 0, embers = 10 }
-- Forge de la Black Anvil, la nuit : âtre, enclume, rigole de lave
Art.paintings.blackrock_forge = { painter = "cavern", pal = "blackrock_forge", horizon = 288, floor = 300,
  glows = { 520 },
  farWall = { amp = 170, edge = 50, seed = 23 }, nearWall = { left = 150, right = 160, top = 80, seed = 24 },
  far = { { "chimney", 330, 288, 0.9 }, { "lavafall", 760, 288, 0.8, nil, 120 } },
  props = { { "hearth", 540, 304, 1.2 }, { "anvil", 300, 322, 1.0 }, { "rocks", 780, 330, 1.2 }, { "brazier", 880, 322, 0.9 } },
  ceiling = CEIL, chains = { { 640, 110 } }, stalagmites = { { 8, 70, 100 }, { 1026, 76, 120 } }, embers = 26 }
-- Blackwing Lair : le trône de Nefarian, piliers, crâne de dragon (combat final)
Art.paintings.blackrock_lair = { painter = "cavern", pal = "blackrock_lair", horizon = 280, floor = 306,
  farWall = { amp = 150, edge = 70, seed = 29 }, nearWall = { left = 90, right = 90, top = 60, seed = 30 },
  glows = { 517 }, far = { { "pillar", 300, 300, 1.0, nil, 230 }, { "pillar", 734, 300, 1.0, nil, 230 } },
  props = { { "throne", 517, 312, 1.0 }, { "skull", 150, 334, 1.1 }, { "banner", 400, 312, 1.1 },
    { "banner", 634, 312, 1.1 } },
  ceiling = { y = 28, amp = 18, seed = 31, stalactites = 10 }, flagstones = true, cracks = 4,
  stalagmites = { { 6, 60, 90 }, { 1028, 60, 90 } } }

for _, k in ipairs({ "span", "prison", "spire", "tavern", "forge", "lair" }) do
  Art.scenes["blackrock_" .. k] = { paint = "blackrock_" .. k }
end
