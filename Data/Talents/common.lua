-- Nœuds génériques des arbres de talents (docs/talents.md, § 2.1 : mêmes noms et mêmes effets dans les six arbres,
-- 9 points sur 24). Chaque fonction rend un nœud neuf à placer dans l'arbre d'une classe (Data/Talents/<classe>.lua),
-- avec ses nombres propres (PV par rang de Toughness) ; textes du jeu en anglais, une phrase par rang.
-- Crochets d'expédition (run, Expedition.modify) : startMaxHp, startGold, zoneHeal, startEpics.
local _, ns = ...

local TC = {}
ns.TalentCommon = TC

local floor = math.floor

-- Toughness : +hp PV max par rang (PV de départ de l'expédition). o = { row = 1, ranks = 3, hp = 4 }.
function TC.toughness(o)
  local hp, ranks = o.hp, o.ranks or 3
  local text = {}
  for r = 1, ranks do text[r] = ("+%d max HP."):format(hp * r) end
  return { id = "toughness", row = o.row or 1, ranks = ranks, name = "Toughness", icon = "spell_holy_devotion",
    hp = hp, text = text,
    run = { startMaxHp = function(exp, src, v) return v + hp * src.rank end } }
end

-- Provisions : +gold or de départ. o = { row = 2, gold = 100 }.
function TC.provisions(o)
  local gold = o.gold or 100
  return { id = "provisions", row = o.row or 2, ranks = 1, name = "Provisions", icon = "inv_misc_bag_10",
    gold = gold, text = { ("Start each expedition with %d more gold."):format(gold) },
    run = { startGold = function(exp, src, v) return v + gold end } }
end

-- Field Medic : le passage d'une zone à la suivante soigne heal des PV max au lieu de Expedition.ZONE_HEAL (50 %).
-- o = { row = 3, heal = 0.75 }.
function TC.fieldMedic(o)
  local heal = o.heal or 0.75
  return { id = "field_medic", row = o.row or 3, ranks = 1, name = "Field Medic", icon = "inv_misc_bandage_02",
    heal = heal,
    text = { ("Moving to the next zone heals %d%% of max HP instead of %d%%."):format(floor(heal * 100 + 0.5),
      floor(ns.Expedition.ZONE_HEAL * 100 + 0.5)) },
    run = { zoneHeal = function(exp, src, v) return math.max(v, heal) end } }
end

-- Veteran's Arsenal : rang 1, une épique au choix au départ parmi celles des zones que la classe a battues ;
-- rang 2, une de plus (le plafond d'épiques du deck est déjà sans limite : Expedition.EPIC.max = 0). Phase
-- « start » de l'expédition (choix « talentEpic », Expedition.new). o = { row = 4 }.
function TC.veteransArsenal(o)
  return { id = "veterans_arsenal", row = o.row or 4, ranks = 2, name = "Veteran's Arsenal",
    icon = "inv_sword_04",
    text = { "Start each expedition with one Epic card of a zone you have beaten.",
      "Start each expedition with two Epic cards of zones you have beaten." },
    run = { startEpics = function(exp, src, v) return v + src.rank end } }
end
