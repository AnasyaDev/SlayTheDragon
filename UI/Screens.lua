-- Écrans génériques pilotés par une liste de choix (voir UI/DemoExpedition.lua) :
--   choice : liste de choix avec texte (accueil, feu de camp, rencontres, bilan)
--   cards  : choix d'une carte (récompense, carte à améliorer ou à retirer)
--   shop   : grille d'objets à prix (marchand)
--   map    : carte de parcours (nœuds reliés)
-- Aucun écran ne connaît les règles : chaque clic devient UI.choose(idOption).
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art, UI = ns.Widgets, ns.Art, ns.UI

local function header(f)
  local title = W.text(f, "GameFontNormalHuge")
  title:SetPoint("TOP", 0, -14)
  local text = W.text(f, "GameFontHighlight")
  text:SetPoint("TOP", title, "BOTTOM", 0, -10)
  text:SetWidth(700)
  text:SetJustifyH("CENTER")
  if text.SetWordWrap then text:SetWordWrap(true) end
  return title, text
end

-- Bouton large à deux lignes (libellé + détail).
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
  b.label = W.text(b, "GameFontNormalLarge", 14)
  b.label:SetPoint("TOPLEFT", 14, -7)
  b.label:SetPoint("TOPRIGHT", -14, -7)
  b.label:SetJustifyH("LEFT")
  b.sub = W.text(b, "GameFontHighlightSmall")
  b.sub:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -3)
  b.sub:SetPoint("TOPRIGHT", b.label, "BOTTOMRIGHT", 0, -3)
  b.sub:SetJustifyH("LEFT")
  b.price = W.text(b, "GameFontNormal")
  b.price:SetPoint("RIGHT", -14, 0)
  W.tooltip(b, function(tt, self)
    local o = self.option
    if not o then return end
    tt:AddLine(o.label or "", 1, 0.82, 0)
    if o.text then tt:AddLine(o.text, 1, 1, 1, true) end
    if o.disabled and o.reason then tt:AddLine(o.reason, 1, 0.3, 0.3, true) end
  end)
  b:SetScript("OnClick", function(self)
    local o = self.option
    if not o then return end
    if o.disabled then UI.flash(o.reason or "Indisponible.") return end
    UI.choose(o.id)
  end)
  return b
end

local function setOption(b, o, n)
  b.option = o
  b.label:SetText((n and (n .. ". ") or "") .. (o.label or o.id))
  b.sub:SetText(o.text or "")
  if o.price then
    b.price:SetText(o.price .. " po")
    if o.disabled then b.price:SetTextColor(1, 0.3, 0.3) else b.price:SetTextColor(1, 0.82, 0) end
  else
    b.price:SetText("")
  end
  b:SetAlpha(o.disabled and 0.5 or 1)
  b:Show()
end

local function chooseOption(o)
  if not o then return end
  if o.disabled then UI.flash(o.reason or "Indisponible.") return end
  UI.choose(o.id)
end

---------------------------------------------------------------------------
-- Liste de choix
---------------------------------------------------------------------------

local Choice = { kinds = { "start", "choice", "event", "end" } }
UI.register("choice", Choice)

function Choice:Build(f)
  self.title, self.text = header(f)
  self.buttons = {}
  for i = 1, 6 do
    local b = optionButton(f, 480, 46)
    b:SetPoint("TOP", f, "TOP", 0, -150 - (i - 1) * 52)
    b:Hide()
    self.buttons[i] = b
  end
  self.optionButtons = {}
end

function Choice:Show(step)
  self.step = step
  self.title:SetText(step.title or "")
  if step.kind == "end" then
    if step.won then self.title:SetTextColor(0.3, 1, 0.3) else self.title:SetTextColor(1, 0.35, 0.35) end
  else
    self.title:SetTextColor(1, 0.82, 0)
  end
  self.text:SetText(step.text or "")
  self.optionButtons = {}
  for i = 1, #self.buttons do
    local o = step.options[i]
    if o then
      setOption(self.buttons[i], o, i)
      self.optionButtons[o.id] = self.buttons[i]
    else
      self.buttons[i].option = nil
      self.buttons[i]:Hide()
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
-- Choix d'une carte (récompense, amélioration, retrait)
---------------------------------------------------------------------------

