# MultiboxLoot

A World of Warcraft: Forever addon for multiboxers. When your leader is master looter, it hands
each drop to the party member whose profession uses it: cloth to your tailor, leather to your
leatherworker, meat and fish to your cook, herbs to your alchemist, and so on. You don't have to
click anything.

## How it works

The addon runs on every character. Each one reports its professions and free bag space to the
group in hidden addon messages. When the leader opens a corpse, the addon works through the loot
one slot at a time:

1. **Skips** coins, quest items, locked slots, and anything that isn't master loot (herbing,
   mining, fishing, opened containers).
2. **Classifies** the item: Cloth, Leather, Herb, Metal, Cooking, Enchanting, Gem, and others.
3. **Picks a recipient** from that category's list of professions. Among the characters that have
   the profession, it skips anyone who isn't eligible for that corpse or whose bags are full, and
   the highest skill wins.
4. **Falls back** to your bank alt, and then to the master looter.
5. **Gives** the item. If the give doesn't go through, it treats that character as full for the
   rest of the corpse and tries the next one.

| Material | Goes to |
|---|---|
| Leather, hides, scales | Leatherworking |
| Cloth | Tailoring |
| Meat, fish, eggs | Cooking |
| Herbs | Alchemy |
| Herb seeds | Alchemy |
| Ore | Mining (to smelt) → Blacksmithing → Engineering |
| Bars, stone | Blacksmithing → Engineering |
| Dusts, essences, shards | Enchanting |
| Parts and devices | Engineering |
| Gems | Blacksmithing → Engineering → Leatherworking → Tailoring → Enchanting |
| Arcane Crystal | Alchemy → Enchanting |
| Stat scrolls (Agility, Intellect, Protection, Spirit, Stamina, Strength) | Highest-level mage |
| Everything else | Bank alt → master looter |

Gathering professions never receive what they gather; it belongs with the crafters. The one
exception is ore, which a miner needs to smelt.

The item lists cover the vanilla materials plus the new Forever materials: Stranglevine,
Heavy Thorium, Pristine Leather, Fel Crystal and others. Items not in the lists fall back to their
item type.

## Requirements

- WoW: Forever. The client must use English, because profession names are matched in English.
- The addon installed and enabled on **every** character in the group.
- The group set to **Master Loot**, with the threshold at the lowest quality you want handed out.
  Poor is recommended, since most profession materials are white quality. The leader must be the
  master looter.

## Install

Copy or symlink the `MultiboxLoot` folder into your Forever AddOns folder, then restart the game:

```sh
ln -s "$PWD/MultiboxLoot" "/Applications/World of Warcraft/_forever_/Interface/AddOns/MultiboxLoot"
```

On Windows the folder is usually
`C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`.

## Usage

| Command | What it does |
|---|---|
| `/mbl status` | Lists every group member's professions, skill and free bag slots, and flags anyone without the addon |
| `/mbl bank <name>` | Sets the bank alt for unclaimed items. Run `/mbl bank` with no name to clear it |
| `/mbl debug` | Turns the dry run on or off: prints each slot's decision and gives nothing out |
| `/mbl quiet` | Turns the per-item chat lines on or off |
| `/mbl on` / `/mbl off` | Turns distribution on or off |

To get started, set your bank alt with `/mbl bank Mulename`. Then turn on the dry run with
`/mbl debug`, loot a few corpses to check the decisions, and run `/mbl debug` again to start
handing out loot for real.

## Development

The decision logic lives in `Items.lua` and `Rules.lua`, which don't call the WoW API. That means
they can be tested with plain Lua 5.1 or later outside the game:

```sh
lua tests/run.lua
```

| File | Role |
|---|---|
| `MultiboxLoot/Core.lua` | Shared setup, event handling, saved settings, `/mbl` |
| `MultiboxLoot/Items.lua` | Item ID lists and the fallback by item type |
| `MultiboxLoot/Rules.lua` | Profession lists per category and recipient selection |
| `MultiboxLoot/Roster.lua` | Shares professions and free bag slots between characters |
| `MultiboxLoot/Distributor.lua` | Master loot window handling |

To add a missing material, put its ID in the right list in `Items.lua` and add a matching test
in `tests/items_test.lua`. Item IDs can be checked at `https://www.wowhead.com/forever/item=<ID>`.

Design notes are in [`docs/superpowers/specs`](docs/superpowers/specs).

## License

[MIT](LICENSE)
