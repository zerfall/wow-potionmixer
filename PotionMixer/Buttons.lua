-- Potion Mixer: secure buttons, visuals, cooldown text, dragging, tooltip.
-- The buttons come in pairs (potions; food and drink). Each pair sits in its
-- own holder frame and moves as one.

local _, ns = ...
local L = ns.L

local Buttons = {}
ns.Buttons = Buttons

local format, floor = string.format, math.floor
local ipairs, tostring, concat = ipairs, tostring, table.concat

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

-- What a click on a potion button does.
--   "macro": one "/use item:<id>" line per owned potion, best first. In combat
--            the attributes can't change, so when the top stack runs out the
--            click falls through to the next-best potion. Cost: after a
--            successful use the later lines can raise "Item is not ready yet".
--   "item":  use only the top potion (no extra error messages, but no
--            fall-through until combat ends).
local ACTION_MODE = "macro"
local MACRO_LIMIT = 255

-- Blizzard's own "exclude this action" value (SecureTemplates.lua): the
-- attribute lookup stops at e.g. "shift-type1" and then treats "" as no action.
local NOOP = ATTRIBUTE_NOOP or ""
local SHIFT_PREFIXES = { "shift-", "ctrl-shift-", "alt-shift-", "alt-ctrl-shift-" }

-- 10.x+ secure code acts on exactly one of down/up depending on the
-- ActionButtonUseKeyDown CVar, so registering both is safe there.
local CLICKS = { "AnyUp", "AnyDown" }

local GAP = 8           -- space between the two buttons of a pair
local GCD_MAX = 1.5     -- cooldowns this short are the global cooldown
local TICK = 0.1        -- countdown text refresh interval
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local TIMER_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- WoW Forever's own action button look, rebuilt from its ActionButtonTemplate
-- (Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml and
-- Mainline/ActionButtonOverrides.lua, "forever" branch of the UI source)
-- rather than inherited, so none of the template's mixin code runs.
local SIZE = 45
local FRAME_WIDTH, FRAME_HEIGHT = 46, 45 -- frame, pushed and highlight art
local COOLDOWN_INSET = 3
local ART = {
    slot      = "ui-hud-actionbar-iconframe-slot",
    mask      = "UI-HUD-ActionBar-IconFrame-Mask",
    frame     = "UI-HUD-ActionBar-IconFrame",
    pushed    = "UI-HUD-ActionBar-IconFrame-Down",
    highlight = "UI-HUD-ActionBar-IconFrame-Mouseover",
    border    = "UI-HUD-ActionBar-IconFrame-Border", -- Blizzard's equipped-item border; our move cue
}
local MOVE_CUE_COLOR = { 1, 0.82, 0 }

-- key: saved-position key (PotionMixerDB.layout[key]); actionMode: see above.
-- Button kind: the ranking list it shows (see Potions.Scan); anchor: its side
-- of the pair.
local GROUP_DEFS = {
    {
        key = "potions",
        actionMode = ACTION_MODE,
        buttons = {
            { key = "healing", kind = "health", name = "PotionMixerHealingButton", anchor = "LEFT",
              empty = L.EMPTY_HEALING, unusable = L.UNUSABLE_HEALING },
            { key = "mana", kind = "mana", name = "PotionMixerManaButton", anchor = "RIGHT",
              empty = L.EMPTY_MANA, unusable = L.UNUSABLE_MANA },
        },
    },
    {
        key = "food",
        -- Always the top item only: food and drink have no cooldown, so a
        -- macro with several /use lines could eat more than one per click.
        -- (They can't be used in combat, where the macro's fall-through
        -- would matter, and out of combat the attributes follow the bags.)
        actionMode = "item",
        buttons = {
            { key = "food", kind = "food", name = "PotionMixerFoodButton", anchor = "LEFT",
              empty = L.EMPTY_FOOD, unusable = L.UNUSABLE_FOOD },
            { key = "drink", kind = "drink", name = "PotionMixerDrinkButton", anchor = "RIGHT",
              empty = L.EMPTY_DRINK, unusable = L.UNUSABLE_DRINK },
        },
    },
}

local VALID_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local GetItemCooldown = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

-- group: { def, frame (unnamed holder; it is what moves), buttons,
--          moving (a Shift-drag is in progress), suspended (clicks switched off) }
local groups = {}
local buttons = {} -- all buttons of all groups

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function ItemIcon(itemID)
    return (itemID and GetItemIconByID and GetItemIconByID(itemID)) or QUESTION_MARK
