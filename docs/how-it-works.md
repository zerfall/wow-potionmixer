# How it works

Potion Mixer targets WoW Forever (client 1.60.1). It adds two pairs of secure action buttons: healing and mana potions, and food and drink. Each button shows its top-ranked item's icon, count, key binding and, for potions, the potion cooldown as a swipe plus a countdown (`1:45`, then `42`, then `2.5`). The ranking is redone whenever the bags change.

## How potions are found and ranked

An item counts as a healing or mana potion if:

- its item ID is in the `KNOWN_POTIONS` table in `PotionMixer/Data.lua`, **or**
- it is a consumable, isn't in `EXCLUDED_ITEMS`, and its "Use:" line restores health and/or mana **instantly**. "Over N sec" wording (food, drink, bandages) never counts as a potion, and "at the cost of … life" runes are rejected.

The amounts come from the client's own tooltip, parsed for English, German, French and Spanish, for example `Restores 1050 to 1750 health.`, `Stellt 1050 bis 1750 Punkt(e) Gesundheit wieder her.`, `Rend 1050 à 1750 points de vie.` or `Restaura 1050 al 1750 p. de salud.`.

An item's "Use:" text comes from its spell, which the client loads only when it's first needed. Until it has arrived, which is typical right after logging in or after switching the client language, the addon asks the client for it and uses the values from `Data.lua` in the meantime. The tooltip's amounts take over a moment later. If the tooltip still can't be read, the `Data.lua` values stay. `/pmix list` shows where each item's amounts came from: `[tooltip]` (parsed from the client) or `[data]` (from `Data.lua`). On a German, French or Spanish client these tags appear in that language.

The score is the average of the minimum and maximum. Ties go to the higher maximum, then the higher item level, then the higher item ID.

Rejuvenation potions restore health and mana, so they appear on both potion buttons, and each button ranks them by the amount it cares about.

Healthstones, mana gems, Demonic/Dark Runes and the Whipper Root / Night Dragon's Breath herbs are excluded on purpose: they don't share the potion cooldown. If Forever adds new potions or similar items, add them to the tables at the top of `Data.lua`.

**Minor Discolored Healing Potion** (Forever) ranks by its instant 150–170 health. The damage over time it deals afterwards (75% of the amount) isn't counted. It ties with Lesser Healing Potion on score, and Lesser wins on its higher maximum.

## How food and drink are found and ranked

An item counts as food (health) or drink (mana) if:

- its item ID is in the `KNOWN_FOOD` table in `Data.lua` (vendor bread and water, mage food and water, manna biscuits), **or**
- it is a consumable, isn't in `EXCLUDED_ITEMS`, and its "Use:" line restores health and/or mana **over time while seated**: `Restores 2065 health over 30 sec. Must remain seated while eating.` / `Stellt im Verlauf von 30 Sek. … wieder her. Ihr müsst beim Essen sitzen bleiben.` Bandages and other heal-over-time effects don't say "seated", so they're never offered.

The amount restored decides, with three refinements:

1. **Buff food comes last.** Food that makes you *Well Fed* (on Forever also +5% experience from kills) is kept for when you want the buff: the button eats plain food first and uses buff food only when that's all you carry. To rank buff food like any other food, set `local SAVE_BUFF_FOOD = true` to `false` at the top of `PotionMixer/Potions.lua`.
2. **Conjured first on ties.** Mage food and water restore exactly as much as the bought food of their tier, so the button uses the free conjured items first.
3. Then the higher item level, then the higher item ID.

Manna biscuits restore health and mana, so they appear on both the food and the drink button.

Each food or drink button always uses just its top item, not a macro. Food and drink have no cooldown, so a macro with several `/use` lines could eat more than one item per click. Since you can't eat or drink in combat, the macro's fall-through (see below) wouldn't help anyway, and out of combat the button follows your bags at once.

## The macro trade-off for potions ("Item is not ready yet")

