-- Free Bars - action bars: nine bars of up to 12 buttons, laid out in a grid or on an arc of a circle.
-- Buttons come from LibActionButton-1.0 (secure action buttons, cooldowns, ranges, bindings...).

local ADDON, ns = ...
local LAB = LibStub("LibActionButton-1.0-Free")
local LFP = LibStub("LibFreeProfiles-1.0", true)
local LFM = LibStub("LibFreeMedia-1.0", true)
local LGrid = LibStub("LibFreeGrid-1.0", true)
local PREFIX = "|cffff8a3dFree Bars|r: "
function ns.Print(msg) print(PREFIX .. msg) end
local WHITE = "Interface\\Buttons\\WHITE8x8"

-- page = action page of the bar (actions (page-1)*12+1 .. page*12), bind = the game's key binding names
ns.BARS = {
    { page = 1, bind = "ACTIONBUTTON",          label = "Bar 1", hint = "main bar (pages with stances, forms, vehicles)" },
    { page = 6, bind = "MULTIACTIONBAR1BUTTON", label = "Bar 2", hint = "bottom left bar of the game" },
    { page = 5, bind = "MULTIACTIONBAR2BUTTON", label = "Bar 3", hint = "bottom right bar of the game" },
    { page = 3, bind = "MULTIACTIONBAR3BUTTON", label = "Bar 4", hint = "right bar of the game" },
    { page = 4, bind = "MULTIACTIONBAR4BUTTON", label = "Bar 5", hint = "left bar of the game" },
    { page = 2, bind = nil,                     label = "Bar 6", hint = "action page 2 (keys: Key Bindings > AddOns > Free Bars)" },
    -- pages 13-15 are the game's Action Bar 5, 6 and 7 on this client (bindings MULTIACTIONBAR5/6/7BUTTON when the game has them)
    { page = 13, bind = "MULTIACTIONBAR5BUTTON", label = "Bar 7", hint = "Action Bar 5 of the game (page 13)" },
    { page = 14, bind = "MULTIACTIONBAR6BUTTON", label = "Bar 8", hint = "Action Bar 6 of the game (page 14)" },
    { page = 15, bind = "MULTIACTIONBAR7BUTTON", label = "Bar 9", hint = "Action Bar 7 of the game (page 15)" },
}
ns.NUM = #ns.BARS

-- ------------------------------------------------------------ settings
local function BarDefaults(i)
    local d = {
        enable = i <= 3, buttons = 12, perRow = 12, size = 36, height = 0, spacing = 3, point = "BOTTOMLEFT",
        layout = "GRID", arcRadius = 140, arcPercent = 50, arcRotation = 90, arcReverse = false,
        backdrop = false, backdropPad = 4, scale = 1, alpha = 1, mouseover = false, fadeAlpha = 0,
        showGrid = false, hotkey = true, macro = false, count = true,
        emptyColor = { 0, 0, 0, 1 },     -- background of buttons without an action (FLAT style)
        visibility = "[petbattle] hide; show",
        pos = { "BOTTOM", 0, 40 + (i - 1) * 42 },
    }
    if i == 4 or i == 5 then d.enable = false; d.perRow = 1; d.point = "TOPRIGHT"; d.pos = { "RIGHT", -4 - (i - 4) * 42, 0 } end
    if i == 6 then d.pos = { "BOTTOM", 0, 166 } end
    if i >= 7 then d.enable = false; d.pos = { "BOTTOM", 0, 40 + (i - 1) * 42 } end
    return d
end
ns.BarDefaults = BarDefaults

local GLOBAL_DEFAULTS = {
    hideBlizzard = true,
    style = "FLAT",                -- FLAT (thin border, cropped icons) or BLIZZARD
    font = "Fonts\\ARIALN.TTF", fontSize = 12, outline = "OUTLINE",
    keyDown = true,                -- cast when the key goes down
    paging = nil,                  -- custom page conditions of bar 1 (nil = automatic)
    rangeColor = true,
}

local function Fill(t, d)
    for k, v in pairs(d) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then t[k] = {} end
            Fill(t[k], v)
        elseif t[k] == nil then
            t[k] = v
        end
    end
    return t
end

