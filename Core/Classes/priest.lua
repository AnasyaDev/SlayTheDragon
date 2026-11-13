-- Règles propres du Prêtre : ses sept cartes épiques (docs/zones/cartes-de-zone.md, « Priest » ; contrat :
-- docs/classes.md, « Cartes épiques »). Le reste du Prêtre (Insanity, Atonement, Regen, Cast) est le socle
-- commun du moteur.
--
-- Une épique est une règle active tout le combat : ses crochets sont des deckHooks (src = { id, up, uid },
-- actifs où que soit la carte), posés ici sur les définitions de Data/Priest.lua. Amélioration : src.up.
--   prayer_of_mending : onHeal → PV rendus (+2) à un ennemi vivant tiré par c.rng.cards (coup sans carte).
--   misery            : un DoT posé par une carte sur SA cible (pas « to all ») est copié sur chaque autre
--                       ennemi vivant (+1), par Combat.applyStatus (sans le crochet apply, sans boucle).
--   echo_of_light     : regenHeal → 0 ; onRegenTick → la valeur (+2) à chaque ennemi vivant (sans carte).
--   shadow_covenant   : cost → 0 pour une carte Shadow de coût final N ≥ 1, payHp → + 2N ; amélioré : la
--                       première carte Shadow du tour ne coûte rien.
--   reflective_shield : afterHit → l'Absorb perdue sur ce coup, au plus 4 (7), à l'attaquant (sans carte).
--   voidform          : canPlay → les cartes à Surge sont injouables ; damage → + Insanity / 3 (/ 2) par coup
--                       d'une carte Shadow.
--   inner_focus       : castAs → la première carte Attack ou Skill du tour part en Cast ; à sa résolution,
--                       dégâts, Absorb, soin, DoT et Regen × 1,5 (× 2), arrondis au supérieur.
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
for _, label in ipairs({ "Each heal", "Each Regen tick", "Shadow cards", "Per 3 Insanity", "Per 2 Insanity", "Per Insanity",
  "First card each turn" }) do
  L.trigger(label)
end
L.keyword("prayerOfMending", { name = "Each heal", pattern = "^Each heal:",
  text = "every source, Regen ticks too, real HP only." })
L.keyword("echoOfLight", { name = "Regen tick", pattern = "^Each Regen tick:",
  text = "start of turn, Spirit of Redemption's too." })
L.keyword("shadowCovenant", { name = "Shadow cards", pattern = "^Shadow cards: pay",
  text = "a card costing N mana costs 0 and pays 2N HP." })
L.keyword("voidform", { name = "Voidform", pattern = "^Surge cards can't be played",
  text = "Insanity is never spent, Shadow hits grow." })
L.keyword("innerFocus", { name = "First card", pattern = "^First card each turn:",
  text = "the first Attack or Skill, resolves next turn." })

---------------------------------------------------------------------------
-- Aides
---------------------------------------------------------------------------
Priest.EPICS = { "prayer_of_mending", "misery", "echo_of_light", "shadow_covenant", "reflective_shield",
  "voidform", "inner_focus" }

-- Réglages (nombres de la fiche, à régler par la simulation : docs/zones/cartes-de-zone.md).
Priest.MENDING_UP = 2        -- Prayer of Mending amélioré : + 2 par soin
Priest.MISERY_UP = 1         -- Misery amélioré : + 1 par copie
Priest.ECHO_PLUS = { 5, 7 }  -- Echo of Light : + N par tic (base, amélioré)
Priest.COVENANT_HP = 3       -- Shadow Covenant : PV par point de mana
Priest.REFLECT_CAP = { 4, 7 }  -- Reflective Shield : Absorb perdue renvoyée, au plus N par coup (base, amélioré)
Priest.VOID_PER = { 1, 1 }   -- Voidform : + 1 par tranche de N Insanity (base, amélioré)
Priest.FOCUS_SCALE = { 1.75, 2 } -- Inner Focus : facteur (base, amélioré)
Priest.VOIDFORM_REASON = "Voidform: Surge cards can't be played."

