-- Arbres de talents à l'écran (docs/talents.md, § 11 ; données : step.talents de UI/Controller.lua, lu dans
-- ns.Talent.view) : onglet « Talents » de l'écran Progress (UI/Screens.lua, ClassProgress), pastille des points
-- à dépenser (accueil, onglet, bilan), liste des talents actifs dans le panneau du deck pendant l'expédition.
--
-- Onglet : ligne des points en haut (« 3 talent points to spend · 12 of 24 spent »), ligne d'état dessous (expédition
-- en cours : lecture seule ; classe sans arbre ; aucun point encore), bouton « Reset talents » à droite (gratuit,
-- confirmé par un second clic ; grisé pendant une expédition ou sans point dépensé, raison en infobulle). Quatre
-- rangées horizontales (bandeau sombre, « Tier N » à gauche ; fermée : bandeau plus sombre, nœuds grisés et sa
-- condition « Spend 10 points to unlock. » sous son nom). Nœud : icône ronde dans le grand anneau doré, rang
-- « 2/3 » dans une pastille sous l'anneau (vert : un rang s'apprend ; or : rang maximal ; gris : rien à faire),
-- nom dessous ; grisé (désaturé, assombri) tant qu'aucun rang n'est appris et qu'il ne s'apprend pas. Clic = un
-- rang (refus : sa raison en message). Nœud Specialization : trois faces (une par voie), clic = choix de la voie
-- (changer ensuite : gratuit) ; la voie active pleine à l'anneau d'or, les autres assombries. Infobulles : nom,
-- « Rank 1/3 », texte du rang actuel, « Next rank: » et le texte suivant, raison en rouge ; Specialization : les
-- trois voies et leurs textes.
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art, UI, Scene = ns.Widgets, ns.Art, ns.UI, ns.Scene
local C = Art.C
local at = Scene.at
local max, min, floor = math.max, math.min, math.floor

local TV = {}
UI.talentView = TV

-- Mise en page (coordonnées de la scène, panneau de ClassProgress : 6, 40, 1022 × 570). Ligne des points centrée
-- à TV_SUM_Y, ligne d'état à TV_NOTE_Y ; « Reset talents » en TV_RESET ; rangées de TV_ROW_H à partir de
-- TV_ROW_TOP, au pas TV_ROW_DY, bandeaux de TV_BAND_X à TV_BAND_X + TV_BAND_W ; noms des rangées à TV_LABEL_X
-- (largeur TV_LABEL_W) ; nœuds centrés sur TV_NODES_CX, au pas TV_PITCH au plus (TV_NODES_W en tout), icônes de
-- TV_ICON (centre à TV_ICON_DY sous le haut de la rangée), pastille du rang à TV_RANK_DY, nom à TV_NAME_DY ;
-- faces de Specialization de TV_FACE au pas TV_FACE_DX.
local TV_SUM_Y, TV_NOTE_Y = 122, 145
local TV_RESET_X, TV_RESET_Y, TV_RESET_W, TV_RESET_H = 860, 104, 150, 36
local TV_ROW_TOP, TV_ROW_H, TV_ROW_DY = 162, 100, 108
local TV_BAND_X, TV_BAND_W = 24, 984
local TV_LABEL_X, TV_LABEL_W = 42, 150
local TV_NODES_CX, TV_NODES_W, TV_PITCH = 604, 790, 170
local TV_ICON, TV_ICON_DY, TV_RANK_DY, TV_NAME_DY = 52, 36, 64, 87
local TV_FACE, TV_FACE_DX = 42, 48
local TV_NODES, TV_FACES, TV_ROWS = 18, 4, 4
TV.L = { sumY = TV_SUM_Y, noteY = TV_NOTE_Y, rowTop = TV_ROW_TOP, rowH = TV_ROW_H, rowDy = TV_ROW_DY,
  icon = TV_ICON, face = TV_FACE, pitch = TV_PITCH, nodesCx = TV_NODES_CX, nodesW = TV_NODES_W }

-- Couleurs du rang (comme le cadre des talents du jeu) : vert = un rang s'apprend, or = maximum, gris = rien.
local RANK_GREEN, RANK_GOLD, RANK_GREY = { 0.25, 1, 0.25 }, { 1, 0.82, 0 }, { 0.6, 0.6, 0.6 }

