-- Harnais de l'interface de Blackrock Mountain (section « UZB » de Sim/ui_harness.lua) : accueil (zone
-- ouverte, titre « Dragonslayer »), écran Progress (titre), combat avec la mécanique visible (crans de
-- phase, infobulle, ouverture remplacée et badge, ouverture différée « Next: »), règles de phase en
-- badges (Invincible, Shadow of the Throne), compteur et phases du combat final, Class Call, rencontres
-- (décor, personnage), Grim Guzzler, décors peints de la zone. Planches : build/snap/zone-blackrock*.svg
-- et decor-blackrock_*.svg.
local function body(T)
  local H, check, snap = T.H, T.check, T.snap
  local clickOption, EXP, V, UI, R = T.clickOption, T.EXP, T.V, T.UI, T.R

  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function tip(o) return table.concat(H.hover(o), " | ") end

  -- Compte vétéran : le Prêtre a gagné les six premières zones (Blackrock ouverte), niveau 7, Nefarian vaincu.
  H.boot(nil)
  local ns = H.ns
  local meta = ns.Persist.db.meta
  for i = 1, 6 do
    local z = ns.Zone.ORDER[i]
    meta.zones[z] = true
    local zs = ns.Meta.zoneState(meta, "priest", z)
    zs.won, zs.keyMax, zs.bestKey = true, 5, 5
  end
  ns.Meta.classState(meta, "priest").xp = ns.Meta.XP_LEVELS[7]
  meta.flags["dragonslayer:priest"] = true
  H.slash("")
  clickOption("class:priest")
  local o = T.option("zone:blackrock")
  check("accueil : Blackrock Mountain ouverte pour le Prêtre (six zones gagnées)", o and not o.disabled, o and o.reason)
  clickOption("zone:blackrock")
  local st = UI().current
  check("accueil : titre sous l'icône de la classe, « Priest — Dragonslayer »",
    st.className and st.className._text == "Priest — Dragonslayer", st.className and st.className._text)
  snap("zone-blackrock-accueil", true)
  -- niveau 7 sans Nefarian : « Veteran »
  meta.flags["dragonslayer:priest"] = nil
  UI().refresh()
  check("accueil : niveau 7 sans victoire contre Nefarian, « Priest — Veteran »",
    UI().current.className._text == "Priest — Veteran", UI().current.className._text)
  meta.flags["dragonslayer:priest"] = true
  UI().refresh()
  -- Écran Progress : titre au-dessus de la barre de niveau
  clickOption("ui:progress")
  local cp = UI().current
  check("Progress : « Priest — Dragonslayer » sous la barre de niveau", T.currentKind() == "classProgress"
    and cp.bar and cp.bar.detail._text == "Priest — Dragonslayer" and vis(cp.bar.detail), cp and cp.bar and tostring(cp.bar.detail._text))
  snap("zone-blackrock-progress", true)
  clickOption("ui:back")
  clickOption("zone:blackrock")

  -- Expédition à Blackrock ; combat de la route sur le Molten Span
  ns.Controller.makeSeed = function() return T.SEED end
  clickOption("go")
  -- départ : bibelot au choix (zone 3 gagnée par le compte) passé
  if T.option("skipStartRelic") then clickOption("skipStartRelic") end
  local exp = EXP()
  check("expédition à Blackrock Mountain", exp and exp.zone == "blackrock", exp and exp.zone)
  local id = exp.map.start[1]
  exp.map.nodes[id].kind = "combat"
  clickOption("path:" .. id)
  H.settle()
  local Combat = ns.Combat
  local c = exp.combat
  check("combat : décor peint du Molten Span (zone)", ns.Scene.scene == "blackrock_span" and ns.Scene.entry.paint == "blackrock_span",
    tostring(ns.Scene.scene))
  -- groupe imposé : Guardsman et Blazing Fireguard
  ns.Cards.uzb_hit = { id = "uzb_hit", name = "Test Hit", cost = 0, type = "attack", target = "enemy",
    effects = { { "damage", 10 } }, text = "Deal 10." }
  for _, e in ipairs(c.enemies) do e.dead = true end
  local g = Combat.spawn(c, { "anvilrage_guardsman", hp = 40 })
  local f = Combat.spawn(c, { "blazing_fireguard", hp = 40 })
  g.intent, f.intent = "strike", "lash"
  c.hand[1] = ns.Card.new("uzb_hit", false, 990)
  local v = V()
  v:Render(true)
  H.settle()
  local sg = v.slotOf[g.uid]
  local m1 = sg and sg.marks[1]
  check("cran de phase à 50 % sur la barre du Guardsman", m1 and vis(m1) and not vis(sg.marks[2]))
  local t = sg and tip(sg.hp) or ""
  check("infobulle du cran : « Below 50%: Shield Wall. Opens with Shield Wall. »",
    t:find("Below 50%: Shield Wall. Opens with Shield Wall.", 1, true) ~= nil, t)
  -- franchir pendant le tour : l'ouverture remplace l'intention, badge d'ouverture
  g.hp = 25
  local gi
  for i, e in ipairs(c.enemies) do if e == g then gi = i end end
  ns.Controller.act({ "play", 1, gi })
  H.settle()
  v:Render(true)
  check("ouverture tout de suite : intention « Shield Wall », badge « Opening move of its new phase. »",
    g.intent == "shield_wall" and vis(sg.intent.badge) and tip(sg.intent):find("Opening move of its new phase.", 1, true) ~= nil,
    g.intent .. " / " .. tip(sg.intent))
  -- franchir après le tour : ouverture différée, en gris sous l'intention
  Combat.forceIntent(c, f, "nova", { now = false, label = "Next" })
  v:Render(true)
  local sf = v.slotOf[f.uid]
  check("ouverture différée en gris : « Next: Fire Nova … »", vis(sf.next) and (sf.next._text or ""):find("^Next: Fire Nova") ~= nil,
    tostring(sf.next._text))
  Combat.applyStatus(c, f, "fire_shield", 2)
  v:Render(true)
  H.settle()
  snap("zone-blackrock", true)

  -- Élite : Panzor (badge Invincible)
  for _, e in ipairs(c.enemies) do e.dead = true end
  local pz = Combat.spawn(c, "panzor")
  pz.intent = "pulverize"
  v:Render(true)
  H.settle()
  local sp = v.slotOf[pz.uid]
  local b1 = sp and sp.badges[1]
  check("Panzor : badge « Max 6 » sous l'intention, infobulle d'Invincible",
    b1 and vis(b1) and b1.text._text == "Max 6" and (b1.tip or ""):find("Invincible", 1, true) ~= nil,
    b1 and tostring(b1.text._text))
  snap("zone-blackrock-panzor", true)

  -- Combat final (même expédition : combat de boss lancé directement)
  local e2 = exp
  e2.combat, e2.fight = nil, nil
  ns.Expedition.startFight(e2, "boss")
  UI().refresh()
  H.settle()
  local bc = e2.combat
  check("combat final : Lord Victor Nefarius et deux Drakonids, salle du trône (décor de boss)",
    bc and bc.enemies[1].id == "nefarian" and #bc.enemies == 3 and ns.Scene.scene == "blackrock_lair",
    tostring(ns.Scene.scene))
  v = V()
  v:Render(true)
  H.settle()
  local n = bc.enemies[1]
  local sn = v.slotOf[n.uid]
  local tb = sn and sn.badges[1]
  local pb = sn and sn.badges[2]
  check("combat final : badge « Phase 1/3 » sous l'intention, infobulle ; pas de compteur sur son cadre",
    pb and vis(pb) and pb.text._text == "Phase 1/3" and (pb.tip or ""):find("Below 75%", 1, true) ~= nil and not vis(v.counter),
    pb and tostring(pb.text._text))
  check("Shadow of the Throne : badge « Half » allumé tant qu'un Drakonid vit", tb and vis(tb) and tb.text._text == "Half"
    and (tb.tip or ""):find("half damage", 1, true) ~= nil)
  snap("zone-blackrock-boss", true)
  -- phase 2 : Nefarian, Class Call
  n.hp = 80
  bc.hand[1] = ns.Card.new("uzb_hit", false, 991)
  ns.Controller.act({ "play", 1, 1 })
  H.settle()
  v:Render(true)
  local tc = tip(sn.intent)
  check("phase 2 : nom « Nefarian », intention Class Call, son état expliqué (Corrupted Healing)",
    ns.Combat.enemyName(n) == "Nefarian" and n.intent == "class_call"
      and tc:find("Corrupted Healing", 1, true) ~= nil and sn.badges[1].text._text == "Phase 2/3", tc)
  check("Throne terminé : plus de badge « Half »", not (sn.badges[1] and vis(sn.badges[1]) and sn.badges[1].text._text == "Half"))
  snap("zone-blackrock-nefarian", true)

  -- Rencontres : décor de la zone, personnage
  local function eventScreen(eid, name)
    local x = EXP()
    x.combat, x.fight = nil, nil
    x.node, x.phase = x.map.start[1], "map"
    ns.Expedition.openEvent(x, eid)
    UI().refresh()
    H.settle()
    local ev = ns.Events[eid]
    local want = ns.Zones.blackrock.scenes[ev.scene]
    check("rencontre " .. eid .. " : écran, décor " .. tostring(want), T.currentKind() == "event" and ns.Scene.scene == want,
      tostring(ns.Scene.scene))
    snap(name, true)
  end
  eventScreen("dark_iron_legacy", "zone-blackrock-rencontre")
  eventScreen("jail_break", "zone-blackrock-prison")
  eventScreen("grim_guzzler", "zone-blackrock-taverne")
  eventScreen("lord_victor_nefarius", "zone-blackrock-spire")

  -- Décors peints de la zone (planches)
  local Sc = ns.Scene
  local bad = {}
  for _, k in ipairs({ "span", "prison", "spire", "tavern", "forge", "lair" }) do
    local key = "blackrock_" .. k
    Sc.set({ scene = key, board = true })
    local gg = Sc.paints[key]
    if not (gg and gg[1] and gg[1]._shown and not Sc.art._shown) then bad[#bad + 1] = key .. " non peint" end
    for _, tx in ipairs(gg or {}) do
      local layer, sub = rawget(tx, "_layer"), rawget(tx, "_sub") or 0
      if not ((layer == "BACKGROUND" and sub >= -8 and sub <= 7) or (layer == "BORDER" and sub >= -8 and sub < 0)) then
        bad[#bad + 1] = key .. " niveau " .. tostring(layer) .. " " .. tostring(sub)
        break
      end
    end
    if #gg > 2600 then bad[#bad + 1] = key .. " : " .. #gg .. " régions" end
    if R and T.root and H then
      local SNAPDIR = arg and arg[2]
      if SNAPDIR then R.svg(H, Sc.decor, SNAPDIR .. "/decor-" .. key .. ".svg", key) end
    end
  end
  check("six décors peints de la zone (peintre « cavern »), couches sous l'illustration, régions raisonnables",
    #bad == 0, table.concat(bad, " ; "))
  local zs = ns.Zones.blackrock.scenes
  check("la zone porte ses décors (route, nuit, marchand, boss…)", zs.road == "blackrock_span" and zs.night == "blackrock_forge"
    and zs.shop == "blackrock_tavern" and zs.mine == "blackrock_lair")
end

-- erreur Lua : affichée et comptée comme un échec (le harnais continue)
return function(T)
  local ok, err = xpcall(function() body(T) end, debug.traceback)
  if not ok then T.check("UZB : section sans erreur Lua", false, err) end
end
