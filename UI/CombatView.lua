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

-- Positions : docs/maquette/gen_combat_pack.py (coordonnées de fenêtre moins le cadre de 3).
local SLOTS = 6
local SLOT_W, SLOT_H = 150, 280
local HERO_X = 196                       -- centre du héros
local HERO_FEET = 292
local ENEMY_X0, ENEMY_X1 = 470, 1022     -- zone des ennemis
local HAND_CX, HAND_W = 530, 660         -- main : centre et largeur
local HAND_TOP = 418                     -- (plaque du bas comprise, la main reste dans la fenêtre)
local HOVER_SCALE = 1.16
local HOVER_TOP = 372                    -- haut d'une carte levée (survol ou sélection)
local SPREAD = { 26, 12 }                -- écart des voisines d'une carte levée (1re, 2e)
local PILE_H = 44                        -- piles : dos de carte de 44 de haut, bas à y 595 (< 614)
local DRAW_PILE = { 49, 573 }
local DISCARD_PILE = { 113, 573 }
local EXHAUST_PILE = { 177, 573 }
local MANA_X, MANA_Y = 81, 474           -- hexagone de mana (84) ; points de mana dessous
local COOLDOWN_X, COOLDOWN_Y = 940, 467  -- recharges (cases de 46)
local AIM_SCALE = 1.07                   -- ennemi visé (carte à cible armée) : il grandit un peu
-- Sous les pieds d'un ennemi (33 + hauteur du personnage sous le haut de l'emplacement, 193 à
-- l'échelle 1) : nom (pilule), jauge, états, décalés depuis les pieds.
local FIG_H = 160
local NAME_DY, NAME_H, NAME_SIZE = 3, 18, 13.5
local HP_DY, ST_DY = 33, 59
local INFO_LEVEL = 6                     -- cadre des infos : au-dessus du personnage (+1 à +4)
local ENEMY_TOP = 92                     -- haut de l'emplacement d'un ennemi à l'échelle 1
local ENEMY_STAGGER = 26                 -- un ennemi sur deux, posé un peu plus bas

local function now() return GetTime and GetTime() or 0 end
local function opts() return ns.Persist.options() end

local function enemyByUid(c, uid)
  for i = 1, #c.enemies do if c.enemies[i].uid == uid then return c.enemies[i], i end end
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

