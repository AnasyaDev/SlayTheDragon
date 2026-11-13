# Cartes de zone : les 35 cartes épiques

Fiche de conception, version 2 (13/11/2026, après la relecture du joueur). Rien n'est codé. Elle remplace la
version 1 du même jour et les sections « Cartes de zone » des sept fiches `docs/zones/<id>.md`, qui ne
gardent qu'un renvoi.

## Ce qui change par rapport à la version 1

Le joueur a relevé la barre (`docs/zones/decisions.md`) : **une seule épique par expédition**, et chaque
épique **pilote le build**. Une épique change une règle de la classe pour toute l'expédition et fait naître
un deck qui n'existe pas sans elle. Deux tests, passés par chacune des 35 :

1. *Avec cette carte, est-ce que je choisis mes récompenses, mes améliorations et mes retraits
   différemment pendant toute l'expédition ?*
2. *Deux expéditions de la même classe avec deux épiques différentes se jouent-elles de façon nettement
   différente ?*

Tout ce qui n'est qu'une bonne carte (pioche, mana, soin, dégâts en plus, réduction de coût, un état de
plus) est refusé. Une épique n'a pas à se combiner avec les autres épiques : on n'en a jamais deux.

## Règles retenues

- **Arrivée en jeu : toutes les épiques sont des règles en jeu dès le début du combat** (règle complète en
  fin de fiche, « A »). Elles ne se piochent pas, ne se jouent pas, n'ont pas de coût. Les 35 sont donc des
  Powers à plaque « Epic » : `type = "power"`, `epic = true`, `rarity = "epic"`, `zone = "<id>"`,
  `path = <voie>`, sans `cost` ni `level`.
- **Déblocage** (inchangé) : la première victoire d'une classe dans une zone débloque sa carte de cette
  zone, introuvable autrement. Ensuite l'épique entre dans la réserve d'épiques de la classe (offre
  garantie, élites, marchand : fin de fiche, « B »).
- **Westfall d'abord simple** : la carte de Westfall de chaque classe est la première épique débloquée ;
  elle se comprend en une lecture. Celles des Steppes et de Blackrock demandent de construire autour.
- **Un nom = une carte** : sorts ou talents réels de la classe, absents de `Data/<Classe>.lua`, uniques
  dans les 35 et dans les variantes de Lone Wolf (vérifié dans `Data/`, `Core/`, `UI/` et `docs/`).
- **Texte** : langage exact des cartes, « Epic. » en tête (mot de plaque, retiré à l'affichage comme
  « Power. »), aucun « you / your ». Le corps tient en quatre lignes d'environ 22 caractères ; les « / »
  sont des retours à la ligne. Quand la règle ne tient pas, la carte dit l'essentiel et l'**infobulle**
  donne le détail.
- **Lien avec la zone** : un bonus, jamais une condition. Aucune épique ne perd sa valeur ailleurs.
- **Retraits** : le feu de camp ne retire rien (repos ou amélioration) ; « à retirer » vise le marchand et
  les rencontres, « feu de camp » vise l'amélioration à faire en priorité.
- **Statut** : *conservée* (règle de la version 1 gardée ; le coût disparaît d'office avec la règle
  d'arrivée, l'amélioration « coût 1 » est remplacée), *modifiée* (idée gardée, règle changée),
  *nouvelle*.

## Répartition par zone

| Zone | Priest | Warrior | Mage | Rogue | Hunter |
|---|---|---|---|---|---|
| 1 Westfall | Prayer of Mending | Death Wish | Mirror Image | Deflection | Call of the Wild |
| 2 Duskwood | Misery | Thunderous Roar | Molten Armor | Doomblade | Trap Launcher |
| 3 Wetlands | Echo of Light | Sweeping Strikes | Water Elemental | Atrophic Poison | Beast Cleave |
| 4 Stranglethorn Vale | Shadow Covenant | Titan's Grip | Fingers of Frost | Echoing Reprimand | Roar of Sacrifice |
| 5 Swamp of Sorrows | Reflective Shield | Shield Charge | Arcane Meditation | Subterfuge | Master Marksman |
| 6 Burning Steppes | Voidform | Anger Management | Conflagration | Kidney Shot | Black Arrow |
| 7 Blackrock Mountain | Inner Focus | Avatar | Rule of Threes | Danse Macabre | Lone Wolf |

Par voie : Priest 2 Holy, 3 Discipline, 2 Shadow ; Warrior 3 Arms, 2 Fury, 2 Protection ; Mage 3 Fire,
2 Frost, 2 Arcane ; Rogue 2 Assassination, 2 Combat, 3 Subtlety ; Hunter 3 Beast Mastery,
2 Marksmanship, 2 Survival.

---

## Priest

Sept builds :
1. **Le soin frappe** (Holy) — Prayer of Mending : Renew, Holy Nova, Flash Heal, Greater Heal, Atonement
   soignent pour tuer ; le Priest accepte les coups.
2. **Le DoT de tout le monde** (Shadow) — Misery : SW: Pain, Vampiric Touch, Devouring Plague posés sur une
   cible couvrent la salle ; Mind Flay toujours allumé.
3. **La Regen devient une nova** (Holy) — Echo of Light : Renew, Holy Nova, Halo, Vampiric Touch frappent
   tous les ennemis à chaque début de tour ; la survie passe par l'Absorb.
4. **Le Shadow payé en PV** (Discipline) — Shadow Covenant : Mind Blast, Mind Flay, SW: Death, Schism ne
   coûtent que des PV, le mana sert à l'Atonement (Solace, Radiance, Penance) qui les rend.
5. **L'Absorb renvoie les coups** (Discipline) — Reflective Shield : les quatre Inner Fire, PW: Shield,
   Luminous Barrier, Rapture tuent ce qui frappe.
6. **Le Shadow qui ne dépense jamais** (Shadow) — Voidform : plus aucun Surge, l'Insanity monte sans fin et
   chaque coup de Mind Blast, Mind Flay, SW: Death grandit avec elle.
7. **Un gros sort par tour** (Discipline, pilote le Cast) — Inner Focus : la première carte du tour devient
   un Cast plus fort ; Holy Fire, Empyreal Blaze, Halo, Penance, Luminous Barrier en tête de tour.

### Westfall — Prayer of Mending (Holy) · conservée

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Each heal: deal the HP` / `restored to a random` / `enemy.` | `Each heal: deal the HP` / `restored + 2 to a` / `random enemy.` |

- **Règle.** Chaque soin qui rend au moins 1 PV au Priest inflige autant (amélioré : autant + 2) à un
  ennemi vivant tiré par `c.rng.cards`. Toutes sources : cartes, chaque tic de Regen, Atonement, potions,
  bibelots, Last Breath. Seuls les PV réellement rendus comptent : un soin à pleine vie ne fait rien, même
  amélioré.
- **Cas limites.** Dégâts sans carte (comme Retaliation) : Sundered de la cible et Demoralized du Priest
  s'appliquent ; ni Atonement ni Shadowform, aucune boucle. Rendu pendant le tour ennemi (aucune source
  aujourd'hui) : même règle. Boss : normal. Dormeur (Swamp) : coup à une cible, donc bonus Rude Awakening
  et réveil. Cible tuée : le soin suivant tire une autre cible.
- **Deck piloté.** Centrales : Renew, Holy Nova, Halo, Flash Heal, Greater Heal, Vampiric Touch, Shadow
  Mend (soin 12), PW: Radiance et PW: Solace (Atonement), bibelot Benediction. Mauvaises : Inner Fire et
  PW: Shield (l'Absorb empêche la perte de PV, donc le soin). À retirer : Inner Fire. Feu de camp :
  Renew, puis Prayer of Mending.
- **Moteur.** Nouveau : notification `onHeal(n, surplus, source)` (soin réellement rendu).

### Duskwood — Misery (Shadow) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `DoT applied to an` / `enemy also goes to` / `every other enemy.` | `…` / `every other enemy, +1.` |

- **Règle.** Quand le Priest pose du DoT sur **un** ennemi (carte à une cible, Surge de Devouring Plague,
  ligne de DoT de Holy Fire), chaque autre ennemi vivant reçoit le même DoT (amélioré : +1 sur chaque
  copie). La valeur copiée est la valeur finale posée sur la cible (Shadowform compris) ; les copies ne
  repassent pas par le crochet `apply`.
- **Cas limites.** Une carte « to all » (Mind Sear) ne copie rien. Le DoT posé sur soi (Shadow Mend) ne
  compte pas. Les copies ne déclenchent pas Misery (pas de boucle). Un ennemi invoqué plus tard ne reçoit
  rien. Boss seul : un deck de DoT ordinaire. Lien Duskwood : un lanceur de Curse fragile tué par son DoT
  au début de son tour lève ses Curses avant d'agir.
- **Deck piloté.** Centrales : SW: Pain (carte de départ, devient une carte de zone), Vampiric Touch,
  Devouring Plague (DoT 2 par Insanity sur tous), Holy Fire, Mind Flay (sa ligne « DoT: » toujours vraie),
  Void Eruption, Shadowform, Silence. Mauvaises : Mind Sear (fait double emploi), Holy Nova. À retirer :
  Smite. Feu de camp : SW: Pain.
- **Moteur.** Crochet existant `onStatusApplied` (unité, état, n) sur l'épique, avec un drapeau
  anti-boucle et la source (carte du joueur, une cible).

### Wetlands — Echo of Light (Holy) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Regen no longer heals.` / `Each Regen tick: deal` / `that much to all.` | `…` / `that much + 2 to all.` |

- **Règle.** Au début du tour du Priest, le tic de Regen ne soigne plus : il inflige sa valeur (amélioré :
  + 2) à chaque ennemi vivant, puis la Regen baisse de 1 comme d'habitude.
