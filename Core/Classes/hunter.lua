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

-- Langage : condition Careful Aim, mot « Pet attacks », déclencheurs des Powers du Chasseur.
L.condition("careful", { name = "Careful Aim", text = "if the target has more than half its HP." })
L.keyword("pet", { name = "Pet attacks", pattern = "[Pp]%at attacks", text = "hits its target for " .. Hunter.PET_BASE .. " + Frenzy, then +1 Frenzy." })
L.trigger("Pet attacks")
L.trigger("Traps")
L.trigger("When a Trap triggers")
-- cartes épiques (docs/zones/cartes-de-zone.md, Hunter) : Black Arrow, Lone Wolf, Aspect of the Turtle
L.trigger("Each enemy DoT tick")
L.trigger("Attack hits")
L.trigger("Each Attack hit")
L.keyword("loneWolf", { name = "Pet cards become shots", pattern = "^Pet cards become shots%.$",
  text = "the pet is gone for the expedition." })

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
  local uid = c.player.lastTarget
  if uid then
    local e = Combat.enemyByUid(c, uid)
    if e and not e.dead then return e end
  end
  for i = 1, #c.enemies do
    if not c.enemies[i].dead then return c.enemies[i] end
  end
  return nil
end

-- Dégâts du prochain coup du familier sur sa cible (affichage, bots), frenzy facultatif.
function Hunter.petDamage(c, t, frenzy)
  t = t or Hunter.petTarget(c)
  if not t then return 0 end
  return Combat.calcDamage(c, c.player, t, Hunter.PET_BASE + (frenzy or c.player.res or 0), nil)
end

local function stat(c, key, n)
  local s = c.stats
  if s then s[key] = (s[key] or 0) + (n or 1) end
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

function Hunter.petAttack(c, why, frenzy)
  if c.result then return 0 end
  if not Hunter.petPresent(c) then return 0 end
  local t = Hunter.petTarget(c)
  if not t then return 0 end
  local dmg = Hunter.petDamage(c, t, frenzy)
  if Hunter.petAll(c) then
    -- tous les ennemis vivants, la cible du familier d'abord ; dmg rendu = celui de la cible ; les autres
    -- petLess de moins
    local list = { t }
    for i = 1, #c.enemies do
      local o = c.enemies[i]
      if o ~= t and not o.dead then list[#list + 1] = o end
    end
    local less = Hunter.petLess(c)
    for i = 1, #list do
      local o = list[i]
      if not o.dead and not c.result then
        local d = Hunter.petDamage(c, o, frenzy)
        if i > 1 then d = math.max(0, d - less) end
        Combat.log(c, { t = "pet_attack", dst = o.uid, dmg = d, why = why, all = true })
        stat(c, "petAttacks")
        stat(c, "petDamage", d)
        Combat.dealDamage(c, c.player, o, d)
      end
    end
  else
    Combat.log(c, { t = "pet_attack", dst = t.uid, dmg = dmg, why = why })
    stat(c, "petAttacks")
    stat(c, "petDamage", dmg)
    Combat.dealDamage(c, c.player, t, dmg)
  end
  if c.result then return dmg end
  if why ~= "surge" then Combat.gainRes(c, 1, "pet") end
  Combat.fire(c, "onPetAttack", t, dmg, why)
  return dmg
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
function Hunter.epicStart(c, src)
  c.cls.epic = { id = src.id, up = src.up and true or false }
  for i = #c.draw, 1, -1 do
    if c.draw[i].uid == src.uid then table.remove(c.draw, i) break end
  end
end

-- Épique en jeu dans ce combat (id) ou nil ; up = vrai si améliorée.
function Hunter.epic(c)
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
    onRoundEnd = function(c, cls)
      if (c.player.res or 0) > 0 then Combat.gainRes(c, -1, "decay") end
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
    local ep = Hunter.epic(c)
    local k = ep and Hunter.EPIC_RES[ep]
    if k then v = v + (c.player.res or 0) * k end
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
