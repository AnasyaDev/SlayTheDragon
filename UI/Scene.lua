-- Scène commune à tous les écrans : décor plein cadre en haut (illustration du jeu ou décor peint
-- de repli en couches unies, aux couleurs des maquettes), plateau de bois en bas, personnages
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

  -- Sondes des illustrations : un cadre visible mais recouvert par le décor (niveau inférieur),
  -- une petite texture par illustration pour vérifier qu'un candidat se charge vraiment.
  local probe = CreateFrame("Frame", nil, parent)
  at(probe, parent, 0, S.TOP, 8, 8)
  probe:SetFrameLevel(parent:GetFrameLevel())
  S.probeFrame = probe
  S.resolveAll()
end

---------------------------------------------------------------------------
-- Illustrations : premier candidat qui se charge réellement, sinon repli sur le décor peint
---------------------------------------------------------------------------
-- Pour chaque candidat (Art.illustrations) : SetTexture doit réussir (pas `false`), la texture doit
-- avoir un FileDataID, puis IsObjectLoaded() doit devenir vrai (chargement asynchrone) dans le délai
-- (compté seulement fenêtre visible). Sinon : candidat suivant ; plus de candidat : repli peint.

S.POLL, S.TIMEOUT = 0.25, 4
S.illus = {}   -- clé -> { state = "pending" | "ok" | "fallback", list, index, cand, log = {} }

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

function S.fileName(file)
  if type(file) == "string" then return file end
  local get = C_Texture and C_Texture.GetFilenameFromFileDataID
  if not get then return nil end
  local ok, name = pcall(get, file)
  if ok and type(name) == "string" and name ~= "" then return name end
  return nil
end

local function resolved(key)
  -- le décor affiché utilise cette illustration : on le reprend
  local entry = S.entry
  if entry and entry.art == key and S.scene ~= false then S.applyArt(entry) end
end

local function tryCandidate(key, i)
  local st = S.illus[key]
  local cand = st.list[i]
  st.index = i
  if not cand then
    st.state, st.cand = "fallback", nil
    resolved(key)
    return
  end
  st.state = "pending"
  local tex = st.probe
  local ok = tex:SetTexture(cand.file)
  if ok == false then
    st.log[i] = "refusé"
    return tryCandidate(key, i + 1)
  end
  if tex.GetTextureFileID then
    local fid = tex:GetTextureFileID()
    if not fid or fid == 0 then
      st.log[i] = "sans fichier"
      return tryCandidate(key, i + 1)
    end
  end
  local waited = 0
  local function poll()
    if st.index ~= i or st.state ~= "pending" then return end
    if not tex.IsObjectLoaded or tex:IsObjectLoaded() then
      st.state, st.cand, st.log[i] = "ok", cand, "retenu"
      resolved(key)
      return
    end
    local visible = S.probeFrame:IsVisible()
    if visible then waited = waited + S.POLL end
    if waited >= S.TIMEOUT then
      st.log[i] = "non chargé"
      return tryCandidate(key, i + 1)
    end
    W.delay(visible and S.POLL or 1, poll)
  end
  poll()
end

function S.resolve(key)
  if S.illus[key] then return S.illus[key] end
  local probe = S.probeFrame:CreateTexture(nil, "BACKGROUND")
  probe:SetSize(4, 4)
  probe:SetPoint("TOPLEFT", 0, 0)
  local st = { state = "pending", list = candidates(key), log = {}, probe = probe }
  S.illus[key] = st
  tryCandidate(key, 1)
  return st
end

function S.resolveAll()
  local keys = {}
  for key in pairs(Art.illustrations) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do S.resolve(key) end
end

-- Illustration retenue pour un décor (candidat ou nil).
function S.chosen(entry)
  local st = entry and entry.art and S.illus[entry.art]
  return st and st.state == "ok" and st.cand or nil
end

-- Texture recadrée et teintée ; faux (illustration cachée, décor peint visible) sinon.
function S.applyArt(entry)
  local art = S.art
  local cand = S.chosen(entry)
  if not cand or opts().decor == false then art:Hide() return false end
  if art:SetTexture(cand.file) == false then art:Hide() return false end
  local c = cand.crop or { 0, 1, 0, 1 }
  local top, bottom = c[3], c[4]
  local shift = entry.shift or 0
  if top + shift < 0 then shift = -top elseif bottom + shift > 1 then shift = 1 - bottom end
  art:SetTexCoord(c[1], c[2], top + shift, bottom + shift)
  local t = entry.tint or { 1, 1, 1 }
  art:SetVertexColor(t[1], t[2], t[3], 1)
  art:Show()
  return true
end

-- Rapport de /slay art : une ligne par décor.
function S.report()
  local lines = {}
  local ids = {}
  for id in pairs(Art.scenes) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local entry = Art.scenes[id]
    local line
    if not entry.art then
      line = id .. " : peint (pas d'illustration)"
    else
      local st = S.illus and S.illus[entry.art]
      if not st then
        line = id .. " : pas encore essayé (ouvrir la fenêtre)"
      elseif st.state == "ok" then
        local name = S.fileName(st.cand.file)
        line = id .. " : candidat " .. st.index .. "/" .. #st.list .. " = " .. tostring(st.cand.file)
          .. (name and name ~= st.cand.file and (" (" .. name .. ")") or "")
      elseif st.state == "fallback" then
        line = id .. " : repli (décor peint)"
      else
        line = id .. " : en cours (candidat " .. tostring(st.index) .. "/" .. #st.list .. ")"
      end
      if st and st.state ~= "pending" then
        local refused = {}
        for i = 1, #st.list do
          if st.log[i] and st.log[i] ~= "retenu" then
            refused[#refused + 1] = tostring(st.list[i].file) .. " " .. st.log[i]
          end
        end
        if #refused > 0 then line = line .. " ; écartés : " .. table.concat(refused, ", ") end
      end
    end
    lines[#lines + 1] = line
  end
  return lines
end

-- stage = { scene = clé d'Art.scenes | false, board = bool, veil = 0..1 }
function S.set(stage)
  stage = stage or {}
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
    S.veil:SetColorTexture(0, 0, 0, stage.veil or 0)
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
