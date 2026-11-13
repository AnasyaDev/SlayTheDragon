-- Règles de la zone Burning Steppes (`steppes`) : Wildfire (fiche docs/zones/steppes.md, § 2 ; décisions :
-- docs/zones/decisions.md ; socle : docs/zones.md).
--
-- Wildfire est un compteur du champ de bataille, pas un état d'unité : z = c.zs.steppes =
--   { left = compte à rebours, max = plafond (T), blaze = brûlure, step = hausse, lit = déjà embrasé une fois }.
-- 1. T selon le genre du combat (ns.Encounters.steppes.wildfire), ou le plus petit champ `wildfire` des
--    ennemis de départ (Volchan 3, Grark 5). Blaze vaut 1 au premier embrasement.
-- 2. Fin de round (onRoundEnd, sauté si le tour ennemi l'a été) : compte >= 1 -> -1 (à 0 : « The ground
--    ignites! », sans dégâts) ; compte déjà à 0 -> perte de Blaze PV (Combat.loseHp, « wildfire » : ni
--    Absorb, ni Parry, ni Pain Suppression), puis Blaze + 2, puis notification « onWildfire » (n).
-- 3. Mort d'un ennemi qui n'est pas un serviteur, combat non fini : compte + 1 (plafond T).
-- 4. Stoke N (action ennemie) : -N au compte (minimum 0), chaque point qui ne peut pas être retiré ajoute 2
--    à Blaze. Ignite N (Grark) : compte à 0 tout de suite ; déjà à 0 : Blaze + N.
-- 5. Douse N (effet de carte) : compte + N (plafond T) ; hors des Steppes, rien.
-- Journal : { t = "counter", zone = "steppes", key = "left" | "blaze", n, d } (le jeton bat), textes flottants.
local _, ns = ...

local Combat, ZR = ns.Combat, ns.ZoneRule
local L = ns.Language
local min, max = math.min, math.max

local Wildfire = {}
ns.Wildfire = Wildfire

local DEFAULT = { normal = 4, elite = 5, boss = 5, blaze = 1, step = 2 }

-- Table de la zone (groupes de Data/Zones/Steppes.lua), valeurs par défaut sinon.
function Wildfire.config()
  local enc = ns.Encounters.steppes
  return enc and enc.wildfire or DEFAULT
end

-- État du Wildfire dans ce combat (nil hors des Steppes).
function Wildfire.state(c)
  return c.zs and c.zs.steppes or nil
end

-- Compte à rebours de départ d'un combat : genre, puis le plus petit `wildfire` des ennemis de départ.
function Wildfire.startCount(c)
  local cfg = Wildfire.config()
  local kind = c.kind == "elite" and "elite" or (c.kind == "boss" and "boss" or "normal")
  local t = cfg[kind] or DEFAULT[kind]
  local own
  for i = 1, #c.enemies do
    local d = ns.Enemies[c.enemies[i].id]
    if d and d.wildfire and (not own or d.wildfire < own) then own = d.wildfire end
  end
  return own or t
end

local function changed(c, z, key, d)
  if d ~= 0 then ZR.counterChanged(c, "steppes", key, z[key], d) end
end

-- Compte à rebours + n (plafond T) ; renvoie le gain réel.
function Wildfire.delay(c, n, why)
  local z = Wildfire.state(c)
  if not z or n <= 0 then return 0 end
  local before = z.left
  z.left = min(z.max, z.left + n)
  local d = z.left - before
  changed(c, z, "left", d)
  if d > 0 then
    Combat.zstat(c, why == "douse" and "roundsDoused" or "roundsByDeaths", d)
    if before == 0 then ZR.float(c, "player", "Wildfire held back", "defendText") end
  end
  return d
end

-- Stoke n : -n au compte ; chaque point au-delà de 0 ajoute step à Blaze.
function Wildfire.stoke(c, n, e)
  local z = Wildfire.state(c)
  if not z or n <= 0 then return end
  local take = min(z.left, n)
  local over = n - take
  if take > 0 then
    z.left = z.left - take
    changed(c, z, "left", -take)
  end
  if over > 0 then
    z.blaze = z.blaze + over * z.step
    changed(c, z, "blaze", over * z.step)
  end
  Combat.zstat(c, "stokes", 1)
  if e then ZR.float(c, e.uid, "Stoke " .. n, "attackText") end
end

-- Ignite n : sol embrasé tout de suite ; déjà embrasé : Blaze + n.
function Wildfire.ignite(c, n, e)
  local z = Wildfire.state(c)
  if not z then return end
  if z.left > 0 then
    local d = z.left
    z.left = 0
    changed(c, z, "left", -d)
    z.lit = true
    Combat.log(c, { t = "wildfire", left = 0, blaze = z.blaze, ignite = true })
    ZR.float(c, "player", "The ground ignites!", "attackText")
  elseif (n or 0) > 0 then
    z.blaze = z.blaze + n
    changed(c, z, "blaze", n)
  end
end

