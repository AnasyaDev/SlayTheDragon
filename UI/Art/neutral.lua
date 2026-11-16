-- Art du contenu commun à toutes les classes : cartes neutres (docs/cartes-neutres.md) et bibelots
-- communs ajoutés (docs/bibelots-communs.md, bloc à part de Data/Relics.lua).
-- Champ `tga` = icône améliorée de Media/Icons (tools/build_media.py --icons-only la copie depuis
-- le pack d'icônes local) ; `icon` = repli par chemin du client.
local _, ns = ...

local Art = ns.Art
local hex = Art.hex

local function I(tga)
  return { tga = tga, icon = "Interface\\Icons\\" .. tga:lower() }
end

local cards = {
  rough_dynamite             = I("INV_Misc_Bomb_06"),
  heavy_silk_bandage         = I("INV_Misc_Bandage_02"),
  rugged_armor_kit           = I("INV_Misc_ArmorKit_09"),
  smoked_desert_dumplings    = I("INV_Misc_Food_64"),
  runecloth_bag              = I("INV_Misc_Bag_13"),
  iron_grenade               = I("INV_Misc_Bomb_08"),
  arcane_bomb                = I("INV_Misc_Bomb_04"),
  elixir_of_superior_defense = I("INV_Potion_86"),
  black_lotus                = I("INV_Misc_Herb_BlackLotus"),
  goblin_sapper_charge       = I("Spell_Fire_SelfDestruct"),
}
for id, e in pairs(cards) do Art.cards[id] = e end

-- Voie « Neutral » : médaillon gris (cartes sans classe).
Art.paths.neutral = { name = "Neutral", ring = hex("#9a9a92"), ink = hex("#4a4a44") }

-- Corps des cartes neutres : ivoire teinté vert sauge (Art.cardBodyTint), quel que soit le premier
-- effet ; la carte se distingue d'un coup d'œil des cartes de classe sans texture de plus.
Art.bodyTints = Art.bodyTints or {}
Art.bodyTints.neutral = { 0.78, 0.95, 0.80 }

-- Mot-clé de l'infobulle : carte neutre (W.cardKeywords).
Art.keywords.neutral = { name = "Neutral", text = "a card that every class can use." }

-- Bibelots communs ajoutés (Data/Relics.lua, bloc « Bibelots communs (fiche) »).
local relics = {
  scroll_of_intellect          = I("INV_Scroll_01"),
  bloodsail_admirals_hat       = I("INV_Helmet_66"),
  herb_pouch                   = I("INV_Misc_Bag_HerbPouch"),
  lifegiving_gem               = I("INV_Misc_Gem_Pearl_05"),
  darkmoon_prize_ticket        = I("INV_Misc_Ticket_Darkmoon_01"),
  head_of_onyxia               = I("INV_Misc_Head_Dragon_01"),
  demonic_rune                 = I("INV_Misc_Rune_04"),
  brilliant_mana_oil           = I("INV_Potion_100"),
  talisman_of_ephemeral_power  = I("INV_Misc_StoneTablet_11"),
  philosophers_stone           = I("INV_Misc_Gem_Bloodstone_01"),
  mark_of_the_champion         = I("INV_Trinket_Naxxramas02"),
  onyxia_scale_cloak           = I("INV_Misc_Cape_05"),
  hourglass_sand               = I("INV_Misc_Dust_02"),
  bag_of_marbles               = I("INV_MISC_BAG_10_BLUE"),
  flint_and_tinder             = I("INV_Tinderbox"),
  harm_prevention_belt         = I("INV_Belt_29"),
  ironfoe                      = I("INV_Mace_15"),
  royal_seal_of_eldre_thalas   = I("INV_Jewelry_Ring_27"),
  drake_fang_talisman          = I("INV_Misc_Bone_09"),
  travelers_backpack           = I("INV_Misc_Bag_11"),
}
for id, e in pairs(relics) do Art.relics[id] = e end
