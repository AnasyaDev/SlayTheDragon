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
local DRAW_PILE = { 45, 554 }            -- piles : cases de 36 et libellé dessous (bas à y 588 < 614)
local DISCARD_PILE = { 95, 554 }
local EXHAUST_PILE = { 145, 554 }
local MANA_X, MANA_Y = 76, 466           -- anneau de mana (76) ; libellé « Mana » dessous
local COOLDOWN_X, COOLDOWN_Y = 940, 467  -- recharges (cases de 46)
-- Crans de la ressource : gemmes de PIP unités en arc autour de l'anneau de mana (rayon PIP_R depuis
-- son centre), du flanc droit sous la pastille (PIP_A0 degrés, 0 = à droite, sens horaire) vers le bas,
-- un cran tous les PIP_DA degrés ; hors de la main (x 200 à 10 cartes) et au-dessus du libellé « Mana ».
-- Plafond au-delà de PIPS_ROW (Combat.resCap : une épique peut porter la Rage à 10) : deux arcs, le
-- premier (intérieur) prend la moitié haute des crans, le second (rayon PIP_R2) le reste, décalé d'un
-- demi-cran ; PIPS_MAX crans au plus.
local PIP, PIPS_MAX, PIPS_ROW = 12, 12, 6
local PIP_R, PIP_A0, PIP_DA = 49, -5, 14
local PIP_R2 = PIP_R + PIP + 2
local PIP_SOCKET = { 0.3, 0.29, 0.28 }  -- alvéole : gemme désaturée assombrie
local PIP_FADE, PIP_GLOW = 0.22, 0.45   -- fondu d'un cran, éclat au remplissage (secondes)
-- Personnage d'un ennemi : 33 sous le haut de l'emplacement, pieds à 33 + FIG_H (193 à l'échelle 1) ;
-- cadre compact au-dessus de la tête, états ST_DY sous les pieds.
local FIG_H = 160
local NAME_SIZE = 11.5
local ST_DY = 10
local INFO_LEVEL = 10                    -- cadre des infos : au-dessus du personnage (modèle +2, repli +4,
                                         -- étage d'interface fig.ui +8 : Scene.UI_LIFT)
local ENEMY_TOP = 92                     -- haut de l'emplacement d'un ennemi à l'échelle 1
local ENEMY_STAGGER = 26                 -- un ennemi sur deux, posé un peu plus bas
local COUNTER_X = 517                    -- compteur de combat d'une zone (Wildfire) : centre x, haut du décor

local function now() return GetTime and GetTime() or 0 end
local function opts() return ns.Persist.options() end

local function enemyByUid(c, uid)
  for i = 1, #c.enemies do if c.enemies[i].uid == uid then return c.enemies[i], i end end
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

-- Intention (direction B) : case de barre d'action à l'icône de l'intention, chiffres exacts à droite,
-- en couleur (rouge attaque, bleu défense, violet guet…). f:SetColor(c) teint le chiffre.
local INTENT_SLOT = 26
local function intentBubble(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(INTENT_SLOT + 60, INTENT_SLOT)
  f:EnableMouse(true)
  local box = CreateFrame("Frame", nil, f)
  box:SetSize(INTENT_SLOT, INTENT_SLOT)
  box:SetPoint("LEFT", 0, 0)
  f.slot = W.slotOn(box, INTENT_SLOT)
  f.icon = f.slot.icon
  f.text = W.label(f, "heavy", 19, C.attackText)
  f.text:SetPoint("LEFT", box, "RIGHT", 4, 0.5)
  f.SetColor = function(self, c) self.text:SetTextColor(c[1], c[2], c[3]) end
  W.tooltip(f, function(tt, self) V.fillIntentTooltip(tt, self.enemy) end, "ANCHOR_TOP")
  return f
end

-- Personnage d'un emplacement posé par les pieds (zone de clic : l'emplacement lui-même).
local function placeFig(s)
  local k = s.fig:GetScale() or 1
  local h = s.figH or 160
  s.fig:ClearAllPoints()
  s.fig:SetPoint("BOTTOM", s, "TOP", 0, -(33 + h) / k)
end

-- Cadre compact (direction B) au-dessus de la tête, intention dessous ; états sous les pieds. Le
-- cadre ne sort jamais du haut du décor (FRAME_MIN_Y, coordonnées du contenu).
local FRAME_W, FRAME_H, BOSS_H = 114, 46, 62
local FRAME_MIN_Y = Scene.TOP + 4
V.FRAME_W, V.FRAME_H = FRAME_W, FRAME_H
local function placeInfo(s)
  local feet = 33 + (s.figH or FIG_H)
  local sc = s:GetScale() or 1
  local h = s.tag:GetHeight() or FRAME_H
  local y = 33 + 10 - h
  local absTop = Scene.TOP + (s.top or 0)
  local minRel = (FRAME_MIN_Y - absTop) / sc
  if y < minRel then y = minRel end
  s.tag:ClearAllPoints()
  s.tag:SetPoint("TOP", s, "TOP", 0, -y)
  s.intent:ClearAllPoints()
  s.intent:SetPoint("TOPLEFT", s.tag, "BOTTOMLEFT", 6, -3)
  s.st:ClearAllPoints()
  s.st:SetPoint("TOP", s, "TOP", 0, -(feet + ST_DY))
end

-- Ennemi visé (carte à cible armée) : son anneau s'allume ; il ne grandit plus (aucune échelle au
-- survol dans l'addon).
local function aimApply(s)
  local v = W.animValue(s, "aim")
  placeFig(s)
  if s.fig.ring:IsShown() then s.fig.ring:SetAlpha(0.45 + 0.55 * max(v, s.ringBase or 0)) end
end

-- Pose le cadre compact d'un ennemi : ordinaire (trois tranches) ou élite / boss (dragon d'or) ; w =
-- largeur du cadre ordinaire (le cadre d'élite garde ses proportions, réduit au besoin).
local function setUnitFrame(s, boss, w)
  local WS = W.Wow
  local meta
  local tag = s.tag
  if boss then
    local e = WS.pieces.unit_boss
    local h = BOSS_H
    local ww = h * e.pw / e.ph
    local k = math.min(1, (w + 12) / ww)
    h, ww = h * k, ww * k
    tag:SetSize(ww, h)
    tag.plain:Hide()
    tag.boss:Show()
    meta = WS.meta.unit_boss
    tag.kk = h / e.ph
  else
    tag:SetSize(w, FRAME_H)
    tag.plain:Show()
    tag.boss:Hide()
    meta = WS.meta.unit_enemy
    tag.kk = FRAME_H / WS.pieces.unit_enemy.ph
  end
  -- logements (pixels stockés de la pièce) -> unités ; en trois tranches, x pris depuis les bords
  local kk = tag.kk
  local pw = boss and WS.pieces.unit_boss.pw or WS.pieces.unit_enemy.pw
  local function box(r)
    local x0, x1 = r[1] * kk, r[1] * kk + r[3] * kk
    if not boss then x1 = w - (pw - r[1] - r[3]) * kk end
    return x0, -r[2] * kk, x1 - x0, r[4] * kk
  end
  local x, y, bw, bh = box(meta.name)
  s.name:ClearAllPoints()
  s.name:SetPoint("CENTER", tag, "TOPLEFT", x + bw / 2, y - bh / 2)
  s.nameW = bw - 6
  x, y, bw, bh = box(meta.hp)
  s.hp:ClearAllPoints()
  s.hp:SetPoint("TOPLEFT", tag, "TOPLEFT", x, y)
  s.hp:SetSize(bw, bh)
  s.hp.w = bw
  x, y, bw, bh = box(meta.low)
  s.block:ClearAllPoints()
  s.block:SetPoint("TOPLEFT", tag, "TOPLEFT", x, y)
  s.block:SetSize(bw, bh)
  s.block.w = bw
  s.frameBoss, s.frameW = boss, w
end

local function buildSlot(self, i)
  local s = CreateFrame("Button", nil, self.bf)
  s:SetSize(SLOT_W, SLOT_H)
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s.index = i
  s.fig = Scene.figure(s, 150, 160)
  s.figH = 160
  placeFig(s)
  s.fig:EnableMouse(false)
  s._animApply = aimApply
  s.model = s.fig.model
  s.fallback = s.fig.fallback
  -- éclat d'un coup : sur l'étage d'interface du personnage, par-dessus le modèle
  s.flash = W.disc(s.fig.ui, "OVERLAY", 0, C.hp, 0)
  s.flash:SetSize(110, 130)
  s.flash:SetPoint("CENTER", 0, 4)
  -- Infos (cadre compact : nom, vie, Absorption ; intention ; états) dans un cadre au-dessus du
  -- personnage et de son repli : aucun modèle, ombre ou anneau ne peut les recouvrir.
  s.info = CreateFrame("Frame", nil, s)
  s.info:SetAllPoints()
  s.info:SetFrameLevel(s:GetFrameLevel() + INFO_LEVEL)
  s.tag = CreateFrame("Frame", nil, s.info)
  s.tag:SetFrameLevel(s.info:GetFrameLevel() + 5) -- au-dessus des jetons d'état
  s.tag:SetSize(FRAME_W, FRAME_H)
  s.tag.plain = W.threeSlice(s.tag, "unit_enemy", "BACKGROUND", 0)
  s.tag.boss = W.wow(s.tag, "unit_boss", "BACKGROUND", 0)
  s.tag.boss:SetAllPoints()
  s.tag.boss:Hide()
  s.name = W.label(s.tag, "bold", NAME_SIZE, C.text, "OVERLAY")
  s.name:SetWordWrap(false)
  s.hp = W.hpBar(s.tag, 100, 10, 9.5, "bar_enemy")
  s.block = W.shieldBadge(s.tag, 100, 8)
  s.intent = intentBubble(s.info)
  s.intent:SetFrameLevel(s.tag:GetFrameLevel() + 2)
  -- Zones (UI/ZoneView.lua) : petite icône à droite de l'intention (Bite de Duskwood), intention
  -- suivante en gris dessous (« On waking: Death Roll 20 »), primes sous l'intention (Pack), crans de vie.
  s.intent.badge = W.noSnap(s.intent:CreateTexture(nil, "OVERLAY", nil, 1))
  s.intent.badge:SetSize(14, 14)
  s.intent.badge:Hide()
  s.next = W.label(s.info, "bold", 10.5, C.textDim, "OVERLAY")
  s.next:SetPoint("TOPLEFT", s.intent, "BOTTOMLEFT", 2, -1)
  s.next:SetJustifyH("LEFT")
  s.next:SetWordWrap(false)
  s.next:Hide()
  s.badges = {}
  for k = 1, 3 do
    local b = CreateFrame("Frame", nil, s.info)
    b:SetSize(SLOT_W - 20, 16)
    b:SetFrameLevel(s.tag:GetFrameLevel() + 1)
    b:EnableMouse(true)
    b.icon = W.noSnap(b:CreateTexture(nil, "ARTWORK", nil, 0))
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("LEFT", 0, 0)
    b.text = W.label(b, "bold", 10.5, C.text, "OVERLAY")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 3, 0)
    b.text:SetJustifyH("LEFT")
    W.tooltip(b, function(tt, f) if f.tip then tt:AddLine(f.tip, 1, 1, 1, true) end end, "ANCHOR_TOP")
    b:Hide()
    s.badges[k] = b
  end
  s.marks = {}
  for k = 1, 4 do
    local m = W.rect(s.hp, "OVERLAY", 3, C.goldText, 0.95)
    m:SetSize(2, 10)
    m:Hide()
    s.marks[k] = m
  end
  s.st = W.tokenRow(s.info, 6, SLOT_W + 10, 24)
  setUnitFrame(s, false, FRAME_W)
  placeInfo(s)
  s:SetScript("OnClick", function(_, button) V:ClickEnemy(s, button) end)
  s:SetScript("OnEnter", function() s.hover = true V:RenderTargets() end)
  s:SetScript("OnLeave", function() s.hover = false V:RenderTargets() end)
  s:Hide()
  return s
end

-- Pile (pioche, défausse, consumées) : case de barre d'action à l'icône du tas, nombre, libellé doré
-- dessous ; clic = consulter (panneau du deck, pioche triée).
local PILE_SLOT = 36
local function pile(self, parent, cx, cy, key, label, short, entry, level)
  local b = CreateFrame("Button", nil, parent)
  at(b, parent, cx - PILE_SLOT / 2, cy - PILE_SLOT / 2, PILE_SLOT, PILE_SLOT)
  b:SetFrameLevel(level + 1)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  b.slot = W.slotOn(face, PILE_SLOT)
  W.setIcon(b.slot.icon, entry, "ui:pile:" .. key)
  b.count = W.label(face, "heavy", 15, C.text, "OVERLAY")
  b.count:SetPoint("BOTTOMRIGHT", face, "BOTTOMRIGHT", -1, 1)
  b.label = W.label(b, "bold", 11.5, C.wowGold)
  b.label:SetPoint("TOP", b, "BOTTOM", 0, -3)
  b.label:SetText(short)
  -- survol : cadre doré de la case en fondu, sans grossir ni bouger (le nombre reste stable)
  W.hoverable(b, { paint = function(f, h) f.slot.hot:SetAlpha(h) end })
  b.pileKey = key
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then return end
    W.sound("click")
    UI.toggleDeckView(key)
  end)
  W.tooltip(b, function(tt) V.fillPileTooltip(tt, key, label) end, "ANCHOR_RIGHT")
  return b
