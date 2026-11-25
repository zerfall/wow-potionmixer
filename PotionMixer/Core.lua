-- Potion Mixer: events, saved variables, combat-deferred queue, slash command.

local ADDON, ns = ...
local L = ns.L

local ipairs, pairs, type, pcall, print, tostring, tonumber = ipairs, pairs, type, pcall, print, tostring, tonumber
local concat, format = table.concat, string.format

---------------------------------------------------------------------------
-- Key binding strings (shown in the key bindings screen)
---------------------------------------------------------------------------

BINDING_HEADER_POTIONMIXER = "Potion Mixer"
_G["BINDING_NAME_CLICK PotionMixerHealingButton:LeftButton"] = L.BINDING_HEALING
_G["BINDING_NAME_CLICK PotionMixerManaButton:LeftButton"] = L.BINDING_MANA
_G["BINDING_NAME_CLICK PotionMixerFoodButton:LeftButton"] = L.BINDING_FOOD
_G["BINDING_NAME_CLICK PotionMixerDrinkButton:LeftButton"] = L.BINDING_DRINK

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

-- One position per pair: potions below the character (healing left, mana
-- right), food and drink just under them (45 px buttons + 8 px gap).
local DEFAULTS = {
    layout = {
        potions = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -180 },
        food    = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -233 },
    },
}
ns.DEFAULTS = DEFAULTS

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and CopyTable(value) or value
    end
    return copy
end

-- Fill in keys missing from target (e.g. added by a later version).
local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function InitSavedVariables()
    if type(PotionMixerDB) ~= "table" then PotionMixerDB = {} end
    local db = PotionMixerDB
    db.positions = nil -- per-button positions of the pre-release build
    -- 1.0.0 saved the potion pair as "position"; it is now layout.potions.
    if type(db.position) == "table" then
        if type(db.layout) ~= "table" then db.layout = {} end
        db.layout.potions = db.layout.potions or db.position
        db.position = nil
    end
    MergeDefaults(db, DEFAULTS)
    ns.db = PotionMixerDB
end

---------------------------------------------------------------------------
-- Helpers shared by the other files
---------------------------------------------------------------------------

function ns.Print(message)
    print("|cff33ff99Potion Mixer:|r " .. message)
end