end

local function TopEntry(button)
    return button.ranking and button.ranking.top
end

local function FormatRemaining(remaining)
    if remaining >= 60 then
        local seconds = floor(remaining)
        return format("%d:%02d", floor(seconds / 60), seconds % 60)
    elseif remaining >= 3 then
        return tostring(floor(remaining))
    end
    return format("%.1f", floor(remaining * 10) / 10)
end

---------------------------------------------------------------------------
-- Secure attributes (protected: never while InCombatLockdown())
---------------------------------------------------------------------------

local function SetAttributeIfChanged(button, name, value)
    if button:GetAttribute(name) ~= value then
        button:SetAttribute(name, value)
    end
end

local function BuildMacroText(entries)
    local lines, length = {}, 0
    for _, entry in ipairs(entries) do
        if entry.usable then
            local line = "/use item:" .. entry.itemID
            local added = #line + (length > 0 and 1 or 0)
            if length + added > MACRO_LIMIT then break end
            lines[#lines + 1] = line
            length = length + added
        end
    end
    return #lines > 0 and concat(lines, "\n") or nil
end

-- "*type1" (not "type1") so Ctrl/Alt-modified clicks and keys still work; the
-- shift-* attributes set at creation take precedence over it.
local function ApplyAttributes(button)
    local group = button.group
    local mode = group.def.actionMode
    local top = TopEntry(button)
    local value
    if top and not group.suspended then
        if mode == "item" then
            value = "item:" .. top.itemID
        else
            value = BuildMacroText(button.ranking.entries)
        end
    end
    SetAttributeIfChanged(button, "*type1", group.suspended and NOOP or mode)
    SetAttributeIfChanged(button, mode == "item" and "*item1" or "*macrotext1", value)
end

local function QueueAttributes(button)
    ns.RunOutOfCombat("attributes:" .. button.def.key, button.applyAttributes)
end

---------------------------------------------------------------------------
-- Positions of the pairs (protected: the holders have secure children)
---------------------------------------------------------------------------

local function IsValidPosition(pos)
    return type(pos) == "table" and VALID_POINTS[pos.point] and VALID_POINTS[pos.relativePoint]
        and type(pos.x) == "number" and type(pos.y) == "number"
end

local function ApplyPosition(group)
    local layout = ns.db and ns.db.layout
    local pos = layout and layout[group.def.key]
    if not IsValidPosition(pos) then pos = ns.DEFAULTS.layout[group.def.key] end
    group.frame:ClearAllPoints()
    group.frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end

local function Round(value)
    return floor(value * 10 + 0.5) / 10
end

-- Saved as an offset of the pair's centre from UIParent's centre.
local function SavePosition(group)
    local cx, cy = group.frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and ux) then return end
    local ratio = group.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    ns.db.layout[group.def.key] = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = Round((cx * ratio - ux) / ratio),
        y = Round((cy * ratio - uy) / ratio),
    }
end

function Buttons.ApplyPositions()
    for _, group in ipairs(groups) do
        ns.RunOutOfCombat("position:" .. group.def.key, group.applyPosition)
    end
end

---------------------------------------------------------------------------
-- Visuals (not protected: updated at any time, including in combat)
---------------------------------------------------------------------------

local function UpdateIcon(button)
    local top = TopEntry(button)
    if top then
        button.icon:SetTexture(ItemIcon(top.itemID))
        button.icon:SetDesaturated(false)
        button.count:SetText(top.count)
        button.count:Show()
    else
        button.icon:SetTexture(ItemIcon(ns.PLACEHOLDER_ITEMS[button.def.kind]))
        button.icon:SetDesaturated(true)
        button.count:SetText("")
        button.count:Hide()
    end
end

local function UpdateHotkey(button)
    local key = GetBindingKey("CLICK " .. button.def.name .. ":LeftButton")
    if key then
        button.hotkey:SetText(GetBindingText and GetBindingText(key, true) or key)
        button.hotkey:Show()
    else
        button.hotkey:SetText("")
        button.hotkey:Hide()
    end
end

