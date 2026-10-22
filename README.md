# CodeBreaker v0.7.4

Fixes **ONE HIT KO** and incoming-move **INFINITE HP** when 1025Dex replaces
the normal damage calculation. Damaging player hits use the opponent's remaining
HP; blocked, missed, immune, failed and zero-damage moves retain their normal result.
The cheat does not amplify enemy attacks or attacks on a player-side partner.

Gen 3 **INFINITE HP/PP** now refill both active player slots and the separate
battle-party copies, including after switching. **BURN FOE** covers both living
opponents in doubles and preserves existing status conditions. **QUICK DAYCARE
EGG** also works through Ruby/Sapphire's native daycare policy without replacing
an already pending egg or allowing incompatible parents.

Existing settings carry over. Replace CodeBreaker and restart G1R.

## Retained from 0.7.3

In Emerald, turn **CHEATS → FRONTIER LEGENDS → ON** to enter the Battle
Frontier with restricted legendary Pokémon. This bypasses the species ban
at both reception and party selection. Turn it OFF to restore the normal
ban immediately. Egg, level, duplicate-species, duplicate-item and Pyramid
held-item rules still apply; the Factory keeps its rental system.

## Retained from 0.7.2

With **1025Dex 1.2.21**, Gen 3's **CHEATS → WILD POKEMON → POKEMON** list
includes all 364 shipped Mega and alternate forms after the 1,025 base species.
Use L/R to jump 50 entries. Selecting a form retains its exact identity for
Battle Now and Wild Pick encounters, including after restarting the game.
Install both updated mod folders and restart. This spawns the selected form
directly; the picker does not trigger a battle transformation.

For Gen1Recomp **0.3.54 or newer, below 0.4.0**. Supports Red, Blue,
Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire and Emerald.
Replace the old CodeBreaker ZIP and restart the launcher. Open **CHEATS** from
the in-game Start menu. The internal `firered_codebreaker` ID is unchanged so
existing settings carry over. Do not enable GameShark or Action Replay alongside it.

## Game-specific menus

Each game only lists applicable controls. Unsupported saved toggles are ignored,
and the exported toggle API rejects cheats that are unavailable in the active game.

| Controls | Games |
| --- | --- |
| Wall Walk, No Battles, money/coins, HP/PP, badges, One Hit KO, Burn Foe, trainer catches | All 11 |
| Wild species/level and Battle Now, Give Item, Teach Move, stat editor | All 11 |
| 100% Catch Rate, Seen All/Caught All, EXP multiplier (1X–10X) | All 11 |
| Safari balls/steps | R/B/Y and all five Gen 3 games |
| Friendship | Yellow (starter Pikachu); Gen 2/3 (party Pokémon) |
| Wild gender/shiny | Gen 2/3 |
| Wild nature/Max IVs; IV/EV editor | Gen 3 |
| DV/Stat EXP editor; Surfboard | Gen 1/2 |
| PC Anywhere, fast egg hatching/daycare eggs, Party EXP, Always Obey | Gen 3 |
| Fast Walk, Bike Indoors/Over Water, No Recharge, Escape Any Battle, Always Your Turn | Gen 3 |
| Instant VS Seeker recharge | FireRed/LeafGreen |
| Rebattle Trainers, Battle Points, Unlock Event Islands | Emerald |
| Celebi/GS Ball event | Crystal |

The old PAY DAY FIX is hidden and disabled: this engine already implements Pay
Day, so the compatibility repair would award extra money.
Master Balls, Rare Candy and PP Ups remain available through GIVE ITEM instead
of duplicate main-menu cheats. Item, move and Pokémon lists use the active game's
loaded data. A cheat cannot add a Pokémon or move that the game has not loaded.

Teleport uses the active game's native destinations: Kanto for R/B/Y, Johto/Kanto
for G/S/C, Kanto/Sevii for FR/LG, and Hoenn for R/S/E. Ruby/Sapphire list Battle
Tower; Emerald lists Battle Frontier. Gen 3 destinations use imported heal-location
data and title-specific constants rather than another game's coordinates.

## Controls

Up/down selects a row; left/right pages lists. A activates or confirms, B goes
back. Gen 3 L/R jumps 50 entries in long Pokémon/item/move/value lists. Gen 1/2
EXP MULTIPLIER cycles 1X–10X with A. Gen 3 opens a value picker.

WILD PICK replaces random encounters with the selected Pokémon. NO BATTLES
suppresses random encounters, so turn it off to use WILD PICK. AUTO keeps the
native encounter level; BATTLE NOW requires a chosen level. Gen 1 has no gender,
shininess or nature controls. Gen 2 shiny/gender settings use its native DVs.
Gen 3 uses its native personality values and the engine's shiny image cache.

WALL WALK offers OFF, SAFE (retains boundaries) and UNSAFE (forced movement).
Surfboard uses the native surf action while temporarily supplying Surf; ordinary
terrain/story restrictions still apply. PC Anywhere requires an active Gen 3
session outside battle. Persistent grants such as items, badges, Dex entries and
event unlocks remain after their control is turned off.

## 1025Dex

1025Dex is optional. The Gen 3 picker and Seen/Caught actions retain support for
registered National species up to 1,025, including selected encounter protection.
Without an expansion, only the game's loaded roster is used. Gen 1/2 use their
own loaded species, move and item registries.

## Changes and verification

0.7.0 enables all eleven games, fixes GB/GBC Infinite PP helper binding and
heals every non-egg party slot. It adds native GB/GBC catch, Dex and EXP controls,
fixes Ruby/Sapphire destinations and breeding-policy selection, and preserves the
current engine's shiny/Spinda rendering function signatures. Persistent Gen 3
wrappers refresh their controller across game changes and fall through when the
owning mod is inactive. The cheat menu is named CODEBREAKER in every generation.

Validated against Gen1Recomp 0.3.95 with full-entrypoint regression fixtures for
all eleven games in Lua 5.3 and LuaJIT, using the current engine's Sandbox and
Hooks. Coverage includes every catalog toggle, supported effects, HP/PP/currency,
native daycare policy dispatch, catch flows, item/move/friendship editing,
encounters, battle controls, badges, rematches and inactive-mod behavior.
The OHKO regression also uses 1025Dex's actual modern damage formula and native
Gen 1/2 damage application, with both hook registration orders. These automated
checks do not replace full playthroughs or testing on an Android device.

## Credits

Existing compatibility/runtime portions derive from goofwear's GameShark 0.9.11,
as in the previous CodeBreaker release. New all-game adapters and controls:
Bentley734/Codebreaker. This mod implements effects against native engine state;
it does not execute arbitrary hardware memory codes.

## 0.7.1 Gen 1/2 spawn and battle
Open CHEATS > SPAWN / BATTLE PKMN (first entry), choose POKEMON, set LEVEL, then BATTLE NOW.
WILD PICK optionally replaces normal encounters. With 1025Dex installed, the full roster is available.
National Dex selection uses 1025Dex's species-number API and excludes alternate forms from fallback numbering.
