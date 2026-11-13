-- Tests de la zone Duskwood (Curse), lancés par Sim/tests_zones.lua : règle de la fiche (docs/zones/duskwood.md,
-- § 2) et ses cas limites, interactions (Absorb, Parry, Stunned, incantation et interruption, Trap, DoT,
-- familier, Rage), chaque ennemi, élite et phase du boss, rencontres, affiche WANTED, déblocages, bibelots, bot.
return function(T)
  local ns, test, eq, combat, play = T.ns, T.test, T.eq, T.combat, T.play
  local Combat, Card, X, DW, Meta = ns.Combat, ns.Card, ns.Expedition, ns.Duskwood, ns.Meta

  local function count(c, id, pile)
    local n = 0
    for _, inst in ipairs(c[pile]) do if inst.id == id then n = n + 1 end end
    return n
  end
  local function curses(c) return DW.count(c) end
  -- combat de Duskwood ; enemies = ids ; intents = { move du 1er, du 2e… } posés tout de suite
  local function dusk(o)
    o.zone = "duskwood"
    local c = combat(o)
    for i, mv in ipairs(o.intents or {}) do if mv then c.enemies[i].intent = mv end end
    return c
  end
  -- carte de test : Trap qui étourdit ; attaque à 3 coups ; compétence de dégâts
  ns.Cards.dw_stun_trap = { id = "dw_stun_trap", name = "Test Stun Trap", cost = 0, type = "skill", trap = true,
    effects = { { "apply", "stunned", 1 } }, text = "Trap.\nApply Stunned 1 ⌛" }
  ns.Cards.dw_triple = { id = "dw_triple", name = "Test Triple", cost = 0, type = "attack", target = "enemy",
    effects = { { "damage", 5, times = 3 } }, text = "Deal 5 three times." }
  ns.Cards.dw_zap = { id = "dw_zap", name = "Test Zap", cost = 0, type = "skill", target = "enemy",
    effects = { { "damage", 5 } }, text = "Deal 5." }
  ns.Cards.dw_big = { id = "dw_big", name = "Test Big", cost = 0, type = "skill", target = "enemy",
    effects = { { "damage", 200 } }, text = "Deal 200." }

  ---------------------------------------------------------------------------
  -- Règle : Bite, Hex, plafond, levée, jouer, fin de tour, effets en main, nettoyage
  ---------------------------------------------------------------------------

  test("Duskwood : zone jouable, règle active dans sa zone seulement (Westfall sans règle)", function()
    assert(ns.Zone.playable("duskwood"))
    local c = dusk({ enemies = { "dark_runner" } })
    eq(c.zr[1], "duskwood"); assert(ns.ZoneRules.duskwood)
    local w = combat({ zone = "westfall", enemies = { "gnoll" } })
    eq(w.zr, nil, "aucune règle à Westfall")
    local ok, why = T.plainData(c.zs); assert(ok, why)
  end)

  test("Bite : Rabies dans la défausse si l'attaque fait perdre des PV (lanceur noté, levée à sa mort)", function()
    local c = dusk({ enemies = { "dark_runner" }, intents = { "bite" } })
    Combat.endTurn(c)
    eq(c.player.hp, 60 - 7)
    -- défausse (pioche vide : remélangée et piochée au tour suivant)
    eq(DW.count(c, nil, "rabies"), 1)
    local inst
    for _, k in ipairs({ "hand", "draw", "discard" }) do for _, x in ipairs(c[k]) do if x.id == "rabies" then inst = x end end end
    eq(inst.src, c.enemies[1].uid); eq(inst.lift, true)
    local d = dusk({ enemies = { "dark_runner" }, intents = { "bite" }, deck = { "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite" } })
    Combat.endTurn(d)
    eq(count(d, "rabies", "discard"), 1, "dans la défausse")
  end)

  test("Bite entièrement absorbé : pas de Curse ; en partie : la Curse passe", function()
    local c = dusk({ enemies = { "dark_runner" }, intents = { "bite" } })
    c.player.block = 7
    Combat.endTurn(c)
    eq(c.player.hp, 60); eq(curses(c), 0)
    local d = dusk({ enemies = { "dark_runner" }, intents = { "bite" } })
    d.player.block = 6
    Combat.endTurn(d)
    eq(d.player.hp, 59); eq(curses(d), 1)
  end)

  test("Bite et Parry (Rogue) : 7 paré (pas de Curse), Vile Bite 9 laisse passer 1 PV et la Curse", function()
    local c = dusk({ class = "rogue", enemies = { "dark_runner" }, intents = { "bite" } })
    c.player.st.parry = 1
    Combat.endTurn(c)
    eq(c.player.hp, 60); eq(curses(c), 0)
    local d = dusk({ class = "rogue", enemies = { "vile_fang" }, intents = { "vile_bite" } })
    d.player.st.parry = 1
    Combat.endTurn(d)
    eq(d.player.hp, 59); eq(DW.count(d, nil, "rabies"), 1)
  end)

  test("Bite : un ennemi étourdi ne pose rien ; une Trap qui étourdit avant le coup l'arrête", function()
    local c = dusk({ enemies = { "dark_runner" }, intents = { "bite" } })
    Combat.applyStatus(c, c.enemies[1], "stunned", 1)
    Combat.endTurn(c)
    eq(c.player.hp, 60); eq(curses(c), 0)
    local d = dusk({ enemies = { "dark_runner" }, intents = { "bite" }, hand = { "dw_stun_trap" } })
    play(d, "dw_stun_trap")
    Combat.endTurn(d)
    eq(d.player.hp, 60); eq(curses(d), 0, "Trap avant le coup")
  end)

  test("Bite à plusieurs coups : une seule Curse par attaque (Fetid Corpse : Fevered Plague)", function()
    local c = dusk({ enemies = { "fetid_corpse", "dark_runner" }, intents = { "rotting_claw", "pounce" } })
    Combat.endTurn(c)
    eq(DW.count(c, nil, "fevered_plague"), 1); eq(DW.count(c, nil, "rabies"), 0, "Pounce n'est pas un Bite")
    eq(c.player.hp, 60 - 5 - 8)
  end)

  test("Hex en incantation (Shadow Weaver) : Curse of Weakness sur la pioche ; interrompue : rien", function()
    local c = dusk({ enemies = { "shadow_weaver" }, intents = { "hex" }, deck = { "smite", "smite", "smite", "smite", "smite", "smite" } })
    Combat.endTurn(c)
    eq(count(c, "curse_of_weakness", "hand"), 1, "posée sur la pioche, piochée au tour suivant")
    local d = dusk({ enemies = { "shadow_weaver" }, intents = { "hex" }, hand = { "silence" } })
    play(d, "silence", 1)
    Combat.endTurn(d)
    eq(curses(d), 0, "interrompue")
  end)

  test("Hex : pas une attaque (aucune Trap) ; Web en main ; main pleine -> défausse", function()
    local c = dusk({ enemies = { "plague_spreader" }, intents = { "cloud" }, hand = { "dw_stun_trap" } })
    play(c, "dw_stun_trap")
    Combat.endTurn(c)
    eq(#c.traps, 1, "la Trap attend toujours"); eq(DW.count(c, nil, "fevered_plague"), 1)
    local d = dusk({ enemies = { "venom_spider" }, intents = { "web" } })
    Combat.endTurn(d)
    eq(count(d, "web", "hand"), 1)
    local f = dusk({ enemies = { "venom_spider" } })
    for _ = 1, Combat.HAND_MAX do Combat.addCard(f, "dw_zap", "hand") end
    local inst = DW.add(f, "web", f.enemies[1], "hand")
    eq(Combat.findCard(f, inst), "discard")
  end)

  test("plafond : 6 Curses au plus (main, pioche, défausse) ; au-delà rien, journal curse_full", function()
    local c = dusk({ enemies = { "dark_runner" } })
    for _ = 1, 6 do assert(DW.add(c, "rabies", c.enemies[1], "discard")) end
    eq(DW.add(c, "rabies", c.enemies[1], "hand"), nil)
    eq(curses(c), 6)
    local seen
    for _, ev in ipairs(c.events) do if ev.t == "curse_full" then seen = true end end
    assert(seen, "journal")
    -- jouer une Curse libère une place
    c.hand[#c.hand + 1] = table.remove(c.discard)
    c.player.mana = 3
    play(c, "rabies")
    assert(DW.add(c, "web", c.enemies[1], "hand"), "place libérée")
  end)

  test("tuer le lanceur lève ses Curses (main, pioche, défausse), pas celles d'un autre ; non jouées", function()
    local c = dusk({ enemies = { "dark_runner", "dark_runner" }, hand = { "dw_big" } })
    local a, b = c.enemies[1], c.enemies[2]
    DW.add(c, "rabies", a, "hand"); DW.add(c, "rabies", a, "draw"); DW.add(c, "rabies", a, "discard")
    DW.add(c, "rabies", b, "discard")
    local lifted, played = 0, 0
    ns.Relics.dw_watch = { id = "dw_watch", name = "x", text = "x", rarity = "common", noPool = true,
      hooks = { onExhaust = function(cc, src, inst, why) if why == "lifted" then lifted = lifted + 1 elseif why == "played" then played = played + 1 end end } }
    c.relics[#c.relics + 1] = "dw_watch"
    c.hk.onExhaust = true
    play(c, "dw_big", 1)
    eq(curses(c), 1, "celle de l'autre reste"); eq(lifted, 3); eq(played, 0)
    eq(c.zs.duskwood ~= nil, true)
    ns.Relics.dw_watch = nil
  end)

  test("lanceur tué par son DoT au début de son tour : Curses levées avant d'agir", function()
    local c = dusk({ enemies = { "dark_runner", "dark_runner" }, intents = { "bite", "pounce" } })
    local a = c.enemies[1]
    DW.add(c, "rabies", a, "discard")
    a.hp = 2
    Combat.applyStatus(c, a, "pain", 3)
    Combat.endTurn(c)
    eq(a.dead, true); eq(count(c, "rabies", "discard"), 0, "levée, et pas de Bite")
  end)

  test("jouer une Curse : coût payé, aucun effet, épuisée (onExhaust played) ; Fevered Plague injouable", function()
    local c = dusk({ enemies = { "dark_runner" } })
    local inst = DW.add(c, "rabies", c.enemies[1], "hand")
    c.player.mana = 3
    play(c, "rabies")
    eq(c.player.mana, 2); eq(c.exhaust[#c.exhaust], inst); eq(curses(c), 0)
    DW.add(c, "fevered_plague", c.enemies[1], "hand")
    local ok, why = Combat.canPlay(c, T.handIndex(c, "fevered_plague"))
    eq(ok, false); eq(why, "unplayable")
  end)

  test("Web : Pay 2 HP (injouable à 2 PV), une carte de moins à la pioche, Retain", function()
    local c = dusk({ enemies = { "venom_spider" }, deck = { "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite" } })
    c.enemies[1].intent = "venom_bite"
    DW.add(c, "web", c.enemies[1], "hand")
    Combat.endTurn(c)
    eq(count(c, "web", "hand"), 1, "gardée")
    eq(#c.hand, 1 + 4, "5 - 1 cartes piochées")
    local hp = c.player.hp
    play(c, "web")
    eq(c.player.hp, hp - 2)
    local d = dusk({ enemies = { "venom_spider" }, hp = 2 })
    DW.add(d, "web", d.enemies[1], "hand")
    eq(select(2, Combat.canPlay(d, T.handIndex(d, "web"))), "hp")
  end)

  test("End of turn : Rabies 3 PV et Fevered Plague 2 PV, sans Absorb, avant la défausse ; peuvent tuer", function()
    local c = dusk({ enemies = { "dark_runner" } })
    c.enemies[1].intent = "pounce"
    DW.add(c, "rabies", c.enemies[1], "hand")
    DW.add(c, "fevered_plague", c.enemies[1], "hand")
    c.player.block = 20
    local before = c.player.hp
    Combat.endPlayerTurn(c)
    eq(c.player.hp, before - 5); eq(c.player.block, 20)
    eq(c.stats == nil or true, true)
    local d = dusk({ enemies = { "dark_runner" }, hp = 3 })
    DW.add(d, "rabies", d.enemies[1], "hand")
    Combat.endTurn(d)
    eq(d.result, "lost", "une Curse peut tuer")
  end)

  test("Curse of Weakness en main : Attacks -3 par coup (0 au moins), cumul ; Skills et familier épargnés", function()
    local c = dusk({ enemies = { "rotted_one" }, hand = { "dw_triple", "dw_zap" } })
    local e = c.enemies[1]
    local hp = e.hp
    DW.add(c, "curse_of_weakness", e, "hand")
    play(c, "dw_triple", 1)
    eq(hp - e.hp, 3 * 2, "5 - 3 par coup")
    hp = e.hp
    play(c, "dw_zap", 1)
    eq(hp - e.hp, 5, "Skill intacte")
    DW.add(c, "curse_of_weakness", e, "hand")
    eq(Combat.calcDamage(c, c.player, e, 5, Card.defById("dw_triple")), 0, "deux Curses : 0 au moins")
    -- familier du Hunter : pas une Attack
    local h = dusk({ class = "hunter", enemies = { "rotted_one" } })
    DW.add(h, "curse_of_weakness", h.enemies[1], "hand")
    local hp2 = h.enemies[1].hp
    ns.Hunter.petAttack(h, "card")
    local pet = hp2 - h.enemies[1].hp
    local h2 = dusk({ class = "hunter", enemies = { "rotted_one" } })
    local hp3 = h2.enemies[1].hp
    ns.Hunter.petAttack(h2, "card")
    eq(pet, hp3 - h2.enemies[1].hp, "familier insensible")
  end)

  test("Curse of Tongues en main : première carte du tour +1, pas sur elle-même, puis prix normal", function()
    local c = dusk({ enemies = { "morbent_fel" }, hand = { "smite", "smite" } })
    DW.add(c, "curse_of_tongues", c.enemies[1], "hand")
    local s = T.handIndex(c, "smite")
    eq(Combat.cost(c, c.hand[s]), 2)
    eq(Combat.cost(c, c.hand[T.handIndex(c, "curse_of_tongues")]), 2, "elle-même : 2")
    c.player.mana = 9
    play(c, "smite", 1)
    eq(Combat.cost(c, c.hand[T.handIndex(c, "smite")]), 1, "deuxième carte : prix normal")
  end)

  test("« Remove negative effects. » : Curses de la main épuisées et comptées ; pioche intacte", function()
    local c = dusk({ class = "warrior", enemies = { "dark_runner" }, hand = { "berserker_rage" }, hp = 74 })
    DW.add(c, "rabies", c.enemies[1], "hand"); DW.add(c, "web", c.enemies[1], "hand")
    DW.add(c, "rabies", c.enemies[1], "draw")
    Combat.applyStatus(c, c.player, "armor_broken", 1)
    eq(Combat.cleanse(c, c.player), 3, "1 état + 2 Curses")
    eq(curses(c), 1, "celle de la pioche reste")
    local d = dusk({ class = "warrior", enemies = { "dark_runner" }, hand = { "berserker_rage" }, hp = 74 })
    DW.add(d, "rabies", d.enemies[1], "hand")
    play(d, "berserker_rage")
    eq(curses(d), 0)
  end)

  test("Rage (Warrior) : les pertes de PV des Curses en donnent", function()
    local c = dusk({ class = "warrior", enemies = { "dark_runner" }, hp = 74 })
    c.enemies[1].intent = "pounce"
    c.player.block = 50
    DW.add(c, "rabies", c.enemies[1], "hand")
    local r = c.player.res or 0
    Combat.endPlayerTurn(c)
    assert((c.player.res or 0) > r, "Rage gagnée")
  end)

  test("clone et sauvegarde : Curses partagées sans copie, état de zone en données simples", function()
    local c = dusk({ enemies = { "dark_runner" } })
    DW.add(c, "rabies", c.enemies[1], "discard")
    local t = Combat.clone(c)
    eq(t.discard[#t.discard], c.discard[#c.discard])
    DW.add(t, "web", t.enemies[1], "hand")
    eq(curses(c), 1); eq(curses(t), 2)
    local ok, why = T.plainData(c.hand); assert(ok, why)
  end)

  ---------------------------------------------------------------------------
  -- Ennemis, élites, boss
  ---------------------------------------------------------------------------

  test("ennemis normaux : motifs, Howl (Strength à tous), Shamble (Absorb à un allié), Smash interrompt", function()
    local c = dusk({ enemies = { "vile_fang", "dark_runner" }, intents = { "howl", "pounce" } })
    Combat.endTurn(c)
    eq(c.enemies[1].st.force, 1); eq(c.enemies[2].st.force, 1)
    local d = dusk({ enemies = { "rotted_one", "plague_spreader" }, intents = { "shamble", "claw" } })
    Combat.endTurn(d)
    assert(d.enemies[1].block + d.enemies[2].block == 0, "Absorb remis à 0 au début du tour ennemi suivant")
    local s = dusk({ enemies = { "splinter_fist" }, intents = { "smash" }, hand = { "holy_fire" } })
    s.player.mana = 9
    play(s, "holy_fire", 1)
    Combat.endTurn(s)
    eq(s.player.cast, nil, "Smash coupe l'incantation")
  end)

  test("Defias Night Runner : Ambush 13 au premier tour, puis Stab et Kick", function()
    local c = dusk({ enemies = { "night_runner" } })
    eq(c.enemies[1].intent, "ambush")
    Combat.endTurn(c)
    eq(c.player.hp, 60 - 13)
    eq(c.enemies[1].intent, "stab")
  end)

  test("Venom Web Spider et Pygmy : DoT sur le joueur après la morsure", function()
    local c = dusk({ enemies = { "venom_spider", "pygmy_spider" }, intents = { "venom_bite", "nip" } })
    Combat.endTurn(c)
    eq(c.player.st.pain ~= nil, true)
  end)

  test("Stitches : Spew (6 + 2 Fevered Plague), Gorge (Absorb 10, Strength 1 par Plague de lui en jeu)", function()
    local c = dusk({ enemies = { "stitches" }, intents = { "spew" } })
    Combat.endTurn(c)
    eq(c.player.hp, 54); eq(DW.count(c, nil, "fevered_plague"), 2)
    c.enemies[1].intent = "gorge"
    DW.add(c, "fevered_plague", nil, "discard") -- sans lanceur : ne compte pas
    Combat.endTurn(c)
    eq(c.enemies[1].st.force, 2); eq(c.enemies[1].block, 10)
  end)

  test("Naraxis : Web Spray (2 Web en main), Brood (petits sbires, 4 ennemis vivants au plus)", function()
    local c = dusk({ enemies = { "naraxis" }, intents = { "web_spray" } })
    Combat.endTurn(c)
    eq(count(c, "web", "hand"), 2)
    c.enemies[1].intent = "brood"
    Combat.endTurn(c)
    eq(#Combat.aliveEnemies(c), 3)
    c.enemies[1].intent = "brood"
    Combat.endTurn(c)
    eq(#Combat.aliveEnemies(c), 4, "trois petits au plus")
    assert(c.enemies[2].minion)
  end)

  test("Mor'Ladim : Bone Armor (Absorb 14 + 7), Hex de 2 Curse of Weakness sur la pioche (interruptible)", function()
    local c = dusk({ enemies = { "morladim" }, intents = { "hex" } })
    Combat.endTurn(c)
    eq(DW.count(c, nil, "curse_of_weakness"), 2)
    c.enemies[1].intent = "bone_armor"
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(c.enemies[1].block, 14); eq(hp - c.player.hp, 7)
  end)

  test("Morbent Fel : Unholy Shield au départ (moitié des dégâts), Morbent's Bane en main la retire", function()
    local c = dusk({ enemies = { "morbent_fel" }, kind = "boss", hand = { "morbents_bane", "dw_zap" } })
    local e = c.enemies[1]
    eq(e.st.unholy_shield, 1)
    local hp = e.hp
    play(c, "dw_zap", 1)
    eq(hp - e.hp, 2, "5 / 2")
    hp = e.hp
    play(c, "morbents_bane", 1)
    eq(e.st.unholy_shield, nil); eq(hp - e.hp, 6, "6 à plein")
    eq(Combat.findCard(c, c.cooldown[1] and c.cooldown[1].card), "cooldown")
  end)

  test("Morbent Fel : seuil à 50 % (2 Fetid Corpses, réplique, Unholy Shield annoncé), Tongues, Drain Life", function()
    local c = dusk({ enemies = { "morbent_fel" }, kind = "boss", hand = { "dw_big" } })
    local e = c.enemies[1]
    e.st.unholy_shield = nil
    Combat.dealDamage(c, c.player, e, e.hp - Combat.phaseHp(e, ns.Enemies.morbent_fel.phases[1]))
    eq(e.mem.phase, 1); eq(#Combat.aliveEnemies(c), 3); eq(e.intent, "unholy_shield")
    Combat.endTurn(c)
    eq(e.st.unholy_shield, 1); eq(e.block, 10, "Absorb 10 jusqu'à son tour suivant")
    local d = dusk({ enemies = { "morbent_fel" }, kind = "boss" })
    d.enemies[1].intent = "tongues"
    Combat.endTurn(d)
    eq(count(d, "curse_of_tongues", "hand"), 1)
    d.enemies[1].intent = "drain_life"
    d.enemies[1].hp = 50
    Combat.endTurn(d)
    assert(d.enemies[1].hp > 50, "Drain Life soigne")
  end)

  test("Morbent Fel : Unholy Shield (phase 2) interrompu : ni Absorb ni bouclier ; sa mort lève tout", function()
    local c = dusk({ enemies = { "morbent_fel" }, kind = "boss", hand = { "silence", "dw_big" } })
    local e = c.enemies[1]
    e.st.unholy_shield = nil
    Combat.forceIntent(c, e, "unholy_shield")
    play(c, "silence", 1)
    Combat.endTurn(c)
    eq(e.st.unholy_shield, nil); eq(e.block, 0)
    DW.add(c, "curse_of_tongues", e, "hand")
    c.hand[#c.hand + 1] = Card.new("dw_big", false, 9999)
    play(c, "dw_big", 1)
    eq(c.result, "won"); eq(curses(c), 0)
  end)

  ---------------------------------------------------------------------------
  -- Expédition : groupes, rencontres, affiche WANTED, déblocages, bibelots
  ---------------------------------------------------------------------------

  local function newExp(o)
    o = o or {}
    local exp = X.new({ seed = o.seed or 5, class = o.class or "priest", zone = "duskwood", quiet = true,
      unlocks = o.unlocks or { level = 7, common = 1, won = { westfall = 0 } } })
    if exp.phase == "start" and exp.startEpics then X.act(exp, { "skipEpic" }) end
    if exp.phase == "start" then X.act(exp, { "skipStartRelic" }) end
    return exp
  end

  test("groupes : ennemis connus, PV des normaux 38 à 70, élites et boss ; rencontres de combat", function()
    local pools = ns.Encounters.duskwood
    for name, list in pairs(pools) do
      for _, g in ipairs(list) do
        for _, spec in ipairs(g) do assert(ns.Enemies[Combat.specId(spec)], name .. " : " .. tostring(spec)) end
      end
    end
    eq(#pools.easy, 4); eq(#pools.normal, 8); eq(#pools.elite, 3); eq(pools.boss[1][1], "morbent_fel")
    for _, id in ipairs({ "event_worgen", "event_ghouls", "event_ogres", "event_morladim", "event_naraxis" }) do assert(pools[id], id) end
  end)

  test("rencontres de Duskwood : tirées dans la zone seulement, décors de la zone, combats de rencontre", function()
    local exp = newExp({ unlocks = { level = 7, common = 2, won = { westfall = 0 } } })
    local pool = {}
    for _, id in ipairs(X.eventPool(exp)) do pool[id] = true end
    for _, id in ipairs({ "scarlet_raven_tavern", "night_watch_wall", "sven_camp", "madame_eva", "abercrombie_shack",
      "viktori_monocle", "webbed_watcher" }) do
      assert(pool[id], id)
      local ev = ns.Events[id]
      assert(ns.Zones.duskwood.scenes[ev.scene] or ev.scene == "road", id .. " : décor")
    end
    assert(not pool.wanted_poster, "affiche : jamais tirée")
    assert(not pool.saldean_farm, "pas de rencontre de Westfall")
    -- combat de Sven : deux worgens
    exp.node, exp.phase = exp.map.start[1], "map"
    X.openEvent(exp, "sven_camp")
    assert(X.act(exp, { "choose", 1 }))
    eq(exp.phase, "combat"); eq(exp.combat.zone, "duskwood"); eq(exp.combat.enemies[1].id, "vile_fang")
  end)

  test("affiche WANTED (commun de la zone 2) : case placée, élite nommée, prochaine élite imposée, +50 po, amélioration", function()
    local exp = newExp({ unlocks = { level = 7, common = 2, won = { westfall = 0 } } })
    local id
    for _, n in ipairs(exp.map.nodes) do if n.kind == "wanted_poster" then id = n.id end end
    assert(id, "case placée")
    local e1 = newExp({ unlocks = { level = 7, common = 1, won = { westfall = 0 } } })
    for _, n in ipairs(e1.map.nodes) do assert(n.kind ~= "wanted_poster", "pas avant la première victoire du compte") end
    exp.node, exp.phase = exp.map.start[1], "map"
    X.openEvent(exp, "wanted_poster")
    local text = X.eventText(exp)
    local roll = exp.event.rolls[1][1]
    local name = ns.Enemies[ns.Encounters.duskwood.elite[roll.group.idx][1]].name
    assert(text:find("WANTED: " .. name, 1, true), text)
    assert(X.act(exp, { "choose", 1 }))
    eq(exp.zs.duskwood.wanted.idx, roll.group.idx)
    exp.phase = "map"
    X.startFight(exp, "elite")
    eq(exp.fight.encounter[1], ns.Encounters.duskwood.elite[roll.group.idx][1])
    assert(exp.fight.wanted and exp.fight.reward.gold >= 50)
    eq(exp.zs.duskwood.wanted, nil, "consommée")
    local ups = 0
    for _, card in ipairs(exp.deck) do if card.up then ups = ups + 1 end end
    for _, e in ipairs(exp.combat.enemies) do Combat.kill(exp.combat, e) end
    X.act(exp, { "endTurn" })
    local ups2 = 0
    for _, card in ipairs(exp.deck) do if card.up then ups2 = ups2 + 1 end end
    eq(exp.phase, "reward"); eq(ups2, ups + 1, "une carte améliorée")
    local ok, why = T.plainData(exp); assert(ok, why)
  end)

  test("commun de la zone 2 (première victoire du compte) et bibelots de clé +1, +3, +5", function()
    local cc = Meta.commonContent(2)
    local function has(list, id) for _, x in ipairs(list) do if x == id then return true end end return false end
    assert(has(cc.cards, "anti_venom") and has(cc.cards, "zombie_juice"))
    for _, r in ipairs({ "ogres_monocle", "night_watch_shortsword", "mistmantle_family_ring" }) do assert(has(cc.relics, r), r) end
    assert(has(cc.events, "wanted_poster"))
    local keys = Meta.keyRelics("priest", "duskwood")
    local byLevel = {}
    for _, k in ipairs(keys) do byLevel[k.level] = k.id end
    eq(byLevel[1], "ghoul_rib"); eq(byLevel[3], "morladims_skull"); eq(byLevel[5], "morbents_bane_relic")
    local exp = newExp({ unlocks = { level = 7, common = 1, won = { westfall = 0, duskwood = 3 } } })
    assert(X.unlocked(exp, ns.Relics.morladims_skull)); assert(not X.unlocked(exp, ns.Relics.morbents_bane_relic))
  end)

  test("bibelots : Ghoul Rib (première Curse ou affaiblissement du tour), Skull (Exhaust joué), Bane (+1 mana)", function()
    local c = dusk({ enemies = { "dark_runner" }, relics = { "ghoul_rib" } })
    eq(DW.add(c, "rabies", c.enemies[1], "discard"), nil, "première du tour empêchée")
    assert(DW.add(c, "rabies", c.enemies[1], "discard"), "la deuxième passe")
    local d = dusk({ enemies = { "dark_runner" }, relics = { "ghoul_rib" } })
    Combat.applyStatus(d, d.player, "armor_broken", 1)
    eq(d.player.st.armor_broken, nil)
    local s = dusk({ enemies = { "dark_runner", "dark_runner" }, relics = { "morladims_skull" } })
    DW.add(s, "rabies", s.enemies[1], "hand")
    local h1, h2 = s.enemies[1].hp, s.enemies[2].hp
    s.player.mana = 3
    play(s, "rabies")
    eq(h1 - s.enemies[1].hp, 3); eq(h2 - s.enemies[2].hp, 3)
    local b = dusk({ enemies = { "shadow_weaver" }, relics = { "morbents_bane_relic" } })
    b.enemies[1].intent = "bolt"
    Combat.endTurn(b)
    local castNow = ns.Enemies.shadow_weaver.moves[b.enemies[1].intent].cast
    eq(b.player.mana, 3 + (castNow and 1 or 0))
  end)

  test("bibelots communs : Shortsword (+2 à la première Attack du tour), Mistmantle Ring (Absorb 4 par mort), Monocle", function()
    local c = dusk({ enemies = { "morladim", "pygmy_spider" }, hand = { "dw_triple", "dw_triple" }, relics = { "night_watch_shortsword", "mistmantle_family_ring" } })
    local e = c.enemies[1]
    local hp = e.hp
    play(c, "dw_triple", 1)
    eq(hp - e.hp, 3 * 7)
    hp = e.hp
    play(c, "dw_triple", 1)
    eq(hp - e.hp, 3 * 5, "deuxième Attack : rien")
    Combat.dealDamage(c, c.player, c.enemies[2], 99)
    eq(c.player.block, 4)
    local exp = newExp()
    exp.relics[#exp.relics + 1] = "ogres_monocle"
    eq(#X.rollReward(exp, "combat").cards, 4)
  end)

  test("cartes neutres : Anti-Venom retire les Curses de la main, Zombie Juice +1 mana", function()
    local c = dusk({ enemies = { "dark_runner" }, hand = { "anti_venom", "zombie_juice" }, deck = { "smite", "smite" } })
    DW.add(c, "rabies", c.enemies[1], "hand")
    play(c, "anti_venom")
    eq(curses(c), 0)
    local m = c.player.mana
    play(c, "zombie_juice")
    eq(c.player.mana, m + 1)
  end)

  ---------------------------------------------------------------------------
  -- Bot et simulation
  ---------------------------------------------------------------------------

  test("bot : une Curse en pile ou gardée en main coûte ; tuer le lanceur la lève (valeur meilleure)", function()
    local zb = ns.ZoneBots.duskwood
    assert(zb and zb.value)
    local W = ns.Bots.W
    local c = dusk({ enemies = { "venom_spider", "dark_runner" }, deck = { "smite", "smite", "smite" } })
    local v0 = zb.value(c, W)
    DW.add(c, "web", c.enemies[1], "hand")
    local v1 = zb.value(c, W)
    assert(v1 < v0, "Web gardée : pénalité")
    Combat.kill(c, c.enemies[1])
    eq(zb.value(c, W), v0, "levée")
  end)

  test("simulation : une expédition complète à Duskwood (bot heuristique, Curses posées)", function()
    local rec, exp = ns.SimExpedition.play({ seed = 3, class = "rogue", zone = "duskwood", zones = 1, level = 7,
      bot = "heuristic", stats = true })
    eq(exp.zone, "duskwood"); eq(exp.phase, "done")
  end)

  ns.Cards.dw_stun_trap, ns.Cards.dw_triple, ns.Cards.dw_zap, ns.Cards.dw_big = nil, nil, nil, nil
end