local function chooseOption(o)
  if not o then return end
  if o.disabled then UI.flash(o.reason or "Unavailable.") return end
  W.sound("click")
  UI.choose(o.id)
end
TV.chooseOption = chooseOption

---------------------------------------------------------------------------
-- Pastille d'un nombre (points à dépenser) : disque rouge dans le petit anneau doré, nombre blanc ; posée au
-- coin haut droit d'un bouton (enfant du bouton, sans souris : le clic reste au bouton). Infobulle du bouton :
-- son texte (b.badgeTip, montré par TV.badgeOn).
---------------------------------------------------------------------------

function TV.badge(button, size)
  size = size or 24
  local f = CreateFrame("Frame", nil, button)
  f:SetSize(size, size)
  f:SetFrameLevel(button:GetFrameLevel() + 6)
  f:EnableMouse(false)
  f.disc = W.disc(f, "ARTWORK", 0, C.hpRed, 1)
  f.disc:SetSize(size * 0.78, size * 0.78)
  f.disc:SetPoint("CENTER")
  f.ring = W.wow(f, "ring_small", "ARTWORK", 1)
  f.ring:SetSize(size, size)
  f.ring:SetPoint("CENTER")
  f.count = W.label(f, "heavy", size >= 24 and 12.5 or 11, C.text, "OVERLAY")
  f.count:SetPoint("CENTER", 0, 0.5)
  f:SetPoint("CENTER", button, "TOPRIGHT", -size * 0.3, -size * 0.25)
  f:Hide()
  return f
end

-- Pastille d'un bouton (créée au premier appel, à la construction de l'écran) : n > 0 la montre avec ce nombre,
-- tip = infobulle du bouton ; sinon cachée.
function TV.badgeOn(button, n, tip)
  local f = button.badge
  if not f then
    f = TV.badge(button)
    button.badge = f
    local enter, leave = button.onEnterExtra, button.onLeaveExtra
    button.onEnterExtra = function(self)
      if enter then enter(self) end
      if self.badgeTip and self.badge:IsShown() and GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.badgeTip, 1, 0.82, 0, true)
        GameTooltip:Show()
      end
    end
    button.onLeaveExtra = function(self)
      if leave then leave(self) end
      if GameTooltip then GameTooltip:Hide() end
    end
  end
  if n and n > 0 then
    f.count:SetText(tostring(n))
    button.badgeTip = tip
    f:Show()
  else
    button.badgeTip = nil
    f:Hide()
  end
end

---------------------------------------------------------------------------
-- Nœud : icône ronde (grand anneau doré), halo doré de survol (créé éteint), pastille du rang sous l'anneau
---------------------------------------------------------------------------

local function paintNode(self, h)
  local k = self.bright or 1
  k = min(1, k + (1 - k) * 0.35 * h)
  self.icon:SetVertexColor(k, k, k, 1)
  local rc = self.ringTint or Art.rim.silver
  self.ring:SetVertexColor(rc[1] * k, rc[2] * k, rc[3] * k, 1)
  self.glow:SetAlpha(0.6 * h)
end

local function nodeButton(parent, size, withRank)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  b.glow = W.skin(face, "glow_round", "BACKGROUND", -8)
  b.glow:SetPoint("CENTER")
  b.glow:SetSize(size * 1.6, size * 1.6)
  b.glow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
  b.glow:SetAlpha(0)
  W.medallionOn(face, size)
  b.icon, b.ring = face.icon, face.ring
  if withRank then
    -- pastille du rang, régions du visuel au-dessus de l'anneau (ARTWORK 3 et 4, texte en OVERLAY ; aucun cadre enfant : le visuel
    -- reste d'un seul bloc) : disque sombre dans le petit anneau doré, « 2/3 »
    local dy = -(TV_RANK_DY - TV_ICON_DY)
    local p = {}
    p.bg = W.disc(face, "ARTWORK", 3, C.black, 0.85)
    p.bg:SetSize(34, 22)
    p.bg:SetPoint("CENTER", face, "CENTER", 0, dy)
    p.ring = W.wow(face, "ring_small", "ARTWORK", 4)
    p.ring:SetSize(38, 26)
    p.ring:SetPoint("CENTER", face, "CENTER", 0, dy)
    p.text = W.label(face, "heavy", 11.5, C.text, "OVERLAY")
    p.text:SetPoint("CENTER", face, "CENTER", 0, dy + 0.5)
    b.rank = p
  end
  W.hoverable(b, { paint = paintNode })
  b:SetScript("OnClick", function(self) chooseOption(self.option) end)
  b:Hide()
  return b
