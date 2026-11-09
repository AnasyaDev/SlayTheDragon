-- États. Règles de durée :
--  * duration = true : la valeur est un nombre de tours ; elle baisse de 1 à la fin
--    de chaque round (après le tour ennemi). Un état posé pendant le tour ennemi
--    saute la baisse suivante, pour durer pendant le tour du joueur ET l'attaque
--    ennemie suivante.
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
  text = "Chaque carte qui inflige des dégâts te rend 2 PV." }
S.pain = { name = "Douleur", debuff = true,
  text = "Subit X dégâts au début de son tour, puis X baisse de 1. Ignore l'Absorption." }
S.regen = { name = "Récupération",
  text = "Soigne X au début de son tour, puis X baisse de 1." }
S.stunned = { name = "Étourdi", debuff = true,
  text = "Perd son prochain tour." }
S.halved = { name = "Suppression de la douleur",
  text = "Dégâts subis divisés par deux jusqu'à ton prochain tour." }
S.force = { name = "Force",
  text = "Inflige X dégâts de plus par coup." }
