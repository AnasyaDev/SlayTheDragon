# Shaman — fiche de conception

Développe la section « Shaman » du GDD des classes (Claude Docs) sans la contredire. Prête à implémenter :
règles au cas limite près, 34 cartes, bibelots, progression, besoins moteur et interface. Les chiffres sont
des points de départ calés sur le Priest (`Data/Priest.lua`) ; la simulation les réglera.

| | |
|---|---|
| Fantasme | Le Shaman pose des totems qui travaillent pour lui quelques tours puis s'éteignent ; il gère quatre emplacements et leurs durées (l'équivalent des orbes du Defect). |
| Ce qu'il est seul à faire | Des Powers à durée, un par élément (Fire, Earth, Water, Air), qui reviennent dans le deck en s'éteignant. |
| Ressource | Maelstrom (0 à 5), dans la pastille violette. À 5, la prochaine carte Cast se résout tout de suite. |
| Style de survie | Soin et Absorb : totems de Water et d'Earth, Earth Shield, soins en Cast. |
| Difficulté | Difficile. |
| PV proposés | 60 (soin récurrent par les totems ; à mesurer). |
| Deck de départ | 4 Flame Shock, 4 Lightning Shield, 1 Lightning Bolt, 1 Searing Totem. |
| Interrupt | Wind Shear (0 mana). |
| Last Breath | Reincarnation. |
| Bibelot de départ | Totemic Relic. |

## 1. Règles propres

### Maelstrom

1. **Gain** : +1 pour chaque carte Attack jouée, **une fois la carte jouée** : après sa résolution pour une
   carte normale ou instantanée, au moment où elle part en incantation pour une carte Cast. Une carte
   « jouée deux fois » (Windfury Totem, Doom Winds, Flurry Axe) donne +2. Quelques cartes en donnent
   directement (« +1 Maelstrom. »). Les cartes Skill et Power n'en donnent pas d'elles-mêmes.
2. **Plafond** : 5. Le surplus est perdu.
3. **À 5 (seuil)** : la **prochaine carte Cast jouée** (Attack ou Skill) se résout **tout de suite**, comme
   une carte normale, puis le Maelstrom tombe à **0** ; si c'est une Attack, son +1 vient ensuite (le
   Maelstrom finit à 1). C'est automatique : le joueur ne choisit pas de garder l'instantané. Le seuil
   vaut 3 avec Elemental Mastery.
4. **Instantané et règles du Cast** : la carte ne passe pas par l'emplacement d'incantation. Elle ne peut
   donc pas être interrompue, et elle se joue **même si une autre incantation est en cours** (l'incantation
   en cours n'est pas touchée). Une seconde incantation *non instantanée* reste interdite, comme pour tous.
   Ce n'est pas tenir deux Cast à la fois (propre au Mage) : l'instantané n'occupe rien.
5. **À 5 sans carte Cast en main** : le Maelstrom reste à 5, d'un tour à l'autre, jusqu'à la prochaine
   carte Cast ; les gains sont perdus en attendant. Earth Shock (Surge) peut le dépenser à la place.
6. **Une incantation commencée avant d'atteindre 5** se résout normalement au début du tour suivant et
   ne consomme pas le Maelstrom.
7. **Surge** (Earth Shock) : compte le Maelstrom, le met à 0, inflige l'effet ; la carte étant une Attack,
   le Maelstrom finit à 1. Injouable à 0.
8. Le Maelstrom dure le combat (il se garde d'un tour à l'autre, sans baisse) et repart de 0 au suivant.

### Totems

1. **Carte totem** : une carte de type Power dont la plaque porte **« <Element> Totem N ⌛ »** (Fire,
   Earth, Water, Air). Jouée, elle **pose un totem** dans l'emplacement de son élément au lieu de rester
   en Power pour tout le combat.
2. **Quatre emplacements**, un par élément ; quatre totems au plus.
3. **Remplacement** : poser un totem dans un emplacement occupé retire l'ancien tout de suite (sa durée
   restante est perdue) ; le nouveau prend sa durée entière. Reposer le même totem le renouvelle.
4. **Durée** : exactement la règle des bienfaits à durée de `Core/Statuses.lua` (comme Atonement). Posé
   pendant le tour du joueur, il saute la baisse du round en cours ; il baisse ensuite de 1 à chaque fin
   de round (après le tour ennemi) et s'éteint en passant sous 1. « Totem N ⌛ » = **le reste du tour en
   cours + N tours suivants du joueur** (et les tours ennemis entre eux). Exemple, Totem 2 ⌛ posé au tour 1 :
   actif aux tours 1, 2 et 3 ; un effet « End of turn: » joue 3 fois, un effet « Start of turn: » 2 fois
   (tours 2 et 3). Les chiffres des cartes tiennent compte de ce décompte.