-- A pair moves as one, so the "can be moved" cue lights up both of its buttons.
local function UpdateMoveCue(group)
    local hovered = false
    for _, button in ipairs(group.buttons) do hovered = hovered or button.hovered == true end
    local cue = group.moving or (hovered and IsShiftKeyDown() and not InCombatLockdown())
    for _, button in ipairs(group.buttons) do
        button.moveCue:SetShown(cue)
    end
end

local function UpdateMoveCues()
    for _, group in ipairs(groups) do UpdateMoveCue(group) end
end

---------------------------------------------------------------------------
-- Cooldown display
---------------------------------------------------------------------------

-- One parentless frame drives the countdown text of all buttons. It is shown
-- only while a cooldown runs, so its OnUpdate only runs then.
local ticker = CreateFrame("Frame")
ticker:Hide()

-- Returns true while any button still has a cooldown running.
local function UpdateTimerTexts()
    local now = GetTime()
    local active = false
    for _, button in ipairs(buttons) do
        if button.cdStart then
            local remaining = button.cdStart + button.cdDuration - now
            if remaining > 0 then
                button.timer:SetText(FormatRemaining(remaining))
                active = true
            else
                button.cdStart, button.cdDuration = nil, nil
                button.timer:SetText("")
            end
        end
    end
    return active
end

do
    local sinceTick = 0
    ticker:SetScript("OnUpdate", function(self, elapsed)
        sinceTick = sinceTick + elapsed
        if sinceTick < TICK then return end
        sinceTick = 0
        if not UpdateTimerTexts() then self:Hide() end
    end)
end

local function ReadCooldown(itemID)
    if not (GetItemCooldown and itemID) then return nil end
    local start, duration, enable = GetItemCooldown(itemID)
    if enable == 0 or enable == false then return nil end
    if not (start and duration) or start <= 0 or duration <= GCD_MAX then return nil end
    return start, duration
end

local function UpdateCooldown(button)
    local top = TopEntry(button)
    -- On an empty button, the placeholder's cooldown (0 on clients that only
    -- report cooldowns for items you own).
    local start, duration = ReadCooldown(top and top.itemID or ns.PLACEHOLDER_ITEMS[button.def.kind])
    if start then
        if start ~= button.cdStart or duration ~= button.cdDuration then
            button.cooldown:SetCooldown(start, duration)
        end
        button.cdStart, button.cdDuration = start, duration
    else
        if button.cdStart then
            if button.cooldown.Clear then button.cooldown:Clear() else button.cooldown:SetCooldown(0, 0) end
        end
        button.cdStart, button.cdDuration = nil, nil
        button.timer:SetText("")
    end
end

function Buttons.UpdateCooldowns()
    for _, button in ipairs(buttons) do UpdateCooldown(button) end
    if UpdateTimerTexts() then ticker:Show() end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function EntryText(entry)
    local text = format("%s  x%d  (%s)", entry.name, entry.count, ns.Potions.AmountText(entry))
    if entry.conjured then text = text .. "  " .. L.TAG_CONJURED end
    if entry.wellFed then text = text .. "  " .. L.TAG_WELL_FED end
    return text
end

