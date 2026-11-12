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

test("cartes : par classe, rep 0/1/2 = 20/5/5 hors départ ; aucune carte de départ n'a de rep", function()
  for class in pairs(ns.Classes) do
    local n = { [0] = 0, [1] = 0, [2] = 0 }
    for id, d in pairs(ns.Cards) do
      if d.class == class then
        if d.rarity == "basic" then
          assert(d.rep == nil, id)
        else
          assert(d.rep == 0 or d.rep == 1 or d.rep == 2, id .. " : rep")
          n[d.rep] = n[d.rep] + 1
        end
      end
    end
    eq(n[0], 20, class .. " Neutre"); eq(n[1], 5, class .. " Amical"); eq(n[2], 5, class .. " Honoré")
  end
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
    if not r.noPool and not r.class then nr = nr + 1 end -- communs (bibelots de rencontre et de classe à part)
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

test("Extase : +1 à chaque gain d'Absorption", function()
  local c = setup({ "rapture", "inner_fire" })
  Combat.play(c, 1)
  Combat.play(c, 1)
  eq(c.player.block, num("inner_fire", 1) + 1)
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
  eq(c.enemies[2].hp, 93); eq(c.player.hp, hp - 10, "l'attaque part quand même")
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
-- Mage : Arcane Charges, deux Cast, Instant, Hot Streak, Frozen, Ice Block, cartes et bibelots
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
  combustion = { 1, 0, "skill", "fire", "fire", "rare", 7 },
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
  polymorph = { 1, 0, "skill", "arcane", "arcane", "common", 2 },
  presence_of_mind = { 0, 0, "skill", "arcane", "arcane", "uncommon", 4 },
  arcane_power = { 1, 0, "power", "arcane", "arcane", "rare", 6 },
  arcane_surge = { 1, 0, "skill", "arcane", "arcane", "rare", 7 },
}

test("Mage : 34 cartes conformes à la fiche (coût, type, voie, école, rareté, niveau), 13/11/6, 10 par voie, rep 20/5/5 dans l'ordre des niveaux", function()
  local n, r, paths, repByLevel = 0, {}, {}, {}
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
      if d.rarity ~= "basic" then
        repByLevel[#repByLevel + 1] = { d.level, d.rep, id }
      end
    end
  end
  eq(n, 34); eq(r.basic, 4); eq(r.common, 13); eq(r.uncommon, 11); eq(r.rare, 6)
  eq(paths.start, 4); eq(paths.fire, 10); eq(paths.frost, 10); eq(paths.arcane, 10)
  -- rep monotone avec le niveau (un niveau plus haut n'a jamais un palier plus bas)
  for _, a in ipairs(repByLevel) do
    for _, b in ipairs(repByLevel) do
      if a[1] < b[1] then assert(a[2] <= b[2], a[3] .. " / " .. b[3] .. " : rep non monotone") end
    end
  end
end)

test("Mage : définition (52 PV, Arcane Charges 0 à 4 gardées, deck de départ, Apprentice's Wand), 6 bibelots avec niveau, Interrupt et Last Breath", function()
  local cd = ns.Classes.mage
  eq(cd.hp, 52); eq(cd.resource.id, "arcane"); eq(cd.resource.cap, 4); eq(cd.resource.keep, true)
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
            has("deal " .. e.per[1] .. " per Arcane Charge" .. (e.all and " to all" or ""))
          elseif k == "absorb" then has("Gain " .. e[2] .. " Absorb.")
          elseif k == "res" then has("+" .. e[2] .. " Arcane Charge.")
          elseif k == "draw" and e[2] > 0 then has("Draw " .. e[2] .. ".")
          elseif k == "apply" then
            local s = ns.Statuses[e[2]]
            has((e.self and "Gain " or "Apply ") .. s.name .. " " .. e[3])
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

test("Arcane Charges : gagnées après le coup (Arcane Blast), plafond 4 (le surplus est perdu), gardées d'un tour à l'autre", function()
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

test("Arcane Charges : +1 par charge à chaque coup des cartes Attack, sur chaque cible ; rien aux Skills ni aux DoT ; avant Demoralized et Sundered", function()
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
  eq(f.enemies[1].hp, 100 - num("frostbolt", 1) - num("ice_lance", 1) - 8, "Frostbolt rend Frozen")
end)

test("Deep Freeze : Stunned 1 seulement sur une cible Frozen ; Shatter : +3 par coup d'Attack sur une cible Frozen", function()
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
  eq(s.enemies[1].hp, hp - 3 * math.floor(num("flurry", 1) + 3), "Frozen : +3 à chaque coup")
end)

test("Ignite : chaque coup d'une carte Fire pose DoT 2 ; Phoenix Flames : DoT sur la cible, Instant 1", function()
  local c = mageHand({ "living_bomb", "phoenix_flames" }, { "test_dummy", "test_dummy" })
  power(c, "ignite")
  Combat.play(c, 1)
  eq(c.enemies[1].st.pain, num("living_bomb", 2, 3) + 2); eq(c.enemies[2].st.pain, num("living_bomb", 2, 3) + 2)
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
  eq(g.enemies[2].hp, 100 - num("ice_lance", 1) - 8, "boss Frozen au premier tour")
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

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
