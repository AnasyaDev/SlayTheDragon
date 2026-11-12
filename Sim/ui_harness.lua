-- Harnais hors jeu de l'interface. Usage : lua5.1 Sim/ui_harness.lua (ou luajit) -> ALL PASS.
-- Simule assez de l'API WoW (cadres en enregistreurs, C_Timer à horloge virtuelle,
-- événements, GameTooltip, modèles) pour charger TOUS les fichiers du TOC, ouvrir la fenêtre,
-- jouer une expédition par des clics et touches simulés, déclencher décollage/atterrissage
-- et vérifier l'aller-retour de la sauvegarde. Ne remplace pas un essai en jeu.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ADDON = "SlayTheDragon"

---------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------

local function deepcopy(v, seen)
  if type(v) ~= "table" then return v end
  seen = seen or {}
  if seen[v] then return seen[v] end
  local t = {}
  seen[v] = t
  for k, x in pairs(v) do t[deepcopy(k, seen)] = deepcopy(x, seen) end
  return t
end

local function deepeq(a, b, path)
  path = path or "racine"
  if type(a) ~= type(b) then return false, path .. " : type " .. type(a) .. " ~= " .. type(b) end
  if type(a) ~= "table" then
    if a == b then return true end
    return false, path .. " : " .. tostring(a) .. " ~= " .. tostring(b)
  end
  for k, v in pairs(a) do
    local ok, why = deepeq(v, b[k], path .. "." .. tostring(k))
    if not ok then return false, why end
  end
  for k in pairs(b) do
    if a[k] == nil then return false, path .. "." .. tostring(k) .. " en trop" end
  end
  return true
end

-- Une sauvegarde ne doit contenir que des données simples (pas de fonction, pas de cycle,
-- clés chaîne ou nombre) : c'est ce que WoW sait écrire dans SavedVariables.
local function plainData(v, seen, path)
  local t = type(v)
  if t == "function" or t == "userdata" or t == "thread" then return false, path .. " : " .. t end
  if t ~= "table" then return true end
  seen = seen or {}
  if seen[v] then return false, path .. " : table partagée ou cycle" end
  seen[v] = true
  for k, x in pairs(v) do
    if type(k) ~= "string" and type(k) ~= "number" then return false, path .. " : clé " .. type(k) end
    local ok, why = plainData(x, seen, path .. "." .. tostring(k))
    if not ok then return false, why end
  end
  return true
end

local failures, checks = 0, 0
local function check(name, cond, detail)
  checks = checks + 1
  if cond then
    print("  ok   " .. name)
  else
    failures = failures + 1
    print("  FAIL " .. name .. (detail ~= nil and ("  <- " .. tostring(detail)) or ""))
  end
end

---------------------------------------------------------------------------
-- Faux client WoW
---------------------------------------------------------------------------

local H = {}

-- Méthodes reconnues comme API WoW réelle mais sans effet ici. Tout autre nom de méthode
-- inconnu est signalé (faute de frappe probable, ou API absente).
local NOOP = {}
for name in ([[
SetFrameStrata SetToplevel SetClampedToScreen SetMovable EnableMouse RegisterForDrag RegisterForClicks
SetBackdrop SetBackdropColor SetBackdropBorderColor SetColorTexture SetTexCoord SetDesaturated SetJustifyH
SetJustifyV SetWordWrap SetFontObject SetTextColor SetStatusBarTexture SetStatusBarColor
SetAlpha SetNormalTexture SetPushedTexture SetHighlightTexture SetCheckedTexture SetFacing ClearModel
SetMaxLines SetFading SetTimeVisible EnableMouseWheel ScrollUp ScrollDown SetThickness SetStartPoint
SetEndPoint SetVertexColor StartMoving StopMovingOrSizing SetCamDistanceScale SetPortraitZoom
SetDrawLayer SetBlendMode SetShadowColor SetShadowOffset SetRotation SetModelAlpha AddMaskTexture
SetGradient SetMaxLines SetHorizTile SetVertTile SetHitRectInsets SetClipsChildren SetSpacing
SetScaleAnimationMode SetSmoothScaling SetOrigin SetSmoothing SetSnapToPixelGrid SetTexelSnappingBias
]]):gmatch("%S+") do NOOP[name] = true end

local Frame = {}
-- Méthodes propres aux textures (SimpleTextureBaseAPI) : absentes des textes et des cadres, comme dans
-- le jeu (l'interface teste leur existence).
local TEXTURE_ONLY = { SetSnapToPixelGrid = true, SetTexelSnappingBias = true }
local TEXTURE_KINDS = { Texture = true, MaskTexture = true, Line = true }
Frame.__index = function(self, k)
  if TEXTURE_ONLY[k] and not TEXTURE_KINDS[rawget(self, "_kind")] then return nil end
  local m = rawget(Frame, k)
  if m then return m end
  if NOOP[k] then
    return function(obj, ...) H.record(obj, k, ...) end
  end
  -- Champ propre à l'addon (minuscule initiale) : absent = nil, comme dans le jeu.
  if type(k) ~= "string" or not k:match("^%u") then return nil end
  H.unknown[k] = (H.unknown[k] or 0) + 1
  return function() end
end

function H.record(obj, name, ...)
  local calls = rawget(obj, "_calls")
  calls[name] = { ... }
end

-- Régions et cadres créés sous un cadre dont une animation d'échelle joue (le client les dessine
-- alors mal : aplat doré démesuré au premier survol) : relevés pour le harnais (U23).
H.playingGroups = {}
H.bornInAnim = {}
local function underPlayingAnim(o)
  if next(H.playingGroups) == nil then return nil end
  while o do
    for g in pairs(H.playingGroups) do
      if rawget(g, "_parent") == o and rawget(g, "_playing") then return o end
    end
    o = rawget(o, "_parent")
  end
  return nil
end

