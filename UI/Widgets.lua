-- Briques d'interface « table de jeu illustrée » : formes (rectangles arrondis, disques), polices,
-- sons, interpolations (tweens), icônes vérifiées, carte unique (main, récompense, marchand, deck),
-- barres de vie, pastilles d'état, boutons, infobulles, textes flottants, modèles 3D.
-- Seule couche (avec Main/Scene/CombatView/Screens/Flight) à toucher l'API WoW.
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local Art = ns.Art
local Card = ns.Card
local C = Art.C

local W = {}
ns.Widgets = W

W.missing = {}   -- icônes ou modèles introuvables en jeu (pour /slay art)

local WHITE = Art.tex.white
local floor, max, min, sin = math.floor, math.max, math.min, math.sin

---------------------------------------------------------------------------
-- Temps, vitesse, interpolations
---------------------------------------------------------------------------

function W.delay(sec, fn)
  if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end
end

-- Multiplicateur appliqué aux durées d'animation.
function W.pace()
  local o = ns.Persist.options()
  if o.fast then return 0.15 end
  local s = o.speed or 1
  if s < 0.25 then s = 0.25 end
  return 1 / s
end

-- Un seul OnUpdate partagé (W.driver) fait avancer deux sortes d'animations, et se coupe dès que
-- plus rien ne bouge :
--   * les interpolations W.tween (durée fixe, fn(p) de 0 à 1 : vols de cartes, chiffres, fondus) ;
--   * les canaux animés W.animTo (une valeur par objet et par clé qui file vers une cible, et repart
--     de sa valeur courante si la cible change en route : survols réversibles).
-- Chaque animation a aussi un minuteur de secours qui la termine (le client peut sauter des images ;
-- le harnais n'a pas d'OnUpdate).
local tweens = {}
local animated = {}   -- objet -> vrai tant qu'un de ses canaux bouge
local driver = CreateFrame("Frame")
W.driver = driver

local function finishTween(tw)
  if tw.done then return end
  tw.done = true
  tweens[tw] = nil
  if tw.fn then tw.fn(1) end
  if tw.onDone then tw.onDone() end
end

W.ease = {
  out = function(p) return 1 - (1 - p) * (1 - p) end,
  -- sortie amortie (survols) : départ vif, arrivée douce
  outCubic = function(p) local q = 1 - p return 1 - q * q * q end,
  inOut = function(p) if p < 0.5 then return 2 * p * p end return 1 - 2 * (1 - p) * (1 - p) end,
  linear = function(p) return p end,
}

-- Fait avancer les canaux d'un objet ; vrai si l'un d'eux bouge encore.
local function stepChannels(obj, dt)
  local moving = false
  for _, ch in pairs(obj._ch) do
    if ch.t < ch.dur then
      ch.t = ch.t + dt
      if ch.t >= ch.dur then
        ch.t, ch.v = ch.dur, ch.to
      else
        ch.v = ch.from + (ch.to - ch.from) * W.ease.outCubic(ch.t / ch.dur)
        moving = true
      end
    end
  end
  if obj._animApply then obj:_animApply() end
  return moving
end

local running, runningObjs = {}, {}
local onUpdate
local function sleepIfIdle()
  if driver.awake and next(tweens) == nil and next(animated) == nil then
    driver.awake = false
    driver:SetScript("OnUpdate", nil)
  end
end
local function wake()
  if not driver.awake then
    driver.awake = true
    driver:SetScript("OnUpdate", onUpdate)
  end
end

onUpdate = function(_, elapsed)
  elapsed = elapsed or 0
  -- copies : les rappels peuvent lancer d'autres animations pendant le parcours
  local n = 0
  for tw in pairs(tweens) do n = n + 1 running[n] = tw end
  for i = 1, n do
    local tw = running[i]
    running[i] = nil
    if not tw.done then
      tw.t = tw.t + elapsed
      if tw.t >= tw.dur then
        finishTween(tw)
      elseif tw.fn then
        local p = tw.t / tw.dur
        tw.fn(tw.ease and tw.ease(p) or p)
      end
    end
  end
  local m = 0
  for obj in pairs(animated) do m = m + 1 runningObjs[m] = obj end
  for i = 1, m do
    local obj = runningObjs[i]
    runningObjs[i] = nil
    if animated[obj] and not stepChannels(obj, elapsed) then
      animated[obj] = nil
      if obj.onAnimSettled then obj:onAnimSettled() end
    end
  end
  sleepIfIdle()
end

-- fn(p) avec p de 0 à 1 ; owner/key : une nouvelle interpolation remplace l'ancienne de même clé.
function W.tween(dur, fn, onDone, owner, key, ease)
  dur = max(0.01, dur * W.pace())
  local tw = { t = 0, dur = dur, fn = fn, onDone = onDone, ease = ease or W.ease.out }
  if owner and key then
    owner._tweens = owner._tweens or {}
    local old = owner._tweens[key]
    if old and not old.done then old.done = true tweens[old] = nil end
    owner._tweens[key] = tw
  end
  tweens[tw] = true
  wake()
  if fn then fn(0) end
  W.delay(dur + 0.02, function() finishTween(tw) sleepIfIdle() end)
  return tw
end

function W.cancel(owner, key)
  local tw = owner and owner._tweens and owner._tweens[key]
  if tw and not tw.done then tw.done = true tweens[tw] = nil end
end

-- Canaux animés -----------------------------------------------------------------------------

W.HOVER_IN, W.HOVER_OUT = 0.12, 0.15  -- survols : entrée vive, sortie un peu plus douce

-- Valeur courante d'un canal (rest si jamais animé).
function W.animValue(obj, key, rest)
  local ch = obj._ch and obj._ch[key]
  if ch then return ch.v end
  return rest or 0
end

-- Pose une valeur sans animation.
function W.animSet(obj, key, value)
  obj._ch = obj._ch or {}
  local ch = obj._ch[key] or {}
  obj._ch[key] = ch
  ch.v, ch.from, ch.to, ch.t, ch.dur = value, value, value, 0, 0
  ch.token = (ch.token or 0) + 1
  if obj._animApply then obj:_animApply() end
end

