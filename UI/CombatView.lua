-- Écran de combat : héros à gauche, 1 à 5 ennemis à droite, main en éventail en bas.
-- N'applique aucune règle : lit l'état du moteur (ns.Combat) et passe par ns.Controller
-- (donc par Expedition.act : coups, fin de tour, potions).
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art, UI, Controller, Combat, Card = ns.Widgets, ns.Art, ns.UI, ns.Controller, ns.Combat, ns.Card

local V = { kinds = { "combat" } }
UI.register("combat", V)

local BF_W, BF_H = 876, 296
local HAND_X, HAND_W = 96, 684
local SLOT_W, SLOTS = 128, 6
local ENEMY_X, ENEMY_W = 212, 660

local function now() return GetTime and GetTime() or 0 end
local function opts() return ns.Persist.options() end

---------------------------------------------------------------------------
-- Noms pour le journal
---------------------------------------------------------------------------

local function enemyByUid(c, uid)
  for i = 1, #c.enemies do if c.enemies[i].uid == uid then return c.enemies[i], i end end
end

local function unitName(c, ref)
  if ref == nil then return "?" end
  if ref == "player" then return "Toi" end
  local e = enemyByUid(c, ref)
  return e and ns.Enemies[e.id].name or "?"
end

local function cardNameByUid(c, uid)
  local function scan(t)
    for i = 1, #t do if t[i].uid == uid then return Card.def(t[i]).name end end
  end
  local n = scan(c.hand) or scan(c.draw) or scan(c.discard) or scan(c.exhaust) or scan(c.player.powers)
  if n then return n end
  for i = 1, #c.cooldown do
    if c.cooldown[i].card.uid == uid then return Card.def(c.cooldown[i].card).name end
  end
  if c.player.cast and c.player.cast.card.uid == uid then return Card.def(c.player.cast.card).name end
  return "?"
end

local function cardName(id)
  local d = ns.Cards[id]
  return d and d.name or tostring(id)
end

