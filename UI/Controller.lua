-- Contrôleur : couche mince entre les écrans et le moteur. Aucune règle de jeu ici :
-- les combats passent par ns.Combat, l'expédition par un « fournisseur »
-- (ns.DemoExpedition aujourd'hui, Core/Expedition.lua demain ; contrat décrit
-- en tête de UI/DemoExpedition.lua et dans docs/interface.md).
-- Lua 5.1 pur, sans API WoW (testé hors jeu par Sim/ui_harness.lua).
--
-- État vivant (copié tel quel dans SlayTheDragonDB.current après chaque action) :
--   live = { provider = id, seed = n, run = état du fournisseur,
--            combat = état ns.Combat | nil, over = nil | "won" | "lost" }
local _, ns = ...

local U, Combat, Card = ns.Util, ns.Combat, ns.Card
local max = math.max

local C = {}
ns.Controller = C

C.providers = { [ns.DemoExpedition.id] = ns.DemoExpedition }
C.provider = ns.DemoExpedition
C.live = nil
C.listeners = {}
C.lastEvents = {}

C.REASONS = {
  phase = "Ce n'est pas ton tour.",
  card = "Carte introuvable.",
  unplayable = "Cette carte ne se joue pas.",
  mana = "Pas assez de mana.",
  casting = "Une incantation est déjà en cours.",
  forbidden = "Interdit par un Pouvoir actif.",
  condition = "Condition non remplie.",
  target = "Choisis une cible valide.",
  over = "Le combat est terminé.",
}

function C.reasonText(why)
  return C.REASONS[why] or tostring(why)
end

