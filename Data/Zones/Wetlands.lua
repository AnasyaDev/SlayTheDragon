-- Zone 3 de la campagne : Wetlands (`wetlands`). Fiche : docs/zones/wetlands.md ; décisions : docs/zones/decisions.md ;
-- guide de l'agent de zone : docs/zones.md. Fichier vide tant que la zone n'est pas écrite (elle reste
-- « Coming later ») : ennemis (ns.Enemies), groupes (ns.Encounters.wetlands), rencontres (ns.Events, zone = "wetlands"),
-- commun débloqué par la zone (cartes neutres, bibelots, potions, cases de parcours : tier = 3), bibelots de clé,
-- puis en dernier `ns.Zones.wetlands.encounters = "wetlands"` (la zone devient jouable).
local _, ns = ...
