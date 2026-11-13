-- Langage des cartes : registre des mots que le texte des cartes peut employer, partagé par le
-- moteur (aucune règle ici), l'interface (couleurs, coupures, explications au survol) et le harnais
-- (forme des textes). Données pures, textes affichés en anglais.
--
-- Une classe ajoute ses mots depuis ses propres fichiers (Data/<Classe>.lua ou
-- Core/Classes/<classe>.lua) par les fonctions ci-dessous, sans toucher à ce fichier ni à l'interface.
-- Les noms des états (ns.Statuses) sont des mots-clés d'office : un état ajouté par une classe
-- (Parry, Stealth…) est coloré, insécable et expliqué sans autre déclaration.
--
--   L.resource(id, { name, plural, text })   ressource de classe (« +1 Rage. », « per Rage »)
--   L.condition(key, { name, text, pattern }) condition nommée « Name: effet » (Execute, Surge…)
--   L.trigger(label)                          libellé de déclencheur d'un Pouvoir (« When hit: … »)
--   L.plate(key, { word, head, flag, n, text }) mot de la plaque du bas (Cast, Cooldown N, Trap…)
--
-- Explications (`text`) : l'effet principal, une phrase de 60 caractères au plus avec le nom, sans
-- « ; », ni parenthèse ; « %s » = nom de la ressource de la classe de la carte, « N » = nombre.
local _, ns = ...

local L = {
  resources = {},   -- id -> { id, name, plural, text }
  conditions = {},  -- liste ordonnée { key, name, text, pattern }
  triggers = {},    -- libellé -> true
  plates = {},      -- liste ordonnée { key, word, head, flag, n, text }
}
ns.Language = L

local byKey = {}

function L.resource(id, t)
  t.id = id
  t.plural = t.plural or t.name
  L.resources[id] = t
  return t
end

-- Nom d'une ressource selon le nombre (« 1 Combo », « 2 Combo »).
function L.resourceName(id, n)
  local r = L.resources[id]
  if not r then return tostring(id) end
  if n and n ~= 1 and n ~= -1 then return r.plural end
  return r.name
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

local plateByKey = {}
function L.plate(key, t)
  t.key = key
  t.flag = t.flag or key
  t.name = t.name or t.word
  if plateByKey[key] then
    for k, v in pairs(t) do plateByKey[key][k] = v end
    return plateByKey[key]
  end
  plateByKey[key] = t
  L.plates[#L.plates + 1] = t
  return t
end

function L.plateByKey(key) return plateByKey[key] end

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

---------------------------------------------------------------------------
-- Conditions nommées (« Name: effet ») ; les états (« DoT: », « Atonement: ») s'y ajoutent d'office
---------------------------------------------------------------------------

L.condition("execute", { name = "Execute", text = "if the target has half its HP or less." })
L.condition("surge", { name = "Surge", text = "spends all %s for the effect." })
L.condition("spend", { name = "Spend", pattern = "^Spend %d+$", text = "pays N %s for the bonus, if available." })
L.condition("lastBreath", { name = "Last Breath", text = "once per combat, upon dropping to 0 HP." })
L.condition("shadow", { name = "Shadow", text = "applies to Shadow cards." })
-- prévues par le GDD (Paladin, Druid) : explications prêtes, règles à écrire par la classe
L.condition("frozen", { name = "Frozen", text = "if the target is Stunned or Demoralized." })
L.condition("demon", { name = "Demon", text = "bonus effect while a Demon is in play." })
L.condition("judgement", { name = "Judgement", text = "bonus effect when a Judgement card is played." })
L.condition("shift", { name = "Shift", text = "triggers on each change of form." })
L.condition("caster", { name = "Caster", text = "bonus effect in Caster form." })
L.condition("bear", { name = "Bear", text = "bonus effect in Bear form." })
L.condition("cat", { name = "Cat", text = "bonus effect in Cat form." })
L.condition("moonkin", { name = "Moonkin", text = "bonus effect in Moonkin form." })

-- Mots hors condition : coût en PV (« Pay 3 HP. », première ligne de la carte), pattern = forme exacte
-- de la clause dans le texte.
L.keyword("payHp", { name = "Pay N HP", pattern = "^Pay %d+ HP%.$", text = "costs HP, unplayable if it would drop to 0." })

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
L.plate("shift", { word = "Shift", head = true, flag = "shift", text = "changes form." })
L.plate("cast", { word = "Cast", head = true, text = "resolves at the start of the next turn." })
L.plate("cooldown", { word = "Cooldown", n = true, text = "returns to hand after N." })
L.plate("exhaust", { word = "Exhaust", text = "removed from combat once played." })
L.plate("retain", { word = "Retain", text = "stays in hand at the end of the turn." })
-- Innate (champ innate) : la carte est dans la main de départ de chaque combat, À LA PLACE d'une carte
-- piochée (la main garde sa taille) ; règle dans Combat.new.
L.plate("innate", { word = "Innate", text = "starts in the opening hand." })

-- Mot de la plaque d'une carte : « Cooldown 2 », « Trap »… (nil si la carte n'a pas ce mot).
function L.plateWord(p, d)
  local v = d[p.flag]
  if p.key == "power" and d.type == "power" then v = true end
  if p.key == "epic" then v = d.rarity == "epic" end
  if p.key == "power" and d.rarity == "epic" then v = nil end -- une épique dit « Epic », jamais « Power »
  if not v then return nil end
  if p.n then return p.word .. " " .. tostring(v) end
  return p.word
end
