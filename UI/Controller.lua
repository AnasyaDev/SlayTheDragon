-- Contrôleur : couche mince entre les écrans et Core/Expedition.lua. Aucune règle de jeu ici :
-- ce qui est possible vient de Expedition.choices, les refus (et leur raison) de
-- Expedition.act, les prix et tirages de l'état de l'expédition. Le contrôleur traduit la
-- phase courante en « étape » générique pour les écrans (UI/Screens.lua, UI/CombatView.lua).
-- Lua 5.1 pur, sans API WoW (testé hors jeu par Sim/ui_harness.lua).
--
-- L'expédition en cours EST SlayTheDragonDB.current (Core/Save.lua) : modifiée sur place par
-- Expedition.act, donc toujours à jour pour la prochaine écriture du fichier par WoW.
-- État propre à l'interface (jamais sauvegardé) :
--   C.ended  = { c, result, title } : combat tranché, bandeau de fin affiché sur l'écran de combat
--   C.ending = { summary, entry }   : expédition archivée (Save.finish), bilan affiché
--   C.ui     = { view, class, key, progressClass, progressTab } : sous-écran (amélioration, retrait,
--              progression, journal), choix de départ, classe et onglet (cartes, zones, talents) de l'écran de
--              progression (consultable pendant une expédition hors combat : arbre en lecture seule)
--
-- Identifiants d'options : « verbe » ou « verbe:argument », où verbe est une action de
-- Expedition.act (path:12, pickCard:2, buyRelic:1, remove:5, choose:1, leave, continue…), ou une
-- navigation de l'interface (ui:upgrade, ui:remove, ui:progress, ui:meta, ui:back, ui:new), un choix de
-- départ (class:priest, key:2, go), une classe ou un onglet de l'écran de progression
-- (pclass:warrior, ptab:zones, ptab:cards, ptab:talents), un talent (talent:<nœud> : un rang ; tspec:<voie> : voie
-- du nœud Specialization ; treset : remboursement). Accueil : les zones de la campagne (zone:<id>) sont affichées,
-- pas choisies (toute expédition part de Westfall).
local _, ns = ...

local U, Combat, Card, X, Save, Meta, Map = ns.Util, ns.Combat, ns.Card, ns.Expedition, ns.Save, ns.Meta, ns.Map
local max, min = math.max, math.min

local C = {}
ns.Controller = C

C.listeners = {}
C.lastEvents = {}
C.END_LEVEL_LINES = 4 -- bilan : une ligne par niveau gagné jusqu'à 4 niveaux d'un coup, une seule au-delà
C.ended = nil
C.ending = nil
C.ui = {}

C.REASONS = {
  -- combat (Core/Combat.lua)
  phase = "It's not your turn.",
  card = "Card not found.",
  unplayable = "This card can't be played.",
  keep = "This card can't be kept.",
  mana = "Not enough mana.",
  casting = "A cast is already in progress.",
  forbidden = "Forbidden by an active Power.",
  condition = "Condition not met.",
  hp = "Not enough HP to pay.",
  resource = "Not enough %s.",
  traps = "Too many Traps already set.",
  target = "Invalid target.",
  over = "The combat is over.",
  combat = "The combat must end first.",
  potions = "Potions can't be used in combat yet.",
  -- expédition (Core/Expedition.lua, Core/Meta.lua, Core/Save.lua)
  gold = "Not enough gold.",
  slot = "No free potion slot.",
  item = "Already sold.",
  badCard = "Not possible with this card.",
  path = "Stage out of reach.",
  action = "Not possible here.",
  potion = "No potion to take.",
  index = "Invalid choice.",
  choice = "A choice is needed first.",
  chosen = "Choice already made.",
  deck = "Deck too small.",
  upgrade = "No card to upgrade.",
  maxed = "Fully upgraded.",
  noUpgrade = "Can't be upgraded.",
  relic = "Relic already owned.",
  epic = "An epic card can't be copied.",
  ended = "The expedition is over.",
  ["key locked"] = "This key isn't unlocked yet.",
  ["zone locked"] = "This zone isn't open to this class yet.",
  ["zone coming later"] = "This zone is coming later.",
  zone = "Unknown zone.",
  running = "An expedition is already in progress.",
}

-- Talents (docs/talents.md, § 11 et § 17.7) : raisons d'un rang refusé (ns.Talent.canLearn, Save.learnTalent) ;
-- « row » : la condition de la rangée (C.talentRowText).
C.TALENT_REASONS = {
  points = "No talent points to spend.",
  max = "Maximum rank.",
  running = "Talents can't change during an expedition.",
  choice = "Already your specialization.",
  unknown = "Unknown talent.",
  spent = "No talent points spent.",
}
C.TALENT_RUNNING_LINE = "An expedition is in progress: talents can't change until it ends."

function C.talentRowText(n)
  return "Spend " .. n .. " point" .. (n == 1 and "" or "s") .. " to unlock."
end

-- « 3 talent points to spend » (1 : « 1 talent point »).
function C.talentPointsText(n)
  return n .. " talent point" .. (n == 1 and "" or "s")
end

-- « %s » : nom de la ressource de la classe jouée (« Not enough Rage. ») ; d (facultatif) = la carte refusée :
-- nom dans la forme de la carte (L.cardResource : « Not enough Combo. » pour une carte Cat du Druid), sinon
-- dans la forme active du combat (L.combatResource), sinon l'id de base. Classe à un seul nom : inchangé.
function C.reasonText(why, d)
  local tk = tostring(why):match("^talent:(.+)$")
  if tk then
    return tk == "row" and "Spend more points in the tree to unlock this row." or C.TALENT_REASONS[tk] or tk
  end
  local t = C.REASONS[why] or tostring(why)
  if t:find("%s", 1, true) then
    local L = ns.Language
    local exp = C.exp()
    local cls = exp and exp.class or "priest"
    local key = d and d.class == cls and L.cardResource(d) or nil
    if not key then
      local c = C.combat()
      key = c and c.class == cls and L.combatResource(c) or nil
    end
    if not key then
      local cd = ns.Classes[cls]
      key = cd and cd.resource and cd.resource.id
    end
    t = t:gsub("%%s", key and L.resourceName(key, 2) or "resource") -- pluriel : « Not enough Combo. »
  end
  return t
end

