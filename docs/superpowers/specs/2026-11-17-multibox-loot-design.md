# MultiboxLoot — Design

**Date:** 2026-11-17
**Target:** World of Warcraft: Forever (Classic-family API). Private use, not published.

## Purpose

Automatically distribute Master Loot to the party member whose profession uses the item
(cloth → tailor, leather → leatherworker, meat → cook, herbs → alchemist, …). The user
multiboxes and controls every character in the party.

## Assumptions

- Loot method is always Master Loot, threshold Poor, with the multibox leader as master looter.
- The addon is installed on every character.
- Gathered materials (herbs, ore, skins picked up by the gatherer) are out of scope — only
  corpse/chest loot that passes through the master loot window is distributed.

## Behaviour

On `LOOT_OPENED`, if the player is the master looter and the addon is enabled, each loot slot
is processed one at a time:

1. **Skip** coins, and quest items — `isQuestItem` or `questID` from `GetLootSlotInfo`, or
   `classID == 12` from `GetItemInfoInstant`. Skipped slots stay on the corpse.
2. **Classify** the item into a category (see Items).
3. **Look up** the category's profession chain (see Rules).
4. **Pick a recipient:** for each profession in the chain, consider characters that
   - have the profession (from the roster),
   - appear in `GetMasterLootCandidate(slot, i)` for this slot (eligible for the corpse),
   - report free bag slots > 0 and are not marked full for this corpse.
   Highest skill wins. If none, go to the next profession in the chain.
5. **Fallback** when no profession recipient is found (or item is unclassified):
   bank alt (if set, eligible, not full) → master looter.
6. **Give** with `GiveMasterLoot(slot, candidateIndex)`. Wait for `LOOT_SLOT_CLEARED` before
   processing the next slot.

Each give prints `[MBL] <item> xN → <name> (<profession> <skill>)` unless quiet mode is on.

## Items (`Items.lua`)

`Classify(itemID) → category | nil`. Pure function.

- Primary: curated item-ID tables per category.
- Fallback: `GetItemInfoInstant` class/subclass (Tradeskill subclasses Cloth, Leather,
  Metal & Stone, Cooking, Herb, Enchanting, Parts/Devices). The classID/subClassID are passed
  in so the function stays pure and testable.

Categories: `Leather`, `Cloth`, `Cooking`, `Herb`, `HerbSeed`, `Ore`, `Metal`, `Enchanting`, `EngineeringParts`, `Gem`, `ArcaneCrystal`.

Item IDs (vanilla + Forever additions) were verified against Wowhead's Forever database
(`https://nether.wowhead.com/forever/tooltip/item/<ID>`) on 2026-11-17.

## Rules (`Rules.lua`)

| Category | Profession chain |
|---|---|
| Leather | Leatherworking |
| Cloth | Tailoring |
| Cooking | Cooking |
| Herb | Alchemy |
| HerbSeed (Forever) | Alchemy |
| Ore | Mining → Blacksmithing → Engineering (the miner smelts it) |
| Metal (bars, stone) | Blacksmithing → Engineering |
| Enchanting | Enchanting |
| EngineeringParts | Engineering |
| Gem | Blacksmithing → Engineering → Leatherworking → Tailoring → Enchanting |
| ArcaneCrystal | Alchemy → Enchanting |
| (unclassified) | → bank alt → master looter |

Gathering professions never receive what they gather, except ore for smelting.

`PickRecipient(category, roster, eligible, fullThisCorpse, bankAlt, masterLooter) → name | nil`.
Pure function.

## Roster (`Roster.lua`)

- Addon message prefix `MBLOOT`, channel `PARTY` (or `RAID` when in a raid).
- Each character broadcasts `{professions = {name = skill, …}, freeSlots = n}`:
  on login, on `GROUP_ROSTER_UPDATE`, on `SKILL_LINES_CHANGED`, and on `BAG_UPDATE`
  (throttled to at most once every 2 seconds).
- Professions read via `GetNumSkillLines` / `GetSkillLineInfo`.
- Free slots summed via `C_Container.GetContainerNumFreeSlots` over bags 0–4
  (ignoring profession-specific bags).
- Leader keeps `roster[name]` in memory only; entries for players who leave the group are dropped.

## Distributor (`Distributor.lua`)

Thin layer between WoW API and the pure functions:

- Gate: `GetLootMethod()` is `"master"` and the player is the master looter.
- Builds the eligible-candidates map per slot, calls `Classify` and `PickRecipient`, calls
  `GiveMasterLoot`.
- Skips locked slots and slots with no master loot candidates (gathering, fishing, opened
  containers), silently.
- Failure detection: if the slot isn't cleared within ~2.5 seconds after a give, mark that
  recipient full for this corpse and retry the slot with the next fallback.
- If even the master looter is full, leave the item and print one warning per corpse.
- Debug mode: prints raw slot info and the decision, does **not** give.

## Core (`Core.lua`) and Slash Commands

| Command | Effect |
|---|---|
| `/mbl on` / `/mbl off` | Enable/disable distribution |
| `/mbl bank <name>` | Set bank alt (`/mbl bank` with no name clears it) |
| `/mbl status` | Print roster: professions, skills, free slots, last seen; flags missing members |
| `/mbl debug` | Toggle dry-run debug mode |
| `/mbl quiet` | Toggle per-give chat lines |

SavedVariables `MultiboxLootDB` (account-wide): `enabled`, `bankAlt`, `debug`, `quiet`.

## Error Handling

| Situation | Behaviour |
|---|---|
| Not master looter / not master loot | Do nothing |
| Recipient not eligible for corpse | Next in chain → bank alt → master looter |
| Recipient reports 0 free slots | Treated as ineligible |
| Give fails (slot not cleared within timeout) | Mark full for this corpse, retry with next fallback |
| Nobody with the profession has reported | Fallback chain; `/mbl status` shows who's missing |
| Master looter also full | Leave on corpse, one chat warning |
| Disabled | No distribution |

## Testing

- **Offline:** `tests/run.lua` with plain `lua` covering `Classify` and `PickRecipient`:
  ties by skill, ineligible recipients, full bags, chain order, bank-alt fallback, master-looter
  fallback, unclassified items, quest-item skip.
- **In game:** `/mbl debug` dry run on the first corpses (including a quest mob, to confirm
  `isQuestItem`/`questID` on Forever), then live.

## Files

```
MultiboxLoot/
  MultiboxLoot.toc
  Core.lua
  Items.lua
  Rules.lua
  Roster.lua
  Distributor.lua
tests/
  run.lua
docs/superpowers/specs/2026-11-17-multibox-loot-design.md
```

## Open Items to Verify In-Game

- Forever's `## Interface:` is 16001 (confirmed from ForeverCore.toc).
- Forever has no Jewelcrafting (confirmed). New Forever materials found so far are in the tables; add any others seen in debug output.
