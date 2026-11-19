-- Tests des règles du Druide (docs/classes/druid.md) : formes, réserve, effets de fin de tour, frappe de l'ours,
-- Clearcasting, Cast et forme de fin de tour, levier de secours, cartes et bibelots clés.
-- Usage : lua5.1 Sim/tests_druid.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
if jit and jit.opt then pcall(jit.opt.start, "maxtrace=65535", "maxmcode=262144") end
local ns = dofile(root .. "/Sim/load.lua")(root)
local Combat, Card, D = ns.Combat, ns.Card, ns.Druid

local passed, failed = 0, 0
local function test(name, f)
  local ok, err = pcall(f)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("ÉCHEC  " .. name .. "\n       " .. tostring(err))
  end
end
local function eq(a, b, msg)
  if a ~= b then error((msg or "") .. " attendu " .. tostring(b) .. ", obtenu " .. tostring(a), 2) end
end

ns.Enemies.dr_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.dr_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }

local function deckOf(list)
  local d = {}
  for i, id in ipairs(list) do
    if type(id) == "table" then d[i] = { id = id[1], up = id[2] } else d[i] = { id = id, up = false } end
  end
  return d
end

-- Combat de test : main imposée (le reste en pioche : cartes de remplissage sans forme), mana 9 sauf opts.mana.
local FILL = { "skull_bash", "skull_bash", "skull_bash", "skull_bash", "skull_bash", "skull_bash" }
local function setup(hand, opts)
  opts = opts or {}
  local list = {}
  for _, id in ipairs(hand) do list[#list + 1] = id end
  for _, id in ipairs(opts.extra or FILL) do list[#list + 1] = id end
  local c = Combat.new({ seed = 7, class = "druid", hp = opts.hp or 60, maxHp = 60, deck = deckOf(list),
    encounter = opts.encounter or { "dr_dummy" }, relics = opts.relics, stats = true, zone = opts.zone })
  local all = {}
  for _, x in ipairs(c.hand) do all[#all + 1] = x end
  for _, x in ipairs(c.draw) do all[#all + 1] = x end
  c.hand, c.draw = {}, {}
  local byId = {}
  for _, x in ipairs(all) do byId[x.id] = byId[x.id] or {}; table.insert(byId[x.id], x) end
  for _, id in ipairs(hand) do
    local key = type(id) == "table" and id[1] or id
    c.hand[#c.hand + 1] = assert(table.remove(byId[key] or {}), "carte absente : " .. key)
  end
  for _, l in pairs(byId) do for _, x in ipairs(l) do c.draw[#c.draw + 1] = x end end
  c.player.mana = opts.mana or 9
  return c
end

local function idx(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
  error("pas en main : " .. id)
end
local function play(c, id, t, o)
  local ok, why = Combat.play(c, idx(c, id), t, o)
  assert(ok, "jeu refusé : " .. id .. " (" .. tostring(why) .. ")")
end
-- Donne une carte en main (instance neuve) ; up facultatif.
local function give(c, id, up)
  local inst = Card.new(id, up, c.nextUid)
  c.nextUid = c.nextUid + 1
  c.hand[#c.hand + 1] = inst
  Combat.listenCard(c, id)
  return inst
end
local function logOf(c, t)
  local out = {}
  for _, ev in ipairs(c.events) do if ev.t == t then out[#out + 1] = ev end end
  return out
end

-- Forme et réserve ----------------------------------------------------------------------------------------

test("début du combat : sans forme, réserve 0 ; un tour fini sans forme ne donne rien", function()
  local c = setup({ "skull_bash" }, { encounter = { "dr_dummy" } })
  eq(c.cls.form, nil, "forme")
  eq(c.player.res, 0, "réserve")
  c.player.res = 3
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 100, "aucune frappe")
  eq(c.player.st.clearcasting, nil)
  eq(c.player.st.regen, nil)
  eq(c.player.res, 3, "la réserve ne baisse pas sans forme")
end)

test("jouer une carte de forme y fait entrer (journal shift, onShift) ; carte de la forme active ou sans forme : rien", function()
  local seen = {}
  ns.Relics.zz_shiftspy = { id = "zz_shiftspy", name = "Spy", hooks = {
    onShift = function(c, src, from, to) seen[#seen + 1] = tostring(from) .. ">" .. to end } }
  local c = setup({ "wrath", "wrath", "skull_bash", "thick_hide" }, { relics = { "zz_shiftspy" } })
  play(c, "wrath", 1)
  eq(c.cls.form, "moonkin")
  play(c, "wrath", 1)
  play(c, "skull_bash", 1)
  eq(c.cls.form, "moonkin", "Skull Bash : sans forme")
  play(c, "thick_hide")
  eq(c.cls.form, "bear")
  eq(table.concat(seen, ","), "nil>moonkin,moonkin>bear")
  local sh = logOf(c, "shift")
  eq(#sh, 2)
  eq(sh[1].from, nil); eq(sh[1].to, "moonkin"); eq(sh[2].from, "moonkin"); eq(sh[2].to, "bear")
  eq(c.cls.shifts, 2, "compteur du tour")
  ns.Relics.zz_shiftspy = nil
end)

test("ordre : coût payé dans la forme d'avant, puis changement, puis résolution dans la nouvelle forme", function()
  -- Cat avec Clearcasting et 3 de réserve : Wrath coûte 0 (Clearcasting, lu en Cat), entre en Moonkin, puis
  -- se résout avec le bonus des Charges (5 + 3)
  local c = setup({ "shred", "wrath" })
  play(c, "shred", 1)
  eq(c.cls.form, "cat")
  c.player.res = 3
  c.player.st.clearcasting = 1
  local hp, mana = c.enemies[1].hp, c.player.mana
  eq(Combat.cost(c, c.hand[idx(c, "wrath")]), 0, "coût affiché")
  play(c, "wrath", 1)
  eq(c.player.mana, mana, "coût 0 payé")
  eq(c.cls.form, "moonkin")
  eq(c.enemies[1].hp, hp - 8, "résolue en Moonkin : 5 + 3")
  eq(c.player.res, 4)
  -- journal : play, shift, puis les dégâts
  local order = {}
  for _, ev in ipairs(c.events) do
    if ev.t == "play" or ev.t == "shift" or ev.t == "damage" or ev.t == "clearcasting_used" then order[#order + 1] = ev.t end
  end
  eq(table.concat(order, ","):match("play,clearcasting_used,shift,damage$") ~= nil, true, table.concat(order, ","))
  -- onShift vu avant la résolution
  local before
  ns.Relics.zz_spy2 = { id = "zz_spy2", name = "Spy", hooks = {
    onShift = function(cc) before = cc.enemies[1].hp end } }
  local d = setup({ "wrath" }, { relics = { "zz_spy2" } })
  play(d, "wrath", 1)
  eq(before, 100, "onShift avant la résolution")
  ns.Relics.zz_spy2 = nil
end)

test("Idol of the Wild : la première carte qui change la forme coûte 0, une seule fois par combat", function()
  local c = setup({ "wrath", "wrath", "thick_hide" }, { relics = { "idol_of_the_wild" }, mana = 3 })
  eq(Combat.cost(c, c.hand[1]), 0, "sans forme : Wrath changera la forme")
  play(c, "wrath", 1)
  eq(c.player.mana, 3)
  eq(Combat.cost(c, c.hand[idx(c, "wrath")]), 1, "même forme")
  eq(Combat.cost(c, c.hand[idx(c, "thick_hide")]), 1, "bibelot servi")
end)

test("réserve gardée au changement de forme : Charges montées en Moonkin dépensées en Combo", function()
  local c = setup({ "wrath", "wrath", "ferocious_bite" })
  play(c, "wrath", 1)
  play(c, "wrath", 1)
  eq(c.player.res, 2)
  local hp = c.enemies[1].hp
  play(c, "ferocious_bite", 1)
  eq(c.cls.form, "cat")
  eq(c.player.res, 0)
  eq(c.enemies[1].hp, hp - (4 + 4 * 2))
end)

test("Surge en Moonkin : Charges lues puis remises à 0 avant le coup (aucun bonus)", function()
  local c = setup({ "wrath", "starsurge" })
  play(c, "wrath", 1)
  c.player.res = 3
  local hp = c.enemies[1].hp
  play(c, "starsurge", 1)
  eq(c.enemies[1].hp, hp - 21)
  local d = setup({ "starsurge" })
  eq(Combat.canPlay(d, 1), false, "Surge seul : injouable à 0")
end)

-- Effets de fin de tour ----------------------------------------------------------------------------------

test("Bear : frappe de 1 + Frenzy sur la dernière cible, +1, puis −1 à la fin du round", function()
  local c = setup({ "maul", "thick_hide" }, { encounter = { "dr_dummy", "dr_dummy" } })
  play(c, "maul", 2) -- cible : le second
  eq(c.player.res, 1, "Maul : frappe 1 + 0, +1")
  eq(c.enemies[2].hp, 100 - 4 - 1)
  c.player.res = 2
  Combat.endPlayerTurn(c)
  eq(c.enemies[2].hp, 100 - 5 - 3, "frappe 1 + 2 sur la dernière cible")
  eq(c.enemies[1].hp, 100)
  eq(c.player.res, 3, "+1 après la frappe")
  local st = logOf(c, "bear_strike")
  eq(st[#st].why, "auto")
  Combat.enemyPhase(c)
  Combat.endRound(c)
  eq(c.player.res, 2, "−1 à la fin du round en Bear")
end)

test("Bear : cible morte -> l'ennemi vivant le plus à gauche", function()
  local c = setup({ "maul" }, { encounter = { "dr_dummy", "dr_dummy" } })
  play(c, "maul", 2)
  c.enemies[2].hp = 1
  Combat.dealDamage(c, c.player, c.enemies[2], 5)
  eq(c.enemies[2].dead, true)
  Combat.endPlayerTurn(c)
  eq(c.enemies[1].hp, 100 - 2, "1 + 1 sur le premier vivant")
end)

test("la réserve ne baisse pas hors de Bear (Moonkin, Cat, Tree of Life)", function()
  for _, id in ipairs({ "wrath", "shred", "rejuvenation" }) do
    local c = setup({ id })
    play(c, id, ns.Cards[id].target == "enemy" and 1 or nil)
    c.player.res = 2
    Combat.endTurn(c)
    eq(c.player.res, 2, id)
  end
end)

test("Cat : Clearcasting à la fin du tour, ne s'empile pas, coût 0 de la prochaine Attack hors Cast", function()
  local c = setup({ "shred" })
  play(c, "shred", 1)
  Combat.endTurn(c)
  eq(c.player.st.clearcasting, 1)
  eq(#logOf(c, "clearcasting"), 1)
  -- second tour fini en Cat sans Attack : toujours une seule
  give(c, "tigers_fury")
  play(c, "tigers_fury")
  Combat.endTurn(c)
  eq(c.player.st.clearcasting, 1, "drapeau")
  eq(#logOf(c, "clearcasting"), 1, "pas de nouvelle pose")
  -- Skill : ne le consomme pas ; Attack Cast : coût normal, ne le consomme pas ; Attack hors Cast : 0, consommé
  give(c, "thick_hide")
  give(c, "starfire")
  give(c, "maul")
  c.player.mana = 9
  play(c, "thick_hide")
  eq(c.player.st.clearcasting, 1, "Skill")
  eq(Combat.cost(c, c.hand[idx(c, "starfire")]), 2, "Cast : coût normal")
  eq(Combat.cost(c, c.hand[idx(c, "maul")]), 0, "Attack hors Cast : 0")
  play(c, "starfire", 1)
  eq(c.player.mana, 9 - 1 - 2)
  eq(c.player.st.clearcasting, 1, "Attack Cast")
  play(c, "maul", 1)
  eq(c.player.mana, 6, "Maul gratuit")
  eq(c.player.st.clearcasting, nil, "consommé")
  eq(#logOf(c, "clearcasting_used"), 1)
end)

test("Clearcasting : une copie (replay) ne le consomme pas", function()
  ns.Relics.zz_replay = { id = "zz_replay", name = "Replay", hooks = {
    replay = function(c, src, v, inst) return v + 1 end } }
  local c = setup({ "wrath" }, { relics = { "zz_replay" } })
  c.player.st.clearcasting = 1
  play(c, "wrath", 1)
  eq(c.player.st.clearcasting, nil, "la carte jouée le consomme")
  c.player.st.clearcasting = 1
  Combat.copyCard(c, c.discard[#c.discard], c.enemies[1])
  eq(c.player.st.clearcasting, 1, "copie")
  ns.Relics.zz_replay = nil
end)

test("Moonkin : 1 dégât à tous par 2 Charges, arrondi au supérieur, 3 au plus, sans bonus des Charges", function()
  for _, k in ipairs({ { 0, 0 }, { 1, 1 }, { 2, 1 }, { 3, 2 }, { 4, 2 }, { 5, 3 } }) do
    local c = setup({ "wrath" }, { encounter = { "dr_dummy", "dr_dummy", "dr_dummy" } })
    play(c, "wrath", 1)
    c.player.res = k[1]
    local hp1 = c.enemies[1].hp
    Combat.endPlayerTurn(c)
    eq(c.enemies[1].hp, hp1 - k[2], "réserve " .. k[1] .. " (cible)")
    eq(c.enemies[2].hp, 100 - k[2], "réserve " .. k[1])
    eq(c.enemies[3].hp, 100 - k[2], "réserve " .. k[1])
    eq(c.player.res, k[1], "réserve lue, pas dépensée")
    eq(#logOf(c, "moonkin_pulse"), k[2] > 0 and 3 or 0)
  end
end)

test("Tree of Life : TREE_ABSORB (2) Absorb à la fin du tour, pour le tour ennemi, sans Regen", function()
  eq(D.TREE_ABSORB, 2)
  eq(D.TREE_REGEN, nil, "plus de Regen de fin de tour")
  local c = setup({ "mark_of_the_wild" }, { hp = 40 })
  play(c, "mark_of_the_wild")
  eq(c.player.st.regen, 2)
  eq(c.player.block, 4)
  Combat.endPlayerTurn(c)
  eq(c.player.st.regen, 2, "la Regen posée ne change pas")
  eq(c.player.block, 4 + 2, "+2 Absorb")
  -- infobulle du mot de plaque : le chiffre écrit est celui de la règle
  local txt = ns.Language.plateByKey("form:tree").text
  assert(txt:find("gain " .. D.TREE_ABSORB .. " Absorb", 1, true), txt)
end)

-- Cast et forme de fin de tour ---------------------------------------------------------------------------

test("Cast : la forme change au jeu ; la résolution se fait dans la forme de fin de tour", function()
  -- fin en Bear : Starfire sans bonus (la frappe de l'ours, 1 + 3, passe avant)
  local a = setup({ "starfire", "thick_hide" })
  a.player.res = 3
  play(a, "starfire", 1)
  eq(a.cls.form, "moonkin", "au jeu")
  play(a, "thick_hide")
  Combat.endTurn(a)
  eq(a.cls.form, "bear", "la résolution ne change pas la forme")
  eq(a.enemies[1].hp, 100 - 4 - 24)
  -- fin en Moonkin : coups à tous (ceil(3 / 2) = 2), puis Starfire avec le bonus (24 + 3)
  local b = setup({ "starfire" })
  b.player.res = 3
  play(b, "starfire", 1)
  Combat.endTurn(b)
  eq(b.cls.form, "moonkin")
  eq(b.enemies[1].hp, 100 - 2 - 27)
end)

test("Nature's Swiftness : sans forme ; Starfire part tout de suite, dans sa forme, avec le bonus", function()
  local c = setup({ "thick_hide", "natures_swiftness", "starfire" })
  play(c, "thick_hide")
  c.player.res = 2
  play(c, "natures_swiftness")
  eq(c.cls.form, "bear", "sans forme")
  play(c, "starfire", 1)
  eq(c.cls.form, "moonkin")
  eq(c.enemies[1].hp, 100 - 26)
  eq(c.player.cast, nil)
end)

test("Healing Touch : entre en Tree au jeu, soigne au tour suivant dans n'importe quelle forme", function()
  local c = setup({ "healing_touch", "thick_hide" }, { hp = 30 })
  play(c, "healing_touch")
  eq(c.cls.form, "tree")
  play(c, "thick_hide")
  Combat.endTurn(c)
  eq(c.cls.form, "bear")
  eq(c.player.hp, 42)
end)

-- Coups sans carte ---------------------------------------------------------------------------------------

test("bonus de Moonkin absent des coups sans carte (frappe de l'ours, coups à tous)", function()
  local c = setup({ "wrath" })
  play(c, "wrath", 1)
  c.player.res = 3
  local hp = c.enemies[1].hp
  D.bearStrike(c, "card")
  eq(c.enemies[1].hp, hp - 4, "frappe : 1 + 3, sans +3")
  eq(D.strikeDamage(c), 1 + 4)
end)

test("Mangle : une frappe par Frenzy compté, chacune à 1 + le montant, sans gain, puis +2 ; Swipe : frappe sur la dernière cible", function()
  local c = setup({ "mangle", "swipe" }, { encounter = { "dr_dummy", "dr_dummy" } })
  c.player.res = 3
  play(c, "mangle", 2)
  eq(c.enemies[2].hp, 100 - 3 * 4)
  eq(c.player.res, 2, "réserve vidée par le Surge, puis +2 Frenzy")
  play(c, "swipe")
  eq(c.enemies[1].hp, 100 - 4)
  eq(c.enemies[2].hp, 100 - 12 - 4 - 3, "Swipe à tous puis frappe 1 + 2 sur la dernière cible")
  eq(c.player.res, 3)
  -- jouable à 0 : aucune frappe, +2 Frenzy
  local z = setup({ "mangle" })
  assert(Combat.canPlay(z, 1), "Mangle jouable à 0")
  play(z, "mangle", 1)
  eq(z.enemies[1].hp, 100); eq(z.player.res, 2)
end)

test("Idol of Brutality : +2 aux frappes de l'ours (automatique, carte, Surge)", function()
  local c = setup({ "maul" }, { relics = { "idol_of_brutality" } })
  play(c, "maul", 1)
  eq(c.enemies[1].hp, 100 - 4 - 3)
  eq(D.strikeDamage(c), 3 + 1)
end)

test("Swamp : la frappe automatique évite un dormeur tant qu'un ennemi est éveillé, la frappe d'une carte non", function()
  local c = setup({ "maul" }, { encounter = { "dr_dummy", "dr_dummy" }, zone = "swamp" })
  assert(ns.Swamp, "règles du marais")
  ns.Swamp.sleep(c, c.enemies[1], 3)
  c.player.lastTarget = c.enemies[1].uid
  eq(c.step, "play")
  eq(D.strikeTarget(c), c.enemies[1], "pendant le jeu : la dernière cible, dormeur compris")
  c.step = "turnEnd"
  eq(D.strikeTarget(c), c.enemies[2], "fin de tour : l'éveillé")
  c.step = "play"
end)

-- Levier de secours -------------------------------------------------------------------------------------

test("levier A (actif) : à partir du 2e changement d'un tour, −1 mana au tour suivant, −2 au plus", function()
  eq(D.TAX, 1, "actif")
  eq(D.TAX_FREE, 1, "un changement gratuit")
  -- un seul changement (entrée dans la première forme du combat comprise) : gratuit
  local c = setup({ "wrath", "wrath", "skull_bash" })
  play(c, "wrath", 1); play(c, "wrath", 1); play(c, "skull_bash", 1)
  eq(c.cls.shifts, 1, "même forme, sans forme : aucun changement")
  eq(D.pendingTax(c), 0)
  Combat.endTurn(c)
  eq(c.player.mana, 3, "1 changement : 3 mana")
  -- deux changements (sans forme → Moonkin → Bear) : −1
  local a = setup({ "wrath", "thick_hide" })
  play(a, "wrath", 1); play(a, "thick_hide")
  eq(a.cls.shifts, 2)
  eq(D.pendingTax(a), 1)
  Combat.endTurn(a)
  eq(a.player.mana, 2, "2 changements : −1")
  eq(a.cls.shifts, 0, "compteur remis à 0")
  eq(a.cls.tax, 1)
  local b = setup({ "wrath", "thick_hide", "shred", "rejuvenation" })
  play(b, "wrath", 1); play(b, "thick_hide"); play(b, "shred", 1); play(b, "rejuvenation")
  Combat.endTurn(b)
  eq(b.player.mana, 1, "4 changements : −2 au plus")
  Combat.endTurn(b)
  eq(b.player.mana, 3, "tour sans changement : plus de malus")
  -- levier coupé (TAX = 0) : aucun malus
  local old = D.TAX
  D.TAX = 0
  local ok, err = pcall(function()
    local z = setup({ "wrath", "thick_hide", "shred" })
    play(z, "wrath", 1); play(z, "thick_hide"); play(z, "shred", 1)
    eq(D.pendingTax(z), 0)
    Combat.endTurn(z)
    eq(z.player.mana, 3, "levier inactif : 3 mana")
  end)
  D.TAX = old
  assert(ok, err)
end)

test("taxe : un passage entre Cat et Bear ne compte pas ; il reste un changement (onShift, Idol of the Wild)", function()
  eq(D.taxed("cat", "bear"), false); eq(D.taxed("bear", "cat"), false)
  eq(D.taxed(nil, "cat"), true, "entrée dans la première forme : comptée")
  eq(D.taxed("moonkin", "cat"), true); eq(D.taxed("tree", "bear"), true); eq(D.taxed("bear", "moonkin"), true)
  -- premier tour : sans forme → Cat → Bear → Cat → Bear : un seul changement compté (l'entrée), 4 changements
  local c = setup({ "shred", "thick_hide", "rake", "maul" }, { mana = 4 })
  local fired = 0
  local old = ns.Combat.fire
  ns.Combat.fire = function(cc, name, ...)
    if name == "onShift" then fired = fired + 1 end
    return old(cc, name, ...)
  end
  local ok, err = pcall(function()
    play(c, "shred", 1); play(c, "thick_hide"); play(c, "rake", 1); play(c, "maul", 1)
  end)
  ns.Combat.fire = old
  assert(ok, err)
  eq(c.cls.shifts, 4, "quatre changements de forme")
  eq(fired, 4, "onShift à chaque changement")
  eq(c.cls.taxed, 1, "un seul compté")
  eq(D.pendingTax(c), 0)
  Combat.endTurn(c)
  eq(c.player.mana, 3, "aucun malus")
  -- Moonkin → Cat → Bear (depuis Moonkin, tour 2) : un seul changement compté, gratuit
  local m = setup({ "wrath" })
  play(m, "wrath", 1)
  Combat.endTurn(m)
  eq(m.cls.form, "moonkin")
  m.player.mana = 9
  give(m, "shred"); give(m, "thick_hide"); give(m, "wrath")
  play(m, "shred", 1); play(m, "thick_hide")
  eq(m.cls.shifts, 2); eq(m.cls.taxed, 1)
  eq(D.pendingTax(m), 0)
  -- Cat → Bear → Moonkin : la sortie vers Moonkin compte
  play(m, "wrath", 1)
  eq(m.cls.taxed, 2)
  eq(D.pendingTax(m), 1)
end)

test("bot : la taxe à venir compte dans l'évaluation (fin de tour simulée) et distingue deux positions", function()
  local a = setup({ "wrath", "thick_hide" }, { mana = 3 })
  local b = setup({ "wrath", "wrath" }, { mana = 3 })
  play(a, "wrath", 1); play(a, "thick_hide")
  play(b, "wrath", 1); play(b, "wrath", 1)
  local cr = ns.ClassRules.druid
  local ka, kb = cr.botKey(a), cr.botKey(b)
  eq(ka:match(":(%d+)$"), "2", "changements dans la clé")
  eq(kb:match(":(%d+)$"), "1")
  Combat.endPlayerTurn(a)
  Combat.endPlayerTurn(b)
  eq(a.cls.tax, 1); eq(b.cls.tax, 0)
  local W = { enemyHp = 1, castRisk = 1, res = 5 }
  local va, vb = cr.botValue(a, W), cr.botValue(b, W)
  -- a finit en Bear (baisse du Frenzy à venir) : on ne compare que la part de la taxe
  local bearPart = (a.player.res or 0) > 0 and -(ns.Classes.druid.bot.resValue) or 0
  eq(va - bearPart, -D.TAX_VALUE, "−22 par mana perdu")
  eq(vb, 0)
end)

-- Cartes et bibelots clés --------------------------------------------------------------------------------

test("Rake, Shred : Combo et DoT ; Frenzied Regeneration : Spend 2 au choix", function()
  local c = setup({ "rake", "shred", "frenzied_regeneration", "frenzied_regeneration" })
  play(c, "rake", 1)
  eq(c.enemies[1].st.pain, 3)
  play(c, "shred", 1)
  eq(c.player.res, 2)
  eq(c.enemies[1].hp, 100 - 3 - 7)
  play(c, "frenzied_regeneration", nil, { spend = false })
  eq(c.player.block, 6); eq(c.player.res, 2)
  play(c, "frenzied_regeneration")
  eq(c.player.block, 18); eq(c.player.res, 0)
end)

test("Faerie Fire, Hurricane : Sundered, Charges, bonus de Moonkin sur chaque cible d'un Cast à tous", function()
  local c = setup({ "faerie_fire", "hurricane" }, { encounter = { "dr_dummy", "dr_dummy" } })
  play(c, "faerie_fire", 1)
  eq(c.player.res, 1); eq(c.enemies[1].st.armor_broken, 2)
  play(c, "hurricane")
  c.player.res = 2
  Combat.endTurn(c)
  -- coups à tous ceil(2 / 2) = 1, puis Hurricane 15 + 2 (Sundered sur le premier : ×1,25)
  eq(c.enemies[2].hp, 100 - 1 - 17)
  eq(c.enemies[1].hp, 100 - 1 - math.floor(17 * 1.25))
end)

test("Swiftmend : 2 par Regen sans la retirer ; Regrowth, Rejuvenation : Exhaust", function()
  local c = setup({ "rejuvenation", "swiftmend", "regrowth" }, { hp = 20 })
  play(c, "rejuvenation")
  eq(c.player.st.regen, 4)
  play(c, "swiftmend")
  eq(c.player.hp, 28); eq(c.player.st.regen, 4)
  play(c, "regrowth")
  eq(c.player.hp, 32); eq(c.player.st.regen, 7)
  eq(#c.exhaust, 3)
end)

test("Powers : sans forme ; Leader of the Pack, Moonkin Aura, Gift of Nature, Thorns, Rebirth", function()
  local c = setup({ "leader_of_the_pack", "moonkin_aura", "gift_of_nature", "shred", "wrath" })
  play(c, "leader_of_the_pack"); play(c, "moonkin_aura"); play(c, "gift_of_nature")
  eq(c.cls.form, nil, "Powers sans forme")
  play(c, "shred", 1)
  eq(c.player.res, 2, "Shred +1, Leader +1")
  play(c, "wrath", 1)
  eq(c.player.res, 3, "Wrath (Moonkin) : pas de Leader")
  -- Gift of Nature : +2 sous Regen aux coups des Attack, pas à la frappe de l'ours
  c.player.st.regen = 2
  local hp = c.enemies[1].hp
  give(c, "wrath")
  play(c, "wrath", 1)
  eq(c.enemies[1].hp, hp - (5 + 3 + 2))
  -- Moonkin Aura : après les coups à tous (lus à 4 Charges)
  eq(c.player.res, 4)
  hp = c.enemies[1].hp
  local b0 = c.player.block
  Combat.endPlayerTurn(c)
  eq(c.enemies[1].hp, hp - 2, "ceil(4 / 2)")
  eq(c.player.res, 5, "+1 après")
  eq(c.player.block, b0 + 4, "Moonkin Aura : 4 Absorb")
  -- Demoralizing Roar : +1 Frenzy, 8 Absorb, Demoralized 2 à tous
  local r = setup({ "demoralizing_roar" })
  play(r, "demoralizing_roar")
  eq(r.cls.form, "bear")
  eq(r.player.res, 1)
  eq(r.player.block, 8, "Demoralizing Roar : 8 Absorb")
  eq(r.enemies[1].st.demoralized, 2)
  -- Thorns et Rebirth
  local t = setup({ "thorns", "rebirth" }, { encounter = { "dr_hitter" }, hp = 5 })
  play(t, "thorns"); play(t, "rebirth")
  Combat.endTurn(t)
  eq(t.result, nil, "Rebirth")
  eq(t.player.hp, 13, "1 + 12")
  eq(t.enemies[1].hp, 100 - 3, "Thorns")
end)

test("bibelots : Wolfshead Helm, Idol of the Moon, Idol of Rejuvenation, Idol of Ferocity", function()
  local c = setup({ "wrath", "thick_hide", "rejuvenation" },
    { relics = { "wolfshead_helm", "idol_of_the_moon", "idol_of_rejuvenation" } })
  local n = #c.hand
  play(c, "wrath", 1)
  eq(#c.hand, n - 1 + 1, "premier changement du tour : pioche 1")
  play(c, "thick_hide")
  eq(#c.hand, n - 2 + 1, "second : rien")
  play(c, "rejuvenation")
  eq(c.player.block, 5 + 3, "Tree : 3 Absorb")
  give(c, "wrath")
  play(c, "wrath", 1)
  c.player.block = 0
  Combat.endPlayerTurn(c)
  eq(c.player.block, 4, "fin en Moonkin : 4 Absorb")
  local f = setup({ "shred", "ferocious_bite" }, { relics = { "idol_of_ferocity" } })
  play(f, "shred", 1)
  local h = #f.hand
  play(f, "ferocious_bite", 1)
  eq(#f.hand, h - 1 + 1, "Surge en Cat : pioche 1")
end)

test("Skull Bash : interrompt sans changer la forme", function()
  ns.Enemies.dr_caster = { name = "Lanceur", hp = 100,
    moves = { bolt = { name = "Trait", intent = "cast", cast = true, actions = { { "attack", 20 } } } }, pattern = { "bolt" } }
  local c = setup({ "thick_hide", "skull_bash" }, { encounter = { "dr_caster" } })
  play(c, "thick_hide")
  play(c, "skull_bash", 1)
  eq(c.enemies[1].interrupted, true)
  eq(c.cls.form, "bear")
end)

-- Bots et simulation -------------------------------------------------------------------------------------

test("état de classe cloné ; clé des bots : forme et Clearcasting distinguent deux positions", function()
  local c = setup({ "wrath" })
  local k0 = ns.ClassRules.druid.botKey(c)
  play(c, "wrath", 1)
  local cl = Combat.clone(c)
  eq(cl.cls.form, "moonkin")
  cl.cls.form = "cat"
  eq(c.cls.form, "moonkin", "copie profonde")
  local k1 = ns.ClassRules.druid.botKey(c)
  c.player.st.clearcasting = 1
  local k2 = ns.ClassRules.druid.botKey(c)
  assert(k0 ~= k1 and k1 ~= k2, k0 .. " / " .. k1 .. " / " .. k2)
end)

test("bot heuristic : un combat de Druide se joue sans erreur", function()
  local deck = deckOf(ns.Classes.druid.deck)
  local c = Combat.new({ seed = 3, class = "druid", hp = 65, maxHp = 65, deck = deck, encounter = { "dr_hitter" },
    relics = { "idol_of_the_wild" }, stats = true })
  local bot = ns.Bots.new("heuristic", ns.Rng.new(1))
  local steps = 0
  while not c.result and steps < 300 do
    local a = bot:act(c)
    steps = steps + 1
    if a[1] == "play" then
      if not Combat.play(c, a[2], a[3], a[4] == "nospend" and { spend = false } or nil) then Combat.endTurn(c) end
    elseif a[1] == "potion" then
      Combat.usePotion(c, a[2], a[3])
    else
      Combat.endTurn(c)
    end
  end
  eq(c.result, "won")
  local z = c.stats.zone or {}
  local ends = (z.druid_end_bear or 0) + (z.druid_end_cat or 0) + (z.druid_end_moonkin or 0)
    + (z.druid_end_tree or 0) + (z.druid_end_none or 0)
  assert(ends >= c.stats.turns - 1 and ends <= c.stats.turns, "une forme de fin par tour fini : " .. ends)
end)

test("expédition simulée du Druide (bot greedy) : de bout en bout, déterministe", function()
  local a = ns.SimExpedition.play({ seed = 11, bot = "greedy", class = "druid" })
  local b = ns.SimExpedition.play({ seed = 11, bot = "greedy", class = "druid" })
  assert(#a.combats > 0)
  eq(#a.combats, #b.combats)
  eq(a.won, b.won)
end)

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