-- Fin de round : baisse, embrasement ou brûlure.
function Wildfire.roundEnd(c)
  local z = Wildfire.state(c)
  if not z or c.result then return end
  if z.left >= 1 then
    z.left = z.left - 1
    changed(c, z, "left", -1)
    if z.left == 0 then
      if not z.lit then Combat.zstat(c, "igniteRound", c.round) Combat.zstat(c, "ignited", 1) end
      z.lit = true
      Combat.log(c, { t = "wildfire", left = 0, blaze = z.blaze, ignite = true })
      ZR.float(c, "player", "The ground ignites!", "attackText")
    end
    return
  end
  local n = z.blaze
  Combat.log(c, { t = "wildfire", left = 0, blaze = n, loss = n })
  local lost = Combat.loseHp(c, n, "wildfire")
  Combat.zstat(c, "burnHp", lost)
  Combat.zstat(c, "burns", 1)
  if c.result then return end
  z.blaze = z.blaze + z.step
  changed(c, z, "blaze", z.step)
  Combat.zfire(c, "onWildfire", n)
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    local d = ns.Enemies[e.id]
    if not e.dead and d.onWildfire then d.onWildfire(c, e, n) end
  end
end

-- Prévision pour l'affichage et le bot : Stoke et Ignite annoncés par les intentions (ennemis vivants,
-- non étourdis, incantation non interrompue) -> compte et Blaze après le tour ennemi, avant la fin du round.
function Wildfire.forecast(c)
  local z = Wildfire.state(c)
  if not z then return nil end
  local left, blaze, stoke = z.left, z.blaze, 0
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    if not e.dead and e.intent and (e.st.stunned or 0) == 0 and not e.interrupted then
      local mv = ns.Enemies[e.id].moves[e.intent]
      for _, a in ipairs(mv and mv.actions or {}) do
        if a[1] == "stoke" then
          stoke = stoke + a[2]
          local take = min(left, a[2])
          left = left - take
          blaze = blaze + (a[2] - take) * z.step
        elseif a[1] == "ignite" then
          if left > 0 then left = 0 else blaze = blaze + (a[2] or 0) end
        end
      end
    end
  end
  -- burnNow : le compte vaut 0 au début de la fin de round (déjà embrasé, ou amené à 0 par un Stoke) : le
  -- joueur perd `blaze` PV à la fin de ce round
  return { left = left, blaze = blaze, stoke = stoke, burnNow = left == 0 }
end

---------------------------------------------------------------------------
-- Actions et conditions des ennemis, effet de carte
---------------------------------------------------------------------------

Combat.ENEMY_ACTIONS.stoke = function(c, e, a) Wildfire.stoke(c, a[2] or 1, e) end
Combat.ENEMY_ACTIONS.ignite = function(c, e, a) Wildfire.ignite(c, a[2] or 0, e) end

-- Le sol brûle (compte à 0) : bonus des attaques « lit ».
Combat.ENEMY_CONDITIONS.lit = function(c)
  local z = Wildfire.state(c)
  return z ~= nil and z.left == 0
end

-- { "douse", n } : Wildfire n rounds plus tard (plafond T) ; hors des Burning Steppes, rien.
ns.Effects.douse = function(c, ctx, e)
  if not ZR.active(c, "steppes") then return end
  Combat.zstat(c, "douses", 1)
  Wildfire.delay(c, e[2] or 1, "douse")
end

---------------------------------------------------------------------------
-- Langage : mots expliqués au survol (cartes, intentions, jeton)
---------------------------------------------------------------------------

L.zoneKeyword("steppes", "wildfire", { name = "Wildfire",
  text = "counts down, then burns you each round." })
L.zoneKeyword("steppes", "douse", { name = "Douse",
  text = "delays Wildfire by N rounds, Burning Steppes only." })
L.zoneKeyword("steppes", "stoke", { name = "Stoke",
  text = "Wildfire N rounds sooner, +2 burn per point if lit." })

---------------------------------------------------------------------------
-- Règle
---------------------------------------------------------------------------

ZR.define("steppes", {
  init = function(c, z)
    local cfg = Wildfire.config()
    local t = Wildfire.startCount(c)
    z.left, z.max, z.blaze, z.step, z.lit = t, t, cfg.blaze or 2, cfg.step or 2, false
  end,
  hooks = {
    onRoundEnd = function(c, z, skipped)
      if skipped then
        Combat.zstat(c, "skippedRounds", 1)
        return
      end
      Wildfire.roundEnd(c)
    end,
    onEnemyDeath = function(c, z, e, info)
      if c.result or info.minion then return end
      -- mort du dernier ennemi principal : le combat se termine avant la fin du round, rien ne change
      local last = true
      for i = 1, #c.enemies do
        local o = c.enemies[i]
        if not o.dead and not o.minion then last = false break end
      end
      if last then return end
      Wildfire.delay(c, 1, "death")
    end,
    onEnemyCastInterrupted = function(c, z, e, mv)
      local m = ns.Enemies[e.id].moves[mv]
      for _, a in ipairs(m and m.actions or {}) do
        if a[1] == "stoke" then Combat.zstat(c, "stokesInterrupted", 1) return end
      end
    end,
    onEnemyStunned = function(c, z, e)
      local m = ns.Enemies[e.id].moves[e.intent]
      for _, a in ipairs(m and m.actions or {}) do
        if a[1] == "stoke" then Combat.zstat(c, "stokesStunned", 1) return end
      end
    end,
  },
})
