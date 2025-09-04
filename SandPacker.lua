
-- SandPacker for World of Warcraft Classic
-- This addon tracks Silithyst locations and displays them on the map.

local SandPacker = CreateFrame("Frame", "SandPackerFrame")
SandPacker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
SandPacker:RegisterEvent("PLAYER_ENTERING_WORLD")
SandPacker:RegisterEvent("CHAT_MSG_LOOT")

SandPacker_SavedNodes = SandPacker_SavedNodes or {}


-- Load Silithyst node locations from SandLocations.lua
local silithystNodes = SandPacker_SilithystNodes or {}


local mapPins = {}
local minimapPins = {}

-- HBD integration
local HBD = LibStub and LibStub("HereBeDragons-2.0", true)
local HBDPins = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
local SANDPACKER_REF = "SandPacker"
local trackingEnabled = true
local minimapButton
local mapOverlay


function AddMapPins()
    if not HBD or not HBDPins then
        print("[SandPacker] HereBeDragons library not found!")
        return
    end
    -- Remove old pins
    HBDPins:RemoveAllWorldMapIcons(SANDPACKER_REF)
    HBDPins:RemoveAllMinimapIcons(SANDPACKER_REF)
    mapPins = {}
    minimapPins = {}

    -- Merge static and discovered nodes
    local allNodes = {}
    for _, node in ipairs(silithystNodes) do table.insert(allNodes, node) end
    for _, node in ipairs(SandPacker_SavedNodes) do table.insert(allNodes, node) end
    print("[SandPacker DEBUG] AddMapPins called. trackingEnabled:", trackingEnabled)
    if not trackingEnabled then return end

    -- Get Silithus map info
    local silithusUiMapID = 1451 -- Classic Silithus
    for i, node in ipairs(allNodes) do
        -- Create icon frame for world map
    local pin = CreateFrame("Frame", nil, UIParent)
    pin:SetSize(8, 8)
        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetTexture("Interface\\Icons\\INV_Misc_Dust_02")
        pin.icon:SetTexCoord(0, 1, 0, 1)
        pin.icon:SetAllPoints(pin)
        pin:Show()
        mapPins[i] = pin
        -- Add to world map using HBD
        HBDPins:AddWorldMapIconMap(SANDPACKER_REF, pin, silithusUiMapID, node.x / 100, node.y / 100, nil, nil)
        -- Add to minimap using HBD
        HBDPins:AddMinimapIconMap(SANDPACKER_REF, pin, silithusUiMapID, node.x / 100, node.y / 100, false, false)
        minimapPins[i] = pin
    end
    print("[SandPacker DEBUG] Map pins placed using HereBeDragons.")
end



local function RemoveMapPins()
    print("[SandPacker DEBUG] RemoveMapPins called.")
    if HBDPins then
        HBDPins:RemoveAllWorldMapIcons(SANDPACKER_REF)
        HBDPins:RemoveAllMinimapIcons(SANDPACKER_REF)
    end
    for _, pin in ipairs(mapPins) do
        if pin then
            pin:Hide()
            pin:SetParent(nil)
        end
    end
    mapPins = {}
    for _, pin in ipairs(minimapPins) do
        if pin then
            pin:Hide()
            pin:SetParent(nil)
        end
    end
    minimapPins = {}
    SandPacker:SetScript("OnUpdate", nil)
end

local function ToggleTracking()
    print("[SandPacker DEBUG] ToggleTracking called. trackingEnabled:", trackingEnabled)
    trackingEnabled = not trackingEnabled
    if trackingEnabled then
        AddMapPins()
    else
        RemoveMapPins()
    end
end



SandPacker:SetScript("OnEvent", function(self, event, ...)
    print("[SandPacker DEBUG] Event:", event)
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        local zone = GetRealZoneText()
        if zone == "Silithus" then
            AddMapPins()
        else
            RemoveMapPins()
        end
    elseif event == "CHAT_MSG_LOOT" then
        local msg = ...
        if msg:find("Silithyst") then
            print("[SandPacker] Silithyst picked up!")
            -- Save current position as a new node if not already present
            local mapID = 1451 -- Silithus mapID for Classic
            local px, py, _ = UnitPosition("player")
            if px and py then
                -- Convert world position to map percent (approximate for Classic)
                -- In Classic, we don't have C_Map, so we use hardcoded bounds
                local minX, minY, maxX, maxY = 0, 0, 100, 100
                local normX = math.floor(px + 0.5)
                local normY = math.floor(py + 0.5)
                -- Check for duplicates
                local exists = false
                for _, node in ipairs(SandPacker_SavedNodes) do
                    if math.abs(node.x - normX) < 1 and math.abs(node.y - normY) < 1 then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(SandPacker_SavedNodes, {x = normX, y = normY})
                    print(string.format("[SandPacker] New Silithyst node saved at (%.1f, %.1f)", normX, normY))
                    AddMapPins()
                end
            end
        end
    end
end)


-- Create a minimap button using the Silithyst icon
local function CreateMinimapButton()
    print("[SandPacker DEBUG] CreateMinimapButton called.")
    if minimapButton then return end
    minimapButton = CreateFrame("Button", "SandPackerMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    -- Place minimap button on the edge of the minimap (default at 45 degrees)
    local radius = (Minimap:GetWidth() / 2) - 12
    local angle = math.rad(45) -- 45 degrees, top-right
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    minimapButton.icon = minimapButton:CreateTexture(nil, "ARTWORK")
    minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Dust_02")
    minimapButton.icon:SetTexCoord(0, 1, 0, 1)
    minimapButton.icon:SetAllPoints(minimapButton)
    minimapButton:Show()
    print("[SandPacker DEBUG] Minimap button shown.")
    minimapButton:SetScript("OnClick", function()
        ToggleTracking()
        if trackingEnabled then
            GameTooltip:AddLine("SandPacker: Tracking ON", 0, 1, 0)
        else
            GameTooltip:AddLine("SandPacker: Tracking OFF", 1, 0, 0)
        end
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("SandPacker", 1, 1, 1)
        if trackingEnabled then
            GameTooltip:AddLine("Left-click to hide Silithyst nodes", 0, 1, 0)
        else
            GameTooltip:AddLine("Left-click to show Silithyst nodes", 1, 0, 0)
        end
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

print("[SandPacker DEBUG] Addon loaded and timer started.")
C_Timer.After(2, function()
    CreateMinimapButton()
    if GetRealZoneText() == "Silithus" then
        AddMapPins()
    end
end)

SLASH_SANDPACKER1 = "/sandpacker"
SlashCmdList["SANDPACKER"] = function(msg)
    print("SandPacker loaded. Silithyst locations are shown on the map in Silithus.")
end
