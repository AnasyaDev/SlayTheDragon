-- Règles propres du Guerrier : la Rage (docs/gdd-classes.md, « Warrior » ; contrat : docs/classes.md).
--   +1 Rage à chaque perte de PV (coup ennemi, DoT, « Pay N HP » : un paiement compte comme une perte),
--   +1 Rage par carte Attack jouée (à sa résolution), plafond 5 (classDef.resource.cap), gardée d'un
--   tour à l'autre. Revenge (champ hurtCost) coûte moins si des PV ont été perdus au tour précédent.
-- État de classe c.cls : hurt (PV perdus depuis le début de ce tour), hurtLast (au tour précédent).
local _, ns = ...

local Combat = ns.Combat

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
      if ctx.def.type == "attack" then Combat.gainRes(c, 1, "attack") end
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
  -- Bots : état qui distingue deux positions (Strength du joueur, PV perdus ce tour).
  botKey = function(c)
    return (c.player.st.force or 0) .. ":" .. (c.cls.hurt and 1 or 0) .. ":" .. (c.cls.hurtLast and 1 or 0)
  end,
}
