-- Écrans pilotés par les étapes génériques de UI/Controller.lua :
--   start    : choix de la classe et de la clé mythique, départ, accès à la méta
--   choice   : liste de choix avec texte (bibelot de départ, feu de camp, rencontres)
--   cards    : grille de cartes (récompense avec butin, amélioration, retrait, sélection)
--   shop     : marchand (cartes, bibelots, potions, retrait, or)
--   map      : carte de parcours ramifiée
--   progress : bilan de fin d'expédition et écran « Réputation et journal »
-- Aucun écran ne connaît les règles : chaque clic devient UI.choose(idOption) ; ce qui est
-- grisé, les prix et les raisons viennent du contrôleur (donc de Core/Expedition.lua).
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art, UI = ns.Widgets, ns.Art, ns.UI

local function header(f)
  local title = W.text(f, "GameFontNormalHuge")
  title:SetPoint("TOP", 0, -14)
  local text = W.text(f, "GameFontHighlight")
  text:SetPoint("TOP", title, "BOTTOM", 0, -10)
  text:SetWidth(720)
  text:SetJustifyH("CENTER")
  if text.SetWordWrap then text:SetWordWrap(true) end
  return title, text
end

local function chooseOption(o)
  if not o then return end
  if o.disabled then UI.flash(o.reason or "Indisponible.") return end
  UI.choose(o.id)
end

