-- Écrans pilotés par les étapes génériques de UI/Controller.lua, sur la scène commune (UI/Scene.lua) :
--   start    : accueil (classe, clé mythique, départ, méta)
--   choice   : rencontre et bibelot de classe (docs/maquette/Rencontre.dc.html)
--   campfire : feu de camp (couchage = repos, grimoire = améliorer)
--   reward   : récompense et coffre (docs/maquette/Recompense.dc.html)
--   deck     : grille du deck (amélioration, retrait, sélection de rencontre)
--   shop     : marchand (étal : cartes, bibelots, fioles, retrait)
--   map      : carte de parcours (docs/maquette/Parcours.dc.html)
--   progress : bilan et « Réputation et journal »
-- Aucun écran ne connaît les règles : chaque clic devient UI.choose(idOption) ; ce qui est grisé, les
-- prix et les raisons viennent du contrôleur (donc de Core/Expedition.lua).
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art, UI, Scene, Controller = ns.Widgets, ns.Art, ns.UI, ns.Scene, ns.Controller
local C = Art.C
local at = Scene.at
local max, min, floor = math.max, math.min, math.floor

local function chooseOption(o)
  if not o then return end
  if o.disabled then UI.flash(o.reason or "Indisponible.") return end
  W.sound("click")
  UI.choose(o.id)
end

-- Couleurs WoW vives -> encres lisibles sur parchemin.
local function inkText(t)
  t = t or ""
  t = t:gsub("|cffffd700", "|cff8a5a00"):gsub("|cff40ff40", "|cff1f6b2a"):gsub("|cff40c0ff", "|cff2f5f8a")
  t = t:gsub("|cffff6060", "|cff9a2a1a")
  return t
end

-- Héros posé à gauche (récompense, rencontre, feu de camp, accueil).
local function heroFigure(f)
  local fig = Scene.figure(f, 170, 200)
  at(fig, f, 85, 146, 170, 200)
  fig:EnableMouse(false)
  return fig
end

