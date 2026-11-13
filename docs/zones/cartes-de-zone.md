# Cartes de zone : les 35 cartes épiques

Fiche de conception (13/11/2026). Rien n'est codé. Elle remplace les sections « Cartes de zone » des sept
fiches `docs/zones/<id>.md`, écrites sans concertation (noms en double, cartes qui ne répondaient qu'à la
mécanique de leur zone).

## Règles retenues

- **Déblocage** : la première victoire d'une classe dans une zone débloque sa carte de cette zone, introuvable
  autrement. Ensuite, la carte entre dans la réserve de la classe (récompenses, marchand, rencontres), dans
  toutes les zones.
- **Rareté `epic`** (décision du joueur du 13/11/2026), au-dessus de `rare`. Dans les données : `rarity = "epic"`,
  `zone = "<id>"`, pas de `level` (champ prévu par `docs/zones.md`), `path` = la voie indiquée.
- **Pivot** : chaque carte ouvre un deck qui n'existe pas sans elle, ou retourne une règle de la classe. Le lien
  avec la mécanique de la zone est un bonus ; aucune ne perd sa valeur hors de sa zone.
- **Un nom = une carte** : sorts ou talents réels de la classe, absents de `Data/<Classe>.lua` (vérifié) et
  uniques dans les 35.
- **Sept directions par classe**, réparties entre les trois voies ; **quatre Powers au plus** par classe
  (20 Powers, 6 Attacks, 9 Skills en tout).
- **Progression** : la carte de Westfall se comprend en une lecture ; celles des Steppes et de Blackrock
  demandent de construire autour. Pas d'escalade de puissance : toutes sont épiques.
- **Texte** : langage exact des cartes (« Power. » / « Cast. » en tête, « Cooldown N. » / « Exhaust. » en fin,
  états en dernière ligne, aucun « you / your »). Le corps (sans les mots de plaque) tient en quatre lignes
  d'environ 22 caractères. Les « / » des tableaux sont des retours à la ligne.
- **Icônes** : présentes dans `~/Téléchargements/ICONS/` (source de `tools/build_media.py`), confirmées par
  `wow_icon_search` quand le pack ne les avait pas, et **non employées** par une carte existante
  (`UI/Art.lua`, `UI/Art/*.lua`). Huit icônes naturelles étaient déjà prises (par Slice and Dice, Defend,
  Slam, Ice Barrier, Shatter, Blazing Barrier, Dire Beast et la pastille de Rage) : remplacées, voir chaque ligne.
- **Statut** : *conservée* (carte d'une fiche gardée telle quelle, au texte près), *modifiée* (idée gardée,
  règle ou chiffres changés), *nouvelle*.

Colonne « Moteur » : crochet existant de `ns.ClassRules` / des Powers (`docs/classes.md`) ou point nouveau,
en un mot. Les points nouveaux sont regroupés en fin de fiche.

## Répartition par zone

| Zone | Priest | Warrior | Mage | Rogue | Hunter |
|---|---|---|---|---|---|
| 1 Westfall | Prayer of Mending | Shockwave | Mirror Image | Ghostly Strike | Call of the Wild |
| 2 Duskwood | Shadowy Apparitions | Enraged Regeneration | Alter Time | Sap | Trap Launcher |
| 3 Wetlands | Mind Spike | Sweeping Strikes | Water Elemental | Subterfuge | Beast Cleave |
| 4 Stranglethorn Vale | Power Infusion | Anger Management | Cold Snap | Deathmark | Black Arrow |
| 5 Swamp of Sorrows | Reflective Shield | Defensive Stance | Molten Armor | Leeching Poison | Exhilaration |
| 6 Burning Steppes | Vampiric Embrace | Death Wish | Touch of the Magi | Relentless Strikes | Kill Shot |
| 7 Blackrock Mountain | Spirit Shell | Avatar | Fingers of Frost | Cold Blood | Lone Wolf |

## Priest

Sept directions :
1. **Le soin devient l'attaque** (Holy) — Prayer of Mending.
2. **Le DoT nourrit l'Insanity**, sans attaque Shadow (Shadow) — Shadowy Apparitions.
3. **Le DoT devient un coup immédiat** (Shadow) — Mind Spike.
4. **Les Cast sacrés partent tout de suite** (Holy) — Power Infusion.
5. **L'Absorb frappe l'attaquant** (Discipline) — Reflective Shield.
6. **Le gros tour Shadow soigne** : le Shadow sans Discipline (Shadow) — Vampiric Embrace.
7. **Le soin en trop devient un rempart qui dure** (Discipline) — Spirit Shell.