function C.onChange(fn)
  C.listeners[#C.listeners + 1] = fn
end

local function notify(kind, data)
  for i = 1, #C.listeners do C.listeners[i](kind, data) end
end

function C.persist()
  ns.Persist.store(C.live)
end

---------------------------------------------------------------------------
-- Validation d'un état restauré (le contenu a pu changer entre deux versions)
---------------------------------------------------------------------------

local function validCard(inst)
  if type(inst) ~= "table" then return false end
  local def = ns.Cards[inst.id]
  if not def then return false end
  if inst.up and not def.up then return false end
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
  if type(c.cooldown) ~= "table" then return false, "cooldown" end
  for i = 1, #c.cooldown do
    if not validCard(c.cooldown[i].card) then return false, "cooldown" end
  end
  if c.player.cast and not validCard(c.player.cast.card) then return false, "cast" end
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    local def = ns.Enemies[e.id]
    if not def then return false, "ennemi inconnu " .. tostring(e.id) end
    if not e.dead and e.intent and not def.moves[e.intent] then return false, "intention" end
  end
  for i = 1, #(c.relics or {}) do
    if not ns.Relics[c.relics[i]] then return false, "bibelot inconnu" end
  end
  return true
end

function C.validate(live)
  if type(live) ~= "table" then return false, "structure" end
  local P = C.providers[live.provider]
  if not P then return false, "fournisseur " .. tostring(live.provider) end
  if P.validate then
    local ok, why = P.validate(live.run)
    if not ok then return false, why end
  end
  if live.combat then
    local ok, why = C.validateCombat(live.combat)
    if not ok then return false, why end
  end
  return true
end

---------------------------------------------------------------------------
-- Cycle de vie
---------------------------------------------------------------------------

-- Reprise depuis la sauvegarde. Un état devenu illisible est archivé, pas chargé.
function C.restore()
  C.live = nil
  local saved = ns.Persist.restore()
  if saved then
    local ok, why = C.validate(saved)
    if ok then
      C.provider = C.providers[saved.provider]
      if saved.combat then saved.combat.events = {} end
      C.live = saved
    else
      ns.Persist.archive({ result = "abandon", reason = "sauvegarde illisible : " .. tostring(why),
        seed = saved.seed })
      ns.Persist.store(nil)
    end
  end
  notify("restore")
  return C.live ~= nil
end

function C.makeSeed()
  local t = 0
  if type(time) == "function" then t = time() end
  local g = 0
  if type(GetTime) == "function" then g = math.floor(GetTime() * 1000) end
  return (t * 7 + g) % 2147483646 + 1
end

function C.newRun(seed, opts)
  seed = seed or C.makeSeed()
  C.provider = ns.DemoExpedition
  C.live = { provider = C.provider.id, seed = seed, run = C.provider.new(seed, opts or { class = "priest" }) }
  C.persist()
  notify("step")
end

function C.abandon()
  if not C.live then return end
  local entry = C.provider.summary(C.live.run)
  entry.result = "abandon"
  ns.Persist.archive(entry)
  C.live = nil
  C.persist()
  notify("step")
end

---------------------------------------------------------------------------
-- Étapes
---------------------------------------------------------------------------

local function startStep()
  local db = ns.Persist.db
  local last = db and db.journal[#db.journal]
  local text = "Un deckbuilder à jouer pendant tes vols. Une expédition : la Marche de l'Ouest, "
    .. "jusqu'à Edwin VanCleef."
  if last then
    local r = last.result == "won" and "victoire" or last.result == "lost" and "défaite" or "abandon"
    text = text .. "\n\nDernière expédition : " .. r .. (last.floor and (", étape " .. last.floor) or "") .. "."
  end
  return { kind = "start", title = "Slay the Dragon", text = text,
    options = { { id = "new", label = "Nouvelle expédition", text = "Prêtre, 65 PV, 10 cartes." } } }
end

-- Crée le combat décrit par l'étape, s'il n'existe pas déjà (reprise exacte sinon).
local function ensureCombat(step)
  if C.live.combat then return C.live.combat end
  local spec = step.combat
  local c = Combat.new({ seed = spec.seed, hp = spec.hp, maxHp = spec.maxHp, deck = spec.deck,
    encounter = spec.encounter, relics = spec.relics, quiet = false })
  C.live.combat = c
  C.live.over = c.result
  C.lastEvents = c.events
  c.events = {}
  C.persist()
  return c
end

-- Étape courante, sous forme générique (voir UI/DemoExpedition.lua).
function C.step()
  if not C.live then return startStep() end
  local step = C.provider.choices(C.live.run)
  if step.kind == "combat" then
    step.state = ensureCombat(step)
    step.over = C.live.over
  end
  return step
end

-- Choix d'une option de l'étape courante.
function C.choose(id, extra)
  if not C.live then
    if id == "new" then C.newRun() return true end
    return false, "start"
  end
  local step = C.provider.choices(C.live.run)
  if step.kind == "end" and id == "new" then
    ns.Persist.archive(C.provider.summary(C.live.run))
    C.newRun()
    return true
  end
  if step.kind == "combat" then return false, "combat" end
  local ok, why = C.provider.act(C.live.run, id, extra)
  C.persist()
  notify("step")
  return ok, why
end

---------------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------------

function C.combat()
  return C.live and C.live.combat
end

local function afterAction(c)
  local evs = c.events
  c.events = {}
  C.lastEvents = evs
  if c.result then C.live.over = c.result end
  C.persist()
  notify("combat", evs)
end

function C.play(handIdx, targetIdx)
  local c = C.combat()
  if not c then return false, "phase" end
  if C.live.over then return false, "over" end
  local ok, why = Combat.play(c, handIdx, targetIdx)
  if ok then afterAction(c) end
  return ok, why
end

function C.endTurn()
  local c = C.combat()
  if not c or C.live.over then return false end
  local ok = Combat.endTurn(c)
  if ok then afterAction(c) end
  return ok
end

-- Après l'écran de fin de combat : rend la main à l'expédition.
function C.finishCombat()
  local c = C.combat()
  if not c or not C.live.over then return false end
  local result = C.live.over
  local hp = max(0, c.player.hp)
  C.live.combat = nil
  C.live.over = nil
  C.provider.act(C.live.run, "combat:" .. result, { hp = hp })
  C.persist()
  notify("step")
  return true
end

-- Infos d'une carte en main pour l'affichage.
function C.handInfo(i)
  local c = C.combat()
  local inst = c and c.hand[i]
  if not inst then return nil end
  local ok, why = Combat.canPlay(c, i)
  if ok and C.live.over then ok, why = false, "over" end
  return { inst = inst, def = Card.def(inst), cost = Combat.cost(c, inst), playable = ok, why = why,
    needsTarget = Combat.needsTarget(inst) }
end

-- Index (1-based) des ennemis vivants, dans l'ordre d'affichage.
function C.aliveTargets()
  local c = C.combat()
  local list = {}
  if not c then return list end
  for i = 1, #c.enemies do
    if not c.enemies[i].dead then list[#list + 1] = i end
  end
  return list
end

-- Résumé de l'expédition pour le bandeau (PV, or, deck).
function C.runInfo()
  if not C.live then return nil end
  local r = C.live.run
  local c = C.live.combat
  return { hp = c and max(0, c.player.hp) or r.hp, maxHp = c and c.player.maxHp or r.maxHp,
    gold = r.gold or 0, deck = r.deck, floor = r.floor, steps = r.sequence and #r.sequence,
    relics = r.relics }
end

-- Copie d'un état de combat sans le journal (comparaisons du harnais).
function C.snapshot()
  return C.live and U.copy(C.live)
end
