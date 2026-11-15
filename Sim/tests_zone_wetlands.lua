-- Tests de la zone Wetlands (mécanique Pack, docs/zones/wetlands.md) : primes réglées à la fin de l'effet,
-- morts groupées, chef et dispersion, interactions (Absorb, Parry, Stunned, incantations, Traps, DoT,
-- familier), chaque ennemi, élites, boss, rencontres, commun et bibelots de clé, case du Gryphon Master.
-- Lancés par Sim/tests_zones.lua.
return function(T)
  local ns, test, eq, combat, play = T.ns, T.test, T.eq, T.combat, T.play
  local Combat, X, Meta, WL = ns.Combat, ns.Expedition, ns.Meta, ns.Wetlands
  local E = ns.Enemies

  -- Cartes de test (sans classe)
  local C = ns.Cards
  C.wlt_hit = { id = "wlt_hit", name = "WL Hit", cost = 0, type = "attack", target = "enemy",
    effects = { { "damage", 50 } }, text = "Deal 50." }
  C.wlt_poke = { id = "wlt_poke", name = "WL Poke", cost = 0, type = "attack", target = "enemy",
    effects = { { "damage", 4 } }, text = "Deal 4." }
  C.wlt_all3 = { id = "wlt_all3", name = "WL Sweep", cost = 0, type = "attack",
    effects = { { "damage", 3, all = true } }, text = "Deal 3 to all." }
  C.wlt_twice = { id = "wlt_twice", name = "WL Twice", cost = 0, type = "attack",
    effects = { { "damage", 3, all = true, times = 2 } }, text = "Deal 3 to all twice." }
  C.wlt_nova = { id = "wlt_nova", name = "WL Nova", cost = 0, type = "attack",
    effects = { { "damage", 200, all = true } }, text = "Deal 200 to all." }
  C.wlt_trap = { id = "wlt_trap", name = "WL Trap", cost = 0, type = "skill", trap = true,
    effects = { { "damage", 50 } }, text = "Trap.\nDeal 50." }
  C.wlt_stun = { id = "wlt_stun", name = "WL Stun", cost = 0, type = "skill", target = "enemy",
    effects = { { "apply", "stunned", 1 } }, text = "Apply Stunned 1" }
  C.wlt_kick = { id = "wlt_kick", name = "WL Kick", cost = 0, type = "skill", target = "enemy",
    effects = { { "interrupt" } }, text = "Interrupt the target's cast." }

  local function bonus(id) return E[id].pack[2] end
  -- Combat des Wetlands : PV des ennemis fixés (liste), intention imposée (liste) ; joueur 60 PV.
  local function wl(enemies, o)
    o = o or {}
    local c = combat({ zone = "wetlands", enemies = enemies, hand = o.hand or { "wlt_hit" }, class = o.class,
      hp = o.hp, relics = o.relics, kind = o.kind })
    for i, e in ipairs(c.enemies) do
      if o.hpList and o.hpList[i] then e.hp = o.hpList[i] end
      if o.intents and o.intents[i] then e.intent = o.intents[i] e.interrupted = false end
    end
    return c
  end
  local function packEvents(c)
    local out = {}
    for _, ev in ipairs(c.events) do if ev.t == "pack" or ev.t == "scatter" then out[#out + 1] = ev end end
    return out
  end

  ---------------------------------------------------------------------------
  -- Règle Pack
  ---------------------------------------------------------------------------

  test("Wetlands : règle de zone active, état de zone en données simples, clone profond", function()
    local c = wl({ "mosshide_brute", "mosshide_brute" })
    eq(c.zr[1], "wetlands"); eq(type(c.zs.wetlands.queue), "table")
    local t = Combat.clone(c)
    t.zs.wetlands.queue[1] = { effect = 1 }
    eq(#c.zs.wetlands.queue, 0)
    local ok, why = T.plainData(c.zs); assert(ok, why)
  end)

  test("Pack : à la mort, chaque autre membre vivant reçoit la prime ; le solitaire jamais", function()
    local c = wl({ "mosshide_brute", "mosshide_brute", "wetlands_crocolisk" }, { hpList = { 5 } })
    play(c, "wlt_hit", 1)
    eq(c.enemies[1].dead, true)
    eq(c.enemies[2].st.force, bonus("mosshide_brute"))
    eq(c.enemies[3].st.force, nil, "crocolisk hors meute")
    local evs = packEvents(c)
    eq(#evs, 1); eq(evs[1].src, c.enemies[1].uid); eq(evs[1].dst, c.enemies[2].uid); eq(evs[1].bonus, "force")
  end)

  test("Pack : primes données à la fin de l'effet (pas entre deux coups d'une même carte)", function()
    local c = wl({ "bluegill_raider", "bluegill_raider" }, { hand = { "wlt_twice" }, hpList = { 2 } })
    local b = c.enemies[2]
    local hp = b.hp
    play(c, "wlt_twice")
    eq(hp - b.hp, 6, "les deux coups portent : l'Absorb arrive après la carte")
    eq(b.block, bonus("bluegill_raider"))
  end)

  test("Pack : morts du même effet = rien entre elles ; le survivant reçoit tout, de gauche à droite", function()
    local c = wl({ "mosshide_brute", "mottled_raptor", "dragonmaw_raider" }, { hand = { "wlt_all3" }, hpList = { 1, 2 } })
    local s = c.enemies[3]
    s.hp = 25
    play(c, "wlt_all3")
    eq(c.enemies[1].dead and c.enemies[2].dead, true)
    eq(s.st.force, bonus("mosshide_brute") + bonus("mottled_raptor"))
    local evs = packEvents(c)
    eq(#evs, 2); eq(evs[1].src, c.enemies[1].uid, "gauche d'abord"); eq(evs[2].src, c.enemies[2].uid)
    -- toute la meute en un effet : aucune prime
    local d = wl({ "mosshide_brute", "mosshide_brute" }, { hand = { "wlt_nova" } })
    play(d, "wlt_nova")
    eq(d.result, "won"); eq(#packEvents(d), 0)
  end)

  test("Pack heal : soigne les blessés, perdu sur un ennemi intact ; Absorb perdue à son tour", function()
    local c = wl({ "mosshide_mystic", "mosshide_brute", "mosshide_brute" }, { hpList = { 3 } })
    local hurt, full = c.enemies[2], c.enemies[3]
    hurt.hp = hurt.maxHp - 20
    play(c, "wlt_hit", 1)
    eq(hurt.hp, hurt.maxHp - 20 + bonus("mosshide_mystic")); eq(full.hp, full.maxHp)
    local d = wl({ "bluegill_raider", "bluegill_raider" }, { hpList = { 2 } })
    play(d, "wlt_hit", 1)
    eq(d.enemies[2].block, bonus("bluegill_raider"))
    Combat.endTurn(d)
    eq(d.enemies[2].block, 0, "perdue au début de son tour")
  end)

  test("Pack Leader : sa mort disperse la meute (sans Demoralized), primes de l'effet annulées", function()
    local c = wl({ "mosshide_brute", "mosshide_mystic", "mosshide_alpha" }, { hpList = { nil, nil, 2 } })
    play(c, "wlt_hit", 3)
    local b, m = c.enemies[1], c.enemies[2]
    assert(WL.scattered(b) and WL.scattered(m), "dispersés")
    eq(b.st.demoralized, nil, "pas de Demoralized (décisions)")
    eq(WL.member(b), false); eq(WL.bonus(b), nil)
    b.hp = 1
    Combat.addCard(c, "wlt_hit", "hand")
    play(c, "wlt_hit", 1)
    eq(m.st.force, nil, "dispersé : plus de prime")
    -- invoqué après la dispersion : arrive dispersé
    local n = Combat.spawn(c, "mottled_raptor", m)
    assert(WL.scattered(n), "invocation dispersée")
    -- chef et membre tués par le même effet : primes annulées, survivant dispersé
    local d = wl({ "mosshide_brute", "mosshide_mystic", "mosshide_alpha" }, { hand = { "wlt_all3" }, hpList = { 1, nil, 1 } })
    d.enemies[2].hp, d.enemies[2].maxHp = 40, 40
    play(d, "wlt_all3")
    eq(d.enemies[2].st.force, nil); assert(WL.scattered(d.enemies[2]))
    local evs = packEvents(d)
    eq(#evs, 1); eq(evs[1].t, "scatter")
  end)

  test("Pack : membre invoqué en cours de combat (Screech) : rejoint la meute, reçoit et donne", function()
    local c = wl({ "mottled_screecher", "mottled_raptor" }, { intents = { "screech" } })
    eq(c.enemies[1].intent, "screech")
    Combat.endTurn(c)
    eq(#c.enemies, 3, "un raptor appelé")
    local r = c.enemies[3]
    assert(WL.member(r))
    c.enemies[2].hp = 1
    Combat.addCard(c, "wlt_hit", "hand")
    play(c, "wlt_hit", 2)
    eq(r.st.force, bonus("mottled_raptor"))
  end)

  test("Screech : incantation interrompue -> aucun raptor", function()
    local c = wl({ "mottled_screecher", "mottled_raptor" }, { hand = { "wlt_kick" }, intents = { "screech" } })
    play(c, "wlt_kick", 1)
    Combat.endTurn(c)
    eq(#c.enemies, 2)
  end)

  test("DoT : mort isolée au début du tour du porteur, prime avant que les suivants agissent", function()
    local c = wl({ "mosshide_brute", "mosshide_brute" }, { hand = {}, hpList = { 3 }, intents = { "club", "club" } })
    Combat.applyStatus(c, c.enemies[1], "pain", 5)
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(c.enemies[1].dead, true)
    local club = E.mosshide_brute.moves.club.actions[1][2]
    eq(hp - c.player.hp, club + bonus("mosshide_brute"), "le second frappe avec la Strength reçue")
  end)

  test("Trap : tue pendant la phase ennemie -> prime tout de suite, l'ennemi suivant frappe plus fort", function()
    local c = wl({ "mosshide_brute", "mosshide_brute" }, { hand = { "wlt_trap" }, intents = { "club", "club" } })
    play(c, "wlt_trap")
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(c.enemies[1].dead, true)
    local club = E.mosshide_brute.moves.club.actions[1][2]
    eq(hp - c.player.hp, club + bonus("mosshide_brute"))
  end)

  test("Stunned : un ennemi étourdi reçoit la prime ; victoire : la file est perdue sans erreur", function()
    local c = wl({ "mosshide_brute", "mosshide_brute" }, { hand = { "wlt_stun", "wlt_hit" }, hpList = { 3 } })
    play(c, "wlt_stun", 2)
    play(c, "wlt_hit", 1)
    eq(c.enemies[2].st.force, bonus("mosshide_brute")); eq(c.enemies[2].st.stunned, 1)
    local d = wl({ "mosshide_brute", "mosshide_brute" }, { hand = { "wlt_nova" } })
    play(d, "wlt_nova")
    eq(d.result, "won")
  end)

  test("Familier du Hunter : attaque de fin de tour = effet à part, prime avant la phase ennemie", function()
    local c = wl({ "mosshide_brute", "mosshide_brute" }, { class = "hunter", hand = {}, hpList = { 1 },
      intents = { "club", "club" } })
    c.player.lastTarget = c.enemies[1].uid
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(c.enemies[1].dead, true, "tué par le familier")
    local club = E.mosshide_brute.moves.club.actions[1][2]
    eq(hp - c.player.hp, club + bonus("mosshide_brute"))
  end)

  test("Parry : la Strength d'une prime passe dans le coup (Parry n'annule que 8)", function()
    local c = wl({ "dragonmaw_raider", "bluegill_raider" }, { class = "rogue", hand = { "wlt_hit" }, hpList = { 1 },
      intents = { "bash", "jab" } })
    play(c, "wlt_hit", 1)
    local b = c.enemies[2]
    local jab = E.bluegill_raider.moves.jab.actions[1][2]
    eq(Combat.intentInfo(c, b).damage, jab + bonus("dragonmaw_raider"), "la bulle montre la nouvelle valeur")
    c.player.st.parry = 1
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(hp - c.player.hp, math.max(0, jab + bonus("dragonmaw_raider") - 8))
  end)

  test("Incantation ennemie : Lightning Bolt part avec la Strength reçue entre-temps", function()
    local c = wl({ "mosshide_brute", "mosshide_mystic" }, { hpList = { 1 }, intents = { "club", "bolt" } })
    eq(c.enemies[2].intent, "bolt")
    play(c, "wlt_hit", 1)
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(hp - c.player.hp, E.mosshide_mystic.moves.bolt.actions[1][2] + bonus("mosshide_brute"))
  end)

  ---------------------------------------------------------------------------
  -- Ennemis
  ---------------------------------------------------------------------------

  local ZONE_ENEMIES = { "bluegill_raider", "mosshide_brute", "mosshide_mystic", "mosshide_alpha", "mottled_screecher",
    "mottled_raptor", "dragonmaw_raider", "wetlands_crocolisk", "black_ooze", "black_slime", "mottled_scytheclaw",
    "sarltooth", "modr", "dragonmaw_centurion", "dragonmaw_bonewarder", "crimson_whelp", "nekrosh" }

  test("chaque ennemi : chaque intention se joue sans erreur (avec un allié), nom, PV, intention connue", function()
    for _, id in ipairs(ZONE_ENEMIES) do
      local d = E[id]
      assert(d.name and d.hp and d.moves, id)
      for mv in pairs(d.moves) do
        local c = wl({ id, "wetlands_crocolisk" }, { hand = {} })
        c.enemies[1].intent = mv
        c.enemies[2].hp = c.enemies[2].hp - 10
        Combat.endTurn(c)
        assert(c.result == nil or c.result == "lost", id .. " " .. mv)
      end
    end
  end)

  test("Mosshide Mystic : Healing Wave si un allié a perdu assez de PV (pas deux fois de suite), sinon Lightning Bolt", function()
    local c = wl({ "mosshide_brute", "mosshide_mystic" }, { hand = {} })
    local m = c.enemies[2]
    eq(m.intent, "bolt")
    c.enemies[1].hp = c.enemies[1].maxHp - 10
    Combat.chooseIntent(c, m)
    eq(m.intent, "wave")
    m.mem.last = "wave"
    Combat.chooseIntent(c, m)
    eq(m.intent, "bolt", "pas deux soins de suite")
  end)

  test("Mosshide Alpha : Rally (Absorb à tous), Maul, Savage Howl (Strength à tous), dans l'ordre", function()
    local c = wl({ "mosshide_brute", "mosshide_alpha" }, { hand = {} })
    eq(c.enemies[2].intent, "rally")
    Combat.endTurn(c)
    eq(c.enemies[1].block, E.mosshide_alpha.moves.rally.actions[1][2], "le Brute a agi avant : l'Absorb du Rally tient")
    eq(c.enemies[2].intent, "maul")
    Combat.endTurn(c)
    eq(c.enemies[2].intent, "howl")
    Combat.endTurn(c)
    eq(c.enemies[1].st.force, 1); eq(c.enemies[2].st.force, 1)
  end)

  test("Black Ooze : à sa mort, deux Black Slime (hors meute) ; le combat continue", function()
    local c = wl({ "black_ooze" }, { hpList = { 3 } })
    play(c, "wlt_hit", 1)
    eq(c.result, nil); eq(#c.enemies, 3)
    eq(c.enemies[2].id, "black_slime"); eq(WL.member(c.enemies[2]), false)
  end)

  ---------------------------------------------------------------------------
  -- Élites
  ---------------------------------------------------------------------------

  test("Sarltooth : chaque Scytheclaw tué le renforce ; sa mort fait fuir les Scytheclaws", function()
    local c = wl({ "mottled_scytheclaw", "sarltooth" }, { hpList = { 1 } })
    play(c, "wlt_hit", 1)
    eq(c.enemies[2].st.force, bonus("mottled_scytheclaw"))
    eq(WL.bonus(c.enemies[2]), nil, "Sarltooth ne donne rien")
    local d = wl({ "mottled_scytheclaw", "sarltooth" }, { hpList = { nil, 1 } })
    play(d, "wlt_hit", 2)
    eq(d.result, "won"); eq(d.enemies[1].fled, true)
    -- Call the Pack (3 au plus en vie... max 2) ; Rend : DoT sur le joueur
    local e = wl({ "mottled_scytheclaw", "sarltooth" }, { hand = {}, intents = { "slash", "rend" } })
    Combat.endTurn(e)
    eq(e.player.st.pain ~= nil or e.player.hp < 60, true)
  end)

  test("Modr : Earthen Charge si moins de 15 PV perdus depuis son tour, DoT compris ; Slam 6 + 8/Charge", function()
    local c = wl({ "modr" }, { hand = { "wlt_poke" } })
    local m = c.enemies[1]
    eq(m.intent, "fist")
    eq(WL.chargePending(c, m), true)
    Combat.endTurn(c)
    eq(m.st.earthen_charge, 1, "rien perdu : +1")
    -- 15 dégâts : pas de Charge
    Combat.dealDamage(c, c.player, m, 15)
    eq(WL.chargePending(c, m), false)
    Combat.endTurn(c)
    eq(m.st.earthen_charge, 1)
    -- le DoT compte (il part avant le test)
    Combat.applyStatus(c, m, "pain", 16)
    eq(WL.chargePending(c, m), false, "prévision : DoT compris")
    eq(m.intent, "slam")
    eq(Combat.intentInfo(c, m).damage, 6 + 8, "une seule Charge, aucune à venir")
    local hp0 = c.player.hp
    Combat.endTurn(c)
    eq(hp0 - c.player.hp, 14, "Seismic Slam avec 1 Charge (le DoT a empêché la 2e)")
    eq(m.st.earthen_charge, nil, "retombées à 0")
    -- Seismic Slam : intention prévue avec la Charge à venir
    local d = wl({ "modr" }, { hand = {}, intents = { "slam" } })
    local n = d.enemies[1]
    n.st.earthen_charge = 2
    eq(Combat.intentInfo(d, n).damage, 6 + 8 * 3, "2 Charges + celle du début de son tour")
    local hp = d.player.hp
    Combat.endTurn(d)
    eq(hp - d.player.hp, 30); eq(n.st.earthen_charge, nil, "retombées à 0")
    -- étourdi : le test a lieu quand même
    local e = wl({ "modr" }, { hand = {} })
    Combat.applyStatus(e, e.enemies[1], "stunned", 1)
    Combat.endTurn(e)
    eq(e.enemies[1].st.earthen_charge, 1)
  end)

  test("Dragonmaw Centurion : Wyrmscale Armor retire 10 au premier coup de chaque tour (pas le DoT), Pack", function()
    local c = wl({ "dragonmaw_raider", "dragonmaw_centurion" }, { hand = { "wlt_poke", "wlt_poke" } })
    local ce = c.enemies[2]
    assert(ce.st.wyrmscale, "prête au début du combat")
    local hp = ce.hp
    play(c, "wlt_poke", 2)
    eq(ce.hp, hp, "4 dégâts : tout pris par l'armure")
    play(c, "wlt_poke", 2)
    eq(ce.hp, hp - 4, "second coup : plein")
    Combat.applyStatus(c, ce, "pain", 3)
    Combat.endTurn(c)
    assert(ce.st.wyrmscale, "prête à nouveau au début du tour du joueur")
    eq(ce.hp, hp - 4 - 3, "le DoT n'use pas l'armure")
    -- coup de 50 : 10 retirés
    Combat.addCard(c, "wlt_hit", "hand")
    local h2 = ce.hp
    play(c, "wlt_hit", 2)
    eq(ce.hp, math.max(0, h2 - 40))
    -- la mort du Raider lui donne Strength
    local d = wl({ "dragonmaw_raider", "dragonmaw_centurion" }, { hpList = { 1 } })
    play(d, "wlt_hit", 1)
    eq(d.enemies[2].st.force, bonus("dragonmaw_raider"))
  end)

  ---------------------------------------------------------------------------
  -- Boss : Chieftain Nek'rosh
  ---------------------------------------------------------------------------

  local function boss(o)
    o = o or {}
    o.kind = "boss"
    return wl({ "nekrosh", "dragonmaw_bonewarder", "dragonmaw_bonewarder" }, o)
  end

  test("Nek'rosh : Bonewarders (sbires, Pack heal) ; leur mort soigne le boss blessé ; Bone Ward sur le boss", function()
    local c = boss({ hpList = { nil, 1 } })
    local n = c.enemies[1]
    n.hp = n.maxHp - 20
    play(c, "wlt_hit", 2)
    eq(n.hp, n.maxHp - 20 + bonus("dragonmaw_bonewarder"))
    local d = boss({ hand = {}, intents = { "cleave", "ward", "bolt" } })
    Combat.endPlayerTurn(d)
    Combat.enemyPhase(d)
    eq(d.enemies[1].block, E.dragonmaw_bonewarder.moves.ward.actions[1][2], "Absorb posée après le tour du boss")
    -- la mort du boss : victoire, les Bonewarders fuient
    local e = boss()
    e.enemies[1].hp = 1
    play(e, "wlt_hit", 1)
    eq(e.result, "won")
  end)

  test("Nek'rosh phase 2 : sous 50 %, réplique, 2 Crimson Whelps (sbires hors meute), Shadow Bolt incanté", function()
    local c = boss({ hand = { "wlt_poke" } })
    local n = c.enemies[1]
    n.hp = math.floor(n.maxHp / 2) + 2
    play(c, "wlt_poke", 1)
    eq(n.mem.phase, 1)
    local whelps = 0
    for _, e in ipairs(c.enemies) do
      if e.id == "crimson_whelp" then whelps = whelps + 1 assert(e.minion and not WL.member(e)) end
    end
    eq(whelps, 2)
    local said = false
    for _, ev in ipairs(c.events) do if ev.t == "say" and ev.text == "Whelps! Burn them!" then said = true end end
    assert(said, "réplique")
    Combat.endTurn(c)
    eq(n.intent, "shadow_bolt"); eq(E.nekrosh.moves.shadow_bolt.cast, true)
  end)

  test("Mortal Wound : soins reçus divisés par deux ; Clan Command : Strength à tous", function()
    local c = boss({ hand = {}, intents = { "cleave" } })
    Combat.endTurn(c)
    assert((c.player.st.mortal_wound or 0) > 0, "posée par Cleave")
    c.player.hp = 20
    Combat.heal(c, c.player, 9)
    eq(c.player.hp, 24, "9 -> 4")
    local d = boss({ hand = {}, intents = { "command" } })
    Combat.endTurn(d)
    local cmd = E.nekrosh.moves.command.actions[1][3]
    eq(d.enemies[1].st.force, cmd); eq(d.enemies[2].st.force, cmd)
  end)

  test("passe de difficulté (14/11/2026) : textes du boss alignés sur ses nombres, Mortal Wound 3 tours", function()
    local cmd = E.nekrosh.moves.command
    assert(cmd.text:find("Strength " .. cmd.actions[1][3] .. "%."), cmd.text)
    assert(cmd.text:find(cmd.actions[2][2] .. " Absorb"), cmd.text)
    local sb = E.nekrosh.moves.shadow_bolt.actions[1][2]
    assert(E.nekrosh.phases[1].text:find("Shadow Bolt %(" .. sb .. "%)"), E.nekrosh.phases[1].text)
    -- Mortal Wound de Nek'rosh et du Raider : 3 tours ; celle du Centurion : 2
    for _, mv in ipairs({ E.nekrosh.moves.cleave, E.nekrosh.moves.sunder, E.dragonmaw_raider.moves.strike,
      E.dragonmaw_centurion.moves.cleave }) do
      local n
      for _, a in ipairs(mv.actions) do if a[2] == "mortal_wound" then n = a[3] end end
      eq(n, mv == E.dragonmaw_centurion.moves.cleave and 2 or 3, mv.name)
    end
    -- une Mortal Wound posée sur une autre s'additionne (la blessure tient la durée annoncée)
    local c = boss({ hand = {}, intents = { "cleave" } })
    Combat.endTurn(c)
    assert((c.player.st.mortal_wound or 0) >= 2, "Mortal Wound encore là au tour du joueur")
  end)

  ---------------------------------------------------------------------------
  -- Expédition : zone jouable, rencontres, commun, bibelots de clé, Gryphon Master
  ---------------------------------------------------------------------------

  local function newExp(o)
    o = o or {}
    local exp = X.new({ seed = o.seed or 5, class = o.class or "priest", zone = "wetlands", quiet = true,
      unlocks = o.unlocks or { level = 7, common = 2, won = { westfall = 5, duskwood = 5 } } })
    if exp.phase == "start" then X.act(exp, { "skipStartRelic" }) end
    return exp
  end

  test("Wetlands jouable : groupes (easy, normal, elite, boss, rencontres), décors, nom", function()
    assert(ns.Zone.playable("wetlands"))
    local pools = ns.Encounters.wetlands
    eq(#pools.easy, 4); eq(#pools.normal, 6); eq(#pools.elite, 3); eq(#pools.boss, 1)
    for k, list in pairs(pools) do
      for _, grp in ipairs(list) do for _, id in ipairs(grp) do assert(E[ns.Combat.specId(id)], k .. " " .. tostring(id)) end end
    end
    local exp = newExp()
    eq(exp.zone, "wetlands"); eq(X.actName(exp), "Wetlands")
    eq(ns.Zones.wetlands.scenes.mine, "wetlands_gates")
  end)

  test("rencontres des Wetlands : chaque réponse se résout (combat de la zone, PV jamais sous 1)", function()
    local ids = { "halloran_skins", "ormers_revenge", "greenwarden", "dun_modr_camp", "deepwater_tavern", "sida_bag",
      "flagongut_fossil", "stoutfist_banners", "gryphon_master" }
    for _, id in ipairs(ids) do
      local ev = ns.Events[id]
      assert(ev, id)
      eq(ev.zone, id ~= "gryphon_master" and "wetlands" or nil, id .. " zone")
      for ci = 1, #ev.choices do
        local exp = newExp({ unlocks = { level = 7, common = 3, won = { westfall = 5, duskwood = 5 } } })
        exp.node, exp.phase = exp.map.start[1], "map"
        exp.gold, exp.hp = 300, 5
        X.openEvent(exp, id)
        eq(exp.event.id, id)
        local ok, why = X.act(exp, { "choose", ci })
        assert(ok or why == "relic", id .. " " .. ci .. " : " .. tostring(why))
        if exp.phase == "combat" then
          for _, e in ipairs(exp.combat.enemies) do assert(ns.Encounters.wetlands, e.id) end
          eq(exp.combat.zone, "wetlands")
        else
          assert(exp.hp >= 1, id .. " " .. ci)
        end
      end
    end
  end)

  test("commun débloqué par la première victoire du compte dans les Wetlands (tier 3)", function()
    local cc = Meta.commonContent(3)
    local function has(list, id) for _, x in ipairs(list) do if x == id then return true end end return false end
    assert(has(cc.cards, "crocolisk_gumbo") and has(cc.cards, "fire_oil"), "cartes neutres")
    assert(has(cc.relics, "crude_flint") and has(cc.relics, "young_crocolisk_skin") and has(cc.relics, "flagonguts_fossil"))
    assert(has(cc.events, "gryphon_master"), "case du Gryphon Master")
    local before = newExp({ unlocks = { level = 7, common = 2, won = {} } })
    eq(X.cardUnlocked(before, "fire_oil"), false)
    local after = newExp({ unlocks = { level = 7, common = 3, won = {} } })
    eq(X.cardUnlocked(after, "fire_oil"), true)
  end)

  test("bibelots de clé : +1, +3, +5 dans les Wetlands, débloqués par la clé gagnée", function()
    local list = Meta.keyRelics("priest", "wetlands")
    eq(#list, 3)
    eq(list[1].id, "dragonmaw_war_banner"); eq(list[2].id, "cursed_eye_of_paleth"); eq(list[3].id, "goaz_stone")
    local e2 = newExp({ unlocks = { level = 7, common = 3, won = { wetlands = 2 } } })
    eq(X.unlocked(e2, ns.Relics.dragonmaw_war_banner), true)
    eq(X.unlocked(e2, ns.Relics.cursed_eye_of_paleth), false)
  end)

  test("bibelots : Crude Flint (2 à tous à chaque mort, dans l'effet), Young Crocolisk Skin, War Banner, Goaz Stone", function()
    local c = wl({ "mosshide_brute", "mosshide_brute", "mosshide_brute" }, { relics = { "crude_flint" }, hpList = { 3, 2 } })
    play(c, "wlt_hit", 1)
    eq(c.enemies[2].dead, true, "achevé par la Flint")
    eq(c.enemies[3].st.force, 2 * bonus("mosshide_brute"), "deux morts du même effet : deux primes au survivant")
    local s = wl({ "bluegill_raider", "bluegill_raider", "bluegill_raider" }, { relics = { "young_crocolisk_skin" } })
    eq(s.player.block, 9)
    local b = wl({ "bluegill_raider", "bluegill_raider", "bluegill_raider" }, { relics = { "dragonmaw_war_banner" },
      hand = { "wlt_all3" }, hpList = { 1, 1, 1 } })
    play(b, "wlt_all3")
    eq(b.player.st.force, 2, "deux premières morts seulement")
    local g = wl({ "bluegill_raider", "bluegill_raider" }, { relics = { "goaz_stone" }, hpList = { 1 } })
    play(g, "wlt_hit", 1)
    local hand = #g.hand
    Combat.endTurn(g)
    eq(g.player.mana, Combat.BASE_MANA + 1)
  end)

  test("bibelots : Flagongut's Fossil (4 cartes après une élite), Cursed Eye (+1 mana, soins hors combat / 2)", function()
    local exp = newExp()
    exp.relics[#exp.relics + 1] = "flagonguts_fossil"
    eq(#X.rollReward(exp, "elite").cards, 4)
    eq(#X.rollReward(exp, "combat").cards, 3)
    local e2 = newExp()
    e2.relics[#e2.relics + 1] = "cursed_eye_of_paleth"
    e2.hp = 10
    e2.node, e2.phase = e2.map.start[1], "map"
    X.openEvent(e2, "greenwarden")
    X.act(e2, { "choose", 2 })
    eq(e2.hp, 10 + math.floor(15 / 2))
    local c = wl({ "mosshide_brute" }, { relics = { "cursed_eye_of_paleth" } })
    eq(c.player.mana, Combat.BASE_MANA + 1)
  end)

  test("Gryphon Master : case posée dans les zones une fois débloquée (tier 3), vol et repos", function()
    local exp = newExp({ unlocks = { level = 7, common = 3, won = {} } })
    local id
    for _, n in ipairs(exp.map.nodes) do if n.kind == "gryphon_master" then id = n.id end end
    assert(id, "case posée")
    local none = newExp({ unlocks = { level = 7, common = 2, won = {} } })
    for _, n in ipairs(none.map.nodes) do assert(n.kind ~= "gryphon_master", "pas avant le tier 3") end
    for _, ev in ipairs(X.eventPool(exp)) do assert(ev ~= "gryphon_master", "jamais tirée au hasard") end
    exp.node, exp.phase = exp.map.start[1], "map"
    exp.gold = 50
    X.openEvent(exp, "gryphon_master")
    assert(X.act(exp, { "choose", 1 }))
    eq(exp.gold, 20); eq(exp.skip, 1)
  end)

  test("simulation : une expédition complète des Wetlands (bot heuristique) se termine", function()
    local rec, exp = ns.SimExpedition.play({ seed = 4, class = "warrior", zone = "wetlands", zones = 2, level = 7,
      bot = "greedy" })
    eq(exp.phase, "done"); eq(exp.zone, "wetlands")
    local ok, why = T.plainData(exp); assert(ok, why)
  end)

  test("paliers neutres : Crocolisk Gumbo +3 coûte 0 ; Fire Oil +2 DoT 7 à tous, +3 Innate", function()
    local c = combat({ hand = { "crocolisk_gumbo" } })
    c.hand[1].up = 3
    c.player.mana, c.player.hp = 0, 40
    play(c, "crocolisk_gumbo")
    eq(c.player.hp, 50); eq(c.player.st.force, 1)
    local d = combat({ enemies = { "zt_dummy", "zt_dummy" }, hand = { "fire_oil" } })
    d.hand[1].up = 2
    play(d, "fire_oil")
    eq(d.enemies[1].st.pain, 7); eq(d.enemies[2].st.pain, 7)
    for seed = 1, 8 do
      local deck = { { id = "fire_oil", up = 3 } }
      for _ = 1, 9 do deck[#deck + 1] = { id = "smite", up = false } end
      local o = Combat.new({ seed = seed, class = "priest", hp = 60, maxHp = 60, deck = deck, encounter = { "zt_dummy" } })
      assert(T.handIndex(o, "fire_oil"), "Fire Oil+3 Innate (graine " .. seed .. ")")
    end
  end)

  -- cartes de test retirées
  for _, id in ipairs({ "wlt_hit", "wlt_poke", "wlt_all3", "wlt_twice", "wlt_nova", "wlt_trap", "wlt_stun", "wlt_kick" }) do
    C[id] = nil
  end
end
