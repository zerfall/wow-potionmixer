**Potion Mixer** adds four buttons in two pairs, one for healing and mana potions and one for food and drink. Each button always uses the best item of its kind in your bags, so you never have to search your bags mid-fight or drag a new potion onto your action bar after a few levels.

## What it does

- **Healing potion and mana potion buttons** use the potion that restores the most.
- **Food and drink buttons** use the food or drink that restores the most.
- **Keeps up with your bags.** Loot or buy something better and the button switches to it right away. When a stack runs out, it moves on to the next best.
- **Works in combat.** If your best potion runs out mid-fight, the next press uses your next-best potion.
- **Saves your buff food.** Food that makes you *Well Fed* is only eaten once you have no plain food left.
- **Mage food first.** Conjured food and water are used before bought food of the same strength.
- **Rejuvenation potions and manna biscuits** restore both health and mana, so they show up on both buttons of their pair.
- **Shows what you carry.** The tooltip lists every item of that kind in your bags, best first, with how much each one restores. Items you can't use yet, for example because your level is too low, are greyed out.
- **Fits your action bars.** The buttons look like WoW Forever's own action buttons, with the item's icon, how many you carry, your key binding and the potion cooldown.
- **Always visible.** With nothing of its kind in your bags, a button shows a greyed-out icon and stays where it is.
- **Speaks your language:** English, German, French and Spanish, including Latin American Spanish.

## How to use it

- **Use an item:** click the button, or press its key.
- **Bind keys:** Options → Keybindings → AddOns → Potion Mixer. No keys are bound by default.
- **Move the buttons:** hold **Shift** and drag a button. The two buttons of a pair move together, and the potion pair and the food pair move separately.
- `/pmix reset` puts both pairs back where they started.
- `/pmix list` shows every potion, food and drink the addon found, best first.
- `/pmix` shows all commands.

## Good to know

- **"Item is not ready yet" after drinking a potion is expected.** So the button can fall back to your next-best potion in combat, each press tries your potions in order. Only one is ever used; the others just report the potion cooldown.
- **Healing and mana potions share one cooldown**, so both potion buttons show the same timer.
- **New loot during a fight is used after combat.** The game doesn't let addons change what a button does in combat. The icon and count stay correct, and the button catches up when the fight ends.
- **No eating or drinking in combat.** That's the game's rule.
- **Shift + your key binding does nothing**, because Shift is used to move the buttons.

## Bug reports, ideas and source code

Found a problem or have an idea? Please open an issue on GitHub: [github.com/zerfall/wow-potionmixer/issues](https://github.com/zerfall/wow-potionmixer/issues). If an item isn't picked up or shows the wrong amount, include a screenshot of `/pmix tooltip` followed by the item's link (Shift-click the item in your bags).

Potion Mixer is open source under the AGPL-3.0 license: [github.com/zerfall/wow-potionmixer](https://github.com/zerfall/wow-potionmixer)
