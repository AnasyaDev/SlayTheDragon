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

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