function C.onChange(fn)
  C.listeners[#C.listeners + 1] = fn
end

local function notify(kind, data)
  for i = 1, #C.listeners do C.listeners[i](kind, data) end
end

function C.db() return ns.Persist.db end

function C.exp()
  local db = ns.Persist.db
  return db and db.current or nil
end

-- Carte proposée (récompense, marchand) telle qu'elle se jouerait dans ce deck : variante de l'épique du
-- deck (transforms, Lone Wolf) avec from = l'originale, sinon la carte elle-même.
local function shownCard(exp, id)
  local map = Card.transformsOf(exp.deck)
  local v = map and map[id]
  if v and ns.Cards[v] then return { id = v, up = false, from = id } end
  return { id = id, up = false }
end

-- Date affichée dans le journal (date() existe en jeu ; repli : horodatage).
function C.date()
  if type(date) == "function" then
    local ok, s = pcall(date, "%Y-%m-%d %H:%M")
    if ok and type(s) == "string" then return s end
  end
  return type(time) == "function" and time() or 0
end

function C.makeSeed()
  local t = 0
  if type(time) == "function" then t = time() end
  local g = 0
  if type(GetTime) == "function" then g = math.floor(GetTime() * 1000) end
  return (t * 7 + g) % 2147483646 + 1
end

---------------------------------------------------------------------------
-- Validation d'un état restauré : Save vérifie la structure, l'interface vérifie
-- que tout ce qu'elle va afficher existe encore (cartes, ennemis, bibelots renommés…).
---------------------------------------------------------------------------

local function validCard(inst)
  if type(inst) ~= "table" then return false end
  local def = ns.Cards[inst.id]
  if not def then return false end
  if Card.level(inst) > Card.tiers(inst.id) then return false end -- palier non écrit (carte renommée…)
  return true
end

local function validPile(t)
  if type(t) ~= "table" then return false end
  for i = 1, #t do if not validCard(t[i]) then return false end end
  return true
end

function C.validateCombat(c)
  if type(c) ~= "table" or type(c.player) ~= "table" or type(c.enemies) ~= "table" then
    return false, "structure"
  end
  if not (c.rng and c.rng.draw and c.rng.ai and c.rng.misc) then return false, "rng" end
  for _, k in ipairs({ "hand", "draw", "discard", "exhaust" }) do
    if not validPile(c[k]) then return false, "pile " .. k end
  end
  if not validPile(c.player.powers or {}) then return false, "powers" end
  if c.epic ~= nil and not validCard(c.epic) then return false, "epic" end
  if c.moreEpics ~= nil and not validPile(c.moreEpics) then return false, "epic" end
  if type(c.cooldown) ~= "table" then return false, "cooldown" end
  for i = 1, #c.cooldown do
    if not validCard(c.cooldown[i].card) then return false, "cooldown" end
  end
  if c.player.cast and not validCard(c.player.cast.card) then return false, "cast" end
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    local def = ns.Enemies[e.id]
    if not def then return false, "unknown enemy " .. tostring(e.id) end
    if not e.dead and e.intent and not ns.Combat.moveOf(e.id, e.intent) then return false, "move" end
  end
  return true
end

local function knownIds(list, registry, what)
  for i = 1, #(list or {}) do
    local id = list[i]
    if id and not registry[id] then return false, "unknown " .. what .. " " .. tostring(id) end
  end
  return true
end

function C.validateExpedition(exp)
  local ok, why = knownIds(exp.relics, ns.Relics, "relic")
  if not ok then return false, why end
  ok, why = knownIds(exp.potions, ns.Potions, "potion")
  if not ok then return false, why end
  if exp.combat then
    ok, why = C.validateCombat(exp.combat)
    if not ok then return false, why end
    ok, why = knownIds(exp.combat.relics, ns.Relics, "relic")
    if not ok then return false, why end
  end
  local r = exp.reward
  if r then
    ok, why = knownIds(r.cards, ns.Cards, "card")
    if not ok then return false, why end
    ok, why = knownIds(r.epics, ns.Cards, "card")
    if not ok then return false, why end
    if r.relic and not ns.Relics[r.relic] then return false, "unknown relic" end
    if r.potion and not ns.Potions[r.potion] then return false, "unknown potion" end
  end
  if exp.shop then
    for _, k in ipairs({ "cards", "relics", "potions" }) do
      local reg = k == "cards" and ns.Cards or k == "relics" and ns.Relics or ns.Potions
      for _, it in ipairs(exp.shop[k] or {}) do
        if not reg[it.id] then return false, "unknown item " .. tostring(it.id) end
      end
    end
  end
  if exp.event and exp.event.id and not (ns.Events and ns.Events[exp.event.id]) then
    return false, "unknown encounter"
  end
  ok, why = knownIds(exp.talentEpics, ns.Cards, "card")
  if not ok then return false, why end
  return knownIds(exp.startRelics, ns.Relics, "relic")
end

---------------------------------------------------------------------------
-- Cycle de vie
---------------------------------------------------------------------------

-- Reprise depuis la sauvegarde. Un état devenu illisible part en quarantaine (Save), pas en jeu.
function C.restore()
  C.ended, C.ending, C.ui = nil, nil, {}
  C.restoreNote = nil
  local db = ns.Persist.db
  local exp = db and db.current
  if exp then
    local ok, why = C.validateExpedition(exp)
    if not ok then
      Save.quarantine(db, "interface: " .. tostring(why))
      C.restoreNote = why
    else
      if exp.combat then
        exp.combat.events = {}
        -- Combat tranché mais pas conclu (sauvegarde au mauvais moment) : on le conclut.
        if exp.combat.result then C.act({ "endTurn" }) end
      end
    end
  end
  notify("restore")
  return C.exp() ~= nil
end

-- Démarre une expédition à Westfall (Save.start : clé vérifiée par Meta).
function C.start(class, key, seed)
  local db = ns.Persist.db
  local exp, why = Save.start(db, { seed = seed or C.makeSeed(), class = class, key = key })
  if not exp then return false, why end
  C.ending, C.ended, C.ui.view = nil, nil, nil
  ns.Persist.talentNotice = nil -- ligne « You have N talent points to spend. » de l'accueil : vue
  notify("step")
  return true
end

-- Archive l'expédition terminée et garde le bilan pour l'écran de fin.
function C.finish()
  local db = ns.Persist.db
  local summary, entry = Save.finish(db, C.date())
  if summary then C.ending = { summary = summary, entry = entry } end
end

function C.abandon()
  local db = ns.Persist.db
  if not db.current then return false end
  local summary, entry = Save.abandon(db, C.date())
  C.ending = summary and { summary = summary, entry = entry } or nil
  C.ended, C.ui.view = nil, nil
  notify("step")
  return true
end

local FIGHT_TITLE = { combat = "Combat", elite = "Elite", boss = "Boss" }

-- Applique une action d'expédition. Renvoie ok, raison, événements de combat produits.
function C.act(a)
  local exp = C.exp()
  if not exp then return false, "ended" end
  local c = exp.combat
  local title = exp.fight and FIGHT_TITLE[exp.fight.kind]
  local kindBefore = exp.fight and exp.fight.kind
  local ok, why = X.act(exp, a)
  if not ok then return false, why end
  -- boss battu, zone atteinte : reportés tout de suite dans la méta (épique, commun, expérience, drapeaux)
  Save.settle(ns.Persist.db)
  local evs = {}
  if c then
    evs = c.events or {}
    c.events = {}
    if c.result and exp.combat ~= c then
      C.ended = { c = c, result = c.result, title = title, kind = kindBefore }
      C.lastFightKind = kindBefore
    end
  end
  -- Nouveau combat (chemin, rencontre) : ses événements d'ouverture ne sont pas rejoués.
  if exp.combat and exp.combat ~= c then
    C.lastEvents = exp.combat.events or {}
    exp.combat.events = {}
  end
  if exp.phase == "done" then C.finish() end
  return true, nil, evs
end

-- Épique remplacée par l'option id (récompense, marchand, rencontre) : rejouée sur une copie ; renvoie
-- { old = { id, up }, new = { id, up } } si l'action ferait partir l'épique du deck pour une autre, sinon
-- nil. L'interface demande alors confirmation (« Replace A with B? » / « Keep A »).
function C.epicSwap(id)
  local exp = C.exp()
  if not exp or C.ended or exp.phase == "combat" then return nil end
  local verb, arg = tostring(id):match("^([%a_]+):(.+)$")
  if not verb then verb = id end
  if verb == "ui" then return nil end
  local i = X.epicIndex(exp)
  if not i then return nil end
  local copy = U.copy(exp)
  local before = copy.stats.epicReplaced or 0
  if not X.act(copy, { verb, tonumber(arg) or arg }) then return nil end
  if (copy.stats.epicReplaced or 0) <= before then return nil end
  local j = X.epicIndex(copy)
  if not j then return nil end
  local old = exp.deck[i]
  return { old = { id = old.id, up = old.up }, new = { id = copy.deck[j].id, up = copy.deck[j].up } }
end

-- Rejoue une action sur une copie : raison du refus, sans rien changer.
function C.reasonFor(a)
  local exp = C.exp()
  if not exp then return nil end
  local ok, why = X.act(U.copy(exp), a)
  if ok then return nil end
  return C.reasonText(why)
end

---------------------------------------------------------------------------
-- Choix d'une option
---------------------------------------------------------------------------

local function parse(id)
  local verb, arg = tostring(id):match("^([%a_]+):(.+)$")
  if not verb then return id, nil end
  return verb, tonumber(arg) or arg
end

local function navigate(where)
  if where == "back" then
    C.ui.view = nil
  elseif where == "new" then
    C.ending, C.ui.view = nil, nil
  elseif where == "upgrade" or where == "remove" or where == "meta" then
    C.ui.view = where
  elseif where == "progress" or where == "talents" then
    -- depuis l'accueil ou le bilan : la classe choisie (ou celle de l'expédition finie) ; retour de
    -- la méta : la classe déjà affichée ; « talents » (bilan : « Spend talent points », panneau du deck
    -- pendant une expédition) : onglet Talents. Pendant une expédition : hors combat seulement.
    local exp = C.exp()
    if exp and (C.ended or exp.phase == "combat") then return false, "combat" end
    if C.ui.view ~= "meta" then C.ui.progressClass = nil end
    if where == "talents" then C.ui.progressTab = "talents" end
    C.ui.view = "progress"
    ns.Persist.talentNotice = nil
  else
    return false, "action"
  end
  notify("step")
  return true
end

-- Talents de la classe affichée par l'écran de progression (hors expédition : Save refuse sinon) : un rang du
-- nœud (talent:<nœud>), la voie du nœud à choix (tspec:<voie>), le remboursement (treset, gratuit). Refus :
-- « talent:<raison> » (C.TALENT_REASONS, par C.reasonText).
local function talentAct(verb, arg)
  local db = ns.Persist.db
  local cid = C.progressClass()
  local ok, why
  if verb == "treset" then
    if db.current then return false, "talent:running" end
    if Meta.spent(db.meta, cid) <= 0 then return false, "talent:spent" end
    ok, why = Save.resetTalents(db, cid)
  else
    local node, choice = arg, nil
    if verb == "tspec" then
      local tree = ns.Talent.tree(cid)
      node, choice = nil, arg
      for _, n in ipairs(tree and tree.nodes or {}) do if n.choices then node = n.id end end
      if not node then return false, "talent:unknown" end
    end
    ok, why = Save.learnTalent(db, cid, node, choice)
  end
  if not ok then return false, "talent:" .. tostring(why) end
  notify("step")
  return true
end

function C.choose(id)
  local verb, arg = parse(id)
  if verb == "ui" then return navigate(arg) end
  if verb == "talent" or verb == "tspec" or verb == "treset" then return talentAct(verb, arg) end
  local exp = C.exp()
  -- écran de progression pendant une expédition : classe et onglet seulement (lecture seule)
  local browsing = exp and C.ui.view == "progress" and (verb == "pclass" or verb == "ptab")
  if not exp or browsing then
    if verb == "class" and ns.Classes[arg] and not exp then
      C.ui.class, C.ui.key = arg, nil
    elseif verb == "pclass" and ns.Classes[arg] then
      C.ui.progressClass = arg
    elseif verb == "ptab" and (arg == "zones" or arg == "cards" or arg == "talents") then
      C.ui.progressTab = arg
    elseif verb == "key" and type(arg) == "number" then
      C.ui.key = arg
    elseif verb == "go" then
      local st = C.startInfo()
      return C.start(st.class, st.key)
    else
      return false, "action"
    end
    notify("step")
    return true
  end
  if C.ended or exp.phase == "combat" then return false, "combat" end
  local ok, why = C.act({ verb, arg })
  if ok then C.ui.view = nil end
  notify("step")
  return ok, why
end

---------------------------------------------------------------------------
-- Potions et bibelots
---------------------------------------------------------------------------

-- Emplacements de potions affichés : ceux du combat s'il les gère, sinon ceux de l'expédition.
function C.potions()
  local exp = C.exp()
  if not exp then return nil end
  local c = exp.combat
  if c and c.player.potions then return c.player.potions end
  return exp.potions
end

function C.inCombat()
  local exp = C.exp()
  return exp ~= nil and exp.phase == "combat" and not C.ended
end

