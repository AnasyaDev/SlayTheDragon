-- Briques d'interface : icônes vérifiées, panneaux, boutons, barres, cartes, états,
-- infobulles, textes flottants. Seule couche (avec Main/CombatView/Screens/Flight)
-- à toucher l'API WoW.
local _, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local Art = ns.Art
local Card = ns.Card

local W = {}
ns.Widgets = W

W.missing = {}   -- icônes ou modèles introuvables en jeu (pour /slay art)

local WHITE = "Interface\\Buttons\\WHITE8X8"

---------------------------------------------------------------------------
-- Temps et vitesse
---------------------------------------------------------------------------

function W.delay(sec, fn)
  if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end
end

-- Multiplicateur appliqué aux délais d'animation.
function W.pace()
  local o = ns.Persist.options()
  if o.fast then return 0.15 end
  local s = o.speed or 1
  if s < 0.25 then s = 0.25 end
  return 1 / s
end

---------------------------------------------------------------------------
-- Icônes
---------------------------------------------------------------------------

local function noteMissing(key)
  if key then W.missing[key] = true end
end

-- entry = { spell = id, icon = "chemin" } ; key sert au rapport /slay art.
function W.setIcon(tex, entry, key)
  entry = entry or {}
  if entry.spell and C_Spell and C_Spell.GetSpellTexture then
    local ok, id = pcall(C_Spell.GetSpellTexture, entry.spell)
    if ok and id then
      tex:SetTexture(id)
      return true
    end
  end
  if entry.icon then
    local ok = tex:SetTexture(entry.icon)
    local fid = tex.GetTextureFileID and tex:GetTextureFileID()
    if ok ~= false and (fid == nil and not tex.GetTextureFileID or fid) then return true end
  end
  noteMissing(key)
  tex:SetTexture(Art.QUESTION)
  return false
end

function W.cardArt(id)
  local e = Art.cards[id]
  if e then return e end
  local d = ns.Cards[id]
  return d and Art.schools[d.school] or nil
end

---------------------------------------------------------------------------
-- Cadres de base
---------------------------------------------------------------------------

function W.create(kind, name, parent, template)
  if template then
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
  end
  return CreateFrame(kind, name, parent)
end

local DIALOG_BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local TOOLTIP_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- Cadre avec bordure Blizzard ; style = "dialog" ou "tooltip".
function W.panel(parent, style, name)
  local f = W.create("Frame", name, parent, "BackdropTemplate")
  if f.SetBackdrop then
    f:SetBackdrop(style == "dialog" and DIALOG_BACKDROP or TOOLTIP_BACKDROP)
    if style ~= "dialog" then
      f:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
      f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
  else
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.08, 0.92)
  end
  return f
end

