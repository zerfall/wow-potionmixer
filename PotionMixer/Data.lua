-- Potion Mixer: seed data.
--
-- Checked against Wowhead's Classic and WoW Forever tooltips on 2026-11-22;
-- where they differ, the Forever value is used (only 4596 differs). Amounts
-- parsed from the client's own tooltip always win, these are only the
-- fallback. Add items Forever introduces here.

local _, ns = ...

-- kind:  "health", "mana" or "both" (both = restores health AND mana)
-- min/max: amount restored
-- level: required level (used only until the client has the item data cached)
ns.KNOWN_POTIONS = {
    -- Healing potions
    [118]   = { name = "Minor Healing Potion",      kind = "health", min = 70,   max = 90,   level = 0 },
    [858]   = { name = "Lesser Healing Potion",     kind = "health", min = 140,  max = 180,  level = 3 },
    -- Forever: renamed "Minor Discolored Healing Potion", 150-170 instantly,
    -- then 75% of that as damage over time (Classic: 140-180, no drawback).
    [4596]  = { name = "Minor Discolored Healing Potion", kind = "health", min = 150, max = 170, level = 5 },
    [929]   = { name = "Healing Potion",            kind = "health", min = 280,  max = 360,  level = 12 },
    [1710]  = { name = "Greater Healing Potion",    kind = "health", min = 455,  max = 585,  level = 21 },
    [3928]  = { name = "Superior Healing Potion",   kind = "health", min = 700,  max = 900,  level = 35 },
    [13446] = { name = "Major Healing Potion",      kind = "health", min = 1050, max = 1750, level = 45 },

    -- Mana potions
    [2455]  = { name = "Minor Mana Potion",         kind = "mana",   min = 140,  max = 180,  level = 5 },
    [3385]  = { name = "Lesser Mana Potion",        kind = "mana",   min = 280,  max = 360,  level = 14 },
    [3827]  = { name = "Mana Potion",               kind = "mana",   min = 455,  max = 585,  level = 22 },
    [6149]  = { name = "Greater Mana Potion",       kind = "mana",   min = 700,  max = 900,  level = 31 },
    [13443] = { name = "Superior Mana Potion",      kind = "mana",   min = 900,  max = 1500, level = 41 },
    [13444] = { name = "Major Mana Potion",         kind = "mana",   min = 1350, max = 2250, level = 49 },

    -- Rejuvenation potions (health and mana)
    [2456]  = { name = "Minor Rejuvenation Potion", kind = "both",   min = 90,   max = 150,  level = 5 },
    [18253] = { name = "Major Rejuvenation Potion", kind = "both",   min = 1440, max = 1760, level = 50 },
}