local db, prof
function ns.GetDB() return db end
function ns.Profile() return prof end
function ns.Bar(i) return prof and prof.bars[i] end
function ns.Global() return prof and prof.global end
local function Prepare(p)
    p.global = Fill(p.global or {}, GLOBAL_DEFAULTS)
    p.bars = p.bars or {}
    for i = 1, ns.NUM do p.bars[i] = Fill(p.bars[i] or {}, BarDefaults(i)) end
    return p
end
function ns.ResetBar(i) if prof then prof.bars[i] = BarDefaults(i) end end

-- ------------------------------------------------------------ conflicts
-- another action bar addon owns the same buttons and bindings: only one of them may run
local function OtherBarAddon()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not loaded then return nil end
    for _, n in ipairs({ "Bartender4", "Dominos" }) do if loaded(n) then return n end end
    if loaded("ElvUI") then
        local pdb = ElvPrivateDB
        local key = (UnitName("player") or "") .. " - " .. (GetRealmName() or "")
        local pname = pdb and pdb.profileKeys and pdb.profileKeys[key]
        local p = pname and pdb.profiles and pdb.profiles[pname]
        local ab = p and p.actionbar
        if not (ab and ab.enable == false) then return "ElvUI (its action bars)" end
    end
end

-- ------------------------------------------------------------ bar 1 paging
local function BarIndex(fnName, fallback)
    local f = (C_ActionBar and C_ActionBar[fnName]) or _G[fnName]
    local ok, v = pcall(f or function() end)
    return (ok and tonumber(v)) or fallback
end
local CLASS_PAGING = {
    DRUID   = "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 8; [bonusbar:2] 10; [bonusbar:3] 9; [bonusbar:4] 10;",
    ROGUE   = "[bonusbar:1] 7;",
    WARRIOR = "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9;",
    PRIEST  = "[form:1] 7;",
}
function ns.DefaultPaging()
    local _, class = UnitClass("player")
    return string.format("[overridebar] %d; [vehicleui][possessbar] %d; [shapeshift] %d; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; %s [bonusbar:5] 11; 1",
        BarIndex("GetOverrideBarIndex", 14), BarIndex("GetVehicleBarIndex", 12), BarIndex("GetTempShapeshiftBarIndex", 13), CLASS_PAGING[class] or "")
end

-- ------------------------------------------------------------ bars
local bars = {}        -- [i] = header (secure), with .holder, .buttons, .bg
ns.bars = bars
local pending = false
local unlocked = false
function ns.IsUnlocked() return unlocked end

local function ButtonConfig(i, b)
    local c, g = ns.Bar(i), ns.Global()
    local info = ns.BARS[i]
    local font = LFM and LFM:FontPath(g.font, g.font) or g.font       -- g.font: a LibFreeMedia key or an old file path
    local flags = LFM and LFM:Flags(g.outline) or (g.outline == "NONE" and "" or g.outline)
    return {
        outOfRangeColoring = g.rangeColor and "button" or "none",
        showGrid = (c.showGrid or unlocked) and true or false,
        clickOnDown = g.keyDown,
        keyBoundTarget = (info.bind and b) and (info.bind .. b) or false,
        hideElements = { hotkey = not c.hotkey, macro = not c.macro, count = not c.count, equipped = (g.style == "FLAT") },
        text = {
            hotkey = { font = { font = font, size = g.fontSize, flags = flags }, position = { anchor = "TOPRIGHT", relAnchor = "TOPRIGHT", offsetX = -2, offsetY = -3 }, justifyH = "RIGHT" },
            count = { font = { font = font, size = g.fontSize + 1, flags = flags }, position = { anchor = "BOTTOMRIGHT", relAnchor = "BOTTOMRIGHT", offsetX = -2, offsetY = 3 }, justifyH = "RIGHT" },
            macro = { font = { font = font, size = math.max(8, g.fontSize - 2), flags = flags }, position = { anchor = "BOTTOM", relAnchor = "BOTTOM", offsetX = 0, offsetY = 2 }, justifyH = "CENTER" },
        },
    }
end