function W.text(parent, font, size, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlight")
  if size then
    local f, _, flags = fs:GetFont()
    if f then fs:SetFont(f, size, flags) end
  end
  return fs
end

function W.button(parent, label, w, h, onClick)
  local b = W.create("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 120, h or 24)
  b:SetText(label or "")
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function W.closeButton(parent, onClick)
  local b = W.create("Button", nil, parent, "UIPanelCloseButton")
  b:SetSize(28, 28)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

-- Case à cocher faite main (textures classiques, sans dépendre d'un modèle XML).
function W.check(parent, label, getter, setter)
  local b = CreateFrame("CheckButton", nil, parent)
  b:SetSize(24, 24)
  b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  local fs = W.text(b, "GameFontHighlight")
  fs:SetPoint("LEFT", b, "RIGHT", 4, 0)
  fs:SetText(label)
  b.label = fs
  b:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
  b.Sync = function(self) self:SetChecked(getter() and true or false) end
  return b
end

-- Barre de vie avec Absorption.
function W.bar(parent, w, h, r, g, b)
  local f = CreateFrame("StatusBar", nil, parent)
  f:SetSize(w, h)
  f:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  f:SetStatusBarColor(r or 0.1, g or 0.8, b or 0.1)
  f:SetMinMaxValues(0, 1)
  f:SetValue(1)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.6)
  local border = W.panel(f, "tooltip")
  border:SetPoint("TOPLEFT", -3, 3)
  border:SetPoint("BOTTOMRIGHT", 3, -3)
  if border.SetBackdropColor then border:SetBackdropColor(0, 0, 0, 0) end
  f.text = W.text(f, "GameFontHighlightSmall")
  f.text:SetPoint("CENTER", 0, 0)
  f.shield = f:CreateTexture(nil, "ARTWORK")
  f.shield:SetColorTexture(0.55, 0.75, 1, 0.55)
  f.shield:SetHeight(h)
  f.shield:Hide()
  f.Set = function(self, hp, maxHp, block)
    maxHp = maxHp > 0 and maxHp or 1
    self:SetMinMaxValues(0, maxHp)
    self:SetValue(hp > 0 and hp or 0)
    if block and block > 0 then
      self.text:SetText(hp .. " / " .. maxHp .. "  |cff8cc4ff+" .. block .. "|r")
      local frac = block / maxHp
      if frac > 1 then frac = 1 end
      self.shield:ClearAllPoints()
      self.shield:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
      self.shield:SetWidth(w * frac)
      self.shield:Show()
    else
      self.text:SetText(hp .. " / " .. maxHp)
      self.shield:Hide()
    end
  end
  return f
end

---------------------------------------------------------------------------
-- Infobulles
---------------------------------------------------------------------------

-- fill(tooltip, owner) ajoute les lignes ; anchor par défaut ANCHOR_RIGHT.
function W.tooltip(frame, fill, anchor)
  frame:SetScript("OnEnter", function(self)
    if self.onEnterExtra then self:onEnterExtra() end
    GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
    fill(GameTooltip, self)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function(self)
    if self.onLeaveExtra then self:onLeaveExtra() end
    GameTooltip:Hide()
  end)
end

local function gold(tt, text) tt:AddLine(text, 1, 0.82, 0) end
local function wrap(tt, text, r, g, b) tt:AddLine(text, r or 1, g or 1, b or 1, true) end

function W.statusText(id, n)
  local s = ns.Statuses[id]
  if not s then return tostring(id), "" end
  local text = (s.text or ""):gsub("X", tostring(n or "X"))
  return s.name, text
end

function W.addStatusLines(tt, id, n)
  local name, text = W.statusText(id, n)
  local s = ns.Statuses[id]
  local suffix = ""
  if n and n > 0 then suffix = s and s.duration and (" (" .. n .. " tour" .. (n > 1 and "s" or "") .. ")")
    or (" " .. n) end
  local bad = s and (s.debuff or s.affix)
  tt:AddLine(name .. suffix, bad and 1 or 0.4, bad and 0.35 or 0.9, bad and 0.35 or 0.4)
  wrap(tt, text)
end

-- Mots-clés d'une définition de carte (pour l'infobulle).
function W.cardKeywords(d)
  local list, seen = {}, {}
  local function add(k, label)
    if seen[k] then return end
    seen[k] = true
    list[#list + 1] = { key = k, label = label }
  end
  if d.cast then add("cast") end
  if d.cooldown then add("cooldown", "Recharge " .. d.cooldown) end
  if d.exhaust then add("exhaust") end
  if d.retain then add("retain") end
  if d.power then add("power") end
  for i = 1, #(d.effects or {}) do
    local e = d.effects[i]
    if e[1] == "absorb" then add("absorb")
    elseif e[1] == "demence" then add("demence")
    elseif e[1] == "interrupt" then add("interrupt")
    elseif e[1] == "apply" then add("status:" .. e[2]) end
  end
  return list
end

function W.fillCardTooltip(tt, id, up, extra)
  local d = Card.defById(id, up)
  local rc = Art.rarity[d.rarity] or Art.rarity.common
  tt:AddLine(d.name, rc[1], rc[2], rc[3])
  local line = (Art.typeName[d.type] or d.type or "") .. " · " .. (Art.schoolName[d.school] or d.school or "")
    .. " · " .. tostring(extra and extra.cost or d.cost) .. " mana"
  tt:AddLine(line, 0.7, 0.7, 0.7)
  wrap(tt, d.text or "")
  if extra and extra.preview and not up and ns.Cards[id].up then
    local u = Card.defById(id, true)
    tt:AddLine(" ")
    gold(tt, "Après amélioration :")
    wrap(tt, u.text or "", 0.5, 1, 0.5)
  end
  local kws = W.cardKeywords(d)
  if #kws > 0 then tt:AddLine(" ") end
  for i = 1, #kws do
    local k = kws[i]
    if k.key:sub(1, 7) == "status:" then
      W.addStatusLines(tt, k.key:sub(8))
    else
      local kw = Art.keywords[k.key]
      gold(tt, k.label or (kw and kw.name) or k.key)
      if kw then wrap(tt, kw.text, 0.85, 0.85, 0.85) end
    end
  end
  if extra and extra.reason then
    tt:AddLine(" ")
    tt:AddLine(extra.reason, 1, 0.3, 0.3, true)
  end
end

-- Bibelot, potion, or ou affixe : nom, effet, détail facultatif.
function W.fillItemTooltip(tt, kind, id, extra)
  if kind == "relic" then
    local r = ns.Relics[id]
    tt:AddLine(r and r.name or tostring(id), 0.6, 0.8, 1)
    tt:AddLine("Bibelot", 0.7, 0.7, 0.7)
    if r and r.text then wrap(tt, r.text) end
  elseif kind == "potion" then
    local p = ns.Potions[id]
    tt:AddLine(p and p.name or tostring(id), 0.5, 1, 0.5)
    tt:AddLine("Potion" .. ((p and p.target) and " · se lance sur un ennemi" or ""), 0.7, 0.7, 0.7)
    if p and p.text then wrap(tt, p.text) end
  elseif kind == "affix" then
    local a = ns.Affixes and ns.Affixes[id]
    gold(tt, a and a.name or tostring(id))
    if a and a.text then wrap(tt, a.text) end
  else
    gold(tt, extra and extra.title or "")
  end
  if extra and extra.text and kind ~= "relic" and kind ~= "potion" and kind ~= "affix" then wrap(tt, extra.text) end
  if extra and extra.hint then wrap(tt, extra.hint, 0.7, 0.7, 0.7) end
  if extra and extra.reason then wrap(tt, extra.reason, 1, 0.3, 0.3) end
end

function W.itemEntry(kind, id)
  if kind == "relic" then return Art.relic(id) end
  if kind == "potion" then return Art.potion(id) end
  if kind == "affix" then return Art.affixes[id] end
  if kind == "gold" then return Art.ui.gold end
  return nil
end

-- Petit bouton carré à icône (bibelot, potion, affixe) ; info = { kind, id, ... } pour l'infobulle.
function W.iconButton(parent, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.count = W.text(b, "NumberFontNormal", 10)
  b.count:SetPoint("BOTTOMRIGHT", 2, -2)
  W.tooltip(b, function(tt, self)
    local info = self.info
    if not info then return end
    W.fillItemTooltip(tt, info.kind, info.id, info)
  end, "ANCHOR_BOTTOM")
  b.SetItem = function(self, kind, id, info)
    self.info = info or {}
    self.info.kind = kind or self.info.kind
    self.info.id = id
    if kind and (id or kind == "gold" or kind == "keystone") then
      local entry = kind == "keystone" and Art.keystone or W.itemEntry(kind, id)
      W.setIcon(self.icon, entry, kind .. ":" .. tostring(id))
      self.icon:SetDesaturated(false)
    else
      W.setIcon(self.icon, Art.emptySlot, "ui:emptySlot")
    end
  end
  return b
end

-- Barre de réputation : bar = { label, levelName, cur, size, detail, hint } (UI/Controller.lua).
function W.repBar(parent, w)
  local f = CreateFrame("StatusBar", nil, parent)
  f:SetSize(w, 16)
  f:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  f:SetStatusBarColor(0.0, 0.6, 0.1)
  f:SetMinMaxValues(0, 1)
  f:SetValue(0)
  f:EnableMouse(true)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.6)
  f.label = W.text(f, "GameFontNormal")
  f.label:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 3)
  f.value = W.text(f, "GameFontHighlightSmall")
  f.value:SetPoint("CENTER")
  f.detail = W.text(f, "GameFontDisableSmall")
  f.detail:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -3)
  W.tooltip(f, function(tt, self)
    local b = self.bar
    if not b then return end
    gold(tt, b.label)
    tt:AddLine(b.levelName .. (b.size and (" : " .. b.cur .. " / " .. b.size) or " (palier maximal)"), 1, 1, 1)
    if b.hint then wrap(tt, b.hint, 0.8, 0.8, 0.8) end
  end, "ANCHOR_TOP")
  f.Set = function(self, b)
    self.bar = b
    self.label:SetText(b.label)
    if b.size then
      self:SetMinMaxValues(0, b.size)
      self:SetValue(b.cur)
      self.value:SetText(b.levelName .. "  " .. b.cur .. " / " .. b.size)
    else
      self:SetMinMaxValues(0, 1)
      self:SetValue(1)
      self.value:SetText(b.levelName)
    end
    self.detail:SetText(b.detail or "")
  end
  return f