function C.discardPotion(slot)
  local exp = C.exp()
  if not exp then return false, "ended" end
  if exp.phase == "combat" then return false, "combat" end
  local ok, why = C.act({ "discardPotion", slot })
  notify("step")
  return ok, why
end

---------------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------------

function C.combat()
  if C.ended then return C.ended.c end
  local exp = C.exp()
  return exp and exp.combat
end

-- Résultat du combat affiché (« won » / « lost ») une fois tranché, nil sinon.
function C.over()
  return C.ended and C.ended.result or nil
end

local function combatAct(a)
  if not C.inCombat() then return false, "over" end
  local ok, why, evs = C.act(a)
  if ok then
    C.lastEvents = evs
    notify("combat", evs)
  end
  return ok, why
end

-- nospend : une carte « Spend N » se joue sans dépenser (Maj enfoncée en jouant).
function C.play(handIdx, targetIdx, nospend)
  return combatAct({ "play", handIdx, targetIdx, nospend and "nospend" or nil })
end

-- keep : uid de la carte gardée au choix en fin de tour (Traveler's Backpack) ; le choix est posé par
-- Combat.markRetain juste avant l'action (l'action « endTurn » de l'expédition ne porte pas d'argument).
function C.endTurn(keep)
  local c = C.combat()
  if keep and c and C.inCombat() and not Combat.markRetain(c, keep) then return false, "keep" end
  return combatAct({ "endTurn" })
end

function C.usePotion(slot, targetIdx)
  return combatAct({ "potion", slot, targetIdx })
end

-- Après le bandeau de fin de combat : passe à l'étape suivante (récompense, bilan).
function C.finishCombat()
  if not C.ended then return false end
  C.ended = nil
  notify("step")
  return true
end

function C.handInfo(i)
  local c = C.combat()
  local inst = c and c.hand[i]
  if not inst then return nil end
  local ok, why = Combat.canPlay(c, i)
  if ok and C.over() then ok, why = false, "over" end
  local d = Card.def(inst)
  local shift = IsShiftKeyDown and IsShiftKeyDown() and true or false
  -- « Spend N: » éteinte quand le bonus ne sera pas payé : ressource insuffisante, condition propre de la
  -- carte (spendNeed, lue comme Combat.play) ou Maj enfoncée
  local spendOff = d.spend ~= nil and (Combat.cardRes(c, d) < d.spend or shift
    or (d.spendNeed ~= nil and not d.spendNeed(c, inst)))
  -- carte Cast qui partira tout de suite (état Instant ou crochet instantCast ; question sans rien consommer)
  local instant = d.cast and not d.trap and Combat.isInstant(c, d, inst, false) or false
  return { inst = inst, def = d, cost = Combat.cost(c, inst), playable = ok, why = why,
    needsTarget = Combat.needsTarget(inst, c), spendOff = spendOff or nil, instant = instant or nil }
end

-- Carte gardée au choix en fin de tour (Traveler's Backpack) : index des cartes proposées (vide sans le
-- bibelot ou sans carte à garder). Lecture du moteur.
function C.retainCandidates()
  local c = C.combat()
  if not c or C.over() or c.phase ~= "player" then return {} end
  return Combat.retainCandidates(c)
end

