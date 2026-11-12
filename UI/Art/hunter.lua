-- Art du Chasseur : icônes des cartes et des bibelots, voies, classe et ressource (Frenzy), vue de classe
-- (familier dans la scène, cible du familier, Traps posées).
-- Champ `tga` = icône améliorée de Media/Icons (tools/build_media.py --icons-only la copie depuis
-- ~/Téléchargements/ICONS) ; `icon` = repli par chemin du client.
local _, ns = ...

local Art = ns.Art
local hex = Art.hex

local function I(tga, spell)
  return { tga = tga, spell = spell, icon = "Interface\\Icons\\" .. tga:lower() }
end

local cards = {
  arcane_shot      = I("Ability_ImpalingBolt"),
  disengage        = I("Ability_Rogue_Feint"),
  serpent_sting    = I("Ability_Hunter_Quickshot"),
  freezing_trap    = I("Spell_Frost_ChainsOfIce"),
  kill_command     = I("Ability_Hunter_KillCommand"),
  cobra_shot       = I("Ability_Hunter_CobraShot"),
  barbed_shot      = I("Ability_Hunter_BarbedShot"),
  dire_beast       = I("Ability_Hunter_SickEm"),
  growl            = I("Ability_Physical_Taunt"),
  intimidation     = I("Ability_Devour"),
  multi_shot       = I("Ability_UpgradeMoonGlaive"),
  spirit_bond      = I("Ability_Druid_DemoralizingRoar"),
  bestial_wrath    = I("Ability_Druid_FerociousBite"),
  the_beast_within = I("Ability_Hunter_BeastWithin"),
  aimed_shot       = I("Ability_Hunter_AimedShot"),
  steady_shot      = I("Ability_Hunter_SteadyShot"),
  hunters_mark     = I("Ability_Hunter_SniperShot"),
  concussive_shot  = I("Spell_Frost_Stun"),
  rapid_fire       = I("Ability_Hunter_RunningShot"),
  counter_shot     = I("INV_Ammo_Arrow_03"),
  volley           = I("Ability_Marksmanship"),
  readiness        = I("Ability_Hunter_Readiness"),
  trueshot_aura    = I("Ability_TrueShot"),
  wailing_arrow    = I("INV_Bow_1H_SylvanasShadowlands_D_01"),
  immolation_trap  = I("Spell_Fire_Immolation"),
  counterattack    = I("Ability_Warrior_Challange"),
  frost_trap       = I("Spell_Frost_FreezingBreath"),
  raptor_strike    = I("Ability_MeleeDamage"),
  explosive_trap   = I("Spell_Fire_SelfDestruct"),
  wyvern_sting     = I("INV_Spear_02"),
  entrapment       = I("Spell_Nature_StrangleVines"),
  lock_and_load    = I("Ability_Hunter_LockAndLoad"),
  feign_death      = I("Ability_Rogue_FeignDeath"),
  resourcefulness  = I("Ability_Hunter_Resourcefulness"),
}
for id, e in pairs(cards) do Art.cards[id] = e end

Art.paths.beast_mastery = { name = "Beast Mastery", ring = hex("#a8642e"), ink = hex("#5e3010") }
Art.paths.marksmanship  = { name = "Marksmanship",  ring = hex("#6f9a4a"), ink = hex("#33521c") }
Art.paths.survival      = { name = "Survival",      ring = hex("#4f8a86"), ink = hex("#1f4a47") }

Art.relics.pet_whistle   = I("INV_Misc_Whistle_Color1")
Art.relics.kiblers_bits  = I("INV_Misc_Food_49")
Art.relics.light_quiver  = I("INV_Misc_Quiver_01")
Art.relics.net_o_matic   = I("INV_Misc_Net_01")
Art.relics.devilsaur_eye = I("INV_Misc_Eye_01")
Art.relics.rhokdelar     = I("INV_Weapon_Bow_08")

-- Icône d'un DoT selon sa source (apply … icon = clé) : piqûres (Serpent Sting, Wyvern Sting), feu des Traps.
Art.statusIcons = Art.statusIcons or {}
Art.statusIcons.sting = I("Ability_Hunter_Quickshot")
Art.statusIcons.immolation = I("Spell_Fire_Immolation")
Art.statusIcons.bleed = Art.statusIcons.bleed or I("Ability_Gouge")

