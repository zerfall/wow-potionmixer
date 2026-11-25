# Development

## Repository layout

| Path | What it is |
|---|---|
| `PotionMixer/` | The addon itself, the folder that goes into `Interface/AddOns` |
| `PotionMixer/PotionMixer.toc` | Addon metadata, the load order and the CurseForge and Wago project IDs |
| `PotionMixer/Locales.lua` | The addon's own texts in English, German, French, Spanish and Latin American Spanish |
| `PotionMixer/Data.lua` | Known potions, food and drink, excluded items and the empty-button placeholders |
| `PotionMixer/Potions.lua` | Bag scan, tooltip parsing and ranking |
| `PotionMixer/Buttons.lua` | The secure buttons, their art, tooltips and moving |
| `PotionMixer/Core.lua` | Events, saved variables, the combat queue and the slash commands |
| `PotionMixer/Bindings.xml` | The four key bindings |
| `PotionMixer/Media/Logo.tga` | The icon in the game's AddOns list |
| `tests/harness.lua` | The test harness |
| `logos/` | The logo and its generator |
| `docs/` | These pages |
| `.github/workflows/release.yml`, `.pkgmeta` | The release pipeline, see [Releasing](releasing.md) |

## Running the addon from the repository

Copy (or symlink) the `PotionMixer` folder into the `Interface/AddOns` folder of your WoW Forever installation, next to your other Forever addons. Don't copy `tests`, `logos` or `docs`.

A copy taken straight from the repository shows `@project-version@` as its version in the game. The packager replaces that placeholder with the tag when it builds a release.

When a change adds new files to the addon folder, restart the game instead of using `/reload`: WoW only picks up new files at startup. Turn on Lua errors with `/console scriptErrors 1`.

## Test harness

`tests/harness.lua` runs the real addon files against a mock of the WoW API and checks the behaviour described in [How it works](how-it-works.md). That covers secure attribute lookup, combat lockdown, bags, tooltips in all four languages, item and spell loading, positions, translations and slash commands. It needs Lua 5.1 or LuaJIT, no game client:

```sh
lua5.1 tests/harness.lua      # or: luajit tests/harness.lua
```

It prints any failed check and ends with `N passed, 0 failed`. Also worth running after a change:

```sh
for f in PotionMixer/*.lua; do luac5.1 -p "$f"; done   # syntax
xmllint --noout PotionMixer/Bindings.xml                # well-formed XML
```

GitHub Actions runs all of these on every push and pull request.

Some things can only be checked in the game: see the [in-game test checklist](in-game-tests.md).

## Logo

The logo is pixel art on a 32 × 32 grid. `python3 logos/make_logos.py` (needs Pillow) draws it and writes `logos/potion-mixer-logo-32/512/1024.png` for the addon websites. It also writes `PotionMixer/Media/Logo.tga`, the icon in the game's AddOns list. When Aseprite is installed (looked up in `$ASEPRITE`, on the PATH and in the Steam library), it also writes `logos/potion-mixer-logo.aseprite`, with the layers *Frame* and *Art* and the palette `logos/potion-mixer.gpl` loaded.
