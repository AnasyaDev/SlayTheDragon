-- Arbre de talents du Rogue (docs/talents.md, § 8 ; contrat : docs/talents.md, « Contrat du socle des talents » ;
-- modèle : Data/Talents/warrior.lua). 14 nœuds, 24 points ; 8 nœuds de mécanique (Combo, Stealth, Parry, DoT), un
-- Specialization, un nœud « une fois par expédition », 4 génériques (ns.TalentCommon). Nombres réglables dans RT
-- (lus à chaque usage : tune=RogueTalents.CLE=n) ; les textes les disent (vérifié par Sim/tests_talents_rogue.lua).
local _, ns = ...

local Combat = ns.Combat
local TC = ns.TalentCommon
local max = math.max

local RT = {
  hp = 3,              -- Toughness : PV max par rang
  initiative = 1,      -- Initiative : Combo au début de chaque combat, par rang
  elusive = 1,         -- Elusiveness : Parry au début de chaque combat, par rang
  opportunity = 2,     -- Opportunity : dégâts de plus par coup d'une Attack jouée sous Stealth, par rang
  vile = 1,            -- Vile Poisons : DoT de plus à chaque DoT posé sur un ennemi
  reflexes = 1,        -- Lightning Reflexes : plafond de Parry +1
  readiness = 2,       -- Combat Readiness : dégâts arrêtés de plus par charge de Parry, par rang
  relentless = 1,      -- Relentless Strikes : Combo après chaque Surge, par rang
  assassinDot = 1,     -- Specialization Assassination : DoT posé sur la cible par Combo dépensé
  combatCombo = 1,     -- Specialization Combat : Combo à chaque Parry
  subtletyDraw = 1,    -- Specialization Subtlety : cartes piochées quand une carte donne Stealth
  stratagem = 1,       -- Deeper Stratagem : plafond de Combo, par rang
  fateParry = { 2, 3 }, -- Cheat Fate : Parry donné en évitant la mort (rang 2 : et Stealth)
}
ns.RogueTalents = RT

local function plural(n, word) return n == 1 and word or (word .. "s") end

-- Coup d'une carte Attack jouée sous Stealth (elle a consommé Stealth, ou en a profité sous Subterfuge) : la
-- carte en cours de résolution (c.cardCtx) est dans c.cls.openers (Core/Classes/rogue.lua).
local function fromStealth(c, d)
  if not d or d.type ~= "attack" then return false end
  local ctx = c.cardCtx
  local o = c.cls and c.cls.openers
  return ctx ~= nil and ctx.def == d and ctx.card ~= nil and o ~= nil and o[tostring(ctx.card.uid)] == true
end

