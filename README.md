# Slay the Dragon

`SlayTheDragon` is a roguelike deckbuilder for **World of Warcraft: Forever** (interface 16001), meant to be played during taxi flights.

You pick a class, build a deck of cards along a branching path, and fight your way through seven Eastern Kingdoms zones up to Blackrock Mountain. An expedition is saved as you play: land, log out, and pick it up again on your next flight.

## Status

In development. Everything described below is playable, but numbers, cards and screens still change between versions, and parts of the interface have not been tested on every client setup. A save from a newer version of the addon is left untouched by an older one.

## Opening the game

- The window opens on its own when a flight starts and closes when you land (both can be turned off in the options).
- `/slay` (or `/slaythedragon`) opens or closes the window at any time.
- The minimap button: left-click opens or closes the window, right-click opens the options, drag to move it.
- The window closes when you enter combat in the world and comes back afterwards if you are still flying.

### Slash commands

- `/slay` : open or close the window
- `/slay options` : options (open on takeoff, close on landing, fast mode, minimap button, illustrated or painted scenery, window scale, animation speed, abandon the current expedition)
- `/slay center` : put the window back in the middle of the screen
- `/slay scenery` : switch between illustrated and painted scenery
- `/slay art`, `/slay text` : list missing art and truncated card texts, for bug reports

## How a run plays

- Each zone is a branching map of eight steps: fights, elites, encounters, a merchant, campfires and chests, then the zone boss.
- Fights are turn-based: you draw five cards, spend 3 mana a turn on attacks, skills and powers, and see what each enemy intends to do next. Enemies cast spells that some of your cards can interrupt.
- After a fight you choose a card to add to your deck. Gold buys cards, relics and potions at the merchant; campfires let you rest or upgrade a card.
- Beating a zone boss takes you to the next zone with your deck, relics, gold and potions, and heals half of your maximum health. Every zone after Westfall adds its own rule to the expedition.
- Defeating Nefarian at the end of Blackrock Mountain wins the expedition.

## Classes

All five classes are available from the start. Each has its own class resource, three paths (talent trees) of cards, a starting deck and a starting relic.

| Class | Resource | Paths |
|---|---|---|
| Priest | Insanity | Discipline, Shadow, Holy |
| Warrior | Rage (up to 5) | Arms, Fury, Protection |
| Rogue | Combo (up to 5) | Assassination, Combat, Subtlety |
| Mage | Arcane Charges (up to 4) | Fire, Frost, Arcane |
| Hunter | Frenzy (up to 5), with a pet that attacks on its own | Beast Mastery, Marksmanship, Survival |

## The campaign

An expedition always starts in Westfall and crosses the seven zones in order:

1. Westfall (Edwin VanCleef)
2. Duskwood (Morbent Fel)
3. Wetlands (Chieftain Nek'rosh)
4. Stranglethorn Vale (Jin'do the Hexxer)
5. Swamp of Sorrows (Somnus)
6. Burning Steppes (Grark Lorkrub)
7. Blackrock Mountain (Lord Victor Nefarius, who becomes Nefarian during the fight)

Every boss you beat counts right away, even if the expedition ends later.

## Progression

- **Class level (1 to 7)**: each class earns experience on every expedition, won or lost. Levels unlock more cards and relics for that class.
- **Epic cards**: each class has one epic card per zone, unlocked the first time that class beats the zone boss. An epic is earned during an expedition (from elites or the merchant), you carry at most one, and it acts as a rule that is active from the start of every fight.
- **Account unlocks**: the first time any class beats a zone boss, new neutral cards, relics, potions and encounters join every class's pool.
- **Mythic Keystones**: beating Nefarian with a class at key +N opens key +N+1 for that class, up to +5. Each key adds an affix (Fortified, Tyrannical, Bolstering, Necrotic, Famine) and more experience.

Progress is stored in the `SlayTheDragonDB` saved variable and shared by every character of the account.

## Installation

1. Download the latest release from CurseForge or from the GitHub releases page.
2. Extract the `SlayTheDragon` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
3. Restart the game client (a new addon is not picked up by `/reload`).

## Development

The game rules (`Core/`, `Data/`) are plain Lua 5.1 with no WoW API, so they run outside the game.

- Rule tests: `lua5.1 Sim/tests.lua` (also `Sim/tests_expedition.lua`, `Sim/tests_zones.lua`, `Sim/tests_epic*.lua`), each ending with `ALL PASS`.
- Screen previews without the game: `lua5.1 Sim/ui_harness.lua 1 build/snap` (SVG files).
- Balance simulation with bots: `luajit Sim/sim.lua runs=2000 bot=heuristic runner=expedition class=priest`.

Design notes, balance measurements and the interface reference are in `docs/` (in French).

## Credits

- Card frames: "Mechanized Magic" card pack by Dumivid (CC0).
- Font: Baloo Chettan 2 by Ek Type, licensed under the SIL Open Font License 1.1 (`Media/Fonts/OFL.txt`).
- World of Warcraft artwork, icons and interface elements used by the addon belong to Blizzard Entertainment.