-- thin border, cropped icon (applied once per button)
local function R(b, k) local v = b[k]; return type(v) == "table" and v or nil end
-- background of a FLAT button: black, or the bar's "empty" colour when the button has no action
function ns.PaintEmpty(b)
    local bg = b.fbBg
    if not bg then return end
    local r, g, bl, a = 0, 0, 0, 1
    local c = b.fbBar and ns.Bar(b.fbBar)
    local ec = c and c.emptyColor
    if type(ec) == "table" then
        local ok, has = pcall(b.HasAction, b)
        if ok and not has then r, g, bl, a = ec[1] or 0, ec[2] or 0, ec[3] or 0, ec[4] or 1 end
    end
    bg:SetVertexColor(r, g, bl, a)
end
function ns.PaintEmptyBar(i)
    local h = bars[i]
    if h then for _, btn in ipairs(h.buttons) do ns.PaintEmpty(btn) end end
end
local function SkinFlat(b)
    if b.fbSkinned then return end
    b.fbSkinned = true
    local icon = R(b, "icon") or R(b, "Icon")
    if icon then
        local mask = R(b, "IconMask")
        if mask then pcall(icon.RemoveMaskTexture, icon, mask); mask:Hide() end
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints(); icon:SetPoint("TOPLEFT", 1, -1); icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetDrawLayer("BACKGROUND", 1)
    end
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints(); bg:SetTexture(WHITE); bg:SetVertexColor(0, 0, 0, 1)
    b.fbBg = bg
    ns.PaintEmpty(b)
    for _, k in ipairs({ "SlotBackground", "SlotArt", "FloatingBG", "RightDivider", "BottomDivider" }) do
        if R(b, k) then b[k]:SetAlpha(0) end
    end
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    if R(b, "NormalTexture") then b.NormalTexture:SetAlpha(0) end
    if b.SetPushedTexture then
        b:SetPushedTexture(WHITE); local t = b:GetPushedTexture()
        if t then t:SetVertexColor(1, 0.85, 0.3, 0.3); t:ClearAllPoints(); t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1) end
    end
    if b.SetHighlightTexture then
        b:SetHighlightTexture(WHITE); local t = b:GetHighlightTexture()
        if t then t:SetVertexColor(1, 1, 1, 0.22); t:ClearAllPoints(); t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1) end
    end
    if b.SetCheckedTexture then
        b:SetCheckedTexture(WHITE); local t = b:GetCheckedTexture()
        if t then t:SetVertexColor(1, 0.54, 0.24, 0.35); t:ClearAllPoints(); t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1) end
    end
    if R(b, "cooldown") and icon then b.cooldown:ClearAllPoints(); b.cooldown:SetAllPoints(icon) end
    if R(b, "Border") then b.Border:SetAlpha(0) end   -- equipped item border
end

local function CreateBar(i)
    local info = ns.BARS[i]
    local holder = CreateFrame("Frame", "FreeBarsBar" .. i .. "Holder", UIParent)
    holder:SetSize(10, 10)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    local h = CreateFrame("Frame", "FreeBarsBar" .. i, UIParent, "SecureHandlerStateTemplate")
    h:SetFrameStrata("LOW")
    h.id, h.holder, h.buttons = i, holder, {}
    h.bg = h:CreateTexture(nil, "BACKGROUND", nil, -7)
    h.bg:SetAllPoints(); h.bg:SetTexture(WHITE); h.bg:SetVertexColor(0.06, 0.06, 0.07, 0.8)
    h:SetAttribute("_onstate-page", [[
        self:SetAttribute("state", newstate)
        control:ChildUpdate("state", newstate)
    ]])
    local flat = ns.Global().style == "FLAT"
    for b = 1, 12 do
        local btn = LAB:CreateButton(b, "FreeBarsBar" .. i .. "Button" .. b, h, ButtonConfig(i, b))
        for k = 1, 18 do btn:SetState(k, "action", (k - 1) * 12 + b) end
        btn.fbBar = i
        if flat then SkinFlat(btn) end
        h.buttons[b] = btn
    end
    bars[i] = h
    return h
end

-- keep the empty-slot colour right when actions change (drag & drop, bar switch, talents...)
if LAB.RegisterCallback then
    local cbOwner = {}
    local function OnBtn(_, btn) if btn and btn.fbBg then ns.PaintEmpty(btn) end end
    LAB.RegisterCallback(cbOwner, "OnButtonUpdate", OnBtn)
    LAB.RegisterCallback(cbOwner, "OnButtonContentsChanged", OnBtn)
