-- Arbre de talents du Rogue (docs/talents.md, § 8 ; contrat : docs/talents.md, « Contrat du socle des talents » ;
-- modèle : Data/Talents/warrior.lua). 14 nœuds, 24 points ; 8 nœuds de mécanique (Combo, Stealth, Parry, DoT), un
-- Specialization, un nœud « une fois par expédition », 4 génériques (ns.TalentCommon). Nombres réglables dans RT
-- (lus à chaque usage : tune=RogueTalents.CLE=n) ; les textes les disent (vérifié par Sim/tests_talents_rogue.lua).
local _, ns = ...

local Combat = ns.Combat
local TC = ns.TalentCommon
local max = math.max

local RT = {
  hp = TC.toughnessHp("rogue"), -- Toughness : PV max par rang (règle commune, ns.TalentCommon)
  initiative = { 1 },  -- Initiative : Combo au début d'un combat d'élite ou de boss (deux rangs, +1 / +2 à chaque
                       --   combat, avant le recalage du 19/11/2026)
  elusive = 1,         -- Elusiveness : Parry au début d'un combat d'élite ou de boss
  opportunity = 1,     -- Opportunity : dégâts de plus par coup d'une Attack jouée sous Stealth, par rang
  vile = 1,            -- Vile Poisons : DoT de plus à chaque DoT posé sur un ennemi
  reflexes = 1,        -- Lightning Reflexes : plafond de Parry +1
  readiness = 1,       -- Combat Readiness : dégâts arrêtés de plus par charge de Parry, par rang
  relentless = 1,      -- Relentless Strikes : Combo après un Surge…
  relentlessAt = { 5, 4 }, --   … d'au moins relentlessAt[rang] Combo (1 : après chaque Surge)
  assassinDot = 1,     -- Specialization Assassination : DoT posé sur la cible par Combo dépensé
  combatCombo = 1,     -- Specialization Combat : Combo à chaque Parry
  subtletyDraw = 1,    -- Specialization Subtlety : cartes piochées quand une carte donne Stealth
  stratagem = 1,       -- Deeper Stratagem : plafond de Combo, par rang
  fateParry = { 0, 2 }, -- Cheat Fate : Parry donné en évitant la mort, par rang (Parry 2 puis Parry 3 et
                       --   Stealth avant le recalage du 19/11/2026)
}
ns.RogueTalents = RT

local function plural(n, word) return n == 1 and word or (word .. "s") end
-- Combat d'élite ou de boss (Elusiveness, Initiative ; recalage du 19/11/2026 : à chaque combat, ils valaient +10
-- et +7 points dans l'arbre au palier 60 %).
local function bigFight(c) return c.kind == "elite" or c.kind == "boss" end
-- Texte de Cheat Fate au rang r.
local function fateText(r)
  local n = RT.fateParry[r]
  if n <= 0 then return "Once per expedition, a hit that would kill you leaves you at 1 HP." end
  return ("Once per expedition, a hit that would kill you leaves you at 1 HP with Parry %d."):format(n)
end
-- Texte de Relentless Strikes au rang r.
local function relentlessText(r)
  if RT.relentlessAt[r] <= 1 then return ("After each Surge: +%d Combo."):format(RT.relentless) end
  return ("After a Surge of %d Combo or more: +%d Combo."):format(RT.relentlessAt[r], RT.relentless)
end

-- Coup d'une carte Attack jouée sous Stealth (elle a consommé Stealth, ou en a profité sous Subterfuge) : la
-- carte en cours de résolution (c.cardCtx) est dans c.cls.openers (Core/Classes/rogue.lua).
local function fromStealth(c, d)
  if not d or d.type ~= "attack" then return false end
  local ctx = c.cardCtx
  local o = c.cls and c.cls.openers
  return ctx ~= nil and ctx.def == d and ctx.card ~= nil and o ~= nil and o[tostring(ctx.card.uid)] == true
end