- **Cas limites.** Toute Regen est concernée, Spirit of Redemption compris (sa Regen 6 frappe au lieu de
  soigner : à dire dans l'infobulle). Les autres soins (Flash Heal, Atonement, potions) soignent toujours.
  Dégâts sans carte, Sundered compris. Le tic a lieu au même moment qu'un Cast résolu en début de tour :
  à Blackrock, il franchit les seuils « pendant ton tour ». Lien Wetlands : un seul effet frappe toute la
  meute, les morts sont simultanées et ne donnent aucune prime. Swamp : réveille tous les dormeurs, sans
  bonus.
- **Deck piloté.** Centrales : Renew (Regen 3), Holy Nova (3 à tous, Regen 2), Halo (Cast, 22 à tous,
  Regen 3), Vampiric Touch, Benediction (+1 par gain de Regen), et pour survivre Inner Fire, PW: Shield,
  Luminous Barrier. Mauvaises : Smite, Mind Blast (une cible). À retirer : Smite. Feu de camp : Renew,
  Holy Nova. À l'inverse de Prayer of Mending, ce Priest garde ses Inner Fire.
- **Moteur.** Nouveau : valeur modifiée `regenHeal` (0 = le tic ne soigne pas) et notification
  `onRegenTick(n)`.

### Stranglethorn Vale — Shadow Covenant (Discipline) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Shadow cards: Pay 2 HP` / `per mana, not mana.` | `…` / `The first each turn` / `is free.` |

- **Règle.** Une carte Shadow dont le coût en mana (tous modificateurs compris) vaut N ≥ 1 coûte 0 mana et
  « Pay 2N HP. » à la place. Amélioré : la première carte Shadow jouée dans le tour ne coûte ni mana ni PV.
- **Cas limites.** Règle commune de « Pay N HP » : payé au jeu, compte comme une perte de PV, ignore
  l'Absorb, carte injouable si elle ferait tomber à 0. Les cartes Shadow à 0 (Devouring Plague, Silence)
  ne changent pas. Curse of Tongues (+1 à la première carte) ajoute 2 PV. Lien Stranglethorn : le Hex vise
  la carte la plus chère en mana ; les cartes Shadow coûtent 0, il frappe donc les cartes sacrées.
- **Deck piloté.** Centrales : Mind Blast, Mind Flay, SW: Death, Schism, Vampiric Touch, Mind Sear,
  Shadowform ; le mana va à PW: Solace, PW: Radiance, Penance, Evangelism (Atonement qui rend les PV) et à
  PW: Shield. Mauvaises : Smite et Holy Fire (mana pour des dégâts). À retirer : Smite. Feu de camp : Mind
  Blast, Solace.
- **Moteur.** Crochets existants `cost` (→ 0) et `payHp` (+ 2N), l'épique passant **après** les autres
  Powers et bibelots pour lire le coût final (ordre nouveau, voir « C »).

### Swamp of Sorrows — Reflective Shield (Discipline) · conservée

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `When hit: deal the` / `damage absorbed to` / `the attacker.` | `…` / `damage absorbed + 3` / `to the attacker.` |

- **Règle.** Chaque coup ennemi qui entame l'Absorb du Priest (même en entier) inflige à son auteur
  l'Absorb perdue sur ce coup (amélioré : + 3), sans carte, comme Retaliation.
- **Cas limites.** Une attaque à plusieurs coups renvoie coup par coup. Pain Suppression divise le coup
  avant l'Absorb : seul ce qui est réellement absorbé revient. Le DoT et les Curses ne sont pas des coups.
  Auteur mort en cours d'attaque : rien. Les ennemis qui n'attaquent pas (lanceurs, dormeurs) ne
  renvoient rien : le deck garde des dégâts. Lien Swamp : les ouvertures de 20 à 26 absorbées reviennent
  entières.
- **Deck piloté.** Centrales : les quatre Inner Fire de départ, PW: Shield, Luminous Barrier, PW: Radiance,
  Penance (Absorb sous Atonement), Rapture (+2 par gain d'Absorb), Angelic Feather, bibelots Robes of
  Prophecy et Truefaith Vestments. Mauvaises : Renew, Flash Heal, Greater Heal. À retirer : un ou deux
  Smite. Feu de camp : Inner Fire.
- **Moteur.** Crochet existant `afterHit` (ennemi, PV perdus, absorbés).

### Burning Steppes — Voidform (Shadow) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Surge cards can't be` / `played. Shadow hits:` / `+1 per 3 Insanity.` | `…` / `+1 per 2 Insanity.` |

- **Règle.** Les cartes qui ont une clause Surge sont injouables (raison « Voidform »). Chaque coup d'une
  carte Shadow inflige 1 de plus par tranche de 3 Insanity (amélioré : 2), lue au moment du coup.
- **Cas limites.** Le DoT n'en profite pas (ce n'est pas un coup de carte). L'Insanity n'a pas de plafond
  et vit le temps du combat : au 4e tour, 12 à 16 Insanity, soit +4 ou +5 par coup. Les cartes Holy n'ont
  rien. Lien Steppes : un Shadow qui finit vite, avant que le feu ne brûle longtemps.
- **Deck piloté.** Centrales : Mind Blast (+2 Insanity, Cooldown 1), Mind Flay, SW: Pain et Vampiric Touch
  (+1 et la ligne « DoT: » de Mind Flay), Shadowform (+2 Insanity, +3), Schism, SW: Death, Psychic Scream
  (+1), bibelot Mindtap Talisman. Mauvaises : Devouring Plague et Void Eruption (injouables), Anathema.
  À retirer : Smite, puis les cartes Surge si on les a prises avant. Feu de camp : Mind Blast.
- **Moteur.** Crochet existant `damage` (école shadow) ; nouveau : valeur modifiée `canPlay` (d, inst) qui
  rend une carte injouable avec une raison.

### Blackrock Mountain — Inner Focus (Discipline, pilote le Cast de Holy) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `First card each turn:` / `Cast, and its values` / `+50%.` | `First card each turn:` / `Cast, values doubled.` |

Infobulle : `The first Attack or Skill each turn is cast: damage, Absorb, heal, DoT and Regen +50%.`

- **Règle.** La première carte Attack ou Skill jouée dans le tour devient un Cast : elle prend
  l'emplacement d'incantation et se résout au début du tour suivant, avec ses valeurs de dégâts, d'Absorb,
  de soin, de DoT et de Regen multipliées par 1,5 (amélioré : 2), arrondies au supérieur. Une carte déjà
  Cast reste Cast et reçoit le bonus.
- **Cas limites.** Les Powers, Curses et cartes Hexed ne comptent pas (la suivante est « la première »).
  Pas de bonus sur les durées (Atonement, Sundered, Stunned ⌛), la pioche, le mana, l'Insanity. Le Priest
  n'a qu'un emplacement de Cast : une fois la première carte incantée, il ne peut plus jouer de carte Cast
  dans ce tour, d'où la décision de commencer par Holy Fire. Interruption ou perte de PV qui coupe
  l'incantation : la carte est perdue pour ce tour (règle commune). Absorb incantée : gagnée au début du
  tour suivant, après la remise à 0, donc elle protège tout ce tour-là et le tour ennemi. Lien Blackrock :
  un Cast résolu en début de tour franchit un seuil « pendant ton tour » et remplace l'intention ; on
  choisit le moment.
- **Deck piloté.** Centrales : Holy Fire (24 → 36), Empyreal Blaze (36 → 54), Halo (22 → 33 à tous),
  Penance (5 → 8 par coup), Luminous Barrier (14 → 21), Greater Heal, Mind Blast ; Apotheosis (+1 mana,
  Cast −1), bibelot Truefaith Vestments. Mauvaises : les cartes à 0 et les petites cartes jouées en
  premier. À retirer : Smite. Feu de camp : Holy Fire ou Empyreal Blaze.
- **Moteur.** Nouveau : valeur modifiée `castAs` (d, inst : la carte part en Cast) et facteur `ctx.scale`
  lu par les effets `damage`, `absorb`, `heal`, `apply` (pain, regen).

---

## Warrior

Sept builds :
1. **Plus aucun bouclier** (Fury) — Death Wish : Bloodthirst, Victory Rush, Rampage, Raging Blow,
   Whirlwind, Battle Shout ; on retire les quatre Defend.
2. **La Rage explose toute seule** (Protection) — Thunderous Roar : Bloodrage, Berserker Rage,
   Demoralizing Shout, Revenge, Overpower, Rampage montent la Rage, qui frappe la salle à 5.
3. **Chaque gros coup en touche deux** (Arms) — Sweeping Strikes : Mortal Strike, Execute, Raging Blow,
   Rampage deviennent des cartes de groupe.
4. **Deux attaques par tour, chacune deux fois** (Fury) — Titan's Grip : Mortal Strike, Rampage,
   Bladestorm, Execute, Bloodthirst ; les Strike partent.
5. **L'Absorb est l'attaque** (Protection) — Shield Charge : Defend, Shield Block, Shield Wall, Ignore
   Pain, Shield Slam ; les Strike partent.
6. **Dépenser recharge** (Arms) — Anger Management : Heroic Strike, Onslaught, Execute, Ignore Pain
   dépensent, Bloodthirst, Shield Wall, Berserker Rage reviennent vite.
7. **Garder sa Rage jusqu'à 10** (Arms) — Avatar : Execute à 45, Ignore Pain à 30.

### Westfall — Death Wish (Fury) · conservée (Steppes → Westfall)

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Can't gain Absorb.` / `Attacks deal 50% more.` | `…` / `Kills: heal 3.` |

- **Règle.** Tout gain d'Absorb du Warrior vaut 0 (cartes, bibelots, potions). Les coups des cartes Attack
  infligent 50 % de plus, après Strength, avant Sundered, arrondi à l'inférieur. Amélioré : chaque ennemi
  tué par le Warrior (toute source) le soigne de 3.
- **Cas limites.** Les cartes d'Absorb se jouent mais ne donnent rien (Shield Slam : 0 + 50 % = 0).
  Retaliation, Deep Wounds, dégâts sans carte : pas de bonus. La Rage monte plus (chaque coup reçu fait
  perdre des PV). Carte la plus simple de la classe : un seul renoncement, un seul gain.
- **Deck piloté.** Centrales : Bloodthirst, Victory Rush, Raging Blow, Whirlwind, Rampage, Battle Shout,
  Recklessness, Enrage, Mortal Strike, Execute. Mauvaises : Defend, Shield Block, Shield Wall, Ignore Pain,
  Shield Slam, Devastate, bibelot Skullflame Shield. À retirer : les quatre Defend. Feu de camp : Heroic
  Strike, Bloodthirst.
- **Moteur.** Crochets existants `block` (→ 0) et `damage` ; `onEnemyDeath` pour l'amélioration.

### Duskwood — Thunderous Roar (Protection) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `At 5 Rage: spend it,` / `deal 6 to all, apply` / `Demoralized 1 ⌛ to all` | `…` / `deal 9 to all, apply` / `…` |

- **Règle.** Dès que la Rage atteint 5, elle tombe à 0 et le Warrior inflige 6 (amélioré : 9) à chaque
  ennemi vivant, sans carte (Strength comprise), puis pose Demoralized 1 ⌛ à tous.
- **Cas limites.** Déclenché juste après le gain qui fait atteindre 5 (fin de la carte, coup reçu, perte de
  PV d'une Curse). Pendant le tour ennemi, Demoralized 1 ⌛ ne dure que jusqu'à la fin du round : il
  allège les coups restants de ce tour. Spend et Surge restent jouables avant 5 (Execute ne compte jamais
  plus de 4 Rage). Battle Standard (+1 au début du combat) amorce. Boss : Demoralized prend. Dormeurs :
  réveillés sans bonus (dégâts à tous). Lien Duskwood : Rabies, Fevered Plague et Web font perdre des PV,
  donc gagner de la Rage ; les ondes tuent les lanceurs fragiles.
- **Deck piloté.** Centrales : Bloodrage (+2), Berserker Rage (+2, pioche), Demoralizing Shout (+1),
  Revenge, Overpower, Victory Rush (Attacks à 0), Rampage (PV payés et Attack), Raging Blow, Thunder Clap,
  Battle Shout et Enrage (Strength dans l'onde). Mauvaises : Execute, Ignore Pain, Onslaught (Spend). À
  retirer : Heroic Strike, un ou deux Defend (l'Absorb prive de Rage). Feu de camp : Bloodrage.
- **Moteur.** Notification existante `onResource` (variation, raison) ; effet sans carte à tous.

### Wetlands — Sweeping Strikes (Arms) · conservée

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Targeted Attack hits` / `also hit another` / `enemy for half.` | `…` / `also hit 2 other` / `enemies for half.` |

- **Règle.** Chaque coup d'une carte Attack qui a une cible inflige aussi la moitié des dégâts réellement
  infligés (arrondie à l'inférieur) à un autre ennemi vivant tiré par `c.rng.cards` (amélioré : deux
  autres, tirés sans remise).
- **Cas limites.** Le coup de rebond n'est pas un coup d'Attack (pas de Deep Wounds, pas de Rage), ni un
  coup à une cible au sens du Swamp (réveille sans bonus). Seul en face : rien. Plusieurs coups (Raging
  Blow, Rampage) : un rebond par coup. Lien Wetlands : rebond et coup principal sont le même effet, deux
  ennemis tués ensemble ne se donnent aucune prime.
- **Deck piloté.** Centrales : Mortal Strike, Execute, Raging Blow, Rampage, Heroic Strike, Overpower,
  Colossus Smash, Slam, Bloodthirst. Mauvaises : Cleave, Whirlwind, Bladestorm, Thunder Clap (sans cible,
  sans rebond, font double emploi). À retirer : un ou deux Defend. Feu de camp : Heroic Strike.
- **Moteur.** Nouveau : notification `onDamageDealt(cible, n, def, ctx)` (dégâts réellement infligés).

### Stranglethorn Vale — Titan's Grip (Fury) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Attacks resolve twice.` / `At most 2 Attacks per` / `turn.` | `…` / `turn, not counting` / `0-cost ones.` |

- **Règle.** Chaque carte Attack se résout deux fois : la copie suit tout de suite, même cible (premier
  ennemi vivant si elle est morte), sans coût. Au plus deux cartes Attack par tour ; la troisième est
  injouable (raison « Titan's Grip »). Amélioré : les Attacks à 0 mana ne comptent pas dans la limite.
- **Cas limites.** La copie reprend la dépense de l'original (Spend payé : bonus aux deux ; Surge : même
  montant compté), sans rien payer. La Rage « +1 par Attack » ne vient qu'une fois par carte. Cast (Slam) :
  les deux à la résolution. Exhaust et Cooldown après la copie. Pummel compte dans la limite. Hand of
  Justice (3e Attack) ne se déclenche plus, sauf amélioré avec des Attacks à 0.
- **Deck piloté.** Centrales : Mortal Strike (2 × 22), Rampage (8 coups pour un seul « Pay 3 HP »),
  Bladestorm, Execute (deux fois le même Surge), Heroic Strike (Spend payé une fois), Onslaught (pioche 2
  deux fois), Bloodthirst (Strength +2), Battle Shout et Recklessness (Strength comptée deux fois). Mauvaises :
  Strike, Overpower, Revenge (une place d'Attack pour peu). À retirer : les quatre Strike. Feu de camp :
  Mortal Strike, Bloodthirst.
- **Moteur.** Crochet existant `replay` (Ironfoe) ; nouveau `canPlay` (limite par tour, comme Voidform).

### Swamp of Sorrows — Shield Charge (Protection) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `End of turn: deal half` / `the Absorb to the last` / `target.` | `End of turn: deal 4 +` / `half the Absorb to the` / `last target.` |

- **Règle.** À la fin du tour du Warrior (avant la défausse et le tour ennemi), il inflige la moitié de son
  Absorb (arrondie à l'inférieur ; amélioré : 4 + la moitié) à sa dernière cible, sans carte. L'Absorb
  reste entière pour le tour ennemi.
- **Cas limites.** Dernière cible morte : l'ennemi vivant le plus à gauche. Comme l'attaque automatique
  du familier, Shield Charge ne vise pas un dormeur tant qu'un ennemi est éveillé ; sinon le coup a le
  bonus Rude Awakening et réveille (ouverture dans ce round : à dire dans l'infobulle). Ce n'est pas une
  carte Attack : pas de Rage. Un tour sans Absorb ne fait rien. Lien Swamp : les ouvertures annoncées se
  bloquent avec l'Absorb qui vient de frapper.
- **Deck piloté.** Centrales : les quatre Defend, Shield Block (Cooldown 1), Shield Wall (18), Ignore Pain
  (3 par Rage), Devastate, Shield Slam (dégâts = Absorb), Last Stand, bibelots Skullflame Shield et Gnomish
  Harm Prevention Belt. Mauvaises : Rampage, Recklessness, Strike. À retirer : les Strike. Feu de camp :
  Defend, Shield Block.
- **Moteur.** Crochet existant `onTurnEnd` ; règle de cible du familier généralisée (Swamp).

### Burning Steppes — Anger Management (Arms) · nouvelle (le nom de la version 1 est gardé, la règle est neuve)

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Each 3 Rage spent:` / `Cooldown cards return` / `1 turn sooner.` | `Each 2 Rage spent:` / `…` |

- **Règle.** La Rage dépensée (Spend payé, montant d'un Surge) s'additionne dans un compteur du combat ;
  chaque fois qu'il passe un multiple de 3 (amélioré : 2), chaque carte en recharge revient un tour plus
  tôt. Une carte qui arrive à 0 revient en main aussitôt (main pleine : au début du tour suivant).
- **Cas limites.** Le reste du compteur se garde d'un tour à l'autre. Berserker Rage (+2 Rage, Cooldown 2)
  ne boucle pas : il faut 6 Rage dépensées pour la ramener aussitôt. Lien Steppes : la brûlure fait perdre
  des PV, donc gagner de la Rage à dépenser.
- **Deck piloté.** Centrales : Bloodthirst (Strength à chaque retour), Shield Wall, Shield Block, Berserker
  Rage, Demoralizing Shout, Pummel ; dépenses : Heroic Strike, Onslaught (Spend 2), Execute et Ignore Pain
  (Surge), Bloodrage pour remplir. Mauvaises : Battle Shout, Recklessness, Victory Rush (Exhaust, rien à
  recharger). À retirer : Strike, Defend. Feu de camp : Bloodthirst, Onslaught.
- **Moteur.** Notifications existantes `onSpend` et `onSurge` ; nouvel effet « recharges −1 »
  (`cooldownTick`, voisin de `readiness`).

### Blackrock Mountain — Avatar (Arms) · conservée

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Rage can go up to 10.` / `Start of turn: +1 Rage.` | `…` / `Start of turn: +2 Rage.` |

- **Règle.** Plafond de Rage à 10. Au début de chaque tour, +1 Rage (amélioré : +2).
- **Cas limites.** Les cartes « per Rage » lisent la Rage réelle (Execute 5 + 4 × 10 = 45, Ignore Pain 30
  Absorb, Skullflame Shield 20 Absorb par tour). Spend N reste N. Lien Blackrock : garder la Rage pour
  traverser un seuil d'un seul coup (« passer à travers » saute la phase).
- **Deck piloté.** Centrales : Execute, Ignore Pain, Bloodrage, Berserker Rage, Colossus Smash et Mortal
  Strike (Sundered pour l'Execute), bibelots Battle Standard et Skullflame Shield. Mauvaises : Heroic Strike
  et Onslaught (Spend qui entament la réserve). À retirer : Heroic Strike, Strike. Feu de camp : Execute.
- **Moteur.** Nouveau : valeur modifiée `resCap` (lue par `Combat.gainRes`) ; `onTurnStart`.

---

## Mage

Sept builds :
1. **Chaque Cast frappe deux fois** (Fire) — Mirror Image : Fireball, Pyroblast, Flamestrike, Glacial
   Spike, protégés par Mana Shield et Counterspell.
2. **Le Mage qui se laisse frapper** (Fire) — Molten Armor : Mana Shield, Ice Barrier, Blazing Barrier,
   Prismatic Barrier encaissent et brûlent ; Phoenix Flames et Ignite suivent.
3. **Le gel vient tout seul** (Frost) — Water Elemental : Ice Lance, Shatter, Deep Freeze, Flurry toujours
   sous Frozen, sans cartes de contrôle.
4. **Le contrôle lance les sorts** (Frost) — Fingers of Frost : Frostbolt, Cone of Cold, Frost Nova
   gèlent, puis Pyroblast et Glacial Spike partent aussitôt.
5. **Économiser son mana** (Arcane) — Arcane Meditation : tours d'attente à 0 mana (Ice Lance, Scorch,
   Counterspell), puis Pyroblast et Glacial Spike dans le même tour.
6. **Le feu passe d'un mort à l'autre** (Fire) — Conflagration : Fireball, Living Bomb, Flamestrike, Ignite
   posent le DoT, Scorch achève.
7. **La troisième carte compte double** (Arcane) — Rule of Threes : cartes à 0 pour arriver à la
   troisième, puis Polymorph, Arcane Barrage, Frost Nova deux fois.

### Westfall — Mirror Image (Fire) · conservée

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Cast cards: deal half their` / `damage again to a` / `random enemy.` | `Cast cards: deal their` / `damage again to a` / `random enemy.` |

- **Règle (réglée le 14/11/2026).** À la résolution d'une carte Cast (sous Instant comprise), son **premier**
  coup frappe une fois de plus un ennemi vivant tiré par `c.rng.cards` (le même possible), pour la moitié
  (arrondie bas ; amélioré : la totalité) des dégâts calculés sur la nouvelle cible, Charges comprises ; c'est
  un coup de la même carte (Shatter, Ignite s'appliquent). Avant : « damage − 6 » ; la totalité dépasse +18 à
  Duskwood.
- **Cas limites.** Une carte « to all » ne rejoue qu'un coup. Cast sans dégâts (Evocation) : rien. Cast
  interrompu : rien. Dormeur : coup à une cible, donc bonus et réveil.
- **Deck piloté.** Centrales : Fireball (deux de départ), Pyroblast, Flamestrike, Glacial Spike, Blizzard,
  et pour protéger l'incantation Mana Shield, Ice Barrier, Counterspell ; Fire Blast et Presence of Mind
  pour les Cast immédiats. Mauvaises : Arcane Blast, Arcane Missiles, Ice Lance. À retirer : Arcane Blast,
  un Frostbolt. Feu de camp : Fireball.
- **Moteur.** `onCastResolved` existant, et `onCardPlayed` avec `ctx.def.cast` pour l'Instant.

### Duskwood — Molten Armor (Fire) · conservée (Swamp → Duskwood)

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `When attacked: apply` / `DoT 2 to the attacker` | `When attacked: apply` / `DoT 4 to the attacker` |

- **Règle (réglée le 14/11/2026).** Chaque attaque ennemie sur le Mage, même entièrement absorbée, pose DoT 2
  (amélioré : 4) à son auteur, par le crochet `apply`. Avant : DoT 1 par coup (+5 points) ; DoT 2 par coup
  donnait +25 à Duskwood (les attaques à plusieurs coups).
- **Cas limites.** Attaque à plusieurs coups : un seul DoT (premier coup). Auteur mort : rien. Le DoT ne se pose pas
  sur un ennemi qui n'attaque pas. Un ennemi Stunned ne frappe pas : le contrôle va contre ce deck. Lien
  Duskwood : un Bite entièrement absorbé ne pose pas de Curse et brûle quand même.
- **Deck piloté.** Centrales : les quatre Mana Shield de départ, Blazing Barrier, Ice Barrier (Retain),
  Prismatic Barrier, Phoenix Flames (« DoT: gain Instant 1 »), Ignite, Living Bomb, bibelot Robe of the
  Archmage. Mauvaises : Frost Nova, Polymorph (un ennemi étourdi ne frappe pas). À retirer : Arcane Blast.
  Feu de camp : Mana Shield.
- **Moteur.** Crochet existant `afterHit`.

### Wetlands — Water Elemental (Frost) · conservée

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Start of turn: deal 2` / `to the last target and` / `apply Demoralized 1` / `for this turn.` | `Start of turn: deal 4` / `…` |

- **Règle (réglée le 14/11/2026).** Au début de chaque tour du Mage (après la pioche, dès le tour 1),
  l'élémentaire inflige 2 (amélioré : 4), sans carte, à la dernière cible du Mage, puis lui pose Demoralized 1
  pour le tour du Mage seulement (retiré à la fin du tour : la cible est Frozen pour ses cartes, pas pour le
  tour ennemi ; un Demoralized posé par une carte s'ajoute et reste). Avant : 5 / 8 un tour sur trois ; la
  règle de la fiche (Demoralized tenu aussi pendant le tour ennemi) donnait +25 points.
- **Cas limites.** Cible morte ou absente : l'ennemi vivant le plus à gauche. Swamp : même règle que le
  familier (pas de dormeur tant qu'un ennemi est éveillé). Boss : Demoralized prend, donc Frozen marche
  partout. Nom du familier ; le sort réel « Summon Water Elemental » est trop long pour le ruban. Lien
  Wetlands : Demoralized répond aux primes de Strength.
- **Deck piloté.** Centrales : Ice Lance (+6 sous Frozen, à 0), Shatter (+4 par coup), Deep Freeze (Frozen :
  Stunned), Flurry et Arcane Missiles (trois coups sous Shatter), Glacial Spike, Frostbolt. Mauvaises :
  Frost Nova, Cone of Cold, Polymorph (contrôle en double). À retirer : deux Mana Shield. Feu de camp :
  Ice Lance.
- **Moteur.** Crochet existant `onTurnStart`, `c.player.lastTarget`.

### Stranglethorn Vale — Fingers of Frost (Frost) · modifiée (Blackrock → Stranglethorn ; plus de gain d'Instant)

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Cast cards aimed at a` / `Frozen enemy resolve at` / `once and thaw it.` | `…` / `once, deal 4 more and` / `thaw it.` |

- **Règle (réglée le 14/11/2026).** Une carte Cast à cible jouée sur un ennemi Frozen (Stunned ou
  Demoralized), lu au moment où elle est jouée, se résout tout de suite : sans emplacement, sans interruption
  possible, sans consommer d'Instant ; elle emploie le gel : le Stunned et le Demoralized que la cible portait
  au jeu lui sont retirés après la résolution (ceux que la carte pose restent : Glacial Spike). Amélioré : ses
  coups infligent 4 de plus. Sans le dégel : +18 points ; « une fois par tour » : +17.
- **Cas limites.** Les Cast sans cible (Flamestrike, Blizzard, Evocation) restent des Cast. Boss :
  Demoralized suffit. La version 1 (« gain Instant 1, once per turn ») n'était qu'un état de plus ; ici le
  contrôle change la nature du Cast. Lien Stranglethorn : un Cast parti au jeu quitte la main et échappe
  au Hex.
- **Deck piloté.** Centrales : les trois Frostbolt de départ (Demoralized, puis Fireball tout de suite),
  Cone of Cold, Frost Nova, Flurry, Polymorph, Deep Freeze, puis Pyroblast, Glacial Spike, Fireball ;
  bibelot Glacial Cloak (Demoralized à tous au début du combat). Mauvaises : Hot Streak, Fire Blast,
  Combustion, Presence of Mind (l'Instant fait double emploi). À retirer : Arcane Blast, deux Mana Shield.
  Feu de camp : Frostbolt, Pyroblast.
- **Moteur.** Crochet existant `instantCast` (d, inst, commit), qui lit la cible posée juste avant par
  `Combat.play` (`c.player.lastTarget`).

### Swamp of Sorrows — Arcane Meditation (Arcane) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Up to 4 unspent mana` / `carries over to the` / `next turn, +1.` | `Up to 6 unspent mana` / `…` / `next turn, +2.` |

- **Règle (réglée le 14/11/2026).** À la fin du tour, le mana non dépensé (4 au plus ; amélioré : 6) est
  gardé, plus 1 (amélioré : 2) s'il en reste ; il s'ajoute au début du tour suivant, après la remise du mana à
  son maximum. Le report seul ne rapportait presque rien (+4) : la main de 5 cartes, pas le mana, borne le tour
  suivant ; le « +1 » paie le tour d'attente.
- **Cas limites.** Le total peut dépasser le maximum (8 mana au tour suivant, 11 amélioré). Rien gardé : pas
  de bonus. Evocation, Arcane
  Surge, Mind Quickening Gem s'ajoutent. Seul le tour suivant profite du report (pas de cumul sur deux
  tours au-delà du plafond). Lien Swamp : les tours où les dormeurs dorment servent à économiser.
- **Deck piloté.** Centrales : Pyroblast, Glacial Spike, Flamestrike, Blizzard, Polymorph, Evocation,
  Arcane Surge, Ice Barrier (Retain : se joue au bon tour), et les cartes à 0 qui laissent passer un tour
  sans rien dépenser : Ice Lance, Scorch, Counterspell, Presence of Mind. Mauvaises : Arcane Blast, Fire
  Blast (petits coups à 1 mana). À retirer : Arcane Blast, un Frostbolt. Feu de camp : Pyroblast.
- **Moteur.** Crochets existants `onTurnEnd` et `onTurnStart` ; valeur gardée dans l'état de l'épique
  (`c.player.flags`) ; l'interface doit afficher un mana au-dessus du maximum.

### Burning Steppes — Conflagration (Fire) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `An enemy dying with` / `DoT gives that DoT + 16` / `to each other enemy.` | `…` / `DoT + 20` / `…` |

- **Règle (réglée le 14/11/2026).** Quand un ennemi meurt en portant du DoT, chaque autre ennemi vivant reçoit
  ce DoT + 16 (amélioré : + 20), posé directement (sans le crochet `apply`). Fiche : + 0 / + 3 (−2 points) ;
  avant : + 8 / + 11.
- **Cas limites.** Valeur lue au moment de la mort ; mort par son propre tic : la valeur de ce tic. Les
  serviteurs comptent. Chaîne possible : un DoT transmis tue au tic suivant et se transmet encore. Seul en
  face : rien (la carte vit des groupes ; les boss de Westfall, Wetlands et Blackrock ont des sbires).
  Lien Steppes : chaque mort recule le feu d'un round, et une mort en appelle d'autres.
- **Deck piloté.** Centrales : Fireball (DoT 2), Living Bomb et Flamestrike (DoT à tous), Ignite (DoT 3 par
  coup Fire), Phoenix Flames, Scorch (achever le porteur), Cone of Cold et Arcane Explosion pour amener les
  petits au seuil. Mauvaises : Glacial Spike, Polymorph (une cible, aucun DoT). À retirer : Arcane Blast,
  un Mana Shield. Feu de camp : Fireball, Living Bomb.
- **Moteur.** Notification existante `onEnemyDeath`, à condition que le DoT de l'ennemi soit encore lisible
  à ce moment (avant le nettoyage de ses états).

### Blackrock Mountain — Rule of Threes (Arcane) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `The 3rd card played` / `each turn spends 1` / `Charge to resolve` / `twice.` | `Every 3rd card played` / `…` |

- **Règle (réglée le 14/11/2026).** La troisième carte jouée dans le tour (amélioré : la 3e, la 6e, la 9e…),
  de tout type, se résout deux fois si le Mage a 1 Charge à dépenser au moment où elle est jouée (dépensée
  avant sa résolution) : la copie suit tout de suite, même cible, sans coût en mana. Sans Charge : une fois.
  Sans le coût : 99 % de victoires dans les trois zones dures (+32) ; « Pay 2 HP » : +22 ; avant : une Attack,
  un tour sur trois.
- **Cas limites.** Compteur `c.turn.played` : les Curses et les cartes Hexed comptent. La copie reprend la
  dépense de l'original (Surge : même nombre de Charges compté, après la Charge de la règle). Une carte Cast en 3e position : les deux
  résolutions à son départ. Powers : la copie ne pose pas un second Power. Exhaust, Cooldown : après la
  copie. Lien Blackrock : la 3e carte du tour fait le gros coup qui traverse un seuil.
- **Deck piloté.** Centrales : cartes à 0 pour atteindre la 3e (Ice Lance, Scorch, Counterspell, Presence
  of Mind, Evocation), puis Polymorph (Stunned 4 ⌛), Arcane Barrage (Surge compté deux fois), Frost Nova,
  Pyroblast, Glacial Spike, Flurry ; pour la Charge de chaque tour : Counterspell, Presence of Mind, Arcane
  Blast, Arcane Missiles, Prismatic Barrier, Polymorph (+1 Charge, deux fois en 3e), bibelot Tome of Arcane
  Brilliance. Mauvaises : les Powers chers, les cartes à 2 mana jouées en premier. À retirer : Mana Shield, un
  Frostbolt. Feu de camp : Arcane Barrage.
- **Moteur.** Crochet existant `replay` (inst, ctx), qui lit `c.turn.played`.

---

## Rogue

Sept builds :
1. **La parade riposte** (Combat) — Deflection : les trois Feint, Riposte, Evasion, Shadowstep, Cloak of
   Shadows frappent à chaque Parry gagné ; les Sinister Strike partent.
2. **Les coups de grâce deviennent poison** (Assassination) — Doomblade : Eviscerate, Nightblade, Secret
   Technique posent du DoT, Envenom et Exsanguinate l'encaissent.
3. **Le poison protège** (Assassination) — Atrophic Poison : Fan of Knives, Garrote, Deadly Poison, Rupture
   gardent tous les ennemis sous DoT, donc Demoralized ; les Feint partent.
4. **Finir à 2 points** (Combat) — Echoing Reprimand : Ambush, Cheap Shot, Premeditation, puis deux coups de
   grâce par tour.
5. **Plusieurs ouvertures par tour** (Subtlety) — Subterfuge : Backstab, Ambush, Secret Technique sous
   Stealth tout le tour.
6. **Le coup de grâce étourdit** (Subtlety) — Kidney Shot : monter à 5 chaque tour, Eviscerate et Between
   the Eyes arrêtent leur cible.
7. **Que des cartes différentes** (Subtlety) — Danse Macabre : un deck sans doublons, Killing Spree et Ambush
   en fin de tour.

### Westfall — Deflection (Combat) · nouvelle (la carte du joueur)

Le nom « Riposte » est pris par une carte commune du Rogue (`riposte`, Combat : `Deal 4.` / `Gain Parry 1`) ;
l'épique prend celui d'un talent Combat de l'ère classique. Voir la question 1.

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Each Parry gained:` / `deal 3, +3 per earlier` / `one this turn, to the` / `last target.` | `…` / `deal 4, +4 per earlier` / `…` |

Infobulle : `Riposte: 3, then 6, 9, 12… each turn, even above Parry 3.`

- **Règle.** Chaque charge de Parry gagnée fait une riposte : la k-ième riposte du tour inflige 3 × k
  (amélioré : 4 × k), sans carte, à la dernière cible du Rogue. La charge est gagnée normalement : le Rogue
  garde sa défense.
- **Progression de X dans le tour.** Compteur remis à 0 au début de chaque tour du Rogue ; « Gain Parry 2 »
  (Evasion) fait deux ripostes de suite. Trois Feint : 3 + 6 + 9 = 18 ; Evasion puis deux Feint : 3 + 6 +
  9 + 12 = 30.
- **Cas limites.** Au-dessus du plafond de 3 Parry, la charge est perdue mais la riposte a lieu : le deck
  peut empiler sans gaspiller. Blinding Powder (Parry 1 au début du combat) riposte au tour 1 et compte.
  Ravenholdt Signet (Parry 1 après chaque Surge), Cheat Death (Parry 3) ripostent aussi. Dernière cible
  morte : l'ennemi vivant le plus à gauche. Sundered de la cible s'applique. Dormeur : coup à une cible
  (bonus, réveil). Wetlands : les ripostes font partie de l'effet de la carte qui donne le Parry.
- **Deck piloté.** Centrales : Feint (de départ, devient la carte phare), Riposte, Evasion, Shadowstep,
  Cloak of Shadows, Hemorrhage (Sundered), Pistol Shot et Sprint (trouver les Feint), bibelots Blinding
  Powder et Ravenholdt Signet. Mauvaises : Sinister Strike, Eviscerate (peu de Combo). À retirer : deux ou
  trois Sinister Strike. Feu de camp : Feint (« Draw 1. »), puis Deflection.
- **Moteur.** Notification existante `onStatusApplied` (unité, état, n), avec **n demandé avant le
  plafond** (nouveau) ; compteur du tour dans l'état de l'épique.

### Duskwood — Doomblade (Assassination) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Surge Attacks apply` / `half their damage as` / `DoT instead.` | `Surge Attacks apply` / `their damage as DoT` / `instead.` |

- **Règle.** Les cartes Attack qui ont une clause Surge (Eviscerate, Between the Eyes, Nightblade, Secret
  Technique) n'infligent plus leurs dégâts : chaque coup pose sur sa cible un DoT égal à la moitié de ce
  qu'il aurait infligé (arrondie au supérieur ; amélioré : la totalité), par le crochet `apply`.
- **Cas limites.** Montant calculé comme un coup (Combo, Stealth, Sundered), sans l'Absorb de l'ennemi : le
  DoT l'ignore. Secret Technique : un DoT par ennemi, deux sous Stealth. Les autres lignes restent
  (Stunned de Between the Eyes, Stealth de Nightblade). Envenom n'a pas de ligne de dégâts : inchangée. Pas
  de coup, donc pas de réveil au Swamp (réveil doux au tic). Lien Duskwood : un lanceur tué par son DoT au
  début de son tour lève ses Curses avant d'agir.
- **Deck piloté.** Centrales : Eviscerate (24 → DoT 12), Nightblade, Secret Technique, Between the Eyes,
  Envenom et Exsanguinate (encaisser), Garrote, Mutilate (« DoT: +1 Combo »), Venomous Wounds, Deadly
  Poison, bibelot Crystal Vial. Mauvaises : Ambush et Backstab moins utiles, Killing Spree. À retirer :
  deux Sinister Strike. Feu de camp : Eviscerate, Exsanguinate.
- **Moteur.** Nouveau : valeur modifiée `convertHit` (cible, dégâts, def, ctx) qui renvoie les dégâts
  infligés et peut poser un état à la place.

### Wetlands — Atrophic Poison (Assassination) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Enemies with DoT count` / `as Demoralized.` | `…` / `as Demoralized and` / `Sundered.` |

- **Règle.** Un ennemi qui porte du DoT inflige 25 % de dégâts en moins, comme sous Demoralized (amélioré :
  il subit aussi 25 % de plus, comme sous Sundered). Ce n'est pas un état posé : il ne se cumule pas avec
  un vrai Demoralized ou Sundered.
- **Cas limites.** Le DoT tique au début du tour de l'ennemi, **avant** qu'il agisse : un DoT 1 tombe à 0
  et l'ennemi frappe plein. Il faut finir son tour avec du DoT 2 ou plus sur chaque attaquant. Exsanguinate
  et Envenom font baisser le DoT : tension entre défense et dégâts. Boss : marche. Affichage : jeton
  Demoralized grisé avec l'icône du poison. Lien Wetlands : répond aux primes de Strength de la meute.
- **Deck piloté.** Centrales : Fan of Knives (DoT à tous, chaque tour), Garrote, Crippling Poison, Deadly
  Poison, Rupture, Mutilate, Venomous Wounds, bibelot Crystal Vial. Mauvaises : Feint, Evasion, Smoke Bomb
  (défense en double), Exsanguinate. À retirer : les trois Feint. Feu de camp : Fan of Knives.
- **Moteur.** Crochet existant `enemyDamage` (et `damage` pour l'amélioration) ; affichage du jeton.

### Stranglethorn Vale — Echoing Reprimand (Combat) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `A Surge of 2 or 3` / `Combo counts as 5.` | `…` / `Combo counts as 6.` |

- **Règle.** Un Surge qui dépense exactement 2 ou 3 Combo compte 5 (amélioré : 6) pour ses effets. 1, 4 et
  5 Combo comptent leur valeur.
- **Cas limites.** La dépense ne change pas (2 ou 3). Monter à 4 est une perte : il faut finir avant.
  Shadowfang (+2 Combo au début du combat) rend le premier coup de grâce prêt. Deux coups de grâce pleins
  par tour sont la norme. Lien Stranglethorn : des coups de grâce à 1 mana et des ouvertures à 0 laissent
  peu de carte chère en main pour le Hex.
- **Deck piloté.** Centrales : Ambush et Cheap Shot (+2 : un coup de grâce prêt), Premeditation, Mutilate,
  Kick (+1), puis Eviscerate, Rupture, Envenom, Between the Eyes, Nightblade, Secret Technique, Exsanguinate.
  Mauvaises : Sinister Strike en surnombre (on ne veut plus 5 ouvertures). À retirer : deux Sinister
  Strike. Feu de camp : Eviscerate.
- **Moteur.** Crochet existant `surge` (valeur, ctx), qui doit lire la dépense réelle dans `ctx`.

### Swamp of Sorrows — Subterfuge (Subtlety) · conservée (Wetlands → Swamp)

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Stealth ends at end of` / `turn, not on Attacks.` | `…` / `Gaining Stealth:` / `+1 Combo.` |

- **Règle.** Une carte Attack jouée sous Stealth applique sa ligne « Stealth: » sans retirer l'état ; le
  Stealth tombe à la fin du tour du Rogue. Amélioré : chaque Stealth gagné (passage d'absent à présent)
  donne +1 Combo.
- **Cas limites.** Le Stealth du début de combat tient tout le premier tour. Vanish, Shadowstep, Smoke
  Bomb, Nightblade (après son coup) le rendent pour le reste du tour ; Shadow Dance chaque tour. Flash
  Powder : un gain sous Stealth n'en est pas un. Lien Swamp : Ambush sur un dormeur fait 27, et toutes les
  ouvertures du tour ont le bonus.
- **Deck piloté.** Centrales : Backstab (à 0, +7), Ambush (+12), Secret Technique (deux fois à tous),
  Cheap Shot, Premeditation, Vanish, Shadowstep, Smoke Bomb, Shadow Dance, Nightblade, bibelot Flash
  Powder. Mauvaises : Sinister Strike, Feint. À retirer : deux Sinister Strike. Feu de camp : Backstab.
- **Moteur.** Nouveau : valeur modifiée `stealthBreak` (le Stealth tombe-t-il à la première Attack), dans
  `Core/Classes/rogue.lua`.

### Burning Steppes — Kidney Shot (Subtlety) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Surge of 5 Combo:` / `apply Stunned 1 ⌛ to` / `the target.` | `Surge of 4+ Combo:` / `…` |

Infobulle : `A boss gets Demoralized 2 ⌛ instead.`

- **Règle.** Une carte à cible dont le Surge dépense 5 Combo (amélioré : 4 ou plus) pose ensuite
  Stunned 1 ⌛ sur sa cible si elle vit ; un boss reçoit Demoralized 2 ⌛.
- **Cas limites.** Les Surge sans cible (Secret Technique) ne font rien de plus. Between the Eyes (déjà
  Stunned 1) : Stunned 2. Atteindre 5 chaque tour coûte trois ou quatre cartes : un étourdissement un tour
  sur deux en moyenne, borné par le mana (règle « aucun garde-fou » des décisions communes). Lien
  Steppes : un attiseur étourdi perd son Stoke.
- **Deck piloté.** Centrales : Ambush, Cheap Shot, Premeditation (+2), Backstab, Mutilate, Kick (+1),
  puis Eviscerate, Between the Eyes, Rupture, Envenom, Nightblade, bibelot Shadowfang. Mauvaises : Secret
  Technique, Fan of Knives, Feint. À retirer : les Feint. Feu de camp : Cheap Shot (coût 0).
- **Moteur.** Notification existante `onSurge` (montant, ctx), avec la cible dans `ctx`.

### Blackrock Mountain — Danse Macabre (Subtlety) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Attack hits: +2 per` / `other card name played` / `this turn.` | `Attack hits: +3 per` / `…` |

- **Règle.** Chaque coup d'une carte Attack inflige 2 de plus (amélioré : 3) par nom de carte différent
  déjà joué dans ce tour, son propre nom exclu, chaque nom compté une fois.
- **Cas limites.** Compté à la résolution, comme Strength, avant Sundered et Rude Awakening. Les Curses et
  les cartes Hexed comptent (un nom chacune). Les doublons ne comptent qu'une fois : le deck veut des
  cartes toutes différentes. Lien Blackrock : un tour à six ou sept cartes différentes traverse un seuil
  d'un coup.
- **Deck piloté.** Centrales : une seule copie de chaque carte ; Backstab, Pistol Shot, Kick, Sprint,
  Vanish, Premeditation (noms à 0 mana), puis Killing Spree (six coups), Ambush, Eviscerate, Hemorrhage ;
  Adrenaline Rush pour allonger le tour. Mauvaises : les doublons. À retirer : quatre Sinister Strike et
  deux Feint (ce Rogue retire plus que les autres : prévoir l'or). Feu de camp : Killing Spree.
- **Moteur.** Nouveau : liste des noms joués dans le tour (`c.turn.names`) ; crochet existant `damage`.

---

## Hunter

Sept builds :
1. **Le familier frappe deux fois par tour** (Beast Mastery) — Call of the Wild : Kill Command, Dire Beast,
   Bestial Wrath, Spirit Bond, The Beast Within.
2. **Les Traps sont des sorts et des ordres** (Survival) — Trap Launcher : toutes les Traps, Entrapment,
   Lock and Load, Resourcefulness.
3. **Le familier frappe toute la salle** (Beast Mastery) — Beast Cleave : Kill Command, Dire Beast, Bestial
   Wrath sans Multi-Shot.
4. **Le Frenzy protège** (Beast Mastery) — Roar of Sacrifice : Barbed Shot, Cobra Shot, Kill Command
   tiennent le Frenzy haut ; les Disengage partent.
5. **Tirer avant le premier coup, tout de suite** (Marksmanship) — Master Marksman : Aimed Shot, Steady
   Shot, Hunter's Mark, Trueshot Aura partent au jeu sur une cible intacte.
6. **Le DoT appelle le familier** (Survival) — Black Arrow : Serpent Sting, Barbed Shot, Immolation Trap,
   Explosive Trap, Wyvern Sting.
7. **Sans familier** (Marksmanship) — Lone Wolf : les cartes de familier deviennent des tirs, Rapid Fire et
   Chimaera Shot portent le Frenzy.

### Westfall — Call of the Wild (Beast Mastery) · conservée

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Start of turn: spend 1` / `Frenzy for a pet attack.` | `Start of turn: pet` / `attacks.` |

- **Règle.** Au début de chaque tour du Hunter, premier compris (après la pioche et la baisse du Frenzy),
  si le Frenzy vaut 1 ou plus, il baisse de 1 et le familier attaque (+1 Frenzy, comme toute attaque : la
  dépense est rendue, l'attaque frappe au Frenzy d'avant moins 1). Amélioré : sans dépense, premier tour
  compris.
- **Réglage (14/11/2026).** Version de la fiche (gratuite, amélioré +1 Frenzy avant) : +19 points en moyenne
  sur Duskwood, Stranglethorn et Steppes (+26 à Duskwood). Le coût de 1 Frenzy, qui fait partie du build
  (garder le Frenzy haut, ne pas le vider par Bestial Wrath ou Growl), la ramène dans la cible ; l'ancienne
  base devient l'amélioration.
- **Cas limites.** Sans Frenzy (premier tour sans Pet Whistle), rien. Avec Pet Whistle, deux attaques au
  premier tour (le sifflet donne le Frenzy que l'épique dépense). Swamp : la cible du familier saute les
  dormeurs tant qu'un ennemi est éveillé. Blackrock : une attaque de début de tour franchit un seuil
  « pendant ton tour ».
- **Deck piloté.** Centrales : Kill Command, Dire Beast, Bestial Wrath (Frenzy à 5), Spirit Bond (Absorb
  par attaque), The Beast Within, Barbed Shot, Intimidation, Arcane Shot, bibelots Kibler's Bits et
  Devilsaur Eye. Mauvaises : Aimed Shot, Steady Shot, Volley (Cast sans familier). À retirer : deux
  Disengage (Spirit Bond protège). Feu de camp : Kill Command.
- **Moteur.** `onTurnStart`, `ns.Hunter.petAttack`.

### Duskwood — Trap Launcher (Survival) · modifiée (toujours active ; ajoute une attaque du familier)

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Traps trigger at once` / `on a chosen enemy, and` / `the pet attacks it.` | `…` / `the pet attacks it` / `twice.` |

- **Règle.** Une carte Trap demande une cible. Jouée, elle se déclenche aussitôt sur cet ennemi comme s'il
  attaquait (`Combat.triggerTrap`, `onTrapTriggered` : Entrapment, Lock and Load s'appliquent), sans prendre
  d'emplacement ; puis le familier attaque cet ennemi (amélioré : deux fois), ce qui en fait sa cible.
- **Cas limites.** Plus aucune Trap n'attend le tour ennemi. Les Traps « to all » (Explosive Trap, Frost
  Trap) touchent tous les ennemis ; le familier frappe la cible choisie. Freezing Trap lancée pendant le
  tour du Hunter : l'ennemi perd son prochain tour (règle habituelle). **Resourcefulness** : la Trap lancée
  revient en main à la fin du tour, pas tout de suite (sinon Freezing Trap étourdit toute la salle à
  chaque tour pour 1 mana chacune). Net-o-Matic : la première coûte 0. Boss : Stunned ne prend pas. Lien
  Duskwood : le Hex n'est pas une attaque et ne déclenche jamais une Trap posée ; lancée, elle frappe le
  lanceur.
- **Deck piloté.** Centrales : Freezing Trap, Immolation Trap, Counterattack (13), Explosive Trap, Frost
  Trap, Entrapment, Lock and Load, Resourcefulness, Spirit Bond (Absorb à chaque attaque du familier),
  bibelot Net-o-Matic. Mauvaises : Disengage, Raptor Strike. À retirer : deux Disengage. Feu de camp :
  Counterattack, Freezing Trap.
- **Moteur.** Nouveau : valeur modifiée `trapLaunch` (la Trap se déclenche au jeu, sur une cible) et
  exception de moment pour Resourcefulness ; `petAttack` avec une cible imposée.

### Wetlands — Beast Cleave (Beast Mastery) · conservée

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Pet attacks hit all` / `enemies, the others` / `for 2 less.` | `…` / `for 2 less.` / `Pet attacks: +1 Frenzy.` |

- **Règle.** Chaque attaque du familier (automatique, commandée, de Surge, de Call of the Wild) frappe tous
  les ennemis vivants : sa cible en plein, les autres pour 2 de moins (jamais sous 0) ; le Frenzy monte de 1
  par attaque (amélioré : de 2).
- **Réglage (14/11/2026).** À tous en plein : +15,5 points en moyenne (+24 à Duskwood) ; « la moitié aux
  autres » : +7,5 ; « 1 de moins » : +13 (+19,5 à Duskwood) ; « 2 de moins » retenu.
- **Cas limites.** Le Surge de Bestial Wrath donne une attaque à tous par point de Frenzy. Swamp : réveille
  tous les dormeurs (sans bonus, dégâts à tous). Lien Wetlands : chaque attaque est un seul effet sur toute
  la meute, les morts sont simultanées.
- **Deck piloté.** Centrales : Kill Command, Dire Beast, Bestial Wrath, Barbed Shot, Cobra Shot, Arcane
  Shot, Intimidation, The Beast Within, Spirit Bond. Mauvaises : Multi-Shot, Volley, Explosive Trap (zone en
  double). À retirer : deux Disengage. Feu de camp : Dire Beast.
- **Moteur.** `Hunter.petAttack` avec l'option « tous les ennemis ».

### Stranglethorn Vale — Roar of Sacrifice (Beast Mastery) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `When hit: spend 1` / `Frenzy to stop up to 2` / `damage.` | `…` / `Frenzy to stop up to 4` / `damage.` |

- **Règle.** À chaque coup ennemi, avant l'Absorb, si le Frenzy vaut 1 ou plus, il baisse de 1 et le coup
  perd jusqu'à 2 dégâts (amélioré : 4 ; fiche : 5 et 8, réglés à Westfall et gardés dans les zones dures).
- **Cas limites.** Automatique, coup par coup ; un coup de 0 ne coûte rien. Pas contre le DoT, ni les
  Curses, ni la brûlure des Steppes. Le Frenzy perdu affaiblit le familier : chaque coup reçu est un choix
  déjà fait, d'où l'intérêt de le remonter vite. Lien Stranglethorn : les panthères ouvrent par leur plus
  gros coup.
- **Deck piloté.** Centrales : Barbed Shot (+2), Cobra Shot (+1), Kill Command et Dire Beast (+1 par
  attaque), The Beast Within (une attaque par Attack), Intimidation, Spirit Bond, bibelots Kibler's Bits et
  Devilsaur Eye. Mauvaises : Bestial Wrath et Growl (vident le Frenzy), Disengage. À retirer : les quatre
  Disengage. Feu de camp : Barbed Shot.
- **Moteur.** Crochet existant `beforeHit` (comme le Parry du Rogue).

### Swamp of Sorrows — Master Marksman (Marksmanship) · nouvelle

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Careful Aim: Cast` / `Attacks resolve at` / `once and deal 20 more.` | `…` / `once and deal 24 more.` |

- **Règle.** Une carte Attack Cast jouée sur une cible au-dessus de la moitié de ses PV (Careful Aim, lu au
  jeu) se résout tout de suite : sans emplacement, sans interruption possible, et ses coups infligent 20 de
  plus (amélioré : 24 ; fiche : 0 et 4 ; 12 et 16 après Westfall : +6 points en moyenne dans les zones dures,
  +1 aux Steppes ; 16 : +8 ; 20 retenu).
- **Cas limites.** Volley (sans cible) reste un Cast. Les lignes « Careful Aim: » se lisent au même moment,
  donc vraies. Une cible déjà entamée sous la moitié : Cast normal. Lien Swamp : un dormeur est intact,
  Aimed Shot part au jeu avec Rude Awakening ((24 + 10) × 1,5 = 51) et le tue avant son ouverture.
- **Deck piloté.** Centrales : Aimed Shot, Steady Shot (pioche sous Careful Aim), Hunter's Mark, Trueshot
  Aura (+5), Concussive Shot, Rapid Fire, bibelots Light Quiver et Rhok'delar. Mauvaises : Volley, Kill
  Command, Dire Beast. À retirer : deux Arcane Shot. Feu de camp : Aimed Shot.
- **Moteur.** Crochet existant `instantCast`, qui lit la cible (`c.player.lastTarget`).

### Burning Steppes — Black Arrow (Survival) · nouvelle (le nom de la version 1 est gardé, la règle est neuve)

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Each enemy DoT tick:` / `spend 1 Frenzy for a` / `pet attack on it.` | `Each enemy DoT tick:` / `pet attacks it.` |

- **Règle.** Après chaque tic de DoT sur un ennemi qui survit, si le Frenzy vaut 1 ou plus, il baisse de 1
  et le familier attaque cet ennemi (+1 Frenzy comme d'habitude : la dépense est rendue), sans changer la
  cible du familier. Amélioré : sans dépense.
- **Réglage (14/11/2026).** Version gratuite (amélioré +1 Frenzy) : +17 points en moyenne, +26 à Duskwood ;
  le coût de 1 Frenzy la ramène dans la cible et rend le Frenzy central dans le deck de DoT (Barbed Shot).
- **Cas limites.** Sans Frenzy au tic : pas d'attaque. Le tic a lieu au début du tour de l'ennemi : le familier peut le tuer **avant qu'il
  agisse**. Un DoT à tous (Explosive Trap) donne une attaque par ennemi. Swamp : le tic réveille, l'attaque
  touche un ennemi éveillé (pas de bonus). Lien Steppes : chaque mort recule le feu.
- **Deck piloté.** Centrales : Serpent Sting (de départ), Barbed Shot (DoT 3, +2 Frenzy), Immolation Trap
  (DoT 7), Explosive Trap (DoT à tous), Wyvern Sting, Spirit Bond, Kill Command, Bestial Wrath. Mauvaises :
  Aimed Shot, Steady Shot, Volley. À retirer : deux Disengage. Feu de camp : Serpent Sting.
- **Moteur.** Notification existante `onDotTick` (unité, n) ; `petAttack` avec une cible imposée (comme
  Trap Launcher).

### Blackrock Mountain — Lone Wolf (Marksmanship) · modifiée (cartes de familier transformées)

| Coût / type | Texte de base | Amélioré |
|---|---|---|
| —, Epic | `Epic.` / `Pet cards become shots.` / `Attack hits: +2 per` / `Frenzy.` | `…` / `Attack hits: +3 per` / `Frenzy.` |

Infobulle : `Kill Command becomes Kill Shot, Arcane Shot Chimaera Shot… (see the deck).`

- **Règle.** Le familier n'existe pas : plus d'attaque automatique. Les cartes qui le nomment sont, tant que
  Lone Wolf est dans le deck, jouées et montrées sous leur variante (table). Chaque coup d'une carte Attack
  inflige 2 de plus par point de Frenzy (amélioré : 3 ; fiche : 1, amélioré « +1 Frenzy au début du tour »,
  trop long pour la carte). Le Frenzy baisse de 1 par tour comme d'habitude.
- **Réglage (14/11/2026).** +2 par Frenzy avec Chimaera Shot 4 / 4 : +7,8 points en moyenne dans les zones
  dures ; +3 par Frenzy : +21 (le bonus se multiplie par les quatre coups de Rapid Fire) ; retenu : +2 et
  Chimaera Shot 5 / 4 (amélioré 8), le tir de départ de la variante porte le deck sans familier (6 / 4 : +16,6).
- **Cas limites.** Le Frenzy vient des variantes (+1), de Barbed Shot (+2), de Cobra Shot, de Kibler's Bits,
  de Devilsaur Eye. Cast (Aimed Shot) : Frenzy lu à la résolution. Les Skills qui infligent des dégâts
  (Scatter Shot, Explosive Shot) n'ont pas le bonus. Growl ne nomme pas le familier : inchangée. Lien
  Blackrock : toute la puissance tombe pendant le tour du Hunter, il choisit quand franchir un seuil.
- **Cartes transformées** (coût, type, rareté, voie et amélioration gardés ; les instances ne changent
  pas) :

| Carte d'origine | Variante | Texte de base | Amélioré |
|---|---|---|---|
| Arcane Shot (1, Attack, départ) | Chimaera Shot | `Deal 5.` / `Deal 4 to another` / `enemy.` / `+1 Frenzy.` | `Deal 8.` / `…` |
| Kill Command (1, Attack, Cooldown 3) | Kill Shot | `Deal 8.` / `Execute: deal 16.` / `+1 Frenzy.` / `Cooldown 3.` | `… Cooldown 2.` |
| Dire Beast (0, Skill, Exhaust) | Double Tap | `Draw 1.` / `+2 Frenzy.` / `Exhaust.` | `Draw 1.` / `+3 Frenzy.` / `Exhaust.` |
| Intimidation (1, Skill, Cooldown 4) | Scatter Shot | `Deal 3.` / `+1 Frenzy.` / `Apply Stunned 1 ⌛` / `Cooldown 4.` | `… Cooldown 3.` |
| Multi-Shot (1, Attack) | Salvo | `Deal 5 to all.` / `+1 Frenzy.` | `Deal 7 to all.` / `+1 Frenzy.` |
| Counter Shot (0, Skill, Cooldown 3) | Silencing Shot | `Interrupt the target's cast.` / `+1 Frenzy.` / `Cooldown 3.` | `… Cooldown 2.` |
| Bestial Wrath (2, Skill, Surge) | Explosive Shot | `Surge: deal 6 per Frenzy.` | coût 1 |
| The Beast Within (1, Power) | Trick Shots | `Power.` / `Attacks: +1 Frenzy.` | coût 0 |
| Spirit Bond (2, Power) | Aspect of the Turtle | `Power.` / `Each Attack hit: gain` / `1 Absorb.` | coût 1 |
| Pet Whistle (bibelot de départ) | Pet Whistle | `At the start of each combat, +1 Frenzy.` | — |

- **Deck piloté.** Centrales : Rapid Fire (quatre coups, Frenzy à chacun), Chimaera Shot (les quatre de
  départ), Trick Shots, Kill Shot, Salvo, Cobra Shot, Barbed Shot, Concussive Shot, Raptor Strike, Double
  Tap. Mauvaises : Aimed Shot et Steady Shot (un seul coup pour 2 ou 1 mana), Volley. À retirer : les
  Disengage. Feu de camp : Rapid Fire, Chimaera Shot.
- **Moteur.** Drapeau « sans familier » (attaque automatique, effet `pet`) ; nouveau : **variantes de
  cartes par épique** (`Card.def` consulte la table de l'épique du deck), lues partout : combat, deck,
  récompenses, marchand.

---

## Cartes de la version 1 écartées

| Carte (classe) | Pourquoi |
|---|---|
| Power Infusion (Priest), Defensive Stance (Warrior) | Refusées par le joueur : une bonne carte, pas un deck. |
| Shadowy Apparitions, Mind Spike, Vampiric Embrace, Spirit Shell (Priest) | De l'Insanity, des dégâts plus tôt, du soin, de l'Absorb : des renforts du deck existant. Remplacées par Misery, Echo of Light, Shadow Covenant, Voidform, Inner Focus. |
| Shockwave, Enraged Regeneration (Warrior) | Une carte de contrôle et une carte de soin ; aucune règle changée. |
| Alter Time, Cold Snap, Touch of the Magi (Mage) | Soin, recharges, dégâts en plus. |
| Ghostly Strike, Sap, Deathmark, Leeching Poison, Relentless Strikes, Cold Blood (Rogue) | Une bonne carte chacune (dégâts, contrôle, soin, mana et pioche, Combo en plus). L'idée de Ghostly Strike (le Parry attaque) revit dans Deflection. |
| Exhilaration, Kill Shot (Hunter) | Soin ; une bonne carte d'achèvement. Kill Shot devient une variante de Lone Wolf. |

---

## A. Comment l'épique arrive en jeu (règle commune aux 35)

**Une épique est une règle en jeu dès le début de chaque combat.**

1. Au début de chaque combat, après `init` de la classe et avant `onCombatStart`, l'épique du deck est
   posée en jeu comme un Power : son icône est sous le héros dès la première main, ses crochets sont
   actifs pour tout le combat.
2. Elle n'est jamais dans la pioche, la main, la défausse ni les recharges : ni piochée, ni jouée, ni
   défaussée, ni épuisée, ni copiée. Elle n'a pas de coût.
3. Aucun effet de combat ne la touche : Hex, Curses, « Remove negative effects. », retraits de Power.
4. Elle compte dans le deck de l'expédition (en tête de la liste du deck, plaque « Epic »). Elle peut être
   améliorée au feu de camp (choix volontaire ; les améliorations au hasard, `upgradeRandom`, l'évitent) et
   retirée chez le marchand ou dans une rencontre (le deck n'a alors plus d'épique).
5. Plaque « Epic » (mot de tête, comme « Power. ») : `Epic. — in play from the start of each combat.`

Pourquoi cette règle plutôt qu'Innate ou « tant qu'elle est dans le deck » :
- **Elle pilote dès le premier tour, à chaque combat.** Une carte en un exemplaire dans 15 à 25 cartes
  n'arrive en main qu'un combat sur trois au premier tour ; Innate la met en main mais lui prend une
  place et du mana au premier tour, la pire entrée possible pour un deck qui en dépend.
- **Elle est à l'abri des mécaniques de zone** (Hex de Stranglethorn, Curses de Duskwood) : une épique
  frappée par un Hex couperait le build pour un combat.
- **Le moteur n'apprend presque rien** : c'est un Power posé d'office, dont les crochets (`def.hooks`)
  existent déjà ; pas de logique de pioche ni de main.
- **Le joueur l'a demandé pour Trap Launcher** (« toujours actif ») ; une seule règle pour les 35 évite
  d'apprendre au joueur une exception par carte.

## B. Une épique par expédition, et l'offre garantie

### Règle de jeu

1. **Le deck contient zéro ou une épique.** Les épiques ne sont jamais tirées dans les récompenses de
   cartes ordinaires ni dans les emplacements de cartes du marchand.
2. **Prendre une épique quand on en a une** ouvre une confirmation qui montre les deux cartes :
   `Replace <old> with <new>?`. Oui : l'ancienne quitte le deck (elle reste débloquée pour les expéditions
   suivantes), la nouvelle entre **non améliorée** (l'amélioration ne se transfère pas). Non : rien ne
   change et l'offre reste ouverte tant que l'écran de récompense l'est.
3. **Jamais en combat** : une épique ne change qu'entre deux combats (récompense, marchand, rencontre).
4. **Marchand** : un emplacement « Epic » quand la classe a débloqué au moins une épique qui n'est pas celle
   du deck : une épique tirée au hasard parmi elles, **150 po** (au-dessus des rares). L'acheter suit la
   règle 2. Le marchand retire aussi l'épique du deck au prix habituel d'un retrait.
5. **Rencontres** : une réponse qui donne « une carte de la classe » ne donne jamais une épique ; « dupe »
   (copier une carte) ne peut pas viser l'épique ; « remove » le peut. Aucune rencontre ne donne d'épique
   aujourd'hui ; une rencontre future qui en donnerait suivrait la règle 2.
6. **Cartes transformées** (Lone Wolf) et règles des cartes (Trap Launcher, Voidform…) : la transformation
   n'est pas écrite sur les cartes, c'est la règle de l'épique. Tant que l'épique est dans le deck, les
   cartes concernées s'affichent et se jouent sous leur variante **partout** : deck, combat, récompenses
   (un Kill Command proposé s'affiche « Kill Shot » avec un ruban « Lone Wolf »), marchand. Si l'épique est
   remplacée ou retirée, les cartes redeviennent celles d'origine aussitôt, avec leur amélioration.

### Offre garantie : à l'étape 1, pas au premier élite

**Proposition : la récompense du premier combat (étape 1) commence par un choix d'épique, une parmi trois
tirées dans celles que la classe a débloquées (toutes si elle en a trois ou moins), avec « Skip ». Le choix
de cartes ordinaire vient ensuite, sur le même écran.** En plus, chaque récompense d'élite ajoute une épique
au hasard (débloquée, autre que celle du deck), à prendre en remplacement ou à laisser.

Pourquoi l'étape 1 plutôt que le premier élite (proposition du joueur) :
- **La carte de l'expédition** (`docs/expedition.md`) : 8 étapes, l'étape 1 est toujours un combat, aucun
  élite avant l'étape 3, 1 ou 2 élites par chemin (1,26 visite en moyenne), et le premier élite peut être
  à l'étape 6. Une expédition donne 4 à 5 choix de cartes. Au premier élite, 1 à 4 de ces choix sont déjà
  faits sans savoir quel deck on construit : le premier test (« je choisis mes récompenses différemment
  pendant toute l'expédition ») échoue pour la moitié de l'expédition, et l'épique ne voit parfois que
  deux combats.
- **Le choix se fait après un vrai combat** : le joueur a vu la zone et sa main de départ, il ne choisit
  pas à froid. Le départ porte déjà le bibelot au choix parmi 3 (zone 3) ; deux choix avant le premier
  combat chargeraient l'écran de départ.
- **L'épique avant les cartes, sur le même écran** : le premier choix de cartes se fait déjà avec la règle
  en tête.
- **Trois au hasard** répond à la question 5 de la version 1 : avec sept épiques débloquées, on ne
  reprend pas toujours la même, et le build de l'expédition change d'une fois à l'autre.
- **Les élites gardent un moment fort** : « en trouver une autre remplace la précédente » existe toujours,
  au moment où le deck a pris forme (changer de build est alors un vrai pari).

Cas : aucune épique débloquée (compte neuf, classe neuve) : pas d'écran. Une seule : elle est proposée
seule, avec « Skip ». Défaite avant la fin de l'étape 1 : rien.

## C. Points de moteur nouveaux, regroupés

Rien n'est codé. Crochets déjà présents et réutilisés tels quels : `afterHit` (Reflective Shield, Molten
Armor), `onTurnStart` / `onTurnEnd` (Water Elemental, Call of the Wild, Shield Charge, Arcane Meditation,
Avatar), `onResource` (Thunderous Roar), `onSpend` / `onSurge` (Anger Management, Kidney Shot), `surge`
(Echoing Reprimand), `replay` (Titan's Grip, Rule of Threes), `instantCast` (Fingers of Frost, Master
Marksman), `enemyDamage` (Atrophic Poison), `beforeHit` (Roar of Sacrifice), `block` / `damage` (Death
Wish, Voidform, Danse Macabre), `cost` / `payHp` (Shadow Covenant), `onStatusApplied` (Misery,
Deflection), `onEnemyDeath` (Conflagration, Death Wish amélioré), `onDotTick` (Black Arrow).

1. **Épiques** : rareté `epic`, champ `epic = true` ; plaque « Epic » au registre (`L.plate`, en tête, à la
   place de « Power ») ; `Combat.new` pose l'épique du deck dans `c.player.powers` avant `onCombatStart`
   et l'exclut de la pioche ; **ordre des crochets** : l'épique passe après les autres Powers et bibelots
   (Shadow Covenant lit le coût final).
2. **Expédition** : `exp.epic` (uid de l'instance), offre de l'étape 1 (trois parmi les débloquées),
   emplacement d'épique des récompenses d'élite et du marchand (150 po), confirmation de remplacement,
   exclusion de `cardPool`, de `upgradeRandom` et de « dupe » ; sauvegarde : un champ de plus, valeur par
   défaut nil, rien à migrer.
3. **Notifications nouvelles** : `onHeal(n, surplus, source)` (Prayer of Mending), `onDamageDealt(cible,
   n, def, ctx)` (Sweeping Strikes), `onRegenTick(n)` (Echo of Light).
4. **Valeurs modifiées nouvelles** : `canPlay(d, inst)` avec raison (Voidform, Titan's Grip) ; `resCap`
   (Avatar) ; `stealthBreak` (Subterfuge) ; `trapLaunch` (Trap Launcher) ; `castAs` et facteur `ctx.scale`
   des effets (Inner Focus) ; `regenHeal` (Echo of Light) ; `convertHit` (Doomblade).
5. **Effets et compteurs** : effet `cooldownTick` (Anger Management, voisin de `readiness`) ; mana reporté
   au-delà du maximum (Arcane Meditation, affichage compris) ; compteur de ripostes du tour et `n` demandé
   avant plafond dans `onStatusApplied` (Deflection) ; `c.turn.names` (Danse Macabre) ; DoT encore lisible
   dans `onEnemyDeath` (Conflagration) ; dépense réelle dans le `ctx` du crochet `surge` (Echoing
   Reprimand) et cible dans celui d'`onSurge` (Kidney Shot) ; « compte comme Demoralized / Sundered » sans
   état posé (Atrophic Poison).
6. **Familier** : `petAttack(c, why, frenzy, cible)` avec cible imposée (Trap Launcher, Black Arrow) ;
   option « tous les ennemis » (Beast Cleave) ; drapeau « sans familier » (Lone Wolf) ; règle « pas de
   dormeur tant qu'un ennemi est éveillé » (Swamp) étendue aux frappes automatiques (Water Elemental,
   Shield Charge).
7. **Variantes de cartes par épique** (Lone Wolf) : définitions des variantes (hors réserve), table
   d'origine → variante portée par l'épique, `Card.def` qui la consulte quand l'épique est dans le deck ;
   affichage dans le deck, les récompenses, le marchand (ruban du nom de l'épique) ; Pet Whistle a la même
   bascule.
8. **Langage et harnais** : plaque Epic ; déclencheurs « Each heal », « Each Regen tick », « Each Parry
   gained », « At 5 Rage », « Surge of 5 Combo », « Surge of 4+ Combo », « Each 3 Rage spent », « Each 2 Rage
   spent », « Targeted Attack hits », « Attack hits », « Shadow hits », « Cast cards aimed at a Frozen
   enemy » (forme à revoir avec U27) ; infobulles d'Inner Focus, Deflection, Kidney Shot, Lone Wolf ;
   tous les textes passent U22 (panneau) et U27 (forme). Trois lignes dépassent 22 caractères d'un à trois
   (`Start of turn: +1 Rage.`, `Start of turn: +2 Rage.`, `Start of turn: +1 Frenzy.`) : à vérifier au
   harnais, la coupure se faisant au mot.
9. **Bots** : note de chaque épique (`bot.rating`), choix à l'étape 1 et décision de remplacement (valeur
   du deck actuel sous l'ancienne et la nouvelle règle), poids des cartes selon l'épique (une table de
   cartes « centrales » par épique, tirée de cette fiche, suffit au début).

## D. Risques d'équilibre

1. **Danse Macabre et Killing Spree** : six coups de 4, chacun + 2 par nom ; après cinq noms différents,
   6 × 14 = 84 pour 2 mana. Repli : bonus plafonné à + 10 par coup.
2. **Trap Launcher et Freezing Trap** : un ennemi étourdi par carte et par tour (hors boss), plus une
   attaque du familier ; avec Lock and Load, chaque Trap repioche. Resourcefulness est déjà retardée à la
   fin du tour ; si ça ne suffit pas, la Trap lancée devient Exhaust pour le combat.
3. **Misery et Devouring Plague** : à 10 Insanity, DoT 20 sur chaque ennemi (210 dégâts sur un groupe de
   trois en dix tours). Repli : les copies valent la moitié.
4. **Titan's Grip et la Strength** : Bloodthirst deux fois (+2 Strength par carte), Battle Shout puis
   Rampage (8 coups) ; un tour à 100 dégâts dès le 3e tour. Repli : la copie n'applique pas les états sur
   soi.
5. **Rule of Threes et le contrôle** : Polymorph en 3e carte (Stunned 4 ⌛), Frost Nova deux fois, Arcane
   Barrage à deux fois 24 à tous. Repli : la copie n'est faite que pour les cartes Attack.
6. **Inner Focus amélioré** : Empyreal Blaze à 72, Halo à 44 à tous, Luminous Barrier à 28 chaque tour où
   elle revient. À mesurer contre le risque d'interruption, qui est le vrai prix.
7. **Les épiques de groupe contre un boss seul** : Conflagration, Sweeping Strikes, Beast Cleave, Misery
   et Echo of Light ne font presque rien contre Grark Lorkrub ou Somnus sans sbires. Ce n'est pas un
   défaut de zone (elles valent ailleurs), mais le taux de victoire au boss doit être mesuré par épique.
8. **Deflection à Westfall** : la première épique du Rogue rend ses trois Feint de départ offensives (18
   dégâts pour 3 mana, et 3 Parry gardés) ; sur un deck de départ, c'est peut-être la plus forte des cinq
   cartes de Westfall. Repli : 2 + 2 par riposte.

## E. Questions pour le joueur

1. **Le nom « Riposte ».** Il est déjà pris par une carte commune du Rogue (`Deal 4.` / `Gain Parry 1`).
   Soit l'épique s'appelle **Deflection** (talent de l'ère classique) et rien d'autre ne change ; soit la
   commune est renommée (par exemple **Ghostly Strike**, libre maintenant) et l'épique prend « Riposte ».
   Dans le second cas, les joueurs qui connaissent déjà la carte commune la verront changer de nom.
2. **Deflection garde-t-elle la défense ?** Telle qu'écrite, chaque Feint pare un coup **et** frappe (3, 6,
   9…). Si « chaque Parry devient une riposte » veut dire que la charge est **consommée** par la riposte,
   le Rogue n'a plus de Parry : il frappe 18 avec trois Feint mais prend les coups en plein, et devra
   retirer moins de Sinister Strike pour tuer avant d'être tué. Laquelle ?
3. **Première épique du Warrior : Death Wish.** C'est la plus simple à lire, mais le premier Warrior qui la
   prend doit retirer ses quatre Defend et jouer sans aucun Absorb dès sa deuxième expédition. Trop dur
   pour une première épique, ou c'est justement la leçon (« le Warrior encaisse et frappe ») ?
4. **Offre à l'étape 1 plutôt qu'au premier élite.** À l'étape 1, tu choisis ton build avant ta première
   carte et toute l'expédition se construit autour ; au premier élite, tu as déjà pris deux à quatre cartes
   au hasard du deck de départ, et l'épique ne sert parfois que pour deux combats et le boss. D'accord pour
   l'étape 1, avec une épique de remplacement à chaque élite et une au marchand à 150 po ?
5. **Améliorer l'épique au feu de camp.** Permis dans cette fiche : un feu de camp sur deux ira sans doute
   à l'épique (Thunderous Roar 6 → 9, Arcane Meditation 3 → 5), au détriment des cartes de départ. Et si on
   remplace une épique améliorée, l'amélioration est perdue. Garder ces deux règles, ou interdire
   l'amélioration des épiques (elles restent telles qu'on les trouve) ?
