-- Règles propres du Mage (fiche : docs/classes/mage.md ; contrat : docs/classes.md).
--   Charges (ressource « arcane », 0 à 4, gardées) : chaque charge ajoute 1 aux dégâts de chaque
--     coup d'une carte Attack (2 avec Arcane Power en jeu), comme Strength, avant Demoralized et
--     Sundered ; ni aux DoT, ni aux Skills, ni aux bibelots et potions. Vidées par Surge (effet commun).
--   Deux incantations à la fois (crochet castSlots) ; la file, l'ordre et l'interruption de la plus
--     récente sont dans le socle (Core/Combat.lua).
--   Frozen (condition) : la cible est Stunned ou Demoralized, testée coup par coup.
--   Ice Block (état) : aucun dégât de coup ennemi jusqu'au début du prochain tour (retiré à ce moment).
-- Pas d'état de classe (c.cls reste vide) : Instant est un état commun, le compte des cartes Fire du tour
-- est c.turn.bySchool.fire (socle).
local _, ns = ...

local Combat, Card = ns.Combat, ns.Card
local L = ns.Language

-- Frozen : Stunned ou Demoralized (les boss sont immunisés à Stunned, pas à Demoralized).
function Combat.isFrozen(unit)
  return unit ~= nil and not unit.dead and ((unit.st.stunned or 0) > 0 or (unit.st.demoralized or 0) > 0)
end

Combat.CONDITIONS.frozen = function(c, ctx, t) return Combat.isFrozen(t) end

ns.Statuses.ice_block = { name = "Ice Block", flag = true, clearAtTurnStart = true,
  text = "Takes no damage from attacks until the next turn." }

-- Libellés de déclencheur des Pouvoirs du Mage (« Fire hits: … », Hot Streak).
L.trigger("Fire hits")
L.trigger("2nd Fire card each turn")

-- Bonus par charge : 1, ou celui d'un Pouvoir en jeu qui le porte (Arcane Power : chargeBonus = 2).
local function perCharge(c)
  local per = 1
  local powers = c.player.powers
  for i = 1, #powers do
    local b = Card.def(powers[i]).chargeBonus
    if b and b > per then per = b end
  end
  return per
end
Combat.chargeBonus = perCharge

---------------------------------------------------------------------------
-- Cartes épiques du Mage (docs/zones/cartes-de-zone.md, « Mage ») : règles actives tout le combat, posées
-- en crochets du deck (deckHooks, src = { id, up, uid } : Card.def(src) donne les nombres de la carte,
-- base ou améliorée). État de combat dans c.cls (données simples) :
--   carry  mana gardé pour le tour suivant (Arcane Meditation), posé en fin de tour ;
--   fof    uid de la carte Cast partie tout de suite par Fingers of Frost, fofOn pendant sa résolution ;
--   r3     { [uid] = true } cartes jouées en 3e position (Rule of Threes), r3surge : Surge de l'original.
---------------------------------------------------------------------------

-- Mot de plaque « Epic » (en tête, comme « Power ») ; déclaré par le socle quand il existe.
if not L.plateByKey("epic") then
  L.plate("epic", { word = "Epic", head = true, text = "in play from the start of each combat." })
end

L.trigger("Every 3rd turn")

local Rng = ns.Rng
local Cards = ns.Cards
local function num(src, k) return Card.def(src)[k] or 0 end

-- Tour où une épique à période (epicPeriod = 3 : « Every 3rd turn ») agit : le 1er, puis un tour sur N.
function Combat.epicTurn(src, round)
  local p = Card.def(src).epicPeriod
  return not p or (round - 1) % p == 0
end

local function firstDamage(d)
  for i = 1, #d.effects do
    if d.effects[i][1] == "damage" then return d.effects[i] end
  end
  return nil
end

