-- Arbre de talents du Druid (docs/talents.md, § 7 ; contrat : docs/talents.md, « Contrat du socle des talents »).
-- 14 nœuds, 24 points ; 10 nœuds de mécanique (formes, réserve, taxe, effets de fin de tour), 4 génériques
-- (ns.TalentCommon). Nombres réglables dans DT (lus à chaque usage : tune=DruidTalents.CLE=n) ; les textes les
-- disent (vérifié par Sim/tests_talents_druid.lua). Constantes de classe changées par Combat.const (TAX_FREE,
-- TAX, TAX_MAX, STRIKE_BASE, TREE_ABSORB, PULSE_BONUS : Core/Classes/druid.lua), jamais sur le module.
-- Réglé le 19/11/2026 au bot human (docs/equilibrage.md, « Talents du Druid ») : les nœuds de la fiche (§ 7)
-- donnaient 68 % au palier 40 et 91 % au palier 60 ; chaque Absorb gagné à chaque tour ou mana rendu vaut
-- beaucoup près du mur, d'où des nœuds à un rang et des Absorb de 1 ou 2.
local _, ns = ...

local Combat = ns.Combat
local TC = ns.TalentCommon
local max, min = math.max, math.min

local DT = {
  hp = TC.toughnessHp("druid"), -- Toughness : PV max par rang (règle commune, ns.TalentCommon)
  primal = 1,          -- Primal Instinct : réserve au début d'un combat d'élite ou de boss, par rang
  taxMax = 1,          -- Natural Shapeshifter 1 : mana perdu au plus par la taxe (au lieu de Druid.TAX_MAX, 2)
  strike = 1,          -- Feral Instinct : dégâts de plus de la frappe de l'ours (un rang ; 2 rangs : +7,7 seul)
  moonglow = 1,        -- Moonglow : Absorb à la fin d'un tour fini en Moonkin, par rang
  seed = 1,            -- Living Seed : Absorb de plus à la fin d'un tour fini en Tree of Life, par rang
  combo = 1,           -- Specialization Feral : réserve gagnée quand Clearcasting est posé
  pulse = 1,           -- Specialization Balance : dégâts de plus du coup à tous de fin de tour en Moonkin
  regen = 1,           -- Specialization Restoration : Regen de plus à chaque Regen gagnée
  cap = 1,             -- Wild Reserve : plafond de la réserve, par rang
  ward = { 1 },        -- Shapeshifter's Ward : Absorb au premier changement de forme de chaque tour (un rang ; deux
                       --   rangs, 1 puis 2 Absorb, avant le recalage du 19/11/2026)
  masterFree = 1,      -- Master Shapeshifter : changements comptés gratuits de plus par tour (un rang ; 2 : +15,8 seul)
  saveAbsorb = 10,     -- Survival Instincts : Absorb donnée en évitant la mort, par rang au-delà du premier
}
ns.DruidTalents = DT

local function form(c) return c.cls and c.cls.form or nil end

