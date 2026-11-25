-- Potion Mixer test harness: runs the real addon files in a mock of the WoW
-- API (secure attribute lookup, combat lockdown, bags, tooltips, item and
-- spell loading, events) and checks the results. No game client needed.
--
-- Usage, from the repository root:
--   lua5.1 tests/harness.lua             (or: luajit tests/harness.lua)
--   lua5.1 tests/harness.lua path/to/PotionMixer/
-- Exits with status 0 when every check passes.
local ADDON_DIR = arg[1] or "PotionMixer/"
if not ADDON_DIR:find("/$") then ADDON_DIR = ADDON_DIR .. "/" end

-- The addon's files, in the order its .toc loads them.
local FILES = {}
for line in io.lines(ADDON_DIR .. "PotionMixer.toc") do
    line = line:gsub("\r$", "")
    if line:find("%.lua$") and not line:find("^#") then FILES[#FILES + 1] = line end
end

local pass, fail = 0, 0
local function check(cond, msg)
    if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. msg) end
end
local function eq(got, want, msg)
    check(got == want, msg .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
end

---------------------------------------------------------------------------
-- Item database. enUS/deDE "Use:" lines are real Wowhead text (Classic for
-- 4540/159, Forever for the other food and drink), except the invented
-- 99xxx items.
---------------------------------------------------------------------------
local ITEMS = {
    [118]   = { name = "Minor Healing Potion", class = 0, ilvl = 5, req = 0, potion = true,
                en = "Use: Restores 70 to 90 health. (2 Min Cooldown)",
                de = "Benutzen: Stellt 70 bis 90 Punkt(e) Gesundheit wieder her. (2 Min Abklingzeit)" },
    [858]   = { name = "Lesser Healing Potion", class = 0, ilvl = 13, req = 3, potion = true,
                en = "Use: Restores 140 to 180 health. (2 Min Cooldown)",
                de = "Benutzen: Stellt 140 bis 180 Punkt(e) Gesundheit wieder her. (2 Min Abklingzeit)" },
    [4596]  = { name = "Minor Discolored Healing Potion", class = 0, ilvl = 15, req = 5, potion = true,
                en = "Use: Restores 150 to 170 health instantly; however you also suffer 75% of that amount over time.",
                de = "Benutzen: Stellt sofort 150 bis 170 Gesundheit wieder her, allerdings erleidet Ihr im Laufe der Zeit Schaden in H\195\182he von 75% des Werts." },
    [929]   = { name = "Healing Potion", class = 0, ilvl = 22, req = 12, potion = true,
                en = "Use: Restores 280 to 360 health. (2 Min Cooldown)",
                de = "Benutzen: Stellt 280 bis 360 Punkt(e) Gesundheit wieder her. (2 Min Abklingzeit)" },
    [13446] = { name = "Major Healing Potion", class = 0, ilvl = 55, req = 45, potion = true,
                en = "Use: Restores 1050 to 1750 health. (2 Min Cooldown)",
                de = "Benutzen: Stellt 1.050 bis 1.750 Punkt(e) Gesundheit wieder her. (2 Min Abklingzeit)" },
    [2455]  = { name = "Minor Mana Potion", class = 0, ilvl = 15, req = 5, potion = true,
                en = "Use: Restores 140 to 180 mana. (2 Min Cooldown)",
                de = "Benutzen: Stellt 140 bis 180 Punkt(e) Mana wieder her. (2 Min Abklingzeit)" },
    [3385]  = { name = "Lesser Mana Potion", class = 0, ilvl = 24, req = 14, potion = true,
                en = "Use: Restores 280 to 360 mana. (2 Min Cooldown)",
                de = "Benutzen: Stellt 280 bis 360 Punkt(e) Mana wieder her. (2 Min Abklingzeit)" },
    [2456]  = { name = "Minor Rejuvenation Potion", class = 0, ilvl = 15, req = 5, potion = true,
                en = "Use: Restores 90 to 150 mana and 90 to 150 health. (2 Min Cooldown)",
                de = "Benutzen: Stellt 90 bis 150 Punkt(e) Mana und 90 bis 150 Punkt(e) Gesundheit wieder her. (2 Min Abklingzeit)" },
    [18253] = { name = "Major Rejuvenation Potion", class = 0, ilvl = 60, req = 50, potion = true,
                en = "Use: Restores 1440 to 1760 mana and health. (2 Min Cooldown)",
                de = "Benutzen: Stellt 1440 bis 1760 Punkt(e) Mana und Gesundheit wieder her. (2 Min Abklingzeit)" },
    [17348] = { name = "Major Healing Draught", class = 0, ilvl = 55, req = 45, potion = true, bgOnly = true,
                en = "Use: Restores 980 to 1260 health. This item may only be used in PvP Battlegrounds. (5 Min Cooldown)",
                de = "Benutzen: Stellt 980 bis 1260 Gesundheit wieder her. Kann nur auf einem PvP-Schlachtfeld verwendet werden. (5 Min Abklingzeit)" },
    [99001] = { name = "Forever Healing Potion", class = 0, ilvl = 30, req = 20, potion = true,
                en = "Use: Restores 2,000 to 2,400 health. (2 Min Cooldown)",
                de = "Benutzen: Stellt 2.000 bis 2.400 Punkt(e) Gesundheit wieder her. (2 Min Abklingzeit)" },
    [1251]  = { name = "Linen Bandage", class = 0, ilvl = 8, req = 0,
                en = "Use: Heals 66 damage over 6 sec.",
                de = "Benutzen: Heilt 6 Sek. lang 66 Punkt(e) Schaden." },
    [5512]  = { name = "Minor Healthstone", class = 0, ilvl = 10, req = 0,
                en = "Use: Instantly restores 100 life. (2 Min Cooldown)",
                de = "Benutzen: Stellt sofort 100 Punkt(e) Leben wieder her. (2 Min Abklingzeit)" },
    [12662] = { name = "Demonic Rune", class = 0, ilvl = 50, req = 40,
                en = "Use: Restores 900 to 1500 mana at the cost of 600 to 1000 life. (2 Min Cooldown)",
                de = "Benutzen: Stellt 900 bis 1500 Manapunkt(e) wieder her, wobei 600 bis 1000 Punkt(e) Leben verbraucht wird. (2 Min Abklingzeit)" },
    [99002] = { name = "Forever Rune", class = 0, ilvl = 50, req = 40,
                en = "Use: Restores 900 to 1500 mana at the cost of 600 to 1000 life. (2 Min Cooldown)",
                de = "Benutzen: Stellt 900 bis 1500 Manapunkt(e) wieder her, wobei 600 bis 1000 Punkt(e) Leben verbraucht wird. (2 Min Abklingzeit)" },
    [2589]  = { name = "Linen Cloth", class = 7, ilvl = 5, req = 0 },

    -- food and drink
    [4540]  = { name = "Tough Hunk of Bread", class = 0, ilvl = 5, req = 1, food = true,
                en = "Use: Restores 61.2 health over 18 sec.  Must remain seated while eating.",
                de = "Benutzen: Stellt im Verlauf von 18 Sek. 61.2 Punkt(e) Gesundheit wieder her. Ihr m\195\188sst beim Essen sitzen bleiben." },
    [159]   = { name = "Refreshing Spring Water", class = 0, ilvl = 5, req = 1, food = true,
                en = "Use: Restores 151.2 mana over 18 sec.  Must remain seated while drinking.",
                de = "Benutzen: Stellt im Verlauf von 18 Sek. 151.2 Punkt(e) Mana wieder her. Ihr m\195\188sst beim Trinken sitzen bleiben." },
    [1179]  = { name = "Ice Cold Milk", class = 0, ilvl = 15, req = 5, food = true,
                en = "Use: Restores 437 mana over 21 sec. Must remain seated while drinking.",
                de = "Benutzen: Stellt im Verlauf von 21 Sek. insgesamt 437 Mana wieder her. Ihr m\195\188sst beim Trinken sitzen bleiben." },
    [8950]  = { name = "Homemade Cherry Pie", class = 0, ilvl = 45, req = 45, food = true,
                en = "Use: Restores 2065 health over 30 sec. Must remain seated while eating.",
                de = "Benutzen: Stellt im Verlauf von 30 Sek. 2065 Punkt(e) Gesundheit wieder her. Ihr m\195\188sst beim Essen sitzen bleiben." },
    [8076]  = { name = "Conjured Sweet Roll", class = 0, ilvl = 45, req = 45, food = true, conjured = true,
                en = "Use: Restores 2065 health over 30 sec. Must remain seated while eating.",
                de = "Benutzen: Stellt im Verlauf von 30 Sek. 2065 Punkt(e) Gesundheit wieder her. Ihr m\195\188sst beim Essen sitzen bleiben." },
    [13724] = { name = "Enriched Manna Biscuit", class = 0, ilvl = 55, req = 45, food = true,
                en = "Use: Restores 2065 health and 4240 mana over 30 sec. Must remain seated while eating.",
                de = "Benutzen: Stellt im Verlauf von 30 Sek. 2065 Gesundheit und 4240 Mana wieder her. Ihr m\195\188sst beim Essen sitzen bleiben." },
    [20452] = { name = "Smoked Desert Dumplings", class = 0, ilvl = 55, req = 45, food = true,
                en = "Use: Restores 2065 health over 30 sec. Must remain seated while eating. If you spend at least 10 sec eating, you will become well fed and gain 20 Strength for 15 min. Additionally, experience gained from kills is increased by 5%.",
                de = "Benutzen: Stellt im Verlauf von 30 Sek. 2065 Punkt(e) Gesundheit wieder her. Ihr m\195\188sst beim Essen sitzen bleiben. Wenn Ihr mindestens 10 Sek. mit Essen verbringt, werdet Ihr satt und erhaltet 15 Min. lang 20 St\195\164rke. Au\195\159erdem wird die durch Siege erhaltene Erfahrung um 5% erh\195\182ht." },
    [21023] = { name = "Dirge's Kickin' Chimaerok Chops", class = 0, ilvl = 55, req = 45, food = true,
                en = "Use: Restores 2452 health over 30 sec. Must remain seated while eating. If you spend at least 10 seconds eating you will become well fed and gain 25 Stamina for 15 min.",
                de = "Benutzen: Stellt im Verlauf von 30 Sek. 2452 Punkt(e) Gesundheit wieder her. Ihr m\195\188sst beim Essen sitzen bleiben. Wenn Ihr mindestens 10 Sekunden lang mit Essen verbringt, werdet Ihr satt und erhaltet 15 Min. lang 25 Punkte Ausdauer." },
    [8766]  = { name = "Morning Glory Dew", class = 0, ilvl = 55, req = 45, food = true,
                en = "Use: Restores 2821 mana over 30 sec. Must remain seated while drinking.",
                de = "Benutzen: Stellt im Verlauf von 30 Sek. 2821 Punkt(e) Mana wieder her. Ihr m\195\188sst beim Trinken sitzen bleiben." },
    [8079]  = { name = "Conjured Crystal Water", class = 0, ilvl = 65, req = 55, food = true, conjured = true,
                en = "Use: Restores 4038 mana over 30 sec. Must remain seated while drinking.",
                de = "Benutzen: Stellt im Verlauf von 30 Sek. 4038 Punkt(e) Mana wieder her. Ihr m\195\188sst beim Trinken sitzen bleiben." },
    [99003] = { name = "Forever Feast", class = 0, ilvl = 60, req = 50, food = true,
                en = "Use: Restores 3,500 health over 30 sec. Must remain seated while eating.",
                de = "Benutzen: Stellt im Verlauf von 30 Sek. 3.500 Punkt(e) Gesundheit wieder her. Ihr m\195\188sst beim Essen sitzen bleiben." },
    [99004] = { name = "Forever Regeneration Tonic", class = 0, ilvl = 40, req = 30,
                en = "Use: Restores 500 health over 10 sec.",
                de = "Benutzen: Stellt im Verlauf von 10 Sek. 500 Punkt(e) Gesundheit wieder her." },
}

---------------------------------------------------------------------------
-- World
---------------------------------------------------------------------------
local FR, ES = "Utiliser\194\160: ", "Uso: " -- in-game prefixes; French has a no-break space before ":"
local TRANSLATIONS = {
    [118]   = { fr = FR .. "Rend 70 à 90 points de vie. (2 Min Recharge)",
                es = ES .. "Restaura 70 al 90 p. de salud. (2 Min Reutilización)" },
    [858]   = { fr = FR .. "Rend 140 à 180 points de vie. (2 Min Recharge)",
                es = ES .. "Restaura 140 al 180 p. de salud. (2 Min Reutilización)" },
    [4596]  = { fr = FR .. "Rend instantanément 150 à 170 points de vie, mais vous subissez également 75 % de ce montant sur la durée.",
                es = ES .. "Restaura 150 al 170 p. de salud al instante, pero también pierdes un 75% de esa cantidad con el tiempo." },
    [13446] = { fr = FR .. "Rend 1050 à 1750 points de vie. (2 Min Recharge)",
                es = ES .. "Restaura 1050 al 1750 p. de salud. (2 Min Reutilización)" },
    [2455]  = { fr = FR .. "Rend 140 à 180 points de mana. (2 Min Recharge)",
                es = ES .. "Restaura 140 al 180 p. de maná. (2 Min Reutilización)" },
    [2456]  = { fr = FR .. "Rend 90 à 150 points de mana et 90 à 150 points de vie. (2 Min Recharge)",
                es = ES .. "Restaura 90 al 150 p. de maná y 90 al 150 de salud. (2 Min Reutilización)" },
    [18253] = { fr = FR .. "Rend 1440 à 1760 points de mana et de vie. (2 Min Recharge)",
                es = ES .. "Restaura 1440 al 1760 p. de maná y de salud. (2 Min Reutilización)" },
    [4540]  = { fr = FR .. "Rend 59 points de vie en 18 sec. Vous devez rester assis pendant que vous mangez.",
                es = ES .. "Restaura 59 p. de salud durante 18 s. Debes permanecer sentado mientras comes." },
    [159]   = { fr = FR .. "Rend 151 points de mana en 18 sec. Vous devez rester en position assise pendant que vous buvez.",
                es = ES .. "Restaura 151 p. de maná durante 18 s. Debes permanecer sentado mientras bebes." },
    [1179]  = { fr = FR .. "Rend 437 points de mana en 21 sec. Vous devez rester en position assise pendant que vous buvez.",
                es = ES .. "Restaura 437 p. de maná durante 21 s. Debes permanecer sentado mientras bebes." },
    [8950]  = { fr = FR .. "Rend 2065 points de vie en 30 sec. Vous devez rester assis pendant que vous mangez.",
                es = ES .. "Restaura 2065 p. de salud durante 30 s. Debes permanecer sentado mientras comes." },
    [8076]  = { fr = FR .. "Rend 2065 points de vie en 30 sec. Vous devez rester assis pendant que vous mangez.",
                es = ES .. "Restaura 2065 p. de salud durante 30 s. Debes permanecer sentado mientras comes." },
    [13724] = { fr = FR .. "Rend 2065 points de vie et 4240 points de mana en 30 sec. Vous devez rester assis pendant que vous mangez.",
                es = ES .. "Restaura 2065 p. de salud y 4240 p. de maná durante 30 s. Debes permanecer sentado mientras comes." },
    [20452] = { fr = FR .. "Rend 2065 points de vie en 30 sec. Vous devez rester assis pendant que vous mangez. Si vous passez au moins 10 s à manger, vous obtiendrez l’effet Bien nourri et bénéficierez d’un bonus de 20 à la Force pendant 15 min. L’expérience que vous gagnez en éliminant des adversaires est également augmentée de 5 %.",
                es = ES .. "Restaura 2065 p. de salud durante 30 s. Debes permanecer sentado mientras comes. Si pasas al menos 10 s comiendo, quedarás bien alimentado y recibirás 20 p. de fuerza durante 15 min. Además, la experiencia obtenida al matar enemigos aumenta un 5%." },
    [21023] = { fr = FR .. "Rend 2452 points de vie en 30 sec. Vous devez rester assis pendant que vous mangez. Si vous passez au moins 10 secondes à manger, vous bénéficiez d'un bonus de 25 à l'Endurance pendant 15 min.",
                es = ES .. "Restaura 2452 p. de salud durante 30 s. Debes permanecer sentado mientras comes. Si comes durante al menos 10 segundos, estarás bien alimentado y ganarás 25 p. de aguante durante 15 min." },
    [8766]  = { fr = FR .. "Rend 2821 points de mana en 30 sec. Vous devez rester assis pendant que vous buvez.",
                es = ES .. "Restaura 2821 p. de maná durante 30 s. Debes permanecer sentado mientras bebes." },
    [1251]  = { fr = FR .. "Rend 66 points de vie en 6 sec.",
                es = ES .. "Cura 66 p. de daño durante 6 s." },
    [5512]  = { fr = FR .. "Rend instantanément 120 points de vie. (2 Min Recharge)",
                es = ES .. "Restaura instantáneamente 120 p. de vida. (2 Min Reutilización)" },
    [12662] = { fr = FR .. "Rend 900 à 1500 points de mana au prix de 600 à 1000 points de vie. (2 Min Recharge)",
                es = ES .. "Restaura 900 al 1500 p. de maná con un consumo de 600 al 1000 p. de vida. (2 Min Reutilización)" },
    [99002] = { fr = FR .. "Rend 900 à 1500 points de mana au prix de 600 à 1000 points de vie. (2 Min Recharge)",
                es = ES .. "Restaura 900 al 1500 p. de maná con un consumo de 600 al 1000 p. de vida. (2 Min Reutilización)" },
    [99001] = { fr = FR .. "Rend 2\194\160000 à 2\194\160400 points de vie. (2 Min Recharge)",
                es = ES .. "Restaura 2.000 al 2.400 p. de salud. (2 Min Reutilización)" },
    [99003] = { fr = FR .. "Rend 3\194\160500 points de vie en 30 sec. Vous devez rester assis pendant que vous mangez.",
                es = ES .. "Restaura 3.500 p. de salud durante 30 s. Debes permanecer sentado mientras comes." },
    [99004] = { fr = FR .. "Rend 500 points de vie en 10 sec.",
                es = ES .. "Restaura 500 p. de salud durante 10 s." },
}
for id, t in pairs(TRANSLATIONS) do ITEMS[id].fr, ITEMS[id].es = t.fr, t.es end

local PROTECTED = {
    SetAttribute = true, SetPoint = true, ClearAllPoints = true, Show = true, Hide = true,
    SetSize = true, StartMoving = true, StopMovingOrSizing = true, SetScale = true,
    SetUserPlaced = true, RegisterForClicks = true, SetMovable = true,
    SetClampedToScreen = true, RegisterForDrag = true,
}

local function NewWorld(opts)
    opts = opts or {}
    local W = {
        time = 1000, lockdown = false, objects = {}, timers = {}, printed = {},
        unknownMethods = {}, violations = {}, bags = {}, cooldown = nil, gcd = nil,
        level = opts.level or 60, bindings = {}, mods = {}, used = {}, errors = {},
        cached = {}, locale = opts.locale or "en", scans = 0, inBattleground = false,
        spellMissing = {}, spellRequests = {},
    }
    -- Each item with a "Use:" text has spell 50000 + itemID; listed items start with it not loaded.
    local function SpellOf(id)
        local item = ITEMS[id]
        if item and (item.en or item.de or item.fr or item.es) then return 50000 + id end
    end
    for _, id in ipairs(opts.uncachedSpells or {}) do W.spellMissing[50000 + id] = true end
    for id in pairs(ITEMS) do W.cached[id] = true end
    for _, id in ipairs(opts.uncached or {}) do W.cached[id] = nil end

    local env = setmetatable({}, { __index = _G })
    W.env = env

    local function TooltipTexts(id)
        local item = ITEMS[id]
        if not W.cached[id] then return { env.RETRIEVING_ITEM_INFO } end
        local lines = { item.name }
        if item.conjured then lines[#lines + 1] = env.ITEM_CONJURED end
        local spellID = SpellOf(id)
        if item[W.locale] and not (spellID and W.spellMissing[spellID]) then lines[#lines + 1] = item[W.locale] end
        return lines
    end

    local function MakeObject(kind, name, parent, template)
        local obj = { _kind = kind, _name = name, _parent = parent, _attrs = {}, _scripts = {},
            _events = {}, _shown = true, _level = (parent and rawget(parent, "_level") or 0) + 1,
            _lines = {}, _fontStrings = {} }
        obj._secure = template ~= nil and template:find("SecureActionButtonTemplate", 1, true) ~= nil
        if obj._secure and parent then rawset(parent, "_hasSecureChild", true) end
        local M = {}
        function M:SetScript(n, fn) self._scripts[n] = fn end
        function M:GetScript(n) return self._scripts[n] end
        function M:RegisterEvent(e) self._events[e] = true end
        function M:UnregisterEvent(e) self._events[e] = nil end
        function M:UnregisterAllEvents() self._events = {} end
        function M:Show() self._shown = true end
        function M:Hide() self._shown = false end
        function M:IsShown() return self._shown end
        function M:SetShown(v) self._shown = v and true or false end
        function M:SetSize(w, h) self._w, self._h = w, h end
        function M:SetWidth(w) self._w = w end
        function M:SetHeight(h) self._h = h end
        function M:SetAttribute(n, v) self._attrs[n] = v end
        function M:GetAttribute(n) return self._attrs[n] end
        function M:SetPoint(point, rel, relPoint, x, y)
            if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end -- SetPoint(point, x, y)
            self._point = { point, rel, relPoint, x, y }
            if rel == env.UIParent and point == "CENTER" and relPoint == "CENTER" then
                self._center = { 960 + (x or 0), 540 + (y or 0) }
            end
        end
        function M:ClearAllPoints() self._point = nil end
        function M:SetAllPoints() end
        function M:GetCenter() if self._center then return self._center[1], self._center[2] end end
        function M:GetEffectiveScale() return 1 end
        function M:StartMoving() self._moving = true end
        function M:StopMovingOrSizing() self._moving = false end
        function M:SetUserPlaced(v) self._userPlaced = v end
        function M:SetMovable() end
        function M:SetClampedToScreen() end
        function M:RegisterForDrag() end
        function M:RegisterForClicks(...) self._clicks = { ... } end
        function M:CreateTexture(_, layer, _, sublevel)
            local t = MakeObject("Texture", nil, self); t._layer, t._sublevel = layer, sublevel; return t
        end
        function M:CreateMaskTexture() return MakeObject("MaskTexture", nil, self) end
        function M:AddMaskTexture(mask) self._mask = mask end
        function M:CreateFontString() return MakeObject("FontString", nil, self) end
        function M:SetAtlas(atlas, useAtlasSize) self._atlas, self._atlasSize = atlas, useAtlasSize end
        function M:SetDrawLayer(layer) self._layer = layer end
        function M:SetVertexColor(r, g, b, a) self._vertex = { r, g, b, a } end
        function M:SetJustifyH(j) self._justifyH = j end
        function M:SetFrameLevel(l) self._level = l end
        function M:GetFrameLevel() return self._level end
        function M:SetCooldown(s, d) self._cd = (d and d > 0) and { s, d } or nil end
        function M:Clear() self._cd = nil end
        function M:SetHideCountdownNumbers(v) self._hideNumbers = v end
        function M:SetSwipeColor(r, g, b, a) self._swipe = { r, g, b, a } end
        function M:SetDrawBling(v) self._bling = v end
        function M:SetDrawEdge(v) self._edge = v end
        function M:SetUsingParentLevel(v) self._useParentLevel = v end
        function M:GetCountdownFontString()
            if not self._countdown then
                self._countdown = MakeObject("FontString", nil, self)
                self._countdown._font = { "Fonts\\FRIZQT__.TTF", 18, "OUTLINE" }
            end
            return self._countdown
        end
        function M:GetName() return self._name end
        function M:SetTexture(t) self._texture = t end
        function M:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
        function M:SetTexCoord() end
        function M:SetDesaturated(v) self._desat = v end
        function M:SetText(t)
            if self._kind == "GameTooltip" then self._lines = { tostring(t) } else self._text = t ~= nil and tostring(t) or nil end
        end
        function M:GetText() return self._text end
        function M:SetFont(font, size, flags) self._font = { font, size, flags } end
        function M:GetFont() if self._font then return self._font[1], self._font[2], self._font[3] end end
        function M:SetFontObject() end
        function M:SetTextColor() end
        for _, state in ipairs({ "Normal", "Pushed", "Highlight" }) do
            M["Set" .. state .. "Atlas"] = function(self, atlas)
                local key = "_" .. state
                self[key] = self[key] or MakeObject("Texture", nil, self)
                self[key]._atlas = atlas
            end
            M["Get" .. state .. "Texture"] = function(self) return self["_" .. state] end
        end
        -- GameTooltip
        function M:SetOwner(owner) self._owner = owner; self._lines = {}; self._shown = true end
        function M:GetOwner() return self._owner end
        function M:ClearLines() self._lines = {}; for _, fs in ipairs(self._fontStrings) do fs._text = nil end end
        function M:AddLine(t) self._lines[#self._lines + 1] = t end
        function M:AddFontStrings(l) self._fontStrings[#self._fontStrings + 1] = l end
        function M:NumLines() return #self._lines end
        function M:SetItemByID(id)
            local lines = TooltipTexts(id)
            self._lines = lines
            for i, text in ipairs(lines) do if self._fontStrings[i] then self._fontStrings[i]._text = text end end
        end
        setmetatable(obj, { __index = function(_, k)
            if type(k) ~= "string" or not k:find("^%u") then return nil end
            local m = M[k]
            if not m then W.unknownMethods[k] = true; return function() end end
            if (obj._secure or rawget(obj, "_hasSecureChild")) and PROTECTED[k] then
                return function(self, ...)
                    if W.lockdown then W.violations[#W.violations + 1] = (self._name or "?") .. ":" .. k end
                    return m(self, ...)
                end
            end
            return m
        end })
        W.objects[#W.objects + 1] = obj
        if name then env[name] = obj end
        return obj
    end

    env.CreateFrame = function(kind, name, parent, template) return MakeObject(kind, name, parent, template) end
    env.UIParent = MakeObject("Frame", "UIParent")
    env.UIParent._center = { 960, 540 }
    env.WorldFrame = MakeObject("Frame", "WorldFrame")
    env.GameTooltip = MakeObject("GameTooltip", "GameTooltip")
    env.GameTooltip._shown = false

    env.ATTRIBUTE_NOOP = ""
    local CLIENT_STRINGS = { -- ITEM_SPELL_TRIGGER_ONUSE, ITEM_CONJURED, ITEM_MIN_LEVEL, RETRIEVING_ITEM_INFO
        en = { "Use:", "Conjured Item", "Requires Level %d", "Retrieving item information", "AddOns", "Key Bindings" },
        de = { "Benutzen:", "Herbeigezauberter Gegenstand", "Benötigt Stufe %d", "Gegenstandsinformationen werden abgerufen", "AddOns", "Tastaturbelegung" },
        fr = { "Utiliser\194\160:", "Objet invoqué", "Niveau %d requis", "Récupération des informations de l'objet", "AddOns", "Raccourcis" },
        es = { "Uso:", "Objeto mágico", "Necesitas ser de nivel %d", "Recuperando información del objeto", "Accesorios", "Asignación de teclas" },
    }
    local S = CLIENT_STRINGS[W.locale]
    env.ITEM_SPELL_TRIGGER_ONUSE, env.ITEM_CONJURED, env.ITEM_MIN_LEVEL, env.RETRIEVING_ITEM_INFO = S[1], S[2], S[3], S[4]
    env.ADDONS, env.SETTINGS_KEYBINDINGS_LABEL = S[5], S[6]
    local LOCALE_CODES = { en = "enUS", de = "deDE", fr = "frFR", es = "esES" }
    env.GetLocale = function() return opts.localeCode or LOCALE_CODES[W.locale] end
    env.NUM_BAG_SLOTS = 4
    env.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.Enum = { ItemClass = { Consumable = 0 } }
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.print = function(...) local parts = {} for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end W.printed[#W.printed + 1] = table.concat(parts, " ") end
    env.SlashCmdList = {}
    env.GetTime = function() return W.time end
    env.InCombatLockdown = function() return W.lockdown end
    env.IsShiftKeyDown = function() return W.mods.shift == true end
    env.UnitLevel = function() return W.level end
    env.GetBindingKey = function(cmd) return W.bindings[cmd] end
    env.GetBindingText = function(key, abbrev) return abbrev and (key:gsub("SHIFT%-", "s-")) or key end

    env.C_Timer = (not opts.noTimer) and { After = function(delay, fn) W.timers[#W.timers + 1] = { at = W.time + delay, fn = fn } end } or nil

    local function SlotItem(bag, slot) return W.bags[bag] and W.bags[bag][slot] end
    if not opts.noContainer then
        env.C_Container = {
            GetContainerNumSlots = function(bag) return (bag >= 0 and bag <= 4) and 16 or 0 end,
            GetContainerItemInfo = function(bag, slot)
                local s = SlotItem(bag, slot)
                if s then return { itemID = s.id, stackCount = s.count, hyperlink = "item:" .. s.id } end
            end,
            GetItemCooldown = function(id)
                local item = ITEMS[id]
                if item and item.potion and W.cooldown and W.cooldown.start + W.cooldown.duration > W.time then
                    return W.cooldown.start, W.cooldown.duration, 1
                end
                if W.gcd then return W.gcd, 1.5, 1 end
                return 0, 0, 1
            end,
        }
    end
    env.C_Item = {
        GetItemInfo = function(id)
            local item = ITEMS[id]
            if not item or not W.cached[id] then return nil end
            return item.name, "item:" .. id, 1, item.ilvl, item.req, "Consumable", "Potion", 5, "", "icon:" .. id, 1, item.class, 0
        end,
        GetItemInfoInstant = function(id)
            local item = ITEMS[id]
            if item then return id, "Consumable", "Potion", "", "icon:" .. id, item.class, 0 end
        end,
        GetItemIconByID = function(id) return "icon:" .. id end,
        IsUsableItem = function(id)
            local item = ITEMS[id]
            if not item then return false, false end
            if item.bgOnly and not W.inBattleground then return false, false end
            if item.food and W.lockdown then return false, false end -- can't eat or drink in combat
            return W.level >= (item.req or 0), false
        end,
        RequestLoadItemDataByID = function() end,
        GetItemSpell = function(id)
            local spellID = SpellOf(id)
            if spellID then return ITEMS[id].name, spellID end
        end,
    }
    env.C_Spell = {
        IsSpellDataCached = function(spellID) return not W.spellMissing[spellID] end,
        RequestLoadSpellData = function(spellID) W.spellRequests[spellID] = (W.spellRequests[spellID] or 0) + 1 end,
    }
    if not opts.noTooltipInfo then
        env.C_TooltipInfo = { GetItemByID = function(id)
            if not ITEMS[id] then return nil end
            local lines = {}
            for i, text in ipairs(TooltipTexts(id)) do lines[i] = { leftText = text } end
            return { lines = lines }
        end }
    end

    env.PotionMixerDB = opts.savedDB
    local ns = {}
    W.ns = ns
    for _, file in ipairs(FILES) do
        local fh = assert(io.open(ADDON_DIR .. file)); local src = fh:read("*a"); fh:close()
        for _, patch in ipairs((opts.patches or {})[file] or {}) do
            local n; src, n = src:gsub(patch[1], patch[2], 1); assert(n == 1, "patch not applied: " .. patch[1])
        end
        local chunk = assert(loadstring(src, "@" .. file))
        setfenv(chunk, env)
        chunk("PotionMixer", ns)
    end

    -- count scans
    local realScan = ns.Potions.Scan
    ns.Potions.Scan = function(...) W.scans = W.scans + 1 return realScan(...) end

    function W.Fire(event, ...)
        for _, obj in ipairs(W.objects) do
            if obj._events[event] and obj._scripts.OnEvent then obj._scripts.OnEvent(obj, event, ...) end
        end
    end
    function W.NextFrame(step)
        step = step or 0.016
        W.time = W.time + step
        local due, keep = {}, {}
        for _, t in ipairs(W.timers) do if t.at <= W.time then due[#due + 1] = t else keep[#keep + 1] = t end end
        W.timers = keep
        for _, t in ipairs(due) do t.fn() end
        for _, obj in ipairs(W.objects) do
            if obj._shown and obj._scripts.OnUpdate and obj._kind == "Frame" then obj._scripts.OnUpdate(obj, step) end
        end
    end
    function W.Advance(seconds) local target = W.time + seconds while W.time < target do W.NextFrame(0.05) end end
    function W.Login()
        W.Fire("ADDON_LOADED", "PotionMixer")
        W.Fire("PLAYER_LOGIN")
        W.Fire("PLAYER_ENTERING_WORLD", true, false)
        W.NextFrame(); W.NextFrame()
    end
    function W.SetBags(list) -- list of {id, count}, 16 slots per bag
        W.bags = {}
        for i, s in ipairs(list) do
            local bag, slot = math.floor((i - 1) / 16), (i - 1) % 16 + 1
            W.bags[bag] = W.bags[bag] or {}
            W.bags[bag][slot] = { id = s[1], count = s[2] }
        end
    end
    function W.Count(id)
        local n = 0
        for _, bag in pairs(W.bags) do for _, s in pairs(bag) do if s.id == id then n = n + s.count end end end
        return n
    end
    function W.Consume(id)
        for _, bag in pairs(W.bags) do for slot, s in pairs(bag) do
            if s.id == id then s.count = s.count - 1; if s.count == 0 then bag[slot] = nil end return end
        end end
    end
    function W.LoadSpell(itemID, success)
        if success then W.spellMissing[50000 + itemID] = nil end
        W.Fire("SPELL_DATA_LOAD_RESULT", 50000 + itemID, success)
    end
    function W.BagChanged() W.Fire("BAG_UPDATE", 0); W.Fire("BAG_UPDATE_DELAYED"); W.NextFrame() end
    function W.EnterCombat() W.Fire("PLAYER_REGEN_DISABLED"); W.lockdown = true end
    function W.LeaveCombat() W.lockdown = false; W.Fire("PLAYER_REGEN_ENABLED") end

    -- Blizzard's lookup: prefix..name..suffix, *name..suffix, prefix..name*, *name*, prefix..name, *name, name
    local function Lookup(button, prefix, name, suffix)
        for _, key in ipairs({ prefix .. name .. suffix, "*" .. name .. suffix, prefix .. name .. "*",
                               "*" .. name .. "*", prefix .. name, "*" .. name, name }) do
            local v = button._attrs[key]
            if v ~= nil then if v == "" then return nil end return v end
        end
    end
    local function TryUse(id)
        if W.Count(id) == 0 then return end
        local item = ITEMS[id]
        if item.potion and W.cooldown and W.cooldown.start + W.cooldown.duration > W.time then
            W.errors[#W.errors + 1] = "Item is not ready yet."
            return
        end
        if not env.C_Item.IsUsableItem(id) then W.errors[#W.errors + 1] = "can't use"; return end
        W.Consume(id)
        W.used[#W.used + 1] = id
        if item.potion then W.cooldown = { start = W.time, duration = 120 } end
    end
    -- One secure click (one press): returns the action type that ran.
    function W.Click(button, mods)
        local prefix = ""
        mods = mods or {}
        if mods.shift then prefix = "shift-" .. prefix end
        if mods.ctrl then prefix = "ctrl-" .. prefix end
        if mods.alt then prefix = "alt-" .. prefix end
        local actionType = Lookup(button, prefix, "type", "1")
        local before = #W.used
        if actionType == "macro" then
            local text = Lookup(button, prefix, "macrotext", "1")
            for id in (text or ""):gmatch("/use item:(%d+)") do TryUse(tonumber(id)) end
        elseif actionType == "item" then
            local item = Lookup(button, prefix, "item", "1")
            if item then TryUse(tonumber(item:match("item:(%d+)"))) end
        end
        if #W.used > before then W.Fire("BAG_UPDATE_COOLDOWN"); W.BagChanged() end
        return actionType
    end
    local BUTTON_NAMES = { healing = "PotionMixerHealingButton", mana = "PotionMixerManaButton",
                           food = "PotionMixerFoodButton", drink = "PotionMixerDrinkButton" }
    function W.Button(key) return env[BUTTON_NAMES[key]] end
    function W.Hover(button) button._scripts.OnEnter(button) end
    function W.TooltipText() return table.concat(env.GameTooltip._lines, "\n") end
    function W.Ids(kind)
        local ids = {}
        for _, e in ipairs(W.ns.lastRankings[kind].entries) do ids[#ids + 1] = e.itemID end
        return table.concat(ids, ",")
    end
    return W
end

---------------------------------------------------------------------------
-- 1. Parser against real tooltip strings
---------------------------------------------------------------------------
do
    local W = NewWorld()
    local P = W.ns.Potions
    local function amounts(line)
        local a = P.ParseUseLine(line)
        if not a then return "nil" end
        local s = { a.effect }
        if a.health then s[#s + 1] = "h" .. a.health.min .. "-" .. a.health.max end
        if a.mana then s[#s + 1] = "m" .. a.mana.min .. "-" .. a.mana.max end
        if a.wellFed then s[#s + 1] = "wellfed" end
        return table.concat(s, " ")
    end
    local expect = {
        [118] = "instant h70-90", [858] = "instant h140-180", [4596] = "instant h150-170",
        [929] = "instant h280-360", [13446] = "instant h1050-1750",
        [2455] = "instant m140-180", [3385] = "instant m280-360", [2456] = "instant h90-150 m90-150",
        [18253] = "instant h1440-1760 m1440-1760", [17348] = "instant h980-1260", [99001] = "instant h2000-2400",
        [1251] = "nil", [5512] = "instant h100-100", [12662] = "nil", [99002] = "nil", [99004] = "nil",
        [4540] = "seated h61.2-61.2", [159] = "seated m151.2-151.2", [1179] = "seated m437-437",
        [8950] = "seated h2065-2065", [8076] = "seated h2065-2065", [13724] = "seated h2065-2065 m4240-4240",
        [20452] = "seated h2065-2065 wellfed", [21023] = "seated h2452-2452 wellfed",
        [8766] = "seated m2821-2821", [8079] = "seated m4038-4038", [99003] = "seated h3500-3500",
    }
    local forever = { [4540] = "seated h59-59", [159] = "seated m151-151", [5512] = "instant h120-120" }
    local byLocale = { fr = forever, es = forever }
    for id, want in pairs(expect) do
        for _, loc in ipairs({ "en", "de", "fr", "es" }) do
            local line = ITEMS[id][loc]
            local wanted = (byLocale[loc] or {})[id] or want
            if line then eq(amounts(line), wanted, "parse " .. loc .. " " .. ITEMS[id].name) end
        end
    end
    eq(amounts("Use: Instantly restores 120 life."), "instant h120-120", "Forever healthstone text")
    eq(amounts("Use: Restores 375 health."), "instant h375-375", "single amount enUS")
    eq(amounts("Use: Restores 375 health"), "instant h375-375", "no full stop")
    eq(amounts("Benutzen: Stellt 375 Mana wieder her."), "instant m375-375", "single amount deDE")
    eq(amounts("Benutzen: Stellt 1050 bis 1750 Gesundheit wieder her."), "instant h1050-1750", "spec deDE example")
    eq(amounts("|cff00ff00Use: Restores 1,050 to 1,750 health.|r"), "instant h1050-1750", "colour codes + commas")
    eq(amounts("Use: Restores 1 050 to 1 750 health."), "instant h1050-1750", "space thousands")
    eq(amounts("Use: Restores 1\194\160050 to 1\194\160750 health."), "instant h1050-1750", "nbsp thousands")
    eq(amounts("Benutzen: Stellt im Verlauf von 18 Sek. 61,2 Punkt(e) Gesundheit wieder her. Ihr m\195\188sst beim Essen sitzen bleiben."), "seated h61.2-61.2", "deDE decimal comma")
    eq(amounts("Utilise: Rend 70 à 90 points de vie."), "instant h70-90", "frFR Wowhead-style prefix")
    eq(amounts("Utiliser : Rend 1\226\128\175050 à 1\226\128\175750 points de vie."), "instant h1050-1750", "frFR narrow no-break space thousands")
    eq(amounts("Utiliser : Rend 61,2 points de vie en 18 sec. Vous devez rester assis pendant que vous mangez."), "seated h61.2-61.2", "frFR decimal comma")
    eq(amounts("Utiliser : Surprend 50 points de vie."), "nil", "frFR 'rend' only as a whole word")
    eq(amounts("Uso: Restaura 1.050 al 1.750 p. de salud."), "instant h1050-1750", "esES thousands dot")
    -- esMX (Latin American Spanish), WoW Forever tooltips from Wowhead
    eq(amounts("Uso: Restaura 90 al 150 p. de maná y 90 al 150 p. de salud. (2 Min Reutilización)"), "instant h90-150 m90-150", "esMX rejuvenation")
    eq(amounts("Uso: Restaura 150 al 170 p. de salud al instante, pero también recibes daño equivalente a un 75% de esa cantidad en el tiempo."), "instant h150-170", "esMX discolored potion")
    eq(amounts("Uso: Restaura 900 al 1500 p. de maná con un costo de 600 al 1000 p. de vida. (2 Min Reutilización)"), "nil", "esMX rune rejected")
    eq(amounts("Uso: Sana 66 p. de daño durante 6 s."), "nil", "esMX bandage")
    eq(amounts("Uso: Restaura 2065 p. de salud durante 30 s. Debes permanecer sentado mientras comes. Debes permanecer sentado mientras comes. Si lo haces durante al menos 10 s, quedarás bien alimentado y obtendrás 20 p. de fuerza durante 15 min."), "seated h2065-2065 wellfed", "esMX buff food")
    eq(amounts("Uso: Restaura 2065 p. de salud y 4240 p. de maná durante 30 s. Debes permanecer sentado mientras comes."), "seated h2065-2065 m4240-4240", "esMX manna biscuit")
    eq(amounts("Benutzen: Stellt 280 bis 360 |4Punkt:Punkte; Gesundheit wieder her."), "instant h280-360", "deDE plural escape |4")
    eq(amounts("Benutzen: Stellt im Verlauf von 24 Sek. 531 |4Punkt:Punkte; Gesundheit wieder her. Ihr müsst beim Essen sitzen bleiben."), "seated h531-531", "deDE food with plural escape")
    eq(amounts("Use: Restores 70 to 90 |4point:points:points; of health."), "instant h70-90", "three-form plural escape")
    eq(amounts("Restores 70 to 90 health."), "nil", "no Use: prefix")
    eq(amounts("Equip: Restores 5 health every 5 sec."), "nil", "Equip line")
    eq(P.AmountText({ min = 2065, max = 2065 }), "2065", "amount text fixed")
    eq(P.AmountText({ min = 61.2, max = 61.2 }), "61.2", "amount text decimal")
    eq(P.AmountText({ min = 1050, max = 1750 }), "1050-1750", "amount text range")
end

---------------------------------------------------------------------------
-- 2. Login with empty bags, then the potion flow out of combat
---------------------------------------------------------------------------
do
    local W = NewWorld()
    W.Login()
    local heal, mana = W.Button("healing"), W.Button("mana")
    local food, drink = W.Button("food"), W.Button("drink")
    check(heal and mana and food and drink, "all four buttons exist")
    eq(heal.icon._texture, "icon:118", "healing placeholder icon")
    eq(mana.icon._texture, "icon:2455", "mana placeholder icon")
    eq(food.icon._texture, "icon:4540", "food placeholder icon")
    eq(drink.icon._texture, "icon:159", "drink placeholder icon")
    eq(heal.icon._desat, true, "placeholder desaturated")
    eq(food.icon._desat, true, "food placeholder desaturated")
    eq(heal.count._shown, false, "count hidden when empty")
    eq(heal._shown, true, "empty button still shown")
    for _, b in ipairs({ heal, mana, food, drink }) do
        eq(b._attrs["shift-type1"], "", b._name .. ": shift-type1 is NOOP")
        eq(b._attrs["alt-ctrl-shift-type1"], "", b._name .. ": alt-ctrl-shift-type1 is NOOP")
    end
    eq(heal._attrs["*macrotext1"], nil, "no macrotext when empty")
    local group = heal._parent
    check(group ~= W.env.UIParent and group == mana._parent, "potion buttons share one holder")
    local foodGroup = food._parent
    check(foodGroup ~= group and foodGroup == drink._parent and foodGroup ~= W.env.UIParent, "food and drink share their own holder")
    eq(group._w, 98, "holder width = 2 buttons + gap")
    eq(group._point[1] .. group._point[3] .. group._point[4] .. "," .. group._point[5], "CENTERCENTER0,-180", "potion pair default position")
    eq(foodGroup._point[1] .. foodGroup._point[3] .. foodGroup._point[4] .. "," .. foodGroup._point[5], "CENTERCENTER0,-233", "food pair default position")
    check(group._point[2] == W.env.UIParent, "holder anchored to UIParent")
    eq(heal._point[1] .. ":" .. heal._point[3], "LEFT:LEFT", "healing on the left")
    eq(mana._point[1] .. ":" .. mana._point[3], "RIGHT:RIGHT", "mana on the right")
    eq(food._point[1] .. ":" .. food._point[3], "LEFT:LEFT", "food on the left")
    eq(drink._point[1] .. ":" .. drink._point[3], "RIGHT:RIGHT", "drink on the right")
    -- Forever action button art
    eq(heal._w, 45, "button is 45x45 like Forever's action buttons")
    local normal, pushed, highlight = heal:GetNormalTexture(), heal:GetPushedTexture(), heal:GetHighlightTexture()
    eq(normal and normal._atlas, "UI-HUD-ActionBar-IconFrame", "frame atlas")
    eq(normal and (normal._w .. "x" .. normal._h .. " " .. normal._layer), "46x45 OVERLAY", "frame size and layer")
    eq(normal and normal._point[1], "TOPLEFT", "frame anchored top-left")
    eq(pushed and pushed._atlas, "UI-HUD-ActionBar-IconFrame-Down", "pushed atlas")
    eq(highlight and highlight._atlas, "UI-HUD-ActionBar-IconFrame-Mouseover", "highlight atlas")
    eq(food:GetNormalTexture() and food:GetNormalTexture()._atlas, "UI-HUD-ActionBar-IconFrame", "food button has the same art")
    eq(heal.icon._mask and heal.icon._mask._atlas, "UI-HUD-ActionBar-IconFrame-Mask", "icon mask atlas")
    eq(heal.icon._mask and heal.icon._mask._atlasSize, true, "icon mask at atlas size")
    eq(heal.cooldown._swipe and table.concat(heal.cooldown._swipe, ","), "0,0,0,0.64", "swipe colour")
    eq(heal.cooldown._point[1] .. heal.cooldown._point[4] .. "," .. heal.cooldown._point[5], "BOTTOMRIGHT-3,3", "cooldown inset 3")
    eq(heal.timer._font[2], 18, "countdown uses the client's cooldown font")
    eq(heal.hotkey._point[4] .. "," .. heal.hotkey._point[5], "-4,-5", "hotkey position")
    eq(heal.count._point[4] .. "," .. heal.count._point[5], "-5,5", "count position")
    eq(heal.moveCue._atlas, "UI-HUD-ActionBar-IconFrame-Border", "move cue uses Blizzard border art")
    eq(heal._clicks[1] .. "," .. heal._clicks[2], "AnyUp,AnyDown", "click registration")
    eq(heal.cooldown._hideNumbers, true, "built-in countdown numbers hidden")
    eq(heal.hotkey._shown, false, "hotkey hidden when unbound")
    eq(#W.violations, 0, "no protected calls in lockdown")

    W.Hover(heal)
    check(W.TooltipText():find("No healing potion in your bags", 1, true), "empty potion tooltip text")
    check(W.TooltipText():find("Shift%-drag to move"), "tooltip hint line")
    heal._scripts.OnLeave(heal)
    W.Hover(food)
    check(W.TooltipText():find("No food in your bags", 1, true), "empty food tooltip text")
    food._scripts.OnLeave(food)

    W.SetBags({ { 118, 3 }, { 858, 2 } })
    local scansBefore = W.scans
    for _ = 1, 5 do W.Fire("BAG_UPDATE_DELAYED") end
    W.NextFrame()
    eq(W.scans - scansBefore, 1, "event burst -> one scan")
    eq(heal.icon._texture, "icon:858", "Lesser chosen")
    eq(heal.count._text, "2", "count of Lesser")
    eq(heal._attrs["*type1"], "macro", "potion type macro")
    eq(heal._attrs["*macrotext1"], "/use item:858\n/use item:118", "macro lists Lesser then Minor")
    W.Hover(heal)
    local tip = W.TooltipText()
    local lesserAt, minorAt = tip:find("Lesser Healing Potion  x2  (140-180)", 1, true), tip:find("Minor Healing Potion  x3  (70-90)", 1, true)
    check(lesserAt and minorAt and lesserAt < minorAt, "tooltip lists Lesser above Minor:\n" .. tip)
    check(tip:find("> Lesser", 1, true), "used entry marked")
    heal._scripts.OnLeave(heal)
    eq(W.env.GameTooltip._shown, false, "tooltip hidden on leave")

    W.SetBags({ { 118, 3 }, { 858, 2 }, { 929, 4 }, { 4540, 5 }, { 159, 5 }, { 1251, 5 }, { 5512, 1 },
                { 12662, 2 }, { 99002, 1 }, { 2589, 10 }, { 17348, 2 }, { 2455, 1 }, { 2456, 2 }, { 99004, 1 } })
    W.BagChanged()
    eq(heal.icon._texture, "icon:929", "switches to Healing Potion without reload")
    eq(heal._attrs["*macrotext1"], "/use item:929\n/use item:858\n/use item:2456\n/use item:118", "healing macro")
    eq(mana._attrs["*macrotext1"], "/use item:2455\n/use item:2456", "mana macro includes rejuvenation")
    eq(W.Ids("health"), "929,858,2456,118,17348", "health ranking; unusable draught last; no food")
    eq(W.Ids("mana"), "2455,2456", "mana ranking; no runes, no drink")
    eq(W.Ids("food"), "4540", "bread on the food button; bandage and tonic ignored")
    eq(W.Ids("drink"), "159", "water on the drink button")

    W.Click(heal)
    eq(W.used[#W.used], 929, "plain click uses top potion")
    eq(#W.used, 1, "exactly one potion per press")
    eq(#W.errors, 3, "trade-off: later macro lines report not ready")
    local usedBefore = #W.used
    W.cooldown = nil
    eq(W.Click(heal, { shift = true }), nil, "shift-click resolves to no action")
    eq(W.Click(heal, { shift = true, alt = true }), nil, "alt-shift-click resolves to no action")
    eq(#W.used, usedBefore, "shift-click used nothing")
    W.Click(heal, { ctrl = true })
    eq(#W.used, usedBefore + 1, "ctrl-click still uses a potion")

    W.cooldown = { start = W.time, duration = 120 }
    W.Fire("BAG_UPDATE_COOLDOWN")
    check(heal.cooldown._cd and mana.cooldown._cd, "swipe on both potion buttons")
    eq(food.cooldown._cd, nil, "potion cooldown not shown on food")
    W.NextFrame(0.11)
    eq(heal.timer._text, "1:59", "m:ss format")
    eq(mana.timer._text, heal.timer._text, "same timer on both potion buttons")
    W.Advance(120 - 45.5 - 0.11)
    eq(heal.timer._text, "45", "whole seconds")
    W.Advance(43)
    check(heal.timer._text and heal.timer._text:find("^%d%.%d$"), "one decimal under 3 s: " .. tostring(heal.timer._text))
    W.Advance(3)
    check(heal.timer._text == nil or heal.timer._text == "", "text cleared when done")
    local tickerRunning = false
    for _, o in ipairs(W.objects) do if o._kind == "Frame" and o._scripts.OnUpdate and o._shown and o._name == nil and o._parent == nil then tickerRunning = true end end
    check(not tickerRunning, "ticker stops when no cooldown runs")
    heal.cooldown._cd = nil
    W.gcd = W.time
    W.Fire("BAG_UPDATE_COOLDOWN")
    eq(heal.cooldown._cd, nil, "GCD ignored")
    W.gcd = nil

    W.bindings["CLICK PotionMixerHealingButton:LeftButton"] = "SHIFT-1"
    W.bindings["CLICK PotionMixerFoodButton:LeftButton"] = "F"
    W.Fire("UPDATE_BINDINGS")
    eq(heal.hotkey._text, "s-1", "hotkey abbreviated"); eq(heal.hotkey._shown, true, "hotkey shown")
    eq(food.hotkey._text, "F", "food hotkey shown")
    W.bindings["CLICK PotionMixerHealingButton:LeftButton"] = nil
    W.Fire("UPDATE_BINDINGS")
    eq(heal.hotkey._shown, false, "hotkey hidden after unbind")

    -- dragging the potion pair
    heal._scripts.OnDragStart(heal)
    eq(group._moving, nil, "plain drag does not move")
    W.mods.shift = true
    mana._scripts.OnEnter(mana)
    eq(mana.moveCue._shown, true, "shift+hover cue on hovered button")
    eq(heal.moveCue._shown, true, "shift+hover cue on the other button too")
    eq(food.moveCue._shown, false, "no cue on the other pair")
    mana._scripts.OnDragStart(mana)
    eq(group._moving, true, "shift-drag on mana moves the potion holder")
    eq(foodGroup._moving, nil, "food holder does not move")
    eq(heal._attrs["*type1"], "", "healing suspended while moving")
    eq(mana._attrs["*type1"], "", "mana suspended while moving")
    eq(food._attrs["*type1"], "item", "food not suspended by a potion move")
    W.mods.shift = false
    eq(W.Click(heal), nil, "click during move uses nothing (healing)")
    group._center = { 1100, 300 }
    mana._scripts.OnDragStop(mana)
    eq(group._moving, false, "move stopped")
    eq(group._userPlaced, false, "SetUserPlaced(false)")
    local pos = W.ns.db.layout.potions
    eq(pos.point .. pos.relativePoint .. pos.x .. "," .. pos.y, "CENTERCENTER140,-240", "potion pair position saved")
    eq(W.ns.db.layout.food.y, -233, "food pair position untouched")
    eq(group._point[4] .. "," .. group._point[5], "140,-240", "holder re-anchored to saved position")
    eq(heal._attrs["*type1"], "", "still suspended in the same frame")
    W.NextFrame()
    eq(heal._attrs["*type1"], "macro", "healing restored next frame")
    eq(mana._attrs["*type1"], "macro", "mana restored next frame")
    mana._scripts.OnLeave(mana)
    eq(heal.moveCue._shown, false, "cue off after leaving")

    -- reset
    W.EnterCombat()
    W.env.SlashCmdList.POTIONMIXER("reset")
    check(W.printed[#W.printed]:find("in combat"), "reset refused in combat")
    eq(W.ns.db.layout.potions.x, 140, "position unchanged by refused reset")
    W.LeaveCombat()
    W.env.SlashCmdList.POTIONMIXER("reset")
    eq(group._point[4], 0, "reset x"); eq(group._point[5], -180, "reset y")
    W.env.SlashCmdList.POTIONMIXER("")
    check(W.printed[#W.printed - 4]:find("commands"), "help text")
    W.env.SlashCmdList.POTIONMIXER("list")
    local listed = table.concat(W.printed, "\n")
    check(listed:find("> Healing Potion x", 1, true) and listed:find("[tooltip]", 1, true), "list shows top and source")
    check(listed:find("food:", 1, true) and listed:find("Tough Hunk of Bread x5 (61.2) [tooltip]", 1, true), "list shows food:\n" .. listed)

    eq(#W.violations, 0, "no protected calls in lockdown (flow 2)")
    local unknown = {}
    for k in pairs(W.unknownMethods) do unknown[#unknown + 1] = k end
    eq(table.concat(unknown, ","), "", "no unmodelled widget methods used")
end

---------------------------------------------------------------------------
-- 3. Potions in combat: stack runs out, fall-through, deferred attributes
---------------------------------------------------------------------------
do
    local W = NewWorld()
    W.Login()
    local heal = W.Button("healing")
    W.SetBags({ { 929, 1 }, { 858, 2 } })
    W.BagChanged()
    local macroBefore = heal._attrs["*macrotext1"]
    W.EnterCombat()
    W.mods.shift = true
    heal._scripts.OnDragStart(heal)
    eq(heal._parent._moving, nil, "no move in combat")
    W.mods.shift = false
    W.Click(heal)
    eq(W.used[#W.used], 929, "combat: uses top")
    eq(heal.icon._texture, "icon:858", "icon follows bags in combat")
    eq(heal._attrs["*macrotext1"], macroBefore, "attributes unchanged in combat")
    W.cooldown = nil
    W.Click(heal)
    eq(W.used[#W.used], 858, "combat: falls through to next-best potion")
    eq(#W.violations, 0, "no protected calls during combat")
    W.LeaveCombat()
    eq(heal._attrs["*macrotext1"], "/use item:858", "attributes rebuilt after combat")

    W.mods.shift = true
    heal._scripts.OnDragStart(heal)
    W.mods.shift = false
    W.EnterCombat()
    eq(heal._parent._moving, false, "move stopped at combat start")
    eq(heal._attrs["*type1"], "macro", "healing restored at combat start")
    eq(W.Button("mana")._attrs["*type1"], "macro", "mana restored at combat start")
    heal._scripts.OnDragStop(heal)
    W.NextFrame()
    eq(#W.violations, 0, "no protected calls after mid-drag combat")
    W.LeaveCombat()
end

---------------------------------------------------------------------------
-- 4. Food and drink
---------------------------------------------------------------------------
do
    local W = NewWorld({ level = 50 })
    W.Login()
    local food, drink, heal = W.Button("food"), W.Button("drink"), W.Button("healing")
    W.SetBags({ { 8950, 3 }, { 8076, 2 }, { 13724, 1 }, { 20452, 4 }, { 21023, 2 }, { 4540, 5 },
                { 8766, 6 }, { 8079, 4 }, { 159, 10 }, { 99004, 1 }, { 1251, 5 }, { 929, 2 } })
    W.BagChanged()
    eq(W.Ids("food"), "8076,13724,8950,4540,21023,20452", "food: conjured first on ties, buff food last")
    eq(W.Ids("drink"), "13724,8766,159,8079", "drink: most mana first, too-high level last")
    eq(W.Ids("health"), "929", "food never on the healing button")
    eq(food._attrs["*type1"], "item", "food uses item mode")
    eq(food._attrs["*item1"], "item:8076", "food item attribute")
    eq(food._attrs["*macrotext1"], nil, "food has no macro")
    eq(drink._attrs["*item1"], "item:13724", "drink item attribute")
    eq(food.icon._texture, "icon:8076", "food icon"); eq(food.count._text, "2", "food count")
    eq(W.ns.lastRankings.food.top.conjured, true, "conjured flag from the tooltip line")

    W.Hover(food)
    local tip = W.TooltipText()
    check(tip:find("> Conjured Sweet Roll  x2  (2065)  conjured", 1, true), "tooltip marks conjured top:\n" .. tip)
    check(tip:find("Smoked Desert Dumplings  x4  (2065)  Well Fed", 1, true), "tooltip tags buff food")
    local breadAt, dumplingsAt = tip:find("Tough Hunk of Bread  x5  (61.2)", 1, true), tip:find("Smoked Desert", 1, true)
    check(breadAt and dumplingsAt and breadAt < dumplingsAt, "plain food listed above buff food")
    food._scripts.OnLeave(food)
    W.Hover(drink)
    check(W.TooltipText():find("Conjured Crystal Water  x4  (4038)  conjured  - Requires Level 55", 1, true), "too-high drink greyed with reason:\n" .. W.TooltipText())
    drink._scripts.OnLeave(drink)

    W.Click(food)
    eq(#W.used, 1, "one click eats exactly one food")
    eq(W.used[1], 8076, "ate the top food")
    eq(#W.errors, 0, "no error messages from food")
    eq(food.count._text, "1", "count follows")
    W.Click(food)
    eq(W.used[2], 8076, "ate the last conjured roll")
    eq(food._attrs["*item1"], "item:13724", "falls to the next food out of combat right away")

    -- potion cooldown leaves food alone
    W.Click(heal)
    check(heal.cooldown._cd ~= nil, "potion cooldown shown on potions")
    eq(food.cooldown._cd, nil, "and not on food")
    W.cooldown = nil

    -- combat: can't eat, but the buttons keep showing what you'll eat afterwards
    W.EnterCombat()
    W.SetBags({ { 13724, 1 }, { 8950, 3 }, { 20452, 4 }, { 8766, 6 }, { 159, 10 }, { 8950, 2 } })
    W.BagChanged()
    eq(food.icon._texture, "icon:13724", "combat: food button keeps its top food")
    eq(food.icon._desat, false, "combat: not shown as empty")
    eq(W.Ids("food"), "13724,8950,20452", "combat ranking keeps usability from before combat")
    local before = #W.used
    W.Click(food)
    eq(#W.used, before, "combat: food can't be eaten")
    eq(#W.violations, 0, "no protected calls with food in combat")
    W.LeaveCombat()
    eq(food._attrs["*item1"], "item:13724", "food attribute after combat")

    -- moving the food pair
    W.mods.shift = true
    drink._scripts.OnEnter(drink)
    eq(food.moveCue._shown, true, "food pair cue")
    eq(heal.moveCue._shown, false, "no cue on the potion pair")
    drink._scripts.OnDragStart(drink)
    local foodGroup = food._parent
    eq(foodGroup._moving, true, "shift-drag moves the food holder")
    eq(heal._parent._moving, nil, "potion holder stays")
    eq(food._attrs["*type1"], "", "food suspended while moving")
    eq(heal._attrs["*type1"], "macro", "potions not suspended by a food move")
    W.mods.shift = false
    foodGroup._center = { 700, 800 }
    drink._scripts.OnDragStop(drink)
    local pos = W.ns.db.layout.food
    eq(pos.x .. "," .. pos.y, "-260,260", "food pair position saved")
    eq(W.ns.db.layout.potions.y, -180, "potion pair position untouched")
    W.NextFrame()
    eq(food._attrs["*type1"], "item", "food restored next frame")
    drink._scripts.OnLeave(drink)
    W.env.SlashCmdList.POTIONMIXER("reset")
    eq(foodGroup._point[4] .. "," .. foodGroup._point[5], "0,-233", "reset moves the food pair back")
    eq(#W.violations, 0, "violations (food)")
end
do -- SAVE_BUFF_FOOD = false: buff food ranks by amount like everything else
    local W = NewWorld({ level = 50, patches = { ["Potions.lua"] = { { "local SAVE_BUFF_FOOD = true", "local SAVE_BUFF_FOOD = false" } } } })
    W.Login()
    W.SetBags({ { 8950, 3 }, { 21023, 2 }, { 20452, 1 } })
    W.BagChanged()
    eq(W.Ids("food"), "21023,20452,8950", "buff food by amount when SAVE_BUFF_FOOD is off (tie: higher item level)")
end
do -- an unknown Forever food, found through its tooltip
    local W = NewWorld({ uncached = { 99003 } })
    W.Login()
    W.SetBags({ { 99003, 2 }, { 8950, 1 } })
    W.BagChanged()
    eq(W.Ids("food"), "8950", "uncached food not offered yet")
    W.cached[99003] = true
    W.Fire("GET_ITEM_INFO_RECEIVED", 99003, true)
    W.NextFrame()
    eq(W.ns.lastRankings.food.top.itemID, 99003, "unknown food found after item info arrives")
    eq(W.ns.lastRankings.food.top.max, 3500, "thousands separator in food")
    eq(W.ns.lastRankings.food.top.source, "tooltip", "food amount from tooltip")
end

---------------------------------------------------------------------------
-- 5. Levels, item cache, deDE, fallbacks
---------------------------------------------------------------------------
do
    local W = NewWorld({ level = 10, uncached = { 99001 } })
    W.Login()
    local heal = W.Button("healing")
    W.SetBags({ { 13446, 2 }, { 118, 1 }, { 99001, 1 } })
    W.BagChanged()
    eq(heal.icon._texture, "icon:118", "level 10: Major not chosen")
    eq(heal._attrs["*macrotext1"], "/use item:118", "unusable potions not in macro")
    check(W.ns.Potions.IsPending(99001), "uncached unknown item is pending")
    W.Hover(heal)
    check(W.TooltipText():find("Major Healing Potion  x2  (1050-1750)  - Requires Level 45", 1, true), "greyed entry with reason:\n" .. W.TooltipText())
    W.cached[99001] = true
    W.Fire("GET_ITEM_INFO_RECEIVED", 99001, true)
    W.NextFrame()
    check(not W.ns.Potions.IsPending(99001), "no longer pending after item info")
    eq(heal.icon._texture, "icon:118", "level 10: new potion (req 20) found but not chosen")
    W.level = 25
    W.Fire("PLAYER_LEVEL_UP", 25)
    W.NextFrame()
    eq(heal.icon._texture, "icon:99001", "new Forever potion chosen after level-up")
    eq(W.ns.lastRankings.health.top.source, "tooltip", "amount source is tooltip")
    eq(W.ns.lastRankings.health.top.max, 2400, "thousands separator parsed")
end
do
    local W = NewWorld({ locale = "de", level = 50 })
    W.Login()
    W.SetBags({ { 13446, 1 }, { 2456, 1 }, { 4540, 3 }, { 8076, 1 }, { 20452, 1 }, { 13724, 1 }, { 1179, 2 } })
    W.BagChanged()
    local top = W.ns.lastRankings.health.top
    eq(top.itemID, 13446, "deDE: Major chosen"); eq(top.source, "tooltip", "deDE: amounts from tooltip"); eq(top.max, 1750, "deDE: 1.750 parsed")
    eq(#W.ns.lastRankings.health.entries, 2, "deDE: food not on the healing button")
    eq(W.Ids("food"), "8076,13724,4540,20452", "deDE food: conjured, biscuit, bread, then buff food")
    eq(W.ns.lastRankings.food.top.conjured, true, "deDE conjured line detected")
    eq(W.Ids("drink"), "13724,1179", "deDE drink incl. 'insgesamt' wording")
end
for _, loc in ipairs({ "fr", "es" }) do
    local W = NewWorld({ locale = loc, level = 50 })
    W.Login()
    W.SetBags({ { 13446, 1 }, { 2456, 1 }, { 4596, 2 }, { 4540, 3 }, { 8076, 1 }, { 20452, 1 }, { 21023, 1 },
                { 13724, 1 }, { 1179, 2 }, { 8766, 1 }, { 1251, 5 }, { 12662, 1 }, { 99002, 1 }, { 5512, 1 }, { 99004, 1 } })
    W.BagChanged()
    eq(W.Ids("health"), "13446,4596,2456", loc .. ": healing potions")
    eq(W.Ids("mana"), "2456", loc .. ": mana potions (no runes)")
    eq(W.Ids("food"), "8076,13724,4540,21023,20452", loc .. ": food (conjured, biscuit, bread, then buff food)")
    eq(W.Ids("drink"), "13724,8766,1179", loc .. ": drink")
    eq(W.ns.lastRankings.health.top.source, "tooltip", loc .. ": potion amounts from tooltip")
    eq(W.ns.lastRankings.food.top.conjured, true, loc .. ": conjured line detected")
    eq(W.ns.lastRankings.food.entries[4].wellFed, true, loc .. ": Dirge's chops counted as buff food")
    eq(W.Button("food")._attrs["*item1"], "item:8076", loc .. ": food attribute")
    eq(#W.violations, 0, loc .. ": violations")
end
do -- a French low-level character: the client's own "requires level" text
    local W = NewWorld({ locale = "fr", level = 10 })
    W.Login()
    W.SetBags({ { 13446, 1 }, { 118, 1 } })
    W.BagChanged()
    W.Hover(W.Button("healing"))
    check(W.TooltipText():find("Niveau 45 requis", 1, true), "frFR level reason in tooltip:\n" .. W.TooltipText())
end
do
    local W = NewWorld({ noTooltipInfo = true })
    W.Login()
    W.SetBags({ { 99001, 1 }, { 118, 1 }, { 8076, 1 } })
    W.BagChanged()
    eq(W.ns.lastRankings.health.top and W.ns.lastRankings.health.top.itemID, 99001, "GameTooltip scanner fallback finds unknown potion")
    eq(W.ns.lastRankings.food.top and W.ns.lastRankings.food.top.conjured, true, "scanner fallback sees the conjured line")
end
do
    local W = NewWorld({ noTimer = true })
    W.Login()
    W.SetBags({ { 118, 1 } })
    W.Fire("BAG_UPDATE_DELAYED")
    W.NextFrame(); W.NextFrame()
    for _, o in ipairs(W.objects) do if o._kind == "Frame" and o._scripts.OnUpdate and o._shown then o._scripts.OnUpdate(o, 0.016) end end
    eq(W.Button("healing").icon._texture, "icon:118", "works without C_Timer")
end

---------------------------------------------------------------------------
-- 6. Login in combat; missing API; macro length; item mode; saved data
---------------------------------------------------------------------------
do
    local W = NewWorld()
    W.lockdown = true
    W.Fire("ADDON_LOADED", "PotionMixer"); W.Fire("PLAYER_LOGIN"); W.NextFrame()
    eq(W.env.PotionMixerHealingButton, nil, "no buttons created in combat")
    eq(#W.violations, 0, "no protected calls on combat login")
    W.LeaveCombat()
    check(W.env.PotionMixerHealingButton ~= nil and W.env.PotionMixerFoodButton ~= nil, "buttons created after combat")
end
do
    local W = NewWorld({ noContainer = true })
    W.Login()
    eq(W.env.PotionMixerHealingButton, nil, "missing API: no buttons")
    eq(#W.printed, 1, "missing API: exactly one message")
    check(W.printed[1] and W.printed[1]:find("GetContainerNumSlots"), "message names the API: " .. tostring(W.printed[1]))
end
do
    local W = NewWorld()
    for i = 1, 30 do
        local id = 70000 + i
        ITEMS[id] = { name = "Test Potion " .. i, class = 0, ilvl = i, req = 0, potion = true,
                      en = "Use: Restores " .. (i * 100) .. " to " .. (i * 100 + 50) .. " health." }
    end
    for id in pairs(ITEMS) do W.cached[id] = true end
    W.Login()
    local list = {}
    for i = 1, 30 do list[i] = { 70000 + i, 1 } end
    W.SetBags(list)
    W.BagChanged()
    local text = W.Button("healing")._attrs["*macrotext1"]
    check(#text <= 255, "macrotext within 255 chars (" .. #text .. ")")
    eq(text:match("^/use item:(%d+)"), "70030", "strongest first")
    check(not text:find("70001", 1, true), "weakest dropped")
end
do -- ACTION_MODE = "item" for potions (the documented one-line switch)
    local W = NewWorld({ patches = { ["Buttons.lua"] = { { 'local ACTION_MODE = "macro"', 'local ACTION_MODE = "item"' } } } })
    W.Login()
    local heal = W.Button("healing")
    W.SetBags({ { 929, 1 }, { 858, 2 } })
    W.BagChanged()
    eq(heal._attrs["*type1"], "item", "item mode: type")
    eq(heal._attrs["*item1"], "item:929", "item mode: top item")
    eq(heal._attrs["*macrotext1"], nil, "item mode: no macrotext")
    W.Click(heal)
    eq(W.used[1], 929, "item mode: uses top"); eq(#W.errors, 0, "item mode: no extra errors")
    eq(W.Click(heal, { shift = true }), nil, "item mode: shift-click no action")
    W.Hover(heal)
    W.env.GameTooltip._lines = { "Lesser Healing Potion" } -- client rebuilt the item tooltip
    W.Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    check(W.TooltipText():find("Shift%-drag to move"), "tooltip redrawn after modifier change")
    W.env.SlashCmdList.POTIONMIXER("bogus")
    check(W.printed[#W.printed - 4]:find("commands"), "unknown command prints help")
end
do -- pre-release per-button positions are dropped
    local W = NewWorld({ savedDB = { positions = { healing = { point = "CENTER", relativePoint = "CENTER", x = 5, y = 5 } } } })
    W.Login()
    eq(W.env.PotionMixerDB.positions, nil, "old per-button positions removed")
    eq(W.env.PotionMixerDB.layout.potions.y, -180, "default potion position filled in")
end
do -- 1.0.0's single position becomes layout.potions
    local W = NewWorld({ savedDB = { position = { point = "CENTER", relativePoint = "CENTER", x = 50, y = 60 } } })
    W.Login()
    local db = W.env.PotionMixerDB
    eq(db.position, nil, "1.0.0 position key removed")
    eq(db.layout.potions.x .. "," .. db.layout.potions.y, "50,60", "1.0.0 potion position kept")
    eq(db.layout.food.y, -233, "food pair gets its default")
    local holder = W.Button("healing")._parent
    eq(holder._point[4] .. "," .. holder._point[5], "50,60", "potion pair placed where it was")
    eq(#W.violations, 0, "violations (migration)")
end

---------------------------------------------------------------------------
-- 7. Spell data not loaded yet: the "[data]" seen on deDE and esES clients
---------------------------------------------------------------------------
do
    local waiting = { 929, 3385, 2455, 4540, 159, 99003, 20452 }
    local W = NewWorld({ locale = "de", level = 50, uncachedSpells = waiting })
    W.Login()
    W.SetBags({ { 929, 1 }, { 3385, 2 }, { 2455, 1 }, { 4540, 1 }, { 159, 22 }, { 99003, 1 }, { 20452, 1 } })
    W.BagChanged()
    eq(W.Ids("health"), "929", "spell not loaded: known potion from Data.lua meanwhile")
    eq(W.ns.lastRankings.health.top.source, "data", "spell not loaded: amounts from Data.lua meanwhile")
    eq(W.Ids("food"), "4540", "spell not loaded: unknown and buff food not offered yet")
    check((W.spellRequests[50929] or 0) >= 1, "spell load requested")
    for _, id in ipairs(waiting) do W.LoadSpell(id, true) end
    W.NextFrame()
    eq(W.ns.lastRankings.health.top.source, "tooltip", "spell loaded: amounts from the tooltip")
    eq(W.Ids("mana"), "3385,2455", "spell loaded: mana potions")
    eq(W.Ids("food"), "99003,4540,20452", "spell loaded: unknown food and buff food found")
    eq(W.ns.lastRankings.drink.top.source, "tooltip", "spell loaded: drink from the tooltip")
end
do -- a spell that never loads: a few requests, no endless rescans, then Data.lua
    local W = NewWorld({ uncachedSpells = { 929 } })
    W.Login()
    W.SetBags({ { 929, 1 } })
    W.BagChanged()
    local scans = W.scans
    for _ = 1, 10 do W.LoadSpell(929, false); W.NextFrame() end
    check(W.scans - scans <= 4, "failed spell loads cause at most a few rescans (" .. (W.scans - scans) .. ")")
    check((W.spellRequests[50929] or 0) <= 3, "spell requested at most 3 times")
    eq(W.ns.lastRankings.health.top.source, "data", "falls back to Data.lua")
end

---------------------------------------------------------------------------
-- 8. /pmix tooltip
---------------------------------------------------------------------------
do
    ITEMS[99005] = { name = "Grammar Potion", class = 0, ilvl = 10, req = 0, potion = true,
                     en = "Use: Restores |cffffffff280|r to 360 health.",
                     de = "Benutzen: Stellt 280 bis 360 |4Punkt:Punkte; Gesundheit wieder her." }
    local W = NewWorld({ locale = "de" })
    W.Login()
    local n = #W.printed
    W.env.SlashCmdList.POTIONMIXER("tooltip |cffffffff|Hitem:929::::::::60:::::|h[Heiltrank]|h|r")
    local out = table.concat(W.printed, "\n", n + 1)
    check(out:find("item 929, spell 50929 (loaded):", 1, true), "tooltip: header from an item link:\n" .. out)
    check(out:find("Benutzen: Stellt 280 bis 360 Punkt(e) Gesundheit wieder her.", 1, true), "tooltip: raw use line")
    check(out:find("-> instant, health 280-360", 1, true), "tooltip: how the line is read")
    n = #W.printed
    W.env.SlashCmdList.POTIONMIXER("tooltip 99005")
    out = table.concat(W.printed, "\n", n + 1)
    check(out:find("||4Punkt:Punkte;", 1, true), "tooltip: escape codes shown:\n" .. out)
    check(out:find("-> instant, health 280-360", 1, true), "tooltip: escape codes handled")
    n = #W.printed
    W.env.SlashCmdList.POTIONMIXER("tooltip 8076")
    out = table.concat(W.printed, "\n", n + 1)
    check(out:find("-> conjured", 1, true) and out:find("-> seated, health 2065", 1, true), "tooltip: food and conjured line:\n" .. out)
    W.env.SlashCmdList.POTIONMIXER("tooltip")
    check(W.printed[#W.printed]:find("Verwendung: /pmix tooltip", 1, true), "tooltip: usage message, translated")
end
do
    local W = NewWorld({ uncachedSpells = { 929 } })
    W.Login()
    W.env.SlashCmdList.POTIONMIXER("tooltip 929")
    check(table.concat(W.printed, "\n"):find("not loaded yet", 1, true), "tooltip: says when the spell isn't loaded")
    check((W.spellRequests[50929] or 0) >= 1, "tooltip: asks for the spell")
end

---------------------------------------------------------------------------
-- 9. The addon's own texts in German, French and Spanish
---------------------------------------------------------------------------
eq(FILES[1], "Locales.lua", "Locales.lua loads first")
do -- every translation has exactly the English keys, with the same placeholders
    local W = NewWorld()
    local english, translations = W.ns.L, W.ns.TRANSLATIONS
    local function Placeholders(text) local n = 0 for _ in text:gmatch("%%s") do n = n + 1 end return n end
    for _, code in ipairs({ "deDE", "frFR", "esES", "esMX" }) do
        local t = translations[code] or {}
        for key, text in pairs(english) do
            check(type(t[key]) == "string" and t[key] ~= "", code .. ": has " .. key)
            if t[key] then eq(Placeholders(t[key]), Placeholders(text), code .. ": placeholders in " .. key) end
        end
        for key in pairs(t) do check(english[key] ~= nil, code .. ": unknown key " .. key) end
    end
    eq(W.env["BINDING_NAME_CLICK PotionMixerFoodButton:LeftButton"], "Use best food", "enUS binding name")
end
local LOCALIZED = {
    de = { binding = "Besten Heiltrank benutzen", empty = "Kein Heiltrank in Euren Taschen.", hint = "Umschalt-Ziehen zum Verschieben",
           help = "Befehle:", keys = "Tastaturbelegung > AddOns > Potion Mixer", heading = "Heiltränke:", source = "[Tooltip]", wellFed = "Satt" },
    fr = { binding = "Utiliser la meilleure potion de soins", empty = "Aucune potion de soins dans vos sacs.", hint = "Maj-glisser pour déplacer",
           help = "commandes :", keys = "Raccourcis > AddOns > Potion Mixer", heading = "potions de soins :", source = "[données]", wellFed = "Bien nourri" },
    es = { binding = "Usar la mejor poción de curación", empty = "No llevas pociones de curación en las bolsas.", hint = "Mayús + arrastrar para mover",
           help = "comandos:", keys = "Asignación de teclas > Accesorios > Potion Mixer", heading = "pociones de curación:", source = "[datos]", wellFed = "Bien alimentado" },
}
for loc, want in pairs(LOCALIZED) do
    local W = NewWorld({ locale = loc, level = 50 })
    W.Login()
    local heal = W.Button("healing")
    eq(W.env["BINDING_NAME_CLICK PotionMixerHealingButton:LeftButton"], want.binding, loc .. ": binding name")
    W.Hover(heal)
    check(W.TooltipText():find(want.empty, 1, true), loc .. ": empty tooltip text:\n" .. W.TooltipText())
    check(W.TooltipText():find(want.hint, 1, true), loc .. ": move hint")
    heal._scripts.OnLeave(heal)
    W.env.SlashCmdList.POTIONMIXER("")
    local help = table.concat(W.printed, "\n")
    check(help:find(want.help, 1, true) and help:find(want.keys, 1, true), loc .. ": help names the client's own menus:\n" .. help)
    -- 929 has no fr/es text in this harness, so there it comes from Data.lua
    W.SetBags({ { 929, 1 }, { 20452, 1 } })
    W.BagChanged()
    W.env.SlashCmdList.POTIONMIXER("list")
    local list = table.concat(W.printed, "\n")
    check(list:find(want.heading, 1, true), loc .. ": list heading:\n" .. list)
    check(list:find(want.source, 1, true), loc .. ": source name")
    check(list:find(want.wellFed, 1, true), loc .. ": Well Fed tag")
    W.Hover(W.Button("food"))
    check(W.TooltipText():find(want.wellFed, 1, true), loc .. ": Well Fed tag in the tooltip")
end
do
    local W = NewWorld({ locale = "es", localeCode = "esMX" })
    W.Login()
    eq(W.env["BINDING_NAME_CLICK PotionMixerDrinkButton:LeftButton"], "Usar la mejor bebida", "esMX binding name")
    eq(W.env["BINDING_NAME_CLICK PotionMixerHealingButton:LeftButton"], "Usar la mejor poción de sanación", "esMX uses the game's term 'sanación'")
    W.Hover(W.Button("healing"))
    check(W.TooltipText():find("No tienes pociones de sanación en tus bolsas.", 1, true), "esMX: Latin American tooltip text:\n" .. W.TooltipText())
    W.env.SlashCmdList.POTIONMIXER("")
    check(table.concat(W.printed, "\n"):find("regresa los dos pares de botones", 1, true), "esMX: Latin American help text")
end

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
