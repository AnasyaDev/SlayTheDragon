-- Scène commune à tous les écrans : décor plein cadre en haut (décor peint en couches unies, aux
-- couleurs des maquettes, ou illustration du jeu validée par le joueur), plateau de bois en bas, personnages
-- (modèle 3D avec ombre au sol). Coordonnées : celles des maquettes, depuis le coin haut gauche de
-- la zone intérieure (1034 × 614), x vers la droite, y vers le bas.
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art = ns.Widgets, ns.Art
local C = Art.C

local S = {}
ns.Scene = S

S.W, S.H = 1034, 614
S.TOP, S.DECOR_H = 44, 380      -- bande du décor : y 44 à 424
S.BOARD_Y, S.BOARD_H = 424, 190 -- plateau : y 424 à 614

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

function PAINT.night(f, g)
  sky(g, f, { 0.09, 0.1, 0.2 }, { 0.17, 0.2, 0.33 })
  local moon = W.disc(f, "BACKGROUND", -7, Art.hex("#e8e2d0"))
  at(moon, f, 820, 40, 56, 56)
  g[#g + 1] = moon
  local stars = { { 80, 40 }, { 200, 90 }, { 340, 30 }, { 470, 70 }, { 610, 24 }, { 700, 110 }, { 940, 60 }, { 990, 140 } }
  for _, s in ipairs(stars) do
    local st = W.disc(f, "BACKGROUND", -7, C.creamLight, 0.8)
    at(st, f, s[1], s[2], 4, 4)
    g[#g + 1] = st
  end
  hills(g, f, 190, Art.hex("#202a2a"), { { 200, 520, 70 }, { 760, 520, 50 } }, -6)
  hills(g, f, 250, Art.hex("#171f1d"), { { 400, 700, 40 } }, -4)
  local ground = W.rect(f, "BACKGROUND", -2, Art.hex("#2a1d14"))
  at(ground, f, 0, 300, S.W, 80)
  g[#g + 1] = ground
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
  -- voile (assombrir pour les écrans de bilan), fondu vers le plateau
  local veil = W.rect(decor, "BORDER", 2, C.black, 0)
  veil:SetAllPoints()
  S.veil = veil
  local fade = decor:CreateTexture(nil, "BORDER", nil, 3)
  W.gradient(fade, { 0, 0, 0, 0 }, { 0.1, 0.06, 0.03, 0.45 })
  at(fade, decor, 0, S.DECOR_H - 50, S.W, 50)

  -- Plateau de bois
  local board = CreateFrame("Frame", nil, parent)
  at(board, parent, 0, S.BOARD_Y, S.W, S.BOARD_H)
  board:SetFrameLevel(parent:GetFrameLevel() + 1)
  local bbg = W.rect(board, "BACKGROUND", 0, C.board)
  bbg:SetAllPoints()
  local grain = board:CreateTexture(nil, "BACKGROUND", nil, 1)
  grain:SetTexture(Art.tex.wood)
  grain:SetAllPoints()
  grain:SetVertexColor(0.55, 0.38, 0.24)
  grain:SetAlpha(0.35)
  S.boardGrain = grain
  local edge = W.rect(board, "BORDER", 0, C.boardEdge)
  at(edge, board, 0, 0, S.W, 4)
  S.board = board

  -- Fond plein (écrans sans décor : carte de parcours)
  local plain = W.rect(parent, "BACKGROUND", -8, C.frame)
  plain:SetAllPoints()
  S.scene = nil
end

---------------------------------------------------------------------------
-- Illustrations : seulement les candidats validés par le joueur, sinon décor peint
---------------------------------------------------------------------------
-- Sur ce client, rien ne dit de façon fiable si un fichier existe : pour un fichier absent, SetTexture
-- réussit, GetTextureFileID renvoie l'identifiant, IsObjectLoaded devient vrai… et WoW dessine un
-- aplat vert. Aucune API documentée (GetFileIDFromPath, C_Texture.GetFilenameFromFileDataID,
-- GetTextureFilePath) ne promet de distinguer un fichier absent. Donc : décor peint par défaut ; un
-- décor montre le premier candidat de SA liste que le joueur a validé à l'œil (mode essai ci-dessous).

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
  return tostring(cand.file) .. " — " .. (cand.name or "sans nom")
    .. (v == true and " [validé]" or v == false and " [refusé]" or " [pas encore jugé]")
end

-- Liste d'essai : tous les candidats de toutes les illustrations, dédoublonnés, ordre stable.
function S.trialList()
  if S.trials then return S.trials end
  local keys = {}
  for key in pairs(Art.illustrations) do keys[#keys + 1] = key end
  table.sort(keys)
  local list, seen = {}, {}
  for _, key in ipairs(keys) do
    for _, c in ipairs(candidates(key)) do
      local k = tostring(c.file)
      if not seen[k] then seen[k] = true list[#list + 1] = c end
    end
  end
  S.trials = list
  return list
end

-- Illustration affichée pour un décor : candidat en essai, sinon premier validé de sa liste, sinon nil.
function S.chosen(entry)
  if S.trial then return S.trialList()[S.trial] end
  if not (entry and entry.art) or opts().decor == false then return nil end
  for _, c in ipairs(candidates(entry.art)) do
    if S.verdict(c) == true then return c end
  end
  return nil
end

-- Texture recadrée et teintée ; faux (illustration cachée, décor peint visible) sinon. En essai :
-- recadrage du candidat, sans décalage ni teinte, pour juger l'image telle quelle.
function S.applyArt(entry)
  local art = S.art
  local cand = S.chosen(entry)
  if not cand then art:Hide() return false end
  if art:SetTexture(cand.file) == false then art:Hide() return false end
  local trial = S.trial ~= nil
  local c = cand.crop or { 0, 1, 0, 1 }
  local top, bottom = c[3], c[4]
  local shift = not trial and entry.shift or 0
  if top + shift < 0 then shift = -top elseif bottom + shift > 1 then shift = 1 - bottom end
  art:SetTexCoord(c[1], c[2], top + shift, bottom + shift)
  local t = not trial and entry.tint or { 1, 1, 1 }
  art:SetVertexColor(t[1], t[2], t[3], 1)
  art:Show()
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

-- Rapport de /slay art : une ligne par décor (peint ou candidat validé), puis les verdicts.
function S.report()
  local lines = {}
  local ids = {}
  for id in pairs(Art.scenes) do ids[#ids + 1] = id end
  table.sort(ids)
  local off = opts().decor == false
  for _, id in ipairs(ids) do
    local entry = Art.scenes[id]
    if not entry.art then
      lines[#lines + 1] = id .. " : peint (pas d'illustration)"
    else
      local list, cand = candidates(entry.art), nil
      for _, c in ipairs(list) do
        if S.verdict(c) == true then cand = c break end
      end
      if not cand then
        lines[#lines + 1] = id .. " : peint (aucun des " .. #list .. " candidats validé)"
      else
        lines[#lines + 1] = id .. " : " .. tostring(cand.file) .. " — " .. (cand.name or "sans nom")
          .. (off and " (illustrations désactivées : peint)" or "")
      end
    end
  end
  local ok, ko, todo = {}, {}, 0
  for _, c in ipairs(S.trialList()) do
    local v = S.verdict(c)
    local label = tostring(c.file) .. " (" .. (c.name or "sans nom") .. ")"
    if v == true then ok[#ok + 1] = label elseif v == false then ko[#ko + 1] = label else todo = todo + 1 end
  end
  lines[#lines + 1] = "validés : " .. (#ok > 0 and table.concat(ok, ", ") or "aucun")
  lines[#lines + 1] = "refusés : " .. (#ko > 0 and table.concat(ko, ", ") or "aucun")
  lines[#lines + 1] = "pas encore jugés : " .. todo .. " sur " .. #S.trialList() .. " (/slay decor essai)"
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

-- Cadre de personnage : w × h, pieds au bas du cadre (feetY depuis le bas).
function S.figure(parent, w, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, h)
  f.ring = CreateFrame("Frame", nil, f)
  f.ring:SetSize(w * 0.9, 24)
  f.ring:SetPoint("BOTTOM", 0, -2)
  f.ring.outer = W.disc(f.ring, "BACKGROUND", 0, C.gold, 0.95)
  f.ring.outer:SetAllPoints()
  f.ring.inner = W.disc(f.ring, "BACKGROUND", 1, C.shadow, 0.9)
  f.ring.inner:SetPoint("TOPLEFT", 4, -3)
  f.ring.inner:SetPoint("BOTTOMRIGHT", -4, 3)
  f.ring:Hide()
  f.shadow = W.disc(f, "BACKGROUND", 2, C.shadow, 0.55)
  f.shadow:SetSize(w * 0.78, 16)
  f.shadow:SetPoint("BOTTOM", 0, 2)
  f.model = W.model(f, w, h)
  f.model:SetPoint("BOTTOM", 0, 0)
  f.fallback = f:CreateTexture(nil, "ARTWORK")
  f.fallback:SetSize(56, 56)
  f.fallback:SetPoint("CENTER", 0, 0)
  f.fallback:Hide()
  f.SetRing = function(self, on, hover)
    if on then
      self.ring:Show()
      self.ring.outer:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], hover and 0.6 or 0.95)
    else
      self.ring:Hide()
    end
  end
  return f
end

function S.playerFigure(f)
  f.model:SetUnit("player")
  f.model.dead = false
  W.modelAlpha(f.model, 1)
  if f.model.SetFacing then f.model:SetFacing(opts().facingPlayer or 0.6) end
end

-- Personnage de rencontre : modèle si l'identifiant est connu, sinon rien.
function S.npcFigure(f, npcId)
  f.fallback:Hide()
  local art = npcId and Art.npcs[npcId]
  if not art then
    f.model:Hide()
    f.shadow:Hide()
    return false
  end
  f.model:Show()
  f.shadow:Show()
  W.setCreatureArt(f.model, art, "npc:" .. npcId, function() f.model:Hide() f.shadow:Hide() end)
  if f.model.SetFacing then f.model:SetFacing(opts().facingEnemy or -0.6) end
  return true
end