end

---------------------------------------------------------------------------
-- Carte
---------------------------------------------------------------------------

W.CARD_W, W.CARD_H = 104, 148

function W.card(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(W.CARD_W, W.CARD_H)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  b.border = b:CreateTexture(nil, "BACKGROUND")
  b.border:SetAllPoints()
  b.border:SetColorTexture(1, 1, 1, 1)
  b.bg = b:CreateTexture(nil, "BORDER")
  b.bg:SetPoint("TOPLEFT", 3, -3)
  b.bg:SetPoint("BOTTOMRIGHT", -3, 3)
  b.bg:SetColorTexture(0.09, 0.08, 0.07, 1)

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(46, 46)
  b.icon:SetPoint("TOP", 0, -20)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  b.costBg = b:CreateTexture(nil, "ARTWORK")
  b.costBg:SetSize(22, 22)
  b.costBg:SetPoint("TOPLEFT", 4, -4)
  b.costBg:SetColorTexture(0.1, 0.25, 0.75, 1)
  b.cost = W.text(b, "GameFontHighlight", 13)
  b.cost:SetPoint("CENTER", b.costBg, "CENTER", 0, 0)

  b.name = W.text(b, "GameFontNormal", 10)
  b.name:SetPoint("TOPLEFT", 28, -6)
  b.name:SetPoint("TOPRIGHT", -4, -6)
  b.name:SetJustifyH("CENTER")
  b.name:SetHeight(12)

  b.kind = W.text(b, "GameFontDisableSmall", 8)
  b.kind:SetPoint("TOP", b.icon, "BOTTOM", 0, -2)

  b.body = W.text(b, "GameFontHighlightSmall", 9)
  b.body:SetPoint("TOPLEFT", 6, -82)
  b.body:SetPoint("BOTTOMRIGHT", -6, 6)
  b.body:SetJustifyH("CENTER")
  b.body:SetJustifyV("TOP")
  if b.body.SetWordWrap then b.body:SetWordWrap(true) end

  b.key = W.text(b, "NumberFontNormal", 10)
  b.key:SetPoint("BOTTOMLEFT", 5, 4)

  b.shade = b:CreateTexture(nil, "OVERLAY")
  b.shade:SetPoint("TOPLEFT", 3, -3)
  b.shade:SetPoint("BOTTOMRIGHT", -3, 3)
  b.shade:SetColorTexture(0, 0, 0, 0.45)
  b.shade:Hide()

  b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -1)
  b.glow:SetPoint("TOPLEFT", -4, 4)
  b.glow:SetPoint("BOTTOMRIGHT", 4, -4)
  b.glow:SetColorTexture(1, 0.85, 0.2, 0.9)
  b.glow:Hide()

  b.tag = W.text(b, "GameFontNormal", 11)
  b.tag:SetPoint("BOTTOM", b, "BOTTOM", 0, -16)

  b.SetCard = function(self, id, up, opts)
    opts = opts or {}
    local d = Card.defById(id, up)
    self.cardId, self.cardUp, self.opts = id, up, opts
    local rc = Art.rarity[d.rarity] or Art.rarity.common
    self.border:SetColorTexture(rc[1], rc[2], rc[3], 1)
    W.setIcon(self.icon, W.cardArt(id), "card:" .. id)
    self.cost:SetText(tostring(opts.cost or d.cost))
    self.name:SetText(d.name)
    if up then self.name:SetTextColor(0.5, 1, 0.5) else self.name:SetTextColor(1, 0.82, 0) end
    self.kind:SetText((Art.typeName[d.type] or "") .. " · " .. (Art.schoolName[d.school] or ""))
    self.body:SetText(d.text or "")
    self.key:SetText(opts.key or "")
    local dim = opts.playable == false
    self.icon:SetDesaturated(dim)
    if dim then self.shade:Show() else self.shade:Hide() end
    self.tag:SetText(opts.tag or "")
  end
  b.SetSelected = function(self, on)
    if on then self.glow:Show() else self.glow:Hide() end
  end

  W.tooltip(b, function(tt, self)
    if self.cardId then
      W.fillCardTooltip(tt, self.cardId, self.cardUp, self.opts)
    end
  end)
  return b