-- C_Timer.After, or a minimal OnUpdate-driven stand-in on clients without it.
do
    local After = C_Timer and C_Timer.After
    if not After then
        local timerFrame = CreateFrame("Frame")
        local timers = {}
        timerFrame:Hide()
        timerFrame:SetScript("OnUpdate", function(self)
            local now, due = GetTime(), {}
            for index = #timers, 1, -1 do
                if timers[index].at <= now then
                    due[#due + 1] = table.remove(timers, index).callback
                end
            end
            if #timers == 0 then self:Hide() end
            for _, callback in ipairs(due) do callback() end
        end)
        After = function(delay, callback)
            timers[#timers + 1] = { at = GetTime() + delay, callback = callback }
            timerFrame:Show()
        end
    end
    ns.After = After
end

-- Protected changes (attributes, points) can't be made in combat. They are
-- stored by key, the latest one winning, and run on PLAYER_REGEN_ENABLED.
local combatQueue, combatQueueOrder = {}, {}

function ns.RunOutOfCombat(key, callback)
    if not InCombatLockdown() then
        combatQueue[key] = nil
        callback()
        return
    end
    if not combatQueue[key] then combatQueueOrder[#combatQueueOrder + 1] = key end
    combatQueue[key] = callback
end

local function FlushCombatQueue()
    local queue, order = combatQueue, combatQueueOrder
    combatQueue, combatQueueOrder = {}, {}
    for _, key in ipairs(order) do
        if queue[key] then ns.RunOutOfCombat(key, queue[key]) end
    end
end

---------------------------------------------------------------------------
-- Scan scheduling: bursts of events become one scan on the next frame.
---------------------------------------------------------------------------

local state = "waiting" -- "waiting" -> "ready", or "disabled"
local scanPending, retryPending = false, false
local TOOLTIP_RETRY_DELAY = 1

local function RunScan()
    scanPending = false
    local rankings, retry = ns.Potions.Scan()
    ns.lastRankings = rankings
    ns.Buttons.SetRankings(rankings)
    if retry then ns.RequestScanLater(TOOLTIP_RETRY_DELAY) end
end

function ns.RequestScan()
    if state ~= "ready" or scanPending then return end
    scanPending = true
    ns.After(0, RunScan)
end

function ns.RequestScanLater(delay)
    if retryPending then return end
    retryPending = true
    ns.After(delay, function()
        retryPending = false
        ns.RequestScan()
    end)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

local RUNTIME_EVENTS = {
    "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP",
    "PLAYER_ALIVE", "PLAYER_UNGHOST", "GET_ITEM_INFO_RECEIVED", "SPELL_DATA_LOAD_RESULT",
    "BAG_UPDATE_COOLDOWN", "UPDATE_BINDINGS", "MODIFIER_STATE_CHANGED",
}

local function RegisterEvent(event)
    -- pcall: an event this client doesn't know must not stop the others
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end

local function Disable(reason)
    state = "disabled"
    eventFrame:UnregisterAllEvents()
    ns.Print(format(L.DISABLED, reason))
end

local function Initialize()
    if state ~= "waiting" then return end
    if InCombatLockdown() then
        -- e.g. logging back in during combat after a disconnect
        ns.RunOutOfCombat("initialize", Initialize)
        return
    end
    if not ns.db then InitSavedVariables() end

    local missing = ns.Potions.MissingAPIs()
    if #missing > 0 then
        Disable(format(L.MISSING_API, concat(missing, ", ")))
        return
    end
    local ok, err = ns.Buttons.Create()
    if not ok then
        Disable(format(L.CREATE_FAILED, tostring(err)))
        return
    end

    state = "ready"
    for _, event in ipairs(RUNTIME_EVENTS) do RegisterEvent(event) end
    ns.RequestScan()
end

function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    eventFrame:UnregisterEvent("ADDON_LOADED")
    InitSavedVariables()
end

function handlers.PLAYER_LOGIN()
    ns.Potions.ClearCache()
    Initialize()
end

function handlers.PLAYER_ENTERING_WORLD() ns.RequestScan() end
function handlers.BAG_UPDATE_DELAYED() ns.RequestScan() end
function handlers.PLAYER_ALIVE() ns.RequestScan() end
function handlers.PLAYER_UNGHOST() ns.RequestScan() end

function handlers.PLAYER_LEVEL_UP(level)
    ns.Potions.SetLevelHint(level)
    ns.RequestScan()
    -- IsUsableItem can lag behind the level change; look again shortly.
    ns.RequestScanLater(1)
end

function handlers.GET_ITEM_INFO_RECEIVED(itemID)
    if ns.Potions.IsPending(itemID) then ns.RequestScan() end
end

-- An item's spell (its "Use:" text) has loaded: its tooltip can be read now.
function handlers.SPELL_DATA_LOAD_RESULT(spellID)
    if ns.Potions.SpellLoaded(spellID) then ns.RequestScan() end
end

function handlers.BAG_UPDATE_COOLDOWN() ns.Buttons.UpdateCooldowns() end
function handlers.UPDATE_BINDINGS() ns.Buttons.UpdateHotkeys() end
function handlers.MODIFIER_STATE_CHANGED() ns.Buttons.OnModifierChanged() end

function handlers.PLAYER_REGEN_DISABLED()
    ns.Buttons.OnCombatStart()
end

function handlers.PLAYER_REGEN_ENABLED()
    FlushCombatQueue()
    ns.Buttons.UpdateMoveCues()
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then handler(...) end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    RegisterEvent(event)
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

local function PrintHelp()
    -- The client's own names for the key bindings screen and its AddOns section.
    local keyBindings = SETTINGS_KEYBINDINGS_LABEL or KEY_BINDINGS or "Key Bindings"
    ns.Print(L.HELP_TITLE)
    print("  " .. L.HELP_RESET)
    print("  " .. L.HELP_LIST)
    print("  " .. L.HELP_TOOLTIP)
    print("  " .. format(L.HELP_MOVE, keyBindings, ADDONS or "AddOns"))
end

local function ResetPositions()
    if state ~= "ready" then
        ns.Print(L.NOT_ACTIVE)
    elseif InCombatLockdown() then
        ns.Print(L.RESET_IN_COMBAT)
    else
        ns.db.layout = CopyTable(DEFAULTS.layout)
        ns.Buttons.ApplyPositions()
        ns.Print(L.RESET_DONE)
    end
end

local LIST_HEADINGS = {
    { kind = "health", heading = L.LIST_HEALING },
    { kind = "mana",   heading = L.LIST_MANA },
    { kind = "food",   heading = L.LIST_FOOD },
    { kind = "drink",  heading = L.LIST_DRINK },
}
local SOURCE_NAMES = { tooltip = L.SOURCE_TOOLTIP, data = L.SOURCE_DATA }

local function EntryTags(entry)
    local tags = ""
    if entry.conjured then tags = tags .. " " .. L.TAG_CONJURED end
    if entry.wellFed then tags = tags .. " " .. L.TAG_WELL_FED end
    if not entry.usable then tags = tags .. " - " .. (entry.reason or "") end
    return tags
end

local function PrintRankings()
    local rankings = ns.lastRankings
    if not rankings then
        ns.Print(L.NO_SCAN)
        return
    end
    for _, list in ipairs(LIST_HEADINGS) do
        local ranking = rankings[list.kind]
        ns.Print(list.heading)
        if #ranking.entries == 0 then print("  " .. L.LIST_NONE) end
        for _, entry in ipairs(ranking.entries) do
            print(format("  %s %s x%d (%s) [%s]%s",
                entry == ranking.top and ">" or " ", entry.name, entry.count,
                ns.Potions.AmountText(entry), SOURCE_NAMES[entry.source] or entry.source, EntryTags(entry)))
        end
    end
end

local function DescribeParse(parsed)
    local parts = { parsed.effect }
    if parsed.health then parts[#parts + 1] = "health " .. ns.Potions.AmountText(parsed.health) end
    if parsed.mana then parts[#parts + 1] = "mana " .. ns.Potions.AmountText(parsed.mana) end
    if parsed.wellFed then parts[#parts + 1] = "Well Fed" end
    return concat(parts, ", ")
end

-- /pmix tooltip <item link or ID>: the item's raw tooltip lines (escape codes
-- shown as ||) and how each one is read. Diagnostic output, in English.
local function PrintTooltip(argument)
    local itemID = tonumber(argument:match("item:(%d+)") or argument:match("^%s*(%d+)%s*$"))
    if not itemID then
        ns.Print(L.TOOLTIP_USAGE)
        return
    end
    local lines, spellID, spellLoaded = ns.Potions.InspectItem(itemID)
    ns.Print(format("item %d, spell %s%s:", itemID, tostring(spellID or "-"),
        spellID and (spellLoaded and " (loaded)" or " (not loaded yet - try again in a moment)") or ""))
    if #lines == 0 then print("  (no tooltip lines)") end
    for _, line in ipairs(lines) do
        local text = "  " .. (line.text:gsub("|", "||"))
        if line.parsed then text = text .. "  |cff33ff99-> " .. DescribeParse(line.parsed) .. "|r" end
        if line.conjured then text = text .. "  |cff33ff99-> conjured|r" end
        print(text)
    end
end

SLASH_POTIONMIXER1 = "/pmix"
SLASH_POTIONMIXER2 = "/potionmixer"
SlashCmdList.POTIONMIXER = function(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "reset" then
        ResetPositions()
    elseif command == "list" then
        PrintRankings()
    elseif command == "tooltip" then
        PrintTooltip(rest)
    else
        PrintHelp()
    end
end
