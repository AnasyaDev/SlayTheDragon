-- Règles de la zone Swamp of Sorrows (`swamp`) : Slumber (fiche docs/zones/swamp.md, § 2 ; décisions :
-- docs/zones/decisions.md ; contrat des crochets : docs/zones.md).
--
-- Asleep N (état d'ennemi) : à chacun de ses tours, au lieu d'agir, le dormeur perd 1 (Slumber : il se soigne
-- d'abord de `mend`) ; à 0 il se réveille sans agir. Tout dégât le réveille (même absorbé, pas un coup
-- mortel) ; le premier coup À UNE CIBLE (pas un tic de DoT) a +50 % (Rude Awakening, en dernier, avant son
-- Absorb). Au réveil, son ouverture (def.opener, ou celle posée par Slumber) devient son intention : jouée à
-- la phase ennemie de ce round s'il est réveillé par un coup à une cible pendant le tour du joueur, au round
-- suivant sinon (effet à tous ou DoT : réveil doux, SOFT_ALL ; compteur, Alarm). Stunned
-- sur un dormeur gèle son compteur ; sur une ouverture, la retarde sans la perdre.
--
-- Mise en œuvre : un dormeur a pour intention le move « asleep » (Swamp.SLEEP, ajouté à la définition de
-- l'ennemi au besoin : aucune action) et, en gris, son ouverture (e.mem.forced, « On waking ») ; le crochet
-- « intent » le maintient endormi tant que l'état dure, « enemyMove » saute son tour. État propre à l'unité :
-- e.zs.swamp = { opener (ouverture posée par Slumber), mend, lulled, pending (ouverture pas encore jouée),
-- stopped (ouverture arrêtée par Stunned), dream (phase de Slumber à appliquer après l'effet en cours) }.
-- Règles actives hors du marais (always) pour un combat qui peut endormir : carte qui pose Asleep (Dream
-- Dust), bibelot (Egg of Hakkar), groupe ou rencontre avec Asleep (Sleeping Camp).
local _, ns = ...

local Combat, ZR, L = ns.Combat, ns.ZoneRule, ns.Language
local ceil = math.ceil

local Swamp = {}
ns.Swamp = Swamp

Swamp.ID = "swamp"
Swamp.SLEEP = "asleep"          -- move d'un dormeur (intention « sleep »)
Swamp.BONUS = 1.5               -- Rude Awakening
Swamp.LULL_MIN_LOST = 8         -- Lull : PV perdus au moins par la cible
Swamp.SLEEP_RELICS = { egg_of_hakkar = true }
Swamp.SOFT_ALL = true           -- un effet à tous réveille en douceur (ouverture au round suivant)
Swamp.PET_WAITS = true          -- familier : aucune attaque automatique quand tous les ennemis dorment

ns.Statuses.asleep = { name = "Asleep", debuff = true, turns = true, max = 4,
  text = "Skips its next N turns. Damage wakes it up." }

L.zoneKeyword("swamp", "rude_awakening", { name = "Rude Awakening",
  text = "+50% from the first single-target hit." })
L.zoneKeyword("swamp", "opener", { name = "On waking", text = "its first move after it wakes up." })

local SLEEP_MOVE = { name = "Asleep", intent = "sleep", actions = {},
  text = "Skips its turn. Damage wakes it up." }
Swamp.SLEEP_MOVE = SLEEP_MOVE

local function def(e) return ns.Enemies[e.id] end

-- Le move « asleep » existe dans la définition de l'ennemi (Dream Dust peut endormir n'importe qui).
local function ensureMove(d)
  if not d.moves[Swamp.SLEEP] then d.moves[Swamp.SLEEP] = SLEEP_MOVE end
end
Swamp.ensureMove = ensureMove

local function us(e) return ZR.unitState(e, Swamp.ID) end
local function peek(e) return e.zs and e.zs.swamp end

function Swamp.asleep(e)
  return e ~= nil and not e.dead and (e.st.asleep or 0) > 0
end
local asleep = Swamp.asleep

-- Ouverture de l'ennemi : celle posée par Slumber, sinon celle de sa définition (nil : aucune).
function Swamp.opener(e)
  local s = peek(e)
  return (s and s.opener) or def(e).opener
end
local opener = Swamp.opener

-- L'ouverture est-elle encore à jouer (réveillé, pas encore joué) ?
function Swamp.pending(e)
  local s = peek(e)
  return s ~= nil and s.pending == true
end

local function stat(c, k, n) Combat.zstat(c, k, n) end

-- Annonce de l'ouverture en gris sous l'intention d'un dormeur.
local function announce(e)
  local op = opener(e)
  if op then
    e.mem.forced, e.mem.forcedLabel = op, "On waking"
  else
    e.mem.forced, e.mem.forcedLabel = nil, nil
  end
end

-- Réveil (cause : hit, all, dot, counter, alarm, effect). Pendant le tour du joueur (jeu, fin du tour) :
-- l'ouverture devient l'intention tout de suite (jouée dans la phase ennemie de ce round) ; sinon elle
-- sera la prochaine intention (l'ennemi n'agit plus dans la phase en cours : son intention reste « asleep »).
function Swamp.wake(c, e, cause)
  if not asleep(e) then return false end
  e.st.asleep = nil
  local s = us(e)
  Combat.log(c, { t = "wake", unit = e.uid, by = cause })
  ZR.float(c, e.uid, "Wakes up!", "attackText")
  stat(c, "wake_" .. (cause or "effect"))
  local op = opener(e)
  -- réveil « doux » (effet à tous, comme un DoT) : ouverture au round suivant, même pendant le tour du joueur
  local now = (c.step == "play" or c.step == "turnEnd") and not (Swamp.SOFT_ALL and cause == "all")
  e.mem.forced, e.mem.forcedLabel = nil, nil
  if op then
    s.pending = true
    if now then
      Combat.forceIntent(c, e, op, { now = true })
    else
      Combat.forceIntent(c, e, op, { now = false, label = "Next" })
    end
  elseif now then
    Combat.chooseIntent(c, e)
  end
  return true
end
local wake = Swamp.wake

-- Endort l'ennemi (Asleep n) : l'état passe par Combat.applyStatus (crochet onStatusApplied ci-dessous).
function Swamp.sleep(c, e, n)
  if e.dead or n <= 0 then return end
  Combat.applyStatus(c, e, "asleep", n)
end

-- Slumber : l'ennemi s'endort lui-même ; mend = soin à chacun de ses tours de sommeil ; opener = ouverture.
function Swamp.slumber(c, e, n, mend, op)
  local s = us(e)
  s.mend = mend
  if op then s.opener = op end
  Swamp.sleep(c, e, n)
end

-- Cause d'un réveil par un coup (source du coup : Combat.hitInfo).
local function causeOf(src)
  if src.kind == "dot" then return "dot" end
  if not src.single then return "all" end
  return "hit"
end

-- Phases de Slumber (Wyrmak, Somnus) : seuil franchi -> actions `dream` de la phase après l'effet en cours.
local function runDreams(c, ignoreActing)
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    local s = peek(e)
    if s and s.dream and not e.dead and (ignoreActing or c.acting ~= e.uid) then
      local k = s.dream
      s.dream = nil
      local ph = def(e).phases and def(e).phases[k]
      if ph and ph.dream then
        for j = 1, #ph.dream do
          Combat.enemyAction(c, e, ph.dream[j])
          if c.result or e.dead then break end
        end
      end
      if c.result then return end
    end
  end
end

-- Cible de Lull : l'allié éveillé le plus blessé (pas le lanceur, pas un boss, pas déjà rendormi, au moins
-- LULL_MIN_LOST PV perdus).
function Swamp.lullTarget(c, caster)
  local best, gap = nil, Swamp.LULL_MIN_LOST - 1
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if o ~= caster and not o.dead and not o.boss and not asleep(o) then
      local s = peek(o)
      local lost = o.maxHp - o.hp
      if not (s and s.lulled) and lost > gap then best, gap = o, lost end
    end
  end
  return best
end

-- Nombre d'alliés endormis (lui exclu).
function Swamp.asleepAllies(c, e)
  local n = 0
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if o ~= e and asleep(o) then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------
-- Actions, conditions et montants des ennemis
---------------------------------------------------------------------------

-- { "lull", n, heal = x } : à la résolution, endort (Asleep n) et soigne l'allié choisi.
Combat.ENEMY_ACTIONS.lull = function(c, e, a)
  local t = Swamp.lullTarget(c, e)
  if not t then
    stat(c, "lull_fizzle")
    return
  end
  us(t).lulled = true
  Swamp.sleep(c, t, a[2] or 2)
  Combat.heal(c, t, a.heal or 8)
  stat(c, "lull_cast")
end

-- { "alarm" } : réveille tous les alliés endormis.
Combat.ENEMY_ACTIONS.alarm = function(c, e)
  local n = 0
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if o ~= e and asleep(o) then
      wake(c, o, "alarm")
      n = n + 1
    end
  end
  stat(c, "alarm_cast")
  if n > 0 then stat(c, "alarm_woken", n) end
end

-- { "slumber", n, mend = x, opener = move } : l'ennemi s'endort lui-même.
Combat.ENEMY_ACTIONS.slumber = function(c, e, a)
  Combat.log(c, { t = "float", unit = e.uid, text = "Falls asleep", color = "defendText" })
  Swamp.slumber(c, e, a[2] or 2, a.mend, a.opener)
  stat(c, "slumber")
end

-- { "block_wounded", n } : Absorb à l'allié le plus blessé (dormeur compris, pas lui ; à défaut, lui-même).
Combat.ENEMY_ACTIONS.block_wounded = function(c, e, a)
  local best, gap = e, 0
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if o ~= e and not o.dead and o.maxHp - o.hp > gap then best, gap = o, o.maxHp - o.hp end
  end
  Combat.gainBlock(c, best, a[2])
end

Combat.ENEMY_AMOUNTS.asleepAllies = function(c, e) return Swamp.asleepAllies(c, e) end
Combat.ENEMY_CONDITIONS.asleepAlly = function(c, e) return Swamp.asleepAllies(c, e) > 0 end
Combat.ENEMY_CONDITIONS.lullTarget = function(c, e) return Swamp.lullTarget(c, e) ~= nil end

---------------------------------------------------------------------------
-- Règles actives hors du marais : combats qui peuvent endormir
---------------------------------------------------------------------------

local sleepCards
local function appliesAsleep(effects)
  for _, x in ipairs(effects or {}) do
    if x[1] == "apply" and x[2] == "asleep" then return true end
  end
  return false
end
function Swamp.sleepCards()
  if not sleepCards then
    sleepCards = {}
    for id, d in pairs(ns.Cards) do
      if d.sleeps or appliesAsleep(d.effects) or (d.up and appliesAsleep(d.up.effects))
          or (d.up2 and appliesAsleep(d.up2.effects)) or (d.up3 and appliesAsleep(d.up3.effects)) then
        sleepCards[id] = true
      end
    end
  end
  return sleepCards
end

function Swamp.needed(o)
  if not o then return false end
  local cards = Swamp.sleepCards()
  for _, card in ipairs(o.deck or {}) do
    if cards[card.id] then return true end
  end
  for _, r in ipairs(o.relics or {}) do
    if Swamp.SLEEP_RELICS[r] then return true end
  end
  if o.mods and o.mods.st and o.mods.st.asleep then return true end
  for _, spec in ipairs(o.encounter or {}) do
    if type(spec) == "table" and spec.st and spec.st.asleep then return true end
    local d = ns.Enemies[Combat.specId(spec)]
    if d and d.asleep then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Règles
---------------------------------------------------------------------------

ZR.define("swamp", {
  always = Swamp.needed,

  -- dormeurs de leur définition (asleep = N), sauf si le groupe leur en a déjà posé (st = { asleep = n })
  init = function(c, z)
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      local d = def(e)
      if d.asleep and not asleep(e) then Swamp.sleep(c, e, d.asleep) end
    end
  end,

  hooks = {
    -- un dormeur garde l'intention « asleep » et son ouverture en gris
    intent = function(c, z, move, e)
      if asleep(e) then
        ensureMove(def(e))
        announce(e)
        return Swamp.SLEEP
      end
      return move
    end,

    -- tour d'un dormeur : soin de Slumber, compteur -1, réveil à 0 ; réveillé pendant cette phase : rien
    enemyMove = function(c, z, move, e)
      if asleep(e) then
        local s = peek(e)
        if s and (s.mend or 0) > 0 then Combat.heal(c, e, s.mend) end
        if e.dead or c.result then return false end
        local n = e.st.asleep - 1
        stat(c, "sleep_turns")
        if n <= 0 then
          wake(c, e, "counter")
        else
          e.st.asleep = n
          ZR.float(c, e.uid, "Asleep " .. n, "defendText")
        end
        return false
      end
      if move == Swamp.SLEEP then return false end
      return move
    end,

    -- Asleep posé : l'ennemi perd son intention annoncée (sauf pendant son propre tour), son ouverture
    -- est annoncée ; Stunned posé pendant son ouverture : elle sera rejouée
    onStatusApplied = function(c, z, unit, id, n)
      if unit.side ~= "enemy" then return end
      if id == "asleep" and n > 0 and asleep(unit) then
        local d = def(unit)
        ensureMove(d)
        local s = us(unit)
        s.pending, s.stopped = nil, nil
        if opener(unit) then unit.mem.idx = nil end
        if unit.intent ~= Swamp.SLEEP and c.acting ~= unit.uid then
          unit.intent = Swamp.SLEEP
          unit.interrupted = false
          Combat.log(c, { t = "intent", unit = unit.uid, move = Swamp.SLEEP })
        end
        announce(unit)
      elseif id == "stunned" and c.phase == "enemy" and c.acting == unit.uid then
        local s = peek(unit)
        if s and s.pending and unit.intent == opener(unit) then s.stopped = true end
      end
    end,

    -- Stunned sur un dormeur : compteur gelé (le moteur ne passe pas par enemyMove). Sur une ouverture :
    -- elle reste annoncée pour le tour suivant.
    onEnemyStunned = function(c, z, e)
      if asleep(e) then
        stat(c, "sleep_stunned")
        return
      end
      local s = peek(e)
      local op = opener(e)
      if s and s.pending and op and e.intent == op then
        Combat.forceIntent(c, e, op, { now = false, label = "Next" })
        stat(c, "opener_delayed")
      end
    end,

    afterEnemyMove = function(c, z, e, move)
      local s = peek(e)
      if s and s.pending and move == opener(e) then
        if s.stopped then
          s.stopped = nil
          Combat.forceIntent(c, e, move, { now = false, label = "Next" })
          stat(c, "opener_delayed")
        else
          s.pending = nil
          stat(c, "opener")
        end
      end
      if s and s.dream then runDreams(c, true) end
    end,

    -- Rude Awakening : +50 % (arrondi au supérieur), coup à une cible, pas un tic de DoT
    enemyDamageLast = function(c, z, v, e, src)
      if v > 0 and asleep(e) and src.single and src.kind ~= "dot" then
        local nv = ceil(v * Swamp.BONUS)
        stat(c, "rude")
        stat(c, "rude_bonus", nv - v)
        return nv
      end
      return v
    end,

    -- tout dégât réveille (même absorbé) ; un coup mortel ne passe pas ici
    onEnemyDamaged = function(c, z, e, loss, absorbed, src)
      if asleep(e) then wake(c, e, causeOf(src)) end
    end,

    onEnemyDeath = function(c, z, e)
      if (e.st.asleep or 0) > 0 then
        stat(c, "killed_asleep")
      else
        local s = peek(e)
        if s and s.pending then stat(c, "killed_before_opener") end
      end
    end,

    -- seuil de Slumber franchi (Wyrmak, Somnus) : sommeil après l'effet en cours
    onEnemyPhase = function(c, z, e, k, ph)
      if ph.dream then us(e).dream = k end
    end,
    onEffectEnd = function(c, z) runDreams(c, false) end,
    onEnemyPhaseEnd = function(c, z) runDreams(c, true) end,

    onEnemyCastInterrupted = function(c, z, e, move)
      local mv = def(e).moves[move]
      local a = mv and mv.actions[1]
      if a and (a[1] == "lull" or a[1] == "alarm") then stat(c, a[1] .. "_interrupted") end
    end,

    -- Asleep par une carte (Dream Dust) : sans effet sur les élites et les boss
    apply = function(c, z, n, id, t)
      if id == "asleep" and t and (t.boss or def(t).elite) then return 0 end
      return n
    end,

    -- familier du Hunter : son attaque automatique (hors du jeu des cartes) évite les dormeurs tant qu'un
    -- ennemi est éveillé, et attend si tous dorment (PET_WAITS : le familier ne réveille jamais seul ; mesure
    -- du 14/11/2026 : sans cela Somnus se réveillait à la fin du tour 1 et le Hunter perdait 8 points de
    -- victoire) ; une attaque commandée par une carte frappe la cible de la carte, dormeur compris
    petTarget = function(c, z, t)
      if t and asleep(t) and c.step ~= "play" then
        for i = 1, #c.enemies do
          local o = c.enemies[i]
          if not o.dead and not asleep(o) then return o end
        end
        if Swamp.PET_WAITS then return nil end
      end
      return t
    end,
  },
})
