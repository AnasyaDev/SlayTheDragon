-- Briques d'interface, peau « Mechanized Magic » (pièces du pack de Dumivid, CC0, fabriquées par
-- tools/build_media.py dans Media/, décrites par UI/SkinData.lua) : plaques d'ardoise au liseré
-- d'argent (neuf tranches), hexagones, médaillons, police Baloo Chettan 2, sons, interpolations,
-- survols, icônes (améliorées d'abord, icône du jeu en repli), carte unique (main, récompense, marchand,
-- deck), jauges de vie, jetons d'état, boutons, infobulles, textes flottants, modèles 3D.
-- Seule couche (avec Main/Scene/CombatView/Screens/Flight) à toucher l'API WoW.
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local Art = ns.Art
local Card = ns.Card
local C = Art.C

local W = {}
ns.Widgets = W

W.missing = {}   -- icônes ou modèles introuvables en jeu (pour /slay art)

local WHITE = Art.tex.white
local floor, max, min, sin = math.floor, math.max, math.min, math.sin

---------------------------------------------------------------------------
-- Temps, vitesse, interpolations
---------------------------------------------------------------------------

function W.delay(sec, fn)
  if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end
end

-- Multiplicateur appliqué aux durées d'animation.
function W.pace()
  local o = ns.Persist.options()
  if o.fast then return 0.15 end
  local s = o.speed or 1
  if s < 0.25 then s = 0.25 end
  return 1 / s
end

-- Un seul OnUpdate partagé (W.driver) fait avancer deux sortes d'animations, et se coupe dès que
-- plus rien ne bouge :
--   * les interpolations W.tween (durée fixe, fn(p) de 0 à 1 : vols de cartes, chiffres, fondus) ;
--   * les canaux animés W.animTo (une valeur par objet et par clé qui file vers une cible, et repart
--     de sa valeur courante si la cible change en route : survols réversibles).
-- Chaque animation a aussi un minuteur de secours qui la termine (le client peut sauter des images ;
-- le harnais n'a pas d'OnUpdate).
local tweens = {}
local animated = {}   -- objet -> vrai tant qu'un de ses canaux bouge
local driver = CreateFrame("Frame")
W.driver = driver

local function finishTween(tw)
  if tw.done then return end
  tw.done = true
  tweens[tw] = nil
  if tw.fn then tw.fn(1) end
  if tw.onDone then tw.onDone() end
end

W.ease = {
  out = function(p) return 1 - (1 - p) * (1 - p) end,
  -- sortie amortie (survols) : départ vif, arrivée douce
  outCubic = function(p) local q = 1 - p return 1 - q * q * q end,
  inOut = function(p) if p < 0.5 then return 2 * p * p end return 1 - 2 * (1 - p) * (1 - p) end,
  linear = function(p) return p end,
}

-- Fait avancer les canaux d'un objet ; vrai si l'un d'eux bouge encore.
local function stepChannels(obj, dt)
  local moving = false
  for _, ch in pairs(obj._ch) do
    if ch.t < ch.dur then
      ch.t = ch.t + dt
      if ch.t >= ch.dur then
        ch.t, ch.v = ch.dur, ch.to
      else
        ch.v = ch.from + (ch.to - ch.from) * W.ease.outCubic(ch.t / ch.dur)
        moving = true
      end
    end
  end
  if obj._animApply then obj:_animApply() end
  return moving
end

local running, runningObjs = {}, {}
local onUpdate
local function sleepIfIdle()
  if driver.awake and next(tweens) == nil and next(animated) == nil then
    driver.awake = false
    driver:SetScript("OnUpdate", nil)
  end
end
local function wake()
  if not driver.awake then
    driver.awake = true
    driver:SetScript("OnUpdate", onUpdate)
  end
end

onUpdate = function(_, elapsed)
  elapsed = elapsed or 0
  -- copies : les rappels peuvent lancer d'autres animations pendant le parcours
  local n = 0
  for tw in pairs(tweens) do n = n + 1 running[n] = tw end
  for i = 1, n do
    local tw = running[i]
    running[i] = nil
    if not tw.done then
      tw.t = tw.t + elapsed
      if tw.t >= tw.dur then
        finishTween(tw)
      elseif tw.fn then
        local p = tw.t / tw.dur
        tw.fn(tw.ease and tw.ease(p) or p)
      end
    end
  end
  local m = 0
  for obj in pairs(animated) do m = m + 1 runningObjs[m] = obj end
  for i = 1, m do
    local obj = runningObjs[i]
    runningObjs[i] = nil
    if animated[obj] and not stepChannels(obj, elapsed) then
      animated[obj] = nil
      if obj.onAnimSettled then obj:onAnimSettled() end
    end
  end
  sleepIfIdle()
end

-- fn(p) avec p de 0 à 1 ; owner/key : une nouvelle interpolation remplace l'ancienne de même clé.
function W.tween(dur, fn, onDone, owner, key, ease)
  dur = max(0.01, dur * W.pace())
  local tw = { t = 0, dur = dur, fn = fn, onDone = onDone, ease = ease or W.ease.out }
  if owner and key then
    owner._tweens = owner._tweens or {}
    local old = owner._tweens[key]
    if old and not old.done then old.done = true tweens[old] = nil end
    owner._tweens[key] = tw
  end
  tweens[tw] = true
  wake()
  if fn then fn(0) end
  W.delay(dur + 0.02, function() finishTween(tw) sleepIfIdle() end)
  return tw
end

function W.cancel(owner, key)
  local tw = owner and owner._tweens and owner._tweens[key]
  if tw and not tw.done then tw.done = true tweens[tw] = nil end
end

-- Canaux animés -----------------------------------------------------------------------------

W.HOVER_IN, W.HOVER_OUT = 0.12, 0.15  -- survols : entrée vive, sortie un peu plus douce

-- Valeur courante d'un canal (rest si jamais animé).
function W.animValue(obj, key, rest)
  local ch = obj._ch and obj._ch[key]
  if ch then return ch.v end
  return rest or 0
end

-- Pose une valeur sans animation.
function W.animSet(obj, key, value)
  obj._ch = obj._ch or {}
  local ch = obj._ch[key] or {}
  obj._ch[key] = ch
  ch.v, ch.from, ch.to, ch.t, ch.dur = value, value, value, 0, 0
  ch.token = (ch.token or 0) + 1
  if obj._animApply then obj:_animApply() end
end