-- Mirror Image : à la résolution d'une carte Cast (incantée ou partie tout de suite), le montant de base de
-- son premier coup (+ epicN) frappe une fois de plus un ennemi vivant tiré au hasard (flux des cartes, la
-- même cible possible) ; coup de la même carte (Charges, Shatter, Ignite). Une carte « to all » : un coup.
local function mirrorHit(c, src, ctx)
  local e = firstDamage(ctx.def)
  if not e or c.result then return end
  local alive = Combat.aliveEnemies(c)
  if #alive == 0 then return end
  local t = alive[Rng.int(c.rng.cards, 1, #alive)]
  local base = e[2] + num(src, "epicN")
  if e.bonus then base = base + e.bonus(c, ctx, t) end
  if e.more or e.per then base = Combat.amount(c, ctx, e, base, t) end
  Combat.log(c, { t = "epic", id = "mirror_image", dst = t.uid })
  Combat.dealDamage(c, c.player, t, Combat.calcDamage(c, c.player, t, base, ctx.def), e.pierce, ctx)
  if ctx.def.type == "attack" and not c.result then Combat.fire(c, "onAttackHit", t, ctx) end
end
Combat.mirrorHit = mirrorHit

Cards.mirror_image.deckHooks = {
  afterCast = function(c, src, inst, ctx) mirrorHit(c, src, ctx) end,
}

-- Molten Armor : chaque coup ennemi sur le Mage, même absorbé, pose DoT epicN à son auteur (valeur passée
-- par le crochet « apply » comme un état posé par une carte).
Cards.molten_armor.deckHooks = {
  afterHit = function(c, src, e)
    if not e or e.dead or e.side ~= "enemy" or c.result then return end
    local n = Combat.modify(c, "apply", num(src, "epicN"), "pain", e, nil)
    if n > 0 then Combat.applyStatus(c, e, "pain", n, "burn") end
  end,
}

-- Water Elemental : cible = la dernière cible du Mage si elle vit, sinon l'ennemi vivant le plus à gauche ;
-- un dormeur (Asleep, Swamp) n'est visé que si tous dorment.
function Combat.elementalTarget(c)
  local function awake(e) return not e.dead and (e.st.asleep or 0) <= 0 end
  local anyAwake = false
  for i = 1, #c.enemies do if awake(c.enemies[i]) then anyAwake = true break end end
  local function ok(e) return e and not e.dead and (awake(e) or not anyAwake) end
  local last = c.player.lastTarget and Combat.enemyByUid(c, c.player.lastTarget)
  if ok(last) then return last end
  for i = 1, #c.enemies do if ok(c.enemies[i]) then return c.enemies[i] end end
  return nil
end

Cards.water_elemental.deckHooks = {
  onTurnStart = function(c, src)
    if not Combat.epicTurn(src, c.round) then return end
    local t = Combat.elementalTarget(c)
    if not t or c.result then return end
    Combat.log(c, { t = "epic", id = "water_elemental", dst = t.uid })
    Combat.dealDamage(c, c.player, t, Combat.calcDamage(c, c.player, t, num(src, "epicN"), nil))
    if not t.dead and not c.result then Combat.applyStatus(c, t, "demoralized", num(src, "epicM")) end
  end,
}

-- Fingers of Frost : une carte Cast à cible jouée sur un ennemi Frozen part tout de suite (crochet
-- « instantCast », cible dans c.aim ; sans cible connue, canPlay : vrai si un ennemi vivant est Frozen),
-- sans emplacement ni Instant consommé ; améliorée, ses coups font epicN de plus.
local function anyFrozen(c)
  for i = 1, #c.enemies do if Combat.isFrozen(c.enemies[i]) then return true end end
  return false
end

Cards.fingers_of_frost.deckHooks = {
  instantCast = function(c, src, v, d, inst, commit)
    if v or not d.cast or d.target ~= "enemy" then return v end
    local ok
    if c.aim then ok = Combat.isFrozen(Combat.enemyByUid(c, c.aim)) else ok = anyFrozen(c) end
    if ok and commit then
      c.cls.fof = inst.uid
      Combat.log(c, { t = "epic", id = "fingers_of_frost", card = inst.uid })
    end
    return ok and true or v
  end,
  beforeCard = function(c, src, inst, ctx)
    if c.cls.fof == inst.uid and not ctx.cast then c.cls.fofOn = true end
  end,
  onCardPlayed = function(c, src, inst)
    if c.cls.fof == inst.uid then c.cls.fof, c.cls.fofOn = nil, nil end
  end,
  damage = function(c, src, v, dst, cardDef)
    if c.cls.fofOn and cardDef and cardDef.cast then return v + num(src, "epicN") end
    return v
  end,
}

-- Arcane Meditation : à la fin du tour, le mana non dépensé (epicN au plus) est gardé ; il s'ajoute au début
-- du tour suivant, après la remise du mana à son maximum (le total peut dépasser le maximum).
Cards.arcane_meditation.deckHooks = {
  onTurnEnd = function(c, src)
    local keep = math.min(math.max(c.player.mana or 0, 0), num(src, "epicN"))
    c.cls.carry = keep > 0 and keep or nil
  end,
  onTurnStart = function(c)
    local n = c.cls.carry
    c.cls.carry = nil
    if n and n > 0 then
      c.player.mana = c.player.mana + n
      Combat.log(c, { t = "mana", n = n, total = c.player.mana, why = "arcane_meditation" })
    end
  end,
}

-- Conflagration : un ennemi qui meurt en portant du DoT (valeur au moment de la mort ; mort par son tic : la
-- valeur de ce tic) le donne, + epicN, à chaque autre ennemi vivant, posé directement (sans crochet « apply »).
Cards.conflagration.deckHooks = {
  onEnemyDeath = function(c, src, dead)
    local n = dead.st.pain or 0
    if n <= 0 then return end
    n = n + num(src, "epicN")
    local icon = dead.stIcon and dead.stIcon.pain or "burn"
    local spread = false
    for i = 1, #c.enemies do
      local o = c.enemies[i]
      if o ~= dead and not o.dead then
        if not spread then
          spread = true
          Combat.log(c, { t = "epic", id = "conflagration", src = dead.uid })
        end
        Combat.applyStatus(c, o, "pain", n, icon)
      end
    end
  end,
}

-- Rule of Threes : la 3e carte jouée du tour (améliorée : chaque 3e) se résout deux fois si c'est une Attack
-- (repli de la fiche, « Risques d'équilibre » 5 : toutes les cartes, c'était 100 % de victoires), la copie tout de
-- suite après, même cible, sans coût (crochet « replay ») ; marquée au jeu (c.turn.played), donc une carte Cast
-- incantée se résout deux fois à son départ. La copie compte le même Surge que l'original.
local function third(c, src, d)
  local n = c.turn.played
  return d.type == "attack" and Combat.epicTurn(src, c.round)
    and (n == 3 or (Card.def(src).epicEvery and n > 0 and n % 3 == 0))
end
Combat.ruleOfThreesNext = function(c, src) -- la prochaine carte jouée sera-t-elle doublée (si Attack) ? (vue)
  local n = c.turn.played + 1
  return Combat.epicTurn(src, c.round) and (n == 3 or (Card.def(src).epicEvery and n % 3 == 0))
end

Cards.rule_of_threes.deckHooks = {
  onCardCommitted = function(c, src, inst, d)
    local r = c.cls.r3 or {}
    c.cls.r3 = r
    r[inst.uid] = third(c, src, d) or nil
  end,
  replay = function(c, src, v, inst, ctx)
    local r = c.cls.r3
    if not (r and r[inst.uid]) then return v end
    r[inst.uid] = nil
    c.cls.r3surge = { uid = inst.uid, n = ctx.surge or 0 }
    Combat.log(c, { t = "epic", id = "rule_of_threes", card = inst.uid })
    return v + 1
  end,
  beforeCard = function(c, src, inst, ctx)
    local s = c.cls.r3surge
    if ctx.copy and s and s.uid == inst.uid then ctx.surge = s.n end
  end,
}

-- Bots : valeur d'un point de mana gardé (Arcane Meditation), en PV ennemis (une carte à 1 mana ≈ 6).
Combat.MAGE_CARRY_VALUE = 5

-- Épique du Mage présente dans ce combat (id) ou nil (vue de classe, bots).
function Combat.mageEpic(c)
  local ps = c.passives
  if not ps then return nil end
  for i = 1, #ps do
    local d = Card.def(ps[i])
    if d.epic and d.class == "mage" then return ps[i].id, ps[i] end
  end
  return nil
end

ns.ClassRules.mage = {
  hooks = {
    damage = function(c, cls, v, dst, cardDef)
      local n = c.player.res or 0
      if n > 0 and cardDef and cardDef.type == "attack" then return v + n * perCharge(c) end
      return v
    end,
    castSlots = function(c, cls, v) return v + 1 end,
    enemyDamage = function(c, cls, v, enemy, dst)
      if dst == c.player and (c.player.st.ice_block or 0) > 0 then return 0 end
      return v
    end,
  },
  -- Bots : ce qui distingue deux positions au-delà de la clé commune (deuxième incantation, Instant,
  -- compte Fire du tour pour Hot Streak, baguette encore à consommer).
  botKey = function(c)
    local p = c.player
    local more = p.castMore and p.castMore[1] and p.castMore[1].card.id or "-"
    local k = more .. ":" .. (p.st.instant or 0) .. ":" .. (c.turn.bySchool.fire or 0) .. ":"
      .. (c.relicState.apprentice_wand and 1 or 0) .. ":" .. (p.st.ice_block or 0)
    -- épiques : rang de la prochaine carte (Rule of Threes), mana gardé (Arcane Meditation)
    if c.passives then
      local id = Combat.mageEpic(c)
      if id == "rule_of_threes" then k = k .. ":r" .. c.turn.played
      elseif id == "water_elemental" then k = k .. ":t" .. tostring(p.lastTarget) end
    end
    return k
  end,
  -- Bots : valeur de la deuxième incantation (Bots.castValue ne lit que la première), du mana
  -- d'Evocation en incantation, et des charges d'Instant gardées.
  botValue = function(c, W)
    local p = c.player
    local alive = #Combat.aliveEnemies(c)
    local v = 0
    local function entryValue(entry, skipDamage)
      local d = Card.def(entry.card)
      local s = (d.evoMana or 0) * 22
      if not skipDamage then
        for i = 1, #d.effects do
          local e = d.effects[i]
          if e[1] == "damage" then
            s = s + (e[2] + (p.res or 0)) * (e.times or 1) * (e.all and alive or 1) * W.enemyHp
          elseif e[1] == "apply" and e[2] == "pain" then
            s = s + e[3] * (e[3] + 1) / 2 * 0.8 * W.enemyHp * (e.all and alive or 1)
          elseif e[1] == "apply" and (e[2] == "demoralized" or e[2] == "stunned") then
            s = s + 12 * e[3] * (e.all and alive or 1)
          elseif e[1] == "absorb" then
            s = s + e[2] * W.hp * 0.5
          end
        end
      end
      return s * W.castRisk
    end
    if p.cast then v = v + entryValue(p.cast, true) end
    local more = p.castMore
    if more then
      for i = 1, #more do v = v + entryValue(more[i], false) * 0.9 end
    end
    v = v + (p.st.instant or 0) * 30
    -- épiques : coup en plus des incantations tenues (Mirror Image), mana gardé (Arcane Meditation)
    if c.passives then
      local id, src = Combat.mageEpic(c)
      if id == "mirror_image" then
        local function mirror(entry)
          local e = entry and firstDamage(Card.def(entry.card))
          if e then v = v + (e[2] + (p.res or 0) + num(src, "epicN")) * W.enemyHp * W.castRisk end
        end
        mirror(p.cast)
        for i = 1, #(more or {}) do mirror(more[i]) end
      elseif id == "arcane_meditation" then
        v = v + (c.cls.carry or 0) * Combat.MAGE_CARRY_VALUE * W.enemyHp
      end
    end
    return v
  end,
}
