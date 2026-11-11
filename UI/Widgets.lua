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
  if obj._hoverable and dur > 0 then dur = dur * W.zoomSlow() end
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
-- Survols : zone de survol fixe, visuel animé
---------------------------------------------------------------------------
-- Piège évité : animer l'échelle ou la position du cadre qui reçoit la souris ferait sortir le
-- curseur de la zone (entrée/sortie en boucle). Le cadre interactif reste donc immobile (zone de
-- survol) ; tout ce qui se voit vit dans son enfant `face`, seul animé (échelle, décalage).

-- Agrandissement des visuels (survols, vols de cartes). Trois exigences : un mouvement fluide, aucun
-- tressautement des textes, et un texte net une fois la carte agrandie (c'est celle qu'on lit).
--   * Changer l'échelle réelle (SetScale) fait re-rasteriser au client toutes les polices du visuel
--     (SetSmoothScaling : hauteur non arrondie, donc une nouvelle taille à chaque pas) : à chaque
--     image, c'est lent (15 images/s en jeu) ; en une fois, les glyphes se recalent (« saut »).
--   * Une animation Scale d'un AnimationGroup avec des textes en mode Vertex
--     (FontString:SetScaleAnimationMode, comme Blizzard_EncounterWarnings) est fluide (GPU) et fige
--     la mise en page, mais étire les glyphes rasterisés à l'échelle réelle.
-- Mode « net » (défaut, préféré pour la fluidité) : l'étirement ne sert que pendant le mouvement ; à
-- l'arrivée, dans le même pas de l'OnUpdate partagé, l'échelle d'arrivée devient l'échelle réelle
-- (SetScale) et l'animation est coupée (Stop) : texte net. L'animation est relative à l'échelle réelle du
-- moment (facteur 1 au départ) et tient son état d'arrivée jusqu'à la bascule. Pour qu'à la bascule rien
-- ne saute : aucun cadre enfant dessiné sous un visuel (une animation Scale pourrait ne porter que sur
-- les régions du cadre animé : un cadre enfant ne grossirait qu'à la bascule) — plaques de carte et
-- médaillons de jetons sont des régions du visuel —, et textures sans accrochage au pixel (W.noSnap).
-- Reste la re-rasterisation des polices à la bascule, inhérente à ce mode.
-- Mode « fluide » (comparaison) : l'échelle RÉELLE du visuel vaut en permanence l'échelle survolée
-- (hoverScale) : les polices sont rasterisées une fois, à la taille qu'on lit. Au repos, une animation
-- Scale tenue (long délai de fin) réduit le visuel d'un facteur 1 / hoverScale ; le survol anime ce
-- facteur vers 1, la sortie le ramène à 1 / hoverScale. Jamais de SetScale ni de Stop pendant un
-- survol : aucune re-rasterisation, aucune bascule. Le repos est identique en taille et en position aux
-- autres modes (harnais, U26). Un cadre caché arrête ses animations : l'OnShow du visuel repose l'état.
-- L'animation n'est armée qu'après la construction du widget (image suivante) : une région créée sous
-- un visuel dont l'animation joue est mal dessinée par le client (U23) ; avant, le visuel est au repos
-- sans animation (échelle réelle 1), identique à l'œil. Les créations tardives passent par W.faceBuild.
-- Mode « lisse » (comparaison) : SetScale à chaque image.
-- Dans tous les modes, la mise en page ne dépend pas de l'échelle : retours à la ligne explicites
-- (W.card), largeurs et ancrages en unités du visuel, textes en SetSmoothScaling (taille rendue
-- exactement proportionnelle). /slay zoom slow : survols au ralenti (diagnostic en jeu).
W.ZOOM_MODES = { "net", "fluide", "lisse" }
W.ZOOM_DEFAULT = "net"
local ZOOM_HOLD = 86400 -- délai de fin qui tient l'échelle d'arrivée (secondes)

function W.zoomMode()
  local o = ns.Persist and ns.Persist.options and ns.Persist.options()
  local z = o and o.zoom
  if z == "fluide" or z == "net" or z == "lisse" then return z end
  return W.ZOOM_DEFAULT
end

-- Ralenti des survols (/slay zoom slow, diagnostic en jeu : voir ce qui ne suit pas l'animation et ce
-- qui bouge à l'arrivée).
W.ZOOM_SLOW = 8
function W.zoomSlow()
  local o = ns.Persist and ns.Persist.options and ns.Persist.options()
  return (o and o.zoomSlow) and W.ZOOM_SLOW or 1
end

-- Accrochage au pixel coupé (textures : SetSnapToPixelGrid, SetTexelSnappingBias, comme les neuf
-- tranches de Blizzard) : une pièce animée ne se recale pas d'un pixel d'une image à l'autre. Les
-- FontString n'ont pas ces méthodes (SimpleTextureBaseAPI) : test d'existence.
function W.noSnap(r)
  if r.SetSnapToPixelGrid then r:SetSnapToPixelGrid(false) end
  if r.SetTexelSnappingBias then r:SetTexelSnappingBias(0) end
  return r
end

-- Textes de l'interface (W.label, W.text), pour le rafraîchissement des polices.
local labels = setmetatable({}, { __mode = "k" })

local function zoomText(fs)
  labels[fs] = true
  if fs.SetScaleAnimationMode and Enum and Enum.FontStringScaleAnimationMode then
    fs:SetScaleAnimationMode(Enum.FontStringScaleAnimationMode.Vertex)
  end
  if fs.SetSmoothScaling then fs:SetSmoothScaling(true) end
  W.noSnap(fs)
end
W.zoomText = zoomText

-- Survolables créés (pour reposer leur état quand la technique de zoom change).
local faceOwners = setmetatable({}, { __mode = "k" })

-- Bascule la technique de zoom ; renvoie le nouveau mode (une valeur inconnue, dont l'ancien
-- « anim », retombe sur le défaut). Les visuels sont reposés dans le nouveau mode.
function W.setZoomMode(mode)
  if mode ~= "fluide" and mode ~= "net" and mode ~= "lisse" then mode = W.ZOOM_DEFAULT end
  ns.Persist.options().zoom = mode
  for f in pairs(faceOwners) do
    if f._animApply == W.faceApply and not f._fly then W.faceApply(f) end
  end
  return mode
end

local ease = {
  OUT = function(p) return 1 - (1 - p) * (1 - p) end,
  IN_OUT = function(p) if p < 0.5 then return 2 * p * p end return 1 - 2 * (1 - p) * (1 - p) end,
}

-- Facteur courant de l'animation Scale d'un visuel (1 si elle ne joue pas).
local function animFactor(face)
  local z = face._zoom
  if not z or not z.ag:IsPlaying() then return 1 end
  local dur = z.dur
  local t = GetTime() - z.t0
  if dur <= 0 or t >= dur then return z.to end
  local fallback = ease[z.smooth] or ease.OUT
  local p = z.anim.GetSmoothProgress and z.anim:GetSmoothProgress() or fallback(t / dur)
  if type(p) ~= "number" or p < 0 or p > 1 then p = fallback(t / dur) end
  return z.from + (z.to - z.from) * p
end

-- Échelle visuelle courante (échelle réelle × facteur de l'animation).
function W.visualScale(face)
  return face:GetScale() * animFactor(face)
end

-- Coupe l'animation d'échelle (le facteur retombe à 1).
local function stopZoom(face)
  local z = face._zoom
  if z then
    z.ag:Stop()
    z.from, z.to = 1, 1
  end
end

local function newZoom(face)
  local ag = face:CreateAnimationGroup()
  local anim = ag:CreateAnimation("Scale")
  anim:SetOrigin("CENTER", 0, 0)
  local z = { ag = ag, anim = anim, from = 1, to = 1, t0 = 0, dur = 0 }
  face._zoom = z
  return z
end

local function setSmooth(z, smooth)
  smooth = smooth or "OUT"
  if z.smooth ~= smooth then
    z.smooth = smooth
    z.anim:SetSmoothing(smooth)
  end
end

-- Lance l'animation de cur vers target en dur secondes, puis la tient (long délai de fin).
local function playZoom(z, cur, target, dur)
  dur = max(dur, 0.001)
  z.anim:SetScaleFrom(cur, cur)
  z.anim:SetScaleTo(target, target)
  z.anim:SetDuration(dur)
  z.anim:SetEndDelay(ZOOM_HOLD)
  z.from, z.to, z.t0, z.dur = cur, target, GetTime(), dur
  z.ag:Play()
end

-- Mode « net » : fait filer le facteur d'animation de face vers target (relatif à l'échelle réelle)
-- en dur secondes, depuis le facteur courant (1 si l'animation ne joue pas : la première image d'un
-- départ est identique avec ou sans animation) ; dur 0 : coupe. smooth = lissage ("OUT" par défaut,
-- "IN_OUT" pour les vols de cartes).
local function zoomTo(face, target, dur, smooth)
  local z = face._zoom
  if not z then
    if target == 1 then return end
    z = newZoom(face)
  end
  setSmooth(z, smooth)
  local playing = z.ag:IsPlaying()
  -- déjà en route vers cette cible
  if playing and z.to == target then return end
  local cur = playing and animFactor(face) or 1
  z.ag:Stop()
  if dur <= 0 or cur == target then
    z.from, z.to = 1, 1
    return
  end
  playZoom(z, cur, target, dur)
end

-- Mode « fluide » : le facteur d'animation de face file vers target en dur secondes puis y reste
-- (jamais coupé : le facteur tenu EST l'état du visuel). Départ : facteur courant si l'animation joue,
-- sinon cur0 (état à reposer : cadre remontré, premier armement) ; dur 0 : target tout de suite.
-- force : relance même si la cible ne change pas (échelle réelle changée).
local function holdTo(face, target, dur, smooth, cur0, force)
  local z = face._zoom
  if not z then
    if target == 1 and (cur0 or 1) == 1 then return end -- facteur 1 : rien à animer
    z = newZoom(face)
  end
  setSmooth(z, smooth)
  local playing = z.ag:IsPlaying()
  if playing and z.to == target and not force then return end
  local cur
  if force and cur0 then cur = cur0 elseif playing then cur = animFactor(face) else cur = cur0 or target end
  if dur <= 0 then cur = target end
  z.ag:Stop()
  if not playing and cur == 1 and target == 1 then z.from, z.to = 1, 1 return end
  playZoom(z, cur, target, cur == target and 0 or dur)
end

-- Crée des régions sous le visuel de f (création tardive : plaque de raison, étiquette de prix…)
-- sans animation d'échelle en cours (le client dessine mal une région née pendant l'animation) :
-- l'animation tenue est coupée le temps de fn, puis relancée au même facteur, dans le même appel.
function W.faceBuild(f, fn)
  local face = f.face
  local z = face and face._zoom
  if not (z and z.ag:IsPlaying()) then return fn() end
  local cur, to = animFactor(face), z.to
  local left = max(0, z.dur - (GetTime() - z.t0))
  z.ag:Stop()
  local a, b, c = fn()
  playZoom(z, cur, to, cur == to and 0 or left)
  return a, b, c
end

-- Crée le visuel `f.face`, centré sur f, de même taille (suivie par OnSizeChanged) plus margin de
-- chaque côté : un visuel dont des pièces débordent (carte : ruban, languette, plaque, halo) est
-- agrandi pour les contenir toutes, et l'animation Scale porte sur un cadre qui les englobe.
function W.face(f, margin)
  local face = CreateFrame("Frame", nil, f)
  margin = margin or 0
  f.faceMargin = margin
  face:SetSize(f:GetWidth() + 2 * margin, f:GetHeight() + 2 * margin)
  face:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.face = face
  faceOwners[f] = true
  f:HookScript("OnSizeChanged", function(self, w, h)
    if w and h then self.face:SetSize(w + 2 * self.faceMargin, h + 2 * self.faceMargin) end
  end)
  -- un cadre caché arrête ses animations : au retour, l'état est reposé (avant la première image)
  face:SetScript("OnShow", function() if f._animApply == W.faceApply then W.faceApply(f) end end)
  return face
end

-- Mode « fluide » : échelle réelle = hs, facteur tenu = échelle voulue / hs. Renvoie l'échelle réelle.
local function applyFluid(f, face, hs, h)
  local ch = f._ch and f._ch.hover
  local moving = ch and ch.t < ch.dur
  if not face._armed and not moving and h == 0 then
    -- widget pas encore armé (construction en cours) : repos sans animation, échelle réelle 1
    if face:GetScale() ~= 1 then face:SetScale(1) end
    stopZoom(face)
    return 1
  end
  face._armed = true
  local real = face:GetScale()
  local cur0, force = (1 + (hs - 1) * h) / hs, nil
  if real ~= hs then
    -- premier armement, échelle de survol changée ou autre mode avant : échelle réelle posée, facteur
    -- recalculé pour garder la taille visible
    cur0 = real * animFactor(face) / hs
    face:SetScale(hs)
    force = true
  end
  if moving then
    holdTo(face, (1 + (hs - 1) * ch.to) / hs, ch.dur - ch.t, "OUT", cur0, force)
  else
    holdTo(face, (1 + (hs - 1) * h) / hs, 0, "OUT", cur0, force)
  end
  return hs
end

-- Applique les canaux « hover » (0..1) et « dx » (pixels) au visuel. Mode « fluide » : voir
-- applyFluid. Mode « net » : pendant le mouvement du canal « hover », échelle réelle inchangée et
-- animation Scale vers l'échelle d'arrivée ; canal immobile : échelle réelle = échelle d'arrivée,
-- animation coupée (même appel). Les décalages (levée, écart) sont divisés par l'échelle réelle.
function W.faceApply(f)
  local face = f.face
  if not face then return end
  local h = W.animValue(f, "hover")
  local dx = W.animValue(f, "dx")
  local hs = f.hoverScale or 1
  local lift = (f.hoverLift or 0) * h
  local base
  local mode = W.zoomMode()
  if f._fly then
    base = face:GetScale() -- vol en cours (W.fly) : l'échelle appartient au vol
  elseif mode == "fluide" then
    base = applyFluid(f, face, hs, h)
  elseif mode == "net" then
    local ch = f._ch and f._ch.hover
    local goal = 1 + (hs - 1) * (ch and ch.to or 0)
    base = face:GetScale()
    if ch and ch.t < ch.dur then
      -- en route : étirement visuel relatif à l'échelle réelle (repart du facteur courant si la
      -- cible change en route : réversible)
      zoomTo(face, goal / base, ch.dur - ch.t)
    else
      -- arrivée : échelle réelle posée, animation coupée, dans le même appel
      if base ~= goal then face:SetScale(goal) base = goal end
      stopZoom(face)
    end
  else
    stopZoom(face)
    base = 1 + (hs - 1) * h
    face:SetScale(base)
  end
  face:ClearAllPoints()
  face:SetPoint("CENTER", f, "CENTER", dx / base, lift / base)
  if f.hoverPaint then f:hoverPaint(h) end
end

-- Change l'échelle et la levée de survol d'un visuel et repose son état (mode fluide : échelle
-- réelle posée tout de suite, au repos, plutôt qu'au survol suivant).
function W.setHover(f, scale, lift)
  if scale then f.hoverScale = scale end
  if lift then f.hoverLift = lift end
  if f._animApply == W.faceApply and f.face and f.face._armed then W.faceApply(f) end
end

-- Rend f survolable : opts = { scale, lift (unités de f, vers le haut), paint(f, h), manual }.
-- manual = l'écran pilote lui-même le canal « hover » (main, cartes à sélection). Mode fluide :
-- armé à l'image suivante (après la construction du widget, qui suit souvent cet appel).
function W.hoverable(f, opts)
  opts = opts or {}
  if not f.face then W.face(f) end
  f._hoverable = true
  f.hoverScale = opts.scale or 1.06
  f.hoverLift = opts.lift or 0
  f.hoverPaint = opts.paint or f.hoverPaint
  f._hoverManual = opts.manual
  f._animApply = W.faceApply
  W.delay(0, function()
    if f._animApply == W.faceApply and f.face and not f.face._armed and not f._fly then
      f.face._armed = true
      W.faceApply(f)
    end
  end)
  return f
end

function W.hoverEnter(f)
  if f._hoverable and not f._hoverManual and f.active ~= false then W.animTo(f, "hover", 1, W.HOVER_IN) end
end

function W.hoverLeave(f)
  if f._hoverable and not f._hoverManual then W.animTo(f, "hover", 0, W.HOVER_OUT) end
end

-- Remet un visuel au repos sans animation (écran qui se reconstruit, cadre caché).
function W.hoverReset(f)
  if f._ch then
    for key in pairs(f._ch) do W.animSet(f, key, 0) end
  end
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

-- Trois tranches horizontales (boutons, cadre compact d'ennemi) : bouts de `cap` pixels stockés mis à
-- l'échelle de la hauteur de l'hôte, milieu étiré. Textures sur opts.parent (défaut : l'hôte).
function W.threeSlice(host, name, layer, sub, opts)
  opts = opts or {}
  local e = WP[name]
  local owner = opts.parent or host
  local o = setmetatable({ parts = {}, host = host, name = name }, Group)
  local a = e.cap / e.pw
  local cuts = { { 0, a }, { a, 1 - a }, { 1 - a, 1 } }
  for i = 1, 3 do
    local t = W.noSnap(owner:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0))
    W.setWow(t, name, { cuts[i][1], cuts[i][2], 0, 1 })
    o.parts[i] = t
  end
  o.Layout = function(self, h)
    h = h or host:GetHeight()
    if not h or h <= 0 then return end
    local cap = e.cap * h / e.ph
    local L, M, R = self.parts[1], self.parts[2], self.parts[3]
    L:ClearAllPoints() M:ClearAllPoints() R:ClearAllPoints()
    L:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    L:SetPoint("BOTTOMRIGHT", host, "BOTTOMLEFT", cap, 0)
    R:SetPoint("TOPLEFT", host, "TOPRIGHT", -cap, 0)
    R:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    M:SetPoint("TOPLEFT", host, "TOPLEFT", cap, 0)
    M:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -cap, 0)
    self.cap = cap
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
-- affichées à k unités par pixel ; milieu et bords étirés.
function W.nineStretch(host, name, m, k, layer, sub, owner)
  local e = WP[name]
  local o = setmetatable({ parts = {}, host = host }, Group)
  owner = owner or host
  local us = { 0, m[1] / e.pw, 1 - m[3] / e.pw, 1 }
  local vs = { 0, m[2] / e.ph, 1 - m[4] / e.ph, 1 }
  local L, T, R, B = m[1] * k, m[2] * k, m[3] * k, m[4] * k
  local xs = { { "LEFT", 0 }, { "LEFT", L }, { "RIGHT", -R }, { "RIGHT", 0 } }
  local ys = { { "TOP", 0 }, { "TOP", -T }, { "BOTTOM", B }, { "BOTTOM", 0 } }
  for row = 1, 3 do
    for col = 1, 3 do
      local t = W.noSnap(owner:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0))
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

-- Boutons rouges du jeu (128-RedButton) ; action principale : rouge et or (128-GoldRedButton). Survol :
-- le bouton s'éclaircit, le liseré d'or apparaît (bouton rouge) ; sélection (b:SetSelected) : liseré d'or
-- tenu. Libellé doré (NORMAL_FONT_COLOR), ombre portée.
local BTN_DIM = 0.86
local function buttonPaint(self, h)
  if self.active == false then h = 0 end
  local k = BTN_DIM + (1 - BTN_DIM) * h
  self.base:SetVertexColor(k, k, k)
  if self.hot then
    self.hot:SetVertexColor(k, k, k)
    self.hot:SetAlpha(max(self.selected and 1 or 0, h))
  end
end

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
  b.label = W.label(face, "bold", size or (h >= 40 and 18 or (h >= 30 and 14 or 12.5)), C.wowGold)
  b.label:SetPoint("CENTER", 0, 0.5)
  b.label:SetText(label or "")
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
  end
  W.hoverable(b, { scale = h >= 40 and 1.04 or 1.06, paint = buttonPaint })
  buttonPaint(b, 0)
  b:SetScript("OnEnter", function(self)
    W.hoverEnter(self)
    if self.onEnterExtra then self:onEnterExtra() end
  end)
  b:SetScript("OnLeave", function(self)
    W.hoverLeave(self)
    if self.onLeaveExtra then self:onLeaveExtra() end
  end)
  b.SetActive = function(self, on)
    self.active = on
    self:SetAlpha(on and 1 or 0.5)
    self.base:SetDesaturated(not on)
    if on then self:Enable() else self:Disable() W.animTo(self, "hover", 0, W.HOVER_OUT) end
  end
  if onClick then b:SetScript("OnClick", function(self, button)
    W.sound("click")
    onClick(self, button)
  end) end
  return b
end

-- Bouton de fermeture rouge du jeu (RedButton-Exit) pour « × » ; autre glyphe (« < », « > ») : petit
-- bouton rouge carré portant le glyphe. Survol : s'éclaircit et grossit un peu.
function W.roundButton(parent, glyph, size, _, _, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  local face = W.face(b)
  if glyph == "×" then
    b.base = W.wow(face, "btn_close", "ARTWORK", 0)
    b.base:SetAllPoints()
    b.label = W.label(face, "heavy", 1, C.text) -- (compatibilité : pas de glyphe dessiné)
  else
    b.base = W.threeSlice(face, "btn_red", "ARTWORK", 0)
    b.label = W.label(face, "heavy", floor(size * 0.55), C.wowGold)
    b.label:SetPoint("CENTER", 0, 1)
    b.label:SetText(glyph)
  end
  W.hoverable(b, { scale = 1.12, paint = function(self, h)
    local k = BTN_DIM + (1 - BTN_DIM) * h
    self.base:SetVertexColor(k, k, k)
  end })
  b.base:SetVertexColor(BTN_DIM, BTN_DIM, BTN_DIM)
  b:SetScript("OnEnter", function(self) W.hoverEnter(self) end)
  b:SetScript("OnLeave", function(self) W.hoverLeave(self) end)
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
function W.slider(parent, w, get, step, setFrac)
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
    local f = max(0, min(1, get() or 0))
    local tw = w - 32 - 12
    self.thumb:ClearAllPoints()
    self.thumb:SetPoint("CENTER", track, "LEFT", 6 + tw * f, 0)
  end
  -- clic ou glisser sur le rail : fraction sous le curseur
  local function fromCursor()
    if not GetCursorPosition then return end
    local x = GetCursorPosition()
    local sc = track:GetEffectiveScale() or 1
    local left = track:GetLeft()
    if not left then return end
    local tw = w - 32 - 12
    setFrac(max(0, min(1, (x / sc - left - 6) / max(1, tw))))
    s:Sync()
  end
  track:SetScript("OnMouseDown", function(self)
    fromCursor()
    self:SetScript("OnUpdate", fromCursor)
  end)
  track:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
  track:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
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

-- Infobulle au survol ; anime aussi le survol si le cadre est survolable (W.hoverable).
function W.tooltip(frame, fill, anchor)
  frame:SetScript("OnEnter", function(self)
    W.hoverEnter(self)
    if self.onEnterExtra then self:onEnterExtra() end
    GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
    fill(GameTooltip, self)
    if GameTooltip:NumLines() > 0 then GameTooltip:Show() else GameTooltip:Hide() end
  end)
  frame:SetScript("OnLeave", function(self)
    W.hoverLeave(self)
    if self.onLeaveExtra then self:onLeaveExtra() end
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
  if n and n > 0 then suffix = s and s.duration and (" (" .. n .. " turn" .. (n > 1 and "s" or "") .. ")")
    or (" " .. n) end
  local bad = s and (s.debuff or s.affix)
  tt:AddLine(name .. suffix, bad and 1 or 0.4, bad and 0.35 or 0.9, bad and 0.35 or 0.4)
  wrap(tt, text)
end

-- Mots-clés d'une définition de carte (pour l'infobulle).
function W.cardKeywords(d)
  local list, seen = {}, {}
  local function add(k, label, n)
    if seen[k] then return end
    seen[k] = true
    list[#list + 1] = { key = k, label = label, n = n }
  end
  if d.cast then add("cast") end
  if d.cooldown then add("cooldown", "Cooldown " .. d.cooldown, d.cooldown) end
  if d.exhaust then add("exhaust") end
  if d.retain then add("retain") end
  if d.power or d.type == "power" then add("power") end
  -- texte : conditions nommées et conditions sur un état (« Name: »), puis états cités
  local text = d.text or ""
  for _, c in ipairs(W.CONDITIONS) do
    if W.hasPhrase(text, c.name .. ":") then add(c.key) end
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
    elseif e[1] == "demence" then add("demence")
    elseif e[1] == "interrupt" then add("interrupt") end
  end
  if W.hasPhrase(text, "Absorb") then add("absorb") end
  if W.hasPhrase(text, "Insanity") then add("demence") end
  return list
end

-- Ligne d'explication d'un mot-clé de carte (W.cardKeywords), sablier en icône.
function W.keywordText(k)
  local line
  if k.key:sub(1, 7) == "status:" then line = Art.statusLine(k.key:sub(8))
  elseif k.key:sub(1, 5) == "cond:" then line = Art.conditionLine(k.key:sub(6))
  else line = Art.keywordLine(k.key, k.label, k.n) end
  return W.inlineIcons(line, 12)
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
  if extra and extra.preview and not up and ns.Cards[id].up then
    local u = Card.defById(id, true)
    gold(tt, "Upgraded:")
    for _, l in ipairs(W.cardTextLines(u, ns.Cards[id])) do wrap(tt, l, 0.5, 1, 0.5) end
  end
  -- mots-clés : une ligne chacun, en bloc (séparé du reste par une ligne vide)
  local kws = W.cardKeywords(d)
  if #kws > 0 and tt:NumLines() > 0 then tt:AddLine(" ") end
  for i = 1, #kws do
    wrap(tt, W.keywordText(kws[i]), 0.85, 0.85, 0.85)
  end
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
  b.count = W.label(face, "heavy", 11, C.text, "OVERLAY")
  b.count:SetPoint("BOTTOMRIGHT", -1, 1)
  W.hoverable(b, { scale = 1.12, paint = function(self, h)
    if self.case then self.case.hot:SetAlpha(h) end
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

-- Barre de réputation : barre jaune du jeu dans un rail de curseur minimal ; bar = { label, levelName,
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
    self.value:SetText(b.size and (b.levelName .. "  " .. b.cur .. " / " .. b.size) or b.levelName)
    self.detail:SetText(b.detail or "")
  end
  return f
end

---------------------------------------------------------------------------
-- Jetons d'état : icônes d'aura (cadre de case du jeu, rouge pour un affaiblissement), nombre en bas à droite
---------------------------------------------------------------------------

-- Rangée centrée de jetons avec infobulle ; list = { { icon = entrée, n = nombre, rim = teinte, info = {...} } }.
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
    t.medal = { icon = icon, ring = ring,
      SetRing = function(self, c) c = c or Art.rim.silver self.ring:SetVertexColor(c[1], c[2], c[3], 1) end }
    t.count = W.label(face, "heavy", floor(size * 0.45), C.text, "OVERLAY")
    t.count:SetPoint("BOTTOMRIGHT", face, "BOTTOMRIGHT", 1, -1)
    W.hoverable(t, { scale = 1.12 })
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
    list[#list + 1] = {
      icon = Art.statuses[id] or Art.affixes[id] or { icon = Art.QUESTION },
      n = type(n) == "number" and n or nil,
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

local KEYWORD_STRIP = {
  { flag = "cooldown", pat = "%s*Cooldown %d+%." },
  { flag = "exhaust", pat = "%s*Exhaust%." },
  { flag = "retain", pat = "%s*Retain%." },
  { flag = "cast", pat = "^Cast%.%s*" },
  { flag = "power", pat = "^Power%.%s*" },
}

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
W.CONDITIONS = {
  { name = "Execute", key = "execute" },
  { name = "Surge", key = "surge" },
  { name = "Last Breath", key = "lastBreath" },
  { name = "Shadow", key = "shadow" },
}

-- Le nombre de l'état compte des tours (sablier) ?
function W.isTurnStatus(id)
  local s = ns.Statuses[id]
  return s ~= nil and (s.duration or s.turns) and true or false
end

-- Séquence |T du sablier pour un texte de taille size (unités) : hauteur entière (la séquence ne
-- prend que des entiers), ~0,68 cadratin (le dessin occupe 30 px sur 32 : à la hauteur des chiffres
-- de Baloo Chettan 2, 0,62 cadratin) ; texture rognée à droite (x 0 à 28 sur 32) : la marge de gauche
-- du dessin tient lieu d'espace après le nombre, presque rien après. color : teinte (couleur de
-- sommet r:g:b, 0–255), blanc par défaut.
W.HOURGLASS_CROP = 28
function W.hourglassSize(size)
  local h = max(5, floor(size * 0.68 + 0.5))
  return h, max(4, floor(h * W.HOURGLASS_CROP / 32 + 0.5))
end
function W.hourglass(size, color)
  local h, w = W.hourglassSize(size)
  local c = color or C.white
  return ("|T%s:%d:%d:0:0:32:32:0:%d:0:32:%d:%d:%d|t"):format(W.HOURGLASS, h, w, W.HOURGLASS_CROP,
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
function W.cardBody(d, base)
  local text = d.text or ""
  for _, k in ipairs(KEYWORD_STRIP) do
    if d[k.flag] or (k.flag == "power" and d.type == "power") then text = text:gsub(k.pat, "") end
  end
  -- ligne d'état : le verbe reste avec le nom de l'état (« Gain Atonement », « Apply Stunned »)
  local cl = {}
  for l in (text .. "\n"):gmatch("(.-)\n") do
    if W.isStateClause(l) then l = l:gsub("^(%S+) ", "%1" .. NBSP, 1) end
    cl[#cl + 1] = l
  end
  text = table.concat(cl, "\n")
  -- un nom d'état insécable avec son nombre (« Pain 5 », « Sundered 2 ⌛ ») ; « to all » insécable
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
  if d.type == "power" then list[#list + 1] = "Power" end
  if d.cast then list[#list + 1] = "Cast" end
  if d.cooldown then list[#list + 1] = "Cooldown " .. d.cooldown end
  if d.exhaust then list[#list + 1] = "Exhaust" end
  if d.retain then list[#list + 1] = "Retain" end
  return list
end

-- Zone utile du texte : intérieur sombre du panneau d'ardoise (mesuré sur Media/card_panel.tga :
-- x 0,1541 à 0,8429, bas 1,19, biseau dès 1,0754 où la demi-largeur intérieure vaut 0,308 et rentre de
-- 0,56 par unité de hauteur), sous la gemme de rareté (bas opaque de la plus grande : 0,7622, mesuré
-- sur Media/gem_*.tga), marges comprises. Fractions de la largeur du corps. Le harnais vérifie chaque
-- ligne posée contre les pixels mêmes des textures (Sim/ui_harness.lua, U22).
local TZ = {
  cx = 0.4985,                  -- axe de l'intérieur
  half = 0.3004,                -- demi-largeur : 0,3444 moins la marge latérale (0,044 ≈ 5,5 unités)
  top = 0.7661,                 -- haut des lignes : sous la gemme (les lignes ont ~2 unités de vide en haut)
  bottom = 1.1492,              -- bas des lignes : 5 unités au-dessus du bas de l'intérieur
  bevY = 1.0754, bevHalf = 0.2574, bevSlope = 0.56, -- biseau du bas, marge déduite (×1,15 en biais)
}
W.CARD_TEXT = TZ
-- Paliers de taille du texte (unités de la carte) : chaque carte prend le plus grand qui tient dans la
-- zone utile ; 7 = plancher lisible. Sous le plancher : secours signalé (bodyFit.under).
W.BODY_SIZES = { 10, 9.5, 9, 8.5, 8, 7.5, 7 }
-- Position verticale du bloc dans la zone (fraction du jeu vertical : 0,5 = centré, 0 = en haut) :
-- essais dans l'ordre, le premier où les lignes tiennent.
W.BODY_LIFT = { 0.5, 0.33, 0.17, 0 }
W.BODY_UNDER = { 6.5, 6 }
-- Nom sur le ruban : une ligne, le plus grand palier qui tient, marge de 4 unités de chaque côté.
W.NAME_SIZES = { 11, 10, 9, 8, 7 }
W.NAME_UNDER = { 6.5, 6 }
W.NAME_MARGIN = 4

-- Demi-largeur utile de la zone à la hauteur y (fraction de la largeur du corps).
function W.cardTextHalf(y)
  return min(TZ.half, TZ.bevHalf - (y - TZ.bevY) * TZ.bevSlope)
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

-- Mots insécables : une ponctuation détachée (« : », plus employée en anglais, gardée par prudence)
-- et un nombre qui finit la phrase (« Draw 1. ») restent avec le mot d'avant, un nombre seul (« 12 »,
-- « +1 ») avec le mot d'après (« 12 Absorb », « +1 Insanity », « 2 turns »).
local function plainWord(w)
  return (w:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", W.HOURGLASS_CHAR))
end
function W.cardWords(text)
  local raw = {}
  for w in text:gmatch("%S+") do raw[#raw + 1] = w end
  local words = {}
  local i = 1
  while i <= #raw do
    local w = raw[i]
    local p = plainWord(w)
    if (p:match("^[:;!?]+$") or (p:gsub("^−", "")):match("^[+%-]?%d+[.,]$")) and #words > 0 then
      words[#words] = words[#words] .. " " .. w
      i = i + 1
    else
      local num = p:gsub("^−", "")
      while num:match("^[+%-]?%d+$") and raw[i + 1] and not plainWord(raw[i + 1]):match("^[:;!?]+$") do
        i = i + 1
        w = w .. " " .. raw[i]
        num = plainWord(raw[i]):gsub("^−", "")
      end
      words[#words + 1] = w
      i = i + 1
    end
  end
  return words
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
-- Pain 3. Gain Regen 1 »). Un paragraphe commence toujours une ligne.
-- Une clause conditionnelle (« Pain: … », « Execute: … ») commence toujours une ligne, et la
-- clause qui la suit aussi (elle ne doit pas paraître soumise à la condition) : seules les clauses
-- simples qui se suivent coulent ensemble.
function W.isConditionClause(s)
  local label = plainClause(s):match("^(.-): ")
  if not label then return false end
  for _, k in ipairs(keywordList()) do if k.name == label then return true end end
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

-- Coupe les paragraphes paras en lignes à la taille size dans la zone (top, bottom en unités) : le
-- moins de lignes possible, chaque ligne limitée à la largeur de la zone à sa hauteur (biseau
-- compris), bloc centré verticalement ; lignes remplies de haut en bas (chaque ligne prend le plus de
-- mots possible tant que la suite tient dans les lignes restantes) ; un paragraphe commence une ligne.
-- Le sablier est posé à la taille size (largeur mesurée avec le texte). Renvoie les lignes, ou nil si
-- le texte ne tient pas ; "font" si la police ne mesure rien (pas encore chargée).
local function layoutBody(paras, size, top, bottom)
  local CW = W.CARD_W
  local m = measureFS("bold", size)
  m:SetText("Ég")
  local lh = m:GetStringHeight() or 0
  if lh <= 0 or widthOf(m, "Ég") <= 0 then return nil, "font" end
  local words, brk = {}, {}
  for p = 1, #paras do
    local ws = W.cardWords(W.inlineIcons(paras[p], size))
    for k = 1, #ws do
      words[#words + 1] = ws[k]
      if k == 1 and p > 1 then brk[#words] = true end
    end
  end
  local nw = #words
  if nw == 0 then return {}, lh end
  -- largeur des mots i..j sur une ligne (mesurée une fois, icônes comprises) ; infinie si la ligne
  -- franchirait un début de paragraphe
  local memo = {}
  local function span(i, j)
    local key = i * 1000 + j
    local v = memo[key]
    if not v then
      v = 0
      for k = i + 1, j do if brk[k] then v = math.huge end end
      if v == 0 then v = widthOf(m, (table.concat(words, " ", i, j):gsub(NBSP, " "))) end
      memo[key] = v
    end
    return v
  end
  local H = bottom - top
  for n = 1, min(nw, floor(H / lh + 1e-6)) do
    -- bloc centré verticalement ; s'il ne tient pas, remonté par paliers jusqu'au haut de la zone
    -- (le biseau du bas laisse alors plus de largeur à la dernière ligne)
    local slack = H - n * lh
    for _, f in ipairs(W.BODY_LIFT) do
      local y0 = top + slack * f
      local wmax = {}
      for k = 1, n do wmax[k] = 2 * W.cardTextHalf((y0 + k * lh) / CW) * CW end
      -- ok[k][i] : les mots i.. tiennent exactement sur les lignes k..n
      local ok = {}
      ok[n + 1] = { [nw + 1] = true }
      for k = n, 1, -1 do
        ok[k] = {}
        for i = k, nw - (n - k) do
          for j = i, nw - (n - k) do
            if span(i, j) > wmax[k] then break end
            if ok[k + 1][j + 1] then ok[k][i] = true break end
          end
        end
      end
      if ok[1][1] then
        local lines, i = {}, 1
        for k = 1, n do
          local j = i
          for jj = i, nw - (n - k) do
            if span(i, jj) > wmax[k] then break end
            if ok[k + 1][jj + 1] then j = jj end
          end
          lines[k] = (table.concat(words, " ", i, j):gsub(NBSP, " "))
          i = j + 1
        end
        return { lines = balanceColors(lines), y0 = y0 }, lh
      end
    end
  end
  return nil, lh
end

local layoutCache = {}
function W.clearTextCache() layoutCache = {} end

-- Pose le texte de la carte : premier palier où il tient, mise en page figée (lignes séparées par
-- des retours explicites, largeur du texte un peu plus grande que la plus longue ligne possible :
-- le client ne recoupe jamais autrement, ni à une autre échelle, ni pendant un zoom), puis
-- vérification par le client (GetNumLines, IsTruncated, GetStringHeight). bottom : bas de la zone
-- (unités), relevé si une plaque mord sur le panneau.
-- Essais dans l'ordre : une clause par ligne aux paliers >= W.CLAUSE_MIN (du plus grand au plus
-- petit) ; sinon, à chaque palier du plus grand au plus petit : une clause par ligne, puis texte qui
-- coule avec chaque état posé sur sa ligne (« flow »), puis états groupés en une dernière ligne
-- (« flowAll »).
W.CLAUSE_MIN = 8.5
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
  for _, e in ipairs(all) do if not e.under and e.s >= W.CLAUSE_MIN then add(e, "clauses") end end
  for _, e in ipairs(all) do
    add(e, "clauses")
    add(e, "flow")
    add(e, "flowAll")
  end
  return tries
end

local function fitBody(card, text, bottom)
  local CW = W.CARD_W
  local fs = card.body
  local top = TZ.top * CW
  fs:ClearAllPoints()
  fs:SetPoint("CENTER", card.bg, "TOPLEFT", TZ.cx * CW, -(top + bottom) / 2)
  fs:SetWidth(2 * TZ.half * CW + 8)
  local fit, fontErr
  for _, t in ipairs(W.cardTries(text)) do
    local s = t.size
    local key = floor(bottom * 10 + 0.5) .. "|" .. t.key
    local lay = layoutCache[key]
    local err, lh
    if lay == nil then
      lay, err = layoutBody(t.paras, s, top, bottom)
      if err == "font" then fontErr = true break end
      lh = err
      if lay then lay.lh = lh end
      layoutCache[key] = lay or false
    end
    if lay then
      local lines = lay.lines
      W.setSize(fs, s)
      fs:SetText(table.concat(lines, "\n"))
      -- centre du bloc : centre de la zone, ou plus haut si le bloc a été remonté
      fs:ClearAllPoints()
      fs:SetPoint("CENTER", card.bg, "TOPLEFT", TZ.cx * CW, -(lay.y0 + #lines * lay.lh / 2))
      local n = fs.GetNumLines and fs:GetNumLines() or #lines
      local hh = fs:GetStringHeight() or 0
      if (n == #lines or #lines == 0) and not (fs.IsTruncated and fs:IsTruncated()) and hh <= bottom - top + 0.5 then
        fit = { size = s, lines = #lines, under = t.under or false, ok = true, mode = t.mode, y0 = lay.y0 }
        break
      end
    end
  end
  if not fit then
    -- police pas encore mesurable, ou texte trop long même au dernier secours : retour à la ligne du
    -- client, au plancher (déborde peut-être : signalé)
    local s = W.BODY_SIZES[#W.BODY_SIZES]
    W.setSize(fs, s)
    fs:SetWidth(2 * TZ.half * CW)
    fs:SetText((W.inlineIcons(text, s):gsub(NBSP, " ")))
    fit = { size = s, under = true, ok = false, font = fontErr }
  end
  card.bodyFit = fit
  return fit
end

-- Nom sur le ruban : premier palier où il tient sur une ligne dans la bande (marges comprises).
local function fitName(fs, text)
  local w = SC.name.len * W.CARD_W - 2 * W.NAME_MARGIN
  local sizes = {}
  for _, s in ipairs(W.NAME_SIZES) do sizes[#sizes + 1] = s end
  for _, s in ipairs(W.NAME_UNDER) do sizes[#sizes + 1] = s end
  fs:SetText(text)
  for idx, s in ipairs(sizes) do
    W.setSize(fs, s)
    local sw = (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0
    if sw > 0 and sw <= w and not (fs.IsTruncated and fs:IsTruncated()) then
      return { size = s, under = idx > #W.NAME_SIZES, ok = true }
    end
  end
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
  local a = PLATE.capPx / PLATE.texW
  local cuts = { { 0, a }, { a, 1 - a }, { 1 - a, 1 } }
  for k = 1, 3 do
    local t = W.noSnap(face:CreateTexture(nil, "BACKGROUND", nil, -5))
    t:SetTexture(ROOT .. e.file, nil, nil, "TRILINEAR")
    t:SetTexCoord(cuts[k][1] * e.tc[2], cuts[k][2] * e.tc[2], 0, e.tc[4])
    o.parts[k] = t
  end
  -- pose les tranches pour une largeur totale w (unités), par rapport au corps org
  o.Layout = function(self, org, w)
    local box = W.cardPlateBox(w)
    self.box = box
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
    local sw = width(text, s)
    if sw > 0 and sw <= baseText then fit = { size = s, w = base, text = text } break end
  end
  if not fit then
    local s = W.PLATE_SIZES[#W.PLATE_SIZES]
    local sw = width(text, s)
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
        local sw = width(t, s)
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
    until #keep == 0 or width(t, s) + extra <= maxW
    fit = { size = s, w = maxW, text = t, wide = true, under = true, short = true, cut = true }
  end
  b.plate:Layout(b.bg, fit.w)
  local box = b.plate.box
  W.setSize(fs, fit.size)
  fs:SetText(fit.text)
  fs:ClearAllPoints()
  fs:SetPoint("CENTER", b.bg, "TOPLEFT", box.cx, -box.cy)
  fs:SetWidth(box.textW + 1)
  if fit.ok == nil then fit.ok = not (fs.IsTruncated and fs:IsTruncated()) end
  b.plateFit = fit
  return fit
end

-- Plaque posée sous la carte (raison d'un refus, prix) : créée au premier besoin (hors animation
-- d'échelle : W.faceBuild).
local newCardPlaque
local function cardPlaque(b, key, w, h)
  local p = b[key]
  if p then return p end
  return W.faceBuild(b, function() return newCardPlaque(b, key, w, h) end)
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
-- que le survol anime (W.hoverable). Réglages par écran : b.hoverScale, b.hoverLift (unités de la
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
    if width(text, s) <= baseW - 2 * REASON_PAD then size = s break end
  end
  if not size then
    size = W.REASON_SIZES[#W.REASON_SIZES]
    local sw = width(text, size)
    if sw + 2 * REASON_PAD <= CW then
      w = sw + 2 * REASON_PAD
    else
      local words = {}
      for word in text:gmatch("%S+") do words[#words + 1] = word end
      local best, bestW
      for k = 1, #words - 1 do
        local a = table.concat(words, " ", 1, k)
        local b = table.concat(words, " ", k + 1)
        local m = max(width(a, size), width(b, size))
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
  fs:SetWidth(w - 2 * REASON_PAD + 1)
  fs:SetText(t)
  local h = REASON_H
  if lines > 1 then h = max(REASON_H, (fs:GetStringHeight() or 2 * size * 1.5) + 6) end
  p:SetSize(w, h)
  p.fit = { size = size, lines = lines, w = w, h = h }
  return h
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

  -- textes
  b.name = W.label(face, "bold", 10, C.text, "OVERLAY")
  b.name:SetWordWrap(false)
  b.name:SetJustifyH("CENTER")
  b.name:SetPoint("CENTER", org, "TOPLEFT", SC.name.cx * CW, -SC.name.cy * CW)
  b.name:SetWidth(SC.name.len * CW)
  b.cost = W.label(face, "heavy", 14, C.costText, "OVERLAY")
  b.cost:SetPoint("CENTER", org, "TOPLEFT", SC.cost.cx * CW, -SC.cost.cy * CW)
  b.body = W.label(face, "bold", W.BODY_SIZES[1], C.textSoft, "OVERLAY")
  -- centré dans la zone utile du panneau, lignes posées par fitBody ; hauteur libre (un texte trop
  -- long déborde au lieu d'être tronqué en « … » : le harnais le signale)
  b.body:SetJustifyH("CENTER")
  b.body:SetJustifyV("MIDDLE")
  b.body:SetWordWrap(true)
  b.plateText = W.label(face, "bold", 8.5, C.text, "OVERLAY")
  b.plateText:SetPoint("CENTER", org, "TOPLEFT", SC.plateText.cx * CW, -SC.plateText.cy * CW)
  b.plateText:SetWordWrap(false)
  b.plateText:SetJustifyH("CENTER")
  b.kind = b.plateText -- compatibilité

  -- opts : cost, playable, reason, manaShort, price, sold, tooPoor, preview, showUp
  b.SetCard = function(self, id, up, opts)
    opts = opts or {}
    self.cardId, self.cardUp, self.opts = id, up, opts
    local showUp = up or opts.showUp
    local d = Card.defById(id, showUp)
    local base = showUp and ns.Cards[id] or nil
    local dim = opts.playable == false
    -- corps à la couleur de la carte
    W.setSkin(self.bg, "card_body_" .. Art.cardBody(id, ns.Cards[id] or d))
    -- nom sur le ruban (paliers)
    self.nameFit = fitName(self.name, d.name)
    local nc = showUp and C.upGreen or C.text
    self.name:SetTextColor(nc[1], nc[2], nc[3])
    -- médaillon
    W.setIcon(self.icon, W.cardArt(id), "card:" .. id)
    -- texte : zone utile du panneau, relevée au-dessus de la plaque de raison si elle y mord
    local text = W.cardBody(d, base)
    local bottom = TZ.bottom * CW
    local reasonH
    if dim and opts.reason then
      reasonH = fitReason(cardPlaque(self, "reasonPlate", 0.84 * CW, REASON_H), opts.reason)
      bottom = min(bottom, REASON_Y * CW + REASON_H / 2 - reasonH - 1)
    end
    local fit = fitBody(self, text, bottom)
    if fit.font and not self._refit then
      -- police pas encore chargée : nouvelle mise en page un peu plus tard
      self._refit = true
      W.delay(0.5, function()
        self._refit = nil
        if self.cardId == id and self.cardUp == up and self.opts == opts then self:SetCard(id, up, opts) end
      end)
    end
    -- plaque du bas : mots-clés
    local pills = W.cardPills(d)
    if #pills > 0 then
      fitPlate(self, pills)
      self.plate:Show()
      self.plateText:Show()
    else
      self.plate:Hide()
      self.plateText:Hide()
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
    -- coût
    local cost = opts.cost or d.cost
    self.cost:SetText(tostring(cost))
    if d.cost == nil or d.unplayable then self.cost:Hide() self.costTab:Hide() else self.cost:Show() self.costTab:Show() end
    -- injouable : grisée, raison dans une plaque rouge au bas de la carte
    local k = dim and 0.62 or 1
    for _, t in ipairs({ self.bg, self.ribbon, self.costTab, self.panel, self.ring, self.plate, self.gem, self.glass }) do
      t:SetDesaturated(dim)
      t:SetVertexColor(k, k, k, 1)
    end
    self.icon:SetDesaturated(dim)
    self.icon:SetVertexColor(k, k, k, 1)
    local short = opts.manaShort and not dim
    if short then
      self.costTab:SetDesaturated(true)
      self.costTab:SetVertexColor(1, 0.42, 0.38, 1)
    end
    local dc = dim and C.textDim or C.textSoft
    self.body:SetTextColor(dc[1], dc[2], dc[3])
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

  -- Survol animé : levée, agrandissement, halo qui s'allume ; passage au premier plan.
  W.hoverable(b, { scale = 1.12, lift = 10, paint = function(self, h)
    if self.hot then self.halo:SetAlpha(h) end -- fondu depuis 0 (pas d'éclat à la première image)
  end })
  b.onAnimSettled = function(self)
    if self.baseLevel and W.animValue(self, "hover") == 0 then W.setLevel(self, self.baseLevel) end
  end
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
  if f:GetScale() ~= scale then f:SetScale(scale) end -- même échelle : rien à redessiner
  f:ClearAllPoints()
  f:SetPoint("CENTER", container, "TOPLEFT", x / scale, -y / scale)
end

-- Fait voler un cadre de (x1, y1) à (x2, y2) avec échelle et alpha, puis onDone.
-- Mode « fluide » (cadre à visuel survolable : cartes) : échelle réelle du cadre fixée pendant tout le
-- vol à B = max(s1, s2) (polices rasterisées une fois, à la plus grande taille du vol : jamais étirées),
-- visuel à son échelle réelle de survol, et le facteur tenu du visuel anime la taille de s1 à s2. Une
-- carte qui grandit (pioche) arrive exactement dans l'état de repos (échelle réelle s2, facteur
-- 1 / hoverScale) : rien ne change à l'atterrissage. Une carte qui rétrécit (vers la cible, la
-- défausse) reçoit son échelle réelle s2 et son facteur de repos dans le même appel, puis est cachée.
-- Mode « net » : échelle réelle fixée à s1 pendant le vol, changement d'échelle par animation Scale
-- partant du facteur 1 ; à l'arrivée, dans le même appel, animation coupée et échelle réelle s2 posée.
-- Mode « lisse » : échelle réelle à chaque image.
function W.fly(f, container, x1, y1, x2, y2, s1, s2, a1, a2, dur, onDone, arc)
  f:Show()
  local mode = W.zoomMode()
  local ok = s1 > 0 and s2 > 0 and f.CreateAnimationGroup ~= nil
  local fluid = ok and mode == "fluide" and f.face ~= nil and f._animApply == W.faceApply
  local anim = ok and mode == "net"
  local base = fluid and max(s1, s2) or s1
  stopZoom(f)
  if fluid then
    local face = f.face
    local hs = f.hoverScale or 1
    local rest = (1 + (hs - 1) * W.animValue(f, "hover")) / hs
    f._fly = true
    face._armed = true
    W.placeCenter(f, container, x1, y1, base)
    if face:GetScale() ~= hs then face:SetScale(hs) end
    holdTo(face, rest * s2 / base, max(0.01, dur * W.pace()), "IN_OUT", rest * s1 / base, true)
  elseif anim then
    W.placeCenter(f, container, x1, y1, base)
    zoomTo(f, s2 / base, max(0.01, dur * W.pace()), "IN_OUT")
  end
  W.tween(dur, function(p)
    local x = x1 + (x2 - x1) * p
    local y = y1 + (y2 - y1) * p - (arc or 0) * 4 * p * (1 - p)
    W.placeCenter(f, container, x, y, (fluid or anim) and base or (s1 + (s2 - s1) * p))
    f:SetAlpha(a1 + (a2 - a1) * p)
  end, function()
    if fluid then
      f._fly = nil
      W.placeCenter(f, container, x2, y2, s2)
      if base ~= s2 then
        local hs = f.hoverScale or 1
        holdTo(f.face, (1 + (hs - 1) * W.animValue(f, "hover")) / hs, 0, "OUT", nil, true)
      end
    elseif anim then
      stopZoom(f)
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
