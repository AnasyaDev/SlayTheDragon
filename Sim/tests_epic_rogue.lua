-- Tests des sept cartes épiques du Voleur (fiche : docs/zones/cartes-de-zone.md, « Rogue » ; règles :
-- Core/Classes/rogue.lua). Une épique = ses cas nominaux et ses cas limites. Les tests ne dépendent pas de
-- la pile où se trouve l'épique : ses crochets sont ceux du deck (deckHooks), actifs partout.
-- Usage : lua5.1 Sim/tests_epic_rogue.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local Combat, Card, Save, R = ns.Combat, ns.Card, ns.Save, ns.Rogue
local Cards = ns.Cards
local E = R.EPIC -- nombres (base, amélioré) des épiques : Data/Rogue.lua
local RD = R.riposteDamage -- k-ième riposte du tour (Deflection)
local function S(n, up) local t = 0 for k = 1, n do t = t + RD(k, up) end return t end

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

ns.Enemies.ter_dummy = { name = "Mannequin", hp = 200,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.ter_hitter = { name = "Cogneur", hp = 200,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }
ns.Enemies.ter_boss = { name = "Chef", hp = 300, boss = true,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.ter_indomitable = { name = "Élite", hp = 200, elite = true, indomitable = true,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }

local EPICS = { "deflection", "doomblade", "atrophic_poison", "echoing_reprimand", "subterfuge", "kidney_shot",
  "danse_macabre" }
local ZONES = { "westfall", "duskwood", "wetlands", "stranglethorn", "swamp", "steppes", "blackrock" }

-- Combat de test : main imposée, l'épique (améliorée si up) dans le deck, le reste en pioche.
local function setup(epic, hand, opts)
  opts = opts or {}
  local deck = {}
  for _, id in ipairs(hand) do deck[#deck + 1] = { id = id, up = false } end
  for _, id in ipairs(opts.extra or { "sinister_strike", "sinister_strike", "sinister_strike" }) do
    deck[#deck + 1] = { id = id, up = false }
  end
  if epic then deck[#deck + 1] = { id = epic, up = opts.up or false } end
  local c = Combat.new({ seed = 7, class = "rogue", hp = 60, maxHp = 60, deck = deck, relics = opts.relics,
    encounter = opts.encounter or { "ter_dummy" } })
  local all = {}
  for _, x in ipairs(c.hand) do all[#all + 1] = x end
  for _, x in ipairs(c.draw) do all[#all + 1] = x end
  c.hand, c.draw = {}, {}
  local byId = {}
  for _, x in ipairs(all) do byId[x.id] = byId[x.id] or {}; table.insert(byId[x.id], x) end
  for _, id in ipairs(hand) do c.hand[#c.hand + 1] = table.remove(byId[id]) end
  for _, list in pairs(byId) do for _, x in ipairs(list) do c.draw[#c.draw + 1] = x end end
  c.player.mana = opts.mana or 9
  return c
end

local function idx(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
  error("absente de la main : " .. id)
end
local function play(c, id, t) return assert(Combat.play(c, idx(c, id), t)) end
local function hp(c, i) return c.enemies[i or 1].hp end
local function dot(v, up) return math.ceil(v * E.doomblade[R.tier(up)] - 1e-9) end

---------------------------------------------------------------------------
-- Commun aux sept
---------------------------------------------------------------------------
test("sept épiques : une par zone, rareté epic, Voleur, texte « Epic. » en tête, nombres du texte = Rogue.EPIC", function()
  for i, id in ipairs(EPICS) do
    local d = Cards[id]
    assert(d, id)
    eq(d.class, "rogue", id); eq(d.rarity, "epic", id); eq(d.zone, ZONES[i], id); eq(d.epic, true, id)
    eq(d.level, nil, id .. " : hors grille"); eq(d.type, "power", id)
    assert(d.deckHooks, id .. " : crochets de l'épique")
    assert(d.text:find("^Epic%.\n"), id); assert(d.up.text:find("^Epic%.\n"), id)
    assert(Card.isEpic(d) and Card.collectible(d))
    eq(ns.Meta.zoneCards("rogue", ZONES[i])[1], id)
  end
  -- texte de la carte (déclencheur, mot de règle et son nombre) et à-côté de ses mots de règle (L.rule)
  local Lg = ns.Language
  for k, up in ipairs({ false, 1, 2, 3 }) do -- k = Rogue.tier(up) : base, +1, +2, +3
    local function card(id) return Card.defById(id, up).text end
    local function t(id)
      local d = Card.defById(id, up)
      local out = { d.text }
      for _, r in ipairs(Lg.ruleWords(d)) do out[#out + 1] = r.kw.name .. ": " .. Lg.ruleText(r.kw, r.n, up) end
      return table.concat(out, "\n")
    end
    assert(card("deflection"):find("Each Parry gained: Riposte " .. E.deflection[k] .. "%."))
    assert(t("deflection"):find("Riposte: Deal " .. E.deflection[k] .. " damage to the last target, %+"
      .. E.deflectionStep[k] .. " per earlier Riposte this turn%."), t("deflection"))
    assert(card("echoing_reprimand"):find("Animacharge " .. E.echoing_reprimand[k] .. "%."))
    assert(t("echoing_reprimand"):find("counts as a Surge of " .. E.echoing_reprimand[k] .. "%."))
    assert(t("echoing_reprimand"):find("Surge of 2" .. (E.echoingMax[k] == 3 and " or 3" or "") .. " Combo", 1, true))
    local kl, kr = E.kidney_shot[k], E.kidneyCombo[k]
    -- paliers 2 et 3 : déclencheur court « Surge of 4+: Gouge, +N Combo. » ; « Shroud 3, Parry N. » (deux lignes)
    if kr > 0 then
      assert(card("kidney_shot"):find("Surge of " .. kl .. "+: Gouge, +" .. kr .. " Combo.", 1, true), card("kidney_shot"))
      assert(Lg.triggers["Surge of " .. kl .. "+"], "déclencheur court enregistré")
    else
      assert(card("kidney_shot"):find("Surge of " .. kl .. "+ Combo: Gouge.", 1, true), card("kidney_shot"))
    end
    assert(t("kidney_shot"):find("Gouge: Apply Stunned 1", 1, true))
    local sp = E.subterfugeParry[k]
    assert(card("subterfuge"):find("Shroud " .. E.subterfugeTurns[k] .. (sp > 0 and (", Parry " .. sp) or "") .. ".",
      1, true), card("subterfuge"))
    assert(t("subterfuge"):find("Stealth lasts " .. E.subterfugeTurns[k] .. " turns", 1, true))
    if E.subterfuge[k] > 0 then assert(t("subterfuge"):find("gives %+" .. E.subterfuge[k] .. " Combo"))
    else assert(not t("subterfuge"):find("Combo%.")) end
    assert((t("subterfuge"):find("Surge of 1+ Combo grants Stealth", 1, true) ~= nil) == (E.subterfugeSurge[k] == true))
    assert(card("danse_macabre"):find("Flourish " .. E.danse_macabre[k] .. ".", 1, true))
    assert(t("danse_macabre"):find("%+" .. E.danse_macabre[k] .. " damage per other card name"))
    if E.danseFree[k] > 1 then assert(t("danse_macabre"):find("after the first " .. E.danseFree[k], 1, true)) end
    assert((t("danse_macabre"):find("up to", 1, true) ~= nil) == (E.danseCap[k] > 0))
    local pct = math.floor(E.doomblade[k] * 100 + 0.5)
    assert(card("doomblade"):find("Surge Attacks: Bleed " .. pct .. "%", 1, true), card("doomblade"))
    assert(t("doomblade"):find("applies " .. pct .. "% of it as DoT", 1, true), t("doomblade"))
    assert(card("atrophic_poison"):find("DoT " .. E.atrophic_poison[k] .. "+: Atrophy", 1, true))
    assert(t("atrophic_poison"):find("with at least that much DoT count as Demoralized", 1, true))
    assert((t("atrophic_poison"):find("Sundered", 1, true) ~= nil) == (k >= 2))
  end
end)

test("arrivée en jeu : l'épique n'est dans aucune pile ni parmi les Powers, posée dans c.epic ; combat sauvegardable", function()
  for _, id in ipairs(EPICS) do
    for seed = 1, 5 do
      local deck = {}
      for _, x in ipairs(ns.Classes.rogue.deck) do deck[#deck + 1] = { id = x, up = false } end
      deck[#deck + 1] = { id = id, up = seed % 2 == 0 }
      local c = Combat.new({ seed = seed, class = "rogue", hp = 50, deck = deck, encounter = { "ter_dummy" } })
      for _, pile in ipairs({ c.hand, c.draw, c.discard }) do
        for _, inst in ipairs(pile) do assert(inst.id ~= id, id .. " dans une pile") end
      end
      eq(#c.hand, 5, "main de 5 cartes ordinaires")
      eq(#c.hand + #c.draw, #ns.Classes.rogue.deck, "l'épique ne prend pas de place")
      eq(#c.player.powers, 0, id .. " : pas un Power joué")
      eq(c.epic.id, id); eq(c.epic.up, ns.Card.upValue(seed % 2 == 0))
      eq(R.epicOf(c), id)
      assert(Save.isPlain(c), id .. " : combat sauvegardable")
    end
  end
end)

test("crochets de l'épique : src = c.epic (amélioration lue sur c.epic.up), après les bibelots", function()
  local c = setup("deflection", { "feint" })
  local h = hp(c)
  play(c, "feint")
  eq(hp(c), h - RD(1))
  local u = setup("deflection", { "feint" }, { up = true })
  eq(u.epic.up, 1)
  play(u, "feint")
  eq(hp(u), 200 - RD(1, true))
end)

---------------------------------------------------------------------------
-- Deflection
---------------------------------------------------------------------------
test("Deflection : trois Feint = N, N+S, N+2S à la dernière cible, Parry gardé", function()
  local c = setup("deflection", { "sinister_strike", "feint", "feint", "feint" }, { encounter = { "ter_dummy", "ter_dummy" } })
  play(c, "sinister_strike", 2)
  local h, h1 = hp(c, 2), hp(c, 1)
  play(c, "feint"); play(c, "feint"); play(c, "feint")
  eq(hp(c, 2), h - S(3), "la dernière cible")
  eq(hp(c, 1), h1, "l'autre ennemi rien")
  eq(c.player.st.parry, 3, "la défense reste")
  eq(R.ripostes(c), 3); eq(R.nextRiposte(c), RD(4))
end)

test("Deflection : Evasion (Parry 2) puis deux Feint = quatre ripostes croissantes ; au-dessus de Parry 3 la riposte a lieu", function()
  local c = setup("deflection", { "evasion", "feint", "feint" })
  local h = hp(c)
  play(c, "evasion"); play(c, "feint"); play(c, "feint")
  eq(hp(c), h - S(4))
  eq(c.player.st.parry, 3, "plafond 3, charge perdue")
end)

test("Deflection : compteur remis à 0 au début du tour du Voleur, continu pendant le tour ennemi", function()
  local c = setup("deflection", { "feint", "feint" }, { extra = { "feint", "feint", "feint", "feint", "feint" } })
  play(c, "feint"); play(c, "feint")
  eq(R.ripostes(c), 2)
  Combat.endPlayerTurn(c)
  local h = hp(c)
  Combat.applyStatus(c, c.player, "parry", 1) -- Cheat Death, effet pendant le tour ennemi
  eq(hp(c), h - RD(3), "troisième riposte du tour")
  Combat.enemyPhase(c); Combat.endRound(c); Combat.startPlayerTurn(c)
  eq(R.ripostes(c), 0)
  h = hp(c)
  c.player.mana = 9
  play(c, "feint")
  eq(hp(c), h - RD(1), "nouveau tour : k")
end)

test("Deflection : Blinding Powder riposte au début du combat et compte pour le tour 1", function()
  local c = setup("deflection", { "feint" }, { relics = { "blinding_powder" } })
  eq(hp(c), 200 - RD(1))
  eq(R.ripostes(c), 1)
  play(c, "feint")
  eq(hp(c), 200 - S(2))
end)

test("Deflection : dernière cible morte = l'ennemi vivant le plus à gauche ; Sundered s'applique ; amélioré", function()
  local c = setup("deflection", { "sinister_strike", "feint", "feint" }, { encounter = { "ter_dummy", "ter_dummy" } })
  play(c, "sinister_strike", 2)
  c.enemies[2].hp = 1
  Combat.dealDamage(c, c.player, c.enemies[2], 5)
  assert(c.enemies[2].dead)
  local h = hp(c, 1)
  play(c, "feint")
  eq(hp(c, 1), h - RD(1), "repli sur l'ennemi de gauche")
  Combat.applyStatus(c, c.enemies[1], "armor_broken", 2)
  h = hp(c, 1)
  play(c, "feint")
  eq(hp(c, 1), h - math.floor(RD(2) * 1.25), "2k × 1,25 arrondi à l'inférieur")
  local u = setup("deflection", { "feint", "feint" }, { up = true })
  play(u, "feint"); play(u, "feint")
  eq(hp(u), 200 - S(2, true))
end)

test("Deflection : Ravenholdt Signet (Parry après un Surge) riposte aussi", function()
  local c = setup("deflection", { "eviscerate" }, { relics = { "ravenholdt_signet" } })
  c.player.res = 2
  play(c, "eviscerate", 1)
  eq(hp(c), 200 - 12 - RD(1))
end)

---------------------------------------------------------------------------
-- Doomblade
---------------------------------------------------------------------------
test("Doomblade : Eviscerate à 5 Combo = DoT (part de 24) au lieu de 24, sans Absorb ; amélioré", function()
  local c = setup("doomblade", { "eviscerate" })
  c.player.res = 5
  c.enemies[1].block = 10
  play(c, "eviscerate", 1)
  eq(hp(c), 200); eq(c.enemies[1].block, 10, "le DoT ignore l'Absorb"); eq(c.enemies[1].st.pain, dot(24))
  eq(c.player.res, 0)
  local u = setup("doomblade", { "eviscerate" }, { up = true })
  u.player.res = 5
  play(u, "eviscerate", 1)
  eq(u.enemies[1].st.pain, dot(24, true))
end)

test("Doomblade : arrondi au supérieur, Sundered compté, Crystal Vial +1 ; les autres Attacks frappent", function()
  local c = setup("doomblade", { "eviscerate", "sinister_strike" }, { relics = { "crystal_vial" } })
  c.player.res = 1
  Combat.applyStatus(c, c.enemies[1], "armor_broken", 2)
  play(c, "eviscerate", 1)
  eq(c.enemies[1].st.pain, dot(10) + 1, "8 × 1,25 = 10, part posée, +1 (Crystal Vial)")
  local h = hp(c)
  play(c, "sinister_strike", 1)
  eq(hp(c), h - 6, "Sinister Strike frappe (5 × 1,25)")
end)

test("Doomblade : Secret Technique sous Stealth = deux DoT par ennemi ; Between the Eyes garde Stunned ; Envenom inchangée", function()
  local c = setup("doomblade", { "secret_technique" }, { encounter = { "ter_dummy", "ter_dummy" } })
  c.player.res = 3
  play(c, "secret_technique")
  eq(c.enemies[1].st.pain, 2 * dot(12)); eq(c.enemies[2].st.pain, 2 * dot(12)); eq(hp(c, 1), 200)
  local b = setup("doomblade", { "between_the_eyes" })
  b.player.res = 2
  play(b, "between_the_eyes", 1)
  eq(b.enemies[1].st.pain, dot(8)); eq(b.enemies[1].st.stunned, 1); eq(hp(b), 200)
  local e = setup("doomblade", { "envenom" })
  e.player.res = 2
  play(e, "envenom", 1)
  eq(e.enemies[1].st.pain, 3, "DoT 4 posé, tic de 4 : reste 3")
  eq(hp(e), 196)
end)

test("Doomblade : un coup converti n'est pas un coup (pas de Deadly Poison)", function()
  local c = setup("doomblade", { "deadly_poison", "nightblade" })
  play(c, "deadly_poison")
  c.player.res = 2
  play(c, "nightblade", 1)
  eq(c.enemies[1].st.pain, dot(12), "12 → DoT, pas de +1 de Deadly Poison")
  eq(c.player.st.stealth, 1, "Nightblade rend Stealth")
end)

---------------------------------------------------------------------------
-- Atrophic Poison
---------------------------------------------------------------------------
test("Atrophic Poison : un ennemi qui porte assez de DoT frappe à -25 % ; DoT 1 tombe avant son coup", function()
  local c = setup("atrophic_poison", { "garrote" }, { encounter = { "ter_hitter" } })
  Combat.applyStatus(c, c.enemies[1], "pain", E.atrophic_poison[1] - 3)
  play(c, "garrote", 1) -- DoT 3 de plus : le seuil
  eq(Combat.intentInfo(c, c.enemies[1]).damage, 7, "intention : 10 → 7")
  local h = c.player.hp
  Combat.endTurn(c)
  eq(c.player.hp, h - 7)
  local d = setup("atrophic_poison", { "feint" }, { encounter = { "ter_hitter" } })
  Combat.applyStatus(d, d.enemies[1], "pain", 1)
  eq(Combat.intentInfo(d, d.enemies[1]).damage, 10, "DoT 1 : intention pleine")
  h = d.player.hp
  Combat.endTurn(d)
  eq(d.player.hp, h - 10, "le DoT 1 tique avant le coup")
end)

test("Atrophic Poison : seuil de DoT (montré avant le tic) ; un de moins ne compte pas, ni pour l'intention ni pour le coup", function()
  local T = E.atrophic_poison[1]
  local c = setup("atrophic_poison", { "feint" }, { encounter = { "ter_hitter" } })
  Combat.applyStatus(c, c.enemies[1], "pain", T)
  eq(Combat.intentInfo(c, c.enemies[1]).damage, T > 1 and 7 or 10, "au seuil")
  local h = c.player.hp
  Combat.endTurn(c)
  eq(c.player.hp, h - 7, "au seuil : le coup suit l'intention")
  if T > 2 then
    local d = setup("atrophic_poison", { "feint" }, { encounter = { "ter_hitter" } })
    Combat.applyStatus(d, d.enemies[1], "pain", T - 1)
    eq(Combat.intentInfo(d, d.enemies[1]).damage, 10, "sous le seuil")
    h = d.player.hp
    Combat.endTurn(d)
    eq(d.player.hp, h - 10, "sous le seuil : coup plein")
  end
  local u = setup("atrophic_poison", { "sinister_strike" }, { up = true })
  Combat.applyStatus(u, u.enemies[1], "pain", E.atrophic_poison[2] - 1)
  play(u, "sinister_strike", 1)
  eq(hp(u), 200 - 5, "amélioré sous le seuil : pas de Sundered")
end)

test("Atrophic Poison : ne se cumule pas avec un vrai Demoralized ; amélioré : Sundered sans cumul", function()
  local c = setup("atrophic_poison", { "crippling_poison" }, { encounter = { "ter_hitter" } })
  play(c, "crippling_poison", 1)
  eq(Combat.intentInfo(c, c.enemies[1]).damage, 7, "un seul -25 %")
  local u = setup("atrophic_poison", { "sinister_strike", "sinister_strike" }, { up = true })
  Combat.applyStatus(u, u.enemies[1], "pain", E.atrophic_poison[2])
  play(u, "sinister_strike", 1)
  eq(hp(u), 200 - 6, "5 × 1,25")
  Combat.applyStatus(u, u.enemies[1], "armor_broken", 2)
  local h = hp(u)
  play(u, "sinister_strike", 1)
  eq(hp(u), h - 6, "vrai Sundered : pas de cumul")
  local b = setup("atrophic_poison", { "sinister_strike" })
  Combat.applyStatus(b, b.enemies[1], "pain", E.atrophic_poison[1])
  play(b, "sinister_strike", 1)
  eq(hp(b), 200 - 5, "non amélioré : pas de Sundered")
end)

---------------------------------------------------------------------------
-- Echoing Reprimand
---------------------------------------------------------------------------
test("Echoing Reprimand : un Surge de 2 ou 3 compte N, la dépense ne change pas ; 1, 4 et 5 comptent leur valeur", function()
  local m = E.echoing_reprimand[1]
  local top = E.echoingMax[1]
  local want = { [1] = 8, [2] = 4 + 4 * m, [3] = top >= 3 and 4 + 4 * m or 16, [4] = 20, [5] = 24 }
  for n = 1, 5 do
    local c = setup("echoing_reprimand", { "eviscerate" })
    c.player.res = n
    play(c, "eviscerate", 1)
    eq(200 - hp(c), want[n], n .. " Combo")
    eq(c.player.res, 0)
  end
  local u = setup("echoing_reprimand", { "eviscerate", "rupture" }, { up = true })
  u.player.res = 2
  play(u, "eviscerate", 1)
  local m2 = E.echoing_reprimand[2]
  eq(hp(u), 200 - (4 + 4 * m2), "amélioré")
  u.player.res = E.echoingMax[2]
  play(u, "rupture", 1)
  eq(u.enemies[1].st.pain, 3 * m2, "amélioré, haut de la plage")
end)

---------------------------------------------------------------------------
-- Subterfuge
---------------------------------------------------------------------------
-- fin des tours jusqu'à la chute de Stealth ; renvoie le nombre de fins de tour
local function untilStealthFalls(c)
  local n = 0
  while (c.player.st.stealth or 0) > 0 and n < 10 do Combat.endTurn(c) n = n + 1 end
  return n
end

test("Subterfuge : chaque Attack profite de Stealth sans le retirer ; il dure T tours (celui du départ aussi)", function()
  local T = E.subterfugeTurns[1]
  local c = setup("subterfuge", { "backstab", "backstab", "ambush" })
  play(c, "backstab", 1); play(c, "backstab", 1)
  eq(hp(c), 200 - 20)
  eq(c.player.st.stealth, 1)
  play(c, "ambush", 1)
  eq(hp(c), 200 - 38)
  eq(c.player.res, 4, "Combo des cartes seulement (aucun Stealth gagné)")
  eq(R.stealthLeft(c), T)
  eq(untilStealthFalls(c), T, "tombé à la fin du T-ième tour")
  eq(R.stealthLeft(c), 0)
end)

test("Subterfuge : un Stealth posé repart pour T tours ; chaque Stealth gagné donne N Combo, pas un gain sous Stealth ni celui du départ", function()
  local T = E.subterfugeTurns[1]
  local c = setup("subterfuge", { "vanish", "backstab" }, { extra = { "feint", "feint", "feint", "feint", "feint",
    "feint", "feint", "feint", "feint", "feint" } })
  eq(c.player.res, 0, "Stealth du début de combat : rien")
  play(c, "vanish")
  eq(c.player.res, 0, "déjà en Stealth : pas un gain")
  eq(R.stealthLeft(c), T, "reparti pour T tours")
  untilStealthFalls(c)
  c.player.mana = 9
  c.hand[#c.hand + 1] = Card.new("vanish", false, 990)
  local r = c.player.res
  play(c, "vanish")
  eq(c.player.res, r + E.subterfuge[1], "absent → présent")
  eq(untilStealthFalls(c), T)
  local u = setup("subterfuge", { "backstab" }, { up = true, extra = { "feint", "feint", "feint", "feint", "feint",
    "feint", "feint", "feint", "feint", "feint" } })
  untilStealthFalls(u)
  u.player.mana = 9
  u.hand[#u.hand + 1] = Card.new("shadowstep", false, 991)
  r = u.player.res
  play(u, "shadowstep")
  eq(u.player.res, r + E.subterfuge[2], "amélioré")
  eq(R.stealthLeft(u), E.subterfugeTurns[2])
end)

test("Subterfuge : chaque Surge rend Stealth (source incluse) ; la carte du Surge n'en profite pas, les suivantes oui", function()
  local T = E.subterfugeTurns[1]
  local c = setup("subterfuge", { "feint" }, { extra = { "feint", "feint", "feint", "feint", "feint",
    "feint", "feint", "feint", "feint", "feint" } })
  untilStealthFalls(c)
  c.player.mana = 9
  c.player.res = 2
  c.hand[#c.hand + 1] = Card.new("eviscerate", false, 993)
  c.hand[#c.hand + 1] = Card.new("backstab", false, 994)
  local h = hp(c)
  play(c, "eviscerate", 1)
  eq(h - hp(c), 12, "Eviscerate sans bonus")
  eq(c.player.st.stealth, 1, "Stealth rendu par le Surge")
  eq(c.player.res, E.subterfuge[1], "gain réel : Combo de l'épique")
  eq(R.stealthLeft(c), T)
  h = hp(c)
  play(c, "backstab", 1)
  eq(h - hp(c), 10, "Backstab sous Stealth")
  local z = setup("subterfuge", { "feint" }, { extra = { "feint", "feint", "feint", "feint", "feint",
    "feint", "feint", "feint", "feint", "feint" } })
  untilStealthFalls(z)
  z.player.mana = 9
  z.player.res = 0
  z.hand[#z.hand + 1] = Card.new("envenom", false, 992)
  play(z, "envenom", 1)
  eq(z.player.st.stealth, nil, "Surge à 0 Combo : rien")
end)

---------------------------------------------------------------------------
-- Kidney Shot
---------------------------------------------------------------------------
test("Kidney Shot : Surge du seuil étourdit la cible vivante ; un de moins ne fait rien ; amélioré : seuil plus bas", function()
  local k1, k2 = E.kidney_shot[1], E.kidney_shot[2]
  local c = setup("kidney_shot", { "eviscerate" })
  c.player.res = k1
  play(c, "eviscerate", 1)
  eq(c.enemies[1].st.stunned, 1)
  local f = setup("kidney_shot", { "eviscerate" })
  f.player.res = k1 - 1
  play(f, "eviscerate", 1)
  eq(f.enemies[1].st.stunned, nil)
  local u = setup("kidney_shot", { "rupture" }, { up = true })
  u.player.res = k2
  play(u, "rupture", 1)
  eq(u.enemies[1].st.stunned, 1, "Skill à cible aussi")
end)

test("Kidney Shot : élite Indomitable = Demoralized 2 ⌛, jamais Stunned (Combat.stunImmune)", function()
  local c = setup("kidney_shot", { "eviscerate" }, { encounter = { "ter_indomitable" } })
  c.player.res = 5
  play(c, "eviscerate", 1)
  eq(c.enemies[1].st.stunned, nil, "Indomitable épargné"); eq(c.enemies[1].st.demoralized, 2)
end)

test("Kidney Shot : boss = Demoralized 2 ⌛ ; Between the Eyes = Stunned 2 ; cible morte ou Surge sans cible : rien", function()
  local c = setup("kidney_shot", { "eviscerate" }, { encounter = { "ter_boss" } })
  c.player.res = 5
  play(c, "eviscerate", 1)
  eq(c.enemies[1].st.stunned, nil); eq(c.enemies[1].st.demoralized, 2)
  local b = setup("kidney_shot", { "between_the_eyes" })
  b.player.res = 5
  play(b, "between_the_eyes", 1)
  eq(b.enemies[1].st.stunned, 2)
  local k = setup("kidney_shot", { "eviscerate" }, { encounter = { "ter_dummy", "ter_dummy" } })
  k.player.res = 5
  k.enemies[1].hp = 10
  play(k, "eviscerate", 1)
  assert(k.enemies[1].dead); eq(k.enemies[2].st.stunned, nil)
  local s = setup("kidney_shot", { "secret_technique" })
  s.player.res = 5
  play(s, "secret_technique")
  eq(s.enemies[1].st.stunned, nil)
end)

---------------------------------------------------------------------------
-- Danse Macabre
---------------------------------------------------------------------------
-- bonus d'un coup quand n autres noms ont été joués ce tour
local function DB(n, up)
  local k = R.tier(up)
  local b = E.danse_macabre[k] * math.max(0, n - E.danseFree[k])
  local cap = E.danseCap[k]
  return (cap > 0 and b > cap) and cap or b
end

test("Danse Macabre : +N par autre nom joué ce tour au-delà des F premiers, doublons comptés une fois, son nom exclu", function()
  local F = E.danseFree[1]
  assert(F == 2, "test écrit pour F = 2")
  local c = setup("danse_macabre", { "kick", "sprint", "pistol_shot", "sinister_strike", "sinister_strike" })
  play(c, "kick", 1); play(c, "sprint")
  local h = hp(c)
  play(c, "pistol_shot", 1)
  eq(hp(c), h - (3 + DB(2)), "deux autres noms : rien encore")
  eq(DB(2), 0)
  h = hp(c)
  play(c, "sinister_strike", 1)
  eq(hp(c), h - (5 + DB(3)), "trois autres noms : N")
  assert(DB(3) > 0)
  h = hp(c)
  play(c, "sinister_strike", 1)
  eq(hp(c), h - (5 + DB(3)), "le doublon ne compte pas, son nom exclu")
  eq(R.namesPlayed(c), 4)
  eq(R.danseBonus(c, false), DB(4), "bonus d'un nom nouveau (ligne de l'épique)")
  Combat.endTurn(c)
  eq(R.namesPlayed(c), 0, "nouveau tour")
  eq(R.danseBonus(c, false), 0)
end)

test("Danse Macabre : chaque coup (Killing Spree), avant Sundered ; amélioré", function()
  local c = setup("danse_macabre", { "kick", "pistol_shot", "sprint", "killing_spree" })
  play(c, "kick", 1); play(c, "pistol_shot", 1); play(c, "sprint")
  local h = hp(c)
  play(c, "killing_spree")
  eq(h - hp(c), 6 * (4 + DB(3)), "six coups de 4 + bonus de trois noms")
  local s = setup("danse_macabre", { "kick", "sprint", "pistol_shot", "sinister_strike" }, { up = true })
  Combat.applyStatus(s, s.enemies[1], "armor_broken", 2)
  play(s, "kick", 1); play(s, "sprint"); play(s, "pistol_shot", 1)
  local h2 = hp(s)
  play(s, "sinister_strike", 1)
  eq(h2 - hp(s), math.floor((5 + DB(3, true)) * 1.25), "(5 + bonus) × 1,25")
end)

---------------------------------------------------------------------------
-- Paliers 2 et 3 des épiques (15/11/2026, docs/ameliorations.md) : nombres lus par Card.level(src)
---------------------------------------------------------------------------
test("paliers : Rogue.tier (base 1 … +3 = 4), nombres croissants, l'à-côté (upText) reste vrai aux paliers 2 et 3", function()
  eq(R.tier(false), 1); eq(R.tier(true), 2); eq(R.tier(2), 3); eq(R.tier({ up = 3 }), 4)
  for key, t in pairs(E) do eq(#t, 4, key .. " : quatre paliers") end
  for _, id in ipairs(EPICS) do eq(Card.tiers(id), 3, id) end
  -- seuils qui baissent, nombres qui montent
  assert(E.deflection[3] > E.deflection[2] and E.deflection[4] > E.deflection[3])
  assert(E.atrophic_poison[3] < E.atrophic_poison[2] and E.atrophic_poison[4] < E.atrophic_poison[3])
  assert(E.kidneyCombo[3] > 0 and E.subterfugeParry[3] > 0)
  -- nombres de l'à-côté écrits pour le +1 : inchangés aux paliers 2 et 3
  for _, key in ipairs({ "deflectionStep", "echoingMax", "subterfuge", "subterfugeSurge", "danseFree", "danseCap" }) do
    eq(E[key][3], E[key][2], key); eq(E[key][4], E[key][2], key)
  end
end)

test("paliers : Deflection +3 (riposte N = 4), Doomblade +2 (part du DoT), Danse Macabre +3", function()
  local u = setup("deflection", { "feint" }, { up = 3 })
  eq(u.epic.up, 3)
  play(u, "feint")
  eq(hp(u), 200 - E.deflection[4]); eq(R.riposteDamage(2, 3), E.deflection[4] + E.deflectionStep[4])
  local d = setup("doomblade", { "eviscerate" }, { up = 2 })
  d.player.res = 5
  play(d, "eviscerate", 1)
  eq(d.enemies[1].st.pain, dot(24, 2)); assert(dot(24, 2) > dot(24, true))
  local s = setup("danse_macabre", { "kick", "sprint", "pistol_shot", "sinister_strike" }, { up = 3 })
  play(s, "kick", 1); play(s, "sprint"); play(s, "pistol_shot", 1)
  local h = hp(s)
  play(s, "sinister_strike", 1)
  eq(h - hp(s), 5 + DB(3, 3)); eq(DB(3, 3), E.danse_macabre[4])
end)

test("paliers : Atrophic Poison +3, seuil 3 (Demoralized et Sundered) ; Echoing Reprimand +3", function()
  local T = E.atrophic_poison[4]
  local c = setup("atrophic_poison", { "sinister_strike" }, { up = 3, encounter = { "ter_hitter" } })
  Combat.applyStatus(c, c.enemies[1], "pain", T)
  assert(R.countsDemoralized(c, c.enemies[1]), "seuil du +3")
  play(c, "sinister_strike", 1)
  eq(hp(c), 200 - 6, "Sundered dès le seuil du +3")
  local b = setup("atrophic_poison", { "sinister_strike" }, { up = 1, encounter = { "ter_hitter" } })
  Combat.applyStatus(b, b.enemies[1], "pain", T)
  assert(not R.countsDemoralized(b, b.enemies[1]), "sous le seuil du +1")
  local e = setup("echoing_reprimand", { "eviscerate" }, { up = 3 })
  e.player.res = 2
  play(e, "eviscerate", 1)
  eq(hp(e), 200 - (4 + 4 * E.echoing_reprimand[4]))
end)

test("paliers : Kidney Shot +2 rend des Combo après le Surge qui étourdit (cible morte comprise), pas en dessous du seuil", function()
  local k = E.kidney_shot[3]
  local c = setup("kidney_shot", { "eviscerate" }, { up = 2 })
  c.player.res = k
  play(c, "eviscerate", 1)
  eq(c.enemies[1].st.stunned, 1); eq(c.player.res, E.kidneyCombo[3])
  local f = setup("kidney_shot", { "eviscerate" }, { up = 3 })
  f.player.res = k - 1
  play(f, "eviscerate", 1)
  eq(f.player.res, 0, "sous le seuil : rien")
  local m = setup("kidney_shot", { "eviscerate" }, { up = 3, encounter = { "ter_dummy", "ter_dummy" } })
  m.player.res = 5
  m.enemies[1].hp = 5
  play(m, "eviscerate", 1)
  assert(m.enemies[1].dead); eq(m.player.res, E.kidneyCombo[4], "cible morte : Combo rendus")
  local u = setup("kidney_shot", { "eviscerate" }, { up = 1 })
  u.player.res = 5
  play(u, "eviscerate", 1)
  eq(u.player.res, 0, "+1 : rien de rendu")
end)

test("paliers : Subterfuge +2 / +3, Parry à chaque Surge (en plus de Stealth)", function()
  for lv = 1, 3 do
    local c = setup("subterfuge", { "eviscerate" }, { up = lv })
    c.player.res = 2
    play(c, "eviscerate", 1)
    eq(c.player.st.parry or 0, E.subterfugeParry[lv + 1], "palier " .. lv)
    eq(c.player.st.stealth, 1)
  end
end)

---------------------------------------------------------------------------
-- Bots et simulation
---------------------------------------------------------------------------
test("simulation : chaque épique imposée tient l'expédition, sans erreur", function()
  for _, id in ipairs(EPICS) do
    local rec, exp = ns.SimExpedition.play({ seed = 2, class = "rogue", epic = id, zones = 7 })
    eq(exp.deck[ns.Expedition.epicIndex(exp)].id, id, id .. " gardée")
    assert(#rec.combats > 0)
  end
end)

ns.Enemies.ter_dummy, ns.Enemies.ter_hitter, ns.Enemies.ter_boss = nil, nil, nil

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