5. **Effets** : une ligne « Start of turn: » joue au début du tour du joueur, après la pioche et le mana
   (comme les crochets `onTurnStart`) ; une ligne « End of turn: » joue à la fin du tour du joueur, avant la
   défausse ; une ligne sans moment est **continue** tant que le totem est posé. **Aucun totem n'agit à la
   pose** : les effets immédiats appartiennent aux Skills. Ordre entre totems : Earth, Fire, Water, Air.
6. **Extinction** (durée finie ou remplacement) : la carte va dans la **défausse** (elle reviendra). Les
   bibelots qui réagissent (« When one of your totems fades ») jouent dans les deux cas.
7. **Fin de combat** : les totems disparaissent sans effet ; le deck est reconstitué comme toujours.
8. **Bonus de durée** (Totemic Mastery, Totemic Relic, Windfury Totem amélioré) : s'ajoutent à la pose.
9. **Cible au hasard** (Searing Totem) : un ennemi vivant tiré par `ns.Rng` (flux nommé, jamais
   `math.random`) ; rien s'il n'y a plus d'ennemi.
10. **Condition d'élément** : « Fire Totem: effet » = l'effet s'ajoute si un totem de Fire est posé
    (même forme que les conditions d'état). « per totem » compte les totems posés, de 0 à 4.

### Earth Shield

État du joueur, à charges (intensité, sans sablier) : **à chaque coup ennemi qui le touche, il soigne 3
puis perd une charge**. Chaque coup d'une attaque à plusieurs coups compte ; un coup entièrement absorbé
par l'Absorb compte aussi (le soin peut être perdu si les PV sont pleins). Le DoT n'est pas un coup. Les
charges restent d'un tour à l'autre. Ré-empilement : les charges s'additionnent.

### « Played twice »

Windfury Totem, Doom Winds et Flurry Axe font **jouer deux fois** une carte Attack : ses effets se
résolvent deux fois de suite sur la même cible (si elle meurt au premier passage, le second va sur
l'ennemi vivant le plus à gauche), mana payé une fois, recharge ou épuisement une fois, +2 Maelstrom. Une
carte Cast jouée deux fois se résout deux fois à sa résolution. Ces effets **ne se cumulent pas** : une
carte n'est jamais jouée plus de deux fois.

### Interactions avec les règles communes

| Règle | Comportement Shaman |
|---|---|
| Absorb | Stoneskin Totem donne son Absorb au début du tour, **après** la disparition de l'Absorb restant : il couvre le tour et le tour ennemi. Windwall Totem réduit chaque coup **avant** l'Absorb. |
| Cast | Lightning Bolt, Lava Burst, Chain Lightning, Healing Wave, Healing Surge, Chain Heal. Instantané à 5 Maelstrom (voir plus haut). Les conditions se vérifient à la résolution : Lava Burst en Cast regarde le DoT au début du tour suivant (un DoT 1 a pu s'éteindre entre-temps) ; Chain Heal compte les totems après la baisse de fin de round. |
| Cooldown | Stormstrike, Wind Shear, Purge, Shamanistic Rage. Jouée deux fois : une seule recharge. |
| Stunned | Le Shaman n'en pose pas : l'immunité des boss ne le gêne pas. Son contrôle : Demoralized (Frost Shock), Windwall Totem, Wind Shear, Purge. |
| Interrupt | Wind Shear, pendant le tour du joueur, sur une intention Cast. |
| Attaques multiples | Windwall Totem et Earth Shield agissent coup par coup : forts contre les attaques à plusieurs coups. Strength of Earth Totem et Totem of Wrath ajoutent par coup (Stormstrike : deux fois). |
| DoT | Flame Shock le pose ; Lava Burst, Frost Shock, Totem of Wrath le lisent ; Lava Surge réagit à chaque tick. |
| Last Breath | Reincarnation (Power) : une fois par combat. |

### Mots-clés propres (deux) et infobulles

| Mot-clé | Règle | Infobulle (≤ 60 caractères) |
|---|---|---|
| **Totem** (« Fire Totem 3 ⌛ », et la condition « Fire Totem: ») | Power à durée dans l'emplacement de son élément. | `Stays N more turns in its element slot. New one replaces it.` |
| **Earth Shield** | État à charges, défini plus haut. | `When hit: heal 3, then lose 1 charge.` |

Infobulles complémentaires (ressource et condition d'élément) :

| Terme | Infobulle (≤ 60 caractères) |
|---|---|
| Maelstrom | `+1 per Attack. At 5, your next Cast resolves at once.` |
| Fire Totem: (et Earth, Water, Air) | `Bonus if a Fire totem is up.` |

## 2. Les 34 cartes

Texte dans le langage des cartes : une clause par ligne, séparées ici par « / » ; états posés en dernière
ligne, sans point ; les mots de plaque sont dans la colonne « Plaque » (pour un totem, « <Element> Totem
N ⌛ » remplace le mot « Power »). Coût et plaque améliorés : entre parenthèses quand ils changent. Icônes
vérifiées dans `~/Téléchargements/ICONS/` (recherche sans casse).

| id | Nom | Voie | Rareté | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|
| `lightning_bolt` | Lightning Bolt | Départ | Départ | 1 | Attack | Cast | Deal 12. | Deal 16. | `spell_nature_lightning` |
| `lightning_shield` | Lightning Shield | Départ | Départ | 1 | Skill | — | Gain 5 Absorb. | Gain 8 Absorb. | `spell_nature_lightningshield` |
| `flame_shock` | Flame Shock | Départ | Départ | 1 | Attack | — | Deal 3. / Apply DoT 3 | Deal 5. / Apply DoT 4 | `spell_fire_flameshock` |
| `searing_totem` | Searing Totem | Départ | Départ | 1 | Power | Fire Totem 3 ⌛ | End of turn: deal 3 to a random enemy. | End of turn: deal 4 to a random enemy. | `spell_fire_searingtotem` |
| `lava_burst` | Lava Burst | Elemental | Commune | 2 | Attack | Cast | Deal 16. / DoT: deal 10 more. | Deal 20. / DoT: deal 13 more. | `spell_shaman_lavaburst` |
| `frost_shock` | Frost Shock | Elemental | Commune | 1 | Attack | — | Deal 6. / DoT: apply Demoralized 2 ⌛ | Deal 9. / DoT: apply Demoralized 2 ⌛ | `spell_frost_frostshock` |
| `magma_totem` | Magma Totem | Elemental | Commune | 1 | Power | Fire Totem 2 ⌛ | End of turn: deal 3 to all. | End of turn: deal 4 to all. | `spell_fire_volcano` |
| `earth_shock` | Earth Shock | Elemental | Commune | 1 | Attack | — | Surge: deal 3 + 3 per Maelstrom. | Surge: deal 4 + 4 per Maelstrom. | `spell_nature_earthshock` |
| `chain_lightning` | Chain Lightning | Elemental | Inhabituelle | 2 | Attack | Cast | Deal 13 to all. | Deal 17 to all. | `spell_nature_chainlightning` |
| `totem_of_wrath` | Totem of Wrath | Elemental | Inhabituelle | 1 | Power | Fire Totem 2 ⌛ | DoT: your Attacks deal 4 more. | DoT: your Attacks deal 6 more. | `spell_fire_totemofwrath` |
| `wind_shear` | Wind Shear | Elemental | Inhabituelle | 0 | Skill | Cooldown 2 | Interrupt the target's cast. / +1 Maelstrom. | idem (Cooldown 1) | `spell_nature_cyclone` |
| `purge` | Purge | Elemental | Inhabituelle | 0 | Skill | Cooldown 3 | Remove the target's Absorb and Strength. | idem (Cooldown 2) | `spell_nature_purge` |
| `lava_surge` | Lava Surge | Elemental | Rare | 1 | Power | Power | When DoT damages an enemy: +1 Maelstrom. | idem (coût 0) | `spell_shaman_lavasurge` |
| `elemental_mastery` | Elemental Mastery | Elemental | Rare | 1 | Power | Power | Instant Cast at 3 Maelstrom. | idem (coût 0) | `spell_nature_wispheal` |
| `stormstrike` | Stormstrike | Enhancement | Commune | 1 | Attack | Cooldown 1 | Deal 5 twice. | Deal 7 twice. | `ability_shaman_stormstrike` |
| `lava_lash` | Lava Lash | Enhancement | Commune | 1 | Attack | — | Deal 6. / Fire Totem: deal 5 more. | Deal 8. / Fire Totem: deal 6 more. | `ability_shaman_lavalash` |
| `crash_lightning` | Crash Lightning | Enhancement | Commune | 1 | Attack | — | Deal 4 to all. / +1 Maelstrom. | Deal 6 to all. / +1 Maelstrom. | `spell_shaman_crashlightning` |
| `strength_of_earth_totem` | Strength of Earth Totem | Enhancement | Commune | 1 | Power | Earth Totem 3 ⌛ | Your Attacks deal 2 more. | Your Attacks deal 3 more. | `spell_nature_earthbindtotem` |
| `windfury_totem` | Windfury Totem | Enhancement | Inhabituelle | 1 | Power | Air Totem 2 ⌛ | First Attack each turn: played twice. | idem (Air Totem 3 ⌛) | `spell_nature_windfury` |
| `grace_of_air_totem` | Grace of Air Totem | Enhancement | Inhabituelle | 1 | Power | Air Totem 3 ⌛ | Your Attacks give 2 Maelstrom. | idem (coût 0) | `spell_nature_invisibilitytotem` |
| `shamanistic_rage` | Shamanistic Rage | Enhancement | Inhabituelle | 1 | Skill | Cooldown 3 | Gain 9 Absorb. / +2 Maelstrom. | Gain 12 Absorb. / +2 Maelstrom. | `spell_nature_shamanrage` |
| `healing_surge` | Healing Surge | Enhancement | Inhabituelle | 0 | Skill | Cast, Exhaust | Heal 8. | Heal 12. | `spell_nature_healingway` |
| `maelstrom_weapon` | Maelstrom Weapon | Enhancement | Rare | 1 | Power | Power | Instant Casts cost 0. | idem (coût 0) | `spell_shaman_maelstromweapon` |
| `doom_winds` | Doom Winds | Enhancement | Rare | 1 | Skill | Exhaust | This turn, Attacks are played twice. | idem (coût 0) | `ability_ironmaidens_swirlingvortex` |
| `healing_stream_totem` | Healing Stream Totem | Restoration | Commune | 1 | Power | Water Totem 3 ⌛ | Start of turn: heal 3. | Start of turn: heal 4. | `inv_spear_04` |
| `stoneskin_totem` | Stoneskin Totem | Restoration | Commune | 1 | Power | Earth Totem 3 ⌛ | Start of turn: gain 3 Absorb. | Start of turn: gain 5 Absorb. | `spell_nature_stoneskintotem` |
| `healing_wave` | Healing Wave | Restoration | Commune | 1 | Skill | Cast, Exhaust | Heal 12. | Heal 16. | `spell_nature_magicimmunity` |
| `windwall_totem` | Windwall Totem | Restoration | Commune | 1 | Power | Air Totem 2 ⌛ | Enemies deal 2 less per hit. | Enemies deal 3 less per hit. | `spell_nature_earthbind` |
| `fire_nova` | Fire Nova | Restoration | Commune | 1 | Attack | — | Deal 2 + 2 per totem to all. | Deal 3 + 3 per totem to all. | `spell_fire_sealoffire` |
| `earth_shield` | Earth Shield | Restoration | Inhabituelle | 1 | Skill | — | Gain Earth Shield 4 | Gain Earth Shield 6 | `spell_nature_skinofearth` |
| `chain_heal` | Chain Heal | Restoration | Inhabituelle | 1 | Skill | Cast, Exhaust | Heal 5 per totem. | Heal 7 per totem. | `spell_nature_healingwavegreater` |
| `mana_tide_totem` | Mana Tide Totem | Restoration | Inhabituelle | 1 | Power | Water Totem 2 ⌛ | Start of turn: +1 mana. | idem (coût 0) | `spell_frost_summonwaterelemental` |
| `reincarnation` | Reincarnation | Restoration | Rare | 1 | Power | Power | Last Breath: return with half your HP. | idem (coût 0) | `spell_nature_reincarnation` |
| `totemic_mastery` | Totemic Mastery | Restoration | Rare | 1 | Power | Power | Your totems last 1 more turn. | idem (coût 0) | `spell_nature_nullward` |

Comptes : 4 de départ ; Elemental 10 (4 communes, 4 inhabituelles, 2 rares) ; Enhancement 10 (4/4/2) ;
Restoration 10 (5/3/2) ; soit 13 communes, 11 inhabituelles, 6 rares. Totems : 10 (Fire 4 avec Searing,
Earth 2, Water 2, Air 3), assez pour que chaque emplacement soit un choix.

Précisions de règle par carte :

- **Deck de départ** : une seule Lightning Bolt, parce qu'une seule incantation est permise à la fois ;
  quatre Lightning Bolt laisseraient une carte morte dans une main sur deux. L'attaque répétée est
  Flame Shock (elle donne le Maelstrom et le DoT qu'Elemental exploite) ; Lightning Bolt montre le Cast et
  l'instantané, Searing Totem le totem.
- **Lightning Bolt** : 12 (GDD : 14) ; un Cast à 1 mana, sur la base d'Holy Fire (24 pour 2).
- **Searing Totem** : 3 par fin de tour (GDD : 4) parce que « Totem 3 ⌛ » joue 4 fois (12 au total).
- **Lava Burst, Frost Shock, Totem of Wrath** : « DoT: » = la cible a du DoT au moment où l'effet joue.
- **Earth Shock** : à 5 Maelstrom, 18 (amélioré 24) ; c'est le choix entre l'instantané et le choc.
- **Purge** : retire tout l'Absorb et toute la Strength de la cible (VanCleef, élites qui se renforcent).
- **Lava Surge** : chaque tick de DoT sur un ennemi, pendant le tour ennemi, donne +1.
- **Elemental Mastery** : le seuil de l'instantané passe à 3 ; le plafond reste 5.
- **Stormstrike** : deux coups ; joué deux fois sous Windfury, quatre coups.
- **Windfury Totem** : la première carte Attack jouée dans le tour pendant que le totem est posé ; si une
  Attack a déjà été jouée ce tour, rien avant le tour suivant.
- **Grace of Air Totem** : chaque carte Attack donne 2 au lieu de 1 (4 si jouée deux fois).
- **Healing Surge** : à 0 mana, sert à encaisser l'instantané quand on n'a rien d'autre ; sinon c'est un
  soin en Cast qui occupe l'emplacement d'incantation.
- **Maelstrom Weapon** : une carte Cast coûte 0 quand elle sera instantanée (Maelstrom au seuil) ; le coût
  affiché en main suit.
- **Doom Winds** : toutes les cartes Attack jouées ce tour, après elle.
- **Windwall Totem** : chaque coup ennemi baisse de 2, après Strength et avant Demoralized (minimum 0).
- **Fire Nova** : compte les totems au moment où elle est jouée.
- **Chain Heal** : compte les totems à la résolution (début du tour suivant), instantané compris.
- **Mana Tide Totem** : posé, rien ce tour ; +1 mana au début des tours 2 et 3 (Water Totem 2 ⌛).
- **Reincarnation** : PV remis à la moitié des PV max (arrondi bas) ; le tour ennemi continue.
- **Totemic Mastery** : +1 à la durée des totems posés après elle.

## 3. Les trois voies

### Elemental — « Les Cast instantanés »

**Moteur.** Flame Shock pose le DoT qui renforce Lava Burst, Frost Shock et Totem of Wrath ; les
attaques montent le Maelstrom jusqu'à l'instantané. Un tour à 5 lance deux gros sorts : un instantané et
un autre en Cast.

**Cartes.** Lava Burst, Frost Shock, Magma Totem, Earth Shock, Chain Lightning, Totem of Wrath, Wind Shear,
Purge, Lava Surge, Elemental Mastery.

**Avec Enhancement.** Les attaques d'Enhancement (Stormstrike, Crash Lightning) remplissent le Maelstrom
pour les Lava Burst instantanés ; Lava Lash profite des totems de Fire d'Elemental ; Maelstrom Weapon rend
ces instantanés gratuits.
**Avec Restoration.** Les totems de Fire remplissent un emplacement pour Fire Nova et Chain Heal ;
Windwall Totem protège l'incantation des coups qui interrompent ; Healing Wave instantané à 5.

**Tour type** (Maelstrom 4, 3 mana, un Gnoll sous DoT 3) : Frost Shock sur le Gnoll (6, Demoralized 2 ⌛,
Maelstrom 5), Lava Burst sur le Gnoll : instantané, 16 + 10 = 26, Maelstrom 0 puis 1.

### Enhancement — « Le Maelstrom à 5 chaque tour »

**Moteur.** Des attaques à 1 mana, doublées par les totems d'Air, remplissent le Maelstrom en un seul tour ;
l'instantané paie un Cast sans attente. Les totems de Fire et d'Earth ajoutent à chaque coup.

**Cartes.** Stormstrike, Lava Lash, Crash Lightning, Strength of Earth Totem, Windfury Totem, Grace of Air
Totem, Shamanistic Rage, Healing Surge, Maelstrom Weapon, Doom Winds.

**Avec Elemental.** Searing, Magma et Totem of Wrath tiennent l'emplacement Fire pour Lava Lash ; Flame
Shock sous Totem of Wrath rend chaque coup de Stormstrike plus fort ; Lava Burst et Chain Lightning sont
les meilleurs instantanés.
**Avec Restoration.** L'emplacement Air devient un choix (Windfury pour frapper, Windwall pour tenir) ;
Fire Nova est une attaque qui compte les totems ; Healing Wave et Chain Heal sont les instantanés de soin.

**Tour type** (Windfury Totem et Searing Totem posés, Maelstrom 0, 3 mana) : Stormstrike jouée deux fois
(4 × 5 = 20, Maelstrom 2), Lava Lash (Fire Totem : 11, Maelstrom 3), Crash Lightning (4 à tous, +1 et +1,
Maelstrom 5). Au tour suivant, Lightning Bolt part tout de suite.

### Restoration — « Quatre totems en même temps »

**Moteur.** Les quatre emplacements remplis soignent (Healing Stream), absorbent (Stoneskin) et
réduisent chaque coup (Windwall) ; Fire Nova et Chain Heal grandissent avec le nombre de totems.
Earth Shield soigne à chaque coup reçu.

**Cartes.** Healing Stream Totem, Stoneskin Totem, Healing Wave, Windwall Totem, Fire Nova, Earth Shield,
Chain Heal, Mana Tide Totem, Reincarnation, Totemic Mastery.

**Avec Elemental.** Les totems de Fire d'Elemental complètent la rangée et frappent ; le Maelstrom des
attaques rend Healing Wave et Chain Heal instantanés.
**Avec Enhancement.** Strength of Earth contre Stoneskin, Windfury contre Windwall : chaque emplacement est
un arbitrage attaque / défense ; Shamanistic Rage complète l'Absorb.

**Tour type** (Healing Stream, Stoneskin et Searing posés, 3 mana) : Windwall Totem (quatre totems),
Fire Nova (2 + 2 × 4 = 10 à tous), Chain Heal (Cast, résout au tour suivant). Tour ennemi : chaque coup
perd 2. Début du tour suivant : Healing Stream soigne 3, Stoneskin donne 3 Absorb, Chain Heal soigne 5 par
totem encore posé.

## 4. Bibelots de classe

| id | Nom | Rareté | Effet (une ligne affichée) | Icône |
|---|---|---|---|---|
| `totemic_relic` | Totemic Relic | Départ | Your first totem each combat lasts 1 more turn. | `inv_misc_idol_03` |
| `totem_of_rage` | Totem of Rage | Commun | Start each combat with 2 Maelstrom. | `inv_relics_totemofrage` |
| `totem_of_life` | Totem of Life | Commun | When one of your totems fades: heal 2. | `inv_relics_totemoflife` |
| `flurry_axe` | Flurry Axe | Inhabituel | Your first Attack each combat is played twice. | `inv_axe_09` |
| `totem_of_sustaining` | Totem of Sustaining | Inhabituel | Start each combat with Earth Shield 3. | `inv_misc_idol_02` |
| `earthshatter_totem` | Earthshatter Totem | Rare | With four totems up: +1 mana each turn. | `inv_relics_totemofrebirth` |

Totemic Relic amorce dès le premier tour : Searing Totem posé au tour 1 dure jusqu'au tour 5. Totem of
Life joue à l'extinction comme au remplacement. Earthshatter Totem vérifie au début du tour, après la
pioche (les totems éteints à la fin du round précédent ne comptent plus). Rareté « Départ » : nouvelle
valeur, jamais tirée.

## 5. Progression

| Niveau | Elemental | Enhancement | Restoration | Bibelots |
|---|---|---|---|---|
| 1 | Lava Burst, Frost Shock, Magma Totem, Earth Shock, Chain Lightning, Wind Shear | Stormstrike, Lava Lash, Crash Lightning, Strength of Earth Totem, Windfury Totem, Shamanistic Rage | Healing Stream Totem, Stoneskin Totem, Healing Wave, Windwall Totem, Fire Nova, Earth Shield | Totemic Relic, Totem of Rage |
| 2 | Totem of Wrath | Grace of Air Totem | Chain Heal | — |
| 3 | — | — | — | Totem of Life |
| 4 | Purge | Healing Surge | Mana Tide Totem | — |
| 5 | — | — | — | Totem of Sustaining |
| 6 | Lava Surge | Maelstrom Weapon | Reincarnation | — |
| 7 | Elemental Mastery | Doom Winds | Totemic Mastery | Flurry Axe, Earthshatter Totem |

Plus les 4 cartes de départ au niveau 1 (22 cartes). Pourquoi cet ordre :

- **Niveau 1 complet par voie** : chaque voie a son moteur entier (Elemental : DoT + gros Cast +
  instantané ; Enhancement : attaques + Windfury ; Restoration : un totem de chaque élément sauf Fire, que
  fournit Searing). Wind Shear (Interrupt) est là dès le départ. Avec Searing, les quatre emplacements
  sont remplissables au niveau 1.
- **Niveaux 2, 4, 6** : des façons de jouer. Totem of Wrath : le totem qui fait d'Elemental un deck de
  frappe sous DoT. Grace of Air : un deuxième totem d'Air, donc un vrai choix d'emplacement. Chain Heal :
  le soin qui compte les totems. Purge : la réponse aux élites qui se renforcent. Healing Surge : encaisser
  l'instantané sans gros sort. Mana Tide : des tours à 4 mana. Lava Surge : le DoT qui fait l'instantané.
  Maelstrom Weapon : instantanés gratuits. Reincarnation : le Last Breath.
- **Niveau 7** : les rares qui changent la règle — seuil à 3, tour où tout frappe deux fois, totems qui
  durent.

## 6. Besoins moteur et interface

### Moteur (`Core/`, Lua pur)

1. **Ressource** `c.player.maelstrom` (0..5), journal `{ t = "maelstrom", n, total }`, remise à 0 dans
   `Combat.new`. Gain dans `Combat.play` (Cast non instantané : à la mise en incantation) et après
   `Combat.resolveCard` (autres cas), +2 si jouée deux fois. Seuil par `Combat.modify(c, "maelstromAt", 5)`
   (Elemental Mastery).
2. **Instantané** : dans `Combat.play`, une carte `cast` jouée avec Maelstrom ≥ seuil se résout tout de
   suite (`resolveCard`), Maelstrom à 0, journal `{ t = "instant" }`. `Combat.canPlay` laisse passer une
   carte Cast pendant une incantation si elle sera instantanée. `Combat.cost` : crochet pour Maelstrom
   Weapon (coût 0 si instantanée).
3. **Totems** : `c.player.totems = { earth = {card = inst, turns = n, fresh = true}, fire = …, water = …,
   air = … }` (données simples, clonables). Champs de carte : `totem = "fire"`, `totemTurns = 3`, `hooks`
   comme un Power. `afterPlay` : remplacement (ancienne carte en défausse, crochet `onTotemFade`), pose
   avec `turns = Combat.modify(c, "totemTurns", n, def)` (Totemic Mastery, Totemic Relic). Baisse dans
   `Combat.endRound` avec la même règle que `decayUnit` (`fresh` sauté une fois) ; extinction → défausse +
   `onTotemFade`. Journaux `totem_set`, `totem_fade`.
4. **Crochets** : `Combat.fire` et `Combat.modify` doivent parcourir les totems posés (ordre Earth, Fire,
   Water, Air) en plus des Powers et des bibelots : `onTurnStart` (Start of turn), `onTurnEnd` (End of
   turn), `damage` (Strength of Earth, Totem of Wrath), `enemyDamage` (Windwall Totem : −N, minimum 0),
   nouveaux `maelstromGain` (Grace of Air) et `playTwice` (Windfury).
5. **« Played twice »** : `resolveCard` deux fois (second passage sur la cible, sinon ennemi vivant le plus
   à gauche), `afterPlay` une fois ; drapeaux par tour `c.player.flags.firstAttackDone`,
   `c.player.flags.doomWinds` ; jamais plus de deux résolutions.
6. **Earth Shield** : nouvel état `earth_shield` dans `Core/Statuses.lua` (sans `duration`, texte
   « When hit: heal 3, then lose 1 charge. ») ; dans `executeMove`, après chaque coup d'une action `attack`
   sur le joueur (même absorbé), soin 3 et −1.
7. **Effets** : `purge` (Absorb et `force` de la cible à 0), compte des totems (`per totem`), condition
   d'élément, `spend`/`surge` sur le Maelstrom (Earth Shock), crochet `onDotTick` dans `tickPeriodic`
   (Lava Surge), mana au début du tour (Mana Tide, Earthshatter) après la remise du mana.
8. **Hasard** : Searing Totem tire sa cible dans un flux nommé (par exemple `c.rng.ai` ou un flux
   `totem`), jamais `math.random`.
9. **Statistiques** : instantanés par combat, Maelstrom perdu au plafond, tours passés à 5 sans Cast,
   nombre moyen de totems posés, temps de pose par emplacement, soins des totems, coups réduits par
   Windwall, charges d'Earth Shield consommées.
10. **Bots** : l'heuristique doit savoir qu'à 5 la prochaine Cast part tout de suite (ordonner attaque puis
    Cast), estimer la valeur restante d'un totem avant de le remplacer, et compter les totems pour Fire
    Nova et Chain Heal.

### Interface (`UI/`)

1. **Rangée de totems** : quatre emplacements carrés côte à côte sous la barre de vie du héros, ordre
   fixe Earth, Fire, Water, Air (celui de la barre de totems de WoW). Chaque emplacement a un liseré de
   la couleur de son élément (Earth ocre, Fire rouge orangé, Water bleu, Air blanc bleuté). Vide : le
   liseré et une rune d'élément pâle. Occupé : l'icône de la carte dans le cadre.
2. **Durée sans texte** : sous chaque emplacement, une rangée de points, un par tour restant (valeur du
   compteur, comme les états à sablier) ; au dernier tour, le cadre pulse. Infobulle : nom, texte de la
   carte et tours restants.
3. **Survol d'une carte totem en main** : l'emplacement visé s'illumine ; s'il est occupé, le totem en
   place se grise avec une croix (il sera remplacé).
4. **Plaque** : « Fire Totem 3 ⌛ », le mot de l'élément dans sa couleur.
5. **Maelstrom** : pastille violette à cinq crans. Au seuil, la pastille s'allume en bleu électrique et
   chaque carte Cast en main prend un liseré d'éclair (« partira tout de suite ») ; coût 0 affiché avec
   Maelstrom Weapon. À la résolution instantanée, la carte va directement de la main à la cible.
6. **Jouée deux fois** : un « ×2 » bref au-dessus de la carte qui résout.
7. **Earth Shield** : jeton d'état ordinaire avec le nombre de charges ; un petit éclat vert à chaque soin.
8. **Lisibilité** : c'est la classe la plus chargée à l'écran ; emplacements de 24 unités au plus,
   aucun chiffre sur les totems (les points suffisent), à vérifier dans le harnais hors jeu.

## 7. Risques d'équilibrage et mesures

1. **Écran chargé** (risque du GDD) : quatre emplacements, une pastille, des jetons d'état. À vérifier :
   planche du harnais (`Sim/ui_harness.lua`) avec quatre totems à des durées différentes ; lisible sans
   infobulle.
2. **Soin récurrent** : les totems reviennent dans le deck (pas Exhaust), contrairement aux soins du
   Priest. Risque de combats qui traînent. À mesurer : tours par combat (cible : comme le Priest, ≤ 8 au
   boss), soins par combat, part du soin venant des totems.
3. **Survie (soin + Absorb)** : PV perdus cibles proposées (Priest, `docs/equilibrage.md` : normal 15,4 ;
   élite 20,0 ; boss 51,6) : **normal ≤ 15, élite ≤ 20, boss ≤ 50**, en comptant les PV regagnés ;
   victoires à ± 5 points du Priest.
4. **Rafales d'Enhancement** : Windfury + Stormstrike + Strength of Earth, Doom Winds. À mesurer :
   dégâts maximum en un tour, `pick=random` sur Windfury Totem et Doom Winds.
5. **Instantané trop fréquent** (Grace of Air, Crash Lightning, Lava Surge à plusieurs ennemis,
   Elemental Mastery) : instantanés par combat, tours à 5 sans Cast. Si l'instantané devient la norme, le
   Cast perd son risque.
6. **Restoration seule** : peu de dégâts (Fire Nova, cartes de départ, Searing). À mesurer : victoires d'un
   deck mono-Restoration ; levier : Fire Nova, Searing Totem.
7. **Deck de départ** : quatre Flame Shock font beaucoup de DoT dès le départ. À comparer au Priest de
   départ (victoires sans aucune carte prise).
8. **Identité** : Elemental frôle le Mage Fire (Cast, brûlure, instantané) et le Druid Moonkin ;
   Enhancement frôle le Warrior Fury (beaucoup d'attaques) ; Restoration frôle le Priest Holy (soins en
   Cast). Ce qui doit rester propre au Shaman : les totems à durée et le choix d'emplacement. Aucune carte
   Shaman ne donne de Strength permanente ni ne soigne en attaquant (Atonement).

## Points à faire trancher

- Composition du deck de départ (4 Flame Shock, 1 Lightning Bolt) à cause de la règle « une incantation à
  la fois ».
- Durée des totems = règle du sablier des bienfaits (reste du tour + N) ; chiffres ajustés en conséquence
  (Lightning Bolt 12, Searing 3, Stoneskin 3 au lieu de 14, 4, 4).
- L'instantané se joue pendant une incantation en cours ; le +1 d'une Attack vient après le passage à 0.
- Earth Shield soigne (plutôt qu'une Absorb) à chaque coup reçu.
- Si le Mage fait d'« Instant » un état, le Maelstrom au seuil pourrait simplement donner cet état.
- PV 60.