local Cards = { kinds = { "reward", "deck" } }
UI.register("cards", Cards)

local PER_PAGE = 18

function Cards:Build(f)
  self.title, self.text = header(f)
  self.cards = {}
  for i = 1, PER_PAGE do
    local c = W.card(f)
    c:SetScript("OnClick", function(card) chooseOption(card.option) end)
    c:Hide()
    self.cards[i] = c
  end
  self.buttons = {}
  for i = 1, 3 do
    local b = W.button(f, "", 150, 26)
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
  if self.step ~= step and (not self.step or self.step.title ~= step.title) then self.page = 1 end
  self.step = step
  self.title:SetText(step.title or "")
  self.title:SetTextColor(1, 0.82, 0)
  self.text:SetText(step.text or "")
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
  local cols = big and count or 9
  local cw, ch = W.CARD_W * scale, W.CARD_H * scale
  local gap = big and 30 or 8
  local rowW = math.min(cols, count) * (cw + gap) - gap
  local x0 = (UI.CONTENT_W - rowW) / 2
  self.optionButtons = {}
  for i = 1, PER_PAGE do
    local card = self.cards[i]
    local o = list[first + i]
    if o and i <= count then
      local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
      card:SetScale(scale)
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (x0 + col * (cw + gap)) / scale,
        -(big and 110 or 92) / scale - row * (W.CARD_H + 18))
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
      b:SetPoint("BOTTOM", self.frame, "BOTTOM", (i - (#self.otherOptions + 1) / 2) * 160, 10)
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
  if key == "SPACE" and self.otherOptions[1] then
    chooseOption(self.otherOptions[1])
    return true
  end
  return false
end

---------------------------------------------------------------------------
-- Marchand : grille d'objets à prix
---------------------------------------------------------------------------

local Shop = { kinds = { "shop" } }
UI.register("shop", Shop)

function Shop:Build(f)
  self.title, self.text = header(f)
  self.cards = {}
  for i = 1, 8 do
    local c = W.card(f)
    c:SetScript("OnClick", function(card) chooseOption(card.option) end)
    c:Hide()
    self.cards[i] = c
  end
  self.buttons = {}
  for i = 1, 4 do
    local b = optionButton(f, 300, 44)
    b:Hide()
    self.buttons[i] = b
  end
  self.optionButtons = {}
end

function Shop:Show(step)
  self.step = step
  self.title:SetText(step.title or "")
  self.title:SetTextColor(1, 0.82, 0)
  self.text:SetText(step.text or "")
  local cards, others = {}, {}
  for i = 1, #step.options do
    local o = step.options[i]
    if o.card then cards[#cards + 1] = o else others[#others + 1] = o end
  end
  self.cardOptions, self.otherOptions = cards, others
  self.optionButtons = {}
  local n = math.min(#cards, #self.cards)
  local gap = 26
  local rowW = n * (W.CARD_W + gap) - gap
  local x0 = (UI.CONTENT_W - rowW) / 2
  for i = 1, #self.cards do
    local card, o = self.cards[i], cards[i]
    if o and i <= n then
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x0 + (i - 1) * (W.CARD_W + gap), -96)
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
  for i = 1, #self.buttons do
    local b, o = self.buttons[i], others[i]
    if o then
      b:ClearAllPoints()
      b:SetPoint("TOP", self.frame, "TOP", (i - (#others + 1) / 2) * 316, -300)
      setOption(b, o)
      self.optionButtons[o.id] = b
    else
      b.option = nil
      b:Hide()
    end
  end
end

function Shop:HandleKey(key)
  local idx = UI.keyIndex(key)
  if idx then chooseOption(self.cardOptions[idx]) return true end
  return false
end

---------------------------------------------------------------------------
-- Carte de parcours : nœuds reliés
---------------------------------------------------------------------------

local Map = { kinds = { "map" } }
UI.register("map", Map)

local MAP_W, MAP_H = 840, 300

function Map:Build(f)
  self.title, self.text = header(f)
  local canvas = W.panel(f, "tooltip")
  canvas:SetSize(MAP_W, MAP_H)
  canvas:SetPoint("TOP", 0, -84)
  self.canvas = canvas
  self.nodes = {}
  self.lines = {}
  self.buttons = {}
  for i = 1, 3 do
    local b = W.button(f, "", 160, 28)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.buttons[i] = b
  end
  self.optionButtons = {}
end

local function nodeButton(self, i)
  local b = CreateFrame("Button", nil, self.canvas)
  b:SetSize(40, 40)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.ring = b:CreateTexture(nil, "BACKGROUND")
  b.ring:SetPoint("TOPLEFT", -4, 4)
  b.ring:SetPoint("BOTTOMRIGHT", 4, -4)
  b.ring:SetColorTexture(1, 0.85, 0.2, 0.9)
  b.check = b:CreateTexture(nil, "OVERLAY")
  b.check:SetSize(20, 20)
  b.check:SetPoint("BOTTOMRIGHT", 4, -4)
  b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  b.label = W.text(b, "GameFontHighlightSmall")
  b.label:SetPoint("TOP", b, "BOTTOM", 0, -3)
  b:SetScript("OnClick", function(btn)
    local node = btn.node
    if node and node.state == "available" then UI.choose(node.id)
    elseif node then UI.flash("Étape inaccessible.") end
  end)
  W.tooltip(b, function(tt, btn)
    local node = btn.node
    if not node then return end
    tt:AddLine(node.label or node.kind, 1, 0.82, 0)
    local st = { done = "Franchie", current = "En cours", available = "Accessible", locked = "Plus loin" }
    tt:AddLine(st[node.state] or "", 0.8, 0.8, 0.8)
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
  local byId = {}
  self.optionButtons = {}
  for i = 1, math.max(#nodes, #self.nodes) do
    local node = nodes[i]
    local b = self.nodes[i] or (node and nodeButton(self, i))
    if node then
      b.node = node
      byId[node.id] = b
      b:ClearAllPoints()
      b:SetPoint("CENTER", self.canvas, "TOPLEFT", node.x * MAP_W, -node.y * MAP_H)
      local entry = Art.ui.map[node.kind] or Art.ui.map.event
      W.setIcon(b.icon, entry, "map:" .. tostring(node.kind))
      b.label:SetText(node.label or "")
      local st = node.state
      b.icon:SetDesaturated(st == "done" or st == "locked")
      b:SetAlpha(st == "locked" and 0.45 or 1)
      if st == "available" or st == "current" then b.ring:Show() else b.ring:Hide() end
      if st == "done" then b.check:Show() else b.check:Hide() end
      b:Show()
      self.optionButtons[node.id] = b
    elseif b then
      b.node = nil
      b:Hide()
    end
  end
  -- Liens
  local k = 0
  if self.canvas.CreateLine then
    for i = 1, #nodes do
      local a = byId[nodes[i].id]
      for j = 1, #(nodes[i].links or {}) do
        local bnode = byId[nodes[i].links[j]]
        if a and bnode then
          k = k + 1
          local line = self.lines[k]
          if not line then
            line = self.canvas:CreateLine(nil, "ARTWORK")
            line:SetThickness(3)
            self.lines[k] = line
          end
          local done = nodes[i].state == "done"
          line:SetColorTexture(0.75, 0.6, 0.3, done and 0.9 or 0.4)
          line:SetStartPoint("CENTER", a, 0, 0)
          line:SetEndPoint("CENTER", bnode, 0, 0)
          line:Show()
        end
      end
    end
  end
  for i = k + 1, #self.lines do self.lines[i]:Hide() end
  -- Boutons de choix
  local opts = step.options or {}
  for i = 1, #self.buttons do
    local b, o = self.buttons[i], opts[i]
    if o then
      b.option = o
      b:SetText(o.label or o.id)
      b:ClearAllPoints()
      b:SetPoint("BOTTOM", self.frame, "BOTTOM", (i - (#opts + 1) / 2) * 170, 12)
      b:Show()
      if not self.optionButtons[o.id] then self.optionButtons[o.id] = b end
    else
      b.option = nil
      b:Hide()
    end
  end
end

function Map:HandleKey(key)
  local opts = self.step and self.step.options or {}
  local idx = UI.keyIndex(key)
  if idx then chooseOption(opts[idx]) return true end
  if key == "ENTER" or key == "SPACE" then chooseOption(opts[1]) return true end
  return false
end
