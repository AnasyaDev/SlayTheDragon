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
SetScaleAnimationMode SetSmoothScaling SetOrigin SetSmoothing
]]):gmatch("%S+") do NOOP[name] = true end

local Frame = {}
Frame.__index = function(self, k)
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

-- Visibilité
function Frame:Show()
  if not self._shown then
    self._shown = true
    run(self, "OnShow")
  end
end
function Frame:Hide()
  if self._shown then
    self._shown = false
    run(self, "OnHide")
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
function Frame:SetAllPoints() self._points = { { "ALL" } } end
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
function Frame:SetScale(s) self._scale = s end
function Frame:GetScale() return self._scale end
function Frame:GetEffectiveScale()
  local s, o = 1, self
  while o do s = s * (o._scale or 1) o = o._parent end
  return s
end
function Frame:SetFrameLevel(l) self._level = l end
function Frame:GetFrameLevel() return self._level end
function Frame:GetParent() return self._parent end
function Frame:SetParent(p) self._parent = p end
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
function Frame:Play()
  self._playing, self._t0 = true, H.now
  H.playingGroups[self] = true
end
function Frame:Stop() self._playing = false H.playingGroups[self] = nil end
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
-- Largeur d'un texte d'une ligne (sans codes) à la taille size, police de self.
function H.textWidth(self, text, size)
  local adv, w = fontAdv(self), 0
  for ch in plainText(text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do w = w + (adv[ch] or 550) end
  return w / 1000 * (size or rawget(self, "_fontSize") or 12)
end
-- Taille de police rendue (unités du texte) : sans SetSmoothScaling(true), le client arrondit la
-- hauteur de police effective au pixel entier (ici : taille × échelle effective arrondie), ce qui
-- change largeurs et coupures quand l'échelle réelle change ; avec, elle est proportionnelle.
function H.renderSize(self)
  local size = rawget(self, "_fontSize") or 12
  local c = rawget(self, "_calls").SetSmoothScaling
  if c and c[1] == true then return size end
  local e = self:GetEffectiveScale()
  if e <= 0 then return size end
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
  if h > 0 and #out * size * METRICS.lineHeight > h + 0.01 then trunc = true end
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
  R.ui_test_charm = { name = "Breloque d'essai", text = "Bibelot du harnais (sans effet).", rarity = "common", tier = 0 }
  R.ui_test_idol = { name = "Idole d'essai", text = "Bibelot du harnais (sans effet).", rarity = "uncommon", tier = 0 }
  R.ui_test_lens = { name = "Loupe d'essai", text = "Bibelot du harnais (sans effet).", rarity = "rare", tier = 0 }
  R.ui_test_trophy = { name = "Trophée d'essai", text = "Bibelot de boss du harnais.", rarity = "boss", tier = 0 }
  R.ui_test_symbol = { name = "Symbole d'essai", text = "Bibelot de classe du harnais.", rarity = "rare", tier = 0,
    class = "priest" }
  P.ui_test_heal = { name = "Potion de soins d'essai", text = "Rends 10 PV.", rarity = "common", tier = 0, effects = {} }
  P.ui_test_bomb = { name = "Bombe d'essai", text = "Inflige 10 dégâts à un ennemi.", rarity = "common", tier = 0,
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
      local fight = (o.text or ""):find("Combat", 1, true)
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
check("échelle +5 %", math.abs(_G.SlayTheDragonFrame._scale - 1.05) < 1e-9, _G.SlayTheDragonFrame._scale)
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
check("clic sur une clé verrouillée : message", UI().err._shown and (UI().err._text or ""):find("victoire", 1, true), UI().err._text)
tt = H.hover(button("key:2"))
check("infobulle d'une clé : affixes", table.concat(tt, " "):find("Tyrannique", 1, true), table.concat(tt, " | "))
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
check("nœud inaccessible : refus", EXP().node == nil and UI().err._text == "Étape inaccessible.", UI().err._text)
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
          for _, l in ipairs(tt) do if l:find(" : ", 1, true) then kl = kl + 1 end end
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
        check("carte injouable : « Pas assez de mana. »", UI().err._text == "Pas assez de mana.", UI().err._text)
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
    check("texte « Carte ajoutée »", (UI().step.text or ""):find("Carte ajoutée", 1, true), UI().step.text)
  elseif k == "end" then
    finished = true
    break
  else
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
check("texte du bilan : réputation", (step.text or ""):find("réputation", 1, true), step.text)
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
  and UI().current.bars[2].label._text == "Ligue des explorateurs")
check("méta : journal", UI().current.journal[1]._shown and (UI().current.journal[1]._text or ""):find("Prêtre", 1, true),
  UI().current.journal[1]._text)
check("méta : clés ouvertes", (UI().current.bars[1].detail._text or ""):find("Clés ouvertes", 1, true))
clickOption("ui:back")
check("retour au bilan", currentKind() == "end", currentKind())
clickOption("ui:new")
check("accueil", currentKind() == "start", currentKind())
local keyMax = db.meta.classes.priest.keyMax
check("clé par défaut = la plus haute ouverte", UI().step.key == keyMax and option("key:" .. keyMax).selected)
check("dernière expédition rappelée", (UI().step.text or ""):find("Dernière expédition", 1, true))
ns = H.ns
ns.Controller.makeSeed = function() return SEED + 1 end
H.key("ENTER")
exp = EXP()
check("nouvelle expédition à la clé " .. keyMax, exp and exp.key == keyMax and #exp.affixes == keyMax)
if keyMax > 0 then
  check("clé mythique dans le bandeau (hexagone violet « +N »)", UI().keystone._shown and UI().keystone.count._text == "+" .. keyMax)
  tt = H.hover(UI().keystone)
  check("infobulle de la clé : affixes", table.concat(tt, " "):find("Fortifié", 1, true), table.concat(tt, " | "))
  check("affixes dans le texte de la carte", (UI().step.text or ""):find("Fortifié", 1, true))
end

print("U8  potions et bibelots : bandeau, défausse, boire en combat")
exp.potions = { "ui_test_heal", "ui_test_bomb", false }
exp.relics[#exp.relics + 1] = "ui_test_charm"
UI().refresh()
check("bibelot dans le bandeau", UI().relicIcons[UI().RELICS_SHOWN]._shown)
tt = H.hover(UI().relicIcons[UI().RELICS_SHOWN])
check("infobulle du bibelot : nom et texte", tt[1] == "Breloque d'essai" and table.concat(tt, " "):find("sans effet", 1, true),
  table.concat(tt, " | "))
tt = H.hover(UI().potionSlots[1])
check("infobulle de potion", tt[1] == "Potion de soins d'essai", tt[1])
H.click(UI().potionSlots[1])
check("hors combat : on ne boit pas", UI().err._text == "Les potions se boivent en combat.", UI().err._text)
exp.potions[3] = "ui_test_heal"
H.click(UI().potionSlots[3], "RightButton")
check("premier clic droit : confirmation demandée", exp.potions[3] == "ui_test_heal" and (UI().err._text or ""):find("jeter", 1, true))
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
check("potion à cible : choix de la cible demandé", V().potionSlot == 2 and (UI().err._text or ""):find("cible", 1, true))
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
check("infobulle d'un bibelot en vente : prix", table.concat(tt, " "):find(relicOpt.price .. " po", 1, true), table.concat(tt, " | "))
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
  and UI().step.options[1].reason == "Pas assez d'or.", UI().step.options[1].reason)
H.click(UI().current.cards[1])
check("clic sur un article trop cher : message", UI().err._text == "Pas assez d'or.", UI().err._text)
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
check("repos : PV rendus calculés par le moteur", option("rest").text == "Rend " .. heal .. " PV.", option("rest").text)
clickOption("ui:upgrade")
check("grille d'amélioration", currentKind() == "deck" and #UI().current.cardOptions >= 1)
snap("amelioration")
tt = H.hover(UI().current.cards[1])
check("aperçu « Après amélioration »", table.concat(tt, " "):find("Après amélioration", 1, true), table.concat(tt, " | "))
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
    if not pick and not o.disabled and not (o.text or ""):find("Combat", 1, true) then pick = i end
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
check("accueil malgré un journal ancien", currentKind() == "start" and (UI().step.text or ""):find("Dernière", 1, true))
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
check("message de mise de côté à l'accueil", (UI().step.text or ""):find("mise de côté", 1, true))
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
H.slash("modeles")
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

print("U17 décors : peint par défaut, essai manuel (suivant, ok, non, peint), verdicts gardés")
do
  local function chat() return table.concat(_G.DEFAULT_CHAT_FRAME._lines, "\n") end
  local function clearChat() _G.DEFAULT_CHAT_FRAME._lines = {} end
  -- Même quand tous les fichiers « répondent » (SetTexture, FileID, chargement), rien n'est affiché
  -- sans validation : sur Forever un fichier absent répond pareil et s'affiche en aplat vert.
  H.badFiles, H.badPaths, H.unloaded = nil, {}, nil
  H.boot(nil)
  H.slash("")
  local Sc = H.ns.Scene
  local fields = Sc.paints.fields[1]
  check("accueil : décor de la route", Sc.scene == "road" and Sc.decor._shown)
  check("par défaut : décor peint, aucune illustration", not Sc.art._shown and fields._shown
    and H.ns.Persist.options().decor == true)
  for id, entry in pairs(H.ns.Art.scenes) do
    if Sc.chosen(entry) ~= nil then check("décor " .. id .. " : rien de choisi par défaut", false) end
  end
  check("plus aucune sonde automatique", Sc.illus == nil and Sc.resolveAll == nil and Sc.probeFrame == nil)
  clearChat()
  H.slash("art")
  local said = chat()
  check("/slay art : décors peints par défaut", said:find("road : peint (aucun des 4 candidats validé)", 1, true)
    and said:find("mine : peint (aucun des 3 candidats validé)", 1, true)
    and said:find("coast : peint (pas d'illustration)", 1, true), said)
  check("/slay art : aucun verdict", said:find("validés : aucun", 1, true) and said:find("refusés : aucun", 1, true)
    and said:find("pas encore jugés : 8 sur 8", 1, true), said)

  -- Liste d'essai : toutes les illustrations, dédoublonnée (les ruines reprennent Elwynn).
  local list = Sc.trialList()
  local keys, dup = {}, false
  for _, c in ipairs(list) do
    if keys[tostring(c.file)] then dup = true end
    keys[tostring(c.file)] = true
  end
  check("liste d'essai : 8 candidats sans doublon", #list == 8 and not dup, #list)
  check("liste d'essai : écrans classiques et Forever", keys["131839"] and keys["131833"] and keys["7963776"]
    and keys["7963777"] and keys["7963782"] and keys["7377860"])

  clearChat()
  H.slash("decor essai")
  said = chat()
  check("essai : candidat 1 affiché sur le décor courant", Sc.trial == 1 and Sc.art._shown
    and Sc.art._texture == list[1].file, Sc.art._texture)
  check("essai : sans teinte ni voile", Sc.art._calls.SetVertexColor[1] == 1 and Sc.art._calls.SetVertexColor[3] == 1
    and Sc.veil._calls.SetColorTexture[4] == 0)
  check("essai : numéro, fichier, nom et mode d'emploi", said:find("essai du décor 1/8 : " .. tostring(list[1].file)
    .. " — " .. list[1].name .. " [pas encore jugé]", 1, true) and said:find("/slay decor ok", 1, true), said)
  clearChat()
  H.slash("decor suivant")
  check("suivant : candidat 2", Sc.trial == 2 and Sc.art._texture == list[2].file
    and chat():find("essai du décor 2/8 : " .. tostring(list[2].file), 1, true), chat())
  H.slash("decor precedent")
  H.slash("decor precedent")
  check("précédent depuis le 1er : retour au dernier", Sc.trial == 8 and Sc.art._texture == list[8].file)
  H.slash("decor suivant")
  check("suivant depuis le dernier : retour au 1er", Sc.trial == 1)

  -- Verdicts : le 1er refusé, puis on valide le premier candidat de la liste d'Elwynn qui n'est pas
  -- le 1er de la liste d'essai, pour vérifier que chaque décor prend le premier validé de SA liste.
  local elwynn = Sc.candidates("elwynn")
  local deadmines = Sc.candidates("deadmines")
  clearChat()
  H.slash("decor non")
  check("non : refusé et dit", H.ns.Persist.options().artChecks[tostring(list[1].file)] == false
    and chat():find(tostring(list[1].file) .. " refusé", 1, true), chat())
  local function goTo(file)
    for _ = 1, #list do
      if Sc.trialList()[Sc.trial].file == file then return true end
      H.slash("decor suivant")
    end
    return false
  end
  check("aller au 3e candidat d'Elwynn", goTo(elwynn[3].file))
  clearChat()
  H.slash("decor ok")
  check("ok : validé et dit", H.ns.Persist.options().artChecks[tostring(elwynn[3].file)] == true
    and chat():find(tostring(elwynn[3].file) .. " validé", 1, true), chat())
  goTo(elwynn[1].file)
  H.slash("decor non")
  goTo(elwynn[4].file)
  H.slash("decor ok")
  goTo(deadmines[3].file)
  H.slash("decor ok")
  check("en essai, le décor montre le candidat essayé", Sc.art._texture == deadmines[3].file)

  clearChat()
  H.slash("decor peint")
  check("peint : fin de l'essai, décor peint", Sc.trial == nil and not Sc.art._shown and fields._shown
    and H.ns.Persist.options().decor == false, chat())
  H.slash("decor illustre")
  check("illustre : la route montre le premier validé de sa liste", H.ns.Persist.options().decor == true
    and Sc.art._shown and Sc.art._texture == elwynn[3].file)
  check("recadrage et teinte du décor", math.abs(Sc.art._calls.SetTexCoord[3] - elwynn[3].crop[3]) < 1e-9
    and math.abs(Sc.art._calls.SetVertexColor[2] - H.ns.Art.scenes.road.tint[2]) < 1e-9)
  check("voile de l'accueil rétabli", math.abs(Sc.veil._calls.SetColorTexture[4] - 0.2) < 1e-9)
  Sc.set({ scene = "mine", board = true })
  check("boss : premier validé de la liste des Mortemines", Sc.art._shown and Sc.art._texture == deadmines[3].file)
  Sc.set({ scene = "ruins", board = true })
  check("ruines : la liste d'Elwynn sert de suite", Sc.art._texture == elwynn[3].file)
  Sc.set({ scene = "coast", board = true })
  check("côte : toujours peinte", not Sc.art._shown and Sc.paints.coast[1]._shown)
  Sc.set({ scene = "road", board = true, veil = 0.2 })
  H.slash("decor")
  check("/slay decor seul : bascule vers peint", H.ns.Persist.options().decor == false and not Sc.art._shown)
  H.slash("decor")
  check("/slay decor seul : bascule vers illustré", H.ns.Persist.options().decor == true and Sc.art._shown)
  H.slash("decor essai")
  H.slash("decor essai")
  check("essai deux fois : bascule (essai fermé)", Sc.trial == nil and Sc.art._texture == elwynn[3].file)
  clearChat()
  H.slash("decor ok")
  check("ok hors essai : rien, message", chat():find("aucun essai en cours", 1, true), chat())

  clearChat()
  H.slash("art")
  said = chat()
  check("/slay art : candidat validé par décor", said:find("road : " .. tostring(elwynn[3].file) .. " — "
    .. elwynn[3].name, 1, true) and said:find("mine : " .. tostring(deadmines[3].file), 1, true), said)
  check("/slay art : validés et refusés", said:find("validés : " .. tostring(deadmines[3].file) .. " (", 1, true)
    and said:find(tostring(elwynn[4].file) .. " (", 1, true)
    and said:find("refusés : " .. tostring(deadmines[1].file) .. " (", 1, true)
    and said:find(tostring(elwynn[1].file) .. " (" .. elwynn[1].name .. ")", 1, true)
    and said:find("pas encore jugés : 3 sur 8", 1, true), said)

  -- Persistance : verdicts relus au rechargement, essai non repris.
  local saved = deepcopy(_G.SlayTheDragonDB)
  local okData = plainData(saved, nil, "SlayTheDragonDB")
  check("verdicts : données simples dans la sauvegarde", okData)
  H.boot(saved)
  H.slash("")
  Sc = H.ns.Scene
  check("rechargement : verdicts gardés", H.ns.Persist.options().artChecks[tostring(elwynn[3].file)] == true
    and H.ns.Persist.options().artChecks[tostring(elwynn[1].file)] == false)
  check("rechargement : la route montre le validé, pas d'essai", Sc.trial == nil and Sc.art._shown
    and Sc.art._texture == elwynn[3].file)
  -- Écran sans décor (parcours) : l'essai prévient où le voir.
  clickOption("go")
  check("parcours : pas de décor", Sc.scene == false)
  clearChat()
  H.slash("decor essai")
  check("essai sur le parcours : message", chat():find("cet écran n'a pas de décor", 1, true)
    and chat():find("essai du décor", 1, true), chat())
  check("essai : départ au premier candidat pas encore jugé", Sc.trial and Sc.verdict(list[Sc.trial]) == nil)
  H.slash("decor peint")
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
    probe:SetText("Inflige 6 points de dégâts.")
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
  -- /slay zoom : bascule « lisse » (échelle réelle à chaque image) et retour
  H.slash("zoom")
  check("/slay zoom : mode lisse", H.ns.Persist.options().zoom == "lisse")
  local eb = v.endTurn
  run(eb, "OnEnter")
  run(driver, "OnUpdate", 0.04)
  check("mode lisse : échelle réelle du visuel animée, sans animation Scale", eb.face._scale > 1
    and eb.face._scale < eb.hoverScale and H.visualScale(eb.face) == 1, eb.face._scale)
  run(eb, "OnLeave")
  H.advance(0.5)
  check("mode lisse : repos exact", eb.face._scale == 1)
  H.slash("zoom net")
  check("/slay zoom net : retour au défaut", H.ns.Persist.options().zoom == "net")
  H.slash("zoom lisse")
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
  check("compteur total dans le titre", (Dv.title._text or ""):find(#exp.deck .. " cartes", 1, true), Dv.title._text)
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
    "gem_uncommon", "gem_rare", "gem_epic", "gem_legendary", "hex_red", "hex_green", "hex_blue", "hex_steel",
    "hex_violet", "hex_empty", "card_back", "tile_slate", "tile_ivory", "nine_slate", "nine_rim", "nine_ivory",
    "pill_slate", "pill_rim", "button_gold" }) do
    if not Skin.tex[need] then bad[#bad + 1] = need end
  end
  check("pièces attendues présentes (corps, ruban, coût, médaillon, gemmes, hexagones, ardoise, ivoire, liserés)",
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
    and tex(card.ring) == ROOT .. Skin.tex.medal_ring.file and card.cost._text == "2" and card.name._text == "Pénitence"
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
    and card.plate.shown and (card.plateText._text or ""):find("Recharge", 1, true) and not card.gem._shown)
  card:SetCard("inner_fire", false, { cost = 1, playable = true })
  check("protection : corps bleu ; carte de base sans gemme ni plaque", tex(card.bg) == ROOT .. Skin.tex.card_body_blue.file
    and not card.gem._shown and not card.plate.shown)
  card:SetCard("smite", false, { cost = 1, playable = true })
  check("départ : corps doré", tex(card.bg) == ROOT .. Skin.tex.card_body_gold.file)
  card:SetCard("smite", false, { cost = 3, playable = false, reason = "Pas assez de mana." })
  check("injouable : corps grisé, raison dans une plaque rouge", card.bg._calls.SetDesaturated[1] == true
    and card.reasonPlate and card.reasonPlate._shown and card.reasonPlate.text._text == "Pas assez de mana.")
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
  check("bulle d'intention : pilule d'ardoise au liseré teinté", slot and slot.intent.plaque and slot.intent._shown
    and (slot.intent.text._text or "") ~= "")
  check("mana : hexagone bleu et un point par mana", v.mana.text._text == tostring(C().combat().player.mana)
    and v.mana.pips[1]._shown)
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
    and table.concat(W.models.sorcerer.tries, ", ") == "créature 619, affichage 2329, affichage 2330"
    and W.models.murloc.via == "affichage 983")
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
  check("OnModelLoaded suffit à valider un essai", W.models.gnoll.state == "ok" and W.models.gnoll.via == "créature 117"
    and not so.fallback._shown)
  -- sans icône : disque sombre (silhouette), jamais le point d'interrogation
  W.setFallbackArt(so.fallback, nil)
  check("repli sans icône : disque sombre", so.fallback.icon._texture == nil and so.fallback.icon._calls.SetColorTexture
    and so.fallback.icon._calls.SetColorTexture[1] == Art.C.slateDark[1])

  -- /slay modeles : une ligne recopiable par modèle absent (ennemis et PNJ)
  H.badCreatures = { [619] = true, [639] = true, [235] = true }
  H.badDisplays = { [2329] = true, [2330] = true, [1691] = true }
  _G.DEFAULT_CHAT_FRAME._lines = {}
  H.slash("modeles")
  H.advance(3.5)
  local said = table.concat(_G.DEFAULT_CHAT_FRAME._lines, "\n")
  local total = 0
  for _ in pairs(Art.enemies) do total = total + 1 end
  for _ in pairs(Art.npcs) do total = total + 1 end
  check("/slay modeles : bilan chiffré", said:find("modèles : " .. (total - 2) .. "/" .. total .. " chargés, 2 sans modèle", 1, true), said)
  check("/slay modeles : ennemi manquant et identifiants essayés",
    said:find("sorcerer : créature 619, affichage 2329, affichage 2330 -> aucun modèle", 1, true), said)
  check("/slay modeles : PNJ manquant", said:find("npc:salma_saldean : créature 235, affichage 1691 -> aucun modèle", 1, true), said)
  check("/slay modeles : modèle chargé par un repli signalé", said:find("vancleef : créature 639 -> aucun modèle ; chargé par affichage 2029", 1, true), said)
  check("/slay modeles : un PNJ et tous les ennemis dans l'aperçu", #V().preview.models == total)
  local stateOk = true
  for _, m in ipairs(V().preview.models) do
    local want = (m.key == "sorcerer" or m.key == "npc:salma_saldean") and "aucun modèle" or "modèle : "
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
          if tr[3] - tr[1] + 0.5 < (s.name:GetStringWidth() or 0) * s.name:GetEffectiveScale() then bad[#bad + 1] = label .. " : nom plus large que sa pilule" end
          local mr = R.rect(s.model)
          if mr and tr[4] > mr[2] + 0.5 then bad[#bad + 1] = label .. " : pilule du nom sur le personnage" end
          local hr = R.rect(s.hp)
          if hr and tr[2] < hr[4] then bad[#bad + 1] = label .. " : pilule du nom sur la jauge" end
          if flevel(s.tag) <= flevel(s.model) or flevel(s.tag) <= flevel(s.hp) or flevel(s.tag) <= flevel(s.fallback) then
            bad[#bad + 1] = label .. " : pilule du nom sous le modèle, la jauge ou le repli"
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
            if inter(t, tr) then bad[#bad + 1] = label .. " : chevauche un autre nom" end
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
    { key = " (injouable)", opts = { playable = false, reason = "Pas assez de mana." } },
  }
  -- toutes les raisons d'une carte injouable en combat (les plus longues passent sur deux lignes)
  for _, why in ipairs({ "phase", "unplayable", "casting", "forbidden", "condition", "target", "over" }) do
    variants[#variants + 1] = { key = " (" .. why .. ")", opts = { playable = false, reason = ns.Controller.reasonText(why) } }
  end
  local reasonDist = {}
  local cases = 0
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
  print("      texte sous le plancher (" .. W.BODY_SIZES[#W.BODY_SIZES] .. ") : "
    .. (#under > 0 and table.concat(under, ", ") or "aucune"))
  print("      nom sous le plancher (" .. W.NAME_SIZES[#W.NAME_SIZES] .. ") : "
    .. (#nameUnder > 0 and table.concat(nameUnder, ", ") or "aucun"))
  check("paliers : la plupart des cartes au premier palier du texte", (bodyDist[W.BODY_SIZES[1]] or 0) * 2 > #ids * 2)
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
      { "penance", false, { playable = false, reason = "Pas assez de mana." } },
      { "spirit_of_redemption", true, { playable = true } }, { "solace", true, { playable = true } },
      { "mind_blast", false, { playable = true } }, { "smite", false, { playable = true } } }
    for i, e in ipairs(list) do
      local c = W.card(sheet)
      c:SetCard(e[1], e[2], e[3])
      W.placeCenter(c, sheet, 80 + (i - 1) * 140, 125, 1)
    end
    Render.svg(H, sheet, SNAP .. "/cartes.svg", "cartes")
    sheet:Hide()
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
    return rawget(t, "_kind") == "Texture" and type(tex) == "string" and tex:find("glow", 1, true) ~= nil
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
    c2:SetCard(c2.cardId, c2.cardUp, { playable = false, reason = "Pas assez de mana" })
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

print("U24 plaques de réponse : toutes les réponses de Data/Events.lua dans la zone utile (marges, paliers, coupures)")
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
    local zw = w - 2 * O.mx
    local why = {}
    if not fit.ok then why[#why + 1] = "ne tient à aucun palier" end
    for _, fs in ipairs({ b.label, b.sub }) do
      if fs._shown and (fs._text or "") ~= "" then
        local ls = lines(fs._text)
        for _, l in ipairs(ls) do
          if H.textWidth(fs, l, fs._fontSize) > zw + 0.01 then why[#why + 1] = "« " .. l .. " » plus large que la zone" end
        end
        if fs:IsTruncated() or fs:GetNumLines() ~= #ls then why[#why + 1] = "recoupé par le client" end
      end
    end
    if fit.block > h - 2 * O.my + 0.01 then why[#why + 1] = "bloc trop haut" end
    local pt = b.label._points[1]
    if pt and -pt[5] < O.my - 0.01 then why[#why + 1] = "libellé collé au haut" end
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
      if e[1] == "pay" then return X.EVENT_REASONS["or"] or "Pas assez d'or." end
    end
    return "Il faut au moins 50 % des PV."
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
  try("feu : se reposer", { id = "rest", label = "Se reposer", text = "+21 PV" }, 240, 104)
  try("feu : s'entraîner", { id = "u", label = "S'entraîner", text = "Améliore une carte" }, 240, 104)
  check(("%d rencontres (%d cas de réponse, possibles et impossibles) : libellé et texte dans la zone utile, marges de %d unités")
    :format(#ids, cases, O.mx), #bad == 0, table.concat(bad, "\n        "))
  local dl = {}
  for k, n in pairs(dist) do dl[#dl + 1] = k .. " : " .. n end
  table.sort(dl)
  print("      texte des réponses (taille × lignes) : " .. table.concat(dl, ", "))
  print("      sur plusieurs lignes : " .. (#multi > 0 and table.concat(multi, ", ") or "aucune"))
  -- la réponse de la capture : une coupure propre, loin des bords
  try("bandits", { id = "x", label = "Charger les bandits", text = "Combat : récompense habituelle + 20 po" }, 285.3, 118)
  local ls = lines(b.sub._text)
  local widest = 0
  for _, l in ipairs(ls) do widest = math.max(widest, H.textWidth(b.sub, l, b.sub._fontSize)) end
  check("« Combat : récompense habituelle + 20 po » : lignes équilibrées, au moins 16 unités des bords",
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

print("U16 méthodes d'API inconnues appelées")
local names = {}
for k in pairs(H.unknown) do names[#names + 1] = k end
table.sort(names)
check("aucune méthode inconnue", #names == 0, table.concat(names, ", "))

print(("%d vérifications, %d échec(s)"):format(checks, failures))
print(failures == 0 and "ALL PASS" or "FAILED")
os.exit(failures == 0 and 0 or 1)
