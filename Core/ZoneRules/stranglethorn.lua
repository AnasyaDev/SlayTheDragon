-- Règles de la zone Stranglethorn Vale (`stranglethorn`) : le Hex (fiche docs/zones/stranglethorn.md, § 2 ;
-- décisions : docs/zones/decisions.md ; contrat des crochets : docs/zones.md).
--
-- Règle codée :
--   1. Un Hex est une incantation ennemie (move cast = true, action { "hex" }) : annoncée au début du tour
--      du joueur, résolue au tour du lanceur ; un Interrupt l'annule (moteur commun).
--   2. Carte visée : la plus chère des cartes encore en main (Combat.cost, égalité : la plus à gauche) ;
--      jamais une carte Hexed. Deux Hex visent deux cartes différentes, dans l'ordre d'action.
--   3. Verrouillage (crochet onHandEnd : après onTurnEnd et le familier, avant la défausse) : chaque lanceur
--      vivant, non interrompu, non étourdi verrouille sa carte (z.locks[uid de l'ennemi] = uid de la carte).
--      Main vide : « The hex finds no card. ».
--   4. Résolution (action « hex » au tour du lanceur) : la carte verrouillée, retrouvée dans la main ou la
--      défausse, est remplacée sur place par une carte Hexed (Combat.transformCard) ; sinon le Hex échoue.
--      Un lanceur mort avant son tour (DoT) perd son Hex (verrous effacés à la fin de la phase ennemie).
--   5. Hexed (Data/Zones/Stranglethorn.lua) : coût 1, Skill, rend la carte d'origine en main et disparaît.
--   6. Hex immédiat (action « hex_now », Death Hex du Zanzil Naga : tué pendant le tour du joueur) : la plus
--      chère des cartes en main, sans verrouillage ni incantation.
local _, ns = ...

local Combat, ZR, Card = ns.Combat, ns.ZoneRule, ns.Card
local X = ns.Expedition
local L = ns.Language

local ID = "stranglethorn"
local ST = {}
ns.Stranglethorn = ST

ST.HEXED = "hexed" -- carte de combat posée par un Hex

---------------------------------------------------------------------------
-- Aides (aussi lues par l'interface et les bots)
---------------------------------------------------------------------------

-- Le move m (définition) est-il un Hex (incantation qui porte l'action « hex ») ?
local function hexMove(mv)
  if not mv or not mv.cast then return false end
  for i = 1, #mv.actions do
    if mv.actions[i][1] == "hex" then return true end
  end
  return false
end
ST.hexMove = hexMove

-- L'ennemi e annonce-t-il un Hex encore valable (vivant, non interrompu, non étourdi) ?
function ST.hexing(c, e)
  if e.dead or e.interrupted or (e.st.stunned or 0) > 0 then return false end
  return hexMove(ns.Enemies[e.id].moves[e.intent])
end

-- Index de la carte que viserait un Hex : la plus chère de la main (coût actuel), la plus à gauche à
-- égalité ; excluded = { [uid] = true } (cartes déjà visées) ; jamais une carte Hexed. nil si aucune.
function ST.hexTarget(c, excluded)
  local best, bi
  for i = 1, #c.hand do
    local inst = c.hand[i]
    if inst.id ~= ST.HEXED and not (excluded and excluded[inst.uid]) then
      local v = Combat.cost(c, inst)
      if not best or v > best then best, bi = v, i end
    end
  end
  return bi
end

-- Cartes que viseraient les Hex annoncés si le tour finissait maintenant : liste ordonnée
-- { { enemy = e, index = i | nil } } (dans l'ordre d'action ; index nil = main vide).
function ST.plan(c)
  local out, taken = {}, {}
  for k = 1, #c.enemies do
    local e = c.enemies[k]
    if ST.hexing(c, e) then
      local i = ST.hexTarget(c, taken)
      if i then taken[c.hand[i].uid] = true end
      out[#out + 1] = { enemy = e, index = i }
    end
  end
  return out
end

-- Cartes Hexed du combat (main, pioche, défausse, recharges).
-- (sans closure : appelé par l'intention des ennemis, chemin chaud de la simulation)
local function hexedIn(list, n)
  local id = ST.HEXED
  for i = 1, #list do if list[i].id == id then n = n + 1 end end
  return n
end

function ST.hexedCount(c)
  local n = hexedIn(c.discard, hexedIn(c.draw, hexedIn(c.hand, 0)))
  local cd, id = c.cooldown, ST.HEXED
  for i = 1, #cd do if cd[i].card.id == id then n = n + 1 end end
  return n
end

-- Remplace inst (main ou défausse) par une carte Hexed posée par e ; renvoie la nouvelle instance.
local function hexCard(c, e, inst)
  local z = c.zs and c.zs[ID]
  local n = Combat.transformCard(c, inst, ST.HEXED, { src = e and e.uid or nil })
  if not n then return nil end
  Combat.log(c, { t = "hex", unit = e and e.uid, card = inst.uid, id = inst.id, into = n.uid })
  ZR.float(c, "player", "Hexed: " .. Card.def(inst).name, "watchText")
  Combat.zstat(c, "hexLanded")
  if z then z.landed = (z.landed or 0) + 1 end
  return n
end

local function fizzle(c, e, why)
  Combat.log(c, { t = "hex_fizzle", unit = e and e.uid, why = why })
  if e then ZR.float(c, e.uid, why == "empty" and "No card" or "Hex fails", "defendText") end
  Combat.zstat(c, why == "empty" and "hexEmpty" or "hexFizzled")
end

-- Hex immédiat (Death Hex, action « hex_now ») : la plus chère des cartes en main. Renvoie l'instance
-- Hexed ou nil (main vide).
function ST.hexNow(c, e)
  local i = ST.hexTarget(c)
  if not i then
    fizzle(c, e, "empty")
    return nil
  end
  return hexCard(c, e, c.hand[i])
end

---------------------------------------------------------------------------
-- Actions et montants d'ennemis
---------------------------------------------------------------------------

-- { "hex", summon = id } : résout le Hex verrouillé par ce lanceur ; summon : invocation si une carte est
-- frappée (Zanzil the Outcast lève un zombie).
Combat.ENEMY_ACTIONS.hex = function(c, e, a)
  local z = c.zs and c.zs[ID]
  if not z then return end -- hors de la zone : un Hex sans règle ne fait rien
  local uid = z.locks[e.uid]
  z.locks[e.uid] = nil
  if uid == nil then return end -- verrouillage manqué (déjà journalisé) ou lanceur arrivé ce tour
  local inst
  for _, key in ipairs({ "hand", "discard" }) do
    for _, x in ipairs(c[key]) do if x.uid == uid then inst = x end end
  end
  if not inst then
    fizzle(c, e, "gone")
    return
  end
  local n = hexCard(c, e, inst)
  if n and a.summon then Combat.spawn(c, a.summon, e) end
end

-- { "hex_now" } : Hex immédiat, sans incantation.
Combat.ENEMY_ACTIONS.hex_now = function(c, e, a)
  if not (c.zs and c.zs[ID]) then return end
  ST.hexNow(c, e)
end

-- Montant « hexed » : cartes Hexed du joueur (Take a Trophy : per = { 3, "hexed" }).
Combat.ENEMY_AMOUNTS.hexed = function(c) return ST.hexedCount(c) end

---------------------------------------------------------------------------
-- Règle de la zone
---------------------------------------------------------------------------

ZR.define(ID, {
  init = function(c, z)
    z.locks = {}
  end,
  hooks = {
    onEnemyCastStart = function(c, z, e, move)
      if hexMove(ns.Enemies[e.id].moves[move]) then Combat.zstat(c, "hexAnnounced") end
    end,
    onEnemyCastInterrupted = function(c, z, e, move)
      if hexMove(ns.Enemies[e.id].moves[move]) then Combat.zstat(c, "hexInterrupted") end
    end,
    onEnemyStunned = function(c, z, e)
      if hexMove(ns.Enemies[e.id].moves[e.intent]) then Combat.zstat(c, "hexStunned") end
    end,
    -- verrouillage : main encore entière, avant la défausse
    onHandEnd = function(c, z)
      z.locks = {}
      for _, p in ipairs(ST.plan(c)) do
        local e = p.enemy
        if p.index then
          local inst = c.hand[p.index]
          z.locks[e.uid] = inst.uid
          Combat.log(c, { t = "hex_lock", unit = e.uid, card = inst.uid, id = inst.id })
        else
          fizzle(c, e, "empty")
        end
      end
    end,
    -- verrous non résolus (lanceur mort de son DoT, tour ennemi sauté) : perdus
    onEnemyPhaseEnd = function(c, z)
      for uid in pairs(z.locks) do
        local e = Combat.enemyByUid(c, uid)
        if e then Combat.zstat(c, "hexLost") end
      end
      z.locks = {}
    end,
    onTurnStart = function(c, z)
      z.locks = {}
    end,
    -- Death Hex : tué pendant le tour du joueur (carte, familier en fin de tour), ni par une Trap ni par
    -- un DoT, ni par un Cast résolu au début du tour (main encore vide)
    onEnemyDeath = function(c, z, e, info)
      local def = ns.Enemies[e.id]
      if def.deathHex and (c.step == "play" or c.step == "turnEnd") and info.kind ~= "trap" and info.kind ~= "dot" then
        Combat.zstat(c, "deathHex")
        ST.hexNow(c, e)
      end
    end,
    onCardPlayed = function(c, z, inst)
      if inst.id == ST.HEXED then Combat.zstat(c, "hexedPlayed") end
    end,
    onCombatEnd = function(c, z, result)
      local n = ST.hexedCount(c)
      if n > 0 then Combat.zstat(c, "hexedLeft", n) end
    end,
  },
})

---------------------------------------------------------------------------
-- Langage : mots expliqués au survol (60 caractères au plus)
---------------------------------------------------------------------------

L.zoneKeyword(ID, "hex", { name = "Hex", text = "enemy cast that hexes the costliest card left in hand." })
L.zoneKeyword(ID, "hexed", { name = "Hexed", text = "costs 1, play it to get the card back in hand." })

---------------------------------------------------------------------------
-- Gurubashi Arena : case de parcours commune à toutes les zones, débloquée par la première victoire du
-- compte dans Stranglethorn (tier 4) ; une au plus par expédition, à partir de l'étape 3, à la place d'une
-- rencontre. Rencontre `gurubashi_arena` (Data/Zones/Stranglethorn.lua).
---------------------------------------------------------------------------

X.nodeKind("gurubashi_arena", { name = "Gurubashi Arena", tier = 4, event = "gurubashi_arena",
  replaces = { "event" }, minFloor = 3, count = 1, chance = 1 })
