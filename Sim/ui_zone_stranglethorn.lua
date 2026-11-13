-- Harnais d'interface de Stranglethorn Vale (section « UZS », lancée par Sim/ui_harness.lua) : décors peints de la
-- jungle, combat avec le Hex visible (carte visée, lanceur, Death Hex, cartes Hexed), boss Jin'do, rencontres.
-- Instantanés : build/snap/zone-stranglethorn*.svg et decor-stranglethorn_*.svg (puis rsvg-convert).
return function(T)
  local H, check, snap, R = T.H, T.check, T.snap, T.R
  local SNAP = arg and arg[2]

  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function lum(hex) local c = H.ns.Art.hex(hex) return 0.3 * c[1] + 0.59 * c[2] + 0.11 * c[3] end

  -- 1. Décors : six paysages peints, portés par la zone
  do
    local ns = H.boot(nil)
    H.slash("")
    local Art, Sc, Z = ns.Art, ns.Scene, ns.Zones.stranglethorn
    local keys = { "stranglethorn_road", "stranglethorn_night", "stranglethorn_camp", "stranglethorn_coast",
      "stranglethorn_ruins", "stranglethorn_gates" }
    local mapped = {}
    for _, k in pairs(Z.scenes) do mapped[k] = true end
    local bad, counts = {}, {}
    for _, key in ipairs(keys) do
      local e = Art.scenes[key]
      if not (mapped[key] and e and not e.art and e.paint == key and Art.paintings[key] and Art.paintings[key].draw) then
        bad[#bad + 1] = key .. " : non déclaré"
      end
      Sc.set({ scene = key, board = true })
      local g = Sc.paints[key]
      if not (g and g[1] and g[1]._shown) then bad[#bad + 1] = key .. " : non peint" else
        counts[#counts + 1] = key:gsub("stranglethorn_", "") .. " " .. #g
        if #g < 150 or #g > 1000 then bad[#bad + 1] = key .. " : " .. #g .. " régions" end
        local grad, soft, rot = 0, 0, 0
        for _, t in ipairs(g) do
          local layer, sub = rawget(t, "_layer"), rawget(t, "_sub") or 0
          if not ((layer == "BACKGROUND" and sub >= -8 and sub <= 7) or (layer == "BORDER" and sub >= -8 and sub < 0)) then
            bad[#bad + 1] = key .. " : couche " .. tostring(layer) .. " " .. tostring(sub)
            break
          end
          local calls = rawget(t, "_calls")
          if calls.SetGradient then grad = grad + 1 end
          if rawget(t, "_texture") == Sc.SHADOW then soft = soft + 1 end
          if calls.SetRotation then rot = rot + 1 end
        end
        if grad < 4 or soft < 20 or rot < 30 then bad[#bad + 1] = ("%s : dégradés %d, fondus %d, tournées %d"):format(key, grad, soft, rot) end
      end
      if SNAP then R.svg(H, Sc.decor, SNAP .. "/decor-" .. key .. ".svg", key) end
    end
    check("Stranglethorn : six décors peints par la zone (route, nuit, camp, Booty Bay, ruines, Zul'Gurub), couches sous "
      .. "l'illustration, dégradés, fondus, formes tournées", #bad == 0, table.concat(bad, " ; ") .. " | " .. table.concat(counts, ", "))
    local day, night = Art.palettes.stranglethorn, Art.palettes.stranglethorn_night
    local g1 = Art.hex(day.canMid)
    check("palettes : canopée verte (vert dominant), nuit nettement plus sombre, Zul'Gurub sous un ciel rouge",
      g1[2] > g1[1] and g1[2] > g1[3] and lum(night.sky[2]) < lum(day.sky[2]) * 0.35
      and Art.hex(Art.palettes.stranglethorn_gates.sky[2])[1] > Art.hex(Art.palettes.stranglethorn_gates.sky[2])[3] * 2)
    check("décors communs remplacés : route, nuit, marchand (Booty Bay), boss (Zul'Gurub)", Z.scenes.road == "stranglethorn_road"
      and Z.scenes.night == "stranglethorn_night" and Z.scenes.shop == "stranglethorn_coast" and Z.scenes.mine == "stranglethorn_gates")
  end

  -- Combat de Stranglethorn à l'écran : une expédition ouverte, le combat remplacé par un groupe choisi.
  local function stvCombat(cl, encounter, kind, hand, relics)
    local e = T.zoneCombat(cl)
    local ns = H.ns
    local Combat = ns.Combat
    for _, id in ipairs(relics or {}) do e.relics[#e.relics + 1] = id end
    e.zone = "stranglethorn"
    e.fight.kind = kind or "combat"
    local c = Combat.new({ seed = 11, class = cl, hp = e.hp, maxHp = e.maxHp, deck = e.deck, encounter = encounter,
      zone = "stranglethorn", kind = kind or "combat", relics = e.relics, potions = { "healing_potion" } })
    if hand then
      -- main imposée (ids du deck, dans l'ordre) : le reste en pioche
      local all = {}
      for _, x in ipairs(c.hand) do all[#all + 1] = x end
      for _, x in ipairs(c.draw) do all[#all + 1] = x end
      c.hand, c.draw = {}, {}
      for _, id in ipairs(hand) do
        local got
        for i, x in ipairs(all) do if x.id == id then got = table.remove(all, i) break end end
        if not got then -- carte hors du deck de départ : instance neuve
          got = ns.Card.new(id, false, c.nextUid)
          c.nextUid = c.nextUid + 1
        end
        c.hand[#c.hand + 1] = got
      end
      for _, x in ipairs(all) do c.draw[#c.draw + 1] = x end
    end
    e.combat = c
    ns.UI.refresh()
    H.settle()
    local v = T.V()
    v:Render(true)
    H.settle()
    return e, c, v
  end

  -- 2. Combat : le Hex se lit avant de jouer
  do
    local e, c, v = stvCombat("priest", { "bloodscalp_witch_doctor", "bloodscalp_headhunter" }, "combat",
      { "smite", "penance", "pw_shield", "smite", "sw_pain" })
    local ns = H.ns
    local Combat, ST, Art = ns.Combat, ns.Stranglethorn, ns.Art
    local wd, hh = c.enemies[1], c.enemies[2]
    Combat.forceIntent(c, wd, "hex", { now = true })
    Combat.forceIntent(c, hh, "trophy", { now = true })
    v:Render(true)
    H.settle()
    check("décor de la route de la jungle pendant un combat de la zone", ns.Scene.entry == Art.scenes.stranglethorn_road,
      tostring(ns.Controller.scene()))
    local s1 = v.slotOf[wd.uid]
    check("intention Hex : icône du Hex, mot « Hex », pas de chiffre de dégâts", vis(s1.intent) and s1.intent.text._text == "Hex",
      tostring(s1.intent.text._text))
    local tt = table.concat(H.hover(s1.intent), " | ")
    check("infobulle de l'intention : Cast, carte visée en ce moment, Interrupt", tt:find("Hexes the costliest card", 1, true)
      and tt:find("Target now: Penance", 1, true) and tt:find("an Interrupt cancels it", 1, true), tt)
    local marked, markedIdx = {}, nil
    for _, cd in ipairs(v.cards) do
      if cd._shown and cd.rimKind == "mark" and vis(cd.rim) and vis(cd.markIcon) then marked[#marked + 1] = cd markedIdx = cd.index end
    end
    check("main : une seule carte marquée (liseré vert, icône du Hex), la plus chère (Penance)", #marked == 1
      and c.hand[markedIdx] and c.hand[markedIdx].id == "penance", #marked)
    local tip = marked[1] and table.concat(H.hover(marked[1]), " | ") or ""
    check("infobulle de la carte marquée : qui la hexe, comment l'éviter", tip:find("Hex: Bloodscalp Witch Doctor", 1, true)
      and tip:find("interrupt or stun", 1, true), tip)
    local b1 = s1.badges[1]
    check("sous l'intention du lanceur : la carte visée", vis(b1) and b1.text._text == "Penance", tostring(b1 and b1.text._text))
    local trophy = ns.Enemies.bloodscalp_headhunter.moves.trophy.actions[1][2]
    check("Headhunter : Take a Trophy annoncé à sa base (aucune Hexed), aucune pastille de Hex (pas un lanceur)",
      v.slotOf[hh.uid].intent.text._text == tostring(trophy) and not vis(v.slotOf[hh.uid].badges[1]),
      tostring(v.slotOf[hh.uid].intent.text._text))
    snap("zone-stranglethorn", true)
    -- la carte visée change en direct quand on joue la carte chère
    ns.Controller.act({ "play", markedIdx, 1 })
    H.settle()
    v:Render(true)
    local now
    for _, cd in ipairs(v.cards) do if cd._shown and cd.rimKind == "mark" then now = c.hand[cd.index] end end
    check("la marque se déplace quand la carte visée est jouée", now and now.id ~= "penance", now and now.id)
    -- fin de tour : une carte Hexed, compteur en haut, Take a Trophy recalculé
    ns.Controller.act({ "endTurn" })
    H.settle()
    v:Render(true)
    H.settle()
    local n = ST.hexedCount(c)
    check("après le tour ennemi : une carte Hexed, compteur « 1 Hexed » en haut", n == 1 and vis(v.counter)
      and v.counter.text._text == "1 Hexed", tostring(n) .. " / " .. tostring(v.counter.text._text))
    if hh.intent == "trophy" then
      check("Take a Trophy recalculé (+3)", v.slotOf[hh.uid].intent.text._text == tostring(ns.Enemies.bloodscalp_headhunter.moves.trophy.actions[1][2] + 3))
    end
    -- une Hexed en main : nom de la carte d'origine au-dessus
    local h
    for _, key in ipairs({ "hand", "draw", "discard" }) do
      for _, x in ipairs(c[key]) do if x.id == "hexed" then h = x end end
    end
    if h and ns.Combat.findCard(c, h) ~= "hand" then
      local key, i = ns.Combat.findCard(c, h)
      table.remove(c[key], i)
      c.hand[#c.hand + 1] = h
      v:Render(true)
      H.settle()
    end
    local hexCard
    for _, cd in ipairs(v.cards) do if cd._shown and cd.cardId == "hexed" then hexCard = cd end end
    check("carte Hexed en main : nom de la carte d'origine au-dessus, corps sobre", hexCard and hexCard.zoneTagPlate
      and vis(hexCard.zoneTagPlate.text) and hexCard.zoneTagPlate.text._text == ns.Card.def(h.orig).name)
    snap("zone-stranglethorn-hexed", true)
  end

  -- 2 bis. Zandalarian Hero Charm : texte au bandeau ; la carte gardée affiche son coût réduit au tour suivant
  do
    local e, c, v = stvCombat("priest", { "bloodscalp_headhunter" }, "combat", { "penance", "smite", "pw_shield" },
      { "zandalarian_hero_charm" })
    local ns = H.ns
    local r = ns.Relics.zandalarian_hero_charm
    local tt = table.concat(H.hover(ns.UI.relicIcons[ns.UI.RELICS_SHOWN]), " ")
    check("Hero Charm au bandeau : nom et texte (80 caractères au plus)", tt:find(r.name, 1, true) ~= nil
      and tt:find(r.text, 1, true) ~= nil and #r.text <= 80, tt)
    local pen = c.hand[1]
    local base = ns.Card.def(pen).cost
    H.click(v.endTurn)
    H.click(v.cards[1])
    H.settle()
    v:Render(true)
    H.settle()
    local shown
    for i, x in ipairs(c.hand) do if x.uid == pen.uid and v.cards[i]._shown then shown = v.cards[i].cost._text end end
    check("carte gardée par le Charm : coût affiché réduit de 1 au tour suivant (" .. (base - 1) .. ")",
      c.result or shown == tostring(base - 1), tostring(shown))
    snap("zone-stranglethorn-charm", true)
  end

  -- 3. Death Hex du Zanzil Naga, deux Hex
  do
    local e, c, v = stvCombat("mage", { "zanzil_naga", "skullsplitter_mystic" }, "combat")
    local ns = H.ns
    local s = v.slotOf[c.enemies[1].uid]
    local found
    for _, b in ipairs(s.badges) do if vis(b) and b.text._text == "Death Hex" then found = b end end
    check("Zanzil Naga : « Death Hex » sous son intention, infobulle", found ~= nil
      and (H.hover(found)[1] or ""):find("On death: hexes", 1, true) ~= nil)
    snap("zone-stranglethorn-naga", true)
  end

  -- 4. Boss : Jin'do aux portes de Zul'Gurub, totem en phase 2
  do
    local e, c, v = stvCombat("warrior", { "jindo" }, "boss")
    local ns = H.ns
    local j = c.enemies[1]
    check("boss : décor de Zul'Gurub", ns.Scene.entry == ns.Art.scenes.stranglethorn_gates, tostring(ns.Controller.scene()))
    local s = v.slotOf[j.uid]
    local tt = table.concat(H.hover(s.hp), " | ")
    check("barre de vie de Jin'do : cran à 50 % (Brain Wash)", tt:find("Below 50%: Brain Wash", 1, true) ~= nil, tt)
    j.hp = 70
    ns.Combat.dealDamage(c, c.player, j, 10)
    ns.Combat.forceIntent(c, j, "hex", { now = true })
    v:Render(true)
    H.settle()
    local hexers = 0
    for _, cd in ipairs(v.cards) do if cd._shown and cd.rimKind == "mark" then hexers = hexers + 1 end end
    check("phase 2 : Brain Wash Totem invoqué, deux cartes marquées (deux Hex)", #c.enemies == 2 and hexers == 2, hexers)
    snap("zone-stranglethorn-boss", true)
  end

  -- 5. Rencontres : Booty Bay (côte), Gurubashi Arena (groupe annoncé)
  do
    T.zoneCombat("rogue")
    local ns = H.ns
    local X = ns.Expedition
    local exp = T.EXP()
    exp.combat, exp.fight = nil, nil
    exp.zone = "stranglethorn"
    exp.phase = "map"
    X.openEvent(exp, "booty_bay_docks")
    ns.UI.refresh()
    H.settle()
    check("rencontre de Booty Bay : écran de rencontre, décor de la côte", T.currentKind() == "event"
      and ns.Scene.entry == ns.Art.scenes.stranglethorn_coast, tostring(ns.Controller.scene()))
    snap("zone-stranglethorn-event", true)
    exp.event = nil
    X.openEvent(exp, "gurubashi_arena")
    ns.UI.refresh()
    H.settle()
    local txt = X.eventText(exp)
    check("Gurubashi Arena : le groupe est nommé avant d'entrer", txt:find("Today's fighters: ", 1, true) ~= nil
      and not txt:find("%g", 1, true), txt)
    snap("zone-stranglethorn-arena", true)
  end
end
