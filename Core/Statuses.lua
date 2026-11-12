-- États. Règles de durée :
--  * duration = true : la valeur est un nombre de tours ; elle baisse de 1 à la fin
--    de chaque round (après le tour ennemi). Un état posé pendant le tour ennemi
--    saute la baisse suivante, pour durer pendant le tour du joueur ET l'attaque
--    ennemie suivante.
--    Bienfait (duration sans debuff) que le joueur se pose pendant son tour : il saute
--    aussi la baisse de ce round. « Expiation N tours » = le reste du tour en cours
--    + les N tours suivants du joueur. Ré-empilement : les tours s'additionnent, sans
--    jamais compter deux fois le tour en cours. Si l'état est déjà protégé (posé ce
--    tour-ci), on ajoute N ; s'il vient d'un tour précédent, sa valeur inclut le tour en
--    cours, on retire donc 1 avant d'ajouter N. Ex. : Expiation 1 au tour 1, puis
--    Expiation 1 au tour 2 => active jusqu'à la fin du tour 3 ; deux Expiation 1 au
--    tour 1 => jusqu'à la fin du tour 3 aussi.
--    Les affaiblissements posés par le joueur sur les ennemis n'ont pas ce report.
--  * pain / regen : se déclenchent au début du tour du porteur, puis baissent de 1.
--  * stunned : consommé quand le porteur perd son tour. Les boss y sont immunisés.
--  * halved : retiré au début du tour du joueur.
--  * force : permanent pour le combat.
--  * max = N : plafond de la valeur (Parry 3) ; flag = true : présent ou non (valeur 1, sans nombre).
--  * clearAtTurnStart = true : retiré au début du tour du joueur.
local _, ns = ...

local S = ns.Statuses

S.armor_broken = { name = "Sundered", debuff = true, duration = true,
  text = "Takes 25% more damage." }
S.demoralized = { name = "Demoralized", debuff = true, duration = true,
  text = "Deals 25% less damage." }
S.atonement = { name = "Atonement", duration = true,
  text = "Each card that deals damage restores 2 HP." }
S.pain = { name = "DoT", debuff = true,
  text = "Takes X damage at the start of its turn, then X drops by 1. Ignores Absorb." }
S.regen = { name = "Regen",
  text = "Heals X at the start of its turn, then X drops by 1." }
-- turns : affichage seulement (le nombre compte des tours perdus, sablier sur les cartes) ;
-- les règles n'en tiennent pas compte.
S.stunned = { name = "Stunned", debuff = true, turns = true,
  text = "Loses its next turn." }
S.halved = { name = "Pain Suppression", clearAtTurnStart = true,
  text = "Damage taken halved until the next turn." }
S.force = { name = "Strength",
  text = "Deals X more damage per hit." }
-- Instant (état commun, Mage et Shaman) : se cumule, se garde d'un tour à l'autre ; la prochaine carte
-- Cast en consomme 1 et se résout tout de suite (Combat.isInstant), sans emplacement ni interruption.
S.instant = { name = "Instant",
  text = "The next Cast card resolves at once." }
