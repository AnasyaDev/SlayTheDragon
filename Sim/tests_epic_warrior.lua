-- Tests des sept cartes épiques du Guerrier (docs/zones/cartes-de-zone.md, « Warrior ») : cas nominaux et
-- cas limites de la fiche. L'épique est posée dans le deck du combat ; les tests ne dépendent pas de la pile
-- où elle se trouve (sa règle est active dès le début du combat).
-- Usage : lua5.1 Sim/tests_epic_warrior.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Save, Combat, Card = ns.Expedition, ns.Meta, ns.Save, ns.Combat, ns.Card
local Warrior = ns.Warrior
local E = Warrior.EPIC
local function N(id, key, up) return Warrior.num(id, key, up or false) end -- nombre au palier (up : 0..3, true = 1)

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
test("sept épiques : une par zone, rareté epic, coût 0, sans niveau, débloquées par la zone", function()
  local zones = {}
  for _, id in ipairs(Warrior.EPICS) do
    local d = ns.Cards[id]
    eq(d.class, "warrior"); eq(d.rarity, "epic"); eq(d.epic, true); eq(d.type, "power")
    eq(d.cost, 0, id .. " : coût (jamais payé)"); eq(d.level, nil, id .. " : niveau")
    assert(d.deckHooks and d.up and d.up.deckHooks, id .. " : crochets")
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

test("textes : les nombres de Warrior.EPIC (carte et à-côté de ses mots de règle)", function()
  local Lg = ns.Language
  local function has(id, up, s)
    local d = Card.defById(id, up)
    local out = { d.text }
    for _, r in ipairs(Lg.ruleWords(d)) do out[#out + 1] = r.kw.name .. ": " .. Lg.ruleText(r.kw, r.n, up) end
    local t = table.concat(out, "\n")
    assert(t:find(s, 1, true), id .. (up and ("+" .. tostring(up)) or "") .. " : « " .. s .. " » absent de « " .. t .. " »")
  end
  local function hasNot(id, up, s)
    local d = Card.defById(id, up)
    local out = { d.text }
    for _, r in ipairs(Lg.ruleWords(d)) do out[#out + 1] = Lg.ruleText(r.kw, r.n, up) end
    assert(not table.concat(out, "\n"):find(s, 1, true), id .. (up and ("+" .. tostring(up)) or "") .. " : « " .. s .. " » en trop")
  end
  -- quatre paliers (0 = false, 1, 2, 3) : nombres de la carte et de l'à-côté lus dans Warrior.EPIC au palier
  local UPS = { false, 1, 2, 3 }
  local function lab(up) return up and ("+" .. up) or "" end
  local function kills(id, up, word)
    local d = Card.defById(id, up)
    return d.text:match(word == "heal" and "\nKills: heal (%d+)%.$" or "\nKills: %+(%d+) Rage%.$")
  end
  for _, up in ipairs(UPS) do
    local pct = math.floor((N("death_wish", "mult", up) - 1) * 100 + 0.5)
    has("death_wish", up, "Carnage " .. pct .. "%."); has("death_wish", up, "Attacks deal " .. pct .. "% more damage. Absorb can't be gained.")
    local h = N("death_wish", "heal", up)
    if h > 0 then has("death_wish", up, "Kills: heal " .. h .. ".") else hasNot("death_wish", up, "Kills") end
    local T = E.thunderous_roar
    local dmg, demo = N("thunderous_roar", "damage", up), N("thunderous_roar", "demoralized", up)
    has("thunderous_roar", up, "At " .. T.at .. " Rage: Shockwave " .. dmg .. ".")
    has("thunderous_roar", up, "Spend all Rage")
    has("thunderous_roar", up, "deal " .. dmg .. " to all enemies")
    if demo > 0 then has("thunderous_roar", up, "apply Demoralized " .. demo .. " ⌛ to all")
    else hasNot("thunderous_roar", up, "Demoralized") end
    local tg = N("sweeping_strikes", "targets", up)
    has("sweeping_strikes", up, (N("sweeping_strikes", "anyAttack", up) and "\nAttacks: Sweep " or "Targeted Attack hits: Sweep ") .. tg .. ".")
    has("sweeping_strikes", up, tg == 1 and "Also hit another random enemy" or ("Also hit " .. tg .. " other random enemies"))
    has("sweeping_strikes", up, "for a third of the HP")
    eq(tonumber(kills("sweeping_strikes", up, "%+") or 0), N("sweeping_strikes", "killRage", up), "Sweeping Strikes" .. lab(up))
    has("titans_grip", up, "Dual Wield " .. E.titans_grip.limit)
    has("titans_grip", up, "Attacks cost " .. E.titans_grip.extraCost .. " more and resolve twice, at most "
      .. E.titans_grip.limit .. " per turn.")
    eq(tonumber(kills("titans_grip", up, "heal") or 0), N("titans_grip", "killHeal", up), "Titan's Grip" .. lab(up))
    local bonus = N("shield_charge", "bonus", up)
    if bonus > 0 then
      has("shield_charge", up, "Punish +" .. bonus .. ".")
      has("shield_charge", up, "deal a quarter of it +" .. bonus .. " to the last target")
    else
      has("shield_charge", up, "End of turn: Punish."); has("shield_charge", up, "deal a quarter of it to the last target")
    end
    local st = N("anger_management", "steps", up)
    has("anger_management", up, "Each Rage spent: Haste " .. st .. ".")
    has("anger_management", up, "return " .. st .. " turn" .. (st > 1 and "s" or "") .. " sooner")
    has("anger_management", up, "Spend and Surge cards go on Cooldown " .. E.anger_management.give .. ", not to the discard")
    local g = N("avatar", "gain", up)
    has("avatar", up, "Start of turn: Juggernaut " .. g .. ".")
    has("avatar", up, "Gain " .. g .. " Rage. Rage goes up to " .. E.avatar.cap .. ",")
    has("avatar", up, "at " .. E.avatar.cap .. " Rage Attacks deal " .. E.avatar.bonus .. " more.")
  end
  eq(N("death_wish", "mult"), 1.5)
  eq(E.sweeping_strikes.div, 3)
  eq(E.titans_grip.copies, 1, "« resolve twice »")
  has("titans_grip", 1, "Dual Wield " .. E.titans_grip.limit .. ", 0-cost free.")
  for _, up in ipairs({ 1, 2, 3 }) do has("titans_grip", up, "0-cost ones skip the cost and limit.") end
  eq(Warrior.TITAN_REASON, ("Only %d Attack%s per turn."):format(E.titans_grip.limit, E.titans_grip.limit > 1 and "s" or ""))
  eq(E.shield_charge.div, 4)
  eq(E.anger_management.per, 1)
  eq(E.avatar.over, E.avatar.cap - 1, "« At 10 Rage »")
  -- l'à-côté n'a qu'un texte amélioré : les nombres qu'il écrit en clair sont ceux de tous les paliers 1 à 3
  for lv = 2, 4 do
    eq(E.thunderous_roar.demoralized[lv], E.thunderous_roar.demoralized[2], "Demoralized du palier " .. (lv - 1))
    eq(E.sweeping_strikes.targets[lv], E.sweeping_strikes.targets[2], "Sweep du palier " .. (lv - 1))
  end
end)

test("règle active dès le premier tour, combat sauvegardable et clonable, épique lue par Warrior.epicOf", function()
  for _, id in ipairs(Warrior.EPICS) do
    for _, up in ipairs({ false, true }) do
      local c = setup({ "strike", "defend" }, { epic = id, up = up })
      local got, gotUp = Warrior.epicOf(c)
      eq(got, id); eq(gotUp, ns.Card.upValue(up))
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
    eq(c.player.hp, up and 40 + N("death_wish", "heal", true) or 40)
    -- dernier ennemi : soigné aussi (avant la victoire)
    c.enemies[2].hp = 3
    assert(play(c, "strike", 2))
    eq(c.result, "won")
    eq(c.player.hp, up and 40 + 2 * N("death_wish", "heal", true) or 40)
  end
end)

---------------------------------------------------------------------------
-- Duskwood — Thunderous Roar
---------------------------------------------------------------------------
test("Thunderous Roar : à 5 Rage (fin de l'Attack), Rage à 0, dégâts à tous, Demoralized selon la règle", function()
  local n = N("thunderous_roar", "damage")
  local c = setup({ "strike" }, { epic = "thunderous_roar", encounter = { "tw_dummy", "tw_dummy" } })
  c.player.res = 4
  local a, b = c.enemies[1].hp, c.enemies[2].hp
  assert(play(c, "strike", 1))
  eq(c.player.res, 0)
  eq(c.enemies[1].hp, a - 6 - n); eq(c.enemies[2].hp, b - n)
  local demo = N("thunderous_roar", "demoralized") > 0 and N("thunderous_roar", "demoralized") or nil
  eq(c.enemies[1].st.demoralized, demo); eq(c.enemies[2].st.demoralized, demo)
  Combat.endTurn(c)
  eq(c.enemies[1].st.demoralized, nil, "jamais au-delà du round")
end)

test("Thunderous Roar : sous 5 rien ; Strength comprise ; amélioré ; gain par paiement de PV", function()
  local c = setup({ "strike" }, { epic = "thunderous_roar" })
  c.player.res = 2
  local hp = c.enemies[1].hp
  assert(play(c, "strike", 1))
  eq(c.player.res, 3); eq(c.enemies[1].hp, hp - 6)
  local c2 = setup({ "bloodrage" }, { epic = "thunderous_roar", up = true })
  Combat.applyStatus(c2, c2.player, "force", 2)
  c2.player.res = 2
  hp = c2.enemies[1].hp
  assert(play(c2, "bloodrage")) -- Pay 2 HP (+1 Rage) puis +2 Rage : 5
  eq(c2.player.res, 0)
  eq(c2.enemies[1].hp, hp - (N("thunderous_roar", "damage", true) + 2))
end)

test("Thunderous Roar : coup reçu pendant le tour ennemi ; Demoralized (si posé) seulement jusqu'à la fin du round", function()
  local old = E.thunderous_roar.demoralized
  for _, demo in ipairs({ 0, 1 }) do
    E.thunderous_roar.demoralized = { demo, demo, demo, demo }
    local c = setup({ "defend" }, { epic = "thunderous_roar", encounter = { "tw_double" } })
    c.player.res = 4
    local hp = c.enemies[1].hp
    Combat.endPlayerTurn(c)
    Combat.enemyPhase(c)
    -- premier coup (3) : +1 Rage, onde ; le second coup est allégé par Demoralized (3 × 0,75 = 2)
    eq(c.enemies[1].hp, hp - N("thunderous_roar", "damage"))
    eq(c.player.hp, 60 - 3 - (demo > 0 and 2 or 3))
    eq(c.enemies[1].st.demoralized, demo > 0 and 1 or nil)
    Combat.endRound(c)
    eq(c.enemies[1].st.demoralized, nil, "retiré à la fin du round")
  end
  E.thunderous_roar.demoralized = old
end)

test("Thunderous Roar amélioré : onde de upDamage puis Demoralized upDemoralized ⌛ ; de base, rien", function()
  for _, up in ipairs({ false, true }) do
    local c = setup({ "strike" }, { epic = "thunderous_roar", up = up, encounter = { "tw_dummy", "tw_dummy" } })
    c.player.res = 4
    local b = c.enemies[2].hp
    assert(play(c, "strike", 1))
    eq(c.enemies[2].hp, b - (up and N("thunderous_roar", "damage", true) or N("thunderous_roar", "damage")))
    local demo = N("thunderous_roar", "demoralized", up)
    eq(c.enemies[2].st.demoralized, demo > 0 and demo or nil, up and "amélioré" or "de base")
  end
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
local function third(n) return math.floor(n / E.sweeping_strikes.div) end

test("Sweeping Strikes : un coup à cible rebondit pour le tiers des PV perdus (arrondi à l'inférieur), sans Rage", function()
  eq(E.sweeping_strikes.div, 3, "« for a third »")
  local c = setup({ "strike", "raging_blow" }, { epic = "sweeping_strikes", encounter = { "tw_dummy", "tw_dummy" } })
  local b = c.enemies[2].hp
  assert(play(c, "strike", 1))
  eq(c.enemies[2].hp, b - third(6))
  eq(c.player.res, 1, "le rebond ne donne pas de Rage")
  c.enemies[1].block = 4
  assert(play(c, "raging_blow", 1))
  -- premier coup : 5 - 4 absorbés = 1 PV perdu (rien), second : 5
  eq(c.enemies[2].hp, b - third(6) - third(1) - third(5), "tiers des PV réellement perdus, un rebond par coup")
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
  eq(c.enemies[2].hp, b - third(6)); eq(c.enemies[3].hp, d - third(6))
  c.enemies[1].hp = 2
  assert(play(c, "strike", 1))
  assert(c.enemies[1].dead)
  eq(c.enemies[2].hp, b - 2 * third(6), "PV perdus du coup qui tue : 6")
  local c2 = setup({ "strike" }, { epic = "sweeping_strikes", up = false, encounter = { "tw_dummy", "tw_dummy", "tw_dummy" } })
  local h2, h3 = c2.enemies[2].hp, c2.enemies[3].hp
  assert(play(c2, "strike", 1))
  eq((h2 - c2.enemies[2].hp) + (h3 - c2.enemies[3].hp), third(6), "de base : un seul autre")
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

test("Titan's Grip : chaque Attack coûte 1 de plus (0 -> 1, Revenge touché -> 1), Skills inchangés ; amélioré : pas les 0", function()
  local x = E.titans_grip.extraCost
  for _, up in ipairs({ false, true }) do
    local c = setup({ "strike", "overpower", "revenge", "defend" }, { epic = "titans_grip", up = up })
    local function cost(id) return Combat.cost(c, c.hand[idx(c, id)]) end
    eq(cost("strike"), 1 + x); eq(cost("defend"), 1)
    eq(cost("overpower"), up and 0 or x, up and "amélioré : 0 exempté" or "de base")
    c.cls.hurtLast = true
    eq(cost("revenge"), up and 0 or x, "Revenge touché")
  end
  eq(Combat.cost(setup({ "strike" }), setup({ "strike" }).hand[1]), 1, "sans épique")
end)

test("Titan's Grip : au plus deux Attacks par tour (raison), Skills libres, compte remis au tour suivant", function()
  local lim = E.titans_grip.limit
  local hand = { "defend" }
  for _ = 1, lim + 1 do hand[#hand + 1] = "strike" end
  local c = setup(hand, { epic = "titans_grip" })
  c.player.mana = 9
  for _ = 1, lim do assert(play(c, "strike", 1)) end
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
  local c = setup({ "heroic_strike" }, { epic = "titans_grip" })
  c.player.res = 3
  local hp = c.enemies[1].hp
  assert(play(c, "heroic_strike", 1))
  eq(c.enemies[1].hp, hp - 2 * 12); eq(c.player.res, 2, "3 - 2 + 1")
  local c2 = setup({ "execute" }, { epic = "titans_grip" })
  c2.enemies[1].hp = 40
  c2.player.res = 3
  assert(play(c2, "execute", 1))
  eq(c2.enemies[1].hp, 40 - 2 * (5 + 4 * 3)); eq(c2.player.res, 1, "Surge 3 une fois, +1 Rage")
end)

test("Titan's Grip : cible morte, la copie va au premier ennemi vivant ; Cast résolu deux fois", function()
  local c = setup({ "strike" }, { epic = "titans_grip", encounter = { "tw_dummy", "tw_dummy" } })
  c.enemies[2].hp = 4
  local a = c.enemies[1].hp
  assert(play(c, "strike", 2))
  assert(c.enemies[2].dead); eq(c.enemies[1].hp, a - 6)
  local c2 = setup({ "slam" }, { epic = "titans_grip" })
  local b = c2.enemies[1].hp
  assert(play(c2, "slam", 1))
  eq(c2.enemies[1].hp, b, "incantée")
  Combat.endTurn(c2)
  eq(c2.enemies[1].hp, b - 32)
end)

test("Titan's Grip amélioré : les Attacks à 0 ne comptent pas ; de base, si", function()
  for _, up in ipairs({ false, true }) do
    local hand = { "overpower" }
    for _ = 1, E.titans_grip.limit + 1 do hand[#hand + 1] = "strike" end
    local c = setup(hand, { epic = "titans_grip", up = up })
    c.player.mana = 9
    assert(play(c, "overpower", 1))
    for _ = 1, E.titans_grip.limit - 1 do assert(play(c, "strike", 1)) end
    eq(Combat.canPlay(c, idx(c, "strike")), up, up and "amélioré" or "de base")
  end
end)

---------------------------------------------------------------------------
-- Swamp of Sorrows — Shield Charge
---------------------------------------------------------------------------
test("Shield Charge : fin du tour, quart de l'Absorb sur la dernière cible, Absorb gardée pour le tour ennemi", function()
  local c = setup({ "strike", "defend", "defend" }, { epic = "shield_charge", encounter = { "tw_hitter", "tw_dummy" } })
  assert(play(c, "strike", 2)); assert(play(c, "defend")); assert(play(c, "defend"))
  eq(c.player.block, 10)
  local a, b = c.enemies[1].hp, c.enemies[2].hp
  local res = c.player.res
  Combat.endPlayerTurn(c)
  eq(c.enemies[2].hp, b - math.floor(10 / E.shield_charge.div)); eq(c.enemies[1].hp, a)
  eq(c.player.block, 10); eq(c.player.res, res, "pas de Rage")
  Combat.enemyPhase(c)
  eq(c.player.hp, 60, "le coup de 10 absorbé")
end)

test("Shield Charge : cible morte -> le plus à gauche ; sans Absorb rien ; amélioré 4 + quart ; dormeur évité", function()
  local c = setup({ "strike", "defend" }, { epic = "shield_charge", encounter = { "tw_dummy", "tw_dummy", "tw_dummy" } })
  c.enemies[3].hp = 3
  assert(play(c, "strike", 3)); assert(c.enemies[3].dead)
  assert(play(c, "defend"))
  local a = c.enemies[1].hp
  Combat.endPlayerTurn(c)
  eq(c.enemies[1].hp, a - math.floor(5 / E.shield_charge.div))
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
  local want = N("shield_charge", "bonus", true) + math.floor(5 / E.shield_charge.div)
  eq(c3.enemies[2].hp, b3 - want)
  eq(Warrior.chargeDamage(c3, true), want)
end)

---------------------------------------------------------------------------
-- Burning Steppes — Anger Management
---------------------------------------------------------------------------
test("Anger Management : chaque Rage dépensée, les recharges avancent ; à 0, retour en main aussitôt", function()
  local c = setup({ "berserker_rage", "heroic_strike", "shield_wall" }, { epic = "anger_management" })
  c.player.mana = 9
  assert(play(c, "berserker_rage")) -- +2 Rage, recharge 2
  assert(play(c, "shield_wall")) -- recharge 3
  eq(#c.cooldown, 2); eq(c.cooldown[1].turns, 2); eq(c.cooldown[2].turns, 3)
  c.player.res = 2
  assert(play(c, "heroic_strike", 1)) -- Spend 2 : deux crans, puis Heroic Strike part en recharge
  eq(#c.cooldown, 2, "Berserker Rage : 2 -> 0, revenue ; Heroic Strike en recharge")
  assert(idx(c, "berserker_rage"), "revenue en main aussitôt")
  eq(c.cooldown[1].card.id, "shield_wall"); eq(c.cooldown[1].turns, 1)
  eq(c.cooldown[2].card.id, "heroic_strike"); eq(c.cooldown[2].turns, E.anger_management.give)
  eq(c.cls.amSpent, 0)
end)

test("Anger Management : Spend et Surge partent en recharge (dépensé ou non) et reviennent ; les autres à la défausse", function()
  local c = setup({ "heroic_strike", "strike", "execute" }, { epic = "anger_management" })
  c.player.mana = 9
  c.player.res = 1
  assert(play(c, "heroic_strike", 1, { spend = false })) -- sans dépense : en recharge quand même
  eq(#c.cooldown, 1); eq(c.cooldown[1].card.id, "heroic_strike"); eq(c.cooldown[1].turns, E.anger_management.give)
  assert(play(c, "strike", 1))
  eq(c.discard[#c.discard].id, "strike", "Strike à la défausse")
  c.enemies[1].hp = 40
  assert(play(c, "execute", 1)) -- Surge 3 : trois crans, Heroic Strike revient aussitôt ; Execute en recharge
  assert(idx(c, "heroic_strike"), "revenue par la dépense suivante")
  eq(#c.cooldown, 1); eq(c.cooldown[1].card.id, "execute")
  -- Cooldown 1 (règle commune) : un tour passé en recharge, de retour au début du tour d'après
  Combat.endTurn(c)
  assert(not idx(c, "execute")); eq(c.cooldown[1].turns, 0)
  Combat.endTurn(c)
  assert(idx(c, "execute"), "revenue")
  -- à blanc (give = 0) : à la défausse ; sans épique : à la défausse
  local old = E.anger_management.give
  E.anger_management.give = 0
  local c2 = setup({ "heroic_strike" }, { epic = "anger_management" })
  assert(play(c2, "heroic_strike", 1))
  eq(#c2.cooldown, 0); eq(c2.discard[#c2.discard].id, "heroic_strike")
  E.anger_management.give = old
  local c3 = setup({ "heroic_strike" })
  assert(play(c3, "heroic_strike", 1))
  eq(#c3.cooldown, 0)
end)

test("Anger Management : Surge compté ; reste gardé ; main pleine, retour au début du tour suivant", function()
  local old = E.anger_management.per
  local c = setup({ "berserker_rage", "ignore_pain" }, { epic = "anger_management" })
  assert(play(c, "berserker_rage"))
  c.player.res = 1
  assert(play(c, "ignore_pain")) -- Surge 1
  eq(c.cooldown[1].turns, 1)
  -- reste gardé d'un tour à l'autre (tranche de 3 essayée)
  E.anger_management.per = 3
  local c2 = setup({ "heroic_strike" }, { epic = "anger_management" })
  c2.player.res = 2
  assert(play(c2, "heroic_strike", 1))
  eq(c2.cls.amSpent, 2)
  Combat.endTurn(c2)
  eq(c2.cls.amSpent, 2, "gardé")
  E.anger_management.per = old
  -- main pleine : gardée à 0, revenue au début du tour suivant
  eq(c.cooldown[2].card.id, "ignore_pain", "Surge : en recharge")
  table.remove(c.cooldown, 2)
  c.cooldown[1].turns = 1
  while #c.hand < Combat.HAND_MAX do c.hand[#c.hand + 1] = Card.new("strike", false, 800 + #c.hand) end
  Warrior.cooldownTick(c)
  eq(#c.cooldown, 1); eq(c.cooldown[1].turns, 0, "main pleine : gardée à 0")
  table.remove(c.hand)
  Combat.endTurn(c)
  assert(idx(c, "berserker_rage"), "revenue au début du tour suivant")
end)

test("Anger Management amélioré : deux crans par Rage dépensée", function()
  local c = setup({ "shield_wall", "heroic_strike" }, { epic = "anger_management", up = true })
  c.player.mana = 9
  assert(play(c, "shield_wall"))
  eq(c.cooldown[1].turns, 3)
  c.player.res = 1
  assert(play(c, "heroic_strike", 1, { spend = false }))
  eq(c.cooldown[1].turns, 3, "sans dépense : rien")
  c.hand[#c.hand + 1] = Card.new("execute", false, 801)
  c.enemies[1].hp = 40
  assert(play(c, "execute", 1)) -- Surge 2 (1 + 1 de l'Attack) : 4 crans
  eq(#c.cooldown, 1, "Shield Wall et Heroic Strike revenus, Execute en recharge"); assert(idx(c, "shield_wall"))
  assert(idx(c, "heroic_strike")); eq(c.cooldown[1].card.id, "execute")
end)

---------------------------------------------------------------------------
-- Blackrock Mountain — Avatar
---------------------------------------------------------------------------
test("Avatar : Rage jusqu'à 10, +1 au début du tour (amélioré +2), cartes « per Rage » sur la Rage réelle", function()
  local c = setup({ "execute", "ignore_pain" }, { epic = "avatar" })
  eq(Combat.resCap(c), E.avatar.cap)
  eq(c.player.res, N("avatar", "gain"), "+1 dès le premier tour")
  Combat.gainRes(c, 20)
  eq(c.player.res, 10)
  c.enemies[1].hp = 50
  assert(play(c, "execute", 1))
  eq(c.enemies[1].hp, 50 - 45, "Execute 5 + 4 × 10")
  c.player.res = 10
  assert(play(c, "ignore_pain"))
  eq(c.player.block, 30)
  local c2 = setup({ "strike" }, { epic = "avatar", up = true })
  eq(c2.player.res, N("avatar", "gain", true))
  Combat.endTurn(c2)
  eq(c2.player.res, 2 * N("avatar", "gain", true))
  eq(Combat.resCap(setup({ "strike" })), 5, "sans épique : 5")
end)

test("Avatar : à 10 Rage, chaque coup d'une Attack +1 (Rampage : quatre fois) ; sous 10, Skills, Execute après Surge : rien", function()
  local b = E.avatar.bonus
  local c = setup({ "strike", "strike", "rampage", "shield_slam" }, { epic = "avatar" })
  c.player.mana = 9
  local e = c.enemies[1]
  c.player.res = E.avatar.cap - 1
  local hp = e.hp
  assert(play(c, "strike", 1)) -- 9 Rage au coup : rien (puis +1 : 10)
  eq(e.hp, hp - 6); eq(c.player.res, E.avatar.cap)
  assert(play(c, "strike", 1))
  eq(e.hp, hp - 6 - (6 + b), "à 10 Rage")
  hp = e.hp
  assert(play(c, "rampage", 1))
  eq(e.hp, hp - 4 * (4 + b), "chaque coup")
  eq(Warrior.avatarBonus(c), b)
  c.player.res = E.avatar.cap
  assert(play(c, "shield_slam", 1))
  eq(c.player.block, 4, "pas d'Absorb en plus")
  local c2 = setup({ "strike" })
  c2.player.res = 5
  local h2 = c2.enemies[1].hp
  assert(play(c2, "strike", 1))
  eq(c2.enemies[1].hp, h2 - 6, "sans épique")
end)

---------------------------------------------------------------------------
-- Paliers +2 et +3 (15/11/2026, docs/ameliorations.md) : nombres lus par Card.level(src)
---------------------------------------------------------------------------
test("paliers : chaque épique a +2 et +3, texte en « Epic. », crochets hérités du palier 1", function()
  for _, id in ipairs(Warrior.EPICS) do
    eq(Card.tiers(id), 3, id)
    for _, up in ipairs({ 2, 3 }) do
      local d = Card.defById(id, up)
      assert(d.text:find("^Epic%.\n"), id .. "+" .. up)
      eq(d.deckHooks, ns.Cards[id].up.deckHooks, id .. "+" .. up .. " : crochets")
      assert(d.text ~= Card.defById(id, up - 1).text, id .. "+" .. up .. " : texte changé")
    end
  end
end)

-- Ennemi tué avec deux ennemis en face (le combat continue) : PV et Rage du Guerrier après le coup.
local function killOne(id, up)
  local c = setup({ "strike" }, { epic = id, up = up, hp = 40, encounter = { "tw_dummy", "tw_dummy" } })
  c.player.res = 0
  c.enemies[1].hp = 2
  assert(play(c, "strike", 1))
  assert(c.enemies[1].dead and not c.result)
  return c
end

test("paliers : « Kills: » (Death Wish 3 / 5, Sweeping Strikes+3 +1 Rage, Titan's Grip 4 / 6)", function()
  for _, up in ipairs({ false, 1, 2, 3 }) do
    local lv = Card.level(up)
    eq(killOne("death_wish", up).player.hp, 40 + ({ 0, 3, 5, 5 })[lv + 1], "Death Wish+" .. lv)
    eq(killOne("sweeping_strikes", up).player.res, 1 + ({ 0, 0, 0, 1 })[lv + 1], "Sweeping Strikes+" .. lv .. " : Rage")
    local tg = killOne("titans_grip", up)
    eq(tg.player.hp, 40 + ({ 0, 0, 4, 6 })[lv + 1], "Titan's Grip+" .. lv)
    eq(tg.player.res, 1, "Titan's Grip : Rage une fois par carte")
  end
  -- dernier ennemi : soigné aussi (comme Death Wish), le soin compte pour la suite de l'expédition
  local c2 = setup({ "strike" }, { epic = "titans_grip", up = 3, hp = 40 })
  c2.enemies[1].hp = 2
  assert(play(c2, "strike", 1))
  eq(c2.result, "won"); eq(c2.player.hp, 46)
end)

test("paliers : Death Wish+3 Carnage 60 % ; Thunderous Roar 5 / 6 ; Shield Charge +6 / +8 ; Avatar +4 / +5 Rage", function()
  for _, up in ipairs({ 2, 3 }) do
    local c = setup({ "strike" }, { epic = "death_wish", up = up })
    Combat.applyStatus(c, c.player, "force", 4)
    local hp = c.enemies[1].hp
    assert(play(c, "strike", 1))
    eq(hp - c.enemies[1].hp, up == 3 and 16 or 15, "(6 + 4) × " .. N("death_wish", "mult", up))
    local r = setup({ "strike" }, { epic = "thunderous_roar", up = up, encounter = { "tw_dummy", "tw_dummy" } })
    r.player.res = 4
    local b = r.enemies[2].hp
    assert(play(r, "strike", 1))
    eq(b - r.enemies[2].hp, up + 3, "Shockwave " .. (up + 3)); eq(r.enemies[2].st.demoralized, 1)
    local s = setup({ "defend" }, { epic = "shield_charge", up = up })
    assert(play(s, "defend"))
    local h = s.enemies[1].hp
    Combat.endPlayerTurn(s)
    eq(h - s.enemies[1].hp, math.floor(5 / 4) + (up == 3 and 8 or 6), "Punish +" .. (up == 3 and 8 or 6))
    local a = setup({ "strike" }, { epic = "avatar", up = up })
    eq(a.player.res, up + 2, "Juggernaut " .. (up + 2)); Combat.endTurn(a); eq(a.player.res, 2 * (up + 2))
  end
end)

test("paliers : Sweeping Strikes+2 « Attack hits » : les Attacks à tous rebondissent aussi ; +1 non", function()
  for _, up in ipairs({ 1, 2, 3 }) do
    local c = setup({ "whirlwind" }, { epic = "sweeping_strikes", up = up, encounter = { "tw_dummy", "tw_dummy", "tw_dummy" } })
    local hp = c.enemies[1].hp
    assert(play(c, "whirlwind"))
    -- 4 deux fois à chacun ; palier 2+ : chaque coup (4 PV) rebondit d'un tiers (1) sur les deux autres
    eq(hp - c.enemies[1].hp, up >= 2 and 12 or 8, "Whirlwind, Sweeping Strikes+" .. up)
  end
end)

test("paliers : Anger Management Haste 3 / 4 (Shield Wall revient après une seule Rage), +1 Haste 2", function()
  for _, up in ipairs({ 1, 2, 3 }) do
    local c = setup({ "shield_wall", "heroic_strike" }, { epic = "anger_management", up = up })
    c.player.mana = 9
    assert(play(c, "shield_wall"))
    c.hand[#c.hand + 1] = Card.new("execute", false, 801)
    c.player.res = 0
    c.enemies[1].hp = 40
    assert(play(c, "execute", 1)) -- Surge 0 (Rage gagnée après) : rien
    c.player.res = 1
    c.hand[#c.hand + 1] = Card.new("ignore_pain", false, 802)
    assert(play(c, "ignore_pain")) -- Surge 1 : 2 ou 3 crans
    local back = idx(c, "shield_wall") ~= nil
    eq(back, up >= 2, "Shield Wall (recharge 3) revenue dès Haste 3")
  end
end)

---------------------------------------------------------------------------
-- Bots
---------------------------------------------------------------------------
test("bot : conseils par épique (bot.byEpic), note d'épique attachée à celle du deck", function()
  local bot = ns.Classes.warrior.bot
  local exp = X.new({ seed = 3, class = "warrior", unlocks = Meta.allUnlocked(7, 7) })
  X.addCard(exp, "death_wish")
  local adv = bot.byEpic.death_wish
  assert(adv.rating.shield_block < 5 and adv.remove.defend < 1 and adv.remove.death_wish == 99)
  assert(bot.epic(exp, "death_wish") > bot.epic(exp, "avatar") + 0.5, "garde l'épique du deck")
  for _, id in ipairs(Warrior.EPICS) do
    local a = bot.byEpic[id]
    assert(a and a.rating and a.upgrade[id] and a.remove[id] == 99, id)
  end
  -- Titan's Grip : les Strike partent les premiers (retrait 0)
  local rec, e2 = ns.SimExpedition.play({ seed = 2, class = "warrior", epic = "titans_grip", zones = 7 })
  eq(e2.deck[X.epicIndex(e2)].id, "titans_grip", "le bot garde l'épique imposée")
  if (rec.removed or 0) > 0 then
    local strikes = 0
    for _, cd in ipairs(e2.deck) do if cd.id == "strike" then strikes = strikes + 1 end end
    assert(strikes < 4, "un Strike retiré d'abord")
  end
end)

for _, id in ipairs({ "tw_dummy", "tw_hitter", "tw_double" }) do ns.Enemies[id] = nil end

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
