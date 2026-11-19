-- Règles propres du Prêtre : ses sept cartes épiques (docs/zones/cartes-de-zone.md, « Priest » ; contrat :
-- docs/classes.md, « Cartes épiques »). Le reste du Prêtre (Insanity, Atonement, Regen, Cast) est le socle
-- commun du moteur.
--
-- Une épique est une règle active tout le combat, hors de toute pile (c.epic) : ses crochets sont des deckHooks
-- (src = c.epic = { id, up, uid }, passent après classe, Powers, bibelots et affixes), posés ici sur les
-- définitions de Data/Priest.lua. Paliers (+1 à +3, docs/ameliorations.md) : nombres lus dans les tables
-- { base, +1, +2, +3 } par Priest.tier(t, src) (Card.level(src)) ; entre parenthèses, +1 / +2 / +3.
--   prayer_of_mending : onHeal → PV rendus (+2 / +3 / +4) à un ennemi vivant tiré par c.rng.cards (coup sans carte).
--   misery            : un DoT posé par une carte sur SA cible (pas « to all ») est copié sur chaque autre
--                       ennemi vivant (+1 / +2 / +3), par Combat.applyStatus (sans le crochet apply, sans boucle).
--   echo_of_light     : whileInDeck → Regen 4 au début du combat ; regenHeal → 0 ; onRegenTick → la valeur
--                       (+2 / +3 / +4) à chaque ennemi vivant (sans carte).
--   shadow_covenant   : cost → 0 pour une carte Shadow de coût final N ≥ 1, payHp → + 2N (1N dès +2), + 2 par
--                       carte Shadow déjà jouée ce tour ; les premières cartes Shadow du tour ne coûtent rien
--                       (0 / 1 / 1 / 2).
--   reflective_shield : afterHit → le tiers (la moitié / trois cinquièmes / deux tiers) de l'Absorb perdue sur ce
--                       coup, au-dessous, à l'attaquant (sans carte).
--   voidform          : canPlay → les cartes à Surge sont injouables ; damage → + 1 (+ 2) par Insanity par coup
--                       d'une carte Shadow, + 2 / + 4 fixes aux paliers 2 et 3.
--   inner_focus       : castAs → la première carte Attack ou Skill du tour part en Cast ; à sa résolution,
--                       dégâts, Absorb, soin, DoT et Regen × 1,5 (× 2 / × 2,25 / × 2,5), arrondis au supérieur.
-- État de classe c.cls : miseryT (uid de la cible de la carte en cours de résolution), miseryBusy,
-- focusRound (round où la première carte a été prise), focus (uid de la carte incantée par Inner Focus),
-- scale (facteur pendant la résolution de cette carte).
local _, ns = ...

local Combat, Rng = ns.Combat, ns.Rng
local L = ns.Language
local floor, ceil = math.floor, math.ceil

local Priest = {}
ns.Priest = Priest