local nodes = {
  -- Rangée 1 (ouverte d'emblée) -----------------------------------------------------------------------------------
  TC.toughness({ row = 1, ranks = 3, hp = RT.hp }),
  -- (rangée 3 et un rang avant le recalage du 19/11/2026)
  { id = "lightning_reflexes", row = 1, ranks = 3, name = "Lightning Reflexes", icon = "spell_shadow_shadowward",
    text = { ("Parry can hold %d more %s."):format(RT.reflexes, plural(RT.reflexes, "charge")),
      ("Parry can hold %d more %s."):format(2 * RT.reflexes, plural(2 * RT.reflexes, "charge")),
      ("Parry can hold %d more %s."):format(3 * RT.reflexes, plural(3 * RT.reflexes, "charge")) },
    const = { PARRY_MAX = function(v, src) return v + RT.reflexes * src.rank end } },

  -- (rangée 2 avant le recalage du 19/11/2026)
  { id = "opportunity", row = 1, ranks = 2, name = "Opportunity", icon = "ability_backstab",
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

  -- Rangée 2 (5 points) -------------------------------------------------------------------------------------------
  -- (rangée 1 et deux rangs avant le recalage du 19/11/2026)
  { id = "deeper_stratagem", row = 2, ranks = 3, name = "Deeper Stratagem", icon = "ability_rogue_eviscerate",
    text = { ("Combo cap +%d."):format(RT.stratagem), ("Combo cap +%d."):format(2 * RT.stratagem),
      ("Combo cap +%d."):format(3 * RT.stratagem) },
    hooks = { resCap = function(c, src, v) return v + RT.stratagem * src.rank end } },
  { id = "vile_poisons", row = 2, ranks = 1, name = "Vile Poisons", icon = "ability_rogue_dualweild",
    text = { ("Each time DoT is applied to an enemy, apply %d more."):format(RT.vile) },
    hooks = {
      apply = function(c, src, n, id)
        if id == "pain" and n > 0 then return n + RT.vile end
        return n
      end,
    } },
  -- (trois rangs avant le recalage du 19/11/2026)
  { id = "combat_readiness", row = 2, ranks = 1, name = "Combat Readiness", icon = "ability_rogue_shadowstrikes",
    text = { ("Each Parry stops up to %d damage."):format(ns.Rogue.PARRY_STOP + RT.readiness) },
    const = { PARRY_STOP = function(v, src) return v + RT.readiness * src.rank end } },
  TC.provisions({ row = 2 }),

  -- Rangée 3 (10 points) ------------------------------------------------------------------------------------------
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
  { id = "elusiveness", row = 3, ranks = 1, name = "Elusiveness", icon = "ability_rogue_feint",
    text = { ("Start of combat against elites and bosses: gain Parry %d."):format(RT.elusive) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result and bigFight(c) then Combat.applyStatus(c, c.player, "parry", RT.elusive) end
      end,
    } },
  -- (contre les élites et les boss seulement, c.kind)
  { id = "initiative", row = 3, ranks = 1, name = "Initiative", icon = "ability_rogue_ambush",
    text = { ("Start of combat against elites and bosses: +%d Combo."):format(RT.initiative[1]) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result and bigFight(c) then Combat.gainRes(c, RT.initiative[src.rank], "talent") end
      end,
    } },
  TC.fieldMedic({ row = 3 }),

  -- Rangée 4 (16 points) ------------------------------------------------------------------------------------------
  { id = "relentless_strikes", row = 4, ranks = 2, name = "Relentless Strikes", icon = "ability_rogue_slicedice",
    text = { relentlessText(1), relentlessText(2) },
    hooks = {
      onSurge = function(c, src, n)
        if not c.result and (n or 0) >= RT.relentlessAt[src.rank] then
          Combat.gainRes(c, RT.relentless, "talent")
        end
      end,
    } },
  TC.veteransArsenal({ row = 4 }),
  -- Une fois par expédition (exp.talentState.cheatFate, repris du combat par l'expédition).
  { id = "cheat_fate", row = 4, ranks = 2, name = "Cheat Fate", icon = "ability_rogue_cheatdeath",
    text = { fateText(1), fateText(2) },
    hooks = {
      preventDeath = function(c, src)
        local st = c.tstate
        if not st or st.cheatFate then return false end
        st.cheatFate = true
        c.player.hp = max(c.player.hp, 1) -- (journal : « saved », posé par Combat.kill)
        local n = RT.fateParry[src.rank]
        if n > 0 then Combat.applyStatus(c, c.player, "parry", n) end
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
      "toughness", "toughness", "toughness", "opportunity", "opportunity",
      "lightning_reflexes", "lightning_reflexes", "deeper_stratagem", "deeper_stratagem", "deeper_stratagem",
      "provisions", "combat_readiness", "specialization", "vile_poisons", "lightning_reflexes",
      "elusiveness", "initiative", "field_medic", "relentless_strikes", "relentless_strikes",
      "veterans_arsenal", "veterans_arsenal", "cheat_fate", "cheat_fate",
    },
    spec = "combat",
  },
})
