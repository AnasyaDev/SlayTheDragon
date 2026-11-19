-- Nœuds génériques des arbres de talents (docs/talents.md, § 2.1 : mêmes noms et mêmes effets dans les six arbres,
-- 9 points sur 24). Chaque fonction rend un nœud neuf à placer dans l'arbre d'une classe (Data/Talents/<classe>.lua),
-- avec ses nombres propres (PV par rang de Toughness) ; textes du jeu en anglais, une phrase par rang.
-- Crochets d'expédition (run, Expedition.modify) : startMaxHp, startGold, zoneHeal, startEpics, startEpicOffer.
local _, ns = ...

local TC = {}
ns.TalentCommon = TC

local floor = math.floor

-- Règle commune de Toughness : +TOUGHNESS_SHARE (3 %) des PV de base de la classe par rang, arrondi, au moins 1 :
-- Warrior 2, Druid 2, Rogue 2, Hunter 2, Mage 1, Priest 1. Recalage du 19/11/2026 (docs/equilibrage.md, « Talents :
-- recalage d'ensemble ») : la valeur propre à chaque arbre (2 à 4 PV) donnait au Warrior +12 PV, +12 points au
-- palier 60 %.
TC.TOUGHNESS_SHARE = 0.03
function TC.toughnessHp(class)
  return math.max(1, floor(ns.Classes[class].hp * TC.TOUGHNESS_SHARE + 0.5))
end

-- Toughness : +hp PV max par rang (PV de départ de l'expédition). o = { row = 1, ranks = 3, hp = TC.toughnessHp(c) }.
function TC.toughness(o)
  local hp, ranks = o.hp, o.ranks or 3
  local text = {}
  for r = 1, ranks do text[r] = ("+%d max HP."):format(hp * r) end
  return { id = "toughness", row = o.row or 1, ranks = ranks, name = "Toughness",
    icon = "spell_nature_unyeildingstamina", hp = hp, text = text,
    run = { startMaxHp = function(exp, src, v) return v + hp * src.rank end } }
end

-- Provisions : +gold or de départ (PROVISIONS_GOLD ; 100 avant le recalage du 19/11/2026). o = { row = 2 }.
TC.PROVISIONS_GOLD = 50
function TC.provisions(o)
  local gold = o.gold or TC.PROVISIONS_GOLD
  return { id = "provisions", row = o.row or 2, ranks = 1, name = "Provisions", icon = "inv_misc_bag_10",
    gold = gold, text = { ("Start each expedition with %d more gold."):format(gold) },
    run = { startGold = function(exp, src, v) return v + gold end } }
end

-- Field Medic : le passage d'une zone à la suivante soigne heal des PV max au lieu de Expedition.ZONE_HEAL (50 %).
-- FIELD_MEDIC_HEAL (0,75 avant le recalage du 19/11/2026). o = { row = 3 }.
TC.FIELD_MEDIC_HEAL = 0.65
function TC.fieldMedic(o)
  local heal = o.heal or TC.FIELD_MEDIC_HEAL
  return { id = "field_medic", row = o.row or 3, ranks = 1, name = "Field Medic", icon = "inv_misc_bandage_02",
    heal = heal,
    text = { ("Moving to the next zone heals %d%% of max HP instead of %d%%."):format(floor(heal * 100 + 0.5),
      floor(ns.Expedition.ZONE_HEAL * 100 + 0.5)) },
    run = { zoneHeal = function(exp, src, v) return math.max(v, heal) end } }
end

-- Veteran's Arsenal : une épique au choix au départ parmi ARSENAL_OFFER[rang] tirées au hasard (ns.Rng, flux
-- « talentEpic ») parmi celles des zones que la classe a battues (crochets startEpics et startEpicOffer ; phase
-- « start » de l'expédition, choix « talentEpic », Expedition.new). Recalage du 19/11/2026 : une épique au choix
-- parmi toutes valait +12 à +33 points au palier 100 % (Warrior : Titan's Grip à chaque départ), deux épiques
-- résolvaient la clé 0. o = { row = 4 }.
TC.ARSENAL_OFFER = { 2, 3 }
function TC.veteransArsenal(o)
  local offer = TC.ARSENAL_OFFER
  local text = {}
  for r = 1, 2 do
    text[r] = ("Start each expedition with one of %d random Epic cards of zones you have beaten."):format(offer[r])
  end
  return { id = "veterans_arsenal", row = o.row or 4, ranks = 2, name = "Veteran's Arsenal",
    icon = "inv_sword_04", text = text,
    run = {
      startEpics = function(exp, src, v) return v + 1 end,
      startEpicOffer = function(exp, src, v) return offer[src.rank] end,
    } }
end