-- Ligne de journal pour un événement du moteur ; nil = rien à écrire.
function V.describe(c, ev)
  local t = ev.t
  if t == "play" then
    local s = "Tu joues " .. cardName(ev.id)
    if ev.target then s = s .. " sur " .. unitName(c, ev.target) end
    return s, 1, 1, 1
  elseif t == "damage" then
    local s = (ev.src and (unitName(c, ev.src) .. " inflige ") or "") .. ev.loss
      .. (ev.src and "" or " dégâts") .. " à " .. (ev.dst == "player" and "toi" or unitName(c, ev.dst))
    if ev.absorbed > 0 then s = s .. " (" .. ev.absorbed .. " absorbés)" end
    if ev.dst == "player" then return s, 1, 0.4, 0.4 end
    return s, 1, 0.85, 0.6
  elseif t == "heal" then
    return unitName(c, ev.unit) .. " récupère " .. ev.amount .. " PV", 0.4, 1, 0.4
  elseif t == "block" then
    return unitName(c, ev.unit) .. " gagne " .. ev.amount .. " Absorption", 0.55, 0.75, 1
  elseif t == "status" then
    local s = ns.Statuses[ev.id]
    return unitName(c, ev.unit) .. " : " .. (s and s.name or ev.id) .. (ev.n >= 0 and " +" or " ") .. ev.n,
      0.9, 0.75, 1
  elseif t == "tick" then
    return "Douleur : " .. ev.n .. " dégâts à " .. (ev.unit == "player" and "toi" or unitName(c, ev.unit)),
      0.8, 0.5, 1
  elseif t == "death" then
    if ev.unit == "player" then return "Tu tombes…", 1, 0.2, 0.2 end
    return unitName(c, ev.unit) .. " meurt", 1, 0.6, 0.2
  elseif t == "turn" then
    return "— Tour " .. ev.round .. " —", 1, 0.82, 0
  elseif t == "interrupt" then
    if ev.src == "player" then return "Tu interromps " .. unitName(c, ev.dst), 0.4, 0.9, 1 end
    return unitName(c, ev.src) .. " interrompt ton incantation (" .. cardName(ev.card) .. ")", 1, 0.4, 0.4
  elseif t == "cast_start" then
    return "Tu commences à incanter " .. cardNameByUid(c, ev.card), 0.8, 0.8, 1
  elseif t == "cast_resolve" then
    return cardNameByUid(c, ev.card) .. " se résout", 0.8, 0.8, 1
  elseif t == "cast_lost" then
    return unitName(c, ev.unit) .. " perd son sort", 0.4, 0.9, 1
  elseif t == "act" then
    local e = enemyByUid(c, ev.unit)
    local mv = e and ns.Enemies[e.id].moves[ev.move]
    return unitName(c, ev.unit) .. " : " .. (mv and mv.name or ev.move), 0.85, 0.85, 0.85
  elseif t == "say" then
    return unitName(c, ev.unit) .. " : « " .. ev.text .. " »", 1, 1, 0.4
  elseif t == "spawn" then
    return (ns.Enemies[ev.id] and ns.Enemies[ev.id].name or ev.id) .. " entre en combat", 0.85, 0.85, 0.85
  elseif t == "flee" then
    return unitName(c, ev.unit) .. " s'enfuit", 0.85, 0.85, 0.85
  elseif t == "stunned" then
    return unitName(c, ev.unit) .. " est étourdi et perd son tour", 0.4, 0.9, 1
  elseif t == "immune" then
    return unitName(c, ev.unit) .. " est insensible à l'étourdissement", 0.85, 0.85, 0.85
  elseif t == "saved" then
    return "L'Esprit de rédemption te maintient à 1 PV", 1, 1, 0.6
  elseif t == "power" then
    return "Pouvoir actif : " .. cardName(ev.card), 0.9, 0.75, 1
  elseif t == "demence" then
    return "Démence " .. (ev.n >= 0 and "+" or "") .. ev.n .. " (total " .. ev.total .. ")", 0.75, 0.5, 1
  elseif t == "reshuffle" then
    return "La défausse est mélangée dans la pioche (" .. ev.n .. " cartes)", 0.7, 0.7, 0.7
  elseif t == "cooldown_back" then
    return cardNameByUid(c, ev.card) .. " revient en main", 0.7, 0.7, 0.7
  elseif t == "result" then
    if ev.result == "won" then return "Victoire !", 0.3, 1, 0.3 end
    return "Défaite…", 1, 0.3, 0.3
  end
  return nil
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function newModel(parent, w, h)
  local m = W.create("PlayerModel", nil, parent)
  m:SetSize(w, h)
  return m
end

local function buildSlot(self, i)
  local s = CreateFrame("Button", nil, self.bf)
  s:SetSize(SLOT_W, 248)
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s.index = i

  s.glow = s:CreateTexture(nil, "BACKGROUND")
  s.glow:SetPoint("TOPLEFT", 2, -28)
  s.glow:SetPoint("BOTTOMRIGHT", -2, 2)
  s.glow:SetColorTexture(1, 0.85, 0.2, 0.18)
  s.glow:Hide()

  local intent = CreateFrame("Frame", nil, s)
  intent:SetSize(SLOT_W, 26)
  intent:SetPoint("TOP", 0, 0)
  intent:EnableMouse(true)
  intent.icon = intent:CreateTexture(nil, "ARTWORK")
  intent.icon:SetSize(24, 24)
  intent.icon:SetPoint("LEFT", 8, 0)
  intent.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  intent.text = W.text(intent, "GameFontNormalLarge", 14)
  intent.text:SetPoint("LEFT", intent.icon, "RIGHT", 4, 0)
  intent.text:SetPoint("RIGHT", -2, 0)
  intent.text:SetJustifyH("LEFT")
  W.tooltip(intent, function(tt, f) V.fillIntentTooltip(tt, f.enemy) end, "ANCHOR_TOP")
  s.intent = intent

  s.model = newModel(s, 120, 160)
  s.model:SetPoint("TOP", 0, -30)
  s.fallback = s:CreateTexture(nil, "ARTWORK")
  s.fallback:SetSize(56, 56)
  s.fallback:SetPoint("CENTER", s.model, "CENTER")
  s.fallback:Hide()

  s.name = W.text(s, "GameFontNormal", 11)
  s.name:SetPoint("TOP", 0, -192)
  s.name:SetWidth(SLOT_W)
  s.hp = W.bar(s, 116, 12, 0.8, 0.1, 0.1)
  s.hp:SetPoint("TOP", 0, -208)
  s.st = W.statusRow(s, 16, 6)
  s.st:SetPoint("TOPLEFT", 6, -226)

  s:SetScript("OnClick", function(_, button) V:ClickEnemy(s, button) end)
  s:SetScript("OnEnter", function() s.hover = true V:RenderTargets() end)
  s:SetScript("OnLeave", function() s.hover = false V:RenderTargets() end)
  s:Hide()
  return s
