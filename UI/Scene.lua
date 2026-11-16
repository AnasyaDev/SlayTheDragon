-- Scène commune à tous les écrans : décor plein cadre en haut (illustration embarquée dans l'addon,
-- Media/Backgrounds, sur un décor peint en couches unies aux couleurs des maquettes), plateau en bas, personnages
-- (modèle 3D avec ombre au sol). Coordonnées : celles des maquettes, depuis le coin haut gauche de
-- la zone intérieure (1034 × 614), x vers la droite, y vers le bas.
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art = ns.Widgets, ns.Art
local C = Art.C

local S = {}
ns.Scene = S

S.W, S.H = 1034, 614
S.TOP, S.DECOR_H = 34, 390      -- bande du décor : y 34 à 424 (sous la barre de titre du cadre métal)
S.BOARD_Y, S.BOARD_H = 424, 190 -- plateau : y 424 à 614
S.GROUND_H, S.GROUND_ALPHA = 170, 0.38 -- voile du bas de l'illustration (hauteur, opacité en bas)

local function opts() return ns.Persist.options() end

-- Place une région (texture ou cadre) dans un cadre, coordonnées de maquette.
local function at(region, parent, x, y, w, h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
  if w then region:SetSize(w, h) end
  return region
end
S.at = at

---------------------------------------------------------------------------
-- Décors peints (repli et sous-couche)
---------------------------------------------------------------------------

local PAINT = {}

-- Collines : bande unie + ellipses sur le bord haut (ondulation).
local function hills(g, f, y, color, bumps, sub)
  local band = W.rect(f, "BACKGROUND", sub, color)
  at(band, f, 0, y, S.W, S.DECOR_H - y)
  g[#g + 1] = band
  for i = 1, #bumps do
    local b = bumps[i]
    local e = W.disc(f, "BACKGROUND", sub, color)
    at(e, f, b[1] - b[2] / 2, y - b[3] / 2, b[2], b[3])
    g[#g + 1] = e
  end
end

local function sky(g, f, top, bottom)
  local s = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  W.gradient(s, top, bottom)
  at(s, f, 0, 0, S.W, S.DECOR_H)
  g[#g + 1] = s
end

function PAINT.fields(f, g)
  sky(g, f, { 0.95, 0.84, 0.54 }, { 0.91, 0.77, 0.42 })
  local sun = W.disc(f, "BACKGROUND", -7, Art.hex("#f8e6ae"))
  at(sun, f, 774, 46, 92, 92)
  g[#g + 1] = sun
  hills(g, f, 170, Art.hex("#c9973f"), { { 180, 520, 70 }, { 560, 420, 40 }, { 900, 380, 50 } }, -6)
  -- moulin
  local post = W.rect(f, "BACKGROUND", -5, C.wood)
  at(post, f, 616, 92, 8, 82)
  g[#g + 1] = post
  for i = 0, 3 do
    local blade = W.rect(f, "BACKGROUND", -5, C.wood)
    at(blade, f, 586, 89, 68, 6)
    if blade.SetRotation then blade:SetRotation(i * math.pi / 4 + 0.3) end
    g[#g + 1] = blade
  end
  hills(g, f, 215, Art.hex("#b07d2c"), { { 260, 600, 60 }, { 780, 520, 40 } }, -4)
  hills(g, f, 262, Art.hex("#8a5f22"), { { 300, 640, 50 }, { 820, 520, 34 } }, -3)
  local ground = W.rect(f, "BACKGROUND", -2, Art.hex("#6f4a1b"))
  at(ground, f, 0, 300, S.W, 80)
  g[#g + 1] = ground
  local blades = { 40, 70, 100, 130, 470, 500, 530, 900, 930, 960, 990 }
  for i, x in ipairs(blades) do
    local h = 20 + (i * 7) % 12
    local t = W.rect(f, "BACKGROUND", -1, Art.hex("#d9a94a"))
    at(t, f, x, 300 - h, 3, h)
    g[#g + 1] = t
  end
end

function PAINT.farm(f, g)
  PAINT.fields(f, g)
  local wall = W.rect(f, "BACKGROUND", -3, Art.hex("#9a5a34"))
  at(wall, f, 360, 150, 180, 100)
  g[#g + 1] = wall
  local roofL = W.rect(f, "BACKGROUND", -3, Art.hex("#5c3418"))
  at(roofL, f, 340, 118, 124, 12)
  if roofL.SetRotation then roofL:SetRotation(0.55) end
  local roofR = W.rect(f, "BACKGROUND", -3, Art.hex("#5c3418"))
  at(roofR, f, 436, 118, 124, 12)
  if roofR.SetRotation then roofR:SetRotation(-0.55) end
  local door = W.rect(f, "BACKGROUND", -2, Art.hex("#5c3418"))
  at(door, f, 428, 190, 44, 60)
  local win = W.rect(f, "BACKGROUND", -2, Art.hex("#f8e6ae"))
  at(win, f, 382, 170, 30, 30)
  for _, t in ipairs({ roofL, roofR, door, win }) do g[#g + 1] = t end
  for i = 0, 3 do
    local p = W.rect(f, "BACKGROUND", -2, Art.hex("#5c3418"))
    at(p, f, 600 + i * 40, 240, 5, 40)
    g[#g + 1] = p
  end
  for _, y in ipairs({ 248, 262 }) do
    local r = W.rect(f, "BACKGROUND", -2, Art.hex("#5c3418"))
    at(r, f, 590, y, 130, 5)
    g[#g + 1] = r
  end
end

function PAINT.cave(f, g)
  sky(g, f, { 0.12, 0.08, 0.06 }, { 0.2, 0.14, 0.09 })
  hills(g, f, 120, Art.hex("#2f2016"), { { 200, 500, 80 }, { 760, 600, 60 } }, -6)
  hills(g, f, 230, Art.hex("#3a2618"), { { 300, 600, 40 }, { 840, 500, 50 } }, -4)
  local ground = W.rect(f, "BACKGROUND", -2, Art.hex("#4a3220"))
  at(ground, f, 0, 300, S.W, 80)
  g[#g + 1] = ground
  for _, x in ipairs({ 60, 340, 700, 960 }) do
    local beam = W.rect(f, "BACKGROUND", -3, Art.hex("#5c3418"))
    at(beam, f, x, 40, 14, 260)
    g[#g + 1] = beam
    local glow = W.disc(f, "BACKGROUND", -1, C.gold, 0.35)
    at(glow, f, x - 23, 70, 60, 60)
    g[#g + 1] = glow
    local lamp = W.disc(f, "BACKGROUND", 0, Art.hex("#fff3cf"))
    at(lamp, f, x - 1, 92, 16, 16)
    g[#g + 1] = lamp
  end
  local top = W.rect(f, "BACKGROUND", -3, Art.hex("#5c3418"))
  at(top, f, 0, 40, S.W, 12)
  g[#g + 1] = top
end

function PAINT.coast(f, g)
  sky(g, f, { 0.95, 0.86, 0.6 }, { 0.85, 0.82, 0.62 })
  local sun = W.disc(f, "BACKGROUND", -7, Art.hex("#f8e6ae"))
  at(sun, f, 160, 40, 80, 80)
  g[#g + 1] = sun
  hills(g, f, 160, Art.hex("#4f7f8f"), {}, -6)
  local swell = W.rect(f, "BACKGROUND", -5, Art.hex("#6f9fa8"))
  at(swell, f, 0, 190, S.W, 6)
  g[#g + 1] = swell
  local tower = W.rect(f, "BACKGROUND", -5, Art.hex("#e8e2d0"))
  at(tower, f, 840, 70, 30, 120)
  local cap = W.rect(f, "BACKGROUND", -5, Art.hex("#7a2a1e"))
  at(cap, f, 834, 60, 42, 16)
  g[#g + 1] = tower
  g[#g + 1] = cap
  hills(g, f, 236, Art.hex("#d9b97a"), { { 300, 700, 50 }, { 900, 400, 30 } }, -4)
  hills(g, f, 280, Art.hex("#b08f52"), { { 600, 900, 30 } }, -3)
  local ground = W.rect(f, "BACKGROUND", -2, Art.hex("#8a6a3a"))
  at(ground, f, 0, 310, S.W, 70)
  g[#g + 1] = ground
end

---------------------------------------------------------------------------
-- Paysages peints par plans (Art.paintings, palettes Art.palettes) : décors à part entière
---------------------------------------------------------------------------
-- Formes : rectangles et dégradés unis, disques (Media/mask_disc), taches fondues (Media/shadow_soft,
-- la texture de l'ombre de contact : nuages, halos, brume, fumée), rectangles tournés autour de leur
-- centre (Texture:SetRotation : ailes, toits en losange, barrières), triangles en tranches (tentes).
-- Ordre de dessin : chaque plan a sa couche et son sous-niveau (BACKGROUND -8 à 7, puis BORDER -8 à
-- -3, sous l'illustration en BORDER 0, absente de ces décors) ; à niveau égal ne se chevauchent que des
-- formes de même couleur, des voiles translucides ou des bords d'un pixel : l'ordre du client à niveau
-- égal (non garanti) ne change donc rien de visible.
-- Rien n'est tiré au hasard : les variations (épis, damier des champs, étoiles) viennent d'une suite
-- fixe (hash), le décor est le même à chaque affichage.
local LV = {
  sky = { "BACKGROUND", -8 }, sun = { "BACKGROUND", -7 }, clouds = { "BACKGROUND", -6 },
  hillsBack = { "BACKGROUND", -5 }, hillsFront = { "BACKGROUND", -4 }, trees = { "BACKGROUND", -3 },
  fieldsFar = { "BACKGROUND", -2 }, haze = { "BACKGROUND", -1 },
  far = { { "BACKGROUND", 0 }, { "BACKGROUND", 1 }, { "BACKGROUND", 2 } },
  fieldsNear = { "BACKGROUND", 3 }, furrows = { "BACKGROUND", 4 },
  roadEdge = { "BACKGROUND", 5 }, road = { "BACKGROUND", 6 },
  mid = { { "BACKGROUND", 7 }, { "BORDER", -8 }, { "BORDER", -7 } },
  ground = { "BORDER", -6 }, stalks = { "BORDER", -5 }, ears = { "BORDER", -4 }, smoke = { "BORDER", -3 },
  -- plan du fond (lisière de forêt derrière la brume de l'horizon : Duskwood), couleurs pal.back
  back = { { "BACKGROUND", -3 }, { "BACKGROUND", -3 }, { "BACKGROUND", -3 } },
}
S.LANDSCAPE_LEVELS = LV

local sin, cos, floor, PI = math.sin, math.cos, math.floor, math.pi

-- Suite fixe dans [0, 1[ (pas de hasard : même décor à chaque fois).
local function hash(i, k)
  local v = sin(i * 12.9898 + (k or 0) * 78.233) * 43758.5453
  return v - floor(v)
end

local colors = {}
local function rgb(c)
  if type(c) ~= "string" then return c end
  local v = colors[c]
  if not v then v = Art.hex(c) colors[c] = v end
  return v
end
local function mix(a, b, t)
  a, b = rgb(a), rgb(b)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
local function withAlpha(c, a)
  c = rgb(c)
  return { c[1], c[2], c[3], a }
end

local function put(g, t) g[#g + 1] = t return t end

local function box(f, g, lv, c, x, y, w, h, a)
  local t = put(g, W.rect(f, lv[1], lv[2], rgb(c), a))
  at(t, f, x, y, w, h)
  return t
end

local function vgrad(f, g, lv, top, bottom, x, y, w, h)
  local t = put(g, f:CreateTexture(nil, lv[1], nil, lv[2]))
  W.gradient(t, top, bottom)
  at(t, f, x, y, w, h)
  return t
end

local function oval(f, g, lv, c, cx, cy, w, h, a)
  local t = put(g, W.disc(f, lv[1], lv[2], rgb(c), a))
  at(t, f, cx - w / 2, cy - h / 2, w, h)
  return t
end

local function blur(f, g, lv, c, cx, cy, w, h, a)
  local t = put(g, f:CreateTexture(nil, lv[1], nil, lv[2]))
  t:SetTexture(S.SHADOW, nil, nil, "TRILINEAR")
  c = rgb(c)
  t:SetVertexColor(c[1], c[2], c[3], a or 1)
  at(t, f, cx - w / 2, cy - h / 2, w, h)
  return t
end

-- Rectangle de len × th centré en (cx, cy), tourné de `angle` (radians, sens trigonométrique).
local function bar(f, g, lv, c, cx, cy, len, th, angle, a)
  local t = box(f, g, lv, c, cx - len / 2, cy - th / 2, len, th, a)
  if angle and angle ~= 0 and t.SetRotation then t:SetRotation(angle) end
  return t
end

-- Losange (carré tourné d'un quart) de demi-diagonale hd centré en (cx, cy) : toit à deux pans dont la
-- moitié basse est cachée par le mur, dessiné au-dessus.
local function diamond(f, g, lv, c, cx, cy, hd)
  local side = hd * 1.41421356
  return bar(f, g, lv, c, cx, cy, side, side, PI / 4)
end

-- Triangle isocèle (pointe en haut) de base w posée en (cx, by), hauteur h : tranches de 2 unités.
local function tri(f, g, lv, c, cx, by, w, h)
  local n = math.max(1, floor(h / 2 + 0.5))
  local sh = h / n
  for i = 1, n do
    local ww = w * (i - 0.5) / n
    box(f, g, lv, c, cx - ww / 2, by - h + (i - 1) * sh, ww, sh + 0.4)
  end
end

-- Accessoires : (f, g, plan = niveaux { fond, masse, détails }, couleurs du plan, palette, x, y du pied,
-- échelle, variante).
local PROPS = {}

-- Moulin : tour de pierre qui s'affine, chapeau, deux bras et quatre ailes à claire-voie.
function PROPS.windmill(f, g, P, c, pal, x, y, s)
  local hw = { 16, 13.5, 11 }
  for i = 1, 3 do box(f, g, P[1], c.main, x - hw[i] * s, y - 22 * i * s, 2 * hw[i] * s, 22 * s + 1) end
  box(f, g, P[3], c.dark, x - 4 * s, y - 14 * s, 8 * s, 14 * s)
  diamond(f, g, P[2], c.dark, x, y - 66 * s, 10 * s)
  local hx, hy, a0 = x, y - 60 * s, 0.38
  for k = 0, 1 do bar(f, g, P[2], c.dark, hx, hy, 100 * s, 2.4 * s, a0 + k * PI / 2) end
  for k = 0, 3 do
    local th = a0 + k * PI / 2
    local dx, dy, px, py = cos(th), -sin(th), sin(th), cos(th)
    bar(f, g, P[2], c.dark, hx + dx * 29 * s + px * 4.5 * s, hy + dy * 29 * s + py * 4.5 * s, 36 * s, 9 * s, th, 0.75)
  end
  if c.light then box(f, g, P[3], c.light, x - 2.5 * s, y - 40 * s, 5 * s, 7 * s) end
end

-- Ferme : mur, toit en losange, cheminée, porte ; fenêtres éclairées la nuit.
local function house(f, g, P, c, x, y, s, hw, wh, hd, chimney)
  local eave = y - wh * s
  diamond(f, g, P[1], c.dark, x, eave, hd * s)
  if chimney then box(f, g, P[1], c.dark, x + 12 * s, eave - 30 * s, 6 * s, 18 * s) end
  box(f, g, P[2], c.main, x - hw * s, eave, 2 * hw * s, wh * s + 1)
  box(f, g, P[3], c.dark, x - 4 * s, y - 15 * s, 8 * s, 15 * s)
  if c.light then
    box(f, g, P[3], c.light, x - (hw - 7) * s, eave + 8 * s, 7 * s, 8 * s)
    box(f, g, P[3], c.light, x + (hw - 14) * s, eave + 8 * s, 7 * s, 8 * s)
  end
end
function PROPS.farmhouse(f, g, P, c, pal, x, y, s) house(f, g, P, c, x, y, s, 32, 35, 35, true) end
function PROPS.shed(f, g, P, c, pal, x, y, s) house(f, g, P, c, x, y, s, 24, 25, 25, false) end

-- Tour de Sentinel Hill : fût de pierre, chemin de ronde, toit pointu, meurtrières, bannière.
function PROPS.tower(f, g, P, c, pal, x, y, s)
  local top = y - 92 * s
  diamond(f, g, P[1], c.dark, x, top - 5 * s, 19 * s)
  box(f, g, P[2], c.main, x - 12 * s, top, 24 * s, 96 * s)
  box(f, g, P[2], c.main, x - 16 * s, top - 6 * s, 32 * s, 8 * s)
  for i = 0, 1 do
    box(f, g, P[3], c.light or c.dark, x - 2 * s, top + (24 + 28 * i) * s, 4 * s, 9 * s)
  end
  box(f, g, P[3], c.dark, x - 0.8 * s, top - 40 * s, 1.6 * s, 22 * s)
  box(f, g, P[3], pal.flag, x + 0.8 * s, top - 40 * s, 15 * s, 9 * s)
end

-- Tente : toile en triangle, ouverture sombre, mât.
function PROPS.tent(f, g, P, c, pal, x, y, s)
  tri(f, g, P[1], c.wood, x, y, 64 * s, 42 * s)
  tri(f, g, P[2], c.dark, x + 5 * s, y, 20 * s, 26 * s)
  box(f, g, P[3], c.dark, x - 1.2 * s, y - 49 * s, 2.4 * s, 9 * s)
end

-- Charrette : caisse, brancards, deux roues ; variante « crates » : chargée de caisses.
function PROPS.cart(f, g, P, c, pal, x, y, s, variant)
  bar(f, g, P[1], c.dark, x + 52 * s, y - 20 * s, 44 * s, 3 * s, -0.22)
  box(f, g, P[2], c.wood, x - 36 * s, y - 38 * s, 72 * s, 20 * s)
  box(f, g, P[3], c.dark, x - 36 * s, y - 30 * s, 72 * s, 1.5 * s)
  oval(f, g, P[3], c.dark, x - 20 * s, y - 13 * s, 26 * s, 26 * s)
  oval(f, g, P[3], c.dark, x + 20 * s, y - 13 * s, 26 * s, 26 * s)
  if variant == "crates" then
    box(f, g, P[2], c.crate, x - 32 * s, y - 56 * s, 20 * s, 17 * s)
    box(f, g, P[2], c.crate, x - 9 * s, y - 52 * s, 16 * s, 13 * s)
    box(f, g, P[2], c.crate, x + 10 * s, y - 60 * s, 22 * s, 21 * s)
    box(f, g, P[2], c.crate, x - 25 * s, y - 70 * s, 14 * s, 12 * s)
  end
end

-- Épouvantail : piquet, bras, manteau, tête, chapeau.
function PROPS.scarecrow(f, g, P, c, pal, x, y, s)
  box(f, g, P[1], c.dark, x - 1.5 * s, y - 72 * s, 3 * s, 72 * s)
  bar(f, g, P[1], c.dark, x, y - 54 * s, 54 * s, 3 * s, 0.06)
  box(f, g, P[2], c.main, x - 9 * s, y - 56 * s, 18 * s, 26 * s)
  bar(f, g, P[2], c.main, x - 16 * s, y - 52 * s, 16 * s, 6 * s, 0.12)
  bar(f, g, P[2], c.main, x + 16 * s, y - 54 * s, 16 * s, 6 * s, 0.02)
  oval(f, g, P[2], c.main, x, y - 63 * s, 11 * s, 12 * s)
  box(f, g, P[3], c.dark, x - 11 * s, y - 69 * s, 22 * s, 2.5 * s)
  box(f, g, P[3], c.dark, x - 5 * s, y - 77 * s, 10 * s, 8 * s)
end

-- Foyer : bûches, braises, fumée en taches fondues qui s'élargissent et dérivent.
function PROPS.smoke(f, g, P, c, pal, x, y, s)
  bar(f, g, P[1], c.dark, x - 4 * s, y - 3 * s, 18 * s, 3 * s, 0.35)
  bar(f, g, P[1], c.dark, x + 4 * s, y - 3 * s, 18 * s, 3 * s, -0.35)
  blur(f, g, P[2], "#ff9a3c", x, y - 6 * s, 30 * s, 18 * s, 0.6)
  oval(f, g, P[3], "#ffd27a", x, y - 6 * s, 7 * s, 9 * s, 0.9)
  local sm = pal.smoke
  for i = 1, 7 do
    local t = i / 7
    blur(f, g, LV.smoke, sm[1], x + 34 * t * t * s + 5 * sin(i * 2.1), y - 22 * s - 150 * t * s,
      (14 + 64 * t) * s, (14 + 50 * t) * s, sm[2] * (0.45 + 0.4 * t) * (1.2 - t))
  end
end

-- Barrière de (x, y) à (x2, y2) : deux lisses, poteaux tous les 34 environ.
local function fence(f, g, P, c, x, y, x2, y2)
  local dx, dy = x2 - x, y2 - y
  local len = math.sqrt(dx * dx + dy * dy)
  local ang = math.atan2(-dy, dx)
  for _, h in ipairs({ 16, 8 }) do bar(f, g, P[1], c.dark, (x + x2) / 2, (y + y2) / 2 - h, len, 2, ang) end
  local n = floor(len / 34)
  for i = 0, n do
    local t = n > 0 and i / n or 0
    box(f, g, P[2], c.main, x + dx * t - 1.5, y + dy * t - 22, 3, 23)
  end
end

-- Forêt, cimetière et bourg de nuit (Duskwood, 13/11/2026) : accessoires génériques. Couleurs du plan :
-- main (masse), dark (ombres, troncs), light (lanternes, fenêtres), rim (liseré de lune, { couleur, alpha }) ;
-- palette : glow (lueur des lanternes), web (toiles).
-- Branche de (x, y) dans la direction ang (radians, 0 = droite, π/2 = haut), qui se divise depth fois.
local function branch(f, g, lv, c, x, y, len, th, ang, depth, seed)
  local dx, dy = cos(ang), -sin(ang)
  bar(f, g, lv, c, x + dx * len / 2, y + dy * len / 2, len + th * 0.5, th, ang)
  if depth > 0 then
    local ex, ey = x + dx * len, y + dy * len
    local spread = 0.4 + 0.35 * hash(seed, depth)
    branch(f, g, lv, c, ex, ey, len * 0.66, math.max(1, th * 0.62), ang + spread, depth - 1, seed * 3 + 1)
    branch(f, g, lv, c, ex, ey, len * 0.58, math.max(1, th * 0.58), ang - spread * 0.85, depth - 1, seed * 3 + 2)
  end
end

-- Fût qui s'affine de bas en haut (trois tronçons).
local function trunk(f, g, lv, c, x, y, w, h)
  for i = 0, 2 do
    local ww = w * (1 - 0.22 * i)
    box(f, g, lv, c, x - ww / 2, y - h * (i + 1) / 3, ww, h / 3 + 1)
  end
end

-- Arbre mort tordu : fût penché, trois branches maîtresses divisées deux fois.
function PROPS.deadtree(f, g, P, c, pal, x, y, s, variant)
  local seed = floor(x * 7 + y * 3)
  local h = 96 * s
  trunk(f, g, P[1], c.dark, x, y, 11 * s, h)
  local tops = { { 0.95, 1.75 }, { 0.72, 0.62 }, { 0.82, 2.55 } }
  for k, t in ipairs(tops) do
    local ang = t[2] + (hash(seed, k) - 0.5) * 0.3
    branch(f, g, P[2], c.dark, x + (k - 2) * 2 * s, y - h * t[1], (34 + 12 * hash(seed, k + 3)) * s, 4.2 * s, ang, 2, seed + k)
  end
  -- racines
  bar(f, g, P[1], c.dark, x - 9 * s, y - 2 * s, 18 * s, 3 * s, 0.35)
  bar(f, g, P[1], c.dark, x + 9 * s, y - 2 * s, 18 * s, 3 * s, -0.35)
end

-- Feuillu sombre : fût, houppier en disques qui se chevauchent, liseré de lune sur le haut.
function PROPS.oak(f, g, P, c, pal, x, y, s)
  local seed = floor(x * 5 + y)
  trunk(f, g, P[1], c.dark, x, y, 10 * s, 70 * s)
  bar(f, g, P[1], c.dark, x - 12 * s, y - 62 * s, 28 * s, 3.5 * s, 2.4)
  bar(f, g, P[1], c.dark, x + 12 * s, y - 66 * s, 26 * s, 3.5 * s, 0.75)
  local cy = y - 96 * s
  for k = 1, 7 do
    local a = k / 7 * 2 * PI
    local r = (22 + 10 * hash(seed, k)) * s
    oval(f, g, P[2], c.main, x + cos(a) * 26 * s, cy - sin(a) * 18 * s, r * 1.7, r * 1.4)
  end
  oval(f, g, P[2], c.main, x, cy, 70 * s, 56 * s)
  if c.rim then
    for k = 1, 3 do
      local rx = x - 14 * s + (k - 2) * 18 * s
      blur(f, g, P[3], c.rim[1], rx, cy - 30 * s + math.abs(k - 2) * 8 * s, 40 * s, 22 * s, c.rim[2])
    end
  end
end

-- Sapin : triangle en tranches (pointe en haut) aux bords lissés par deux barres tournées, sur un fût court.
local function spire(f, g, lv, c, cx, by, w, h)
  local n = 8
  for i = 1, n do
    local ww = w * (i - 0.35) / n
    box(f, g, lv, c, cx - ww / 2, by - h + (i - 1) * h / n, ww, h / n + 0.6)
  end
  local side = math.sqrt(h * h + w * w / 4)
  local ang = math.atan2(h, w / 2)
  bar(f, g, lv, c, cx - w / 4, by - h / 2, side, 2.2, ang)
  bar(f, g, lv, c, cx + w / 4, by - h / 2, side, 2.2, -ang)
end
PROPS.pine = function(f, g, P, c, pal, x, y, s)
  box(f, g, P[1], c.dark, x - 2 * s, y - 12 * s, 4 * s, 12 * s)
  spire(f, g, P[2], c.main, x, y - 8 * s, 34 * s, 92 * s)
end

-- Lisière de forêt : rangée de houppiers serrés de x à x2, haute de h (pied en y), sapins qui dépassent,
-- base pleine resserrée (pas de bord droit aux extrémités).
function PROPS.treeline(f, g, P, c, pal, x, y, s, x2)
  local h = 60 * s
  x2 = x2 or x + 300
  box(f, g, P[1], c.main, x + 18 * s, y - h * 0.42, x2 - x - 36 * s, h * 0.42 + 1)
  local xx = x
  while xx < x2 do
    local w = (26 + 22 * hash(xx, 11)) * s
    local edge = math.min(1, (xx - x) / (60 * s) + 0.35, (x2 - xx) / (60 * s) + 0.35)
    local hh = h * (0.62 + 0.5 * hash(xx, 12)) * edge
    oval(f, g, P[1], c.main, xx + w / 2, y - hh * 0.55, w * 1.15, hh)
    if hash(xx, 14) > 0.5 then
      oval(f, g, P[1], c.main, xx + w * (0.2 + 0.6 * hash(xx, 15)), y - hh * 0.95, w * 0.6, hh * 0.5)
    end
    -- sapins qui dépassent
    if hash(xx, 13) > 0.7 and edge >= 1 then
      spire(f, g, P[1], c.main, xx + w / 2, y - hh * 0.5, 22 * s, hh * 1.05)
    end
    xx = xx + w * 0.62
  end
  if c.rim then blur(f, g, P[2], c.rim[1], (x + x2) / 2, y - h * 0.95, (x2 - x) * 1.05, h * 0.5, c.rim[2] * 0.6) end
end

-- Buisson du sous-bois : quatre disques bas qui se chevauchent, liseré de lune.
function PROPS.bush(f, g, P, c, pal, x, y, s)
  for k = 0, 3 do
    local w = (24 + 14 * hash(x + k, 21)) * s
    oval(f, g, P[2], c.main, x + (k - 1.5) * 15 * s, y - (10 + 7 * hash(x + k, 22)) * s, w, w * 0.8)
  end
  if c.rim then blur(f, g, P[3], c.rim[1], x - 6 * s, y - 22 * s, 50 * s, 16 * s, c.rim[2] * 0.8) end
end

-- Flaque de lumière au sol (clair de lune, feu de camp) : taches fondues, couleur pal.glow ou c.rim.
function PROPS.glow(f, g, P, c, pal, x, y, s, variant)
  local col = variant == "moon" and c.rim or pal.glow or { "#ffb24a", 0.3 }
  blur(f, g, LV.furrows, col[1], x, y, 260 * s, 70 * s, col[2])
  blur(f, g, LV.furrows, col[1], x, y, 120 * s, 34 * s, col[2])
end

-- Pierre tombale arrondie (variante « cross » : croix), légèrement penchée.
function PROPS.tombstone(f, g, P, c, pal, x, y, s, variant)
  local tilt = (hash(x, y) - 0.5) * 0.18
  if variant == "cross" then
    bar(f, g, P[2], c.main, x, y - 19 * s, 38 * s, 5 * s, PI / 2 + tilt)
    bar(f, g, P[2], c.main, x - tilt * 20 * s, y - 27 * s, 20 * s, 5 * s, tilt)
  else
    local t = bar(f, g, P[2], c.main, x, y - 11 * s, 18 * s, 22 * s, tilt)
    oval(f, g, P[2], c.main, x - tilt * 12 * s, y - 22 * s, 18 * s, 14 * s)
    bar(f, g, P[3], c.dark, x - tilt * 10 * s, y - 15 * s, 9 * s, 1.6 * s, tilt)
  end
  if c.rim then blur(f, g, P[3], c.rim[1], x - 4 * s, y - 24 * s, 16 * s, 10 * s, c.rim[2]) end
end

-- Mausolée : marches, corps, colonnes, fronton en losange, porte (lueur facultative de la palette).
function PROPS.crypt(f, g, P, c, pal, x, y, s, variant)
  local w, h = 92 * s, 58 * s
  diamond(f, g, P[1], c.dark, x, y - h, 50 * s)
  box(f, g, P[2], c.main, x - w / 2 - 6 * s, y - 7 * s, w + 12 * s, 7 * s)
  box(f, g, P[2], c.main, x - w / 2, y - h, w, h - 6 * s)
  for k = -2, 2 do
    if k ~= 0 then box(f, g, P[3], c.dark, x + k * 18 * s - 2.5 * s, y - h + 6 * s, 5 * s, h - 13 * s) end
  end
  box(f, g, P[3], c.dark, x - 10 * s, y - 34 * s, 20 * s, 27 * s)
  if variant == "lit" and pal.glow then
    box(f, g, P[3], pal.glow[1], x - 7 * s, y - 31 * s, 14 * s, 24 * s, 0.85)
    blur(f, g, LV.smoke, pal.glow[1], x, y - 20 * s, 90 * s, 60 * s, pal.glow[2])
  end
  if c.rim then blur(f, g, P[3], c.rim[1], x - 18 * s, y - h - 20 * s, 70 * s, 26 * s, c.rim[2]) end
end

-- Réverbère : poteau, potence, lanterne allumée et halo.
function PROPS.lamppost(f, g, P, c, pal, x, y, s)
  box(f, g, P[1], c.dark, x - 2 * s, y - 92 * s, 4 * s, 92 * s)
  box(f, g, P[1], c.dark, x - 5 * s, y - 6 * s, 10 * s, 6 * s)
  bar(f, g, P[1], c.dark, x + 9 * s, y - 88 * s, 20 * s, 2.5 * s, 0)
  box(f, g, P[2], c.dark, x + 13 * s, y - 86 * s, 12 * s, 14 * s)
  local lt = c.light or "#ffd27a"
  box(f, g, P[3], lt, x + 15 * s, y - 84 * s, 8 * s, 10 * s)
  local gl = pal.glow or { "#ffb24a", 0.4 }
  blur(f, g, LV.smoke, gl[1], x + 19 * s, y - 80 * s, 70 * s, 64 * s, gl[2])
end

-- Toile d'araignée entre deux branches : rayons et trois tours, translucides.
function PROPS.web(f, g, P, c, pal, x, y, s)
  local col = pal.web or { "#c9cede", 0.45 }
  local r = 34 * s
  for k = 0, 7 do
    local a = k * PI / 4 + 0.2
    bar(f, g, P[3], col[1], x + cos(a) * r / 2, y - sin(a) * r / 2, r, 1, a, col[2])
  end
  for ring = 1, 3 do
    local rr = r * ring / 3.4
    for k = 0, 7 do
      local a = (k + 0.5) * PI / 4 + 0.2
      bar(f, g, P[3], col[1], x + cos(a) * rr * 0.92, y - sin(a) * rr * 0.92, rr * 0.78, 1, a + PI / 2, col[2] * 0.8)
    end
  end
end

-- Banc de brume au ras du sol, devant le plan moyen.
function PROPS.mist(f, g, P, c, pal, x, y, s, x2)
  local hz = pal.haze
  local w = (x2 or x + 400) - x
  for k = 0, 2 do
    blur(f, g, LV.smoke, hz[1], x + w * (0.2 + 0.3 * k), y - 6 * s - k * 4 * s, w * 0.55, 34 * s, hz[2] * 0.55)
  end
end

-- Plans propres à une zone : Art.paintings[clé].layers = { skyline = f, ground = f, front = f }, appelés
-- avec (kit, cadre, g, entrée, palette) après les collines lointaines (skyline : montagnes), après la route
-- (ground : coulées, rochers, au sol) et à la fin (front : premier plan). Le kit donne les formes et les
-- niveaux du peintre ; S.PROPS est le registre des accessoires (une zone peut y ajouter les siens).
-- `furrows = false` : pas de rangs de champ sur le sol proche (sol de cendres, marais…).
S.PROPS = PROPS
S.paintKit = { LV = LV, box = box, vgrad = vgrad, oval = oval, blur = blur, bar = bar, diamond = diamond,
  tri = tri, hash = hash, rgb = rgb, mix = mix, withAlpha = withAlpha, W = S.W, H = S.DECOR_H }
local function zoneLayer(sp, name, f, g, pal)
  local fn = sp.layers and sp.layers[name]
  if fn then fn(S.paintKit, f, g, sp, pal) end
end

-- Peint le paysage `sp` (entrée d'Art.paintings) dans f ; g reçoit toutes les régions. sp.draw(kit, f, g, sp,
-- palette) : paysage peint en entier par sa zone (jungle de Stranglethorn), à la place des plans ci-dessous.
function S.landscape(f, g, sp)
  local pal = Art.palettes[sp.pal] or Art.palettes.westfall
  if sp.draw then return sp.draw(S.paintKit, f, g, sp, pal) end
  local Wd, Hd, hz, fl = S.W, S.DECOR_H, sp.horizon or 190, sp.field or 228
  -- ciel : deux dégradés
  local sk = pal.sky
  local mid = floor(hz * 0.55)
  vgrad(f, g, LV.sky, rgb(sk[1]), rgb(sk[2]), 0, 0, Wd, mid)
  vgrad(f, g, LV.sky, rgb(sk[2]), rgb(sk[3]), 0, mid - 1, Wd, hz + 9 - mid)
  -- soleil ou lune, halo ; étoiles la nuit
  local orb, body, glow = sp.sun or sp.moon, pal.sun or pal.moon, pal.sunGlow or pal.moonGlow
  if orb and body then
    blur(f, g, LV.sun, glow[1], orb[1], orb[2], orb[3] * 18, orb[3] * 13, glow[2])
    blur(f, g, LV.sun, glow[1], orb[1], orb[2], orb[3] * 6, orb[3] * 6, glow[2])
    oval(f, g, LV.clouds, body, orb[1], orb[2], orb[3] * 2, orb[3] * 2)
  end
  if pal.stars then
    for i = 1, 46 do
      local x, y = hash(i, 1) * Wd, 8 + hash(i, 2) * (hz - 50)
      if not (orb and math.abs(x - orb[1]) < 60 and math.abs(y - orb[2]) < 60) then
        local d = 1.5 + hash(i, 3) * 1.8
        oval(f, g, LV.sun, pal.stars, x, y, d, d, 0.35 + 0.55 * hash(i, 4))
      end
    end
  end
  -- nuages : quatre taches fondues chacun
  local cl = pal.cloud
  for _, c in ipairs(sp.clouds or {}) do
    local x, y, w, h = c[1], c[2], c[3], c[4]
    blur(f, g, LV.clouds, cl[1], x, y, w, h, cl[2])
    blur(f, g, LV.clouds, cl[1], x - w * 0.22, y + h * 0.12, w * 0.55, h * 0.8, cl[2])
    blur(f, g, LV.clouds, cl[1], x + w * 0.24, y + h * 0.1, w * 0.5, h * 0.75, cl[2])
    blur(f, g, LV.clouds, cl[1], x - w * 0.04, y - h * 0.22, w * 0.42, h * 0.8, cl[2] * 0.9)
  end
  -- collines lointaines : deux rangées de bosses basses (horizon plat)
  local hl = sp.hills or {}
  for _, row in ipairs({ { hl.back, LV.hillsBack, pal.hillsBack }, { hl.front, LV.hillsFront, pal.hillsFront } }) do
    if row[1] then
      box(f, g, row[2], row[3], 0, hz - 4, Wd, 12)
      for _, b in ipairs(row[1]) do oval(f, g, row[2], row[3], b[1], hz, b[2], b[3] * 2) end
    end
  end
  zoneLayer(sp, "skyline", f, g, pal)
  -- colline du plan moyen (Sentinel Hill) et son reflet
  if sp.mound then
    local m = sp.mound
    local cy = fl + 30
    oval(f, g, LV.trees, pal.mound, m[1], cy, m[3], (cy - m[2]) * 2)
    local ml = pal.moundLight
    blur(f, g, LV.fieldsFar, ml[1], m[1] - m[3] * 0.1, m[2] + 34, m[3] * 0.5, 74, ml[2])
  end
  -- bosquets sur l'horizon
  for _, t in ipairs(sp.trees or {}) do
    for k = 1, t[2] do
      local w = 11 + 6 * hash(t[1], k)
      oval(f, g, LV.trees, pal.trees, t[1] + (k - 1) * 9 - (t[2] - 1) * 4.5, hz - 2 - (k % 2) * 2, w, w * 0.8)
    end
  end
  -- champs lointains : damier en rangées de plus en plus hautes, haies sombres entre les rangées
  local rows, sum = { 1, 1.4, 1.9, 2.6, 3.4 }, 10.3
  local y = hz
  for r, wgt in ipairs(rows) do
    local h = (fl - hz) * wgt / sum
    local x, k = -12, 0
    local veil = 0.46 - 0.08 * r -- plus brumeux près de l'horizon
    while x < Wd do
      k = k + 1
      local w = (90 + 260 * hash(r * 31 + k, 5)) * (0.6 + 0.12 * r)
      local c = mix(pal.patches[1 + floor(hash(r * 17 + k, 6) * #pal.patches)], pal.patches[1], 0.4)
      vgrad(f, g, LV.fieldsFar, mix(c, pal.haze[1], veil + 0.04), mix(c, pal.haze[1], veil - 0.04), x, y, w + 1, h + 1)
      x = x + w
    end
    if r > 2 then box(f, g, LV.haze, pal.hedge[1], 0, y - 0.5, Wd, 1, pal.hedge[2] * 0.15 * r) end
    y = y + h
  end
  -- colline du plan moyen : flanc à l'ombre, sentier en lacet de la route à la tour
  if sp.mound then
    local m = sp.mound
    blur(f, g, LV.fieldsFar, pal.hedge[1], m[1] + m[3] * 0.24, m[2] + 62, m[3] * 0.55, 96, 0.22)
    local x0 = sp.road and sp.road[1] or m[1]
    local pts = { { x0, hz - 1 }, { m[1] + 70, m[2] + 46 }, { m[1] - 4, m[2] + 4 } }
    for i = 1, #pts - 1 do
      local a, b = pts[i], pts[i + 1]
      local dx, dy = b[1] - a[1], b[2] - a[2]
      bar(f, g, LV.fieldsFar, mix(pal.road[1], pal.mound, 0.25), (a[1] + b[1]) / 2, (a[2] + b[2]) / 2,
        math.sqrt(dx * dx + dy * dy) + 1, 3.2 - i * 1.1, math.atan2(-dy, dx), 0.9)
    end
  end
  -- brume de l'horizon
  local hzc = pal.haze
  blur(f, g, LV.haze, hzc[1], Wd / 2, hz + 2, Wd * 1.6, 70, hzc[2])
  blur(f, g, LV.haze, hzc[1], Wd / 2, hz - 4, Wd * 1.6, 26, hzc[2] * 0.8)
  -- champs proches : dégradé, rangs du blé qui fuient vers l'horizon (plus épais devant), ombres de
  -- nuages fondues, quelques ondulations
  vgrad(f, g, LV.fieldsNear, rgb(pal.fieldsNear[1]), rgb(pal.fieldsNear[2]), 0, fl, Wd, Hd - fl)
  local vx = sp.road and sp.road[1] or Wd / 2
  local fd, fli = pal.furrowDark, pal.furrowLight
  for k = -24, 24 do
    local xa, xb = vx + k * 6, vx + k * 66
    if k ~= 0 and xb > -260 and xb < Wd + 260 and sp.furrows ~= false then
      local segs = { { 0, 0.3, 0.9 }, { 0.3, 0.62, 1.6 }, { 0.62, 1.04, 2.6 } }
      for _, sg in ipairs(segs) do
        local x1, y1 = xa + (xb - xa) * sg[1], fl + (Hd - fl) * sg[1]
        local x2, y2 = xa + (xb - xa) * sg[2], fl + (Hd - fl) * sg[2]
        local dx, dy = x2 - x1, y2 - y1
        bar(f, g, LV.furrows, fd[1], (x1 + x2) / 2, (y1 + y2) / 2, math.sqrt(dx * dx + dy * dy), sg[3],
          math.atan2(-dy, dx), fd[2])
        bar(f, g, LV.furrows, fli[1], (x1 + x2) / 2 + sg[3] * 1.4, (y1 + y2) / 2, math.sqrt(dx * dx + dy * dy),
          sg[3] * 0.7, math.atan2(-dy, dx), fli[2])
      end
    end
  end
  for _, sh in ipairs(sp.shadows or { { 250, fl + 70, 560, 64 }, { 860, fl + 26, 440, 30 }, { 640, Hd - 40, 520, 60 } }) do
    blur(f, g, LV.furrows, fd[1], sh[1], sh[2], sh[3], sh[4], fd[2] * 0.9)
  end
  for k = 1, sp.furrows == false and 0 or 5 do
    local t = (k / 6) ^ 1.6
    box(f, g, LV.furrows, fli[1], 0, fl + (Hd - fl) * t, Wd, 1 + 3 * t, fli[2] * 0.6)
  end
  -- route en perspective : tranches horizontales, largeur proportionnelle à la distance à l'horizon
  if sp.road then
    local r = sp.road
    local y0 = hz + 3
    local yy = y0
    while yy < Hd do
      local t = (yy - y0) / (Hd - y0)
      local step = 1.2 + 1.6 * t
      local tm = math.min(1, (yy + step / 2 - y0) / (Hd - y0))
      local w = r[3] + (r[4] - r[3]) * tm
      local cx = r[1] + (r[2] - r[1]) * tm + (r[5] or 0) * sin(PI * tm)
      local edge = 1 + 4 * tm
      box(f, g, LV.roadEdge, pal.roadEdge, cx - w / 2 - edge, yy, w + 2 * edge, step + 0.6)
      box(f, g, LV.road, mix(pal.road[1], pal.road[2], tm), cx - w / 2, yy, w, step + 0.6)
      yy = yy + step
    end
  end
  -- accessoires (bâtiments lointains, plan moyen) ; ombre fondue au pied de ceux du plan moyen
  local GROUND_W = { scarecrow = 34, tent = 80, cart = 104, oak = 70, deadtree = 44, crypt = 120, tombstone = 24,
    lamppost = 18, pine = 30, bush = 60 }
  for _, p in ipairs(sp.props or {}) do
    local kind = p[1]
    if GROUND_W[kind] and p[5] == "mid" then
      local s = p[4] or 1
      blur(f, g, LV.furrows, pal.ground[1], p[2] + 6 * s, p[3] - 1, GROUND_W[kind] * s * 1.3, 14 * s, 0.55)
    end
    if kind == "fence" then
      fence(f, g, LV[p[6]] or LV.mid, pal[p[6]] or pal.mid, p[2], p[3], p[4], p[5])
    elseif PROPS[kind] then
      PROPS[kind](f, g, LV[p[5]] or LV.mid, pal[p[5]] or pal.mid, pal, p[2], p[3], p[4] or 1, p[6])
    end
  end
  zoneLayer(sp, "ground", f, g, pal)
  -- voile du bas (sol des personnages) et épis du premier plan
  local gr = pal.ground
  vgrad(f, g, LV.ground, withAlpha(gr[1], 0), withAlpha(gr[1], gr[2]), 0, Hd - 128, Wd, 128)
  -- épis : tige, feuille, épi en deux grains allongés, à contre-jour (couleurs sombres de la palette)
  for ci, cl2 in ipairs(sp.wheat or {}) do
    for i = 1, cl2[3] do
      local s0 = ci * 101 + i
      local h1, h2, h3, h4 = hash(s0, 7), hash(s0, 8), hash(s0, 9), hash(s0, 10)
      local bx, by = cl2[1] + (cl2[2] - cl2[1]) * h1, Hd + 4 + 10 * h4
      local L, lean = 46 + 58 * h2, (h3 - 0.5) * 0.5
      local dx, dy = sin(lean), -cos(lean)
      local th = PI / 2 - lean
      bar(f, g, LV.stalks, pal.stalk, bx + dx * L / 2, by + dy * L / 2, L, 1.6, th)
      local side = (h3 < 0.5) and -1 or 1
      local la = lean + side * (0.55 + 0.3 * h1)
      local lx, ly = bx + dx * L * 0.35, by + dy * L * 0.35
      bar(f, g, LV.stalks, pal.stalk, lx + sin(la) * 9, ly - cos(la) * 9, 20, 2.2, PI / 2 - la)
      local ec = pal.ears[1 + floor(h4 * #pal.ears)]
      for j = 0, 1 do
        local d = L + 5 + j * 9
        local ear = oval(f, g, LV.ears, ec, bx + dx * d, by + dy * d, 11 - j * 2, 4.4 - j * 0.6)
        if ear.SetRotation then ear:SetRotation(th) end
      end
    end
  end
  zoneLayer(sp, "front", f, g, pal)
end

-- Autres peintres (décor peint qui n'est pas un paysage à ciel ouvert : intérieur de montagne, crypte…) :
-- Art.painters[nom] = function(f, g, sp, K), choisi par le champ `painter` de l'entrée d'Art.paintings ;
-- K = S.paintKit (formes et niveaux du peintre), pour qu'un fichier d'art de zone peigne sans toucher à ce fichier.
function S.paint(f, g, sp)
  local painter = sp.painter and Art.painters and Art.painters[sp.painter]
  if painter then return painter(f, g, sp, S.paintKit) end
  return S.landscape(f, g, sp)
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

-- Construit décor et plateau dans `parent` (zone intérieure de la fenêtre), sous les écrans.
function S.build(parent)
  local decor = CreateFrame("Frame", nil, parent)
  at(decor, parent, 0, S.TOP, S.W, S.DECOR_H)
  decor:SetFrameLevel(parent:GetFrameLevel() + 1)
  S.decor = decor
  S.paints = {}
  for name, fn in pairs(PAINT) do
    local g = {}
    fn(decor, g)
    S.paints[name] = g
    for i = 1, #g do g[i]:Hide() end
  end
  local art = decor:CreateTexture(nil, "BORDER", nil, 0)
  art:SetAllPoints()
  S.art = art
  -- voile sombre léger sur le bas de l'illustration (sol des personnages, lisibilité des modèles)
  local ground = decor:CreateTexture(nil, "BORDER", nil, 1)
  W.gradient(ground, { 0, 0, 0, 0 }, { 0.02, 0.03, 0.05, S.GROUND_ALPHA })
  at(ground, decor, 0, S.DECOR_H - S.GROUND_H, S.W, S.GROUND_H)
  ground:Hide()
  S.ground = ground
  -- voile froid léger (planches), voile d'assombrissement (bilan), fondu vers le plateau
  local cool = W.rect(decor, "BORDER", 1, C.cool, 0.15)
  cool:SetAllPoints()
  local veil = W.rect(decor, "BORDER", 2, C.black, 0)
  veil:SetAllPoints()
  S.veil = veil
  local fade = decor:CreateTexture(nil, "BORDER", nil, 3)
  W.gradient(fade, { 0, 0, 0, 0 }, { 0.05, 0.06, 0.09, 0.4 })
  at(fade, decor, 0, S.DECOR_H - 50, S.W, 50)

  -- Table du bas : pierre sombre Dragonflight (UI-Frame-DragonFlight-BackgroundTile) répétée, filet du
  -- cadre métal (bord bas des fenêtres) en séparation, ombre portée du décor
  local board = CreateFrame("Frame", nil, parent)
  at(board, parent, 0, S.BOARD_Y, S.W, S.BOARD_H)
  board:SetFrameLevel(parent:GetFrameLevel() + 1)
  S.board = board
  S.boardTile = W.fillTile(board, "table", 1, "BACKGROUND", 0, 0)
  local shade = board:CreateTexture(nil, "BORDER", nil, 0)
  W.gradient(shade, { 0, 0, 0, 0.5 }, { 0, 0, 0, 0 })
  at(shade, board, 0, 4, S.W, 26)
  S.rule(board, 0)

  -- Fond plein (écrans sans décor : carte de parcours) : roche
  local plain = W.fillTile(parent, "rock", 1, "BACKGROUND", -8, 0)
  plain:SetVertexColor(0.45, 0.45, 0.45, 1)
  S.scene = nil
end

-- Filet de séparation (bord bas du cadre métal des fenêtres, répété) dont le trait est à y unités sous
-- le haut du cadre.
function S.rule(parent, y)
  local k = W.K_METAL
  local mm = W.Wow.meta.metal
  local t = W.wow(parent, "metal_bottom", "BORDER", 1)
  local _, h = W.wowSize("metal_bottom", k)
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(y - mm.lineB0 * k))
  t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(y - mm.lineB0 * k))
  t:SetHeight(h)
  W.tileTo(t, "metal_bottom", S.W, h, k)
  return t
end

---------------------------------------------------------------------------
-- Illustrations : fond embarqué (Media/Backgrounds), sinon candidat validé, sinon décor peint
---------------------------------------------------------------------------
-- Un fond embarqué est un fichier de l'addon : il existe forcément, il est affiché sans validation.
-- Repli (candidats du client, FileDataID ou chemin) : sur ce client, rien ne dit de façon fiable si un
-- tel fichier existe (pour un fichier absent, SetTexture réussit, GetTextureFileID renvoie l'identifiant,
-- IsObjectLoaded devient vrai… et WoW dessine un aplat vert) : seuls ceux que le joueur a validés à
-- l'œil (mode essai ci-dessous) peuvent s'afficher.

-- Liste à plat des candidats d'une illustration (les entrées chaîne renvoient à une autre liste).
local function candidates(key, out, seen)
  out, seen = out or {}, seen or {}
  if seen[key] then return out end
  seen[key] = true
  for _, c in ipairs(Art.illustrations[key] or {}) do
    if type(c) == "string" then candidates(c, out, seen) else out[#out + 1] = c end
  end
  return out
end
S.candidates = function(key) return candidates(key) end

-- Verdicts du joueur, gardés dans la sauvegarde : tostring(fichier) -> true (validé) | false (refusé).
local function checks()
  local o = opts()
  if type(o.artChecks) ~= "table" then o.artChecks = {} end
  return o.artChecks
end

function S.verdict(cand) return checks()[tostring(cand.file)] end

-- Description d'un candidat pour la discussion : fichier, nom, verdict.
function S.describe(cand)
  local v = S.verdict(cand)
  return tostring(cand.file) .. " — " .. (cand.name or "unnamed")
    .. (v == true and " [accepted]" or v == false and " [rejected]" or " [not judged yet]")
end

-- Liste d'essai : tous les candidats du client (pas les fonds embarqués, qui n'ont rien à valider) de
-- toutes les illustrations, dédoublonnés, ordre stable.
function S.trialList()
  if S.trials then return S.trials end
  local keys = {}
  for key in pairs(Art.illustrations) do keys[#keys + 1] = key end
  table.sort(keys)
  local list, seen = {}, {}
  for _, key in ipairs(keys) do
    for _, c in ipairs(candidates(key)) do
      local k = tostring(c.file)
      if not c.embedded and not seen[k] then seen[k] = true list[#list + 1] = c end
    end
  end
  S.trials = list
  return list
end

-- Fond embarqué d'un décor (premier de sa liste), ou nil.
function S.embedded(entry)
  if not (entry and entry.art) then return nil end
  for _, c in ipairs(candidates(entry.art)) do
    if c.embedded then return c end
  end
  return nil
end

-- Illustration affichée pour un décor : candidat en essai, sinon le premier de sa liste qui est un fond
-- embarqué ou un candidat validé, sinon nil (décor peint).
function S.chosen(entry)
  if S.trial then return S.trialList()[S.trial] end
  if not (entry and entry.art) or opts().decor == false then return nil end
  for _, c in ipairs(candidates(entry.art)) do
    if c.embedded or S.verdict(c) == true then return c end
  end
  return nil
end

-- Coordonnées de texture d'un fond embarqué : bande au format du décor (S.W × S.DECOR_H) dans une
-- texture qui contient une zone de rapport `ratio` (étirée), placée en hauteur par `focus` (0..1).
function S.bandCoords(cand, focus)
  local target = S.W / S.DECOR_H
  local r = cand.ratio or target
  if r >= target then
    local g = target / r
    return (1 - g) / 2, (1 + g) / 2, 0, 1
  end
  local f = r / target
  local top = (1 - f) * math.max(0, math.min(1, focus or 0.5))
  return 0, 1, top, top + f
end

-- Texture recadrée et teintée ; faux (illustration cachée, décor peint visible) sinon. En essai :
-- recadrage du candidat, sans décalage ni teinte, pour juger l'image telle quelle.
function S.applyArt(entry)
  local art = S.art
  local cand = S.chosen(entry)
  if not cand then art:Hide() S.ground:Hide() return false end
  if art:SetTexture(cand.file) == false then art:Hide() S.ground:Hide() return false end
  local trial = S.trial ~= nil
  if cand.embedded then
    art:SetTexCoord(S.bandCoords(cand, entry.focus))
  else
    local c = cand.crop or { 0, 1, 0, 1 }
    local top, bottom = c[3], c[4]
    local shift = not trial and entry.shift or 0
    if top + shift < 0 then shift = -top elseif bottom + shift > 1 then shift = 1 - bottom end
    art:SetTexCoord(c[1], c[2], top + shift, bottom + shift)
  end
  local t = not trial and entry.tint or { 1, 1, 1 }
  art:SetVertexColor(t[1], t[2], t[3], 1)
  art:Show()
  if trial then S.ground:Hide() else S.ground:Show() end
  return true
end

-- Redessine le décor courant (après un pas d'essai ou un verdict).
function S.redraw()
  if S.decor and S.stage then S.set(S.stage) end
end

-- Mode essai : le décor affiché, quel qu'il soit, montre le candidat n° S.trial de la liste d'essai.
-- Départ : le premier candidat pas encore jugé (sinon le premier). Renvoie le candidat affiché.
function S.trialStart()
  local list = S.trialList()
  local k = 1
  for i = 1, #list do
    if S.verdict(list[i]) == nil then k = i break end
  end
  S.trial = k
  S.redraw()
  return list[k]
end

function S.trialStep(d)
  local n = #S.trialList()
  S.trial = ((S.trial or 1) - 1 + d) % n + 1
  S.redraw()
  return S.trialList()[S.trial]
end

function S.trialStop()
  S.trial = nil
  S.redraw()
end

-- Verdict sur le candidat affiché (true = validé, false = refusé) ; renvoie le candidat.
function S.trialMark(ok)
  local cand = S.trial and S.trialList()[S.trial]
  if not cand then return nil end
  checks()[tostring(cand.file)] = ok and true or false
  return cand
end

-- Rapport de /slay art : les fonds embarqués (et leurs scènes), une ligne par décor (fond embarqué,
-- candidat validé ou peint), puis les verdicts de l'essai.
function S.report()
  local lines = {}
  local ids = {}
  for id in pairs(Art.scenes) do ids[#ids + 1] = id end
  table.sort(ids)
  local off = opts().decor == false
  local bgKeys, users = {}, {}
  for key in pairs(Art.backgrounds or {}) do bgKeys[#bgKeys + 1] = key users[key] = {} end
  table.sort(bgKeys)
  for _, id in ipairs(ids) do
    local bg = S.embedded(Art.scenes[id])
    if bg and users[bg.key] then table.insert(users[bg.key], id) end
  end
  lines[#lines + 1] = "embedded backgrounds (Media\\Backgrounds): " .. #bgKeys
  for _, key in ipairs(bgKeys) do
    local bg = Art.backgrounds[key]
    lines[#lines + 1] = "  " .. key .. ".tga — " .. (bg.name or "unnamed") .. " (FileDataID " .. tostring(bg.source)
      .. "): " .. (#users[key] > 0 and table.concat(users[key], ", ") or "no scene")
  end
  for _, id in ipairs(ids) do
    local entry = Art.scenes[id]
    if not entry.art then
      lines[#lines + 1] = id .. ": painted (no illustration)"
    else
      local list, cand = candidates(entry.art), nil
      for _, c in ipairs(list) do
        if c.embedded or S.verdict(c) == true then cand = c break end
      end
      local tail = off and " (illustrations off: painted)" or ""
      if not cand then
        lines[#lines + 1] = id .. ": painted (none of the " .. #list .. " candidates accepted)"
      elseif cand.embedded then
        lines[#lines + 1] = id .. ": embedded background " .. cand.key .. " — " .. (cand.name or "unnamed") .. tail
      else
        lines[#lines + 1] = id .. ": " .. tostring(cand.file) .. " — " .. (cand.name or "unnamed") .. tail
      end
    end
  end
  local ok, ko, todo = {}, {}, 0
  for _, c in ipairs(S.trialList()) do
    local v = S.verdict(c)
    local label = tostring(c.file) .. " (" .. (c.name or "unnamed") .. ")"
    if v == true then ok[#ok + 1] = label elseif v == false then ko[#ko + 1] = label else todo = todo + 1 end
  end
  lines[#lines + 1] = "client candidates (optional fallback): accepted: " .. (#ok > 0 and table.concat(ok, ", ") or "none")
  lines[#lines + 1] = "rejected: " .. (#ko > 0 and table.concat(ko, ", ") or "none")
  lines[#lines + 1] = "not judged yet: " .. todo .. " of " .. #S.trialList() .. " (/slay scenery test)"
  return lines
end

-- stage = { scene = clé d'Art.scenes | false, board = bool, veil = 0..1 }
function S.set(stage)
  stage = stage or {}
  S.stage = stage
  local id = stage.scene
  if id == false then
    S.decor:Hide()
  else
    local entry = Art.scenes[id or Art.defaultScene] or Art.scenes[Art.defaultScene]
    S.entry = entry
    S.decor:Show()
    -- paysage peint (Art.paintings) : construit à son premier affichage
    local spec = entry.paint and not S.paints[entry.paint] and Art.paintings and Art.paintings[entry.paint]
    if spec then
      local g = {}
      S.paint(S.decor, g, spec)
      S.paints[entry.paint] = g
    end
    for name, g in pairs(S.paints) do
      local on = name == entry.paint
      for i = 1, #g do if on then g[i]:Show() else g[i]:Hide() end end
    end
    S.applyArt(entry)
    S.veil:SetColorTexture(0, 0, 0, S.trial and 0 or stage.veil or 0)
  end
  if stage.board == false then S.board:Hide() else S.board:Show() end
  S.scene = id
end

---------------------------------------------------------------------------
-- Personnages : modèle 3D posé au sol, ombre, anneau de cible
---------------------------------------------------------------------------

-- Ombre de contact : Media/shadow_soft.tga (disque blanc, alpha en dégradé radial doux nul sur tout le
-- bord, tools/build_shadow.py) teintée en noir, aplatie (SHADOW_RATIO:1), centrée sur les pieds
-- (SHADOW_FEET au-dessus du bas du cadre, centre de l'anneau de cible). Deux couches : pénombre large
-- et légère, cœur étroit et dense (≈ 58 % d'opacité au centre). Largeurs proportionnelles à celle du
-- cadre, recalculées quand il change de taille (ennemis agrandis). Sans accrochage au pixel : elle suit
-- les décalages et la visée sans sauter d'un pixel. f.shadow : Show, Hide, SetShown, IsShown, SetAlpha.
S.SHADOW = ns.Skin.root .. "shadow_soft.tga"
S.SHADOW_RATIO, S.SHADOW_FEET = 3.5, 10
S.SHADOW_LAYERS = {
  { w = 0.74, a = 0.25 }, -- pénombre
  { w = 0.46, a = 0.44 }, -- cœur
}

local Shadow = {}
Shadow.__index = Shadow
function Shadow:SetShown(on)
  for _, t in ipairs(self.parts) do if on then t:Show() else t:Hide() end end
  self.shown = on and true or false
end
function Shadow:Show() self:SetShown(true) end
function Shadow:Hide() self:SetShown(false) end
function Shadow:IsShown() return self.shown end
function Shadow:SetAlpha(a) for _, t in ipairs(self.parts) do t:SetAlpha(a) end end
function Shadow:Place(w)
  for i, t in ipairs(self.parts) do
    local lw = w * S.SHADOW_LAYERS[i].w
    t:SetSize(lw, lw / S.SHADOW_RATIO)
  end
end

local function contactShadow(f, w)
  local sh = setmetatable({ parts = {}, shown = true }, Shadow)
  for i, layer in ipairs(S.SHADOW_LAYERS) do
    local t = W.noSnap(f:CreateTexture(nil, "BACKGROUND", nil, 1 + i))
    t:SetTexture(S.SHADOW, nil, nil, "TRILINEAR")
    t:SetVertexColor(0, 0, 0, layer.a)
    t:SetPoint("CENTER", f, "BOTTOM", 0, S.SHADOW_FEET)
    sh.parts[i] = t
  end
  sh:Place(w)
  -- cadre élargi (S.setWide) : l'ombre suit la largeur de base (figW), pas la largeur élargie
  f:SetScript("OnSizeChanged", function(self, nw)
    nw = self.figW or nw
    if nw and nw > 0 then sh:Place(nw) end
  end)
  return sh
end

-- Ordre de dessin d'un personnage. Un cadre de modèle 3D (PlayerModel) dessine ses pixels à son propre
-- niveau, par-dessus toutes les régions (textes, textures, toutes couches) des cadres de niveau inférieur
-- ou égal : un nom posé comme région du cadre de l'écran, ou du personnage lui-même, passe sous le modèle
-- (nom de Salma Saldean coupé par sa robe). D'où trois étages :
--   f (niveau L)         : ombre de contact seulement, qui doit rester sous le modèle ;
--   f.model (L + 1)      : le modèle, puis le repli en médaillon (L + 3) ;
--   f.ui (L + 1 + UI_LIFT) : tout ce qui se lit ou se voit par-dessus le personnage (anneau de cible, nom,
--                          éclat d'un coup) ; au-dessus de tous les modèles d'une scène dont les
--                          personnages sont posés à moins de UI_LIFT - 2 niveaux d'écart.
-- Les écrans portent leurs propres éléments (cadres d'unité, intentions, états) dans des cadres de niveau
-- encore supérieur (CombatView : info au niveau de l'emplacement + 10).
S.UI_LIFT = 6

-- Nom d'un personnage (PNJ de rencontre) : au-dessus de la tête, comme le cadre des ennemis en combat ;
-- bas du texte NAME_GAP au-dessus du haut du cadre du modèle (jamais sur le modèle), voile sombre fondu
-- (texture de l'ombre de contact) derrière le texte pour qu'il se lise sur tout décor.
S.NAME_GAP = 8

-- Cadre de personnage : w × h, pieds au bas du cadre (feetY depuis le bas).
function S.figure(parent, w, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, h)
  f.figW, f.figH, f.wideW = w, h, w
  f.shadow = contactShadow(f, w)
  f.model = W.model(f, w, h)
  f.model:SetPoint("BOTTOM", 0, 0)
  f.model:EnableMouse(false)
  f.model.sceneCenterFeet = true -- pieds ramenés sous l'ombre à chaque cadrage (S.centerFeet)
  -- repli sans modèle : médaillon argenté (icône de l'ennemi ou disque sombre), W.setFallbackArt
  f.fallback = W.medallion(f, math.max(40, math.floor(math.min(w, h) * 0.42)))
  f.fallback:SetPoint("CENTER", 0, h * 0.08)
  f.fallback:SetFrameLevel(f.model:GetFrameLevel() + 2)
  f.fallback:Hide()
  -- étage de l'interface du personnage, au-dessus du modèle et du repli
  f.ui = CreateFrame("Frame", nil, f)
  f.ui:SetAllPoints()
  f.ui:SetFrameLevel(f.model:GetFrameLevel() + S.UI_LIFT)
  f.ui:EnableMouse(false)
  -- anneau de cible : anneau doré du jeu aplati, creux (il passe sur les pieds sans les masquer)
  f.ring = CreateFrame("Frame", nil, f.ui)
  f.ring:SetSize(w * 0.9, 24)
  f.ring:SetPoint("BOTTOM", 0, -2)
  f.ring.outer = W.wow(f.ring, "ring_small", "ARTWORK", 0)
  f.ring.outer:SetAllPoints()
  f.ring:Hide()
  f.SetRing = function(self, on, hover)
    if on then
      self.ring:Show()
      self.ring.outer:SetVertexColor(1, 1, 1, hover and 0.6 or 1)
    else
      self.ring:Hide()
    end
  end
  return f
end

-- Personnage large (art.wide, quadrupède long : crocilisque, raptor, worg…) : un PlayerModel rogne ce qui
-- sort de son cadre (queue d'un crocilisque de trois quarts coupée net). Le cadre (et son modèle) est
-- élargi de wide en largeur seulement, centré, même hauteur ; la taille apparente du modèle ne doit pas
-- changer. Or la projection d'un cadre de modèle dépend de toute sa taille, pas de sa seule hauteur :
-- l'interface de Blizzard (ScriptAnimatedModelScene.lua, CalculatePixelsPerSceneUnit) mesure l'échelle par
-- la DIAGONALE de la vue (« experimentally determined ») ; élargir 150 × 160 à 240 × 160 grossirait le
-- modèle d'environ 31 %. D'où les marges de vue (SetViewInsets, API des modèles : SimpleModelAPI, client
-- Forever compris) : (largeur élargie - largeur de base) / 2 de chaque côté, la vue projetée reste
-- exactement le cadre de base, centrée (même mécanisme que ScriptAnimatedModelScene, qui ramène toute vue à
-- 600 × 680). Les marges ne rognent pas le dessin : les scènes plein écran de Blizzard (GlobalFX*ModelScene,
-- UIParent entier, ramenées à 600 × 680 par ces marges) dessinent leurs effets partout dans le cadre ; le
-- modèle déborde donc de la vue jusqu'au bord du cadre élargi. Sans SetViewInsets : aucun élargissement.
-- Ombre, anneau de cible, repli et éclat restent à la taille de base (f.figW) ; le cadre et son étage
-- d'interface ne prennent jamais la souris. maxW : largeur au plus (grille de /slay models).
function S.setWide(f, wide, maxW)
  local m = f.model
  local w, h = f.figW, f.figH
  local ww = w
  if wide and wide > 1 and m.SetViewInsets then
    ww = w * wide
    if maxW and ww > maxW then ww = math.max(w, maxW) end
  end
  f.wideW = ww
  f:SetSize(ww, h)
  m:SetSize(ww, h)
  if m.SetViewInsets then
    local inset = (ww - w) / 2
    m:SetViewInsets(inset, inset, 0, 0)
  end
  if f.shadow then f.shadow:Place(w) end
  -- modèle déjà chargé : caméra recalculée pour la nouvelle taille (S.frameModel)
  S.refreshFigure(f)
end

-- Cadre d'un personnage qui change de taille ou d'échelle (S.setWide, emplacement à 0,86 de CombatView)
-- alors que son modèle est chargé : caméra recalculée, animation en cours gardée.
function S.refreshFigure(f)
  local m = f and f.model
  if m and m.sceneHasModel then S.frameModel(m, true) end
end

-- Taille de base d'un personnage (ennemi agrandi par art.scale) ; l'élargissement en cours est gardé.
function S.setFigureSize(f, w, h)
  local wide = (f.wideW or f.figW) / f.figW
  f.figW, f.figH = w, h
  S.setWide(f, wide)
end

-- Nom au-dessus de la tête du personnage f (créé à la demande, sur f.ui) ; texte vide = rien d'affiché.
function S.setName(f, text, size, color)
  if not f.name then
    f.nameBack = W.noSnap(f.ui:CreateTexture(nil, "BACKGROUND", nil, 0))
    f.nameBack:SetTexture(S.SHADOW, nil, nil, "TRILINEAR")
    f.nameBack:SetVertexColor(0, 0, 0, 0.6)
    f.name = W.label(f.ui, "bold", size or 14, color or C.wowGold, "OVERLAY")
    f.name:SetPoint("BOTTOM", f, "TOP", 0, S.NAME_GAP)
    f.name:SetWidth(f:GetWidth())
    f.name:SetJustifyH("CENTER")
    f.nameBack:SetPoint("CENTER", f.name, "CENTER", 0, 0)
  end
  text = text or ""
  f.name:SetText(text)
  if text == "" then
    f.nameBack:Hide()
  else
    local tw = math.min(f.name:GetStringWidth() or 0, f:GetWidth())
    f.nameBack:SetSize(tw + 44, (f.name:GetHeight() or 14) + 16)
    f.nameBack:Show()
  end
  return f.name
end

function S.playerFigure(f)
  f.model:SetUnit("player")
  f.model.dead = false
  W.modelAlpha(f.model, 1)
  if f.model.SetFacing then f.model:SetFacing(opts().facingPlayer or 0.6) end
end

---------------------------------------------------------------------------
-- Chargement des modèles : candidats, attente, mémoire du gagnant, préchargement
---------------------------------------------------------------------------
-- Ce que dit l'API (wow_api_search, client Forever) et l'interface de Blizzard (wow_ui_grep, retail) :
--   * SetCreature(idCréature) : l'affichage est lu dans les données de la créature, connues du client
--     seulement si le serveur les lui a envoyées (cache Cache/WDB/…/creaturecache.wdb, rempli quand le
--     joueur a croisé la créature) ; sinon le client les demande au serveur et le modèle arrive plus
--     tard, ou jamais si le serveur ne la connaît pas ;
--   * SetDisplayInfo(idAffichage) : lit les données d'affichage du client lui-même (pas de serveur,
--     pas de cache de créatures) ; échoue seulement si l'affichage manque à ce client ;
--   * SetModel(fichier) : un fichier .m2 du client (FileDataID ou chemin) ; idem.
-- Aucun des trois ne lève d'erreur pour un identifiant inconnu : le cadre reste vide. Le chargement est
-- asynchrone ; le script OnModelLoaded sonne quand le modèle est prêt (utilisé ainsi par
-- MissionCompletePreload_* et RecruitAFriendFrame). Un essai réussit si OnModelLoaded a sonné pour lui,
-- ou (créature, affichage) si GetModelFileID rend un fichier MODEL_WAIT secondes plus tard. Pour un
-- fichier, GetModelFileID pourrait rendre l'identifiant demandé même absent (comme GetTextureFileID
-- pour les textures, voir plus haut) : seul OnModelLoaded compte, sauf client sans ce script.
--
-- MODEL_WAIT : délai avant de passer au candidat suivant. Il valait 0,8 s (W.MODEL_WAIT) : trop court
-- pour un premier chargement (humanoïde équipé : modèle, textures, objets lus sur le disque ; créature
-- absente du cache : aller-retour au serveur), plus d'une seconde en jeu ; le candidat était alors
-- abandonné (ClearModel) juste avant d'arriver. 2 s couvre ces cas ; le délai ne coûte rien quand le
-- modèle charge (OnModelLoaded valide aussitôt) ni quand le gagnant est connu (préchargement), il ne
-- retarde que l'abandon d'un candidat qui échoue vraiment.
S.MODEL_WAIT = 2
S.MODEL_LATE = 4     -- pause avant chaque tour de relance (repli affiché)
S.MODEL_ROUNDS = 2   -- tours de relance de tous les candidats après l'échec de tous
S.FADE_IN = 0.3      -- apparition d'un personnage chargé

-- Candidats d'une entrée d'art, dans l'ordre déclaré : créature, affichage(s), fichier(s).
function S.modelTries(art)
  local out = {}
  if not art then return out end
  if art.creature then out[#out + 1] = { "creature", art.creature } end
  local d = art.display
  if type(d) == "number" then
    out[#out + 1] = { "display", d }
  elseif type(d) == "table" then
    for i = 1, #d do out[#out + 1] = { "display", d[i] } end
  end
  for _, f in ipairs(art.files or {}) do out[#out + 1] = { "file", f[1], name = f[2] } end
  return out
end

function S.tryLabel(t) return t[1] .. " " .. tostring(t[2]) end

-- Mémoire : gagnant par clé (session S.won, et options.modelWins d'une session à l'autre : un affichage
-- ou un fichier qui a chargé chargera encore ; oublié dès qu'il échoue), candidats qui ont échoué
-- (session : essayés en dernier), clés dont tous les candidats ont échoué (S.lost : repli aussitôt).
S.won, S.failed, S.lost = {}, {}, {}

local function saved()
  local o = opts()
  if type(o.modelWins) ~= "table" then o.modelWins = {} end
  return o.modelWins
end

function S.winner(key) return S.won[key] or saved()[key] end

local function remember(key, label)
  S.won[key] = label
  saved()[key] = label
  S.lost[key] = nil
  if S.failed[key] then S.failed[key][label] = nil end
end

local function forget(key, label)
  if S.won[key] == label then S.won[key] = nil end
  if saved()[key] == label then saved()[key] = nil end
  S.failed[key] = S.failed[key] or {}
  S.failed[key][label] = true
end

-- Ordre d'essai : le gagnant connu, puis les candidats pas encore en échec, puis ceux en échec.
function S.orderedTries(key, art)
  local tries = S.modelTries(art)
  local win, bad = S.winner(key), S.failed[key] or {}
  local first, good, late = {}, {}, {}
  for _, t in ipairs(tries) do
    local l = S.tryLabel(t)
    if l == win then first[#first + 1] = t elseif bad[l] then late[#late + 1] = t else good[#good + 1] = t end
  end
  for _, t in ipairs(good) do first[#first + 1] = t end
  for _, t in ipairs(late) do first[#first + 1] = t end
  return first, tries
end

-- Demandes et chargements tardifs. Le client ne promet pas qu'une demande remplacée (ClearModel puis
-- SetCreature / SetDisplayInfo / SetModel sur le même cadre) soit annulée : une créature absente du
-- cache, demandée au serveur puis abandonnée au bout de MODEL_WAIT, peut arriver plus tard et remplacer
-- le modèle du cadre ; son OnModelLoaded ressemble alors à celui du candidat suivant. Chaque pose est
-- donc une demande (model.sceneReq = { kind, id, token, label }) ; une demande abandonnée avant son
-- chargement devient orpheline (model.sceneOrphans, oubliée après ORPHAN_TTL secondes) ; à chaque
-- OnModelLoaded, S.judgeLoad dit si le modèle arrivé est celui de la demande en cours :
--   * affichage : GetDisplayInfo() (CharacterModelBase, client Forever) doit rendre l'affichage
--     demandé ; Blizzard compare de même GetDisplayInfo() à l'affichage voulu avant de reposer un
--     modèle (TalkingHeadFrameMixin:PlayCurrent) ;
--   * fichier (FileDataID) : GetModelFileID() doit rendre le fichier demandé ;
--   * créature (affichage inconnu d'avance) : rien ne la distingue d'une autre créature abandonnée ;
--   * un affichage orphelin qui arrive se reconnaît toujours à son identifiant.
-- Verdicts : « mine » (validé, mémorisé), « foreign » (chargement étranger : la demande en cours est
-- reposée, REPOSE_MAX fois au plus par chaîne, sans jamais rien valider), « unsure » (rien ne permet
-- de trancher : orphelin possible encore en route, ou identifiant rendu différent sans orphelin ; le
-- modèle est gardé et cadré, le candidat compte comme chargé pour cet affichage mais n'est JAMAIS
-- mémorisé comme gagnant).
-- Chaque chargement reçu, le nôtre ou non, est cadré (S.frameModel) : un modèle arrivé en retard
-- n'est jamais montré avec la caméra, la position ou l'animation d'un autre.
S.ORPHAN_TTL = 60   -- secondes pendant lesquelles une demande abandonnée peut encore arriver
S.ORPHAN_MAX = 16   -- orphelins gardés par cadre (les plus anciens oubliés d'abord)
S.REPOSE_MAX = 3    -- reposes de la demande en cours après un chargement étranger, par chaîne

local function clock() return GetTime and GetTime() or 0 end

local function call(model, name)
  local fn = model[name]
  if not fn then return nil end
  local ok, a, b, c = pcall(fn, model)
  if ok then return a, b, c end
  return nil
end

-- Affichage réellement porté par le cadre (nil : inconnu, vide, ou client sans GetDisplayInfo).
function S.shownDisplay(model)
  local d = call(model, "GetDisplayInfo")
  if type(d) == "number" and d ~= 0 then return d end
  return nil
end

-- Fichier du modèle porté (nil : aucun, ou client sans GetModelFileID).
function S.shownFile(model)
  local f = call(model, "GetModelFileID")
  if f ~= nil and f ~= 0 then return f end
  return nil
end

-- État neutre d'un cadre avant la pose d'un candidat : rien de ce que le modèle précédent a reçu
-- (position, échelle, distance de caméra, zoom, animation de mort, retour à l'attente prévu par
-- W.anim) ne passe au suivant. Cadres réutilisés d'un combat à l'autre (emplacements des ennemis).
function S.resetModel(model)
  model.animToken = (model.animToken or 0) + 1
  model.sceneHasModel = false
  if model.ClearModel then model:ClearModel() end
  if model.SetPosition then model:SetPosition(0, 0, 0) end
  if model.SetModelScale then model:SetModelScale(1) end
  if model.SetCamDistanceScale then model:SetCamDistanceScale(1) end
  if model.SetPortraitZoom then model:SetPortraitZoom(0) end
  if not model.dead and model.SetAnimation then model:SetAnimation(Art.anim.stand) end
end

-- Cadrage d'un modèle chargé, à chaque OnModelLoaded (le nôtre ou un étranger) et quand le cadre
-- change de taille ou d'échelle : caméra recalculée pour la taille actuelle du cadre (RefreshCamera,
-- comme TalkingHeadFrameModelMixin:OnModelLoaded et Model_OnEvent de Blizzard), position et échelle
-- neutres, orientation du personnage (model.sceneFacing), attente debout (sauf keepAnim : simple
-- changement de taille, ou mort en cours), puis le cadrage propre du cadre (model.sceneFraming :
-- feu de camp, S.fireCam, qui règle échelle, hauteur et orientation).
function S.frameModel(model, keepAnim)
  if model.RefreshCamera then model:RefreshCamera() end
  if model.SetPosition then model:SetPosition(0, 0, 0) end
  if model.SetModelScale then model:SetModelScale(1) end
  if model.SetCamDistanceScale then model:SetCamDistanceScale(1) end
  if model.sceneFacing and model.SetFacing then model:SetFacing(model.sceneFacing) end
  if not keepAnim and not model.dead and model.SetAnimation then model:SetAnimation(Art.anim.stand) end
  if model.sceneFraming then model.sceneFraming(model)
  elseif model.sceneCenterFeet then S.centerFeet(model) end
  model.sceneFramed = (model.sceneFramed or 0) + 1
end

-- Ombre décalée (retour du 16/11/2026, capture d'un élite : ombre nettement à gauche et sous un orc de face tourné
-- de trois quarts). L'ombre et l'anneau de cible sont posés au centre du bas du cadre du personnage. Or le client ne
-- cadre pas une créature sur ses pieds (origine du modèle) : RefreshCamera vise le centre de sa boîte englobante
-- (comme les caméras d'interface de Blizzard, GetUICameraInfo → useModelCenter, UseModelCenterToTransform). Une
-- arme tenue d'un côté, une cape, un modèle tourné de trois quarts (SetFacing) déplacent ce centre, donc les pieds,
-- hors de l'axe du cadre : l'ombre restait au milieu, à côté des pieds. Correction (indépendante de l'angle de champ,
-- inconnu) : position et cible de la caméra glissent ensemble, perpendiculairement à la visée et à l'horizontale, de
-- la distance qui sépare l'origine de l'axe de visée ; l'origine se projette alors au centre horizontal du cadre, sur
-- l'ombre. Hauteur : inchangée (la boîte est posée sur les pieds ; S.SHADOW_FEET). Sans les fonctions de caméra
-- (autre client, harnais sans elles) : rien ne change. Renvoie le glissement appliqué (unités du modèle) ou nil.
function S.centerFeet(model)
  if not (model.GetCameraPosition and model.GetCameraTarget and model.SetCameraPosition and model.SetCameraTarget) then
    return nil
  end
  local ok1, px, py, pz = pcall(model.GetCameraPosition, model)
  local ok2, tx, ty, tz = pcall(model.GetCameraTarget, model)
  if not (ok1 and ok2 and px and py and pz and tx and ty and tz) then return nil end
  local dx, dy = tx - px, ty - py
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1e-6 then return nil end
  local rx, ry = dy / len, -dx / len -- à droite de la visée, à l'horizontale
  local shift = -(tx * rx + ty * ry)  -- origine (0, 0, 0) ramenée sur l'axe de visée
  model.sceneFeetShift = shift
  if math.abs(shift) < 1e-5 then return 0 end
  model:SetCameraPosition(px + shift * rx, py + shift * ry, pz)
  model:SetCameraTarget(tx + shift * rx, ty + shift * ry, tz)
  return shift
end

local function orphans(model)
  local list = model.sceneOrphans
  if not list then list = {} model.sceneOrphans = list end
  local t = clock()
  for i = #list, 1, -1 do
    if t - (list[i].at or t) > S.ORPHAN_TTL then table.remove(list, i) end
  end
  return list
end

-- La demande en cours, pas encore arrivée, devient orpheline (elle peut arriver plus tard).
local function retire(model)
  local r = model.sceneReq
  model.sceneReq = nil
  if not r or r.loaded or r.reposed then return end
  local list = orphans(model)
  r.at = clock()
  list[#list + 1] = r
  while #list > S.ORPHAN_MAX do table.remove(list, 1) end
end

-- Pose d'un candidat t = { genre, identifiant } sous le jeton token (le même pour une repose).
local function request(model, t, token)
  retire(model)
  S.resetModel(model)
  local r = { kind = t[1], id = t[2], token = token, label = S.tryLabel(t) }
  model.sceneReq = r
  if t[1] == "creature" then model:SetCreature(t[2])
  elseif t[1] == "display" then model:SetDisplayInfo(t[2])
  else model:SetModel(t[2]) end
  return r
end

-- Retire le premier orphelin qui vérifie pred ; le renvoie.
local function take(list, pred)
  for i = 1, #list do
    if pred(list[i]) then return table.remove(list, i) end
  end
  return nil
end

-- Le chargement qui vient de sonner est-il celui de la demande en cours r ? « mine », « foreign » ou
-- « unsure » (voir plus haut), et l'orphelin reconnu s'il y en a un.
function S.judgeLoad(model, r)
  local list = orphans(model)
  local d = S.shownDisplay(model)
  if d then
    -- un affichage abandonné qui arrive se reconnaît à son identifiant
    local o = take(list, function(x) return x.kind == "display" and x.id == d end)
    if o and not (r and r.kind == "display" and r.id == d) then return "foreign", o end
  end
  if not r then return "foreign", take(list, function() return true end) end
  local file = (r.kind == "file" and type(r.id) == "number") and S.shownFile(model) or nil
  local proof, other
  if r.kind == "display" and d then proof, other = d == r.id, d ~= r.id end
  if file then proof, other = file == r.id, file ~= r.id end
  -- créature déjà chargée : son affichage est connu depuis, un autre est un chargement étranger
  if r.kind == "creature" and r.display and d then proof, other = d == r.display, d ~= r.display end
  if proof then return "mine" end
  if other then
    -- autre modèle que celui demandé : une créature (ou un fichier) abandonnée qui arrive ; sans
    -- orphelin pour l'expliquer, rien ne prouve un chargement étranger (identifiant rendu autrement)
    local o = take(list, function(x) return x.kind ~= "display" end)
    if o then return "foreign", o end
    return "unsure"
  end
  -- pas de preuve d'identité (créature, chemin de fichier, client sans ces fonctions) : sûr seulement
  -- si aucune autre demande abandonnée ne peut être en route
  for i = #list, 1, -1 do
    local x = list[i]
    if x.kind == r.kind and x.id == r.id then table.remove(list, i) end -- la même demande : même modèle
  end
  for _, x in ipairs(list) do
    -- un affichage orphelin arrivé aurait été reconnu ci-dessus (si GetDisplayInfo existe)
    if not (d and x.kind == "display") then return "unsure" end
  end
  return "mine"
end

-- OnModelLoaded de tous les cadres de la chaîne.
function S.onModelLoaded(model)
  model.sceneLoads = (model.sceneLoads or 0) + 1
  model.sceneHasModel = true
  local r = model.sceneReq
  local verdict, orphan = S.judgeLoad(model, r)
  if verdict == "foreign" and r and (model.sceneReposes or 0) >= S.REPOSE_MAX then verdict = "unsure" end
  S.frameModel(model)
  if verdict == "foreign" then
    model.sceneLate = (model.sceneLate or 0) + 1
    model.sceneLateWhat = orphan and orphan.label or "?"
    if r then
      -- la demande en cours est reposée (même jeton : la chaîne continue, le délai d'essai court encore)
      model.sceneReposes = (model.sceneReposes or 0) + 1
      r.reposed = true
      request(model, { r.kind, r.id }, r.token).display = r.display
    else
      S.resetModel(model) -- rien ne doit être montré
    end
    return
  end
  if r then
    r.loaded, r.verified = true, verdict == "mine"
    r.display = r.display or S.shownDisplay(model)
    if verdict == "unsure" then model.sceneUnsure = (model.sceneUnsure or 0) + 1 end
  end
  -- candidat déjà affiché sans preuve, prouvé depuis (rechargé une fois les orphelins arrivés) :
  -- mémorisé maintenant
  local st = model.sceneStatus
  if verdict == "mine" and r and st and st.state == "ok" and st.unsure and st.via == r.label then
    st.unsure = nil
    remember(st.key, st.via)
  end
  if model.sceneOnLoaded then model.sceneOnLoaded(r) end
end

-- OnModelLoaded (pcall : sans effet sur un client qui ne connaît pas ce script ; model.sceneHook dit
-- s'il est posé) ; échelle de l'interface ou taille de l'écran changée : caméra recalculée (comme
-- Model_OnLoad / Model_OnEvent de Blizzard).
local function hookLoaded(model)
  if model.sceneHook ~= nil then return end
  model.sceneHook = pcall(model.SetScript, model, "OnModelLoaded", S.onModelLoaded) and true or false
  if model.RegisterEvent and pcall(model.SetScript, model, "OnEvent", function(self)
    if self.sceneHasModel then S.frameModel(self, true) end
  end) then
    pcall(model.RegisterEvent, model, "UI_SCALE_CHANGED")
    pcall(model.RegisterEvent, model, "DISPLAY_SIZE_CHANGED")
  end
end

-- Le candidat posé sous token est-il chargé ? Renvoie chargé, vérifié. Sans OnModelLoaded (client
-- sans ce script) : GetModelFileID, et l'identité si le client la donne.
local function isLoaded(model, t, token)
  local r = model.sceneReq
  if not r or r.token ~= token then return false end
  if r.loaded then return true, r.verified end
  if t[1] == "file" and model.sceneHook then return false end
  if not W.hasModel(model) then return false end
  local verdict = S.judgeLoad(model, r)
  if verdict == "foreign" then return false end
  return true, verdict == "mine"
end

-- Abandon des essais d'un cadre (cadre de préchargement rendu au réservoir) : vidé, demande orpheline.
function S.releaseModel(model)
  model.sceneChain = (model.sceneChain or 0) + 1
  model.sceneOnLoaded = nil
  retire(model)
  S.resetModel(model)
end

-- Essais en chaîne sur un cadre de modèle. h = { onFound(libellé, essai), onMissing(), quiet = sans
-- statut public }. Statut (W.models[key], lu par /slay models et /slay art ; model.sceneStatus pour le
-- diagnostic du cadre) : tries = libellés dans l'ordre déclaré, state = "pending" | "ok" | "missing",
-- via = libellé du candidat chargé, unsure = chargé sans preuve d'identité (jamais mémorisé).
-- Après l'échec de tous : onMissing (repli), puis MODEL_ROUNDS tours de relance de tous les candidats
-- (MODEL_LATE entre deux), puis le premier candidat reste posé : un OnModelLoaded tardif le valide.
function S.loadModel(model, art, key, h)
  key, h = tostring(key), h or {}
  model.sceneChain = (model.sceneChain or 0) + 1
  local chain = model.sceneChain
  model.sceneOnLoaded = nil
  -- diagnostic du personnage en cours (/slay models) : chargements reçus, chargements étrangers
  model.sceneReposes, model.sceneLoads, model.sceneLate, model.sceneLateWhat = 0, 0, 0, nil
  hookLoaded(model)
  local tries, declared = S.orderedTries(key, art)
  local labels, names = {}, {}
  for i = 1, #tries do labels[i] = S.tryLabel(tries[i]) end
  for i = 1, #declared do names[i] = S.tryLabel(declared[i]) end
  local status = { tries = names, state = "pending", key = key }
  model.sceneStatus = status
  if not h.quiet then W.models[key] = status end
  local function live() return model.sceneChain == chain and status.state ~= "ok" end
  local function found(i, verified)
    if not live() then return end
    status.state, status.via, status.unsure = "ok", labels[i], (not verified) or nil
    model.sceneOnLoaded = nil
    -- seul un chargement prouvé (ou sans autre demande en route) est mémorisé comme gagnant
    if verified then remember(key, labels[i]) end
    if not h.quiet then W.missing["model:" .. key] = nil end
    if h.onFound then h.onFound(labels[i], tries[i]) end
  end
  local function missing()
    status.state = "missing"
    S.lost[key] = true
    if not h.quiet then W.missing["model:" .. key] = true end
    if h.onMissing then h.onMissing() end
  end
  if #tries == 0 then
    retire(model)
    S.resetModel(model)
    missing()
    return status
  end
  local function pose(i)
    model.sceneToken = (model.sceneToken or 0) + 1
    local token = model.sceneToken
    model.sceneOnLoaded = function(r)
      if model.sceneChain == chain and model.sceneToken == token then found(i, r and r.verified) end
    end
    request(model, tries[i], token)
    return token
  end
  local function attempt(i, onFail)
    local token = pose(i)
    W.delay(S.MODEL_WAIT, function()
      if not live() or model.sceneToken ~= token then return end
      local ok, verified = isLoaded(model, tries[i], token)
      if ok then found(i, verified) return end
      forget(key, labels[i])
      onFail()
    end)
  end
  local function run(i, round)
    attempt(i, function()
      if i < #tries then run(i + 1, round) return end
      if round == 0 then missing() end
      if round < S.MODEL_ROUNDS then
        W.delay(S.MODEL_LATE, function() if live() then run(1, round + 1) end end)
      else
        pose(1)
      end
    end)
  end
  run(1, 0)
  return status
end

-- Diagnostic d'un cadre (/slay models) : candidat validé, modèle réellement porté (affichage,
-- fichier), position, échelle, chargements reçus, chargements étrangers (tardifs). ASCII seulement.
local function num(v)
  if type(v) ~= "number" then return "?" end
  if v == math.floor(v) then return tostring(v) end
  return ("%.2f"):format(v)
end

-- compact = sans le candidat (case de la grille, sous l'état « model: … »).
function S.modelDiag(model, compact)
  local st = model.sceneStatus
  local parts = {}
  if not compact then
    local via = st and (st.state == "ok" and (st.via .. (st.unsure and " (unverified)" or ""))
      or st.state) or "nothing posed"
    parts[#parts + 1] = "via " .. via
  end
  local d, f = S.shownDisplay(model), S.shownFile(model)
  parts[#parts + 1] = (d and ("display " .. d .. " ") or "") .. "file " .. (f and tostring(f) or "?")
  local x, y, z = call(model, "GetPosition")
  parts[#parts + 1] = "pos " .. num(x) .. "," .. num(y) .. "," .. num(z)
  parts[#parts + 1] = "scale " .. num(call(model, "GetModelScale"))
  parts[#parts + 1] = "loads " .. (model.sceneLoads or 0)
  if (model.sceneLate or 0) > 0 then
    parts[#parts + 1] = "late " .. model.sceneLate .. (compact and "" or (" (" .. tostring(model.sceneLateWhat) .. ")"))
  end
  return table.concat(parts, compact and " " or "; ")
end

-- Anomalie à signaler sur la ligne du rapport (/slay models) : chargement étranger (tardif), position
-- ou échelle hors du neutre (sauf cadre à cadrage propre : feu de camp) ; "" sinon. Candidat non
-- prouvé : « (unverified) » de S.reportLine.
function S.modelAnomaly(model)
  local out = {}
  if (model.sceneLate or 0) > 0 then
    out[#out + 1] = "late load x" .. model.sceneLate .. " (" .. tostring(model.sceneLateWhat) .. ")"
  end
  if not model.sceneFraming then
    local x, y, z = call(model, "GetPosition")
    if (x and x ~= 0) or (y and y ~= 0) or (z and z ~= 0) then
      out[#out + 1] = "pos " .. num(x) .. "," .. num(y) .. "," .. num(z)
    end
    local s = call(model, "GetModelScale")
    if s and s ~= 1 then out[#out + 1] = "scale " .. num(s) end
  end
  return #out > 0 and (" [" .. table.concat(out, "; ") .. "]") or ""
end

-- Personnage (cadre de S.figure ou S.campfire : model, fallback, shadow facultative) : le modèle reste
-- invisible (alpha 0 : le client le charge quand même, comme les cadres de préchargement de Blizzard,
-- MissionCompletePreloadModelTemplate alpha="0") jusqu'à son chargement, puis apparaît en fondu court
-- avec son ombre. Le médaillon de repli (icône de art.icon) n'apparaît qu'après l'échec de TOUS les
-- candidats (aussitôt si une tentative précédente a déjà tout essayé en vain : S.lost), et s'efface
-- si un modèle finit par arriver. o = { facing, framing(model) = cadrage propre après chaque
-- chargement, onFound(libellé, essai) }. Rien d'autre n'attend.
function S.showModel(f, art, key, o)
  o = o or {}
  local m = f.model
  key = tostring(key)
  W.cancel(m, "appear")
  m.dead = false
  -- un PlayerModel caché libère son modèle (SetKeepModelOnHide, CharacterModelBase) : gardé ici, la
  -- fenêtre se fermant et se rouvrant en vol
  if m.SetKeepModelOnHide then m:SetKeepModelOnHide(true) end
  m:Show()
  m:SetAlpha(0)
  if f.shadow then f.shadow:Hide() end
  -- orientation et cadrage réappliqués après chaque chargement (S.frameModel)
  m.sceneFacing, m.sceneFraming = o.facing, o.framing
  -- personnage de S.figure : élargi selon art.wide (S.setWide), remis à la largeur de base sinon
  if f.figW then S.setWide(f, art and art.wide, f.wideMax) end
  W.setFallbackArt(f.fallback, art and art.icon)
  if S.lost[key] then f.fallback:Show() else f.fallback:Hide() end
  if o.facing and m.SetFacing then m:SetFacing(o.facing) end
  S.loadModel(m, art, key, {
    onFound = function(label, t)
      f.fallback:Hide()
      if o.onFound then o.onFound(label, t) end
      if m.dead then return end
      if f.shadow then f.shadow:Show() end
      W.tween(S.FADE_IN, function(p)
        W.modelAlpha(m, p)
        if f.shadow then f.shadow:SetAlpha(p) end
      end, nil, m, "appear")
    end,
    onMissing = function() f.fallback:Show() end,
  })
  return true
end

-- Personnage de rencontre : modèle (Art.npcs[npcId]) dès qu'il est chargé, sinon médaillon de repli ;
-- sans déclaration : médaillon sombre (jamais de vide). Renvoie vrai si le personnage est montré.
function S.npcFigure(f, npcId)
  if not npcId then
    f.model:Hide()
    f.shadow:Hide()
    f.fallback:Hide()
    return false
  end
  return S.showModel(f, Art.npcs[npcId], "npc:" .. npcId, { facing = opts().facingEnemy or -0.6 })
end

-- Ennemi en combat (UI/CombatView.lua) : même mécanisme, médaillon à l'icône de l'ennemi.
function S.enemyFigure(fig, enemyId)
  return S.showModel(fig, Art.enemies[enemyId], enemyId, { facing = opts().facingEnemy or -0.6 })
end

---------------------------------------------------------------------------
-- Préchargement : modèles de la prochaine scène possible
---------------------------------------------------------------------------
-- Cadres de modèle créés une fois et réutilisés, MONTRÉS avec une alpha 0 (comme les cadres de
-- MissionCompletePreloadModels de Blizzard : un cadre caché n'est pas garanti de charger, et un
-- PlayerModel libère son modèle quand il est caché, sauf SetKeepModelOnHide), enfants d'UIParent (la
-- fenêtre de l'addon peut être fermée), dans l'écran, sans souris. Chaque cadre fait les essais de sa
-- clé (S.loadModel, sans statut public) : le gagnant est mémorisé ; une fois chargé, le cadre est
-- caché (plus rien à dessiner) en gardant son modèle (SetKeepModelOnHide), qui reste ainsi en mémoire
-- du client jusqu'à l'affichage de la scène, qui pose le gagnant en premier et l'obtient aussitôt.
S.PRELOAD_MAX = 24
S.preloads = {}   -- clé -> { model, status }

local function preloadFrame()
  local host = S.preloadHost
  if not host then
    host = CreateFrame("Frame", nil, UIParent)
    host:SetSize(64, 64)
    host:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    host:EnableMouse(false)
    S.preloadHost = host
    S.preloadFree = {}
  end
  local m = table.remove(S.preloadFree)
  if not m then
    m = W.model(host, 64, 64)
    m:SetPoint("BOTTOMLEFT", 0, 0)
    m:EnableMouse(false)
    if m.SetKeepModelOnHide then m:SetKeepModelOnHide(true) end
  end
  m:SetAlpha(0)
  m:Show()
  return m
end

-- list = { { key = clé, art = entrée d'art }, … } : les modèles de cette liste se chargent (ceux déjà
-- en cours ou chargés sont gardés) ; les autres cadres sont vidés et rendus au réservoir.
function S.preload(list)
  local want, order = {}, {}
  for _, e in ipairs(list or {}) do
    local k = tostring(e.key)
    if e.art and not want[k] then want[k] = e.art order[#order + 1] = k end
  end
  for k, p in pairs(S.preloads) do
    if not want[k] then
      S.releaseModel(p.model) -- arrête ses essais, vide le cadre (demande en cours : orpheline)
      S.preloadFree[#S.preloadFree + 1] = p.model
      S.preloads[k] = nil
    end
  end
  local n = 0
  for _ in pairs(S.preloads) do n = n + 1 end
  for _, k in ipairs(order) do
    if not S.preloads[k] and n < S.PRELOAD_MAX then
      local m = preloadFrame()
      -- chargé : le cadre est caché (plus rien à dessiner), son modèle gardé (SetKeepModelOnHide)
      S.preloads[k] = { model = m, status = S.loadModel(m, want[k], k, { quiet = true,
        onFound = function() m:Hide() end }) }
      n = n + 1
    end
  end
  return order
end

-- Ce dont la prochaine étape peut avoir besoin, depuis l'état de l'expédition : ennemis des combats
-- possibles (groupes de la réserve du genre de chaque étape accessible), personnages des rencontres
-- possibles (X.eventPool), feu de camp (toujours : petit, et l'écran le plus fréquent), familier.
-- extra = entrées en plus (combats que peut lancer une rencontre ouverte).
function S.nextNeeds(exp, extra)
  local out = {}
  local function enemies(pool)
    for _, group in ipairs(pool or {}) do
      for _, id in ipairs(group) do out[#out + 1] = { key = id, art = Art.enemies[id] } end
    end
  end
  out[#out + 1] = { key = "campfire", art = Art.campfire }
  if Art.pet and exp and exp.class == "hunter" then out[#out + 1] = { key = "pet:hunter", art = Art.pet } end
  local Map, X = ns.Map, ns.Expedition
  local act = exp and ns.Zones[exp.zone or ns.Zone.FIRST]
  local pools = act and ns.Encounters and ns.Encounters[act.encounters]
  if exp and exp.map and Map.nextNodes and pools then
    for _, id in ipairs((ns.Expedition.nextNodes and ns.Expedition.nextNodes(exp)) or Map.nextNodes(exp.map, exp.node) or {}) do
      local node = exp.map.nodes[id]
      local k = node and node.kind
      if k == "combat" then
        enemies((exp.combatsInAct or 0) < (X.EASY_COMBATS or 0) and pools.easy or pools.normal)
      elseif k == "elite" or k == "boss" then
        enemies(pools[k])
      elseif k == "event" and X.eventPool then
        local ok, ids = pcall(X.eventPool, exp)
        for _, evId in ipairs(ok and ids or {}) do
          local ev = ns.Events[evId]
          if ev and ev.npc then out[#out + 1] = { key = "npc:" .. ev.npc, art = Art.npcs[ev.npc] } end
        end
      end
    end
  end
  for _, e in ipairs(extra or {}) do out[#out + 1] = e end
  return out
end

-- Combats qu'une rencontre peut lancer (effet « fight » de ses réponses) : leurs ennemis.
function S.eventFightNeeds(ev, exp)
  local out = {}
  local act = exp and ns.Zones[exp.zone or ns.Zone.FIRST]
  local pools = act and ns.Encounters and ns.Encounters[act.encounters] or {}
  local function scan(effects)
    for _, e in ipairs(effects or {}) do
      if e[1] == "fight" then
        local pool = pools[e[2] or (e.kind == "elite" and "elite" or "normal")]
        for _, group in ipairs(pool or {}) do
          for _, id in ipairs(group) do out[#out + 1] = { key = id, art = Art.enemies[id] } end
        end
      elseif e[1] == "gamble" then
        scan(e.win)
        scan(e.lose)
      end
    end
  end
  for _, ch in ipairs(ev and ev.choices or {}) do scan(ch.effects) end
  return out
end

---------------------------------------------------------------------------
-- Feu de camp : modèle 3D d'un feu du jeu, lueur chaude au sol, médaillon de repli
---------------------------------------------------------------------------
-- Lueur : la texture fondue de l'ombre de contact (S.SHADOW), teintée orange, en mode additif, aplatie
-- et centrée sur le pied du feu, deux couches (halo large et cœur) qui vacillent doucement. Elle est
-- dessinée par le cadre du feu (niveau L, couche du fond), sous le modèle (L + 1) ; le médaillon de
-- repli est au-dessus du modèle (L + 3). Pas d'ombre de contact : la lueur la remplace.
S.FIRE_GLOW = {
  { w = 2.1, ratio = 3.2, color = { 1, 0.45, 0.12 }, a = 0.42 }, -- halo
  { w = 1.05, ratio = 3.4, color = { 1, 0.68, 0.3 }, a = 0.55 }, -- cœur
}
S.FIRE_FEET = 14 -- centre de la lueur au-dessus du bas du cadre (pied du feu)

function S.campfire(parent, w, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, h)
  f:EnableMouse(false)
  f.glow = {}
  for i, g in ipairs(S.FIRE_GLOW) do
    local t = W.noSnap(f:CreateTexture(nil, "BACKGROUND", nil, i))
    t:SetTexture(S.SHADOW, nil, nil, "TRILINEAR")
    t:SetBlendMode("ADD")
    t:SetVertexColor(g.color[1], g.color[2], g.color[3], g.a)
    t:SetSize(w * g.w, w * g.w / g.ratio)
    t:SetPoint("CENTER", f, "BOTTOM", 0, S.FIRE_FEET)
    f.glow[i] = t
  end
  -- vacillement doux (le halo et le cœur en opposition), seulement quand le feu est montré
  local clock, halo, core, sin = 0, f.glow[1], f.glow[2], math.sin
  f:SetScript("OnUpdate", function(_, el)
    clock = clock + (el or 0)
    local a = 0.9 + 0.06 * sin(clock * 7.3) + 0.04 * sin(clock * 12.1)
    halo:SetAlpha(a)
    core:SetAlpha((2 - a) * 0.95)
  end)
  f.model = W.model(f, w, h)
  f.model:SetPoint("BOTTOM", 0, 0)
  f.model:SetFrameLevel(f:GetFrameLevel() + 1)
  f.model:EnableMouse(false)
  f.fallback = W.medallion(f, 74)
  f.fallback:SetPoint("CENTER", f, "BOTTOM", 0, 37 + 4)
  f.fallback:SetFrameLevel(f.model:GetFrameLevel() + 2)
  f.fallback:Hide()
  return f
end

-- Cadrage du feu après chargement : orientation (Art.campfire.facing), échelle et hauteur facultatives
-- (Art.campfire.scale / z), réglage du joueur (/slay fire, options.fireCam) en priorité.
function S.fireCam(m)
  local a, o = Art.campfire or {}, opts().fireCam
  local scale, z, facing = a.scale, a.z, a.facing
  if type(o) == "table" then scale, z, facing = o[1] or scale, o[2] or z, o[3] or facing end
  -- sans réglage : échelle et hauteur neutres (/slay fire reset efface aussi un réglage déjà posé)
  if m.SetModelScale then m:SetModelScale(scale or 1) end
  if m.SetPosition then m:SetPosition(0, 0, z or 0) end
  if facing and m.SetFacing then m:SetFacing(facing) end
end

function S.showCampfire(f)
  -- cadrage du feu réappliqué après chaque chargement (S.frameModel, model.sceneFraming)
  return S.showModel(f, Art.campfire, "campfire", { framing = S.fireCam })
end

-- Ligne de rapport d'un modèle (/slay models) : « clé (nom): display 1691 » si chargé (« , after
-- creature 235 » si des candidats ont échoué avant), « clé (nom): fallback (no model: creature 619,
-- display 2329, …) » sinon, « …: loading (…) » pendant les essais ; « (unverified) » : chargé sans
-- preuve d'identité, jamais mémorisé (S.judgeLoad). ASCII seulement.
function S.reportLine(key, name)
  local st = W.models[tostring(key)]
  local head = tostring(key) .. ((name and name ~= key) and (" (" .. name .. ")") or "") .. ": "
  if not st then return head .. "not shown yet" end
  local tried = #st.tries > 0 and table.concat(st.tries, ", ") or "no identifier"
  if st.state == "ok" then
    return head .. st.via .. (st.via ~= st.tries[1] and (" (declared first: " .. tostring(st.tries[1]) .. ")") or "")
      .. (st.unsure and " (unverified)" or "")
  elseif st.state == "missing" then
    return head .. "fallback (no model: " .. tried .. ")"
  end
  return head .. "loading (" .. tried .. ")"
end
