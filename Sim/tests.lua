-- Tests des règles. Usage : lua5.1 Sim/tests.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local Combat, Card, Rng = ns.Combat, ns.Card, ns.Rng

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

-- Données de test : un ennemi passif et un ennemi qui frappe.
ns.Enemies.test_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.test_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }
ns.Enemies.test_caster = { name = "Lanceur", hp = 100,
  moves = { bolt = { name = "Trait", intent = "cast", cast = true, actions = { { "attack", 20 } } } }, pattern = { "bolt" } }
ns.Enemies.test_watcher = { name = "Guetteur", hp = 100,
  moves = { watch = { name = "Guette", intent = "watch", actions = { { "interrupt" } } } }, pattern = { "watch" } }
ns.Enemies.test_pusher = { name = "Cogneur vif", hp = 100,
  moves = { kick = { name = "Coup de pied", intent = "attack", actions = { { "attack", 10, interrupts = true } } } },
  pattern = { "kick" } }
ns.Enemies.test_boss = { name = "Boss", hp = 100, boss = true,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }

local function deckOf(...)
  local d = {}
  for i, id in ipairs({ ... }) do d[i] = { id = id, up = false } end
  return d
end

-- Combat dont la main de départ est exactement `hand` (le reste en pioche).
local function setup(hand, encounter, extra, more)
  local deck = deckOf(unpack(hand))
  for _, id in ipairs(extra or {}) do deck[#deck + 1] = { id = id, up = false } end
  local o = { seed = 7, hp = 60, maxHp = 60, deck = deck, encounter = encounter or { "test_dummy" } }
  for k, v in pairs(more or {}) do o[k] = v end
  local c = Combat.new(o)
  -- remet la main dans l'ordre demandé
  local all = {}
  for _, x in ipairs(c.hand) do all[#all + 1] = x end
  for _, x in ipairs(c.draw) do all[#all + 1] = x end
  c.hand, c.draw = {}, {}
  for i = 1, #all do
    if i <= #hand then c.hand[#c.hand + 1] = nil end
  end
  local byId = {}
  for _, x in ipairs(all) do byId[x.id] = byId[x.id] or {}; table.insert(byId[x.id], x) end
  for _, id in ipairs(hand) do c.hand[#c.hand + 1] = table.remove(byId[id]) end
  for _, list in pairs(byId) do for _, x in ipairs(list) do c.draw[#c.draw + 1] = x end end
  return c
end

-- Valeur du i-ème effet d'une carte (j = position dans l'effet, 2 par défaut).
local function num(id, i, j) return Card.defById(id).effects[i][j or 2] end

local function handIndex(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
end

test("rng déterministe et dans les bornes", function()
  local a, b = Rng.new(42), Rng.new(42)
  for _ = 1, 1000 do
    local x = Rng.int(a, 1, 6)
    eq(x, Rng.int(b, 1, 6))
    assert(x >= 1 and x <= 6)
  end
  local s1, s2 = Rng.stream(1, "draw"), Rng.stream(1, "ai")
  assert(Rng.next(s1) ~= Rng.next(s2), "flux distincts")
end)

test("toutes les cartes ont nom, coût, effets, texte et amélioration", function()
  for id, d in pairs(ns.Cards) do
    assert(d.name and d.cost and d.effects and d.text and d.type and d.rarity, id)
    assert(d.up and d.up.text, id .. " : amélioration manquante")
    local u = Card.defById(id, true)
    assert(u.name:sub(-1) == "+", id)
  end
end)

test("tous les ennemis des rencontres existent et ont des intentions valides", function()
  for _, pools in pairs(ns.Encounters) do
    for _, list in pairs(pools) do
      for _, enc in ipairs(list) do
        for _, id in ipairs(enc) do
          local d = ns.Enemies[id]
          assert(d, "ennemi " .. id)
          for _, mv in ipairs(d.pattern or {}) do assert(d.moves[mv], id .. " : " .. mv) end
        end
      end
    end
  end
end)

test("dégâts, mana, défausse", function()
  local c = setup({ "smite", "smite", "smite", "smite" })
  local e = c.enemies[1]
  assert(Combat.play(c, 1, 1))
  eq(e.hp, 94, "PV ennemi")
  eq(c.player.mana, 2, "mana")
  eq(#c.discard, 1, "défausse")
end)

test("l'Absorption encaisse puis tombe au début du tour", function()
  local c = setup({ "inner_fire" }, { "test_hitter" })
  assert(Combat.play(c, 1))
  eq(c.player.block, 5)
  Combat.endTurn(c)
  eq(c.player.hp, 55, "10 - 5 absorbés")
  eq(c.player.block, 0, "Absorption retombée")
end)

test("Armure fracassée : +25 % de dégâts subis", function()
  local c = setup({ "smite" })
  local e = c.enemies[1]
  Combat.applyStatus(c, e, "armor_broken", 1)
  Combat.play(c, 1, 1)
  eq(e.hp, 100 - 7)
end)

test("Démoralisé posé par l'ennemi dure le tour du joueur suivant", function()
  local c = setup({}, { "test_dummy" })
  c.phase = "enemy"
  Combat.applyStatus(c, c.player, "demoralized", 1)
  Combat.endRound(c)
  eq(c.player.st.demoralized, 1, "survit à la fin du round où il est posé")
  Combat.endRound(c)
  eq(c.player.st.demoralized, nil, "expire au round suivant")
end)

test("Douleur : dégâts en début de tour, ignore l'Absorption, puis baisse", function()
  local c = setup({ "sw_pain" })
  local e = c.enemies[1]
  e.block = 50
  Combat.play(c, 1, 1)
  eq(e.st.pain, 5)
  eq(c.player.res, 1)
  Combat.endTurn(c)
  eq(e.hp, 95)
  eq(e.st.pain, 4)
end)

test("Recharge : absente N tours, puis revient en main", function()
  local c = setup({ "pw_shield" }, { "test_dummy" }, { "smite", "smite", "smite", "smite", "smite",
    "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite" })
  Combat.play(c, 1)
  eq(#c.cooldown, 1)
  Combat.endTurn(c) -- tour 2
  assert(not handIndex(c, "pw_shield"), "pas au tour 2")
  Combat.endTurn(c) -- tour 3
  assert(not handIndex(c, "pw_shield"), "pas au tour 3")
  Combat.endTurn(c) -- tour 4
  assert(handIndex(c, "pw_shield"), "revenue au tour 4")
end)

test("Incantation : payée maintenant, résolue au début du tour suivant", function()
  local c = setup({ "holy_fire" })
  local e = c.enemies[1]
  Combat.play(c, 1, 1)
  eq(c.player.mana, 1)
  eq(e.hp, 100, "pas encore")
  assert(c.player.cast)
  Combat.endTurn(c)
  eq(e.hp, 100 - num("holy_fire", 1), "dégâts au tour suivant")
  eq(e.st.pain, num("holy_fire", 2, 3))
end)

test("une seule incantation à la fois", function()
  local c = setup({ "holy_fire", "greater_heal" })
  c.player.mana = 5
  Combat.play(c, 1, 1)
  local ok, why = Combat.canPlay(c, 1)
  eq(ok, false)
  eq(why, "casting")
end)

test("Guette coupe l'incantation du joueur", function()
  local c = setup({ "holy_fire" }, { "test_watcher" })
  local e = c.enemies[1]
  Combat.play(c, 1, 1)
  Combat.endTurn(c)
  eq(e.hp, 100, "sort perdu")
  eq(c.player.cast, nil)
end)

test("Silence annule le sort ennemi", function()
  local c = setup({ "silence" }, { "test_caster" })
  Combat.play(c, 1, 1)
  Combat.endTurn(c)
  eq(c.player.hp, 60, "Trait annulé")
  Combat.endTurn(c)
  eq(c.player.hp, 40, "le suivant passe")
end)

test("Expiation : une carte de dégâts rend 2 PV", function()
  local c = setup({ "radiance", "smite" })
  c.player.hp = 50
  Combat.play(c, 1)
  Combat.play(c, 1, 1)
  eq(c.player.hp, 52)
end)

test("Pénitence sous Expiation : 2 Absorption par coup", function()
  local c = setup({ "radiance", "penance" })
  Combat.play(c, 1)
  Combat.play(c, 1, 1)
  eq(c.player.block, 4 + 6)
  eq(c.enemies[1].hp, 100 - 3 * num("penance", 1))
end)

test("Expiation 1 tour : dure encore tout le tour suivant du joueur", function()
  local c = setup({ "luminous_barrier" })
  Combat.play(c, 1)
  eq(c.player.st.atonement, 1)
  Combat.endTurn(c) -- tour 2
  eq(c.player.st.atonement, 1, "toujours active au tour suivant")
  c.hand = { Card.new("penance", false, c.nextUid) }
  c.nextUid = c.nextUid + 1
  c.player.block = 0
  Combat.play(c, 1, 1)
  eq(c.player.block, 3 * 2, "Pénitence : 2 Absorption par coup")
  Combat.endTurn(c) -- tour 3
  eq(c.player.st.atonement, nil, "disparue au tour d'après")
end)

test("Expiation : ré-empilement sans compter deux fois le tour en cours", function()
  -- deux fois 1 au même tour : jusqu'à la fin du tour 3
  local c = setup({ "solace", "solace" })
  Combat.play(c, 1, 1)
  Combat.play(c, 1, 1)
  eq(c.player.st.atonement, 2)
  Combat.endTurn(c)
  Combat.endTurn(c)
  eq(c.player.st.atonement, 1, "active au tour 3")
  Combat.endTurn(c)
  eq(c.player.st.atonement, nil, "finie au tour 4")
  -- 1 au tour 1 puis 1 au tour 2 : jusqu'à la fin du tour 3, pas plus
  local d = setup({ "solace" })
  Combat.play(d, 1, 1)
  Combat.endTurn(d) -- tour 2
  d.hand = { Card.new("solace", false, d.nextUid) }
  d.nextUid = d.nextUid + 1
  Combat.play(d, 1, 1)
  eq(d.player.st.atonement, 1, "le tour en cours n'est pas recompté")
  Combat.endTurn(d)
  eq(d.player.st.atonement, 1, "active au tour 3")
  Combat.endTurn(d)
  eq(d.player.st.atonement, nil, "finie au tour 4")
  -- le clone garde la protection
  local e = setup({ "solace" })
  Combat.play(e, 1, 1)
  local k = Combat.clone(e)
  Combat.endTurn(k)
  eq(k.player.st.atonement, 1, "clone : active au tour 2")
end)

test("Armure fracassée posée par le joueur baisse dès la fin du round", function()
  local c = setup({ "schism" })
  Combat.play(c, 1, 1)
  local e = c.enemies[1]
  eq(e.st.armor_broken, num("schism", 2, 3))
  Combat.endTurn(c)
  eq(e.st.armor_broken, num("schism", 2, 3) - 1)
end)

test("Étourdi : l'ennemi perd son tour ; les boss y sont immunisés", function()
  local c = setup({ "chastise" }, { "test_hitter" })
  Combat.play(c, 1, 1)
  Combat.endTurn(c)
  eq(c.player.hp, 60, "pas de coup")
  local b = setup({ "chastise" }, { "test_boss" })
  Combat.play(b, 1, 1)
  eq(b.enemies[1].st.stunned, nil)
end)

test("Forme d'ombre : +3 dégâts et +3 Douleur aux cartes d'ombre, rien sur le sacré", function()
  local c = setup({ "shadowform", "mind_flay", "smite", "sw_pain" })
  c.player.mana = 5
  Combat.play(c, 1)
  eq(Combat.cost(c, c.hand[handIndex(c, "smite")]), 1)
  Combat.play(c, handIndex(c, "mind_flay"), 1)
  eq(c.enemies[1].hp, 100 - num("mind_flay", 3) - 3)
  Combat.play(c, handIndex(c, "sw_pain"), 1)
  eq(c.enemies[1].st.pain, num("sw_pain", 1, 3) + 3)
end)

test("Esprit de rédemption : reste à 1 PV, tour suivant gratuit", function()
  local c = setup({ "spirit_of_redemption" }, { "test_hitter" }, { "smite" })
  Combat.play(c, 1)
  c.player.hp = 5
  Combat.endTurn(c)
  eq(c.result, nil)
  eq(c.player.hp, 1 + 6, "1 PV, puis Récupération 6 au début du tour")
  eq(Combat.cost(c, c.hand[1]), 0)
end)

test("Peste dévorante : dépense la Démence", function()
  local c = setup({ "devouring_plague" })
  eq(Combat.canPlay(c, 1), false, "sans Démence")
  c.player.res = 3
  Combat.play(c, 1, 1)
  eq(c.player.res, 0)
  eq(c.enemies[1].st.pain, 6)
end)

test("murlocs : la mort d'un murloc renforce les autres", function()
  local c = setup({ "smite" }, { "murloc", "murloc" })
  c.enemies[1].hp = 3
  Combat.play(c, 1, 1)
  eq(c.enemies[2].st.force, 1)
end)

test("VanCleef appelle deux sbires à 50 % ; sa mort termine le combat", function()
  local c = setup({ "smite" }, { "vancleef" })
  local v = c.enemies[1]
  v.hp = math.floor(v.maxHp / 2) + 3
  Combat.play(c, 1, 1)
  eq(#c.enemies, 3)
  v.hp = 1
  Combat.dealDamage(c, c.player, v, 5)
  eq(c.result, "won")
end)

-- Contenu ajouté : réputation, bibelots, potions --------------------------------

-- Table « Progression par classe » du GDD : niveau 1 = 4 cartes de départ + 6 par voie et 2 bibelots
-- (dont celui de départ) ; 2, 4, 6 = une carte par voie ; 3 et 5 = un bibelot ; 7 = une rare par voie et
-- 2 bibelots.
test("progression : répartition exacte des cartes et bibelots par niveau, pour chaque classe jouable", function()
  local n = 0
  for class, cd in pairs(ns.Classes) do
    if cd.playable ~= false then
      n = n + 1
      local paths = { start = true }
      for _, p in ipairs(cd.paths) do paths[p.id] = true end
      local by = {} -- by[voie][niveau] = nombre
      local rare7 = {}
      for id, d in pairs(ns.Cards) do
        if d.class == class then
          assert(type(d.level) == "number" and d.level >= 1 and d.level <= 7, id .. " : level")
          assert(d.rep == nil, id .. " : rep retiré")
          assert(paths[d.path], id .. " : voie")
          by[d.path] = by[d.path] or {}
          by[d.path][d.level] = (by[d.path][d.level] or 0) + 1
          if d.rarity == "basic" then eq(d.level, 1, id .. " : carte de départ au niveau 1") end
          if d.level == 7 then eq(d.rarity, "rare", id .. " : niveau 7 = rare") rare7[d.path] = true end
        end
      end
      eq(by.start[1], 4, class .. " : départ")
      local total = { 0, 0, 0, 0, 0, 0, 0 }
      for _, p in ipairs(cd.paths) do
        local b = by[p.id] or {}
        eq(b[1], 6, class .. "/" .. p.id .. " niveau 1")
        for _, lv in ipairs({ 2, 4, 6, 7 }) do eq(b[lv], 1, class .. "/" .. p.id .. " niveau " .. lv) end
        for _, lv in ipairs({ 3, 5 }) do eq(b[lv], nil, class .. "/" .. p.id .. " niveau " .. lv) end
        assert(rare7[p.id], class .. "/" .. p.id .. " : rare au niveau 7")
        for lv = 1, 7 do total[lv] = total[lv] + (b[lv] or 0) end
      end
      eq(total[1] + 4, 22, class .. " : 22 cartes au niveau 1")
      eq(total[1] + 4 + total[2] + total[4] + total[6] + total[7], 34, class .. " : 34 cartes au niveau 7")
      local rl, start = {}, cd.startRelic and ns.Relics[cd.startRelic]
      local nr = 0
      for id, r in pairs(ns.Relics) do
        if r.class == class then
          nr = nr + 1
          assert(type(r.level) == "number", id .. " : level")
          assert(r.tier == nil, id .. " : tier retiré (la Ligue ne compte pas)")
          rl[r.level] = (rl[r.level] or 0) + 1
        end
      end
      eq(nr, 6, class .. " : 6 bibelots de classe")
      eq(rl[1], 2, class .. " : 2 bibelots au niveau 1"); eq(rl[3], 1); eq(rl[5], 1); eq(rl[7], 2, class .. " : 2 au niveau 7")
      assert(start and start.class == class and start.level == 1 and start.noPool, class .. " : bibelot de départ")
    end
  end
  eq(n, 5, "cinq classes jouables")
end)

test("récompenses filtrées par niveau de classe", function()
  local rng = Rng.new(5)
  for _ = 1, 200 do
    local ch = ns.Rewards.cardChoices(rng, "priest", 3, nil, 1)
    eq(#ch, 3)
    for _, id in ipairs(ch) do eq(ns.Cards[id].level, 1, id) end
  end
  eq(#ns.Rewards.cardPool("priest", 1), 18)
  eq(#ns.Rewards.cardPool("priest", 2), 21)
  eq(#ns.Rewards.cardPool("priest", 6), 27)
  eq(#ns.Rewards.cardPool("priest"), 30)
  local pool = ns.Rewards.relicPool({ class = "priest", level = 3 })
  local function has(id) for _, x in ipairs(pool) do if x == id then return true end end return false end
  assert(has("mindtap_talisman") and has("benediction") and not has("robes_of_prophecy") and not has("sacred_candle"))
end)

test("bibelots du Prêtre : Sacred Candle, Mindtap Talisman, Benediction, Robes, Anathema, Vestments", function()
  eq(ns.Classes.priest.startRelic, "sacred_candle")
  -- Sacred Candle : Atonement 1 au début du combat (premier tour et le suivant)
  local c = setup({ "smite" }, { "test_dummy" }, nil, { relics = { "sacred_candle" } })
  assert((c.player.st.atonement or 0) >= 1, "Atonement posé")
  -- Mindtap Talisman : +2 Insanity
  c = setup({ "smite" }, { "test_dummy" }, nil, { relics = { "mindtap_talisman" } })
  eq(c.player.res, 2)
  -- Benediction : chaque Regen gagné +1 (Renew), sans toucher aux états des ennemis
  local a = setup({ "renew" }, { "test_dummy" })
  local b = setup({ "renew" }, { "test_dummy" }, nil, { relics = { "benediction" } })
  Combat.play(a, 1, 1); Combat.play(b, 1, 1)
  eq(b.player.st.regen, a.player.st.regen + 1)
  -- Robes of Prophecy : Absorb +2 sous Atonement seulement
  a = setup({ "inner_fire" }, { "test_dummy" }, nil, { relics = { "robes_of_prophecy" } })
  Combat.play(a, 1)
  eq(a.player.block, 5, "sans Atonement")
  b = setup({ "inner_fire" }, { "test_dummy" }, nil, { relics = { "robes_of_prophecy", "sacred_candle" } })
  Combat.play(b, 1)
  eq(b.player.block, 7, "sous Atonement")
  -- Anathema : un Surge compte 2 de plus (Void Eruption à 3 Insanity : 4 + 4 × 5), la dépense reste 3
  a = setup({ "void_eruption" }, { "test_dummy" }, nil, { relics = { "anathema" } })
  a.player.res = 3
  local hp = a.enemies[1].hp
  Combat.play(a, 1, 1)
  eq(hp - a.enemies[1].hp, 4 + 4 * 5); eq(a.player.res, 0)
  -- Truefaith Vestments : Absorb 4 quand un Cast se résout
  a = setup({ "holy_fire" }, { "test_dummy" })
  b = setup({ "holy_fire" }, { "test_dummy" }, nil, { relics = { "truefaith_vestments" } })
  Combat.play(a, 1, 1); Combat.play(b, 1, 1)
  Combat.endTurn(a); Combat.endTurn(b)
  assert(a.player.cast == nil and b.player.cast == nil, "incantations résolues")
  eq(b.player.block, a.player.block + 4, "Absorb de l'incantation résolue")
end)

test("bibelots et potions respectent le contrat", function()
  local nr, np = 0, 0
  for id, r in pairs(ns.Relics) do
    if not r.noPool and not r.class then nr = nr + 1 end -- communs (bibelots de rencontre et de classe à part)
    assert(r.name and r.text and r.hooks, id)
    assert(r.rarity == "common" or r.rarity == "uncommon" or r.rarity == "rare" or r.rarity == "boss", id)
    -- communs : palier de Ligue (tier) ; de classe : niveau de classe (test « progression »)
    if not r.class then assert(type(r.tier) == "number" and r.tier >= 0 and r.tier <= 3, id) end
  end
  for id, p in pairs(ns.Potions) do
    np = np + 1
    assert(p.name and p.text and p.rarity and p.effects and type(p.tier) == "number", id)
    for _, e in ipairs(p.effects) do assert(ns.Effects[e[1]], id .. " : " .. e[1]) end
  end
  -- 10 tirables d'origine + 19 de la fiche des bibelots communs (Traveler's Backpack laissé de côté)
  eq(nr, 29, "bibelots"); eq(np, 5, "potions")
  eq(#ns.Rewards.relicPool({ maxTier = 0 }), 8, "bibelots neutres hors boss")
  eq(#ns.Rewards.relicPool({ boss = true }), 3, "bibelots de boss")
  ns.Relics.test_class = { name = "x", text = "x", rarity = "rare", tier = 0, class = "priest", hooks = {} }
  ns.Relics.test_nopool = { name = "x", text = "x", rarity = "common", tier = 0, noPool = true, hooks = {} }
  eq(#ns.Rewards.relicPool({ maxTier = 0 }), 8, "bibelots de classe et noPool exclus des tirages")
  ns.Relics.test_class, ns.Relics.test_nopool = nil, nil
  local ch = ns.Rewards.relicChoices(Rng.new(3), 2, { maxTier = 3, exclude = { hearthstone = true } })
  eq(#ch, 2)
  for _, id in ipairs(ch) do assert(id ~= "hearthstone" and ns.Relics[id].rarity ~= "boss", id) end
  assert(ns.Potions[ns.Rewards.randomPotion(Rng.new(1), 0)].tier == 0)
end)

test("potion : bue sans mana, emplacement vidé, état relisible", function()
  local c = setup({ "smite" }, { "test_dummy" }, nil, { potions = { "healing_potion", false, "mana_potion" } })
  eq(#c.player.potions, 3)
  c.player.hp = 30
  eq(Combat.canUsePotion(c, 2), false, "emplacement vide")
  assert(Combat.usePotion(c, 1))
  eq(c.player.hp, 45); eq(c.player.mana, 3, "aucun mana dépensé")
  eq(c.player.potions[1], false)
  local ok, why = Combat.usePotion(c, 1)
  eq(ok, false, "déjà bue"); eq(why, "potion")
  assert(Combat.usePotion(c, 3))
  eq(c.player.mana, 5)
  eq(c.stats == nil, true)
end)

test("potion ciblée : il faut une cible vivante ; clone indépendant", function()
  local c = setup({}, { "test_dummy" }, nil, { potions = { "liquid_fire" } })
  local ok, why = Combat.canUsePotion(c, 1)
  eq(ok, false, "sans cible"); eq(why, "target")
  eq(#Combat.legalPotions(c), 1)
  local t = Combat.clone(c)
  assert(Combat.usePotion(t, 1, 1))
  eq(t.enemies[1].hp, 90); eq(t.enemies[1].st.pain, 3)
  eq(c.player.potions[1], "liquid_fire", "l'original garde sa potion")
end)

test("Pierre de foyer : fuite une fois par expédition, jamais contre un boss", function()
  local c = setup({}, { "test_dummy" })
  eq(Combat.canFlee(c), false, "sans bibelot")
  c = setup({}, { "test_dummy" }, nil, { relics = { "hearthstone" } })
  assert(Combat.flee(c))
  eq(c.result, "fled"); eq(c.charges.hearthstone_used, true)
  local d = setup({}, { "test_dummy" }, nil, { relics = { "hearthstone" }, charges = c.charges })
  eq(Combat.canFlee(d), false, "déjà utilisée")
  local b = setup({}, { "test_boss" }, nil, { relics = { "hearthstone" } })
  eq(Combat.canFlee(b), false, "boss")
end)

test("Bandage en lin : soigne 3 à la victoire", function()
  local c = setup({ "smite" }, { "test_dummy" }, nil, { relics = { "linen_bandage" } })
  c.player.hp = 40
  c.enemies[1].hp = 3
  Combat.play(c, 1, 1)
  eq(c.result, "won"); eq(c.player.hp, 43)
end)

test("Tabard de Hurlevent : 5 Absorption au premier tour seulement", function()
  local c = setup({}, { "test_dummy" }, nil, { relics = { "stormwind_tabard" } })
  eq(c.player.block, 5)
  Combat.endTurn(c)
  eq(c.player.block, 0)
end)

test("Bandeau de VanCleef : 4 mana par tour, ennemis Force 2", function()
  local deck = {}
  for i = 1, 14 do deck[i] = { id = "smite", up = false } end
  local c = Combat.new({ seed = 1, hp = 60, deck = deck, encounter = { "test_hitter" }, relics = { "vancleef_bandana" } })
  eq(#c.hand, 5); eq(c.player.mana, 4); eq(c.enemies[1].st.force, 2)
  Combat.endTurn(c)
  eq(c.player.mana, 4); eq(c.player.hp, 48)
end)

test("Insigne : retire les états négatifs une fois par combat", function()
  local c = setup({}, { "test_dummy" }, nil, { relics = { "faction_insignia" } })
  c.phase = "enemy"
  Combat.applyStatus(c, c.player, "armor_broken", 2)
  c.phase = "player"
  Combat.endTurn(c)
  eq(c.player.st.armor_broken, nil, "retirée")
  c.phase = "enemy"
  Combat.applyStatus(c, c.player, "demoralized", 2)
  c.phase = "player"
  Combat.endTurn(c)
  eq(c.player.st.demoralized, 2, "pas une deuxième fois")
end)

test("Pierre à aiguiser : +1 par coup d'attaque seulement", function()
  local c = setup({ "smite", "penance", "sw_pain" }, { "test_dummy" }, nil, { relics = { "sharpening_stone" } })
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 93)
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 93 - 3 * (num("penance", 1) + 1))
end)

test("Coup qui interrompt : coupe l'incantation s'il fait perdre des PV", function()
  local c = setup({ "holy_fire" }, { "test_pusher" })
  Combat.play(c, 1, 1)
  Combat.endTurn(c)
  eq(c.player.cast, nil); eq(c.enemies[1].hp, 100, "sort perdu")
  local d = setup({ "holy_fire", "pw_shield" }, { "test_pusher" })
  Combat.play(d, 1, 1)
  d.player.block = 10
  Combat.endTurn(d)
  eq(d.enemies[1].hp, 100 - num("holy_fire", 1), "absorbé : le sort passe")
  eq(Combat.intentInfo(d, d.enemies[1]).interrupts, true)
end)

test("Talisman de concentration : la première interruption est sans effet", function()
  local c = setup({ "holy_fire" }, { "test_watcher" }, nil, { relics = { "focus_talisman" } })
  Combat.play(c, 1, 1)
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 100 - num("holy_fire", 1))
end)

test("Rubis de mana : 4 mana au premier tour seulement", function()
  local deck = {}
  for i = 1, 12 do deck[i] = { id = "smite", up = false } end
  local c = Combat.new({ seed = 1, hp = 60, deck = deck, encounter = { "test_dummy" }, relics = { "mana_ruby" } })
  eq(c.player.mana, 4)
  Combat.endTurn(c)
  eq(c.player.mana, 3)
end)

test("Réconfort : +1 mana sous Expiation", function()
  local c = setup({ "radiance", "solace" })
  Combat.play(c, 1)
  Combat.play(c, 1, 1)
  eq(c.player.mana, 2); eq(c.enemies[1].hp, 100 - num("solace", 2))
end)

test("Mot de l'ombre : Mort : double sous la moitié des PV", function()
  local c = setup({ "sw_death", "sw_death" })
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 94)
  c.enemies[1].hp = 50
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 38)
end)

test("Éruption du Vide : base + bonus par Démence dépensée", function()
  local c = setup({ "void_eruption" })
  eq(Combat.canPlay(c, 1), false)
  c.player.res = 4
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - num("void_eruption", 2) - 4 * Card.defById("void_eruption").effects[2].per[1]); eq(c.player.res, 0)
end)

test("Apothéose : les incantations coûtent 1 de moins", function()
  local c = setup({ "apotheosis", "holy_fire", "smite" })
  Combat.play(c, 1)
  eq(Combat.cost(c, c.hand[1]), 1)
  eq(Combat.cost(c, c.hand[2]), 1)
end)

test("Extase : +2 à chaque gain d'Absorption", function()
  local c = setup({ "rapture", "inner_fire" })
  Combat.play(c, 1)
  Combat.play(c, 1)
  eq(c.player.block, num("inner_fire", 1) + 2)
end)

test("Guérison de l'ombre : soigne puis Douleur sur soi", function()
  local c = setup({ "shadow_mend" })
  c.player.hp = 30
  Combat.play(c, 1)
  eq(c.player.hp, 40); eq(c.player.st.pain, 2); eq(c.player.res, 1)
  Combat.endTurn(c)
  eq(c.player.hp, 38)
end)

test("Halo : incantation qui touche tous les ennemis", function()
  local c = setup({ "halo" }, { "test_dummy", "test_dummy" })
  Combat.play(c, 1)
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 100 - num("halo", 1)); eq(c.enemies[2].hp, 100 - num("halo", 1)); eq(c.player.st.regen, num("halo", 2, 3))
end)

test("Cri psychique et Incandescence : effets de zone", function()
  local c = setup({ "psychic_scream", "mind_sear" }, { "test_hitter", "test_hitter" })
  Combat.play(c, 1)
  Combat.play(c, 1)
  eq(c.enemies[2].st.demoralized, num("psychic_scream", 1, 3)); eq(c.enemies[2].st.pain, num("mind_sear", 1, 3))
  Combat.endTurn(c)
  eq(c.player.hp, 60 - 7 - 7, "coups réduits de 25 %")
  eq(c.enemies[2].st.demoralized, 1, "Démoralisé 2 posé à ton tour dure encore le tour suivant")
end)

test("cartes Consumées : Rénovation quitte le combat", function()
  local c = setup({ "renew" })
  Combat.play(c, 1)
  eq(#c.exhaust, 1); eq(c.player.st.regen, num("renew", 1, 3))
end)

test("Mystique : Guette coupe l'incantation, sinon frappe", function()
  local c = setup({ "holy_fire", "smite" }, { "mystic" })
  eq(c.enemies[1].intent, "watch", "incantation en main")
  Combat.play(c, 1, 1)
  Combat.endTurn(c)
  eq(c.player.hp, 60, "sort coupé, pas de coup")
  eq(c.player.cast, nil)
  local d = setup({ "holy_fire", "smite" }, { "mystic" })
  Combat.endTurn(d)
  eq(d.player.hp, 57, "rien à couper : 3 dégâts")
end)

test("VanCleef : le Coup de pied coupe, la Frappe mortelle non", function()
  local mv = ns.Enemies.vancleef.moves
  eq(mv.kick.actions[1].interrupts, true)
  eq(mv.strike.actions[1].interrupts, nil)
end)

test("Fouet mental : pioche 1 et +2 Démence si la cible a Douleur", function()
  local c = setup({ "sw_pain", "mind_flay" }, { "test_dummy" }, { "smite", "smite" })
  Combat.play(c, 1, 1)
  local before = #c.hand
  Combat.play(c, 1, 1)
  eq(#c.hand, before, "une carte jouée, une piochée")
  eq(c.player.res, 3)
end)

test("Apothéose : +1 mana par tour ; Forme d'ombre : +2 Démence", function()
  local c = setup({ "apotheosis", "shadowform", "holy_fire" }, { "test_dummy" }, { "smite", "smite", "smite", "smite",
    "smite", "smite", "smite", "smite" })
  c.player.mana = 4
  Combat.play(c, 1)
  Combat.play(c, 1)
  eq(c.player.res, 2)
  eq(Combat.cost(c, c.hand[handIndex(c, "holy_fire")]), 1)
  Combat.endTurn(c)
  eq(c.player.mana, 4)
end)

test("clone indépendant de l'original", function()
  local c = setup({ "smite", "smite" })
  local t = Combat.clone(c)
  Combat.play(t, 1, 1)
  eq(c.enemies[1].hp, 100)
  eq(#c.hand, 2)
end)

test("une expédition simulée est reproductible", function()
  local a = ns.Run.play({ seed = 3, bot = "greedy" })
  local b = ns.Run.play({ seed = 3, bot = "greedy" })
  eq(a.floor, b.floor); eq(a.hp, b.hp); eq(a.won, b.won)
end)

---------------------------------------------------------------------------
-- Socle multi-classes : grammaire commune, points d'extension, Warrior
---------------------------------------------------------------------------

local W = { class = "warrior" } -- options de Combat.new pour un combat de Guerrier

test("DoT : l'état pain s'affiche « DoT » (nom, textes), l'id interne reste pain", function()
  eq(ns.Statuses.pain.name, "DoT")
  for id, d in pairs(ns.Cards) do
    for _, up in ipairs({ false, true }) do
      local t = Card.defById(id, up).text or ""
      assert(not t:find("Pain", 1, true) or t:find("SW: Pain", 1, true) or t:find("Ignore Pain", 1, true), id .. " : « Pain »")
    end
  end
  for id, r in pairs(ns.Relics) do assert(not r.text:find("Pain ", 1, true), id) end
end)

test("DoT : icône selon la source gardée à part (unit.stIcon), règle inchangée, clonée", function()
  local c = setup({ "rend" }, nil, nil, W)
  Combat.play(c, 1, 1)
  eq(c.enemies[1].st.pain, num("rend", 2, 3)); eq(c.enemies[1].stIcon.pain, "bleed")
  local t = Combat.clone(c)
  t.enemies[1].stIcon.pain = "poison"
  eq(c.enemies[1].stIcon.pain, "bleed")
end)

test("classe : Combat.new connaît sa classe, état de classe et ressource ; classe inconnue refusée", function()
  local c = setup({ "smite" })
  eq(c.class, "priest"); eq(c.player.res, 0); eq(type(c.cls), "table")
  local w = setup({ "strike" }, nil, nil, W)
  eq(w.class, "warrior"); eq(w.cls.hurt, false)
  assert(not pcall(Combat.new, { class = "nope", hp = 10, deck = {}, encounter = {} }))
end)

test("ressource : plafond de la classe, Insanity sans plafond", function()
  local w = setup({ "strike" }, nil, nil, W)
  eq(Combat.gainRes(w, 9), 5); eq(w.player.res, 5)
  eq(Combat.gainRes(w, -9), -5); eq(w.player.res, 0)
  local c = setup({ "smite" })
  Combat.gainRes(c, 40); eq(c.player.res, 40)
end)

test("Rage : +1 par carte Attack jouée, rien pour une carte Skill", function()
  local c = setup({ "strike", "defend" }, nil, nil, W)
  Combat.play(c, 1, 1)
  eq(c.player.res, 1)
  Combat.play(c, 1)
  eq(c.player.res, 1)
end)

test("Rage : +1 par coup qui fait perdre des PV, rien si tout est absorbé ; gardée d'un tour à l'autre", function()
  local c = setup({ "strike" }, { "test_hitter" }, nil, W)
  Combat.endTurn(c)
  eq(c.player.res, 1, "coup de 10 reçu")
  c.player.block = 50
  c.player.mana = 0
  Combat.endPlayerTurn(c); Combat.enemyPhase(c)
  eq(c.player.res, 1, "coup absorbé")
  Combat.endRound(c); Combat.startPlayerTurn(c)
  eq(c.player.res, 1, "gardée au tour suivant")
end)

test("Rage : bibelot de départ Battle Standard (+1 au début du combat)", function()
  local c = setup({ "strike" }, nil, nil, { class = "warrior", relics = { "battle_standard" } })
  eq(c.player.res, 1)
end)

test("Spend N : payé au jeu si la ressource suffit, bonus à la résolution, sinon la carte se joue sans", function()
  local d = Card.defById("heroic_strike")
  local base, bonus = d.effects[1][2], d.effects[1].more[1][1]
  local c = setup({ "heroic_strike" }, nil, nil, W)
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - base, "sans Rage"); eq(c.player.res, 1)
  local c2 = setup({ "heroic_strike" }, nil, nil, W)
  c2.player.res = 3
  Combat.play(c2, 1, 1)
  eq(c2.enemies[1].hp, 100 - base - bonus); eq(c2.player.res, 3 - d.spend + 1)
end)

test("Spend N d'une carte Cast : payé au jeu, gardé dans l'incantation, rien rendu si elle est coupée", function()
  ns.Cards.test_spend_cast = { id = "test_spend_cast", class = "warrior", name = "x", cost = 0, type = "attack",
    rarity = "common", target = "enemy", cast = true, spend = 2, text = "Cast.\nDeal 5.\nSpend 2: deal 10 more.",
    effects = { { "damage", 5, more = { { 10, "spent" } } } } }
  local c = setup({ "test_spend_cast" }, nil, nil, W)
  c.player.res = 2
  Combat.play(c, 1, 1)
  eq(c.player.res, 0, "payé au jeu"); eq(c.player.cast.spent, true)
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 85, "bonus à la résolution")
  local i = setup({ "test_spend_cast" }, { "test_pusher" }, nil, W)
  i.player.res = 2
  Combat.play(i, 1, 1)
  Combat.endTurn(i)
  eq(i.enemies[1].hp, 100, "coupée"); eq(i.player.res, 1, "rien rendu (+1 du coup reçu)")
  ns.Cards.test_spend_cast = nil
end)

test("Surge générique : dépense toute la ressource (Ignore Pain), injouable à 0 (minRes)", function()
  local c = setup({ "ignore_pain" }, nil, nil, W)
  eq(select(2, Combat.canPlay(c, 1)), "resource")
  c.player.res = 3
  Combat.play(c, 1)
  eq(c.player.res, 0); eq(c.player.block, 3 * Card.defById("ignore_pain").effects[2].per[1])
end)

test("Execute : Surge seulement sur une cible à la moitié de ses PV ou moins", function()
  local d = Card.defById("execute")
  local base, per = d.effects[2][2], d.effects[2].per[1]
  local c = setup({ "execute" }, nil, nil, W)
  c.player.res = 3
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - base, "cible intacte : pas de Surge"); eq(c.player.res, 4)
  local e = setup({ "execute" }, nil, nil, W)
  e.player.res = 3
  e.enemies[1].hp = 50
  Combat.play(e, 1, 1)
  eq(e.enemies[1].hp, 50 - base - 3 * per); eq(e.player.res, 1, "vidée puis +1 (Attack)")
end)

test("Pay N HP : payé au jeu, sans Absorb, compte comme une perte de PV (Rage), jamais mortel", function()
  local c = setup({ "bloodrage", "bloodrage" }, nil, { "strike", "strike", "strike" }, W)
  c.player.block = 20
  local hp, hand = c.player.hp, #c.hand
  local pay = Card.defById("bloodrage").payHp
  Combat.play(c, 1)
  eq(c.player.hp, hp - pay); eq(c.player.block, 20)
  eq(c.player.res, 3, "+2 Rage et +1 pour la perte de PV"); eq(#c.hand, hand - 1 + 1)
  c.player.hp = pay
  eq(select(2, Combat.canPlay(c, handIndex(c, "bloodrage"))), "hp")
  c.player.hp = pay + 1
  assert(Combat.canPlay(c, handIndex(c, "bloodrage")))
end)

test("Pay N HP : crochet payHp (coût modifiable), événement onPayHp", function()
  ns.ClassRules.warrior.hooks.payHp = function(c, cls, v) return v - 1 end
  local paid
  ns.ClassRules.warrior.hooks.onPayHp = function(c, cls, n) paid = n end
  local c = setup({ "bloodrage" }, nil, nil, W)
  local hp = c.player.hp
  Combat.play(c, 1)
  ns.ClassRules.warrior.hooks.payHp, ns.ClassRules.warrior.hooks.onPayHp = nil, nil
  local pay = Card.defById("bloodrage").payHp - 1
  eq(c.player.hp, hp - pay); eq(paid, pay)
end)

test("Revenge : coûte 0 seulement après une perte de PV au tour précédent ; Retain", function()
  local c = setup({ "revenge" }, { "test_hitter" }, nil, W)
  eq(Combat.cost(c, c.hand[1]), 1)
  Combat.endTurn(c)
  eq(Combat.cost(c, c.hand[handIndex(c, "revenge")]), 0, "frappé au tour ennemi")
  c.player.block = 50
  Combat.endTurn(c)
  eq(Combat.cost(c, c.hand[handIndex(c, "revenge")]), 1, "tout absorbé")
end)

test("Enrage : Strength 1 par perte de PV, une fois par tour", function()
  local c = setup({ "enrage", "bloodrage", "bloodrage" }, nil, nil, W)
  Combat.play(c, 1)
  Combat.play(c, 1)
  Combat.play(c, 1)
  eq(c.player.st.force, 1)
end)

test("Shield Slam : dégâts égaux à l'Absorb ; Retaliation : riposte même sur un coup absorbé", function()
  local c = setup({ "shield_slam" }, nil, nil, W)
  c.player.block = 13
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - 13 - num("shield_slam", 1))
  local r = setup({ "retaliation" }, { "test_hitter" }, nil, W)
  Combat.play(r, 1)
  r.player.block = 50
  Combat.endTurn(r)
  eq(r.enemies[1].hp, 96)
end)

test("Last Stand : Last Breath, reste à 1 PV puis soin, une fois", function()
  local c = setup({ "last_stand" }, { "test_hitter" }, nil, W)
  Combat.play(c, 1)
  c.player.hp = 5
  Combat.endTurn(c)
  eq(c.result, nil); eq(c.player.hp, 16)
  c.player.hp = 5
  Combat.endTurn(c)
  eq(c.result, "lost")
end)

test("Warrior : chaque carte (base et améliorée) jouable sans erreur, texte et effets cohérents", function()
  local n = 0
  for id, d0 in pairs(ns.Cards) do
    if d0.class == "warrior" then
      for _, up in ipairs({ false, true }) do
        local c = setup({ id }, { "test_dummy", "test_caster" }, { "strike", "strike", "strike", "strike" },
          { class = "warrior", hp = 60 })
        c.player.mana, c.player.res = 9, 5
        c.hand[1] = Card.new(id, up, 999)
        c.player.block = 4
        c.enemies[1].hp = 40
        local ok, why = Combat.play(c, 1, 1)
        assert(ok, id .. (up and "+" or "") .. " : " .. tostring(why))
        Combat.endTurn(c)
        Combat.endTurn(c)
        n = n + 1
      end
    end
  end
  eq(n, 68)
end)

test("Warrior : 34 cartes (4 de départ, 13/11/6), 10 par voie, 6 bibelots de classe, Interrupt et Last Breath", function()
  local r, paths, nInt, nLb = {}, {}, 0, 0
  for id, d in pairs(ns.Cards) do
    if d.class == "warrior" then
      r[d.rarity] = (r[d.rarity] or 0) + 1
      paths[d.path] = (paths[d.path] or 0) + 1
      for _, e in ipairs(d.effects) do if e[1] == "interrupt" then nInt = nInt + 1 end end
      if d.hooks and d.hooks.preventDeath then nLb = nLb + 1 end
    end
  end
  eq(r.basic, 4); eq(r.common, 13); eq(r.uncommon, 11); eq(r.rare, 6)
  eq(paths.start, 4); eq(paths.arms, 10); eq(paths.fury, 10); eq(paths.protection, 10)
  assert(nInt >= 1 and nLb >= 1)
  local nr = 0
  for _, rel in pairs(ns.Relics) do if rel.class == "warrior" then nr = nr + 1 end end
  eq(nr, 6)
  local cd = ns.Classes.warrior
  eq(#cd.deck, 10); eq(cd.resource.cap, 5); eq(cd.resource.keep, true); eq(cd.startRelic, "battle_standard")
  eq(ns.Relics.battle_standard.noPool, true)
end)

test("points d'extension : carte engagée et compteurs du tour (type, école), remis à 0 au tour suivant", function()
  local seen = {}
  ns.ClassRules.warrior.hooks.onCardCommitted = function(c, cls, inst, d) seen[#seen + 1] = inst.id .. ":" .. c.turn.played end
  local c = setup({ "strike", "slam" }, nil, nil, W)
  Combat.play(c, 1, 1)
  Combat.play(c, 1, 1)
  ns.ClassRules.warrior.hooks.onCardCommitted = nil
  eq(seen[1], "strike:1"); eq(seen[2], "slam:2", "carte Cast engagée au jeu")
  eq(c.turn.byType.attack, 2)
  local p = setup({ "smite", "mind_flay" })
  Combat.play(p, 1, 1)
  Combat.play(p, 1, 1)
  eq(p.turn.bySchool.holy, 1); eq(p.turn.bySchool.shadow, 1)
  Combat.endTurn(p)
  eq(p.turn.played, 0)
  eq(Combat.test(p, { def = Card.defById("smite") }, "school:holy"), true)
end)

test("points d'extension : file d'incantations (castSlots), résolue dans l'ordre, interruption de la plus récente", function()
  ns.ClassRules.warrior.hooks.castSlots = function(c, cls, v) return 2 end
  local c = setup({ "slam", "slam" }, nil, nil, W)
  c.player.mana = 2
  Combat.play(c, 1, 1)
  Combat.play(c, 1, 1)
  eq(Combat.castCount(c), 2)
  Combat.interruptPlayer(c, c.enemies[1])
  eq(Combat.castCount(c), 1); assert(c.player.cast ~= nil and c.player.castMore == nil, "la plus ancienne reste")
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 100 - num("slam", 1))
  ns.ClassRules.warrior.hooks.castSlots = nil
end)

test("points d'extension : instantCast (sans consommer quand commit est faux)", function()
  local asked = {}
  ns.ClassRules.warrior.hooks.instantCast = function(c, cls, v, d, inst, commit) asked[#asked + 1] = commit return true end
  local c = setup({ "slam" }, nil, nil, W)
  Combat.play(c, 1, 1)
  ns.ClassRules.warrior.hooks.instantCast = nil
  eq(c.player.cast, nil); eq(c.enemies[1].hp, 100 - num("slam", 1))
  eq(asked[#asked], true)
end)

test("points d'extension : mana remis avant la résolution des incantations (Evocation)", function()
  ns.Cards.test_evocation = { id = "test_evocation", name = "x", cost = 0, type = "skill", rarity = "common",
    cast = true, effects = { { "mana", 3 } }, text = "Cast.\n+3 mana." }
  local c = setup({ "test_evocation" })
  Combat.play(c, 1)
  Combat.endTurn(c)
  eq(c.player.mana, Combat.BASE_MANA + 3)
  ns.Cards.test_evocation = nil
end)

test("points d'extension : Power unique par emplacement (remplacé), Power à durée (retiré)", function()
  ns.Cards.test_seal_a = { id = "test_seal_a", name = "a", cost = 0, type = "power", power = true, slot = "seal",
    rarity = "common", effects = {}, text = "Power." }
  ns.Cards.test_seal_b = { id = "test_seal_b", name = "b", cost = 0, type = "power", power = true, slot = "seal",
    rarity = "common", effects = {}, text = "Power.", replacedTo = "exhaust" }
  ns.Cards.test_totem = { id = "test_totem", name = "t", cost = 0, type = "power", power = true, slot = "fire",
    lasts = 2, rarity = "common", effects = {}, text = "Power." }
  local c = setup({ "test_seal_b", "test_seal_a", "test_totem" })
  Combat.play(c, 1)
  Combat.play(c, 1)
  eq(#c.player.powers, 1); eq(c.player.powers[1].id, "test_seal_a"); eq(c.exhaust[1].id, "test_seal_b")
  Combat.play(c, 1)
  eq(#c.player.powers, 2)
  local t = Combat.clone(c)
  Combat.endTurn(c)
  eq(#c.player.powers, 2, "1 round : encore là")
  Combat.endTurn(c)
  eq(#c.player.powers, 1, "2 rounds : retiré")
  local back = false
  for _, pile in ipairs({ c.hand, c.draw, c.discard }) do
    for _, x in ipairs(pile) do if x.id == "test_totem" then back = true end end
  end
  assert(back, "le totem expiré revient dans les piles")
  eq(t.player.powerTurns[t.player.powers[2].uid], 2, "clone indépendant")
  ns.Cards.test_seal_a, ns.Cards.test_seal_b, ns.Cards.test_totem = nil, nil, nil
end)

test("points d'extension : beforeHit (Parry) annule un coup, afterHit voit le coup, dotDecay", function()
  local hits = 0
  ns.ClassRules.warrior.hooks.beforeHit = function(c, cls, dmg) return 0 end
  ns.ClassRules.warrior.hooks.afterHit = function(c, cls, e, loss) hits = hits + 1 end
  ns.ClassRules.warrior.hooks.dotDecay = function(c, cls, v, unit) return unit.side == "enemy" and 0 or v end
  local c = setup({ "rend" }, { "test_hitter" }, nil, W)
  local hp = c.player.hp
  Combat.play(c, 1, 1)
  Combat.endTurn(c)
  Combat.endTurn(c)
  ns.ClassRules.warrior.hooks.beforeHit, ns.ClassRules.warrior.hooks.afterHit, ns.ClassRules.warrior.hooks.dotDecay = nil, nil, nil
  eq(c.player.hp, hp); eq(hits, 2)
  eq(c.enemies[1].st.pain, num("rend", 2, 3), "DoT qui ne baisse plus")
end)

test("points d'extension : dernière cible gardée, état de classe cloné en profondeur", function()
  local c = setup({ "strike" }, { "test_dummy", "test_dummy" }, nil, W)
  Combat.play(c, 1, 2)
  eq(c.player.lastTarget, c.enemies[2].uid)
  c.cls.deep = { n = 1 }
  local t = Combat.clone(c)
  t.cls.deep.n = 2
  eq(c.cls.deep.n, 1)
end)

test("Warrior : combats simulés par le bot heuristique, sans erreur", function()
  local r = ns.Run.play({ seed = 4, bot = "heuristic", class = "warrior", cap = 120 })
  assert(r.combats[1] ~= nil)
end)

test("Spend N au choix : opts.spend = false joue sans dépenser ; coups légaux en double ; action « nospend »", function()
  local d = Card.defById("heroic_strike")
  local c = setup({ "heroic_strike" }, nil, nil, W)
  c.player.res = 3
  local n, nos = 0, 0
  for _, a in ipairs(Combat.legalPlays(c)) do
    if a[1] == 1 then n = n + 1 if a[3] then nos = nos + 1 end end
  end
  eq(n, 2); eq(nos, 1)
  Combat.play(c, 1, 1, { spend = false })
  eq(c.player.res, 4, "rien dépensé (+1 Attack)"); eq(c.enemies[1].hp, 100 - d.effects[1][2])
  local p = setup({ "heroic_strike" }, nil, nil, W)
  local nn = 0
  for _, a in ipairs(Combat.legalPlays(p)) do if a[1] == 1 then nn = nn + 1 end end
  eq(nn, 1, "sans ressource : une seule façon de jouer")
end)

test("Surge à 0 : une carte dont le seul effet est Surge est injouable, une autre se joue et son Surge ne fait rien", function()
  local ip = setup({ "ignore_pain" }, nil, nil, W)
  eq(select(2, Combat.canPlay(ip, 1)), "resource")
  local ex = setup({ "execute" }, nil, nil, W)
  ex.enemies[1].hp = 40
  assert(Combat.canPlay(ex, 1))
  Combat.play(ex, 1, 1)
  eq(ex.enemies[1].hp, 40 - Card.defById("execute").effects[2][2])
end)

test("Instant (état commun) : la carte Cast se résout tout de suite, sans emplacement, une charge consommée", function()
  local c = setup({ "holy_fire", "holy_fire" })
  c.player.mana = 4
  Combat.applyStatus(c, c.player, "instant", 1)
  Combat.play(c, 1, 1)
  eq(c.player.cast, nil); eq(c.enemies[1].hp, 100 - num("holy_fire", 1) - 3 * 0)
  eq(c.player.st.instant, nil)
  Combat.play(c, 1, 1)
  assert(c.player.cast ~= nil, "la suivante incante")
  local d = setup({ "holy_fire", "holy_fire" })
  d.player.mana = 4
  Combat.play(d, 1, 1)
  eq(select(2, Combat.canPlay(d, 1)), "casting")
  Combat.applyStatus(d, d.player, "instant", 2)
  assert(Combat.canPlay(d, 1), "Instant : jouable malgré l'incantation en cours")
end)

test("Trap : posée au jeu, déclenchée à la prochaine attaque ennemie sur l'attaquant, 3 au plus", function()
  ns.Cards.test_trap = { id = "test_trap", name = "t", cost = 0, type = "skill", trap = true, rarity = "common",
    effects = { { "damage", 7 }, { "apply", "stunned", 1 } }, text = "Trap.\nDeal 7.\nApply Stunned 1 ⌛" }
  local c = setup({ "test_trap", "test_trap", "test_trap", "test_trap" }, { "test_dummy", "test_hitter" })
  Combat.play(c, 1)
  eq(#c.traps, 1); eq(c.enemies[2].hp, 100)
  Combat.play(c, 1); Combat.play(c, 1)
  eq(select(2, Combat.canPlay(c, 1)), "traps")
  local hp = c.player.hp
  Combat.endTurn(c)
  eq(#c.traps, 2, "une seule déclenchée (une attaque)"); eq(c.enemies[1].hp, 100, "pas sur l'ennemi passif")
  eq(c.enemies[2].hp, 93); eq(c.player.hp, hp, "étourdi pendant son tour : l'attaque n'a pas lieu")
  eq(c.enemies[2].st.stunned, nil, "charge consommée par ce tour-là")
  local t = Combat.clone(c)
  table.remove(t.traps)
  eq(#c.traps, 2, "clone indépendant")
  ns.Cards.test_trap = nil
end)

test("DoT déclenché tout de suite (effet tickDot), état plafonné (max) et à drapeau (flag)", function()
  ns.Cards.test_envenom = { id = "test_envenom", name = "e", cost = 0, type = "attack", target = "enemy",
    rarity = "common", effects = { { "tickDot" } }, text = "Trigger the target's DoT." }
  local c = setup({ "sw_pain", "test_envenom" })
  Combat.play(c, 1, 1)
  local dot = c.enemies[1].st.pain
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - dot); eq(c.enemies[1].st.pain, dot - 1)
  ns.Cards.test_envenom = nil
  ns.Statuses.test_parry = { name = "Testparry", max = 3 }
  ns.Statuses.test_stealth = { name = "Teststealth", flag = true }
  Combat.applyStatus(c, c.player, "test_parry", 5)
  Combat.applyStatus(c, c.player, "test_stealth", 1)
  Combat.applyStatus(c, c.player, "test_stealth", 1)
  eq(c.player.st.test_parry, 3); eq(c.player.st.test_stealth, 1)
  ns.Statuses.test_parry, ns.Statuses.test_stealth = nil, nil
  c.player.st.test_parry, c.player.st.test_stealth = nil, nil
end)

test("tour ennemi sauté (drapeau skipEnemyTurn), Interrupt de tous, onAttackHit et onSurge", function()
  local c = setup({ "smite" }, { "test_hitter" })
  local hp = c.player.hp
  c.player.flags.skipEnemyTurn = true
  Combat.endTurn(c)
  eq(c.player.hp, hp); eq(c.player.flags.skipEnemyTurn, nil)
  ns.Cards.test_kick_all = { id = "test_kick_all", name = "k", cost = 0, type = "skill", rarity = "common",
    effects = { { "interrupt", all = true } }, text = "Interrupt all casts." }
  local k = setup({ "test_kick_all" }, { "test_caster", "test_caster" })
  Combat.play(k, 1)
  assert(k.enemies[1].interrupted and k.enemies[2].interrupted)
  ns.Cards.test_kick_all = nil
  local hits, surged = 0, 0
  ns.ClassRules.warrior.hooks.onAttackHit = function() hits = hits + 1 end
  ns.ClassRules.warrior.hooks.onSurge = function(cc, cls, n) surged = n end
  local w = setup({ "raging_blow", "ignore_pain" }, nil, nil, W)
  Combat.play(w, 1, 1)
  w.player.res = 4
  Combat.play(w, 1)
  ns.ClassRules.warrior.hooks.onAttackHit, ns.ClassRules.warrior.hooks.onSurge = nil, nil
  eq(hits, 2); eq(surged, 4)
end)

---------------------------------------------------------------------------
-- Rogue : Combo, Parry, Stealth, effets du DoT, cartes et bibelots (docs/classes/rogue.md)
---------------------------------------------------------------------------

local RO = { class = "rogue" } -- options de Combat.new pour un combat de Voleur
ns.Enemies.test_big = { name = "Fracas", hp = 100,
  moves = { smash = { name = "Fracas", intent = "attack", actions = { { "attack", 18 } } } }, pattern = { "smash" } }
ns.Enemies.test_triple = { name = "Moisson", hp = 100,
  moves = { reap = { name = "Moisson", intent = "attack", actions = { { "attack", 8, times = 3 } } } }, pattern = { "reap" } }
ns.Enemies.test_poke = { name = "Piqûre", hp = 100,
  moves = { poke = { name = "Piqûre", intent = "attack", actions = { { "attack", 6, interrupts = true } } } },
  pattern = { "poke" } }
ns.Enemies.test_weak = { name = "Chiquenaude", hp = 100,
  moves = { tap = { name = "Rien", intent = "attack", actions = { { "attack", 0 } } } }, pattern = { "tap" } }

-- Ennemi n° i à hp PV (tests de dégâts lisibles).
local function hpOf(c, i) return c.enemies[i or 1].hp end

test("Rogue : 34 cartes (4 de départ, 13/11/6), 10 par voie, niveau 1 à 7 sur tout, 6 bibelots, Kick et Cheat Death", function()
  local r, paths, nInt, nLb, lv = {}, {}, 0, 0, {}
  for id, d in pairs(ns.Cards) do
    if d.class == "rogue" then
      r[d.rarity] = (r[d.rarity] or 0) + 1
      paths[d.path] = (paths[d.path] or 0) + 1
      assert(type(d.level) == "number" and d.level >= 1 and d.level <= 7, id .. " : level")
      lv[d.level] = (lv[d.level] or 0) + 1
      for _, e in ipairs(d.effects) do if e[1] == "interrupt" then nInt = nInt + 1 end end
      if d.hooks and d.hooks.preventDeath then nLb = nLb + 1 end
    end
  end
  eq(r.basic, 4); eq(r.common, 13); eq(r.uncommon, 11); eq(r.rare, 6)
  eq(paths.start, 4); eq(paths.assassination, 10); eq(paths.combat, 10); eq(paths.subtlety, 10)
  eq(lv[1], 22, "niveau 1 : 18 + 4 de départ"); eq(lv[2], 3); eq(lv[4], 3); eq(lv[6], 3); eq(lv[7], 3)
  eq(nInt, 1); eq(nLb, 1)
  local nr = 0
  for id, rel in pairs(ns.Relics) do
    if rel.class == "rogue" then
      nr = nr + 1
      assert(type(rel.level) == "number" and rel.level >= 1 and rel.level <= 7, id .. " : level")
    end
  end
  eq(nr, 6)
  local cd = ns.Classes.rogue
  eq(#cd.deck, 10); eq(cd.resource.id, "combo"); eq(cd.resource.cap, 5); eq(cd.resource.keep, true)
  eq(cd.startRelic, "thieves_tools"); eq(ns.Relics.thieves_tools.noPool, true); eq(cd.hp, 49)
  eq(Card.defById("kick").cost, 0)
end)

test("Combo : plafond 5, gardés d'un tour à l'autre, 0 au début du combat", function()
  local c = setup({ "sinister_strike" }, nil, nil, RO)
  eq(c.player.res, 0)
  Combat.gainRes(c, 4)
  Combat.play(c, 1, 1)
  eq(c.player.res, 5)
  eq(Combat.gainRes(c, 3), 0, "au-delà de 5 : perdu")
  Combat.endTurn(c)
  eq(c.player.res, 5, "gardés")
end)

test("Parry : un coup paré jusqu'à 8, le reste passe ; charges gardées d'un tour à l'autre, 3 au plus", function()
  local c = setup({ "feint", "feint", "feint", "feint" }, { "test_hitter" }, nil, RO)
  c.player.mana = 4
  for _ = 1, 4 do Combat.play(c, 1) end
  eq(c.player.st.parry, 3, "plafond 3")
  local hp = c.player.hp
  Combat.endTurn(c)
  eq(c.player.hp, hp - 2, "coup de 10 : 8 parés, 2 passent"); eq(c.player.st.parry, 2)
  local k = setup({ "feint" }, { "test_dummy" }, nil, RO)
  Combat.play(k, 1)
  Combat.endTurn(k); Combat.endTurn(k)
  eq(k.player.st.parry, 1, "gardée sans coup reçu")
end)

test("Parry : avant l'Absorb (Fracas 18, Parry 1, 5 Absorb : 8 parés, 5 absorbés, 5 PV)", function()
  local c = setup({ "feint" }, { "test_big" }, nil, RO)
  Combat.play(c, 1)
  c.player.block = 5
  local hp = c.player.hp
  Combat.endPlayerTurn(c); Combat.enemyPhase(c)
  eq(c.player.hp, hp - 5); eq(c.player.block, 0); eq(c.player.st.parry, nil)
  local stopped
  for _, ev in ipairs(c.events) do if ev.t == "parry" then stopped = ev.prevented end end
  eq(stopped, 8, "événement parry")
end)

test("Parry : une charge par coup (Moisson 8 × 3, Parry 2 : le troisième touche), coup de 0 ignoré", function()
  local c = setup({ "evasion" }, { "test_triple" }, nil, RO)
  Combat.play(c, 1)
  local hp = c.player.hp
  Combat.endPlayerTurn(c); Combat.enemyPhase(c)
  eq(c.player.hp, hp - 8); eq(c.player.st.parry, nil)
  local z = setup({ "feint" }, { "test_weak" }, nil, RO)
  Combat.play(z, 1)
  Combat.endTurn(z)
  eq(z.player.st.parry, 1, "coup de 0 : aucune charge")
end)

test("Parry : jamais contre le DoT ; un coup entièrement paré ne coupe pas l'incantation", function()
  local c = setup({ "feint" }, nil, nil, RO)
  Combat.play(c, 1)
  c.player.st.pain = 5
  local hp = c.player.hp
  Combat.endTurn(c)
  eq(c.player.hp, hp - 5, "DoT subi"); eq(c.player.st.parry, 1)
  local i = setup({ "feint", "slam" }, { "test_poke" }, nil, RO)
  Combat.play(i, 1)
  Combat.play(i, 1, 1)
  assert(i.player.cast ~= nil)
  Combat.endTurn(i)
  eq(hpOf(i), 100 - num("slam", 1), "coup paré : l'incantation part")
end)

test("Stealth : posé au début du combat, sans nombre ; ne s'empile pas", function()
  local c = setup({ "vanish", "vanish" }, nil, { "sinister_strike", "sinister_strike" }, RO)
  eq(c.player.st.stealth, 1)
  assert(ns.Statuses.stealth.flag and ns.Statuses.parry.max == 3)
  Combat.play(c, 1)
  eq(c.player.st.stealth, 1, "déjà caché : rien")
end)

test("Stealth : consommé par la première Attack (même sans ligne Stealth:), son bonus à la résolution", function()
  local d = Card.defById("backstab")
  local base, bonus = d.effects[1][2], d.effects[1].more[1][1]
  local c = setup({ "backstab", "backstab" }, nil, nil, RO)
  Combat.play(c, 1, 1)
  eq(hpOf(c), 100 - base - bonus, "Backstab caché"); eq(c.player.st.stealth, nil)
  Combat.play(c, 1, 1)
  eq(hpOf(c), 100 - 2 * base - bonus, "la seconde sans bonus")
  local s = setup({ "sinister_strike", "backstab" }, nil, nil, RO)
  Combat.play(s, 1, 1)
  eq(s.player.st.stealth, nil, "Sinister Strike consomme")
  Combat.play(s, 1, 1)
  eq(hpOf(s), 100 - num("sinister_strike", 1) - base)
  eq(next(s.cls.openers), nil, "rien ne reste après la résolution")
end)

test("Stealth : lu sans être consommé par les Skills (Premeditation, Cheap Shot), puis Ambush", function()
  local c = setup({ "premeditation", "cheap_shot", "ambush" }, nil, { "feint", "feint" }, RO)
  c.player.mana = 4
  Combat.play(c, 1)
  eq(c.player.res, 2); eq(c.player.st.stealth, 1)
  Combat.play(c, 1, 1)
  eq(c.player.res, 4); eq(c.enemies[1].st.stunned, 1); eq(c.player.st.stealth, 1)
  Combat.play(c, handIndex(c, "ambush"), 1)
  local d = Card.defById("ambush")
  eq(hpOf(c), 100 - d.effects[1][2] - d.effects[1].more[1][1]); eq(c.player.res, 5); eq(c.player.st.stealth, nil)
  local n = setup({ "sinister_strike", "premeditation", "cheap_shot" }, nil, nil, RO)
  Combat.play(n, 1, 1)
  Combat.play(n, 1)
  eq(n.player.res, 1, "Premeditation sans Stealth")
  Combat.play(n, 1, 1)
  eq(n.enemies[1].st.stunned, nil, "Cheap Shot sans Stealth : pas d'étourdissement")
end)

test("Stealth : rendu par Vanish et Shadowstep ; Flash Powder seulement sur un gain réel par une carte", function()
  local c = setup({ "sinister_strike", "vanish", "shadowstep", "vanish" }, nil, { "feint", "feint", "feint" },
    { class = "rogue", relics = { "flash_powder" } })
  c.player.mana = 5
  local hand = #c.hand
  eq(hand, 4, "Stealth du début de combat : pas de pioche")
  Combat.play(c, 1, 1)
  Combat.play(c, 1)
  eq(c.player.st.stealth, 1); eq(#c.hand, 2 + 1 + 1, "Vanish : pioche 1, Flash Powder 1")
  Combat.play(c, handIndex(c, "shadowstep"))
  eq(#c.hand, 3, "déjà caché : pas de Flash Powder"); eq(c.player.st.parry, 1)
end)

test("Stealth : une Attack en Cast le consomme au jeu et garde le bonus pour sa résolution", function()
  ns.Cards.test_cast_stealth = { id = "test_cast_stealth", name = "x", cost = 0, type = "attack", rarity = "common",
    target = "enemy", cast = true, effects = { { "damage", 5, more = { { 10, "stealth" } } } },
    text = "Cast.\nDeal 5.\nStealth: deal 10 more." }
  local c = setup({ "test_cast_stealth" }, nil, nil, RO)
  Combat.play(c, 1, 1)
  eq(c.player.st.stealth, nil)
  Combat.endTurn(c)
  eq(hpOf(c), 85)
  ns.Cards.test_cast_stealth = nil
end)

test("Surge à 0 : Eviscerate, Rupture, Exsanguinate injouables ; Envenom, Secret Technique, Between the Eyes jouables", function()
  for _, id in ipairs({ "eviscerate", "rupture", "exsanguinate" }) do
    local c = setup({ id }, nil, nil, RO)
    eq(select(2, Combat.canPlay(c, 1)), "resource", id)
  end
  local e = setup({ "envenom" }, nil, nil, RO)
  e.enemies[1].st.pain = 4
  Combat.play(e, 1, 1)
  eq(hpOf(e), 96, "Envenom à 0 : éclate seulement"); eq(e.enemies[1].st.pain, 3)
  local s = setup({ "secret_technique" }, nil, nil, RO)
  assert(Combat.canPlay(s, 1))
  local b = setup({ "between_the_eyes" }, nil, nil, RO)
  Combat.play(b, 1, 1)
  eq(hpOf(b), 100); eq(b.enemies[1].st.stunned, 1)
end)

test("Eviscerate : 4 + 4 par point ; Between the Eyes : 4 par point et Stunned", function()
  local ev, evu = Card.defById("eviscerate").effects[2], Card.defById("eviscerate", true).effects[2]
  local c = setup({ "eviscerate" }, nil, nil, RO)
  c.player.res = 4
  Combat.play(c, 1, 1)
  eq(hpOf(c), 100 - ev[2] - ev.per[1] * 4); eq(c.player.res, 0)
  local u = setup({ "eviscerate" }, nil, nil, RO)
  u.hand[1] = Card.new("eviscerate", true, 999)
  u.player.res = 5
  Combat.play(u, 1, 1)
  eq(hpOf(u), 100 - evu[2] - evu.per[1] * 5)
  local b = setup({ "between_the_eyes" }, nil, nil, RO)
  b.player.res = 3
  Combat.play(b, 1, 1)
  eq(hpOf(b), 100 - 12); eq(b.enemies[1].st.stunned, 1)
end)

test("Envenom : DoT par point puis éclate tout de suite ; Rupture : DoT par point", function()
  local c = setup({ "envenom" }, nil, nil, RO)
  c.enemies[1].st.pain = 4
  c.player.res = 5
  Combat.play(c, 1, 1)
  eq(hpOf(c), 100 - 14, "DoT 4 + 10 éclate : 14"); eq(c.enemies[1].st.pain, 13); eq(c.enemies[1].stIcon.pain, "poison")
  local r = setup({ "rupture" }, nil, nil, RO)
  r.player.res = 3
  Combat.play(r, 1, 1)
  eq(r.enemies[1].st.pain, 9); eq(r.player.res, 0); eq(hpOf(r), 100)
end)

test("Exsanguinate : un déclenchement par point, arrêt quand le DoT tombe à 0", function()
  local c = setup({ "exsanguinate" }, nil, nil, RO)
  c.enemies[1].st.pain = 10
  c.player.res = 3
  Combat.play(c, 1, 1)
  eq(hpOf(c), 100 - 10 - 9 - 8); eq(c.enemies[1].st.pain, 7)
  local s = setup({ "exsanguinate" }, nil, nil, RO)
  s.enemies[1].st.pain = 2
  s.player.res = 5
  Combat.play(s, 1, 1)
  eq(hpOf(s), 100 - 2 - 1); eq(s.enemies[1].st.pain, nil); eq(s.player.res, 0, "points dépensés")
end)

test("Mutilate : +1 point de plus sur une cible sous DoT ; Garrote, Fan of Knives, Hemorrhage", function()
  local m = setup({ "mutilate", "mutilate" }, nil, nil, RO)
  Combat.play(m, 1, 1)
  eq(hpOf(m), 94); eq(m.player.res, 1)
  m.enemies[1].st.pain = 2
  Combat.play(m, 1, 1)
  eq(m.player.res, 3)
  local g = setup({ "garrote" }, nil, nil, RO)
  Combat.play(g, 1, 1)
  eq(hpOf(g), 97); eq(g.player.res, 1); eq(g.enemies[1].st.pain, num("garrote", 3, 3))
  local f = setup({ "fan_of_knives" }, { "test_dummy", "test_dummy" }, nil, RO)
  Combat.play(f, 1)
  eq(hpOf(f, 1), 97); eq(hpOf(f, 2), 97); eq(f.enemies[2].st.pain, 2); eq(f.player.res, 1)
  local h = setup({ "hemorrhage" }, nil, nil, RO)
  Combat.play(h, 1, 1)
  eq(hpOf(h), 100 - num("hemorrhage", 1)); eq(h.enemies[1].st.armor_broken, num("hemorrhage", 3, 3)); eq(h.player.res, 1)
end)

test("Killing Spree : six coups au hasard (flux des cartes), Deadly Poison sur chacun ; Blade Flurry", function()
  local c = setup({ "deadly_poison", "killing_spree" }, { "test_dummy", "test_dummy" }, nil, RO)
  c.player.mana = Card.defById("deadly_poison").cost + Card.defById("killing_spree").cost
  Combat.play(c, 1)
  local before = Rng.int(Combat.clone(c).rng.cards, 1, 2)
  Combat.play(c, 1)
  eq((100 - hpOf(c, 1)) + (100 - hpOf(c, 2)), 6 * num("killing_spree", 1))
  eq((c.enemies[1].st.pain or 0) + (c.enemies[2].st.pain or 0), 6, "un DoT 1 par coup")
  assert(before == 1 or before == 2)
  local b = setup({ "blade_flurry", "sinister_strike", "feint" }, { "test_dummy", "test_dummy" }, nil, RO)
  Combat.play(b, 1)
  Combat.play(b, 1, 1)
  eq(hpOf(b, 1), 100 - num("sinister_strike", 1) - 2); eq(hpOf(b, 2), 98)
  Combat.play(b, 1)
  eq(hpOf(b, 2), 98, "un Skill ne déclenche rien")
  eq(b.enemies[2].st.pain, nil, "pas un coup d'Attack")
end)

test("Slice and Dice : la première Attack du tour coûte 0, pas la suivante ; deux exemplaires idem", function()
  local c = setup({ "slice_and_dice", "slice_and_dice", "ambush", "sinister_strike", "feint" }, nil, nil, RO)
  c.player.mana = 9
  Combat.play(c, 1)
  Combat.play(c, 1)
  eq(Combat.cost(c, c.hand[handIndex(c, "ambush")]), 0); eq(Combat.cost(c, c.hand[handIndex(c, "feint")]), 1)
  local m = c.player.mana
  Combat.play(c, handIndex(c, "ambush"), 1)
  eq(c.player.mana, m); eq(Combat.cost(c, c.hand[handIndex(c, "sinister_strike")]), 1)
  Combat.endTurn(c)
  local ss = handIndex(c, "sinister_strike") or handIndex(c, "ambush")
  if ss then eq(Combat.cost(c, c.hand[ss]), 0, "de nouveau au tour suivant") end
end)

test("Venomous Wounds : +1 point par ennemi sous DoT au début du tour ; Shadow Dance : Stealth", function()
  local c = setup({ "venomous_wounds", "shadow_dance", "sinister_strike" }, { "test_dummy", "test_dummy", "test_dummy" }, nil, RO)
  c.player.mana = 5
  Combat.play(c, 1)
  Combat.play(c, 1)
  Combat.play(c, 1, 1)
  eq(c.player.st.stealth, nil)
  c.enemies[1].st.pain = 5
  c.enemies[3].st.pain = 5
  local r = c.player.res
  Combat.endTurn(c)
  eq(c.player.res, r + 2); eq(c.player.st.stealth, 1)
end)

test("Cheat Death : Last Breath, 1 PV, Parry 3 et Stealth, les coups suivants du tour parés ; une fois", function()
  local c = setup({ "cheat_death", "sinister_strike" }, { "test_hitter", "test_poke" }, nil, RO)
  Combat.play(c, 1)
  Combat.play(c, 1, 1)
  eq(c.player.st.stealth, nil)
  c.player.hp = 5
  Combat.endTurn(c)
  eq(c.result, nil); eq(c.player.hp, 1, "le coup de 6 qui suit est paré")
  eq(c.player.st.parry, 2); eq(c.player.st.stealth, 1)
  c.player.st.parry = nil
  Combat.endTurn(c)
  eq(c.result, "lost", "une fois par combat")
end)

test("Kick : coupe le sort et +1 point ; Riposte : Parry ; Cloak of Shadows : nettoie et Parry ; Adrenaline Rush", function()
  local k = setup({ "kick" }, { "test_caster" }, nil, RO)
  Combat.play(k, 1, 1)
  assert(k.enemies[1].interrupted); eq(k.player.res, 1); eq(k.player.mana, 3)
  local r = setup({ "riposte" }, nil, nil, RO)
  Combat.play(r, 1, 1)
  eq(hpOf(r), 96); eq(r.player.st.parry, 1)
  local cl = setup({ "cloak_of_shadows" }, nil, nil, RO)
  cl.player.st.demoralized = 2
  Combat.play(cl, 1)
  eq(cl.player.st.demoralized, nil); eq(cl.player.st.parry, 1)
  local a = setup({ "adrenaline_rush" }, nil, { "feint", "feint" }, RO)
  Combat.play(a, 1)
  eq(a.player.mana, 3 - 1 + num("adrenaline_rush", 1)); eq(#a.hand, 2); eq(a.exhaust[1].id, "adrenaline_rush")
  local sb = setup({ "smoke_bomb", "sinister_strike" }, { "test_dummy", "test_dummy" }, nil, RO)
  Combat.play(sb, 2, 1)
  Combat.play(sb, 1)
  eq(sb.enemies[2].st.demoralized, 2); eq(sb.player.st.stealth, 1)
end)

test("Secret Technique : 4 par point à tous, deux fois sous Stealth", function()
  local c = setup({ "secret_technique" }, { "test_dummy", "test_dummy" }, nil, RO)
  c.player.res = 4
  Combat.play(c, 1)
  local k = Card.defById("secret_technique").effects[2].per[1]
  eq(hpOf(c, 1), 100 - 2 * 4 * k); eq(hpOf(c, 2), 100 - 2 * 4 * k); eq(c.player.st.stealth, nil)
  local n = setup({ "sinister_strike", "secret_technique" }, { "test_dummy", "test_dummy" }, nil, RO)
  Combat.play(n, 1, 1)
  n.player.res = 4
  Combat.play(n, 1)
  eq(hpOf(n, 2), 100 - 4 * k)
end)

test("bibelots du Voleur : Thieves' Tools, Blinding Powder, Crystal Vial, Ravenholdt Signet, Shadowfang", function()
  local deck = { "feint", "feint", "feint", "feint", "feint", "feint", "feint", "feint", "feint", "feint", "feint", "feint" }
  local t = Combat.new({ seed = 3, hp = 60, class = "rogue", deck = deckOf(unpack(deck)), encounter = { "test_dummy" },
    relics = { "thieves_tools", "blinding_powder", "shadowfang" } })
  eq(#t.hand, 6, "Thieves' Tools : 6 cartes au premier tour"); eq(t.player.st.parry, 1); eq(t.player.res, 2)
  Combat.endTurn(t)
  eq(#t.hand, 5, "5 ensuite")
  local v = setup({ "garrote", "rupture" }, nil, nil, { class = "rogue", relics = { "crystal_vial", "ravenholdt_signet" } })
  Combat.play(v, 1, 1)
  eq(v.enemies[1].st.pain, num("garrote", 3, 3) + 1, "Garrote + 1")
  v.player.res = 2
  Combat.play(v, 1, 1)
  eq(v.enemies[1].st.pain, num("garrote", 3, 3) + 1 + 7, "Rupture 6 + 1"); eq(v.player.st.parry, 1, "Parry après le Surge")
end)

test("Rogue : chaque carte (base et améliorée) jouable sans erreur, combat déroulé deux tours", function()
  local n = 0
  for id, d0 in pairs(ns.Cards) do
    if d0.class == "rogue" then
      for _, up in ipairs({ false, true }) do
        local c = setup({ id }, { "test_dummy", "test_caster" }, { "feint", "feint", "feint", "feint" },
          { class = "rogue", hp = 60 })
        c.player.mana, c.player.res = 9, 5
        c.hand[1] = Card.new(id, up, 999)
        c.enemies[1].hp = 40
        c.enemies[1].st.pain = 3
        local ok, why = Combat.play(c, 1, 1)
        assert(ok, id .. (up and "+" or "") .. " : " .. tostring(why))
        Combat.endTurn(c)
        Combat.endTurn(c)
        n = n + 1
      end
    end
  end
  eq(n, 68)
end)

test("Rogue : combats simulés par le bot heuristique, sans erreur", function()
  local r = ns.Run.play({ seed = 4, bot = "heuristic", class = "rogue", cap = 120 })
  assert(r.combats[1] ~= nil)
end)

---------------------------------------------------------------------------
-- Mage : Charges, deux Cast, Instant, Hot Streak, Frozen, Ice Block, cartes et bibelots
-- (docs/classes/mage.md, docs/classes/decisions.md)
---------------------------------------------------------------------------

local M = { class = "mage" } -- options de Combat.new pour un combat de Mage
ns.Enemies.test_mage_triple = { name = "Triple", hp = 100,
  moves = { hit = { name = "Coups", intent = "attack", actions = { { "attack", 10, times = 3, interrupts = true } } } },
  pattern = { "hit" } }

local function mageHand(hand, encounter, more)
  local o = { class = "mage" }
  for k, v in pairs(more or {}) do o[k] = v end
  return setup(hand, encounter, { "mana_shield", "mana_shield", "mana_shield", "mana_shield", "mana_shield" }, o)
end
local function power(c, id, up)
  c.player.powers[#c.player.powers + 1] = Card.new(id, up, 800 + #c.player.powers)
end

-- Fiche, section 2 : coût (base, amélioré), type, voie, école, rareté, niveau.
local MAGE_SHEET = {
  fireball = { 1, 1, "attack", "start", "fire", "basic", 1 },
  frostbolt = { 1, 1, "attack", "start", "frost", "basic", 1 },
  mana_shield = { 1, 1, "skill", "start", "arcane", "basic", 1 },
  arcane_blast = { 1, 1, "attack", "start", "arcane", "basic", 1 },
  fire_blast = { 1, 1, "attack", "fire", "fire", "common", 1 },
  scorch = { 0, 0, "attack", "fire", "fire", "common", 1 },
  flamestrike = { 2, 2, "attack", "fire", "fire", "common", 1 },
  blazing_barrier = { 1, 1, "skill", "fire", "fire", "common", 1 },
  pyroblast = { 2, 2, "attack", "fire", "fire", "uncommon", 1 },
  hot_streak = { 1, 0, "power", "fire", "fire", "uncommon", 1 },
  living_bomb = { 1, 1, "attack", "fire", "fire", "uncommon", 2 },
  phoenix_flames = { 1, 1, "attack", "fire", "fire", "uncommon", 4 },
  ignite = { 1, 1, "power", "fire", "fire", "rare", 6 },
  combustion = { 0, 0, "skill", "fire", "fire", "rare", 7 },
  ice_lance = { 0, 0, "attack", "frost", "frost", "common", 1 },
  frost_nova = { 1, 1, "skill", "frost", "frost", "common", 1 },
  ice_barrier = { 1, 1, "skill", "frost", "frost", "common", 1 },
  cone_of_cold = { 1, 1, "attack", "frost", "frost", "common", 1 },
  flurry = { 1, 1, "attack", "frost", "frost", "uncommon", 1 },
  blizzard = { 2, 2, "attack", "frost", "frost", "uncommon", 1 },
  glacial_spike = { 2, 2, "attack", "frost", "frost", "uncommon", 2 },
  ice_block = { 1, 0, "power", "frost", "frost", "rare", 4 },
  deep_freeze = { 1, 1, "attack", "frost", "frost", "uncommon", 6 },
  shatter = { 1, 1, "power", "frost", "frost", "rare", 7 },
  arcane_missiles = { 1, 1, "attack", "arcane", "arcane", "common", 1 },
  arcane_explosion = { 1, 1, "attack", "arcane", "arcane", "common", 1 },
  prismatic_barrier = { 1, 1, "skill", "arcane", "arcane", "common", 1 },
  arcane_barrage = { 1, 1, "attack", "arcane", "arcane", "common", 1 },
  counterspell = { 0, 0, "skill", "arcane", "arcane", "uncommon", 1 },
  evocation = { 0, 0, "skill", "arcane", "arcane", "uncommon", 1 },
  polymorph = { 2, 1, "skill", "arcane", "arcane", "common", 2 },
  presence_of_mind = { 0, 0, "skill", "arcane", "arcane", "uncommon", 4 },
  arcane_power = { 1, 0, "power", "arcane", "arcane", "rare", 6 },
  arcane_surge = { 1, 0, "skill", "arcane", "arcane", "rare", 7 },
}

test("Mage : 34 cartes conformes à la fiche (coût, type, voie, école, rareté, niveau), 13/11/6, 10 par voie", function()
  local n, r, paths = 0, {}, {}
  for id, d in pairs(ns.Cards) do
    if d.class == "mage" then
      n = n + 1
      local s = MAGE_SHEET[id]
      assert(s, id .. " : absente de la fiche")
      local up = Card.defById(id, true)
      eq(d.cost, s[1], id .. " coût"); eq(up.cost, s[2], id .. "+ coût"); eq(d.type, s[3], id .. " type")
      eq(d.path, s[4], id .. " voie"); eq(d.school, s[5], id .. " école"); eq(d.rarity, s[6], id .. " rareté")
      eq(d.level, s[7], id .. " niveau")
      r[d.rarity] = (r[d.rarity] or 0) + 1
      paths[d.path] = (paths[d.path] or 0) + 1
    end
  end
  eq(n, 34); eq(r.basic, 4); eq(r.common, 13); eq(r.uncommon, 11); eq(r.rare, 6)
  eq(paths.start, 4); eq(paths.fire, 10); eq(paths.frost, 10); eq(paths.arcane, 10)
end)

test("Mage : définition (42 PV, Charges 0 à 4 gardées, deck de départ, Apprentice's Wand), 6 bibelots avec niveau, Interrupt et Last Breath", function()
  local cd = ns.Classes.mage
  eq(cd.hp, 42); eq(cd.resource.id, "arcane"); eq(cd.resource.cap, 4); eq(cd.resource.keep, true)
  eq(cd.startRelic, "apprentice_wand"); eq(ns.Relics.apprentice_wand.noPool, true); eq(cd.survival, "control")
  local cnt = {}
  for _, id in ipairs(cd.deck) do cnt[id] = (cnt[id] or 0) + 1 end
  eq(#cd.deck, 10); eq(cnt.frostbolt, 3); eq(cnt.mana_shield, 4); eq(cnt.fireball, 2); eq(cnt.arcane_blast, 1)
  local levels = { apprentice_wand = 1, tome_arcane_brilliance = 1, robe_archmage = 3, glacial_cloak = 5,
    fire_ruby = 7, mind_quickening_gem = 7 }
  local nr = 0
  for id, rel in pairs(ns.Relics) do
    if rel.class == "mage" then
      nr = nr + 1
      eq(rel.level, levels[id], id .. " niveau")
      local low = " " .. rel.text:lower():gsub("[%p]", " ") .. " "
      assert(not low:find(" you ", 1, true) and not low:find(" your ", 1, true), id .. " : « you »")
    end
  end
  eq(nr, 6)
  local nInt, nLb = 0, 0
  for _, d in pairs(ns.Cards) do
    if d.class == "mage" then
      for _, e in ipairs(d.effects) do if e[1] == "interrupt" then nInt = nInt + 1 end end
      if d.hooks and d.hooks.preventDeath then nLb = nLb + 1 end
    end
  end
  eq(nInt, 1); eq(nLb, 1)
end)

-- Chiffres du texte = chiffres des effets (« Deal N », « Gain N Absorb. », « Apply X N », « +N Arcane
-- Charge. », « Draw N. », plaque).
test("Mage : texte de chaque carte (base et améliorée) conforme à ses effets et à sa plaque", function()
  for id, d0 in pairs(ns.Cards) do
    if d0.class == "mage" then
      for _, up in ipairs({ false, true }) do
        local d = Card.defById(id, up)
        local t, label = d.text, id .. (up and "+" or "")
        local function has(s) assert(t:find(s, 1, true), label .. " : « " .. s .. " » absent de « " .. t:gsub("\n", " / ") .. " »") end
        for _, e in ipairs(d.effects) do
          local k = e[1]
          if k == "damage" and e[2] > 0 then
            has("Deal " .. e[2] .. (e.times == 3 and " three times" or "") .. (e.all and " to all" or ""))
            for _, m in ipairs(e.more or {}) do
              if m[2] == "frozen" then has("Frozen: deal " .. m[1] .. " more.") end
              if m[2] == "execute" then has("Execute: deal " .. (e[2] + m[1]) .. ".") end
            end
          elseif k == "damage" then
            has("deal " .. e.per[1] .. " per Charge" .. (e.all and " to all" or ""))
          elseif k == "absorb" then has("Gain " .. e[2] .. " Absorb.")
          elseif k == "res" then has("+" .. e[2] .. " Charge.")
          elseif k == "draw" and e[2] > 0 then has("Draw " .. e[2] .. ".")
          elseif k == "apply" then
            local s = ns.Statuses[e[2]]
            local line = (e.self and "Gain " or "Apply ") .. s.name .. " " .. e[3]
            if e.cond then line = line:sub(1, 1):lower() .. line:sub(2) end -- « DoT: gain Instant 1 »
            has(line)
          elseif k == "interrupt" then has("Interrupt the target's cast.")
          end
        end
        if d.cast then eq(t:match("^[^\n]+"), "Cast.", label) end
        if d.power then eq(t:match("^[^\n]+"), "Power.", label) end
        if d.cooldown then has("Cooldown " .. d.cooldown .. ".") end
        if d.exhaust then has("Exhaust.") end
        if d.retain then has("Retain.") end
        if d.evoMana then has("+" .. d.evoMana .. " mana.") end
      end
    end
  end
end)

test("Mage : chaque carte (base et améliorée) jouable sans erreur, deux tours joués ensuite", function()
  local n = 0
  for id, d0 in pairs(ns.Cards) do
    if d0.class == "mage" then
      for _, up in ipairs({ false, true }) do
        local c = mageHand({ id }, { "test_dummy", "test_caster" })
        c.player.mana, c.player.res = 9, 4
        c.hand[1] = Card.new(id, up, 999)
        c.enemies[1].hp = 40
        Combat.applyStatus(c, c.enemies[1], "demoralized", 1)
        local ok, why = Combat.play(c, 1, 1)
        assert(ok, id .. (up and "+" or "") .. " : " .. tostring(why))
        Combat.endTurn(c)
        Combat.endTurn(c)
        n = n + 1
      end
    end
  end
  eq(n, 68)
end)

test("Charges : gagnées après le coup (Arcane Blast), plafond 4 (le surplus est perdu), gardées d'un tour à l'autre", function()
  local c = mageHand({ "arcane_blast", "arcane_blast" })
  c.player.res = 3
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - num("arcane_blast", 1) - 3, "charges d'avant le coup"); eq(c.player.res, 4)
  Combat.play(c, 1, 1)
  eq(c.player.res, 4, "plafond")
  Combat.endTurn(c)
  eq(c.player.res, 4, "gardées")
  local f = mageHand({ "frostbolt" })
  eq(f.player.res, 0, "0 au début du combat")
end)

test("Charges : +1 par charge à chaque coup des cartes Attack, sur chaque cible ; rien aux Skills ni aux DoT ; avant Demoralized et Sundered", function()
  local c = mageHand({ "arcane_missiles" })
  c.player.res = 2
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - 3 * (num("arcane_missiles", 1) + 2), "trois coups"); eq(c.player.res, 3)
  local a = mageHand({ "arcane_explosion" }, { "test_dummy", "test_dummy" })
  a.player.res = 2
  Combat.play(a, 1)
  eq(a.enemies[1].hp, 100 - num("arcane_explosion", 1) - 2); eq(a.enemies[2].hp, 100 - num("arcane_explosion", 1) - 2)
  local s = mageHand({ "prismatic_barrier", "fireball" })
  s.player.res = 4
  Combat.play(s, 1)
  eq(s.player.block, num("prismatic_barrier", 1), "Skill : pas de bonus")
  local d = mageHand({ "frostbolt" })
  d.player.res = 2
  Combat.applyStatus(d, d.player, "demoralized", 1)
  Combat.applyStatus(d, d.enemies[1], "armor_broken", 1)
  Combat.play(d, 1, 1)
  eq(d.enemies[1].hp, 100 - math.floor(math.floor((num("frostbolt", 1) + 2) * 0.75) * 1.25))
  -- DoT de Fireball : sans bonus
  local f = mageHand({ "fireball" })
  f.player.res = 4
  f.player.st.instant = 1
  Combat.play(f, 1, 1)
  local hp = f.enemies[1].hp
  eq(hp, 100 - num("fireball", 1) - 4)
  Combat.endTurn(f)
  eq(f.enemies[1].hp, hp - num("fireball", 2, 3), "DoT sans charge")
end)

test("Arcane Power : 2 par charge au lieu de 1 (deux exemplaires ne font pas 3)", function()
  local c = mageHand({ "frostbolt", "frostbolt" })
  c.player.res = 3
  power(c, "arcane_power")
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - num("frostbolt", 1) - 6)
  power(c, "arcane_power")
  local hp = c.enemies[1].hp
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, hp - num("frostbolt", 1) - 6)
end)

test("Surge du Mage : Arcane Barrage injouable à 0, vide les charges, 6 par charge à tous sans bonus passif ; Arcane Surge : mana et pioche", function()
  local c = mageHand({ "arcane_barrage" }, { "test_dummy", "test_dummy" })
  eq(select(2, Combat.canPlay(c, 1)), "resource")
  c.player.res = 3
  Combat.play(c, 1)
  eq(c.player.res, 0)
  eq(c.enemies[1].hp, 100 - 18); eq(c.enemies[2].hp, 100 - 18)
  local s = mageHand({ "arcane_surge" })
  eq(select(2, Combat.canPlay(s, 1)), "resource")
  s.player.res = 4
  local hand = #s.hand
  Combat.play(s, 1)
  eq(s.player.mana, 3 - 1 + 4); eq(#s.hand, hand - 1 + 4); eq(s.player.res, 0)
end)

test("Deux Cast : deux emplacements, une troisième carte Cast injouable sauf sous Instant ; résolues de la plus ancienne à la plus récente", function()
  local c = mageHand({ "fireball", "glacial_spike", "pyroblast" })
  c.player.mana = 9
  eq(Combat.castSlots(c), 2)
  Combat.play(c, 1, 1)
  Combat.play(c, 1, 1)
  eq(Combat.castCount(c), 2)
  eq(select(2, Combat.canPlay(c, 1)), "casting")
  Combat.applyStatus(c, c.player, "instant", 1)
  assert(Combat.canPlay(c, 1), "Instant : jouable avec deux incantations en cours")
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - num("pyroblast", 1), "partie tout de suite"); eq(Combat.castCount(c), 2)
  eq(c.player.st.instant, nil)
  c.events = {}
  Combat.endTurn(c)
  local order = {}
  for _, ev in ipairs(c.events) do
    if ev.t == "cast_resolve" then
      for _, x in ipairs({ c.discard, c.hand, c.draw }) do
        for _, inst in ipairs(x) do if inst.uid == ev.card then order[#order + 1] = inst.id end end
      end
    end
  end
  eq(table.concat(order, ","), "fireball,glacial_spike")
  eq(c.enemies[1].hp, 100 - num("pyroblast", 1) - num("fireball", 1) - num("glacial_spike", 1))
  eq(c.enemies[1].st.demoralized, 2)
end)

test("Deux Cast : une interruption coupe la plus récente ; la seconde est perdue si la première finit le combat", function()
  local c = mageHand({ "fireball", "pyroblast" }, { "test_pusher" })
  Combat.play(c, 1, 1)
  Combat.play(c, 1, 1)
  eq(c.player.mana, 0, "mana payé au jeu")
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 100 - num("fireball", 1), "Fireball résolue, Pyroblast coupée")
  local cut = false
  for _, x in ipairs({ c.discard, c.hand, c.draw }) do for _, inst in ipairs(x) do if inst.id == "pyroblast" then cut = true end end end
  assert(cut, "Pyroblast à la défausse")
  -- plusieurs coups qui interrompent : une incantation par coup qui fait perdre des PV
  local t = mageHand({ "fireball", "fireball" }, { "test_mage_triple" })
  Combat.play(t, 1, 1)
  Combat.play(t, 1, 1)
  Combat.endTurn(t)
  eq(t.enemies[1].hp, 100, "les deux coupées")
  local k = mageHand({ "fireball", "pyroblast" })
  k.enemies[1].hp = 10
  Combat.play(k, 1, 1)
  Combat.play(k, 1, 1)
  Combat.endTurn(k)
  eq(k.result, "won")
end)

test("Instant : se cumule, se garde d'un tour à l'autre, la prochaine carte Cast (quelle qu'elle soit) le consomme et ne peut pas être coupée", function()
  local c = mageHand({ "fire_blast", "fire_blast", "evocation", "fireball" }, { "test_pusher" })
  c.player.mana = 9
  Combat.play(c, 1, 1)
  Combat.play(c, 1, 1)
  eq(c.player.st.instant, 2)
  local mana = c.player.mana
  Combat.play(c, handIndex(c, "evocation"))
  eq(c.player.st.instant, 1, "Evocation le consomme"); eq(c.player.mana, mana + 3, "+3 mana tout de suite")
  eq(c.player.cast, nil)
  Combat.endTurn(c)
  eq(c.player.st.instant, 1, "gardé")
  c.hand[#c.hand + 1] = Card.new("fireball", false, 950)
  Combat.play(c, #c.hand, 1)
  eq(c.player.cast, nil, "sans emplacement"); eq(c.player.st.instant, nil)
  local hp = c.enemies[1].hp
  Combat.endTurn(c)
  eq(c.enemies[1].hp, hp - num("fireball", 2, 3), "pas d'incantation à couper (DoT seul)")
end)

test("Hot Streak : la 2e carte Fire du tour donne Instant 1, après sa mise en emplacement ; une fois par tour ; deux exemplaires = 2", function()
  local c = mageHand({ "scorch", "fireball", "fireball", "scorch" })
  c.player.mana = 9
  power(c, "hot_streak")
  Combat.play(c, 1, 1)
  eq(c.player.st.instant, nil)
  Combat.play(c, 1, 1)
  assert(c.player.cast ~= nil, "la 2e carte Fire (Cast) prend son emplacement"); eq(c.player.st.instant, 1)
  Combat.play(c, 1, 1)
  eq(c.player.st.instant, nil, "la Fireball suivante part tout de suite"); eq(Combat.castCount(c), 1)
  Combat.play(c, 1, 1)
  eq(c.player.st.instant, nil, "une fois par tour")
  local d = mageHand({ "scorch", "scorch" })
  power(d, "hot_streak"); power(d, "hot_streak", true)
  Combat.play(d, 1, 1)
  Combat.play(d, 1, 1)
  eq(d.player.st.instant, 2)
  Combat.endTurn(d)
  eq(d.turn.bySchool.fire or 0, 0, "compte remis à 0")
end)

test("Frozen : Stunned ou Demoralized, lu sur la cible au coup (Ice Lance), marche contre un boss Demoralized", function()
  local c = mageHand({ "ice_lance", "ice_lance" }, { "test_dummy", "test_boss" })
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - num("ice_lance", 1))
  Combat.applyStatus(c, c.enemies[2], "stunned", 1)
  eq(c.enemies[2].st.stunned, nil, "boss immunisé à Stunned")
  Combat.applyStatus(c, c.enemies[2], "demoralized", 1)
  Combat.play(c, 1, 2)
  eq(c.enemies[2].hp, 100 - num("ice_lance", 1) - Card.defById("ice_lance").effects[1].more[1][1])
  local f = mageHand({ "frostbolt", "ice_lance" })
  Combat.play(f, 1, 1)
  Combat.play(f, 1, 1)
  eq(f.enemies[1].hp, 100 - num("frostbolt", 1) - num("ice_lance", 1)
    - Card.defById("ice_lance").effects[1].more[1][1], "Frostbolt rend Frozen")
end)

test("Deep Freeze : Stunned 1 seulement sur une cible Frozen ; Shatter : +4 par coup d'Attack sur une cible Frozen", function()
  local c = mageHand({ "deep_freeze" })
  Combat.play(c, 1, 1)
  eq(c.enemies[1].st.stunned, nil)
  local d = mageHand({ "deep_freeze" })
  Combat.applyStatus(d, d.enemies[1], "demoralized", 1)
  Combat.play(d, 1, 1)
  eq(d.enemies[1].st.stunned, 1)
  local s = mageHand({ "flurry", "flurry" })
  power(s, "shatter")
  Combat.play(s, 1, 1)
  eq(s.enemies[1].hp, 100 - 3 * num("flurry", 1), "pas encore Frozen au coup")
  local hp = s.enemies[1].hp
  Combat.play(s, 1, 1)
  eq(s.enemies[1].hp, hp - 3 * math.floor(num("flurry", 1) + 4), "Frozen : +4 à chaque coup")
end)

test("Ignite : chaque coup d'une carte Fire pose DoT 3 ; Phoenix Flames : DoT sur la cible, Instant 1", function()
  local c = mageHand({ "living_bomb", "phoenix_flames" }, { "test_dummy", "test_dummy" })
  power(c, "ignite")
  Combat.play(c, 1)
  eq(c.enemies[1].st.pain, num("living_bomb", 2, 3) + 3); eq(c.enemies[2].st.pain, num("living_bomb", 2, 3) + 3)
  eq(c.enemies[1].stIcon.pain, "burn")
  local p = mageHand({ "phoenix_flames" })
  Combat.play(p, 1, 1)
  eq(p.player.st.instant, nil, "sans DoT")
  local q = mageHand({ "phoenix_flames" })
  power(q, "ignite")
  Combat.play(q, 1, 1)
  eq(q.player.st.instant, 1, "le DoT d'Ignite compte")
end)

test("Ice Block : Last Breath une fois, PV 0 puis soin 10, les coups suivants font 0 et n'interrompent pas, retiré au début du tour", function()
  local c = mageHand({ "ice_block", "fireball", "fireball" }, { "test_mage_triple" })
  c.player.mana = 4
  Combat.play(c, 1)
  Combat.play(c, 1, 1)
  Combat.play(c, 1, 1)
  c.player.hp = 5
  Combat.endTurn(c)
  eq(c.result, nil); eq(c.player.hp, 10)
  eq(c.player.st.ice_block, nil, "retiré au début du tour")
  eq(c.enemies[1].hp, 100 - num("fireball", 1), "le coup mortel coupe la plus récente, les suivants (0) rien")
  c.player.hp = 5
  Combat.endTurn(c)
  eq(c.result, "lost")
  -- intention affichée à 0 pendant Ice Block
  local d = mageHand({ "frostbolt" }, { "test_hitter" })
  Combat.applyStatus(d, d.player, "ice_block", 1)
  eq(Combat.intentInfo(d, d.enemies[1]).damage, 0)
end)

test("Evocation : +3 mana au tour suivant (6 mana), +3 tout de suite sous Instant ; Counterspell et Polymorph donnent une charge", function()
  local c = mageHand({ "evocation" })
  Combat.play(c, 1)
  assert(c.player.cast ~= nil)
  Combat.endTurn(c)
  eq(c.player.mana, Combat.BASE_MANA + 3)
  local k = mageHand({ "counterspell", "polymorph" }, { "test_caster", "test_boss" })
  Combat.play(k, 1, 1)
  assert(k.enemies[1].interrupted); eq(k.player.res, 1)
  Combat.play(k, 1, 2)
  eq(k.player.res, 2); eq(k.enemies[2].st.stunned, nil, "boss immunisé, la charge reste")
  local p = mageHand({ "polymorph" }, { "test_hitter" })
  Combat.play(p, 1, 1)
  eq(p.enemies[1].st.stunned, 2)
  local hp = p.player.hp
  Combat.endTurn(p); Combat.endTurn(p)
  eq(p.player.hp, hp, "deux tours perdus")
end)

test("Bibelots du Mage : baguette (1re carte Cast à 0, même Evocation), Tome, Robe (Instant compris), Cape, Rubis, Gemme", function()
  local w = mageHand({ "pyroblast", "pyroblast" }, nil, { relics = { "apprentice_wand" } })
  eq(Combat.cost(w, w.hand[1]), 0)
  Combat.play(w, 1, 1)
  eq(w.player.mana, 3); eq(Combat.cost(w, w.hand[1]), 2)
  local e = mageHand({ "evocation", "pyroblast" }, nil, { relics = { "apprentice_wand" } })
  Combat.play(e, 1)
  eq(Combat.cost(e, e.hand[1]), 2, "consommée par Evocation")
  local t = mageHand({ "frostbolt" }, nil, { relics = { "tome_arcane_brilliance" } })
  eq(t.player.res, 1)
  local r = mageHand({ "fireball", "fireball" }, nil, { relics = { "robe_archmage" } })
  Combat.play(r, 1, 1)
  eq(r.player.block, 0)
  Combat.endTurn(r)
  eq(r.player.block, 4, "à la résolution, après la remise à 0")
  Combat.applyStatus(r, r.player, "instant", 1)
  r.hand[#r.hand + 1] = Card.new("fireball", false, 950)
  Combat.play(r, #r.hand, 1)
  eq(r.player.block, 8, "sous Instant aussi")
  local g = mageHand({ "ice_lance" }, { "test_dummy", "test_boss" }, { relics = { "glacial_cloak" } })
  eq(g.enemies[1].st.demoralized, 1); eq(g.enemies[2].st.demoralized, 1)
  Combat.play(g, 1, 2)
  eq(g.enemies[2].hp, 100 - num("ice_lance", 1) - Card.defById("ice_lance").effects[1].more[1][1], "boss Frozen au premier tour")
  local f = mageHand({ "frostbolt" }, nil, { relics = { "fire_ruby" } })
  eq(f.player.st.instant, 1)
  local m = mageHand({ "frostbolt" }, nil, { relics = { "mind_quickening_gem" } })
  m.player.res = 3
  Combat.endTurn(m)
  eq(m.player.mana, 3)
  m.player.res = 4
  Combat.endTurn(m)
  eq(m.player.mana, 4)
end)

test("Mage : état cloné (deux incantations, Instant), combats simulés par le bot heuristique sans erreur", function()
  local c = mageHand({ "fireball", "pyroblast" })
  Combat.play(c, 1, 1)
  Combat.play(c, 1, 1)
  local t = Combat.clone(c)
  Combat.interruptPlayer(t, t.enemies[1])
  eq(Combat.castCount(c), 2); eq(Combat.castCount(t), 1)
  assert(type(ns.ClassRules.mage.botKey(c)) == "string")
  local r = ns.Run.play({ seed = 4, bot = "heuristic", class = "mage", cap = 120 })
  assert(r.combats[1] ~= nil)
end)

---------------------------------------------------------------------------
-- Hunter : familier, Frenzy, Careful Aim, Traps, cartes et bibelots (docs/classes/hunter.md)
---------------------------------------------------------------------------

do
  local HU = { class = "hunter" } -- options de Combat.new pour un combat de Chasseur
  local Hn = ns.Hunter
  local P = Hn.PET_BASE
  ns.Enemies.test_triple = { name = "Triple", hp = 100,
    moves = { hits = { name = "Rafale", intent = "attack", actions = { { "attack", 8, times = 3 } } } }, pattern = { "hits" } }
  ns.Enemies.test_frail = { name = "Frêle", hp = 5,
    moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }
  -- coups du familier pendant une action (dégâts lus dans le journal)
  local function petHits(c)
    local out = {}
    for _, ev in ipairs(c.events) do if ev.t == "pet_attack" then out[#out + 1] = ev end end
    return out
  end

  test("Hunter : le familier attaque en fin de tour (base + Frenzy) la première cible vivante sans cible visée, puis +1 Frenzy", function()
    local c = setup({ "disengage" }, { "test_dummy", "test_dummy" }, nil, HU)
    eq(c.player.res, 0)
    Combat.play(c, 1)
    eq(c.player.lastTarget, nil, "carte sans cible : pas de cible")
    c.events = {}
    Combat.endPlayerTurn(c)
    eq(c.enemies[1].hp, 100 - P, "premier ennemi vivant"); eq(c.enemies[2].hp, 100)
    eq(c.player.res, 1, "+1 Frenzy après le coup")
    eq(#petHits(c), 1); eq(petHits(c)[1].dmg, P, "dégâts au Frenzy d'avant le gain")
  end)

  test("Hunter : cible du familier = dernière cible visée ; morte, il passe au premier ennemi vivant ; Cast : dès le jeu", function()
    local c = setup({ "concussive_shot", "aimed_shot" }, { "test_dummy", "test_dummy", "test_dummy" }, nil, HU)
    c.player.mana = 5
    Combat.play(c, 1, 3)
    eq(c.player.lastTarget, c.enemies[3].uid)
    Combat.play(c, 1, 2) -- Aimed Shot (Cast) : la cible change au jeu, avant la résolution
    eq(c.player.lastTarget, c.enemies[2].uid)
    eq(Hn.petTarget(c), c.enemies[2])
    c.enemies[2].hp, c.enemies[2].dead = 0, true
    eq(Hn.petTarget(c), c.enemies[1], "cible morte : le plus à gauche")
    c.enemies[1].dead = true
    eq(Hn.petTarget(c), c.enemies[3])
    local e = setup({ "disengage" }, { "test_dummy" }, nil, HU)
    e.enemies[1].dead = true
    eq(Hn.petTarget(e), nil); eq(Hn.petAttack(e, "auto"), 0, "aucun ennemi : rien")
  end)

  test("Hunter : Frenzy plafonné à 5, sans baisse au premier tour, -1 au début de chaque tour suivant, jamais sous 0", function()
    local c = setup({ "disengage" }, { "test_dummy" }, nil, HU)
    eq(Combat.gainRes(c, 9), 5); eq(c.player.res, 5)
    c.player.res = 0
    Combat.endTurn(c) -- fin du tour 1 : le familier frappe (+1), puis la baisse au début du tour 2
    eq(c.round, 2); eq(c.player.res, 0, "+1 en fin de tour, -1 au tour suivant")
    c.player.res = 4
    Combat.endTurn(c)
    eq(c.player.res, 4, "4 +1 (familier) -1 (baisse)")
    local z = setup({ "disengage" }, { "test_dummy", "test_dummy" }, nil, HU)
    z.enemies[1].dead, z.enemies[2].dead = true, true -- (combat figé : rien à frapper)
    z.result = nil
    Combat.endRound(z)
    eq(z.player.res, 0, "jamais sous 0")
  end)

  test("Hunter : « Pet attacks twice » recalcule chaque coup (le second profite du Frenzy gagné)", function()
    local c = setup({ "kill_command" }, nil, nil, HU)
    c.player.res = 2
    c.events = {}
    Combat.play(c, 1, 1)
    local h = petHits(c)
    eq(#h, 2); eq(h[1].dmg, P + 2); eq(h[2].dmg, P + 3)
    eq(c.player.res, 4); eq(c.enemies[1].hp, 100 - (2 * P + 5))
    eq(c.cooldown[1].card.id, "kill_command")
  end)

  test("Hunter : Surge (Bestial Wrath) : une attaque par Frenzy au Frenzy compté, sans en redonner ; injouable à 0", function()
    local c = setup({ "bestial_wrath" }, nil, nil, HU)
    eq(select(2, Combat.canPlay(c, 1)), "resource")
    c.player.res = 5
    c.events = {}
    Combat.play(c, 1, 1)
    local h = petHits(c)
    eq(#h, 5)
    for i = 1, 5 do eq(h[i].dmg, P + 5, "coup " .. i) end
    eq(c.player.res, 0, "vidé, rien regagné"); eq(c.enemies[1].hp, 100 - 5 * (P + 5))
  end)

  test("Hunter : coups du familier : Strength et Demoralized du Chasseur, Sundered et Absorb de la cible ; pas les bonus « Attacks »", function()
    local c = setup({ "disengage" }, nil, nil, { class = "hunter", relics = { "light_quiver", "rhokdelar" } })
    c.player.res = 3
    Combat.applyStatus(c, c.player, "force", 2)
    Combat.applyStatus(c, c.enemies[1], "armor_broken", 2)
    local want = math.floor((P + 3 + 2) * 1.25)
    eq(Hn.petAttack(c, "card"), want, "Strength puis Sundered, ni Light Quiver ni Rhok'delar")
    c.player.res = 3
    Combat.applyStatus(c, c.player, "demoralized", 1)
    eq(Hn.petAttack(c, "card"), math.floor(math.floor((P + 3 + 2) * 0.75) * 1.25), "Demoralized du Chasseur")
    local b = setup({ "trueshot_aura" }, nil, nil, HU)
    Combat.play(b, 1)
    b.enemies[1].block = 2
    local hp = b.enemies[1].hp
    Hn.petAttack(b, "card")
    eq(b.enemies[1].hp, hp - (P - 2 > 0 and P - 2 or 0), "Absorb de la cible, sans Trueshot Aura"); eq(b.enemies[1].block, math.max(0, 2 - P))
  end)

  test("Hunter : le familier qui tue le dernier ennemi en fin de tour gagne le combat avant le tour ennemi", function()
    local c = setup({ "disengage" }, { "test_hitter" }, nil, HU)
    c.enemies[1].hp = P
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(c.result, "won"); eq(c.player.hp, hp)
  end)

  test("Careful Aim : au-dessus de la moitié des PV seulement (moitié exacte : non), lu au début de la résolution", function()
    local d = Card.defById("aimed_shot")
    local base, more = d.effects[1][2], d.effects[1].more[1][1]
    local ok = setup({ "aimed_shot" }, nil, nil, HU)
    ok.enemies[1].hp = 51 + P -- le familier la ramène à 51/100 avant la résolution
    Combat.play(ok, 1, 1)
    Combat.endTurn(ok)
    eq(ok.enemies[1].hp, 51 - base - more, "51/100 à la résolution : Careful Aim")
    local half = setup({ "aimed_shot" }, nil, nil, HU)
    half.enemies[1].hp = 50 + P -- le familier la ramène à la moitié exacte avant la résolution
    Combat.play(half, 1, 1)
    Combat.endTurn(half)
    eq(half.enemies[1].hp, 50 - base, "50/100 à la résolution : pas de Careful Aim")
    eq(Combat.test(half, {}, "careful", { hp = 50, maxHp = 100 }), false)
    eq(Combat.test(half, {}, "careful", { hp = 51, maxHp = 100 }), true)
    -- Steady Shot : la pioche dépend de la cible au début de la résolution, pas après le coup
    local s = setup({ "steady_shot" }, nil, { "disengage", "disengage", "disengage", "disengage", "disengage", "disengage" }, HU)
    s.enemies[1].hp = 56
    Combat.play(s, 1, 1)
    Combat.endPlayerTurn(s); Combat.enemyPhase(s); Combat.endRound(s)
    s.enemies[1].hp = 55
    local nHand = #s.hand
    Combat.startPlayerTurn(s)
    eq(#s.hand, nHand + 1 + Combat.DRAW_PER_TURN, "55/100 : 1 de plus, puis la pioche du tour")
  end)

  test("Traps : 3 au plus, la plus ancienne d'abord, une par attaque, avant le premier coup ; rien sans attaque", function()
    local c = setup({ "counterattack", "freezing_trap", "frost_trap", "immolation_trap" }, { "test_triple" }, nil, HU)
    c.player.mana = 9
    Combat.play(c, 1); Combat.play(c, 1); Combat.play(c, 1)
    eq(select(2, Combat.canPlay(c, 1)), "traps")
    eq(c.traps[1].card.id, "counterattack")
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(#c.traps, 2, "une seule déclenchée"); eq(c.traps[1].card.id, "freezing_trap")
    eq(c.enemies[1].hp, 100 - P - num("counterattack", 1), "Counterattack sur l'attaquant")
    eq(c.player.hp, hp - 3 * 8, "attaque à trois coups : la Trap ne part qu'une fois")
    -- Freezing Trap : Stunned posé pendant son tour => l'attaque en cours n'a pas lieu (aucun des trois
    -- coups), charge consommée ; Demoralized couvre l'attaque du tour suivant
    hp = c.player.hp
    Combat.endTurn(c)
    eq(#c.traps, 1); eq(c.player.hp, hp, "étourdi pendant son tour : aucun des trois coups")
    eq(c.enemies[1].st.stunned, nil, "charge consommée")
    assert((c.enemies[1].st.demoralized or 0) > 0, "Demoralized encore là au tour suivant")
    -- la Frost Trap (Demoralized à tous) part à l'attaque suivante ; Demoralized réduit les trois coups
    hp = c.player.hp
    Combat.endTurn(c)
    eq(c.player.hp, hp - 3 * math.floor(8 * 0.75), "attaque du tour suivant affaiblie de 25 %")
    eq(#c.traps, 0, "Frost Trap déclenchée")
    local q = setup({ "counterattack" }, { "test_dummy" }, nil, HU)
    Combat.play(q, 1)
    Combat.endTurn(q); Combat.endTurn(q)
    eq(#q.traps, 1, "ennemi qui n'attaque pas : la Trap reste posée")
  end)

  test("Stunned posé pendant le tour de l'ennemi : arrêt immédiat (plusieurs actions, boss, Stunned 2, deux Traps)", function()
    ns.Enemies.test_combo = { name = "Combo", hp = 100, moves = { combo = { name = "Combo", intent = "attack",
      actions = { { "block", 5 }, { "attack", 6, times = 2 }, { "buff", "force", 2 } } } }, pattern = { "combo" } }
    ns.Enemies.test_boss_hitter = { name = "Boss frappeur", hp = 100, boss = true,
      moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 12 } } } }, pattern = { "hit" } }
    ns.Cards.test_stun2 = { id = "test_stun2", name = "s", cost = 0, type = "skill", trap = true, rarity = "common",
      effects = { { "apply", "stunned", 2 } }, text = "Trap.\nApply Stunned 2 ⌛" }
    ns.Cards.test_stun_all = { id = "test_stun_all", name = "s", cost = 0, type = "skill", trap = true, rarity = "common",
      effects = { { "apply", "stunned", 1, all = true } }, text = "Trap.\nApply Stunned 1 ⌛ to all" }
    -- ennemi à plusieurs actions : ce qui précède l'attaque a eu lieu, l'attaque et la suite sont annulées
    local c = setup({ "freezing_trap" }, { "test_combo" }, nil, HU)
    Combat.play(c, 1)
    local hp = c.player.hp
    Combat.endPlayerTurn(c); Combat.enemyPhase(c)
    local e = c.enemies[1]
    eq(c.player.hp, hp, "aucun coup"); eq(e.block, 5, "l'action d'avant a eu lieu"); eq(e.st.force, nil, "l'action d'après est annulée")
    eq(e.st.stunned, nil, "charge consommée")
    local stoppedEv, actEv = false, false
    for _, ev in ipairs(c.events) do
      if ev.t == "stunned" and ev.stopped and ev.unit == e.uid then stoppedEv = true end
      if ev.t == "act" and ev.unit == e.uid then actEv = true end
    end
    assert(stoppedEv, "journal : stunned (stopped)"); assert(actEv, "journal : act (le bloc est parti)")
    Combat.endRound(c); Combat.startPlayerTurn(c)
    hp = c.player.hp
    Combat.endTurn(c)
    eq(c.player.hp, hp - 2 * math.floor(6 * 0.75), "tour suivant : il agit, affaibli par Demoralized")
    -- attaque d'abord : aucun « act » (pas d'élan d'attaque à l'écran) ; deux Traps : une seule part
    local t = setup({ "freezing_trap", "counterattack" }, { "test_triple" }, nil, HU)
    t.player.mana = 9
    Combat.play(t, 1); Combat.play(t, 1)
    hp = t.player.hp
    Combat.endPlayerTurn(t); Combat.enemyPhase(t)
    eq(t.player.hp, hp, "aucun des trois coups"); eq(#t.traps, 1, "une Trap par attaque")
    for _, ev in ipairs(t.events) do assert(ev.t ~= "act", "pas d'action partie : pas d'élan") end
    -- boss : immunisé à Stunned, Demoralized réduit l'attaque en cours et la suivante
    local b = setup({ "freezing_trap" }, { "test_boss_hitter" }, nil, HU)
    Combat.play(b, 1)
    hp = b.player.hp
    Combat.endTurn(b)
    eq(b.player.hp, hp - math.floor(12 * 0.75), "boss : attaque en cours affaiblie")
    hp = b.player.hp
    Combat.endTurn(b)
    eq(b.player.hp, hp - math.floor(12 * 0.75), "boss : attaque suivante affaiblie")
    hp = b.player.hp
    Combat.endTurn(b)
    eq(b.player.hp, hp - 12, "puis pleine")
    -- Stunned 2 : ce tour et le suivant
    local s = setup({ "test_stun2" }, { "test_hitter" }, nil, HU)
    Combat.play(s, 1)
    hp = s.player.hp
    Combat.endTurn(s)
    eq(s.player.hp, hp, "ce tour"); eq(s.enemies[1].st.stunned, 1)
    Combat.endTurn(s)
    eq(s.player.hp, hp, "et le suivant"); eq(s.enemies[1].st.stunned, nil)
    Combat.endTurn(s)
    eq(s.player.hp, hp - 10, "puis il frappe")
    -- Stunned posé sur un AUTRE ennemi pendant le tour d'un premier : règle habituelle (il perd son
    -- prochain tour, ici celui de cette phase) ; le premier est arrêté
    local a = setup({ "test_stun_all" }, { "test_hitter", "test_hitter" }, nil, HU)
    Combat.play(a, 1)
    hp = a.player.hp
    Combat.endTurn(a)
    eq(a.player.hp, hp, "les deux perdent ce tour"); eq(a.enemies[1].st.stunned, nil); eq(a.enemies[2].st.stunned, nil)
    Combat.endTurn(a)
    eq(a.player.hp, hp - 20, "puis les deux frappent")
    -- Stunned posé pendant le tour du joueur : inchangé (perd son prochain tour, charge consommée alors)
    local p = setup({ "chastise" }, { "test_hitter" })
    Combat.play(p, 1, 1)
    hp = p.player.hp
    Combat.endTurn(p)
    eq(p.player.hp, hp); eq(p.enemies[1].st.stunned, nil)
    ns.Enemies.test_combo, ns.Enemies.test_boss_hitter, ns.Cards.test_stun2, ns.Cards.test_stun_all = nil, nil, nil, nil
  end)

  test("Traps : deux attaquants, chacun la sienne ; l'attaquant tué par la Trap n'attaque pas ; tour sauté : rien", function()
    local c = setup({ "counterattack", "counterattack" }, { "test_hitter", "test_frail" }, nil, HU)
    c.player.mana = 9
    Combat.play(c, 1); Combat.play(c, 1)
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(#c.traps, 0)
    eq(c.enemies[1].hp, 100 - P - num("counterattack", 1)); eq(c.enemies[2].dead, true)
    eq(c.player.hp, hp - 10, "seul le premier a frappé")
    local s = setup({ "counterattack" }, { "test_hitter" }, nil, HU)
    Combat.play(s, 1)
    s.player.flags.skipEnemyTurn = true
    Combat.endTurn(s)
    eq(#s.traps, 1, "tour ennemi sauté : aucune Trap")
    -- fin de combat : un nouveau combat repart sans Trap (le deck est reconstitué)
    local n = setup({ "disengage" }, nil, { "counterattack" }, HU)
    eq(#n.traps, 0)
  end)

  test("Hunter : Growl (Spend 2 au choix), Counter Shot, Wailing Arrow, Readiness, Hunter's Mark, Rapid Fire", function()
    local g = setup({ "growl", "growl" }, nil, nil, HU)
    g.player.res = 3
    Combat.play(g, 1)
    eq(g.player.block, 12); eq(g.player.res, 1)
    Combat.play(g, 1)
    eq(g.player.block, 18, "pas assez de Frenzy : sans bonus"); eq(g.player.res, 1)
    local k = setup({ "counter_shot" }, { "test_caster" }, nil, HU)
    Combat.play(k, 1, 1)
    eq(k.enemies[1].interrupted, true); eq(k.enemies[1].hp, 100 - P)
    local w = setup({ "wailing_arrow" }, { "test_caster", "test_caster" }, nil, HU)
    Combat.play(w, 1)
    assert(w.enemies[1].interrupted and w.enemies[2].interrupted)
    eq(w.enemies[2].hp, 100 - num("wailing_arrow", 1)); eq(w.exhaust[1].id, "wailing_arrow")
    local r = setup({ "kill_command", "rapid_fire", "readiness" }, nil, nil, HU)
    r.player.mana = 9
    Combat.play(r, 1, 1); Combat.play(r, 1, 1)
    eq(#r.cooldown, 2)
    Combat.play(r, 1)
    eq(#r.cooldown, 0); eq(r.hand[1].id, "kill_command"); eq(r.hand[2].id, "rapid_fire")
    local m = setup({ "hunters_mark", "rapid_fire" }, nil, nil, HU)
    Combat.play(m, 1, 1)
    eq(m.enemies[1].st.armor_broken, 3)
    Combat.play(m, 1, 1)
    eq(m.enemies[1].hp, 100 - 4 * math.floor(num("rapid_fire", 1) * 1.25))
  end)

  test("Hunter : Powers (Spirit Bond, The Beast Within, Trueshot Aura coup par coup, Entrapment, Lock and Load, Resourcefulness)", function()
    local sb = setup({ "spirit_bond" }, nil, nil, HU)
    sb.player.mana = 3
    Combat.play(sb, 1)
    Combat.endPlayerTurn(sb)
    eq(sb.player.block, 2, "attaque automatique : +2 Absorb")
    local bw = setup({ "the_beast_within", "concussive_shot", "disengage" }, nil, nil, HU)
    bw.player.mana = 9
    Combat.play(bw, 1)
    bw.events = {}
    Combat.play(bw, 1, 1)
    eq(#petHits(bw), 1, "après une Attack")
    bw.events = {}
    Combat.play(bw, 1)
    eq(#petHits(bw), 0, "pas après une Skill")
    local ta = setup({ "trueshot_aura", "rapid_fire" }, nil, nil, HU)
    Combat.play(ta, 1)
    ta.enemies[1].hp = 64
    Combat.play(ta, 1, 1)
    -- 64 -> 56 (3+5) -> 48 (3+5) -> 45 (sous la moitié : plus de bonus) -> 42
    eq(ta.enemies[1].hp, 42, "bonus perdu en cours de route")
    local en = setup({ "entrapment", "frost_trap", "counterattack" }, { "test_hitter" }, { "disengage", "disengage" }, HU)
    en.player.mana = 9
    Combat.play(en, 1)
    Combat.play(en, 1)
    Combat.endPlayerTurn(en); Combat.enemyPhase(en)
    eq(en.enemies[1].st.demoralized, 2, "Frost Trap 1 + Entrapment 1")
    local ll = setup({ "lock_and_load", "counterattack" }, { "test_hitter" }, nil, HU)
    Combat.play(ll, 1)
    Combat.play(ll, 1)
    Combat.endPlayerTurn(ll)
    local nh = #ll.hand
    Combat.enemyPhase(ll)
    eq(#ll.hand, nh + 1, "une carte piochée pendant le tour ennemi")
    local rf = setup({ "resourcefulness", "counterattack" }, { "test_hitter" }, nil, HU)
    rf.player.mana = 9
    Combat.play(rf, 1)
    Combat.play(rf, 1)
    Combat.endPlayerTurn(rf)
    Combat.enemyPhase(rf)
    eq(rf.hand[#rf.hand].id, "counterattack", "la Trap revient en main")
  end)

  test("Hunter : Feign Death (tour ennemi annulé : coups restants et ennemis suivants ; DoT : prochain tour sauté), une fois", function()
    local c = setup({ "feign_death" }, { "test_triple", "test_hitter" }, nil, HU)
    Combat.play(c, 1)
    c.player.hp = 5
    Combat.endTurn(c)
    eq(c.result, nil); eq(c.player.hp, 1, "reste à 1 PV : coups restants et ennemi suivant annulés")
    eq(c.player.flags.skipEnemyTurn, nil)
    c.player.block = 0
    Combat.endTurn(c)
    eq(c.result, "lost", "une seule fois")
    local d = setup({ "feign_death" }, { "test_hitter" }, nil, HU)
    Combat.play(d, 1)
    Combat.endPlayerTurn(d); Combat.enemyPhase(d); Combat.endRound(d)
    d.player.hp, d.player.st.pain = 3, 5
    Combat.startPlayerTurn(d)
    eq(d.player.hp, 1); eq(d.player.flags.skipEnemyTurn, true)
    local hp = d.player.hp
    Combat.endPlayerTurn(d); Combat.enemyPhase(d)
    eq(d.player.hp, hp, "tour ennemi sauté")
  end)

  test("Hunter : bibelots (Pet Whistle, Kibler's Bits, Light Quiver, Net-o-Matic, Devilsaur Eye, Rhok'delar)", function()
    local pw = setup({ "disengage" }, nil, nil, { class = "hunter", relics = { "pet_whistle" } })
    eq(pw.enemies[1].hp, 100 - P); eq(pw.player.res, 1, "Frenzy 1 au premier tour")
    local kb = setup({ "disengage" }, nil, nil, { class = "hunter", relics = { "kiblers_bits" } })
    eq(kb.player.res, 1)
    local lq = setup({ "aimed_shot", "concussive_shot" }, nil, nil, { class = "hunter", relics = { "light_quiver" } })
    lq.player.mana = 9
    lq.enemies[1].hp = 40
    Combat.play(lq, 2, 1)
    eq(lq.enemies[1].hp, 40 - num("concussive_shot", 1), "Attack sans Cast : rien")
    lq.enemies[1].st.demoralized = nil
    local nm = setup({ "counterattack", "frost_trap" }, nil, nil, { class = "hunter", relics = { "net_o_matic" } })
    eq(Combat.cost(nm, nm.hand[1]), 0)
    Combat.play(nm, 1)
    eq(nm.player.mana, 3); eq(Combat.cost(nm, nm.hand[1]), 1, "la première seulement")
    local de = setup({ "concussive_shot" }, { "test_dummy", "test_dummy" }, nil, { class = "hunter", relics = { "devilsaur_eye" } })
    de.enemies[1].hp = 2
    Combat.play(de, 1, 1)
    eq(de.player.res, 2)
    local rk = setup({ "concussive_shot", "concussive_shot" }, nil, nil, { class = "hunter", relics = { "rhokdelar" } })
    Combat.play(rk, 1, 1)
    eq(rk.enemies[1].hp, 100 - num("concussive_shot", 1) - 5, "premier tour : +5")
    Combat.endTurn(rk)
    local i = handIndex(rk, "concussive_shot")
    if i then
      local hp = rk.enemies[1].hp
      rk.enemies[1].st.armor_broken = nil
      Combat.play(rk, i, 1)
      eq(rk.enemies[1].hp, hp - num("concussive_shot", 1), "tour suivant : rien")
    end
  end)

  -- Textes conformes aux effets : chaque nombre de dégâts, d'Absorb, de pioche, de Frenzy, d'attaques du
  -- familier, et chaque mot de la plaque (Cast, Trap, Cooldown N, Exhaust, Power) est dans le texte.
  test("Hunter : 34 cartes (base et améliorée) jouables sans erreur, textes conformes aux effets", function()
    local n, bad = 0, {}
    local function has(t, s) return t:find(s, 1, true) ~= nil end
    for id, d0 in pairs(ns.Cards) do
      if d0.class == "hunter" then
        for _, up in ipairs({ false, true }) do
          local d = Card.defById(id, up)
          local t, lab = d.text, id .. (up and "+" or "")
          for _, e in ipairs(d.effects) do
            local k = e[1]
            if k == "damage" then
              local w = (e.times == 4 and ("eal " .. e[2] .. " four times")) or ("eal " .. e[2] .. (e.all and " to all" or "."))
              if not has(t, w) then bad[#bad + 1] = lab .. " : " .. w end
              for _, m in ipairs(e.more or {}) do
                if not has(t, "deal " .. m[1] .. " more") then bad[#bad + 1] = lab .. " : more" end
              end
            elseif k == "absorb" and not has(t, "ain " .. e[2] .. " Absorb") then bad[#bad + 1] = lab .. " : absorb"
            elseif k == "draw" and not has(t, "raw " .. e[2] .. ".") then bad[#bad + 1] = lab .. " : draw"
            elseif k == "res" and not has(t, "+" .. e[2] .. " Frenzy.") then bad[#bad + 1] = lab .. " : res"
            elseif k == "pet" then
              local w = e.surge and "pet attacks once per Frenzy."
                or (e[2] == 3 and "et attacks three times." or e[2] == 2 and "et attacks twice." or "et attacks.")
              if not has(t, w) then bad[#bad + 1] = lab .. " : pet" end
            elseif k == "interrupt" and not has(t, e.all and "Interrupt all casts." or "Interrupt the target's cast.") then
              bad[#bad + 1] = lab .. " : interrupt"
            end
          end
          if (d.cast == true) ~= has(t, "Cast.\n") then bad[#bad + 1] = lab .. " : Cast" end
          if (d.trap == true) ~= (t:find("^Trap%.\n") ~= nil) then bad[#bad + 1] = lab .. " : Trap" end
          if (d.power == true) ~= (t:find("^Power%.\n") ~= nil) then bad[#bad + 1] = lab .. " : Power" end
          if (d.exhaust == true) ~= has(t, "Exhaust.") then bad[#bad + 1] = lab .. " : Exhaust" end
          if d.cooldown and not has(t, "Cooldown " .. d.cooldown .. ".") then bad[#bad + 1] = lab .. " : Cooldown" end
          if d.trap and d.type ~= "skill" then bad[#bad + 1] = lab .. " : Trap = Skill" end
          -- jouable : sur un ennemi passif et un lanceur, puis deux tours (Traps contre un attaquant)
          local c = setup({ id }, { "test_dummy", "test_hitter" }, { "disengage", "disengage", "disengage", "disengage" },
            { class = "hunter", hp = 60 })
          c.player.mana, c.player.res = 9, 5
          c.hand[1] = Card.new(id, up, 999)
          c.enemies[1].hp = 40
          local ok, why = Combat.play(c, 1, 1)
          if not ok then bad[#bad + 1] = lab .. " : injouable (" .. tostring(why) .. ")" end
          Combat.endTurn(c)
          Combat.endTurn(c)
          n = n + 1
        end
      end
    end
    eq(n, 68)
    assert(#bad == 0, table.concat(bad, " ; "))
  end)

  test("Hunter : 34 cartes (4 de départ, 13/11/6), 10 par voie, niveaux 1 à 7, 6 bibelots, Interrupt et Last Breath", function()
    local r, paths, nInt, nLb = {}, {}, 0, 0
    for id, d in pairs(ns.Cards) do
      if d.class == "hunter" then
        r[d.rarity] = (r[d.rarity] or 0) + 1
        paths[d.path] = (paths[d.path] or 0) + 1
        assert(type(d.level) == "number" and d.level >= 1 and d.level <= 7, id .. " : level")
        if d.rarity == "basic" then eq(d.level, 1, id) end
        for _, e in ipairs(d.effects) do if e[1] == "interrupt" then nInt = nInt + 1 end end
        if d.hooks and d.hooks.preventDeath then nLb = nLb + 1 end
      end
    end
    eq(r.basic, 4); eq(r.common, 13); eq(r.uncommon, 11); eq(r.rare, 6)
    eq(paths.start, 4); eq(paths.beast_mastery, 10); eq(paths.marksmanship, 10); eq(paths.survival, 10)
    assert(nInt >= 2 and nLb == 1)
    local nr = 0
    for id, rel in pairs(ns.Relics) do
      if rel.class == "hunter" then
        nr = nr + 1
        assert(type(rel.level) == "number" and rel.level >= 1 and rel.level <= 7, id .. " : level")
      end
    end
    eq(nr, 6)
    local cd = ns.Classes.hunter
    eq(#cd.deck, 10); eq(cd.resource.id, "frenzy"); eq(cd.resource.cap, 5); eq(cd.resource.keep, true)
    eq(cd.startRelic, "pet_whistle"); eq(ns.Relics.pet_whistle.noPool, true)
    -- niveaux de la fiche (§ 5) : quelques repères
    eq(ns.Cards.dire_beast.level, 2); eq(ns.Cards.readiness.level, 4); eq(ns.Cards.feign_death.level, 6)
    eq(ns.Cards.the_beast_within.level, 7); eq(ns.Relics.net_o_matic.level, 5); eq(ns.Relics.light_quiver.level, 3)
  end)

  test("Hunter : état cloné (Traps, cible), bots : clé et valeur propres, combat simulé sans erreur", function()
    local c = setup({ "counterattack", "concussive_shot" }, { "test_dummy", "test_dummy" }, nil, HU)
    Combat.play(c, 1)
    Combat.play(c, 1, 2)
    local t = Combat.clone(c)
    table.remove(t.traps)
    eq(#c.traps, 1)
    local cr = ns.ClassRules.hunter
    assert(cr.botKey(c):find("counterattack", 1, true))
    eq(cr.botValue(c, ns.Bots.W), Hn.TRAP_VALUE)
    local r = ns.Run.play({ seed = 4, bot = "heuristic", class = "hunter", cap = 120 })
    assert(r.combats[1] ~= nil)
  end)

  ns.Enemies.test_triple, ns.Enemies.test_frail = nil, nil
end

---------------------------------------------------------------------------
-- Cartes neutres (Data/Neutral.lua, docs/cartes-neutres.md) : jouables par les cinq classes
---------------------------------------------------------------------------
do
  local CLASSES = { "priest", "warrior", "mage", "rogue", "hunter" }
  local NEUTRAL = {
    rough_dynamite = { 0, "common", 1, "attack" }, heavy_silk_bandage = { 0, "common", 1, "skill" },
    rugged_armor_kit = { 0, "common", 1, "skill" }, smoked_desert_dumplings = { 0, "uncommon", 1, "skill" },
    runecloth_bag = { 1, "common", 1, "skill" }, iron_grenade = { 1, "uncommon", 1, "attack" },
    arcane_bomb = { 2, "uncommon", 0, "skill" }, elixir_of_superior_defense = { 2, "uncommon", 1, "power" },
    black_lotus = { 3, "rare", 0, "skill" }, goblin_sapper_charge = { 3, "rare", 2, "attack" },
  }

  test("neutres : 10 cartes de la fiche (palier, rareté, coût, type), sans classe ni ressource, amélioration", function()
    local n, byTier, byRarity = 0, {}, {}
    for id, d in pairs(ns.Cards) do
      if d.neutral then
        n = n + 1
        local want = NEUTRAL[id]
        assert(want, id .. " : carte neutre hors fiche")
        eq(d.class, nil, id); eq(d.path, "neutral", id); eq(d.noReward, true, id)
        eq(d.tier, want[1], id .. " palier"); eq(d.rarity, want[2], id); eq(d.cost, want[3], id); eq(d.type, want[4], id)
        assert(d.up and d.up.text, id .. " : amélioration")
        -- payHp est commun (« Pay N HP. », décisions communes) : seule Goblin Sapper Charge le porte
        assert(d.rep == nil and d.level == nil and not d.spend and not d.minRes, id .. " : champ de classe")
        assert(not d.payHp or id == "goblin_sapper_charge", id .. " : coût en PV inattendu")
        for _, up in ipairs({ false, true }) do
          for _, e in ipairs(Card.defById(id, up).effects) do
            assert(e[1] ~= "res" and e[1] ~= "surge" and e[1] ~= "demence", id .. " : ressource de classe")
            if e[1] == "apply" then
              assert(({ force = 1, stunned = 1, pain = 1, regen = 1, armor_broken = 1, demoralized = 1 })[e[2]],
                id .. " : état commun seulement (" .. e[2] .. ")")
            end
          end
        end
        byTier[d.tier] = (byTier[d.tier] or 0) + 1
        byRarity[d.rarity] = (byRarity[d.rarity] or 0) + 1
      end
    end
    eq(n, 10)
    eq(byTier[0], 4); eq(byTier[1], 2); eq(byTier[2], 2); eq(byTier[3], 2)
    eq(byRarity.common, 4); eq(byRarity.uncommon, 4); eq(byRarity.rare, 2)
    -- jamais dans les récompenses de combat : Card.pool (sans neutres) ni Rewards.cardPool
    for _, cl in ipairs(CLASSES) do
      for _, id in ipairs(Card.pool(cl)) do assert(not ns.Cards[id].neutral, cl .. " : " .. id) end
      for _, id in ipairs(Card.pool(cl, true)) do assert(not ns.Cards[id].neutral, cl .. " (neutral) : " .. id) end
      for _, id in ipairs(ns.Rewards.cardPool(cl)) do assert(not ns.Cards[id].neutral, cl .. " : " .. id) end
    end
  end)

  -- Joue la carte (base ou améliorée) dans un combat de la classe ; renvoie le combat et l'état d'avant.
  local function playNeutral(cl, id, up, enc, hp)
    local c = setup({ id }, enc or { "test_dummy", "test_dummy" }, { "smite", "smite", "smite" }, { class = cl })
    if up then c.hand[1] = Card.new(id, true, c.hand[1].uid) end
    c.player.hp = hp or 40
    c.player.mana = 3
    local before = { hp = c.player.hp, mana = c.player.mana, hand = #c.hand, e1 = c.enemies[1].hp, e2 = c.enemies[2] and c.enemies[2].hp }
    local d = Card.defById(id, up)
    local ok, why = Combat.play(c, 1, d.target == "enemy" and 1 or nil)
    assert(ok, cl .. " " .. id .. (up and "+" or "") .. " : " .. tostring(why))
    return c, before, d
  end

  test("neutres : chaque carte jouée par chaque classe, effets conformes au texte (base et améliorée)", function()
    for _, cl in ipairs(CLASSES) do
      for _, up in ipairs({ false, true }) do
        local tag = cl .. (up and " +" or "")
        -- Rough Dynamite : 6 (9) à tous
        local c, b = playNeutral(cl, "rough_dynamite", up)
        local k = up and 9 or 6
        eq(b.e1 - c.enemies[1].hp, k, tag .. " dynamite 1"); eq(b.e2 - c.enemies[2].hp, k, tag .. " dynamite 2")
        eq(#c.exhaust, 1, tag .. " dynamite Exhaust")
        -- Heavy Silk Bandage : soigne 6 (9)
        c, b = playNeutral(cl, "heavy_silk_bandage", up)
        eq(c.player.hp - b.hp, up and 9 or 6, tag .. " bandage"); eq(#c.exhaust, 1, tag .. " bandage Exhaust")
        -- Rugged Armor Kit : 4 (7) Absorb, gardée en main en fin de tour (Retain)
        c, b = playNeutral(cl, "rugged_armor_kit", up)
        eq(c.player.block, up and 7 or 4, tag .. " kit")
        local kit = setup({ "rugged_armor_kit" }, { "test_dummy" }, nil, { class = cl })
        Combat.endTurn(kit)
        assert(handIndex(kit, "rugged_armor_kit"), tag .. " kit Retain")
        -- Smoked Desert Dumplings : Strength 1 (2), dure le combat
        c = playNeutral(cl, "smoked_desert_dumplings", up)
        eq(c.player.st.force, up and 2 or 1, tag .. " dumplings")
        Combat.endTurn(c)
        eq(c.player.st.force, up and 2 or 1, tag .. " Strength gardée")
        -- Runecloth Bag : pioche 2 (coût 0 améliorée)
        c, b = playNeutral(cl, "runecloth_bag", up)
        eq(#c.hand, b.hand - 1 + 2, tag .. " bag pioche"); eq(b.mana - c.player.mana, up and 0 or 1, tag .. " bag coût")
        -- Iron Grenade : 5 (8) et Stunned 1 sur la cible
        c, b = playNeutral(cl, "iron_grenade", up)
        eq(b.e1 - c.enemies[1].hp, up and 8 or 5, tag .. " grenade"); eq(c.enemies[1].st.stunned, 1, tag .. " Stunned")
        eq(c.enemies[2].hp, b.e2, tag .. " grenade : une seule cible")
        -- Arcane Bomb : interrompt la cible (pioche 1 améliorée)
        c, b = playNeutral(cl, "arcane_bomb", up, { "test_caster", "test_dummy" })
        assert(c.enemies[1].interrupted, tag .. " bomb Interrupt")
        eq(#c.hand, b.hand - 1 + (up and 1 or 0), tag .. " bomb pioche"); eq(c.player.mana, b.mana, tag .. " bomb coût 0")
        -- Elixir of Superior Defense : Power, 3 (4) Absorb au début de chaque tour
        c = playNeutral(cl, "elixir_of_superior_defense", up)
        eq(#c.player.powers, 1, tag .. " elixir Power")
        Combat.endTurn(c)
        eq(c.player.block, up and 4 or 3, tag .. " elixir tour 2")
        Combat.endTurn(c)
        eq(c.player.block, up and 4 or 3, tag .. " elixir tour 3 (Absorb remise à 0 avant)")
        -- Black Lotus : +2 mana (pioche 1 améliorée)
        c, b = playNeutral(cl, "black_lotus", up)
        eq(c.player.mana - b.mana, 2, tag .. " lotus"); eq(#c.hand, b.hand - 1 + (up and 1 or 0), tag .. " lotus pioche")
        -- Goblin Sapper Charge : Pay 5 HP, 14 (18) à tous
        c, b = playNeutral(cl, "goblin_sapper_charge", up, { "test_hitter", "test_dummy" })
        k = up and 18 or 14
        eq(b.e1 - c.enemies[1].hp, k, tag .. " sapper 1"); eq(b.e2 - c.enemies[2].hp, k, tag .. " sapper 2")
        eq(b.hp - c.player.hp, 5, tag .. " sapper -5 PV"); eq(b.mana - c.player.mana, 2, tag .. " sapper coût")
      end
    end
  end)

  test("neutres : Goblin Sapper Charge, « Pay 5 HP. » (coût), injouable s'il ferait tomber à 0", function()
    for _, cl in ipairs(CLASSES) do
      local c = setup({ "goblin_sapper_charge" }, { "test_dummy" }, nil, { class = cl })
      eq(ns.Cards.goblin_sapper_charge.payHp, 5, cl .. " : coût en PV")
      c.player.hp = 5
      local ok, why = Combat.canPlay(c, 1)
      assert(not ok and why == "hp", cl .. " : " .. tostring(why))
      c.player.hp = 6
      assert(Combat.canPlay(c, 1), cl .. " jouable à 6 PV")
      c.player.block = 10
      Combat.play(c, 1, nil)
      eq(c.player.hp, 1, cl .. " : payé à 6 PV, il reste 1 PV (l'Absorb ne protège pas)")
      eq(c.player.block, 10, cl .. " : Absorb intacte")
      assert(not c.result, cl .. " : pas de défaite")
    end
  end)
end

---------------------------------------------------------------------------
-- Bibelots communs de la fiche (docs/bibelots-communs.md) : crochets de combat et points d'extension
---------------------------------------------------------------------------
do
  ns.Enemies.test_elite_dummy = { name = "Élite", hp = 100, elite = true,
    moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
  ns.Enemies.test_boss_hitter = { name = "Boss", hp = 100, boss = true,
    moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10, times = 2 } } } }, pattern = { "hit" } }
  local function withRelic(id, hand, enc, extra, more)
    more = more or {}
    more.relics = { id }
    return setup(hand, enc, extra, more)
  end
  local SHEET = {
    scroll_of_intellect = { "common", 0 }, bloodsail_admirals_hat = { "common", 0 }, herb_pouch = { "common", 0 },
    lifegiving_gem = { "common", 0 }, darkmoon_prize_ticket = { "common", 1 }, head_of_onyxia = { "common", 1 },
    demonic_rune = { "common", 1 }, brilliant_mana_oil = { "uncommon", 1 }, talisman_of_ephemeral_power = { "uncommon", 1 },
    philosophers_stone = { "uncommon", 2 }, mark_of_the_champion = { "uncommon", 2 }, onyxia_scale_cloak = { "uncommon", 2 },
    hourglass_sand = { "uncommon", 2 }, bag_of_marbles = { "rare", 1 }, flint_and_tinder = { "rare", 2 },
    harm_prevention_belt = { "rare", 2 }, ironfoe = { "rare", 3 }, royal_seal_of_eldre_thalas = { "boss", 1 },
    drake_fang_talisman = { "boss", 2 },
  }

  test("bibelots communs : 19 de la fiche (rareté, palier), communs, tirables, 31 communs au total", function()
    local n, total = 0, 0
    for id, want in pairs(SHEET) do
      local r = ns.Relics[id]
      assert(r, id)
      n = n + 1
      eq(r.rarity, want[1], id); eq(r.tier, want[2], id .. " palier")
      assert(not r.class and not r.noPool, id .. " : commun et tirable")
      assert(not r.text:lower():find("%f[%a]you%f[%A]") and not r.text:lower():find("%f[%a]your%f[%A]"), id .. " : you")
    end
    eq(n, 19)
    for _, r in pairs(ns.Relics) do if not r.class then total = total + 1 end end
    eq(total, 31, "12 d'origine + 19")
    eq(ns.Relics.hand_of_justice.class, "warrior", "bibelot du Guerrier intact")
    eq(ns.Relics.force_reactive_disk.class, "warrior", "bibelot du Guerrier intact")
  end)

  test("Scroll of Intellect : pioche 1 au remélange ; main pleine ; défausse d'une carte", function()
    local c = withRelic("scroll_of_intellect", { "smite" }, nil, { "smite", "smite", "smite", "smite", "smite" })
    for i = #c.draw, 1, -1 do c.discard[#c.discard + 1] = table.remove(c.draw, i) end
    local h = #c.hand
    Combat.drawCards(c, 1)
    eq(#c.hand, h + 2, "1 + 1 au remélange")
    -- défausse d'une seule carte : le crochet la pioche, la boucle s'arrête sans erreur
    c = withRelic("scroll_of_intellect", { "smite" }, nil, { "smite" })
    c.discard = { table.remove(c.draw) }
    c.draw = {}
    Combat.drawCards(c, 3)
    eq(#c.hand, 2); eq(#c.draw, 0)
    -- main pleine : rien de plus
    c = withRelic("scroll_of_intellect", { "smite" }, nil, { "smite", "smite" })
    for i = #c.draw, 1, -1 do c.discard[#c.discard + 1] = table.remove(c.draw, i) end
    while #c.hand < Combat.HAND_MAX - 1 do c.hand[#c.hand + 1] = Card.new("smite", false, 900 + #c.hand) end
    Combat.drawCards(c, 1)
    eq(#c.hand, Combat.HAND_MAX)
  end)

  test("Demonic Rune : 3 Absorb par carte Exhaust jouée (une fois même copiée), rien sinon", function()
    for _, cl in ipairs({ "priest", "warrior", "mage", "rogue", "hunter" }) do
      local c = withRelic("demonic_rune", { "rough_dynamite", "heavy_silk_bandage" }, nil, nil, { class = cl })
      Combat.play(c, 1)
      eq(c.player.block, 3, cl)
      Combat.play(c, 1)
      eq(c.player.block, 6, cl)
    end
    local c = withRelic("demonic_rune", { "smite" })
    Combat.play(c, 1, 1)
    eq(c.player.block, 0, "Smite n'est pas Exhaust")
    c = setup({ "rough_dynamite" }, nil, nil, { relics = { "demonic_rune", "ironfoe" } })
    Combat.play(c, 1)
    eq(c.player.block, 3, "copie d'Ironfoe : pas de seconde Absorb")
  end)

  test("Brilliant Mana Oil : +1 mana aux tours 3, 6, 9", function()
    local c = withRelic("brilliant_mana_oil", { "smite" })
    local seen = {}
    for t = 1, 9 do
      seen[t] = c.player.mana
      Combat.endTurn(c)
    end
    eq(seen[1], 3); eq(seen[2], 3); eq(seen[3], 4); eq(seen[4], 3); eq(seen[6], 4); eq(seen[9], 4)
  end)

  test("Talisman of Ephemeral Power : +3 par coup des cartes Cast seulement", function()
    local c = withRelic("talisman_of_ephemeral_power", { "fireball", "frostbolt" }, nil, nil, { class = "mage" })
    local hp = c.enemies[1].hp
    local fb = Card.defById("fireball")
    Combat.resolveCard(c, c.hand[1], c.enemies[1], true)
    eq(hp - c.enemies[1].hp, fb.effects[1][2] + 3, "Fireball (Cast)")
    hp = c.enemies[1].hp
    Combat.play(c, 2, 1)
    eq(hp - c.enemies[1].hp, Card.defById("frostbolt").effects[1][2], "Frostbolt sans Cast")
  end)

  test("Bag of Marbles : Stunned 1 sur un ennemi au hasard, jamais un boss, reproductible", function()
    local c = withRelic("bag_of_marbles", { "smite" }, { "test_boss", "test_dummy" })
    eq(c.enemies[1].st.stunned, nil, "boss épargné"); eq(c.enemies[2].st.stunned, 1)
    c = withRelic("bag_of_marbles", { "smite" }, { "test_boss" })
    eq(c.enemies[1].st.stunned, nil, "boss seul : rien")
    local a = withRelic("bag_of_marbles", { "smite" }, { "test_dummy", "test_dummy", "test_dummy" })
    local b = withRelic("bag_of_marbles", { "smite" }, { "test_dummy", "test_dummy", "test_dummy" })
    local n = 0
    for i = 1, 3 do
      eq(a.enemies[i].st.stunned, b.enemies[i].st.stunned, "même graine")
      n = n + (a.enemies[i].st.stunned or 0)
    end
    eq(n, 1)
    -- le tour perdu : l'ennemi étourdi ne frappe pas au premier tour
    c = withRelic("bag_of_marbles", { "smite" }, { "test_hitter" })
    Combat.endTurn(c)
    eq(c.player.hp, 60, "premier coup perdu")
  end)

  test("Royal Seal of Eldre'Thalas : 4 mana par tour ; Drake Fang Talisman : Strength 2, 6 Absorb aux ennemis le premier tour", function()
    local c = withRelic("royal_seal_of_eldre_thalas", { "smite" })
    eq(c.player.mana, 4)
    Combat.endTurn(c)
    eq(c.player.mana, 4)
    c = withRelic("drake_fang_talisman", { "smite" }, { "test_dummy", "test_dummy" })
    eq(c.player.st.force, 2); eq(c.enemies[1].block, 6); eq(c.enemies[2].block, 6)
    local hp = c.enemies[1].hp
    Combat.play(c, 1, 1)
    eq(hp - c.enemies[1].hp, 6 + 2 - 6, "Smite 6 + Strength 2, 6 absorbés")
    Combat.endTurn(c)
    eq(c.enemies[1].block, 0, "Absorb ennemie perdue à leur tour")
    eq(c.player.st.force, 2, "Strength gardée")
  end)

  test("Philosopher's Stone : 6 Absorb par potion bue", function()
    local c = withRelic("philosophers_stone", { "smite" }, nil, nil, { potions = { "healing_potion", false, false } })
    assert(Combat.usePotion(c, 1))
    eq(c.player.block, 6)
  end)

  test("Mark of the Champion : Attacks +3 contre élites et boss, rien contre un ennemi normal", function()
    local c = withRelic("mark_of_the_champion", { "smite", "smite", "smite" }, { "test_elite_dummy", "test_boss", "test_dummy" })
    local hps = { c.enemies[1].hp, c.enemies[2].hp, c.enemies[3].hp }
    Combat.play(c, 1, 1); Combat.play(c, 1, 2); Combat.play(c, 1, 3)
    eq(hps[1] - c.enemies[1].hp, 9, "élite"); eq(hps[2] - c.enemies[2].hp, 9, "boss"); eq(hps[3] - c.enemies[3].hp, 6, "normal")
  end)

  test("Onyxia Scale Cloak : -2 par coup de boss (intention comprise), jamais sous 0 ; ennemis normaux intacts", function()
    local c = withRelic("onyxia_scale_cloak", { "smite" }, { "test_boss_hitter", "test_hitter" })
    eq(Combat.intentInfo(c, c.enemies[1]).damage, 8, "intention du boss")
    eq(Combat.intentInfo(c, c.enemies[2]).damage, 10, "intention normale")
    Combat.endTurn(c)
    eq(c.player.hp, 60 - 8 * 2 - 10)
    eq(Combat.modify(c, "enemyDamage", 1, c.enemies[1], c.player), 0, "plancher 0")
  end)

  test("Hourglass Sand : Cooldown 2 devient 1, Cooldown 1 reste 1 ; carte revenue un tour plus tôt", function()
    local c = withRelic("hourglass_sand", { "pw_shield", "kick" }, nil, nil, { class = "priest" })
    Combat.play(c, 1)
    eq(c.cooldown[1].turns, 1, "Cooldown 2 -> 1")
    c.hand[#c.hand + 1] = Card.new("kick", true, 990)
    c.player.mana = 3
    Combat.play(c, #c.hand, 1)
    eq(c.cooldown[2].turns, 1, "Kick+ Cooldown 1 reste 1")
    local back = 0
    for t = 1, 3 do
      Combat.endTurn(c)
      if handIndex(c, "pw_shield") and back == 0 then back = t end
    end
    eq(back, 2, "PW: Shield revient au 2e tour suivant (au 3e sans le bibelot)")
    local d = setup({ "pw_shield" })
    Combat.play(d, 1)
    eq(d.cooldown[1].turns, 2, "sans bibelot : inchangé")
  end)

  test("Gnomish Harm Prevention Belt : jusqu'à 5 Absorb gardées au début du tour", function()
    local c = withRelic("harm_prevention_belt", { "smite" })
    c.player.block = 8
    Combat.endTurn(c)
    eq(c.player.block, 5)
    c.player.block = 3
    Combat.endTurn(c)
    eq(c.player.block, 3)
    local d = setup({ "smite" })
    d.player.block = 8
    Combat.endTurn(d)
    eq(d.player.block, 0, "sans bibelot : remise à 0")
  end)

  test("Ironfoe : la première Attack jouée l'est deux fois (même cible, sans coût) ; Cast et cible morte", function()
    local c = withRelic("ironfoe", { "inner_fire", "smite", "smite" }, { "test_dummy", "test_dummy" })
    Combat.play(c, 1)
    eq(c.player.block, 5, "une Skill ne consomme rien")
    local hp, mana = c.enemies[1].hp, c.player.mana
    Combat.play(c, 1, 1)
    eq(hp - c.enemies[1].hp, 12, "deux fois 6"); eq(mana - c.player.mana, 1, "un seul coût")
    eq(#c.discard, 2, "la carte ne part qu'une fois (+ Inner Fire)")
    hp = c.enemies[1].hp
    Combat.play(c, 1, 1)
    eq(hp - c.enemies[1].hp, 6, "seconde Attack simple")
    -- cible tuée par l'originale : la copie frappe le premier ennemi vivant
    c = withRelic("ironfoe", { "smite" }, { "test_dummy", "test_dummy" })
    c.enemies[1].hp = 4
    Combat.play(c, 1, 1)
    assert(c.enemies[1].dead); eq(c.enemies[2].hp, 94)
    -- Attack Cast jouée en premier : doublée à sa résolution
    c = withRelic("ironfoe", { "fireball", "frostbolt" }, nil, nil, { class = "mage" })
    Combat.play(c, 1, 1)
    hp = c.enemies[1].hp
    Combat.play(c, 1, 1)
    eq(hp - c.enemies[1].hp, Card.defById("frostbolt").effects[1][2], "Frostbolt simple : Fireball marquée")
    hp = c.enemies[1].hp
    Combat.endTurn(c)
    local fb = Card.defById("fireball").effects[1][2]
    assert(hp - c.enemies[1].hp >= 2 * fb, "Fireball résolue deux fois : " .. (hp - c.enemies[1].hp))
  end)

  ns.Enemies.test_elite_dummy, ns.Enemies.test_boss_hitter = nil, nil
end

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
