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
  -- cartes épiques (cartes de zone)
  call_of_the_wild  = I("Ability_Hunter_CalloftheWild"),
  trap_launcher     = I("Ability_Hunter_TrapLauncher"),
  beast_cleave      = I("Ability_Hunter_Carve"),
  roar_of_sacrifice = I("Ability_Hunter_Fervor"),
  master_marksman   = I("Ability_Hunter_MasterMarksman"),
  black_arrow       = I("Spell_Shadow_PainSpike"),
  lone_wolf         = I("Spell_Hunter_LoneWolf"),
  -- variantes de Lone Wolf
  chimaera_shot        = I("Ability_Hunter_ChimeraShot2"),
  kill_shot            = I("Ability_Hunter_Assassinate2"),
  double_tap           = I("Ability_Hunter_FocusedAim"),
  scatter_shot         = I("Ability_GolemStormBolt"),
  salvo                = I("Ability_Hunter_Crossfire"),
  silencing_shot       = I("Ability_TheBlackArrow"),
  explosive_shot       = I("Ability_Hunter_ExplosiveShot"),
  trick_shots          = I("INV_TrickShot"),
  aspect_of_the_turtle = I("Ability_Hunter_Pet_Turtle"),
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

-- Pet Whistle sous une épique qui retire le familier (Lone Wolf, deckHooks.petAbsent) : le bibelot montre
-- le texte de sa variante (loneText) tant que l'expédition en cours a cette épique (règle : Data/Hunter.lua).
do
  local whistle = ns.Relics.pet_whistle
  if whistle and whistle.loneText and rawget(whistle, "text") then
    local base = whistle.text
    whistle.text = nil
    setmetatable(whistle, { __index = function(_, k)
      if k ~= "text" then return nil end
      local Ctl = ns.Controller
      local exp = Ctl and Ctl.exp and Ctl.exp()
      local i = exp and exp.deck and ns.Expedition.epicIndex(exp)
      local d = i and ns.Card.defById(exp.deck[i].id)
      if d and d.deckHooks and d.deckHooks.petAbsent then return whistle.loneText end
      return base
    end })
  end
end

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

-- Ligne de l'épique sous les états du héros (comme le Voleur, UI/Art/rogue.lua) : icône de l'épique (infobulle
-- = la carte) et ce qu'elle change maintenant. Texte (nil : rien à montrer), lu aussi par le harnais.
local EPIC_ICON = 22
local W_ = "|cffffffff%s|r"
local function num(n) return W_:format(tostring(n)) end
function Art.hunterEpicLine(c)
  local H = ns.Hunter
  local id, up = H and H.epic(c)
  if not id or c.result then return nil end
  local E, res = ns.HunterEpic, c.player.res or 0
  local k = up and 2 or 1
  local alive = 0
  for i = 1, #c.enemies do if not c.enemies[i].dead then alive = alive + 1 end end
  if id == "call_of_the_wild" then
    return "Start of turn: pet attacks for " .. num(H.petDamage(c, nil, math.min(5, res + (up and 1 or 0))))
  elseif id == "trap_launcher" then
    return "Traps hit at once, pet attacks " .. num(E.launcher[k]) .. "x"
  elseif id == "beast_cleave" then
    return "Pet hits all " .. num(alive) .. " enemies"
  elseif id == "roar_of_sacrifice" then
    if res >= 1 then return "Next hit: " .. num(-E.roar[k]) .. " damage (" .. num(res) .. " Frenzy left)" end
    return "No Frenzy: hits are not reduced"
  elseif id == "master_marksman" then
    local n = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead and e.hp * 2 > e.maxHp then n = n + 1 end
    end
    if n > 0 then return "Cast Attacks on " .. num(n) .. " intact target" .. (n > 1 and "s" or "") .. " resolve at once" end
    return "No intact target: Cast Attacks wait"
  elseif id == "black_arrow" then
    local n = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead and (e.st.pain or 0) > 0 then n = n + 1 end
    end
    return "Pet attacks on DoT ticks: " .. num(n) .. " enem" .. (n == 1 and "y" or "ies")
  elseif id == "lone_wolf" then
    return "No pet. Attack hits: " .. num("+" .. E.lonePer[k] * res)
  end
  return nil
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
  -- ligne de l'épique : icône et texte, à gauche de la zone de classe
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
  -- le familier suit la zone de classe (cachée quand le combat est d'une autre classe)
  host:SetScript("OnHide", function() pet:Hide() end)
  host.petX = PET_X - PET_W / 2
  host.petY = PET_FEET - PET_H
  -- modèle : apparaît une fois chargé (candidat gagnant mémorisé, préchargé dès le parcours) ; médaillon
  -- si aucun candidat ne charge
  local function showPet() Scene.showModel(pet, Art.pet, "pet:hunter", { facing = 0.9 }) end
  host:SetScript("OnShow", function()
    local c = ns.Controller.combat and ns.Controller.combat()
    if c and c.class == "hunter" and not ns.Hunter.petPresent(c) then pet:Hide() return end
    pet:Show()
    showPet()
  end)
  showPet()
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
  -- sans familier (Lone Wolf) : ni figure, ni nom, ni marqueur de cible
  local present = ns.Hunter.petPresent(c)
  if present then host.pet:Show() else host.pet:Hide() end
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
  -- ligne de l'épique
  local ep = host.epic
  local id, up = ns.Hunter.epic(c)
  local line = id and Art.hunterEpicLine(c)
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
  -- cible du familier
  local t = (present and not c.result) and ns.Hunter.petTarget(c) or nil
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
  local W, Scene = ns.Widgets, ns.Scene
  if ev.t == "roar" then
    -- Roar of Sacrifice : le nom part du héros (comme « Parry »), le chiffre des PV perdus suit
    view:Push(0.18, function()
      local x, y = view:UnitPos("player")
      if not x then return end
      W.sound("block")
      W.float(view.parent, x - 44, y - 40, "Roar", Art.C.goldText, 22, 1.1)
    end)
    return
  end
  if ev.t ~= "pet_attack" then return end
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
