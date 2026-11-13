-- Zone 5 de la campagne : Swamp of Sorrows (`swamp`). Fiche : docs/zones/swamp.md ; décisions : docs/zones/decisions.md ;
-- guide de l'agent de zone : docs/zones.md. Fichier vide tant que la zone n'est pas écrite (elle reste
-- « Coming later ») : ennemis (ns.Enemies), groupes (ns.Encounters.swamp), rencontres (ns.Events, zone = "swamp"),
-- commun débloqué par la zone (cartes neutres, bibelots, potions, cases de parcours : tier = 5), bibelots de clé,
-- puis en dernier `ns.Zones.swamp.encounters = "swamp"` (la zone devient jouable).
local _, ns = ...
