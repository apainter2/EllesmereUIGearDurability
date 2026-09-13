-- Independent settings window for the companion addon. Built only on demand.
local ADDON, EGD = ...
local panel
local refreshers = {}
local syncing = false

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff0cd29f[Gear Durability]|r " .. message)
end

local function RefreshPanel()
    syncing = true
    for i = 1, #refreshers do refreshers[i]() end
    syncing = false
end

local function Apply()
    EGD.Apply()
    if EllesmereUI._unlockActive and EllesmereUI.RepositionBarToMover then
        EllesmereUI.RepositionBarToMover("EGD_GearDurability")
    end
end

local function Move()
    if InCombatLockdown() then
        Print("Leave combat before opening Unlock Mode.")
        return
    end
    local p = EGD.Settings()
    p.visibility = "ALWAYS"
    if not p.showIcon and not p.showPercent then p.showPercent = true end
    Apply()
    EGD.SeedPos()
    if panel then panel:Hide() end
    EllesmereUI:OpenUnlockMode()
end

local function BuildPanel()
    panel = CreateFrame("Frame", "EGD_SettingsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(460, 470)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    panel:SetBackdropColor(0.055, 0.065, 0.075, 0.98)
    panel:SetBackdropBorderColor(0.05, 0.82, 0.62, 1)
    tinsert(UISpecialFrames, "EGD_SettingsPanel")

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText("EllesmereUI - Gear Durability")
    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", 20, -47)
    subtitle:SetText("Lowest equipped durability. Settings are saved per character.")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)

    local function Check(label, x, y, get, set)
        local button = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        button:SetPoint("TOPLEFT", x, y)
        button:SetSize(26, 26)
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", button, "RIGHT", 2, 0)
        text:SetText(label)
        button:SetScript("OnClick", function(self)
            set(self:GetChecked() and true or false)
            Apply()
            RefreshPanel()
        end)
        refreshers[#refreshers + 1] = function() button:SetChecked(get()) end
    end

    Check("Enable display", 18, -75,
        function() return EGD.Settings().visibility ~= "NEVER" end,
        function(v) EGD.Settings().visibility = v and "ALWAYS" or "NEVER" end)
    Check("Hide at full durability", 230, -75,
        function() return EGD.Settings().hideAtFull end,
        function(v) EGD.Settings().hideAtFull = v end)
    Check("Show icon", 18, -110,
        function() return EGD.Settings().showIcon end,
        function(v) EGD.Settings().showIcon = v end)
    Check("Show percentage", 230, -110,
        function() return EGD.Settings().showPercent end,
        function(v) EGD.Settings().showPercent = v end)
    Check("Dynamic white-to-red colour", 18, -145,
        function() return EGD.Settings().dynamicColor end,
        function(v) EGD.Settings().dynamicColor = v end)

    local function Slider(label, y, lo, hi, step, get, set, disabled)
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 30, y)
        slider:SetWidth(395)
        slider:SetMinMaxValues(lo, hi)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        slider.Low:SetText(tostring(lo))
        slider.High:SetText(tostring(hi))
        local function UpdateLabel(v)
            slider.Text:SetText(label .. ": " .. tostring(math.floor(v + 0.5)))
        end
        slider:SetScript("OnValueChanged", function(_, value)
            UpdateLabel(value)
            if syncing then return end
            set(math.floor(value + 0.5))
            Apply()
        end)
        refreshers[#refreshers + 1] = function()
            slider:SetValue(get())
            UpdateLabel(get())
            local enabled = not disabled or not disabled()
            slider:SetEnabled(enabled)
            slider:SetAlpha(enabled and 1 or 0.4)
        end
    end
    Slider("Font size", -203, 8, 30, 1,
        function() return EGD.Settings().fontSize end,
        function(v) EGD.Settings().fontSize = v end)
    local channels = { {"Red", "r"}, {"Green", "g"}, {"Blue", "b"} }
    for i, channel in ipairs(channels) do
        local name, key = channel[1], channel[2]
        Slider("Static colour - " .. name, -203 - i * 48, 0, 255, 1,
            function() return EGD.Settings().color[key] * 255 end,
            function(v) EGD.Settings().color[key] = v / 255 end,
            function() return EGD.Settings().dynamicColor end)
    end

    local function Button(label, x, callback)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(195, 26)
        button:SetPoint("BOTTOMLEFT", x, 35)
        button:SetText(label)
        button:SetScript("OnClick", callback)
    end
    Button("Move in Unlock Mode", 25, Move)
    Button("Reset position", 240, function()
        EGD.Settings().pos = nil
        Apply()
    end)
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOM", 0, 15)
    hint:SetText("Hover the display for durability by slot. /egd help for commands.")
    panel:SetScript("OnShow", RefreshPanel)
end

function EGD.OpenOptions()
    if not EGD.Settings() then return end
    if not panel then BuildPanel() end
    panel:Show()
    RefreshPanel()
end

SLASH_ELLESMEREGEARDURABILITY1 = "/egd"
SlashCmdList.ELLESMEREGEARDURABILITY = function(message)
    if not EGD.Settings() then return end
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "" or command == "options" then
        EGD.OpenOptions()
    elseif command == "enable" or command == "disable" then
        EGD.Settings().visibility = command == "enable" and "ALWAYS" or "NEVER"
        Apply()
        if panel then RefreshPanel() end
        Print(command == "enable" and "Display enabled." or "Display disabled.")
    elseif command == "move" then
        Move()
    elseif command == "reset" then
        EGD.Reset()
        if panel then RefreshPanel() end
        Print("Settings reset; display disabled.")
    else
        Print("/egd - settings; /egd enable; /egd disable; /egd move; /egd reset")
    end
end