-- Fait filer le canal `key` de obj vers `target` en `dur` secondes, depuis sa valeur courante
-- (réversible : une cible qui change en route repart de là où l'on en est). obj._animApply(obj)
-- est appelé à chaque image ; obj.onAnimSettled(obj) quand plus aucun canal ne bouge.
function W.animTo(obj, key, target, dur, rest)
  obj._ch = obj._ch or {}
  local ch = obj._ch[key]
  if not ch then
    local v0 = rest or 0
    ch = { v = v0, from = v0, to = v0, t = 0, dur = 0 }
    obj._ch[key] = ch
  end
  if ch.to == target then return end
  dur = dur or W.HOVER_IN
  if dur <= 0 then W.animSet(obj, key, target) return end
  ch.from, ch.to, ch.t, ch.dur = ch.v, target, 0, dur
  ch.token = (ch.token or 0) + 1
  local token = ch.token
  animated[obj] = true
  wake()
  W.delay(dur + 0.05, function()
    if ch.token ~= token or ch.t >= ch.dur then return end
    ch.t, ch.v = ch.dur, ch.to
    if obj._animApply then obj:_animApply() end
    for _, other in pairs(obj._ch) do if other.t < other.dur then return end end
    animated[obj] = nil
    if obj.onAnimSettled then obj:onAnimSettled() end
    sleepIfIdle()
  end)
end

-- Vrai si le pilote tourne (pour le harnais : il doit s'arrêter quand tout est immobile).
function W.driverAwake() return driver.awake and true or false end

---------------------------------------------------------------------------
-- Survols : zone de survol fixe, visuel animé
---------------------------------------------------------------------------
-- Piège évité : animer l'échelle ou la position du cadre qui reçoit la souris ferait sortir le
-- curseur de la zone (entrée/sortie en boucle). Le cadre interactif reste donc immobile (zone de
-- survol) ; tout ce qui se voit vit dans son enfant `face`, seul animé (échelle, décalage).

-- Crée le visuel `f.face`, centré sur f, de même taille (suivie par OnSizeChanged).
function W.face(f)
  local face = CreateFrame("Frame", nil, f)
  face:SetSize(f:GetWidth(), f:GetHeight())
  face:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.face = face
  f:SetScript("OnSizeChanged", function(self, w, h) if w and h then self.face:SetSize(w, h) end end)
  return face
end

-- Applique les canaux « hover » (0..1) et « dx » (pixels) au visuel.
function W.faceApply(f)
  local face = f.face
  if not face then return end
  local h = W.animValue(f, "hover")
  local dx = W.animValue(f, "dx")
  local s = 1 + ((f.hoverScale or 1) - 1) * h
  face:SetScale(s)
  face:ClearAllPoints()
  face:SetPoint("CENTER", f, "CENTER", dx / s, (f.hoverLift or 0) * h / s)
  if f.hoverPaint then f:hoverPaint(h) end
end

-- Rend f survolable : opts = { scale, lift (unités de f, vers le haut), paint(f, h), manual }.
-- manual = l'écran pilote lui-même le canal « hover » (main, cartes à sélection).
function W.hoverable(f, opts)
  opts = opts or {}
  if not f.face then W.face(f) end
  f._hoverable = true
  f.hoverScale = opts.scale or 1.06
  f.hoverLift = opts.lift or 0
  f.hoverPaint = opts.paint or f.hoverPaint
  f._hoverManual = opts.manual
  f._animApply = W.faceApply
  return f
end

function W.hoverEnter(f)
  if f._hoverable and not f._hoverManual and f.active ~= false then W.animTo(f, "hover", 1, W.HOVER_IN) end
end

function W.hoverLeave(f)
  if f._hoverable and not f._hoverManual then W.animTo(f, "hover", 0, W.HOVER_OUT) end
end

-- Remet un visuel au repos sans animation (écran qui se reconstruit, cadre caché).
function W.hoverReset(f)
  if f._ch then
    for key in pairs(f._ch) do W.animSet(f, key, 0) end
  end
end

---------------------------------------------------------------------------
-- Sons (identifiants SOUNDKIT, voir Art.sounds)
---------------------------------------------------------------------------

local lastSound = {}
function W.sound(key)
  local name = Art.sounds[key]
  local id = name and SOUNDKIT and SOUNDKIT[name]
  if not id or not PlaySound then return end
  local t = GetTime and GetTime() or 0
  if lastSound[key] and t - lastSound[key] < 0.08 then return end
  lastSound[key] = t
  pcall(PlaySound, id)
end

---------------------------------------------------------------------------
-- Couleurs, formes
---------------------------------------------------------------------------

function W.rgb(c) return c[1], c[2], c[3] end

-- Texture unie.
function W.rect(parent, layer, sub, color, alpha)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
  t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
  return t
end

-- Disque (texture ronde teintée).
function W.disc(parent, layer, sub, color, alpha)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
  t:SetTexture(Art.tex.circle)
  t:SetVertexColor(color[1], color[2], color[3], alpha or 1)
  return t
end

-- Dégradé vertical (haut -> bas) ; repli : couleur du bas.
function W.gradient(tex, top, bottom)
  tex:SetTexture(WHITE)
  if CreateColor and tex.SetGradient then
    tex:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
      CreateColor(top[1], top[2], top[3], top[4] or 1))
  else
    tex:SetColorTexture(bottom[1], bottom[2], bottom[3], bottom[4] or 1)
  end
end

-- Rectangle arrondi en 7 textures sans recouvrement (alpha propre) : bandes + quarts de disque.
-- inset > 0 rentre la forme dans le cadre, < 0 la fait déborder (halo).
local RR = {}
RR.__index = RR

function W.roundRect(parent, layer, sub, radius, inset)
  local o = setmetatable({ parts = {}, r = radius, inset = inset or 0, parent = parent }, RR)
  local function tex() local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0) o.parts[#o.parts + 1] = t return t end
  o.mid, o.top, o.bot = tex(), tex(), tex()
  o.tl, o.tr, o.bl, o.br = tex(), tex(), tex(), tex()
  for _, t in ipairs({ o.mid, o.top, o.bot }) do t:SetTexture(WHITE) end
  for _, t in ipairs({ o.tl, o.tr, o.bl, o.br }) do t:SetTexture(Art.tex.circle) end
  o.tl:SetTexCoord(0, 0.5, 0, 0.5)
  o.tr:SetTexCoord(0.5, 1, 0, 0.5)
  o.bl:SetTexCoord(0, 0.5, 0.5, 1)
  o.br:SetTexCoord(0.5, 1, 0.5, 1)
  o:Layout()
  return o
end

function RR:Layout()
  local p, r, i = self.parent, self.r, self.inset
  for _, t in ipairs(self.parts) do t:ClearAllPoints() end
  self.mid:SetPoint("TOPLEFT", p, "TOPLEFT", i, -i - r)
  self.mid:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -i, i + r)
  self.top:SetPoint("TOPLEFT", p, "TOPLEFT", i + r, -i)
  self.top:SetPoint("BOTTOMRIGHT", p, "TOPRIGHT", -i - r, -i - r)
  self.bot:SetPoint("TOPLEFT", p, "BOTTOMLEFT", i + r, i + r)
  self.bot:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -i - r, i)
  for _, t in ipairs({ self.tl, self.tr, self.bl, self.br }) do t:SetSize(r, r) end
  self.tl:SetPoint("TOPLEFT", p, "TOPLEFT", i, -i)
  self.tr:SetPoint("TOPRIGHT", p, "TOPRIGHT", -i, -i)
  self.bl:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", i, i)
  self.br:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -i, i)
end

function RR:SetColor(c, a)
  local r, g, b = c[1], c[2], c[3]
  a = a or 1
  self.mid:SetColorTexture(r, g, b, a)
  self.top:SetColorTexture(r, g, b, a)
  self.bot:SetColorTexture(r, g, b, a)
  for _, t in ipairs({ self.tl, self.tr, self.bl, self.br }) do t:SetVertexColor(r, g, b, a) end
  self.color = c
  return self
end

function RR:SetAlpha(a)
  for _, t in ipairs(self.parts) do t:SetAlpha(a) end
end

function RR:SetShown(on)
  for _, t in ipairs(self.parts) do if on then t:Show() else t:Hide() end end
  self.shown = on
end
function RR:Show() self:SetShown(true) end
function RR:Hide() self:SetShown(false) end

