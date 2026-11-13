-- Harnais d'interface des Burning Steppes (section UZS) : combat avec le Wildfire visible (jeton, prévision
-- des Stoke, flamme sur l'intention, brûlure hachurée sur la barre de PV, serviteur), boss, rencontres,
-- décors peints (planches build/snap/decor-steppes_*.svg). Lancé par Sim/ui_harness.lua (docs/zones.md, § 8).
return function(T)
  local H, check, snap, R = T.H, T.check, T.snap, T.R
  local SNAP = arg and arg[2]

  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end

  -- Expédition des Steppes (zones 1 à 5 gagnées), premier nœud forcé au genre `kind`.
  local function steppesRun(cl, kind, seed, setup)
    H.boot(nil)
    H.slash("")
    local ns = H.ns
    local X = ns.Expedition
    local won = { westfall = 5, duskwood = 5, wetlands = 5, stranglethorn = 5, swamp = 5 }
    local exp = X.new({ seed = seed or T.SEED, class = cl or "priest", zone = "steppes",
      unlocks = { level = 7, common = 6, won = won } })
    if exp.phase == "start" then X.act(exp, { "skipStartRelic" }) end
    ns.Persist.db.current = exp
    ns.UI.refresh()
    H.settle()
    if setup then setup(exp) end
    if kind then
      local id = exp.map.start[1]
      exp.map.nodes[id].kind = kind
      exp.gold = 500
      T.clickOption("path:" .. id)
      H.settle()
    end
    return exp, ns
  end

  -- 1. Combat : jeton, Stoke, prévision, hachure, serviteur
  local exp, ns = steppesRun("priest", "combat")
  local c, v = exp.combat, T.V()
  check("Steppes : combat dans la zone, règle active", c and c.zone == "steppes" and c.zs and c.zs.steppes ~= nil)
  local WF = ns.Wildfire
  local z = c.zs.steppes
  -- groupe imposé : un attiseur (Stoke en attaque) et un frappeur
  local E = ns.Enemies
  c.enemies[1].id, c.enemies[1].intent = "black_dragonspawn", "roar"
  for i = 2, #c.enemies do c.enemies[i].id, c.enemies[i].intent = "blackrock_worg", "bite" end
  v:Render(true)
  H.settle()
  check("jeton : « Wildfire in 3 → 2 » (Stoke annoncé), flamme grise, infobulle",
    vis(v.counter) and v.counter.text._text == "Wildfire in 3 → 2" and (H.hover(v.counter)[1] or ""):find("Ignites in 3 rounds", 1, true) ~= nil,
    tostring(v.counter.text._text))
  local s1 = v.slotOf[c.enemies[1].uid]
  check("intention avec Stoke : « 6 +1 » et petite flamme à droite, infobulle Stoke",
    s1 and (s1.intent.text._text or ""):find("+1", 1, true) and vis(s1.intent.badge)
    and table.concat(H.hover(s1.intent), " | "):find("Stoke 1:", 1, true) ~= nil,
    s1 and tostring(s1.intent.text._text))
  snap("zone-steppes-combat", true)
  -- sol embrasé : brûlure, jeton rouge, hachure sur la barre de PV
  z.left = 0
  v:Render(true)
  H.settle()
  local host = v.zoneHost.views.steppes
  local hatch = host and host.hatch
  check("sol embrasé : « Wildfire 2 → 4 » (Stoke sur sol embrasé), infobulle de fin de round",
    v.counter.text._text == "Wildfire 2 → 4" and (H.hover(v.counter)[1] or ""):find("End of round: you lose 4 HP", 1, true) ~= nil,
    tostring(v.counter.text._text))
  check("brûlure hachurée sur la barre de PV du joueur (rayures, dans la barre)",
    hatch and vis(hatch) and (hatch.shown or 0) >= 2)
  local hr, br = R.rect(hatch), R.rect(v.playerHp)
  check("hachure dans la barre de PV", hr and br and hr[1] >= br[1] - 0.5 and hr[3] <= br[3] + 0.5 and hr[2] >= br[2] - 0.5)
  snap("zone-steppes-lit", true)
  -- serviteur : flamme grisée sous l'intention
  local ok = pcall(function()
    local m = ns.Combat.spawn(c, "ember_worg", c.enemies[1])
    v:Render(true)
    H.settle()
    local sm = v.slotOf[m.uid]
    assert(sm and vis(sm.badges[1]) and (H.hover(sm.badges[1])[1] or ""):find("does not delay", 1, true))
  end)
  check("serviteur : flamme grisée (sa mort ne recule pas le feu)", ok)
  -- carte Douse : explication du mot au survol
  local L = ns.Language
  check("mots de la zone : Wildfire, Douse, Stoke (explications de 60 caractères au plus)",
    L.keywords.douse and #("Douse: " .. L.keywords.douse.text) <= 60 and #("Wildfire: " .. L.keywords.wildfire.text) <= 60
    and #("Stoke: " .. L.keywords.stoke.text) <= 60)
  local kw = ns.Widgets.cardKeywords(ns.Cards.greater_fire_protection_potion)
  local hasDouse = false
  for _, k in ipairs(kw) do if k.key == "douse" then hasDouse = true end end
  check("Greater Fire Protection Potion : mot Douse expliqué au survol", hasDouse)

  -- 2. Boss
  exp, ns = steppesRun("warrior", "boss")
  c, v = exp.combat, T.V()
  check("boss : Grark Lorkrub, Wildfire 4, crans de phase (50 %, 25 %)", c and c.enemies[1].id == "grark_lorkrub"
    and c.zs.steppes.left == 4 and #ns.Combat.phaseMarks(c.enemies[1]) == 2)
  snap("zone-steppes-boss", true)
  check("décor du boss : Blackrock Stronghold peint", ns.Scene.scene == "steppes_boss", tostring(ns.Scene.scene))

  -- 3. Élites (modèles déclarés, médaillons de repli)
  local Art = ns.Art
  local missing = {}
  for id, d in pairs(ns.Enemies) do
    local own = false
    for _, list in pairs(ns.Encounters.steppes) do
      if type(list) == "table" then
        for _, g in ipairs(list) do
          if type(g) == "table" then for _, sp in ipairs(g) do if ns.Combat.specId(sp) == id then own = true end end end
        end
      end
    end
    if (own or id == "dark_iron_land_mine" or id == "ember_worg") and not (Art.enemies[id] and Art.enemies[id].icon) then
      missing[#missing + 1] = id
    end
  end
  check("ennemis des Steppes : modèle et médaillon de repli déclarés", #missing == 0, table.concat(missing, ", "))
  missing = {}
  for id, ev in pairs(ns.Events) do
    if (ev.zone == "steppes" or id == "wanted_poster") and not (Art.npcs[ev.npc] and Art.npcs[ev.npc].icon) then
      missing[#missing + 1] = id
    end
  end
  check("personnages des rencontres : modèle ou médaillon déclarés", #missing == 0, table.concat(missing, ", "))

  -- 4. Rencontres : décor de la zone, personnage
  for _, t in ipairs({ { "marshal_maxwell", "steppes_camp" }, { "yuka_ribbly", "steppes_shop" },
      { "cyrus_taste_of_flame", "steppes_hill" }, { "ragged_john", "steppes_road" }, { "wanted_poster", "steppes_camp" } }) do
    exp, ns = steppesRun("rogue", nil, T.SEED + 5, nil)
    exp.node, exp.phase = exp.map.start[1], "map"
    ns.Expedition.openEvent(exp, t[1])
    ns.UI.refresh()
    H.settle()
    check("rencontre " .. t[1] .. " : décor " .. t[2], ns.Scene.scene == t[2], tostring(ns.Scene.scene))
    if t[1] == "marshal_maxwell" or t[1] == "wanted_poster" then snap("zone-steppes-event-" .. t[1], true) end
  end

  -- 5. Décors peints
  local Sc = ns.Scene
  local KEYS = { "steppes_road", "steppes_hill", "steppes_camp", "steppes_shop", "steppes_night", "steppes_boss" }
  local lvOk, counts = true, {}
  for _, key in ipairs(KEYS) do
    Sc.set({ scene = key, board = true })
    local g = Sc.paints[key]
    counts[#counts + 1] = key .. " " .. (g and #g or 0)
    if not g or #g < 100 or #g > 900 then lvOk = false end
    for _, t in ipairs(g or {}) do
      local layer, sub = rawget(t, "_layer"), rawget(t, "_sub") or 0
      if not ((layer == "BACKGROUND" and sub >= -8 and sub <= 7) or (layer == "BORDER" and sub >= -8 and sub < 0)) then
        lvOk = false
      end
    end
    if SNAP then R.svg(H, Sc.decor, SNAP .. "/decor-" .. key .. ".svg", key) end
  end
  check("Steppes : six décors peints, couches du client, 100 à 900 régions", lvOk, table.concat(counts, ", "))
  local pal = Art.palettes.steppes
  local sky, field = Art.hex(pal.sky[3]), Art.hex(pal.fieldsNear[1])
  check("palette : horizon rouge-orangé (rouge > vert > bleu), sol de cendres sombre",
    sky[1] > sky[2] and sky[2] > sky[3] and field[1] + field[2] + field[3] < 1)
  local grad, soft, rot = 0, 0, 0
  for _, t in ipairs(Sc.paints.steppes_road) do
    local calls = rawget(t, "_calls")
    if calls.SetGradient then grad = grad + 1 end
    if rawget(t, "_texture") == Sc.SHADOW then soft = soft + 1 end
    if calls.SetRotation then rot = rot + 1 end
  end
  check("route : dégradés, lueurs fondues (lave, fumées, brume), crêtes et coulées tournées",
    grad >= 3 and soft >= 30 and rot >= 30, grad .. " / " .. soft .. " / " .. rot)
end