end

local function pileButton(self, parent, label, entry, key, y)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(88, 34)
  b:SetPoint("TOPLEFT", 2, y)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(28, 28)
  b.icon:SetPoint("LEFT", 2, 0)
  W.setIcon(b.icon, entry, "ui:" .. key)
  b.label = W.text(b, "GameFontNormalSmall")
  b.label:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 4, -1)
  b.label:SetText(label)
  b.count = W.text(b, "GameFontHighlightLarge", 14)
  b.count:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 4, 0)
  b.pile = key
  W.tooltip(b, function(tt) V.fillPileTooltip(tt, key, label) end, "ANCHOR_RIGHT")
  return b
end

function V:Build(parent)
  self.parent = parent
  local bf = CreateFrame("Frame", nil, parent)
  bf:SetSize(BF_W, BF_H)
  bf:SetPoint("TOPLEFT", 0, 0)
  bf:EnableMouse(true)
  bf:SetScript("OnMouseUp", function(_, button) V:ClickField(button) end)
  self.bf = bf
  local bg = bf:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.12, 0.1, 0.08, 0.35)

  self.round = W.text(bf, "GameFontNormal", 12)
  self.round:SetPoint("TOP", 0, -2)

  -- Héros ----------------------------------------------------------------
  local hero = CreateFrame("Frame", nil, bf)
  hero:SetSize(196, BF_H)
  hero:SetPoint("TOPLEFT", 4, 0)
  self.hero = hero

  local cast = CreateFrame("StatusBar", nil, hero)
  cast:SetSize(150, 14)
  cast:SetPoint("TOPLEFT", 30, -6)
  cast:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  cast:SetStatusBarColor(0.6, 0.45, 1)
  cast:SetMinMaxValues(0, 1)
  cast:SetValue(1)
  local cbg = cast:CreateTexture(nil, "BACKGROUND")
  cbg:SetAllPoints()
  cbg:SetColorTexture(0, 0, 0, 0.6)
  cast.icon = cast:CreateTexture(nil, "ARTWORK")
  cast.icon:SetSize(18, 18)
  cast.icon:SetPoint("RIGHT", cast, "LEFT", -4, 0)
  cast.text = W.text(cast, "GameFontHighlightSmall", 9)
  cast.text:SetPoint("CENTER")
  cast:EnableMouse(true)
  W.tooltip(cast, function(tt)
    local c = Controller.combat()
    local pc = c and c.player.cast
    if not pc then return end
    W.fillCardTooltip(tt, pc.card.id, pc.card.up)
    tt:AddLine(" ")
    tt:AddLine("Se résout au début de ton prochain tour, sauf interruption.", 0.8, 0.8, 1, true)
  end, "ANCHOR_TOP")
  cast:Hide()
  self.cast = cast

  self.playerModel = newModel(hero, 180, 168)
  self.playerModel:SetPoint("TOP", 0, -24)

  self.playerName = W.text(hero, "GameFontNormal", 11)
  self.playerName:SetPoint("TOP", 0, -194)
  self.playerHp = W.bar(hero, 170, 14, 0.1, 0.8, 0.1)
  self.playerHp:SetPoint("TOP", 0, -210)
  self.playerSt = W.statusRow(hero, 18, 9)
  self.playerSt:SetPoint("TOPLEFT", 12, -230)

  -- Ennemis ----------------------------------------------------------------
  self.slots = {}
  for i = 1, SLOTS do self.slots[i] = buildSlot(self, i) end
  self.slotOf = {}

  -- Journal discret ----------------------------------------------------------
  local log = W.create("ScrollingMessageFrame", nil, bf)
  log:SetPoint("TOPLEFT", ENEMY_X, -262)
  log:SetPoint("BOTTOMRIGHT", -4, 2)
  log:SetFontObject(GameFontHighlightSmall)
  log:SetJustifyH("LEFT")
  log:SetMaxLines(200)
  log:SetFading(true)
  log:SetTimeVisible(20)
  log:EnableMouseWheel(true)
  log:SetScript("OnMouseWheel", function(f, d) if d > 0 then f:ScrollUp() else f:ScrollDown() end end)
  self.log = log

  -- Bandeau de fin de combat ---------------------------------------------------
  local banner = W.panel(bf, "tooltip")
  banner:SetSize(300, 110)
  banner:SetPoint("CENTER", bf, "CENTER", 110, 10)
  banner:SetFrameLevel(bf:GetFrameLevel() + 30)
  banner.text = W.text(banner, "GameFontNormalHuge")
  banner.text:SetPoint("TOP", 0, -18)
  banner.button = W.button(banner, "Continuer", 140, 26, function() Controller.finishCombat() end)
  banner.button:SetPoint("BOTTOM", 0, 16)
  banner:Hide()
  self.banner = banner

  -- Bas de l'écran : piles, main, mana, fin du tour --------------------------------
  local hz = CreateFrame("Frame", nil, parent)
  hz:SetPoint("TOPLEFT", 0, -BF_H - 2)
  hz:SetPoint("BOTTOMRIGHT", 0, 0)
  self.hz = hz

  self.drawPile = pileButton(self, hz, "Pioche", Art.ui.draw, "draw", -2)
  self.discardPile = pileButton(self, hz, "Défausse", Art.ui.discard, "discard", -38)
  self.exhaustPile = pileButton(self, hz, "Consumées", Art.ui.exhaust, "exhaust", -74)
  local cdl = W.text(hz, "GameFontNormalSmall")
  cdl:SetPoint("TOPLEFT", 4, -112)
  cdl:SetText("Recharges")
  self.cdRow = W.statusRow(hz, 20, 4)
  self.cdRow:SetPoint("TOPLEFT", 2, -126)

  local mana = CreateFrame("Frame", nil, hz)
  mana:SetSize(56, 56)
  mana:SetPoint("TOPRIGHT", -18, -4)
  mana:EnableMouse(true)
  mana.icon = mana:CreateTexture(nil, "ARTWORK")
  mana.icon:SetAllPoints()
  W.setIcon(mana.icon, Art.ui.mana, "ui:mana")
  mana.text = W.text(mana, "GameFontNormalHuge")
  mana.text:SetPoint("CENTER")
  mana.text:SetTextColor(1, 1, 1)
  W.tooltip(mana, function(tt)
    local c = Controller.combat()
    tt:AddLine("Mana", 0.4, 0.6, 1)
    if c then tt:AddLine(c.player.mana .. " disponible(s) ce tour.", 1, 1, 1) end
    tt:AddLine("Le mana non dépensé est perdu à la fin du tour.", 0.8, 0.8, 0.8, true)
  end, "ANCHOR_LEFT")
  self.mana = mana

  local dem = CreateFrame("Frame", nil, hz)
  dem:SetSize(80, 22)
  dem:SetPoint("TOPRIGHT", -6, -66)
  dem:EnableMouse(true)
  dem.icon = dem:CreateTexture(nil, "ARTWORK")
  dem.icon:SetSize(20, 20)
  dem.icon:SetPoint("LEFT")
  W.setIcon(dem.icon, Art.ui.demence, "ui:demence")
  dem.text = W.text(dem, "GameFontHighlight")
  dem.text:SetPoint("LEFT", dem.icon, "RIGHT", 4, 0)
  W.tooltip(dem, function(tt)
    local kw = Art.keywords.demence
    tt:AddLine(kw.name, 0.75, 0.5, 1)
    tt:AddLine(kw.text, 1, 1, 1, true)
  end, "ANCHOR_LEFT")
  self.demence = dem

  self.endTurn = W.button(hz, "Fin du tour", 92, 30, function() V:EndTurn() end)
  self.endTurn:SetPoint("BOTTOMRIGHT", -2, 6)
  local hint = W.text(hz, "GameFontDisableSmall", 8)
  hint:SetPoint("BOTTOM", self.endTurn, "TOP", 0, 2)
  hint:SetText("(Espace)")

  self.cards = {}
  for i = 1, Combat.HAND_MAX do
    local card = W.card(hz)
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

  self.queue = {}
  self.playing = false
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
  for i = 1, #mv.actions do
    local a = mv.actions[i]
    if a[1] == "attack" then
      local times = a.times or 1
      tt:AddLine("Attaque : " .. Combat.calcDamage(c, e, c.player, a[2])
        .. (times > 1 and (" × " .. times) or "") .. " dégâts.", 1, 0.5, 0.5, true)
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
  local pile = c[key]
  tt:AddLine(label .. " (" .. #pile .. ")", 1, 0.82, 0)
  if key == "draw" then tt:AddLine("Ordre caché ; liste triée.", 0.6, 0.6, 0.6) end
  local counts, order = {}, {}
  for i = 1, #pile do
    local n = Card.def(pile[i]).name
    if not counts[n] then counts[n] = 0 order[#order + 1] = n end
    counts[n] = counts[n] + 1
  end
  table.sort(order)
  for i = 1, #order do tt:AddLine(counts[order[i]] .. " × " .. order[i], 1, 1, 1) end
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
  if self.preview then self.preview:Hide() end
  if self.c ~= c then
    self.c = c
    self.selected = nil
    self.potionSlot = nil
    self.kbTarget = nil
    self.queue = {}
    self.slotOf = {}
    for i = 1, #self.slots do
      local s = self.slots[i]
      s.uid = nil
      s.dying = false
      s:Hide()
    end
    if self.log.Clear then self.log:Clear() end
    local names = {}
    for i = 1, #c.enemies do
      if not c.enemies[i].dead then names[#names + 1] = ns.Enemies[c.enemies[i].id].name end
    end
    self.log:AddMessage((step.title or "Combat") .. " : " .. table.concat(names, ", "), 1, 0.82, 0)
    self.playerModel:SetUnit("player")
    self.playerModel.dead = false
  end
  self:ApplyFacing()
  self:Render()
end

function V:OnHide()
  self.queue = {}
  self.playing = false
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
  local w = n > 0 and math.min(132, ENEMY_W / n) or 132
  local x0 = ENEMY_X + (ENEMY_W - n * w) / 2
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
      W.setCreature(s.model, e.id, s.fallback)
      if s.model.SetFacing then s.model:SetFacing(opts().facingEnemy or -0.6) end
      s.model:SetAlpha(1)
    end
    s.enemyIndex = idx
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", self.bf, "TOPLEFT", x0 + (k - 1) * w + (w - SLOT_W) / 2, -16)
  end
end

local function intentDisplay(c, e)
  local info = Combat.intentInfo(c, e)
  if info.stunned then return Art.intents.stunned, "Étourdi", 0.6, 0.6, 0.6 end
  if info.interrupted then return Art.intents.interrupted, "Interrompu", 0.6, 0.6, 0.6 end
  local mv = ns.Enemies[e.id].moves[e.intent]
  local parts = {}
  for i = 1, #mv.actions do
    local a = mv.actions[i]
    if a[1] == "attack" then
      local times = a.times or 1
      local dmg = Combat.calcDamage(c, e, c.player, a[2])
      parts[#parts + 1] = "|cffff5050" .. dmg .. (times > 1 and ("×" .. times) or "") .. "|r"
    elseif a[1] == "block" or a[1] == "block_ally" then
      parts[#parts + 1] = "|cff8cc4ff+" .. a[2] .. "|r"
    elseif a[1] == "heal_ally" then
      parts[#parts + 1] = "|cff60ff60+" .. a[2] .. "|r"
    elseif a[1] == "summon" then
      parts[#parts + 1] = "+" .. (a.count or 1)
    end
  end
  local text = table.concat(parts, " ")
  if info.kind == "watch" then text = "Guette" end
  if info.cast then text = "|cffff9a30Incante|r " .. text end
  return Art.intents[info.kind] or Art.intents.attack, text, 1, 1, 1
end

function V:RenderEnemies()
  local c = self.c
  self:LayoutEnemies()
  for uid, s in pairs(self.slotOf) do
    local e = enemyByUid(c, uid)
    local def = ns.Enemies[e.id]
    s.name:SetText(def.name)
    if def.boss then s.name:SetTextColor(1, 0.5, 0.1)
    elseif def.elite then s.name:SetTextColor(0.8, 0.4, 1)
    else s.name:SetTextColor(1, 0.82, 0) end
    s.hp:Set(math.max(e.hp, 0), e.maxHp, e.block)
    s.st:Set(W.unitStatuses(e))
    s.intent.enemy = e
    if e.dead or c.result then
      s.intent:Hide()
    else
      local entry, text = intentDisplay(c, e)
      W.setIcon(s.intent.icon, entry, "intent:" .. tostring(Combat.intentInfo(c, e).kind))
      s.intent.text:SetText(text)
      s.intent:Show()
    end
    s:SetAlpha(e.dead and 0.6 or 1)
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

function V:RenderTargets()
  if not self.c then return end
  local info = self:SelectedInfo()
  local targeting = (info and info.needsTarget) or self.potionSlot ~= nil
  local kb = self:KbTarget()
  for _, s in pairs(self.slotOf) do
    local e = self.c.enemies[s.enemyIndex]
    local on = e and not e.dead and (s.hover or (targeting and s.enemyIndex == kb))
    if on then s.glow:Show() else s.glow:Hide() end
  end
end

function V:RenderPlayer()
  local c = self.c
  local p = c.player
  self.playerName:SetText(UnitName and UnitName("player") or "Toi")
  self.playerHp:Set(math.max(p.hp, 0), p.maxHp, p.block)
  local list = W.unitStatuses(p)
  for i = 1, #p.powers do
    local inst = p.powers[i]
    list[#list + 1] = { entry = W.cardArt(inst.id), key = "card:" .. inst.id, info = { power = inst } }
  end
  self.playerSt:Set(list)
  if p.cast then
    local d = Card.def(p.cast.card)
    local tgt = p.cast.target and enemyByUid(c, p.cast.target)
    W.setIcon(self.cast.icon, W.cardArt(p.cast.card.id), "card:" .. p.cast.card.id)
    self.cast.text:SetText(d.name .. (tgt and (" → " .. ns.Enemies[tgt.id].name) or ""))
    self.cast:Show()
  else
    self.cast:Hide()
  end
  self.mana.text:SetText(tostring(p.mana))
  self.demence.text:SetText(tostring(p.demence or 0))
  self.drawPile.count:SetText(#c.draw)
  self.discardPile.count:SetText(#c.discard)
  self.exhaustPile.count:SetText(#c.exhaust)
  local cds = {}
  for i = 1, #c.cooldown do
    local cd = c.cooldown[i]
    local d = Card.def(cd.card)
    local turns = cd.turns + 1
    cds[#cds + 1] = { entry = W.cardArt(cd.card.id), key = "card:" .. cd.card.id, count = turns,
      info = { title = d.name, text = "Revient en main dans " .. turns .. " tour" .. (turns > 1 and "s" or "") .. "." } }
  end
  self.cdRow:Set(cds)
  self.round:SetText("Tour " .. c.round)
end

local function keyLabel(i) return i == 10 and "0" or tostring(i) end

function V:PlaceCard(card)
  if not card.baseX or self.dragging == card then return end
  local lift = 0
  if self.selected == card.index then lift = 22 elseif card.hover then lift = 14 end
  card:ClearAllPoints()
  card:SetPoint("TOPLEFT", self.hz, "TOPLEFT", card.baseX, card.baseY + lift)
  card:SetFrameLevel(self.hz:GetFrameLevel() + card.index + ((lift > 0) and 20 or 0))
  card:SetSelected(self.selected == card.index)
end

function V:RenderHand()
  local c = self.c
  local n = #c.hand
  if self.selected and self.selected > n then self.selected = nil end
  local cw = W.CARD_W
  local spacing = n > 1 and math.min(cw + 4, (HAND_W - cw) / (n - 1)) or 0
  local total = cw + (n - 1) * spacing
  local x0 = HAND_X + (HAND_W - total) / 2
  for i = 1, #self.cards do
    local card = self.cards[i]
    if i <= n then
      local info = Controller.handInfo(i)
      card:SetCard(info.inst.id, info.inst.up, { cost = info.cost, playable = info.playable,
        key = keyLabel(i), reason = not info.playable and Controller.reasonText(info.why) or nil })
      local d = i - (n + 1) / 2
      card.baseX = x0 + (i - 1) * spacing
      card.baseY = -10 - d * d * 0.7
      self:PlaceCard(card)
      card:Show()
    else
      card.baseX = nil
      card:Hide()
    end
  end
end

function V:RenderBanner()
  local over = Controller.over()
  if over then
    self.banner.text:SetText(over == "won" and "|cff40ff40Victoire !|r" or "|cffff4040Défaite…|r")
    self.banner.button:SetText(over == "won" and "Continuer" or "Voir le bilan")
    self.banner:Show()
    self.endTurn:Disable()
  else
    self.banner:Hide()
    self.endTurn:Enable()
  end
end

function V:Render()
  if not self.c then return end
  self:RenderPlayer()
  self:RenderEnemies()
  self:RenderHand()
  self:RenderBanner()
end

---------------------------------------------------------------------------
-- Événements du moteur : journal + animations (cosmétiques, l'état est déjà à jour)
---------------------------------------------------------------------------

local function unitAnchor(self, ref)
  if ref == "player" then return self.playerModel end
  local s = self.slotOf[ref]
  return s and s.model
end

function V:Push(delay, fn)
  self.queue[#self.queue + 1] = { delay = delay, fn = fn }
end

function V:RunQueue()
  local item = table.remove(self.queue, 1)
  if not item then self.playing = false return end
  self.playing = true
  item.fn()
  W.delay(item.delay * W.pace(), function() V:RunQueue() end)
end

function V:OnEvents(evs)
  local c = self.c
  if not c then return end
  for i = 1, #evs do
    local ev = evs[i]
    local line, r, g, b = V.describe(c, ev)
    if line then self.log:AddMessage(line, r, g, b) end
    if ev.t == "death" and ev.unit ~= "player" then
      local s = self.slotOf[ev.unit]
      if s then s.dying = true end
    end
    self:QueueEvent(ev)
  end
  self:Render()
  if not self.playing then self:RunQueue() end
end

function V:QueueEvent(ev)
  local t = ev.t
  local A = Art.anim
  local self_ = self
  if t == "play" then
    self:Push(0.2, function() W.anim(self_.playerModel, A.spell, 1.0) end)
  elseif t == "act" then
    local e = enemyByUid(self.c, ev.unit)
    local mv = e and ns.Enemies[e.id].moves[ev.move]
    self:Push(0.25, function()
      local m = unitAnchor(self_, ev.unit)
      if m then W.anim(m, (mv and mv.intent == "attack") and A.attack or A.spellOmni, 0.9) end
    end)
  elseif t == "damage" then
    self:Push(0.3, function()
      local m = unitAnchor(self_, ev.dst)
      if not m then return end
      if ev.loss > 0 then W.anim(m, A.wound, 0.6) end
      local txt = "-" .. ev.loss
      if ev.absorbed > 0 then txt = txt .. " |cff8cc4ff(" .. ev.absorbed .. ")|r" end
      W.float(m, txt, 1, 0.3, 0.3, 20)
    end)
  elseif t == "heal" then
    self:Push(0.15, function()
      local m = unitAnchor(self_, ev.unit)
      if m then W.float(m, "+" .. ev.amount, 0.3, 1, 0.3, 30) end
    end)
  elseif t == "block" then
    self:Push(0.15, function()
      local m = unitAnchor(self_, ev.unit)
      if m then W.float(m, "+" .. ev.amount .. " Absorption", 0.55, 0.75, 1, 40) end
    end)
  elseif t == "status" then
    local s = ns.Statuses[ev.id]
    self:Push(0.12, function()
      local m = unitAnchor(self_, ev.unit)
      if m then W.float(m, (s and s.name or ev.id), 0.9, 0.75, 1, 55, 1.0) end
    end)
  elseif t == "death" then
    self:Push(0.4, function()
      local m = unitAnchor(self_, ev.unit)
      if not m then return end
      W.anim(m, A.death)
      m.dead = true
      W.delay(1.2 * W.pace(), function() if m.dead and m.SetAnimation then m:SetAnimation(A.dead) end end)
      if ev.unit ~= "player" then
        W.delay(1.6 * W.pace(), function()
          local s = self_.slotOf[ev.unit]
          if s then s.dying = false end
          if self_.c then self_:RenderEnemies() end
        end)
      end
    end)
  elseif t == "interrupt" then
    self:Push(0.25, function()
      local m = unitAnchor(self_, ev.dst)
      if m then W.float(m, "Interrompu !", 0.4, 0.9, 1, 60) end
    end)
  elseif t == "cast_start" then
    self:Push(0.2, function() W.anim(self_.playerModel, A.ready, 1.2) end)
  elseif t == "cast_resolve" then
    self:Push(0.3, function() W.anim(self_.playerModel, A.spellOmni, 1.0) end)
  elseif t == "cast_lost" then
    self:Push(0.2, function()
      local m = unitAnchor(self_, ev.unit)
      if m then W.float(m, "Sort perdu", 0.6, 0.6, 0.6, 60) end
    end)
  elseif t == "say" then
    self:Push(0.3, function()
      local m = unitAnchor(self_, ev.unit)
      if m then W.float(m, ev.text, 1, 1, 0.4, 70, 2.5) end
    end)
  elseif t == "stunned" or t == "immune" or t == "flee" then
    local label = t == "stunned" and "Étourdi" or t == "immune" and "Insensible" or "S'enfuit"
    self:Push(0.2, function()
      local m = unitAnchor(self_, ev.unit)
      if m then W.float(m, label, 0.8, 0.8, 0.8, 60) end
    end)
  elseif t == "saved" then
    self:Push(0.3, function() W.float(self_.playerModel, "Esprit de rédemption !", 1, 1, 0.6, 60, 2) end)
  elseif t == "demence" and ev.n ~= 0 then
    self:Push(0.1, function()
      W.float(self_.playerModel, (ev.n > 0 and "+" or "") .. ev.n .. " Démence", 0.75, 0.5, 1, 75, 1.0)
    end)
  elseif t == "turn" then
    self:Push(0.2, function() W.float(self_.bf, "Tour " .. ev.round, 1, 0.82, 0, 60, 1.0) end)
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
  self.selected = nil
  local ok, why = Controller.play(i, target)
  if not ok then
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
  Controller.endTurn()
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
  card:SetFrameLevel(self.hz:GetFrameLevel() + 60)
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
    local p = W.panel(UI.content, "tooltip")
    p:SetAllPoints()
    p:SetFrameLevel(UI.content:GetFrameLevel() + 50)
    p:EnableMouse(true)
    p.models = {}
    local ids = {}
    for id in pairs(Art.enemies) do ids[#ids + 1] = id end
    table.sort(ids)
    for k = 1, #ids do
      local col, row = (k - 1) % 5, math.floor((k - 1) / 5)
      local m = newModel(p, 160, 180)
      m:SetPoint("TOPLEFT", 10 + col * 172, -10 - row * 216)
      local fb = p:CreateTexture(nil, "ARTWORK")
      fb:SetSize(48, 48)
      fb:SetPoint("CENTER", m, "CENTER")
      fb:Hide()
      local label = W.text(p, "GameFontNormal", 11)
      label:SetPoint("TOP", m, "BOTTOM", 0, -2)
      local art = Art.enemies[ids[k]]
      label:SetText((ns.Enemies[ids[k]] and ns.Enemies[ids[k]].name or ids[k])
        .. " (" .. tostring(art.creature) .. ")")
      m.id, m.fallback = ids[k], fb
      p.models[k] = m
    end
    local close = W.button(p, "Fermer", 100, 24, function() p:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -10, 10)
    self.preview = p
  end
  self.preview:Show()
  for k = 1, #self.preview.models do
    local m = self.preview.models[k]
    W.setCreature(m, m.id, m.fallback)
    if m.SetFacing then m:SetFacing(opts().facingEnemy or -0.6) end
  end
end
