-- Fenêtre principale, gestion des écrans, clavier, options, /slay et bouton de minimap.
local addonName, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art, Controller, Persist = ns.Widgets, ns.Art, ns.Controller, ns.Persist

local UI = {}
ns.UI = UI

UI.WIDTH, UI.HEIGHT = 900, 520
UI.screens = {}         -- kind d'étape -> écran
UI.screenByKind = {}    -- kind -> nom d'écran
UI.current = nil        -- écran affiché
UI.dirty = true

local function opts() return Persist.options() end

local function say(msg)
  local cf = DEFAULT_CHAT_FRAME
  if cf and cf.AddMessage then cf:AddMessage("|cffd4a017Slay the Dragon|r : " .. msg) else print(msg) end
end
UI.say = say

-- Enregistre un écran : screen = { kinds = {...}, Build(self, parent), Show(self, step), Hide(self),
-- HandleKey(self, key) -> handled }.
function UI.register(name, screen)
  UI.screens[name] = screen
  for i = 1, #screen.kinds do UI.screenByKind[screen.kinds[i]] = name end
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------

local function savePosition(f)
  local p, _, rp, x, y = f:GetPoint(1)
  if p then opts().point = { p, rp, x, y } end
end

function UI.applyPosition()
  local f = UI.frame
  local pt = opts().point
  f:ClearAllPoints()
  if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end
end

function UI.applyScale()
  local s = opts().scale or 1
  if s < 0.6 then s = 0.6 elseif s > 1.5 then s = 1.5 end
  opts().scale = s
  UI.frame:SetScale(s)
end

