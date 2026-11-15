-- Free Bars - options window (/fb)

local ADDON, ns = ...
local UI = LibStub("LibFreeUI-1.0")
local C = UI.C
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

local scope = "global"          -- "global" or bar number
local needReload = false

local cards = { { title = "General", state = function() return ns.conflict and "Paused" or "Fonts, style" end,
                  selected = function() return scope == "global" end, onClick = function() scope = "global" end } }
for i = 1, ns.NUM do
    cards[#cards + 1] = {
        title = "Bar " .. i,
        state = function()
            local c = ns.Bar(i); if not c then return "" end
            if not c.enable then return "Off" end
            return c.layout == "ARC" and (c.buttons .. " · arc") or (c.buttons .. " buttons")
        end,
        on = function() local c = ns.Bar(i); return c and c.enable end,
        selected = function() return scope == i end,
        onClick = function() scope = i end,
    }
end

local kit = UI:New({ name = "FreeBarsOptions", title = "Free Bars", sub = "Action bars", addon = ADDON,
                     icon = MEDIA .. "icon", circle = MEDIA .. "circle", shadow = MEDIA .. "shadow", w = 1000, h = 660, row = 36,
                     cards = cards,
                     tabs = { { "layout", "Layout" }, { "look", "Look" }, { "general", "General" }, { "profiles", "Profiles" } },
                     tabShown = function(key)
                         if scope == "global" then return key == "general" or key == "profiles" end
                         return key == "layout" or key == "look"
                     end,
                     subFn = function()
                         if ns.conflict then return "  ·  |cffff6b61paused: " .. ns.conflict .. " draws the bars|r" end
                         return "  ·  Profile: " .. ((ns.profiles and ns.profiles:Current()) or "Default")
                     end })

local function Bar() return type(scope) == "number" and ns.Bar(scope) end
local function BGet(k) return function() local c = Bar(); return c and c[k] end end
local function BSet(k) return function(v) local c = Bar(); if c then c[k] = v; ns.UpdateBar(scope); kit:Refresh() end end end
local function GGet(k) return function() local g = ns.Global(); return g and g[k] end end
local function GSet(k, reload) return function(v)
    local g = ns.Global(); if not g then return end
    g[k] = v
    if reload then needReload = true end
    ns.UpdateAll(); kit:Refresh()
end end
local function Pct(get) return function() return math.floor((get() or 0) * 100 + 0.5) end end
local function FromPct(set) return function(v) set(v / 100) end end

-- fonts: the saved value is a LibFreeMedia key ("ARIALN") or, in older settings, a file path ("Fonts\\ARIALN.TTF")
local function FontKey()
    local v = (ns.Global() or {}).font
    local LFM = LibStub("LibFreeMedia-1.0", true)
    if LFM and type(v) == "string" then
        local norm = v:gsub("/", "\\"):lower()
        for _, f in ipairs(LFM:ListFonts()) do
            if f.key == v or (f.path and f.path:gsub("/", "\\"):lower() == norm) then return f.key end
        end
    end
    return v
end

