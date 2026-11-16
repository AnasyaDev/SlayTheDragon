-- Harnais d'interface des Wetlands (section « UZW » de Sim/ui_harness.lua) : décors peints de la zone, combat
-- avec la meute (Pack dans la fiche de l'ennemi, chef, dispersion), Modr (compteur de Charge), Dragonmaw Centurion,
-- boss Nek'rosh (phases), rencontres, case du Gryphon Master. Planches : build/snap/zone-wetlands*.svg et
-- build/snap/decor-wetlands_*.svg (rsvg-convert pour les PNG).
return function(T)
  local H, check, snap, R = T.H, T.check, T.snap, T.R
  local SNAP = arg and arg[2]

  -- Compte où le Prêtre (ou la classe cl) a gagné Westfall et Duskwood : les Wetlands lui sont ouvertes.
  local function meta(cl)
    local won = { won = true, keyMax = 5, bestKey = 4 }
    return { version = 5, meta = { runs = 2, zones = { westfall = true, duskwood = true }, flags = {},
      classes = { [cl] = { xp = 4000, runs = 2, wins = 2, zones = { westfall = won, duskwood = won } } } } }
  end

  -- Expédition des Wetlands pilotée par l'interface ; premier nœud forcé au genre kind.
  local function wetRun(cl, kind, seed)
    H.boot(meta(cl or "priest"))
    H.slash("")
    T.clickOption("class:" .. (cl or "priest"))
    H.ns.Controller.makeSeed = function() return seed or T.SEED end
    T.clickOption("go")
    local e = T.toZone("wetlands")
    -- choix de départ (bibelot) : passé
    if e.phase == "start" then
      pcall(T.clickOption, "skipStartRelic")
      e = T.EXP()
    end
    if kind then
      local id = e.map.start[1]
      e.map.nodes[id].kind = kind
      e.gold = 300
      T.clickOption("path:" .. id)
      H.settle()
    end
    return T.EXP()
  end

  local ns = H.ns
  -- 1. Décors : huit décors peints portés par la zone, sans illustration
  do
    local e = wetRun("priest", nil)
    ns = H.ns
    local Art, Sc, Z = ns.Art, ns.Scene, ns.Zones.wetlands
    check("Wetlands : expédition ouverte dans la zone", e and e.zone == "wetlands", e and e.zone)
    local keys = { road = "wetlands_road", hill = "wetlands_hill", camp = "wetlands_camp", shop = "wetlands_shop",
      night = "wetlands_night", mine = "wetlands_gates", coast = "wetlands_coast", ruins = "wetlands_ruins" }
    local bad = {}
    for common, key in pairs(keys) do
      local sc = Art.scenes[key]
      if not (Z.scenes[common] == key and sc and sc.paint == key and not sc.art and Art.paintings[key]) then
        bad[#bad + 1] = common
      end
    end
    check("Wetlands : huit décors peints (route, colline, camp, marché, nuit, boss, quais, ruines)", #bad == 0,
      table.concat(bad, ", "))
    check("décor de la zone choisi par le contrôleur (carte : route des marais)",
      ns.Controller.zoneScene("road") == "wetlands_road" and ns.Controller.zoneScene("mine") == "wetlands_gates")
    local counts, lvOk = {}, true
    for _, key in pairs(keys) do
      Sc.set({ scene = key, board = true })
      local g = Sc.paints[key]
      counts[#counts + 1] = key .. " " .. #g
      if #g < 150 or #g > 1400 then lvOk = false end
      for _, t in ipairs(g) do
        local layer, sub = rawget(t, "_layer"), rawget(t, "_sub") or 0
        if not ((layer == "BACKGROUND" and sub >= -8 and sub <= 7) or (layer == "BORDER" and sub >= -8 and sub < 0)) then
          lvOk = false
        end
      end
      check("décor " .. key .. " : seul paysage affiché", g[1] and g[1]._shown and not Sc.art._shown)
      if SNAP then R.svg(H, Sc.decor, SNAP .. "/decor-" .. key .. ".svg", key) end
    end
    table.sort(counts)
    check("décors des Wetlands : couches sous l'illustration, 150 à 1400 régions", lvOk, table.concat(counts, ", "))
    local grad, soft = 0, 0
    for _, t in ipairs(Sc.paints.wetlands_road) do
      if rawget(t, "_calls").SetGradient then grad = grad + 1 end
      if rawget(t, "_texture") == Sc.SHADOW then soft = soft + 1 end
    end
    check("route des marais : dégradés et taches fondues (brume, mares, houppiers)", grad >= 2 and soft >= 40,
      grad .. " / " .. soft)
    -- Westfall garde ses décors
    check("Westfall inchangée : décors communs = ceux de Westfall", Art.scenes.road == Art.scenes.westfall_road)
  end

  -- Combat d'un groupe choisi (pool, idx) dans une expédition des Wetlands, rendu par l'écran de combat.
  local function fight(cl, kind, pool, idx)
    local e = wetRun(cl or "priest", nil)
    ns = H.ns
    e.node, e.phase = e.map.start[1], "map"
    ns.Expedition.startFight(e, kind, pool, nil, { idx = idx })
    ns.UI.refresh()
    H.settle()
    local v = T.V()
    v:Render(true)
    H.settle()
    return e, e.combat, v
  end
  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  -- fiche d'un ennemi (survol du « ? » de son cadre), lignes réunies ; vide s'il n'a pas de « ? »
  local function sheet(v, en)
    local s = v.slotOf[en.uid]
    if not (s and vis(s.ask)) then return "", s end
    return table.concat(H.hover(s.ask), " | "), s
  end

  -- 2. Meute Mosshide : Pack dans la fiche de chaque membre (prime, chef, dispersion), aucune ligne sur le modèle
  do
    local e, c, v = fight("priest", "combat", "normal", 1)
    check("combat des Wetlands : Brute, Mystic, Alpha à l'écran", T.currentKind() == "combat"
      and c.enemies[1].id == "mosshide_brute" and c.enemies[3].id == "mosshide_alpha", T.currentKind())
    local WL = ns.Wetlands
    local t1, s1 = sheet(v, c.enemies[1])
    local t2 = sheet(v, c.enemies[2])
    local t3 = sheet(v, c.enemies[3])
    local nb = ns.Enemies.mosshide_brute.pack[2]
    check("fiche de chaque membre : Pack de la Brute (Strength N), du Mystic (heal), Pack Leader de l'Alpha",
      t1:find("^Mosshide Brute | ") ~= nil
        and t1:find("Pack|r — when it dies, the other members of its pack gain Strength " .. nb .. ".", 1, true) ~= nil
        and t1:find("Packmates that die at the same time gain nothing.", 1, true) ~= nil
        and t2:find("Pack|r — when it dies, the other members of its pack heal %d+%.") ~= nil
        and t3:find("Pack Leader|r — when it dies, its pack scatters", 1, true) ~= nil, t1 .. " // " .. t2 .. " // " .. t3)
    check("Pack : aucun compteur gardé sous le cadre (fiche seule)", not vis(s1.chips[1]))
    T.snap("zone-wetlands", true)
    -- le chef tombe : meute dispersée, état dans la fiche
    c.enemies[3].hp = 1
    ns.Combat.dealDamage(c, c.player, c.enemies[3], 5)
    v:Render(true)
    H.settle()
    local d1 = sheet(v, c.enemies[1])
    check("dispersion : « Scattered: it no longer gives or gains Pack bonuses. » dans la fiche",
      d1:find("Scattered: it no longer gives or gains Pack bonuses.", 1, true) ~= nil and WL.scattered(c.enemies[1]), d1)
    -- animation de prime : un événement « pack » passe par la vue sans erreur
    local ok, err = pcall(function()
      v:OnEvents({ { t = "pack", src = c.enemies[3].uid, dst = c.enemies[1].uid, bonus = "force", n = 1, got = 1 },
        { t = "float", unit = c.enemies[1].uid, text = "+1 Strength", color = "attackText" } })
      H.settle()
    end)
    check("flèche de prime et texte flottant : joués sans erreur", ok, err)
  end

  -- 3. Élites : Modr (Charge prévue), Centurion (armure en jeton), Sarltooth
  do
    local e, c, v = fight("mage", "elite", "elite", 2)
    local m = c.enemies[1]
    local tm, sm = sheet(v, m)
    local ch = sm.chips[1]
    local red = ch and ch.text._calls.SetTextColor
    local ar = ns.Art.C.attackText
    check("Modr : compteur gardé sous le cadre « 0/15 » en rouge (il chargera), Earthen Charge dans la fiche",
      ch and vis(ch) and ch.text._text == "0/15" and red and math.abs(red[1] - ar[1]) < 1e-6
        and tm:find("Earthen Charge|r — at the start of its turn", 1, true) ~= nil
        and tm:find("Lost since its last turn: 0 of 15. It gains a Charge", 1, true) ~= nil,
      tostring(ch and ch.text._text) .. " // " .. tm)
    check("Modr : infobulle du compteur = fiche", ch and table.concat(H.hover(ch), " | ") == tm)
    T.snap("zone-wetlands-modr", true)
    local e2, c2, v2 = fight("rogue", "elite", "elite", 3)
    local ce = c2.enemies[2]
    local tc = sheet(v2, ce)
    check("Dragonmaw Centurion : Wyrmscale Armor prête (jeton, fiche « Ready this turn. »), Pack sans prime, Elite",
      ce.st.wyrmscale == 1 and tc:find("^Dragonmaw Centurion | Elite | ") ~= nil
        and tc:find("Pack|r — gains the bonus of each packmate that dies, but gives none.", 1, true) ~= nil
        and tc:find("Wyrmscale Armor|r — ", 1, true) ~= nil and tc:find("Ready this turn.", 1, true) ~= nil, tc)
    T.snap("zone-wetlands-centurion", true)
  end

  -- 4. Boss : Nek'rosh et ses Bonewarders, cran de phase, décor des portes
  do
    local e, c, v = fight("warrior", "boss", "boss", 1)
    check("boss : Chieftain Nek'rosh, deux Bonewarders (Pack : heal N), décor des portes de Grim Batol",
      c.enemies[1].id == "nekrosh" and sheet(v, c.enemies[2]):find("its pack heal %d+%.") ~= nil
      and ns.Scene.scene == "wetlands_gates", tostring(ns.Scene.scene))
    local s = v.slotOf[c.enemies[1].uid]
    local tt = table.concat(H.hover(s.hp), " | ")
    check("boss : cran à 50 % (infobulle « Whelps »)", tt:find("Below 50%: Whelps", 1, true) ~= nil, tt)
    T.snap("zone-wetlands-boss", true)
    c.enemies[1].hp = math.floor(c.enemies[1].maxHp / 2) + 1
    ns.Combat.dealDamage(c, c.player, c.enemies[1], 3)
    v:Render(true)
    H.settle()
    local whelps = 0
    for _, en in ipairs(c.enemies) do if en.id == "crimson_whelp" and not en.dead then whelps = whelps + 1 end end
    check("boss phase 2 : deux Crimson Whelps à l'écran", whelps == 2)
    T.snap("zone-wetlands-boss2", true)
  end

  -- 5. Rencontre : Rethiel the Greenwarden (décor de la route), réponses lisibles
  do
    local e = wetRun("hunter", nil)
    ns = H.ns
    e.node, e.phase = e.map.start[1], "map"
    ns.Expedition.openEvent(e, "greenwarden")
    ns.UI.refresh()
    H.settle()
    check("rencontre des Wetlands : écran de rencontre, décor de la route des marais", T.currentKind() == "event"
      and ns.Scene.scene == "wetlands_road", tostring(T.currentKind()) .. " " .. tostring(ns.Scene.scene))
    T.snap("zone-wetlands-event", true)
  end
end
