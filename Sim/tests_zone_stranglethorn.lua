-- Tests de la zone Stranglethorn Vale (le Hex) : règle (Core/ZoneRules/stranglethorn.lua), ennemis, élites, boss,
-- rencontres, commun et bibelots de clé (Data/Zones/Stranglethorn.lua). Lancé par Sim/tests_zones.lua.
return function(T)
  local ns, test, eq, combat, play = T.ns, T.test, T.eq, T.combat, T.play
  local Combat, Card, X, Meta, ST = ns.Combat, ns.Card, ns.Expedition, ns.Meta, ns.Stranglethorn
  local C = ns.Cards

  -- cartes de test (retirées à la fin)
  local TEST = {}
  local function card(id, t)
    t.id, t.name, t.type, t.rarity = id, t.name or id, t.type or "skill", "common"
    t.effects = t.effects or {}
    t.text = t.text or ""
    t.up = { text = t.text }
    C[id] = t
    TEST[#TEST + 1] = id
  end
  card("stv_c0", { cost = 0 })
  card("stv_c1", { cost = 1 })
  card("stv_c2", { cost = 2 })
  card("stv_c3", { cost = 3 })
  card("stv_c2b", { cost = 2 })
  card("stv_cast", { cost = 3, cast = true, effects = { { "absorb", 1 } } })
  card("stv_keep", { cost = 2, retain = true })
  card("stv_trap", { cost = 0, trap = true, effects = { { "damage", 1 } } })
  card("stv_bigtrap", { cost = 0, trap = true, effects = { { "damage", 200 } } })
  card("stv_kick", { cost = 0, target = "enemy", effects = { { "interrupt" } } })
  card("stv_stun", { cost = 0, target = "enemy", effects = { { "apply", "stunned", 1 } } })
  card("stv_hit", { cost = 0, type = "attack", target = "enemy", effects = { { "damage", 10 } } })
  card("stv_kill", { cost = 0, type = "attack", target = "enemy", effects = { { "damage", 200 } } })
  card("stv_dot", { cost = 0, target = "enemy", effects = { { "apply", "pain", 40 } } })
  card("stv_mana", { cost = 0, effects = { { "mana", 5 } } })

  local function hand(c, id) for i, x in ipairs(c.hand) do if x.id == id then return x, i end end end
  local function count(c, id) return Combat.countCards(c, function(i) return i.id == id end) end
  local function hexedOf(c, id)
    return Combat.countCards(c, function(i) return i.id == "hexed" and i.orig and i.orig.id == id end)
  end
  local function force(c, e, move) Combat.forceIntent(c, e, move, { now = true }) end
  -- un ennemi immobile (aucune action) pour tenir le combat ouvert
  ns.Enemies.stv_dummy = { name = "Dummy", hp = 200, moves = { idle = { name = "Idle", intent = "buff", actions = {} } }, pattern = { "idle" } }
  local function wd(c) return c.enemies[1] end
  local function setup(h, enemies, o)
    o = o or {}
    o.zone, o.hand, o.enemies = "stranglethorn", h, enemies or { "bloodscalp_witch_doctor", "stv_dummy" }
    o.deck = o.deck or { "stv_c0", "stv_c0", "stv_c0", "stv_c0", "stv_c0" }
    local c = combat(o)
    for _, e in ipairs(c.enemies) do
      if ns.Enemies[e.id].moves.hex and not o.keepIntent then force(c, e, "hex") end
    end
    return c
  end

  ---------------------------------------------------------------------------
  -- 1. Règle
  ---------------------------------------------------------------------------

  test("Stranglethorn : zone jouable, règle active, état simple et clonable", function()
    assert(ns.Zone.playable("stranglethorn"))
    local c = setup({ "stv_c1" })
    eq(c.zr[1], "stranglethorn"); eq(type(c.zs.stranglethorn.locks), "table")
    local ok, why = T.plainData(c.zs); assert(ok, why)
    local w = combat({ zone = "westfall" })
    eq(w.zs, nil, "Westfall sans règle")
  end)

  test("Hex : carte visée = la plus chère (coût actuel), la plus à gauche à égalité, jamais une Hexed", function()
    local c = setup({ "stv_c1", "stv_c2", "stv_c0", "stv_c2b" })
    eq(ST.hexTarget(c), 2, "égalité : la plus à gauche")
    play(c, "stv_c2")
    eq(c.hand[ST.hexTarget(c)].id, "stv_c2b", "la marque se déplace quand la carte est jouée")
    Combat.transformCard(c, hand(c, "stv_c2b"), "hexed")
    eq(c.hand[ST.hexTarget(c)].id, "stv_c1", "une Hexed n'est jamais visée")
    -- coût actuel : un tour gratuit met tout à 0, la plus à gauche l'emporte
    c.player.flags.freeTurnActive = true
    eq(ST.hexTarget(c), 1)
  end)

  test("Hex : verrouillé en fin de tour, résolu au tour du lanceur (défausse), carte d'origine gardée", function()
    local c = setup({ "stv_c1", "stv_c3", "stv_c0" })
    local orig = hand(c, "stv_c3")
    Combat.endTurn(c)
    eq(hexedOf(c, "stv_c3"), 1, "Hexed à la place")
    local h
    for _, x in ipairs(c.discard) do if x.id == "hexed" then h = x end end
    if not h then for _, x in ipairs(c.hand) do if x.id == "hexed" then h = x end end end
    if not h then for _, x in ipairs(c.draw) do if x.id == "hexed" then h = x end end end
    assert(h and h.orig == orig, "orig = l'instance d'origine")
    eq(Combat.findCard(c, orig), nil, "l'originale n'est plus dans les piles")
    eq(h.src, wd(c).uid)
  end)

  test("Hexed : coût 1, Skill ; jouée, la carte d'origine revient en main et la Hexed disparaît", function()
    local c = setup({ "stv_c3", "stv_c1" })
    local orig = c.hand[1]
    local h = Combat.transformCard(c, orig, "hexed", { src = wd(c).uid })
    eq(Combat.cost(c, h), 1); eq(Card.def(h).type, "skill")
    local mana = c.player.mana
    play(c, "hexed")
    eq(c.player.mana, mana - 1)
    eq(c.hand[#c.hand], orig, "originale en main, jouable tout de suite")
    eq(Combat.findCard(c, h), nil, "ni défausse ni épuisement")
    eq(c.turn.byType.skill, 1, "compte comme une Skill jouée")
    play(c, "stv_c1") -- reste du mana : 1
    eq(count(c, "hexed"), 0)
  end)

  test("Hex : deux lanceurs visent deux cartes différentes, dans l'ordre d'action", function()
    local c = setup({ "stv_c3", "stv_c2", "stv_c1" }, { "bloodscalp_witch_doctor", "skullsplitter_mystic" })
    local plan = ST.plan(c)
    eq(#plan, 2); eq(c.hand[plan[1].index].id, "stv_c3"); eq(c.hand[plan[2].index].id, "stv_c2")
    Combat.endTurn(c)
    eq(hexedOf(c, "stv_c3"), 1); eq(hexedOf(c, "stv_c2"), 1); eq(hexedOf(c, "stv_c1"), 0)
  end)

  test("Hex : un Interrupt l'annule (marque retirée aussitôt, rien de verrouillé)", function()
    local c = setup({ "stv_kick", "stv_c3" })
    eq(#ST.plan(c), 1)
    play(c, "stv_kick", 1)
    eq(#ST.plan(c), 0, "plus de carte visée")
    Combat.endTurn(c)
    eq(count(c, "hexed"), 0)
  end)

  test("Hex : un lanceur étourdi perd son tour, rien de verrouillé", function()
    local c = setup({ "stv_stun", "stv_c3" })
    play(c, "stv_stun", 1)
    eq(#ST.plan(c), 0)
    Combat.endTurn(c)
    eq(count(c, "hexed"), 0)
  end)

  test("Hex : main vide au verrouillage -> « The hex finds no card. », rien", function()
    local c = setup({ "stv_c0" })
    play(c, "stv_c0")
    local n0 = #c.events
    Combat.endTurn(c)
    local fizz = false
    for i = n0 + 1, #c.events do if c.events[i].t == "hex_fizzle" and c.events[i].why == "empty" then fizz = true end end
    assert(fizz, "journal hex_fizzle")
    eq(count(c, "hexed"), 0)
  end)

  test("Hex : lanceur tué par son DoT au début de son tour -> Hex perdu, carte intacte", function()
    local c = setup({ "stv_dot", "stv_c3" })
    play(c, "stv_dot", 1)
    Combat.endTurn(c)
    assert(wd(c).dead, "mort du DoT")
    eq(count(c, "hexed"), 0); eq(count(c, "stv_c3"), 1)
    eq(next(c.zs.stranglethorn.locks), nil, "verrous effacés")
  end)

  test("Hex : carte Retain visée -> Hexed en main ; Absorb ne protège pas ; Trap posée intacte", function()
    local c = setup({ "stv_keep", "stv_c1", "stv_trap" })
    play(c, "stv_trap")
    c.player.block = 30
    local orig = hand(c, "stv_keep")
    Combat.endTurn(c)
    local h = hand(c, "hexed")
    assert(h and h.orig == orig, "Hexed en main (Retain)")
    eq(#c.traps, 1, "le Hex ne déclenche pas la Trap")
  end)

  test("Hex : une carte en incantation n'est pas en main, intouchable", function()
    local c = setup({ "stv_mana", "stv_cast", "stv_c1" })
    play(c, "stv_mana")
    play(c, "stv_cast")
    Combat.endTurn(c)
    eq(hexedOf(c, "stv_c1"), 1); eq(hexedOf(c, "stv_cast"), 0)
  end)

  test("Hex : le familier du Hunter frappe avant le verrouillage ; s'il tue le lanceur, rien", function()
    local c = setup({ "stv_c3" }, nil, { class = "hunter" })
    wd(c).hp = 1
    Combat.endTurn(c)
    assert(wd(c).dead, "tué par le familier")
    eq(count(c, "hexed"), 0)
  end)

  test("Hex : hors de Stranglethorn (Gurubashi Arena ailleurs), l'action ne fait rien", function()
    local c = combat({ zone = "westfall", hand = { "stv_c3" }, enemies = { "bloodscalp_witch_doctor", "stv_dummy" } })
    force(c, c.enemies[1], "hex")
    Combat.endTurn(c)
    eq(count(c, "hexed"), 0)
  end)

  ---------------------------------------------------------------------------
  -- 2. Ennemis normaux
  ---------------------------------------------------------------------------

  test("Headhunter : Take a Trophy = base + 3 par carte Hexed (main, pioche, défausse)", function()
    local c = setup({ "stv_c1", "stv_c2" }, { "bloodscalp_headhunter" })
    local e = c.enemies[1]
    force(c, e, "trophy")
    local base = ns.Enemies.bloodscalp_headhunter.moves.trophy.actions[1][2]
    eq(Combat.intentInfo(c, e).damage, base)
    Combat.transformCard(c, c.hand[1], "hexed")
    Combat.transformCard(c, c.draw[1], "hexed")
    eq(Combat.intentInfo(c, e).damage, base + 6, "recalculé")
    play(c, "hexed")
    eq(Combat.intentInfo(c, e).damage, base + 3, "une récupérée")
  end)

  test("Zanzil Naga : Death Hex tué pendant le tour (plus chère en main) ; par DoT ou Trap : rien", function()
    local c = setup({ "stv_kill", "stv_c3", "stv_c1" }, { "zanzil_naga", "stv_dummy" })
    play(c, "stv_kill", 1)
    eq(hexedOf(c, "stv_c3"), 1, "Death Hex"); eq(hexedOf(c, "stv_c1"), 0)
    -- main vide : rien
    local d = setup({ "stv_kill" }, { "zanzil_naga", "stv_dummy" })
    play(d, "stv_kill", 1)
    eq(count(d, "hexed"), 0)
    -- DoT
    local f = setup({ "stv_dot", "stv_c3" }, { "zanzil_naga", "stv_dummy" })
    play(f, "stv_dot", 1)
    Combat.endTurn(f)
    assert(f.enemies[1].dead); eq(count(f, "hexed"), 0)
    -- Trap
    local g = setup({ "stv_bigtrap", "stv_c3" }, { "zanzil_naga", "stv_dummy" })
    play(g, "stv_bigtrap")
    force(g, g.enemies[1], "trident")
    Combat.endTurn(g)
    assert(g.enemies[1].dead); eq(count(g, "hexed"), 0)
  end)

  test("Skullsplitter Mystic : Hex d'abord, puis Healing Wave si un allié a perdu 8 PV, sinon Lightning Bolt", function()
    local c = setup({ "stv_c1" }, { "skullsplitter_mystic", "lashtail_raptor" }, { keepIntent = true })
    local m = c.enemies[1]
    eq(m.intent, "hex")
    Combat.endTurn(c)
    eq(m.intent, "bolt", "aucun allié blessé")
    c.enemies[2].hp = c.enemies[2].maxHp - 8
    Combat.endTurn(c)
    eq(m.intent, "hex")
    Combat.endTurn(c)
    eq(m.intent, "wave")
  end)

  test("Shadowmaw Panther et King Bangalash ouvrent par leur plus gros coup ; Swashbuckler coupe un Cast", function()
    for s = 1, 3 do
      local c = combat({ zone = "stranglethorn", seed = s * 17, enemies = { "shadowmaw_panther", "king_bangalash" } })
      eq(c.enemies[1].intent, "ravage"); eq(c.enemies[2].intent, "pounce")
    end
    local c = combat({ zone = "stranglethorn", hand = { "stv_mana", "stv_cast" }, enemies = { "bloodsail_swashbuckler" } })
    play(c, "stv_mana"); play(c, "stv_cast")
    force(c, c.enemies[1], "kick")
    Combat.endTurn(c)
    eq(c.player.cast, nil, "Kick : incantation coupée")
  end)

  test("Gorille : Beat Chest donne Strength 2 ; Raptor : Lashing Tail 4 × 2", function()
    local c = combat({ zone = "stranglethorn", enemies = { "mistvale_gorilla" } })
    force(c, c.enemies[1], "beat_chest")
    Combat.endTurn(c)
    eq(c.enemies[1].st.force, 2); eq(c.enemies[1].block, 8)
    local r = combat({ zone = "stranglethorn", enemies = { "lashtail_raptor" } })
    force(r, r.enemies[1], "tail")
    local info = Combat.intentInfo(r, r.enemies[1])
    eq(info.damage, 4); eq(info.times, 2)
  end)

  ---------------------------------------------------------------------------
  -- 3. Élites
  ---------------------------------------------------------------------------

  test("King Bangalash : Pounce, Rake, Call the Pride (2 tigres), Maul ; Roar si les deux tigres vivent", function()
    local c = combat({ zone = "stranglethorn", enemies = { "king_bangalash" }, hp = 200 })
    local b = c.enemies[1]
    local seen = {}
    for _ = 1, 4 do seen[#seen + 1] = b.intent Combat.endTurn(c) end
    eq(table.concat(seen, ","), "pounce,rake,call,maul")
    local tigers = 0
    for _, e in ipairs(c.enemies) do if e.id == "young_stranglethorn_tiger" and not e.dead then tigers = tigers + 1 end end
    eq(tigers, 2)
    Combat.endTurn(c) -- pounce
    Combat.endTurn(c) -- rake
    eq(b.intent, "roar", "deux tigres vivants : Roar")
  end)

  test("Mokk : à 49 PV, Berserk (Strength 3), puis seulement Thrash et Pound", function()
    local c = combat({ zone = "stranglethorn", enemies = { "mokk_the_savage" }, hand = { "stv_hit" }, hp = 300 })
    local m = c.enemies[1]
    m.hp = 58
    play(c, "stv_hit", 1)
    eq(m.mem.phase, 1); eq(m.st.force, 3)
    local seen = {}
    for _ = 1, 4 do Combat.endTurn(c) seen[#seen + 1] = m.intent end
    for _, mv in ipairs(seen) do assert(mv == "thrash" or mv == "pound", mv) end
  end)

  test("Zanzil the Outcast : un Hex qui passe lève un zombie ; interrompu : rien ; sa mort : victoire", function()
    local c = setup({ "stv_c3" }, { "zanzil_the_outcast" })
    Combat.endTurn(c)
    eq(hexedOf(c, "stv_c3"), 1)
    local z = 0
    for _, e in ipairs(c.enemies) do if e.id == "zanzil_zombie" then z = z + 1 end end
    eq(z, 1, "zombie levé")
    local d = setup({ "stv_kick", "stv_c3" }, { "zanzil_the_outcast" })
    play(d, "stv_kick", 1)
    Combat.endTurn(d)
    eq(#d.enemies, 1, "interrompu : aucun zombie")
    -- mort de Zanzil : les zombies fuient
    local e = setup({ "stv_c3" }, { "zanzil_the_outcast" })
    Combat.endTurn(e)
    e.hand[#e.hand + 1] = Card.new("stv_kill", false, 999)
    Combat.play(e, #e.hand, 1)
    eq(e.result, "won")
  end)

  ---------------------------------------------------------------------------
  -- 4. Boss : Jin'do the Hexxer
  ---------------------------------------------------------------------------

  test("Jin'do : immunisé à Stunned (seul l'Interrupt arrête son Hex)", function()
    local c = setup({ "stv_stun", "stv_c3" }, { "jindo" }, { kind = "boss" })
    play(c, "stv_stun", 1)
    eq(c.enemies[1].st.stunned, nil)
    eq(#ST.plan(c), 1)
  end)

  test("Jin'do phase 1 : Hex, Shadow Bolt, Healing Ward (Bolt si un Ward vit), Delusions ; le Ward le soigne", function()
    local c = combat({ zone = "stranglethorn", kind = "boss", enemies = { "jindo" }, hp = 400 })
    local j = c.enemies[1]
    local seen = {}
    for _ = 1, 4 do seen[#seen + 1] = j.intent Combat.endTurn(c) end
    eq(table.concat(seen, ","), "hex,bolt,ward,delusion")
    local ward
    for _, e in ipairs(c.enemies) do if e.id == "healing_ward" then ward = e end end
    assert(ward and ward.minion, "Ward invoqué (serviteur)")
    j.hp = 100
    Combat.endTurn(c) -- hex ; le Ward soigne
    eq(j.hp, 100 + ns.Enemies.healing_ward.moves.heal.actions[1][2])
    Combat.endTurn(c) -- bolt
    eq(j.intent, "bolt", "un Ward vit : Shadow Bolt à la place")
  end)

  test("Jin'do : Delusions coupe l'incantation en cours, sinon frappe ; Shadow Volley coupe même à travers l'Absorb", function()
    local c = combat({ zone = "stranglethorn", kind = "boss", enemies = { "jindo" }, hand = { "stv_mana", "stv_cast" }, hp = 200 })
    local j = c.enemies[1]
    play(c, "stv_mana"); play(c, "stv_cast")
    force(c, j, "delusion")
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(c.player.cast, nil, "coupée"); eq(c.player.hp, hp, "pas de dégâts quand elle coupe")
    force(c, j, "delusion")
    Combat.endTurn(c)
    assert(c.player.hp < hp, "sans incantation : dégâts")
    local d = combat({ zone = "stranglethorn", kind = "boss", enemies = { "jindo" }, hand = { "stv_mana", "stv_cast" }, hp = 200 })
    play(d, "stv_mana"); play(d, "stv_cast")
    d.player.block = 99
    force(d, d.enemies[1], "volley")
    Combat.endTurn(d)
    eq(d.player.cast, nil, "Volley : coupée malgré l'Absorb")
    -- Shadow Bolt : coupe aussi à travers l'Absorb
    local b = combat({ zone = "stranglethorn", kind = "boss", enemies = { "jindo" }, hand = { "stv_mana", "stv_cast" }, hp = 200 })
    play(b, "stv_mana"); play(b, "stv_cast")
    b.player.block = 99
    force(b, b.enemies[1], "bolt")
    Combat.endTurn(b)
    eq(b.player.cast, nil, "Shadow Bolt : coupée malgré l'Absorb")
    -- Delusions sans incantation : un coup ordinaire (Absorb, Parry, Trap)
    local a = combat({ zone = "stranglethorn", kind = "boss", enemies = { "jindo" }, hp = 200 })
    a.player.block = 99
    local ahp = a.player.hp
    force(a, a.enemies[1], "delusion")
    Combat.endTurn(a)
    eq(a.player.hp, ahp, "Delusions : arrêtée par l'Absorb")
  end)

  test("Jin'do à 88 PV : Brain Wash Totem (« Your soul belongs to Hakkar! »), puis Volley, Hex, Bolt ; deux Hex", function()
    local c = setup({ "stv_hit", "stv_c3", "stv_c2", "stv_c1" }, { "jindo" }, { kind = "boss", hp = 300 })
    local j = c.enemies[1]
    j.hp = 70
    play(c, "stv_hit", 1)
    eq(j.mem.phase, 1)
    local totem
    for _, e in ipairs(c.enemies) do if e.id == "brain_wash_totem" then totem = e end end
    assert(totem and totem.intent == "wash", "totem invoqué, Brain Wash annoncé")
    local said = false
    for _, ev in ipairs(c.events) do if ev.t == "say" and ev.text == "Your soul belongs to Hakkar!" then said = true end end
    assert(said)
    eq(#ST.plan(c), 2, "Hex de Jin'do et Brain Wash")
    Combat.endTurn(c)
    eq(hexedOf(c, "stv_c3"), 1); eq(hexedOf(c, "stv_c2"), 1)
    eq(j.intent, "volley")
    -- le totem peut être étourdi (pas un boss)
    Combat.applyStatus(c, totem, "stunned", 1)
    eq(totem.st.stunned, 1)
  end)

  ---------------------------------------------------------------------------
  -- 5. Commun, bibelots de clé
  ---------------------------------------------------------------------------

  test("Jungle Remedy : rend toutes les Hexed en main (pleine : défausse), retire les effets négatifs, pioche", function()
    local c = setup({ "jungle_remedy", "stv_c3", "stv_c2" }, nil, { deck = { "stv_c0", "stv_c0", "stv_c1" } })
    local a, b = c.hand[2], c.hand[3]
    Combat.transformCard(c, a, "hexed")
    local drawn = c.draw[1]
    Combat.transformCard(c, drawn, "hexed")
    Combat.applyStatus(c, c.player, "demoralized", 2)
    play(c, "jungle_remedy")
    eq(count(c, "hexed"), 0); eq(c.player.st.demoralized, nil)
    assert(hand(c, "stv_c3") and hand(c, "stv_c2"), "originales en main")
    eq(Combat.findCard(c, drawn), "hand")
  end)

  test("Rumsey Rum : 6 Absorb, Exhaust ; neutres et bibelots du palier 4 ; bibelots de clé +1 +3 +5", function()
    local c = combat({ zone = "stranglethorn", hand = { "rumsey_rum_black_label" } })
    play(c, "rumsey_rum_black_label")
    eq(c.player.block, 6); eq(c.exhaust[1].id, "rumsey_rum_black_label")
    local cc = Meta.commonContent(4)
    eq(table.concat(cc.cards, ","), "jungle_remedy,rumsey_rum_black_label")
    eq(#cc.relics, 3); eq(cc.events[1], "gurubashi_arena")
    local kr = Meta.keyRelics("mage", "stranglethorn")
    eq(#kr, 3); eq(kr[1].id, "nesingwary_4000"); eq(kr[2].id, "jindos_bag_of_whammies"); eq(kr[3].id, "zandalarian_hero_charm")
    eq(kr[3].level, 5)
  end)

  test("Green Hills : 6 cartes au premier tour ; Gorilla Fang : +2 par coup au premier tour seulement", function()
    local deck = {}
    for _ = 1, 12 do deck[#deck + 1] = { id = "stv_c0", up = false } end
    local c = Combat.new({ seed = 3, class = "priest", hp = 50, deck = deck, encounter = { "stv_dummy" }, zone = "stranglethorn",
      relics = { "green_hills_of_stranglethorn" } })
    eq(#c.hand, 6)
    Combat.endTurn(c)
    eq(#c.hand, 5)
    local g = combat({ zone = "stranglethorn", hand = { "stv_hit", "stv_hit" }, enemies = { "stv_dummy" }, relics = { "gorilla_fang" } })
    play(g, "stv_hit", 1)
    eq(g.enemies[1].hp, 200 - 12)
  end)

  test("Shrunken Head : la première incantation ennemie du combat échoue (une seule)", function()
    local c = combat({ zone = "stranglethorn", hand = { "stv_c3" }, enemies = { "zanzil_the_outcast" }, relics = { "shrunken_head" } })
    local z = c.enemies[1]
    eq(z.intent, "hex"); eq(z.interrupted, true, "Hex annoncé déjà interrompu")
    eq(#ST.plan(c), 0)
    Combat.endTurn(c) -- bolt
    Combat.endTurn(c) -- hex : celui-ci passe
    eq(z.intent, "hex"); eq(z.interrupted, false)
  end)

  test("Nesingwary 4000 : 10 à l'ennemi le plus solide (boss compris) ; Bag of Whammies ; Hero Charm", function()
    local c = combat({ zone = "stranglethorn", kind = "boss", enemies = { "lashtail_raptor", "jindo" }, relics = { "nesingwary_4000" } })
    eq(c.enemies[2].hp, c.enemies[2].maxHp - 10)
    local d = setup({ "stv_kick", "stv_c1" }, nil, { relics = { "jindos_bag_of_whammies" }, deck = { "stv_c2" } })
    local mana, n = d.player.mana, #d.hand
    play(d, "stv_kick", 1)
    eq(d.player.mana, mana + 1); eq(#d.hand, n, "pioche 1 (la carte jouée remplacée)")
    local e = combat({ zone = "stranglethorn", relics = { "zandalarian_hero_charm" } })
    eq(Combat.retainPicks(e), 1)
  end)

  test("Hero Charm : la carte gardée au choix coûte 1 de moins au tour suivant seulement (minimum 0)", function()
    local charm = { relics = { "zandalarian_hero_charm" } }
    local c = setup({ "stv_c3", "stv_c0", "stv_keep" }, { "stv_dummy" }, charm)
    local c3, keep = c.hand[1], c.hand[3]
    assert(#ns.Relics.zandalarian_hero_charm.text <= 80, "texte de 80 caractères au plus")
    eq(Combat.cost(c, c3), 3, "rien avant d'être gardée")
    assert(Combat.markRetain(c, c3.uid))
    Combat.endTurn(c)
    eq(Combat.findCard(c, c3), "hand")
    eq(Combat.cost(c, c3), 2, "gardée au choix : -1 au tour suivant")
    eq(Combat.cost(c, keep), 2, "carte Retain : pas de réduction")
    eq(c.relicState.hero_charm_uid, c3.uid, "réduction portée par l'état du combat (uid)")
    eq(c3.cost, nil, "instance inchangée")
    -- clone et sauvegarde : données simples, la copie garde la réduction sans toucher l'originale
    local ok, why = T.plainData(c.relicState); assert(ok, why)
    local d = Combat.clone(c)
    eq(Combat.cost(d, c3), 2, "clone : réduction gardée")
    d.relicState.hero_charm_uid = nil
    eq(Combat.cost(c, c3), 2, "clone indépendant")
    -- pas jouée ce tour-là : perdue au tour d'après, même si la carte revient en main
    Combat.endTurn(c)
    eq(Combat.cost(c, c3), 3, "réduction perdue au tour d'après")
    -- minimum 0 : une carte gratuite le reste
    local z = hand(c, "stv_c0")
    assert(z and Combat.markRetain(c, z.uid))
    Combat.endTurn(c)
    eq(Combat.findCard(c, z), "hand")
    eq(Combat.cost(c, z), 0, "minimum 0")
    eq(Combat.cost(c, c3), 3, "seule la carte choisie")
  end)

  test("Hero Charm : jouée, la réduction disparaît ; Traveler's Backpack en plus : un seul choix, -1", function()
    local c = setup({ "stv_c3", "stv_c1" }, { "stv_dummy" }, { relics = { "zandalarian_hero_charm" } })
    local c3 = c.hand[1]
    assert(Combat.markRetain(c, c3.uid))
    Combat.endTurn(c)
    local mana = c.player.mana
    play(c, "stv_c3")
    eq(c.player.mana, mana - 2, "payée 2")
    eq(c.relicState.hero_charm_uid, nil, "réduction consommée")
    eq(Combat.cost(c, c3), 3, "ne suit pas la carte dans la défausse")
    -- les deux bibelots : retainPicks = 2, mais un seul choix ; la carte gardée reçoit la réduction (-1)
    local b = setup({ "stv_c3", "stv_c2" }, { "stv_dummy" }, { relics = { "travelers_backpack", "zandalarian_hero_charm" } })
    eq(Combat.retainPicks(b), 2)
    local b3, b2 = b.hand[1], b.hand[2]
    assert(Combat.markRetain(b, b3.uid))
    assert(Combat.markRetain(b, b2.uid), "le second choix remplace le premier")
    Combat.endTurn(b)
    eq(Combat.findCard(b, b2), "hand"); eq(Combat.findCard(b, b3), "discard", "une seule carte gardée")
    eq(Combat.cost(b, b2), 1, "-1, pas -2")
    -- Traveler's Backpack seul : aucune réduction
    local t = setup({ "stv_c3" }, { "stv_dummy" }, { relics = { "travelers_backpack" } })
    local t3 = t.hand[1]
    assert(Combat.markRetain(t, t3.uid))
    Combat.endTurn(t)
    eq(Combat.findCard(t, t3), "hand"); eq(Combat.cost(t, t3), 3)
  end)

  test("Hero Charm : carte gardée puis Hexed, la Hexed coûte 1 et l'originale rendue n'a plus de réduction", function()
    local c = setup({ "stv_c3", "stv_c1" }, nil, { relics = { "zandalarian_hero_charm" } })
    local c3 = c.hand[1]
    assert(Combat.markRetain(c, c3.uid))
    Combat.endTurn(c)
    local h = hand(c, "hexed")
    assert(h and h.orig == c3, "la carte gardée est Hexed en main")
    eq(Combat.cost(c, h), 1, "Hexed : coût 1, sans réduction")
    eq(c.relicState.hero_charm_uid, nil, "réduction effacée par le Hex")
    play(c, "hexed")
    eq(Combat.findCard(c, c3), "hand"); eq(Combat.cost(c, c3), 3)
  end)

  test("Hero Charm : le bot garde de préférence une carte de coût 1 ou plus", function()
    local function pick(relic)
      local c = setup({ "stv_c1" }, { "stv_dummy" }, { relics = { relic } })
      c.hand = { Card.new("stv_c0", true, 900), Card.new("stv_c1", false, 901) }
      return ns.Bots.retainPick(c)
    end
    eq(pick("travelers_backpack"), 900, "sans le Charm : la carte améliorée à 0")
    eq(pick("zandalarian_hero_charm"), 901, "avec le Charm : la carte de coût 1")
  end)

  ---------------------------------------------------------------------------
  -- 6. Expédition : rencontres, Gurubashi Arena, décors, boss
  ---------------------------------------------------------------------------

  local function newExp(o)
    o = o or {}
    local exp = X.new({ seed = o.seed or 5, class = o.class or "priest", zone = o.zone or "stranglethorn",
      unlocks = o.unlocks or Meta.allUnlocked(7, 3), quiet = true })
    if exp.phase == "start" then X.act(exp, { "skipStartRelic" }) end
    return exp
  end

  test("Rencontres : huit dans la zone, combats valides, tirables ; Gurubashi Arena jamais tirée", function()
    local ids = {}
    for id, ev in pairs(ns.Events) do if ev.zone == "stranglethorn" then ids[#ids + 1] = id end end
    eq(#ids, 8)
    local pools = ns.Encounters.stranglethorn
    for _, id in ipairs(ids) do
      for _, ch in ipairs(ns.Events[id].choices) do
        for _, e in ipairs(ch.effects) do
          if e[1] == "fight" then assert(pools[e[2]], id .. " : groupe " .. e[2]) end
        end
      end
    end
    local exp = newExp()
    local pool = {}
    for _, id in ipairs(X.eventPool(exp)) do pool[id] = true end
    assert(pool.booty_bay_docks and pool.nesingwary_expedition and not pool.gurubashi_arena)
    local w = newExp({ zone = "westfall" })
    for _, id in ipairs(X.eventPool(w)) do assert(ns.Events[id].zone ~= "stranglethorn", id) end
  end)

  test("Gurubashi Arena : case placée (palier 4, toutes zones, étape 3+), groupe vu, +15 % PV, cartes d'un cran, +25 po", function()
    local exp = newExp({ unlocks = Meta.allUnlocked(7, 4) })
    local node
    for _, n in ipairs(exp.map.nodes) do if n.kind == "gurubashi_arena" then node = n end end
    assert(node and node.floor >= 3, "case placée")
    local before = newExp({ unlocks = Meta.allUnlocked(7, 3) })
    for _, n in ipairs(before.map.nodes) do assert(n.kind ~= "gurubashi_arena", "pas avant la victoire") end
    local w = newExp({ zone = "westfall", unlocks = Meta.allUnlocked(7, 4) })
    local wn
    for _, n in ipairs(w.map.nodes) do if n.kind == "gurubashi_arena" then wn = n end end
    assert(wn, "case commune à toutes les zones")
    -- entrée : groupe tiré, texte, combat
    exp.node, exp.phase = exp.map.start[1], "map"
    X.openEvent(exp, "gurubashi_arena")
    local text = X.eventText(exp)
    assert(not text:find("%g", 1, true) and text:find("Today's fighters: ", 1, true), text)
    local g = exp.event.rolls[1][1].group
    assert(g and g.pool == "normal")
    assert(X.act(exp, { "choose", 1 }))
    eq(exp.phase, "combat")
    local spec = ns.Encounters.stranglethorn.normal[g.idx]
    local e1 = exp.combat.enemies[1]
    local def = ns.Enemies[e1.id]
    local hi = type(def.hp) == "table" and def.hp[2] or def.hp
    assert(e1.maxHp > hi, "PV + 15 %")
    assert(exp.fight.reward.gold >= 25)
    for _, id in ipairs(exp.fight.reward.cards) do assert(C[id].rarity ~= "common", "cartes d'un cran") end
    eq(e1.id, Combat.specId(spec[1]))
  end)

  test("Décors : la zone porte ses décors peints ; boss Jin'do ; le Hex des bots joue sans erreur", function()
    local Z = ns.Zones.stranglethorn
    for _, k in ipairs({ "road", "hill", "camp", "shop", "night", "mine", "coast", "ruins" }) do
      assert(Z.scenes[k], "décor " .. k)
    end
    eq(ns.Encounters.stranglethorn.boss[1][1], "jindo")
    local rec, exp = ns.SimExpedition.play({ seed = 4, class = "rogue", zone = "stranglethorn", zones = 3, bot = "greedy" })
    eq(exp.phase, "done"); eq(exp.zone, "stranglethorn")
  end)

  test("Bots : une carte Hexed coûte à l'évaluation ; le Hex se lit dans le combat cloné", function()
    local zb = ns.ZoneBots.stranglethorn
    assert(zb and zb.value, "conseils du bot")
    local c = setup({ "stv_c3", "stv_c1" })
    local v0 = zb.value(c, ns.Bots.W)
    Combat.transformCard(c, c.hand[1], "hexed")
    assert(zb.value(c, ns.Bots.W) < v0, "pénalité de la Hexed")
    local t = Combat.clone(c)
    Combat.endTurn(t)
    eq(count(c, "hexed"), 1, "l'original n'a pas bougé")
  end)

  -- ménage
  for _, id in ipairs(TEST) do C[id] = nil end
  ns.Enemies.stv_dummy = nil
end
