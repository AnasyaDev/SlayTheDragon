-- Tests des sept cartes épiques du Guerrier (docs/zones/cartes-de-zone.md, « Warrior ») : cas nominaux et
-- cas limites de la fiche. L'épique est posée dans le deck du combat ; les tests ne dépendent pas de la pile
-- où elle se trouve (sa règle est active dès le début du combat).
-- Usage : lua5.1 Sim/tests_epic_warrior.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Save, Combat, Card = ns.Expedition, ns.Meta, ns.Save, ns.Combat, ns.Card
local Warrior = ns.Warrior
local E = Warrior.EPIC

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

ns.Enemies.tw_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.tw_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }
ns.Enemies.tw_double = { name = "Double", hp = 100,
  moves = { hit = { name = "Coups", intent = "attack", actions = { { "attack", 3, times = 2 } } } }, pattern = { "hit" } }

-- Combat du Guerrier : main imposée (le reste en pioche), l'épique `epic` (amélioré si up) dans le deck.
local function setup(hand, opts)
  opts = opts or {}
  local deck = {}
  for i, id in ipairs(hand) do deck[i] = { id = id, up = false } end
  for _, id in ipairs(opts.extra or { "defend", "defend", "defend", "defend", "defend" }) do
    deck[#deck + 1] = { id = id, up = false }
  end
  if opts.epic then deck[#deck + 1] = { id = opts.epic, up = opts.up or false } end
  local c = Combat.new({ seed = opts.seed or 7, class = "warrior", hp = opts.hp or 60, maxHp = 60, deck = deck,
    encounter = opts.encounter or { "tw_dummy" }, relics = opts.relics })
  local all = {}
  for _, x in ipairs(c.hand) do all[#all + 1] = x end
  for _, x in ipairs(c.draw) do all[#all + 1] = x end
  c.hand, c.draw = {}, {}
  local byId = {}
  for _, x in ipairs(all) do
    if x.id ~= opts.epic then byId[x.id] = byId[x.id] or {}; table.insert(byId[x.id], x) end
  end
  for _, id in ipairs(hand) do c.hand[#c.hand + 1] = table.remove(byId[id]) end
  for _, list in pairs(byId) do for _, x in ipairs(list) do c.draw[#c.draw + 1] = x end end
  return c
end

local function idx(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
end
local function play(c, id, t, o)
  local i = idx(c, id)
  assert(i, id .. " en main")
  return Combat.play(c, i, t, o)
end

---------------------------------------------------------------------------
-- Commun
---------------------------------------------------------------------------
test("sept épiques : une par zone, rareté epic, sans coût ni niveau, débloquées par la zone", function()
  local zones = {}
  for _, id in ipairs(Warrior.EPICS) do
    local d = ns.Cards[id]
    eq(d.class, "warrior"); eq(d.rarity, "epic"); eq(d.epic, true); eq(d.type, "power")
    eq(d.cost, nil, id .. " : coût"); eq(d.level, nil, id .. " : niveau")
    assert(d.deckHooks and d.whileInDeck and d.up and d.up.deckHooks, id .. " : crochets")
    assert(d.text:find("^Epic%.\n") and d.up.text:find("^Epic%.\n"), id .. " : « Epic. » en tête")
    assert(not zones[d.zone], "une par zone"); zones[d.zone] = id
    eq(Meta.zoneCards("warrior", d.zone)[1], id)
  end
  for _, z in ipairs({ "westfall", "duskwood", "wetlands", "stranglethorn", "swamp", "steppes", "blackrock" }) do
    assert(zones[z], z)
  end
  eq(zones.westfall, "death_wish", "Death Wish reste la première épique (décisions)")
  for _, id in ipairs(Card.pool("warrior")) do assert(ns.Cards[id].rarity ~= "epic", "hors réserve : " .. id) end
end)

test("textes : les nombres de Warrior.EPIC", function()
  local function has(id, up, s) assert(Card.defById(id, up).text:find(s, 1, true), id .. (up and "+" or "") .. " : " .. s) end
  has("death_wish", false, "50% more"); has("death_wish", true, "heal " .. E.death_wish.heal)
  eq(E.death_wish.mult, 1.5)
  has("thunderous_roar", false, "At " .. E.thunderous_roar.at .. " Rage")
  has("thunderous_roar", false, "deal " .. E.thunderous_roar.damage)
  has("thunderous_roar", true, "deal " .. E.thunderous_roar.upDamage)
  has("thunderous_roar", false, "Demoralized " .. E.thunderous_roar.demoralized)
  has("sweeping_strikes", true, "hit " .. E.sweeping_strikes.upTargets .. " other")
  has("titans_grip", false, "At most " .. E.titans_grip.limit .. " Attacks")
  has("shield_charge", true, "deal " .. E.shield_charge.upBonus .. " + half")
  has("anger_management", false, "Each " .. E.anger_management.per .. " Rage spent")
  has("anger_management", true, "Each " .. E.anger_management.upPer .. " Rage spent")
  has("avatar", false, "up to " .. E.avatar.cap); has("avatar", false, "+" .. E.avatar.gain .. " Rage")
  has("avatar", true, "+" .. E.avatar.upGain .. " Rage")
end)

test("règle active dès le premier tour, combat sauvegardable et clonable, épique lue par Warrior.epicOf", function()
  for _, id in ipairs(Warrior.EPICS) do
    for _, up in ipairs({ false, true }) do
      local c = setup({ "strike", "defend" }, { epic = id, up = up })
      local got, gotUp = Warrior.epicOf(c)
      eq(got, id); eq(gotUp, up)
      assert(Save.isPlain(c), id .. " : sauvegardable")
      local cl = Combat.clone(c)
      eq(Warrior.epicOf(cl), id)
      for _, pile in ipairs({ c.hand, c.draw, c.discard }) do
        for _, inst in ipairs(pile) do assert(inst.id ~= id, "jamais piochée") end
      end
    end
  end
  eq(Warrior.epicOf(setup({ "strike" })), nil, "sans épique")
end)

---------------------------------------------------------------------------
-- Westfall — Death Wish
---------------------------------------------------------------------------
test("Death Wish : aucun Absorb (cartes, Shield Slam à 0, bibelots)", function()
  local c = setup({ "defend", "shield_slam", "ignore_pain" }, { epic = "death_wish", relics = { "skullflame_shield" } })
  c.player.res = 3
  assert(play(c, "defend"))
  eq(c.player.block, 0)
  local hp = c.enemies[1].hp
  assert(play(c, "shield_slam", 1))
  eq(c.player.block, 0); eq(c.enemies[1].hp, hp, "Shield Slam : 0 + 50 % = 0")
  assert(play(c, "ignore_pain"))
  eq(c.player.block, 0, "Ignore Pain")
  c.player.res = 4
  Combat.endTurn(c)
  eq(c.player.block, 0, "Skullflame Shield")
end)

test("Death Wish : Attacks +50 % après Strength, avant Sundered, arrondi à l'inférieur ; sans carte inchangé", function()
  local c = setup({ "strike", "strike", "strike" }, { epic = "death_wish" })
  local e = c.enemies[1]
  local hp = e.hp
  assert(play(c, "strike", 1))
  eq(e.hp, hp - 9)
  Combat.applyStatus(c, c.player, "force", 1)
  assert(play(c, "strike", 1))
  eq(e.hp, hp - 9 - 10, "(6 + 1) × 1,5 = 10")
  Combat.applyStatus(c, e, "armor_broken", 2)
  assert(play(c, "strike", 1))
  eq(e.hp, hp - 19 - 12, "10 × 1,25 = 12")
  eq(Combat.calcDamage(c, c.player, e, 4, nil), 6, "riposte : (4 + 1) × 1,25, sans bonus")
  eq(Combat.calcDamage(c, c.player, e, 4, ns.Cards.defend), 6, "carte non Attack : sans bonus")
end)

test("Death Wish amélioré : chaque ennemi tué soigne de 3 ; de base, rien", function()
  for _, up in ipairs({ false, true }) do
    local c = setup({ "strike", "strike" }, { epic = "death_wish", up = up, hp = 40,
      encounter = { "tw_dummy", "tw_dummy" } })
    c.enemies[1].hp = 5
    assert(play(c, "strike", 1))
    assert(c.enemies[1].dead)
    eq(c.player.hp, up and 40 + E.death_wish.heal or 40)
    -- dernier ennemi : soigné aussi (avant la victoire)
    c.enemies[2].hp = 3
    assert(play(c, "strike", 2))
    eq(c.result, "won")
    eq(c.player.hp, up and 40 + 2 * E.death_wish.heal or 40)
  end
end)

---------------------------------------------------------------------------
-- Duskwood — Thunderous Roar
---------------------------------------------------------------------------
test("Thunderous Roar : à 5 Rage (fin de l'Attack), Rage à 0, 6 à tous, Demoralized 1 à tous", function()
  local c = setup({ "strike" }, { epic = "thunderous_roar", encounter = { "tw_dummy", "tw_dummy" } })
  c.player.res = 4
  local a, b = c.enemies[1].hp, c.enemies[2].hp
  assert(play(c, "strike", 1))
  eq(c.player.res, 0)
  eq(c.enemies[1].hp, a - 6 - E.thunderous_roar.damage); eq(c.enemies[2].hp, b - E.thunderous_roar.damage)
  eq(c.enemies[1].st.demoralized, 1); eq(c.enemies[2].st.demoralized, 1)
  -- posé pendant le tour du joueur : couvre le tour ennemi, retiré à la fin du round
  Combat.endTurn(c)
  eq(c.enemies[1].st.demoralized, nil)
end)

test("Thunderous Roar : sous 5 rien ; Strength comprise ; amélioré 9 ; gain par paiement de PV", function()
  local c = setup({ "strike" }, { epic = "thunderous_roar" })
  c.player.res = 2
  local hp = c.enemies[1].hp
  assert(play(c, "strike", 1))
  eq(c.player.res, 3); eq(c.enemies[1].hp, hp - 6); eq(c.enemies[1].st.demoralized, nil)
  local c2 = setup({ "bloodrage" }, { epic = "thunderous_roar", up = true })
  Combat.applyStatus(c2, c2.player, "force", 2)
  c2.player.res = 2
  hp = c2.enemies[1].hp
  assert(play(c2, "bloodrage")) -- Pay 2 HP (+1 Rage) puis +2 Rage : 5
  eq(c2.player.res, 0)
  eq(c2.enemies[1].hp, hp - (E.thunderous_roar.upDamage + 2))
end)

test("Thunderous Roar : coup reçu pendant le tour ennemi, Demoralized seulement jusqu'à la fin du round", function()
  local c = setup({ "defend" }, { epic = "thunderous_roar", encounter = { "tw_double" } })
  c.player.res = 4
  local hp = c.enemies[1].hp
  Combat.endPlayerTurn(c)
  Combat.enemyPhase(c)
  -- premier coup (3) : +1 Rage, onde ; le second coup est allégé (3 × 0,75 = 2)
  eq(c.enemies[1].hp, hp - E.thunderous_roar.damage)
  eq(c.player.hp, 60 - 3 - 2)
  eq(c.enemies[1].st.demoralized, 1)
  Combat.endRound(c)
  eq(c.enemies[1].st.demoralized, nil, "retiré à la fin du round")
end)

test("Thunderous Roar : Execute ne compte jamais plus de 4 Rage ; Battle Standard amorce", function()
  local c = setup({ "execute" }, { epic = "thunderous_roar" })
  c.player.res = 4
  c.enemies[1].hp = 40
  assert(play(c, "execute", 1))
  eq(c.enemies[1].hp, 40 - (5 + 4 * 4))
  eq(c.player.res, 1, "Surge 4 puis +1 Rage")
  local c2 = setup({ "strike" }, { epic = "thunderous_roar", relics = { "battle_standard" } })
  eq(c2.player.res, 1)
end)

---------------------------------------------------------------------------
-- Wetlands — Sweeping Strikes
---------------------------------------------------------------------------
test("Sweeping Strikes : un coup à cible rebondit pour la moitié des PV perdus, sans Rage", function()
  local c = setup({ "strike", "raging_blow" }, { epic = "sweeping_strikes", encounter = { "tw_dummy", "tw_dummy" } })
  local b = c.enemies[2].hp
  assert(play(c, "strike", 1))
  eq(c.enemies[2].hp, b - 3)
  eq(c.player.res, 1, "le rebond ne donne pas de Rage")
  c.enemies[1].block = 4
  assert(play(c, "raging_blow", 1))
  -- premier coup : 5 - 4 absorbés = 1 PV perdu (rien), second : 5 (2)
  eq(c.enemies[2].hp, b - 3 - 2, "moitié des PV réellement perdus, un rebond par coup")
end)

test("Sweeping Strikes : seul en face rien ; sans cible rien ; le rebond ne pose pas Deep Wounds", function()
  local c = setup({ "strike" }, { epic = "sweeping_strikes" })
  local hp = c.enemies[1].hp
  assert(play(c, "strike", 1))
  eq(c.enemies[1].hp, hp - 6)
  local c2 = setup({ "whirlwind" }, { epic = "sweeping_strikes", encounter = { "tw_dummy", "tw_dummy" } })
  local a, b = c2.enemies[1].hp, c2.enemies[2].hp
  assert(play(c2, "whirlwind"))
  eq(c2.enemies[1].hp, a - 8); eq(c2.enemies[2].hp, b - 8)
  local c3 = setup({ "deep_wounds", "strike" }, { epic = "sweeping_strikes", encounter = { "tw_dummy", "tw_dummy" } })
  assert(play(c3, "deep_wounds"))
  assert(play(c3, "strike", 1))
  eq(c3.enemies[1].st.pain, 1); eq(c3.enemies[2].st.pain, nil)
end)

test("Sweeping Strikes amélioré : deux autres ennemis, sans remise ; coup qui tue compris", function()
  local c = setup({ "strike", "strike" }, { epic = "sweeping_strikes", up = true,
    encounter = { "tw_dummy", "tw_dummy", "tw_dummy" } })
  local b, d = c.enemies[2].hp, c.enemies[3].hp
  assert(play(c, "strike", 1))
  eq(c.enemies[2].hp, b - 3); eq(c.enemies[3].hp, d - 3)
  c.enemies[1].hp = 2
  assert(play(c, "strike", 1))
  assert(c.enemies[1].dead)
  eq(c.enemies[2].hp, b - 6, "PV perdus du coup qui tue : 6")
  local c2 = setup({ "strike" }, { epic = "sweeping_strikes", up = false, encounter = { "tw_dummy", "tw_dummy", "tw_dummy" } })
  local h2, h3 = c2.enemies[2].hp, c2.enemies[3].hp
  assert(play(c2, "strike", 1))
  eq((h2 - c2.enemies[2].hp) + (h3 - c2.enemies[3].hp), 3, "de base : un seul autre")
end)

---------------------------------------------------------------------------
-- Stranglethorn Vale — Titan's Grip
---------------------------------------------------------------------------
test("Titan's Grip : chaque Attack deux fois, Rage +1 une fois par carte", function()
  local c = setup({ "strike" }, { epic = "titans_grip" })
  local hp = c.enemies[1].hp
  assert(play(c, "strike", 1))
  eq(c.enemies[1].hp, hp - 12); eq(c.player.res, 1)
  eq(#c.discard, 1, "la carte ne part qu'une fois")
end)

test("Titan's Grip : au plus deux Attacks par tour (raison), Skills libres, compte remis au tour suivant", function()
  local c = setup({ "strike", "strike", "strike", "defend" }, { epic = "titans_grip" })
  c.player.mana = 9
  assert(play(c, "strike", 1)); assert(play(c, "strike", 1))
  local ok, why = Combat.canPlay(c, idx(c, "strike"))
  assert(not ok); eq(why, Warrior.TITAN_REASON)
  assert(play(c, "defend"))
  local found = false
  for _, p in ipairs(Combat.legalPlays(c)) do if c.hand[p[1]].id == "strike" then found = true end end
  assert(not found, "hors des coups légaux")
  Combat.endTurn(c)
  eq(c.cls.tgAttacks, 0)
end)

test("Titan's Grip : Spend payé une fois, bonus aux deux ; Surge : même montant, rien de plus dépensé", function()
  local c = setup({ "heroic_strike", "execute" }, { epic = "titans_grip" })
  c.player.res = 3
  local hp = c.enemies[1].hp
  assert(play(c, "heroic_strike", 1))
  eq(c.enemies[1].hp, hp - 2 * 12); eq(c.player.res, 2, "3 - 2 + 1")
  c.enemies[1].hp = 40
  c.player.res = 3
  assert(play(c, "execute", 1))
  eq(c.enemies[1].hp, 40 - 2 * (5 + 4 * 3)); eq(c.player.res, 1, "Surge 3 une fois, +1 Rage")
end)

test("Titan's Grip : cible morte, la copie va au premier ennemi vivant ; Cast résolu deux fois", function()
  local c = setup({ "strike", "slam" }, { epic = "titans_grip", encounter = { "tw_dummy", "tw_dummy" } })
  c.enemies[2].hp = 4
  local a = c.enemies[1].hp
  assert(play(c, "strike", 2))
  assert(c.enemies[2].dead); eq(c.enemies[1].hp, a - 6)
  assert(play(c, "slam", 1))
  eq(c.enemies[1].hp, a - 6, "incantée")
  Combat.endTurn(c)
  eq(c.enemies[1].hp, a - 6 - 32)
end)

test("Titan's Grip amélioré : les Attacks à 0 ne comptent pas ; de base, si", function()
  for _, up in ipairs({ false, true }) do
    local c = setup({ "overpower", "strike", "strike" }, { epic = "titans_grip", up = up })
    assert(play(c, "overpower", 1)); assert(play(c, "strike", 1))
    eq(Combat.canPlay(c, idx(c, "strike")), up, up and "amélioré" or "de base")
  end
end)

---------------------------------------------------------------------------
-- Swamp of Sorrows — Shield Charge
---------------------------------------------------------------------------
test("Shield Charge : fin du tour, moitié de l'Absorb sur la dernière cible, Absorb gardée pour le tour ennemi", function()
  local c = setup({ "strike", "defend", "defend" }, { epic = "shield_charge", encounter = { "tw_hitter", "tw_dummy" } })
  assert(play(c, "strike", 2)); assert(play(c, "defend")); assert(play(c, "defend"))
  eq(c.player.block, 10)
  local a, b = c.enemies[1].hp, c.enemies[2].hp
  local res = c.player.res
  Combat.endPlayerTurn(c)
  eq(c.enemies[2].hp, b - 5); eq(c.enemies[1].hp, a)
  eq(c.player.block, 10); eq(c.player.res, res, "pas de Rage")
  Combat.enemyPhase(c)
  eq(c.player.hp, 60, "le coup de 10 absorbé")
end)

test("Shield Charge : cible morte -> le plus à gauche ; sans Absorb rien ; amélioré 4 + moitié ; dormeur évité", function()
  local c = setup({ "strike", "defend" }, { epic = "shield_charge", encounter = { "tw_dummy", "tw_dummy", "tw_dummy" } })
  c.enemies[3].hp = 3
  assert(play(c, "strike", 3)); assert(c.enemies[3].dead)
  assert(play(c, "defend"))
  local a = c.enemies[1].hp
  Combat.endPlayerTurn(c)
  eq(c.enemies[1].hp, a - 2)
  local c2 = setup({ "strike" }, { epic = "shield_charge", up = true })
  assert(play(c2, "strike", 1))
  local h = c2.enemies[1].hp
  Combat.endPlayerTurn(c2)
  eq(c2.enemies[1].hp, h, "sans Absorb : rien, même amélioré")
  local c3 = setup({ "strike", "defend" }, { epic = "shield_charge", up = true, encounter = { "tw_dummy", "tw_dummy" } })
  assert(play(c3, "strike", 1)); assert(play(c3, "defend"))
  c3.enemies[1].st.asleep = 2 -- dormeur (Swamp) : évité tant qu'un ennemi est éveillé
  local b3 = c3.enemies[2].hp
  Combat.endPlayerTurn(c3)
  eq(c3.enemies[2].hp, b3 - (E.shield_charge.upBonus + 2))
  eq(Warrior.chargeDamage(c3, true), E.shield_charge.upBonus + 2)
end)

---------------------------------------------------------------------------
-- Burning Steppes — Anger Management
---------------------------------------------------------------------------
test("Anger Management : chaque 3 Rage dépensées, les recharges avancent ; à 0, retour en main aussitôt", function()
  local c = setup({ "berserker_rage", "ignore_pain", "heroic_strike", "execute" }, { epic = "anger_management" })
  c.player.mana = 9
  assert(play(c, "berserker_rage")) -- +2 Rage, recharge 2
  eq(#c.cooldown, 1); eq(c.cooldown[1].turns, 2)
  c.player.res = 3
  assert(play(c, "ignore_pain")) -- Surge 3
  eq(c.cooldown[1].turns, 1); eq(c.cls.amSpent, 0)
  c.player.res = 2
  assert(play(c, "heroic_strike", 1)) -- Spend 2 : reste 2
  eq(c.cooldown[1].turns, 1); eq(c.cls.amSpent, 2)
  c.player.res = 1
  c.enemies[1].hp = 40
  assert(play(c, "execute", 1)) -- Surge 1 : 3 -> recharge à 0, retour en main
  eq(#c.cooldown, 0); assert(idx(c, "berserker_rage"), "revenue en main"); eq(c.cls.amSpent, 0)
end)

test("Anger Management : reste gardé d'un tour à l'autre ; main pleine, retour au début du tour suivant", function()
  local c = setup({ "berserker_rage", "heroic_strike" }, { epic = "anger_management" })
  assert(play(c, "berserker_rage"))
  c.player.res = 2
  assert(play(c, "heroic_strike", 1))
  eq(c.cls.amSpent, 2)
  Combat.endTurn(c)
  eq(c.cls.amSpent, 2, "gardé")
  c.cooldown[1].turns = 1
  while #c.hand < Combat.HAND_MAX do c.hand[#c.hand + 1] = Card.new("strike", false, 800 + #c.hand) end
  Warrior.cooldownTick(c)
  eq(#c.cooldown, 1); eq(c.cooldown[1].turns, 0, "main pleine : gardée à 0")
  table.remove(c.hand)
  Combat.endTurn(c)
  assert(idx(c, "berserker_rage"), "revenue au début du tour suivant")
end)

test("Anger Management amélioré : chaque 2 Rage dépensées", function()
  local c = setup({ "shield_wall", "heroic_strike" }, { epic = "anger_management", up = true })
  c.player.mana = 9
  assert(play(c, "shield_wall"))
  eq(c.cooldown[1].turns, 3)
  c.player.res = 2
  assert(play(c, "heroic_strike", 1))
  eq(c.cooldown[1].turns, 2)
end)

---------------------------------------------------------------------------
-- Blackrock Mountain — Avatar
---------------------------------------------------------------------------
test("Avatar : Rage jusqu'à 10, +1 au début du tour (amélioré +2), cartes « per Rage » sur la Rage réelle", function()
  local c = setup({ "execute", "ignore_pain" }, { epic = "avatar" })
  eq(Combat.resCap(c), E.avatar.cap)
  eq(c.player.res, E.avatar.gain, "+1 dès le premier tour")
  Combat.gainRes(c, 20)
  eq(c.player.res, 10)
  c.enemies[1].hp = 50
  assert(play(c, "execute", 1))
  eq(c.enemies[1].hp, 50 - 45, "Execute 5 + 4 × 10")
  c.player.res = 10
  assert(play(c, "ignore_pain"))
  eq(c.player.block, 30)
  local c2 = setup({ "strike" }, { epic = "avatar", up = true })
  eq(c2.player.res, E.avatar.upGain)
  Combat.endTurn(c2)
  eq(c2.player.res, 2 * E.avatar.upGain)
  eq(Combat.resCap(setup({ "strike" })), 5, "sans épique : 5")
end)

---------------------------------------------------------------------------
-- Bots
---------------------------------------------------------------------------
test("bot : conseils du deck selon l'épique, note d'épique attachée à celle du deck", function()
  local bot = ns.Classes.warrior.bot
  local exp = X.new({ seed = 3, class = "warrior", unlocks = Meta.allUnlocked(7, 7) })
  eq(bot.deck(exp), nil, "sans épique")
  X.addCard(exp, "death_wish")
  local adv = bot.deck(exp)
  assert(adv and adv.rating.shield_block < 5 and adv.remove.defend < 1 and adv.remove.death_wish == 99)
  assert(bot.epic(exp, "death_wish") > bot.epic(exp, "avatar") + 0.5, "garde l'épique du deck")
  for _, id in ipairs(Warrior.EPICS) do
    assert(bot.advice[id] and bot.advice[id].rating and bot.advice[id].upgrade[id], id)
  end
  local rec, e2 = ns.SimExpedition.play({ seed = 2, class = "warrior", epic = "titans_grip", zones = 7 })
  eq(e2.deck[X.epicIndex(e2)].id, "titans_grip", "le bot garde l'épique imposée")
  for _, cd in ipairs(e2.deck) do
    if cd.id == "strike" and rec.removed and rec.removed > 0 then error("Strike gardé malgré des retraits") end
  end
end)

for _, id in ipairs({ "tw_dummy", "tw_hitter", "tw_double" }) do ns.Enemies[id] = nil end

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