end

-- État visuel d'un nœud (ou d'une face) : bright (luminosité de l'icône), désaturé, teinte de l'anneau.
local function setLook(b, bright, desat, ring)
  b.bright, b.ringTint = bright, ring
  b.icon:SetDesaturated(desat and true or false)
  paintNode(b, W.animValue(b, "hover"))
end

-- Infobulle d'un nœud ordinaire : nom, rang, texte du rang actuel, rang suivant, raison ou consigne.
local function fillNode(tt, b)
  local o = b.option
  if not o then return end
  tt:AddLine(o.name or "", 1, 0.82, 0)
  tt:AddLine("Rank " .. o.rank .. "/" .. o.ranks, 1, 1, 1)
  if o.text then tt:AddLine(o.text, 1, 1, 1, true) end
  if o.nextText then
    if o.rank > 0 then tt:AddLine("Next rank:", 1, 0.82, 0) end
    tt:AddLine(o.nextText, o.rank > 0 and 0.85 or 1, o.rank > 0 and 0.85 or 1, o.rank > 0 and 0.85 or 1, true)
  end
  if o.disabled and o.reason and o.rank < o.ranks then tt:AddLine(o.reason, 1, 0.3, 0.3, true)
  elseif not o.disabled then tt:AddLine("Click: learn a rank.", 0.6, 0.6, 0.6) end
end

-- Infobulle d'une face du nœud Specialization : les trois voies et leurs textes, la voie survolée en or.
local function fillFace(tt, b)
  local node, o = b.node, b.option
  if not (node and o) then return end
  tt:AddLine(node.name or "Specialization", 1, 0.82, 0)
  tt:AddLine("Rank " .. node.rank .. "/" .. node.ranks .. " · one path at a time", 1, 1, 1)
  for _, ch in ipairs(node.choices) do
    local head = ch.name .. (ch.active and " (active)" or "")
    if ch.choice == o.choice then tt:AddLine(head, 1, 0.82, 0)
    elseif ch.active then tt:AddLine(head, 0.25, 1, 0.25)
    else tt:AddLine(head, 0.75, 0.75, 0.75) end
    local v = ch.choice == o.choice and 1 or 0.75
    tt:AddLine(ch.text or "", v, v, v, true)
  end
  if o.active then return end
  if o.disabled then
    if o.reason then tt:AddLine(o.reason, 1, 0.3, 0.3, true) end
  elseif node.rank > 0 then
    tt:AddLine("Click: switch to " .. o.name .. " (free).", 0.6, 0.6, 0.6)
  else
    tt:AddLine("Click: choose " .. o.name .. ".", 0.6, 0.6, 0.6)
  end
end

---------------------------------------------------------------------------
-- Construction (une fois, avec l'écran : rien n'est créé pendant un survol ni un affichage)
---------------------------------------------------------------------------

local function resetClick(b)
  local o = b.option
  if not o then return end
  if o.disabled then UI.flash(o.reason or "Unavailable.") return end
  if b.armed then
    b.armed = false
    b:SetText(o.label)
    W.sound("click")
    UI.choose(o.id)
  else
    b.armed = true
    b:SetText("Confirm reset?")
    W.delay(3, function()
      if b.armed then
        b.armed = false
        b:SetText(b.option and b.option.label or "Reset talents")
      end
    end)
  end
end

function TV.build(scr, f, panel)
  local lv = panel:GetFrameLevel()
  local t = { nodes = {}, names = {}, faces = {}, bands = {}, rowNames = {}, rowLocks = {} }
  scr.tv = t
  -- bandeaux des rangées : cadre sous les nœuds, au-dessus du fond du panneau
  t.bandFrame = CreateFrame("Frame", nil, panel)
  t.bandFrame:SetAllPoints(panel)
  t.bandFrame:SetFrameLevel(lv + 1)
  for r = 1, TV_ROWS do
    local band = W.rect(t.bandFrame, "BACKGROUND", 0, C.black, 0.28)
    band:Hide()
    t.bands[r] = band
    local name = W.label(t.bandFrame, "bold", 15, C.wowGold, "OVERLAY")
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:Hide()
    t.rowNames[r] = name
    local lock = W.label(t.bandFrame, "body", 11.5, C.badText, "OVERLAY")
    lock:SetJustifyH("LEFT")
    lock:SetJustifyV("TOP")
    lock:Hide()
    t.rowLocks[r] = lock
  end
  t.summary = W.label(t.bandFrame, "bold", 15, C.wowGold, "OVERLAY")
  t.summary:SetWordWrap(false)
  t.summary:Hide()
  t.note = W.label(t.bandFrame, "body", 12.5, C.textSoft, "OVERLAY")
  t.note:SetWordWrap(false)
  t.note:Hide()
  t.reset = W.button(f, "Reset talents", TV_RESET_W, TV_RESET_H, nil, "red", 14)
  at(t.reset, f, TV_RESET_X, TV_RESET_Y, TV_RESET_W, TV_RESET_H)
  t.reset:SetFrameLevel(lv + 4)
  t.reset:SetScript("OnClick", resetClick)
  W.tooltip(t.reset, function(tt, b)
    local o = b.option
    if not o then return end
    tt:AddLine(o.label or "", 1, 0.82, 0)
    tt:AddLine("Refunds every point of the tree, for free.", 1, 1, 1, true)
    if o.disabled and o.reason then tt:AddLine(o.reason, 1, 0.3, 0.3, true)
    elseif b.armed then tt:AddLine("Click again to confirm.", 0.6, 0.6, 0.6) end
  end, "ANCHOR_BOTTOM")
  t.reset:Hide()
  for i = 1, TV_NODES do
    local b = nodeButton(f, TV_ICON, true)
    b:SetFrameLevel(lv + 5)
    W.tooltip(b, fillNode, "ANCHOR_RIGHT")
    t.nodes[i] = b
    local name = W.label(t.bandFrame, "bold", 12, C.text, "OVERLAY")
    name:SetWordWrap(false)
    name:Hide()
    t.names[i] = name
  end
  -- nœud Specialization : une face par voie ; la pastille du rang et le nom sont ceux d'un nœud ordinaire
  for i = 1, TV_FACES do
    local b = nodeButton(f, TV_FACE, false)
    b:SetFrameLevel(lv + 5)
    W.tooltip(b, fillFace, "ANCHOR_RIGHT")
    t.faces[i] = b
  end
end

---------------------------------------------------------------------------
-- Affichage
---------------------------------------------------------------------------

local function hideAll(t)
  for _, b in ipairs(t.bands) do b:Hide() end
  for _, l in ipairs(t.rowNames) do l:Hide() end
  for _, l in ipairs(t.rowLocks) do l:Hide() end
  for _, b in ipairs(t.nodes) do b.option = nil b:Hide() end
  for _, l in ipairs(t.names) do l:Hide() end
  for _, b in ipairs(t.faces) do b.option, b.node = nil, nil b:Hide() end
  t.summary:Hide()
  t.note:Hide()
  t.reset.option = nil
  t.reset:Hide()
end

function TV.hide(scr)
  if scr.tv then hideAll(scr.tv) end
end

-- Texte d'une ligne centrée sur cx (scène), réduit jusqu'à minSize s'il dépasse w.
local function placeLine(fs, frame, text, cx, cy, size, w, minSize)
  local s = size
  while s > minSize and UI.textWidth(fs, text, s) * W.TEXT_SAFE > w do s = s - 0.5 end
  UI.setLines(fs, { text }, s, w)
  fs:SetJustifyH("CENTER")
  fs:ClearAllPoints()
  fs:SetPoint("CENTER", frame, "TOPLEFT", cx, -cy)
  fs:Show()
end

-- Rang d'un nœud : texte et couleur ; look de l'icône : appris (plein, anneau d'or au maximum), apprenable
-- (plein), sinon grisé.
local function paintRank(b, o, open)
  local p = b.rank
  p.text:SetText(o.rank .. "/" .. o.ranks)
  local rc = RANK_GREY
  if o.rank >= o.ranks then rc = RANK_GOLD
  elseif o.canLearn then rc = RANK_GREEN
  elseif o.rank > 0 then rc = RANK_GREEN end
  p.text:SetTextColor(rc[1], rc[2], rc[3])
  if o.rank >= o.ranks then setLook(b, 1, false, Art.rim.gold)
  elseif o.rank > 0 or o.canLearn then setLook(b, 1, false, Art.rim.silver)
  else setLook(b, open and 0.5 or 0.38, true, Art.rim.dim) end
end

function TV.show(scr, step)
  local t = scr.tv
  local data = step.talents
  hideAll(t)
  if not data then return end
  local frame = scr.frame
  scr.optionButtons = scr.optionButtons or {}
  placeLine(t.summary, frame, data.summary or "", 517, TV_SUM_Y, 15, 560, 11)
  if data.note then
    placeLine(t.note, frame, data.note, 517, TV_NOTE_Y, 12.5, 600, 10)
    local nc = data.running and C.badText or C.textSoft
    t.note:SetTextColor(nc[1], nc[2], nc[3])
  end
  local r = data.reset
  if r and not data.empty then
    t.reset.option = r
    if not t.reset.armed then t.reset:SetText(r.label) end
    t.reset:SetActive(not r.disabled)
    t.reset:Show()
    scr.optionButtons[r.id] = t.reset
  end
  local ni, fi = 0, 0
  for ri, row in ipairs(data.rows or {}) do
    if ri > TV_ROWS then break end
    local top = TV_ROW_TOP + (ri - 1) * TV_ROW_DY
    local band = t.bands[ri]
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", frame, "TOPLEFT", TV_BAND_X, -top)
    band:SetSize(TV_BAND_W, TV_ROW_H)
    band:SetColorTexture(0, 0, 0, row.open and 0.28 or 0.5)
    band:Show()
    -- nom de la rangée ; fermée : sa condition dessous
    local rn = t.rowNames[ri]
    rn:SetText("Tier " .. ri)
    W.looseBox(rn, 1, TV_LABEL_W)
    rn:ClearAllPoints()
    rn:SetPoint("LEFT", frame, "TOPLEFT", TV_LABEL_X, -(top + (row.open and TV_ROW_H / 2 or 32)))
    local c = row.open and C.wowGold or C.textDim
    rn:SetTextColor(c[1], c[2], c[3])
    rn:Show()
    if row.lock then
      local lk = t.rowLocks[ri]
      local lines = UI.balancedLines(lk, row.lock, 11.5, 2)
      UI.setLines(lk, lines, 11.5, TV_LABEL_W)
      lk:ClearAllPoints()
      lk:SetPoint("TOPLEFT", frame, "TOPLEFT", TV_LABEL_X, -(top + 46))
      lk:Show()
    end
    -- nœuds de la rangée, centrés
    local n = #row.nodes
    local pitch = min(TV_PITCH, TV_NODES_W / max(n, 1))
    for k, o in ipairs(row.nodes) do
      local cx = TV_NODES_CX + (k - (n + 1) / 2) * pitch
      local cy = top + TV_ICON_DY
      ni = ni + 1
      local b = t.nodes[ni]
      if not b then break end
      local name = t.names[ni]
      local label = o.name or o.node
      if o.choices then
        -- trois faces (une par voie) ; la pastille du rang reste sous la face du milieu (bouton du nœud sans
        -- icône ni anneau : seulement sa pastille)
        local nc = #o.choices
        local activeName
        for j, ch in ipairs(o.choices) do
          fi = fi + 1
          local fb = t.faces[fi]
          if fb then
            fb.node, fb.option = o, ch
            local fx = cx + (j - (nc + 1) / 2) * TV_FACE_DX
            at(fb, frame, fx - TV_FACE / 2, cy - TV_FACE / 2, TV_FACE, TV_FACE)
            W.setIcon(fb.icon, Art.talentIcon(data.class, ch.choice, ch.icon, o.icon), "talent:" .. ch.choice)
            if o.rank > 0 then
              if ch.active then setLook(fb, 1, false, Art.rim.gold) activeName = ch.name
              else setLook(fb, 0.55, true, Art.rim.dim) end
            elseif o.canLearn then setLook(fb, 1, false, Art.rim.silver)
            else setLook(fb, row.open and 0.5 or 0.38, true, Art.rim.dim) end
            fb:Show()
            scr.optionButtons[ch.id] = fb
          end
        end
        if activeName then label = label .. ": " .. activeName end
        -- pastille du rang du nœud à choix : le bouton du nœud, sans icône, sert de support (clic : rien)
        b.option = nil
        at(b, frame, cx - TV_ICON / 2, cy - TV_ICON / 2, TV_ICON, TV_ICON)
        b.icon:Hide()
        b.ring:Hide()
        b:EnableMouse(false)
        paintRank(b, o, row.open)
        b:Show()
      else
        b.option = o
        b.icon:Show()
        b.ring:Show()
        b:EnableMouse(true)
        at(b, frame, cx - TV_ICON / 2, cy - TV_ICON / 2, TV_ICON, TV_ICON)
        W.setIcon(b.icon, Art.talentIcon(data.class, o.node, o.icon), "talent:" .. o.node)
        paintRank(b, o, row.open)
        b:Show()
        scr.optionButtons[o.id] = b
      end
      local w = pitch - 12
      placeLine(name, frame, label, cx, top + TV_NAME_DY, 12, w, 9)
      local tc = (o.rank > 0 or o.canLearn) and C.text or C.textDim
      name:SetTextColor(tc[1], tc[2], tc[3])
    end
  end
end

---------------------------------------------------------------------------
-- Pendant l'expédition : talents actifs dans le panneau du deck (lecture seule)
---------------------------------------------------------------------------
-- Une ligne en bas à gauche du panneau (à gauche de « Close ») : « Talents: Toughness 3 · Battle Ready 2 · Fury
-- … » (rang écrit s'il y en a plusieurs), réduite pour tenir ; infobulle = chaque talent et son texte ; hors
-- combat, un clic ouvre l'onglet Talents de l'écran Progress (lecture seule). Cachée sans talent.

local DT_X, DT_BOTTOM, DT_W = 18, 22, 740

function TV.deckLine(panel)
  local b = CreateFrame("Button", nil, panel)
  b:SetSize(DT_W, 22)
  b:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", DT_X, DT_BOTTOM)
  b:SetFrameLevel(panel:GetFrameLevel() + 3)
  b:RegisterForClicks("LeftButtonUp")
  b.text = W.label(b, "bold", 12.5, C.textSoft, "OVERLAY")
  b.text:SetPoint("LEFT", 0, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  W.hoverable(b, { paint = function(self, h)
    local c = C.textSoft
    local k = h
    self.text:SetTextColor(c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k)
  end })
  W.tooltip(b, function(tt, self)
    local list = self.list
    if not list then return end
    tt:AddLine("Talents of this expedition", 1, 0.82, 0)
    for _, e in ipairs(list) do
      local head = e.name .. (e.specName and (": " .. e.specName) or "") .. (e.ranks > 1 and (" " .. e.rank .. "/" .. e.ranks) or "")
      tt:AddLine(head, 1, 1, 1)
      if e.text then tt:AddLine(e.text, 0.8, 0.8, 0.8, true) end
    end
    tt:AddLine("Set at the start of the expedition.", 0.6, 0.6, 0.6, true)
    if not ns.Controller.inCombat() then tt:AddLine("Click: view the talent tree.", 0.6, 0.6, 0.6) end
  end, "ANCHOR_TOP")
  b:SetScript("OnClick", function()
    if ns.Controller.inCombat() then UI.flash("Not during a combat.") return end
    if UI.deckView then UI.deckView:Close() end
    UI.choose("ui:talents")
  end)
  b:Hide()
  return b
end

-- Remplit la ligne : list = Controller.activeTalents() (nil : cachée).
function TV.fillDeckLine(b, list)
  b.list = list
  if not list then b:Hide() return end
  local parts = {}
  for _, e in ipairs(list) do
    local s = e.specName or e.name
    if e.ranks > 1 then s = s .. " " .. e.rank end
    parts[#parts + 1] = s
  end
  local text = "Talents: " .. table.concat(parts, " · ")
  local s = 12.5
  while s > 9 and UI.textWidth(b.text, text, s) * W.TEXT_SAFE > DT_W do s = s - 0.5 end
  -- au plancher, la liste se coupe (« +N ») : l'infobulle les donne tous
  local shown = #parts
  while shown > 1 and UI.textWidth(b.text, text, s) * W.TEXT_SAFE > DT_W do
    shown = shown - 1
    text = "Talents: " .. table.concat(parts, " · ", 1, shown) .. " · +" .. (#parts - shown)
  end
  UI.setLines(b.text, { text }, s, DT_W)
  b.text:SetJustifyH("LEFT")
  b.text:ClearAllPoints()
  b.text:SetPoint("LEFT", b, "LEFT", 0, 0)
  b:Show()
end