local nodes = {
  -- Rangée 1 (ouverte d'emblée) ----------------------------------------------------------------------------------
  TC.toughness({ row = 1, ranks = 3, hp = DT.hp }),
  -- (avec Heart of the Wild, la réserve gagnée va à la réserve sans forme, comme toute réserve d'avant la forme)
  -- (un rang, à chaque combat, avant le recalage du 19/11/2026)
  { id = "primal_instinct", row = 1, ranks = 3, name = "Primal Instinct", icon = "ability_druid_catform",
    text = { ("Start of combat against elites and bosses: +%d Reserve."):format(DT.primal),
      ("Start of combat against elites and bosses: +%d Reserve."):format(2 * DT.primal),
      ("Start of combat against elites and bosses: +%d Reserve."):format(3 * DT.primal) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result and (c.kind == "elite" or c.kind == "boss") then
          Combat.gainRes(c, DT.primal * src.rank, "talent")
        end
      end,
    } },
  -- rang 2 : l'entrée dans la première forme du combat (depuis « sans forme ») n'est pas comptée pour la taxe
  -- (c.cls.taxed, compteur de classe du tour ; un changement gratuit de plus à chaque tour valait +3,6 dans l'arbre
  -- au palier 60 %, +7,5 seul au palier 40 %)
  { id = "natural_shapeshifter", row = 1, ranks = 2, name = "Natural Shapeshifter", icon = "spell_nature_wispsplode",
    text = { ("The shift tax costs at most %d mana."):format(DT.taxMax),
      ("The shift tax costs at most %d mana, and entering the first form each combat is free of it."):format(
        DT.taxMax) },
    const = { TAX_MAX = function(v) return min(v, DT.taxMax) end },
    hooks = {
      onShift = function(c, src, from)
        if src.rank >= 2 and from == nil and (c.cls.taxed or 0) > 0 then c.cls.taxed = c.cls.taxed - 1 end
      end,
    } },
  -- (rangée 2 avant le recalage du 19/11/2026 : seul, il ne vaut presque rien)
  { id = "living_seed", row = 1, ranks = 3, name = "Living Seed", icon = "inv_misc_flower_02",
    text = { ("End of turn in Tree of Life: gain %d more Absorb."):format(DT.seed),
      ("End of turn in Tree of Life: gain %d more Absorb."):format(2 * DT.seed),
      ("End of turn in Tree of Life: gain %d more Absorb."):format(3 * DT.seed) },
    const = { TREE_ABSORB = function(v, src) return v + DT.seed * src.rank end } },

  -- Rangée 2 (5 points) -----------------------------------------------------------------------------------------
  { id = "feral_instinct", row = 2, ranks = 1, name = "Feral Instinct", icon = "inv_misc_bearpaw_brown",
    text = { ("Bear strikes deal %d more."):format(DT.strike) },
    const = { STRIKE_BASE = function(v) return v + DT.strike end } },
  -- (deux rangs avant le recalage du 19/11/2026)
  { id = "moonglow", row = 2, ranks = 1, name = "Moonglow", icon = "ability_upgrademoonglaive",
    text = { ("End of turn in Moonkin: gain %d Absorb."):format(DT.moonglow) },
    hooks = {
      onTurnEnd = function(c, src)
        if form(c) == "moonkin" and not c.result then Combat.gainBlock(c, c.player, DT.moonglow * src.rank) end
      end,
    } },
  TC.provisions({ row = 2 }),

  -- Rangée 3 (10 points) ----------------------------------------------------------------------------------------
  { id = "specialization", row = 3, ranks = 1, name = "Specialization", icon = "classicon_druid",
    choices = {
      -- Clearcasting posé (fin de tour en Cat, s'il n'était pas déjà posé) : +1 Combo
      { id = "feral", name = "Feral", icon = "ability_racial_bearform",
        text = ("Clearcasting also gives +%d Combo."):format(DT.combo),
        hooks = {
          onStatusApplied = function(c, src, unit, id)
            if id == "clearcasting" and unit == c.player and not c.result then
              Combat.gainRes(c, DT.combo, "talent")
            end
          end,
        } },
      { id = "balance", name = "Balance", icon = "spell_nature_starfall",
        text = ("End of turn in Moonkin: deal %d more to each enemy."):format(DT.pulse),
        const = { PULSE_BONUS = function(v) return v + DT.pulse end } },
      { id = "restoration", name = "Restoration", icon = "spell_nature_healingtouch",
        text = ("Regen you gain is %d higher."):format(DT.regen),
        hooks = {
          applySelf = function(c, src, v, id)
            if id == "regen" then return v + DT.regen end
            return v
          end,
        } },
    } },
  -- (deux rangs avant le recalage du 19/11/2026)
  { id = "wild_reserve", row = 3, ranks = 1, name = "Wild Reserve", icon = "inv_misc_monsterfang_01",
    text = { ("Reserve cap +%d."):format(DT.cap) },
    hooks = { resCap = function(c, src, v) return v + DT.cap * src.rank end } },
  -- premier changement de forme du tour (compteur de classe c.cls.shifts, remis à 0 au début du tour ; le
  -- premier changement du combat compris)
  -- (deux rangs, 1 puis 2 Absorb, avant le recalage du 19/11/2026)
  { id = "shapeshifters_ward", row = 3, ranks = 1, name = "Shapeshifter's Ward", icon = "spell_nature_enchantarmor",
    text = { ("The first form change each turn: gain %d Absorb."):format(DT.ward[1]) },
    hooks = {
      onShift = function(c, src)
        if c.cls.shifts == 1 and not c.result then Combat.gainBlock(c, c.player, DT.ward[src.rank]) end
      end,
    } },
  TC.fieldMedic({ row = 3 }),

  -- Rangée 4 (16 points) ----------------------------------------------------------------------------------------
  { id = "master_shapeshifter", row = 4, ranks = 1, name = "Master Shapeshifter", icon = "inv_misc_idol_02",
    text = { ("%s each turn %s free of the shift tax."):format(
        DT.masterFree == 1 and "One more form change" or (DT.masterFree .. " more form changes"),
        DT.masterFree == 1 and "is" or "are") },
    const = { TAX_FREE = function(v) return v + DT.masterFree end } },
  TC.veteransArsenal({ row = 4 }),
  -- Une fois par expédition (exp.talentState.survival, repris du combat par l'expédition). Rebirth reste le Last
  -- Breath de combat (Power : passe avant les talents).
  { id = "survival_instincts", row = 4, ranks = 3, name = "Survival Instincts", icon = "inv_misc_bearpaw_black",
    text = { "Once per expedition, a hit that would kill you leaves you at 1 HP in Bear.",
      ("Once per expedition, a hit that would kill you leaves you at 1 HP in Bear with %d Absorb.")
        :format(DT.saveAbsorb),
      ("Once per expedition, a hit that would kill you leaves you at 1 HP in Bear with %d Absorb.")
        :format(2 * DT.saveAbsorb) },
    hooks = {
      preventDeath = function(c, src)
        local st = c.tstate
        if not st or st.survival then return false end
        st.survival = true
        c.player.hp = max(c.player.hp, 1) -- (journal : « saved », posé par Combat.kill)
        if form(c) ~= "bear" then ns.Druid.shift(c, "bear") end
        if src.rank >= 2 then Combat.gainBlock(c, c.player, DT.saveAbsorb * (src.rank - 1)) end
        return true
      end,
    } },
}

ns.Talent.define("druid", {
  rows = { 0, 5, 10, 16 },
  nodes = nodes,
  -- Ordre de dépense du bot de simulation (tree=, un id par point ; docs/talents.md, § 7) et voie choisie. Recalage
  -- du 19/11/2026 : les nœuds les plus faibles d'abord (Living Seed, Primal Instinct), Toughness au 9e point, Natural
  -- Shapeshifter et Feral Instinct après le palier 60 % (le contenu seul du Druid vaut déjà 28,5 % au palier 40 %).
  bot = {
    order = {
      "living_seed", "living_seed", "living_seed", "primal_instinct", "primal_instinct",
      "moonglow", "provisions", "primal_instinct", "toughness", "toughness",
      "toughness", "specialization", "wild_reserve", "field_medic", "shapeshifters_ward",
      "feral_instinct", "natural_shapeshifter", "natural_shapeshifter", "master_shapeshifter", "survival_instincts",
      "veterans_arsenal", "veterans_arsenal", "survival_instincts", "survival_instincts",
    },
    spec = "feral",
    -- accord des épiques avec l'arbre : aucun écart. Mesuré à l'arbre plein (zones=7) : Veteran's Arsenal 2 vaut
    -- +6,5 points (90,7 % contre 84,2 sans), le bot prend Mark of Ursol, Owlkin Frenzy, Lifebloom, King of the
    -- Jungle et Heart of the Wild, jamais Eclipse ni Furor ; rien ne contredit l'arbre comme Thunderous Roar celui
    -- du Warrior (Heart of the Wild borne la réserve à 5 : Wild Reserve ne sert plus, Primal Instinct remplit la
    -- réserve sans forme ; pris quand même, +7 points avec / sans).
    epic = {},
  },
})
