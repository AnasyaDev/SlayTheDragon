-- Harnais de l'interface des talents (section « UTL » de Sim/ui_harness.lua ; docs/talents.md, § 11 ; écran :
-- UI/TalentView.lua, données : UI/Controller.lua). Onglet Talents de l'écran Progress : arbre neuf, arbre à 15
-- points dépensé par des clics (voie Specialization, changement gratuit, rangée 4 ouverte, refus), arbre plein,
-- classe sans arbre, remboursement confirmé ; pendant l'expédition : talents actifs dans le panneau du deck, arbre
-- en lecture seule ; départ avec Veteran's Arsenal (deux épiques, puis le bibelot) ; bilan avec niveaux et points
-- gagnés (« Spend talent points ») ; accueil (pastille, ligne de la migration v8) ; icônes des nœuds. Planches :
-- build/snap/talents-*.svg.
return function(T)
  local H, check, snap, R = T.H, T.check, T.snap, T.R
  local clickOption, button, option, UI, EXP = T.clickOption, T.button, T.option, T.UI, T.EXP
  local function kind() return UI().step and UI().step.kind end

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
  local function fmt(r) return r and ("%.0f,%.0f,%.0f,%.0f"):format(r[1], r[2], r[3], r[4]) or "nil" end
  local function tip(o) return H.hover(o) end
  local function joined(t) return table.concat(t or {}, " | ") end

  -- Compte : niveaux par classe (expérience au seuil du niveau), arbres { [classe] = { map, spec } }, zones gagnées
  -- par classe (Veteran's Arsenal : épiques proposables ; le compte les a aussi battues), version de la sauvegarde.
  local function boot(o)
    if not H.ns then H.boot(nil) end
    local ns0 = H.ns
    local XPL = ns0.Meta.XP_LEVELS
    local db = { version = o.version or 8, meta = { runs = 0, zones = {}, classes = {}, flags = {} }, journal = {} }
    for cid, lv in pairs(o.levels or {}) do
      db.meta.classes[cid] = { xp = o.xp and o.xp[cid] or XPL[lv], runs = 0, wins = 0, zones = {} }
    end
    for cid, t in pairs(o.trees or {}) do
      local cs = db.meta.classes[cid]
      cs.talents, cs.spec = t[1], t[2]
    end
    for cid, n in pairs(o.won or {}) do
      for i = 1, n do
        local z = ns0.Zone.ORDER[i]
        db.meta.zones[z] = true
        db.meta.classes[cid].zones[z] = { won = true, keyMax = 0, bestKey = 0 }
      end
    end
    H.boot(db)
    H.slash("")
    return H.ns
  end

  -- Arbre construit par l'ordre du bot (n premiers points) : { [nœud] = rang }, voie.
  local function botTree(ns, cid, n, spec)
    local order = ns.Talent.tree(cid).bot.order
    local list = {}
    for i = 1, n do list[i] = order[i] end
    return ns.Talent.build(cid, list, spec)
  end

  local function openTalents(cid)
    clickOption("ui:progress")
    clickOption("pclass:" .. cid)
    clickOption("ptab:talents")
    return UI().current, UI().step
  end

  -- Place : nœuds, faces, noms, conditions, lignes et bouton dans la fenêtre ; nœuds et faces sans chevauchement
  -- entre eux ni avec les boutons de l'en-tête ; noms sans chevauchement ; rien de tronqué.
  local function layoutProblems(scr)
    local t = scr.tv
    local content = R.rect(H.ns.UI.content)
    local bad, boxes, names = {}, {}, {}
    local header = {}
    for _, b in ipairs(scr.tabBtns) do if vis(b) then header[#header + 1] = R.rect(b) end end
    for _, b in ipairs({ scr.metaBtn, scr.back, scr.bar, t.reset }) do if vis(b) then header[#header + 1] = R.rect(b) end end
    for i, b in ipairs(t.nodes) do
      if vis(b) then
        local r = R.rect(b)
        if not inside(r, content) then bad[#bad + 1] = "nœud " .. i .. " " .. fmt(r) end
        if b.option then boxes[#boxes + 1] = { r, "nœud " .. b.option.node } end
        local pr = R.rect(b.rank.bg)
        if not inside(pr, content) then bad[#bad + 1] = "rang " .. i .. " " .. fmt(pr) end
      end
    end
    for i, b in ipairs(t.faces) do
      if vis(b) then
        local r = R.rect(b)
        if not inside(r, content) then bad[#bad + 1] = "face " .. i .. " " .. fmt(r) end
        boxes[#boxes + 1] = { r, "face " .. tostring(b.option and b.option.choice) }
      end
    end
    for i = 1, #boxes do
      for j = i + 1, #boxes do
        if overlaps(boxes[i][1], boxes[j][1]) then bad[#bad + 1] = boxes[i][2] .. " sur " .. boxes[j][2] end
      end
      for _, hr in ipairs(header) do
        if overlaps(boxes[i][1], hr) then bad[#bad + 1] = boxes[i][2] .. " sur l'en-tête" end
      end
    end
    local function textBox(fs)
      -- encre du texte : largeur mesurée, centrée sur l'ancrage de la boîte lâche
      local r = R.rect(fs)
      if not r then return nil end
      local w = (fs:GetStringWidth() or 0)
      local cx = (r[1] + r[3]) / 2
      local cy = (r[2] + r[4]) / 2
      local h = (fs:GetStringHeight() or 12)
      local calls = rawget(fs, "_calls") or {}
      local jh = calls.SetJustifyH and calls.SetJustifyH[1]
      if jh == "LEFT" then return { r[1], cy - h / 2, r[1] + w, cy + h / 2 } end
      return { cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2 }
    end
    for i, l in ipairs(t.names) do
      if vis(l) then
        local r = textBox(l)
        names[#names + 1] = { r, "nom " .. tostring(l._text) }
        if not inside(r, content) then bad[#bad + 1] = "nom " .. i .. " " .. fmt(r) end
      end
    end
    for i = 1, #names do
      for j = i + 1, #names do
        if overlaps(names[i][1], names[j][1]) then bad[#bad + 1] = names[i][2] .. " sur " .. names[j][2] end
      end
      for _, b in ipairs(boxes) do
        if overlaps(names[i][1], b[1]) then bad[#bad + 1] = names[i][2] .. " sur " .. b[2] end
      end
    end
    for _, l in ipairs({ t.summary, t.note }) do
      if vis(l) then
        local r = textBox(l)
        if not inside(r, content) then bad[#bad + 1] = "ligne " .. fmt(r) end
        for _, hr in ipairs(header) do if overlaps(r, hr) then bad[#bad + 1] = "ligne « " .. tostring(l._text) .. " » sur un bouton" end end
      end
    end
    for i, l in ipairs(t.rowLocks) do
      if vis(l) then
        local r = textBox(l)
        for _, b in ipairs(boxes) do if overlaps(r, b[1]) then bad[#bad + 1] = "condition " .. i .. " sur " .. b[2] end end
      end
    end
    H.settle()
    for _, s in ipairs(H.ns.Widgets.truncatedNow()) do bad[#bad + 1] = "tronqué : " .. s end
    return bad
  end

  local function count(list) local n = 0 for _, b in ipairs(list) do if vis(b) then n = n + 1 end end return n end
  local function nodeButton(scr, id) return scr.optionButtons["talent:" .. id] end

  -- 1. Arbre neuf (Warrior niveau 1) ------------------------------------------------------------------------------
  local ns = boot({ levels = { warrior = 1 } })
  clickOption("class:warrior")
  check("accueil : aucune pastille sur « Progress » sans point à dépenser",
    not (button("ui:progress").badge and vis(button("ui:progress").badge)))
  local scr, st = openTalents("warrior")
  local t = scr.tv
  check("onglet Talents : affiché, onglet au liseré d'or, cartes et zones cachées", st.tab == "talents"
    and option("ptab:talents").selected and button("ptab:talents").selected and not vis(scr.cards[1]) and not vis(scr.locks[1])
    and not vis(scr.zoneCols[1].name) and not vis(scr.relics[1]), tostring(st.tab))
  check("arbre neuf : ligne des points, ligne « un point par niveau »",
    t.summary._text == "0 talent points to spend · 0 of 24 spent" and vis(t.summary)
    and t.note._text == "Each level from level 2 gives one talent point." and vis(t.note), tostring(t.summary._text))
  local tree = ns.Talent.tree("warrior")
  local nNodes, nFaces = 0, 0
  for _, n in ipairs(tree.nodes) do if n.choices then nFaces = nFaces + #n.choices else nNodes = nNodes + 1 end end
  local shownNodes = 0
  for _, b in ipairs(t.nodes) do if vis(b) and b.option then shownNodes = shownNodes + 1 end end
  check(("arbre neuf : %d nœuds et %d faces de Specialization, quatre rangées"):format(nNodes, nFaces),
    shownNodes == nNodes and count(t.faces) == nFaces and count(t.bands) == 4, shownNodes .. " " .. count(t.faces))
  local locks = {}
  for i = 2, 4 do locks[#locks + 1] = (t.rowLocks[i]._text or ""):gsub("\n", " ") end
  check("arbre neuf : rangée 1 ouverte, rangées 2 à 4 fermées « Spend 5 / 10 / 16 points to unlock. »",
    not vis(t.rowLocks[1]) and vis(t.rowLocks[2]) and vis(t.rowLocks[4])
    and joined(locks) == "Spend 5 points to unlock. | Spend 10 points to unlock. | Spend 16 points to unlock.", joined(locks))
  local tough = nodeButton(scr, "toughness")
  check("arbre neuf : Toughness 0/3, rang gris, icône grisée (aucun point)", tough.rank.text._text == "0/3"
    and tough.icon._calls.SetDesaturated and tough.icon._calls.SetDesaturated[1] == true, tostring(tough.rank.text._text))
  local tt = tip(tough)
  check("infobulle d'un nœud : nom, rang, texte du rang suivant, raison", joined(tt)
    == "Toughness | Rank 0/3 | +4 max HP. | No talent points to spend.", joined(tt))
  local fury
  for _, b in ipairs(t.faces) do if b.option and b.option.choice == "fury" then fury = b end end
  local ft = tip(fury)
  check("infobulle d'une face de Specialization : les trois voies et leurs textes, raison (rangée fermée)",
    ft[1] == "Specialization" and joined(ft):find("Arms", 1, true) and joined(ft):find("Fury", 1, true)
    and joined(ft):find("Protection", 1, true) and joined(ft):find(tree.byId.specialization.byChoice.protection.text, 1, true)
    and ft[#ft] == "Spend 10 points to unlock.", joined(ft))
  local rt = tip(t.reset)
  check("« Reset talents » grisé sans point dépensé, raison en infobulle", t.reset.active == false
    and rt[#rt] == "No talent points spent.", joined(rt))
  local bad = layoutProblems(scr)
  check("arbre neuf : tout dans la fenêtre, sans chevauchement, rien de tronqué", #bad == 0, joined(bad))
  snap("talents-neuf", true)
  local before = ns.Meta.spent(ns.Persist.db.meta, "warrior")
  H.click(tough)
  check("clic sur un nœud sans point : refusé, rien ne change", ns.Meta.spent(ns.Persist.db.meta, "warrior") == before)
  -- icônes : chaque nœud et chaque voie des arbres définis a une icône embarquée dans Media/Icons (remplacement
  -- Art.talentIcons pris en compte) ; la liste des manquantes dit lesquelles remplacer (UI/Art/talents.lua)
  local Skin, Art = ns.Skin or ns.SkinData, ns.Art
  local icons = Skin and Skin.icons
  local missing, nIcons, classes = {}, 0, {}
  for cid, tr in pairs(ns.Talents) do
    classes[#classes + 1] = cid
    for _, n in ipairs(tr.nodes) do
      local parts = n.choices or { n }
      for _, p in ipairs(parts) do
        nIcons = nIcons + 1
        local e = Art.talentIcon(cid, p.id, p.icon, n.icon)
        if not (e and (e.tga or e.icon)) then missing[#missing + 1] = cid .. "/" .. p.id
        elseif icons and not (e.tga and icons[e.tga:lower()]) then
          missing[#missing + 1] = cid .. "/" .. p.id .. " (" .. tostring(e.tga or e.icon) .. ")"
        end
      end
    end
  end
  table.sort(classes)
  check(("icônes des nœuds : %d (nœuds et voies, %s), toutes embarquées dans Media/Icons"):format(nIcons,
    table.concat(classes, ", ")), icons ~= nil and #missing == 0 and #classes == 6, joined(missing))
  -- remplacements : chaque nom de Art.talentIcons est embarqué et vise un nœud ou une voie de l'arbre
  local badOver = {}
  for cid, map in pairs(Art.talentIcons) do
    local tr = ns.Talents[cid]
    for id, name in pairs(map) do
      local known = false
      for _, n in ipairs(tr and tr.nodes or {}) do
        if n.id == id then known = true end
        for _, ch in ipairs(n.choices or {}) do if ch.id == id then known = true end end
      end
      if not known or not (icons and icons[name:lower()]) then badOver[#badOver + 1] = cid .. "/" .. id .. " " .. name end
    end
  end
  check("remplacements d'icônes (Art.talentIcons) : nœuds connus, icônes embarquées", #badOver == 0, joined(badOver))
  check("nœud sans icône : repli sur l'icône de la classe", Art.talentIcon("warrior", "x", nil, nil) == Art.class("warrior"))

  -- 2. Arbre à 15 points dépensé par des clics (Warrior niveau 17 : 16 points) ------------------------------------
  ns = boot({ levels = { warrior = 17 } })
  clickOption("class:warrior")
  local pb = button("ui:progress")
  check("accueil : pastille « 16 » sur « Progress », infobulle", pb.badge and vis(pb.badge) and pb.badge.count._text == "16"
    and joined(tip(pb)) == "16 talent points to spend (Warrior).", joined(tip(pb)))
  scr = openTalents("warrior")
  t = scr.tv
  check("onglet Talents : pastille « 16 »", button("ptab:talents").badge and vis(button("ptab:talents").badge)
    and button("ptab:talents").badge.count._text == "16")
  local order, okClicks = tree.bot.order, true
  local meta = ns.Persist.db.meta
  for i = 1, 15 do
    local id = order[i]
    local n = ns.Talent.node("warrior", id)
    clickOption(n.choices and ("tspec:" .. tree.bot.spec) or ("talent:" .. id))
    if ns.Meta.spent(meta, "warrior") ~= i then okClicks = false end
  end
  scr = UI().current
  t = scr.tv
  check("15 clics dans l'ordre du bot : 15 points dépensés, voie Fury", okClicks and meta.classes.warrior.spec == "fury"
    and t.summary._text == "1 talent point to spend · 15 of 24 spent", tostring(t.summary._text))
  check("15 points : rangées 1 à 3 ouvertes, rangée 4 fermée (« Spend 16 points to unlock. »)",
    not vis(t.rowLocks[3]) and vis(t.rowLocks[4]) and (t.rowLocks[4]._text or ""):gsub("\n", " ") == "Spend 16 points to unlock.")
  local furyFace, armsFace
  for _, b in ipairs(t.faces) do
    if b.option and b.option.choice == "fury" then furyFace = b end
    if b.option and b.option.choice == "arms" then armsFace = b end
  end
  check("Specialization : Fury active (anneau d'or, pleine), Arms assombrie, nom « Specialization: Fury »",
    furyFace.option.active and furyFace.ringTint == H.ns.Art.rim.gold and armsFace.icon._calls.SetDesaturated[1] == true
    and (function() for _, l in ipairs(t.names) do if l._text == "Specialization: Fury" and vis(l) then return true end end end)())
  ft = tip(armsFace)
  check("infobulle d'Arms : trois voies, « Fury (active) », consigne de changement gratuit",
    joined(ft):find("Fury (active)", 1, true) and ft[#ft] == "Click: switch to Arms (free).", joined(ft))
  local tm = nodeButton(scr, "tactical_mastery")
  tt = tip(tm)
  check("Tactical Mastery 0/2 apprenable : rang vert, infobulle avec consigne", tm.rank.text._text == "0/2"
    and joined(tt) == "Tactical Mastery | Rank 0/2 | " .. tree.byId.tactical_mastery.text[1] .. " | Click: learn a rank.", joined(tt))
  local bw = nodeButton(scr, "battle_ready")
  tt = tip(bw)
  check("Battle Ready 2/2 : rang d'or, texte du rang actuel seul", bw.rank.text._text == "2/2"
    and joined(tt) == "Battle Ready | Rank 2/2 | " .. tree.byId.battle_ready.text[2], joined(tt))
  bad = layoutProblems(scr)
  check("15 points : tout dans la fenêtre, sans chevauchement, rien de tronqué", #bad == 0, joined(bad))
  snap("talents-15-points", true)
  H.hover(armsFace) -- (survol : rien à vérifier de plus que l'infobulle)
  clickOption("tspec:arms")
  check("changer de voie : Arms, gratuit (15 points)", meta.classes.warrior.spec == "arms" and ns.Meta.spent(meta, "warrior") == 15)
  scr = UI().current
  local flashed
  local oldFlash = UI().flash
  UI().flash = function(msg, ...) flashed = msg return oldFlash(msg, ...) end
  clickOption("tspec:arms")
  check("cliquer la voie active : refusé (« Already your specialization. »)", flashed == "Already your specialization."
    and meta.classes.warrior.spec == "arms", tostring(flashed))
  clickOption("talent:tactical_mastery")
  scr = UI().current
  t = scr.tv
  check("16e point : rangée 4 ouverte, plus aucun point", ns.Meta.spent(meta, "warrior") == 16 and not vis(t.rowLocks[4])
    and t.summary._text == "0 talent points to spend · 16 of 24 spent" and not vis(button("ptab:talents").badge))
  flashed = nil
  clickOption("talent:rampage")
  check("rang refusé sans point : message « No talent points to spend. »", flashed == "No talent points to spend."
    and (meta.classes.warrior.talents.rampage or 0) == 0, tostring(flashed))
  -- remboursement : premier clic = confirmation, second = rendu (gratuit)
  clickOption("treset")
  check("« Reset talents » : premier clic demande confirmation, rien n'est rendu", scr.tv.reset.label._text == "Confirm reset?"
    and ns.Meta.spent(meta, "warrior") == 16, tostring(scr.tv.reset.label._text))
  clickOption("treset")
  scr = UI().current
  check("« Reset talents » : second clic rend les 16 points, voie effacée", ns.Meta.spent(meta, "warrior") == 0
    and meta.classes.warrior.spec == nil and scr.tv.summary._text == "16 talent points to spend · 0 of 24 spent"
    and scr.tv.reset.label._text == "Reset talents" and scr.tv.reset.active == false, tostring(scr.tv.summary._text))
  UI().flash = oldFlash

  -- 3. Arbre plein (niveau 25) -----------------------------------------------------------------------------------
  local full, fspec = botTree(ns, "warrior", 24, "fury")
  ns = boot({ levels = { warrior = 25 }, trees = { warrior = { full, fspec } } })
  clickOption("class:warrior")
  scr = openTalents("warrior")
  t = scr.tv
  local allMax = true
  for _, b in ipairs(t.nodes) do
    if vis(b) and b.option and b.option.rank ~= b.option.ranks then allMax = false end
  end
  check("arbre plein : 24 sur 24, tous les rangs au maximum, aucune ligne d'état, pas de pastille", allMax
    and t.summary._text == "0 talent points to spend · 24 of 24 spent" and not vis(t.note) and not vis(button("ptab:talents").badge)
    and not vis(t.rowLocks[2]) and not vis(t.rowLocks[4]) and t.reset.active ~= false, tostring(t.summary._text))
  bad = layoutProblems(scr)
  check("arbre plein : tout dans la fenêtre, sans chevauchement, rien de tronqué", #bad == 0, joined(bad))
  snap("talents-plein", true)

  -- 4. Classe sans arbre --------------------------------------------------------------------------------------------
  local emptyClass
  for _, cid in ipairs(ns.Controller.sortedClasses()) do
    if not ns.Talent.tree(cid) then emptyClass = cid break end
  end
  if emptyClass then
    ns = boot({ levels = { [emptyClass] = 5 } })
    clickOption("class:" .. emptyClass)
    check("classe sans arbre : aucune pastille sur « Progress »", not (button("ui:progress").badge and vis(button("ui:progress").badge)))
    scr = openTalents(emptyClass)
    t = scr.tv
    local cname = ns.Classes[emptyClass].name
    check("classe sans arbre (" .. cname .. ") : points, « No talent tree for the " .. cname .. " yet. », ni rangée, ni nœud, ni remboursement",
      t.summary._text == "4 talent points to spend · 0 of 24 spent" and t.note._text == "No talent tree for the " .. cname .. " yet."
      and count(t.bands) == 0 and count(t.nodes) == 0 and count(t.faces) == 0 and not vis(t.reset)
      and not vis(button("ptab:talents").badge), tostring(t.note._text))
    bad = layoutProblems(scr)
    check("classe sans arbre : rien de tronqué", #bad == 0, joined(bad))
    snap("talents-arbre-vide", true)
    -- arbre d'essai de 15 nœuds (cinq dans la rangée du nœud à choix, noms longs, nœuds sans icône : repli sur
    -- l'icône de la classe) posé sur cette classe le temps du cas : la disposition tient pour d'autres arbres
    local TC = ns.TalentCommon
    local function nd(id, row, ranks, name, icon)
      local text = {}
      for r = 1, ranks do text[r] = ("Test effect of rank %d."):format(r) end
      return { id = id, row = row, ranks = ranks, name = name, icon = icon, text = text }
    end
    ns.Talent.define(emptyClass, { rows = { 0, 5, 10, 16 }, nodes = {
      TC.toughness({ row = 1, ranks = 3, hp = 3 }), nd("primal", 1, 2, "Primal Instinct of the Wilds", "ability_druid_catform"),
      nd("second", 1, 2, "Second Breath"),
      TC.provisions({ row = 2 }), nd("natural", 2, 2, "Natural Shapeshifter", "ability_druid_eclipse"),
      nd("feral", 2, 2, "Feral Instinct", "ability_druid_rake"), nd("moonkin", 2, 1, "Moonkin Aura", "spell_nature_forceofnature"),
      { id = "specialization", row = 3, ranks = 1, name = "Specialization", icon = "classicon_druid", choices = {
        { id = "feral", name = "Feral", icon = "ability_druid_catform", text = "Test path one." },
        { id = "balance", name = "Balance", text = "Test path two, no icon of its own." },
        { id = "restoration", name = "Restoration", icon = "spell_nature_healingtouch", text = "Test path three." } } },
      TC.fieldMedic({ row = 3 }), nd("grasp", 3, 2, "Nature's Grasp", "spell_nature_naturesblessing"),
      nd("hide", 3, 1, "Thick Hide", "inv_misc_pelt_bear_03"), nd("omen", 3, 1, "Omen of Clarity", "spell_nature_crystalball"),
      TC.veteransArsenal({ row = 4 }), nd("growth", 4, 2, "Wild Growth", "ability_druid_flourish"),
      nd("hearth", 4, 1, "Ancient Hearth of the Grove") } })
    local cs = ns.Persist.db.meta.classes[emptyClass]
    cs.xp = ns.Meta.XP_LEVELS[12]
    cs.talents = { toughness = 3, primal = 2, second = 2, natural = 2, feral = 2 }
    clickOption("ptab:zones")
    clickOption("ptab:talents")
    scr = UI().current
    t = scr.tv
    local fives = 0
    for _, row in ipairs(UI().step.talents.rows) do if #row.nodes == 5 then fives = fives + 1 end end
    check("arbre d'essai de 15 nœuds : une rangée de cinq (avec le nœud à choix), 14 nœuds et trois faces montrés, rangée 3 ouverte",
      fives == 1 and count(t.faces) == 3 and t.summary._text == "0 talent points to spend · 11 of 24 spent"
      and not vis(t.rowLocks[3]) and vis(t.rowLocks[4]), tostring(t.summary._text))
    local hearth = nodeButton(scr, "hearth")
    check("nœud sans icône : icône de la classe", hearth and rawget(hearth.icon, "_texture") ~= nil
      and tostring(rawget(hearth.icon, "_texture")):lower():find(emptyClass, 1, true) ~= nil, tostring(hearth and rawget(hearth.icon, "_texture")))
    bad = layoutProblems(scr)
    check("arbre d'essai de 15 nœuds : tout dans la fenêtre, sans chevauchement, rien de tronqué", #bad == 0, joined(bad))
    snap("talents-arbre-15-noeuds", true)
    ns.Talents[emptyClass] = nil
  else
    check("classe sans arbre : toutes les classes ont leur arbre (cas sans objet)", true)
  end

  -- 5. Pendant l'expédition : panneau du deck, arbre en lecture seule ------------------------------------------------
  local m15, s15 = botTree(ns, "warrior", 15, "fury")
  ns = boot({ levels = { warrior = 17 }, trees = { warrior = { m15, s15 } } })
  clickOption("class:warrior")
  ns.Controller.makeSeed = function() return T.SEED end
  clickOption("go")
  check("départ avec 15 points : carte de la zone (aucun choix au départ)", kind() == "map", tostring(kind()))
  local e = EXP()
  check("expédition : talents figés au départ (13 entrées au plus, Toughness 3/3)", e.talents
    and ns.Talent.rankIn(e.talents, "toughness") == 3, tostring(e.talents and #e.talents))
  -- deck de 24 cartes : trois rangées pleines dans le panneau (la ligne des talents reste sous la dernière)
  for _ = 1, 14 do ns.Expedition.addCard(e, "strike") end
  UI().toggleDeckView("deck")
  local DV = UI().deckView
  local line = DV.talents
  local lt = line and tip(line) or {}
  check("panneau du deck : ligne des talents (« Talents: Toughness 3 · … · Fury … »), infobulle de chacun",
    line and vis(line) and (line.text._text or ""):find("^Talents: Toughness 3 · Battle Ready 2") ~= nil
    and (line.text._text or ""):find("Fury", 1, true) ~= nil and lt[1] == "Talents of this expedition"
    and joined(lt):find("Specialization: Fury", 1, true) ~= nil and lt[#lt] == "Click: view the talent tree.",
    tostring(line and line.text._text) .. " / " .. joined(lt))
  -- la ligne ne touche aucune carte du panneau, reste dans le panneau
  local lr, pr = R.rect(line.text), R.rect(DV.panel)
  local lw = line.text:GetStringWidth() or 0
  local ink = lr and { lr[1], (lr[2] + lr[4]) / 2 - 8, lr[1] + lw, (lr[2] + lr[4]) / 2 + 8 }
  local onCard = {}
  for i, c in ipairs(DV.cards) do
    if vis(c) and overlaps(ink, R.rect(c)) then onCard[#onCard + 1] = "carte " .. i end
  end
  check("panneau du deck : ligne des talents dans le panneau, sur aucune carte ni sur « Close »", ink and inside(ink, pr)
    and #onCard == 0 and not overlaps(ink, R.rect(DV.close)), fmt(ink) .. " " .. joined(onCard))
  snap("talents-deck", true)
  H.click(line)
  scr, st = UI().current, UI().step
  t = scr.tv
  check("clic sur la ligne : panneau fermé, onglet Talents de la classe en lecture seule", not DV:IsShown()
    and kind() == "classProgress" and st.tab == "talents" and st.class == "warrior" and st.running
    and t.note._text == ns.Controller.TALENT_RUNNING_LINE and vis(t.note), tostring(t.note._text))
  rt = tip(t.reset)
  check("en expédition : « Reset talents » grisé, raison", t.reset.active == false
    and rt[#rt] == "Talents can't change during an expedition.", joined(rt))
  tt = tip(nodeButton(scr, "tactical_mastery"))
  check("en expédition : infobulle d'un nœud avec la raison", tt[#tt] == "Talents can't change during an expedition.", joined(tt))
  flashed = nil
  UI().flash = function(msg, ...) flashed = msg return oldFlash(msg, ...) end
  local spent0 = ns.Meta.spent(ns.Persist.db.meta, "warrior")
  clickOption("talent:tactical_mastery")
  local okRefuse = flashed == "Talents can't change during an expedition."
  flashed = nil
  local okCtl, why = ns.Controller.choose("talent:tactical_mastery")
  UI().flash = oldFlash
  check("en expédition : un rang est refusé (message), l'arbre ne change pas", okRefuse and not okCtl
    and ns.Controller.reasonText(why) == "Talents can't change during an expedition."
    and ns.Meta.spent(ns.Persist.db.meta, "warrior") == spent0)
  check("en expédition : pas de « Log », onglets des cartes et des zones consultables", not vis(scr.metaBtn)
    and vis(button("ptab:cards")))
  bad = layoutProblems(scr)
  check("en expédition : tout dans la fenêtre, rien de tronqué", #bad == 0, joined(bad))
  snap("talents-expedition", true)
  clickOption("ptab:cards")
  check("en expédition : onglet Cards", UI().step.tab == "cards" and kind() == "classProgress")
  clickOption("ui:back")
  check("« Back » : retour à la carte de l'expédition", kind() == "map", tostring(kind()))

  -- 6. Départ avec Veteran's Arsenal 2 (trois zones gagnées : trois épiques, puis le bibelot au choix) -------------
  ns = boot({ levels = { warrior = 25 }, trees = { warrior = { full, fspec } }, won = { warrior = 3 } })
  clickOption("class:warrior")
  ns.Controller.makeSeed = function() return T.SEED end
  clickOption("go")
  st, scr = UI().step, UI().current
  local epics = {}
  for _, o in ipairs(st.options or {}) do if o.card then epics[#epics + 1] = o.card.id end end
  check("Veteran's Arsenal : choix des épiques au départ (grille, « Skip »), 1 sur 2",
    kind() == "talentEpic" and UI().current == UI().screens.deck and #epics == 3
    and st.title == "Veteran's Arsenal: choose an epic card (1 of 2)" and button("skipTalentEpic").label._text == "Skip",
    tostring(kind()) .. " " .. tostring(st.title) .. " " .. #epics)
  local shownCards = 0
  for _, c in ipairs(scr.cards) do if vis(c) then shownCards = shownCards + 1 end end
  check("Veteran's Arsenal : trois vraies cartes épiques montrées", shownCards == 3, tostring(shownCards))
  local hint = scr.hint
  local hr = hint and R.rect(hint)
  local lowest = math.huge -- (y vers le haut : bas le plus bas des cartes)
  for _, c in ipairs(scr.cards) do if vis(c) then lowest = math.min(lowest, R.rect(c)[2]) end end
  check("Veteran's Arsenal : consigne sous les cartes (« It joins the deck… »)", hint and vis(hint)
    and (hint._text or ""):find("^It joins the deck for this expedition%.") ~= nil and hr and (hr[2] + hr[4]) / 2 < lowest,
    tostring(hint and hint._text))
  snap("talents-veterans-arsenal", true)
  local first = epics[2]
  H.click(button("talentEpic:2"))
  st = UI().step
  local epics2 = {}
  for _, o in ipairs(st.options or {}) do if o.card then epics2[#epics2 + 1] = o.card.id end end
  check("rang 2 : deuxième choix (2 sur 2), l'épique prise retirée de la liste, ajoutée au deck",
    kind() == "talentEpic" and st.title == "Veteran's Arsenal: choose an epic card (2 of 2)" and #epics2 == 2
    and EXP().deck[#EXP().deck].id == first, tostring(st.title))
  H.click(button("talentEpic:1"))
  check("après les deux épiques : le bibelot au choix (zone 3 gagnée), deux épiques au deck",
    kind() == "startRelic" and ns.Expedition.epicCount(EXP()) == 2, tostring(kind()))
  clickOption("skipStartRelic")
  check("puis la carte", kind() == "map", tostring(kind()))
  -- « Skip » : aucune épique, puis le bibelot
  ns = boot({ levels = { warrior = 25 }, trees = { warrior = { full, fspec } }, won = { warrior = 3 } })
  clickOption("class:warrior")
  clickOption("go")
  clickOption("skipTalentEpic")
  check("« Skip » : aucune épique, puis le bibelot au choix", kind() == "startRelic" and ns.Expedition.epicCount(EXP()) == 0,
    tostring(kind()))
  -- reprise après rechargement sur le choix des épiques
  ns = boot({ levels = { warrior = 25 }, trees = { warrior = { full, fspec } }, won = { warrior = 3 } })
  clickOption("class:warrior")
  clickOption("go")
  local saved = ns.Persist.db
  ns = H.boot(saved)
  H.slash("")
  check("rechargement pendant le choix des épiques : même écran", kind() == "talentEpic", tostring(kind()))

  -- 7. Bilan : niveaux et points gagnés, « Spend talent points » ---------------------------------------------------
  ns = boot({ levels = { warrior = 2 }, xp = { warrior = 95 } })
  clickOption("class:warrior")
  ns.Controller.makeSeed = function() return T.SEED end
  clickOption("go")
  e = EXP()
  e.stats.cleared, e.stats.elites, e.stats.bosses = 30, 1, 1
  e.result, e.phase = "won", "done"
  UI().refresh()
  st = UI().step
  local s = ns.Controller.ending.summary
  local want = {}
  for lv = s.levelBefore + 1, s.levelAfter do want[#want + 1] = "Warrior reaches level " .. lv .. "! +1 talent point." end
  local okLines = #want >= 2
  for _, w in ipairs(want) do if not (st.text or ""):find(w, 1, true) then okLines = false end end
  check(("bilan : une ligne par niveau gagné (%d), points gagnés %d"):format(#want, s.pointsGained or -1),
    kind() == "end" and okLines and s.pointsGained == #want, st.text)
  local sb = button("ui:talents")
  check("bilan : bouton « Spend talent points » avec la pastille des points", sb.label._text == "Spend talent points"
    and vis(sb) and sb.badge and vis(sb.badge) and sb.badge.count._text == tostring(s.levelAfter - 1), tostring(sb.label._text))
  local br, others = R.rect(sb), {}
  for _, b in ipairs(UI().current.buttons) do
    if b ~= sb and vis(b) and overlaps(R.rect(b), br) then others[#others + 1] = b.label._text end
  end
  check("bilan : les trois boutons sans chevauchement, dans la fenêtre", #others == 0 and inside(br, R.rect(ns.UI.content)), joined(others))
  H.settle()
  check("bilan : rien de tronqué", #ns.Widgets.truncatedNow() == 0, joined(ns.Widgets.truncatedNow()))
  snap("talents-bilan", true)
  clickOption("ui:talents")
  st = UI().step
  check("« Spend talent points » : onglet Talents de la classe de l'expédition", kind() == "classProgress"
    and st.tab == "talents" and st.class == "warrior" and not st.running, tostring(kind()))
  -- beaucoup de niveaux d'un coup : une seule ligne
  clickOption("ui:back")
  check("« Back » depuis l'onglet Talents : retour au bilan", kind() == "end", tostring(kind()))
  clickOption("ui:new")
  clickOption("go")
  e = EXP()
  e.stats.cleared, e.stats.elites, e.stats.bosses = 200, 4, 4
  e.result, e.phase = "won", "done"
  UI().refresh()
  st, s = UI().step, ns.Controller.ending.summary
  local n = s.levelAfter - s.levelBefore
  check(("bilan : %d niveaux d'un coup (plus de %d) : une seule ligne"):format(n, ns.Controller.END_LEVEL_LINES),
    n > ns.Controller.END_LEVEL_LINES and (st.text or ""):find("Warrior reaches level " .. s.levelAfter .. "! +" .. n
      .. " talent points (levels " .. (s.levelBefore + 1) .. " to " .. s.levelAfter .. ").", 1, true) ~= nil
    and not (st.text or ""):find("+1 talent point.", 1, true), st.text)

  -- 8. Migration v8 : la ligne « You have N talent points to spend. » une fois sur l'accueil -----------------------
  ns = boot({ version = 7, levels = { warrior = 1 }, xp = { warrior = 1400 } })
  clickOption("class:warrior")
  st = UI().step
  check("migration v7 → v8 (1 400 d'expérience : niveau 12) : « You have 11 talent points to spend. » sur l'accueil",
    (st.text or ""):find("You have 11 talent points to spend.", 1, true) ~= nil
    and (UI().current.note._text or ""):find("You have 11 talent points to spend.", 1, true) ~= nil, st.text)
  clickOption("ui:progress")
  clickOption("ui:back")
  st = UI().step
  check("migration : la ligne disparaît après l'écran Progress, la pastille reste", not (st.text or ""):find("talent points to spend", 1, true)
    and button("ui:progress").badge.count._text == "11", st.text)
  ns = boot({ levels = { warrior = 12 } })
  clickOption("class:warrior")
  check("sauvegarde déjà en v8 : pas de ligne de migration", not (UI().step.text or ""):find("You have", 1, true))

  -- 9. Les six arbres réels, pleins (ordre du bot, 24 points) : rangées de 3 à 5 nœuds, noms longs, trois faces ---
  local CLASSES = { "warrior", "druid", "hunter", "mage", "priest", "rogue" }
  for _, cid in ipairs(CLASSES) do
    local tr = ns.Talent.tree(cid)
    if not tr then
      check("arbre de " .. cid .. " : défini", false)
    else
      local map, spec = botTree(ns, cid, 24, tr.bot.spec)
      ns = boot({ levels = { [cid] = 25 }, trees = { [cid] = { map, spec } } })
      clickOption("class:" .. cid)
      scr = openTalents(cid)
      t = scr.tv
      local perRow, nodes, faces = {}, 0, 0
      for _, n in ipairs(tr.nodes) do
        perRow[n.row] = (perRow[n.row] or 0) + 1
        if n.choices then faces = faces + #n.choices else nodes = nodes + 1 end
      end
      local shownN = 0
      for _, b in ipairs(t.nodes) do if vis(b) and b.option then shownN = shownN + 1 end end
      local sizes = {}
      for r = 1, 4 do sizes[r] = perRow[r] or 0 end
      local specName = tr.byId.specialization.byChoice[spec].name
      local named = false
      for _, l in ipairs(t.names) do if vis(l) and l._text == "Specialization: " .. specName then named = true end end
      check(("arbre plein du %s : 24 sur 24, rangées de %s nœuds, %d nœuds et %d faces, « Specialization: %s »"):format(
        ns.Classes[cid].name, table.concat(sizes, "/"), nodes, faces, specName),
        t.summary._text == "0 talent points to spend · 24 of 24 spent" and shownN == nodes and count(t.faces) == faces
        and faces == 3 and named and count(t.bands) == 4, tostring(t.summary._text) .. " " .. shownN .. " " .. count(t.faces))
      bad = layoutProblems(scr)
      check(("arbre plein du %s : tout dans la fenêtre, sans chevauchement, rien de tronqué"):format(ns.Classes[cid].name),
        #bad == 0, joined(bad))
      -- infobulle de chaque nœud : nom, « Rank N/N », texte du rang actuel (nœud au maximum : pas de rang suivant)
      local tbad = {}
      for _, b in ipairs(t.nodes) do
        if vis(b) and b.option then
          local o = b.option
          local lines = tip(b)
          if lines[1] ~= o.name or lines[2] ~= ("Rank %d/%d"):format(o.ranks, o.ranks)
            or lines[3] ~= ns.Talent.rankText(cid, o.node, o.ranks) then tbad[#tbad + 1] = joined(lines) end
        end
      end
      check(("arbre plein du %s : infobulles des nœuds (nom, rang maximal, texte)"):format(ns.Classes[cid].name),
        #tbad == 0, joined(tbad))
      snap("talents-" .. cid, true)
    end
  end

  -- 10. En combat : les chiffres changés par les talents (pastille, infobulles, marques, jetons d'état) ----------
  -- Expédition de la classe au niveau 25 avec son arbre plein (voie au choix), premier nœud de la carte en combat.
  local function plainTip(o)
    local out = {}
    for _, l in ipairs(tip(o)) do out[#out + 1] = H.plain(tostring(l)) end
    return table.concat(out, " | ")
  end
  local function talentCombat(cid, spec)
    local map, sp = botTree(H.ns or ns, cid, 24, spec)
    ns = boot({ levels = { [cid] = 25 }, trees = { [cid] = { map, sp } } })
    clickOption("class:" .. cid)
    ns.Controller.makeSeed = function() return T.SEED end
    clickOption("go")
    for _ = 1, 3 do
      if kind() == "talentEpic" then clickOption("skipTalentEpic")
      elseif kind() == "startRelic" then clickOption("skipStartRelic") end
    end
    local ex = EXP()
    local id = ex.map.start[1]
    ex.map.nodes[id].kind = "combat"
    clickOption("path:" .. id)
    H.settle()
    local v = T.V()
    local c = ex.combat
    v:Render(true)
    H.settle()
    return c, v
  end
  local function has(text, s) return text:find(s, 1, true) ~= nil end
  local function statusToken(row, id)
    for _, tk in ipairs(row.tokens) do
      if vis(tk) and tk.info and tk.info.status == id then return tk end
    end
  end

  -- Druid (Balance) : frappe de l'ours (Feral Instinct), coup à tous (voie Balance), Absorb de Tree of Life (Living
  -- Seed), plafond de la réserve (Wild Reserve), taxe (Master Shapeshifter, Natural Shapeshifter)
  do
    local c, v = talentCombat("druid", "balance")
    local D, DT, Art2, Combat = ns.Druid, ns.DruidTalents, ns.Art, ns.Combat
    local rk = function(id) return ns.Talent.rankIn(c.talents, id) end
    local strike = D.STRIKE_BASE + DT.strike * rk("feral_instinct")
    local cap = ns.Classes.druid.resource.cap + DT.cap * rk("wild_reserve")
    local res = 3
    c.player.res = res
    c.cls.form, c.cls.taxed = "bear", 0
    v:Render(true)
    H.advance(1)
    local tb = plainTip(v.resource)
    local t1, dmg = Art2.druidStrike(c)
    check(("Druid, talents en combat : Bear « strikes for %d » (base %d), frappe de %d sur sa cible, « %d / %d »"):format(
      strike + res, D.STRIKE_BASE + res, dmg, res, cap),
      rk("feral_instinct") > 0 and has(tb, ("Bear strikes for %d."):format(strike + res))
      and has(tb, ("strikes for %d + Frenzy"):format(strike)) and t1 and dmg == Combat.strikeDamage(c, t1, strike, true)
      and has(tb, ("End of turn: Bear strikes %s for %d"):format(Combat.enemyName(t1), dmg))
      and has(tb, ("%d / %d"):format(res, cap)) and cap > ns.Classes.druid.resource.cap, tb)
    local free = D.TAX_FREE + DT.masterFree * rk("master_shapeshifter")
    local taxMax = math.min(D.TAX_MAX, DT.taxMax)
    check(("Druid : taxe « %d more free » (base %d), malus de %d au plus"):format(free, D.TAX_FREE, taxMax),
      has(tb, ("Form changes this turn: 0. Shifting between Cat and Bear is free. %d more free, then shifting costs %d mana next turn."):format(
        free, math.min(D.TAX, taxMax))), tb)
    c.cls.form = "moonkin"
    v:Render(true)
    H.advance(1)
    tb = plainTip(v.resource)
    local pulse = math.min(D.PULSE_MAX, math.ceil(res / 2)) + DT.pulse
    local host = v.classZone.views.druid
    local mk
    for _, m in ipairs(host.marks) do if vis(m) then mk = m break end end
    local mt = mk and plainTip(mk) or ""
    local e1 = mk and mk.unit
    check(("Druid : Moonkin « %d damage to each enemy » (base %d), marque « %d damage to it », règle « then %d more », « up to %d »"):format(
      pulse, pulse - DT.pulse, e1 and Combat.strikeDamage(c, e1, pulse, false) or -1, DT.pulse, cap),
      has(tb, ("End of turn: %d damage to each enemy."):format(pulse)) and has(tb, ("up to %d."):format(cap))
      and e1 and has(mt, ("End of turn: %d damage to it."):format(Combat.strikeDamage(c, e1, pulse, false)))
      and has(mt, ("per 2 Charges, up to %d, then %d more."):format(D.PULSE_MAX, DT.pulse)), tb .. "\n        " .. mt)
    c.player.res = 0
    v:Render(true)
    H.advance(1)
    local marks0 = 0
    for _, m in ipairs(host.marks) do if vis(m) then marks0 = marks0 + 1 end end
    tb = plainTip(v.resource)
    check(("Druid : Moonkin sans Charge, la voie Balance frappe quand même (%d, marques sur les ennemis)"):format(DT.pulse),
      has(tb, ("End of turn: %d damage to each enemy."):format(DT.pulse)) and marks0 > 0, tb)
    c.cls.form = "tree"
    v:Render(true)
    H.advance(1)
    tb = plainTip(v.resource)
    local absorb = D.TREE_ABSORB + DT.seed * rk("living_seed")
    check(("Druid : Tree of Life « gain %d Absorb » (base %d)"):format(absorb, D.TREE_ABSORB),
      rk("living_seed") > 0 and has(tb, ("End of turn: gain %d Absorb."):format(absorb)), tb)
    snap("talents-combat-druid", true)
    -- hors combat : les valeurs de base
    check("Druid, hors combat : règle du coup à tous et Absorb de Tree of Life de base",
      Art2.druidPulseRule(nil) == ("1 damage to each enemy per 2 Charges, up to %d."):format(D.PULSE_MAX)
      and Art2.druidTreeAbsorb(nil) == D.TREE_ABSORB, Art2.druidPulseRule(nil))
  end

  -- Hunter : coup du familier (Unleashed Fury), plafond du Frenzy (Animal Handler), baisse (Bestial Discipline)
  do
    local c, v = talentCombat("hunter")
    local Hn, HT, Combat = ns.Hunter, ns.HunterTalents, ns.Combat
    local rk = function(id) return ns.Talent.rankIn(c.talents, id) end
    local cap = ns.Classes.hunter.resource.cap + HT.handler * rk("animal_handler")
    local every = HT.decayEvery[rk("bestial_discipline")]
    local word = ({ [2] = "other", [3] = "third", [4] = "fourth" })[every]
    c.player.res = 3
    v:Render(true)
    H.advance(1)
    local tb = plainTip(v.resource)
    check(("Hunter, talents en combat : pastille « up to %d », « 3 / %d », « drops by 1 only every %s round »"):format(cap, cap, tostring(word)),
      cap > ns.Classes.hunter.resource.cap and has(tb, ("up to %d."):format(cap)) and has(tb, ("3 / %d"):format(cap))
      and word ~= nil and has(tb, ("Frenzy drops by 1 only every %s round."):format(word)), tb)
    local pet = v.classZone.views.hunter.pet
    local tp = plainTip(pet)
    local tg = Hn.petTarget(c)
    local want = Combat.calcDamage(c, c.player, tg, Hn.PET_BASE + HT.fury * rk("unleashed_fury") + 3, nil)
    local base = Combat.calcDamage(c, c.player, tg, Hn.PET_BASE + 3, nil)
    check(("Hunter : familier « for %d » (base %d), « up to %d »"):format(want, base, cap),
      want > base and has(tp, ("Attacks %s for %d at the end of the turn."):format(ns.Enemies[tg.id].name, want))
      and has(tp, ("up to %d."):format(cap)), tp)
    snap("talents-combat-hunter", true)
  end

  -- Rogue : plafond de Combo (Deeper Stratagem), dégâts arrêtés et charges de Parry (Combat Readiness, Lightning
  -- Reflexes) sur le jeton Parry du héros
  do
    local c, v = talentCombat("rogue")
    local Ro, RT = ns.Rogue, ns.RogueTalents
    local rk = function(id) return ns.Talent.rankIn(c.talents, id) end
    local cap = ns.Classes.rogue.resource.cap + RT.stratagem * rk("deeper_stratagem")
    c.player.res = 2
    c.player.st.parry = 2
    v:Render(true)
    H.advance(1)
    local tb = plainTip(v.resource)
    local stop = Ro.PARRY_STOP + RT.readiness * rk("combat_readiness")
    local pmax = Ro.PARRY_MAX + RT.reflexes * rk("lightning_reflexes")
    local tk = statusToken(v.playerSt, "parry")
    local tp = tk and plainTip(tk) or ""
    check(("Rogue, talents en combat : pastille « up to %d », « 2 / %d » ; Parry « up to %d damage » (base %d), « Max %d » (base %d)"):format(
      cap, cap, stop, Ro.PARRY_STOP, pmax, Ro.PARRY_MAX),
      cap > ns.Classes.rogue.resource.cap and has(tb, ("up to %d."):format(cap)) and has(tb, ("2 / %d"):format(cap))
      and stop > Ro.PARRY_STOP and pmax > Ro.PARRY_MAX
      and has(tp, ("up to %d damage. Max %d."):format(stop, pmax)), tb .. "\n        " .. tp)
    check("Rogue, hors combat : texte de Parry de base", ns.Art.statusNow("parry", ns.Statuses.parry.text, nil)
      == ns.Statuses.parry.text and has(ns.Statuses.parry.text, ("up to %d damage"):format(Ro.PARRY_STOP)))
    snap("talents-combat-rogue", true)
  end

  -- Priest : soin d'Atonement (Twin Disciplines) sur le jeton Atonement du héros
  do
    local c, v = talentCombat("priest")
    local PT, Combat = ns.PriestTalents, ns.Combat
    local heal = Combat.ATONEMENT_HEAL + PT.twin * ns.Talent.rankIn(c.talents, "twin_disciplines")
    c.player.st.atonement = 2
    v:Render(true)
    H.advance(1)
    local tk = statusToken(v.playerSt, "atonement")
    local tp = tk and plainTip(tk) or ""
    check(("Priest, talents en combat : Atonement « restores %d HP » (base %d)"):format(heal, Combat.ATONEMENT_HEAL),
      heal > Combat.ATONEMENT_HEAL and has(tp, ("restores %d HP."):format(heal)), tp)
    check("Priest, hors combat : texte d'Atonement de base", ns.Art.statusNow("atonement", ns.Statuses.atonement.text, nil)
      == ns.Statuses.atonement.text)
  end

  -- Mage : plafond de Charges (Arcane Mind) ; crans de la pastille
  do
    local c, v = talentCombat("mage")
    local MT = ns.MageTalents
    local cap = ns.Classes.mage.resource.cap + MT.mind * ns.Talent.rankIn(c.talents, "arcane_mind")
    c.player.res = 2
    v:Render(true)
    H.advance(1)
    local tb = plainTip(v.resource)
    local sockets = 0
    for _, p in ipairs(v.resPips.list) do if vis(p.socket) then sockets = sockets + 1 end end
    check(("Mage, talents en combat : pastille « up to %d » (base %d), « 2 / %d », %d crans"):format(cap,
      ns.Classes.mage.resource.cap, cap, cap), cap > ns.Classes.mage.resource.cap and has(tb, ("up to %d."):format(cap))
      and has(tb, ("2 / %d"):format(cap)) and sockets == cap, tb .. " / " .. sockets)
  end

  -- Warrior (Arms) : plafond de Rage (Unbridled Wrath), Sundered (voie Arms) sur le jeton de l'ennemi
  do
    local c, v = talentCombat("warrior", "arms")
    local WT, Combat = ns.WarriorTalents, ns.Combat
    local cap = ns.Classes.warrior.resource.cap + WT.wrath * ns.Talent.rankIn(c.talents, "unbridled_wrath")
    c.player.res = 1
    local en = Combat.aliveEnemies(c)[1]
    en.st.armor_broken = 2
    v:Render(true)
    H.advance(1)
    local tb = plainTip(v.resource)
    local pct = math.floor((Combat.SUNDER_MULT - 1 + WT.sunder) * 100 + 0.5)
    local tk = statusToken(v.slotOf[en.uid].st, "armor_broken")
    local tp = tk and plainTip(tk) or ""
    check(("Warrior, talents en combat : pastille « up to %d », « 1 / %d » ; Sundered « %d%% more damage » (base %d%%)"):format(
      cap, cap, pct, math.floor((Combat.SUNDER_MULT - 1) * 100 + 0.5)),
      cap > ns.Classes.warrior.resource.cap and has(tb, ("up to %d."):format(cap)) and has(tb, ("1 / %d"):format(cap))
      and has(tp, ("Takes %d%% more damage."):format(pct)) and Combat.const(c, "SUNDER_MULT", Combat.SUNDER_MULT) > Combat.SUNDER_MULT,
      tb .. "\n        " .. tp)
    check("Warrior, hors combat : explication de la Rage de base (« up to 5 »)",
      has(ns.Art.resourceLine(nil, "rage"), ("up to %d."):format(ns.Classes.warrior.resource.cap)))
    snap("talents-combat-warrior", true)
  end
end
