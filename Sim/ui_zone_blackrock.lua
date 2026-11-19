-- Harnais de l'interface de Blackrock Mountain (section « UZB » de Sim/ui_harness.lua) : accueil (zone
-- ouverte, titre « Dragonslayer »), écran Progress (titre), combat avec la mécanique visible (crans de
-- phase, infobulle, ouverture remplacée et badge, ouverture différée « Next: »), règles de phase en
-- fiche de l'ennemi (Invincible, Indomitable, Shadow of the Throne, Drakonid), phases du combat final, Class Call, rencontres
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
  local o, so = T.option("zone:blackrock"), T.option("zone:steppes")
  check("accueil : campagne du Prêtre, six boss battus, Blackrock Mountain pas encore atteinte",
    o and o.status == "ahead" and so and so.status == "won" and so.farthest, o and o.status)
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
  -- Journal (« Log ») : même titre que l'accueil et Progress (Dragonslayer contre Nefarian, Veteran au niveau 7)
  clickOption("ui:meta")
  local function logDetail()
    local lb = UI().current.bars and UI().current.bars[1]
    return lb and vis(lb) and tostring(lb.detail._text) or "?"
  end
  local d = logDetail()
  check("journal : « title: Dragonslayer » (Nefarian vaincu avec la classe)", T.currentKind() == "meta"
    and d:find("title: Dragonslayer", 1, true) ~= nil, d)
  meta.flags["dragonslayer:priest"] = nil
  UI().refresh()
  d = logDetail()
  check("journal : niveau 7 sans victoire contre Nefarian, « title: Veteran » (pas Dragonslayer)",
    d:find("title: Veteran", 1, true) ~= nil and not d:find("Dragonslayer", 1, true), d)
  snap("zone-blackrock-journal", true)
  meta.flags["dragonslayer:priest"] = true
  clickOption("ui:progress")
  clickOption("ui:back")

  -- Expédition amenée à Blackrock (T.toZone : bibelot au choix du départ passé) ; combat de la route sur le
  -- Molten Span
  ns.Controller.makeSeed = function() return T.SEED end
  clickOption("go")
  local exp = T.toZone("blackrock")
  check("expédition à Blackrock Mountain", exp and exp.zone == "blackrock", exp and exp.zone)
  -- Parcours : icône du boss de la zone (Art.ui.mapBoss), plus celle de VanCleef
  local bossNode
  for _, nd in ipairs(UI().step.nodes or {}) do if nd.kind == "boss" then bossNode = nd end end
  local btex = bossNode and T.button(bossNode.id) and tostring(T.button(bossNode.id).icon._texture) or "?"
  check("parcours de Blackrock : icône de Nefarian sur le boss (pas VanCleef)", T.currentKind() == "map"
    and btex:lower():find("achievement_boss_nefarion", 1, true) ~= nil, btex)
  snap("zone-blackrock-parcours", true)
  -- les sept zones portent l'icône de leur boss (boss des groupes de la zone, icône embarquée)
  local Art, Skin = ns.Art, ns.Skin
  local WANT = { westfall = "vancleef", duskwood = "morbent_fel", wetlands = "nekrosh", stranglethorn = "jindo",
    swamp = "somnus", steppes = "grark_lorkrub", blackrock = "nefarian" }
  local badZ = {}
  for _, z in ipairs(ns.Zone.ORDER) do
    local e = Art.ui.mapBoss[z]
    local def = ns.Zones[z]
    local groups = def and ns.Encounters[def.encounters] and ns.Encounters[def.encounters].boss
    local bid = groups and groups[1] and groups[1][1]
    if not e then badZ[#badZ + 1] = z .. " : pas d'icône"
    elseif bid ~= WANT[z] or e ~= Art.enemies[bid].icon then badZ[#badZ + 1] = z .. " : " .. tostring(bid)
    elseif Skin and Skin.icons and not Skin.icons[tostring(e.tga):lower()] then badZ[#badZ + 1] = z .. " : " .. tostring(e.tga) .. " non embarquée"
    end
  end
  check("Art.ui.mapBoss : le boss de chacune des sept zones, icône embarquée", #badZ == 0, table.concat(badZ, " ; "))
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
  check("ouverture différée : marque sur la case, « Next: Fire Nova … » au survol", vis(sf.intent.plus)
    and (sf.intent.nextText or ""):find("^Next: Fire Nova") ~= nil and tip(sf.intent):find("Next: Fire Nova", 1, true) ~= nil,
    tostring(sf.intent.nextText))
  Combat.applyStatus(c, f, "fire_shield", 2)
  v:Render(true)
  H.settle()
  snap("zone-blackrock", true)

  -- Élite : Panzor (compteur et fiche d'Invincible)
  for _, e in ipairs(c.enemies) do e.dead = true end
  local pz = Combat.spawn(c, "panzor")
  pz.intent = "pulverize"
  v:Render(true)
  H.settle()
  local sp = v.slotOf[pz.uid]
  local b1 = sp and sp.chips[1]
  local tp = sp and vis(sp.ask) and table.concat(H.hover(sp.ask), " | ") or ""
  check("Panzor : compteur « " .. ns.Enemies.panzor.maxHit .. " » (bouclier) sous le cadre, Invincible dans la fiche",
    b1 and vis(b1) and b1.text._text == tostring(ns.Enemies.panzor.maxHit)
      and tp:find("Invincible|r — each hit deals at most " .. ns.Enemies.panzor.maxHit .. " damage to it.", 1, true) ~= nil,
    tostring(b1 and b1.text._text) .. " // " .. tp)
  check("Panzor : « Indomitable — can't be Stunned. » dans la fiche, pas de Stun Resistant",
    tp:find("Indomitable|r — can't be Stunned.", 1, true) ~= nil and not tp:find("Stun Resistant", 1, true), tp)
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
  local function sheetOf(s) return s and vis(s.ask) and table.concat(H.hover(s.ask), " | ") or "" end
  local tn = sheetOf(sn)
  check("combat final : fiche « Phase 1 of 3 — … Below 75%, Nefarian lands. », Boss ; pas de compteur sur son cadre",
    tn:find("^Lord Victor Nefarius | Boss | ") ~= nil and tn:find("Phase 1 of 3|r — Lord Victor Nefarius on his throne. Below 75%", 1, true) ~= nil
      and not vis(v.counter) and not vis(sn.chips[1]), tn)
  check("Shadow of the Throne : « Active: a Drakonid lives. » dans la fiche tant qu'un Drakonid vit",
    tn:find("Shadow of the Throne|r — takes half damage while a Drakonid lives.", 1, true) ~= nil
      and tn:find("Active: a Drakonid lives.", 1, true) ~= nil, tn)
  local td = sheetOf(v.slotOf[bc.enemies[2].uid])
  check("Drakonid : sa règle dans la fiche (moitié des dégâts, Bone Construct)", td:find("Drakonid|r — while it lives", 1, true) ~= nil, td)
  snap("zone-blackrock-boss", true)
  -- phase 2 : Nefarian, Class Call
  n.hp = math.floor(n.maxHp * 80 / 138) -- 58 % des PV (138 sur la fiche, × la dureté de la zone)
  bc.hand[1] = ns.Card.new("uzb_hit", false, 991)
  ns.Controller.act({ "play", 1, 1 })
  H.settle()
  v:Render(true)
  local tc = tip(sn.intent)
  check("phase 2 : nom « Nefarian », intention Class Call, son état expliqué (Corrupted Healing)",
    ns.Combat.enemyName(n) == "Nefarian" and n.intent == "class_call"
      and tc:find("Corrupted Healing", 1, true) ~= nil and sheetOf(sn):find("Phase 2 of 3|r — Nefarian calls on your class.", 1, true) ~= nil, tc)
  check("Throne terminé : plus de Shadow of the Throne dans la fiche", not sheetOf(sn):find("Shadow of the Throne|r", 1, true), sheetOf(sn))
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

  -- Bilan de la première victoire contre Nefarian (compte et classe) : titre de victoire, titre Dragonslayer,
  -- Rallying Cry of the Dragonslayer (docs/zones/blackrock.md § 10)
  meta.flags["dragonslayer:priest"], meta.flags.rallying_cry = nil, nil
  local x = EXP()
  x.combat, x.fight = nil, nil
  ns.Expedition.fire(x, "onCombatWon", "boss")
  x.stats.cleared, x.stats.elites, x.stats.bosses = 8, 1, 1
  x.result, x.phase = "won", "done"
  UI().refresh()
  H.settle()
  local es, pg = UI().step, UI().current
  local txt = es and es.text or ""
  check("bilan : titre « Expedition complete! » affiché, en vert", T.currentKind() == "end" and pg.title._text == "Expedition complete!"
    and vis(pg.title), pg and pg.title and tostring(pg.title._text))
  check("bilan : « The Priest earns the title Dragonslayer. »", txt:find("The Priest earns the title Dragonslayer.", 1, true) ~= nil, txt)
  check("bilan : ligne Rallying Cry (+6 PV max à l'expédition suivante)",
    txt:find("Rallying Cry of the Dragonslayer: the next expedition (any class) starts with +6 max HP.", 1, true) ~= nil, txt)
  check("bilan : aucun texte tronqué", #ns.Widgets.truncatedNow() == 0, table.concat(ns.Widgets.truncatedNow(), " ; "))
  snap("zone-blackrock-bilan", true)
end

-- erreur Lua : affichée et comptée comme un échec (le harnais continue)
return function(T)
  local ok, err = xpcall(function() body(T) end, debug.traceback)
  if not ok then T.check("UZB : section sans erreur Lua", false, err) end
end