| Zone | Nom | Coût / type / voie | Texte de base | Amélioré | Icône | Le deck qu'elle fait naître | Moteur | Statut |
|---|---|---|---|---|---|---|---|---|
| Westfall | Prayer of Mending | 2, Power, Holy | Power. / Each heal: deal the HP restored to a random enemy. | coût 1 | `spell_holy_prayerofmendingtga` | Renew, Holy Nova, Flash Heal, Greater Heal et l'Atonement (Solace, Radiance) tuent : le Holy encaisse, puis soigne pour frapper, avec peu de Smite. | nouveau `onHeal` | conservée (Steppes → Westfall) ; plein montant au lieu de la moitié |
| Duskwood | Shadowy Apparitions | 1, Power, Shadow | Power. / Each enemy DoT tick: +1 Insanity. | coût 0 | `ability_priest_shadowyapparition` | SW: Pain, Vampiric Touch, Mind Sear posent le DoT partout, puis Void Eruption ou Devouring Plague : un Shadow de Skills qui monte l'Insanity sans jouer Mind Blast ni Mind Flay. | `onDotTick` | nouvelle |
| Wetlands | Mind Spike | 1, Attack, Shadow | Deal 4 + the target's DoT. / It loses its DoT. / +1 Insanity. | Deal 7 + the target's DoT. / … | `spell_priest_mindspike` | Mind Sear et Devouring Plague empilent, Mind Spike encaisse tout de suite (Shadowform ajoute +3) : le DoT devient une réserve qu'on vide au moment choisi. | nouveau montant `dot`, effet `strip` | nouvelle |
| Stranglethorn | Power Infusion | 0, Skill, Holy | Draw 1. / Gain Instant 1 / Cooldown 2. | Draw 2. / Gain Instant 1 / Cooldown 2. | `spell_holy_powerinfusion` | Holy Fire, Halo, Empyreal Blaze et Greater Heal partent au jeu un tour sur deux, sans risque d'interruption ; avec Apotheosis, deux gros Cast par tour. | aucun (état `instant`) | modifiée (Westfall → STV ; Cooldown au lieu d'Exhaust, sans mana) |
| Swamp | Reflective Shield | 1, Power, Discipline | Power. / When hit: deal the damage absorbed to the attacker. | coût 0 | `ability_priest_reflectiveshield` | Inner Fire, PW: Shield, Luminous Barrier, Radiance et Rapture : la Discipline tue en se protégeant, chaque coup ennemi absorbé revient à son auteur. | `afterHit` | nouvelle |
| Steppes | Vampiric Embrace | 1, Skill, Shadow | Draw 1. / Until end of turn, Shadow damage heals half. / Cooldown 2. | coût 0 | `spell_shadow_unsummonbuilding` | Le tour de Void Eruption (6 + 5 par Insanity) ou de Mind Blast rend la moitié de ses dégâts : un Shadow qui se soigne sans Atonement. | nouveau `onDamageDealt` | nouvelle |
| Blackrock | Spirit Shell | 2, Power, Discipline | Power. / Overhealing: gain as much Absorb. / Keep up to 15 Absorb each turn. | coût 1 | `ability_shaman_astralshift` | Renew, Holy Nova, Atonement soignent à pleine vie et montent un rempart qui passe d'un tour à l'autre : Holy et Discipline jouent ensemble la défense. | nouveau `onHeal`, `blockKeep` | conservée (texte réécrit sans « your » ; icône changée, l'ancienne va à Reflective Shield) |

Précisions :
- **Prayer of Mending** : compte les PV réellement rendus (un soin à pleine vie ne fait rien), toutes sources
  (cartes, Regen, Atonement, potions, bibelots). Les dégâts ne viennent pas d'une carte : ni Atonement, ni
  Vampiric Embrace en retour, aucune boucle. Cible tirée par `c.rng.cards`.
- **Shadowy Apparitions** : une fois par ennemi et par tick (au début de son tour) ; l'Insanity arrive pendant
  le tour ennemi.
- **Mind Spike** : dégâts = 4 + DoT de la cible lu à la résolution (Shadowform et Sundered s'appliquent), puis
  le DoT de la cible tombe à 0.
- **Power Infusion** : l'Instant est l'état commun (decisions.md) : il se garde, la prochaine carte Cast le
  consomme. C'est la première source d'Instant hors Mage (question 3).
- **Reflective Shield** : à chaque coup ennemi qui entame l'Absorb, même en entier ; dégâts sans carte
  (comme Retaliation) égaux à l'Absorb perdue sur ce coup.
- **Vampiric Embrace** : dégâts des cartes `school = "shadow"` jusqu'à la fin du tour, arrondis à l'inférieur ;
  le DoT, qui se déclenche au tour ennemi, n'en profite pas.
- **Spirit Shell** : le surplus de soin devient Absorb ; au début du tour, 15 Absorb au plus restent
  (`blockKeep` : avec la Gnomish Harm Prevention Belt, on garde la plus grande des deux valeurs).

## Warrior

Sept directions :
1. **La Rage devient du contrôle de groupe** (Protection) — Shockwave.
2. **La Rage devient des PV** : la Fury sans Absorb tient (Fury) — Enraged Regeneration.
3. **Chaque gros coup touche deux ennemis** (Arms) — Sweeping Strikes.
4. **La Rage paie le mana** des cartes lourdes (Arms et Fury) — Anger Management.
5. **Bloquer paie aussi** : l'Absorb s'accumule et donne de la Rage (Protection) — Defensive Stance.
6. **Plus aucun bouclier**, tout dans l'attaque (Fury) — Death Wish.
7. **Garder sa Rage** jusqu'à 10 au lieu de la dépenser à 5 (Arms) — Avatar.

| Zone | Nom | Coût / type / voie | Texte de base | Amélioré | Icône | Le deck qu'elle fait naître | Moteur | Statut |
|---|---|---|---|---|---|---|---|---|
| Westfall | Shockwave | 1, Attack, Protection | Deal 7 to all. / Spend 3: apply Stunned 1 ⌛ to all / Cooldown 3. | Deal 10 to all. / … | `ability_warrior_shockwave` | Bloodrage, Berserker Rage, Demoralizing Shout gardent 3 Rage pour arrêter tout un groupe tous les trois tours : le Warrior contrôle au lieu d'encaisser. | aucun (`spend`, `apply … all`) | conservée (version de Westfall) |
| Duskwood | Enraged Regeneration | 1, Skill, Fury | Surge: heal 3 per Rage. / Cooldown 3. | Surge: heal 4 per Rage. / Cooldown 3. | `ability_warrior_endlessrage` | Rampage, Recklessness, Bloodrage (PV payés) et les coups pris montent la Rage, qui revient en PV : la Fury retire ses Defend. | aucun (`surge`, `heal per`) | modifiée (Swamp → Duskwood ; sans Afflictions, Cooldown au lieu d'Exhaust) |
| Wetlands | Sweeping Strikes | 1, Power, Arms | Power. / Targeted Attacks also hit another enemy for half. | coût 0 | `ability_warrior_weaponmastery` | Mortal Strike, Execute, Colossus Smash, Raging Blow frappent aussi un second ennemi : l'Arms devient un deck de groupe sans Cleave ni Whirlwind. | nouveau `onDamageDealt` | nouvelle |
| Stranglethorn | Anger Management | 0, Skill, Arms | Draw 1. / Spend 3: +2 mana. / Cooldown 2. | Draw 2. / Spend 3: +2 mana. / Cooldown 2. | `warrior_talent_icon_angermanagement` | Mortal Strike, Bladestorm, Shield Wall (2 mana) deux par tour : la Rage paie les cartes lourdes au lieu de leurs bonus Spend. | aucun (`mana`, `spent`) | nouvelle |
| Swamp | Defensive Stance | 1, Power, Protection | Power. / Keep half the Absorb each turn. / Fully absorbed hits: +1 Rage. | coût 0 | `ability_warrior_shieldguard` | Shield Block, Shield Wall, Ignore Pain remplissent une réserve qui dure ; Shield Slam (dégâts = Absorb) grandit d'un tour à l'autre. Bloquer ne prive plus de Rage. | `blockKeep`, `afterHit` | nouvelle |
| Steppes | Death Wish | 2, Power, Fury | Power. / Can't gain Absorb. / Attacks deal 50% more. | coût 1 | `spell_shadow_deathpact` | Le deck retire Defend et Shield Block, vit de Bloodthirst, Victory Rush et de la Rage gagnée en prenant les coups, et finit vite. | `block`, `damage` | conservée |
| Blackrock | Avatar | 2, Power, Arms | Power. / Rage can go up to 10. / Start of turn: +1 Rage. | coût 1 | `warrior_talent_icon_avatar` | Execute (5 + 4 par Rage), Ignore Pain, Enraged Regeneration lisent la Rage réelle : on la garde au lieu de la dépenser à 5, pour un coup de 45. | nouveau `resCap`, `onTurnStart` | conservée (texte sans « your ») |

Précisions :
- **Shockwave** : Spend au choix ; la Rage est payée au jeu, puis la carte Attack donne +1 Rage. Boss immunisé
  au Stunned, les dégâts s'appliquent.
- **Enraged Regeneration** : injouable à 0 Rage (seul effet : son Surge).
- **Sweeping Strikes** : à chaque coup d'une carte Attack qui a une cible, la moitié des dégâts infligés
  (arrondie à l'inférieur) frappe un autre ennemi vivant tiré au hasard (`c.rng.cards`) ; ce n'est pas un coup
  d'Attack (pas de Deep Wounds en plus). Seul en face : rien.
- **Anger Management** : Spend au choix ; Avatar ne le rend pas plus fort (Spend fixe).
- **Defensive Stance** : au début du tour, la moitié de l'Absorb (arrondie à l'inférieur) reste ; un coup
  ennemi entièrement absorbé donne +1 Rage, comme une perte de PV.
- **Death Wish** : +50 % après Strength, avant Sundered (crochet `damage`), arrondi à l'inférieur. Les cartes
  d'Absorb se jouent mais ne donnent rien.

## Mage

Sept directions :
1. **Chaque Cast frappe deux fois** (Fire) — Mirror Image.
2. **Se défendre par le Cast** : annuler le tour ennemi (Arcane) — Alter Time.
3. **Le gel vient tout seul**, les cartes Frozen toujours allumées (Frost) — Water Elemental.
4. **Rejouer ses cartes à recharge** (Frost) — Cold Snap.
5. **Brûler en se défendant** : l'Absorb du Mage devient de l'attaque (Fire) — Molten Armor.
6. **Concentrer le gros tour Arcane** sur une cible (Arcane) — Touch of the Magi.
7. **Le contrôle donne l'Instant** (Frost) — Fingers of Frost.

| Zone | Nom | Coût / type / voie | Texte de base | Amélioré | Icône | Le deck qu'elle fait naître | Moteur | Statut |
|---|---|---|---|---|---|---|---|---|
| Westfall | Mirror Image | 2, Power, Fire | Power. / Cast cards: deal their damage again to a random enemy. | coût 1 | `spell_magic_lesserinvisibilty` | Fireball, Pyroblast, Glacial Spike, Flamestrike : un deck tout en Cast qui protège ses incantations (Absorb, Counterspell) au lieu de chercher l'Instant. | `onCastResolved`, nouveau `onDamageDealt` | conservée (Steppes → Westfall) |
| Duskwood | Alter Time | 1, Skill (Cast), Arcane | Cast. / Heal the HP lost since this was played. / Cooldown 3. | coût 0 | `spell_mage_altertime` | Le Mage retire ses Mana Shield : un tour sur trois, le tour ennemi est effacé ; il garde un emplacement de Cast pour Pyroblast ou Blizzard. | nouvel effet `healLost` | modifiée (Swamp → Duskwood ; sans Afflictions, Cooldown au lieu d'Exhaust) |
| Wetlands | Water Elemental | 1, Power, Frost | Power. / Start of turn: deal 3 to the last target and apply Demoralized 1. | Start of turn: deal 5 … | `spell_frost_summonwaterelemental_2` | Ice Lance (+6), Shatter (+4 par coup), Deep Freeze toujours sous Frozen, même contre un boss : le Frost sans cartes de contrôle. | `onTurnStart`, `lastTarget` | nouvelle |
| Stranglethorn | Cold Snap | 0, Skill, Frost | Return Cooldown cards to hand. / Cooldown 4. | Cooldown 3. | `spell_frost_coldhearted` | Frost Nova, Presence of Mind, Fire Blast, Cone of Cold, Counterspell deux fois de suite : un deck de recharges. | effet `readiness` rendu commun | nouvelle |
| Swamp | Molten Armor | 1, Power, Fire | Power. / When hit: apply DoT 3 to the attacker. | When hit: apply DoT 4 … | `spell_fire_firearmor` | Les quatre Mana Shield de départ, Ice Barrier, Blazing Barrier : le Mage encaisse et brûle ; Phoenix Flames (DoT → Instant) et Ignite suivent. | `afterHit` | nouvelle |
| Steppes | Touch of the Magi | 1, Attack, Arcane | Deal 6. / +1 Charge. / Apply Touch of the Magi | Deal 9. / … | `spell_arcane_arcanetactics` | Evocation, Arcane Missiles, Arcane Barrage, Arcane Surge : tout le tour à 6 mana sur une cible, qui reprend la moitié en fin de tour. | nouvel état `touch`, `onDamageDealt` | nouvelle |
| Blackrock | Fingers of Frost | 1, Power, Frost | Power. / Applying Stunned or Demoralized: gain Instant 1, once per turn. | coût 0 | `ability_mage_wintersgrasp` | Frostbolt, Cone of Cold, Frost Nova donnent l'Instant à Pyroblast et Glacial Spike : un sort lourd par tour, jamais interrompu, même contre un boss (Demoralized). | `onStatusApplied` | modifiée (clause « change de phase » retirée : elle ne valait qu'à Blackrock) |

Précisions :
- **Mirror Image** : à la résolution d'une carte Cast (Instant compris : `onCardPlayed` avec `ctx.def.cast`),
  le montant de son **premier** coup est infligé une fois de plus à un ennemi vivant tiré au hasard (le même
  possible), recalculé sur la nouvelle cible. Une carte « to all » ne rejoue donc qu'un coup.
- **Alter Time** : les PV au moment du jeu sont gardés dans l'incantation (données simples) ; à la résolution,
  soigne la différence si elle est positive. Interrompue, rien. Sous Instant, elle se résout au jeu et ne
  soigne rien : à dire dans l'infobulle.
- **Water Elemental** : nom du familier, le sort réel s'appelle « Summon Water Elemental » (trop long pour le
  ruban). Frappe au début du tour du joueur, avant la pioche, sur `c.player.lastTarget` (premier ennemi vivant
  sinon) : le Demoralized 1 tient tout le tour du joueur et le tour ennemi.
- **Cold Snap** : toutes les cartes en recharge reviennent en main (main de 10 au plus), puis Cold Snap part en
  recharge à son tour.
- **Molten Armor** : à chaque coup ennemi, même entièrement absorbé ; le DoT passe par le crochet `apply`.
- **Touch of the Magi** : état à drapeau sur l'ennemi. Infobulle : `End of turn: takes half the damage dealt to
  it this turn.` À la fin du tour du joueur, la moitié (arrondie à l'inférieur) des dégâts subis depuis la pose
  est infligée, sans carte, puis l'état tombe.
- **Fingers of Frost** : sur un boss, Stunned ne prend pas mais Demoralized oui : la carte marche partout.

## Rogue

Sept directions :
1. **Le Parry devient l'attaque** (Combat) — Ghostly Strike.
2. **Le Stealth sert à neutraliser** (Subtlety) — Sap.
3. **Plusieurs ouvertures par tour** (Subtlety) — Subterfuge.
4. **Empiler le DoT puis le doubler** (Assassination) — Deathmark.
5. **Le Rogue qui se soigne en frappant** (Assassination) — Leeching Poison.
6. **Plusieurs coups de grâce par tour** (Combat ; Combo) — Relentless Strikes.
7. **Un coup de grâce plein à chaque tour** (Assassination ; Combo) — Cold Blood.

Deux cartes seulement touchent au Combo (6 et 7) ; les cinq autres ouvrent le Parry, le Stealth, le DoT et le
soin.

| Zone | Nom | Coût / type / voie | Texte de base | Amélioré | Icône | Le deck qu'elle fait naître | Moteur | Statut |
|---|---|---|---|---|---|---|---|---|
| Westfall | Ghostly Strike | 1, Attack, Combat | Deal 3 + 4 per Parry. / +1 Combo. | Deal 5 + 5 per Parry. / +1 Combo. | `spell_shadow_curse` | Les trois Feint de départ, Evasion, Riposte, Shadowstep, Blinding Powder gardent 3 Parry, qui frappent sans être dépensés : le Rogue qui pare attaque. | nouveau montant `parry` | modifiée (Duskwood → Westfall ; dégâts par Parry au lieu de Parry 2) |
| Duskwood | Sap | 1, Skill, Subtlety | Stealth: apply Stunned 2 ⌛ / Gain Stealth / Cooldown 3. | coût 0 | `ability_sap` | Vanish, Shadowstep, Smoke Bomb, Shadow Dance rendent le Stealth pour endormir un ennemi pendant qu'Ambush et Backstab tuent l'autre. | aucun (condition `stealth`) | nouvelle |
| Wetlands | Subterfuge | 1, Power, Subtlety | Power. / Stealth ends at end of turn, not on the first Attack. | coût 0 | `rogue_subterfuge` | Backstab, Ambush, Secret Technique (deux fois à tous), Premeditation dans le même tour : chaque Vanish ou Shadowstep vaut trois ouvertures. | nouveau crochet `stealthBreak` | nouvelle |
| Stranglethorn | Deathmark | 1, Attack, Assassination | Deal 4. / Double the target's DoT. / Cooldown 3. | Deal 7. / … / Cooldown 2. | `ability_rogue_deathmark` | Garrote, Rupture, Crippling Poison, Deadly Poison empilent sur une cible, Deathmark double, Envenom ou Exsanguinate encaissent. | nouvel effet `double` | nouvelle |
| Swamp | Leeching Poison | 1, Power, Assassination | Power. / Each Attack hit: heal 1. | coût 0 | `rogue_leeching_poison` | Mutilate, Fan of Knives, Killing Spree, Riposte : beaucoup de coups, chacun soigne ; le Rogue tient les longs combats sans Parry. | `onAttackHit` | nouvelle |
| Steppes | Relentless Strikes | 1, Power, Combat | Power. / Each Surge of 3+ Combo: +1 mana, draw 1. | coût 0 | `ability_rogue_ruthlessness` | Pistol Shot, Backstab, Sinister Strike à bas prix, puis deux ou trois Eviscerate, Between the Eyes ou Nightblade dans le même tour. | `onSurge` | conservée (icône changée : la sienne est celle de Slam) |
| Blackrock | Cold Blood | 2, Power, Assassination | Power. / First Surge each turn counts 2 more Combo. | coût 1 | `ability_rogue_deadliness` | Trois cartes d'ouverture suffisent pour un Eviscerate à 5 Combo ; à 5, il frappe comme à 7 : un coup de grâce plein chaque tour. | `surge` | conservée (texte sans « your » ; icône changée : la sienne est celle d'Ice Barrier) |

Précisions :
- **Ghostly Strike** : lit le Parry à la résolution, sans le consommer (3 au plus : 15 dégâts de base).
- **Sap** : une Skill lit le Stealth sans le consommer (règle du Rogue) ; le Stunned est lu avant le « Gain
  Stealth ». Sans Stealth, Sap ne fait que le rendre. Boss immunisés.
- **Subterfuge** : la première Attack applique sa ligne « Stealth: » sans retirer le Stealth ; il tombe à la
  fin du tour. Le Stealth du début de combat dure donc tout le premier tour.
- **Deathmark** : pose sur la cible autant de DoT qu'elle en a déjà, sans passer par le crochet `apply`
  (Crystal Vial ne s'y ajoute pas).
- **Leeching Poison** : un coup d'Attack sur un ennemi (Blade Flurry n'en est pas un).
- **Relentless Strikes** : après la résolution d'un Surge qui a dépensé 3 Combo ou plus (montant de `onSurge`).
- **Cold Blood** : la première carte Surge jouée dans le tour compte Combo + 2 (7 au plus) ; injouable à
  0 Combo comme avant.

## Hunter

Sept directions :
1. **Le familier frappe deux fois par tour** (Beast Mastery) — Call of the Wild.
2. **Les Traps deviennent des sorts visés** (Survival) — Trap Launcher.
3. **Le familier frappe toute la salle** (Beast Mastery) — Beast Cleave.
4. **Le DoT nourrit la pioche** (Survival) — Black Arrow.
5. **Le Frenzy devient des PV** (Beast Mastery) — Exhilaration.
6. **Achever en chaîne** : le Marksmanship tue aussi sous la moitié (Marksmanship) — Kill Shot.
7. **Sans familier** : toute la puissance dans les tirs (Marksmanship) — Lone Wolf.

| Zone | Nom | Coût / type / voie | Texte de base | Amélioré | Icône | Le deck qu'elle fait naître | Moteur | Statut |
|---|---|---|---|---|---|---|---|---|
| Westfall | Call of the Wild | 1, Power, Beast Mastery | Power. / Start of turn: pet attacks. | coût 0 | `ability_hunter_callofthewild` | Le Frenzy monte seul à 5 ; Kill Command, Dire Beast, Bestial Wrath et Spirit Bond profitent d'un familier qui frappe au début et à la fin du tour. | `onTurnStart`, `petAttack` | conservée |
| Duskwood | Trap Launcher | 1, Power, Survival | Power. / Traps trigger at once on a chosen enemy. | coût 0 | `ability_hunter_traplauncher` | Counterattack, Explosive Trap, Immolation Trap, Freezing Trap deviennent des sorts : le Survival attaque à son tour, même contre un ennemi qui n'attaque pas. | nouveau crochet `trapLaunch` | nouvelle |
| Wetlands | Beast Cleave | 1, Power, Beast Mastery | Power. / Pet attacks hit all enemies. | coût 0 | `ability_hunter_pet_ravager` | Kill Command, Dire Beast, Bestial Wrath frappent tous les ennemis : le Beast Mastery devient un deck de groupe sans Multi-Shot. | `petAttack` (option `all`) | nouvelle |
| Stranglethorn | Black Arrow | 1, Skill, Survival | Apply DoT 6 / Apply Black Arrow | Apply DoT 9 / Apply Black Arrow | `spell_shadow_painspike` | Serpent Sting, Immolation Trap, Wyvern Sting prolongent le DoT de la cible marquée ; chaque tick pioche : plus de Traps et de tirs par tour. | nouvel état `black_arrow`, `onDotTick` | nouvelle |
| Swamp | Exhilaration | 1, Skill, Beast Mastery | Pet attacks. / Heal 2 per Frenzy. / Cooldown 3. | Pet attacks. / Heal 3 per Frenzy. / Cooldown 3. | `ability_hunter_onewithnature` | Barbed Shot, Cobra Shot, Kibler's Bits tiennent le Frenzy haut : il soigne au lieu de passer par Bestial Wrath, et le Beast Mastery retire ses Disengage. | aucun (`per res`) | modifiée (sans Afflictions ; soin par Frenzy) |
| Steppes | Kill Shot | 1, Attack, Marksmanship | Deal 6. / Execute: deal 18. / Kill: return to hand. | Deal 8. / Execute: deal 24. / … | `ability_hunter_assassinate2` | Aimed Shot et Steady Shot (Careful Aim) entament, Kill Shot finit et revient : le Marksmanship tue plusieurs blessés dans le même tour. | nouvelle condition `kill` | nouvelle |
| Blackrock | Lone Wolf | 1, Power, Marksmanship | Power. / The pet leaves. / Attacks: +1 Frenzy. / Attack hits deal Frenzy more. | coût 0 | `spell_hunter_lonewolf` | Rapid Fire, Arcane Shot, Concussive Shot, Raptor Strike : beaucoup de petites Attacks montent le Frenzy et le portent ; le deck abandonne le Beast Mastery. | `damage`, nouveau drapeau `noPet` | conservée (version des Steppes, placée à Blackrock) |

Précisions :
- **Call of the Wild** : au début du tour du joueur à partir du tour suivant, après DoT, Regen, Cast et baisse
  du Frenzy ; +1 Frenzy comme toute attaque du familier. Deux exemplaires : deux attaques.
- **Trap Launcher** : une Trap jouée demande une cible ; elle se déclenche aussitôt sur elle, comme si cet
  ennemi attaquait (`Combat.triggerTrap`, `onTrapTriggered` : Entrapment, Lock and Load, Resourcefulness
  s'appliquent), et ne prend pas d'emplacement de Trap. Freezing Trap posé ainsi suit la règle habituelle du
  Stunned pendant le tour du joueur (l'ennemi perd son prochain tour). Question 2.
- **Beast Cleave** : chaque attaque du familier (automatique, commandée, de Surge, de Call of the Wild) frappe
  tous les ennemis vivants ; le Frenzy ne monte que de 1 par attaque.
- **Black Arrow** : état à drapeau sur l'ennemi, infobulle `Each DoT tick on it: draw 1.` La carte piochée
  arrive pendant le tour ennemi (comme Lock and Load) et reste en main au tour suivant.
- **Exhilaration** : le familier frappe d'abord (+1 Frenzy), puis le soin lit le Frenzy.
- **Kill Shot** : « Execute: deal 18. » = total (forme de Scorch). « Kill » : la cible est morte à la fin de la
  résolution ; la carte revient alors de la défausse en main (main pleine : elle reste).
- **Lone Wolf** : plus d'attaque automatique ; les lignes « Pet attacks » ne font rien ; Kill Command, Dire
  Beast, Bestial Wrath deviennent injouables (raison « No pet »). Chaque carte Attack donne +1 Frenzy après sa
  résolution ; chaque coup d'une carte Attack fait Frenzy de plus.
  La baisse de 1 par tour reste. La version de Blackrock (« +4 par coup, Careful Aim toujours vrai ») est
  écartée : elle rendait Careful Aim sans objet.

## Cartes proposées et écartées

| Nom | Fiche | Pourquoi |
|---|---|---|
| Mass Dispel (×3) | Duskwood, Wetlands, Swamp | Réponse aux buffs ennemis et aux cartes ennemies : sa valeur dépend de la zone, aucun deck ne naît d'elle. |
| Spell Reflection (×2) | Duskwood, STV | Réponse aux Cast ennemis. |
| Spellsteal (×3) | Westfall, Wetlands, STV | Interrupt ou vol de buff : réponse. |
| Marked for Death (×2) | Westfall, Wetlands | +5 Combo en Exhaust : un tour fort, pas un deck ; la version des Wetlands lit les primes de meute. |
| Remove Curse, Master's Call, Shiv | Duskwood, Swamp | Valeur liée aux Curses et aux Afflictions. |
| Hex of Weakness, Mind-numbing Poison, Snake Trap | STV | Répondent aux Cast et au Hex. |
| Aspect of the Pack | Wetlands | Morts en chaîne : faible contre un boss seul, et Beast Cleave couvre le groupe. |
| Lone Wolf (version de Blackrock) | Blackrock | Doublon ; la version des Steppes est gardée. |

## Points de moteur nouveaux

Rien n'est à faire pour Shockwave, Enraged Regeneration, Anger Management, Power Infusion, Sap, Exhilaration
(effets et conditions existants). Le reste, regroupé :

1. **Rareté `epic`** : valeur de `rarity`, cadre et couleur de carte, place dans le tirage des récompenses et du
   marchand (question 5), notes des bots (`bot.rating`). Champ `zone` déjà prévu (`docs/zones.md`).
2. **Notifications nouvelles** :
   - `onHeal(n, surplus)` : soin réellement rendu et surplus au-delà du maximum (Prayer of Mending,
     Spirit Shell) ;
   - `onDamageDealt(cible, n, carte)` : dégâts réellement infligés par un coup du joueur (Mirror Image,
     Vampiric Embrace, Sweeping Strikes, Touch of the Magi).
3. **Valeurs modifiées nouvelles** : `resCap` (plafond de la ressource, lu par `Combat.gainRes` : Avatar) ;
   `stealthBreak` (le Stealth tombe-t-il à la première Attack : Subterfuge, dans `Core/Classes/rogue.lua`) ;
   `trapLaunch` (une Trap se déclenche-t-elle au jeu, sur une cible choisie : Trap Launcher).
4. **Montants, conditions, effets** :
   - montants `dot` (DoT de la cible : Mind Spike) et `parry` (Parry du joueur : Ghostly Strike), dans
     `Combat.AMOUNTS` ;
   - condition `kill` (cible morte à la fin de la résolution) et effet « revenir en main » (Kill Shot), libellé
     « Kill » au registre ;
   - effets `strip` (retirer un état de la cible : Mind Spike), `double` (doubler un état de la cible :
     Deathmark), `healLost` avec les PV notés dans l'incantation (Alter Time) ;
   - effet `readiness` du Hunter rendu commun (`Core/Effects.lua`) pour Cold Snap.
5. **États nouveaux** : `touch` (drapeau ennemi, dégâts comptés pendant le tour, résolu par `onTurnEnd`) ;
   `black_arrow` (drapeau ennemi, lu par `onDotTick`) ; drapeau de tour de Vampiric Embrace (`c.turn`).
6. **Familier** : `Hunter.petAttack` avec option « tous les ennemis » (Beast Cleave) ; drapeau « familier
   absent » lu par l'attaque automatique, l'effet `pet` et `Combat.canPlay` (raison « No pet ») pour Lone Wolf.
7. **Instant pour le Priest** : aucun code (état commun), mais l'infobulle et l'affichage de l'état doivent
   exister dans la vue du Priest.
8. **Langage** (`L.trigger`) : « Each heal », « Overhealing », « Each enemy DoT tick », « Fully absorbed hits »,
   « Applying Stunned or Demoralized », « Each Surge of 3+ Combo » ; condition « Kill » ; infobulles des états
   Touch of the Magi et Black Arrow. Tous les textes sont à passer par le harnais U22 et U27.

## Risques d'équilibre

1. **Avatar avec les cartes « per Rage »** : à 10 Rage, Enraged Regeneration soigne 30 (40 amélioré), Ignore
   Pain donne 30 Absorb, Skullflame Shield 20 Absorb par tour, Execute 45. Deux épiques ensemble (Avatar et
   Enraged Regeneration) font un Warrior qui ne meurt plus.
2. **Deathmark, Rupture et Exsanguinate** : Rupture à 5 Combo (DoT 15), Deathmark (30), puis Exsanguinate à
   5 Combo : 30 + 29 + 28 + 27 + 26 = 140 en deux tours. Le Cooldown 3 ne suffit peut-être pas ; repli : « add
   half its DoT ».
3. **Trap Launcher, Resourcefulness, Freezing Trap** : la Trap déclenchée au jeu revient en main ; Freezing
   Trap étourdit un ennemi chaque tour pour 1 mana (hors boss), et Lock and Load pioche à chaque fois.
4. **Shadowy Apparitions et Devouring Plague** : le Surge pose DoT 2 par Insanity, chaque tick en rend 1 ; sur
   une élite à beaucoup de PV, l'Insanity revient presque entière tant que la cible vit.
5. **Water Elemental et Fingers of Frost** : le gel automatique du début de tour donne l'Instant chaque tour ;
   Pyroblast part tous les tours sans risque, et Shatter s'applique à tout.
6. **Cold Snap et Frost Nova, Presence of Mind** : Frost Nova deux fois de suite étourdit deux tours sur trois ;
   Presence of Mind deux fois donne deux Instant. Même famille : Sap avec Subterfuge et Shadow Dance (Stunned 2
   tous les trois tours sur la même cible).
7. **Defensive Stance et Shield Slam** : la moitié de l'Absorb restant chaque tour, Shield Wall (18) et Ignore
   Pain montent une réserve que Shield Slam convertit (40 et plus vers le 4e tour), tout en gagnant de la Rage.
8. **Beast Cleave et Bestial Wrath** : à Frenzy 5, cinq attaques de 6 sur chaque ennemi (30 à tous pour
   2 mana) ; avec Call of the Wild, le familier frappe la salle deux fois par tour.

## Questions au joueur

1. **Lone Wolf renvoie le familier.** Pris par un Hunter Beast Mastery, il rend injouables Kill Command, Dire
   Beast et Bestial Wrath déjà dans le deck, et Arcane Shot (carte de départ) ne fait plus que 3 + Frenzy. Un
   Hunter Marksmanship le prendra toujours, un Beast Mastery jamais. Le garder aussi tranché, ou laisser le
   familier frapper 3 une fois par tour, sans Frenzy ?
2. **Trap Launcher : toujours, ou au choix ?** Toujours : plus aucune Trap ne se pose pour le tour ennemi, et
   Freezing Trap ne peut plus arrêter une attaque dès son premier coup (elle étourdit pendant ton tour : l'ennemi
   perd son tour suivant, le résultat est le même, mais il faut savoir qui étourdir avant). Au choix (comme
   Spend : clic gauche lance, clic droit pose) : la carte n'a plus de défaut, elle n'est plus qu'un gain.
3. **Le Priest reçoit l'Instant (Power Infusion).** Ses Cast sacrés (Holy Fire 24, Empyreal Blaze 36, Halo 22 à
   tous) partiraient au jeu un tour sur deux, sans pouvoir être interrompus. Le Mage perd l'exclusivité « seule
   classe qui accélère le Cast ». Accepter, ou remplacer par « Cast cards cost 1 less this turn » ?
4. **Defensive Stance retourne la règle du Warrior.** Le GDD dit « bloquer prive de Rage » ; avec cette carte, un
   coup entièrement absorbé donne de la Rage, et Revenge (gratuite si l'on a perdu des PV) perd son intérêt dans
   ce deck. C'est voulu (une carte pivot), mais c'est la seule des 35 qui annule le défaut central de sa classe.
   Garder ?
5. **Fréquence des cartes épiques dans les récompenses.** Si elles suivent la fréquence des rares, un joueur
   qui vient de débloquer sa carte de Westfall peut ne pas la voir de toute l'expédition suivante. Si chaque
   classe a une chance garantie (par exemple une carte épique proposée par expédition, au boss d'élite ou au
   coffre), il la verra toujours, mais les sept zones gagnées rendent ce choix prévisible. Laquelle ?