end

-- positions of n buttons (centre of each) for the bar's layout
local function Positions(c)
    local n = math.max(1, math.min(12, c.buttons))
    local w = c.size
    local hgt = (c.height and c.height > 0) and c.height or c.size
    local out = {}
    if c.layout == "ARC" then
        local A = math.max(1, math.min(100, c.arcPercent or 50)) * 3.6
        local R = math.max(10, c.arcRadius or 140)
        local full = A >= 359.9
        local step = full and (A / n) or (n > 1 and A / (n - 1) or 0)
        local first = (c.arcRotation or 90) + (full and 0 or A / 2)
        local dir = c.arcReverse and 1 or -1
        for k = 0, n - 1 do
            local a = math.rad(first + dir * k * step)
            out[k + 1] = { R * math.cos(a), R * math.sin(a) }
        end
    else
        local per = math.max(1, math.min(n, c.perRow or 12))
        local p = c.point or "BOTTOMLEFT"
        local sx = p:find("RIGHT") and -1 or 1
        local sy = p:find("TOP") and -1 or 1
        for k = 0, n - 1 do
            local col, row = k % per, math.floor(k / per)
            out[k + 1] = { sx * col * (w + c.spacing), sy * row * (hgt + c.spacing) }
        end
    end
    return out, w, hgt
end
ns.Positions = Positions

local function ApplyBar(i)
    local h = bars[i]
    if not h then return end
    local c = ns.Bar(i)
    local pos, w, hgt = Positions(c)
    local minX, maxX, minY, maxY = 1e9, -1e9, 1e9, -1e9
    for _, p in ipairs(pos) do
        minX = math.min(minX, p[1]); maxX = math.max(maxX, p[1]); minY = math.min(minY, p[2]); maxY = math.max(maxY, p[2])
    end
    local pad = c.backdrop and (c.backdropPad or 4) or 0
    local bw = (maxX - minX) + w + 2 * pad
    local bh = (maxY - minY) + hgt + 2 * pad
    h:SetSize(bw, bh)
    h:SetScale(c.scale or 1)
    for b, btn in ipairs(h.buttons) do
        local p = pos[b]
        btn:ClearAllPoints()
        if p then
            btn:SetSize(w, hgt)
            -- equipped item border (Blizzard style): the template draws it at a fixed size, follow the button
            if type(btn.Border) == "table" and btn.Border.ClearAllPoints then btn.Border:ClearAllPoints(); btn.Border:SetAllPoints(btn) end
            btn:SetPoint("CENTER", h, "TOPLEFT", pad + (p[1] - minX) + w / 2, -(pad + (maxY - p[2]) + hgt / 2))
            btn:SetAttribute("statehidden", nil)
            btn:Show()
        else
            btn:SetAttribute("statehidden", true)
            btn:Hide()
        end
        btn:UpdateConfig(ButtonConfig(i, b))
        ns.PaintEmpty(btn)
    end
    h.bg:SetShown(c.backdrop and true or false)
    -- place: holder (plain frame, saved position) carries the bar
    local holder = h.holder
    holder:ClearAllPoints()
    holder:SetPoint(c.pos[1] or "CENTER", UIParent, c.pos[1] or "CENTER", c.pos[2] or 0, c.pos[3] or 0)
    holder:SetSize(bw * (c.scale or 1), bh * (c.scale or 1))
    h:ClearAllPoints()
    h:SetPoint("CENTER", holder, "CENTER", 0, 0)
    -- paging and visibility
    UnregisterStateDriver(h, "page")
    local paging = (i == 1) and ((ns.Global().paging and ns.Global().paging ~= "") and ns.Global().paging or ns.DefaultPaging()) or tostring(ns.BARS[i].page)
    RegisterStateDriver(h, "page", paging)
    UnregisterStateDriver(h, "visibility")
    if c.enable then
        local vis = (c.visibility and c.visibility ~= "") and c.visibility or "show"
        if unlocked then vis = "show" end
        RegisterStateDriver(h, "visibility", vis)
    else
        RegisterStateDriver(h, "visibility", "hide")
    end
    ns.UpdateFade(i)
end