-- Tas du deck sur le plateau (nombre de cartes ; infobulle = contenu).
local function deckPile(f)
  local back = CreateFrame("Frame", nil, f)
  at(back, f, 68, 476, 72, 100)
  W.roundRect(back, "BACKGROUND", -8, 8, 0):SetColor(C.band)
  local mid = CreateFrame("Frame", nil, f)
  at(mid, f, 64, 472, 72, 100)
  W.roundRect(mid, "BACKGROUND", -8, 8, 0):SetColor(C.woodDark)
  local p = CreateFrame("Frame", nil, f)
  at(p, f, 60, 468, 72, 100)
  p:EnableMouse(true)
  p.shape = W.shape(p, 8, C.gold, C.wood, 3, -6)
  p.count = W.label(p, "title", 28, C.creamLight)
  p.count:SetPoint("CENTER")
  W.tooltip(p, function(tt) UI.fillDeckTooltip(tt) end, "ANCHOR_RIGHT")
  p.Sync = function(self)
    local r = Controller.runInfo()
    self.count:SetText(r and #r.deck or "")
  end
  return p
end

-- Plaque de réponse (rencontre, bibelot) : libellé + ce que ça donne.
local function plaque(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(300, 124)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.halo = W.roundRect(b, "BACKGROUND", -8, 13, -4):SetColor(C.gold)
  b.halo:Hide()
  b.shape = W.shape(b, 10, C.edgeCommon, C.parchment, 4, -7, 0.22)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(40, 40)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.icon:Hide()
  b.label = W.label(b, "title", 18, C.ink)
  b.label:SetWidth(280)
  b.label:SetJustifyH("CENTER")
  b.sub = W.label(b, "body", 14, C.inkSoft)
  b.sub:SetWidth(280)
  b.sub:SetJustifyH("CENTER")
  b.sub:SetWordWrap(true)
  b.SetOption = function(self, o, w, h)
    self.option = o
    self:SetSize(w, h)
    self.label:SetWidth(w - 24)
    self.sub:SetWidth(w - 24)
    self.label:SetText(o.label or o.id)
    local sub = o.text or ""
    local col = C.inkSoft
    if o.disabled and o.reason then sub, col = o.reason, C.numberInk
    elseif sub:match("^%+") then col = C.green end
    self.sub:SetText(sub)
    self.sub:SetTextColor(col[1], col[2], col[3])
    self.label:ClearAllPoints()
    if o.item then
      W.setIcon(self.icon, W.itemEntry(o.item.kind, o.item.id), o.item.kind .. ":" .. tostring(o.item.id))
      self.icon:ClearAllPoints()
      self.icon:SetPoint("TOP", 0, -12)
      self.icon:Show()
      self.label:SetPoint("TOP", self.icon, "BOTTOM", 0, -6)
    else
      self.icon:Hide()
      self.label:SetPoint("CENTER", 0, sub ~= "" and 14 or 0)
    end
    self.sub:ClearAllPoints()
    self.sub:SetPoint("TOP", self.label, "BOTTOM", 0, -8)
    self:SetAlpha(o.disabled and 0.6 or 1)
    self:Show()
  end
  b:SetScript("OnClick", function(self) chooseOption(self.option) end)
  W.tooltip(b, function(tt, self)
    local o = self.option
    if o and o.item then W.fillItemTooltip(tt, o.item.kind, o.item.id, { reason = o.disabled and o.reason or nil }) end
  end, "ANCHOR_TOP")
  b.onEnterExtra = function(self)
    if self.option and not self.option.disabled then
      self.halo:Show()
      self.shape.fill:SetColor(C.parchmentLight)
    end
  end
  b.onLeaveExtra = function(self)
    self.halo:Hide()
    self.shape.fill:SetColor(C.parchment)
  end
  return b
end

-- Objet posé au sol, cliquable (couchage, grimoire, bourse, fiole, bibelot, coffre) : ombre, cadre,
-- icône, étiquette dessous.
local function groundObject(parent, size, shape)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.shadow = W.disc(b, "BACKGROUND", -8, C.shadow, 0.55)
  b.shadow:SetSize(size * 1.05, 14)
  b.shadow:SetPoint("TOP", b, "BOTTOM", 0, 8)
  b.halo = W.roundRect(b, "BACKGROUND", -7, shape == "flask" and floor(size / 3) + 3 or 10, -4):SetColor(C.gold)
  b.halo:Hide()
  local radius = shape == "flask" and floor(size / 3) or (shape == "bag" and floor(size / 2.4) or 8)
  b.shape = W.shape(b, radius, C.cream, C.woodDark, 3, -6)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 4, -4)
  b.icon:SetPoint("BOTTOMRIGHT", -4, 4)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if shape == "flask" or shape == "bag" then W.roundMask(b, b.icon) end
  b.big = W.label(b, "title", 20, C.creamLight, "OVERLAY", true)
  b.big:SetPoint("CENTER", 0, 0)
  b.tag = CreateFrame("Frame", nil, b)
  b.tag:SetSize(80, 22)
  b.tag:SetPoint("TOP", b, "BOTTOM", 0, -10)
  b.tag.shape = W.shape(b.tag, 7, C.goldDeep, C.band, 2, -4)
  b.tag.text = W.label(b.tag, "body", 13, C.gold)
  b.tag.text:SetPoint("CENTER")
  b.tag:Hide()
  b.SetTag = function(self, text, color)
    if not text or text == "" then self.tag:Hide() return end
    self.tag.text:SetText(text)
    local c = color or C.gold
    self.tag.text:SetTextColor(c[1], c[2], c[3])
    self.tag:SetWidth((self.tag.text:GetStringWidth() or 40) + 20)
    self.tag:Show()
  end
  b.onEnterExtra = function(self) if self.active ~= false then self.halo:Show() end end
  b.onLeaveExtra = function(self) self.halo:Hide() end
  W.tooltip(b, function(tt, self)
    local info = self.info
    if not info then return end
    W.fillItemTooltip(tt, info.kind, info.id, info)
  end, "ANCHOR_TOP")
  return b
end

-- Bulle de dialogue (parchemin bordé) avec pointe facultative.
local function bubble(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(370, 100)
  f.shape = W.shape(f, 14, C.wood, C.parchmentLight, 3, -6, 0.2)
  f.title = W.label(f, "title", 16, C.wood)
  f.title:SetPoint("TOPLEFT", 18, -12)
  f.text = W.label(f, "body", 15, C.ink)
  f.text:SetWidth(334)
  f.text:SetJustifyH("LEFT")
  f.text:SetWordWrap(true)
  f.tail = CreateFrame("Frame", nil, f)
  f.tail:SetSize(22, 22)
  f.tail.edge = W.rect(f.tail, "BACKGROUND", -8, C.wood)
  f.tail.edge:SetAllPoints()
  f.tail.fill = W.rect(f.tail, "BACKGROUND", -7, C.parchmentLight)
  f.tail.fill:SetPoint("TOPLEFT", 3, -3)
  f.tail.fill:SetPoint("BOTTOMRIGHT", -3, 3)
  if f.tail.edge.SetRotation then
    f.tail.edge:SetRotation(math.pi / 4)
    f.tail.fill:SetRotation(math.pi / 4)
  end
  f.tail:SetFrameLevel(f:GetFrameLevel())
  f.Set = function(self, title, text, edge, tail)
    self.title:SetText(title or "")
    self.text:ClearAllPoints()
    if title and title ~= "" then
      self.text:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -8)
    else
      self.text:SetPoint("TOPLEFT", 18, -14)
    end
    self.text:SetText(text or "")
    local h = (self.text.GetStringHeight and self.text:GetStringHeight()) or 60
    if type(h) ~= "number" or h <= 0 then h = 60 end
    self:SetHeight(h + ((title and title ~= "") and 52 or 30))
    self.shape.edge:SetColor(edge or C.wood)
    self.tail.edge:SetColorTexture(W.rgb(edge or C.wood))
    self.tail:ClearAllPoints()
    if tail == "right" then
      self.tail:SetPoint("CENTER", self, "BOTTOMRIGHT", -50, 1)
      self.tail:Show()
    elseif tail == "left" then
      self.tail:SetPoint("CENTER", self, "BOTTOMLEFT", 50, 1)
      self.tail:Show()
    else
      self.tail:Hide()
    end
  end
  return f
end

---------------------------------------------------------------------------
-- Accueil : classe, clé mythique, départ
---------------------------------------------------------------------------

local Start = { kinds = { "start" } }
UI.register("start", Start)

function Start:Build(f)
  self.hero = heroFigure(f)
  local panel = W.parchment(f, 12)
  at(panel, f, 280, 64, 560, 330)
  self.panel = panel
  self.title = W.label(panel, "title", 32, C.ink)
  self.title:SetPoint("TOP", 0, -18)
  self.title:SetText("Slay the Dragon")
  self.classButtons = {}
  for i = 1, 4 do
    local b = W.button(panel, "", 220, 52, nil, "parchment", 16)
    b.sub = W.label(b, "body", 11, C.inkSoft)
    b.sub:SetPoint("TOP", b.label, "BOTTOM", 0, -2)
    b.label:ClearAllPoints()
    b.label:SetPoint("CENTER", 0, 7)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.classButtons[i] = b
  end
  self.keyLabel = W.label(panel, "title", 15, C.wood)
  self.keyLabel:SetPoint("TOP", 0, -150)
  self.keyLabel:SetText("Clé mythique")
  self.keyButtons = {}
  for i = 1, 6 do
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(46, 46)
    b.ring = W.disc(b, "BACKGROUND", 0, C.gold)
    b.ring:SetAllPoints()
    b.fill = W.disc(b, "BACKGROUND", 1, C.key)
    b.fill:SetPoint("TOPLEFT", 3, -3)
    b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    b.label = W.label(b, "title", 16, C.frame)
    b.label:SetPoint("CENTER")
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    W.tooltip(b, function(tt, btn)
      local o = btn.option
      if not o then return end
      tt:AddLine("Clé +" .. o.label:gsub("^%+", ""), 1, 0.82, 0)
      if o.text then tt:AddLine(o.text, 1, 1, 1, true) end
      if o.disabled and o.reason then tt:AddLine(o.reason, 1, 0.3, 0.3, true) end
    end, "ANCHOR_TOP")
    b:Hide()
    self.keyButtons[i] = b
  end
  self.affixIcons = {}
  for i = 1, 6 do
    local b = W.iconButton(panel, 30, "round")
    b:Hide()
    self.affixIcons[i] = b
  end
  self.note = W.label(f, "body", 13, C.cream, "OVERLAY", true)
  at(self.note, f, 190, 440, 590, 0)
  self.note:SetWidth(600)
  self.note:SetJustifyH("CENTER")
  self.note:SetWordWrap(true)
  self.go = W.button(f, "Partir en expédition", 230, 52, nil, "gold", 16)
  at(self.go, f, 790, 492, 230, 52)
  self.go:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  self.meta = W.button(f, "Réputation et journal", 200, 34, nil, "wood", 13)
  at(self.meta, f, 20, 500, 200, 34)
  self.meta:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  self.optionButtons = {}
end

function Start:Show(step)
  self.step = step
  UI.setStage({ scene = "road", board = true, veil = 0.2 })
  Scene.playerFigure(self.hero)
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
      b:SetPoint("TOP", self.panel, "TOP", (i - (#classes + 1) / 2) * 232, -70)
      b.option = o
      b:SetText(o.label)
      b.sub:SetText(o.text or "")
      b.shape.edge:SetColor(o.selected and C.gold or C.edgeCommon)
      b:Show()
      self.optionButtons[o.id] = b
    else
      b.option = nil
      b:Hide()
    end
  end
  for i, b in ipairs(self.keyButtons) do
    local o = keys[i]
    if o then
      b:ClearAllPoints()
      b:SetPoint("TOP", self.panel, "TOP", (i - (#keys + 1) / 2) * 56, -176)
      b.option = o
      b.label:SetText(o.label)
      local ring = o.selected and C.creamLight or (o.disabled and C.woodLine or C.gold)
      b.ring:SetVertexColor(ring[1], ring[2], ring[3], 1)
      local fill = o.disabled and C.woodDark or C.key
      b.fill:SetVertexColor(fill[1], fill[2], fill[3], 1)
      local lc = o.disabled and C.woodLine or C.frame
      b.label:SetTextColor(lc[1], lc[2], lc[3])
      b:SetScale(o.selected and 1.15 or 1)
      b:Show()
      self.optionButtons[o.id] = b
    else
      b.option = nil
      b:Hide()
    end
  end
  local aff = step.affixes or {}
  for i, b in ipairs(self.affixIcons) do
    local id = aff[i]
    if id then
      b:ClearAllPoints()
      b:SetPoint("TOP", self.panel, "TOP", (i - (#aff + 1) / 2) * 36, -240)
      b:SetItem("affix", id)
      b:Show()
    else
      b:Hide()
    end
  end
  self.note:SetText(step.text or "")
  for _, o in ipairs(others) do
    if o.id == "go" then
      self.go.option = o
      self.optionButtons[o.id] = self.go
    else
      self.meta.option = o
      self.meta:SetText(o.label)
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
-- Rencontre (et bibelot de classe) : bulle, personnage, plaques de réponses
---------------------------------------------------------------------------

local Choice = { kinds = { "choice", "startRelic", "event" } }
UI.register("choice", Choice)

local RARITY_EDGE = { rare = C.goldDeep, story = Art.hex("#7b4bb3") }

function Choice:Build(f)
  self.hero = heroFigure(f)
  self.npc = Scene.figure(f, 170, 200)
  at(self.npc, f, 765, 146, 170, 200)
  self.npc:EnableMouse(false)
  self.speaker = W.label(f, "body", 14, C.cream, "OVERLAY", true)
  at(self.speaker, f, 770, 350, 160, 0)
  self.speaker:SetWidth(160)
  self.speaker:SetJustifyH("CENTER")
  self.bubble = bubble(f)
  at(self.bubble, f, 380, 64)
  self.buttons = {}
  for i = 1, 4 do
    local b = plaque(f)
    b:Hide()
    self.buttons[i] = b
  end
  self.optionButtons = {}
end

function Choice:Show(step)
  self.step = step
  local npcShown = step.kind == "event" and Scene.npcFigure(self.npc, step.npc) or false
  if not npcShown then self.npc.model:Hide() self.npc.shadow:Hide() end
  UI.setStage({ scene = step.scene or Controller.scene(), board = true })
  Scene.playerFigure(self.hero)
  self.speaker:SetText(step.kind == "event" and (step.speaker or "") or "")
  local edge = RARITY_EDGE[step.rarity or ""] or C.wood
  self.bubble:Set(step.title, step.text, edge, npcShown and "right" or nil)
  self.bubble:SetWidth(npcShown and 370 or 470)
  at(self.bubble, self.frame, npcShown and 380 or 282, 64)
  self.optionButtons = {}
  local opts = step.options or {}
  local n = min(#opts, #self.buttons)
  local span = n <= 2 and 734 or (n == 3 and 900 or 980)
  local gap = 22
  local w = (span - (n - 1) * gap) / max(n, 1)
  local h = n >= 4 and 116 or 124
  local x0 = (Scene.W - span) / 2
  for i, b in ipairs(self.buttons) do
    local o = opts[i]
    if o and i <= n then
      at(b, self.frame, x0 + (i - 1) * (w + gap), 456)
      b:SetOption(o, w, h)
      self.optionButtons[o.id] = b
    else
      b.option = nil
      b:Hide()
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
-- Feu de camp : un feu, un couchage (repos), un grimoire (améliorer)
---------------------------------------------------------------------------

local Camp = { kinds = { "campfire" } }
UI.register("campfire", Camp)

function Camp:Build(f)
  self.hero = heroFigure(f)
  -- Le feu : bûches, flammes en couches qui vacillent, lueur.
  local fire = CreateFrame("Frame", nil, f)
  at(fire, f, 457, 230, 120, 120)
  fire.glow = W.disc(fire, "BACKGROUND", 0, C.gold, 0.22)
  fire.glow:SetSize(300, 130)
  fire.glow:SetPoint("BOTTOM", 0, -30)
  for i, rot in ipairs({ 0.35, -0.35 }) do
    local log = W.rect(fire, "ARTWORK", 0, Art.hex("#5c3418"))
    log:SetSize(96, 14)
    log:SetPoint("BOTTOM", 0, 6 + i)
    if log.SetRotation then log:SetRotation(rot) end
  end
  fire.outer = W.disc(fire, "ARTWORK", 1, Art.hex("#e2863b"))
  fire.outer:SetSize(62, 92)
  fire.outer:SetPoint("BOTTOM", 0, 12)
  fire.inner = W.disc(fire, "ARTWORK", 2, C.gold)
  fire.inner:SetSize(38, 62)
  fire.inner:SetPoint("BOTTOM", 0, 14)
  fire.core = W.disc(fire, "ARTWORK", 3, C.creamLight)
  fire.core:SetSize(18, 30)
  fire.core:SetPoint("BOTTOM", 0, 16)
  local t = 0
  fire:SetScript("OnUpdate", function(_, el)
    t = t + (el or 0)
    local a = math.sin(t * 9) * 0.5 + math.sin(t * 13.7) * 0.5
    fire.outer:SetSize(62 + a * 5, 92 + a * 9)
    fire.inner:SetSize(38 - a * 3, 62 + a * 6)
    fire.glow:SetAlpha(0.2 + 0.05 * a)
  end)
  self.fire = fire

  self.rest = groundObject(f, 92, "square")
  at(self.rest, f, 250, 250, 92, 92)
  W.setIcon(self.rest.icon, Art.ui.bedroll, "ui:bedroll")
  self.rest:SetScript("OnClick", function(b) chooseOption(b.option) end)
  self.book = groundObject(f, 92, "square")
  at(self.book, f, 690, 250, 92, 92)
  W.setIcon(self.book.icon, Art.ui.grimoire, "ui:grimoire")
  self.book:SetScript("OnClick", function(b) chooseOption(b.option) end)
  self.pile = deckPile(f)
  self.leave = W.button(f, "Reprendre la route", 200, 52, nil, "gold", 16)
  at(self.leave, f, 808, 492, 200, 52)
  self.leave:SetScript("OnClick", function(b) chooseOption(b.option) end)
  self.optionButtons = {}
end

function Camp:Show(step)
  self.step = step
  UI.setStage({ scene = "night", board = true })
  Scene.playerFigure(self.hero)
  self.pile:Sync()
  self.optionButtons = {}
  for _, o in ipairs(step.options) do
    if o.id == "rest" then
      self.rest.option = o
      local heal = (o.text or ""):match("(%d+)")
      self.rest:SetTag(heal and ("+" .. heal .. " PV") or o.label, C.healText)
      self.rest.info = { title = o.label, text = o.text, reason = o.disabled and o.reason or nil }
      self.rest.active = not o.disabled
      self.rest:SetAlpha(o.disabled and 0.5 or 1)
      self.optionButtons[o.id] = self.rest
    elseif o.id == "ui:upgrade" then
      self.book.option = o
      self.book:SetTag("Améliorer une carte", C.gold)
      self.book.info = { title = o.label, reason = o.disabled and o.reason or nil }
      self.book.active = not o.disabled
      self.book.icon:SetDesaturated(o.disabled and true or false)
      self.book:SetAlpha(o.disabled and 0.5 or 1)
      self.optionButtons[o.id] = self.book
    elseif o.id == "leave" then
      self.leave.option = o
      self.optionButtons[o.id] = self.leave
    end
  end
end

function Camp:HandleKey(key)
  local idx = UI.keyIndex(key)
  if idx == 1 then chooseOption(self.rest.option) return true end
  if idx == 2 then chooseOption(self.book.option) return true end
  if key == "ENTER" or key == "SPACE" then chooseOption(self.leave.option) return true end
  return idx ~= nil
end

---------------------------------------------------------------------------
-- Récompense : 3 cartes en grand, butin au sol, deck, « Reprendre la route » ; coffre à ouvrir
---------------------------------------------------------------------------

local Reward = { kinds = { "reward" } }
UI.register("reward", Reward)

local REWARD_CARDS = { { 378, 118 + 111 }, { 563, 118 + 111 }, { 748, 118 + 111 } } -- centres
local REWARD_SCALE = 1.26

function Reward:Build(f)
  self.hero = heroFigure(f)
  self.bubble = bubble(f)
  self.bubble:SetWidth(470)
  at(self.bubble, f, 282, 54)
  self.cards = {}
  for i = 1, 4 do
    local c = W.card(f)
    c:SetScript("OnClick", function(card) Reward:Pick(card) end)
    c.onEnterExtra = function(card) card.hover = true Reward:PlaceCard(card) end
    c.onLeaveExtra = function(card) card.hover = false Reward:PlaceCard(card) end
    c:Hide()
    self.cards[i] = c
  end
  -- butin au sol
  self.goldBag = groundObject(f, 62, "bag")
  at(self.goldBag, f, 868, 296, 62, 62)
  W.setIcon(self.goldBag.icon, Art.ui.gold, "ui:gold")
  self.goldBag.icon:SetAlpha(0.45)
  self.goldBag:SetScript("OnClick", function() Reward:Collect("gold") end)
  self.flask = groundObject(f, 48, "flask")
  at(self.flask, f, 950, 300, 42, 56)
  self.flask:SetSize(42, 56)
  self.flask:SetScript("OnClick", function() Reward:Collect("potion") end)
  self.relic = groundObject(f, 54, "square")
  at(self.relic, f, 898, 222, 54, 54)
  self.relic:SetScript("OnClick", function() Reward:Collect("relic") end)
  -- coffre fermé
  self.chest = groundObject(f, 120, "square")
  at(self.chest, f, 457, 190, 120, 120)
  W.setIcon(self.chest.icon, Art.ui.chest, "ui:chest")
  self.chest:SetScript("OnClick", function() Reward:OpenChest() end)
  self.loot = CreateFrame("Frame", nil, f) -- compatibilité harnais : butin affiché
  self.loot:SetSize(1, 1)
  self.pile = deckPile(f)
  self.leave = W.button(f, "Reprendre la route", 200, 52, nil, "gold", 16)
  at(self.leave, f, 808, 492, 200, 52)
  self.leave:SetScript("OnClick", function() Reward:Leave() end)
  self.optionButtons = {}
end

function Reward:PlaceCard(card)
  if not card.cx then return end
  local up = card.hover
  local sc = up and REWARD_SCALE * 1.09 or REWARD_SCALE
  W.placeCenter(card, self.frame, card.cx, card.cy - (up and 18 or 0), sc)
  card:SetFrameLevel(self.frame:GetFrameLevel() + 10 + (up and 20 or card.slot))
  card:SetHot(up)
end

function Reward:Show(step)
  self.step = step
  local exp = Controller.exp()
  local r = exp and exp.reward
  UI.setStage({ scene = Controller.scene(), board = true })
  Scene.playerFigure(self.hero)
  -- Nouveau butin : on le retient au sol tant qu'il n'est pas ramassé (cosmétique).
  if r ~= self.rewardRef then
    self.rewardRef = r
    self.leaving = false
    self.opened = not (r and r.kind == "chest")
    UI.hold = {}
    if r then
      UI.hold.gold = (r.goldGained or 0) > 0 and r.goldGained or nil
      UI.hold.relic = r.relic
      if r.potion and r.potionTaken then
        UI.hold.potion = r.potion
        local pots = Controller.potions() or {}
        for i = #pots, 1, -1 do if pots[i] == r.potion then UI.hold.potionSlot = i break end end
      end
    end
  end
  self.pile:Sync()
  self.optionButtons = {}
  self.cardOptions = {}
  local closed = not self.opened
  if closed then
    self.chest:Show()
    self.chest.info = { title = "Coffre" }
  else
    self.chest:Hide()
  end
  -- bulle : texte « après coup » d'une rencontre
  if step.rewardKind == "event" and step.after and not closed then
    local txt = step.after:gsub("\n?Choisis une carte à ajouter à ton deck%.", "")
    self.bubble:Set(step.title, txt)
    self.bubble:Show()
  else
    self.bubble:Hide()
  end
  local k = 0
  for _, o in ipairs(step.options) do
    if o.card then
      k = k + 1
      self.cardOptions[k] = o
      local card = self.cards[k]
      if card and not closed then
        card.option, card.slot = o, k
        card.cx, card.cy = REWARD_CARDS[k] and REWARD_CARDS[k][1] or (378 + (k - 1) * 185), 229
        card:SetCard(o.card.id, o.card.up, { playable = not o.disabled, reason = o.disabled and o.reason or nil })
        self:PlaceCard(card)
        card:SetAlpha(1)
        card:Show()
        self.optionButtons[o.id] = card
      end
    elseif o.id == "takePotion" then
      self.optionButtons[o.id] = self.flask
    elseif o.id == "leave" then
      self.leave.option = o
      self.optionButtons[o.id] = self.leave
    end
  end
  for i = k + 1, #self.cards do
    self.cards[i].option, self.cards[i].cx = nil, nil
    self.cards[i]:Hide()
  end
  if closed then for i = 1, #self.cards do self.cards[i]:Hide() end end
  -- butin
  local loot = {}
  local hold = UI.hold
  local r2 = r or {}
  self.goldBag.info = r2.goldGained and { title = "Bourse", text = "+" .. r2.goldGained .. " po" } or nil
  if hold.gold and not closed then
    self.goldBag.big:SetText(tostring(hold.gold))
    self.goldBag:Show()
    loot[#loot + 1] = "gold"
  else
    self.goldBag:Hide()
  end
  if r2.relic and hold.relic and not closed then
    self.relic.info = { kind = "relic", id = r2.relic }
    W.setIcon(self.relic.icon, Art.relic(r2.relic), "relic:" .. r2.relic)
    self.relic:Show()
    loot[#loot + 1] = "relic"
  else
    self.relic:Hide()
  end
  local pendingPotion = r2.potion and not r2.potionTaken
  if r2.potion and (hold.potion or pendingPotion) and not closed then
    self.flask.info = { kind = "potion", id = r2.potion,
      hint = pendingPotion and "Tes emplacements de potion sont pleins : jettes-en une (clic droit dans le bandeau)." or nil }
    W.setIcon(self.flask.icon, Art.potion(r2.potion), "potion:" .. r2.potion)
    self.flask.icon:SetDesaturated(pendingPotion and true or false)
    self.flask:SetTag(pendingPotion and "Pas de place" or nil, C.hpText)
    self.flask:Show()
    loot[#loot + 1] = "potion"
  else
    self.flask:Hide()
  end
  step.loot = step.loot or {}
  if #step.loot > 0 then self.loot:Show() else self.loot:Hide() end
end

function Reward:OpenChest()
  if self.opened then return end
  self.opened = true
  W.sound("coin")
  local chest = self.chest
  W.tween(0.35, function(p) chest:SetAlpha(1 - p) chest:SetScale(1 + 0.3 * p) end, function()
    chest:Hide() chest:SetAlpha(1) chest:SetScale(1)
  end, chest, "open")
  self:Show(self.step)
end

-- Prend une carte : elle file vers le tas du deck, les autres s'effacent.
function Reward:Pick(card)
  local o = card.option
  if not o then return end
  if o.disabled then UI.flash(o.reason or "Indisponible.") return end
  local g = W.ghostCard(self.frame)
  g:SetFrameLevel(self.frame:GetFrameLevel() + 60)
  g:SetCard(card.cardId, card.cardUp, {})
  local x, y = card.cx, card.cy
  W.sound("pick")
  if UI.choose(o.id) then
    W.fly(g, self.frame, x, y, 96, 518, REWARD_SCALE, 0.4, 1, 0.3, 0.45, function() W.releaseGhost(g) end, 60)
  else
    W.releaseGhost(g)
  end
end

-- Ramasse un objet du butin : il file vers le bandeau.
function Reward:Collect(kind, silent)
  local hold = UI.hold
  local obj = kind == "gold" and self.goldBag or (kind == "relic" and self.relic or self.flask)
  local exp = Controller.exp()
  local r = exp and exp.reward
  if kind == "potion" and r and r.potion and not r.potionTaken then
    local o
    for _, op in ipairs(self.step.options) do if op.id == "takePotion" then o = op end end
    if not o or o.disabled then
      if not silent then UI.flash(o and o.reason or "Tes emplacements de potion sont pleins.") end
      return
    end
    UI.choose("takePotion")
    return
  end
  if not obj:IsShown() or not hold[kind] then return end
  hold[kind] = nil
  if kind == "potion" then hold.potionSlot = nil end
  W.sound(kind == "gold" and "coin" or "pick")
  local x, y = obj.cx or 0, obj.cy or 0
  local tx, ty = UI.bandTarget(kind)
  local p, rel, rp, ox, oy = obj:GetPoint(1)
  local bx, by = (ox or 0) + obj:GetWidth() / 2, -(oy or 0) + obj:GetHeight() / 2
  if p ~= "TOPLEFT" then bx, by = x, y end
  W.tween(0.45, function(t)
    obj:ClearAllPoints()
    obj:SetPoint("CENTER", self.frame, "TOPLEFT", bx + (tx - bx) * t, -(by + (ty - by) * t - 60 * 4 * t * (1 - t)))
    obj:SetAlpha(1 - 0.6 * t)
  end, function()
    obj:Hide()
    obj:SetAlpha(1)
    obj:ClearAllPoints()
    if p then obj:SetPoint(p, rel, rp, ox, oy) end
    UI.refreshInfo()
  end, obj, "collect", W.ease.inOut)
end

function Reward:Leave()
  if self.leaving then return end
  local o = self.leave.option
  if not o then return end
  if o.disabled then UI.flash(o.reason or "Indisponible.") return end
  self.leaving = true
  local any = false
  for _, k in ipairs({ "gold", "relic", "potion" }) do
    if UI.hold[k] then any = true self:Collect(k, true) end
  end
  W.delay((any and 0.5 or 0) * W.pace(), function()
    self.leaving = false
    UI.hold = {}
    if UI.current == self then UI.choose("leave") end
  end)
end

function Reward:OnHide()
  UI.hold = {}
end

function Reward:HandleKey(key)
  local idx = UI.keyIndex(key)
  if idx then
    if not self.opened then self:OpenChest() return true end
    local o = self.cardOptions and self.cardOptions[idx]
    local card = o and self.optionButtons[o.id]
    if card then self:Pick(card) end
    return true
  end
  if key == "SPACE" or key == "ENTER" then
    if not self.opened then self:OpenChest() else self:Leave() end
    return true
  end
  return false
end

---------------------------------------------------------------------------
-- Grille du deck : amélioration, retrait, sélection de rencontre
---------------------------------------------------------------------------

local Deck = { kinds = { "deck", "select" } }
UI.register("deck", Deck)

local PER_PAGE, PER_ROW, GRID_SCALE = 16, 8, 0.8

function Deck:Build(f)
  local panel = W.woodPanel(f, 12)
  at(panel, f, 16, 54, 1002, 362)
  self.panel = panel
  self.title = W.label(panel, "title", 18, C.gold)
  self.title:SetPoint("TOP", 0, -12)
  self.cards = {}
  for i = 1, PER_PAGE do
    local c = W.card(f)
    c:SetFrameLevel(panel:GetFrameLevel() + 5)
    c:SetScript("OnClick", function(card) chooseOption(card.option) end)
    c.onEnterExtra = function(card) card.hover = true Deck:PlaceCard(card) end
    c.onLeaveExtra = function(card) card.hover = false Deck:PlaceCard(card) end
    c:Hide()
    self.cards[i] = c
  end
  self.prev = W.button(f, "‹", 34, 34, function() self.page = self.page - 1 self:Layout() end, "wood", 18)
  at(self.prev, f, 24, 214, 34, 34)
  self.next = W.button(f, "›", 34, 34, function() self.page = self.page + 1 self:Layout() end, "wood", 18)
  at(self.next, f, 976, 214, 34, 34)
  self.pile = deckPile(f)
  self.buttons = {}
  for i = 1, 2 do
    local b = W.button(f, "", 200, 52, nil, i == 1 and "gold" or "wood", 16)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.buttons[i] = b
  end
  self.page = 1
  self.optionButtons = {}
end

function Deck:PlaceCard(card)
  if not card.cx then return end
  local up = card.hover
  local sc = up and GRID_SCALE * 1.2 or GRID_SCALE
  W.placeCenter(card, self.frame, card.cx, card.cy - (up and 8 or 0), sc)
  card:SetFrameLevel(self.panel:GetFrameLevel() + 5 + (up and 40 or card.slot))
  -- aperçu de l'amélioration au survol
  if card.option and card.option.preview then
    card:SetCard(card.option.card.id, card.option.card.up, { preview = true, showUp = up,
      playable = not card.option.disabled, reason = card.option.disabled and card.option.reason or nil })
  end
  card:SetHot(up)
end

function Deck:Show(step)
  if not self.step or self.step.title ~= step.title or self.step.kind ~= step.kind then self.page = 1 end
  self.step = step
  UI.setStage({ scene = Controller.scene(), board = true, veil = 0.35 })
  self.title:SetText(step.title or "")
  self.pile:Sync()
  self.cardOptions, self.otherOptions = {}, {}
  for i = 1, #step.options do
    local o = step.options[i]
    if o.card then self.cardOptions[#self.cardOptions + 1] = o else self.otherOptions[#self.otherOptions + 1] = o end
  end
  self:Layout()
end

function Deck:Layout()
  local list = self.cardOptions
  local pages = max(1, math.ceil(#list / PER_PAGE))
  if self.page > pages then self.page = pages end
  if self.page < 1 then self.page = 1 end
  local first = (self.page - 1) * PER_PAGE
  local count = min(PER_PAGE, #list - first)
  local cw, ch = W.CARD_W * GRID_SCALE, W.CARD_H * GRID_SCALE
  local gapX = 16
  local rowW = min(PER_ROW, count) * (cw + gapX) - gapX
  local x0 = (Scene.W - rowW) / 2
  self.optionButtons = {}
  for i = 1, PER_PAGE do
    local card = self.cards[i]
    local o = list[first + i]
    if o and i <= count then
      local col, row = (i - 1) % PER_ROW, floor((i - 1) / PER_ROW)
      card.cx = x0 + col * (cw + gapX) + cw / 2
      card.cy = 100 + row * (ch + 12) + ch / 2
      card.option, card.slot = o, i
      card:SetCard(o.card.id, o.card.up, { preview = o.preview, playable = not o.disabled,
        reason = o.disabled and o.reason or nil })
      self:PlaceCard(card)
      card:Show()
      self.optionButtons[o.id] = card
    else
      card.option, card.cx = nil, nil
      card:Hide()
    end
  end
  for i = 1, #self.buttons do
    local b, o = self.buttons[i], self.otherOptions[#self.otherOptions - i + 1]
    if o then
      b.option = o
      b:SetText(o.label or o.id)
      at(b, self.frame, 808 - (i - 1) * 216, 492, 200, 52)
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

function Deck:HandleKey(key)
  local idx = UI.keyIndex(key)
  if idx then
    chooseOption(self.cardOptions[(self.page - 1) * PER_PAGE + idx])
    return true
  end
  if key == "SPACE" or key == "ENTER" then
    chooseOption(self.otherOptions[#self.otherOptions])
    return true
  end
  return false
end

---------------------------------------------------------------------------
-- Marchand : étal (cartes, bibelots, fioles avec étiquettes de prix), retrait de carte
---------------------------------------------------------------------------

local Shop = { kinds = { "merchant" } }
UI.register("shop", Shop)

function Shop:Build(f)
  -- l'étal : comptoir de bois et tenture
  local stall = CreateFrame("Frame", nil, f)
  at(stall, f, 24, 70, 986, 300)
  local cloth = W.rect(stall, "BACKGROUND", -8, Art.hex("#7a2a1e"), 0.85)
  at(cloth, stall, 0, 0, 986, 18)
  for i = 0, 12 do
    local scallop = W.disc(stall, "BACKGROUND", -8, Art.hex("#7a2a1e"), 0.85)
    at(scallop, stall, i * 78, 8, 80, 22)
  end
  local counter = W.rect(stall, "BACKGROUND", -7, C.wood)
  at(counter, stall, 0, 254, 986, 46)
  local top = W.rect(stall, "BACKGROUND", -6, C.woodLine)
  at(top, stall, 0, 254, 986, 6)
  local grain = stall:CreateTexture(nil, "BACKGROUND", nil, -5)
  grain:SetTexture(Art.tex.wood)
  at(grain, stall, 0, 260, 986, 40)
  grain:SetVertexColor(0.55, 0.38, 0.24)
  grain:SetAlpha(0.4)
  self.stall = stall

  self.cards = {}
  for i = 1, 7 do
    local c = W.card(f)
    c:SetScript("OnClick", function(card) chooseOption(card.option) end)
    c.onEnterExtra = function(card) card.hover = true Shop:PlaceCard(card) end
    c.onLeaveExtra = function(card) card.hover = false Shop:PlaceCard(card) end
    c:Hide()
    self.cards[i] = c
  end
  self.items = {}
  for i = 1, 8 do
    local b = groundObject(f, 56, "square")
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.items[i] = b
  end
  -- service : retrait de carte (plaque sur le plateau)
  self.remove = plaque(f)
  self.remove:Hide()
  self.pile = deckPile(f)
  self.leave = W.button(f, "Partir", 200, 52, nil, "gold", 16)
  at(self.leave, f, 808, 492, 200, 52)
  self.leave:SetScript("OnClick", function(b) chooseOption(b.option) end)
  self.optionButtons = {}
end

local SHOP_SCALE = 0.92

function Shop:PlaceCard(card)
  if not card.cx then return end
  local up = card.hover
  local sc = up and SHOP_SCALE * 1.12 or SHOP_SCALE
  W.placeCenter(card, self.frame, card.cx, card.cy - (up and 10 or 0), sc)
  card:SetFrameLevel(self.frame:GetFrameLevel() + 10 + (up and 30 or card.slot))
  card:SetHot(up)
end

function Shop:Show(step)
  self.step = step
  UI.setStage({ scene = "shop", board = true })
  self.pile:Sync()
  local cards, relics, potions, services = {}, {}, {}, {}
  for _, o in ipairs(step.options) do
    if o.card then cards[#cards + 1] = o
    elseif o.item and o.item.kind == "relic" then relics[#relics + 1] = o
    elseif o.item then potions[#potions + 1] = o
    else services[#services + 1] = o end
  end
  self.cardOptions = cards
  self.serviceOptions = services
  self.optionButtons = {}
  local n = min(#cards, #self.cards)
  local cw = W.CARD_W * SHOP_SCALE
  local gap = 16
  local rowW = n * (cw + gap) - gap
  local x0 = 30 + (660 - rowW) / 2
  for i = 1, #self.cards do
    local card, o = self.cards[i], cards[i]
    if o and i <= n then
      card.option, card.slot = o, i
      card.cx = x0 + (i - 1) * (cw + gap) + cw / 2
      card.cy = 92 + W.CARD_H * SHOP_SCALE / 2
      card:SetCard(o.card.id, o.card.up, { price = o.price, sold = o.sold, tooPoor = o.disabled and not o.sold,
        playable = true })
      self:PlaceCard(card)
      card:Show()
      self.optionButtons[o.id] = card
    else
      card.option, card.cx = nil, nil
      card:Hide()
    end
  end
  -- Bibelots (rangée du haut) puis fioles, à droite de l'étal.
  local k = 0
  local function place(list, y, shape)
    for i, o in ipairs(list) do
      k = k + 1
      local b = self.items[k]
      if b then
        local x = 780 + (i - 1) * 78 - ((#list - 1) * 78) / 2 + 78
        b.cx, b.cy = x, y + 28
        at(b, self.frame, x - 28, y, 56, 56)
        b.option = o
        b.info = { kind = o.item.kind, id = o.item.id, price = o.price, reason = o.disabled and o.reason or nil }
        W.setIcon(b.icon, W.itemEntry(o.item.kind, o.item.id), o.item.kind .. ":" .. tostring(o.item.id))
        b.icon:SetDesaturated(o.sold and true or false)
        b.shape.edge:SetColor(o.item.kind == "relic"
          and (Art.rarity[(ns.Relics[o.item.id] or {}).rarity or "common"] or C.cream) or C.cream)
        if o.sold then b:SetTag("Vendu", { 0.6, 0.6, 0.6 })
        else b:SetTag(o.price .. " po", o.disabled and C.hpText or C.gold) end
        b.active = not o.disabled
        b:SetAlpha(o.sold and 0.45 or 1)
        b:Show()
        self.optionButtons[o.id] = b
      end
    end
  end
  place(relics, 96, "square")
  place(potions, 214, "flask")
  for i = k + 1, #self.items do self.items[i].option = nil self.items[i]:Hide() end
  for _, o in ipairs(services) do
    if o.id == "leave" then
      self.leave.option = o
      self.optionButtons[o.id] = self.leave
    else
      local label = { id = o.id, label = o.label, text = (o.price and (o.price .. " po") or ""),
        disabled = o.disabled, reason = o.reason }
      at(self.remove, self.frame, 330, 462)
      self.remove:SetOption(label, 300, 104)
      self.remove.option = o
      self.optionButtons[o.id] = self.remove
    end
  end
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
-- Carte de parcours : parchemin, symboles par type, halo des étapes accessibles, chemin parcouru
---------------------------------------------------------------------------

local Map = { kinds = { "map" } }
UI.register("map", Map)

local MAP_X0, MAP_X1, BOSS_X = 110, 790, 900
local MAP_Y0, MAP_Y1 = 150, 440

local NODE_FILL = { combat = C.nodeCombat, elite = C.nodeElite, boss = C.nodeDone }

function Map:Build(f)
  local parch = W.parchment(f, 8)
  at(parch, f, 20, 62, 994, 536)
  parch:EnableMouse(false)
  self.parch = parch
  -- chemins décoratifs
  for _, r in ipairs({ { 40, 470, 960, 16 }, { 60, 104, 200, 9 }, { 700, 98, 200, 9 } }) do
    local road = W.rect(parch, "BACKGROUND", -3, C.mapRoad, 0.6)
    at(road, parch, r[1] - 20, r[2] - 62, r[3], r[4])
  end
  self.canvas = CreateFrame("Frame", nil, f)
  self.canvas:SetAllPoints()
  self.canvas:SetFrameLevel(parch:GetFrameLevel() + 2)
  self.nodes = {}
  self.lines = {}
  self.dots = {}
  self.optionButtons = {}
end

local function nodeButton(self, i)
  local b = CreateFrame("Button", nil, self.canvas)
  b:SetSize(46, 46)
  b:SetFrameLevel(self.canvas:GetFrameLevel() + 5)
  b.halo = W.disc(b, "BACKGROUND", 0, C.nodeHalo)
  b.halo:SetPoint("CENTER")
  b.outer = W.disc(b, "BACKGROUND", 1, C.creamLight)
  b.outer:SetPoint("CENTER")
  b.edge = W.disc(b, "BACKGROUND", 2, C.nodeFutureEdge)
  b.edge:SetAllPoints()
  b.fill = W.disc(b, "BACKGROUND", 3, C.nodeFuture)
  b.fill:SetPoint("TOPLEFT", 3, -3)
  b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 8, -8)
  b.icon:SetPoint("BOTTOMRIGHT", -8, 8)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  W.roundMask(b, b.icon)
  b.glyph = W.label(b, "title", 22, C.inkSoft)
  b.glyph:SetPoint("CENTER", 0, 0)
  b.check = b:CreateTexture(nil, "OVERLAY")
  b.check:SetTexture(Art.tex.check)
  b.check:SetSize(24, 24)
  b.check:SetPoint("CENTER")
  -- boss : losange
  b.dEdge = W.rect(b, "BACKGROUND", 2, C.ink)
  b.dEdge:SetSize(84, 84)
  b.dEdge:SetPoint("CENTER")
  b.dFill = W.rect(b, "BACKGROUND", 3, C.nodeDone)
  b.dFill:SetSize(76, 76)
  b.dFill:SetPoint("CENTER")
  b.dHalo = W.rect(b, "BACKGROUND", 1, C.nodeHalo)
  b.dHalo:SetSize(96, 96)
  b.dHalo:SetPoint("CENTER")
  for _, t in ipairs({ b.dEdge, b.dFill, b.dHalo }) do if t.SetRotation then t:SetRotation(math.pi / 4) end end
  b.bossText = W.label(b, "title", 22, C.creamLight)
  b.bossText:SetPoint("CENTER")
  b.bossText:SetText("Boss")
  b.bossName = W.label(b, "title", 15, C.ink)
  b.bossName:SetPoint("TOP", b, "BOTTOM", 0, -20)
  b:SetScript("OnClick", function(btn)
    local node = btn.node
    if node and node.state == "available" then W.sound("click") UI.choose(node.id)
    elseif node then UI.flash("Étape inaccessible.") end
  end)
  W.tooltip(b, function(tt, btn)
    local node = btn.node
    if node and node.kind ~= "event" then tt:AddLine(node.label or node.kind, 1, 0.82, 0) end
  end, "ANCHOR_TOP")
  self.nodes[i] = b
  return b
end

local function nodePos(node, floors)
  if node.kind == "boss" then return BOSS_X, (MAP_Y0 + MAP_Y1) / 2 end
  local f = node.floor or 1
  local x = MAP_X0 + (f - 1) / max(1, floors - 2) * (MAP_X1 - MAP_X0)
  local y = MAP_Y0 + (node.y or 0.5) * (MAP_Y1 - MAP_Y0)
  return x, y
end

local function paintNode(b, node, bossName)
  local st, kind = node.state, node.kind
  local boss = kind == "boss"
  local size = boss and 84 or (st == "current" and 60 or (st == "available" and 56 or 46))
  b:SetSize(size, size)
  for _, t in ipairs({ b.dEdge, b.dFill, b.dHalo, b.bossText, b.bossName }) do if boss then t:Show() else t:Hide() end end
  for _, t in ipairs({ b.edge, b.fill, b.halo, b.outer }) do if boss then t:Hide() end end
  b.check:Hide()
  b.glyph:Hide()
  b.icon:Hide()
  if boss then
    b.bossName:SetText(bossName or "")
    if st == "available" then b.dHalo:Show() else b.dHalo:Hide() end
    b.icon:SetTexture(nil)
    W.setIcon(b.icon, Art.ui.map.boss, "map:boss")
    return
  end
  b.edge:Show()
  b.fill:Show()
  b.halo:SetSize(size + 12, size + 12)
  b.outer:SetSize(size + 10, size + 10)
  if st == "available" then b.halo:Show() else b.halo:Hide() end
  if st == "current" then b.outer:Show() else b.outer:Hide() end
  local edge, fill = C.nodeFutureEdge, C.nodeFuture
  if st == "done" or st == "current" then
    edge, fill = st == "current" and C.gold or C.nodeDoneEdge, C.nodeDone
    b.check:SetSize(size * 0.5, size * 0.5)
    b.check:Show()
  elseif st == "available" then
    edge, fill = C.nodeRing, NODE_FILL[kind] or Art.hex("#7a5a2a")
  elseif kind == "elite" then
    edge = C.nodeElite
  end
  b.edge:SetVertexColor(edge[1], edge[2], edge[3], 1)
  b.fill:SetVertexColor(fill[1], fill[2], fill[3], 1)
  if st == "done" or st == "current" then
    W.setIcon(b.icon, Art.ui.map[kind] or Art.ui.map.event, "map:" .. tostring(kind))
    return
  end
  if kind == "event" then
    b.glyph:SetText("?")
    local gc = st == "available" and C.creamLight or C.inkSoft
    b.glyph:SetTextColor(gc[1], gc[2], gc[3])
    b.glyph:Show()
    W.setIcon(b.icon, Art.ui.map.event, "map:event")
    b.icon:Hide()
    return
  end
  W.setIcon(b.icon, Art.ui.map[kind] or Art.ui.map.event, "map:" .. tostring(kind))
  b.icon:Show()
  b.icon:SetDesaturated(st ~= "available")
  b.icon:SetAlpha(st == "available" and 1 or 0.7)
  if st ~= "available" then b.icon:SetVertexColor(0.85, 0.7, 0.5) else b.icon:SetVertexColor(1, 1, 1) end
end

-- Pointillés : petits disques le long d'un segment (pool).
function Map:Dots(x1, y1, x2, y2, color, size, step, startK)
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  local n = floor(len / step)
  local k = startK
  for j = 1, n - 1 do
    k = k + 1
    local d = self.dots[k]
    if not d then
      d = W.disc(self.canvas, "ARTWORK", 0, color)
      self.dots[k] = d
    end
    d:SetVertexColor(color[1], color[2], color[3], 1)
    d:SetSize(size, size)
    at(d, self.frame, x1 + dx * j / n - size / 2, y1 + dy * j / n - size / 2)
    d:Show()
  end
  return k
end

function Map:Show(step)
  self.step = step
  UI.setStage({ scene = false, board = false })
  local nodes = step.nodes or {}
  local floors = step.floors or 8
  local byId, stateOf, pos = {}, {}, {}
  self.optionButtons = {}
  for i = 1, max(#nodes, #self.nodes) do
    local node = nodes[i]
    local b = self.nodes[i] or (node and nodeButton(self, i))
    if node then
      b.node = node
      byId[node.id] = b
      stateOf[node.id] = node.state
      local x, y = nodePos(node, floors)
      pos[node.id] = { x, y }
      paintNode(b, node, step.bossName)
      b:ClearAllPoints()
      b:SetPoint("CENTER", self.frame, "TOPLEFT", x, -y)
      b:Show()
      self.optionButtons[node.id] = b
    elseif b then
      b.node = nil
      b:Hide()
    end
  end
  -- Liens : chemin parcouru en trait plein, départs possibles en pointillés dorés, le reste en pointillés.
  local k, kd = 0, 0
  self.linkCount = 0
  for i = 1, #nodes do
    local from = nodes[i]
    for j = 1, #(from.links or {}) do
      local to = from.links[j]
      local p1, p2 = pos[from.id], pos[to]
      if p1 and p2 then
        self.linkCount = self.linkCount + 1
        local s1, s2 = from.state, stateOf[to]
        local walked = (s1 == "done" or s1 == "current") and (s2 == "done" or s2 == "current")
        if walked and self.canvas.CreateLine then
          k = k + 1
          local line = self.lines[k]
          if not line then
            line = self.canvas:CreateLine(nil, "ARTWORK")
            self.lines[k] = line
          end
          line:SetThickness(5)
          line:SetColorTexture(C.nodeDone[1], C.nodeDone[2], C.nodeDone[3], 1)
          line:SetStartPoint("TOPLEFT", self.frame, p1[1], -p1[2])
          line:SetEndPoint("TOPLEFT", self.frame, p2[1], -p2[2])
          line:Show()
        elseif s1 == "current" and s2 == "available" or (s1 == nil and s2 == "available") then
          kd = self:Dots(p1[1], p1[2], p2[1], p2[2], C.nodeRing, 6, 14, kd)
        else
          kd = self:Dots(p1[1], p1[2], p2[1], p2[2], C.nodeFutureEdge, 4, 12, kd)
        end
      end
    end
  end
  for i = k + 1, #self.lines do self.lines[i]:Hide() end
  for i = kd + 1, #self.dots do self.dots[i]:Hide() end
  self.options = step.options or {}
  for _, o in ipairs(self.options) do
    if not self.optionButtons[o.id] then self.optionButtons[o.id] = byId[o.id] end
  end
end

function Map:HandleKey(key)
  local opts = self.step and self.step.options or {}
  local idx = UI.keyIndex(key)
  if idx then chooseOption(opts[idx]) return true end
  if (key == "ENTER" or key == "SPACE") and #opts == 1 then chooseOption(opts[1]) return true end
  return false
end

---------------------------------------------------------------------------
-- Bilan et méta : parchemin, barres de réputation, journal
---------------------------------------------------------------------------

local Progress = { kinds = { "end", "meta" } }
UI.register("progress", Progress)

function Progress:Build(f)
  local panel = W.parchment(f, 12)
  at(panel, f, 167, 60, 700, 356)
  self.panel = panel
  self.title = W.label(panel, "title", 28, C.ink)
  self.title:SetPoint("TOP", 0, -16)
  self.text = W.label(panel, "body", 13, C.ink)
  self.text:SetPoint("TOP", self.title, "BOTTOM", 0, -10)
  self.text:SetWidth(620)
  self.text:SetJustifyH("CENTER")
  self.text:SetWordWrap(true)
  self.bars = {}
  for i = 1, 5 do
    local b = W.repBar(panel, 440)
    b:Hide()
    self.bars[i] = b
  end
  self.journal = {}
  for i = 1, 8 do
    local fs = W.label(panel, "body", 12, C.inkSoft)
    fs:SetWidth(600)
    fs:SetJustifyH("LEFT")
    self.journal[i] = fs
  end
  self.buttons = {}
  for i = 1, 3 do
    local b = W.button(f, "", 220, 52, nil, i == 1 and "gold" or "wood", i == 1 and 16 or 13)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.buttons[i] = b
  end
  self.optionButtons = {}
end

function Progress:Show(step)
  self.step = step
  UI.setStage({ scene = step.kind == "end" and Controller.scene() or "road", board = true, veil = 0.45 })
  self.title:SetText(step.title or "")
  local tc = C.ink
  if step.kind == "end" then tc = step.won and C.green or C.numberInk end
  self.title:SetTextColor(tc[1], tc[2], tc[3])
  self.text:SetText(inkText(step.text))
  local bars = step.bars or {}
  local y0 = step.kind == "end" and -170 or -110
  for i, b in ipairs(self.bars) do
    local data = bars[i]
    if data then
      b:ClearAllPoints()
      b:SetPoint("TOP", self.panel, "TOP", 0, y0 - (i - 1) * 54)
      b:Set(data)
      b:Show()
    else
      b:Hide()
    end
  end
  local jy = y0 - #bars * 54 - 4
  local lines = step.journal or {}
  for i, fs in ipairs(self.journal) do
    local l = lines[i]
    fs:ClearAllPoints()
    fs:SetPoint("TOP", self.panel, "TOP", 0, jy - (i - 1) * 16)
    if l then
      fs:SetText(l.text)
      local c = l.won and C.green or C.inkSoft
      fs:SetTextColor(c[1], c[2], c[3])
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
      if i == 1 then at(b, self.frame, 790, 492, 220, 52) else at(b, self.frame, 24 + (i - 2) * 236, 500, 220, 36) end
      b:SetSize(220, i == 1 and 52 or 36)
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