-- Forme bordée : bord + fond (+ grain de parchemin facultatif).
function W.shape(parent, radius, edge, fill, edgeW, layerSub, grain)
  local base = layerSub or -6
  local o = {}
  o.edge = W.roundRect(parent, "BACKGROUND", base, radius, 0):SetColor(edge)
  o.fill = W.roundRect(parent, "BACKGROUND", base + 1, max(1, radius - (edgeW or 2)), edgeW or 2):SetColor(fill)
  if grain then
    o.grain = parent:CreateTexture(nil, "BACKGROUND", nil, base + 2)
    o.grain:SetTexture(Art.tex.parchment)
    o.grain:SetPoint("TOPLEFT", (edgeW or 2) + 3, -(edgeW or 2) - 3)
    o.grain:SetPoint("BOTTOMRIGHT", -(edgeW or 2) - 3, (edgeW or 2) + 3)
    o.grain:SetAlpha(grain)
  end
  return o
end

---------------------------------------------------------------------------
-- Polices
---------------------------------------------------------------------------

W.FONT_TITLE = "Fonts\\MORPHEUS.ttf"
W.FONT_BODY = "Fonts\\FRIZQT__.TTF"

-- kind = "title" (Morpheus, titres et chiffres) ou "body" ; color = couleur Art.C ; shadow = vrai.
function W.label(parent, kind, size, color, layer, shadow)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlight")
  local file = kind == "title" and W.FONT_TITLE or W.FONT_BODY
  local ok = fs:SetFont(file, size or 12, "")
  if ok == false then
    local f = fs:GetFont()
    if f then fs:SetFont(f, size or 12, "") end
  end
  fs._size = size or 12
  fs._fontKind = kind
  if color then fs:SetTextColor(color[1], color[2], color[3]) end
  if shadow then
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
  else
    fs:SetShadowOffset(0, 0)
  end
  return fs
end

function W.setSize(fs, size)
  if fs._size == size then return end
  fs._size = size
  local ok = fs:SetFont(fs._fontKind == "title" and W.FONT_TITLE or W.FONT_BODY, size, "")
  if ok == false then
    local f = fs:GetFont()
    if f then fs:SetFont(f, size, "") end
  end
end

