-- Tests de la zone Swamp of Sorrows (Slumber) : règle (dormeurs, ouverture, Rude Awakening, réveils), cas
-- limites de la fiche (Absorb, Stunned, Cast, Traps, DoT, familier, coup mortel), ennemis, élites, phases du
-- boss, rencontres, commun et bibelots de clé, Dream Dust hors du marais. Lancé par Sim/tests_zones.lua.
return function(T)
  local ns, test, eq, combat, play = T.ns, T.test, T.eq, T.combat, T.play
  local Combat, Card, X, S = ns.Combat, ns.Card, ns.Expedition, ns.Swamp
  local ceil = math.ceil

  local function sw(o)
    o.zone = o.zone or "swamp"
    return combat(o)
  end
  local function zstat(c, k) return c.stats and c.stats.zone and c.stats.zone[k] or 0 end
  -- premier coup d'attaque (base) d'un move, et nombre de coups
  local function atk(id, mv)
    for _, a in ipairs(ns.Enemies[id].moves[mv].actions) do if a[1] == "attack" then return a[2], a.times or 1 end end
    return 0, 0
  end
  local function block(id, mv, k)
    local n = 0
    for _, a in ipairs(ns.Enemies[id].moves[mv].actions) do if a[1] == k then n = a[2] end end
    return n
  end
  local function idOf(c, id)
    for i, e in ipairs(c.enemies) do if e.id == id then return e, i end end
  end

  ---------------------------------------------------------------------------
  -- Règle de base
  ---------------------------------------------------------------------------

  test("Swamp : dormeur au départ (Asleep 2), intention « asleep », ouverture annoncée en gris", function()
    local c = sw({ enemies = { "sawtooth_crocolisk" } })
    local e = c.enemies[1]
    eq(e.st.asleep, 2); eq(e.intent, "asleep"); eq(e.mem.forced, "death_roll"); eq(e.mem.forcedLabel, "On waking")
    local info = Combat.intentInfo(c, e)
    eq(info.damage, 0); eq(info.kind, "sleep")
    eq(c.zr[1], "swamp")
    local ok, why = T.plainData(c.zs); assert(ok, why)
    ok, why = T.plainData(e.zs or {}); assert(ok, why)
  end)

  test("Swamp : Asleep N = N tours sans agir, réveil par le compteur sans agir, ouverture au round suivant", function()
    local c = sw({ enemies = { "sawtooth_crocolisk" }, hp = 80 })
    local e = c.enemies[1]
    Combat.endTurn(c)
    eq(c.player.hp, 80); eq(e.st.asleep, 1); eq(e.intent, "asleep")
    Combat.endTurn(c)
    eq(c.player.hp, 80, "réveil sans agir"); eq(e.st.asleep, nil); eq(e.intent, "death_roll", "ouverture annoncée")
    Combat.endTurn(c)
    eq(c.player.hp, 80 - atk("sawtooth_crocolisk", "death_roll"), "Death Roll"); eq(e.intent, "snap", "le motif reprend au début")
  end)

  test("Swamp : Rude Awakening (+50 % arrondi au supérieur, coup à une cible), réveil, ouverture dans ce round", function()
    local c = sw({ enemies = { "sawtooth_crocolisk" }, hand = { "smite" }, hp = 80, seed = 3 })
    local e = c.enemies[1]
    local hp = e.hp
    play(c, "smite", 1)
    eq(hp - e.hp, ceil(8 * 1.5)); eq(e.st.asleep, nil); eq(e.intent, "death_roll"); eq(e.mem.forced, nil)
    Combat.endTurn(c)
    eq(c.player.hp, 80 - atk("sawtooth_crocolisk", "death_roll"), "ouverture jouée dans la phase ennemie de ce round")
    eq(e.intent, "snap")
  end)

  test("Swamp : bonus au premier coup seulement (Penance : 3 coups, le premier réveille)", function()
    local c = sw({ enemies = { "swampwalker" }, hand = { "penance" } })
    local e = c.enemies[1]
    local hp = e.hp
    play(c, "penance", 1)
    eq(hp - e.hp, ceil(5 * 1.5) + 5 + 5)
  end)

  test("Swamp : un effet « to all » réveille en douceur (sans bonus, ouvertures au round suivant) ; un tic de DoT aussi", function()
    local c = sw({ enemies = { "dreaming_whelp", "dreaming_whelp" }, hand = { "holy_nova" }, hp = 80 })
    local a, b = c.enemies[1], c.enemies[2]
    local ha, hb = a.hp, b.hp
    play(c, "holy_nova")
    eq(ha - a.hp, 3); eq(hb - b.hp, 3); eq(a.st.asleep, nil); eq(b.st.asleep, nil)
    eq(a.intent, "asleep", "réveil doux : n'agit pas ce round"); eq(a.mem.forced, "dream_breath")
    Combat.endTurn(c)
    eq(c.player.hp, 80, "aucune ouverture ce round"); eq(a.intent, "dream_breath"); eq(b.intent, "dream_breath")
    local hp1 = c.player.hp
    Combat.endTurn(c)
    eq(c.player.hp, hp1 - 2 * atk("dreaming_whelp", "dream_breath") + 1, "deux ouvertures au round suivant (Regen 1)")
    -- DoT : poser ne réveille pas, le tic (début de son tour) réveille sans bonus, pas d'action ce round
    local d = sw({ enemies = { "sawtooth_crocolisk" }, hand = { "sw_pain" }, hp = 80 })
    local e = d.enemies[1]
    local hp = e.hp
    play(d, "sw_pain", 1)
    eq(e.st.asleep, 2, "poser un DoT ne réveille pas")
    Combat.endTurn(d)
    eq(hp - e.hp, 5, "tic sans bonus"); eq(e.st.asleep, nil); eq(d.player.hp, 80, "pas d'action ce round")
    eq(e.intent, "death_roll", "ouverture au round suivant")
  end)

  test("Swamp : coup entièrement absorbé réveille ; coup mortel ne réveille pas (dormeur tué avant d'agir)", function()
    local c = sw({ enemies = { "sawtooth_crocolisk", "lost_one_hunter" }, hand = { "smite" } })
    local e = c.enemies[1]
    e.block = 50
    play(c, "smite", 1)
    eq(e.block, 50 - 12, "bonus avant l'Absorb"); eq(e.st.asleep, nil, "réveillé")
    local d = Combat.new({ seed = 2, class = "priest", hp = 60, deck = { { id = "smite" } }, zone = "swamp",
      encounter = { "sawtooth_crocolisk", "lost_one_hunter" }, stats = true })
    local x = d.enemies[1]
    x.hp = 10
    Combat.play(d, 1, 1)
    eq(x.dead, true); eq(zstat(d, "killed_asleep"), 1); eq(zstat(d, "wake_hit"), 0)
  end)

  test("Swamp : Stunned sur un dormeur gèle le compteur ; Stunned sur une ouverture la retarde", function()
    local c = sw({ enemies = { "sawtooth_crocolisk" }, hp = 80 })
    local e = c.enemies[1]
    Combat.applyStatus(c, e, "stunned", 2)
    Combat.endTurn(c)
    Combat.endTurn(c)
    eq(e.st.asleep, 2, "Polymorph sur Asleep 2 : quatre tours de sommeil")
    -- ouverture retardée, pas perdue
    local d = sw({ enemies = { "sawtooth_crocolisk" }, hand = { "chastise" }, hp = 80 })
    local x = d.enemies[1]
    play(d, "chastise", 1)
    eq(x.st.asleep, nil); eq(x.intent, "death_roll")
    Combat.endTurn(d)
    eq(d.player.hp, 80, "tour perdu"); eq(x.intent, "death_roll", "ouverture gardée")
    Combat.endTurn(d)
    eq(d.player.hp, 80 - atk("sawtooth_crocolisk", "death_roll"))
  end)

  test("Swamp : Freezing Trap pendant l'ouverture : tour arrêté, ouverture rejouée ; un dormeur ne déclenche pas de Trap", function()
    local c = sw({ class = "hunter", enemies = { "sawtooth_crocolisk", "lost_one_hunter" }, hand = { "freezing_trap" }, hp = 80 })
    local e = c.enemies[1]
    play(c, "freezing_trap")
    -- le chasseur Lost One attaque : la Trap part sur lui, pas sur le dormeur
    Combat.endTurn(c)
    eq(#c.traps, 0)
    local d = sw({ class = "hunter", enemies = { "sawtooth_crocolisk" }, hand = { "freezing_trap", "arcane_shot" }, hp = 80 })
    local x = d.enemies[1]
    play(d, "arcane_shot", 1)
    eq(x.st.asleep, nil); eq(x.intent, "death_roll")
    play(d, "freezing_trap")
    Combat.endTurn(d)
    eq(d.player.hp, 80, "ouverture arrêtée"); eq(x.intent, "death_roll", "ouverture rejouée")
  end)

  test("Swamp : un Cast résolu au début du tour sur un dormeur a le bonus et l'ouverture part dans ce round", function()
    local c = sw({ enemies = { "swampwalker" }, hand = { "holy_fire" }, hp = 80 })
    local e = c.enemies[1]
    local hp = e.hp
    local d = Card.defById("holy_fire")
    play(c, "holy_fire", 1)
    assert(c.player.cast, "incantation")
    Combat.endTurn(c)
    assert(e.hp < hp, "résolu")
    eq(e.st.asleep, nil); eq(e.intent, "bog_crush")
    assert(d.cast)
  end)

  test("Swamp : familier — l'attaque automatique évite les dormeurs tant qu'un ennemi est éveillé ; commandée, elle frappe la cible", function()
    local c = sw({ class = "hunter", enemies = { "sawtooth_crocolisk", "lost_one_hunter" }, hand = { "arcane_shot" } })
    local croc, hunter = c.enemies[1], c.enemies[2]
    c.player.lastTarget = croc.uid
    eq(ns.Hunter.petTarget(c), croc, "pendant le jeu : la cible")
    c.step = "turnEnd"
    eq(ns.Hunter.petTarget(c), hunter, "auto : l'éveillé")
    c.step = "play"
    local hp = croc.hp
    play(c, "arcane_shot", 1)
    eq(hp - croc.hp, ceil(3 * 1.5) + (ns.Hunter.PET_BASE + 0), "tir avec bonus, puis le familier sans bonus")
    -- seuls des dormeurs : l'attaque automatique attend (le familier ne réveille jamais seul)
    local d = sw({ class = "hunter", enemies = { "sawtooth_crocolisk" }, hand = {} })
    local x = d.enemies[1]
    d.player.res = 3
    local hx = x.hp
    Combat.endTurn(d)
    eq(x.hp, hx); eq(x.st.asleep, 1); eq(d.player.hp, 60)
  end)

  ---------------------------------------------------------------------------
  -- Ennemis
  ---------------------------------------------------------------------------

  test("Swamp : Wyrmkin Dreamwalker — Dream Bolt +3 par allié endormi (+9 au plus) ; Lull sur l'éveillé blessé", function()
    local c = sw({ enemies = { "wyrmkin_dreamwalker", "dreaming_whelp", "dreaming_whelp", "marsh_inkspewer" }, hp = 80 })
    local dw = c.enemies[1]
    eq(dw.intent, "bolt"); eq(Combat.intentInfo(c, dw).damage, atk("wyrmkin_dreamwalker", "bolt") + 6)
    -- Lull : l'inkspewer blessé de 8 est rendormi et soigné
    local ink = c.enemies[4]
    ink.hp = ink.maxHp - 9
    dw.mem.last = nil
    Combat.chooseIntent(c, dw)
    eq(dw.intent, "lull"); assert(Combat.intentInfo(c, dw).cast)
    Combat.endTurn(c)
    -- rendormi avant son tour dans cette phase : ce tour compte déjà (« Skips its next 2 turns »)
    eq(ink.st.asleep, 1); eq(ink.hp, ink.maxHp - 1); eq(ink.zs.swamp.lulled, true)
    eq(dw.intent, "bolt", "pas deux Lull de suite")
    -- un ennemi rendormi ne l'est qu'une fois
    eq(S.lullTarget(c, dw), nil)
  end)

  test("Swamp : Lull interrompu ne fait rien ; sans cible valable à la résolution, rien", function()
    local c = sw({ enemies = { "wyrmkin_dreamwalker", "lost_one_hunter" }, hand = { "silence" }, stats = true })
    local dw, h = c.enemies[1], c.enemies[2]
    h.hp = h.maxHp - 10
    Combat.chooseIntent(c, dw)
    eq(dw.intent, "lull")
    play(c, "silence", 1)
    Combat.endTurn(c)
    eq(h.st.asleep, nil)
    Combat.chooseIntent(c, dw)
    dw.intent = "lull"
    h.hp = h.maxHp
    Combat.enemyAction(c, dw, { "lull", 2, heal = 8 })
    eq(h.st.asleep, nil, "plus de cible")
  end)

  test("Swamp : Marsh Oracle — Alarm Cry réveille tous les dormeurs pendant la phase ennemie, ouvertures au round suivant", function()
    local c = sw({ enemies = { "marsh_oracle", "sawtooth_crocolisk", "dreaming_whelp" }, hp = 80 })
    local o, croc, wh = c.enemies[1], c.enemies[2], c.enemies[3]
    eq(o.intent, "alarm_cry")
    Combat.endTurn(c)
    eq(croc.st.asleep, nil); eq(wh.st.asleep, nil)
    eq(c.player.hp, 80, "réveillés pendant la phase ennemie : aucune action")
    eq(croc.intent, "death_roll"); eq(wh.intent, "dream_breath")
    eq(o.intent, "bolt")
    Combat.endTurn(c)
    eq(c.player.hp, 80 - atk("sawtooth_crocolisk", "death_roll") - atk("dreaming_whelp", "dream_breath") - atk("marsh_oracle", "bolt"), "deux ouvertures et Lightning Bolt")
  end)

  test("Swamp : Alarm interrompue ne réveille personne", function()
    local c = sw({ enemies = { "marsh_oracle", "sawtooth_crocolisk" }, hand = { "silence" } })
    play(c, "silence", 1)
    Combat.endTurn(c)
    eq(c.enemies[2].st.asleep, 1, "toujours endormi (compteur)")
  end)

  test("Swamp : Swampwalker Asleep 3, Bog Crush interrompt ; Bog Shield protège l'allié le plus blessé", function()
    local c = sw({ enemies = { "swampwalker", "sawtooth_crocolisk" } })
    local w, croc = c.enemies[1], c.enemies[2]
    eq(w.st.asleep, 3); eq(w.mem.forced, "bog_crush")
    croc.hp = croc.maxHp - 5
    for _, a in ipairs(ns.Enemies.swampwalker.moves.shield.actions) do Combat.enemyAction(c, w, a) end
    eq(w.block, block("swampwalker", "shield", "block")); eq(croc.block, block("swampwalker", "shield", "block_wounded"))
    assert(ns.Enemies.swampwalker.moves.bog_crush.actions[1].interrupts)
  end)

  test("Swamp : ennemis normaux, groupes et rencontres valides (motifs, ouvertures, Asleep)", function()
    local pools = ns.Encounters.swamp
    for _, key in ipairs({ "easy", "normal", "elite", "boss" }) do assert(#pools[key] > 0, key) end
    eq(#pools.easy, 4); eq(#pools.normal, 6); eq(#pools.elite, 3); eq(#pools.boss, 1)
    for _, list in pairs(pools) do
      for _, enc in ipairs(list) do
        for _, spec in ipairs(enc) do
          local id = Combat.specId(spec)
          local d = ns.Enemies[id]
          assert(d, id)
          if d.opener then assert(d.moves[d.opener], id .. " : ouverture") end
          for _, mv in ipairs(d.pattern or {}) do assert(d.moves[mv], id .. " : " .. mv) end
          -- chaque groupe se joue sans erreur sur quelques tours
          local c = Combat.new({ seed = 5, class = "warrior", hp = 70, deck = {}, zone = "swamp", encounter = enc })
          for _ = 1, 6 do if not c.result then Combat.endTurn(c) end end
        end
      end
    end
    -- tarentule : DoT 3 ; inkspewer : Sundered ; chasseur : Demoralized
    local c = sw({ enemies = { "deathstrike_tarantula" }, hp = 80 })
    c.enemies[1].intent = "bite"
    Combat.endTurn(c)
    eq(c.player.hp, 80 - atk("deathstrike_tarantula", "bite") - 3, "Venomous Bite puis le tic du DoT au début du tour");
  end)

  ---------------------------------------------------------------------------
  -- Élites et boss
  ---------------------------------------------------------------------------

  test("Swamp : Lost One Chieftain dort ; sa sentinelle sonne du cor au round 1 (Alarm), serviteur", function()
    local c = sw({ enemies = { "lost_one_muckdweller", "lost_one_chieftain" }, kind = "elite", hp = 80 })
    local m, ch = c.enemies[1], c.enemies[2]
    eq(ch.st.asleep, 2); eq(m.intent, "horn"); eq(m.minion, true)
    Combat.endTurn(c)
    eq(ch.st.asleep, nil); eq(ch.intent, "spear"); eq(c.player.hp, 80)
    Combat.endTurn(c)
    eq(c.player.hp, 80 - atk("lost_one_chieftain", "spear") - atk("lost_one_muckdweller", "stab"))
  end)

  test("Swamp : Wyrmak à mi-vie s'endort APRÈS la carte (Slumber 2, soin 6 par tour de sommeil, Dream Fury)", function()
    local c = sw({ enemies = { "wyrmak" }, kind = "elite", hand = { "penance" }, hp = 90 })
    local w = c.enemies[1]
    w.hp = 60
    play(c, "penance", 1)
    eq(w.hp, 60 - 15, "les trois coups sans bonus : le sommeil tombe après la carte")
    eq(w.st.asleep, 2); eq(w.intent, "asleep"); eq(w.mem.forced, "dream_fury"); eq(w.mem.phase, 1)
    Combat.endTurn(c)
    eq(w.hp, 45 + 6); eq(w.st.asleep, 1); eq(c.player.hp, 90)
    -- Stunned sur lui endormi : compteur gelé, pas de soin
    Combat.applyStatus(c, w, "stunned", 1)
    Combat.endTurn(c)
    eq(w.hp, 51); eq(w.st.asleep, 1)
    Combat.endTurn(c)
    eq(w.hp, 57); eq(w.st.asleep, nil); eq(w.intent, "dream_fury")
    Combat.endTurn(c)
    eq(c.player.hp, 90 - 2 * atk("wyrmak", "dream_fury")); eq(w.intent, "cleave", "le motif reprend à Cleave")
  end)

  test("Swamp : Gilmorian — deux incantations (Lightning Bolt, Healing Wave), Frost Shock interrompt", function()
    local c = sw({ enemies = { "gilmorian" }, kind = "elite", hp = 80 })
    local g = c.enemies[1]
    eq(g.intent, "bolt"); assert(Combat.intentInfo(c, g).cast)
    Combat.endTurn(c)
    eq(c.player.hp, 80 - atk("gilmorian", "bolt"))
    g.hp = 50
    g.intent = "wave"
    Combat.endTurn(c)
    eq(g.hp, 70)
  end)

  test("Swamp : Somnus — Asleep 2 et Bellowing Roar ; immunisé à Stunned et à Dream Dust", function()
    local c = sw({ enemies = { "somnus" }, kind = "boss", hand = { "dream_dust", "chastise" }, hp = 90 })
    local s = c.enemies[1]
    eq(s.st.asleep, 2); eq(s.mem.forced, "roar"); eq(s.maxHp, ns.Enemies.somnus.hp)
    play(c, "dream_dust", 1)
    eq(s.st.asleep, 2, "Dream Dust sans effet sur un boss")
    play(c, "chastise", 1)
    eq(s.st.stunned, nil); eq(s.st.asleep, nil, "réveillé par le coup"); eq(s.intent, "roar")
    Combat.endTurn(c)
    eq(c.player.hp, 90 - atk("somnus", "roar")); eq(c.player.st.demoralized ~= nil, true)
    eq(s.intent, "breath")
  end)

  test("Swamp : Somnus à 74 PV — deux dragonnets éveillés, Slumber 2 (soin 5), Deep Breath, motif de la phase 3", function()
    local c = sw({ enemies = { "somnus" }, kind = "boss", hand = { "smite" }, hp = 90 })
    local s = c.enemies[1]
    S.wake(c, s, "test")
    local at = math.floor(s.maxHp * 0.5)
    s.hp = at + 5
    play(c, "smite", 1)
    eq(s.hp, at - 3); eq(#c.enemies, 3); eq(c.enemies[2].id, "somnus_whelp"); eq(c.enemies[2].minion, true)
    eq(c.enemies[2].st.asleep, nil, "dragonnets éveillés"); eq(c.enemies[2].intent, "bite")
    eq(s.st.asleep, 2); eq(s.mem.forced, "deep_breath")
    Combat.endTurn(c)
    eq(c.player.hp, 90 - 2 * atk("somnus_whelp", "bite"), "les dragonnets mordent"); eq(s.hp, at - 3 + 5)
    Combat.endTurn(c)
    eq(s.hp, at - 3 + 10); eq(s.st.asleep, nil); eq(s.intent, "deep_breath")
    Combat.endTurn(c)
    eq(s.intent, "claw2")
    -- tuer Somnus fait fuir les dragonnets
    s.hp = 1
    c.player.mana = 3
    local d = sw({ enemies = { "somnus" }, kind = "boss", hand = { "smite" } })
    d.enemies[1].hp = 5
    play(d, "smite", 1)
    eq(d.result, "won")
  end)

  ---------------------------------------------------------------------------
  -- Hors du marais : Dream Dust, Egg of Hakkar ; commun et bibelots de clé
  ---------------------------------------------------------------------------

  test("Swamp : règles actives hors du marais seulement si le combat peut endormir (Westfall intacte)", function()
    local w = combat({ zone = "westfall", enemies = { "bandit" }, hand = { "smite" } })
    eq(w.zr, nil, "Westfall sans Dream Dust : aucune règle de zone")
    local c = combat({ zone = "westfall", enemies = { "bandit", "harvest_golem" }, hand = { "dream_dust", "smite" } })
    eq(c.zr[1], "swamp")
    local b, g = c.enemies[1], c.enemies[2]
    local before = b.intent
    assert(before ~= "asleep")
    play(c, "dream_dust", 1)
    eq(b.st.asleep, 2); eq(b.intent, "asleep", "l'ennemi perd son intention"); eq(b.mem.forced, nil, "sans ouverture")
    play(c, "smite", 1)
    eq(b.st.asleep, nil); assert(b.intent ~= "asleep", "reprend son motif")
    -- élite : sans effet
    local d = combat({ zone = "westfall", enemies = { "harvest_golem" }, hand = { "dream_dust" } })
    play(d, "dream_dust", 1)
    eq(d.enemies[1].st.asleep, nil)
  end)

  test("Swamp : Dream Dust et Dreamless Sleep Potion (cartes neutres, palier 5)", function()
    local dd, dp = ns.Cards.dream_dust, ns.Cards.dreamless_sleep_potion
    eq(dd.tier, 5); eq(dd.neutral, true); eq(dd.cost, 1); eq(Card.defById("dream_dust", true).cost, 0)
    eq(dp.tier, 5); eq(dp.cost, 0)
    local c = sw({ enemies = { "lost_one_hunter" }, hand = { "dreamless_sleep_potion" } })
    c.player.hp = 30
    play(c, "dreamless_sleep_potion")
    eq(c.player.hp, 40); eq(c.player.mana, 0)
    local list = ns.Meta.commonContent(5)
    local has = {}
    for _, k in ipairs({ "cards", "relics", "potions", "events" }) do
      for _, id in ipairs(list[k] or {}) do has[id] = true end
    end
    assert(has.dream_dust and has.dreamless_sleep_potion, "cartes du commun de la zone 5")
    assert(has.green_dragonscale and has.tender_crocolisk_meat and has.atalai_artifact, "bibelots du commun")
  end)

  test("Swamp : bibelots communs (Green Dragonscale, Tender Crocolisk Meat, Atal'ai Artifact)", function()
    local c = sw({ enemies = { "lost_one_hunter" }, relics = { "green_dragonscale" }, hp = 80 })
    local h = c.enemies[1]
    h.intent = "thrust"
    Combat.endTurn(c)
    eq(c.player.hp, 80 - (atk("lost_one_hunter", "thrust") - 3), "premier coup -3")
    h.intent = "thrust"
    Combat.endTurn(c)
    eq(c.player.hp, 80 - (atk("lost_one_hunter", "thrust") - 3) - atk("lost_one_hunter", "thrust"))
    local d = sw({ enemies = { "lost_one_hunter" }, relics = { "tender_crocolisk_meat" }, kind = "elite", hand = { "smite" } })
    d.player.hp = 30
    d.enemies[1].hp = 1
    play(d, "smite", 1)
    eq(d.result, "won"); eq(d.player.hp, 38)
    local a = sw({ enemies = { "lost_one_hunter", "marsh_inkspewer" }, relics = { "atalai_artifact" } })
    eq(a.enemies[1].st.armor_broken, 1); eq(a.enemies[2].st.armor_broken, 1)
  end)

  test("Swamp : bibelots de clé (+1 Chained Essence avant le bonus, +3 Egg of Hakkar, +5 Essence of Eranikus)", function()
    eq(ns.Relics.chained_essence_of_eranikus.key.level, 1); eq(ns.Relics.egg_of_hakkar.key.level, 3)
    eq(ns.Relics.essence_of_eranikus.key.level, 5)
    local c = sw({ enemies = { "sawtooth_crocolisk" }, relics = { "chained_essence_of_eranikus" }, hand = { "smite", "smite" } })
    local e = c.enemies[1]
    local hp = e.hp
    play(c, "smite", 1)
    eq(hp - e.hp, ceil((8 + 4) * 1.5), "4 ajoutés avant le × 1,5")
    hp = e.hp
    play(c, "smite", 1)
    eq(hp - e.hp, 8)
    -- Egg of Hakkar en Westfall : l'ennemi non boss le plus robuste dort 1 tour (élite comprise)
    local w = combat({ zone = "westfall", enemies = { "gnoll", "harvest_golem" }, relics = { "egg_of_hakkar" } })
    eq(w.zr[1], "swamp"); eq(w.enemies[2].st.asleep, 1); eq(w.enemies[2].intent, "asleep")
    -- dans le marais : s'ajoute au sommeil d'un dormeur
    local s = sw({ enemies = { "swampwalker", "marsh_inkspewer" }, relics = { "egg_of_hakkar" } })
    eq(s.enemies[1].st.asleep, 4)
    -- Essence of Eranikus : +1 mana si un ennemi dort ou est étourdi
    local m = sw({ enemies = { "sawtooth_crocolisk" }, relics = { "essence_of_eranikus" } })
    eq(m.player.mana, 4)
    local n = sw({ enemies = { "lost_one_hunter" }, relics = { "essence_of_eranikus" } })
    eq(n.player.mana, 3)
  end)

  test("Swamp : rencontres (8, décors de la zone, Sleeping Camp pose Asleep 3 à tout le groupe)", function()
    local n = 0
    for id, ev in pairs(ns.Events) do
      if ev.zone == "swamp" then
        n = n + 1
        assert(ns.Zones.swamp.scenes[ev.scene:gsub("^swamp_", "")] or ev.scene:find("^swamp_"), id)
      end
    end
    eq(n, 8)
    local exp = X.new({ seed = 4, class = "warrior", zone = "swamp", unlocks = { level = 7, common = 7 }, quiet = true })
    if exp.phase == "start" and exp.startEpics then X.act(exp, { "skipEpic" }) end
    if exp.phase == "start" then X.act(exp, { "skipStartRelic" }) end
    exp.node, exp.phase = exp.map.start[1], "map"
    X.openEvent(exp, "temple_steps")
    assert(X.act(exp, { "choose", 2 }))
    eq(exp.phase, "combat")
    for _, e in ipairs(exp.combat.enemies) do eq(e.st.asleep, 3, e.id) end
    eq(exp.combat.enemies[1].id, "green_scalebane")
  end)

  test("Swamp : l'expédition se joue de bout en bout (bot heuristique)", function()
    local rec, exp = ns.SimExpedition.play({ seed = 3, class = "warrior", zone = "swamp", zones = 4, level = 7, bot = "heuristic" })
    eq(exp.phase, "done"); eq(exp.zone, "swamp")
  end)
end
