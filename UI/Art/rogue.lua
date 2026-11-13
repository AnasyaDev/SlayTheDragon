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
  -- cartes épiques (une par zone)
  deflection        = I("Ability_Rogue_Dismantle", 13713),
  doomblade         = I("Ability_Rogue_Deathmark", 381673),
  atrophic_poison   = I("Rogue_Paralytic_Poison", 381637),
  echoing_reprimand = I("INV_Ability_Rogue_EchoingReprimand", 323547),
  subterfuge        = I("Rogue_Subterfuge", 108208),
  kidney_shot       = I("Ability_Rogue_KidneyShot", 408),
  danse_macabre     = I("Rogue_Shadow_Reflection", 382528),
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
-- Épique du combat (ns.Rogue, Core/Classes/rogue.lua) : une ligne sous les états du héros, icône de
-- l'épique et ce qu'elle change maintenant (ripostes du tour et la suivante, noms joués, Surge qui compte
-- 5, Surge qui étourdit, Stealth jusqu'à la fin du tour) ; Atrophic Poison : marque sur chaque ennemi qui
-- compte comme Demoralized. N'applique aucune règle : lit le combat.
local STEALTH_ALPHA = 0.45
local EPIC_ICON, MARKS = 22, 6

-- Texte de la ligne de l'épique (nil : rien à montrer). Lu aussi par le harnais.
function Art.rogueEpicLine(c)
  local R = ns.Rogue
  if not R then return nil end
  local id, up = R.epicOf(c)
  if not id then return nil end
  local E, res = R.EPIC, c.player.res or 0
  local k = up and 2 or 1
  if id == "deflection" then
    return ("Ripostes this turn: |cffffffff%d|r   next: |cffffffff%d|r"):format(R.ripostes(c), R.nextRiposte(c))
  elseif id == "danse_macabre" then
    local n = R.namesPlayed(c)
    return ("Card names this turn: |cffffffff%d|r   +%d per hit"):format(n, math.min(n * E.danse_macabre[k], E.danseCap[k]))
  elseif id == "echoing_reprimand" then
    if res == 2 or res == 3 then return ("Surge now counts as |cffffffff%d|r Combo"):format(E.echoing_reprimand[k]) end
  elseif id == "kidney_shot" then
    if res >= E.kidney_shot[k] then return "Surge now stuns the target" end
  elseif id == "subterfuge" then
    local left = R.stealthLeft(c)
    if left == 1 then return "Stealth until the end of the turn" end
    if left and left > 1 then return ("Stealth for |cffffffff%d|r turns"):format(left) end
  end
  return nil
end

-- L'ennemi compte-t-il comme Demoralized par Atrophic Poison (et pas par un vrai Demoralized) ?
function Art.rogueAtrophic(c, e)
  local R = ns.Rogue
  if not (R and R.epicOf(c) == "atrophic_poison") or e.dead then return false end
  return R.countsDemoralized(c, e)
end

ns.ClassViews.rogue = {
  build = function(host, view)
    local W = ns.Widgets
    host:SetScript("OnHide", function()
      local m = view.playerModel
      if m and not m.dead then W.modelAlpha(m, 1) end
    end)
    -- ligne de l'épique : icône (infobulle = la carte) et texte
    local ep = CreateFrame("Frame", nil, host)
    ep:SetSize(EPIC_ICON, EPIC_ICON)
    ep:SetPoint("LEFT", host, "LEFT", 2, 0)
    ep:EnableMouse(true)
    ep.slot = W.slotOn(ep, EPIC_ICON)
    W.tooltip(ep, function(tt, f)
      if f.epicId then W.fillCardTooltip(tt, f.epicId, f.epicUp, { full = true }) end
    end, "ANCHOR_RIGHT")
    ep.text = W.label(host, "bold", 11, Art.C.goldText, "OVERLAY")
    ep.text:SetPoint("LEFT", ep, "RIGHT", 6, 0)
    ep:Hide()
    ep.text:Hide()
    host.epic = ep
    -- marques d'Atrophic Poison (une par ennemi, à droite de son cadre)
    host.marks = {}
    for i = 1, MARKS do
      local mk = CreateFrame("Frame", nil, host)
      mk:SetSize(16, 16)
      mk:SetFrameLevel(host:GetFrameLevel() + 30)
      mk.icon = W.noSnap(mk:CreateTexture(nil, "ARTWORK", nil, 0))
      mk.icon:SetAllPoints()
      W.roundMask(mk, mk.icon)
      W.setIcon(mk.icon, Art.cards.atrophic_poison, "card:atrophic_poison")
      mk.icon:SetDesaturated(true)
      mk:EnableMouse(true)
      W.tooltip(mk, function(tt)
        tt:AddLine("Atrophic Poison", 0.64, 0.21, 0.93)
        tt:AddLine("Has DoT: counts as Demoralized.", 1, 1, 1, true)
      end, "ANCHOR_RIGHT")
      mk:Hide()
      host.marks[i] = mk
    end
  end,
  render = function(host, c, view)
    local W = ns.Widgets
    local m = view.playerModel
    if m and not m.dead then
      W.modelAlpha(m, (c.player.st.stealth or 0) > 0 and STEALTH_ALPHA or 1)
    end
    local ep = host.epic
    local id, up = ns.Rogue.epicOf(c)
    local line = id and Art.rogueEpicLine(c)
    if line then
      if ep.epicId ~= id then W.setIcon(ep.slot.icon, Art.cards[id], "card:" .. id) end
      ep.epicId, ep.epicUp = id, up
      ep.text:SetText(line)
      ep:Show()
      ep.text:Show()
    else
      ep.epicId = nil
      ep:Hide()
      ep.text:Hide()
    end
    local k = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      local s = view.slotOf and view.slotOf[e.uid]
      if k < MARKS and s and s.tag and s:IsShown() and Art.rogueAtrophic(c, e) then
        k = k + 1
        local mk = host.marks[k]
        mk:ClearAllPoints()
        mk:SetPoint("LEFT", s.tag, "RIGHT", 2, 0)
        mk:Show()
      end
    end
    for i = k + 1, MARKS do host.marks[i]:Hide() end
  end,
}