function C.aliveTargets()
  local c = C.combat()
  local list = {}
  if not c then return list end
  for i = 1, #c.enemies do
    if not c.enemies[i].dead then list[#list + 1] = i end
  end
  return list
end

-- Mana maximal du tour (affichage « 2/3 » de l'orbe) : lecture du moteur, aucune règle ici.
function C.maxMana()
  local c = C.combat()
  if not c then return 0 end
  local ok, v = pcall(Combat.modify, c, "maxMana", Combat.BASE_MANA)
  return ok and v or (Combat.BASE_MANA or 3)
end

-- Décor de l'étape en cours (clé de UI/Art.lua : Art.scenes) : boss -> mine, feu de camp -> night,
-- rencontre -> champ `scene` facultatif de la rencontre (piste F), sinon route. Une zone peut remplacer un
-- décor par le sien (champ scenes de ns.Zones[id], docs/zones.md).
local baseScene

-- Décor de la zone de l'expédition pour le décor commun s (road, night, shop…), sinon s lui-même.
function C.zoneScene(s)
  local exp = C.exp()
  local z = exp and ns.Zones[exp.zone or ""]
  return z and z.scenes and z.scenes[s] or s
end

function C.scene()
  return C.zoneScene(baseScene(C.exp()))
end

baseScene = function(exp)
  if not exp then return "road" end
  local f = (C.ended and C.ended.kind) or (exp.fight and exp.fight.kind) or C.lastFightKind
  if exp.phase == "campfire" then return "night" end
  if exp.phase == "merchant" then return "shop" end
  local ev = exp.event and exp.event.id and ns.Events[exp.event.id]
  if (exp.phase == "event" or exp.phase == "select") and ev then return ev.scene or "road" end
  if (exp.phase == "combat" or exp.phase == "reward" or C.ended) and f == "boss" then return "mine" end
  if exp.phase == "reward" and exp.reward and exp.reward.kind == "event" and ev then return ev.scene or "road" end
  return "road"
end

-- Résumé pour le bandeau (PV, or, deck, bibelots, clé).
function C.runInfo()
  local exp = C.exp()
  if not exp then
    local e = C.ending and C.ending.entry
    if not e then return nil end
    return { hp = e.hp or 0, maxHp = e.maxHp or 0, gold = e.gold or 0, deck = e.deck or {},
      floor = e.floor, relics = e.relics or {}, key = e.key or 0, affixes = Meta.affixesFor(e.key or 0) }
  end
  local c = exp.combat or (C.ended and C.ended.c)
  local hp, maxHp = exp.hp, exp.maxHp
  if exp.combat then hp, maxHp = max(0, c.player.hp), c.player.maxHp end
  -- act : zone en cours et sa place dans la campagne (« Duskwood · 2/7 »)
  return { hp = hp, maxHp = maxHp, gold = exp.gold, deck = X.shownDeck(exp), floor = exp.floor,
    floors = exp.map and exp.map.floors, relics = exp.relics, key = exp.key or 0,
    affixes = exp.affixes or {}, act = X.campaignName(exp) }
end

-- Copie de l'expédition (comparaisons du harnais).
function C.snapshot()
  local exp = C.exp()
  return exp and U.copy(exp)
end

---------------------------------------------------------------------------
-- Étapes génériques pour les écrans
--   step = { kind, title, text, options = { { id, label, text, card = {id, up}, item = {kind, id},
--            price, disabled, reason, preview, sold, selected, group } }, ... }
---------------------------------------------------------------------------

local function key(a)
  if a[2] == nil then return a[1] end
  return a[1] .. ":" .. tostring(a[2])
end

-- Ensemble des actions possibles maintenant (clés « verbe:argument »).
local function available(exp)
  local set = {}
  local ch = X.choices(exp)
  for i = 1, #ch do set[key(ch[i])] = true end
  return set
end

-- Option d'action : grisée si l'action n'est pas proposée, avec la raison du moteur.
local function actionOption(avail, o)
  if o.disabled == nil and not avail[o.id] then
    o.disabled = true
    if not o.reason then o.reason = C.reasonFor({ parse(o.id) }) or "Unavailable." end
  end
  return o
end

local function relicName(id)
  local r = ns.Relics[id]
  return r and r.name or tostring(id)
end

local function potionName(id)
  local p = ns.Potions[id]
  return p and p.name or tostring(id)
end

local function cardName(id)
  local d = ns.Cards[id]
  return d and d.name or tostring(id)
end

local function affixLine(affixes, key_)
  if not affixes or #affixes == 0 then return nil end
  local names = {}
  for i = 1, #affixes do
    local a = ns.Affixes[affixes[i]]
    names[i] = a and a.name or affixes[i]
  end
  return "Key +" .. key_ .. ": " .. table.concat(names, ", ") .. "."
end
C.affixLine = affixLine

-- Barre d'expérience d'une classe (W.repBar) : { label, points, level, levelName = « Level N », cur, size }.
local function levelBar(cid)
  local cs = ns.Persist.db.meta.classes[cid]
  local lv, cur, size = Meta.xpProgress(cs and cs.xp or 0)
  return { label = ns.Classes[cid] and ns.Classes[cid].name or cid, points = cs and cs.xp or 0, level = lv,
    levelName = "Level " .. lv, cur = cur, size = size }
end
C.levelBar = levelBar

-- Classes jouables (playable ~= false), dans l'ordre de leur définition (order), puis par id.
local function sortedClasses()
  local list = {}
  for id, cd in pairs(ns.Classes) do
    if cd.playable ~= false then list[#list + 1] = id end
  end
  table.sort(list, function(a, b)
    local oa, ob = ns.Classes[a].order or 99, ns.Classes[b].order or 99
    if oa ~= ob then return oa < ob end
    return a < b
  end)
  return list
end
C.sortedClasses = sortedClasses

local function className(cid)
  local cd = ns.Classes[cid]
  return cd and cd.name or tostring(cid)
end

local RESULT = { won = "victory", lost = "defeat", abandoned = "abandoned", abandon = "abandoned" }

-- « Duskwood (2/7) » : zone et sa place dans la campagne.
local function zonePos(zid)
  return ns.Zone.name(zid) .. " (" .. (ns.Zone.order(zid) or "?") .. "/" .. ns.Zone.count() .. ")"
end

-- Ligne du journal : date, classe et clé, résultat, zone atteinte (et étape), boss battus, expérience.
-- Les entrées d'avant la campagne continue (sans beaten) gardent leur zone seule.
local function journalLine(e)
  local parts = {}
  if e.date then parts[#parts + 1] = tostring(e.date) end
  local cls = e.class and ns.Classes[e.class]
  parts[#parts + 1] = (cls and cls.name or "?") .. (e.key and (" +" .. e.key) or "")
  parts[#parts + 1] = RESULT[e.result] or tostring(e.result)
  local where = e.zone and ns.Zones[e.zone] and (e.beaten and zonePos(e.zone) or ns.Zones[e.zone].name)
  local stage = (e.floor or 0) > 0 and ("stage " .. e.floor) or nil
  if where then parts[#parts + 1] = where .. (stage and (" " .. stage) or "")
  elseif stage then parts[#parts + 1] = stage end
  if e.beaten then parts[#parts + 1] = #e.beaten .. (#e.beaten == 1 and " boss" or " bosses") end
  if e.xp then parts[#parts + 1] = "+" .. e.xp .. " experience" end
  return table.concat(parts, " · "), e.result == "won"
end

-- Classe et clé choisies sur l'écran d'accueil (toute expédition part de Westfall). Clé par défaut : la plus
-- haute ouverte pour cette classe.
function C.startInfo()
  local db = ns.Persist.db
  local classes = sortedClasses()
  local class = (C.ui.class and ns.Classes[C.ui.class]) and C.ui.class or classes[1]
  local keyMax = Meta.keyMax(db.meta, class)
  local k = C.ui.key
  if not k or k > keyMax or k < 0 then k = keyMax end
  return { class = class, zone = ns.Zone.FIRST, key = k, keyMax = keyMax, classes = classes }
end

-- État d'une zone de la campagne pour une classe, prêt à afficher : { status = "won" (boss battu par la classe) |
-- "reached" (atteinte) | "ahead" (pas encore atteinte) | "later" (pas de données), label, text (infobulle) }.
local ZONE_STATUS = { won = "Beaten", reached = "Reached", ahead = "Not reached", later = "Coming later" }
function C.zoneStatus(class, zone)
  local m = ns.Persist.db.meta
  local st
  if not ns.Zone.playable(zone) then st = "later"
  elseif Meta.classWon(m, class, zone) then st = "won"
  elseif Meta.zoneReached(m, class, zone) then st = "reached"
  else st = "ahead" end
  local cname = className(class)
  local text
  if st == "won" then
    local best = Meta.bestKey(m, class, zone)
    text = "Boss defeated by the " .. cname .. (best > 0 and (", best key +" .. best) or "") .. "."
  elseif st == "reached" then
    text = "Reached by the " .. cname .. ", boss not yet defeated."
  elseif st == "ahead" then
    text = "Not yet reached by the " .. cname .. "."
  else
    text = "Coming later."
  end
  return { status = st, label = ZONE_STATUS[st], text = text }
end

local function startStep()
  local db = ns.Persist.db
  local st = C.startInfo()
  local text = ""
  local last = db.journal[#db.journal]
  if last then text = "Last expedition: " .. (journalLine(last)) .. "." end
  if C.restoreNote then
    text = text .. "\n|cffff6060The saved expedition was unreadable (" .. C.restoreNote
      .. "): it has been set aside.|r"
  end
  if ns.Persist.readOnly then
    text = text .. "\n|cffff6060Save from a newer version of the addon: nothing will be saved.|r"
  end
  local opts = {}
  for _, cid in ipairs(st.classes) do
    local cd = ns.Classes[cid]
    opts[#opts + 1] = { id = "class:" .. cid, group = "class", label = cd.name or cid,
      text = (cd.hp or "?") .. " HP, " .. #(cd.deck or {}) .. " cards", level = Meta.levelOf(db.meta, cid),
      selected = cid == st.class }
  end
  -- la campagne, dans l'ordre (affichée, pas choisie : toute expédition part de Westfall et traverse les sept
  -- zones) : boss battu par la classe, zone atteinte, pas encore atteinte ; la plus loin atteinte est marquée
  local far = Meta.farthest(db.meta, st.class)
  for _, zid in ipairs(ns.Zone.ORDER) do
    local zs = C.zoneStatus(st.class, zid)
    opts[#opts + 1] = { id = "zone:" .. zid, group = "zone", info = true, label = ns.Zone.name(zid),
      status = zs.status, statusLabel = zs.label, text = zs.text, farthest = ns.Zone.order(zid) == far or nil }
  end
  local lastName = ns.Zone.name(ns.Zone.ORDER[#ns.Zone.ORDER])
  local boss = "Nefarian" -- boss de la dernière zone (phase 2 de Lord Victor Nefarius)
  for k = 0, Meta.MAX_KEY do
    local o = { id = "key:" .. k, group = "key", label = "+" .. k, selected = k == st.key,
      text = affixLine(Meta.affixesFor(k), k) or "No affix." }
    if k > st.keyMax then
      o.disabled = true
      o.reason = "Defeat " .. boss .. " at +" .. st.keyMax .. " to unlock key +" .. (st.keyMax + 1) .. "."
    end
    opts[#opts + 1] = o
  end
  opts[#opts + 1] = { id = "go", label = "Start expedition", text = ns.Zone.name(st.zone) }
  -- points de talent à dépenser par la classe choisie : pastille sur « Progress » (onglet Talents)
  local left = C.talentPointsLeft(st.class)
  opts[#opts + 1] = { id = "ui:progress", label = "Progress", badge = left > 0 and left or nil,
    badgeText = left > 0 and (C.talentPointsText(left) .. " to spend (" .. className(st.class) .. ").") or nil }
  -- premier accueil après la migration v8 (25 niveaux, arbres de talents) : les points sont à dépenser
  if ns.Persist.talentNotice and left > 0 then
    text = "|cffffd700You have " .. C.talentPointsText(left) .. " to spend.|r" .. (text ~= "" and ("\n" .. text) or "")
  end
  local beaten = Meta.beatenCount(db.meta, st.class)
  local campaign = far > 0 and ("Farthest: " .. zonePos(ns.Zone.ORDER[far]) .. " · bosses defeated: " .. beaten
    .. " of " .. ns.Zone.count()) or ("From " .. ns.Zone.name(ns.Zone.FIRST) .. " to " .. lastName .. ".")
  return { kind = "start", title = "Slay the Dragon", text = text, options = opts, campaign = campaign,
    class = st.class, zone = st.zone, key = st.key, keyMax = st.keyMax, affixes = Meta.affixesFor(st.key) }
end

-- Classe affichée par l'écran de progression : choisie par ses onglets, sinon celle de l'expédition qui
-- vient de finir (bilan), sinon celle de l'accueil.
local function progressClass()
  local cid = C.ui.progressClass
  if cid and ns.Classes[cid] then return cid end
  local exp = C.exp()
  if exp and ns.Classes[exp.class] then return exp.class end -- pendant une expédition : sa classe
  local e = C.ending and C.ending.entry
  if e and e.class and ns.Classes[e.class] then return e.class end
  return C.startInfo().class
end
C.progressClass = progressClass

-- Zones d'une classe pour l'écran de progression, dans l'ordre : { id, name, status, statusLabel, won,
-- bestKey (meilleure clé où la classe a battu le boss de la zone), card = emplacement de la carte de zone, keys = { emplacements des bibelots de clé
-- (+1, +3, +5) } }. Emplacement : { id (si débloqué), unlocked, condition (verrouillé), level (clé) } ;
-- sans donnée encore écrite, l'emplacement est montré verrouillé avec sa condition.
local function zoneRows(cid)
  local m = ns.Persist.db.meta
  local rows = {}
  for _, zid in ipairs(ns.Zone.ORDER) do
    local zs = C.zoneStatus(cid, zid)
    local zname = ns.Zone.name(zid)
    local won = Meta.classWon(m, cid, zid)
    local best = Meta.bestKey(m, cid, zid)
    local cards = Meta.zoneCards(cid, zid)
    local card = { unlocked = false, condition = "Win " .. zname .. " to unlock", epic = true }
    if cards[1] then
      card.cardId = cards[1]
      if won then card.unlocked, card.id, card.condition = true, cards[1], nil end
    end
    local byLevel = {}
    for _, e in ipairs(Meta.keyRelics(cid, zid)) do byLevel[e.level] = byLevel[e.level] or e.id end
    local keys = {}
    for i, lv in ipairs(Meta.KEY_RELIC_LEVELS) do
      local id = byLevel[lv]
      local open = id ~= nil and best >= lv
      keys[i] = { level = lv, id = open and id or nil, unlocked = open,
        condition = not open and ("Win " .. zname .. " +" .. lv .. " to unlock") or nil }
    end
    rows[#rows + 1] = { id = zid, name = zname, status = zs.status, statusLabel = zs.label, won = won,
      bestKey = best, card = card, keys = keys }
  end
  return rows
end
C.zoneRows = zoneRows

-- Écran de progression d'une classe, deux onglets. Cartes : niveau et barre d'expérience, cartes rangées
-- par voie (départ puis les trois voies, dans l'ordre des niveaux), bibelots de classe. Zones : les sept
-- zones (gagnée, clé max, carte de zone, bibelots de clé). Verrouillé : seulement la condition
-- (« Priest level 4 », « Win Westfall to unlock »), ni nom ni texte ni icône.
-- Onglet Talents (docs/talents.md, § 11 ; lecture : ns.Talent.view, § 17.7) : { class, className, points, spent,
-- left, total, running, empty (classe sans arbre), summary (ligne des points), note (ligne d'état : expédition en
-- cours, arbre absent, aucun point encore), rows = { { row, need, open, lock (condition d'une rangée fermée),
-- nodes = { { id (option talent:<nœud>), node, name, icon, ranks, rank, text, nextText, canLearn, disabled,
-- reason, choices = { { id (option tspec:<voie>), choice, name, icon, text, active, disabled, reason } } } } } },
-- reset = { id = "treset", label, disabled, reason } }.
local function talentTab(cid, running)
  local T = ns.Talent
  local m = ns.Persist.db.meta
  local v = T.view(m, cid, running)
  local tree = T.tree(cid)
  local cname = className(cid)
  local R = C.TALENT_REASONS
  local t = { class = cid, className = cname, points = v.points, spent = v.spent, left = v.left, total = T.POINTS,
    running = running or nil, empty = (not tree) or nil, rows = {} }
  t.summary = C.talentPointsText(max(0, v.left)) .. " to spend · " .. v.spent .. " of " .. T.POINTS .. " spent"
  if running then t.note = C.TALENT_RUNNING_LINE
  elseif not tree then t.note = "No talent tree for the " .. cname .. " yet."
  elseif v.points <= 0 then t.note = "Each level from level 2 gives one talent point." end
  local function why(w, need)
    if w == "row" then return C.talentRowText(need) end
    return R[w] or C.reasonText(w)
  end
  for r, row in ipairs(v.rows) do
    local tr = { row = r, need = row.need, open = row.open, lock = (not row.open) and C.talentRowText(row.need) or nil,
      nodes = {} }
    for _, e in ipairs(row.nodes) do
      local o = { id = "talent:" .. e.id, node = e.id, name = e.name, icon = e.icon, ranks = e.ranks, rank = e.rank,
        text = e.text, nextText = e.nextText, canLearn = e.canLearn, disabled = not e.canLearn or nil }
      -- rangée fermée : sa condition d'abord (plus utile que « aucun point »)
      if not e.canLearn then o.reason = why((not row.open and not running) and "row" or e.why, row.need) end
      if e.choices then
        o.choices = {}
        for _, ch in ipairs(e.choices) do
          local co = { id = "tspec:" .. ch.id, choice = ch.id, name = ch.name, icon = ch.icon, text = ch.text,
            active = ch.active or nil }
          if running then co.disabled, co.reason = true, R.running
          elseif e.rank > 0 then
            if ch.active then co.disabled, co.reason = true, R.choice end -- changer de voie : gratuit
          elseif not e.canLearn then co.disabled, co.reason = true, o.reason end
          o.choices[#o.choices + 1] = co
        end
      end
      tr.nodes[#tr.nodes + 1] = o
    end
    t.rows[r] = tr
  end
  t.reset = { id = "treset", label = "Reset talents" }
  if running then t.reset.disabled, t.reset.reason = true, R.running
  elseif v.spent <= 0 then t.reset.disabled, t.reset.reason = true, R.spent end
  return t
end
C.talentTab = talentTab

-- Points de talent à dépenser par la classe (0 sans arbre : rien à dépenser).
function C.talentPointsLeft(cid)
  if not ns.Talent.tree(cid) then return 0 end
  return max(0, Meta.pointsLeft(ns.Persist.db.meta, cid))
end

local function progressStep()
  local db = ns.Persist.db
  local cid = progressClass()
  local cd = ns.Classes[cid]
  local level = Meta.levelOf(db.meta, cid)
  local tier = Meta.contentTier(level)
  local tab = C.ui.progressTab
  if tab ~= "zones" and tab ~= "talents" then tab = "cards" end
  local running = db.current ~= nil
  -- palier de contenu de la carte (champ level, 1 à 7), ouvert au niveau de classe Meta.CONTENT_LEVELS[palier]
  local function entry(id, def)
    local lv = Meta.unlockLevel(def)
    local open = lv <= tier
    local need = Meta.CONTENT_LEVELS[lv] or lv
    return { id = open and id or nil, level = need, unlocked = open,
      condition = not open and ((cd.name or cid) .. " level " .. need) or nil }
  end
  local content = Meta.classContent(cid)
  local rows = { { id = "start", name = "Start", cards = {} } }
  local byPath = { start = rows[1] }
  for _, p in ipairs(cd.paths or {}) do
    rows[#rows + 1] = { id = p.id, name = p.name, cards = {} }
    byPath[p.id] = rows[#rows]
  end
  for _, id in ipairs(content.cards) do
    local d = ns.Cards[id]
    local row = byPath[d.path] or rows[1]
    row.cards[#row.cards + 1] = entry(id, d)
  end
  local relics = {}
  for _, id in ipairs(content.relics) do relics[#relics + 1] = entry(id, ns.Relics[id]) end
  local opts = {}
  for _, c in ipairs(sortedClasses()) do
    opts[#opts + 1] = { id = "pclass:" .. c, group = "class", label = ns.Classes[c].name or c,
      level = Meta.levelOf(db.meta, c), selected = c == cid }
  end
  -- onglets : les trois vues, l'affichée au liseré d'or ; Talents : pastille des points à dépenser
  local left = running and 0 or C.talentPointsLeft(cid)
  opts[#opts + 1] = { id = "ptab:cards", label = "Cards", group = "tab", selected = tab == "cards" }
  opts[#opts + 1] = { id = "ptab:zones", label = "Zones", group = "tab", selected = tab == "zones" }
  opts[#opts + 1] = { id = "ptab:talents", label = "Talents", group = "tab", selected = tab == "talents",
    badge = left > 0 and left or nil,
    badgeText = left > 0 and (C.talentPointsText(left) .. " to spend (" .. className(cid) .. ").") or nil }
  -- journal : hors expédition (son retour mène à l'écran de progression de l'accueil)
  if not running then opts[#opts + 1] = { id = "ui:meta", label = "Log" } end
  opts[#opts + 1] = { id = "ui:back", label = "Back" }
  return { kind = "classProgress", title = cd.name or cid, class = cid, level = level, bar = levelBar(cid),
    tab = tab, rows = rows, relics = relics, zones = zoneRows(cid), options = opts,
    talents = tab == "talents" and talentTab(cid, running) or nil, running = running or nil }
end

local function metaStep()
  local db = ns.Persist.db
  local m = db.meta
  local bars, lines = {}, {}
  -- une barre de classe (niveau) : celle de l'écran de progression ; puis le journal
  for _, cid in ipairs({ progressClass() }) do
    local cs = m.classes[cid]
    local b = levelBar(cid)
    local won = Meta.beatenCount(m, cid)
    local far = Meta.farthest(m, cid)
    b.detail = "Bosses defeated: " .. won .. " of " .. ns.Zone.count()
      .. (far > 0 and (" · farthest: " .. ns.Zone.name(ns.Zone.ORDER[far])) or "")
      .. ((cs and cs.runs) and (" · " .. cs.runs .. " expedition(s), " .. (cs.wins or 0) .. " victory(ies)") or "")
    -- même titre que l'accueil et l'écran Progress (« Dragonslayer » : Nefarian ; « Veteran » : niveau 7)
    local BR = ns.Blackrock
    local title = (BR and BR.title or Meta.title)(m, cid)
    if title then b.detail = b.detail .. " · title: " .. title end
    bars[#bars + 1] = b
  end
  local j = db.journal
  for i = #j, max(1, #j - 7), -1 do
    local line, won = journalLine(j[i])
    lines[#lines + 1] = { text = line, won = won }
  end
  return { kind = "meta", title = "Expedition log",
    text = (#j == 0 and "No expedition finished yet." or "Last expeditions:")
      .. "\n" .. (m.runs or 0) .. " expedition(s) in total.",
    bars = bars, journal = lines, options = { { id = "ui:progress", label = "Back" } } }
end

-- Déblocages montrés par la vitrine (UI/Screens.lua, Shelf : écran entre deux zones, bilan) : un groupe par
-- destinataire, { label, cards = {ids} (épiques d'abord), relics = {ids}, potions = {ids}, notes = {textes} } ;
-- ce qui n'est ni carte ni objet (rencontres, avantages du compte) en notes courtes.
local PERK_TEXT = { startRelic = "Choose a relic at the start of each expedition.",
  merchantRelic = "One more relic at the merchant." }

local function epicsFirst(ids)
  local out = {}
  for _, id in ipairs(ids) do
    if ns.Cards[id] and ns.Cards[id].rarity == "epic" then out[#out + 1] = id end
  end
  for _, id in ipairs(ids) do
    if not (ns.Cards[id] and ns.Cards[id].rarity == "epic") then out[#out + 1] = id end
  end
  return out
end

-- Groupe de la classe (cartes, bibelots) ; nil s'il est vide.
local function classGroup(cname, cards, relics)
  if #cards + #relics == 0 then return nil end
  return { label = cname, cards = epicsFirst(cards), relics = relics, potions = {}, notes = {} }
end

-- Groupe du compte (« All classes ») : contenu commun d'une ou plusieurs zones (Meta.commonContent) ; nil s'il
-- est vide.
local function commonGroup(list)
  local g = { label = "All classes", cards = {}, relics = {}, potions = {}, notes = {} }
  local events, perks = 0, {}
  for _, c in ipairs(list) do
    for _, id in ipairs(c.cards or {}) do g.cards[#g.cards + 1] = id end
    for _, id in ipairs(c.relics or {}) do g.relics[#g.relics + 1] = id end
    for _, id in ipairs(c.potions or {}) do g.potions[#g.potions + 1] = id end
    events = events + #(c.events or {})
    for _, k in ipairs(c.perks or {}) do perks[#perks + 1] = k end
  end
  if events > 0 then
    g.notes[#g.notes + 1] = events .. (events == 1 and " new encounter." or " new encounters.")
  end
  for _, k in ipairs(perks) do g.notes[#g.notes + 1] = PERK_TEXT[k] end
  if #g.cards + #g.relics + #g.potions + #g.notes == 0 then return nil end
  return g
end

local function unlockGroups(class, common)
  local groups = {}
  if class then groups[#groups + 1] = class end
  if common then groups[#groups + 1] = common end
  return #groups > 0 and groups or nil
end

local function endStep()
  local s, e = C.ending.summary, C.ending.entry
  local won = e.result == "won"
  local title = won and "Expedition complete!" or e.result == "lost" and "Expedition over"
    or "Expedition abandoned"
  -- zone atteinte (où l'expédition s'est arrêtée) et boss battus en chemin
  local zid = s.zone or e.zone or ns.Zone.FIRST
  local zname = ns.Zone.name(zid)
  local cname = className(e.class)
  local beaten = s.beaten or e.beaten or {}
  local lines = {}
  if won then
    lines[#lines + 1] = "Nefarian has fallen: the " .. ns.Zone.count() .. " zones are crossed. Expedition ended with "
      .. e.hp .. " HP and " .. #e.deck .. " cards."
  elseif e.result == "lost" then
    local names = {}
    for id in tostring(e.killedBy or ""):gmatch("[^+]+") do
      names[#names + 1] = ns.Enemies[id] and ns.Enemies[id].name or id
    end
    lines[#lines + 1] = "Fell in " .. zonePos(zid) .. " at stage " .. (e.floor or "?")
      .. (#names > 0 and (" against " .. table.concat(names, ", ")) or "") .. "."
  elseif (e.floor or 0) == 0 then
    -- abandon avant la première étape d'une zone (écran entre deux zones, carte)
    lines[#lines + 1] = "Turned back at the gates of " .. zonePos(zid) .. "."
  else
    lines[#lines + 1] = "Turned back in " .. zonePos(zid) .. " at stage " .. e.floor .. "."
  end
  if not won then
    if #beaten > 0 then
      local names = {}
      for i, z in ipairs(beaten) do names[i] = ns.Zone.name(z) end
      lines[#lines + 1] = "Zones beaten: " .. table.concat(names, ", ") .. " (" .. #beaten .. " of "
        .. ns.Zone.count() .. ")."
    else
      lines[#lines + 1] = "No zone beaten."
    end
  end
  lines[#lines + 1] = (e.cleared or 0) .. " stage(s) cleared, " .. (e.elites or 0) .. " elite(s), "
    .. (e.bosses or 0) .. " boss(es)."
  lines[#lines + 1] = "|cffffd700+" .. (s.xp or 0) .. " " .. cname .. " experience.|r"
  local up = s.levelAfter and s.levelBefore and s.levelAfter > s.levelBefore
  if up then
    -- une ligne par niveau gagné, un point de talent chacun (docs/talents.md, § 11) ; au-delà de END_LEVEL_LINES
    -- niveaux d'un coup, une ligne pour tous (le panneau du bilan garde sa place pour la vitrine)
    local n = s.levelAfter - s.levelBefore
    local pts = s.pointsGained or n
    if n <= C.END_LEVEL_LINES then
      for lv = s.levelBefore + 1, s.levelAfter do
        lines[#lines + 1] = "|cff40ff40" .. cname .. " reaches level " .. lv .. "! +1 talent point.|r"
      end
    else
      lines[#lines + 1] = "|cff40ff40" .. cname .. " reaches level " .. s.levelAfter .. "! +" .. pts
        .. " talent points (levels " .. (s.levelBefore + 1) .. " to " .. s.levelAfter .. ").|r"
    end
  end
  -- déblocages de la campagne, acquis à chaque boss battu : premiers boss de la classe (épiques), bibelots de
  -- clé, commun du compte ; regroupés (une expédition peut en battre sept d'un coup) et montrés par la vitrine
  -- (unlocks, plus bas) ; en texte : les premiers boss de la classe, la clé suivante (Nefarian)
  local firsts, commons = {}, {}
  for _, p in ipairs(s.zones or {}) do
    if p.zoneWon then firsts[#firsts + 1] = ns.Zone.name(p.zone) end
    if p.accountZone and p.common then commons[#commons + 1] = p.common end
  end
  if #firsts > 0 then
    lines[#lines + 1] = "|cff40ff40First " .. (#firsts == 1 and "boss" or "bosses") .. " defeated with the " .. cname .. ": "
      .. table.concat(firsts, ", ") .. ".|r"
  end
  if s.keyUnlocked then
    lines[#lines + 1] = "|cff40c0ffMythic Keystone +" .. s.keyUnlocked .. " unlocked.|r"
  end
  -- fin de campagne (Blackrock, docs/zones/blackrock.md § 10) : titre de la classe, Rallying Cry du compte,
  -- d'après les drapeaux de compte posés par cette expédition (summary.flags)
  local newFlag = {}
  for _, name in ipairs(s.flags or {}) do newFlag[name] = true end
  if newFlag["dragonslayer:" .. tostring(e.class)] then
    lines[#lines + 1] = "|cffffd700The " .. cname .. " earns the title Dragonslayer.|r"
  end
  if newFlag.rallying_cry then
    local hp = ns.Blackrock and ns.Blackrock.RALLY_HP or 6
    lines[#lines + 1] = "|cff40c0ffRallying Cry of the Dragonslayer: the next expedition (any class) starts with +"
      .. hp .. " max HP.|r"
  end
  local bars = { levelBar(e.class) }
  -- ce que l'expédition vient de débloquer, montré tel quel (vitrine) : pour la classe, cartes de zone
  -- (épiques d'abord), cartes et bibelots de la montée de niveau, bibelots de clé ; pour toutes les classes,
  -- le commun des zones dont le compte bat le boss pour la première fois
  local cards, relics = {}, {}
  for _, id in ipairs(s.zoneCards or {}) do cards[#cards + 1] = id end
  if up and s.unlocked then
    for _, id in ipairs(s.unlocked.cards) do cards[#cards + 1] = id end
    for _, id in ipairs(s.unlocked.relics) do relics[#relics + 1] = id end
  end
  for _, id in ipairs(s.keyRelics or {}) do relics[#relics + 1] = id end
  local unlocks = unlockGroups(classGroup(cname, cards, relics), commonGroup(commons))
  local opts = { { id = "ui:new", label = "New expedition" }, { id = "ui:progress", label = "Progress" } }
  -- points de talent à dépenser (gagnés maintenant ou avant) : bouton vers l'onglet Talents
  local left = C.talentPointsLeft(e.class)
  if left > 0 then
    opts[#opts + 1] = { id = "ui:talents", label = "Spend talent points",
      badge = left, badgeText = C.talentPointsText(left) .. " to spend (" .. cname .. ")." }
  end
  return { kind = "end", won = won, result = e.result, title = title, text = table.concat(lines, "\n"),
    bars = bars, unlocks = unlocks, pointsGained = s.pointsGained, options = opts }
end

local function mapStep(exp)
  local map = exp.map
  local avail = available(exp)
  local visited = {}
  for _, id in ipairs(exp.path or {}) do visited[id] = true end
  local floors = map.floors or 8
  local nodes = {}
  for i, n in ipairs(map.nodes) do
    local id = "path:" .. n.id
    local state = "locked"
    if n.id == exp.node then state = "current"
    elseif visited[n.id] then state = "done"
    elseif avail[id] then state = "available" end
    local links = {}
    for j, nx in ipairs(n.next or {}) do links[j] = "path:" .. nx end
    nodes[i] = { id = id, kind = n.kind, label = Map.KINDS[n.kind] or n.kind, floor = n.floor,
      x = (n.floor - 0.5) / floors, y = n.x, links = links, state = state }
  end
  local opts = {}
  local nx = U.copyArr(X.nextNodes and X.nextNodes(exp) or Map.nextNodes(map, exp.node))
  table.sort(nx, function(a, b) return map.nodes[a].x < map.nodes[b].x end)
  for _, id in ipairs(nx) do
    opts[#opts + 1] = actionOption(avail, { id = "path:" .. id, label = Map.KINDS[map.nodes[id].kind] })
  end
  local text = "Choose the next stage."
  local al = affixLine(exp.affixes, exp.key)
  if al then text = text .. "\n" .. al end
  -- Nom du boss de la zone (si tous les groupes de boss ont le même chef).
  local bossName
  local act = X.zoneDef(exp)
  local groups = act and ns.Encounters[act.encounters] and ns.Encounters[act.encounters].boss
  if groups and groups[1] then
    local first = groups[1][1]
    local same = true
    for _, g in ipairs(groups) do if g[1] ~= first then same = false end end
    if same and ns.Enemies[first] then bossName = ns.Enemies[first].name end
  end
  return { kind = "map", title = X.campaignName(exp) .. " · stage " .. min(exp.floor + 1, floors) .. " of " .. floors,
    text = text, nodes = nodes, options = opts, affixes = exp.affixes, key = exp.key, bossName = bossName, zone = exp.zone,
    floor = exp.floor, floors = floors }
end

local eventResult -- défini plus bas (texte « après coup » d'une rencontre)

local REWARD_TITLE = { combat = "Victory!", elite = "Elite defeated!", boss = "Boss defeated!", chest = "Chest" }

local function rewardStep(exp)
  local r = exp.reward
  local avail = available(exp)
  local title = REWARD_TITLE[r.kind] or "Reward"
  local text
  local ev = exp.event and exp.event.id and ns.Events[exp.event.id]
  if r.kind == "event" and ev then
    title = ev.name
    text = eventResult(exp)
  elseif r.kind == "chest" then
    text = "You open the chest."
  else
    text = "The combat is won."
  end
  local loot = {}
  if r.goldGained and r.goldGained > 0 then
    loot[#loot + 1] = { kind = "gold", label = "+" .. r.goldGained .. "g", title = "Gold",
      text = "Added to your purse." }
  end
  if r.relic then
    local def = ns.Relics[r.relic]
    loot[#loot + 1] = { kind = "relic", id = r.relic, label = relicName(r.relic), title = relicName(r.relic),
      text = def and def.text }
  end
  if r.potion then
    local def = ns.Potions[r.potion]
    loot[#loot + 1] = { kind = "potion", id = r.potion, label = potionName(r.potion), title = potionName(r.potion),
      text = def and def.text, pending = not r.potionTaken }
  end
  local opts = {}
  local after = text -- texte « après coup » d'une rencontre, sans la consigne des cartes
  -- choix « Epic » (épique tombée sur un élite, Expedition.rollEpicDrop) : montré avant les cartes ordinaires
  local epicMode = r.epics ~= nil and not r.epicDone
  if epicMode then
    local full = X.epicIndex(exp) and X.epicFull(exp)
    text = text .. (text ~= "" and "\n" or "") .. (not full and "Epic card: take it, or skip."
      or X.epicMax() <= 1 and "Epic card: replace yours, or skip." or "Epic card: replace your oldest, or skip.")
    for i, id in ipairs(r.epics) do
      opts[#opts + 1] = actionOption(avail, { id = "pickEpic:" .. i, card = { id = id, up = false }, epic = true })
    end
    opts[#opts + 1] = actionOption(avail, { id = "skipEpic", label = "Skip", epic = true })
  elseif r.epicPicked then
    text = text .. (text ~= "" and "\n" or "") .. "Epic card added: " .. cardName(r.epicPicked) .. "."
  end
  if not r.cardsDone and not epicMode then
    text = text .. (text ~= "" and "\n" or "") .. "Choose a card to add to the deck."
    for i, id in ipairs(r.cards) do
      opts[#opts + 1] = actionOption(avail, { id = "pickCard:" .. i, card = shownCard(exp, id) })
    end
    opts[#opts + 1] = actionOption(avail, { id = "skipCards", label = "Skip the cards" })
  elseif r.picked then
    text = text .. (text ~= "" and "\n" or "") .. "Card added: " .. cardName(r.picked) .. "."
  end
  if r.potion and not r.potionTaken then
    text = text .. "\nPotion slots full: discard one (right-click) to take "
      .. potionName(r.potion) .. "."
    opts[#opts + 1] = actionOption(avail, { id = "takePotion", label = "Take the potion" })
  end
  opts[#opts + 1] = actionOption(avail, { id = "leave", label = "Continue" })
  return { kind = "reward", title = title, text = text, loot = loot, options = opts, rewardKind = r.kind,
    picked = r.picked, cardsDone = r.cardsDone, after = (r.kind == "event") and after or nil,
    epicMode = epicMode or nil }
end

local function campfireStep(exp)
  local avail = available(exp)
  local copy = U.copy(exp)
  X.act(copy, { "rest" })
  local heal = copy.lastRest or 0
  local canUp = false
  for k in pairs(avail) do if k:match("^upgrade:") then canUp = true end end
  local opts = {
    actionOption(avail, { id = "rest", label = "Rest", text = "Restores " .. heal .. " HP." }),
    { id = "ui:upgrade", label = "Meditate", text = "Upgrade a card in the deck.",
      disabled = not canUp, reason = not canUp and C.reasonText("upgrade") or nil },
    actionOption(avail, { id = "leave", label = "Move on", text = "Without stopping." }),
  }
  -- actions de feu de camp des zones (ns.ZoneRules[id].campfire) : options « campAction:<id> »
  for _, ca in ipairs(X.campActions and X.campActions(exp) or {}) do
    opts[#opts + 1] = actionOption(avail, { id = "campAction:" .. ca.id, label = ca.label, text = ca.text })
  end
  return { kind = "campfire", title = "Campfire",
    text = "You have " .. exp.hp .. " of " .. exp.maxHp .. " HP.", options = opts }
end

-- Options de cartes du deck : celle de l'épique en tête (stable pour les autres).
local function epicFirst(opts)
  for i = 1, #opts do
    local o = opts[i]
    if o.card and ns.Cards[o.card.id] and ns.Cards[o.card.id].rarity == "epic" then
      if i > 1 then table.insert(opts, 1, table.remove(opts, i)) end
      break
    end
  end
  return opts
end

-- Carte du deck sur un écran d'amélioration (feu de camp, rencontre « upgrade ») : améliorable, avec l'aperçu
-- de son palier suivant au survol ; sinon grisée avec sa raison (« Fully upgraded. » : dernier palier écrit
-- atteint, X.upgradeRefusal). card = carte montrée (X.shownDeck), i = sa place dans le deck.
local function upgradeOption(exp, avail, id, i, card)
  local o = { id = id, card = { id = card.id, up = card.up, from = card.from } }
  if avail[id] then
    o.preview = Card.canUp(card.id, card.up) or nil
  elseif not X.canUpgrade(exp, i) then
    o.disabled, o.reason = true, C.reasonText(X.upgradeRefusal(exp, i))
  end
  return actionOption(avail, o)
end

local function deckStep(exp, view)
  local avail = available(exp)
  local opts = {}
  local title
  local shown = X.shownDeck(exp)
  if view == "upgrade" then
    title = "Meditate: choose a card to upgrade"
    for i, card in ipairs(shown) do
      opts[#opts + 1] = upgradeOption(exp, avail, "upgrade:" .. i, i, card)
    end
  else
    title = "Remove a card from the deck (" .. X.removePrice(exp) .. "g)"
    for i, card in ipairs(shown) do
      opts[#opts + 1] = actionOption(avail, { id = "remove:" .. i, card = { id = card.id, up = card.up, from = card.from } })
    end
  end
  epicFirst(opts)
  opts[#opts + 1] = { id = "ui:back", label = "Back" }
  return { kind = "deck", title = title, text = "", options = opts }
end

local function merchantStep(exp)
  local s = exp.shop
  local avail = available(exp)
  local opts = {}
  local function item(verb, i, it, extra)
    local o = { id = verb .. ":" .. i, price = it.price, sold = it.sold }
    for k, v in pairs(extra) do o[k] = v end
    if it.sold then o.disabled, o.reason = true, "Sold." end
    opts[#opts + 1] = actionOption(avail, o)
  end
  for i, it in ipairs(s.cards) do
    -- carte vendue déjà améliorée (zones hautes, X.SHOP_UPGRADED) : affichée à son palier (variante : borné à ses
    -- paliers écrits)
    local card = shownCard(exp, it.id)
    if it.up then card.up = Card.upValue(math.min(Card.level(it.up), Card.tiers(card.id))) end
    item("buyCard", i, it, { card = card, epic = it.epic })
  end
  for i, it in ipairs(s.relics) do
    local def = ns.Relics[it.id]
    item("buyRelic", i, it, { item = { kind = "relic", id = it.id }, label = relicName(it.id), text = def and def.text })
  end
  for i, it in ipairs(s.potions) do
    local def = ns.Potions[it.id]
    item("buyPotion", i, it, { item = { kind = "potion", id = it.id }, label = potionName(it.id), text = def and def.text })
  end
  local canRemove = false
  for k in pairs(avail) do if k:match("^remove:") then canRemove = true end end
  opts[#opts + 1] = { id = "ui:remove", label = "Remove a card", service = true,
    text = "The goblin removes a card from the deck.", price = X.removePrice(exp),
    disabled = not canRemove, reason = not canRemove and (C.reasonFor({ "remove", 1 }) or "Unavailable.") or nil }
  opts[#opts + 1] = actionOption(avail, { id = "leave", label = "Leave", service = true })
  return { kind = "merchant", title = "Goblin Merchant", gold = exp.gold,
    text = "\"Nothing but bargains, friend!\" Purse: |cffffd700" .. exp.gold .. "g|r.", options = opts }
end

-- Texte « après coup » d'une rencontre : exp.event.result (issue d'un pari comprise), sinon after.
eventResult = function(exp)
  local ev = exp.event
  local def = ev and ev.id and ns.Events[ev.id]
  if not def or not ev.chosen then return "" end
  if ev.result and ev.result ~= "" then return ev.result end
  local ch = def.choices[ev.chosen]
  return ch and (ch.result or ch.after) or ""
end
C.eventResult = eventResult

local function eventStep(exp)
  local ev = exp.event
  local avail = available(exp)
  if not ev.id then
    return { kind = "event", title = "Encounter", text = "The road is quiet: nothing to report.",
      options = { actionOption(avail, { id = "leave", label = "Continue" }) } }
  end
  local def = ns.Events[ev.id]
  -- Champs facultatifs (piste F) : speaker, scene, npc, rarity ; réponses : outcome, hidden.
  local base = { kind = "event", title = def.name, speaker = def.speaker, scene = def.scene, npc = def.npc,
    rarity = def.rarity }
  if ev.chosen then
    base.text = eventResult(exp)
    base.after = true
    base.options = { actionOption(avail, { id = "leave", label = "Continue" }) }
    return base
  end
  local opts = {}
  if X.eventOptions then
    -- Toutes les réponses, y compris désactivées (grisées avec leur raison) ; « ? » si cachée.
    for _, o in ipairs(X.eventOptions(exp)) do
      local opt = { id = "choose:" .. o.index, label = o.label, text = o.outcome or "", hidden = o.hidden }
      if o.disabled then opt.disabled, opt.reason = true, o.reason or "Unavailable." end
      opts[#opts + 1] = actionOption(avail, opt)
    end
  else
    for i, ch in ipairs(def.choices) do
      local outcome = ch.outcome or ch.text
      if ch.hidden then outcome = "?" end
      opts[#opts + 1] = actionOption(avail, { id = "choose:" .. i, label = ch.label, text = outcome,
        hidden = ch.hidden })
    end
  end
  -- « %s » / « %g » : nom de l'ennemi ou du groupe tiré à l'entrée (X.eventText)
  base.text = X.eventText and X.eventText(exp) or def.text
  base.options = opts
  return base
end

local function selectStep(exp)
  local avail = available(exp)
  local sel = exp.select
  local ev = exp.event and exp.event.id and ns.Events[exp.event.id]
  local opts = {}
  for i, card in ipairs(X.shownDeck(exp)) do
    local id = "select:" .. i
    if sel.kind == "upgrade" then
      opts[#opts + 1] = upgradeOption(exp, avail, id, i, card)
    elseif avail[id] then
      opts[#opts + 1] = { id = id, card = { id = card.id, up = card.up, from = card.from } }
    end
  end
  opts[#opts + 1] = actionOption(avail, { id = "skipSelect", label = "Skip" })
  local what = sel.kind == "upgrade" and "choose a card to upgrade"
    or (sel.kind == "dupe" and "choose a card to copy" or "choose a card to remove")
  return { kind = "select", title = (ev and ev.name or "Encounter") .. ": " .. what,
    text = eventResult(exp), options = opts, selectKind = sel.kind }
end

local function startRelicStep(exp)
  local avail = available(exp)
  local opts = {}
  for i, id in ipairs(exp.startRelics) do
    local def = ns.Relics[id]
    opts[#opts + 1] = actionOption(avail, { id = "startRelic:" .. i, label = relicName(id), text = def and def.text,
      item = { kind = "relic", id = id } })
  end
  opts[#opts + 1] = actionOption(avail, { id = "skipStartRelic", label = "Leave without a relic" })
  return { kind = "startRelic", title = "Relic choice",
    text = "Choose a relic for this expedition.",
    options = opts }
end

-- Épiques au départ (talent Veteran's Arsenal, phase « start » avant le bibelot au choix) : les épiques
-- proposables de la classe (exp.talentEpics), une par choix restant (exp.talentEpicsLeft) ; grille du deck
-- (écran « deck ») avec « Skip ». Rang 2 : un deuxième choix, l'épique prise retirée de la liste.
local function talentEpicStep(exp)
  local avail = available(exp)
  local opts = {}
  for i, id in ipairs(exp.talentEpics) do
    opts[#opts + 1] = actionOption(avail, { id = "talentEpic:" .. i, card = { id = id, up = false }, epic = true })
  end
  opts[#opts + 1] = actionOption(avail, { id = "skipTalentEpic", label = "Skip" })
  local left = exp.talentEpicsLeft or 1
  local total = max(left, math.floor(X.modify(exp, "startEpics", 0)))
  local title = "Veteran's Arsenal: choose an epic card"
  if total > 1 then title = title .. " (" .. (total - left + 1) .. " of " .. total .. ")" end
  return { kind = "talentEpic", title = title, options = opts, left = left, total = total,
    text = "It joins the deck for this expedition. Its rule is in play from the start of each combat." }
end

-- Talents de l'expédition en cours (figés au départ, exp.talents), dans l'ordre de l'arbre, prêts à afficher :
-- { { id, name, icon, rank, ranks, spec, specName, text } } ; nil hors expédition ou sans talent.
function C.activeTalents()
  local exp = C.exp()
  if not exp or not exp.talents then return nil end
  local list = {}
  for _, e in ipairs(exp.talents) do
    local n = ns.Talent.node(exp.class, e.id)
    if n then
      local ch = n.choices and n.byChoice[e.spec or ""]
      list[#list + 1] = { id = e.id, name = n.name, icon = ch and ch.icon or n.icon, rank = e.rank, ranks = n.ranks,
        spec = e.spec, specName = ch and ch.name or nil, text = ns.Talent.rankText(exp.class, e.id, e.rank, e.spec) }
    end
  end
  return #list > 0 and list or nil
end

-- Entre deux zones (phase « transit ») : la zone suivante (nom, décor, place dans la campagne), le soin du
-- passage, ce que le boss vaincu vient de débloquer pour les expéditions suivantes ; « Continue » ou l'abandon.
local function transitStep(exp)
  local t = exp.transit or {}
  local avail = available(exp)
  local n, total = X.campaignPos(exp)
  local cname = className(exp.class)
  local lines = {}
  lines[#lines + 1] = ns.Zone.name(t.from) .. " is behind you. Zone " .. n .. " of " .. total .. "."
  lines[#lines + 1] = "|cff40ff40You recover " .. (t.healed or 0) .. " HP (" .. exp.hp .. "/" .. exp.maxHp .. ").|r"
  -- déblocages reportés au boss (Meta.bank) : ils servent aux prochaines expéditions ; montrés par la vitrine
  -- (unlocks) : épique et cartes de zone, bibelots de clé (la classe), commun de la zone (le compte)
  local part
  for _, p in ipairs(exp.banked and exp.banked.zones or {}) do
    if p.zone == t.from then part = p end
  end
  local unlocks
  if part then
    local cards, relics = {}, {}
    if part.zoneWon then cards = Meta.zoneCards(exp.class, part.zone) end
    for _, id in ipairs(part.keyRelics or {}) do relics[#relics + 1] = id end
    unlocks = unlockGroups(classGroup(cname, cards, relics),
      part.accountZone and commonGroup({ Meta.commonContent(ns.Zone.order(part.zone) or 0) }) or nil)
  end
  return { kind = "transit", title = X.actName(exp), text = table.concat(lines, "\n"), zone = exp.zone,
    from = t.from, healed = t.healed, pos = n, count = total, unlocks = unlocks,
    options = { actionOption(avail, { id = "continue", label = "Continue" }) } }
end

-- Étape courante.
function C.step()
  if C.ended then
    return { kind = "combat", title = C.ended.title or "Combat", options = {}, state = C.ended.c, over = C.ended.result }
  end
  local exp = C.exp()
  if not exp then
    if C.ui.view == "meta" then return metaStep() end
    if C.ui.view == "progress" then return progressStep() end
    if C.ending then return endStep() end
    return startStep()
  end
  local ph = exp.phase
  -- écran de progression consulté pendant l'expédition (hors combat) : arbre de talents en lecture seule
  if C.ui.view == "progress" and ph ~= "combat" and ph ~= "done" then return progressStep() end
  if ph == "combat" then
    return { kind = "combat", title = exp.fight and FIGHT_TITLE[exp.fight.kind] or "Combat", options = {},
      state = exp.combat }
  elseif ph == "map" then return mapStep(exp)
  elseif ph == "start" then
    if exp.talentEpics then return talentEpicStep(exp) end
    return startRelicStep(exp)
  elseif ph == "reward" then return rewardStep(exp)
  elseif ph == "campfire" then
    if C.ui.view == "upgrade" then return deckStep(exp, "upgrade") end
    return campfireStep(exp)
  elseif ph == "merchant" then
    if C.ui.view == "remove" then return deckStep(exp, "remove") end
    return merchantStep(exp)
  elseif ph == "event" then return eventStep(exp)
  elseif ph == "select" then return selectStep(exp)
  elseif ph == "transit" then return transitStep(exp)
  end
  -- « done » : déjà archivée par C.act ; filet de sécurité.
  C.finish()
  return C.ending and endStep() or startStep()
end

---------------------------------------------------------------------------
-- Combat de test (/slay dev fight, développement) : le prochain combat lancé dans l'expédition en cours oppose
-- les ennemis armés à la place du groupe tiré ; genre, récompense et suite inchangés. État armé non sauvegardé
-- (perdu au /reload) ; le combat de test, lui, est dans db.current comme tout combat. Branché sur la
-- notification onFightStart (X.fire, après les tirages et les règles de zone) : rien ne change sans armement.
-- Les fiches ne sont jamais modifiées : seuls opts.encounter et exp.fight.encounter du combat sont remplacés.
---------------------------------------------------------------------------

C.devFight = nil -- { exp = expédition visée, ids = { id, … } }

do
  local fire = X.fire
  X.fire = function(exp, name, a, b)
    local r = fire(exp, name, a, b)
    local d = C.devFight
    if name == "onFightStart" and d and d.exp == exp then
      C.devFight = nil
      b.encounter = U.copy(d.ids)
      a.encounter = U.copy(d.ids)
      a.test = true
    end
    return r
  end
end

-- Ennemis de la zone de l'expédition (groupes ns.Encounters, ordre des groupes) hors boss et serviteurs :
-- réguliers, élites.
local function zoneEnemies(exp)
  local pools = ns.Encounters[X.zoneDef(exp).encounters] or {}
  local keys = {}
  for k in pairs(pools) do keys[#keys + 1] = k end
  table.sort(keys)
  local seen, reg, eli = {}, {}, {}
  for _, k in ipairs(keys) do
    for _, g in ipairs(pools[k]) do
      for _, spec in ipairs(g) do
        local id = Combat.specId(spec)
        local def = ns.Enemies[id]
        if def and not seen[id] and not def.boss and not def.minion then
          seen[id] = true
          if def.elite then eli[#eli + 1] = id else reg[#reg + 1] = id end
        end
      end
    end
  end
  return reg, eli
end

-- Arme le combat de test : arg = "" | N | "off" | "id id …". Renvoie le message à afficher.
function C.armDevFight(arg)
  local exp = C.exp()
  if arg == "off" then
    C.devFight = nil
    return "dev fight: off."
  end
  if not exp or exp.phase == "done" then return "dev fight: no expedition running." end
  local reg, eli = zoneEnemies(exp)
  local ids = {}
  local n = tonumber(arg ~= "" and arg or "4")
  if n then
    n = max(1, min(Combat.MAX_ENEMIES, math.floor(n)))
    if n >= 3 and #eli > 0 then ids[1] = eli[1] end
    local i = 0
    while #ids < n and #reg > 0 do
      i = i + 1
      ids[#ids + 1] = reg[(i - 1) % #reg + 1]
    end
  else
    for id in arg:gmatch("%S+") do
      if not ns.Enemies[id] then
        local list = {}
        for _, v in ipairs(reg) do list[#list + 1] = v end
        for _, v in ipairs(eli) do list[#list + 1] = v end
        return "dev fight: unknown enemy '" .. id .. "'. Try: " .. table.concat(list, " ") .. "."
      end
      if #ids < Combat.MAX_ENEMIES then ids[#ids + 1] = id end
    end
  end
  if #ids == 0 then return "dev fight: no enemy to arm." end
  C.devFight = { exp = exp, ids = ids }
  return "dev fight armed (next fight): " .. table.concat(ids, ", ") .. "."
end
