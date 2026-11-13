-- Rencontres (étapes « Rencontre » de la carte). Liste commentée et intentions : docs/rencontres.md.
--
-- Une rencontre :
--   name      titre affiché
--   zone      zone (id de ns.Zones, nil = toutes)   tier   palier commun (0 d'emblée, N = zone N gagnée par le compte)
--   rarity    "common" (ordinaire) | "rare" (poids faible) | "story" (une fois par compte)
--   weight    poids de tirage (défaut : Expedition.EVENT_WEIGHT selon rarity : 10 / 3 / 8)
--   once      true = une fois par compte (drapeau « event:<id> » posé à l'entrée) ; ou nom de drapeau
--   when      conditions de déclenchement (voir plus bas), toutes requises, évaluées à l'entrée du nœud
--   speaker   nom du personnage qui parle   npc   identifiant libre du personnage (modèle 3D)
--   scene     décor : farm | road | coast | mine | hill | camp | ruins
--   text      ce que dit ou voit le personnage (2 à 3 phrases)
--   choices   2 ou 3 réponses (plus une éventuelle réponse conditionnelle) :
--     label    bouton
--     outcome  ce que la réponse donne ou coûte, en clair (« +10 PV », « 50 % : 60 po, sinon -8 PV »)
--     hidden   true = l'interface affiche « ? » au lieu de outcome (rare : rencontres rares ou à histoire)
--     when     conditions : réponse affichée désactivée avec la raison si elles manquent
--     effects  liste d'effets (données)
--     result   texte affiché après le choix
--   (text et after sont recopiés de outcome et result pour l'interface d'origine.)
--
-- Conditions (Core/Expedition.lua, X.CONDITIONS) : { "hpBelow", 0.5 } PV < 50 % ;
--   { "hpAbove", 0.6 } PV >= 60 % ; { "gold", n } ; { "relic", id } ; { "noRelic", id } ;
--   { "potion" } une potion en poche ; { "card", id } ; { "key", n } clé mythique >= n ;
--   { "flag", nom } / { "noFlag", nom } drapeau de compte (connu au départ de l'expédition) ;
--   { "floor", n } étape >= n ; { "unlocked", idCarte } carte débloquée (neutre : palier commun).
--   Champ text = raison affichée à la place de celle par défaut ; hide = true : réponse absente (et
--   non grisée) tant que la condition manque.
--
-- Effets (données, interprétés par Core/Expedition.lua) :
--   { "heal", n }   { "healPct", f }   { "loseHp", n } (jamais sous 1 PV)
--   { "maxHp", n } +n PV max et +n PV      { "loseMaxHp", n } -n PV max (PV ramenés au max)
--   { "gold", n }   { "pay", n } (réponse désactivée sans l'or)   { "loseGold", n } (ce qu'on a)
--   { "card", id, up = b }   { "cardChoice", n = 3, rarity = "common" } (une parmi n, ou passer ;
--     neutral = true : parmi les cartes neutres débloquées au lieu des cartes de la classe)
--   { "relic" } bibelot tiré   { "relic", id } bibelot précis (désactivé si déjà possédé)
--   { "potion" } potion tirée  { "potion", id } potion précise   { "losePotion" } (requiert une potion)
--   { "upgradeRandom", n }   { "upgrade" } / { "remove" } / { "dupe" } : carte au choix (sélection)
--   { "fight", groupe, kind = "combat"|"elite", gold = n } : combat (groupe de ns.Encounters de
--     l'acte, défaut selon kind), récompense habituelle du genre + n po
--   { "gamble", p, win = {effets}, lose = {effets}, winText, loseText } : pari tiré à l'entrée
--   { "flag", nom } : drapeau de compte, reporté dans la méta en fin d'expédition
-- Tout le hasard (cartes, bibelots, potions, récompense de combat, pari) est tiré à l'entrée
-- de la rencontre et stocké dans exp.event.rolls. Une réponse a au plus une suite interactive
-- (combat ou sélection de carte) ; une récompense de la même réponse s'ouvre après la sélection.
local _, ns = ...

ns.Events = ns.Events or {}
local E = ns.Events

local function event(id, t)
  t.rarity = t.rarity or "common"
  for _, ch in ipairs(t.choices) do
    ch.result = ch.result or ""
    ch.text = ch.hidden and "?" or ch.outcome
    ch.after = ch.result
  end
  E[id] = t
end

---------------------------------------------------------------------------
-- Ordinaires
---------------------------------------------------------------------------

event("saldean_farm", {
  name = "The Saldean Farm", zone = "westfall", tier = 0,
  speaker = "Salma Saldean", npc = "salma_saldean", scene = "farm",
  text = "\"You look hungry, traveler. Come in, there's stew left! And if you have a moment, "
    .. "my husband could use some help in the fields.\"",
  choices = {
    { label = "Eat the stew", outcome = "+10 HP",
      result = "Salma serves you a bowl of stew. You leave rested.",
      effects = { { "heal", 10 } } },
    { label = "Learn her recipe", outcome = "One of 3 common cards",
      result = "Salma copies her stew recipe onto the back of an old ledger for you.",
      effects = { { "cardChoice", n = 3, rarity = "common" } } },
    { label = "Help Farmer Saldean", outcome = "-5 HP, then +5 max HP",
      result = "You weed the fields all afternoon and come out tougher.",
      effects = { { "loseHp", 5 }, { "maxHp", 5 } } },
    -- carte neutre (docs/cartes-neutres.md) : la recette de la fermière
    { label = "Ask for her dumplings", outcome = "Smoked Desert Dumplings (card)",
      result = "Salma wraps a batch of her smoked dumplings for the road.",
      effects = { { "card", "smoked_desert_dumplings" } } },
  },
})

event("defias_caravan", {
  name = "The Overturned Wagon", zone = "westfall", tier = 0,
  speaker = "Farmer Furlbrow", npc = "farmer_furlbrow", scene = "road",
  text = "\"Help! The Defias who took our farm came back for our wagon. It turned over on me, "
    .. "and they're looting the crates!\"",
  choices = {
    { label = "Charge the bandits", outcome = "Fight: usual reward + 20g",
      result = "You attack the Defias bandits.",
      effects = { { "fight", "normal", gold = 20 } } },
    { label = "Free Furlbrow", outcome = "-5 HP, a potion",
      result = "You lift the wagon and free Farmer Furlbrow. He gives you a potion from his crates.",
      effects = { { "loseHp", 5 }, { "potion" } } },
    { label = "Move on", outcome = "Nothing",
      result = "You leave Farmer Furlbrow under his wagon and continue down the road.",
      effects = {} },
    -- carte neutre : les Défias font sauter les portes des Mortemines
    { label = "Search the wagon", outcome = "-3 HP, Rough Dynamite (card)",
      result = "You cut your hands on the broken crates and find a stick of Defias dynamite.",
      effects = { { "loseHp", 3 }, { "card", "rough_dynamite" } } },
  },
})

event("sentinel_hill", {
  name = "Sentinel Hill", zone = "westfall", tier = 0,
  speaker = "Gryan Stoutmantle", npc = "gryan_stoutmantle", scene = "hill",
  text = "\"The People's Militia defends Westfall against the Defias, and we're short on "
    .. "everything. If you want to help us, you're welcome here.\"",
  choices = {
    { label = "Train with the militia", outcome = "-6 HP, upgrade 2 random cards",
      result = "You train for hours with the militiamen and improve.",
      effects = { { "loseHp", 6 }, { "upgradeRandom", 2 } } },
    { label = "Donate to the militia", outcome = "Pay 40g, remove a card from the deck",
      result = "\"Thank you. Leave us whatever weighs you down too, the militia will put it to good use.\"",
      effects = { { "pay", 40 }, { "remove" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You salute the guard and head back on the road.",
      effects = {} },
    -- Réponse conditionnelle : le tabard de Hurlevent ouvre l'armurerie.
    { label = "Show your Stormwind Tabard", outcome = "One of 3 uncommon cards",
      when = { { "relic", "stormwind_tabard" } },
      result = "Gryan recognizes the tabard. \"A soldier of Stormwind? Help yourself at the armory.\"",
      effects = { { "cardChoice", n = 3, rarity = "uncommon" } } },
  },
})

event("coast_murlocs", {
  name = "The Militia's Fish Traps", zone = "westfall", tier = 0,
  speaker = "Scout Galiaan", npc = "scout_galiaan", scene = "coast",
  text = "\"Murlocs took the militia's dock on the coast, and our fish traps with it. That fish "
    .. "feeds Sentinel Hill. Run them off, or go pull up the traps yourself.\"",
  choices = {
    { label = "Retake the dock", outcome = "Fight 4 murlocs: usual reward + 15g",
      result = "You attack the murlocs on the dock.",
      effects = { { "fight", "event_murlocs", gold = 15 } } },
    { label = "Pull up the traps yourself", outcome = "50%: a potion and 20g, else -7 HP",
      effects = { { "gamble", 0.5,
        win = { { "potion" }, { "gold", 20 } },
        winText = "In the traps, you find an intact potion and a coin purse.",
        lose = { { "loseHp", 7 } },
        loseText = "A murloc was hiding in a trap. It bites you and runs off." } } },
    { label = "Share his fried fish", outcome = "+8 HP",
      result = "Galiaan shares his fried fish with you. \"Eat. There's enough for two.\"",
      effects = { { "heal", 8 } } },
  },
})

event("jangolode_prospector", {
  name = "The Jangolode Vein", zone = "westfall", tier = 0,
  speaker = "Thor, gryphon master", npc = "thor", scene = "mine",
  text = "\"There's still gold in Jangolode Mine. The Defias have gone to eat, and my gryphons "
    .. "can wait an hour. Help me dig, or fund my claim, and we'll split it.\"",
  choices = {
    { label = "Dig with him", outcome = "-8 HP, +45g",
      result = "You dig for hours and find a nugget. Thor splits it with you.",
      effects = { { "loseHp", 8 }, { "gold", 45 } } },
    { label = "Fund his claim", outcome = "Pay 30g. 50%: 80g",
      effects = { { "pay", 30 }, { "gamble", 0.5,
        win = { { "gold", 80 } },
        winText = "Thor strikes gold and pays you back with interest.",
        lose = {},
        loseText = "Thor finds nothing. \"Next time for sure!\"" } } },
    { label = "Buy his flask", outcome = "Pay 15g, a potion",
      result = "\"Dwarven stout. Drink it when a fight goes badly.\"",
      effects = { { "pay", 15 }, { "potion" } } },
    -- carte neutre : la dynamite des mineurs
    { label = "Buy his dynamite", outcome = "Pay 20g, Rough Dynamite (card)",
      result = "\"Keep it away from the lantern.\" Thor hands you a stick of dynamite.",
      effects = { { "pay", 20 }, { "card", "rough_dynamite" } } },
  },
})

event("moonbrook_refugees", {
  name = "The Moonbrook Refugees", zone = "westfall", tier = 1,
  speaker = "Verna Furlbrow", npc = "verna_furlbrow", scene = "camp",
  text = "\"The Defias drove us off our farm, and the Moonbrook families with us. We have wounded, "
    .. "and nothing left to treat them or to feed ourselves. Any help is welcome.\"",
  choices = {
    { label = "Tend to the wounded", outcome = "-6 HP, upgrade a card of your choice",
      result = "You spend the day tending to the wounded. You gain experience from it.",
      effects = { { "loseHp", 6 }, { "upgrade" } } },
    { label = "Give them 35g", outcome = "Pay 35g, +6 max HP",
      result = "Verna thanks you and asks the Light to protect you.",
      effects = { { "pay", 35 }, { "maxHp", 6 } } },
    -- carte neutre (remplace « Move on » : quatre réponses au plus à l'écran) : les secours aux blessés
    { label = "Roll bandages with her", outcome = "-4 HP, Heavy Silk Bandage (card)",
      result = "You tear and roll silk bandages with Verna until nightfall. She lets you keep some.",
      effects = { { "loseHp", 4 }, { "card", "heavy_silk_bandage" } } },
    -- Réponse conditionnelle : il faut une potion à donner.
    { label = "Leave them a potion", outcome = "Lose a potion, upgrade 2 random cards",
      when = { { "potion" } },
      result = "The potion heals an old priest. He teaches you his prayers.",
      effects = { { "losePotion" }, { "upgradeRandom", 2 } } },
  },
})

event("herbalist", {
  name = "Heather's Remedies", zone = "westfall", tier = 1,
  speaker = "Innkeeper Heather", npc = "innkeeper_heather", scene = "hill",
  -- N'apparaît que si l'on est mal en point.
  when = { { "hpBelow", 0.5 } },
  text = "\"By the Light, you can barely stand! Sit down. I keep remedies for the militia; they "
    .. "aren't free, but they work. Or help me pick peacebloom behind the inn.\"",
  choices = {
    { label = "Pay for her remedies", outcome = "Pay 25g, heal 35% of max HP",
      result = "Heather puts a poultice on your wounds.",
      effects = { { "pay", 25 }, { "healPct", 0.35 } } },
    { label = "Pick with her", outcome = "+12 HP",
      result = "You pick peacebloom with her and chew the leaves she gives you.",
      effects = { { "heal", 12 } } },
    -- carte neutre de palier 2 dans une rencontre de palier 1 : réponse absente tant qu'elle n'est pas
    -- débloquée (condition « unlocked », hide = true)
    { label = "Buy one of her elixirs", outcome = "Pay 30g, Elixir of Superior Defense (card)",
      when = { { "unlocked", "elixir_of_superior_defense", hide = true } },
      result = "Heather corks a bottle of her best elixir. \"One sip each morning.\"",
      effects = { { "pay", 30 }, { "card", "elixir_of_superior_defense" } } },
  },
})

event("scarecrow_field", {
  name = "The Creaking Scarecrow", zone = "westfall", tier = 2,
  speaker = "Farmer Molsen", npc = "farmer_molsen", scene = "farm",
  text = "\"That scarecrow moves at night, I tell you! Yesterday it was at the other end of "
    .. "the field. Must be Defias sorcery. Burn it, please.\"",
  choices = {
    { label = "Burn the scarecrow", outcome = "-5 HP, remove a card from the deck",
      result = "The straw catches all at once and burns your hands. Molsen thanks you.",
      effects = { { "loseHp", 5 }, { "remove" } } },
    { label = "Search its straw", outcome = "-4 max HP, one of 3 rare cards",
      result = "You find a Defias scroll in the straw. Its magic weakens you.",
      effects = { { "loseMaxHp", 4 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Leave it alone", outcome = "Nothing",
      result = "You leave Farmer Molsen to his scarecrow.",
      effects = {} },
  },
})

event("lighthouse_keeper", {
  name = "The Westfall Lighthouse", zone = "westfall", tier = 2,
  speaker = "Captain Grayson", npc = "captain_grayson", scene = "coast",
  -- Le phare est au bout de la côte : seulement après l'étape 4.
  when = { { "floor", 4 } },
  text = "\"The light must burn all night, or ships will run aground on the reefs. I'm dead, "
    .. "I can't hold a blade, and the murlocs are prowling. Can you keep watch for me?\"",
  choices = {
    { label = "Tend the light all night", outcome = "-10 HP, copy a card in the deck",
      result = "You hold the murlocs off on the lighthouse stairs until dawn. The light stays lit.",
      effects = { { "loseHp", 10 }, { "dupe" } } },
    { label = "Sleep at the lighthouse", outcome = "Heal 30% of max HP",
      result = "Grayson shows you the old keeper's bed near the fire. You sleep until morning.",
      effects = { { "healPct", 0.30 } } },
    -- carte neutre : la réserve de matériel avant le boss
    { label = "Search the lighthouse stores", outcome = "-6 HP, Arcane Bomb (card)",
      result = "A shelf gives way on the stairs. Under it, you find an arcane bomb in its crate.",
      effects = { { "loseHp", 6 }, { "card", "arcane_bomb" } } },
  },
})

event("gnoll_raiders", {
  name = "The Riverpaw Raiders", zone = "westfall", tier = 3,
  speaker = "Graymaw", npc = "riverpaw_gnoll", scene = "camp",
  -- Les meutes Rivepatte ne s'aventurent sur la route qu'à partir de la clé +2.
  when = { { "key", 2 } },
  text = "\"You give gold. Or you give blood.\" Graymaw and his Riverpaw raiders block "
    .. "your path. \"Graymaw not picky.\"",
  choices = {
    { label = "Face the pack", outcome = "Fight 3 gnolls: usual reward + 30g",
      result = "You attack Graymaw's pack.",
      effects = { { "fight", "event_gnolls", gold = 30 } } },
    { label = "Pay the toll", outcome = "Pay 30g",
      result = "Graymaw bites the coin, satisfied. \"You pass. You come back.\"",
      effects = { { "pay", 30 } } },
    { label = "Flee across the fields", outcome = "-8 HP",
      result = "You flee across the fields. An arrow hits you.",
      effects = { { "loseHp", 8 } } },
  },
})

---------------------------------------------------------------------------
-- Rares
---------------------------------------------------------------------------

event("goblin_peddler", {
  name = "The Defias Profiteer", zone = "westfall", tier = 1, rarity = "rare",
  speaker = "Defias Profiteer", npc = "defias_profiteer", scene = "road",
  text = "\"Parts from the Brotherhood's workshops, no questions asked. This cog came off a real "
    .. "harvest golem. It works, but it takes a bit of your health.\"",
  choices = {
    { label = "Take the cog", outcome = "-8 max HP, Harvest Golem Cog (relic)",
      result = "The profiteer fastens the cog to your chest. You feel weaker at once.",
      effects = { { "loseMaxHp", 8 }, { "relic", "harvest_cog" } } },
    { label = "Play the shell game", outcome = "Pay 40g. 50%: 100g",
      effects = { { "pay", 40 }, { "gamble", 0.5,
        win = { { "gold", 100 } },
        winText = "You find the right cup. The profiteer grimaces and pays.",
        lose = {},
        loseText = "The cup is empty. The profiteer pockets your gold." } } },
    { label = "Politely decline", outcome = "Nothing",
      result = "\"Your loss.\" The profiteer walks off toward Moonbrook.",
      effects = {} },
    -- carte neutre : un marchand défias, le matériel des mines
    { label = "Buy an iron grenade", outcome = "Pay 35g, Iron Grenade (card)",
      result = "\"Pull the pin and throw it. We use them to clear the mine tunnels.\"",
      effects = { { "pay", 35 }, { "card", "iron_grenade" } } },
  },
})

event("harvest_watcher", {
  name = "The Sleeping Harvester", zone = "westfall", tier = 0, rarity = "rare",
  speaker = "Farmer Saldean", npc = "farmer_saldean", scene = "farm",
  -- Proposé seulement en bonne santé : la réponse principale est un combat d'élite.
  when = { { "hpAbove", 0.6 } },
  text = "\"Quiet! The Defias left a chest in my field, and that harvest golem guards it. If it "
    .. "wakes up, it'll attack us both. Can you pick a lock?\"",
  choices = {
    { label = "Wake the golem", outcome = "Elite fight: elite reward + 40g",
      result = "The golem's eyes light up. Saldean dives into the hay.",
      effects = { { "fight", "event_golem", kind = "elite", gold = 40 } } },
    { label = "Quietly pick the chest", outcome = "40%: a relic, else -12 HP",
      effects = { { "gamble", 0.4,
        win = { { "relic" } },
        winText = "The chest opens without a sound. The golem is still asleep.",
        lose = { { "loseHp", 12 } },
        loseText = "The lock clicks loudly. The golem wakes up and hits you." } } },
    { label = "Tiptoe back out", outcome = "Nothing",
      result = "Saldean watches you leave, disappointed.",
      effects = {} },
  },
})

---------------------------------------------------------------------------
-- À histoire : Tobin, en deux temps (une fois par compte chacun)
---------------------------------------------------------------------------

-- Premier temps : le choix fixe la suite (drapeau tobin_jailed ou tobin_spared).
event("tobin_thief", {
  name = "The Bread Thief", zone = "westfall", tier = 0, rarity = "story", once = true,
  speaker = "Tobin", npc = "tobin_young", scene = "farm",
  text = "You grab a skinny boy by the collar, his pockets full of bread stolen from the Saldeans. "
    .. "\"Let go of me! The Defias say they feed anyone who joins them. I'm just hungry.\"",
  choices = {
    { label = "Turn him in to the militia", outcome = "+30g. He will remember.",
      result = "Gryan Stoutmantle counts out the bounty without a glance at the boy. \"He'll learn.\"",
      effects = { { "gold", 30 }, { "flag", "tobin_jailed" } } },
    { label = "Buy him a real meal", outcome = "Pay 20g. He will remember.",
      result = "Tobin wolfs down the loaf, then runs off toward Sentinel Hill. \"I'll pay you back!\"",
      effects = { { "pay", 20 }, { "flag", "tobin_spared" } } },
    { label = "Let him go", outcome = "Nothing",
      result = "Tobin runs off into the wheat fields.",
      effects = {} },
  },
})

-- Second temps, s'il a été nourri : retrouvé dans la milice. Débloque le Canif de Tobin.
event("tobin_scout", {
  name = "The Hill Lookout", zone = "westfall", tier = 0, rarity = "story", once = true,
  speaker = "Tobin, militia lookout", npc = "tobin_scout", scene = "hill",
  when = { { "flag", "tobin_spared" } },
  text = "\"Hey! Remember me? The Saldeans' bread! I'm a lookout for the People's Militia "
    .. "now. I kept something for you.\"",
  choices = {
    { label = "Accept his pocketknife", outcome = "Tobin's Pocketknife (relic)",
      result = "\"I stole it from a Defias. It's better off with you.\"",
      effects = { { "relic", "tobin_knife" } } },
    { label = "Ask what he knows about the Defias", outcome = "One of 3 rare cards",
      result = "Tobin draws you a map of the Defias tunnels and explains their habits.",
      effects = { { "cardChoice", n = 3, rarity = "rare" } } },
  },
})

-- Second temps, s'il a été livré : il a rejoint la Confrérie.
event("tobin_defias", {
  name = "The Red Kerchief", zone = "westfall", tier = 0, rarity = "story", once = true,
  speaker = "Tobin, Defias cutthroat", npc = "tobin_defias", scene = "road",
  when = { { "flag", "tobin_jailed" } },
  text = "\"Remember me? The militia kept me in a cell for six months. The Defias got me "
    .. "out. Now hand over your purse.\"",
  choices = {
    { label = "Fight him", outcome = "Fight Tobin and his henchmen: usual reward + 25g",
      result = "Tobin and his henchmen attack you.",
      effects = { { "fight", "event_tobin", gold = 25 } } },
    { label = "Pay back the bounty", outcome = "Pay 30g",
      result = "Tobin takes the purse. \"We're even.\"",
      effects = { { "pay", 30 } } },
    -- La surprise fait l'intérêt : parler suffit, mais rien ne l'annonce.
    { label = "Mention the Saldeans' bread", outcome = "He lowers his blade: nothing to pay", hidden = true,
      result = "Tobin sheathes his dagger. \"Get going, before I change my mind.\"",
      effects = {} },
  },
})
