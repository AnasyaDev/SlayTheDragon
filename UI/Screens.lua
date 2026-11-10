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

-- Textes du moteur (couleurs WoW vives) : lisibles tels quels sur l'ardoise.
local function inkText(t)
  return t or ""
end

-- Héros posé à gauche (récompense, rencontre, feu de camp, accueil).
local function heroFigure(f)
  local fig = Scene.figure(f, 170, 200)
  at(fig, f, 85, 146, 170, 200)
  fig:EnableMouse(false)
  return fig
end

-- Tas du deck sur le plateau : deux dos de carte, nombre dans un hexagone d'acier (planches) ;
-- infobulle = contenu ; clic = consulter le deck. Bas à y 574 : rien ne déborde de la fenêtre.
local PILE_X, PILE_Y, PILE_H = 67, 519, 104
local function deckPile(f)
  local w = W.skinWidth("card_back", PILE_H)
  local under = CreateFrame("Frame", nil, f)
  at(under, f, PILE_X - w / 2 + 5, PILE_Y - PILE_H / 2 - 4, w, PILE_H)
  local ub = W.cardBack(under, PILE_H, "BACKGROUND", 0)
  ub:SetPoint("CENTER")
  ub:SetVertexColor(0.7, 0.7, 0.7, 1)
  local p = CreateFrame("Button", nil, f)
  at(p, f, PILE_X - w / 2, PILE_Y - PILE_H / 2, w, PILE_H)
  p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(p)
  p.shadow = W.cardBack(face, PILE_H, "BACKGROUND", -1)
  p.shadow:SetPoint("CENTER", 2, -3)
  p.shadow:SetVertexColor(0, 0, 0, 0.5)
  p.back = W.cardBack(face, PILE_H, "BACKGROUND", 0)
  p.back:SetPoint("CENTER")
  p.hex = W.hex(face, "steel", 34, "ARTWORK", 0)
  p.hex:SetPoint("CENTER", 30, -46)
  p.count = W.label(face, "heavy", 15, C.text)
  p.count:SetPoint("CENTER", p.hex, "CENTER", 0, 1)
  W.hoverable(p, { scale = 1.06, lift = 6 })
  p:SetScript("OnClick", function(_, button)
    if button == "RightButton" then return end
    W.sound("click")
    UI.toggleDeckView("deck")
  end)
  W.tooltip(p, function(tt)
    UI.fillDeckTooltip(tt)
    tt:AddLine("Clic : voir les cartes.", 0.6, 0.6, 0.6)
  end, "ANCHOR_RIGHT")
  p.Sync = function(self)
    local r = Controller.runInfo()
    self.count:SetText(r and #r.deck or "")
  end
  return p
end

-- Plaque de réponse (rencontre, bibelot, feu de camp, service) : libellé + ce que ça donne (vert si
-- c'est un gain). Survol : liseré doré, ardoise plus claire, halo, levée.
-- Mise en page (comme le texte des cartes) : zone utile = intérieur de la plaque moins OPT_MX sur les
-- côtés et OPT_MY en haut et en bas ; libellé sur une ligne (paliers OPT_LABEL), texte en dessous sur
-- une ligne si possible (paliers OPT_SUB), sinon coupé en lignes équilibrées au mot le plus près du
-- milieu ; le bloc (icône, libellé, texte) est centré verticalement. Mesures par le client.
local OPT_MX, OPT_MY, OPT_GAP = 16, 10, 6
local OPT_LABEL = { 20, 18, 16 }
local OPT_SUB = { 15.5, 14.5, 13.5, 12.5 }
UI.OPT = { mx = OPT_MX, my = OPT_MY, label = OPT_LABEL, sub = OPT_SUB }

-- Largeur d'un texte d'une ligne à la taille s (police du texte fs).
local function textWidth(fs, t, s)
  W.setSize(fs, s)
  fs:SetWordWrap(false)
  fs:SetWidth(0)
  fs:SetText(t)
  return (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0
end

-- Coupe t en n lignes équilibrées (la plus longue la plus courte possible) ; renvoie lignes, largeur.
local function balanced(fs, t, s, n)
  local words = {}
  for w in t:gmatch("%S+") do words[#words + 1] = w end
  if n <= 1 or #words < n then return { t }, textWidth(fs, t, s) end
  local best, bestW
  if n == 2 then
    for k = 1, #words - 1 do
      local a, b = table.concat(words, " ", 1, k), table.concat(words, " ", k + 1)
      local m = max(textWidth(fs, a, s), textWidth(fs, b, s))
      if not bestW or m < bestW then best, bestW = { a, b }, m end
    end
  else
    for i = 1, #words - 2 do
      for k = i + 1, #words - 1 do
        local a, b, c = table.concat(words, " ", 1, i), table.concat(words, " ", i + 1, k), table.concat(words, " ", k + 1)
        local m = max(textWidth(fs, a, s), textWidth(fs, b, s), textWidth(fs, c, s))
        if not bestW or m < bestW then best, bestW = { a, b, c }, m end
      end
    end
  end
  return best, bestW
end

-- Pose un texte de plaque : lignes explicites, largeur un peu plus grande que la plus longue ligne
-- (le client ne recoupe jamais autrement) ; renvoie sa hauteur mesurée.
local function setLines(fs, lines, s, zw)
  W.setSize(fs, s)
  fs:SetWordWrap(#lines > 1)
  fs:SetWidth(zw + 1)
  fs:SetText(table.concat(lines, "\n"))
  return fs:GetStringHeight() or 0
end

local function plaque(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(300, 118)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  b.plaque = W.plaque(face, { r = 14 })
  b.icon = face:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(40, 40)
  W.roundMask(face, b.icon, "mask_roundsq")
  b.icon:Hide()
  b.label = W.label(face, "bold", 20, C.text)
  b.label:SetJustifyH("CENTER")
  b.label:SetWordWrap(false)
  b.sub = W.label(face, "bold", 15.5, C.textSoft)
  b.sub:SetJustifyH("CENTER")
  b.sub:SetWordWrap(true)
  -- Libellé et texte dans la zone utile (voir OPT_*) ; renvoie la mise en page retenue.
  b.Layout = function(self, label, sub, w, h, withIcon)
    local zw = w - 2 * OPT_MX
    local zh = h - 2 * OPT_MY
    local iconH = withIcon and (40 + OPT_GAP) or 0
    local fit = { ok = false }
    -- libellé : une ligne au premier palier qui tient ; sinon deux lignes au plancher
    local ls, llines = nil, { label }
    for _, s in ipairs(OPT_LABEL) do
      if textWidth(self.label, label, s) <= zw then ls = s break end
    end
    if not ls then
      ls = OPT_LABEL[#OPT_LABEL]
      llines = balanced(self.label, label, ls, 2)
    end
    local lh = setLines(self.label, llines, ls, zw)
    -- texte : une ligne si possible (deux premiers paliers), sinon lignes équilibrées
    local cands = {}
    if sub ~= "" then
      for i = 1, 2 do cands[#cands + 1] = { OPT_SUB[i], 1 } end
      for _, s in ipairs(OPT_SUB) do cands[#cands + 1] = { s, 2 } end
      cands[#cands + 1] = { OPT_SUB[#OPT_SUB], 3 }
    end
    local sh, slines, ss = 0, {}, OPT_SUB[1]
    for _, c in ipairs(cands) do
      local lines, lw = balanced(self.sub, sub, c[1], c[2])
      if #lines == c[2] and lw <= zw then
        local hh = setLines(self.sub, lines, c[1], zw)
        if iconH + lh + OPT_GAP + hh <= zh then sh, slines, ss, fit.ok = hh, lines, c[1], true break end
      end
    end
    if sub == "" then fit.ok = iconH + lh <= zh
    elseif not fit.ok then
      -- rien ne tient : plus petit palier sur trois lignes (signalé)
      slines = balanced(self.sub, sub, OPT_SUB[#OPT_SUB], 3)
      ss = OPT_SUB[#OPT_SUB]
      sh = setLines(self.sub, slines, ss, zw)
    end
    self.sub:SetShown(sub ~= "")
    local block = iconH + lh + (sub ~= "" and (OPT_GAP + sh) or 0)
    local top = (h - block) / 2
    self.label:ClearAllPoints()
    self.icon:ClearAllPoints()
    if withIcon then
      self.icon:SetPoint("TOP", self.face, "TOP", 0, -top)
      self.label:SetPoint("TOP", self.face, "TOP", 0, -(top + iconH))
    else
      self.label:SetPoint("TOP", self.face, "TOP", 0, -top)
    end
    self.sub:ClearAllPoints()
    self.sub:SetPoint("TOP", self.label, "BOTTOM", 0, -OPT_GAP)
    fit.label, fit.sub, fit.subLines, fit.block, fit.zw, fit.zh = ls, ss, #slines, block, zw, zh
    self.optFit = fit
    return fit
  end
  b.SetOption = function(self, o, w, h)
    self.option = o
    self:SetSize(w, h)
    local sub = o.text or ""
    local col = C.textSoft
    if o.disabled and o.reason then sub, col = o.reason, C.badText
    elseif sub:match("^%+") then col = C.healGreen end
    self.sub:SetTextColor(col[1], col[2], col[3])
    if o.item then
      W.setIcon(self.icon, W.itemEntry(o.item.kind, o.item.id), o.item.kind .. ":" .. tostring(o.item.id))
      self.icon:Show()
    else
      self.icon:Hide()
    end
    self:Layout(o.label or o.id, sub, w, h, o.item ~= nil)
    self:SetAlpha(o.disabled and 0.6 or 1)
    -- une réponse impossible bouge à peine au survol
    self.hoverScale, self.hoverLift = o.disabled and 1.01 or 1.04, o.disabled and 0 or 5
    self:Show()
  end
  b:SetScript("OnClick", function(self) chooseOption(self.option) end)
  W.tooltip(b, function(tt, self)
    local o = self.option
    if o and o.item then W.fillItemTooltip(tt, o.item.kind, o.item.id, { reason = o.disabled and o.reason or nil }) end
  end, "ANCHOR_TOP")
  -- survol : la plaque se lève, son liseré passe à l'or, l'ardoise s'éclaircit, le halo s'allume
  W.hoverable(b, { scale = 1.04, lift = 5, paint = function(self, h)
    local live = self.option and not self.option.disabled
    if not live then h = 0 end
    self.plaque:SetFill(1 + 0.25 * h)
    self.plaque:SetRim(W.lerpColor(Art.rim.silver, Art.rim.gold, h))
    self.plaque:SetGlow(0.75 * h)
  end })
  return b
end

-- Objet posé au sol, cliquable (couchage, grimoire, bourse, fiole, bibelot, coffre) : ombre, cadre,
-- icône, étiquette dessous.
-- Pastille d'étiquette (pilule d'ardoise) : t:Set(texte, couleur, prix, trop cher) ; un prix montre la
-- pièce à gauche du nombre, « trop cher » rougit le liseré ; texte vide = cachée.
local function tagPill(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetSize(58, 22)
  t.plaque = W.plaque(t, { r = 11, pill = true, gloss = false })
  t.coin = t:CreateTexture(nil, "ARTWORK")
  t.coin:SetSize(15, 15)
  t.coin:SetPoint("LEFT", 6, 0)
  W.roundMask(t, t.coin)
  W.setIcon(t.coin, Art.ui.gold, "ui:gold")
  t.text = W.label(t, "heavy", 13.5, C.goldText)
  t.text:SetPoint("CENTER", 0, 1)
  t:Hide()
  t.Set = function(self, text, color, isPrice, bad)
    if not text or text == "" then self:Hide() return end
    self.text:SetText(text)
    local c = color or C.goldText
    self.text:SetTextColor(c[1], c[2], c[3])
    self.text:ClearAllPoints()
    if isPrice then
      self.coin:Show()
      self.text:SetPoint("CENTER", 7, 1)
      self:SetWidth(max(58, (self.text:GetStringWidth() or 30) + 36))
    else
      self.coin:Hide()
      self.text:SetPoint("CENTER", 0, 1)
      self:SetWidth((self.text:GetStringWidth() or 40) + 24)
    end
    self.plaque:SetRim(bad and Art.rim.red or Art.rim.silver)
    self:Show()
  end
  return t
end

-- Objet cliquable (butin, articles du marchand, couchage et grimoire du feu, coffre) : case d'ardoise
-- et icône aux coins arrondis (shape "square"), ou médaillon argenté (shape "round") ; nombre en bas à
-- droite (b.big) ; étiquette dessous (prix : pièce + nombre, rouge si trop cher ; ou texte).
local function groundObject(parent, size, shape)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  b.icon = face:CreateTexture(nil, "ARTWORK", nil, 1)
  if shape == "round" then
    b.glow = W.skin(face, "glow_round", "BACKGROUND", -8)
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(size * 1.55, size * 1.55)
    b.glow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
    b.glow:SetAlpha(0)
    b.ring = W.skin(face, "medal_ring", "ARTWORK", 0)
    b.ring:SetAllPoints()
    b.icon:SetPoint("TOPLEFT", size * 0.11, -size * 0.11)
    b.icon:SetPoint("BOTTOMRIGHT", -size * 0.11, size * 0.11)
    W.roundMask(face, b.icon)
  else
    b.plaque = W.plaque(face, { r = max(8, floor(size / 4.4)), fill = 0.7, gloss = false })
    local pad = max(4, floor(size * 0.09))
    b.icon:SetPoint("TOPLEFT", pad, -pad)
    b.icon:SetPoint("BOTTOMRIGHT", -pad, pad)
    W.roundMask(face, b.icon, "mask_roundsq")
  end
  b.big = W.label(face, "heavy", 15, C.goldText, "OVERLAY")
  b.big:SetPoint("CENTER", face, "BOTTOMRIGHT", -6, 6)
  b.tag = tagPill(b)
  b.tag:SetPoint("TOP", b, "BOTTOM", 0, -6)
  b.SetTag = function(self, ...) self.tag:Set(...) end
  b.SetRim = function(self, c) if self.plaque then self.plaque:SetRim(c) end end
  W.hoverable(b, { scale = 1.08, lift = 6, paint = function(self, h)
    if self.active == false then h = 0 end
    if self.glow then self.glow:SetAlpha(0.8 * h) end
    if self.plaque then
      self.plaque:SetGlow(0.7 * h)
      self.plaque:SetFill(0.7 * (1 + 0.3 * h))
    end
  end })
  W.tooltip(b, function(tt, self)
    local info = self.info
    if not info then return end
    W.fillItemTooltip(tt, info.kind, info.id, info)
  end, "ANCHOR_TOP")
  return b
end

-- Bulle de dialogue : ivoire du pack au liseré d'argent, texte sombre, pointe facultative vers le
-- personnage ; edge = teinte du liseré (or : rencontre rare, violet : histoire).
local function bubble(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(400, 96)
  f.plaque = W.plaque(f, { mat = "ivory", r = 14 })
  f.tail = W.skin(f, "tail_ivory", "BACKGROUND", -8)
  f.tail:SetSize(26, 18)
  f.tailRim = W.skin(f, "tail_rim", "BACKGROUND", -7)
  f.tailRim:SetAllPoints(f.tail)
  f.title = W.label(f, "bold", 16, C.inkDark, "OVERLAY", false)
  f.title:SetPoint("TOPLEFT", 18, -12)
  f.text = W.label(f, "bold", 14.5, C.inkDark, "OVERLAY", false)
  f.text:SetWidth(364)
  f.text:SetJustifyH("LEFT")
  f.text:SetWordWrap(true)
  f.text:SetSpacing(4)
  f.Set = function(self, title, text, edge, tail)
    self.title:SetText(title or "")
    self.text:SetWidth(self:GetWidth() - 36)
    self.text:ClearAllPoints()
    if title and title ~= "" then
      self.text:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -8)
    else
      self.text:SetPoint("TOPLEFT", 18, -16)
    end
    self.text:SetText(text or "")
    local h = (self.text.GetStringHeight and self.text:GetStringHeight()) or 60
    if type(h) ~= "number" or h <= 0 then h = 60 end
    self:SetHeight(h + ((title and title ~= "") and 58 or 34))
    local rim = edge or Art.rim.silver
    self.plaque:SetRim(rim)
    self.tailRim:SetVertexColor(rim[1], rim[2], rim[3], 1)
    self.tail:ClearAllPoints()
    if tail == "right" then
      self.tail:SetPoint("TOP", self, "BOTTOMRIGHT", -60, 2)
      self.tail:Show()
      self.tailRim:Show()
    elseif tail == "left" then
      self.tail:SetPoint("TOP", self, "BOTTOMLEFT", 60, 2)
      self.tail:Show()
      self.tailRim:Show()
    else
      self.tail:Hide()
      self.tailRim:Hide()
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
  local panel = W.woodPanel(f, 14)
  at(panel, f, 280, 70, 560, 290)
  self.panel = panel
  self.title = W.label(panel, "heavy", 32, C.text)
  self.title:SetPoint("TOP", 0, -18)
  self.title:SetText("Slay the Dragon")
  self.classButtons = {}
  for i = 1, 4 do
    local b = W.button(panel, "", 220, 52, nil, "slate", 17)
    b.sub = W.label(b.face, "body", 11, C.textSoft)
    b.sub:SetPoint("TOP", b.label, "BOTTOM", 0, -2)
    b.label:ClearAllPoints()
    b.label:SetPoint("CENTER", 0, 7)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.classButtons[i] = b
  end
  self.keyLabel = W.label(panel, "bold", 15, C.textSoft)
  self.keyLabel:SetPoint("TOP", 0, -150)
  self.keyLabel:SetText("Clé mythique")
  self.keyButtons = {}
  -- clés +0…+5 : hexagones violets (verrouillées : hexagones vides)
  for i = 1, 6 do
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(46, 46)
    local face = W.face(b)
    b.hex = W.hex(face, "violet", 46, "BACKGROUND", 0)
    b.hex:SetPoint("CENTER")
    b.label = W.label(face, "heavy", 16, C.text)
    b.label:SetPoint("CENTER", 0, 1)
    W.hoverable(b, { scale = 1.14 })
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
  self.note = W.label(f, "bold", 14, C.textSoft, "OVERLAY")
  at(self.note, f, 250, 446, 540, 0)
  self.note:SetWidth(540)
  self.note:SetJustifyH("CENTER")
  self.note:SetWordWrap(true)
  self.go = W.button(f, "Partir en expédition", 230, 50, nil, "gold", 18)
  at(self.go, f, 790, 494, 230, 50)
  self.go:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  self.meta = W.button(f, "Réputation et journal", 210, 44, nil, "slate", 15)
  at(self.meta, f, 24, 497, 210, 44)
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
      b.plaque:SetRim(o.selected and Art.rim.gold or Art.rim.silver)
      b.plaque:SetGlow(o.selected and 0.5 or 0)
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
      local s = o.selected and 54 or 44
      W.setHex(b.hex, o.disabled and "empty" or "violet", s)
      local lc = o.disabled and C.textDim or C.text
      b.label:SetTextColor(lc[1], lc[2], lc[3])
      W.setSize(b.label, o.selected and 19 or 16)
      b:SetSize(s, s)
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

local RARITY_EDGE = { rare = Art.rim.gold, story = Art.rim.violet }

function Choice:Build(f)
  self.hero = heroFigure(f)
  self.npc = Scene.figure(f, 170, 200)
  at(self.npc, f, 765, 146, 170, 200)
  self.npc:EnableMouse(false)
  self.speaker = W.label(f, "bold", 14, C.text, "OVERLAY")
  at(self.speaker, f, 770, 293, 160, 0)
  self.speaker:SetWidth(160)
  self.speaker:SetJustifyH("CENTER")
  self.bubble = bubble(f)
  at(self.bubble, f, 397, 68)
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
  local edge = RARITY_EDGE[step.rarity or ""]
  self.bubble:SetWidth(npcShown and 400 or 470)
  self.bubble:Set(step.title, step.text, edge, npcShown and "right" or nil)
  at(self.bubble, self.frame, npcShown and 397 or 282, 68)
  self.optionButtons = {}
  local opts = step.options or {}
  local n = min(#opts, #self.buttons)
  local span = n <= 2 and 668 or (n == 3 and 900 or 980)
  local gap = n <= 2 and 28 or 22
  local w = (span - (n - 1) * gap) / max(n, 1)
  local h = n >= 4 and 112 or 118
  local x0 = (Scene.W - span) / 2
  for i, b in ipairs(self.buttons) do
    local o = opts[i]
    if o and i <= n then
      at(b, self.frame, x0 + (i - 1) * (w + gap), 462)
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

  -- couchage et grimoire : médaillons au sol ; leurs plaques sur le plateau (planche ecran_feu.jpg)
  self.rest = groundObject(f, 74, "round")
  at(self.rest, f, 387 - 37, 347 - 37, 74, 74)
  W.setIcon(self.rest.icon, Art.ui.bedroll, "ui:bedroll")
  self.rest:SetScript("OnClick", function(b) chooseOption(b.option) end)
  self.book = groundObject(f, 74, "round")
  at(self.book, f, 657 - 37, 347 - 37, 74, 74)
  W.setIcon(self.book.icon, Art.ui.grimoire, "ui:grimoire")
  self.book:SetScript("OnClick", function(b) chooseOption(b.option) end)
  self.restPlaque = plaque(f)
  self.bookPlaque = plaque(f)
  -- la plaque et le médaillon s'allument ensemble
  for _, pair in ipairs({ { self.rest, self.restPlaque }, { self.book, self.bookPlaque } }) do
    local obj, pl = pair[1], pair[2]
    obj.onEnterExtra = function() W.hoverEnter(pl) end
    obj.onLeaveExtra = function() W.hoverLeave(pl) end
    pl.onEnterExtra = function() W.hoverEnter(obj) end
    pl.onLeaveExtra = function() W.hoverLeave(obj) end
  end
  self.pile = deckPile(f)
  self.leave = W.button(f, "Reprendre la route", 210, 44, nil, "slate", 15)
  at(self.leave, f, 800, 497, 210, 44)
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
      self.rest.info = { title = o.label, text = o.text, reason = o.disabled and o.reason or nil }
      self.rest.active = not o.disabled
      self.rest:SetAlpha(o.disabled and 0.5 or 1)
      at(self.restPlaque, self.frame, 385 - 120, 469)
      self.restPlaque:SetOption({ id = o.id, label = o.label, text = heal and ("+" .. heal .. " PV") or o.text,
        disabled = o.disabled, reason = o.reason }, 240, 104)
      self.restPlaque.option = o
      self.optionButtons[o.id] = self.rest
    elseif o.id == "ui:upgrade" then
      self.book.option = o
      self.book.info = { title = o.label, reason = o.disabled and o.reason or nil }
      self.book.active = not o.disabled
      self.book.icon:SetDesaturated(o.disabled and true or false)
      self.book:SetAlpha(o.disabled and 0.5 or 1)
      at(self.bookPlaque, self.frame, 662 - 120, 469)
      self.bookPlaque:SetOption({ id = o.id, label = "S'entraîner", text = "Améliore une carte",
        disabled = o.disabled, reason = o.reason }, 240, 104)
      self.bookPlaque.option = o
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

-- Planche ecran_recompense.jpg : trois cartes ×1,08 (centres x 407 / 552 / 697, haut du corps y 147),
-- butin à droite, consigne au centre du plateau.
local REWARD_SCALE = 1.08
local REWARD_TOP = 147
local REWARD_CARDS = { 407, 552, 697 }

function Reward:Build(f)
  self.hero = heroFigure(f)
  self.bubble = bubble(f)
  self.bubble:SetWidth(470)
  at(self.bubble, f, 282, 54)
  self.cards = {}
  for i = 1, 4 do
    local c = W.card(f)
    c:SetScript("OnClick", function(card) Reward:Pick(card) end)
    c.hoverScale, c.hoverLift = 1.17, 22 / REWARD_SCALE
    c:Hide()
    self.cards[i] = c
  end
  -- butin au sol : bourse (montant), bibelot, fiole
  self.goldBag = groundObject(f, 44, "square")
  at(self.goldBag, f, 878 - 22, 327 - 22, 44, 44)
  W.setIcon(self.goldBag.icon, Art.ui.bag, "ui:bag")
  self.goldBag:SetScript("OnClick", function() Reward:Collect("gold") end)
  self.flask = groundObject(f, 44, "square")
  at(self.flask, f, 934 - 22, 335 - 22, 44, 44)
  self.flask:SetScript("OnClick", function() Reward:Collect("potion") end)
  self.relic = groundObject(f, 44, "square")
  at(self.relic, f, 906 - 22, 273 - 22, 44, 44)
  self.relic:SetScript("OnClick", function() Reward:Collect("relic") end)
  -- coffre fermé
  self.chest = groundObject(f, 120, "square")
  at(self.chest, f, 457, 190, 120, 120)
  W.setIcon(self.chest.icon, Art.ui.chest, "ui:chest")
  self.chest:SetScript("OnClick", function() Reward:OpenChest() end)
  self.loot = CreateFrame("Frame", nil, f) -- compatibilité harnais : butin affiché
  self.loot:SetSize(1, 1)
  self.pile = deckPile(f)
  self.hint = W.label(f, "bold", 15, C.textSoft)
  self.hint:SetPoint("CENTER", f, "TOPLEFT", 552, -519)
  self.hint:SetText("Une carte au choix, ou aucune.")
  self.leave = W.button(f, "Reprendre la route", 206, 50, nil, "gold", 18)
  at(self.leave, f, 913 - 103, 519 - 25, 206, 50)
  self.leave:SetScript("OnClick", function() Reward:Leave() end)
  self.optionButtons = {}
end

-- Pose au repos (zone de clic fixe) ; le survol anime le visuel (W.card).
function Reward:PlaceCard(card)
  if not card.cx then return end
  local base = self.frame:GetFrameLevel() + 10 + card.slot
  W.placeCard(card, self.frame, card.cx, card.cy, REWARD_SCALE, base, base + 30)
  card:SetHot(card.hover and true or false)
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
    self.bubble:Set(step.title, step.after)
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
        card.cx = REWARD_CARDS[k] or (407 + (k - 1) * 145)
        card.cy = REWARD_TOP + W.CARD_H * REWARD_SCALE / 2
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
    W.hideCard(self.cards[i])
  end
  if closed then for i = 1, #self.cards do W.hideCard(self.cards[i]) end end
  -- butin
  local loot = {}
  local hold = UI.hold
  local r2 = r or {}
  self.goldBag.info = r2.goldGained and { title = "Bourse", text = "+" .. r2.goldGained .. " po" } or nil
  local anyCard = false
  for _, o in ipairs(step.options) do if o.card then anyCard = true end end
  if anyCard and not closed then self.hint:Show() else self.hint:Hide() end
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
    local rel = ns.Relics[r2.relic]
    self.relic:SetRim(Art.rarityRim[rel and rel.rarity or "common"] or Art.rim.silver)
    self.relic:Show()
    loot[#loot + 1] = "relic"
  else
    self.relic:Hide()
  end
  local pendingPotion = r2.potion and not r2.potionTaken
  if r2.potion and (hold.potion or pendingPotion) and not closed then
    self.flask.info = { kind = "potion", id = r2.potion,
      hint = pendingPotion and "Emplacements de potion pleins : en jeter une (clic droit dans le bandeau)." or nil }
    W.setIcon(self.flask.icon, Art.potion(r2.potion), "potion:" .. r2.potion)
    self.flask.icon:SetDesaturated(pendingPotion and true or false)
    self.flask:SetTag(pendingPotion and "Pas de place" or nil, C.badText, false, true)
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
    W.fly(g, self.frame, x, y, 67, 519, REWARD_SCALE, 0.4, 1, 0.3, 0.45, function() W.releaseGhost(g) end, 60)
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
      if not silent then UI.flash(o and o.reason or "Emplacements de potion pleins.") end
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

local PER_PAGE, PER_ROW, GRID_SCALE = 16, 8, 0.75
local GRID_TOP, GRID_GAPY = 100, 28 -- haut du corps de la 1re rangée ; écart (languette et plaque du bas)

function Deck:Build(f)
  local panel = W.woodPanel(f, 12)
  at(panel, f, 16, 54, 1002, 362)
  self.panel = panel
  self.title = W.label(panel, "bold", 18, C.text)
  self.title:SetPoint("TOP", 0, -12)
  self.cards = {}
  for i = 1, PER_PAGE do
    local c = W.card(f)
    c:SetFrameLevel(panel:GetFrameLevel() + 5)
    c:SetScript("OnClick", function(card) chooseOption(card.option) end)
    c.hoverScale, c.hoverLift = 1.2, 8 / GRID_SCALE
    -- survol : animation commune (W.card) + aperçu de l'amélioration
    local enter, leave = c.onEnterExtra, c.onLeaveExtra
    c.onEnterExtra = function(card) enter(card) Deck:Preview(card) end
    c.onLeaveExtra = function(card) leave(card) Deck:Preview(card) end
    c:Hide()
    self.cards[i] = c
  end
  self.prev = W.roundButton(f, "<", 34, 1, nil, function() self.page = self.page - 1 self:Layout() end)
  at(self.prev, f, 24, 214, 34, 34)
  self.next = W.roundButton(f, ">", 34, 1, nil, function() self.page = self.page + 1 self:Layout() end)
  at(self.next, f, 976, 214, 34, 34)
  self.pile = deckPile(f)
  self.buttons = {}
  for i = 1, 2 do
    local b = W.button(f, "", 206, i == 1 and 50 or 44, nil, i == 1 and "gold" or "slate", i == 1 and 18 or 15)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.buttons[i] = b
  end
  self.page = 1
  self.optionButtons = {}
end

function Deck:PlaceCard(card)
  if not card.cx then return end
  local base = self.panel:GetFrameLevel() + 5 + card.slot
  W.placeCard(card, self.frame, card.cx, card.cy, GRID_SCALE, base, base + 40)
  self:Preview(card)
end

-- Aperçu de l'amélioration au survol.
function Deck:Preview(card)
  local up = card.hover and true or false
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
      card.cy = GRID_TOP + row * (ch + GRID_GAPY) + ch / 2
      card.option, card.slot = o, i
      card:SetCard(o.card.id, o.card.up, { preview = o.preview, playable = not o.disabled,
        reason = o.disabled and o.reason or nil })
      self:PlaceCard(card)
      card:Show()
      self.optionButtons[o.id] = card
    else
      card.option, card.cx = nil, nil
      W.hideCard(card)
    end
  end
  for i = 1, #self.buttons do
    local b, o = self.buttons[i], self.otherOptions[#self.otherOptions - i + 1]
    if o then
      b.option = o
      b:SetText(o.label or o.id)
      at(b, self.frame, 810 - (i - 1) * 222, i == 1 and 494 or 497, 206, i == 1 and 50 or 44)
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

-- Planche ecran_marchand.jpg : rangée de cartes ×0,92 (prix en pastille dessous), puis « Bibelots »,
-- « Potions » et « Service » (plaque « Retirer une carte ») ; plateau : deck, or, « Reprendre la route ».
local SHOP_SCALE = 0.92
local SHOP_TOP, SHOP_X0, SHOP_DX = 81, 147, 150
local SHOP_ITEM_Y, SHOP_ITEM_DX = 365, 104

-- Plaque de service (icône à gauche, libellé), étiquette de prix dessous.
local function serviceButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(230, 52)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  b.plaque = W.plaque(face, { r = 12 })
  b.icon = face:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(34, 34)
  b.icon:SetPoint("CENTER", face, "LEFT", 29, 0)
  W.roundMask(face, b.icon, "mask_roundsq")
  W.setIcon(b.icon, Art.ui.remove, "ui:remove")
  b.label = W.label(face, "bold", 15, C.text)
  b.label:SetPoint("LEFT", face, "LEFT", 53, 0)
  b.tag = tagPill(b)
  b.tag:SetPoint("TOP", b, "BOTTOM", 0, -6)
  W.hoverable(b, { scale = 1.04, lift = 3, paint = function(self, h)
    if self.option and self.option.disabled then h = 0 end
    self.plaque:SetFill(1 + 0.25 * h)
    self.plaque:SetRim(W.lerpColor(Art.rim.silver, Art.rim.gold, h))
    self.plaque:SetGlow(0.7 * h)
  end })
  b:SetScript("OnClick", function(self) chooseOption(self.option) end)
  W.tooltip(b, function(tt, self)
    local o = self.option
    if o and o.disabled and o.reason then tt:AddLine(o.reason, 1, 0.3, 0.3, true) end
  end, "ANCHOR_TOP")
  return b
end

function Shop:Build(f)
  self.cards = {}
  for i = 1, 7 do
    local c = W.card(f)
    c:SetScript("OnClick", function(card) chooseOption(card.option) end)
    c.hoverScale, c.hoverLift = 1.12, 10 / SHOP_SCALE
    c:Hide()
    self.cards[i] = c
  end
  self.sections = {}
  for i, t in ipairs({ { "Bibelots", 57 }, { "Potions", 417 }, { "Service", 757 } }) do
    local l = W.label(f, "bold", 13, Art.hex("#d6deec"))
    l:SetPoint("LEFT", f, "TOPLEFT", t[2], -319)
    l:SetText(t[1])
    self.sections[i] = l
  end
  self.items = {}
  for i = 1, 8 do
    local b = groundObject(f, 46, "square")
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.items[i] = b
  end
  -- service : retrait de carte
  self.remove = serviceButton(f)
  at(self.remove, f, 869 - 115, 369 - 26, 230, 52)
  self.remove:Hide()
  self.pile = deckPile(f)
  self.coin = f:CreateTexture(nil, "ARTWORK")
  self.coin:SetSize(34, 34)
  self.coin:SetPoint("CENTER", f, "TOPLEFT", 467, -519)
  W.roundMask(f, self.coin)
  W.setIcon(self.coin, Art.ui.gold, "ui:gold")
  self.gold = W.label(f, "heavy", 30, C.goldText)
  self.gold:SetPoint("LEFT", f, "TOPLEFT", 491, -517)
  self.leave = W.button(f, "Reprendre la route", 206, 50, nil, "gold", 18)
  at(self.leave, f, 913 - 103, 519 - 25, 206, 50)
  self.leave:SetScript("OnClick", function(b) chooseOption(b.option) end)
  self.optionButtons = {}
end

function Shop:PlaceCard(card)
  if not card.cx then return end
  local base = self.frame:GetFrameLevel() + 10 + card.slot
  W.placeCard(card, self.frame, card.cx, card.cy, SHOP_SCALE, base, base + 30)
  card:SetHot(card.hover and true or false)
end

function Shop:Show(step)
  self.step = step
  UI.setStage({ scene = "shop", board = true, veil = 0.4 })
  self.pile:Sync()
  local r = Controller.runInfo()
  self.gold:SetText(r and tostring(r.gold) or "")
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
  local dx = n > 6 and 140 or SHOP_DX
  for i = 1, #self.cards do
    local card, o = self.cards[i], cards[i]
    if o and i <= n then
      card.option, card.slot = o, i
      card.cx = SHOP_X0 + (i - 1) * dx
      card.cy = SHOP_TOP + W.CARD_H * SHOP_SCALE / 2
      card:SetCard(o.card.id, o.card.up, { price = o.price, sold = o.sold, tooPoor = o.disabled and not o.sold,
        playable = true })
      self:PlaceCard(card)
      card:Show()
      self.optionButtons[o.id] = card
    else
      card.option, card.cx = nil, nil
      W.hideCard(card)
    end
  end
  -- Bibelots puis potions : cases sous leur titre, prix en pastille (rouge si trop cher).
  local k = 0
  local function place(list, x0)
    local step = #list > 3 and (SHOP_ITEM_DX * 3 / #list) or SHOP_ITEM_DX
    for i, o in ipairs(list) do
      k = k + 1
      local b = self.items[k]
      if b then
        local x = x0 + (i - 1) * step
        b.cx, b.cy = x, SHOP_ITEM_Y
        at(b, self.frame, x - 23, SHOP_ITEM_Y - 23, 46, 46)
        b.option = o
        b.info = { kind = o.item.kind, id = o.item.id, price = o.price, reason = o.disabled and o.reason or nil }
        W.setIcon(b.icon, W.itemEntry(o.item.kind, o.item.id), o.item.kind .. ":" .. tostring(o.item.id))
        b.icon:SetDesaturated(o.sold and true or false)
        b:SetRim(o.item.kind == "relic" and Art.rarityRim[(ns.Relics[o.item.id] or {}).rarity or "common"]
          or Art.rim.silver)
        if o.sold then b:SetTag("Vendu", { 0.6, 0.6, 0.6 })
        else b:SetTag(tostring(o.price), o.disabled and C.badText or C.goldText, true, o.disabled) end
        b.active = not o.disabled
        b:SetAlpha(o.sold and 0.45 or 1)
        b:Show()
        self.optionButtons[o.id] = b
      end
    end
  end
  place(relics, 81)
  place(potions, 441)
  for i = k + 1, #self.items do self.items[i].option = nil self.items[i]:Hide() end
  self.remove:Hide()
  for _, o in ipairs(services) do
    if o.id == "leave" then
      self.leave.option = o
      self.optionButtons[o.id] = self.leave
    else
      local rm = self.remove
      rm.option = o
      rm.label:SetText(o.label or o.id)
      rm.tag:Set(o.price and tostring(o.price) or "", o.disabled and C.badText or C.goldText, true, o.disabled)
      rm:SetAlpha(o.disabled and 0.6 or 1)
      rm:Show()
      self.optionButtons[o.id] = rm
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

-- Planche ecran_parcours.jpg : feuille d'ivoire au liseré d'argent ; étapes en médaillons argentés
-- (icône du type) ; accessibles : halo blanc ; position actuelle : plus grande, halo doré ; franchies :
-- icône estompée et petit hexagone vert ; à venir : icône grisée ; boss : grand médaillon à halo rouge
-- et son nom ; liens en pointillés (chemin parcouru brun doré, départs possibles sombres et épais,
-- le reste clair et fin). Aucune légende ; infobulle = nom du type.
local MAP_X0, MAP_X1, BOSS_X = 110, 790, 910
local MAP_Y0, MAP_Y1 = 150, 450
local NODE = 46            -- médaillon d'une étape (position actuelle : 54 ; boss : 76)

function Map:Build(f)
  local sheet = W.parchment(f, 12)
  at(sheet, f, 17, 60, 1000, 540)
  sheet:EnableMouse(false)
  self.parch = sheet
  self.canvas = CreateFrame("Frame", nil, f)
  self.canvas:SetAllPoints()
  self.canvas:SetFrameLevel(sheet:GetFrameLevel() + 2)
  self.nodes = {}
  self.lines = {}
  self.dots = {}
  self.optionButtons = {}
end

local function nodeButton(self, i)
  local b = CreateFrame("Button", nil, self.canvas)
  b:SetSize(NODE, NODE)
  b:SetFrameLevel(self.canvas:GetFrameLevel() + 5)
  local face = W.face(b)
  b.halo = W.skin(face, "glow_round", "BACKGROUND", 0)
  b.halo:SetPoint("CENTER")
  b.halo:Hide()
  b.shadow = W.skin(face, "medal_ring", "BACKGROUND", 1)
  b.shadow:SetPoint("CENTER", 1.5, -2)
  b.shadow:SetVertexColor(0, 0, 0, 0.45)
  b.ring = W.skin(face, "medal_ring", "ARTWORK", 0)
  b.ring:SetAllPoints()
  b.icon = face:CreateTexture(nil, "ARTWORK", nil, 1)
  b.icon:SetPoint("TOPLEFT", NODE * 0.11, -NODE * 0.11)
  b.icon:SetPoint("BOTTOMRIGHT", -NODE * 0.11, NODE * 0.11)
  W.roundMask(face, b.icon)
  b.done = W.hex(face, "green", 16, "OVERLAY", 0)
  b.done:SetPoint("CENTER", face, "CENTER", 16, -16)
  b.done:Hide()
  b.bossName = W.label(face, "bold", 14, C.inkDark, "OVERLAY", false)
  b.bossName:SetPoint("TOP", face, "BOTTOM", 0, -12)
  -- survol : l'étape grossit (davantage si elle est accessible, voir paintNode)
  W.hoverable(b, { scale = 1.1 })
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
  local cur = st == "current"
  local size = boss and 76 or (cur and 54 or NODE)
  b:SetSize(size, size)
  b.shadow:SetSize(size, size)
  b.hoverScale = st == "available" and 1.18 or 1.06
  b.icon:ClearAllPoints()
  b.icon:SetPoint("TOPLEFT", size * 0.11, -size * 0.11)
  b.icon:SetPoint("BOTTOMRIGHT", -size * 0.11, size * 0.11)
  W.setIcon(b.icon, Art.ui.map[kind] or Art.ui.map.event, "map:" .. tostring(kind))
  -- halo : doré (position actuelle), blanc (accessible), rouge (boss)
  local halo = boss and { 0.84, 0.15, 0.17 } or (cur and C.gold or (st == "available" and C.white or nil))
  if halo then
    b.halo:SetSize(size * 1.7, size * 1.7)
    b.halo:SetVertexColor(halo[1], halo[2], halo[3], 1)
    b.halo:SetAlpha(boss and 0.9 or (cur and 0.95 or 0.7))
    b.halo:Show()
  else
    b.halo:Hide()
  end
  -- icône : vive (accessible, actuelle, boss), estompée (franchie), grisée (à venir)
  local live = cur or st == "available" or boss
  b.icon:SetDesaturated(not live and st ~= "done")
  if st == "done" then b.icon:SetAlpha(0.6) b.icon:SetVertexColor(1, 1, 1, 1)
  elseif live then b.icon:SetAlpha(1) b.icon:SetVertexColor(1, 1, 1, 1)
  else b.icon:SetAlpha(1) b.icon:SetVertexColor(1.0, 1.0, 1.0, 1) end
  if st == "done" then b.done:Show() else b.done:Hide() end
  b.bossName:SetText(boss and (bossName or "") or "")
end

-- Pointillés : petits disques le long d'un segment (pool).
function Map:Dots(x1, y1, x2, y2, color, size, step, startK, alpha)
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  local n = floor(len / step)
  local k = startK
  for j = 2, n - 2 do
    k = k + 1
    local d = self.dots[k]
    if not d then
      d = W.disc(self.canvas, "ARTWORK", 0, color)
      self.dots[k] = d
    end
    d:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    d:SetSize(size, size)
    at(d, self.frame, x1 + dx * j / n - size / 2, y1 + dy * j / n - size / 2)
    d:Show()
  end
  return k
end

local DOT_WALKED, DOT_NEXT, DOT_REST = Art.hex("#966014"), Art.hex("#3c3428"), Art.hex("#786e5c")

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
  -- Liens en pointillés : chemin parcouru (brun doré), départs possibles (sombres, épais), le reste.
  local kd = 0
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
        if walked then
          kd = self:Dots(p1[1], p1[2], p2[1], p2[2], DOT_WALKED, 4.8, 9, kd)
        elseif s1 == "current" and s2 == "available" or (s1 == nil and s2 == "available") then
          kd = self:Dots(p1[1], p1[2], p2[1], p2[2], DOT_NEXT, 4.8, 9, kd)
        else
          kd = self:Dots(p1[1], p1[2], p2[1], p2[2], DOT_REST, 3.2, 9, kd, 0.6)
        end
      end
    end
  end
  for i = 1, #self.lines do self.lines[i]:Hide() end
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
-- Bilan et méta : panneau d'ardoise, barres de réputation, journal
---------------------------------------------------------------------------

local Progress = { kinds = { "end", "meta" } }
UI.register("progress", Progress)

function Progress:Build(f)
  local panel = W.woodPanel(f, 14)
  at(panel, f, 167, 60, 700, 356)
  self.panel = panel
  self.title = W.label(panel, "heavy", 28, C.text)
  self.title:SetPoint("TOP", 0, -16)
  self.text = W.label(panel, "bold", 13.5, C.textSoft)
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
    local fs = W.label(panel, "body", 12, C.textSoft)
    fs:SetWidth(600)
    fs:SetJustifyH("LEFT")
    self.journal[i] = fs
  end
  self.buttons = {}
  for i = 1, 3 do
    local b = W.button(f, "", 220, i == 1 and 50 or 44, nil, i == 1 and "gold" or "slate", i == 1 and 18 or 15)
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
  local tc = C.text
  if step.kind == "end" then tc = step.won and C.healGreen or C.badText end
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
      local c = l.won and C.healGreen or C.textSoft
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
      if i == 1 then at(b, self.frame, 790, 494, 220, 50) else at(b, self.frame, 24 + (i - 2) * 236, 497, 220, 44) end
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

---------------------------------------------------------------------------
-- Consultation des cartes (par-dessus l'écran) : deck complet, pioche, défausse, consumées
---------------------------------------------------------------------------
-- Grille de vraies cartes (W.card), triées par type, coût puis nom ; la pioche n'est jamais montrée
-- dans l'ordre de tirage. Défilement à la molette ; fermeture par Échap, clic hors du panneau ou
-- « Fermer ». Aucune règle : ne fait que lire l'état.

local DV = { kind = nil, offset = 0, list = {} }
UI.deckView = DV

local DV_X, DV_Y, DV_W, DV_H = 52, 58, 930, 540
local DV_SCALE, DV_ROW, DV_ROWS = 0.72, 8, 3
local DV_GAPX, DV_GAPY = 14, 28 -- (languette de coût et plaque du bas entre deux rangées)
local DV_TOP = DV_Y + 58
local DV_TITLE = { deck = "Deck", draw = "Pioche", discard = "Défausse", exhaust = "Consumées" }
local TYPE_ORDER = { attack = 1, skill = 2, power = 3 }

-- Copie triée : type, coût, nom, puis non améliorée avant améliorée (l'ordre réel est perdu).
function DV.sorted(list)
  local out = {}
  for i = 1, #(list or {}) do
    local inst = list[i]
    local d = ns.Card.defById(inst.id, inst.up)
    out[i] = { inst = inst, t = TYPE_ORDER[d.type] or 9, cost = d.cost or 99, name = d.name or inst.id,
      up = inst.up and 1 or 0, uid = tostring(inst.uid or "") }
  end
  table.sort(out, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    if a.cost ~= b.cost then return a.cost < b.cost end
    if a.name ~= b.name then return a.name < b.name end
    if a.up ~= b.up then return a.up < b.up end
    return a.uid < b.uid
  end)
  for i = 1, #out do out[i] = out[i].inst end
  return out
end

-- Cartes de la source demandée (nil si indisponible : pas d'expédition, ou pile hors combat).
function DV.source(kind)
  if kind == "deck" then
    local r = Controller.runInfo()
    return r and r.deck
  end
  local c = Controller.combat()
  return c and c[kind]
end

local function wheel(_, delta) DV:Scroll(-delta) end

function DV:Build()
  local content = UI.content
  local base = content:GetFrameLevel() + 110
  -- voile cliquable sous le bandeau : un clic hors du panneau ferme
  local veil = CreateFrame("Button", nil, content)
  at(veil, content, 0, Scene.TOP, Scene.W, Scene.H - Scene.TOP)
  veil:SetFrameLevel(base)
  veil:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local shade = W.rect(veil, "BACKGROUND", 0, C.black, 0.5)
  shade:SetAllPoints()
  veil:SetScript("OnClick", function() DV:Close() end)
  veil:EnableMouseWheel(true)
  veil:SetScript("OnMouseWheel", wheel)
  veil:Hide()
  self.frame = veil

  local panel = W.woodPanel(veil, 12)
  at(panel, content, DV_X, DV_Y, DV_W, DV_H)
  panel:SetFrameLevel(base + 2)
  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", wheel)
  self.panel = panel
  self.title = W.label(panel, "bold", 20, C.text)
  self.title:SetPoint("TOP", 0, -14)
  self.empty = W.label(panel, "body", 14, C.textSoft)
  self.empty:SetPoint("CENTER", 0, 10)
  self.empty:SetText("Aucune carte.")
  self.close = W.button(panel, "Fermer", 120, 34, function() DV:Close() end, "gold", 14)
  self.close:SetPoint("BOTTOMRIGHT", -16, 14)
  -- indicateur de défilement
  self.track = W.rect(panel, "ARTWORK", 0, C.barTrack)
  self.thumb = W.rect(panel, "ARTWORK", 1, Art.hex("#ced6e2"))

  self.cards = {}
  for i = 1, DV_ROW * DV_ROWS do
    local c = W.card(veil)
    c.hoverScale, c.hoverLift = 1.14, 6 / DV_SCALE
    c:EnableMouseWheel(true)
    c:SetScript("OnMouseWheel", wheel)
    c:SetScript("OnClick", function(_, button) if button == "RightButton" then DV:Close() end end)
    c:Hide()
    self.cards[i] = c
  end
end

function DV:Rows() return math.ceil(#self.list / DV_ROW) end
function DV:MaxOffset() return max(0, self:Rows() - DV_ROWS) end

function DV:Layout()
  local cw, ch = W.CARD_W * DV_SCALE, W.CARD_H * DV_SCALE
  local perRow = max(1, min(DV_ROW, #self.list)) -- une seule rangée incomplète : centrée
  local rowW = perRow * (cw + DV_GAPX) - DV_GAPX
  local x0 = DV_X + (DV_W - rowW) / 2
  local first = self.offset * DV_ROW
  local level = self.panel:GetFrameLevel() + 5
  for i, card in ipairs(self.cards) do
    local inst = self.list[first + i]
    if inst then
      local col, row = (i - 1) % DV_ROW, floor((i - 1) / DV_ROW)
      card:SetCard(inst.id, inst.up, {})
      W.placeCard(card, UI.content, x0 + col * (cw + DV_GAPX) + cw / 2,
        DV_TOP + row * (ch + DV_GAPY) + ch / 2, DV_SCALE, level + i, level + 60)
      card:SetHot(card.hover and true or false)
      card:Show()
    else
      W.hideCard(card)
    end
  end
  if #self.list == 0 then self.empty:Show() else self.empty:Hide() end
  -- indicateur de défilement : seulement si tout ne tient pas
  local maxOff = self:MaxOffset()
  if maxOff > 0 then
    local trackH = DV_ROWS * (ch + DV_GAPY) - DV_GAPY
    local thumbH = max(24, trackH * DV_ROWS / self:Rows())
    at(self.track, self.panel, DV_W - 22, DV_TOP - DV_Y, 6, trackH)
    at(self.thumb, self.panel, DV_W - 22, DV_TOP - DV_Y + (trackH - thumbH) * self.offset / maxOff, 6, thumbH)
    self.track:Show()
    self.thumb:Show()
  else
    self.track:Hide()
    self.thumb:Hide()
  end
end

-- Relit la source (l'état a pu changer : potion bue, combat fini…).
function DV:Refresh()
  if not self:IsShown() then return end
  local src = DV.source(self.kind)
  if not src then self:Close() return end
  self.list = DV.sorted(src)
  local n = #self.list
  self.title:SetText((DV_TITLE[self.kind] or "Cartes") .. " · " .. n .. " carte" .. (n > 1 and "s" or ""))
  if self.offset > self:MaxOffset() then self.offset = self:MaxOffset() end
  self:Layout()
end

function DV:Open(kind)
  if not UI.content or not DV.source(kind) then return false end
  if not self.frame then self:Build() end
  if GameTooltip then GameTooltip:Hide() end
  self.kind = kind
  self.offset = 0
  self.frame:Show()
  self:Refresh()
  W.sound("card")
  return true
end

function DV:Close()
  if not self:IsShown() then return end
  for _, card in ipairs(self.cards) do W.hideCard(card) end
  self.frame:Hide()
  self.kind = nil
  if GameTooltip then GameTooltip:Hide() end
end

function DV:IsShown() return self.frame ~= nil and self.frame:IsShown() and true or false end

-- delta > 0 : vers le bas (une rangée par cran de molette).
function DV:Scroll(delta)
  local off = self.offset + (delta > 0 and 1 or -1)
  if off < 0 then off = 0 end
  if off > self:MaxOffset() then off = self:MaxOffset() end
  if off == self.offset then return end
  self.offset = off
  self:Layout()
end

-- Ouvre la source demandée, ou ferme si elle est déjà affichée.
function UI.toggleDeckView(kind)
  if DV:IsShown() and DV.kind == kind then DV:Close() return end
  if not DV:Open(kind) then UI.flash("Aucune carte à montrer.") end
end
