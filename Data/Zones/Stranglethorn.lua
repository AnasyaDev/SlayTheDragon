-- Zone 4 de la campagne : Stranglethorn Vale (`stranglethorn`). Fiche : docs/zones/stranglethorn.md ; décisions : docs/zones/decisions.md ;
-- guide de l'agent de zone : docs/zones.md. Fichier vide tant que la zone n'est pas écrite (elle reste
-- « Coming later ») : ennemis (ns.Enemies), groupes (ns.Encounters.stranglethorn), rencontres (ns.Events, zone = "stranglethorn"),
-- commun débloqué par la zone (cartes neutres, bibelots, potions, cases de parcours : tier = 4), bibelots de clé,
-- puis en dernier `ns.Zones.stranglethorn.encounters = "stranglethorn"` (la zone devient jouable).
local _, ns = ...
