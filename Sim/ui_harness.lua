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
SetGradient SetMaxLines SetHorizTile SetVertTile SetHitRectInsets SetClipsChildren
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

local function newObject(kind, name, parent)
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
function Frame:CreateAnimationGroup() return newObject("AnimationGroup", nil, self) end
function Frame:CreateMaskTexture() return newObject("MaskTexture", nil, self) end

-- Texte
function Frame:SetText(t) self._text = t end
function Frame:GetText() return self._text end
function Frame:SetFormattedText(fmt, ...) self._text = fmt:format(...) end
function Frame:GetStringWidth() return #(self._text or "") * 6 end
function Frame:GetStringHeight() return 14 * math.max(1, math.ceil(#(self._text or "") * 6 / math.max(1, self._w or 200))) end
function Frame:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Frame:SetFont(f, size, flags)
  if type(size) ~= "number" or size <= 0 then error("SetFont : taille invalide") end
  self._fontSize = size
  self._fontFile = type(f) == "string" and f:upper():find("MORPHEUS") and "title" or "body"
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
  self._model = "display:" .. id
end
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
          check("infobulle de carte : mots-clés", #tt >= 2, #tt)
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
  check("clé mythique dans le bandeau", UI().keystone._shown and UI().keystone.count._text == "Clé +" .. keyMax)
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
check("cinq cartes à prix", #s.cardOptions == 5 and s.cards[5]._shown and s.cards[1].tag._shown
  and (s.cards[1].tag.text._text or ""):find("po", 1, true))
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
  journal = { { result = "abandon", floor = 2, seed = 1 } }, options = { scale = 1.2 } }
H.boot(devDb)
db = _G.SlayTheDragonDB
check("ancienne sauvegarde de l'interface : options gardées", H.ns.Persist.options().scale == 1.2
  and H.ns.Persist.options().autoOpen == true)
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
H.badSpells = { [585] = true }
H.badFiles = { [135924] = true }
H.badCreatures = { [639] = true, [117] = true }
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
H.advance(2)
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
H.badSpells, H.badPaths, H.badFiles, H.badCreatures = nil, {}, nil, {}

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
  check("pilote à l'arrêt quand rien ne bouge", not Wd.driverAwake() and driver._scripts.OnUpdate == nil)
  run(card, "OnEnter")
  check("survol : le pilote démarre", Wd.driverAwake() and driver._scripts.OnUpdate ~= nil)
  run(driver, "OnUpdate", 0.04)
  local mid = Wd.animValue(card, "hover")
  check("survol en cours : valeur intermédiaire", mid > 0 and mid < 1, mid)
  check("visuel agrandi et levé, zone de survol immobile", card.face._scale > 1 and hit(card) == before,
    card.face._scale)
  run(card, "OnLeave")
  run(driver, "OnUpdate", 0.01)
  local back = Wd.animValue(card, "hover")
  check("sortie en cours de route : repart de la valeur courante", back > 0 and back <= mid, back .. " / " .. mid)
  for _ = 1, 30 do run(driver, "OnUpdate", 0.02) end
  check("sortie terminée : repos exact", Wd.animValue(card, "hover") == 0 and card.face._scale == 1)
  check("pilote arrêté une fois tout immobile", not Wd.driverAwake() and driver._scripts.OnUpdate == nil)
  -- état final par les seuls minuteurs de secours (images sautées)
  run(card, "OnEnter")
  H.advance(0.5)
  check("survol : état final atteint", Wd.animValue(card, "hover") == 1
    and math.abs(card.face._scale - 1.16) < 1e-9 and hit(card) == before, card.face._scale)
  local n = #C().combat().hand
  if n >= 2 then
    check("voisine écartée (visuel seulement)", Wd.animValue(v.cards[2], "dx") > 0)
  end
  check("carte survolée devant les autres (visuel et médaillon compris)", card._level > v.cards[n]._level
    and card.face._level > v.cards[n].face._level and card.medal._level > v.cards[n].medal._level)
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
    local up = f.face._scale > 1
    run(f, "OnLeave")
    H.advance(0.5)
    check("survol animé : " .. tostring(f.label and f.label._text or f.pileKey or "icône"),
      up and f.face._scale == 1 and hit(f) == hb)
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
    and math.abs(upShown.name._calls.SetTextColor[2] - H.ns.Art.C.green[2]) < 1e-9)
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

print("U16 méthodes d'API inconnues appelées")
local names = {}
for k in pairs(H.unknown) do names[#names + 1] = k end
table.sort(names)
check("aucune méthode inconnue", #names == 0, table.concat(names, ", "))

print(("%d vérifications, %d échec(s)"):format(checks, failures))
print(failures == 0 and "ALL PASS" or "FAILED")
os.exit(failures == 0 and 0 or 1)
