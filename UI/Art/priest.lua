-- Art du Prêtre propre à ses cartes épiques : icônes des sept épiques et vue de classe (zone libre sous les
-- états du héros) qui dit ce que l'épique change pendant le combat. Le reste de l'art du Prêtre (cartes,
-- bibelots, ressource) est dans UI/Art.lua.
-- Champ `tga` = icône améliorée de Media/Icons (tools/build_media.py --icons-only la copie depuis
-- ~/Téléchargements/ICONS) ; `spell` = repli par l'icône du sort ; `icon` = FileDataID (vérifiés).
local _, ns = ...

local Art = ns.Art

local cards = {
  prayer_of_mending = { spell = 33076,  icon = 135944,  tga = "Spell_Holy_PrayerOfMendingtga" },  -- spell_holy_prayerofmendingtga
  misery            = { spell = 33196,  icon = 136176,  tga = "Spell_Shadow_Misery" },            -- spell_shadow_misery
  echo_of_light     = { spell = 77485,  icon = 237537,  tga = "Spell_Holy_Aspiration" },          -- spell_holy_aspiration
  shadow_covenant   = { spell = 204065, icon = 136221,  tga = "Spell_Shadow_SummonVoidWalker" },  -- spell_shadow_summonvoidwalker
  reflective_shield = { spell = 33201,  icon = 458412,  tga = "Ability_Priest_ReflectiveShield" }, -- ability_priest_reflectiveshield
  voidform          = { spell = 194249, icon = 1386550, tga = "Spell_Priest_Voidform" },          -- spell_priest_voidform
  inner_focus       = { spell = 14751,  icon = 135863,  tga = "Spell_Frost_WindWalkOn" },         -- spell_frost_windwalkon
}
for id, a in pairs(cards) do Art.cards[id] = a end

-- Ligne de la vue de classe selon l'épique en jeu (nil : rien à dire). Ne lit que le combat.
local function epicLine(c)
  local P = ns.Priest
  local id, up = P.epicOf(c)
  if not id then return nil end
  local p = c.player
  if id == "echo_of_light" then
    local r = p.st.regen or 0
    if r <= 0 then return id, "Echo of Light: Regen deals damage" end
    return id, ("Regen %d: %d to all next turn"):format(r, r + P.ECHO_PLUS[up and 2 or 1])
  elseif id == "shadow_covenant" then
    -- PV de la prochaine carte Shadow à 1 mana (toutes les cartes Shadow coûtent 1)
    local played = c.turn.bySchool.shadow or 0
    if up and played == 0 then
      return id, ("Shadow: first card free, then %d HP"):format(P.COVENANT_HP[2] + P.COVENANT_STEP)
    end
    return id, ("Next Shadow card: %d HP"):format(P.covenantHp(c, up, 1))
  elseif id == "voidform" then
    local b = (p.res or 0) * P.VOID_BONUS[up and 2 or 1]
    return id, ("Voidform: Shadow hits +%d"):format(b)
  elseif id == "inner_focus" then
    local s = P.FOCUS_SCALE[up and 2 or 1]
    local mult = ("+%d%%"):format(math.floor((s - 1) * 100 + 0.5))
    if p.cast and c.cls.focus == p.cast.card.uid then
      return id, ("Focused cast: %s %s"):format(ns.Card.def(p.cast.card).name, mult)
    end
    if P.focusReady(c) then return id, ("Inner Focus: next card is Cast, %s"):format(mult) end
    return id, "Inner Focus: used this turn"
  end
  return nil
end
Art.priestEpicLine = epicLine

ns.ClassViews.priest = {
  build = function(host)
    local W, C = ns.Widgets, Art.C
    local box = CreateFrame("Frame", nil, host)
    box:SetSize(26, 26)
    box:SetPoint("LEFT", host, "LEFT", 0, 0)
    box:EnableMouse(true)
    box.slot = W.slotOn(box, 26)
    W.tooltip(box, function(tt)
      local c = ns.Controller.combat()
      local id, up = c and ns.Priest.epicOf(c)
      if not id then return end
      W.fillCardTooltip(tt, id, up, { full = true })
    end, "ANCHOR_TOP")
    host.box = box
    host.line = W.label(host, "bold", 12.5, C.text)
    host.line:SetPoint("LEFT", host, "LEFT", 32, 0)
    host.line:SetWidth(260)
    host.line:SetJustifyH("LEFT")
    host.line:SetWordWrap(false)
  end,
  render = function(host, c)
    local W = ns.Widgets
    local id, text = epicLine(c)
    if id then
      W.setIcon(host.box.slot.icon, W.cardArt(id), "card:" .. id)
      host.line:SetText(text)
      host.box:Show()
      host.line:Show()
    else
      host.box:Hide()
      host.line:Hide()
    end
  end,
}
