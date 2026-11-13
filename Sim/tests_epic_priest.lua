-- Tests des sept cartes épiques du Prêtre (docs/zones/cartes-de-zone.md, « Priest ») : cas nominaux et cas
-- limites de la fiche. L'épique est posée en jeu (c.epic) comme le fait Combat.new, et un test vérifie qu'une
-- épique placée dans le deck de départ est active et dans aucune pile.
-- Usage : lua5.1 Sim/tests_epic_priest.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local Combat, Card, Save, P = ns.Combat, ns.Card, ns.Save, ns.Priest

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

---------------------------------------------------------------------------
-- Ennemis de test (retirés à la fin)
---------------------------------------------------------------------------
local E = ns.Enemies
E.tp_dummy = { name = "Dummy", hp = 100, moves = { idle = { name = "Idle", intent = "buff", actions = {} } },
  pattern = { "idle" } }
E.tp_hitter = { name = "Hitter", hp = 100,
  moves = { hit = { name = "Hit", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }
E.tp_twice = { name = "Twice", hp = 100,
  moves = { hit = { name = "Hits", intent = "attack", actions = { { "attack", 5, times = 2 } } } }, pattern = { "hit" } }
E.tp_kicker = { name = "Kicker", hp = 100,
  moves = { kick = { name = "Kick", intent = "attack", actions = { { "attack", 6, interrupts = true } } } },
  pattern = { "kick" } }

local function deckOf(list)
  local d = {}
  for i, id in ipairs(list) do d[i] = { id = id, up = false } end
  return d
end

-- Combat du Prêtre à main imposée (le reste en pioche) ; opts : hp, maxHp, encounter, extra (pioche).
local function setup(hand, opts)
  opts = opts or {}
  local list = {}
  for _, id in ipairs(hand) do list[#list + 1] = id end
  for _, id in ipairs(opts.extra or { "smite", "smite", "smite", "smite", "smite", "smite" }) do list[#list + 1] = id end
  local c = Combat.new({ seed = opts.seed or 7, class = "priest", hp = opts.hp or 60, maxHp = opts.maxHp or 60,
    deck = deckOf(list), encounter = opts.encounter or { "tp_dummy" } })
  local all = {}
  for _, x in ipairs(c.hand) do all[#all + 1] = x end
  for _, x in ipairs(c.draw) do all[#all + 1] = x end
  c.hand, c.draw = {}, {}
  local byId = {}
  for _, x in ipairs(all) do byId[x.id] = byId[x.id] or {}; table.insert(byId[x.id], x) end
  for _, id in ipairs(hand) do c.hand[#c.hand + 1] = table.remove(byId[id]) end
  for _, l in pairs(byId) do for _, x in ipairs(l) do c.draw[#c.draw + 1] = x end end
  return c
end

-- Pose l'épique en jeu comme Combat.new le fait pour l'épique du deck (c.epic, hors de toute pile).
local function epic(c, id, up)
  c.epic = { id = id, up = up or false, uid = 900 }
  local d = Card.defById(id, up)
  if d.whileInDeck then d.whileInDeck(c, c.epic) end
end

local function hi(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
  error("carte absente de la main : " .. id, 2)
end

local function play(c, id, t)
  local ok, why = Combat.play(c, hi(c, id), t)
  assert(ok, "jouée : " .. id .. " (" .. tostring(why) .. ")")
end

local function power(c, id, up)
  c.player.powers[#c.player.powers + 1] = Card.new(id, up or false, 800 + #c.player.powers)
end

local function hp(c) local t = {} for i, e in ipairs(c.enemies) do t[i] = e.hp end return t end

---------------------------------------------------------------------------
-- Données et socle
---------------------------------------------------------------------------
test("données : sept épiques, une par zone, coût 0 jamais payé, sans niveau, plaque Epic, améliorables", function()
  local zones = {}
  for _, id in ipairs(P.EPICS) do
    local d = ns.Cards[id]
    assert(d, id)
    eq(d.rarity, "epic", id); eq(d.class, "priest", id); eq(d.type, "power", id); eq(d.epic, true, id)
    eq(d.cost, 0, id .. " : coût (jamais payé)"); eq(d.level, nil, id .. " : niveau")
    assert(d.deckHooks, id .. " : crochets")
    assert(d.text:find("^Epic%.\n"), id .. " : « Epic. » en tête")
    assert(d.up and d.up.text, id .. " : amélioration")
    assert(not zones[d.zone], "une par zone"); zones[d.zone] = true
    eq(ns.Meta.zoneCards("priest", d.zone)[1], id)
  end
  for _, z in ipairs({ "westfall", "duskwood", "wetlands", "stranglethorn", "swamp", "steppes", "blackrock" }) do
    assert(zones[z], z)
  end
  eq(ns.Language.plateWord(ns.Language.plateByKey("epic"), ns.Cards.misery), "Epic")
end)

test("socle : une épique posée dans le deck de départ est en jeu (c.epic), dans aucune pile", function()
  for _, id in ipairs(P.EPICS) do
    local deck = deckOf({ "smite", "smite", "smite", "inner_fire", "inner_fire", "pw_shield", "sw_pain" })
    deck[#deck + 1] = { id = id, up = true }
    local c = Combat.new({ seed = 3, class = "priest", hp = 40, deck = deck, encounter = { "tp_dummy" } })
    local got, up = P.epicOf(c)
    eq(got, id); eq(up, true)
    for _, pile in ipairs({ c.hand, c.draw, c.discard, c.exhaust }) do
      for _, inst in ipairs(pile) do assert(inst.id ~= id, id .. " : dans aucune pile") end
    end
    assert(Save.isPlain(c), id .. " : combat sauvegardable")
  end
  local c = Combat.new({ seed = 3, class = "priest", hp = 40, deck = deckOf({ "smite", "smite" }), encounter = { "tp_dummy" } })
  eq(P.epicOf(c), nil, "sans épique")
end)

---------------------------------------------------------------------------
-- Prayer of Mending
---------------------------------------------------------------------------
test("Prayer of Mending : chaque soin inflige les PV rendus à un ennemi vivant au hasard", function()
  local c = setup({ "flash_heal", "flash_heal" }, { hp = 50 })
  epic(c, "prayer_of_mending")
  play(c, "flash_heal")
  eq(c.player.hp, 57); eq(c.enemies[1].hp, 93, "7 rendus = 7 dégâts")
  play(c, "flash_heal")
  eq(c.player.hp, 60); eq(c.enemies[1].hp, 90, "3 rendus seulement (plein)")
  Combat.heal(c, c.player, 5)
  eq(c.enemies[1].hp, 90, "à pleine vie : rien")
end)

test("Prayer of Mending amélioré : + 2, seulement si un PV est rendu", function()
  local c = setup({ "flash_heal" }, { hp = 50 })
  epic(c, "prayer_of_mending", true)
  play(c, "flash_heal")
  eq(c.enemies[1].hp, 91, "7 + 2")
  c.player.hp = c.player.maxHp
  Combat.heal(c, c.player, 4)
  eq(c.enemies[1].hp, 91, "amélioré à pleine vie : rien")
end)

test("Prayer of Mending : toutes sources (tic de Regen, Atonement), coup sans carte (Sundered, pas Shadowform)", function()
  local c = setup({ "solace" }, { hp = 40 })
  epic(c, "prayer_of_mending")
  power(c, "shadowform")
  c.player.st.atonement = 2
  play(c, "solace", 1)
  -- Solace 4 (holy, pas de bonus) + Atonement 2 rendus → 2 dégâts sans carte
  eq(c.enemies[1].hp, 100 - 4 - 2)
  Combat.applyStatus(c, c.enemies[1], "armor_broken", 2)
  Combat.applyStatus(c, c.player, "regen", 4)
  local before = c.enemies[1].hp
  Combat.endTurn(c)
  -- tic de Regen 4 : 4 rendus → 4 × 1,25 = 5
  eq(before - c.enemies[1].hp, 5, "tic de Regen, Sundered")
end)

test("Prayer of Mending : la cible tuée, le soin suivant en tire une autre ; dernière cible tuée = victoire", function()
  local c = setup({ "flash_heal", "flash_heal" }, { hp = 30, encounter = { "tp_dummy", "tp_dummy" } })
  epic(c, "prayer_of_mending")
  c.enemies[1].hp = 1
  c.enemies[2].hp = 5
  play(c, "flash_heal")
  local dead = (c.enemies[1].dead and 1 or 0) + (c.enemies[2].dead and 1 or 0)
  eq(dead, 1, "une cible tuée")
  play(c, "flash_heal")
  eq(c.result, "won", "le second soin vise l'ennemi restant")
end)

---------------------------------------------------------------------------
-- Misery
---------------------------------------------------------------------------
local THREE = { "tp_dummy", "tp_dummy", "tp_dummy" }

test("Misery : le DoT posé sur une cible va aussi à chaque autre ennemi vivant (amélioré : +1)", function()
  local c = setup({ "sw_pain" }, { encounter = THREE })
  epic(c, "misery")
  c.enemies[3].dead = true
  play(c, "sw_pain", 1)
  eq(c.enemies[1].st.pain, 5); eq(c.enemies[2].st.pain, 5); eq(c.enemies[3].st.pain, nil, "mort : rien")
  local u = setup({ "sw_pain" }, { encounter = THREE })
  epic(u, "misery", true)
  play(u, "sw_pain", 2)
  eq(u.enemies[2].st.pain, 5); eq(u.enemies[1].st.pain, 6); eq(u.enemies[3].st.pain, 6)
end)

test("Misery : valeur finale copiée (Shadowform compris), sans repasser par le crochet apply ni boucler", function()
  local c = setup({ "vampiric_touch" }, { encounter = THREE })
  epic(c, "misery")
  power(c, "shadowform")
  play(c, "vampiric_touch", 1)
  eq(c.enemies[1].st.pain, 6, "3 + 3"); eq(c.enemies[2].st.pain, 6, "copie de 6, pas 9"); eq(c.enemies[3].st.pain, 6)
end)

test("Misery : « to all » (Mind Sear) ne copie rien ; le DoT sur soi (Shadow Mend) non plus", function()
  local c = setup({ "mind_sear", "shadow_mend" }, { encounter = THREE })
  epic(c, "misery")
  play(c, "mind_sear")
  for i = 1, 3 do eq(c.enemies[i].st.pain, 5, "Mind Sear " .. i) end
  play(c, "shadow_mend")
  for i = 1, 3 do eq(c.enemies[i].st.pain, 5, "Shadow Mend " .. i) end
  eq(c.player.st.pain, 2)
end)

test("Misery : Surge de Devouring Plague, DoT de Holy Fire incantée, DoT hors carte non copié", function()
  local c = setup({ "devouring_plague", "holy_fire" }, { encounter = THREE })
  epic(c, "misery")
  c.player.res = 3
  play(c, "devouring_plague", 1)
  eq(c.enemies[1].st.pain, 6); eq(c.enemies[2].st.pain, 6); eq(c.enemies[3].st.pain, 6)
  play(c, "holy_fire", 2)
  Combat.endTurn(c) -- les DoT tiquent (6 → 5), puis Holy Fire se résout : DoT 3 sur la cible et les autres
  eq(c.enemies[2].st.pain, 8); eq(c.enemies[1].st.pain, 8); eq(c.enemies[3].st.pain, 8)
  Combat.applyStatus(c, c.enemies[1], "pain", 4)
  eq(c.enemies[2].st.pain, 8, "pas une carte : pas de copie")
end)

test("Misery : boss seul = un deck de DoT ordinaire", function()
  local c = setup({ "sw_pain" })
  epic(c, "misery")
  play(c, "sw_pain", 1)
  eq(c.enemies[1].st.pain, 5)
end)

---------------------------------------------------------------------------
-- Echo of Light
---------------------------------------------------------------------------
test("Echo of Light : le tic de Regen ne soigne plus, il frappe chaque ennemi vivant (+ 7), puis baisse de 1", function()
  local c = setup({ "renew" }, { hp = 40, encounter = { "tp_dummy", "tp_dummy" } })
  epic(c, "echo_of_light")
  play(c, "renew")
  Combat.endTurn(c)
  eq(c.player.hp, 40, "aucun soin"); eq(c.enemies[1].hp, 90, "3 + 7"); eq(c.enemies[2].hp, 90)
  eq(c.player.st.regen, 2)
  local u = setup({ "renew" }, { hp = 40, encounter = { "tp_dummy", "tp_dummy" } })
  epic(u, "echo_of_light", true)
  play(u, "renew")
  Combat.endTurn(u)
  eq(u.enemies[1].hp, 88, "amélioré : 3 + 9")
end)

test("Echo of Light : les autres soins soignent ; Sundered s'applique ; Spirit of Redemption frappe", function()
  local c = setup({ "flash_heal" }, { hp = 30 })
  epic(c, "echo_of_light")
  play(c, "flash_heal")
  eq(c.player.hp, 37, "Flash Heal soigne")
  Combat.applyStatus(c, c.enemies[1], "armor_broken", 3)
  c.player.st.regen = 4
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 87, "(4 + 7) × 1,25")
  -- Spirit of Redemption : Regen 6 au Last Breath, qui frappe au tic
  local s = setup({ "smite" }, { hp = 5, encounter = { "tp_hitter" } })
  epic(s, "echo_of_light")
  power(s, "spirit_of_redemption")
  Combat.endTurn(s)
  eq(s.player.hp, 1, "sauvé, puis aucun soin"); eq(s.enemies[1].hp, 87, "Regen 6 + 7 frappe")
end)

test("Echo of Light : un tic qui tue le dernier ennemi gagne le combat", function()
  local c = setup({ "smite" })
  epic(c, "echo_of_light")
  c.enemies[1].hp = 2
  c.player.st.regen = 3
  Combat.endTurn(c)
  eq(c.result, "won")
end)

---------------------------------------------------------------------------
-- Shadow Covenant
---------------------------------------------------------------------------
test("Shadow Covenant : une carte Shadow coûte 0 mana et 3 PV par point ; Holy et coût 0 inchangés", function()
  local c = setup({ "mind_blast", "smite", "devouring_plague" }, { hp = 50 })
  epic(c, "shadow_covenant")
  local i = hi(c, "mind_blast")
  eq(Combat.cost(c, c.hand[i]), 0); eq(Combat.payHpOf(c, Card.def(c.hand[i]), c.hand[i]), 3)
  play(c, "mind_blast", 1)
  eq(c.player.mana, 3, "mana gardé"); eq(c.player.hp, 47, "3 PV payés")
  play(c, "smite", 1)
  eq(c.player.mana, 2, "Smite : 1 mana"); eq(c.player.hp, 47)
  c.player.res = 2
  play(c, "devouring_plague", 1)
  eq(c.player.hp, 47, "coût 0 : aucun PV")
end)

test("Shadow Covenant : le paiement ignore l'Absorb, compte comme une perte de PV, jamais mortel", function()
  local c = setup({ "mind_flay", "mind_flay" }, { hp = 4 })
  epic(c, "shadow_covenant")
  c.player.block = 10
  play(c, "mind_flay", 1)
  eq(c.player.hp, 1); eq(c.player.block, 10)
  local ok, why = Combat.canPlay(c, hi(c, "mind_flay"))
  assert(not ok); eq(why, "hp", "ferait tomber à 0")
end)

test("Shadow Covenant amélioré : la première carte Shadow du tour ne coûte rien, la suivante paie", function()
  local c = setup({ "mind_blast", "mind_flay", "sw_pain" }, { hp = 50 })
  epic(c, "shadow_covenant", true)
  play(c, "mind_blast", 1)
  eq(c.player.hp, 50, "gratuite"); eq(c.player.mana, 3)
  play(c, "mind_flay", 1)
  eq(c.player.hp, 47, "la suivante paie")
  Combat.endTurn(c)
  c.hand[#c.hand + 1] = Card.new("sw_pain", false, 777)
  local hpNow = c.player.hp
  play(c, "sw_pain", 1)
  eq(c.player.hp, hpNow, "nouveau tour : de nouveau gratuite")
end)

test("Shadow Covenant : tour gratuit (Spirit of Redemption) = ni mana ni PV ; coût final lu (Psychic Scream+ à 0)", function()
  local c = setup({ "mind_blast", "psychic_scream" }, { hp = 50 })
  epic(c, "shadow_covenant")
  c.player.flags.freeTurnActive = true
  play(c, "mind_blast", 1)
  eq(c.player.hp, 50)
  c.player.flags.freeTurnActive = nil
  c.hand[hi(c, "psychic_scream")] = Card.new("psychic_scream", true, 778)
  play(c, "psychic_scream")
  eq(c.player.hp, 50, "coût 0 après amélioration : aucun PV")
end)

---------------------------------------------------------------------------
-- Reflective Shield
---------------------------------------------------------------------------
test("Reflective Shield : un coup qui entame l'Absorb renvoie l'Absorb perdue à son auteur, au plus 2 (amélioré : 4)", function()
  local c = setup({ "inner_fire" }, { encounter = { "tp_hitter" } })
  epic(c, "reflective_shield")
  play(c, "inner_fire")
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 98, "6 absorbés, 2 au plus"); eq(c.player.hp, 56)
  local u = setup({ "inner_fire" }, { encounter = { "tp_hitter" } })
  epic(u, "reflective_shield", true)
  play(u, "inner_fire")
  Combat.endTurn(u)
  eq(u.enemies[1].hp, 96, "amélioré : 4 au plus")
end)

test("Reflective Shield : coup absorbé en entier ; sans Absorb rien ; coup par coup ; Pain Suppression", function()
  local c = setup({ "smite" }, { encounter = { "tp_hitter" } })
  epic(c, "reflective_shield")
  c.player.block = 30
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 98, "10 absorbés en entier, 2 renvoyés")
  local n = setup({ "smite" }, { encounter = { "tp_hitter" } })
  epic(n, "reflective_shield")
  Combat.endTurn(n)
  eq(n.enemies[1].hp, 100, "sans Absorb : rien")
  local t = setup({ "smite" }, { encounter = { "tp_twice" } })
  epic(t, "reflective_shield")
  t.player.block = 7
  Combat.endTurn(t)
  eq(t.enemies[1].hp, 96, "5 puis 2 absorbés : 2 et 2")
  local h = setup({ "pain_suppression" }, { encounter = { "tp_hitter" } })
  epic(h, "reflective_shield")
  play(h, "pain_suppression")
  h.player.block = 30
  Combat.endTurn(h)
  eq(h.enemies[1].hp, 98, "coup divisé avant l'Absorb : 5 absorbés, 2 renvoyés")
end)

test("Reflective Shield : le DoT n'est pas un coup ; un auteur qui n'attaque pas ne renvoie rien", function()
  local c = setup({ "smite" })
  epic(c, "reflective_shield")
  c.player.block = 10
  c.player.st.pain = 3
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 100)
end)

---------------------------------------------------------------------------
-- Voidform
---------------------------------------------------------------------------
test("Voidform : les cartes à Surge sont injouables (raison Voidform)", function()
  local c = setup({ "devouring_plague", "void_eruption", "mind_blast" })
  epic(c, "voidform")
  c.player.res = 5
  local ok, why = Combat.canPlay(c, hi(c, "devouring_plague"))
  assert(not ok); eq(why, P.VOIDFORM_REASON)
  ok, why = Combat.canPlay(c, hi(c, "void_eruption"))
  assert(not ok); eq(why, P.VOIDFORM_REASON)
  assert(Combat.canPlay(c, hi(c, "mind_blast")))
  for _, a in ipairs(Combat.legalPlays(c)) do
    assert(c.hand[a[1]].id == "mind_blast", "seul Mind Blast est un coup légal")
  end
end)

test("Voidform : chaque coup Shadow + 1 par Insanity, lue au coup ; Holy et DoT rien (amélioré : + 2)", function()
  local c = setup({ "mind_blast", "smite" })
  epic(c, "voidform")
  c.player.res = 7
  play(c, "mind_blast", 1)
  eq(c.enemies[1].hp, 100 - 17, "10 + 7 (7 Insanity)")
  eq(c.player.res, 9, "+2 Insanity, sans plafond")
  play(c, "smite", 1)
  eq(c.enemies[1].hp, 83 - 8, "Holy : rien")
  c.enemies[1].st.pain = 5
  local before = c.enemies[1].hp
  Combat.endTurn(c)
  eq(before - c.enemies[1].hp, 5, "DoT : rien")
  local u = setup({ "mind_blast" })
  epic(u, "voidform", true)
  u.player.res = 7
  play(u, "mind_blast", 1)
  eq(u.enemies[1].hp, 100 - 24, "amélioré : 10 + 2 × 7")
end)

---------------------------------------------------------------------------
-- Inner Focus
---------------------------------------------------------------------------
test("Inner Focus : la première carte du tour part en Cast et se résout au tour suivant, valeurs +75 %", function()
  local c = setup({ "smite", "smite" })
  epic(c, "inner_focus")
  play(c, "smite", 1)
  eq(c.enemies[1].hp, 100, "incantée"); eq(c.player.cast.card.id, "smite"); eq(c.player.mana, 2)
  play(c, "smite", 1)
  eq(c.enemies[1].hp, 92, "la deuxième est normale")
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 92 - 14, "8 × 1,75")
  eq(c.player.cast, nil)
  local u = setup({ "smite" })
  epic(u, "inner_focus", true)
  play(u, "smite", 1)
  Combat.endTurn(u)
  eq(u.enemies[1].hp, 84, "amélioré : × 2")
end)

test("Inner Focus : une carte déjà Cast reçoit le bonus (DoT arrondi au supérieur), plus d'autre Cast ce tour", function()
  local c = setup({ "holy_fire", "halo" })
  epic(c, "inner_focus")
  play(c, "holy_fire", 1)
  c.player.mana = 5
  local ok, why = Combat.canPlay(c, hi(c, "halo"))
  assert(not ok); eq(why, "casting")
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 100 - 42, "24 × 1,75"); eq(c.enemies[1].st.pain, 6, "3 × 1,75 = 5,25 → 6")
end)

test("Inner Focus : Absorb incantée gagnée au tour suivant (protège ce tour-là) ; Regen et soin aussi", function()
  local c = setup({ "inner_fire", "smite" }, { encounter = { "tp_hitter" } })
  epic(c, "inner_focus")
  play(c, "inner_fire")
  eq(c.player.block, 0, "rien ce tour")
  Combat.endTurn(c)
  eq(c.player.hp, 50, "le coup passe en entier")
  eq(c.player.block, 11, "6 × 1,75 = 10,5 → 11 au début du tour suivant")
  local h = setup({ "halo" }, { hp = 40, encounter = { "tp_dummy", "tp_dummy" } })
  epic(h, "inner_focus")
  play(h, "halo")
  Combat.endTurn(h)
  eq(h.enemies[1].hp, 61); eq(h.enemies[2].hp, 61, "22 × 1,75 → 39 à tous"); eq(h.player.st.regen, 6, "Regen 3 × 1,75 → 6")
end)

test("Inner Focus : un Power ne compte pas, la carte suivante est la première ; Penance : Absorb par coup aussi", function()
  local c = setup({ "shadowform", "penance" })
  epic(c, "inner_focus")
  play(c, "shadowform")
  eq(c.player.cast, nil)
  c.player.st.atonement = 3
  play(c, "penance", 1)
  eq(c.player.cast.card.id, "penance")
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 100 - 3 * 9, "5 × 1,75 = 8,75 → 9 par coup")
  eq(c.player.block, 12, "2 × 1,75 → 4 Absorb par coup")
end)

test("Inner Focus : incantation coupée = carte perdue ; le tour suivant a de nouveau sa première carte", function()
  local c = setup({ "smite" }, { encounter = { "tp_kicker" } })
  epic(c, "inner_focus")
  play(c, "smite", 1)
  Combat.endTurn(c)
  eq(c.player.cast, nil, "interrompue")
  eq(c.enemies[1].hp, 100)
  eq(c.discard[#c.discard].id, "smite")
  assert(P.focusReady(c), "nouvelle première carte")
  c.hand[#c.hand + 1] = Card.new("smite", false, 779)
  play(c, "smite", 1)
  eq(c.player.cast.card.id, "smite")
end)

---------------------------------------------------------------------------
-- Clone et bots
---------------------------------------------------------------------------
test("clone : l'état des épiques (c.cls) suit la copie sans toucher l'original", function()
  local c = setup({ "smite", "smite" })
  epic(c, "inner_focus")
  local k = Combat.clone(c)
  play(k, "smite", 1)
  assert(P.focusReady(c), "original intact")
  assert(not P.focusReady(k))
  assert(Save.isPlain(k))
end)

test("bots : note des épiques et conseils du deck piloté", function()
  local b = ns.Classes.priest.bot
  for _, id in ipairs(P.EPICS) do assert(b.byEpic[id], id) end
  local exp = { class = "priest", deck = deckOf({ "smite", "renew", "renew", "flash_heal" }) }
  assert(b.epic(exp, "prayer_of_mending") > b.epic(exp, "voidform"), "le deck soigne : Prayer of Mending")
  eq(ns.SimExpedition.epicRating(exp, "misery"), 7)
end)

for _, id in ipairs({ "tp_dummy", "tp_hitter", "tp_twice", "tp_kicker" }) do E[id] = nil end

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
