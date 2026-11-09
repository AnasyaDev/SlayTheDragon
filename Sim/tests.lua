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
  eq(c.player.demence, 1)
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
  eq(c.enemies[1].hp, 100 - num("mind_flay", 2) - 3)
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
  c.player.demence = 3
  Combat.play(c, 1, 1)
  eq(c.player.demence, 0)
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

test("cartes : rep 0/1/2 = 20/5/5 hors départ ; aucune carte de départ n'a de rep", function()
  local n = { [0] = 0, [1] = 0, [2] = 0 }
  for id, d in pairs(ns.Cards) do
    if d.rarity == "basic" then
      assert(d.rep == nil, id)
    else
      assert(d.rep == 0 or d.rep == 1 or d.rep == 2, id .. " : rep")
      n[d.rep] = n[d.rep] + 1
    end
  end
  eq(n[0], 20, "Neutre"); eq(n[1], 5, "Amical"); eq(n[2], 5, "Honoré")
end)

test("récompenses filtrées par réputation de classe", function()
  local rng = Rng.new(5)
  for _ = 1, 200 do
    local ch = ns.Rewards.cardChoices(rng, "priest", 3, nil, 0)
    eq(#ch, 3)
    for _, id in ipairs(ch) do eq(ns.Cards[id].rep, 0, id) end
  end
  eq(#ns.Rewards.cardPool("priest", 1), 25)
  eq(#ns.Rewards.cardPool("priest"), 30)
end)

test("bibelots et potions respectent le contrat", function()
  local nr, np = 0, 0
  for id, r in pairs(ns.Relics) do
    nr = nr + 1
    assert(r.name and r.text and r.hooks, id)
    assert(r.rarity == "common" or r.rarity == "uncommon" or r.rarity == "rare" or r.rarity == "boss", id)
    assert(type(r.tier) == "number" and r.tier >= 0 and r.tier <= 3, id)
  end
  for id, p in pairs(ns.Potions) do
    np = np + 1
    assert(p.name and p.text and p.rarity and p.effects and type(p.tier) == "number", id)
    for _, e in ipairs(p.effects) do assert(ns.Effects[e[1]], id .. " : " .. e[1]) end
  end
  eq(nr, 10, "bibelots"); eq(np, 5, "potions")
  eq(#ns.Rewards.relicPool({ maxTier = 0 }), 4, "bibelots neutres hors boss")
  eq(#ns.Rewards.relicPool({ boss = true }), 1, "bibelots de boss")
  ns.Relics.test_class = { name = "x", text = "x", rarity = "rare", tier = 0, class = "priest", hooks = {} }
  ns.Relics.test_nopool = { name = "x", text = "x", rarity = "common", tier = 0, noPool = true, hooks = {} }
  eq(#ns.Rewards.relicPool({ maxTier = 0 }), 4, "bibelots de classe et noPool exclus des tirages")
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

test("Bandeau de VanCleef : 6 cartes par tour, 1 mana de moins au premier tour", function()
  local deck = {}
  for i = 1, 14 do deck[i] = { id = "smite", up = false } end
  local c = Combat.new({ seed = 1, hp = 60, deck = deck, encounter = { "test_hitter" }, relics = { "vancleef_bandana" } })
  eq(#c.hand, 6); eq(c.player.mana, 2)
  Combat.endTurn(c)
  eq(c.player.mana, 3)
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
  c.player.demence = 4
  Combat.play(c, 1, 1)
  eq(c.enemies[1].hp, 100 - num("void_eruption", 2) - 4 * Card.defById("void_eruption").perDemence); eq(c.player.demence, 0)
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
  eq(c.player.block, 7)
end)

test("Guérison de l'ombre : soigne puis Douleur sur soi", function()
  local c = setup({ "shadow_mend" })
  c.player.hp = 30
  Combat.play(c, 1)
  eq(c.player.hp, 40); eq(c.player.st.pain, 2); eq(c.player.demence, 1)
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
  eq(c.enemies[2].st.demoralized, nil, "Démoralisé 1 posé à ton tour ne dure que ce tour-ci")
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
  eq(c.player.demence, 3)
end)

test("Apothéose : +1 mana par tour ; Forme d'ombre : +2 Démence", function()
  local c = setup({ "apotheosis", "shadowform", "holy_fire" }, { "test_dummy" }, { "smite", "smite", "smite", "smite",
    "smite", "smite", "smite", "smite" })
  c.player.mana = 4
  Combat.play(c, 1)
  Combat.play(c, 1)
  eq(c.player.demence, 2)
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

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
