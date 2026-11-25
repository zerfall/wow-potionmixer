-- Potion Mixer: bag scan, tooltip parsing, ranking and the potency cache,
-- for potions (healing, mana) and for food and drink.

local _, ns = ...

local Potions = {}
ns.Potions = Potions

-- Eat plain food before food that gives a Well Fed buff (on Forever that buff
-- also adds 5% experience from kills), so buff food is kept for when you want
-- it. Set to false to rank all food purely by the amount it restores.
local SAVE_BUFF_FOOD = true

local format, max, floor = string.format, math.max, math.floor
local ipairs, pairs, tonumber, type, pcall = ipairs, pairs, tonumber, type, pcall
local sort = table.sort

---------------------------------------------------------------------------
-- API, resolved once: namespaced function first, legacy global second.
---------------------------------------------------------------------------

local C_Container, C_Item, C_Spell, C_TooltipInfo = C_Container, C_Item, C_Spell, C_TooltipInfo

local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetContainerItemInfo = (C_Container and C_Container.GetContainerItemInfo) or GetContainerItemInfo
local GetItemInfo          = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant   = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local IsUsableItem         = (C_Item and C_Item.IsUsableItem) or IsUsableItem
local RequestLoadItemData  = C_Item and C_Item.RequestLoadItemDataByID
local GetItemSpell         = (C_Item and C_Item.GetItemSpell) or GetItemSpell
local IsSpellDataCached    = C_Spell and C_Spell.IsSpellDataCached
local RequestLoadSpellData = C_Spell and C_Spell.RequestLoadSpellData
local GetItemTooltipData   = C_TooltipInfo and C_TooltipInfo.GetItemByID

-- C_Container.GetContainerItemInfo returns a table, the legacy global a list.
local containerInfoIsTable = C_Container ~= nil and C_Container.GetContainerItemInfo ~= nil

local CONSUMABLE_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
local REQUIRES_LEVEL = ITEM_MIN_LEVEL or "Requires Level %d"
local NOT_USABLE = ns.L.NOT_USABLE
local MAX_SCAN_LINES = 30
local MAX_TOOLTIP_RETRIES = 3
local MAX_SPELL_REQUESTS = 3

