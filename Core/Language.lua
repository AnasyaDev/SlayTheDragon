-- Langage des cartes : registre des mots que le texte des cartes peut employer, partagé par le
-- moteur (aucune règle ici), l'interface (couleurs, coupures, explications au survol) et le harnais
-- (forme des textes). Données pures, textes affichés en anglais.
--
-- Une classe ajoute ses mots depuis ses propres fichiers (Data/<Classe>.lua ou
-- Core/Classes/<classe>.lua) par les fonctions ci-dessous, sans toucher à ce fichier ni à l'interface.
-- Les noms des états (ns.Statuses) sont des mots-clés d'office : un état ajouté par une classe
-- (Parry, Stealth…) est coloré, insécable et expliqué sans autre déclaration.
--
--   L.resource(id, { name, plural, text, forms })   ressource de classe (« +1 Rage. », « per Rage ») ;
--                                             forms = noms selon la forme (Druid), voir L.resourceKey
--   L.condition(key, { name, text, pattern }) condition nommée « Name: effet » (Execute, Surge…)
--   L.trigger(label)                          libellé de déclencheur d'un Pouvoir (« When hit: … »)
--   L.plate(key, { word, head, flag, n, text }) mot de la plaque du bas (Cast, Cooldown N, Trap…)
--   L.plate(key, { field, values, head, name, text }) mot lu sur une valeur (plaque de forme du Druid)
--   L.rule(key, { name, text, upText, pattern }) mot de règle d'une épique (« Riposte 1 »), règle complète
--
-- Explications (`text`) : l'effet principal, une phrase de 60 caractères au plus avec le nom, sans
-- « ; », ni parenthèse ; « %s » = nom de la ressource de la carte (selon sa forme), « N » = nombre.
local _, ns = ...

local L = {
  resources = {},   -- id -> { id, name, plural, text, forms } (clé « id:forme » : voir L.resourceKey)
  conditions = {},  -- liste ordonnée { key, name, text, pattern }
  triggers = {},    -- libellé -> true
  plates = {},      -- liste ordonnée { key, word, head, flag, n, text } ou { key, field, values, … }
}
ns.Language = L

local byKey = {}

-- Ressource à noms multiples (Druid, docs/classes.md, « Ressource à noms multiples ») : une seule
-- valeur (c.player.res), dont le nom dépend d'une forme. t.forms[forme] = { name, plural, text } ;
-- forme = valeur du champ `form` des cartes (« cat », « bear »…), et en combat `c.cls.form`. Une forme
-- sans entrée (Tree of Life) et l'absence de forme gardent le nom de base (t.name : « Reserve »).
-- Clé de ressource : « id » ou « id:forme » (L.resourceKey) ; L.resources[clé] rend l'entrée de la forme
-- (le nom de base pour une forme sans entrée), si bien qu'une clé s'emploie partout où un id s'emploie
-- (L.resourceName, Art.keyword("res:" .. clé), Art.keywordLine(…, res = clé)). pairs(L.resources) ne
-- parcourt que les ids de base : L.resourceKeys() donne aussi les clés des formes.
setmetatable(L.resources, { __index = function(t, key)
  if type(key) ~= "string" then return nil end
  local id, form = key:match("^([^:]+):(.+)$")
  local r = id and rawget(t, id)
  if not r then return nil end
  return (r.forms and r.forms[form]) or r
end })

function L.resource(id, t)
  t.id = id
  t.plural = t.plural or t.name
  for form, v in pairs(t.forms or {}) do
    v.id, v.base, v.form = id .. ":" .. form, id, form
    v.plural = v.plural or v.name
    v.text = v.text or t.text
  end
  rawset(L.resources, id, t)
  return t
end

-- Clé de la ressource id dans la forme form (nil = sans forme) : « id:forme » si la ressource a un nom
-- propre à cette forme, sinon id.
function L.resourceKey(id, form)
  local r = id and rawget(L.resources, id)
  if form and r and r.forms and r.forms[form] then return id .. ":" .. form end
  return id
