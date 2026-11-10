-- Fenêtre principale (1040 × 620), bandeau, gestion des écrans, clavier, options, /slay, minimap.
local addonName, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art, Controller, Persist, Scene = ns.Widgets, ns.Art, ns.Controller, ns.Persist, ns.Scene
local C = Art.C

local UI = {}
ns.UI = UI

UI.WIDTH, UI.HEIGHT = 1040, 620
UI.CONTENT_W, UI.CONTENT_H = 1034, 614
UI.screens = {}         -- nom -> écran
UI.screenByKind = {}    -- kind d'étape -> nom d'écran
UI.current = nil        -- écran affiché
UI.dirty = true
UI.hold = {}            -- butin pas encore « ramassé » à l'écran (cosmétique) : gold, relic, potion

local function opts() return Persist.options() end

local function say(msg)
  local cf = DEFAULT_CHAT_FRAME
  if cf and cf.AddMessage then cf:AddMessage("|cffd4a017Slay the Dragon|r : " .. msg) else print(msg) end
end
UI.say = say

-- Enregistre un écran : screen = { kinds = {...}, Build(self, parent), Show(self, step), OnHide(self),
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
  if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint("CENTER", UIParent, "CENTER", 0, 30) end
end

function UI.applyScale()
  local s = opts().scale or 1
  if s < 0.6 then s = 0.6 elseif s > 1.5 then s = 1.5 end
  opts().scale = s
  UI.frame:SetScale(s)
end

-- Décor et plateau (Scene.set) ; appelé par chaque écran.
function UI.setStage(stage)
  if Scene.decor then Scene.set(stage) end
end

local function buildBand(f)
  local band = CreateFrame("Frame", nil, f)
  Scene.at(band, f, 0, 0, UI.CONTENT_W, 44)
  band:SetFrameLevel(f:GetFrameLevel() + 40)
  band:EnableMouse(true)
  band:RegisterForDrag("LeftButton")
  band:SetScript("OnDragStart", function() UI.frame:StartMoving() end)
  band:SetScript("OnDragStop", function() UI.frame:StopMovingOrSizing() savePosition(UI.frame) end)
  local bg = W.rect(band, "BACKGROUND", 0, C.band)
  bg:SetAllPoints()
  local edge = W.rect(band, "BORDER", 0, C.bandEdge)
  edge:SetPoint("BOTTOMLEFT")
  edge:SetPoint("BOTTOMRIGHT")
  edge:SetHeight(2)
  UI.band = band

  UI.className = W.label(band, "title", 16, C.gold)
  UI.className:SetPoint("LEFT", 14, 0)
  UI.hpText = W.label(band, "body", 15, C.hpText)
  UI.hpText:SetPoint("LEFT", UI.className, "RIGHT", 16, 0)
  UI.goldText = W.label(band, "body", 15, C.gold)
  UI.goldText:SetPoint("LEFT", UI.hpText, "RIGHT", 16, 0)

  -- Centre : nom de la zone (ligne du haut) et progression de l'acte (ligne du bas). Le cadre
  -- s'étend de l'or (à gauche) au premier élément de droite (UI.layoutMid) : un nom trop long est
  -- tronqué, jamais posé sur les points ni sur les icônes.
  local mid = CreateFrame("Frame", nil, band)
  mid:SetHeight(40)
  mid:SetPoint("LEFT", UI.goldText, "RIGHT", 16, 0)
  mid:SetPoint("RIGHT", band, "RIGHT", -100, 0)
  UI.zone = W.label(mid, "title", 14, C.cream)
  UI.zone:SetWordWrap(false)
  UI.zone:SetJustifyH("CENTER")
  UI.dots = {}
  for i = 1, 12 do
    local d = W.disc(mid, "ARTWORK", 0, C.gold)
    d:Hide()
    UI.dots[i] = d
  end
  UI.bossDot = W.rect(mid, "ARTWORK", 0, C.hp)
  UI.bossDot:SetSize(11, 11)
  if UI.bossDot.SetRotation then UI.bossDot:SetRotation(math.pi / 4) end
  UI.bossDot:Hide()
  UI.mid = mid

  -- Droite : × ≡ potions | bibelots, clé, deck.
  local close = W.roundButton(band, "×", 30, C.red, C.redEdge, function() UI.close("button") end)
  close:SetPoint("RIGHT", -10, 0)
  UI.closeButton = close
  local gear = W.roundButton(band, "menu", 30, C.woodDark, C.woodLine, function() UI.toggleOptions() end)
  gear:SetPoint("RIGHT", close, "LEFT", -6, 0)
  UI.gear = gear

  UI.potionSlots = {}
  for i = 1, 3 do
    local b = W.iconButton(band, 30, "flask")
    b:SetPoint("RIGHT", gear, "LEFT", -14 - (3 - i) * 31, 0)
    b.slot = i
    b:SetScript("OnClick", function(self, button) UI.clickPotion(self, button) end)
    UI.potionSlots[i] = b
  end
  local sep = W.rect(band, "ARTWORK", 0, C.bandEdge)
  sep:SetSize(2, 24)
  sep:SetPoint("RIGHT", UI.potionSlots[1], "LEFT", -8, 0)
  UI.sep = sep
  UI.RELICS_SHOWN = 6
  UI.relicIcons = {}
  for i = 1, UI.RELICS_SHOWN do
    local b = W.iconButton(band, 28, "square")
    b:SetPoint("RIGHT", sep, "LEFT", -8 - (UI.RELICS_SHOWN - i) * 32, 0)
    b:Hide()
    UI.relicIcons[i] = b
  end
  UI.relicMore = W.label(band, "body", 11, C.cream)
  UI.relicMore:SetPoint("RIGHT", UI.relicIcons[1], "LEFT", -3, 0)

  -- Clé mythique : pastille violette.
  local ks = CreateFrame("Button", nil, band)
  ks:SetSize(54, 20)
  W.face(ks)
  ks.shape = W.shape(ks.face, 4, C.key, C.key, 1, -4)
  ks.count = W.label(ks.face, "body", 13, C.frame)
  ks.count:SetPoint("CENTER")
  W.hoverable(ks, { scale = 1.1 })
  W.tooltip(ks, function(tt, self)
    if self.info then W.fillItemTooltip(tt, "keystone", self.info.id, self.info) end
  end, "ANCHOR_BOTTOM")
  ks:Hide()
  UI.keystone = ks

  -- Deck : bouton de bois (aussi en combat), infobulle = contenu du deck ; clic = consulter.
  local deck = W.button(band, "Deck", 74, 28, function() UI.toggleDeckView("deck") end, "wood", 13)
  W.tooltip(deck, function(tt)
    UI.fillDeckTooltip(tt)
    tt:AddLine("Clic : voir les cartes.", 0.6, 0.6, 0.6)
  end, "ANCHOR_BOTTOM")
  UI.info = deck
  UI.deckButton = deck
end

function UI.fillDeckTooltip(tt)
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
end

function UI.build()
  if UI.frame then return UI.frame end
  local f = CreateFrame("Frame", "SlayTheDragonFrame", UIParent)
  UI.frame = f
  f:SetSize(UI.WIDTH, UI.HEIGHT)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:Hide()
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "SlayTheDragonFrame") end
  W.roundRect(f, "BACKGROUND", -8, 10, 0):SetColor(C.frameEdge)
  W.roundRect(f, "BACKGROUND", -7, 8, 3):SetColor(C.frame)

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", 3, -3)
  content:SetSize(UI.CONTENT_W, UI.CONTENT_H)
  UI.content = content
  Scene.build(content)
  buildBand(content)

  -- Message passager (raison d'un refus, consigne).
  local err = CreateFrame("Frame", nil, content)
  err:SetSize(520, 34)
  Scene.at(err, content, (UI.CONTENT_W - 520) / 2, 196, 520, 34)
  err:SetFrameLevel(content:GetFrameLevel() + 90)
  err.shape = W.shape(err, 10, C.red, C.band, 2, -4)
  err.text = W.label(err, "body", 15, C.hpText, "OVERLAY", true)
  err.text:SetPoint("CENTER")
  err:Hide()
  -- Compatibilité avec le harnais : err._text / err:SetText.
  err.SetText = function(self, t) self.text:SetText(t) self._text = t end
  UI.err = err

  f:SetScript("OnKeyDown", function(self, key) UI.onKey(key) end)
  f:SetScript("OnShow", function() UI.onShow() end)
  f:SetScript("OnHide", function() UI.onHide() end)

  for _, s in pairs(UI.screens) do
    s.frame = CreateFrame("Frame", nil, content)
    s.frame:SetAllPoints()
    s.frame:SetFrameLevel(content:GetFrameLevel() + 5)
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
  err:SetWidth(math.max(220, (err.text:GetStringWidth() or 200) + 40))
  err:Show()
  UI.flashToken = (UI.flashToken or 0) + 1
  local token = UI.flashToken
  W.delay(1.8, function() if UI.flashToken == token then err:Hide() end end)
end

---------------------------------------------------------------------------
-- Bandeau
---------------------------------------------------------------------------

local function affixText(r)
  local lines = {}
  for i = 1, #(r.affixes or {}) do
    local a = ns.Affixes[r.affixes[i]]
    if a then lines[#lines + 1] = a.name .. " : " .. a.text end
  end
  return table.concat(lines, "\n")
end

-- Nom de zone sur la ligne du haut, points de progression centrés sur la ligne du bas : les deux
-- ne peuvent pas se chevaucher, quelle que soit la longueur du nom (tronqué à la largeur du cadre).
local function layoutDots(r)
  local mid = UI.mid
  local floors = r and r.floors
  local showDots = floors and UI.step and UI.step.kind ~= "map"
  UI.zone:ClearAllPoints()
  local zy = showDots and 9 or 0
  UI.zone:SetPoint("LEFT", mid, "LEFT", 4, zy)
  UI.zone:SetPoint("RIGHT", mid, "RIGHT", -4, zy)
  if not showDots then
    for i = 1, #UI.dots do UI.dots[i]:Hide() end
    UI.bossDot:Hide()
    return
  end
  local cur = math.max(1, (r.floor or 0))
  local n = math.min(floors - 1, #UI.dots)
  local dotsW = n * 15 + 16
  local x = -dotsW / 2
  for i = 1, #UI.dots do
    local d = UI.dots[i]
    if i <= n then
      d:ClearAllPoints()
      local size = (i == cur) and 13 or 9
      d:SetSize(size, size)
      d:SetPoint("CENTER", mid, "CENTER", x + 5, -11)
      local c = i < cur and C.gold or (i == cur and C.creamLight or Art.hex("#5a4630"))
      d:SetVertexColor(c[1], c[2], c[3], 1)
      d:Show()
      x = x + 15
    else
      d:Hide()
    end
  end
  UI.bossDot:ClearAllPoints()
  UI.bossDot:SetSize(10, 10)
  UI.bossDot:SetPoint("CENTER", mid, "CENTER", x + 6, -11)
  UI.bossDot:Show()
end

-- Bornes du cadre central : de l'or à l'élément le plus à gauche du groupe de droite.
local function layoutMid(rightmost)
  local mid = UI.mid
  mid:ClearAllPoints()
  mid:SetHeight(40)
  mid:SetPoint("LEFT", UI.goldText, "RIGHT", 16, 0)
  mid:SetPoint("RIGHT", rightmost, "LEFT", -12, 0)
end

function UI.refreshInfo()
  local r = Controller.runInfo()
  local potions = Controller.potions()
  local hold = UI.hold
  local heldPotion = hold.potion
  for i = 1, #UI.potionSlots do
    local b = UI.potionSlots[i]
    local id = potions and potions[i]
    if heldPotion and id == heldPotion and i == hold.potionSlot then id = nil end
    if r then
      if id then
        b:SetItem("potion", id, { hint = Controller.inCombat() and "Clic : boire."
          or "Se boit en combat. Clic droit (deux fois) : jeter." })
      else
        b:SetItem(nil, nil, { kind = "empty" })
      end
      b:Show()
    else
      b:Hide()
    end
  end
  local relics = r and r.relics or {}
  local nShown = #relics
  if hold.relic and relics[#relics] == hold.relic then nShown = nShown - 1 end
  -- calés à droite : le dernier bibelot obtenu touche les potions
  for i = 1, UI.RELICS_SHOWN do
    local b = UI.relicIcons[i]
    local id = relics[nShown - (UI.RELICS_SHOWN - i)]
    if id and nShown - (UI.RELICS_SHOWN - i) >= 1 then b:SetItem("relic", id) b:Show() else b:Hide() end
  end
  UI.relicMore:SetText(nShown > UI.RELICS_SHOWN and ("+" .. (nShown - UI.RELICS_SHOWN)) or "")
  if r then UI.sep:Show() else UI.sep:Hide() end
  -- clé et deck, à gauche des bibelots
  local anchor = UI.relicIcons[math.max(1, UI.RELICS_SHOWN - math.min(nShown, UI.RELICS_SHOWN) + 1)]
  if nShown == 0 then anchor = UI.sep end
  local right = anchor
  if r and (r.key or 0) > 0 then
    UI.keystone.info = { id = r.key, title = "Clé mythique +" .. r.key, text = affixText(r) }
    UI.keystone.count:SetText("Clé +" .. r.key)
    UI.keystone:ClearAllPoints()
    UI.keystone:SetPoint("RIGHT", right, "LEFT", -10, 0)
    UI.keystone:Show()
    right = UI.keystone
  else
    UI.keystone:Hide()
  end
  if r then
    UI.deckButton:SetText("Deck " .. #r.deck)
    UI.deckButton:ClearAllPoints()
    UI.deckButton:SetPoint("RIGHT", right, "LEFT", -10, 0)
    UI.deckButton:Show()
    right = UI.deckButton
  else
    UI.deckButton:Hide()
    right = UI.gear
  end
  layoutMid(right)
  if UI.deckView then UI.deckView:Refresh() end
  if not r then
    UI.className:SetText("Slay the Dragon")
    UI.hpText:SetText("")
    UI.goldText:SetText("")
    UI.zone:SetText("")
    layoutDots(nil)
    return
  end
  local cls = Controller.exp() and ns.Classes[Controller.exp().class]
  UI.className:SetText(cls and cls.name or "Slay the Dragon")
  UI.hpText:SetText(r.hp .. " / " .. r.maxHp .. " PV")
  UI.goldText:SetText(math.max(0, r.gold - (hold.gold or 0)) .. " po")
  local zone = r.act or ""
  if UI.step and UI.step.kind == "map" then zone = "Acte " .. (Controller.exp() and Controller.exp().act or 1) .. " · " .. zone end
  UI.zone:SetText(zone)
  layoutDots(r)
end

-- Position (coordonnées du contenu) d'une destination du bandeau, pour le butin qui y vole.
function UI.bandTarget(kind)
  if kind == "gold" then return 190, 22 end
  if kind == "potion" then return 880, 22 end
  if kind == "relic" then return 760, 22 end
  return 517, 22
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
  if UI.current and UI.current ~= screen then
    UI.current.frame:Hide()
    if UI.current.OnHide then UI.current:OnHide() end
    if UI.deckView then UI.deckView:Close() end
  end
  UI.current = screen
  screen.frame:Show()
  screen:Show(step)
  UI.refreshInfo()
end

-- Choix générique depuis un écran (bouton, carte, nœud de carte).
function UI.choose(id)
  local ok, why = Controller.choose(id)
  if not ok and why then UI.flash(Controller.reasonText(why) or "Choix impossible.") end
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
  W.sound("open")
  UI.refresh()
end

function UI.onHide()
  setKeyboard(false)
  if UI.deckView then UI.deckView:Close() end
  if UI.current and UI.current.OnHide then UI.current:OnHide() end
  if GameTooltip then GameTooltip:Hide() end
  W.sound("close")
end

-- Touche pressée, fenêtre ouverte. Les touches non gérées sont rendues au jeu.
function UI.onKey(key)
  local handled = false
  local dv = UI.deckView
  if key == "ESCAPE" then
    if UI.optionsFrame and UI.optionsFrame:IsShown() then UI.optionsFrame:Hide()
    elseif dv and dv:IsShown() then dv:Close()
    else UI.close("escape") end
    handled = true
  elseif UI.optionsFrame and UI.optionsFrame:IsShown() then
    handled = false
  elseif dv and dv:IsShown() then
    handled = false -- panneau des cartes ouvert : l'écran dessous ne reçoit rien
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
  local p = W.parchment(UI.content, 10)
  p:SetSize(360, 330)
  p:SetPoint("TOPRIGHT", UI.content, "TOPRIGHT", -10, -48)
  p:SetFrameLevel(UI.content:GetFrameLevel() + 100)
  p:Hide()
  UI.optionsFrame = p

  local t = W.label(p, "title", 20, C.ink)
  t:SetPoint("TOPLEFT", 16, -14)
  t:SetText("Options")

  local checks = {}
  local function check(label, key, y, onSet)
    local c = W.check(p, label, function() return opts()[key] end,
      function(v) opts()[key] = v if onSet then onSet(v) end end)
    c:SetPoint("TOPLEFT", 14, y)
    checks[#checks + 1] = c
    return c
  end
  check("Ouvrir au décollage", "autoOpen", -44)
  check("Fermer à l'atterrissage", "autoClose", -68)
  check("Mode rapide (animations éclair)", "fast", -92)
  local mm = W.check(p, "Bouton de minimap", function() return not opts().minimap.hide end,
    function(v) opts().minimap.hide = not v UI.updateMinimapButton() end)
  mm:SetPoint("TOPLEFT", 14, -116)
  checks[#checks + 1] = mm
  check("Décor illustré (sinon peint)", "decor", -140, function() UI.refresh() end)
  UI.optionChecks = checks

  local function stepper(label, y, get, set, fmt)
    local l = W.label(p, "body", 12, C.ink)
    l:SetPoint("TOPLEFT", 18, y)
    l:SetText(label)
    local v = W.label(p, "title", 14, C.ink)
    v:SetPoint("TOPLEFT", 214, y + 1)
    local minus = W.button(p, "-", 26, 22, function() set(-1) v:SetText(fmt(get())) end)
    minus:SetPoint("TOPLEFT", 178, y + 4)
    local plus = W.button(p, "+", 26, 22, function() set(1) v:SetText(fmt(get())) end)
    plus:SetPoint("TOPLEFT", 270, y + 4)
    v.Sync = function() v:SetText(fmt(get())) end
    return v, minus, plus
  end
  local pct = function(x) return math.floor(x * 100 + 0.5) .. " %" end
  UI.scaleValue, UI.scaleMinus, UI.scalePlus = stepper("Échelle", -178, function() return opts().scale end,
    function(d) opts().scale = (opts().scale or 1) + d * 0.05 UI.applyScale() end, pct)
  UI.speedValue, UI.speedMinus, UI.speedPlus = stepper("Vitesse des animations", -208,
    function() return opts().speed end,
    function(d)
      local s = (opts().speed or 1) + d * 0.25
      if s < 0.5 then s = 0.5 elseif s > 3 then s = 3 end
      opts().speed = s
    end, function(x) return "×" .. x end)

  local ab = W.button(p, "Abandonner l'expédition", 200, 26, nil, "red")
  ab:SetPoint("BOTTOMLEFT", 14, 48)
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

  local rp = W.button(p, "Recentrer la fenêtre", 200, 26, function()
    opts().point = nil
    UI.applyPosition()
  end)
  rp:SetPoint("BOTTOMLEFT", 14, 16)

  local ok = W.button(p, "Fermer", 90, 26, function() p:Hide() end, "gold", 13)
  ok:SetPoint("BOTTOMRIGHT", -14, 16)

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

-- /slay art : décors (candidat retenu ou repli, décor par décor), puis icônes et modèles manquants.
local function artReport()
  if not UI.frame then UI.build() end
  say("décors illustrés" .. (opts().decor == false and " (désactivés : /slay decor)" or "") .. " :")
  for _, line in ipairs(Scene.report()) do say("  " .. line) end
  local keys = {}
  for k in pairs(W.missing) do keys[#keys + 1] = k end
  table.sort(keys)
  if #keys == 0 then
    say("aucune icône ni aucun modèle manquant repéré jusqu'ici (à relancer après quelques écrans).")
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
  elseif msg == "decor" then
    opts().decor = opts().decor == false
    say("décor " .. (opts().decor and "illustré" or "peint") .. ".")
    if UI.frame and UI.frame:IsShown() then UI.refresh() end
  elseif msg == "centre" or msg == "reset" then opts().point = nil if UI.frame then UI.applyPosition() end
  elseif msg:match("^facing") then
    local p, e = msg:match("^facing%s+(%S+)%s+(%S+)")
    p, e = tonumber(p), tonumber(e)
    if p and e then
      opts().facingPlayer, opts().facingEnemy = p, e
      say("orientation : joueur " .. p .. ", ennemis " .. e .. ".")
      for _, s in pairs(UI.screens) do if s.ApplyFacing then s:ApplyFacing() end end
    else
      say("usage : /slay facing <joueur> <ennemis>  (radians, ex. 0.6 -0.6)")
    end
  else
    say("/slay : ouvrir/fermer ; /slay options ; /slay art (art manquant) ; /slay modeles ; "
      .. "/slay decor ; /slay facing <j> <e> ; /slay centre")
  end
end
