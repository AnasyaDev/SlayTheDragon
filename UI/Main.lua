-- Fenêtre principale (1040 × 620), bandeau, gestion des écrans, options, /slay, minimap.
-- Aucun raccourci clavier : la fenêtre ne capte jamais le clavier (les touches restent au jeu, joué en
-- vol) ; Échap la ferme par UISpecialFrames, comme toute fenêtre du jeu.
local addonName, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local W, Art, Controller, Persist, Scene = ns.Widgets, ns.Art, ns.Controller, ns.Persist, ns.Scene
local C = Art.C

local UI = {}
ns.UI = UI

UI.WIDTH, UI.HEIGHT = 1040, 620
UI.CONTENT_W, UI.CONTENT_H = 1034, 614
UI.INSET_L, UI.INSET_T = 2.5, 2.5 -- contenu dans la fenêtre (droite et bas : 3,5 ; voir UI.build)
UI.screens = {}         -- nom -> écran
UI.screenByKind = {}    -- kind d'étape -> nom d'écran
UI.current = nil        -- écran affiché
UI.dirty = true
UI.hold = {}            -- butin pas encore « ramassé » à l'écran (cosmétique) : gold, relic, potion

local function opts() return Persist.options() end

local function say(msg)
  local cf = DEFAULT_CHAT_FRAME
  if cf and cf.AddMessage then cf:AddMessage("|cffd4a017Slay the Dragon|r: " .. msg) else print(msg) end
end
UI.say = say

-- Enregistre un écran : screen = { kinds = {...}, Build(self, parent), Show(self, step), OnHide(self) }.
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

-- Nouvelle échelle choisie par le joueur : la fenêtre garde son centre à l'écran et reste entière dans
-- l'écran (centrée sur un axe où elle ne tient pas). Les décalages d'ancre (SetPoint, GetPoint, donc
-- opts().point) sont en unités de la fenêtre, multipliés par son échelle à l'écran : sans conversion, la
-- fenêtre glissait d'autant. Elle est réancrée par son centre sur le coin bas gauche de UIParent, et la
-- position enregistrée l'est dans les unités de la nouvelle échelle (cohérente avec opts().scale).
function UI.setScale(s)
  local f = UI.frame
  local old = f:GetScale() or 1
  local cx, cy = f:GetCenter() -- unités de la fenêtre, à l'ancienne échelle
  opts().scale = s
  UI.applyScale()
  local new = f:GetScale() or 1
  if not cx or not cy or old <= 0 or new <= 0 then return end
  local ux, uy = cx * old, cy * old -- unités de UIParent (parent de la fenêtre)
  local pw, ph = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
  local fw, fh = (f:GetWidth() or 0) * new, (f:GetHeight() or 0) * new
  local function fit(c, size, room)
    if room <= 0 then return c end
    if size >= room then return room / 2 end
    return math.max(size / 2, math.min(room - size / 2, c))
  end
  ux, uy = fit(ux, fw, pw), fit(uy, fh, ph)
  local pt = { "CENTER", "BOTTOMLEFT", ux / new, uy / new }
  opts().point = pt
  f:ClearAllPoints()
  f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
end

-- Décor et plateau (Scene.set) ; appelé par chaque écran. Le décor commun demandé (road, night, shop…)
-- devient celui de la zone de l'expédition quand elle en déclare un (Controller.zoneScene).
function UI.setStage(stage)
  if not Scene.decor then return end
  if stage and stage.scene then
    local id = Controller.zoneScene(stage.scene)
    if id ~= stage.scene then
      local copy = {}
      for k, v in pairs(stage) do copy[k] = v end
      copy.scene = id
      stage = copy
    end
  end
  Scene.set(stage)
end

local BAND_H = 31       -- bandeau : sous la barre de titre du cadre métal (centre à y 15,5)
local BAND_SLOT = 25    -- cases du bandeau (bibelots, fioles, clé)

