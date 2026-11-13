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
SetTextureSliceMargins SetTextureSliceMode SetModelScale SetPosition SetKeepModelOnHide
]]):gmatch("%S+") do NOOP[name] = true end

local Frame = {}
-- Méthodes propres aux textures (SimpleTextureBaseAPI) : absentes des textes et des cadres, comme dans
-- le jeu (l'interface teste leur existence).
-- Découpe par le client (SetTextureSliceMargins, WoW Forever comme Retail) : H.noSlice = true simule un
-- client sans cette API (repli de l'interface en tranches séparées, UB).
local TEXTURE_ONLY = { SetSnapToPixelGrid = true, SetTexelSnappingBias = true, SetTextureSliceMargins = true,
  SetTextureSliceMode = true }
local SLICE_API = { SetTextureSliceMargins = true, SetTextureSliceMode = true }
local TEXTURE_KINDS = { Texture = true, MaskTexture = true, Line = true }
Frame.__index = function(self, k)
  if TEXTURE_ONLY[k] and not TEXTURE_KINDS[rawget(self, "_kind")] then return nil end
  if SLICE_API[k] and H.noSlice then return nil end
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
-- taille de police = cadratin, hauteur de ligne = TAILLE DE POLICE (1 cadratin, H.LINE_EM) ; codes
-- |c…|r ignorés ; retours explicites, puis retour à la ligne par mots si une largeur est posée.
-- Hauteur de ligne : le fichier généré donne ascendante + descendante de Baloo (hhea, 1,47 cadratin),
-- mais le client ne s'en sert pas : capture en jeu du 12/11/2026 (Freezing Trap survolée, texte de
-- 7,5 unités à l'échelle 1,15 × 1,16) : deux lignes à 9 px l'une de l'autre pour des glyphes dont
-- les largeurs donnent ~1,25–1,35 px par unité (≈ 0,9 à 1,0 cadratin d'interligne, pas 1,47) ; les
-- lignes des infobulles, de même, sont espacées de la taille de leur police (plus l'espacement de
-- l'infobulle). Le client règle l'interligne d'un texte sur sa taille de police (GetLineHeight).
-- En jeu, la mise en page des cartes mesure la hauteur d'une ligne (GetStringHeight) : seul le faux
-- client dépend de cette valeur.
local METRICS = dofile(root .. "/Sim/baloo_metrics.lua")
H.metrics = METRICS
H.LINE_EM = 1.0
H.HHEA_EM = METRICS.lineHeight
METRICS.lineHeight = H.LINE_EM
local function plainText(t)
  return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local function fontAdv(self)
  local p = tostring(rawget(self, "_fontPath") or "")
  return METRICS[p:find("heavy") and "heavy" or (p:find("medium") and "medium" or "bold")]
end
-- Icônes en ligne |Tchemin:hauteur:largeur:…|t (comme le client) : largeur = 3e champ, sinon la
-- hauteur ; hauteur 0 = taille du texte. Renvoie le texte sans les séquences et la largeur des icônes.
-- unit : unités du texte par unité de la séquence pour une hauteur ou une largeur EXPLICITE (H.ICON_PX :
-- pixels d'écran, H.iconUnit) ; une hauteur nulle suit la police, quelle que soit l'échelle.
function H.inlineIcons(text, size, unit)
  local icons = 0
  local list = {}
  unit = unit or 1
  text = tostring(text or ""):gsub("|T(.-)|t", function(spec)
    local f = {}
    for v in (spec .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
    local hgt = tonumber(f[2] or "") or 0
    local wid = tonumber(f[3] or "") or hgt
    if hgt == 0 then hgt = size else hgt = hgt * unit end
    if wid == 0 then wid = hgt else wid = wid * unit end
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
  local plain, icons = H.inlineIcons(text, size, H.iconUnit(self))
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
-- Taille EXPLICITE d'une icône en ligne (|Tchemin:7:7:…|t) : prise en PIXELS D'ÉCRAN (H.ICON_PX), pas
-- dans les unités du texte. Retour en jeu du 12/11/2026 (Frostbolt, fenêtre à 115 %, écran de 1440 px
-- de haut : 1,875 × 1,15 ≈ 2,16 px par unité) : un sablier demandé à 7 (dessin de 6,6) à côté de
-- chiffres de 6,2 unités se voyait à peu près deux fois plus petit que le chiffre (7 px contre ~13) ;
-- l'ancien faux client le dessinait à 6,6 unités, plus haut que le chiffre, et ne pouvait pas le voir.
-- Modèle retenu parce qu'il reproduit la capture (mécanisme du client non documenté) ; une hauteur
-- nulle (« :0: ») suit la police à toute échelle et n'en dépend pas. Renvoie les unités du texte par
-- pixel d'écran (1 si H.ICON_PX est faux ou sans cadre).
H.ICON_PX = true
function H.iconUnit(self)
  if not H.ICON_PX or not self or not self.GetEffectiveScale then return 1 end
  return 768 / (effScale(self) * ((H.screen and H.screen[2]) or 1440))
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

-- Modèles. Chargement asynchrone, comme le client : le modèle posé (_model) est annoncé par le script
-- OnModelLoaded H.modelDelay secondes plus tard (H.slowModels[nom] : délai propre, « creature:619 »),
-- s'il est toujours celui du cadre. H.noModels = true : le client ne connaît aucun modèle (créatures,
-- affichages, fichiers). Fichiers (SetModel) : seuls ceux de H.goodFiles existent (le faux client n'a
-- pas de feu de camp par défaut : aperçus en repli).
H.modelDelay = 0.2
local function poseModel(self, name)
  if H.noModels then name = nil end
  self._model = name
  self._modelSerial = (rawget(self, "_modelSerial") or 0) + 1
  if not name then return end
  local serial = self._modelSerial
  local d = (H.slowModels and H.slowModels[name]) or H.modelDelay
  H.timers[#H.timers + 1] = { at = H.now + d, fn = function()
    if rawget(self, "_modelSerial") == serial and rawget(self, "_model") == name then
      H.modelLoads = (H.modelLoads or 0) + 1
      run(self, "OnModelLoaded")
    end
  end }
end
function Frame:SetUnit(u) self._model = "unit:" .. u return true end
function Frame:SetCreature(id)
  if type(id) ~= "number" then error("SetCreature : nombre attendu") end
  poseModel(self, (not H.badCreatures[id]) and ("creature:" .. id) or nil)
end
function Frame:SetDisplayInfo(id)
  if type(id) ~= "number" then error("SetDisplayInfo : nombre attendu") end
  poseModel(self, (not (H.badDisplays and H.badDisplays[id])) and ("display:" .. id) or nil)
end
function Frame:SetModel(file)
  if type(file) ~= "number" and type(file) ~= "string" then error("SetModel : fichier attendu") end
  poseModel(self, (H.goodFiles and H.goodFiles[file]) and ("file:" .. tostring(file)) or nil)
end
function Frame:ClearModel() self._model = nil self._modelSerial = (rawget(self, "_modelSerial") or 0) + 1 end
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
PLAYER_REGEN_ENABLED PLAYER_CONTROL_LOST PLAYER_CONTROL_GAINED TAXIMAP_CLOSED TAXIMAP_OPENED
MODIFIER_STATE_CHANGED]]):gmatch("%S+") do
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
  -- Couleur du client (ColorMixin) : les dégradés (Texture:SetGradient) en reçoivent deux.
  _G.CreateColor = function(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1, GetRGBA = function(self) return self.r, self.g, self.b, self.a end }
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
  -- écran physique (pixels) : levée des cartes ramenée à un nombre entier de pixels (W.pixelSnap)
  H.screen = H.screen or { 2560, 1440 }
  _G.GetPhysicalScreenSize = function() return H.screen[1], H.screen[2] end
  -- boutons de souris enfoncés (H.mouseDown.LeftButton) : glisser des curseurs (U32)
  H.mouseDown = {}
  _G.IsMouseButtonDown = function(b) return H.mouseDown[b or "LeftButton"] and true or false end
  _G.IsShiftKeyDown = function() return H.shift and true or false end
  _G.UnitClass = function(u) assert(u == "player") return "Priest", "PRIEST", 5 end
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

-- Touche pressée, à la façon du client : tout cadre visible qui capte le clavier (EnableKeyboard) la
-- reçoit d'abord, et s'il ne la propage pas le jeu ne la voit pas ; sinon le jeu la traite (Échap :
-- CloseSpecialWindows cache les fenêtres de UISpecialFrames). Renvoie vrai si la touche est allée au jeu.
function H.key(key)
  local toGame = true
  for _, o in ipairs(H.objects) do
    if o._keyboard and o:IsVisible() then
      local fn = o._scripts.OnKeyDown
      if fn then fn(o, key) end
      if not o._propagate then toGame = false end
    end
  end
  if toGame and key == "ESCAPE" then
    for _, name in pairs(_G.UISpecialFrames) do
      local f = _G[name]
      if f and f:IsShown() then f:Hide() end
    end
  end
  return toGame
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

-- Un coup du bot, exécuté par l'interface à la souris : clic carte puis clic cible (ou second clic),
-- ennemi retenu puis double clic sur la carte (ou clic dans le décor), glisser-déposer.
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
    H.click(v.endTurn)
    -- Traveler's Backpack : choix de la carte gardée (celle du bot), sinon « Keep none »
    if v.keepMode then
      local uid = H.ns.Bots.retainPick(c)
      local kc
      for _, cd in ipairs(v.cards) do if uid and cd.uid == uid and cd._shown then kc = cd end end
      H.click(kc or v.endTurn)
    end
    playStyle = playStyle + 1
    return "end"
  end
  local idx, t = a[2], a[3]
  H.shift = a[4] == "nospend" -- Maj enfoncée : carte « Spend N » jouée sans dépenser
  local card = v.cards[idx]
  local style = playStyle % 3
  playStyle = playStyle + 1
  local needs = C().handInfo(idx).needsTarget
  if style == 0 then
    H.click(card)
    if needs then H.click(enemySlot(t)) else H.click(card) end
  elseif style == 1 then
    if needs then
      H.click(enemySlot(t)) -- sans carte choisie : l'ennemi est retenu
      H.click(card)
      H.click(card) -- second clic : jouée sur l'ennemi retenu
    else
      H.click(card)
      run(v.bf, "OnMouseUp", "LeftButton") -- clic dans le décor
    end
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
  H.shift = false
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
    clickOption(target)
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
check("clavier non capté", not _G.SlayTheDragonFrame._keyboard)
check("écran d'accueil", currentKind() == "start", currentKind())
check("UISpecialFrames contient la fenêtre", _G.UISpecialFrames[1] == "SlayTheDragonFrame")
local prop = H.key("W")
check("touche rendue au jeu", prop == true, prop)
prop = H.key("ESCAPE")
check("Échap va au jeu (UISpecialFrames)", prop == true, prop)
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
H.click(UI().optionsClose)
check("bouton de fermeture des options", not UI().optionsFrame._shown and shown())

print("U4  accueil : classe, clé verrouillée, départ")
local st = UI().step
check("bouton de classe Prêtre sélectionné", option("class:priest") and option("class:priest").selected)
do
  -- choix de classe : icône de la classe (anneau doré, sans texte), nom et infos dans l'infobulle
  local pb = button("class:priest")
  local texts = {}
  local function walk(o)
    for _, k in ipairs(rawget(o, "_kids") or {}) do
      if rawget(k, "_kind") == "FontString" and k._shown and (k._text or "") ~= "" then texts[#texts + 1] = k._text end
      walk(k)
    end
  end
  walk(pb)
  check("accueil : la classe est une icône (classicon_priest), aucun texte sur l'icône",
    (pb.icon._texture or ""):lower():find("classicon_priest", 1, true) and #texts == 0 and pb.ring and pb.ring._wow == "ring_large",
    tostring(pb.icon._texture) .. " / " .. table.concat(texts, "|"))
  local tt = table.concat(H.hover(pb), " | ")
  check("accueil : infobulle de la classe (nom, PV, cartes, niveau de classe)", tt:find("Priest", 1, true)
    and tt:find(ns.Classes.priest.hp .. " HP", 1, true) and tt:find("cards", 1, true) and tt:find("Level 1", 1, true)
    and not tt:find("Reputation", 1, true), tt)
  local st0 = UI().screens.start
  check("accueil : nom de la classe choisie sous la rangée", st0.className._shown and st0.className._text == "Priest",
    st0.className._text)
end
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
      H.click(V().banner.button)
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
          H.advance(6)
          snap("combat-survol")
          v.cards[2].hover = false
          v:PlaceCard(v.cards[2])
          -- options par-dessus le combat (aperçu seulement)
          H.slash("options")
          H.advance(0.2)
          snap("options")
          H.click(UI().optionsClose)
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
    clickOption(UI().current.cardOptions[1].id)
    check("clic : la première carte prise", #EXP().deck == deckN + 1 and EXP().reward.cardsDone, #EXP().deck)
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

print("U7  bilan : Save.finish, expérience, déblocages de la campagne, journal, clé suivante")
local db = _G.SlayTheDragonDB
local Meta = H.ns.Meta
check("expédition archivée (db.current = nil)", db.current == nil)
check("une entrée au journal", #db.journal == 1 and db.journal[1].date ~= nil and db.journal[1].zone == "westfall")
check("expérience de classe gagnée, plus de Ligue", db.meta.league == nil and db.meta.classes.priest.xp > 0
  and db.journal[1].xp == db.meta.classes.priest.xp)
check("texte du bilan : expérience, ni réputation ni Ligue", (step.text or ""):find("Priest experience", 1, true)
  and not (step.text or ""):find("eputation", 1, true) and not (step.text or ""):find("League", 1, true), step.text)
snap("bilan")
check("une seule barre (niveau de la classe)", UI().current.bars[1]._shown and not UI().current.bars[2]._shown)
tt = H.hover(UI().current.bars[1])
check("infobulle d'une barre : niveau", #tt >= 2 and table.concat(tt, " "):find("Level", 1, true), #tt)
if won then
  check("victoire : clé +1 débloquée dans Westfall", Meta.keyMax(db.meta, "priest", "westfall") == 1
    and (step.text or ""):find("Mythic Keystone +1 unlocked in Westfall", 1, true), step.text)
  check("victoire : zone suivante annoncée (Duskwood, à venir), commun du compte annoncé",
    (step.text or ""):find("Westfall won with the Priest: Duskwood is open to the Priest (coming later).", 1, true)
    and (step.text or ""):find("First Westfall victory on this account", 1, true), step.text)
else
  check("défaite : pas de nouvelle clé", Meta.keyMax(db.meta, "priest", "westfall") == 0)
end
clickOption("ui:progress")
check("bilan -> progression de la classe jouée", currentKind() == "classProgress" and UI().step.class == "priest", currentKind())
clickOption("ui:meta")
check("écran du journal", currentKind() == "meta" and UI().step.title == "Expedition log", currentKind())
snap("meta")
check("journal : barre de la classe (niveau) seulement", UI().current.bars[1]._shown and not UI().current.bars[2]._shown
  and UI().current.bars[1].label._text == "Priest" and (UI().current.bars[1].value._text or ""):find("Level", 1, true))
check("journal : lignes", UI().current.journal[1]._shown and (UI().current.journal[1]._text or ""):find("Priest · Westfall", 1, true)
  and (UI().current.journal[1]._text or ""):find("experience", 1, true), UI().current.journal[1]._text)
check("journal : zones gagnées", (UI().current.bars[1].detail._text or ""):find("Zones won: " .. (won and 1 or 0) .. " of 7", 1, true),
  UI().current.bars[1].detail._text)
clickOption("ui:progress")
check("journal -> retour à la progression", currentKind() == "classProgress", currentKind())
clickOption("ui:back")
check("retour au bilan", currentKind() == "end", currentKind())
clickOption("ui:new")
check("accueil", currentKind() == "start", currentKind())
local keyMax = Meta.keyMax(db.meta, "priest", "westfall")

check("clé par défaut = la plus haute ouverte", UI().step.key == keyMax and option("key:" .. keyMax).selected)
check("dernière expédition rappelée", (UI().step.text or ""):find("Last expedition", 1, true))
ns = H.ns
ns.Controller.makeSeed = function() return SEED + 1 end
H.click(UI().current.go)
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
check("cinq cartes de classe et l'emplacement neutre, à prix (pastille : pièce + nombre)",
  #s.cardOptions == #exp.shop.cards and #exp.shop.cards == 5 + (exp.shop.cards[6] and exp.shop.cards[6].neutral and 1 or 0)
  and s.cards[#s.cardOptions]._shown and s.cards[1].tag._shown
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
clickOption(UI().current.cardOptions[1].id)
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
  clickOption(UI().step.options[pick].id)
  local k = currentKind()
  check("choix appliqué (résultat, sélection ou récompense)", exp.event.chosen == pick
    and (k == "event" or k == "select" or k == "reward"), k)
  if k == "event" then
    check("texte après coup", UI().step.text == (exp.event.result or ev.choices[pick].after), UI().step.text)
    clickOption(UI().step.options[1].id)
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

print("U12 bibelot au choix au départ (zone 3 gagnée par le compte) ; abandon")
exp = freshRun(SEED + 5, nil, { runs = 3, zones = { westfall = true, duskwood = true, wetlands = true },
  classes = { priest = { xp = 0, runs = 3, wins = 0, zones = {} } } })
check("phase de bibelot de départ", currentKind() == "startRelic", currentKind())
snap("bibelot-de-classe")
check("bibelot proposé avec icône", option("startRelic:1") and button("startRelic:1").icon._shown)
check("texte : choix d'un bibelot, sans la Ligue", UI().step.text == "Choose a relic for this expedition."
  and UI().step.title == "Relic choice", UI().step.text)
local offered = exp.startRelics[1]
clickOption("startRelic:1")
check("bibelot choisi pris après le bibelot de départ", exp.relics[1] == "sacred_candle" and exp.relics[2] == offered
  and currentKind() == "map")
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
check("ancienne option du ruban ignorée, ancienne option de zoom effacée", H.ns.Persist.options().flatRibbon == nil
  and H.ns.Persist.options().zoom == nil)
do
  local o = H.ns.Persist.options()
  o.zoom, o.zoomSlow = "fluide", true -- valeurs sauvegardées par les versions avec /slay zoom
  H.ns.Persist.init()
  check("anciennes options de zoom (« fluide », ralenti) : ignorées et effacées, sans erreur",
    H.ns.Persist.options().zoom == nil and H.ns.Persist.options().zoomSlow == nil and H.ns.Widgets.zoomMode == nil)
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
H.advance(4.5)
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

print("U17 décors : fonds embarqués ou décors peints par défaut (TGA sur disque), essai manuel en repli, verdicts gardés")
do
  local function chat() return table.concat(_G.DEFAULT_CHAT_FRAME._lines, "\n") end
  local function clearChat() _G.DEFAULT_CHAT_FRAME._lines = {} end
  local function u16(s, i) return s:byte(i) + 256 * s:byte(i + 1) end
  local function pow2(n) return n > 0 and math.floor(math.log(n) / math.log(2) + 0.5) == math.log(n) / math.log(2) end
  local BG = "Interface\\AddOns\\SlayTheDragon\\Media\\Backgrounds\\"
  -- Même quand tous les fichiers du client « répondent » (SetTexture, FileID, chargement), aucun
  -- candidat du client n'est affiché sans validation : sur Forever un fichier absent répond pareil et
  -- s'affiche en aplat vert. Les fonds embarqués, eux, sont des fichiers de l'addon ; les décors de
  -- Westfall (route, colline, camp, marchand, nuit) sont peints, sans illustration.
  H.badFiles, H.badPaths, H.unloaded = nil, {}, nil
  H.boot(nil)
  H.slash("")
  local Sc = H.ns.Scene
  local Art = H.ns.Art
  local target = Sc.W / Sc.DECOR_H
  local function painted(key) local g = Sc.paints[key] return g and g[1] and g[1]._shown end
  check("accueil : décor de la route", Sc.scene == "road" and Sc.decor._shown)
  check("par défaut : la route est le décor peint de Westfall, sans illustration ni voile du bas",
    Sc.entry == Art.scenes.westfall_road and painted("westfall_road") and not Sc.art._shown
    and not Sc.ground._shown and H.ns.Persist.options().decor == true, Sc.art._texture)
  check("plus aucune sonde automatique", Sc.illus == nil and Sc.resolveAll == nil and Sc.probeFrame == nil)

  -- Chaque scène illustrée : un fond embarqué, en tête de sa liste, fichier TGA présent et conforme,
  -- affiché par défaut au bon format (bande ≈ 2,72:1 dans la zone de rapport `ratio`), teinte de la
  -- scène. Chaque scène sans illustration : un paysage peint déclaré (Art.paintings), affiché seul.
  local ids = {}
  for id in pairs(Art.scenes) do ids[#ids + 1] = id end
  table.sort(ids)
  local used = {}
  for _, id in ipairs(ids) do
    local entry = Art.scenes[id]
    if not entry.art then
      Sc.set({ scene = id, board = true })
      check("décor " .. id .. " : paysage peint déclaré et seul affiché", Art.paintings[entry.paint] ~= nil
        and painted(entry.paint) and not Sc.art._shown and Sc.chosen(entry) == nil)
    else
      local bg = Sc.embedded(entry)
      local list = Sc.candidates(entry.art)
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
  end
  for key in pairs(Art.backgrounds) do
    check("fond " .. key .. " employé par au moins une scène", used[key])
  end
  Sc.set({ scene = "road", board = true, veil = 0.2 })

  clearChat()
  H.slash("art")
  local said = chat()
  check("/slay art : liste des fonds embarqués et de leurs scènes", said:find("embedded backgrounds (Media\\Backgrounds): 4", 1, true)
    and said:find("deadmines.tga — " .. Art.backgrounds.deadmines.name .. " (FileDataID 131833): mine", 1, true)
    and said:find("coast.tga — ", 1, true) and not said:find("elwynn", 1, true), said)
  check("/slay art : chaque décor dit son fond, ou peint", said:find("road: painted (no illustration)", 1, true)
    and said:find("westfall_night: painted (no illustration)", 1, true)
    and said:find("mine: embedded background deadmines — ", 1, true)
    and said:find("coast: embedded background coast — ", 1, true), said)
  check("/slay art : aucun verdict", said:find("accepted: none", 1, true) and said:find("rejected: none", 1, true)
    and said:find("not judged yet: 4 of 4", 1, true), said)

  -- Liste d'essai : les candidats du client seulement (Mortemines, ruines), dédoublonnée.
  local list = Sc.trialList()
  local keys, dup, emb = {}, false, false
  for _, c in ipairs(list) do
    if keys[tostring(c.file)] then dup = true end
    if c.embedded then emb = true end
    keys[tostring(c.file)] = true
  end
  check("liste d'essai : 4 candidats du client, sans doublon ni fond embarqué", #list == 4 and not dup and not emb, #list)
  check("liste d'essai : écran classique des Mortemines et écrans Forever, plus d'Elwynn", keys["131833"]
    and keys["7963777"] and keys["7963782"] and not keys["7377860"] and not keys["131839"] and not keys["7963776"])

  clearChat()
  H.slash("scenery test")
  said = chat()
  check("essai : candidat 1 affiché sur le décor courant (peint)", Sc.trial == 1 and Sc.art._shown
    and Sc.art._texture == list[1].file, Sc.art._texture)
  check("essai : sans teinte ni voile", Sc.art._calls.SetVertexColor[1] == 1 and Sc.art._calls.SetVertexColor[3] == 1
    and Sc.veil._calls.SetColorTexture[4] == 0 and not Sc.ground._shown)
  check("essai : numéro, fichier, nom et mode d'emploi", said:find("scenery test 1/4: " .. tostring(list[1].file)
    .. " — " .. list[1].name .. " [not judged yet]", 1, true) and said:find("/slay scenery ok", 1, true), said)
  clearChat()
  H.slash("scenery next")
  check("suivant : candidat 2", Sc.trial == 2 and Sc.art._texture == list[2].file
    and chat():find("scenery test 2/4: " .. tostring(list[2].file), 1, true), chat())
  H.slash("scenery prev")
  H.slash("scenery prev")
  check("précédent depuis le 1er : retour au dernier", Sc.trial == 4 and Sc.art._texture == list[4].file)
  H.slash("scenery next")
  check("suivant depuis le dernier : retour au 1er", Sc.trial == 1)

  -- Verdicts : le 1er refusé, puis on valide le 3e candidat du client de la liste des Mortemines et
  -- celui des ruines, pour vérifier qu'un décor sans fond embarqué prend le premier validé de SA liste.
  local function clientOnly(key)
    local out = {}
    for _, c in ipairs(Sc.candidates(key)) do if not c.embedded then out[#out + 1] = c end end
    return out
  end
  local deadmines = clientOnly("deadmines")
  local ruins = clientOnly("ruins")
  clearChat()
  H.slash("scenery no")
  check("non : refusé et dit", H.ns.Persist.options().artChecks[tostring(list[1].file)] == false
    and list[1].file == deadmines[1].file and chat():find(tostring(list[1].file) .. " rejected", 1, true), chat())
  local function goTo(file)
    for _ = 1, #list do
      if Sc.trialList()[Sc.trial].file == file then return true end
      H.slash("scenery next")
    end
    return false
  end
  check("aller au 3e candidat des Mortemines", goTo(deadmines[3].file))
  clearChat()
  H.slash("scenery ok")
  check("ok : validé et dit", H.ns.Persist.options().artChecks[tostring(deadmines[3].file)] == true
    and chat():find(tostring(deadmines[3].file) .. " accepted", 1, true), chat())
  goTo(ruins[1].file)
  H.slash("scenery ok")
  check("en essai, le décor montre le candidat essayé", Sc.art._texture == ruins[1].file)

  clearChat()
  H.slash("scenery painted")
  check("peint : fin de l'essai, la route reste peinte", Sc.trial == nil and not Sc.art._shown
    and painted("westfall_road") and not Sc.ground._shown and H.ns.Persist.options().decor == false, chat())
  Sc.set({ scene = "mine", board = true })
  check("peint : la mine passe à son décor peint de repli", not Sc.art._shown and painted("cave"))
  H.slash("scenery illustrated")
  Sc.set({ scene = "mine", board = true })
  check("illustré : la mine montre son fond embarqué, même avec des candidats validés",
    H.ns.Persist.options().decor == true and Sc.art._shown and Sc.art._texture == Art.backgrounds.deadmines.file
    and Sc.ground._shown)
  Sc.set({ scene = "road", board = true, veil = 0.2 })
  check("illustré : la route reste peinte (aucune illustration à montrer)", not Sc.art._shown and painted("westfall_road"))
  check("voile de l'accueil rétabli", math.abs(Sc.veil._calls.SetColorTexture[4] - 0.2) < 1e-9)
  Sc.set({ scene = "coast", board = true })
  check("côte : fond embarqué de la côte", Sc.art._shown and Sc.art._texture == Art.backgrounds.coast.file)
  -- Repli : sans fond embarqué dans la liste, le premier candidat validé (recadré, décalé, teinté).
  local saved = Art.illustrations.deadmines
  local stripped = {}
  for _, c in ipairs(saved) do if type(c) ~= "table" or not c.embedded then stripped[#stripped + 1] = c end end
  Art.illustrations.deadmines = stripped
  Sc.set({ scene = "mine", board = true })
  check("repli : la mine montre le premier validé de sa liste", Sc.art._shown and Sc.art._texture == deadmines[3].file
    and math.abs(Sc.art._calls.SetTexCoord[3] - deadmines[3].crop[3]) < 1e-9
    and math.abs(Sc.art._calls.SetVertexColor[2] - Art.scenes.mine.tint[2]) < 1e-9)
  Art.illustrations.deadmines = saved
  -- (chaque commande redessine l'écran courant, l'accueil : la mine est reposée pour la vérifier)
  H.slash("scenery")
  Sc.set({ scene = "mine", board = true })
  check("/slay decor seul : bascule vers peint", H.ns.Persist.options().decor == false and not Sc.art._shown)
  H.slash("scenery")
  Sc.set({ scene = "mine", board = true })
  check("/slay decor seul : bascule vers illustré", H.ns.Persist.options().decor == true and Sc.art._shown)
  H.slash("scenery test")
  H.slash("scenery test")
  check("essai deux fois : bascule (essai fermé)", Sc.trial == nil and Sc.art._texture == Art.backgrounds.deadmines.file)
  clearChat()
  H.slash("scenery ok")
  check("ok hors essai : rien, message", chat():find("no test in progress", 1, true), chat())

  clearChat()
  H.slash("art")
  said = chat()
  check("/slay art : validés et refusés", said:find("accepted: " .. tostring(deadmines[3].file) .. " (", 1, true)
    and said:find(tostring(ruins[1].file) .. " (", 1, true)
    and said:find("rejected: " .. tostring(deadmines[1].file) .. " (" .. deadmines[1].name .. ")", 1, true)
    and said:find("not judged yet: 1 of 4", 1, true), said)

  -- Persistance : verdicts relus au rechargement, essai non repris.
  local savedDB = deepcopy(_G.SlayTheDragonDB)
  local okData = plainData(savedDB, nil, "SlayTheDragonDB")
  check("verdicts : données simples dans la sauvegarde", okData)
  H.boot(savedDB)
  H.slash("")
  Sc = H.ns.Scene
  check("rechargement : verdicts gardés", H.ns.Persist.options().artChecks[tostring(deadmines[3].file)] == true
    and H.ns.Persist.options().artChecks[tostring(deadmines[1].file)] == false)
  check("rechargement : la route montre son décor peint, pas d'essai", Sc.trial == nil and not Sc.art._shown
    and painted("westfall_road"))
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

print("U18 survols animés : zone fixe, visuel levé et allumé sans échelle, réversible, pilote qui s'arrête")
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
  -- échelle visuelle totale du visuel (réelle × animation éventuelle)
  local function vis(f) return f.face._scale * H.visualScale(f.face) end
  local function liftOf(f) local p = f.face._points[1] return p and p[5] or 0 end
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
  local n0 = face._nSetScale or 0
  check("survol en route : aucune échelle (ni SetScale, ni animation Scale), visuel qui monte, zone fixe",
    vis(card) == 1 and face._zoom == nil and liftOf(card) > 0 and liftOf(card) < card.hoverLift
    and hit(card) == before, liftOf(card))
  check("textes en mode Vertex et SetSmoothScaling (vols de cartes, fenêtre à l'échelle)",
    card.body._calls.SetScaleAnimationMode and card.body._calls.SetScaleAnimationMode[1] == 1
    and card.body._calls.SetSmoothScaling and card.body._calls.SetSmoothScaling[1] == true)
  check("mise en page identique pendant le mouvement", layout(card) == rest, layout(card))
  run(card, "OnLeave")
  run(driver, "OnUpdate", 0.01)
  local back = Wd.animValue(card, "hover")
  check("sortie en cours de route : repart de la valeur courante", back > 0 and back <= mid, back .. " / " .. mid)
  for _ = 1, 30 do run(driver, "OnUpdate", 0.02) end
  H.now = H.now + 1
  check("sortie terminée : repos exact (levée 0), aucune échelle", Wd.animValue(card, "hover") == 0
    and liftOf(card) == 0 and vis(card) == 1 and (face._nSetScale or 0) == n0)
  check("pilote arrêté une fois tout immobile", not Wd.driverAwake() and driver._scripts.OnUpdate == nil)
  check("mise en page identique après le survol", layout(card) == rest, layout(card))

  -- arrivée : levée de W.CARD_LIFT ramenée à un nombre entier de pixels de l'écran physique
  run(card, "OnEnter")
  H.advance(0.5)
  local px = liftOf(card) * face:GetEffectiveScale() * H.screen[2] / 768
  check(("arrivée : carte levée de %.2f unités = %.3f pixels (entier), halo allumé, échelle 1"):format(liftOf(card), px),
    math.abs(px - math.floor(px + 0.5)) < 1e-6 and math.abs(liftOf(card) - Wd.CARD_LIFT) < 1
    and card.halo._shown and (card.halo._calls.SetAlpha or {})[1] == 1 and vis(card) == 1 and hit(card) == before)
  check("mise en page identique une fois levée (même nombre de lignes, mêmes coupures)", layout(card) == rest, layout(card))
  for _, ws in ipairs({ 1.15, 0.85, 1.5 }) do
    UI().frame:SetScale(ws)
    Wd.faceApply(card)
    local p2 = liftOf(card) * face:GetEffectiveScale() * H.screen[2] / 768
    check(("fenêtre à %.2f : levée toujours entière en pixels (%.3f)"):format(ws, p2),
      math.abs(p2 - math.floor(p2 + 0.5)) < 1e-6)
  end
  UI().frame:SetScale(1)
  Wd.faceApply(card)
  local n = #C().combat().hand
  check("carte survolée devant les autres (visuel compris)", card._level > v.cards[n]._level
    and card.face._level > v.cards[n].face._level)
  check("zone de survol prolongée vers le haut (de la levée)", card._calls.SetHitRectInsets
    and card._calls.SetHitRectInsets[3] < 0 and card._calls.SetHitRectInsets[3] >= -math.ceil(Wd.CARD_LIFT))
  if n >= 2 then
    check("voisines immobiles (plus d'écart : la carte ne grossit plus)", Wd.animValue(v.cards[2], "dx") == 0
      and liftOf(v.cards[2]) == 0)
  end
  run(card, "OnLeave")
  H.advance(0.5)
  check("retour au repos", Wd.animValue(card, "hover") == 0 and card._level == card.baseLevel and liftOf(card) == 0)

  -- bouton, pile, potion, menu : surbrillance seule, aucune échelle, aucun déplacement
  for _, f in ipairs({ v.endTurn, v.drawPile, UI().potionSlots[1], UI().gear }) do
    local hb, fb = hit(f), hit(f.face)
    run(f, "OnEnter")
    H.advance(0.5)
    local up = vis(f) == 1 and hit(f.face) == fb and Wd.animValue(f, "hover") == 1
    run(f, "OnLeave")
    H.advance(0.5)
    check("survol : " .. tostring(f.label and f.label._text or f.pileKey or "icône")
      .. " (allumé, ni échelle ni déplacement, repos exact ensuite)",
      up and vis(f) == 1 and hit(f) == hb and hit(f.face) == fb and Wd.animValue(f, "hover") == 0)
  end
  -- /slay zoom : retiré (l'aide ne le cite plus, aucune option posée)
  local chat = rawget(_G.DEFAULT_CHAT_FRAME, "_lines")
  local c0 = #chat
  H.slash("zoom")
  H.slash("zoom fluid")
  local said = table.concat(chat, "\n", c0 + 1)
  check("/slay zoom retiré : aide générale, sans « zoom », aucune option enregistrée",
    said:find("/slay options", 1, true) ~= nil and not said:find("zoom", 1, true)
    and H.ns.Persist.options().zoom == nil, said)
  -- vol de carte : étirement pendant le vol, échelle réelle d'arrivée posée une fois, texte net
  do
    local g = Wd.ghostCard(v.parent)
    g:SetCard(card.cardId, card.cardUp, card.opts)
    local landed = false
    local s0 = g._nSetScale or 0
    Wd.fly(g, v.parent, 100, 400, 500, 300, 0.3, 1, 0.6, 1, 0.28, function() landed = true end)
    local gz = g._flyScale
    local inFlight = gz and gz.ag:IsPlaying() and g._scale == 0.3 and math.abs(gz.to - 1 / 0.3) < 1e-9
      and gz.from == 1
    local nIn = (g._nSetScale or 0) - s0
    H.advance(0.5)
    check("vol de carte : étirement en vol (échelle réelle de départ), à l'arrivée échelle réelle d'arrivée"
      .. " posée une fois et aucune animation d'échelle", inFlight and landed and g._scale == 1
      and not gz.ag:IsPlaying() and (g._nSetScale or 0) - s0 == nIn + 1, (g._nSetScale or 0) - s0)
    Wd.releaseGhost(g)
  end
  -- ennemi ciblable quand une carte à cible est armée : son anneau s'allume, il ne grandit plus
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
    check("ennemi visé : anneau allumé, ni échelle ni zone de clic changées", slot.fig._scale == 1
      and hit(slot) == hs and Wd.animValue(slot, "aim") == 1, slot.fig._scale)
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
  check("panneau ouvert : la touche 1 va au jeu, rien ne change", prop == true and Dv:IsShown()
    and currentKind() == "map")
  H.key("ESCAPE")
  check("Échap ferme la fenêtre, et le panneau avec elle", not Dv:IsShown() and not shown())
  H.slash("")
  check("rouverte : panneau fermé, même écran", shown() and not Dv:IsShown() and currentKind() == "map")
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
  H.click(Dv.close)

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
  H.click(Dv.close)
  c.exhaust[#c.exhaust + 1] = c.draw[#c.draw]
  table.remove(c.draw)
  V():Render()
  check("tas des consumées affiché quand il y en a", V().exhaustPile._shown and V().exhaustPile.count._text == 1)
  H.click(V().exhaustPile)
  check("consumées consultables", Dv:IsShown() and Dv.kind == "exhaust" and #Dv.list == 1)
  H.click(Dv.close)
  check("bouton Deck aussi en combat", UI().deckButton._shown)
  H.click(UI().deckButton)
  check("deck complet consultable en combat", Dv:IsShown() and Dv.kind == "deck" and #Dv.list == #exp.deck)
  local hand = #c.hand
  H.key("1")
  check("panneau ouvert en combat : la touche 1 ne joue rien", #c.hand == hand and Dv:IsShown())
  H.click(Dv.close)
  check("Fermer : panneau fermé, combat intact", not Dv:IsShown() and currentKind() == "combat")
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
  -- (UI/Art.lua et les fichiers d'art des classes UI/Art/*.lua, aide I("Nom") comprise : fichiers du TOC)
  local used, absent = 0, {}
  local artFiles = { "UI/Art.lua" }
  for line in io.lines(root .. "/SlayTheDragon.toc") do
    local f = line:gsub("\r", ""):match("^UI\\Art\\(.+%.lua)$")
    if f then artFiles[#artFiles + 1] = "UI/Art/" .. f:gsub("\\", "/") end -- UI\Art\Zones\<zone>.lua compris
  end
  for _, file in ipairs(artFiles) do
    local art = assert(io.open(root .. "/" .. file)):read("*a")
    for name in art:gmatch('tga%s*=%s*"([^"]+)"') do
      used = used + 1
      if not Skin.icons[name:lower()] then absent[#absent + 1] = name end
    end
    for name in art:gmatch('%f[%w_]I%(%s*"([^"]+)"') do
      used = used + 1
      if not Skin.icons[name:lower()] then absent[#absent + 1] = name end
    end
  end
  check(("icônes nommées dans l'art (%d fichiers) toutes copiées (%d)"):format(#artFiles, used), #absent == 0, table.concat(absent, ", "))
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
    and (card.body._text or ""):find("|cff7dff7d" .. H.ns.Cards.smite.up.effects[1][2] .. "|r", 1, true), card.body._text)
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
  local Sc = ns.Scene
  local SORC = { 2329, 2330, 2321, 2322, 4281, 4282 }
  H.badCreatures = { [619] = true, [126] = true }
  H.badDisplays = {}
  for _, d in ipairs(SORC) do H.badDisplays[d] = true end
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
  local function alpha(m) return m._calls.SetAlpha and m._calls.SetAlpha[1] end
  check("pas de repli avant la fin des essais ; modèle invisible (alpha 0) tant qu'il n'est pas chargé",
    so and not so.fallback._shown and alpha(so.model) == 0 and not so.fig.shadow:IsShown())
  H.advance((#SORC + 1) * Sc.MODEL_WAIT + 0.5)
  check("sorcier sans modèle : médaillon argenté de repli après l'échec des 7 candidats", so.fallback._shown
    and so.fallback.ring ~= nil and so.fallback.icon._texture ~= Art.QUESTION, so.fallback.icon._texture)
  check("repli : icône de l'ennemi (Media)", so.fallback.icon._texture
    == "Interface\\AddOns\\SlayTheDragon\\Media\\" .. ns.Skin.icons.spell_fire_flamebolt, so.fallback.icon._texture)
  check("repli au-dessus du modèle", R.rect(so.fallback) ~= nil and so.fallback._level > so.model._level)
  check("murloc : affichage 983 après l'échec de la créature, apparu en fondu avec son ombre",
    mu.model._model == "display:983" and not mu.fallback._shown and alpha(mu.model) == 1 and mu.fig.shadow:IsShown(),
    mu.model._model)
  check("statut des essais (créature, affichages)", W.models.sorcerer.state == "missing"
    and table.concat(W.models.sorcerer.tries, ", ") == "creature 619, display 2329, display 2330, display 2321, "
      .. "display 2322, display 4281, display 4282"
    and W.models.murloc.via == "display 983")
  check("gagnant mémorisé (session et options)", Sc.won.murloc == "display 983"
    and ns.Persist.options().modelWins.murloc == "display 983" and Sc.lost.sorcerer == true)
  -- relance tardive : la créature arrive dans le cache du client -> le repli s'efface
  H.badCreatures = { [126] = true }
  H.advance(Sc.MODEL_LATE + 0.5)
  check("relance tardive : modèle trouvé, repli caché, plus listé manquant", not so.fallback._shown
    and so.model._model == "creature:619" and W.models.sorcerer.state == "ok" and not W.missing["model:sorcerer"])
  -- OnModelLoaded sonne alors que GetModelFileID ne rend rien encore : l'essai est jugé réussi
  H.badCreatures = { [117] = true }
  Sc.enemyFigure(so.fig, "gnoll")
  so.model:GetScript("OnModelLoaded")(so.model)
  check("OnModelLoaded suffit à valider un essai", W.models.gnoll.state == "ok" and W.models.gnoll.via == "creature 117"
    and not so.fallback._shown)
  -- sans icône : disque sombre (silhouette), jamais le point d'interrogation
  W.setFallbackArt(so.fallback, nil)
  check("repli sans icône : disque sombre", so.fallback.icon._texture == nil and so.fallback.icon._calls.SetColorTexture
    and so.fallback.icon._calls.SetColorTexture[1] == Art.C.slateDark[1])

  -- /slay models : une ligne recopiable par modèle (ennemis, PNJ des rencontres, familier, feu de camp) :
  -- candidat chargé, ou « fallback » avec les candidats essayés
  H.badCreatures = { [619] = true, [639] = true, [235] = true }
  H.badDisplays = { [1691] = true, [8185] = true }
  for _, d in ipairs(SORC) do H.badDisplays[d] = true end
  H.goodFiles = { [189705] = true }
  Sc.won, Sc.failed, Sc.lost = {}, {}, {}
  ns.Persist.options().modelWins = {}
  _G.DEFAULT_CHAT_FRAME._lines = {}
  H.slash("models")
  H.advance(8 * Sc.MODEL_WAIT + 1)
  local said = table.concat(_G.DEFAULT_CHAT_FRAME._lines, "\n")
  local total = 0
  for _ in pairs(Art.enemies) do total = total + 1 end
  local npcIds = {}
  for _, ev in pairs(ns.Events) do if type(ev) == "table" and ev.npc then npcIds[ev.npc] = ev.speaker end end
  for id in pairs(Art.npcs) do npcIds[id] = npcIds[id] or id end
  for _ in pairs(npcIds) do total = total + 1 end
  total = total + 2 -- familier, feu de camp
  check("/slay models : bilan chiffré", said:find("models: " .. (total - 2) .. "/" .. total .. " loaded, 2 on fallback:", 1, true), said)
  check("/slay models : ennemi en repli et identifiants essayés", said:find("sorcerer (" .. ns.Enemies.sorcerer.name
    .. "): fallback (no model: creature 619, display 2329, display 2330, display 2321", 1, true), said)
  check("/slay models : PNJ en repli", said:find("npc:salma_saldean (Salma Saldean): fallback (no model: creature 235, "
    .. "display 1691, display 8185)", 1, true), said)
  check("/slay models : modèle chargé par un candidat de secours signalé",
    said:find("vancleef (" .. ns.Enemies.vancleef.name .. "): display 2029 (declared first: creature 639)", 1, true), said)
  check("/slay models : feu de camp (candidat chargé)", said:find("campfire (Campfire): file 189705", 1, true), said)
  local everyNpc = true
  for id, speaker in pairs(npcIds) do
    if not said:find("npc:" .. id .. " (" .. speaker .. "): ", 1, true) then everyNpc = false end
  end
  check("/slay models : une ligne par PNJ des rencontres (nom affiché)", everyNpc, said)
  check("/slay models : ennemis, PNJ, familier et feu dans l'aperçu", #V().preview.models == total)
  local stateOk = true
  for _, m in ipairs(V().preview.models) do
    local want = (m.key == "sorcerer" or m.key == "npc:salma_saldean") and "fallback" or "model: "
    if not (m.state._text or ""):find(want, 1, true) then stateOk = false end
    if m.fallback.icon._texture == Art.QUESTION then stateOk = false end
  end
  check("aperçu : état sous chaque modèle, aucun point d'interrogation", stateOk)
  H.badCreatures, H.badDisplays, H.goodFiles = {}, nil, nil
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
  -- marges minimales vérifiées : côtés, haut (boîte de la ligne), bas de la boîte de la ligne au milieu
  -- (bas de l'intérieur), et sous l'ENCRE de la ligne sur toute sa largeur (biseau : ligne de base, ou
  -- bas des jambages, W.lineInkBottom ; depuis le 12/11/2026 — avant, 4 unités sous la BOÎTE sur toute
  -- la largeur, soit ~6,7 unités sous la ligne de base d'une ligne sans jambage : le décrochement du
  -- biseau à y 133,1 interdisait la pleine largeur à des lignes dont l'encre finit 3 unités plus haut)
  local MX, MT, MB, MBI = 4, 1, 4, 2
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
  for _, why in ipairs({ "phase", "unplayable", "casting", "forbidden", "condition", "target", "over", "hp", "resource", "traps" }) do
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
        -- blocs du texte (un seul, ou un par clause avec l'écart entre clauses) : chacun vérifié
        local lines, size = {}, fs._fontSize
        local lh = size * LH
        local bottom, prevBottom = -math.huge, nil
        if not fit.ok then bad[#bad + 1] = label .. " : ne tient à aucun palier" end
        local gem = card.gem._shown and gems[(card.gem._texture or ""):match("gem_(%a+)%.tga$")]
        for b = 1, card.bodyUsed or 1 do
          local p = card.bodyParts[b]
          local pl = splitLines(p._text)
          local pt = p._points[1]
          local cx, cy = pt[4], -pt[5]
          local top = cy - #pl * lh / 2
          if p._fontSize ~= size or not p._shown then bad[#bad + 1] = label .. " : bloc " .. b .. " caché ou d'une autre taille" end
          if p:GetNumLines() ~= #pl or p:IsTruncated() then
            bad[#bad + 1] = label .. " : lignes recoupées par le client (" .. p:GetNumLines() .. " / " .. #pl .. ")"
          end
          -- blocs dans l'ordre, sans chevauchement, séparés de l'écart prévu
          if prevBottom and math.abs(top - prevBottom - (fit.gap or 0)) > 0.01 then
            bad[#bad + 1] = ("%s : bloc %d à %.2f du précédent (écart %.2f attendu)"):format(label, b, top - prevBottom, fit.gap or 0)
          end
          prevBottom = top + #pl * lh
          bottom = math.max(bottom, prevBottom)
          for k, line in ipairs(pl) do
            lines[#lines + 1] = line
            local lw = H.textWidth(p, line, size)
            local x0, x1 = cx - lw / 2, cx + lw / 2
            local y0, y1 = top + (k - 1) * lh, top + k * lh
            local yi = W.lineInkBottom(line, y0, lh, size)
            local ok, where = all(x0 - MX, y0 - MT, x1 + MX, yi + MBI, dark)
            if ok then ok, where = all(cx, y1, cx, y1 + MB, dark) end
            if not ok then bad[#bad + 1] = ("%s : ligne %d hors de l'ardoise (marges comprises) en %s"):format(label, #lines, where) end
            if gem then
              local ok2, where2 = all(x0, y0, x1, y1, function(u, v) local _, _, _, a = gem(u, v) return a <= 60 end)
              if not ok2 then bad[#bad + 1] = ("%s : ligne %d sous la gemme en %s"):format(label, #lines, where2) end
            end
          end
        end
        for b = (card.bodyUsed or 1) + 1, #card.bodyParts do
          if card.bodyParts[b]._shown or (card.bodyParts[b]._text or "") ~= "" then bad[#bad + 1] = label .. " : bloc " .. b .. " inutile affiché" end
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
          -- encre : de 0,455 cadratin au-dessus du milieu de la ligne à 0,595 au-dessous (capitales et
          -- jambages de Baloo, ligne de base aux 1,078 / 1,47 d'une ligne de 1,47 cadratin : la mesure
          -- d'avant la hauteur de ligne du client, H.LINE_EM, gardée telle quelle)
          local mid = ny0 + nlh / 2
          local ok, where = all(np[4] - nw / 2 - 2, mid - 0.455 * ns_, np[4] + nw / 2 + 2, mid + 0.595 * ns_,
            function(u, v) local _, _, _, a = ribbon(u, v) return a > 200 end)
          if not ok or not nf.ok or card.name:IsTruncated() then
            bad[#bad + 1] = ("%s : nom hors du ruban en %s"):format(label, tostring(where))
          end
          nameDist[ns_] = (nameDist[ns_] or 0) + 1
          tiers[#tiers + 1] = { label = label, name = card.name._text, nameSize = ns_, bodySize = size,
            lines = #lines, text = d_text(W.cardBodyText(card)), gap = card.bodyFit.gap or 0 }
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
        local sized = pl.sliced and (pl.anchor._w > 0 and pl.anchor._h > 0) or (t._w > 0 and t._h > 0)
        if not t._shown or a < 1 or not sized or (t._sub or 0) <= (card.bg._sub or 0)
          or t._layer ~= card.bg._layer then
          plateBad[#plateBad + 1] = label .. " : plaque invisible (caché, alpha, taille nulle ou derrière le corps)"
          break
        end
      end
      if pl.sliced then
        -- une texture découpée par le client, sur la région d'ancrage de la plaque (échelle propre = hauteur
        -- ÷ hauteur de la texture, bouts de capPx pixels)
        local t, an = pl.parts[1], pl.anchor
        local sm = t._calls.SetTextureSliceMargins
        if #pl.parts ~= 1 or math.abs(an._w - box.w) > 0.01 or math.abs(an._h - box.h) > 0.01
          or math.abs(t._scale - box.h / W.CARD_PLATE.texH) > 1e-9 or not sm or sm[1] ~= W.CARD_PLATE.capPx
          or math.abs(sm[1] * t._scale - box.cap) > 1e-9 then
          plateBad[#plateBad + 1] = label .. " : plaque découpée mal posée"
        end
      else
        local l, m, r = pl.parts[1], pl.parts[2], pl.parts[3]
        if math.abs(l._w + m._w + r._w - box.w) > 0.01 or math.abs(l._h - box.h) > 0.01 then
          plateBad[#plateBad + 1] = label .. " : tranches mal posées"
        end
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
      f:write(table.concat({ t.label, t.name, tostring(t.nameSize), tostring(t.bodySize), tostring(t.lines), t.text, ("%.2f"):format(t.gap or 0) }, "\t"), "\n")
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
  local okParts = true
  for b = 1, card.bodyUsed or 1 do
    local p = card.bodyParts[b]
    if p:GetNumLines() ~= #splitLines(p._text) or p._w < 2 * W.CARD_TEXT.half * CW then okParts = false end
  end
  check("Forme d'ombre : lignes posées une à une (dans chaque bloc), aucune recoupe par le client",
    W.cardBodyText(card):find("\n", 1, true) and okParts)
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
  -- échelle effective d'une région ; une texture découpée par le client a une échelle propre (pixels de
  -- ses marges -> unités de l'hôte, voir W.sliceFit) qui ne compte pas ici
  local function effScale(o)
    local s = 1
    if rawget(o, "_calls") and o._calls.SetTextureSliceMargins then s = 1 / (rawget(o, "_scale") or 1) end
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

print("U26 survols sans échelle (plus de modes de zoom) : aucun cadre enfant dessiné, carte levée dans la fenêtre, vols ; abréviations")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local Wd = H.ns.Widgets
  check("plus de modes de zoom (W.zoomMode, W.setZoomMode, W.faceBuild, W.setHover retirés)",
    Wd.zoomMode == nil and Wd.setZoomMode == nil and Wd.faceBuild == nil and Wd.setHover == nil and Wd.ZOOM_MODES == nil)
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
  local function name(f) return tostring(f.cardId or (f.label and f.label._text) or "jeton") end

  -- 1. aucun cadre enfant dessiné sous un visuel survolable (carte, plaques, bouton, jeton)
  freshRun(SEED, "combat")
  H.settle()
  local v = V()
  local c2 = v.cards[2]
  c2:SetCard(c2.cardId, c2.cardUp, { playable = false, reason = "Not enough mana." })
  v.playerSt:Set({ { icon = H.ns.Art.ui.gold, key = "ui:gold", n = 3, info = { title = "Essai" } } })
  H.advance(0.1)
  local childFrames = {}
  for _, f in ipairs({ v.cards[1], c2, v.endTurn, UI().gear, v.playerSt.tokens[1] }) do
    for _, k in ipairs(rawget(f.face, "_kids")) do
      if KINDS[rawget(k, "_kind")] and k:IsVisible() and #regions(k) > 0 then childFrames[#childFrames + 1] = name(f) end
    end
  end
  check("aucun cadre enfant dessiné sous un visuel survolable (carte, plaques, bouton, jeton)", #childFrames == 0,
    table.concat(childFrames, ", "))

  -- 2. vols de cartes : échelle réelle de départ pendant le vol, échelle réelle d'arrivée posée une fois
  local card = v.cards[1]
  for _, it in ipairs({ { "pioche, 0,3 → 1", 100, 400, 500, 300, 0.3, 1 }, { "vers la cible, 1 → 0,35", 500, 300, 100, 400, 1, 0.35 } }) do
    local g = Wd.ghostCard(v.parent)
    g:SetCard(card.cardId, card.cardUp, card.opts)
    local landed = false
    Wd.fly(g, v.parent, it[2], it[3], it[4], it[5], it[6], it[7], 1, 1, 0.3, function() landed = true end)
    local start = g._scale * H.visualScale(g)
    H.now = H.now + 0.12
    local mid = g._scale * H.visualScale(g)
    local real = g._scale
    H.advance(0.6)
    local lo, hi = math.min(it[6], it[7]), math.max(it[6], it[7])
    check(("vol (%s) : échelle réelle fixe en vol, taille animée, arrivée à l'échelle réelle d'arrivée sans animation"):format(it[1]),
      landed and math.abs(start - it[6]) < 1e-9 and real == it[6] and mid > lo and mid < hi and g._scale == it[7]
      and H.visualScale(g) == 1 and g.face._scale == 1, start .. " / " .. mid .. " / " .. g._scale)
    Wd.releaseGhost(g)
  end

  -- 3. carte levée de la main : dans la fenêtre, à toutes les places, carte injouable comprise
  do
    local content = R.rect(UI().content)
    local outW, lowest, highest = {}, math.huge, -math.huge
    for i = 1, #C().combat().hand do
      for _, opts in ipairs({ { playable = true }, { playable = false, reason = "Not enough mana." } }) do
        local card1 = v.cards[i]
        card1:SetCard("penance", false, opts)
        card1.hover = true
        v:PlaceCard(card1)
        H.advance(0.5)
        local box = { math.huge, math.huge, -math.huge, -math.huge }
        for _, t in ipairs(regions(card1)) do
          if t ~= card1.halo then
            local r = R.vrect(t)
            box = { math.min(box[1], r[1]), math.min(box[2], r[2]), math.max(box[3], r[3]), math.max(box[4], r[4]) }
          end
        end
        lowest, highest = math.min(lowest, box[2]), math.max(highest, box[4])
        if box[2] < content[2] - 0.01 or box[4] > content[4] + 0.01 then outW[#outW + 1] = i .. "/" .. tostring(opts.playable) end
        card1.hover = false
        v:PlaceCard(card1)
        H.advance(0.5)
      end
    end
    print(("      main : carte levée de %d, du haut %.1f au bas %.1f (fenêtre 0 à %.1f)")
      :format(Wd.CARD_LIFT, content[4] - highest, content[4] - lowest, content[4] - content[2]))
    check("main : carte levée (halo exclu) dans la fenêtre, à toutes les places, injouable comprise", #outW == 0,
      table.concat(outW, ", "))
  end

  -- 4. noms abrégés : en anglais, « Power Word: Radiance » ne tient pas au palier 9 (relevé du
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
  local PLATE = { "^Cooldown %d+%.$", "^Exhaust%.$", "^Retain%.$", "^Cast%.$", "^Power%.$", "^Trap%.$" }
  local function isPlate(cl) for _, p in ipairs(PLATE) do if cl:find(p) then return true end end return false end
  -- ligne d'état sous condition d'état (« Stealth: apply Stunned 1 ⌛ ») : ramenée à sa forme simple
  -- (« Apply Stunned 1 ⌛ ») et libellé de la condition ; une autre ligne est rendue telle quelle
  local function stateBody(cl)
    local lab, verb, rest = cl:match("^(%u[%a ]-): (%l%a*)( .*)$")
    if lab and (verb == "apply" or verb == "gain") then
      for _, s in pairs(ns.Statuses) do
        if s.name == lab then return verb:sub(1, 1):upper() .. verb:sub(2) .. rest, lab end
      end
    end
    return cl
  end
  -- libellé d'une condition d'effet (cond = "status:<id>", id d'état ou clé du registre du langage)
  local function condLabel(k)
    k = k:gsub("^status:", "")
    if ns.Statuses[k] then return ns.Statuses[k].name end
    local lc = ns.Language.conditionByKey(k)
    return lc and lc.name or k
  end
  -- ligne d'état : « Apply … », ou « Gain » suivi d'un nom (« Gain 5 Absorb. » est un effet)
  local function isStateCl(cl)
    cl = stateBody(cl)
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
          want[#want + 1] = { id = e[2], n = e[3], self = e.self, all = e.all, name = s.name, flag = s.flag,
            cond = e.cond and condLabel(e.cond) or nil }
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
          -- état à drapeau (Stealth) : sans nombre ; sous condition : « Name: apply … »
          if w.cond then verb = w.cond .. ": " .. verb:lower() end
          local expect = verb .. " " .. w.name .. (w.flag and "" or (" " .. tostring(w.n)))
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
          local name = stateBody(cl):match("^%S+ (.-) %d")
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
          -- libellés qui ne sont pas des conditions (déclencheurs de Pouvoir) : registre du langage
          if not known and not ns.Language.knownLabel(lab) then bad[#bad + 1] = label .. " : condition inconnue « " .. lab .. " »" end
        end
      end
    end
  end
  check(("textes : %d états posés, chacun sur sa ligne « Gain » (soi) / « Apply » (ennemi) en dernier, sablier seulement pour une durée, impersonnels")
    :format(nState), #bad == 0, table.concat(bad, "\n        "))
  -- grammaire commune, vérifiée depuis les données : Execute (condition « execute »), Surge (effet
  -- « surge »), Spend N (effet « spend »), Last Breath (empêche la mort), Shadow (Pouvoir d'ombre),
  -- Pay N HP (champ payHp, première clause), gains de ressource (« +N Rage. », nom de la ressource de
  -- la classe au singulier ou au pluriel), chiffres des formes conditionnelles
  local L = ns.Language
  local function usesCond(d, name)
    for _, e in ipairs(d.effects or {}) do
      if e.cond == name then return true end
      for _, m in ipairs(e.more or {}) do if m[2] == name then return true end end
    end
    return false
  end
  local function effectOf(d, kind)
    for _, e in ipairs(d.effects or {}) do if e[1] == kind then return e end end
    return nil
  end
  local function damageWith(d, pred)
    for _, e in ipairs(d.effects or {}) do if e[1] == "damage" and pred(e) then return e end end
    return nil
  end
  local cbad = {}
  local nForms = 0
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      local d = Card.defById(id, up)
      local label = id .. (up and "+" or "")
      local t = d.text or ""
      local cls = {}
      for _, cl in ipairs(clauses(t)) do if not isPlate(cl) then cls[#cls + 1] = cl end end
      local function has(n) return W.hasPhrase(t, n .. ":") end
      local cd = ns.Classes[d.class or ""]
      local rid = cd and cd.resource and cd.resource.id
      local r = rid and L.resources[rid]
      if has("Execute") ~= usesCond(d, "execute") then cbad[#cbad + 1] = label .. " : Execute" end
      if has("Surge") ~= (effectOf(d, "surge") ~= nil) then cbad[#cbad + 1] = label .. " : Surge" end
      -- Surge à 0 : une carte dont toutes les clauses sont « Surge: … » est injouable à 0 (minRes)
      local surgeOnly = #cls > 0
      for _, cl in ipairs(cls) do if not cl:find("^Surge: ") then surgeOnly = false end end
      if surgeOnly ~= ((d.minRes or 0) >= 1) then cbad[#cbad + 1] = label .. " : Surge seul <-> minRes" end
      if has("Last Breath") ~= (d.hooks ~= nil and d.hooks.preventDeath ~= nil) then cbad[#cbad + 1] = label .. " : Last Breath" end
      if has("Shadow") ~= (d.power == true and d.school == "shadow") then cbad[#cbad + 1] = label .. " : Shadow" end
      -- Spend N : champ spend = n (payé au jeu) <-> clause « Spend n: … »
      local sp = d.spend and { "spend", d.spend } or nil
      local spendCl
      for _, cl in ipairs(cls) do if cl:find("^Spend %d+: ") then spendCl = cl end end
      if (sp ~= nil) ~= (spendCl ~= nil) or (sp and not spendCl:find("^Spend " .. sp[2] .. ": ")) then
        cbad[#cbad + 1] = label .. " : Spend N"
      end
      if sp and spendCl then
        nForms = nForms + 1
        local dm = damageWith(d, function(e) return e.more ~= nil end)
        for _, m in ipairs(dm and dm.more or {}) do
          if m[2] == "spent" and not spendCl:find("deal " .. m[1] .. " more", 1, true) then cbad[#cbad + 1] = label .. " : chiffre de Spend" end
        end
      end
      -- Pay N HP : champ payHp <-> première clause « Pay N HP. »
      local payCl = cls[1] and cls[1]:match("^Pay (%d+) HP%.$")
      local anyPay = false
      -- une seule formulation pour une perte de PV sur une carte : « Pay N HP. » en première ligne
      -- (décisions communes) ; « Lose N HP » n'existe plus
      for _, cl in ipairs(cls) do
        if cl:find("^Pay %d+ HP") or cl:find("Lose %d+ HP") then anyPay = true end
      end
      if (d.payHp ~= nil) ~= (payCl ~= nil) or (d.payHp and tonumber(payCl) ~= d.payHp) or (anyPay and not payCl) then
        cbad[#cbad + 1] = label .. " : Pay N HP (première ligne, champ payHp)"
      end
      if d.payHp then nForms = nForms + 1 end
      -- gains de ressource : chaque effet { "res", n } sans condition a sa clause « +n Ressource. »
      for _, e in ipairs(d.effects or {}) do
        if (e[1] == "res" or e[1] == "demence") and not e.cond and not e.more and not e.per then
          nForms = nForms + 1
          local want = "+" .. e[2] .. " " .. (r and L.resourceName(rid, e[2]) or "?") .. "."
          local found = false
          for _, cl in ipairs(cls) do if cl == want then found = true end end
          if not found then cbad[#cbad + 1] = label .. " : clause « " .. want .. " » absente" end
        end
      end
      -- noms de ressource : seulement celle de la classe, accordée au nombre (« +1 Combo. »)
      for orid, res in pairs(L.resources) do
        if orid ~= rid and (W.hasPhrase(t, res.name) or W.hasPhrase(t, res.plural)) then
          cbad[#cbad + 1] = label .. " : ressource d'une autre classe (" .. res.name .. ")"
        end
      end
      if r and r.plural ~= r.name then
        for n, word in t:gmatch("%+(%d+) ([%a ]-)%.") do
          if word ~= L.resourceName(rid, tonumber(n)) and (word == r.name or word == r.plural) then
            cbad[#cbad + 1] = label .. " : accord « +" .. n .. " " .. word .. " »"
          end
        end
      end
      -- chiffres d'Execute (« Deal X. » / « Execute: deal X+k. ») et de Surge (« deal B + K per Res. »)
      local ex = damageWith(d, function(e) return e.more ~= nil end)
      for _, m in ipairs(ex and ex.more or {}) do
        if m[2] == "execute" and (not t:find("Deal " .. ex[2] .. "%.") or not t:find("Execute: deal " .. (ex[2] + m[1]) .. "%.")) then
          cbad[#cbad + 1] = label .. " : chiffres d'Execute"
        end
      end
      local sg = damageWith(d, function(e) return e.per ~= nil and e.per[2] == "surge" end)
      if sg and r then
        nForms = nForms + 1
        local phrase = (sg[2] > 0 and ("deal " .. sg[2] .. " + ") or "deal ") .. sg.per[1] .. " per " .. r.name
        -- ou en deux clauses : « Deal B. » puis « …: deal K per Res. » (Execute du Guerrier)
        local split = t:find("Deal " .. sg[2] .. ".", 1, true) and t:find("deal " .. sg.per[1] .. " per " .. r.name, 1, true)
        if not t:find(phrase, 1, true) and not split then
          cbad[#cbad + 1] = label .. " : Surge chiffré (« " .. phrase .. " » attendu)"
        end
      end
      if d.plagueMult and not t:find("apply DoT " .. d.plagueMult .. " per Insanity", 1, true) then
        cbad[#cbad + 1] = label .. " : Peste chiffrée"
      end
    end
  end
  check(("grammaire commune : Execute, Surge, Spend N, Last Breath, Shadow, Pay N HP, gains de ressource exactement sur les cartes qui les ont, chiffres justes (%d formes)"):format(nForms),
    #cbad == 0, table.concat(cbad, "\n        "))
  -- 2. mise en page : la ligne d'état commence une ligne et finit le texte ; en mode « clauses », chaque
  -- clause commence une ligne (elle peut se replier) ; tous les essais « clauses » (à tous les paliers)
  -- avant le premier texte coulé ; sablier en icône |T dans le texte posé, compté dans la mesure
  local card = W.card(UI().content)
  local lbad, nIcons = {}, 0
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      card:SetCard(id, up, { playable = true })
      local d = Card.defById(id, up)
      local label = id .. (up and "+" or "")
      local fit = card.bodyFit
      local shown = W.cardBodyText(card)
      local lines = clauses(shown)
      local pl = {}
      for k, l in ipairs(lines) do pl[k] = plain(l) end
      local cls = {}
      for _, cl in ipairs(clauses(d.text or "")) do if not isPlate(cl) then cls[#cls + 1] = cl end end
      -- première ligne d'état : en début de ligne ; plus rien après la dernière
      local firstState
      for _, cl in ipairs(cls) do if isStateCl(cl) then firstState = cl break end end
      if firstState then
        -- verbe puis nom (« Gain Atonement », « Apply DoT »), le verbe seul en fin de ligne possible
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
      -- mode « clauses » : chaque clause commence une ligne
      if fit.mode == "clauses" then
        for _, cl in ipairs(cls) do
          local head = plain(cl):match("^%S+")
          local found = false
          for _, l in ipairs(pl) do if l:sub(1, #head) == head then found = true end end
          if not found then lbad[#lbad + 1] = label .. " : clause « " .. cl .. " » au milieu d'une ligne" end
        end
      end
      -- ordre des essais : les clauses repliées à tous les paliers (secours compris) avant tout texte coulé
      local tries, flowed = W.cardTries(W.cardBody(d)), false
      for _, t in ipairs(tries) do
        if t.mode ~= "clauses" then flowed = true
        elseif flowed then lbad[#lbad + 1] = label .. " : essai coulé avant les clauses repliées à " .. t.size end
      end
      if fit.mode ~= "clauses" then lbad[#lbad + 1] = label .. " : texte coulé (" .. tostring(fit.mode) .. ")" end
      -- sablier : présent en icône dans le texte posé, autant que de « ⌛ » dans la source
      local nSrc = select(2, (d.text or ""):gsub(HG, ""))
      local nTex = select(2, shown:gsub("|T[^|]*hourglass%.tga[^|]*|t", ""))
      nIcons = nIcons + nTex
      if nSrc ~= nTex or shown:find(HG, 1, true) then
        lbad[#lbad + 1] = ("%s : %d sablier(s) dans le texte, %d icône(s) posée(s)"):format(label, nSrc, nTex)
      end
    end
  end
  check(("mise en page : états posés en début de ligne et en dernier, chaque clause en début de ligne (repliée au besoin), jamais de texte coulé, %d sabliers en icône |T"):format(nIcons),
    #lbad == 0, table.concat(lbad, "\n        "))
  -- l'icône est comptée dans la mesure (faux client comme le client : largeur de la séquence |T)
  local m = W.label(UI().content, "bold", 9)
  m:SetText("Atonement 1")
  local w0 = m:GetStringWidth()
  local hgt, wid = W.hourglassSize(9)
  m:SetText("Atonement 1" .. W.hourglass(9))
  local w1 = m:GetStringWidth()
  -- boîte : la hauteur du texte (séquence à hauteur nulle), carrée, à tous les paliers (la hauteur du
  -- dessin dans la boîte est vérifiée par UC, sur les pixels de la texture)
  local hOk = true
  for _, s in ipairs(W.BODY_SIZES) do
    local hh, ww = W.hourglassSize(s)
    if hh ~= s or ww ~= hh then hOk = false end
  end
  check(("sablier compté dans la mesure du texte (+%.1f unités à la taille 9, boîte %s), carré, à la hauteur du texte à chaque palier"):format(w1 - w0, tostring(hgt)),
    math.abs(w1 - w0 - wid) < 1e-6 and hgt == 9 and wid == hgt and hOk, w1 - w0)
  -- séquence |T : forme de CreateTextureMarkup (chemin:hauteur:largeur:x:y:largeur et hauteur du
  -- fichier:gauche:droite:haut:bas) + couleur r:g:b, entiers, hauteur et largeur NULLES (la taille du
  -- texte), fichier de Media/ présent (TGA 32 bits, 64 × 64, blanc), affiché ENTIER (coordonnées
  -- 0:64:0:64, aucun rognage), dessin posé à gauche de la boîte : marge de gauche d'environ une espace
  -- (0,15 à 0,25 cadratin), alpha nul sur les colonnes du bord
  local mk = W.hourglass(8.5)
  local f = {}
  for v in (mk:match("^|T(.-)|t$") .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
  local allInt = #f == 14
  for k = 2, 14 do if not (f[k] or ""):match("^%d+$") then allInt = false end end
  local tga = io.open(root .. "/Media/hourglass.tga", "rb")
  local hdr = tga and tga:read(18)
  local body = tga and tga:read("*a")
  if tga then tga:close() end
  local PX = 64
  local white = body and #body == PX * PX * 4
  local xmin, xmax = PX, -1
  if white then
    for i = 1, #body, 4 do
      if body:byte(i) ~= 255 or body:byte(i + 1) ~= 255 or body:byte(i + 2) ~= 255 then white = false break end
      if body:byte(i + 3) > 8 then
        local x = ((i - 1) / 4) % PX
        xmin, xmax = math.min(xmin, x), math.max(xmax, x)
      end
    end
  end
  local sym = xmin >= 0.15 * PX and xmin <= 0.25 * PX and xmax < PX - 2
  local full = f[6] == tostring(PX) and f[7] == tostring(PX) and f[8] == "0" and f[9] == tostring(PX)
    and f[10] == "0" and f[11] == tostring(PX) and f[2] == "0" and f[3] == "0"
  check(("séquence |T du sablier : 14 champs entiers, hauteur nulle, Media/hourglass.tga 64 × 64 TGA 32 bits, blanc (teinté par la séquence), entier, marge de gauche d'une espace (x %d à %d)"):format(xmin, xmax),
    allInt and f[1] == W.HOURGLASS and hdr and hdr:byte(3) == 2 and hdr:byte(17) == 32 and full and sym
      and hdr:byte(13) + 256 * hdr:byte(14) == PX and hdr:byte(15) + 256 * hdr:byte(16) == PX and white, mk)
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
      for _, res in pairs(ns.Language.resources) do
        if W.hasPhrase(t, res.name) or W.hasPhrase(t, res.plural) then need(res.name, res.name .. ": ") end
      end
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
  -- explications du registre du langage (conditions, plaque, mots, ressources) : présentes, une
  -- phrase courte, la ressource de chaque classe substituée
  local kbad = {}
  local reslist = {}
  for rid in pairs(ns.Language.resources) do reslist[#reslist + 1] = rid end
  table.sort(reslist)
  for _, k in ipairs({ "turns", "absorb", "interrupt" }) do
    local l = Art.keywords[k] and plain(Art.keywordLine(k)) or ""
    if l == "" or W.utf8len(l) > 60 then kbad[#kbad + 1] = k end
  end
  local function okLine(key, n)
    for _, rid in ipairs(reslist) do
      local l = plain(Art.keywordLine(key, nil, n, rid))
      if W.utf8len(l) > 60 or l:find("%s", 1, true) or l:find("[;()]") or select(2, l:gsub("%. ", "")) > 0 then
        kbad[#kbad + 1] = key .. " (" .. rid .. ") : « " .. l .. " »"
        return
      end
    end
  end
  for _, c in ipairs(ns.Language.conditions) do okLine(c.key, 2) end
  for _, p in ipairs(ns.Language.plates) do okLine(p.key, 2) end
  for key in pairs(ns.Language.keywords) do okLine(key, 2) end
  for _, rid in ipairs(reslist) do okLine("res:" .. rid) end
  for sid in pairs(Art.statusShort) do
    if not ns.Statuses[sid] or W.utf8len(plain(Art.statusLine(sid))) > 60 then kbad[#kbad + 1] = "état " .. sid end
  end
  check(("registre du langage : %d conditions, %d mots de plaque, %d ressources, sablier et définitions courtes des états, une ligne de 60 caractères au plus")
    :format(#ns.Language.conditions, #ns.Language.plates, #reslist), #kbad == 0, table.concat(kbad, ", "))
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

print("UT texte des cartes replié plutôt que réduit : palier maximal, plancher 8,5, coupures permises, toutes les classes et les neutres")
do
  freshRun(SEED, "combat")
  H.settle()
  local ns = H.ns
  local W, Card, L = ns.Widgets, ns.Card, ns.Language
  local TZ, CW = W.CARD_TEXT, W.CARD_W
  local HG = W.HOURGLASS_CHAR
  local FLOOR = 8.5
  -- paliers sous 8,5 prouvés maximaux (aucune coupure permise ne fait tenir le texte plus grand) :
  -- aucune carte aujourd'hui ; une entrée ici doit être justifiée (docs/interface.md)
  local EXCEPT = {}
  local top, bottom = TZ.top * CW, TZ.bottom * CW
  -- lignes que la zone contient à chaque palier (hauteur de ligne mesurée, garde du bas comprise)
  local caps = {}
  for _, s in ipairs(W.BODY_SIZES) do
    local m = W.label(UI().content, "bold", s)
    m:SetText("Ég")
    caps[#caps + 1] = ("%s → %d"):format(s, math.floor((bottom - top - W.TEXT_BOTTOM_GUARD) / m:GetStringHeight() + 1e-6))
    m:Hide()
  end
  print("      lignes par palier (zone de " .. ("%.1f"):format(bottom - top) .. " unités) : " .. table.concat(caps, ", "))
  local card = W.card(UI().content)
  local ids = {}
  for id in pairs(ns.Cards) do ids[#ids + 1] = id end
  table.sort(ids)
  -- noms en plusieurs mots (états, conditions, ressources)
  local phrases = {}
  local function addPhrase(n)
    if n and n:find(" ", 1, true) then
      local ws = {}
      for w in n:gmatch("%S+") do ws[#ws + 1] = w end
      phrases[#phrases + 1] = ws
    end
  end
  for _, k in ipairs(W.keywordList()) do addPhrase(k.name) end
  for _, r in pairs(L.resources) do addPhrase(r.name) addPhrase(r.plural) end
  local statusNames = {}
  for _, s in pairs(ns.Statuses) do statusNames[#statusNames + 1] = s.name end
  local function plain(t)
    return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", HG):gsub("\194\160", " "))
  end
  local function bare(w) return (w:gsub("[.,:;]+$", "")) end
  local NUMVERBS = { deal = true, heal = true, draw = true, pay = true, lose = true, spend = true, cooldown = true, cost = true, costs = true }
  local COUNTED = { more = true, mana = true, damage = true, HP = true }
  local TAIL = { to = true, per = true, once = true, twice = true }
  local NUMW = { two = true, three = true, four = true, five = true, six = true, seven = true, eight = true }
  local classes = { "priest", "warrior", "mage", "rogue", "hunter", "neutral" }
  local dist, under, notMax, bad = {}, {}, {}, {}
  local kinds = { cond = 0, comma = 0, state = 0, tail = 0, any = 0 }
  local anyList, gains = {}, {}
  local nCards, nGap = 0, 0
  for _, c in ipairs(classes) do dist[c] = {} end
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      card:SetCard(id, up, { playable = true })
      local d = Card.defById(id, up)
      local label = id .. (up and "+" or "")
      local cls = d.class or "neutral"
      local fit = card.bodyFit
      nCards = nCards + 1
      if (fit.gap or 0) > 0 then nGap = nGap + 1 end
      dist[cls] = dist[cls] or {}
      dist[cls][fit.size] = (dist[cls][fit.size] or 0) + 1
      if not fit.ok or (fit.size < FLOOR and not EXCEPT[label]) then under[#under + 1] = label .. " (" .. tostring(fit.size) .. ")" end
      -- palier maximal : aucun palier plus grand ne tient, quelle que soit la coupure permise
      local paras = W.cardParagraphs(W.cardBody(d), "clauses")
      for _, s in ipairs(W.BODY_SIZES) do
        if s > fit.size and W.layoutBody(paras, s, top, bottom) then
          notMax[#notMax + 1] = ("%s : %s choisi, %s tient"):format(label, tostring(fit.size), tostring(s))
        end
      end
      -- coupures à l'intérieur d'une clause
      local lines = {}
      for l in (W.cardBodyText(card) .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = plain(l) end
      if #lines ~= fit.lines then bad[#bad + 1] = label .. " : " .. #lines .. " lignes affichées, " .. tostring(fit.lines) .. " posées" end
      for k = 1, #lines do
        local l = lines[k]
        local only = l:match("^(%S+)$")
        if only and #bare(only) <= 3 and not only:find("%d") and not only:find(":$") and #lines > 1 then
          bad[#bad + 1] = ("%s : ligne d'un seul petit mot « %s »"):format(label, only)
        end
        if l:find("^" .. HG) then bad[#bad + 1] = label .. " : sablier en début de ligne" end
        if k < #lines and fit.clause and fit.clause[k] == fit.clause[k + 1] then
          local a = l:match("(%S+)$") or ""
          local b = lines[k + 1]:match("^(%S+)") or ""
          local why
          local an = (a:gsub("^−", "-"))
          if an:match("^[+%-]?%d+$") and (bare(b):find("^%u") or COUNTED[bare(b)]) then why = "nombre séparé de ce qu'il compte"
          elseif an:match("^%+%d+$") then why = "« +N » séparé de son nom"
          elseif NUMVERBS[a:lower()] and b:gsub("^−", "-"):match("^[+%-]?%d") then why = "verbe séparé de son nombre"
          elseif b:match("^%d+[.,:]?$") or b:match("^%d+" .. HG) then why = "nombre séparé du mot d'avant"
          elseif a == "+" or b == "+" then why = "opérateur en bout de ligne"
          end
          for _, ph in ipairs(phrases) do
            for i = 1, #ph - 1 do
              if bare(a) == ph[i] and bare(b) == ph[i + 1] then why = "nom en deux mots coupé (" .. table.concat(ph, " ") .. ")" end
            end
          end
          if why then bad[#bad + 1] = ("%s : %s (« %s » / « %s »)"):format(label, why, a, b) end
          -- nature de la coupure (ordre de préférence : cond, comma, state, tail, any)
          local kind
          local isState = false
          for _, n in ipairs(statusNames) do if lines[k + 1]:sub(1, #n) == n then isState = true end end
          if a:find(":$") then kind = "cond"
          elseif a:find(",$") then kind = "comma"
          elseif (a == "Apply" or a == "Gain" or a == "apply" or a == "gain") and isState then kind = "state"
          elseif TAIL[b:lower()] or (NUMW[b:lower()] and (lines[k + 1]:match("^%S+ (%S+)") or ""):find("^times")) then kind = "tail"
          else kind = "any" anyList[#anyList + 1] = ("%s « %s / %s »"):format(label, l, lines[k + 1]) end
          kinds[kind] = kinds[kind] + 1
        end
      end
    end
  end
  local function row(t)
    local ks, out, n, big = {}, {}, 0, 0
    for k, v in pairs(t) do ks[#ks + 1] = k n = n + v if k >= 9.5 then big = big + v end end
    table.sort(ks, function(a, b) return a > b end)
    for _, k in ipairs(ks) do out[#out + 1] = k .. " : " .. t[k] end
    return table.concat(out, ", ") .. (" (%d sur %d à 9,5 ou plus)"):format(big, n), big, n
  end
  local bigAll, nAll = 0, 0
  for _, c in ipairs(classes) do
    local r, big, n = row(dist[c])
    bigAll, nAll = bigAll + big, nAll + n
    print(("      %-8s %s"):format(c, r))
  end
  print(("      coupures dans une clause : après une condition %d, après une virgule %d, verbe / état %d, avant « to / per / once / N times » %d, ailleurs %d"):format(
    kinds.cond, kinds.comma, kinds.state, kinds.tail, kinds.any))
  print("      coupures « ailleurs » (dernier recours) : " .. (#anyList > 0 and table.concat(anyList, ", ") or "aucune"))
  print(("      écart d'un tiers de ligne entre les clauses : %d textes sur %d (quand la hauteur le permet)"):format(nGap, nCards))
  check(("toutes les cartes (%d, base et améliorées) à 8,5 ou plus, exceptions justifiées seulement ; la grande majorité à 9,5–10 (%d)"):format(nCards, bigAll),
    #under == 0 and bigAll * 4 >= nAll * 3, table.concat(under, ", "))
  check("palier maximal effectivement choisi : aucun palier plus grand ne tient, quelle que soit la coupure permise",
    #notMax == 0, table.concat(notMax, "\n        "))
  check("coupures permises seulement : jamais un nombre séparé de ce qu'il compte, un nom en deux mots coupé, un sablier seul, un petit mot seul sur sa ligne",
    #bad == 0, table.concat(bad, "\n        "))
  -- tri des coupures d'une clause : coûts dans l'ordre de préférence demandé
  local B = W.BREAK
  check("ordre de préférence des coupures : entre clauses < condition < virgule < verbe / état < « to / per / N times » < ailleurs",
    B.clause < B.cond and B.cond < B.comma and B.comma < B.state and B.state < B.tail and B.tail < B.any)
  -- groupes insécables de quelques clauses typiques (mesure sans police : W.clauseGroups seul)
  local function groupsOf(t)
    local g = W.clauseGroups(t)
    local out = {}
    for _, x in ipairs(g.groups) do out[#out + 1] = x.plain end
    return table.concat(out, " | ")
  end
  local expect = {
    { W.inlineIcons("Apply Demoralized\194\1602 ⌛ to\194\160all", 10), "Apply | Demoralized 2⌛ | to all" },
    { "Deal 6 three times.", "Deal 6 | three times." },
    { "Atonement: +2 Absorb per hit.", "Atonement: | +2 Absorb | per | hit." },
    { "+1 Charge.", "+1 Charge." },
    { "Surge: deal 4 + 4 per Insanity.", "Surge: | deal 4 + 4 | per | Insanity." },
    { "Pay 3 HP.", "Pay 3 HP." },
    { "Surge: pet attacks once per Frenzy.", "Surge: | pet | attacks | once per | Frenzy." },
  }
  local gbad = {}
  for _, e in ipairs(expect) do
    local got = groupsOf(e[1])
    if got ~= e[2] then gbad[#gbad + 1] = ("« %s » -> « %s » (attendu « %s »)"):format(e[1], got, e[2]) end
  end
  check("groupes insécables : nombre et nom, verbe et nombre, « N times », « to all », noms en deux mots, opérateur",
    #gbad == 0, table.concat(gbad, "\n        "))
  card:Hide()
  -- aperçus : cartes du Prêtre (base, améliorée) ; gros plan de cinq cartes (texte_gros_plan.svg)
  if SNAP then
    local pids = {}
    for id, d in pairs(ns.Cards) do if d.class == "priest" then pids[#pids + 1] = id end end
    table.sort(pids)
    local perRow, cw, ch = 10, 140, 230
    local all = {}
    for _, id in ipairs(pids) do all[#all + 1] = { id, false } all[#all + 1] = { id, true } end
    local big = CreateFrame("Frame", nil, _G.UIParent)
    big:SetSize(perRow * cw + 20, math.ceil(#all / perRow) * ch + 10)
    big:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
    big:SetScale(1.5)
    for i, e in ipairs(all) do
      local c = W.card(big)
      c:SetCard(e[1], e[2], { playable = true })
      W.placeCenter(c, big, 80 + ((i - 1) % perRow) * cw, 125 + math.floor((i - 1) / perRow) * ch, 1)
    end
    Render.svg(H, big, SNAP .. "/cartes_priest.svg", "cartes du Prêtre (base, améliorée)")
    big:Hide()
    local five = { "freezing_trap", "schism", "psychic_scream", "colossus_smash", "thunder_clap" }
    local zoom = CreateFrame("Frame", nil, _G.UIParent)
    zoom:SetSize(#five * 140 + 20, 240)
    zoom:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
    zoom:SetScale(3)
    for i, id in ipairs(five) do
      local c = W.card(zoom)
      c:SetCard(id, false, { playable = true })
      W.placeCenter(c, zoom, 80 + (i - 1) * 140, 125, 1)
    end
    Render.svg(H, zoom, SNAP .. "/texte_gros_plan.svg", "texte des cartes, gros plan")
    zoom:Hide()
  end
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

  -- rencontre : ombre du héros, ombre du PNJ seulement quand son modèle est chargé (elle apparaît
  -- avec lui)
  freshRun(SEED + 4, "event")
  local ch = UI().current
  local npcKey = "npc:" .. tostring(UI().step.npc)
  local function loadedNpc() local st = H.ns.Widgets.models[npcKey] return st and st.state == "ok" end
  check("rencontre : pas d'ombre du PNJ avant le chargement de son modèle", not ch.npc.shadow:IsShown())
  H.advance(1)
  local ebad = {}
  shadowBad(ch.hero, "héros (rencontre)", ebad)
  if loadedNpc() then shadowBad(ch.npc, "PNJ", ebad) end
  check("rencontre : ombre du héros sous les pieds ; ombre du PNJ affichée avec son modèle chargé",
    #ebad == 0 and loadedNpc() and ch.npc.shadow:IsShown(), table.concat(ebad, " ; "))
end

print("U29 textes affichés en anglais : aucune chaîne française dans Core/, Data/, UI/ ni le TOC")
do
  -- Chaînes du code (hors commentaires) des fichiers du TOC, plus Title et Notes du TOC. Une chaîne est
  -- française si elle contient une lettre accentuée latine, des guillemets « », ou un mot-outil
  -- français. Exceptions : textes de mesure de police (jamais lus par le joueur).
  local KEEP = { ["\195\137\195\169"] = true, ["\195\137g"] = true }
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
      local sliced = e and o._calls.SetTextureSliceMargins
      if sliced and visible(o) and under(o, fr) then
        -- découpée par le client : marges (bouts, coins) à l'échelle propre de la région, jamais agrandies
        local s = 1
        local p = o
        while p and p ~= fr do s = s * (rawget(p, "_scale") or 1) p = rawget(p, "_parent") end
        s = s * (fr._scale or 1)
        if s > 1.01 then blurry[#blurry + 1] = string.format("%s : %s découpée, %.2f unité par pixel", where, wn, s) end
      elseif e and not e.tile and tc and visible(o) and under(o, fr)
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
  H.click(UI().optionsClose)

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
  H.click(Um.optionsClose)
  Um.toggleDeckView("deck")
  Um.flash("Test message.")
  check("message passager au-dessus du panneau du deck", Um.deckView:IsShown() and errOver(Um.deckView.frame) == 0)
  H.click(Um.deckView.close)
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
    local sm = tex._calls.SetTextureSliceMargins
    if sm then
      -- pièce entière découpée par le client : marges à 1 pixel = 1 unité de la région (échelle propre
      -- comprise), centre étiré
      local s, p = 1, tex
      while p do s = s * (rawget(p, "_scale") or 1) p = rawget(p, "_parent") end
      local function map(px, n, m0, m1, lo, hi)
        if px <= m0 then return lo + px * s end
        if px >= n - m1 then return hi - (n - px) * s end
        return lo + m0 * s + (px - m0) * ((hi - lo) - (m0 + m1) * s) / math.max(1e-9, n - m0 - m1)
      end
      for y = 0, m.ph - 1 do
        for x = 0, m.pw - 1 do
          if m.ext[y * m.pw + x] then
            local l, rr = map(x, m.pw, sm[1], sm[3], r[1], r[3]), map(x + 1, m.pw, sm[1], sm[3], r[1], r[3])
            local t0, t1 = map(y, m.ph, sm[2], sm[4], 0, r[4] - r[2]), map(y + 1, m.ph, sm[2], sm[4], 0, r[4] - r[2])
            out[#out + 1] = { l, r[4] - t1, rr, r[4] - t0 }
          end
        end
      end
      return out
    end
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
  H.click(Um.optionsClose)
  Um.toggleDeckView("deck")
  dl("deck")
  H.click(Um.deckView.close)

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

print("U33 personnages : noms, cadres, barres, anneaux, éclats et textes flottants au-dessus des modèles 3D ; ombre dessous ; nom hors du modèle")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
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
  local function above(o, t) return R.drawnBefore(R.drawKey(t), R.drawKey(o)) end
  local function inter(a, b) return a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5 end
  local function isRegion(o)
    local k = rawget(o, "_kind")
    if k == "Texture" then return rawget(o, "_texture") ~= nil or (o._calls.SetColorTexture ~= nil) end
    if k == "FontString" then return (rawget(o, "_text") or "") ~= "" end
    return false
  end
  local function nameOf(o)
    return tostring(rawget(o, "_text") or rawget(o, "_wow") or rawget(o, "_texture") or rawget(o, "_kind"))
  end

  -- 1. règle du faux client : un cadre de modèle recouvre les régions (toutes couches) des cadres de
  -- niveau inférieur ou égal créés avant lui ; un cadre de niveau supérieur passe dessus
  do
    local top = CreateFrame("Frame", nil, UIParent)
    local low = CreateFrame("Frame", nil, top)
    low:SetFrameLevel(5)
    local eq = CreateFrame("Frame", nil, top)
    eq:SetFrameLevel(7)
    local tl, te = low:CreateFontString(nil, "OVERLAY"), eq:CreateFontString(nil, "OVERLAY")
    local m = CreateFrame("PlayerModel", nil, top)
    m:SetFrameLevel(7)
    local high = CreateFrame("Frame", nil, top)
    high:SetFrameLevel(8)
    local th = high:CreateTexture(nil, "BACKGROUND", nil, -8)
    check("faux client : un modèle (niveau 7) recouvre le texte d'un cadre de niveau 5 et d'un cadre de niveau 7 créé avant lui ; une texture de fond d'un cadre de niveau 8 passe dessus",
      above(m, tl) and above(m, te) and above(th, m))
    top:Hide()
  end

  -- 2. écran par écran
  local function regionsOf(rootObj)
    local out = {}
    if not rootObj then return out end
    for _, o in ipairs(H.objects) do
      if isRegion(o) and (o == rootObj or under(o, rootObj)) and vis(o) then out[#out + 1] = o end
    end
    return out
  end
  local function models()
    local out = {}
    for _, o in ipairs(H.objects) do
      if rawget(o, "_kind") == "PlayerModel" and under(o, H.ns.UI.content) and vis(o) then out[#out + 1] = o end
    end
    return out
  end
  -- assoc : { { libellé, cadre ou région } } (éléments d'interface des personnages) ; figs : { { libellé,
  -- personnage, nom } } (ombre sous le modèle, nom hors de son rectangle)
  local function sceneCheck(where, assoc, figs)
    local ms = models()
    local bad, n = {}, 0
    for _, a in ipairs(assoc) do
      for _, o in ipairs(regionsOf(a[2])) do
        n = n + 1
        for _, m in ipairs(ms) do
          if not above(o, m) then bad[#bad + 1] = a[1] .. " (" .. nameOf(o) .. ")" break end
        end
      end
    end
    check(("%s : les %d éléments d'interface des personnages sont dessinés au-dessus des %d modèles 3D"):format(where, n, #ms),
      n > 0 and #ms > 0 and #bad == 0, table.concat(bad, ", "))
    -- tout texte visible du contenu qui croise un modèle est dessiné au-dessus de lui
    local hidden = {}
    for _, o in ipairs(H.objects) do
      if rawget(o, "_kind") == "FontString" and isRegion(o) and under(o, H.ns.UI.content) and vis(o) and alphaOf(o) > 0.01 then
        local r = R.rect(o)
        for _, m in ipairs(ms) do
          local mr = R.rect(m)
          if r and mr and inter(r, mr) and not above(o, m) then hidden[#hidden + 1] = nameOf(o) break end
        end
      end
    end
    check(where .. " : aucun texte visible n'est recouvert par un modèle", #hidden == 0, table.concat(hidden, ", "))
    local sbad, nbad = {}, {}
    for _, f in ipairs(figs) do
      local fig, nm = f[2], f[3]
      if fig.model and vis(fig.model) then
        for i, part in ipairs(fig.shadow.parts) do
          if vis(part) and not above(fig.model, part) then sbad[#sbad + 1] = f[1] .. " couche " .. i end
        end
        if nm and vis(nm) and (rawget(nm, "_text") or "") ~= "" then
          local nr, mr = R.rect(nm), R.rect(fig.model)
          if nr and mr and inter(nr, mr) then
            nbad[#nbad + 1] = ("%s : nom [%.0f, %.0f] dans le modèle [%.0f, %.0f] (hauteur)"):format(f[1], nr[2], nr[4], mr[2], mr[4])
          end
        end
      end
    end
    check(where .. " : ombre de contact sous le modèle de chaque personnage", #sbad == 0, table.concat(sbad, ", "))
    check(where .. " : le nom de chaque personnage ne chevauche pas le rectangle de son modèle", #nbad == 0, table.concat(nbad, " ; "))
  end
  local function heroRing(fig) fig:SetRing(true) return { "anneau du héros", fig.ring } end

  -- accueil
  H.boot()
  H.slash("")
  local st = UI().current
  sceneCheck("accueil", { heroRing(st.hero) }, { { "héros", st.hero } })
  st.hero:SetRing(false)

  -- combat : héros, ennemis (anneaux de cible allumés, cible visée agrandie), texte flottant
  freshRun(SEED, "combat")
  H.settle()
  local v = V()
  local assoc = { { "cadre du héros", v.heroFrame }, { "états du héros", v.playerSt }, { "éclat du héros", v.hero.flash },
    heroRing(v.hero) }
  if v.cast:IsShown() then assoc[#assoc + 1] = { "incantation", v.cast } end
  local figs = { { "héros", v.hero } }
  local first
  for _, s in pairs(v.slotOf) do
    if s:IsVisible() then
      first = first or s
      local nm = tostring(s.name._text)
      s.fig:SetRing(true)
      assoc[#assoc + 1] = { nm .. " : cadre, intention, états", s.info }
      assoc[#assoc + 1] = { nm .. " : éclat", s.flash }
      assoc[#assoc + 1] = { nm .. " : anneau de cible", s.fig.ring }
      figs[#figs + 1] = { nm, s.fig, s.name }
    end
  end
  local fl = H.ns.Widgets.float(v.parent, 700, 200, "-12", H.ns.Art.C.white, 30)
  assoc[#assoc + 1] = { "texte flottant", fl }
  sceneCheck("combat", assoc, figs)
  snap("combat-anneaux") -- aperçu : anneaux de cible allumés, texte flottant
  -- ennemi visé (agrandi) : nom toujours hors du modèle
  if first then
    H.ns.Widgets.animSet(first, "aim", 1)
    sceneCheck("combat, ennemi visé", { { "cadre de l'ennemi visé", first.info } }, { { "ennemi visé", first.fig, first.name } })
    H.ns.Widgets.animSet(first, "aim", 0)
  end
  for _, s in pairs(v.slotOf) do s.fig:SetRing(false) end
  v.hero:SetRing(false)
  H.advance(2)
  -- personnages agrandis (golem, VanCleef) aux places décalées, sans puis avec la visée, petite et
  -- grande échelle de la fenêtre
  local group = { "murloc", "harvest_golem", "sorcerer", "vancleef" }
  for _, scale in ipairs({ 0.6, 1.5 }) do
    H.ns.Persist.options().scale = scale
    H.ns.UI.applyScale()
    local c = C().combat()
    c.enemies = {}
    for _, id in ipairs(group) do H.ns.Combat.spawn(c, id) end
    v.c = nil
    v:Show({ state = c })
    H.advance(0.5)
    for _, aim in ipairs({ 0, 1 }) do
      local ga, gf = {}, {}
      for _, s in pairs(v.slotOf) do
        if s:IsVisible() then
          H.ns.Widgets.animSet(s, "aim", aim)
          s.fig:SetRing(true)
          ga[#ga + 1] = { tostring(s.name._text), s.info }
          ga[#ga + 1] = { tostring(s.name._text) .. " : anneau", s.fig.ring }
          gf[#gf + 1] = { tostring(s.name._text), s.fig, s.name }
        end
      end
      sceneCheck(("combat, %d ennemis dont 2 agrandis, échelle %.1f, visée %d"):format(#gf, scale, aim), ga, gf)
      for _, s in pairs(v.slotOf) do H.ns.Widgets.animSet(s, "aim", 0) s.fig:SetRing(false) end
    end
  end
  H.ns.Persist.options().scale = 1
  H.ns.UI.applyScale()

  -- rencontre : PNJ (nom, voile du nom, anneau), héros
  freshRun(SEED + 4, "event")
  local ch = UI().current
  local npcName = ch.npc.name or ch.speaker
  check("rencontre : PNJ affiché avec son modèle et son nom",
    ch.npc.model:IsVisible() and (npcName._text or "") ~= "", tostring(npcName._text))
  ch.npc:SetRing(true)
  local ea = { { "nom du PNJ", npcName }, { "anneau du PNJ", ch.npc.ring }, heroRing(ch.hero) }
  if ch.npc.nameBack then ea[#ea + 1] = { "voile du nom du PNJ", ch.npc.nameBack } end
  sceneCheck("rencontre", ea, { { "PNJ", ch.npc, npcName }, { "héros", ch.hero } })
  ch.npc:SetRing(false)
  ch.hero:SetRing(false)
  -- même nom, même place, aux échelles extrêmes de la fenêtre
  for _, scale in ipairs({ 0.6, 1.5 }) do
    H.ns.Persist.options().scale = scale
    H.ns.UI.applyScale()
    sceneCheck(("rencontre, échelle %.1f"):format(scale), { { "nom du PNJ", npcName } }, { { "PNJ", ch.npc, npcName } })
  end
  H.ns.Persist.options().scale = 1
  H.ns.UI.applyScale()

  -- feu de camp, coffre
  freshRun(SEED + 3, "campfire")
  local cp = UI().current
  sceneCheck("feu de camp", { heroRing(cp.hero) }, { { "héros", cp.hero } })
  cp.hero:SetRing(false)
  freshRun(SEED + 5, "chest")
  local rw = UI().current
  if rw.hero then
    sceneCheck("coffre", { heroRing(rw.hero) }, { { "héros", rw.hero } })
    rw.hero:SetRing(false)
  end
end

print("U34 textes jamais tronqués ni recoupés par le client : cartes (toutes les échelles d'écran, aperçu), réponses, boutons (client défavorable)")
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
    -- blocs suivants du texte (écart entre clauses)
    for b = 2, c.bodyUsed or 1 do list[#list + 1] = { "texte (bloc " .. b .. ")", c.bodyParts[b] } end
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
  -- (1) toutes les cartes, base et améliorées, jouables et injouables, à chaque échelle de fenêtre et
  -- d'écran : main et aperçu des petites cartes (1), récompense (1,08), marchand (0,92), grille (0,75),
  -- panneau du deck (0,72), progression (0,6), bilan (0,5). Plus aucune échelle de survol : la carte
  -- survolée a le texte du repos (levée ou aperçu à l'échelle 1).
  local holder = CreateFrame("Frame", nil, UI().content)
  local card = W.card(holder)
  local SCREENS = { { "main", 1 }, { "récompense", 1.08 }, { "marchand", 0.92 }, { "grille", 0.75 }, { "deck", 0.72 },
    { "progression", 0.6 }, { "bilan", 0.5 } }
  local VARS = { { "", { playable = true } }, { " (injouable)", { playable = false, reason = "Not enough mana." } } }
  local bad, cases = {}, 0
  for _, ws in ipairs(SCALES) do
    frame:SetScale(ws)
    for _, sc in ipairs(SCREENS) do
      holder:SetScale(sc[2])
      for _, id in ipairs(ids) do
        for _, up in ipairs({ false, true }) do
          for _, var in ipairs(VARS) do
            card:SetCard(id, up, var[2])
            cases = cases + 1
            cardBad(card, ("%s%s%s, fenêtre %.2f, %s"):format(id, up and "+" or "", var[1], ws, sc[1]), bad)
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
  check(("%d cartes × base/améliorée × jouable/injouable × fenêtre 1 / 1,15 / 1,5 / 0,6 × 7 échelles d'écran (%d cas) : aucun texte tronqué ni recoupé")
    :format(#ids, cases), #bad == 0, head(bad, 12))
  -- (2) la carte de la capture, en main, survolée (levée) et au repos
  local v = V()
  local hc = v.cards[1]
  local bad2 = {}
  for _, ws in ipairs(SCALES) do
    frame:SetScale(ws)
    for _, up in ipairs({ false, true }) do
      hc:SetCard("radiance", up, { playable = true })
      hc:Show()
      W.animSet(hc, "hover", 1)
      cardBad(hc, ("fenêtre %.2f, survolée ×%.3f"):format(ws, hc.face._scale * H.visualScale(hc.face)), bad2)
      W.animSet(hc, "hover", 0)
      cardBad(hc, ("fenêtre %.2f, au repos ×%.3f"):format(ws, hc.face._scale * H.visualScale(hc.face)), bad2)
    end
  end
  check("« PW: Radiance » en main, survolée (levée) et au repos, fenêtre 0,6 à 1,5 : deux lignes entières",
    #bad2 == 0, head(bad2, 8))
  -- garde-fou en jeu : un texte que le client tronque malgré tout fait descendre la carte d'un palier
  if not W.checkCardTexts then
    check("garde-fou : texte tronqué après la pose -> un palier plus bas (W.checkCardTexts)", false, "absent")
  else
    local c = W.card(holder)
    c:SetCard("radiance", false, { playable = true })
    local s0 = c.bodyFit.size
    local orig = c.body.IsTruncated
    c.body.IsTruncated = function() return true end
    W.checkCardTexts(c)
    c.body.IsTruncated = orig
    local log = W.truncatedLog()
    check("garde-fou : texte tronqué après la pose -> un palier plus bas, relevé pour /slay text",
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
      b:SetOption(o, w, h)
      cases3 = cases3 + 1
      for _, it in ipairs({ { "libellé", b.label }, { "texte", b.sub } }) do
        local why = textBad(it[2])
        if why then bad3[#bad3 + 1] = ("%s, fenêtre %.2f : %s « %s » %s"):format(label, ws, it[1],
          tostring(it[2]._text):gsub("\n", " / "), why) end
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
  check(("%d rencontres, réponses aux fenêtres 1 / 1,15 / 1,5 / 0,6 (%d cas ; le survol ne change que la surbrillance) : libellé et texte entiers")
    :format(#evIds, cases3), #bad3 == 0, head(bad3, 12))
  -- (4) libellés des boutons et autres textes des visuels survolables créés jusqu'ici (une ligne, largeur
  -- libre) : entiers à toute échelle de fenêtre (le survol ne change pas leur échelle)
  local bad4, n4 = {}, 0
  for _, o in ipairs(H.objects) do
    local face = rawget(o, "_parent")
    local owner = face and rawget(face, "_parent")
    if rawget(o, "_kind") == "FontString" and owner and rawget(owner, "face") == face and rawget(owner, "_hoverable")
      and (rawget(o, "_text") or "") ~= "" then
      n4 = n4 + 1
      for _, ws in ipairs(SCALES) do
        frame:SetScale(ws)
        local why = textBad(o)
        if why then bad4[#bad4 + 1] = ("« %s », fenêtre %.2f : %s"):format(tostring(o._text):gsub("\n", " / "), ws, why) end
      end
    end
  end
  check(("%d textes des visuels survolables (boutons, plaques, jetons…) : entiers aux fenêtres 1 / 1,15 / 1,5 / 0,6")
    :format(n4), n4 > 20 and #bad4 == 0, head(bad4, 12))
  H.strictText = false
  W.clearTextCache()
  frame:SetScale(scale0)
end

print("U35 classes : choix sur l'accueil, Guerrier en combat (pastille de Rage, portrait, nom), accueil à neuf classes")
do
  H.boot(nil)
  H.slash("")
  local ns = H.ns
  local W, Art = ns.Widgets, ns.Art
  -- accueil : Priest (order 1) choisi par défaut, Warrior proposé, puis les autres classes jouables
  -- dans l'ordre de leur champ order
  local ids = {}
  for _, o in ipairs(UI().step.options) do if o.group == "class" then ids[#ids + 1] = o.id end end
  local playable = {}
  for id, cd in pairs(ns.Classes) do if cd.playable ~= false then playable[#playable + 1] = cd end end
  table.sort(playable, function(a, b) return (a.order or 99) < (b.order or 99) end)
  local wantIds = {}
  for i, cd in ipairs(playable) do wantIds[i] = "class:" .. cd.id end
  check("accueil : classes jouables dans l'ordre (Priest, Warrior…), Priest choisi par défaut",
    table.concat(ids, ",") == table.concat(wantIds, ",") and ids[1] == "class:priest" and ids[2] == "class:warrior"
    and option("class:priest").selected and not option("class:warrior").selected, table.concat(ids, ","))
  local wb = button("class:warrior")
  local wtt = table.concat(H.hover(wb), " | ")
  check("accueil : icône du Guerrier, infobulle (nom, PV, cartes, niveau, clic)", wb and wb._shown
    and (wb.icon._texture or ""):lower():find("classicon_warrior", 1, true)
    and wtt:find("Warrior", 1, true) and wtt:find(ns.Classes.warrior.hp .. " HP, 10 cards", 1, true)
    and wtt:find("Level 1", 1, true) and wtt:find("Click", 1, true), wtt)
  local pb = button("class:priest")
  local function glowA(b) return b.glow._calls.SetAlpha and b.glow._calls.SetAlpha[1] or 1 end
  local function iconK(b) return b.icon._calls.SetVertexColor and b.icon._calls.SetVertexColor[1] or 1 end
  check("accueil : classe choisie mise en évidence (halo doré tenu), l'autre assombrie et sans halo",
    pb.selected and glowA(pb) > 0.5 and iconK(pb) == 1 and not wb.selected and glowA(wb) == 0 and iconK(wb) < 0.7,
    glowA(pb) .. " / " .. glowA(wb) .. " / " .. iconK(wb))
  -- survol d'une classe non choisie : halo et icône s'allument en fondu, sans grossir
  run(wb, "OnEnter")
  for _ = 1, 30 do run(W.driver, "OnUpdate", 0.02) H.now = H.now + 0.02 end
  check("accueil : survol d'une icône (éclairée, halo, à sa taille)", wb.face._scale == 1 and iconK(wb) == 1 and glowA(wb) > 0.3,
    wb.face._scale .. " / " .. iconK(wb) .. " / " .. glowA(wb))
  run(wb, "OnLeave")
  for _ = 1, 30 do run(W.driver, "OnUpdate", 0.02) H.now = H.now + 0.02 end
  clickOption("class:warrior")
  local st = UI().screens.start
  check("accueil : clic sur l'icône du Guerrier, il devient le choix (halo, nom sous la rangée)", option("class:warrior").selected
    and not option("class:priest").selected and button("class:warrior").selected and glowA(button("class:warrior")) > 0.5
    and not button("class:priest").selected and st.className._text == "Warrior")
  snap("accueil-guerrier", true)
  H.ns.Controller.makeSeed = function() return SEED end
  clickOption("go")
  local e = EXP()
  check("départ : expédition du Guerrier (classe, deck, Battle Standard)", e and e.class == "warrior"
    and ns.Cards[e.deck[1].id].class == "warrior" and e.relics[1] == "battle_standard")
  check("bandeau : nom de la classe", UI().className._text == "Warrior", UI().className._text)
  local id = e.map.start[1]
  e.map.nodes[id].kind = "combat"
  clickOption("path:" .. id)
  H.settle()
  local v = V()
  local c = e.combat
  check("combat du Guerrier : classe du combat, Rage 1 (Battle Standard)", c and c.class == "warrior" and c.player.res == 1)
  v:Render(true)
  local r = v.resource
  check("pastille de ressource : icône de la Rage, nombre, visible",
    r._shown and (r.icon._texture or ""):lower():find("ability_warrior_focusedrage", 1, true) and r.text._text == "1",
    tostring(r.icon._texture) .. " / " .. tostring(r.text._text))
  local tt = table.concat(H.hover(r), " | ")
  check("pastille de ressource : explication de la Rage et plafond", tt:find("Rage", 1, true) and tt:find("1 / 5", 1, true), tt)
  check("cadre du héros : nom et portrait = icône de classe (personnage d'une autre classe)",
    v.heroFrame.name._text == "Warrior" and (v.heroFrame.portrait._texture or ""):lower():find("classicon_warrior", 1, true),
    tostring(v.heroFrame.portrait._texture))
  local allW = #c.hand > 0
  for _, inst in ipairs(c.hand) do if ns.Cards[inst.id].class ~= "warrior" then allW = false end end
  check("main du Guerrier : ses cartes", allW)
  -- chiffre flottant de ressource au nom de la classe
  local floats = {}
  local old = W.float
  W.float = function(parent, x, y, text, ...) floats[#floats + 1] = text return old(parent, x, y, text, ...) end
  v:OnEvents({ { t = "resource", n = 2, total = 3 } })
  H.advance(2)
  W.float = old
  check("chiffre flottant : « +2 Rage »", table.concat(floats, "|"):find("+2 Rage", 1, true), table.concat(floats, "|"))
  -- zone libre de la classe : ns.ClassViews appelé (build une fois, render à chaque rendu)
  local built, rendered = 0, 0
  ns.ClassViews.warrior = { build = function() built = built + 1 end, render = function() rendered = rendered + 1 end }
  v:Render(true)
  v:Render(true)
  ns.ClassViews.warrior = nil
  check("zone libre de classe : build une fois, render à chaque rendu", built == 1 and rendered == 2, built .. "/" .. rendered)
  snap("combat-guerrier", true)
  -- carte du Guerrier jouée par l'interface (Strike) : Rage +1
  local hi
  for i, inst in ipairs(c.hand) do if inst.id == "strike" then hi = i end end
  if hi then
    local before = c.player.res
    H.ns.Controller.act({ "play", hi, 1 })
    H.settle()
    check("Strike jouée : +1 Rage", c.player.res == before + 1, c.player.res)
  end
  -- accueil à 2, 5 et 9 classes : une icône par classe, rangée centrée et régulière, dans le panneau et la
  -- fenêtre, au-dessus des clés ; aucune icône ne chevauche sa voisine (halo compris pour la choisie)
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local fakes = { "rogue", "mage", "hunter", "warlock", "paladin", "shaman", "druid" }
  local real = 0
  for _ in pairs(ns.Classes) do real = real + 1 end
  for _, want in ipairs({ 2, 5, 9 }) do
    H.boot(nil)
    ns = H.ns
    local added = {}
    for i = 1, math.max(0, want - real) do
      local f = fakes[i]
      local id = "zz_" .. f
      ns.Classes[id] = { id = id, name = f:sub(1, 1):upper() .. f:sub(2), order = 50 + i, hp = 70, deck = {},
        resource = { id = "rage" } }
      added[#added + 1] = id
    end
    H.slash("")
    H.settle()
    local st = UI().screens.start
    local panel = st.panel
    local pr, fr = R.rect(panel), R.rect(_G.SlayTheDragonFrame)
    local keyR = R.rect(st.keyLabel)
    local n, bad, xs = 0, {}, {}
    for _, b in ipairs(st.classIcons) do
      if b._shown then
        n = n + 1
        local r = R.rect(b)
        xs[#xs + 1] = (r[1] + r[3]) / 2
        if r[1] < pr[1] + 8 or r[3] > pr[3] - 8 or r[1] < fr[1] or r[3] > fr[3] then bad[#bad + 1] = "hors du panneau" end
        if r[2] < keyR[4] + 4 then bad[#bad + 1] = "sur les clés" end
        if math.abs((r[3] - r[1]) - (r[4] - r[2])) > 1e-6 then bad[#bad + 1] = "pas carrée" end
        local texts = 0
        for _, k in ipairs(rawget(b.face, "_kids")) do
          if rawget(k, "_kind") == "FontString" and (k._text or "") ~= "" then texts = texts + 1 end
        end
        if texts > 0 then bad[#bad + 1] = "texte sur l'icône" end
        local tt = table.concat(H.hover(b), " | ")
        if not (tt:find(b.option.label, 1, true) and tt:find("HP", 1, true)) then bad[#bad + 1] = "infobulle : " .. tt end
      end
    end
    local regular = true
    for i = 3, #xs do if math.abs((xs[i] - xs[i - 1]) - (xs[2] - xs[1])) > 1e-6 then regular = false end end
    local centered = #xs > 0 and math.abs((xs[1] + xs[#xs]) / 2 - (pr[1] + pr[3]) / 2) < 1e-6
    local w1 = n > 0 and R.rect(st.classIcons[1]) or { 0, 0, 0, 0 }
    local apart = #xs < 2 or (xs[2] - xs[1]) > (w1[3] - w1[1]) * 1.08 + 4
    local nameR = R.rect(st.className)
    local nameOk = st.className._shown and nameR[2] > keyR[4] and nameR[4] < w1[2] + 0.01
    check(("accueil à %d classes : %d icônes centrées, régulières, espacées, dans le panneau et la fenêtre, au-dessus des clés, nom de la choisie entre les deux"):format(want, n),
      n == math.max(want, real) and #bad == 0 and regular and centered and apart and nameOk,
      table.concat(bad, ", ") .. (regular and "" or " irrégulières") .. (centered and "" or " décentrées")
        .. (apart and "" or " serrées") .. (nameOk and "" or " nom mal placé"))
    -- clic sur la dernière : choisie (halo), départ inchangé (bouton existant)
    local last = st.classIcons[n]
    H.click(last)
    check(("accueil à %d classes : clic sur la dernière icône, elle devient le choix"):format(want),
      option(last.option.id).selected and button(last.option.id).selected, last.option.id)
    snap("accueil-" .. want .. "-classes", true)
    for _, id in ipairs(added) do ns.Classes[id] = nil end
  end
end

-- planche des cartes du Guerrier (base et améliorée), langage des cartes
if SNAP then
  local ns = H.ns
  local W = ns.Widgets
  local ids = {}
  for id, d in pairs(ns.Cards) do if d.class == "warrior" then ids[#ids + 1] = id end end
  local RANK = { basic = 0, common = 1, uncommon = 2, rare = 3 }
  local PATH = { start = 0, arms = 1, fury = 2, protection = 3 }
  table.sort(ids, function(a, b)
    local da, db = ns.Cards[a], ns.Cards[b]
    if PATH[da.path] ~= PATH[db.path] then return PATH[da.path] < PATH[db.path] end
    if RANK[da.rarity] ~= RANK[db.rarity] then return RANK[da.rarity] < RANK[db.rarity] end
    return a < b
  end)
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
  Render.svg(H, big, SNAP .. "/cartes_warrior.svg", "cartes du Guerrier (base, améliorée)")
  big:Hide()
end

print("UK  clavier laissé au jeu : aucun cadre ne le capte, aucune touche n'agit, Échap par UISpecialFrames, aucun raccourci affiché, Maj au jeu d'une carte")
do
  local function head(t, n)
    local out = {}
    for i = 1, math.min(#t, n) do out[i] = t[i] end
    if #t > n then out[#out + 1] = ("… (%d en tout)"):format(#t) end
    return table.concat(out, "\n        ")
  end
  -- (1) sources de l'interface : aucune capture du clavier ni nom de touche (commentaires retirés)
  local srcBad = {}
  local tocF = assert(io.open("SlayTheDragon.toc", "r"))
  for line in tocF:lines() do
    local path = line:gsub("\r", ""):match("^(UI[\\/][%w_/\\]+%.lua)%s*$")
    if path then
      local f = io.open((path:gsub("\\", "/")), "r")
      if f then
        local n = 0
        for l in f:lines() do
          n = n + 1
          local code = l:gsub("%-%-.*$", "")
          for _, pat in ipairs({ "EnableKeyboard", "OnKeyDown", "OnKeyUp", "OnChar", "SetPropagateKeyboardInput",
            "OverrideBinding", "SetBinding", "IsKeyDown", "GetBindingKey", '"SPACE"', '"ENTER"', '"TAB"', '"ESCAPE"',
            "HandleKey", "keyIndex" }) do
            if code:find(pat, 1, true) then srcBad[#srcBad + 1] = path .. ":" .. n .. " " .. pat end
          end
        end
        f:close()
      end
    end
  end
  tocF:close()
  check("sources de UI/ : ni capture du clavier, ni gestion de touche, ni nom de touche", #srcBad == 0, head(srcBad, 8))

  -- touches essayées : tout ce qu'un joueur presse en vol (chat, saut, barres, déplacement, ciblage)
  local KEYS = { "SPACE", "ENTER", "TAB", "BACKSPACE", "UP", "DOWN", "LEFT", "RIGHT", "LSHIFT", "LCTRL", "LALT",
    "F1", "NUMPAD1", "-", "=", "/" }
  for d = 0, 9 do KEYS[#KEYS + 1] = tostring(d) end
  for b = string.byte("A"), string.byte("Z") do KEYS[#KEYS + 1] = string.char(b) end

  local function lower(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):lower()) end
  local WORDS = { "space", "spacebar", "enter", "return", "tab", "esc", "escape", "ctrl", "alt", "hotkey", "hotkeys",
    "shortcut", "shortcuts", "keybind", "keybinding", "keyboard", "press", "numpad" }
  -- nom de touche ou mention d'un raccourci ; « Key +N », « Keys unlocked » = clés mythiques, « Shift » permis
  local function shortcutWord(t)
    local l = " " .. lower(t) .. " "
    for _, w in ipairs(WORDS) do
      if l:find("%f[%a]" .. w .. "%f[%A]") then return w end
    end
    local rest = l:gsub("%f[%a]keys? %+", ""):gsub("%f[%a]keys unlocked", "")
    if rest:find("%f[%a]keys?%f[%A]") then return "key" end
    return nil
  end

  local seen, textBadList, nTexts, nTips = {}, {}, 0, 0
  local consumers, actions = {}, {}
  local function noteText(where, t)
    if type(t) ~= "string" or t == "" or seen[t] then return end
    seen[t] = true
    nTexts = nTexts + 1
    local w = shortcutWord(t)
    if w then textBadList[#textBadList + 1] = where .. " : « " .. t:gsub("\n", " / ") .. " » (" .. w .. ")" end
  end
  -- état observable : sauvegarde complète, écran, fenêtre, options, panneau des cartes
  local function state()
    return { db = deepcopy(_G.SlayTheDragonDB), kind = currentKind(), shown = shown() and true or false,
      opt = UI().optionsFrame and UI().optionsFrame._shown or false,
      dv = UI().deckView and UI().deckView:IsShown() or false,
      sel = V().selected, pot = V().potionSlot }
  end
  -- un écran : aucun cadre ne capte le clavier, chaque touche va au jeu sans rien changer, textes et
  -- infobulles relevés
  local function probe(where)
    H.settle()
    for _, o in ipairs(H.objects) do
      local sc = rawget(o, "_scripts")
      if rawget(o, "_keyboard") or (sc and (sc.OnKeyDown or sc.OnKeyUp or sc.OnChar)) then
        consumers[#consumers + 1] = where .. " : " .. tostring(rawget(o, "_name") or rawget(o, "_kind"))
      end
    end
    for _, k in ipairs(KEYS) do
      local before = state()
      local toGame = H.key(k)
      H.advance(0.3)
      local after = state()
      local same, why = deepeq(before, after)
      if not toGame or not same then
        actions[#actions + 1] = where .. " : " .. k .. (toGame and "" or " (non rendue au jeu)") .. (same and "" or " — " .. tostring(why))
      end
    end
    for _, o in ipairs(H.objects) do
      if rawget(o, "_kind") == "FontString" and o:IsVisible() then noteText(where, rawget(o, "_text")) end
    end
    for _, o in ipairs(H.objects) do
      local sc = rawget(o, "_scripts")
      if sc and sc.OnEnter and o:IsVisible() then
        for _, line in ipairs(H.hover(o)) do
          nTips = nTips + 1
          noteText(where .. " (infobulle)", type(line) == "table" and line[1] or line)
        end
      end
    end
  end

  -- accueil, options, parcours, panneau des cartes, combat, feu de camp, marchand, rencontre, bilan, méta
  H.boot(nil)
  H.slash("")
  probe("accueil")
  UI().toggleOptions()
  probe("options")
  H.click(UI().optionsClose)
  local exp = freshRun(SEED)
  probe("parcours")
  H.click(UI().deckButton)
  probe("panneau du deck")
  H.click(UI().deckView.close)
  exp = freshRun(SEED, "combat")
  probe("combat")
  local v = V()
  H.click(v.cards[1])
  probe("combat, carte choisie")
  H.click(v.cards[1], "RightButton")
  exp = freshRun(SEED + 3, "campfire")
  probe("feu de camp")
  exp = freshRun(SEED + 2, "merchant")
  probe("marchand")
  exp = freshRun(SEED + 4, "event")
  probe("rencontre")
  UI().toggleOptions()
  H.click(UI().abandonButton)
  H.click(UI().abandonButton)
  probe("bilan")
  clickOption("ui:progress")
  probe("progression")
  clickOption("ui:meta")
  probe("méta")
  check("aucun cadre de l'addon ne capte le clavier (EnableKeyboard, OnKeyDown, OnKeyUp, OnChar), sur tous les écrans",
    #consumers == 0, head(consumers, 8))
  check(("aucune des %d touches ne déclenche d'action ni n'est retenue (écran, sauvegarde, sélection, panneaux), sur 11 vues")
    :format(#KEYS), #actions == 0, head(actions, 8))
  check(("aucun texte affiché ni infobulle ne mentionne une touche ou un raccourci (%d textes, %d lignes d'infobulle)")
    :format(nTexts, nTips), nTexts > 100 and nTips > 20 and #textBadList == 0, head(textBadList, 8))
  check("le détecteur de mentions voit bien « Space: end turn » et « (Enter) », pas « Key +2 » ni « Shift: »",
    shortcutWord("Space: end turn") and shortcutWord("Continue (Enter)") and shortcutWord("Press 1")
    and not shortcutWord("Key +2") and not shortcutWord("Keys unlocked: +0 to +3")
    and not shortcutWord(H.ns.Widgets.SPEND_HINT))

  -- (2) Échap : rendu au jeu, qui ferme la fenêtre par UISpecialFrames (options et panneau avec elle)
  exp = freshRun(SEED, "combat")
  UI().toggleOptions()
  UI().toggleDeckView("deck")
  check("Échap : options et panneau des cartes ouverts avant", UI().optionsFrame._shown and UI().deckView:IsShown())
  local listed = false
  for _, n in pairs(_G.UISpecialFrames) do if n == "SlayTheDragonFrame" and _G[n] == UI().frame then listed = true end end
  check("UISpecialFrames nomme la fenêtre de l'addon", listed)
  local hand = #C().combat().hand
  local toGame = H.key("ESCAPE")
  check("Échap va au jeu et ferme la fenêtre par UISpecialFrames, options et panneau compris",
    toGame and not shown() and not UI().optionsFrame._shown and not UI().deckView:IsShown(), toGame)
  check("Échap ne joue rien", #C().combat().hand == hand and currentKind() == "combat")
  H.slash("")
  check("rouverte par /slay : même combat, rien d'ouvert par-dessus", shown() and currentKind() == "combat"
    and not UI().optionsFrame._shown and not UI().deckView:IsShown())

  -- (3) Maj tenue au jeu d'une carte « Spend N » : jouée sans dépenser (modificateur lu au clic)
  H.boot(nil)
  H.slash("")
  clickOption("class:warrior")
  H.ns.Controller.makeSeed = function() return SEED end
  clickOption("go")
  exp = EXP()
  local id = exp.map.start[1]
  exp.map.nodes[id].kind = "combat"
  clickOption("path:" .. id)
  H.settle()
  v = V()
  local c = C().combat()
  local ctl = H.ns.Controller
  local got = {}
  local play0 = ctl.play
  ctl.play = function(i, t, nospend) got[#got + 1] = nospend and true or false return play0(i, t, nospend) end
  local function heroic()
    c.hand[1] = { uid = 990000 + #got, id = "heroic_strike" }
    c.player.res = 3 -- sous le plafond : un gain éventuel de l'attaque reste visible
    c.player.mana = 3
    v:Render(true)
    H.settle()
    return v.cards[1]
  end
  local target = C().aliveTargets()[1]
  H.shift = true
  local card = heroic()
  local keyToGame = H.key("LSHIFT")
  H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
  H.click(card)
  H.click(enemySlot(target))
  H.shift = false
  H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
  H.settle()
  local resShift = c.player.res
  check("Maj tenue : la touche va au jeu, la carte Spend se joue sans dépenser",
    keyToGame and got[1] == true and resShift >= 3, tostring(got[1]) .. " / " .. tostring(resShift))
  card = heroic()
  H.click(card)
  H.click(enemySlot(target))
  H.settle()
  check("sans Maj : la même carte dépense (2 Rage de moins qu'avec Maj)", got[2] == false
    and c.player.res == resShift - 2, tostring(got[2]) .. " / " .. tostring(c.player.res) .. " / " .. resShift)
  ctl.play = play0
  local zone = false
  for _, o in ipairs(H.listeners.MODIFIER_STATE_CHANGED or {}) do if o == v.classZone then zone = true end end
  check("MODIFIER_STATE_CHANGED écouté (ligne « Spend N: » redessinée), sans capter le clavier", zone
    and not rawget(v.classZone, "_keyboard"))
end

print("UR  Rogue : accueil, combat (Combo, Parry et Stealth sous le héros, modèle caché), planche des cartes")
do
  H.boot(nil)
  H.slash("")
  local ns = H.ns
  local W = ns.Widgets
  local rb = button("class:rogue")
  check("accueil : bouton du Voleur visible", rb and rb._shown, rb and rb._shown)
  clickOption("class:rogue")
  check("accueil : clic sur le Voleur, il devient le choix", option("class:rogue").selected
    and not option("class:priest").selected)
  H.ns.Controller.makeSeed = function() return SEED end
  clickOption("go")
  local e = EXP()
  check("départ : expédition du Voleur (classe, deck, Thieves' Tools)", e and e.class == "rogue"
    and ns.Cards[e.deck[1].id].class == "rogue" and e.relics[1] == "thieves_tools")
  check("bandeau : nom de la classe", UI().className._text == "Rogue", UI().className._text)
  local id = e.map.start[1]
  e.map.nodes[id].kind = "combat"
  clickOption("path:" .. id)
  H.settle()
  local v = V()
  local c = e.combat
  check("combat du Voleur : classe, Stealth posé, 6 cartes au premier tour (Thieves' Tools)",
    c and c.class == "rogue" and c.player.st.stealth == 1 and #c.hand == 6, c and #c.hand)
  v:Render(true)
  check("cadre du héros : nom et portrait du Voleur", v.heroFrame.name._text == "Rogue"
    and (v.heroFrame.portrait._texture or ""):lower():find("classicon_rogue", 1, true), tostring(v.heroFrame.portrait._texture))
  -- états sous le héros : Stealth (sans nombre) et Parry (avec ses charges), explication au survol
  ns.Combat.applyStatus(c, c.player, "parry", 2)
  ns.Combat.gainRes(c, 3)
  v:Render(true)
  local tok = {}
  for _, t in ipairs(v.playerSt.tokens) do
    if t._shown and t.info and t.info.status then tok[t.info.status] = t end
  end
  local st, pa = tok.stealth, tok.parry
  check("jeton Stealth : présent, icône, sans nombre", st and (st.medal.icon._texture or ""):lower():find("ability_stealth", 1, true)
    and (st.count._text or "") == "", st and tostring(st.count._text))
  check("jeton Parry : présent, icône, nombre de charges", pa and (pa.medal.icon._texture or ""):lower():find("ability_parry", 1, true)
    and pa.count._text == "2", pa and tostring(pa.count._text))
  local ts = st and table.concat(H.hover(st), " | ") or ""
  local tp = pa and table.concat(H.hover(pa), " | ") or ""
  check("survol de Stealth : nom sans nombre et explication", ts:find("Stealth", 1, true) and not ts:find("Stealth 1", 1, true)
    and ts:find("Attack", 1, true), ts)
  check("survol de Parry : nom, charges et explication", tp:find("Parry 2", 1, true) and tp:find("8 damage", 1, true), tp)
  local r = v.resource
  check("pastille de ressource : icône des Combo, nombre",
    r._shown and (r.icon._texture or ""):lower():find("inv_throwingknife_04", 1, true) and r.text._text == "3",
    tostring(r.icon._texture) .. " / " .. tostring(r.text._text))
  local tt = table.concat(H.hover(r), " | ")
  check("pastille de ressource : explication des Combo et plafond", tt:find("Combo", 1, true) and tt:find("3 / 5", 1, true), tt)
  local m = v.playerModel
  local function alpha() local k = m and m._calls and m._calls.SetModelAlpha return k and k[1] end
  check("modèle du héros en semi-transparence sous Stealth", alpha() and alpha() < 1, alpha())
  snap("combat-rogue", true)
  -- première Attack jouée par l'interface : Stealth consommé, le jeton disparaît, le modèle redevient opaque
  local hi
  for i, inst in ipairs(c.hand) do if ns.Cards[inst.id].type == "attack" and ns.Combat.canPlay(c, i) then hi = i break end end
  if hi then
    H.ns.Controller.act({ "play", hi, 1 })
    H.settle()
    v:Render(true)
    local still = false
    for _, t in ipairs(v.playerSt.tokens) do if t._shown and t.info and t.info.status == "stealth" then still = true end end
    check("Attack jouée : Stealth consommé, jeton retiré, modèle opaque", c.player.st.stealth == nil and not still and alpha() == 1, alpha())
  end
  -- carte Surge à 0 point : raison au pluriel
  check("raison d'une carte Surge à 0 : « Not enough Combo. »",
    ns.Controller.reasonText("resource") == "Not enough Combo.", ns.Controller.reasonText("resource"))
  -- infobulle d'une carte : Stealth, Parry, condition Stealth et Combo expliqués
  local tip = { lines = {} }
  function tip:AddLine(t) self.lines[#self.lines + 1] = t end
  function tip:NumLines() return #self.lines end
  W.fillCardTooltip(tip, "backstab", false)
  W.fillCardTooltip(tip, "shadowstep", false)
  local all = table.concat(tip.lines, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  check("infobulles des cartes : Stealth (condition et état), Parry, Combo",
    all:find("Stealth: bonus effect", 1, true) and all:find("Stealth: the next Attack", 1, true)
    and all:find("Parry: each charge", 1, true) and all:find("Combo", 1, true), all)
end

-- planche des cartes du Voleur (base et améliorée)
if SNAP then
  local ns = H.ns
  local W = ns.Widgets
  local ids = {}
  for id, d in pairs(ns.Cards) do if d.class == "rogue" then ids[#ids + 1] = id end end
  local RANK = { basic = 0, common = 1, uncommon = 2, rare = 3 }
  local PATH = { start = 0, assassination = 1, combat = 2, subtlety = 3 }
  table.sort(ids, function(a, b)
    local da, db = ns.Cards[a], ns.Cards[b]
    if PATH[da.path] ~= PATH[db.path] then return PATH[da.path] < PATH[db.path] end
    if RANK[da.rarity] ~= RANK[db.rarity] then return RANK[da.rarity] < RANK[db.rarity] end
    return a < b
  end)
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
  Render.svg(H, big, SNAP .. "/cartes_rogue.svg", "cartes du Voleur (base, améliorée)")
  big:Hide()
end

print("UM  Mage : textes des cartes dans la zone, accueil, combat (pastille d'Charges, portrait, Instant, deuxième incantation)")
do
  H.boot(nil)
  H.slash("")
  local ns = H.ns
  local W, Art = ns.Widgets, ns.Art
  -- textes : les 34 cartes du Mage (base et améliorée) tiennent dans le panneau, une clause par ligne
  local card = W.card(UI().content)
  local ids, bad, minSize = {}, {}, 99
  for id, d in pairs(ns.Cards) do if d.class == "mage" then ids[#ids + 1] = id end end
  table.sort(ids)
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      card:SetCard(id, up, { playable = true })
      local fit = card.bodyFit
      if not (fit and fit.ok and not fit.under and fit.mode == "clauses") then
        bad[#bad + 1] = id .. (up and "+" or "") .. " : " .. tostring(fit and fit.mode) .. " " .. tostring(fit and fit.size)
      else
        minSize = math.min(minSize, fit.size)
      end
      if not Art.cards[id] or not Art.cards[id].tga or not ns.Skin.icons[Art.cards[id].tga:lower()] then
        bad[#bad + 1] = id .. " : icône absente de Media/Icons"
      end
    end
  end
  card:Hide()
  check(("textes : %d cartes du Mage (base et améliorée) dans le panneau, une clause par ligne (taille mini %.1f), icônes embarquées")
    :format(#ids, minSize), #ids == 34 and #bad == 0, table.concat(bad, ", "))
  local rbad = {}
  for id, r in pairs(ns.Relics) do
    if r.class == "mage" and not (Art.relics[id] and ns.Skin.icons[Art.relics[id].tga:lower()]) then rbad[#rbad + 1] = id end
  end
  check("bibelots du Mage : icônes embarquées", #rbad == 0, table.concat(rbad, ", "))
  -- accueil : le Mage proposé après le Priest et le Warrior, choisissable
  local cls = {}
  for _, o in ipairs(UI().step.options) do if o.group == "class" then cls[#cls + 1] = o.id end end
  local pos
  for i, id in ipairs(cls) do if id == "class:mage" then pos = i end end
  check("accueil : Mage proposé après le Priest et le Warrior", pos ~= nil and pos > 2, table.concat(cls, ","))
  local mb = button("class:mage")
  local mtt = table.concat(H.hover(mb), " | ")
  check("accueil : icône du Mage, infobulle (PV, cartes)", mb and mb._shown
    and mtt:find(ns.Classes.mage.hp .. " HP, 10 cards", 1, true), mtt)
  clickOption("class:mage")
  check("accueil : clic sur le Mage, il devient le choix", option("class:mage").selected and not option("class:priest").selected)
  snap("accueil-mage", true)
  H.ns.Controller.makeSeed = function() return SEED end
  clickOption("go")
  local e = EXP()
  check("départ : expédition du Mage (classe, deck, Apprentice's Wand)", e and e.class == "mage"
    and ns.Cards[e.deck[1].id].class == "mage" and e.relics[1] == "apprentice_wand")
  check("bandeau : nom de la classe", UI().className._text == "Mage", UI().className._text)
  local id = e.map.start[1]
  e.map.nodes[id].kind = "combat"
  clickOption("path:" .. id)
  H.settle()
  local v = V()
  local c = e.combat
  check("combat du Mage : classe du combat, 0 charge au départ", c and c.class == "mage" and c.player.res == 0)
  v:Render(true)
  check("pastille de ressource cachée à 0 charge", not v.resource._shown)
  c.player.res = 2
  v:Render(true)
  local r = v.resource
  check("pastille de ressource : icône des Charges, nombre, visible",
    r._shown and (r.icon._texture or ""):lower():find("spell_arcane_arcane01", 1, true) and r.text._text == "2",
    tostring(r.icon._texture) .. " / " .. tostring(r.text._text))
  local tt = table.concat(H.hover(r), " | ")
  check("pastille de ressource : explication des Charges et plafond 4", tt:find("Charge", 1, true) and tt:find("2 / 4", 1, true), tt)
  check("cadre du héros : nom et portrait = icône du Mage",
    v.heroFrame.name._text == "Mage" and (v.heroFrame.portrait._texture or ""):lower():find("classicon_mage", 1, true),
    tostring(v.heroFrame.portrait._texture))
  local allM = #c.hand > 0
  for _, inst in ipairs(c.hand) do if ns.Cards[inst.id].class ~= "mage" then allM = false end end
  check("main du Mage : ses cartes", allM)
  -- chiffre flottant au nom de la ressource (singulier / pluriel)
  local floats = {}
  local old = W.float
  W.float = function(parent, x, y, text, ...) floats[#floats + 1] = text return old(parent, x, y, text, ...) end
  v:OnEvents({ { t = "resource", n = 1, total = 3 }, { t = "resource", n = 2, total = 4 } })
  H.advance(2)
  W.float = old
  local fl = table.concat(floats, "|")
  check("chiffres flottants : « +1 Charge » et « +2 Charges »", fl:find("+1 Charge", 1, true)
    and fl:find("+2 Charges", 1, true), fl)
  -- Instant : jeton sous le héros avec son nombre
  ns.Combat.applyStatus(c, c.player, "instant", 2)
  v:Render(true)
  local tok
  for _, t in ipairs(v.playerSt.tokens) do if t._shown and t.info and t.info.status == "instant" then tok = t end end
  check("jeton Instant sous le héros (nombre 2)", tok ~= nil and tok.info.n == 2)
  -- deux incantations : la barre commune montre la plus ancienne, la vue du Mage la plus récente
  c.player.st.instant = nil
  c.player.mana = 9
  c.hand[#c.hand + 1] = ns.Card.new("fireball", false, 9101)
  c.hand[#c.hand + 1] = ns.Card.new("pyroblast", false, 9102)
  ns.Combat.play(c, #c.hand - 1, 1)
  ns.Combat.play(c, #c.hand, 1)
  v:Render(true)
  local host = v.classZone.views.mage
  check("deux incantations : barre commune = Fireball, vue du Mage = « 2nd cast: Pyroblast »",
    v.cast._shown and (v.cast.name._text or ""):find("Fireball", 1, true) and host and host._shown
      and host.name._shown and host.name._text == "2nd cast: Pyroblast",
    tostring(v.cast.name._text) .. " / " .. tostring(host and host.name._text))
  local ctt = table.concat(H.hover(host.box), " | ")
  check("infobulle de la deuxième incantation : carte et interruption", ctt:find("Pyroblast", 1, true)
    and ctt:find("interrupt cancels this cast first", 1, true), ctt)
  -- Hot Streak en jeu : compte Fire du tour
  c.player.powers[#c.player.powers + 1] = ns.Card.new("hot_streak", false, 9103)
  v:Render(true)
  check("Hot Streak en jeu : « Fire 2/2 » dans la vue du Mage", host.fire._shown and host.fire._text == "Fire 2/2", host.fire._text)
  snap("combat-mage", true)
  -- carte Cast injouable avec deux incantations : raison du moteur
  c.hand[#c.hand + 1] = ns.Card.new("blizzard", false, 9104)
  local ok, why = ns.Combat.canPlay(c, #c.hand)
  check("troisième carte Cast : injouable (raison « casting »)", not ok and why == "casting", why)
end

-- planche des cartes du Mage (base et améliorée)
if SNAP then
  local ns = H.ns
  local W = ns.Widgets
  local ids = {}
  for id, d in pairs(ns.Cards) do if d.class == "mage" then ids[#ids + 1] = id end end
  local RANK = { basic = 0, common = 1, uncommon = 2, rare = 3 }
  local PATH = { start = 0, fire = 1, frost = 2, arcane = 3 }
  table.sort(ids, function(a, b)
    local da, db = ns.Cards[a], ns.Cards[b]
    if PATH[da.path] ~= PATH[db.path] then return PATH[da.path] < PATH[db.path] end
    if RANK[da.rarity] ~= RANK[db.rarity] then return RANK[da.rarity] < RANK[db.rarity] end
    return a < b
  end)
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
  Render.svg(H, big, SNAP .. "/cartes_mage.svg", "cartes du Mage (base, améliorée)")
  big:Hide()
end

print("UH  Hunter : choix sur l'accueil, combat (familier dans la scène, cible, Traps posées, pastille de Frenzy), dessus des modèles")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local function under(o, top)
    while o do if o == top then return true end o = rawget(o, "_parent") end
    return false
  end
  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function above(o, t) return R.drawnBefore(R.drawKey(t), R.drawKey(o)) end
  local function inter(a, b) return a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5 end
  local function isRegion(o)
    local k = rawget(o, "_kind")
    if k == "Texture" then return rawget(o, "_texture") ~= nil or (o._calls.SetColorTexture ~= nil) end
    if k == "FontString" then return (rawget(o, "_text") or "") ~= "" end
    return false
  end
  H.boot(nil)
  H.slash("")
  local ns = H.ns
  -- accueil : le Hunter est proposé (ordre 5, après le Guerrier), choisissable
  local ids = {}
  for _, o in ipairs(UI().step.options) do if o.group == "class" then ids[#ids + 1] = o.id end end
  local joined = table.concat(ids, ",")
  check("accueil : Hunter proposé après Priest et Warrior", joined:find("^class:priest,class:warrior") ~= nil
    and joined:find("class:hunter", 1, true) ~= nil, joined)
  local hb = button("class:hunter")
  local htt = table.concat(H.hover(hb), " | ")
  check("accueil : icône du Hunter visible, nom dans l'infobulle", hb and hb._shown and htt:find("Hunter", 1, true) ~= nil, htt)
  clickOption("class:hunter")
  check("accueil : clic sur le Hunter, il devient le choix", option("class:hunter").selected and not option("class:priest").selected)
  snap("accueil-hunter", true)
  H.ns.Controller.makeSeed = function() return SEED end
  clickOption("go")
  local e = EXP()
  check("départ : expédition du Hunter (classe, deck, Pet Whistle)", e and e.class == "hunter"
    and ns.Cards[e.deck[1].id].class == "hunter" and e.relics[1] == "pet_whistle")
  local id = e.map.start[1]
  e.map.nodes[id].kind = "combat"
  clickOption("path:" .. id)
  H.settle()
  local v = V()
  local c = e.combat
  check("combat du Hunter : Pet Whistle, le familier a déjà frappé (Frenzy 1)", c and c.class == "hunter" and c.player.res == 1)
  -- une Trap posée par l'interface (Freezing Trap mise en main)
  c.hand[1] = ns.Card.new("freezing_trap", false, 9001)
  c.player.mana = 3
  v:Render(true)
  H.ns.Controller.act({ "play", 1 })
  H.settle()
  v:Render(true)
  local host = v.classZone.views.hunter
  check("vue de classe construite (familier, marqueur, cases de Traps)", host and host._shown and host.pet and host.mark and #host.traps == 3)
  local pet = host.pet
  check("familier dans la scène : figure visible (modèle ou médaillon), nom au-dessus sur l'étage f.ui",
    vis(pet) and (vis(pet.model) or vis(pet.fallback)) and pet.name and pet.name._text == ns.Art.pet.name
    and under(pet.name, pet.ui))
  check("Trap posée : une case visible, icône de la carte, infobulle = la carte", #c.traps == 1 and vis(host.traps[1])
    and not vis(host.traps[2]) and (host.traps[1].icon._texture or ""):lower():find("chainsofice", 1, true) ~= nil,
    tostring(host.traps[1].icon._texture))
  local tt = table.concat(H.hover(host.traps[1]), " | ")
  check("infobulle de la Trap : nom, texte, déclenchement", tt:find("Freezing Trap", 1, true) and tt:find("Stunned", 1, true)
    and tt:find("next enemy attack", 1, true), tt)
  local tp = table.concat(H.hover(pet), " | ")
  check("infobulle du familier : cible et dégâts, explication du Frenzy", tp:find("Attacks ", 1, true) and tp:find("Frenzy", 1, true), tp)
  local tgt = ns.Hunter.petTarget(c)
  local s = tgt and v.slotOf[tgt.uid]
  check("marqueur de la cible du familier : visible, collé au cadre de l'ennemi visé", vis(host.mark) and s
    and host.mark._points[1] and host.mark._points[1][2] == s.tag)
  -- pastille de ressource : Frenzy
  local r = v.resource
  check("pastille de ressource : icône du Frenzy, nombre, visible", r._shown
    and (r.icon._texture or ""):lower():find("ferociousinspiration", 1, true) ~= nil and r.text._text == tostring(c.player.res),
    tostring(r.icon._texture) .. " / " .. tostring(r.text._text))
  local tr = table.concat(H.hover(r), " | ")
  check("pastille de ressource : explication du Frenzy et plafond", tr:find("Frenzy", 1, true) and tr:find(" / 5", 1, true), tr)
  -- dessus des modèles : étage du familier, cases de Traps, marqueur ; aucun texte recouvert
  local ms = {}
  for _, o in ipairs(H.objects) do
    if rawget(o, "_kind") == "PlayerModel" and under(o, ns.UI.content) and vis(o) then ms[#ms + 1] = o end
  end
  local bad, n = {}, 0
  for _, root2 in ipairs({ pet.ui, host.traps[1], host.mark }) do
    for _, o in ipairs(H.objects) do
      if isRegion(o) and (o == root2 or under(o, root2)) and vis(o) then
        n = n + 1
        for _, m in ipairs(ms) do
          if not above(o, m) then bad[#bad + 1] = tostring(rawget(o, "_text") or rawget(o, "_texture") or "?") break end
        end
      end
    end
  end
  check(("familier (nom), Trap et marqueur : %d éléments au-dessus des %d modèles 3D"):format(n, #ms),
    n > 0 and #ms >= 2 and #bad == 0, table.concat(bad, ", "))
  local hidden = {}
  for _, o in ipairs(H.objects) do
    if rawget(o, "_kind") == "FontString" and isRegion(o) and under(o, ns.UI.content) and vis(o) then
      local rr = R.rect(o)
      for _, m in ipairs(ms) do
        local mr = R.rect(m)
        if rr and mr and inter(rr, mr) and not above(o, m) then hidden[#hidden + 1] = tostring(o._text) break end
      end
    end
  end
  check("combat du Hunter : aucun texte visible recouvert par un modèle", #hidden == 0, table.concat(hidden, ", "))
  local sh = {}
  for i, part in ipairs(pet.shadow.parts) do
    if vis(part) and vis(pet.model) and not above(pet.model, part) then sh[#sh + 1] = i end
  end
  local nr, mr = R.rect(pet.name), R.rect(pet.model)
  check("familier : ombre sous le modèle, nom hors du rectangle du modèle", #sh == 0 and nr and mr and not inter(nr, mr))
  -- dans la scène : familier et cases de Traps dans la bande du décor, sans chevaucher les ennemis
  local content = R.rect(ns.UI.content)
  local inside = true
  for _, o in ipairs({ pet, host.traps[1], host.traps[3], pet.name }) do
    local rr = R.rect(o)
    if not rr or rr[1] < content[1] or rr[3] > content[3] or rr[2] < content[2] or rr[4] > content[4] then inside = false end
  end
  local clash = {}
  local pr = R.rect(pet)
  for _, sl in pairs(v.slotOf) do
    if sl:IsVisible() and inter(pr, R.rect(sl.fig.model)) then clash[#clash + 1] = tostring(sl.name._text) end
  end
  check("familier et Traps dans la fenêtre, le familier ne chevauche aucun ennemi", inside and #clash == 0, table.concat(clash, ", "))
  snap("combat-hunter", true)
  -- attaque du familier : bond dans la file d'animations, chiffre flottant de dégâts sur la cible
  local floats = {}
  local W = ns.Widgets
  local old = W.float
  W.float = function(parent, x, y, text, ...) floats[#floats + 1] = text return old(parent, x, y, text, ...) end
  local tw = 0
  local oldTween = W.tween
  W.tween = function(dur, fn, done, owner, key, ...) if owner == pet and key == "leap" then tw = tw + 1 end
    return oldTween(dur, fn, done, owner, key, ...) end
  local uid = tgt and tgt.uid
  v:OnEvents({ { t = "pet_attack", dst = uid, dmg = 4, why = "auto" },
    { t = "damage", src = "player", dst = uid, amount = 4, absorbed = 0, loss = 4 } })
  H.advance(2)
  W.float, W.tween = old, oldTween
  check("attaque du familier : bond vers la cible et « -4 » flottant", tw == 1 and table.concat(floats, "|"):find("-4", 1, true) ~= nil,
    tw .. " / " .. table.concat(floats, "|"))
  -- fin du tour par l'interface : le familier frappe, le combat continue sans erreur
  local hpBefore = tgt and tgt.hp
  H.ns.Controller.act({ "endTurn" })
  H.settle()
  check("fin du tour : le familier a frappé sa cible", c.result or (tgt and (tgt.hp < hpBefore or tgt.dead)), tostring(hpBefore))
  -- un combat d'une autre classe : la vue du Hunter et son familier disparaissent
  H.boot(nil)
  H.slash("")
  clickOption("go")
  local e2 = EXP()
  local id2 = e2.map.start[1]
  e2.map.nodes[id2].kind = "combat"
  clickOption("path:" .. id2)
  H.settle()
  local v2 = V()
  local h2 = v2.classZone.views.hunter
  check("combat d'une autre classe (Priest) : pas de familier", e2.class ~= "hunter" and (h2 == nil or not vis(h2.pet)))
end

-- planche des cartes du Hunter (base et améliorée)
if SNAP then
  local ns = H.ns
  local W = ns.Widgets
  local ids = {}
  for id, d in pairs(ns.Cards) do if d.class == "hunter" then ids[#ids + 1] = id end end
  local RANK = { basic = 0, common = 1, uncommon = 2, rare = 3 }
  local PATH = { start = 0, beast_mastery = 1, marksmanship = 2, survival = 3 }
  table.sort(ids, function(a, b)
    local da, db = ns.Cards[a], ns.Cards[b]
    if PATH[da.path] ~= PATH[db.path] then return PATH[da.path] < PATH[db.path] end
    if RANK[da.rarity] ~= RANK[db.rarity] then return RANK[da.rarity] < RANK[db.rarity] end
    return a < b
  end)
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
  Render.svg(H, big, SNAP .. "/cartes_hunter.svg", "cartes du Hunter (base, améliorée)")
  big:Hide()
end

print("UB  pièces en tranches : une texture découpée par le client, repli bord à bord à toute échelle, gardes de l'atlas")
do
  freshRun(SEED, "combat")
  H.settle()
  local ns = H.ns
  local W, WS = ns.Widgets, ns.WowSkin
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local frame = _G.SlayTheDragonFrame
  local Wd = W
  local function step(dt) run(Wd.driver, "OnUpdate", dt) H.now = H.now + dt end
  local function settleHover() for _ = 1, 40 do step(0.02) end H.now = H.now + 1 end

  -- 1. pièces en trois tranches : bouts dans la pièce (2 × bout < largeur), hauteur entière
  local badCap = {}
  for name, e in pairs(WS.pieces) do
    if e.cap and not (e.cap > 0 and 2 * e.cap < e.pw) then badCap[#badCap + 1] = name end
  end
  check("pièces en trois tranches : bouts à l'intérieur de la pièce", #badCap == 0, table.concat(badCap, ", "))

  -- 2. gardes de l'atlas : autour de chaque pièce, au moins 2 pixels qui répètent son bord (alpha et
  -- couleur visible) et n'appartiennent à aucune autre pièce : le filtrage (bilinéaire, mipmaps du
  -- trilinéaire jusqu'au demi) aux bords d'une pièce ou d'une tranche ne lit jamais une voisine. (Avant le
  -- 12/11/2026, les gardes gauche et droite étaient noires sous l'alpha du bord : liseré sombre possible.)
  local GUARD = 2
  local f = assert(io.open(root .. "/Media/WowUI/atlas.tga", "rb"))
  local img = f:read("*a")
  f:close()
  local AW, AH = img:byte(13) + 256 * img:byte(14), img:byte(15) + 256 * img:byte(16)
  local function px(x, y)
    local i = 18 + ((AH - 1 - y) * AW + x) * 4
    return img:byte(i + 3), img:byte(i + 2), img:byte(i + 1), img:byte(i + 4) -- r, g, b, a (TGA : BGRA)
  end
  local rects = {}
  for name, e in pairs(WS.pieces) do
    if e.file == "atlas.tga" then
      local x0, y0 = math.floor(e.tc[1] * e.w + 0.5), math.floor(e.tc[3] * e.h + 0.5)
      rects[name] = { x0, y0, x0 + e.pw, y0 + e.ph }
    end
  end
  local guardBad, nPieces = {}, 0
  for name, r in pairs(rects) do
    nPieces = nPieces + 1
    local g = { r[1] - GUARD, r[2] - GUARD, r[3] + GUARD, r[4] + GUARD }
    if g[1] < 0 or g[2] < 0 or g[3] > AW or g[4] > AH then guardBad[#guardBad + 1] = name .. " (bord de la toile)" end
    for other, o in pairs(rects) do
      if other ~= name and o[1] < g[3] and o[3] > g[1] and o[2] < g[4] and o[4] > g[2] then
        guardBad[#guardBad + 1] = name .. " touche " .. other
      end
    end
    -- anneau de garde = bord répété
    local wrong = 0
    for y = math.max(0, g[2]), math.min(AH, g[4]) - 1 do
      for x = math.max(0, g[1]), math.min(AW, g[3]) - 1 do
        if x < r[1] or x >= r[3] or y < r[2] or y >= r[4] then
          local ex = math.min(math.max(x, r[1]), r[3] - 1)
          local ey = math.min(math.max(y, r[2]), r[4] - 1)
          local r1, g1, b1, a1 = px(x, y)
          local r2, g2, b2, a2 = px(ex, ey)
          -- couleur comparée prémultipliée (écart ≤ 2 sur 255 : rééchantillonnage des pixels presque transparents)
          local k = a2 / 255
          if a1 ~= a2 or math.abs(r1 - r2) * k > 2 or math.abs(g1 - g2) * k > 2 or math.abs(b1 - b2) * k > 2 then
            wrong = wrong + 1
          end
        end
      end
    end
    if wrong > 0 then guardBad[#guardBad + 1] = name .. " : " .. wrong .. " pixels de garde différents du bord" end
  end
  table.sort(guardBad)
  check(("atlas : %d pièces entourées de %d pixels de garde (bord répété, aucune voisine)"):format(nPieces, GUARD),
    nPieces > 30 and #guardBad == 0, table.concat(guardBad, ", "))

  -- 3. client avec la découpe (WoW Forever) : chaque composition en tranches est UNE texture découpée,
  -- sans jointure ; pièce entière (coordonnées de la pièce), marges dans la pièce, bouts à l'échelle de
  -- la hauteur, texture qui couvre exactement son hôte ; vérifié sur les écrans parcourus
  local function slicedIn(top)
    local out = {}
    local function walk(o)
      for _, k in ipairs(rawget(o, "_kids") or {}) do
        if rawget(k, "_kind") == "Texture" and k._calls.SetTextureSliceMargins then out[#out + 1] = k end
        walk(k)
      end
    end
    walk(top)
    return out
  end
  local function groups()
    local out = {}
    for _, o in ipairs(H.objects) do
      for _, key in ipairs({ "base", "hot", "nine", "plate" }) do
        local g = rawget(o, key)
        if type(g) == "table" and rawget(g, "parts") and (rawget(g, "Layout") or rawget(g, "margins")) then
          out[#out + 1] = { g = g, owner = o, key = key }
        end
      end
      local tag = rawget(o, "tag")
      if type(tag) == "table" and type(rawget(tag, "plain")) == "table" then out[#out + 1] = { g = tag.plain, owner = o, key = "tag" } end
    end
    return out
  end
  local apiBad, nGroups, nTex = {}, 0, 0
  local function apiCheck(where)
    for _, it in ipairs(groups()) do
      local g = it.g
      local t = g.parts[1]
      if t and t:IsVisible() then
        nGroups = nGroups + 1
        local label = where .. " " .. it.key .. " " .. tostring(rawget(t, "_wow") or rawget(t, "_texture"))
        local sm = t._calls.SetTextureSliceMargins
        if not g.sliced or #g.parts ~= 1 or not sm then
          apiBad[#apiBad + 1] = label .. " : pas d'un seul tenant"
        else
          local e = rawget(t, "_wow") and WS.pieces[t._wow]
          local tc = t._calls.SetTexCoord
          if e then
            if not tc or math.abs(tc[1] - e.tc[1]) > 1e-9 or math.abs(tc[2] - e.tc[2]) > 1e-9
              or math.abs(tc[3] - e.tc[3]) > 1e-9 or math.abs(tc[4] - e.tc[4]) > 1e-9 then
              apiBad[#apiBad + 1] = label .. " : coordonnées hors de la pièce"
            end
            if sm[1] + sm[3] >= e.pw or sm[2] + sm[4] >= e.ph then apiBad[#apiBad + 1] = label .. " : marges plus grandes que la pièce" end
            if g.cap and math.abs(sm[1] * t._scale - g.cap) > 1e-9 then apiBad[#apiBad + 1] = label .. " : bout ≠ hauteur × bout / hauteur de la pièce" end
          end
          local host = g.host or (g.anchor)
          if g.anchor then host = g.anchor end
          local rt, rh = R.rect(t), host and R.rect(host)
          if not rt or not rh or math.abs(rt[1] - rh[1]) > 1e-6 or math.abs(rt[3] - rh[3]) > 1e-6
            or math.abs(rt[2] - rh[2]) > 1e-6 or math.abs(rt[4] - rh[4]) > 1e-6 then
            apiBad[#apiBad + 1] = label .. " : texture qui ne couvre pas son hôte"
          end
          -- les bouts ne se chevauchent pas (hôte assez large pour deux bouts)
          local s, p = 1, t
          while p do s = s * (rawget(p, "_scale") or 1) p = rawget(p, "_parent") end
          if rt and (sm[1] + sm[3]) * s > (rt[3] - rt[1]) + 1e-6 then apiBad[#apiBad + 1] = label .. " : bouts qui se chevauchent" end
        end
      end
    end
    nTex = nTex + #slicedIn(frame)
  end
  apiCheck("combat")
  for _, sc in ipairs({ { SEED + 4, "event", "rencontre" }, { SEED + 5, nil, "parcours" }, { SEED + 2, "merchant", "marchand" },
    { SEED + 3, "campfire", "feu de camp" } }) do
    freshRun(sc[1], sc[2])
    H.advance(1)
    apiCheck(sc[3])
  end
  H.slash("options")
  apiCheck("options")
  H.key("ESCAPE")
  check(("client avec découpe : %d compositions en tranches (boutons, liserés, plaques, parchemins, cadres d'ennemi) d'un seul tenant"):format(nGroups),
    nGroups > 20 and nTex > 20 and #apiBad == 0, table.concat(apiBad, ", "))

  -- pendant un survol (zoom net, fenêtre 0,6 à 1,5) : la texture découpée reste seule, à la même échelle
  -- propre et sur les mêmes ancres ; seul le visuel est animé
  freshRun(SEED, "combat")
  H.settle()
  local btn = V().endTurn
  local tex = btn.base.parts[1]
  local d0, pts0 = tex._scale, #tex._points
  local animBad = {}
  for _, ws in ipairs({ 0.6, 0.85, 1, 1.15, 1.5 }) do
    frame:SetScale(ws)
    run(btn, "OnEnter")
    for i = 1, 8 do
      step(0.013)
      if tex._scale ~= d0 or #tex._points ~= pts0 or #btn.base.parts ~= 1 then animBad[#animBad + 1] = ws .. "/" .. i end
    end
    run(btn, "OnLeave")
    settleHover()
  end
  frame:SetScale(1.15)
  check("survol d'un bouton découpé (fenêtre 0,6 à 1,5, images intermédiaires) : une texture, échelle propre et ancres fixes",
    #animBad == 0, table.concat(animBad, ", "))

  -- 4. client sans la découpe (repli) : tranches bord à bord, sans jour ni chevauchement, aux fenêtres
  -- 0,6 à 1,5 et à chaque image d'un survol (positions fractionnaires) ; coordonnées contiguës, dans la pièce
  H.noSlice = true
  local holder = CreateFrame("Frame", nil, frame)
  holder:SetSize(600, 200)
  holder:SetPoint("TOPLEFT", frame, "TOPLEFT", 37.3, -91.7)
  local rb = W.button(holder, "Warrior", 220, 52, nil, "red", 17)
  rb:SetPoint("TOPLEFT", holder, "TOPLEFT", 10.37, -12.41)
  local gb = W.button(holder, "Start", 231.3, 49.7, nil, "gold", 18)
  gb:SetPoint("TOPLEFT", holder, "TOPLEFT", 300.21, -15.66)
  local parch = W.parchment(holder)
  parch:SetSize(203.7, 121.3)
  parch:SetPoint("TOPLEFT", holder, "TOPLEFT", 12.2, -80.9)
  local card = W.card(holder)
  card:SetCard("strike", false, { playable = true })
  W.placeCenter(card, holder, 400.3, 140.7, 1)
  H.settle()
  local fbBad, samples = {}, 0
  local function tcOf(t) return t._calls.SetTexCoord end
  local function within(tc, e) return tc[1] >= e.tc[1] - 1e-9 and tc[2] <= e.tc[2] + 1e-9 and tc[3] >= e.tc[3] - 1e-9 and tc[4] <= e.tc[4] + 1e-9 end
  local function rowCheck(label, parts, e)
    if #parts ~= 3 then fbBad[#fbBad + 1] = label .. " : " .. #parts .. " tranches" return end
    local a, b, c = R.vrect(parts[1]), R.vrect(parts[2]), R.vrect(parts[3])
    samples = samples + 1
    if not (a and b and c) then fbBad[#fbBad + 1] = label .. " : non mesurable" return end
    local gap1, gap2 = b[1] - a[3], c[1] - b[3]
    if math.abs(gap1) > 1e-6 or math.abs(gap2) > 1e-6 or math.abs(a[2] - b[2]) > 1e-6 or math.abs(a[4] - b[4]) > 1e-6
      or math.abs(c[2] - b[2]) > 1e-6 or math.abs(c[4] - b[4]) > 1e-6 then
      fbBad[#fbBad + 1] = string.format("%s : jour %.4f / %.4f", label, gap1, gap2)
    end
    local t1, t2, t3 = tcOf(parts[1]), tcOf(parts[2]), tcOf(parts[3])
    if e and not (within(t1, e) and within(t2, e) and within(t3, e) and math.abs(t1[2] - t2[1]) < 1e-12
      and math.abs(t2[2] - t3[1]) < 1e-12 and math.abs(t1[1] - e.tc[1]) < 1e-12 and math.abs(t3[2] - e.tc[2]) < 1e-12) then
      fbBad[#fbBad + 1] = label .. " : coordonnées non contiguës ou hors de la pièce"
    end
  end
  local function sampleAll(label)
    rowCheck(label .. " bouton rouge", rb.base.parts, WS.pieces.btn_red)
    rowCheck(label .. " liseré d'or", rb.hot.parts, WS.pieces.btn_goldred)
    rowCheck(label .. " bouton rouge et or", gb.base.parts, WS.pieces.btn_goldred)
    rowCheck(label .. " plaque de carte", card.plate.parts, nil)
    local np = parch.nine.parts
    if #np ~= 9 then fbBad[#fbBad + 1] = label .. " parchemin : " .. #np .. " tranches" else
      for row = 0, 2 do rowCheck(label .. " parchemin rang " .. row, { np[row * 3 + 1], np[row * 3 + 2], np[row * 3 + 3] }, WS.pieces.parch_text) end
      for col = 1, 3 do
        local a, b, c = R.vrect(np[col]), R.vrect(np[col + 3]), R.vrect(np[col + 6])
        if math.abs(a[2] - b[4]) > 1e-6 or math.abs(b[2] - c[4]) > 1e-6 then fbBad[#fbBad + 1] = label .. " parchemin colonne " .. col end
      end
    end
  end
  for _, ws in ipairs({ 0.6, 0.85, 1, 1.15, 1.5 }) do
    frame:SetScale(ws)
    sampleAll(("repos ×%.2f"):format(ws))
    for _, b in ipairs({ rb, gb, card }) do
      W.animTo(b, "hover", 1, W.HOVER_IN)
      for i = 1, 6 do
        step(0.017)
        sampleAll(("survol ×%.2f image %d"):format(ws, i))
      end
      W.animTo(b, "hover", 0, W.HOVER_OUT)
      for i = 1, 6 do
        step(0.019)
        sampleAll(("sortie ×%.2f image %d"):format(ws, i))
      end
      settleHover()
    end
  end
  frame:SetScale(1.15)
  check(("client sans découpe : tranches bord à bord, sans jour ni chevauchement (%d relevés, fenêtre 0,6 à 1,5, survols image par image), coordonnées contiguës dans la pièce"):format(samples),
    samples > 500 and #fbBad == 0, table.concat(fbBad, ", ", 1, math.min(#fbBad, 6)))
  H.noSlice = false

  -- aperçu agrandi : un bouton découpé et son repli, fenêtre 1,15, à mi-survol (×3 pour l'aperçu)
  if SNAP then
    local big = CreateFrame("Frame", nil, _G.UIParent)
    big:SetSize(330, 90)
    big:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
    big:SetScale(1.15 * 3)
    local b1 = W.button(big, "Warrior", 150.3, 52, nil, "red", 17)
    b1:SetPoint("TOPLEFT", big, "TOPLEFT", 6.37, -10.21)
    H.noSlice = true
    local b2 = W.button(big, "Warrior", 150.3, 52, nil, "red", 17)
    b2:SetPoint("TOPLEFT", big, "TOPLEFT", 170.61, -10.21)
    H.noSlice = false
    H.settle()
    for _, b in ipairs({ b1, b2 }) do b:SetSelected(true) W.animTo(b, "hover", 1, W.HOVER_IN) end
    step(0.03)
    Render.svg(H, big, SNAP .. "/ub_bouton_mi_survol.svg", "découpé (gauche) / repli en tranches (droite), fenêtre 1,15, mi-survol, ×3")
    big:Hide()
  end
  holder:Hide()
end

print("UN  cartes neutres et bibelots communs : textes dans la zone et au langage, corps teinté, emplacement neutre du marchand, infobulles des bibelots")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  H.boot(nil)
  H.slash("")
  local ns = H.ns
  local W, Art, L = ns.Widgets, ns.Art, ns.Language
  local ROOT = ns.Skin.root
  -- 1. textes des 10 cartes neutres (base et améliorée) : panneau, une clause par ligne, icône embarquée,
  -- langage (aucun « you / your », libellés connus, aucune ressource de classe), corps ivoire teinté
  local card = W.card(UI().content)
  local ids, bad, minSize = {}, {}, 99
  for id, d in pairs(ns.Cards) do if d.neutral and not d.class then ids[#ids + 1] = id end end
  table.sort(ids)
  local tint = Art.bodyTints.neutral
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      local label = id .. (up and "+" or "")
      card:SetCard(id, up, { playable = true })
      local fit = card.bodyFit
      if not (fit and fit.ok and not fit.under and fit.mode == "clauses") then
        bad[#bad + 1] = label .. " : " .. tostring(fit and fit.mode) .. " " .. tostring(fit and fit.size)
      else
        minSize = math.min(minSize, fit.size)
      end
      local e = Art.cards[id]
      if not e or not e.tga or not ns.Skin.icons[e.tga:lower()] then bad[#bad + 1] = label .. " : icône absente de Media/Icons" end
      local d = ns.Card.defById(id, up)
      local low = " " .. d.text:lower():gsub("[%p\n]", " ") .. " "
      for _, w in ipairs({ "you", "your", "yours" }) do
        if low:find(" " .. w .. " ", 1, true) then bad[#bad + 1] = label .. " : « " .. w .. " »" end
      end
      for cl in (d.text .. "\n"):gmatch("(.-)\n") do
        local lab = cl:match("^(%u[%a ]-): ")
        if lab and not L.knownLabel(lab) then bad[#bad + 1] = label .. " : libellé inconnu « " .. lab .. " »" end
        if cl ~= "" and not cl:find("%.$") and not cl:find("^Gain %a") and not cl:find("^Apply ") then
          bad[#bad + 1] = label .. " : clause sans point « " .. cl .. " »"
        end
      end
      for _, r in pairs(L.resources) do
        if W.hasPhrase(d.text, r.name) or W.hasPhrase(d.text, r.plural) then bad[#bad + 1] = label .. " : ressource " .. r.name end
      end
      local vc = card.bg._calls.SetVertexColor or {}
      if card.bg._texture ~= ROOT .. ns.Skin.tex.card_body_ivory.file or math.abs((vc[1] or 0) - tint[1]) > 1e-9
          or math.abs((vc[2] or 0) - tint[2]) > 1e-9 or math.abs((vc[3] or 0) - tint[3]) > 1e-9 then
        bad[#bad + 1] = label .. " : corps " .. tostring(card.bg._texture) .. " teinte " .. tostring(vc[1])
      end
    end
  end
  -- une carte de classe garde son corps sans teinte
  card:SetCard("inner_fire", false, { playable = true })
  local vc = card.bg._calls.SetVertexColor or {}
  local classOk = card.bg._texture == ROOT .. ns.Skin.tex.card_body_blue.file and vc[1] == 1 and vc[2] == 1 and vc[3] == 1
  card:Hide()
  check(("textes : %d cartes neutres (base et améliorée) dans le panneau, une clause par ligne (taille mini %.1f), langage, icônes, corps ivoire teinté vert sauge"):format(#ids, minSize),
    #ids >= 10 and #bad == 0, table.concat(bad, ", ")) -- 10 de la fiche, plus le commun des zones
  check("carte de classe : corps et couleur inchangés (Inner Fire bleue, sans teinte)", classOk)
  -- infobulle : ligne « Neutral », explication de « Pay N HP. » (seule formulation d'un coût en PV)
  local tip = { lines = {} }
  function tip:AddLine(t) self.lines[#self.lines + 1] = t end
  function tip:NumLines() return #self.lines end
  W.fillCardTooltip(tip, "goblin_sapper_charge", false)
  local all = table.concat(tip.lines, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  check("infobulle d'une carte neutre : « Neutral » et « Pay N HP » expliqués", all:find("Neutral: a card that every class can use.", 1, true)
    and all:find("Pay N HP: costs HP", 1, true) and not all:find("Lose N HP", 1, true), all)

  -- 2. marchand : 5 cartes de classe + l'emplacement neutre, dans la fenêtre, sans chevauchement
  for _, cl in ipairs({ "priest", "warrior" }) do
    H.boot(nil)
    H.slash("")
    clickOption("class:" .. cl)
    H.ns.Controller.makeSeed = function() return SEED + 7 end
    clickOption("go")
    local e = EXP()
    local id = e.map.start[1]
    e.map.nodes[id].kind = "merchant"
    e.gold = 500
    clickOption("path:" .. id)
    H.settle()
    local s = UI().current
    local n = #s.cardOptions
    local last = s.cards[n]
    local lo = last and last.option
    local nid = lo and lo.card.id
    local fr = R.vrect(UI().content)
    local rects = {}
    for i = 1, n do rects[i] = { body = R.vrect(s.cards[i].bg), tag = s.cards[i].tag and R.vrect(s.cards[i].tag) } end
    local why = {}
    for i, r in ipairs(rects) do
      for _, k in ipairs({ "body", "tag" }) do
        local q = r[k]
        if not q then why[#why + 1] = i .. " " .. k .. " absent"
        elseif q[1] < fr[1] - 0.5 or q[3] > fr[3] + 0.5 or q[2] < fr[2] - 0.5 or q[4] > fr[4] + 0.5 then
          why[#why + 1] = ("%d %s hors de la fenêtre (%.1f..%.1f)"):format(i, k, q[1], q[3])
        end
      end
      if i > 1 and rects[i - 1].body and r.body and rects[i - 1].body[3] > r.body[1] + 0.5 then why[#why + 1] = i .. " chevauche " .. (i - 1) end
    end
    -- sous les cartes : titres des sections (bibelots, potions, service) plus bas que les étiquettes de prix
    for _, l in ipairs(s.sections) do
      local q = R.vrect(l)
      for i, r in ipairs(rects) do if r.tag and q and r.tag[2] < q[4] and r.tag[4] > q[2] and r.tag[3] > q[1] and r.tag[1] < q[3] then why[#why + 1] = i .. " sur « " .. l._text .. " »" end end
    end
    check(("marchand (%s) : 5 cartes de classe et la carte neutre en 6e, corps teinté, prix, dans la fenêtre sans chevauchement"):format(cl),
      n == 6 and last._shown and nid and ns.Cards[nid].neutral and e.shop.cards[6].neutral
        and last.bg._texture == ROOT .. ns.Skin.tex.card_body_ivory.file and last.tag._shown
        and last.tag.text._text == tostring(e.shop.cards[6].price) and #why == 0,
      tostring(n) .. " " .. tostring(nid) .. " " .. table.concat(why, ", "))
    local tt = table.concat(H.hover(last), " | ")
    check(("marchand (%s) : infobulle de la carte neutre (« Neutral »)"):format(cl), tt:find("Neutral", 1, true), tt)
    snap("marchand-neutre-" .. cl, true)
    local deckN = #e.deck
    clickOption(lo.id)
    check(("marchand (%s) : carte neutre achetée, dans le deck, marquée vendue"):format(cl),
      #e.deck == deckN + 1 and e.deck[#e.deck].id == nid and option(lo.id).sold)
  end
end

-- UN (suite) : bibelots communs de la fiche (infobulles, icônes embarquées), Herb Pouch dans le bandeau
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  H.boot(nil)
  H.slash("")
  local ns = H.ns
  local W, Art = ns.Widgets, ns.Art
  H.ns.Controller.makeSeed = function() return SEED + 8 end
  clickOption("go")
  local e = EXP()
  local NEW = { "scroll_of_intellect", "bloodsail_admirals_hat", "herb_pouch", "lifegiving_gem", "darkmoon_prize_ticket",
    "head_of_onyxia", "demonic_rune", "brilliant_mana_oil", "talisman_of_ephemeral_power", "philosophers_stone",
    "mark_of_the_champion", "onyxia_scale_cloak", "hourglass_sand", "bag_of_marbles", "flint_and_tinder",
    "harm_prevention_belt", "ironfoe", "royal_seal_of_eldre_thalas", "drake_fang_talisman" }
  local bad = {}
  for _, id in ipairs(NEW) do
    local r = ns.Relics[id]
    local a = Art.relics[id]
    if not (a and a.tga and ns.Skin.icons[a.tga:lower()]) then bad[#bad + 1] = id .. " : icône absente de Media/Icons" end
    -- bibelot posé en dernier : la case la plus à droite du bandeau, infobulle = nom puis texte
    e.relics[#e.relics + 1] = id
    UI().refresh()
    local b = UI().relicIcons[UI().RELICS_SHOWN]
    local tt = H.hover(b)
    local all = table.concat(tt, " ")
    if not b._shown or tt[1] ~= r.name or not all:find(r.text, 1, true) then
      bad[#bad + 1] = id .. " : « " .. table.concat(tt, " | ") .. " »"
    end
    if not (b.icon._texture or ""):lower():find(a.tga:lower(), 1, true) then bad[#bad + 1] = id .. " : icône " .. tostring(b.icon._texture) end
    if #r.text > 80 then bad[#bad + 1] = id .. " : texte de " .. #r.text .. " caractères" end
    table.remove(e.relics)
  end
  check(("bibelots communs : %d infobulles (nom, texte), icônes embarquées dans le bandeau"):format(#NEW), #bad == 0,
    table.concat(bad, ", "))
  -- Herb Pouch : quatre cases de potion calées à droite, séparateur et bibelots décalés, sans chevauchement
  ns.Expedition.gainRelic(e, "herb_pouch")
  for i = 4, 8 do e.relics[#e.relics + 1] = NEW[i] end
  UI().refresh()
  local slots = UI().potionSlots
  local why = {}
  if #e.potions ~= 4 then why[#why + 1] = "emplacements " .. #e.potions end
  for i = 1, 4 do if not slots[i]._shown then why[#why + 1] = "case " .. i .. " cachée" end end
  local band = R.vrect(UI().band)
  local prev
  for i = 1, 4 do
    local q = R.vrect(slots[i])
    if q[1] < band[1] or q[3] > band[3] then why[#why + 1] = "case " .. i .. " hors du bandeau" end
    if prev and prev[3] > q[1] + 0.5 then why[#why + 1] = "case " .. i .. " chevauche" end
    prev = q
  end
  local sepR, firstSlot = R.vrect(UI().sep), R.vrect(slots[1])
  if sepR[3] > firstSlot[1] + 0.5 then why[#why + 1] = "séparateur sur la case 1" end
  local lastRelic = R.vrect(UI().relicIcons[UI().RELICS_SHOWN])
  if lastRelic[3] > sepR[1] + 0.5 then why[#why + 1] = "bibelot sur le séparateur" end
  local gear = R.vrect(UI().gear)
  if R.vrect(slots[4])[3] > gear[1] + 0.5 then why[#why + 1] = "case 4 sur le bouton Menu" end
  check("Herb Pouch : quatre cases de potion dans le bandeau, alignées, sans chevauchement (séparateur, bibelots, Menu)",
    #why == 0, table.concat(why, ", "))
  H.hover(slots[4])
  check("case 4 vide : survol sans erreur", slots[4]._shown)
  snap("bandeau-herb-pouch", true)
end

-- planche des cartes neutres (base et améliorée)
if SNAP then
  local ns = H.ns
  local W = ns.Widgets
  local ids = {}
  for id, d in pairs(ns.Cards) do if d.neutral and not d.class then ids[#ids + 1] = id end end
  table.sort(ids, function(a, b)
    local da, db = ns.Cards[a], ns.Cards[b]
    if da.tier ~= db.tier then return da.tier < db.tier end
    return a < b
  end)
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
  Render.svg(H, big, SNAP .. "/cartes_neutres.svg", "cartes neutres (base, améliorée), par palier de Ligue")
  big:Hide()
end

print("UP  progression par classe : écran (5 classes aux niveaux 1, 4, 7), verrouillés muets, bilan avec montée de niveau, accueil")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function inside(r, box)
    return r and r[1] >= box[1] - 0.5 and r[2] >= box[2] - 0.5 and r[3] <= box[3] + 0.5 and r[4] <= box[4] + 0.5
  end
  local function fmt(r) return r and ("%.0f,%.0f,%.0f,%.0f"):format(r[1], r[2], r[3], r[4]) or "nil" end
  -- textes et textures visibles sous un cadre (descendants compris)
  local function regionsUnder(f, out)
    out = out or {}
    for _, k in ipairs(rawget(f, "_kids") or {}) do
      local kind = rawget(k, "_kind")
      if (kind == "FontString" or kind == "Texture") and vis(k) then out[#out + 1] = k end
      regionsUnder(k, out)
    end
    return out
  end
  local CLASSES = { "priest", "warrior", "mage", "rogue", "hunter" }
  -- seuils d'expérience (Meta.XP_LEVELS, vérifiés par les tests de l'expédition)
  local XPL = { 0, 100, 250, 450, 700, 1000, 1400 }
  local function bootLevels(levels)
    local db = { version = 5, meta = { runs = 0, zones = {}, classes = {}, flags = {} }, journal = {} }
    for cid, lv in pairs(levels) do
      db.meta.classes[cid] = { xp = XPL[lv], runs = 0, wins = 0, zones = {} }
    end
    H.boot(db)
    H.slash("")
  end
  local OPEN_CARDS = { 22, 25, 25, 28, 28, 31, 34 }
  local OPEN_RELICS = { 2, 2, 3, 3, 4, 4, 6 }
  for _, lv in ipairs({ 1, 4, 7 }) do
    local levels = {}
    for _, c in ipairs(CLASSES) do levels[c] = lv end
    bootLevels(levels)
    local ns = H.ns
    local W = ns.Widgets
    clickOption("ui:progress")
    check(("niveau %d : l'accueil mène à l'écran de progression"):format(lv), currentKind() == "classProgress", currentKind())
    for _, cid in ipairs(CLASSES) do
      clickOption("pclass:" .. cid)
      local tag = ("%s niveau %d"):format(cid, lv)
      local scr, st = UI().current, UI().step
      check(tag .. " : classe et niveau affichés (onglet choisi, barre « Level N »)", st.class == cid and st.level == lv
        and option("pclass:" .. cid).selected and (scr.bar.value._text or ""):find("Level " .. lv, 1, true) ~= nil
        and scr.bar.label._text == ns.Classes[cid].name, scr.bar.value._text)
      -- cartes : 34 emplacements, débloqués en vraies cartes, verrouillés en dos de carte
      local nCards, nLocks, badLock, badCard, badTip, outside = 0, 0, {}, {}, {}, {}
      local content = R.rect(ns.UI.content)
      local cond = ns.Classes[cid].name .. " level "
      for i = 1, #scr.cards do
        local c, k = scr.cards[i], scr.locks[i]
        if vis(c) then
          nCards = nCards + 1
          if not (c.entry and c.entry.unlocked and c.cardId == c.entry.id) then badCard[#badCard + 1] = tostring(c.cardId) end
          if (c.hoverLift or 0) ~= 0 then badCard[#badCard + 1] = "levée " .. tostring(c.hoverLift) end
          if not inside(R.rect(c), content) then outside[#outside + 1] = "carte " .. tostring(c.cardId) .. " " .. fmt(R.rect(c)) end
        end
        if vis(k) then
          nLocks = nLocks + 1
          -- rien d'autre que le dos de carte : aucun texte, aucune icône
          for _, r in ipairs(regionsUnder(k)) do
            local kind = rawget(r, "_kind")
            if kind == "FontString" and (rawget(r, "_text") or "") ~= "" then badLock[#badLock + 1] = "texte " .. r._text
            elseif kind == "Texture" and r ~= k.back then badLock[#badLock + 1] = "texture " .. tostring(rawget(r, "_texture")) end
          end
          if not tostring(rawget(k.back, "_texture") or ""):find("card_back", 1, true) then badLock[#badLock + 1] = "dos " .. tostring(rawget(k.back, "_texture")) end
          local tt = H.hover(k)
          if not (#tt == 1 and tt[1] == cond .. k.entry.level) then badTip[#badTip + 1] = table.concat(tt, " | ") end
          if not inside(R.rect(k), content) then outside[#outside + 1] = "dos " .. fmt(R.rect(k)) end
        end
      end
      -- cartes hors grille (Rogue : Nightblade, Subtlety niveau 3) comptées depuis les données
      local nAll, nOpen0 = 0, 0
      for _, d in pairs(ns.Cards) do
        if d.class == cid then nAll = nAll + 1; if (d.level or 1) <= lv then nOpen0 = nOpen0 + 1 end end
      end
      local xAll, xOpen = nAll - 34, nOpen0 - OPEN_CARDS[lv]
      check(tag .. (" : %d cartes, %d débloquées en vraies cartes, le reste en dos de carte"):format(34 + xAll, OPEN_CARDS[lv] + xOpen),
        nCards == OPEN_CARDS[lv] + xOpen and nCards + nLocks == 34 + xAll and #badCard == 0, nCards .. "+" .. nLocks .. " " .. table.concat(badCard, ","))
      check(tag .. " : carte verrouillée sans nom, texte ni icône ; infobulle = la condition seule",
        #badLock == 0 and #badTip == 0, table.concat(badLock, ",") .. " / " .. table.concat(badTip, ","))
      -- bibelots : 6 cases ; verrouillé = point d'interrogation grisé, infobulle = la condition
      local nOpen, badRelic = 0, {}
      for i, b in ipairs(scr.relics) do
        if vis(b) then
          local e = b.entry
          local tt = H.hover(b)
          if e.unlocked then
            nOpen = nOpen + 1
            if not (tt[1] == ns.Relics[e.id].name) then badRelic[#badRelic + 1] = "infobulle " .. table.concat(tt, " | ") end
          else
            if not (#tt == 1 and tt[1] == cond .. e.level) then badRelic[#badRelic + 1] = "verrou " .. table.concat(tt, " | ") end
            if not tostring(rawget(b.icon, "_texture") or ""):lower():find("questionmark", 1, true) then
              badRelic[#badRelic + 1] = "icône " .. tostring(rawget(b.icon, "_texture"))
            end
            if not b.icon._calls.SetDesaturated or b.icon._calls.SetDesaturated[1] ~= true then badRelic[#badRelic + 1] = "pas grisé" end
          end
          if not inside(R.rect(b), content) then outside[#outside + 1] = "bibelot " .. i .. " " .. fmt(R.rect(b)) end
        else
          badRelic[#badRelic + 1] = "case " .. i .. " cachée"
        end
      end
      check(tag .. (" : 6 bibelots, %d débloqués (infobulle du bibelot), verrouillés muets"):format(OPEN_RELICS[lv]),
        nOpen == OPEN_RELICS[lv] and #badRelic == 0, nOpen .. " " .. table.concat(badRelic, ","))
      -- noms des voies, onglets, barre et boutons dans la fenêtre ; rien de tronqué
      for i, l in ipairs(scr.rowLabels) do
        if vis(l) and not inside(R.rect(l), content) then outside[#outside + 1] = "voie " .. i .. " " .. fmt(R.rect(l)) end
      end
      for _, o in ipairs({ scr.bar, scr.metaBtn, scr.back }) do
        if not inside(R.rect(o), content) then outside[#outside + 1] = fmt(R.rect(o)) end
      end
      for i, b in ipairs(scr.tabs) do
        if vis(b) and not inside(R.rect(b), content) then outside[#outside + 1] = "onglet " .. i end
      end
      check(tag .. " : tout tient dans la fenêtre, sans défilement", #outside == 0, table.concat(outside, " ; "))
      H.settle()
      local tr = W.truncatedNow()
      check(tag .. " : aucun texte tronqué", #tr == 0, table.concat(tr, " ; "))
      if lv == 1 and cid == "priest" then snap("progression-priest-1", true) end
      if lv == 4 and cid == "warrior" then snap("progression-warrior-4", true) end
    end
    -- survol d'une carte de la dernière rangée : immobile et à sa taille, aperçu à taille réelle à côté,
    -- dans la fenêtre
    local scr = UI().current
    local last
    for i = #scr.cards, 1, -1 do if vis(scr.cards[i]) then last = scr.cards[i] break end end
    if last then
      local r0 = R.vrect(last.bg)
      last:GetScript("OnEnter")(last)
      for _ = 1, 40 do H.advance(0.02) end
      local vr = R.vrect(last.bg)
      local pv = H.ns.Widgets.preview
      local pr = pv and pv:IsVisible() and R.vrect(pv.bg)
      local content = R.rect(H.ns.UI.content)
      local ws = (content[3] - content[1]) / H.ns.UI.CONTENT_W -- échelle de la fenêtre (unités d'écran par unité)
      local k = pr and (pr[3] - pr[1]) / ws / H.ns.Widgets.CARD_W or 0
      check(("niveau %d : carte de la dernière rangée survolée immobile, aperçu à taille réelle (×%.2f) dans la fenêtre"):format(lv, k),
        fmt(vr) == fmt(r0) and pr and pv.of == last and pv.cardId == last.cardId and inside(pr, content)
        and math.abs(k - 1) < 1e-6, fmt(r0) .. " -> " .. fmt(vr) .. " / " .. (pr and fmt(pr) or "pas d'aperçu"))
      last:GetScript("OnLeave")(last)
      for _ = 1, 40 do H.advance(0.02) end
      check(("niveau %d : aperçu caché à la sortie"):format(lv), not pv:IsShown())
    end
    clickOption("ui:back")
    check(("niveau %d : retour à l'accueil"):format(lv), currentKind() == "start", currentKind())
  end
  -- accueil : l'infobulle d'une classe dit son niveau
  bootLevels({ warrior = 4 })
  local wtt = table.concat(H.hover(button("class:warrior")), " | ")
  check("accueil : infobulle du Guerrier « Level 4 »", wtt:find("Level 4", 1, true) ~= nil, wtt)
  -- bilan avec montée de niveau : expérience, niveau atteint, cartes révélées
  bootLevels({ priest = 1 })
  local ns = H.ns
  _G.SlayTheDragonDB.meta.classes.priest.xp = 95
  ns.Controller.makeSeed = function() return SEED end
  clickOption("go")
  local e = EXP()
  check("expédition au niveau de la classe au départ", e and e.unlock.level == 1)
  e.stats.cleared, e.stats.elites, e.stats.bosses = 8, 1, 1
  e.result, e.phase = "won", "done"
  ns.UI.refresh()
  local st = UI().step
  check("bilan : montée de niveau annoncée", currentKind() == "end" and (st.text or ""):find("Priest reaches level 2!", 1, true)
    and (st.text or ""):find("Priest experience", 1, true), st.text)
  local scr = UI().current
  local shownIds, content, out = {}, R.rect(ns.UI.content), {}
  for _, c in ipairs(scr.newCards) do
    if vis(c) then
      shownIds[#shownIds + 1] = c.cardId
      if not inside(R.rect(c), content) then out[#out + 1] = fmt(R.rect(c)) end
      for _, b in ipairs(scr.buttons) do
        local br = R.rect(b)
        local cr = R.rect(c)
        if vis(b) and br and cr and cr[1] < br[3] and br[1] < cr[3] and cr[2] < br[4] and br[2] < cr[4] then out[#out + 1] = "sur un bouton" end
      end
    end
  end
  table.sort(shownIds)
  check("bilan : les 3 cartes du niveau 2 révélées (vraies cartes), dans la fenêtre, hors des boutons",
    table.concat(shownIds, ",") == "evangelism,flash_heal,mind_sear" and #out == 0, table.concat(shownIds, ",") .. " " .. table.concat(out, " "))
  check("bilan : barre du niveau de classe seule (plus de Ligue)", scr.bars[1]._shown and (scr.bars[1].value._text or ""):find("Level 2", 1, true)
    and not scr.bars[2]._shown)
  H.settle()
  check("bilan : aucun texte tronqué", #ns.Widgets.truncatedNow() == 0, table.concat(ns.Widgets.truncatedNow(), " ; "))
  snap("bilan-montee-de-niveau", true)
  -- niveau 3 : un bibelot révélé (case du bibelot, infobulle du bibelot)
  clickOption("ui:new")
  _G.SlayTheDragonDB.meta.classes.priest.xp = 245
  clickOption("go")
  e = EXP()
  e.stats.cleared, e.stats.bosses = 8, 1
  e.result, e.phase = "won", "done"
  ns.UI.refresh()
  scr = UI().current
  local rb = scr.newRelics[1]
  local rtt = vis(rb) and table.concat(H.hover(rb), " | ") or ""
  check("bilan niveau 3 : Benediction révélée, aucune carte", vis(rb) and rtt:find("Benediction", 1, true) ~= nil
    and not vis(scr.newCards[1]), rtt)
  -- sans montée : rangée cachée, panneau à sa place
  clickOption("ui:new")
  clickOption("go")
  e = EXP()
  e.result, e.phase = "lost", "done"
  ns.UI.refresh()
  scr = UI().current
  check("bilan sans montée : rien de révélé", not vis(scr.newCards[1]) and not vis(scr.newRelics[1]))
end

print("UX survols sans agrandissement : texte immobile au pixel, surbrillance, cartes levées ou aperçu à taille réelle")
do
  -- Retour en jeu (vidéo, 12/11/2026) : au survol, un bouton grossissait de 4 % et son texte changeait
  -- d'espacement et se décalait d'un ou deux pixels (étiré pendant l'animation, puis redessiné à une
  -- autre taille). Règle : plus AUCUNE échelle au survol, nulle part. Pour chaque élément survolable de
  -- chaque écran : échelle de tout son sous-arbre inchangée (pendant et après le mouvement) ; s'il porte
  -- un texte et n'est pas une carte, textes au même rectangle au survol qu'au repos, visuel immobile, et
  -- surbrillance qui s'allume puis s'éteint ; élément sans texte : surbrillance aussi ; carte lisible :
  -- levée, halo, devant ses voisines ; petite carte : immobile, aperçu à taille réelle à côté.
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local function under(o, top)
    while o do
      if o == top then return true end
      o = rawget(o, "_parent")
    end
    return false
  end
  local function walk(f, out, kinds)
    for _, k in ipairs(rawget(f, "_kids")) do
      local kind = rawget(k, "_kind")
      if kind == "Texture" or kind == "FontString" then
        if not kinds or kinds[kind] then out[#out + 1] = k end
      elseif kind ~= "AnimationGroup" and kind ~= "Animation" and kind ~= "MaskTexture" then
        if kinds == nil or kinds.frames then out[#out + 1] = k end
        walk(k, out, kinds)
      end
    end
    return out
  end
  local function texts(f)
    local out = {}
    for _, t in ipairs(walk(f, {}, { FontString = true })) do
      if t:IsVisible() and (t._text or "") ~= "" then out[#out + 1] = t end
    end
    return out
  end
  local function lum(t)
    if not t:IsVisible() then return 0 end
    local a = (t._calls.SetAlpha and t._calls.SetAlpha[1]) or 1
    local vc = t._calls.SetVertexColor
    local k = vc and math.max(vc[1] or 1, vc[2] or 1, vc[3] or 1) or 1
    local o = rawget(t, "_parent")
    while o do
      local c = rawget(o, "_calls")
      if c and c.SetAlpha then a = a * (c.SetAlpha[1] or 1) end
      o = rawget(o, "_parent")
    end
    return a * k
  end
  local function lums(f)
    local out = {}
    for _, t in ipairs(walk(f, {}, { Texture = true })) do out[t] = lum(t) end
    return out
  end
  local function brighter(a, b)
    for t, v in pairs(b) do if v > (a[t] or 0) + 0.05 then return true end end
    return false
  end
  local function sameLum(a, b)
    for t, v in pairs(b) do if math.abs(v - (a[t] or 0)) > 1e-6 then return false end end
    return true
  end
  -- échelles de tout le sous-arbre (cadres et régions) et animations d'échelle en cours
  local function scales(f)
    local out = { f = rawget(f, "_scale") }
    for _, k in ipairs(walk(f, {}, nil)) do out[k] = rawget(k, "_scale") end
    return out
  end
  local function anyAnim(f)
    for _, k in ipairs(walk(f, {}, { frames = true })) do
      if rawget(k, "_kind") ~= "Texture" and rawget(k, "_kind") ~= "FontString" and H.visualScale(k) ~= 1 then return true end
    end
    return H.visualScale(f) ~= 1
  end
  local function sameScales(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    return true
  end
  local function rects(list)
    local out = {}
    for i, t in ipairs(list) do out[i] = R.vrect(t) or { 0, 0, 0, 0 } end
    return out
  end
  local function maxd(a, b)
    if #a ~= #b then return math.huge end
    local m = 0
    for i = 1, #a do for k = 1, 4 do m = math.max(m, math.abs(a[i][k] - b[i][k])) end end
    return m
  end
  local function isCard(f) return rawget(f, "cardId") ~= nil and rawget(f, "halo") ~= nil and rawget(f, "bg") ~= nil end
  local function label(f)
    if isCard(f) then return "carte " .. tostring(f.cardId) end
    for _, t in ipairs(texts(f)) do return "« " .. tostring(t._text):gsub("\n", " / ") .. " »" end
    return rawget(f, "pileKey") or rawget(f, "cid") or (rawget(f, "isLock") and "carte verrouillée") or "sans texte"
  end
  local function inside(r, box, m)
    m = m or 0
    return r[1] >= box[1] - m and r[3] <= box[3] + m and r[2] >= box[2] - m and r[4] <= box[4] + m
  end
  -- texte posé entier (ni tronqué, ni recoupé)
  local function whole(fs)
    if not fs or not fs:IsVisible() or (fs._text or "") == "" then return true end
    local n = 0
    for _ in ((fs._text or "") .. "\n"):gmatch("(.-)\n") do n = n + 1 end
    return not fs:IsTruncated() and fs:GetNumLines() == n
  end

  local stats = { text = 0, plain = 0, readable = 0, small = 0, locked = 0 }
  local bad = { scale = {}, text = {}, plain = {}, readable = {}, small = {}, locked = {} }
  local function visit(where)
    local Wd = H.ns.Widgets
    local frame = UI().frame
    local content = R.rect(UI().content)
    local list = {}
    for _, o in ipairs(H.objects) do
      if rawget(o, "_hoverable") and rawget(o, "face") and not rawget(o, "isPreview") and under(o, frame) and o:IsVisible() then
        list[#list + 1] = o
      end
    end
    for _, f in ipairs(list) do
      if f:IsVisible() then
        local name = where .. " : " .. label(f)
        local card = isCard(f)
        local tx = texts(f.face)
        local sc0, l0, r0 = scales(f), lums(f), rects(tx)
        local fp0 = tostring(f.face._points[1] and f.face._points[1][5])
        local lv0 = f._level
        local body0 = card and R.vrect(f.bg)
        run(f, "OnEnter")
        run(Wd.driver, "OnUpdate", 0.04)
        H.now = H.now + 0.04
        local scMid, animMid, rMid = scales(f), anyAnim(f), rects(tx)
        H.advance(0.5)
        local sc1, l1, r1 = scales(f), lums(f), rects(tx)
        local scaleOk = sameScales(sc0, scMid) and sameScales(sc0, sc1) and not animMid and not anyAnim(f)
          and f.face._scale == 1
        if not scaleOk then bad.scale[#bad.scale + 1] = name end
        local lit = brighter(l0, l1) or (rawget(f, "selected") == true)
        local pv = Wd.preview
        if card then
          local s = f:GetScale()
          local body1 = R.vrect(f.bg)
          if s >= Wd.PREVIEW_BELOW then
            stats.readable = stats.readable + 1
            local up = body1[2] - body0[2]
            if not (up > 0 and math.abs((body1[3] - body1[1]) - (body0[3] - body0[1])) < 1e-9 and lit and f._level > lv0
              and not (pv and pv:IsShown() and pv.of == f)) then
              bad.readable[#bad.readable + 1] = ("%s (levée %.2f, halo %s, niveau %s→%s)"):format(name, up, tostring(lit), lv0, f._level)
            end
          else
            stats.small = stats.small + 1
            local why = {}
            if maxd({ body0 }, { body1 }) > 1e-9 then why[#why + 1] = "bouge" end
            if not lit then why[#why + 1] = "halo éteint" end
            if not (pv and pv:IsVisible() and pv.of == f and pv.cardId == f.cardId and pv.cardUp == f.cardUp) then
              why[#why + 1] = "pas d'aperçu"
            else
              local pr = R.vrect(pv.bg)
              local k = (pr[3] - pr[1]) / ((content[3] - content[1]) / H.ns.UI.CONTENT_W) / Wd.CARD_W
              if math.abs(k - 1) > 1e-6 then why[#why + 1] = ("aperçu ×%.2f"):format(k) end
              local box = { math.huge, math.huge, -math.huge, -math.huge }
              for _, t in ipairs(walk(pv.face, {}, { Texture = true, FontString = true })) do
                if t:IsVisible() and t ~= pv.halo and (rawget(t, "_kind") == "Texture" or (t._text or "") ~= "") then
                  local q = R.vrect(t)
                  if q then box = { math.min(box[1], q[1]), math.min(box[2], q[2]), math.max(box[3], q[3]), math.max(box[4], q[4]) } end
                end
              end
              if not inside(box, content, 0.01) then why[#why + 1] = ("aperçu hors de la fenêtre (%.0f..%.0f × %.0f..%.0f)"):format(box[1], box[3], box[2], box[4]) end
              if box[1] < R.vrect(f.bg)[3] and box[3] > R.vrect(f.bg)[1] and box[2] < R.vrect(f.bg)[4] and box[4] > R.vrect(f.bg)[2] then
                why[#why + 1] = "aperçu sur la carte"
              end
              for _, k in ipairs({ "name", "cost", "body", "plateText" }) do
                if not whole(pv[k]) then why[#why + 1] = "aperçu : " .. k .. " tronqué" end
              end
              local tp = _G.GameTooltip._points[1]
              if _G.GameTooltip._shown and not (tp and tp[2] == pv) then why[#why + 1] = "infobulle pas à côté de l'aperçu" end
            end
            if #why > 0 then bad.small[#bad.small + 1] = name .. " : " .. table.concat(why, ", ") end
          end
        elseif rawget(f, "isLock") then
          stats.locked = stats.locked + 1
          if (pv and pv:IsShown()) or not lit then bad.locked[#bad.locked + 1] = name end
        elseif #tx > 0 then
          stats.text = stats.text + 1
          local fp1 = tostring(f.face._points[1] and f.face._points[1][5])
          local d = math.max(maxd(r0, rMid), maxd(r0, r1))
          local inactive = f.active == false or (rawget(f, "option") and f.option.disabled)
          if d > 1e-9 or fp1 ~= fp0 or (not lit and not inactive) or (lit and inactive and not f.selected) then
            bad.text[#bad.text + 1] = ("%s (texte déplacé de %.4f, %s)"):format(name, d, lit and "allumé" or "éteint")
          end
        else
          stats.plain = stats.plain + 1
          if not lit then bad.plain[#bad.plain + 1] = name end
        end
        run(f, "OnLeave")
        H.advance(0.5)
        local l2 = lums(f)
        if not sameLum(l0, l2) and not card then bad.plain[#bad.plain + 1] = name .. " (surbrillance restée allumée)" end
        if pv and pv:IsShown() then bad.small[#bad.small + 1] = name .. " : aperçu resté affiché" end
      end
    end
  end

  -- accueil, progression par classe
  H.boot(nil)
  H.slash("")
  visit("accueil")
  clickOption("ui:progress")
  visit("progression")
  if SNAP then
    -- aperçu à taille réelle d'une petite carte (instantané)
    local scr = UI().current
    local c = scr.cards[3]
    if c and c:IsVisible() then
      run(c, "OnEnter")
      H.advance(0.5)
      snap("survol-apercu-progression", true)
      run(c, "OnLeave")
      H.advance(0.5)
    end
    -- gros plan des boutons au repos et survolés (rouge, rouge et or, fermeture, réponse)
    local Wd = H.ns.Widgets
    local holder = CreateFrame("Frame", nil, UI().content)
    holder:SetSize(560, 260)
    holder:SetPoint("TOPLEFT", UI().content, "TOPLEFT", 0, 0)
    holder:SetFrameLevel(UI().content:GetFrameLevel() + 400)
    local bg = Wd.rect(holder, "BACKGROUND", -8, { 0.12, 0.1, 0.08 }, 1)
    bg:SetAllPoints()
    local shots = {}
    for row, spec in ipairs({ { "Back on the road", "red" }, { "Start expedition", "gold" } }) do
      for col = 1, 2 do
        local b = Wd.button(holder, spec[1], 220, 50, nil, spec[2], 18)
        b:SetPoint("TOPLEFT", holder, "TOPLEFT", 20 + (col - 1) * 260, -20 - (row - 1) * 70)
        shots[#shots + 1] = { b, col == 2 }
      end
    end
    for col = 1, 2 do
      local x = Wd.closeButton(holder, 30)
      x:SetPoint("TOPLEFT", holder, "TOPLEFT", 20 + (col - 1) * 260, -170)
      local m = Wd.button(holder, "Menu", 62, 22, nil, "red", 12.5)
      m:SetPoint("TOPLEFT", holder, "TOPLEFT", 70 + (col - 1) * 260, -174)
      shots[#shots + 1] = { x, col == 2 }
      shots[#shots + 1] = { m, col == 2 }
    end
    for _, s in ipairs(shots) do if s[2] then run(s[1], "OnEnter") end end
    H.advance(0.5)
    Render.svg(H, holder, SNAP .. "/survol-boutons.svg", "boutons : repos (gauche) / survolés (droite)")
    for _, s in ipairs(shots) do if s[2] then run(s[1], "OnLeave") end end
    H.advance(0.5)
    holder:Hide()
  end
  -- combat (main, boutons, piles, jetons, bandeau), panneau du deck, options
  freshRun(SEED, "combat")
  H.settle()
  local v = V()
  v.playerSt:Set({ { icon = H.ns.Art.ui.gold, key = "ui:gold", n = 3, info = { title = "Essai" } } })
  H.advance(0.1)
  visit("combat")
  -- bouton inactif : rien ne s'allume
  do
    local eb = v.endTurn
    eb:SetActive(false)
    local l0 = lums(eb)
    run(eb, "OnEnter")
    H.advance(0.5)
    check("bouton inactif (« End Turn ») : aucune surbrillance au survol", not brighter(l0, lums(eb)) and H.ns.Widgets.animValue(eb, "hover") == 0)
    run(eb, "OnLeave")
    H.advance(0.5)
    eb:SetActive(true)
    -- clic maintenu : assombri, sans bouger ; relâché : rallumé
    run(eb, "OnEnter")
    H.advance(0.5)
    local lUp = lums(eb)
    local tx0 = rects(texts(eb.face))
    run(eb, "OnMouseDown", "LeftButton")
    local lDown = lums(eb)
    local darker = false
    for t, val in pairs(lDown) do if val < (lUp[t] or 0) - 0.01 then darker = true end end
    local still = maxd(tx0, rects(texts(eb.face))) == 0 and eb.face._scale == 1
    run(eb, "OnMouseUp", "LeftButton")
    check("clic maintenu : bouton assombri, texte immobile ; relâché : surbrillance rendue", eb.pressed == false and darker and still
      and sameLum(lUp, lums(eb)))
    run(eb, "OnLeave")
    H.advance(0.5)
  end
  UI().toggleDeckView("deck")
  H.advance(0.2)
  visit("panneau du deck")
  H.click(UI().deckView.close)
  H.slash("options")
  visit("options")
  H.click(UI().optionsClose)
  -- marchand, feu de camp, grille d'amélioration, rencontre, parcours
  freshRun(SEED + 2, "merchant")
  visit("marchand")
  freshRun(SEED + 3, "campfire")
  visit("feu de camp")
  clickOption("ui:upgrade")
  visit("grille d'amélioration")
  freshRun(SEED + 4, "event")
  visit("rencontre")
  freshRun(SEED + 5, nil)
  visit("parcours")
  -- récompense (après une victoire)
  freshRun(SEED, "combat")
  H.settle()
  fightUntil(nil, 600)
  if V().banner._shown then
    visit("fin de combat")
    H.click(V().banner.button)
  end
  if currentKind() == "reward" then visit("récompense") end

  local function head(t, n)
    local out = {}
    for i = 1, math.min(#t, n) do out[i] = t[i] end
    if #t > n then out[#out + 1] = ("… (%d en tout)"):format(#t) end
    return table.concat(out, "\n        ")
  end
  local total = stats.text + stats.plain + stats.readable + stats.small + stats.locked
  check(("%d éléments survolés sur 12 écrans : aucune échelle changée (sous-arbre, animation Scale), pendant ni après le survol"):format(total),
    total > 80 and #bad.scale == 0, head(bad.scale, 10))
  check(("%d éléments à texte (boutons, plaques, onglets, cases à nombre…) : visuel immobile, texte au même rectangle au pixel près, surbrillance allumée puis éteinte (inactif : éteinte)"):format(stats.text),
    stats.text > 30 and #bad.text == 0, head(bad.text, 10))
  check(("%d éléments sans texte (icônes de classe, cases, étapes…) : à leur taille, surbrillance au survol, éteinte ensuite"):format(stats.plain),
    stats.plain > 5 and #bad.plain == 0, head(bad.plain, 10))
  check(("%d cartes lisibles (main, récompense, marchand) : levées, à leur taille, halo allumé, devant leurs voisines, sans aperçu"):format(stats.readable),
    stats.readable > 5 and #bad.readable == 0, head(bad.readable, 10))
  check(("%d petites cartes (grilles, panneau du deck, progression) : immobiles, halo, aperçu à taille réelle à côté, dans la fenêtre, texte entier, infobulle à côté"):format(stats.small),
    stats.small > 10 and #bad.small == 0, head(bad.small, 10))
  check(("%d cartes verrouillées : éclaircies, sans aperçu"):format(stats.locked), stats.locked > 0 and #bad.locked == 0, head(bad.locked, 10))
  local nPrev = 0
  for _, o in ipairs(H.objects) do if rawget(o, "isPreview") and under(o, UI().frame) then nPrev = nPrev + 1 end end
  check("aperçu : une seule instance pour la fenêtre, sur la couche du dessus (UI.overlay)", nPrev == 1
    and H.ns.Widgets.preview:GetParent() == UI().overlay, nPrev)
end

print("UF  feu de camp en modèle 3D (candidats, lueur, repli) ; PNJ des rencontres (candidats, attente, repli, gagnant) ; préchargement")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local function under(o, top)
    while o do if o == top then return true end o = rawget(o, "_parent") end
    return false
  end
  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function above(o, t) return R.drawnBefore(R.drawKey(t), R.drawKey(o)) end
  local function inter(a, b) return a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5 end
  local function alpha(m) return m._calls.SetAlpha and m._calls.SetAlpha[1] end
  H.boot()
  local ns = H.ns
  local Art, W, Sc = ns.Art, ns.Widgets, ns.Scene

  -- 1. données : feu (plusieurs fichiers, icône de repli embarquée) ; chaque rencontre a un personnage
  -- déclaré avec au moins deux candidats et une icône de repli embarquée
  local fireTries = Sc.modelTries(Art.campfire)
  local fireIcon = Art.campfire.icon and Art.campfire.icon.tga and ns.Skin.icons[Art.campfire.icon.tga:lower()]
  check("feu de camp : au moins 3 fichiers candidats (SetModel), icône du feu de camp embarquée en repli",
    #fireTries >= 3 and fireTries[1][1] == "file" and fireIcon ~= nil, #fireTries)
  local bad = {}
  for id, ev in pairs(ns.Events) do
    local a = ev.npc and Art.npcs[ev.npc]
    if not a then
      bad[#bad + 1] = id .. " : personnage " .. tostring(ev.npc) .. " non déclaré"
    else
      local n = #Sc.modelTries(a)
      local ic = a.icon and a.icon.tga and ns.Skin.icons[a.icon.tga:lower()]
      if n < 3 or not a.creature then bad[#bad + 1] = id .. " : " .. n .. " candidat(s)" end
      if not ic then bad[#bad + 1] = id .. " : icône de repli non embarquée (" .. tostring(a.icon and a.icon.tga) .. ")" end
    end
  end
  table.sort(bad)
  check("chaque rencontre : personnage déclaré, créature + affichages (3 candidats ou plus), icône embarquée",
    #bad == 0, table.concat(bad, " ; "))
  local src = io.open(root .. "/UI/Screens.lua"):read("*a")
  check("plus aucune trace de l'ancien dessin du feu (bûches, flammes en ellipses, halo ovale)",
    not src:find("fire.outer", 1, true) and not src:find("fire.inner", 1, true) and not src:find("#e2863b", 1, true)
    and not src:find("#5c3418", 1, true))

  -- 2. feu de camp, faux client sans fichier de feu : modèle invisible, puis médaillon après tous
  freshRun(SEED + 3, "campfire")
  ns = H.ns
  Art, W, Sc = ns.Art, ns.Widgets, ns.Scene
  local cp = UI().current
  local fire = cp.fire
  check("feu : cadre de modèle (PlayerModel) posé, invisible tant qu'il n'est pas chargé, pas de repli tout de suite",
    fire.model._kind == "PlayerModel" and fire.model:IsVisible() and alpha(fire.model) == 0 and not fire.fallback._shown)
  check("feu : les boutons et réponses n'attendent pas le modèle", cp.restPlaque:IsVisible() and cp.bookPlaque:IsVisible()
    and cp.leave:IsVisible())
  H.advance(#fireTries * Sc.MODEL_WAIT + 0.5)
  check("feu : aucun fichier ne charge -> médaillon à l'icône du feu de camp, au-dessus du modèle",
    fire.fallback._shown and fire.fallback.icon._texture == "Interface\\AddOns\\SlayTheDragon\\Media\\" .. fireIcon
    and fire.fallback._level > fire.model._level and W.models.campfire.state == "missing", fire.fallback.icon._texture)
  local fr, mr, hr = R.rect(fire), R.rect(fire.model), R.rect(cp.hero)
  local glowBad = {}
  if #fire.glow ~= #Sc.FIRE_GLOW then glowBad[1] = "nombre de couches" end
  for i, g in ipairs(fire.glow) do
    local vc = g._calls.SetVertexColor or {}
    local gr = R.rect(g)
    local why = {}
    if not vis(g) then why[#why + 1] = "cachée" end
    if g._texture ~= Sc.SHADOW then why[#why + 1] = "texture " .. tostring(g._texture) end
    if not (g._calls.SetBlendMode and g._calls.SetBlendMode[1] == "ADD") then why[#why + 1] = "pas additive" end
    if not (vc[1] == 1 and vc[2] < 0.8 and vc[3] < 0.4) then why[#why + 1] = "pas orange" end
    if not above(fire.model, g) then why[#why + 1] = "pas sous le modèle" end
    local k = (fr[3] - fr[1]) / fire._w
    if not gr or math.abs((gr[2] + gr[4]) / 2 - (mr[2] + Sc.FIRE_FEET * k)) > 0.6 then
      why[#why + 1] = ("centre %.1f, pied %.1f"):format(gr and (gr[2] + gr[4]) / 2 or -1, mr[2] + Sc.FIRE_FEET * k)
    end
    if #why > 0 then glowBad[#glowBad + 1] = "couche " .. i .. " : " .. table.concat(why, ", ") end
  end
  check("feu : lueur chaude (texture fondue, orange, additive) au pied du feu, sous le modèle", #glowBad == 0,
    table.concat(glowBad, " ; "))
  local oldBits = {}
  for _, o in ipairs(H.objects) do
    if rawget(o, "_kind") == "Texture" and under(o, fire) and not under(o, fire.fallback) and o._texture ~= Sc.SHADOW then
      oldBits[#oldBits + 1] = tostring(o._texture)
    end
  end
  check("feu : aucune autre région que la lueur (ni ellipse ni bûche dessinée)", #oldBits == 0, table.concat(oldBits, ", "))
  check("feu : posé sur la ligne des pieds du héros, entre le couchage et le grimoire, à l'échelle du héros",
    math.abs(mr[2] - hr[2]) < 0.6 and mr[1] > R.rect(cp.rest)[3] and mr[3] < R.rect(cp.book)[1]
    and (mr[4] - mr[2]) > 0.5 * (hr[4] - hr[2]) and (mr[4] - mr[2]) < 0.9 * (hr[4] - hr[2]))
  -- rien d'interface sous un modèle : toute région visible du contenu qui croise le modèle du feu (hors
  -- la lueur, ambiance voulue dessous, et le décor) est dessinée au-dessus de lui
  local hidden = {}
  for _, o in ipairs(H.objects) do
    local k = rawget(o, "_kind")
    if (k == "FontString" and (o._text or "") ~= "" or k == "Texture" and o._texture ~= nil) and vis(o)
      and under(o, ns.UI.content) and not under(o, ns.Scene.decor) and not under(o, ns.Scene.board)
      and rawget(o, "_parent") ~= ns.UI.content and not (o._calls.SetAlpha and o._calls.SetAlpha[1] == 0)
      and not (under(o, fire) and not under(o, fire.fallback)) then
      local r = R.rect(o)
      if r and inter(r, mr) and not above(o, fire.model) then hidden[#hidden + 1] = k .. " " .. tostring(o._texture or o._text) end
    end
  end
  check("feu : rien d'interface sous le modèle", #hidden == 0, table.concat(hidden, ", "))
  snap("feu-de-camp-repli")
  -- un fichier arrive tard (relance) : le modèle remplace le médaillon
  H.goodFiles = { [189705] = true }
  H.advance(Sc.MODEL_LATE + 0.5)
  check("feu : fichier arrivé à la relance -> modèle en fondu, médaillon effacé",
    not fire.fallback._shown and alpha(fire.model) == 1 and fire.model._model == "file:189705"
    and W.models.campfire.via == "file 189705", fire.model._model)
  H.goodFiles = nil

  -- 3. rencontre, client sans aucun modèle : le personnage attend, puis médaillon ; le texte n'attend pas
  H.noModels = true
  freshRun(SEED + 4, "event")
  ns = H.ns
  Art, W, Sc = ns.Art, ns.Widgets, ns.Scene
  local ch = UI().current
  local npcId = UI().step.npc
  local art = Art.npcs[npcId]
  check("rencontre : texte et réponses tout de suite, personnage invisible (alpha 0), pas encore de médaillon",
    ch.bubble:IsVisible() and ch.buttons[1]:IsVisible() and alpha(ch.npc.model) == 0 and not ch.npc.fallback._shown
    and not ch.npc.shadow:IsShown())
  H.advance(Sc.MODEL_WAIT * 1.5)
  check("rencontre : toujours pas de médaillon tant que des candidats restent", not ch.npc.fallback._shown)
  H.advance(#Sc.modelTries(art) * Sc.MODEL_WAIT)
  local icon = ns.Skin.icons[art.icon.tga:lower()]
  local nr, fr2 = R.rect(ch.npc.name), R.rect(ch.npc)
  check("rencontre : tous les candidats en échec -> médaillon à l'icône du personnage, nom au-dessus",
    ch.npc.fallback._shown and ch.npc.fallback.icon._texture == "Interface\\AddOns\\SlayTheDragon\\Media\\" .. icon
    and ch.npc.name._text == UI().step.speaker and nr and nr[2] >= fr2[4] and above(ch.npc.name, ch.npc.model)
    and W.models["npc:" .. npcId].state == "missing", ch.npc.fallback.icon._texture)
  snap("rencontre-repli")
  H.noModels = nil
  H.advance(Sc.MODEL_LATE + 0.5)
  check("rencontre : modèle arrivé tard -> il remplace le médaillon (fondu, ombre)",
    not ch.npc.fallback._shown and alpha(ch.npc.model) == 1 and ch.npc.shadow:IsShown()
    and W.models["npc:" .. npcId].state == "ok")

  -- 4. premier chargement lent (1,5 s) : attendu, jamais abandonné ni remplacé par le médaillon
  H.slowModels = { ["creature:235"] = 1.5 }
  Sc.won, Sc.failed, Sc.lost = {}, {}, {}
  ns.Persist.options().modelWins = {}
  Sc.npcFigure(ch.npc, "salma_saldean")
  local seen = false
  for _ = 1, 9 do
    H.advance(0.2)
    if ch.npc.fallback._shown then seen = true end
  end
  check("chargement lent (1,5 s < délai d'essai) : premier candidat gardé, aucun médaillon entre-temps",
    not seen and ch.npc.model._model == "creature:235" and W.models["npc:salma_saldean"].via == "creature 235"
    and Sc.MODEL_WAIT >= 1.5, tostring(seen) .. " " .. tostring(ch.npc.model._model) .. " "
    .. tostring(W.models["npc:salma_saldean"].state) .. " " .. tostring(W.models["npc:salma_saldean"].via))
  H.slowModels = nil

  -- 5. préchargement depuis le parcours : modèles des étapes accessibles chargés d'avance, gagnant
  -- mémorisé, scène qui l'obtient aussitôt
  H.boot()
  ns = H.ns
  Art, W, Sc = ns.Art, ns.Widgets, ns.Scene
  H.badCreatures = {}
  for _, a in pairs(Art.npcs) do H.badCreatures[a.creature] = true end
  H.slash("")
  ns.Controller.makeSeed = function() return SEED + 4 end
  clickOption("go")
  local e = EXP()
  local first = e.map.start[1]
  e.map.nodes[first].kind = "event"
  for i = 2, #e.map.start do e.map.nodes[e.map.start[i]].kind = "combat" end
  ns.UI.refresh()
  local pre = Sc.preloads
  local poolOk = pre.campfire ~= nil
  for _, evId in ipairs(ns.Expedition.eventPool(e)) do
    local npc = ns.Events[evId].npc
    if npc and not pre["npc:" .. npc] then poolOk = false end
  end
  for _, group in ipairs(ns.Encounters.westfall.easy) do
    for _, id in ipairs(group) do if not pre[id] then poolOk = false end end
  end
  check("préchargement lancé au parcours : feu de camp, PNJ des rencontres possibles, ennemis des combats possibles", poolOk)
  local framesOk = true
  for _, p in pairs(pre) do
    if not (vis(p.model) and alpha(p.model) == 0 and not under(p.model, _G.SlayTheDragonFrame)) then framesOk = false end
  end
  check("préchargement : cadres montrés avec une alpha 0, hors de la fenêtre de l'addon", framesOk)
  H.advance(Sc.MODEL_WAIT + 1)
  local winOk = true
  for k, p in pairs(pre) do
    if k:match("^npc:") then
      local a = Art.npcs[k:sub(5)]
      local d = type(a.display) == "table" and a.display[1] or a.display
      if not (p.status.state == "ok" and Sc.won[k] == "display " .. d and ns.Persist.options().modelWins[k] == Sc.won[k]) then
        winOk = false
      end
    end
  end
  check("préchargement : gagnant de chaque PNJ mémorisé (premier affichage, la créature échouant)", winOk)
  local keptOk = true
  for _, p in pairs(pre) do
    if p.status.state == "ok" and (p.model._shown or not p.model._model
      or not (p.model._calls.SetKeepModelOnHide and p.model._calls.SetKeepModelOnHide[1] == true)) then keptOk = false end
  end
  check("préchargement : cadre chargé caché (plus rien à dessiner), modèle gardé (SetKeepModelOnHide)", keptOk)
  clickOption("path:" .. first)
  local ch2 = UI().current
  local key = "npc:" .. UI().step.npc
  local a2 = Art.npcs[UI().step.npc]
  local d2 = type(a2.display) == "table" and a2.display[1] or a2.display
  check("scène : le gagnant mémorisé est posé en premier", ch2.npc.model._model == "display:" .. d2, ch2.npc.model._model)
  H.advance(0.9)
  check("scène : personnage affiché en moins d'une seconde grâce au préchargement, sans médaillon",
    W.models[key].state == "ok" and W.models[key].via == "display " .. d2 and not ch2.npc.fallback._shown
    and alpha(ch2.npc.model) == 1, tostring(W.models[key].state) .. " " .. tostring(W.models[key].via) .. " "
    .. tostring(ch2.npc.fallback._shown) .. " " .. tostring(alpha(ch2.npc.model)))
  local ev2 = ns.Events[EXP().event.id]
  local need = Sc.eventFightNeeds(ev2, EXP())
  local fightOk = Sc.preloads.campfire ~= nil
  for _, n in ipairs(need) do if not Sc.preloads[n.key] then fightOk = false end end
  check("rencontre : préchargement des ennemis des combats qu'elle peut lancer, feu de camp gardé", fightOk,
    EXP().event.id .. " : " .. #need .. " ennemi(s)")
  H.badCreatures = {}
end

-- UC : retours en jeu du 12/11/2026 (main du Mage, fenêtre à 115 %). Frostbolt : « Deal 6. » / « Apply » /
-- « Demoralized 1 ⌛ » collé en haut du panneau, vide dessous (« le texte est remonté, il ne devrait
-- pas ») ; le sablier à peu près deux fois plus petit que le chiffre voisin, lu comme un « z ». Le faux
-- client montrait déjà le bloc remonté (aucune vérification ne le regardait) ; il dessinait le sablier
-- trop grand (taille explicite prise en unités du texte : H.ICON_PX).
print("UC  texte des cartes centré dans le panneau (1 à 4 lignes, toutes les classes), sablier à la hauteur des chiffres")
do
  freshRun(SEED, "combat")
  H.settle()
  local ns = H.ns
  local W, Card = ns.Widgets, ns.Card
  local TZ, CW = W.CARD_TEXT, W.CARD_W
  local LH = H.metrics.lineHeight
  local optC = TZ.optY * CW
  local function splitLines(t)
    local out = {}
    if t == nil or t == "" then return out end
    for l in (t .. "\n"):gmatch("(.-)\n") do out[#out + 1] = l end
    return out
  end
  -- centre optique mesuré sur les pixels du panneau : premières et dernières lignes sombres (critère de
  -- U22) dans la colonne du milieu
  do
    local e = ns.Skin.tex.card_panel
    local f = assert(io.open(root .. "/Media/" .. e.file:gsub("\\", "/"), "rb"))
    local d = f:read("*a")
    f:close()
    local w, h = d:byte(13) + 256 * d:byte(14), d:byte(15) + 256 * d:byte(16)
    local function dark(x, y)
      local i = 18 + ((h - 1 - y) * w + x) * 4 + 1
      return d:byte(i + 3) > 250 and d:byte(i) + d:byte(i + 1) + d:byte(i + 2) < 360
    end
    local x = math.floor(TZ.cx * CW / (ns.Skin.card.pieces.card_panel[3] * CW) * e.cw
      - ns.Skin.card.pieces.card_panel[1] / ns.Skin.card.pieces.card_panel[3] * e.cw)
    local y0, y1
    for y = 0, e.ch - 1 do
      if dark(x, y) then y0 = y0 or y y1 = y end
    end
    local r = ns.Skin.card.pieces.card_panel
    local top = (r[2] + y0 / e.ch * r[4]) * CW
    local bot = (r[2] + (y1 + 1) / e.ch * r[4]) * CW
    check(("centre optique : milieu de l'intérieur sombre mesuré sur Media/card_panel.tga (%.1f à %.1f unités, centre %.2f ; TZ.optY : %.2f)")
      :format(top, bot, (top + bot) / 2, optC), math.abs((top + bot) / 2 - optC) < 0.3)
  end
  -- encre d'un texte posé : haut des capitales de la première ligne, ligne de base de la dernière
  -- (ligne de base aux W.TEXT_BASE de la ligne, capitales de W.TEXT_CAP cadratin : Baloo Chettan 2, même
  -- modèle que le rendu SVG du harnais)
  local function inkCenter(card)
    local first, last, n = nil, nil, 0
    for b = 1, card.bodyUsed or 1 do
      local p = card.bodyParts[b]
      local pl = splitLines(p._text)
      if #pl > 0 then
        local size = H.renderSize(p)
        local lh = size * LH
        local top = -p._points[1][5] - #pl * lh / 2
        first = first or (top + W.TEXT_BASE * lh - W.TEXT_CAP * size)
        last = top + (#pl - 1) * lh + W.TEXT_BASE * lh
        n = n + #pl
      end
    end
    return first and (first + last) / 2 or nil, n
  end
  local holder = UI().content
  local card = W.card(holder)
  local ids = {}
  for id in pairs(ns.Cards) do ids[#ids + 1] = id end
  table.sort(ids)
  local bad, worst, byLines, more = {}, 0, {}, {}
  for _, id in ipairs(ids) do
    for _, up in ipairs({ false, true }) do
      card:SetCard(id, up, { playable = true })
      local c, n = inkCenter(card)
      local label = id .. (up and "+" or "")
      if c and card.bodyFit.ok then
        local dv = c - optC
        if n >= 1 and n <= 4 then
          byLines[n] = (byLines[n] or 0) + 1
          worst = math.max(worst, math.abs(dv))
          if math.abs(dv) > 1 + 1e-6 then
            bad[#bad + 1] = ("%s (%d lignes, taille %s) : centre de l'encre à %+.2f du centre optique"):format(label, n, tostring(card.bodyFit.size), dv)
          end
        else
          more[#more + 1] = ("%s %+.1f"):format(label, dv)
        end
      elseif not card.bodyFit.ok then
        bad[#bad + 1] = label .. " : ne tient à aucun palier"
      end
    end
  end
  -- témoin : l'ancienne position de Frostbolt (bloc en haut de la zone, 3 lignes à 10, sans écart) serait refusée
  local oldC = (TZ.top * CW + W.TEXT_BASE * 10 - W.TEXT_CAP * 10 + TZ.top * CW + 2 * 10 + W.TEXT_BASE * 10) / 2
  local cnt = {}
  for k = 1, 4 do cnt[#cnt + 1] = ("%d → %d"):format(k, byLines[k] or 0) end
  check(("bloc centré à ±1 unité (encre : haut des capitales de la 1re ligne, ligne de base de la dernière) sur toutes les cartes de 1 à 4 lignes, base et améliorées (%s ; écart maximal %.2f) ; témoin : Frostbolt d'avant à %+.1f")
    :format(table.concat(cnt, ", "), worst, oldC - optC), #bad == 0 and math.abs(oldC - optC) > 1, table.concat(bad, "\n        "))
  print("      5 lignes et plus (décalage au plus nécessaire, sous la gemme) : " .. (#more > 0 and table.concat(more, ", ") or "aucune"))
  -- sablier : dessin mesuré sur les pixels de Media/hourglass.tga (alpha > 8)
  local tf = assert(io.open(root .. "/Media/hourglass.tga", "rb"))
  local td = tf:read("*a")
  tf:close()
  local tw, th = td:byte(13) + 256 * td:byte(14), td:byte(15) + 256 * td:byte(16)
  local ymin, ymax = th, -1
  for r = 0, th - 1 do
    for x = 0, tw - 1 do
      if td:byte(18 + (r * tw + x) * 4 + 4) > 8 then
        local y = th - 1 - r
        ymin, ymax = math.min(ymin, y), math.max(ymax, y)
      end
    end
  end
  local frac, botFrac = (ymax - ymin + 1) / th, (ymax + 1) / th
  -- chaque sablier posé sur une carte, fenêtre 1, 1,15 et 0,6 : hauteur du dessin (taille de la séquence
  -- telle que le faux client la rend, H.iconUnit) ≥ 90 % de la hauteur de capitale du texte rendu ; bas
  -- du dessin sur la ligne de base (icône centrée sur la ligne)
  local hbad, nHg, minR = {}, 0, math.huge
  for _, sc in ipairs({ 1, 1.15, 0.6 }) do
    local box = CreateFrame("Frame", nil, _G.UIParent)
    box:SetSize(300, 300)
    box:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
    box:SetScale(sc)
    local c2 = W.card(box)
    for _, id in ipairs(ids) do
      for _, up in ipairs({ false, true }) do
        c2:SetCard(id, up, { playable = true })
        for b = 1, c2.bodyUsed or 1 do
          local p = c2.bodyParts[b]
          local size = H.renderSize(p)
          local _, _, list = H.inlineIcons(p._text or "", size, H.iconUnit(p))
          for _, ic in ipairs(list) do
            nHg = nHg + 1
            local r = ic.h * frac / (W.TEXT_CAP * size)
            minR = math.min(minR, r)
            local lh = size * LH
            local base = (lh - ic.h) / 2 + botFrac * ic.h -- bas du dessin, depuis le haut de la ligne
            if r < 0.9 or math.abs(base - W.TEXT_BASE * lh) > 0.08 * size then
              hbad[#hbad + 1] = ("%s%s ×%s : dessin %.2f / capitale %.2f, bas à %+.2f de la ligne de base"):format(id, up and "+" or "", tostring(sc),
                ic.h * frac, W.TEXT_CAP * size, base - W.TEXT_BASE * lh)
            end
          end
        end
      end
    end
    box:Hide()
  end
  -- témoin : l'ancienne séquence (hauteur explicite 7 pour un texte de 10, dessin de 60/64) dans une carte à
  -- 1,15 : la moitié de la hauteur de capitale, comme sur la capture
  local box = CreateFrame("Frame", nil, _G.UIParent)
  box:SetScale(1.15)
  local fs = W.label(box, "bold", 10)
  local _, _, olist = H.inlineIcons("1|TInterface\\AddOns\\SlayTheDragon\\Media\\hourglass.tga:7:7:0:0:64:64:0:64:0:64:255:255:255|t", 10, H.iconUnit(fs))
  local oldR = olist[1].h * 60 / 64 / (W.TEXT_CAP * 10)
  box:Hide()
  check(("sablier : %d posés (fenêtre 1, 1,15 et 0,6), dessin ≥ 90 %% de la hauteur de capitale (au plus petit %d %%), bas sur la ligne de base ; dessin %d/%d texels de haut ; témoin : ancienne séquence à 1,15 : %d %%")
    :format(nHg, math.floor(minR * 100 + 0.5), ymax - ymin + 1, th, math.floor(oldR * 100 + 0.5)),
    #hbad == 0 and nHg > 0 and oldR < 0.9, table.concat(hbad, "\n        "))
  card:Hide()
  -- planche : Frostbolt, Fireball, une carte de quatre lignes, une d'une ligne (texte_centre.svg)
  if SNAP then
    local four, one
    for _, id in ipairs({ "shadowform", "penance" }) do
      card:SetCard(id, false, { playable = true })
      if not four and select(2, inkCenter(card)) == 4 then four = id end
    end
    card:SetCard("smite", false, { playable = true })
    if select(2, inkCenter(card)) == 1 then one = "smite" end
    local list = { "frostbolt", "fireball", four or "shadowform", one or "smite" }
    local zoom = CreateFrame("Frame", nil, _G.UIParent)
    zoom:SetSize(#list * 140 + 20, 240)
    zoom:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
    zoom:SetScale(3)
    for i, id in ipairs(list) do
      local c = W.card(zoom)
      c:SetCard(id, false, { playable = true })
      W.placeCenter(c, zoom, 80 + (i - 1) * 140, 125, 1)
    end
    Render.svg(H, zoom, SNAP .. "/texte_centre.svg", "texte centré, sablier : " .. table.concat(list, ", "))
    zoom:Hide()
  end
end

print("UG  combat : crans de la ressource, textes flottants des annulations, liseré Instant et Spend N, Traveler's Backpack")
do
  -- combat de l'acte 1 pour une classe (bibelots ajoutés avant le combat)
  local function ugCombat(cl, relics)
    H.boot(nil)
    H.slash("")
    clickOption("class:" .. cl)
    H.ns.Controller.makeSeed = function() return SEED end
    clickOption("go")
    local e = EXP()
    for _, r in ipairs(relics or {}) do e.relics[#e.relics + 1] = r end
    local id = e.map.start[1]
    e.map.nodes[id].kind = "combat"
    clickOption("path:" .. id)
    H.settle()
    local v = V()
    v:Render(true)
    return e, e.combat, v
  end
  local function alphaOf(t) return t._calls.SetAlpha and t._calls.SetAlpha[1] or 1 end
  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function hexOf(col) return H.ns.Widgets.hexOf(col) end
  local function stepDriver(dt) run(H.ns.Widgets.driver, "OnUpdate", dt) end
  local function filled(v, cap)
    local n, bad = 0, {}
    for i = 1, cap do
      local a = alphaOf(v.resPips.list[i].fill)
      if a == 1 then n = n + 1 elseif a ~= 0 then bad[#bad + 1] = i .. "=" .. a end
    end
    return n, table.concat(bad, ",")
  end

  -- 1. Crans : aucun pour l'Insanity (sans plafond), autant que le plafond sinon, remplis selon la ressource
  local _, cp, vp = ugCombat("priest")
  check("crans : aucun pour le Priest (Insanity sans plafond)", not vis(vp.resPips))
  local CAPS = { warrior = 5, rogue = 5, mage = 4, hunter = 5 }
  for _, cl in ipairs({ "warrior", "rogue", "mage", "hunter" }) do
    local _, c, v = ugCombat(cl)
    local cap = CAPS[cl]
    local eqCap = H.ns.Classes[cl].resource.cap
    local sockets = 0
    for i, p in ipairs(v.resPips.list) do if vis(p.socket) then sockets = sockets + 1 end end
    c.player.res = 0
    v:Render(true)
    H.advance(1)
    local n0 = filled(v, cap)
    check(("crans du %s : %d alvéoles (plafond %d), visibles à 0, aucun rempli"):format(cl, sockets, cap),
      vis(v.resPips) and sockets == cap and eqCap == cap and n0 == 0 and not v.resource._shown, sockets .. " / " .. n0)
    -- remplissage : 0 -> 3, fondu (valeur intermédiaire au pilote), éclat qui s'éteint, sans échelle
    c.player.res = 3
    v:Render(true)
    local p3 = v.resPips.list[3]
    local a0 = alphaOf(p3.fill)
    stepDriver(0.1)
    local mid = alphaOf(p3.fill)
    local g = alphaOf(p3.glow)
    H.advance(1)
    local n3, bad3 = filled(v, cap)
    check(("crans du %s : 3 remplis en fondu (%.2f -> %.2f -> 1), éclat %.2f puis éteint, aucune échelle"):format(cl, a0, mid, g),
      a0 == 0 and mid > 0 and mid < 1 and g > 0 and n3 == 3 and bad3 == "" and alphaOf(p3.glow) == 0
      and not p3.fill._calls.SetScale and not v.resPips._calls.SetScale, bad3)
    -- vidage : 3 -> 1, fondu sans éclat
    c.player.res = 1
    v:Render(true)
    stepDriver(0.1)
    local m2 = alphaOf(v.resPips.list[2].fill)
    local g2 = alphaOf(v.resPips.list[2].glow)
    H.advance(1)
    local n1 = filled(v, cap)
    check(("crans du %s : vidés en fondu jusqu'à 1 (%.2f en route), sans éclat"):format(cl, m2), n1 == 1 and m2 > 0 and m2 < 1 and g2 == 0)
    -- couleur de la ressource (Art.classes[cl].resource.color), gemme désaturée puis teinte
    local ra = H.ns.Art.classResource(cl)
    local col = H.ns.Art.C[ra.color]
    local vc = v.resPips.list[1].fill._calls.SetVertexColor
    check(("crans du %s : gemme embarquée (Media), désaturée, teinte de la ressource"):format(cl),
      (v.resPips.list[1].fill._texture or ""):find("gem_rare", 1, true) and v.resPips.list[1].fill._calls.SetDesaturated[1] == true
      and vc and math.abs(vc[1] - col[1]) < 1e-6 and math.abs(vc[3] - col[3]) < 1e-6, tostring(v.resPips.list[1].fill._texture))
    -- placement : hors de la main (bord gauche des cartes) et dans le plateau
    local R = dofile(root .. "/Sim/ui_render.lua")
    R.H = H
    local lastR = R.rect(v.resPips.list[cap].socket)
    local firstR = R.rect(v.resPips.list[1].socket)
    local cardR = R.rect(v.cards[1])
    local board = R.rect(v.hz)
    check(("crans du %s : en arc à droite de l'anneau de mana, à gauche de la main, dans le plateau"):format(cl),
      lastR and cardR and firstR[3] < cardR[1] and lastR[3] < cardR[1] and firstR[2] >= board[2] and lastR[4] <= board[4],
      firstR and cardR and (firstR[3] .. " < " .. cardR[1]))
    c.player.res = math.min(3, cap)
    v:Render(true)
    H.advance(1)
    snap("ug-crans-" .. cl, true)
  end

  -- 2. Textes flottants des annulations : Parry (héros), Trap (son nom, sur l'ennemi), interruption sans
  -- effet (nom du bibelot), tour ennemi sauté ; les retours qui existaient restent (Absorb, Stunned, Interrupted)
  local floats = {}
  -- relevé des textes flottants (à reposer après chaque H.boot : nouveaux modules)
  local function hookFloats()
    local Wg = H.ns.Widgets
    local old = Wg.float
    Wg.float = function(parent, x, y, text, ...) floats[#floats + 1] = { text = text, x = x, y = y } return old(parent, x, y, text, ...) end
  end
  local function seen(txt)
    for _, f in ipairs(floats) do if f.text == txt then return f end end
  end
  local e, c, v = ugCombat("rogue")
  hookFloats()
  H.ns.Combat.applyStatus(c, c.player, "parry", 3)
  c.events = {} -- (le gain posé à la main n'est pas rejoué : son nom flotterait aussi)
  v:Render(true)
  floats = {}
  H.click(v.endTurn)
  local evs = H.ns.Controller.lastEvents or {}
  local nParry = 0
  for _, ev in ipairs(evs) do if ev.t == "parry" then nParry = nParry + 1 end end
  -- instantané quand « Parry » est à l'écran
  local shot = false
  for _ = 1, 80 do
    H.advance(0.1)
    if not shot and seen("Parry") then H.advance(0.25) snap("ug-parry-rogue", true) shot = true end
    if not v.playing then break end
  end
  H.settle()
  local pf = seen("Parry")
  local hx = select(1, v:UnitPos("player"))
  local nf = 0
  for _, f in ipairs(floats) do if f.text == "Parry" then nf = nf + 1 end end
  check(("Parry : « Parry » flottant au héros, un par charge employée (%d coups parés)"):format(nParry),
    nParry > 0 and nf == nParry and pf and math.abs(pf.x - hx) < 60, nf .. " / " .. nParry)
  -- Trap déclenchée (Hunter, Freezing Trap posée par l'interface) : son nom part de l'ennemi
  e, c, v = ugCombat("hunter")
  hookFloats()
  c.hand[1] = H.ns.Card.new("freezing_trap", false, 9301)
  c.player.mana = 3
  v:Render(true)
  H.ns.Controller.play(1)
  H.settle()
  floats = {}
  H.click(v.endTurn)
  local trapEv
  for _, ev in ipairs(H.ns.Controller.lastEvents or {}) do if ev.t == "trap" then trapEv = ev end end
  shot = false
  for _ = 1, 80 do
    H.advance(0.1)
    if not shot and seen("Freezing Trap!") then H.advance(0.25) snap("ug-trap-hunter", true) shot = true end
    if not v.playing then break end
  end
  H.settle()
  local tf = seen("Freezing Trap!")
  local ex = trapEv and select(1, v:UnitPos(trapEv.dst))
  check("Trap déclenchée : « Freezing Trap! » flottant sur l'ennemi qui l'a déclenchée (journal : id de la carte)",
    trapEv and trapEv.id == "freezing_trap" and tf and ex and math.abs(tf.x - ex) < 1, trapEv and tostring(trapEv.id))
  check("Stunned qui arrête le tour ennemi : « Stunned » (existait)", seen("Stunned") ~= nil)
  -- événements synthétiques : interruption sans effet, tour sauté, et retours qui existaient
  floats = {}
  local alive = {}
  for _, en in ipairs(c.enemies) do if not en.dead then alive[#alive + 1] = en end end
  v:OnEvents({ { t = "interrupt_prevented", src = alive[1].uid, dst = "player", card = "fireball", by = "focus_talisman" },
    { t = "interrupt_prevented", src = alive[1].uid, dst = "player", card = "fireball" },
    { t = "enemy_turn_skipped" },
    { t = "damage", src = alive[1].uid, dst = "player", amount = 5, absorbed = 5, loss = 0 },
    { t = "interrupt", src = alive[1].uid, dst = "player", card = "fireball" },
    { t = "stunned", unit = alive[1].uid, stopped = true } })
  H.settle()
  local nSkip = 0
  for _, f in ipairs(floats) do if f.text == "Skips its turn" then nSkip = nSkip + 1 end end
  check("interruption sans effet : nom du bibelot (« Talisman of Focus! »), sinon « Not interrupted »",
    seen("Talisman of Focus!") and seen("Not interrupted"))
  check(("tour ennemi sauté (Feign Death) : « Skips its turn » sur chaque ennemi vivant (%d)"):format(#alive), nSkip == #alive and #alive > 0)
  check("retours existants : coup absorbé « -5 », « Interrupted! », « Stunned »", seen("-5") and seen("Interrupted!") and seen("Stunned"))
  local W

  -- 3. Liseré Instant et « Cast · Instant » ; ligne « Spend N: » allumée / éteinte
  e, c, v = ugCombat("mage")
  W = H.ns.Widgets
  c.hand[1] = H.ns.Card.new("fireball", false, 9401)
  c.hand[2] = H.ns.Card.new("frostbolt", false, 9402)
  c.player.mana = 3
  c.player.st.instant = nil
  v:Render(true)
  local fb = v.cards[1]
  check("sans Instant : Fireball sans liseré, plaque « Cast »", not vis(fb.rim) and fb.plateText._text == "Cast", fb.plateText._text)
  H.ns.Combat.applyStatus(c, c.player, "instant", 1)
  v:Render(true)
  local plain = (fb.plateText._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local rc = fb.rim._calls.SetVertexColor or {}
  check("Instant : Fireball au liseré bleu (sous le halo, devant rien), plaque « Cast · Instant »",
    vis(fb.rim) and plain == "Cast · Instant" and math.abs(rc[1] - W.INSTANT_RIM_COLOR[1]) < 1e-6
    and fb.rim._layer == "BACKGROUND" and fb.halo._sub < fb.rim._sub and fb.rim._sub < fb.bg._sub, plain)
  local fr = v.cards[2]
  check("Instant : une carte qui n'est pas Cast (Frostbolt) n'a ni liseré ni « Instant »",
    not vis(fr.rim) and not (fr.plateText._text or ""):find("Instant", 1, true), fr.plateText._text)
  local tt = table.concat(H.hover(fb), " | ")
  check("Instant : infobulle « Instant: this Cast resolves at once. »", tt:find("this Cast resolves at once", 1, true), tt)
  -- survol : le liseré reste visible avec le halo doré, et ne bouge pas sans la carte (même visuel)
  H.hover(fb)
  check("liseré dans le visuel de la carte (suit la levée), aucune échelle", rawget(fb.rim, "_parent") == fb.face
    and not fb.rim._calls.SetScale)
  -- toutes les cartes Cast, base et améliorée, sous Instant : plaque qui tient (jamais coupée)
  local probe = W.card(UI().content)
  local pbad, np = {}, 0
  for id, d in pairs(H.ns.Cards) do
    if d.cast then
      for _, up in ipairs({ false, true }) do
        probe:SetCard(id, up, { playable = true, instant = true })
        np = np + 1
        local f = probe.plateFit
        if not (f and f.ok and not f.cut) then pbad[#pbad + 1] = id .. (up and "+" or "") end
      end
    end
  end
  probe:Hide()
  check(("plaque « Cast · Instant » : %d cartes Cast (base, améliorée) qui tiennent sans coupure"):format(np), np > 0 and #pbad == 0,
    table.concat(pbad, ", "))
  snap("ug-instant-mage", true)
  -- la carte jouée sous Instant part tout de suite (le moteur ; l'affichage ne ment pas)
  local ok = H.ns.Controller.play(1, 1)
  H.settle()
  check("Fireball jouée sous Instant : résolue tout de suite, aucune incantation", ok and c.player.cast == nil and not c.player.st.instant)
  v:Render(true)
  check("Instant consommé : plus de liseré sur les cartes Cast restantes", not vis(v.cards[1].rim))
  -- Spend N (Warrior, Heroic Strike) : allumée si les points sont là, éteinte sinon ou Maj tenue
  e, c, v = ugCombat("warrior")
  W = H.ns.Widgets
  c.hand[1] = H.ns.Card.new("heroic_strike", false, 9501)
  c.player.mana = 3
  local off = "|cff" .. hexOf(W.SPEND_OFF_COLOR) .. "Spend 2:"
  local function bodyText(card)
    local t = {}
    for _, p in ipairs(card.bodyParts) do if p._shown and p._text then t[#t + 1] = p._text end end
    return table.concat(t, "\n")
  end
  c.player.res = 0
  v:Render(true)
  local t0 = bodyText(v.cards[1])
  c.player.res = 2
  v:Render(true)
  local t2 = bodyText(v.cards[1])
  H.shift = true
  run(v.classZone, "OnEvent", "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
  local ts = bodyText(v.cards[1])
  H.shift = false
  run(v.classZone, "OnEvent", "MODIFIER_STATE_CHANGED", "LSHIFT", 0)
  check("Spend 2 : éteinte à 0 Rage, allumée à 2 (mot-clé en couleur), éteinte sous Maj, rallumée au relâchement",
    t0:find(off, 1, true) and not t2:find(off, 1, true) and t2:find("Spend", 1, true) and t2:find("|cff" .. hexOf(W.KEYWORD_COLOR), 1, true)
    and ts:find(off, 1, true) and not bodyText(v.cards[1]):find(off, 1, true), t2)
  snap("ug-spend-warrior", true)
  c.player.res = 0
  v:Render(true)
  snap("ug-spend-off-warrior", true)

  -- 4. Traveler's Backpack : « End Turn » ouvre le choix, liseré d'or, clic = carte gardée, clic droit annule,
  -- « Keep none » finit sans garder ; sans carte à garder, le tour finit tout de suite
  for _, cl in ipairs({ "warrior", "priest" }) do
    e, c, v = ugCombat(cl, { "travelers_backpack" })
    check(cl .. " : Traveler's Backpack porté (bandeau), icône embarquée", e.relics[#e.relics] == "travelers_backpack"
      and H.ns.Skin.icons[H.ns.Art.relics.travelers_backpack.tga:lower()] ~= nil)
    local round = c.round
    local flashed
    local oldFlash = UI().flash
    UI().flash = function(msg, ...) flashed = msg return oldFlash(msg, ...) end
    H.click(v.endTurn)
    local rims, cands = 0, #H.ns.Combat.retainCandidates(c)
    for i = 1, #c.hand do if vis(v.cards[i].rim) and v.cards[i].rimKind == "keep" then rims = rims + 1 end end
    check(cl .. " : « End Turn » ouvre le choix (tour en cours, bouton « Keep none », message, liseré d'or sur chaque carte proposée)",
      v.keepMode and c.round == round and v.endTurn:GetText() == "Keep none" and flashed == "Choose a card to keep in hand."
      and rims == cands and cands > 0, rims .. " / " .. cands)
    local ktt = table.concat(H.hover(v.cards[1]), " | ")
    check(cl .. " : infobulle d'une carte proposée « Click: keep this card in hand… »", ktt:find("keep this card in hand", 1, true), ktt)
    snap("ug-backpack-choix-" .. cl, true)
    H.click(v.cards[1], "RightButton")
    check(cl .. " : clic droit : choix annulé, liserés éteints, « End Turn », tour en cours",
      not v.keepMode and not vis(v.cards[1].rim) and v.endTurn:GetText() == "End Turn" and c.round == round)
    H.click(v.endTurn)
    local keepUid = c.hand[2].uid
    H.click(v.cards[2])
    H.settle()
    local kept = false
    for _, x in ipairs(c.hand) do if x.uid == keepUid then kept = true end end
    local retained = false
    for _, ev in ipairs(H.ns.Controller.lastEvents or {}) do if ev.t == "retained" and ev.card == keepUid then retained = true end end
    check(cl .. " : clic sur une carte proposée : tour fini, elle reste en main (journal « retained »), bouton rendu",
      c.result or (c.round == round + 1 and kept and retained and not v.keepMode and v.endTurn:GetText() == "End Turn"))
    if not c.result then
      round = c.round
      H.click(v.endTurn)
      H.click(v.endTurn) -- « Keep none »
      H.settle()
      local any = false
      for _, ev in ipairs(H.ns.Controller.lastEvents or {}) do if ev.t == "retained" then any = true end end
      check(cl .. " : « Keep none » : tour fini sans carte gardée", c.result or (c.round == round + 1 and not any))
    end
    UI().flash = oldFlash
  end
  -- sans le bibelot : « End Turn » finit le tour tout de suite (aucun choix)
  e, c, v = ugCombat("warrior")
  local r0 = c.round
  H.click(v.endTurn)
  H.settle()
  check("sans Traveler's Backpack : « End Turn » finit le tour, aucun choix", not v.keepMode and (c.result or c.round == r0 + 1))
end

print("UZ  campagne par zones : accueil (sept zones, verrouillées ou à venir, clés par zone), Progress (onglet Zones), bilan (déblocages), sauvegarde v4 reprise, aucune mention de la Ligue")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function inside(r, box)
    return r and r[1] >= box[1] - 0.5 and r[2] >= box[2] - 0.5 and r[3] <= box[3] + 0.5 and r[4] <= box[4] + 0.5
  end
  local function overlaps(a, b)
    return a and b and a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5
  end
  local function fmt(r) return r and ("%.0f,%.0f,%.0f,%.0f"):format(r[1], r[2], r[3], r[4]) or "nil" end
  -- textes visibles sous un cadre (descendants compris)
  local function texts(f, out)
    out = out or {}
    for _, k in ipairs(rawget(f, "_kids") or {}) do
      local tx = rawget(k, "_text")
      if rawget(k, "_kind") == "FontString" and vis(k) and tx ~= nil and tostring(tx) ~= "" then out[#out + 1] = tostring(tx) end
      texts(k, out)
    end
    return out
  end
  local BAD = { "League", "league", "Reputation", "reputation", "Explorers", "Revered", "Exalted" }
  local seen, screens = {}, {}
  local function noLeague(where, extra)
    screens[#screens + 1] = where
    local list = texts(_G.SlayTheDragonFrame)
    for _, t in ipairs(extra or {}) do list[#list + 1] = tostring(t) end
    for _, t in ipairs(list) do
      for _, w in ipairs(BAD) do
        if t:find(w, 1, true) then seen[#seen + 1] = where .. " : " .. t end
      end
    end
  end
  -- contenu de test : une carte de zone du Prêtre (Westfall) et un bibelot de clé (Westfall +1)
  local function addTestContent(ns)
    local d = {}
    for k, v in pairs(ns.Cards.radiance) do d[k] = v end
    d.id, d.name, d.zone, d.level, d.rarity = "uz_zone_card", "Westfall Test Card", "westfall", nil, "rare"
    ns.Cards.uz_zone_card = d
    ns.Relics.uz_key_relic = { id = "uz_key_relic", name = "Test Key Relic", text = "Harness relic (no effect).",
      rarity = "rare", key = { zone = "westfall", level = 1 }, hooks = {} }
  end
  local ZONES = "Westfall, Duskwood, Wetlands, Stranglethorn Vale, Swamp of Sorrows, Burning Steppes, Blackrock Mountain"

  -- 1. Accueil d'un compte neuf -------------------------------------------------------------------
  H.boot(nil)
  H.slash("")
  local ns = H.ns
  local W = ns.Widgets
  addTestContent(ns)
  ns.UI.refresh()
  local st = UI().step
  local names, zopts = {}, {}
  for _, o in ipairs(st.options) do
    if o.group == "zone" then zopts[#zopts + 1] = o; names[#names + 1] = o.label end
  end
  check("accueil : sept zones dans l'ordre de la campagne", table.concat(names, ", ") == ZONES, table.concat(names, ", "))
  local laterOk = true
  -- zone suivante jouable (son fichier de données est écrit, docs/zones.md) : « Locked » pour un compte
  -- neuf ; sinon « Coming later »
  for i = 2, #zopts do
    local o = zopts[i]
    local zid = ns.Zone.ORDER[i]
    if ns.Zone.playable(zid) then
      if not (o.disabled and o.status == "locked" and o.statusLabel == "Locked") then laterOk = false end
    elseif not (o.disabled and o.status == "later" and o.statusLabel == "Coming later" and o.reason == "Coming later.") then
      laterOk = false
    end
  end
  check("accueil : Westfall choisie et jouable, les six autres « Coming later » (ou « Locked » si jouables), grisées",
    zopts[1].selected and not zopts[1].disabled and st.zone == "westfall" and laterOk)
  local scr = UI().current
  local content, panel = R.rect(ns.UI.content), R.rect(scr.panel)
  local bad = {}
  for i, b in ipairs(scr.zoneButtons) do
    local r = R.rect(b)
    if not vis(b) then bad[#bad + 1] = "bouton " .. i .. " caché" end
    if not inside(r, panel) then bad[#bad + 1] = "bouton " .. i .. " hors du panneau " .. fmt(r) end
    if b.label._text ~= zopts[i].label then bad[#bad + 1] = "libellé " .. tostring(b.label._text) end
    local want = i == 1 and "" or (ns.Zone.playable(ns.Zone.ORDER[i]) and "Locked" or "Coming later")
    if (b.status._text or "") ~= want then bad[#bad + 1] = "état " .. tostring(b.status._text) end
    for j = i + 1, #scr.zoneButtons do
      if overlaps(r, R.rect(scr.zoneButtons[j])) then bad[#bad + 1] = ("boutons %d et %d se chevauchent"):format(i, j) end
    end
    for _, k in ipairs(scr.keyButtons) do
      if vis(k) and overlaps(r, R.rect(k)) then bad[#bad + 1] = "bouton " .. i .. " sur une clé" end
    end
    if overlaps(r, R.rect(scr.keyLabel)) or overlaps(r, R.rect(scr.zoneLabel)) or overlaps(r, R.rect(scr.className)) then
      bad[#bad + 1] = "bouton " .. i .. " sur un libellé"
    end
  end
  if not inside(panel, content) then bad[#bad + 1] = "panneau hors de la fenêtre " .. fmt(panel) end
  if overlaps(panel, R.rect(scr.note)) and (scr.note._text or "") ~= "" then bad[#bad + 1] = "panneau sur la note" end
  for _, a in ipairs(scr.affixIcons) do
    if vis(a) and not inside(R.rect(a), panel) then bad[#bad + 1] = "affixe hors du panneau" end
  end
  check("accueil : sept boutons de zone (4 puis 3) dans le panneau, sans chevauchement, nom et état", #bad == 0, table.concat(bad, " ; "))
  H.settle()
  check("accueil : aucun texte tronqué", #W.truncatedNow() == 0, table.concat(W.truncatedNow(), " ; "))
  local tt = H.hover(button("zone:duskwood"))
  check("infobulle d'une zone à venir : nom et « Coming later. »", tt[1] == "Duskwood"
    and table.concat(tt, " | "):find("Coming later.", 1, true) ~= nil, table.concat(tt, " | "))
  H.click(button("zone:duskwood"))
  check("clic sur une zone à venir : raison affichée, rien ne change", UI().err._shown
    and (UI().err._text or "") == "Coming later." and UI().step.zone == "westfall", UI().err._text)
  -- survol : surbrillance seulement (même rectangle), jamais sur une zone grisée
  local wb = button("zone:westfall")
  local r0 = fmt(R.vrect(wb))
  wb:GetScript("OnEnter")(wb)
  for _ = 1, 30 do H.advance(0.02) end
  local r1 = fmt(R.vrect(wb))
  wb:GetScript("OnLeave")(wb)
  for _ = 1, 30 do H.advance(0.02) end
  check("survol d'une zone : pas d'agrandissement ; zones grisées jamais allumées", r0 == r1
    and button("zone:duskwood").active == false and wb.active == true, r0 .. " -> " .. r1)
  H.advance(5) -- message passager effacé avant la planche
  snap("accueil-zones", true)
  noLeague("accueil", H.hover(button("class:priest")))

  -- 2. Zone suivante verrouillée tant que la classe n'a pas gagné la précédente -------------------
  ns.Zones.duskwood.encounters = "westfall" -- Duskwood jouable le temps du test
  ns.UI.refresh()
  local dz = option("zone:duskwood")
  check("Duskwood jouable mais verrouillée : « Locked », raison", dz.disabled and dz.statusLabel == "Locked"
    and dz.reason == "Win Westfall with the Priest to open it." and button("zone:duskwood").status._text == "Locked", dz.reason)
  H.click(button("zone:duskwood"))
  check("clic sur une zone verrouillée : raison affichée", (UI().err._text or "") == "Win Westfall with the Priest to open it.",
    UI().err._text)
  H.advance(5) -- message passager effacé avant les planches

  -- 3. Victoire du Prêtre à Westfall : bilan des déblocages ---------------------------------------
  ns.Controller.makeSeed = function() return SEED end
  clickOption("go")
  local e = EXP()
  check("expédition dans Westfall", e and e.zone == "westfall" and UI().zone._text == "Westfall", UI().zone._text)
  e.stats.cleared, e.stats.elites, e.stats.bosses = 8, 1, 1
  e.result, e.phase = "won", "done"
  ns.UI.refresh()
  st = UI().step
  local function missingIn(text, want)
    local missing = {}
    for _, w in ipairs(want) do if not text:find(w, 1, true) then missing[#missing + 1] = w end end
    return missing
  end
  -- cartes et bibelots révélés : ids, et ce qui sort de la fenêtre ou recouvre un bouton, une barre
  local function revealed()
    scr = UI().current
    local ids, rids, out = {}, {}, {}
    content = R.rect(ns.UI.content)
    for _, c in ipairs(scr.newCards) do
      if vis(c) then
        ids[#ids + 1] = c.cardId
        if not inside(R.rect(c), content) then out[#out + 1] = "carte " .. fmt(R.rect(c)) end
        for _, b in ipairs(scr.buttons) do if vis(b) and overlaps(R.rect(c), R.rect(b)) then out[#out + 1] = "carte sur un bouton" end end
      end
    end
    for _, b in ipairs(scr.newRelics) do
      if vis(b) then
        rids[#rids + 1] = b.info and b.info.id or "?"
        if not inside(R.rect(b), content) then out[#out + 1] = "bibelot " .. fmt(R.rect(b)) end
      end
    end
    local pr = R.rect(scr.panel)
    if not inside(pr, content) then out[#out + 1] = "panneau " .. fmt(pr) end
    for _, b in ipairs(scr.buttons) do if vis(b) and overlaps(pr, R.rect(b)) then out[#out + 1] = "panneau sur un bouton" end end
    local tb = R.rect(scr.text)
    for _, b in ipairs(scr.bars) do if vis(b) and overlaps(tb, R.rect(b)) then out[#out + 1] = "texte sur la barre" end end
    return table.concat(ids, ","), table.concat(rids, ","), out
  end
  local text = st.text or ""
  local missing = missingIn(text, {
    "Westfall won with the Priest: Duskwood is open to the Priest.",
    "New Priest card: Westfall Test Card.",
    "Mythic Keystone +1 unlocked in Westfall.",
    "First Westfall victory on this account:",
    "unlocked for every class.",
  })
  check("bilan : zone suivante, carte de zone, clé suivante, commun du compte annoncés",
    currentKind() == "end" and #missing == 0 and not text:find("New relic", 1, true), table.concat(missing, " / ") .. " <- " .. text)
  local ids, rids, out = revealed()
  check("bilan : carte de zone révélée (vraie carte), dans la fenêtre, hors des boutons",
    ids:find("uz_zone_card", 1, true) and rids == "" and #out == 0, ids .. " / " .. rids .. " / " .. table.concat(out, " ; "))
  H.settle()
  check("bilan : aucun texte tronqué", #W.truncatedNow() == 0, table.concat(W.truncatedNow(), " ; "))
  snap("bilan-campagne", true)
  noLeague("bilan", H.hover(scr.bars[1]))
  -- deuxième victoire, à +1 : bibelot de clé de Westfall +1, clé +2 ; plus de première victoire
  clickOption("ui:new")
  clickOption("zone:westfall")
  clickOption("key:1")
  clickOption("go")
  e = EXP()
  check("deuxième expédition : Westfall +1", e and e.zone == "westfall" and e.key == 1)
  e.stats.cleared, e.stats.elites, e.stats.bosses = 8, 1, 1
  e.result, e.phase = "won", "done"
  ns.UI.refresh()
  text = UI().step.text or ""
  missing = missingIn(text, { "New relic: Test Key Relic.", "Mythic Keystone +2 unlocked in Westfall." })
  check("bilan à +1 : bibelot de clé et clé +2 annoncés, rien d'autre de la campagne", #missing == 0
    and not text:find("won with", 1, true) and not text:find("First Westfall", 1, true) and not text:find("New Priest card", 1, true),
    table.concat(missing, " / ") .. " <- " .. text)
  ids, rids, out = revealed()
  check("bilan à +1 : bibelot de clé révélé (case du bibelot), dans la fenêtre", rids == "uz_key_relic" and #out == 0,
    ids .. " / " .. rids .. " / " .. table.concat(out, " ; "))
  snap("bilan-bibelot-de-cle", true)
  noLeague("bilan à +1")


  -- 4. Écran Progress, onglet « Zones » ------------------------------------------------------------
  clickOption("ui:progress")
  check("Progress : bouton d'onglet « Zones », « Log » (plus de « Reputation and log »)",
    button("ptab:zones").label._text == "Zones" and button("ui:meta").label._text == "Log")
  noLeague("progression (cartes)")
  clickOption("ptab:zones")
  st, scr = UI().step, UI().current
  check("onglet Zones affiché, cartes de niveau masquées", st.tab == "zones" and button("ptab:cards").label._text == "Cards"
    and not vis(scr.cards[1]) and not vis(scr.locks[1]) and not vis(scr.relics[1]))
  local cols, bad2 = scr.zoneCols, {}
  content = R.rect(ns.UI.content)
  local cnames = {}
  for i, col in ipairs(cols) do
    cnames[i] = col.name._text
    for _, o in ipairs({ col.name, col.status, col.keys }) do
      if vis(o) and not inside(R.rect(o), content) then bad2[#bad2 + 1] = "texte " .. i end
    end
    local slot = vis(col.card) and col.card or col.lock
    if not vis(slot) then bad2[#bad2 + 1] = "carte " .. i .. " absente" end
    if not inside(R.rect(slot), content) then bad2[#bad2 + 1] = "carte " .. i .. " " .. fmt(R.rect(slot)) end
    for k, b in ipairs(col.relics) do
      if not vis(b) then bad2[#bad2 + 1] = ("bibelot %d.%d absent"):format(i, k) end
      if not inside(R.rect(b), content) then bad2[#bad2 + 1] = ("bibelot %d.%d hors"):format(i, k) end
      if overlaps(R.rect(b), R.rect(slot)) then bad2[#bad2 + 1] = ("bibelot %d.%d sur la carte"):format(i, k) end
    end
    if i > 1 and overlaps(R.rect(slot), R.rect(vis(cols[i - 1].card) and cols[i - 1].card or cols[i - 1].lock)) then
      bad2[#bad2 + 1] = "cartes " .. (i - 1) .. " et " .. i .. " se chevauchent"
    end
  end
  check("onglet Zones : sept colonnes dans l'ordre, tout dans la fenêtre, sans chevauchement",
    table.concat(cnames, ", ") == ZONES and #bad2 == 0, table.concat(bad2, " ; "))
  check("onglet Zones : Westfall gagnée (clés +0 à +2, meilleure +1), Duskwood ouverte, Wetlands à venir",
    cols[1].status._text == "Won" and (cols[1].keys._text or ""):find("Keys +0 to +2 · best +1", 1, true)
    and cols[2].status._text == "Open" and cols[3].status._text == "Coming later" and (cols[3].keys._text or "") == "",
    tostring(cols[1].status._text) .. " / " .. tostring(cols[1].keys._text) .. " / " .. tostring(cols[2].status._text))
  check("carte de zone de Westfall débloquée (vraie carte)", vis(cols[1].card) and cols[1].card.cardId == "uz_zone_card"
    and not vis(cols[1].lock))
  local ltt = H.hover(cols[2].lock)
  check("carte de zone verrouillée : dos de carte, infobulle = « Win Duskwood to unlock » seule", vis(cols[2].lock)
    and #ltt == 1 and ltt[1] == "Win Duskwood to unlock", table.concat(ltt, " | "))
  local k1 = H.hover(cols[1].relics[1])
  local k3 = H.hover(cols[1].relics[2])
  check("bibelots de clé : +1 débloqué (infobulle du bibelot), +3 verrouillé (« Win Westfall +3 to unlock » seule)",
    k1[1] == "Test Key Relic" and #k3 == 1 and k3[1] == "Win Westfall +3 to unlock"
    and cols[1].relicLabels[1]._text == "+1" and cols[1].relicLabels[3]._text == "+5",
    table.concat(k1, " | ") .. " / " .. table.concat(k3, " | "))
  H.settle()
  check("onglet Zones : aucun texte tronqué", #W.truncatedNow() == 0, table.concat(W.truncatedNow(), " ; "))
  snap("progression-zones", true)
  noLeague("progression (zones)", ltt)
  clickOption("ptab:cards")
  scr = UI().current
  check("retour à l'onglet Cards : cartes de niveau visibles, colonnes de zones masquées",
    UI().step.tab == "cards" and (vis(scr.cards[1]) or vis(scr.locks[1])) and not vis(scr.zoneCols[1].name)
    and not vis(scr.zoneCols[1].card) and not vis(scr.zoneCols[1].lock))
  clickOption("ui:meta")
  check("journal des expéditions", currentKind() == "meta")
  noLeague("journal", H.hover(UI().current.bars[1]))
  clickOption("ui:progress")
  clickOption("ui:back")
  clickOption("ui:new")

  -- 5. Accueil après la victoire : Duskwood ouverte pour le Prêtre seulement, clés par zone --------
  check("accueil : Duskwood ouverte au Prêtre", currentKind() == "start" and not option("zone:duskwood").disabled
    and option("zone:duskwood").text == "Open to the Priest." and option("zone:westfall").text == "Won with the Priest, best key +1.",
    tostring(option("zone:duskwood").text))
  check("zone gardée : la dernière choisie (Westfall)", UI().step.zone == "westfall")
  clickOption("zone:duskwood")
  check("clic sur Duskwood : choisie", UI().step.zone == "duskwood" and option("zone:duskwood").selected)
  check("Duskwood : clé +0 seulement", UI().step.keyMax == 0 and option("key:1").disabled
    and (option("key:1").reason or ""):find("in Duskwood", 1, true), option("key:1").reason)
  clickOption("zone:westfall")
  check("Westfall : clé +2 ouverte, choisie par défaut", UI().step.zone == "westfall" and UI().step.keyMax == 2
    and option("key:2").selected and not option("key:2").disabled)
  clickOption("class:mage")
  local md = option("zone:duskwood")
  check("Mage : Duskwood verrouillée, Westfall à +0", md.disabled and md.statusLabel == "Locked"
    and md.reason == "Win Westfall with the Mage to open it." and UI().step.zone == "westfall" and UI().step.keyMax == 0,
    md.reason)
  noLeague("accueil (Mage)")
  ns.Zones.duskwood.encounters = nil

  -- 6. Sauvegarde v4 avec une expédition en cours : reprise dans Westfall --------------------------
  local tmp = ns.Save.new()
  local cur = assert(ns.Save.start(tmp, { seed = 7, class = "priest" }))
  local id = cur.map.start[1]
  cur.map.nodes[id].kind = "combat"
  assert(ns.Expedition.act(cur, { "path", id }))
  cur.combat.events = {}
  cur.version, cur.zone, cur.unlock = 4, nil, { level = 1, league = 3 }
  local v4 = { version = 4, meta = { league = 1500, runs = 2, flags = {}, classes = {
    priest = { xp = 150, runs = 2, wins = 1, keyMax = 1, bestKey = 0 } } }, current = cur, journal = {} }
  H.boot(deepcopy(v4))
  H.slash("")
  local db = _G.SlayTheDragonDB
  check("sauvegarde v4 reprise : version 5 (expédition 6), rien en quarantaine, expédition dans Westfall", db.version == 5
    and #db.quarantine == 0 and EXP() and EXP().zone == "westfall" and EXP().version == ns.Expedition.VERSION and db.meta.league == nil
    and db.meta.zones.westfall == true and db.meta.classes.priest.zones.westfall.keyMax == 1)
  check("sauvegarde v4 reprise : combat en cours affiché, zone dans le bandeau", currentKind() == "combat"
    and UI().zone._text == "Westfall", tostring(currentKind()) .. " / " .. tostring(UI().zone._text))
  H.ns.Controller.act({ "endTurn" })
  check("sauvegarde v4 reprise : le combat continue", EXP() ~= nil and (EXP().phase == "combat" or EXP().phase == "reward"))
  noLeague("reprise v4")

  check(("aucune mention de la Ligue ni de la réputation à l'écran (%d écrans)"):format(#screens), #seen == 0,
    table.concat(seen, " ; "))
end

print("UW  Westfall réelle : décors peints couleur blé portés par la zone, Elwynn retirée, Defias Highwayman, gens de la Marche dans les rencontres")
do
  local ns = H.boot(nil)
  H.slash("")
  local Art, Sc, Z = ns.Art, ns.Scene, ns.Zones.westfall
  local WF = { road = "westfall_road", hill = "westfall_hill", camp = "westfall_camp", shop = "westfall_shop",
    night = "westfall_night" }
  local function painted(key) local g = Sc.paints[key] return g and g[1] and g[1]._shown end
  local function lum(hex) local c = Art.hex(hex) return 0.3 * c[1] + 0.59 * c[2] + 0.11 * c[3] end

  -- 1. Décors : portés par la zone, peints, sans illustration ; communs = ceux de Westfall
  local zoneOk = type(Z.scenes) == "table"
  for common, key in pairs(WF) do
    local e = Art.scenes[key]
    if not (Z.scenes and Z.scenes[common] == key and e and not e.art and e.paint == key and Art.paintings[key]
      and Art.scenes[common] == e) then zoneOk = false end
  end
  check("Westfall porte ses cinq décors (champ scenes de la zone), peints, sans illustration ; décors communs = les siens",
    zoneOk)
  check("accueil : la route peinte, construite à son premier affichage ; les autres pas encore",
    Sc.scene == "road" and painted("westfall_road") and Sc.paints.westfall_camp == nil and Sc.paints.westfall_night == nil)
  local pal, night = Art.palettes.westfall, Art.palettes.westfall_night
  local sky, field = Art.hex(pal.sky[1]), Art.hex(pal.fieldsNear[1])
  check("palette : ciel bleu pâle (bleu > rouge), blé jaune-ocre (rouge > vert > bleu)",
    sky[3] > sky[1] and field[1] > field[2] and field[2] > field[3] and lum(pal.sky[3]) > 0.75)
  check("nuit : même décor (mêmes plans, mêmes accessoires), assombri", Art.paintings.westfall_night.props
    == Art.paintings.westfall_road.props and night.night and lum(night.sky[1]) < lum(pal.sky[1]) * 0.3
    and lum(night.fieldsNear[1]) < lum(pal.fieldsNear[1]) * 0.5)

  -- couches : sous l'illustration (BORDER 0), sous-niveaux valides, nombre de régions raisonnable
  local lvOk, counts = true, {}
  for common, key in pairs(WF) do
    Sc.set({ scene = key, board = true })
    local g = Sc.paints[key]
    counts[#counts + 1] = key .. " " .. #g
    if #g < 100 or #g > 900 then lvOk = false end
    for _, t in ipairs(g) do
      local layer, sub = rawget(t, "_layer"), rawget(t, "_sub") or 0
      if not ((layer == "BACKGROUND" and sub >= -8 and sub <= 7) or (layer == "BORDER" and sub >= -8 and sub < 0)) then
        lvOk = false
      end
    end
    check("décor " .. key .. " : seul paysage affiché, aucune illustration", painted(key) and not Sc.art._shown
      and not painted(key == "westfall_road" and "westfall_night" or "westfall_road"))
  end
  table.sort(counts)
  check("paysages peints : couches sous l'illustration, sous-niveaux du client, 100 à 900 régions",
    lvOk, table.concat(counts, ", "))
  -- dégradés doux et formes fondues, pas seulement des aplats
  local grad, soft, rot = 0, 0, 0
  for _, t in ipairs(Sc.paints.westfall_road) do
    local calls = rawget(t, "_calls")
    if calls.SetGradient then grad = grad + 1 end
    if rawget(t, "_texture") == Sc.SHADOW then soft = soft + 1 end
    if calls.SetRotation then rot = rot + 1 end
  end
  check("route : dégradés (ciel, champs), taches fondues (nuages, brume, halo), formes tournées (ailes, rangs)",
    grad >= 10 and soft >= 15 and rot >= 40, grad .. " / " .. soft .. " / " .. rot)
  if SNAP then
    for _, key in pairs(WF) do
      Sc.set({ scene = key, board = true })
      Render.svg(H, Sc.decor, SNAP .. "/decor-" .. key .. ".svg", key)
    end
  end

  -- 2. Elwynn retirée (fond, liste d'illustrations, fichier, fabrication)
  local f = io.open(root .. "/Media/Backgrounds/elwynn.tga", "rb")
  if f then f:close() end
  local py = io.open(root .. "/tools/build_backgrounds.py"):read("*a")
  local block = py:sub(py:find("BACKGROUNDS = {", 1, true), py:find("OTHERS = {", 1, true))
  local artRef = false
  for _, e in pairs(Art.scenes) do if e.art == "elwynn" then artRef = true end end
  check("Elwynn retirée : ni fond, ni illustration, ni fichier, ni fabrication", Art.backgrounds.elwynn == nil
    and Art.illustrations.elwynn == nil and f == nil and not block:find('"elwynn"', 1, true) and not artRef)

  -- 3. Defias Highwayman : nom et modèle, mêmes chiffres, même id
  local E = ns.Enemies
  check("Defias Highwayman : id bandit, nom, créature 122, affichages 2342 / 2343", E.bandit.name == "Defias Highwayman"
    and Art.enemies.bandit.creature == 122 and Art.enemies.bandit.display[1] == 2342 and Art.enemies.bandit.display[2] == 2343)
  local function ser(v, skip)
    if type(v) ~= "table" then
      return type(v) == "string" and string.format("%q", v) or (type(v) == "function" and "fn" or tostring(v))
    end
    local keys = {}
    for k in pairs(v) do if not skip[k] then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k], skip) end
    return "{" .. table.concat(out, ",") .. "}"
  end
  local function djb(s) local h = 5381 for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end return h end
  local zoneE = {}
  for _, id in ipairs({ "gnoll", "mystic", "murloc", "bandit", "sorcerer", "harvest_golem", "rhahkzor",
    "defias_henchman", "vancleef" }) do zoneE[id] = E[id] end
  local sig = ser(zoneE, { name = true }) .. ser({ westfall = ns.Encounters.westfall }, { name = true })
  check("ennemis et groupes de Westfall : chiffres inchangés (empreinte d'avant le 13/11/2026)",
    djb(sig) == 3796836427 and #sig == 2741, djb(sig) .. " " .. #sig)
  local stale = {}
  for id, e in pairs(E) do if e.name == "Defias Bandit" then stale[#stale + 1] = id end end
  check("plus aucun « Defias Bandit »", #stale == 0, table.concat(stale, ", "))

  -- 4. Rencontres : gens de la Marche (nom, modèle), règles inchangées
  local WANT = {
    defias_caravan = { "Farmer Furlbrow", "farmer_furlbrow", 237 },
    moonbrook_refugees = { "Verna Furlbrow", "verna_furlbrow", 238 },
    coast_murlocs = { "Scout Galiaan", "scout_galiaan", 878 },
    jangolode_prospector = { "Thor, gryphon master", "thor", 523 },
    herbalist = { "Innkeeper Heather", "innkeeper_heather", 8931 },
    lighthouse_keeper = { "Captain Grayson", "captain_grayson", 392 },
    goblin_peddler = { "Defias Profiteer", "defias_profiteer", 1669 },
    harvest_watcher = { "Farmer Saldean", "farmer_saldean", 233 },
    saldean_farm = { "Salma Saldean", "salma_saldean", 235 },
    sentinel_hill = { "Gryan Stoutmantle", "gryan_stoutmantle", 234 },
    tobin_defias = { "Tobin, Defias cutthroat", "tobin_defias", 121 },
  }
  local bad = {}
  for id, w in pairs(WANT) do
    local ev = ns.Events[id]
    local a = ev and Art.npcs[ev.npc]
    if not (ev and ev.speaker == w[1] and ev.npc == w[2] and a and a.creature == w[3]) then
      bad[#bad + 1] = id .. " : " .. tostring(ev and ev.speaker) .. " / " .. tostring(ev and ev.npc)
    end
  end
  check("personnages : gens de la Marche, nom et créature", #bad == 0, table.concat(bad, "; "))
  -- créatures d'ailleurs retirées (Brog Hamfist, Lee Brown, Prospecteur Stormpike, Ma Stonefield,
  -- Alma Jainrose, Dockmaster Baren, Zixil, Deek Fizzlebizz, Vide-gousset défias, Defias Bandit,
  -- Sorcier-voleur défias) et leurs affichages
  local OLD_C = { [151] = 1, [1651] = 1, [1356] = 1, [244] = 1, [812] = 1, [381] = 1, [3537] = 1, [3290] = 1,
    [94] = 1, [116] = 1, [474] = 1 }
  local OLD_D = { [1292] = 1, [3272] = 1, [3330] = 1, [1745] = 1, [3360] = 1, [7133] = 1, [1832] = 1, [2361] = 1,
    [2362] = 1, [2357] = 1, [2358] = 1, [2359] = 1, [2360] = 1 }
  local left = {}
  local function scan(where, a)
    if a.creature and OLD_C[a.creature] then left[#left + 1] = where .. " créature " .. a.creature end
    local d = type(a.display) == "table" and a.display or { a.display }
    for _, x in ipairs(d) do if OLD_D[x] then left[#left + 1] = where .. " affichage " .. x end end
  end
  for id, a in pairs(Art.npcs) do scan("npc:" .. id, a) end
  for id, a in pairs(Art.enemies) do scan(id, a) end
  -- (seul repli d'apparence gardé hors de la Marche : l'affichage 3594, un nain, en dernier pour Thor)
  check("plus aucun personnage d'Elwynn, de Forgefer, de Redridge ni de Hillsbrad (créatures et affichages retirés)",
    #left == 0 and Art.npcs.thor.display[#Art.npcs.thor.display] == 3594, table.concat(left, ", "))
  local npcOk = true
  for _, ev in pairs(ns.Events) do if ev.npc and not Art.npcs[ev.npc] then npcOk = false end end
  check("chaque personnage de rencontre est déclaré dans Art.npcs", npcOk)
  local OLD_SIG = {
    coast_murlocs = { 2586618650, 341 }, defias_caravan = { 3107617194, 344 }, gnoll_raiders = { 2439352936, 269 },
    goblin_peddler = { 3243603999, 408 }, harvest_watcher = { 2340963395, 335 }, herbalist = { 1500083630, 413 },
    jangolode_prospector = { 385269940, 413 }, lighthouse_keeper = { 1450562328, 327 },
    moonbrook_refugees = { 1182098161, 465 }, saldean_farm = { 3917480906, 363 }, scarecrow_field = { 3541117412, 290 },
    sentinel_hill = { 13829917, 406 }, tobin_defias = { 580772835, 329 }, tobin_scout = { 1619478947, 259 },
    tobin_thief = { 1794341274, 286 },
  }
  local TEXTS = { label = true, result = true, text = true, after = true, winText = true, loseText = true,
    name = true, speaker = true, npc = true, scene = true }
  local changed = {}
  for id, s0 in pairs(OLD_SIG) do
    local s = ns.Events[id] and ser(ns.Events[id], TEXTS) or ""
    if djb(s) ~= s0[1] or #s ~= s0[2] then changed[#changed + 1] = id end
  end
  check("rencontres : choix, conditions, issues et effets inchangés (empreinte d'avant le 13/11/2026)",
    #changed == 0, table.concat(changed, ", "))
  -- textes : plus de personnages ni de lieux d'ailleurs
  local OLD_WORDS = { "Old Hank", "Hank", "Grit", "Mother Hanna", "Hanna", "Aunt Mirelle", "Mirelle", "Keeper Alden",
    "Alden", "Grizzle", "Bertil", "wagon driver", "Elwynn", "Goldshire", "Northshire", "Crystal Lake", "Redridge",
    "Lakeshire", "goblin", "gnome", "Defias Bandit" }
  local found = {}
  local function words(where, s)
    if type(s) ~= "string" then return end
    for _, w in ipairs(OLD_WORDS) do
      if s:find("%f[%a]" .. w .. "%f[%A]") then found[#found + 1] = where .. " : " .. w end
    end
  end
  local function walk(where, v)
    if type(v) == "table" then for k, x in pairs(v) do walk(where .. "." .. tostring(k), x) end else words(where, v) end
  end
  for id, ev in pairs(ns.Events) do walk(id, ev) end
  for id, e in pairs(E) do words(id, e.name) end
  check("textes des rencontres et noms d'ennemis : aucun personnage ni lieu hors de la Marche", #found == 0,
    table.concat(found, "; "))

  -- 5. En expédition : le décor de la zone partout (combat, feu de camp, marchand, rencontres)
  local run = freshRun(SEED, "combat")
  check("combat : route de Westfall", H.ns.Scene.scene == "westfall_road" and run.zone == "westfall", H.ns.Scene.scene)
  freshRun(SEED + 3, "campfire")
  check("feu de camp : la route de Westfall de nuit", H.ns.Scene.scene == "westfall_night", H.ns.Scene.scene)
  freshRun(SEED + 2, "merchant")
  check("marchand : décor du marchand de Westfall", H.ns.Scene.scene == "westfall_shop", H.ns.Scene.scene)
  local function forcedEvent(id, seed)
    H.boot(nil)
    H.slash("")
    H.ns.Controller.makeSeed = function() return seed end
    clickOption("go")
    local e = EXP()
    local node = e.map.start[1]
    e.map.nodes[node].kind = "event"
    for k, ev in pairs(H.ns.Events) do if k == id then ev.weight = 1e6 end end
    clickOption("path:" .. node)
    return e
  end
  local e1 = forcedEvent("defias_caravan", SEED + 4)
  local scr = UI().current
  check("rencontre de la route : Farmer Furlbrow, son modèle, la route de Westfall", e1.event.id == "defias_caravan"
    and H.ns.Scene.scene == "westfall_road" and scr.npc and scr.npc.name and scr.npc.name._text == "Farmer Furlbrow"
    and scr.npc.model._model == "creature:237", tostring(e1.event.id) .. " " .. tostring(H.ns.Scene.scene)
    .. " " .. tostring(scr.npc and scr.npc.model._model))
  snap("rencontre-furlbrow", true)
  local e2 = forcedEvent("sentinel_hill", SEED + 4)
  check("rencontre de la colline : Sentinel Hill peinte", e2.event.id == "sentinel_hill"
    and H.ns.Scene.scene == "westfall_hill", tostring(e2.event.id) .. " " .. tostring(H.ns.Scene.scene))
  snap("rencontre-sentinel-hill", true)
end

print("UE  cartes épiques : choix au départ (puis bibelot), règle en jeu parmi les Powers, carte sans coût, remplacement après une élite, variantes, marchand, crans à 10, Progress (Zones), bilan")
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function inside(r, box)
    return r and r[1] >= box[1] - 0.5 and r[2] >= box[2] - 0.5 and r[3] <= box[3] + 0.5 and r[4] <= box[4] + 0.5
  end
  local function overlaps(a, b)
    return a and b and a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5
  end
  local function tex(t) return (rawget(t, "_texture") or ""):match("([%w_]+)%.tga$") or "" end
  -- contenu de test (Prêtre) : trois épiques (Westfall, Duskwood, Wetlands), la première transforme Smite en
  -- une variante ; une épique du Warrior qui porte la Rage à 10 ; aucune carte réelle
  local function addTestContent(ns)
    local C0 = ns.Cards
    C0.ue_epic_a = { id = "ue_epic_a", class = "priest", zone = "westfall", rarity = "epic", name = "Test Epic",
      type = "power", path = "holy", school = "holy", effects = {}, text = "Epic.\nAttacks deal 1 more.",
      transforms = { smite = "ue_variant" }, up = { text = "Epic.\nAttacks deal 2 more." } }
    C0.ue_epic_b = { id = "ue_epic_b", class = "priest", zone = "duskwood", rarity = "epic", name = "Second Epic",
      type = "power", path = "shadow", school = "shadow", effects = {}, text = "Epic.\nStart of turn: draw 1.",
      up = { text = "Epic.\nStart of turn: draw 2." } }
    C0.ue_epic_c = { id = "ue_epic_c", class = "priest", zone = "wetlands", rarity = "epic", name = "Third Epic",
      type = "power", path = "discipline", effects = {}, text = "Epic.\nStart of turn: gain 5 Absorb.",
      up = { text = "Epic.\nStart of turn: gain 8 Absorb." } }
    C0.ue_variant = { id = "ue_variant", class = "priest", variant = true, rarity = "basic", name = "Test Smite",
      cost = 1, type = "attack", school = "holy", path = "start", target = "enemy", effects = { { "damage", 10 } },
      text = "Deal 10.", up = { effects = { { "damage", 13 } }, text = "Deal 13." } }
    C0.ue_epic_w = { id = "ue_epic_w", class = "warrior", zone = "westfall", rarity = "epic", name = "Test Fury",
      type = "power", path = "fury", effects = {}, text = "Epic.\nRage goes up to 10.",
      deckHooks = { resCap = function(c, src, v) return 10 end } }
  end
  local function epicFrame(card)
    return tex(card.ribbon) == "card_ribbon_epic" and tex(card.costTab) == "card_cost_epic"
      and vis(card.epicGlow) and vis(card.gem) and tex(card.gem) == "gem_epic"
  end
  -- carte épique sans coût : languette violette marquée « Epic », chiffre caché, plaque du bas « Epic »
  local function noCost(card)
    return vis(card.costTab) and not vis(card.cost) and vis(card.epicMark) and card.epicMark._text == "Epic"
      and (card.plateText._text or ""):find("Epic", 1, true) ~= nil
      and not (card.plateText._text or ""):find("Power", 1, true)
  end
  local function plainFrame(card)
    return tex(card.ribbon) == "card_ribbon" and tex(card.costTab) == "card_cost" and not vis(card.epicGlow)
      and not vis(card.epicMark) and vis(card.cost)
  end
  local content
  local W

  -- 0. Départ : l'épique de l'expédition au choix (trois débloquées), puis le bibelot au choix ----------
  H.boot(nil)
  H.slash("")
  local ns = H.ns
  W = ns.Widgets
  addTestContent(ns)
  ns.Controller.makeSeed = function() return SEED end
  local db = _G.SlayTheDragonDB
  for _, z in ipairs({ "westfall", "duskwood", "wetlands" }) do
    ns.Meta.zoneState(db.meta, "priest", z).won = true
    db.meta.zones[z] = true -- zone 3 gagnée par le compte : bibelot au choix au départ
  end
  clickOption("go")
  local st, scr = UI().step, UI().current
  local e = EXP()
  check("départ : choix « Epic » d'abord (trois épiques débloquées), le bibelot ensuite", currentKind() == "startEpic"
    and e.phase == "start" and #e.startEpics == 3 and e.startRelics ~= nil and option("pickEpic:3") and option("skipEpic")
    and not option("startRelic:1"), currentKind())
  local shown, okFrames, okCost = 0, true, true
  for _, card in ipairs(scr.cards) do
    if vis(card) then
      shown = shown + 1
      if not epicFrame(card) then okFrames = false end
      if not noCost(card) then okCost = false end
    end
  end
  check("départ : trois cartes au cadre violet, sans coût (languette « Epic »), plaque « Epic »", shown == 3
    and okFrames and okCost)
  content = R.rect(ns.UI.content)
  local hr, sr = R.rect(scr.hint), R.rect(scr.skip)
  check("départ : titre « Epic card », consigne, « Skip » à la place du départ (pas de « Back on the road »)",
    vis(scr.epicTitle) and scr.epicTitle._text == "Epic card" and vis(scr.skip) and button("skipEpic") == scr.skip
    and scr.hint._text == "Choose the epic card of this expedition, or none." and not vis(scr.leave)
    and not overlaps(hr, sr) and inside(sr, content) and inside(hr, content)
    and not overlaps(R.rect(scr.epicTitle), R.rect(scr.cards[1].ribbon)), tostring(scr.hint._text))
  local function plainText(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  local ctt = plainText(table.concat(H.hover(scr.cards[1]), " | "))
  check("départ : infobulle de la carte (Epic : en jeu dès le début de chaque combat, une par expédition)",
    ctt:find("in play from the start of each combat", 1, true) and ctt:find("One epic card per expedition", 1, true), ctt)
  H.settle()
  check("départ : aucun texte tronqué", #W.truncatedNow() == 0, table.concat(W.truncatedNow(), " ; "))
  snap("ue-depart-epique", true)
  local ia
  for i, id in ipairs(e.startEpics) do if id == "ue_epic_a" then ia = i end end
  H.click(scr.cards[ia])
  H.settle()
  check("départ : épique prise sans confirmation, puis le bibelot au choix", e.deck[ns.Expedition.epicIndex(e)].id == "ue_epic_a"
    and currentKind() == "startRelic" and option("startRelic:1") ~= nil and not ns.UI.epicConfirm:IsShown(), currentKind())
  clickOption("skipStartRelic")
  check("départ : puis la carte", currentKind() == "map", currentKind())

  -- 1. Combat : l'épique est une règle en jeu (premier des Powers, liseré violet), hors de la main ----------
  local sm = e.deck[1] -- Smite améliorée : la variante hérite de l'amélioration
  sm.up = true
  local id = e.map.start[1]
  e.map.nodes[id].kind = "elite"
  clickOption("path:" .. id)
  H.settle()
  local v = V()
  v:Render(true)
  local c = EXP().combat
  local inHand, plainCard, variantInDeck = false, nil, nil
  for i, inst in ipairs(c.hand) do
    if inst.id == "ue_epic_a" then inHand = true elseif not plainCard then plainCard = v.cards[i] end
  end
  for _, pile in ipairs({ c.hand, c.draw }) do
    for _, inst in ipairs(pile) do
      if inst.id == "ue_epic_a" then inHand = true end
      if inst.id == "smite" then variantInDeck = false end
      if inst.id == "ue_variant" and variantInDeck == nil then variantInDeck = true end
    end
  end
  check("combat : l'épique n'est dans aucune pile, main de 5, c.epic posé", not inHand and #c.hand == 5
    and c.epic and c.epic.id == "ue_epic_a")
  check("combat : carte ordinaire au cadre habituel (coût, aura cachée)", plainCard and plainFrame(plainCard))
  check("combat : Smite transformé en sa variante tant que l'épique est dans le deck", variantInDeck == true)
  local tokens = {}
  for _, t in ipairs(v.playerSt.tokens) do if vis(t) and t.info and t.info.power then tokens[#tokens + 1] = t end end
  local etok = tokens[1]
  local rimOk = etok and etok.medal.ring._calls.SetVertexColor
  local er = ns.Art.rarityRim.epic
  check("combat : l'épique est le premier des Powers en jeu, liseré violet", etok and etok.info.power.id == "ue_epic_a"
    and rimOk and math.abs(rimOk[1] - er[1]) < 1e-6 and math.abs(rimOk[2] - er[2]) < 1e-6)
  local ett = etok and plainText(table.concat(H.hover(etok), " | ")) or ""
  check("combat : infobulle complète (nom, texte, Epic, une par expédition, transformation)",
    ett:find("Test Epic", 1, true) and ett:find("Attacks deal 1 more.", 1, true)
    and ett:find("in play from the start of each combat", 1, true) and ett:find("One epic card per expedition", 1, true)
    and ett:find("While in the deck: Smite becomes", 1, true) and not ett:find("Power", 1, true), ett)
  -- un pouvoir joué se range après l'épique
  c.player.powers[#c.player.powers + 1] = { uid = 9901, id = "shadowform", up = false }
  v:Render(true)
  tokens = {}
  for _, t in ipairs(v.playerSt.tokens) do if vis(t) and t.info and t.info.power then tokens[#tokens + 1] = t end end
  check("combat : un Power joué vient après l'épique", #tokens == 2 and tokens[1].info.power.id == "ue_epic_a"
    and tokens[2].info.power.id == "shadowform")
  H.settle()
  snap("ue-combat-epique", true)
  c.player.powers[#c.player.powers] = nil
  v:Render(true)
  -- deck : l'épique en tête, sans coût
  UI().toggleDeckView("deck")
  local dv = UI().deckView
  check("deck : l'épique en tête, cadre violet, sans coût", dv.list[1] and dv.list[1].id == "ue_epic_a"
    and epicFrame(dv.cards[1]) and noCost(dv.cards[1]))
  H.settle()
  snap("ue-carte-epique", true)
  dv:Close()

  -- 2. Victoire sur l'élite : une épique de remplacement, avant les cartes ------------------------------
  for _, en in ipairs(c.enemies) do en.hp = 1 end
  local att
  for i, inst in ipairs(c.hand) do if ns.Card.def(inst).type == "attack" then att = i break end end
  if not att then
    c.hand[1] = ns.Card.new("ue_variant", false, 990)
    att = 1
  end
  local alive = C().aliveTargets()[1]
  ns.Controller.play(att, alive)
  for _ = 1, 5 do
    if C().over() then break end
    local t = C().aliveTargets()[1]
    if not t then break end
    c.hand[#c.hand + 1] = ns.Card.new("ue_variant", false, 991 + #c.hand)
    c.player.mana = 3
    ns.Controller.play(#c.hand, t)
  end
  H.settle()
  check("élite vaincue", C().over() == "won", C().over())
  H.click(V().banner.button)
  H.settle()
  -- l'épique du deck est améliorée : le remplacement le dira
  EXP().deck[ns.Expedition.epicIndex(EXP())].up = true
  ns.UI.refresh()
  st = UI().step
  scr = UI().current
  local r = EXP().reward
  check("récompense d'élite : UNE épique de remplacement (hors celle du deck), avant les cartes",
    currentKind() == "reward" and st.epicMode and r.epics and #r.epics == 1 and r.epics[1] ~= "ue_epic_a"
    and option("pickEpic:1") and option("skipEpic") and not option("pickCard:1"), r.epics and table.concat(r.epics, ","))
  local shownEpic, okF = 0, true
  for _, card in ipairs(scr.cards) do
    if vis(card) then
      shownEpic = shownEpic + 1
      if not epicFrame(card) or not noCost(card) then okF = false end
    end
  end
  check("remplacement proposé : carte centrée au cadre violet, titre « Epic card », consigne, « Skip »", shownEpic == 1
    and okF and vis(scr.epicTitle) and scr.epicTitle._text == "Epic card" and vis(scr.skip) and vis(scr.leave)
    and scr.hint._text == "Replace your epic card, or skip it." and button("skipEpic") == scr.skip
    and math.abs(scr.cards[1].cx - 552) < 0.5, tostring(scr.hint._text))
  hr, sr = R.rect(scr.hint), R.rect(scr.skip)
  check("remplacement proposé : consigne, « Skip » et départ sans chevauchement, dans la fenêtre",
    not overlaps(hr, sr) and not overlaps(sr, R.rect(scr.leave)) and inside(sr, content)
    and inside(R.rect(scr.epicTitle), content) and not overlaps(R.rect(scr.epicTitle), R.rect(scr.cards[1].ribbon)))
  H.settle()
  snap("ue-choix-epic", true)

  -- 3. Remplacement : confirmation (« The upgrade is lost. »), « Keep » puis « Replace » -----------------
  local before = #EXP().deck
  H.click(scr.cards[1])
  local ec = UI().epicConfirm
  local newId = r.epics[1]
  local newName = ns.Cards[newId].name
  check("prendre une autre épique : confirmation, l'action attend", ec:IsShown() and #EXP().deck == before
    and ns.Expedition.epicIndex(EXP()) and EXP().deck[ns.Expedition.epicIndex(EXP())].id == "ue_epic_a")
  check("confirmation : « Replace Test Epic+ with " .. newName .. "? » / « Keep Test Epic+ »",
    ec.question._text == "Replace Test Epic+ with " .. newName .. "?" and ec.keep.label._text == "Keep Test Epic+"
    and ec.replace.label._text == "Replace", tostring(ec.question._text) .. " / " .. tostring(ec.keep.label._text))
  check("confirmation : épique améliorée = « The upgrade is lost. » sous « Leaves the deck »", vis(ec.lost)
    and ec.lost._text == "The upgrade is lost." and R.rect(ec.lost)[4] <= R.rect(ec.oldLabel)[2] + 0.5)
  check("confirmation : les deux cartes côte à côte (ancienne à gauche, nouvelle à droite), cadre violet",
    vis(ec.cards[1]) and vis(ec.cards[2]) and ec.cards[1].cardId == "ue_epic_a" and ec.cards[2].cardId == newId
    and epicFrame(ec.cards[1]) and epicFrame(ec.cards[2]) and R.rect(ec.cards[1])[3] < R.rect(ec.cards[2])[1]
    and not overlaps(R.rect(ec.cards[1]), R.rect(ec.panel.title)))
  local inPanel = true
  for _, o in ipairs({ ec.cards[1], ec.cards[2], ec.replace, ec.keep, ec.question, ec.note, ec.oldLabel, ec.newLabel, ec.lost }) do
    if not inside(R.rect(o), R.rect(ec.panel)) then inPanel = false end
  end
  check("confirmation : tout dans le panneau, boutons sous les cartes et les libellés", inPanel
    and not overlaps(R.rect(ec.replace), R.rect(ec.oldLabel)) and not overlaps(R.rect(ec.keep), R.rect(ec.newLabel))
    and not overlaps(R.rect(ec.replace), R.rect(ec.lost)) and not overlaps(R.rect(ec.keep), R.rect(ec.lost))
    and not overlaps(R.rect(ec.replace), R.rect(ec.cards[1])) and not overlaps(R.rect(ec.keep), R.rect(ec.cards[2])))
  -- survol : halo seulement (ni levée, ni aperçu à taille réelle)
  local r0 = R.vrect(ec.cards[2])
  ec.cards[2]:GetScript("OnEnter")(ec.cards[2])
  for _ = 1, 30 do H.advance(0.02) end
  local r1 = R.vrect(ec.cards[2])
  local prev = W.preview and vis(W.preview)
  ec.cards[2]:GetScript("OnLeave")(ec.cards[2])
  for _ = 1, 30 do H.advance(0.02) end
  check("confirmation : survol sans zoom ni aperçu", r0 and r1 and math.abs(r0[1] - r1[1]) < 0.01
    and math.abs(r0[4] - r1[4]) < 0.01 and not prev)
  H.settle()
  snap("ue-remplacement", true)
  H.click(ec.keep)
  check("« Keep » : rien ne change, le choix reste", not ec:IsShown() and #EXP().deck == before
    and EXP().deck[ns.Expedition.epicIndex(EXP())].id == "ue_epic_a" and UI().step.epicMode)
  H.click(UI().current.cards[1])
  H.click(ec.replace)
  local ep = ns.Expedition.epicIndex(EXP())
  check("« Replace » : la nouvelle épique remplace l'ancienne (non améliorée), les cartes ordinaires suivent",
    not ec:IsShown() and #EXP().deck == before and EXP().deck[ep].id == newId and EXP().deck[ep].up == false
    and EXP().stats.epicReplaced == 1 and not UI().step.epicMode and option("pickCard:1") ~= nil)
  -- une épique non améliorée remplacée : pas de ligne « The upgrade is lost. »
  ns.UI.epicConfirm:Open("pickCard:1", { old = { id = newId, up = false }, new = { id = "ue_epic_a", up = false } })
  check("confirmation d'une épique non améliorée : pas de « The upgrade is lost. »", not vis(ec.lost))
  ns.UI.epicConfirm.pending = nil
  ns.UI.epicConfirm:Close()
  -- l'épique partie : plus de transformation (panneau du deck)
  UI().toggleDeckView("deck")
  dv = UI().deckView
  local hasSmite, hasVariant = false, false
  for _, inst in ipairs(dv.list) do
    if inst.id == "smite" then hasSmite = true end
    if inst.id == "ue_variant" then hasVariant = true end
  end
  check("deck : transformation défaite quand l'épique est remplacée", hasSmite and not hasVariant)
  dv:Close()
  -- remise de la première épique : le deck montre la variante, améliorée comme l'originale
  ns.Expedition.addCard(EXP(), "ue_epic_a")
  UI().toggleDeckView("deck")
  local varCard
  for i, inst in ipairs(dv.list) do
    if inst.id == "ue_variant" then varCard = dv.cards[i] end
  end
  check("deck : variante affichée, améliorée comme la Smite d'origine, infobulle « Transformed Smite. »",
    varCard and varCard.cardUp == true and table.concat(H.hover(varCard), " | "):find("Transformed Smite.", 1, true))
  dv:Close()
  clickOption("leave")
  H.advance(2)

  -- 4. Marchand : épique en vente (prix élevé), achat confirmé ------------------------------------
  local X = ns.Expedition
  local oldShop = X.EPIC.shop
  X.EPIC.shop = 1
  local nx = ns.Map.nextNodes(EXP().map, EXP().node)
  local node = EXP().map.nodes[nx[1]]
  node.kind, node.floor = "merchant", X.EPIC.shopFloor
  clickOption("path:" .. nx[1])
  X.EPIC.shop = oldShop
  scr = UI().current
  local s = EXP().shop
  local last = s.cards[#s.cards]
  local ecard
  for _, card in ipairs(scr.cards) do if vis(card) and card.option and card.option.epic then ecard = card end end
  check("marchand : une épique en vente, cadre violet, prix élevé", last.epic and ecard and epicFrame(ecard)
    and last.price >= X.EPIC.price * (1 - X.PRICE_JITTER) - 1 and (ecard.tag and ecard.tag.text._text) == tostring(last.price))
  EXP().gold = 999
  ns.UI.refresh()
  for _, card in ipairs(UI().current.cards) do if vis(card) and card.option and card.option.epic then ecard = card end end
  H.click(ecard)
  check("marchand : acheter l'épique demande confirmation", ec:IsShown())
  H.click(ec.keep)
  check("marchand : « Keep » ne vend rien", not last.sold and EXP().gold == 999)
  clickOption("leave")

  -- 5. Progress, onglet Zones : emplacement épique, carte lisible une fois débloquée ----------------
  local db = _G.SlayTheDragonDB
  ns.Meta.zoneState(db.meta, "priest", "westfall").won = true
  -- (le départ du 0. avait gagné Duskwood et Wetlands : seule Westfall reste gagnée ici)
  for _, z in ipairs({ "duskwood", "wetlands" }) do ns.Meta.zoneState(db.meta, "priest", z).won = false end
  db.current = nil
  ns.Controller.ending = nil
  ns.UI.refresh()
  clickOption("ui:progress")
  clickOption("ptab:zones")
  scr = UI().current
  local cols = scr.zoneCols
  check("onglet Zones : carte de Westfall débloquée, lisible, au cadre violet", vis(cols[1].card)
    and cols[1].card.cardId == "ue_epic_a" and epicFrame(cols[1].card))
  check("onglet Zones : emplacement verrouillé de Duskwood au cadre épique (aura violette), infobulle de la condition",
    vis(cols[2].lock) and cols[2].lock.epic and vis(cols[2].lock.epicGlow)
    and table.concat(H.hover(cols[2].lock), " | ") == "Win Duskwood to unlock")
  -- survol de la carte débloquée : aperçu à taille réelle à côté
  local card1 = cols[1].card
  card1:GetScript("OnEnter")(card1)
  for _ = 1, 30 do H.advance(0.02) end
  local pv = W.preview
  check("onglet Zones : survol = aperçu à taille réelle de l'épique", pv and vis(pv) and pv.cardId == "ue_epic_a" and epicFrame(pv))
  card1:GetScript("OnLeave")(card1)
  for _ = 1, 30 do H.advance(0.02) end
  H.settle()
  snap("ue-progression-zones", true)
  clickOption("ui:back")

  -- 6. Bilan : l'épique débloquée présentée à part --------------------------------------------------
  H.boot(nil)
  H.slash("")
  ns = H.ns
  addTestContent(ns)
  ns.Controller.makeSeed = function() return SEED end
  clickOption("go")
  e = EXP()
  e.stats.cleared, e.stats.elites, e.stats.bosses = 8, 1, 1
  e.result, e.phase = "won", "done"
  ns.UI.refresh()
  st, scr = UI().step, UI().current
  content = R.rect(ns.UI.content)
  check("bilan : « New epic card: Test Epic. », carte à part (unlocked.epic)", currentKind() == "end"
    and (st.text or ""):find("New epic card: Test Epic.", 1, true) and st.unlocked and st.unlocked.epic == "ue_epic_a",
    st.text)
  local ebad = {}
  if not vis(scr.epicCard) or scr.epicCard.cardId ~= "ue_epic_a" then ebad[#ebad + 1] = "carte absente" end
  if not epicFrame(scr.epicCard) then ebad[#ebad + 1] = "cadre" end
  if not vis(scr.epicLabel) or scr.epicLabel._text ~= "New epic card" then ebad[#ebad + 1] = "libellé" end
  if scr.epicCard:GetScale() <= 0.5 + 1e-6 then ebad[#ebad + 1] = "pas plus grande" end
  for _, o in ipairs({ scr.epicCard, scr.epicLabel }) do
    if not inside(R.rect(o), content) then ebad[#ebad + 1] = "hors de la fenêtre" end
    if not inside(R.rect(o), R.rect(scr.panel)) then ebad[#ebad + 1] = "hors du panneau" end
    for _, b in ipairs(scr.buttons) do if vis(b) and overlaps(R.rect(o), R.rect(b)) then ebad[#ebad + 1] = "sur un bouton" end end
    for _, b in ipairs(scr.bars) do if vis(b) and overlaps(R.rect(o), R.rect(b)) then ebad[#ebad + 1] = "sur une barre" end end
  end
  for _, nc in ipairs(scr.newCards) do
    if vis(nc) and overlaps(R.rect(nc), R.rect(scr.epicCard)) then ebad[#ebad + 1] = "sur une autre carte" end
    if vis(nc) and nc.cardId == "ue_epic_a" then ebad[#ebad + 1] = "en double dans la rangée" end
  end
  check("bilan : épique plus grande, libellée, dans le panneau, sans chevauchement", #ebad == 0, table.concat(ebad, " ; "))
  H.settle()
  check("bilan : aucun texte tronqué", #W.truncatedNow() == 0, table.concat(W.truncatedNow(), " ; "))
  snap("ue-bilan-epique", true)

  -- 7. Crans de la ressource : plafond du combat (Combat.resCap), Rage à 10 par une épique : deux arcs ------
  H.boot(nil)
  H.slash("")
  ns = H.ns
  addTestContent(ns)
  clickOption("class:warrior")
  ns.Controller.makeSeed = function() return SEED end
  clickOption("go")
  e = EXP()
  ns.Expedition.addCard(e, "ue_epic_w")
  local nid = e.map.start[1]
  e.map.nodes[nid].kind = "combat"
  clickOption("path:" .. nid)
  H.settle()
  v = V()
  c = EXP().combat
  c.player.res = 7
  v:Render(true)
  H.advance(1)
  local pips = v.resPips
  local sockets, full = 0, 0
  for _, p in ipairs(pips.list) do
    if vis(p.socket) then sockets = sockets + 1 end
    if vis(p.socket) and (p.fill._calls.SetAlpha and p.fill._calls.SetAlpha[1] or 0) == 1 then full = full + 1 end
  end
  check("crans : plafond du combat (Combat.resCap = 10), 10 alvéoles, 7 pleines", ns.Combat.resCap(c) == 10
    and sockets == 10 and full == 7 and vis(pips), sockets .. " / " .. full)
  -- lisibles : aucun cran sur un autre, à gauche de la main, dans le plateau, hors de l'anneau de mana
  local pbad = {}
  local rects = {}
  for i = 1, 10 do rects[i] = R.rect(pips.list[i].socket) end
  -- (gemmes en losange : écart des centres d'au moins 0,9 cran)
  local function center(r) return (r[1] + r[3]) / 2, (r[2] + r[4]) / 2 end
  for i = 1, 10 do
    for j = i + 1, 10 do
      local xi, yi = center(rects[i])
      local xj, yj = center(rects[j])
      if math.sqrt((xi - xj) ^ 2 + (yi - yj) ^ 2) < 0.9 * (rects[i][3] - rects[i][1]) then pbad[#pbad + 1] = i .. "/" .. j end
    end
    if rects[i][3] >= R.rect(v.cards[1])[1] then pbad[#pbad + 1] = i .. " sur la main" end
    if not inside(rects[i], R.rect(v.hz)) then pbad[#pbad + 1] = i .. " hors du plateau" end
  end
  check("crans à 10 : deux arcs, aucun chevauchement, hors de la main, dans le plateau", #pbad == 0,
    table.concat(pbad, ", "))
  H.settle()
  snap("ue-crans-rage-10", true)
  -- sans l'épique : retour à un arc de 5
  local deck = {}
  for _, cd in ipairs(e.deck) do if cd.id ~= "ue_epic_w" then deck[#deck + 1] = cd end end
  e.deck = deck
  c.epic = nil
  c.player.res = 2
  v:Render(true)
  H.advance(1)
  sockets = 0
  for _, p in ipairs(pips.list) do if vis(p.socket) then sockets = sockets + 1 end end
  check("crans : sans l'épique, plafond de la classe (5)", sockets == 5 and ns.Combat.resCap(c) == 5, sockets)
end

print("UZG socle des zones : crans de vie, primes, intention remplacée et suivante, compteur, cartes de combat (corps, carte d'origine, marque), feu de camp, textes flottants")
-- Combat de la zone 1 piloté par l'interface, avec une zone factice « uztest » pour les vues (c.zone).
local function zoneCombat(cl)
  H.boot(nil)
  H.slash("")
  clickOption("class:" .. (cl or "priest"))
  H.ns.Controller.makeSeed = function() return SEED end
  clickOption("go")
  local e = EXP()
  local id = e.map.start[1]
  e.map.nodes[id].kind = "combat"
  clickOption("path:" .. id)
  H.settle()
  local v = V()
  v:Render(true)
  return e, e.combat, v
end
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function inside(r, box)
    return r and r[1] >= box[1] - 0.5 and r[2] >= box[2] - 0.5 and r[3] <= box[3] + 0.5 and r[4] <= box[4] + 0.5
  end
  local function overlaps(a, b)
    return a and b and a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5
  end
  local function fmt(r) return r and ("%.0f,%.0f,%.0f,%.0f"):format(r[1], r[2], r[3], r[4]) or "nil" end
  local e, c, v = zoneCombat("priest")
  local ns = H.ns
  local Combat, Art = ns.Combat, ns.Art
  -- données de test : un ennemi à deux seuils, une carte de combat et sa forme transformée
  ns.Enemies.uz_phaser = { name = "Phase Tester", hp = 60,
    moves = { hit = { name = "Hit", intent = "attack", actions = { { "attack", 6 } } } }, pattern = { "hit" },
    phases = { { at = 0.5, name = "Enraged", text = "Gains Strength 2." }, { at = 0.25, name = "Last Stand" } } }
  ns.Cards.uz_token = { id = "uz_token", name = "Test Curse", cost = 1, type = "skill", token = true, exhaust = true,
    effects = {}, text = "Unplayable test card." }
  ns.Cards.uz_hexed = { id = "uz_hexed", name = "Hexed", cost = 1, type = "skill", token = true, vanish = true,
    effects = { { "restore" } }, text = "Turn back into the hexed card, in your hand." }
  local e1 = c.enemies[1]
  e1.id, e1.intent = "uz_phaser", "hit"
  local s1 = v.slotOf[e1.uid]
  local sleepIcon = { icon = 136090, tga = "Spell_Nature_Sleep" }
  ns.ZoneViews.uztest = {
    counter = function() return { icon = { icon = 135805 }, text = "Wildfire in 2", tip = "Ignites in 2 rounds.", hot = false } end,
    intent = function(cc, en) if en == e1 then return { icon = sleepIcon, text = "Asleep 2", color = "defend",
      title = "Asleep", tip = "Skips its next 2 turns. Damage wakes it up." } end end,
    intentBadge = function(cc, en) if en ~= e1 then return { icon = { icon = 136139 }, tip = "Bite: adds a Curse." } end end,
    enemyBadges = function(cc, en) return { { icon = { icon = 132203 }, text = "+2 Str", tip = "Pack: when it dies, the rest gains this." } } end,
    handMark = function(cc, i) if i == 1 then return { rim = { 0.4, 1, 0.4, 1 }, icon = { icon = 136071 }, tip = "Hexed at the end of your turn." } end end,
  }
  c.zone = "uztest"
  -- carte transformée en main, carte de combat en main
  local orig = c.hand[2]
  Combat.transformCard(c, orig, "uz_hexed")
  Combat.addCard(c, "uz_token", "hand")
  -- intention suivante d'un autre ennemi (s'il y en a un), sinon du premier
  local e2 = c.enemies[2] or e1
  Combat.forceIntent(c, e2, e2.intent, { now = false, label = "On waking" })
  v:Render(true)
  H.settle()
  -- crans de vie
  local hpw = s1.hp.w or s1.hp._w
  local m1 = s1.marks[1]
  local p = m1._points and m1._points[1]
  check("crans de vie : deux traits sur la barre (50 % et 25 %), infobulle des phases",
    vis(m1) and vis(s1.marks[2]) and not vis(s1.marks[3]) and p and math.abs((p[4] or 0) - hpw * 0.5) < 0.6,
    p and tostring(p[4]) .. " / " .. tostring(hpw))
  local tt = H.hover(s1.hp)
  check("infobulle de la barre : « Below 50%: Enraged. Gains Strength 2. »",
    table.concat(tt, " | "):find("Below 50%: Enraged. Gains Strength 2.", 1, true) ~= nil, table.concat(tt, " | "))
  -- intention remplacée, primes, intention suivante, petite icône
  check("intention remplacée par la zone : « Asleep 2 », infobulle de la zone",
    s1.intent.text._text == "Asleep 2" and (H.hover(s1.intent)[1] or "") == "Asleep", s1.intent.text._text)
  local b1 = s1.badges[1]
  local content = R.rect(ns.UI.content)
  local badBadge = {}
  for _, s in pairs(v.slotOf) do
    local b = s.badges[1]
    if not vis(b) then badBadge[#badBadge + 1] = "prime cachée" end
    if (b.text._text or "") ~= "+2 Str" then badBadge[#badBadge + 1] = tostring(b.text._text) end
    if not inside(R.rect(b), content) then badBadge[#badBadge + 1] = "hors fenêtre " .. fmt(R.rect(b)) end
    if overlaps(R.rect(b), R.rect(s.tag)) then badBadge[#badBadge + 1] = "sur le cadre" end
  end
  check("primes sous l'intention de chaque ennemi : « +2 Str », dans la fenêtre, hors du cadre", #badBadge == 0,
    table.concat(badBadge, " ; "))
  check("infobulle d'une prime", (H.hover(b1)[1] or ""):find("Pack:", 1, true) ~= nil)
  local s2 = v.slotOf[e2.uid]
  check("intention suivante en gris sous l'intention (« On waking: … »)", vis(s2.next)
    and (s2.next._text or ""):find("^On waking: ") ~= nil, tostring(s2.next._text))
  if e2 ~= e1 then
    check("petite icône de zone à droite de l'intention", vis(s2.intent.badge) and not vis(s1.intent.badge))
  end
  -- compteur de combat
  local cr = R.rect(v.counter)
  local hf = R.rect(v.heroFrame)
  local badC = {}
  if not vis(v.counter) then badC[#badC + 1] = "caché" end
  if overlaps(cr, hf) then badC[#badC + 1] = "sur le cadre du héros" end
  for _, s in pairs(v.slotOf) do if overlaps(cr, R.rect(s.tag)) then badC[#badC + 1] = "sur un cadre d'ennemi" end end
  check("compteur de combat en haut au centre : « Wildfire in 2 », hors des cadres", #badC == 0
    and v.counter.text._text == "Wildfire in 2", table.concat(badC, " ; ") .. " " .. fmt(cr))
  check("infobulle du compteur", (H.hover(v.counter)[1] or "") == "Ignites in 2 rounds.")
  -- cartes de combat : corps teinté, carte d'origine, marque
  local hexCard, tokCard, firstCard
  for _, cd in ipairs(v.cards) do
    if cd._shown and cd.cardId == "uz_hexed" then hexCard = cd end
    if cd._shown and cd.cardId == "uz_token" then tokCard = cd end
    if cd._shown and cd.index == 1 then firstCard = cd end
  end
  local tint = Art.bodyTints.token
  local vc = tokCard and tokCard.bg._calls.SetVertexColor
  check("carte de combat (token) : corps teinté sobre", vc and math.abs(vc[1] - tint[1]) < 1e-6 and math.abs(vc[3] - tint[3]) < 1e-6)
  check("carte transformée : nom de la carte d'origine au-dessus de la carte, infobulle", hexCard and hexCard.zoneTagPlate
    and vis(hexCard.zoneTagPlate.text) and hexCard.zoneTagPlate.text._text == ns.Card.def(orig).name
    and table.concat(H.hover(hexCard), " | "):find(ns.Card.def(orig).name, 1, true) ~= nil)
  check("carte marquée par la zone : liseré et icône, infobulle", firstCard and vis(firstCard.rim) and vis(firstCard.markIcon)
    and firstCard.rimKind == "mark" and table.concat(H.hover(firstCard), " | "):find("Hexed at the end", 1, true) ~= nil)
  -- jouer la carte transformée : la carte d'origine revient en main
  local hi
  for i, inst in ipairs(c.hand) do if inst.id == "uz_hexed" then hi = i end end
  H.ns.Controller.act({ "play", hi })
  H.settle()
  local back = false
  for _, inst in ipairs(c.hand) do if inst == orig then back = true end end
  check("carte transformée jouée : la carte d'origine revient en main", back)
  -- textes flottants (zone, phase, compteur, carte posée)
  local ok, err = pcall(function()
    v:OnEvents({ { t = "float", unit = e1.uid, text = "Wakes!", color = "attackText" },
      { t = "phase", unit = e1.uid, n = 1, name = "Enraged" }, { t = "counter", zone = "uztest", key = "wildfire", n = 1, d = -1 },
      { t = "card_added", card = 999, id = "uz_token", to = "discard", src = e1.uid }, { t = "cards_lifted", unit = e1.uid, n = 2 } })
    H.settle()
  end)
  check("textes flottants des zones : float, phase, compteur, carte posée, cartes levées", ok, err)
  snap("zone-socle", true)
  ns.ZoneViews.uztest = nil
  -- feu de camp : action de zone en bouton, au-dessus de « Back on the road »
  local treat = { hooks = {}, campfire = { { id = "uz_treat", label = "Treat wounds", text = "Pay 10g: +1 max HP.",
    can = function(x) if x.gold < 10 then return false, "gold" end return true end,
    apply = function(x) x.gold = x.gold - 10 x.maxHp = x.maxHp + 1 end } } }
  local exp = freshRun(SEED + 3, "campfire")
  ns = H.ns
  ns.ZoneRules.westfall = treat
  ns.UI.refresh()
  H.settle()
  local ok2, b = pcall(button, "campAction:uz_treat")
  local rb = ok2 and R.rect(b)
  local leave = ok2 and R.rect(button("leave"))
  check("feu de camp : action de zone en bouton (libellé), au-dessus de « Back on the road », dans la fenêtre",
    ok2 and vis(b) and b.label._text == "Treat wounds" and inside(rb, R.rect(ns.UI.content)) and not overlaps(rb, leave),
    ok2 and fmt(rb) or tostring(b))
  local hp0 = exp.maxHp
  if ok2 then H.click(b) end
  check("feu de camp : action de zone appliquée, retour à la carte", EXP().maxHp == hp0 + 1 and EXP().phase == "map")
  ns.ZoneRules.westfall = nil
  ns.Enemies.uz_phaser, ns.Cards.uz_token, ns.Cards.uz_hexed = nil, nil, nil
end

-- Harnais propres aux zones : Sim/ui_zone_<zone>.lua (return function(T) … end), dans l'ordre de la
-- campagne s'ils existent. T = { H, ns = H.ns, check, snap, root, SEED, zoneCombat(classe) -> exp, combat,
-- vue, UI, V, EXP, button, clickOption, option, currentKind, R = Sim/ui_render.lua }.
do
  local R = dofile(root .. "/Sim/ui_render.lua")
  R.H = H
  local T = { H = H, check = check, snap = snap, root = root, SEED = SEED, zoneCombat = zoneCombat, UI = UI, V = V,
    EXP = EXP, button = button, clickOption = clickOption, option = option, currentKind = currentKind, R = R }
  for _, id in ipairs(H.ns.Zone.ORDER) do
    local path = root .. "/Sim/ui_zone_" .. id .. ".lua"
    local f = io.open(path, "r")
    if f then
      f:close()
      print("UZ" .. id:sub(1, 1):upper() .. "  " .. id)
      T.ns = H.ns
      dofile(path)(T)
    end
  end
end

print("U16 méthodes d'API inconnues appelées")
local names = {}
for k in pairs(H.unknown) do names[#names + 1] = k end
table.sort(names)
check("aucune méthode inconnue", #names == 0, table.concat(names, ", "))

print(("%d vérifications, %d échec(s)"):format(checks, failures))
print(failures == 0 and "ALL PASS" or "FAILED")
os.exit(failures == 0 and 0 or 1)
