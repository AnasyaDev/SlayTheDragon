-- Art du Voleur : icônes des cartes et des bibelots, voies, classe, ressource (Combo), états
-- Parry et Stealth, vue de classe (modèle du héros en semi-transparence sous Stealth).
-- Champ `tga` = icône améliorée de Media/Icons (tools/build_media.py --icons-only la copie depuis
-- ~/Téléchargements/ICONS) ; `spell` = repli par l'icône du sort ; `icon` = repli par chemin du client.
local _, ns = ...

local Art = ns.Art
local hex = Art.hex

local function I(tga, spell)
  return { tga = tga, spell = spell, icon = "Interface\\Icons\\" .. tga:lower() }
end

local cards = {
  sinister_strike  = I("Spell_Shadow_RitualOfSacrifice", 1752),
  feint            = I("Ability_Rogue_Feint", 1966),
  backstab         = I("Ability_BackStab", 53),
  eviscerate       = I("Ability_Rogue_Eviscerate", 2098),
  mutilate         = I("Ability_Rogue_ShadowStrikes", 1329),
  garrote          = I("Ability_Rogue_Garrote", 703),
  rupture          = I("Ability_Rogue_Rupture", 1943),
  fan_of_knives    = I("Ability_Rogue_FanofKnives", 51723),
  envenom          = I("Ability_Rogue_Disembowel", 32645),
  cloak_of_shadows = I("Spell_Shadow_NetherCloak", 31224),
  crippling_poison = I("ABILITY_POISONSTING", 3408),
  exsanguinate     = I("ability_deathwing_bloodcorruption_death", 200806),
  deadly_poison    = I("Ability_Rogue_DualWeild", 2823),
  venomous_wounds  = I("ability_rogue_venomouswounds", 79134),
  kick             = I("Ability_Kick", 1766),
  pistol_shot      = I("Ability_Rogue_PistolShot", 185763),
  sprint           = I("Ability_Rogue_Sprint", 2983),
  riposte          = I("Ability_Warrior_Challange", 14251),
  evasion          = I("Spell_Shadow_ShadowWard", 5277),
  blade_flurry     = I("Ability_Warrior_PunishingBlow", 13877),
  slice_and_dice   = I("Ability_Rogue_SliceDice", 5171),
  killing_spree    = I("Ability_Rogue_MurderSpree", 51690),
  between_the_eyes = I("INV_Weapon_Rifle_01", 199804),
  adrenaline_rush  = I("Spell_Shadow_ShadowWordDominate", 13750),
  ambush           = I("Ability_Rogue_Ambush", 8676),
  hemorrhage       = I("Spell_Shadow_LifeDrain", 16511),
  vanish           = I("Ability_Vanish", 1856),
  shadowstep       = I("Ability_Rogue_Shadowstep", 36554),
  cheap_shot       = I("Ability_CheapShot", 1833),
  secret_technique = I("Ability_Rogue_SinisterCalling", 280719),
  nightblade       = I("Ability_Rogue_Nightblade", 195452),
  premeditation    = I("Spell_Shadow_Possession", 14183),
  cheat_death      = I("Ability_Rogue_CheatDeath", 31230),
  smoke_bomb       = I("ability_rogue_smoke", 76577),
  shadow_dance     = I("Ability_Rogue_ShadowDance", 185313),
}
for id, e in pairs(cards) do Art.cards[id] = e end

-- Corps des cartes : départ en or (règle commune), le reste en ivoire (pas d'Absorb chez le Voleur).

Art.paths.assassination = { name = "Assassination", ring = hex("#5e9c3a"), ink = hex("#2f5a17") }
Art.paths.combat        = { name = "Combat",        ring = hex("#c9a227"), ink = hex("#6b5410") }
Art.paths.subtlety      = { name = "Subtlety",      ring = hex("#6a5acd"), ink = hex("#352a7a") }

Art.relics.thieves_tools     = I("INV_Misc_Gear_03")
Art.relics.blinding_powder   = I("INV_Misc_Powder_Purple")
Art.relics.flash_powder      = I("INV_Misc_Powder_Black")
Art.relics.crystal_vial      = I("INV_Alchemy_CrystalVial")
Art.relics.ravenholdt_signet = I("INV_Jewelry_Ring_03")
Art.relics.shadowfang        = I("INV_Sword_07")

-- États propres (jetons sous le héros, explications courtes des cartes : 60 caractères au plus).
Art.statuses.parry   = I("Ability_Parry")
Art.statuses.stealth = I("Ability_Stealth")
Art.statusShort.parry = "each charge stops one hit, up to 8 damage."
Art.statusShort.stealth = "the next Attack played consumes it for a bonus."

-- Icône d'un DoT selon sa source (Combat.applyStatus(..., icon) : poisons du Voleur ; Garrote et
-- Rupture reprennent le saignement du Guerrier).
Art.statusIcons = Art.statusIcons or {}
Art.statusIcons.poison = I("ABILITY_POISONS")
Art.statusIcons.bleed = Art.statusIcons.bleed or I("Ability_Gouge")

Art.classes.rogue = I("ClassIcon_Rogue")
Art.classes.rogue.wow = "ROGUE"
Art.classes.rogue.resource = { tga = "INV_ThrowingKnife_04", icon = "Interface\\Icons\\inv_throwingknife_04",
  color = "goldText" }

-- Vue de classe : sous Stealth, le modèle du héros passe en semi-transparence (indice immédiat) ;
-- rendu à pleine opacité dès que la vue est cachée (autre classe, fin du combat).
local STEALTH_ALPHA = 0.45
ns.ClassViews.rogue = {
  build = function(host, view)
    host:SetScript("OnHide", function()
      local m = view.playerModel
      if m and not m.dead then ns.Widgets.modelAlpha(m, 1) end
    end)
  end,
  render = function(host, c, view)
    local m = view.playerModel
    if not m or m.dead then return end
    ns.Widgets.modelAlpha(m, (c.player.st.stealth or 0) > 0 and STEALTH_ALPHA or 1)
  end,
}
