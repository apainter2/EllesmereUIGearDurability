-- Run from the repository root: lua tests/run.lua
-- Focused runtime checks with mocked WoW frames; not an in-game UI test.
local created, inventory, samples = {}, {}, 0
local function noop() end
local methods = {}
for _, name in ipairs({"SetFrameStrata", "EnableMouse", "SetVertexColor", "SetFont",
    "SetTextColor", "SetClampedToScreen", "SetMovable", "RegisterForDrag",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "StartMoving",
    "StopMovingOrSizing", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag",
    "SetEnabled", "SetAlpha"}) do methods[name] = noop end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:GetWidth() return self.width or 1 end
function methods:GetHeight() return self.height or 1 end
function methods:GetSize() return self:GetWidth(), self:GetHeight() end
function methods:SetPoint(...) self.point = {...} end
function methods:ClearAllPoints() self.point = nil end
function methods:GetLeft() return 900 end
function methods:GetBottom() return 400 end
function methods:SetText(text) self.text = text end
function methods:SetTextColor(r, g, b) self.color = {r, g, b} end
function methods:GetStringWidth() return #(self.text or "") * 7 end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetShown(shown) self.shown = shown end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown = false end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterAllEvents() self.events = {} end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
local function object()
    return setmetatable({events = {}, scripts = {}}, {__index = methods})
end
function methods:CreateTexture() local o = object(); self.textureObject = o; return o end
function methods:CreateFontString() local o = object(); self.fontObject = o; return o end
function CreateFrame(kind, name, parent, template)
    local o = object(); o.name = name; o.kind = kind
    if template == "OptionsSliderTemplate" then o.Low, o.High, o.Text = object(), object(), object() end
    created[#created + 1] = o
    if name then _G[name] = o end
    return o
end
function wipe(t) for k in pairs(t) do t[k] = nil end end
tinsert = table.insert
UIParent = object(); UIParent:SetSize(1920, 1080)
STANDARD_TEXT_FONT = "font"
C_AddOns = {GetAddOnInfo = function() return nil end}
SlashCmdList, UISpecialFrames = {}, {}
DEFAULT_CHAT_FRAME = {AddMessage = noop}
local combat = false
function InCombatLockdown() return combat end
function GetInventoryItemDurability(slot)
    samples = samples + 1
    if inventory[slot] then return unpack(inventory[slot]) end
end
local unlocked, tooltip, element
EllesmereUI = {
    L = function(s) return s end,
    GetFontPath = function() return "font" end,
    SlugFlag = function() return "OUTLINE" end,
    ShowWidgetTooltip = function(_, text) tooltip = text() end,
    HideWidgetTooltip = noop,
    MakeUnlockElement = function(o) return o end,
    RegisterUnlockElements = function(_, elements) element = elements[1] end,
    OpenUnlockMode = function() unlocked = true end,
}
HEADSLOT, MAINHANDSLOT = "Head", "Main Hand"
local EGD = {}
assert(loadfile("Durability.lua"))("EllesmereUIGearDurability", EGD)
assert(loadfile("Options.lua"))("EllesmereUIGearDurability", EGD)
local boot = created[1]
boot.scripts.OnEvent(boot)
assert(#created == 1 and samples == 0, "disabled login must not build or sample")
assert(element.key == "EGD_GearDurability" and element.getFrame() == nil)
assert(EGD.Settings().visibility == "NEVER")
local p = EGD.Settings()
inventory = {[1] = {77, 100}, [16] = {145, 200}, [2] = {0, 0}}
p.visibility = "ALWAYS"; EGD.Apply()
local display = assert(EGD_DurabilityDisplay)
assert(display.shown and display.fontObject.text == "72%", "floor lowest, not average")
assert(display.textureObject.texture == "Interface\\Icons\\Trade_BlackSmithing")
local eventFrame
for _, f in ipairs(created) do if f.events.UPDATE_INVENTORY_DURABILITY then eventFrame = f end end
assert(eventFrame)
local count = 0; for _ in pairs(eventFrame.events) do count = count + 1 end
assert(count == 6)
for _, event in ipairs({"UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_REGEN_ENABLED", "PLAYER_UNGHOST", "MERCHANT_CLOSED", "PLAYER_ENTERING_WORLD"}) do
    assert(eventFrame.events[event], event)
    inventory[16] = {50, 100}; eventFrame.scripts.OnEvent(eventFrame, event)
    assert(display.fontObject.text == "50%", event)
end
display.scripts.OnEnter(display)
assert(tooltip:find("Head  77%%") and tooltip:find("Main Hand  50%%"))
inventory = {[1] = {100, 100}}; p.hideAtFull = true; EGD.Apply()
assert(not display.shown)
inventory = {[1] = {0, 100}}; EGD.Apply()
assert(display.shown and display.fontObject.text == "0%")
assert(display.fontObject.color[1] == 1 and display.fontObject.color[2] == 0.35)
inventory = {}; EGD.Apply(); assert(not display.shown)
p.hideAtFull = false; p.showIcon = false; p.showPercent = false; EGD.Apply()
assert(not display.shown)
p.showPercent = true; p.fontSize = 22; p.dynamicColor = false
p.color = {r = 0.2, g = 0.4, b = 0.6}; EGD.Apply()
assert(display.shown and display:GetHeight() == 24)
assert(display.fontObject.color[1] == 0.2 and display.fontObject.color[3] == 0.6)
p.pos = {centerX = 123, centerY = -45}; element.applyPos()
assert(display.point[4] == 123 and display.point[5] == -45)
assert(element.loadPos().x == 123)
element.savePos(nil, "CENTER", "CENTER", 0, 0)
assert(type(p.pos.centerX) == "number")
local original = EllesmereUIGearDurabilityDB
EGD.OpenOptions(); assert(EGD_SettingsPanel.shown)
combat = true; SlashCmdList.ELLESMEREGEARDURABILITY("move"); assert(not unlocked)
combat = false; SlashCmdList.ELLESMEREGEARDURABILITY("move"); assert(unlocked)
SlashCmdList.ELLESMEREGEARDURABILITY("disable")
assert(not display.shown and next(eventFrame.events) == nil)
local previousSamples = samples; EGD.Apply(); assert(samples == previousSamples)
EGD.Reset(); assert(EllesmereUIGearDurabilityDB == original)
assert(EGD.Settings().visibility == "NEVER" and EGD.Settings().fontSize == 14)
local frameCount = #created
SlashCmdList.ELLESMEREGEARDURABILITY("enable")
assert(#created == frameCount, "re-enable should reuse frames")
for _, f in ipairs(created) do assert(not f.scripts.OnUpdate, "no polling") end
assert(not _G._EUI_GearDurability_Apply and not _G.EllesmereUIQoLDB)
EGD.Settings().pos = {centerX = 17, centerY = -23}
EGD.Settings().fontSize = 19
local reloaded = {}
assert(loadfile("Durability.lua"))("EllesmereUIGearDurability", reloaded)
local reloadBoot = created[#created]
reloadBoot.scripts.OnEvent(reloadBoot)
assert(reloaded.Settings().fontSize == 19 and reloaded.Settings().pos.centerY == -23)
assert(EGD_DurabilityDisplay.point[4] == 17 and EGD_DurabilityDisplay.point[5] == -23)
print("PASS: lazy startup, minimum durability, all refresh events, tooltip, visibility,")
print("colours, settings UI, movement, reset, persistence, frame reuse, no polling, isolation")
