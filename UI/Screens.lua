-- Écrans pilotés par les étapes génériques de UI/Controller.lua, sur la scène commune (UI/Scene.lua) :
--   start    : accueil (classe, clé mythique, départ, méta)
--   choice   : rencontre et bibelot de classe (docs/maquette/Rencontre.dc.html)
--   campfire : feu de camp (couchage = repos, grimoire = améliorer)
--   reward   : récompense et coffre (docs/maquette/Recompense.dc.html)
--   deck     : grille du deck (amélioration, retrait, sélection de rencontre)
--   shop     : marchand (étal : cartes, bibelots, fioles, retrait)
--   map      : carte de parcours (docs/maquette/Parcours.dc.html)
--   progress : bilan et journal des expéditions (« Log »)
-- Aucun écran ne connaît les règles : chaque clic devient UI.choose(idOption) ; ce qui est grisé, les
-- prix et les raisons viennent du contrôleur (donc de Core/Expedition.lua).
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art, UI, Scene, Controller = ns.Widgets, ns.Art, ns.UI, ns.Scene, ns.Controller
local C = Art.C
local at = Scene.at
local max, min, floor = math.max, math.min, math.floor

-- Titre d'une classe après son nom (« Priest — Dragonslayer » : Nefarian vaincu avec la classe ; « Veteran » au
-- niveau 7) : règle ns.Blackrock.title (Core/ZoneRules/blackrock.lua), lue sur le compte ; nom seul sinon.
local function withTitle(name, cid)
  local BR = ns.Blackrock
  local db = ns.Persist and ns.Persist.db
  local t = BR and BR.title and cid and db and BR.title(db.meta, cid)
  return t and ((name or "") .. " — " .. t) or (name or "")
end

local function chooseOption(o)
  if not o then return end
  if o.disabled then UI.flash(o.reason or "Unavailable.") return end
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

