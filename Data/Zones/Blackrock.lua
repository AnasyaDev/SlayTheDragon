-- Zone 7 de la campagne : Blackrock Mountain (`blackrock`). Fiche : docs/zones/blackrock.md ; décisions : docs/zones/decisions.md ;
-- guide de l'agent de zone : docs/zones.md. Fichier vide tant que la zone n'est pas écrite (elle reste
-- « Coming later ») : ennemis (ns.Enemies), groupes (ns.Encounters.blackrock), rencontres (ns.Events, zone = "blackrock"),
-- commun débloqué par la zone (cartes neutres, bibelots, potions, cases de parcours : tier = 7), bibelots de clé,
-- puis en dernier `ns.Zones.blackrock.encounters = "blackrock"` (la zone devient jouable).
local _, ns = ...