end

-- Toutes les clés de ressource (ids de base et clés des formes), triées.
function L.resourceKeys()
  local out = {}
  for id, r in pairs(L.resources) do
    out[#out + 1] = id
    for form in pairs(r.forms or {}) do out[#out + 1] = id .. ":" .. form end
  end
  table.sort(out)
  return out
end

-- Nom d'une ressource selon le nombre (« 1 Combo », « 2 Combo ») ; id = id ou clé de ressource ; form
-- (facultatif) = forme (« +1 Combo. » d'une carte Cat, « +1 Frenzy » d'un gain en Bear).
function L.resourceName(id, n, form)
  local r = L.resources[form and L.resourceKey(id, form) or id]
  if not r then return tostring(id) end
  if n and n ~= 1 and n ~= -1 then return r.plural end
  return r.name
end

-- Clés de ressource qu'une carte peut nommer, la sienne d'abord : ressource de sa classe dans la forme
-- de la carte (d.form) ; pour une carte sans forme d'une classe à noms multiples (Power), aussi la forme
-- que nomme le libellé d'une clause (« Cat Attacks: +1 Combo. », « End of turn in Moonkin: … »), d'après
-- les mots de la plaque de forme. Liste vide pour une carte neutre.
function L.cardResourceKeys(d)
  local cd = d and d.class and ns.Classes and ns.Classes[d.class]
  local rid = cd and cd.resource and cd.resource.id
  if not rid then return {} end
  local out = { L.resourceKey(rid, d.form) }
  local r = rawget(L.resources, rid)
  if r and r.forms and not d.form then
    local forms = {}
    for form in pairs(r.forms) do forms[#forms + 1] = form end
    table.sort(forms)
    local seen = {}
    for cl in ((d.text or "") .. "\n"):gmatch("(.-)\n") do
      local lab = cl:match("^(.-): ")
      for _, form in ipairs(lab and forms or {}) do
        local word = L.formWord(form)
        if word and not seen[form] and lab:find("%f[%w]" .. word .. "%f[^%w]") then
          seen[form] = true
          out[#out + 1] = rid .. ":" .. form
        end
      end
    end
  end
  return out
end

-- Clé de la ressource d'une carte (L.cardResourceKeys(d)[1]) ou nil.
function L.cardResource(d)
  return L.cardResourceKeys(d)[1]
end

-- Clé de la ressource en combat : ressource de la classe dans la forme active (c.cls.form).
function L.combatResource(c)
  local cd = c and ns.Classes and ns.Classes[c.class]
  local rid = cd and cd.resource and cd.resource.id
  return rid and L.resourceKey(rid, c.cls and c.cls.form) or nil
end

function L.condition(key, t)
  t.key = key
  if byKey[key] then
    for k, v in pairs(t) do byKey[key][k] = v end
    return byKey[key]
  end
  byKey[key] = t
  L.conditions[#L.conditions + 1] = t
  return t
end

function L.conditionByKey(key) return byKey[key] end

function L.trigger(label) L.triggers[label] = true end

-- Mots expliqués au survol qui ne sont ni des conditions ni des états (« Pay N HP », Absorb…).
L.keywords = {}
function L.keyword(key, t)
  t.key = key
  L.keywords[key] = t
  return t
end

-- Mot de règle d'une épique (14/11/2026 : une épique tient en deux lignes au plus) : la carte dit
-- « Déclencheur: Nom N. » (« Each Parry gained: Riposte 1. »), l'à-côté donne la règle complète.
-- t = { name, text, upText facultatif (carte améliorée), pattern facultatif (clause où le nom compte,
-- quand deux épiques emploient le même nom) }. text : une ou deux phrases courtes, 110 caractères au
-- plus avec le nom (harnais U27), majuscule en tête ; « N » = le nombre qui suit le nom sur la carte.
-- Le nom est un mot-clé du texte : coloré, insécable s'il est en plusieurs mots, expliqué au survol.
function L.rule(key, t)
  t.rule = true
  return L.keyword(key, t)
end

local function escape(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- Mots de règle cités par le texte d'une carte : liste { key, kw, n } (n = nombre après le nom, ou nil),
-- dans l'ordre des clauses, puis des clés.
function L.ruleWords(d)
  local out, seen = {}, {}
  local keys = {}
  for key, kw in pairs(L.keywords) do if kw.rule then keys[#keys + 1] = key end end
  table.sort(keys)
  for cl in ((d and d.text or "") .. "\n"):gmatch("(.-)\n") do
    for _, key in ipairs(keys) do
      local kw = L.keywords[key]
      local _, e = cl:find("%f[%w]" .. escape(kw.name) .. "%f[^%w]")
      if e and not seen[key] and (not kw.pattern or cl:find(kw.pattern)) then
        seen[key] = true
        out[#out + 1] = { key = key, kw = kw, n = tonumber((cl:sub(e + 1):match("^ %+?(%-?%d+)"))) }
      end
    end
  end
  return out
end

-- Règle d'un mot de règle (texte de l'à-côté, sans le nom) : upText sur une carte améliorée, N remplacé.
function L.ruleText(kw, n, up)
  local text = (up and kw.upText) or kw.text or ""
  if n then text = text:gsub("%f[%w]N%f[%W]", tostring(n)) end
  return text
end

-- Mot-clé d'une zone (Curse, Pack, Hex, Asleep, Wildfire, Phase…) : explication au survol (infobulles
-- des cartes, des ennemis, des intentions), comme L.keyword, avec zone = id. L.zoneWords[zone] = clés.
-- t = { name, text (60 caractères au plus), pattern facultatif }.
L.zoneWords = {}
function L.zoneKeyword(zone, key, t)
  t.zone = zone
  L.keyword(key, t)
  local list = L.zoneWords[zone] or {}
  L.zoneWords[zone] = list
  for i = 1, #list do if list[i] == key then return t end end
  list[#list + 1] = key
  return t
end

-- Mot de plaque lu sur une valeur (t.field, plaque de forme du Druid) : t.values[valeur] = { word, name,
-- text } ; la carte porte le mot de sa valeur (d[t.field]), aucun mot sans valeur. Une seule entrée du
-- registre (un seul mot-clé) ; chaque valeur a son explication, clé « key:valeur » (L.plateByKey), dont
-- `text` est la ligne entière de l'infobulle, le nom (`name`, ou `word`) y étant écrit et coloré
-- (`inline = true` : « Enters Cat (Combo). End of turn: next Attack costs 0. »). t.name / t.text : nom
-- et règle commune de l'entrée (registre).
local plateByKey = {}
function L.plate(key, t)
  t.key = key
  t.flag = t.flag or key
  t.name = t.name or t.word
  for value, v in pairs(t.values or {}) do
    v.key, v.value, v.plate, v.head = key .. ":" .. value, value, key, t.head
    v.name = v.name or v.word
    v.inline = true
  end
  if plateByKey[key] then
    for k, v in pairs(t) do plateByKey[key][k] = v end
    return plateByKey[key]
  end
  plateByKey[key] = t
  L.plates[#L.plates + 1] = t
  return t
end

-- Entrée d'un mot de plaque : clé « key », ou « key:valeur » pour une plaque lue sur une valeur.
function L.plateByKey(key)
  local p = plateByKey[key]
  if p then return p end
  local k, value = key:match("^([^:]+):(.+)$")
  p = k and plateByKey[k]
  return p and p.values and p.values[value] or nil
end

-- Mot de plaque d'une forme (« cat » -> « Cat », « tree » -> « Tree ») : plaque lue sur le champ `form`.
function L.formWord(form)
  for _, p in ipairs(L.plates) do
    if p.field == "form" then
      local v = p.values and p.values[form]
      return v and v.word or nil
    end
  end
  return nil
end

-- Le libellé « Name » d'une clause « Name: effet » est-il connu (condition, état, déclencheur) ?
function L.knownLabel(label)
  if L.triggers[label] then return true end
  for _, c in ipairs(L.conditions) do
    if c.name == label or (c.pattern and label:find(c.pattern)) then return true end
  end
  for _, s in pairs(ns.Statuses) do
    if s.name == label then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Ressources des classes prévues par le GDD (docs/gdd-classes.md)
---------------------------------------------------------------------------

L.resource("insanity", { name = "Insanity", text = "resource gained by Shadow cards." })
L.resource("rage", { name = "Rage", text = "+1 per Attack played and per hit taken, up to 5." })
L.resource("combo", { name = "Combo", plural = "Combo", text = "gained by openers, spent by finishers, up to 5." })
L.resource("arcane", { name = "Charge", plural = "Charges", text = "+1 damage to Attacks per charge, up to 4." })
L.resource("shards", { name = "Soul Shard", plural = "Soul Shards", text = "gained from kills and drains, up to 5." })
L.resource("frenzy", { name = "Frenzy", text = "+1 pet damage per point, up to 5." })
L.resource("holy", { name = "Holy Power", text = "gained by basic cards, up to 3." })
L.resource("maelstrom", { name = "Maelstrom", text = "+1 per Attack, at 5 the next Cast is instant." })
-- Druid (docs/classes/druid.md, § 1.2) : une réserve, nommée selon la forme ; « Reserve » sans forme et
-- en Tree of Life (aucune entrée « tree »). Explications ramenées à une phrase de 60 caractères avec le nom.
L.resource("wild", { name = "Reserve", text = "kept between forms, used by Cat, Bear and Moonkin.",
  forms = {
    cat = { name = "Combo", text = "kept between forms and turns, Surge spends it all." },
    bear = { name = "Frenzy", text = "Bear strikes for 1 + Frenzy, −1 each round in Bear." },
    moonkin = { name = "Charge", plural = "Charges", text = "+1 to each Attack hit per Charge, up to 5." },
  } })

---------------------------------------------------------------------------
-- Conditions nommées (« Name: effet ») ; les états (« DoT: », « Atonement: ») s'y ajoutent d'office
---------------------------------------------------------------------------

L.condition("execute", { name = "Execute", text = "if the target has half its HP or less." })
L.condition("surge", { name = "Surge", text = "spends all %s for the effect." })
L.condition("spend", { name = "Spend", pattern = "^Spend %d+$", text = "pays N %s for the bonus, if available." })
L.condition("lastBreath", { name = "Last Breath", text = "once per combat, upon dropping to 0 HP." })
L.condition("shadow", { name = "Shadow", text = "applies to Shadow cards." })
-- prévues par le GDD (Mage, Warlock, Paladin) : explications prêtes, règles à écrire par la classe
L.condition("frozen", { name = "Frozen", text = "if the target is Stunned or Demoralized." })
L.condition("demon", { name = "Demon", text = "bonus effect while a Demon is in play." })
L.condition("judgement", { name = "Judgement", text = "bonus effect when a Judgement card is played." })

-- Mots hors condition : coût en PV (« Pay 3 HP. », première ligne de la carte), pattern = forme exacte
-- de la clause dans le texte.
L.keyword("payHp", { name = "Pay N HP", pattern = "^Pay %d+ HP%.$", text = "costs HP, unplayable if it would drop to 0." })
-- Druid : frappe de l'ours (« Bear strikes. », « Bear strikes twice. », « Surge: Bear strikes once per
-- Frenzy. »), pendant de « Pet attacks. » ; base 1 (fiche, § 1.4) : la classe redéclare le mot si sa
-- base change. Aussi déclencheur des épiques (« Bear strikes: … »).
L.keyword("bearStrike", { name = "Bear strikes", pattern = "Bear strikes",
  text = "hits the last target for 1 + Frenzy, then +1." })
L.trigger("Bear strikes")

-- Libellés de déclencheur des Pouvoirs (« When hit: … ») : pas des conditions, pas d'explication.
for _, label in ipairs({ "Each Absorb gain", "Cast cards", "When hit", "HP lost", "Attacks", "Start of turn", "End of turn" }) do
  L.trigger(label)
end

---------------------------------------------------------------------------
-- Mots de la plaque du bas : en tête (« Power. », « Cast. ») ou en fin (« Cooldown N. », « Exhaust. »)
-- du texte, retirés à l'affichage et montrés sur la plaque. flag = champ de la carte ; n = le mot
-- porte le nombre du champ (« Cooldown 2 »). Ordre = ordre sur la plaque.
---------------------------------------------------------------------------

-- Epic (rareté epic) : en tête de la plaque, à la place de « Power » ; la carte n'a pas de coût, elle est en
-- jeu dès le début de chaque combat (Combat.new : c.epic). Mot de tête facultatif « Epic. » dans le texte.
L.plate("epic", { word = "Epic", head = true, text = "in play from the start of each combat." })
L.plate("power", { word = "Power", head = true, text = "stays active until the end of combat." })
L.plate("trap", { word = "Trap", head = true, text = "triggers on the next enemy attack." })
L.plate("seal", { word = "Seal", head = true, text = "only one Seal at a time, a new one replaces it." })
L.plate("demon", { word = "Demon", head = true, text = "only one Demon at a time, a new one replaces it." })
L.plate("totem", { word = "Totem", head = true, n = true, text = "a Power that lasts N." })
-- Forme (Druid, docs/classes/druid.md, § 1.8) : un seul mot-clé pour les quatre mots, lu sur d.form,
-- premier mot de la plaque (« Moonkin · Cast »), jamais écrit dans `text` (toléré en tête : retiré
-- comme « Cast. »). Infobulles de la fiche, ligne entière (nom coloré dans le texte).
L.plate("form", { head = true, field = "form", name = "Form", text = "playing the card enters its form.",
  values = {
    cat = { word = "Cat", text = "Enters Cat (Combo). End of turn: next Attack costs 0." },
    bear = { word = "Bear", text = "Enters Bear (Frenzy). End of turn: Bear strikes." },
    moonkin = { word = "Moonkin", text = "Enters Moonkin (Charges). End of turn: 1 to all per 2." },
    tree = { word = "Tree", name = "Tree of Life", text = "Enters Tree of Life. End of turn: gain Regen 1." },
  } })
L.plate("cast", { word = "Cast", head = true, text = "resolves at the start of the next turn." })
L.plate("cooldown", { word = "Cooldown", n = true, text = "returns to hand after N." })
L.plate("exhaust", { word = "Exhaust", text = "removed from combat once played." })
L.plate("retain", { word = "Retain", text = "stays in hand at the end of the turn." })
-- Innate (champ innate) : la carte est dans la main de départ de chaque combat, À LA PLACE d'une carte
-- piochée (la main garde sa taille) ; règle dans Combat.new.
L.plate("innate", { word = "Innate", text = "starts in the opening hand." })

-- Mot de la plaque d'une carte : « Cooldown 2 », « Trap », « Moonkin »… (nil si la carte n'a pas ce mot).
function L.plateWord(p, d)
  if p.field then
    local e = d[p.field] ~= nil and p.values and p.values[d[p.field]]
    return e and e.word or nil
  end
  local v = d[p.flag]
  if p.key == "power" and d.type == "power" then v = true end
  if p.key == "epic" then v = d.rarity == "epic" end
  if p.key == "power" and d.rarity == "epic" then v = nil end -- une épique dit « Epic », jamais « Power »
  if not v then return nil end
  if p.n then return p.word .. " " .. tostring(v) end
  return p.word
end

-- Clé de l'explication du mot de plaque p sur la carte d (« cooldown », « form:bear »), nil sans mot.
function L.plateKey(p, d)
  if not L.plateWord(p, d) then return nil end
  if p.field then return p.key .. ":" .. tostring(d[p.field]) end
  return p.key
end