-- Fait filer le canal `key` de obj vers `target` en `dur` secondes, depuis sa valeur courante
-- (réversible : une cible qui change en route repart de là où l'on en est). obj._animApply(obj)
-- est appelé à chaque image ; obj.onAnimSettled(obj) quand plus aucun canal ne bouge.
function W.animTo(obj, key, target, dur, rest)
  obj._ch = obj._ch or {}
  local ch = obj._ch[key]
  if not ch then
    local v0 = rest or 0
    ch = { v = v0, from = v0, to = v0, t = 0, dur = 0 }
    obj._ch[key] = ch
  end
  if ch.to == target then return end
  dur = dur or W.HOVER_IN
  if dur <= 0 then W.animSet(obj, key, target) return end
  ch.from, ch.to, ch.t, ch.dur = ch.v, target, 0, dur
  ch.token = (ch.token or 0) + 1
  local token = ch.token
  animated[obj] = true
  wake()
  W.delay(dur + 0.05, function()
    if ch.token ~= token or ch.t >= ch.dur then return end
    ch.t, ch.v = ch.dur, ch.to
    if obj._animApply then obj:_animApply() end
    for _, other in pairs(obj._ch) do if other.t < other.dur then return end end
    animated[obj] = nil
    if obj.onAnimSettled then obj:onAnimSettled() end
    sleepIfIdle()
  end)
end

-- Vrai si le pilote tourne (pour le harnais : il doit s'arrêter quand tout est immobile).
function W.driverAwake() return driver.awake and true or false end

---------------------------------------------------------------------------
-- Survols : zone de survol fixe, visuel qui s'allume (et, pour une carte, se soulève), jamais agrandi
---------------------------------------------------------------------------
-- Piège évité : déplacer le cadre qui reçoit la souris ferait sortir le curseur de la zone
-- (entrée/sortie en boucle). Le cadre interactif reste donc immobile (zone de survol) ; tout ce qui se
-- voit vit dans son enfant `face`, seul déplacé (levée d'une carte, écart).
--
-- Aucun agrandissement au survol, nulle part (retour en jeu du 12/11/2026) : à une échelle de quelques
-- pour cent, le client ne peut pas garder un texte stable (police recalée au pixel à chaque taille :
-- espacement des lettres qui change, texte décalé d'un ou deux pixels, étiré pendant l'animation). Le
-- survol se signale comme sur les boutons du jeu : une surbrillance (couche additive, liseré ou halo
-- doré créés d'avance, en fondu par le canal « hover ») et, pour une carte lisible, une levée. La levée
-- arrive sur un nombre entier de pixels (W.pixelSnap) : le texte est redessiné à l'identique, décalé.
-- L'échelle d'un visuel ne change plus que pendant un vol de carte (W.fly : animation Scale, puis
-- échelle réelle d'arrivée posée une fois).

-- Accrochage au pixel coupé (textures : SetSnapToPixelGrid, SetTexelSnappingBias, comme les neuf
-- tranches de Blizzard) : une pièce déplacée ou en vol ne se recale pas d'un pixel d'une image à
-- l'autre. Les FontString n'ont pas ces méthodes (SimpleTextureBaseAPI) : test d'existence.
function W.noSnap(r)
  if r.SetSnapToPixelGrid then r:SetSnapToPixelGrid(false) end
  if r.SetTexelSnappingBias then r:SetTexelSnappingBias(0) end
  return r
end

-- Textes de l'interface (W.label, W.text), pour le rafraîchissement des polices.
local labels = setmetatable({}, { __mode = "k" })

-- Texte posé par l'interface : taille rendue exactement proportionnelle à l'échelle (SetSmoothScaling :
-- fenêtre à 115 %, aperçu, arrivée d'un vol) et mode Vertex pendant l'animation Scale d'un vol (comme
-- Blizzard_EncounterWarnings : la mise en page reste figée pendant le vol).
local function zoomText(fs)
  labels[fs] = true
  if fs.SetScaleAnimationMode and Enum and Enum.FontStringScaleAnimationMode then
    fs:SetScaleAnimationMode(Enum.FontStringScaleAnimationMode.Vertex)
  end
  if fs.SetSmoothScaling then fs:SetSmoothScaling(true) end
  W.noSnap(fs)
end
W.zoomText = zoomText

-- Unités du cadre r les plus proches de u qui font un nombre entier de pixels d'écran (levée d'une
-- carte : à l'arrivée, le texte est redessiné aux mêmes positions dans le pixel qu'au repos). Pixels
-- par unité = échelle effective × hauteur physique ÷ 768 (repère de l'interface du jeu).
function W.pixelSnap(r, u)
  if not u or u == 0 then return 0 end
  local s = r.GetEffectiveScale and r:GetEffectiveScale()
  if type(s) ~= "number" or s <= 0 then return u end
  local ph
  if GetPhysicalScreenSize then
    local _, h = GetPhysicalScreenSize()
    ph = h
  end
  local k = s * ((type(ph) == "number" and ph > 0) and ph / 768 or 1)
  return floor(u * k + 0.5) / k
end

-- Vol de carte (W.fly) : animation Scale du cadre en vol, relative à son échelle réelle de départ.
-- C'est la seule animation d'échelle de l'addon ; à l'arrivée, elle est coupée et l'échelle d'arrivée
-- posée comme échelle réelle (texte net), dans le même appel.
local ease = {
  OUT = function(p) return 1 - (1 - p) * (1 - p) end,
  IN_OUT = function(p) if p < 0.5 then return 2 * p * p end return 1 - 2 * (1 - p) * (1 - p) end,
}

-- Facteur courant de l'animation de vol de f (1 si elle ne joue pas).
local function flyFactor(f)
  local z = f._flyScale
  if not z or not z.ag:IsPlaying() then return 1 end
  local dur = z.dur
  local t = GetTime() - z.t0
  if dur <= 0 or t >= dur then return z.to end
  local p = z.anim.GetSmoothProgress and z.anim:GetSmoothProgress() or ease.IN_OUT(t / dur)
  if type(p) ~= "number" or p < 0 or p > 1 then p = ease.IN_OUT(t / dur) end
  return z.from + (z.to - z.from) * p
end

-- Échelle visuelle courante d'un cadre (échelle réelle × facteur d'un vol en cours).
function W.visualScale(f)
  return f:GetScale() * flyFactor(f)
end

local function flyScaleStop(f)
  local z = f._flyScale
  if z then
    z.ag:Stop()
    z.from, z.to = 1, 1
  end
end

-- Lance l'animation de vol de f : facteur 1 → target en dur secondes (lissage IN_OUT), tenu jusqu'à
-- l'arrivée (long délai de fin).
local function flyScaleTo(f, target, dur)
  local z = f._flyScale
  if not z then
    if target == 1 then return end
    local ag = f:CreateAnimationGroup()
    local anim = ag:CreateAnimation("Scale")
    anim:SetOrigin("CENTER", 0, 0)
    anim:SetSmoothing("IN_OUT")
    z = { ag = ag, anim = anim, from = 1, to = 1, t0 = 0, dur = 0 }
    f._flyScale = z
  end
  z.ag:Stop()
  if dur <= 0 or target == 1 then z.from, z.to = 1, 1 return end
  dur = max(dur, 0.001)
  z.anim:SetScaleFrom(1, 1)
  z.anim:SetScaleTo(target, target)
  z.anim:SetDuration(dur)
  z.anim:SetEndDelay(86400)
  z.from, z.to, z.t0, z.dur = 1, target, GetTime(), dur
  z.ag:Play()
end

-- Crée le visuel `f.face`, centré sur f, de même taille (suivie par OnSizeChanged) plus margin de
-- chaque côté (carte : halo, ruban, languette, plaques qui débordent du corps).
function W.face(f, margin)
  local face = CreateFrame("Frame", nil, f)
  margin = margin or 0
  f.faceMargin = margin
  face:SetSize(f:GetWidth() + 2 * margin, f:GetHeight() + 2 * margin)
  face:SetPoint("CENTER", f, "CENTER", 0, 0)
  face._x, face._y = 0, 0
  f.face = face
  f:HookScript("OnSizeChanged", function(self, w, h)
    if w and h then self.face:SetSize(w + 2 * self.faceMargin, h + 2 * self.faceMargin) end
  end)
  return face
end

-- Applique les canaux « hover » (0..1) et « dx » (unités de f) au visuel : surbrillance (f.hoverPaint)
-- et position (levée f.hoverLift × hover, écart dx). Aucune échelle. La levée et l'écart d'arrivée sont
-- ramenés à un nombre entier de pixels ; le visuel n'est réancré que si sa position change (un bouton
-- ne fait que s'allumer : aucun SetPoint, rien de redessiné que la surbrillance).
function W.faceApply(f)
  local face = f.face
  if not face then return end
  local h = W.animValue(f, "hover")
  local dx = W.animValue(f, "dx")
  local lift = f.hoverLift or 0
  local x, y = 0, 0
  if lift ~= 0 then y = W.pixelSnap(face, lift) * h end
  if dx ~= 0 then
    local ch = f._ch and f._ch.dx
    x = (ch and ch.t >= ch.dur) and W.pixelSnap(face, dx) or dx
  end
  if face._x ~= x or face._y ~= y then
    face._x, face._y = x, y
    face:ClearAllPoints()
    face:SetPoint("CENTER", f, "CENTER", x, y)
  end
  if f.hoverPaint then f:hoverPaint(h) end
end

-- Change la levée de survol d'un visuel (unités de f, vers le haut ; 0 : il ne fait que s'allumer).
function W.setLift(f, lift)
  f.hoverLift = lift or 0
  if f._animApply == W.faceApply and f.face then W.faceApply(f) end
end

-- Rend f survolable : opts = { lift (unités de f, vers le haut ; cartes seulement), paint(f, h) : la
-- surbrillance, manual }. manual = l'écran pilote lui-même le canal « hover » (main, cartes à
-- sélection).
function W.hoverable(f, opts)
  opts = opts or {}
  if not f.face then W.face(f) end
  f._hoverable = true
  f.hoverLift = opts.lift or 0
  f.hoverPaint = opts.paint or f.hoverPaint
  f._hoverManual = opts.manual
  f._animApply = W.faceApply
  return f
end

function W.hoverEnter(f)
  if f._hoverable and not f._hoverManual and f.active ~= false then W.animTo(f, "hover", 1, W.HOVER_IN) end
end

function W.hoverLeave(f)
  if f.pressed then
    -- clic maintenu puis sortie : relâché (repeint par le canal, ou tout de suite s'il est au repos)
    f.pressed = false
    if f.hoverPaint then f:hoverPaint(W.animValue(f, "hover")) end
  end
  if f._hoverable and not f._hoverManual then W.animTo(f, "hover", 0, W.HOVER_OUT) end
end

-- Remet un visuel au repos sans animation (écran qui se reconstruit, cadre caché).
function W.hoverReset(f)
  if f._ch then
    for key in pairs(f._ch) do W.animSet(f, key, 0) end
  end
end

-- Surbrillance des boutons, à la façon du jeu (128-RedButton-Highlight, posé en ADD sur le bouton) :
-- une copie de la pièce du bouton en mélange additif, éteinte au repos, à LIGHT_ADD au survol. Elle
-- éclaircit le bouton en gardant sa forme (bords, ombre, liseré). Créée avec le bouton (jamais pendant
-- un survol). x : un trois tranches (W.threeSlice) ou une texture.
W.LIGHT_ADD = 0.32
function W.lightLayer(x)
  local parts = x.parts or { x }
  for _, t in ipairs(parts) do
    if t.SetBlendMode then t:SetBlendMode("ADD") end
  end
  W.hoverLayer(x)
  x:SetAlpha(0)
  return x
end

-- Enfoncement (clic maintenu) : f.pressed, puis repeint (la surbrillance l'assombrit, PRESS_DIM) ; rien
-- ne bouge ni ne change d'échelle. Relâché au OnMouseUp, en le cachant et en le quittant (W.hoverLeave).
W.PRESS_DIM = 0.8
function W.pressable(f)
  f:HookScript("OnMouseDown", function(self)
    if self.active == false or (self.IsEnabled and not self:IsEnabled()) then return end
    if self.option and self.option.disabled then return end -- réponse ou service impossible
    self.pressed = true
    if self.hoverPaint then self:hoverPaint(W.animValue(self, "hover")) end
  end)
  local function release(self)
    if not self.pressed then return end
    self.pressed = false
    if self.hoverPaint then self:hoverPaint(W.animValue(self, "hover")) end
  end
  f:HookScript("OnMouseUp", release)
  f:HookScript("OnHide", release)
  return f
end

---------------------------------------------------------------------------
-- Sons (identifiants SOUNDKIT, voir Art.sounds)
---------------------------------------------------------------------------

local lastSound = {}
function W.sound(key)
  local name = Art.sounds[key]
  local id = name and SOUNDKIT and SOUNDKIT[name]
  if not id or not PlaySound then return end
  local t = GetTime and GetTime() or 0
  if lastSound[key] and t - lastSound[key] < 0.08 then return end
  lastSound[key] = t
  pcall(PlaySound, id)
end

---------------------------------------------------------------------------
-- Couleurs, formes simples
---------------------------------------------------------------------------

function W.rgb(c) return c[1], c[2], c[3] end

-- Texture unie.
function W.rect(parent, layer, sub, color, alpha)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
  t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
  return t
end

-- Disque teinté : disque blanc embarqué (Media/mask_disc), repli sur le disque du jeu.
function W.disc(parent, layer, sub, color, alpha)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
  if not W.setSkin(t, "mask_disc") then t:SetTexture(Art.tex.circle) end
  t:SetVertexColor(color[1], color[2], color[3], alpha or 1)
  return t
end

-- Dégradé vertical (haut -> bas) ; repli : couleur du bas.
function W.gradient(tex, top, bottom)
  tex:SetTexture(WHITE)
  if CreateColor and tex.SetGradient then
    tex:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
      CreateColor(top[1], top[2], top[3], top[4] or 1))
  else
    tex:SetColorTexture(bottom[1], bottom[2], bottom[3], bottom[4] or 1)
  end
end

local function lerpColor(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
W.lerpColor = lerpColor

local function mul(c, k)
  if type(k) == "table" then return { c[1] * k[1], c[2] * k[2], c[3] * k[3] } end
  return { c[1] * k, c[2] * k, c[3] * k }
end

local function clamp1(c) return { min(1, c[1]), min(1, c[2]), min(1, c[3]) } end

---------------------------------------------------------------------------
-- Peau : textures de Media/ (UI/SkinData.lua, fabriqué par tools/build_media.py)
---------------------------------------------------------------------------
-- Aucun chiffre de texture en dur ici : fichiers, zones utiles, coordonnées et géométrie de la carte
-- viennent de ns.Skin. Les textures sont des TGA 32 bits en puissances de deux (contenu en haut à gauche).

local Skin = ns.Skin
W.Skin = Skin
local ROOT, TEX = Skin.root, Skin.tex

function W.skinPath(name)
  local e = TEX[name]
  return e and (ROOT .. e.file) or nil
end

-- Pose la texture `name` (zone utile) sur tex ; sub = { l, r, t, b } en fractions de la zone utile.
function W.setSkin(tex, name, sub)
  local e = TEX[name]
  if not e then tex:SetTexture(nil) return false end
  tex:SetTexture(ROOT .. e.file, nil, nil, "TRILINEAR")
  local u, v = e.tc[2], e.tc[4]
  if sub then tex:SetTexCoord(sub[1] * u, sub[2] * u, sub[3] * v, sub[4] * v)
  else tex:SetTexCoord(0, u, 0, v) end
  return true
end

function W.skin(parent, name, layer, sub, alpha)
  local t = W.noSnap(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
  W.setSkin(t, name)
  if alpha then t:SetAlpha(alpha) end
  return t
end

-- Largeur d'une pièce posée à la hauteur h (proportions de sa zone utile).
function W.skinWidth(name, h)
  local e = TEX[name]
  return e and h * e.cw / e.ch or h
end

-- Groupe de textures piloté d'un bloc (couleur, alpha, visibilité).
local Group = {}
Group.__index = Group
function Group:SetVertexColor(r, g, b, a) for _, t in ipairs(self.parts) do t:SetVertexColor(r, g, b, a or 1) end end
function Group:SetAlpha(a) for _, t in ipairs(self.parts) do t:SetAlpha(a) end end
function Group:SetShown(on) for _, t in ipairs(self.parts) do if on then t:Show() else t:Hide() end end self.shown = on end
function Group:Show() self:SetShown(true) end
function Group:Hide() self:SetShown(false) end
function Group:SetDesaturated(on) for _, t in ipairs(self.parts) do t:SetDesaturated(on) end end

-- Texture à neuf tranches : coins de `corner` unités (le coin de la texture), bords étirés.
-- opts = { corner, inset, noCenter, cornersOnly, parent }. Ancrages seulement : suit la taille de
-- l'hôte ; textures créées sur opts.parent (défaut : l'hôte), ancrées à l'hôte.
-- Bords d'une tranche : colonne -> (gauche, droite), rangée -> (haut, bas) ; chaque bord = côté de
-- l'hôte et décalage (i = retrait, c = coin).
local function sliceEdges(col, row, i, c)
  local l, r, t, b
  if col == 1 then l, r = { "LEFT", i }, { "LEFT", i + c }
  elseif col == 2 then l, r = { "LEFT", i + c }, { "RIGHT", -(i + c) }
  else l, r = { "RIGHT", -(i + c) }, { "RIGHT", -i } end
  if row == 1 then t, b = { "TOP", -i }, { "TOP", -(i + c) }
  elseif row == 2 then t, b = { "TOP", -(i + c) }, { "BOTTOM", i + c }
  else t, b = { "BOTTOM", i + c }, { "BOTTOM", i } end
  return l, r, t, b
end

function W.nine(host, name, layer, sub, opts)
  opts = opts or {}
  local e = TEX[name]
  local o = setmetatable({ host = host, parts = {}, e = e, slices = {} }, Group)
  local owner = opts.parent or host
  local a, bu = e.corner / e.w, 1 - e.corner / e.w
  local av, bv = e.corner / e.h, 1 - e.corner / e.h
  local us, vs = { 0, a, bu, 1 }, { 0, av, bv, 1 }
  for row = 1, 3 do
    for col = 1, 3 do
      local corner = row ~= 2 and col ~= 2
      local center = row == 2 and col == 2
      if not (center and opts.noCenter) and not (opts.cornersOnly and not corner) then
        local t = W.noSnap(owner:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0))
        t:SetTexture(ROOT .. e.file, nil, nil, "TRILINEAR")
        t:SetTexCoord(us[col], us[col + 1], vs[row], vs[row + 1])
        o.parts[#o.parts + 1] = t
        o.slices[#o.slices + 1] = { t, row, col }
      end
    end
  end
  o.Layout = function(self, corner, inset)
    self.c, self.i = corner or self.c, inset or self.i
    local c, i, h = self.c, self.i, self.host
    for _, s in ipairs(self.slices) do
      local t, row, col = s[1], s[2], s[3]
      local l, r, tp, b = sliceEdges(col, row, i, c)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", h, tp[1] .. l[1], l[2], tp[2])
      t:SetPoint("BOTTOMRIGHT", h, b[1] .. r[1], r[2], b[2])
    end
  end
  o:Layout(opts.corner or 8, opts.inset or 0)
  return o
end

---------------------------------------------------------------------------
-- Plaques d'ardoise au liseré d'argent (pièces de la peau des cartes) : seulement les plaques posées
-- sous une carte (raison d'un refus, prix) ; le reste de l'interface est habillé de pièces du jeu.
---------------------------------------------------------------------------
-- Coins en neuf tranches (matière et liseré), intérieur en deux bandes de matière carrelée à l'échelle
-- (coordonnées de texture répétées, recalculées quand l'hôte change de taille).
-- p:SetFill(k | couleur) éclaircit ou teinte la matière ; p:SetRim(couleur) teinte le liseré (Art.rim) ;
-- p:SetGlow(alpha, couleur) allume un halo. opts.parent : cadre qui porte les textures (défaut : l'hôte,
-- qui ne sert alors que d'ancre) — une plaque posée sur un visuel animé y met ses textures (régions du
-- visuel : elles suivent son animation).

local Plaque = {}
Plaque.__index = Plaque

function W.plaque(host, opts)
  opts = opts or {}
  local r = opts.r or 8
  local layer, sub = opts.layer or "BACKGROUND", opts.sub or -6
  local owner = opts.parent or host
  local p = setmetatable({ host = host, r = r, i = opts.inset or 0, layer = layer, sub = sub,
    tile = Skin.slateTile, base = Skin.slateBase }, Plaque)
  local fillName, rimName = "pill_slate", "pill_rim"
  p.corners = W.nine(host, fillName, layer, sub, { corner = r, inset = p.i, cornersOnly = true, parent = owner })
  p.bands = {}
  for k = 1, 2 do
    local t = W.noSnap(owner:CreateTexture(nil, layer, nil, sub + 1))
    t:SetTexture(ROOT .. TEX.tile_slate.file, "REPEAT", "REPEAT")
    p.bands[k] = t
  end
  local re = TEX[rimName]
  p.rimIn = re.rimIn * r / re.corner
  p.rim = W.nine(host, rimName, layer, sub + 3, { corner = r, inset = p.i, noCenter = true, parent = owner })
  -- halo créé dès maintenant, caché : une texture créée au premier survol naîtrait pendant
  -- l'animation Scale du visuel (le client la dessinait alors démesurée, en aplat doré sur l'écran)
  local g = 10
  p.glow = W.nine(host, "nine_glow", layer, max(-8, sub - 1), { corner = 2 * g, inset = p.i - g, parent = owner })
  p.glow:SetAlpha(0)
  p.glow:Hide()
  p:Layout()
  if host.HookScript then host:HookScript("OnSizeChanged", function(_, w, h) p:Tile(w, h) end) end
  p:Tile(host:GetWidth(), host:GetHeight())
  p:SetFill(opts.fill or 1)
  p:SetRim(opts.rim)
  return p
end

function Plaque:Layout()
  local r, i, ri, h = self.r, self.i, self.rimIn, self.host
  local hb, vb = self.bands[1], self.bands[2]
  hb:ClearAllPoints()
  hb:SetPoint("TOPLEFT", h, "TOPLEFT", i + ri, -(i + r))
  hb:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -(i + ri), i + r)
  vb:ClearAllPoints()
  vb:SetPoint("TOPLEFT", h, "TOPLEFT", i + r, -(i + ri))
  vb:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -(i + r), i + ri)
  if self.gloss then
    self.gloss:ClearAllPoints()
    self.gloss:SetPoint("TOPLEFT", h, "TOPLEFT", i + r * 0.7, -(i + ri))
    self.gloss:SetPoint("BOTTOMRIGHT", h, "RIGHT", -(i + r * 0.7), 0)
  end
end

-- Coordonnées de la matière carrelée : la même grille pour les deux bandes (aucune couture).
function Plaque:Tile(w, h)
  if not w or not h or w <= 0 or h <= 0 then return end
  local T, r, i, ri = self.tile, self.r, self.i, self.rimIn
  local function set(t, x0, y0, x1, y1)
    if x1 - x0 <= 0.5 or y1 - y0 <= 0.5 then t:SetAlpha(0) return end
    t:SetAlpha(self.alpha or 1)
    t:SetTexCoord(x0 / T, x1 / T, y0 / T, y1 / T)
  end
  set(self.bands[1], i + ri, i + r, w - i - ri, h - i - r)
  set(self.bands[2], i + r, i + ri, w - i - r, h - i - ri)
end

function Plaque:SetRadius(r)
  self.r = r
  self.rimIn = self.rim.e.rimIn * r / self.rim.e.corner
  self.corners:Layout(r)
  self.rim:Layout(r)
  self:Layout()
  self:Tile(self.host:GetWidth(), self.host:GetHeight())
end

-- k : facteur de clarté (1 = normal) ou couleur multiplicative { r, g, b } (clarté 1).
function Plaque:SetFill(k)
  self.fillK = k
  local c = type(k) == "table" and clamp1(mul(k, self.base)) or clamp1({ self.base * k, self.base * k, self.base * k })
  self.corners:SetVertexColor(c[1], c[2], c[3])
  for _, t in ipairs(self.bands) do t:SetVertexColor(c[1], c[2], c[3], 1) end
end

function Plaque:SetRim(c)
  c = c or Art.rim.silver
  self.rimColor = c
  self.rim:SetVertexColor(c[1], c[2], c[3])
end

-- Halo (lueur douce autour de la plaque) : alpha 0 le cache.
function Plaque:SetGlow(a, c)
  if (a or 0) <= 0 then
    self.glow:SetAlpha(0)
    self.glow:Hide()
    return
  end
  c = c or C.gold
  self.glow:SetVertexColor(c[1], c[2], c[3], 1)
  self.glow:SetAlpha(a)
  self.glow:Show()
end

function Plaque:SetAlpha(a)
  self.alpha = a
  self.corners:SetAlpha(a)
  self.rim:SetAlpha(a)
  for _, t in ipairs(self.bands) do t:SetAlpha(a) end
  if self.gloss then self.gloss:SetAlpha(a) end
  self:Tile(self.host:GetWidth(), self.host:GetHeight())
end

function Plaque:SetShown(on)
  self.shown = on
  self.corners:SetShown(on)
  self.rim:SetShown(on)
  for _, t in ipairs(self.bands) do if on then t:Show() else t:Hide() end end
  if self.gloss then if on then self.gloss:Show() else self.gloss:Hide() end end
  if not on then self.glow:Hide() end
end
function Plaque:Show() self:SetShown(true) end
function Plaque:Hide() self:SetShown(false) end

---------------------------------------------------------------------------
-- Habillage WoW : pièces de l'interface du jeu embarquées (Media/WowUI, décrites par UI/WowSkin.lua,
-- fabriqué par tools/build_wowui.py). Jamais d'atlas du jeu ni de chemin Interface\… du client pour
-- l'habillage : sur WoW Forever, une texture absente s'afficherait en aplat vert sans qu'on le sache.
---------------------------------------------------------------------------
-- Échelles d'affichage (unités par pixel stocké) : à l'échelle 115 % d'un écran où une unité vaut un
-- pixel, une pièce reste nette tant que k ≤ 1 / 1,15 ≈ 0,87.

local WS = ns.WowSkin
W.Wow = WS
local WROOT, WP, WM = WS.root, WS.pieces, WS.meta
W.K_METAL = 0.87     -- cadre de la fenêtre (pièces -2x stockées à 1)
W.K_DIAMOND = 0.5    -- boîtes de dialogue (pièces -2x stockées à 0,5)

function W.wowPath(name)
  local e = WP[name]
  return e and (WROOT .. e.file) or nil
end

-- Pose la pièce `name` sur tex ; sub = { l, r, t, b } en fractions de la pièce.
function W.setWow(tex, name, sub)
  local e = WP[name]
  if not e then tex:SetTexture(nil) return false end
  if e.tile then tex:SetTexture(WROOT .. e.file, "REPEAT", "REPEAT")
  else tex:SetTexture(WROOT .. e.file, nil, nil, "TRILINEAR") end
  local l, r, t, b = e.tc[1], e.tc[2], e.tc[3], e.tc[4]
  if sub then
    local du, dv = r - l, b - t
    tex:SetTexCoord(l + du * sub[1], l + du * sub[2], t + dv * sub[3], t + dv * sub[4])
  else
    tex:SetTexCoord(l, r, t, b)
  end
  tex._wow = name
  return true
end

function W.wow(parent, name, layer, sub, alpha)
  local t = W.noSnap(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
  W.setWow(t, name)
  if alpha then t:SetAlpha(alpha) end
  return t
end

-- Taille (unités) d'une pièce affichée à k unités par pixel stocké.
function W.wowSize(name, k)
  local e = WP[name]
  return e.pw * k, e.ph * k
end

-- Coordonnées d'une pièce répétée (fichier à part) posée sur w × h unités, période = pièce × k ; un axe
-- non répété garde la pièce entière (étirée).
function W.tileTo(tex, name, w, h, k)
  local e = WP[name]
  local t = e.tile or ""
  local u = t:find("h") and (max(0.01, w) / (e.pw * k)) or e.tc[2]
  local v = t:find("v") and (max(0.01, h) / (e.ph * k)) or e.tc[4]
  tex:SetTexCoord(0, u, 0, v)
end

-- Matière répétée (roche, table, parchemin carrelé) qui couvre l'hôte moins `inset` : période = pièce × k ;
-- suit la taille de l'hôte. owner : cadre porteur de la texture (défaut : l'hôte).
function W.fillTile(host, name, k, layer, sub, inset, owner)
  local t = W.noSnap((owner or host):CreateTexture(nil, layer or "BACKGROUND", nil, sub or -8))
  W.setWow(t, name)
  inset = inset or 0
  t:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset)
  t:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
  local function re(w, h)
    if w and h and w > 0 and h > 0 then W.tileTo(t, name, w - 2 * inset, h - 2 * inset, k) end
  end
  if host.HookScript then host:HookScript("OnSizeChanged", function(_, w, h) re(w, h) end) end
  re(host:GetWidth(), host:GetHeight())
  return t
end

-- Cadre à pièces séparées autour de l'hôte : coins de l'atlas, bords répétés (fichiers à part).
-- spec = { tl, tr, bl, br, top, bottom, left, right } ; k = unités par pixel stocké ; out = { l, t, r, b } :
-- débord des pièces hors de l'hôte (unités). opts = { parent (porteur des textures), top (porteur de la
-- rangée du haut), layer, sub }. Les bords se recalculent quand l'hôte change de taille.
function W.frameSlices(host, spec, k, out, opts)
  opts = opts or {}
  local owner = opts.parent or host
  local topOwner = opts.top or owner
  local layer, sub = opts.layer or "BORDER", opts.sub or 0
  local o = setmetatable({ parts = {}, host = host }, Group)
  local P = {}
  local function mk(key, own)
    local t = W.noSnap(own:CreateTexture(nil, layer, nil, sub))
    W.setWow(t, spec[key])
    o.parts[#o.parts + 1] = t
    P[key] = t
    return t
  end
  for _, key in ipairs({ "tl", "top", "tr" }) do mk(key, topOwner) end
  for _, key in ipairs({ "left", "right", "bl", "bottom", "br" }) do mk(key, owner) end
  o.P = P
  local function sz(key) return W.wowSize(spec[key], k) end
  local tlw, tlh = sz("tl")
  local trw, trh = sz("tr")
  local blw, blh = sz("bl")
  local brw, brh = sz("br")
  local _, toph = sz("top")
  local _, both = sz("bottom")
  local lw = sz("left")
  local rw = sz("right")
  local l, t, r, b = out[1], out[2], out[3], out[4]
  P.tl:SetSize(tlw, tlh) P.tl:SetPoint("TOPLEFT", host, "TOPLEFT", -l, t)
  P.tr:SetSize(trw, trh) P.tr:SetPoint("TOPRIGHT", host, "TOPRIGHT", r, t)
  P.bl:SetSize(blw, blh) P.bl:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", -l, -b)
  P.br:SetSize(brw, brh) P.br:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", r, -b)
  P.top:SetPoint("TOPLEFT", host, "TOPLEFT", tlw - l, t)
  P.top:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", r - trw, t - toph)
  P.bottom:SetPoint("TOPLEFT", host, "BOTTOMLEFT", blw - l, both - b)
  P.bottom:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", r - brw, -b)
  P.left:SetPoint("TOPLEFT", host, "TOPLEFT", -l, t - tlh)
  P.left:SetPoint("BOTTOMRIGHT", host, "BOTTOMLEFT", lw - l, blh - b)
  P.right:SetPoint("TOPLEFT", host, "TOPRIGHT", r - rw, t - trh)
  P.right:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", r, blh - b)
  o.Tile = function(_, w, h)
    if not w or not h or w <= 0 or h <= 0 then return end
    local ww, hh = w + l + r, h + t + b
    W.tileTo(P.top, spec.top, ww - tlw - trw, toph, k)
    W.tileTo(P.bottom, spec.bottom, ww - blw - brw, both, k)
    W.tileTo(P.left, spec.left, lw, hh - tlh - blh, k)
    W.tileTo(P.right, spec.right, rw, hh - trh - brh, k)
  end
  if host.HookScript then host:HookScript("OnSizeChanged", function(_, w, h) o:Tile(w, h) end) end
  o:Tile(host:GetWidth(), host:GetHeight())
  return o
end

-- Pièces en tranches d'un seul tenant (découpe par le client).
-- Retour en jeu du 12/11/2026 (zoom net, fenêtre à 115 %) : pendant l'agrandissement d'un bouton, un
-- jour de 3 pixels entre chaque bout et le milieu, où le fond se voit (ombre du bouton comprise). Les
-- tranches séparées étaient pourtant ancrées bord à bord, sur les mêmes points, sans accrochage au
-- pixel : un écart de 3 pixels ne vient ni d'un arrondi ni du filtrage (coutures d'au plus un pixel,
-- l'atlas a 3 pixels de bords répétés autour de chaque pièce), mais de la façon dont l'animation Scale
-- transforme les régions du visuel (hypothèse : chaque région séparément, pas le visuel d'un bloc).
-- Remède qui ne dépend pas de ce que fait l'animation : une seule texture, découpée par le client
-- (SetTextureSliceMargins, « préféré aux neuf textures séparées » d'après la documentation de l'API) :
-- plus aucune jointure entre régions. Les marges sont en pixels de la texture ; pour qu'elles valent
-- `d` unités de l'hôte par pixel stocké, la région prend l'échelle propre d et couvre l'ancre par deux
-- points sans décalage (sa taille propre vaut alors l'ancre ÷ d). Repli sans l'API (autres clients,
-- W.CLIENT_SLICE coupé) : tranches séparées, bord à bord sur les mêmes ancres (harnais, UB).
W.CLIENT_SLICE = true
local SLICE_STRETCHED = (Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched) or 0

function W.canSlice(t)
  return W.CLIENT_SLICE and t.SetTextureSliceMargins ~= nil and t.SetScale ~= nil
end

-- Pose la texture découpée t sur l'ancre (deux points, sans décalage), d unités par pixel stocké.
function W.sliceFit(t, anchor, d)
  if not d or d <= 0 then return end
  t:SetScale(d)
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
  t:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
end

-- Découpe la texture t (pièce et coordonnées déjà posées) : marges l, tp, r, b en pixels stockés,
-- centre et bords étirés.
function W.sliceMargins(t, l, tp, r, b)
  t:SetTextureSliceMargins(l, tp, r, b)
  if t.SetTextureSliceMode then t:SetTextureSliceMode(SLICE_STRETCHED) end
  t._slice = { l, tp, r, b }
end

-- Trois tranches horizontales (boutons, cadre compact d'ennemi) : bouts de `cap` pixels stockés mis à
-- l'échelle de la hauteur de l'hôte, milieu étiré. Textures sur opts.parent (défaut : l'hôte). Une seule
-- texture découpée par le client quand il le permet (o.sliced), sinon trois tranches bord à bord.
function W.threeSlice(host, name, layer, sub, opts)
  opts = opts or {}
  local e = WP[name]
  local owner = opts.parent or host
  local o = setmetatable({ parts = {}, host = host, name = name }, Group)
  local first = W.noSnap(owner:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0))
  if W.canSlice(first) then
    W.setWow(first, name)
    W.sliceMargins(first, e.cap, 0, e.cap, 0)
    o.parts[1] = first
    o.sliced = true
  else
    local a = e.cap / e.pw
    local cuts = { { 0, a }, { a, 1 - a }, { 1 - a, 1 } }
    for i = 1, 3 do
      local t = i == 1 and first or W.noSnap(owner:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0))
      W.setWow(t, name, { cuts[i][1], cuts[i][2], 0, 1 })
      o.parts[i] = t
    end
  end
  o.Layout = function(self, h)
    h = h or host:GetHeight()
    if not h or h <= 0 then return end
    local cap = e.cap * h / e.ph
    self.cap = cap
    if self.sliced then
      -- hauteur entière de la pièce (aucune marge verticale) : 1 pixel stocké = h / ph unités
      W.sliceFit(self.parts[1], host, h / e.ph)
      return
    end
    local L, M, R = self.parts[1], self.parts[2], self.parts[3]
    L:ClearAllPoints() M:ClearAllPoints() R:ClearAllPoints()
    L:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    L:SetPoint("BOTTOMRIGHT", host, "BOTTOMLEFT", cap, 0)
    R:SetPoint("TOPLEFT", host, "TOPRIGHT", -cap, 0)
    R:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    M:SetPoint("TOPLEFT", host, "TOPLEFT", cap, 0)
    M:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -cap, 0)
  end
  if host.HookScript then host:HookScript("OnSizeChanged", function(_, _, h) o:Layout(h) end) end
  o:Layout()
  return o
end

-- Marque un calque de survol (liseré d'or, cadre doré) : éteint au repos, allumé en fondu au survol
-- (le harnais le contrôle comme un halo, U23).
function W.hoverLayer(x)
  if x.parts then for _, t in ipairs(x.parts) do t._glowLayer = true end else x._glowLayer = true end
  return x
end

-- Neuf tranches d'une seule pièce étirée (parchemins) : marges m = { l, t, r, b } en pixels stockés,
-- affichées à k unités par pixel ; milieu et bords étirés. Une seule texture découpée par le client quand
-- il le permet (o.sliced), sinon neuf tranches bord à bord.
function W.nineStretch(host, name, m, k, layer, sub, owner)
  local e = WP[name]
  local o = setmetatable({ parts = {}, host = host, name = name, margins = m, k = k }, Group)
  owner = owner or host
  local first = W.noSnap(owner:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0))
  if W.canSlice(first) then
    W.setWow(first, name)
    W.sliceMargins(first, m[1], m[2], m[3], m[4])
    W.sliceFit(first, host, k)
    o.parts[1] = first
    o.sliced = true
    return o
  end
  local us = { 0, m[1] / e.pw, 1 - m[3] / e.pw, 1 }
  local vs = { 0, m[2] / e.ph, 1 - m[4] / e.ph, 1 }
  local L, T, R, B = m[1] * k, m[2] * k, m[3] * k, m[4] * k
  local xs = { { "LEFT", 0 }, { "LEFT", L }, { "RIGHT", -R }, { "RIGHT", 0 } }
  local ys = { { "TOP", 0 }, { "TOP", -T }, { "BOTTOM", B }, { "BOTTOM", 0 } }
  for row = 1, 3 do
    for col = 1, 3 do
      local t = (row == 1 and col == 1) and first or W.noSnap(owner:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0))
      W.setWow(t, name, { us[col], us[col + 1], vs[row], vs[row + 1] })
      t:SetPoint("TOPLEFT", host, ys[row][1] .. xs[col][1], xs[col][2], ys[row][2])
      t:SetPoint("BOTTOMRIGHT", host, ys[row + 1][1] .. xs[col + 1][1], xs[col + 1][2], ys[row + 1][2])
      o.parts[#o.parts + 1] = t
    end
  end
  return o
end

-- Boîte de dialogue (cadre DiamondMetal, fond roche, en-tête du titre) : W.dialog(parent, titre | nil).
-- f.title (texte doré de l'en-tête), f:SetTitle(t) ; le filet du cadre est sur le bord du cadre f.
local DIAMOND = { tl = "diamond_tl", tr = "diamond_tr", bl = "diamond_bl", br = "diamond_br",
  top = "diamond_top", bottom = "diamond_bottom", left = "diamond_left", right = "diamond_right" }
function W.dialog(parent, title, titleSize)
  local f = CreateFrame("Frame", nil, parent)
  f:EnableMouse(true)
  local k, dm = W.K_DIAMOND, WM.diamond
  f.bg = W.fillTile(f, "rock", 1, "BACKGROUND", -8, 3)
  f.bg:SetVertexColor(0.8, 0.8, 0.8, 1)
  -- filets sur le bord du cadre : débord = position du filet dans la pièce
  f.border = W.frameSlices(f, DIAMOND, k, { dm.lineL0 * k, dm.lineT0 * k, (64 - dm.lineR1) * k, (64 - dm.lineB1) * k },
    { layer = "BORDER", sub = 2 })
  f.header = CreateFrame("Frame", nil, f)
  f.header:SetHeight(WP.header_m.ph * k)
  f.header:SetPoint("CENTER", f, "TOP", 0, 1)
  local hl = W.wow(f.header, "header_l", "ARTWORK", 0)
  local hr = W.wow(f.header, "header_r", "ARTWORK", 0)
  local capW = WP.header_l.pw * k
  hl:SetPoint("TOPLEFT") hl:SetPoint("BOTTOMLEFT") hl:SetWidth(capW)
  hr:SetPoint("TOPRIGHT") hr:SetPoint("BOTTOMRIGHT") hr:SetWidth(capW)
  local hm = W.wow(f.header, "header_m", "ARTWORK", 0)
  hm:SetPoint("TOPLEFT", hl, "TOPRIGHT") hm:SetPoint("BOTTOMRIGHT", hr, "BOTTOMLEFT")
  f.header.mid = hm
  f.title = W.label(f.header, "bold", titleSize or 15, C.wowGold, "OVERLAY")
  f.title:SetPoint("CENTER", 0, 0)
  f.SetTitle = function(self, t)
    self.title:SetText(t or "")
    if not t or t == "" then self.header:Hide() return end
    local tw = self.title:GetStringWidth() or 60
    local w = max(2 * capW + 20, tw + 2 * capW - 10)
    self.header:SetWidth(w)
    W.tileTo(self.header.mid, "header_m", w - 2 * capW, WP.header_m.ph * k, k)
    self.header:Show()
  end
  f:SetTitle(title)
  return f
end

-- Parchemin (texte sombre, sans ombre) : Dragonflight (rencontres) ou Neutral (parcours).
function W.parchment(parent, kind)
  local f = CreateFrame("Frame", nil, parent)
  f:EnableMouse(true)
  if kind == "map" then
    f.nine = W.nineStretch(f, "parch_map", { 70, 60, 70, 60 }, 0.5, "BACKGROUND", 0)
  else
    f.nine = W.nineStretch(f, "parch_text", { 34, 28, 34, 28 }, 0.85, "BACKGROUND", 0)
  end
  return f
end

---------------------------------------------------------------------------
-- Polices : Baloo Chettan 2 en instances statiques (Media/Fonts), blanc avec ombre portée
---------------------------------------------------------------------------

W.FONT = {
  title = ROOT .. Skin.fonts.bold, bold = ROOT .. Skin.fonts.bold,
  heavy = ROOT .. Skin.fonts.heavy, body = ROOT .. Skin.fonts.medium,
}
W.FONT_FALLBACK = "Fonts\\FRIZQT__.TTF"

local function setFont(fs, kind, size)
  local ok = fs:SetFont(W.FONT[kind] or W.FONT.body, size, "")
  if ok == false then
    ok = fs:SetFont(W.FONT_FALLBACK, size, "")
    if ok == false then
      local f = fs:GetFont()
      if f then fs:SetFont(f, size, "") end
    end
  end
end

-- Préchargement : une police d'addon peut ne rien afficher à son tout premier emploi (chargement
-- asynchrone du fichier : le texte posé avant reste vide jusqu'à sa prochaine mise en page — c'était
-- le changement d'échelle du survol qui le faisait apparaître). Le cadre de préchargement est à
-- l'écran (un cadre transparent ou hors écran peut ne jamais être dessiné, donc ne rien charger),
-- presque invisible ; W.refreshFonts repose ensuite police et texte de tous les textes.
do
  local pre = CreateFrame("Frame", nil, UIParent)
  pre:SetSize(4, 4)
  pre:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
  pre:SetAlpha(0.01)
  for _, kind in ipairs({ "body", "bold", "heavy" }) do
    local fs = pre:CreateFontString(nil, "OVERLAY")
    setFont(fs, kind, 12)
    fs:SetPoint("BOTTOMLEFT", pre, "BOTTOMLEFT", 0, 0)
    fs:SetText("Éé")
  end
  W.fontPreload = pre
end

-- Repose police et texte de tous les textes de l'interface (police d'addon chargée après coup) ;
-- les cartes refont leur mise en page (W.refreshCards).
function W.refreshFonts()
  for fs in pairs(labels) do
    if fs._fontKind then
      setFont(fs, fs._fontKind, fs._size + 0.01) -- taille différente : le client recharge vraiment
      setFont(fs, fs._fontKind, fs._size)
    end
    local t = fs:GetText()
    if t and t ~= "" then
      fs:SetText("")
      fs:SetText(t)
    end
  end
  if W.refreshCards then W.refreshCards() end
end

-- kind = "title" / "bold" (700), "heavy" (800, chiffres), "body" (500) ; shadow : ombre portée
-- (par défaut ; false pour un texte sombre sur ivoire).
function W.label(parent, kind, size, color, layer, shadow)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs._size = size or 12
  fs._fontKind = kind or "body"
  setFont(fs, fs._fontKind, fs._size)
  zoomText(fs)
  color = color or C.text
  fs:SetTextColor(color[1], color[2], color[3])
  if shadow ~= false then
    fs:SetShadowColor(0, 0, 0, 0.85)
    fs:SetShadowOffset(1, -1)
  else
    fs:SetShadowOffset(0, 0)
  end
  return fs
end

function W.setSize(fs, size)
  if fs._size == size then return end
  fs._size = size
  setFont(fs, fs._fontKind or "body", size)
end

function W.setFontKind(fs, kind)
  if fs._fontKind == kind then return end
  fs._fontKind = kind
  setFont(fs, kind, fs._size or 12)
end

-- Compatibilité : texte à objet de police Blizzard.
function W.text(parent, font, size, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlight")
  if size then
    local f, _, flags = fs:GetFont()
    if f then fs:SetFont(f, size, flags) end
  end
  zoomText(fs)
  return fs
end

function W.utf8len(s)
  local n = 0
  for _ in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
  return n
end

-- Ajuste la taille d'un texte sur une ligne à la largeur w (de size vers le bas, jusqu'à minSize).
function W.fitText(fs, text, size, w, minSize)
  W.setSize(fs, size)
  fs:SetText(text)
  local sw = fs:GetStringWidth() or 0
  if sw > w and sw > 0 then
    local s = max(minSize or 6, floor(size * w / sw * 10) / 10)
    W.setSize(fs, s)
    -- la largeur n'est pas exactement proportionnelle (crénage, arrondis) : on descend jusqu'à ce que ça tienne
    while s > (minSize or 6) and (fs:GetStringWidth() or 0) > w do
      s = max(minSize or 6, s - 0.25)
      W.setSize(fs, s)
    end
  end
end

local function hexOf(c)
  return string.format("%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end
W.hexOf = hexOf

function W.colorize(text, c)
  return "|cff" .. hexOf(c) .. text .. "|r"
end

---------------------------------------------------------------------------
-- Icônes : icône améliorée de Media/Icons d'abord, sinon icône du jeu
---------------------------------------------------------------------------

local function noteMissing(key)
  if key then W.missing[key] = true end
end

-- entry = { tga = nom d'icône améliorée, spell = id, icon = FileDataID ou chemin } ; key sert au
-- rapport /slay art. Ordre : fichier de Media/Icons (s'il a été copié par tools/build_media.py), icône
-- du sort, FileDataID, point d'interrogation.
function W.setIcon(tex, entry, key)
  entry = entry or {}
  if entry.tga then
    local f = Skin.icons[entry.tga:lower()]
    if f and tex:SetTexture(ROOT .. f, nil, nil, "TRILINEAR") ~= false then
      tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      return true
    end
  end
  tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  if entry.spell and C_Spell and C_Spell.GetSpellTexture then
    local ok, id = pcall(C_Spell.GetSpellTexture, entry.spell)
    if ok and id then
      tex:SetTexture(id)
      return true
    end
  end
  if entry.icon then
    local ok = tex:SetTexture(entry.icon)
    local fid = tex.GetTextureFileID and tex:GetTextureFileID()
    if ok ~= false and (fid == nil and not tex.GetTextureFileID or fid) then return true end
  end
  noteMissing(key)
  tex:SetTexture(Art.QUESTION)
  return false
end

function W.cardArt(id)
  local e = Art.cards[id]
  if e then return e end
  local d = ns.Cards[id]
  return d and Art.schools[d.school] or nil
end

-- Masque sur une texture d'icône (Media : disque "mask_disc" par défaut, ou "medal_mask").
function W.roundMask(frame, tex, maskName)
  if not frame.CreateMaskTexture or not tex.AddMaskTexture then return end
  local m = frame:CreateMaskTexture()
  local file = W.skinPath(maskName or "mask_disc") or Art.tex.circle
  m:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetAllPoints(tex)
  tex:AddMaskTexture(m)
  return m
end

-- Médaillon : grand anneau doré du jeu, icône masquée en rond. f.icon, f:Resize(taille), f:SetRing(teinte).
-- W.medallionOn(f, …) pose ces pièces sur un cadre existant (visuel animé : régions du visuel).
function W.medallion(parent, size, layerSub)
  local f = CreateFrame("Frame", nil, parent)
  return W.medallionOn(f, size, layerSub)
end

local RING_IN = 0.12 -- retrait de l'icône sous l'anneau (fraction de la taille)
function W.medallionOn(f, size, layerSub)
  f:SetSize(size, size)
  local sub = layerSub or 0
  f.icon = W.noSnap(f:CreateTexture(nil, "ARTWORK", nil, sub))
  W.roundMask(f, f.icon)
  f.ring = W.wow(f, "ring_large", "ARTWORK", sub + 1)
  f.ring:SetAllPoints()
  f.Resize = function(self, s)
    self:SetSize(s, s)
    self.icon:ClearAllPoints()
    self.icon:SetPoint("TOPLEFT", s * RING_IN, -s * RING_IN)
    self.icon:SetPoint("BOTTOMRIGHT", -s * RING_IN, s * RING_IN)
  end
  f.SetRing = function(self, c) c = c or Art.rim.silver self.ring:SetVertexColor(c[1], c[2], c[3], 1) end
  f:Resize(size)
  return f
end

---------------------------------------------------------------------------
-- Cadres de base, boutons
---------------------------------------------------------------------------

function W.create(kind, name, parent, template)
  if template then
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
  end
  return CreateFrame(kind, name, parent)
end

-- Boutons rouges du jeu (128-RedButton) ; action principale : rouge et or (128-GoldRedButton). Survol,
-- comme les boutons du jeu (SharedButtonTemplate : surbrillance 128-RedButton-Highlight en ADD, libellé
-- qui passe de NORMAL_FONT_COLOR à HIGHLIGHT_FONT_COLOR) : le bouton s'éclaircit (pièce plus claire et
-- sa copie additive, W.lightLayer), le liseré d'or apparaît en fondu (bouton rouge : le rouge et or
-- par-dessus) et le libellé blanchit ; rien ne grossit ni ne bouge (texte stable). Clic maintenu :
-- assombri (W.pressable). Sélection (b:SetSelected) : liseré d'or tenu. Inactif : rien ne s'allume.
local BTN_DIM = 0.86
W.BTN_DIM = BTN_DIM
local function buttonPaint(self, h)
  if self.active == false then h = 0 end
  local k = (BTN_DIM + (1 - BTN_DIM) * h) * (self.pressed and W.PRESS_DIM or 1)
  self.base:SetVertexColor(k, k, k)
  if self.hot then
    self.hot:SetVertexColor(k, k, k)
    self.hot:SetAlpha(max(self.selected and 1 or 0, h))
  end
  if self.light then self.light:SetAlpha(W.LIGHT_ADD * h * (self.pressed and 0.5 or 1)) end
  if self.label and self.labelColor then
    local c = lerpColor(self.labelColor, C.white, h)
    self.label:SetTextColor(c[1], c[2], c[3])
  end
end
W.buttonPaint = buttonPaint

-- style : "gold" (action principale : rouge et or, un seul par écran) ; sinon rouge ("red", "slate").
function W.button(parent, label, w, h, onClick, style, size)
  local b = CreateFrame("Button", nil, parent)
  w, h = w or 120, h or 26
  b:SetSize(w, h)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  local gold = style == "gold"
  b.style = gold and "gold" or "red"
  b.base = W.threeSlice(face, gold and "btn_goldred" or "btn_red", "BACKGROUND", -6)
  if not gold then
    -- liseré d'or du survol et de la sélection : le bouton rouge et or par-dessus, en fondu
    b.hot = W.hoverLayer(W.threeSlice(face, "btn_goldred", "BACKGROUND", -5))
    b.hot:SetAlpha(0)
  end
  -- surbrillance additive : copie du bouton rouge et or (la pièce visible au survol, liseré d'or
  -- compris), éteinte au repos
  b.light = W.lightLayer(W.threeSlice(face, "btn_goldred", "BACKGROUND", -4))
  b.label = W.label(face, "bold", size or (h >= 40 and 18 or (h >= 30 and 14 or 12.5)), C.wowGold)
  b.label:SetPoint("CENTER", 0, 0.5)
  b.label:SetText(label or "")
  b.labelColor = C.wowGold
  b.SetText = function(self, t) self.label:SetText(t or "") self._text = t end
  b.GetText = function(self) return self.label:GetText() end
  b._text = label
  b.SetSelected = function(self, on)
    self.selected = on and true or false
    buttonPaint(self, W.animValue(self, "hover"))
  end
  b.Relayout = function(self, hh)
    self.base:Layout(hh)
    if self.hot then self.hot:Layout(hh) end
    self.light:Layout(hh)
  end
  W.hoverable(b, { paint = buttonPaint })
  buttonPaint(b, 0)
  b:SetScript("OnEnter", function(self)
    W.hoverEnter(self)
    if self.onEnterExtra then self:onEnterExtra() end
  end)
  b:SetScript("OnLeave", function(self)
    W.hoverLeave(self)
    if self.onLeaveExtra then self:onLeaveExtra() end
  end)
  W.pressable(b)
  b.SetActive = function(self, on)
    self.active = on
    self:SetAlpha(on and 1 or 0.5)
    self.base:SetDesaturated(not on)
    if on then self:Enable() else self:Disable() W.animTo(self, "hover", 0, W.HOVER_OUT) end
    buttonPaint(self, W.animValue(self, "hover"))
  end
  if onClick then b:SetScript("OnClick", function(self, button)
    W.sound("click")
    onClick(self, button)
  end) end
  return b
end

-- Bouton de fermeture rouge du jeu (RedButton-Exit) pour « × » ; autre glyphe (« < », « > ») : petit
-- bouton rouge carré portant le glyphe. Survol : s'éclaircit (pièce plus claire et copie additive,
-- comme RedButton-Highlight en ADD dans UIPanelCloseButton), sans grossir ; clic maintenu : assombri.
function W.roundButton(parent, glyph, size, _, _, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  local face = W.face(b)
  if glyph == "×" then
    b.base = W.wow(face, "btn_close", "ARTWORK", 0)
    b.base:SetAllPoints()
    b.light = W.lightLayer(W.wow(face, "btn_close", "ARTWORK", 1))
    b.light:SetAllPoints()
    b.label = W.label(face, "heavy", 1, C.text) -- (compatibilité : pas de glyphe dessiné)
  else
    b.base = W.threeSlice(face, "btn_red", "ARTWORK", 0)
    b.light = W.lightLayer(W.threeSlice(face, "btn_red", "ARTWORK", 1))
    b.label = W.label(face, "heavy", floor(size * 0.55), C.wowGold)
    b.label:SetPoint("CENTER", 0, 1)
    b.label:SetText(glyph)
    b.labelColor = C.wowGold
  end
  W.hoverable(b, { paint = buttonPaint })
  buttonPaint(b, 0)
  b:SetScript("OnEnter", function(self) W.hoverEnter(self) end)
  b:SetScript("OnLeave", function(self) W.hoverLeave(self) end)
  W.pressable(b)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end
W.closeButton = function(parent, size, onClick) return W.roundButton(parent, "×", size, nil, nil, onClick) end

-- Case à cocher minimale du jeu (checkbox-minimal) : case et coche embarquées, libellé à droite.
function W.check(parent, label, getter, setter, color)
  local b = CreateFrame("CheckButton", nil, parent)
  b:SetSize(22, 22)
  b.box = W.wow(b, "check_box", "BACKGROUND", 0)
  b.box:SetAllPoints()
  b.mark = W.wow(b, "check_mark", "ARTWORK", 0)
  b.mark:SetSize(19, 16)
  b.mark:SetPoint("CENTER", 2, 2)
  local fs = W.label(b, "body", 13, color or C.text)
  fs:SetPoint("LEFT", b, "RIGHT", 7, 0)
  fs:SetText(label)
  b.label = fs
  local function paint(self)
    local on = self:GetChecked() and true or false
    if on then self.mark:Show() else self.mark:Hide() end
    local c = on and (color or C.text) or C.textSoft
    self.label:SetTextColor(c[1], c[2], c[3])
  end
  b:SetScript("OnClick", function(self)
    paint(self)
    setter(self:GetChecked() and true or false)
  end)
  b.Sync = function(self) self:SetChecked(getter() and true or false) paint(self) end
  paint(b)
  return b
end

-- Curseur minimal du jeu (Minimal_SliderBar) : rail, poignée, flèches aux deux bouts. get() -> fraction
-- 0..1 ; step(-1 | 1) avance d'un cran ; setFrac(f) pose une fraction (clic ou glisser sur le rail).
-- s.minus, s.plus : flèches (boutons) ; s:Sync() replace la poignée.
-- preview(f) (facultatif) : glisser différé, pour un réglage qui déplace ou redimensionne le curseur
-- lui-même (échelle de la fenêtre : appliqué en direct, le rail bougeait sous la souris, la valeur
-- recalculée changeait l'échelle à nouveau, et ainsi de suite). Pendant le glisser, seule la poignée
-- bouge : preview(f) met à jour l'aperçu (libellé) et renvoie la fraction à afficher (arrondie au cran)
-- ou nil ; setFrac n'est appelé qu'une fois, au relâchement du bouton, même hors du rail (relâchement
-- constaté par IsMouseButtonDown si le rail ne reçoit pas OnMouseUp) ou si le rail est caché.
function W.slider(parent, w, get, step, setFrac, preview)
  local s = CreateFrame("Frame", nil, parent)
  s:SetSize(w, 16)
  local track = CreateFrame("Button", nil, s)
  track:SetPoint("LEFT", 16, 0)
  track:SetSize(w - 32, 14)
  s.track = track
  local l, m, r = W.wow(track, "slider_l", "BACKGROUND", 0), W.wow(track, "slider_m", "BACKGROUND", 0),
    W.wow(track, "slider_r", "BACKGROUND", 0)
  l:SetSize(9, 14) l:SetPoint("LEFT")
  r:SetSize(9, 14) r:SetPoint("RIGHT")
  m:SetPoint("TOPLEFT", l, "TOPRIGHT") m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
  s.thumb = W.wow(track, "slider_thumb", "ARTWORK", 0)
  s.thumb:SetSize(17, 16)
  local tw = w - 32 - 12 -- course du centre de la poignée (unités du rail), de 6 à 6 + tw
  local function place(f)
    s.thumb:ClearAllPoints()
    s.thumb:SetPoint("CENTER", track, "LEFT", 6 + tw * max(0, min(1, f)), 0)
  end
  local function arrow(piece, d, side)
    local a = CreateFrame("Button", nil, s)
    a:SetSize(piece == "arrow_l" and 9 or 7.5, piece == "arrow_l" and 16 or 15)
    a:SetPoint(side, s, side, 0, 0)
    a.tex = W.wow(a, piece, "ARTWORK", 0)
    a.tex:SetAllPoints()
    a:SetScript("OnEnter", function(self) self.tex:SetVertexColor(1, 0.9, 0.5, 1) end)
    a:SetScript("OnLeave", function(self) self.tex:SetVertexColor(1, 1, 1, 1) end)
    a:SetScript("OnClick", function() W.sound("click") step(d) s:Sync() end)
    return a
  end
  s.minus = arrow("arrow_l", -1, "LEFT")
  s.plus = arrow("arrow_r", 1, "RIGHT")
  s.Sync = function(self)
    if preview and self.dragging then return end -- glisser différé : la poignée suit l'aperçu
    place(get() or 0)
  end
  -- Fraction sous la souris. GetCursorPosition : pixels d'écran ; divisés par l'échelle effective du
  -- rail (échelle de l'interface × échelle de la fenêtre), ils passent dans les unités du rail, celles
  -- de GetLeft et de la course tw : juste quelle que soit l'échelle de la fenêtre.
  local function cursorFrac()
    if not GetCursorPosition then return nil end
    local x = GetCursorPosition()
    local sc = track:GetEffectiveScale()
    local left = track:GetLeft()
    if not x or not left or not sc or sc <= 0 then return nil end
    return max(0, min(1, (x / sc - left - 6) / max(1, tw)))
  end
  local pending -- glisser différé : fraction à appliquer au relâchement
  local function follow()
    local f = cursorFrac()
    if not f then return end
    if preview then
      pending = f
      place(preview(f) or f)
    else
      setFrac(f)
      place(get() or 0)
    end
  end
  local function finish()
    track:SetScript("OnUpdate", nil)
    if not s.dragging then return end
    s.dragging = false
    local f = pending
    pending = nil
    if f then setFrac(f) end
    s:Sync()
  end
  local function onUpdate()
    -- bouton relâché hors du rail (OnMouseUp non reçu) : fin du glisser, valeur appliquée
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then finish() return end
    follow()
  end
  track:SetScript("OnMouseDown", function(self, button)
    if button and button ~= "LeftButton" then return end
    s.dragging = true
    pending = nil
    follow()
    self:SetScript("OnUpdate", onUpdate)
  end)
  track:SetScript("OnMouseUp", function(self, button)
    if button and button ~= "LeftButton" then return end
    if s.dragging then follow() end -- position du relâchement (la fenêtre n'a pas encore bougé)
    finish()
  end)
  track:SetScript("OnHide", finish)
  s:Sync()
  return s
end

---------------------------------------------------------------------------
-- Barres d'unité (texture de barre du jeu rognée à la fraction) et Absorption
---------------------------------------------------------------------------

-- Barre de vie : texture `piece` (bar_hp, bar_enemy) rognée à la fraction, portion perdue claire qui se
-- vide, texte « PV / max » centré. Le cadre d'unité qui la porte dessine le logement.
function W.hpBar(parent, w, h, textSize, piece)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, h)
  f.w = w
  piece = piece or "bar_hp"
  f.piece = piece
  f.ghost = W.rect(f, "ARTWORK", 0, C.ghostLight, 0.9)
  f.ghost:SetPoint("TOPLEFT")
  f.ghost:SetPoint("BOTTOMLEFT")
  f.fill = W.wow(f, piece, "ARTWORK", 1)
  f.fill:SetPoint("TOPLEFT")
  f.fill:SetPoint("BOTTOMLEFT")
  f.text = W.label(f, "heavy", textSize or 11, C.text, "OVERLAY")
  f.text:SetPoint("CENTER", 0, 0.5)
  -- largeur courante (f.w : le cadre d'unité qui porte la barre peut la redimensionner)
  local function width(frac) return max(0.01, (f.w or w) * max(0, min(1, frac))) end
  local function setFill(self, frac)
    frac = max(0.001, min(1, frac))
    self.fill:SetWidth(width(frac))
    W.setWow(self.fill, piece, { 0, frac, 0, 1 })
  end
  -- animate : la portion perdue reste claire un instant puis se vide.
  f.Set = function(self, hp, maxHp, animate)
    hp = max(0, hp)
    maxHp = maxHp > 0 and maxHp or 1
    local old = self.hp
    self.hp, self.maxHp = hp, maxHp
    self.text:SetText(hp .. " / " .. maxHp)
    setFill(self, hp / maxHp)
    if hp <= 0 then self.fill:Hide() else self.fill:Show() end
    if animate and old and old > hp then
      local from = old / maxHp
      self.ghost:SetWidth(width(from))
      self.ghost:Show()
      W.delay(0.35 * W.pace(), function()
        if self.hp ~= hp then return end
        W.tween(0.4, function(p)
          self.ghost:SetWidth(width(from + (hp / maxHp - from) * p))
        end, function() self.ghost:Hide() end, self, "ghost")
      end)
    else
      W.cancel(self, "ghost")
      self.ghost:Hide()
    end
  end
  f:EnableMouse(true)
  W.tooltip(f, function(tt, self)
    if self.hp then tt:AddLine("Health: " .. self.hp .. " / " .. self.maxHp, 1, 0.5, 0.45) end
    -- lignes en plus posées par l'écran (crans de vie d'un ennemi : phases, seuils de zone)
    if self.extraTip then self.extraTip(tt, self) end
  end, "ANCHOR_TOP")
  f.ghost:Hide()
  return f
end

-- Absorption : barre bleue du jeu dans le logement bas du cadre d'unité (fraction des PV max, plafonnée)
-- et son nombre ; cachée à 0 (le logement vide reste dessiné par le cadre). Set(n, maxHp).
function W.shieldBadge(parent, w, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, h)
  f:EnableMouse(true)
  f.fill = W.wow(f, "bar_absorb", "ARTWORK", 1)
  f.fill:SetPoint("TOPLEFT")
  f.fill:SetPoint("BOTTOMLEFT")
  f.text = W.label(f, "heavy", max(9, min(12, h + 1)), C.text, "OVERLAY")
  f.text:SetPoint("CENTER", 0, 0.5)
  f.w = w
  f.Set = function(self, n, maxHp)
    if maxHp then self.maxHp = maxHp end
    if n and n > 0 then
      local frac = min(1, n / max(1, self.maxHp or 50))
      self.fill:SetWidth(max(0.01, self.w * frac))
      W.setWow(self.fill, "bar_absorb", { 0, max(0.001, frac), 0, 1 })
      self.text:SetText(tostring(n))
      self:Show()
    else
      self:Hide()
    end
  end
  W.tooltip(f, function(tt)
    tt:AddLine(Art.keywordLine("absorb"), 1, 1, 1, true)
  end, "ANCHOR_TOP")
  return f
end

-- Géométrie des cases, mesurée sur les pixels des pièces (pixels stockés, origine en haut à gauche ;
-- le harnais la revérifie sur Media/WowUI/atlas.tga, U31) :
--   slot_frame (69 × 68) : liseré opaque (alpha ≥ 0,5) de 4 px, ouverture [4, 62) × [4, 62), carré
--   visible [0, 66) ; à droite et en bas, 3 px d'ombre portée (d'où les 69 × 68) ; dans l'ouverture,
--   biseau sombre translucide (0,4 → 0) sur 4 px, posé sur l'icône comme sur les barres d'action.
--   slot_bg (96 × 93) : case vide sombre, pleine sur [7, 89) × [7, 89), bord adouci sur 5 px autour
--   (alpha non nul sur [2, 94) × [2, 93)) ; la partie pleine est posée sur l'ouverture, le bord adouci
--   reste sous le liseré.
-- Dans le jeu (ActionButtonTemplate), l'icône couvre tout le bouton et le cadre (46 × 45) se pose
-- dessus : seul le liseré du cadre la borde. L'ancienne case posait l'icône à 80 % de la taille, centrée
-- sur la pièce (ombre comprise), et le fond à 132 % : la case vide débordait de 2 à 5 unités hors du
-- cadre, d'où le gros pourtour noir. Ici : ouverture centrée sur l'hôte, icône = ouverture, fond rentré
-- sous le liseré (rien ne dépasse du cadre).
local SLOT_PW, SLOT_PH = 69, 68
local SLOT_OPEN = { 4, 4, 62, 62 }      -- ouverture du cadre { x0, y0, x1, y1 }
local SLOT_BG_FULL = { 7, 7, 89, 89 }   -- partie pleine du fond
local SLOT_BG_TO = { 4, 4, 62, 62 }     -- … posée sur l'ouverture
W.SLOT = { pw = SLOT_PW, ph = SLOT_PH, open = SLOT_OPEN, bgFull = SLOT_BG_FULL, bgTo = SLOT_BG_TO }

-- Pose la pièce `tex` dont la boîte { x0, y0, x1, y1 } (pixels de la pièce) doit couvrir la boîte `to`
-- (pixels du cadre de case, unités = k par pixel) ; (ox, oy) : coin haut gauche du cadre de case par
-- rapport au centre de l'hôte, en unités (y vers le haut).
local function slotPlace(tex, host, k, ox, oy, pw, ph, box, to)
  local s = (to[3] - to[1]) / (box[3] - box[1])          -- pixels du cadre par pixel de la pièce
  local sy = (to[4] - to[2]) / (box[4] - box[2])
  local x0 = to[1] - box[1] * s                           -- coin haut gauche de la pièce (px du cadre)
  local y0 = to[2] - box[2] * sy
  tex:SetSize(pw * s * k, ph * sy * k)
  tex:ClearAllPoints()
  tex:SetPoint("TOPLEFT", host, "CENTER", ox + x0 * k, oy - y0 * k)
end

-- Case de barre d'action Dragonflight (fond, icône, cadre, cadre doré de survol) de taille `size` (largeur
-- de la pièce du cadre, ombre comprise), ouverture centrée sur le cadre host ; textures portées par owner
-- (défaut : host ; un cadre d'ancrage posé sur un visuel animé y laisse ainsi ses pièces). Renvoie { icon,
-- frame, hot, bg } ; slot.frame:SetVertexColor teint le cadre (qualité d'un bibelot).
-- Place icône, cadre et fond (facultatif) d'une case de taille `size` sur l'hôte (ouverture centrée).
function W.slotFit(host, size, icon, frame, bg)
  local k = size / SLOT_PW
  -- coin haut gauche du cadre : centre de l'ouverture sur le centre de l'hôte
  local ox = -(SLOT_OPEN[1] + SLOT_OPEN[3]) / 2 * k
  local oy = (SLOT_OPEN[2] + SLOT_OPEN[4]) / 2 * k
  if bg then slotPlace(bg, host, k, ox, oy, WP.slot_bg.pw, WP.slot_bg.ph, SLOT_BG_FULL, SLOT_BG_TO) end
  icon:ClearAllPoints()
  icon:SetSize((SLOT_OPEN[3] - SLOT_OPEN[1]) * k, (SLOT_OPEN[4] - SLOT_OPEN[2]) * k)
  icon:SetPoint("CENTER", host, "CENTER", 0, 0)
  slotPlace(frame, host, k, ox, oy, SLOT_PW, SLOT_PH, { 0, 0, SLOT_PW, SLOT_PH }, { 0, 0, SLOT_PW, SLOT_PH })
  frame._slotIcon, frame._slotBg = icon, bg -- (harnais : l'icône couvre l'ouverture, U31)
end

function W.slotOn(host, size, sub, owner)
  sub = sub or 0
  local face = host
  owner = owner or host
  local s = {}
  s.bg = W.wow(owner, "slot_bg", "BACKGROUND", sub)
  s.icon = W.noSnap(owner:CreateTexture(nil, "ARTWORK", nil, sub))
  s.frame = W.wow(owner, "slot_frame", "ARTWORK", sub + 2)
  W.slotFit(face, size, s.icon, s.frame, s.bg)
  s.hot = W.hoverLayer(W.wow(owner, "slot_hover", "ARTWORK", sub + 3))
  s.hot:SetSize(size * 1.04, size * 1.04 * WP.slot_hover.ph / WP.slot_hover.pw)
  s.hot:SetPoint("CENTER", face, "CENTER", 0, 0)
  s.hot:SetAlpha(0)
  s.size = size
  return s
end

---------------------------------------------------------------------------
-- Infobulles (seulement si on les demande, et seulement si elles ont quelque chose à dire)
---------------------------------------------------------------------------

-- Infobulle au survol ; anime aussi le survol si le cadre est survolable (W.hoverable). Un cadre peut
-- placer lui-même l'infobulle : self:tooltipSpot() -> { point, relatif, point relatif, x, y } ou nil
-- (petite carte : à côté de son aperçu à taille réelle) ; self:tooltipLeave() à la sortie.
function W.tooltip(frame, fill, anchor)
  frame:SetScript("OnEnter", function(self)
    W.hoverEnter(self)
    if self.onEnterExtra then self:onEnterExtra() end
    local spot = self.tooltipSpot and self:tooltipSpot()
    if spot then
      GameTooltip:SetOwner(self, "ANCHOR_NONE")
      GameTooltip:ClearAllPoints()
      GameTooltip:SetPoint(spot[1], spot[2], spot[3], spot[4], spot[5])
    else
      GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
    end
    fill(GameTooltip, self)
    if GameTooltip:NumLines() > 0 then GameTooltip:Show() else GameTooltip:Hide() end
  end)
  frame:SetScript("OnLeave", function(self)
    W.hoverLeave(self)
    if self.onLeaveExtra then self:onLeaveExtra() end
    if self.tooltipLeave then self:tooltipLeave() end
    GameTooltip:Hide()
  end)
end

local function gold(tt, text) tt:AddLine(text, 1, 0.82, 0) end
local function wrap(tt, text, r, g, b) tt:AddLine(text, r or 1, g or 1, b or 1, true) end

function W.statusText(id, n)
  local s = ns.Statuses[id]
  if not s then return tostring(id), "" end
  local text = (s.text or ""):gsub("X", tostring(n or "X"))
  return s.name, text
end

function W.addStatusLines(tt, id, n)
  local name, text = W.statusText(id, n)
  local s = ns.Statuses[id]
  local suffix = ""
  -- état à drapeau (Stealth) : présent ou non, sans nombre
  if n and n > 0 and not (s and s.flag) then suffix = s and s.duration and (" (" .. n .. " turn" .. (n > 1 and "s" or "") .. ")")
    or (" " .. n) end
  local bad = s and (s.debuff or s.affix)
  tt:AddLine(name .. suffix, bad and 1 or 0.4, bad and 0.35 or 0.9, bad and 0.35 or 0.4)
  wrap(tt, text)
end

-- Mots-clés d'une définition de carte (pour l'infobulle).
W.SPEND_HINT = "|cffffd100Shift|r: play it without spending."

-- Ressource de la classe d'une carte (id du registre du langage) ou nil.
function W.cardResource(d)
  local cd = d and d.class and ns.Classes[d.class]
  return cd and cd.resource and cd.resource.id or nil
end

function W.cardKeywords(d)
  local list, seen = {}, {}
  local res = W.cardResource(d)
  local function add(k, label, n, up)
    if seen[k] then return end
    seen[k] = true
    list[#list + 1] = { key = k, label = label, n = n, res = res, up = up }
  end
  -- carte neutre (sans classe) : utilisable par toutes les classes (Art.keywords.neutral)
  if d.neutral and not d.class and Art.keywords.neutral then add("neutral") end
  -- mots de la plaque, dans l'ordre de la plaque (Core/Language.lua)
  local L = ns.Language
  for _, p in ipairs(L.plates) do
    local word = L.plateWord(p, d)
    if word then add(p.key, p.n and word or nil, p.n and d[p.flag] or nil) end
  end
  -- texte : conditions nommées et conditions sur un état (« Name: »), puis états cités
  local text = d.text or ""
  for _, c in ipairs(W.CONDITIONS) do
    if c.pattern then
      for cl in (text .. "\n"):gmatch("(.-)\n") do
        local lab = cl:match("^(.-): ")
        if lab and lab:find(c.pattern) then add(c.key, lab, tonumber(lab:match("%d+"))) end
      end
    elseif W.hasPhrase(text, c.name .. ":") then add(c.key) end
  end
  -- mots de règle des épiques (L.rule) : nombre de la carte et texte de la carte améliorée
  for _, r in ipairs(L.ruleWords(d)) do
    add(r.key, nil, r.n, d.isUp or nil)
  end
  for key, kw in pairs(L.keywords) do
    if kw.rule then -- déjà vus
    elseif kw.pattern then
      for cl in (text .. "\n"):gmatch("(.-)\n") do
        if cl:find(kw.pattern) then add(key) end
      end
    elseif kw.zone and W.hasPhrase(text, kw.name) then
      -- mot-clé de zone (L.zoneKeyword) cité par la carte : Curse, Hex, Douse…
      add(key)
    end
  end
  local ids = {}
  for id in pairs(ns.Statuses) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    if W.hasPhrase(text, ns.Statuses[id].name .. ":") then add("cond:" .. id) end
  end
  for i = 1, #(d.effects or {}) do
    local e = d.effects[i]
    if e[1] == "apply" then add("status:" .. e[2]) end
  end
  for _, id in ipairs(ids) do
    if W.hasPhrase(text, ns.Statuses[id].name) then add("status:" .. id) end
  end
  if text:find(W.HOURGLASS_CHAR, 1, true) then add("turns") end
  for i = 1, #(d.effects or {}) do
    local e = d.effects[i]
    if e[1] == "absorb" then add("absorb")
    elseif (e[1] == "res" or e[1] == "demence" or e[1] == "spend" or e[1] == "surge") and res then add("res:" .. res)
    elseif e[1] == "interrupt" then add("interrupt") end
  end
  if W.hasPhrase(text, "Absorb") then add("absorb") end
  -- ressources nommées par le texte (celle de la classe, ou une autre citée)
  local rids = {}
  for id in pairs(L.resources) do rids[#rids + 1] = id end
  table.sort(rids)
  for _, id in ipairs(rids) do
    local r = L.resources[id]
    if W.hasPhrase(text, r.name) or W.hasPhrase(text, r.plural) then add("res:" .. id) end
  end
  return list
end

-- Ligne d'explication d'un mot-clé de carte (W.cardKeywords), sablier en icône.
function W.keywordText(k)
  local line
  if k.key:sub(1, 7) == "status:" then line = Art.statusLine(k.key:sub(8))
  elseif k.key:sub(1, 5) == "cond:" then line = Art.conditionLine(k.key:sub(6))
  else line = Art.keywordLine(k.key, k.label, k.n, k.res, k.up) end
  return W.inlineIcons(line, 12)
end

-- Lignes « While in the deck: A becomes B. » d'une épique (champ transforms), triées par nom d'origine.
function W.transformLines(d)
  local out = {}
  local map = d and d.transforms
  if not map then return out end
  local froms = {}
  for from in pairs(map) do if ns.Cards[from] and ns.Cards[map[from]] then froms[#froms + 1] = from end end
  table.sort(froms, function(a, b) return ns.Cards[a].name < ns.Cards[b].name end)
  for _, from in ipairs(froms) do
    out[#out + 1] = "While in the deck: " .. ns.Cards[from].name .. " becomes |cffffd100" .. ns.Cards[map[from]].name .. "|r."
  end
  return out
end

-- Infobulle de carte : la carte se lit d'elle-même ; l'infobulle n'explique que les mots-clés,
-- l'amélioration (aperçu) et la raison d'un refus. full = nom et texte en plus (pouvoirs, recharges).
function W.fillCardTooltip(tt, id, up, extra)
  local d = Card.defById(id, up)
  if extra and extra.full then
    local rc = Art.rarityText[d.rarity] or Art.rarityText.common
    tt:AddLine(d.name, rc[1], rc[2], rc[3])
    for _, l in ipairs(W.cardTextLines(d)) do wrap(tt, l) end
  end
  -- aperçu de l'amélioration : le palier suivant de cette carte, chiffres qui changent en vert
  if extra and extra.preview and Card.canUp(id, up) then
    local lv = Card.level(up)
    local u = Card.defById(id, lv + 1)
    gold(tt, lv == 0 and "Upgraded:" or ("Upgraded" .. Card.suffix(lv + 1) .. ":"))
    for _, l in ipairs(W.cardTextLines(u, Card.defById(id, lv))) do wrap(tt, l, 0.5, 1, 0.5) end
  end
  -- mots-clés : une ligne chacun, en bloc (séparé du reste par une ligne vide)
  local kws = W.cardKeywords(d)
  if #kws > 0 and tt:NumLines() > 0 then tt:AddLine(" ") end
  for i = 1, #kws do
    wrap(tt, W.keywordText(kws[i]), 0.85, 0.85, 0.85)
  end
  -- « Spend N » au choix : comment jouer la carte sans dépenser (une ligne)
  if d.spend then wrap(tt, W.SPEND_HINT, 0.85, 0.85, 0.85) end
  -- épique : une seule par expédition ; cartes qu'elle transforme tant qu'elle est dans le deck ; variante :
  -- la carte d'origine
  if d.rarity == "epic" then
    wrap(tt, W.EPIC_HINT, 0.85, 0.85, 0.85)
    for _, l in ipairs(W.transformLines(d)) do wrap(tt, l, 0.85, 0.85, 0.85) end
  end
  if extra and extra.from and ns.Cards[extra.from] then
    wrap(tt, "Transformed " .. ns.Cards[extra.from].name .. ".", 0.85, 0.85, 0.85)
  end
  -- carte en main : Cast qui partira tout de suite (Instant), choix de la carte gardée en fin de tour
  if extra and extra.instant then wrap(tt, W.INSTANT_HINT, 0.85, 0.85, 0.85) end
  if extra and extra.keepPick then wrap(tt, W.KEEP_HINT, 1, 0.82, 0) end
  -- carte de zone : carte d'origine d'une carte transformée, marque posée par une zone (Hex visé)
  if extra and extra.zoneTag then wrap(tt, extra.zoneTag, 0.75, 0.6, 1) end
  if extra and extra.markTip then wrap(tt, extra.markTip, 0.55, 1, 0.55) end
  if extra and extra.reason then
    if tt:NumLines() > 0 then tt:AddLine(" ") end
    tt:AddLine(extra.reason, 1, 0.3, 0.3, true)
  end
end

-- Bibelot, potion, or ou affixe : nom, effet, détail facultatif.
function W.fillItemTooltip(tt, kind, id, extra)
  if kind == "relic" then
    local r = ns.Relics[id]
    tt:AddLine(r and r.name or tostring(id), 0.6, 0.8, 1)
    if r and r.text then wrap(tt, r.text) end
  elseif kind == "potion" then
    local p = ns.Potions[id]
    tt:AddLine(p and p.name or tostring(id), 0.5, 1, 0.5)
    if p and p.text then wrap(tt, p.text) end
  elseif kind == "affix" then
    local a = ns.Affixes and ns.Affixes[id]
    gold(tt, a and a.name or tostring(id))
    if a and a.text then wrap(tt, a.text) end
  elseif kind == "locked" then
    -- bibelot verrouillé (écran de progression) : la condition seule, rien de ce qu'on obtiendra
    if extra and extra.condition then tt:AddLine(extra.condition, 1, 0.3, 0.3) end
    return
  elseif extra and extra.title then
    gold(tt, extra.title)
  end
  if extra and extra.text and kind ~= "relic" and kind ~= "potion" and kind ~= "affix" then wrap(tt, extra.text) end
  if extra and extra.hint then
    -- aide : une ligne par idée (texte ou liste de lignes)
    local lines = type(extra.hint) == "table" and extra.hint or { extra.hint }
    for _, l in ipairs(lines) do wrap(tt, l, 0.7, 0.7, 0.7) end
  end
  if extra and extra.reason then wrap(tt, extra.reason, 1, 0.3, 0.3) end
  if extra and extra.price then tt:AddLine(extra.price .. "g", 1, 0.82, 0) end
end

function W.itemEntry(kind, id)
  if kind == "relic" then return Art.relic(id) end
  if kind == "potion" then return Art.potion(id) end
  if kind == "affix" then return Art.affixes[id] end
  if kind == "gold" then return Art.ui.gold end
  if kind == "keystone" then return Art.keystone end
  return nil
end

-- Case à icône (bibelot, potion, affixe, clé) : case de barre d'action (shape "square") ou médaillon à
-- l'anneau doré (shape "round") ; info = { kind, id, ... } pour l'infobulle. Le cadre de la case prend
-- la couleur de qualité d'un bibelot ; survol : cadre doré en fondu.
function W.iconButton(parent, size, shape)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local face = W.face(b)
  b.round = shape == "round"
  if b.round then
    W.medallionOn(face, size)
    b.icon, b.ring = face.icon, face.ring
  else
    b.case = W.slotOn(face, size)
    b.icon = b.case.icon
  end
  if b.round then
    -- halo doré (créé d'avance, éteint) : surbrillance du médaillon
    b.glow = W.skin(face, "glow_round", "BACKGROUND", -8)
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(size * 1.55, size * 1.55)
    b.glow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
    b.glow:SetAlpha(0)
  end
  b.count = W.label(face, "heavy", 11, C.text, "OVERLAY")
  b.count:SetPoint("BOTTOMRIGHT", -1, 1)
  -- survol : cadre doré de la case (ou halo doré du médaillon) en fondu, sans grossir
  W.hoverable(b, { paint = function(self, h)
    if self.case then self.case.hot:SetAlpha(h) end
    if self.glow then self.glow:SetAlpha(0.7 * h) end
  end })
  W.tooltip(b, function(tt, self)
    local info = self.info
    if not info then return end
    W.fillItemTooltip(tt, info.kind, info.id, info)
  end, "ANCHOR_BOTTOM")
  b.SetRim = function(self, c)
    c = c or Art.rim.silver
    if self.case then self.case.frame:SetVertexColor(c[1], c[2], c[3], 1) end
  end
  b.SetItem = function(self, kind, id, info)
    self.info = info or {}
    self.info.kind = kind or self.info.kind
    self.info.id = id
    if kind and (id or kind == "gold" or kind == "keystone") then
      W.setIcon(self.icon, W.itemEntry(kind, id), kind .. ":" .. tostring(id))
      self.icon:SetDesaturated(false)
      self.icon:Show()
      local rim = Art.rim.silver
      if kind == "relic" then
        local r = ns.Relics[id]
        rim = Art.rarityRim[r and r.rarity or "common"] or Art.rim.silver
      end
      self:SetRim(rim)
    else
      self.icon:SetTexture(nil)
      self.icon:Hide()
      self:SetRim(Art.rim.silver)
    end
  end
  return b
end

-- Barre de progression (niveau de classe) : barre jaune du jeu dans un rail de curseur minimal ; bar = { label, levelName,
-- cur, size, detail, hint } (UI/Controller.lua).
function W.repBar(parent, w)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, 14)
  f:EnableMouse(true)
  local l, m, r = W.wow(f, "slider_l", "BACKGROUND", 0), W.wow(f, "slider_m", "BACKGROUND", 0),
    W.wow(f, "slider_r", "BACKGROUND", 0)
  l:SetSize(9, 14) l:SetPoint("LEFT")
  r:SetSize(9, 14) r:SetPoint("RIGHT")
  m:SetPoint("TOPLEFT", l, "TOPRIGHT") m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
  f.fill = W.wow(f, "bar_yellow", "ARTWORK", 0)
  f.fill:SetVertexColor(0.95, 0.72, 0.2, 1) -- or plus sombre : le texte blanc reste lisible dessus
  f.fill:SetPoint("TOPLEFT", 3, -2.5)
  f.fill:SetPoint("BOTTOMLEFT", 3, 2.5)
  f.label = W.label(f, "bold", 14, C.wowGold)
  f.label:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, 3)
  f.value = W.label(f, "bold", 11, C.text, "OVERLAY")
  f.value:SetPoint("CENTER", 0, 0.5)
  f.detail = W.label(f, "body", 11, C.textSoft)
  f.detail:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 2, -3)
  W.tooltip(f, function(tt, self)
    local b = self.bar
    if not b then return end
    tt:AddLine(b.label, 1, 0.82, 0)
    tt:AddLine(b.levelName .. (b.size and (": " .. b.cur .. " / " .. b.size) or " (max level)"), 1, 1, 1)
    if b.hint then
      local lines = type(b.hint) == "table" and b.hint or { b.hint }
      for _, ln in ipairs(lines) do tt:AddLine(ln, 0.8, 0.8, 0.8, true) end
    end
  end, "ANCHOR_TOP")
  f.Set = function(self, b)
    self.bar = b
    self.label:SetText(b.label)
    local frac = max(0.001, min(1, b.size and (b.cur / b.size) or 1))
    self.fill:SetWidth(max(0.01, (w - 6) * frac))
    W.setWow(self.fill, "bar_yellow", { 0, frac, 0, 1 })
    self.value:SetText(b.size and (b.levelName .. " · " .. b.cur .. " / " .. b.size) or b.levelName)
    self.detail:SetText(b.detail or "")
  end
  return f
end

---------------------------------------------------------------------------
-- Jetons d'état : icônes d'aura (cadre de case du jeu, rouge pour un affaiblissement), nombre en bas à droite
---------------------------------------------------------------------------

-- Rangée centrée de jetons avec infobulle ; list = { { icon = entrée, n = nombre, rim = teinte, info = {...},
-- glow = couleur d'une aura tenue derrière le jeton (épique en jeu) } }.
-- t.medal = { icon, ring (cadre), SetRing(teinte) } (régions du visuel du jeton : tout suit son animation).
function W.tokenRow(parent, maxN, width, size)
  size = size or 30
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, size)
  row.tokens = {}
  for i = 1, maxN do
    local t = CreateFrame("Frame", nil, row)
    t:SetSize(size, size)
    t:EnableMouse(true)
    local face = W.face(t)
    local icon = W.noSnap(face:CreateTexture(nil, "ARTWORK", nil, 0))
    local ring = W.wow(face, "slot_frame", "ARTWORK", 1)
    W.slotFit(face, size, icon, ring) -- icône = ouverture du cadre (liseré fin, comme les cases)
    -- aura tenue (champ glow : épique en jeu), créée éteinte
    t.aura = W.skin(face, "glow_round", "BACKGROUND", 0)
    t.aura:SetSize(size * 1.7, size * 1.7)
    t.aura:SetPoint("CENTER", face, "CENTER", 0, 0)
    t.aura:Hide()
    t.medal = { icon = icon, ring = ring,
      SetRing = function(self, c) c = c or Art.rim.silver self.ring:SetVertexColor(c[1], c[2], c[3], 1) end }
    t.count = W.label(face, "heavy", floor(size * 0.45), C.text, "OVERLAY")
    t.count:SetPoint("BOTTOMRIGHT", face, "BOTTOMRIGHT", 1, -1)
    -- survol : cadre doré de case (créé d'avance, éteint), sans grossir
    t.hot = W.hoverLayer(W.wow(face, "slot_hover", "ARTWORK", 3))
    t.hot:SetSize(size * 1.04, size * 1.04 * WP.slot_hover.ph / WP.slot_hover.pw)
    t.hot:SetPoint("CENTER", face, "CENTER", 0, 0)
    t.hot:SetAlpha(0)
    W.hoverable(t, { paint = function(self, h) self.hot:SetAlpha(h) end })
    W.tooltip(t, function(tt, self)
      local info = self.info
      if not info then return end
      if info.status then W.addStatusLines(tt, info.status, info.n)
      elseif info.power then W.fillCardTooltip(tt, info.power.id, info.power.up, { full = true })
      else
        if info.title then tt:AddLine(info.title, 1, 0.82, 0) end
        if info.text then tt:AddLine(info.text, 1, 1, 1, true) end
      end
    end, "ANCHOR_TOP")
    t:Hide()
    row.tokens[i] = t
  end
  row.pills = row.tokens -- compatibilité
  row.align = "CENTER"
  row.Set = function(self, list)
    local n = min(#list, #self.tokens)
    local gap = 4
    local perLine = max(1, floor((width + gap) / (size + gap)))
    for i = 1, #self.tokens do
      local t, it = self.tokens[i], list[i]
      if it and i <= n then
        t.info = it.info
        W.setIcon(t.medal.icon, it.icon, it.key)
        t.medal:SetRing(it.rim)
        if it.glow then
          t.aura:SetVertexColor(it.glow[1], it.glow[2], it.glow[3], 1)
          t.aura:SetAlpha(it.glow[4] or 0.9)
          t.aura:Show()
        else
          t.aura:Hide()
        end
        t.count:SetText((it.n and it.n ~= 0 and it.n ~= true) and tostring(it.n) or "")
        local line, col = floor((i - 1) / perLine), (i - 1) % perLine
        local inLine = min(perLine, n - line * perLine)
        local x = col * (size + gap)
        if self.align == "CENTER" then x = x + (width - (inLine * (size + gap) - gap)) / 2 end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", self, "TOPLEFT", x, -line * (size + 4))
        t:Show()
      else
        t.info = nil
        t:Hide()
      end
    end
  end
  return row
end
W.pillRow = W.tokenRow

-- États d'une unité en jetons (triés par id, stable).
function W.unitStatuses(unit)
  local ids = {}
  for id, v in pairs(unit.st or {}) do if v and v ~= 0 then ids[#ids + 1] = id end end
  table.sort(ids)
  local list = {}
  for i = 1, #ids do
    local id, n = ids[i], unit.st[ids[i]]
    local s = ns.Statuses[id]
    local bad = s and (s.debuff or s.affix)
    local src = unit.stIcon and unit.stIcon[id]
    list[#list + 1] = {
      icon = (src and Art.statusIcons[src]) or Art.statuses[id] or Art.affixes[id] or { icon = Art.QUESTION },
      n = (type(n) == "number" and not (s and s.flag)) and n or nil, -- état à drapeau : sans nombre
      rim = bad and Art.rim.debuff or nil,
      text = (s and s.name or id), -- nom (infobulle, harnais)
      info = { status = id, n = n }, key = "status:" .. id,
    }
  end
  return list
end

---------------------------------------------------------------------------
-- Carte (composant unique : main, récompense, marchand, deck, amélioration)
---------------------------------------------------------------------------
-- Pièces du pack posées sur le visuel `face` d'après la géométrie de ns.Skin.card (fractions de la
-- largeur du corps) : halo, plaque du bas (mots-clés), corps à la couleur de la carte, médaillon
-- (anneau, icône masquée par l'ouverture exacte du PSD, verre), panneau de texte, languette de coût,
-- ruban horizontal du nom, gemme de rareté ; textes Baloo Chettan 2 blancs à ombre portée.

local SC = Skin.card
W.CARD_W = 124
W.CARD_H = W.CARD_W * SC.aspect

-- Mots de la plaque retirés du texte affiché : registre du langage (Core/Language.lua), en tête
-- (« ^Cast. ») ou en fin (« Cooldown 2. »).
local function keywordStrip()
  local list = {}
  for _, p in ipairs(ns.Language.plates) do
    local w = p.word .. (p.n and " %d+" or "")
    list[#list + 1] = { plate = p, pat = p.head and ("^" .. w .. "%.%s*") or ("%s*" .. w .. "%.") }
  end
  return list
end

-- Langage des cartes (docs/interface.md, « Langage des cartes ») : une clause par ligne dans `text`
-- (séparées par « \n ») ; « Status: » = si l'état est présent ; conditions nommées ; états posés
-- en dernier (« Gain » + nom d'état sur soi, « Apply » sur un ennemi) ; « ⌛ » = nombre de tours, remplacé à
-- l'affichage par une petite icône dans le texte (séquence |T…|t, Media/hourglass.tga, blanche et
-- teinte par la séquence). Mots-clés en évidence par la COULEUR (une seule couleur d'accent : la
-- police ne mêle pas deux graisses dans un même texte).
W.KEYWORD_COLOR = C.goldText
W.HOURGLASS = ROOT .. "hourglass.tga"
W.HOURGLASS_CHAR = "⌛"
local NBSP = "\194\160" -- espace insécable : glue les mots d'un nom d'état et le nom à son nombre
-- Conditions nommées (texte « Name: effect ») et clé de leur explication (Art.keywords).
-- Registre partagé (Core/Language.lua) : { name, key, pattern, text }.
W.CONDITIONS = ns.Language.conditions

-- Le nombre de l'état compte des tours (sablier) ?
function W.isTurnStatus(id)
  local s = ns.Statuses[id]
  return s ~= nil and (s.duration or s.turns) and true or false
end

-- Séquence |T du sablier pour un texte de taille size (unités). Champs (CreateTextureMarkup,
-- Blizzard_SharedXMLBase/TextureUtil.lua) : chemin:hauteur:largeur:décalage x:décalage y:largeur et
-- hauteur du fichier:gauche:droite:haut:bas (en pixels du fichier), puis couleur de sommet r:g:b
-- (0–255) ; entiers (%d partout chez Blizzard).
-- HAUTEUR ET LARGEUR NULLES (« :0:0: », comme Blizzard pour une icône à la taille du texte : « 25
-- |T…:0:0:0:0|t », Blizzard_GarrisonBuildingUI.lua ; « |T…:0|t » des marques du journal de combat) :
-- le client donne à l'icône la hauteur de la police qu'il rend réellement, carrée. Retour en jeu du
-- 12/11/2026 (fenêtre à 115 %, écran 2560 × 1440) : avec une hauteur explicite de 7 (0,70 × 10), le
-- sablier était à peu près deux fois plus petit que le chiffre voisin, lu comme un « z » ; le dessin
-- remplissait pourtant 60/64 de la texture et 7 unités dépassent les chiffres (6,2) : c'est la hauteur
-- explicite qui n'est pas rendue dans les unités du texte. Ce que montre la capture correspond à une
-- hauteur prise en pixels d'écran (7 px pour des chiffres de 6,2 × 2,16 ≈ 13 px : 0,5) ; le faux client
-- du harnais suit ce modèle (H.ICON_PX). Une hauteur nulle n'en dépend pas.
-- Texture 64 × 64 (tools/build_glyphs.py) = la boîte d'une ligne : dessin plein (deux traverses, deux
-- triangles opposés) posé comme un chiffre de Baloo Chettan 2, de la ligne de base (aux W.TEXT_BASE de
-- la boîte) à 0,62 cadratin au-dessus (y 7 à 47), x 12 à 41 : la marge de gauche fait la petite espace
-- après le nombre. Affichée ENTIÈRE (0:64:0:64). color : teinte, blanc par défaut.
W.HOURGLASS_PX = 64
-- Boîte de l'icône (unités du texte) pour un texte de taille size : la hauteur du texte, carrée.
function W.hourglassSize(size)
  return size, size
end
function W.hourglass(size, color)
  local c = color or C.white
  local P = W.HOURGLASS_PX
  return ("|T%s:0:0:0:0:%d:%d:0:%d:0:%d:%d:%d:%d|t"):format(W.HOURGLASS, P, P, P, P,
    floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end

-- Remplace « ⌛ » (et l'espace qui le précède : la marge du dessin en tient lieu) par l'icône.
function W.inlineIcons(text, size, color)
  local m = W.hourglass(size, color)
  return (text:gsub(" ?" .. W.HOURGLASS_CHAR, function() return m end))
end

-- Noms à mettre en évidence : noms d'états, conditions nommées ; les plus longs d'abord.
local keywordNames
local function keywordList()
  if keywordNames then return keywordNames end
  keywordNames = {}
  for id, s in pairs(ns.Statuses) do keywordNames[#keywordNames + 1] = { name = s.name, status = id } end
  for _, c in ipairs(W.CONDITIONS) do keywordNames[#keywordNames + 1] = { name = c.name, cond = c.key } end
  -- mots de règle des épiques (L.rule : Riposte, Bleed…), un par nom
  local ruleNames = {}
  for key, kw in pairs(ns.Language.keywords) do
    if kw.rule and not ruleNames[kw.name] then
      ruleNames[kw.name] = true
      keywordNames[#keywordNames + 1] = { name = kw.name, rule = key }
    end
  end
  table.sort(keywordNames, function(a, b)
    if #a.name ~= #b.name then return #a.name > #b.name end
    return a.name < b.name
  end)
  return keywordNames
end
W.keywordList = keywordList

-- Remplace chaque occurrence de phrase comme mot entier (début, espace, retour ou insécable avant ;
-- fin, espace, retour, ponctuation ou insécable après). fn(phrase) -> remplacement.
local function eachPhrase(text, phrase, fn)
  local out, pos = {}, 1
  while true do
    local i, j = text:find(phrase, pos, true)
    if not i then break end
    local before = i > 1 and text:sub(i - 1, i - 1) or ""
    local after = text:sub(j + 1, j + 1)
    local okB = before == "" or before == " " or before == "\n" or (before == "\160" and text:sub(i - 2, i - 2) == "\194")
    local okA = after == "" or after:find("^[ \n.,:]") ~= nil or after == "\194"
    out[#out + 1] = text:sub(pos, i - 1)
    out[#out + 1] = (okB and okA) and fn(text:sub(i, j)) or text:sub(i, j)
    pos = j + 1
  end
  out[#out + 1] = text:sub(pos)
  return table.concat(out)
end
W.eachPhrase = eachPhrase

-- Le texte d'une carte contient-il phrase comme mot entier ?
function W.hasPhrase(text, phrase)
  local found = false
  eachPhrase(text, phrase, function(p) found = true return p end)
  return found
end

-- Clause d'état posé (« Gain <état> … » / « Apply … ») ? « Gain 5 Absorb. » n'en est pas une : après
-- « Gain », il faut un nom d'état.
local function plainClause(s)
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", W.HOURGLASS_CHAR):gsub(NBSP, " "))
end
function W.isStateClause(s)
  local p = plainClause(s)
  if p:find("^Apply ") then return true end
  local rest = p:match("^Gain (.*)$")
  if not rest then return false end
  for id, s in pairs(ns.Statuses) do
    if rest:sub(1, #s.name + 1) == s.name .. " " then return true end
  end
  return false
end

-- Texte affiché : sans les mots-clés de la plaque du bas, noms d'états et conditions insécables et
-- en couleur d'accent, chiffres en évidence (blancs, ou verts s'ils changent avec l'amélioration).
-- Garde les « \n » des clauses et le « ⌛ » (posé à la taille du palier par la mise en page).
-- spendOff : la clause « Spend N: … » est éteinte (gris, chiffres compris) : le bonus ne sera pas payé.
W.SPEND_OFF_COLOR = C.textDim
function W.cardBody(d, base, spendOff)
  local text = d.text or ""
  for _, k in ipairs(keywordStrip()) do
    if ns.Language.plateWord(k.plate, d) or (k.plate.key == "power" and d.rarity == "epic") then
      text = text:gsub(k.pat, "")
    end
  end
  -- (ligne d'état : le verbe et le nom de l'état peuvent se couper, coupure de second choix de la
  -- mise en page, W.clauseGroups ; plus d'insécable entre eux)
  -- un nom d'état insécable avec son nombre (« DoT 5 », « Sundered 2 ⌛ ») ; « to all » insécable
  for _, k in ipairs(keywordList()) do
    if k.status then
      text = eachPhrase(text, k.name, function(p) return p .. "\001" end)
      text = text:gsub("\001 ([+%-]?%d)", NBSP .. "%1"):gsub("\001", "")
    end
  end
  text = eachPhrase(text, "to all", function() return "to" .. NBSP .. "all" end)
  local baseNums = {}
  if base then for n in (base.text or ""):gmatch("%d+") do baseNums[#baseNums + 1] = n end end
  local i = 0
  text = text:gsub("%d+", function(n)
    i = i + 1
    if base and baseNums[i] ~= n then return W.colorize(n, C.upGreen) end
    return W.colorize(n, C.white)
  end)
  -- mots-clés : noms d'états et conditions nommées (une seule couleur d'accent)
  for _, k in ipairs(keywordList()) do
    text = eachPhrase(text, k.name, function(p) return W.colorize(p, W.KEYWORD_COLOR) end)
  end
  if spendOff then
    -- clause « Spend N: … » éteinte : couleurs retirées, la clause entière en gris
    local out = {}
    for l in (text .. "\n"):gmatch("(.-)\n") do
      local plain = l:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      if plain:find("^Spend %d+: ") then l = W.colorize(plain, W.SPEND_OFF_COLOR) end
      out[#out + 1] = l
    end
    text = table.concat(out, "\n")
  end
  return text
end

-- Texte d'une carte pour une infobulle (jeton de Pouvoir, recharge, aperçu d'amélioration) : comme
-- sur la carte (sans les mots de la plaque, mots-clés en couleur), une ligne par clause, sablier en
-- icône à la taille du texte des infobulles. base : chiffres changés en vert (aperçu).
function W.cardTextLines(d, base)
  local out = {}
  for l in (W.cardBody(d, base) .. "\n"):gmatch("(.-)\n") do
    if l ~= "" then out[#out + 1] = W.inlineIcons((l:gsub(NBSP, " ")), 12) end
  end
  return out
end

-- Mots-clés de la plaque du bas.
function W.cardPills(d)
  local list = {}
  for _, p in ipairs(ns.Language.plates) do
    local w = ns.Language.plateWord(p, d)
    if w then list[#list + 1] = w end
  end
  return list
end

-- Zone utile du texte : intérieur sombre du panneau d'ardoise (mesuré sur les pixels de
-- Media/card_panel.tga, critère du harnais U22 : opaque et r + g + b < 360), sous la gemme de rareté
-- (bas opaque de la plus grande : 0,7622, mesuré sur Media/gem_*.tga), marges comprises. Fractions de
-- la largeur du corps. Forme réelle de l'intérieur : demi-largeur 0,3444 (x 14 à 240 sur 256 px) de
-- y 0,7039 à 1,0735 ; là, un DÉCROCHEMENT (le bord gauche passe de x 14 à 25 px d'une ligne à la
-- suivante : demi-largeur 0,3110 côté gauche, le côté le plus étroit), puis un biseau qui rentre de
-- 0,557 par unité de hauteur jusqu'au bas (1,1799). Le harnais vérifie chaque ligne posée contre les
-- pixels mêmes des textures (Sim/ui_harness.lua, U22) ; W.cardTextHalf en est le modèle exact.
local TZ = {
  cx = 0.4985,                  -- axe de l'intérieur
  half = 0.3004,                -- demi-largeur : 0,3444 moins la marge latérale (0,044 ≈ 5,5 unités)
  top = 0.7661,                 -- haut des lignes : sous la gemme (les lignes ont ~2 unités de vide en haut)
  bottom = 1.1492,              -- bas des lignes : 5 unités au-dessus du bas de l'intérieur
  inHalf = 0.3444,              -- demi-largeur de l'intérieur au-dessus du biseau
  bevY = 1.0735, bevIn = 0.3110, bevSlope = 0.557, -- biseau : début (décrochement), demi-largeur, pente
  margin = 0.044,               -- marge latérale (côtés et biseau)
  bevGuard = 2 / 124,           -- le biseau est jugé 2 unités sous l'encre de la ligne (marge du bas, U22)
  -- centre optique : milieu de l'intérieur sombre dans la colonne du milieu (haut 87,1 unités, bas
  -- 146,3 ; harnais UC), même marge visible au-dessus de l'encre de la première ligne et sous la ligne
  -- de base de la dernière
  optY = 0.94114,
}
W.CARD_TEXT = TZ
-- Paliers de taille du texte (unités de la carte) : chaque carte prend le plus grand qui tient dans la
-- zone utile en repliant ses clauses sur autant de lignes que la zone en contient à ce palier
-- (layoutBody) ; 7 = plancher lisible. Sous le plancher : secours signalé (bodyFit.under).
W.BODY_SIZES = { 10, 9.5, 9, 8.5, 8, 7.5, 7 }
-- Carte épique (14/11/2026) : deux lignes au plus. Elle prend le plus grand palier, jusqu'au plancher
-- W.EPIC_FLOOR, où son texte tient en W.EPIC_LINES lignes (« Each Parry gained: Riposte 1. » : 9, trois
-- lignes à 10) ; sinon la règle commune (texte trop long, signalé par le harnais).
W.EPIC_LINES = 2
W.EPIC_FLOOR = 8.5
-- Lignes au plus du texte d'une carte (nil : celles que la zone contient).
function W.cardMaxLines(d)
  if d and d.rarity == "epic" then return W.EPIC_LINES end
  return nil
end
-- Position verticale du bloc (retour en jeu du 12/11/2026, Frostbolt : « le texte est remonté, il ne
-- devrait pas ») : le bloc est CENTRÉ sur le centre optique du panneau (TZ.optY : encre de la première
-- ligne et ligne de base de la dernière à égale distance des bords de l'intérieur sombre). Il ne se
-- décale que si une ligne sortirait de la forme du panneau (biseau, gemme, bas de la zone), du minimum
-- nécessaire et de W.BODY_SHIFT unité au plus ; au-delà, une autre coupure ou un palier plus petit.
-- (Avant : le bloc remontait jusqu'en haut de la zone, 0,5 / 0,33 / 0,17 / 0 du jeu vertical, pour
-- élargir sa dernière ligne contre un biseau mal modélisé : Frostbolt 8,5 unités trop haut.)
W.BODY_SHIFT = 1
W.BODY_SHIFT_STEP = 0.25
W.SHIFT_COST = 2       -- coût d'un décalage d'une unité (préféré à une coupure de plus, W.BREAK)
-- Encre dans une ligne (police Baloo Chettan 2, même modèle que le faux client Sim/ui_render.lua) :
-- ligne de base aux 1,078 / 1,47 de la hauteur de ligne (ascendante / ascendante + descendante, hhea),
-- capitales et chiffres hauts de 0,602 cadratin (OS/2 sCapHeight).
W.TEXT_BASE = 1.078 / 1.47
W.TEXT_CAP = 0.602
-- Jambages (g j p q y, virgule, parenthèses… : jusqu'à 0,2 cadratin sous la ligne de base).
W.TEXT_DESC = 0.2
W.DESC_CHARS = "[gjpqyQ,;/()%[%]{}$@_]"
-- Bas de l'encre d'une ligne (texte affiché, codes compris) dont la boîte commence à yTop (unités) :
-- ligne de base, plus les jambages s'il y en a.
function W.lineInkBottom(line, yTop, lh, size)
  local plain = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
  return yTop + W.TEXT_BASE * lh + (plain:find(W.DESC_CHARS) and W.TEXT_DESC * size or 0)
end
W.BODY_UNDER = { 6.5, 6 }
-- Nom sur le ruban : une ligne, le plus grand palier qui tient, marge de 4 unités de chaque côté.
W.NAME_SIZES = { 11, 10, 9, 8, 7 }
W.NAME_UNDER = { 6.5, 6 }
W.NAME_MARGIN = 4

-- Boîte d'un texte dont la mise en page a choisi les lignes (retours explicites) : largeur ET hauteur
-- posées, bien plus grandes que le texte (W.TEXT_ROOM, plus W.TEXT_PAD unités), lignes illimitées
-- (SetMaxLines(0)). Retour en jeu (fenêtre à 115 %, zoom net, carte survolée en main) : « PW: Radiance »
-- affichait « Gain 4 Absorb.... » sur une ligne au lieu de deux. Le texte avait une hauteur AUTOMATIQUE
-- (aucune hauteur posée) : à l'échelle survolée, la hauteur que le client lui donnait ne suffisait plus
-- pour deux lignes, il a gardé la première et l'a finie par « … » (arrondi de la police à l'échelle
-- effective, voir docs/interface.md). Avec une boîte posée et large, le client n'a jamais à recouper ni
-- à tronquer, à aucune échelle (fenêtre 0,6 à 1,5, survol, zoom net, fluide ou lisse), même si sa police
-- rendue est un peu plus grande que mesurée. Le texte reste centré dans la boîte (ancrage par le centre et
-- JustifyV "MIDDLE", ou par le haut et JustifyV "TOP"). n : nombre de lignes ; w : plus grande largeur
-- permise d'une ligne ; lh : hauteur d'une ligne (sinon GetLineHeight).
-- W.TEXT_SAFE : marge du choix des paliers (une ligne mesurée doit tenir dans sa zone multipliée par
-- W.TEXT_SAFE : la mesure est faite à l'échelle de UIParent, l'affichage à une autre).
W.TEXT_SAFE = 1.02
W.TEXT_ROOM = 1.3
W.TEXT_PAD = 8
function W.looseBox(fs, n, w, lh)
  lh = lh or (fs.GetLineHeight and fs:GetLineHeight()) or (fs._size or 12) * 1.5
  if fs.SetMaxLines then fs:SetMaxLines(0) end
  fs:SetWidth(w * W.TEXT_ROOM + W.TEXT_PAD)
  fs:SetHeight(max(1, n) * lh * W.TEXT_ROOM + W.TEXT_PAD)
end

-- Demi-largeur utile d'une ligne dont l'ENCRE finit à la hauteur y (fraction de la largeur du corps ;
-- ligne de base, ou bas des jambages si la ligne en a, W.lineInkBottom) : forme réelle de l'intérieur
-- (pleine largeur au-dessus du biseau, décrochement, pente), jugée TZ.bevGuard sous l'encre, moins la
-- marge latérale. (Avant le 12/11/2026 : la pente du biseau était prolongée AU-DESSUS de son début,
-- jusqu'à 10 unités de largeur retirées entre y 124 et 133 où l'intérieur est plein, et jugée au bas de
-- la BOÎTE de la ligne, 2,7 unités sous la ligne de base à la taille 10 ; la mise en page remontait
-- alors les blocs pour élargir leur dernière ligne.)
function W.cardTextHalf(y)
  local yy = y + TZ.bevGuard
  local inner = TZ.inHalf
  if yy >= TZ.bevY then inner = TZ.bevIn - (yy - TZ.bevY) * TZ.bevSlope end
  return min(TZ.half, inner - TZ.margin)
end

-- Texte de mesure (même police que le texte des cartes), hors de toute carte.
local measurer
local function measureFS(kind, size)
  if not measurer then
    measurer = W.fontPreload:CreateFontString(nil, "OVERLAY")
    measurer:SetPoint("BOTTOMLEFT", W.fontPreload, "BOTTOMLEFT", 0, 0)
    measurer:SetWordWrap(false)
    -- même rendu que les textes des cartes (hauteur non arrondie) : mesures proportionnelles
    if measurer.SetSmoothScaling then measurer:SetSmoothScaling(true) end
  end
  if measurer._fontKind ~= kind or measurer._size ~= size then
    measurer._fontKind, measurer._size = kind, size
    setFont(measurer, kind, size)
  end
  return measurer
end

local function widthOf(m, s)
  m:SetText(s)
  return m:GetStringWidth() or 0
end

-- Coupures d'une clause (retour du joueur : « s'autoriser à revenir à la ligne au lieu de réduire le
-- texte ») : la clause est découpée en GROUPES insécables, et chaque espace entre deux groupes est une
-- coupure possible avec son coût (plus petit = préférée). Ordre de préférence : entre deux clauses
-- (coût nul, hors de cette fonction ; « clause » entre deux phrases d'un texte coulé) ; après une
-- condition « Name: » (cond) ; après une virgule (comma) ; entre le verbe et le nom d'état (« Apply » /
-- « Demoralized 1 ⌛ », state) ; avant « to all », « to … », « per … », « once per », « three times »,
-- « twice » (tail) ; ailleurs en dernier recours (any). Jamais coupés (même
-- groupe) : un nombre et ce qu'il compte (« 5 Absorb », « +2 Insanity », « 1 HP », « Stunned 1 ⌛ »
-- par l'insécable de W.cardBody), un verbe et son nombre (« Deal 6 », « Draw 1. », « Pay 3 HP. »), un
-- nombre et le mot d'avant quand rien ne suit qu'il compte (« deal 4 + 4 »), « N times », les noms en
-- plusieurs mots (noms d'états et conditions nommées, ressources : « Combo », « Arcane
-- Charge », « Last Breath: »), une ponctuation détachée, le sablier et son nombre (icône collée).
W.BREAK = { clause = 1, cond = 10, comma = 12, state = 14, tail = 18, any = 40 }
W.BREAK_SHORT = 60     -- ligne d'un seul mot très court (« to », « a ») dans une clause coupée
W.BREAK_DANGLING = 12  -- ligne coupée après un petit mot (« the », « to », « per »…)
W.BREAK_BALANCE = 10   -- lignes d'une même clause inégales (écart rapporté à la largeur utile)
local SMALL = { the = true, a = true, an = true, to = true, of = true, at = true, ["and"] = true,
  ["or"] = true, per = true, with = true, ["in"] = true, on = true, ["for"] = true, its = true }
local NUMVERBS = { deal = true, heal = true, draw = true, pay = true, lose = true, spend = true,
  cooldown = true, cost = true, costs = true }
local COUNTED = { more = true, mana = true, damage = true, less = true }
local NUMWORDS = { two = true, three = true, four = true, five = true, six = true, seven = true, eight = true }
local TAIL = { to = true, per = true, once = true, twice = true }

local function plainWord(w)
  return (w:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", W.HOURGLASS_CHAR))
end
-- mot sans ponctuation finale, insécables en espaces
local function bare(p) return ((p:gsub(NBSP, " "):gsub("[.,:;!?]+$", ""))) end
local function firstWord(p) return (bare(p):match("^(%S+)") or ""):lower() end

-- Noms en plusieurs mots (noms d'états, conditions nommées, ressources), les plus longs d'abord.
local phraseList
local function phrases()
  if phraseList then return phraseList end
  phraseList = {}
  local function add(name)
    if name and name:find(" ", 1, true) then
      local ws = {}
      for w in name:gmatch("%S+") do ws[#ws + 1] = w end
      phraseList[#phraseList + 1] = ws
    end
  end
  for _, k in ipairs(keywordList()) do add(k.name) end
  for _, r in pairs(ns.Language.resources) do add(r.name) add(r.plural) end
  table.sort(phraseList, function(a, b) return #a > #b end)
  return phraseList
end

-- Le texte p commence-t-il par un nom d'état (« Stunned 1 ⌛ », « Stealth ») ?
local function startsStatus(p)
  p = p:gsub(NBSP, " ")
  for _, k in ipairs(keywordList()) do
    if k.status and p:sub(1, #k.name) == k.name and not p:sub(#k.name + 1, #k.name + 1):find("^%a") then return true end
  end
  return false
end

-- Groupes d'une clause (texte de W.cardBody, sablier déjà en icône) : { groups = { { text, plain,
-- short, small } }, cost = { coût de la coupure après le groupe k } }.
function W.clauseGroups(clause)
  local raw, pl = {}, {}
  for w in clause:gmatch("[^ ]+") do raw[#raw + 1] = w pl[#pl + 1] = plainWord(w) end
  local n = #raw
  local glue = {}
  -- noms en plusieurs mots
  for _, ph in ipairs(phrases()) do
    for i = 1, n - #ph + 1 do
      local ok = true
      for k = 1, #ph do
        local w = pl[i + k - 1]:gsub(NBSP, " ")
        local want = ph[k]
        if k < #ph then
          if w ~= want then ok = false break end
        elseif w:sub(1, #want) ~= want or w:sub(#want + 1, #want + 1):find("^%a") then
          ok = false break
        end
      end
      if ok then for k = i, i + #ph - 2 do glue[k] = true end end
    end
  end
  for i = 1, n do
    local p = pl[i]:gsub("^−", "-")
    if p == "+" or p == "-" or p == "×" then
      -- opérateur : collé des deux côtés (« deal 4 + 4 per Insanity »)
      if i > 1 then glue[i - 1] = true end
      if i < n then glue[i] = true end
    elseif p:match("^[+%-]?%d+$") then
      -- nombre nu : avec ce qu'il compte (mot suivant à majuscule, « more », « mana »…) ; « +N » toujours
      -- avec le mot suivant ; avec le verbe d'avant (« Deal 6 », « Pay 3 HP »), ou avec le mot d'avant
      -- s'il ne compte rien après lui (« deal 4 + 4 »)
      local nx = pl[i + 1] and bare(pl[i + 1])
      local counted = nx ~= nil and (nx:find("^%u") ~= nil or COUNTED[(nx:match("^(%S+)") or ""):lower()] == true)
      if p:find("^%+") and nx then counted = true end
      if counted then glue[i] = true end
      if i > 1 and (NUMVERBS[firstWord(pl[i - 1])] or not counted) then glue[i - 1] = true end
    elseif p:match("^[+%-]?%d+[.,:;]$") or p:match("^[:;!?]+$") then
      -- nombre qui finit la phrase (« Draw 1. », « Spend 2: »), ponctuation détachée
      if i > 1 then glue[i - 1] = true end
    end
    if NUMWORDS[firstWord(pl[i])] and pl[i + 1] and firstWord(pl[i + 1]) == "times" then glue[i] = true end
    -- « once per … » : une seule tournure
    if firstWord(pl[i]) == "once" and pl[i + 1] and firstWord(pl[i + 1]) == "per" then glue[i] = true end
  end
  -- groupes et coûts des coupures entre eux
  local groups, cost = {}, {}
  local cur = { i = 1 }
  for i = 1, n do
    if i == n or not glue[i] then
      local parts, pparts = {}, {}
      for k = cur.i, i do parts[#parts + 1] = raw[k] pparts[#pparts + 1] = pl[k] end
      local plain = table.concat(pparts, " "):gsub(NBSP, " ")
      local last = bare(pl[i]):match("(%S+)$") or ""
      groups[#groups + 1] = { text = table.concat(parts, " "), plain = plain, last = i,
        short = cur.i == i and #bare(pl[i]) <= 3 and not bare(pl[i]):find("%d") and not pl[i]:find(":$"),
        small = SMALL[last:lower()] == true }
      if i < n then
        local pa, pb = pl[i], pl[i + 1]
        local c
        if pa:find(":$") then c = W.BREAK.cond
        elseif pa:find("%.$") then c = W.BREAK.clause
        elseif pa:find(",$") then c = W.BREAK.comma
        elseif (firstWord(pa) == "apply" or firstWord(pa) == "gain") and cur.i == i and startsStatus(pb) then c = W.BREAK.state
        elseif TAIL[firstWord(pb)] or (NUMWORDS[firstWord(pb)] and pl[i + 2] and firstWord(pl[i + 2]) == "times") then c = W.BREAK.tail
        else c = W.BREAK.any end
        cost[#groups] = c
      end
      cur = { i = i + 1 }
    end
  end
  return { groups = groups, cost = cost }
end

-- Une ligne qui finit dans une couleur ouverte (nom d'état coupé en deux lignes) la ferme, et la
-- ligne suivante la rouvre : chaque ligne est autonome.
local function balanceColors(lines)
  local open
  for k = 1, #lines do
    local l = lines[k]
    if open then l = open .. l end
    open = nil
    local pos = 1
    while true do
      local i = l:find("|[cr]", pos)
      if not i then break end
      if l:sub(i + 1, i + 1) == "c" then open = l:sub(i, i + 9) pos = i + 10 else open = nil pos = i + 2 end
    end
    if open then l = l .. "|r" end
    lines[k] = l
  end
  return lines
end
W.balanceColors = balanceColors

-- Paragraphes du texte d'une carte selon le mode : "clauses" = une clause par paragraphe ; "flow" =
-- les clauses d'effet coulent ensemble, chaque clause d'état posé (« Donne » / « Applique ») reste un
-- paragraphe ; "flowAll" = les clauses d'état sont groupées en un dernier paragraphe (« Apply
-- DoT 3. Gain Regen 1 »). Un paragraphe commence toujours une ligne.
-- Une clause conditionnelle (« DoT: … », « Execute: … ») commence toujours une ligne, et la
-- clause qui la suit aussi (elle ne doit pas paraître soumise à la condition) : seules les clauses
-- simples qui se suivent coulent ensemble.
function W.isConditionClause(s)
  local label = plainClause(s):match("^(.-): ")
  if not label then return false end
  for _, k in ipairs(keywordList()) do if k.name == label then return true end end
  for _, c in ipairs(W.CONDITIONS) do
    if c.pattern and label:find(c.pattern) then return true end
  end
  return false
end

function W.cardParagraphs(text, mode)
  local clauses = {}
  for l in (text .. "\n"):gmatch("(.-)\n") do if l ~= "" then clauses[#clauses + 1] = l end end
  if mode == "clauses" then return clauses end
  local paras, states = {}, {}
  local prevSimple = false
  for _, cl in ipairs(clauses) do
    if W.isStateClause(cl) then
      states[#states + 1] = cl
    else
      local simple = not W.isConditionClause(cl)
      if simple and prevSimple then paras[#paras] = paras[#paras] .. " " .. cl else paras[#paras + 1] = cl end
      prevSimple = simple
    end
  end
  if mode == "flowAll" and #states > 0 then
    -- états groupés (le verbe de chaque état est déjà collé à son nom, W.cardBody)
    paras[#paras + 1] = table.concat(states, ". ")
  else
    for _, s in ipairs(states) do paras[#paras + 1] = s end
  end
  return paras
end

-- Coupe les paragraphes paras (un paragraphe = une clause, qui commence toujours une ligne) en lignes
-- à la taille size dans la zone (top, bottom en unités). Hauteur de ligne MESURÉE par le client
-- (texte de mesure « Ég ») : la zone contient floor(hauteur ÷ ligne) lignes à ce palier, toutes
-- utilisables. Chaque clause peut se replier sur plusieurs lignes, aux coupures de W.clauseGroups ;
-- chaque ligne tient dans la largeur de la zone à son bas (biseau compris, marge W.TEXT_SAFE). Parmi
-- les mises en page qui tiennent, la moins coûteuse : somme des coupures, ligne d'un seul petit mot,
-- ligne finie par un petit mot, lignes inégales dans une clause, bloc décalé de son centre (W.SHIFT_COST
-- par unité, W.BODY_SHIFT au plus), pas d'écart entre clauses (W.CLAUSE_GAP) quand il y a la place ; à
-- coût égal, le moins de lignes. Sablier posé à la taille size (largeur mesurée avec le texte). Renvoie
-- { lines, y0, gap, clause = { clause de chaque ligne }, cost }, lh ; nil si rien ne tient ; nil,
-- "font" si la police ne mesure rien (pas encore chargée).
-- Écart entre deux clauses (fraction de la hauteur de ligne), quand la hauteur le permet : une clause
-- repliée sur deux lignes reste lisible comme UNE clause (« Deal 6. » / écart / « Apply » / « Sundered 3 ⌛ »).
-- Sans écart, coût W.NOGAP_COST : préféré à une coupure de plus.
W.CLAUSE_GAP = 1 / 3
W.NOGAP_COST = 3
-- Le bas de l'intérieur sombre est mesuré à y ≈ 146,3 unités (liseré clair dès 146,5 ; 1,19 de la
-- largeur, 147,6, dans le commentaire de TZ) : la marge de 5 unités sous TZ.bottom n'en fait que ~3,8.
-- Avec des lignes d'un cadratin, la dernière ligne peut arriver au bas de la zone : 0,5 unité de garde
-- pour garder 4 unités sous la boîte de la ligne (vérifié sur les pixels, harnais U22).
W.TEXT_BOTTOM_GUARD = 0.5
local function layoutBody(paras, size, top, bottom, maxLines)
  local CW = W.CARD_W
  local m = measureFS("bold", size)
  m:SetText("Ég")
  local lh = m:GetStringHeight() or 0
  if lh <= 0 or widthOf(m, "Ég") <= 0 then return nil, "font" end
  -- garde de W.TEXT_BOTTOM_GUARD au bas : la dernière ligne peut maintenant toucher le bas de la zone
  local H = bottom - top - W.TEXT_BOTTOM_GUARD
  local N = floor(H / lh + 1e-6)
  -- lignes au plus (épique : W.EPIC_LINES), sans changer la zone ni le centrage
  if maxLines and maxLines < N then N = maxLines end
  local C = #paras
  if C == 0 then return { lines = {}, y0 = top, clause = {} }, lh end
  if C > N then return nil, lh end
  local full = 2 * TZ.half * CW
  -- candidats de chaque clause : toutes les façons de la couper en lignes assez étroites
  local cands, groupsOf = {}, {}
  for c = 1, C do
    local g = W.clauseGroups(W.inlineIcons(paras[c], size))
    groupsOf[c] = g
    local G = #g.groups
    local memo = {}
    local function span(i, j)
      local key = i * 256 + j
      local v = memo[key]
      if not v then
        local parts = {}
        for k = i, j do parts[#parts + 1] = g.groups[k].text end
        -- marge W.TEXT_SAFE : la ligne doit tenir avec quelques pour cent de reste
        v = widthOf(m, (table.concat(parts, " "):gsub(NBSP, " "))) * W.TEXT_SAFE
        memo[key] = v
      end
      return v
    end
    local list, acc, ws = {}, {}, {}
    local maxK = N - (C - 1)
    local function finish()
      local k, cost = #acc, 0
      if k > 1 then
        local lo, hi = math.huge, 0
        for t = 1, k do
          local a, b = acc[t][1], acc[t][2]
          if t < k then
            cost = cost + g.cost[b]
            if g.groups[b].small then cost = cost + W.BREAK_DANGLING end
          end
          if a == b and g.groups[a].short then cost = cost + W.BREAK_SHORT end
          lo, hi = min(lo, ws[t]), max(hi, ws[t])
        end
        cost = cost + W.BREAK_BALANCE * (hi - lo) / full
      end
      local r, w, dsc = {}, {}, {}
      for t = 1, k do
        r[t] = { acc[t][1], acc[t][2] } w[t] = ws[t]
        -- jambages de la ligne (le biseau est jugé sous l'encre, W.cardTextHalf)
        dsc[t] = 0
        for q = acc[t][1], acc[t][2] do
          if g.groups[q].plain:find(W.DESC_CHARS) then dsc[t] = W.TEXT_DESC * size break end
        end
      end
      list[#list + 1] = { ranges = r, widths = w, desc = dsc, cost = cost }
    end
    local function rec(i)
      if i > G then finish() return end
      if #acc >= maxK then return end
      for j = i, G do
        local w = span(i, j)
        if w > full then break end
        acc[#acc + 1] = { i, j }
        ws[#ws + 1] = w
        rec(j + 1)
        acc[#acc] = nil
        ws[#ws] = nil
      end
    end
    if G > 0 then rec(1) end
    if #list == 0 then return nil, lh end
    table.sort(list, function(a, b) return a.cost < b.cost end)
    cands[c] = list
  end
  -- meilleure combinaison pour n lignes en tout, avec ou sans écart entre clauses : bloc centré sur
  -- le centre optique (relevé de moitié si une plaque relève le bas de la zone), décalé seulement si
  -- une ligne sort de la forme, de W.BODY_SHIFT au plus
  local best
  local gaps = (C > 1 and W.CLAUSE_GAP > 0) and { W.CLAUSE_GAP * lh, 0 } or { 0 }
  local optC = TZ.optY * CW - (TZ.bottom * CW - bottom) / 2
  -- centre de la boîte du bloc qui met le centre de l'encre sur optC
  local boxC = optC + lh * (0.5 - W.TEXT_BASE) + W.TEXT_CAP * size / 2
  local lowest = top + H
  for n = C, N do
   for _, gap in ipairs(gaps) do
    local total = n * lh + (C - 1) * gap
    local ideal = boxC - total / 2
    -- dans la zone (sous la gemme, au-dessus du bas) : le moins de décalage possible
    local y0c = max(top, min(ideal, lowest - total))
    local ys = {}
    if total <= H + 1e-6 and math.abs(y0c - ideal) <= W.BODY_SHIFT + 1e-6 then
      ys[1] = y0c
      -- puis vers le haut (le biseau rétrécit le bas), pas à pas, sans sortir de la zone
      local k = 1
      while true do
        local y = y0c - k * W.BODY_SHIFT_STEP
        if y < top - 1e-6 or math.abs(y - ideal) > W.BODY_SHIFT + 1e-6 then break end
        ys[#ys + 1] = y
        k = k + 1
      end
    end
    for _, y0 in ipairs(ys) do
      local shiftCost = W.SHIFT_COST * math.abs(y0 - ideal)
      local dp = { [0] = { [0] = { cost = 0 } } }
      for c = 1, C do
        local row = {}
        for L, st in pairs(dp[c - 1]) do
          for ci, cand in ipairs(cands[c]) do
            local k = #cand.ranges
            if L + k <= n - (C - c) then
              local e = row[L + k]
              local nc = st.cost + cand.cost
              if not e or nc < e.cost then
                local ok = true
                for t = 1, k do
                  -- bas de l'encre : ligne de base de la ligne, plus ses jambages
                  local yi = y0 + (L + t - 1) * lh + (c - 1) * gap + W.TEXT_BASE * lh + cand.desc[t]
                  if cand.widths[t] > 2 * W.cardTextHalf(yi / CW) * CW then ok = false break end
                end
                if ok then row[L + k] = { cost = nc, prev = L, cand = ci } end
              end
            end
          end
        end
        dp[c] = row
      end
      local e = dp[C][n]
      if e then
        local tc = e.cost + shiftCost + ((C > 1 and gap == 0) and W.NOGAP_COST or 0)
        if not best or tc < best.cost - 1e-9 then best = { cost = tc, n = n, y0 = y0, dp = dp, gap = gap } end
        -- premier essai qui tient à cette position : inutile de monter davantage
        break
      end
    end
   end
  end
  if not best then return nil, lh end
  -- lignes de la meilleure combinaison
  local picks, L = {}, best.n
  for c = C, 1, -1 do
    local e = best.dp[c][L]
    picks[c] = cands[c][e.cand]
    L = e.prev
  end
  local lines, clause = {}, {}
  for c = 1, C do
    local g = groupsOf[c]
    for _, r in ipairs(picks[c].ranges) do
      local parts = {}
      for k = r[1], r[2] do parts[#parts + 1] = g.groups[k].text end
      lines[#lines + 1] = (table.concat(parts, " "):gsub(NBSP, " "))
      clause[#clause + 1] = c
    end
  end
  return { lines = balanceColors(lines), y0 = best.y0, clause = clause, cost = best.cost, gap = best.gap }, lh
end
W.layoutBody = layoutBody

local layoutCache = {}
function W.clearTextCache() layoutCache = {} end

-- Pose le texte de la carte : premier palier où il tient, mise en page figée (lignes séparées par
-- des retours explicites dans une boîte posée, large et haute, W.looseBox : le client ne recoupe ni ne
-- tronque jamais, à aucune échelle), puis vérification par le client (GetNumLines, IsTruncated,
-- GetStringHeight). bottom : bas de la zone (unités), relevé si une plaque mord sur le panneau.
-- Essais dans l'ordre : une clause par paragraphe (chaque clause commence une ligne et peut se
-- replier), du plus grand palier au plus petit, secours compris ; seulement ensuite, palier par palier,
-- texte qui coule (« flow » : clauses simples qui se suivent sur les mêmes lignes) puis états groupés
-- (« flowAll »). Le palier retenu est donc le plus grand où le texte tient en se repliant.
function W.cardTries(text)
  local all = {}
  for _, s in ipairs(W.BODY_SIZES) do all[#all + 1] = { s = s } end
  for _, s in ipairs(W.BODY_UNDER) do all[#all + 1] = { s = s, under = true } end
  local tries, seen = {}, {}
  local function add(e, mode)
    local paras = W.cardParagraphs(text, mode)
    local key = e.s .. "|" .. table.concat(paras, "\n")
    if seen[key] then return end
    seen[key] = true
    tries[#tries + 1] = { size = e.s, under = e.under, mode = mode, paras = paras, key = key }
  end
  for _, e in ipairs(all) do add(e, "clauses") end
  for _, e in ipairs(all) do
    add(e, "flow")
    add(e, "flowAll")
  end
  return tries
end

-- Blocs du texte d'une carte : card.body, puis d'autres textes (W.BODY_PARTS en tout, créés avec la
-- carte, cachés tant qu'inutiles). Sans écart entre clauses, tout le texte est dans card.body ; avec
-- écart, un texte par clause (même police, même boîte posée), posés l'un sous l'autre.
W.BODY_PARTS = 6
-- Texte complet affiché (lignes de tous les blocs, retours compris).
function W.cardBodyText(card)
  local out = {}
  for k = 1, card.bodyUsed or 1 do
    local t = card.bodyParts and card.bodyParts[k] and card.bodyParts[k]:GetText() or (k == 1 and card.body:GetText())
    if t and t ~= "" then out[#out + 1] = t end
  end
  return table.concat(out, "\n")
end

local function fitBody(card, text, bottom, maxLines)
  local CW = W.CARD_W
  local fs = card.body
  local parts = card.bodyParts or { fs }
  local top = TZ.top * CW
  for k = 2, #parts do
    parts[k]:SetText("")
    parts[k]:Hide()
  end
  card.bodyUsed = 1
  fs:ClearAllPoints()
  fs:SetPoint("CENTER", card.bg, "TOPLEFT", TZ.cx * CW, -(top + bottom) / 2)
  -- cap : palier interdit et au-dessus (garde-fou W.checkCardTexts : le client a tronqué ce texte)
  local cap = card.textCap and card.textCap.body
  local fit, fontErr
  -- carte à lignes comptées (épique) : d'abord les essais en maxLines lignes, jusqu'à W.EPIC_FLOOR
  local tries = W.cardTries(text)
  if maxLines then
    local limited = {}
    for _, t in ipairs(tries) do
      if t.mode == "clauses" and not t.under and t.size >= W.EPIC_FLOOR then
        limited[#limited + 1] = { size = t.size, mode = t.mode, paras = t.paras, key = t.key, max = maxLines }
      end
    end
    for _, t in ipairs(tries) do limited[#limited + 1] = t end
    tries = limited
  end
  for _, t in ipairs(tries) do
    local s = t.size
    local key = floor(bottom * 10 + 0.5) .. "|" .. (t.max or "") .. "|" .. t.key
    local lay = (not cap or s < cap) and layoutCache[key]
    local err, lh
    if lay == nil then
      lay, err = layoutBody(t.paras, s, top, bottom, t.max)
      if err == "font" then fontErr = true break end
      lh = err
      if lay then lay.lh = lh end
      layoutCache[key] = lay or false
    end
    if lay then
      local lines = lay.lines
      -- blocs : un par clause s'il y a un écart (et assez de textes), sinon un seul
      local blocks = {}
      local split = (lay.gap or 0) > 0 and (lay.clause[#lines] or 1) <= #parts
      for i, l in ipairs(lines) do
        local b = split and lay.clause[i] or 1
        blocks[b] = blocks[b] or {}
        blocks[b][#blocks[b] + 1] = l
      end
      local ok, y = true, lay.y0
      for b = 1, #blocks do
        local p = parts[b]
        local bl = blocks[b]
        W.setSize(p, s)
        -- boîte posée, large et haute (W.looseBox) : le client ne recoupe ni ne tronque jamais ces lignes
        W.looseBox(p, #bl, 2 * TZ.half * CW, lay.lh)
        p:SetText(table.concat(bl, "\n"))
        -- centre du bloc : dans la zone, au-dessous du bloc précédent et de l'écart
        p:ClearAllPoints()
        p:SetPoint("CENTER", card.bg, "TOPLEFT", TZ.cx * CW, -(y + #bl * lay.lh / 2))
        p:Show()
        y = y + #bl * lay.lh + (split and lay.gap or 0)
        local n = p.GetNumLines and p:GetNumLines() or #bl
        local hh = p:GetStringHeight() or 0
        if not ((n == #bl or #bl == 0) and not (p.IsTruncated and p:IsTruncated()) and hh <= bottom - top + 0.5) then ok = false end
      end
      for k = #blocks + 1, #parts do
        parts[k]:SetText("")
        parts[k]:Hide()
      end
      card.bodyUsed = max(1, #blocks)
      if ok then
        fit = { size = s, lines = #lines, under = t.under or false, ok = true, mode = t.mode, y0 = lay.y0, max = t.max,
          lh = lay.lh, clause = lay.clause, cost = lay.cost, gap = split and lay.gap or 0, blocks = #blocks }
        break
      end
    end
  end
  if not fit then
    -- police pas encore mesurable, ou texte trop long même au dernier secours : retour à la ligne du
    -- client, au plancher (déborde peut-être : signalé)
    for k = 2, #parts do
      parts[k]:SetText("")
      parts[k]:Hide()
    end
    card.bodyUsed = 1
    local s = W.BODY_SIZES[#W.BODY_SIZES]
    W.setSize(fs, s)
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", card.bg, "TOPLEFT", TZ.cx * CW, -(top + bottom) / 2)
    fs:SetWidth(2 * TZ.half * CW)
    fs:SetHeight(0) -- hauteur libre : le texte déborde (signalé) plutôt que d'être tronqué
    fs:SetText((W.inlineIcons(text, s):gsub(NBSP, " ")))
    fit = { size = s, under = true, ok = false, font = fontErr, gap = 0, blocks = 1 }
  end
  card.bodyFit = fit
  return fit
end

-- Nom sur le ruban : premier palier où il tient sur une ligne dans la bande (marges comprises).
-- Boîte posée et large (W.looseBox) ; marge W.TEXT_SAFE ; cap : palier interdit et au-dessus (garde-fou).
local function fitName(fs, text, cap)
  local w = SC.name.len * W.CARD_W - 2 * W.NAME_MARGIN
  local sizes = {}
  for _, s in ipairs(W.NAME_SIZES) do sizes[#sizes + 1] = s end
  for _, s in ipairs(W.NAME_UNDER) do sizes[#sizes + 1] = s end
  fs:SetText(text)
  for idx, s in ipairs(sizes) do
    if not cap or s < cap then
      W.setSize(fs, s)
      W.looseBox(fs, 1, SC.name.len * W.CARD_W)
      local sw = (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0
      if sw > 0 and sw * W.TEXT_SAFE <= w and not (fs.IsTruncated and fs:IsTruncated()) then
        return { size = s, under = idx > #W.NAME_SIZES, ok = true }
      end
    end
  end
  W.setSize(fs, sizes[#sizes])
  W.looseBox(fs, 1, SC.name.len * W.CARD_W)
  return { size = sizes[#sizes], under = true, ok = false }
end

-- Pose une pièce (fractions de la largeur du corps) par rapport au corps de la carte (org = b.bg).
local function place(tex, org, rect)
  local CW = W.CARD_W
  tex:ClearAllPoints()
  tex:SetPoint("TOPLEFT", org, "TOPLEFT", rect[1] * CW, -rect[2] * CW)
  tex:SetSize(rect[3] * CW, rect[4] * CW)
end

-- Cartes créées (pour W.refreshCards : nouvelle mise en page quand la police arrive).
local cards = setmetatable({}, { __mode = "k" })
function W.refreshCards()
  W.clearTextCache()
  for card in pairs(cards) do
    if card.cardId then card:SetCard(card.cardId, card.cardUp, card.opts) end
  end
end

-- Plaque du bas (mots-clés) : Media/card_plate.tga en trois tranches (bords gauche et droit à
-- l'échelle de la hauteur, milieu étiré : la plaque s'élargit sans déformer ses coins), posée DEVANT
-- le corps (derrière, l'ombre portée du corps la masquait presque entière), à la place que lui donne
-- le PSD (son liseré du haut mord d'une unité sur le bas opaque du corps). Mesures sur la texture
-- (zone utile 256 × 89 px) : intérieur sombre x 20 à 234, y 20 à 70 ; coins arrondis du bas dans
-- les 48 px de chaque bord. Zone du texte = intérieur moins PLATE.margin de chaque côté.
local PLATE = { texW = 256, texH = 89, capPx = 48, inL = 20, inR = 234, inT = 20, inB = 70, margin = 3 }
W.CARD_PLATE = PLATE
-- Paliers du texte de la plaque : 8 = plancher lisible ; au plancher, la plaque s'élargit (jusqu'à la
-- largeur du corps) ; au-delà, secours 7,5 / 7, puis mots-clés abrégés (W.PLATE_SHORT).
W.PLATE_SIZES = { 9, 8.5, 8 }
W.PLATE_UNDER = { 7.5, 7 }
W.PLATE_SHORT = { Cooldown = "CD", Exhaust = "Exh.", Retain = "Ret." }

-- Géométrie de la plaque (unités de la carte, origine au coin haut gauche du corps) pour une largeur
-- totale w : position, bords, intérieur, zone du texte.
function W.cardPlateBox(w)
  local CW = W.CARD_W
  local r = SC.pieces.card_plate
  local h = r[4] * CW
  local u = h / PLATE.texH                       -- unités par pixel de texture (bords à l'échelle)
  w = w or r[3] * CW
  local x0, y0 = (CW - w) / 2, r[2] * CW
  local inL, inR = x0 + PLATE.inL * u, x0 + w - (PLATE.texW - PLATE.inR) * u
  local inT, inB = y0 + PLATE.inT * u, y0 + PLATE.inB * u
  return { x = x0, y = y0, w = w, h = h, cap = PLATE.capPx * u, inL = inL, inR = inR, inT = inT, inB = inB,
    textW = inR - inL - 2 * PLATE.margin, cx = (inL + inR) / 2, cy = (inT + inB) / 2 }
end

-- Trois tranches de la plaque du bas (groupe : couleur, désaturation, visibilité d'un bloc).
local function cardPlate(face)
  local e = TEX.card_plate
  local o = setmetatable({ parts = {} }, Group)
  local first = W.noSnap(face:CreateTexture(nil, "BACKGROUND", nil, -5))
  if W.canSlice(first) then
    -- une seule texture découpée par le client (voir W.threeSlice), posée sur une région d'ancrage sans
    -- texture (rien de dessiné) qui porte le rectangle de la plaque
    first:SetTexture(ROOT .. e.file, nil, nil, "TRILINEAR")
    first:SetTexCoord(0, e.tc[2], 0, e.tc[4])
    W.sliceMargins(first, PLATE.capPx, 0, PLATE.capPx, 0)
    o.parts[1] = first
    o.sliced = true
    o.anchor = face:CreateTexture(nil, "BACKGROUND", nil, -5)
  else
    local a = PLATE.capPx / PLATE.texW
    local cuts = { { 0, a }, { a, 1 - a }, { 1 - a, 1 } }
    for k = 1, 3 do
      local t = k == 1 and first or W.noSnap(face:CreateTexture(nil, "BACKGROUND", nil, -5))
      t:SetTexture(ROOT .. e.file, nil, nil, "TRILINEAR")
      t:SetTexCoord(cuts[k][1] * e.tc[2], cuts[k][2] * e.tc[2], 0, e.tc[4])
      o.parts[k] = t
    end
  end
  -- pose les tranches pour une largeur totale w (unités), par rapport au corps org
  o.Layout = function(self, org, w)
    local box = W.cardPlateBox(w)
    self.box = box
    if self.sliced then
      local an = self.anchor
      an:ClearAllPoints()
      an:SetPoint("TOPLEFT", org, "TOPLEFT", box.x, -box.y)
      an:SetSize(box.w, box.h)
      W.sliceFit(self.parts[1], an, box.h / PLATE.texH)
      return
    end
    local l, m, r = self.parts[1], self.parts[2], self.parts[3]
    for _, t in ipairs(self.parts) do t:ClearAllPoints() end
    l:SetPoint("TOPLEFT", org, "TOPLEFT", box.x, -box.y)
    l:SetSize(box.cap, box.h)
    m:SetPoint("TOPLEFT", org, "TOPLEFT", box.x + box.cap, -box.y)
    m:SetSize(box.w - 2 * box.cap, box.h)
    r:SetPoint("TOPLEFT", org, "TOPLEFT", box.x + box.w - box.cap, -box.y)
    r:SetSize(box.cap, box.h)
  end
  return o
end

-- Pose les mots-clés sur la plaque : premier palier qui tient dans la zone utile à la largeur de
-- repos ; sinon plaque élargie au plancher ; sinon secours plus petits à la largeur du corps ; sinon
-- mots-clés abrégés. Mesure par le client (GetUnboundedStringWidth), vérification (IsTruncated).
local function fitPlate(b, pills)
  local fs = b.plateText
  local CW = W.CARD_W
  local base = SC.pieces.card_plate[3] * CW
  local baseText = W.cardPlateBox(base).textW
  local extra = base - baseText                  -- largeur de plaque hors zone de texte
  local maxW = CW                                -- plaque au plus large : largeur du corps
  local function width(t, s)
    W.setSize(fs, s)
    fs:SetWidth(0)
    fs:SetText(t)
    return (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0
  end
  local text = table.concat(pills, " · ")
  local fit
  for _, s in ipairs(W.PLATE_SIZES) do
    local sw = width(text, s) * W.TEXT_SAFE
    if sw > 0 and sw <= baseText then fit = { size = s, w = base, text = text } break end
  end
  if not fit then
    local s = W.PLATE_SIZES[#W.PLATE_SIZES]
    local sw = width(text, s) * W.TEXT_SAFE
    if sw + extra <= maxW then fit = { size = s, w = max(base, sw + extra), text = text, wide = true } end
  end
  if not fit then
    local short = {}
    for i, pl in ipairs(pills) do
      local head, tail = pl:match("^(%S+)(.*)$")
      short[i] = (W.PLATE_SHORT[head] or head) .. tail
    end
    for _, t in ipairs({ text, table.concat(short, " · ") }) do
      for _, s in ipairs(W.PLATE_UNDER) do
        local sw = width(t, s) * W.TEXT_SAFE
        if sw + extra <= maxW then
          fit = { size = s, w = max(base, sw + extra), text = t, wide = true, under = true, short = t ~= text }
          break
        end
      end
      if fit then break end
    end
  end
  if not fit then
    -- même abrégés, trop de mots-clés : les premiers qui tiennent, suivis de « … » (signalé)
    local s = W.PLATE_UNDER[#W.PLATE_UNDER]
    local keep = {}
    for i, pl in ipairs(pills) do
      local head, tail = pl:match("^(%S+)(.*)$")
      keep[i] = (W.PLATE_SHORT[head] or head) .. tail
    end
    local t
    repeat
      keep[#keep] = nil
      t = table.concat(keep, " · ") .. (#keep > 0 and " …" or "…")
    until #keep == 0 or width(t, s) * W.TEXT_SAFE + extra <= maxW
    fit = { size = s, w = maxW, text = t, wide = true, under = true, short = true, cut = true }
  end
  b.plate:Layout(b.bg, fit.w)
  local box = b.plate.box
  W.setSize(fs, fit.size)
  fs:SetText(fit.text)
  fs:ClearAllPoints()
  fs:SetPoint("CENTER", b.bg, "TOPLEFT", box.cx, -box.cy)
  W.looseBox(fs, 1, box.textW) -- boîte posée et large : jamais tronqué par le client
  if fit.ok == nil then fit.ok = not (fs.IsTruncated and fs:IsTruncated()) end
  b.plateFit = fit
  return fit
end

-- Plaque posée sous la carte (raison d'un refus, prix) : créée au premier besoin.
local newCardPlaque
local function cardPlaque(b, key, w, h)
  local p = b[key]
  if p then return p end
  return newCardPlaque(b, key, w, h)
end

-- p est un cadre d'ancrage seulement (taille, position) : plaque, icône et texte sont des régions du
-- visuel de la carte, ancrées à p (un cadre enfant du visuel pourrait ne pas suivre son animation
-- Scale) ; p:Show() / p:Hide() montrent ou cachent ces régions, p:SetIcon(entrée | nil) pose l'icône.
newCardPlaque = function(b, key, w, h)
  local face = b.face
  local p = CreateFrame("Frame", nil, face)
  p:SetSize(w, h)
  -- devant les pièces de la carte (ARTWORK 0 à 3), sous les textes (OVERLAY)
  p.plaque = W.plaque(p, { r = h / 2, pill = true, gloss = false, parent = face, layer = "ARTWORK", sub = 4 })
  p.icon = W.noSnap(face:CreateTexture(nil, "OVERLAY", nil, -1))
  p.icon:SetSize(h - 6, h - 6)
  p.icon:SetPoint("LEFT", p, "LEFT", 5, 0)
  p.icon:Hide()
  p.text = W.label(face, "heavy", 11, C.text, "OVERLAY")
  p.text:SetPoint("CENTER", p, "CENTER", 0, 1)
  local frameShow, frameHide = p.Show, p.Hide
  p.Show = function(self)
    frameShow(self)
    self.plaque:Show()
    self.text:Show()
    if self.iconOn then self.icon:Show() else self.icon:Hide() end
  end
  p.Hide = function(self)
    frameHide(self)
    self.plaque:Hide()
    self.text:Hide()
    self.icon:Hide()
  end
  p.SetIcon = function(self, entry, k)
    self.iconOn = entry ~= nil
    if entry then W.setIcon(self.icon, entry, k) end
    if self.iconOn and self:IsShown() then self.icon:Show() else self.icon:Hide() end
  end
  p:Hide()
  b[key] = p
  return p
end

-- La carte est un bouton immobile (zone de survol et de clic) ; tout son visuel est dans b.face,
-- que le survol anime (W.hoverable). Réglage par écran : b.hoverLift (W.setLift, unités de la
-- carte, vers le haut) ; b.baseLevel / b.upLevel : niveau au repos et au survol (passage devant).
-- Plaque rouge de raison (carte injouable) : à cheval sur le bas du panneau, sous la zone du texte.
local REASON_Y, REASON_H = 1.225, 20
-- Texte de la raison : paliers 11 à 8 (plancher) dans la largeur de repos (0,84 du corps, 6 unités
-- de marge de chaque côté) ; au plancher, la plaque s'élargit jusqu'à la largeur du corps ; au-delà,
-- deux lignes coupées au mot le plus près du milieu, la plaque grandit vers le haut (son bas reste
-- au-dessus de la plaque des mots-clés).
W.REASON_SIZES = { 11, 10, 9, 8 }
local REASON_PAD = 6

-- Pose la raison dans sa plaque p ; renvoie la hauteur de la plaque.
local function fitReason(p, text)
  local CW = W.CARD_W
  local fs = p.text
  local baseW = 0.84 * CW
  local function width(t, s)
    W.setSize(fs, s)
    fs:SetWordWrap(false)
    fs:SetWidth(0)
    fs:SetText(t)
    return (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0
  end
  local w, t, size, lines = baseW, text, nil, 1
  for _, s in ipairs(W.REASON_SIZES) do
    if width(text, s) * W.TEXT_SAFE <= baseW - 2 * REASON_PAD then size = s break end
  end
  if not size then
    size = W.REASON_SIZES[#W.REASON_SIZES]
    local sw = width(text, size) * W.TEXT_SAFE
    if sw + 2 * REASON_PAD <= CW then
      w = sw + 2 * REASON_PAD
    else
      local words = {}
      for word in text:gmatch("%S+") do words[#words + 1] = word end
      local best, bestW
      for k = 1, #words - 1 do
        local a = table.concat(words, " ", 1, k)
        local b = table.concat(words, " ", k + 1)
        local m = max(width(a, size), width(b, size)) * W.TEXT_SAFE
        if not bestW or m < bestW then best, bestW = { a, b }, m end
      end
      if best then
        t, lines = best[1] .. "\n" .. best[2], 2
        w = min(CW, max(baseW, bestW + 2 * REASON_PAD))
      else
        w = CW
      end
    end
  end
  W.setSize(fs, size)
  fs:SetWordWrap(lines > 1)
  W.looseBox(fs, lines, w - 2 * REASON_PAD) -- boîte posée et large : jamais tronqué par le client
  fs:SetText(t)
  local h = REASON_H
  if lines > 1 then h = max(REASON_H, (fs:GetStringHeight() or 2 * size * 1.5) + 6) end
  p:SetSize(w, h)
  p.fit = { size = size, lines = lines, w = w, h = h }
  return h
end
-- Garde-fou en jeu : après la pose d'une carte et après chaque survol (une image plus tard : le client a
-- refait sa mise en page à l'échelle d'arrivée), un texte que le client tronque malgré tout (IsTruncated)
-- fait descendre son palier (texte, nom ; card.textCap, propre à la carte) et reposer la carte ; tout
-- texte tronqué est relevé (W.truncatedLog, /slay text) pour que le joueur puisse le signaler.
local truncLog = {}
local TRUNC_LOG_MAX = 40
local function plainShort(t)
  return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", W.HOURGLASS_CHAR)
    :gsub("\n", " / "))
end
local function isTruncated(fs)
  return fs ~= nil and fs:IsShown() and fs.IsTruncated ~= nil and (fs:GetText() or "") ~= "" and fs:IsTruncated()
end
local function describeText(fs)
  local e = fs.GetEffectiveScale and fs:GetEffectiveScale() or 1
  return ("\"%s\" (size %s, scale %.3f)"):format(plainShort(fs:GetText()), tostring(fs._size), e)
end
local function logTruncated(line)
  truncLog[#truncLog + 1] = line
  if #truncLog > TRUNC_LOG_MAX then table.remove(truncLog, 1) end
end
function W.truncatedLog() return truncLog end

function W.checkCardTexts(card)
  if not card.cardId or not card:IsShown() then return end
  local who = plainShort(card.name:GetText())
  local refit = false
  local parts = { { "name", card.name, "name", card.nameFit }, { "text", card.body, "body", card.bodyFit },
    { "keywords", card.plateText }, { "cost", card.cost } }
  for k = 2, card.bodyUsed or 1 do parts[#parts + 1] = { "text", card.bodyParts[k], "body", card.bodyFit } end
  if card.reasonPlate and card.reasonPlate:IsShown() then parts[#parts + 1] = { "reason", card.reasonPlate.text } end
  if card.priceTag and card.priceTag:IsShown() then parts[#parts + 1] = { "price", card.priceTag.text } end
  for _, p in ipairs(parts) do
    local fs, key, fit = p[2], p[3], p[4]
    if isTruncated(fs) then
      local what = describeText(fs)
      if key and fit and fit.ok and fit.size then
        card.textCap = card.textCap or {}
        card.textCap[key] = fit.size
        refit = true
        what = what .. " -> smaller size"
      end
      logTruncated(who .. " (" .. p[1] .. "): " .. what)
    end
  end
  if refit then card:SetCard(card.cardId, card.cardUp, card.opts) end
end

-- Vérification une image plus tard (une seule en attente par carte).
function W.checkCardTextsSoon(card)
  if card._textCheck then return end
  card._textCheck = true
  W.delay(0, function()
    card._textCheck = nil
    W.checkCardTexts(card)
  end)
end

-- Textes de l'interface (W.label, W.text) visibles et tronqués en ce moment.
function W.truncatedNow()
  local out = {}
  for fs in pairs(labels) do
    if fs:IsVisible() and isTruncated(fs) then out[#out + 1] = describeText(fs) end
  end
  table.sort(out)
  return out
end

-- Marge du visuel autour du corps (fraction de la largeur) : contient le halo (0,215), la languette
-- de coût, le ruban, la plaque du bas et l'étiquette de prix (jusqu'à 0,29 sous le corps).
local CARD_MARGIN = 0.3
W.CARD_MARGIN = CARD_MARGIN

function W.card(parent)
  local CW, CH = W.CARD_W, W.CARD_H
  local P = SC.pieces
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(CW, CH)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  -- visuel agrandi de CARD_MARGIN de chaque côté : il contient halo, ruban, languette, plaques
  local face = W.face(b, CARD_MARGIN * CW)
  -- corps : centré sur le visuel, à la taille de la carte ; toutes les pièces et tous les textes
  -- sont posés par rapport à lui (régions du même visuel : elles grossissent d'un seul bloc)
  b.bg = W.skin(face, "card_body_ivory", "BACKGROUND", -6)
  b.bg:SetSize(CW, CH)
  b.bg:SetPoint("CENTER", face, "CENTER", 0, 0)
  local org = b.bg

  b.halo = W.skin(face, "card_glow", "BACKGROUND", -8)
  place(b.halo, org, P.card_glow)
  b.halo:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
  b.halo:SetAlpha(0)
  b.halo:Hide()
  -- liseré d'état (carte Cast qui partira tout de suite sous Instant ; carte proposée au choix de fin de
  -- tour) : même halo, plus serré (il reste visible sous le halo doré du survol), teinté, tenu sans
  -- animation ; créé ici (jamais pendant un survol)
  b.rim = W.skin(face, "card_glow", "BACKGROUND", -7)
  local k = W.CARD_RIM_K
  local g = P.card_glow
  place(b.rim, org, { g[1] * k, g[2] * k, 1 + (g[3] - 1) * k, (g[4] + 2 * g[2]) - 2 * g[2] * k })
  b.rim:Hide()
  -- aura des cartes épiques : même halo, violet des objets épiques, tenu (créée ici, cachée sinon)
  b.epicGlow = W.skin(face, "card_glow", "BACKGROUND", -8)
  place(b.epicGlow, org, P.card_glow)
  b.epicGlow:SetVertexColor(W.EPIC_COLOR[1], W.EPIC_COLOR[2], W.EPIC_COLOR[3], 1)
  b.epicGlow:SetAlpha(W.EPIC_GLOW_ALPHA)
  b.epicGlow:Hide()
  b.plate = cardPlate(face)
  b.plate:Layout(org)
  -- médaillon : anneau, icône masquée, verre
  b.ring = W.skin(face, "medal_ring", "BORDER", 0)
  place(b.ring, org, P.medal_ring)
  b.icon = W.noSnap(face:CreateTexture(nil, "BORDER", nil, 1))
  place(b.icon, org, P.medal_mask)
  b.iconMask = W.roundMask(face, b.icon, "medal_mask")
  b.glass = W.skin(face, "medal_glass", "BORDER", 2)
  place(b.glass, org, P.medal_glass)
  b.medal = { icon = b.icon } -- compatibilité (harnais : b.medal.icon)
  -- devant : panneau, languette de coût, ruban, gemme
  b.panel = W.skin(face, "card_panel", "ARTWORK", 0)
  place(b.panel, org, P.card_panel)
  b.costTab = W.skin(face, "card_cost", "ARTWORK", 1)
  place(b.costTab, org, P.card_cost)
  b.ribbon = W.skin(face, "card_ribbon", "ARTWORK", 2)
  place(b.ribbon, org, P.card_ribbon)
  b.gem = W.noSnap(face:CreateTexture(nil, "ARTWORK", nil, 3))
  b.gem:Hide()
  -- marque d'une zone (opts.markIcon : carte que vise un Hex), coin haut droit du corps, cachée
  b.markIcon = W.noSnap(face:CreateTexture(nil, "ARTWORK", nil, 6)) -- sous les textes (OVERLAY)
  b.markIcon:SetSize(0.2 * CW, 0.2 * CW)
  b.markIcon:SetPoint("CENTER", b.bg, "TOPRIGHT", -0.06 * CW, -0.06 * CW)
  b.markIcon:Hide()

  -- textes
  b.name = W.label(face, "bold", 10, C.text, "OVERLAY")
  b.name:SetWordWrap(false)
  b.name:SetJustifyH("CENTER")
  b.name:SetPoint("CENTER", org, "TOPLEFT", SC.name.cx * CW, -SC.name.cy * CW)
  b.name:SetWidth(SC.name.len * CW)
  b.cost = W.label(face, "heavy", 14, C.costText, "OVERLAY")
  b.cost:SetPoint("CENTER", org, "TOPLEFT", SC.cost.cx * CW, -SC.cost.cy * CW)
  -- carte épique : pas de coût (règle en jeu dès le début du combat) ; la languette violette porte « Epic »
  b.epicMark = W.label(face, "bold", 10, W.EPIC_MARK_COLOR, "OVERLAY")
  b.epicMark:SetPoint("CENTER", org, "TOPLEFT", SC.cost.cx * CW, -SC.cost.cy * CW)
  b.epicMark:SetText("Epic")
  b.epicMark:Hide()
  -- centré dans la zone utile du panneau, lignes posées par fitBody dans une boîte posée (W.looseBox) ;
  -- hauteur libre seulement au secours (un texte trop long déborde au lieu d'être tronqué en « … »).
  -- Blocs des clauses (écart entre clauses) : b.body puis W.BODY_PARTS - 1 autres, créés ici (jamais
  -- pendant un survol), cachés tant qu'inutiles.
  b.bodyParts = {}
  for k = 1, W.BODY_PARTS do
    local p = W.label(face, "bold", W.BODY_SIZES[1], C.textSoft, "OVERLAY")
    p:SetJustifyH("CENTER")
    p:SetJustifyV("MIDDLE")
    p:SetWordWrap(true)
    if k > 1 then p:Hide() end
    b.bodyParts[k] = p
  end
  b.body = b.bodyParts[1]
  b.plateText = W.label(face, "bold", 8.5, C.text, "OVERLAY")
  b.plateText:SetPoint("CENTER", org, "TOPLEFT", SC.plateText.cx * CW, -SC.plateText.cy * CW)
  b.plateText:SetWordWrap(false)
  b.plateText:SetJustifyH("CENTER")
  b.kind = b.plateText -- compatibilité

  -- opts : cost, playable, reason, manaShort, price, sold, tooPoor, preview, showUp
  -- up : palier de la carte (false, true = 1, 1..3 ; Card.level) ; showUp : montre le palier suivant s'il est
  -- écrit (aperçu de l'amélioration au survol), chiffres qui changent en vert par rapport au palier actuel ;
  -- sinon, carte améliorée : chiffres qui diffèrent de la carte de base en vert, nom en vert suivi de +, +2, +3.
  b.SetCard = function(self, id, up, opts)
    opts = opts or {}
    up = Card.upValue(up) -- false ou palier 1..3 (0 et true acceptés)
    self.cardId, self.cardUp, self.opts = id, up, opts
    local lv = Card.level(up)
    local shown = (opts.showUp and Card.canUp(id, lv)) and lv + 1 or lv
    local showUp = shown > 0
    local d = Card.defById(id, shown)
    local base = (shown > lv and lv > 0) and Card.defById(id, lv) or (showUp and ns.Cards[id] or nil)
    local dim = opts.playable == false
    -- paliers interdits par le garde-fou (W.checkCardTexts) : propres à une carte
    local capFor = id .. Card.suffix(shown)
    if self.textCapFor ~= capFor then self.textCap, self.textCapFor = nil, capFor end
    -- corps à la couleur de la carte
    W.setSkin(self.bg, "card_body_" .. Art.cardBody(id, ns.Cards[id] or d))
    -- nom sur le ruban (paliers)
    self.nameFit = fitName(self.name, d.name, self.textCap and self.textCap.name)
    local nc = showUp and C.upGreen or C.text
    self.name:SetTextColor(nc[1], nc[2], nc[3])
    -- médaillon
    W.setIcon(self.icon, W.cardArt(id), "card:" .. id)
    -- texte : zone utile du panneau, relevée au-dessus de la plaque de raison si elle y mord
    local text = W.cardBody(d, base, opts.spendOff)
    local bottom = TZ.bottom * CW
    local reasonH
    if dim and opts.reason then
      reasonH = fitReason(cardPlaque(self, "reasonPlate", 0.84 * CW, REASON_H), opts.reason)
      bottom = min(bottom, REASON_Y * CW + REASON_H / 2 - reasonH - 1)
    end
    local fit = fitBody(self, text, bottom, W.cardMaxLines(d))
    if fit.font and not self._refit then
      -- police pas encore chargée : nouvelle mise en page un peu plus tard
      self._refit = true
      W.delay(0.5, function()
        self._refit = nil
        if self.cardId == id and self.cardUp == up and self.opts == opts then self:SetCard(id, up, opts) end
      end)
    end
    -- plaque du bas : mots-clés ; Instant (la prochaine carte Cast part tout de suite) : « Cast · Instant »
    local pills = W.cardPills(d)
    if opts.instant then
      local at = #pills + 1
      for i = 1, #pills do if pills[i] == "Cast" then at = i + 1 break end end
      table.insert(pills, at, W.colorize("Instant", W.INSTANT_COLOR))
    end
    -- liseré tenu : Instant (bleu) ou choix de la carte gardée en fin de tour (or)
    -- liseré d'une zone (opts.markRim : carte que vise un Hex), après les deux autres
    local rim = opts.keepPick and W.KEEP_RIM_COLOR or (opts.instant and not dim and W.INSTANT_RIM_COLOR)
      or opts.markRim or nil
    if rim then
      self.rim:SetVertexColor(rim[1], rim[2], rim[3], 1)
      self.rim:SetAlpha(rim[4] or 1)
      self.rim:Show()
    else
      self.rim:Hide()
    end
    self.rimKind = rim and (opts.keepPick and "keep" or ((opts.instant and not dim) and "instant") or "mark") or nil
    if opts.markIcon then
      W.setIcon(self.markIcon, opts.markIcon, "mark:" .. tostring(opts.markKey or id))
      self.markIcon:Show()
    else
      self.markIcon:Hide()
    end
    -- plaque au-dessus de la carte (opts.zoneTag : nom de la carte d'origine d'une carte transformée)
    if opts.zoneTag then
      local zp = cardPlaque(self, "zoneTagPlate", 0.9 * CW, 18)
      zp:ClearAllPoints()
      zp:SetPoint("CENTER", self.bg, "TOPLEFT", CW / 2, 4)
      zp:SetIcon(nil)
      zp.text:SetText(opts.zoneTag)
      zp.text:SetTextColor(0.85, 0.75, 1)
      zp.plaque:SetRim(Art.rim.violet)
      zp:Show()
    elseif self.zoneTagPlate then
      self.zoneTagPlate:Hide()
    end
    if #pills > 0 then
      fitPlate(self, pills)
      self.plate:Show()
      self.plateText:Show()
    else
      self.plate:Hide()
      self.plateText:Hide()
    end
    -- carte épique : ruban et languette de coût violets (Media/card_*_epic.tga), aura violette tenue
    local epic = d.rarity == "epic"
    if self.isEpic ~= epic then
      self.isEpic = epic
      W.setSkin(self.ribbon, epic and "card_ribbon_epic" or "card_ribbon")
      W.setSkin(self.costTab, epic and "card_cost_epic" or "card_cost")
      if epic then self.epicGlow:Show() else self.epicGlow:Hide() end
    end
    -- gemme de rareté
    local gem = Art.gems[d.rarity or ""]
    if gem then
      W.setSkin(self.gem, "gem_" .. gem)
      place(self.gem, self.bg, SC.gems[gem])
      self.gem:Show()
    else
      self.gem:Hide()
    end
    -- coût ; épique : sans coût, languette violette marquée « Epic »
    local cost = opts.cost or d.cost
    self.cost:SetText(tostring(cost))
    if epic then
      self.cost:Hide()
      self.costTab:Show()
      self.epicMark:Show()
    elseif d.cost == nil or d.unplayable then
      self.cost:Hide() self.costTab:Hide() self.epicMark:Hide()
    else
      self.cost:Show() self.costTab:Show() self.epicMark:Hide()
    end
    -- injouable : grisée, raison dans une plaque rouge au bas de la carte
    local k = dim and 0.62 or 1
    for _, t in ipairs({ self.bg, self.ribbon, self.costTab, self.panel, self.ring, self.plate, self.gem, self.glass }) do
      t:SetDesaturated(dim)
      t:SetVertexColor(k, k, k, 1)
    end
    -- teinte du corps (carte neutre : Art.cardBodyTint), multipliée par l'assombrissement
    local tint = Art.cardBodyTint(id, ns.Cards[id] or d)
    if tint then self.bg:SetVertexColor(k * tint[1], k * tint[2], k * tint[3], 1) end
    self.icon:SetDesaturated(dim)
    self.icon:SetVertexColor(k, k, k, 1)
    local short = opts.manaShort and not dim
    if short then
      self.costTab:SetDesaturated(true)
      self.costTab:SetVertexColor(1, 0.42, 0.38, 1)
    end
    local dc = dim and C.textDim or C.textSoft
    for _, p in ipairs(self.bodyParts) do p:SetTextColor(dc[1], dc[2], dc[3]) end
    if dim and opts.reason then
      local p = self.reasonPlate
      p.plaque:SetFill({ 1, 0.47, 0.43 })
      p.plaque:SetRim(Art.rim.red)
      p:ClearAllPoints()
      -- bas de la plaque fixe (au-dessus de la plaque des mots-clés) : une raison sur deux lignes
      -- la fait grandir vers le haut
      p:SetPoint("CENTER", self.bg, "TOPLEFT", CW / 2, -(REASON_Y * CW + REASON_H / 2 - reasonH / 2))
      p:Show()
    elseif self.reasonPlate then
      self.reasonPlate:Hide()
    end
    -- prix (marchand)
    if opts.sold or opts.price then
      local p = cardPlaque(self, "priceTag", 58, 22)
      p:ClearAllPoints()
      p:SetPoint("CENTER", self.bg, "TOPLEFT", CW / 2, -(CH + 0.185 * CW))
      if opts.sold then
        p:SetIcon(nil)
        p.text:SetText("Sold")
        p.text:SetTextColor(0.6, 0.6, 0.6)
        p.text:ClearAllPoints()
        p.text:SetPoint("CENTER", p, "CENTER", 0, 1)
        p.plaque:SetRim(Art.rim.silver)
      else
        p:SetIcon(Art.ui.gold, "ui:gold")
        p.text:SetText(tostring(opts.price))
        local pc = opts.tooPoor and C.badText or C.goldText
        p.text:SetTextColor(pc[1], pc[2], pc[3])
        p.text:ClearAllPoints()
        p.text:SetPoint("CENTER", p, "CENTER", 7, 1)
        p.plaque:SetRim(opts.tooPoor and Art.rim.red or Art.rim.silver)
      end
      p:Show()
      self.tag = p
    elseif self.priceTag then
      self.priceTag:Hide()
    end
    self:SetAlpha(opts.sold and 0.45 or 1)
    W.checkCardTextsSoon(self)
  end

  -- Survol / sélection : halo doré en fondu (la position est gérée par l'écran).
  b.SetHot = function(self, on)
    if self.hot == on and self.cardId == self._hotId then return end
    self.hot, self._hotId = on, self.cardId
    if on then
      self.halo:Show()
      self.halo:SetAlpha(W.animValue(self, "hover"))
    else
      self.halo:Hide()
    end
  end
  b.SetSelected = function(self, on) self:SetHot(on or self.hover) end

  -- Survol : halo qui s'allume, passage au premier plan ; carte lisible : levée (W.setLift, réglée par
  -- l'écran) ; petite carte : aperçu à taille réelle à côté (W.cardPreview). Jamais d'échelle.
  W.hoverable(b, { paint = function(self, h)
    if self.hot then self.halo:SetAlpha(h) end -- fondu depuis 0 (pas d'éclat à la première image)
  end })
  b.onAnimSettled = function(self)
    if self.baseLevel and W.animValue(self, "hover") == 0 then W.setLevel(self, self.baseLevel) end
  end
  b.tooltipSpot = function(self) return W.cardPreviewShow(self) end
  b.tooltipLeave = function(self) W.cardPreviewHide(self) end
  b:HookScript("OnHide", function(self) W.cardPreviewHide(self) end)
  b.onEnterExtra = function(self)
    if self._hoverManual then return end
    self.hover = true
    W.cardFront(self, true)
    self:SetHot(true)
  end
  b.onLeaveExtra = function(self)
    if self._hoverManual then return end
    self.hover = false
    W.cardFront(self, false)
    self:SetHot(false)
  end

  W.tooltip(b, function(tt, self)
    if self.cardId then W.fillCardTooltip(tt, self.cardId, self.cardUp, self.opts) end
  end, "ANCHOR_RIGHT")
  cards[b] = true
  return b
end

---------------------------------------------------------------------------
-- Aperçu à taille réelle d'une petite carte (grilles, panneau du deck, progression, bilan)
---------------------------------------------------------------------------
-- Une petite carte (échelle de base sous PREVIEW_BELOW) ne grossit pas au survol : une vraie carte à
-- l'échelle 1 (la taille de la main) apparaît à côté d'elle, en fondu, du côté où il y a de la place,
-- entièrement dans la fenêtre, sur la couche du dessus (UI.overlay : au-dessus du contenu rogné, des
-- modèles 3D, du bandeau et de la barre de titre ; à PREVIEW_MARGIN des bords, sous les filets du cadre
-- sans les toucher). L'infobulle des mots-clés se place à côté de l'aperçu, du côté opposé à la carte.
-- Une seule instance pour tout l'addon, construite avec la fenêtre (W.buildCardPreview) et réutilisée :
-- rien n'est créé pendant un survol. Position : coordonnées de pose de la carte (W.placeCenter), dans un
-- conteneur qui couvre le contenu (écrans, panneau du deck) — mêmes unités que la couche du dessus.
-- Liseré d'état d'une carte (b.rim, W.card) : halo resserré (fraction CARD_RIM_K de la marge du halo
-- doré), couleur et alpha ; Instant en bleu arcane, carte proposée au choix de fin de tour en or pâle.
W.CARD_RIM_K = 0.85
-- Cartes épiques : violet des objets épiques de WoW (#a335ee), aura tenue derrière la carte.
W.EPIC_COLOR = { 0.64, 0.21, 0.93 }
W.EPIC_TEXT = { 0.78, 0.5, 1 } -- titres et libellés (plus clair, lisible sur la roche)
W.EPIC_GLOW_ALPHA = 0.75
W.EPIC_HINT = "One epic card per expedition: a new one replaces it."
W.EPIC_MARK_COLOR = { 0.95, 0.88, 1 } -- « Epic » sur la languette violette (à la place du coût)
W.INSTANT_COLOR = { 0.45, 0.85, 1 }
W.INSTANT_RIM_COLOR = { 0.35, 0.8, 1, 1 }
W.KEEP_RIM_COLOR = { 1, 0.9, 0.55, 0.9 }
W.INSTANT_HINT = "|cff73d9ffInstant|r: this Cast resolves at once."
W.KEEP_HINT = "Click: keep this card in hand for the next turn."
W.CARD_LIFT = 12         -- levée d'une carte lisible survolée, en unités de la scène (écran : W.CARD_LIFT / échelle)
W.PREVIEW_BELOW = 0.9
W.PREVIEW_GAP = 10       -- écart entre la petite carte et l'aperçu
W.PREVIEW_MARGIN = 8     -- marge aux bords du contenu
-- débords visibles d'une carte autour de son corps (fractions de la largeur) : languette de coût et
-- ruban en haut, ruban sur les côtés, plaque du bas (vérifiés sur les pièces par le harnais, UX)
W.PREVIEW_PAD = { side = 0.12, top = 0.14, bottom = 0.2 }
local preview

-- host : la couche du dessus (au rectangle du contenu, w × h unités).
function W.buildCardPreview(host, w, h)
  if preview then return preview end
  local p = W.card(host)
  p.areaW, p.areaH = w, h
  p:EnableMouse(false)
  p:SetFrameLevel(host:GetFrameLevel() + 20)
  p.isPreview = true
  p.tooltipSpot, p.tooltipLeave = nil, nil
  -- fondu par le canal « show » (alpha du visuel ; l'alpha du cadre reste à SetCard : carte vendue)
  p._animApply = function(self)
    W.faceApply(self)
    self.face:SetAlpha(W.animValue(self, "show"))
  end
  p.onAnimSettled = function(self)
    if W.animValue(self, "show") == 0 then self.of = nil self:Hide() end
  end
  p.face:SetAlpha(0)
  p:Hide()
  preview = p
  W.preview = p
  return p
end

-- Montre l'aperçu de `card` si c'est une petite carte posée ; renvoie la place de l'infobulle (à côté de
-- l'aperçu) ou nil (carte lisible : infobulle habituelle).
function W.cardPreviewShow(card)
  local p = preview
  if not p or card.isPreview or not card.cardId or not card._pc then return nil end
  local s = card:GetScale() or 1
  if s >= W.PREVIEW_BELOW then return nil end
  local host = p:GetParent()
  local CW, CH = W.CARD_W, W.CARD_H
  local pad, M = W.PREVIEW_PAD, W.PREVIEW_MARGIN
  local width, height = p.areaW or host:GetWidth() or 0, p.areaH or host:GetHeight() or 0
  local cx, cy = card._px, card._py
  local half = CW / 2 + pad.side * CW
  local off = CW * s / 2 + W.PREVIEW_GAP + half
  local x, right = cx + off, true
  if x + half > width - M then x, right = cx - off, false end
  if x - half < M then
    -- ni à droite ni à gauche en entier : du côté le plus large, rentré dans la fenêtre
    right = cx < width / 2
    x = right and min(cx + off, width - M - half) or max(cx - off, M + half)
  end
  local top, bottom = CH / 2 + pad.top * CW, CH / 2 + pad.bottom * CW
  local y = max(M + top, min(height - M - bottom, cy))
  p:SetCard(card.cardId, card.cardUp, card.opts)
  W.placeCenter(p, host, x, y, 1)
  p.of = card
  p:Show()
  W.animTo(p, "show", 1, W.HOVER_IN)
  if right then return { "TOPLEFT", p, "TOPRIGHT", 6 + pad.side * CW, 0 } end
  return { "TOPRIGHT", p, "TOPLEFT", -6 - pad.side * CW, 0 }
end

-- Cache l'aperçu (en fondu) s'il montre `card`.
function W.cardPreviewHide(card)
  local p = preview
  if not p or p.of ~= card then return end
  if W.animValue(p, "show") == 0 then p.of = nil p:Hide() return end
  W.animTo(p, "show", 0, W.HOVER_OUT)
end

-- Dos de carte (piles, tas du deck) : texture du pack, hauteur h.
function W.cardBack(parent, h, layer, sub)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
  W.setSkin(t, "card_back")
  t:SetSize(W.skinWidth("card_back", h), h)
  return t
end

-- Niveau d'un cadre survolable et de son visuel : le client relève d'ordinaire les enfants avec
-- leur parent, on le fait aussi explicitement pour le visuel (il doit passer devant les voisines).
local function relevel(frame, level)
  frame:SetFrameLevel(level)
  if frame.GetChildren then
    local kids = { frame:GetChildren() }
    for i = 1, #kids do relevel(kids[i], level + 1) end
  end
end

function W.setLevel(f, level)
  f:SetFrameLevel(level)
  if f.face then relevel(f.face, level + 1) end
end

-- Passe un cadre (et son sous-arbre) sous un autre parent, au niveau `level` (enfants au-dessus, dans
-- l'ordre où ils étaient) ; renvoie de quoi le remettre en place (parent et niveaux d'origine). Sert au
-- butin qui vole vers le bandeau : il quitte le contenu rogné pour la couche du dessus (UI.overlay).
function W.lift(f, parent, level)
  local saved = {}
  local function save(fr)
    saved[#saved + 1] = { fr, fr:GetFrameLevel() }
    if fr.GetChildren then
      local kids = { fr:GetChildren() }
      for i = 1, #kids do save(kids[i]) end
    end
  end
  save(f)
  local home = f:GetParent()
  local base = saved[1][2]
  f:SetParent(parent)
  for i = 1, #saved do saved[i][1]:SetFrameLevel(level + (saved[i][2] - base)) end
  return function()
    f:SetParent(home)
    for i = 1, #saved do saved[i][1]:SetFrameLevel(saved[i][2]) end
  end
end

-- Niveau d'une carte : devant au survol ; en sortie, juste au-dessus des voisines tant qu'elle
-- rétrécit, puis au repos (onAnimSettled).
function W.cardFront(card, up)
  if not card.baseLevel then return end
  if up then W.setLevel(card, card.upLevel or (card.baseLevel + 60))
  elseif W.animValue(card, "hover") > 0 then W.setLevel(card, card.baseLevel + 30)
  else W.setLevel(card, card.baseLevel) end
end

-- Cache une carte et remet son survol au repos (la souris ne la quittera pas : elle disparaît).
function W.hideCard(card)
  card.hover, card.lifted = false, false
  W.hoverReset(card)
  if card.baseLevel then W.setLevel(card, card.baseLevel) end
  card:Hide()
end

-- Pose une carte au repos : centre (x, y) et échelle de base, niveaux ; le survol garde sa valeur.
function W.placeCard(card, container, x, y, scale, baseLevel, upLevel)
  W.placeCenter(card, container, x, y, scale)
  card.baseLevel, card.upLevel = baseLevel, upLevel
  W.cardFront(card, card.hover or card.lifted)
end

-- Carte fantôme (vol de la main vers la cible, de la pioche vers la main…).
local ghosts = {}
function W.ghostCard(container)
  for i = 1, #ghosts do
    local g = ghosts[i]
    if not g.busy and g:GetParent() == container then g.busy = true g:Show() return g end
  end
  local g = W.card(container)
  g:EnableMouse(false)
  g.busy = true
  ghosts[#ghosts + 1] = g
  return g
end

function W.releaseGhost(g)
  g.busy = false
  g:Hide()
end

-- Place un cadre par son centre dans les coordonnées du conteneur (x vers la droite, y vers le bas).
function W.placeCenter(f, container, x, y, scale)
  scale = scale or 1
  f._pc, f._px, f._py = container, x, y -- (aperçu d'une petite carte : W.cardPreviewShow)
  if f:GetScale() ~= scale then f:SetScale(scale) end -- même échelle : rien à redessiner
  f:ClearAllPoints()
  f:SetPoint("CENTER", container, "TOPLEFT", x / scale, -y / scale)
end

-- Fait voler un cadre de (x1, y1) à (x2, y2) avec échelle et alpha, puis onDone. Échelle réelle fixée
-- à s1 pendant le vol, changement de taille par l'animation Scale du cadre (textes en mode Vertex : mise
-- en page figée) ; à l'arrivée, dans le même appel, animation coupée et échelle réelle s2 posée une fois
-- (texte redessiné net, à sa taille d'arrivée). Sans animation possible : échelle réelle à chaque image.
function W.fly(f, container, x1, y1, x2, y2, s1, s2, a1, a2, dur, onDone, arc)
  f:Show()
  local anim = s1 > 0 and s2 > 0 and f.CreateAnimationGroup ~= nil
  flyScaleStop(f)
  if anim then
    W.placeCenter(f, container, x1, y1, s1)
    flyScaleTo(f, s2 / s1, max(0.01, dur * W.pace()))
  end
  W.tween(dur, function(p)
    local x = x1 + (x2 - x1) * p
    local y = y1 + (y2 - y1) * p - (arc or 0) * 4 * p * (1 - p)
    W.placeCenter(f, container, x, y, anim and s1 or (s1 + (s2 - s1) * p))
    f:SetAlpha(a1 + (a2 - a1) * p)
  end, function()
    if anim then
      flyScaleStop(f)
      W.placeCenter(f, container, x2, y2, s2)
    end
    if onDone then onDone() end
  end, f, "fly", W.ease.inOut)
end

---------------------------------------------------------------------------
-- Textes flottants (chiffres de dégâts, soins, Absorption)
---------------------------------------------------------------------------

local floatPool = {}

-- x, y : centre dans le conteneur ; size : taille de police ; dur : secondes.
function W.float(container, x, y, text, color, size, dur, rise)
  local f
  for i = 1, #floatPool do
    if not floatPool[i].busy and floatPool[i]:GetParent() == container then f = floatPool[i] break end
  end
  if not f then
    f = CreateFrame("Frame", nil, container)
    f:SetSize(200, 40)
    f.fs = W.label(f, "heavy", 30, C.white, "OVERLAY")
    f.fs:SetPoint("CENTER")
    f.fs:SetShadowColor(0.29, 0.06, 0.03, 1)
    f.fs:SetShadowOffset(2, -2)
    floatPool[#floatPool + 1] = f
  end
  f.busy = true
  f:SetFrameLevel(container:GetFrameLevel() + 80)
  W.setSize(f.fs, size or 30)
  f.fs:SetText(text)
  color = color or C.white
  f.fs:SetTextColor(color[1], color[2], color[3])
  rise = rise or 34
  W.tween(dur or 1.1, function(p)
    local pop = p < 0.15 and (1.5 - p / 0.15 * 0.5) or 1
    W.placeCenter(f, container, x, y - rise * p, pop)
    f:SetAlpha(p < 0.6 and 1 or (1 - (p - 0.6) / 0.4))
  end, function()
    f:Hide()
    f.busy = false
  end, f, "float", W.ease.linear)
  f:Show()
  return f
end

---------------------------------------------------------------------------
-- Modèles 3D
---------------------------------------------------------------------------

function W.model(parent, w, h)
  local m = W.create("PlayerModel", nil, parent)
  m:SetSize(w, h)
  return m
end

-- Anime un modèle puis revient à l'attente (ou reste figé pour « dead »).
function W.anim(model, anim, hold)
  if not model or not model.SetAnimation or model.dead then return end
  model:SetAnimation(anim)
  model.animToken = (model.animToken or 0) + 1
  local token = model.animToken
  if hold then
    W.delay(hold * W.pace(), function()
      if model.animToken == token and not model.dead then model:SetAnimation(Art.anim.stand) end
    end)
  end
end

function W.modelAlpha(model, a)
  model:SetAlpha(a)
  if model.SetModelAlpha then model:SetModelAlpha(a) end
end

-- Détection d'un modèle absent. SetCreature / SetDisplayInfo ne lèvent aucune erreur pour un
-- identifiant inconnu : le cadre reste simplement vide, et le chargement est asynchrone (une créature
-- absente du cache du client est demandée au serveur). Un essai est jugé réussi si le gestionnaire
-- OnModelLoaded a sonné pour lui, ou si GetModelFileID rend un fichier (ni nil ni 0) MODEL_WAIT
-- secondes plus tard ; sinon l'essai suivant est tenté. Sans aucun modèle, le repli s'affiche, puis
-- une relance tardive (MODEL_LATE) retente la créature ; un OnModelLoaded tardif efface aussi le repli.
W.MODEL_WAIT = 0.8
W.MODEL_LATE = 3
W.models = {} -- clé -> { tries = { libellés }, state = "pending" | "ok" | "missing", via = libellé }

local function hasModel(model)
  if not model.GetModelFileID then return true end
  local ok, id = pcall(model.GetModelFileID, model)
  return ok and id ~= nil and id ~= 0
end
W.hasModel = hasModel

-- Essais d'une entrée d'art, dans l'ordre : créature, puis affichage(s) (nombre ou liste).
function W.modelTries(art)
  local out = {}
  if art and art.creature then out[#out + 1] = { "creature", art.creature } end
  local d = art and art.display
  if type(d) == "number" then
    out[#out + 1] = { "display", d }
  elseif type(d) == "table" then
    for i = 1, #d do out[#out + 1] = { "display", d[i] } end
  end
  return out
end

function W.tryLabel(t) return (t[1] == "creature" and "creature " or "display ") .. t[2] end

local function applyTry(model, t)
  if model.ClearModel then model:ClearModel() end
  if t[1] == "creature" then model:SetCreature(t[2]) else model:SetDisplayInfo(t[2]) end
end

-- OnModelLoaded : gestionnaire des cadres Model (pcall : sans effet si le client ne le connaît pas).
local function hookLoaded(model)
  if model.artHooked then return end
  model.artHooked = true
  pcall(model.SetScript, model, "OnModelLoaded", function(self)
    self.loadedToken = self.artToken
    if self.onArtLoaded then self.onArtLoaded() end
  end)
end

-- Affiche une créature : essais en chaîne (W.modelTries), puis repli.
-- art = { creature, display } ; key = clé des rapports (/slay art, /slay models) ;
-- onMissing() sans aucun modèle, onFound(libellé) quand un modèle (même tardif) est là.
function W.setCreatureArt(model, art, key, onMissing, onFound)
  key = tostring(key)
  model.dead = false
  model.artKey = key
  model.artChain = (model.artChain or 0) + 1
  model.onArtLoaded = nil
  local chain = model.artChain
  hookLoaded(model)
  local tries = W.modelTries(art)
  local labels = {}
  for i = 1, #tries do labels[i] = W.tryLabel(tries[i]) end
  local status = { tries = labels, state = "pending" }
  W.models[key] = status
  local current = 0
  local function found()
    if model.artChain ~= chain or status.state == "ok" then return end
    status.state, status.via = "ok", labels[current]
    model.onArtLoaded = nil
    W.missing["model:" .. key] = nil
    if onFound then onFound(status.via) end
  end
  local function missing()
    status.state = "missing"
    W.missing["model:" .. key] = true
    if onMissing then onMissing() end
  end
  if #tries == 0 then
    if model.ClearModel then model:ClearModel() end
    missing()
    return
  end
  local function attempt(i, onFail)
    current = i
    model.artToken = (model.artToken or 0) + 1
    local token = model.artToken
    applyTry(model, tries[i])
    W.delay(W.MODEL_WAIT, function()
      if model.artChain ~= chain or status.state == "ok" then return end
      if model.loadedToken == token or hasModel(model) then found() else onFail() end
    end)
  end
  local function run(i)
    attempt(i, function()
      if i < #tries then run(i + 1) return end
      missing()
      model.onArtLoaded = function() if model.artChain == chain then found() end end
      W.delay(W.MODEL_LATE, function()
        if model.artChain ~= chain or status.state == "ok" then return end
        attempt(1, function() end)
      end)
    end)
  end
  run(1)
end

-- Repli d'un modèle absent : médaillon argenté (W.medallion) à l'icône de l'ennemi, sinon disque
-- sombre (silhouette sobre). Jamais de point d'interrogation.
function W.setFallbackArt(medal, entry)
  local icon = medal.icon
  icon:SetVertexColor(1, 1, 1, 1)
  if entry and W.setIcon(icon, entry) then return true end
  icon:SetTexture(nil)
  icon:SetColorTexture(C.slateDark[1], C.slateDark[2], C.slateDark[3], 1)
  return false
end

-- Ennemi : modèle, sinon médaillon de repli (fallback = W.medallion, caché tant qu'un modèle est là).
function W.setCreature(model, enemyId, fallback)
  local art = Art.enemies[enemyId]
  if fallback then
    fallback:Hide()
    W.setFallbackArt(fallback, art and art.icon)
  end
  model.enemyId = enemyId
  W.setCreatureArt(model, art, enemyId, function()
    if fallback then fallback:Show() end
  end, function()
    if fallback then fallback:Hide() end
  end)
end
