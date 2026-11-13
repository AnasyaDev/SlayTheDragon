-- Tests de la zone Burning Steppes (Wildfire) : règle (compte à rebours, embrasement, brûlure, morts, Stoke,
-- Douse, Ignite), interactions (Absorb, Parry, Pain Suppression, Stunned, Cast interrompu, Traps, DoT,
-- familier, Rage, Feign Death), chaque ennemi, élite et phase du boss, rencontres, déblocages, bot.
-- Lancé par Sim/tests_zones.lua (T : docs/zones.md, § 8).
return function(T)
  local ns, test, eq, combat, play = T.ns, T.test, T.eq, T.combat, T.play
  local Combat, X, Meta, WF = ns.Combat, ns.Expedition, ns.Meta, ns.Wildfire
  local E = ns.Enemies

  -- Ennemis de test : sans action, frappeur, attiseur (Stoke 1 en attaque, Stoke 2 en Cast).
  E.sz_idle = { name = "Idle", hp = 60, moves = { idle = { name = "Idle", intent = "buff", actions = {} } }, pattern = { "idle" } }
  E.sz_small = { name = "Small", hp = 5, moves = { idle = { name = "Idle", intent = "buff", actions = {} } }, pattern = { "idle" } }
  E.sz_minion = { name = "Minion", hp = 5, minion = true,
    moves = { idle = { name = "Idle", intent = "buff", actions = {} } }, pattern = { "idle" } }
  E.sz_stoker = { name = "Stoker", hp = 60,
    moves = { roar = { name = "Roar", intent = "attack", actions = { { "attack", 5 }, { "stoke", 1 } } },
      fan = { name = "Fan", intent = "cast", cast = true, actions = { { "stoke", 2 } } } },
    pattern = { "roar" } }

  local function steppes(o)
    o = o or {}
    o.zone = "steppes"
    o.enemies = o.enemies or { "sz_idle" }
    return combat(o)
  end
  local function z(c) return c.zs.steppes end
  -- Nombres de la zone (Data/Zones/Steppes.lua) : compte d'un combat normal, première brûlure, hausse.
  local CFG = ns.Encounters.steppes.wildfire
  local T0, B, S = CFG.normal, CFG.blaze, CFG.step
  local function rounds(c, n) for _ = 1, n do Combat.endTurn(c) end end

  ---------------------------------------------------------------------------
  -- Règle
  ---------------------------------------------------------------------------

  test("Steppes : compte de départ selon le genre (4, 5, 5), champ wildfire d'un ennemi (Volchan 3) ; données simples", function()
    eq(T0, 4); eq(CFG.elite, 5); eq(B, 1); eq(S, 2)
    eq(z(steppes()).left, T0); eq(z(steppes()).max, T0)
    eq(z(steppes({ kind = "elite" })).left, CFG.elite)
    eq(z(steppes({ kind = "boss", enemies = { "grark_lorkrub" } })).left, 5)
    local v = steppes({ kind = "elite", enemies = { "volchan" } })
    eq(z(v).left, 3); eq(z(v).max, 3); eq(z(v).blaze, B)
    local ok, why = T.plainData(v.zs); assert(ok, why)
    local cl = Combat.clone(v)
    cl.zs.steppes.left = 0
    eq(z(v).left, 3, "clone profond")
    local w = combat({ zone = "westfall" })
    eq(w.zs, nil, "Westfall : aucune règle de zone")
  end)

  test("Steppes : 4, 3, 2, 1, embrasement sans dégâts, puis brûle 1, 3, 5 (Blaze + 2 après chaque brûlure)", function()
    local c = steppes()
    rounds(c, T0 - 1)
    eq(z(c).left, 1); eq(c.player.hp, 60)
    Combat.endTurn(c)
    eq(z(c).left, 0); eq(z(c).lit, true); eq(c.player.hp, 60, "embrasement : pas de dégâts ce round")
    local ign = false
    for _, ev in ipairs(c.events) do if ev.t == "wildfire" and ev.ignite then ign = true end end
    assert(ign, "journal : embrasement")
    Combat.endTurn(c)
    eq(c.player.hp, 59); eq(z(c).blaze, 3)
    Combat.endTurn(c)
    eq(c.player.hp, 56); eq(z(c).blaze, 5)
    Combat.endTurn(c)
    eq(c.player.hp, 51)
  end)

  test("Steppes : la brûlure ignore l'Absorb, Parry et Pain Suppression ; elle peut tuer", function()
    local c = steppes({ class = "rogue" })
    z(c).left = 0
    c.player.block, c.player.st.parry, c.player.st.halved = 30, 2, 1
    Combat.endRound(c)
    eq(c.player.hp, 60 - B); eq(c.player.st.parry, 2, "Parry intacte")
    local d = steppes({ hp = B })
    z(d).left = 0
    Combat.endTurn(d)
    eq(d.result, "lost")
  end)

  test("Steppes : la brûlure donne +1 Rage au Warrior (perte de PV)", function()
    local c = steppes({ class = "warrior" })
    z(c).left = 0
    local r0 = c.player.res or 0
    Combat.endRound(c)
    eq(c.player.res, r0 + 1)
  end)

  test("Steppes : une mort recule le feu d'un round (plafond T) ; à 0, le round en cours ne brûle pas", function()
    local c = steppes({ enemies = { "sz_small", "sz_idle" }, hand = { "smite" } })
    z(c).left = 2
    play(c, "smite", 1)
    eq(c.enemies[1].dead, true); eq(z(c).left, 3)
    local d = steppes({ enemies = { "sz_small", "sz_small", "sz_idle" }, hand = { "smite", "smite" } })
    play(d, "smite", 1)
    eq(z(d).left, T0, "plafond T")
    z(d).left, z(d).blaze = 0, 6
    play(d, "smite", 2)
    eq(z(d).left, 1)
    Combat.endTurn(d)
    eq(d.player.hp, 60, "repassé à 1 : pas de brûlure ce round"); eq(z(d).left, 0); eq(z(d).blaze, 6, "Blaze garde sa valeur")
  end)

  test("Steppes : la mort d'un serviteur ne recule pas le feu ; la mort du dernier ennemi : rien ne brûle", function()
    local c = steppes({ enemies = { "sz_minion", "sz_idle" }, hand = { "smite" } })
    z(c).left = 1
    play(c, "smite", 1)
    eq(c.enemies[1].dead, true); eq(z(c).left, 1)
    local d = steppes({ enemies = { "sz_small" }, hand = { "smite" } })
    z(d).left = 0
    play(d, "smite", 1)
    eq(d.result, "won"); eq(d.player.hp, 60); eq(z(d).left, 0, "combat fini : compte inchangé")
  end)

  test("Steppes : morts par DoT et par le familier du Hunter comptent", function()
    local c = steppes({ enemies = { "sz_small", "sz_idle" } })
    z(c).left = 1
    Combat.applyStatus(c, c.enemies[1], "pain", 6)
    Combat.endTurn(c) -- DoT au tour de l'ennemi : mort, 1 -> 2 ; fin de round : 2 -> 1
    assert(c.enemies[1].dead, "mort du DoT")
    eq(z(c).left, 1, "la mort par DoT a reculé le feu")
    local h = steppes({ class = "hunter", enemies = { "sz_small", "sz_idle" } })
    z(h).left = 1
    h.enemies[1].hp = 1
    ns.Hunter.petAttack(h, "card")
    assert(h.enemies[1].dead, "tué par le familier")
    eq(z(h).left, 2, "mort par le familier")
  end)

  test("Steppes : Stoke retire au compte ; à 0, +2 Blaze par point ; Stoke qui amène à 0 brûle dès ce round", function()
    local c = steppes({ enemies = { "sz_stoker" } })
    eq(z(c).left, T0)
    z(c).left = 3
    Combat.endTurn(c) -- Stoke 1 puis fin de round : 3 -> 2 -> 1
    eq(z(c).left, 1); eq(c.player.hp, 55)
    Combat.endTurn(c) -- Stoke 1 : 1 -> 0, fin de round : brûle 1
    eq(c.player.hp, 55 - 5 - B); eq(z(c).blaze, B + S)
    Combat.endTurn(c) -- Stoke sur sol embrasé : Blaze 3 + 2 = 5, brûle 5
    eq(c.player.hp, 55 - 5 - B - 5 - (B + 2 * S)); eq(z(c).blaze, B + 3 * S)
    local s = 0
    for _, ev in ipairs(c.events) do if ev.t == "counter" and ev.zone == "steppes" then s = s + 1 end end
    assert(s > 0, "journal counter")
  end)

  test("Steppes : Stoke en Cast interrompu ou ennemi étourdi : rien ; Trap Freezing sur une attaque + Stoke : rien", function()
    local c = steppes({ enemies = { "sz_stoker" }, hand = { "zt_interrupt" } })
    c.enemies[1].intent = "fan"
    c.enemies[1].interrupted = false
    play(c, "zt_interrupt", 1)
    eq(c.enemies[1].interrupted, true)
    Combat.endTurn(c)
    eq(z(c).left, T0 - 1, "Stoke perdu : seule la fin de round baisse")
    local d = steppes({ enemies = { "sz_stoker" } })
    Combat.applyStatus(d, d.enemies[1], "stunned", 1)
    Combat.endTurn(d)
    eq(z(d).left, T0 - 1); eq(d.player.hp, 60)
    local h = steppes({ class = "hunter", enemies = { "sz_stoker" }, hand = { "freezing_trap" } })
    play(h, "freezing_trap")
    Combat.endTurn(h)
    eq(z(h).left, T0 - 1, "Trap : le tour s'arrête avant le Stoke"); eq(h.player.hp, 60)
  end)

  test("Steppes : une intention sans attaque (Fan the Flames) ne déclenche pas de Trap", function()
    local h = steppes({ class = "hunter", enemies = { "sz_stoker" }, hand = { "freezing_trap" } })
    h.enemies[1].intent = "fan"
    play(h, "freezing_trap")
    Combat.endTurn(h)
    eq(#h.traps, 1, "la Trap attend"); eq(z(h).left, T0 - 3, "Stoke 2 puis fin de round")
  end)

  test("Steppes : Douse N (plafond T, sur sol embrasé repasse à N) ; hors des Steppes, rien", function()
    local c = steppes({ hand = { "greater_fire_protection_potion", "greater_fire_protection_potion" } })
    play(c, "greater_fire_protection_potion")
    eq(z(c).left, T0, "plafond"); eq(c.player.block, 6)
    z(c).left, z(c).blaze = 0, 8
    play(c, "greater_fire_protection_potion")
    eq(z(c).left, 3); eq(z(c).blaze, 8)
    local w = combat({ zone = "westfall", hand = { "greater_fire_protection_potion" } })
    play(w, "greater_fire_protection_potion")
    eq(w.zs, nil); eq(w.player.block, 6, "Absorb seule")
  end)

  test("Steppes : tour ennemi sauté (Feign Death) : la fin du round ne touche pas au Wildfire", function()
    local c = steppes()
    z(c).left = 0
    c.player.flags.skipEnemyTurn = true
    Combat.endTurn(c)
    eq(c.player.hp, 60); eq(z(c).blaze, B)
    local d = steppes()
    d.player.flags.skipEnemyTurn = true
    Combat.endTurn(d)
    eq(z(d).left, T0)
  end)

  test("Steppes : condition lit (Bite + 3, Fire Nova + 6), affichée par intentInfo", function()
    local c = steppes({ enemies = { "blackrock_worg" } })
    c.enemies[1].intent = "bite"
    local base = Combat.intentInfo(c, c.enemies[1]).damage
    z(c).left = 0
    eq(Combat.intentInfo(c, c.enemies[1]).damage, base + 3)
    local f = steppes({ enemies = { "thaurissan_firewalker" } })
    f.enemies[1].intent = "nova"
    local nb = Combat.intentInfo(f, f.enemies[1]).damage
    z(f).left = 0
    eq(Combat.intentInfo(f, f.enemies[1]).damage, nb + E.thaurissan_firewalker.moves.nova.actions[1].more[1][1])
  end)

  test("Steppes : prévision (Stoke annoncés, ennemi étourdi ou interrompu exclu), burnNow", function()
    local c = steppes({ enemies = { "sz_stoker", "sz_stoker" } })
    local fc = WF.forecast(c)
    eq(fc.left, T0 - 2); eq(fc.stoke, 2); eq(fc.burnNow, false)
    Combat.applyStatus(c, c.enemies[2], "stunned", 1)
    eq(WF.forecast(c).left, T0 - 1)
    z(c).left = 1
    eq(WF.forecast(c).burnNow, true)
    z(c).left = 0
    fc = WF.forecast(c)
    eq(fc.blaze, B + S); eq(fc.burnNow, true)
  end)

  ---------------------------------------------------------------------------
  -- Ennemis, élites, boss
  ---------------------------------------------------------------------------

  test("Steppes : chaque ennemi joue chacune de ses intentions sans erreur", function()
    for id, d in pairs(E) do
      local own = d.name and ns.Encounters.steppes and false
      for _, list in pairs(ns.Encounters.steppes) do
        if type(list) == "table" then
          for _, g in ipairs(list) do
            for _, spec in ipairs(type(g) == "table" and g or {}) do
              if Combat.specId(spec) == id then own = true end
            end
          end
        end
      end
      if own or id == "dark_iron_land_mine" or id == "ember_worg" then
        for mv in pairs(d.moves) do
          local c = steppes({ enemies = { id, "sz_idle" }, kind = d.boss and "boss" or (d.elite and "elite" or "combat"), hp = 200 })
          c.enemies[1].intent = mv
          Combat.endTurn(c)
          assert(c.result == nil or c.result == "won", id .. " " .. mv)
        end
      end
    end
  end)

  test("Steppes : Firegut Ogre Mage : Bloodlust si un allié vit, jamais deux tours de suite, deux fois au plus", function()
    local c = steppes({ enemies = { "firegut_ogre_mage", "sz_idle" }, hp = 300 })
    local e = c.enemies[1]
    local seq = { e.intent }
    for _ = 1, 5 do Combat.endTurn(c) seq[#seq + 1] = e.intent end
    eq(table.concat(seq, ","), "bloodlust,fireball,bloodlust,fireball,fireball,fireball")
    eq(c.enemies[2].st.force, 2)
    local d = steppes({ enemies = { "firegut_ogre_mage" } })
    eq(d.enemies[1].intent, "fireball", "seul : Fireball")
  end)

  test("Steppes : Gruklash, Frenzy sous la moitié (Strength 2), motif qui reprend où il en était", function()
    local c = steppes({ kind = "elite", enemies = { "gruklash" }, hand = { "smite" }, hp = 300 })
    local e = c.enemies[1]
    eq(e.intent, "pummel")
    Combat.endTurn(c)
    eq(e.intent, "backhand")
    e.hp = math.floor(e.maxHp / 2) + 2
    c.hand = {}
    c.hand[1] = ns.Card.new("smite", false, 9001)
    play(c, "smite", 1)
    eq(e.mem.phase, 1); eq(e.st.force, 2)
    Combat.endTurn(c)
    eq(e.intent, "mortal", "après Backhand : Mortal Strike")
  end)

  test("Steppes : Thauris Balgarr pose des mines (2 au plus) ; une mine s'arme puis explose (Stoke), serviteur", function()
    local c = steppes({ kind = "elite", enemies = { "thauris_balgarr" }, hp = 300 })
    local t = c.enemies[1]
    eq(t.intent, "mine")
    Combat.endTurn(c)
    eq(#c.enemies, 2); local m = c.enemies[2]
    eq(m.id, "dark_iron_land_mine"); eq(m.minion, true); eq(m.intent, "arm")
    local left = z(c).left
    Combat.endTurn(c)
    eq(m.intent, "detonate")
    local hp = c.player.hp
    Combat.endTurn(c)
    eq(m.dead, true, "la mine se détruit")
    assert(c.player.hp < hp)
    eq(z(c).left, math.max(0, left - 2 - 1), "deux fins de round et un Stoke ; la mort de la mine ne recule rien")
    -- deux mines vivantes : Shoot à la place
    local d = steppes({ kind = "elite", enemies = { "thauris_balgarr", "dark_iron_land_mine", "dark_iron_land_mine" }, hp = 300 })
    d.enemies[1].mem.k = 0
    eq(E.thauris_balgarr.ai(d, d.enemies[1]), "shoot")
  end)

  test("Steppes : Volchan, Wildfire 3, pas de soin par la brûlure", function()
    local c = steppes({ kind = "elite", enemies = { "volchan" }, hp = 300 })
    eq(z(c).left, 3)
    c.enemies[1].hp = 50
    z(c).left = 0
    Combat.endRound(c)
    eq(c.enemies[1].hp, 50)
  end)

  test("Steppes : Grark, phase 2 sous 30 % (sol embrasé, Torch puis Mortal Strike), déjà embrasé : Blaze + 4", function()
    local c = steppes({ kind = "boss", enemies = { "grark_lorkrub" }, hand = { "smite" }, hp = 300 })
    local g = c.enemies[1]
    eq(z(c).left, 5); eq(E.grark_lorkrub.phases[1].at, 0.3)
    g.hp = Combat.phaseHp(g, E.grark_lorkrub.phases[1]) + 3
    play(c, "smite", 1)
    eq(g.mem.phase, 1); eq(z(c).left, 0); eq(g.intent, "torch")
    Combat.endTurn(c)
    eq(g.intent, "mortal")
    local d = steppes({ kind = "boss", enemies = { "grark_lorkrub" }, hand = { "smite" }, hp = 300 })
    z(d).left = 0
    d.enemies[1].hp = Combat.phaseHp(d.enemies[1], E.grark_lorkrub.phases[1]) + 3
    play(d, "smite", 1)
    eq(z(d).blaze, B + 4)
  end)

  test("Steppes : Grark, phase 3 sous 20 % (2 Ember Worgs, Absorb) ; motif de phase 2 continué ; serviteurs", function()
    local c = steppes({ kind = "boss", enemies = { "grark_lorkrub" }, hand = { "smite" }, hp = 300 })
    local g = c.enemies[1]
    g.mem.phase = 1
    g.intent, g.mem.last = "torch", "block"
    eq(E.grark_lorkrub.phases[2].at, 0.2)
    g.hp = Combat.phaseHp(g, E.grark_lorkrub.phases[2]) + 3
    play(c, "smite", 1)
    eq(g.mem.phase, 2); eq(g.block, E.grark_lorkrub.phases[2].enter[2][2])
    local worgs = 0
    for _, e in ipairs(c.enemies) do if e.id == "ember_worg" and not e.dead then worgs = worgs + 1 end end
    eq(worgs, 2)
    Combat.endTurn(c)
    eq(g.intent == "mortal" or g.intent == "rend", true, "motif de phase 2 : " .. tostring(g.intent))
    -- Call the Pack : 2 loups au plus
    local d = steppes({ kind = "boss", enemies = { "grark_lorkrub", "ember_worg", "ember_worg" }, hp = 300 })
    eq(d.enemies[1].intent, "orders")
    Combat.endTurn(d)
    local n = 0
    for _, e in ipairs(d.enemies) do if e.id == "ember_worg" then n = n + 1 end end
    eq(n, 2, "max = 2")
  end)

  ---------------------------------------------------------------------------
  -- Commun, bibelots de clé
  ---------------------------------------------------------------------------

  test("Steppes : Thorium Grenade (10 à tous) : chaque mort recule le feu", function()
    local c = steppes({ enemies = { "sz_small", "sz_small", "sz_idle" }, hand = { "thorium_grenade" } })
    z(c).left = 1
    play(c, "thorium_grenade")
    eq(z(c).left, 3)
  end)

  test("Steppes : bibelots communs (Medallion, Gor'tesh, Draco-Incarcinatrix)", function()
    local c = steppes({ enemies = { "sz_small", "sz_small", "sz_idle" }, hand = { "smite", "smite" },
      deck = { "smite", "smite", "smite", "smite", "smite" },
      relics = { "blackrock_medallion", "draco_incarcinatrix" } })
    local h0 = #c.hand
    play(c, "smite", 1)
    eq(c.player.block, 3); eq(#c.hand, h0 - 1 + 2, "première mort : pioche 2")
    play(c, "smite", 2)
    eq(c.player.block, 6); eq(#c.hand, h0 + 1 - 1, "seconde mort : rien")
    local d = steppes({ enemies = { "sz_idle", "sz_idle" }, relics = { "gortesh_head" } })
    eq(d.enemies[1].st.demoralized, 1); eq(d.enemies[2].st.demoralized, 1)
  end)

  test("Steppes : Libram of Resilience annule la première perte de PV (coup, brûlure ou Pay N HP)", function()
    local c = steppes({ enemies = { "sz_stoker" }, relics = { "libram_of_resilience" } })
    z(c).left = 3
    Combat.endTurn(c)
    eq(c.player.hp, 60, "premier coup annulé")
    Combat.endTurn(c)
    eq(c.player.hp, 60 - 5 - B, "coup de 5, puis brûle 1 (Stoke à 0)")
    local d = steppes({ relics = { "libram_of_resilience" } })
    z(d).left = 0
    Combat.endRound(d)
    eq(d.player.hp, 60, "première brûlure annulée")
    Combat.loseHp(d, 4, "pay")
    eq(d.player.hp, 56)
    local a = steppes({ enemies = { "sz_stoker" }, relics = { "libram_of_resilience" } })
    a.player.block = 10
    Combat.endTurn(a)
    eq(a.relicState.libram_of_resilience, nil, "coup absorbé : pas consommé")
  end)

  test("Steppes : Libram of Voracity (Strength 1 par mort), Heart of the Mountain (+1 mana, pioche 1 sous la moitié)", function()
    local c = steppes({ enemies = { "sz_small", "sz_idle" }, hand = { "smite" }, relics = { "libram_of_voracity" } })
    play(c, "smite", 1)
    eq(c.player.st.force, 1)
    local d = steppes({ relics = { "heart_of_the_mountain" }, deck = { "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite" } })
    local mana0 = d.player.mana
    d.player.hp = 30
    Combat.endTurn(d)
    eq(d.player.mana, mana0 + 1); eq(#d.hand, 6)
  end)

  test("Steppes : commun débloqué par la première victoire du compte (zone 6) ; bibelots de clé +1, +3, +5", function()
    local cc = Meta.commonContent(6)
    local function has(list, id) for _, x in ipairs(list) do if x == id then return true end end return false end
    assert(has(cc.cards, "greater_fire_protection_potion") and has(cc.cards, "thorium_grenade"))
    assert(has(cc.relics, "blackrock_medallion") and has(cc.relics, "gortesh_head") and has(cc.relics, "draco_incarcinatrix"))
    assert(has(cc.events, "wanted_poster")); eq(cc.perks[1], "merchantRelic")
    local kr = Meta.keyRelics("mage", "steppes")
    eq(#kr, 3); eq(kr[1].id, "libram_of_resilience"); eq(kr[2].level, 3); eq(kr[3].id, "heart_of_the_mountain")
    for _, r in ipairs(kr) do
      assert(not ns.Relics[r.id].tier, r.id .. " : pas de tier")
    end
  end)

  ---------------------------------------------------------------------------
  -- Expédition : rencontres, décors, WANTED, bot
  ---------------------------------------------------------------------------

  local function newExp(seed, common)
    local exp = X.new({ seed = seed or 5, class = "priest", zone = "steppes",
      unlocks = { level = 7, common = common or 5, won = { westfall = 5, duskwood = 5, wetlands = 5, stranglethorn = 5, swamp = 5 } } })
    if exp.phase == "start" then assert(X.act(exp, { "skipStartRelic" })) end
    return exp
  end

  test("Steppes : rencontres de la zone (zone, décor, personnage), tirées dans les Steppes seulement", function()
    local mine = { "oralius_firegut", "marshal_maxwell", "ragged_john", "mathredis_librams", "tinkee_incarcinatrix",
      "helendis_dragonkin", "yuka_ribbly", "cyrus_taste_of_flame" }
    for _, id in ipairs(mine) do
      local ev = ns.Events[id]
      assert(ev and ev.zone == "steppes" and ev.npc and ev.scene, id)
    end
    local exp = newExp()
    local pool = {}
    for _, id in ipairs(X.eventPool(exp)) do pool[id] = true end
    assert(pool.oralius_firegut and not pool.saldean_farm, "Steppes : ses rencontres, pas celles de Westfall")
    assert(not pool.wanted_poster, "WANTED : après la première victoire du compte dans les Steppes")
    local w = X.new({ seed = 5, class = "priest", zone = "westfall", unlocks = { level = 7, common = 6 } })
    local wpool = {}
    for _, id in ipairs(X.eventPool(w)) do wpool[id] = true end
    assert(wpool.wanted_poster and not wpool.oralius_firegut, "WANTED dans toutes les zones au palier 6")
  end)

  test("Steppes : WANTED nomme l'élite tirée et lance un combat d'élite (+50 po)", function()
    local exp = newExp(9, 6)
    exp.node, exp.phase = exp.map.start[1], "map"
    X.openEvent(exp, "wanted_poster")
    local g = exp.event.rolls[1][1].group
    assert(g and g.pool == "elite")
    eq(X.eventText(exp), "\"WANTED: " .. g.names[1] .. ". Reward paid at the camp, on proof of death.\"")
    assert(X.act(exp, { "choose", 1 }))
    eq(exp.phase, "combat"); eq(exp.combat.kind, "elite"); eq(exp.combat.zone, "steppes")
    eq(exp.combat.zs.steppes.left, WF.startCount(exp.combat))
    assert(exp.fight.reward.gold >= 50)
  end)

  test("Steppes : combats de rencontre (Firegut, dragonkin, Volchan en élite)", function()
    for _, t in ipairs({ { "oralius_firegut", "firegut_brute" }, { "helendis_dragonkin", "black_dragonspawn" },
        { "cyrus_taste_of_flame", "volchan", "elite" } }) do
      local exp = newExp(3)
      exp.hp = exp.maxHp
      exp.node, exp.phase = exp.map.start[1], "map"
      X.openEvent(exp, t[1])
      assert(X.act(exp, { "choose", 1 }), t[1])
      eq(exp.phase, "combat", t[1]); eq(exp.combat.enemies[1].id, t[2])
      if t[3] then eq(exp.combat.kind, "elite") end
    end
  end)

  test("Steppes : zone jouable, décors propres (road, hill, camp, shop, night, boss)", function()
    assert(ns.Zone.playable("steppes"))
    local sc = ns.Zones.steppes.scenes
    eq(sc.road, "steppes_road"); eq(sc.camp, "steppes_camp"); eq(sc.shop, "steppes_shop")
    eq(sc.night, "steppes_night"); eq(sc.hill, "steppes_hill"); eq(sc.mine, "steppes_boss")
  end)

  test("Steppes : le bot compte la brûlure à venir (valeur), clé de l'état ; une expédition simulée se termine", function()
    local zb = ns.ZoneBots.steppes
    local c = steppes()
    local v0 = zb.value(c, ns.Bots.W)
    z(c).left = 0
    local v1 = zb.value(c, ns.Bots.W)
    assert(v1 < v0, "sol embrasé : pire")
    eq(zb.key(c), "0:" .. B)
    local rec, exp = ns.SimExpedition.play({ seed = 4, class = "rogue", zone = "steppes", zones = 5, level = 7, bot = "greedy" })
    eq(exp.phase, "done"); eq(exp.zone, "steppes")
  end)
end