-- Épique du Prêtre active dans ce combat : id, amélioration (nil sans épique).
function Priest.epicOf(c)
  local ps = c.passives
  if not ps then return nil end
  for i = 1, #ps do
    local d = ns.Cards[ps[i].id]
    if d and d.rarity == "epic" and d.class == "priest" then return ps[i].id, ps[i].up end
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
    strike(c, e, n + (src.up and Priest.MENDING_UP or 0))
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
    local v = n + (src.up and Priest.MISERY_UP or 0)
    for i = 1, #c.enemies do
      local o = c.enemies[i]
      if o ~= unit and not o.dead then Combat.applyStatus(c, o, "pain", v) end
    end
    cls.miseryBusy = nil
  end,
}

H.echo_of_light = {
  regenHeal = function() return 0 end,
  onRegenTick = function(c, src, n)
    local v = n + Priest.ECHO_PLUS[src.up and 2 or 1]
    for i = 1, #c.enemies do
      if c.result then return end
      strike(c, c.enemies[i], v)
    end
  end,
}

local function covenantFree(c, src)
  return src.up and (c.turn.bySchool.shadow or 0) == 0
end

H.shadow_covenant = {
  cost = function(c, src, v, d)
    if c.cls.peek or not v or d.school ~= "shadow" then return v end
    if v >= 1 then return 0 end
    return v
  end,
  -- coût final en mana (autres Powers et bibelots compris) relu sans la conversion : PV = 2 par point
  payHp = function(c, src, v, d, inst)
    if d.school ~= "shadow" or not d.cost or c.player.flags.freeTurnActive then return v end
    if covenantFree(c, src) then return v end
    c.cls.peek = true
    local n = math.max(0, Combat.modify(c, "cost", d.cost, d, inst))
    c.cls.peek = nil
    if n >= 1 then return v + Priest.COVENANT_HP * n end
    return v
  end,
}

H.reflective_shield = {
  afterHit = function(c, src, e, loss, absorbed)
    if not absorbed or absorbed <= 0 then return end
    strike(c, e, math.min(absorbed, Priest.REFLECT_CAP[src.up and 2 or 1]))
  end,
}

H.voidform = {
  canPlay = function(c, src, v, d)
    if v == true and hasSurge(d) then return Priest.VOIDFORM_REASON end
    return v
  end,
  damage = function(c, src, v, dst, d)
    if d and d.school == "shadow" then
      return v + floor((c.player.res or 0) / Priest.VOID_PER[src.up and 2 or 1])
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
      c.cls.scale = Priest.FOCUS_SCALE[src.up and 2 or 1]
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
function Priest.botValue(c, W)
  local id, up = Priest.epicOf(c)
  if not id then return 0 end
  local p = c.player
  local r = p.st.regen or 0
  if id == "echo_of_light" and r > 0 then
    -- la Regen ne soigne plus (l'évaluation commune la compte en soin) : elle frappe tout le monde
    local healV = math.min(r * (r + 1) / 2, p.maxHp - p.hp) * W.hp * W.regen
    local dmg = r * (r + 1) / 2 + Priest.ECHO_PLUS[up and 2 or 1] * r
    return dmg * alive(c) * W.enemyHp * 0.7 - healV
  elseif id == "prayer_of_mending" and r > 0 then
    local heal = math.min(r * (r + 1) / 2, p.maxHp - p.hp)
    return heal * W.enemyHp * 0.7
  elseif id == "voidform" then
    -- chaque point d'Insanity grandit les coups Shadow à venir (environ 3 tours de 3,5 cartes)
    local hits = 3 * 3.5 * share(c, shadowHitter)
    return (p.res or 0) / Priest.VOID_PER[up and 2 or 1] * hits * W.enemyHp
  elseif id == "inner_focus" and p.cast and c.cls.focus == p.cast.card.uid and ns.Bots then
    return ns.Bots.castValue(c) * (Priest.FOCUS_SCALE[up and 2 or 1] - 1)
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