-- Bandeau (direction B) : posé sur la barre de titre du cadre métal de la fenêtre. À gauche classe, PV,
-- or (pièce), deck (dos de carte + nombre) ; au centre zone et pastilles de progression (icônes de la
-- carte de vol) ; à droite clé, bibelots et fioles dans des cases de barre d'action, Menu, fermeture.
-- host : porteur (frameTop, qui dessine la barre de titre : le bandeau, son enfant, passe au-dessus) ;
-- place : cadre de référence des positions (le contenu : UI.bandTarget reste en coordonnées du contenu).
local function buildBand(host, place)
  local band = CreateFrame("Frame", nil, host)
  Scene.at(band, place, 0, 0, UI.CONTENT_W, BAND_H)
  band:SetFrameLevel(host:GetFrameLevel() + 1)
  band:EnableMouse(true)
  band:RegisterForDrag("LeftButton")
  band:SetScript("OnDragStart", function() UI.frame:StartMoving() end)
  band:SetScript("OnDragStop", function() UI.frame:StopMovingOrSizing() savePosition(UI.frame) end)
  UI.band = band

  UI.className = W.label(band, "bold", 15, C.wowGold)
  UI.className:SetPoint("LEFT", 18, 0)
  -- PV : « HP 52/65 »
  UI.hpLabel = W.label(band, "bold", 12.5, C.wowGold)
  UI.hpLabel:SetPoint("LEFT", UI.className, "RIGHT", 16, 0)
  UI.hpLabel:SetText("HP")
  UI.hpText = W.label(band, "heavy", 14.5, C.hpText)
  UI.hpText:SetPoint("LEFT", UI.hpLabel, "RIGHT", 4, 0)
  UI.hpMax = W.label(band, "bold", 12.5, C.hpText)
  UI.hpMax:SetPoint("LEFT", UI.hpText, "RIGHT", 1, 0)
  -- or
  UI.goldIcon = band:CreateTexture(nil, "ARTWORK")
  UI.goldIcon:SetSize(17, 17)
  UI.goldIcon:SetPoint("LEFT", UI.hpMax, "RIGHT", 18, 0)
  W.roundMask(band, UI.goldIcon)
  W.setIcon(UI.goldIcon, Art.ui.gold, "ui:gold")
  UI.goldText = W.label(band, "heavy", 14.5, C.text)
  UI.goldText:SetPoint("LEFT", UI.goldIcon, "RIGHT", 4, 0)
  -- deck : dos de carte et nombre (aussi en combat) ; infobulle = contenu ; clic = consulter
  local deck = CreateFrame("Button", nil, band)
  deck:SetSize(46, 26)
  deck:SetPoint("LEFT", UI.goldText, "RIGHT", 16, 0)
  deck:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local dface = W.face(deck)
  deck.back = W.cardBack(dface, 24)
  deck.back:SetPoint("LEFT", 0, 0)
  -- surbrillance : copie additive du dos de carte (créée d'avance, éteinte) ; le nombre ne bouge pas
  deck.light = W.lightLayer(W.cardBack(dface, 24, "ARTWORK", 1))
  deck.light:SetPoint("LEFT", 0, 0)
  deck.label = W.label(dface, "heavy", 14.5, C.text)
  deck.label:SetPoint("LEFT", deck.back, "RIGHT", 4, 0)
  deck.SetText = function(self, t) self.label:SetText(t) self._text = t end
  W.hoverable(deck, { paint = function(self, h) self.light:SetAlpha(W.LIGHT_ADD * h) end })
  deck:SetScript("OnClick", function(_, button)
    if button == "RightButton" then return end
    W.sound("click")
    UI.toggleDeckView("deck")
  end)
  W.tooltip(deck, function(tt)
    UI.fillDeckTooltip(tt)
    tt:AddLine("Click: view the cards.", 0.6, 0.6, 0.6)
  end, "ANCHOR_BOTTOM")
  UI.info = deck
  UI.deckButton = deck

  -- Centre : nom de la zone, puis pastilles de progression sur la même ligne (franchies vertes, étape
  -- en cours jaune, à venir grises, boss rouge). Le cadre va du deck au premier élément de droite
  -- (layoutMid) : un nom trop long est tronqué, jamais posé sur les pastilles ni sur les cases.
  local mid = CreateFrame("Frame", nil, band)
  mid:SetHeight(BAND_H)
  mid:SetPoint("LEFT", deck, "RIGHT", 16, 0)
  mid:SetPoint("RIGHT", band, "RIGHT", -100, 0)
  UI.zone = W.label(mid, "bold", 15, C.wowGold)
  UI.zone:SetWordWrap(false)
  UI.zone:SetJustifyH("CENTER")
  UI.dots = {}
  for i = 1, 12 do
    local d = W.wow(mid, "pip_gray", "ARTWORK", 2)
    d:Hide()
    UI.dots[i] = d
  end
  UI.bossDot = W.wow(mid, "pip_red", "ARTWORK", 2)
  UI.bossDot:Hide()
  UI.mid = mid

  -- Droite : fermeture, Menu, fioles | bibelots, clé.
  local close = W.closeButton(band, 24, function() UI.close("button") end)
  close:SetPoint("CENTER", band, "RIGHT", -20, 0)
  UI.closeButton = close
  local gear = W.button(band, "Menu", 62, 22, function() UI.toggleOptions() end, "red", 12.5)
  gear:SetPoint("CENTER", band, "RIGHT", -72, 0)
  UI.gear = gear

  -- emplacements de potion : 3, jusqu'à 4 avec Herb Pouch (#exp.potions) ; calés à droite (UI.refreshInfo)
  UI.potionSlots = {}
  UI.POTION_SLOTS_MAX = 4
  for i = 1, UI.POTION_SLOTS_MAX do
    local b = W.iconButton(band, BAND_SLOT, "square")
    b:SetPoint("CENTER", band, "RIGHT", -124 - (3 - i) * 29, 0)
    b.slot = i
    b:SetScript("OnClick", function(self, button) UI.clickPotion(self, button) end)
    if i > 3 then b:Hide() end
    UI.potionSlots[i] = b
  end
  local sep = CreateFrame("Frame", nil, band)
  sep:SetSize(6, BAND_SLOT)
  sep:SetPoint("RIGHT", UI.potionSlots[1], "LEFT", -5, 0)
  UI.sep = sep
  UI.RELICS_SHOWN = 6
  UI.relicIcons = {}
  for i = 1, UI.RELICS_SHOWN do
    local b = W.iconButton(band, BAND_SLOT, "square")
    b:SetPoint("RIGHT", sep, "LEFT", -5 - (UI.RELICS_SHOWN - i) * 29, 0)
    b:Hide()
    UI.relicIcons[i] = b
  end
  UI.relicMore = W.label(band, "bold", 11, C.textSoft)
  UI.relicMore:SetPoint("RIGHT", UI.relicIcons[1], "LEFT", -3, 0)

  -- Clé mythique : case à l'icône de la clé, « +N ».
  local ks = W.iconButton(band, BAND_SLOT, "square")
  ks:SetItem("keystone", 0)
  ks.count:ClearAllPoints()
  ks.count:SetPoint("CENTER", ks.face, "CENTER", 0, 0)
  W.setSize(ks.count, 12)
  ks:Hide()
  UI.keystone = ks
end

function UI.fillDeckTooltip(tt)
  local r = Controller.runInfo()
  if not r then tt:AddLine("No expedition in progress.") return end
  tt:AddLine("Deck (" .. #r.deck .. " cards)", 1, 0.82, 0)
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
  -- Échap : mécanisme standard du jeu (CloseSpecialWindows cache la fenêtre, et avec elle les options et
  -- le panneau des cartes) ; la fenêtre ne capte pas le clavier.
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "SlayTheDragonFrame") end

  -- Ordre de dessin. Un cadre qui rogne ses enfants (SetClipsChildren) dessine tout son sous-arbre dans
  -- sa propre passe, à SON niveau : les niveaux de ses descendants ne se comparent qu'entre eux, jamais à
  -- ceux d'un cadre extérieur (le bandeau, enfant du contenu au niveau contenu + 40, restait sous la
  -- barre de titre, sœur du contenu au niveau contenu + 39). Tout ce qui doit passer au-dessus du
  -- contenu est donc un cadre frère, enfant de la fenêtre, de niveau supérieur, et les écarts sont assez
  -- grands pour que l'ordre tienne même si le client comparait tous les niveaux entre eux (sous-arbre
  -- du contenu < contenu + 300) :
  --   contenu (rogné)          niveau L        décor, plateau, écrans, options, panneau du deck
  --   frameTop                 L + 300         barre de titre du cadre métal, puis le bandeau (enfant)
  --   UI.overlay (rogné)       L + 600         message passager, butin en vol, aperçu des petites cartes
  --   rimHost                  L + 900         filets gauche, droit et bas du cadre métal
  -- Le contenu est rentré de 2,5 (gauche, haut) et 3,5 (droite, bas) : ses bords tombent sous la partie
  -- opaque du filet et ses coins dans la silhouette des coins biseautés (le harnais le vérifie au pixel,
  -- U31) ; le fond de roche a exactement son rectangle (rien de visible hors de la silhouette du cadre).
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", UI.INSET_L, -UI.INSET_T)
  content:SetSize(UI.CONTENT_W, UI.CONTENT_H)
  content:SetClipsChildren(true)
  UI.content = content
  local L = content:GetFrameLevel()
  -- fond de roche (UI-Background-Rock), porté par la fenêtre, au rectangle du contenu
  UI.frameBg = W.fillTile(content, "rock", 1, "BACKGROUND", -8, 0, f)
  UI.frameBg:SetVertexColor(0.55, 0.55, 0.55, 1)
  -- Cadre métal des fenêtres du jeu (UI-Frame-Metal) : barre de titre (frameTop) sous le bandeau, filets
  -- des côtés et du bas (rimHost) par-dessus tout. Débords : filets gauche, droit et bas sur le bord de la
  -- fenêtre, haut de la barre de titre au bord haut.
  local k, mm = W.K_METAL, W.Wow.meta.metal
  local frameTop = CreateFrame("Frame", nil, f)
  frameTop:SetAllPoints()
  frameTop:SetFrameLevel(L + 300)
  UI.frameTop = frameTop
  local overlay = CreateFrame("Frame", nil, f)
  overlay:SetAllPoints(content)
  overlay:SetClipsChildren(true)
  overlay:SetFrameLevel(L + 600)
  UI.overlay = overlay
  -- aperçu à taille réelle des petites cartes (une instance, construite ici, réutilisée)
  UI.cardPreview = W.buildCardPreview(overlay, UI.CONTENT_W, UI.CONTENT_H)
  local rimHost = CreateFrame("Frame", nil, f)
  rimHost:SetAllPoints()
  rimHost:SetFrameLevel(L + 900)
  UI.rimHost = rimHost
  UI.frameMetal = W.frameSlices(f, { tl = "metal_tl", tr = "metal_tr", bl = "metal_bl", br = "metal_br",
    top = "metal_top", bottom = "metal_bottom", left = "metal_left", right = "metal_right" }, k,
    { mm.lineL0 * k, mm.barTop * k, (150 - mm.lineR1) * k, (64 - mm.lineB1) * k },
    { parent = rimHost, top = frameTop, layer = "ARTWORK" })
  Scene.build(content)
  -- bandeau : enfant de frameTop (au-dessus de sa barre de titre), placé en coordonnées du contenu
  buildBand(frameTop, content)

  -- Message passager (raison d'un refus, consigne) : à la façon des erreurs du jeu (texte rouge), sur
  -- un voile sombre léger pour rester lisible sur le décor ; sur la couche du dessus (au-dessus des
  -- options et du panneau du deck).
  local err = CreateFrame("Frame", nil, overlay)
  err:SetSize(520, 34)
  Scene.at(err, content, (UI.CONTENT_W - 520) / 2, 196, 520, 34)
  err:SetFrameLevel(overlay:GetFrameLevel() + 10)
  err.veil = W.rect(err, "BACKGROUND", 0, C.black, 0.55)
  err.veil:SetAllPoints()
  err.text = W.label(err, "heavy", 15, { 1, 0.3, 0.25 }, "OVERLAY")
  err.text:SetPoint("CENTER")
  err:Hide()
  -- Compatibilité avec le harnais : err._text / err:SetText.
  err.SetText = function(self, t) self.text:SetText(t) self._text = t end
  UI.err = err

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
    if a then lines[#lines + 1] = a.name .. ": " .. a.text end
  end
  return table.concat(lines, "\n")
end

-- Nom de zone puis pastilles de progression, sur une ligne, centrés dans le cadre central (UI.mid, de
-- largeur connue : layoutMid). Le nom est tronqué à la place laissée par les pastilles : rien ne se
-- chevauche, quelle que soit sa longueur.
local PIP, PIP_CUR, PIP_STEP = 11, 13, 13
local function layoutDots(r)
  local mid = UI.mid
  local midW = UI.midW or 300
  local floors = r and r.floors
  -- ni sur la carte (elle montre les étapes) ni entre deux zones (aucune étape commencée)
  local showDots = floors and UI.step and UI.step.kind ~= "map" and UI.step.kind ~= "transit"
  local n = showDots and math.min(floors - 1, #UI.dots) or 0
  local pipsW = showDots and (n * PIP_STEP + PIP_CUR) or 0
  local gap = showDots and 10 or 0
  UI.zone:SetWidth(0)
  local tw = UI.zone:GetStringWidth() or 0
  tw = math.max(0, math.min(tw, midW - pipsW - gap))
  UI.zone:SetWidth(tw + 1)
  local x0 = (midW - (tw + gap + pipsW)) / 2
  UI.zone:ClearAllPoints()
  UI.zone:SetPoint("LEFT", mid, "LEFT", x0, 0.5)
  if not showDots then
    for i = 1, #UI.dots do UI.dots[i]:Hide() end
    UI.bossDot:Hide()
    return
  end
  -- pastilles de la carte de vol : franchies vertes, étape en cours jaune (plus grande), à venir grises,
  -- boss rouge
  local cur = math.max(1, (r.floor or 0))
  local px = x0 + tw + gap + PIP_STEP / 2
  for i = 1, #UI.dots do
    local d = UI.dots[i]
    if i <= n then
      local size = i == cur and PIP_CUR or PIP
      W.setWow(d, i < cur and "pip_green" or (i == cur and "pip_yellow" or "pip_gray"))
      d:SetSize(size, size)
      d:ClearAllPoints()
      d:SetPoint("CENTER", mid, "LEFT", px + (i - 1) * PIP_STEP, 0)
      d:Show()
    else
      d:Hide()
    end
  end
  UI.bossDot:SetSize(PIP_CUR, PIP_CUR)
  UI.bossDot:ClearAllPoints()
  UI.bossDot:SetPoint("CENTER", mid, "LEFT", px + n * PIP_STEP + 1, 0)
  UI.bossDot:Show()
end

-- Bornes du cadre central : du deck au groupe de droite (largeur calculée : rightW = place prise à
-- droite par les cases, Menu et fermeture).
local function layoutMid(rightW)
  local mid = UI.mid
  local function sw(fs) return (fs:IsShown() and fs:GetText() and fs:GetText() ~= "") and (fs:GetStringWidth() or 0) or 0 end
  local left = 18 + sw(UI.className)
  if UI.hpText:IsShown() then
    left = left + 16 + sw(UI.hpLabel) + 4 + sw(UI.hpText) + 1 + sw(UI.hpMax) + 18 + 17 + 4 + sw(UI.goldText)
  end
  if UI.deckButton:IsShown() then left = left + 16 + UI.deckButton:GetWidth() end
  left = left + 14
  local w = math.max(60, UI.CONTENT_W - rightW - 12 - left)
  mid:ClearAllPoints()
  mid:SetSize(w, BAND_H)
  mid:SetPoint("LEFT", UI.band, "LEFT", left, 0)
  UI.midW = w
end

function UI.refreshInfo()
  local r = Controller.runInfo()
  local potions = Controller.potions()
  local hold = UI.hold
  local heldPotion = hold.potion
  local nSlots = math.max(3, math.min(potions and #potions or 3, #UI.potionSlots))
  for i = 1, #UI.potionSlots do
    local b = UI.potionSlots[i]
    local id = potions and potions[i]
    if heldPotion and id == heldPotion and i == hold.potionSlot then id = nil end
    b:ClearAllPoints()
    b:SetPoint("CENTER", UI.band, "RIGHT", -124 - (nSlots - i) * 29, 0)
    if i > nSlots then
      b:Hide()
    elseif r then
      if id then
        b:SetItem("potion", id, { hint = Controller.inCombat() and "Click: drink."
          or { "Drink it in combat.", "Right-click twice: discard." } })
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
  -- place prise à droite : fermeture, Menu, fioles, séparateur, bibelots, clé
  local rightW = 103
  if r then rightW = 210.5 + (nSlots - 3) * 29 + math.min(nShown, UI.RELICS_SHOWN) * 29 end
  if nShown > UI.RELICS_SHOWN then rightW = rightW + 3 + (UI.relicMore:GetStringWidth() or 12) end
  -- clé, à gauche des bibelots
  local anchor = UI.relicIcons[math.max(1, UI.RELICS_SHOWN - math.min(nShown, UI.RELICS_SHOWN) + 1)]
  if nShown == 0 then anchor = UI.sep end
  if r and (r.key or 0) > 0 then
    UI.keystone.info = { id = r.key, title = "Mythic Keystone +" .. r.key, text = affixText(r) }
    UI.keystone.count:SetText("+" .. r.key)
    UI.keystone:ClearAllPoints()
    UI.keystone:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
    UI.keystone:Show()
    rightW = rightW + 8 + 25
  else
    UI.keystone:Hide()
  end
  local shown = r and true or false
  for _, t in ipairs({ UI.hpLabel, UI.hpText, UI.hpMax, UI.goldIcon, UI.goldText }) do
    if shown then t:Show() else t:Hide() end
  end
  if r then
    UI.deckButton:SetText(tostring(#r.deck))
    UI.deckButton:Show()
  else
    UI.deckButton:Hide()
  end
  if UI.deckView then UI.deckView:Refresh() end
  if not r then
    UI.className:SetText("Slay the Dragon")
    UI.hpText:SetText("")
    UI.hpMax:SetText("")
    UI.goldText:SetText("")
    UI.zone:SetText("")
    layoutMid(rightW)
    layoutDots(nil)
    return
  end
  local cls = Controller.exp() and ns.Classes[Controller.exp().class]
  UI.className:SetText(cls and cls.name or "Slay the Dragon")
  UI.hpText:SetText(tostring(r.hp))
  UI.hpMax:SetText("/" .. r.maxHp)
  UI.goldText:SetText(tostring(math.max(0, r.gold - (hold.gold or 0))))
  local zone = r.act or ""
  UI.zone:SetText(zone)
  layoutMid(rightW)
  layoutDots(r)
end

-- Position (coordonnées du contenu) d'une destination du bandeau, pour le butin qui y vole.
function UI.bandTarget(kind)
  if kind == "gold" then return 197, 15 end
  if kind == "potion" then return 852, 15 end
  if kind == "relic" then return 790, 15 end
  return 263, 15
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
    if Controller.inCombat() then UI.flash("Potions can't be discarded during combat.") return end
    if b.armed then
      b.armed = false
      local ok, why = Controller.discardPotion(b.slot)
      if not ok then UI.flash(Controller.reasonText(why)) end
    else
      b.armed = true
      UI.flash("Right-click again to discard " .. name .. ".")
      W.delay(3, function() b.armed = false end)
    end
    return
  end
  if not Controller.inCombat() then UI.flash("Potions are drunk in combat.") return end
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

-- Choix générique depuis un écran (bouton, carte, nœud de carte). Une option qui remplacerait la carte
-- épique du deck demande d'abord confirmation (UI.confirmEpic, UI/Screens.lua) : rien ne part, faux est
-- renvoyé ; confirmed = vrai pour la rejouer après la réponse.
function UI.choose(id, confirmed)
  if not confirmed and UI.confirmEpic and UI.confirmEpic(id) then return false end
  local ok, why = Controller.choose(id)
  if not ok and why then UI.flash(Controller.reasonText(why) or "Choice not possible.") end
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
    if reason ~= "flight" then say("unavailable in combat.") end
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

function UI.onShow()
  W.sound("open")
  UI.refresh()
  -- police d'addon chargée après coup : textes reposés (sinon certains restent vides jusqu'au survol)
  W.delay(0.1, function() if UI.isShown() then W.refreshFonts() end end)
  if not UI.fontsRefreshed then
    UI.fontsRefreshed = true
    W.delay(1, function() if UI.isShown() then W.refreshFonts() end end)
  end
end

function UI.onHide()
  -- fermée (Échap compris) : options et panneau des cartes fermés avec elle, rien ne reste ouvert au retour
  if UI.optionsFrame then UI.optionsFrame:Hide() end
  if UI.deckView then UI.deckView:Close() end
  if UI.current and UI.current.OnHide then UI.current:OnHide() end
  if GameTooltip then GameTooltip:Hide() end
  W.sound("close")
end

---------------------------------------------------------------------------
-- Options
---------------------------------------------------------------------------

-- Options : boîte de dialogue DiamondMetal du jeu (en-tête « Options », bouton de fermeture rouge),
-- cases à cocher et curseurs minimaux, boutons rouges.
function UI.buildOptions()
  local p = W.dialog(UI.content, "Options")
  p:SetSize(370, 372)
  p:SetPoint("TOPRIGHT", UI.content, "TOPRIGHT", -18, -58)
  p:SetFrameLevel(UI.content:GetFrameLevel() + 100)
  p:Hide()
  UI.optionsFrame = p
  local x = W.closeButton(p, 22, function() p:Hide() end)
  x:SetPoint("TOPRIGHT", -12, -12)
  UI.optionsClose = x

  local checks = {}
  local function check(label, key, y, onSet)
    local c = W.check(p, label, function() return opts()[key] end,
      function(v) opts()[key] = v if onSet then onSet(v) end end)
    c:SetPoint("TOPLEFT", 24, y)
    checks[#checks + 1] = c
    return c
  end
  check("Open on takeoff", "autoOpen", -38)
  check("Close on landing", "autoClose", -64)
  check("Fast mode (instant animations)", "fast", -90)
  local mm = W.check(p, "Minimap button", function() return not opts().minimap.hide end,
    function(v) opts().minimap.hide = not v UI.updateMinimapButton() end)
  mm:SetPoint("TOPLEFT", 24, -116)
  checks[#checks + 1] = mm
  check("Illustrated scenery (else painted)", "decor", -142, function() UI.refresh() end)
  UI.optionChecks = checks

  -- curseur : libellé doré, rail (flèches aux bouts = un cran), valeur à droite. deferred : le glisser
  -- ne montre qu'un aperçu (poignée et valeur), set n'est appelé qu'au relâchement (W.slider, preview).
  local function slider(label, y, lo, hi, stepV, get, set, fmt, deferred)
    local l = W.label(p, "bold", 13, C.wowGold)
    l:SetPoint("TOPLEFT", 26, y)
    l:SetText(label)
    local v = W.label(p, "heavy", 13.5, C.text)
    v:SetPoint("TOPLEFT", 288, y - 21)
    -- valeur au cran le plus proche, bornée (arrondie : pas de 1.1500000000000001)
    local function snap(x)
      local val = tonumber(("%.6f"):format(lo + math.floor((x - lo) / stepV + 0.5) * stepV))
      return math.max(lo, math.min(hi, val))
    end
    local function frac() return ((get() or lo) - lo) / (hi - lo) end
    local preview = deferred and function(f)
      local val = snap(lo + f * (hi - lo))
      v:SetText(fmt(val))
      return (val - lo) / (hi - lo)
    end or nil
    local s = W.slider(p, 252, frac, function(d)
      set(snap((get() or lo) + d * stepV))
      v:SetText(fmt(get()))
    end, function(f)
      local val = snap(lo + f * (hi - lo))
      if val ~= get() then set(val) end
      v:SetText(fmt(get()))
    end, preview)
    s:SetPoint("TOPLEFT", 24, y - 20)
    v.Sync = function() v:SetText(fmt(get())) s:Sync() end
    return v, s.minus, s.plus, s
  end
  local pct = function(x) return math.floor(x * 100 + 0.5) .. "%" end
  UI.scaleValue, UI.scaleMinus, UI.scalePlus, UI.scaleSlider = slider("Window scale", -174, 0.6, 1.5, 0.05,
    function() return opts().scale end, function(s) UI.setScale(s) end, pct, true)
  UI.speedValue, UI.speedMinus, UI.speedPlus, UI.speedSlider = slider("Animation speed", -222, 0.5, 3, 0.25,
    function() return opts().speed end, function(s) opts().speed = s end, function(x) return "×" .. x end)

  local ab = W.button(p, "Abandon expedition", 196, 28, nil, "red")
  ab:SetPoint("BOTTOMLEFT", 22, 54)
  ab:SetScript("OnClick", function(self)
    if not Controller.exp() then UI.flash("No expedition in progress.") return end
    if self.armed then
      self.armed = false
      self:SetText("Abandon expedition")
      Controller.abandon()
      p:Hide()
    else
      self.armed = true
      self:SetText("Confirm abandon?")
      W.delay(3, function() if self.armed then self.armed = false self:SetText("Abandon expedition") end end)
    end
  end)
  UI.abandonButton = ab

  local rp = W.button(p, "Recenter the window", 196, 28, function()
    opts().point = nil
    UI.applyPosition()
  end)
  rp:SetPoint("BOTTOMLEFT", 22, 20)

  local ok = W.button(p, "Close", 110, 28, function() p:Hide() end)
  ok:SetPoint("BOTTOMRIGHT", -22, 20)

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
    tt:AddLine("Left-click: open / close", 1, 1, 1)
    tt:AddLine("Right-click: options", 1, 1, 1)
    tt:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
  end, "ANCHOR_LEFT")
  UI.updateMinimapButton()
end

---------------------------------------------------------------------------
-- /slay
---------------------------------------------------------------------------

-- /slay art : fonds embarqués, décors (fond embarqué, candidat validé ou peint ; verdicts), puis icônes et
-- modèles manquants.
local function artReport()
  if not UI.frame then UI.build() end
  say("scenery" .. (opts().decor == false and " (illustrations off: /slay scenery illustrated)" or "") .. ":")
  for _, line in ipairs(Scene.report()) do say("  " .. line) end
  local keys = {}
  for k in pairs(W.missing) do keys[#keys + 1] = k end
  table.sort(keys)
  if #keys == 0 then
    say("no missing icon or model found so far (run again after a few screens).")
  else
    say(#keys .. " missing art element(s):")
    for i = 1, #keys do say("  " .. keys[i]) end
  end
  local cut = #W.truncatedLog() + #W.truncatedNow()
  if cut > 0 then say(cut .. " truncated text(s): /slay text.") end
end

-- /slay text : textes que le client a tronqués (« … ») : relevés du garde-fou des cartes (palier
-- descendu, voir W.checkCardTexts), puis textes visibles tronqués en ce moment.
local function textReport()
  local log, now = W.truncatedLog(), W.truncatedNow()
  if #log == 0 and #now == 0 then
    say("no truncated text found so far (hover a few cards, then run again).")
    return
  end
  if #log > 0 then
    say(#log .. " truncated card text(s) caught (please report them):")
    for i = 1, #log do say("  " .. log[i]) end
  end
  if #now > 0 then
    say(#now .. " text(s) truncated on screen right now:")
    for i = 1, #now do say("  " .. now[i]) end
  end
end

-- Affiche tous les ennemis de l'acte (vérification des modèles), sans toucher à l'expédition.
local function artPreview()
  UI.open("art")
  local s = UI.screens.combat
  if s and s.PreviewEnemies then s:PreviewEnemies() end
end

-- /slay scenery [test | next | prev | ok | no | painted | illustrated] : décor illustré (fonds embarqués
-- dans l'addon, affichés sans validation) ou peint ; essai manuel des candidats du client (repli facultatif :
-- seul moyen de savoir si un fichier existe dans ce client).
local DECOR_HELP = "/slay scenery ok (image visible) or no (flat green, black or empty); "
  .. "/slay scenery next / prev; /slay scenery painted to finish."

local function trialSay(cand)
  local list = Scene.trialList()
  say("scenery test " .. Scene.trial .. "/" .. #list .. ": " .. Scene.describe(cand) .. ".")
end

local function decorCommand(arg)
  local trialCmd = arg == "test" or arg == "next" or arg == "prev"
  if trialCmd then
    if arg == "test" and Scene.trial then
      Scene.trialStop()
      say("test over; scenery " .. (opts().decor == false and "painted" or "illustrated (embedded backgrounds)") .. ".")
      return
    end
    local first = not Scene.trial
    if first and not UI.isShown() and not UI.open("decor") then return end
    local cand
    if first then cand = Scene.trialStart()
    else cand = Scene.trialStep(arg == "next" and 1 or -1) end
    trialSay(cand)
    if first then
      say(DECOR_HELP)
      if Scene.scene == false then
        say("this screen has no scenery: the test shows on the home screen, in combat, on a reward, "
          .. "at the merchant or at the campfire.")
      end
    end
  elseif arg == "ok" or arg == "no" then
    local cand = Scene.trialMark(arg == "ok")
    if not cand then say("no test in progress: /slay scenery test.") return end
    say(tostring(cand.file) .. " " .. (arg == "ok" and "accepted" or "rejected") .. " (kept in the save). "
      .. "Next: /slay scenery next.")
  elseif arg == "painted" or arg == "illustrated" or arg == "" then
    local was = Scene.trial
    if was then Scene.trialStop() end
    if arg == "" then
      if not was then opts().decor = opts().decor == false end
    else
      opts().decor = arg ~= "painted"
    end
    say((was and "test over; " or "") .. "scenery " .. (opts().decor and "illustrated (backgrounds embedded "
      .. "in the addon)" or "painted") .. ".")
    if UI.frame and UI.frame:IsShown() then UI.refresh() end
  else
    say("/slay scenery: toggle painted / illustrated; /slay scenery painted; /slay scenery illustrated; "
      .. "/slay scenery test (then next, prev, ok, no): client candidates, optional.")
  end
end

SLASH_SLAYTHEDRAGON1 = "/slay"
SLASH_SLAYTHEDRAGON2 = "/slaythedragon"
SlashCmdList.SLAYTHEDRAGON = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" then UI.toggle()
  elseif msg == "options" or msg == "config" then UI.toggleOptions()
  elseif msg == "art" then artReport()
  elseif msg == "text" then textReport()
  elseif msg == "models" then artPreview()
  elseif msg == "scenery" or msg:match("^scenery%s") then
    decorCommand(msg:match("^scenery%s*(.*)$") or "")
  elseif msg == "center" or msg == "reset" then opts().point = nil if UI.frame then UI.applyPosition() end
  elseif msg == "fire" or msg:match("^fire%s") then
    -- cadrage du modèle du feu de camp (non vérifiable hors jeu) : échelle, hauteur, orientation ;
    -- « reset » rend les valeurs d'Art.campfire. Appliqué au feu affiché, gardé dans les options.
    local a, b, c = msg:match("^fire%s+(%S+)%s+(%S+)%s+(%S+)")
    a, b, c = tonumber(a), tonumber(b), tonumber(c)
    if msg:match("^fire%s+reset") then
      opts().fireCam = nil
      say("campfire framing: defaults.")
    elseif a and b and c then
      opts().fireCam = { a, b, c }
      say(("campfire framing: scale %g, height %g, facing %g."):format(a, b, c))
    else
      local o = opts().fireCam
      say("usage: /slay fire <scale> <height> <facing>  (e.g. 1 0 0.5), or /slay fire reset; now: "
        .. (type(o) == "table" and table.concat(o, " ") or "defaults") .. ".")
      return
    end
    local camp = UI.screens.campfire
    if camp and camp.fire and camp.fire.model then Scene.fireCam(camp.fire.model) end
  elseif msg:match("^facing") then
    local p, e = msg:match("^facing%s+(%S+)%s+(%S+)")
    p, e = tonumber(p), tonumber(e)
    if p and e then
      opts().facingPlayer, opts().facingEnemy = p, e
      say("facing: player " .. p .. ", enemies " .. e .. ".")
      for _, s in pairs(UI.screens) do if s.ApplyFacing then s:ApplyFacing() end end
    else
      say("usage: /slay facing <player> <enemies>  (radians, e.g. 0.6 -0.6)")
    end
  else
    say("/slay: open/close; /slay options; /slay art (scenery, missing art); /slay models; "
      .. "/slay scenery [test]; /slay facing <p> <e>; /slay fire <scale> <height> <facing>; /slay center")
  end
end