local function newObject(kind, name, parent)
  if parent and kind ~= "AnimationGroup" and kind ~= "Animation" and underPlayingAnim(parent) then
    local where = debug.traceback("", 2):match("UI/[%w_]+%.lua:%d+") or "?"
    H.bornInAnim[#H.bornInAnim + 1] = kind .. " (" .. where .. ")"
  end
  local o = setmetatable({ _kind = kind, _name = name, _parent = parent, _scripts = {}, _calls = {},
    _shown = true, _points = {},
    _w = 0, _h = 0, _scale = 1, _level = parent and (rawget(parent, "_level") or 1) + 1 or 1,
    _enabled = true, _lines = {}, _kids = {} }, Frame)
  H.objects[#H.objects + 1] = o
  if name then _G[name] = o end
  if parent then local kids = rawget(parent, "_kids") kids[#kids + 1] = o end
  return o
end
H.newObject = newObject

-- Scripts
function Frame:SetScript(k, fn) self._scripts[k] = fn end
function Frame:GetScript(k) return self._scripts[k] end
function Frame:HookScript(k, fn)
  local old = self._scripts[k]
  self._scripts[k] = function(...) if old then old(...) end fn(...) end
end
local function run(self, k, ...)
  local f = self._scripts[k]
  if f then return f(self, ...) end
end
H.run = run

-- Visibilité, comme dans le jeu : OnShow / OnHide aussi pour les cadres enfants qui deviennent
-- visibles ou cachés avec leur parent ; un cadre caché (lui ou un parent) arrête ses animations.
local isFrameKind
local function visibleChain(o)
  while o do
    if not rawget(o, "_shown") then return false end
    o = rawget(o, "_parent")
  end
  return true
end
local function cascade(o, script, top)
  if not top and not rawget(o, "_shown") then return end
  if script == "OnHide" then
    for _, k in ipairs(rawget(o, "_kids")) do
      if rawget(k, "_kind") == "AnimationGroup" and rawget(k, "_playing") then k:Stop() end
    end
  end
  run(o, script)
  for _, k in ipairs(rawget(o, "_kids")) do
    if isFrameKind(k) and rawget(k, "_parent") == o then cascade(k, script) end
  end
end
function Frame:Show()
  if not self._shown then
    self._shown = true
    if visibleChain(self) then cascade(self, "OnShow", true) end
  end
end
function Frame:Hide()
  if self._shown then
    local was = visibleChain(self._parent)
    self._shown = false
    if was then
      self._shown = true
      cascade(self, "OnHide", true)
      self._shown = false
    end
  end
end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self._shown end
function Frame:IsVisible()
  local o = self
  while o do
    if not o._shown then return false end
    o = o._parent
  end
  return true
end

-- Géométrie
local function sizeChanged(self)
  local f = self._scripts.OnSizeChanged
  if f then f(self, self._w, self._h) end
end
function Frame:SetSize(w, h)
  local changed = self._w ~= w or self._h ~= h
  self._w, self._h = w, h
  if changed then sizeChanged(self) end
end
function Frame:SetWidth(w) local c = self._w ~= w self._w = w if c then sizeChanged(self) end end
function Frame:SetHeight(h) local c = self._h ~= h self._h = h if c then sizeChanged(self) end end
function Frame:GetWidth() return self._w end
function Frame:GetHeight() return self._h end
function Frame:GetSize() return self._w, self._h end
function Frame:SetPoint(p, a, b, c, d)
  for _, v in ipairs({ p, a, b, c, d }) do
    if type(v) == "number" and v ~= v then error("SetPoint : NaN") end
  end
  local rel, rp, x, y = a, b, c, d
  if type(a) == "number" then rel, rp, x, y = self._parent, p, a, b end
  if type(a) == "string" then rel, rp, x, y = self._parent, a, b, c end
  self._points[#self._points + 1] = { p, rel, rp or p, x or 0, y or 0 }
end
function Frame:SetAllPoints(rel) self._points = { { "ALL", type(rel) == "table" and rel or nil } } end
function Frame:ClearAllPoints() self._points = {} end
function Frame:GetPoint(i)
  local pt = self._points[i or 1]
  if not pt then return nil end
  return pt[1], pt[2], pt[3], pt[4], pt[5]
end
function Frame:GetNumPoints() return #self._points end
function Frame:GetCenter() return 400, 300 end
function Frame:GetLeft() return 0 end
function Frame:GetBottom() return 0 end
function Frame:SetScale(s) self._scale = s self._nSetScale = (self._nSetScale or 0) + 1 end
function Frame:GetScale() return self._scale end
function Frame:GetEffectiveScale()
  local s, o = 1, self
  while o do s = s * (o._scale or 1) o = o._parent end
  return s
end
function Frame:SetFrameLevel(l) self._level = l end
function Frame:GetFrameLevel() return self._level end
function Frame:GetParent() return self._parent end
function Frame:SetParent(p)
  local old = self._parent
  if old == p then return end
  if old then
    local kids = rawget(old, "_kids")
    for i = #kids, 1, -1 do if kids[i] == self then table.remove(kids, i) end end
  end
  self._parent = p
  if p then local kids = rawget(p, "_kids") kids[#kids + 1] = self end
end
function Frame:GetName() return self._name end
function Frame:GetObjectType() return self._kind end
function Frame:IsMouseOver() return self._mouseOver and true or false end

-- Enfants
function Frame:CreateTexture(_, layer, _, sub)
  local o = newObject("Texture", nil, self)
  o._layer, o._sub = layer, sub
  return o
end
function Frame:CreateFontString(_, layer, font)
  local o = newObject("FontString", nil, self)
  o._font, o._layer = font, layer
  return o
end
function Frame:CreateLine() return newObject("Line", nil, self) end
function Frame:CreateAnimationGroup()
  local g = newObject("AnimationGroup", nil, self)
  g._anims = {}
  return g
end
-- Animations (Scale) : temps virtuel H.now ; lissage OUT = 1 - (1 - p)² ; le délai de fin tient
-- l'état d'arrivée ; Stop rend l'échelle réelle. H.visualScale(cadre) = échelle animée courante.
function Frame:CreateAnimation(kind)
  if kind ~= "Scale" then error("CreateAnimation : type non simulé " .. tostring(kind)) end
  local a = newObject("Animation", nil, self)
  a._from, a._to, a._dur, a._endDelay = { 1, 1 }, { 1, 1 }, 0, 0
  self._anims[#self._anims + 1] = a
  return a
end
function Frame:SetScaleFrom(x, y) self._from = { x, y } end
function Frame:SetScaleTo(x, y) self._to = { x, y } end
function Frame:SetDuration(d) self._dur = d end
function Frame:SetEndDelay(d) self._endDelay = d end
local function animProgress(a)
  local g = a._parent
  if not g._playing then return nil end
  local t = H.now - g._t0
  if t >= a._dur + a._endDelay then g._playing = false return nil end
  local p = a._dur > 0 and math.min(1, t / a._dur) or 1
  return 1 - (1 - p) * (1 - p)
end
function Frame:GetSmoothProgress() return animProgress(self) or 0 end
-- Play sur un cadre caché : sans effet (hypothèse prudente ; l'interface repose l'état à l'OnShow).
function Frame:Play()
  if not visibleChain(self._parent) then self._playing = false return end
  self._playing, self._t0 = true, H.now
  H.playingGroups[self] = true
end
function Frame:Stop() self._playing = false self._nStop = (self._nStop or 0) + 1 H.playingGroups[self] = nil end
function Frame:Pause() self._playing = false H.playingGroups[self] = nil end
function Frame:IsPlaying()
  if not self._playing then return false end
  for _, a in ipairs(self._anims or {}) do animProgress(a) end
  return self._playing
end
function H.visualScale(f)
  local s = 1
  for _, k in ipairs(rawget(f, "_kids")) do
    if rawget(k, "_kind") == "AnimationGroup" and k:IsPlaying() then
      for _, a in ipairs(k._anims) do
        local p = animProgress(a)
        if p then s = s * (a._from[1] + (a._to[1] - a._from[1]) * p) end
      end
    end
  end
  return s
end
function Frame:CreateMaskTexture() return newObject("MaskTexture", nil, self) end

-- Texte
function Frame:SetText(t) self._text = t end
function Frame:GetText() return self._text end
function Frame:SetFormattedText(fmt, ...) self._text = fmt:format(...) end
-- Mesure des textes : avances des glyphes de Baloo Chettan 2 (Sim/baloo_metrics.lua, généré depuis
-- Media/Fonts ; graisse d'après le fichier de police, « bold » pour les polices du jeu), sans crénage ;
-- taille de police = cadratin, hauteur de ligne = ascendante + descendante (1,47 cadratin) ; codes
-- |c…|r ignorés ; retours explicites, puis retour à la ligne par mots si une largeur est posée.
local METRICS = dofile(root .. "/Sim/baloo_metrics.lua")
H.metrics = METRICS
local function plainText(t)
  return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local function fontAdv(self)
  local p = tostring(rawget(self, "_fontPath") or "")
  return METRICS[p:find("heavy") and "heavy" or (p:find("medium") and "medium" or "bold")]
end
-- Icônes en ligne |Tchemin:hauteur:largeur:…|t (comme le client) : largeur = 3e champ, sinon la
-- hauteur ; hauteur 0 = taille du texte. Renvoie le texte sans les séquences et la largeur des icônes.
function H.inlineIcons(text, size)
  local icons = 0
  local list = {}
  text = tostring(text or ""):gsub("|T(.-)|t", function(spec)
    local f = {}
    for v in (spec .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
    local hgt = tonumber(f[2] or "") or 0
    local wid = tonumber(f[3] or "") or hgt
    if hgt == 0 then hgt = size end
    if wid == 0 then wid = hgt end
    icons = icons + wid
    list[#list + 1] = { path = f[1], w = wid, h = hgt, spec = f }
    return ""
  end)
  return text, icons, list
end
-- Largeur d'un texte d'une ligne (sans codes) à la taille size, police de self ; icônes comprises.
function H.textWidth(self, text, size)
  local adv, w = fontAdv(self), 0
  size = size or rawget(self, "_fontSize") or 12
  local plain, icons = H.inlineIcons(text, size)
  for ch in plainText(plain):gmatch("[%z\1-\127\194-\244][\128-\191]*") do w = w + (adv[ch] or 550) end
  return w / 1000 * size + icons
end
-- Taille de police rendue (unités du texte) : sans SetSmoothScaling(true), le client arrondit la
-- hauteur de police effective au pixel entier (ici : taille × échelle effective arrondie), ce qui
-- change largeurs et coupures quand l'échelle réelle change ; avec, elle est proportionnelle.
-- Client défavorable (H.strictText, U33 ; reproduit le « Gain 4 Absorb.... » vu en jeu sur une carte
-- survolée, fenêtre à 115 %) : la police est rendue à la hauteur arrondie au pixel SUPÉRIEUR à l'échelle
-- effective, SetSmoothScaling ou non (glyphes, interligne et largeurs un peu plus grands que mesurés) ;
-- la hauteur automatique d'un texte de plusieurs lignes (aucune hauteur posée) est calculée, elle, à la
-- hauteur arrondie au pixel le plus PROCHE : quand les deux diffèrent, les lignes qui n'y tiennent plus
-- disparaissent et la dernière visible finit par « … » (IsTruncated). La première ligne reste toujours.
H.strictText = false
local function effScale(self)
  local e = self:GetEffectiveScale()
  return (e and e > 0) and e or 1
end
function H.renderSize(self)
  local size = rawget(self, "_fontSize") or 12
  if H.strictText then
    local e = effScale(self)
    return math.max(1, math.ceil(size * e - 1e-9)) / e
  end
  local c = rawget(self, "_calls").SetSmoothScaling
  if c and c[1] == true then return size end
  local e = self:GetEffectiveScale()
  if e <= 0 then return size end
  return math.max(1, math.floor(size * e + 0.5)) / e
end
-- Taille avec laquelle le client défavorable calcule une hauteur automatique (pixel le plus proche).
function H.layoutSize(self)
  local size = rawget(self, "_fontSize") or 12
  local e = effScale(self)
  return math.max(1, math.floor(size * e + 0.5)) / e
end
-- Lignes affichées : { largeurs }, tronqué ?
local function wrapLines(self)
  local text = plainText(rawget(self, "_text"))
  if text == "" then return {}, false end
  local size = H.renderSize(self)
  local w = rawget(self, "_w") or 0
  local wc = rawget(self, "_calls").SetWordWrap
  local wrap = not (wc and wc[1] == false)
  local out, trunc = {}, false
  for para in (text .. "\n"):gmatch("(.-)\n") do
    if w <= 0 then
      out[#out + 1] = H.textWidth(self, para, size)
    elseif not wrap then
      local pw = H.textWidth(self, para, size)
      if pw > w + 0.01 then trunc = true pw = w end
      out[#out + 1] = pw
    else
      local cur
      for word in para:gmatch("%S+") do
        local cand = cur and (cur .. " " .. word) or word
        if cur and H.textWidth(self, cand, size) > w + 0.01 then
          out[#out + 1] = H.textWidth(self, cur, size)
          cur = word
        else
          cur = cand
        end
        if H.textWidth(self, word, size) > w + 0.01 then trunc = true end
      end
      out[#out + 1] = cur and math.min(w, H.textWidth(self, cur, size)) or 0
    end
  end
  local h = rawget(self, "_h") or 0
  local lineH = size * METRICS.lineHeight
  if H.strictText and h <= 0 and #out > 1 then h = #out * H.layoutSize(self) * METRICS.lineHeight end
  if h > 0 and #out * lineH > h + 0.01 then
    trunc = true
    if H.strictText then
      -- lignes qui ne tiennent pas : retirées (la première reste)
      for i = #out, math.max(1, math.floor(h / lineH + 1e-6)) + 1, -1 do out[i] = nil end
    end
  end
  return out, trunc
end
H.wrapLines = wrapLines
function Frame:GetUnboundedStringWidth()
  local m = 0
  for para in (plainText(self._text) .. "\n"):gmatch("(.-)\n") do m = math.max(m, H.textWidth(self, para, H.renderSize(self))) end
  return m
end
function Frame:GetStringWidth()
  local lines = wrapLines(self)
  local m = 0
  for _, lw in ipairs(lines) do m = math.max(m, lw) end
  return m
end
function Frame:GetLineHeight() return H.renderSize(self) * METRICS.lineHeight end
function Frame:GetNumLines() return #(wrapLines(self)) end
function Frame:GetStringHeight() return #(wrapLines(self)) * self:GetLineHeight() end
function Frame:IsTruncated() local _, t = wrapLines(self) return t end
function Frame:GetFont() return self._fontPath or "Fonts\\FRIZQT__.TTF", self._fontSize or 12, "" end
function Frame:SetFont(f, size, flags)
  if type(size) ~= "number" or size <= 0 then error("SetFont : taille invalide") end
  self._fontSize = size
  self._setFontCount = (self._setFontCount or 0) + 1
  self._fontFile = type(f) == "string" and f:upper():find("MORPHEUS") and "title" or "body"
  self._fontPath = f
end

-- Textures
function Frame:SetTexture(t)
  if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then error("SetTexture : argument " .. type(t)) end
  self._texture = t
  if type(t) == "string" and H.badPaths[t] then return false end
  if type(t) == "number" and H.badFiles and H.badFiles[t] then return false end
  return true
end
function Frame:GetTexture() return self._texture end
function Frame:GetTextureFileID()
  local t = self._texture
  if t == nil or (type(t) == "string" and H.badPaths[t]) then return nil end
  if type(t) == "number" and H.badFiles and H.badFiles[t] then return nil end
  return type(t) == "number" and t or 4242
end
function Frame:SetAtlas(a) self._atlas = a return true end
-- Chargement asynchrone : un fichier de H.unloaded ne finit jamais de charger.
function Frame:IsObjectLoaded()
  local t = self._texture
  return not (H.unloaded and t ~= nil and H.unloaded[t])
end

-- Barres
function Frame:SetMinMaxValues(a, b) self._min, self._max = a, b end
function Frame:SetValue(v)
  if type(v) ~= "number" then error("SetValue : nombre attendu") end
  self._value = v
end
function Frame:GetValue() return self._value end

-- Boutons
function Frame:Enable() self._enabled = true end
function Frame:Disable() self._enabled = false end
function Frame:IsEnabled() return self._enabled end
function Frame:SetChecked(v) self._checked = v and true or false end
function Frame:GetChecked() return self._checked end
function Frame:Click(button) run(self, "OnClick", button or "LeftButton", false) end

-- Clavier
function Frame:EnableKeyboard(v) self._keyboard = v end
function Frame:SetPropagateKeyboardInput(v)
  if H.inCombat then error("SetPropagateKeyboardInput en combat") end
  self._propagate = v
end

-- Événements
function Frame:RegisterEvent(e)
  if not H.knownEvents[e] then error("événement inconnu : " .. tostring(e)) end
  H.listeners[e] = H.listeners[e] or {}
  H.listeners[e][#H.listeners[e] + 1] = self
end
function Frame:UnregisterEvent(e)
  local l = H.listeners[e] or {}
  for i = #l, 1, -1 do if l[i] == self then table.remove(l, i) end end
end

-- Modèles
function Frame:SetUnit(u) self._model = "unit:" .. u return true end
function Frame:SetCreature(id)
  if type(id) ~= "number" then error("SetCreature : nombre attendu") end
  self._model = (not H.badCreatures[id]) and ("creature:" .. id) or nil
end
function Frame:SetDisplayInfo(id)
  if type(id) ~= "number" then error("SetDisplayInfo : nombre attendu") end
  self._model = (not (H.badDisplays and H.badDisplays[id])) and ("display:" .. id) or nil
end
function Frame:ClearModel() self._model = nil end
function Frame:GetModelFileID() return self._model and 777 or nil end
function Frame:SetAnimation(a)
  if type(a) ~= "number" then error("SetAnimation : nombre attendu") end
  self._anim = a
  H.anims[#H.anims + 1] = a
end

-- Messages défilants
function Frame:AddMessage(text)
  if type(text) ~= "string" then error("AddMessage : texte attendu") end
  self._lines[#self._lines + 1] = text
end
function Frame:Clear() self._lines = {} end

-- Infobulle
function Frame:SetOwner(o) self._owner = o self._tt = {} end
function Frame:AddLine(t)
  if type(t) ~= "string" then error("AddLine : texte attendu, obtenu " .. type(t)) end
  self._tt = self._tt or {}
  self._tt[#self._tt + 1] = t
end
function Frame:NumLines() return #(self._tt or {}) end

local TEMPLATES = { BackdropTemplate = true, UIPanelButtonTemplate = true, UIPanelCloseButton = true }
local KINDS = { Frame = true, Button = true, CheckButton = true, StatusBar = true, PlayerModel = true,
  ScrollingMessageFrame = true, Slider = true, EditBox = true, ScrollFrame = true }
isFrameKind = function(o) return KINDS[rawget(o, "_kind")] == true end

-- Cadres enfants (pas les textures ni les textes), comme Frame:GetChildren.
function Frame:GetChildren()
  local out = {}
  for _, k in ipairs(self._kids) do
    if KINDS[k._kind] and k._parent == self then out[#out + 1] = k end
  end
  return unpack(out)
end

local EVENTS = {}
for e in ([[ADDON_LOADED PLAYER_LOGIN PLAYER_ENTERING_WORLD PLAYER_LOGOUT PLAYER_REGEN_DISABLED
PLAYER_REGEN_ENABLED PLAYER_CONTROL_LOST PLAYER_CONTROL_GAINED TAXIMAP_CLOSED TAXIMAP_OPENED]]):gmatch("%S+") do
  EVENTS[e] = true
end

local GLOBALS_TO_CLEAR = { "SlayTheDragonFrame", "SlayTheDragonMinimapButton", "SLASH_SLAYTHEDRAGON1",
  "SLASH_SLAYTHEDRAGON2", "SlayTheDragonDB" }

-- Installe un client neuf et charge l'addon. db = contenu de SlayTheDragonDB lu « sur disque ».
function H.boot(db)
  for _, g in ipairs(GLOBALS_TO_CLEAR) do _G[g] = nil end
  H.now = 0
  H.timers = {}
  H.listeners = {}
  H.objects = {}
  H.playingGroups = {}
  H.unknown = H.unknown or {}
  H.anims = {}
  H.chat = {}
  H.taxi = false
  H.inCombat = false
  H.cursor = { 500, 300 }
  H.badPaths = H.badPaths or {}
  H.badCreatures = H.badCreatures or {}
  H.knownEvents = EVENTS

  _G.CreateFrame = function(kind, name, parent, template)
    if not KINDS[kind] then error("CreateFrame : type inconnu " .. tostring(kind)) end
    if template and not TEMPLATES[template] then error("modèle XML inconnu : " .. template) end
    local o = newObject(kind, name, parent)
    o._shown = true
    return o
  end
  _G.UIParent = newObject("Frame", "UIParent")
  _G.Minimap = newObject("Frame", "Minimap", _G.UIParent)
  _G.Minimap._w, _G.Minimap._h = 140, 140
  _G.GameTooltip = newObject("Frame", "GameTooltip", _G.UIParent)
  _G.GameTooltip._shown = false
  _G.DEFAULT_CHAT_FRAME = newObject("ScrollingMessageFrame", "ChatFrame1", _G.UIParent)
  _G.UISpecialFrames = {}
  _G.SlashCmdList = {}
  -- SOUNDKIT : tout nom demandé reçoit un identifiant (les noms sont vérifiés dans UI/Art.lua).
  H.sounds = {}
  _G.SOUNDKIT = setmetatable({}, { __index = function(_, k) return type(k) == "string" and (#k + 1000) or nil end })
  _G.PlaySound = function(id)
    if type(id) ~= "number" then error("PlaySound : identifiant attendu") end
    H.sounds[#H.sounds + 1] = id
  end
  _G.GameFontNormal, _G.GameFontHighlightSmall, _G.GameFontHighlight = {}, {}, {}
  _G.C_Timer = {
    After = function(d, fn)
      if type(fn) ~= "function" then error("C_Timer.After : fonction attendue") end
      H.timers[#H.timers + 1] = { at = H.now + d, fn = fn }
    end,
    NewTicker = function(d, fn)
      local t = { cancelled = false }
      local function tick()
        if t.cancelled then return end
        fn()
        H.timers[#H.timers + 1] = { at = H.now + d, fn = tick }
      end
      H.timers[#H.timers + 1] = { at = H.now + d, fn = tick }
      function t:Cancel() self.cancelled = true end
      return t
    end,
  }
  _G.C_Spell = { GetSpellTexture = function(id)
    if H.badSpells and H.badSpells[id] then return nil end
    return 100000 + id
  end }
  _G.C_Texture = { GetFilenameFromFileDataID = function(id)
    if type(id) ~= "number" then error("GetFilenameFromFileDataID : nombre attendu") end
    if H.badFiles and H.badFiles[id] then return nil end
    return "interface/test/fichier_" .. id
  end }
  _G.GetTime = function() return H.now end
  _G.Enum = { FontStringScaleAnimationMode = { FontSize = 0, Vertex = 1 } }
  _G.time = function() return 1762000000 + math.floor(H.now) end
  _G.UnitOnTaxi = function(u) assert(u == "player") return H.taxi end
  _G.InCombatLockdown = function() return H.inCombat end
  _G.UnitName = function() return "Testeur" end
  _G.GetCursorPosition = function() return H.cursor[1], H.cursor[2] end
  -- boutons de souris enfoncés (H.mouseDown.LeftButton) : glisser des curseurs (U32)
  H.mouseDown = {}
  _G.IsMouseButtonDown = function(b) return H.mouseDown[b or "LeftButton"] and true or false end
  _G.IsShiftKeyDown = function() return false end
  _G.date = function(fmt) return os.date(fmt, 1762000000 + math.floor(H.now)) end
  _G.SlayTheDragonDB = db and deepcopy(db) or nil

  local ns = {}
  local toc = assert(io.open(root .. "/" .. ADDON .. ".toc", "r"))
  for line in toc:lines() do
    line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and not line:match("^#") and line:match("%.lua$") then
      local chunk = assert(loadfile(root .. "/" .. line:gsub("\\", "/")))
      chunk(ADDON, ns)
    end
  end
  toc:close()
  H.ns = ns
  ns.Bots = dofile(root .. "/Sim/bots.lua")(ns)
  ns.Run = dofile(root .. "/Sim/run.lua")(ns)
  H.setup(ns)
  H.fire("ADDON_LOADED", "OtherAddon", false)
  H.fire("ADDON_LOADED", ADDON, false)
  H.fire("PLAYER_LOGIN")
  H.fire("PLAYER_ENTERING_WORLD", true, false)
  H.advance(3)
  return ns
end

function H.fire(event, ...)
  local l = H.listeners[event] or {}
  for i = 1, #l do run(l[i], "OnEvent", event, ...) end
end

function H.advance(seconds)
  local target = H.now + seconds
  while true do
    local best, idx = nil, nil
    for i, t in ipairs(H.timers) do
      if t.at <= target and (not best or t.at < best.at) then best, idx = t, i end
    end
    if not best then break end
    table.remove(H.timers, idx)
    H.now = math.max(H.now, best.at)
    best.fn()
  end
  H.now = target
end

-- Laisse la file d'animations du combat se vider (au plus 60 s virtuelles).
function H.settle()
  local v = H.ns.UI.screens.combat
  for _ = 1, 120 do
    if not v.playing then break end
    H.advance(0.5)
  end
  H.advance(1)
end

function H.slash(msg)
  local f = _G.SlashCmdList.SLAYTHEDRAGON
  assert(f, "/slay non enregistré")
  assert(_G.SLASH_SLAYTHEDRAGON1 == "/slay", "SLASH_SLAYTHEDRAGON1")
  f(msg or "")
end

function H.key(key)
  local f = _G.SlayTheDragonFrame
  run(f, "OnKeyDown", key)
  return f._propagate
end

function H.click(obj, button)
  assert(obj, "clic sur un objet nil")
  assert(obj._shown, "clic sur un objet caché")
  run(obj, "OnClick", button or "LeftButton", false)
end

function H.hover(obj)
  run(obj, "OnEnter")
  local lines = _G.GameTooltip._tt or {}
  run(obj, "OnLeave")
  return lines
end


---------------------------------------------------------------------------
-- Contenu de test : bibelots et potions (registres vides tant que la piste A n'a pas fusionné)
---------------------------------------------------------------------------

function H.setup(ns)
  local R, P = ns.Relics, ns.Potions
  R.ui_test_charm = { name = "Test Charm", text = "Harness relic (no effect).", rarity = "common", tier = 0 }
  R.ui_test_idol = { name = "Test Idol", text = "Harness relic (no effect).", rarity = "uncommon", tier = 0 }
  R.ui_test_lens = { name = "Test Lens", text = "Harness relic (no effect).", rarity = "rare", tier = 0 }
  R.ui_test_trophy = { name = "Test Trophy", text = "Harness boss relic.", rarity = "boss", tier = 0 }
  R.ui_test_symbol = { name = "Test Symbol", text = "Harness class relic.", rarity = "rare", tier = 0,
    class = "priest" }
  P.ui_test_heal = { name = "Test Healing Potion", text = "Heal 10 HP.", rarity = "common", tier = 0, effects = {} }
  P.ui_test_bomb = { name = "Test Bomb", text = "Deal 10 damage to an enemy.", rarity = "common", tier = 0,
    target = true, effects = {} }
  H.potionStub = false
  if not ns.Combat.usePotion then
    -- Pas encore de potions dans le moteur : doublure minimale pour exercer l'interface.
    H.potionStub = true
    local new = ns.Combat.new
    ns.Combat.new = function(opts)
      local c = new(opts)
      if opts.potions and not c.player.potions then c.player.potions = deepcopy(opts.potions) end
      return c
    end
    ns.Combat.usePotion = function(c, slot, t)
      local pots = c.player.potions
      local id = pots and pots[slot]
      if not id then return false, "potion" end
      if c.result then return false, "over" end
      local e
      if P[id] and P[id].target then
        e = c.enemies[t or 0]
        if not e or e.dead then return false, "target" end
      end
      pots[slot] = false
      if id == "ui_test_heal" then ns.Combat.heal(c, c.player, 10)
      elseif e then ns.Combat.dealDamage(c, c.player, e, 10) end
      return true
    end
  end
end

---------------------------------------------------------------------------
-- Pilotage
---------------------------------------------------------------------------

local function UI() return H.ns.UI end
local function C() return H.ns.Controller end
local function V() return H.ns.UI.screens.combat end
local function EXP() return H.ns.Controller.exp() end

local function shown() return _G.SlayTheDragonFrame and _G.SlayTheDragonFrame._shown end

local function currentKind()
  return UI().step and UI().step.kind
end

local function button(id)
  local s = UI().current
  local b = s.optionButtons and s.optionButtons[id]
  assert(b, "bouton introuvable pour l'option " .. tostring(id) .. " sur l'écran " .. tostring(currentKind()))
  return b
end

local function clickOption(id) H.click(button(id)) end

local function option(id)
  for _, o in ipairs(UI().step.options or {}) do
    if o.id == id then return o end
  end
  return nil
end

local function enemySlot(t)
  for _, s in pairs(V().slotOf) do if s.enemyIndex == t then return s end end
  error("emplacement de la cible introuvable")
end

-- Un coup du bot, exécuté par l'interface : clic carte puis clic cible (ou second clic),
-- en variant clavier et glisser-déposer pour couvrir tous les chemins.
local playStyle = 0
local function playAction(bot)
  local c = C().combat()
  local a = bot:act(c)
  local v = V()
  if a[1] == "potion" then
    H.click(UI().potionSlots[a[2]])
    if a[3] then H.click(enemySlot(a[3])) end
    return "potion"
  end
  if a[1] ~= "play" then
    if playStyle % 2 == 0 then H.click(v.endTurn) else H.key("SPACE") end
    playStyle = playStyle + 1
    return "end"
  end
  local idx, t = a[2], a[3]
  local card = v.cards[idx]
  local style = playStyle % 3
  playStyle = playStyle + 1
  local needs = C().handInfo(idx).needsTarget
  if style == 0 then
    H.click(card)
    if needs then H.click(enemySlot(t)) else H.click(card) end
  elseif style == 1 then
    H.key(idx == 10 and "0" or tostring(idx))
    if needs then
      local guard = 0
      while v:KbTarget() ~= t and guard < 10 do H.key("TAB") guard = guard + 1 end
    end
    H.key(idx == 10 and "0" or tostring(idx))
  else
    run(card, "OnDragStart")
    local slot
    if needs then
      slot = enemySlot(t)
      slot._mouseOver = true
    else
      v.bf._mouseOver = true
    end
    run(card, "OnUpdate", 0.016)
    run(card, "OnDragStop")
    if slot then slot._mouseOver = false end
    v.bf._mouseOver = false
  end
  return "play"
end

local function newBot()
  local exp = EXP()
  local seed = (exp and exp.fight and exp.fight.seed) or 1
  return H.ns.Bots.new("heuristic", H.ns.Rng.stream(seed, "uibot"), { cap = 3000 })
end

-- Joue jusqu'à la fin du combat en cours, ou jusqu'à stopFn(). Renvoie le résultat (ou nil).
local function fightUntil(stopFn, maxActions)
  H.actions = H.actions or 0
  local bot = newBot()
  for _ = 1, maxActions or 400 do
    if C().over() then H.settle() return C().over() end
    if stopFn and stopFn() then return nil end
    local before = C().combat().round
    local kind = playAction(bot)
    H.actions = H.actions + 1
    H.advance(0.5)
    if kind == "play" and C().combat() and C().combat().round ~= before and not C().over() then
      error("le tour a changé sur un coup")
    end
  end
  if C().over() then H.settle() end
  return C().over()
end

local function rating(id)
  if id == "smite" then return 2.5 elseif id == "inner_fire" then return 2 end
  return H.ns.Run.RATING[id] or 3
end

-- Chemin visé : passe par un marchand, une rencontre et un feu de camp, le moins d'élites possible.
local function planPath(exp)
  local best, bestScore
  H.ns.Map.eachPath(exp.map, function(path)
    local has, elites, ids = {}, 0, {}
    for i, n in ipairs(path) do
      has[n.kind] = true
      ids[i] = n.id
      if n.kind == "elite" then elites = elites + 1 end
    end
    local score = (has.merchant and 100 or 0) + (has.event and 50 or 0) + (has.campfire and 50 or 0) - elites * 10
    if not bestScore or score > bestScore then best, bestScore = ids, score end
  end)
  return best
end

-- Une décision hors combat, prise en cliquant sur le bouton correspondant.
local function decide(state)
  local step = UI().step
  local k = step.kind
  local exp = EXP()
  if k == "map" then
    local target
    for _, id in ipairs(state.plan or {}) do
      local o = option("path:" .. id)
      if o and not o.disabled then target = o.id end
    end
    target = target or step.options[1].id
    -- une fois sur deux au clavier (1..3 = étapes accessibles de gauche à droite)
    local idx
    for i, o in ipairs(step.options) do if o.id == target then idx = i end end
    if state.mapStyle and idx then H.key(tostring(idx)) else clickOption(target) end
    state.mapStyle = not state.mapStyle
  elseif k == "reward" then
    if UI().current.opened == false then H.click(UI().current.chest) end
    local best, bestR
    for _, o in ipairs(step.options) do
      if o.card and not o.disabled and (not bestR or rating(o.card.id) > bestR) then best, bestR = o, rating(o.card.id) end
    end
    local tp = option("takePotion")
    if best then clickOption(best.id)
    elseif tp and not tp.disabled then clickOption("takePotion")
    else clickOption("leave") end
  elseif k == "campfire" then
    state.seen.campfire = true
    local up = option("ui:upgrade")
    if exp.hp / exp.maxHp < 0.5 or up.disabled then clickOption("rest") else clickOption("ui:upgrade") end
  elseif k == "deck" then
    local best, bestV
    local upgrading = C().ui.view == "upgrade"
    for _, o in ipairs(step.options) do
      if o.card and not o.disabled then
        local v = upgrading and rating(o.card.id) or -rating(o.card.id)
        if not bestV or v > bestV then best, bestV = o, v end
      end
    end
    if best then clickOption(best.id) else clickOption("ui:back") end
    state.removed = state.removed or not upgrading
  elseif k == "merchant" then
    state.seen.merchant = true
    local pick
    for _, o in ipairs(step.options) do
      if not pick and o.item and o.item.kind == "relic" and not o.disabled then pick = o.id end
    end
    local rm = option("ui:remove")
    if not pick and not state.removed and not rm.disabled and #exp.deck > 8 then pick = "ui:remove" end
    if not pick then
      for _, o in ipairs(step.options) do
        if not pick and o.card and not o.disabled and rating(o.card.id) >= 6 then pick = o.id end
      end
    end
    if not pick then
      for _, o in ipairs(step.options) do
        if not pick and o.item and o.item.kind == "potion" and not o.disabled then pick = o.id end
      end
    end
    clickOption(pick or "leave")
  elseif k == "event" then
    state.seen.event = true
    local pick
    for _, o in ipairs(step.options) do
      local fight = (o.text or ""):find("[Ff]ight")
      if not pick and not o.disabled and (not fight or exp.hp / exp.maxHp > 0.6) then pick = o.id end
    end
    clickOption(pick or step.options[#step.options].id)
  elseif k == "select" then
    local first
    for _, o in ipairs(step.options) do if o.card and not first then first = o.id end end
    clickOption(first or "skipSelect")
  elseif k == "startRelic" then
    clickOption(step.options[1].id)
  else
    error("écran inattendu : " .. tostring(k))
  end
end

-- Aller-retour de sauvegarde : copie « disque », nouveau client, reprise identique.
local function reloadRoundTrip(label)
  local ok, why = plainData(_G.SlayTheDragonDB, nil, "SlayTheDragonDB")
  check(label .. " : la sauvegarde ne contient que des données simples", ok, why)
  local vok, errs = H.ns.Save.validate(_G.SlayTheDragonDB)
  check(label .. " : Save.validate accepte la sauvegarde", vok, errs and table.concat(errs, "; "))
  local snap = C().snapshot()
  local db = deepcopy(_G.SlayTheDragonDB)
  check(label .. " : la sauvegarde EST l'état vivant", deepeq(db.current, snap))
  H.boot(db)
  check(label .. " : reprise identique", deepeq(C().snapshot(), snap), select(2, deepeq(C().snapshot(), snap)))
  H.slash("")
  return snap
end

---------------------------------------------------------------------------
-- Scénario
---------------------------------------------------------------------------

local SEED = tonumber(arg and arg[1]) or 1 -- graine 1 : victoire, donc clé +1 exercée
-- Instantanés SVG facultatifs de chaque écran : lua5.1 Sim/ui_harness.lua 1 build/snap
local SNAP = arg and arg[2]
local Render = SNAP and dofile(root .. "/Sim/ui_render.lua")
if SNAP then
  -- aperçus PNG des textures de Media (tools/build_media.py) à côté des SVG : rsvg-convert ne lit
  -- que les images du dossier du SVG et de ses sous-dossiers
  os.execute("mkdir -p '" .. SNAP .. "/media' && cp -r '" .. root .. "/build/media_png/.' '" .. SNAP .. "/media/' 2>/dev/null")
end
local snapped = {}
local function snap(name, force)
  if not SNAP or (snapped[name] and not force) then return end
  snapped[name] = true
  local content = H.ns.UI.content
  if content then Render.svg(H, _G.SlayTheDragonFrame, SNAP .. "/" .. name .. ".svg", name) end
end

print("U1  chargement de tous les fichiers du TOC et premier lancement")
local ns = H.boot(nil)
check("SlayTheDragonDB créée par Save au format courant", _G.SlayTheDragonDB and _G.SlayTheDragonDB.version == ns.Save.VERSION
  and type(_G.SlayTheDragonDB.meta.classes) == "table")
check("options de l'interface dans la sauvegarde", _G.SlayTheDragonDB.options and _G.SlayTheDragonDB.options.autoOpen == true)
check("aucune expédition au départ", EXP() == nil)
check("fenêtre pas encore créée", _G.SlayTheDragonFrame == nil)
check("bouton de minimap créé", _G.SlayTheDragonMinimapButton ~= nil and _G.SlayTheDragonMinimapButton._shown)
local tt = H.hover(_G.SlayTheDragonMinimapButton)
check("infobulle du bouton de minimap", #tt >= 2, #tt)

print("U2  /slay ouvre la fenêtre sur l'accueil, Échap la ferme")
H.slash("")
check("fenêtre ouverte", shown())
check("clavier capté", _G.SlayTheDragonFrame._keyboard == true)
check("écran d'accueil", currentKind() == "start", currentKind())
check("UISpecialFrames contient la fenêtre", _G.UISpecialFrames[1] == "SlayTheDragonFrame")
local prop = H.key("W")
check("touche non gérée rendue au jeu", prop == true, prop)
prop = H.key("ESCAPE")
check("Échap gérée (non propagée)", prop == false, prop)
check("Échap ferme", not shown())
H.slash("")
check("/slay rouvre", shown())

print("U3  options : échelle, vitesse, cases à cocher")
H.slash("options")
check("panneau d'options ouvert", UI().optionsFrame._shown)
H.click(UI().scalePlus)
check("échelle +5 %", math.abs(_G.SlayTheDragonFrame._scale - 1.20) < 1e-9, _G.SlayTheDragonFrame._scale)
H.click(UI().scaleMinus)
H.click(UI().speedPlus)
check("vitesse ×1.25 enregistrée dans SlayTheDragonDB.options", _G.SlayTheDragonDB.options.speed == 1.25)
H.click(UI().speedMinus)
local autoOpen = UI().optionChecks[1]
autoOpen:SetChecked(false) H.click(autoOpen)
check("décocher « ouvrir au décollage » enregistre l'option", ns.Persist.options().autoOpen == false)
autoOpen:SetChecked(true) H.click(autoOpen)
check("recocher", ns.Persist.options().autoOpen == true)
H.key("ESCAPE")
check("Échap ferme d'abord les options", not UI().optionsFrame._shown and shown())

print("U4  accueil : classe, clé verrouillée, départ")
local st = UI().step
check("bouton de classe Prêtre sélectionné", option("class:priest") and option("class:priest").selected)
check("clé +0 sélectionnée par défaut", option("key:0").selected and st.key == 0)
check("clé +1 verrouillée, avec raison", option("key:1").disabled and (option("key:1").reason or ""):find("+0", 1, true))
H.click(button("key:1"))
check("clic sur une clé verrouillée : message", UI().err._shown and (UI().err._text or ""):find("victory", 1, true), UI().err._text)
tt = H.hover(button("key:2"))
check("infobulle d'une clé : affixes", table.concat(tt, " "):find("Tyrannical", 1, true), table.concat(tt, " | "))
check("potions et bibelots masqués sans expédition", not UI().potionSlots[1]._shown)
ns.Controller.makeSeed = function() return SEED end
snap("accueil")
clickOption("go")
local exp = EXP()
check("expédition démarrée par Save.start", exp ~= nil and exp.seed == SEED and exp.key == 0 and exp.class == "priest")
check("db.current est l'expédition", _G.SlayTheDragonDB.current == exp)

print("U5  carte de parcours ramifiée")
snap("parcours")
check("écran carte", currentKind() == "map", currentKind())
st = UI().step
check("tous les nœuds de l'acte affichés", #st.nodes == #exp.map.nodes, #st.nodes)
local avail = 0
for _, n in ipairs(st.nodes) do if n.state == "available" then avail = avail + 1 end end
check("nœuds accessibles = Map.nextNodes", avail == #ns.Map.nextNodes(exp.map, nil) and #st.options == avail)
local boss
for _, n in ipairs(st.nodes) do if n.kind == "boss" then boss = n end end
check("boss à droite, icône de boss", boss and boss.x > 0.9 and button(boss.id).icon._texture ~= ns.Art.QUESTION)
H.click(button(boss.id))
check("nœud inaccessible : refus", EXP().node == nil and UI().err._text == "Stage out of reach.", UI().err._text)
check("liens tracés", (UI().current.linkCount or 0) >= #exp.map.nodes - 1, UI().current.linkCount)
check("trois emplacements de potion vides dans le bandeau", UI().potionSlots[3]._shown
  and not UI().potionSlots[1].icon._shown)
check("pas de clé mythique affichée à +0", not UI().keystone._shown)

print("U6  expédition complète par l'interface (clics, touches, glisser-déposer)")
local state = { plan = planPath(exp), seen = {} }
local nCombats, combatReloaded, rewardReloaded = 0, false, false
local guard = 0
local finished = false
H.actions = 0
while guard < 400 do
  guard = guard + 1
  local k = currentKind()
  if k == "combat" then
    if C().over() then
      if guard % 2 == 0 then H.click(V().banner.button) else H.key("SPACE") end
    else
      nCombats = nCombats + 1
      check("combat " .. nCombats .. " : main affichée", V().cards[1]._shown)
      if not combatReloaded then
        check("modèle du joueur", V().playerModel._model == "unit:player")
        local firstSlot = select(2, next(V().slotOf))
        check("intention affichée", firstSlot.intent._shown and (firstSlot.intent.text._text or "") ~= "")
        tt = H.hover(firstSlot.intent)
        check("infobulle d'intention", #tt >= 2, #tt)
        -- Infobulle de carte : seulement les mots-clés (la carte se lit d'elle-même).
        local kwCard
        for i = 1, #C().combat().hand do
          local d = H.ns.Card.def(C().combat().hand[i])
          if #H.ns.Widgets.cardKeywords(d) > 0 and not kwCard then kwCard = V().cards[i] end
        end
        if kwCard then
          tt = H.hover(kwCard)
          local nk = #H.ns.Widgets.cardKeywords(H.ns.Card.defById(kwCard.cardId, kwCard.cardUp))
          local kl = 0
          for _, l in ipairs(tt) do if l:find(": ", 1, true) then kl = kl + 1 end end
          check("infobulle de carte : une ligne « Nom : effet » par mot-clé", #tt == nk and kl == nk, #tt .. " / " .. nk)
        end
        check("carte : nom, médaillon et texte dessinés", (V().cards[1].name._text or "") ~= ""
          and V().cards[1].medal.icon._texture ~= nil and (V().cards[1].body._text or "") ~= "")
        tt = H.hover(UI().info)
        check("infobulle du deck dans le bandeau", #tt >= 2 and tt[1]:find("Deck", 1, true), tt[1])
        -- Carte injouable : raison, rien ne bouge.
        local c = C().combat()
        local saveMana = c.player.mana
        c.player.mana = 0
        V():Render()
        local handBefore = #c.hand
        H.click(V().cards[1])
        check("carte injouable : « Not enough mana. »", UI().err._text == "Not enough mana.", UI().err._text)
        check("carte non jouée", #c.hand == handBefore)
        c.player.mana = saveMana
        V():Render()
        H.advance(3)
        snap("combat")
        fightUntil(function() return C().combat().round >= 2 and #C().combat().hand > 0 end, 100)
        if SNAP and not C().over() then
          local v = V()
          v.cards[2].hover = true
          v:PlaceCard(v.cards[2])
          v:Spread()
          H.advance(6)
          snap("combat-survol")
          v.cards[2].hover = false
          v:PlaceCard(v.cards[2])
          v:Spread()
          -- options par-dessus le combat (aperçu seulement)
          H.slash("options")
          H.advance(0.2)
          snap("options")
          H.key("ESCAPE")
        end
        if not C().over() then
          combatReloaded = true
          check("journal d'animations vidé dans la sauvegarde", #_G.SlayTheDragonDB.current.combat.events == 0)
          local snap = reloadRoundTrip("combat en cours")
          check("reprise sur l'écran de combat", currentKind() == "combat", currentKind())
          local hand = #C().combat().hand
          check("même main à l'écran", V().cards[hand]._shown and not (V().cards[hand + 1] and V().cards[hand + 1]._shown))
          local a = H.ns.Combat.clone(C().combat())
          local b2 = H.ns.Combat.clone(snap.combat)
          H.ns.Combat.endTurn(a) H.ns.Combat.endTurn(b2)
          check("le tirage suivant est identique après reprise", deepeq(a.hand, b2.hand) and a.round == b2.round)
        end
      end
      local r = fightUntil(nil, 600)
      check("combat " .. nCombats .. " terminé", r ~= nil, r)
      check("bandeau de fin affiché", V().banner._shown)
      check("Fin du tour désactivé", V().endTurn._enabled == false)
    end
  elseif k == "reward" and not rewardReloaded then
    rewardReloaded = true
    snap("recompense")
    local r = EXP().reward
    check("récompense : or affiché dans le butin", UI().current.loot._shown and #UI().step.loot >= 1)
    check("récompense : trois cartes", #UI().current.cardOptions == #r.cards and #r.cards == 3, #r.cards)
    local cards = deepcopy(r.cards)
    reloadRoundTrip("écran de récompense")
    check("reprise sur la récompense, mêmes cartes", currentKind() == "reward" and deepeq(EXP().reward.cards, cards))
    local deckN = #EXP().deck
    H.key("1")
    check("touche 1 prend la première carte", #EXP().deck == deckN + 1 and EXP().reward.cardsDone, #EXP().deck)
    check("texte « Card added »", (UI().step.text or ""):find("Card added", 1, true), UI().step.text)
  elseif k == "end" then
    finished = true
    break
  else
    -- parcours en cours de route (position, chemin parcouru) : aperçu seulement
    if k == "map" and ((H.ns.Controller.runInfo() or {}).floor or 0) >= 3 then snap("parcours-milieu") end
    decide(state)
  end
  H.advance(1)
end
check("bilan de fin d'expédition atteint", finished, currentKind())
check("sauvegarde rechargée en plein combat", combatReloaded)
check("sauvegarde rechargée sur une récompense", rewardReloaded)
check("marchand traversé", state.seen.merchant)
check("rencontre traversée", state.seen.event)
check("feu de camp traversé", state.seen.campfire)
check("animations jouées", #H.anims > 0, #H.anims)
check("sons joués (PlaySound)", #H.sounds > 0, #H.sounds)
local step = UI().step
local won = step.won
do
  local e = _G.SlayTheDragonDB.journal[#_G.SlayTheDragonDB.journal] or {}
  print("      (résultat : " .. (won and "victoire" or "défaite") .. ", étape " .. tostring(e.floor) .. ", "
    .. nCombats .. " combats, " .. H.actions .. " actions" .. (e.killedBy and (", vaincu par " .. e.killedBy) or "") .. ")")
end

print("U7  bilan : Save.finish, réputation, journal, clé suivante")
local db = _G.SlayTheDragonDB
check("expédition archivée (db.current = nil)", db.current == nil)
check("une entrée au journal", #db.journal == 1 and db.journal[1].date ~= nil)
check("réputation gagnée", db.meta.classes.priest.rep > 0 and db.meta.league == db.meta.classes.priest.rep)
check("texte du bilan : réputation", (step.text or ""):find("reputation", 1, true), step.text)
snap("bilan")
check("barres de réputation affichées", UI().current.bars[1]._shown and UI().current.bars[2]._shown)
tt = H.hover(UI().current.bars[1])
check("infobulle d'une barre : palier", #tt >= 2, #tt)
if won then
  check("victoire : clé +1 débloquée", db.meta.classes.priest.keyMax == 1 and (step.text or ""):find("+1", 1, true))
else
  check("défaite : pas de nouvelle clé", db.meta.classes.priest.keyMax == 0)
end
clickOption("ui:meta")
check("écran méta", currentKind() == "meta", currentKind())
snap("meta")
check("méta : barres classe et Ligue", UI().current.bars[1]._shown and UI().current.bars[2]._shown
  and UI().current.bars[2].label._text == "Explorers' League")
check("méta : journal", UI().current.journal[1]._shown and (UI().current.journal[1]._text or ""):find("Priest", 1, true),
  UI().current.journal[1]._text)
check("méta : clés ouvertes", (UI().current.bars[1].detail._text or ""):find("Keys unlocked", 1, true))
clickOption("ui:back")
check("retour au bilan", currentKind() == "end", currentKind())
clickOption("ui:new")
check("accueil", currentKind() == "start", currentKind())
local keyMax = db.meta.classes.priest.keyMax
check("clé par défaut = la plus haute ouverte", UI().step.key == keyMax and option("key:" .. keyMax).selected)
check("dernière expédition rappelée", (UI().step.text or ""):find("Last expedition", 1, true))
ns = H.ns
ns.Controller.makeSeed = function() return SEED + 1 end
H.key("ENTER")
exp = EXP()
check("nouvelle expédition à la clé " .. keyMax, exp and exp.key == keyMax and #exp.affixes == keyMax)
if keyMax > 0 then
  check("clé mythique dans le bandeau (hexagone violet « +N »)", UI().keystone._shown and UI().keystone.count._text == "+" .. keyMax)
  tt = H.hover(UI().keystone)
  check("infobulle de la clé : affixes", table.concat(tt, " "):find("Fortified", 1, true), table.concat(tt, " | "))
  check("affixes dans le texte de la carte", (UI().step.text or ""):find("Fortified", 1, true))
end

print("U8  potions et bibelots : bandeau, défausse, boire en combat")
exp.potions = { "ui_test_heal", "ui_test_bomb", false }
exp.relics[#exp.relics + 1] = "ui_test_charm"
UI().refresh()
check("bibelot dans le bandeau", UI().relicIcons[UI().RELICS_SHOWN]._shown)
tt = H.hover(UI().relicIcons[UI().RELICS_SHOWN])
check("infobulle du bibelot : nom et texte", tt[1] == "Test Charm" and table.concat(tt, " "):find("no effect", 1, true),
  table.concat(tt, " | "))
tt = H.hover(UI().potionSlots[1])
check("infobulle de potion", tt[1] == "Test Healing Potion", tt[1])
H.click(UI().potionSlots[1])
check("hors combat : on ne boit pas", UI().err._text == "Potions are drunk in combat.", UI().err._text)
exp.potions[3] = "ui_test_heal"
H.click(UI().potionSlots[3], "RightButton")
check("premier clic droit : confirmation demandée", exp.potions[3] == "ui_test_heal" and (UI().err._text or ""):find("discard", 1, true))
H.click(UI().potionSlots[3], "RightButton")
check("second clic droit : potion jetée (discardPotion)", exp.potions[3] == false)
-- Entrer dans un combat
local first = exp.map.start[1]
exp.map.nodes[first].kind = "combat"
clickOption("path:" .. first)
check("combat engagé", currentKind() == "combat", currentKind())
local c = C().combat()
local pots = C().potions()
check("potions transmises au combat", pots and pots[1] == "ui_test_heal" and pots[2] == "ui_test_bomb")
c.player.hp = c.player.hp - 20
local hpBefore = c.player.hp
H.click(UI().potionSlots[1])
check("potion bue : emplacement vidé", C().potions()[1] == false)
if H.potionStub then check("effet de la potion (doublure)", c.player.hp == hpBefore + 10, c.player.hp) end
H.click(UI().potionSlots[2])
check("potion à cible : choix de la cible demandé", V().potionSlot == 2 and (UI().err._text or ""):find("target", 1, true))
local t = C().aliveTargets()[1]
local ehp = c.enemies[t].hp
H.click(enemySlot(t))
check("potion lancée sur l'ennemi", C().potions()[2] == false and V().potionSlot == nil)
if H.potionStub then check("dégâts de la bombe (doublure)", c.enemies[t].hp == ehp - 10 or c.enemies[t].dead) end
check("journal d'animations vidé", #c.events == 0)
local r = fightUntil(nil, 600)
check("combat avec potions terminé", r ~= nil)
if r == "won" then
  H.click(V().banner.button)
  local held, gained = 0, (EXP().reward and EXP().reward.potionTaken) and 1 or 0
  for _, p in ipairs(EXP().potions) do if p then held = held + 1 end end
  check("potions bues absentes de l'expédition", held == gained, held)
end

print("U9  marchand complet : cartes, bibelots, potions, retrait au prix croissant")
local function freshRun(seed, kind, meta)
  H.boot(meta and { version = 1, meta = meta } or nil)
  H.slash("")
  H.ns.Controller.makeSeed = function() return seed end
  clickOption("go")
  local e = EXP()
  if kind then
    local id = e.map.start[1]
    e.map.nodes[id].kind = kind
    e.gold = 500
    clickOption("path:" .. id)
  end
  return e
end
exp = freshRun(SEED + 2, "merchant")
ns = H.ns
check("écran marchand", currentKind() == "merchant", currentKind())
snap("marchand")
local s = UI().current
check("cinq cartes à prix (pastille : pièce + nombre)", #s.cardOptions == 5 and s.cards[5]._shown and s.cards[1].tag._shown
  and s.cards[1].tag.text._text == tostring(s.cardOptions[1].price) and s.cards[1].tag.icon._shown)
do
  local poor
  for i, o in ipairs(s.cardOptions) do if o.disabled and not o.sold then poor = i end end
  if poor then
    local tc = s.cards[poor].tag.text._calls.SetTextColor
    check("carte trop chère : prix en rouge", tc and math.abs(tc[1] - H.ns.Art.C.badText[1]) < 1e-9
      and math.abs(tc[2] - H.ns.Art.C.badText[2]) < 1e-9)
  end
end
local relicOpt, potionOpt
for _, o in ipairs(UI().step.options) do
  if o.item and o.item.kind == "relic" and not relicOpt then relicOpt = o end
  if o.item and o.item.kind == "potion" and not potionOpt then potionOpt = o end
end
check("bibelots en vente (registre de test)", relicOpt ~= nil and button(relicOpt.id).icon._shown)
check("potions en vente", potionOpt ~= nil)
tt = H.hover(button(relicOpt.id))
check("infobulle d'un bibelot en vente : prix", table.concat(tt, " "):find(relicOpt.price .. "g", 1, true), table.concat(tt, " | "))
local gold = exp.gold
clickOption(relicOpt.id)
check("bibelot acheté", exp.relics[#exp.relics] == relicOpt.item.id and exp.gold == gold - relicOpt.price)
check("bibelot marqué vendu", option(relicOpt.id).sold and option(relicOpt.id).disabled)
gold = exp.gold
clickOption(potionOpt.id)
check("potion achetée dans un emplacement", exp.potions[1] == potionOpt.item.id and exp.gold == gold - potionOpt.price)
local price1 = option("ui:remove").price
clickOption("ui:remove")
check("écran de retrait (grille du deck)", currentKind() == "deck" and #UI().current.cardOptions == #exp.deck)
local deckN = #exp.deck
H.key("1")
check("carte retirée, retour chez le marchand", #exp.deck == deckN - 1 and currentKind() == "merchant", currentKind())
check("prix du retrait croissant", option("ui:remove").price == price1 + ns.Expedition.REMOVE_STEP, option("ui:remove").price)
clickOption("ui:remove")
clickOption("ui:back")
check("retour sans retirer", currentKind() == "merchant" and #exp.deck == deckN - 1)
exp.gold = 0
UI().refresh()
check("trop pauvre : carte grisée avec raison du moteur", UI().step.options[1].disabled
  and UI().step.options[1].reason == "Not enough gold.", UI().step.options[1].reason)
H.click(UI().current.cards[1])
check("clic sur un article trop cher : message", UI().err._text == "Not enough gold.", UI().err._text)
clickOption("leave")
check("départ : retour à la carte", currentKind() == "map", currentKind())

print("U10 feu de camp : repos chiffré, amélioration avec aperçu")
exp = freshRun(SEED + 3, "campfire")
ns = H.ns
check("écran feu de camp", currentKind() == "campfire", currentKind())
snap("feu-de-camp")
exp.hp = 20
UI().refresh()
local heal = math.floor(exp.maxHp * ns.Expedition.REST_FRACTION)
check("repos : PV rendus calculés par le moteur", option("rest").text == "Restores " .. heal .. " HP.", option("rest").text)
clickOption("ui:upgrade")
check("grille d'amélioration", currentKind() == "deck" and #UI().current.cardOptions >= 1)
snap("amelioration")
tt = H.hover(UI().current.cards[1])
check("aperçu « Upgraded »", table.concat(tt, " "):find("Upgraded:", 1, true), table.concat(tt, " | "))
local cardId = UI().current.cardOptions[1].id
H.click(UI().current.cards[1])
local idx = tonumber(cardId:match("%d+"))
check("carte améliorée, retour à la carte", exp.deck[idx].up == true and currentKind() == "map", currentKind())

print("U11 rencontre : texte, choix, résultat")
exp = freshRun(SEED + 4, "event")
ns = H.ns
check("écran de rencontre", currentKind() == "event", currentKind())
snap("rencontre")
local ev = exp.event.id and ns.Events[exp.event.id]
if ev then
  check("texte de la rencontre", UI().step.text == ev.text)
  check("un bouton par choix", #UI().step.options == #ev.choices)
  local pick
  for i, o in ipairs(UI().step.options) do
    if not pick and not o.disabled and not (o.text or ""):find("[Ff]ight") then pick = i end
  end
  H.key(tostring(pick))
  local k = currentKind()
  check("choix appliqué (résultat, sélection ou récompense)", exp.event.chosen == pick
    and (k == "event" or k == "select" or k == "reward"), k)
  if k == "event" then
    check("texte après coup", UI().step.text == (exp.event.result or ev.choices[pick].after), UI().step.text)
    H.key("ENTER")
  elseif k == "select" then
    clickOption("skipSelect")
  else
    clickOption("leave")
  end
  H.advance(1) -- le butin vole vers le bandeau avant le départ
  check("retour à la carte", currentKind() == "map", currentKind())
else
  check("rencontre vide : continuer", option("leave") ~= nil)
end

print("U12 Révéré : bibelot de classe au départ ; abandon")
exp = freshRun(SEED + 5, nil, { league = 0, runs = 3,
  classes = { priest = { rep = 1100, runs = 3, wins = 0, keyMax = 0, bestKey = -1 } } })
check("phase de bibelot de départ", currentKind() == "startRelic", currentKind())
snap("bibelot-de-classe")
check("bibelot de classe proposé avec icône", option("startRelic:1") and button("startRelic:1").icon._shown)
clickOption("startRelic:1")
check("bibelot de départ pris", exp.relics[1] == "ui_test_symbol" and currentKind() == "map")
UI().toggleOptions()
H.click(UI().abandonButton)
check("abandon : confirmation demandée", EXP() ~= nil)
H.click(UI().abandonButton)
check("abandon : bilan", currentKind() == "end" and UI().step.result == "abandoned" and EXP() == nil, currentKind())
check("abandon au journal", _G.SlayTheDragonDB.journal[#_G.SlayTheDragonDB.journal].result == "abandoned")

print("U13 vol : ouverture au décollage, fermeture à l'atterrissage, masquage en combat")
exp = freshRun(SEED, "combat")
H.key("ESCAPE")
check("fermée avant le vol", not shown())
H.taxi = true
H.fire("PLAYER_CONTROL_LOST")
H.advance(0.5)
check("décollage : fenêtre ouverte", shown())
check("sur l'étape en cours", currentKind() == "combat", currentKind())
H.inCombat = true
H.fire("PLAYER_REGEN_DISABLED")
check("combat réel : fenêtre masquée", not shown())
H.slash("")
check("/slay refusé en combat", not shown())
H.inCombat = false
H.fire("PLAYER_REGEN_ENABLED")
check("fin du combat réel en vol : fenêtre rouverte", shown())
H.taxi = false
H.fire("PLAYER_CONTROL_GAINED")
H.advance(0.5)
check("atterrissage : fenêtre fermée", not shown())
H.taxi = true
H.advance(3)
check("décollage repéré par le seul sondage (sans événement)", shown())
H.taxi = false
H.advance(3)
check("atterrissage repéré par le sondage", not shown())
H.ns.Persist.options().autoOpen = false
H.taxi = true
H.fire("PLAYER_CONTROL_LOST")
H.advance(1)
check("option désactivée : pas d'ouverture", not shown())
H.ns.Persist.options().autoOpen = true
H.taxi = false
H.advance(3)
db = deepcopy(_G.SlayTheDragonDB)
H.boot(db)
H.taxi = true
H.fire("PLAYER_ENTERING_WORLD", false, true)
H.advance(0.5)
check("/reload en vol : fenêtre ouverte sur le combat", shown() and currentKind() == "combat")
H.taxi = false
H.advance(3)
H.fire("PLAYER_LOGOUT")
check("déconnexion : journal d'animations vidé", #_G.SlayTheDragonDB.current.combat.events == 0)

print("U14 sauvegardes abîmées, anciennes ou futures")
local devDb = { version = 1, meta = { saves = 4 }, current = { provider = "demo", seed = 1, run = {} },
  journal = { { result = "abandon", floor = 2, seed = 1 } }, options = { scale = 1.2, flatRibbon = true, zoom = 3 } }
H.boot(devDb)
db = _G.SlayTheDragonDB
check("ancienne sauvegarde de l'interface : options gardées", H.ns.Persist.options().scale == 1.2
  and H.ns.Persist.options().autoOpen == true)
check("ancienne option du ruban ignorée, zoom invalide remis au défaut", H.ns.Persist.options().flatRibbon == nil
  and H.ns.Persist.options().zoom == "net")
do
  local o = H.ns.Persist.options()
  o.zoom = "anim" -- valeur sauvegardée par la version précédente
  H.ns.Persist.init()
  check("ancienne valeur de zoom « anim » : nouveau défaut « net », sans erreur",
    H.ns.Persist.options().zoom == "net" and H.ns.Widgets.zoomMode() == "net")
end
check("ancienne expédition en quarantaine, méta réparée", db.current == nil and #db.quarantine == 1
  and type(db.meta.classes) == "table")
H.slash("")
check("accueil malgré un journal ancien", currentKind() == "start" and (UI().step.text or ""):find("Last expedition", 1, true))
H.ns.Controller.makeSeed = function() return 77 end
clickOption("go")
local good = deepcopy(_G.SlayTheDragonDB)
local bad = deepcopy(good)
bad.current.deck[1].id = "carte_disparue"
H.boot(bad)
check("carte inconnue : Save met l'expédition en quarantaine", EXP() == nil and #_G.SlayTheDragonDB.quarantine == 2)
bad = deepcopy(good)
bad.current.relics[1] = "bibelot_disparu"
H.boot(bad)
check("bibelot inconnu : l'interface met l'expédition en quarantaine", EXP() == nil
  and (_G.SlayTheDragonDB.quarantine[2].reason or ""):find("bibelot", 1, true))
H.slash("")
check("message de mise de côté à l'accueil", (UI().step.text or ""):find("set aside", 1, true))
local future = { version = 99, current = { x = 1 }, meta = { odd = true } }
H.boot(future)
check("version future : pas touchée", _G.SlayTheDragonDB.version == 99 and _G.SlayTheDragonDB.current.x == 1
  and _G.SlayTheDragonDB.meta.odd == true)
check("version future : jeu en lecture seule", H.ns.Persist.readOnly and EXP() == nil)
H.slash("")
clickOption("go")
check("version future : la session joue sans écrire", EXP() ~= nil and _G.SlayTheDragonDB.current.x == 1)
H.boot("n'importe quoi")
check("base illisible remplacée", type(_G.SlayTheDragonDB) == "table" and _G.SlayTheDragonDB.version == H.ns.Save.VERSION)

print("U15 art manquant : repli et rapport /slay art")
-- icône améliorée de Media, icône du sort, FileDataID : tout manque -> point d'interrogation
H.badSpells = { [585] = true }
H.badFiles = { [135924] = true }
H.badPaths = { ["Interface\\AddOns\\SlayTheDragon\\Media\\Icons\\spell_holy_holysmite.tga"] = true }
H.badCreatures = { [639] = true, [117] = true }
H.badDisplays = { [175] = true }
freshRun(SEED, "combat")
H.advance(2)
local smite
for i = 1, 10 do
  local card = V().cards[i]
  if card._shown and card.cardId == "smite" then smite = card end
end
check("icône introuvable -> point d'interrogation", smite and smite.medal.icon._texture == H.ns.Art.QUESTION,
  smite and smite.medal.icon._texture)
H.slash("models")
H.advance(2.6)
check("VanCleef : repli SetDisplayInfo", (function()
  for _, m in ipairs(V().preview.models) do
    if m.id == "vancleef" then return m._model == "display:2029" end
  end
end)())
check("gnoll sans modèle : icône de repli", (function()
  for _, m in ipairs(V().preview.models) do
    if m.id == "gnoll" then return m.fallback._shown end
  end
end)())
H.slash("art")
local said = table.concat(_G.DEFAULT_CHAT_FRAME._lines, "\n")
check("/slay art liste l'icône et le modèle manquants", said:find("card:smite", 1, true) and said:find("model:gnoll", 1, true), said)
H.badSpells, H.badPaths, H.badFiles, H.badCreatures, H.badDisplays = nil, {}, nil, {}, nil

print("U17 décors : fonds embarqués par défaut (TGA sur disque), essai manuel en repli, verdicts gardés")
do
  local function chat() return table.concat(_G.DEFAULT_CHAT_FRAME._lines, "\n") end
  local function clearChat() _G.DEFAULT_CHAT_FRAME._lines = {} end
  local function u16(s, i) return s:byte(i) + 256 * s:byte(i + 1) end
  local function pow2(n) return n > 0 and math.floor(math.log(n) / math.log(2) + 0.5) == math.log(n) / math.log(2) end
  local BG = "Interface\\AddOns\\SlayTheDragon\\Media\\Backgrounds\\"
  -- Même quand tous les fichiers du client « répondent » (SetTexture, FileID, chargement), aucun
  -- candidat du client n'est affiché sans validation : sur Forever un fichier absent répond pareil et
  -- s'affiche en aplat vert. Les fonds embarqués, eux, sont des fichiers de l'addon.
  H.badFiles, H.badPaths, H.unloaded = nil, {}, nil
  H.boot(nil)
  H.slash("")
  local Sc = H.ns.Scene
  local Art = H.ns.Art
  local fields = Sc.paints.fields[1]
  local target = Sc.W / Sc.DECOR_H
  check("accueil : décor de la route", Sc.scene == "road" and Sc.decor._shown)
  check("par défaut : fond embarqué d'Elwynn, décor peint dessous, voile du bas", Sc.art._shown
    and Sc.art._texture == Art.backgrounds.elwynn.file and fields._shown and Sc.ground._shown
    and H.ns.Persist.options().decor == true, Sc.art._texture)
  check("plus aucune sonde automatique", Sc.illus == nil and Sc.resolveAll == nil and Sc.probeFrame == nil)

  -- Chaque scène : un fond embarqué, en tête de sa liste, fichier TGA présent et conforme, affiché par
  -- défaut au bon format (bande ≈ 2,72:1 dans la zone de rapport `ratio`), teinte de la scène.
  local ids = {}
  for id in pairs(Art.scenes) do ids[#ids + 1] = id end
  table.sort(ids)
  local used = {}
  for _, id in ipairs(ids) do
    local entry = Art.scenes[id]
    local bg = Sc.embedded(entry)
    local list = entry.art and Sc.candidates(entry.art) or {}
    check("décor " .. id .. " : fond embarqué en tête de sa liste", bg ~= nil and list[1] == bg
      and type(bg.file) == "string" and bg.file:sub(1, #BG) == BG and bg.file:sub(-4) == ".tga"
      and Art.backgrounds[bg.key] == bg and type(bg.ratio) == "number" and type(bg.source) == "number",
      bg and bg.file)
    if bg then
      used[bg.key] = true
      local f = io.open(root .. "/Media/Backgrounds/" .. bg.file:sub(#BG + 1), "rb")
      local hdr = f and f:read(18)
      local size = f and f:seek("end")
      if f then f:close() end
      local w, h = hdr and u16(hdr, 13), hdr and u16(hdr, 15)
      check("décor " .. id .. " : " .. bg.key .. ".tga sur disque, 32 bits non compressé, puissances de deux",
        hdr and #hdr == 18 and hdr:byte(3) == 2 and hdr:byte(17) == 32 and hdr:byte(18) == 8
        and pow2(w) and pow2(h) and size == 18 + w * h * 4, hdr and (w .. "×" .. h) or "absent")
      check("décor " .. id .. " : choisi sans validation", Sc.chosen(entry) == bg)
      Sc.set({ scene = id, board = true })
      local tc = Sc.art._calls.SetTexCoord
      local shownRatio = tc and bg.ratio * (tc[2] - tc[1]) / (tc[4] - tc[3])
      check("décor " .. id .. " : affiché, bande au format du décor", Sc.art._shown and Sc.art._texture == bg.file
        and tc[1] >= 0 and tc[2] <= 1 and tc[3] >= -1e-9 and tc[4] <= 1 + 1e-9
        and math.abs(shownRatio - target) < 1e-6, tc and table.concat(tc, " "))
      local t = entry.tint or { 1, 1, 1 }
      local vc = Sc.art._calls.SetVertexColor
      check("décor " .. id .. " : teinte de la scène", math.abs(vc[1] - t[1]) < 1e-9 and math.abs(vc[3] - t[3]) < 1e-9)
    end
  end
  for key in pairs(Art.backgrounds) do
    check("fond " .. key .. " employé par au moins une scène", used[key])
  end
  local fCamp = { Sc.bandCoords(Art.backgrounds.elwynn, Art.scenes.camp.focus) }
  local fHill = { Sc.bandCoords(Art.backgrounds.elwynn, Art.scenes.hill.focus) }
  check("même image, cadrages différents (colline plus haut que le camp)", fHill[3] < fCamp[3])
  Sc.set({ scene = "road", board = true, veil = 0.2 })

  clearChat()
  H.slash("art")
  local said = chat()
  check("/slay art : liste des fonds embarqués et de leurs scènes", said:find("embedded backgrounds (Media\\Backgrounds): 5", 1, true)
    and said:find("elwynn.tga — " .. Art.backgrounds.elwynn.name .. " (FileDataID 7377860): camp, hill, night, road, shop", 1, true)
    and said:find("deadmines.tga — ", 1, true) and said:find("): mine", 1, true)
    and said:find("coast.tga — ", 1, true), said)
  check("/slay art : chaque décor dit son fond", said:find("road: embedded background elwynn — ", 1, true)
    and said:find("mine: embedded background deadmines — ", 1, true)
    and said:find("coast: embedded background coast — ", 1, true), said)
  check("/slay art : aucun verdict", said:find("accepted: none", 1, true) and said:find("rejected: none", 1, true)
    and said:find("not judged yet: 8 of 8", 1, true), said)

  -- Liste d'essai : les candidats du client seulement, dédoublonnée (les ruines reprennent Elwynn).
  local list = Sc.trialList()
  local keys, dup, emb = {}, false, false
  for _, c in ipairs(list) do
    if keys[tostring(c.file)] then dup = true end
    if c.embedded then emb = true end
    keys[tostring(c.file)] = true
  end
  check("liste d'essai : 8 candidats du client, sans doublon ni fond embarqué", #list == 8 and not dup and not emb, #list)
  check("liste d'essai : écrans classiques et Forever", keys["131839"] and keys["131833"] and keys["7963776"]
    and keys["7963777"] and keys["7963782"] and keys["7377860"])

  clearChat()
  H.slash("scenery test")
  said = chat()
  check("essai : candidat 1 affiché sur le décor courant", Sc.trial == 1 and Sc.art._shown
    and Sc.art._texture == list[1].file, Sc.art._texture)
  check("essai : sans teinte ni voile", Sc.art._calls.SetVertexColor[1] == 1 and Sc.art._calls.SetVertexColor[3] == 1
    and Sc.veil._calls.SetColorTexture[4] == 0 and not Sc.ground._shown)
  check("essai : numéro, fichier, nom et mode d'emploi", said:find("scenery test 1/8: " .. tostring(list[1].file)
    .. " — " .. list[1].name .. " [not judged yet]", 1, true) and said:find("/slay scenery ok", 1, true), said)
  clearChat()
  H.slash("scenery next")
  check("suivant : candidat 2", Sc.trial == 2 and Sc.art._texture == list[2].file
    and chat():find("scenery test 2/8: " .. tostring(list[2].file), 1, true), chat())
  H.slash("scenery prev")
  H.slash("scenery prev")
  check("précédent depuis le 1er : retour au dernier", Sc.trial == 8 and Sc.art._texture == list[8].file)
  H.slash("scenery next")
  check("suivant depuis le dernier : retour au 1er", Sc.trial == 1)

  -- Verdicts : le 1er refusé, puis on valide le 3e candidat du client de la liste d'Elwynn, pour
  -- vérifier qu'un décor sans fond embarqué prend le premier validé de SA liste.
  local function clientOnly(key)
    local out = {}
    for _, c in ipairs(Sc.candidates(key)) do if not c.embedded then out[#out + 1] = c end end
    return out
  end
  local elwynn = clientOnly("elwynn")
  local deadmines = clientOnly("deadmines")
  clearChat()
  H.slash("scenery no")
  check("non : refusé et dit", H.ns.Persist.options().artChecks[tostring(list[1].file)] == false
    and chat():find(tostring(list[1].file) .. " rejected", 1, true), chat())
  local function goTo(file)
    for _ = 1, #list do
      if Sc.trialList()[Sc.trial].file == file then return true end
      H.slash("scenery next")
    end
    return false
  end
  check("aller au 3e candidat d'Elwynn", goTo(elwynn[3].file))
  clearChat()
  H.slash("scenery ok")
  check("ok : validé et dit", H.ns.Persist.options().artChecks[tostring(elwynn[3].file)] == true
    and chat():find(tostring(elwynn[3].file) .. " accepted", 1, true), chat())
  goTo(elwynn[1].file)
  H.slash("scenery no")
  goTo(elwynn[4].file)
  H.slash("scenery ok")
  goTo(deadmines[3].file)
  H.slash("scenery ok")
  check("en essai, le décor montre le candidat essayé", Sc.art._texture == deadmines[3].file)

  clearChat()
  H.slash("scenery painted")
  check("peint : fin de l'essai, décor peint", Sc.trial == nil and not Sc.art._shown and fields._shown
    and not Sc.ground._shown and H.ns.Persist.options().decor == false, chat())
  H.slash("scenery illustrated")
  check("illustre : la route montre son fond embarqué, même avec des candidats validés",
    H.ns.Persist.options().decor == true and Sc.art._shown and Sc.art._texture == Art.backgrounds.elwynn.file
    and Sc.ground._shown)
  check("voile de l'accueil rétabli", math.abs(Sc.veil._calls.SetColorTexture[4] - 0.2) < 1e-9)
  Sc.set({ scene = "mine", board = true })
  check("boss : fond embarqué des Mortemines", Sc.art._shown and Sc.art._texture == Art.backgrounds.deadmines.file)
  Sc.set({ scene = "coast", board = true })
  check("côte : fond embarqué de la côte", Sc.art._shown and Sc.art._texture == Art.backgrounds.coast.file)
  -- Repli : sans fond embarqué dans la liste, le premier candidat validé (recadré, décalé, teinté).
  local saved = Art.illustrations.elwynn
  local stripped = {}
  for _, c in ipairs(saved) do if type(c) ~= "table" or not c.embedded then stripped[#stripped + 1] = c end end
  Art.illustrations.elwynn = stripped
  Sc.set({ scene = "road", board = true })
  check("repli : la route montre le premier validé de sa liste", Sc.art._shown and Sc.art._texture == elwynn[3].file
    and math.abs(Sc.art._calls.SetTexCoord[3] - elwynn[3].crop[3]) < 1e-9
    and math.abs(Sc.art._calls.SetVertexColor[2] - Art.scenes.road.tint[2]) < 1e-9)
  Art.illustrations.elwynn = saved
  Sc.set({ scene = "road", board = true, veil = 0.2 })
  H.slash("scenery")
  check("/slay decor seul : bascule vers peint", H.ns.Persist.options().decor == false and not Sc.art._shown)
  H.slash("scenery")
  check("/slay decor seul : bascule vers illustré", H.ns.Persist.options().decor == true and Sc.art._shown)
  H.slash("scenery test")
  H.slash("scenery test")
  check("essai deux fois : bascule (essai fermé)", Sc.trial == nil and Sc.art._texture == Art.backgrounds.elwynn.file)
  clearChat()
  H.slash("scenery ok")
  check("ok hors essai : rien, message", chat():find("no test in progress", 1, true), chat())

  clearChat()
  H.slash("art")
  said = chat()
  check("/slay art : validés et refusés", said:find("accepted: " .. tostring(deadmines[3].file) .. " (", 1, true)
    and said:find(tostring(elwynn[4].file) .. " (", 1, true)
    and said:find("rejected: " .. tostring(deadmines[1].file) .. " (", 1, true)
    and said:find(tostring(elwynn[1].file) .. " (" .. elwynn[1].name .. ")", 1, true)
    and said:find("not judged yet: 3 of 8", 1, true), said)

  -- Persistance : verdicts relus au rechargement, essai non repris.
  local savedDB = deepcopy(_G.SlayTheDragonDB)
  local okData = plainData(savedDB, nil, "SlayTheDragonDB")
  check("verdicts : données simples dans la sauvegarde", okData)
  H.boot(savedDB)
  H.slash("")
  Sc = H.ns.Scene
  check("rechargement : verdicts gardés", H.ns.Persist.options().artChecks[tostring(elwynn[3].file)] == true
    and H.ns.Persist.options().artChecks[tostring(elwynn[1].file)] == false)
  check("rechargement : la route montre son fond embarqué, pas d'essai", Sc.trial == nil and Sc.art._shown
    and Sc.art._texture == H.ns.Art.backgrounds.elwynn.file)
  -- Écran sans décor (parcours) : l'essai prévient où le voir.
  clickOption("go")
  check("parcours : pas de décor", Sc.scene == false)
  clearChat()
  H.slash("scenery test")
  check("essai sur le parcours : message", chat():find("this screen has no scenery", 1, true)
    and chat():find("scenery test", 1, true), chat())
  check("essai : départ au premier candidat pas encore jugé", Sc.trial and Sc.verdict(list[Sc.trial]) == nil)
  H.slash("scenery painted")
  H.slash("scenery illustrated")
  H.badFiles, H.badPaths, H.unloaded = nil, {}, nil
end

print("U18 survols animés : zone fixe, visuel animé, réversible, pilote qui s'arrête")
do
  freshRun(SEED, "combat")
  H.settle()
  local Wd = H.ns.Widgets
  local driver = Wd.driver
  local v = V()
  local card = v.cards[1]
  local function hit(f)
    local p = f._points[1]
    return p and (tostring(p[1]) .. "|" .. tostring(p[2]) .. "|" .. tostring(p[3]) .. "|" .. tostring(p[4])
      .. "|" .. tostring(p[5]) .. "|" .. tostring(f._scale)) or "?"
  end
  local before = hit(card)
  local face = card.face
  local hs = card.hoverScale
  -- échelle visuelle totale (réelle × animation) et état de l'animation d'échelle
  local function vis(f) return f.face._scale * H.visualScale(f.face) end
  local function animOn(f) local z = f.face._zoom return z ~= nil and z.ag:IsPlaying() end
  -- mise en page des textes de la carte : lignes, coupures, largeurs (unités du visuel), tailles
  local function layout(c)
    local out = {}
    for _, key in ipairs({ "name", "cost", "body", "plateText" }) do
      local fs = c[key]
      out[#out + 1] = key .. "=" .. tostring(fs._text) .. "#" .. fs:GetNumLines() .. "/"
        .. tostring(fs:IsTruncated()) .. "/" .. string.format("%.3f", fs:GetStringWidth())
        .. "/" .. tostring(fs._fontSize) .. "/" .. tostring(fs._setFontCount)
    end
    return table.concat(out, " ; ")
  end
  local rest = layout(card)
  check("pilote à l'arrêt quand rien ne bouge", not Wd.driverAwake() and driver._scripts.OnUpdate == nil)
  run(card, "OnEnter")
  check("survol : le pilote démarre", Wd.driverAwake() and driver._scripts.OnUpdate ~= nil)
  run(driver, "OnUpdate", 0.04)
  local mid = Wd.animValue(card, "hover")
  check("survol en cours : valeur intermédiaire", mid > 0 and mid < 1, mid)
  local zoom = face._zoom
  check("zoom « net » en route : animation Scale vers l'échelle du survol, échelle réelle encore 1",
    zoom and animOn(card) and math.abs(zoom.to - hs) < 1e-9 and zoom.from == 1 and face._scale == 1
    and hit(card) == before, zoom and zoom.to)
  check("textes en mode Vertex et SetSmoothScaling (taille rendue proportionnelle à l'échelle)",
    card.body._calls.SetScaleAnimationMode and card.body._calls.SetScaleAnimationMode[1] == 1
    and card.name._calls.SetScaleAnimationMode and card.cost._calls.SetScaleAnimationMode
    and card.body._calls.SetSmoothScaling and card.body._calls.SetSmoothScaling[1] == true
    and card.name._calls.SetSmoothScaling[1] == true and card.plateText._calls.SetSmoothScaling[1] == true)
  check("mise en page identique pendant le mouvement", layout(card) == rest, layout(card))
  H.now = H.now + 0.05
  local vs = vis(card)
  check("échelle visuelle intermédiaire au cours du survol", vs > 1 and vs < hs, vs)
  run(card, "OnLeave")
  run(driver, "OnUpdate", 0.01)
  local back = Wd.animValue(card, "hover")
  check("sortie en cours de route : repart de la valeur courante", back > 0 and back <= mid, back .. " / " .. mid)
  check("sortie en route : l'animation repart de l'échelle visuelle courante vers 1, échelle réelle 1",
    animOn(card) and math.abs(zoom.from - vs) < 1e-6 and zoom.to == 1 and face._scale == 1, zoom.from .. " / " .. vs)
  for _ = 1, 30 do run(driver, "OnUpdate", 0.02) end
  H.now = H.now + 1
  check("sortie terminée : repos exact, aucune animation d'échelle", Wd.animValue(card, "hover") == 0
    and face._scale == 1 and not animOn(card) and vis(card) == 1)
  check("pilote arrêté une fois tout immobile", not Wd.driverAwake() and driver._scripts.OnUpdate == nil)
  check("mise en page identique après le survol", layout(card) == rest, layout(card))

  -- arrivée image par image : la bascule (échelle réelle posée, animation coupée) se fait dans le pas
  -- où le canal s'arrête, sans saut d'échelle visible
  run(card, "OnEnter")
  local last, jump, steps, switched = 1, 0, 0, nil
  while Wd.animValue(card, "hover") < 1 and steps < 100 do
    run(driver, "OnUpdate", 0.016)
    H.now = H.now + 0.016
    steps = steps + 1
    local s = vis(card)
    if face._scale ~= 1 and not switched then switched = { s = s, prev = last, anim = animOn(card) } end
    jump = math.max(jump, math.abs(s - last))
    last = s
  end
  check("arrivée : échelle réelle du visuel = échelle de survol, aucune animation d'échelle active",
    face._scale == hs and not animOn(card) and H.visualScale(face) == 1 and hit(card) == before, face._scale)
  check("bascule à l'arrivée : même pas, sans saut ni image à la mauvaise taille", switched
    and not switched.anim and math.abs(switched.s - hs) < 1e-9 and math.abs(switched.s - switched.prev) < 0.02
    and jump < 0.05, switched and (switched.prev .. " -> " .. switched.s) or "pas de bascule")
  local lift0 = face._points[1]
  check("arrivée : position du visuel compensée par l'échelle réelle (levée en unités d'écran)",
    lift0 and math.abs(lift0[5] * face._scale - card.hoverLift) < 1e-6, lift0 and lift0[5])
  check("mise en page identique une fois agrandie (même nombre de lignes, mêmes coupures)",
    layout(card) == rest, layout(card))
  -- sortie depuis l'état agrandi : étirement depuis l'échelle réelle, sans saut au départ
  run(card, "OnLeave")
  run(driver, "OnUpdate", 0.016)
  H.now = H.now + 0.016
  check("sortie : échelle réelle gardée, animation vers 1 / échelle (facteur 1 au départ)",
    face._scale == hs and animOn(card) and zoom.from == 1 and math.abs(zoom.to - 1 / hs) < 1e-9
    and vis(card) < hs and vis(card) > hs - 0.05, vis(card))
  check("mise en page identique pendant la sortie", layout(card) == rest, layout(card))
  -- retour en plein mouvement (réversible), puis bascule interrompue au pas même de l'arrivée
  run(card, "OnEnter")
  run(driver, "OnUpdate", 0.016)
  H.now = H.now + 0.016
  check("retour en route : animation relancée depuis le facteur courant, échelle réelle inchangée",
    face._scale == hs and animOn(card) and zoom.to == 1 and zoom.from < 1, zoom.from)
  for _ = 1, 20 do run(driver, "OnUpdate", 0.016) H.now = H.now + 0.016 end
  check("retour terminé : échelle réelle de survol, aucune animation", face._scale == hs and not animOn(card)
    and Wd.animValue(card, "hover") == 1)
  -- sortie au pas même de la bascule d'arrivée
  run(card, "OnLeave")
  run(card, "OnEnter")
  run(driver, "OnUpdate", 0.016)
  H.now = H.now + 0.016
  check("sortie et retour dans le même pas : rien ne bouge", face._scale == hs and not animOn(card)
    and Wd.animValue(card, "hover") == 1)
  run(card, "OnLeave")
  for _ = 1, 30 do run(driver, "OnUpdate", 0.016) H.now = H.now + 0.016 end
  check("sortie terminée : échelle réelle 1, aucune animation d'échelle", face._scale == 1 and not animOn(card)
    and vis(card) == 1 and Wd.animValue(card, "hover") == 0)
  check("mise en page identique après la sortie", layout(card) == rest, layout(card))
  -- témoin : sans SetSmoothScaling, le faux client arrondit la hauteur de police à l'échelle réelle
  do
    local probe = H.ns.Widgets.label(face, "bold", 7.5)
    probe._calls.SetSmoothScaling = nil
    probe:SetText("Deal 6 points of damage.")
    local w1 = probe:GetStringWidth()
    face:SetScale(1.12)
    local w2 = probe:GetStringWidth()
    face:SetScale(1)
    probe:Hide()
    check("témoin : sans hauteur non arrondie, la largeur d'un texte change avec l'échelle réelle", w1 ~= w2,
      w1 .. " / " .. w2)
  end

  -- état final par les seuls minuteurs de secours (images sautées)
  run(card, "OnEnter")
  H.advance(0.5)
  check("survol : état final par les minuteurs, échelle réelle de survol, aucune animation",
    Wd.animValue(card, "hover") == 1 and face._scale == hs and not animOn(card) and hit(card) == before,
    face._scale)
  local n = #C().combat().hand
  if n >= 2 then
    check("voisine écartée (visuel seulement)", Wd.animValue(v.cards[2], "dx") > 0)
  end
  check("carte survolée devant les autres (visuel et médaillon compris)", card._level > v.cards[n]._level
    and card.face._level > v.cards[n].face._level)
  check("zone de survol prolongée vers le haut", card._calls.SetHitRectInsets
    and card._calls.SetHitRectInsets[3] < 0)
  run(card, "OnLeave")
  H.advance(0.5)
  check("retour au repos", Wd.animValue(card, "hover") == 0 and card._level == card.baseLevel
    and Wd.animValue(v.cards[2], "dx") == 0)
  -- bouton, pile, potion, menu : même mécanique
  for _, f in ipairs({ v.endTurn, v.drawPile, UI().potionSlots[1], UI().gear }) do
    local hb = hit(f)
    run(f, "OnEnter")
    H.advance(0.5)
    local up = f.face._scale > 1 and f.face._scale == f.hoverScale and not animOn(f)
    run(f, "OnLeave")
    H.advance(0.5)
    check("survol animé : " .. tostring(f.label and f.label._text or f.pileKey or "icône")
      .. " (échelle réelle à l'arrivée, repos exact ensuite)",
      up and not animOn(f) and f.face._scale == 1 and hit(f) == hb)
  end
  -- /slay zoom : cycle net → fluide → lisse, puis « lisse » (échelle réelle à chaque image) et retour
  H.slash("zoom")
  check("/slay zoom : net → fluide", H.ns.Persist.options().zoom == "fluide" and Wd.zoomMode() == "fluide")
  H.slash("zoom")
  check("/slay zoom : fluide → lisse", H.ns.Persist.options().zoom == "lisse")
  local eb = v.endTurn
  run(eb, "OnEnter")
  run(driver, "OnUpdate", 0.04)
  check("mode lisse : échelle réelle du visuel animée, sans animation Scale", eb.face._scale > 1
    and eb.face._scale < eb.hoverScale and H.visualScale(eb.face) == 1, eb.face._scale)
  run(eb, "OnLeave")
  H.advance(0.5)
  check("mode lisse : repos exact", eb.face._scale == 1)
  H.slash("zoom sharp")
  check("/slay zoom net : retour au défaut", H.ns.Persist.options().zoom == "net")
  H.slash("zoom smooth")
  H.slash("zoom anim")
  check("/slay zoom anim (ancien nom) : mode net", H.ns.Persist.options().zoom == "net")
  -- vol de carte : étirement pendant le vol, carte nette une fois posée
  do
    local g = Wd.ghostCard(v.parent)
    g:SetCard(card.cardId, card.cardUp, card.opts)
    local landed = false
    Wd.fly(g, v.parent, 100, 400, 500, 300, 0.3, 1, 0.6, 1, 0.28, function() landed = true end)
    local gz = g._zoom
    local inFlight = gz and gz.ag:IsPlaying() and g._scale == 0.3 and math.abs(gz.to - 1 / 0.3) < 1e-9
      and gz.from == 1
    H.advance(0.5)
    check("vol de carte : étirement en vol (échelle réelle de départ), à l'arrivée échelle réelle d'arrivée"
      .. " et aucune animation d'échelle", inFlight and landed and g._scale == 1 and not gz.ag:IsPlaying())
    Wd.releaseGhost(g)
  end
  -- ennemi ciblable quand une carte à cible est armée
  local c = C().combat()
  local idx
  for i = 1, #c.hand do
    local info = C().handInfo(i)
    if info and info.playable and info.needsTarget and not idx then idx = i end
  end
  if idx then
    v:Select(idx)
    local t = C().aliveTargets()[1]
    local slot = enemySlot(t)
    local hs = hit(slot)
    run(slot, "OnEnter")
    H.advance(0.5)
    check("ennemi visé : il grandit, sa zone de clic reste", slot.fig._scale > 1 and hit(slot) == hs, slot.fig._scale)
    run(slot, "OnLeave")
    v:Deselect()
    H.advance(0.5)
    check("visée annulée : ennemi au repos", Wd.animValue(slot, "aim") == 0)
  end
end

print("U19 panneau du deck : ouverture, tri, défilement, fermeture ; pioche triée en combat")
do
  local exp = freshRun(SEED + 6, nil)
  local Dv = UI().deckView
  local Card = H.ns.Card
  -- deck assez grand pour défiler, une carte améliorée
  local n0 = #exp.deck
  for i = 1, 20 do
    local src = exp.deck[(i - 1) % n0 + 1]
    exp.deck[#exp.deck + 1] = { uid = 9000 + i, id = src.id, up = false }
  end
  exp.deck[2].up = true
  UI().refresh()
  check("bouton Deck du bandeau affiché", UI().deckButton._shown)
  H.click(UI().deckButton)
  check("clic sur Deck : panneau ouvert", Dv:IsShown() and Dv.kind == "deck")
  snap("deck-panneau")
  check("compteur total dans le titre", (Dv.title._text or ""):find(#exp.deck .. " cards", 1, true), Dv.title._text)
  local TYPE = { attack = 1, skill = 2, power = 3 }
  local sorted = #Dv.list == #exp.deck
  for i = 2, #Dv.list do
    local a, b = Card.defById(Dv.list[i - 1].id, Dv.list[i - 1].up), Card.defById(Dv.list[i].id, Dv.list[i].up)
    local ka = { TYPE[a.type] or 9, a.cost or 99, a.name }
    local kb = { TYPE[b.type] or 9, b.cost or 99, b.name }
    if ka[1] > kb[1] or (ka[1] == kb[1] and (ka[2] > kb[2] or (ka[2] == kb[2] and ka[3] > kb[3]))) then sorted = false end
  end
  check("cartes triées par type, coût puis nom", sorted)
  check("vraies cartes (W.card) dans l'ordre trié", Dv.cards[1]._shown and Dv.cards[1].cardId == Dv.list[1].id
    and Dv.cards[1].name._text ~= nil)
  local upShown
  for _, cd in ipairs(Dv.cards) do if cd._shown and cd.cardUp then upShown = cd end end
  check("carte améliorée : nom en vert", upShown and upShown.name._calls.SetTextColor
    and math.abs(upShown.name._calls.SetTextColor[2] - H.ns.Art.C.upGreen[2]) < 1e-9)
  check("plus de cartes que de places : défilement possible", Dv:MaxOffset() > 0, Dv:MaxOffset())
  run(Dv.panel, "OnMouseWheel", -1)
  check("molette : une rangée plus bas", Dv.offset == 1)
  for _ = 1, 10 do run(Dv.cards[1], "OnMouseWheel", -1) end
  local last = Dv.list[#Dv.list]
  local lastShown = false
  for _, cd in ipairs(Dv.cards) do
    if cd._shown and cd.cardId == last.id and (cd.cardUp or false) == (last.up or false) then lastShown = true end
  end
  check("molette jusqu'au bout : dernière carte visible", Dv.offset == Dv:MaxOffset() and lastShown)
  run(Dv.frame, "OnMouseWheel", 5)
  check("molette vers le haut", Dv.offset == Dv:MaxOffset() - 1)
  local prop = H.key("1")
  check("panneau ouvert : les touches ne vont pas à l'écran dessous", prop == true and Dv:IsShown()
    and currentKind() == "map")
  H.key("ESCAPE")
  check("Échap ferme le panneau (pas la fenêtre)", not Dv:IsShown() and shown())
  H.click(UI().deckButton)
  H.click(Dv.frame)
  check("clic hors du panneau : fermé", not Dv:IsShown())
  H.click(UI().deckButton)
  H.click(Dv.close)
  check("bouton Fermer", not Dv:IsShown())
  H.click(UI().deckButton)
  H.click(UI().deckButton)
  check("second clic sur Deck : fermé", not Dv:IsShown())

  -- plateau d'un écran hors combat : la pile du deck
  exp = freshRun(SEED + 3, "campfire")
  Dv = UI().deckView
  H.click(UI().current.pile)
  check("pile du deck (feu de camp) : panneau ouvert", Dv:IsShown() and Dv.kind == "deck" and #Dv.list == #exp.deck)
  H.key("ESCAPE")

  -- combat : pioche (triée, jamais l'ordre réel), défausse, consumées, deck complet
  exp = freshRun(SEED, "combat")
  Dv = UI().deckView
  H.settle()
  local c = C().combat()
  -- ordre réel volontairement à rebours du tri
  local rev = Dv.sorted(c.draw)
  for i = 1, #rev do c.draw[i] = rev[#rev - i + 1] end
  local real = {}
  for i = 1, #c.draw do real[i] = c.draw[i].uid end
  H.click(V().drawPile)
  check("clic sur la pioche : panneau de la pioche", Dv:IsShown() and Dv.kind == "draw" and #Dv.list == #c.draw)
  snap("combat-pioche")
  local same, differs = true, false
  local srt = Dv.sorted(c.draw)
  for i = 1, #srt do
    if Dv.list[i] ~= srt[i] then same = false end
    if Dv.list[i].uid ~= real[i] then differs = true end
  end
  check("pioche affichée triée", same)
  check("pioche : jamais l'ordre réel de tirage", differs or #c.draw < 2)
  local untouched = true
  for i = 1, #c.draw do if c.draw[i].uid ~= real[i] then untouched = false end end
  check("ouvrir la pioche ne touche pas à l'ordre réel", untouched)
  H.click(V().drawPile)
  check("second clic sur la pioche : fermé", not Dv:IsShown())
  H.click(V().discardPile)
  check("défausse consultable", Dv:IsShown() and Dv.kind == "discard" and #Dv.list == #c.discard)
  H.key("ESCAPE")
  c.exhaust[#c.exhaust + 1] = c.draw[#c.draw]
  table.remove(c.draw)
  V():Render()
  check("tas des consumées affiché quand il y en a", V().exhaustPile._shown and V().exhaustPile.count._text == 1)
  H.click(V().exhaustPile)
  check("consumées consultables", Dv:IsShown() and Dv.kind == "exhaust" and #Dv.list == 1)
  H.key("ESCAPE")
  check("bouton Deck aussi en combat", UI().deckButton._shown)
  H.click(UI().deckButton)
  check("deck complet consultable en combat", Dv:IsShown() and Dv.kind == "deck" and #Dv.list == #exp.deck)
  local hand = #c.hand
  H.key("1")
  check("panneau ouvert en combat : la touche 1 ne joue rien", #c.hand == hand and Dv:IsShown())
  H.key("ESCAPE")
  check("Échap : panneau fermé, combat intact", not Dv:IsShown() and currentKind() == "combat")
end

print("U20 peau : SkinData cohérent avec Media/, carte composée, repli d'icône")
do
  freshRun(SEED, "combat")
  H.settle()
  local Skin = H.ns.Skin
  local W = H.ns.Widgets
  local ROOT = "Interface\\AddOns\\SlayTheDragon\\Media\\"
  check("racine des textures de l'addon", Skin.root == ROOT, Skin.root)
  local function disk(rel) return root .. "/Media/" .. rel:gsub("\\", "/") end
  local function u16(s, i) return s:byte(i) + 256 * s:byte(i + 1) end
  local function pow2(n) return n > 0 and math.floor(math.log(n) / math.log(2) + 0.5) == math.log(n) / math.log(2) end
  -- chaque texture : fichier présent, TGA 32 bits non compressé (origine en bas, 8 bits d'alpha),
  -- dimensions en puissances de deux égales à celles de SkinData, zone utile et coordonnées cohérentes
  local bad, n = {}, 0
  for name, e in pairs(Skin.tex) do
    n = n + 1
    local f = io.open(disk(e.file), "rb")
    local hdr = f and f:read(18)
    local size = f and f:seek("end")
    if f then f:close() end
    local ok = hdr and #hdr == 18 and hdr:byte(3) == 2 and hdr:byte(17) == 32 and hdr:byte(18) == 8
      and u16(hdr, 13) == e.w and u16(hdr, 15) == e.h and size == 18 + e.w * e.h * 4
      and pow2(e.w) and pow2(e.h) and e.cw <= e.w and e.ch <= e.h
      and math.abs(e.tc[2] - e.cw / e.w) < 1e-4 and math.abs(e.tc[4] - e.ch / e.h) < 1e-4
    if not ok then bad[#bad + 1] = name end
  end
  table.sort(bad)
  check(n .. " textures de SkinData : fichiers TGA présents et conformes", #bad == 0, table.concat(bad, ", "))
  bad = {}
  for _, need in ipairs({ "card_body_ivory", "card_body_violet", "card_body_blue", "card_body_gold", "card_panel",
    "card_ribbon", "card_cost", "card_plate", "medal_ring", "medal_mask", "medal_glass",
    "gem_uncommon", "gem_rare", "gem_epic", "gem_legendary", "card_back", "tile_slate", "pill_slate", "pill_rim",
    "nine_glow" }) do
    if not Skin.tex[need] then bad[#bad + 1] = need end
  end
  check("pièces attendues présentes (corps, ruban, coût, médaillon, gemmes, dos, plaques des cartes)",
    #bad == 0, table.concat(bad, ", "))
  local missingIcons, ni = {}, 0
  for key, rel in pairs(Skin.icons) do
    ni = ni + 1
    local f = io.open(disk(rel), "rb")
    if f then f:close() else missingIcons[#missingIcons + 1] = key end
  end
  check(ni .. " icônes de SkinData présentes dans Media/Icons", ni > 0 and #missingIcons == 0, table.concat(missingIcons, ", "))
  -- icônes réellement utilisées : chaque nom `tga` de UI/Art.lua est copié (ou signalé par le script)
  local used, absent = 0, {}
  local art = assert(io.open(root .. "/UI/Art.lua")):read("*a")
  for name in art:gmatch('tga%s*=%s*"([^"]+)"') do
    used = used + 1
    if not Skin.icons[name:lower()] then absent[#absent + 1] = name end
  end
  check("icônes nommées dans Art.lua toutes copiées (" .. used .. ")", #absent == 0, table.concat(absent, ", "))
  for kind, rel in pairs(Skin.fonts) do
    local f = io.open(disk(rel), "rb")
    check("police " .. kind .. " présente", f ~= nil, rel)
    if f then f:close() end
  end
  -- carte composée
  local holder = UI().content
  local card = W.card(holder)
  local function tex(t) return t._texture end
  card:SetCard("penance", false, { cost = 2, playable = true })
  check("carte : corps ivoire (Sacré), ruban, coût, panneau, médaillon",
    tex(card.bg) == ROOT .. Skin.tex.card_body_ivory.file and tex(card.panel) == ROOT .. Skin.tex.card_panel.file
    and tex(card.ring) == ROOT .. Skin.tex.medal_ring.file and card.cost._text == "2" and card.name._text == "Penance"
    and tex(card.ribbon) == ROOT .. Skin.tex.card_ribbon.file)
  check("carte : icône améliorée de Media, masquée par l'ouverture du médaillon",
    tex(card.icon) == ROOT .. Skin.icons.spell_holy_penance and card.icon._calls.AddMaskTexture ~= nil)
  check("carte peu commune : gemme triangle verte", card.gem._shown and tex(card.gem) == ROOT .. Skin.tex.gem_uncommon.file)
  check("texte centré dans le panneau, chiffres en évidence", (card.body._text or ""):find("|cffffffff", 1, true)
    and card.body._calls.SetJustifyH[1] == "CENTER")
  check("nom horizontal sur le ruban (aucune rotation), centré sur la bande", card.name._calls.SetRotation == nil
    and card.name._points[1][4] == Skin.card.name.cx * W.CARD_W and Skin.card.name.angle == nil
    and Skin.tex.card_ribbon_flat == nil)
  card:SetCard("mind_blast", false, { cost = 1, playable = true })
  check("Ombre : corps violet ; mot-clé dans la plaque du bas", tex(card.bg) == ROOT .. Skin.tex.card_body_violet.file
    and card.plate.shown and (card.plateText._text or ""):find("Cooldown", 1, true) and not card.gem._shown)
  card:SetCard("inner_fire", false, { cost = 1, playable = true })
  check("protection : corps bleu ; carte de base sans gemme ni plaque", tex(card.bg) == ROOT .. Skin.tex.card_body_blue.file
    and not card.gem._shown and not card.plate.shown)
  card:SetCard("smite", false, { cost = 1, playable = true })
  check("départ : corps doré", tex(card.bg) == ROOT .. Skin.tex.card_body_gold.file)
  card:SetCard("smite", false, { cost = 3, playable = false, reason = "Not enough mana." })
  check("injouable : corps grisé, raison dans une plaque rouge", card.bg._calls.SetDesaturated[1] == true
    and card.reasonPlate and card.reasonPlate._shown and card.reasonPlate.text._text == "Not enough mana.")
  card:SetCard("smite", true, { cost = 1, playable = true })
  check("améliorée : nom vert, chiffre changé en vert", card.name._calls.SetTextColor[2] == H.ns.Art.C.upGreen[2]
    and (card.body._text or ""):find("|cff7dff7d9|r", 1, true), card.body._text)
  check("carte jouable : plus de plaque rouge", not card.reasonPlate._shown)
  local chat0 = #(_G.DEFAULT_CHAT_FRAME._lines)
  H.slash("ruban")
  check("/slay ruban retiré : simple aide, rien ne change", #(_G.DEFAULT_CHAT_FRAME._lines) > chat0
    and tex(card.ribbon) == ROOT .. Skin.tex.card_ribbon.file and H.ns.Persist.options().flatRibbon == nil)
  -- repli : icône améliorée absente de Media -> icône du sort du jeu
  local saved = Skin.icons.spell_holy_holysmite
  Skin.icons.spell_holy_holysmite = nil
  card:SetCard("smite", false, {})
  check("repli : sans fichier dans Media, icône du sort du jeu", tex(card.icon) == 100000 + 585, tex(card.icon))
  Skin.icons.spell_holy_holysmite = saved
  card:Hide()
  -- jeton d'état et bulle d'intention : médaillon et liseré teinté
  local v = V()
  local slot
  for _, s in pairs(v.slotOf) do slot = s end
  check("intention : case de barre d'action du jeu et chiffre en couleur", slot and slot.intent.slot
    and slot.intent.slot.frame._wow == "slot_frame" and slot.intent._shown and (slot.intent.text._text or "") ~= ""
    and slot.intent.text._calls.SetTextColor ~= nil)
  check("mana : grand anneau doré, « N » et « /max », libellé Mana", v.mana.text._text == tostring(C().combat().player.mana)
    and v.mana.ring._wow == "ring_large" and v.mana.label._text == "Mana" and v.mana.pips == nil)
end

print("U21 modèles d'ennemis (essais, repli en médaillon, /slay modeles) ; noms d'ennemis lisibles")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  -- client neuf (badCreatures/badDisplays lus au moment des essais, pas au démarrage)
  freshRun(SEED, "combat")
  H.settle()
  local ns = H.ns
  local Art, W = ns.Art, ns.Widgets
  -- données : chaque ennemi et chaque PNJ a une créature ET un affichage de repli ; icône de repli
  local noArt = {}
  for id in pairs(ns.Enemies) do
    local a = Art.enemies[id]
    if not (a and a.creature and a.display and a.icon) then noArt[#noArt + 1] = id end
  end
  for id, a in pairs(Art.npcs) do
    if not (a.creature and a.display) then noArt[#noArt + 1] = "npc:" .. id end
  end
  table.sort(noArt)
  check("ennemis et PNJ : créature, affichage(s) et icône de repli", #noArt == 0, table.concat(noArt, ", "))
  check("plus d'icône « point d'interrogation » pour les ennemis", Art.enemyIcon == nil)

  -- combat Sorcier défias + murloc : sorcier sans aucun modèle, murloc chargé par son affichage
  H.badCreatures = { [619] = true, [126] = true }
  H.badDisplays = { [2329] = true, [2330] = true }
  local function fight(ids)
    local c = C().combat()
    c.enemies = {}
    for i = 1, #ids do
      if not ns.Combat.spawn(c, ids[i]) then
        -- au-delà de Combat.MAX_ENEMIES (un mourant reste affiché) : copie directe
        local e = deepcopy(c.enemies[1])
        e.uid, e.id, e.mem = c.nextUid, ids[i], {}
        e.intent = ns.Enemies[ids[i]].pattern[1]
        c.nextUid = c.nextUid + 1
        c.enemies[#c.enemies + 1] = e
      end
    end
    local v = V()
    v.c = nil
    v:Show({ state = c })
    return v, c
  end
  local v = fight({ "sorcerer", "murloc" })
  H.advance(0.5)
  local function slotOf(id)
    for _, s in pairs(v.slotOf) do
      if s.uid and ns.Combat and v.c then
        for _, e in ipairs(v.c.enemies) do if e.uid == s.uid and e.id == id then return s end end
      end
    end
  end
  local so, mu = slotOf("sorcerer"), slotOf("murloc")
  check("pas de repli avant la fin des essais", so and not so.fallback._shown)
  H.advance(3 * W.MODEL_WAIT)
  check("sorcier sans modèle : médaillon argenté de repli", so.fallback._shown and so.fallback.ring ~= nil
    and so.fallback.icon._texture ~= Art.QUESTION, so.fallback.icon._texture)
  check("repli : icône de l'ennemi (Media)", so.fallback.icon._texture
    == "Interface\\AddOns\\SlayTheDragon\\Media\\" .. ns.Skin.icons.spell_fire_flamebolt, so.fallback.icon._texture)
  check("repli au-dessus du modèle", R.rect(so.fallback) ~= nil and so.fallback._level > so.model._level)
  check("murloc : affichage 983 après l'échec de la créature", mu.model._model == "display:983" and not mu.fallback._shown,
    mu.model._model)
  check("statut des essais (créature, affichages)", W.models.sorcerer.state == "missing"
    and table.concat(W.models.sorcerer.tries, ", ") == "creature 619, display 2329, display 2330"
    and W.models.murloc.via == "display 983")
  -- relance tardive : la créature arrive dans le cache du client -> le repli s'efface
  H.badCreatures = { [126] = true }
  H.advance(W.MODEL_LATE + W.MODEL_WAIT + 0.1)
  check("relance tardive : modèle trouvé, repli caché, plus listé manquant", not so.fallback._shown
    and so.model._model == "creature:619" and W.models.sorcerer.state == "ok" and not W.missing["model:sorcerer"])
  -- OnModelLoaded sonne alors que GetModelFileID ne rend rien encore : l'essai est jugé réussi
  H.badCreatures = { [117] = true }
  W.setCreature(so.model, "gnoll", so.fallback)
  so.model:GetScript("OnModelLoaded")(so.model)
  H.advance(W.MODEL_WAIT + 0.05)
  check("OnModelLoaded suffit à valider un essai", W.models.gnoll.state == "ok" and W.models.gnoll.via == "creature 117"
    and not so.fallback._shown)
  -- sans icône : disque sombre (silhouette), jamais le point d'interrogation
  W.setFallbackArt(so.fallback, nil)
  check("repli sans icône : disque sombre", so.fallback.icon._texture == nil and so.fallback.icon._calls.SetColorTexture
    and so.fallback.icon._calls.SetColorTexture[1] == Art.C.slateDark[1])

  -- /slay modeles : une ligne recopiable par modèle absent (ennemis et PNJ)
  H.badCreatures = { [619] = true, [639] = true, [235] = true }
  H.badDisplays = { [2329] = true, [2330] = true, [1691] = true }
  _G.DEFAULT_CHAT_FRAME._lines = {}
  H.slash("models")
  H.advance(3.5)
  local said = table.concat(_G.DEFAULT_CHAT_FRAME._lines, "\n")
  local total = 0
  for _ in pairs(Art.enemies) do total = total + 1 end
  for _ in pairs(Art.npcs) do total = total + 1 end
  check("/slay modeles : bilan chiffré", said:find("models: " .. (total - 2) .. "/" .. total .. " loaded, 2 without a model", 1, true), said)
  check("/slay modeles : ennemi manquant et identifiants essayés",
    said:find("sorcerer: creature 619, display 2329, display 2330 -> no model", 1, true), said)
  check("/slay modeles : PNJ manquant", said:find("npc:salma_saldean: creature 235, display 1691 -> no model", 1, true), said)
  check("/slay modeles : modèle chargé par un repli signalé", said:find("vancleef: creature 639 -> no model; loaded by display 2029", 1, true), said)
  check("/slay modeles : un PNJ et tous les ennemis dans l'aperçu", #V().preview.models == total)
  local stateOk = true
  for _, m in ipairs(V().preview.models) do
    local want = (m.key == "sorcerer" or m.key == "npc:salma_saldean") and "no model" or "model: "
    if not (m.state._text or ""):find(want, 1, true) then stateOk = false end
    if m.fallback.icon._texture == Art.QUESTION then stateOk = false end
  end
  check("aperçu : état sous chaque modèle, aucun point d'interrogation", stateOk)
  H.badCreatures, H.badDisplays = {}, nil
  V().preview:Hide()

  -- noms : toujours lisibles, de 1 à 6 ennemis, aux échelles extrêmes de la fenêtre
  local function vis(o)
    while o do
      if not rawget(o, "_shown") then return false end
      o = rawget(o, "_parent")
    end
    return true
  end
  local function flevel(f)
    if not f then return 0 end
    local p = rawget(f, "_parent")
    local own = rawget(f, "_level") or 0
    if p and rawget(p, "_name") ~= "UIParent" then return math.max(own, flevel(p) + 1) end
    return own
  end
  local function frameOf(o)
    local k = rawget(o, "_kind")
    if k == "Texture" or k == "FontString" or k == "Line" then return rawget(o, "_parent") end
    return o
  end
  local function under(o, root2)
    while o do if o == root2 then return true end o = rawget(o, "_parent") end
    return false
  end
  local function inter(a, b) return a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5 end
  local Scene = ns.Scene
  local bad = {}
  -- personnages agrandis (golem, VanCleef) aux places décalées vers le bas (2e, 4e) : cas le plus bas
  local group = { "murloc", "harvest_golem", "sorcerer", "vancleef", "mystic", "gnoll" }
  local layouts = 0
  for _, scale in ipairs({ 0.6, 1, 1.5 }) do
    ns.Persist.options().scale = scale
    ns.UI.applyScale()
    for n = 1, 6 do
      local ids = {}
      for i = 1, n do ids[i] = group[i] end
      fight(ids)
      H.advance(0.1)
      if scale == 1 and n == 4 then snap("combat-boss") end
      layouts = layouts + 1
      local content = R.rect(ns.UI.content)
      local k = scale -- unités du contenu -> unités résolues
      local boardTop = content[4] - Scene.BOARD_Y * k
      local tags = {}
      for _, s in pairs(V().slotOf) do
        local label = ("%d ennemi(s), échelle %.1f, %s"):format(n, scale, tostring(s.name._text))
        local nr = R.rect(s.name)
        local tr = R.rect(s.tag)
        if not (vis(s.name) and (s.name._text or "") ~= "" and nr and tr) then
          bad[#bad + 1] = label .. " : nom caché ou vide"
        else
          if nr[1] < content[1] or nr[3] > content[3] or nr[4] > content[4] or nr[2] < content[2] then
            bad[#bad + 1] = label .. " : nom rogné par le contenu"
          end
          if nr[2] < boardTop + 4 * k or tr[2] < boardTop then bad[#bad + 1] = label .. " : nom sur le plateau" end
          local sr = R.rect(s.st)
          if sr and sr[2] < boardTop then bad[#bad + 1] = label .. " : états sur le plateau" end
          -- cadre compact (direction B) : au-dessus de la tête, dans le décor (sous le bandeau), nom dans
          -- son logement, barre de vie dans le sien, au-dessus du modèle et du repli
          if (s.name:GetStringWidth() or 0) > (s.nameW or 0) + 0.5 then bad[#bad + 1] = label .. " : nom plus large que son logement" end
          if tr[4] > content[4] - Scene.TOP * k + 0.5 then bad[#bad + 1] = label .. " : cadre sur le bandeau" end
          local hr = R.rect(s.hp)
          if not hr or hr[1] < tr[1] - 0.5 or hr[3] > tr[3] + 0.5 or hr[4] > tr[4] + 0.5 or hr[2] < tr[2] - 0.5 then
            bad[#bad + 1] = label .. " : barre de vie hors du cadre"
          end
          if nr[2] < (hr and hr[4] or nr[2]) - 2 * k then bad[#bad + 1] = label .. " : nom sur la barre de vie" end
          if flevel(s.tag) <= flevel(s.model) or flevel(s.tag) <= flevel(s.fallback) then
            bad[#bad + 1] = label .. " : cadre sous le modèle ou le repli"
          end
          -- rien de visible, d'un cadre de niveau supérieur ou égal (hors la pilule elle-même), ne le recouvre
          local nl = flevel(s.tag)
          for _, o in ipairs(H.objects) do
            local kind = rawget(o, "_kind")
            if (kind == "Texture" or kind == "FontString" or kind == "PlayerModel") and o ~= s.name and not under(o, s.tag)
              and under(o, ns.UI.content) and vis(o) and not (o._calls.SetAlpha and o._calls.SetAlpha[1] == 0) then
              local r = R.rect(o)
              if r and inter(r, nr) and flevel(frameOf(o)) >= nl then
                bad[#bad + 1] = label .. " : recouvert par " .. kind .. " " .. tostring(o._texture or o._text or "")
              end
            end
          end
          for _, t in ipairs(tags) do
            if inter(t, tr) then bad[#bad + 1] = label .. " : chevauche un autre cadre" end
          end
          tags[#tags + 1] = tr
        end
      end
    end
  end
  ns.Persist.options().scale = 1
  ns.UI.applyScale()
  check(("noms d'ennemis lisibles (%d dispositions : 1 à 6 ennemis × 3 échelles)"):format(layouts), #bad == 0,
    table.concat(bad, "\n        "))
end

print("U22 textes des cartes : toutes les cartes tiennent dans le panneau et le ruban ; textes visibles au repos")
do
  freshRun(SEED, "combat")
  H.settle()
  local ns = H.ns
  local W, Skin = ns.Widgets, ns.Skin
  local SC = Skin.card
  local CW = W.CARD_W
  local LH = H.metrics.lineHeight
  -- textures lues sur le disque (TGA 32 bits, origine en bas) : pixel(x, y) avec y vers le bas
  local function readTGA(rel)
    local f = assert(io.open(root .. "/Media/" .. rel:gsub("\\", "/"), "rb"))
    local d = f:read("*a")
    f:close()
    local w, h = d:byte(13) + 256 * d:byte(14), d:byte(15) + 256 * d:byte(16)
    return function(x, y)
      x, y = math.floor(x), math.floor(y)
      if x < 0 or y < 0 or x >= w or y >= h then return 0, 0, 0, 0 end
      local i = 18 + ((h - 1 - y) * w + x) * 4 + 1
      return d:byte(i + 2), d:byte(i + 1), d:byte(i), d:byte(i + 3)
    end
  end
  -- échantillon d'une pièce posée en rect (fractions de la largeur du corps) au point (u, v) en unités
  local function sampler(texName, rect)
    local e = Skin.tex[texName]
    local px = readTGA(e.file)
    return function(u, v)
      local x = (u / CW - rect[1]) / rect[3] * e.cw
      local y = (v / CW - rect[2]) / rect[4] * e.ch
      if x < 0 or y < 0 or x >= e.cw or y >= e.ch then return 0, 0, 0, 0 end
      return px(x, y)
    end
  end
  local panel = sampler("card_panel", SC.pieces.card_panel)
  local ribbon = sampler("card_ribbon", SC.pieces.card_ribbon)
  local gems = {}
  for k, r in pairs(SC.gems) do gems[k] = sampler("gem_" .. k, r) end
  local function dark(u, v)
    local r, g, b, a = panel(u, v)
    return a > 250 and r + g + b < 360
  end
  -- tous les points d'un rectangle (pas de 0,5 unité) vérifient pred ?
  local function all(x0, y0, x1, y1, pred)
    local y = y0
    while y <= y1 + 1e-9 do
      local x = x0
      while x <= x1 + 1e-9 do
        if not pred(x, y) then return false, ("(%.1f, %.1f)"):format(x, y) end
        x = x + 0.5
      end
      y = y + 0.5
    end
    return true
  end
  local MX, MT, MB = 4, 1, 4   -- marges minimales vérifiées : côtés, haut (intérieur), bas (biseau compris)
  local function splitLines(t)
    local out = {}
    if t == nil or t == "" then return out end
    for l in (t .. "\n"):gmatch("(.-)\n") do out[#out + 1] = l end
    return out
  end
  local holder = UI().content
  local card = W.card(holder)
  local ids = {}
  for id in pairs(ns.Cards) do ids[#ids + 1] = id end
  table.sort(ids)
  local bad, under, nameUnder = {}, {}, {}
  local bodyDist, nameDist = {}, {}
  local variants = {
    { key = "", opts = { playable = true } },
    { key = " (injouable)", opts = { playable = false, reason = "Not enough mana." } },
  }
  -- toutes les raisons d'une carte injouable en combat (les plus longues passent sur deux lignes)
  for _, why in ipairs({ "phase", "unplayable", "casting", "forbidden", "condition", "target", "over" }) do
    variants[#variants + 1] = { key = " (" .. why .. ")", opts = { playable = false, reason = ns.Controller.reasonText(why) } }
  end
  local reasonDist = {}
  local cases = 0
  -- paliers par carte (tableau : SLAY_TIERS=fichier écrit le relevé, séparé par des tabulations)
  local tiers = {}
  local function d_text(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      for vi, var in ipairs(variants) do
        cases = cases + 1
        card:SetCard(id, up, var.opts)
        local label = id .. (up and "+" or "") .. var.key
        local fit = card.bodyFit
        local fs = card.body
        local lines = splitLines(fs._text)
        local size = fs._fontSize
        local lh = size * LH
        local pt = fs._points[1]
        local cx, cy = pt[4], -pt[5]
        local top = cy - #lines * lh / 2
        local bottom = top + #lines * lh
        if not fit.ok then bad[#bad + 1] = label .. " : ne tient à aucun palier" end
        if fs:GetNumLines() ~= #lines or fs:IsTruncated() then
          bad[#bad + 1] = label .. " : lignes recoupées par le client (" .. fs:GetNumLines() .. " / " .. #lines .. ")"
        end
        local gem = card.gem._shown and gems[(card.gem._texture or ""):match("gem_(%a+)%.tga$")]
        for k, line in ipairs(lines) do
          local lw = H.textWidth(fs, line, size)
          local x0, x1 = cx - lw / 2, cx + lw / 2
          local y0, y1 = top + (k - 1) * lh, top + k * lh
          local ok, where = all(x0 - MX, y0 - MT, x1 + MX, y1 + MB, dark)
          if not ok then bad[#bad + 1] = ("%s : ligne %d hors de l'ardoise (marges comprises) en %s"):format(label, k, where) end
          if gem then
            local ok2, where2 = all(x0, y0, x1, y1, function(u, v) local _, _, _, a = gem(u, v) return a <= 60 end)
            if not ok2 then bad[#bad + 1] = ("%s : ligne %d sous la gemme en %s"):format(label, k, where2) end
          end
        end
        if card.plate.shown and bottom > SC.pieces.card_plate[2] * CW then bad[#bad + 1] = label .. " : sur la plaque du bas" end
        if card.reasonPlate and card.reasonPlate._shown then
          local rp = card.reasonPlate._points[1]
          if bottom > -rp[5] - card.reasonPlate._h / 2 then bad[#bad + 1] = label .. " : sous la plaque de raison" end
          -- raison : dans sa plaque (marges de 6 unités), plaque dans la largeur du corps, au-dessus de
          -- la plaque des mots-clés
          local p, rt = card.reasonPlate, card.reasonPlate.text
          local rl = splitLines(rt._text)
          local rw = 0
          for _, l in ipairs(rl) do rw = math.max(rw, H.textWidth(rt, l, rt._fontSize)) end
          if rw > p._w - 12 + 0.01 or p._w > CW + 0.01 or rt:IsTruncated() or rt:GetNumLines() ~= #rl
            or #rl > 2 or rt:GetStringHeight() > p._h - 2 then
            bad[#bad + 1] = ("%s : raison « %s » hors de sa plaque"):format(label, tostring(rt._text))
          end
          if card.plate.shown and -rp[5] + p._h / 2 > card.plate.box.inT - 1 then
            bad[#bad + 1] = label .. " : plaque de raison sur le texte des mots-clés"
          end
          reasonDist[rt._text:gsub("\n", " / ")] = rt._fontSize
        end
        if vi == 1 then
          bodyDist[size] = (bodyDist[size] or 0) + 1
          if fit.under then under[#under + 1] = ("%s (%s)"):format(label, tostring(size)) end
          -- nom : une ligne dans la bande du ruban (encre de la ligne, marge de 2 unités)
          local nf = card.nameFit
          local ns_ = card.name._fontSize
          local np = card.name._points[1]
          local nw = H.textWidth(card.name, card.name._text, ns_)
          local nlh = ns_ * LH
          local ny0 = -np[5] - nlh / 2
          local ok, where = all(np[4] - nw / 2 - 2, ny0 + 0.28 * ns_, np[4] + nw / 2 + 2, ny0 + 1.33 * ns_,
            function(u, v) local _, _, _, a = ribbon(u, v) return a > 200 end)
          if not ok or not nf.ok or card.name:IsTruncated() then
            bad[#bad + 1] = ("%s : nom hors du ruban en %s"):format(label, tostring(where))
          end
          nameDist[ns_] = (nameDist[ns_] or 0) + 1
          tiers[#tiers + 1] = { label = label, name = card.name._text, nameSize = ns_, bodySize = size,
            lines = #lines, text = d_text(card.body._text) }
          if nf.under then nameUnder[#nameUnder + 1] = ("%s (%s)"):format(card.name._text, tostring(ns_)) end
        end
      end
    end
  end
  -- plaque du bas : texte dans la zone utile (intérieur sombre moins les marges), plaque visible
  -- (devant le corps, alpha, taille), dans la largeur du corps ; toutes les cartes et combinaisons
  do
    local P = W.CARD_PLATE
    local plateTex = readTGA(Skin.tex.card_plate.file)
    -- les constantes mesurées correspondent aux pixels : intérieur opaque et sombre (zone du texte,
    -- marges comprises, hors arrondi des coins du bas)
    local u = SC.pieces.card_plate[4] * CW / P.texH
    local okTex = true
    for y = P.inT, P.inB - 4 do
      for x = P.inL + math.floor(P.margin / u), P.inR - math.floor(P.margin / u) do
        local r, g, b, a = plateTex(x, y)
        if a < 250 or r + g + b > 450 then okTex = false end -- (paillettes de l'ardoise tolérées)
      end
    end
    check("plaque du bas : zone utile mesurée sur Media/card_plate.tga (intérieur sombre, marges comprises)", okTex)
    local plateBad, combos, wide = {}, {}, {}
    local function checkPlate(label)
      local pl, fs = card.plate, card.plateText
      if not pl.shown then return end
      local box = pl.box
      local size = fs._fontSize
      local tw = H.textWidth(fs, fs._text, size)
      local pt = fs._points[1]
      local cx, cy = pt[4], -pt[5]
      if tw > box.textW + 0.01 or math.abs(cx - box.cx) > 0.01 then
        plateBad[#plateBad + 1] = ("%s : « %s » (%.1f) plus large que la zone (%.1f)"):format(label, fs._text, tw, box.textW)
      end
      if cy - size * LH / 2 < box.inT - 0.5 or cy + size * LH / 2 > box.inB + 0.5 then
        plateBad[#plateBad + 1] = label .. " : texte hors de la hauteur de l'intérieur"
      end
      if fs:IsTruncated() or fs:GetNumLines() ~= 1 then plateBad[#plateBad + 1] = label .. " : texte recoupé" end
      if box.x < -0.01 or box.x + box.w > CW + 0.01 then plateBad[#plateBad + 1] = label .. " : plaque plus large que le corps" end
      for _, t in ipairs(pl.parts) do
        local a = t._calls.SetAlpha and t._calls.SetAlpha[1] or 1
        if not t._shown or a < 1 or t._w <= 0 or t._h <= 0 or (t._sub or 0) <= (card.bg._sub or 0)
          or t._layer ~= card.bg._layer then
          plateBad[#plateBad + 1] = label .. " : plaque invisible (caché, alpha, taille nulle ou derrière le corps)"
          break
        end
      end
      local l, m, r = pl.parts[1], pl.parts[2], pl.parts[3]
      if math.abs(l._w + m._w + r._w - box.w) > 0.01 or math.abs(l._h - box.h) > 0.01 then
        plateBad[#plateBad + 1] = label .. " : tranches mal posées"
      end
      if box.inT < 163 then plateBad[#plateBad + 1] = label .. " : intérieur de la plaque sous le corps" end
      combos[fs._text] = combos[fs._text] or label
      if card.plateFit.wide then wide[fs._text] = ("%s (plaque %.0f, taille %s)"):format(label, box.w, tostring(size)) end
    end
    for _, id in ipairs(ids) do
      for _, up in ipairs({ false, true }) do
        for _, var in ipairs(variants) do
          card:SetCard(id, up, var.opts)
          checkPlate(id .. (up and "+" or "") .. var.key)
        end
      end
    end
    -- cas extrême (toutes les marques) : plaque au plus large, texte abrégé, jamais hors de la plaque
    ns.Cards.ui_test_all = { name = "Essai", type = "power", cast = true, cooldown = 4, exhaust = true, retain = true,
      cost = 1, text = "Essai.", rarity = "common", actions = {} }
    card:SetCard("ui_test_all", false, { playable = true })
    checkPlate("toutes les marques (essai)")
    local extreme = card.plateText._text
    ns.Cards.ui_test_all = nil
    check(("plaque du bas : %d combinaisons réelles et un cas extrême, texte dans la zone utile, plaque visible devant le corps")
      :format((function() local n = 0 for _ in pairs(combos) do n = n + 1 end return n - 1 end)()),
      #plateBad == 0, table.concat(plateBad, "\n        "))
    local wl = {}
    for t, l in pairs(wide) do if l:sub(1, 6) ~= "toutes" then wl[#wl + 1] = "« " .. t .. " » " .. l end end
    table.sort(wl)
    print("      plaque élargie : " .. (#wl > 0 and table.concat(wl, ", ") or "aucune"))
    print("      cas extrême : « " .. tostring(extreme) .. " »")
  end
  local function dist(t)
    local ks, out = {}, {}
    for k in pairs(t) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b) return a > b end)
    for _, k in ipairs(ks) do out[#out + 1] = k .. " : " .. t[k] end
    return table.concat(out, ", ")
  end
  check(("%d cartes × base/améliorée × jouable/injouable (%d cas) : texte dans l'ardoise, marges comprises ; nom dans le ruban")
    :format(#ids, cases), #bad == 0, table.concat(bad, "\n        "))
  do
    local rl = {}
    for t, sz in pairs(reasonDist) do rl[#rl + 1] = "« " .. t .. " » " .. sz end
    table.sort(rl)
    print("      raisons : " .. table.concat(rl, ", "))
  end
  print("      texte, cartes par taille : " .. dist(bodyDist))
  print("      nom, cartes par taille : " .. dist(nameDist))
  if os.getenv("SLAY_TIERS") then
    local f = assert(io.open(os.getenv("SLAY_TIERS"), "w"))
    for _, t in ipairs(tiers) do
      f:write(table.concat({ t.label, t.name, tostring(t.nameSize), tostring(t.bodySize), tostring(t.lines), t.text }, "\t"), "\n")
    end
    f:close()
  end
  print("      texte sous le plancher (" .. W.BODY_SIZES[#W.BODY_SIZES] .. ") : "
    .. (#under > 0 and table.concat(under, ", ") or "aucune"))
  print("      nom sous le plancher (" .. W.NAME_SIZES[#W.NAME_SIZES] .. ") : "
    .. (#nameUnder > 0 and table.concat(nameUnder, ", ") or "aucun"))
  -- paliers : chaque carte au plus grand palier qui tient (voir U26), la grande majorité à 8,5 ou plus,
  -- aucune sous le plancher
  do
    local big = 0
    for sz, n in pairs(bodyDist) do if sz >= 8.5 then big = big + n end end
    check(("paliers : %d cartes sur %d (base et améliorées) à 8,5 ou plus, aucune sous le plancher"):format(big, #ids * 2),
      big * 3 >= #ids * 2 * 2 and #under == 0, big)
  end
  -- mise en page figée : lignes à retours explicites, largeur plus grande que la plus longue ligne
  card:SetCard("shadowform", false, { playable = true })
  check("Forme d'ombre : lignes posées une à une, aucune recoupe par le client",
    (card.body._text or ""):find("\n", 1, true) and card.body:GetNumLines() == #splitLines(card.body._text)
    and card.body._w >= 2 * W.CARD_TEXT.half * CW)
  -- textes d'une carte fraîche, non survolée : visibles (alpha 1, police et taille valides, au-dessus
  -- des pièces de la carte, rien de dessiné par-dessus)
  local fresh = W.card(holder)
  fresh:SetCard("penance", false, { playable = true, cost = 2 })
  local LAYER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
  local function effAlpha(o)
    local a = 1
    while o do
      local c = rawget(o, "_calls").SetAlpha
      if c then a = a * (c[1] or 1) end
      o = rawget(o, "_parent")
    end
    return a
  end
  local vis = {}
  for _, key in ipairs({ "name", "cost", "body", "plateText" }) do
    local fs = fresh[key]
    if fs._shown then
      local col = fs._calls.SetTextColor
      local okFont = type(fs._fontPath) == "string" and fs._fontPath:find("Baloo", 1, true) and (fs._fontSize or 0) >= 6
      local okLayer = true
      for _, k in ipairs(rawget(fresh.face, "_kids")) do
        if rawget(k, "_kind") == "Texture" and (LAYER[k._layer] or 0) >= LAYER[fs._layer] then okLayer = false end
      end
      for _, k in ipairs(rawget(fresh.face, "_kids")) do
        if rawget(k, "_kind") == "Frame" and k._shown and k ~= fresh.face then okLayer = false end
      end
      if not (fs:IsVisible() and effAlpha(fs) == 1 and okFont and okLayer and (fs._text or "") ~= ""
        and (not col or (col[4] or 1) == 1)) then
        vis[#vis + 1] = key
      end
    end
  end
  check("carte fraîche non survolée : nom, coût, texte et plaque visibles (alpha 1, police, couche au-dessus des pièces)",
    #vis == 0, table.concat(vis, ", "))
  -- police d'addon chargée après coup : à l'ouverture, police et texte de tous les textes sont reposés
  local probe = W.label(holder, "bold", 11)
  probe:SetText("essai")
  local n0 = probe._setFontCount or 0
  UI().frame:Hide()
  UI().frame:Show()
  H.advance(0.2)
  check("ouverture : polices et textes reposés (texte vide jusqu'au survol évité)", (probe._setFontCount or 0) > n0
    and probe._text == "essai" and probe._fontSize == 11)
  -- vol d'une carte (pioche, jeu, récompense) : échelle réelle fixe pendant le vol, animation Scale
  local g = W.ghostCard(holder)
  g:SetCard("smite", false, {})
  local landed = false
  W.fly(g, holder, 100, 100, 300, 200, 0.3, 1, 1, 1, 0.3, function() landed = true end)
  local text0 = g.body._text
  H.now = H.now + 0.1
  local mid = H.visualScale(g)
  check("vol de carte : échelle réelle fixe (0,3), agrandissement par animation Scale, texte inchangé",
    g._scale == 0.3 and mid > 1 and mid < 1 / 0.3 and g.body._text == text0, g._scale .. " / " .. mid)
  H.advance(0.5)
  check("vol de carte : à l'arrivée, échelle réelle posée, animation arrêtée", landed and g._scale == 1
    and H.visualScale(g) == 1)
  W.releaseGhost(g)
  card:Hide()
  fresh:Hide()
  probe:Hide()
  -- planche de cartes (instantané facultatif) : textes longs, injouable, mot-clé, noms longs
  if SNAP then
    local sheet = CreateFrame("Frame", nil, _G.UIParent)
    sheet:SetSize(6 * 140 + 20, 230)
    sheet:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
    sheet:SetScale(1.8)
    local list = { { "shadowform", false, { playable = true } },
      { "penance", false, { playable = false, reason = "Not enough mana." } },
      { "spirit_of_redemption", true, { playable = true } }, { "solace", true, { playable = true } },
      { "mind_blast", false, { playable = true } }, { "smite", false, { playable = true } } }
    for i, e in ipairs(list) do
      local c = W.card(sheet)
      c:SetCard(e[1], e[2], e[3])
      W.placeCenter(c, sheet, 80 + (i - 1) * 140, 125, 1)
    end
    Render.svg(H, sheet, SNAP .. "/cartes.svg", "cartes")
    sheet:Hide()
    -- planche de toutes les cartes (base puis améliorée, côte à côte), langage en mots-clés
    local perRow, cw, ch = 10, 140, 230
    local all = {}
    for _, id in ipairs(ids) do all[#all + 1] = { id, false } all[#all + 1] = { id, true } end
    local rows = math.ceil(#all / perRow)
    local big = CreateFrame("Frame", nil, _G.UIParent)
    big:SetSize(perRow * cw + 20, rows * ch + 10)
    big:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
    big:SetScale(1.5)
    for i, e in ipairs(all) do
      local c = W.card(big)
      c:SetCard(e[1], e[2], { playable = true })
      W.placeCenter(c, big, 80 + ((i - 1) % perRow) * cw, 125 + math.floor((i - 1) / perRow) * ch, 1)
    end
    Render.svg(H, big, SNAP .. "/cartes_mots_cles.svg", "toutes les cartes (base, améliorée)")
    big:Hide()
  end
end

print("U23 premier survol : halos bornés et éteints au départ, pièces d'un seul bloc, rien de créé en route")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local function under(o, top)
    while o do
      if o == top then return true end
      o = rawget(o, "_parent")
    end
    return false
  end
  local function visibleIn(o, top)
    while o and o ~= top do
      if not rawget(o, "_shown") then return false end
      o = rawget(o, "_parent")
    end
    return true
  end
  local function alphaOf(o)
    local c = rawget(o, "_calls").SetAlpha
    return c and (c[1] or 1) or 1
  end
  local function effScale(o)
    local s = 1
    while o do s = s * (rawget(o, "_scale") or 1) o = rawget(o, "_parent") end
    return s
  end
  -- régions (textures, textes) sous f
  local function regions(f, out)
    out = out or {}
    for _, k in ipairs(rawget(f, "_kids")) do
      local kind = rawget(k, "_kind")
      if kind == "Texture" or kind == "FontString" then out[#out + 1] = k
      elseif kind ~= "AnimationGroup" and kind ~= "Animation" and kind ~= "MaskTexture" then regions(k, out) end
    end
    return out
  end
  local function isGlow(t)
    local tex = rawget(t, "_texture")
    return rawget(t, "_kind") == "Texture" and ((type(tex) == "string" and tex:find("glow", 1, true) ~= nil)
      or rawget(t, "_glowLayer") == true)
  end
  -- premier survol d'un élément : une image, puis contrôles ; enfin survol mené à son terme
  local function firstHover(label, f, opts)
    opts = opts or {}
    local Wd = H.ns.Widgets
    local fr = R.rect(f)
    check(label .. " : élément affiché et mesurable", f:IsVisible() and fr ~= nil)
    if not fr then return end
    local size = math.max(fr[3] - fr[1], fr[4] - fr[2])
    local m = 0.4 * size + 12
    local glows = {}
    for _, t in ipairs(regions(f.face)) do if isGlow(t) then glows[#glows + 1] = t end end
    local dark = true
    for _, t in ipairs(glows) do
      if visibleIn(t, f) and alphaOf(t) > 0 and not opts.staticGlow then dark = false end
    end
    check(label .. " : halo éteint avant le premier survol (alpha 0 ou caché)", dark)
    local n0 = #H.bornInAnim
    run(f, "OnEnter")
    run(Wd.driver, "OnUpdate", 0.016)
    H.now = H.now + 0.016
    local bad = {}
    local hs = f.hoverScale or 1
    for _, t in ipairs(glows) do
      if visibleIn(t, f) then
        local r = R.rect(t)
        local a = alphaOf(t)
        if not r or r[1] < fr[1] - m or r[3] > fr[3] + m or r[2] < fr[2] - m or r[4] > fr[4] + m then
          bad[#bad + 1] = "taille " .. (r and string.format("%.0f×%.0f", r[3] - r[1], r[4] - r[2]) or "?")
        end
        if effScale(t) * H.visualScale(f.face) > effScale(f) * hs * 1.001 then bad[#bad + 1] = "échelle" end
        if not opts.staticGlow and a > 0.5 then bad[#bad + 1] = "alpha " .. a end
      end
    end
    check(label .. " : première image du premier survol, halo borné autour de l'élément et alpha parti de 0",
      #bad == 0, table.concat(bad, ", "))
    check(label .. " : aucune région créée pendant l'animation d'échelle", #H.bornInAnim == n0,
      table.concat(H.bornInAnim, ", ", n0 + 1))
    H.advance(0.5)
    -- survol terminé : toutes les régions visibles descendent du visuel et ont la même échelle effective
    local scales, outside = {}, {}
    local target = effScale(f.face)
    local fr2 = R.rect(f.face)
    for _, t in ipairs(regions(f)) do
      local excluded = false
      for _, x in ipairs(opts.fixed or {}) do if under(t, x) then excluded = true end end
      if not excluded and visibleIn(t, f) and (rawget(t, "_kind") ~= "FontString" or (t._text or "") ~= "") then
        if not under(t, f.face) then outside[#outside + 1] = tostring(rawget(t, "_texture") or t._text or rawget(t, "_kind")) end
        if math.abs(effScale(t) - target) > 1e-9 then scales[#scales + 1] = string.format("%.3f", effScale(t)) end
        if opts.inside then
          local r = R.rect(t)
          if r and fr2 and (r[1] < fr2[1] - 0.5 or r[3] > fr2[3] + 0.5 or r[2] < fr2[2] - 0.5 or r[4] > fr2[4] + 0.5) then
            outside[#outside + 1] = "hors du visuel : " .. tostring(rawget(t, "_texture") or t._text)
          end
        end
      end
    end
    check(label .. " : survol terminé, toutes les pièces dans le visuel animé, même échelle effective ("
      .. string.format("%.2f", target) .. ")", #outside == 0 and #scales == 0 and f.face._scale == hs,
      table.concat(outside, ", ") .. " " .. table.concat(scales, ", "))
    run(f, "OnLeave")
    H.advance(0.5)
  end

  -- combat : carte de la main (avec plaque du bas et plaque de raison), bouton doré, bouton rond
  freshRun(SEED, "combat")
  H.settle()
  local v = V()
  firstHover("carte de la main", v.cards[1], { inside = true })
  local unplayable
  for i = 1, #C().combat().hand do
    local info = C().handInfo(i)
    if info and not info.playable and v.cards[i].reasonPlate then unplayable = v.cards[i] end
  end
  if not unplayable then
    -- carte rendue injouable pour l'essai : plaque de raison
    local c2 = v.cards[2]
    c2:SetCard(c2.cardId, c2.cardUp, { playable = false, reason = "Not enough mana" })
    unplayable = c2
  end
  firstHover("carte injouable (plaque de raison)", unplayable, { inside = true })
  firstHover("bouton doré « Fin du tour »", v.endTurn)
  firstHover("bouton rond ≡", UI().gear)
  -- marchand : objets (butin) et service
  freshRun(SEED + 2, "merchant")
  local s = UI().current
  local item
  for _, b in ipairs(s.items) do if b:IsVisible() and not item then item = b end end
  if item then firstHover("objet du marchand (butin)", item, { fixed = { item.tag } }) end
  firstHover("carte du marchand (étiquette de prix)", s.cards[1], { inside = true })
  firstHover("service du marchand", s.remove, { fixed = { s.remove.tag } })
  -- feu de camp : couchage (médaillon)
  freshRun(SEED + 3, "campfire")
  s = UI().current
  firstHover("couchage du feu de camp", s.rest, { fixed = { s.rest.tag } })
  -- rencontre : plaque de réponse
  freshRun(SEED + 4, "event")
  local live
  for _, o in ipairs(UI().step.options) do if not o.disabled and not live then live = o end end
  if live then firstHover("plaque de réponse", button(live.id)) end
  -- parcours : étape accessible (halo fixe : seule la taille est contrôlée)
  freshRun(SEED + 5, nil)
  local map = UI().screens.map
  local node
  for _, b in ipairs(map and map.nodes or {}) do
    if b:IsVisible() and b.node and b.node.state == "available" and not node then node = b end
  end
  if node then firstHover("étape du parcours", node, { staticGlow = true }) end
  check("aucune région créée sous un visuel en cours d'animation, sur tout le harnais", #H.bornInAnim == 0,
    table.concat(H.bornInAnim, ", "))
end

print("U24 réponses (bouton rouge, gain dessous) : toutes les réponses de Data/Events.lua dans leurs zones")
do
  freshRun(SEED + 4, "event")
  local ns = H.ns
  local s = UI().current
  local b = s.buttons[1]
  local O = UI().OPT
  local bad, dist, multi = {}, {}, {}
  local cases = 0
  local function lines(t)
    local out = {}
    for l in ((t or "") .. "\n"):gmatch("(.-)\n") do out[#out + 1] = l end
    return out
  end
  local function try(label, o, w, h)
    cases = cases + 1
    b:SetOption(o, w, h)
    local fit = b.optFit
    local why = {}
    if not fit.ok then why[#why + 1] = "ne tient à aucun palier" end
    -- libellé : une ligne dans le bouton (moins ses bouts, une marge et l'icône) ; texte sous le bouton,
    -- dans la largeur moins les marges, et dans la hauteur restante
    for _, it in ipairs({ { b.label, fit.lw }, { b.sub, fit.zw } }) do
      local fs, zw = it[1], it[2]
      if fs._shown and (fs._text or "") ~= "" then
        local ls = lines(fs._text)
        for _, l in ipairs(ls) do
          if H.textWidth(fs, l, fs._fontSize) > zw + 0.01 then why[#why + 1] = "« " .. l .. " » plus large que la zone" end
        end
        if fs:IsTruncated() or fs:GetNumLines() ~= #ls then why[#why + 1] = "recoupé par le client" end
      end
    end
    if #lines(b.label._text) ~= 1 then why[#why + 1] = "libellé sur plusieurs lignes" end
    if (b.label._fontSize or 0) < 10 then why[#why + 1] = "libellé trop petit" end
    if b.label._fontSize * H.metrics.lineHeight > O.btn - 8 then why[#why + 1] = "libellé plus haut que le bouton" end
    if b.sub._shown and fit.subH > fit.zh + 0.01 then why[#why + 1] = "texte plus haut que la place sous le bouton" end
    local cap = b.base.cap or 0
    if fit.lw > w - 2 * cap + 0.01 then why[#why + 1] = "zone du libellé sur les bouts du bouton" end
    if #why > 0 then bad[#bad + 1] = label .. " : " .. table.concat(why, ", ") end
    if b.sub._shown then
      local k = fit.sub .. " × " .. fit.subLines
      dist[k] = (dist[k] or 0) + 1
      if fit.subLines > 1 then multi[#multi + 1] = ("%s (%s)"):format(label, k) end
    end
  end
  -- raison affichée d'une réponse impossible : texte de sa première condition, ou d'un paiement
  local X = ns.Expedition
  local function reasonOf(ch)
    for _, c in ipairs(ch.when or {}) do
      local def = X.CONDITIONS[c[1]]
      if c.text then return c.text end
      if def and def.text then return def.text(c[2], c) end
    end
    for _, e in ipairs(ch.effects or {}) do
      if e[1] == "pay" then return X.EVENT_REASONS.gold or "Not enough gold." end
    end
    return "Requires at least 50% HP."
  end
  local ids = {}
  for id in pairs(ns.Events) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local ev = ns.Events[id]
    local n = math.min(#ev.choices, #s.buttons)
    local span = n <= 2 and 668 or (n == 3 and 900 or 980)
    local gap = n <= 2 and 28 or 22
    local w = (span - (n - 1) * gap) / math.max(n, 1)
    local h = n >= 4 and 112 or 118
    for i = 1, n do
      local ch = ev.choices[i]
      local text = ch.hidden and "?" or (ch.outcome or ch.text or "")
      try(id .. "/" .. i, { id = "x", label = ch.label, text = text }, w, h)
      try(id .. "/" .. i .. " (impossible)", { id = "x", label = ch.label, text = text, disabled = true,
        reason = reasonOf(ch) }, w, h)
    end
  end
  -- feu de camp (240 × 104)
  try("feu : se reposer", { id = "rest", label = "Rest", text = "+21 HP" }, 240, 104)
  try("feu : s'entraîner", { id = "u", label = "Train", text = "Upgrade a card" }, 240, 104)
  check(("%d rencontres (%d cas de réponse, possibles et impossibles) : libellé et texte dans la zone utile, marges de %d unités")
    :format(#ids, cases, O.mx), #bad == 0, table.concat(bad, "\n        "))
  local dl = {}
  for k, n in pairs(dist) do dl[#dl + 1] = k .. " : " .. n end
  table.sort(dl)
  print("      texte des réponses (taille × lignes) : " .. table.concat(dl, ", "))
  print("      sur plusieurs lignes : " .. (#multi > 0 and table.concat(multi, ", ") or "aucune"))
  -- la réponse de la capture : une coupure propre, loin des bords
  try("bandits", { id = "x", label = "Charge the bandits", text = "Fight: usual reward + 20g" }, 285.3, 118)
  local ls = lines(b.sub._text)
  local widest = 0
  for _, l in ipairs(ls) do widest = math.max(widest, H.textWidth(b.sub, l, b.sub._fontSize)) end
  check("« Fight: usual reward + 20g » : lignes équilibrées, au moins 16 unités des bords",
    widest <= 285.3 - 32 and (#ls == 1 or math.abs(H.textWidth(b.sub, ls[1], b.sub._fontSize)
      - H.textWidth(b.sub, ls[2], b.sub._fontSize)) < 0.4 * widest), b.sub._text)
end

print("U25 explications des mots-clés : une phrase courte par mot-clé")
do
  local Art = H.ns.Art
  local bad = {}
  for key in pairs(Art.keywords) do
    for _, n in ipairs({ false, 1, 4 }) do
      local line = Art.keywordLine(key, nil, n or nil):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      local len = H.ns.Widgets.utf8len(line)
      if len > 60 or line:find("[;()]") or select(2, line:gsub("%. ", "")) > 0 then
        bad[#bad + 1] = line .. " (" .. len .. ")"
      end
    end
  end
  check("chaque mot-clé : une ligne de 60 caractères au plus, une seule phrase, sans point-virgule ni parenthèse",
    #bad == 0, table.concat(bad, " | "))
end

print("U26 zoom fluide (repos identique, survol sans re-rasterisation, caché, vol) ; mode net sans saut ; abréviations")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  -- sauvegarde : « net » par défaut, valeurs choisies gardées, inconnues remises au défaut
  for _, z in ipairs({ "net", "fluide", "lisse", "anim", 3 }) do
    H.boot({ version = 1, options = { zoom = z } })
    local want = (z == "fluide" or z == "lisse") and z or "net"
    check("sauvegarde : zoom « " .. tostring(z) .. " » → « " .. want .. " »",
      H.ns.Persist.options().zoom == want and H.ns.Widgets.zoomMode() == want, H.ns.Persist.options().zoom)
  end
  H.boot(nil)
  check("défaut : zoom « net »", H.ns.Widgets.zoomMode() == "net" and H.ns.Persist.options().zoom == "net")

  -- expédition lancée avec le mode de zoom voulu dès la construction des écrans
  local Wd
  local function freshRunZ(seed, kind, zoom)
    H.boot(nil)
    Wd = H.ns.Widgets
    H.ns.Persist.options().zoom = zoom
    H.slash("")
    H.ns.Controller.makeSeed = function() return seed end
    clickOption("go")
    local e = EXP()
    if kind then
      local id = e.map.start[1]
      e.map.nodes[id].kind = kind
      e.gold = 500
      clickOption("path:" .. id)
    end
    H.advance(0.1)
    return e
  end
  local function regions(f, out)
    out = out or {}
    for _, k in ipairs(rawget(f, "_kids")) do
      local kind = rawget(k, "_kind")
      if kind == "Texture" or kind == "FontString" then
        if k:IsVisible() and (kind ~= "FontString" or (k._text or "") ~= "") then out[#out + 1] = k end
      elseif kind ~= "AnimationGroup" and kind ~= "Animation" and kind ~= "MaskTexture" then regions(k, out) end
    end
    return out
  end
  -- rectangles affichés de toutes les régions visibles des éléments (ordre de création stable)
  local function shot(list, regionsOnly)
    local out = {}
    for _, f in ipairs(list) do
      for _, t in ipairs(regions(f)) do
        local r = R.vrect(t, regionsOnly)
        if r then out[#out + 1] = { t = t, r = r } end
      end
    end
    return out
  end
  local function maxDiff(a, b)
    if #a ~= #b then return math.huge, "nombre de régions " .. #a .. " / " .. #b end
    local m, what = 0, nil
    for i = 1, #a do
      for k = 1, 4 do
        local d = math.abs(a[i].r[k] - b[i].r[k])
        if d > m then m, what = d, tostring(rawget(a[i].t, "_texture") or a[i].t._text or a[i].t._kind) end
      end
    end
    return m, what
  end
  local function step(n, dt)
    for _ = 1, n do
      run(Wd.driver, "OnUpdate", dt)
      H.now = H.now + dt
    end
  end
  local function vis(f) return f.face._scale * H.visualScale(f.face) end
  local function playing(f) local z = f.face._zoom return z ~= nil and z.ag:IsPlaying() end
  local function name(f) return tostring(f.cardId or (f.label and f.label._text) or "jeton") end

  -- 1. repos identique : mêmes rectangles affichés en net et en fluide (main, boutons, jetons d'état)
  freshRunZ(SEED, "combat", "net")
  H.settle()
  local v = V()
  -- une carte injouable (plaque de raison) dans la main, un jeton d'état
  local c2 = v.cards[2]
  c2:SetCard(c2.cardId, c2.cardUp, { playable = false, reason = "Not enough mana." })
  v.playerSt:Set({ { icon = H.ns.Art.ui.gold, key = "ui:gold", n = 3, info = { title = "Essai" } } })
  H.advance(0.1)
  local list = {}
  for i = 1, #C().combat().hand do list[#list + 1] = v.cards[i] end
  list[#list + 1] = v.endTurn
  list[#list + 1] = UI().gear
  list[#list + 1] = v.playerSt.tokens[1]
  local restNet = shot(list)
  Wd.setZoomMode("fluide")
  H.advance(0.1)
  local restFluid = shot(list)
  local armed, bad = 0, {}
  for _, f in ipairs(list) do
    local hs = f.hoverScale
    if f.face._scale == hs and playing(f) and math.abs(H.visualScale(f.face) - 1 / hs) < 1e-9 then armed = armed + 1
    else bad[#bad + 1] = name(f) end
  end
  check(("fluide au repos : %d éléments, échelle réelle = échelle de survol, animation tenue à 1 / échelle"):format(#list),
    armed == #list, table.concat(bad, ", "))
  local d, what = maxDiff(restNet, restFluid)
  check(("fluide au repos : %d régions affichées aux mêmes rectangles qu'en net (±0,01)"):format(#restNet), d <= 0.01,
    string.format("%.4f %s", d, tostring(what)))

  -- 2. survol en fluide : ni SetScale ni Stop, taille animée, arrivée = rectangles du net agrandi
  local card = v.cards[1]
  local face = card.face
  local hs = card.hoverScale
  local n0s = face._nSetScale or 0
  card.hover = true
  v:PlaceCard(card)
  local last, jump, steps = vis(card), 0, 0
  while (Wd.animValue(card, "hover") < 1 or steps < 2) and steps < 100 do
    step(1, 0.016)
    steps = steps + 1
    local s = vis(card)
    jump = math.max(jump, math.abs(s - last))
    last = s
  end
  step(5, 0.016)
  check("fluide, survol : aucune re-rasterisation (SetScale) ni bascule pendant et après le mouvement",
    (face._nSetScale or 0) == n0s and playing(card) and face._scale == hs, (face._nSetScale or 0) - n0s)
  check("fluide, survol : taille croissante sans à-coup, arrivée à l'échelle de survol (facteur tenu 1)",
    math.abs(vis(card) - hs) < 1e-9 and jump < 0.05, vis(card) .. " / saut " .. jump)
  local hoverFluid = shot({ card })
  -- sortie
  card.hover = false
  v:PlaceCard(card)
  step(40, 0.016)
  check("fluide, sortie : retour au facteur 1 / échelle, échelle réelle inchangée, animation tenue",
    face._scale == hs and playing(card) and math.abs(H.visualScale(face) - 1 / hs) < 1e-9 and (face._nSetScale or 0) == n0s)
  local d2 = maxDiff(shot(list), restFluid)
  check("fluide, sortie terminée : rectangles de repos retrouvés (±0,01)", d2 <= 0.01, d2)
  -- cible qui change en route : la taille repart de là où elle est
  local eb = v.endTurn
  run(eb, "OnEnter")
  step(3, 0.016)
  local before = vis(eb)
  run(eb, "OnLeave")
  local after = vis(eb)
  step(1, 0.016)
  check("fluide, cible changée en route : aucun saut de taille, animation relancée du facteur courant",
    math.abs(after - before) < 1e-9 and vis(eb) <= before + 1e-9 and before > 1 and playing(eb)
    and eb.face._scale == eb.hoverScale, before .. " / " .. after .. " / " .. vis(eb))
  step(40, 0.016)
  -- même agrandissement que le mode net à l'arrivée
  Wd.setZoomMode("net")
  H.advance(0.1)
  card.hover = true
  v:PlaceCard(card)
  H.advance(0.5)
  local d3, w3 = maxDiff(shot({ card }), hoverFluid)
  check("fluide, carte agrandie : mêmes rectangles qu'en net à l'arrivée (±0,01)", d3 <= 0.01,
    string.format("%.4f %s", d3, tostring(w3)))
  card.hover = false
  v:PlaceCard(card)
  H.advance(0.5)
  Wd.setZoomMode("fluide")
  H.advance(0.1)

  -- 3. caché puis remontré : animation arrêtée par le client, état reposé à l'OnShow (avant toute image)
  UI().frame:Hide()
  check("fenêtre cachée : animations arrêtées (comme dans le jeu)", not playing(card))
  UI().frame:Show()
  check("fenêtre remontrée : animation tenue reposée dans l'OnShow même, taille de repos", playing(card)
    and math.abs(vis(card) - 1) < 1e-9)
  H.advance(0.2)
  -- (l'écran s'est redessiné à l'ouverture : comparaison avec le même écran en net)
  local again = shot(list)
  Wd.setZoomMode("net")
  H.advance(0.1)
  local d4, w4 = maxDiff(again, shot(list))
  check(("fenêtre remontrée : %d régions aux rectangles de repos du mode net (±0,01)"):format(#again), d4 <= 0.01,
    tostring(d4) .. " " .. tostring(w4))
  Wd.setZoomMode("fluide")
  H.advance(0.1)
  -- caché en plein survol, remontré : taille entre repos et survol, jamais démesurée
  run(eb, "OnEnter")
  step(2, 0.016)
  eb:Hide()
  eb:Show()
  check("caché en plein survol puis remontré : taille entre repos et survol", vis(eb) >= 1 - 1e-9
    and vis(eb) <= eb.hoverScale + 1e-9 and playing(eb), vis(eb))
  run(eb, "OnLeave")
  H.advance(0.5)
  -- cadre jamais montré : carte créée sous un parent caché, puis montrée
  local holder = CreateFrame("Frame", nil, UI().content)
  holder:SetSize(10, 10)
  holder:SetPoint("TOPLEFT", UI().content, "TOPLEFT", 0, 0)
  local fresh = Wd.card(holder)
  fresh:SetCard("smite", false, { playable = true })
  check("carte neuve (pas encore armée) : repos sans animation, échelle réelle 1", fresh.face._scale == 1
    and not playing(fresh))
  holder:Hide()
  local nc = Wd.card(holder)
  nc:SetCard("smite", false, { playable = true })
  H.advance(0.1)
  check("carte jamais montrée : aucune animation sur un cadre caché", not playing(nc))
  holder:Show()
  check("carte montrée pour la première fois : état reposé avant la première image (taille de repos)",
    math.abs(vis(nc) - 1) < 1e-9 and playing(nc) and math.abs(vis(fresh) - 1) < 1e-9, vis(nc))
  -- création tardive sous un visuel armé (plaques de raison et de prix) : rien né pendant l'animation
  local nb = #H.bornInAnim
  nc:SetCard("smite", false, { playable = false, reason = "Not enough mana." })
  nc:SetCard("smite", false, { price = 50 })
  check("plaques créées après l'armement (raison, prix) : hors animation (W.faceBuild), animation reprise",
    #H.bornInAnim == nb and playing(nc) and math.abs(vis(nc) - 1) < 1e-9, table.concat(H.bornInAnim, ", ", nb + 1))
  holder:Hide()

  -- 4. vols de cartes en fluide
  local g = Wd.ghostCard(v.parent)
  g:SetCard(card.cardId, card.cardUp, card.opts)
  local landed = false
  Wd.fly(g, v.parent, 100, 400, 500, 300, 0.3, 1, 0.6, 1, 0.28, function() landed = true end)
  local ghs = g.hoverScale
  local start = g._scale * vis(g)
  H.now = H.now + 0.1
  local mid = g._scale * vis(g)
  local nS = g._nSetScale or 0
  H.advance(0.5)
  check("vol (pioche, 0,3 → 1) : échelle réelle fixe 1, visuel à son échelle de survol, taille animée de 0,3 à 1",
    landed and g._scale == 1 and g.face._scale == ghs and math.abs(start - 0.3) < 1e-6 and mid > 0.3 and mid < 1
    and math.abs(g._scale * vis(g) - 1) < 1e-9 and playing(g), start .. " / " .. mid)
  check("vol (pioche) : à l'atterrissage, aucune nouvelle échelle réelle, état de repos exact", (g._nSetScale or 0) == nS
    and math.abs(H.visualScale(g.face) - 1 / ghs) < 1e-9)
  Wd.releaseGhost(g)
  g = Wd.ghostCard(v.parent)
  g:SetCard(card.cardId, card.cardUp, card.opts)
  landed = false
  Wd.fly(g, v.parent, 500, 300, 100, 400, 1.16, 0.35, 1, 0.1, 0.38, function() landed = true end)
  start = g._scale * vis(g)
  H.advance(0.6)
  check("vol (vers la cible, 1,16 → 0,35) : polices à la plus grande échelle du vol, état de repos à l'arrivée",
    landed and math.abs(start - 1.16) < 1e-6 and g._scale == 0.35 and math.abs(H.visualScale(g.face) - 1 / ghs) < 1e-9, start)
  Wd.releaseGhost(g)

  -- 5. écrans construits en fluide : aucune région créée sous un visuel animé
  local nb2 = #H.bornInAnim
  for i, kind in ipairs({ "merchant", "campfire", "event", "combat" }) do
    freshRunZ(SEED + i, kind, "fluide")
    local s = UI().current
    for _, b in ipairs(s and (s.cards or s.items or s.buttons) or {}) do
      if b.IsVisible and b:IsVisible() and b._hoverable then run(b, "OnEnter") H.advance(0.3) run(b, "OnLeave") H.advance(0.3) end
    end
  end
  freshRunZ(SEED, "combat", "fluide")
  H.settle()
  fightUntil(function() return C().over() ~= nil end, 200)
  H.advance(2)
  check("fluide : marchand, feu, rencontre, combat jusqu'au bout, sans région créée sous une animation",
    #H.bornInAnim == nb2, table.concat(H.bornInAnim, ", ", nb2 + 1))

  -- 6. mode net : aucun saut à la bascule. Hypothèse prudente du rendu : une animation Scale ne porte
  -- que sur les régions du cadre animé (un cadre enfant du visuel ne grossirait qu'à la bascule).
  freshRunZ(SEED, "combat", "net")
  H.settle()
  v = V()
  c2 = v.cards[2]
  c2:SetCard(c2.cardId, c2.cardUp, { playable = false, reason = "Not enough mana." })
  v.playerSt:Set({ { icon = H.ns.Art.ui.gold, key = "ui:gold", n = 3, info = { title = "Essai" } } })
  H.advance(0.1)
  local worst, label = 0, nil
  local childFrames = {}
  for _, f in ipairs({ v.cards[1], c2, v.endTurn, UI().gear, v.playerSt.tokens[1] }) do
    for _, k in ipairs(rawget(f.face, "_kids")) do
      if KINDS[rawget(k, "_kind")] and k:IsVisible() and #regions(k) > 0 then childFrames[#childFrames + 1] = name(f) end
    end
    if f._hoverManual then f.hover = true v:PlaceCard(f) else run(f, "OnEnter") end
    -- pas de la bascule comparé au pas d'avant : la bascule n'ajoute aucun déplacement au mouvement
    local prev = shot({ f }, true)
    local dPrev, dSwitch, wSwitch = 0, nil, nil
    for _ = 1, 200 do
      local sc0 = f.face._scale
      run(Wd.driver, "OnUpdate", 0.004)
      H.now = H.now + 0.004
      local cur = shot({ f }, true)
      local dd, w = maxDiff(prev, cur)
      if f.face._scale ~= sc0 then dSwitch, wSwitch = dd, w break end
      dPrev = dd
      prev = cur
    end
    if f._hoverManual then f.hover = false v:PlaceCard(f) else run(f, "OnLeave") end
    H.advance(0.5)
    print(("      %s : %d régions, pas avant la bascule %.3f, pas de la bascule %s"):format(name(f), #prev, dPrev,
      dSwitch and string.format("%.3f", dSwitch) or "ABSENT"))
    local extra = dSwitch and (dSwitch - dPrev) or math.huge
    if extra > worst then worst, label = extra, name(f) .. " : " .. tostring(wSwitch) end
  end
  check("net : aucun cadre enfant dessiné sous un visuel survolable (carte, plaques, bouton, jeton)", #childFrames == 0,
    table.concat(childFrames, ", "))
  check(("net, survol image par image (4 ms) : la bascule n'ajoute aucun déplacement (au plus %.3f unité de plus que le pas d'avant)")
    :format(worst), worst < 0.05, label)

  -- 7. carte survolée de la main : dans la fenêtre, sans recouvrir les ennemis (noms, jauges, états) ;
  -- toutes les places de la main, carte injouable comprise (plaque de raison), pour chaque taille de main
  do
    local content = R.rect(UI().content)
    local enemyRects = {}
    for _, sl in ipairs(v.slots) do
      if sl:IsVisible() then
        for kn, k in pairs({ nom = sl.tag, jauge = sl.hp, etats = sl.st }) do
          if k and k:IsVisible() then
            for _, t in ipairs(regions(k)) do local r = R.rect(t) r.what = kn enemyRects[#enemyRects + 1] = r end
          end
        end
      end
    end
    local outW, overE, lowest, highest = {}, {}, math.huge, -math.huge
    local cases = {}
    for i = 1, #C().combat().hand do
      cases[#cases + 1] = { i, { playable = true } }
      cases[#cases + 1] = { i, { playable = false, reason = "Not enough mana." } }
    end
    local card1 = v.cards[1]
    for _, cs in ipairs(cases) do
      card1 = v.cards[cs[1]]
      local opts = cs[2]
      card1:SetCard("penance", false, opts)
      card1.hover = true
      v:PlaceCard(card1)
      H.advance(0.5)
      local box = { math.huge, math.huge, -math.huge, -math.huge }
      for _, t in ipairs(regions(card1)) do
        if not (t == card1.halo) then
          local r = R.vrect(t)
          box = { math.min(box[1], r[1]), math.min(box[2], r[2]), math.max(box[3], r[3]), math.max(box[4], r[4]) }
        end
      end
      lowest, highest = math.min(lowest, box[2]), math.max(highest, box[4])
      if box[2] < content[2] - 0.01 or box[4] > content[4] + 0.01 then outW[#outW + 1] = tostring(opts.playable) end
      for _, er in ipairs(enemyRects) do
        if box[1] < er[3] and box[3] > er[1] and box[2] < er[4] and box[4] > er[2] then
          overE[#overE + 1] = ("carte %d (%s, %.1f)"):format(cs[1], er.what, er[2] - box[4] < 0 and box[4] - er[2] or 0) break
        end
      end
      card1.hover = false
      v:PlaceCard(card1)
      H.advance(0.5)
    end
    print(("      main : carte survolée ×%.2f, du haut %.1f au bas %.1f (fenêtre %.1f à %.1f ; bas de l'ennemi le plus bas %.1f)")
      :format(card1.hoverScale, content[4] - highest, content[4] - lowest, 0, content[4] - content[2],
        (function() local m = -math.huge for _, er in ipairs(enemyRects) do m = math.max(m, content[4] - er[2]) end return m end)()))
    -- (relevé : avec ×1,16 et HOVER_TOP 372, la carte survolée au milieu de la main mord déjà de quelques
    -- unités sur le bas des infos d'un ennemi quand il en a ; d'où l'échelle de survol laissée telle quelle)
    print("      main : recouvrement des infos d'ennemis (unités d'écran) : "
      .. (#overE > 0 and table.concat(overE, ", ") or "aucun"))
    check("main : carte survolée (halo exclu) dans la fenêtre, à toutes les places, injouable comprise", #outW == 0,
      table.concat(outW, ", "))
  end

  -- 8. noms abrégés : en anglais, « Power Word: Radiance » ne tient pas au palier 9 (relevé du
  -- harnais : 8, et 7 améliorée) ; toutes les cartes « Power Word » et « Shadow Word » sont donc
  -- abrégées de la même façon (« PW: », « SW: »)
  local long = {}
  for _, dd in pairs(H.ns.Cards) do
    if dd.name:find("Power Word", 1, true) or dd.name:find("Shadow Word", 1, true) then long[#long + 1] = dd.name end
  end
  check("noms abrégés : plus de « Power Word » ni « Shadow Word » (PW:, SW:)", #long == 0
    and H.ns.Cards.pw_shield.name == "PW: Shield" and H.ns.Cards.sw_pain.name == "SW: Pain"
    and H.ns.Card.defById("sw_death", true).name:find("^SW: Death") ~= nil, table.concat(long, ", "))
end

print("U27 langage des cartes : mots-clés, états posés (Gain / Apply), sablier, explications, Pouvoirs")
do
  freshRun(SEED, "combat")
  H.settle()
  local ns = H.ns
  local W, Art, Card = ns.Widgets, ns.Art, ns.Card
  local HG = W.HOURGLASS_CHAR
  local ids = {}
  for id in pairs(ns.Cards) do ids[#ids + 1] = id end
  table.sort(ids)
  local function plain(t)
    return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", HG))
  end
  local function clauses(t)
    local out = {}
    for l in (t .. "\n"):gmatch("(.-)\n") do if l ~= "" then out[#out + 1] = l end end
    return out
  end
  local PLATE = { "^Cooldown %d+%.$", "^Exhaust%.$", "^Retain%.$", "^Cast%.$", "^Power%.$" }
  local function isPlate(cl) for _, p in ipairs(PLATE) do if cl:find(p) then return true end end return false end
  -- ligne d'état : « Apply … », ou « Gain » suivi d'un nom (« Gain 5 Absorb. » est un effet)
  local function isStateCl(cl)
    return cl:find("^Apply ") ~= nil or (cl:find("^Gain %a") ~= nil and cl:find("^Gain %d") == nil)
  end
  -- 1. forme des textes, cohérence texte <-> effets
  local bad, nState = {}, 0
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      local d = Card.defById(id, up)
      local label = id .. (up and "+" or "")
      local cls = clauses(d.text or "")
      -- états posés par les effets (un état qui porte le nom de la carte est décrit, pas nommé)
      local want = {}
      for _, e in ipairs(d.effects or {}) do
        if e[1] == "apply" and ns.Statuses[e[2]] and ns.Statuses[e[2]].name ~= ns.Cards[id].name then
          local s = ns.Statuses[e[2]]
          want[#want + 1] = { id = e[2], n = e[3], self = e.self, all = e.all, name = s.name }
        end
      end
      -- clauses d'état : en dernier (avant les seuls mots de la plaque), une par état, dans l'ordre
      local states, seenState, afterState = {}, false, false
      for _, cl in ipairs(cls) do
        local isState = isStateCl(cl)
        if isState then states[#states + 1] = cl seenState = true
        elseif seenState and not isPlate(cl) then afterState = true end
        if cl:find("^Cast%.$") or cl:find("^Power%.$") then
          if cl ~= cls[1] then bad[#bad + 1] = label .. " : « " .. cl .. " » pas en tête" end
        end
      end
      if afterState then bad[#bad + 1] = label .. " : une clause suit les états posés" end
      if #states ~= #want then
        bad[#bad + 1] = ("%s : %d état(s) posé(s) par les effets, %d ligne(s) Gain / Apply"):format(label, #want, #states)
      else
        -- ordre : ennemis (« Apply ») d'abord, puis soi (« Gain »)
        table.sort(want, function(a, b) return (a.self and 1 or 0) < (b.self and 1 or 0) end)
        for k, w in ipairs(want) do
          local cl = states[k]
          local verb = w.self and "Gain" or "Apply"
          local expect = verb .. " " .. w.name .. " " .. tostring(w.n)
            .. (W.isTurnStatus(w.id) and (" " .. HG) or "") .. (w.all and " to all" or "")
          nState = nState + 1
          if cl ~= expect then bad[#bad + 1] = ("%s : « %s » au lieu de « %s »"):format(label, cl, expect) end
        end
      end
      -- sablier : seulement dans une ligne d'état, seulement pour une durée ; jamais « N turn(s) »
      for _, cl in ipairs(cls) do
        local isState = isStateCl(cl)
        if cl:find(HG, 1, true) and not isState then bad[#bad + 1] = label .. " : sablier hors d'une ligne d'état" end
        if isState then
          if cl:find("%.$") then bad[#bad + 1] = label .. " : ligne d'état terminée par un point" end
          local name = cl:match("^%S+ (.-) %d")
          for sid, s in pairs(ns.Statuses) do
            if s.name == name and (cl:find(HG, 1, true) ~= nil) ~= W.isTurnStatus(sid) then
              bad[#bad + 1] = label .. " : sablier " .. (W.isTurnStatus(sid) and "manquant" or "en trop") .. " (" .. name .. ")"
            end
          end
        end
        if cl:find("%d+ turns?") then bad[#bad + 1] = label .. " : « N turn(s) » au lieu du sablier" end
        -- « Deal » réservé aux dégâts
        for _, s in pairs(ns.Statuses) do
          if cl:find("[Dd]eal " .. s.name, 1, false) then bad[#bad + 1] = label .. " : « Deal » pour un état" end
        end
        -- impersonnel
        local low = " " .. cl:lower():gsub("[%p]", " ") .. " "
        for _, w in ipairs({ "you", "your", "yours", "yourself" }) do
          if low:find(" " .. w .. " ", 1, true) then bad[#bad + 1] = label .. " : « " .. w .. " »" end
        end
        -- « Name: » = état ou condition nommée (ou libellé sans majuscule de mot-clé)
        local lab = cl:match("^(.-): ")
        if lab and lab:find("^%u") then
          local known = false
          for _, k in ipairs(W.keywordList()) do if k.name == lab then known = true end end
          -- libellés qui ne sont pas des conditions (cible d'un Pouvoir) : liste fermée
          local NOT_COND = { ["Cast cards"] = true, ["Each Absorb gain"] = true }
          if not known and not NOT_COND[lab] then bad[#bad + 1] = label .. " : condition inconnue « " .. lab .. " »" end
        end
      end
    end
  end
  check(("textes : %d états posés, chacun sur sa ligne « Gain » (soi) / « Apply » (ennemi) en dernier, sablier seulement pour une durée, impersonnels")
    :format(nState), #bad == 0, table.concat(bad, "\n        "))
  -- conditions vérifiables depuis les données : Exécution (bonus d'exécution), Déferlement (dépense
  -- de la Démence : la carte ne se joue qu'avec de la Démence), Dernier souffle (empêche la mort),
  -- Ombre (Pouvoir d'ombre)
  local cbad = {}
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      local d = Card.defById(id, up)
      local t = d.text or ""
      local function has(n) return W.hasPhrase(t, n .. ":") end
      if has("Execute") ~= (d.executeBonus ~= nil) then cbad[#cbad + 1] = id .. " : Execute" end
      if has("Surge") ~= (d.canPlay ~= nil) then cbad[#cbad + 1] = id .. " : Surge" end
      if has("Last Breath") ~= (d.hooks ~= nil and d.hooks.preventDeath ~= nil) then cbad[#cbad + 1] = id .. " : Last Breath" end
      if has("Shadow") ~= (d.power == true and d.school == "shadow") then cbad[#cbad + 1] = id .. " : Shadow" end
      -- chiffres d'Exécution et de Déferlement
      if d.executeBonus then
        local base = d.effects[1][2]
        if not t:find("Deal " .. base .. "%.") or not t:find("Execute: deal " .. (base + d.executeBonus) .. "%.") then
          cbad[#cbad + 1] = id .. (up and "+" or "") .. " : chiffres d'Execute"
        end
      end
      if d.perDemence and not t:find("per Insanity", 1, true) then cbad[#cbad + 1] = id .. " : Surge chiffré" end
      if d.perDemence and not t:find("+ " .. d.perDemence .. " per Insanity", 1, true) then cbad[#cbad + 1] = id .. (up and "+" or "") .. " : Surge chiffré" end
      if d.plagueMult and not t:find("apply Pain " .. d.plagueMult .. " per Insanity", 1, true) then
        cbad[#cbad + 1] = id .. (up and "+" or "") .. " : Peste chiffrée"
      end
    end
  end
  check("conditions nommées présentes exactement sur les cartes qui les ont (Execute, Surge, Last Breath, Shadow), chiffres justes",
    #cbad == 0, table.concat(cbad, ", "))
  -- 2. mise en page : la ligne d'état commence une ligne et finit le texte ; une clause par ligne aux
  -- paliers >= 8,5 ; sablier en icône |T dans le texte posé, compté dans la mesure
  local card = W.card(UI().content)
  local lbad, nIcons = {}, 0
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      card:SetCard(id, up, { playable = true })
      local d = Card.defById(id, up)
      local label = id .. (up and "+" or "")
      local fit = card.bodyFit
      local lines = clauses(card.body._text or "")
      local pl = {}
      for k, l in ipairs(lines) do pl[k] = plain(l) end
      local cls = {}
      for _, cl in ipairs(clauses(d.text or "")) do if not isPlate(cl) then cls[#cls + 1] = cl end end
      -- première ligne d'état : en début de ligne ; plus rien après la dernière
      local firstState
      for _, cl in ipairs(cls) do if isStateCl(cl) then firstState = cl break end end
      if firstState then
        -- verbe puis nom (« Gain Atonement », « Apply Pain »), le verbe seul en fin de ligne possible
        -- (« Apply » / « Stunned 1 ⌛ ») ; « Gain 4 Absorb. » ne compte pas
        local verb, name1 = firstState:match("^(%S+) (%S+)")
        local startLine
        for k, l in ipairs(pl) do
          local lp = l:gsub("\194\160", " ")
          local nx = (pl[k + 1] or ""):gsub("\194\160", " ")
          if lp:sub(1, #verb + #name1 + 1) == verb .. " " .. name1
            or (lp == verb and nx:sub(1, #name1) == name1) then startLine = k break end
        end
        if not startLine then lbad[#lbad + 1] = label .. " : la ligne d'état ne commence pas une ligne" end
        local lastCl = cls[#cls]:gsub(" " .. HG, HG)
        local tail = pl[#pl]
        if lastCl:sub(-#tail) ~= tail then lbad[#lbad + 1] = label .. " : texte après la ligne d'état (« " .. tail .. " »)" end
      end
      -- une clause par ligne : chaque clause commence une ligne
      if fit.mode == "clauses" then
        for _, cl in ipairs(cls) do
          local head = plain(cl):match("^%S+")
          local found = false
          for _, l in ipairs(pl) do if l:sub(1, #head) == head then found = true end end
          if not found then lbad[#lbad + 1] = label .. " : clause « " .. cl .. " » au milieu d'une ligne" end
        end
      end
      -- ordre des essais : une clause par ligne à tous les paliers >= 8,5 avant tout texte coulé
      local tries, flowed = W.cardTries(W.cardBody(d)), false
      for _, t in ipairs(tries) do
        if t.mode ~= "clauses" then flowed = true
        elseif flowed and t.size >= W.CLAUSE_MIN then lbad[#lbad + 1] = label .. " : essai coulé avant une clause par ligne à " .. t.size end
      end
      -- sablier : présent en icône dans le texte posé, autant que de « ⌛ » dans la source
      local nSrc = select(2, (d.text or ""):gsub(HG, ""))
      local nTex = select(2, (card.body._text or ""):gsub("|T[^|]*hourglass%.tga[^|]*|t", ""))
      nIcons = nIcons + nTex
      if nSrc ~= nTex or (card.body._text or ""):find(HG, 1, true) then
        lbad[#lbad + 1] = ("%s : %d sablier(s) dans le texte, %d icône(s) posée(s)"):format(label, nSrc, nTex)
      end
    end
  end
  check(("mise en page : états posés en début de ligne et en dernier, une clause par ligne en mode « clauses », %d sabliers en icône |T"):format(nIcons),
    #lbad == 0, table.concat(lbad, "\n        "))
  -- l'icône est comptée dans la mesure (faux client comme le client : largeur de la séquence |T)
  local m = W.label(UI().content, "bold", 9)
  m:SetText("Atonement 1")
  local w0 = m:GetStringWidth()
  local hgt, wid = W.hourglassSize(9)
  m:SetText("Atonement 1" .. W.hourglass(9))
  local w1 = m:GetStringWidth()
  check(("sablier compté dans la mesure du texte (+%.1f unités à la taille 9, hauteur %d)"):format(w1 - w0, hgt),
    math.abs(w1 - w0 - wid) < 1e-6 and hgt >= 5 and wid >= 4, w1 - w0)
  -- séquence |T : forme de CreateTextureMarkup (chemin:hauteur:largeur:x:y:largeur et hauteur du
  -- fichier:gauche:droite:haut:bas) + couleur r:g:b, entiers, fichier de Media/ présent (TGA 32 bits,
  -- puissance de deux, blanc)
  local mk = W.hourglass(8.5)
  local f = {}
  for v in (mk:match("^|T(.-)|t$") .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
  local allInt = #f == 14
  for k = 2, 14 do if not (f[k] or ""):match("^%d+$") then allInt = false end end
  local tga = io.open(root .. "/Media/hourglass.tga", "rb")
  local hdr = tga and tga:read(18)
  local body = tga and tga:read("*a")
  if tga then tga:close() end
  local white = body and #body == 32 * 32 * 4
  if white then
    for i = 1, #body, 4 do
      if body:byte(i) ~= 255 or body:byte(i + 1) ~= 255 or body:byte(i + 2) ~= 255 then white = false break end
    end
  end
  check("séquence |T du sablier : 14 champs entiers, Media/hourglass.tga 32 × 32 TGA 32 bits, blanc (teinté par la séquence)",
    allInt and f[1] == W.HOURGLASS and hdr and hdr:byte(3) == 2 and hdr:byte(17) == 32
      and hdr:byte(13) + 256 * hdr:byte(14) == 32 and hdr:byte(15) + 256 * hdr:byte(16) == 32 and white, mk)
  -- mots-clés en couleur d'accent (une seule), chiffres blancs / verts : rien d'autre en couleur
  local colors, cbad2 = {}, {}
  local accent = "|cff" .. W.hexOf(W.KEYWORD_COLOR)
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      local txt = W.cardBody(Card.defById(id, up), up and ns.Cards[id] or nil)
      for code, word in txt:gmatch("(|c%x%x%x%x%x%x%x%x)(.-)|r") do
        colors[code] = true
        if code == accent then
          local ok = false
          for _, k in ipairs(W.keywordList()) do if word == k.name then ok = true end end
          if not ok then cbad2[#cbad2 + 1] = id .. " : « " .. word .. " » en couleur d'accent" end
        elseif not word:match("^%d+$") then
          cbad2[#cbad2 + 1] = id .. " : « " .. word .. " » coloré"
        end
      end
    end
  end
  local nColors = 0
  for _ in pairs(colors) do nColors = nColors + 1 end
  check(("couleurs du texte : noms d'états et conditions en %s, chiffres blancs ou verts (%d couleurs)"):format(accent, nColors),
    #cbad2 == 0 and nColors <= 3 and colors[accent], table.concat(cbad2, ", "))
  -- 3. explications au survol : chaque mot-clé employé a sa ligne, 60 caractères au plus, une phrase
  local ebad, nLines = {}, 0
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      local d = Card.defById(id, up)
      local label = id .. (up and "+" or "")
      local tt = { lines = {} }
      function tt:AddLine(t) self.lines[#self.lines + 1] = t end
      function tt:NumLines() return #self.lines end
      W.fillCardTooltip(tt, id, up)
      local all = plain(table.concat(tt.lines, "\n"))
      local t = d.text or ""
      local function need(what, line)
        if not all:find(line, 1, true) then ebad[#ebad + 1] = label .. " : pas d'explication pour " .. what end
      end
      for _, c in ipairs(W.CONDITIONS) do
        if W.hasPhrase(t, c.name .. ":") then need(c.name, c.name .. ": ") end
      end
      for sid, s in pairs(ns.Statuses) do
        if W.hasPhrase(t, s.name) then need(s.name, s.name .. ": ") end
        if W.hasPhrase(t, s.name .. ":") then need(s.name .. " (condition)", s.name .. ": bonus effect") end
      end
      for _, e in ipairs(d.effects or {}) do
        if e[1] == "apply" then need(ns.Statuses[e[2]].name, ns.Statuses[e[2]].name .. ": ") end
      end
      if t:find(HG, 1, true) then need("le sablier", HG .. ": ") end
      if W.hasPhrase(t, "Absorb") then need("Absorb", "Absorb: ") end
      if W.hasPhrase(t, "Insanity") then need("Insanity", "Insanity: ") end
      for _, l in ipairs(tt.lines) do
        local p = plain(l)
        if p ~= " " then
          nLines = nLines + 1
          local len = W.utf8len(p)
          if len > 60 or p:find("[;()]") or select(2, p:gsub("%. ", "")) > 0 then
            ebad[#ebad + 1] = label .. " : « " .. p .. " » (" .. len .. ")"
          end
        end
      end
    end
  end
  check(("explications : chaque mot-clé, état et condition des textes expliqué, %d lignes de 60 caractères au plus"):format(nLines),
    #ebad == 0, table.concat(ebad, "\n        "))
  -- explications des nouveaux mots-clés : présentes, une phrase courte
  local kbad = {}
  for _, k in ipairs({ "execute", "surge", "lastBreath", "shadow", "turns" }) do
    local l = Art.keywords[k] and plain(Art.keywordLine(k)) or ""
    if l == "" or W.utf8len(l) > 60 then kbad[#kbad + 1] = k end
  end
  for sid in pairs(Art.statusShort) do
    if not ns.Statuses[sid] or W.utf8len(plain(Art.statusLine(sid))) > 60 then kbad[#kbad + 1] = "état " .. sid end
  end
  check("Execute, Surge, Last Breath, Shadow, sablier et définitions courtes des états : une ligne de 60 caractères au plus",
    #kbad == 0, table.concat(kbad, ", "))
  -- 4. Pouvoir joué : jeton sous le personnage (icône de la carte, liseré doré), effet au survol ;
  -- l'état sérialisé ne change pas (la liste des pouvoirs existait déjà)
  local c = C().combat()
  local v = V()
  local before = #c.player.powers
  local pbad = {}
  for _, pid in ipairs({ "shadowform", "rapture", "spirit_of_redemption", "apotheosis" }) do
    c.player.powers[#c.player.powers + 1] = { uid = 9000 + #c.player.powers, id = pid, up = pid == "rapture" }
    v:Render(true)
    local tok
    for _, t in ipairs(v.playerSt.tokens) do
      if t._shown and t.info and t.info.power and t.info.power.id == pid then tok = t end
    end
    if not tok then
      pbad[#pbad + 1] = pid .. " : pas de jeton"
    else
      local lines = H.hover(tok)
      local all = plain(table.concat(lines, "\n"))
      local d = Card.defById(pid, pid == "rapture")
      local first = plain(W.cardTextLines(d)[1] or "")
      if not all:find(d.name, 1, true) or not all:find(first, 1, true) or not all:find("Power: ", 1, true) then
        pbad[#pbad + 1] = pid .. " : infobulle « " .. all:gsub("\n", " / ") .. " »"
      end
      if all:find("Power.", 1, true) then pbad[#pbad + 1] = pid .. " : « Power. » dans le texte de l'infobulle" end
      local tex = tok.medal.icon._texture
      if tex == nil then pbad[#pbad + 1] = pid .. " : jeton sans icône" end
    end
  end
  for i = #c.player.powers, before + 1, -1 do c.player.powers[i] = nil end
  v:Render(true)
  check("Pouvoirs joués (Forme d'ombre, Extase+, Esprit de rédemption, Apothéose) : jeton sous le personnage, icône de la carte, nom, texte et mots-clés au survol",
    #pbad == 0, table.concat(pbad, "\n        "))
  card:Hide()
  m:Hide()
end

print("U28 ombres de contact : une par personnage affiché, sous les pieds, texture fondue sur disque, mort")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  freshRun(SEED, "combat")
  H.settle()
  local ns = H.ns
  local Sc = ns.Scene
  -- texture : Media/shadow_soft.tga, TGA 32 bits non compressé 128 × 128, blanche, alpha nul sur tout
  -- le bord, plein au centre, décroissant du centre vers le bord
  local f = io.open(root .. "/Media/shadow_soft.tga", "rb")
  local hdr = f and f:read(18)
  local body = f and f:read("*a")
  if f then f:close() end
  local N = 128
  local okTex = Sc.SHADOW == "Interface\\AddOns\\SlayTheDragon\\Media\\shadow_soft.tga" and hdr ~= nil
    and hdr:byte(3) == 2 and hdr:byte(17) == 32 and hdr:byte(18) == 8
    and hdr:byte(13) + 256 * hdr:byte(14) == N and hdr:byte(15) + 256 * hdr:byte(16) == N
    and body ~= nil and #body == N * N * 4
  local why
  if okTex then
    local function px(x, y) local i = (y * N + x) * 4 return body:byte(i + 1), body:byte(i + 2), body:byte(i + 3), body:byte(i + 4) end
    for i = 0, N * N - 1 do
      local b, g, r = body:byte(i * 4 + 1), body:byte(i * 4 + 2), body:byte(i * 4 + 3)
      if b ~= 255 or g ~= 255 or r ~= 255 then why = "pixel non blanc" break end
    end
    for k = 0, N - 1 do
      if select(4, px(k, 0)) ~= 0 or select(4, px(k, N - 1)) ~= 0 or select(4, px(0, k)) ~= 0
        or select(4, px(N - 1, k)) ~= 0 then why = "bord non transparent" break end
    end
    local prev = 256
    for x = N / 2, N - 1 do
      local a = select(4, px(x, N / 2))
      if a > prev then why = "alpha non décroissant" break end
      prev = a
    end
    if not why and select(4, px(N / 2, N / 2)) < 250 then why = "centre non plein" end
  end
  check("Media/shadow_soft.tga : TGA 32 bits 128 × 128, blanc, bord à alpha 0, dégradé radial du centre plein au bord",
    okTex and why == nil, why)

  -- une ombre par personnage affiché (héros + ennemis), centrée sous les pieds, aplatie, noire, sans
  -- accrochage au pixel, proportionnelle au cadre (ennemi agrandi compris)
  local function shadowBad(fig, label, bad)
    local sh = fig.shadow
    if not (sh and sh.parts and #sh.parts == #Sc.SHADOW_LAYERS) then bad[#bad + 1] = label .. " : pas d'ombre" return end
    local fr = R.rect(fig)
    local fx = (fr[1] + fr[3]) / 2
    local k = (fr[3] - fr[1]) / fig._w
    for i, t in ipairs(sh.parts) do
      local r = R.rect(t)
      local w, h = r[3] - r[1], r[4] - r[2]
      local vc = t._calls.SetVertexColor or {}
      local snap = t._calls.SetSnapToPixelGrid
      local problems = {}
      if not t:IsVisible() then problems[#problems + 1] = "cachée" end
      if t._texture ~= Sc.SHADOW then problems[#problems + 1] = "texture " .. tostring(t._texture) end
      if vc[1] ~= 0 or vc[2] ~= 0 or vc[3] ~= 0 or vc[4] ~= Sc.SHADOW_LAYERS[i].a then problems[#problems + 1] = "teinte" end
      if not (snap and snap[1] == false) then problems[#problems + 1] = "accrochage au pixel" end
      if math.abs(w / h - Sc.SHADOW_RATIO) > 0.01 then problems[#problems + 1] = ("rapport %.2f"):format(w / h) end
      if math.abs(w - fig._w * Sc.SHADOW_LAYERS[i].w * k) > 0.01 then problems[#problems + 1] = ("largeur %.1f"):format(w) end
      if math.abs((r[1] + r[3]) / 2 - fx) > 0.01 then problems[#problems + 1] = "décentrée" end
      local cy = (r[2] + r[4]) / 2 - fr[2]
      if cy <= 0 or cy > 20 * k then problems[#problems + 1] = ("hauteur des pieds %.1f"):format(cy) end
      if #problems > 0 then bad[#bad + 1] = label .. " couche " .. i .. " : " .. table.concat(problems, ", ") end
    end
  end
  local c = C().combat()
  c.enemies = {}
  for _, id in ipairs({ "murloc", "harvest_golem" }) do ns.Combat.spawn(c, id) end
  local v = V()
  v.c = nil
  v:Show({ state = c })
  H.advance(0.5)
  local bad, n, figs = {}, 0, {}
  shadowBad(v.hero, "héros", bad)
  n = n + 1
  for _, s in pairs(v.slotOf) do
    if s:IsVisible() then
      n = n + 1
      figs[#figs + 1] = s
      for _, e in ipairs(c.enemies) do if e.uid == s.uid then shadowBad(s.fig, e.id, bad) end end
    end
  end
  check("combat : une ombre par personnage affiché (héros, murloc, golem agrandi), sous les pieds, fondue",
    n == 3 and #bad == 0, table.concat(bad, " ; "))
  -- mort d'un ennemi : l'ombre s'efface avec le modèle, puis part avec l'emplacement
  local golem
  for _, s in ipairs(figs) do
    for _, e in ipairs(c.enemies) do if e.uid == s.uid and e.id == "harvest_golem" then golem = { s = s, e = e } end end
  end
  if golem then
    golem.e.hp, golem.e.dead = 0, true
    v:OnEvents({ { t = "death", unit = golem.e.uid } })
    H.advance(5)
    local part = golem.s.fig.shadow.parts[1]
    local a = part._calls.SetAlpha
    check("mort d'un ennemi : son ombre s'efface (alpha 0) et disparaît avec lui",
      a and a[1] == 0 and not part:IsVisible() and not golem.s:IsVisible(), a and a[1])
  else
    check("mort d'un ennemi : golem affiché", false)
  end

  -- rencontre : ombre du héros, ombre du PNJ seulement quand son modèle est affiché
  freshRun(SEED + 4, "event")
  local ch = UI().current
  local ebad = {}
  shadowBad(ch.hero, "héros (rencontre)", ebad)
  if ch.npc.model:IsShown() then shadowBad(ch.npc, "PNJ", ebad) end
  check("rencontre : ombre du héros sous les pieds ; ombre du PNJ affichée avec son modèle seulement",
    #ebad == 0 and ch.npc.shadow:IsShown() == (ch.npc.model:IsShown() and true or false), table.concat(ebad, " ; "))
end

print("U29 textes affichés en anglais : aucune chaîne française dans Core/, Data/, UI/ ni le TOC")
do
  -- Chaînes du code (hors commentaires) des fichiers du TOC, plus Title et Notes du TOC. Une chaîne est
  -- française si elle contient une lettre accentuée latine, des guillemets « », ou un mot-outil
  -- français. Exceptions : valeurs enregistrées dans la sauvegarde gardées telles quelles (zoom) et
  -- textes de mesure de police (jamais lus par le joueur).
  local KEEP = { ["fluide"] = true, ["lisse"] = true, ["net"] = true, ["\195\137\195\169"] = true, ["\195\137g"] = true }
  -- mots-outils et vocabulaire du jeu en français (comparés en minuscules), sans homographes anglais
  local FR_WORDS = { "de", "du", "des", "les", "le", "la", "une", "et", "pour", "avec", "aux", "au", "est", "pas",
    "sur", "dans", "sans", "vous", "votre", "vos", "ou", "il", "elle", "ici", "trop", "faut", "aucun", "aucune",
    "non", "oui", "carte", "cartes", "tour", "tours", "ennemi", "ennemis", "pv", "po", "recharge", "incantation",
    "pouvoir", "pioche", "inflige", "soigne", "soins", "gagne", "donne", "applique", "fermer", "retour", "passer",
    "continuer", "partir", "rien", "coffre", "rencontre", "marchand", "douleur", "expiation", "absorption", "ombre",
    "bibelot", "bibelots", "essai", "suivant", "peint", "modeles", "clic", "acte", "inconnu", "inconnue", "vendu",
    "indisponible", "choix", "cible", "chemin", "emplacement", "nouvelle", "titre", "centre", "quarantaine",
    "palier", "neutre", "amical", "galvanisant", "disette", "tyrannique", "rugissement", "horion", "rafale",
    "blindage", "moisson", "griffe", "morsure", "guette", "garde", "invoque", "attaque", "chargement", "schisme",
    "extase", "rivepatte", "moissonneur", "cocher", "fouet", "mentale", "liquide", "consumée", "conservée",
    "manquant", "manquants", "manquante", "absente", "invalide", "maintenant", "nombre", "classe", "sauvegarde",
    "toucher", "psychique", "frappe", "mortelle", "vieux", "tante", "fermier", "gardien", "bricoleur", "chercheur",
    "logement", "souffle", "dernier", "perdu", "pouv", "rech" }
  local function isFrench(s)
    if KEEP[s] then return nil end
    local plain = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", " ")
    -- lettres latines accentuées (U+00C0 à U+017F, sauf × et ÷) ; guillemets « »
    for c1, c2 in plain:gmatch("([\195\196\197])(.)") do
      local b2 = c2:byte()
      if not (c1 == "\195" and (b2 == 0x97 or b2 == 0xB7)) then return "lettre accentuée" end
    end
    if plain:find("\194\171", 1, true) or plain:find("\194\187", 1, true) then return "guillemets « »" end
    -- typographie française : espace avant « : », « ! », « ? », « ; »
    if plain:find("[%w%)] [:!?;]") or plain:find("^ :") then return "espace avant la ponctuation" end
    local padded = " " .. plain:lower():gsub("[%p%d]", " ") .. " "
    for _, w in ipairs(FR_WORDS) do
      if padded:find(" " .. w .. " ", 1, true) then return "mot « " .. w .. " »" end
    end
    return nil
  end
  -- extraction des chaînes d'un source Lua (commentaires et chaînes longues compris)
  local function strings(src)
    local out, i, n, line = {}, 1, #src, 1
    while i <= n do
      local c = src:sub(i, i)
      if c == "\n" then line = line + 1 i = i + 1
      elseif src:sub(i, i + 1) == "--" then
        local eq = src:match("^%-%-%[(=*)%[", i)
        if eq then
          local j = src:find("]" .. eq .. "]", i, true)
          local body = src:sub(i, j)
          line = line + select(2, body:gsub("\n", ""))
          i = j + #eq + 2
        else
          local j = src:find("\n", i, true)
          i = j or n + 1
        end
      elseif src:match("^%[=*%[", i) then
        local eq = src:match("^%[(=*)%[", i)
        local j = src:find("]" .. eq .. "]", i, true)
        local body = src:sub(i + #eq + 2, j - 1)
        out[#out + 1] = { line, body }
        line = line + select(2, body:gsub("\n", ""))
        i = j + #eq + 2
      elseif c == "\"" or c == "'" then
        local j, buf = i + 1, {}
        while j <= n do
          local d = src:sub(j, j)
          if d == "\\" then buf[#buf + 1] = src:sub(j, j + 1) j = j + 2
          elseif d == c or d == "\n" then break
          else buf[#buf + 1] = d j = j + 1 end
        end
        out[#out + 1] = { line, table.concat(buf) }
        i = j + 1
      else
        i = i + 1
      end
    end
    return out
  end
  local found, nStr, nFiles = {}, 0, 0
  local toc = assert(io.open(root .. "/" .. ADDON .. ".toc", "r"))
  for raw in toc:lines() do
    local l = raw:gsub("\r", "")
    local field, value = l:match("^## (%a+): (.*)$")
    if field == "Title" or field == "Notes" then
      nStr = nStr + 1
      local why = isFrench(value)
      if why then found[#found + 1] = ADDON .. ".toc " .. field .. " : « " .. value .. " » (" .. why .. ")" end
    elseif l:match("%.lua$") and not l:match("^#") then
      local path = l:gsub("\\", "/")
      local f = assert(io.open(root .. "/" .. path, "r"))
      local src = f:read("*a")
      f:close()
      nFiles = nFiles + 1
      for _, s in ipairs(strings(src)) do
        nStr = nStr + 1
        local why = isFrench(s[2])
        if why then found[#found + 1] = path .. ":" .. s[1] .. " : « " .. s[2] .. " » (" .. why .. ")" end
      end
    end
  end
  toc:close()
  check(("%d fichiers du TOC, %d chaînes : aucune en français"):format(nFiles, nStr), #found == 0,
    table.concat(found, "\n        "))
  -- le détecteur reconnaît bien du français (témoins)
  check("détecteur : témoins français reconnus, anglais accepté", isFrench("Inflige 6.") and isFrench("Ce n'est pas votre tour.")
    and isFrench("Démence") and isFrench("« Merci. »") and not isFrench("Deal 6.") and not isFrench("Gain Atonement 1 ⌛")
    and not isFrench("\"Thank you.\" × 2 · —"))
end

print("U30 habillage WoW : pièces embarquées (TGA conformes), aucune texture supprimée, ni atlas ni chemin du client, textes dans leurs zones")
do
  freshRun(SEED, "combat")
  H.settle()
  local ns = H.ns
  local W = ns.Widgets
  local WS = ns.WowSkin
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local MEDIA = "Interface\\AddOns\\SlayTheDragon\\Media\\"
  check("racine des pièces : Media\\WowUI de l'addon", WS.root == MEDIA .. "WowUI\\", WS.root)
  local function u16(s, i) return s:byte(i) + 256 * s:byte(i + 1) end
  local function pow2(n) return n > 0 and math.floor(math.log(n) / math.log(2) + 0.5) == math.log(n) / math.log(2) end
  -- 1. chaque pièce : fichier présent, TGA 32 bits non compressé à origine en bas (descripteur 8),
  -- dimensions en puissances de deux égales à la table, coordonnées = pièce / toile, pièce répétée qui
  -- remplit sa toile sur l'axe répété
  local bad, n, files = {}, 0, {}
  for name, e in pairs(WS.pieces) do
    n = n + 1
    local f = io.open(root .. "/Media/WowUI/" .. e.file, "rb")
    local hdr = f and f:read(18)
    local size = f and f:seek("end")
    if f then f:close() end
    local ok = hdr and #hdr == 18 and hdr:byte(3) == 2 and hdr:byte(17) == 32 and hdr:byte(18) == 8
      and u16(hdr, 13) == e.w and u16(hdr, 15) == e.h and size == 18 + e.w * e.h * 4 and pow2(e.w) and pow2(e.h)
      and e.pw <= e.w and e.ph <= e.h and e.tc[2] - e.tc[1] > 0 and e.tc[4] - e.tc[3] > 0
      and math.abs((e.tc[2] - e.tc[1]) - e.pw / e.w) < 1e-4 and math.abs((e.tc[4] - e.tc[3]) - e.ph / e.h) < 1e-4
      and type(e.fid) == "number"
    if e.tile then
      ok = ok and (not e.tile:find("h") or e.pw == e.w) and (not e.tile:find("v") or e.ph == e.h)
        and e.tc[1] == 0 and e.tc[3] == 0
    end
    if not ok then bad[#bad + 1] = name end
    files[e.file] = true
  end
  table.sort(bad)
  check(n .. " pièces de UI/WowSkin.lua : TGA de Media\\WowUI présents et conformes", n > 30 and #bad == 0,
    table.concat(bad, ", "))
  -- aucun fichier orphelin dans Media/WowUI
  local orphans = {}
  local pipe = io.popen("ls '" .. root .. "/Media/WowUI'")
  for line in pipe:lines() do if not files[line] then orphans[#orphans + 1] = line end end
  pipe:close()
  check("Media\\WowUI : aucun fichier hors de la table", #orphans == 0, table.concat(orphans, ", "))

  -- 2. sources de UI/ : pièces nommées connues, aucune texture supprimée, aucun atlas, chemins du client
  -- seulement dans la liste permise (texture blanche, bouton de minicarte, icônes, police de repli,
  -- écrans de chargement candidats du décor)
  local REMOVED = { "hex_red", "hex_green", "hex_blue", "hex_steel", "hex_violet", "hex_empty", "tile_ivory",
    "nine_slate", "nine_ivory", "nine_rim", "button_gold", "tail_slate", "tail_ivory", "tail_rim", "medal_ring_s",
    "mask_roundsq" }
  local ALLOWED = { "Interface\\\\Buttons\\\\WHITE8X8", "Interface\\\\Minimap\\\\", "Interface\\\\Icons\\\\",
    "Interface\\\\AddOns\\\\SlayTheDragon\\\\", "Interface\\\\Glues\\\\LoadingScreens\\\\" }
  local unknownPieces, removedRefs, atlas, clientPaths = {}, {}, {}, {}
  for _, file in ipairs({ "Widgets", "Main", "Scene", "CombatView", "Screens", "Flight", "Art", "Controller", "Persist" }) do
    local src = assert(io.open(root .. "/UI/" .. file .. ".lua")):read("*a")
    for fn, name in src:gmatch("W%.(%a+)%([^\n]-\"([%l_]+)\"") do
      if (fn == "wow" or fn == "setWow" or fn == "wowSize" or fn == "fillTile" or fn == "threeSlice" or fn == "nineStretch"
        or fn == "wowPath") and not WS.pieces[name] then unknownPieces[#unknownPieces + 1] = file .. ": " .. name end
    end
    for _, r in ipairs(REMOVED) do
      if src:find('"' .. r .. '"', 1, true) or src:find(r .. ".tga", 1, true) then removedRefs[#removedRefs + 1] = file .. ": " .. r end
    end
    if src:find("SetAtlas", 1, true) then atlas[#atlas + 1] = file end
    for lit in src:gmatch('"(Interface\\\\[^"]*)"') do
      local ok = false
      for _, a in ipairs(ALLOWED) do if lit:sub(1, #a) == a then ok = true end end
      if not ok then clientPaths[#clientPaths + 1] = file .. ": " .. lit end
    end
  end
  check("pièces nommées dans UI/ toutes présentes dans UI/WowSkin.lua", #unknownPieces == 0, table.concat(unknownPieces, ", "))
  check("aucune référence aux textures supprimées de l'ancienne peau", #removedRefs == 0, table.concat(removedRefs, ", "))
  removedRefs = {}
  for _, r in ipairs(REMOVED) do
    local f = io.open(root .. "/Media/" .. r .. ".tga", "rb")
    if f then f:close() removedRefs[#removedRefs + 1] = "Media/" .. r .. ".tga" end
  end
  check("textures de l'ancienne peau retirées de Media/", #removedRefs == 0, table.concat(removedRefs, ", "))
  check("aucun SetAtlas dans UI/", #atlas == 0, table.concat(atlas, ", "))
  check("chemins Interface\\ du client : seulement la liste permise (blanc, minicarte, icônes, écrans de chargement)",
    #clientPaths == 0, table.concat(clientPaths, ", "))

  -- 3. à l'exécution : toute texture de la fenêtre est un fichier de l'addon (présent sur disque), la
  -- texture blanche, une icône (chemin ou FileDataID d'icône) ou un fond du décor ; toute pièce posée existe
  local function under(o, top)
    while o do if o == top then return true end o = rawget(o, "_parent") end
    return false
  end
  local frame = _G.SlayTheDragonFrame
  local missingFiles, strayTex, unknownWow = {}, {}, {}
  local seen = {}
  for _, o in ipairs(H.objects) do
    local kind = rawget(o, "_kind")
    if (kind == "Texture" or kind == "MaskTexture" or kind == "Line") and under(o, frame) then
      local tex = rawget(o, "_texture")
      if type(tex) == "string" and not seen[tex] then
        seen[tex] = true
        if tex:sub(1, #MEDIA) == MEDIA then
          local f = io.open(root .. "/Media/" .. tex:sub(#MEDIA + 1):gsub("\\", "/"), "rb")
          if f then f:close() else missingFiles[#missingFiles + 1] = tex end
        elseif tex ~= ns.Art.tex.white and not tex:find("^Interface\\Icons\\") and not tex:find("^Interface\\Glues\\") then
          strayTex[#strayTex + 1] = tex
        end
      end
      local wn = rawget(o, "_wow")
      if wn and not WS.pieces[wn] then unknownWow[#unknownWow + 1] = wn end
    end
  end
  check("textures de la fenêtre : fichiers de l'addon présents sur disque", #missingFiles == 0, table.concat(missingFiles, ", "))
  check("textures de la fenêtre : aucun chemin du client hors icônes et texture blanche", #strayTex == 0,
    table.concat(strayTex, ", "))
  check("pièces posées à l'exécution toutes connues de UI/WowSkin.lua", #unknownWow == 0, table.concat(unknownWow, ", "))

  -- 4. netteté : une pièce entière (ni tranche, ni répétée) n'est jamais affichée plus grande que ses
  -- pixels stockés, à l'échelle de la fenêtre (115 %) et au repos
  local scale = frame._scale or 1
  local function visible(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local blurry = {}
  local function sharp(where)
    local fr = _G.SlayTheDragonFrame
    for _, o in ipairs(H.objects) do
      local wn = rawget(o, "_wow")
      local e = wn and WS.pieces[wn]
      local tc = e and o._calls.SetTexCoord
      if e and not e.tile and tc and visible(o) and under(o, fr)
        and math.abs((tc[2] - tc[1]) - (e.tc[2] - e.tc[1])) < 1e-6 and math.abs((tc[4] - tc[3]) - (e.tc[4] - e.tc[3])) < 1e-6 then
        local r = R.rect(o)
        if r then
          local w, h = (r[3] - r[1]), (r[4] - r[2])
          if (w > e.pw + 0.75 and e.stretch ~= "h") or h > e.ph + 0.75 then
            blurry[#blurry + 1] = string.format("%s : %s %.0f×%.0f > %d×%d", where, wn, w, h, e.pw, e.ph)
          end
        end
      end
    end
  end
  sharp("combat")
  H.slash("options")
  sharp("options")
  H.key("ESCAPE")

  -- 5. textes dans leurs zones : libellés des boutons rouges (entre les bouts du bouton), cadre du héros
  -- (nom dans son logement, PV dans la barre), cadres compacts des ennemis (voir U21)
  local outB = {}
  for _, o in ipairs(H.objects) do
    if rawget(o, "_kind") == "Button" and rawget(o, "base") and rawget(o, "label") and o.base.cap and visible(o) then
      local t = o.label._text or ""
      if t ~= "" then
        local tw = H.textWidth(o.label, t, o.label._fontSize)
        local inner = o._w - 2 * o.base.cap
        if tw > inner + 0.5 then outB[#outB + 1] = string.format("« %s » %.0f > %.0f", t, tw, inner) end
        if o.label._fontSize * H.metrics.lineHeight > o._h + 1 then outB[#outB + 1] = "« " .. t .. " » plus haut que le bouton" end
      end
    end
  end
  check("libellés des boutons affichés entre les bouts du bouton", #outB == 0, table.concat(outB, ", "))
  local v = V()
  local hf = v.heroFrame
  local m = WS.meta.unit_player
  local k = hf._w / WS.pieces.unit_player.pw
  local nameW = H.textWidth(hf.name, hf.name._text or "", hf.name._fontSize)
  local hpW = H.textWidth(v.playerHp.text, v.playerHp.text._text or "", v.playerHp.text._fontSize)
  check("cadre du héros : nom dans son logement, PV dans la barre, barre dans son logement",
    nameW <= m.name[3] * k and hpW <= v.playerHp._w and math.abs(v.playerHp._w - m.hp[3] * k) < 0.01
    and v.playerHp.text._fontSize * H.metrics.lineHeight <= m.hp[4] * k + 3 and (hf.name._text or "") ~= "",
    string.format("nom %.0f / %.0f, PV %.0f / %.0f", nameW, m.name[3] * k, hpW, v.playerHp._w))
  local outE = {}
  for _, s in pairs(v.slotOf) do
    local t = s.hp.text._text or ""
    if H.textWidth(s.hp.text, t, s.hp.text._fontSize) > s.hp.w then outE[#outE + 1] = t end
  end
  check("cadres compacts des ennemis : PV dans la barre", #outE == 0, table.concat(outE, ", "))

  -- 6. visuels survolables : aucun cadre enfant dessiné (une animation d'échelle pourrait ne pas le suivre)
  local function drawnRegions(f)
    for _, kid in ipairs(rawget(f, "_kids") or {}) do
      local kk = rawget(kid, "_kind")
      if kk == "Texture" or kk == "FontString" then return true end
      if kk ~= "AnimationGroup" and kk ~= "Animation" and kk ~= "MaskTexture" and drawnRegions(kid) then return true end
    end
    return false
  end
  local childBad, nh = {}, 0
  for _, o in ipairs(H.objects) do
    local face = rawget(o, "face")
    if rawget(o, "_hoverable") and face then
      nh = nh + 1
      for _, kid in ipairs(rawget(face, "_kids") or {}) do
        local kk = rawget(kid, "_kind")
        if kk ~= "Texture" and kk ~= "FontString" and kk ~= "MaskTexture" and kk ~= "AnimationGroup"
          and kk ~= "Animation" and drawnRegions(kid) then
          childBad[#childBad + 1] = tostring(rawget(o, "_text") or rawget(o, "_kind"))
        end
      end
    end
  end
  check(nh .. " visuels survolables : aucun cadre enfant dessiné", nh > 20 and #childBad == 0, table.concat(childBad, ", "))

  -- netteté (suite) : les autres écrans
  for _, sc in ipairs({ { SEED + 2, "merchant", "marchand" }, { SEED + 5, nil, "parcours" },
    { SEED + 4, "event", "rencontre" }, { SEED + 3, "campfire", "feu de camp" } }) do
    freshRun(sc[1], sc[2])
    H.advance(1)
    sharp(sc[3])
  end
  check(("pièces entières nettes à l'échelle %.2f (affichées au plus à leur taille stockée)"):format(scale),
    #blurry == 0, table.concat(blurry, ", "))
end

print("U31 ordre de dessin (cadres rogneurs), bandeau sur la barre de titre, silhouette des cadres, cases d'icônes")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  -- chaque expédition neuve relance l'addon (H.boot) : références reprises après chaque freshRun
  local Um, WS, P, bar, rim
  local function refs()
    Um, WS = H.ns.UI, H.ns.WowSkin
    P = Um.frameMetal.P
    bar = { P.top, P.tl, P.tr }
    rim = { P.left, P.right, P.bottom, P.bl, P.br }
  end
  local function fresh(...)
    freshRun(...)
    refs()
  end
  refs()
  local function under(o, top)
    while o do if o == top then return true end o = rawget(o, "_parent") end
    return false
  end
  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function alphaOf(o)
    local a = 1
    while o do
      local c = rawget(o, "_calls")
      if c and c.SetAlpha then a = a * (c.SetAlpha[1] or 1) end
      o = rawget(o, "_parent")
    end
    return a
  end
  local function isRegion(o)
    local k = rawget(o, "_kind")
    if k == "Texture" then return rawget(o, "_texture") ~= nil or (o._calls.SetColorTexture ~= nil) end
    if k == "FontString" then return (rawget(o, "_text") or "") ~= "" end
    return false
  end
  -- régions visibles (alpha > 0) sous top, sauf celles sous un des cadres de `skip`
  local function regionsUnder(top, skip)
    local out = {}
    for _, o in ipairs(H.objects) do
      if isRegion(o) and under(o, top) and vis(o) and alphaOf(o) > 0.01 then
        local ok = true
        for _, s in ipairs(skip or {}) do if under(o, s) or o == s then ok = false end end
        if ok then out[#out + 1] = o end
      end
    end
    return out
  end
  local function clipped(o)
    local r = R.rect(o)
    if not r then return nil end
    local c = R.clipRect(o)
    if c then r = { math.max(r[1], c[1]), math.max(r[2], c[2]), math.min(r[3], c[3]), math.min(r[4], c[4]) } end
    if r[3] - r[1] <= 0 or r[4] - r[2] <= 0 then return nil end
    return r
  end
  local function area(a, b)
    if not a or not b then return 0 end
    local w = math.min(a[3], b[3]) - math.max(a[1], b[1])
    local h = math.min(a[4], b[4]) - math.max(a[2], b[2])
    return (w > 0 and h > 0) and w * h or 0
  end
  local function above(o, t) return R.drawnBefore(R.drawKey(t), R.drawKey(o)) end

  -- 1. règle du faux client : un cadre rogneur dessine ses descendants à son niveau
  do
    local top = CreateFrame("Frame", nil, UIParent)
    local clip = CreateFrame("Frame", nil, top)
    clip:SetFrameLevel(2)
    clip:SetClipsChildren(true)
    local kid = CreateFrame("Frame", nil, clip)
    kid:SetFrameLevel(50)
    local sib = CreateFrame("Frame", nil, top)
    sib:SetFrameLevel(10)
    local tk, ts, tc = kid:CreateTexture(nil, "OVERLAY"), sib:CreateTexture(nil, "BACKGROUND"), clip:CreateTexture(nil, "ARTWORK")
    local free = CreateFrame("Frame", nil, top)
    free:SetFrameLevel(50)
    local tf = free:CreateTexture(nil, "OVERLAY")
    check("faux client : un descendant (niveau 50) d'un rogneur (niveau 2) passe sous un frère du rogneur (niveau 10)",
      above(ts, tk) and above(tk, tc) and above(tf, ts))
    top:Hide()
  end

  -- 2. bandeau au-dessus de la barre de titre ; filets au-dessus du contenu ; écran par écran
  local function bandCheck(where)
    local bad, n = {}, 0
    for _, o in ipairs(regionsUnder(Um.band)) do
      for _, t in ipairs(bar) do
        if area(clipped(o), R.rect(t)) > 0 then
          n = n + 1
          if not above(o, t) then bad[#bad + 1] = (rawget(o, "_text") or rawget(o, "_wow") or rawget(o, "_kind")) end
        end
      end
    end
    check(where .. " : les " .. n .. " éléments du bandeau sont dessinés au-dessus de la barre de titre",
      n >= 12 and #bad == 0, table.concat(bad, ", "))
    local under0 = {}
    for _, o in ipairs(regionsUnder(Um.content)) do
      for _, t in ipairs(rim) do
        if area(clipped(o), R.rect(t)) > 0 and not above(t, o) then under0[#under0 + 1] = tostring(rawget(o, "_wow") or rawget(o, "_kind")) end
      end
    end
    check(where .. " : filets du cadre métal par-dessus tout le contenu", #under0 == 0, table.concat(under0, ", "))
  end
  fresh(SEED, "combat")
  H.settle()
  bandCheck("combat")

  -- message passager au-dessus des options et du panneau du deck
  H.slash("options")
  Um.flash("Test message.")
  local function errOver(panel)
    local bad = 0
    for _, o in ipairs(regionsUnder(panel)) do
      if area(clipped(o), R.rect(Um.err.text)) > 0 and not above(Um.err.text, o) then bad = bad + 1 end
    end
    return bad
  end
  check("message passager au-dessus du panneau d'options", Um.err._shown and errOver(Um.optionsFrame) == 0)
  H.key("ESCAPE")
  Um.toggleDeckView("deck")
  Um.flash("Test message.")
  check("message passager au-dessus du panneau du deck", Um.deckView:IsShown() and errOver(Um.deckView.frame) == 0)
  H.key("ESCAPE")
  H.advance(3)

  -- 3. silhouette des cadres : rien du contenu ni d'un fond ne tombe sur un pixel transparent à
  -- l'extérieur du cadre (pièces lues dans Media/WowUI, alpha < 0,5 relié au bord extérieur)
  local tgaCache = {}
  local function tga(file)
    if tgaCache[file] then return tgaCache[file] end
    local f = assert(io.open(root .. "/Media/WowUI/" .. file, "rb"))
    local s = f:read("*a")
    f:close()
    local w, h = s:byte(13) + 256 * s:byte(14), s:byte(15) + 256 * s:byte(16)
    local t = { w = w, h = h, alpha = function(x, y) return s:byte(18 + ((h - 1 - y) * w + x) * 4 + 4) end }
    tgaCache[file] = t
    return t
  end
  -- masque extérieur d'une pièce (pixels de la pièce, origine en haut à gauche) : remplissage depuis les
  -- côtés extérieurs (l, r, t, b) à travers les pixels d'alpha < 128
  local extCache = {}
  local function exterior(name, sides)
    local key = name .. ":" .. sides
    if extCache[key] then return extCache[key] end
    local e = WS.pieces[name]
    local img = tga(e.file)
    local x0, y0 = math.floor(e.tc[1] * e.w + 0.5), math.floor(e.tc[3] * e.h + 0.5)
    local pw, ph = e.pw, e.ph
    local ext, stack = {}, {}
    local function push(x, y)
      if x < 0 or y < 0 or x >= pw or y >= ph then return end
      local i = y * pw + x
      if ext[i] or img.alpha(x0 + x, y0 + y) >= 128 then return end
      ext[i] = true
      stack[#stack + 1] = i
    end
    if sides:find("l") then for y = 0, ph - 1 do push(0, y) end end
    if sides:find("r") then for y = 0, ph - 1 do push(pw - 1, y) end end
    if sides:find("t") then for x = 0, pw - 1 do push(x, 0) end end
    if sides:find("b") then for x = 0, pw - 1 do push(x, ph - 1) end end
    while #stack > 0 do
      local i = table.remove(stack)
      local x, y = i % pw, math.floor(i / pw)
      push(x + 1, y) push(x - 1, y) push(x, y + 1) push(x, y - 1)
    end
    local m = { ext = ext, pw = pw, ph = ph, e = e }
    extCache[key] = m
    return m
  end
  -- boîtes d'écran {l, b, r, t} des pixels extérieurs d'une texture posée (pièce entière, tranche
  -- d'une pièce, ou bord répété : alors une bande par colonne / rangée extérieure)
  local function extBoxes(tex, sides)
    local name = rawget(tex, "_wow")
    local m = exterior(name, sides)
    local e = m.e
    local r = R.rect(tex)
    local out = {}
    if not r then return out end
    if e.tile then
      -- bord répété : profil pris au milieu de la pièce, sur l'axe non répété
      if e.tile == "v" then
        local y = math.floor(m.ph / 2)
        for x = 0, m.pw - 1 do
          if m.ext[y * m.pw + x] then
            local sx = (r[3] - r[1]) / m.pw
            out[#out + 1] = { r[1] + x * sx, r[2], r[1] + (x + 1) * sx, r[4] }
          end
        end
      else
        local x = math.floor(m.pw / 2)
        for y = 0, m.ph - 1 do
          if m.ext[y * m.pw + x] then
            local sy = (r[4] - r[2]) / m.ph
            out[#out + 1] = { r[1], r[4] - (y + 1) * sy, r[3], r[4] - y * sy }
          end
        end
      end
      return out
    end
    local tc = tex._calls.SetTexCoord or { 0, 1, 0, 1 }
    -- coordonnées de texture -> pixels de la pièce
    local px0 = (tc[1] - e.tc[1]) * e.w
    local px1 = (tc[2] - e.tc[1]) * e.w
    local py0 = (tc[3] - e.tc[3]) * e.h
    local py1 = (tc[4] - e.tc[3]) * e.h
    local sx, sy = (r[3] - r[1]) / (px1 - px0), (r[4] - r[2]) / (py1 - py0)
    for y = math.max(0, math.floor(py0)), math.min(m.ph, math.ceil(py1)) - 1 do
      for x = math.max(0, math.floor(px0)), math.min(m.pw, math.ceil(px1)) - 1 do
        if m.ext[y * m.pw + x] then
          local l = r[1] + (math.max(x, px0) - px0) * sx
          local rr = r[1] + (math.min(x + 1, px1) - px0) * sx
          local t = r[4] - (math.max(y, py0) - py0) * sy
          local b = r[4] - (math.min(y + 1, py1) - py0) * sy
          out[#out + 1] = { l, b, rr, t }
        end
      end
    end
    return out
  end
  -- fuites : rectangles testés (nom -> rect) posés sur un pixel extérieur d'une pièce du cadre
  local function leaks(pieces, rects)
    local out = {}
    for _, pc in ipairs(pieces) do
      local boxes = extBoxes(pc[1], pc[2])
      for nm, rr in pairs(rects) do
        local a = 0
        for _, bx in ipairs(boxes) do a = a + area(bx, rr) end
        if a > 0.01 then out[#out + 1] = string.format("%s sur %s (%.2f u²)", nm, rawget(pc[1], "_wow"), a) end
      end
    end
    table.sort(out)
    return out
  end
  local function frameLeaks(where)
    local pieces = { { P.tl, "lt" }, { P.tr, "rt" }, { P.bl, "lb" }, { P.br, "rb" }, { P.top, "t" },
      { P.left, "l" }, { P.right, "r" }, { P.bottom, "b" } }
    local rects = { contenu = R.rect(Um.content), ["fond de roche"] = R.rect(Um.frameBg), ["couche du dessus"] = R.rect(Um.overlay) }
    for i, o in ipairs(regionsUnder(Um.band)) do rects["bandeau " .. i .. " " .. tostring(rawget(o, "_wow") or rawget(o, "_text") or "")] = clipped(o) end
    local l = leaks(pieces, rects)
    check(where .. " : fenêtre, rien du contenu, du fond ni du bandeau hors de la silhouette du cadre métal (coins compris)",
      #l == 0, table.concat(l, ", "))
  end
  frameLeaks("combat")
  -- contenu bord à bord avec le filet : ses bords tombent sur la partie opaque (alpha ≥ 0,5) des filets
  do
    local c = R.rect(Um.content)
    local function opaqueSpan(tex, axis)
      local m = exterior(rawget(tex, "_wow"), "")
      local e = m.e
      local img = tga(e.file)
      local r = R.rect(tex)
      local lo, hi
      if axis == "x" then
        local y = math.floor(m.ph / 2)
        for x = 0, m.pw - 1 do
          if img.alpha(x, y) >= 128 then lo = lo or x hi = x + 1 end
        end
        local s = (r[3] - r[1]) / m.pw
        return r[1] + lo * s, r[1] + hi * s
      else
        local x = math.floor(m.pw / 2)
        for y = 0, m.ph - 1 do
          if img.alpha(x, y) >= 128 then lo = lo or y hi = y + 1 end
        end
        local s = (r[4] - r[2]) / m.ph
        return r[4] - hi * s, r[4] - lo * s
      end
    end
    local l0, l1 = opaqueSpan(P.left, "x")
    local r0, r1 = opaqueSpan(P.right, "x")
    local b0, b1 = opaqueSpan(P.bottom, "y")
    local t0, t1 = opaqueSpan(P.top, "y")
    local ok = c[1] >= l0 - 0.01 and c[1] <= l1 + 0.01 and c[3] >= r0 - 0.01 and c[3] <= r1 + 0.01
      and c[2] >= b0 - 0.01 and c[2] <= b1 + 0.01 and c[4] >= t0 - 0.01 and c[4] <= t1 + 0.01
    check("contenu bord à bord avec les filets (aucune bande vide entre le contenu et le filet)", ok,
      string.format("contenu %.2f %.2f %.2f %.2f ; filets x %.2f-%.2f / %.2f-%.2f, y %.2f-%.2f / %.2f-%.2f",
        c[1], c[3], c[2], c[4], l0, l1, r0, r1, b0, b1, t0, t1))
  end

  -- boîtes de dialogue (DiamondMetal) visibles : fond et contenu dans la silhouette
  local function dialogLeaks(where)
    local bad, n = {}, 0
    for _, d in ipairs(H.objects) do
      local bd = rawget(d, "border")
      if bd and type(bd) == "table" and bd.P and rawget(d, "bg") and rawget(d, "header") and vis(d) then
        n = n + 1
        local Q = bd.P
        local pieces = { { Q.tl, "lt" }, { Q.tr, "rt" }, { Q.bl, "lb" }, { Q.br, "rb" }, { Q.top, "t" },
          { Q.left, "l" }, { Q.right, "r" }, { Q.bottom, "b" } }
        local rects = {}
        local skip = { d.header }
        for _, t in ipairs(bd.parts) do skip[#skip + 1] = t end
        for i, o in ipairs(regionsUnder(d, skip)) do rects[where .. " " .. i .. " " .. tostring(rawget(o, "_wow") or rawget(o, "_text") or "")] = clipped(o) end
        for _, l in ipairs(leaks(pieces, rects)) do bad[#bad + 1] = l end
      end
    end
    return bad, n
  end
  local allBad, nd = {}, 0
  local function dl(where)
    local b, n = dialogLeaks(where)
    nd = nd + n
    for _, x in ipairs(b) do allBad[#allBad + 1] = x end
  end
  H.slash("options")
  dl("options")
  H.key("ESCAPE")
  Um.toggleDeckView("deck")
  dl("deck")
  H.key("ESCAPE")

  -- butin en vol vers le bandeau : sur la couche du dessus pendant le vol, de retour à l'arrivée
  local res = fightUntil(nil, 600)
  if res and V().banner._shown then
    dl("fin de combat")
    H.click(V().banner.button)
  end
  check("récompense atteinte (butin à ramasser)", currentKind() == "reward", currentKind())
  if currentKind() == "reward" then
    bandCheck("récompense")
    frameLeaks("récompense")
    local rw = Um.current
    local bag = rw.goldBag
    local home = bag:GetParent()
    if bag._shown and Um.hold.gold then
      H.click(bag)
      H.advance(0.2)
      local icon = bag.slot.icon
      local flying = bag:GetParent() == Um.overlay and above(icon, P.top) and above(icon, Um.band.bg or P.top)
      local bandTop = true
      for _, o in ipairs(regionsUnder(Um.band)) do
        if area(clipped(o), clipped(icon)) > 0 and not above(icon, o) then bandTop = false end
      end
      check("butin en vol : sur la couche du dessus, au-dessus de la barre de titre et du bandeau", flying and bandTop)
      H.advance(1)
      check("butin arrivé : rendu à son écran, caché, or crédité au bandeau", bag:GetParent() == home and not bag._shown
        and Um.hold.gold == nil and bag:GetFrameLevel() < Um.overlay:GetFrameLevel())
    else
      check("butin : bourse d'or à ramasser", false)
    end
  end

  -- parchemins visibles : rien posé dessus ne déborde de leur silhouette
  local function parchLeaks(where)
    local bad, n = {}, 0
    for _, p in ipairs(H.objects) do
      local nine = rawget(p, "nine")
      if nine and type(nine) == "table" and nine.parts and vis(p) then
        n = n + 1
        local pieces = {}
        for i, t in ipairs(nine.parts) do if i ~= 5 then pieces[#pieces + 1] = { t, "lrtb" } end end
        local rects = {}
        -- ce que porte le parchemin : ses textes, et pour le parcours le canevas posé dessus (étapes, traits)
        for _, s in pairs(Um.screens) do
          if s.parch == p and s.canvas then
            for i, o in ipairs(regionsUnder(s.canvas)) do
              rects[where .. " " .. i .. " " .. tostring(rawget(o, "_wow") or rawget(o, "_text") or rawget(o, "_kind"))] = clipped(o)
            end
          end
        end
        for i, t in ipairs(regionsUnder(p, nine.parts)) do rects[where .. " texte " .. i .. " " .. tostring(rawget(t, "_text") or "")] = clipped(t) end
        for _, l in ipairs(leaks(pieces, rects)) do bad[#bad + 1] = l end
      end
    end
    return bad, n
  end
  local pBad, np = {}, 0
  for _, sc in ipairs({ { SEED + 5, nil, "parcours" }, { SEED + 4, "event", "rencontre" } }) do
    fresh(sc[1], sc[2])
    H.advance(1)
    local b, n = parchLeaks(sc[3])
    np = np + n
    for _, x in ipairs(b) do pBad[#pBad + 1] = x end
    frameLeaks(sc[3])
    bandCheck(sc[3])
  end
  check(nd .. " boîtes de dialogue (options, deck, fin de combat) : fond et contenu dans la silhouette du cadre",
    nd >= 3 and #allBad == 0, table.concat(allBad, ", "))
  check(np .. " parchemins (parcours, rencontre) : rien ne déborde de leur silhouette", np >= 2 and #pBad == 0,
    table.concat(pBad, ", "))

  -- 4. cases d'icônes : l'icône couvre l'ouverture du cadre (mesurée sur les pixels de la pièce, bord
  -- intérieur du liseré d'alpha ≥ 0,5) à ±1 unité ; le fond reste dans le cadre
  do
    local e = WS.pieces.slot_frame
    local img = tga(e.file)
    local x0, y0 = math.floor(e.tc[1] * e.w + 0.5), math.floor(e.tc[3] * e.h + 0.5)
    local function a(x, y) return img.alpha(x0 + x, y0 + y) end
    local my, mx = math.floor(e.ph / 2), math.floor(e.pw / 2)
    local oL, oR, oT, oB = 0, e.pw, 0, e.ph
    while a(oL, my) >= 128 or oL == 0 do oL = oL + 1 end            -- premier pixel après le liseré gauche
    oR = oL while a(oR, my) < 128 do oR = oR + 1 end                -- début du liseré droit
    while a(mx, oT) >= 128 or oT == 0 do oT = oT + 1 end
    oB = oT while a(mx, oB) < 128 do oB = oB + 1 end
    local outR = oR while a(outR, my) >= 128 do outR = outR + 1 end -- bord extérieur du liseré droit
    local outB = oB while a(mx, outB) >= 128 do outB = outB + 1 end
    check(("ouverture du cadre de case mesurée [%d, %d) × [%d, %d), carré visible [0, %d) × [0, %d) (pixels de la pièce)")
      :format(oL, oR, oT, oB, outR, outB), oR - oL > 40 and oB - oT > 40)
    -- partie non nulle du fond de case
    local be = WS.pieces.slot_bg
    local bimg = tga(be.file)
    local bx0, by0 = math.floor(be.tc[1] * be.w + 0.5), math.floor(be.tc[3] * be.h + 0.5)
    local bl, br, bt, bb = be.pw, -1, be.ph, -1
    for y = 0, be.ph - 1 do
      for x = 0, be.pw - 1 do
        if bimg.alpha(bx0 + x, by0 + y) > 8 then
          if x < bl then bl = x end
          if x > br then br = x end
          if y < bt then bt = y end
          if y > bb then bb = y end
        end
      end
    end
    local function fitAll(where)
      local bad, n = {}, 0
      for _, f in ipairs(H.objects) do
        local icon = rawget(f, "_slotIcon")
        if icon and vis(f) and rawget(f, "_wow") == "slot_frame" then
          n = n + 1
          local fr, ir = R.rect(f), R.rect(icon)
          local kx, ky = (fr[3] - fr[1]) / e.pw, (fr[4] - fr[2]) / e.ph
          local want = { fr[1] + oL * kx, fr[4] - oB * ky, fr[1] + oR * kx, fr[4] - oT * ky }
          local d = math.max(math.abs(ir[1] - want[1]), math.abs(ir[2] - want[2]), math.abs(ir[3] - want[3]), math.abs(ir[4] - want[4]))
          if d > 1 then bad[#bad + 1] = string.format("%s : icône à %.1f u de l'ouverture (case %.0f)", where, d, fr[3] - fr[1]) end
          local bg = rawget(f, "_slotBg")
          if bg and vis(bg) then
            local gr = R.rect(bg)
            local gx, gy = (gr[3] - gr[1]) / be.pw, (gr[4] - gr[2]) / be.ph
            local vis0 = { gr[1] + bl * gx, gr[4] - (bb + 1) * gy, gr[1] + (br + 1) * gx, gr[4] - bt * gy }
            local box = { fr[1], fr[4] - outB * ky, fr[1] + outR * kx, fr[4] }
            if vis0[1] < box[1] - 0.25 or vis0[3] > box[3] + 0.25 or vis0[2] < box[2] - 0.25 or vis0[4] > box[4] + 0.25 then
              bad[#bad + 1] = string.format("%s : fond de case hors du cadre (%.1f %.1f %.1f %.1f / %.1f %.1f %.1f %.1f)", where,
                vis0[1], vis0[2], vis0[3], vis0[4], box[1], box[2], box[3], box[4])
            end
          end
        end
      end
      return bad, n
    end
    local sBad, ns0 = {}, 0
    local function sl(where)
      local b, n = fitAll(where)
      ns0 = ns0 + n
      for _, x in ipairs(b) do sBad[#sBad + 1] = x end
    end
    fresh(SEED, "combat")
    H.settle()
    sl("combat")
    fresh(SEED + 2, "merchant")
    H.advance(1)
    sl("marchand")
    check(ns0 .. " cases d'icônes (bandeau, combat, marchand) : icône = ouverture du cadre à ±1, fond dans le cadre",
      ns0 >= 15 and #sBad == 0, table.concat(sBad, ", "))
  end
end

print("U32 curseur d'échelle : aperçu pendant le glisser, échelle au relâchement, valeur juste à toute échelle, fenêtre en place")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  -- géométrie résolue (R.rect, unités d'écran = pixels, UIParent 1600 × 1000 à l'échelle 1) : GetLeft et
  -- GetCenter rendent, comme dans le jeu, des unités du cadre (écran / échelle effective)
  local oldLeft, oldCenter = Frame.GetLeft, Frame.GetCenter
  local uiW, uiH = UIParent._w, UIParent._h
  UIParent._w, UIParent._h = 1600, 1000
  Frame.GetLeft = function(self)
    local r = R.rect(self)
    return r and r[1] / self:GetEffectiveScale() or nil
  end
  Frame.GetCenter = function(self)
    local r = R.rect(self)
    if not r then return nil end
    local e = self:GetEffectiveScale()
    return (r[1] + r[3]) / 2 / e, (r[2] + r[4]) / 2 / e
  end

  local Um = UI()
  if not Um.frame:IsShown() then H.slash("") end
  if not Um.optionsFrame:IsShown() then H.slash("options") end
  local f, o = Um.frame, H.ns.Persist.options() -- addon relancé par les sections précédentes : H.ns
  local sl, sp = Um.scaleSlider, Um.speedSlider
  local function near(a, b, eps) return a and b and math.abs(a - b) < (eps or 1e-6) end
  -- pixel d'écran (x, y) du centre de la poignée de `s` à la fraction fr
  local function at(s, fr)
    local r = R.rect(s.track)
    local e = s.track:GetEffectiveScale()
    return r[1] + (6 + (s.track._w - 12) * fr) * e, (r[2] + r[4]) / 2
  end
  local function thumbX(s)
    local _, _, _, x = s.thumb:GetPoint(1)
    return (x - 6) / (s.track._w - 12)
  end
  local function down(s, fr)
    H.cursor = { at(s, fr) }
    H.mouseDown.LeftButton = true
    run(s.track, "OnMouseDown", "LeftButton")
  end
  local function move(s, fr) H.cursor = { at(s, fr) } run(s.track, "OnUpdate", 0.016) end
  local function up(s)
    H.mouseDown.LeftButton = false
    run(s.track, "OnMouseUp", "LeftButton")
  end
  local function fracOf(v) return (v - 0.6) / 0.9 end
  local function onScreen()
    local r = R.rect(f)
    return r[1] >= -0.01 and r[2] >= -0.01 and r[3] <= 1600.01 and r[4] <= 1000.01, r
  end
  local function centerU() -- centre de la fenêtre en unités de UIParent
    local r = R.rect(f)
    return (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
  end

  -- 1. glisser : l'échelle de la fenêtre ne bouge pas avant le relâchement
  Um.setScale(1.15)
  local n0, pts0 = f._nSetScale or 0, f._points[1]
  down(sl, fracOf(1.15))
  for i = 1, 10 do move(sl, fracOf(1.15 + 0.025 * i)) end
  check("glisser : échelle de la fenêtre et ancre inchangées pendant le glisser",
    (f._nSetScale or 0) == n0 and f._scale == 1.15 and f._points[1] == pts0 and o.scale == 1.15, f._scale)
  check("glisser : aperçu = libellé 140 % et poignée au cran de 140 %",
    Um.scaleValue._text == "140%" and near(thumbX(sl), fracOf(1.4)), tostring(Um.scaleValue._text) .. " " .. thumbX(sl))
  up(sl)
  check("relâchement : échelle 1,4 appliquée une fois et enregistrée",
    f._scale == 1.4 and o.scale == 1.4 and (f._nSetScale or 0) == n0 + 1 and Um.scaleValue._text == "140%", f._scale)
  check("relâchement : glisser terminé (plus d'OnUpdate)", sl.track._scripts.OnUpdate == nil and not sl.dragging)
  local ok, r = onScreen()
  check("fenêtre entière dans l'écran après application", ok, r and table.concat(r, " "))

  -- 2. valeur juste depuis la souris à toute échelle (aller-retour : clic sur le rail)
  for _, sc in ipairs({ 1, 1.15, 1.5 }) do
    Um.setScale(sc)
    local bad = {}
    for _, v in ipairs({ 0.6, 0.75, 1, 1.15, 1.3, 1.5 }) do
      Um.setScale(sc)
      down(sl, fracOf(v))
      up(sl)
      if not near(o.scale, v) then bad[#bad + 1] = v .. " -> " .. tostring(o.scale) end
    end
    check(("échelle %.2f : clic sur le rail = valeur sous la souris (0,6 à 1,5)"):format(sc), #bad == 0, table.concat(bad, ", "))
    Um.setScale(sc)
    local before = o.speed
    down(sp, (2 - 0.5) / 2.5)
    local live = o.speed
    move(sp, (2.75 - 0.5) / 2.5)
    local live2 = o.speed
    up(sp)
    check(("échelle %.2f : vitesse d'animation juste et appliquée en direct (×2 puis ×2.75)"):format(sc),
      near(live, 2) and near(live2, 2.75) and near(o.speed, 2.75) and Um.speedValue._text == "×2.75",
      tostring(live) .. " " .. tostring(live2))
    o.speed = before
    Um.speedValue.Sync()
  end

  -- 3. un clic sur une flèche = un pas de 5 %, appliqué tout de suite, une seule fois
  Um.setScale(1)
  local n1 = f._nSetScale or 0
  H.click(Um.scalePlus)
  check("flèche + : un pas de 5 % (1 -> 1,05), une seule application",
    near(o.scale, 1.05) and near(f._scale, 1.05) and (f._nSetScale or 0) == n1 + 1 and Um.scaleValue._text == "105%", o.scale)
  H.click(Um.scaleMinus)
  check("flèche - : retour à 1", near(o.scale, 1) and (f._nSetScale or 0) == n1 + 2)

  -- 4. relâchement hors du rail (OnMouseUp non reçu) : valeur appliquée, glisser terminé
  Um.setScale(1)
  down(sl, fracOf(1))
  move(sl, fracOf(1.2))
  H.cursor = { 1590, 20 } -- loin du rail
  run(sl.track, "OnUpdate", 0.016)
  check("souris hors du rail, bouton tenu : aperçu au bout (150 %), échelle inchangée",
    f._scale == 1 and Um.scaleValue._text == "150%", tostring(f._scale) .. " " .. tostring(Um.scaleValue._text))
  H.mouseDown.LeftButton = false
  run(sl.track, "OnUpdate", 0.016)
  check("relâché hors du rail : échelle 1,5 appliquée, OnUpdate retiré, curseur libéré",
    o.scale == 1.5 and f._scale == 1.5 and sl.track._scripts.OnUpdate == nil and not sl.dragging, f._scale)
  local n2 = f._nSetScale or 0
  run(sl.track, "OnMouseUp", "LeftButton") -- OnMouseUp tardif : sans effet
  check("OnMouseUp tardif après la fin : rien de plus", (f._nSetScale or 0) == n2 and o.scale == 1.5)
  -- rail caché pendant un glisser : terminé et appliqué
  Um.setScale(1)
  down(sl, fracOf(1))
  move(sl, fracOf(0.8))
  Um.optionsFrame:Hide()
  check("options fermées pendant le glisser : valeur appliquée, glisser terminé",
    near(o.scale, 0.8) and sl.track._scripts.OnUpdate == nil and not sl.dragging, o.scale)
  H.mouseDown.LeftButton = false
  Um.optionsFrame:Show()

  -- 5. position : le centre reste en place, la position enregistrée suit l'échelle, fenêtre dans l'écran
  Um.setScale(1)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 700, 450)
  Um.setScale(1.15)
  local cx, cy = centerU()
  check("échelle 1 -> 1,15 : centre gardé (700, 450)", near(cx, 700, 0.01) and near(cy, 450, 0.01), cx .. ", " .. cy)
  local pt = o.point
  check("position enregistrée en unités de la nouvelle échelle (décalage × échelle = centre)",
    pt and pt[1] == "CENTER" and pt[2] == "BOTTOMLEFT" and near(pt[3] * 1.15, 700, 0.01) and near(pt[4] * 1.15, 450, 0.01))
  local r1 = R.rect(f)
  Um.applyScale() Um.applyPosition() -- rechargement : échelle puis position enregistrées
  local r2 = R.rect(f)
  check("rechargement : même rectangle à l'écran", near(r1[1], r2[1], 0.01) and near(r1[4], r2[4], 0.01))
  -- ancre d'un déplacement (unités de l'ancienne échelle) près du bord droit, puis agrandissement
  Um.setScale(1)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1600 - 1040, 1000)
  local bad = {}
  for _, v in ipairs({ 1.15, 1.5, 0.6, 1.3 }) do
    Um.setScale(v)
    local okv, rv = onScreen()
    if not okv then bad[#bad + 1] = v .. " : " .. table.concat(rv, " ") end
  end
  check("fenêtre collée au coin haut droit, échelle 1,15 / 1,5 / 0,6 / 1,3 : toujours entière dans l'écran",
    #bad == 0, table.concat(bad, " ; "))

  -- remise en l'état
  o.point = nil
  Um.applyPosition()
  Um.setScale(1.15)
  o.point = nil
  Um.applyPosition()
  Frame.GetLeft, Frame.GetCenter = oldLeft, oldCenter
  UIParent._w, UIParent._h = uiW, uiH
  H.mouseDown.LeftButton = false
end

print("U33 textes jamais tronqués ni recoupés par le client : cartes au repos et survolées, réponses, boutons (client défavorable)")
do
  -- Retour en jeu : « PW: Radiance » survolée en main (fenêtre à 115 %, zoom net) affichait
  -- « Gain 4 Absorb.... » sur une ligne au lieu de ses deux lignes. Le client défavorable
  -- (H.strictText) arrondit la police rendue au pixel supérieur et la hauteur automatique au plus proche.
  freshRun(SEED, "combat")
  H.settle()
  local ns = H.ns
  local W = ns.Widgets
  local frame = UI().frame
  local scale0 = frame._scale
  local mode0 = W.zoomMode()
  H.strictText = true
  W.clearTextCache()
  local function nLines(t)
    local n = 0
    for _ in ((t or "") .. "\n"):gmatch("(.-)\n") do n = n + 1 end
    return n
  end
  -- texte posé (lignes choisies par la mise en page) : ni tronqué, ni recoupé
  local function textBad(fs)
    if not fs or not fs._shown or (fs._text or "") == "" then return nil end
    local want = nLines(fs._text)
    if fs:IsTruncated() then return "tronqué (" .. fs:GetNumLines() .. "/" .. want .. " lignes)" end
    if fs:GetNumLines() ~= want then return "recoupé (" .. fs:GetNumLines() .. "/" .. want .. " lignes)" end
    return nil
  end
  local function cardBad(c, label, out)
    local list = { { "nom", c.name }, { "coût", c.cost }, { "texte", c.body }, { "plaque", c.plateText } }
    if c.reasonPlate and c.reasonPlate._shown then list[#list + 1] = { "raison", c.reasonPlate.text } end
    for _, it in ipairs(list) do
      local why = textBad(it[2])
      if why then
        out[#out + 1] = ("%s : %s « %s » %s"):format(label, it[1],
          tostring(it[2]._text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "⌛"):gsub("\n", " / "), why)
      end
    end
  end
  local ids = {}
  for id in pairs(ns.Cards) do ids[#ids + 1] = id end
  table.sort(ids)
  local SCALES = { 1, 1.15, 1.5, 0.6 }
  -- (1) toutes les cartes, base et améliorées, jouables et injouables : échelle de la fenêtre, échelle
  -- réelle du visuel à la pose (1 : modes net et lisse ; échelle de survol : mode fluide), puis affichée
  -- au repos et survolée ; écrans : main (survol 1,16), récompense (1,08 × 1,17), grille (0,75 × 1,2),
  -- marchand (0,92 × 1,12)
  local holder = CreateFrame("Frame", nil, UI().content)
  local card = W.card(holder)
  local SCREENS = { { "main", 1, 1.16 }, { "récompense", 1.08, 1.17 }, { "grille", 0.75, 1.2 }, { "marchand", 0.92, 1.12 } }
  local VARS = { { "", { playable = true } }, { " (injouable)", { playable = false, reason = "Not enough mana." } } }
  local bad, cases = {}, 0
  for _, ws in ipairs(SCALES) do
    frame:SetScale(ws)
    for _, sc in ipairs(SCREENS) do
      holder:SetScale(sc[2])
      local hs = sc[3]
      for _, id in ipairs(ids) do
        for _, up in ipairs({ false, true }) do
          for _, var in ipairs(VARS) do
            for _, at in ipairs({ 1, hs }) do
              card.face:SetScale(at)
              card:SetCard(id, up, var[2])
              for _, view in ipairs({ 1, hs }) do
                card.face:SetScale(view)
                cases = cases + 1
                cardBad(card, ("%s%s%s, fenêtre %.2f, %s, pose ×%.2f, vue ×%.2f"):format(id, up and "+" or "", var[1],
                  ws, sc[1], at, view), bad)
              end
            end
          end
        end
      end
    end
  end
  holder:SetScale(1)
  card:Hide()
  local function head(t, n)
    local out = {}
    for i = 1, math.min(#t, n) do out[i] = t[i] end
    if #t > n then out[#out + 1] = ("… (%d en tout)"):format(#t) end
    return table.concat(out, "\n        ")
  end
  check(("%d cartes × base/améliorée × jouable/injouable × fenêtre 1 / 1,15 / 1,5 / 0,6 × 4 écrans, au repos et survolées (%d cas) : aucun texte tronqué ni recoupé")
    :format(#ids, cases), #bad == 0, head(bad, 12))
  -- (2) la carte de la capture, en main, par le vrai survol, dans les trois modes de zoom
  local v = V()
  local hc = v.cards[1]
  local bad2 = {}
  for _, mode in ipairs(W.ZOOM_MODES) do
    W.setZoomMode(mode)
    for _, ws in ipairs(SCALES) do
      frame:SetScale(ws)
      for _, up in ipairs({ false, true }) do
        hc:SetCard("radiance", up, { playable = true })
        hc:Show()
        W.animSet(hc, "hover", 1)
        cardBad(hc, ("%s, fenêtre %.2f, survolée ×%.3f"):format(mode, ws, hc.face._scale * H.visualScale(hc.face)), bad2)
        W.animSet(hc, "hover", 0)
        cardBad(hc, ("%s, fenêtre %.2f, au repos ×%.3f"):format(mode, ws, hc.face._scale * H.visualScale(hc.face)), bad2)
      end
    end
  end
  check("« PW: Radiance » en main, survolée et au repos, zoom net / fluide / lisse, fenêtre 0,6 à 1,5 : deux lignes entières",
    #bad2 == 0, head(bad2, 8))
  -- garde-fou en jeu : un texte que le client tronque malgré tout fait descendre la carte d'un palier
  if not W.checkCardTexts then
    check("garde-fou : texte tronqué après la pose ou le zoom -> un palier plus bas (W.checkCardTexts)", false, "absent")
  else
    local c = W.card(holder)
    c:SetCard("radiance", false, { playable = true })
    local s0 = c.bodyFit.size
    local orig = c.body.IsTruncated
    c.body.IsTruncated = function() return true end
    W.checkCardTexts(c)
    c.body.IsTruncated = orig
    local log = W.truncatedLog()
    check("garde-fou : texte tronqué après la pose ou le zoom -> un palier plus bas, relevé pour /slay text",
      c.bodyFit.size < s0 and #log > 0 and log[#log]:find("PW: Radiance", 1, true) ~= nil,
      tostring(c.bodyFit.size) .. " / " .. tostring(log[#log]))
    local chat = rawget(_G.DEFAULT_CHAT_FRAME, "_lines")
    local n0 = #chat
    H.slash("text")
    local said = {}
    for i = n0 + 1, #chat do said[#said + 1] = chat[i] end
    local joined = table.concat(said, "\n")
    check("/slay text : textes tronqués listés", joined:find("PW: Radiance", 1, true) ~= nil, joined)
    c:Hide()
  end
  -- (3) réponses des rencontres (libellé dans le bouton, texte dessous) et feu de camp
  freshRun(SEED + 4, "event")
  frame = UI().frame
  local s = UI().current
  local b = s.buttons[1]
  local bad3, cases3 = {}, 0
  local evIds = {}
  for id in pairs(ns.Events) do evIds[#evIds + 1] = id end
  table.sort(evIds)
  local function tryOpt(label, o, w, h)
    for _, ws in ipairs(SCALES) do
      frame:SetScale(ws)
      b.face:SetScale(1)
      b:SetOption(o, w, h)
      for _, view in ipairs({ 1, 1.04 }) do
        b.face:SetScale(view)
        cases3 = cases3 + 1
        for _, it in ipairs({ { "libellé", b.label }, { "texte", b.sub } }) do
          local why = textBad(it[2])
          if why then bad3[#bad3 + 1] = ("%s, fenêtre %.2f, ×%.2f : %s « %s » %s"):format(label, ws, view, it[1],
            tostring(it[2]._text):gsub("\n", " / "), why) end
        end
      end
    end
  end
  for _, id in ipairs(evIds) do
    local ev = ns.Events[id]
    local n = math.min(#ev.choices, #s.buttons)
    local span = n <= 2 and 668 or (n == 3 and 900 or 980)
    local gap = n <= 2 and 28 or 22
    local w = (span - (n - 1) * gap) / math.max(n, 1)
    local h = n >= 4 and 112 or 118
    for i = 1, n do
      local ch = ev.choices[i]
      tryOpt(id .. "/" .. i, { id = "x", label = ch.label, text = ch.hidden and "?" or (ch.outcome or ch.text or "") }, w, h)
    end
  end
  tryOpt("feu : se reposer", { id = "rest", label = "Rest", text = "+21 HP" }, 240, 104)
  tryOpt("bandits", { id = "x", label = "Charge the bandits", text = "Fight: usual reward + 20g" }, 285.3, 118)
  check(("%d rencontres, réponses aux fenêtres 1 / 1,15 / 1,5 / 0,6, au repos et survolées (%d cas) : libellé et texte entiers")
    :format(#evIds, cases3), #bad3 == 0, head(bad3, 12))
  -- (4) libellés des boutons et autres textes des visuels survolables créés jusqu'ici (une ligne, largeur
  -- libre) : entiers à toute échelle de fenêtre, au repos et survolés
  local bad4, n4 = {}, 0
  for _, o in ipairs(H.objects) do
    local face = rawget(o, "_parent")
    local owner = face and rawget(face, "_parent")
    if rawget(o, "_kind") == "FontString" and owner and rawget(owner, "face") == face and rawget(owner, "_hoverable")
      and (rawget(o, "_text") or "") ~= "" then
      n4 = n4 + 1
      for _, ws in ipairs(SCALES) do
        frame:SetScale(ws)
        local s0 = face._scale
        for _, view in ipairs({ 1, owner.hoverScale or 1.06 }) do
          face._scale = view
          local why = textBad(o)
          if why then bad4[#bad4 + 1] = ("« %s », fenêtre %.2f, ×%.2f : %s"):format(tostring(o._text):gsub("\n", " / "), ws, view, why) end
        end
        face._scale = s0
      end
    end
  end
  check(("%d textes des visuels survolables (boutons, plaques, jetons…) : entiers aux fenêtres 1 / 1,15 / 1,5 / 0,6, au repos et survolés")
    :format(n4), n4 > 20 and #bad4 == 0, head(bad4, 12))
  H.strictText = false
  W.clearTextCache()
  W.setZoomMode(mode0)
  frame:SetScale(scale0)
end

print("U16 méthodes d'API inconnues appelées")
local names = {}
for k in pairs(H.unknown) do names[#names + 1] = k end
table.sort(names)
check("aucune méthode inconnue", #names == 0, table.concat(names, ", "))

print(("%d vérifications, %d échec(s)"):format(checks, failures))
print(failures == 0 and "ALL PASS" or "FAILED")
os.exit(failures == 0 and 0 or 1)