end

---------------------------------------------------------------------------
-- Icône d'état (avec compteur et infobulle)
---------------------------------------------------------------------------

function W.statusIcon(parent, size)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size or 18, size or 18)
  f:EnableMouse(true)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints()
  f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  f.count = W.text(f, "NumberFontNormal", 10)
  f.count:SetPoint("BOTTOMRIGHT", 2, -2)
  -- f.info = { status = id, n = n } ou { power = inst } ou { text = ..., title = ... }
  W.tooltip(f, function(tt, self)
    local info = self.info
    if not info then return end
    if info.status then
      W.addStatusLines(tt, info.status, info.n)
    elseif info.power then
      W.fillCardTooltip(tt, info.power.id, info.power.up)
    else
      gold(tt, info.title or "")
      if info.text then wrap(tt, info.text) end
    end
  end, "ANCHOR_TOP")
  return f
end

-- Rangée d'icônes d'état ; list = { {entry, key, count, info} }.
function W.statusRow(parent, size, maxN)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize((size + 2) * maxN, size)
  row.icons = {}
  for i = 1, maxN do
    local ic = W.statusIcon(row, size)
    ic:SetPoint("LEFT", (i - 1) * (size + 2), 0)
    ic:Hide()
    row.icons[i] = ic
  end
  row.Set = function(self, list)
    for i = 1, #self.icons do
      local ic, it = self.icons[i], list[i]
      if it then
        W.setIcon(ic.icon, it.entry, it.key)
        ic.count:SetText(it.count and it.count ~= 0 and tostring(it.count) or "")
        ic.info = it.info
        ic:Show()
      else
        ic.info = nil
        ic:Hide()
      end
    end
  end
  return row