function ns.UpdateBar(i)
    if InCombatLockdown() then pending = true; return end
    ns.Safe("bar " .. i, ApplyBar, i)
    ns.UpdateBindings()
    if ns.UpdateMover then ns.UpdateMover(i) end
end
function ns.UpdateAll()
    if InCombatLockdown() then pending = true; return end
    for i = 1, ns.NUM do ns.Safe("bar " .. i, ApplyBar, i) end
    ns.UpdateBindings()
    if ns.UpdateMovers then ns.UpdateMovers() end
end

-- ------------------------------------------------------------ mouseover fade
local fader = CreateFrame("Frame")
local fadeBars = {}
function ns.UpdateFade(i)
    local h, c = bars[i], ns.Bar(i)
    if not (h and c) then return end
    fadeBars[i] = (c.mouseover and not unlocked) and true or nil
    if not fadeBars[i] then h:SetAlpha(c.alpha or 1) end
    fader:SetShown(next(fadeBars) ~= nil)
end
local acc = 0
fader:SetScript("OnUpdate", function(_, el)
    acc = acc + el
    if acc < 0.08 then return end
    acc = 0
    for i in pairs(fadeBars) do
        local h, c = bars[i], ns.Bar(i)
        if h and c then
            local over = h:IsMouseOver(4, -4, -4, 4) or ns.dragging or (SpellFlyout and SpellFlyout:IsShown() and SpellFlyout:IsMouseOver())
            local target = over and (c.alpha or 1) or (c.fadeAlpha or 0)
            local cur = h:GetAlpha()
            if math.abs(cur - target) > 0.01 then h:SetAlpha(cur + (target - cur) * 0.45) end
        end
    end
end)
fader:Hide()

-- ------------------------------------------------------------ key bindings
-- bars 1-5 (and 7-9 when the game has the bindings) answer the game's own bindings; bars 6-9 also have their own CLICK lines
function ns.UpdateBindings()
    if InCombatLockdown() then pending = true; return end
    for i, h in pairs(bars) do
        ClearOverrideBindings(h)
        local bind = ns.BARS[i].bind
        local c = ns.Bar(i)
        if bind and c.enable then
            for b, btn in ipairs(h.buttons) do
                if b <= c.buttons then
                    for _, key in ipairs({ GetBindingKey(bind .. b) }) do
                        SetOverrideBindingClick(h, false, key, btn:GetName(), "LeftButton")
                    end
                end
            end
        end
    end
end
for _, n in ipairs({ 6, 7, 8, 9 }) do
    for b = 1, 12 do
        _G["BINDING_NAME_CLICK FreeBarsBar" .. n .. "Button" .. b .. ":LeftButton"] = "Bar " .. n .. " button " .. b
    end
end
BINDING_HEADER_FREEBARS = "Free Bars"

