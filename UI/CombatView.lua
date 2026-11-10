-- Écran de combat (docs/maquette/Main.dc.html) : décor plein cadre, héros à gauche et ennemis à
-- droite posés au sol, bulle d'intention, barres de vie ; plateau de bois : orbe de mana, Démence,
-- pioche et défausse, main en arc, recharges, « Fin du tour ».
-- N'applique aucune règle : lit l'état du moteur (ns.Combat) et passe par ns.Controller (donc par
-- Expedition.act). L'état est à jour avant les animations : elles rejouent les événements dans une
-- file (cosmétique), puis l'écran se resynchronise sur le moteur.
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art, UI, Controller, Combat, Card, Scene = ns.Widgets, ns.Art, ns.UI, ns.Controller, ns.Combat, ns.Card,
  ns.Scene
local C = Art.C
local at = Scene.at
local max, min, abs, floor = math.max, math.min, math.abs, math.floor

local V = { kinds = { "combat" } }
UI.register("combat", V)

local SLOTS = 6
local SLOT_W, SLOT_H = 150, 280
local HERO_X = 196                       -- centre du héros
local HERO_FEET = 292
local ENEMY_X0, ENEMY_X1 = 470, 1022     -- zone des ennemis
local HAND_CX, HAND_W = 525, 670         -- main : centre et largeur
local HAND_TOP = 428
local HOVER_SCALE = 1.16
local DRAW_PILE = { 77, 584 }
local DISCARD_PILE = { 123, 584 }

local function now() return GetTime and GetTime() or 0 end
local function opts() return ns.Persist.options() end

local function enemyByUid(c, uid)
  for i = 1, #c.enemies do if c.enemies[i].uid == uid then return c.enemies[i], i end end
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

