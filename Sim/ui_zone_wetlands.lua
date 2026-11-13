-- Harnais d'interface des Wetlands (section « UZW » de Sim/ui_harness.lua) : décors peints de la zone, combat
-- avec la meute (primes sous les ennemis, chef, dispersion), Modr (Charge), Dragonmaw Centurion (armure),
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
    T.clickOption("zone:wetlands")
    H.ns.Controller.makeSeed = function() return seed or T.SEED end
    T.clickOption("go")
    local e = T.EXP()
    -- choix de départ (épique, bibelot) : passés
    for _ = 1, 3 do
      if e.phase ~= "start" then break end
      local ok = pcall(T.clickOption, "skipEpic")
      if not ok then pcall(T.clickOption, "skipStartRelic") end
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
end
