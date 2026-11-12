-- Règles propres du Chasseur (fiche : docs/classes/hunter.md ; contrat : docs/classes.md).
--
-- Familier : pas une unité (ni PV, ni Absorb, ni états, jamais ciblé). Une attaque = un coup de
--   3 + Frenzy sur la cible du familier (c.player.lastTarget, posée par Combat.play dès qu'une carte à
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

Hunter.PET_BASE = 3 -- dégâts d'une attaque du familier à Frenzy 0

-- Langage : condition Careful Aim, mot « Pet attacks », déclencheurs des Powers du Chasseur.
L.condition("careful", { name = "Careful Aim", text = "if the target has more than half its HP." })
L.keyword("pet", { name = "Pet attacks", pattern = "[Pp]%at attacks", text = "hits its target for 3 + Frenzy, then +1 Frenzy." })
L.trigger("Pet attacks")
L.trigger("Traps")
L.trigger("When a Trap triggers")

Combat.CONDITIONS.careful = function(c, ctx, t)
  if ctx and ctx.careful ~= nil and t == ctx.target then return ctx.careful end
  return t ~= nil and not t.dead and t.hp * 2 > t.maxHp
end

-- Cible du familier : la dernière cible visée si elle vit, sinon l'ennemi vivant le plus à gauche.
function Hunter.petTarget(c)
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
function Hunter.petAttack(c, why, frenzy)
  if c.result then return 0 end
  local t = Hunter.petTarget(c)
  if not t then return 0 end
  local dmg = Hunter.petDamage(c, t, frenzy)
  Combat.log(c, { t = "pet_attack", dst = t.uid, dmg = dmg, why = why })
  stat(c, "petAttacks")
  stat(c, "petDamage", dmg)
  Combat.dealDamage(c, c.player, t, dmg)
  if c.result then return dmg end
  if why ~= "surge" then Combat.gainRes(c, 1, "pet") end
  Combat.fire(c, "onPetAttack", t, dmg, why)
  return dmg
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

-- Valeur estimée d'une Trap encore posée après le tour ennemi (bots) : elle partira à la prochaine
-- attaque. Unités de Bots.W (10 = 1 PV).
Hunter.TRAP_VALUE = 25

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