-- Bouton large à deux lignes (libellé + détail), icône facultative (bibelot, potion).
local function optionButton(parent, w, h)
  local b = W.create("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  if b.SetBackdrop then
    b:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    b:SetBackdropColor(0.12, 0.1, 0.08, 0.95)
    b:SetBackdropBorderColor(0.8, 0.65, 0.3, 1)
  end
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(h - 12, h - 12)
  b.icon:SetPoint("LEFT", 6, 0)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.icon:Hide()
  b.label = W.text(b, "GameFontNormalLarge", h >= 40 and 14 or 12)
  b.label:SetJustifyH("LEFT")
  b.sub = W.text(b, "GameFontHighlightSmall")
  b.sub:SetJustifyH("LEFT")
  b.price = W.text(b, "GameFontNormal")
  b.price:SetPoint("RIGHT", -10, 0)
  b.Place = function(self, withIcon)
    local left = withIcon and (self:GetHeight() - 2) or 12
    self.label:ClearAllPoints()
    self.label:SetPoint("TOPLEFT", left, -7)
    self.label:SetPoint("TOPRIGHT", -12, -7)
    self.sub:ClearAllPoints()
    self.sub:SetPoint("TOPLEFT", self.label, "BOTTOMLEFT", 0, -3)
    self.sub:SetPoint("TOPRIGHT", self.label, "BOTTOMRIGHT", 0, -3)
  end
  b:Place(false)
  W.tooltip(b, function(tt, self)
    local o = self.option
    if not o then return end
    if o.item then
      W.fillItemTooltip(tt, o.item.kind, o.item.id, { reason = o.disabled and o.reason or nil })
    else
      tt:AddLine(o.label or "", 1, 0.82, 0)
      if o.text then tt:AddLine(o.text, 1, 1, 1, true) end
      if o.disabled and o.reason then tt:AddLine(o.reason, 1, 0.3, 0.3, true) end
    end
    if o.price then tt:AddLine(o.price .. " po", 1, 0.82, 0) end
  end)
  b:SetScript("OnClick", function(self) chooseOption(self.option) end)
  return b
end

local function setOption(b, o, n)
  b.option = o
  b.label:SetText((n and (n .. ". ") or "") .. (o.label or o.id))
  b.sub:SetText(o.text or "")
  if o.item then
    W.setIcon(b.icon, W.itemEntry(o.item.kind, o.item.id), o.item.kind .. ":" .. tostring(o.item.id))
    b.icon:SetDesaturated(o.sold and true or false)
    b.icon:Show()
    b:Place(true)
  else
    b.icon:Hide()
    b:Place(false)
  end
  if o.sold then
    b.price:SetText("|cff808080Vendu|r")
  elseif o.price then
    b.price:SetText(o.price .. " po")
    if o.disabled then b.price:SetTextColor(1, 0.3, 0.3) else b.price:SetTextColor(1, 0.82, 0) end
  else
    b.price:SetText("")
  end
  if b.SetBackdropBorderColor then
    if o.selected then b:SetBackdropBorderColor(1, 0.85, 0.2, 1) else b:SetBackdropBorderColor(0.55, 0.45, 0.3, 1) end
  end
  b.label:SetTextColor(o.selected and 0.4 or 1, o.selected and 1 or 0.82, o.selected and 0.4 or 0)
  b:SetAlpha(o.disabled and 0.5 or 1)
  b:Show()
end

local function hideButton(b)
  b.option = nil
  b:Hide()
end

-- Petite ligne d'icônes de butin (récompense) : { kind, id, label, title, text, pending }.
local function lootRow(parent, n)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(n * 210, 34)
  row.items = {}
  for i = 1, n do
    local b = W.iconButton(row, 30)
    b.label = W.text(b, "GameFontHighlight")
    b.label:SetPoint("LEFT", b, "RIGHT", 6, 0)
    b:Hide()
    row.items[i] = b
  end
  row.Set = function(self, list)
    local count = #list
    for i = 1, #self.items do
      local b, it = self.items[i], list[i]
      if it then
        b:ClearAllPoints()
        b:SetPoint("LEFT", self, "CENTER", (i - 1 - count / 2) * 210 + 20, 0)
        b:SetItem(it.kind, it.id, { title = it.title, text = it.text,
          hint = it.pending and "Pas encore prise : libère un emplacement." or nil })
        b.icon:SetDesaturated(it.pending and true or false)
        b.label:SetText(it.label or "")
        b:Show()
      else
        b:Hide()
      end
    end
  end
  return row
end

---------------------------------------------------------------------------
-- Accueil : classe, clé mythique, départ
---------------------------------------------------------------------------

local Start = { kinds = { "start" } }
UI.register("start", Start)

function Start:Build(f)
  self.title, self.text = header(f)
  self.classLabel = W.text(f, "GameFontNormal")
  self.classLabel:SetPoint("TOP", 0, -132)
  self.classLabel:SetText("Classe")
  self.classButtons = {}
  for i = 1, 4 do
    local b = optionButton(f, 220, 42)
    b:Hide()
    self.classButtons[i] = b
  end
  self.keyLabel = W.text(f, "GameFontNormal")
  self.keyLabel:SetPoint("TOP", 0, -204)
  self.keyLabel:SetText("Clé mythique")
  self.keyButtons = {}
  for i = 1, 6 do
    local b = optionButton(f, 62, 30)
    b:Hide()
    self.keyButtons[i] = b
  end
  self.affixes = W.text(f, "GameFontHighlightSmall")
  self.affixes:SetPoint("TOP", 0, -290)
  self.affixes:SetWidth(640)
  self.affixes:SetJustifyH("CENTER")
  self.affixRow = W.statusRow(f, 22, 6)
  self.go = optionButton(f, 300, 42)
  self.go:SetPoint("BOTTOM", 0, 52)
  self.meta = W.button(f, "", 200, 24)
  self.meta:SetPoint("BOTTOM", 0, 14)
  self.meta:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  self.optionButtons = {}
end

function Start:Show(step)
  self.step = step
  self.title:SetText(step.title or "")
  self.title:SetTextColor(1, 0.82, 0)
  self.text:SetText(step.text or "")
  self.optionButtons = {}
  local classes, keys, others = {}, {}, {}
  for _, o in ipairs(step.options) do
    if o.group == "class" then classes[#classes + 1] = o
    elseif o.group == "key" then keys[#keys + 1] = o
    else others[#others + 1] = o end
  end
  for i, b in ipairs(self.classButtons) do
    local o = classes[i]
    if o then
      b:ClearAllPoints()
      b:SetPoint("TOP", self.frame, "TOP", (i - (#classes + 1) / 2) * 230, -150)
      setOption(b, o)
      self.optionButtons[o.id] = b
    else
      hideButton(b)
    end
  end
  for i, b in ipairs(self.keyButtons) do
    local o = keys[i]
    if o then
      b:ClearAllPoints()
      b:SetPoint("TOP", self.frame, "TOP", (i - (#keys + 1) / 2) * 70, -222)
      setOption(b, o)
      self.optionButtons[o.id] = b
    else
      hideButton(b)
    end
  end
  local list, lines = {}, {}
  for _, id in ipairs(step.affixes or {}) do
    local a = ns.Affixes[id]
    list[#list + 1] = { entry = Art.affixes[id], key = "affix:" .. id, info = { title = a.name, text = a.text } }
    lines[#lines + 1] = a.name .. " : " .. a.text
  end
  self.affixes:SetText(#lines > 0 and table.concat(lines, "\n") or "Clé +0 : aucun affixe.")
  self.affixRow:ClearAllPoints()
  self.affixRow:SetPoint("TOPLEFT", self.frame, "TOP", -(#list * 24) / 2, -260)
  self.affixRow:Set(list)
  for _, o in ipairs(others) do
    if o.id == "go" then
      setOption(self.go, o)
      self.optionButtons[o.id] = self.go
    else
      self.meta.option = o
      self.meta:SetText(o.label)
      self.meta:Show()
      self.optionButtons[o.id] = self.meta
    end
  end
end

function Start:HandleKey(key)
  if key == "ENTER" or key == "SPACE" then chooseOption(self.go.option) return true end
  local idx = UI.keyIndex(key)
  if idx and idx <= 6 then
    -- 1..6 : clé +0..+5
    local b = self.keyButtons[idx]
    if b and b.option then chooseOption(b.option) end
    return true
  end
  return false
end

---------------------------------------------------------------------------
-- Liste de choix
---------------------------------------------------------------------------

local Choice = { kinds = { "choice", "startRelic", "campfire", "event" } }
UI.register("choice", Choice)

function Choice:Build(f)
  self.title, self.text = header(f)
  self.buttons = {}
  for i = 1, 6 do
    local b = optionButton(f, 520, 46)
    b:SetPoint("TOP", f, "TOP", 0, -160 - (i - 1) * 52)
    b:Hide()
    self.buttons[i] = b
  end
  self.optionButtons = {}
end

function Choice:Show(step)
  self.step = step
  self.title:SetText(step.title or "")
  self.title:SetTextColor(1, 0.82, 0)
  self.text:SetText(step.text or "")
  self.optionButtons = {}
  for i = 1, #self.buttons do
    local o = step.options[i]
    if o then
      setOption(self.buttons[i], o, i)
      self.optionButtons[o.id] = self.buttons[i]
    else
      hideButton(self.buttons[i])
    end
  end
end

function Choice:HandleKey(key)
  local idx = UI.keyIndex(key)
  if idx then chooseOption(self.step.options[idx]) return true end
  if (key == "ENTER" or key == "SPACE") and #self.step.options == 1 then
    chooseOption(self.step.options[1])
    return true
  end
  return false
end

---------------------------------------------------------------------------
-- Cartes : récompense (avec butin), amélioration, retrait, sélection
---------------------------------------------------------------------------

local Cards = { kinds = { "reward", "deck", "select" } }
UI.register("cards", Cards)

local PER_PAGE = 18

function Cards:Build(f)
  self.title, self.text = header(f)
  self.loot = lootRow(f, 3)
  self.loot:SetPoint("TOP", 0, -98)
  self.cards = {}
  for i = 1, PER_PAGE do
    local c = W.card(f)
    c:SetScript("OnClick", function(card) chooseOption(card.option) end)
    c:Hide()
    self.cards[i] = c
  end
  self.buttons = {}
  for i = 1, 4 do
    local b = W.button(f, "", 170, 26)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.buttons[i] = b
  end
  self.prev = W.button(f, "< Précédent", 110, 24, function() self.page = self.page - 1 self:Layout() end)
  self.prev:SetPoint("BOTTOMLEFT", 10, 8)
  self.next = W.button(f, "Suivant >", 110, 24, function() self.page = self.page + 1 self:Layout() end)
  self.next:SetPoint("BOTTOMRIGHT", -10, 8)
  self.page = 1
  self.optionButtons = {}
end

function Cards:Show(step)
  if not self.step or self.step.title ~= step.title or self.step.kind ~= step.kind then self.page = 1 end
  self.step = step
  self.title:SetText(step.title or "")
  self.title:SetTextColor(1, 0.82, 0)
  self.text:SetText(step.text or "")
  local loot = step.loot or {}
  self.loot:Set(loot)
  if #loot > 0 then self.loot:Show() else self.loot:Hide() end
  self.cardOptions, self.otherOptions = {}, {}
  for i = 1, #step.options do
    local o = step.options[i]
    if o.card then self.cardOptions[#self.cardOptions + 1] = o else self.otherOptions[#self.otherOptions + 1] = o end
  end
  self:Layout()
end

function Cards:Layout()
  local list = self.cardOptions
  local pages = math.max(1, math.ceil(#list / PER_PAGE))
  if self.page > pages then self.page = pages end
  if self.page < 1 then self.page = 1 end
  local first = (self.page - 1) * PER_PAGE
  local count = math.min(PER_PAGE, #list - first)
  local big = #list <= 4
  local scale = big and 1.25 or 0.8
  local cols = big and math.max(count, 1) or 9
  local cw = W.CARD_W * scale
  local gap = big and 30 or 8
  local rowW = math.min(cols, count) * (cw + gap) - gap
  local x0 = (UI.CONTENT_W - rowW) / 2
  local top = (self.step.loot and #self.step.loot > 0) and 142 or (big and 110 or 92)
  self.optionButtons = {}
  for i = 1, PER_PAGE do
    local card = self.cards[i]
    local o = list[first + i]
    if o and i <= count then
      local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
      card:SetScale(scale)
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (x0 + col * (cw + gap)) / scale,
        -top / scale - row * (W.CARD_H + 18))
      card.option = o
      card:SetCard(o.card.id, o.card.up, { key = tostring(i % 10), preview = o.preview,
        playable = not o.disabled, reason = o.disabled and o.reason or nil })
      card:Show()
      self.optionButtons[o.id] = card
    else
      card.option = nil
      card:Hide()
    end
  end
  for i = 1, #self.buttons do
    local b, o = self.buttons[i], self.otherOptions[i]
    if o then
      b.option = o
      b:SetText(o.label or o.id)
      b:ClearAllPoints()
      b:SetPoint("BOTTOM", self.frame, "BOTTOM", (i - (#self.otherOptions + 1) / 2) * 180, 10)
      b:SetAlpha(o.disabled and 0.5 or 1)
      b:Show()
      self.optionButtons[o.id] = b
    else
      b.option = nil
      b:Hide()
    end
  end
  if pages > 1 then
    if self.page > 1 then self.prev:Show() else self.prev:Hide() end
    if self.page < pages then self.next:Show() else self.next:Hide() end
  else
    self.prev:Hide()
    self.next:Hide()
  end
end

function Cards:HandleKey(key)
  local idx = UI.keyIndex(key)
  if idx then
    chooseOption(self.cardOptions[(self.page - 1) * PER_PAGE + idx])
    return true
  end
  if key == "SPACE" or key == "ENTER" then
    -- le dernier bouton (Continuer / Retour / Passer) est l'action par défaut
    chooseOption(self.otherOptions[#self.otherOptions])
    return true
  end
  return false
end

---------------------------------------------------------------------------
-- Marchand : cartes, bibelots, potions, services
---------------------------------------------------------------------------

local Shop = { kinds = { "merchant" } }
UI.register("shop", Shop)

function Shop:Build(f)
  self.title, self.text = header(f)
  self.cards = {}
  for i = 1, 7 do
    local c = W.card(f)
    c:SetScript("OnClick", function(card) chooseOption(card.option) end)
    c:Hide()
    self.cards[i] = c
  end
  self.items = {}
  for i = 1, 8 do
    local b = optionButton(f, 200, 40)
    b:Hide()
    self.items[i] = b
  end
  self.services = {}
  for i = 1, 3 do
    local b = optionButton(f, 280, 40)
    b:Hide()
    self.services[i] = b
  end
  self.optionButtons = {}
end

function Shop:Show(step)
  self.step = step
  self.title:SetText(step.title or "")
  self.title:SetTextColor(1, 0.82, 0)
  self.text:SetText(step.text or "")
  local cards, relics, potions, services = {}, {}, {}, {}
  for _, o in ipairs(step.options) do
    if o.card then cards[#cards + 1] = o
    elseif o.item and o.item.kind == "relic" then relics[#relics + 1] = o
    elseif o.item then potions[#potions + 1] = o
    else services[#services + 1] = o end
  end
  self.cardOptions = cards
  self.optionButtons = {}
  local n = math.min(#cards, #self.cards)
  local gap = 22
  local rowW = n * (W.CARD_W + gap) - gap
  local x0 = (UI.CONTENT_W - rowW) / 2
  for i = 1, #self.cards do
    local card, o = self.cards[i], cards[i]
    if o and i <= n then
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x0 + (i - 1) * (W.CARD_W + gap), -78)
      card.option = o
      local tag
      if o.sold then tag = "|cff808080Vendu|r"
      elseif o.disabled then tag = "|cffff5050" .. (o.price or "?") .. " po|r"
      else tag = "|cffffd700" .. (o.price or "?") .. " po|r" end
      card:SetCard(o.card.id, o.card.up, { tag = tag, key = tostring(i % 10),
        playable = not o.disabled, reason = o.disabled and o.reason or nil })
      card:Show()
      self.optionButtons[o.id] = card
    else
      card.option = nil
      card:Hide()
    end
  end
  -- Bibelots (1re rangée) puis potions (2e rangée).
  local k = 0
  local function place(list, y)
    for i, o in ipairs(list) do
      k = k + 1
      local b = self.items[k]
      if b then
        b:ClearAllPoints()
        b:SetPoint("TOP", self.frame, "TOP", (i - (#list + 1) / 2) * 210, y)
        setOption(b, o)
        self.optionButtons[o.id] = b
      end
    end
  end
  place(relics, -252)
  place(potions, -298)
  for i = k + 1, #self.items do hideButton(self.items[i]) end
  for i, b in ipairs(self.services) do
    local o = services[i]
    if o then
      b:ClearAllPoints()
      b:SetPoint("BOTTOM", self.frame, "BOTTOM", (i - (#services + 1) / 2) * 290, 12)
      setOption(b, o)
      self.optionButtons[o.id] = b
    else
      hideButton(b)
    end
  end
  self.serviceOptions = services
end

function Shop:HandleKey(key)
  local idx = UI.keyIndex(key)
  if idx then chooseOption(self.cardOptions[idx]) return true end
  if key == "SPACE" or key == "ENTER" then
    for _, o in ipairs(self.serviceOptions or {}) do
      if o.id == "leave" then chooseOption(o) return true end
    end
  end
  return false
end

---------------------------------------------------------------------------
-- Carte de parcours : étapes de gauche à droite, nœuds reliés
---------------------------------------------------------------------------

local Map = { kinds = { "map" } }
UI.register("map", Map)

local MAP_W, MAP_H, MAP_PAD = 840, 316, 34

function Map:Build(f)
  self.title, self.text = header(f)
  local canvas = W.panel(f, "tooltip")
  canvas:SetSize(MAP_W, MAP_H)
  canvas:SetPoint("TOP", 0, -92)
  self.canvas = canvas
  self.nodes = {}
  self.lines = {}
  self.buttons = {}
  for i = 1, 3 do
    local b = W.button(f, "", 170, 26)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.buttons[i] = b
  end
  self.affixRow = W.statusRow(f, 22, 6)
  self.affixRow:SetPoint("BOTTOMLEFT", 8, 12)
  self.optionButtons = {}
end

local STATE_TEXT = { done = "Franchie", current = "Tu es ici", available = "Accessible", locked = "Hors de portée" }

local function nodeButton(self, i)
  local b = CreateFrame("Button", nil, self.canvas)
  b:SetSize(34, 34)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.ring = b:CreateTexture(nil, "BACKGROUND")
  b.ring:SetPoint("TOPLEFT", -4, 4)
  b.ring:SetPoint("BOTTOMRIGHT", 4, -4)
  b.ring:SetColorTexture(1, 0.85, 0.2, 0.9)
  b.check = b:CreateTexture(nil, "OVERLAY")
  b.check:SetSize(18, 18)
  b.check:SetPoint("BOTTOMRIGHT", 4, -4)
  b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  b.label = W.text(b, "GameFontHighlightSmall", 9)
  b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
  b:SetScript("OnClick", function(btn)
    local node = btn.node
    if node and node.state == "available" then UI.choose(node.id)
    elseif node then UI.flash("Étape inaccessible.") end
  end)
  W.tooltip(b, function(tt, btn)
    local node = btn.node
    if not node then return end
    tt:AddLine(node.label or node.kind, 1, 0.82, 0)
    tt:AddLine("Étape " .. (node.floor or "?") .. " · " .. (STATE_TEXT[node.state] or ""), 0.8, 0.8, 0.8)
  end)
  self.nodes[i] = b
  return b
end

function Map:Show(step)
  self.step = step
  self.title:SetText(step.title or "")
  self.title:SetTextColor(1, 0.82, 0)
  self.text:SetText(step.text or "")
  local nodes = step.nodes or {}
  local byId, stateOf = {}, {}
  self.optionButtons = {}
  for i = 1, math.max(#nodes, #self.nodes) do
    local node = nodes[i]
    local b = self.nodes[i] or (node and nodeButton(self, i))
    if node then
      b.node = node
      byId[node.id] = b
      stateOf[node.id] = node.state
      b:ClearAllPoints()
      b:SetPoint("CENTER", self.canvas, "TOPLEFT", node.x * MAP_W, -(MAP_PAD + node.y * (MAP_H - 2 * MAP_PAD)))
      local entry = Art.ui.map[node.kind] or Art.ui.map.event
      W.setIcon(b.icon, entry, "map:" .. tostring(node.kind))
      b.label:SetText(node.label or "")
      local st = node.state
      b.icon:SetDesaturated(st == "done" or st == "locked")
      b:SetAlpha(st == "locked" and 0.5 or 1)
      if st == "available" then
        b.ring:SetColorTexture(1, 0.85, 0.2, 0.9)
        b.ring:Show()
      elseif st == "current" then
        b.ring:SetColorTexture(0.3, 0.7, 1, 0.9)
        b.ring:Show()
      else
        b.ring:Hide()
      end
      if st == "done" or st == "current" then b.check:Show() else b.check:Hide() end
      b:Show()
      self.optionButtons[node.id] = b
    elseif b then
      b.node = nil
      b:Hide()
    end
  end
  -- Liens : chemin parcouru en clair, départs possibles en doré, le reste estompé.
  local k = 0
  if self.canvas.CreateLine then
    for i = 1, #nodes do
      local a = byId[nodes[i].id]
      for j = 1, #(nodes[i].links or {}) do
        local to = nodes[i].links[j]
        local bnode = byId[to]
        if a and bnode then
          k = k + 1
          local line = self.lines[k]
          if not line then
            line = self.canvas:CreateLine(nil, "ARTWORK")
            self.lines[k] = line
          end
          local s1, s2 = nodes[i].state, stateOf[to]
          local walked = (s1 == "done" or s1 == "current") and (s2 == "done" or s2 == "current")
          if walked then
            line:SetThickness(4)
            line:SetColorTexture(0.95, 0.9, 0.7, 0.95)
          elseif s1 == "current" and s2 == "available" then
            line:SetThickness(3)
            line:SetColorTexture(1, 0.8, 0.2, 0.8)
          else
            line:SetThickness(2)
            line:SetColorTexture(0.6, 0.5, 0.3, 0.35)
          end
          line:SetStartPoint("CENTER", a, 0, 0)
          line:SetEndPoint("CENTER", bnode, 0, 0)
          line:Show()
        end
      end
    end
  end
  for i = k + 1, #self.lines do self.lines[i]:Hide() end
  -- Boutons des étapes accessibles (clavier 1..3).
  local opts = step.options or {}
  for i = 1, #self.buttons do
    local b, o = self.buttons[i], opts[i]
    if o then
      b.option = o
      b:SetText(i .. ". " .. (o.label or o.id))
      b:ClearAllPoints()
      b:SetPoint("BOTTOM", self.frame, "BOTTOM", (i - (#opts + 1) / 2) * 180, 12)
      b:Show()
      if not self.optionButtons[o.id] then self.optionButtons[o.id] = b end
    else
      b.option = nil
      b:Hide()
    end
  end
  -- Affixes actifs.
  local list = {}
  if (step.key or 0) > 0 then
    list[1] = { entry = Art.keystone, key = "ui:keystone", count = "+" .. step.key,
      info = { title = "Clé mythique +" .. step.key, text = "Affixes actifs : survole les icônes." } }
  end
  for _, id in ipairs(step.affixes or {}) do
    local a = ns.Affixes[id]
    list[#list + 1] = { entry = Art.affixes[id], key = "affix:" .. id, info = { title = a.name, text = a.text } }
  end
  self.affixRow:Set(list)
end

function Map:HandleKey(key)
  local opts = self.step and self.step.options or {}
  local idx = UI.keyIndex(key)
  if idx then chooseOption(opts[idx]) return true end
  if (key == "ENTER" or key == "SPACE") and #opts == 1 then chooseOption(opts[1]) return true end
  return false
end

---------------------------------------------------------------------------
-- Bilan et méta : texte, barres de réputation, journal
---------------------------------------------------------------------------

local Progress = { kinds = { "end", "meta" } }
UI.register("progress", Progress)

function Progress:Build(f)
  self.title, self.text = header(f)
  self.bars = {}
  for i = 1, 5 do
    local b = W.repBar(f, 420)
    b:Hide()
    self.bars[i] = b
  end
  self.journal = {}
  for i = 1, 8 do
    local fs = W.text(f, "GameFontHighlightSmall")
    fs:SetWidth(640)
    fs:SetJustifyH("LEFT")
    self.journal[i] = fs
  end
  self.buttons = {}
  for i = 1, 3 do
    local b = W.button(f, "", 200, 26)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.buttons[i] = b
  end
  self.optionButtons = {}
end

function Progress:Show(step)
  self.step = step
  self.title:SetText(step.title or "")
  if step.kind == "end" then
    if step.won then self.title:SetTextColor(0.3, 1, 0.3) else self.title:SetTextColor(1, 0.35, 0.35) end
  else
    self.title:SetTextColor(1, 0.82, 0)
  end
  self.text:SetText(step.text or "")
  local bars = step.bars or {}
  local y0 = step.kind == "end" and -230 or -100
  for i, b in ipairs(self.bars) do
    local data = bars[i]
    if data then
      b:ClearAllPoints()
      b:SetPoint("TOP", self.frame, "TOP", 0, y0 - (i - 1) * 52)
      b:Set(data)
      b:Show()
    else
      b:Hide()
    end
  end
  local jy = y0 - #bars * 52 - 6
  local lines = step.journal or {}
  for i, fs in ipairs(self.journal) do
    local l = lines[i]
    fs:ClearAllPoints()
    fs:SetPoint("TOP", self.frame, "TOP", 0, jy - (i - 1) * 16)
    if l then
      fs:SetText(l.text)
      if l.won then fs:SetTextColor(0.5, 1, 0.5) else fs:SetTextColor(0.85, 0.85, 0.85) end
      fs:Show()
    else
      fs:SetText("")
      fs:Hide()
    end
  end
  self.optionButtons = {}
  local opts = step.options or {}
  for i, b in ipairs(self.buttons) do
    local o = opts[i]
    if o then
      b.option = o
      b:SetText(o.label)
      b:ClearAllPoints()
      b:SetPoint("BOTTOM", self.frame, "BOTTOM", (i - (#opts + 1) / 2) * 210, 12)
      b:Show()
      self.optionButtons[o.id] = b
    else
      b.option = nil
      b:Hide()
    end
  end
end

function Progress:HandleKey(key)
  local opts = self.step and self.step.options or {}
  local idx = UI.keyIndex(key)
  if idx then chooseOption(opts[idx]) return true end
  if key == "ENTER" or key == "SPACE" then chooseOption(opts[1]) return true end
  return false
end
