-- Règles de la zone Duskwood (`duskwood`) : la Curse (fiche docs/zones/duskwood.md, § 2 ; décisions :
-- docs/zones/decisions.md), sur le socle ns.ZoneRules (contrat et crochets : docs/zones.md).
--
-- Une Curse est une carte ennemie (Data/Zones/Duskwood.lua : token, curse = true) posée dans les piles du
-- joueur par un ennemi, son lanceur (inst.src = uid, lift = true : levée, c'est-à-dire épuisée, à sa mort,
-- d'office dans Combat.kill). Deux façons d'en recevoir :
--   * Bite : drapeau `curse = id` d'une attaque ; si l'action a fait perdre des PV (total > 0, Absorb et
--     Parry l'empêchent), la Curse va dans la défausse (crochet afterEnemyAttack, une fois par action) ;
--   * Hex : action `{ "curse", id, n, to }`, sans condition (défausse, dessus de la pioche, main ; main pleine :
--     défausse) ; portée par une incantation, elle s'interrompt.
-- Plafond : 6 Curses dans les piles et la main réunies (DW.CAP) ; au-delà, rien (journal « curse_full »).
-- S'en débarrasser : la jouer (coût en mana ou en PV, épuisée), tuer son lanceur, « Remove negative effects. »
-- (crochet cleanse : les Curses de la MAIN sont épuisées et comptées comme effets retirés).
-- Effets : « End of turn » (champ endOfTurn, moteur : perte de PV sans Absorb, why = "curse", peut tuer) ;
-- « In hand » : crochets damage (Curse of Weakness : -3 par coup des Attacks, 0 au moins), drawPerTurn (Web :
-- une carte de moins), cost (Curse of Tongues : +1 à la première carte jouée du tour, pas sur elle-même).
-- Boss : Unholy Shield (dégâts subis divisés par 2, sans durée) retiré par Morbent's Bane, carte donnée en
-- main au début du combat (champ d'ennemi `gift`).
-- Commun de la zone 2 : l'affiche WANTED (case de parcours « night_watch_poster », effet de rencontre « wanted »).
local _, ns = ...

local Combat, Card, ZR, X = ns.Combat, ns.Card, ns.ZoneRule, ns.Expedition
local L = ns.Language
local floor, max = math.floor, math.max

local DW = {}
ns.Duskwood = DW

DW.CAP = 6 -- Curses au plus dans les piles et la main réunies

local function isCurse(inst, d) return (d or Card.def(inst)).curse == true end
DW.isCurse = isCurse

-- Curses du combat (main, pioche, défausse, recharges) ; src = uid du lanceur, id = sorte (facultatifs).
-- (sans closure : appelé dans les chemins chauds de la simulation, où une closure arrête la compilation LuaJIT)
local function countIn(list, src, id, n)
  for i = 1, #list do
    local inst = list[i]
    if Card.def(inst).curse == true and (src == nil or inst.src == src) and (id == nil or inst.id == id) then
      n = n + 1
    end
  end
  return n
end

function DW.count(c, src, id)
  local n = countIn(c.hand, src, id, 0)
  n = countIn(c.draw, src, id, n)
  n = countIn(c.discard, src, id, n)
  local cd = c.cooldown
  for i = 1, #cd do
    local inst = cd[i].card
    if Card.def(inst).curse == true and (src == nil or inst.src == src) and (id == nil or inst.id == id) then
      n = n + 1
    end
  end
  return n
end

-- Curses de cette sorte dans la main.
function DW.inHand(c, id)
  local n = 0
  local hand = c.hand
  for i = 1, #hand do if hand[i].id == id then n = n + 1 end end
  return n
end

-- Valeur « In hand » portée par les Curses de la main (champ de la définition : weakness, drawLess, tongues).
local function handSum(c, field)
  local n = 0
  local hand = c.hand
  for i = 1, #hand do
    local d = Card.def(hand[i])
    if d.curse and d[field] then n = n + d[field] end
  end
  return n
end
DW.handSum = handSum

-- Pose la Curse id venue de l'ennemi e (nil : sans lanceur) dans la pile `to` (défaut : défausse). Plafond,
-- puis crochet « preventCurse » (c, src, v = false, id, e) : vrai l'empêche (Ghoul Rib). Renvoie l'instance.
function DW.add(c, id, e, to)
  if c.result then return nil end
  if DW.count(c) >= DW.CAP then
    Combat.log(c, { t = "curse_full", id = id, src = e and e.uid })
    ZR.float(c, "player", "Curses full", "watchText")
    Combat.zstat(c, "curseFull", 1)
    return nil
  end
  if Combat.modify(c, "preventCurse", false, id, e) then
    Combat.log(c, { t = "curse_prevented", id = id, src = e and e.uid })
    Combat.zstat(c, "cursePrevented", 1)
    return nil
  end
  local inst = Combat.addCard(c, id, to or "discard", { src = e and e.uid, lift = e ~= nil })
  Combat.zstat(c, "cursesAdded", 1)
  return inst
end

---------------------------------------------------------------------------
-- États, actions d'ennemis, effets de carte
---------------------------------------------------------------------------

ns.Statuses.unholy_shield = { name = "Unholy Shield", flag = true,
  text = "Takes half damage. Morbent's Bane removes it." }

-- { "curse", id, n = 1, to = "discard" | "draw" | "hand" } : Hex, sans condition.
Combat.ENEMY_ACTIONS.curse = function(c, e, a)
  for _ = 1, (a.n or 1) do
    DW.add(c, a[2], e, a.to)
    if c.result then return end
  end
end

-- { "gorge", k } (Stitches) : Strength k par Fevered Plague posée par lui encore en jeu.
Combat.ENEMY_ACTIONS.gorge = function(c, e, a)
  local n = DW.count(c, e.uid, "fevered_plague")
  if n > 0 then Combat.applyStatus(c, e, "force", n * (a[2] or 1)) end
end

-- { "removeUnholyShield" } (Morbent's Bane) : retire Unholy Shield de la cible.
ns.Effects.removeUnholyShield = function(c, ctx, e)
  local t = ctx.target
  if t and not t.dead and (t.st.unholy_shield or 0) > 0 then
    Combat.applyStatus(c, t, "unholy_shield", -1)
    Combat.zstat(c, "shieldRemoved", 1)
  end
end

---------------------------------------------------------------------------
-- Langage
---------------------------------------------------------------------------

L.zoneKeyword("duskwood", "curse", { name = "Curse", text = "enemy card for this combat, exhausted when played." })
L.zoneKeyword("duskwood", "unplayable", { name = "Unplayable", text = "can't be played." })
L.trigger("In hand")

---------------------------------------------------------------------------
-- Règle de la zone
---------------------------------------------------------------------------

ZR.define("duskwood", {
  init = function(c, z) end,
  hooks = {
    -- carte donnée par un ennemi au début du combat (Morbent's Bane), en main
    onCombatStart = function(c, z)
      for _, e in ipairs(c.enemies) do
        local gift = ns.Enemies[e.id].gift
        if gift and not e.dead then Combat.addCard(c, gift, "hand", { src = e.uid }) end
      end
    end,
    -- Bite : une Curse en défausse si l'attaque a fait perdre des PV (lanceur encore vivant)
    afterEnemyAttack = function(c, z, e, a, total)
      if a.curse and total > 0 and not e.dead then DW.add(c, a.curse, e, a.to or "discard") end
    end,
    -- In hand : Curse of Weakness (Attacks, par coup, 0 au moins)
    damage = function(c, z, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" then
        local n = handSum(c, "weakness")
        if n > 0 then return max(0, v - n) end
      end
      return v
    end,
    -- In hand : Web (une carte de moins à la pioche du tour)
    drawPerTurn = function(c, z, v)
      local n = handSum(c, "drawLess")
      if n > 0 then return max(0, v - n) end
      return v
    end,
    -- In hand : Curse of Tongues (première carte jouée du tour, pas sur elle-même)
    cost = function(c, z, v, d, inst)
      if v and c.turn and c.turn.played == 0 and c.phase == "player" and not (d and d.tongues) then
        local n = handSum(c, "tongues")
        if n > 0 then return v + n end
      end
      return v
    end,
    -- « Remove negative effects. » : les Curses de la main sont épuisées, comptées comme effets retirés
    cleanse = function(c, z, n, unit)
      if unit ~= c.player then return n end
      local list = {}
      for _, inst in ipairs(c.hand) do if isCurse(inst) then list[#list + 1] = inst end end
      for i = 1, #list do Combat.removeCard(c, list[i], "cleansed") end
      if #list > 0 then
        Combat.zstat(c, "cursesCleansed", #list)
        ZR.float(c, "player", #list .. " cleansed", "healText")
      end
      return n + #list
    end,
    -- Morbent Fel : Unholy Shield (dégâts subis divisés par 2, avant l'Absorb)
    enemyDamageTaken = function(c, z, v, e, src)
      if (e.st.unholy_shield or 0) > 0 and v > 0 then return floor(v / 2) end
      return v
    end,
    -- statistiques : Curses jouées (mana), levées ; PV perdus par les Curses (fin de tour, Pay N HP)
    onCardCommitted = function(c, z, inst, d)
      if d.curse then
        Combat.zstat(c, "cursesPlayed", 1)
        Combat.zstat(c, "curseMana", d.cost or 0)
      end
    end,
    onExhaust = function(c, z, inst, why)
      if why == "lifted" and isCurse(inst) then Combat.zstat(c, "cursesLifted", 1) end
    end,
    onHpLost = function(c, z, n, why)
      if why == "curse" then Combat.zstat(c, "curseHp", n) end
    end,
    onPayHp = function(c, z, n, inst)
      if inst and isCurse(inst) then Combat.zstat(c, "curseHp", n) end
    end,
  },
  run = {
    -- affiche WANTED : la prochaine élite du chemin est celle de l'affiche ; +50 po à la récompense
    onFightStart = function(exp, fight, opts)
      local zs = exp.zs and exp.zs.duskwood
      local w = zs and zs.wanted
      if not (w and fight.kind == "elite" and fight.pool == "elite") then return end
      local list = ns.Encounters[X.zoneDef(exp).encounters].elite
      local group = list[w.idx] or list[1]
      opts.encounter = group
      fight.encounter = X.groupIds(group)
      fight.wanted = true
      fight.reward.gold = (fight.reward.gold or 0) + DW.WANTED_GOLD
      fight.reward.wanted = true
      zs.wanted = nil
    end,
    -- élite de l'affiche battue : une carte améliorée au hasard
    onCombatWon = function(exp, kind, fight)
      if fight and fight.wanted then
        X.upgradeRandom(exp, 1, exp.rng.loot)
        exp.stats.wanted = (exp.stats.wanted or 0) + 1
      end
    end,
  },
})

---------------------------------------------------------------------------
-- Affiche WANTED (commun de la zone 2) : case de parcours et effet de rencontre
---------------------------------------------------------------------------
DW.WANTED_GOLD = 50

-- { "wanted" } : l'élite est tirée à l'entrée de la rencontre (nom dans le texte, « %s ») ; la réponse
-- la pose sur la prochaine élite du chemin (exp.zs.duskwood.wanted).
X.EFFECTS.wanted = {
  roll = function(exp, rng, e)
    local pools = ns.Encounters[X.zoneDef(exp).encounters]
    local list = pools and pools.elite
    if not list or #list == 0 then return nil end
    local idx = ns.Rng.int(rng, 1, #list)
    local names = {}
    for i, spec in ipairs(list[idx]) do names[i] = ns.Enemies[Combat.specId(spec)].name end
    return { group = { pool = "elite", idx = idx, names = names } }
  end,
  apply = function(exp, e, roll)
    if not roll or not roll.group then return end
    X.zoneState(exp, "duskwood").wanted = { idx = roll.group.idx, name = roll.group.names[1] }
  end,
}

X.nodeKind("night_watch_poster", { name = "Wanted Poster", tier = 2, zone = "duskwood", event = "night_watch_poster",
  replaces = { "event" }, minFloor = 2, maxFloor = 5 })
