-- Zone 2 de la campagne : Duskwood (`duskwood`). Fiche : docs/zones/duskwood.md ; décisions : docs/zones/decisions.md ;
-- guide de l'agent de zone : docs/zones.md. Fichier vide tant que la zone n'est pas écrite (elle reste
-- « Coming later ») : ennemis (ns.Enemies), groupes (ns.Encounters.duskwood), rencontres (ns.Events, zone = "duskwood"),
-- commun débloqué par la zone (cartes neutres, bibelots, potions, cases de parcours : tier = 2), bibelots de clé,
-- puis en dernier `ns.Zones.duskwood.encounters = "duskwood"` (la zone devient jouable).
local _, ns = ...
