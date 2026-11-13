-- Tests de la zone Blackrock Mountain (phases) : lancés par Sim/tests_zones.lua (T décrit là-bas).
-- Règle de phase (pendant / après le tour, Stunned, Cast, coup mortel, plusieurs seuils), chaque ennemi,
-- élite et phase du boss, règles propres (Invincible, Fire Shield, Throne, Class Call par classe, Veil,
-- Shadowflame Fury, Burning Adrenaline, Essence of the Red), rencontres, commun et bibelots de clé,
-- Grim Guzzler, titre Dragonslayer et Rallying Cry, Westfall inchangée.
return function(T)
  local ns, test, eq, combat, play = T.ns, T.test, T.eq, T.combat, T.play
  local Combat, X, Meta, BR = ns.Combat, ns.Expedition, ns.Meta, ns.Blackrock
  local E = ns.Enemies

  -- Cartes de test (sans coût : le mana ne gêne pas les scénarios)
  local C = ns.Cards
  local function card(id, t) t.id = id t.cost = t.cost or 0 t.text = t.text or id C[id] = t end
  card("brt_hit", { name = "Hit", type = "attack", target = "enemy", effects = { { "damage", 10 } } })
  card("brt_hit2", { name = "Hit 2", type = "attack", target = "enemy", effects = { { "damage", 10 } } })
  card("brt_big", { name = "Big", type = "attack", target = "enemy", effects = { { "damage", 60 } } })
  card("brt_big2", { name = "Big 2", type = "attack", target = "enemy", effects = { { "damage", 60 } } })
  card("brt_multi", { name = "Multi", type = "attack", target = "enemy", effects = { { "damage", 3, times = 3 } } })
  card("brt_dot", { name = "Dot", type = "skill", target = "enemy", effects = { { "apply", "pain", 5 } } })
  card("brt_stun", { name = "Stun", type = "skill", target = "enemy", effects = { { "apply", "stunned", 1 } } })
  card("brt_kick", { name = "Kick", type = "skill", target = "enemy", effects = { { "interrupt" } } })
  card("brt_heal", { name = "Heal", type = "skill", effects = { { "heal", 8 } } })
  card("brt_guard", { name = "Guard", type = "skill", effects = { { "absorb", 4 } } })
  card("brt_cast", { name = "Cast", type = "attack", target = "enemy", cost = 1, cast = true, effects = { { "damage", 5 } } })
  card("brt_trap", { name = "Trap", type = "skill", trap = true, effects = { { "damage", 5 } } })

  local function bc(o)
    o.zone = "blackrock"
    o.hp = o.hp or 60
    return combat(o)
  end
  local function us(e) return e.zs and e.zs.blackrock or {} end
  -- valeur de la première action d'attaque d'un move (les nombres sont réglés par la simulation)
  local function atk(id, move)
    for _, a in ipairs(E[id].moves[move].actions) do if a[1] == "attack" then return a[2], a.times or 1 end end
  end
  local function alive(c, id)
    local n = 0
    for _, e in ipairs(c.enemies) do if not e.dead and e.id == id then n = n + 1 end end
    return n
  end

  ---------------------------------------------------------------------------
  -- Données
  ---------------------------------------------------------------------------

  test("Blackrock : zone jouable, groupes valides, phases complètes (texte du cran, ouverture, libellé)", function()
    assert(ns.Zone.playable("blackrock"))
    eq(ns.Zones.blackrock.encounters, "blackrock")
    local pools = ns.Encounters.blackrock
    for pool, list in pairs(pools) do
      for _, group in ipairs(list) do
        for _, spec in ipairs(group) do assert(E[Combat.specId(spec)], pool .. " : " .. tostring(Combat.specId(spec))) end
      end
    end
    eq(#pools.easy, 4); eq(#pools.normal, 7); eq(#pools.elite, 3); eq(#pools.boss, 1)
    local phased = 0
    local ids = { rookery_whelpling = true, bone_construct = true }
    for _, list in pairs(pools) do
      for _, group in ipairs(list) do for _, spec in ipairs(group) do ids[Combat.specId(spec)] = true end end
    end
    for id in pairs(ids) do
      local d = E[id]
      if d.phases then
        for k, ph in ipairs(d.phases) do
          assert(ph.name and ph.text and ph.text ~= "", id .. " phase " .. k .. " : nom et texte")
          if ph.open then
            assert(d.moves[ph.open], id .. " : ouverture " .. ph.open)
            assert(ph.text:find("Opens with " .. d.moves[ph.open].name, 1, true), id .. " : « Opens with »")
          end
          eq(ph.label, "Next", id .. " : libellé de l'ouverture différée")
          for _, m in ipairs(ph.pattern or {}) do assert(d.moves[m], id .. " : motif " .. m) end
        end
      end
    end
    -- 7 ennemis normaux sur 9 à phase (seuil 50 %)
    for _, id in ipairs({ "anvilrage_guardsman", "anvilrage_medic", "blazing_fireguard", "firebrand_pyromancer",
        "blackhand_veteran", "rage_talon_dragonspawn", "rookery_hatcher" }) do
      eq(E[id].phases and E[id].phases[1].at, 0.5, id); phased = phased + 1
    end
    eq(phased, 7)
    assert(not E.firebrand_grunt.phases and not E.rookery_whelp.phases)
    eq(E.nefarian.phases[1].at, 0.75); eq(E.nefarian.phases[2].at, 0.25)
    assert(E.nefarian.phases[1].cap and E.nefarian.phases[2].cap, "boss : plafond au seuil")
    eq(E.anvilrage_guardsman.phases[1].text, "Opens with Shield Wall.")
    eq(E.blackhand_veteran.phases[1].text, "Gains Strength 3. Opens with Whirlwind.")
  end)

  ---------------------------------------------------------------------------
  -- Règle de phase
  ---------------------------------------------------------------------------

  test("Phase pendant le tour : l'ouverture remplace l'intention tout de suite (Shield Wall, puis le motif)", function()
    local c = bc({ enemies = { { "anvilrage_guardsman", hp = 40 } }, hand = { "brt_hit" } })
    local e = c.enemies[1]
    e.intent, e.hp = "strike", 29
    play(c, "brt_hit", 1)
    eq(e.mem.phase, 1); eq(e.intent, "shield_wall"); eq(BR.opening(e), "shield_wall")
    Combat.endTurn(c)
    eq(c.player.hp, 60, "l'attaque remplacée ne part pas")
    eq(e.block, 15, "Absorb de Shield Wall pendant le tour du joueur")
    eq(e.intent, "shield_slam", "puis le motif de la phase")
    eq(BR.opening(e), nil)
  end)

  test("Phase après le tour (DoT) : l'intention annoncée part, l'ouverture vient au tour suivant", function()
    local c = bc({ enemies = { { "anvilrage_guardsman", hp = 40 } }, hand = { "brt_dot" } })
    local e = c.enemies[1]
    e.intent, e.hp = "strike", 22
    play(c, "brt_dot", 1)
    eq(e.mem.phase, nil)
    Combat.endTurn(c)
    eq(e.mem.phase, 1)
    local v, k = atk("anvilrage_guardsman", "strike")
    eq(c.player.hp, 60 - v * k, "Strike part quand même")
    eq(e.intent, "shield_wall", "ouverture au tour suivant")
  end)

  test("Phase et Stunned : l'ouverture se perd avec le tour sauté, reprise au motif de la phase", function()
    local c = bc({ enemies = { { "anvilrage_guardsman", hp = 40 } }, hand = { "brt_hit", "brt_stun" } })
    local e = c.enemies[1]
    e.intent, e.hp = "strike", 29
    play(c, "brt_hit", 1)
    eq(e.intent, "shield_wall")
    play(c, "brt_stun", 1)
    Combat.endTurn(c)
    eq(e.block, 0, "pas de Shield Wall"); eq(c.player.hp, 60)
    eq(e.intent, "shield_slam"); eq(BR.opening(e), nil)
  end)

  test("Phase et Cast : franchir puis interrompre coupe l'ouverture ; une incantation coupée est remplacée", function()
    -- franchir puis interrompre
    local c = bc({ enemies = { { "firebrand_pyromancer", hp = 30 } }, hand = { "brt_hit", "brt_kick" } })
    local e = c.enemies[1]
    e.intent, e.hp = "scorch", 16
    play(c, "brt_hit", 1)
    eq(e.intent, "flamestrike"); eq(e.interrupted, false)
    play(c, "brt_kick", 1)
    Combat.endTurn(c)
    eq(c.player.hp, 60, "Flamestrike interrompue"); eq(c.player.st.pain, nil)
    -- interrompre puis franchir : l'ouverture n'est pas interrompue
    c = bc({ enemies = { { "firebrand_pyromancer", hp = 30 } }, hand = { "brt_kick", "brt_hit" } })
    e = c.enemies[1]
    e.intent, e.hp = "fireball", 16
    Combat.forceIntent(c, e, "fireball", { now = true })
    play(c, "brt_kick", 1)
    eq(e.interrupted, true)
    play(c, "brt_hit", 1)
    eq(e.intent, "flamestrike"); eq(e.interrupted, false)
    Combat.endTurn(c)
    eq(c.player.hp, 60 - 12 - 3, "Flamestrike 12, puis son DoT au début du tour"); eq(c.player.st.pain, 2)
  end)

  test("Phase : un coup mortel n'en déclenche aucune ; plusieurs seuils d'un coup (boss plafonné à part)", function()
    local c = bc({ enemies = { { "blackhand_veteran", hp = 34 }, "zt_dummy" }, hand = { "brt_big" } })
    local e = c.enemies[1]
    e.hp = 30
    play(c, "brt_big", 1)
    eq(e.dead, true); eq(e.mem.phase, nil)
    eq(c.player.st.force, nil)
  end)

  ---------------------------------------------------------------------------
  -- Ennemis normaux
  ---------------------------------------------------------------------------

  test("Firebrand Grunt : Sunder Armor pose Sundered ; Rookery Whelp : Strength 1 à la mort d'un autre", function()
    local c = bc({ enemies = { { "firebrand_grunt", hp = 25 } } })
    c.enemies[1].intent = "sunder"
    Combat.endTurn(c)
    eq(c.player.hp, 55); assert((c.player.st.armor_broken or 0) > 0)
    c = bc({ enemies = { "rookery_whelp", "rookery_whelp", "rookery_whelp" }, hand = { "brt_big" } })
    play(c, "brt_big", 1)
    eq(c.enemies[2].st.force, 1); eq(c.enemies[3].st.force, 1)
  end)

  test("Anvilrage Medic : soigne le plus blessé ; Desperate Prayer à l'entrée de phase", function()
    local c = bc({ enemies = { { "anvilrage_medic", hp = 20 }, { "firebrand_grunt", hp = 25 } }, hand = { "brt_hit" } })
    local m, g = c.enemies[1], c.enemies[2]
    g.hp = 10
    Combat.forceIntent(c, m, Combat.chooseIntent and "heal" or "heal", { now = true })
    Combat.endTurn(c)
    eq(g.hp, 18, "Heal 8 sur le grunt")
    c = bc({ enemies = { { "anvilrage_medic", hp = 20 } }, hand = { "brt_hit" } })
    m = c.enemies[1]
    m.intent, m.hp = "smite", 11
    play(c, "brt_hit", 1)
    eq(m.intent, "prayer")
    Combat.endTurn(c)
    eq(m.hp, 11)
  end)

  test("Blazing Fireguard : Fire Shield 2 à la phase ; coups d'Attack et de Trap (pas le coup d'entrée, ni DoT ni familier)", function()
    local c = bc({ enemies = { { "blazing_fireguard", hp = 40 } }, hand = { "brt_hit", "brt_multi", "brt_guard", "brt_dot" } })
    local e = c.enemies[1]
    e.intent, e.hp = "lash", 21
    play(c, "brt_hit", 1)
    eq(e.mem.phase, 1); eq(e.st.fire_shield, 2)
    eq(c.player.hp, 60, "le coup qui fait entrer dans la phase ne déclenche rien")
    eq(e.intent, "nova")
    play(c, "brt_guard")
    play(c, "brt_multi", 1)
    eq(c.player.hp, 58, "3 coups × 2, Absorb 4 d'abord")
    e.hp = 30
    play(c, "brt_dot", 1)
    -- familier : source « pet »
    local hp = c.player.hp
    c.hitKind, c.hitAll = "pet", false
    Combat.dealDamage(c, c.player, e, 1)
    c.hitKind, c.hitAll = nil, nil
    eq(c.player.hp, hp, "familier : rien")
    -- tic de DoT au tour de l'ennemi : rien
    e.intent = "lash"
    Combat.endTurn(c)
    eq(c.player.hp, hp - atk("blazing_fireguard", "lash"), "seul Flame Lash")
    -- Trap
    c = bc({ enemies = { { "blazing_fireguard", hp = 40 } }, hand = { "brt_trap" } })
    e = c.enemies[1]
    e.st.fire_shield, e.intent, e.hp = 2, "lash", 30
    play(c, "brt_trap")
    Combat.endTurn(c)
    eq(c.player.hp, 60 - 2 - atk("blazing_fireguard", "lash"), "Trap : 2, puis Flame Lash")
  end)

  test("Firebrand Pyromancer, Blackhand Veteran, Rage Talon Dragonspawn, Rookery Hatcher : ouvertures", function()
    local c = bc({ enemies = { { "blackhand_veteran", hp = 34 } }, hand = { "brt_hit" } })
    local e = c.enemies[1]
    e.intent, e.hp = "strike", 18
    play(c, "brt_hit", 1)
    eq(e.st.force, 3); eq(e.intent, "whirlwind")
    Combat.endTurn(c)
    eq(c.player.hp, 60 - 18, "Whirlwind (6 + 3) × 2")
    eq(e.intent, "strike")
    -- Dragonspawn : Bellowing Roar, aucun dégât, Sundered 2 et Demoralized 2
    c = bc({ enemies = { { "rage_talon_dragonspawn", hp = 34 } }, hand = { "brt_hit" } })
    e = c.enemies[1]
    e.intent, e.hp = "cleave", 18
    play(c, "brt_hit", 1)
    eq(e.intent, "roar")
    Combat.endTurn(c)
    eq(c.player.hp, 60); eq(c.player.st.armor_broken, 2); eq(c.player.st.demoralized, 2)
    -- Hatcher : 2 Rookery Whelps (sbires) ; ils fuient à sa mort
    c = bc({ enemies = { { "rookery_hatcher", hp = 28 } }, hand = { "brt_hit", "brt_big" } })
    e = c.enemies[1]
    e.intent, e.hp = "strike", 15
    play(c, "brt_hit", 1)
    eq(e.intent, "hatch")
    Combat.endTurn(c)
    eq(alive(c, "rookery_whelpling"), 2)
    assert(c.enemies[2].minion and c.enemies[3].minion)
    c.hand[#c.hand + 1] = ns.Card.new("brt_big", false, 900)
    play(c, "brt_big", 1)
    eq(c.result, "won", "les sbires fuient")
  end)

  ---------------------------------------------------------------------------
  -- Élites
  ---------------------------------------------------------------------------

  test("Panzor : Invincible (6 par coup, DoT en entier), puis Cracked Plating (+25 %) et Rampage", function()
    local c = bc({ enemies = { "panzor" }, hand = { "brt_hit", "brt_multi", "brt_dot", "brt_hit2" }, kind = "elite" })
    local e = c.enemies[1]
    local m = E.panzor.hp
    eq(e.maxHp, m)
    play(c, "brt_hit", 1)
    eq(e.hp, m - 6, "10 -> 6")
    play(c, "brt_multi", 1)
    eq(e.hp, m - 15, "3 coups de 3")
    play(c, "brt_dot", 1)
    e.intent = "overheat"
    Combat.endTurn(c)
    eq(e.hp, m - 20, "DoT 5 en entier")
    local thr = math.floor(m * 0.5)
    e.hp = thr + 5
    c.hand[#c.hand + 1] = ns.Card.new("brt_hit", false, 901)
    play(c, "brt_hit", 1)
    eq(e.hp, thr - 1); eq(e.mem.phase, 1); eq(e.st.cracked, 1); eq(e.intent, "rampage"); eq(BR.maxHit(e), nil)
    play(c, "brt_hit2", 1)
    eq(e.hp, thr - 1 - 12, "10 × 1,25, sans plafond")
  end)

  test("Rend et Gyth : Rend descend à la moitié (nom, modèle, Strength 2, Cleave) ; les états de Gyth restent", function()
    local c = bc({ enemies = { "rend_gyth" }, hand = { "brt_hit" }, kind = "elite" })
    local e = c.enemies[1]
    e.intent = "corrosive"
    Combat.endTurn(c)
    eq(c.player.st.armor_broken, 2)
    e.hp = 51
    c.hand[#c.hand + 1] = ns.Card.new("brt_hit", false, 902)
    play(c, "brt_hit", 1)
    eq(Combat.enemyName(e), "Warchief Rend Blackhand"); eq(e.art, "rend_blackhand")
    eq(e.st.force, 2); eq(e.intent, "cleave")
    assert((c.player.st.armor_broken or 0) > 0, "Sundered reste")
  end)

  test("Vaelastrasz : 35 % des PV, Essence of the Red (+2 mana), Burning Adrenaline (+50 %, puis 15 PV), Essence Fades", function()
    local c = bc({ enemies = { "vaelastrasz" }, hand = { "brt_hit", "brt_hit2" }, kind = "elite", hp = 80 })
    local e = c.enemies[1]
    eq(e.maxHp, 200); eq(e.hp, 70)
    eq(c.player.st.essence_of_red, 1); eq(c.player.mana, 5)
    Combat.applyStatus(c, c.player, "burning_adrenaline", 2)
    play(c, "brt_hit", 1)
    eq(e.hp, 55, "10 × 1,5")
    -- Burning Adrenaline posée pendant le tour du joueur : 2 rounds, puis 15 PV (ennemi inerte)
    local d = bc({ enemies = { "zt_dummy" }, hp = 80 })
    Combat.applyStatus(d, d.player, "burning_adrenaline", 2)
    Combat.endTurn(d)
    eq(d.player.hp, 80, "rien à la fin du premier round")
    Combat.endTurn(d)
    eq(d.player.hp, 65, "15 PV à la fin de Burning Adrenaline")
    eq(d.player.st.burning_adrenaline, nil)
    -- seuil de 15 % : l'Essence prend fin, Fire Nova
    e.hp = 31
    play(c, "brt_hit2", 1)
    eq(e.mem.phase, 1); eq(c.player.st.essence_of_red, nil); eq(e.intent, "nova")
    e.intent = "adrenaline"
    Combat.endTurn(c)
    eq(c.player.mana, 3, "mana de base au tour suivant")
  end)

  ---------------------------------------------------------------------------
  -- Boss : Nefarian
  ---------------------------------------------------------------------------

  local function nef(o)
    o.enemies = o.enemies or { "nefarian", "red_drakonid", "blue_drakonid" }
    o.kind = "boss"
    o.hp = o.hp or 100
    local c = bc(o)
    return c, c.enemies[1]
  end

  test("Nefarius : Shadow of the Throne (moitié tant qu'un Drakonid vit, DoT compris), Drakonids tués comptés", function()
    local c, n = nef({ hand = { "brt_hit", "brt_dot", "brt_big", "brt_big2", "brt_hit2" } })
    local M = E.nefarian.hp
    eq(n.maxHp, M); eq(Combat.enemyName(n), "Lord Victor Nefarius")
    play(c, "brt_hit", 1)
    eq(n.hp, M - 5, "10 -> 5")
    play(c, "brt_dot", 1)
    n.intent = "volley"
    for i = 2, 3 do c.enemies[i].intent = "claw" end
    Combat.endTurn(c)
    eq(n.hp, M - 5 - 2, "DoT 5 -> 2")
    play(c, "brt_big", 2)
    play(c, "brt_big2", 3)
    eq(n.mem.fallen, 2)
    local hp = n.hp
    play(c, "brt_hit2", 1)
    eq(n.hp, hp - 10, "plus de Drakonid : dégâts entiers")
  end)

  test("Nefarius : appel des Drakonids sous 2, Dark Mending sur un allié blessé, sinon le motif", function()
    local c, n = nef({ enemies = { "nefarian", "red_drakonid" } })
    Combat.chooseIntent(c, n)
    eq(n.intent, "call")
    n.mem.last = "call"
    c.enemies[2].hp = 3
    Combat.chooseIntent(c, n)
    eq(n.intent, "mending")
    n.mem.last = "call"
    c.enemies[2].hp = c.enemies[2].maxHp
    Combat.chooseIntent(c, n)
    eq(n.intent, "shadow_bolt", "rien à soigner, appel déjà fait : le motif")
    n.intent = "call"
    Combat.endTurn(c)
    eq(alive(c, "blue_drakonid"), 1, "couleur absente d'abord")
  end)

  test("Nefarian : plafond au seuil de 75 %, nom et modèle, Class Call (pas un Cast), Throne terminé", function()
    local c, n = nef({ hand = { "brt_big", "brt_hit" } })
    local t75 = math.floor(E.nefarian.hp * 0.75)
    n.hp = t75 + 6
    play(c, "brt_big", 1)
    eq(n.hp, t75, "60 / 2 = 30, plafonné au seuil")
    eq(n.mem.phase, 1); eq(Combat.enemyName(n), "Nefarian"); eq(n.art, "nefarian_dragon")
    eq(n.intent, "class_call"); eq(E.nefarian.moves.class_call.cast, nil)
    play(c, "brt_hit", 1)
    eq(n.hp, t75 - 10, "Throne terminé : 10 entiers")
    Combat.applyStatus(c, n, "stunned", 1)
    eq(n.st.stunned, nil, "immunisé à Stunned")
  end)

  test("Class Call : un état par classe (2 tours), effets sur le moteur de chaque classe", function()
    local function called(cl, o)
      o = o or {}
      o.class = cl
      local c, n = nef(o)
      n.mem.phase = 1
      n.intent = "class_call"
      for i = 2, 3 do c.enemies[i].dead = true end
      Combat.endTurn(c)
      return c, n
    end
    -- Priest : chaque soin pose DoT 3
    local c = called("priest", { hand = { "brt_heal" }, deck = { "brt_heal", "brt_heal", "brt_heal", "brt_heal" } })
    eq(c.player.st.corrupted_healing, 2)
    c.player.hp = 50
    play(c, "brt_heal")
    eq(c.player.st.pain, BR.CORRUPTED_DOT)
    -- Warrior : Attacks + BERSERKER_BONUS, coups reçus × 1,25
    c = called("warrior", { hand = { "brt_hit" }, deck = { "brt_hit", "brt_hit", "brt_hit", "brt_hit" } })
    eq(c.player.st.berserker_stance, 2)
    local n = c.enemies[1]
    local hp = n.hp
    play(c, "brt_hit", 1)
    eq(hp - n.hp, 10 + BR.BERSERKER_BONUS)
    n.intent = "tail_sweep"
    eq(Combat.intentInfo(c, n).damage, math.floor(atk("nefarian", "tail_sweep") * 1.25))
    -- Mage : Cast cards +1
    c = called("mage", { hand = { "brt_cast" }, deck = { "brt_cast", "brt_cast", "brt_cast", "brt_cast" } })
    eq(c.player.st.wild_polymorph, 2)
    eq(Combat.cost(c, c.hand[1]), 2)
    -- Rogue : Parry et Stealth perdus, plus de Stealth
    local cr = bc({ class = "rogue", enemies = { "nefarian" }, kind = "boss" })
    cr.player.st.parry = 2
    assert((cr.player.st.stealth or 0) > 0, "Stealth du début de combat")
    cr.enemies[1].mem.phase, cr.enemies[1].intent = 1, "class_call"
    Combat.endTurn(cr)
    eq(cr.player.st.called_out, 2); eq(cr.player.st.parry, nil); eq(cr.player.st.stealth, nil)
    Combat.applyStatus(cr, cr.player, "stealth", 1)
    eq(cr.player.st.stealth, nil, "pas de Stealth")
    -- Hunter : Attack cards -3, familier inchangé
    c = called("hunter", { hand = { "brt_hit" }, deck = { "brt_hit", "brt_hit", "brt_hit", "brt_hit" } })
    eq(c.player.st.broken_bow, 2)
    n = c.enemies[1]
    hp = n.hp
    play(c, "brt_hit", 1)
    eq(hp - n.hp, 7)
    eq(Combat.calcDamage(c, c.player, n, 5, nil), 5, "coup sans carte (familier) : inchangé")
    -- durée : 2 tours du joueur
    n.intent = "veil"
    Combat.endTurn(c)
    eq(c.player.st.broken_bow, 1)
    Combat.endTurn(c)
    eq(c.player.st.broken_bow, nil)
    -- classe sans état propre : Demoralized
    eq(BR.classCall("shaman").status, "demoralized")
  end)

  test("Veil of Shadow (soins et Regen à moitié), Shadow Flame (DoT, sauf Onyxia Scale Cloak)", function()
    local c, n = nef({ hand = { "brt_heal" } })
    n.mem.phase, n.intent = 1, "veil"
    for i = 2, 3 do c.enemies[i].dead = true end
    Combat.endTurn(c)
    eq(c.player.st.veil_of_shadow, E.nefarian.moves.veil.actions[2][3])
    c.player.hp = 50
    c.hand[#c.hand + 1] = ns.Card.new("brt_heal", false, 903)
    play(c, "brt_heal")
    eq(c.player.hp, 54)
    n.intent = "shadow_flame"
    Combat.endTurn(c)
    eq(c.player.st.pain, 2, "DoT 3, un tic au début du tour")
    local d, m = nef({ relics = { "onyxia_scale_cloak" } })
    m.mem.phase, m.intent = 1, "shadow_flame"
    for i = 2, 3 do d.enemies[i].dead = true end
    Combat.endTurn(d)
    eq(d.player.st.pain, nil, "pas de DoT avec la cape")
    eq(d.player.hp, 100 - (atk("nefarian", "shadow_flame") - 2), "et 2 de moins par coup")
  end)

  test("Phase 3 : Bone Constructs (un par Drakonid tué, 3 au plus) agissent tout de suite, Frenzy, Shadowflame Fury", function()
    local c, n = nef({ hand = { "brt_big" }, hp = 200 })
    for i = 2, 3 do c.enemies[i].dead = true end
    n.mem.phase, n.mem.fallen = 1, 2
    n.name, n.art = "Nefarian", "nefarian_dragon"
    local t25 = math.floor(E.nefarian.hp * 0.25)
    n.hp = t25 + 4
    n.intent = "tail_sweep"
    play(c, "brt_big", 1)
    eq(n.hp, t25, "plafonné au seuil de 25 %")
    eq(n.mem.phase, 2); eq(alive(c, "bone_construct"), 2); eq(n.st.force, 3); eq(n.st.shadowflame_fury, 3)
    eq(n.intent, "roar")
    Combat.endTurn(c)
    local rv, rk = atk("nefarian", "roar")
    eq(c.player.hp, 200 - (rv + 3) * rk - atk("bone_construct", "strike") * 2, "Bellowing Roar et les deux Bone Constructs")
    n.intent = "roar"
    Combat.endTurn(c)
    eq(n.st.force, 3)
    n.intent = "roar"
    Combat.endTurn(c)
    eq(n.st.force, 3 + BR.FURY_STRENGTH, "Shadowflame Fury arrivée à son terme")
    -- au plus 3
    local d, m = nef({ hand = { "brt_big" }, hp = 200 })
    for i = 2, 3 do d.enemies[i].dead = true end
    m.mem.phase, m.mem.fallen, m.hp = 1, 5, t25 + 4
    play(d, "brt_big", 1)
    eq(alive(d, "bone_construct"), 3)
  end)

  test("Nefarian : mort, victoire, sbires en fuite ; état de zone en données simples, clonable", function()
    local c, n = nef({ hand = { "brt_big", "brt_hit" } })
    n.hp = 85
    play(c, "brt_big", 1)
    local ok, why = T.plainData(c.zs) assert(ok, why)
    for _, e in ipairs(c.enemies) do ok, why = T.plainData(e.zs or {}) assert(ok, why) end
    local k = Combat.clone(c)
    k.enemies[1].zs.blackrock.opening = "x"
    eq(BR.opening(n), "class_call", "copie profonde")
    n.hp = 5
    play(c, "brt_hit", 1)
    eq(c.result, "won")
  end)

  ---------------------------------------------------------------------------
  -- Commun, bibelots de clé, Grim Guzzler
  ---------------------------------------------------------------------------

  test("Commun de la zone 7 : 2 neutres, 3 bibelots, case Grim Guzzler ; bibelots de clé +1, +3, +5", function()
    local cc = Meta.commonContent(7)
    table.sort(cc.cards) table.sort(cc.relics)
    eq(table.concat(cc.cards, ","), "dark_iron_ale_mug,dark_iron_bomb")
    eq(table.concat(cc.relics, ","), "black_dragonscale,blood_of_the_mountain,shadowforge_key")
    local kr = Meta.keyRelics("priest", "blackrock")
    local lv = {}
    for _, e in ipairs(kr) do lv[e.level] = e.id end
    eq(lv[1], "blackhands_breadth"); eq(lv[3], "draconic_infused_emblem"); eq(lv[5], "neltharions_tear")
    eq(X.NODE_KINDS.grim_guzzler.tier, 7); eq(X.NODE_KINDS.grim_guzzler.zone, "blackrock")
  end)

  test("Neutres : Dark Iron Bomb (4 à tous, Stunned 1, pas le boss), Dark Iron Ale Mug (Pay 3 HP, Strength 2)", function()
    local c = bc({ enemies = { { "firebrand_grunt", hp = 25 }, { "firebrand_grunt", hp = 25 } }, hand = { "dark_iron_bomb", "dark_iron_ale_mug" } })
    c.player.mana = 3
    play(c, "dark_iron_bomb")
    eq(c.enemies[1].hp, 21); eq(c.enemies[2].st.stunned, 1)
    play(c, "dark_iron_ale_mug")
    eq(c.player.hp, 57); eq(c.player.st.force, 2)
  end)

  test("Bibelots : Blood of the Mountain, Black Dragonscale, Blackhand's Breadth, Emblem (une pioche par coup), Tear", function()
    local c = bc({ enemies = { { "blackhand_veteran", hp = 40 } }, hand = { "brt_hit", "brt_hit2" },
      deck = { "brt_dot", "brt_dot", "brt_dot", "brt_dot", "brt_dot", "brt_dot" },
      relics = { "blood_of_the_mountain", "blackhands_breadth", "draconic_infused_emblem" } })
    local e = c.enemies[1]
    e.hp = 25
    local hand = #c.hand
    play(c, "brt_hit", 1)
    eq(e.hp, 15); eq(e.mem.phase, 1)
    eq(c.player.block, 4, "Blood of the Mountain")
    eq(#c.hand, hand - 1 + 1, "Emblem : une seule pioche (phase et moitié sur le même coup)")
    play(c, "brt_hit2", 1)
    eq(e.hp, 1, "Blackhand's Breadth : +4 sous la moitié")
    -- Black Dragonscale : -4 sur une attaque Cast
    local d = bc({ enemies = { { "firebrand_pyromancer", hp = 30 } }, relics = { "black_dragonscale" } })
    d.enemies[1].intent = "fireball"
    Combat.endTurn(d)
    eq(d.player.hp, 60 - (atk("firebrand_pyromancer", "fireball") - 4))
    -- Neltharion's Tear : la première carte du tour coûte 1 de moins
    local t = bc({ enemies = { "zt_dummy" }, hand = { "brt_cast", "brt_cast" }, relics = { "neltharions_tear" } })
    eq(Combat.cost(t, t.hand[1]), 0)
    play(t, "brt_cast", 1)
    t.player.cast = nil
    eq(Combat.cost(t, t.hand[1]), 1)
  end)

  local function bexp(o)
    o = o or {}
    return X.new({ seed = o.seed or 5, class = o.class or "priest", zone = "blackrock", flags = o.flags,
      unlocks = { level = 7, common = o.common or 7, won = { blackrock = 5 } } })
  end

  test("Shadowforge Key : un coffre contient aussi une potion", function()
    local exp = bexp()
    exp.relics[#exp.relics + 1] = "shadowforge_key"
    local r = X.rollReward(exp, "chest")
    assert(r.potion, "potion dans le coffre")
  end)

  test("Grim Guzzler : boisson offerte (combat suivant), seconde à 30 po parmi les trois autres ; seulement à Blackrock", function()
    local exp = bexp()
    local kinds = X.nodeKindsFor(exp)
    local has = false
    for _, k in ipairs(kinds) do if k == "grim_guzzler" then has = true end end
    assert(has, "case proposée à Blackrock (palier 7)")
    local low = bexp({ common = 6 })
    for _, k in ipairs(X.nodeKindsFor(low)) do assert(k ~= "grim_guzzler", "pas avant la première victoire du compte") end
    local w = X.new({ seed = 5, class = "priest", zone = "westfall", unlocks = { level = 7, common = 7 } })
    for _, k in ipairs(X.nodeKindsFor(w)) do assert(k ~= "grim_guzzler", "pas à Westfall") end
    exp.node, exp.phase = exp.map.start[1], "map"
    X.openEvent(exp, "grim_guzzler")
    assert(X.act(exp, { "choose", 1 }))
    eq(exp.phase, "event"); eq(exp.event.id, "grim_guzzler_ale"); eq(#exp.nextCombat, 1)
    for _, ch in ipairs(ns.Events.grim_guzzler_ale.choices) do assert(ch.label ~= "Dark Iron Ale", "trois autres") end
    eq(#ns.Events.grim_guzzler_ale.choices, 4)
    exp.gold, exp.hp = 40, exp.maxHp - 20
    local hp = exp.hp
    local li
    for i, ch in ipairs(ns.Events.grim_guzzler_ale.choices) do if ch.label == "Thunderbrew Lager" then li = i end end
    assert(X.act(exp, { "choose", li }))
    eq(exp.gold, 10); eq(exp.hp, hp + 12)
    X.startFight(exp, "combat")
    eq(exp.combat.player.st.force, 2, "Dark Iron Ale au combat suivant")
  end)

  test("Rencontres de Blackrock : données complètes, décor de la zone, réponse toujours possible, PV jamais sous 1", function()
    local KNOWN = { heal = true, healPct = true, loseHp = true, maxHp = true, loseMaxHp = true, gold = true, pay = true,
      card = true, cardChoice = true, relic = true, potion = true, upgradeRandom = true, upgrade = true, remove = true,
      fight = true, gamble = true }
    local n = 0
    for id, ev in pairs(ns.Events) do
      if ev.zone == "blackrock" then
        n = n + 1
        assert(ev.name and ev.text and ev.speaker and ev.npc, id)
        assert(type(ev.scene) == "string" and ev.scene:find("^blackrock_"), id .. " : décor " .. tostring(ev.scene))
        local free = false
        for ci, ch in ipairs(ev.choices) do
          assert(ch.label and ch.outcome, id .. " " .. ci)
          local needs = ch.when ~= nil
          for _, e in ipairs(ch.effects) do
            assert(KNOWN[e[1]] or X.EFFECTS[e[1]], id .. " : effet " .. e[1])
            if e[1] == "fight" then assert(ns.Encounters.blackrock[e[2] or "normal"], id .. " : groupe " .. tostring(e[2])) end
            if e[1] == "pay" or e[1] == "remove" or e[1] == "upgrade" then needs = true end
          end
          if not needs then free = true end
        end
        assert(free or ev.node, id .. " : une réponse toujours possible")
        if not ev.node then
          for ci = 1, #ev.choices do
            local exp = bexp({ seed = 3 + ci })
            exp.node, exp.phase = exp.map.start[1], "map"
            X.openEvent(exp, id)
            exp.hp, exp.maxHp, exp.gold = 1, 8, 500
            local ok, why = X.act(exp, { "choose", ci })
            assert(ok or why == "relic", id .. " " .. ci .. " : " .. tostring(why))
            if exp.phase ~= "combat" then assert(exp.hp >= 1 and exp.hp <= exp.maxHp, id .. " " .. ci) end
          end
        end
      end
    end
    eq(n, 8 + 5, "8 rencontres et 5 étapes du Grim Guzzler")
  end)

  ---------------------------------------------------------------------------
  -- Titre, Rallying Cry, Westfall
  ---------------------------------------------------------------------------

  test("Dragonslayer (Nefarian vaincu avec la classe), Veteran au niveau 7, Rallying Cry (+6 PV max, une fois)", function()
    local meta = Meta.new()
    eq(BR.title(meta, "priest"), nil)
    Meta.classState(meta, "priest").xp = Meta.XP_LEVELS[7]
    eq(BR.title(meta, "priest"), "Veteran")
    local exp = bexp({ class = "priest" })
    X.fire(exp, "onCombatWon", "elite")
    eq(exp.newFlags["dragonslayer:priest"], nil)
    X.fire(exp, "onCombatWon", "boss")
    assert(exp.newFlags["dragonslayer:priest"] and exp.newFlags.rallying_cry)
    exp.result = "won"
    Meta.record(meta, exp)
    eq(BR.title(meta, "priest"), "Dragonslayer"); eq(BR.title(meta, "mage"), nil)
    local hp = ns.Classes.mage.hp
    local nx = X.new({ seed = 2, class = "mage", zone = "westfall", flags = meta.flags, unlocks = { level = 1 } })
    eq(nx.maxHp, hp + 6); eq(nx.hp, hp + 6)
    nx.result = "lost"
    Meta.record(meta, nx)
    local again = X.new({ seed = 3, class = "mage", zone = "westfall", flags = meta.flags, unlocks = { level = 1 } })
    eq(again.maxHp, hp, "une seule fois")
  end)

  test("Westfall inchangée : aucune règle de Blackrock hors de la zone", function()
    local list = Combat.zoneRulesFor("westfall") or {}
    for _, id in ipairs(list) do assert(id ~= "blackrock") end
    local c = combat({ zone = "westfall", enemies = { "gnoll" } })
    assert(not (c.zs and c.zs.blackrock))
  end)

  test("Simulation : une expédition à Blackrock (bot glouton) va au bout", function()
    local rec, exp = ns.SimExpedition.play({ seed = 4, class = "rogue", zone = "blackrock", zones = 6, level = 7, bot = "greedy" })
    eq(exp.phase, "done"); eq(exp.zone, "blackrock")
  end)
end
