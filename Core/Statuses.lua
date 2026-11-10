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
local _, ns = ...

local S = ns.Statuses

S.armor_broken = { name = "Armure fracassée", debuff = true, duration = true,
  text = "Subit 25 % de dégâts en plus." }
S.demoralized = { name = "Démoralisé", debuff = true, duration = true,
  text = "Inflige 25 % de dégâts en moins." }
S.atonement = { name = "Expiation", duration = true,
  text = "Chaque carte qui inflige des dégâts rend 2 PV." }
S.pain = { name = "Douleur", debuff = true,
  text = "Subit X dégâts au début de son tour, puis X baisse de 1. Ignore l'Absorption." }
S.regen = { name = "Récupération",
  text = "Soigne X au début de son tour, puis X baisse de 1." }
S.stunned = { name = "Étourdi", debuff = true,
  text = "Perd son prochain tour." }
S.halved = { name = "Suppression de la douleur",
  text = "Dégâts subis divisés par deux jusqu'au prochain tour." }
S.force = { name = "Force",
  text = "Inflige X dégâts de plus par coup." }
