-- Règles propres du Chasseur (fiche : docs/classes/hunter.md ; contrat : docs/classes.md).
--
-- Familier : pas une unité (ni PV, ni Absorb, ni états, jamais ciblé). Une attaque = un coup de
--   PET_BASE + Frenzy sur la cible du familier (c.player.lastTarget, posée par Combat.play dès qu'une carte à
--   cible est jouée ; morte ou absente : l'ennemi vivant le plus à gauche), calculé comme un coup du
--   Chasseur SANS carte (Strength et Demoralized du Chasseur, Sundered et Absorb de la cible ; les bonus
--   « Attacks » des cartes, Powers et bibelots ne s'appliquent pas : cardDef nil), puis +1 Frenzy.
--   Attaque automatique à la fin de chaque tour du joueur (crochet de classe onTurnEnd : avant les Powers
--   et bibelots, avant la défausse). Effet de carte { "pet", n } : n attaques tout de suite ; surge = true
--   (Bestial Wrath) : au Frenzy compté avant la dépense, sans redonner de Frenzy.
--   Événement propre « onPetAttack » (cible, dégâts, raison) pour les Powers et bibelots (Spirit Bond) ;
--   journal { t = "pet_attack", dst, dmg, why } juste avant le coup (animation de l'interface).
-- Frenzy = ressource de classe (c.player.res, 0 à 5, gardée) : -1 à la fin de chaque round (crochet
--   onRoundEnd), donc au début de chaque tour du joueur sauf le premier, avant la résolution des Cast.
-- Careful Aim : condition « careful », inverse d'Execute (cible au-dessus de la moitié de ses PV) ; pour les
--   effets d'une carte, lue sur la cible au DÉBUT de la résolution (même verdict pour toutes les lignes :
--   « Deal 10. / Careful Aim: draw 1. » ne dépend pas des dégâts de la ligne d'avant).
-- Traps : mécanisme commun (champ trap, c.traps, Combat.triggerTrap).
local _, ns = ...

local Combat = ns.Combat
local L = ns.Language

local Hunter = {}
ns.Hunter = Hunter

-- Dégâts d'une attaque du familier à Frenzy 0. Fiche : 3 ; ramené à 1 par la simulation de fumée
-- (3 : 99 % de victoires à la clé 0, le deck de départ seul en gagnait 95 % ; voir le rapport du lot).
Hunter.PET_BASE = 1
-- Le Frenzy baisse de 1 un round sur DECAY_EVERY (1 : chaque round) ; changé par les talents (Combat.const
-- « DECAY_EVERY » : Bestial Discipline).
Hunter.DECAY_EVERY = 1

-- Langage : condition Careful Aim, mot « Pet attacks », déclencheurs des Powers du Chasseur.
L.condition("careful", { name = "Careful Aim", text = "if the target has more than half its HP." })
L.keyword("pet", { name = "Pet attacks", pattern = "[Pp]%at attacks", text = "hits its target for " .. Hunter.PET_BASE .. " + Frenzy, then +1 Frenzy." })
L.trigger("Pet attacks")
L.trigger("Traps")
L.trigger("When a Trap triggers")
-- cartes épiques (docs/zones/cartes-de-zone.md, Hunter) : déclencheurs, puis mots de règle (L.rule : la carte dit
-- « Déclencheur: Mot N. », l'à-côté la règle complète, avec les nombres de ns.HunterEpic, base puis améliorée)
L.trigger("Each enemy DoT tick")
L.trigger("Enemy DoT ticks")
L.trigger("Attack hits")
L.trigger("Each Attack hit")
do
  local E = ns.HunterEpic
  local TIMES = { [1] = "", [2] = " twice", [3] = " three times", [4] = " four times" }
  L.rule("wildCall", { name = "Wild Call", pattern = "^Start of turn:",
    text = "Spend N Frenzy, if available, for a pet attack." })
  L.rule("wildCallTick", { name = "Wild Call", pattern = "^Enemy DoT ticks:",
    text = "Spend N Frenzy, if available: the pet attacks that enemy." })
  -- Launch N : N = attaques du familier (base : 1 ; améliorée, paliers 2 et 3 compris : le nombre de la carte)
  local function launch(n) return "The Trap triggers at once on a target, then the pet attacks it" .. TIMES[n] .. "." end
  L.rule("launch", { name = "Launch", text = launch(E.launcher[1]),
    upText = "The Trap triggers at once on a target, then the pet attacks it N times." })
  local function stampede(less)
    return "Pet attacks also hit every other enemy" .. (less > 0 and (", for " .. less .. " less") or "")
      .. ", unless one sleeps."
  end
  L.rule("stampede", { name = "Stampede", text = stampede(E.cleaveLess[1]),
    upText = stampede(E.cleaveLess[2]) .. " Each one gives N more Frenzy." })
  -- paliers 2 et 3 des épiques (15/11/2026) : Beast Cleave (Trample), Call of the Wild (Hunt), Black Arrow (Prey)
  L.rule("trample", { name = "Trample",
    text = "Pet attacks also hit every other enemy, in full, unless one sleeps. Each one gives N more Frenzy." })


  L.rule("hunt", { name = "Hunt", text = "Gain N Frenzy, then the pet attacks." })
  L.rule("prey", { name = "Prey", text = "The pet attacks that enemy, then gain N Frenzy." })
  L.rule("intervene", { name = "Intervene", text = "Spend 1 Frenzy, if available, to stop up to N damage of the hit." })
  local function deadeye(n) return "Cast Attacks resolve at once" .. (n > 0 and " and deal N more." or ".") end
  L.rule("deadeye", { name = "Deadeye", text = deadeye(E.marksman[1]), upText = deadeye(E.marksman[2]) })
  local function ferocity(start)
    return "+N damage per Frenzy. The pet is gone: pet cards become shots"
      .. (start > 0 and (", and each turn starts with +" .. start .. " Frenzy.") or ".")
  end
  L.rule("ferocity", { name = "Ferocity", text = ferocity(E.loneStart[1]), upText = ferocity(E.loneStart[2]) })
end

Combat.CONDITIONS.careful = function(c, ctx, t)
  if ctx and ctx.careful ~= nil and t == ctx.target then return ctx.careful end
  return t ~= nil and not t.dead and t.hp * 2 > t.maxHp
end

-- Cible du familier : la dernière cible visée si elle vit, sinon l'ennemi vivant le plus à gauche.
function Hunter.petTarget(c)
  -- cible imposée le temps d'une attaque (Hunter.petAttackOn : Trap Launcher, Black Arrow)
  local force = c.cls and c.cls.petForce
  if force then
    local e = Combat.enemyByUid(c, force)
    if e and not e.dead then return e end
  end
  return Combat.strikeTarget(c)
end

-- Base du coup du familier dans ce combat : PET_BASE, changée par les talents (Combat.const « PET_BASE »).
function Hunter.petBase(c) return Combat.const(c, "PET_BASE", Hunter.PET_BASE) end

-- Dégâts du prochain coup du familier sur sa cible (affichage, bots), frenzy facultatif.
function Hunter.petDamage(c, t, frenzy)
  t = t or Hunter.petTarget(c)
  if not t then return 0 end
  return Combat.calcDamage(c, c.player, t, Hunter.petBase(c) + (frenzy or c.player.res or 0), nil)
end

-- Une attaque du familier. why : "auto" (fin de tour), "card", "relic", "surge" (pas de Frenzy gagné) ;
-- frenzy : valeur comptée (Surge), sinon le Frenzy actuel. Renvoie les dégâts.
-- Familier présent ? Crochet « petAbsent » (faux par défaut ; Lone Wolf) : absent, il n'attaque plus (ni
-- attaque automatique, ni effet « pet »), sans Frenzy gagné.
function Hunter.petPresent(c)
  return not Combat.modify(c, "petAbsent", false)
end

-- Le familier frappe-t-il tous les ennemis ? Crochet « petAll » (faux par défaut ; Beast Cleave) : chaque
-- attaque touche chaque ennemi vivant (dégâts calculés pour chacun), +1 Frenzy une seule fois.
function Hunter.petAll(c)
  return Combat.modify(c, "petAll", false) and true or false
end

-- Avec petAll : les ennemis autres que la cible prennent N dégâts de moins du familier (crochet « petLess »,
-- 0 par défaut = en plein ; Beast Cleave : 1), jamais moins de 0.
function Hunter.petLess(c)
  return math.max(0, Combat.modify(c, "petLess", 0) or 0)
end

-- Le coup lui-même est le coup sans carte commun (Combat.strike, Core/Companion.lua) : base PET_BASE + Frenzy
-- (relu à chaque coup ; Surge : le Frenzy compté), cible du familier puis, avec petAll, les autres ennemis
-- vivants petLess de moins ; journal « pet_attack », +1 Frenzy (sauf Surge), événement « onPetAttack ».
function Hunter.petAttack(c, why, frenzy)
  if c.result then return 0 end
  if not Hunter.petPresent(c) then return 0 end
  local t = Hunter.petTarget(c)
  if not t then return 0 end
  local all = Hunter.petAll(c)
  local opts = { res = frenzy == nil, gain = why ~= "surge" and 1 or 0, gainWhy = "pet",
    count = "petAttacks", total = "petDamage", all = all, less = all and Hunter.petLess(c) or nil }
  return Combat.strike(c, why, Hunter.petBase(c) + (frenzy or 0), t, "pet_attack", "onPetAttack", opts)
end

-- Une attaque du familier sur la cible imposée e (Trap Launcher, Black Arrow), sans changer sa cible
-- (c.player.lastTarget) : c.cls.petForce = uid de e le temps de l'attaque, lu par Hunter.petTarget (donc aussi
-- par les zones qui enveloppent petAttack / petTarget, Core/ZoneRules.lua) ; e mort : sa cible habituelle.
function Hunter.petAttackOn(c, why, e)
  local old = c.cls.petForce
  c.cls.petForce = e and e.uid or nil
  local r = Hunter.petAttack(c, why)
  c.cls.petForce = old
  return r
end

-- { "pet", n, per = …, surge = bool } : « Pet attacks. » / « twice » / « once per Frenzy » (Surge).
ns.Effects.pet = function(c, ctx, e)
  local n = e[2] or 1
  if e.more or e.per then n = Combat.amount(c, ctx, e, n, ctx.target) end
  for _ = 1, n do
    if e.surge then Hunter.petAttack(c, "surge", ctx.surge or 0) else Hunter.petAttack(c, "card") end
    if c.result then return end
  end
end

-- { "readiness" } : toutes les cartes en recharge reviennent en main, dans l'ordre où elles y sont
-- entrées ; celles qui ne tiennent pas dans la main (10) restent en recharge.
ns.Effects.readiness = function(c, ctx, e)
  local keep = {}
  for i = 1, #c.cooldown do
    local cd = c.cooldown[i]
    if #c.hand < Combat.HAND_MAX then
      c.hand[#c.hand + 1] = cd.card
      Combat.log(c, { t = "cooldown_back", card = cd.card.uid })
    else
      keep[#keep + 1] = cd
    end
  end
  c.cooldown = keep
end

-- { "damageOther", n } : « Deal N to another enemy. » (Chimaera Shot) : un coup de la carte sur l'ennemi
-- vivant le plus à gauche autre que la cible (rien s'il n'y en a pas) ; mêmes règles qu'un coup de
-- « damage » (Attack hit, Lone Wolf, Sundered…).
ns.Effects.damageOther = function(c, ctx, e)
  local main = ctx.target
  local other
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if o ~= main and not o.dead then other = o break end
  end
  if not other then return end
  ctx.target = other
  ns.Effects.damage(c, ctx, { "damage", e[2] })
  ctx.target = main
end

-- Cartes épiques (Data/Hunter.lua, docs/zones/cartes-de-zone.md) : règles en jeu dès le début du combat,
-- par deckHooks (où que soit la carte). whileInDeck = Hunter.epicStart : retient l'épique en jeu dans
-- c.cls.epic = { id, up } (vue de classe, bots) et la sort de la pioche si elle y est encore (une épique
-- n'est ni piochée ni jouée ; sans effet quand le socle la pose déjà hors des piles).
-- Plusieurs épiques en jeu (c.moreEpics) : c.cls.epic garde la première.
function Hunter.epicStart(c, src)
  c.cls.epic = c.cls.epic or { id = src.id, up = ns.Card.upValue(src.up) }
  for i = #c.draw, 1, -1 do
    if c.draw[i].uid == src.uid then table.remove(c.draw, i) break end
  end
end

-- Épique en jeu dans ce combat (id) ou nil ; up = vrai si améliorée. want = id cherché (cette épique si elle
-- est en jeu, Combat.hasEpic), sinon la première.
function Hunter.epic(c, want)
  if want then
    local e = Combat.hasEpic(c, want)
    if not e then return nil end
    return e.id, ns.Card.upValue(e.up)
  end
  local e = c.cls and c.cls.epic
  if not e then return nil end
  return e.id, e.up
end

-- Valeur estimée d'une Trap encore posée après le tour ennemi (bots) : elle partira à la prochaine
-- attaque. Unités de Bots.W (10 = 1 PV).
Hunter.TRAP_VALUE = 25
Hunter.EPIC_RES = { roar_of_sacrifice = 12, lone_wolf = 6 }

ns.ClassRules.hunter = {
  init = function(c, cls) end,
  hooks = {
    -- Careful Aim des lignes d'une carte : verdict pris au début de la résolution
    beforeCard = function(c, cls, inst, ctx)
      local t = ctx.target
      if t then ctx.careful = not t.dead and t.hp * 2 > t.maxHp end
    end,
    onTurnEnd = function(c, cls)
      Hunter.petAttack(c, "auto")
    end,
    -- baisse un round sur DECAY_EVERY (talent Bestial Discipline : 2, rounds pairs)
    onRoundEnd = function(c, cls)
      if (c.player.res or 0) > 0 then
        local every = c.talents and Combat.const(c, "DECAY_EVERY", Hunter.DECAY_EVERY) or Hunter.DECAY_EVERY
        if every <= 1 or c.round % every == 0 then Combat.gainRes(c, -1, "decay") end
      end
    end,
  },
  -- Bots : cible du familier et Traps posées distinguent deux positions.
  botKey = function(c)
    local ids = {}
    for i = 1, #c.traps do ids[i] = c.traps[i].card.id end
    return tostring(c.player.lastTarget or 0) .. ":" .. table.concat(ids, ",") .. ":" .. (c.player.st.force or 0)
  end,
  -- Bots : une Trap encore posée après le tour ennemi vaudra à la prochaine attaque ; Careful Aim d'une
  -- incantation en cours (Bots.castValue ne compte que la valeur de base).
  botValue = function(c, W)
    local v = #c.traps * Hunter.TRAP_VALUE
    -- épique en jeu : le Frenzy gardé vaut plus quand il protège (Roar of Sacrifice) ou s'ajoute à chaque
    -- coup des Attacks (Lone Wolf) ; Hunter.EPIC_RES[id] = valeur en plus d'un point (unités de Bots.W)
    if c.moreEpics then
      for ep, k in pairs(Hunter.EPIC_RES) do
        if Combat.hasEpic(c, ep) then v = v + (c.player.res or 0) * k end
      end
    else
      local ep = Hunter.epic(c)
      local k = ep and Hunter.EPIC_RES[ep]
      if k then v = v + (c.player.res or 0) * k end
    end
    local cast = c.player.cast
    if cast then
      local d = ns.Card.def(cast.card)
      local t = cast.target and Combat.enemyByUid(c, cast.target)
      if t and not t.dead and t.hp * 2 > t.maxHp then
        for i = 1, #d.effects do
          local more = d.effects[i].more
          if more then
            for j = 1, #more do
              if more[j][2] == "careful" then v = v + more[j][1] * W.enemyHp * W.castRisk end
            end
          end
        end
      end
    end
    return v
  end,
}