end

-- Liste des états d'une unité, triée par nom d'id (stable).
function W.unitStatuses(unit)
  local ids = {}
  for id, v in pairs(unit.st or {}) do if v and v ~= 0 then ids[#ids + 1] = id end end
  table.sort(ids)
  local list = {}
  for i = 1, #ids do
    local id, n = ids[i], unit.st[ids[i]]
    list[#list + 1] = { entry = Art.statuses[id], key = "status:" .. id, count = n,
      info = { status = id, n = n } }
  end
  return list
end

---------------------------------------------------------------------------
-- Textes flottants (sans AnimationGroup : un OnUpdate suffit et reste portable)
---------------------------------------------------------------------------

local floatPool = {}

function W.float(anchor, text, r, g, b, dy, dur)
  local f
  for i = 1, #floatPool do
    if not floatPool[i].busy then f = floatPool[i] break end
  end
  if not f then
    f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(160, 20)
    f:SetFrameStrata("DIALOG")
    f.fs = W.text(f, "GameFontNormalLarge", 16)
    f.fs:SetPoint("CENTER")
    floatPool[#floatPool + 1] = f
  end
  f.busy = true
  f:SetParent(anchor)
  f:SetFrameStrata("DIALOG")
  f:ClearAllPoints()
  f:SetPoint("CENTER", anchor, "CENTER", 0, dy or 0)
  f.fs:SetText(text)
  f.fs:SetTextColor(r or 1, g or 1, b or 1)
  f:SetAlpha(1)
  f:Show()
  local t, total = 0, (dur or 1.2) * math.max(W.pace(), 0.5)
  f:SetScript("OnUpdate", function(self, elapsed)
    t = t + elapsed
    if t >= total then
      self:SetScript("OnUpdate", nil)
      self:Hide()
      self.busy = false
      return
    end
    self:ClearAllPoints()
    self:SetPoint("CENTER", anchor, "CENTER", 0, (dy or 0) + 30 * t / total)
    self:SetAlpha(1 - (t / total) ^ 2)
  end)
  return f
end

---------------------------------------------------------------------------
-- Modèles 3D
---------------------------------------------------------------------------

-- Anime un modèle puis revient à l'attente (ou reste figé pour « dead »).
function W.anim(model, anim, hold)
  if not model or not model.SetAnimation or model.dead then return end
  model:SetAnimation(anim)
  model.animToken = (model.animToken or 0) + 1
  local token = model.animToken
  if hold then
    W.delay(hold, function()
      if model.animToken == token and not model.dead then model:SetAnimation(Art.anim.stand) end
    end)
  end
end

local function hasModel(model)
  if not model.GetModelFileID then return true end
  local ok, id = pcall(model.GetModelFileID, model)
  return ok and id and id ~= 0
end

-- Affiche une créature : SetCreature, puis SetDisplayInfo, puis icône de repli.
function W.setCreature(model, enemyId, fallbackTex)
  local art = Art.enemies[enemyId] or {}
  model.dead = false
  model.enemyId = enemyId
  if model.ClearModel then model:ClearModel() end
  if fallbackTex then fallbackTex:Hide() end
  if art.creature then
    model:SetCreature(art.creature)
  elseif art.display then
    model:SetDisplayInfo(art.display)
  end
  if art.facing and model.SetFacing then model:SetFacing(art.facing) end
  local function check(stage)
    if model.enemyId ~= enemyId then return end
    if hasModel(model) then return end
    if stage == 1 and art.display and art.creature then
      model:SetDisplayInfo(art.display)
      W.delay(0.6, function() check(2) end)
      return
    end
    W.missing["model:" .. enemyId] = true
    if fallbackTex then
      W.setIcon(fallbackTex, { icon = Art.enemyIcon })
      fallbackTex:Show()
    end
  end
  W.delay(0.6, function() check(1) end)
end