-- Food and drink: restored over time while seated. Forever values, checked
-- against Wowhead's WoW Forever tooltips on 2026-11-25. Food that gives a
-- Well Fed buff isn't listed: it is found through its tooltip (enUS, deDE,
-- frFR, esES/esMX).
-- kind: "health" (food), "mana" (drink) or "both"; amount: total restored;
-- conjured: made by mages (preferred over bought food of the same amount)
ns.KNOWN_FOOD = {
    -- Food
    [4540]  = { name = "Tough Hunk of Bread",        kind = "health", amount = 59,   level = 0 },
    [4541]  = { name = "Freshly Baked Bread",        kind = "health", amount = 234,  level = 5 },
    [4542]  = { name = "Moist Cornbread",            kind = "health", amount = 531,  level = 15 },
    [4544]  = { name = "Mulgore Spice Bread",        kind = "health", amount = 841,  level = 25 },
    [4601]  = { name = "Soft Banana Bread",          kind = "health", amount = 1338, level = 35 },
    [8950]  = { name = "Homemade Cherry Pie",        kind = "health", amount = 2065, level = 45 },
    [5349]  = { name = "Conjured Muffin",            kind = "health", amount = 59,   level = 0,  conjured = true },
    [1113]  = { name = "Conjured Bread",             kind = "health", amount = 234,  level = 5,  conjured = true },
    [1114]  = { name = "Conjured Rye",               kind = "health", amount = 531,  level = 15, conjured = true },
    [1487]  = { name = "Conjured Pumpernickel",      kind = "health", amount = 841,  level = 25, conjured = true },
    [8075]  = { name = "Conjured Sourdough",         kind = "health", amount = 1338, level = 35, conjured = true },
    [8076]  = { name = "Conjured Sweet Roll",        kind = "health", amount = 2065, level = 45, conjured = true },
    [22895] = { name = "Conjured Cinnamon Roll",     kind = "health", amount = 3058, level = 55, conjured = true },

    -- Drink
    [159]   = { name = "Refreshing Spring Water",    kind = "mana",   amount = 151,  level = 0 },
    [1179]  = { name = "Ice Cold Milk",              kind = "mana",   amount = 437,  level = 5 },
    [1205]  = { name = "Melon Juice",                kind = "mana",   amount = 835,  level = 15 },
    [1708]  = { name = "Sweet Nectar",               kind = "mana",   amount = 1345, level = 25 },
    [1645]  = { name = "Moonberry Juice",            kind = "mana",   amount = 1915, level = 35 },
    [8766]  = { name = "Morning Glory Dew",          kind = "mana",   amount = 2821, level = 45 },
    [5350]  = { name = "Conjured Water",             kind = "mana",   amount = 151,  level = 0,  conjured = true },
    [2288]  = { name = "Conjured Fresh Water",       kind = "mana",   amount = 437,  level = 5,  conjured = true },
    [2136]  = { name = "Conjured Purified Water",    kind = "mana",   amount = 835,  level = 15, conjured = true },
    [3772]  = { name = "Conjured Spring Water",      kind = "mana",   amount = 1345, level = 25, conjured = true },
    [8077]  = { name = "Conjured Mineral Water",     kind = "mana",   amount = 1915, level = 35, conjured = true },
    [8078]  = { name = "Conjured Sparkling Water",   kind = "mana",   amount = 2821, level = 45, conjured = true },
    [8079]  = { name = "Conjured Crystal Water",     kind = "mana",   amount = 4038, level = 55, conjured = true },

    -- Food and drink in one (Enriched Manna Biscuit: 2065 health, 4240 mana)
    [13724] = { name = "Enriched Manna Biscuit",     kind = "both",   health = 2065, mana = 4240, level = 45 },
    [19301] = { name = "Alterac Manna Biscuit",      kind = "both",   amount = 4240, level = 51 },
}

-- Items that restore health or mana but are not potions and don't share the
-- potion cooldown. They are never offered on any button, whatever their
-- tooltip says.
ns.EXCLUDED_ITEMS = {
    -- Healthstones (Minor, Lesser, Healthstone, Greater, Major; each with its
    -- two Improved Healthstone variants)
    [5512] = true, [19004] = true, [19005] = true,
    [5511] = true, [19006] = true, [19007] = true,
    [5509] = true, [19008] = true, [19009] = true,
    [5510] = true, [19010] = true, [19011] = true,
    [9421] = true, [19012] = true, [19013] = true,

    -- Mana gems: Agate, Jade, Citrine, Ruby
    [5514] = true, [5513] = true, [8007] = true, [8008] = true,

    -- Runes: Demonic Rune, Dark Rune
    [12662] = true, [20520] = true,

    -- Herbs: Whipper Root Tuber, Night Dragon's Breath
    [11951] = true, [11952] = true,
}

-- Icon shown (desaturated) on a button that has nothing of its kind.
ns.PLACEHOLDER_ITEMS = {
    health = 118,  -- Minor Healing Potion
    mana   = 2455, -- Minor Mana Potion
    food   = 4540, -- Tough Hunk of Bread
    drink  = 159,  -- Refreshing Spring Water
}
