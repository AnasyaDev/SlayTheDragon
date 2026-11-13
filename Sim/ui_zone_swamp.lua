-- Harnais d'interface de Swamp of Sorrows (section « UZS ») : combat avec dormeurs (« Asleep 2 », ouverture en
-- gris, Rude Awakening dans l'infobulle, Alarm « Wakes N », réveil), boss Somnus (Slumber et dragonnets), une
-- rencontre, les sept décors peints (planches build/snap/decor-swamp_*.svg). Lancé par Sim/ui_harness.lua.
return function(T)
  local H, check, snap, R = T.H, T.check, T.snap, T.R
  local SNAP = arg and arg[2]

  local function vis(o)
    while o do if not rawget(o, "_shown") then return false end o = rawget(o, "_parent") end
    return true
  end
  local function tip(o) return table.concat(H.hover(o), " | ") end

  -- combat du marais piloté par l'interface : l'expédition passe dans le marais, nouveau combat
  local function swampCombat(cl, encounter, kind)
    local e = T.zoneCombat(cl)
    local ns = H.ns
    e.zone = "swamp"
    e.fight = e.fight or {}
    e.fight.kind = kind or "combat"
    e.combat = ns.Combat.new({ seed = T.SEED, class = cl, hp = e.hp, maxHp = e.maxHp, deck = e.deck,
      encounter = encounter, zone = "swamp", kind = kind or "combat", relics = e.relics })
    ns.UI.refresh()
    H.settle()
    local v = T.V()
    v:Render(true)
    return e, e.combat, v
  end

  -- 1. Combat : Marsh Oracle (Alarm Cry), crocolisk et Swampwalker endormis
  local e, c, v = swampCombat("priest", { "marsh_oracle", "sawtooth_crocolisk", "swampwalker" })
  local ns = H.ns
  local Combat, Art = ns.Combat, ns.Art
  local oracle, croc, walker = c.enemies[1], c.enemies[2], c.enemies[3]
  local so, sc, sw = v.slotOf[oracle.uid], v.slotOf[croc.uid], v.slotOf[walker.uid]
  local roll = Combat.calcDamage(c, croc, c.player, ns.Enemies.sawtooth_crocolisk.moves.death_roll.actions[1][2])
  check("dormeurs : bulle « Asleep 2 » / « Asleep 3 », icône du sommeil", sc.intent.text._text == "Asleep 2"
    and sw.intent.text._text == "Asleep 3", tostring(sc.intent.text._text) .. " / " .. tostring(sw.intent.text._text))
  check("ouverture annoncée en gris sous la bulle : « On waking: Death Roll " .. roll .. " »", vis(sc.next)
    and sc.next._text == "On waking: Death Roll " .. roll, tostring(sc.next._text))
  local t = tip(sc.intent)
  check("infobulle du dormeur : tours sautés, réveil par les dégâts, Rude Awakening, ouverture",
    t:find("Asleep 2", 1, true) and t:find("Damage wakes it up", 1, true) and t:find("Rude Awakening", 1, true)
    and t:find("On waking: Death Roll", 1, true), t)
  check("Marsh Oracle : Alarm Cry annonce le nombre de dormeurs (« Wakes 2 »), incantation",
    (so.intent.text._text or ""):find("Wakes 2", 1, true) ~= nil and tip(so.intent):find("Wakes up all sleeping allies", 1, true) ~= nil,
    tostring(so.intent.text._text) .. " | " .. tip(so.intent))
  check("état Asleep : mot du langage (zone swamp) et définition courte", ns.Language.keywords.rude_awakening
    and ns.Language.keywords.rude_awakening.zone == "swamp" and Art.statusShort.asleep ~= nil and Art.statuses.asleep ~= nil)
  snap("zone-swamp", true)

  -- réveil par une carte : l'ouverture devient l'intention (chiffre en couleur), petite icône d'ouverture
  local idx
  for i, inst in ipairs(c.hand) do if ns.Card.def(inst).target == "enemy" and ns.Card.def(inst).type == "attack" then idx = i break end end
  local hp0 = croc.hp
  if idx then
    ns.Controller.act({ "play", idx, 2 })
    H.settle()
    v:Render(true)
  end
  check("réveil par un coup : bonus, ouverture devenue l'intention (« " .. roll .. " »), petite icône d'ouverture",
    idx and croc.hp < hp0 and croc.st.asleep == nil and sc.intent.text._text == tostring(roll) and vis(sc.intent.badge)
    and not vis(sc.next), tostring(sc.intent.text._text))
  snap("zone-swamp-wake", true)

  -- 2. Boss : Somnus endormi, puis The Dream (dragonnets, Slumber, soin affiché sous la bulle)
  local e2, c2, v2 = swampCombat("warrior", { "somnus" }, "boss")
  ns = H.ns -- nouveau démarrage de l'addon (zoneCombat)
  Combat, Art = ns.Combat, ns.Art
  local s = c2.enemies[1]
  local ss = v2.slotOf[s.uid]
  check("Somnus : « Asleep 2 », ouverture Bellowing Roar en gris, cran de The Dream sur la barre",
    ss.intent.text._text == "Asleep 2" and (ss.next._text or ""):find("^On waking: Bellowing Roar") ~= nil
    and vis(ss.marks[1]), tostring(ss.next._text))
  ns.Swamp.wake(c2, s, "test")
  s.hp = math.floor(s.maxHp * 0.5) + 1
  Combat.dealDamage(c2, c2.player, s, 3)
  ns.Combat.fire(c2, "onEffectEnd", "card", 1)
  v2:Render(true)
  H.settle()
  local mend = ss.badges[1]
  check("The Dream : deux dragonnets, Somnus endormi (« Asleep 2 »), soin de Slumber sous la bulle (« +10 »)",
    #c2.enemies == 3 and ss.intent.text._text == "Asleep 2" and vis(mend) and mend.text._text == "+10"
    and (ss.next._text or ""):find("Deep Breath", 1, true) ~= nil, tostring(mend and mend.text._text))
  check("décor du boss : Pool of Tears (zone)", ns.Controller.scene() == "swamp_pool", ns.Controller.scene())
  snap("zone-swamp-boss", true)

  -- 3. Rencontre : les marches du temple (Sleeping Camp), décor et personnage
  local ex = T.EXP()
  ex.zone = "swamp"
  ex.combat, ex.fight = nil, nil
  ns.Expedition.openEvent(ex, "temple_steps")
  ex.phase = "event"
  ns.UI.refresh()
  H.settle()
  check("rencontre Temple Steps : décor des marches du temple, réponses", ns.Controller.scene() == "swamp_temple"
    and T.currentKind() == "event", tostring(ns.Controller.scene()) .. " " .. tostring(T.currentKind()))
  snap("zone-swamp-event", true)

  -- 4. Décors peints : sept scènes, couches valides, dégradés et formes fondues, palette verte
  local Sc = ns.Scene
  local keys = { "swamp_road", "swamp_night", "swamp_camp", "swamp_shop", "swamp_temple", "swamp_pool", "swamp_strand" }
  local okLv, counts = true, {}
  for _, key in ipairs(keys) do
    Sc.set({ scene = key, board = true })
    local g = Sc.paints[key]
    counts[#counts + 1] = key .. " " .. (g and #g or 0)
    if not g or #g < 100 or #g > 1200 then okLv = false end
    for _, tx in ipairs(g or {}) do
      local layer, sub = rawget(tx, "_layer"), rawget(tx, "_sub") or 0
      if not ((layer == "BACKGROUND" and sub >= -8 and sub <= 7) or (layer == "BORDER" and sub >= -8 and sub < 0)) then
        okLv = false
      end
    end
    if SNAP then R.svg(H, Sc.decor, SNAP .. "/decor-" .. key .. ".svg", key) end
  end
  check("décors du marais : sept paysages peints, couches sous l'illustration, 100 à 1200 régions", okLv,
    table.concat(counts, ", "))
  local Z = ns.Zones.swamp.scenes
  check("la zone porte ses décors (route, colline, camp, marchand, nuit, boss, côte)", Z.road == "swamp_road"
    and Z.night == "swamp_night" and Z.camp == "swamp_camp" and Z.shop == "swamp_shop" and Z.hill == "swamp_temple"
    and Z.mine == "swamp_pool" and Z.coast == "swamp_strand")
  local pal = Art.palettes.swamp
  local sky, ground = Art.hex(pal.sky[2]), Art.hex(pal.fieldsNear[1])
  check("palette : ciel et sol vert sombre (vert >= rouge, sol sombre), eau, mousse", sky[2] >= sky[1] and ground[2] >= ground[1]
    and ground[1] + ground[2] + ground[3] < 1.0 and pal.water and pal.moss)
end
