# TuskUpLoot

## 1.3.0

#### Addon Networking

- Master Looter broadcast loot drops from encounter
- Marked items as acquired broadcasts to raid/party/guild members

## 1.2.1

#### Better Looting Handling

- Trash loot should now be properly accounted for
- Items dropped should only be announced once


## 1.2.0

#### Actual Drop Capturing & Tracking

- Listed and non-listed items share display logic
- Item Cache for links and tooltips for all referenced Items
- Attempt capture of actual loot drops (master looter only)
- Persist drop data with cleared encounters


## 1.1.0

- Open addon to users outside of `<Tusk Up>` guild
- Event handler refactor & bug fixes


## 1.0.3

#### Encounter tracking fixes

- Addresses bug with how instance ids and unique zone ids were being handled
- Raid lockouts now correctly identify as individual runs

## 1.0.2

#### Manual Character Ordering.

- Adds third tabular view to Character list
- Allow manually ordering the list of Characters within this new view
- Preserves manual sorting order between sessions (in DB)
- Draggable Character names within manual sorting list facilitate resorting

## 1.0.1

#### Character List Ordering.

- Fix Character name ordering to be case-insensitive
- Add grouping by Character Class
- Tabular UI to switch between Character lists
- Reversible ordering for both display choices

## 1.0.0

#### First public release.

- TBC Anniversary support (`Interface 20505`)
- Import BIS gear sets from sixtyupgrades JSON
- Characters tab: class-colored summary, gear sets (newest import first), tabular slots, acquired toggles
- Items tab: who needs each item, mark acquired
- Raids tab: instance loot catalog, need counts, boss clear tracking
- Slash commands: `/tul`, `/tuskup`
