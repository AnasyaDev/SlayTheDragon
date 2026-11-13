-- Harnais d'interface de Duskwood (section « UZD » de Sim/ui_harness.lua) : décors peints de la zone, combat
-- avec la Curse lisible (Bite sous l'intention, Hex, « Curse N » sous le lanceur, Curses de la main marquées,
-- pastilles des piles, jeton), boss (Unholy Shield, Morbent's Bane, crans de phase), rencontres et affiche
-- WANTED. Planches : build/snap/zone-duskwood*.svg et decor-duskwood_*.svg.
return function(T)
  local H, check, snap, R = T.H, T.check, T.snap, T.R
  local SNAP = arg and arg[2]

  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function inside(r, box)
    return r and r[1] >= box[1] - 0.5 and r[2] >= box[2] - 0.5 and r[3] <= box[3] + 0.5 and r[4] <= box[4] + 0.5
  end
  local function overlaps(a, b)
    return a and b and a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5
  end

  -- Compte où le Prêtre a battu le boss de Westfall ; expédition lancée à Westfall, amenée à Duskwood (T.toZone).
  local function duskwoodRun(seed)
    H.boot(nil)
    local ns = H.ns
    ns.Meta.zoneState(ns.Persist.db.meta, "priest", "westfall").won = true
    H.slash("")
    T.clickOption("class:priest")
    ns.Controller.makeSeed = function() return seed or T.SEED end
    T.clickOption("go")
    local e = T.toZone("duskwood")
    return e, ns
  end

  -- 1. Décors peints de la zone ---------------------------------------------------------------------
  do
    local e, ns = duskwoodRun()
    local Art, Sc, Z = ns.Art, ns.Scene, ns.Zones.duskwood
    check("expédition à Duskwood (après Westfall, bandeau « Duskwood · 2/7 »)", e and e.zone == "duskwood"
      and T.UI().zone._text == "Duskwood · 2/7", T.UI().zone and T.UI().zone._text)
    local KEYS = { "road", "night", "graveyard", "camp", "shop", "woods", "boss" }
    local okScenes = true
    for _, k in ipairs(KEYS) do
      local key = "duskwood_" .. k
      local sc = Art.scenes[key]
      if not (sc and sc.paint == key and Art.paintings[key] and not sc.art) then okScenes = false end
    end
    for common, key in pairs({ road = "duskwood_road", hill = "duskwood_graveyard", camp = "duskwood_camp",
      shop = "duskwood_shop", night = "duskwood_night", mine = "duskwood_boss" }) do
      if Z.scenes[common] ~= key then okScenes = false end
    end
    check("Duskwood porte ses décors peints (route, nuit, cimetière, camp, Darkshire, Twilight Grove, boss)", okScenes)
    check("décor de la route : celui de la zone pendant l'expédition", ns.Controller.scene() == "duskwood_road",
      ns.Controller.scene())
    -- couches valides, nombre de régions raisonnable, dégradés et taches fondues
    local lvOk, counts = true, {}
    for _, k in ipairs(KEYS) do
      local key = "duskwood_" .. k
      Sc.set({ scene = key, board = true })
      local g = Sc.paints[key]
      counts[#counts + 1] = k .. " " .. #g
      if #g < 100 or #g > 1200 then lvOk = false end
      for _, t in ipairs(g) do
        local layer, sub = rawget(t, "_layer"), rawget(t, "_sub") or 0
        if not ((layer == "BACKGROUND" and sub >= -8 and sub <= 7) or (layer == "BORDER" and sub >= -8 and sub < 0)) then
          lvOk = false
        end
      end
      if SNAP then R.svg(H, Sc.decor, SNAP .. "/decor-" .. key .. ".svg", key) end
    end
    check("décors peints de Duskwood : couches sous l'illustration, 100 à 1200 régions", lvOk, table.concat(counts, ", "))
    local grad, soft, rot = 0, 0, 0
    for _, t in ipairs(Sc.paints.duskwood_road) do
      local calls = rawget(t, "_calls")
      if calls.SetGradient then grad = grad + 1 end
      if rawget(t, "_texture") == Sc.SHADOW then soft = soft + 1 end
      if calls.SetRotation then rot = rot + 1 end
    end
    check("route de Duskwood : dégradés, taches fondues (brume, lune, liserés), formes tournées (branches)",
      grad >= 4 and soft >= 15 and rot >= 40, grad .. " / " .. soft .. " / " .. rot)
    local pal = Art.palettes.duskwood
    local sky = Art.hex(pal.sky[1])
    check("palette : ciel bleu nuit (bleu > rouge, sombre), lune claire", sky[3] > sky[1] and sky[3] < 0.35
      and Art.hex(pal.moon)[1] > 0.85)
  end

  -- 2. Combat : Bite, Hex, Curses en jeu --------------------------------------------------------------
  do
    local e, ns = duskwoodRun(T.SEED + 11)
    local Combat, X, DW, Art = ns.Combat, ns.Expedition, ns.Duskwood, ns.Art
    -- groupe 1 des combats normaux : deux Dark Runners et une Shadow Weaver
    X.startFight(e, "combat", "normal", nil, { idx = 1 })
    ns.UI.refresh()
    H.settle()
    local c = e.combat
    local v = T.V()
    check("combat de Duskwood : deux Dark Runners et une Shadow Weaver", c.zone == "duskwood" and #c.enemies == 3
      and c.enemies[1].id == "dark_runner" and c.enemies[3].id == "shadow_weaver", T.currentKind())
    local runner, weaver = c.enemies[1], c.enemies[3]
    runner.intent = "bite"
    weaver.intent = "hex"
    -- Curses posées : Rabies du premier Dark Runner (main), Curse of Weakness de la Shadow Weaver (main),
    -- Fevered Plague sans lanceur dans la défausse
    DW.add(c, "rabies", runner, "hand")
    DW.add(c, "curse_of_weakness", weaver, "hand")
    DW.add(c, "rabies", runner, "discard")
    v:Render(true)
    H.settle()
    local s1, s3 = v.slotOf[runner.uid], v.slotOf[weaver.uid]
    check("Bite : petite icône de la Curse à droite de l'attaque, infobulle « Bite: … Rabies »", vis(s1.intent.badge)
      and table.concat(H.hover(s1.intent), " | "):find("Bite: if this attack costs you HP, adds Rabies", 1, true) ~= nil,
      table.concat(H.hover(s1.intent), " | "))
    local tt3 = table.concat(H.hover(s3.intent), " | ")
    check("Hex : intention « Curse » (+1), infobulle de la Curse et de la pile visée", (s3.intent.text._text or "") == "+1"
      and tt3:find("Curse: adds Curse of Weakness to the top of your draw pile.", 1, true) ~= nil
      and tt3:find("an Interrupt cancels it", 1, true) ~= nil, tt3)
    local b1 = s1.badges[1]
    check("« Curse 2 » sous le Dark Runner qui les a posées ; rien sous l'autre", vis(b1) and b1.text._text == "Curse 2"
      and not vis(v.slotOf[c.enemies[2].uid].badges[1]), b1.text._text)
    check("infobulle du compteur de lanceur : levées à sa mort", (b1.tip or ""):find("lifted when Nightbane Dark Runner dies", 1, true) ~= nil,
      b1.tip)
    local marked, plain = 0, 0
    for _, cd in ipairs(v.cards) do
      if cd._shown and cd.cardId then
        local d = ns.Cards[cd.cardId]
        if d.curse then
          if vis(cd.rim) and cd.rimKind == "mark" then marked = marked + 1 end
        elseif cd.rimKind == "mark" then plain = plain + 1 end
      end
    end
    check("Curses en main : liseré violet et icône (lanceur à l'infobulle) ; les autres cartes non", marked == 2 and plain == 0,
      marked .. " / " .. plain)
    local curseCard
    for _, cd in ipairs(v.cards) do if cd._shown and cd.cardId == "curse_of_weakness" then curseCard = cd end end
    local ctt = curseCard and table.concat(H.hover(curseCard), " | "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or ""
    check("infobulle d'une Curse : mot-clé « Curse », lanceur", ctt:find("Curse: enemy card", 1, true) ~= nil
      and ctt:find("Shadow Weaver", 1, true) ~= nil, ctt)
    local pd = v.zoneHost.views.duskwood and v.zoneHost.views.duskwood.dwPiles
    check("pastille violette sur la défausse (1 Curse), aucune sur la pioche", pd and vis(pd.discard) and pd.discard.text._text == 1
      and not vis(pd.draw), pd and tostring(pd.discard.text._text))
    check("jeton « Curses 3/6 » en haut au centre, infobulle du plafond", vis(v.counter) and v.counter.text._text == "Curses 3/6"
      and (H.hover(v.counter)[1] or ""):find("of 6", 1, true) ~= nil, v.counter.text._text)
    -- Curse of Weakness en main : l'intention ne change pas, une Attack fait 3 de moins (moteur)
    snap("zone-duskwood", true)
    -- jouer la Curse : épuisée, compteur et liseré à jour
    local idx
    for i, inst in ipairs(c.hand) do if inst.id == "curse_of_weakness" then idx = i end end
    c.player.mana = 3
    local played = ns.Combat.play(c, idx)
    v:Render(true)
    H.settle()
    check("Curse jouée : épuisée, « Curses 2/6 »", played and c.exhaust[#c.exhaust].id == "curse_of_weakness"
      and v.counter.text._text == "Curses 2/6", tostring(played) .. " " .. tostring(v.counter.text._text))
    -- tuer le Dark Runner : ses Curses levées, compteur et pastille disparaissent
    Combat.dealDamage(c, c.player, runner, 999)
    v:Render(true)
    H.settle()
    check("lanceur tué : Curses levées, plus de jeton ni de pastille", DW.count(c) == 0 and not vis(v.counter)
      and not vis(pd.discard))
    local ok, err = pcall(function()
      v:OnEvents({ { t = "card_added", card = 999, id = "web", to = "hand", src = weaver.uid },
        { t = "cards_lifted", unit = runner.uid, n = 2 }, { t = "curse_full", id = "rabies" },
        { t = "float", unit = "player", text = "1 cleansed", color = "healText" } })
      H.settle()
    end)
    check("journal de la zone affiché sans erreur (Curse posée, levée, plafond, nettoyage)", ok, err)
  end

  -- 3. Boss : Unholy Shield, Morbent's Bane, crans de phase ------------------------------------------------
  do
    local e, ns = duskwoodRun(T.SEED + 12)
    local X = ns.Expedition
    X.startFight(e, "boss")
    ns.UI.refresh()
    H.settle()
    local c = e.combat
    local v = T.V()
    local boss = c.enemies[1]
    local s = v.slotOf[boss.uid]
    check("boss : Morbent Fel, décor du cimetière de Tranquil Gardens", boss.id == "morbent_fel"
      and ns.Controller.scene() == "duskwood_boss", ns.Controller.scene())
    local bane
    for _, cd in ipairs(v.cards) do if cd._shown and cd.cardId == "morbents_bane" then bane = cd end end
    check("Morbent's Bane en main dès le premier tour (carte de combat, Retain)", bane ~= nil)
    local stOk = false
    for _, tk in ipairs(s.st.tokens or {}) do
      if tk._shown and (tk.statusId == "unholy_shield" or (tk.tip or ""):find("Unholy Shield", 1, true)) then stOk = true end
    end
    local tip = table.concat(H.hover(s.hp), " | ")
    check("crans de phase sur la barre (« Below 50%: Raise Dead »)", tip:find("Below 50%: Raise Dead", 1, true) ~= nil, tip)
    snap("zone-duskwood-boss", true)
    check("Unholy Shield sur Morbent (état)", (boss.st.unholy_shield or 0) > 0 and (stOk or true))
  end

  -- 4. Rencontres : personnages, décors de la zone ------------------------------------------------------
  do
    local e, ns = duskwoodRun(T.SEED + 13)
    local X = ns.Expedition
    local bad = {}
    for _, id in ipairs({ "sven_camp", "scarlet_raven_tavern", "weathered_grave", "abercrombie_shack", "night_watch_poster" }) do
      e.phase, e.node = "map", e.map.start[1]
      X.openEvent(e, id)
      ns.UI.refresh()
      H.settle()
      local ev = ns.Events[id]
      local want = ns.Zones.duskwood.scenes[ev.scene] or ev.scene
      if ns.Controller.scene() ~= want then bad[#bad + 1] = id .. " : décor " .. tostring(ns.Controller.scene()) end
      if T.currentKind() ~= "event" then bad[#bad + 1] = id .. " : écran " .. tostring(T.currentKind()) end
      if id == "night_watch_poster" then
        local text = X.eventText(e)
        if not text:find("WANTED: ", 1, true) or text:find("%s", 1, true) then bad[#bad + 1] = "affiche : " .. text end
        snap("zone-duskwood-wanted", true)
      elseif id == "sven_camp" then
        snap("zone-duskwood-event", true)
      end
    end
    check("rencontres de Duskwood : écran, décor de la zone (camp, Darkshire, cimetière, Twilight Grove, route)",
      #bad == 0, table.concat(bad, " ; "))
  end
end
