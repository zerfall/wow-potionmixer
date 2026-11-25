# In-game test checklist

Run these on WoW Forever after a change and note anything that doesn't match the expected result. Start with `/console scriptErrors 1` so Lua errors are shown.

| # | Do this | Expected |
|---|---|---|
| 1 | `/console scriptErrors 1`, then `/reload` with no potions, food or drink in your bags | All four buttons show greyed placeholders (Minor Healing Potion, Minor Mana Potion, Tough Hunk of Bread, Refreshing Spring Water). No counts. No Lua errors. |
| 2 | Carry Minor and Lesser Healing Potions | The healing button shows Lesser with the right count. The tooltip lists Lesser (marked `>`) above Minor. |
| 3 | Loot or buy a better potion | The button switches to it without a `/reload` |
| 4 | Use the potion by click and by hotkey | Exactly one potion is used per press. The swipe and countdown appear on **both** potion buttons, not on food or drink. |
| 5 | Shift-drag the healing button, then the mana button; plain-drag a button; `/reload`; log out and back in | Each Shift-drag moves both potion buttons together, keeps their spacing, leaves the food pair where it is and uses nothing. A plain drag doesn't move them. The position survives the reload and the relog. |
| 6 | In combat: Shift-drag a button. Then use up the top potion stack, wait for the cooldown, press again. Leave combat. | Shift-drag does nothing, and there are no "Interface action blocked" messages. After the cooldown, the next press uses the next-best potion. After combat, the icons and `/pmix list` match your bags. |
| 7 | Bind, then unbind, a key for each of the four buttons in Keybindings → AddOns → Potion Mixer | The hotkey text on the button appears and disappears at once |
| 8 | `/pmix reset` out of combat, then in combat | Out of combat: both pairs return to their default positions. In combat: refused with a message. |
| 9 | On a low-level character, carry a potion and a drink above your level (for example a Major Healing Potion and Morning Glory Dew) | Neither is chosen. Each appears greyed at the bottom of its tooltip with "Requires Level …". |
| 10 | On a German, French or Spanish client (deDE, frFR, esES, esMX), if available: carry a potion, conjured food, buff food and a drink, then `/pmix list` | Potions, food and drink show `[tooltip]`, meaning their amounts were parsed from that language's tooltip. The conjured food and the buff food are tagged in your language (German: `herbeigezaubert`, `Satt`). The tooltips, chat messages and key binding names are in that language too. |
| 11 | Carry bread and water; click the food button, then the drink button | One item each is used and you sit and eat/drink. The counts go down by one. |
| 12 | Carry conjured food and bought food of the same tier (for example Conjured Sweet Roll and Homemade Cherry Pie) | The conjured food is on top and is eaten first. The tooltip tags it `conjured`. |
| 13 | Carry buff food (for example Smoked Desert Dumplings) and plain food | Plain food is used first. The buff food is listed after it, tagged `Well Fed`, and is only used once the plain food is gone. |
| 14 | Carry an Enriched or Alterac Manna Biscuit | It appears on both the food and the drink button |
| 15 | In combat: click the food button; loot food. Leave combat. | Nothing is eaten (the game refuses), no "Interface action blocked", and the food button keeps showing your best food, not a greyed placeholder. After combat, a click eats it. |
| 16 | Shift-drag the food or drink button; `/reload` | Only the food and drink pair moves, and its position survives the reload |
| 17 | Switch the client language (or clear the game's cache), log in, and run `/pmix list` twice: once right away, then again a few seconds later | The first list may show `[data]`. The second shows `[tooltip]` for every item whose text is parsed (potions, food and drink in English, German, French and Spanish). Buff food that isn't in `Data.lua` appears by the second list at the latest. |
| 18 | `/pmix tooltip` with a Shift-clicked potion link | The item's tooltip lines, the "Use:" line marked `-> instant, health …` |

These checks cover points that couldn't be verified without the game:

| # | Do this | Expected |
|---|---|---|
| 19 | Shift-click, and Shift+Alt-click, a button that has an item | Nothing is used. The buttons' Shift actions are set to Blizzard's `ATTRIBUTE_NOOP` (`""`). |
| 20 | Start a Shift-drag, let go of Shift first, then of the mouse button | The pair moves and nothing is used |
| 21 | `/console ActionButtonUseKeyDown 1`, press a potion hotkey; then `/console ActionButtonUseKeyDown 0`, press it again | One potion per press either way: on key down with `1`, on key release with `0`. A double fire can't use two potions, because of the shared cooldown. It would show up as an extra "Item is not ready yet", which is easiest to see with `ACTION_MODE = "item"`. If that happens, register `"AnyUp"` only (`CLICKS` in `Buttons.lua`). For food, a double fire would eat two items: check that one press eats exactly one. |
| 22 | Hover a button, then press and release Shift | Both buttons of that pair get a gold border while Shift is held (the other pair doesn't), and the ranked list stays in the tooltip |
| 23 | Note any red error text after a successful potion use | "Item is not ready yet" is the known macro trade-off (see [How it works](how-it-works.md#the-macro-trade-off-for-potions-item-is-not-ready-yet)). Anything else is unexpected. |
| 24 | Put the buttons next to your action bar and compare them | Same frame, rounded icon corners, mouseover glow, pressed look, cooldown swipe and hotkey/count text. A plain or empty square instead of the frame means an atlas name didn't resolve on this client. |