local function ShowTooltip(button)
    local tooltip = GameTooltip
    tooltip:SetOwner(button, "ANCHOR_RIGHT")

    local ranking = button.ranking
    local entries = ranking and ranking.entries or {}
    local top = TopEntry(button)
    if top then
        tooltip:SetItemByID(top.itemID)
    else
        tooltip:SetText("Potion Mixer", 1, 1, 1)
        tooltip:AddLine(#entries > 0 and button.def.unusable or button.def.empty, 1, 0.3, 0.3)
    end

    if #entries > 0 then
        tooltip:AddLine(" ")
        for _, entry in ipairs(entries) do
            if entry == top then
                tooltip:AddLine("> " .. EntryText(entry), 0.2, 1, 0.2)
            elseif entry.usable then
                tooltip:AddLine("   " .. EntryText(entry), 1, 1, 1)
            else
                tooltip:AddLine("   " .. EntryText(entry) .. "  - " .. (entry.reason or ""), 0.5, 0.5, 0.5)
            end
        end
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(L.MOVE_HINT, 0.6, 0.6, 0.6)
    tooltip:Show()
end

local function IsTooltipOwner(button)
    return GameTooltip:IsShown() and GameTooltip:GetOwner() == button
end

---------------------------------------------------------------------------
-- Moving
---------------------------------------------------------------------------

-- Shift-dragging either button of a pair moves the pair's holder, so the two
-- stay together. While a move is in progress the pair's click actions are
-- suspended, so that releasing Shift before the mouse button can never use
-- anything.
local function SetActionsSuspended(group, value)
    group.suspended = value
    for _, button in ipairs(group.buttons) do QueueAttributes(button) end -- applied now when out of combat
end

local function FinishMove(group)
    if not group.moving then return end
    group.moving = false
    if not InCombatLockdown() then
        group.frame:StopMovingOrSizing()
        group.frame:SetUserPlaced(false) -- our saved position wins over the layout cache
        SavePosition(group)
        ApplyPosition(group)             -- re-anchor to UIParent CENTER
    end
    UpdateMoveCue(group)
end

local function OnDragStart(self)
    -- Moving a protected frame is blocked in combat: ignore the drag silently.
    if InCombatLockdown() or not IsShiftKeyDown() then return end
    local group = self.group
    SetActionsSuspended(group, true)
    group.moving = true
    group.frame:StartMoving()
    UpdateMoveCue(group)
end

local function OnDragStop(self)
    local group = self.group
    if not group.moving then return end
    FinishMove(group)
    -- Resume on the next frame, after any click belonging to this mouse
    -- release has been handled (and ignored).
    ns.After(0, group.resumeActions)
end

-- PLAYER_REGEN_DISABLED fires just before the lockdown starts, so protected
-- calls are still allowed here: end any move and restore the click actions.
function Buttons.OnCombatStart()
    for _, group in ipairs(groups) do
        FinishMove(group)
        if group.suspended then SetActionsSuspended(group, false) end
        UpdateMoveCue(group)
    end
end

---------------------------------------------------------------------------
-- Creation (out of combat only)
---------------------------------------------------------------------------

-- Frame, pushed and highlight art: 46x45 from the top-left, drawn over the icon.
local function PlaceFrameArt(texture, layer)
    if not texture then return end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT")
    texture:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    if layer then texture:SetDrawLayer(layer) end
end

local function CreateIcon(button)
    -- Empty-slot art under the icon, as on Forever's main action bar.
    local slot = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    slot:SetAllPoints()
    slot:SetAtlas(ART.slot)

    local icon = button:CreateTexture(nil, "BACKGROUND", nil, 0)
    icon:SetAllPoints()
    if button.CreateMaskTexture and icon.AddMaskTexture then
        -- Rounded corners, like Blizzard's buttons (atlas at its own size,
        -- as Blizzard's 45 px buttons use it).
        local mask = button:CreateMaskTexture()
        mask:SetAtlas(ART.mask, true)
        mask:SetPoint("CENTER", icon, "CENTER")
        icon:AddMaskTexture(mask)
    else
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    button.icon = icon
end

local function CreateFrameArt(button)
    button:SetNormalAtlas(ART.frame)
    PlaceFrameArt(button:GetNormalTexture(), "OVERLAY")
    button:SetPushedAtlas(ART.pushed)
    PlaceFrameArt(button:GetPushedTexture(), "OVERLAY")
    button:SetHighlightAtlas(ART.highlight)
    PlaceFrameArt(button:GetHighlightTexture())
end

local function CreateCooldown(button)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    if cooldown.SetUsingParentLevel then cooldown:SetUsingParentLevel(true) end -- template: useParentLevel
    cooldown:SetPoint("TOPLEFT", button.icon, "TOPLEFT", COOLDOWN_INSET, -COOLDOWN_INSET)
    cooldown:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", -COOLDOWN_INSET, COOLDOWN_INSET)
    if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.64) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
    cooldown.noCooldownCount = true -- we draw our own text; tells OmniCC-style addons to stay out
    button.cooldown = cooldown
end

-- Font of the client's own cooldown numbers, so our countdown looks the same.
local function CountdownFont(cooldown)
    local fontString = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
    if fontString then
        local font, size, flags = fontString:GetFont()
        if font and size and size > 0 then return font, size, flags end
    end
    return TIMER_FONT, 16, "OUTLINE"
end