-- colour swatch (the game's colour picker, modern API guarded); field = key of the bar settings holding { r, g, b, a }
local function OpenColorPicker(r, g, b, a, onChange)
    local CPF = ColorPickerFrame
    if not CPF then return end
    local function current()
        local nr, ng, nb = CPF:GetColorRGB()
        local na = a
        if CPF.GetColorAlpha then na = CPF:GetColorAlpha() elseif OpacitySliderFrame then na = 1 - OpacitySliderFrame:GetValue() end
        return nr, ng, nb, na
    end
    local info = {
        r = r, g = g, b = b, opacity = a, hasOpacity = true,
        swatchFunc = function() onChange(current()) end,
        opacityFunc = function() onChange(current()) end,
        cancelFunc = function() onChange(r, g, b, a) end,
    }
    if CPF.SetupColorPickerAndShow then
        CPF:SetupColorPickerAndShow(info)
    else
        CPF.func, CPF.opacityFunc, CPF.cancelFunc = info.swatchFunc, info.opacityFunc, info.cancelFunc
        CPF.hasOpacity, CPF.opacity = true, 1 - (a or 1)
        CPF:SetColorRGB(r, g, b)
        CPF:Hide(); CPF:Show()
    end
end

local function Build()
    local pages, footer = kit:Build()
    local LX, RX, COLW, PAD = kit.LX, kit.RX, kit.COLW, kit.PAD
    local function y(i) return kit:Y(i) end

    -- ------------------------------------------------ Layout
    local p = pages.layout
    kit:Caption(p, "Bar", LX, 0)
    kit:SwitchRow(p, "Enabled", LX, y(1), COLW, BGet("enable"), BSet("enable"))
    kit:SliderRow(p, "Buttons", LX, y(2), COLW, BGet("buttons"), BSet("buttons"), { lo = 1, hi = 12, step = 1, min = 1, max = 12 })
    kit:SliderRow(p, "Button size", LX, y(3), COLW, BGet("size"), BSet("size"), { lo = 16, hi = 80, step = 1, min = 8 })
    kit:SliderRow(p, "Button height", LX, y(4), COLW, BGet("height"), BSet("height"), { lo = 0, hi = 80, step = 1, min = 0 })
    kit:SliderRow(p, "Spacing", LX, y(5), COLW, BGet("spacing"), BSet("spacing"), { lo = -1, hi = 20, step = 1 })
    kit:SliderRow(p, "Scale", LX, y(6), COLW, BGet("scale"), BSet("scale"), { lo = 0.5, hi = 2, step = 0.05, min = 0.2 })
    kit:Label(p, "Layout", LX, y(7) - 5)
    kit:Segmented(p, { { "GRID", "Grid" }, { "ARC", "Arc of a circle" } }, LX + 120, y(7), COLW - 120, BGet("layout"), BSet("layout"))
    kit:Hint(p, "Button height 0 = square buttons. Scale also grows the texts.", LX, y(8) + 6, COLW)
    local info = kit:Hint(p, "", LX, y(9), COLW)
    kit:OnRefresh(function() if type(scope) == "number" then info:SetText("|cffff9a4d" .. ns.BARS[scope].label .. "|r: " .. ns.BARS[scope].hint .. ".") end end)

    kit:Caption(p, "Grid", RX, 0)
    kit:SliderRow(p, "Buttons per row", RX, y(1), COLW, BGet("perRow"), BSet("perRow"), { lo = 1, hi = 12, step = 1, min = 1, max = 12 })
    kit:Label(p, "First button", RX, y(2) - 5)
    kit:Segmented(p, { { "TOPLEFT", "Top left" }, { "TOPRIGHT", "Top right" }, { "BOTTOMLEFT", "Bottom left" }, { "BOTTOMRIGHT", "Bottom right" } },
        RX + 120, y(2), COLW - 120, BGet("point"), BSet("point"))
    kit:Caption(p, "Arc of a circle", RX, y(3) - 4)
    kit:SliderRow(p, "Radius", RX, y(4) - 4, COLW, BGet("arcRadius"), BSet("arcRadius"), { lo = 20, hi = 600, step = 1, min = 10 })
    kit:SliderRow(p, "Arc size (%)", RX, y(5) - 4, COLW, BGet("arcPercent"), BSet("arcPercent"), { lo = 5, hi = 100, step = 1, min = 1, max = 100 })
    kit:SliderRow(p, "Rotation (deg)", RX, y(6) - 4, COLW, BGet("arcRotation"), BSet("arcRotation"), { lo = 0, hi = 359, step = 1 })
    kit:SwitchRow(p, "Other direction", RX, y(7) - 4, COLW, BGet("arcReverse"), BSet("arcReverse"))
    kit:Hint(p, "50% = half a circle, 100% = a full circle. Rotation is where the middle of the arc points: 90 = up (a rainbow), 270 = down (a smile), 0 = right, 180 = left.", RX, y(8), COLW)

    -- ------------------------------------------------ Look
    p = pages.look
    kit:Caption(p, "Look", LX, 0)
    kit:SliderRow(p, "Opacity (%)", LX, y(1), COLW, Pct(BGet("alpha")), FromPct(BSet("alpha")), { lo = 0, hi = 100, step = 5, min = 0, max = 100 })
    kit:SwitchRow(p, "Show on mouseover only", LX, y(2), COLW, BGet("mouseover"), BSet("mouseover"))
    kit:SliderRow(p, "Faded opacity (%)", LX, y(3), COLW, Pct(BGet("fadeAlpha")), FromPct(BSet("fadeAlpha")), { lo = 0, hi = 100, step = 5, min = 0, max = 100 })
    kit:SwitchRow(p, "Show empty buttons", LX, y(4), COLW, BGet("showGrid"), BSet("showGrid"))
    kit:SwitchRow(p, "Backdrop", LX, y(5), COLW, BGet("backdrop"), BSet("backdrop"))
    kit:SliderRow(p, "Backdrop padding", LX, y(6), COLW, BGet("backdropPad"), BSet("backdropPad"), { lo = 0, hi = 20, step = 1, min = 0 })

    -- background of the buttons that have no action (Flat style), with its opacity
    kit:Label(p, "Empty button color", LX, y(7) - 3)
    local sw = CreateFrame("Button", nil, p)
    sw:SetSize(46, 20)
    sw:SetPoint("TOPRIGHT", p, "TOPLEFT", LX + COLW, y(7))
    kit:Flow(sw, "TOPRIGHT", LX + COLW, y(7), nil, true)
    local chk = kit:Fill(sw, { 0.3, 0.3, 0.3, 1 }); chk:SetAllPoints()
    local fillT = kit:Fill(sw, { 0, 0, 0, 1 }, "ARTWORK"); fillT:SetPoint("TOPLEFT", 2, -2); fillT:SetPoint("BOTTOMRIGHT", -2, 2)
    kit:Border(sw, 0.15, "OVERLAY")
    sw:SetScript("OnEnter", function(self) kit:BorderColor(self, C.accent[1], C.accent[2], C.accent[3], 1) end)
    sw:SetScript("OnLeave", function(self) kit:BorderColor(self, 1, 1, 1, 0.15) end)
    sw:SetScript("OnClick", function()
        local c = Bar(); if not c then return end
        local e = c.emptyColor or { 0, 0, 0, 1 }
        local key = scope
        OpenColorPicker(e[1], e[2], e[3], e[4] or 1, function(r, g, bl, a)
            local bc = ns.Bar(key); if not bc then return end
            bc.emptyColor = { r, g, bl, a }
            ns.PaintEmptyBar(key); kit:Refresh()
        end)
    end)
    kit:OnRefresh(function() local c = Bar(); local e = c and c.emptyColor; if e then fillT:SetVertexColor(e[1], e[2], e[3], e[4] or 1) end end)
    local copyAll = kit:Button(p, "Copy color to all bars", 190, false, function()
        local c = Bar(); if not (c and c.emptyColor) then return end
        for k = 1, ns.NUM do
            local bc = ns.Bar(k)
            if bc then bc.emptyColor = { c.emptyColor[1], c.emptyColor[2], c.emptyColor[3], c.emptyColor[4] or 1 }; ns.PaintEmptyBar(k) end
        end
    end)
    copyAll:SetPoint("TOPLEFT", LX, y(8) + 4); kit:Flow(copyAll, "TOPLEFT", LX, y(8) + 4)
    kit:Hint(p, "Shown behind buttons with no action (Flat style); the alpha makes them see-through.", LX, y(9) - 2, COLW)

    kit:Caption(p, "Texts", RX, 0)
    kit:SwitchRow(p, "Key binding", RX, y(1), COLW, BGet("hotkey"), BSet("hotkey"))
    kit:SwitchRow(p, "Macro name", RX, y(2), COLW, BGet("macro"), BSet("macro"))
    kit:SwitchRow(p, "Stack count / charges", RX, y(3), COLW, BGet("count"), BSet("count"))
    kit:Caption(p, "Visibility", RX, y(4) - 4)
    local vis = kit:InputBox(p, COLW, 26)
    vis:SetPoint("TOPLEFT", RX, y(5) - 4)
    kit:Flow(vis, "TOPLEFT", RX, y(5) - 4, COLW)
    vis:SetScript("OnEnterPressed", function(s) s:ClearFocus(); BSet("visibility")(s:GetText() or "") end)
    kit:OnRefresh(function() if not vis:HasFocus() then vis:SetText((Bar() and Bar().visibility) or ""); vis:SetCursorPosition(0) end end)
    kit:Hint(p, "A macro condition, applied when you press Enter. Examples: \"[combat] show; hide\"  ·  \"[@target,exists] show; hide\"  ·  \"[petbattle] hide; show\" (default).", RX, y(6) - 2, COLW)

    -- ------------------------------------------------ General
    p = pages.general
    kit:Caption(p, "The game's bars", LX, 0)
    kit:SwitchRow(p, "Hide the game's action bars", LX, y(1), COLW, GGet("hideBlizzard"), GSet("hideBlizzard", true))
    kit:Label(p, "Button style", LX, y(2) - 5)
    kit:Segmented(p, { { "FLAT", "Flat" }, { "BLIZZARD", "Blizzard" } }, LX + 120, y(2), COLW - 120, GGet("style"), GSet("style", true))
    kit:SwitchRow(p, "Cast when the key goes down", LX, y(3), COLW, GGet("keyDown"), GSet("keyDown"))
    kit:SwitchRow(p, "Out of range in red", LX, y(4), COLW, GGet("rangeColor"), GSet("rangeColor"))
    kit:Caption(p, "Font", LX, y(5) - 4)
    kit:FontDropdown(p, "Font", LX, y(6) - 4, COLW, FontKey, GSet("font"))
    kit:SliderRow(p, "Size", LX, y(7) - 4, COLW, GGet("fontSize"), GSet("fontSize"), { lo = 6, hi = 24, step = 1, min = 4 })
    kit:OutlineDropdown(p, "Outline", LX, y(8) - 4, COLW, GGet("outline"), GSet("outline"))
    kit:Hint(p, "Hiding the game's bars and the button style apply after a reload (button below). The pet and stance bars of the game stay.", LX, y(9), COLW)

    kit:Caption(p, "Key bindings", RX, 0)
    kit:Hint(p, "Bars 1 to 5 (and 7 to 9, when the game has Action Bars 5 to 7) use the game's own bindings (Key Bindings in the game menu). Bars 6 to 9 also have their own lines under AddOns > Free Bars.", RX, -22, COLW)
    kit:Caption(p, "Bar 1 paging (advanced)", RX, y(3) - 4)
    local pg = kit:InputBox(p, COLW, 26)
    pg:SetPoint("TOPLEFT", RX, y(4) - 4)
    kit:Flow(pg, "TOPLEFT", RX, y(4) - 4, COLW)
    pg:SetScript("OnEnterPressed", function(s) s:ClearFocus(); local t = s:GetText() or ""; GSet("paging")(t ~= "" and t or nil) end)
    kit:OnRefresh(function() if not pg:HasFocus() then pg:SetText((ns.Global() and ns.Global().paging) or ns.DefaultPaging()); pg:SetCursorPosition(0) end end)
    local pgReset = kit:Button(p, "Automatic", 100, false, function() GSet("paging")(nil) end)
    pgReset:SetPoint("TOPLEFT", RX, y(5) - 6)
    kit:Flow(pgReset, "TOPLEFT", RX, y(5) - 6)
    kit:Hint(p, "Which action page bar 1 shows: forms, stances, stealth, vehicles. Change it only if you know macro conditions; \"Automatic\" puts back the one made for your class.", RX, y(6) - 2, COLW)

    -- ------------------------------------------------ Profiles
    p = pages.profiles
    local PM = function() return ns.profiles end
    local function items(exceptCurrent)
        local out = {}
        local m = PM(); if not m then return out end
        for _, name in ipairs(m:List()) do
            if not (exceptCurrent and name == m:Current()) then
                local n = m:Users(name)
                out[#out + 1] = { key = name, label = name .. (n > 0 and ("  (" .. n .. " char.)") or "") }
            end
        end
        return out
    end
    kit:Caption(p, "Profile", LX, 0)
    kit:Dropdown(p, "This character", LX, y(1), COLW, function() return items(false) end,
        function() return PM() and PM():Current() end, function(v) if PM() then PM():Set(v) end end)
    kit:Label(p, "New profile", LX, y(2) - 5)
    local nb = kit:InputBox(p, COLW - 120 - 2 * 76)
    nb:SetPoint("TOPLEFT", LX + 120, y(2)); kit:Flow(nb, "TOPLEFT", LX + 120, y(2), COLW - 120 - 2 * 76)
    local function nn() local t = (nb:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", ""); return t ~= "" and t or nil end
    local bE = kit:Button(p, "Empty", 72, false, function() local n = nn(); if n and PM() then nb:SetText(""); nb:ClearFocus(); PM():Set(n) end end)
    bE:SetPoint("LEFT", nb, "RIGHT", 4, 0)
    local bC = kit:Button(p, "Copy", 72, true, function() local n = nn(); if n and PM() then nb:SetText(""); nb:ClearFocus(); PM():Set(n, PM():Current()) end end)
    bC:SetPoint("LEFT", bE, "RIGHT", 4, 0)
    nb:SetScript("OnEnterPressed", function() bC:Click() end)
    local cp = kit:Dropdown(p, "Copy settings", LX, y(3), COLW, function() return items(true) end, function() return nil end,
        function(v) if PM() then PM():CopyFrom(v) end end)
    cp.placeholder = "from another profile..."
    local dl = kit:Dropdown(p, "Delete", LX, y(4), COLW, function() return items(true) end, function() return nil end,
        function(v) if PM() then PM():Delete(v); kit:Refresh() end end)
    dl.placeholder = "choose a profile..."
    kit:Hint(p, "Each character remembers its profile. \"Copy\" starts the new profile from the current one.", LX, y(5), COLW)
    local LFP = LibStub("LibFreeProfiles-1.0", true)
    kit:Caption(p, "Share", RX, 0)
    local bX = kit:Button(p, "Export profile", 150, false, function() if LFP and PM() then LFP:ShowExport("Export Free Bars profile: " .. PM():Current(), PM():Export()) end end)
    bX:SetPoint("TOPLEFT", RX, -22); kit:Flow(bX, "TOPLEFT", RX, -22)
    local bI = kit:Button(p, "Import profile", 150, false, function()
        if LFP and PM() then LFP:ShowImport("Import a Free Bars profile", "Imported", function(t, n) local ok, r = PM():Import(t, n); kit:Refresh(); return ok, r end) end
    end)
    bI:SetPoint("LEFT", bX, "RIGHT", 8, 0)
    kit:Hint(p, "Export gives one line of text to paste on another character or account. Import creates a profile from it and selects it.", RX, y(2), COLW)

    -- ------------------------------------------------ footer
    local reset
    reset = kit:Button(footer, "Reset bar", 110, false, function()
        if type(scope) ~= "number" then return end
        local now = GetTime and GetTime() or 0
        if reset.armed and now - reset.armed < 4 then
            reset.armed = nil; reset.label:SetText("Reset bar")
            ns.ResetBar(scope); ns.UpdateBar(scope); kit:Refresh()
        else
            reset.armed = now; reset.label:SetText("Click again")
        end
    end)
    reset:SetPoint("LEFT", PAD, 0)
    local reload = kit:Button(footer, "Reload to apply", 140, false, function() ReloadUI() end)
    reload:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    local lock = kit:Button(footer, "Unlock", 120, true, function() ns.SetUnlocked(not ns.IsUnlocked()) end)
    lock:SetPoint("RIGHT", -PAD, 0)
    kit:OnRefresh(function()
        reset:SetShown(type(scope) == "number")
        reset.armed = nil; reset.label:SetText("Reset bar")
        reload:SetShown(needReload)
        lock.label:SetText(ns.IsUnlocked() and "Lock" or "Unlock")
    end)
end

local function DoBuild() if not kit.frame then Build() end end

ns.OnChanged = function() kit:Refresh() end
function ns.OpenBar(i)
    scope = i
    if not (kit.frame and kit.frame:IsShown()) then ns.ToggleConfig() end
    kit:Refresh()
end

kit:RegisterHub("FreeBars", DoBuild, function(show) if ns.ApplyMinimapVisibility then ns.ApplyMinimapVisibility(show) end end)

ns.ToggleConfig = function()
    if not ns.GetDB() then return end
    kit:Toggle("FreeBars", DoBuild)
end
