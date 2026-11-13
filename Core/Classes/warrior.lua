-- Règles propres du Guerrier : la Rage (docs/gdd-classes.md, « Warrior » ; contrat : docs/classes.md).
--   +1 Rage à chaque perte de PV (coup ennemi, DoT, « Pay N HP » : un paiement compte comme une perte),
--   +1 Rage par carte Attack jouée (à sa résolution), plafond 5 (classDef.resource.cap), gardée d'un
--   tour à l'autre. Revenge (champ hurtCost) coûte moins si des PV ont été perdus au tour précédent.
-- État de classe c.cls : hurt (PV perdus depuis le début de ce tour), hurtLast (au tour précédent) ; états
-- des cartes épiques (plus bas) : titan, tgAttacks, tgSurge, tgHeld, amSpent.
local _, ns = ...

local Combat, Card, Rng = ns.Combat, ns.Card, ns.Rng
local L = ns.Language
local floor = math.floor

ns.Warrior = ns.Warrior or {}
local Warrior = ns.Warrior

ns.ClassRules.warrior = {
  init = function(c, cls)
    cls.hurt = false
    cls.hurtLast = false
  end,
  hooks = {
    onHpLost = function(c, cls, n)
      cls.hurt = true
      if not c.result then Combat.gainRes(c, 1, "hit") end
    end,
    onCardPlayed = function(c, cls, inst, ctx)
      -- Titan's Grip : la copie d'une Attack ne donne pas sa Rage (une fois par carte)
      if ctx.def.type == "attack" and not (ctx.copy and cls.titan) then Combat.gainRes(c, 1, "attack") end
    end,
    onTurnStart = function(c, cls)
      cls.hurtLast = cls.hurt
      cls.hurt = false
    end,
    cost = function(c, cls, v, d)
      if d.hurtCost and cls.hurtLast then return d.hurtCost end
      return v
    end,
  },
  -- Bots : état qui distingue deux positions (Strength du joueur, PV perdus ce tour ; Attacks du tour sous
  -- Titan's Grip, reste de Rage dépensée sous Anger Management).
  botKey = function(c)
    local cls = c.cls
    return (c.player.st.force or 0) .. ":" .. (cls.hurt and 1 or 0) .. ":" .. (cls.hurtLast and 1 or 0)
      .. ":" .. (cls.tgAttacks or 0) .. ":" .. (cls.amSpent or 0)
  end,
  -- Bots : valeur propre (unités de Bots.W, 10 = 1 PV). Anger Management : la Rage déjà dépensée vers le
  -- prochain cran de recharge vaut une part d'un cran.
  botValue = function(c, W)
    local id, up = Warrior.epicOf(c)
    if id == "anger_management" then
      local per = up and Warrior.EPIC.anger_management.upPer or Warrior.EPIC.anger_management.per
      return (c.cls.amSpent or 0) / per * 12
    end
    return 0
  end,
}

---------------------------------------------------------------------------
-- Cartes épiques du Guerrier (docs/zones/cartes-de-zone.md, « Warrior »)
---------------------------------------------------------------------------
-- Règle active pendant tout le combat, dès son début : deckHooks (crochets actifs où que soit la carte,
-- src = { id, up, uid }) et whileInDeck (au début du combat). Nombres réglés par la simulation (rapport du
-- 14/11/2026) : ce tableau seul, les textes de Data/Warrior.lua les disent.
Warrior.EPIC = {
  death_wish = { mult = 1.5, heal = 3 },
  thunderous_roar = { at = 5, damage = 3, upDamage = 5, demoralized = 0 },
  sweeping_strikes = { targets = 1, upTargets = 2 },
  titans_grip = { limit = 1, selfStates = true },
  shield_charge = { div = 4, upBonus = 4 },
  anger_management = { per = 1, upPer = 1, steps = 1, upSteps = 2 },
  avatar = { cap = 10, gain = 2, upGain = 3 },
}
local E = Warrior.EPIC
Warrior.EPICS = { "death_wish", "thunderous_roar", "sweeping_strikes", "titans_grip", "shield_charge",
  "anger_management", "avatar" }
local IS_EPIC = {}
for _, id in ipairs(Warrior.EPICS) do IS_EPIC[id] = true end

-- Épique du Guerrier active dans ce combat : id, amélioré (nil sans épique). Lit les effets passifs du deck
-- (c.passives), puis les Powers (une épique posée parmi eux par le socle).
function Warrior.epicOf(c)
  local ps = c.passives
  if ps then
    for i = 1, #ps do if IS_EPIC[ps[i].id] then return ps[i].id, ps[i].up end end
  end
  local pw = c.player.powers
  for i = 1, #pw do if IS_EPIC[pw[i].id] then return pw[i].id, pw[i].up end end
  return nil
end

-- Mots du langage (déclencheurs « Name: » des textes) et plaque « Epic » (si le socle ne l'a pas posée).
L.trigger("Kills")
L.trigger("At 5 Rage")
L.trigger("Targeted Attack hits")
L.trigger("Each Rage spent")
do
  local has = false
  for _, p in ipairs(L.plates) do if p.word == "Epic" then has = true end end
  if not has then
    L.plate("epic", { word = "Epic", head = true, text = "in play from the start of each combat." })
  end
end

-- Début de combat : l'épique n'est ni piochée ni jouée. Tant que le socle la laisse dans la pioche, on l'en
-- sort ici (provisoire : sans effet quand le socle la pose ailleurs).
local function settle(c, src)
  for _, pile in ipairs({ c.draw, c.hand }) do
    for i = #pile, 1, -1 do
      if pile[i].uid == src.uid then table.remove(pile, i) end
    end
  end
end

local function withSettle(f)
  return function(c, src)
    settle(c, src)
    if f then f(c, src) end
  end
end

local function attach(id, hooks, upHooks, start)
  local d = ns.Cards[id]
  d.deckHooks = hooks
  d.whileInDeck = withSettle(start)
  d.up.deckHooks = upHooks or hooks
  d.up.whileInDeck = d.whileInDeck
end

local function hasEffect(d, kind)
  for i = 1, #d.effects do if d.effects[i][1] == kind then return true end end
  return false
end

-- Westfall — Death Wish : aucun Absorb gagné ; les coups des cartes Attack +50 % (après Strength, avant
-- Sundered, arrondi à l'inférieur : crochet attackMult) ; amélioré : chaque ennemi tué soigne de 3.
do
  local base = {
    canGainBlock = function() return false end,
    attackMult = function(c, src, v) return v * E.death_wish.mult end,
  }
  local up = {
    canGainBlock = base.canGainBlock,
    attackMult = base.attackMult,
    onEnemyDeath = function(c) Combat.heal(c, c.player, E.death_wish.heal) end,
  }
  attach("death_wish", base, up)
end

-- Duskwood — Thunderous Roar : dès que la Rage atteint 5 (juste après le gain, quelle qu'en soit la source),
-- elle tombe à 0, le Guerrier inflige 6 (amélioré : 9) à chaque ennemi vivant, sans carte (Strength
-- comprise), puis pose Demoralized 1 sur chacun. Pendant le tour ennemi, Demoralized ne dure que jusqu'à la
-- fin du round (il allège les coups restants de ce tour) : l'état posé n'est pas protégé de la baisse.
function Warrior.roar(c, up)
  local p = c.player
  Combat.gainRes(c, -(p.res or 0), "roar")
  Combat.log(c, { t = "epic_trigger", card = "thunderous_roar" })
  local n = up and E.thunderous_roar.upDamage or E.thunderous_roar.damage
  local list = Combat.aliveEnemies(c)
  for i = 1, #list do
    local e = list[i]
    if not e.dead and not c.result then Combat.dealDamage(c, p, e, Combat.calcDamage(c, p, e, n)) end
  end
  if c.result then return end
  if E.thunderous_roar.demoralized <= 0 then return end
  list = Combat.aliveEnemies(c)
  for i = 1, #list do
    local e = list[i]
    local fresh = e.fresh.demoralized
    Combat.applyStatus(c, e, "demoralized", E.thunderous_roar.demoralized)
    if c.phase == "enemy" then e.fresh.demoralized = fresh end
  end
end

do
  local hooks = {
    onResource = function(c, src, delta)
      if delta <= 0 or c.result or (c.player.res or 0) < E.thunderous_roar.at then return end
      Warrior.roar(c, src.up)
    end,
  }
  attach("thunderous_roar", hooks)
end

-- Wetlands — Sweeping Strikes : chaque coup d'une carte Attack à cible inflige aussi la moitié des PV qu'il
-- a fait perdre (arrondie à l'inférieur) à un autre ennemi vivant tiré par c.rng.cards (amélioré : deux,
-- sans remise). Le rebond est un coup sans carte (ctx nil) : ni Rage, ni Deep Wounds, ni nouveau rebond.
local function sweepHooks(count)
  return {
    onDamageDealt = function(c, src, t, loss, ctx)
      if not ctx or not ctx.def or ctx.def.type ~= "attack" or ctx.def.target ~= "enemy" then return end
      if t ~= ctx.target then return end
      local n = floor(loss / 2)
      if n <= 0 then return end
      local others = {}
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if e ~= t and not e.dead then others[#others + 1] = e end
      end
      for _ = 1, count do
        if #others == 0 or c.result then return end
        local e = table.remove(others, Rng.int(c.rng.cards, 1, #others))
        Combat.log(c, { t = "epic_trigger", card = "sweeping_strikes", unit = e.uid })
        Combat.dealDamage(c, c.player, e, n)
      end
    end,
  }
end
attach("sweeping_strikes", sweepHooks(E.sweeping_strikes.targets), sweepHooks(E.sweeping_strikes.upTargets))

-- Stranglethorn Vale — Titan's Grip : chaque carte Attack se résout deux fois (crochet replay : la copie
-- suit, même cible ou premier ennemi vivant, sans coût, reprend le Spend payé et le montant du Surge de
-- l'original sans rien dépenser) ; la Rage « +1 par Attack » une fois par carte ; au plus deux cartes
-- Attack par tour (crochet canPlay ; amélioré : celles qui coûtent 0 au moment du jeu ne comptent pas).
Warrior.TITAN_REASON = "Only 1 Attack per turn."

local function titanCounts(c, src, inst)
  return not (src.up and Combat.cost(c, inst) == 0)
end

local titanHooks = {
  replay = function(c, src, v, inst, ctx)
    if ctx.def.type ~= "attack" then return v end
    c.cls.tgSurge = hasEffect(ctx.def, "surge") and (ctx.surge or 0) or nil
    return v + 1
  end,
  canPlay = function(c, src, v, d, inst)
    if v ~= true or d.type ~= "attack" or not titanCounts(c, src, inst) then return v end
    if (c.cls.tgAttacks or 0) >= E.titans_grip.limit then return Warrior.TITAN_REASON end
    return v
  end,
  onCardCommitted = function(c, src, inst, d)
    if d.type == "attack" and titanCounts(c, src, inst) then c.cls.tgAttacks = (c.cls.tgAttacks or 0) + 1 end
  end,
  onTurnStart = function(c) c.cls.tgAttacks = 0 end,
  -- copie d'un Surge : la Rage de l'original est prêtée le temps de la copie, puis rendue telle quelle
  beforeCard = function(c, src, inst, ctx)
    local cls = c.cls
    cls.tgCopy = ctx.copy and true or nil
    if ctx.copy and cls.tgSurge then
      cls.tgHeld = c.player.res or 0
      c.player.res = cls.tgSurge
    end
  end,
  -- la copie ne pose pas d'état sur le héros (Strength de Bloodthirst) si selfStates est faux
  applySelf = function(c, src, n)
    if c.cls.tgCopy and not E.titans_grip.selfStates then return 0 end
    return n
  end,
  onCardPlayed = function(c, src, inst, ctx)
    local cls = c.cls
    cls.tgCopy = nil
    if ctx.copy and cls.tgHeld then
      c.player.res = cls.tgHeld
      cls.tgHeld, cls.tgSurge = nil, nil
    end
  end,
}
attach("titans_grip", titanHooks, nil, function(c) c.cls.titan = true c.cls.tgAttacks = 0 end)

-- Swamp of Sorrows — Shield Charge : à la fin du tour du Guerrier (avant la défausse), la moitié de son
-- Absorb (arrondie à l'inférieur ; amélioré : 4 + la moitié) frappe sa dernière cible, sans carte
-- (Strength comprise) ; dernière cible morte : l'ennemi vivant le plus à gauche ; un dormeur (état asleep,
-- Swamp) n'est visé que s'il ne reste aucun ennemi éveillé. L'Absorb reste entière. Sans Absorb : rien.
local function asleep(e) return (e.st.asleep or 0) > 0 end

function Warrior.chargeTarget(c)
  local last = c.player.lastTarget and Combat.enemyByUid(c, c.player.lastTarget)
  local awake, first
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    if not e.dead then
      first = first or e
      if not awake and not asleep(e) then awake = e end
    end
  end
  if last and not last.dead and (not asleep(last) or not awake) then return last end
  return awake or first
end

function Warrior.chargeDamage(c, up)
  local b = c.player.block or 0
  if b <= 0 then return 0 end
  return floor(b / E.shield_charge.div) + (up and E.shield_charge.upBonus or 0)
end

do
  local hooks = {
    onTurnEnd = function(c, src)
      if c.result then return end
      local n = Warrior.chargeDamage(c, src.up)
      local t = n > 0 and Warrior.chargeTarget(c)
      if not t then return end
      Combat.log(c, { t = "epic_trigger", card = "shield_charge", unit = t.uid })
      Combat.dealDamage(c, c.player, t, Combat.calcDamage(c, c.player, t, n))
    end,
  }
  attach("shield_charge", hooks)
end

-- Burning Steppes — Anger Management : la Rage dépensée (Spend payé, montant d'un Surge) s'ajoute à un
-- compteur du combat (c.cls.amSpent, reste gardé d'un tour à l'autre) ; à chaque tranche de 3 (amélioré :
-- 2), chaque carte en recharge revient un tour plus tôt (Warrior.cooldownTick). Une carte dont la recharge
-- arrive à 0 revient en main aussitôt ; main pleine : au début du tour suivant.
function Warrior.cooldownTick(c)
  local keep = {}
  for i = 1, #c.cooldown do
    local cd = c.cooldown[i]
    local turns = cd.turns - 1
    if turns <= 0 and #c.hand < Combat.HAND_MAX then
      c.hand[#c.hand + 1] = cd.card
      Combat.log(c, { t = "cooldown_back", card = cd.card.uid })
    else
      keep[#keep + 1] = { card = cd.card, turns = turns > 0 and turns or 0 }
    end
  end
  c.cooldown = keep
end

local function angerHooks(per, steps)
  local function spent(c, n)
    local cls = c.cls
    cls.amSpent = (cls.amSpent or 0) + n
    while cls.amSpent >= per do
      cls.amSpent = cls.amSpent - per
      if #c.cooldown > 0 then Combat.log(c, { t = "epic_trigger", card = "anger_management" }) end
      for _ = 1, steps do Warrior.cooldownTick(c) end
    end
  end
  return {
    onSpend = function(c, src, n) spent(c, n) end,
    onSurge = function(c, src, n) spent(c, n) end,
  }
end
attach("anger_management", angerHooks(E.anger_management.per, E.anger_management.steps),
  angerHooks(E.anger_management.upPer, E.anger_management.upSteps),
  function(c) c.cls.amSpent = 0 end)

-- Blackrock Mountain — Avatar : plafond de Rage à 10 (crochet resCap) ; au début de chaque tour, +1 Rage
-- (amélioré : +2). Les cartes « per Rage » lisent la Rage réelle (Execute 5 + 4 × 10).
local function avatarHooks(gain)
  return {
    resCap = function(c, src, v) return math.max(v, E.avatar.cap) end,
    onTurnStart = function(c) Combat.gainRes(c, gain, "avatar") end,
  }
end
attach("avatar", avatarHooks(E.avatar.gain), avatarHooks(E.avatar.upGain))
