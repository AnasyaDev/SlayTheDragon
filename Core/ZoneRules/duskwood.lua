-- Règles de la zone Duskwood (`duskwood`) : mécanique de la fiche docs/zones/duskwood.md, sur le socle ns.ZoneRules
-- (contrat et liste des crochets : docs/zones.md). Fichier vide tant que la zone n'est pas écrite : aucune
-- règle déclarée, aucun coût pour le moteur.
--   ns.ZoneRule.define("duskwood", { init = …, hooks = { … }, run = { … }, campfire = { … } })
--   états (ns.Statuses), effets de carte (ns.Effects), actions d'ennemis (ns.Combat.ENEMY_ACTIONS), conditions
--   et montants (ns.Combat.ENEMY_CONDITIONS / ENEMY_AMOUNTS), effets de rencontre (ns.Expedition.EFFECTS), cases
--   de parcours (ns.Expedition.nodeKind), mots du langage (ns.Language.zoneKeyword).
local _, ns = ...
