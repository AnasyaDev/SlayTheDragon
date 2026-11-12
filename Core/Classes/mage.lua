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
    return more .. ":" .. (p.st.instant or 0) .. ":" .. (c.turn.bySchool.fire or 0) .. ":"
      .. (c.relicState.apprentice_wand and 1 or 0) .. ":" .. (p.st.ice_block or 0)
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
    return v
  end,
}