-- ------------------------------------------------------------ the game's bars
local hider = CreateFrame("Frame")
hider:Hide()
local BLIZZ_BARS = { "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7" }
local BLIZZ_BUTTONS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarLeftButton", "MultiBarRightButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
-- frames that must stay visible even if the game keeps them inside its main bar
local KEEP = { "StanceBar", "StanceBarFrame", "PetActionBar", "PetActionBarFrame", "PossessActionBar", "PossessBarFrame",
               "MicroMenuContainer", "MicroButtonAndBagsBar", "BagsBar", "MainMenuBarVehicleLeaveButton", "StatusTrackingBarManager",
               "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "MultiCastActionBarFrame" }
local blizzHidden = false
-- Forever: re-parenting the game's bars, removing their events or editing their tables taints them
-- (blocked actions, secret value errors). Only make them invisible and let clicks through:
-- the game keeps running them, and our override key bindings take the keys.
local function HideBlizzard()
    if blizzHidden or InCombatLockdown() then return end
    blizzHidden = true
    local hiddenSet = {}
    for _, n in ipairs(BLIZZ_BARS) do if _G[n] then hiddenSet[_G[n]] = true end end
    for _, n in ipairs(KEEP) do
        local f = _G[n]
        if f and f.GetParent and hiddenSet[f:GetParent()] and f.SetIgnoreParentAlpha then f:SetIgnoreParentAlpha(true) end
    end
    local function Invisible(f)
        f:SetAlpha(0)
        if f.EnableMouse then pcall(f.EnableMouse, f, false) end
        hooksecurefunc(f, "SetAlpha", function(self, a) if a ~= 0 then self:SetAlpha(0) end end)
    end
    for f in pairs(hiddenSet) do Invisible(f) end
    for _, prefix in ipairs(BLIZZ_BUTTONS) do
        for b = 1, 12 do
            local btn = _G[prefix .. b]
            if btn then Invisible(btn) end
        end
    end
end

-- ------------------------------------------------------------ movers (unlock)
local movers = {}
local C_ACCENT = { 1, 0.54, 0.24 }
local Grid, gridBar
local function HolderRect(i)
    local hd = bars[i] and bars[i].holder
    if not hd then return end
    local l, b, w, hh = hd:GetRect()
    if not l then return end
    local s = hd:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return l * s, b * s, w * s, hh * s
end
local function OtherRects(i)
    local out = {}
    for k, m in pairs(movers) do
        if k ~= i and m:IsShown() then
            local l, b, w, h = HolderRect(k)
            if l then out[#out + 1] = { l, b, w, h } end
        end
    end
    return out
end
local function Snap(i, l, b, w, h)
    if not Grid then return l, b end
    return Grid:Snap(l, b, w, h, OtherRects(i))
end
local function SavePos(i, l, b, w, h)
    local c = ns.Bar(i)
    local point = c.pos[1] or "CENTER"
    local sx, sy = UIParent:GetSize()
    local x, y
    if point:find("LEFT") then x = l elseif point:find("RIGHT") then x = l + w - sx else x = l + w / 2 - sx / 2 end
    if point:find("TOP") then y = b + h - sy elseif point:find("BOTTOM") then y = b else y = b + h / 2 - sy / 2 end
    c.pos = { point, math.floor(x + 0.5), math.floor(y + 0.5) }
end
local function Mover(i)
    if movers[i] then return movers[i] end
    local hd = bars[i].holder
    local m = CreateFrame("Button", nil, UIParent)
    m:SetFrameStrata("HIGH")
    m:SetAllPoints(hd)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    local bg = m:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetTexture(WHITE); bg:SetVertexColor(0.07, 0.074, 0.085, 0.4)
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local e = m:CreateTexture(nil, "BORDER"); e:SetTexture(WHITE); e:SetVertexColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.9)
        e:SetPoint(p[1]); e:SetPoint(p[2]); if p[3] then e:SetHeight(1) else e:SetWidth(1) end
    end
    local t = m:CreateFontString(nil, "OVERLAY"); t:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE"); t:SetPoint("CENTER")
    t:SetTextColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3]); t:SetText(ns.BARS[i].label)
    m:SetScript("OnDragStart", function() if not InCombatLockdown() then hd:StartMoving() end end)
    m:SetScript("OnDragStop", function()
        hd:StopMovingOrSizing()
        local l, b, w, h = HolderRect(i)
        if not l then return end
        if not IsAltKeyDown() then l, b = Snap(i, l, b, w, h) end
        SavePos(i, l, b, w, h)
        ns.UpdateBar(i)
        if ns.OnChanged then ns.OnChanged() end
    end)
    m:EnableMouseWheel(true)
    m:SetScript("OnMouseWheel", function(_, d)
        local c = ns.Bar(i)
        if IsShiftKeyDown() then c.pos[2] = c.pos[2] + d else c.pos[3] = c.pos[3] + d end
        ns.UpdateBar(i)
        if ns.OnChanged then ns.OnChanged() end
    end)
    m:SetScript("OnClick", function(_, btn) if btn == "RightButton" and ns.OpenBar then ns.OpenBar(i) end end)
    m:RegisterForClicks("RightButtonUp")
    m:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:AddLine(ns.BARS[i].label, C_ACCENT[1], C_ACCENT[2], C_ACCENT[3])
        GameTooltip:AddLine("Drag to move: snaps to the other bars, the screen centre and the grid (options in the toolbar; hold Alt to place freely). Mouse wheel: up/down, Shift + wheel: left/right. Right-click: options of this bar.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    movers[i] = m
    return m
end
function ns.UpdateMover(i)
    local c = ns.Bar(i)
    if unlocked and c and c.enable and bars[i] then Mover(i):Show() elseif movers[i] then movers[i]:Hide() end
end
function ns.UpdateMovers() for i = 1, ns.NUM do ns.UpdateMover(i) end end
function ns.SetUnlocked(on)
    if on and InCombatLockdown() then ns.Print("bars cannot be moved in combat."); return end
    unlocked = on and true or false
    if LGrid and db then
        if unlocked and not gridBar then
            gridBar = Grid:Toolbar(db.grid, nil, function() if unlocked then ns.SetUnlocked(false) end end, "Free Bars")
        end
        if gridBar then if unlocked then gridBar:Show() else gridBar:Hide() end end
    end
    ns.UpdateAll()
    if ns.OnChanged then ns.OnChanged() end
end

-- ------------------------------------------------------------ errors
local reported = {}
function ns.Safe(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        db.errors = db.errors or {}
        table.insert(db.errors, { where = label, error = tostring(err) })
        while #db.errors > 30 do table.remove(db.errors, 1) end
        if not reported[label .. tostring(err)] then reported[label .. tostring(err)] = true; ns.Print("error (" .. label .. "): " .. tostring(err)) end
    end
    return ok
end

-- ------------------------------------------------------------ events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        FreeBarsDB = type(FreeBarsDB) == "table" and FreeBarsDB or {}
        db = FreeBarsDB
        db.minimap = db.minimap or { hide = false }
        db.grid = type(db.grid) == "table" and db.grid or {}      -- account-level unlock grid settings (LibFreeGrid)
        if LGrid then Grid = LGrid:Attach(db.grid) end
        return
    elseif event == "PLAYER_LOGIN" then
        if LFP then
            ns.profiles = LFP:New("FreeBars", db, function(d)
                prof = Prepare(d)
                if next(bars) then ns.UpdateAll() end
                if ns.OnChanged then ns.OnChanged() end
            end, Prepare, nil, { perCharacter = true })
            prof = ns.profiles:Data()
        else
            db.profiles = db.profiles or {}
            db.profiles.Default = Prepare(db.profiles.Default or {})
            prof = db.profiles.Default
        end
        -- 1.3: the game's bars are hidden in a safe way now, so hiding them is on for everyone (once)
        if not db.hideBlizzardV2 then
            db.hideBlizzardV2 = true
            for _, p in pairs(db.profiles or {}) do
                if type(p) == "table" and type(p.global) == "table" then p.global.hideBlizzard = true end
            end
        end
        local other = OtherBarAddon()
        if other then
            ns.conflict = other
            ns.Print("paused: " .. other .. " already draws the action bars. Turn it off (or its action bars), then /reload, to use Free Bars.")
            return
        end
        for i = 1, ns.NUM do ns.Safe("create " .. i, CreateBar, i) end
        if ns.Global().hideBlizzard then ns.Safe("hide game bars", HideBlizzard) end
        ns.UpdateAll()
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("UPDATE_BINDINGS")
        self:RegisterEvent("ACTIONBAR_SHOWGRID")
        self:RegisterEvent("ACTIONBAR_HIDEGRID")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        if unlocked then
            unlocked = false; for _, m in pairs(movers) do m:Hide() end; pending = true
            if gridBar then gridBar:Hide() end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then pending = false; ns.UpdateAll() end
    elseif event == "UPDATE_BINDINGS" then
        ns.UpdateBindings()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- vehicle / override indexes are known for sure now
        if not ns.Global().paging and not InCombatLockdown() and bars[1] then
            RegisterStateDriver(bars[1], "page", ns.DefaultPaging())
        end
    elseif event == "ACTIONBAR_SHOWGRID" then
        ns.dragging = true
    elseif event == "ACTIONBAR_HIDEGRID" then
        ns.dragging = nil
    end
end)

-- ------------------------------------------------------------ slash
SLASH_FREEBARS1 = "/fb"
SLASH_FREEBARS2 = "/freebars"
SlashCmdList.FREEBARS = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "unlock" or msg == "lock" or msg == "move" then ns.SetUnlocked(not unlocked)
    elseif msg == "help" or msg == "?" then ns.Print("/fb = options, /fb unlock = move the bars.")
    elseif ns.ToggleConfig then ns.ToggleConfig() end
end
