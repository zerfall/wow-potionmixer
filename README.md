# Potion Mixer

<p align="center"><img src="logos/potion-mixer-logo-512.png" width="128" height="128" alt="Potion Mixer logo: a pixel-art flask, half red, half blue"></p>

Potion Mixer is a WoW Forever addon that gives you four buttons in two pairs: **healing and mana potions**, and **food and drink**. Each button always uses the best item of its kind in your bags, so you never have to look for the right potion in the middle of a fight or keep your action bars up to date.

## Features

- **Always the best item.** Each button picks the best healing potion, mana potion, food or drink you carry. When you loot or buy something better, the button switches to it right away. When a stack runs out, it moves on to the next best.
- **Fits your action bars.** The buttons look like WoW Forever's own action buttons. They show the item's icon, how many you carry, your key binding and the potion cooldown.
- **Shows what you carry.** The tooltip lists every potion, food or drink of that kind in your bags, best first, with how much each restores. The one the button will use is marked with a green `>`. Items you can't use yet, for example because your level is too low, are greyed out at the bottom.
- **Saves your buff food.** The food button eats plain food first and keeps food that makes you *Well Fed* until it's all you have left.
- **Mage food first.** Conjured food and water are used before bought food of the same strength.
- **Rejuvenation potions and manna biscuits** restore both health and mana, so they show up on both buttons of their pair.
- **Works in combat.** If your best potion runs out mid-fight, the next press uses your next-best potion.
- **Always visible.** With nothing of its kind in your bags, a button shows a greyed-out icon and stays where it is, so you always know where to click.
- **In your language:** English, German, French and Spanish, including Latin American Spanish.

## Install

Download Potion Mixer from **CurseForge**, [**Wago**](https://addons.wago.io/addons/kNMPl3Gz) or [**GitHub**](https://github.com/zerfall/wow-potionmixer/releases), or install it with an addon manager that supports WoW Forever.

To install the download by hand:

1. Open the `Interface/AddOns` folder of your WoW Forever installation, the one that holds your other Forever addons.
2. Unzip the download there. You should end up with an `Interface/AddOns/PotionMixer` folder. When updating, replace the whole folder.
3. Restart the game. On the character screen, open the **AddOns** list and check that **Potion Mixer** (with its flask icon) is enabled.

If the AddOns list marks Potion Mixer as *out of date*, tick **Load out of date AddOns**.

## How to use it

| What | How |
|---|---|
| Use the best item | Left-click the button, or press its key |
| Bind keys | Options → Keybindings → **AddOns** → **Potion Mixer**: *Use best healing potion*, *Use best mana potion*, *Use best food*, *Use best drink*. There are no keys bound by default. |
| Move the buttons | Hold **Shift** and drag either button of a pair. The two buttons of a pair move together. The potion pair and the food pair move separately. Moving doesn't work in combat. |
| Put the buttons back | `/pmix reset` puts both pairs back where they started (below your character). |
| See what's in your bags | `/pmix list` shows every potion, food and drink the addon found, best first |
| Help | `/pmix` |

The healing button is on the left and the mana button on the right; food is on the left and drink on the right. The positions are saved for all your characters.

## Good to know

- **"Item is not ready yet" after drinking a potion.** That's expected and harmless. So that the potion buttons can fall back to your next-best potion in combat, each press tries all your potions in order, best first. Only one is ever used, but the others report that the potion cooldown is running.
- **Both potion buttons show the same cooldown.** Healing and mana potions share one cooldown, so using one starts the timer on both.
- **New loot during a fight is used after combat.** The game doesn't let addons change what a button does in combat. The icon and count stay correct, and the button catches up as soon as the fight ends.
- **No eating or drinking in combat.** That's the game's rule. The food and drink buttons keep showing what you'll use once the fight is over.
- **Shift + your key binding does nothing**, because Shift is used for moving the buttons. Ctrl or Alt with the key still works.
- **Minor Discolored Healing Potion** is ranked by the health it restores. The damage it deals afterwards isn't counted.
- **Other client languages.** On a client that isn't English, German, French or Spanish, the addon recognizes only the common potions, bread, water and mage food it has built in, and its texts are in English.
- **Edit Mode.** The buttons aren't part of Edit Mode; move them with Shift-drag. If you turn on Edit Mode's *Hide Bar Art*, your action bars change their frame and these buttons keep the standard one.

## Found a problem?

If an item isn't picked up, or shows the wrong amount:

1. Type `/pmix tooltip` followed by a space, then Shift-click the item in your bags to insert its link, and press Enter.
2. [Open an issue on GitHub](https://github.com/zerfall/wow-potionmixer/issues) with what you expected, your client language, and the lines that `/pmix tooltip` printed.

## License

Potion Mixer is free software under the [GNU Affero General Public License v3](LICENSE), or any later version. Copyright (C) 2026 zerfall.

For developers: how the addon works, the tests, the in-game test checklist and the release process are in [docs](docs/README.md).