end
-- Cadre d'unité du héros (direction B) : UI-HUD-UnitFrame-Player, portrait dans l'anneau, nom, barre de
-- vie, Absorption dans le logement bas ; états (auras) dessous. Position : coin haut gauche du décor.
local HERO_FRAME_X, HERO_FRAME_Y, HERO_K = 12, 42, 0.735
local function heroFrame(self, parent, level)
  local WS = W.Wow
  local e, m = WS.pieces.unit_player, WS.meta.unit_player
  local k = HERO_K
  local f = CreateFrame("Frame", nil, parent)
  at(f, parent, HERO_FRAME_X, HERO_FRAME_Y, e.pw * k, e.ph * k)
  f:SetFrameLevel(level)
  -- portrait : visage du personnage (SetPortraitTexture), sinon icône de classe ; sous l'anneau du cadre
  f.portrait = W.noSnap(f:CreateTexture(nil, "BACKGROUND", nil, 0))
  local p = m.portrait
  at(f.portrait, f, p[1] * k, p[2] * k, p[3] * k, p[4] * k)
  W.roundMask(f, f.portrait)
  f.art = W.wow(f, "unit_player", "BORDER", 0)
  f.art:SetAllPoints()
  local nb = m.name
  f.name = W.label(f, "bold", 13, C.wowGold, "OVERLAY")
  f.name:SetPoint("LEFT", f, "TOPLEFT", nb[1] * k + 2, -(nb[2] + nb[4] / 2) * k)
  local hb = m.hp
  self.playerHp = W.hpBar(f, hb[3] * k, hb[4] * k, 12, "bar_hp")
  self.playerHp:SetPoint("TOPLEFT", f, "TOPLEFT", hb[1] * k, -hb[2] * k)
  self.playerHp:SetFrameLevel(level + 1)
  local ab = m.absorb
  self.playerBlock = W.shieldBadge(f, ab[3] * k, ab[4] * k)
  self.playerBlock:SetPoint("TOPLEFT", f, "TOPLEFT", ab[1] * k, -ab[2] * k)
  self.playerBlock:SetFrameLevel(level + 1)
  -- Portrait : visage du personnage s'il est de la classe jouée (UnitClass), sinon icône de la classe.
  f.SetPortrait = function(fr)
    local exp = Controller.exp()
    local class = exp and exp.class or "priest"
    local art = Art.class(class)
    local same = false
    if UnitClass then
      local ok, _, file = pcall(UnitClass, "player")
      same = ok and file ~= nil and file == art.wow
    end
    local ok = false
    if same and SetPortraitTexture then ok = pcall(SetPortraitTexture, fr.portrait, "player") end
    if ok then fr.portrait:SetTexCoord(0, 1, 0, 1) fr.portrait._unit = "player" fr.portrait._class = class
    else
      W.setIcon(fr.portrait, art, "ui:class")
      fr.portrait._unit = nil
      fr.portrait._class = class
    end
  end
  f:EnableMouse(false)
  self.heroFrame = f
  return f
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
  hero.flash = W.disc(hero.ui, "OVERLAY", 0, C.hp, 0)
  hero.flash:SetSize(130, 160)
  hero.flash:SetPoint("CENTER", 0, 0)

  -- Cadre d'unité, états dessous (auras alignées à gauche, sous les barres).
  local hf = heroFrame(self, parent, bf:GetFrameLevel() + 15)
  self.playerSt = W.tokenRow(parent, 8, 220, 24)
  self.playerSt.align = "LEFT"
  at(self.playerSt, parent, HERO_FRAME_X + W.Wow.meta.unit_player.hp[1] * HERO_K, HERO_FRAME_Y + hf:GetHeight() + 4, 220, 24)
  self.playerSt:SetFrameLevel(bf:GetFrameLevel() + 15)

  -- Barre d'incantation : case du sort, nom, barre jaune du jeu dans un rail (à droite du cadre d'unité).
  local cast = CreateFrame("Frame", nil, parent)
  at(cast, parent, HERO_FRAME_X + hf:GetWidth() + 10, HERO_FRAME_Y + 14, 196, 34)
  cast:SetFrameLevel(parent:GetFrameLevel() + 20)
  local box = CreateFrame("Frame", nil, cast)
  box:SetSize(30, 30)
  box:SetPoint("LEFT", 0, 0)
  cast.slot = W.slotOn(box, 30)
  cast.medal = { icon = cast.slot.icon } -- compatibilité
  cast.name = W.label(cast, "bold", 12.5, C.text)
  cast.name:SetPoint("LEFT", cast, "LEFT", 38, 7)
  cast.name:SetWidth(154)
  cast.name:SetJustifyH("LEFT")
  cast.name:SetWordWrap(false)
  local rail = CreateFrame("Frame", nil, cast)
  rail:SetSize(154, 13)
  rail:SetPoint("LEFT", cast, "LEFT", 38, -8)
  local l, mm, r = W.wow(rail, "slider_l", "BACKGROUND", 0), W.wow(rail, "slider_m", "BACKGROUND", 0),
    W.wow(rail, "slider_r", "BACKGROUND", 0)
  l:SetSize(8, 13) l:SetPoint("LEFT")
  r:SetSize(8, 13) r:SetPoint("RIGHT")
  mm:SetPoint("TOPLEFT", l, "TOPRIGHT") mm:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
  cast.track = rail
  cast.bar = W.wow(rail, "bar_yellow", "ARTWORK", 0)
  cast.bar:SetPoint("LEFT", rail, "LEFT", 3, 0)
  cast.bar:SetSize(92, 7)
  W.setWow(cast.bar, "bar_yellow", { 0, 0.62, 0, 1 })
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

  -- Ennemis ----------------------------------------------------------------
  self.slots = {}
  for i = 1, SLOTS do self.slots[i] = buildSlot(self, i) end
  self.slotOf = {}

  -- Plateau : mana, Démence, piles ----------------------------------------------
  local hz = CreateFrame("Frame", nil, parent)
  at(hz, parent, 0, Scene.BOARD_Y, Scene.W, Scene.BOARD_H)
  hz:SetFrameLevel(parent:GetFrameLevel() + 10)
  self.hz = hz

  -- Mana (direction C) : grand anneau doré autour de l'orbe de mana, « 2/3 » au centre, libellé « Mana ».
  local mana = CreateFrame("Frame", nil, parent)
  at(mana, parent, MANA_X - 38, MANA_Y - 38, 76, 76)
  mana:SetFrameLevel(hz:GetFrameLevel() + 2)
  mana:EnableMouse(true)
  W.medallionOn(mana, 76)
  W.setIcon(mana.icon, Art.ui.mana, "ui:mana")
  mana.shade = W.disc(mana, "ARTWORK", 0, C.black, 0.25)
  mana.shade:SetAllPoints(mana.icon)
  mana.text = W.label(mana, "heavy", 30, C.text, "OVERLAY")
  mana.text:SetPoint("CENTER", -7, 1)
  mana.max = W.label(mana, "heavy", 17, Art.hex("#d6e6ff"), "OVERLAY")
  mana.max:SetPoint("LEFT", mana.text, "RIGHT", 0, -5)
  mana.label = W.label(mana, "bold", 13, C.wowGold, "OVERLAY")
  mana.label:SetPoint("TOP", mana, "BOTTOM", 0, -2)
  mana.label:SetText("Mana")
  W.tooltip(mana, function(tt)
    tt:AddLine("Mana", 0.4, 0.6, 1)
    tt:AddLine("Unspent mana is lost at the end of the turn.", 0.8, 0.8, 0.8, true)
  end, "ANCHOR_RIGHT")
  self.mana = mana

  -- Ressource de classe (Insanity, Rage…) : petit anneau doré à l'icône de la ressource
  -- (Art.classes[classe].resource), en haut à droite du mana, caché à 0 ; infobulle = explication.
  local dem = CreateFrame("Frame", nil, parent)
  at(dem, parent, MANA_X + 46 - 18, MANA_Y - 30 - 18, 36, 36)
  dem:SetFrameLevel(hz:GetFrameLevel() + 3)
  dem:EnableMouse(true)
  dem.icon = W.noSnap(dem:CreateTexture(nil, "ARTWORK", nil, 0))
  dem.icon:SetPoint("TOPLEFT", 5, -5)
  dem.icon:SetPoint("BOTTOMRIGHT", -5, 5)
  W.roundMask(dem, dem.icon)
  W.setIcon(dem.icon, Art.classResource("priest"), "ui:resource")
  dem.ring = W.wow(dem, "ring_small", "ARTWORK", 1)
  dem.ring:SetAllPoints()
  dem.text = W.label(dem, "heavy", 15, C.text)
  dem.text:SetPoint("CENTER", 0, 1)
  W.tooltip(dem, function(tt)
    local c = Controller.combat()
    local rd = c and ns.Classes[c.class] and ns.Classes[c.class].resource
    local rid = rd and rd.id or "insanity"
    tt:AddLine(Art.keywordLine("res:" .. rid), 1, 1, 1, true)
    if rd and rd.cap then tt:AddLine(("%d / %d"):format(c.player.res or 0, Combat.resCap(c) or rd.cap), 0.8, 0.8, 0.8) end
  end, "ANCHOR_RIGHT")
  self.resource = dem
  self.demence = dem -- ancien nom

  -- Crans de la ressource (Rage 5, Combo 5, Charge 4, Frenzy 5 ; aucun sans plafond, Insanity) : petites
  -- gemmes en losange en arc autour de l'anneau de mana, sous la pastille, comme les points de combo du
  -- jeu (alvéole sombre, gemme pleine à la couleur de la ressource). Gemme de rareté du pack embarquée
  -- (Media/gem_rare.tga) désaturée puis teintée : aucune texture de plus. Un cran qui se remplit ou se
  -- vide passe en fondu (éclat doux en plus au remplissage), sans échelle. Visibles dès que la classe a
  -- un plafond, même à 0 (les alvéoles disent le plafond). Cadre sans souris (il couvre l'anneau de mana,
  -- dont il ne doit pas voler l'infobulle) : l'infobulle de la ressource reste celle de la pastille.
  local pips = CreateFrame("Frame", nil, parent)
  local box = 2 * (PIP_R2 + PIP)
  at(pips, parent, MANA_X - box / 2, MANA_Y - box / 2, box, box)
  pips:SetFrameLevel(hz:GetFrameLevel() + 3)
  pips:EnableMouse(false)
  pips.list = {}
  for i = 1, PIPS_MAX do
    local p = {}
    p.socket = W.skin(pips, "gem_rare", "ARTWORK", 0)
    p.socket:SetDesaturated(true)
    p.socket:SetVertexColor(PIP_SOCKET[1], PIP_SOCKET[2], PIP_SOCKET[3], 1)
    p.fill = W.skin(pips, "gem_rare", "ARTWORK", 1)
    p.fill:SetDesaturated(true)
    p.fill:SetAlpha(0)
    p.glow = W.skin(pips, "glow_round", "ARTWORK", 2)
    if p.glow.SetBlendMode then p.glow:SetBlendMode("ADD") end
    p.glow:SetAlpha(0)
    for _, t in ipairs({ p.socket, p.fill }) do t:SetSize(PIP, PIP) end
    p.glow:SetSize(PIP * 2.2, PIP * 2.2)
    p.glow:SetPoint("CENTER", p.socket, "CENTER", 0, 0)
    pips.list[i] = p
  end
  V.layoutPips(pips, PIPS_ROW)
  pips:Hide()
  self.resPips = pips

  -- Zone libre de la classe (familier, Traps, marques sur les ennemis…) : cadre vide sous les états du
  -- héros, rempli par ns.ClassViews[classe] (build(zone, vue) une fois, render(zone, combat, vue) à chaque
  -- rendu). Aucun texte permanent : ce qu'une épique ou un pouvoir fait maintenant va sur son jeton des
  -- états du héros (tokens(combat, liste, vue), RenderPlayer). Contrat : docs/classes.md.
  local zone = CreateFrame("Frame", nil, parent)
  at(zone, parent, HERO_FRAME_X, HERO_FRAME_Y + hf:GetHeight() + 32, 300, 40)
  zone:SetFrameLevel(bf:GetFrameLevel() + 15)
  zone.views = {}
  self.classZone = zone
  -- Maj enfoncée ou relâchée : la ligne « Spend N: » des cartes en main s'éteint ou se rallume
  zone:RegisterEvent("MODIFIER_STATE_CHANGED")
  zone:SetScript("OnEvent", function(_, _, key)
    if (key == "LSHIFT" or key == "RSHIFT") and self.c and parent:IsVisible() and not self.frozen then self:RenderHand() end
  end)

  self.drawPile = pile(self, parent, DRAW_PILE[1], DRAW_PILE[2], "draw", "Draw pile", "Draw", Art.ui.grimoire,
    hz:GetFrameLevel() + 1)
  self.discardPile = pile(self, parent, DISCARD_PILE[1], DISCARD_PILE[2], "discard", "Discard pile", "Discard",
    Art.ui.bag, hz:GetFrameLevel() + 1)
  self.exhaustPile = pile(self, parent, EXHAUST_PILE[1], EXHAUST_PILE[2], "exhaust", "Exhausted", "Exhaust",
    Art.ui.remove, hz:GetFrameLevel() + 1)
  self.exhaustPile:Hide()

  -- Recharges (cases de barre d'action : icône grisée, tours restants) et fin du tour ---------------
  self.cdCards = {}
  for i = 1, 6 do
    local m = CreateFrame("Frame", nil, parent)
    m:SetSize(42, 42)
    m:SetFrameLevel(hz:GetFrameLevel() + 2)
    m:EnableMouse(true)
    m.slot = W.slotOn(m, 42)
    m.icon = m.slot.icon
    m.icon:SetDesaturated(true)
    m.icon:SetVertexColor(0.6, 0.6, 0.6, 1)
    m.count = W.label(m, "heavy", 22, C.text, "OVERLAY")
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

  self.endTurn = W.button(parent, "End Turn", 168, 50, function(_, button) V:EndTurn(button) end, "gold", 20)
  at(self.endTurn, parent, 852, 520, 168, 50)
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
    card.onEnterExtra = function(f) f.hover = true V:PlaceCard(f) end
    card.onLeaveExtra = function(f) f.hover = false V:PlaceCard(f) end
    card:Hide()
    self.cards[i] = card
  end

  -- Fin de combat : boîte de dialogue du jeu, « Victoire ! » en grand, bouton rouge et or ---------------
  local banner = W.dialog(parent, nil)
  at(banner, parent, 317, 140, 400, 150)
  banner:SetFrameLevel(parent:GetFrameLevel() + 70)
  banner.text = W.label(banner, "heavy", 42, C.goldText, "OVERLAY")
  banner.text:SetPoint("TOP", 0, -20)
  banner.button = W.button(banner, "Continue", 190, 48, function() Controller.finishCombat() end, "gold", 18)
  banner.button:SetPoint("BOTTOM", 0, 18)
  banner:Hide()
  self.banner = banner

  -- Zones : compteur de combat en haut au centre du décor (Wildfire : ns.ZoneViews[zone].counter), calque
  -- libre des vues de zone (build / render / event, comme ns.ClassViews), sans souris.
  local counter = CreateFrame("Frame", nil, parent)
  at(counter, parent, COUNTER_X - 70, Scene.TOP + 6, 140, 34)
  counter:SetFrameLevel(bf:GetFrameLevel() + 16)
  counter:EnableMouse(true)
  local cbox = CreateFrame("Frame", nil, counter)
  cbox:SetSize(30, 30)
  cbox:SetPoint("LEFT", 0, 0)
  counter.slot = W.slotOn(cbox, 30)
  counter.text = W.label(counter, "heavy", 15, C.goldText, "OVERLAY")
  counter.text:SetPoint("LEFT", cbox, "RIGHT", 5, 0.5)
  counter.text:SetJustifyH("LEFT")
  W.tooltip(counter, function(tt, f) if f.tip then tt:AddLine(f.tip, 1, 1, 1, true) end end, "ANCHOR_BOTTOM")
  counter:Hide()
  self.counter = counter
  local zhost = CreateFrame("Frame", nil, parent)
  at(zhost, parent, 0, Scene.TOP, Scene.W, Scene.DECOR_H)
  zhost:SetFrameLevel(bf:GetFrameLevel() + 15)
  zhost:EnableMouse(false)
  zhost.views = {}
  self.zoneHost = zhost

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
  heal_allies = function(a) return "Heals each enemy for " .. a[2] .. "." end,
  heal_self = function(a) return "Heals itself for " .. a[2] .. "." end,
  block_allies = function(a) return "Gives " .. a[2] .. " Absorb to each enemy." end,
  block_boss = function(a) return "Gives " .. a[2] .. " Absorb to its leader." end,
  die = function() return "Destroys itself." end,
  addCard = function(a)
    local d = ns.Cards[a[2]]
    local where = a.to == "hand" and "your hand" or (a.to == "draw" and "the top of your draw pile") or "your discard"
    return "Adds " .. (d and d.name or a[2]) .. " to " .. where .. "."
  end,
}

-- Texte d'une action d'intention : actions communes, puis celles des zones (Art.actionText).
local function actionLine(c, e, a)
  local f = ACTION_TEXT[a[1]] or Art.actionText[a[1]]
  return f and f(a, c, e) or nil
end

function V.fillIntentTooltip(tt, e)
  local c = Controller.combat()
  if not c or not e or e.dead then return end
  local info = Combat.intentInfo(c, e)
  local mv = ns.Combat.moveOf(e.id, e.intent)
  -- intention remplacée par une zone (dormeur) : son infobulle d'abord
  local over = ns.ZoneView.first(c, "intent", e)
  if over then
    if over.title then tt:AddLine(over.title, 1, 0.82, 0) end
    if over.tip then tt:AddLine(over.tip, 1, 1, 1, true) end
  end
  if not over or over.showMove then
    tt:AddLine(info.name or e.intent, 1, 0.82, 0)
    tt:AddLine(Art.intentName[info.kind] or info.kind or "", 0.7, 0.7, 0.7)
    if info.stunned then tt:AddLine("Stunned: loses its next turn.", 0.4, 0.9, 1, true) end
    if info.interrupted then tt:AddLine("Spell interrupted: it won't go off.", 0.4, 0.9, 1, true) end
    if mv.text then tt:AddLine(mv.text, 1, 1, 1, true) end
    for i = 1, #mv.actions do
      local a = mv.actions[i]
      if a[1] == "attack" then
        local times = a.times or 1
        tt:AddLine("Attack: " .. Combat.calcDamage(c, e, c.player, Combat.enemyBase(c, e, a))
          .. (times > 1 and (" × " .. times) or "") .. " damage.", 1, 0.5, 0.5, true)
        if a.interrupts then tt:AddLine("Interrupts your cast.", 1, 0.5, 0.5, true) end
      else
        local line = actionLine(c, e, a)
        if line then tt:AddLine(line, 1, 1, 1, true) end
      end
    end
    if info.cast and not info.interrupted then
      tt:AddLine("Spell being cast: an Interrupt cancels it.", 1, 0.6, 0.2, true)
    end
  end
  -- intention suivante imposée (ouverture d'une phase, d'un dormeur)
  if info.forced then
    local fm = ns.Combat.moveOf(e.id, info.forced)
    tt:AddLine((info.forcedLabel or "Next") .. ": " .. (fm and fm.name or info.forced) .. ".", 0.7, 0.7, 0.7, true)
  end
  local badge = ns.ZoneView.first(c, "intentBadge", e)
  if badge and badge.tip then tt:AddLine(badge.tip, 0.75, 0.6, 1, true) end
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
    self.aimTarget = nil
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
    self.resPips.class = nil -- nouveau combat : crans posés sans animation
    self.keepMode = nil
  end
  self:ApplyFacing()
  self:Render(true)
end

function V:OnHide()
  self.queue = {}
  self.playing = false
  self.frozen = false
  self:ExitKeep(true)
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
      s.artKey = nil
      W.animSet(s, "aim", 0)
      s:SetAlpha(1)
      s.hp:Set(e.hp, e.maxHp)
      s.block:Set(e.block, e.maxHp)
    end
    -- modèle (e.art : modèle d'une phase, Nefarius -> Nefarian) : apparaît en fondu une fois chargé
    -- (ombre avec lui) ; médaillon si aucun candidat ne charge
    local artKey = e.art or e.id
    if s.artKey ~= artKey then
      s.artKey = artKey
      local art = Art.enemies[artKey] or {}
      local sc = art.scale or 1
      -- taille de base ; art.wide (quadrupède long) l'élargit, centrée, à hauteur égale (Scene.setWide,
      -- dans Scene.showModel) : pieds, cadre d'unité, intention et ombre ne bougent pas
      Scene.setFigureSize(s.fig, 150 * sc, 160 * sc)
      s.figH = FIG_H * sc
      Scene.enemyFigure(s.fig, artKey)
    end
    s.enemyIndex = idx
    s.cx = cx0 + (k - 1) * spacing
    -- personnage agrandi (art.scale) : l'emplacement remonte, les pieds restent sur la même ligne
    s.top = ENEMY_TOP + ((k % 2 == 0) and ENEMY_STAGGER or 0) - Scene.TOP - ((s.figH or FIG_H) - FIG_H)
    local sc = n >= 5 and 0.86 or 1
    s:SetScale(sc)
    -- cadre compact : ordinaire, ou d'élite / boss (dragon d'or) ; jamais plus large que l'écart
    local def = ns.Enemies[e.id]
    setUnitFrame(s, def.boss or def.elite, min(FRAME_W, spacing / sc - 8))
    placeInfo(s)
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
  -- intention remplacée par une zone (dormeur : « Asleep 2 »), sinon la bulle commune
  local over = ns.ZoneView.first(c, "intent", e)
  if over then return over.icon or Art.intents.defend, over.text or "", over.color or "defend", over.key end
  local info = Combat.intentInfo(c, e)
  if info.stunned then return Art.intents.stunned, "Stunned", "defend" end
  if info.interrupted then return Art.intents.interrupted, "Interrupted", "defend" end
  local mv = ns.Combat.moveOf(e.id, e.intent)
  local parts = {}
  for i = 1, #mv.actions do
    local a = mv.actions[i]
    if a[1] == "attack" then
      local times = a.times or 1
      local dmg = Combat.calcDamage(c, e, c.player, Combat.enemyBase(c, e, a))
      parts[#parts + 1] = dmg .. (times > 1 and ("×" .. times) or "")
    elseif a[1] == "block" or a[1] == "block_ally" or a[1] == "block_allies" or a[1] == "block_boss" then
      parts[#parts + 1] = (#parts > 0 and "+" or "") .. a[2]
    elseif a[1] == "heal_ally" or a[1] == "heal_allies" or a[1] == "heal_self" then
      parts[#parts + 1] = "+" .. a[2]
    elseif a[1] == "summon" then
      parts[#parts + 1] = "+" .. (a.count or 1)
    elseif Art.intentParts[a[1]] then
      local p = Art.intentParts[a[1]](c, e, a)
      if p and p ~= "" then parts[#parts + 1] = p end
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
  if e.dead or c.result then
    s.intent:Hide()
    s.next:Hide()
    return
  end
  local entry, text, color, key = intentDisplay(c, e)
  W.setIcon(s.intent.icon, entry, key or ("intent:" .. tostring(Combat.intentInfo(c, e).kind)))
  s.intent:SetColor(C[(color or "attack") .. "Text"] or C.attackText)
  local big = W.utf8len(text) <= 3
  W.setSize(s.intent.text, big and 19 or 13.5)
  s.intent.text:SetText(text)
  local w = 30 + max(20, s.intent.text:GetStringWidth() or 20)
  -- petite icône d'une zone à droite du chiffre (Curse posée par un Bite)
  local badge = ns.ZoneView.first(c, "intentBadge", e)
  if badge and badge.icon then
    W.setIcon(s.intent.badge, badge.icon, badge.key or "intent:badge")
    s.intent.badge:ClearAllPoints()
    s.intent.badge:SetPoint("LEFT", s.intent.text, "RIGHT", 3, 0)
    s.intent.badge:Show()
    w = w + 17
  else
    s.intent.badge:Hide()
  end
  s.intent:SetWidth(w)
  s.intent:SetAlpha(1)
  s.intent:SetScale(1)
  s.intent:Show()
  -- intention suivante imposée, en gris (« On waking: Death Roll 20 »)
  local info = Combat.intentInfo(c, e)
  local fm = info.forced and ns.Combat.moveOf(e.id, info.forced)
  if fm and info.forcedLabel then
    local dmg
    for _, a in ipairs(fm.actions) do
      if a[1] == "attack" then
        dmg = Combat.calcDamage(c, e, c.player, Combat.enemyBase(c, e, a)) .. ((a.times or 1) > 1 and ("×" .. a.times) or "")
        break
      end
    end
    s.next:SetText(info.forcedLabel .. ": " .. fm.name .. (dmg and (" " .. dmg) or ""))
    s.next:Show()
  else
    s.next:Hide()
  end
end

-- Primes et crans d'une zone sur un ennemi (sous l'intention ; traits sur la barre de vie).
function V:RenderZoneEnemy(s, e)
  local c = self.c
  local list = (e.dead or c.result) and {} or ns.ZoneView.all(c, "enemyBadges", e)
  -- trait commun des élites Stun Resistant, après ceux de la zone
  if not (e.dead or c.result) and Combat.stunResistant(e) then list[#list + 1] = Art.stunResistBadge(e) end
  local anchor = s.next:IsShown() and s.next or s.intent
  for k, b in ipairs(s.badges) do
    local it = list[k]
    if it then
      W.setIcon(b.icon, it.icon or { icon = Art.QUESTION }, it.key or ("badge:" .. k))
      b.icon:SetDesaturated(it.dim and true or false)
      b.text:SetText(it.text or "")
      local col = it.color and (C[it.color] or it.color) or C.text
      b.text:SetTextColor(col[1], col[2], col[3])
      b.tip = it.tip
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", k == 1 and 0 or 0, -2)
      b:Show()
      anchor = b
    else
      b.tip = nil
      b:Hide()
    end
  end
  -- crans de vie : phases (def.phases) puis ceux des zones ; infobulle de la barre
  local marks = Combat.phaseMarks(e)
  for _, m in ipairs(ns.ZoneView.all(c, "marks", e)) do marks[#marks + 1] = m end
  local w = s.hp.w or s.hp:GetWidth() or 100
  local h = s.hp:GetHeight() or 10
  for k, t in ipairs(s.marks) do
    local m = marks[k]
    if m and not e.dead then
      t:ClearAllPoints()
      t:SetSize(2, h)
      t:SetPoint("CENTER", s.hp, "LEFT", w * m.at, 0)
      local col = m.passed and C.textDim or (m.color and (C[m.color] or m.color)) or C.goldText
      t:SetVertexColor(col[1], col[2], col[3], 1)
      t:Show()
    else
      t:Hide()
    end
  end
  s.hp.extraTip = #marks > 0 and function(tt)
    for _, m in ipairs(marks) do
      local pct = math.floor((m.frac or m.at) * 100 + 0.5)
      local line = "Below " .. pct .. "%: " .. (m.name or "") .. (m.text and (". " .. m.text) or "")
      tt:AddLine(line, m.passed and 0.6 or 1, m.passed and 0.6 or 0.82, m.passed and 0.6 or 0, true)
    end
  end or nil
end

-- Compteur de combat d'une zone (Wildfire) et calque libre des vues de zone.
function V:RenderZone()
  local c = self.c
  local spec = ns.ZoneView.first(c, "counter")
  local f = self.counter
  if spec and not c.result then
    W.setIcon(f.slot.icon, spec.icon or { icon = Art.QUESTION }, spec.key or "zone:counter")
    f.slot.icon:SetDesaturated(spec.hot == false)
    f.text:SetText(spec.text or tostring(spec.value or ""))
    local col = spec.hot and C.attackText or C.goldText
    f.text:SetTextColor(col[1], col[2], col[3])
    f.tip = spec.tip
    f:Show()
  else
    f.tip = nil
    f:Hide()
  end
  local host = self.zoneHost
  local active = {}
  for _, id in ipairs({ c.zone, unpack(c.zr or {}) }) do
    local zv = id and ns.ZoneViews[id]
    if zv and (zv.build or zv.render) and not active[id] then
      active[id] = true
      local h = host.views[id]
      if not h then
        h = CreateFrame("Frame", nil, host)
        h:SetAllPoints()
        if zv.build then zv.build(h, self) end
        host.views[id] = h
      end
      h:Show()
      if zv.render then zv.render(h, c, self) end
    end
  end
  for id, h in pairs(host.views) do if not active[id] then h:Hide() end end
end

-- full = resynchroniser barres et états sur le moteur (hors animations).
function V:RenderEnemies(full)
  local c = self.c
  self:LayoutEnemies()
  for uid, s in pairs(self.slotOf) do
    local e = enemyByUid(c, uid)
    local def = ns.Enemies[e.id]
    local name = Combat.enemyName(e) -- une phase peut renommer l'ennemi
    if s.nameText ~= name or s.nameFitW ~= s.nameW then
      s.nameFitW, s.nameText = s.nameW, name
      W.fitText(s.name, name, NAME_SIZE, s.nameW or (FRAME_W - 14), 8)
    end
    local nc = def.boss and { 1, 0.6, 0.25 } or (def.elite and C.watchText or C.text)
    s.name:SetTextColor(nc[1], nc[2], nc[3])
    if full then
      s.hp:Set(e.hp, e.maxHp)
      s.block:Set(e.block, e.maxHp)
      s.st:Set(W.unitStatuses(e))
    end
    if not self.frozen or e.dead then self:RenderIntent(s, e) end
    self:RenderZoneEnemy(s, e)
  end
  self:RenderTargets()
end

function V:SelectedInfo()
  return self.selected and Controller.handInfo(self.selected) or nil
end

-- Index de l'ennemi retenu (dernier ennemi cliqué, uid stable ; repli sur le premier vivant) : un second
-- clic sur une carte à cible la joue sur lui.
function V:AimTarget()
  local c = self.c
  if not c then return nil end
  if self.aimTarget then
    local e, i = enemyByUid(c, self.aimTarget)
    if e and not e.dead then return i end
  end
  local alive = Controller.aliveTargets()
  if alive[1] then
    self.aimTarget = c.enemies[alive[1]].uid
    return alive[1]
  end
  return nil
end

-- Anneau doré aux pieds de la cible.
function V:RenderTargets()
  if not self.c then return end
  local info = self:SelectedInfo()
  local targeting = (info and info.needsTarget) or self.potionSlot ~= nil
  local aimed = self:AimTarget()
  for _, s in pairs(self.slotOf) do
    local e = self.c.enemies[s.enemyIndex]
    local alive = e and not e.dead and not s.dying
    local on = alive and ((targeting and (s.hover or s.enemyIndex == aimed)) or s.hover)
    s.fig:SetRing(on, not targeting)
    -- visée : l'ennemi survolé (ou l'ennemi retenu) grandit, son anneau s'allume
    s.ringBase = targeting and 0 or 1
    local aim = alive and targeting and (s.hover or s.enemyIndex == aimed)
    W.animTo(s, "aim", aim and 1 or 0, aim and W.HOVER_IN or W.HOVER_OUT)
    aimApply(s)
  end
end

function V:RenderPlayer(full)
  local c = self.c
  local p = c.player
  if full then
    self.playerHp:Set(p.hp, p.maxHp)
    self.playerBlock:Set(p.block, p.maxHp)
    local list = W.unitStatuses(p)
    -- épique en jeu (c.epic) : le premier des pouvoirs, liseré violet, infobulle complète
    if c.epic then
      list[#list + 1] = { icon = W.cardArt(c.epic.id), text = Card.def(c.epic).name,
        rim = Art.rarityRim.epic or Art.rim.violet, glow = W.EPIC_COLOR, info = { power = c.epic, epic = true },
        key = "epic:" .. c.epic.id, epic = true }
    end
    for i = 1, #p.powers do
      local inst = p.powers[i]
      list[#list + 1] = { icon = W.cardArt(inst.id), text = Card.def(inst).name, rim = Art.rim.gold,
        info = { power = inst }, key = "card:" .. inst.id }
    end
    -- vue de classe : ce que l'épique et les pouvoirs font maintenant, sur leurs jetons (compteur sur
    -- l'icône, ligne dans l'infobulle, icône atténuée si la règle est inactive), jetons de plus
    -- (W.noteToken ; docs/classes.md, « Vue de classe ») : aucun texte permanent sur la scène
    local cv = ns.ClassViews and ns.ClassViews[c.class or "priest"]
    if cv and cv.tokens then cv.tokens(c, list, self) end
    self.playerSt:Set(list)
  end
  if p.cast then
    local d = Card.def(p.cast.card)
    local tgt = p.cast.target and enemyByUid(c, p.cast.target)
    self.cast.name:SetText(d.name .. (tgt and (" on " .. Combat.enemyName(tgt)) or ""))
    W.setIcon(self.cast.medal.icon, W.cardArt(p.cast.card.id), "card:" .. p.cast.card.id)
    self.cast:Show()
  else
    self.cast:Hide()
  end
  -- mana : chiffre et maximum dans l'anneau doré
  local maxMana = Controller.maxMana()
  self.mana.text:SetText(tostring(p.mana))
  self.mana.max:SetText("/" .. maxMana)
  local class = c.class or "priest"
  self.heroFrame.name:SetText((ns.Classes[class] or {}).name or "")
  if self.heroFrame.portrait._class ~= class then self.heroFrame:SetPortrait() end
  -- ressource de classe : icône de la classe jouée, nombre, cachée à 0
  if self.resource._class ~= class then
    self.resource._class = class
    W.setIcon(self.resource.icon, Art.classResource(class), "ui:resource:" .. class)
  end
  local dem = p.res or 0
  self.resource.text:SetText(tostring(dem))
  if dem > 0 then self.resource:Show() else self.resource:Hide() end
  self:RenderPips(class, dem)
  -- zone libre de la classe
  local zone, cv = self.classZone, ns.ClassViews and ns.ClassViews[class]
  for k, f in pairs(zone.views) do if k ~= class then f:Hide() end end
  if cv then
    local host = zone.views[class]
    if not host then
      host = CreateFrame("Frame", nil, zone)
      host:SetAllPoints()
      if cv.build then cv.build(host, self) end
      zone.views[class] = host
    end
    host:Show()
    if cv.render then cv.render(host, c, self) end
  end
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
      local x0 = COOLDOWN_X - (rowN * 50 - 8) / 2
      at(m, self.parent, x0 + col * 50, COOLDOWN_Y - 21 - row * 50, 42, 42)
      m:Show()
    else
      m.cd = nil
      m:Hide()
    end
  end
end

-- Crans de la ressource : autant d'alvéoles que le plafond, les n premières pleines. Un changement de n
-- fait passer les crans touchés en fondu (et un éclat doux sur ceux qui se remplissent) ; un changement
-- de classe ou un premier rendu les pose sans animation.
local function pipTo(p, on, animate)
  local target = on and 1 or 0
  if p.on == on then return end
  p.on = on
  W.cancel(p, "fill")
  W.cancel(p, "glow")
  if not animate then
    p.alpha = target
    p.fill:SetAlpha(target)
    p.glow:SetAlpha(0)
    return
  end
  -- fondu depuis la valeur courante (un cran repris en route ne saute pas)
  local from = p.alpha or (1 - target)
  W.tween(PIP_FADE, function(t)
    p.alpha = from + (target - from) * t
    p.fill:SetAlpha(p.alpha)
  end, function()
    p.alpha = target
    p.fill:SetAlpha(target)
  end, p, "fill", W.ease.linear)
  if on then
    W.tween(PIP_GLOW, function(t) p.glow:SetAlpha(0.85 * (1 - t)) end, function() p.glow:SetAlpha(0) end, p, "glow",
      W.ease.linear)
  end
end

-- Pose des crans pour un plafond cap : un arc jusqu'à PIPS_ROW, deux au-delà (voir PIPS_ROW).
function V.layoutPips(pips, cap)
  local inner = cap <= PIPS_ROW and cap or math.ceil(cap / 2)
  for i, p in ipairs(pips.list) do
    local r, a = PIP_R, PIP_A0 + (i - 1) * PIP_DA
    if i > inner then r, a = PIP_R2, PIP_A0 + PIP_DA / 2 + (i - inner - 1) * PIP_DA end
    a = math.rad(a)
    p.x, p.y = MANA_X + r * math.cos(a), MANA_Y + r * math.sin(a) -- centre (coordonnées du contenu)
    for _, t in ipairs({ p.socket, p.fill }) do
      t:ClearAllPoints()
      t:SetPoint("CENTER", pips, "CENTER", p.x - MANA_X, -(p.y - MANA_Y))
    end
  end
  pips.layoutCap = cap
end

function V:RenderPips(class, n)
  local row = self.resPips
  local rd = ns.Classes[class] and ns.Classes[class].resource
  -- plafond du combat (crochet « resCap » : épique, pouvoir), sinon celui de la classe
  local c = self.c
  local cap = (c and c.class == class and Combat.resCap(c)) or (rd and rd.cap)
  if not cap or cap < 1 then
    row:Hide()
    row.class, row.cap = nil, nil
    return
  end
  cap = min(cap, PIPS_MAX)
  local fresh = row.class ~= class or row.cap ~= cap or not row:IsShown()
  if fresh then
    row.class, row.cap = class, cap
    if row.layoutCap ~= cap then V.layoutPips(row, cap) end
    local ra = Art.classResource(class)
    local col = ra.color and C[ra.color] or C.watchText
    for i, p in ipairs(row.list) do
      local used = i <= cap
      p.fill:SetVertexColor(col[1], col[2], col[3], 1)
      p.glow:SetVertexColor(col[1], col[2], col[3], 1)
      p.on = nil
      for _, t in ipairs({ p.socket, p.fill, p.glow }) do if used then t:Show() else t:Hide() end end
    end
    row:Show()
  end
  n = max(0, min(n or 0, cap))
  for i = 1, cap do pipTo(row.list[i], i <= n, not fresh) end
  row.n = n
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

-- Carte de la main : la zone de clic reste à sa place dans l'éventail ; au survol ou à la sélection
-- (canal « hover »), le visuel (face) se soulève de W.CARD_LIFT (nombre entier de pixels à l'arrivée),
-- son halo doré s'allume et il passe devant ses voisines. Aucune échelle : le texte reste celui du repos.
function V:PlaceCard(card)
  if not card.baseX or self.dragging == card then return end
  local up = (self.selected == card.index or card.hover) and true or false
  card.lifted = up
  local cy = card.baseY + W.CARD_H / 2
  card.hoverLift = W.CARD_LIFT
  local base = self.hz:GetFrameLevel() + 5 + card.index * 3
  W.placeCard(card, self.parent, card.baseX, cy, 1, base, base + 60)
  W.animTo(card, "hover", up and 1 or 0, up and W.HOVER_IN or W.HOVER_OUT)
  -- zone de survol prolongée vers le haut tant que la carte est levée (on peut monter dessus)
  if card.SetHitRectInsets then
    local top = up and -math.ceil(card.hoverLift) or 0
    if card._hitTop ~= top then card._hitTop = top card:SetHitRectInsets(0, 0, top, 0) end
  end
  card:SetHot(up)
end

function V:RenderHand()
  local c = self.c
  local n = #c.hand
  if self.selected and self.selected > n then self.selected = nil end
  local mana = c.player.mana
  self.shownHand = {}
  -- choix de la carte gardée en fin de tour (Traveler's Backpack) : cartes proposées au liseré d'or
  local keepable = {}
  if self.keepMode then
    for _, k in ipairs(Controller.retainCandidates()) do keepable[k] = true end
  end
  for i = 1, #self.cards do
    local card = self.cards[i]
    if i <= n then
      local info = Controller.handInfo(i)
      -- marque d'une zone (Hex visé : liseré et icône) ; carte transformée : nom de la carte d'origine
      local mark = ns.ZoneView.first(c, "handMark", i, info.inst)
      local orig = info.inst.orig
      -- « Spend N: » allumée si la ressource suffit et que Maj n'est pas enfoncée, éteinte sinon ;
      -- carte Cast qui partira tout de suite (Instant) : liseré bleu et « Cast · Instant »
      card:SetCard(info.inst.id, info.inst.up, { cost = info.cost, playable = info.playable,
        manaShort = info.cost > mana, reason = not info.playable and Controller.reasonText(info.why) or nil,
        spendOff = info.spendOff, instant = info.instant, keepPick = keepable[i] or nil,
        markRim = mark and mark.rim or nil, markIcon = mark and mark.icon or nil, markTip = mark and mark.tip or nil,
        markKey = mark and mark.key or nil, zoneTag = orig and Card.def(orig).name or nil })
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
  self:RenderZone()
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
  W.fly(g, self.parent, pp.x, pp.y, tx, ty, 1, 0.35, 1, 0.1, 0.38, function() W.releaseGhost(g) end, 40)
end

function V:QueueEvent(ev)
  local t = ev.t
  local A = Art.anim
  local self_ = self
  -- vue de la classe : ses propres animations, dans la même file (ns.ClassViews[classe].event(hôte, ev, vue),
  -- qui appelle vue:Push ; familier du Hunter), avant celles de l'événement commun
  local cls = self.c and self.c.class
  local cv = cls and ns.ClassViews and ns.ClassViews[cls]
  local host = cv and cv.event and self.classZone.views[cls]
  if host then cv.event(host, ev, self) end
  -- vues de zone : leurs animations (ns.ZoneViews[zone].event(hôte, ev, vue)), hôte du calque des zones
  if self.c then
    for _, id in ipairs({ self.c.zone, unpack(self.c.zr or {}) }) do
      local zv = id and ns.ZoneViews[id]
      if zv and zv.event then zv.event(self.zoneHost.views[id] or self.zoneHost, ev, self) end
    end
  end
  if t == "float" then
    -- texte flottant d'une zone (ns.ZoneRule.float) : sur l'unité, couleur de Art.C
    local col = C[ev.color or "watchText"] or C.watchText
    self:Push(0.2, function()
      local x, y = self_:UnitPos(ev.unit or "player")
      if x then W.float(self_.parent, x, y - 70, ev.text or "", col, 17, 1.2, 14) end
    end)
  elseif t == "phase" then
    -- seuil franchi : bandeau « Phase 2: Enraged » au-dessus de l'ennemi
    self:Push(0.35, function()
      local x, y = self_:UnitPos(ev.unit)
      if x then W.float(self_.parent, x, y - 120, "Phase " .. (ev.n + 1) .. (ev.name and (": " .. ev.name) or ""),
        C.goldText, 18, 1.6, 14) end
    end)
  elseif t == "counter" then
    -- compteur de combat d'une zone : le jeton bat (sans échelle : fondu de l'icône)
    self:Push(0.15, function()
      local f = self_.counter
      if f:IsShown() then
        W.tween(0.4, function(p) f.slot.icon:SetAlpha(0.4 + 0.6 * p) end, function() f.slot.icon:SetAlpha(1) end, f, "pulse")
        if ev.d and ev.d ~= 0 then
          W.float(self_.parent, COUNTER_X, Scene.TOP + 52, (ev.d > 0 and "+" or "") .. ev.d, ev.d > 0 and C.defendText or C.attackText, 16, 1.0, 14)
        end
      end
    end)
  elseif t == "card_added" or t == "card_transformed" then
    -- carte de combat posée (Curse) ou transformée (Hexed) : son nom part de l'ennemi qui l'a posée
    local d = ns.Cards[ev.id]
    local where = { hand = " (hand)", draw = " (draw pile)", drawRandom = " (draw pile)", discard = " (discard)" }
    local name = (d and d.name or tostring(ev.id)) .. (t == "card_added" and (where[ev.to or ""] or "") or "!")
    self:Push(0.25, function()
      local x, y = self_:UnitPos(ev.src or "player")
      if not x then x, y = self_:UnitPos("player") end
      if x then W.float(self_.parent, x, y - 90, name, C.watchText, 15, 1.3, 16) end
    end)
  elseif t == "cards_lifted" then
    self:Push(0.25, function()
      local x, y = self_:UnitPos("player")
      if x then W.float(self_.parent, x, y - 90, ev.n .. " lifted", C.healText, 15, 1.2, 16) end
    end)
  elseif t == "play" then
    local pp = self.pendingPlay
    self.pendingPlay = nil
    self:Push(0.3, function()
      W.sound("play")
      self_:FlyPlayed(pp, ev)
      W.anim(self_.playerModel, A.spell, 1.0)
    end)
  elseif t == "act" then
    local e = enemyByUid(self.c, ev.unit)
    local mv = e and ns.Combat.moveOf(e.id, ev.move)
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
  elseif t == "parry" then
    -- charge de Parry (Rogue) : « Parry » part du héros, à gauche du chiffre des PV perdus s'il en reste
    self:Push(0.18, function()
      local x, y = self_:UnitPos("player")
      W.sound("block")
      W.float(self_.parent, x - 44, y - 40, "Parry", C.goldText, 22, 1.1)
    end)
  elseif t == "trap" then
    -- Trap déclenchée : son nom part de l'ennemi qui l'a déclenchée, avant ses effets
    local d = ev.id and ns.Cards[ev.id]
    local name = d and d.name or "Trap"
    self:Push(0.3, function()
      local x, y = self_:UnitPos(ev.dst)
      W.sound("interrupt")
      if x then W.float(self_.parent, x, y - 92, name .. "!", C.goldText, 18, 1.3) end
    end)
  elseif t == "interrupt_prevented" then
    -- interruption sans effet (Talisman of Focus) : le nom de ce qui l'a empêchée part du héros
    local by = ev.by and (ns.Relics[ev.by] or ns.Cards[ev.by])
    local label = by and (by.name .. "!") or "Not interrupted"
    self:Push(0.3, function()
      local x, y = self_:UnitPos("player")
      W.sound("block")
      W.float(self_.parent, x, y - 60, label, C.defendText, 17, 1.4)
    end)
  elseif t == "enemy_turn_skipped" then
    -- tour ennemi sauté (Feign Death) : « Skips its turn » sur chaque ennemi vivant
    self:Push(0.3, function()
      for uid, s in pairs(self_.slotOf) do
        local e = self_.c and enemyByUid(self_.c, uid)
        local x, y = self_:UnitPos(uid)
        if x and e and not e.dead then W.float(self_.parent, x, y - 60, "Skips its turn", C.defendText, 16) end
      end
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
    -- nom du pouvoir (ou du bibelot) qui a empêché la mort
    local by = ev.by and (ns.Cards[ev.by] or ns.Relics[ev.by])
    local label = (by and by.name or "Last Breath") .. "!"
    self:Push(0.4, function() W.float(self_.parent, HERO_X, HERO_FEET - 150, label, C.goldText, 18, 2) end)
  elseif (t == "resource" or t == "demence") and ev.n ~= 0 then
    local c = Controller.combat()
    local cd = c and ns.Classes[c.class]
    local rid = cd and cd.resource and cd.resource.id or "insanity"
    local ra = Art.classResource(c and c.class or "priest")
    local col = ra.color and C[ra.color] or C.watchText
    local word = ns.Language.resourceName(rid, ev.n)
    self:Push(0.1, function()
      W.float(self_.parent, MANA_X + 44, MANA_Y - 40, (ev.n > 0 and "+" or "") .. ev.n .. " " .. word, col, 15, 1.0, 26)
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
  self:ExitKeep(true)
  self:RenderHand()
  self:RenderTargets()
end

function V:Play(i, target)
  local card = self.cards[i]
  if card and card.baseX then
    local info = Controller.handInfo(i)
    self.pendingPlay = { x = card.baseX, y = card.baseY + W.CARD_H / 2 - W.CARD_LIFT, id = card.cardId, up = card.cardUp,
      cost = info and info.cost }
  end
  self.selected = nil
  -- Maj enfoncée au moment de jouer : une carte « Spend N » se joue sans dépenser
  local nospend = IsShiftKeyDown and IsShiftKeyDown() and true or false
  local ok, why = Controller.play(i, target, nospend)
  if not ok then
    self.pendingPlay = nil
    UI.flash(Controller.reasonText(why))
    self:Render()
  end
  return ok
end

-- Joue la carte sélectionnée (sur l'ennemi retenu si elle demande une cible).
function V:Confirm()
  local i = self.selected
  local info = i and Controller.handInfo(i)
  if not info then return end
  if info.needsTarget then
    local t = self:AimTarget()
    if not t then UI.flash(Controller.reasonText("target")) return end
    return self:Play(i, t)
  end
  return self:Play(i)
end

function V:ClickCard(i, button)
  if self.justDragged and now() - self.justDragged < 0.15 then return end
  if button == "RightButton" then self:Deselect() return end
  if Controller.over() then return end
  if self.keepMode then
    -- choix de fin de tour : la carte cliquée est gardée (une carte Retain l'est déjà)
    local card = self.cards[i]
    local ok = false
    for _, k in ipairs(Controller.retainCandidates()) do if k == i then ok = true end end
    if ok and card and card.uid then self:FinishTurn(card.uid)
    else UI.flash(Controller.reasonText("keep")) end
    return
  end
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
    self.aimTarget = e.uid
    if info then self:Play(self.selected) else self:RenderTargets() end
  end
end

-- Potion à cible (bandeau) : la prochaine cible cliquée la reçoit.
function V:SelectPotion(slot)
  self:ExitKeep(true)
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

-- Choix de la carte gardée en fin de tour (Traveler's Backpack) : « End Turn » ouvre le choix s'il y a une
-- carte à garder ; les cartes proposées portent un liseré d'or, un clic sur l'une d'elles finit le tour en
-- la gardant ; le bouton, devenu « Keep none », finit le tour sans rien garder ; un clic droit annule.
V.KEEP_PROMPT = "Choose a card to keep in hand."
V.KEEP_NONE = "Keep none"

function V:EnterKeep()
  self.keepMode = true
  self.selected = nil
  self.potionSlot = nil
  self.endTurn:SetText(V.KEEP_NONE)
  UI.flash(V.KEEP_PROMPT)
  self:RenderHand()
  self:RenderTargets()
end

function V:ExitKeep(quiet)
  if not self.keepMode then return end
  self.keepMode = nil
  self.endTurn:SetText("End Turn")
  if not quiet and self.c then self:RenderHand() end
end

function V:EndTurn(button)
  if Controller.over() then Controller.finishCombat() return end
  if self.keepMode then
    if button == "RightButton" then self:ExitKeep() return end
    return self:FinishTurn(nil) -- « Keep none »
  end
  if #Controller.retainCandidates() > 0 then return self:EnterKeep() end
  return self:FinishTurn(nil)
end

-- Fin du tour (keep : uid de la carte gardée au choix, ou nil).
function V:FinishTurn(keep)
  self:ExitKeep(true)
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
  local ok, why = Controller.endTurn(keep)
  if ok then
    self:FlyDiscard(before)
  else
    self.frozen = false
    if why == "keep" then UI.flash(Controller.reasonText(why)) self:Render() end
  end
  return ok
end

function V:StartDrag(card)
  if self.keepMode then return end -- choix de fin de tour : un clic, pas de glisser
  local info = Controller.handInfo(card.index)
  if not info or not info.playable or Controller.over() then return end
  if GameTooltip then GameTooltip:Hide() end
  self.selected = card.index
  self.dragging = card
  self:RenderTargets()
  card:SetFrameLevel(self.hz:GetFrameLevel() + 95)
  -- la carte suit le curseur : plus de levée, halo allumé
  card.hoverLift = 0
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

---------------------------------------------------------------------------
-- Aperçu des modèles (/slay models) : vérifie l'art sans toucher à l'expédition
---------------------------------------------------------------------------

-- Entrées de l'aperçu, dans l'ordre du rapport : ennemis (Art.enemies), personnages des rencontres
-- (chaque `npc` de Data/Events.lua, déclaré ou non dans Art.npcs), familier, feu de camp.
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
    if type(ev) == "table" and ev.npc then speaker[ev.npc] = speaker[ev.npc] or ev.speaker or ev.npc end
  end
  for id in pairs(Art.npcs) do speaker[id] = speaker[id] or id end
  ids = {}
  for id in pairs(speaker) do ids[#ids + 1] = id end
  table.sort(ids)
  for i = 1, #ids do
    out[#out + 1] = { id = "npc:" .. ids[i], key = "npc:" .. ids[i], art = Art.npcs[ids[i]],
      name = speaker[ids[i]], npc = true }
  end
  if Art.pet then
    out[#out + 1] = { id = "pet:hunter", key = "pet:hunter", art = Art.pet, name = Art.pet.name or "Pet", npc = true }
  end
  out[#out + 1] = { id = "campfire", key = "campfire", art = Art.campfire, name = "Campfire", fire = true }
  return out
end

-- Identifiants essayés, en clair : « creature 619, display 2329, display 2330 ».
local function triesText(art)
  local t = Scene.modelTries(art)
  local parts = {}
  for i = 1, #t do parts[i] = Scene.tryLabel(t[i]) end
  return #parts > 0 and table.concat(parts, ", ") or "no identifier"
end

V.PREVIEW_ROWS = 3
V.PREVIEW_MAX = 60 -- secondes au plus avant le rapport (essais encore en cours : « loading »)

function V:PreviewEnemies()
  if not self.preview then
    local p = W.dialog(UI.content, "Models (chat lists every one: loaded candidate or fallback)", 14)
    p:SetPoint("TOPLEFT", 10, -50)
    p:SetPoint("BOTTOMRIGHT", -10, 10)
    p:SetFrameLevel(UI.content:GetFrameLevel() + 95)
    p:EnableMouse(true)
    p.models = {}
    local list = previewEntries()
    local cols = math.ceil(#list / V.PREVIEW_ROWS)
    local rows = math.ceil(#list / cols)
    local cellW = (UI.CONTENT_W - 20 - 24) / cols
    local rowH = min(236, (UI.CONTENT_H - 60 - 36 - 50) / max(1, rows))
    local figW = min(150, cellW - 8)
    local figH = min(170, rowH - 52)
    for k = 1, #list do
      local e = list[k]
      local col, row = (k - 1) % cols, floor((k - 1) / cols)
      local fig = e.fire and Scene.campfire(p, figW, figH) or Scene.figure(p, figW, figH)
      fig:SetPoint("TOP", p, "TOPLEFT", 12 + (col + 0.5) * cellW, -36 - row * rowH)
      -- modèle large (art.wide) : élargi par Scene.showModel, jamais au-delà de sa case
      fig.wideMax = cellW - 4
      -- textes au-dessus du modèle et du repli : jamais sous un modèle
      local top = fig.ui
      if not top then
        top = CreateFrame("Frame", nil, fig)
        top:SetAllPoints()
        top:SetFrameLevel(fig.model:GetFrameLevel() + Scene.UI_LIFT)
        fig.ui = top
      end
      local m = fig.model
      local label = W.label(top, "bold", 11, C.text)
      label:SetPoint("TOP", fig, "BOTTOM", 0, -3)
      label:SetWidth(cellW - 4)
      label:SetWordWrap(false)
      label:SetText(e.name)
      local ids = W.label(top, "body", 9.5, C.textDim)
      ids:SetPoint("TOP", label, "BOTTOM", 0, -1)
      ids:SetWidth(cellW - 4)
      ids:SetWordWrap(false)
      ids:SetText(triesText(e.art))
      m.state = W.label(top, "bold", 10, C.textDim)
      m.state:SetPoint("TOP", ids, "BOTTOM", 0, -1)
      m.state:SetWidth(cellW - 4)
      m.state:SetWordWrap(false)
      m.id, m.key, m.art, m.npc, m.fire, m.fallback, m.label, m.fig = e.id, e.key, e.art, e.npc, e.fire,
        fig.fallback, e.name, fig
      p.models[k] = m
    end
    local close = W.button(p, "Close", 110, 30, function() p:Hide() end, "red", 14)
    close:SetPoint("BOTTOMRIGHT", -16, 16)
    self.preview = p
  end
  self.preview:Show()
  for k = 1, #self.preview.models do
    local m = self.preview.models[k]
    m.state:SetText("loading")
    m.state:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    if m.fire then
      Scene.showCampfire(m.fig)
    else
      Scene.showModel(m.fig, m.art, m.key, { facing = opts().facingEnemy or -0.6 })
    end
  end
  -- rapport au chat quand plus aucun essai n'est en cours (ou au bout de PREVIEW_MAX secondes)
  self.previewToken = (self.previewToken or 0) + 1
  local token = self.previewToken
  UI.say("model preview: checking " .. #self.preview.models .. " models (up to "
    .. Scene.MODEL_WAIT .. " s per candidate; the report follows).")
  local waited = 0
  local function poll()
    if self.previewToken ~= token then return end
    local pending = false
    for _, m in ipairs(self.preview.models) do
      local st = W.models[m.key]
      if not st or st.state == "pending" then pending = true end
    end
    if pending and waited < V.PREVIEW_MAX then
      waited = waited + 0.5
      W.delay(0.5, poll)
    else
      self:ReportModels()
    end
  end
  W.delay(0.5, poll)
end

-- Lignes du rapport (/slay models), à recopier telles quelles : bilan, puis une ligne par modèle
-- (candidat chargé, ou « fallback » avec les candidats essayés). ASCII seulement (polices du jeu).
function V:ModelReportLines()
  local ok, lost = 0, 0
  local models = self.preview and self.preview.models or {}
  local body = {}
  for k = 1, #models do
    local m = models[k]
    local st = W.models[m.key]
    if st and st.state == "ok" then ok = ok + 1 elseif st and st.state == "missing" then lost = lost + 1 end
    body[#body + 1] = Scene.reportLine(m.key, m.label)
  end
  local lines = { "models: " .. ok .. "/" .. #models .. " loaded, " .. lost .. " on fallback"
    .. (ok + lost < #models and (", " .. (#models - ok - lost) .. " still loading") or "") .. ":" }
  for i = 1, #body do lines[#lines + 1] = body[i] end
  return lines, lost
end

function V:ReportModels()
  local models = self.preview and self.preview.models or {}
  for k = 1, #models do
    local m = models[k]
    local st = W.models[m.key]
    local good = st and st.state == "ok"
    m.state:SetText(good and ("model: " .. st.via) or (st and st.state == "missing" and "fallback" or "loading"))
    local c = good and C.healGreen or C.badText
    m.state:SetTextColor(c[1], c[2], c[3])
  end
  local lines = self:ModelReportLines()
  for i = 1, #lines do UI.say(i == 1 and lines[i] or ("  " .. lines[i])) end
end