-- Names of the functions the addon can't work without, or an empty list.
function Potions.MissingAPIs()
    local missing = {}
    if not GetContainerNumSlots then missing[#missing + 1] = "GetContainerNumSlots" end
    if not GetContainerItemInfo then missing[#missing + 1] = "GetContainerItemInfo" end
    if not GetItemInfo then missing[#missing + 1] = "GetItemInfo" end
    return missing
end

---------------------------------------------------------------------------
-- Tooltip parsing (enUS, deDE, frFR, esES/esMX)
--
-- Examples of the wording handled, from WoW Forever's tooltips:
--   enUS  Use: Restores 90 to 150 mana and 90 to 150 health.
--         Use: Restores 2065 health over 30 sec. Must remain seated while eating.
--   deDE  Benutzen: Stellt 1050 bis 1750 Punkt(e) Gesundheit wieder her.
--         Benutzen: Stellt im Verlauf von 30 Sek. 2065 Punkt(e) Gesundheit wieder her. Ihr müsst beim Essen sitzen bleiben.
--   frFR  Utiliser : Rend 90 à 150 points de mana et 90 à 150 points de vie.
--         Utiliser : Rend 2065 points de vie en 30 sec. Vous devez rester assis pendant que vous mangez.
--   esES  Uso: Restaura 90 al 150 p. de maná y 90 al 150 de salud.
--         Uso: Restaura 2065 p. de salud durante 30 s. Debes permanecer sentado mientras comes.
---------------------------------------------------------------------------

-- Strip escape codes, turn no-break spaces into plain ones, drop the space
-- French puts before a colon ("Utiliser :"), trim and lower-case.
local function Simplify(raw)
    local text = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|n", " ")
    -- Grammar escape choosing a singular or plural form ("|4Punkt:Punkte;");
    -- keep the first form, so its "4" isn't read as an amount.
    text = text:gsub("|4([^:;]*)[^;]*;", "%1")
    text = text:gsub("\194\160", " "):gsub("\226\128\175", " "):gsub(" +:", ":") -- U+00A0, U+202F
    return (text:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Simplified, de-duplicated list of the client's own string and fallbacks.
local function StringList(strings)
    local list, seen = {}, {}
    for _, text in ipairs(strings) do
        text = Simplify(text)
        if text ~= "" and not seen[text] then
            seen[text] = true
            list[#list + 1] = text
        end
    end
    return list
end

-- "Use:" prefixes and "Conjured Item" lines: the client's own string first
-- (it also covers esMX), then enUS, deDE, frFR and esES.
local USE_PREFIXES = StringList({
    ITEM_SPELL_TRIGGER_ONUSE or "Use:", "Use:", "Benutzen:", "Utiliser :", "Utilise :", "Uso:",
})
local CONJURED_LINES = StringList({
    ITEM_CONJURED or "Conjured Item", "Conjured Item", "Herbeigezauberter Gegenstand",
    "Objet invoqu\195\169", "Objeto m\195\161gico", -- "Objet invoqué", "Objeto mágico"
})

-- Over-time wording: food, drink, bandages and regeneration effects.
local OVER_TIME_PATTERNS = {
    "over %d",             -- enUS: "Restores 59 health over 18 sec."
    "verlauf von %d",      -- deDE: "Stellt im Verlauf von 18 Sek. ... wieder her."
    "%d sek%.? lang",      -- deDE: "Heilt 6 Sek. lang 66 Punkt(e) Schaden."
    "\195\188ber %d",      -- deDE: "über 18 Sek."
    "en %d+ s",            -- frFR: "Rend 59 points de vie en 18 sec."
    "durante %d",          -- esES: "Restaura 59 p. de salud durante 18 s."
}
-- Food and drink say you must stay seated; other over-time effects don't.
local SEATED_WORDS = {
    "must remain seated",  -- enUS
    "sitzen bleiben",      -- deDE
    "assis",               -- frFR: "rester assis", "rester en position assise"
    "sentado",             -- esES: "Debes permanecer sentado"
}
-- Food that also gives a Well Fed buff.
local WELL_FED_WORDS = {
    "well fed",            -- enUS
    "werdet ihr satt",     -- deDE
    "bien nourri",         -- frFR
    "passez au moins",     -- frFR text that lacks "Bien nourri": "Si vous passez au moins 10 secondes à manger"
    "bien alimentado",     -- esES
}
-- Rune-like items that trade life for mana are never offered.
local LIFE_COST_WORDS = {
    "at the cost of",      -- enUS
    "verbraucht",          -- deDE
    "au prix de",          -- frFR
    "con un consumo de",   -- esES
    "con un costo de",     -- esMX
}

-- Capture the text listing what is restored. The line gets a trailing space,
-- so a sentence ends at ". " and decimals like "61.2" stay whole. %f[%a]
-- keeps "rend" from matching inside words like "prend".
local CLAUSE_PATTERNS = {
    "%f[%a]restores (.-)%.%s",      -- enUS
    "%f[%a]stellt (.-) wieder her", -- deDE
    "%f[%a]rend (.-)%.%s",          -- frFR
    "%f[%a]restaura (.-)%.%s",      -- esES
    "%f[%a]restores (.+)",          -- the same without a full stop
    "%f[%a]rend (.+)",
    "%f[%a]restaura (.+)",
}

local NUMBER = "(%d+[%.,]?%d*)"
-- After a number, these turn it into a range: "1050 to 1750", "1050 bis 1750",
-- "1050 à 1750", "1050 al 1750" (and "a", "-").
local RANGE_JOINERS = {}
for _, joiner in ipairs({ "^ to ", "^ bis ", "^ \195\160 ", "^ al ", "^ a ", "^%s*%-%s*" }) do
    RANGE_JOINERS[#RANGE_JOINERS + 1] = joiner .. NUMBER
end

local HEALTH_WORDS = { "health", "life", "gesundheit", "leben", "vie", "salud", "vida" }
local MANA_WORDS = { "mana", "man\195\161" } -- "maná" (esES, esMX)

local function ContainsAny(text, words)
    for _, word in ipairs(words) do
        if text:find(word, 1, true) then return true end
    end
    return false
end

local function MatchesAny(text, patterns)
    for _, pattern in ipairs(patterns) do
        if text:find(pattern) then return true end
    end
    return false
end

-- "61.2" or "61,2" (decimal comma) -> 61.2
local function ToNumber(text)
    return tonumber((text:gsub(",", ".")))
end

-- Simplify, then join thousands separators ("1,050", "1.050", "1 050") so
-- numbers are plain digit runs, and drop the dot of the Spanish "p."
-- (puntos) so that it doesn't end the sentence.
local function NormalizeLine(raw)
    local text = Simplify(raw)
    local previous
    repeat
        previous = text
        text = text:gsub("(%d)[,%. ](%d%d%d)%f[%D]", "%1%2")
    until text == previous
    return (text:gsub("(%d p)%.", "%1"))
end

local function HasUsePrefix(text)
    for _, prefix in ipairs(USE_PREFIXES) do
        if text:sub(1, #prefix) == prefix then return true end
    end
    return false
end

-- "90 to 150 mana and 90 to 150 health" -> { mana = {90,150}, health = {90,150} }
-- Each amount applies to the words that follow it, up to the next number.
local function ParseAmounts(clause)
    local result
    local pos = 1
    while true do
        local _, last, low = clause:find(NUMBER, pos)
        if not low then break end
        local high = low
        for _, joiner in ipairs(RANGE_JOINERS) do
            local _, joinEnd, value = clause:find(joiner, last + 1)
            if value then
                high, last = value, joinEnd
                break
            end
        end
        local nextNumber = clause:find("%d", last + 1)
        local words = clause:sub(last + 1, nextNumber and nextNumber - 1 or #clause)
        local amount = { min = ToNumber(low), max = ToNumber(high) }
        if amount.min > amount.max then amount.min, amount.max = amount.max, amount.min end

        local health, mana = ContainsAny(words, HEALTH_WORDS), ContainsAny(words, MANA_WORDS)
        if health or mana then
            result = result or {}
            if health and not result.health then result.health = amount end
            if mana and not result.mana then result.mana = amount end
        end
        pos = last + 1
    end
    return result
end

-- Parses one tooltip line. For a "Use:" line that restores health and/or
-- mana it returns
--   { health = {min=,max=}?, mana = {min=,max=}?, effect = ..., wellFed = bool }
-- where effect is "instant" (a potion) or "seated" (food or drink: over time,
-- while sitting). Anything else returns nil, including bandages, other
-- over-time effects and items that trade life for mana.
function Potions.ParseUseLine(raw)
    local text = NormalizeLine(raw)
    if not HasUsePrefix(text) or ContainsAny(text, LIFE_COST_WORDS) then return nil end
    local effect = "instant"
    if MatchesAny(text, OVER_TIME_PATTERNS) then
        if not ContainsAny(text, SEATED_WORDS) then return nil end
        effect = "seated"
    end
    local padded = text .. " "
    for _, pattern in ipairs(CLAUSE_PATTERNS) do
        local clause = padded:match(pattern)
        local amounts = clause and ParseAmounts(clause)
        if amounts then
            amounts.effect = effect
            amounts.wellFed = effect == "seated" and ContainsAny(text, WELL_FED_WORDS)
            return amounts
        end
    end
    return nil
end

local function IsConjuredLine(raw)
    local text = Simplify(raw)
    for _, conjured in ipairs(CONJURED_LINES) do
        if text == conjured then return true end
    end
    return false
end

local function FormatNumber(value)
    if value == floor(value) then return tostring(value) end
    return format("%.1f", value)
end

-- "1050-1750", or "2065" when the amount is fixed
function Potions.AmountText(entry)
    if entry.min == entry.max then return FormatNumber(entry.min) end
    return FormatNumber(entry.min) .. "-" .. FormatNumber(entry.max)
end

local function LinesFromTooltipData(itemID)
    local ok, data = pcall(GetItemTooltipData, itemID)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local lines = {}
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text == nil and type(line.args) == "table" then
            -- 10.0.x shape: values not yet surfaced onto the line itself
            for _, arg in ipairs(line.args) do
                if arg.field == "leftText" then text = arg.stringVal break end
            end
        end
        if type(text) == "string" and text ~= "" then lines[#lines + 1] = text end
    end
    return lines
end

-- Fallback for clients without C_TooltipInfo: an unnamed GameTooltip with
-- our own font strings, so it adds no globals.
local scanner, scannerLines

local function CreateScanner()
    local tip = CreateFrame("GameTooltip")
    local lefts = {}
    for i = 1, MAX_SCAN_LINES do
        local left = tip:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        local right = tip:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        tip:AddFontStrings(left, right)
        lefts[i] = left
    end
    return tip, lefts
end

local function LinesFromScanner(itemID)
    if scanner == nil then
        local ok, tip, lefts = pcall(CreateScanner)
        scanner, scannerLines = ok and tip or false, ok and lefts or nil
    end
    if not scanner then return nil end

    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:ClearLines()
    local ok = pcall(scanner.SetItemByID, scanner, itemID)
    local lines = {}
    if ok then
        for i = 1, math.min(scanner:NumLines() or 0, MAX_SCAN_LINES) do
            local text = scannerLines[i]:GetText()
            if text and text ~= "" then lines[#lines + 1] = text end
        end
    end
    scanner:Hide()
    return lines
end

local function GetTooltipLines(itemID)
    if GetItemTooltipData then
        local lines = LinesFromTooltipData(itemID)
        if lines and #lines > 0 then return lines end
    end
    return LinesFromScanner(itemID)
end

-- Returns a potency table (or nil) and whether the tooltip was complete
-- enough to trust.
local function ParseItemTooltip(itemID)
    local lines = GetTooltipLines(itemID)
    if not lines or #lines == 0 then return nil, false end
    local potency, conjured = nil, false
    for _, line in ipairs(lines) do
        if RETRIEVING_ITEM_INFO and line:find(RETRIEVING_ITEM_INFO, 1, true) then return nil, false end
        conjured = conjured or IsConjuredLine(line)
        potency = potency or Potions.ParseUseLine(line)
    end
    if potency then potency.conjured = conjured end
    return potency, true
end

---------------------------------------------------------------------------
-- Potency cache
---------------------------------------------------------------------------

local potencyCache = {}   -- itemID -> potency table, or false when it's none of ours
local pendingItems = {}   -- itemID -> true while its item data is still loading
local tooltipRetries = {} -- itemID -> number of incomplete tooltip reads
local usableOutOfCombat = {} -- itemID -> IsUsableItem result from the last scan out of combat
local pendingSpells = {}  -- spellID -> true while an item's spell (its "Use:" text) is loading
local spellRequests = {}  -- spellID -> number of load requests (a spell that never loads isn't waited for forever)
local retryWanted = false -- a scan saw an incomplete tooltip; scan again a bit later
local levelHint = 0       -- level from PLAYER_LEVEL_UP, which can run ahead of UnitLevel

function Potions.ClearCache()
    wipe(potencyCache)
    wipe(pendingItems)
    wipe(tooltipRetries)
    wipe(usableOutOfCombat)
    wipe(pendingSpells)
    wipe(spellRequests)
end

function Potions.IsPending(itemID)
    return pendingItems[itemID] == true
end

-- For SPELL_DATA_LOAD_RESULT: true if we were waiting for this spell.
function Potions.SpellLoaded(spellID)
    if not pendingSpells[spellID] then return false end
    pendingSpells[spellID] = nil
    return true
end

-- An item's "Use:" text comes from its spell, which the client loads on
-- demand: until then the tooltip has no Use line, and the item would look
-- like no potion or food at all. Returns false (and asks for the spell) while
-- it isn't loaded; SPELL_DATA_LOAD_RESULT then triggers a new scan.
local function IsSpellLoaded(itemID)
    if not (GetItemSpell and IsSpellDataCached and RequestLoadSpellData) then return true end
    local _, spellID = GetItemSpell(itemID)
    if not spellID or IsSpellDataCached(spellID) then return true end
    spellRequests[spellID] = (spellRequests[spellID] or 0) + 1
    if spellRequests[spellID] > MAX_SPELL_REQUESTS then return true end -- read whatever there is
    pendingSpells[spellID] = true
    RequestLoadSpellData(spellID)
    return false
end

function Potions.SetLevelHint(level)
    levelHint = tonumber(level) or 0
end

local function MarkPending(itemID)
    pendingItems[itemID] = true
    if RequestLoadItemData then RequestLoadItemData(itemID) end
end

-- Seed entry for an item and its effect: KNOWN_POTIONS are "instant",
-- KNOWN_FOOD is "seated".
local function LookUpKnown(itemID)
    local potion = ns.KNOWN_POTIONS[itemID]
    if potion then return potion, "instant" end
    local food = ns.KNOWN_FOOD and ns.KNOWN_FOOD[itemID]
    if food then return food, "seated" end
    return nil
end

local function PotencyFromData(known, effect)
    local potency = { source = "data", effect = effect, conjured = known.conjured == true, wellFed = false }
    for _, resource in ipairs({ "health", "mana" }) do
        if known.kind == resource or known.kind == "both" then
            -- per-resource amount (food and drink in one), else min/max or amount
            local low = tonumber(known[resource] or known.min or known.amount) or 0
            local high = tonumber(known[resource] or known.max) or low
            potency[resource] = { min = low, max = high }
        end
    end
    return potency
end

local function GetItemClassID(itemID)
    if GetItemInfoInstant then
        local classID = select(6, GetItemInfoInstant(itemID))
        if classID then return classID end
    end
    return (select(12, GetItemInfo(itemID)))
end

-- Potency of an item, or nil if it isn't a potion, food or drink (or we
-- can't tell yet; then the item is marked pending and nothing is cached).
local function ResolvePotency(itemID)
    local cached = potencyCache[itemID]
    if cached ~= nil then return cached or nil end

    if ns.EXCLUDED_ITEMS[itemID] then
        potencyCache[itemID] = false
        return nil
    end

    local known, knownEffect = LookUpKnown(itemID)
    if not known then
        local classID = GetItemClassID(itemID)
        if classID == nil then
            MarkPending(itemID)
            return nil
        elseif classID ~= CONSUMABLE_CLASS then
            potencyCache[itemID] = false
            return nil
        end
    end

    if not GetItemInfo(itemID) then
        MarkPending(itemID)
        return known and PotencyFromData(known, knownEffect) or nil
    end
    if not IsSpellLoaded(itemID) then
        return known and PotencyFromData(known, knownEffect) or nil -- not cached: parsed once the spell arrives
    end

    local parsed, complete = ParseItemTooltip(itemID)
    if not complete then
        tooltipRetries[itemID] = (tooltipRetries[itemID] or 0) + 1
        if tooltipRetries[itemID] <= MAX_TOOLTIP_RETRIES then
            retryWanted = true
            return known and PotencyFromData(known, knownEffect) or nil
        end
    end

    pendingItems[itemID] = nil
    if parsed then
        parsed.source = "tooltip"
        parsed.conjured = parsed.conjured or (known ~= nil and known.conjured == true)
        potencyCache[itemID] = parsed
    elseif known then
        potencyCache[itemID] = PotencyFromData(known, knownEffect)
    else
        potencyCache[itemID] = false
    end
    return potencyCache[itemID] or nil
end

---------------------------------------------------------------------------
-- Bag scan and ranking
---------------------------------------------------------------------------

local function LastBagIndex()
    return max(NUM_BAG_SLOTS or 4, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0)
end

local function ReadSlot(bag, slot)
    if containerInfoIsTable then
        local info = GetContainerItemInfo(bag, slot)
        if info then return info.itemID, info.stackCount end
        return nil
    end
    local _, count, _, _, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
    if not itemID and link then itemID = tonumber(link:match("item:(%d+)")) end
    return itemID, count
end

-- itemID -> total count across all bags
local function CountBagItems()
    local counts = {}
    for bag = 0, LastBagIndex() do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local itemID, count = ReadSlot(bag, slot)
            if itemID then counts[itemID] = (counts[itemID] or 0) + (count or 1) end
        end
    end
    return counts
end

local function PlayerLevel()
    return max(UnitLevel("player") or 1, levelHint)
end

-- Food and drink can't be used in combat, and IsUsableItem may say so then.
-- In combat, keep the answer from the last scan out of combat, so the buttons
-- keep showing what you'll eat once the fight is over.
local function IsItemUsable(itemID)
    if not IsUsableItem then return true end
    if InCombatLockdown() then
        local known = usableOutOfCombat[itemID]
        if known == nil then return true end
        return known
    end
    local usable, noMana = IsUsableItem(itemID)
    usable = (usable or noMana) and true or false
    usableOutOfCombat[itemID] = usable
    return usable
end

-- Returns usable, reason-if-not.
local function CheckUsable(itemID, minLevel, playerLevel)
    if minLevel > playerLevel then
        return false, format(REQUIRES_LEVEL, minLevel)
    end
    if not IsItemUsable(itemID) then return false, NOT_USABLE end
    return true
end

-- Usable first; then (with SAVE_BUFF_FOOD) food without a Well Fed buff;
-- then by score, max, conjured first, item level and itemID.
local function CompareEntries(a, b)
    if a.usable ~= b.usable then return a.usable end
    if SAVE_BUFF_FOOD and a.wellFed ~= b.wellFed then return b.wellFed end
    if a.score ~= b.score then return a.score > b.score end
    if a.max ~= b.max then return a.max > b.max end
    if a.conjured ~= b.conjured then return a.conjured end
    if a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
    return a.itemID > b.itemID
end

-- The button list each restored resource goes to, by effect.
local LISTS = {
    instant = { health = "health", mana = "mana" },  -- potions
    seated  = { health = "food",   mana = "drink" }, -- food and drink
}

local function BuildEntries(counts, playerLevel)
    local lists = { health = {}, mana = {}, food = {}, drink = {} }
    for itemID, count in pairs(counts) do
        local potency = ResolvePotency(itemID)
        local targets = potency and LISTS[potency.effect]
        if targets then
            local known = LookUpKnown(itemID)
            local name, _, _, itemLevel, minLevel = GetItemInfo(itemID)
            name = name or (known and known.name) or ("item:" .. itemID)
            minLevel = minLevel or (known and known.level) or 0
            local usable, reason = CheckUsable(itemID, minLevel, playerLevel)
            for resource, listKey in pairs(targets) do
                local amount = potency[resource]
                if amount then
                    local list = lists[listKey]
                    list[#list + 1] = {
                        itemID = itemID,
                        name = name,
                        count = count,
                        min = amount.min,
                        max = amount.max,
                        score = (amount.min + amount.max) / 2,
                        itemLevel = itemLevel or 0,
                        usable = usable,
                        reason = reason,
                        source = potency.source,
                        conjured = potency.conjured == true,
                        wellFed = potency.wellFed == true,
                    }
                end
            end
        end
    end
    return lists
end

-- Scans the bags and returns
--   { health = { entries = {...}, top = entry|nil }, mana = ..., food = ..., drink = ... }, retry
-- entries are ranked best first, unusable ones last; top is the first usable
-- entry. retry is true when some tooltip wasn't loaded yet.
function Potions.Scan()
    retryWanted = false
    local counts = CountBagItems()
    local lists = BuildEntries(counts, PlayerLevel())

    local result = {}
    for kind, list in pairs(lists) do
        sort(list, CompareEntries)
        local first = list[1]
        result[kind] = { entries = list, top = (first and first.usable) and first or nil }
    end

    -- Items that left the bags no longer need GET_ITEM_INFO_RECEIVED.
    for itemID in pairs(pendingItems) do
        if not counts[itemID] then pendingItems[itemID] = nil end
    end
    return result, retryWanted
end

---------------------------------------------------------------------------
-- /pmix tooltip
---------------------------------------------------------------------------

-- An item's raw tooltip lines, each with what ParseUseLine makes of it, and
-- its spell: (lines, spellID, spellLoaded). Asks for the spell if it isn't
-- loaded, so trying again a moment later shows the full text.
function Potions.InspectItem(itemID)
    local spellID, spellLoaded
    if GetItemSpell then spellID = select(2, GetItemSpell(itemID)) end
    if spellID and IsSpellDataCached then
        spellLoaded = IsSpellDataCached(spellID)
        if not spellLoaded and RequestLoadSpellData then RequestLoadSpellData(spellID) end
    end
    local lines = {}
    for _, text in ipairs(GetTooltipLines(itemID) or {}) do
        lines[#lines + 1] = { text = text, parsed = Potions.ParseUseLine(text), conjured = IsConjuredLine(text) }
    end
    return lines, spellID, spellLoaded
end