-- Bulle d'intention : fond sombre arrondi, liseré de couleur, icône ronde + chiffre.
local function intentBubble(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(80, 28)
  f:EnableMouse(true)
  f.shape = W.shape(f, 13, C.attack, C.band, 2, -4)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(18, 18)
  f.icon:SetPoint("LEFT", 10, 0)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  W.roundMask(f, f.icon)
  f.text = W.label(f, "title", 18, C.attackText)
  f.text:SetPoint("LEFT", f.icon, "RIGHT", 5, 0)
  W.tooltip(f, function(tt, self) V.fillIntentTooltip(tt, self.enemy) end, "ANCHOR_TOP")
  return f
end

local function buildSlot(self, i)
  local s = CreateFrame("Button", nil, self.bf)
  s:SetSize(SLOT_W, SLOT_H)
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s.index = i
  s.intent = intentBubble(s)
  s.intent:SetPoint("TOP", 0, 0)
  s.fig = Scene.figure(s, 150, 160)
  s.fig:SetPoint("TOP", 0, -33)
  s.fig:EnableMouse(false)
  s.model = s.fig.model
  s.fallback = s.fig.fallback
  s.flash = W.disc(s.fig, "OVERLAY", 0, C.hp, 0)
  s.flash:SetSize(110, 130)
  s.flash:SetPoint("CENTER", 0, 4)
  s.block = W.shieldBadge(s, 28, 22)
  s.block:SetPoint("RIGHT", s, "TOPLEFT", 4 + 5, -207)
  s.hp = W.hpBar(s, 140, 18, 12)
  s.hp:SetPoint("TOP", 0, -198)
  s.name = W.label(s, "body", 13, C.cream, "OVERLAY", true)
  s.name:SetPoint("TOP", 0, -220)
  s.name:SetWidth(SLOT_W + 10)
  s.st = W.pillRow(s, 6, SLOT_W + 10, 11)
  s.st:SetPoint("TOP", 0, -238)
  s:SetScript("OnClick", function(_, button) V:ClickEnemy(s, button) end)
  s:SetScript("OnEnter", function() s.hover = true V:RenderTargets() end)
  s:SetScript("OnLeave", function() s.hover = false V:RenderTargets() end)
  s:Hide()
  return s
end

-- Pile (pioche ou défausse) : petit tas de cartes avec nombre.
local function pile(self, parent, x, y, key, label, dashed, level)
  if not dashed then
    local back = CreateFrame("Frame", nil, parent)
    at(back, parent, x + 3, y + 3, 36, 48)
    back:SetFrameLevel(level)
    W.roundRect(back, "BACKGROUND", -8, 5, 0):SetColor(C.woodDark)
  end
  local b = CreateFrame("Frame", nil, parent)
  at(b, parent, x, y, 36, 48)
  b:SetFrameLevel(level + 1)
  b:EnableMouse(true)
  b.shape = W.shape(b, 5, dashed and C.woodLine or C.gold, dashed and C.woodDark or C.wood, 2, -6)
  b.count = W.label(b, "title", 18, dashed and C.parchment or C.creamLight)
  b.count:SetPoint("CENTER")
  W.tooltip(b, function(tt) V.fillPileTooltip(tt, key, label) end, "ANCHOR_RIGHT")
  return b
end

function V:Build(parent)
  self.parent = parent
  -- Champ de bataille (bande du décor) : clic = jouer une carte sans cible.
  local bf = CreateFrame("Frame", nil, parent)
  at(bf, parent, 0, Scene.TOP, Scene.W, Scene.DECOR_H)
  bf:EnableMouse(true)
  bf:SetScript("OnMouseUp", function(_, button) V:ClickField(button) end)
  self.bf = bf

  -- Héros ----------------------------------------------------------------
  local hero = Scene.figure(parent, 200, 220)
  at(hero, parent, HERO_X - 100, HERO_FEET - 220, 200, 220)
  self.hero = hero
  self.playerModel = hero.model
  hero.flash = W.disc(hero, "OVERLAY", 0, C.hp, 0)
  hero.flash:SetSize(130, 160)
  hero.flash:SetPoint("CENTER", 0, 0)

  local cast = CreateFrame("Frame", nil, parent)
  at(cast, parent, HERO_X - 95, 84, 190, 32)
  cast:SetFrameLevel(parent:GetFrameLevel() + 20)
  cast.shape = W.shape(cast, 6, C.gold, C.band, 2, -4)
  cast.name = W.label(cast, "body", 12, C.cream)
  cast.name:SetPoint("TOPLEFT", 8, -4)
  cast.when = W.label(cast, "body", 12, C.gold)
  cast.when:SetPoint("TOPRIGHT", -8, -4)
  cast.when:SetText("au prochain tour")
  cast.track = W.rect(cast, "ARTWORK", 0, C.woodDark)
  cast.track:SetPoint("BOTTOMLEFT", 8, 5)
  cast.track:SetSize(174, 7)
  cast.bar = W.rect(cast, "ARTWORK", 1, C.gold)
  cast.bar:SetPoint("BOTTOMLEFT", 8, 5)
  cast.bar:SetSize(108, 7)
  cast:EnableMouse(true)
  W.tooltip(cast, function(tt)
    local c = Controller.combat()
    local pc = c and c.player.cast
    if not pc then return end
    W.fillCardTooltip(tt, pc.card.id, pc.card.up, { full = true })
    tt:AddLine(" ")
    tt:AddLine("Se résout au début de ton prochain tour, sauf interruption.", 0.8, 0.8, 1, true)
  end, "ANCHOR_TOP")
  cast:Hide()
  self.cast = cast

  local hpRow = CreateFrame("Frame", nil, parent)
  at(hpRow, parent, HERO_X - 95, HERO_FEET + 6, 190, 30)
  self.playerBlock = W.shieldBadge(hpRow, 34, 30)
  self.playerBlock:SetPoint("LEFT", 0, 0)
  self.playerHp = W.hpBar(hpRow, 150, 24, 14)
  self.playerHp:SetPoint("RIGHT", 0, 0)
  self.playerSt = W.pillRow(parent, 8, 230, 12)
  at(self.playerSt, parent, HERO_X - 115, HERO_FEET + 42, 230, 18)
  hpRow:SetFrameLevel(bf:GetFrameLevel() + 15)
  self.playerSt:SetFrameLevel(bf:GetFrameLevel() + 15)

  -- Ennemis ----------------------------------------------------------------
  self.slots = {}
  for i = 1, SLOTS do self.slots[i] = buildSlot(self, i) end
  self.slotOf = {}

  -- Plateau : mana, Démence, piles ----------------------------------------------
  local hz = CreateFrame("Frame", nil, parent)
  at(hz, parent, 0, Scene.BOARD_Y, Scene.W, Scene.BOARD_H)
  hz:SetFrameLevel(parent:GetFrameLevel() + 10)
  self.hz = hz

  local mana = CreateFrame("Frame", nil, parent)
  at(mana, parent, 55, 440, 84, 84)
  mana:SetFrameLevel(hz:GetFrameLevel() + 2)
  mana:EnableMouse(true)
  mana.edge = W.disc(mana, "ARTWORK", 0, C.gemEdge)
  mana.edge:SetAllPoints()
  mana.fill = W.disc(mana, "ARTWORK", 1, C.gem)
  mana.fill:SetPoint("TOPLEFT", 4, -4)
  mana.fill:SetPoint("BOTTOMRIGHT", -4, 4)
  mana.shine = W.disc(mana, "ARTWORK", 2, C.white, 0.18)
  mana.shine:SetSize(40, 26)
  mana.shine:SetPoint("TOP", -8, -10)
  mana.text = W.label(mana, "title", 28, C.white, "OVERLAY", true)
  mana.text:SetPoint("CENTER", 0, 5)
  mana.sub = W.label(mana, "body", 12, C.white)
  mana.sub:SetPoint("TOP", mana.text, "BOTTOM", 0, -1)
  mana.sub:SetText("mana")
  W.tooltip(mana, function(tt)
    tt:AddLine("Mana", 0.4, 0.6, 1)
    tt:AddLine("Le mana non dépensé est perdu à la fin du tour.", 0.8, 0.8, 0.8, true)
  end, "ANCHOR_RIGHT")
  self.mana = mana

  local dem = W.pill(parent, 13)
  dem:SetFrameLevel(hz:GetFrameLevel() + 2)
  dem:EnableMouse(true)
  W.tooltip(dem, function(tt)
    local kw = Art.keywords.demence
    tt:AddLine(kw.name, 0.75, 0.5, 1)
    tt:AddLine(kw.text, 1, 1, 1, true)
  end, "ANCHOR_RIGHT")
  self.demence = dem

  self.drawPile = pile(self, parent, DRAW_PILE[1] - 18, DRAW_PILE[2] - 24, "draw", "Pioche", false,
    hz:GetFrameLevel() + 1)
  self.discardPile = pile(self, parent, DISCARD_PILE[1] - 18, DISCARD_PILE[2] - 24, "discard", "Défausse", true,
    hz:GetFrameLevel() + 1)

  -- Recharges (mini-cartes) et fin du tour ------------------------------------------
  self.cdCards = {}
  for i = 1, 6 do
    local m = CreateFrame("Frame", nil, parent)
    m:SetSize(44, 58)
    m:SetFrameLevel(hz:GetFrameLevel() + 2)
    m:EnableMouse(true)
    m.shape = W.shape(m, 5, C.edgeCommon, Art.hex("#8f8468"), 2, -6)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetSize(24, 24)
    m.icon:SetPoint("TOP", 0, -5)
    m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    m.icon:SetDesaturated(true)
    m.icon:SetAlpha(0.7)
    W.roundMask(m, m.icon)
    m.count = W.label(m, "title", 20, C.frame)
    m.count:SetPoint("BOTTOM", 0, 5)
    W.tooltip(m, function(tt, f)
      if not f.cd then return end
      W.fillCardTooltip(tt, f.cd.card.id, f.cd.card.up, { full = true })
      tt:AddLine(" ")
      tt:AddLine("Revient en main dans " .. f.turns .. " tour" .. (f.turns > 1 and "s" or "") .. ".", 1, 0.82, 0)
    end, "ANCHOR_TOP")
    m:Hide()
    self.cdCards[i] = m
  end

  self.endTurn = W.button(parent, "Fin du tour", 146, 48, function() V:EndTurn() end, "gold", 16)
  at(self.endTurn, parent, 874, 506, 146, 48)
  self.endTurn:SetFrameLevel(hz:GetFrameLevel() + 2)

  -- Main -----------------------------------------------------------------------------
  self.cards = {}
  for i = 1, Combat.HAND_MAX do
    local card = W.card(parent)
    card.index = i
    card:RegisterForDrag("LeftButton")
    card:SetScript("OnClick", function(f, button) V:ClickCard(f.index, button) end)
    card:SetScript("OnDragStart", function(f) V:StartDrag(f) end)
    card:SetScript("OnDragStop", function(f) V:StopDrag(f) end)
    card.onEnterExtra = function(f) f.hover = true V:PlaceCard(f) end
    card.onLeaveExtra = function(f) f.hover = false V:PlaceCard(f) end
    card:Hide()
    self.cards[i] = card
  end

  -- Fin de combat ---------------------------------------------------------------------
  local banner = CreateFrame("Frame", nil, parent)
  at(banner, parent, 317, 150, 400, 150)
  banner:SetFrameLevel(parent:GetFrameLevel() + 70)
  banner:EnableMouse(true)
  banner.glow = W.disc(banner, "BACKGROUND", 0, C.black, 0.45)
  banner.glow:SetPoint("TOPLEFT", -40, 10)
  banner.glow:SetPoint("BOTTOMRIGHT", 40, -10)
  banner.text = W.label(banner, "title", 44, C.gold, "OVERLAY", true)
  banner.text:SetPoint("TOP", 0, -14)
  banner.button = W.button(banner, "Continuer", 180, 46, function() Controller.finishCombat() end, "gold", 16)
  banner.button:SetPoint("BOTTOM", 0, 12)
  banner:Hide()
  self.banner = banner

  self.queue = {}
  self.playing = false
  self.pendingDraw = {}
end

---------------------------------------------------------------------------
-- Infobulles
---------------------------------------------------------------------------

local ACTION_TEXT = {
  block = function(a) return "Gagne " .. a[2] .. " Absorption." end,
  debuff = function(a)
    local s = ns.Statuses[a[2]]
    return "T'inflige " .. (s and s.name or a[2]) .. " " .. a[3] .. "."
  end,
  buff = function(a)
    local s = ns.Statuses[a[2]]
    return "Gagne " .. (s and s.name or a[2]) .. " " .. a[3] .. "."
  end,
  buff_allies = function(a)
    local s = ns.Statuses[a[2]]
    return "Donne " .. (s and s.name or a[2]) .. " " .. a[3] .. " à ses alliés."
  end,
  heal_ally = function(a) return "Soigne de " .. a[2] .. " l'allié le plus blessé." end,
  block_ally = function(a) return "Donne " .. a[2] .. " Absorption à un allié." end,
  interrupt = function() return "Interrompt ton incantation si tu en lances une ce tour." end,
  summon = function(a)
    local d = ns.Enemies[a[2]]
    return "Invoque " .. ((a.count or 1) > 1 and (a.count .. " × ") or "") .. (d and d.name or a[2]) .. "."
  end,
}

function V.fillIntentTooltip(tt, e)
  local c = Controller.combat()
  if not c or not e or e.dead then return end
  local info = Combat.intentInfo(c, e)
  local mv = ns.Enemies[e.id].moves[e.intent]
  tt:AddLine(info.name or e.intent, 1, 0.82, 0)
  tt:AddLine(Art.intentName[info.kind] or info.kind or "", 0.7, 0.7, 0.7)
  if info.stunned then tt:AddLine("Étourdi : perd son prochain tour.", 0.4, 0.9, 1, true) end
  if info.interrupted then tt:AddLine("Sort interrompu : il ne partira pas.", 0.4, 0.9, 1, true) end
  if mv.text then tt:AddLine(mv.text, 1, 1, 1, true) end
  for i = 1, #mv.actions do
    local a = mv.actions[i]
    if a[1] == "attack" then
      local times = a.times or 1
      tt:AddLine("Attaque : " .. Combat.calcDamage(c, e, c.player, a[2])
        .. (times > 1 and (" × " .. times) or "") .. " dégâts."
        .. (a.interrupts and " Interrompt ton incantation." or ""), 1, 0.5, 0.5, true)
    elseif ACTION_TEXT[a[1]] then
      tt:AddLine(ACTION_TEXT[a[1]](a), 1, 1, 1, true)
    end
  end
  if info.cast and not info.interrupted then
    tt:AddLine("Sort incanté : peut être interrompu (Silence…).", 1, 0.6, 0.2, true)
  end
end

function V.fillPileTooltip(tt, key, label)
  local c = Controller.combat()
  if not c then return end
  local pileList = c[key]
  tt:AddLine(label .. " (" .. #pileList .. ")", 1, 0.82, 0)
  if key == "draw" then tt:AddLine("Ordre caché ; liste triée.", 0.6, 0.6, 0.6) end
  local counts, order = {}, {}
  for i = 1, #pileList do
    local n = Card.def(pileList[i]).name
    if not counts[n] then counts[n] = 0 order[#order + 1] = n end
    counts[n] = counts[n] + 1
  end
  table.sort(order)
  for i = 1, #order do tt:AddLine(counts[order[i]] .. " × " .. order[i], 1, 1, 1) end
  if key == "discard" and #c.exhaust > 0 then
    tt:AddLine(" ")
    tt:AddLine("Consumées : " .. #c.exhaust, 0.8, 0.6, 0.4)
  end
end

---------------------------------------------------------------------------
-- Rendu
---------------------------------------------------------------------------

function V:ApplyFacing()
  if self.playerModel and self.playerModel.SetFacing then self.playerModel:SetFacing(opts().facingPlayer or 0.6) end
  for i = 1, #(self.slots or {}) do
    local m = self.slots[i].model
    if m.SetFacing then m:SetFacing(opts().facingEnemy or -0.6) end
  end
end

function V:Show(step)
  local c = step.state
  UI.setStage({ scene = Controller.scene(), board = true })
  if self.preview then self.preview:Hide() end
  if self.c ~= c then
    self.c = c
    self.selected = nil
    self.potionSlot = nil
    self.kbTarget = nil
    self.queue = {}
    self.playing = false
    self.frozen = false
    self.pendingDraw = {}
    self.slotOf = {}
    for i = 1, #self.slots do
      local s = self.slots[i]
      s.uid = nil
      s.dying = false
      s:Hide()
    end
    Scene.playerFigure(self.hero)
    self.shownHand = {}
  end
  self:ApplyFacing()
  self:Render(true)
end

function V:OnHide()
  self.queue = {}
  self.playing = false
  self.frozen = false
  if self.dragging then self:StopDrag(self.dragging, true) end
end

-- Attribution stable ennemi (uid) -> emplacement, pour garder le modèle chargé.
function V:LayoutEnemies()
  local c = self.c
  local shown = {}
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    local s = self.slotOf[e.uid]
    if not e.dead or (s and s.dying) then shown[#shown + 1] = i end
  end
  while #shown > SLOTS do
    local dropped = false
    for k = 1, #shown do
      if c.enemies[shown[k]].dead then table.remove(shown, k) dropped = true break end
    end
    if not dropped then table.remove(shown) end
  end
  local keep = {}
  for k = 1, #shown do keep[c.enemies[shown[k]].uid] = true end
  for uid, s in pairs(self.slotOf) do
    if not keep[uid] then
      self.slotOf[uid] = nil
      s.uid = nil
      s.dying = false
      s:Hide()
    end
  end
  local n = #shown
  local spacing = n > 0 and min(170, (ENEMY_X1 - ENEMY_X0) / n) or 170
  local cx0 = (ENEMY_X0 + ENEMY_X1) / 2 - (n - 1) * spacing / 2
  for k = 1, n do
    local idx = shown[k]
    local e = c.enemies[idx]
    local s = self.slotOf[e.uid]
    if not s then
      for j = 1, SLOTS do
        if not self.slots[j].uid then s = self.slots[j] break end
      end
      s.uid = e.uid
      s.dying = false
      self.slotOf[e.uid] = s
      s:Show()
      local art = Art.enemies[e.id] or {}
      local sc = art.scale or 1
      s.fig:SetSize(150 * sc, 160 * sc)
      s.model:SetSize(150 * sc, 160 * sc)
      W.setCreature(s.model, e.id, s.fallback)
      if s.model.SetFacing then s.model:SetFacing(opts().facingEnemy or -0.6) end
      W.modelAlpha(s.model, 1)
      s:SetAlpha(1)
      s.hp:Set(e.hp, e.maxHp)
      s.block:Set(e.block)
    end
    s.enemyIndex = idx
    s.cx = cx0 + (k - 1) * spacing
    s.top = 92 + ((k % 2 == 0) and 26 or 0) - Scene.TOP
    s:SetScale(n >= 5 and 0.86 or 1)
    self:PlaceSlot(s, 0, 0)
  end
end

function V:PlaceSlot(s, dx, dy)
  local sc = s:GetScale() or 1
  s:ClearAllPoints()
  s:SetPoint("TOP", self.bf, "TOPLEFT", (s.cx + (dx or 0)) / sc, -(s.top + (dy or 0)) / sc)
end

-- Bulle d'intention : icône + chiffres exacts (Combat.calcDamage).
local function intentDisplay(c, e)
  local info = Combat.intentInfo(c, e)
  if info.stunned then return Art.intents.stunned, "Étourdi", "defend" end
  if info.interrupted then return Art.intents.interrupted, "Coupé", "defend" end
  local mv = ns.Enemies[e.id].moves[e.intent]
  local parts = {}
  for i = 1, #mv.actions do
    local a = mv.actions[i]
    if a[1] == "attack" then
      local times = a.times or 1
      local dmg = Combat.calcDamage(c, e, c.player, a[2])
      parts[#parts + 1] = dmg .. (times > 1 and ("×" .. times) or "")
    elseif a[1] == "block" or a[1] == "block_ally" then
      parts[#parts + 1] = (#parts > 0 and "+" or "") .. a[2]
    elseif a[1] == "heal_ally" then
      parts[#parts + 1] = "+" .. a[2]
    elseif a[1] == "summon" then
      parts[#parts + 1] = "+" .. (a.count or 1)
    end
  end
  local text = table.concat(parts, " ")
  if info.kind == "watch" then text = "Guette" end
  local entry = Art.intents[info.kind] or Art.intents.attack
  return entry, text, entry.color
end

function V:RenderIntent(s, e)
  local c = self.c
  s.intent.enemy = e
  if e.dead or c.result then s.intent:Hide() return end
  local entry, text, color = intentDisplay(c, e)
  W.setIcon(s.intent.icon, entry, "intent:" .. tostring(Combat.intentInfo(c, e).kind))
  local edge, ink = C[color] or C.attack, C[color .. "Text"] or C.attackText
  s.intent.shape.edge:SetColor(edge)
  s.intent.text:SetTextColor(ink[1], ink[2], ink[3])
  W.setSize(s.intent.text, text:match("^%d") and 20 or 14)
  s.intent.text:SetText(text)
  s.intent:SetWidth(max(56, (s.intent.text:GetStringWidth() or 20) + 46))
  s.intent:SetAlpha(1)
  s.intent:SetScale(1)
  s.intent:Show()
end

-- full = resynchroniser barres et états sur le moteur (hors animations).
function V:RenderEnemies(full)
  local c = self.c
  self:LayoutEnemies()
  for uid, s in pairs(self.slotOf) do
    local e = enemyByUid(c, uid)
    local def = ns.Enemies[e.id]
    s.name:SetText(def.name)
    local nc = def.boss and { 1, 0.6, 0.25 } or (def.elite and C.watchText or C.cream)
    s.name:SetTextColor(nc[1], nc[2], nc[3])
    if full then
      s.hp:Set(e.hp, e.maxHp)
      s.block:Set(e.block)
      s.st:Set(W.unitStatuses(e))
    end
    if not self.frozen or e.dead then self:RenderIntent(s, e) end
  end
  self:RenderTargets()
end

function V:SelectedInfo()
  return self.selected and Controller.handInfo(self.selected) or nil
end

-- Index de l'ennemi visé au clavier (uid stable, repli sur le premier vivant).
function V:KbTarget()
  local c = self.c
  if not c then return nil end
  if self.kbTarget then
    local e, i = enemyByUid(c, self.kbTarget)
    if e and not e.dead then return i end
  end
  local alive = Controller.aliveTargets()
  if alive[1] then
    self.kbTarget = c.enemies[alive[1]].uid
    return alive[1]
  end
  return nil
end

-- Anneau doré aux pieds de la cible.
function V:RenderTargets()
  if not self.c then return end
  local info = self:SelectedInfo()
  local targeting = (info and info.needsTarget) or self.potionSlot ~= nil
  local kb = self:KbTarget()
  for _, s in pairs(self.slotOf) do
    local e = self.c.enemies[s.enemyIndex]
    local alive = e and not e.dead and not s.dying
    local on = alive and ((targeting and (s.hover or s.enemyIndex == kb)) or s.hover)
    s.fig:SetRing(on, not targeting)
  end
end

function V:RenderPlayer(full)
  local c = self.c
  local p = c.player
  if full then
    self.playerHp:Set(p.hp, p.maxHp)
    self.playerBlock:Set(p.block)
    local list = W.unitStatuses(p)
    for i = 1, #p.powers do
      local inst = p.powers[i]
      list[#list + 1] = { text = Card.def(inst).name, edge = C.goldDeep, ink = C.gold, info = { power = inst } }
    end
    self.playerSt:Set(list)
  end
  if p.cast then
    local d = Card.def(p.cast.card)
    local tgt = p.cast.target and enemyByUid(c, p.cast.target)
    self.cast.name:SetText(d.name .. (tgt and (" sur " .. ns.Enemies[tgt.id].name) or ""))
    self.cast:Show()
  else
    self.cast:Hide()
  end
  self.mana.text:SetText(p.mana .. "/" .. Controller.maxMana())
  local dem = p.demence or 0
  local w = self.demence:Set("Démence " .. dem, C.watch, C.watchText)
  at(self.demence, self.parent, 97 - w / 2, 530, w, 19)
  if dem > 0 then self.demence:Show() else self.demence:Hide() end
  self.drawPile.count:SetText(#c.draw)
  self.discardPile.count:SetText(#c.discard)
  -- recharges
  local n = min(#c.cooldown, #self.cdCards)
  local per = n > 3 and 3 or n
  for i = 1, #self.cdCards do
    local m = self.cdCards[i]
    local cd = c.cooldown[i]
    if cd and i <= n then
      local turns = cd.turns + 1
      m.cd, m.turns = cd, turns
      local d = Card.def(cd.card)
      m.shape.edge:SetColor(Art.rarity[d.rarity] or C.edgeCommon)
      W.setIcon(m.icon, W.cardArt(cd.card.id), "card:" .. cd.card.id)
      m.count:SetText(tostring(turns))
      local row, col = floor((i - 1) / 3), (i - 1) % 3
      local rowN = (row == 0) and per or (n - 3)
      local x0 = 947 - (rowN * 52 - 8) / 2
      at(m, self.parent, x0 + col * 52, 440 - row * 64, 44, 58)
      m:Show()
    else
      m.cd = nil
      m:Hide()
    end
  end
end

-- Position d'une carte de la main (centre x, haut y), sans survol.
function V:HandSlot(i, n)
  local spacing = n > 1 and min(130, (HAND_W - W.CARD_W) / (n - 1)) or 0
  local d = i - (n + 1) / 2
  local half = max(1, (n - 1) / 2)
  local x = HAND_CX + d * spacing
  local y = HAND_TOP + 10 * (d / half) * (d / half)
  return x, y
end

function V:PlaceCard(card)
  if not card.baseX or self.dragging == card then return end
  local up = self.selected == card.index or card.hover
  local sc = up and HOVER_SCALE or 1
  local top = up and 372 or card.baseY
  W.placeCenter(card, self.parent, card.baseX, top + W.CARD_H * sc / 2, sc)
  card:SetFrameLevel(self.hz:GetFrameLevel() + 5 + card.index * 3 + (up and 60 or 0))
  card:SetHot(up)
end

function V:RenderHand()
  local c = self.c
  local n = #c.hand
  if self.selected and self.selected > n then self.selected = nil end
  local mana = c.player.mana
  self.shownHand = {}
  for i = 1, #self.cards do
    local card = self.cards[i]
    if i <= n then
      local info = Controller.handInfo(i)
      card:SetCard(info.inst.id, info.inst.up, { cost = info.cost, playable = info.playable,
        manaShort = info.cost > mana, reason = not info.playable and Controller.reasonText(info.why) or nil })
      card.uid = info.inst.uid
      card.baseX, card.baseY = self:HandSlot(i, n)
      self:PlaceCard(card)
      card:SetAlpha(self.pendingDraw[card.uid] and 0 or 1)
      card:Show()
      self.shownHand[card.uid] = i
    else
      card.baseX, card.uid = nil, nil
      card:Hide()
    end
  end
end

function V:RenderBanner()
  local over = Controller.over()
  if over then
    self.banner.text:SetText(over == "won" and "Victoire !" or "Défaite")
    local col = over == "won" and C.gold or C.hpText
    self.banner.text:SetTextColor(col[1], col[2], col[3])
    self.banner.button:SetText(over == "won" and "Continuer" or "Voir le bilan")
    if not self.banner:IsShown() then
      self.banner:Show()
      W.tween(0.35, function(p) self.banner:SetAlpha(p) end, nil, self.banner, "show")
    end
    self.endTurn:SetActive(false)
  else
    self.banner:Hide()
    self.endTurn:SetActive(true)
  end
end

function V:Render(full)
  if not self.c then return end
  if full == nil then full = not self.playing end
  self:RenderPlayer(full)
  self:RenderEnemies(full)
  self:RenderHand()
  if full then self:RenderBanner() end
end

---------------------------------------------------------------------------
-- Événements du moteur : animations (cosmétiques, l'état est déjà à jour)
---------------------------------------------------------------------------

-- Centre (coordonnées du contenu) d'une unité.
function V:UnitPos(ref)
  if ref == "player" then return HERO_X, HERO_FEET - 100, self.hero end
  local s = self.slotOf[ref]
  if not s then return nil end
  local sc = s:GetScale() or 1
  return s.cx, Scene.TOP + s.top + (33 + 80) * sc, s
end

function V:Push(delay, fn)
  self.queue[#self.queue + 1] = { delay = delay, fn = fn }
end

function V:RunQueue()
  local item = table.remove(self.queue, 1)
  if not item then
    self.playing = false
    self.frozen = false
    self.pendingDraw = {}
    if self.c then self:Render(true) end
    return
  end
  self.playing = true
  item.fn()
  -- File en retard (clics rapides) : on rattrape en accélérant.
  local d = item.delay * W.pace()
  if #self.queue > 10 then d = d * 0.35 elseif #self.queue > 5 then d = d * 0.6 end
  W.delay(d, function() V:RunQueue() end)
end

function V:OnEvents(evs)
  local c = self.c
  if not c then return end
  for i = 1, #evs do
    local ev = evs[i]
    if ev.t == "death" and ev.unit ~= "player" then
      local s = self.slotOf[ev.unit]
      if s then s.dying = true end
    elseif ev.t == "draw" or ev.t == "cooldown_back" then
      self.pendingDraw[ev.card] = ev.t
    end
    self:QueueEvent(ev)
  end
  local wasPlaying = self.playing
  self.playing = true
  self:Render(false)
  if not wasPlaying then self:RunQueue() end
end

local function shake(self, s, amount)
  W.tween(0.32, function(p)
    local dx = math.sin(p * 28) * (1 - p) * (amount or 6)
    if s == self.hero then
      at(self.hero, self.parent, HERO_X - 100 + dx, HERO_FEET - 220)
    else
      self:PlaceSlot(s, dx, 0)
    end
  end, nil, s, "shake", W.ease.linear)
end

local function flash(tex, r, g, b)
  tex:SetVertexColor(r, g, b, 1)
  W.tween(0.35, function(p) tex:SetAlpha(0.45 * (1 - p)) end, nil, tex, "flash", W.ease.linear)
end

-- Ligne d'une carte jouée : carte fantôme qui file vers la cible ou le héros.
function V:FlyPlayed(pp, ev)
  if not pp then return end
  local g = W.ghostCard(self.parent)
  g:SetFrameLevel(self.hz:GetFrameLevel() + 90)
  g:SetCard(pp.id, pp.up, { cost = pp.cost })
  g:SetHot(true)
  local tx, ty = HERO_X, HERO_FEET - 110
  if ev.target then
    local x, y = self:UnitPos(ev.target)
    if x then tx, ty = x, y end
  end
  W.fly(g, self.parent, pp.x, pp.y, tx, ty, HOVER_SCALE, 0.35, 1, 0.1, 0.38, function() W.releaseGhost(g) end, 40)
end

function V:QueueEvent(ev)
  local t = ev.t
  local A = Art.anim
  local self_ = self
  if t == "play" then
    local pp = self.pendingPlay
    self.pendingPlay = nil
    self:Push(0.3, function()
      W.sound("play")
      self_:FlyPlayed(pp, ev)
      W.anim(self_.playerModel, A.spell, 1.0)
    end)
  elseif t == "act" then
    local e = enemyByUid(self.c, ev.unit)
    local mv = e and ns.Enemies[e.id].moves[ev.move]
    local isAttack = mv and mv.intent == "attack"
    self:Push(0.35, function()
      local s = self_.slotOf[ev.unit]
      if not s then return end
      local b = s.intent
      if b:IsShown() then
        W.tween(0.3, function(p) b:SetScale(1 + 0.5 * p) b:SetAlpha(1 - p) end, function()
          b:Hide() b:SetScale(1) b:SetAlpha(1)
        end, b, "pop")
      end
      if isAttack then
        W.tween(0.34, function(p)
          local k = p < 0.5 and p * 2 or (1 - p) * 2
          self_:PlaceSlot(s, -46 * k, 0)
        end, nil, s, "shake", W.ease.linear)
      end
      W.anim(s.model, isAttack and A.attack or A.spellOmni, 0.9)
    end)
  elseif t == "damage" then
    self:Push(0.32, function()
      local x, y, who = self_:UnitPos(ev.dst)
      if not x then return end
      local bar = ev.dst == "player" and self_.playerHp or who.hp
      local badge = ev.dst == "player" and self_.playerBlock or who.block
      if ev.loss > 0 then
        W.sound(ev.loss >= 12 and "bigHit" or "hit")
        W.float(self_.parent, x + 18, y - 40, "-" .. ev.loss, C.white, ev.loss >= 12 and 36 or 30)
        if bar.hp then bar:Set(bar.hp - ev.loss, bar.maxHp, true) end
        shake(self_, who, ev.loss >= 12 and 9 or 6)
        flash(who.flash, C.hp[1], C.hp[2], C.hp[3])
        W.anim(who.model or self_.playerModel, A.wound, 0.6)
      end
      if ev.absorbed > 0 then
        W.sound("block")
        W.float(self_.parent, x - 34, y - 10, "-" .. ev.absorbed, C.absorb, 20, 0.9)
        local cur = tonumber(badge.text:GetText() or "") or 0
        badge:Set(max(0, cur - ev.absorbed))
      end
    end)
  elseif t == "heal" then
    self:Push(0.2, function()
      local x, y, who = self_:UnitPos(ev.unit)
      if not x then return end
      W.sound("heal")
      W.float(self_.parent, x, y - 40, "+" .. ev.amount, C.healText, 28)
      local bar = ev.unit == "player" and self_.playerHp or who.hp
      if bar.hp then bar:Set(bar.hp + ev.amount, bar.maxHp) end
    end)
  elseif t == "block" then
    self:Push(0.18, function()
      local x, y, who = self_:UnitPos(ev.unit)
      if not x then return end
      W.sound("block")
      W.float(self_.parent, x - 30, y - 20, "+" .. ev.amount, C.absorb, 24)
      local badge = ev.unit == "player" and self_.playerBlock or who.block
      badge:Set(ev.total)
      W.tween(0.25, function(p) badge:SetScale(1 + 0.3 * (1 - p)) end, nil, badge, "pop")
    end)
  elseif t == "status" then
    local s = ns.Statuses[ev.id]
    self:Push(0.12, function()
      local x, y = self_:UnitPos(ev.unit)
      if x and ev.n > 0 then W.float(self_.parent, x, y - 70, s and s.name or ev.id, C.watchText, 15, 1.0, 20) end
    end)
  elseif t == "death" then
    self:Push(0.5, function()
      local _, _, who = self_:UnitPos(ev.unit)
      if not who then return end
      local m = who.model or self_.playerModel
      W.sound(ev.unit == "player" and "playerDeath" or "enemyDeath")
      W.anim(m, A.death)
      m.dead = true
      if ev.unit ~= "player" then
        who.intent:Hide()
        W.tween(0.9, function(p) W.modelAlpha(m, 1 - p) who:SetAlpha(1 - 0.7 * p) end, function()
          who.dying = false
          if self_.c then self_:RenderEnemies(false) end
        end, who, "fade", W.ease.linear)
      else
        W.delay(1.2 * W.pace(), function() if m.dead and m.SetAnimation then m:SetAnimation(A.dead) end end)
      end
    end)
  elseif t == "interrupt" then
    self:Push(0.3, function()
      local x, y = self_:UnitPos(ev.dst)
      W.sound("interrupt")
      if x then W.float(self_.parent, x, y - 60, "Interrompu !", C.defendText, 20, 1.3) end
    end)
  elseif t == "cast_start" then
    self:Push(0.2, function() W.anim(self_.playerModel, A.ready, 1.2) end)
  elseif t == "cast_resolve" then
    self:Push(0.35, function() W.anim(self_.playerModel, A.spellOmni, 1.0) end)
  elseif t == "cast_lost" then
    self:Push(0.2, function()
      local x, y = self_:UnitPos(ev.unit)
      if x then W.float(self_.parent, x, y - 60, "Sort perdu", C.defendText, 16) end
    end)
  elseif t == "say" then
    self:Push(0.4, function()
      local x, y = self_:UnitPos(ev.unit)
      if x then W.float(self_.parent, x, y - 110, ev.text, C.creamLight, 15, 2.6, 12) end
    end)
  elseif t == "stunned" or t == "immune" or t == "flee" then
    local label = t == "stunned" and "Étourdi" or t == "immune" and "Insensible" or "S'enfuit"
    self:Push(0.25, function()
      local x, y = self_:UnitPos(ev.unit)
      if x then W.float(self_.parent, x, y - 60, label, C.defendText, 16) end
    end)
  elseif t == "saved" then
    self:Push(0.4, function() W.float(self_.parent, HERO_X, HERO_FEET - 150, "Esprit de rédemption !", C.gold, 18, 2) end)
  elseif t == "demence" and ev.n ~= 0 then
    self:Push(0.1, function()
      W.float(self_.parent, 97, 500, (ev.n > 0 and "+" or "") .. ev.n .. " Démence", C.watchText, 15, 1.0, 26)
    end)
  elseif t == "mana" and ev.n ~= 0 then
    self:Push(0.1, function() W.float(self_.parent, 97, 470, "+" .. ev.n .. " mana", C.gemEdge, 15, 1.0, 26) end)
  elseif t == "turn" then
    self:Push(0.35, function()
      W.float(self_.parent, 517, 120, "Tour " .. ev.round, C.gold, 26, 1.1, 16)
    end)
  elseif t == "draw" or t == "cooldown_back" then
    self:Push(0.09, function() self_:FlyDraw(ev.card, t == "cooldown_back") end)
  elseif t == "result" then
    self:Push(0.2, function() W.sound(ev.result == "won" and "victory" or "defeat") end)
  end
end

-- Pioche : une carte arrive du tas (ou des recharges) jusqu'à sa place dans la main.
function V:FlyDraw(uid, fromCooldown)
  local idx = self.shownHand and self.shownHand[uid]
  local card = idx and self.cards[idx]
  self.pendingDraw[uid] = nil
  if not card or not card.baseX then return end
  W.sound("card")
  local g = W.ghostCard(self.parent)
  g:SetFrameLevel(self.hz:GetFrameLevel() + 80)
  g:SetCard(card.cardId, card.cardUp, card.opts)
  local fx, fy = DRAW_PILE[1], DRAW_PILE[2]
  if fromCooldown then fx, fy = 947, 469 end
  W.fly(g, self.parent, fx, fy, card.baseX, card.baseY + W.CARD_H / 2, 0.3, 1, 0.6, 1, 0.28, function()
    W.releaseGhost(g)
    if card.uid == uid then card:SetAlpha(1) end
  end)
end

-- Fin du tour : la main part à la défausse.
function V:FlyDiscard(before)
  for uid, pos in pairs(before) do
    if not (self.shownHand and self.shownHand[uid]) then
      local g = W.ghostCard(self.parent)
      g:SetFrameLevel(self.hz:GetFrameLevel() + 80)
      g:SetCard(pos.id, pos.up, { cost = pos.cost })
      W.fly(g, self.parent, pos.x, pos.y, DISCARD_PILE[1], DISCARD_PILE[2], 1, 0.3, 1, 0.3, 0.3, function()
        W.releaseGhost(g)
      end)
    end
  end
end

---------------------------------------------------------------------------
-- Actions du joueur
---------------------------------------------------------------------------

function V:Select(i)
  local info = Controller.handInfo(i)
  if not info then return end
  self.potionSlot = nil
  if not info.playable then UI.flash(Controller.reasonText(info.why)) return end
  W.sound("card")
  self.selected = i
  self:RenderHand()
  self:RenderTargets()
end

function V:Deselect()
  self.selected = nil
  self.potionSlot = nil
  self:RenderHand()
  self:RenderTargets()
end

function V:Play(i, target)
  local card = self.cards[i]
  if card and card.baseX then
    local info = Controller.handInfo(i)
    self.pendingPlay = { x = card.baseX, y = 372 + W.CARD_H * HOVER_SCALE / 2, id = card.cardId, up = card.cardUp,
      cost = info and info.cost }
  end
  self.selected = nil
  local ok, why = Controller.play(i, target)
  if not ok then
    self.pendingPlay = nil
    UI.flash(Controller.reasonText(why))
    self:Render()
  end
  return ok
end

-- Joue la carte sélectionnée (sur la cible clavier si elle en demande une).
function V:Confirm()
  local i = self.selected
  local info = i and Controller.handInfo(i)
  if not info then return end
  if info.needsTarget then
    local t = self:KbTarget()
    if not t then UI.flash(Controller.reasonText("target")) return end
    return self:Play(i, t)
  end
  return self:Play(i)
end

function V:ClickCard(i, button)
  if self.justDragged and now() - self.justDragged < 0.15 then return end
  if button == "RightButton" then self:Deselect() return end
  if Controller.over() then return end
  if self.selected == i then self:Confirm() else self:Select(i) end
end

function V:ClickEnemy(slot, button)
  if button == "RightButton" then self:Deselect() return end
  local e = self.c and self.c.enemies[slot.enemyIndex]
  if not e or e.dead or Controller.over() then return end
  if self.potionSlot then return self:DrinkPotion(self.potionSlot, slot.enemyIndex) end
  local info = self:SelectedInfo()
  if info and info.needsTarget then
    self:Play(self.selected, slot.enemyIndex)
  else
    self.kbTarget = e.uid
    if info then self:Play(self.selected) else self:RenderTargets() end
  end
end

-- Potion à cible (bandeau) : la prochaine cible cliquée la reçoit ; Entrée vise la cible clavier.
function V:SelectPotion(slot)
  self.selected = nil
  self.potionSlot = slot
  self:RenderHand()
  self:RenderTargets()
  UI.flash("Choisis une cible pour la potion.")
end

function V:DrinkPotion(slot, target)
  self.potionSlot = nil
  local ok, why = Controller.usePotion(slot, target)
  if not ok then
    UI.flash(Controller.reasonText(why))
    self:Render()
  end
  return ok
end

function V:ClickField(button)
  if button == "RightButton" then self:Deselect() return end
  local info = self:SelectedInfo()
  if info and not info.needsTarget then self:Play(self.selected) end
end

function V:EndTurn()
  if Controller.over() then Controller.finishCombat() return end
  self.selected = nil
  local before = {}
  for i = 1, #self.cards do
    local card = self.cards[i]
    if card.uid and card.baseX then
      before[card.uid] = { x = card.baseX, y = card.baseY + W.CARD_H / 2, id = card.cardId, up = card.cardUp,
        cost = card.opts and card.opts.cost }
    end
  end
  self.frozen = true
  W.sound("endTurn")
  local ok = Controller.endTurn()
  if ok then self:FlyDiscard(before) else self.frozen = false end
end

function V:CycleTarget(back)
  local alive = Controller.aliveTargets()
  if #alive == 0 then return end
  local cur = self:KbTarget()
  local pos = 1
  for k = 1, #alive do if alive[k] == cur then pos = k end end
  pos = back and (pos - 2) % #alive + 1 or pos % #alive + 1
  self.kbTarget = self.c.enemies[alive[pos]].uid
  self:RenderTargets()
end

function V:StartDrag(card)
  local info = Controller.handInfo(card.index)
  if not info or not info.playable or Controller.over() then return end
  if GameTooltip then GameTooltip:Hide() end
  self.selected = card.index
  self.dragging = card
  self:RenderTargets()
  card:SetFrameLevel(self.hz:GetFrameLevel() + 95)
  card:SetScript("OnUpdate", function(f)
    local x, y = GetCursorPosition()
    local s = f:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
  end)
end

-- Lâcher : sur un ennemi (carte ciblée) ou n'importe où au-dessus de la main (sinon).
function V:StopDrag(card, cancel)
  card:SetScript("OnUpdate", nil)
  if self.dragging ~= card then return end
  self.dragging = nil
  self.justDragged = now()
  local idx = card.index
  local info = Controller.handInfo(idx)
  if not cancel and info and info.playable then
    if info.needsTarget then
      for _, s in pairs(self.slotOf) do
        local e = self.c.enemies[s.enemyIndex]
        if e and not e.dead and s:IsMouseOver() then return self:Play(idx, s.enemyIndex) end
      end
    elseif self.bf:IsMouseOver() then
      return self:Play(idx)
    end
  end
  self.selected = nil
  self:RenderHand()
  self:RenderTargets()
end

function V:HandleKey(key)
  local c = self.c
  if not c then return false end
  if Controller.over() then
    if key == "SPACE" or key == "ENTER" then Controller.finishCombat() return true end
    return UI.keyIndex(key) ~= nil
  end
  local idx = UI.keyIndex(key)
  if idx then
    if idx <= #c.hand then
      if self.selected == idx then self:Confirm() else self:Select(idx) end
    end
    return true
  elseif key == "TAB" then
    self:CycleTarget(IsShiftKeyDown and IsShiftKeyDown())
    return true
  elseif key == "SPACE" then
    self:EndTurn()
    return true
  elseif key == "ENTER" then
    if self.potionSlot then
      local t = self:KbTarget()
      if t then self:DrinkPotion(self.potionSlot, t) end
    else
      self:Confirm()
    end
    return true
  end
  return false
end

---------------------------------------------------------------------------
-- Aperçu des modèles (/slay modeles) : vérifie l'art sans toucher à l'expédition
---------------------------------------------------------------------------

function V:PreviewEnemies()
  if not self.preview then
    local p = W.woodPanel(UI.content, 10)
    p:SetPoint("TOPLEFT", 10, -50)
    p:SetPoint("BOTTOMRIGHT", -10, 10)
    p:SetFrameLevel(UI.content:GetFrameLevel() + 95)
    p.models = {}
    local ids = {}
    for id in pairs(Art.enemies) do ids[#ids + 1] = id end
    table.sort(ids)
    for k = 1, #ids do
      local col, row = (k - 1) % 5, floor((k - 1) / 5)
      local m = W.model(p, 180, 200)
      m:SetPoint("TOPLEFT", 20 + col * 200, -16 - row * 270)
      local fb = p:CreateTexture(nil, "ARTWORK")
      fb:SetSize(48, 48)
      fb:SetPoint("CENTER", m, "CENTER")
      fb:Hide()
      local label = W.label(p, "body", 12, C.cream)
      label:SetPoint("TOP", m, "BOTTOM", 0, -4)
      local art = Art.enemies[ids[k]]
      label:SetText((ns.Enemies[ids[k]] and ns.Enemies[ids[k]].name or ids[k])
        .. " (" .. tostring(art.creature) .. ")")
      m.id, m.fallback = ids[k], fb
      p.models[k] = m
    end
    local close = W.button(p, "Fermer", 110, 30, function() p:Hide() end, "gold", 14)
    close:SetPoint("BOTTOMRIGHT", -14, 14)
    self.preview = p
  end
  self.preview:Show()
  for k = 1, #self.preview.models do
    local m = self.preview.models[k]
    W.setCreature(m, m.id, m.fallback)
    if m.SetFacing then m:SetFacing(opts().facingEnemy or -0.6) end
  end
end