local nodes = {
  -- Rangée 1 (ouverte d'emblée) ----------------------------------------------------------------------------------
  TC.toughness({ row = 1, ranks = 3, hp = RT.hp }),
  { id = "initiative", row = 1, ranks = 2, name = "Initiative", icon = "ability_rogue_ambush",
    text = { ("Start of combat: +%d Combo."):format(RT.initiative),
      ("Start of combat: +%d Combo."):format(2 * RT.initiative) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result then Combat.gainRes(c, RT.initiative * src.rank, "talent") end
      end,
    } },
  { id = "elusiveness", row = 1, ranks = 2, name = "Elusiveness", icon = "ability_rogue_feint",
    text = { ("Start of combat: gain Parry %d."):format(RT.elusive),
      ("Start of combat: gain Parry %d."):format(2 * RT.elusive) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result then Combat.applyStatus(c, c.player, "parry", RT.elusive * src.rank) end
      end,
    } },

  -- Rangée 2 (5 points) -----------------------------------------------------------------------------------------
  { id = "opportunity", row = 2, ranks = 2, name = "Opportunity", icon = "ability_backstab",
    text = { ("Attacks played in Stealth deal %d more per hit."):format(RT.opportunity),
      ("Attacks played in Stealth deal %d more per hit."):format(2 * RT.opportunity) },
    hooks = {
      damage = function(c, src, v, dst, d)
        if fromStealth(c, d) then return v + RT.opportunity * src.rank end
        return v
      end,
    },
    -- (bots : Stealth gardé vaut ce bonus de plus sur la prochaine Attack)
    bot = { value = function(c, src, W)
      return (c.player.st.stealth or 0) * RT.opportunity * src.rank * W.enemyHp
    end } },
  { id = "vile_poisons", row = 2, ranks = 1, name = "Vile Poisons", icon = "ability_rogue_dualweild",
    text = { ("Each time DoT is applied to an enemy, apply %d more."):format(RT.vile) },
    hooks = {
      apply = function(c, src, n, id)
        if id == "pain" and n > 0 then return n + RT.vile end
        return n
      end,
    } },
  { id = "lightning_reflexes", row = 2, ranks = 1, name = "Lightning Reflexes", icon = "spell_shadow_shadowward",
    text = { ("Parry can hold %d more %s."):format(RT.reflexes, plural(RT.reflexes, "charge")) },
    const = { PARRY_MAX = function(v) return v + RT.reflexes end } },
  TC.provisions({ row = 2 }),

  -- Rangée 3 (10 points) ----------------------------------------------------------------------------------------
  { id = "specialization", row = 3, ranks = 1, name = "Specialization", icon = "classicon_rogue",
    choices = {
      { id = "assassination", name = "Assassination", icon = "ability_rogue_rupture",
        text = ("Each Surge applies DoT %d per Combo spent to its target."):format(RT.assassinDot),
        hooks = {
          onSurge = function(c, src, n, ctx)
            local t = ctx and ctx.target
            if not t or t.dead or t.side ~= "enemy" or c.result or n <= 0 then return end
            local k = Combat.modify(c, "apply", RT.assassinDot * n, "pain", t, ctx.def)
            if k > 0 then Combat.applyStatus(c, t, "pain", k, "poison") end
          end,
        } },
      { id = "combat", name = "Combat", icon = "ability_parry",
        text = ("Each Parry: +%d Combo."):format(RT.combatCombo),
        hooks = {
          onParry = function(c, src)
            if not c.result then Combat.gainRes(c, RT.combatCombo, "talent") end
          end,
        } },
      { id = "subtlety", name = "Subtlety", icon = "ability_stealth",
        text = ("Each time a card grants Stealth, draw %d."):format(RT.subtletyDraw),
        hooks = {
          onStatusApplied = function(c, src, unit, id)
            if id == "stealth" and unit == c.player and c.cls.stealthGained and not c.result then
              Combat.drawCards(c, RT.subtletyDraw)
            end
          end,
        } },
    } },
  { id = "combat_readiness", row = 3, ranks = 2, name = "Combat Readiness", icon = "ability_rogue_shadowstrikes",
    text = { ("Each Parry stops up to %d damage."):format(ns.Rogue.PARRY_STOP + RT.readiness),
      ("Each Parry stops up to %d damage."):format(ns.Rogue.PARRY_STOP + 2 * RT.readiness) },
    const = { PARRY_STOP = function(v, src) return v + RT.readiness * src.rank end } },
  { id = "relentless_strikes", row = 3, ranks = 2, name = "Relentless Strikes", icon = "ability_rogue_slicedice",
    text = { ("After each Surge: +%d Combo."):format(RT.relentless),
      ("After each Surge: +%d Combo."):format(2 * RT.relentless) },
    hooks = {
      onSurge = function(c, src)
        if not c.result then Combat.gainRes(c, RT.relentless * src.rank, "talent") end
      end,
    } },
  TC.fieldMedic({ row = 3 }),

  -- Rangée 4 (16 points) ----------------------------------------------------------------------------------------
  { id = "deeper_stratagem", row = 4, ranks = 2, name = "Deeper Stratagem", icon = "ability_rogue_eviscerate",
    text = { ("Combo cap +%d."):format(RT.stratagem), ("Combo cap +%d."):format(2 * RT.stratagem) },
    hooks = { resCap = function(c, src, v) return v + RT.stratagem * src.rank end } },
  TC.veteransArsenal({ row = 4 }),
  -- Une fois par expédition (exp.talentState.cheatFate, repris du combat par l'expédition).
  { id = "cheat_fate", row = 4, ranks = 2, name = "Cheat Fate", icon = "ability_rogue_cheatdeath",
    text = { ("Once per expedition, a hit that would kill you leaves you at 1 HP with Parry %d."):format(RT.fateParry[1]),
      ("Once per expedition, a hit that would kill you leaves you at 1 HP with Parry %d and Stealth.")
        :format(RT.fateParry[2]) },
    hooks = {
      preventDeath = function(c, src)
        local st = c.tstate
        if not st or st.cheatFate then return false end
        st.cheatFate = true
        c.player.hp = max(c.player.hp, 1) -- (journal : « saved », posé par Combat.kill)
        Combat.applyStatus(c, c.player, "parry", RT.fateParry[src.rank])
        if src.rank >= 2 then Combat.applyStatus(c, c.player, "stealth", 1) end
        return true
      end,
    } },
}

ns.Talent.define("rogue", {
  rows = { 0, 5, 10, 16 },
  nodes = nodes,
  -- Ordre de dépense du bot de simulation (tree=, un id par point ; docs/talents.md, § 8) et voie choisie.
  bot = {
    order = {
      "toughness", "toughness", "toughness", "initiative", "initiative", "elusiveness", "elusiveness",
      "opportunity", "opportunity", "lightning_reflexes", "vile_poisons", "provisions",
      "specialization", "combat_readiness", "combat_readiness", "relentless_strikes", "relentless_strikes",
      "field_medic",
      "deeper_stratagem", "deeper_stratagem", "veterans_arsenal", "veterans_arsenal", "cheat_fate", "cheat_fate",
    },
    spec = "combat",
  },
})