-- Bulle d'intention : pilule d'ardoise au liseré de la couleur de l'intention (rouge attaque, bleu
-- défense, violet guet…), pointe vers l'ennemi, icône ronde + chiffre blanc.
local function intentBubble(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(64, 30)
  f:EnableMouse(true)
  f.plaque = W.plaque(f, { r = 15, pill = true })
  f.tail = W.skin(f, "tail_slate", "BACKGROUND", -8)
  f.tail:SetSize(18, 9)
  f.tail:SetPoint("TOP", f, "BOTTOM", 0, 1.5)
  f.tailRim = W.skin(f, "tail_rim", "BACKGROUND", -7)
  f.tailRim:SetAllPoints(f.tail)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(22, 22)
  f.icon:SetPoint("CENTER", f, "LEFT", 16, 0)
  W.roundMask(f, f.icon)
  f.text = W.label(f, "heavy", 19, C.text)
  f.text:SetPoint("LEFT", f, "LEFT", 31, 0)
  f.SetRim = function(self, c)
    self.plaque:SetRim(c)
    self.tailRim:SetVertexColor(c[1], c[2], c[3], 1)
  end
  W.tooltip(f, function(tt, self) V.fillIntentTooltip(tt, self.enemy) end, "ANCHOR_TOP")
  return f
end

-- Personnage d'un emplacement posé par les pieds : la mise à l'échelle (visée) le fait grandir
-- vers le haut sans bouger la zone de clic (l'emplacement lui-même).
local function placeFig(s)
  local k = s.fig:GetScale() or 1
  local h = s.figH or 160
  s.fig:ClearAllPoints()
  s.fig:SetPoint("BOTTOM", s, "TOP", 0, -(33 + h) / k)
end

-- Nom, jauge et états sous les pieds (qui descendent avec la hauteur du personnage).
local function placeInfo(s)
  local feet = 33 + (s.figH or FIG_H)
  s.tag:ClearAllPoints()
  s.tag:SetPoint("TOP", s, "TOP", 0, -(feet + NAME_DY))
  s.hp:ClearAllPoints()
  s.hp:SetPoint("TOP", s, "TOP", 8, -(feet + HP_DY))
  s.st:ClearAllPoints()
  s.st:SetPoint("TOP", s, "TOP", 0, -(feet + ST_DY))
end

local function aimApply(s)
  local v = W.animValue(s, "aim")
  s.fig:SetScale(1 + (AIM_SCALE - 1) * v)
  placeFig(s)
  if s.fig.ring:IsShown() then s.fig.ring:SetAlpha(0.45 + 0.55 * max(v, s.ringBase or 0)) end
end

local function buildSlot(self, i)
  local s = CreateFrame("Button", nil, self.bf)
  s:SetSize(SLOT_W, SLOT_H)
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s.index = i
  s.intent = intentBubble(s)
  s.intent:SetPoint("TOP", 0, 0)
  s.fig = Scene.figure(s, 150, 160)
  s.figH = 160
  placeFig(s)
  s.fig:EnableMouse(false)
  s._animApply = aimApply
  s.model = s.fig.model
  s.fallback = s.fig.fallback
  s.flash = W.disc(s.fig, "OVERLAY", 0, C.hp, 0)
  s.flash:SetSize(110, 130)
  s.flash:SetPoint("CENTER", 0, 4)
  -- Infos (nom, jauge, Absorption, états) dans un cadre au-dessus du personnage et de son repli :
  -- aucun modèle, ombre ou anneau ne peut les recouvrir. Nom sur une pilule d'ardoise (lisible sur
  -- tout décor), au-dessus de la jauge, juste sous les pieds.
  s.info = CreateFrame("Frame", nil, s)
  s.info:SetAllPoints()
  s.info:SetFrameLevel(s:GetFrameLevel() + INFO_LEVEL)
  s.tag = CreateFrame("Frame", nil, s.info)
  s.tag:SetFrameLevel(s.info:GetFrameLevel() + 5) -- au-dessus de la jauge et des jetons d'état
  s.tag:SetSize(SLOT_W, NAME_H)
  s.tag.plaque = W.plaque(s.tag, { r = NAME_H / 2, pill = true, fill = 0.85, gloss = false })
  s.tag.plaque:SetRim(Art.rim.dim)
  s.name = W.label(s.tag, "bold", NAME_SIZE, C.text, "OVERLAY")
  s.name:SetPoint("CENTER", s.tag, "CENTER", 0, 0.5)
  s.name:SetWordWrap(false)
  s.hp = W.hpBar(s.info, 120, 13, 14)
  s.block = W.shieldBadge(s.info, 28, 28)
  s.block:SetPoint("LEFT", s.hp, "RIGHT", 4, 0)
  s.st = W.tokenRow(s.info, 6, SLOT_W + 10, 26)
  placeInfo(s)
  s:SetScript("OnClick", function(_, button) V:ClickEnemy(s, button) end)
  s:SetScript("OnEnter", function() s.hover = true V:RenderTargets() end)
  s:SetScript("OnLeave", function() s.hover = false V:RenderTargets() end)
  s:Hide()
  return s
end

-- Pile (pioche, défausse, consumées) : petit tas de cartes avec nombre ; clic = consulter
-- (panneau du deck, pioche triée).
local function pile(self, parent, cx, cy, key, label, style, level)
  local w = W.skinWidth("card_back", PILE_H)
  local b = CreateFrame("Button", nil, parent)
  at(b, parent, cx - w / 2, cy - PILE_H / 2, w, PILE_H)
  b:SetFrameLevel(level + 1)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  -- ombre portée, dos de carte (défausse estompée, consumées teintées de violet)
  b.shadow = W.cardBack(face, PILE_H, "BACKGROUND", -1)
  b.shadow:SetPoint("CENTER", 1.5, -2)
  b.shadow:SetVertexColor(0, 0, 0, 0.55)
  b.back = W.cardBack(face, PILE_H, "BACKGROUND", 0)
  b.back:SetPoint("CENTER")
  if style == "dashed" then b.back:SetAlpha(0.6) end
  if style == "exhaust" then b.back:SetDesaturated(true) b.back:SetVertexColor(0.75, 0.55, 1, 1) end
  b.count = W.label(face, "heavy", 15, C.text)
  b.count:SetPoint("CENTER", 0, 1)
  W.hoverable(b, { scale = 1.12, lift = 3 })
  b.pileKey = key
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then return end
    W.sound("click")
    UI.toggleDeckView(key)
  end)
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

  -- Barre d'incantation : plaque d'ardoise, médaillon du sort, nom, jauge dorée.
  local cast = CreateFrame("Frame", nil, parent)
  at(cast, parent, HERO_X - 98, 79, 190, 36)
  cast:SetFrameLevel(parent:GetFrameLevel() + 20)
  cast.plaque = W.plaque(cast, { r = 10 })
  cast.medal = W.medallion(cast, 32)
  cast.medal:SetPoint("CENTER", cast, "LEFT", 22, 0)
  cast.name = W.label(cast, "bold", 12.5, C.text)
  cast.name:SetPoint("LEFT", cast, "LEFT", 41, 5)
  cast.name:SetWidth(140)
  cast.name:SetJustifyH("LEFT")
  cast.name:SetWordWrap(false)
  cast.track = W.rect(cast, "ARTWORK", 0, C.barTrack)
  cast.track:SetPoint("LEFT", cast, "LEFT", 41, -8)
  cast.track:SetSize(140, 6)
  cast.bar = W.rect(cast, "ARTWORK", 1, C.goldText)
  cast.bar:SetPoint("LEFT", cast.track, "LEFT", 1, 0)
  cast.bar:SetSize(87, 4)
  cast:EnableMouse(true)
  W.tooltip(cast, function(tt)
    local c = Controller.combat()
    local pc = c and c.player.cast
    if not pc then return end
    -- la ligne « Incantation » de la carte dit déjà quand elle part
    W.fillCardTooltip(tt, pc.card.id, pc.card.up, { full = true })
  end, "ANCHOR_TOP")
  cast:Hide()
  self.cast = cast

  -- Jauge de vie (hexagone rouge au bout), Absorption en hexagone d'acier au bout droit, jetons d'état.
  local hpRow = CreateFrame("Frame", nil, parent)
  at(hpRow, parent, HERO_X - 65, HERO_FEET + 10, 138, 13)
  self.playerHp = W.hpBar(hpRow, 138, 13, 15)
  self.playerHp:SetPoint("LEFT", 0, 0)
  self.playerBlock = W.shieldBadge(hpRow, 30, 30)
  self.playerBlock:SetPoint("CENTER", self.playerHp, "RIGHT", 18, 0)
  self.playerSt = W.tokenRow(parent, 8, 230, 30)
  at(self.playerSt, parent, HERO_X - 115, HERO_FEET + 38, 230, 30)
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

  -- Mana : grand hexagone bleu « 2/3 », un petit hexagone par point de mana (vides une fois dépensés).
  local mana = CreateFrame("Frame", nil, parent)
  at(mana, parent, MANA_X - 42, MANA_Y - 42, 84, 84)
  mana:SetFrameLevel(hz:GetFrameLevel() + 2)
  mana:EnableMouse(true)
  mana.hex = W.hex(mana, "blue", 84)
  mana.hex:SetPoint("CENTER")
  mana.text = W.label(mana, "heavy", 36, C.text, "OVERLAY")
  mana.text:SetPoint("CENTER", -6, 3)
  mana.max = W.label(mana, "heavy", 18, Art.hex("#d6e6ff"), "OVERLAY")
  mana.max:SetPoint("LEFT", mana.text, "RIGHT", 0, -6)
  mana.pips = {}
  for i = 1, 8 do
    local p = W.hex(parent, "blue", 18, "ARTWORK", 0)
    p:Hide()
    mana.pips[i] = p
  end
  W.tooltip(mana, function(tt)
    tt:AddLine("Mana", 0.4, 0.6, 1)
    tt:AddLine("Unspent mana is lost at the end of the turn.", 0.8, 0.8, 0.8, true)
  end, "ANCHOR_RIGHT")
  self.mana = mana

  -- Démence : hexagone violet en haut à droite du mana (caché à 0).
  local dem = CreateFrame("Frame", nil, parent)
  at(dem, parent, MANA_X + 44 - 17, MANA_Y - 32 - 17, 34, 34)
  dem:SetFrameLevel(hz:GetFrameLevel() + 3)
  dem:EnableMouse(true)
  dem.hex = W.hex(dem, "violet", 34)
  dem.hex:SetPoint("CENTER")
  dem.text = W.label(dem, "heavy", 15, C.text)
  dem.text:SetPoint("CENTER", 0, 1)
  W.tooltip(dem, function(tt)
    tt:AddLine(Art.keywordLine("demence"), 1, 1, 1, true)
  end, "ANCHOR_RIGHT")
  self.demence = dem

  self.drawPile = pile(self, parent, DRAW_PILE[1], DRAW_PILE[2], "draw", "Draw pile", "full", hz:GetFrameLevel() + 1)
  self.discardPile = pile(self, parent, DISCARD_PILE[1], DISCARD_PILE[2], "discard", "Discard pile", "dashed",
    hz:GetFrameLevel() + 1)
  self.exhaustPile = pile(self, parent, EXHAUST_PILE[1], EXHAUST_PILE[2], "exhaust", "Exhausted", "exhaust",
    hz:GetFrameLevel() + 1)
  self.exhaustPile:Hide()

  -- Recharges (cases d'ardoise : icône grisée, tours restants) et fin du tour -------------------
  self.cdCards = {}
  for i = 1, 6 do
    local m = CreateFrame("Frame", nil, parent)
    m:SetSize(46, 46)
    m:SetFrameLevel(hz:GetFrameLevel() + 2)
    m:EnableMouse(true)
    m.plaque = W.plaque(m, { r = 9, fill = 0.7, gloss = false })
    m.plaque:SetRim(Art.rim.dim)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetSize(38, 38)
    m.icon:SetPoint("CENTER")
    m.icon:SetDesaturated(true)
    m.icon:SetVertexColor(0.6, 0.6, 0.6, 1)
    W.roundMask(m, m.icon, "mask_roundsq")
    m.count = W.label(m, "heavy", 24, C.text)
    m.count:SetPoint("CENTER", 0, 1)
    W.tooltip(m, function(tt, f)
      if not f.cd then return end
      W.fillCardTooltip(tt, f.cd.card.id, f.cd.card.up, { full = true })
      tt:AddLine(" ")
      tt:AddLine("Returns to hand in " .. f.turns .. " turn" .. (f.turns > 1 and "s" or "") .. ".", 1, 0.82, 0)
    end, "ANCHOR_TOP")
    m:Hide()
    self.cdCards[i] = m
  end

  self.endTurn = W.button(parent, "End Turn", 156, 50, function() V:EndTurn() end, "gold", 19)
  at(self.endTurn, parent, 863, 520, 156, 50)
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
    -- Survol piloté par l'écran (la carte sélectionnée reste levée).
    card._hoverManual = true
    card.hoverScale = HOVER_SCALE
    card.onEnterExtra = function(f) f.hover = true V:PlaceCard(f) V:Spread() end
    card.onLeaveExtra = function(f) f.hover = false V:PlaceCard(f) V:Spread() end
    card:Hide()
    self.cards[i] = card
  end

  -- Fin de combat ---------------------------------------------------------------------
  local banner = CreateFrame("Frame", nil, parent)
  at(banner, parent, 317, 150, 400, 150)
  banner:SetFrameLevel(parent:GetFrameLevel() + 70)
  banner:EnableMouse(true)
  banner.plaque = W.plaque(banner, { r = 16 })
  banner.text = W.label(banner, "heavy", 44, C.goldText, "OVERLAY")
  banner.text:SetPoint("TOP", 0, -18)
  banner.button = W.button(banner, "Continue", 190, 50, function() Controller.finishCombat() end, "gold", 18)
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
  block = function(a) return "Gains " .. a[2] .. " Absorb." end,
  debuff = function(a)
    local s = ns.Statuses[a[2]]
    return "Applies " .. (s and s.name or a[2]) .. " " .. a[3] .. "."
  end,
  buff = function(a)
    local s = ns.Statuses[a[2]]
    return "Gains " .. (s and s.name or a[2]) .. " " .. a[3] .. "."
  end,
  buff_allies = function(a)
    local s = ns.Statuses[a[2]]
    return "Gives " .. (s and s.name or a[2]) .. " " .. a[3] .. " to its allies."
  end,
  heal_ally = function(a) return "Heals the most wounded ally for " .. a[2] .. "." end,
  block_ally = function(a) return "Gives " .. a[2] .. " Absorb to an ally." end,
  interrupt = function() return "Interrupts your cast." end,
  summon = function(a)
    local d = ns.Enemies[a[2]]
    return "Summons " .. ((a.count or 1) > 1 and (a.count .. " × ") or "") .. (d and d.name or a[2]) .. "."
  end,
}