-- Compatibilité : texte à objet de police Blizzard.
function W.text(parent, font, size, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlight")
  if size then
    local f, _, flags = fs:GetFont()
    if f then fs:SetFont(f, size, flags) end
  end
  return fs
end

function W.utf8len(s)
  local n = 0
  for _ in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
  return n
end

local function hexOf(c)
  return string.format("%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end
W.hexOf = hexOf

function W.colorize(text, c)
  return "|cff" .. hexOf(c) .. text .. "|r"
end

---------------------------------------------------------------------------
-- Icônes
---------------------------------------------------------------------------

local function noteMissing(key)
  if key then W.missing[key] = true end
end

-- entry = { spell = id, icon = FileDataID ou chemin } ; key sert au rapport /slay art.
function W.setIcon(tex, entry, key)
  entry = entry or {}
  if entry.spell and C_Spell and C_Spell.GetSpellTexture then
    local ok, id = pcall(C_Spell.GetSpellTexture, entry.spell)
    if ok and id then
      tex:SetTexture(id)
      return true
    end
  end
  if entry.icon then
    local ok = tex:SetTexture(entry.icon)
    local fid = tex.GetTextureFileID and tex:GetTextureFileID()
    if ok ~= false and (fid == nil and not tex.GetTextureFileID or fid) then return true end
  end
  noteMissing(key)
  tex:SetTexture(Art.QUESTION)
  return false
end

function W.cardArt(id)
  local e = Art.cards[id]
  if e then return e end
  local d = ns.Cards[id]
  return d and Art.schools[d.school] or nil
end

-- Masque rond sur une texture d'icône (si l'API existe).
function W.roundMask(frame, tex)
  if not frame.CreateMaskTexture or not tex.AddMaskTexture then return end
  local m = frame:CreateMaskTexture()
  m:SetTexture(Art.tex.circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetAllPoints(tex)
  tex:AddMaskTexture(m)
  return m
end

-- Médaillon : disque de couleur, fond sombre, icône ronde.
function W.medallion(parent, size, layerSub)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  f.ring = W.disc(f, "ARTWORK", (layerSub or 0), C.wood)
  f.ring:SetAllPoints()
  f.inner = W.disc(f, "ARTWORK", (layerSub or 0) + 1, C.ink)
  f.icon = f:CreateTexture(nil, "ARTWORK", nil, (layerSub or 0) + 2)
  f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  W.roundMask(f, f.icon)
  f.Resize = function(self, s, ringW)
    self:SetSize(s, s)
    ringW = ringW or max(2, floor(s / 16))
    self.inner:ClearAllPoints()
    self.inner:SetPoint("TOPLEFT", ringW, -ringW)
    self.inner:SetPoint("BOTTOMRIGHT", -ringW, ringW)
    self.icon:ClearAllPoints()
    self.icon:SetPoint("TOPLEFT", ringW + 1, -ringW - 1)
    self.icon:SetPoint("BOTTOMRIGHT", -ringW - 1, ringW + 1)
  end
  f.SetRing = function(self, c) self.ring:SetVertexColor(c[1], c[2], c[3], 1) end
  f:Resize(size)
  return f
end

---------------------------------------------------------------------------
-- Cadres de base
---------------------------------------------------------------------------

function W.create(kind, name, parent, template)
  if template then
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
  end
  return CreateFrame(kind, name, parent)
end

-- Panneau de parchemin bordé (bilan, accueil, options, grilles).
function W.parchment(parent, radius)
  local f = CreateFrame("Frame", nil, parent)
  f:EnableMouse(true)
  f.shape = W.shape(f, radius or 10, C.mapEdge, C.map, 4, -6, 0.35)
  return f
end

-- Panneau de bois sombre.
function W.woodPanel(parent, radius)
  local f = CreateFrame("Frame", nil, parent)
  f:EnableMouse(true)
  f.shape = W.shape(f, radius or 8, C.wood, C.board, 3, -6)
  return f
end

-- Bouton générique dessiné : style = "gold" | "wood" | "parchment" | "red".
local STYLES = {
  gold = { edge = C.creamLight, fill = C.gold, hover = { 1, 0.86, 0.48 }, text = C.ink, font = "title" },
  wood = { edge = C.woodLine, fill = C.woodDark, hover = { 0.38, 0.27, 0.17 }, text = C.cream, font = "body" },
  parchment = { edge = C.edgeCommon, fill = C.parchment, hover = C.parchmentLight, text = C.ink, font = "title" },
  red = { edge = C.redEdge, fill = C.red, hover = { 0.6, 0.22, 0.15 }, text = C.creamLight, font = "body" },
}

local function lerpColor(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
W.lerpColor = lerpColor

-- Survol d'un bouton : le fond glisse vers la couleur de survol.
local function buttonPaint(self, h)
  local st = self.style
  if self.active == false then h = 0 end
  self.shape.fill:SetColor(h > 0 and lerpColor(st.fill, st.hover, h) or st.fill)
end

function W.button(parent, label, w, h, onClick, style, size)
  local st = STYLES[style or "wood"]
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 120, h or 26)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.style = st
  local face = W.face(b)
  local radius = min(8, floor((h or 26) / 3))
  b.shape = W.shape(face, radius, st.edge, st.fill, (h or 26) >= 40 and 3 or 2, -6, style == "parchment" and 0.25 or nil)
  b.label = W.label(face, st.font, size or ((h or 26) >= 40 and 16 or 12), st.text)
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetText(label or "")
  b.SetText = function(self, t) self.label:SetText(t or "") self._text = t end
  b.GetText = function(self) return self.label:GetText() end
  b._text = label
  W.hoverable(b, { scale = (h or 26) >= 40 and 1.04 or 1.06, paint = buttonPaint })
  b:SetScript("OnEnter", function(self)
    W.hoverEnter(self)
    if self.onEnterExtra then self:onEnterExtra() end
  end)
  b:SetScript("OnLeave", function(self)
    W.hoverLeave(self)
    if self.onLeaveExtra then self:onLeaveExtra() end
  end)
  b.SetActive = function(self, on)
    self.active = on
    self:SetAlpha(on and 1 or 0.5)
    if on then self:Enable() else self:Disable() W.animTo(self, "hover", 0, W.HOVER_OUT) end
  end
  if onClick then b:SetScript("OnClick", function(self, button)
    W.sound("click")
    onClick(self, button)
  end) end
  return b
end

-- Bouton rond (≡, ×).
function W.roundButton(parent, glyph, size, fill, edge, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  local face = W.face(b)
  b.edge = W.disc(face, "BACKGROUND", 0, edge)
  b.edge:SetAllPoints()
  b.fill = W.disc(face, "BACKGROUND", 1, fill)
  b.fill:SetPoint("TOPLEFT", 2, -2)
  b.fill:SetPoint("BOTTOMRIGHT", -2, 2)
  b.label = W.label(face, "body", 15, C.creamLight)
  b.label:SetPoint("CENTER", 0, 1)
  if glyph == "menu" then
    -- trois traits (le glyphe ≡ manque aux polices du jeu)
    for i = -1, 1 do
      local l = W.rect(face, "ARTWORK", 0, C.creamLight)
      l:SetSize(size * 0.42, 2)
      l:SetPoint("CENTER", 0, i * 5)
    end
  else
    b.label:SetText(glyph)
  end
  W.hoverable(b, { scale = 1.12, paint = function(self, h)
    local k = 1 + 0.3 * h
    self.fill:SetVertexColor(fill[1] * k, fill[2] * k, fill[3] * k, 1)
  end })
  b:SetScript("OnEnter", function(self) W.hoverEnter(self) end)
  b:SetScript("OnLeave", function(self) W.hoverLeave(self) end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

-- Case à cocher faite main (textures classiques, sans dépendre d'un modèle XML).
function W.check(parent, label, getter, setter)
  local b = CreateFrame("CheckButton", nil, parent)
  b:SetSize(24, 24)
  b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  local fs = W.label(b, "body", 12, C.ink)
  fs:SetPoint("LEFT", b, "RIGHT", 4, 0)
  fs:SetText(label)
  b.label = fs
  b:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
  b.Sync = function(self) self:SetChecked(getter() and true or false) end
  return b
end

---------------------------------------------------------------------------
-- Barre de vie (portion perdue claire qui se vide) et écusson d'Absorption
---------------------------------------------------------------------------

function W.hpBar(parent, w, h, textSize)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, h)
  f.w = w
  f.edge = W.rect(f, "BACKGROUND", 0, C.barEdge)
  f.edge:SetAllPoints()
  f.bg = W.rect(f, "BACKGROUND", 1, C.barBg)
  f.bg:SetPoint("TOPLEFT", 2, -2)
  f.bg:SetPoint("BOTTOMRIGHT", -2, 2)
  f.ghost = W.rect(f, "ARTWORK", 0, C.ghost, 0.85)
  f.ghost:SetPoint("TOPLEFT", 2, -2)
  f.ghost:SetPoint("BOTTOMLEFT", 2, 2)
  f.fill = W.rect(f, "ARTWORK", 1, C.hp)
  f.fill:SetPoint("TOPLEFT", 2, -2)
  f.fill:SetPoint("BOTTOMLEFT", 2, 2)
  f.text = W.label(f, "body", textSize or 13, C.white, "OVERLAY", true)
  f.text:SetPoint("CENTER", 0, 0)
  local inner = w - 4
  local function width(frac) return max(0.01, inner * max(0, min(1, frac))) end
  -- animate : la portion perdue reste claire un instant puis se vide.
  f.Set = function(self, hp, maxHp, animate)
    hp = max(0, hp)
    maxHp = maxHp > 0 and maxHp or 1
    local old = self.hp
    self.hp, self.maxHp = hp, maxHp
    self.text:SetText(hp .. " / " .. maxHp)
    self.fill:SetWidth(width(hp / maxHp))
    if animate and old and old > hp then
      local from = old / maxHp
      self.ghost:SetWidth(width(from))
      self.ghost:Show()
      W.delay(0.35 * W.pace(), function()
        if self.hp ~= hp then return end
        W.tween(0.4, function(p)
          self.ghost:SetWidth(width(from + (hp / maxHp - from) * p))
        end, function() self.ghost:Hide() end, self, "ghost")
      end)
    else
      W.cancel(self, "ghost")
      self.ghost:Hide()
    end
  end
  f.ghost:Hide()
  return f
end

-- Écusson d'Absorption (bleu, chiffre).
function W.shieldBadge(parent, w, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w or 34, h or 30)
  f:EnableMouse(true)
  f.shape = W.shape(f, 7, C.absorbEdge, C.absorb, 2, -4)
  f.text = W.label(f, "title", 15, C.absorbText)
  f.text:SetPoint("CENTER", 0, 0)
  f.Set = function(self, n)
    if n and n > 0 then self.text:SetText(tostring(n)) self:Show() else self:Hide() end
  end
  W.tooltip(f, function(tt)
    local kw = Art.keywords.absorb
    tt:AddLine(kw.name, 0.55, 0.75, 1)
    tt:AddLine(kw.text, 1, 1, 1, true)
  end, "ANCHOR_TOP")
  return f
end

---------------------------------------------------------------------------
-- Infobulles (seulement si on les demande, et seulement si elles ont quelque chose à dire)
---------------------------------------------------------------------------

-- Infobulle au survol ; anime aussi le survol si le cadre est survolable (W.hoverable).
function W.tooltip(frame, fill, anchor)
  frame:SetScript("OnEnter", function(self)
    W.hoverEnter(self)
    if self.onEnterExtra then self:onEnterExtra() end
    GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
    fill(GameTooltip, self)
    if GameTooltip:NumLines() > 0 then GameTooltip:Show() else GameTooltip:Hide() end
  end)
  frame:SetScript("OnLeave", function(self)
    W.hoverLeave(self)
    if self.onLeaveExtra then self:onLeaveExtra() end
    GameTooltip:Hide()
  end)
end

local function gold(tt, text) tt:AddLine(text, 1, 0.82, 0) end
local function wrap(tt, text, r, g, b) tt:AddLine(text, r or 1, g or 1, b or 1, true) end

function W.statusText(id, n)
  local s = ns.Statuses[id]
  if not s then return tostring(id), "" end
  local text = (s.text or ""):gsub("X", tostring(n or "X"))
  return s.name, text
end

function W.addStatusLines(tt, id, n)
  local name, text = W.statusText(id, n)
  local s = ns.Statuses[id]
  local suffix = ""
  if n and n > 0 then suffix = s and s.duration and (" (" .. n .. " tour" .. (n > 1 and "s" or "") .. ")")
    or (" " .. n) end
  local bad = s and (s.debuff or s.affix)
  tt:AddLine(name .. suffix, bad and 1 or 0.4, bad and 0.35 or 0.9, bad and 0.35 or 0.4)
  wrap(tt, text)
end

-- Mots-clés d'une définition de carte (pour l'infobulle).
function W.cardKeywords(d)
  local list, seen = {}, {}
  local function add(k, label)
    if seen[k] then return end
    seen[k] = true
    list[#list + 1] = { key = k, label = label }
  end
  if d.cast then add("cast") end
  if d.cooldown then add("cooldown", "Recharge " .. d.cooldown) end
  if d.exhaust then add("exhaust") end
  if d.retain then add("retain") end
  if d.power or d.type == "power" then add("power") end
  for i = 1, #(d.effects or {}) do
    local e = d.effects[i]
    if e[1] == "absorb" then add("absorb")
    elseif e[1] == "demence" then add("demence")
    elseif e[1] == "interrupt" then add("interrupt")
    elseif e[1] == "apply" then add("status:" .. e[2]) end
  end
  return list
end

-- Infobulle de carte : la carte se lit d'elle-même ; l'infobulle n'explique que les mots-clés,
-- l'amélioration (aperçu) et la raison d'un refus. full = nom et texte en plus (pouvoirs, recharges).
function W.fillCardTooltip(tt, id, up, extra)
  local d = Card.defById(id, up)
  if extra and extra.full then
    local rc = Art.rarityText[d.rarity] or Art.rarityText.common
    tt:AddLine(d.name, rc[1], rc[2], rc[3])
    wrap(tt, d.text or "")
  end
  if extra and extra.preview and not up and ns.Cards[id].up then
    local u = Card.defById(id, true)
    gold(tt, "Après amélioration :")
    wrap(tt, u.text or "", 0.5, 1, 0.5)
  end
  local kws = W.cardKeywords(d)
  for i = 1, #kws do
    local k = kws[i]
    if tt:NumLines() > 0 then tt:AddLine(" ") end
    if k.key:sub(1, 7) == "status:" then
      W.addStatusLines(tt, k.key:sub(8))
    else
      local kw = Art.keywords[k.key]
      gold(tt, k.label or (kw and kw.name) or k.key)
      if kw then wrap(tt, kw.text, 0.85, 0.85, 0.85) end
    end
  end
  if extra and extra.reason then
    if tt:NumLines() > 0 then tt:AddLine(" ") end
    tt:AddLine(extra.reason, 1, 0.3, 0.3, true)
  end
end

-- Bibelot, potion, or ou affixe : nom, effet, détail facultatif.
function W.fillItemTooltip(tt, kind, id, extra)
  if kind == "relic" then
    local r = ns.Relics[id]
    tt:AddLine(r and r.name or tostring(id), 0.6, 0.8, 1)
    if r and r.text then wrap(tt, r.text) end
  elseif kind == "potion" then
    local p = ns.Potions[id]
    tt:AddLine(p and p.name or tostring(id), 0.5, 1, 0.5)
    if p and p.text then wrap(tt, p.text) end
  elseif kind == "affix" then
    local a = ns.Affixes and ns.Affixes[id]
    gold(tt, a and a.name or tostring(id))
    if a and a.text then wrap(tt, a.text) end
  elseif extra and extra.title then
    gold(tt, extra.title)
  end
  if extra and extra.text and kind ~= "relic" and kind ~= "potion" and kind ~= "affix" then wrap(tt, extra.text) end
  if extra and extra.hint then wrap(tt, extra.hint, 0.7, 0.7, 0.7) end
  if extra and extra.reason then wrap(tt, extra.reason, 1, 0.3, 0.3) end
  if extra and extra.price then tt:AddLine(extra.price .. " po", 1, 0.82, 0) end
end

function W.itemEntry(kind, id)
  if kind == "relic" then return Art.relic(id) end
  if kind == "potion" then return Art.potion(id) end
  if kind == "affix" then return Art.affixes[id] end
  if kind == "gold" then return Art.ui.gold end
  if kind == "keystone" then return Art.keystone end
  return nil
end

-- Case à icône bordée (bibelot, potion, affixe, clé) ; info = { kind, id, ... } pour l'infobulle.
-- shape = "square" | "flask" | "round".
function W.iconButton(parent, size, shape)
  local b = CreateFrame("Button", nil, parent)
  local w, h = size, size
  if shape == "flask" then w, h = floor(size * 0.87), size end
  b:SetSize(w, h)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  local radius = shape == "flask" and floor(w / 3) or (shape == "round" and floor(size / 2) or 6)
  b.shape = W.shape(face, radius, C.woodLine, C.woodDark, 2, -4)
  b.icon = face:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 3, -3)
  b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if shape == "round" or shape == "flask" then W.roundMask(face, b.icon) end
  b.count = W.label(face, "title", 11, C.creamLight, "OVERLAY", true)
  b.count:SetPoint("BOTTOMRIGHT", 2, -2)
  W.hoverable(b, { scale = 1.14 })
  W.tooltip(b, function(tt, self)
    local info = self.info
    if not info then return end
    W.fillItemTooltip(tt, info.kind, info.id, info)
  end, "ANCHOR_BOTTOM")
  b.SetItem = function(self, kind, id, info)
    self.info = info or {}
    self.info.kind = kind or self.info.kind
    self.info.id = id
    if kind and (id or kind == "gold" or kind == "keystone") then
      W.setIcon(self.icon, W.itemEntry(kind, id), kind .. ":" .. tostring(id))
      self.icon:SetDesaturated(false)
      self.icon:Show()
      local edge = C.woodLine
      if kind == "relic" then
        local r = ns.Relics[id]
        edge = Art.rarity[r and r.rarity or "common"] or C.edgeCommon
      elseif kind == "potion" then
        edge = C.cream
      end
      self.shape.edge:SetColor(edge)
    else
      self.icon:SetTexture(nil)
      self.icon:Hide()
      self.shape.edge:SetColor(C.woodLine)
    end
  end
  return b
end

-- Barre de réputation : bar = { label, levelName, cur, size, detail, hint } (UI/Controller.lua).
function W.repBar(parent, w)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, 16)
  f:EnableMouse(true)
  f.edge = W.rect(f, "BACKGROUND", 0, C.inkSoft)
  f.edge:SetAllPoints()
  f.bg = W.rect(f, "BACKGROUND", 1, C.barBg)
  f.bg:SetPoint("TOPLEFT", 2, -2)
  f.bg:SetPoint("BOTTOMRIGHT", -2, 2)
  f.fill = W.rect(f, "ARTWORK", 0, C.goldDeep)
  f.fill:SetPoint("TOPLEFT", 2, -2)
  f.fill:SetPoint("BOTTOMLEFT", 2, 2)
  f.label = W.label(f, "title", 14, C.ink)
  f.label:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 3)
  f.value = W.label(f, "body", 11, C.creamLight, "OVERLAY", true)
  f.value:SetPoint("CENTER")
  f.detail = W.label(f, "body", 11, C.inkSoft)
  f.detail:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -3)
  W.tooltip(f, function(tt, self)
    local b = self.bar
    if not b then return end
    gold(tt, b.label)
    tt:AddLine(b.levelName .. (b.size and (" : " .. b.cur .. " / " .. b.size) or " (palier maximal)"), 1, 1, 1)
    if b.hint then wrap(tt, b.hint, 0.8, 0.8, 0.8) end
  end, "ANCHOR_TOP")
  f.Set = function(self, b)
    self.bar = b
    self.label:SetText(b.label)
    local frac = b.size and (b.cur / b.size) or 1
    self.fill:SetWidth(max(0.01, (w - 4) * frac))
    self.value:SetText(b.size and (b.levelName .. "  " .. b.cur .. " / " .. b.size) or b.levelName)
    self.detail:SetText(b.detail or "")
  end
  return f