function UI.build()
  if UI.frame then return UI.frame end
  local f = W.panel(UIParent, "dialog", "SlayTheDragonFrame")
  UI.frame = f
  f:SetSize(UI.WIDTH, UI.HEIGHT)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() savePosition(self) end)
  f:Hide()
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "SlayTheDragonFrame") end

  local title = W.text(f, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 18, -14)
  title:SetText("Slay the Dragon")
  UI.title = title

  local info = CreateFrame("Frame", nil, f)
  info:SetSize(330, 18)
  info:SetPoint("LEFT", title, "RIGHT", 18, 0)
  info.text = W.text(info, "GameFontHighlight")
  info.text:SetPoint("LEFT")
  info:EnableMouse(true)
  W.tooltip(info, function(tt)
    local r = Controller.runInfo()
    if not r then tt:AddLine("Aucune expédition en cours.") return end
    tt:AddLine("Deck (" .. #r.deck .. " cartes)", 1, 0.82, 0)
    local counts, order = {}, {}
    for i = 1, #r.deck do
      local c = r.deck[i]
      local d = ns.Card.defById(c.id, c.up)
      if not counts[d.name] then counts[d.name] = 0 order[#order + 1] = d.name end
      counts[d.name] = counts[d.name] + 1
    end
    for i = 1, #order do tt:AddLine(counts[order[i]] .. " × " .. order[i], 1, 1, 1) end
    local relics = r.relics or {}
    if #relics > 0 then
      tt:AddLine(" ")
      tt:AddLine("Bibelots", 1, 0.82, 0)
      for i = 1, #relics do
        local def = ns.Relics[relics[i]]
        tt:AddLine(def and def.name or tostring(relics[i]), 0.6, 0.8, 1)
        if def and def.text then tt:AddLine(def.text, 0.85, 0.85, 0.85, true) end
      end
    end
  end, "ANCHOR_BOTTOM")
  UI.info = info

  local close = W.closeButton(f, function() UI.close("button") end)
  close:SetPoint("TOPRIGHT", -6, -6)

  local gear = W.button(f, "Options", 80, 22, function() UI.toggleOptions() end)
  gear:SetPoint("RIGHT", close, "LEFT", -4, 0)
  UI.gear = gear

  -- Potions (3 emplacements), bibelots et clé mythique, à droite du bandeau.
  UI.potionSlots = {}
  for i = 1, 3 do
    local b = W.iconButton(f, 22)
    b:SetPoint("RIGHT", gear, "LEFT", -8 - (3 - i) * 25, 0)
    b.slot = i
    b:SetScript("OnClick", function(self, button) UI.clickPotion(self, button) end)
    UI.potionSlots[i] = b
  end
  UI.RELICS_SHOWN = 6
  UI.relicIcons = {}
  for i = 1, UI.RELICS_SHOWN do
    local b = W.iconButton(f, 20)
    b:SetPoint("RIGHT", UI.potionSlots[1], "LEFT", -10 - (UI.RELICS_SHOWN - i) * 22, 0)
    b:Hide()
    UI.relicIcons[i] = b
  end
  local more = W.text(f, "GameFontHighlightSmall")
  more:SetPoint("RIGHT", UI.relicIcons[1], "LEFT", -2, 0)
  UI.relicMore = more
  local ks = W.iconButton(f, 22)
  ks:SetPoint("RIGHT", UI.relicIcons[1], "LEFT", -22, 0)
  ks:Hide()
  UI.keystone = ks

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", 12, -36)
  content:SetPoint("BOTTOMRIGHT", -12, 12)
  UI.content = content
  UI.CONTENT_W, UI.CONTENT_H = UI.WIDTH - 24, UI.HEIGHT - 48

  -- Message d'erreur passager (raison d'une carte injouable, etc.).
  local err = W.text(f, "GameFontNormalLarge", 14)
  err:SetPoint("CENTER", content, "CENTER", 0, 30)
  err:SetTextColor(1, 0.25, 0.25)
  err:Hide()
  UI.err = err

  -- Clavier : capté seulement fenêtre ouverte, le reste passe au jeu.
  f:SetScript("OnKeyDown", function(self, key) UI.onKey(key) end)
  f:SetScript("OnShow", function() UI.onShow() end)
  f:SetScript("OnHide", function() UI.onHide() end)

  for _, s in pairs(UI.screens) do
    s.frame = CreateFrame("Frame", nil, content)
    s.frame:SetAllPoints()
    s.frame:Hide()
    s:Build(s.frame)
  end
  UI.buildOptions()
  UI.applyScale()
  UI.applyPosition()
  return f
end

function UI.flash(msg)
  local err = UI.err
  if not err then return end
  err:SetText(msg)
  err:Show()
  UI.flashToken = (UI.flashToken or 0) + 1
  local token = UI.flashToken
  W.delay(1.6, function() if UI.flashToken == token then err:Hide() end end)
end

---------------------------------------------------------------------------
-- Affichage des étapes
---------------------------------------------------------------------------

local function affixText(r)
  local lines = {}
  for i = 1, #(r.affixes or {}) do
    local a = ns.Affixes[r.affixes[i]]
    if a then lines[#lines + 1] = a.name .. " : " .. a.text end
  end
  return table.concat(lines, "\n")
end

function UI.refreshInfo()
  local r = Controller.runInfo()
  local potions = Controller.potions()
  for i = 1, #UI.potionSlots do
    local b = UI.potionSlots[i]
    local id = potions and potions[i]
    if r then
      if id then
        b:SetItem("potion", id, { hint = Controller.inCombat() and "Clic : boire."
          or "Se boit en combat. Clic droit (deux fois) : jeter." })
      else
        b:SetItem(nil, nil, { kind = "empty", title = "Emplacement de potion vide" })
      end
      b:Show()
    else
      b:Hide()
    end
  end
  local relics = r and r.relics or {}
  -- calés à droite : le dernier bibelot obtenu touche les potions
  for i = 1, UI.RELICS_SHOWN do
    local b = UI.relicIcons[i]
    local id = relics[#relics - (UI.RELICS_SHOWN - i)]
    if id then b:SetItem("relic", id) b:Show() else b:Hide() end
  end
  UI.relicMore:SetText(#relics > UI.RELICS_SHOWN and ("+" .. (#relics - UI.RELICS_SHOWN)) or "")
  if r and (r.key or 0) > 0 then
    UI.keystone:SetItem("keystone", r.key, { title = "Clé mythique +" .. r.key, text = affixText(r) })
    UI.keystone.count:SetText("+" .. r.key)
    UI.keystone:Show()
  else
    UI.keystone:Hide()
  end
  if not r then UI.info.text:SetText("") return end
  local t = "|cffff5050" .. r.hp .. "/" .. r.maxHp .. " PV|r   |cffffd700" .. r.gold .. " po|r   "
    .. #r.deck .. " cartes"
  if r.floors then t = t .. "   étape " .. math.max(r.floor or 0, 1) .. "/" .. r.floors end
  UI.info.text:SetText(t)
end

-- Clic sur un emplacement de potion : boire en combat (cible au clic suivant si besoin),
-- jeter hors combat par deux clics droits.
function UI.clickPotion(b, button)
  local potions = Controller.potions()
  local id = potions and potions[b.slot]
  if not id then return end
  local def = ns.Potions[id]
  local name = def and def.name or tostring(id)
  if button == "RightButton" then
    if Controller.inCombat() then UI.flash("On ne jette pas une potion en plein combat.") return end
    if b.armed then
      b.armed = false
      local ok, why = Controller.discardPotion(b.slot)
      if not ok then UI.flash(Controller.reasonText(why)) end
    else
      b.armed = true
      UI.flash("Clic droit à nouveau pour jeter " .. name .. ".")
      W.delay(3, function() b.armed = false end)
    end
    return
  end
  if not Controller.inCombat() then UI.flash("Les potions se boivent en combat.") return end
  if def and def.target then
    UI.screens.combat:SelectPotion(b.slot)
  else
    local ok, why = Controller.usePotion(b.slot)
    if not ok then UI.flash(Controller.reasonText(why)) end
  end
end

function UI.refresh()
  if not UI.frame or not UI.frame:IsShown() then UI.dirty = true return end
  UI.dirty = false
  local step = Controller.step()
  UI.step = step
  local name = UI.screenByKind[step.kind] or "choice"
  local screen = UI.screens[name]
  if UI.current and UI.current ~= screen then UI.current.frame:Hide() if UI.current.OnHide then UI.current:OnHide() end end
  UI.current = screen
  screen.frame:Show()
  screen:Show(step)
  UI.refreshInfo()
end

-- Choix générique depuis un écran (bouton, carte, nœud de carte).
function UI.choose(id)
  local ok, why = Controller.choose(id)
  if not ok and why then UI.flash("Choix impossible.") end
  return ok
end

Controller.onChange(function(kind, data)
  if not UI.frame then return end
  if kind == "combat" then
    local s = UI.screens.combat
    if UI.frame:IsShown() and UI.current == s then
      s:OnEvents(data)
      UI.refreshInfo()
    else
      UI.dirty = true
    end
  else
    UI.refresh()
  end
end)

---------------------------------------------------------------------------
-- Ouverture / fermeture
---------------------------------------------------------------------------

UI.openReason = nil

function UI.isShown() return UI.frame and UI.frame:IsShown() or false end

function UI.open(reason)
  if InCombatLockdown and InCombatLockdown() then
    if reason ~= "flight" then say("indisponible en combat.") end
    return false
  end
  UI.build()
  UI.openReason = reason
  UI.frame:Show()
  return true
end

function UI.close(reason)
  if not UI.frame then return end
  UI.closeReason = reason
  UI.frame:Hide()
end

function UI.toggle()
  if UI.isShown() then UI.close("toggle") else UI.open("toggle") end
end

local function setKeyboard(on)
  local f = UI.frame
  if InCombatLockdown and InCombatLockdown() then
    f:EnableKeyboard(false)
    return
  end
  f:EnableKeyboard(on)
  if on and f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
end

function UI.onShow()
  setKeyboard(true)
  if PlaySound and SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_OPEN then pcall(PlaySound, SOUNDKIT.IG_SPELLBOOK_OPEN) end
  UI.refresh()
end

function UI.onHide()
  setKeyboard(false)
  if UI.current and UI.current.OnHide then UI.current:OnHide() end
  if GameTooltip then GameTooltip:Hide() end
  if PlaySound and SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_CLOSE then pcall(PlaySound, SOUNDKIT.IG_SPELLBOOK_CLOSE) end
end

-- Touche pressée, fenêtre ouverte. Les touches non gérées sont rendues au jeu.
function UI.onKey(key)
  local handled = false
  if key == "ESCAPE" then
    if UI.optionsFrame and UI.optionsFrame:IsShown() then UI.optionsFrame:Hide() else UI.close("escape") end
    handled = true
  elseif UI.optionsFrame and UI.optionsFrame:IsShown() then
    handled = false
  elseif UI.current and UI.current.HandleKey then
    handled = UI.current:HandleKey(key) and true or false
  end
  local f = UI.frame
  if f.SetPropagateKeyboardInput and not (InCombatLockdown and InCombatLockdown()) then
    f:SetPropagateKeyboardInput(not handled)
  end
  return handled
end

-- Touches numériques : "1".."9", "0" -> 1..10 ; nil sinon.
function UI.keyIndex(key)
  if key == "0" then return 10 end
  local n = tonumber(key)
  if n and n >= 1 and n <= 9 and #key == 1 then return n end
  return nil
end

---------------------------------------------------------------------------
-- Options
---------------------------------------------------------------------------

function UI.buildOptions()
  local p = W.panel(UI.frame, "tooltip")
  p:SetSize(360, 300)
  p:SetPoint("TOPRIGHT", UI.frame, "TOPRIGHT", -14, -34)
  p:SetFrameLevel(UI.frame:GetFrameLevel() + 40)
  p:EnableMouse(true)
  p:Hide()
  UI.optionsFrame = p

  local t = W.text(p, "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 14, -12)
  t:SetText("Options")

  local checks = {}
  local function check(label, key, y, onSet)
    local c = W.check(p, label, function() return opts()[key] end,
      function(v) opts()[key] = v if onSet then onSet(v) end end)
    c:SetPoint("TOPLEFT", 14, y)
    checks[#checks + 1] = c
    return c
  end
  check("Ouvrir au décollage", "autoOpen", -40)
  check("Fermer à l'atterrissage", "autoClose", -66)
  check("Mode rapide (animations éclair)", "fast", -92)
  local mm = W.check(p, "Bouton de minimap", function() return not opts().minimap.hide end,
    function(v) opts().minimap.hide = not v UI.updateMinimapButton() end)
  mm:SetPoint("TOPLEFT", 14, -118)
  checks[#checks + 1] = mm
  UI.optionChecks = checks

  local function stepper(label, y, get, set, fmt)
    local l = W.text(p, "GameFontHighlight")
    l:SetPoint("TOPLEFT", 18, y)
    l:SetText(label)
    local v = W.text(p, "GameFontNormal")
    v:SetPoint("TOPLEFT", 200, y)
    local minus = W.button(p, "-", 26, 20, function() set(-1) v:SetText(fmt(get())) end)
    minus:SetPoint("TOPLEFT", 160, y + 3)
    local plus = W.button(p, "+", 26, 20, function() set(1) v:SetText(fmt(get())) end)
    plus:SetPoint("TOPLEFT", 250, y + 3)
    v.Sync = function() v:SetText(fmt(get())) end
    return v, minus, plus
  end
  local pct = function(x) return math.floor(x * 100 + 0.5) .. " %" end
  UI.scaleValue, UI.scaleMinus, UI.scalePlus = stepper("Échelle", -156, function() return opts().scale end,
    function(d) opts().scale = (opts().scale or 1) + d * 0.05 UI.applyScale() end, pct)
  UI.speedValue, UI.speedMinus, UI.speedPlus = stepper("Vitesse des animations", -184,
    function() return opts().speed end,
    function(d)
      local s = (opts().speed or 1) + d * 0.25
      if s < 0.5 then s = 0.5 elseif s > 3 then s = 3 end
      opts().speed = s
    end, function(x) return "×" .. x end)

  local ab = W.button(p, "Abandonner l'expédition", 200, 24)
  ab:SetPoint("BOTTOMLEFT", 14, 44)
  ab:SetScript("OnClick", function(self)
    if not Controller.exp() then UI.flash("Aucune expédition en cours.") return end
    if self.armed then
      self.armed = false
      self:SetText("Abandonner l'expédition")
      Controller.abandon()
      p:Hide()
    else
      self.armed = true
      self:SetText("Confirmer l'abandon ?")
      W.delay(3, function() if self.armed then self.armed = false self:SetText("Abandonner l'expédition") end end)
    end
  end)
  UI.abandonButton = ab

  local rp = W.button(p, "Recentrer la fenêtre", 200, 24, function()
    opts().point = nil
    UI.applyPosition()
  end)
  rp:SetPoint("BOTTOMLEFT", 14, 14)

  local ok = W.button(p, "Fermer", 80, 24, function() p:Hide() end)
  ok:SetPoint("BOTTOMRIGHT", -14, 14)

  p:SetScript("OnShow", function()
    for i = 1, #checks do checks[i]:Sync() end
    UI.scaleValue.Sync()
    UI.speedValue.Sync()
  end)
end

function UI.toggleOptions()
  UI.build()
  if not UI.frame:IsShown() then UI.open("options") end
  if UI.optionsFrame:IsShown() then UI.optionsFrame:Hide() else UI.optionsFrame:Show() end
end

---------------------------------------------------------------------------
-- Bouton de minimap (fait main)
---------------------------------------------------------------------------

local function minimapRadius()
  local w = Minimap and Minimap.GetWidth and Minimap:GetWidth()
  return ((w and w > 0) and w / 2 or 70) + 10
end

function UI.placeMinimapButton()
  local b = UI.minimapButton
  if not b then return end
  local a = math.rad(opts().minimap.angle or 215)
  local r = minimapRadius()
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function UI.updateMinimapButton()
  local b = UI.minimapButton
  if not b then return end
  if opts().minimap.hide then b:Hide() else b:Show() UI.placeMinimapButton() end
end

function UI.createMinimapButton()
  if UI.minimapButton or not Minimap then return end
  local b = CreateFrame("Button", "SlayTheDragonMinimapButton", Minimap)
  UI.minimapButton = b
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -5)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  W.setIcon(icon, Art.ui.minimap, "ui:minimap")
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then UI.toggleOptions() else UI.toggle() end
  end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      cx, cy = cx / s, cy / s
      local ang = math.deg(math.atan2(cy - my, cx - mx))
      opts().minimap.angle = ang
      UI.placeMinimapButton()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  W.tooltip(b, function(tt)
    tt:AddLine("Slay the Dragon", 1, 0.82, 0)
    tt:AddLine("Clic gauche : ouvrir / fermer", 1, 1, 1)
    tt:AddLine("Clic droit : options", 1, 1, 1)
    tt:AddLine("Glisser : déplacer ce bouton", 0.7, 0.7, 0.7)
  end, "ANCHOR_LEFT")
  UI.updateMinimapButton()
end

---------------------------------------------------------------------------
-- /slay
---------------------------------------------------------------------------

local function artReport()
  local keys = {}
  for k in pairs(W.missing) do keys[#keys + 1] = k end
  table.sort(keys)
  if #keys == 0 then
    say("aucune icône ni aucun modèle manquant repéré jusqu'ici (ouvre d'abord quelques écrans).")
  else
    say(#keys .. " élément(s) d'art manquant(s) :")
    for i = 1, #keys do say("  " .. keys[i]) end
  end
end

-- Affiche tous les ennemis de l'acte (vérification des modèles), sans toucher à l'expédition.
local function artPreview()
  UI.open("art")
  local s = UI.screens.combat
  if s and s.PreviewEnemies then s:PreviewEnemies() end
end

SLASH_SLAYTHEDRAGON1 = "/slay"
SLASH_SLAYTHEDRAGON2 = "/slaythedragon"
SlashCmdList.SLAYTHEDRAGON = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" then UI.toggle()
  elseif msg == "options" or msg == "config" then UI.toggleOptions()
  elseif msg == "art" then artReport()
  elseif msg == "modeles" or msg == "models" then artPreview()
  elseif msg == "centre" or msg == "reset" then opts().point = nil if UI.frame then UI.applyPosition() end
  elseif msg:match("^facing") then
    local p, e = msg:match("^facing%s+(%S+)%s+(%S+)")
    p, e = tonumber(p), tonumber(e)
    if p and e then
      opts().facingPlayer, opts().facingEnemy = p, e
      say("orientation : joueur " .. p .. ", ennemis " .. e .. ".")
      if UI.screens.combat and UI.screens.combat.ApplyFacing then UI.screens.combat:ApplyFacing() end
    else
      say("usage : /slay facing <joueur> <ennemis>  (radians, ex. 0.6 -0.6)")
    end
  else
    say("/slay : ouvrir/fermer ; /slay options ; /slay art (art manquant) ; /slay modeles ; "
      .. "/slay facing <j> <e> ; /slay centre")
  end
end