-- Move cue, hotkey, count and countdown sit on a frame above the cooldown swipe.
local function CreateOverlay(button)
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)

    local cue = overlay:CreateTexture(nil, "OVERLAY")
    cue:SetAtlas(ART.border, true)
    cue:SetPoint("TOPLEFT")
    cue:SetVertexColor(MOVE_CUE_COLOR[1], MOVE_CUE_COLOR[2], MOVE_CUE_COLOR[3], 1)
    cue:Hide()
    button.moveCue = cue

    local hotkey = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    hotkey:SetSize(32, 10)
    hotkey:SetJustifyH("RIGHT")
    hotkey:SetPoint("TOPRIGHT", -4, -5)
    if ACTIONBAR_HOTKEY_FONT_COLOR then hotkey:SetVertexColor(ACTIONBAR_HOTKEY_FONT_COLOR:GetRGB()) end
    button.hotkey = hotkey

    local count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetJustifyH("RIGHT")
    count:SetPoint("BOTTOMRIGHT", -5, 5)
    button.count = count

    local timer = overlay:CreateFontString(nil, "OVERLAY")
    timer:SetFont(CountdownFont(button.cooldown))
    timer:SetPoint("CENTER", 0, 0)
    timer:SetTextColor(1, 1, 1)
    button.timer = timer
end

local function CreateRegions(button)
    CreateIcon(button)
    CreateFrameArt(button)
    CreateCooldown(button)
    CreateOverlay(button)
end

local function OnEnter(self)
    self.hovered = true
    ShowTooltip(self)
    UpdateMoveCue(self.group)
end

local function OnLeave(self)
    self.hovered = false
    if IsTooltipOwner(self) then GameTooltip:Hide() end
    UpdateMoveCue(self.group)
end

local function CreateHolder()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(2 * SIZE + GAP, SIZE)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    return frame
end

local function CreateButton(def, group)
    local button = CreateFrame("Button", def.name, group.frame, "SecureActionButtonTemplate")
    button.def = def
    button.group = group
    button.applyAttributes = function() ApplyAttributes(button) end

    button:SetSize(SIZE, SIZE)
    button:SetPoint(def.anchor, group.frame, def.anchor, 0, 0)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks(CLICKS[1], CLICKS[2])
    CreateRegions(button)

    -- Shift + left click is reserved for moving and must never use anything.
    for _, prefix in ipairs(SHIFT_PREFIXES) do
        button:SetAttribute(prefix .. "type1", NOOP)
    end

    button:SetScript("OnDragStart", OnDragStart)
    button:SetScript("OnDragStop", OnDragStop)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)

    ApplyAttributes(button)
    UpdateIcon(button)
    button:Show()
    return button
end

local function CreateGroup(groupDef)
    local group = { def = groupDef, buttons = {}, moving = false, suspended = false }
    group.applyPosition = function() ApplyPosition(group) end
    group.resumeActions = function()
        if not group.moving then SetActionsSuspended(group, false) end
    end
    group.frame = CreateHolder()
    ApplyPosition(group)
    for _, def in ipairs(groupDef.buttons) do
        local button = CreateButton(def, group)
        group.buttons[#group.buttons + 1] = button
        buttons[#buttons + 1] = button
    end
    return group
end

local function CreateAll()
    for _, groupDef in ipairs(GROUP_DEFS) do
        groups[#groups + 1] = CreateGroup(groupDef)
    end
end

-- Must run out of combat. Returns true, or false and an error message.
function Buttons.Create()
    if #groups > 0 then return true end
    local ok, err = pcall(CreateAll)
    if not ok then return false, err end
    Buttons.UpdateHotkeys()
    UpdateMoveCues()
    return true
end

---------------------------------------------------------------------------
-- Updates driven by Core's events
---------------------------------------------------------------------------

-- rankings: the result of ns.Potions.Scan()
function Buttons.SetRankings(rankings)
    for _, button in ipairs(buttons) do
        button.ranking = rankings[button.def.kind]
        UpdateIcon(button)
        UpdateCooldown(button)
        QueueAttributes(button) -- applied now, or when combat ends
        if IsTooltipOwner(button) then ShowTooltip(button) end
    end
    if UpdateTimerTexts() then ticker:Show() end
end

function Buttons.UpdateHotkeys()
    for _, button in ipairs(buttons) do UpdateHotkey(button) end
end

Buttons.UpdateMoveCues = UpdateMoveCues

-- The client may rebuild an item tooltip when modifiers change, which would
-- drop our ranked list, so redraw it.
function Buttons.OnModifierChanged()
    UpdateMoveCues()
    for _, button in ipairs(buttons) do
        if button.hovered and IsTooltipOwner(button) then ShowTooltip(button) end
    end
end
