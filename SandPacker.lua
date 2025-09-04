
-- SandPacker for World of Warcraft Classic
-- This addon tracks Silithyst locations and displays them on the map.

local SandPacker = CreateFrame("Frame", "SandPackerFrame")
SandPacker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
SandPacker:RegisterEvent("PLAYER_ENTERING_WORLD")
SandPacker:RegisterEvent("CHAT_MSG_LOOT")

SandPacker_SavedNodes = SandPacker_SavedNodes or {}

local silithystNodes = {
    {x = 41.2, y = 45.6},
    {x = 54.3, y = 34.7},
    {x = 60.1, y = 25.3},
    {x = 36.7, y = 29.8},
    {x = 49.5, y = 19.2},
    {x = 65.2, y = 44.1},
    {x = 32.8, y = 53.7},
    {x = 44.9, y = 62.3},
    {x = 58.7, y = 59.1},
    {x = 51.3, y = 51.2},
    {x = 34.0, y = 36.0},
    {x = 60.0, y = 53.0},
    {x = 45.0, y = 23.0},
    {x = 53.0, y = 63.0},
    {x = 39.0, y = 59.0},
    {x = 63.0, y = 29.0},
    {x = 57.0, y = 41.0},
    {x = 38.0, y = 41.0},
    {x = 47.0, y = 38.0},
    {x = 56.0, y = 32.0},
}


local mapPins = {}
local minimapPins = {}
local trackingEnabled = true
local minimapButton
local mapOverlay

function AddMapPins()
    -- Merge static and discovered nodes
    local allNodes = {}
    for _, node in ipairs(silithystNodes) do table.insert(allNodes, node) end
    for _, node in ipairs(SandPacker_SavedNodes) do table.insert(allNodes, node) end
    print("[SandPacker DEBUG] AddMapPins called. trackingEnabled:", trackingEnabled)
    if not trackingEnabled then return end
    -- World Map pins (Questie-style overlay)
    if WorldMapFrame and GetRealZoneText() == "Silithus" then
        -- Create overlay if needed
        if not mapOverlay then
            mapOverlay = CreateFrame("Frame", "SandPackerMapOverlay", WorldMapFrame)
            mapOverlay:SetAllPoints(WorldMapFrame)
            mapOverlay:SetFrameStrata("FULLSCREEN")
            mapOverlay:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)
        end
        -- Hook AddMapPins to WorldMapFrame events
        if not WorldMapFrame.SandPackerHooked then
            WorldMapFrame:HookScript("OnShow", function()
                if GetRealZoneText() == "Silithus" and trackingEnabled then AddMapPins() end
            end)
            WorldMapFrame:HookScript("OnSizeChanged", function()
                if GetRealZoneText() == "Silithus" and trackingEnabled then AddMapPins() end
            end)
            WorldMapFrame.SandPackerHooked = true
        end
        mapOverlay:Show()
        -- Remove old pins
        for _, pin in ipairs(mapPins) do
            if pin then pin:Hide(); pin:SetParent(nil) end
        end
        mapPins = {}
        for i, node in ipairs(allNodes) do
            local pin = CreateFrame("Frame", nil, mapOverlay)
            pin:SetSize(9, 9)
            pin.icon = pin:CreateTexture(nil, "ARTWORK")
            pin.icon:SetTexture("Interface\\Icons\\INV_Misc_Dust_02")
            pin.icon:SetTexCoord(0, 1, 0, 1)
            pin.icon:SetAllPoints(pin)
            pin:Show()
            mapPins[i] = pin
        end
        -- Update pin positions
        local function UpdatePinPositions()
            local mapW, mapH = mapOverlay:GetWidth(), mapOverlay:GetHeight()
            for i, node in ipairs(allNodes) do
                local pin = mapPins[i]
                if pin then
                    pin:ClearAllPoints()
                    pin:SetPoint("TOPLEFT", mapOverlay, "TOPLEFT", node.x / 100 * mapW - 9, -node.y / 100 * mapH - 9)
                end
            end
        end
        mapOverlay:SetScript("OnShow", UpdatePinPositions)
        mapOverlay:SetScript("OnSizeChanged", UpdatePinPositions)
        UpdatePinPositions()
        print("[SandPacker DEBUG] Map pins placed using overlay.")
    elseif mapOverlay then
        mapOverlay:Hide()
    end
end

    -- Minimap pins
    if GetRealZoneText() == "Silithus" then
        local px, py = UnitPosition("player")
        for i, node in ipairs(silithystNodes) do
            if not minimapPins[i] then
                local pin = CreateFrame("Frame", nil, Minimap)
                pin:SetSize(8, 8)
                pin.icon = pin:CreateTexture(nil, "ARTWORK")
                pin.icon:SetTexture("Interface\\Icons\\INV_Misc_Dust_02")
                pin.icon:SetTexCoord(0, 1, 0, 1)
                pin.icon:SetAllPoints(pin)
                minimapPins[i] = pin
            end
            minimapPins[i]:Show()
        end
        SandPacker:SetScript("OnUpdate", function()
            local playerX, playerY, playerMap = UnitPosition("player")
            for i, node in ipairs(silithystNodes) do
                local pin = minimapPins[i]
                if pin then
                    -- Convert node coords (0-100) to world position
                    local nodeX, nodeY = node.x, node.y
                    -- Silithus map bounds (approximate, for Classic)
                    local mapMinX, mapMinY, mapMaxX, mapMaxY = 0, 0, 100, 100
                    local dx = (nodeX - (playerX or 0)) * 10 -- scale for minimap
                    local dy = (nodeY - (playerY or 0)) * 10
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist < 80 then -- Only show if within 80 units (tweak as needed)
                        pin:SetPoint("CENTER", Minimap, "CENTER", dx, -dy)
                        pin:Show()
                    else
                        pin:Hide()
                    end
                end
            end
        end)
    end

local function RemoveMapPins()
    print("[SandPacker DEBUG] RemoveMapPins called.")
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