function V.fillIntentTooltip(tt, e)
  local c = Controller.combat()
  if not c or not e or e.dead then return end
  local info = Combat.intentInfo(c, e)
  local mv = ns.Enemies[e.id].moves[e.intent]
  tt:AddLine(info.name or e.intent, 1, 0.82, 0)
  tt:AddLine(Art.intentName[info.kind] or info.kind or "", 0.7, 0.7, 0.7)
  if info.stunned then tt:AddLine("Stunned: loses its next turn.", 0.4, 0.9, 1, true) end
  if info.interrupted then tt:AddLine("Spell interrupted: it won't go off.", 0.4, 0.9, 1, true) end
  if mv.text then tt:AddLine(mv.text, 1, 1, 1, true) end
  for i = 1, #mv.actions do
    local a = mv.actions[i]
    if a[1] == "attack" then
      local times = a.times or 1
      tt:AddLine("Attack: " .. Combat.calcDamage(c, e, c.player, a[2])
        .. (times > 1 and (" × " .. times) or "") .. " damage.", 1, 0.5, 0.5, true)
      if a.interrupts then tt:AddLine("Interrupts your cast.", 1, 0.5, 0.5, true) end
    elseif ACTION_TEXT[a[1]] then
      tt:AddLine(ACTION_TEXT[a[1]](a), 1, 1, 1, true)
    end
  end
  if info.cast and not info.interrupted then
    tt:AddLine("Spell being cast: an Interrupt cancels it.", 1, 0.6, 0.2, true)
  end
