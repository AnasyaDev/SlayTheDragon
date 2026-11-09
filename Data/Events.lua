-- Rencontres (étapes « Rencontre » de la carte). Une rencontre :
--   name, act (nil = tous les actes), tier (palier de la Ligue des explorateurs, 0..3),
--   text, choices = { { label, text (conséquence affichée), after (texte après coup), effects } }
-- Effets (données, interprétés par Core/Expedition.lua) :
--   { "heal", n }          soigne n PV            { "healPct", f }      soigne f × PV max
--   { "loseHp", n }        perd n PV (jamais sous 1)   { "maxHp", n }    +n PV max (et +n PV)
--   { "gold", n }          gagne n po             { "pay", n }          paie n po (choix grisé sinon)
--   { "card", id, up = b } ajoute une carte précise
--   { "cardChoice", n = 3, rarity = "common" }   une carte au choix parmi n (ou passer)
--   { "relic" }            un bibelot tiré au hasard     { "potion" }   une potion tirée au hasard
--   { "upgradeRandom", n } améliore n cartes au hasard
--   { "upgrade" }          améliore une carte au choix   { "remove" }  retire une carte au choix
--   { "fight", groupe, gold = n }  combat (groupe de ns.Encounters de l'acte), récompense +n po
-- Un choix a au plus une suite interactive : fight, upgrade/remove, ou une récompense
-- (gold, cardChoice, relic, potion).
local _, ns = ...

ns.Events = ns.Events or {}
local E = ns.Events

E.saldean_farm = {
  name = "La ferme des Saldean", act = 1, tier = 0,
  text = "Sur la route poussiéreuse, Salma Saldean t'appelle depuis le seuil de sa ferme : "
    .. "« Tu as l'air affamé, voyageur. Entre donc, la marmite est encore chaude ! »",
  choices = {
    { label = "Manger la soupe", text = "Soigne 10 PV.",
      after = "Une soupe épaisse aux légumes du potager. Tu te sens revigoré.",
      effects = { { "heal", 10 } } },
    { label = "Apprendre sa recette", text = "Une carte commune au choix parmi 3.",
      after = "Salma te confie le secret de son bouillon, griffonné au dos d'un vieux registre.",
      effects = { { "cardChoice", n = 3, rarity = "common" } } },
    { label = "Aider le fermier Saldean", text = "Perds 5 PV. +5 PV max.",
      after = "Une après-midi à arracher les mauvaises herbes. Dur, mais ça forge.",
      effects = { { "loseHp", 5 }, { "maxHp", 5 } } },
  },
}

E.defias_caravan = {
  name = "La carriole renversée", act = 1, tier = 0,
  text = "Une carriole gît en travers de la route de Ruisselune. Deux bandits défias fouillent "
    .. "les caisses pendant que le cocher, coincé sous une roue, appelle à l'aide.",
  choices = {
    { label = "Charger les bandits", text = "Combat. Récompense habituelle et 20 po de plus.",
      after = "Les bandits ne s'attendaient pas à toi.",
      effects = { { "fight", "normal", gold = 20 } } },
    { label = "Dégager le cocher", text = "Perds 5 PV. Reçois une potion.",
      after = "Tu soulèves la roue à la force des bras. Le cocher te glisse une fiole en remerciement.",
      effects = { { "loseHp", 5 }, { "potion" } } },
    { label = "Passer ton chemin", text = "Rien ne se passe.",
      after = "Ce n'est pas ton problème. Les cris s'éteignent derrière toi.",
      effects = {} },
  },
}

E.sentinel_hill = {
  name = "La Colline des sentinelles", act = 1, tier = 0,
  text = "Au pied de la tour, le Peuple de la Colline des sentinelles s'entraîne. "
    .. "Gryan Fortmanteau te jauge : « On a besoin de bras. Et toi, tu as besoin de quoi ? »",
  choices = {
    { label = "S'entraîner avec la milice", text = "Perds 6 PV. Améliore 2 cartes au hasard.",
      after = "Des heures de passes d'armes avec les miliciens. Tes gestes sont plus sûrs.",
      effects = { { "loseHp", 6 }, { "upgradeRandom", 2 } } },
    { label = "Faire un don au Peuple", text = "Paie 40 po. Retire une carte de ton deck.",
      after = "Gryan hoche la tête. « Laisse-nous ce qui t'encombre, on en fera bon usage. »",
      effects = { { "pay", 40 }, { "remove" } } },
    { label = "Repartir", text = "Rien ne se passe.",
      after = "Tu salues la garde et reprends la route.",
      effects = {} },
  },
}