Art.classes.hunter = I("ClassIcon_Hunter")
Art.classes.hunter.wow = "HUNTER"
Art.classes.hunter.resource = { tga = "Ability_Hunter_FerociousInspiration",
  icon = "Interface\\Icons\\ability_hunter_ferociousinspiration", color = "attackText" }

-- Familier : modèle 3D (Young Wolf de la forêt d'Elwynn, puis Mangy Wolf ; identifiants relevés dans
-- Cache/WDB/enUS/creaturecache.wdb du client Forever), repli en médaillon à l'icône du loup.
Art.pet = { creature = 299, display = { 447, 903 }, icon = I("Ability_Hunter_Pet_Wolf"), name = "Wolf" }
Art.petMark = I("Ability_Hunter_Pet_Wolf") -- marqueur de la cible du familier

---------------------------------------------------------------------------
-- Vue de classe (ns.ClassViews.hunter, docs/classes.md) : familier à droite du héros, un peu plus bas,
-- dans la scène ; nom au-dessus (étage f.ui, au-dessus des modèles) ; marqueur sur sa cible ; Traps
-- posées en jetons carrés devant les pieds du héros (la plus ancienne à gauche), infobulle = la carte.
-- N'applique aucune règle : lit le combat (ns.Hunter.petTarget / petDamage pour l'affichage).
---------------------------------------------------------------------------
if not CreateFrame then return end -- hors du jeu (Sim/load.lua saute UI\, garde-fou)

local HERO_X, HERO_FEET = 196, 292 -- UI/CombatView.lua (centre du héros, pieds)
local PET_W, PET_H = 120, 110
local PET_X, PET_FEET = HERO_X + 112, HERO_FEET + 14
local TRAP_SIZE, TRAP_GAP = 30, 4
local TRAP_Y = HERO_FEET + 30

local V = {}
ns.ClassViews.hunter = V

local function petTooltip(tt)
  local c = ns.Controller.combat()
  if not c or c.class ~= "hunter" then return end
  local H = ns.Hunter
  tt:AddLine(Art.pet.name, 1, 0.82, 0)
  local t = H.petTarget(c)
  local name = t and ns.Enemies[t.id] and ns.Enemies[t.id].name
  if t then
    tt:AddLine(("Attacks %s for %d at the end of the turn."):format(name or "?", H.petDamage(c, t)), 1, 1, 1, true)
  end
  tt:AddLine(Art.keywordLine("res:frenzy"), 1, 1, 1, true)
  tt:AddLine("The pet attacks the last enemy targeted.", 0.8, 0.8, 0.8, true)
end