end

---------------------------------------------------------------------------
-- Pastilles (états, mots-clés, Démence)
---------------------------------------------------------------------------

-- Pastille : fond sombre arrondi, bord coloré, texte.
function W.pill(parent, size)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(60, (size or 12) + 6)
  f.shape = W.shape(f, floor(((size or 12) + 6) / 2), C.goldDeep, C.band, 1, -4)
  f.text = W.label(f, "body", size or 12, C.gold)
  f.text:SetPoint("CENTER", 0, 0)
  f.Set = function(self, text, edge, ink, fill)
    self.text:SetText(text)
    self.text:SetTextColor(ink[1], ink[2], ink[3])
    self.shape.edge:SetColor(edge)
    self.shape.fill:SetColor(fill or C.band)
    local tw = self.text:GetStringWidth() or (#text * 6)
    self:SetWidth(tw + 16)
    return self:GetWidth()
  end
  return f
end

-- Rangée centrée de pastilles avec infobulle ; list = { {text, edge, ink, info} }.
function W.pillRow(parent, maxN, width, size)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, (size or 12) + 6)
  row.pills = {}
  for i = 1, maxN do
    local p = W.pill(row, size)
    p:EnableMouse(true)
    W.tooltip(p, function(tt, self)
      local info = self.info
      if not info then return end
      if info.status then W.addStatusLines(tt, info.status, info.n)
      elseif info.power then W.fillCardTooltip(tt, info.power.id, info.power.up, { full = true })
      else
        if info.title then gold(tt, info.title) end
        if info.text then wrap(tt, info.text) end
      end
    end, "ANCHOR_TOP")
    p:Hide()
    row.pills[i] = p
  end
  row.Set = function(self, list)
    local widths, total = {}, 0
    local n = min(#list, #self.pills)
    for i = 1, #self.pills do
      local p, it = self.pills[i], list[i]
      if it and i <= n then
        widths[i] = p:Set(it.text, it.edge, it.ink, it.fill)
        total = total + widths[i] + 4
        p.info = it.info
        p:Show()
      else
        p.info = nil
        p:Hide()
      end
    end
    -- deux lignes au plus, centrées
    local lineH = (size or 12) + 8
    local lines, cur, curW = {}, {}, 0
    for i = 1, n do
      if curW + widths[i] > width and #cur > 0 then lines[#lines + 1] = { cur, curW } cur, curW = {}, 0 end
      cur[#cur + 1] = i
      curW = curW + widths[i] + 4
    end
    if #cur > 0 then lines[#lines + 1] = { cur, curW } end
    for li, line in ipairs(lines) do
      local x = (width - (line[2] - 4)) / 2
      for _, i in ipairs(line[1]) do
        local p = self.pills[i]
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(li - 1) * lineH)
        x = x + widths[i] + 4
      end
    end
  end
  return row
end

-- États d'une unité en pastilles (triés par id, stable).
function W.unitStatuses(unit)
  local ids = {}
  for id, v in pairs(unit.st or {}) do if v and v ~= 0 then ids[#ids + 1] = id end end
  table.sort(ids)
  local list = {}
  for i = 1, #ids do
    local id, n = ids[i], unit.st[ids[i]]
    local s = ns.Statuses[id]
    local bad = s and (s.debuff or s.affix)
    local good = id == "regen" or id == "atonement" or id == "halved"
    list[#list + 1] = {
      text = (s and s.name or id) .. ((type(n) == "number" and n > 0) and (" " .. n) or ""),
      edge = bad and C.watch or (good and C.heal or C.goldDeep),
      ink = bad and C.watchText or (good and C.healText or C.gold),
      info = { status = id, n = n }, key = "status:" .. id,
    }
  end
  return list
end

---------------------------------------------------------------------------
-- Carte (composant unique : main, récompense, marchand, deck, amélioration)
---------------------------------------------------------------------------

W.CARD_W, W.CARD_H = 124, 176

local KEYWORD_STRIP = {
  { flag = "cooldown", pat = "%s*Recharge %d+%." },
  { flag = "exhaust", pat = "%s*Consumée%." },
  { flag = "retain", pat = "%s*Conservée%." },
  { flag = "cast", pat = "^Incantation%.%s*" },
  { flag = "power", pat = "^Pouvoir%.%s*" },
}

-- Texte affiché : sans les mots-clés déjà en pastilles, chiffres en évidence (verts s'ils
-- changent avec l'amélioration).
function W.cardBody(d, base)
  local text = d.text or ""
  for _, k in ipairs(KEYWORD_STRIP) do
    if d[k.flag] or (k.flag == "power" and d.type == "power") then text = text:gsub(k.pat, "") end
  end
  local baseNums = {}
  if base then for n in (base.text or ""):gmatch("%d+") do baseNums[#baseNums + 1] = n end end
  local i = 0
  text = text:gsub("%d+", function(n)
    i = i + 1
    if base and baseNums[i] ~= n then return W.colorize(n, C.green) end
    return W.colorize(n, C.numberInk)
  end)
  return text
end

function W.cardPills(d)
  local list = {}
  if d.cast then list[#list + 1] = "Incantation" end
  if d.cooldown then list[#list + 1] = "Recharge " .. d.cooldown end
  if d.exhaust then list[#list + 1] = "Consumée" end
  if d.retain then list[#list + 1] = "Conservée" end
  return list
end

-- La carte est un bouton immobile (zone de survol et de clic) ; tout son visuel est dans b.face,
-- que le survol anime (W.hoverable). Réglages par écran : b.hoverScale, b.hoverLift (unités de la
-- carte, vers le haut) ; b.baseLevel / b.upLevel : niveau au repos et au survol (passage devant).
function W.card(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(W.CARD_W, W.CARD_H)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)

  b.halo = W.roundRect(face, "BACKGROUND", -8, 12, -4):SetColor(C.gold)
  b.halo:Hide()
  b.edge = W.roundRect(face, "BACKGROUND", -7, 9, 0):SetColor(C.edgeCommon)
  b.fill = W.roundRect(face, "BACKGROUND", -6, 6, 3):SetColor(C.parchment)
  b.grain = face:CreateTexture(nil, "BACKGROUND", nil, -5)
  b.grain:SetTexture(Art.tex.parchment)
  b.grain:SetPoint("TOPLEFT", 6, -6)
  b.grain:SetPoint("BOTTOMRIGHT", -6, 6)
  b.grain:SetAlpha(0.22)

  b.name = W.label(face, "title", 13, C.ink)
  b.name:SetPoint("TOP", 0, -9)
  b.name:SetWidth(W.CARD_W - 18)
  b.name:SetJustifyH("CENTER")
  b.name:SetWordWrap(true)
  b.name:SetMaxLines(2)

  b.medal = W.medallion(face, 58)
  b.medal:SetPoint("TOP", 0, -26)

  b.kind = W.label(face, "body", 10, C.wood)
  b.kind:SetPoint("TOP", b.medal, "BOTTOM", 0, -3)

  b.body = W.label(face, "body", 12, C.ink)
  b.body:SetPoint("TOP", b.kind, "BOTTOM", 0, -3)
  b.body:SetWidth(W.CARD_W - 16)
  b.body:SetJustifyH("CENTER")
  b.body:SetJustifyV("TOP")
  b.body:SetWordWrap(true)

  b.pills = {}
  for i = 1, 2 do
    local p = W.pill(face, 10)
    p:Hide()
    b.pills[i] = p
  end

  -- Gemme de coût (déborde en haut à gauche).
  local gem = CreateFrame("Frame", nil, face)
  gem:SetSize(30, 30)
  gem:SetPoint("CENTER", face, "TOPLEFT", 6, -6)
  gem.edge = W.disc(gem, "ARTWORK", 0, C.gemEdge)
  gem.edge:SetAllPoints()
  gem.fill = W.disc(gem, "ARTWORK", 1, C.gem)
  gem.fill:SetPoint("TOPLEFT", 2, -2)
  gem.fill:SetPoint("BOTTOMRIGHT", -2, 2)
  gem.text = W.label(gem, "title", 17, C.white, "OVERLAY", true)
  gem.text:SetPoint("CENTER", 0, 0)
  b.gem = gem

  -- Étiquette de prix (marchand).
  local tag = CreateFrame("Frame", nil, face)
  tag:SetSize(70, 22)
  tag:SetPoint("TOP", face, "BOTTOM", 0, 6)
  tag.shape = W.shape(tag, 7, C.goldDeep, C.band, 2, -4)
  tag.text = W.label(tag, "title", 14, C.gold)
  tag.text:SetPoint("CENTER", 0, 0)
  tag:Hide()
  b.tag = tag

  -- opts : cost, playable, reason, manaShort, price, sold, preview, showUp
  b.SetCard = function(self, id, up, opts)
    opts = opts or {}
    self.cardId, self.cardUp, self.opts = id, up, opts
    local showUp = up or opts.showUp
    local d = Card.defById(id, showUp)
    local base = showUp and ns.Cards[id] or nil
    local path = Art.paths[d.path] or Art.paths.start
    self.edge:SetColor(Art.rarity[d.rarity] or C.edgeCommon)
    local dim = opts.playable == false
    self.fill:SetColor(dim and C.parchmentDim or (self.hot and C.parchmentLight or C.parchment))
    -- nom (sur deux lignes s'il est long : le médaillon descend et rétrécit)
    self.name:SetText(d.name)
    local nameLen = W.utf8len(d.name)
    local twoLines = nameLen > 15
    W.setSize(self.name, nameLen > 13 and 12 or 13)
    local nc = showUp and C.green or C.ink
    self.name:SetTextColor(nc[1], nc[2], nc[3])
    -- médaillon
    local text = W.cardBody(d, base)
    local long = W.utf8len(text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    local ms = long > 80 and 42 or (long > 52 and 50 or 58)
    if twoLines then ms = ms - 8 end
    self.medal:Resize(ms, 3)
    self.medal:ClearAllPoints()
    self.medal:SetPoint("TOP", 0, twoLines and -38 or -26)
    self.medal:SetRing(path.ring)
    W.setIcon(self.medal.icon, W.cardArt(id), "card:" .. id)
    self.medal.icon:SetDesaturated(dim)
    -- type
    self.kind:SetText((Art.typeName[d.type] or "Sort") .. " · " .. path.name)
    self.kind:SetTextColor(path.ink[1], path.ink[2], path.ink[3])
    -- texte
    W.setSize(self.body, long > 80 and 10 or (long > 52 and 11 or 12))
    self.body:SetText(text)
    -- pastilles (raison d'injouabilité en rouge à la place)
    local pills = W.cardPills(d)
    local list = {}
    if dim and opts.reason then
      list[1] = { opts.reason, C.redEdge, C.white, C.red }
    else
      for i = 1, min(2, #pills) do list[i] = { pills[i], C.ink, C.cream, C.ink } end
    end
    local total = 0
    for i = 1, 2 do
      local p, it = self.pills[i], list[i]
      if it then
        total = total + p:Set(it[1], it[2], it[3], it[4]) + 4
        p:Show()
      else
        p:Hide()
      end
    end
    if total - 4 <= W.CARD_W - 12 then
      local x = (W.CARD_W - (total - 4)) / 2
      for i = 1, 2 do
        local p = self.pills[i]
        if p:IsShown() then
          p:ClearAllPoints()
          p:SetPoint("BOTTOMLEFT", self.face, "BOTTOMLEFT", x, 8)
          x = x + p:GetWidth() + 4
        end
      end
    else -- trop larges : l'une au-dessus de l'autre
      for i = 1, 2 do
        local p = self.pills[i]
        p:ClearAllPoints()
        p:SetPoint("BOTTOM", self.face, "BOTTOM", 0, 8 + (2 - i) * 18)
      end
    end
    -- texte masqué sur une carte injouable (raison écrite), revient au survol
    if dim and opts.reason and not self.hot then self.body:Hide() else self.body:Show() end
    -- coût
    local cost = opts.cost or d.cost
    self.gem.text:SetText(tostring(cost))
    local bad = opts.manaShort
    self.gem.edge:SetVertexColor(W.rgb(bad and C.gemBadEdge or C.gemEdge))
    self.gem.fill:SetVertexColor(W.rgb(bad and C.gemBad or C.gem))
    if d.cost == nil or d.unplayable then self.gem:Hide() else self.gem:Show() end
    -- prix
    if opts.sold then
      self.tag.text:SetText("Vendu")
      self.tag.text:SetTextColor(0.6, 0.6, 0.6)
      self.tag:Show()
    elseif opts.price then
      self.tag.text:SetText(opts.price .. " po")
      local pc = opts.tooPoor and C.hpText or C.gold
      self.tag.text:SetTextColor(pc[1], pc[2], pc[3])
      self.tag:Show()
    else
      self.tag:Hide()
    end
    self:SetAlpha(opts.sold and 0.45 or 1)
  end

  -- Survol / sélection : halo doré, parchemin plus clair (la position est gérée par l'écran).
  b.SetHot = function(self, on)
    if self.hot == on and self.cardId == self._hotId then return end
    self.hot, self._hotId = on, self.cardId
    if on then
      self.halo:Show()
      self.halo:SetAlpha(0.35 + 0.65 * W.animValue(self, "hover"))
    else
      self.halo:Hide()
    end
    if self.cardId then self:SetCard(self.cardId, self.cardUp, self.opts) end
  end
  b.SetSelected = function(self, on) self:SetHot(on or self.hover) end

  -- Survol animé : levée, agrandissement, halo qui s'allume ; passage au premier plan.
  W.hoverable(b, { scale = 1.12, lift = 10, paint = function(self, h)
    if self.hot then self.halo:SetAlpha(0.35 + 0.65 * h) end
  end })
  b.onAnimSettled = function(self)
    if self.baseLevel and W.animValue(self, "hover") == 0 then W.setLevel(self, self.baseLevel) end
  end
  b.onEnterExtra = function(self)
    if self._hoverManual then return end
    self.hover = true
    W.cardFront(self, true)
    self:SetHot(true)
  end
  b.onLeaveExtra = function(self)
    if self._hoverManual then return end
    self.hover = false
    W.cardFront(self, false)
    self:SetHot(false)
  end

  W.tooltip(b, function(tt, self)
    if self.cardId then W.fillCardTooltip(tt, self.cardId, self.cardUp, self.opts) end
  end, "ANCHOR_RIGHT")
  return b
end

-- Niveau d'un cadre survolable et de son visuel : le client relève d'ordinaire les enfants avec
-- leur parent, on le fait aussi explicitement pour le visuel (il doit passer devant les voisines).
local function relevel(frame, level)
  frame:SetFrameLevel(level)
  if frame.GetChildren then
    local kids = { frame:GetChildren() }
    for i = 1, #kids do relevel(kids[i], level + 1) end
  end
end

function W.setLevel(f, level)
  f:SetFrameLevel(level)
  if f.face then relevel(f.face, level + 1) end
end

-- Niveau d'une carte : devant au survol ; en sortie, juste au-dessus des voisines tant qu'elle
-- rétrécit, puis au repos (onAnimSettled).
function W.cardFront(card, up)
  if not card.baseLevel then return end
  if up then W.setLevel(card, card.upLevel or (card.baseLevel + 60))
  elseif W.animValue(card, "hover") > 0 then W.setLevel(card, card.baseLevel + 30)
  else W.setLevel(card, card.baseLevel) end
end

-- Cache une carte et remet son survol au repos (la souris ne la quittera pas : elle disparaît).
function W.hideCard(card)
  card.hover, card.lifted = false, false
  W.hoverReset(card)
  if card.baseLevel then W.setLevel(card, card.baseLevel) end
  card:Hide()
end

-- Pose une carte au repos : centre (x, y) et échelle de base, niveaux ; le survol garde sa valeur.
function W.placeCard(card, container, x, y, scale, baseLevel, upLevel)
  W.placeCenter(card, container, x, y, scale)
  card.baseLevel, card.upLevel = baseLevel, upLevel
  W.cardFront(card, card.hover or card.lifted)
end

-- Carte fantôme (vol de la main vers la cible, de la pioche vers la main…).
local ghosts = {}
function W.ghostCard(container)
  for i = 1, #ghosts do
    local g = ghosts[i]
    if not g.busy and g:GetParent() == container then g.busy = true g:Show() return g end
  end
  local g = W.card(container)
  g:EnableMouse(false)
  g.busy = true
  ghosts[#ghosts + 1] = g
  return g
end

function W.releaseGhost(g)
  g.busy = false
  g:Hide()
end

-- Place un cadre par son centre dans les coordonnées du conteneur (x vers la droite, y vers le bas).
function W.placeCenter(f, container, x, y, scale)
  scale = scale or 1
  f:SetScale(scale)
  f:ClearAllPoints()
  f:SetPoint("CENTER", container, "TOPLEFT", x / scale, -y / scale)
end

-- Fait voler un cadre de (x1, y1) à (x2, y2) avec échelle et alpha, puis onDone.
function W.fly(f, container, x1, y1, x2, y2, s1, s2, a1, a2, dur, onDone, arc)
  f:Show()
  W.tween(dur, function(p)
    local x = x1 + (x2 - x1) * p
    local y = y1 + (y2 - y1) * p - (arc or 0) * 4 * p * (1 - p)
    W.placeCenter(f, container, x, y, s1 + (s2 - s1) * p)
    f:SetAlpha(a1 + (a2 - a1) * p)
  end, onDone, f, "fly", W.ease.inOut)
end

---------------------------------------------------------------------------
-- Textes flottants (chiffres de dégâts, soins, Absorption)
---------------------------------------------------------------------------

local floatPool = {}

-- x, y : centre dans le conteneur ; size : taille de police ; dur : secondes.
function W.float(container, x, y, text, color, size, dur, rise)
  local f
  for i = 1, #floatPool do
    if not floatPool[i].busy and floatPool[i]:GetParent() == container then f = floatPool[i] break end
  end
  if not f then
    f = CreateFrame("Frame", nil, container)
    f:SetSize(200, 40)
    f.fs = W.label(f, "title", 30, C.white, "OVERLAY", true)
    f.fs:SetPoint("CENTER")
    f.fs:SetShadowColor(0.29, 0.06, 0.03, 1)
    f.fs:SetShadowOffset(2, -2)
    floatPool[#floatPool + 1] = f
  end
  f.busy = true
  f:SetFrameLevel(container:GetFrameLevel() + 80)
  W.setSize(f.fs, size or 30)
  f.fs:SetText(text)
  color = color or C.white
  f.fs:SetTextColor(color[1], color[2], color[3])
  rise = rise or 34
  W.tween(dur or 1.1, function(p)
    local pop = p < 0.15 and (1.5 - p / 0.15 * 0.5) or 1
    W.placeCenter(f, container, x, y - rise * p, pop)
    f:SetAlpha(p < 0.6 and 1 or (1 - (p - 0.6) / 0.4))
  end, function()
    f:Hide()
    f.busy = false
  end, f, "float", W.ease.linear)
  f:Show()
  return f
end

---------------------------------------------------------------------------
-- Modèles 3D
---------------------------------------------------------------------------

function W.model(parent, w, h)
  local m = W.create("PlayerModel", nil, parent)
  m:SetSize(w, h)
  return m
end

-- Anime un modèle puis revient à l'attente (ou reste figé pour « dead »).
function W.anim(model, anim, hold)
  if not model or not model.SetAnimation or model.dead then return end
  model:SetAnimation(anim)
  model.animToken = (model.animToken or 0) + 1
  local token = model.animToken
  if hold then
    W.delay(hold * W.pace(), function()
      if model.animToken == token and not model.dead then model:SetAnimation(Art.anim.stand) end
    end)
  end
end

function W.modelAlpha(model, a)
  model:SetAlpha(a)
  if model.SetModelAlpha then model:SetModelAlpha(a) end
end

local function hasModel(model)
  if not model.GetModelFileID then return true end
  local ok, id = pcall(model.GetModelFileID, model)
  return ok and id and id ~= 0
end
W.hasModel = hasModel

-- Affiche une créature : SetCreature, puis SetDisplayInfo, puis repli (icône ou rien).
-- art = { creature, display } ; key = clé du rapport /slay art ; onMissing() appelé sans modèle.
function W.setCreatureArt(model, art, key, onMissing)
  art = art or {}
  model.dead = false
  model.artKey = key
  if model.ClearModel then model:ClearModel() end
  if art.creature then
    model:SetCreature(art.creature)
  elseif art.display then
    model:SetDisplayInfo(art.display)
  end
  local function check(stage)
    if model.artKey ~= key then return end
    if hasModel(model) then return end
    if stage == 1 and art.display and art.creature then
      model:SetDisplayInfo(art.display)
      W.delay(0.6, function() check(2) end)
      return
    end
    W.missing["model:" .. tostring(key)] = true
    if onMissing then onMissing() end
  end
  W.delay(0.6, function() check(1) end)
end

-- Ennemi : modèle ou icône de repli.
function W.setCreature(model, enemyId, fallbackTex)
  if fallbackTex then fallbackTex:Hide() end
  model.enemyId = enemyId
  W.setCreatureArt(model, Art.enemies[enemyId], enemyId, function()
    if fallbackTex then
      W.setIcon(fallbackTex, { icon = Art.enemyIcon })
      fallbackTex:Show()
    end
  end)
end
