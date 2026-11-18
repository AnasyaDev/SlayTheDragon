-- Art du Druide : icônes des cartes, des épiques et des bibelots, voies, classe, état Clearcasting, formes
-- (icône, couleur, nom), vue de classe (pastille de la forme active, cible de la frappe de l'ours, coups de
-- fin de tour de Moonkin, animations des changements de forme). Fiche : docs/classes/druid.md, § 1.8.
-- Champ `tga` = icône améliorée de Media/Icons (tools/build_media.py --icons-only la copie depuis
-- le pack d'icônes local) ; `icon` = repli par chemin du client (icône pas encore copiée : aucun plantage).
-- N'applique aucune règle : lit le combat (c.cls.form, c.player.res, c.player.st.clearcasting).
local _, ns = ...

local Art = ns.Art
local hex = Art.hex

local function I(tga, spell)
  return { tga = tga, spell = spell, icon = "Interface\\Icons\\" .. tga:lower() }
end

-- Cartes (noms d'icônes de la fiche, § 3 ; vérifiés dans ~/Téléchargements/ICONS le 18/11/2026)
local cards = {
  -- départ
  wrath                 = I("Spell_Nature_WrathV2"),
  thick_hide            = I("Ability_Druid_Ironfur"),
  maul                  = I("Ability_Druid_Maul"),
  ferocious_bite        = I("Ability_Druid_FerociousBite"),
  -- Feral
  shred                 = I("Spell_Shadow_VampiricAura"),
  rake                  = I("Ability_Druid_Rake"),
  swipe                 = I("Ability_Druid_Swipe"),
  skull_bash            = I("INV_Bone_Skull_04"),
  rip                   = I("Ability_GhoulFrenzy"),
  frenzied_regeneration = I("Ability_BullRush"),
  tigers_fury           = I("Ability_Mount_JungleTiger"),
  mangle                = I("Ability_Druid_Mangle2"),
  demoralizing_roar     = I("ABILITY_DRUID_DEMORALIZINGROAR"),
  leader_of_the_pack    = I("Spell_Nature_UnyeildingStamina"),
  -- Balance
  starfire              = I("Spell_Arcane_StarFire"),
  moonfire              = I("Spell_Nature_StarFall"),
  starsurge             = I("Spell_Arcane_Arcane03"),
  faerie_fire           = I("Spell_Nature_FaerieFire"),
  insect_swarm          = I("Spell_Nature_InsectSwarm"),
  hurricane             = I("Spell_Nature_Cyclone"),
  entangling_roots      = I("Spell_Nature_StrangleVines"),
  starfall              = I("Ability_Druid_Starfall"),
  natures_grace         = I("Spell_Nature_NaturesBlessing"),
  moonkin_aura          = I("Spell_Nature_ForceOfNature"),
  -- Restoration
  rejuvenation          = I("Spell_Nature_Rejuvenation"),
  regrowth              = I("Spell_Nature_ResistNature"),
  mark_of_the_wild      = I("Spell_Nature_Regeneration"),
  thorns                = I("Spell_Nature_Thorns"),
  swiftmend             = I("INV_Relics_IdolofRejuvenation"),
  rebirth               = I("Spell_Nature_Reincarnation"),
  natures_swiftness     = I("Spell_Nature_RavenForm"),
  healing_touch         = I("SPELL_NATURE_HEALINGTOUCH"),
  gift_of_nature        = I("Spell_Nature_ProtectionformNature"),
  tranquility           = I("Spell_Nature_Tranquility"),
  -- cartes épiques (une par zone, § 5)
  furor                 = I("Spell_Holy_BlessingOfStamina"),
  mark_of_ursol         = I("Ability_Druid_MarkofUrsol"),
  eclipse               = I("Ability_Druid_Eclipse"),
  king_of_the_jungle    = I("Ability_Druid_KingoftheJungle"),
  lifebloom             = I("INV_Misc_Herb_Felblossom"),
  owlkin_frenzy         = I("Ability_Druid_OwlkinFrenzy"),
  heart_of_the_wild     = I("Spell_Holy_BlessingOfAgility"),
}
for id, e in pairs(cards) do Art.cards[id] = e end

Art.paths.feral       = { name = "Feral",       ring = hex("#c9772e"), ink = hex("#6b3a10") }
Art.paths.balance     = { name = "Balance",     ring = hex("#6276d8"), ink = hex("#27306e") }
Art.paths.restoration = { name = "Restoration", ring = hex("#4fa04a"), ink = hex("#1f5219") }

Art.relics.idol_of_the_wild     = I("INV_Misc_Idol_02")
Art.relics.idol_of_brutality    = I("INV_Misc_Idol_03")
Art.relics.idol_of_ferocity     = I("INV_Relics_IdolofFerocity")
Art.relics.idol_of_the_moon     = I("INV_MISC_IDOL_05")
Art.relics.idol_of_rejuvenation = I("INV_Relics_IdolofHealth")
Art.relics.wolfshead_helm       = I("INV_Helmet_04")

-- État Clearcasting (§ 1.3 : icône de Clearcasting dans WoW), jeton sous le héros ; définition courte
-- seulement si la classe a déclaré l'état (Core/Classes/druid.lua, chargé avant ce fichier).
Art.statuses.clearcasting = I("Spell_Shadow_ManaBurn")
if ns.Statuses and ns.Statuses.clearcasting then
  Art.statusShort.clearcasting = "the next Attack costs 0, not Cast cards."
end

Art.classes.druid = I("ClassIcon_Druid")
Art.classes.druid.wow = "DRUID"
-- ressource sans forme (« Reserve ») : icône de la classe ; la pastille suit la forme (Art.druidForms)
Art.classes.druid.resource = { tga = "ClassIcon_Druid", icon = "Interface\\Icons\\classicon_druid", color = "textSoft" }

-- Formes (§ 1.8) : nom affiché, icône de la pastille et des marques, teinte de l'anneau (multipliée sur
-- l'anneau doré), couleur des crans, des chiffres flottants et du titre de l'infobulle. none = sans forme
-- (début du combat) : icône de la classe, anneau gris. Brun pour Bear, jaune pour Cat, bleu nuit pour
-- Moonkin, vert pour Tree of Life.
Art.druidForms = {
  none    = { name = "No form", icon = Art.classes.druid, ring = { 0.75, 0.75, 0.75 }, grey = true,
              color = hex("#bec8d6") },
  cat     = { name = "Cat Form", icon = I("Ability_Druid_CatForm"), ring = { 1, 0.86, 0.32 }, color = hex("#ffd660") },
  bear    = { name = "Bear Form", icon = I("Ability_Racial_BearForm"), ring = { 0.86, 0.56, 0.34 }, color = hex("#e2a26e") },
  moonkin = { name = "Moonkin Form", icon = I("Spell_Nature_ForceOfNature"), ring = { 0.52, 0.6, 1 }, color = hex("#a9b8ff") },
  tree    = { name = "Tree of Life", icon = I("Ability_Druid_TreeofLife"), ring = { 0.58, 1, 0.5 }, color = hex("#a8e6b0") },
}
for key, f in pairs(Art.druidForms) do
  -- pastille propre à la classe (ns.ClassViews.druid.badge, UI/CombatView.lua) : table fixe par forme
  f.key = key
  f.badge = { icon = f.icon, key = "ui:druid:" .. key, ring = f.ring, grey = f.grey, color = f.color, always = true }
end

-- Forme active du combat (entrée de Art.druidForms).
function Art.druidForm(c)
  local form = c and c.cls and c.cls.form
  return Art.druidForms[form or "none"] or Art.druidForms.none
end

---------------------------------------------------------------------------
-- Ce que fera la fin de tour (pastille, marques des ennemis ; lu aussi par le harnais). Chiffres de la fiche
-- (§ 1.3, § 1.4) sauf si la classe les publie (ns.Druid.STRIKE_BASE, PULSE_PER, PULSE_MAX).
---------------------------------------------------------------------------
local function strikeBase() local D = ns.Druid return (D and D.STRIKE_BASE) or 1 end

-- Frappe de l'ours : cible (dernière cible vivante, sinon l'ennemi vivant le plus à gauche) et dégâts.
function Art.druidStrike(c)
  local Combat = ns.Combat
  local t = Combat.strikeTarget(c)
  if not t then return nil, 0 end
  return t, Combat.strikeDamage(c, t, strikeBase(), true)
end

-- Coups à tous de Moonkin : base (ceil(Charges / 2), 3 au plus) et dégâts sur e (nil : la base).
function Art.druidPulse(c, e)
  local D = ns.Druid
  local per, cap = (D and D.PULSE_PER) or 2, (D and D.PULSE_MAX) or 3
  local n = math.min(cap, math.ceil((c.player.res or 0) / per))
  if n <= 0 then return 0, 0 end
  return n, e and ns.Combat.strikeDamage(c, e, n, false) or n
end

local WH = "|cffffffff%s|r"
local function num(n) return WH:format(tostring(n)) end

-- Lignes de la pastille : valeur de la réserve maintenant, puis l'effet de fin de tour (or), puis le Cast en
-- attente quand la forme de fin change son bonus. Renvoie now, endLine, castLine (nil : rien).
function Art.druidLines(c)
  local L = ns.Language
  local form = c.cls and c.cls.form
  local res = c.player.res or 0
  local rname = L.resourceName(L.combatResource(c) or "wild", res)
  local now, eot, cast
  if form == "cat" then
    now = num(res) .. " " .. rname .. ": spent by Surge."
    if (c.player.st.clearcasting or 0) ~= 0 then
      eot = "End of turn: Clearcasting is already set, it doesn't stack."
    else
      eot = "End of turn: Clearcasting, the next Attack costs 0."
    end
  elseif form == "bear" then
    local t, dmg = Art.druidStrike(c)
    now = num(res) .. " " .. rname .. ": Bear strikes for " .. num(strikeBase() + res) .. "."
    if t then
      eot = "End of turn: Bear strikes " .. ns.Combat.enemyName(t) .. " for " .. num(dmg) .. ", then +1 "
        .. L.resourceName(L.combatResource(c) or "wild", 1) .. "."
    else
      eot = "End of turn: Bear strikes."
    end
  elseif form == "moonkin" then
    local n = Art.druidPulse(c)
    now = num(res) .. " " .. rname .. ": Attack hits +" .. num(res) .. "."
    if n > 0 then
      eot = "End of turn: " .. num(n) .. " damage to each enemy."
    else
      eot = "End of turn: nothing, no Charge."
    end
  elseif form == "tree" then
    now = rname .. " " .. num(res) .. ": unused in Tree of Life."
    eot = "End of turn: gain Regen " .. ((ns.Druid and ns.Druid.TREE_REGEN) or 2) .. "."
  else
    now = rname .. " " .. num(res) .. ": unused until a form card is played."
    eot = "End of turn: nothing, no form yet."
  end
  -- Cast Attack en attente : bonus des Charges seulement si le tour finit en Moonkin (§ 1.1, point 4)
  local p = c.player
  local cd = p.cast and ns.Card.def(p.cast.card)
  if cd and cd.type == "attack" and res > 0 then
    if form == "moonkin" then
      cast = cd.name .. " resolves next turn with +" .. num(res) .. "."
    else
      cast = cd.name .. " resolves without the Charges: end the turn in Moonkin for +" .. num(res) .. "."
    end
  end
  return now, eot, cast
end

-- Note de l'épique sur son jeton des états du héros (W.noteToken, comme les autres classes) : ce qu'elle fait
-- maintenant (ligne de l'infobulle, nil : rien à dire), compteur écrit sur l'icône (nil : aucun), vrai si la
-- règle est inactive (icône atténuée). Nombres de ns.DruidEpic au palier de l'épique. Lu aussi par le harnais.
function Art.druidEpicLine(c)
  local D = ns.Druid
  local id, up
  if D and D.epic then id, up = D.epic(c) end
  local E = ns.DruidEpic
  if not id or not E or c.result then return nil end
  local k = ns.Card.level(up) + 1
  local res = c.player.res or 0
  local form = c.cls and c.cls.form
  if id == "furor" then
    local used = (c.cls.furorRound == c.round) and (c.cls.furor or 0) or 0
    local left = math.max(0, E.primal[k] - used)
    if left > 0 then return "Form changes this turn: +1 reserve, " .. num(left) .. " left", tostring(left) end
    return "No more reserve from form changes this turn", nil, true
  elseif id == "mark_of_ursol" then
    local _, dmg = Art.druidStrike(c)
    local n = math.floor((dmg or 0) * E.ironfur[k] / 100)
    if form == "bear" and n > 0 then return "End of turn: the Bear strike gives " .. num(n) .. " Absorb", "+" .. n end
    return "Bear strikes give " .. num(E.ironfur[k] .. "%") .. " of their damage as Absorb"
  elseif id == "eclipse" then
    local need = E.lunar[k]
    if res >= need then
      return "Moonkin Cast cards resolve at once" .. (E.solar[k] > 0 and (", " .. num("+" .. E.solar[k]) .. " damage") or "")
    end
    return "Moonkin Cast cards resolve at once from " .. num(need) .. " reserve", res .. "/" .. need, true
  elseif id == "king_of_the_jungle" then
    local line = "Each Surge leaves up to " .. num(E.predator[k]) .. " in the reserve"
    if E.apex[k] > 0 then
      if c.cls.apexRound == c.round then
        line = line .. ", draw already used this turn"
      else
        line = line .. ", the first one this turn draws " .. num(E.apex[k])
      end
    end
    return line
  elseif id == "lifebloom" then
    if (c.player.st.regen or 0) > 0 then
      return "Next Regen heal: " .. num("+" .. E.bloom[k]) .. " reserve", "+" .. E.bloom[k]
    end
    return "No Regen: no reserve gained", nil, true
  elseif id == "owlkin_frenzy" then
    if form == "moonkin" then
      return "Each enemy attack that costs HP: " .. num("+" .. E.moonfury[k]) .. " reserve"
        .. (E.barkskin[k] > 0 and (", end of turn " .. num(E.barkskin[k]) .. " Absorb") or ""), "+" .. E.moonfury[k]
    end
    return "Not in Moonkin: hits give nothing", nil, true
  elseif id == "heart_of_the_wild" then
    local L = ns.Language
    local parts = {}
    for _, f in ipairs({ "cat", "bear", "moonkin" }) do
      local v = D.pool(c, f)
      parts[#parts + 1] = num(v) .. " " .. L.resourceName(L.resourceKey("wild", f), v)
    end
    return table.concat(parts, ", ") .. ", up to " .. num(E.kinship[k]) .. " each"
  end
  return nil
end

---------------------------------------------------------------------------
-- Vue de classe (ns.ClassViews.druid, docs/classes.md, « Interface ») : pastille de la forme active
-- (badge / badgeTooltip, lus par UI/CombatView.lua), marques sur les ennemis (cible de la frappe en Bear,
-- coups de fin de tour en Moonkin), jeton Clearcasting mis en avant, animations (shift, bear_strike,
-- moonkin_pulse, clearcasting).
---------------------------------------------------------------------------
local V = {}
ns.ClassViews.druid = V
V.enemyMarks = true -- marque sur un cadre d'ennemi : CombatView lui réserve la fin de la ligne du nom

-- Pastille : table fixe de la forme active (icône, clé, teinte de l'anneau, couleur, toujours visible).
function V.badge(c)
  return Art.druidForm(c).badge
end

-- Infobulle de la pastille : nom de la forme, valeur de la réserve, fin de tour, Cast en attente, explication
-- de la ressource dans la forme, « n / plafond ».
function V.badgeTooltip(tt, c)
  local f = Art.druidForm(c)
  local col = f.color
  tt:AddLine(f.name, col[1], col[2], col[3])
  local now, eot, cast = Art.druidLines(c)
  tt:AddLine(now, 1, 1, 1, true)
  tt:AddLine(eot, 1, 0.82, 0, true)
  if cast then tt:AddLine(cast, 1, 0.82, 0, true) end
  local key = ns.Language.combatResource(c) or "wild"
  tt:AddLine(Art.keywordLine("res:" .. key), 0.8, 0.8, 0.8, true)
  local rd = ns.Classes.druid and ns.Classes.druid.resource
  local cap = ns.Combat.resCap(c) or (rd and rd.cap)
  if cap then tt:AddLine(("%d / %d"):format(c.player.res or 0, cap), 0.8, 0.8, 0.8) end
  local tl = Art.druidTaxLine(c)
  if tl then tt:AddLine(tl, 1, 0.5, 0.25, true) end
end

-- Levier A (taxe des changements de forme) : compteur du tour et malus à venir ; nil si le levier est inactif.
function Art.druidTaxLine(c)
  local D = ns.Druid
  if not D or (D.TAX or 0) <= 0 then return nil end
  local n = c.cls and c.cls.shifts or 0
  local tax = D.pendingTax(c)
  local head = ("Form changes this turn: %d. "):format(n)
  if tax > 0 then return head .. ("Next turn: %d mana less."):format(tax) end
  if n >= D.TAX_FREE then return head .. ("Shifting again costs %d mana next turn."):format(D.TAX) end
  return head .. ("%d more free, then each costs %d mana next turn."):format(D.TAX_FREE - n, D.TAX)
end

-- Jeton Clearcasting (état à drapeau, sans nombre) : aura jaune de Cat tant qu'il attend son Attack.
local CC_GLOW
function V.tokens(c, list)
  ns.Widgets.noteToken(list, "epic", Art.druidEpicLine(c)) -- épique en jeu : ce qu'elle fait maintenant
  if (c.player.st.clearcasting or 0) == 0 then return end
  CC_GLOW = CC_GLOW or { Art.druidForms.cat.color[1], Art.druidForms.cat.color[2], Art.druidForms.cat.color[3], 0.8 }
  for i = 1, #list do
    local it = list[i]
    if it.key == "status:clearcasting" then
      it.glow = CC_GLOW
      it.rim = Art.rim.gold
    end
  end
end

if not CreateFrame then return end -- hors du jeu (Sim/load.lua saute UI\, garde-fou)

local MARKS = 6

local function markTooltip(tt, f)
  local c = ns.Controller.combat()
  if not c or c.class ~= "druid" or not f.unit then return end
  local e = f.unit
  if f.kind == "bear" then
    local t, dmg = Art.druidStrike(c)
    tt:AddLine("Bear strike", unpack(Art.druidForms.bear.color))
    if t == e then tt:AddLine(("End of turn: Bear strikes it for %d."):format(dmg), 1, 1, 1, true) end
    tt:AddLine("The bear hits the last enemy targeted.", 0.8, 0.8, 0.8, true)
  else
    local _, dmg = Art.druidPulse(c, e)
    tt:AddLine("Moonkin Form", unpack(Art.druidForms.moonkin.color))
    tt:AddLine(("End of turn: %d damage to it."):format(dmg), 1, 1, 1, true)
    tt:AddLine("1 damage to each enemy per 2 Charges, up to 3.", 0.8, 0.8, 0.8, true)
  end
end

function V.build(host, view)
  local W = ns.Widgets
  host.marks = {}
  for i = 1, MARKS do
    local mk = CreateFrame("Frame", nil, host)
    mk:SetSize(13, 13)
    mk:SetFrameLevel(host:GetFrameLevel() + 30)
    mk.icon = W.noSnap(mk:CreateTexture(nil, "ARTWORK", nil, 0))
    mk.icon:SetAllPoints()
    W.roundMask(mk, mk.icon)
    mk.ring = W.wow(mk, "ring_small", "ARTWORK", 1)
    mk.ring:SetPoint("TOPLEFT", -2, 2)
    mk.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    mk:EnableMouse(true)
    W.tooltip(mk, markTooltip, "ANCHOR_RIGHT")
    mk:Hide()
    host.marks[i] = mk
  end
end

-- Marques : en Bear, la cible de la frappe de fin de tour ; en Moonkin avec au moins une Charge, chaque
-- ennemi vivant (coups à tous) ; rien dans les autres formes ni après la fin du combat.
function V.render(host, c, view)
  local W = ns.Widgets
  local form = c.cls and c.cls.form
  host.pulsing = nil -- salve de Moonkin du lot d'événements précédent (V.event) : déjà en file
  local k = 0
  local function mark(e, kind)
    local s = view.slotOf and view.slotOf[e.uid]
    if k >= MARKS or not (s and s.tag and s:IsShown()) then return end
    k = k + 1
    local mk = host.marks[k]
    if mk.kind ~= kind then
      mk.kind = kind
      W.setIcon(mk.icon, Art.druidForms[kind].icon, "ui:druid:" .. kind)
      local r = Art.druidForms[kind].ring
      mk.ring:SetVertexColor(r[1], r[2], r[3], 1)
    end
    mk.unit = e
    mk:ClearAllPoints()
    mk:SetPoint("CENTER", s.markSpot or s.tag, "CENTER", 0, 0)
    mk:Show()
  end
  if not c.result then
    if form == "bear" then
      local t = Art.druidStrike(c)
      if t then mark(t, "bear") end
    elseif form == "moonkin" and Art.druidPulse(c) > 0 then
      for i = 1, #c.enemies do
        if not c.enemies[i].dead then mark(c.enemies[i], "moonkin") end
      end
    end
  end
  for i = k + 1, MARKS do
    host.marks[i].unit = nil
    host.marks[i]:Hide()
  end
end

-- Événements du moteur (file d'animations de CombatView) : changement de forme (l'icône de la pastille
-- tourne, nom de la forme au-dessus du héros), frappe de l'ours (coup du héros ; le chiffre vient de
-- l'événement « damage » qui suit), coups à tous de Moonkin (un nom pour la salve), Clearcasting posé.
local TWO_PI = 2 * math.pi
function V.event(host, ev, view)
  local W = ns.Widgets
  local A = Art.anim
  local t = ev.t
  if t == "shift" then
    local f = Art.druidForms[ev.to or "none"] or Art.druidForms.none
    view:Push(0.2, function()
      local res = view.resource
      if res and res.icon then
        W.tween(0.4, function(p) res.icon:SetRotation(TWO_PI * p) end, function() res.icon:SetRotation(0) end,
          res.icon, "shift", W.ease.linear)
      end
      local x, y = view:UnitPos("player")
      if x then W.float(view.parent, x, y - 70, f.name, f.color, 17, 1.0, 16) end
      if view.playerModel then W.anim(view.playerModel, A.spellOmni, 0.8) end
    end)
  elseif t == "bear_strike" then
    view:Push(0.16, function()
      if view.playerModel then W.anim(view.playerModel, A.attack, 0.6) end
      local x, y = view:UnitPos("player")
      if x then W.float(view.parent, x + 40, y - 40, "Bear strike", Art.druidForms.bear.color, 14, 0.9, 14) end
    end)
  elseif t == "moonkin_pulse" then
    -- une entrée par ennemi touché (all = true) : un seul nom pour la salve, posé au premier coup
    if not host.pulsing then
      host.pulsing = true
      view:Push(0.2, function()
        host.pulsing = nil
        if view.playerModel then W.anim(view.playerModel, A.spellOmni, 0.8) end
        local x, y = view:UnitPos("player")
        if x then W.float(view.parent, x, y - 70, "Moonkin", Art.druidForms.moonkin.color, 16, 1.0, 16) end
      end)
    end
    view:Push(0.08, function() end) -- un temps par coup, avant le chiffre de dégâts de l'ennemi
  elseif t == "clearcasting" then
    view:Push(0.15, function()
      local x, y = view:UnitPos("player")
      if x then W.float(view.parent, x, y - 90, "Clearcasting", Art.druidForms.cat.color, 15, 1.0, 14) end
    end)
  end
end
