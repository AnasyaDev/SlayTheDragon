-- Zone 6 de la campagne : Burning Steppes (`steppes`). Fiche : docs/zones/steppes.md ; décisions : docs/zones/decisions.md ;
-- guide de l'agent de zone : docs/zones.md. Fichier vide tant que la zone n'est pas écrite (elle reste
-- « Coming later ») : ennemis (ns.Enemies), groupes (ns.Encounters.steppes), rencontres (ns.Events, zone = "steppes"),
-- commun débloqué par la zone (cartes neutres, bibelots, potions, cases de parcours : tier = 6), bibelots de clé,
-- puis en dernier `ns.Zones.steppes.encounters = "steppes"` (la zone devient jouable).
local _, ns = ...