end

function V.fillPileTooltip(tt, key, label)
  local c = Controller.combat()
  if not c then return end
  local pileList = c[key]
  tt:AddLine(label .. " (" .. #pileList .. ")", 1, 0.82, 0)
  if key == "draw" then tt:AddLine("Sorted list: the draw order stays hidden.", 0.6, 0.6, 0.6) end
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
    tt:AddLine("Exhausted: " .. #c.exhaust, 0.8, 0.6, 0.4)
  end
  tt:AddLine("Click: view the cards.", 0.6, 0.6, 0.6)
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
      s.figH = FIG_H * sc
      placeInfo(s)
      W.animSet(s, "aim", 0)
      W.setCreature(s.model, e.id, s.fallback)
      if s.model.SetFacing then s.model:SetFacing(opts().facingEnemy or -0.6) end
      W.modelAlpha(s.model, 1)
      s.fig.shadow:SetAlpha(1)
      s:SetAlpha(1)
      s.hp:Set(e.hp, e.maxHp)
      s.block:Set(e.block)
    end
    s.enemyIndex = idx
    s.cx = cx0 + (k - 1) * spacing
    -- personnage agrandi (art.scale) : l'emplacement remonte, les pieds restent sur la même ligne
    s.top = ENEMY_TOP + ((k % 2 == 0) and ENEMY_STAGGER or 0) - Scene.TOP - ((s.figH or FIG_H) - FIG_H)
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
  if info.stunned then return Art.intents.stunned, "Stunned", "defend" end
  if info.interrupted then return Art.intents.interrupted, "Interrupted", "defend" end
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
  if info.kind == "watch" then text = "Watch" end
  local entry = Art.intents[info.kind] or Art.intents.attack
  return entry, text, entry.color
end

function V:RenderIntent(s, e)
  local c = self.c
  s.intent.enemy = e
  if e.dead or c.result then s.intent:Hide() return end
  local entry, text, color = intentDisplay(c, e)
  W.setIcon(s.intent.icon, entry, "intent:" .. tostring(Combat.intentInfo(c, e).kind))
  s.intent:SetRim(Art.rim[color] or Art.rim.attack)
  local big = W.utf8len(text) <= 2
  W.setSize(s.intent.text, big and 19 or 13.5)
  s.intent.text:SetText(text)
  s.intent:SetWidth(big and 64 or max(64, (s.intent.text:GetStringWidth() or 20) + 44))
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
    if s.name:GetText() ~= def.name then
      W.fitText(s.name, def.name, NAME_SIZE, SLOT_W - 14, 10)
      s.tag:SetWidth(min(SLOT_W, (s.name:GetStringWidth() or 60) + 18))
    end
    local nc = def.boss and { 1, 0.6, 0.25 } or (def.elite and C.watchText or C.text)
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
    -- visée : l'ennemi survolé (ou la cible clavier) grandit, son anneau s'allume
    s.ringBase = targeting and 0 or 1
    local aim = alive and targeting and (s.hover or s.enemyIndex == kb)
    W.animTo(s, "aim", aim and 1 or 0, aim and W.HOVER_IN or W.HOVER_OUT)
    aimApply(s)
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
      list[#list + 1] = { icon = W.cardArt(inst.id), text = Card.def(inst).name, rim = Art.rim.gold,
        info = { power = inst }, key = "card:" .. inst.id }
    end
    self.playerSt:Set(list)
  end
  if p.cast then
    local d = Card.def(p.cast.card)
    local tgt = p.cast.target and enemyByUid(c, p.cast.target)
    self.cast.name:SetText(d.name .. (tgt and (" on " .. ns.Enemies[tgt.id].name) or ""))
    W.setIcon(self.cast.medal.icon, W.cardArt(p.cast.card.id), "card:" .. p.cast.card.id)
    self.cast:Show()
  else
    self.cast:Hide()
  end
  -- mana : chiffre, maximum, un petit hexagone par point (bleu disponible, vide dépensé)
  local maxMana = Controller.maxMana()
  self.mana.text:SetText(tostring(p.mana))
  self.mana.max:SetText("/" .. maxMana)
  local pips = self.mana.pips
  local n = min(#pips, max(maxMana, p.mana))
  for i = 1, #pips do
    local pip = pips[i]
    if i <= n then
      W.setHex(pip, i <= p.mana and "blue" or "empty", 18)
      pip:ClearAllPoints()
      pip:SetPoint("CENTER", self.parent, "TOPLEFT", MANA_X + (i - (n + 1) / 2) * 22, -(MANA_Y + 55))
      pip:Show()
    else
      pip:Hide()
    end
  end
  local dem = p.demence or 0
  self.demence.text:SetText(tostring(dem))
  if dem > 0 then self.demence:Show() else self.demence:Hide() end
  self.drawPile.count:SetText(#c.draw)
  self.discardPile.count:SetText(#c.discard)
  self.exhaustPile.count:SetText(#c.exhaust)
  if #c.exhaust > 0 then self.exhaustPile:Show() else self.exhaustPile:Hide() end
  -- recharges
  local n = min(#c.cooldown, #self.cdCards)
  local per = n > 3 and 3 or n
  for i = 1, #self.cdCards do
    local m = self.cdCards[i]
    local cd = c.cooldown[i]
    if cd and i <= n then
      local turns = cd.turns + 1
      m.cd, m.turns = cd, turns
      W.setIcon(m.icon, W.cardArt(cd.card.id), "card:" .. cd.card.id)
      m.count:SetText(tostring(turns))
      local row, col = floor((i - 1) / 3), (i - 1) % 3
      local rowN = (row == 0) and per or (n - 3)
      local x0 = COOLDOWN_X - (rowN * 54 - 8) / 2
      at(m, self.parent, x0 + col * 54, COOLDOWN_Y - 23 - row * 54, 46, 46)
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

-- Carte de la main : la zone de clic reste à sa place dans l'éventail ; le visuel (face) se lève,
-- grossit et passe devant au survol ou à la sélection (canal « hover »).
function V:PlaceCard(card)
  if not card.baseX or self.dragging == card then return end
  local up = (self.selected == card.index or card.hover) and true or false
  card.lifted = up
  local cy = card.baseY + W.CARD_H / 2
  -- levée : le haut de la carte agrandie arrive à HOVER_TOP
  card.hoverLift = cy - (HOVER_TOP + W.CARD_H * HOVER_SCALE / 2)
  local base = self.hz:GetFrameLevel() + 5 + card.index * 3
  W.placeCard(card, self.parent, card.baseX, cy, 1, base, base + 60)
  W.animTo(card, "hover", up and 1 or 0, up and W.HOVER_IN or W.HOVER_OUT)
  -- zone de survol prolongée vers le haut tant que la carte est levée (on peut monter dessus)
  if card.SetHitRectInsets then
    local top = up and -floor(card.hoverLift + W.CARD_H * (HOVER_SCALE - 1) / 2) or 0
    if card._hitTop ~= top then card._hitTop = top card:SetHitRectInsets(0, 0, top, 0) end
  end
  card:SetHot(up)
end

-- Les voisines d'une carte levée (agrandie, donc plus large) s'écartent un peu ; visuel seulement :
-- leurs zones de clic ne bougent pas.
function V:Spread()
  local n = self.c and #self.c.hand or 0
  local focus
  for i = 1, min(n, #self.cards) do
    if self.cards[i].hover then focus = i end
  end
  focus = focus or self.selected
  for i = 1, #self.cards do
    local card = self.cards[i]
    local dx = 0
    if focus and i ~= focus and i <= n then
      local d = i - focus
      dx = (SPREAD[abs(d)] or 0) * (d > 0 and 1 or -1)
    end
    if self.dragging ~= card then W.animTo(card, "dx", dx, W.HOVER_IN) end
  end
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
      card.hover, card.lifted = false, false
      W.hoverReset(card)
      card:Hide()
    end
  end
  self:Spread()
end

function V:RenderBanner()
  local over = Controller.over()
  if over then
    self.banner.text:SetText(over == "won" and "Victory!" or "Defeat")
    local col = over == "won" and C.goldText or C.badText
    self.banner.text:SetTextColor(col[1], col[2], col[3])
    self.banner.button:SetText(over == "won" and "Continue" or "See the summary")
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
  return s.cx, Scene.TOP + s.top + (33 + (s.figH or FIG_H) / 2) * sc, s
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
        W.tween(0.9, function(p) W.modelAlpha(m, 1 - p) who.fig.shadow:SetAlpha(1 - p) who:SetAlpha(1 - 0.7 * p) end, function()
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
      if x then W.float(self_.parent, x, y - 60, "Interrupted!", C.defendText, 20, 1.3) end
    end)
  elseif t == "cast_start" then
    self:Push(0.2, function() W.anim(self_.playerModel, A.ready, 1.2) end)
  elseif t == "cast_resolve" then
    self:Push(0.35, function() W.anim(self_.playerModel, A.spellOmni, 1.0) end)
  elseif t == "cast_lost" then
    self:Push(0.2, function()
      local x, y = self_:UnitPos(ev.unit)
      if x then W.float(self_.parent, x, y - 60, "Spell lost", C.defendText, 16) end
    end)
  elseif t == "say" then
    self:Push(0.4, function()
      local x, y = self_:UnitPos(ev.unit)
      if x then W.float(self_.parent, x, y - 110, ev.text, C.creamLight, 15, 2.6, 12) end
    end)
  elseif t == "stunned" or t == "immune" or t == "flee" then
    local label = t == "stunned" and "Stunned" or t == "immune" and "Immune" or "Flees"
    self:Push(0.25, function()
      local x, y = self_:UnitPos(ev.unit)
      if x then W.float(self_.parent, x, y - 60, label, C.defendText, 16) end
    end)
  elseif t == "saved" then
    self:Push(0.4, function() W.float(self_.parent, HERO_X, HERO_FEET - 150, "Spirit of Redemption!", C.goldText, 18, 2) end)
  elseif t == "demence" and ev.n ~= 0 then
    self:Push(0.1, function()
      W.float(self_.parent, MANA_X + 44, MANA_Y - 40, (ev.n > 0 and "+" or "") .. ev.n .. " Insanity", C.watchText, 15, 1.0, 26)
    end)
  elseif t == "mana" and ev.n ~= 0 then
    self:Push(0.1, function() W.float(self_.parent, MANA_X, MANA_Y - 10, "+" .. ev.n .. " mana", C.defendText, 15, 1.0, 26) end)
  elseif t == "turn" then
    self:Push(0.35, function()
      W.float(self_.parent, 517, 120, "Turn " .. ev.round, C.goldText, 26, 1.1, 16)
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
  if fromCooldown then fx, fy = COOLDOWN_X, COOLDOWN_Y end
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
  UI.flash("Potion: click its target.")
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
  -- la carte suit le curseur : plus de levée ni d'écart, elle garde sa taille de survol
  card.hoverLift = 0
  W.animSet(card, "dx", 0)
  W.animTo(card, "hover", 1, W.HOVER_IN)
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
-- Aperçu des modèles (/slay models) : vérifie l'art sans toucher à l'expédition
---------------------------------------------------------------------------

-- Entrées de l'aperçu : ennemis (Art.enemies) puis personnages des rencontres (Art.npcs), triés.
local function previewEntries()
  local out, ids = {}, {}
  for id in pairs(Art.enemies) do ids[#ids + 1] = id end
  table.sort(ids)
  for i = 1, #ids do
    local d = ns.Enemies[ids[i]]
    out[#out + 1] = { id = ids[i], key = ids[i], art = Art.enemies[ids[i]], name = d and d.name or ids[i] }
  end
  local speaker = {}
  for _, ev in pairs(ns.Events or {}) do
    if type(ev) == "table" and ev.npc and ev.speaker then speaker[ev.npc] = ev.speaker end
  end
  ids = {}
  for id in pairs(Art.npcs) do ids[#ids + 1] = id end
  table.sort(ids)
  for i = 1, #ids do
    out[#out + 1] = { id = "npc:" .. ids[i], key = "npc:" .. ids[i], art = Art.npcs[ids[i]],
      name = speaker[ids[i]] or ids[i], npc = true }
  end
  return out
end

-- Identifiants essayés, en clair : « creature 619, display 2329, display 2330 ».
local function triesText(art)
  local t = W.modelTries(art)
  local parts = {}
  for i = 1, #t do parts[i] = W.tryLabel(t[i]) end
  return #parts > 0 and table.concat(parts, ", ") or "no identifier"
end

local PREVIEW_COLS = 6

function V:PreviewEnemies()
  if not self.preview then
    local p = W.woodPanel(UI.content, 10)
    p:SetPoint("TOPLEFT", 10, -50)
    p:SetPoint("BOTTOMRIGHT", -10, 10)
    p:SetFrameLevel(UI.content:GetFrameLevel() + 95)
    p:EnableMouse(true)
    p.title = W.label(p, "bold", 14, C.textSoft)
    p.title:SetPoint("TOPLEFT", 16, -10)
    p.title:SetText("Enemy and character models (chat lists the missing ones)")
    p.models = {}
    local list = previewEntries()
    local rows = math.ceil(#list / PREVIEW_COLS)
    local cellW = (UI.CONTENT_W - 20 - 24) / PREVIEW_COLS
    local rowH = min(236, (UI.CONTENT_H - 60 - 36 - 50) / max(1, rows))
    local figH = min(170, rowH - 52)
    for k = 1, #list do
      local e = list[k]
      local col, row = (k - 1) % PREVIEW_COLS, floor((k - 1) / PREVIEW_COLS)
      local fig = Scene.figure(p, 150, figH)
      fig:SetPoint("TOP", p, "TOPLEFT", 12 + (col + 0.5) * cellW, -36 - row * rowH)
      local m = fig.model
      local label = W.label(p, "bold", 12, C.text)
      label:SetPoint("TOP", fig, "BOTTOM", 0, -3)
      label:SetWidth(cellW - 6)
      label:SetWordWrap(false)
      label:SetText(e.name)
      local ids = W.label(p, "body", 10.5, C.textDim)
      ids:SetPoint("TOP", label, "BOTTOM", 0, -1)
      ids:SetWidth(cellW - 6)
      ids:SetText(triesText(e.art))
      m.state = W.label(p, "bold", 11, C.textDim)
      m.state:SetPoint("TOP", ids, "BOTTOM", 0, -1)
      m.state:SetWidth(cellW - 6)
      m.id, m.key, m.art, m.npc, m.fallback, m.label = e.id, e.key, e.art, e.npc, fig.fallback, e.name
      p.models[k] = m
    end
    local close = W.button(p, "Close", 110, 30, function() p:Hide() end, "gold", 14)
    close:SetPoint("BOTTOMRIGHT", -14, 14)
    self.preview = p
  end
  self.preview:Show()
  local most = 1
  for k = 1, #self.preview.models do
    local m = self.preview.models[k]
    m.state:SetText("loading")
    m.state:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    if m.npc then
      m.fallback:Hide()
      W.setFallbackArt(m.fallback, nil)
      W.setCreatureArt(m, m.art, m.key, function() m.fallback:Show() end, function() m.fallback:Hide() end)
    else
      W.setCreature(m, m.id, m.fallback)
    end
    most = max(most, #W.modelTries(m.art))
    if m.SetFacing then m:SetFacing(opts().facingEnemy or -0.6) end
  end
  -- rapport au chat quand tous les essais ont eu leur délai
  self.previewToken = (self.previewToken or 0) + 1
  local token = self.previewToken
  UI.say("model preview: checking (" .. #self.preview.models .. " models, about "
    .. math.ceil(most * W.MODEL_WAIT) .. " s).")
  W.delay(most * W.MODEL_WAIT + 0.2, function()
    if self.previewToken == token then self:ReportModels() end
  end)
end

-- Lignes du rapport (/slay models), à recopier telles quelles : une par modèle absent, puis une par
-- modèle chargé seulement par un essai de repli. ASCII pour les flèches (polices du jeu).
function V:ModelReportLines()
  local lost, late, ok = {}, {}, 0
  local models = self.preview and self.preview.models or {}
  for k = 1, #models do
    local m = models[k]
    local st = W.models[m.key]
    if st and st.state == "ok" then
      ok = ok + 1
      if st.via ~= st.tries[1] then
        local failed = {}
        for i = 1, #st.tries do
          if st.tries[i] == st.via then break end
          failed[#failed + 1] = st.tries[i]
        end
        late[#late + 1] = m.key .. ": " .. table.concat(failed, ", ") .. " -> no model; loaded by " .. st.via
      end
    else
      local tried = st and #st.tries > 0 and table.concat(st.tries, ", ") or "no identifier"
      lost[#lost + 1] = m.key .. ": " .. tried .. " -> no model"
    end
  end
  local lines = { "models: " .. ok .. "/" .. #models .. " loaded"
    .. (#lost > 0 and (", " .. #lost .. " without a model:") or ".") }
  for i = 1, #lost do lines[#lines + 1] = lost[i] end
  if #late > 0 then lines[#lines + 1] = "loaded by a fallback identifier:" end
  for i = 1, #late do lines[#lines + 1] = late[i] end
  return lines, #lost
end

function V:ReportModels()
  local models = self.preview and self.preview.models or {}
  for k = 1, #models do
    local m = models[k]
    local st = W.models[m.key]
    local good = st and st.state == "ok"
    m.state:SetText(good and ("model: " .. st.via) or "no model")
    local c = good and C.healGreen or C.badText
    m.state:SetTextColor(c[1], c[2], c[3])
  end
  local lines = self:ModelReportLines()
  for i = 1, #lines do UI.say(i == 1 and lines[i] or ("  " .. lines[i])) end
end