Secure buttons can't be changed in combat. A plain "use item X" button would therefore stop working the moment its stack ran out mid-fight. Instead, each potion button runs a hidden macro with one `/use item:<id>` line per potion you own, best first. The macro is rebuilt out of combat whenever the ranking changes. In combat, the first line that works is the one that runs, so the button falls through to your next-best potion.

The cost: after a potion is used, the remaining lines try too and can show **"Item is not ready yet"** in red, with the error sound. Only one potion is ever used per press.

To avoid those errors, open `PotionMixer/Buttons.lua` and change

```lua
local ACTION_MODE = "macro"
```

to

```lua
local ACTION_MODE = "item"
```

The potion buttons then use only the top potion. When that stack runs out in combat, they switch to the next potion only after combat ends.

## Combat, moving and key bindings

- **Mid-fight changes wait for combat to end.** The icon and count always show the truth, but what a click does is fixed when combat starts. Attribute changes requested in combat are queued and applied on `PLAYER_REGEN_ENABLED`. A potion looted during a fight is shown at once and is only used after combat. With the macro, a potion that runs out is skipped automatically.
- **Moving.** Shift + left-drag moves a pair. While a drag runs, the pair's click actions are suspended, and they're restored on the next frame after the drag ends. A drag in progress when combat starts is finished at once. Plain drags do nothing.
- **Shift actions.** The buttons' Shift click actions (`shift-type1` and the other Shift combinations) are set to Blizzard's `ATTRIBUTE_NOOP` (`""`), so a Shift-click never uses an item. This is also why Shift + a bound key uses nothing. Ctrl or Alt + the key still works.
- **Clicks.** The buttons register `"AnyUp"` and `"AnyDown"`, so they follow the client's `ActionButtonUseKeyDown` setting like the action bars do (`CLICKS` in `Buttons.lua`).
- **Saved positions.** Each pair's position is saved account-wide in `PotionMixerDB.layout`. An older single `position` entry from early development builds is migrated to the potion pair.

## Looks

The buttons are 45×45 and use WoW Forever's main action bar atlases: `UI-HUD-ActionBar-IconFrame`, its `-Down`, `-Mouseover` and `-Mask` variants, `ui-hud-actionbar-iconframe-slot`, and `-Border`, tinted gold, as the cue that a pair can be moved while Shift is held. The countdown font is copied from the cooldown frame's own countdown font string.

- If Edit Mode's *Hide Bar Art* is on, Forever switches its own bars to a slightly larger frame, and these buttons don't follow.
- The buttons aren't integrated with Edit Mode.
- An empty potion button shows the cooldown of its placeholder item (Minor Healing Potion, Minor Mana Potion). Some clients report no cooldown for items you don't own, and then the empty button shows none. The food and drink placeholders are Tough Hunk of Bread and Refreshing Spring Water.

## Languages

- **Tooltip parsing** covers English (enUS/enGB), German (deDE), French (frFR) and Spanish (esES, esMX). The French and Spanish wording was checked against WoW Forever's frFR, esES and esMX tooltips. Latin American Spanish words its tooltips almost exactly like European Spanish.
- **Other clients** (for example Russian or Portuguese) find only the items listed in `Data.lua`, with their amounts from `Data.lua`. Buff food isn't listed there, so it isn't found.
- **The addon's own texts** (`PotionMixer/Locales.lua`) are translated into German, French, Spanish and, separately, Latin American Spanish for esMX clients, which uses the game's Latin American terms, for example "poción de sanación". Missing keys fall back to English, and other languages see English. The `/pmix tooltip` diagnostic output is always in English.

## `/pmix tooltip`

`/pmix tooltip` followed by an item link or item ID prints the item's tooltip lines as the client delivers them, with escape codes visible (`|` shown as `||`), and what the addon reads from each line, for example `-> instant, health …` on a potion's "Use:" line. It's the first thing to ask for when an item isn't detected or shows the wrong amount.

## Interface number

The `.toc` declares `## Interface: 16001`, taken from Auctionator's `.toc`. If the AddOns list marks Potion Mixer as *out of date*, run `/dump select(4, GetBuildInfo())` in game and put that number in `PotionMixer.toc`. The release pipeline reads the same number to file releases under WoW Forever.