-- Tas du deck sur la table : deux dos de carte, nombre dans un petit anneau doré ; infobulle = contenu ;
-- clic = consulter le deck. Bas à y 574 : rien ne déborde de la fenêtre.
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
  -- surbrillance : copie additive du dos de carte (créée d'avance, éteinte)
  p.light = W.lightLayer(W.cardBack(face, PILE_H, "BACKGROUND", 1))
  p.light:SetPoint("CENTER")
  p.disc = W.disc(face, "ARTWORK", 0, C.black, 0.8)
  p.disc:SetSize(28, 28)
  p.disc:SetPoint("CENTER", 30, -46)
  p.ring = W.wow(face, "ring_small", "ARTWORK", 1)
  p.ring:SetSize(36, 36)
  p.ring:SetPoint("CENTER", p.disc, "CENTER", 0, 0)
  p.count = W.label(face, "heavy", 15, C.text, "OVERLAY")
  p.count:SetPoint("CENTER", p.disc, "CENTER", 0, 1)
  -- survol : le dos de carte s'éclaircit (le nombre ne bouge pas)
  W.hoverable(p, { paint = function(self, h) self.light:SetAlpha(W.LIGHT_ADD * h) end })
  p:SetScript("OnClick", function(_, button)
    if button == "RightButton" then return end
    W.sound("click")
    UI.toggleDeckView("deck")
  end)
  W.tooltip(p, function(tt)
    UI.fillDeckTooltip(tt)
    tt:AddLine("Click: view the cards.", 0.6, 0.6, 0.6)
  end, "ANCHOR_RIGHT")
  p.Sync = function(self)
    local r = Controller.runInfo()
    self.count:SetText(r and #r.deck or "")
  end
  return p
end

-- Réponse (rencontre, bibelot, feu de camp) à la façon B : gros bouton rouge du jeu portant le libellé
-- (icône de l'objet dans une case à gauche), et sous le bouton ce que la réponse donne ou coûte (vert
-- pour un gain, rouge pour une perte ou la raison d'un refus). Survol : liseré d'or, bouton éclairci,
-- libellé blanchi, sans grossir ni bouger (texte stable) ; clic maintenu : assombri.
-- Mise en page : bouton de OPT_BTN de haut en haut de la zone ; libellé sur une ligne dans le bouton
-- moins ses bouts et OPT_MX (paliers OPT_LABEL, puis réduit) ; texte dessous, dans la largeur moins
-- OPT_MX, sur une ligne si possible (paliers OPT_SUB), sinon en lignes équilibrées ; mesures par le client.
local OPT_BTN, OPT_MX, OPT_GAP, OPT_ICON = 50, 14, 7, 34
local OPT_LABEL = { 19, 18, 17, 16, 15, 14 }
local OPT_SUB = { 15, 14, 13.5, 13, 12.5 }
UI.OPT = { btn = OPT_BTN, mx = OPT_MX, gap = OPT_GAP, icon = OPT_ICON, label = OPT_LABEL, sub = OPT_SUB }

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

-- Pose un texte : lignes explicites dans une boîte posée, bien plus large et plus haute que le texte
-- (W.looseBox : le client ne recoupe ni ne tronque jamais, à aucune échelle) ; renvoie sa hauteur mesurée
-- (nombre de lignes × hauteur d'une ligne : la hauteur du texte, pas celle de la boîte).
local function setLines(fs, lines, s, zw)
  W.setSize(fs, s)
  fs:SetWordWrap(#lines > 1)
  W.looseBox(fs, #lines, zw)
  fs:SetText(table.concat(lines, "\n"))
  return fs:GetStringHeight() or 0
end

local function plaque(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(300, 118)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  -- bouton : cadre d'ancrage seulement (aucune région), pièces posées sur le visuel
  b.btn = CreateFrame("Frame", nil, face)
  b.btn:SetPoint("TOPLEFT", face, "TOPLEFT", 0, 0)
  b.btn:SetPoint("TOPRIGHT", face, "TOPRIGHT", 0, 0)
  b.btn:SetHeight(OPT_BTN)
  b.base = W.threeSlice(b.btn, "btn_red", "BACKGROUND", -6, { parent = face })
  b.hot = W.hoverLayer(W.threeSlice(b.btn, "btn_goldred", "BACKGROUND", -5, { parent = face }))
  b.hot:SetAlpha(0)
  b.light = W.lightLayer(W.threeSlice(b.btn, "btn_goldred", "BACKGROUND", -4, { parent = face }))
  b.iconBox = CreateFrame("Frame", nil, face)
  b.iconBox:SetSize(OPT_ICON, OPT_ICON)
  b.slot = W.slotOn(b.iconBox, OPT_ICON, 0, face)
  b.icon = b.slot.icon
  b.label = W.label(face, "bold", OPT_LABEL[1], C.wowGold)
  b.label:SetJustifyH("CENTER")
  b.label:SetWordWrap(false)
  b.labelColor = C.wowGold
  b.sub = W.label(face, "bold", OPT_SUB[1], C.text)
  b.sub:SetJustifyH("CENTER")
  b.sub:SetJustifyV("TOP") -- ancré par le haut dans une boîte plus haute que lui (W.looseBox)
  b.sub:SetWordWrap(true)
  -- Libellé dans le bouton, texte dessous ; renvoie la mise en page retenue.
  b.Layout = function(self, label, sub, w, h, withIcon)
    local cap = self.base.cap or (OPT_BTN * 0.36)
    local iconW = withIcon and (OPT_ICON + 6) or 0
    local lw = w - 2 * cap - 2 * OPT_MX + 16 - iconW
    local fit = { ok = false }
    local ls
    for _, s in ipairs(OPT_LABEL) do
      if textWidth(self.label, label, s) * W.TEXT_SAFE <= lw then ls = s break end
    end
    if not ls then
      ls = OPT_LABEL[#OPT_LABEL]
      local tw = textWidth(self.label, label, ls) * W.TEXT_SAFE
      ls = max(10, floor(ls * lw / max(1, tw) * 10) / 10)
    end
    setLines(self.label, { label }, ls, lw)
    local labelW = textWidth(self.label, label, ls)
    setLines(self.label, { label }, ls, lw)
    -- texte sous le bouton
    local zw = w - 2 * OPT_MX
    local zh = h - OPT_BTN - OPT_GAP
    local sh, slines, ss = 0, {}, OPT_SUB[1]
    if sub ~= "" then
      local cands = {}
      for i = 1, 2 do cands[#cands + 1] = { OPT_SUB[i], 1 } end
      for _, s in ipairs(OPT_SUB) do cands[#cands + 1] = { s, 2 } end
      for _, s in ipairs(OPT_SUB) do cands[#cands + 1] = { s, 3 } end
      for _, c in ipairs(cands) do
        local lines, lwid = balanced(self.sub, sub, c[1], c[2])
        if #lines == c[2] and lwid * W.TEXT_SAFE <= zw then
          local hh = setLines(self.sub, lines, c[1], zw)
          if hh <= zh then sh, slines, ss, fit.ok = hh, lines, c[1], true break end
        end
      end
      if not fit.ok then
        slines = balanced(self.sub, sub, OPT_SUB[#OPT_SUB], 3)
        ss = OPT_SUB[#OPT_SUB]
        sh = setLines(self.sub, slines, ss, zw)
      end
    else
      fit.ok = true
    end
    self.sub:SetShown(sub ~= "")
    -- libellé (et icône) centrés dans le bouton
    local block = labelW + iconW
    self.label:ClearAllPoints()
    self.label:SetPoint("CENTER", self.btn, "CENTER", iconW / 2, 0.5)
    self.iconBox:ClearAllPoints()
    if withIcon then
      self.iconBox:SetPoint("CENTER", self.btn, "CENTER", -block / 2 + OPT_ICON / 2, 0)
    end
    self.sub:ClearAllPoints()
    self.sub:SetPoint("TOP", self.btn, "BOTTOM", 0, -OPT_GAP)
    fit.label, fit.sub, fit.subLines, fit.labelW, fit.lw, fit.zw, fit.zh, fit.subH =
      ls, ss, #slines, labelW, lw, zw, zh, sh
    self.optFit = fit
    return fit
  end
  b.SetOption = function(self, o, w, h)
    self.option = o
    self:SetSize(w, h)
    local sub = o.text or ""
    local col = C.text
    if o.disabled and o.reason then sub, col = o.reason, C.badText
    elseif sub:match("^%+") then col = C.healGreen
    elseif sub:match("^%-") then col = C.badText end
    self.sub:SetTextColor(col[1], col[2], col[3])
    local withIcon = o.item ~= nil
    if withIcon then
      W.setIcon(self.icon, W.itemEntry(o.item.kind, o.item.id), o.item.kind .. ":" .. tostring(o.item.id))
    end
    for _, t in ipairs({ self.slot.bg, self.slot.icon, self.slot.frame, self.slot.hot }) do t:SetShown(withIcon) end
    self.base:Layout(OPT_BTN)
    self.hot:Layout(OPT_BTN)
    self.light:Layout(OPT_BTN)
    self:Layout(o.label or o.id, sub, w, h, withIcon)
    self.base:SetDesaturated(o.disabled and true or false)
    self:SetAlpha(o.disabled and 0.6 or 1)
    -- une réponse impossible ne s'allume pas
    self:hoverPaint(W.animValue(self, "hover"))
    self:Show()
  end
  b:SetScript("OnClick", function(self) chooseOption(self.option) end)
  W.tooltip(b, function(tt, self)
    local o = self.option
    if o and o.item then W.fillItemTooltip(tt, o.item.kind, o.item.id, { reason = o.disabled and o.reason or nil }) end
  end, "ANCHOR_TOP")
  -- survol : le liseré d'or apparaît, le bouton s'éclaircit (comme W.button) ; une réponse impossible
  -- ne s'allume pas
  W.hoverable(b, { paint = function(self, h)
    if not (self.option and not self.option.disabled) then h = 0 end
    W.buttonPaint(self, h)
  end })
  W.pressable(b)
  return b
end

-- Étiquette de prix (ou d'état) : rail sombre du curseur minimal du jeu, pièce d'or et nombre ;
-- t:Set(texte, couleur, prix, trop cher) ; texte vide = cachée. « Trop cher » : nombre en rouge.
local function tagPill(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetSize(58, 14)
  local l, m, r = W.wow(t, "slider_l", "BACKGROUND", 0), W.wow(t, "slider_m", "BACKGROUND", 0),
    W.wow(t, "slider_r", "BACKGROUND", 0)
  l:SetSize(9, 14) l:SetPoint("LEFT")
  r:SetSize(9, 14) r:SetPoint("RIGHT")
  m:SetPoint("TOPLEFT", l, "TOPRIGHT") m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
  t.coin = t:CreateTexture(nil, "ARTWORK")
  t.coin:SetSize(13, 13)
  t.coin:SetPoint("LEFT", 5, 0)
  W.roundMask(t, t.coin)
  W.setIcon(t.coin, Art.ui.gold, "ui:gold")
  t.text = W.label(t, "heavy", 12.5, C.goldText)
  t.text:SetPoint("CENTER", 0, 0.5)
  t:Hide()
  t.Set = function(self, text, color, isPrice, bad)
    if not text or text == "" then self:Hide() return end
    self.text:SetText(text)
    local c = color or C.goldText
    self.text:SetTextColor(c[1], c[2], c[3])
    self.text:ClearAllPoints()
    if isPrice then
      self.coin:Show()
      self.text:SetPoint("CENTER", 7, 0.5)
      self:SetWidth(max(56, (self.text:GetStringWidth() or 30) + 36))
    else
      self.coin:Hide()
      self.text:SetPoint("CENTER", 0, 0.5)
      self:SetWidth((self.text:GetStringWidth() or 40) + 24)
    end
    self.bad = bad
    self:Show()
  end
  return t
end

-- Objet cliquable (butin, articles du marchand, couchage et grimoire du feu, coffre) : case de barre
-- d'action du jeu (shape "square") ou icône ronde dans le grand anneau doré (shape "round") ; nombre en
-- bas à droite (b.big) ; étiquette dessous (prix : pièce + nombre, rouge si trop cher ; ou texte).
-- Survol : cadre doré (case) ou halo doré (anneau), sans grossir ni bouger (nombre et étiquette stables).
local function groundObject(parent, size, shape)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  if shape == "round" then
    b.glow = W.skin(face, "glow_round", "BACKGROUND", -8)
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(size * 1.55, size * 1.55)
    b.glow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
    b.glow:SetAlpha(0)
    W.medallionOn(face, size)
    b.icon, b.ring = face.icon, face.ring
  else
    b.slot = W.slotOn(face, size)
    b.icon = b.slot.icon
  end
  b.big = W.label(face, "heavy", 15, C.goldText, "OVERLAY")
  b.big:SetPoint("CENTER", face, "BOTTOMRIGHT", -6, 6)
  b.tag = tagPill(b)
  b.tag:SetPoint("TOP", b, "BOTTOM", 0, -5)
  b.SetTag = function(self, ...) self.tag:Set(...) end
  b.SetRim = function(self, c)
    if self.slot then c = c or Art.rim.silver self.slot.frame:SetVertexColor(c[1], c[2], c[3], 1) end
  end
  W.hoverable(b, { paint = function(self, h)
    if self.active == false then h = 0 end
    if self.glow then self.glow:SetAlpha(0.8 * h) end
    if self.slot then self.slot.hot:SetAlpha(h) end
  end })
  W.tooltip(b, function(tt, self)
    local info = self.info
    if not info then return end
    W.fillItemTooltip(tt, info.kind, info.id, info)
  end, "ANCHOR_TOP")
  return b
end

-- Texte d'une rencontre (direction B) : parchemin Dragonflight, titre et texte à l'encre sombre (sans
-- ombre), centrés ; edge = couleur du titre (rencontre rare : or sombre, histoire : violet sombre).
local function bubble(parent)
  local f = W.parchment(parent)
  f:SetSize(470, 96)
  f.title = W.label(f, "bold", 16, C.parchInk, "OVERLAY", false)
  f.title:SetPoint("TOP", 0, -18)
  f.text = W.label(f, "bold", 14, C.parchInk, "OVERLAY", false)
  f.text:SetJustifyH("CENTER")
  f.text:SetWordWrap(true)
  f.text:SetSpacing(3)
  f.Set = function(self, title, text, edge)
    self.title:SetText(title or "")
    local tc = edge or C.parchInk
    self.title:SetTextColor(tc[1], tc[2], tc[3])
    self.text:SetWidth(self:GetWidth() - 64)
    self.text:ClearAllPoints()
    if title and title ~= "" then
      self.text:SetPoint("TOP", self.title, "BOTTOM", 0, -8)
    else
      self.text:SetPoint("TOP", 0, -20)
    end
    self.text:SetText(text or "")
    local h = (self.text.GetStringHeight and self.text:GetStringHeight()) or 60
    if type(h) ~= "number" or h <= 0 then h = 60 end
    self:SetHeight(h + ((title and title ~= "") and 70 or 42))
  end
  return f
end

---------------------------------------------------------------------------
-- Accueil : classe, clé mythique, départ
---------------------------------------------------------------------------

local Start = { kinds = { "start" } }
UI.register("start", Start)

-- Rangée des classes : icônes de START_ICON unités (anneau compris) espacées de START_STEP, centrées dans
-- START_ROW_W ; au-delà, pas et taille réduits pour tenir dans le panneau. Haut de la rangée à START_TOP
-- sous le haut du panneau ; libellé des zones à START_ZONES (deux rangées de boutons : 4 puis 3, de
-- START_ZONE_W × START_ZONE_H, pas START_ZONE_DX / START_ZONE_DY) ; libellé des clés à START_KEYS. Panneau
-- en START_PANEL_Y, START_PANEL_H de haut (son bas reste au-dessus de la note, y 446).
local START_ICON, START_STEP, START_ROW_W, START_TOP = 64, 92, 520, 56
local START_ZONES, START_ZONE_W, START_ZONE_H, START_ZONE_DX, START_ZONE_DY = 150, 126, 34, 132, 38
local START_KEYS, START_PANEL_Y, START_PANEL_H = 258, 44, 392
UI.START = { icon = START_ICON, step = START_STEP, rowW = START_ROW_W, top = START_TOP, keys = START_KEYS,
  zones = START_ZONES, zoneW = START_ZONE_W, zoneH = START_ZONE_H, panelY = START_PANEL_Y, panelH = START_PANEL_H }

-- Infobulle d'une classe : nom, PV et cartes (accueil), niveau de classe.
local function fillClassTooltip(tt, o)
  tt:AddLine(o.label or "", 1, 0.82, 0)
  if o.text and o.text ~= "" then tt:AddLine(o.text, 1, 1, 1, true) end
  if o.level then tt:AddLine("Level " .. o.level, 1, 1, 1) end
  if not o.selected and o.id and o.id:match("^class:") then tt:AddLine("Click: play this class.", 0.6, 0.6, 0.6) end
end

-- Icône de classe : grand anneau doré, icône ronde, halo doré créé d'avance (éteint) ; choisie : halo
-- tenu, anneau et icône pleins ; sinon assombrie, éclairée au survol (halo en fondu, sans grossir).
local CLASS_DIM = 0.5
local function classIcon(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(START_ICON, START_ICON)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  b.glow = W.skin(face, "glow_round", "BACKGROUND", -8)
  b.glow:SetPoint("CENTER")
  b.glow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
  b.glow:SetAlpha(0)
  W.medallionOn(face, START_ICON)
  b.icon, b.ring = face.icon, face.ring
  b.Resize = function(self, s)
    self:SetSize(s, s)
    self.face:Resize(s)
    self.glow:SetSize(s * 1.6, s * 1.6)
  end
  b:Resize(START_ICON)
  W.hoverable(b, { paint = function(self, h)
    local sel = self.selected
    local k = sel and 1 or (CLASS_DIM + (1 - CLASS_DIM) * h)
    self.icon:SetVertexColor(k, k, k, 1)
    local rk = sel and 1 or (0.62 + 0.38 * h)
    self.ring:SetVertexColor(rk, rk, rk, 1)
    self.glow:SetAlpha(sel and 0.85 or 0.45 * h)
  end })
  b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  W.tooltip(b, function(tt, btn) if btn.option then fillClassTooltip(tt, btn.option) end end, "ANCHOR_TOP")
  b.SetSelected = function(self, on)
    self.selected = on and true or false
    self:hoverPaint(W.animValue(self, "hover"))
  end
  b:Hide()
  return b
end

function Start:Build(f)
  self.hero = heroFigure(f)
  local panel = W.dialog(f, "Slay the Dragon", 18)
  at(panel, f, 280, START_PANEL_Y, 560, START_PANEL_H)
  self.panel = panel
  self.title = panel.title
  -- Classes : une rangée d'icônes de classe dans le grand anneau doré, sans texte ; nom, PV, cartes et
  -- niveau dans l'infobulle ; la classe choisie a son halo doré, les autres sont assombries, et son
  -- nom seul est écrit sous son icône. Autant d'icônes que de classes jouables (Start:Show).
  self.classIcons = {}
  self.className = W.label(panel, "bold", 14, C.wowGold)
  self.className:Hide()
  -- La campagne : une plaque rouge par zone, dans l'ordre (nom ; dessous, en petit, « Beaten », « Reached »,
  -- « Not reached »), affichée et non choisie (toute expédition part de Westfall) : aucun clic, aucune
  -- surbrillance ; la plus loin atteinte au liseré d'or ; pas encore atteinte : éteinte ; état en infobulle.
  self.zoneLabel = W.label(panel, "bold", 15, C.wowGold)
  self.zoneLabel:SetPoint("TOP", 0, -START_ZONES)
  self.zoneLabel:SetText("Campaign")
  self.zoneButtons = {}
  for i = 1, #ns.Zone.ORDER do
    local b = W.button(panel, "", START_ZONE_W, START_ZONE_H, nil, "red", 12.5)
    b.status = W.label(b.face, "body", 10, C.textSoft, "OVERLAY")
    b.status:SetPoint("CENTER", 0, -7.5)
    b.active = false
    W.tooltip(b, function(tt, btn)
      local o = btn.option
      if not o then return end
      tt:AddLine(o.label or "", 1, 0.82, 0)
      if o.text then tt:AddLine(o.text, 1, 1, 1, true) end
    end, "ANCHOR_TOP")
    b:Hide()
    self.zoneButtons[i] = b
  end
  self.keyLabel = W.label(panel, "bold", 15, C.wowGold)
  self.keyLabel:SetPoint("TOP", 0, -START_KEYS)
  self.keyLabel:SetText("Mythic Keystone")
  self.keyButtons = {}
  -- clés +0…+5 : cases de barre d'action à l'icône de la clé, « +N » ; choisie : cadre doré ;
  -- verrouillée : icône grise
  for i = 1, 6 do
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(46, 46)
    local face = W.face(b)
    b.slot = W.slotOn(face, 46)
    W.setIcon(b.slot.icon, Art.keystone, "ui:keystone")
    b.label = W.label(face, "heavy", 16, C.text, "OVERLAY")
    b.label:SetPoint("CENTER", 0, 1)
    -- survol : cadre doré de la case (tenu pour la clé choisie), sans grossir ; clé verrouillée : rien
    -- ne s'allume (son infobulle dit pourquoi)
    W.hoverable(b, { paint = function(self, h)
      if self.option and self.option.disabled then h = 0 end
      self.slot.hot:SetAlpha(max(h, self.selected and 1 or 0))
    end })
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    W.tooltip(b, function(tt, btn)
      local o = btn.option
      if not o then return end
      tt:AddLine("Key +" .. o.label:gsub("^%+", ""), 1, 0.82, 0)
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
  self.go = W.button(f, "Start expedition", 230, 50, nil, "gold", 18)
  at(self.go, f, 790, 494, 230, 50)
  self.go:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  self.meta = W.button(f, "Progress", 210, 44, nil, "red", 15)
  at(self.meta, f, 24, 497, 210, 44)
  self.meta:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  self.optionButtons = {}
end

function Start:Show(step)
  self.step = step
  UI.setStage({ scene = "road", board = true, veil = 0.2 })
  Scene.playerFigure(self.hero)
  self.optionButtons = {}
  local classes, zones, keys, others = {}, {}, {}, {}
  for _, o in ipairs(step.options) do
    if o.group == "class" then classes[#classes + 1] = o
    elseif o.group == "zone" then zones[#zones + 1] = o
    elseif o.group == "key" then keys[#keys + 1] = o
    else others[#others + 1] = o end
  end
  -- rangée d'icônes de classe, centrée ; pas et taille réduits si les classes ne tiennent pas
  local nc = #classes
  local pitch = min(START_STEP, START_ROW_W / max(nc, 1))
  local size = min(START_ICON, floor(pitch - 20))
  local chosen
  for i = #self.classIcons + 1, nc do self.classIcons[i] = classIcon(self.panel) end
  for i, b in ipairs(self.classIcons) do
    local o = classes[i]
    if o then
      local cid = o.id:match("^class:(.+)$")
      if b.cid ~= cid then
        b.cid = cid
        W.setIcon(b.icon, Art.class(cid), "class:" .. tostring(cid))
      end
      if b.size ~= size then b.size = size b:Resize(size) end
      b:ClearAllPoints()
      b.x = (i - (nc + 1) / 2) * pitch
      b:SetPoint("TOP", self.panel, "TOP", b.x, -START_TOP - (START_ICON - size) / 2)
      b.option = o
      b:SetSelected(o.selected)
      if o.selected then chosen = b end
      b:Show()
      self.optionButtons[o.id] = b
    else
      b.option = nil
      b:Hide()
    end
  end
  -- nom seul de la classe choisie, sous son icône
  self.className:ClearAllPoints()
  if chosen then
    self.className:SetPoint("TOP", self.panel, "TOP", chosen.x, -START_TOP - START_ICON - 6)
    self.className:SetText(withTitle(chosen.option.label, chosen.cid))
    self.className:Show()
  else
    self.className:Hide()
  end
  self.panel:SetHeight(START_PANEL_H)
  -- campagne : 4 puis 3 plaques, chaque rangée centrée ; état sous le nom ; pas encore atteinte : éteinte
  local perRow = 4
  for i, b in ipairs(self.zoneButtons) do
    local o = zones[i]
    if o then
      local row = floor((i - 1) / perRow)
      local inRow = min(perRow, #zones - row * perRow)
      local col = (i - 1) % perRow
      b:ClearAllPoints()
      b:SetPoint("TOP", self.panel, "TOP", (col - (inRow - 1) / 2) * START_ZONE_DX,
        -START_ZONES - 24 - row * START_ZONE_DY)
      b.option = o
      local off = o.status == "ahead" or o.status == "later"
      b:SetText(o.label)
      b.label:ClearAllPoints()
      b.label:SetPoint("CENTER", 0, 5.5)
      b.status:SetText(o.statusLabel or "")
      local sc = o.status == "won" and C.healGreen or C.textSoft
      b.status:SetTextColor(sc[1], sc[2], sc[3])
      b.labelColor = off and C.textDim or C.wowGold
      b.active = false
      b.base:SetDesaturated(off)
      b:SetSelected(o.farthest and true or false)
      b:Show()
      self.optionButtons[o.id] = b
    else
      b.option = nil
      b:Hide()
    end
  end
  self.keyLabel:ClearAllPoints()
  self.keyLabel:SetPoint("TOP", 0, -START_KEYS)
  for i, b in ipairs(self.keyButtons) do
    local o = keys[i]
    if o then
      b:ClearAllPoints()
      b:SetPoint("TOP", self.panel, "TOP", (i - (#keys + 1) / 2) * 56, -START_KEYS - 26)
      b.option = o
      b.label:SetText(o.label)
      b.selected = o.selected and true or false
      b.slot.icon:SetDesaturated(o.disabled and true or false)
      b.slot.icon:SetVertexColor(o.disabled and 0.55 or 1, o.disabled and 0.55 or 1, o.disabled and 0.55 or 1, 1)
      b.slot.hot:SetAlpha(b.selected and 1 or 0)
      local lc = o.disabled and C.textDim or C.text
      b.label:SetTextColor(lc[1], lc[2], lc[3])
      W.setSize(b.label, o.selected and 18 or 16)
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
      b:SetPoint("TOP", self.panel, "TOP", (i - (#aff + 1) / 2) * 36, -START_KEYS - 90)
      b:SetItem("affix", id)
      b:Show()
    else
      b:Hide()
    end
  end
  -- sous le panneau : la campagne de la classe (zone la plus loin, boss battus), puis la dernière expédition
  local note = step.campaign or ""
  if step.text and step.text ~= "" then note = note .. (note ~= "" and "\n" or "") .. step.text end
  self.note:SetText(note)
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

---------------------------------------------------------------------------
-- Rencontre (et bibelot de classe) : bulle, personnage, plaques de réponses
---------------------------------------------------------------------------

local Choice = { kinds = { "choice", "startRelic", "event" } }
UI.register("choice", Choice)

-- couleur du titre d'une rencontre rare (or sombre) ou d'histoire (violet sombre), sur le parchemin
local RARITY_EDGE = { rare = Art.hex("#7a5200"), story = Art.hex("#55237d") }

function Choice:Build(f)
  self.hero = heroFigure(f)
  self.npc = Scene.figure(f, 170, 200)
  at(self.npc, f, 765, 146, 170, 200)
  self.npc:EnableMouse(false)
  -- nom du PNJ : au-dessus de sa tête, sur l'étage d'interface du personnage (au-dessus des modèles)
  self.speaker = Scene.setName(self.npc, "")
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
  -- personnage : apparaît quand son modèle est chargé (médaillon si aucun candidat ne charge) ; le
  -- texte et les réponses ne l'attendent pas
  local npcShown = step.kind == "event" and Scene.npcFigure(self.npc, step.npc) or false
  if not npcShown then Scene.npcFigure(self.npc, nil) end
  if step.kind == "event" then
    -- combats que les réponses peuvent lancer : leurs ennemis se chargent pendant la lecture
    local exp = Controller.exp()
    local ev = exp and exp.event and exp.event.id and ns.Events[exp.event.id]
    if ev then Scene.preload(Scene.nextNeeds(nil, Scene.eventFightNeeds(ev, exp))) end
  end
  UI.setStage({ scene = step.scene or Controller.scene(), board = true })
  Scene.playerFigure(self.hero)
  Scene.setName(self.npc, step.kind == "event" and (step.speaker or "") or "")
  local edge = RARITY_EDGE[step.rarity or ""]
  self.bubble:SetWidth(npcShown and 440 or 480)
  self.bubble:Set(step.title, step.text, edge)
  at(self.bubble, self.frame, npcShown and 297 or 277, 62)
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

---------------------------------------------------------------------------
-- Feu de camp : un feu, un couchage (repos), un grimoire (améliorer)
---------------------------------------------------------------------------

local Camp = { kinds = { "campfire" } }
UI.register("campfire", Camp)

-- Feu : centre x, ligne des pieds, taille du cadre du modèle. 140 de large : le halo doré de survol du
-- couchage et du grimoire (1,55 × 74) s'arrête juste avant (x 444 et 599).
local FIRE_X, FIRE_FEET, FIRE_W, FIRE_H = 517, 346, 140, 130

function Camp:Build(f)
  self.hero = heroFigure(f)
  -- Le feu : modèle 3D d'un feu de camp du jeu (Art.campfire, essais et repli : Scene.campfire), posé
  -- au sol sur la ligne des pieds du héros (y 346), entre le couchage et le grimoire, lueur chaude
  -- dessous. 140 × 130 : environ les deux tiers de la hauteur du héros, flammes comprises.
  self.fire = Scene.campfire(f, FIRE_W, FIRE_H)
  at(self.fire, f, FIRE_X - FIRE_W / 2, FIRE_FEET - FIRE_H, FIRE_W, FIRE_H)

  -- couchage et grimoire : médaillons au sol ; leurs plaques sur le plateau (planche ecran_feu.jpg)
  self.rest = groundObject(f, 74, "round")
  at(self.rest, f, 387 - 37, 347 - 37, 74, 74)
  W.setIcon(self.rest.icon, Art.ui.bedroll, "ui:bedroll")
  self.rest:SetScript("OnClick", function(b) chooseOption(b.option) end)
  self.book = groundObject(f, 74, "round")
  at(self.book, f, 657 - 37, 347 - 37, 74, 74)
  W.setIcon(self.book.icon, Art.ui.grimoire, "ui:grimoire")
  self.book:SetScript("OnClick", function(b) chooseOption(b.option) end)
  -- couchage et grimoire au-dessus du feu (modèle et médaillon) : rien d'interface sous un modèle
  for _, obj in ipairs({ self.rest, self.book }) do obj:SetFrameLevel(self.fire.fallback:GetFrameLevel() + 1) end
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
  self.leave = W.button(f, "Back on the road", 210, 44, nil, "red", 15)
  at(self.leave, f, 800, 497, 210, 44)
  self.leave:SetScript("OnClick", function(b) chooseOption(b.option) end)
  -- actions de feu de camp des zones (« campAction:<id> », ns.ZoneRules[zone].campfire) : boutons
  -- au-dessus de « Back on the road », texte et raison en infobulle
  self.extra = {}
  for k = 1, 2 do
    local b = W.button(f, "", 210, 44, nil, "gold", 15)
    at(b, f, 800, 497 - 52 * k, 210, 44)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    W.tooltip(b, function(tt, btn)
      local o = btn.option
      if not o then return end
      tt:AddLine(o.label or "", 1, 0.82, 0)
      if o.text then tt:AddLine(o.text, 1, 1, 1, true) end
      if o.disabled and o.reason then tt:AddLine(o.reason, 1, 0.3, 0.3, true) end
    end, "ANCHOR_LEFT")
    b:Hide()
    self.extra[k] = b
  end
  self.optionButtons = {}
end

function Camp:Show(step)
  self.step = step
  UI.setStage({ scene = "night", board = true })
  Scene.playerFigure(self.hero)
  Scene.showCampfire(self.fire)
  self.pile:Sync()
  self.optionButtons = {}
  local nExtra = 0
  for _, b in ipairs(self.extra) do b.option = nil b:Hide() end
  for _, o in ipairs(step.options) do
    if tostring(o.id):match("^campAction:") and nExtra < #self.extra then
      nExtra = nExtra + 1
      local b = self.extra[nExtra]
      b.option = o
      b:SetText(o.label or "")
      if b.SetActive then b:SetActive(not o.disabled) end
      b:Show()
      self.optionButtons[o.id] = b
    end
    if o.id == "rest" then
      self.rest.option = o
      local heal = (o.text or ""):match("(%d+)")
      self.rest.info = { title = o.label, text = o.text, reason = o.disabled and o.reason or nil }
      self.rest.active = not o.disabled
      self.rest:SetAlpha(o.disabled and 0.5 or 1)
      at(self.restPlaque, self.frame, 385 - 120, 469)
      self.restPlaque:SetOption({ id = o.id, label = o.label, text = heal and ("+" .. heal .. " HP") or o.text,
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
      self.bookPlaque:SetOption({ id = o.id, label = "Train", text = "Upgrade a card",
        disabled = o.disabled, reason = o.reason }, 240, 104)
      self.bookPlaque.option = o
      self.optionButtons[o.id] = self.book
    elseif o.id == "leave" then
      self.leave.option = o
      self.optionButtons[o.id] = self.leave
    end
  end
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
-- choix « Epic » : titre au-dessus des languettes de coût, consigne décalée à gauche du bouton « Skip »
local REWARD_EPIC_TITLE_Y, REWARD_HINT_X, REWARD_HINT_EPIC_X = 98, 552, 470
-- « Skip » : à gauche de « Back on the road »
local REWARD_SKIP_X, REWARD_SKIP_Y = 810 - 14 - 150, 497

function Reward:Build(f)
  self.hero = heroFigure(f)
  self.bubble = bubble(f)
  self.bubble:SetWidth(480)
  at(self.bubble, f, 277, 44)
  self.cards = {}
  for i = 1, 4 do
    local c = W.card(f)
    c:SetScript("OnClick", function(card) Reward:Pick(card) end)
    W.setLift(c, W.CARD_LIFT / REWARD_SCALE) -- carte lisible : levée et halo au survol
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
  self.chest = groundObject(f, 110, "round")
  at(self.chest, f, 462, 195, 110, 110)
  W.setIcon(self.chest.icon, Art.ui.chest, "ui:chest")
  self.chest:SetScript("OnClick", function() Reward:OpenChest() end)
  self.loot = CreateFrame("Frame", nil, f) -- compatibilité harnais : butin affiché
  self.loot:SetSize(1, 1)
  self.pile = deckPile(f)
  self.hint = W.label(f, "bold", 15, C.textSoft)
  self.hint:SetPoint("CENTER", f, "TOPLEFT", 552, -519)
  self.hint:SetText("Choose one card, or none.")
  self.leave = W.button(f, "Back on the road", 206, 50, nil, "gold", 18)
  at(self.leave, f, 913 - 103, 519 - 25, 206, 50)
  self.leave:SetScript("OnClick", function() Reward:Leave() end)
  -- choix « Epic » (épique tombée sur un élite) : titre violet au-dessus des cartes, « Skip » à gauche du départ
  self.epicTitle = W.label(f, "heavy", 20, W.EPIC_TEXT, "OVERLAY")
  self.epicTitle:SetPoint("CENTER", f, "TOPLEFT", 552, -REWARD_EPIC_TITLE_Y)
  self.epicTitle:SetText("Epic card")
  self.epicTitle:Hide()
  self.skip = W.button(f, "Skip", 150, 44, nil, "red", 15)
  at(self.skip, f, REWARD_SKIP_X, REWARD_SKIP_Y, 150, 44)
  self.skip:SetScript("OnClick", function(b) chooseOption(b.option) end)
  self.skip:Hide()
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
    self.chest.info = { title = "Chest" }
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
  self.leave.option = nil
  self.leave:Hide()
  -- choix « Epic » de une ou deux cartes : centré sous son titre
  local nCards = 0
  for _, o in ipairs(step.options) do if o.card then nCards = nCards + 1 end end
  for _, o in ipairs(step.options) do
    if o.card then
      k = k + 1
      self.cardOptions[k] = o
      local card = self.cards[k]
      if card and not closed then
        card.option, card.slot = o, k
        card.cx = REWARD_CARDS[k] or (407 + (k - 1) * 145)
        if step.epicMode and nCards < 3 then card.cx = REWARD_CARDS[2] + (k - (nCards + 1) / 2) * 145 end
        card.cy = REWARD_TOP + W.CARD_H * REWARD_SCALE / 2
        card:SetCard(o.card.id, o.card.up, { playable = not o.disabled, reason = o.disabled and o.reason or nil })
        self:PlaceCard(card)
        card:SetAlpha(1)
        card:Show()
        self.optionButtons[o.id] = card
      end
    elseif o.id == "takePotion" then
      self.optionButtons[o.id] = self.flask
    elseif o.id == "skipEpic" then
      self.skip.option = o
      self.optionButtons[o.id] = self.skip
    elseif o.id == "leave" then
      self.leave.option = o
      self.leave:Show()
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
  self.goldBag.info = r2.goldGained and { title = "Purse", text = "+" .. r2.goldGained .. "g" } or nil
  local anyCard = false
  for _, o in ipairs(step.options) do if o.card then anyCard = true end end
  if anyCard and not closed then self.hint:Show() else self.hint:Hide() end
  -- choix « Epic » (épique tombée sur un élite) : consigne, titre violet, « Skip » à gauche du départ
  local epic = step.epicMode and not closed
  local hint = "Choose one card, or none."
  if epic then
    hint = (exp and ns.Expedition.epicIndex(exp)) and "Replace your epic card, or skip it."
      or "Take this epic card, or skip it."
  end
  self.hint:SetText(hint)
  self.hint:ClearAllPoints()
  self.hint:SetPoint("CENTER", self.frame, "TOPLEFT", epic and REWARD_HINT_EPIC_X or REWARD_HINT_X, -519)
  if epic then self.epicTitle:Show() self.skip:Show() else self.epicTitle:Hide() self.skip:Hide() end
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
      hint = pendingPotion and "Potions full: right-click a potion to discard it." or nil }
    W.setIcon(self.flask.icon, Art.potion(r2.potion), "potion:" .. r2.potion)
    self.flask.icon:SetDesaturated(pendingPotion and true or false)
    self.flask:SetTag(pendingPotion and "No room" or nil, C.badText, false, true)
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
  if o.disabled then UI.flash(o.reason or "Unavailable.") return end
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
      if not silent then UI.flash(o and o.reason or "Potion slots full.") end
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
  -- en vol, l'objet passe sur la couche du dessus (au-dessus de la barre de titre et du bandeau, rognée
  -- au contenu) ; il reste ancré à l'écran (self.frame couvre le contenu) : coordonnées inchangées
  if obj.landHome then obj.landHome() end
  obj.landHome = W.lift(obj, UI.overlay, UI.overlay:GetFrameLevel() + 20)
  W.tween(0.45, function(t)
    obj:ClearAllPoints()
    obj:SetPoint("CENTER", self.frame, "TOPLEFT", bx + (tx - bx) * t, -(by + (ty - by) * t - 60 * 4 * t * (1 - t)))
    obj:SetAlpha(1 - 0.6 * t)
  end, function()
    obj:Hide()
    if obj.landHome then obj.landHome() obj.landHome = nil end
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
  if o.disabled then UI.flash(o.reason or "Unavailable.") return end
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

---------------------------------------------------------------------------
-- Grille du deck : amélioration, retrait, sélection de rencontre
---------------------------------------------------------------------------

local Deck = { kinds = { "deck", "select" } }
UI.register("deck", Deck)

local PER_PAGE, PER_ROW, GRID_SCALE = 16, 8, 0.75
local GRID_TOP, GRID_GAPY = 100, 28 -- haut du corps de la 1re rangée ; écart (languette et plaque du bas)

function Deck:Build(f)
  local panel = W.dialog(f, "", 16)
  at(panel, f, 16, 58, 1002, 358)
  self.panel = panel
  self.title = panel.title
  self.cards = {}
  for i = 1, PER_PAGE do
    local c = W.card(f)
    c:SetFrameLevel(panel:GetFrameLevel() + 5)
    c:SetScript("OnClick", function(card) chooseOption(card.option) end)
    -- survol : halo et aperçu à taille réelle (petite carte, W.cardPreviewShow) + aperçu de l'amélioration
    local enter, leave = c.onEnterExtra, c.onLeaveExtra
    c.onEnterExtra = function(card) enter(card) Deck:Preview(card) end
    c.onLeaveExtra = function(card) leave(card) Deck:Preview(card) end
    c:Hide()
    self.cards[i] = c
  end
  -- Flèches de page : posées sur le panneau (qui capte la souris), donc à un niveau explicitement
  -- au-dessus de lui et des cartes levées (panneau + 5 + case + 40) ; au même niveau que le panneau (leur
  -- niveau par défaut), le client ne garantissait pas qui recevait le clic : « > » restait sans effet.
  local arrowLevel = panel:GetFrameLevel() + 5 + PER_PAGE + 50
  self.prev = W.roundButton(f, "<", 30, 1, nil, function() self.page = self.page - 1 self:Layout() end)
  at(self.prev, f, 26, 220, 30, 30)
  W.setLevel(self.prev, arrowLevel)
  self.next = W.roundButton(f, ">", 30, 1, nil, function() self.page = self.page + 1 self:Layout() end)
  at(self.next, f, 978, 220, 30, 30)
  W.setLevel(self.next, arrowLevel)
  self.pile = deckPile(f)
  self.buttons = {}
  for i = 1, 2 do
    local b = W.button(f, "", 206, i == 1 and 50 or 44, nil, i == 1 and "gold" or "red", i == 1 and 18 or 15)
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
  self.panel:SetTitle(step.title or "")
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

-- Service (retrait de carte) : bouton rouge du jeu, icône dans une case à gauche, libellé doré ;
-- étiquette de prix dessous. Survol : liseré d'or, bouton éclairci, libellé blanchi, sans bouger.
local function serviceButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(230, 46)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  b.base = W.threeSlice(face, "btn_red", "BACKGROUND", -6)
  b.hot = W.hoverLayer(W.threeSlice(face, "btn_goldred", "BACKGROUND", -5))
  b.hot:SetAlpha(0)
  b.light = W.lightLayer(W.threeSlice(face, "btn_goldred", "BACKGROUND", -4))
  b.iconBox = CreateFrame("Frame", nil, face)
  b.iconBox:SetSize(30, 30)
  b.iconBox:SetPoint("CENTER", face, "LEFT", 34, 0)
  b.slot = W.slotOn(b.iconBox, 30, 0, face)
  b.icon = b.slot.icon
  W.setIcon(b.icon, Art.ui.remove, "ui:remove")
  b.label = W.label(face, "bold", 15, C.wowGold)
  b.label:SetPoint("LEFT", face, "LEFT", 58, 0.5)
  b.labelColor = C.wowGold
  b.tag = tagPill(b)
  b.tag:SetPoint("TOP", b, "BOTTOM", 0, -6)
  W.hoverable(b, { paint = function(self, h)
    if self.option and self.option.disabled then h = 0 end
    W.buttonPaint(self, h)
  end })
  W.pressable(b)
  b:hoverPaint(0)
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
    W.setLift(c, W.CARD_LIFT / SHOP_SCALE) -- carte lisible : levée et halo au survol
    c:Hide()
    self.cards[i] = c
  end
  self.sections = {}
  for i, t in ipairs({ { "Relics", 57 }, { "Potions", 417 }, { "Service", 757 } }) do
    local l = W.label(f, "bold", 14, C.wowGold)
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
  at(self.remove, f, 869 - 115, 369 - 23, 230, 46)
  self.remove:Hide()
  self.pile = deckPile(f)
  self.coin = f:CreateTexture(nil, "ARTWORK")
  self.coin:SetSize(34, 34)
  self.coin:SetPoint("CENTER", f, "TOPLEFT", 467, -519)
  W.roundMask(f, self.coin)
  W.setIcon(self.coin, Art.ui.gold, "ui:gold")
  self.gold = W.label(f, "heavy", 30, C.goldText)
  self.gold:SetPoint("LEFT", f, "TOPLEFT", 491, -517)
  self.leave = W.button(f, "Back on the road", 206, 50, nil, "gold", 18)
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
        if o.sold then b:SetTag("Sold", { 0.6, 0.6, 0.6 })
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

---------------------------------------------------------------------------
-- Carte de parcours : façon carte de vol (direction C) dans la fenêtre au cadre métal
---------------------------------------------------------------------------
-- Parchemin (UI-Frame-Neutral-CardParchmentWider) ; étapes : icône ronde dans le petit anneau doré
-- (élite : marqueur de vignette d'élite) ; accessibles en couleur, franchies et hors de portée grisées
-- (hors de portée aussi estompées) ; position : botte ailée de la carte de vol au-dessus de l'étape ;
-- boss : portrait dans le grand anneau, dragon d'or, ruban à son nom ; liens : traits de trajet de taxi
-- (chemin parcouru et départs possibles pleins, le reste estompé). Aucune légende ; infobulle = nom du type.
local Map = { kinds = { "map" } }
UI.register("map", Map)

local MAP_X0, MAP_X1, BOSS_X = 110, 790, 910
local MAP_Y0, MAP_Y1 = 150, 450
local NODE = 44            -- étape (élite : 54 ; boss : 78)

function Map:Build(f)
  local sheet = W.parchment(f, "map")
  at(sheet, f, 16, 42, 1002, 562)
  sheet:EnableMouse(false)
  self.parch = sheet
  self.canvas = CreateFrame("Frame", nil, f)
  self.canvas:SetAllPoints()
  self.canvas:SetFrameLevel(sheet:GetFrameLevel() + 2)
  self.nodes = {}
  self.lines = {}
  self.optionButtons = {}
end

local function nodeButton(self, i)
  local b = CreateFrame("Button", nil, self.canvas)
  b:SetSize(NODE, NODE)
  b:SetFrameLevel(self.canvas:GetFrameLevel() + 5)
  local face = W.face(b)
  -- halo (accessibles) : lueur douce, fixe
  b.halo = W.skin(face, "glow_round", "BACKGROUND", 0)
  b.halo:SetPoint("CENTER")
  b.halo:Hide()
  b.icon = W.noSnap(face:CreateTexture(nil, "ARTWORK", nil, 0))
  W.roundMask(face, b.icon)
  b.ring = W.wow(face, "ring_small", "ARTWORK", 1)
  b.ring:SetPoint("CENTER")
  b.big = W.wow(face, "ring_large", "ARTWORK", 1)
  b.big:SetPoint("CENTER")
  b.big:Hide()
  b.elite = W.wow(face, "elite_node", "ARTWORK", 2)
  b.elite:SetPoint("CENTER")
  b.elite:Hide()
  b.dragon = W.wow(face, "elite_dragon", "ARTWORK", 3)
  b.dragon:Hide()
  b.boot = W.wow(face, "boot", "OVERLAY", 0)
  b.boot:SetSize(40, 40)
  b.boot:SetPoint("BOTTOM", face, "TOP", 4, -12)
  b.boot:Hide()
  b.ribbon = W.wow(face, "ribbon", "ARTWORK", 4)
  b.ribbon:SetSize(186, 56)
  b.ribbon:SetPoint("TOP", face, "BOTTOM", 0, 12)
  b.ribbon:Hide()
  b.bossName = W.label(face, "bold", 14, C.parchInk, "OVERLAY", false)
  b.bossName:SetPoint("CENTER", b.ribbon, "CENTER", 0, 2)
  -- surbrillance : lueur dorée (créée d'avance, éteinte), plus vive sur une étape accessible
  b.hl = W.hoverLayer(W.skin(face, "glow_round", "BACKGROUND", 1))
  b.hl:SetPoint("CENTER")
  b.hl:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
  b.hl:SetAlpha(0)
  -- survol : la lueur s'allume, l'étape ne grossit pas (le nom du boss reste stable)
  W.hoverable(b, { paint = function(self, h)
    local st = self.node and self.node.state
    self.hl:SetAlpha(h * ((st == "available" or (self.node and self.node.kind == "boss")) and 0.8 or 0.35))
  end })
  b:SetScript("OnClick", function(btn)
    local node = btn.node
    if node and node.state == "available" then W.sound("click") UI.choose(node.id)
    elseif node then UI.flash("Stage out of reach.") end
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

-- step : étape « map » (bossName ; zone : icône du boss de la zone, Art.ui.mapBoss, repli Art.ui.map.boss).
local function paintNode(b, node, step)
  local st, kind = node.state, node.kind
  local bossName = step.bossName
  local boss = kind == "boss"
  local elite = kind == "elite"
  local cur = st == "current"
  local size = boss and 78 or (elite and 54 or NODE)
  b:SetSize(size, size)
  b.hl:SetSize(size * 1.6, size * 1.6)
  b.icon:ClearAllPoints()
  local inset = boss and size * 0.12 or size * 0.16
  b.icon:SetPoint("TOPLEFT", inset, -inset)
  b.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
  local zoneBoss = boss and step.zone and Art.ui.mapBoss and Art.ui.mapBoss[step.zone]
  W.setIcon(b.icon, zoneBoss or Art.ui.map[kind] or Art.ui.map.event, "map:" .. tostring(kind))
  b.ring:SetSize(size * 1.04, size * 1.04)
  b.big:SetSize(size, size)
  b.elite:SetSize(size, size * W.Wow.pieces.elite_node.ph / W.Wow.pieces.elite_node.pw)
  b.ring:SetShown(not boss and not elite)
  b.big:SetShown(boss)
  b.elite:SetShown(elite)
  b.icon:SetShown(not elite)
  -- état : en couleur (accessible, position, boss), grisé (franchie), grisé et estompé (hors de portée)
  local live = cur or st == "available" or boss
  local grey = not live
  for _, t in ipairs({ b.icon, b.ring, b.elite }) do
    t:SetDesaturated(grey)
    t:SetAlpha((st == "done" or live) and 1 or 0.55)
  end
  if st == "done" then b.icon:SetVertexColor(0.8, 0.8, 0.8, 1) else b.icon:SetVertexColor(1, 1, 1, 1) end
  -- halo léger des étapes accessibles
  if st == "available" then
    b.halo:SetSize(size * 1.7, size * 1.7)
    b.halo:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
    b.halo:SetAlpha(0.55)
    b.halo:Show()
  else
    b.halo:Hide()
  end
  if cur then b.boot:Show() else b.boot:Hide() end
  if boss then
    b.dragon:SetSize(54, 54)
    b.dragon:ClearAllPoints()
    b.dragon:SetPoint("CENTER", b.face, "TOPRIGHT", -6, -8)
    b.dragon:Show()
    b.ribbon:Show()
    b.bossName:SetText(bossName or "")
  else
    b.dragon:Hide()
    b.ribbon:Hide()
    b.bossName:SetText("")
  end
end

-- Trait de trajet de taxi (UI-Taxi-Line) entre deux points : texture couchée, étirée et pivotée (pool).
function Map:Line(k, x1, y1, x2, y2, thick, alpha)
  local t = self.lines[k]
  if not t then
    t = W.wow(self.canvas, "taxi_line", "BACKGROUND", 0)
    self.lines[k] = t
  end
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  t:ClearAllPoints()
  t:SetSize(len, thick)
  t:SetPoint("CENTER", self.frame, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
  t:SetRotation(math.atan2(-dy, dx))
  t:SetAlpha(alpha)
  t:Show()
end

function Map:Show(step)
  self.step = step
  UI.setStage({ scene = false, board = false })
  -- étapes accessibles connues : préchargement des modèles de la prochaine scène possible
  Scene.preload(Scene.nextNeeds(Controller.exp()))
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
      paintNode(b, node, step)
      b:ClearAllPoints()
      b:SetPoint("CENTER", self.frame, "TOPLEFT", x, -y)
      b:Show()
      self.optionButtons[node.id] = b
    elseif b then
      b.node = nil
      b:Hide()
    end
  end
  -- Traits de trajet : chemin parcouru et départs possibles pleins, le reste estompé.
  local k = 0
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
        local nextUp = s1 == "current" and s2 == "available" or (s1 == nil and s2 == "available")
        k = k + 1
        if walked then self:Line(k, p1[1], p1[2], p2[1], p2[2], 27, 1)
        elseif nextUp then self:Line(k, p1[1], p1[2], p2[1], p2[2], 27, 0.95)
        else self:Line(k, p1[1], p1[2], p2[1], p2[2], 22, 0.55) end
      end
    end
  end
  for i = k + 1, #self.lines do self.lines[i]:Hide() end
  self.options = step.options or {}
  for _, o in ipairs(self.options) do
    if not self.optionButtons[o.id] then self.optionButtons[o.id] = byId[o.id] end
  end
end

---------------------------------------------------------------------------
-- Entre deux zones : le décor de la zone suivante, le héros, un panneau (nom de la zone, sa place dans la
-- campagne en pastilles de carte de vol, soin du passage, déblocages du boss vaincu), « Continue »
---------------------------------------------------------------------------
-- Pastilles : zones franchies vertes, zone suivante jaune (plus grande), à venir grises (mêmes pièces que le
-- bandeau). Abandon : bouton Menu du bandeau, comme ailleurs.

local Transit = { kinds = { "transit" } }
UI.register("transit", Transit)

local TR_X, TR_Y, TR_W, TR_H = 280, 70, 560, 250
local TR_PIP, TR_PIP_CUR, TR_PIP_DX = 16, 20, 34
UI.TR = { x = TR_X, y = TR_Y, w = TR_W, h = TR_H }

function Transit:Build(f)
  self.hero = heroFigure(f)
  local panel = W.dialog(f, nil)
  at(panel, f, TR_X, TR_Y, TR_W, TR_H)
  self.panel = panel
  self.title = W.label(panel, "heavy", 28, C.wowGold)
  self.title:SetPoint("TOP", 0, -24)
  self.pips = {}
  for i = 1, #ns.Zone.ORDER do
    local d = W.wow(panel, "pip_gray", "ARTWORK", 1)
    d:Hide()
    self.pips[i] = d
  end
  self.text = W.label(panel, "bold", 14, C.textSoft)
  self.text:SetPoint("TOP", self.title, "BOTTOM", 0, -52)
  self.text:SetWidth(TR_W - 60)
  self.text:SetJustifyH("CENTER")
  self.text:SetWordWrap(true)
  self.go = W.button(f, "Continue", 230, 50, nil, "gold", 18)
  at(self.go, f, 790, 494, 230, 50)
  self.go:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  self.optionButtons = {}
end

function Transit:Show(step)
  self.step = step
  -- décor de la zone suivante (la zone de l'expédition est déjà la nouvelle : Controller.zoneScene)
  UI.setStage({ scene = Controller.scene(), board = true, veil = 0.2 })
  Scene.playerFigure(self.hero)
  self.title:SetText(step.title or "")
  local n, total = step.pos or 1, step.count or #self.pips
  for i, d in ipairs(self.pips) do
    if i <= total then
      local size = i == n and TR_PIP_CUR or TR_PIP
      W.setWow(d, i < n and "pip_green" or (i == n and "pip_yellow" or "pip_gray"))
      d:SetSize(size, size)
      d:ClearAllPoints()
      d:SetPoint("CENTER", self.panel, "TOP", (i - (total + 1) / 2) * TR_PIP_DX, -82)
      d:Show()
    else
      d:Hide()
    end
  end
  self.text:SetText(inkText(step.text))
  self.optionButtons = {}
  for _, o in ipairs(step.options or {}) do
    if o.id == "continue" then
      self.go.option = o
      self.go:SetText(o.label or "Continue")
      self.optionButtons[o.id] = self.go
    end
  end
end

---------------------------------------------------------------------------
-- Bilan et journal : panneau d'ardoise, barre de niveau de la classe, journal
---------------------------------------------------------------------------
-- Bilan avec montée de niveau : sous les barres, ce qui vient d'être débloqué, révélé tel quel (vraies
-- cartes à petite échelle, agrandies au survol ; cases des bibelots), sans autre texte. Le panneau monte
-- et grandit pour les accueillir (jamais sur les boutons du bas).

local Progress = { kinds = { "end", "meta" } }
UI.register("progress", Progress)

-- Panneau : PG_X, PG_Y, PG_W × PG_H au moins ; monté à PG_UP_Y avec des déblocages, son bas jamais sous
-- PG_BOTTOM (boutons du bas à y 494). Barres sous le texte (au moins à PG_BARS de son haut, la méta à
-- PG_BARS_META), rangée des déblocages sous les barres.
local PG_X, PG_W, PG_Y, PG_H, PG_UP_Y, PG_BOTTOM = 167, 700, 64, 352, 40, 488
local PG_BARS, PG_BARS_META, PG_BAR_DY = 170, 110, 54
local PG_SCALE, PG_PITCH, PG_RELIC, PG_RELIC_DX = 0.5, 72, 44, 58
local PG_MAX_CARDS, PG_MAX_RELICS = 9, 3
-- épique débloquée au bilan : plus grande, à gauche de la rangée, libellé « New epic card » au-dessus
local PG_EPIC_SCALE, PG_EPIC_GAP, PG_EPIC_LABEL = 0.72, 40, 20
UI.PG = { scale = PG_SCALE, maxCards = PG_MAX_CARDS, maxRelics = PG_MAX_RELICS, bottom = PG_BOTTOM }

function Progress:Build(f)
  local panel = W.dialog(f, nil)
  at(panel, f, 167, 64, 700, 352)
  self.panel = panel
  self.title = W.label(panel, "heavy", 28, C.wowGold)
  self.title:SetPoint("TOP", 0, -20)
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
    local b = W.button(f, "", 220, i == 1 and 50 or 44, nil, i == 1 and "gold" or "red", i == 1 and 18 or 15)
    b:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
    b:Hide()
    self.buttons[i] = b
  end
  -- déblocages révélés (bilan avec montée de niveau)
  self.newCards, self.newRelics = {}, {}
  for i = 1, PG_MAX_CARDS do
    local c = W.card(f)
    c:SetFrameLevel(panel:GetFrameLevel() + 5)
    c:Hide()
    self.newCards[i] = c
  end
  for i = 1, PG_MAX_RELICS do
    local b = W.iconButton(f, PG_RELIC, "square")
    b:SetFrameLevel(panel:GetFrameLevel() + 5)
    b:Hide()
    self.newRelics[i] = b
  end
  -- carte épique débloquée (première victoire de la classe dans la zone) : à part, plus grande, libellé violet
  self.epicCard = W.card(f)
  self.epicCard:SetFrameLevel(panel:GetFrameLevel() + 5)
  self.epicCard:Hide()
  self.epicLabel = W.label(panel, "heavy", 13, W.EPIC_TEXT, "OVERLAY")
  self.epicLabel:SetText("New epic card")
  self.epicLabel:Hide()
  self.optionButtons = {}
end

-- Rangée des déblocages, centrée sous les barres (centre à rowY, coordonnées de la scène) ; cachée sans
-- montée de niveau.
function Progress:ShowUnlocked(u, rowY)
  local cards = u and u.cards or {}
  local relics = u and u.relics or {}
  local nc, nr = math.min(#cards, PG_MAX_CARDS), math.min(#relics, PG_MAX_RELICS)
  local cw = W.CARD_W * PG_SCALE
  local width = (nc > 0 and ((nc - 1) * PG_PITCH + cw) or 0) + (nr > 0 and ((nc > 0 and 24 or 0) + (nr - 1) * PG_RELIC_DX + PG_RELIC) or 0)
  -- épique : d'abord, à PG_EPIC_SCALE, séparée du reste par PG_EPIC_GAP, libellé au-dessus
  local ew = W.CARD_W * PG_EPIC_SCALE
  local epic = u and u.epic
  if epic then width = width + ew + (width > 0 and PG_EPIC_GAP or 0) end
  local x = PG_X + PG_W / 2 - width / 2
  local lv = self.panel:GetFrameLevel()
  if epic then
    local ex = x + ew / 2
    self.epicCard:SetCard(epic, false, {})
    W.placeCard(self.epicCard, self.frame, ex, rowY, PG_EPIC_SCALE, lv + 5, lv + 60)
    self.epicCard:Show()
    self.epicLabel:ClearAllPoints()
    self.epicLabel:SetPoint("BOTTOM", self.frame, "TOPLEFT", ex, -(rowY - W.CARD_H * PG_EPIC_SCALE / 2 - 22))
    self.epicLabel:Show()
    x = x + ew + (width > ew and PG_EPIC_GAP or 0)
  else
    W.hideCard(self.epicCard)
    self.epicLabel:Hide()
  end
  for i, c in ipairs(self.newCards) do
    if i <= nc then
      c:SetCard(cards[i], false, {})
      W.placeCard(c, self.frame, x + cw / 2 + (i - 1) * PG_PITCH, rowY, PG_SCALE, lv + 5 + i, lv + 60)
      c:Show()
    else
      W.hideCard(c)
    end
  end
  x = x + (nc > 0 and ((nc - 1) * PG_PITCH + cw + 24) or 0)
  for i, b in ipairs(self.newRelics) do
    if i <= nr then
      at(b, self.frame, x + (i - 1) * PG_RELIC_DX, rowY - PG_RELIC / 2, PG_RELIC, PG_RELIC)
      b:SetItem("relic", relics[i])
      b:Show()
    else
      b:Hide()
    end
  end
end

function Progress:OnHide()
  for _, c in ipairs(self.newCards) do W.hideCard(c) end
  W.hideCard(self.epicCard)
end

function Progress:Show(step)
  self.step = step
  UI.setStage({ scene = step.kind == "end" and Controller.scene() or "road", board = true, veil = 0.45 })
  local up = step.kind == "end" and step.unlocked ~= nil
  self.title:SetText(step.title or "")
  local tc = C.wowGold
  if step.kind == "end" then tc = step.won and C.healGreen or C.badText end
  self.title:SetTextColor(tc[1], tc[2], tc[3])
  self.text:SetText(inkText(step.text))
  local bars = step.bars or {}
  -- barres sous le texte (libellé de la barre au-dessus d'elle : 34 de marge)
  local textH = tonumber(self.text:GetStringHeight()) or 0
  local titleH = tonumber(self.title:GetStringHeight()) or 34
  local y0 = -max(step.kind == "end" and PG_BARS or PG_BARS_META, 20 + titleH + 10 + textH + 34)
  -- panneau : monté et agrandi pour la rangée des déblocages (centre sous la dernière barre et son détail)
  local panelY, panelH = PG_Y, PG_H
  local half = W.CARD_H * PG_SCALE / 2
  local epicUp = up and step.unlocked.epic
  if epicUp then half = W.CARD_H * PG_EPIC_SCALE / 2 end
  local rowRel = -y0 + (max(#bars, 1) - 1) * PG_BAR_DY + 58 + half + (epicUp and PG_EPIC_LABEL or 0)
  if up then
    panelY = PG_UP_Y
    panelH = min(PG_BOTTOM - PG_UP_Y, max(PG_H, rowRel + half + 20))
  else
    -- bilan à plusieurs déblocages : le panneau s'allonge vers le bas sous la dernière barre et le journal
    local need = -y0 + (max(#bars, 1) - 1) * PG_BAR_DY + 40 + 16 * #(step.journal or {}) + 16
    panelH = min(PG_BOTTOM - PG_Y, max(PG_H, need))
  end
  at(self.panel, self.frame, PG_X, panelY, PG_W, panelH)
  self:ShowUnlocked(up and step.unlocked or nil, panelY + rowRel)
  for i, b in ipairs(self.bars) do
    local data = bars[i]
    if data then
      b:ClearAllPoints()
      b:SetPoint("TOP", self.panel, "TOP", 0, y0 - (i - 1) * PG_BAR_DY)
      b:Set(data)
      b:Show()
    else
      b:Hide()
    end
  end
  local jy = y0 - #bars * PG_BAR_DY - 4
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

---------------------------------------------------------------------------
-- Progression d'une classe : niveau, expérience, 34 cartes (35 au Rogue) par voie, 6 bibelots
---------------------------------------------------------------------------
-- Une boîte DiamondMetal sur toute la scène. En-tête : icônes des classes (mêmes que l'accueil, la classe
-- affichée au halo d'or ; infobulle = nom et niveau), barre d'expérience (« Level 3 · 20 / 150 »),
-- onglet « Zones » / « Cards », « Log » et « Back ». Dessous, une rangée par voie (départ, puis les trois voies), les cartes
-- dans l'ordre de leur niveau ; les bibelots à droite des cartes de départ. Débloqué : la vraie carte (W.card)
-- ou la case du bibelot, avec son infobulle, agrandie au survol. Verrouillé : dos de carte assombri et
-- désaturé, ou case grisée au point d'interrogation ; l'infobulle ne dit que la condition (« Priest level 4 »).
-- Aucun texte permanent hors des noms de voies. Onglet « Zones » : une colonne par zone de la campagne (nom,
-- état, clés ouvertes et meilleure clé, carte de zone, bibelots de clé +1 / +3 / +5), mêmes règles de verrou
-- (« Win Westfall to unlock », « Win Westfall +3 to unlock »).

local ClassProgress = { kinds = { "classProgress" } }
UI.register("classProgress", ClassProgress)

-- Mise en page (coordonnées de la scène) : cartes à CP_SCALE, CP_PITCH entre deux centres, colonne des
-- voies à gauche (noms à partir de CP_LABEL_X, réduits pour tenir dans CP_LABEL_W), rangées de CP_ROW_H à
-- partir de CP_ROW_TOP ;
-- bibelots en cases de CP_RELIC, pas CP_RELIC_DX, à partir de CP_RELIC_X.
local CP_SCALE, CP_PITCH, CP_X0, CP_LABEL_X, CP_LABEL_W = 0.6, 84, 190, 18, 128
local CP_ROW_TOP, CP_ROW_H = 112, 122
local CP_RELIC, CP_RELIC_DX, CP_RELIC_X, CP_RELIC_LABEL_R = 46, 62, 612, 574
local CP_TAB, CP_TAB_DX, CP_TAB_X, CP_TAB_Y = 44, 56, 50, 76
-- 36 emplacements : 34 de la grille commune, plus les cartes hors grille (Rogue : Nightblade). Une rangée
-- de plus de CP_ROW_MAX cartes resserre son pas pour garder le même bord droit.
local CP_SLOTS, CP_ROWS, CP_ROW_MAX = 36, 4, 10
-- Onglet « Zones » : colonnes de CP_ZONE_DX à partir de CP_ZONE_TOP (nom, état, clés), carte de zone à
-- CP_ZONE_SCALE, bibelots de clé en cases de CP_ZONE_RELIC au pas CP_ZONE_RELIC_DX.
local CP_ZONE_DX, CP_ZONE_TOP, CP_ZONE_SCALE, CP_ZONE_RELIC, CP_ZONE_RELIC_DX = 140, 124, 0.85, 36, 40
UI.CP = { scale = CP_SCALE, pitch = CP_PITCH, x0 = CP_X0, rowTop = CP_ROW_TOP, rowH = CP_ROW_H,
  relic = CP_RELIC, relicDx = CP_RELIC_DX, relicX = CP_RELIC_X, zoneDx = CP_ZONE_DX, zoneTop = CP_ZONE_TOP,
  zoneScale = CP_ZONE_SCALE, zoneRelic = CP_ZONE_RELIC }

-- Infobulle d'un élément verrouillé : la condition seule.
local function fillLocked(tt, cond)
  if cond then tt:AddLine(cond, 1, 0.3, 0.3) end
end

-- Carte verrouillée : dos de carte du pack, assombri et désaturé, à la taille d'une carte ; rien d'autre.
local function lockedCard(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(W.CARD_W, W.CARD_H)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  b.isLock = true
  b.back = W.cardBack(face, W.CARD_H, "ARTWORK", 0)
  b.back:SetPoint("CENTER")
  b.back:SetDesaturated(true)
  b.back:SetVertexColor(0.42, 0.42, 0.42, 1)
  -- emplacement d'une carte épique (onglet Zones) : aura violette tenue, dos teinté de violet (SetEpic)
  b.epicGlow = W.skin(face, "card_glow", "BACKGROUND", -8)
  b.epicGlow:SetSize(W.CARD_W * 1.43, W.CARD_H * 1.31)
  b.epicGlow:SetPoint("CENTER")
  b.epicGlow:SetVertexColor(W.EPIC_COLOR[1], W.EPIC_COLOR[2], W.EPIC_COLOR[3], 1)
  b.epicGlow:SetAlpha(W.EPIC_GLOW_ALPHA * 0.8)
  b.epicGlow:Hide()
  b.tint = { 1, 1, 1 }
  b.SetEpic = function(self, on)
    self.epic = on and true or false
    self.tint = on and { 0.85, 0.55, 1 } or { 1, 1, 1 }
    if on then self.epicGlow:Show() else self.epicGlow:Hide() end
    self:hoverPaint(W.animValue(self, "hover"))
  end
  W.hoverable(b, { paint = function(self, h)
    local k = 0.42 + 0.12 * h
    local t = self.tint
    self.back:SetVertexColor(k * t[1], k * t[2], k * t[3], 1)
  end })
  W.tooltip(b, function(tt, self) fillLocked(tt, self.condition) end, "ANCHOR_RIGHT")
  b:Hide()
  return b
end

function ClassProgress:Build(f)
  local panel = W.dialog(f, nil)
  at(panel, f, 6, 40, 1022, 570)
  self.panel = panel
  local lv = panel:GetFrameLevel()
  -- onglets : icônes des classes
  self.tabs = {}
  -- barre d'expérience (W.repBar)
  self.bar = W.repBar(panel, 290)
  at(self.bar, f, 318, 72, 290, 14)
  -- onglet (« Zones » ou « Cards » : l'autre vue), journal, retour
  self.tabBtn = W.button(f, "Zones", 110, 44, nil, "red", 15)
  at(self.tabBtn, f, 622, 52, 110, 44)
  self.tabBtn:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  self.metaBtn = W.button(f, "Log", 110, 44, nil, "red", 15)
  at(self.metaBtn, f, 742, 52, 110, 44)
  self.metaBtn:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  self.back = W.button(f, "Back", 150, 48, nil, "gold", 18)
  at(self.back, f, 866, 50, 150, 48)
  self.back:SetScript("OnClick", function(btn) chooseOption(btn.option) end)
  for _, b in ipairs({ self.tabBtn, self.metaBtn, self.back }) do b:SetFrameLevel(lv + 4) end
  -- noms des voies (colonne de gauche) et titre des bibelots
  self.rowLabels = {}
  for i = 1, CP_ROWS do
    local l = W.label(panel, "bold", 14, C.wowGold, "OVERLAY")
    l:SetJustifyH("LEFT")
    l:SetWordWrap(false)
    self.rowLabels[i] = l
  end
  self.relicLabel = W.label(panel, "bold", 14, C.wowGold, "OVERLAY")
  self.relicLabel:SetJustifyH("RIGHT")
  -- cartes : une vraie carte et une silhouette par emplacement (l'une ou l'autre est montrée)
  self.cards, self.locks = {}, {}
  for i = 1, CP_SLOTS do
    local c = W.card(f)
    c:SetFrameLevel(lv + 5)
    c:Hide()
    self.cards[i] = c
    local k = lockedCard(f)
    k:SetFrameLevel(lv + 5)
    self.locks[i] = k
  end
  -- bibelots : case du jeu (débloqué : icône et infobulle du bibelot ; verrouillé : point d'interrogation grisé)
  self.relics = {}
  for i = 1, 6 do
    local b = W.iconButton(f, CP_RELIC, "square")
    b:SetFrameLevel(lv + 5)
    b:Hide()
    self.relics[i] = b
  end
  -- onglet « Zones » : une colonne par zone (nom, état, clés, carte de zone, bibelots de clé +1 / +3 / +5)
  self.zoneCols = {}
  for i = 1, #ns.Zone.ORDER do
    local col = {}
    col.name = W.label(panel, "bold", 14, C.wowGold, "OVERLAY")
    col.name:SetWordWrap(false)
    col.status = W.label(panel, "body", 11.5, C.text, "OVERLAY")
    col.status:SetWordWrap(false)
    col.keys = W.label(panel, "body", 11, C.textSoft, "OVERLAY")
    col.keys:SetWordWrap(false)
    col.card = W.card(f)
    col.card:SetFrameLevel(lv + 5)
    col.card:Hide()
    col.lock = lockedCard(f)
    col.lock:SetFrameLevel(lv + 5)
    col.relics, col.relicLabels = {}, {}
    for k = 1, #ns.Meta.KEY_RELIC_LEVELS do
      local b = W.iconButton(f, CP_ZONE_RELIC, "square")
      b:SetFrameLevel(lv + 5)
      b:Hide()
      col.relics[k] = b
      col.relicLabels[k] = W.label(panel, "bold", 11, C.textSoft, "OVERLAY")
    end
    self.zoneCols[i] = col
  end
  self.optionButtons = {}
end

-- Case de bibelot de l'écran de progression : débloqué (icône et infobulle du bibelot) ou verrouillé
-- (point d'interrogation grisé, infobulle = la condition seule).
local function paintRelicSlot(b, e)
  b.entry = e
  if e.unlocked then
    b:SetItem("relic", e.id)
    b.icon:SetVertexColor(1, 1, 1, 1)
  else
    b.info = { kind = "locked", condition = e.condition }
    W.setIcon(b.icon, Art.ui.locked, "ui:locked")
    b.icon:SetDesaturated(true)
    b.icon:SetVertexColor(0.45, 0.45, 0.45, 1)
    b.icon:Show()
    b.case.frame:SetVertexColor(0.5, 0.5, 0.5, 1)
  end
end

-- Vue « Zones » : colonnes de CP_ZONE_DX centrées dans le panneau ; carte de zone à CP_ZONE_SCALE.
function ClassProgress:ShowZones(zones, shown)
  local n = #ns.Zone.ORDER
  local x0 = 6 + (1022 - n * CP_ZONE_DX) / 2 + CP_ZONE_DX / 2
  local cardH = W.CARD_H * CP_ZONE_SCALE
  local cardCy = CP_ZONE_TOP + 80 + cardH / 2
  local relicY = CP_ZONE_TOP + 80 + cardH + 20
  local STATUS_COLOR = { won = C.healGreen, reached = C.text, ahead = C.textDim, later = C.textDim }
  for i, col in ipairs(self.zoneCols) do
    local z = shown and zones and zones[i]
    if z then
      local cx = x0 + (i - 1) * CP_ZONE_DX
      local function place(fs, y, text, size)
        fs:ClearAllPoints()
        fs:SetPoint("TOP", self.frame, "TOPLEFT", cx, -y)
        fs:SetWidth(CP_ZONE_DX - 8)
        fs:SetJustifyH("CENTER")
        local s = size
        while s > 9 and textWidth(fs, text, s) * W.TEXT_SAFE > CP_ZONE_DX - 8 do s = s - 0.5 end
        setLines(fs, { text }, s, CP_ZONE_DX - 8)
        fs:Show()
      end
      place(col.name, CP_ZONE_TOP, z.name, 14)
      place(col.status, CP_ZONE_TOP + 20, z.statusLabel or "", 11.5)
      local sc = STATUS_COLOR[z.status] or C.text
      col.status:SetTextColor(sc[1], sc[2], sc[3])
      -- meilleure clé à laquelle la classe a battu le boss de la zone (bibelots de clé +1, +3, +5)
      local keyText = ""
      if z.status == "won" and (z.bestKey or -1) >= 0 then keyText = "Best key +" .. z.bestKey end
      place(col.keys, CP_ZONE_TOP + 36, keyText, 11)
      local e = z.card
      col.card.entry, col.lock.entry = e, e
      if e.unlocked then
        W.hideCard(col.lock)
        col.lock:Hide()
        col.card:SetCard(e.id, false, {})
        col.card.cx, col.card.cy = cx, cardCy
        W.placeCard(col.card, self.frame, cx, cardCy, CP_ZONE_SCALE, self.panel:GetFrameLevel() + 45 + i,
          self.panel:GetFrameLevel() + 80)
        col.card:Show()
      else
        W.hideCard(col.card)
        col.lock.condition = e.condition
        col.lock:SetEpic(e.epic)
        W.placeCenter(col.lock, self.frame, cx, cardCy, CP_ZONE_SCALE)
        W.setLevel(col.lock, self.panel:GetFrameLevel() + 45 + i)
        col.lock:Show()
      end
      local nk = #z.keys
      for k, b in ipairs(col.relics) do
        local ke = z.keys[k]
        local lbl = col.relicLabels[k]
        if ke then
          local rx = cx + (k - (nk + 1) / 2) * CP_ZONE_RELIC_DX
          at(b, self.frame, rx - CP_ZONE_RELIC / 2, relicY, CP_ZONE_RELIC, CP_ZONE_RELIC)
          paintRelicSlot(b, ke)
          b:Show()
          lbl:ClearAllPoints()
          lbl:SetPoint("TOP", self.frame, "TOPLEFT", rx, -(relicY + CP_ZONE_RELIC + 3))
          lbl:SetText("+" .. ke.level)
          lbl:Show()
        else
          b:Hide()
          lbl:Hide()
        end
      end
    else
      col.name:Hide(); col.status:Hide(); col.keys:Hide()
      W.hideCard(col.card)
      col.lock:Hide()
      for k, b in ipairs(col.relics) do b:Hide() col.relicLabels[k]:Hide() end
    end
  end
end

-- Pose une carte (vraie ou silhouette) au repos ; au survol : halo et aperçu à taille réelle à côté
-- (petite carte, W.cardPreviewShow) ; silhouette : son infobulle de condition seulement.
local function placeCP(self, card, slot, cx, cy)
  local lv = self.panel:GetFrameLevel()
  if not card.isLock then
    W.placeCard(card, self.frame, cx, cy, CP_SCALE, lv + 5 + slot, lv + 80)
  else
    W.placeCenter(card, self.frame, cx, cy, CP_SCALE)
    W.setLevel(card, lv + 5 + slot)
  end
  card.cx, card.cy = cx, cy
end

function ClassProgress:Show(step)
  self.step = step
  UI.setStage({ scene = "road", board = true, veil = 0.45 })
  self.optionButtons = {}
  local tabs, others = {}, {}
  for _, o in ipairs(step.options or {}) do
    if o.group == "class" then tabs[#tabs + 1] = o else others[#others + 1] = o end
  end
  for i = #self.tabs + 1, #tabs do
    local b = classIcon(self.panel)
    b:Resize(CP_TAB)
    b:SetFrameLevel(self.panel:GetFrameLevel() + 4)
    self.tabs[i] = b
  end
  for i, b in ipairs(self.tabs) do
    local o = tabs[i]
    if o then
      local cid = o.id:match("^pclass:(.+)$")
      if b.cid ~= cid then
        b.cid = cid
        W.setIcon(b.icon, Art.class(cid), "class:" .. tostring(cid))
      end
      at(b, self.frame, CP_TAB_X + (i - 1) * CP_TAB_DX - CP_TAB / 2, CP_TAB_Y - CP_TAB / 2, CP_TAB, CP_TAB)
      b.option = o
      b:SetSelected(o.selected)
      b:Show()
      self.optionButtons[o.id] = b
    else
      b.option = nil
      b:Hide()
    end
  end
  self.bar:Set(step.bar)
  -- titre de la classe sous la barre de niveau (« Priest — Dragonslayer »)
  local named = withTitle(step.bar and step.bar.label, step.class)
  if named ~= (step.bar and step.bar.label or "") then self.bar.detail:SetText(named) end
  for _, o in ipairs(others) do
    local b = o.group == "tab" and self.tabBtn or (o.id == "ui:meta" and self.metaBtn or self.back)
    b.option = o
    b:SetText(o.label)
    self.optionButtons[o.id] = b
  end
  local zonesTab = step.tab == "zones"
  self:ShowZones(step.zones, zonesTab)
  -- rangées de cartes (onglet « Cards » ; vides sur l'onglet « Zones »)
  local slot = 0
  for r = 1, CP_ROWS do
    local row = not zonesTab and step.rows and step.rows[r]
    local l = self.rowLabels[r]
    local cy = CP_ROW_TOP + (r - 1) * CP_ROW_H + W.CARD_H * CP_SCALE / 2
    if row then
      -- nom de la voie : 14, réduit s'il ne tient pas dans la colonne
      local name = row.name or ""
      local size = 14
      while size > 10 and textWidth(l, name, size) * W.TEXT_SAFE > CP_LABEL_W do size = size - 0.5 end
      setLines(l, { name }, size, CP_LABEL_W)
      l:ClearAllPoints()
      l:SetPoint("LEFT", self.frame, "TOPLEFT", CP_LABEL_X, -cy)
      l:Show()
      local pitch = #row.cards > CP_ROW_MAX and CP_PITCH * (CP_ROW_MAX - 1) / (#row.cards - 1) or CP_PITCH
      for i, e in ipairs(row.cards) do
        slot = slot + 1
        local card, lock = self.cards[slot], self.locks[slot]
        if card and lock then
          local cx = CP_X0 + (i - 1) * pitch
          card.entry, lock.entry = e, e
          if e.unlocked then
            W.hideCard(lock)
            lock:Hide()
            card:SetCard(e.id, false, {})
            placeCP(self, card, slot, cx, cy)
            card:Show()
          else
            W.hideCard(card)
            lock.condition = e.condition
            placeCP(self, lock, slot, cx, cy)
            lock:Show()
          end
        end
      end
    else
      l:Hide()
    end
  end
  for i = slot + 1, CP_SLOTS do
    W.hideCard(self.cards[i])
    self.locks[i]:Hide()
  end
  -- bibelots, à droite des cartes de départ
  local cy = CP_ROW_TOP + W.CARD_H * CP_SCALE / 2
  self.relicLabel:SetText("Relics")
  W.looseBox(self.relicLabel, 1, 120)
  self.relicLabel:ClearAllPoints()
  self.relicLabel:SetPoint("RIGHT", self.frame, "TOPLEFT", CP_RELIC_LABEL_R, -cy)
  if zonesTab then self.relicLabel:Hide() else self.relicLabel:Show() end
  for i, b in ipairs(self.relics) do
    local e = not zonesTab and step.relics and step.relics[i]
    if e then
      at(b, self.frame, CP_RELIC_X + (i - 1) * CP_RELIC_DX - CP_RELIC / 2, cy - CP_RELIC / 2, CP_RELIC, CP_RELIC)
      paintRelicSlot(b, e)
      b:Show()
    else
      b.entry = nil
      b:Hide()
    end
  end
end

function ClassProgress:OnHide()
  for i = 1, CP_SLOTS do W.hideCard(self.cards[i]) end
  for _, col in ipairs(self.zoneCols) do W.hideCard(col.card) end
end

---------------------------------------------------------------------------
-- Consultation des cartes (par-dessus l'écran) : deck complet, pioche, défausse, consumées
---------------------------------------------------------------------------
-- Grille de vraies cartes (W.card), triées par type, coût puis nom ; la pioche n'est jamais montrée
-- dans l'ordre de tirage. Défilement à la molette ; fermeture par clic hors du panneau, « Fermer », ou
-- avec la fenêtre (Échap). Aucune règle : ne fait que lire l'état.

local DV = { kind = nil, offset = 0, list = {} }
UI.deckView = DV

local DV_X, DV_Y, DV_W, DV_H = 52, 58, 930, 540
local DV_SCALE, DV_ROW, DV_ROWS = 0.72, 8, 3
local DV_GAPX, DV_GAPY = 14, 28 -- (languette de coût et plaque du bas entre deux rangées)
local DV_TOP = DV_Y + 58
local DV_TITLE = { deck = "Deck", draw = "Draw pile", discard = "Discard pile", exhaust = "Exhausted" }
local TYPE_ORDER = { attack = 1, skill = 2, power = 3 }

-- Copie triée : l'épique, puis type, coût, nom, puis non améliorée avant améliorée (l'ordre réel est perdu).
function DV.sorted(list)
  local out = {}
  for i = 1, #(list or {}) do
    local inst = list[i]
    local d = ns.Card.defById(inst.id, inst.up)
    -- l'épique en tête (règle de l'expédition, docs/expedition.md, « Cartes épiques »)
    out[i] = { inst = inst, t = d.rarity == "epic" and 0 or TYPE_ORDER[d.type] or 9, cost = d.cost or 99,
      name = d.name or inst.id,
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

  local panel = W.dialog(veil, "", 16)
  at(panel, content, DV_X, DV_Y, DV_W, DV_H)
  panel:SetFrameLevel(base + 2)
  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", wheel)
  self.panel = panel
  self.title = panel.title
  self.empty = W.label(panel, "body", 14, C.textSoft)
  self.empty:SetPoint("CENTER", 0, 10)
  self.empty:SetText("No cards.")
  self.close = W.button(panel, "Close", 120, 34, function() DV:Close() end, "red", 14)
  self.close:SetPoint("BOTTOMRIGHT", -16, 14)
  -- indicateur de défilement
  self.track = W.rect(panel, "ARTWORK", 0, C.barTrack)
  self.thumb = W.rect(panel, "ARTWORK", 1, C.wowGold)

  self.cards = {}
  for i = 1, DV_ROW * DV_ROWS do
    local c = W.card(veil)
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
      card:SetCard(inst.id, inst.up, inst.from and { from = inst.from } or {})
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
  self.panel:SetTitle((DV_TITLE[self.kind] or "Cards") .. " · " .. n .. " card" .. (n ~= 1 and "s" or ""))
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
  if not DV:Open(kind) then UI.flash("No cards to show.") end
end

---------------------------------------------------------------------------
-- Remplacement d'une carte épique (une seule par expédition) : confirmation
---------------------------------------------------------------------------
-- Une option qui ferait partir l'épique du deck pour une autre (Controller.epicSwap : récompense « Epic »,
-- épique du marchand, rencontre) ouvre ce panneau par-dessus l'écran : les deux cartes côte à côte (l'actuelle
-- telle qu'elle est, améliorée ou non, à gauche ; la nouvelle, non améliorée, à droite), la question
-- « Replace A with B? » et deux boutons : « Replace » (l'action part) et « Keep A » (rien ne change). Cartes à
-- EC_SCALE, sans levée ni aperçu au survol (halo seulement) ; clic hors du panneau = « Keep ». Construit au
-- premier usage (comme le panneau du deck), jamais pendant un survol.

local EC = { pending = nil }
UI.epicConfirm = EC

local EC_W, EC_H, EC_SCALE = 520, 372, 0.9

function EC:Build()
  local content = UI.content
  local base = content:GetFrameLevel() + 130
  local veil = CreateFrame("Button", nil, content)
  at(veil, content, 0, Scene.TOP, Scene.W, Scene.H - Scene.TOP)
  veil:SetFrameLevel(base)
  veil:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local shade = W.rect(veil, "BACKGROUND", 0, C.black, 0.55)
  shade:SetAllPoints()
  veil:SetScript("OnClick", function() EC:Answer(false) end)
  veil:Hide()
  self.frame = veil
  local x, y = (Scene.W - EC_W) / 2, Scene.TOP + (Scene.H - Scene.TOP - EC_H) / 2
  self.x, self.y = x, y
  local panel = W.dialog(veil, "Epic card", 16)
  at(panel, content, x, y, EC_W, EC_H)
  panel:SetFrameLevel(base + 2)
  self.panel = panel
  self.question = W.label(panel, "heavy", 18, C.wowGold, "OVERLAY")
  self.question:SetPoint("TOP", 0, -26)
  self.question:SetWidth(EC_W - 40)
  self.question:SetJustifyH("CENTER")
  self.question:SetWordWrap(true)
  self.note = W.label(panel, "body", 12.5, C.textSoft, "OVERLAY")
  self.note:SetPoint("TOP", self.question, "BOTTOM", 0, -6)
  self.note:SetWidth(EC_W - 40)
  self.note:SetJustifyH("CENTER")
  self.note:SetText("Only one epic card per expedition: the current one leaves the deck.")
  self.arrow = W.label(panel, "heavy", 30, C.wowGold, "OVERLAY")
  self.arrow:SetText(">")
  self.cards = {}
  for i = 1, 2 do
    local c = W.card(veil)
    c:SetFrameLevel(base + 6)
    c:SetScript("OnClick", function() end)
    c:Hide()
    self.cards[i] = c
  end
  self.oldLabel = W.label(panel, "bold", 12, C.badText, "OVERLAY")
  self.newLabel = W.label(panel, "bold", 12, C.healGreen, "OVERLAY")
  self.oldLabel:SetText("Leaves the deck")
  self.newLabel:SetText("Joins the deck")
  -- l'épique actuelle est améliorée : l'amélioration ne passe pas à la nouvelle (une ligne sous « Leaves »)
  self.lost = W.label(panel, "body", 12, C.textSoft, "OVERLAY")
  self.lost:SetText("The upgrade is lost.")
  self.lost:Hide()
  self.replace = W.button(panel, "Replace", 200, 44, function() EC:Answer(true) end, "gold", 16)
  self.replace:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -8, 16)
  self.keep = W.button(panel, "Keep", 200, 40, function() EC:Answer(false) end, "red", 14)
  self.keep:SetPoint("BOTTOMLEFT", panel, "BOTTOM", 8, 18)
end

function EC:IsShown() return self.frame ~= nil and self.frame:IsShown() and true or false end

-- Ouvre la confirmation pour l'option id (swap = Controller.epicSwap(id)).
function EC:Open(id, swap)
  if not UI.content then return false end
  if not self.frame then self:Build() end
  if GameTooltip then GameTooltip:Hide() end
  self.pending = id
  local function name(c) return ns.Card.defById(c.id, c.up).name end
  self.question:SetText("Replace " .. name(swap.old) .. " with " .. name(swap.new) .. "?")
  self.keep:SetText("Keep " .. name(swap.old))
  local cw = W.CARD_W * EC_SCALE
  local cy = self.y + 104 + W.CARD_H * EC_SCALE / 2
  local cx = { Scene.W / 2 - cw / 2 - 46, Scene.W / 2 + cw / 2 + 46 }
  local lv = self.panel:GetFrameLevel()
  for i, c in ipairs(self.cards) do
    local e = i == 1 and swap.old or swap.new
    c:SetCard(e.id, e.up, {})
    W.placeCard(c, UI.content, cx[i], cy, EC_SCALE, lv + 4 + i, lv + 8)
    c:Show()
  end
  self.arrow:ClearAllPoints()
  self.arrow:SetPoint("CENTER", UI.content, "TOPLEFT", Scene.W / 2, -cy)
  local ly = cy + W.CARD_H * EC_SCALE / 2 + 12
  self.oldLabel:ClearAllPoints()
  self.oldLabel:SetPoint("TOP", UI.content, "TOPLEFT", cx[1], -ly)
  self.newLabel:ClearAllPoints()
  self.newLabel:SetPoint("TOP", UI.content, "TOPLEFT", cx[2], -ly)
  self.lost:ClearAllPoints()
  self.lost:SetPoint("TOP", self.oldLabel, "BOTTOM", 0, -2)
  if swap.old.up then self.lost:Show() else self.lost:Hide() end
  self.frame:Show()
  W.sound("card")
  return true
end

function EC:Close()
  if not self:IsShown() then return end
  for _, c in ipairs(self.cards) do W.hideCard(c) end
  self.frame:Hide()
  if GameTooltip then GameTooltip:Hide() end
end

-- Réponse : vrai = l'action part (l'épique est remplacée), faux = rien ne change.
function EC:Answer(yes)
  local id = self.pending
  self.pending = nil
  self:Close()
  if yes and id then
    W.sound("pick")
    UI.choose(id, true)
  end
end

-- Appelé par UI.choose : vrai si l'option id remplacerait l'épique du deck (la confirmation s'ouvre, l'action
-- attend la réponse).
function UI.confirmEpic(id)
  local swap = Controller.epicSwap and Controller.epicSwap(id)
  if not swap then return false end
  return EC:Open(id, swap)
end
