-- Art du Prêtre propre à ses cartes épiques : icônes des sept épiques et vue de classe (note sur le jeton de
-- l'épique, dans les états du héros) qui dit ce que l'épique change pendant le combat. Le reste de l'art du Prêtre (cartes,
-- bibelots, ressource) est dans UI/Art.lua.
-- Champ `tga` = icône améliorée de Media/Icons (tools/build_media.py --icons-only la copie depuis
-- le pack d'icônes local) ; `spell` = repli par l'icône du sort ; `icon` = FileDataID (vérifiés).
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

-- Note de l'épique en jeu (nil : pas d'épique du Prêtre) : id, ligne actuelle (infobulle du jeton, nil : rien
-- à dire), compteur écrit sur l'icône (nil : aucun), vrai si la règle est inactive (icône atténuée). Ne lit
-- que le combat ; lu aussi par le harnais.
local function epicLine(c, want)
  local P = ns.Priest
  local id, up = P.epicOf(c, want)
  if not id then return nil end
  local p = c.player
  if id == "echo_of_light" then
    local r = p.st.regen or 0
    if r <= 0 then return id, "No Regen: no damage next turn", nil, true end
    local dmg = r + P.ECHO_PLUS[up and 2 or 1]
    return id, ("Regen %d: %d to all next turn"):format(r, dmg), tostring(dmg)
  elseif id == "shadow_covenant" then
    -- PV de la prochaine carte Shadow à 1 mana (toutes les cartes Shadow coûtent 1)
    local played = c.turn.bySchool.shadow or 0
    if up and played == 0 then
      return id, ("Shadow: first card free, then %d HP"):format(P.COVENANT_HP[2] + P.COVENANT_STEP), "0"
    end
    local hp = P.covenantHp(c, up, 1)
    return id, ("Next Shadow card: %d HP"):format(hp), tostring(hp)
  elseif id == "voidform" then
    local b = (p.res or 0) * P.VOID_BONUS[up and 2 or 1]
    return id, ("Shadow hits: +%d"):format(b), b > 0 and ("+" .. b) or nil, b <= 0
  elseif id == "inner_focus" then
    local s = P.FOCUS_SCALE[up and 2 or 1]
    local mult = ("+%d%%"):format(math.floor((s - 1) * 100 + 0.5))
    if p.cast and c.cls.focus == p.cast.card.uid then
      return id, ("Focused cast: %s %s"):format(ns.Card.def(p.cast.card).name, mult)
    end
    if P.focusReady(c) then return id, ("Next card is Cast, %s"):format(mult) end
    return id, "Used this turn", nil, true
  end
  return id
end
Art.priestEpicLine = epicLine

-- Vue de classe : rien d'écrit sur la scène ; la note de l'épique va sur son jeton des états du héros.
ns.ClassViews.priest = {
  tokens = function(c, list)
    ns.Widgets.noteEpics(c, list, function(c2, want)
      local id, text, n, dim = epicLine(c2, want)
      if id then return text, n, dim end
    end)
  end,
}