---------------------------------------------------------------------------
-- Langage : plaque « Epic » (si le socle ne l'a pas encore), déclencheurs, mots expliqués au survol
---------------------------------------------------------------------------
if not L.plateByKey("epic") then
  L.plate("epic", { word = "Epic", head = true, flag = "epic", text = "in play from the start of each combat." })
end
for _, label in ipairs({ "Each heal", "DoT applied", "Each Regen heal", "Shadow cards", "Shadow hits",
  "1st card each turn" }) do
  L.trigger(label)
end
-- mots de règle des épiques (L.rule) : déclarés plus bas, avec les réglages

---------------------------------------------------------------------------
-- Aides
---------------------------------------------------------------------------
Priest.EPICS = { "prayer_of_mending", "misery", "echo_of_light", "shadow_covenant", "reflective_shield",
  "voidform", "inner_focus" }

-- Réglages (fiche : docs/zones/cartes-de-zone.md). Réglage par zones du 14/11/2026 (docs/classes.md,
-- « Épiques du Prêtre ») : Duskwood, Stranglethorn, Steppes contre epic=none, cible +8 à +14 par épique.
-- Tables par palier { base, +1, +2, +3 } (paliers écrits à la main du 15/11/2026, docs/ameliorations.md), lues
-- par Priest.tier(t, src) = t[Card.level(src) + 1].
Priest.MENDING_UP = { 0, 2, 3, 4 } -- Prayer of Mending : + N par soin
Priest.MISERY_UP = { 0, 1, 2, 3 }  -- Misery : + N par copie
Priest.ECHO_START = 4              -- Echo of Light : Regen gagnée au début de chaque combat
Priest.ECHO_PLUS = { 0, 2, 3, 4 }  -- Echo of Light : + N par tic
Priest.COVENANT_HP = { 2, 2, 1, 1 } -- Shadow Covenant : PV par point de mana
Priest.COVENANT_STEP = 2           -- Shadow Covenant : + N PV par carte Shadow déjà jouée ce tour
Priest.COVENANT_FREE = { 0, 1, 1, 2 } -- Shadow Covenant : premières cartes Shadow du tour sans PV
Priest.REFLECT_PCT = { 1 / 3, 1 / 2, 3 / 5, 2 / 3 } -- Reflective Shield : part de l'Absorb perdue renvoyée, au-dessous
Priest.VOID_BONUS = { 1, 2, 2, 2 } -- Voidform : dégâts en plus par point d'Insanity, par coup Shadow
Priest.VOID_FLAT = { 0, 0, 2, 4 }  -- Voidform : dégâts fixes en plus par coup Shadow
Priest.FOCUS_SCALE = { 1.5, 2, 2.25, 2.5 } -- Inner Focus : facteur

-- Valeur d'une table par palier pour une épique (src = c.epic, ou up / palier).
function Priest.tier(t, src)
  local n = ns.Card.level(src) + 1
  local v = t[n]
  if v == nil then v = t[#t] end
  return v
end
Priest.VOIDFORM_REASON = "Voidform: Surge cards can't be played."

-- Mots de règle des épiques (L.rule) : la carte dit « Déclencheur: Mot N. », l'à-côté la règle complète (mêmes
-- nombres que les réglages ci-dessus ; base, puis améliorée).
L.rule("divineStar", { name = "Divine Star",
  text = "Deal the HP actually restored to a random enemy. Every heal counts, Regen heals too.",
  upText = "Deal the HP actually restored, +N, to a random enemy. Every heal counts, Regen heals too." })
L.rule("contagion", { name = "Contagion",
  text = "A DoT a card applies to its target also goes to every other enemy.",
  upText = "A DoT a card applies to its target also goes to every other enemy, +N." })
L.rule("sanctify", { name = "Sanctify",
  text = "Deal the Regen heal to all enemies instead of healing. Each combat starts with Regen " .. Priest.ECHO_START .. ".",
  upText = "Deal the Regen heal +N to all enemies instead of healing. Each combat starts with Regen " .. Priest.ECHO_START .. "." })
L.rule("lifeTap", { name = "Life Tap",
  text = "Pay N HP per mana instead of mana, +" .. Priest.COVENANT_STEP .. " per Shadow card played before this turn.",
  upText = "The first ones each turn are free, as stated. Others pay N HP per mana, +"
    .. Priest.COVENANT_STEP .. " per Shadow card before." })
L.rule("reflect", { name = "Reflect",
  text = "Deal that part of the Absorb lost on the hit to the attacker, rounded down." })
L.rule("madness", { name = "Madness", text = "+N damage per Insanity. Surge cards can't be played." })
-- Empower N% : N lu sur la carte (50, 100, 125, 150 selon le palier)
L.rule("empower", { name = "Empower",
  text = "The first Attack or Skill each turn becomes a Cast, its values +N%, rounded up." })

-- Épique du Prêtre active dans ce combat : id, amélioration (nil sans épique). Plusieurs épiques en jeu
-- (c.moreEpics) : want = id cherché (cette épique si elle est en jeu), sinon la première du Prêtre.
function Priest.epicOf(c, want)
  local e, more, k = c.epic, c.moreEpics, 0
  while e do
    local d = ns.Cards[e.id]
    if d and d.class == "priest" and (not want or e.id == want) then return e.id, e.up end
    k = k + 1
    e = more and more[k]
  end
  return nil
end

-- Coup sans carte du Prêtre (comme Retaliation) : Sundered de la cible, Demoralized du Prêtre ; ni
-- Atonement, ni Shadowform, aucune boucle.
local function strike(c, e, n)
  if n <= 0 or e.dead or c.result then return end
  Combat.dealDamage(c, c.player, e, Combat.calcDamage(c, c.player, e, n))
end

local function hasSurge(d)
  local es = d.effects
  for i = 1, #(es or {}) do if es[i][1] == "surge" then return true end end
  return false
end
Priest.hasSurge = hasSurge

-- Carte qui pose un DoT « to all » (Mind Sear) : Misery ne la copie pas.
local function dotToAll(d)
  local es = d.effects
  for i = 1, #(es or {}) do
    local e = es[i]
    if e[1] == "apply" and e[2] == "pain" and e.all then return true end
  end
  return false
end

-- Inner Focus : carte qui compte comme « première carte du tour » (Attack ou Skill, hors cartes de combat
-- posées par une zone : Curse, Hexed).
local function focusable(d)
  return (d.type == "attack" or d.type == "skill") and not d.token
end
Priest.focusable = focusable

-- Inner Focus : la prochaine carte Attack ou Skill jouée ce tour sera-t-elle la première ?
function Priest.focusReady(c)
  return c.cls.focusRound ~= c.round
end

local function scaled(c, v)
  local s = c.cls.scale
  if s and v and v > 0 then return ceil(v * s - 1e-9) end
  return v
end

---------------------------------------------------------------------------
-- Crochets des épiques (deckHooks)
---------------------------------------------------------------------------
local H = {}

H.prayer_of_mending = {
  onHeal = function(c, src, n)
    if not n or n < 1 or c.result then return end
    local list = Combat.aliveEnemies(c)
    if #list == 0 then return end
    local e = list[Rng.int(c.rng.cards, 1, #list)]
    strike(c, e, n + Priest.tier(Priest.MENDING_UP, src))
  end,
}

H.misery = {
  beforeCard = function(c, src, inst, ctx)
    local t = ctx.target
    c.cls.miseryT = (t and t.side == "enemy" and not dotToAll(ctx.def)) and t.uid or nil
  end,
  onCardPlayed = function(c) c.cls.miseryT = nil end,
  onStatusApplied = function(c, src, unit, id, n)
    local cls = c.cls
    if id ~= "pain" or unit.side ~= "enemy" or cls.miseryBusy or cls.miseryT ~= unit.uid then return end
    if not n or n <= 0 then return end
    cls.miseryBusy = true
    local v = n + Priest.tier(Priest.MISERY_UP, src)
    for i = 1, #c.enemies do
      local o = c.enemies[i]
      if o ~= unit and not o.dead then Combat.applyStatus(c, o, "pain", v) end
    end
    cls.miseryBusy = nil
  end,
}

-- Echo of Light : Regen de départ posée par whileInDeck (plus bas), au début du combat.
H.echo_of_light = {
  regenHeal = function() return 0 end,
  onRegenTick = function(c, src, n)
    local v = n + Priest.tier(Priest.ECHO_PLUS, src)
    for i = 1, #c.enemies do
      if c.result then return end
      strike(c, c.enemies[i], v)
    end
  end,
}

local function covenantFree(c, src)
  return (c.turn.bySchool.shadow or 0) < Priest.tier(Priest.COVENANT_FREE, src)
end

-- PV d'une carte Shadow de coût final n ≥ 1 : 2 par point (1 dès le palier 2), + 2 par carte Shadow déjà jouée
-- ce tour. up : palier de l'épique (valeur up ou instance).
function Priest.covenantHp(c, up, n)
  return Priest.tier(Priest.COVENANT_HP, up) * n + Priest.COVENANT_STEP * (c.turn.bySchool.shadow or 0)
end

H.shadow_covenant = {
  cost = function(c, src, v, d)
    if c.cls.peek or not v or d.school ~= "shadow" then return v end
    if v >= 1 then return 0 end
    return v
  end,
  -- coût final en mana (autres Powers et bibelots compris) relu sans la conversion : Priest.covenantHp
  payHp = function(c, src, v, d, inst)
    if d.school ~= "shadow" or not d.cost or c.player.flags.freeTurnActive then return v end
    if covenantFree(c, src) then return v end
    c.cls.peek = true
    local n = math.max(0, Combat.modify(c, "cost", d.cost, d, inst))
    c.cls.peek = nil
    if n >= 1 then return v + Priest.covenantHp(c, src.up, n) end
    return v
  end,
}

H.reflective_shield = {
  afterHit = function(c, src, e, loss, absorbed)
    if not absorbed or absorbed <= 0 then return end
    strike(c, e, floor(absorbed * Priest.tier(Priest.REFLECT_PCT, src) + 1e-9))
  end,
}

H.voidform = {
  canPlay = function(c, src, v, d)
    if v == true and hasSurge(d) then return Priest.VOIDFORM_REASON end
    return v
  end,
  damage = function(c, src, v, dst, d)
    if d and d.school == "shadow" then
      return v + (c.player.res or 0) * Priest.tier(Priest.VOID_BONUS, src) + Priest.tier(Priest.VOID_FLAT, src)
    end
    return v
  end,
}

H.inner_focus = {
  castAs = function(c, src, v, d)
    if v or not focusable(d) or not Priest.focusReady(c) then return v end
    if Combat.castCount(c) >= Combat.castSlots(c) then return v end
    return true
  end,
  onCardCommitted = function(c, src, inst, d)
    if not focusable(d) or not Priest.focusReady(c) then return end
    c.cls.focusRound = c.round
    -- onCardCommitted passe avant la pose de l'incantation : la carte partira en Cast si elle l'est déjà
    -- (elle reçoit le bonus) ou si castAs l'a voulu (même question qu'au jeu, même réponse)
    if d.cast or Combat.castCount(c) < Combat.castSlots(c) then c.cls.focus = inst.uid end
  end,
  beforeCard = function(c, src, inst, ctx)
    if ctx.cast and c.cls.focus == inst.uid then
      c.cls.focus = nil
      c.cls.scale = Priest.tier(Priest.FOCUS_SCALE, src)
    end
  end,
  onCardPlayed = function(c) c.cls.scale = nil end,
  onTurnStart = function(c) c.cls.focus = nil c.cls.scale = nil end,
  damage = function(c, src, v) return scaled(c, v) end,
  block = function(c, src, v) return scaled(c, v) end,
  heal = function(c, src, v) return scaled(c, v) end,
  apply = function(c, src, n, id)
    if id == "pain" then return scaled(c, n) end
    return n
  end,
  applySelf = function(c, src, n, id)
    if id == "regen" then return scaled(c, n) end
    return n
  end,
}

Priest.HOOKS = H
for id, hooks in pairs(H) do
  local d = ns.Cards[id]
  if d then d.deckHooks = hooks end
end

-- Echo of Light : Regen de départ, une fois au début de chaque combat (après init de la classe, avant
-- onCombatStart : le premier tic part au début du premier tour).
if ns.Cards.echo_of_light then
  ns.Cards.echo_of_light.whileInDeck = function(c)
    if Priest.ECHO_START > 0 then Combat.applyStatus(c, c.player, "regen", Priest.ECHO_START) end
  end
end


---------------------------------------------------------------------------
-- Bots (Sim/) : valeur propre et clé d'état selon l'épique
---------------------------------------------------------------------------
-- Part des cartes du combat qui vérifient pred (main, pioche, défausse, recharges).
local function share(c, pred)
  local n, k = 0, 0
  local function scan(list)
    for i = 1, #list do
      local inst = list[i].card or list[i]
      n = n + 1
      if pred(ns.Card.def(inst)) then k = k + 1 end
    end
  end
  scan(c.hand); scan(c.draw); scan(c.discard); scan(c.cooldown)
  return n > 0 and k / n or 0
end

local function shadowHitter(d)
  if d.school ~= "shadow" then return false end
  for i = 1, #(d.effects or {}) do if d.effects[i][1] == "damage" then return true end end
  return false
end

local function alive(c)
  local n = 0
  for i = 1, #c.enemies do if not c.enemies[i].dead then n = n + 1 end end
  return n
end

-- Valeur ajoutée à l'évaluation des bots (unités de Bots.W : 10 = 1 PV, 4 = 1 PV ennemi).
-- Plusieurs épiques en jeu : la somme de leurs valeurs.
local epicValue
function Priest.botValue(c, W)
  local e, more, k, v = c.epic, c.moreEpics, 0, 0
  while e do
    if ns.Cards[e.id] and ns.Cards[e.id].class == "priest" then v = v + epicValue(c, W, e.id, e.up) end
    k = k + 1
    e = more and more[k]
  end
  return v
end
-- Valeur d'une épique en jeu (id, up) pour les bots.
epicValue = function(c, W, id, up)
  local p = c.player
  local r = p.st.regen or 0
  if id == "echo_of_light" and r > 0 then
    -- la Regen ne soigne plus (l'évaluation commune la compte en soin) : elle frappe tout le monde
    local healV = math.min(r * (r + 1) / 2, p.maxHp - p.hp) * W.hp * W.regen
    local dmg = r * (r + 1) / 2 + Priest.tier(Priest.ECHO_PLUS, up) * r
    return dmg * alive(c) * W.enemyHp * 0.7 - healV
  elseif id == "prayer_of_mending" and r > 0 then
    local heal = math.min(r * (r + 1) / 2, p.maxHp - p.hp)
    return heal * W.enemyHp * 0.7
  elseif id == "voidform" then
    -- chaque point d'Insanity grandit les coups Shadow à venir (environ 3 tours de 3,5 cartes)
    local hits = 3 * 3.5 * share(c, shadowHitter)
    return ((p.res or 0) * Priest.tier(Priest.VOID_BONUS, up) + Priest.tier(Priest.VOID_FLAT, up)) * hits * W.enemyHp
  elseif id == "inner_focus" and p.cast and c.cls.focus == p.cast.card.uid and ns.Bots then
    return ns.Bots.castValue(c) * (Priest.tier(Priest.FOCUS_SCALE, up) - 1)
  end
  return 0
end

function Priest.botKey(c)
  local cls = c.cls
  return (cls.focusRound == c.round and "f" or "") .. tostring(cls.focus or "") .. ":"
    .. tostring(c.turn.bySchool.shadow or 0)
end

ns.ClassRules.priest = {
  botValue = Priest.botValue,
  botKey = Priest.botKey,
}
