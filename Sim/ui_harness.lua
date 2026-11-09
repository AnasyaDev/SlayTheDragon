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
SetDrawLayer SetBlendMode
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
    _enabled = true, _lines = {} }, Frame)
  H.objects[#H.objects + 1] = o
  if name then _G[name] = o end
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
function Frame:SetSize(w, h) self._w, self._h = w, h end
function Frame:SetWidth(w) self._w = w end
function Frame:SetHeight(h) self._h = h end
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
function Frame:CreateTexture() return newObject("Texture", nil, self) end
function Frame:CreateFontString(_, _, font) local o = newObject("FontString", nil, self) o._font = font return o end
function Frame:CreateLine() return newObject("Line", nil, self) end
function Frame:CreateAnimationGroup() return newObject("AnimationGroup", nil, self) end

-- Texte
function Frame:SetText(t) self._text = t end
function Frame:GetText() return self._text end
function Frame:SetFormattedText(fmt, ...) self._text = fmt:format(...) end
function Frame:GetStringWidth() return #(self._text or "") * 6 end
function Frame:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Frame:SetFont(f, size, flags)
  if type(size) ~= "number" or size <= 0 then error("SetFont : taille invalide") end
  self._fontSize = size
end

-- Textures
function Frame:SetTexture(t)
  if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then error("SetTexture : argument " .. type(t)) end
  self._texture = t
  if type(t) == "string" and H.badPaths[t] then return false end
  return true
end
function Frame:GetTexture() return self._texture end
function Frame:GetTextureFileID()
  local t = self._texture
  if t == nil or (type(t) == "string" and H.badPaths[t]) then return nil end
  return type(t) == "number" and t or 4242
end
function Frame:SetAtlas(a) self._atlas = a return true end

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
  _G.SOUNDKIT = { IG_SPELLBOOK_OPEN = 829, IG_SPELLBOOK_CLOSE = 830 }
  _G.PlaySound = function() end
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
  _G.GetTime = function() return H.now end
  _G.time = function() return 1762000000 + math.floor(H.now) end
  _G.UnitOnTaxi = function(u) assert(u == "player") return H.taxi end
  _G.InCombatLockdown = function() return H.inCombat end
  _G.UnitName = function() return "Testeur" end
  _G.GetCursorPosition = function() return H.cursor[1], H.cursor[2] end
  _G.IsShiftKeyDown = function() return false end
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
-- Pilotage
---------------------------------------------------------------------------

local function UI() return H.ns.UI end
local function C() return H.ns.Controller end
local function V() return H.ns.UI.screens.combat end

local function shown() return _G.SlayTheDragonFrame and _G.SlayTheDragonFrame._shown end

local function currentKind()
  return UI().step and UI().step.kind
end

local function chooseOptionByClick(id)
  local s = UI().current
  local b = s.optionButtons and s.optionButtons[id]
  assert(b, "bouton introuvable pour l'option " .. tostring(id) .. " sur l'écran " .. tostring(currentKind()))
  H.click(b)
end

-- Un coup du bot, exécuté par l'interface : clic carte puis clic cible (ou second clic),
-- en variant clavier et glisser-déposer pour couvrir tous les chemins.
local playStyle = 0
local function playAction(bot)
  local c = C().combat()
  local a = bot:act(c)
  local v = V()
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
    if needs then
      local slot
      for _, s in pairs(v.slotOf) do if s.enemyIndex == t then slot = s end end
      assert(slot, "emplacement de la cible introuvable")
      H.click(slot)
    else
      H.click(card)
    end
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
      for _, s in pairs(v.slotOf) do if s.enemyIndex == t then slot = s end end
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

-- Joue jusqu'à la fin du combat en cours (ou maxActions). Renvoie le résultat.
local function fightUntil(bot, stopFn, maxActions)
  H.actions = 0
  for _ = 1, maxActions or 400 do
    if C().live.over then return C().live.over end
    if stopFn and stopFn() then return nil end
    local before = C().combat().round
    local kind = playAction(bot)
    H.actions = H.actions + 1
    H.advance(0.5)
    if kind == "play" and C().combat() and C().combat().round ~= before then
      -- un coup ne doit jamais faire changer de tour
      error("le tour a changé sur un coup")
    end
  end
  return C().live.over
end

---------------------------------------------------------------------------
-- Scénario
---------------------------------------------------------------------------

local SEED = tonumber(arg and arg[1]) or 4242

print("U1  chargement de tous les fichiers du TOC et premier lancement")
local ns = H.boot(nil)
check("SlayTheDragonDB créée au format courant", _G.SlayTheDragonDB and _G.SlayTheDragonDB.version == ns.Persist.VERSION)
check("aucune expédition au départ", C().live == nil)
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
check("vitesse ×1.25", ns.Persist.options().speed == 1.25, ns.Persist.options().speed)
H.click(UI().speedMinus)
local autoOpen = UI().optionChecks[1]
autoOpen:SetChecked(false) H.click(autoOpen)
check("décocher « ouvrir au décollage » enregistre l'option", ns.Persist.options().autoOpen == false)
autoOpen:SetChecked(true) H.click(autoOpen)
check("recocher", ns.Persist.options().autoOpen == true)
H.key("ESCAPE")
check("Échap ferme d'abord les options", not UI().optionsFrame._shown and shown())

print("U4  nouvelle expédition, carte du parcours, premier combat")
ns.Controller.makeSeed = function() return SEED end
chooseOptionByClick("new")
check("une expédition démarre", C().live ~= nil and C().live.seed == SEED)
check("écran carte", currentKind() == "map", currentKind())
check("nœuds affichés", #UI().current.step.nodes == #ns.DemoExpedition.SEQUENCE)
H.click(UI().current.optionButtons["node:1"])
check("écran de combat", currentKind() == "combat", currentKind())
local c = C().combat()
check("combat créé avec événements non silencieux", c and c.quiet == false)
check("main affichée (5 cartes)", V().cards[5]._shown and not V().cards[6]._shown)
check("modèle du joueur", V().playerModel._model == "unit:player")
local nslots = 0
for _, s in pairs(V().slotOf) do
  nslots = nslots + 1
  if not s.model._model then check("modèle ennemi chargé", false, s.model.enemyId) end
end
check("un emplacement par ennemi vivant", nslots == #C().aliveTargets(), nslots)
local firstSlot = select(2, next(V().slotOf))
check("intention affichée", firstSlot.intent._shown and (firstSlot.intent.text._text or "") ~= "", firstSlot.intent.text._text)
tt = H.hover(firstSlot.intent)
check("infobulle d'intention", #tt >= 2, #tt)
tt = H.hover(V().cards[1])
check("infobulle de carte", #tt >= 2, #tt)
tt = H.hover(V().drawPile)
check("infobulle de la pioche", #tt >= 1, #tt)
check("journal alimenté", #V().log._lines >= 1)
tt = H.hover(UI().info)
check("infobulle du deck dans le bandeau", #tt >= 2 and tt[1]:find("Deck", 1, true), tt[1])
check("bandeau PV / or / étape", (UI().info.text._text or ""):find("PV", 1, true), UI().info.text._text)

print("U5  carte injouable : raison affichée, rien ne bouge")
local saveMana = c.player.mana
c.player.mana = 0
V():Render()
local handBefore = #c.hand
H.click(V().cards[1])
check("raison « Pas assez de mana. »", UI().err._shown and UI().err._text == "Pas assez de mana.", UI().err._text)
check("carte non jouée", #c.hand == handBefore)
check("carte grisée", V().cards[1].shade._shown)
c.player.mana = saveMana
V():Render()

print("U6  combat complet par clics, touches et glisser-déposer")
local bot = ns.Bots.new("heuristic", ns.Rng.stream(SEED, "uibot"), { cap = 3000 })
local savesBefore = _G.SlayTheDragonDB.meta.saves
local r1 = fightUntil(bot, nil, 400)
check("le combat se termine", r1 ~= nil, r1)
check("sauvegarde réécrite à chaque action (" .. H.actions .. " actions)",
  _G.SlayTheDragonDB.meta.saves - savesBefore >= H.actions, _G.SlayTheDragonDB.meta.saves - savesBefore)
check("animations jouées", #H.anims > 0, #H.anims)
check("bandeau de fin affiché", V().banner._shown)
check("le bouton Fin du tour est désactivé", V().endTurn._enabled == false)

print("U7  victoire -> récompense (tirage fixé par la sauvegarde)")
if r1 == "won" then
  H.click(V().banner.button)
  check("écran de récompense", currentKind() == "reward", currentKind())
  local choices = deepcopy(C().live.run.node.choices)
  local db = deepcopy(_G.SlayTheDragonDB)
  ns = H.boot(db)
  check("reprise sur la récompense", C().live and C().live.run.phase == "reward")
  check("mêmes cartes proposées après rechargement", deepeq(choices, C().live.run.node.choices))
  H.slash("")
  check("écran de récompense rouvert", currentKind() == "reward", currentKind())
  local deckN = #C().live.run.deck
  H.key("1")
  check("touche 1 prend la première carte", #C().live.run.deck == deckN + 1 and currentKind() == "map", currentKind())
else
  check("victoire attendue avec la graine " .. SEED, false, r1)
end

print("U8  aller-retour de sauvegarde en plein combat")
H.click(UI().current.optionButtons["node:2"])
bot = ns.Bots.new("heuristic", ns.Rng.stream(SEED + 1, "uibot"), { cap = 3000 })
fightUntil(bot, function() return C().combat().round >= 2 and #C().combat().hand > 0 end, 100)
c = C().combat()
check("combat en cours au tour 2+", c and c.round >= 2 and not C().live.over, c and c.round)
local ok, why = plainData(_G.SlayTheDragonDB, nil, "SlayTheDragonDB")
check("la sauvegarde ne contient que des données simples", ok, why)
local snap = C().snapshot()
local db = deepcopy(_G.SlayTheDragonDB)
check("la sauvegarde égale l'état vivant", deepeq(db.current, snap))
ns = H.boot(db)
check("reprise : état identique (tour, main, PV ennemis, hasard)", deepeq(C().snapshot(), snap), select(2, deepeq(C().snapshot(), snap)))
H.slash("")
check("reprise affichée sur l'écran de combat", currentKind() == "combat", currentKind())
check("même main à l'écran", V().cards[#C().combat().hand]._shown and not V().cards[#C().combat().hand + 1]._shown)
-- Même suite de coups des deux côtés => même résultat (le hasard est dans l'état).
local a = ns.Combat.clone(C().combat())
local b2 = ns.Combat.clone(snap.combat)
ns.Combat.endTurn(a) ns.Combat.endTurn(b2)
check("le tirage suivant est identique après reprise", deepeq(a.hand, b2.hand) and a.round == b2.round)

print("U9  vol : ouverture au décollage, fermeture à l'atterrissage, masquage en combat")
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
ns.Persist.options().autoOpen = false
H.taxi = true
H.fire("PLAYER_CONTROL_LOST")
H.advance(1)
check("option désactivée : pas d'ouverture", not shown())
ns.Persist.options().autoOpen = true
H.taxi = false
H.advance(3)
-- Rechargement de l'interface en plein vol : ouverture au chargement.
db = deepcopy(_G.SlayTheDragonDB)
H.badPaths = {}
ns = H.boot(db) -- au chargement on est au sol ; le vol est déjà en cours à l'entrée dans le monde
H.taxi = true
H.fire("PLAYER_ENTERING_WORLD", false, true)
H.advance(0.5)
check("/reload en vol : fenêtre ouverte", shown())
H.taxi = false
H.advance(3)

print("U10 fin de l'expédition par l'interface")
H.slash("")
local guard = 0
local finalKind
while guard < 60 do
  guard = guard + 1
  local k = currentKind()
  if k == "combat" then
    bot = ns.Bots.new("heuristic", ns.Rng.stream(SEED + guard, "uibot"), { cap = 3000 })
    local r = fightUntil(bot, nil, 400)
    check("combat " .. guard .. " terminé", r ~= nil)
    H.key("SPACE")
  elseif k == "map" then
    H.key("ENTER")
  elseif k == "reward" then
    H.click(UI().current.optionButtons["card:1"])
  elseif k == "choice" then
    -- feu de camp : améliorer si possible, sinon se reposer
    local up = UI().current.optionButtons["upgrade"]
    if up and not up.option.disabled then H.click(up) else H.click(UI().current.optionButtons["rest"]) end
  elseif k == "deck" then
    H.click(UI().current.optionButtons[UI().current.cardOptions[1].id])
  elseif k == "shop" then
    local s = UI().current
    local bought = false
    for _, o in ipairs(s.cardOptions) do
      if not o.disabled then H.click(s.optionButtons[o.id]) bought = true break end
    end
    if not bought then H.click(s.optionButtons["leave"]) end
  elseif k == "end" then
    finalKind = k
    break
  else
    error("écran inattendu : " .. tostring(k))
  end
  H.advance(0.3)
end
check("bilan de fin d'expédition atteint", finalKind == "end", currentKind())
local won = UI().step.won
print("      (résultat : " .. (won and "victoire" or "défaite") .. ", étape " .. C().live.run.floor .. ")")
H.click(UI().current.optionButtons["new"])
check("nouvelle expédition et journal archivé", C().live and #_G.SlayTheDragonDB.journal >= 1)

print("U11 marchand et retrait de carte (écran grille à prix)")
do
  local P = ns.DemoExpedition
  local run = C().live.run
  run.gold = 500
  run.floor = 5
  run.phase = "map"
  C().choose("node:6")
  check("écran marchand", currentKind() == "shop", currentKind())
  local s = UI().current
  local o = s.cardOptions[1]
  local deckN = #run.deck
  H.click(s.optionButtons[o.id])
  check("achat : carte ajoutée et or retiré", #run.deck == deckN + 1 and run.gold == 500 - o.price)
  check("carte marquée vendue", UI().current.cardOptions[1].sold == true)
  H.click(UI().current.optionButtons["remove"])
  check("écran de retrait (grille de cartes)", currentKind() == "deck", currentKind())
  local before = #run.deck
  H.key("1")
  check("carte retirée", #run.deck == before - 1 and currentKind() == "shop", currentKind())
  check("retrait unique", UI().current.optionButtons["remove"].option.disabled == true)
  H.click(UI().current.optionButtons["leave"])
  check("départ : retour à la carte", currentKind() == "map", currentKind())
  assert(P)
end

print("U12 sauvegardes abîmées ou anciennes")
ns = H.boot({ options = { scale = 1.2 } })
check("base sans version : options gardées", _G.SlayTheDragonDB.version == ns.Persist.VERSION
  and ns.Persist.options().scale == 1.2 and ns.Persist.options().autoOpen == true)
local bad = deepcopy(db)
bad.current.run.deck[1].id = "carte_disparue"
ns = H.boot(bad)
check("carte inconnue : expédition archivée, pas d'erreur", C().live == nil
  and _G.SlayTheDragonDB.journal[#_G.SlayTheDragonDB.journal].result == "abandon")
ns = H.boot({ version = 99, current = { x = 1 } })
check("version future mise de côté", _G.SlayTheDragonDB.version == ns.Persist.VERSION
  and _G.SlayTheDragonDB.meta.future and _G.SlayTheDragonDB.current == nil)
ns = H.boot("n'importe quoi")
check("base illisible remplacée", type(_G.SlayTheDragonDB) == "table" and _G.SlayTheDragonDB.version == ns.Persist.VERSION)

print("U13 art manquant : repli et rapport /slay art")
H.badSpells = { [585] = true }
H.badPaths = { ["Interface\\Icons\\Spell_Holy_HolySmite"] = true }
H.badCreatures = { [639] = true, [117] = true }
ns = H.boot(nil)
H.slash("")
chooseOptionByClick("new")
H.key("ENTER")
H.advance(2)
local smite
for i = 1, 10 do
  local card = V().cards[i]
  if card._shown and card.cardId == "smite" then smite = card end
end
check("icône introuvable -> point d'interrogation", smite and smite.icon._texture == ns.Art.QUESTION,
  smite and smite.icon._texture)
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
H.badSpells, H.badPaths, H.badCreatures = nil, {}, {}

print("U14 méthodes d'API inconnues appelées")
local names = {}
for k in pairs(H.unknown) do names[#names + 1] = k end
table.sort(names)
check("aucune méthode inconnue", #names == 0, table.concat(names, ", "))

print(("%d vérifications, %d échec(s)"):format(checks, failures))
print(failures == 0 and "ALL PASS" or "FAILED")
os.exit(failures == 0 and 0 or 1)