function V.build(host, view)
  local W, Scene = ns.Widgets, ns.Scene
  local parent = view.parent
  -- familier : figure de la scène (ombre, modèle, repli, étage f.ui), au niveau du héros
  local pet = Scene.figure(parent, PET_W, PET_H)
  Scene.at(pet, parent, PET_X - PET_W / 2, PET_FEET - PET_H, PET_W, PET_H)
  pet:SetFrameLevel(view.hero:GetFrameLevel())
  pet.model:SetFrameLevel(pet:GetFrameLevel() + 1)
  pet.fallback:SetFrameLevel(pet.model:GetFrameLevel() + 2)
  pet.ui:SetFrameLevel(pet.model:GetFrameLevel() + Scene.UI_LIFT)
  pet.flash = W.disc(pet.ui, "OVERLAY", 0, Art.C.hp, 0)
  pet.flash:SetSize(70, 70)
  pet.flash:SetPoint("CENTER", 0, 0)
  pet:EnableMouse(true)
  W.tooltip(pet, petTooltip, "ANCHOR_RIGHT")
  Scene.setName(pet, Art.pet.name, 12)
  host.pet = pet
  -- le familier suit la zone de classe (cachée quand le combat est d'une autre classe)
  host:SetScript("OnHide", function() pet:Hide() end)
  host:SetScript("OnShow", function() pet:Show() end)
  host.petX = PET_X - PET_W / 2
  host.petY = PET_FEET - PET_H
  W.setFallbackArt(pet.fallback, Art.pet.icon)
  pet.fallback:Hide()
  W.setCreatureArt(pet.model, Art.pet, "pet:hunter", function() pet.fallback:Show() end,
    function() pet.fallback:Hide() end)
  if pet.model.SetFacing then pet.model:SetFacing(0.9) end
  -- marqueur de la cible du familier : petite icône ronde à gauche du cadre de l'ennemi visé
  local mark = CreateFrame("Frame", nil, host)
  mark:SetSize(18, 18)
  mark:SetFrameLevel(host:GetFrameLevel() + 30)
  mark.icon = W.noSnap(mark:CreateTexture(nil, "ARTWORK", nil, 0))
  mark.icon:SetAllPoints()
  W.roundMask(mark, mark.icon)
  W.setIcon(mark.icon, Art.petMark, "ui:petmark")
  mark.ring = W.wow(mark, "ring_small", "ARTWORK", 1)
  mark.ring:SetPoint("TOPLEFT", -3, 3)
  mark.ring:SetPoint("BOTTOMRIGHT", 3, -3)
  mark:EnableMouse(false)
  mark:Hide()
  host.mark = mark
  -- Traps posées : trois cases au plus, devant les pieds du héros
  host.traps = {}
  for i = 1, 3 do
    local tk = CreateFrame("Frame", nil, host)
    Scene.at(tk, parent, HERO_X - (3 * TRAP_SIZE + 2 * TRAP_GAP) / 2 + (i - 1) * (TRAP_SIZE + TRAP_GAP), TRAP_Y,
      TRAP_SIZE, TRAP_SIZE)
    tk:SetFrameLevel(host:GetFrameLevel() + 20)
    tk:EnableMouse(true)
    tk.slot = W.slotOn(tk, TRAP_SIZE)
    tk.icon = tk.slot.icon
    W.tooltip(tk, function(tt, f)
      if not f.inst then return end
      W.fillCardTooltip(tt, f.inst.id, f.inst.up, { full = true })
      tt:AddLine(" ")
      tt:AddLine(f.index == 1 and "Triggers on the next enemy attack." or ("Triggers on enemy attack " .. f.index .. "."),
        1, 0.82, 0, true)
    end, "ANCHOR_TOP")
    tk:Hide()
    host.traps[i] = tk
  end
end

function V.render(host, c, view)
  local W = ns.Widgets
  host.pet:Show()
  -- Traps
  for i = 1, #host.traps do
    local tk, tr = host.traps[i], c.traps[i]
    if tr then
      tk.inst, tk.index = tr.card, i
      W.setIcon(tk.icon, W.cardArt(tr.card.id), "card:" .. tr.card.id)
      tk:Show()
    else
      tk.inst = nil
      tk:Hide()
    end
  end
  -- cible du familier
  local t = (not c.result) and ns.Hunter.petTarget(c) or nil
  local s = t and view.slotOf and view.slotOf[t.uid]
  if s and s.tag and s:IsShown() then
    host.mark:ClearAllPoints()
    host.mark:SetPoint("RIGHT", s.tag, "LEFT", -2, 0)
    host.mark:Show()
  else
    host.mark:Hide()
  end
end

-- Événements du moteur (file d'animations de CombatView) : le familier bondit vers sa cible ; le chiffre
-- de dégâts vient de l'événement « damage » qui suit (mécanisme commun).
function V.event(host, ev, view)
  if ev.t ~= "pet_attack" then return end
  local W, Scene = ns.Widgets, ns.Scene
  view:Push(0.16, function()
    local pet = host.pet
    if not pet then return end
    local tx = view:UnitPos(ev.dst)
    local dx = tx and math.max(0, math.min(90, (tx - PET_X) * 0.35)) or 50
    W.tween(0.3, function(p)
      local k = p < 0.5 and p * 2 or (1 - p) * 2
      Scene.at(pet, view.parent, host.petX + dx * k, host.petY)
    end, nil, pet, "leap", W.ease.linear)
    W.anim(pet.model, Art.anim.attack, 0.6)
  end)
end
